class_name RoyaleResults
extends ResultsPanel
## Bilan d'une partie de Battle royale (bilan v2, lot BR-I2, maquette 5 de `conception/benchmark/battle_royale_maquettes`) :
## bandeau incliné « N°1 · Victoire ! » ou « Place N » (autocollant de la Bible), confettis discrets à la victoire, tuiles
## (place, éliminations, dégâts, niveau, coffres, durée), chronologie de la partie (saut, 1re élimination, largage, mise à
## prix, retour, fin : Royale.stats.timeline), Gagné (maîtrise, titre) et Gardé (insignes, coffre d'apparence), « Rejouer »
## en bouton principal et « Menu principal ».

## Étiquettes de la chronologie : sorte -> [texte, couleur de la pastille].
const MOMENTS := {
	"jump": ["Saut", RoyaleStyle.PAPER_200], "kill": ["1re élim.", RoyaleStyle.APPLE_LIGHT], "drop": ["Largage", RoyaleStyle.SUN_LIGHT],
	"bounty": ["Mis à prix", RoyaleStyle.STRAWBERRY_LIGHT], "revive": ["Retour", Color("86ddff")], "down": ["", RoyaleStyle.STRAWBERRY_LIGHT],
	"win": ["N°1", RoyaleStyle.SUN],
}
const TIMELINE_W := 900.0

var banner: PanelContainer
var timeline: Control
var confetti: Array = []


## Lignes de Royale.settle rangées comme les autres bilans (DuelResults._report_rows).
static func report_rows(got: Dictionary) -> Dictionary:
	var out := {"gained": [], "kept": []}
	if int(got.get("mastery", 0)) > 0:
		out.gained.append(row("Maîtrise %s" % GameData.class_data(Run.class_id).get("name_fr", ""), "+%d" % int(got.mastery), "", "expertise"))
	for t in got.get("text", []):
		var line := String(t)
		if line.begins_with("Maîtrise : "):
			continue  # déjà en tête de « Gagné »
		if line.begins_with("Titre : "):
			out.gained.append(row("Titre " + line.trim_prefix("Titre : "), "", "", "user"))
		else:
			out.kept.append(reward_row(line))
	return out


## Texte du bandeau : « N°1 · Victoire ! » ou « Place 4 ».
static func banner_text(place: int) -> String:
	return "N°1 · Victoire !" if place == 1 else "Place %d" % place


func show_results(place: int, kills: int, level: int, chests: int, secs: float, got: Dictionary) -> void:
	var won := place == 1
	var rep := report_rows(got)
	var dealt := float(Royale.stats.get("dealt", 0.0))
	var tiles: Array = [
		["%d / %d" % [place, Royale.PLAYERS], "place", "", won],
		[str(kills), "élimination" if kills <= 1 else "éliminations"],
		[RoyaleStyle.number(dealt), "dégâts", "Dégâts infligés aux autres héros"],
		[str(level), "niveau"],
		[str(chests), "coffre" if chests <= 1 else "coffres"],
		[RoyaleStyle.clock(secs), "durée"],
	]
	var wins := int(Profile.records.get("royale_wins", 0))
	show_spec({
		"title": banner_text(place),
		"tone": "win" if place <= 3 else "lose",
		"subtitle": ("%s · " % Profile.hero_name if Profile.hero_name != "" else "")
			+ ("Dernier debout sur %d héros" % Royale.PLAYERS if won else "Tu termines %de sur %d" % [place, Royale.PLAYERS])
			+ (" · %de victoire" % wins if won and wins > 1 else ""),
		"tiles": tiles,
		"gained": rep.gained,
		"kept": rep.kept,
		"quest": Compass.after("royale", {"looks": 1 if (got.get("text", []) as Array).any(func(t): return String(t).begins_with("Coffre d'apparence")) else 0}),
		"buttons": [
			{"text": "Rejouer", "primary": true, "call": func():
				get_tree().paused = false
				Royale.start(Profile.selected_class)
				get_tree().change_scene_to_file("res://scenes/world.tscn")},
			{"text": "Menu principal", "call": func(): Royale.leave(get_tree())},
		],
	})
	_dress(place)
	_add_timeline(Royale.stats.get("timeline", []), float(Royale.stats.get("clock", 0.0)))
	if won:
		_confetti()
	_fit_v2.call_deferred()


## Le titre du composant commun devient un bandeau autocollant incliné (soleil à la victoire, fraise sinon).
func _dress(place: int) -> void:
	var title := _body.get_child(0) as Label
	var orn := _body.get_child(1)
	title.visible = false
	if orn is Control:
		(orn as Control).visible = false
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(wrap)
	_body.move_child(wrap, 0)
	banner = PanelContainer.new()
	var tone := "soleil" if place == 1 else ("lagon" if place <= 3 else "fraise")
	banner.add_theme_stylebox_override("panel", RoyaleStyle.sticker(tone, 8, Vector2(48, 4), 20))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := RoyaleStyle.label(banner, banner_text(place), 50, Color.WHITE, "title", 9)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RoyaleStyle.tilt(wrap, banner, -4.0)  # (bandeau incliné : un conteneur remettrait l'angle à zéro)
	# entrée en ressort (Bible § 7 : récompense 520 ms élastique)
	banner.scale = Vector2(0.6, 0.6)
	var tw := banner.create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Chronologie de la partie : une barre (départ de l'aigle -> fin) et une pastille par moment, à sa place.
func _add_timeline(moments: Array, total: float) -> void:
	if moments.is_empty():
		return
	var end := total
	for m in moments:
		end = maxf(end, float(m.t))
	end = maxf(end, 1.0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(box)
	_body.move_child(box, _tiles_index() + 1)
	RoyaleStyle.label(box, "La partie", 16, UiTheme.TEXT, "bold", 0)
	timeline = Control.new()
	timeline.custom_minimum_size = Vector2(TIMELINE_W, 58)
	timeline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	timeline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(timeline)
	var bar := Panel.new()
	var sb := RoyaleStyle.box(RoyaleStyle.LAGOON, 7, 0, Vector2.ZERO)
	sb.set_border_width_all(2)
	bar.add_theme_stylebox_override("panel", sb)
	bar.position = Vector2(0, 34)
	bar.size = Vector2(TIMELINE_W, 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timeline.add_child(bar)
	var last_x := -INF
	var row := 0
	for m in moments:
		var def: Array = MOMENTS.get(String(m.kind), ["", RoyaleStyle.PAPER_200])
		var text := String(def[0]) if String(def[0]) != "" else String(m.get("text", ""))
		if String(m.kind) == "kill" and String(m.get("text", "")) != "":
			text = String(def[0])
		var x := clampf(float(m.t) / end, 0.0, 1.0) * TIMELINE_W
		row = 1 - row if x - last_x < 96.0 else 0  # deux pastilles proches : l'une au-dessus de l'autre
		last_x = x
		var pill := RoyaleStyle.pill(timeline, text, def[1], 14)
		pill.set_meta("kind", String(m.kind))
		var tip := String(m.get("text", ""))
		if tip != "" and tip != text:
			pill.tooltip_text = tip
			pill.mouse_filter = Control.MOUSE_FILTER_PASS
		pill.position = Vector2(clampf(x - 40.0, 0.0, TIMELINE_W - 86.0), 0.0 if row == 0 else 50.0)
		var tick := ColorRect.new()
		tick.color = RoyaleStyle.INK
		tick.size = Vector2(3, 18)
		tick.position = Vector2(clampf(x, 1.0, TIMELINE_W - 2.0) - 1.5, 30)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		timeline.add_child(tick)
	if row == 1:
		timeline.custom_minimum_size.y = 80


## Rang des tuiles dans le corps du bilan (pour glisser la chronologie juste dessous).
func _tiles_index() -> int:
	for i in _body.get_child_count():
		var c := _body.get_child(i)
		if c is HBoxContainer and c.get_child_count() > 0 and c.get_child(0) is PanelContainer:
			return i
	return 2


## Confettis des 5 bonbons, 24 au plus, 1,2 s (Bible § 8), seulement à la victoire.
func _confetti() -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	var vw := get_viewport().get_visible_rect().size
	for i in 24:
		var c := ColorRect.new()
		c.color = RoyaleStyle.CANDIES[i % RoyaleStyle.CANDIES.size()]
		c.size = Vector2(randf_range(8, 14), randf_range(5, 9))
		c.position = Vector2(vw.x * randf_range(0.18, 0.82), randf_range(-40.0, vw.y * 0.12))
		c.rotation = randf() * TAU
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(c)
		confetti.append(c)
		var tw := c.create_tween().set_parallel(true)
		var fall := randf_range(160.0, 320.0)
		tw.tween_property(c, "position:y", c.position.y + fall, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(c, "rotation", c.rotation + randf_range(-4.0, 4.0), 1.2)
		tw.tween_property(c, "modulate:a", 0.0, 0.5).set_delay(0.7)
	Sfx.ui("confirm", -8.0)


## La chronologie prend sa place : les blocs Gagné / Gardé défilent un peu plus tôt (1280×720).
func _fit_v2() -> void:
	if _scroll == null or timeline == null:
		return
	var inner := _scroll.get_child(0) as Control
	var room := clampf(get_viewport().get_visible_rect().size.y - 450.0 - 90.0 - (50.0 if _quest_box != null else 0.0), 120.0, 400.0)
	_scroll.custom_minimum_size.y = minf(inner.get_combined_minimum_size().y, room)
