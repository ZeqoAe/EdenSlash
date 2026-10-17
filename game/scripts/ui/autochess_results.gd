class_name AutochessResults
extends ResultsPanel
## L'Échiquier, lot AC-I : le bilan de fin de partie, par le composant commun des bilans (ResultsPanel). Ta place en grand,
## cinq tuiles (place, manches, dégâts de tes héros, meilleure unité, durée), « Gagné » (coffres d'apparence, titres :
## AutochessRewards.last), la ligne « Ta quête », et trois boutons : Rejouer, Statistiques (le bilan détaillé d'AC-V,
## AutochessRecap.open_game), Menu principal. Mode scellé : rien d'autre (ni maîtrise, ni insignes, ni XP de héros).
## Lot ACX-2 : podium des 8 stratèges sous les tuiles (portrait, place, trait principal ; toi en soleil), « Menu principal »
## (mot de la BIBLE, plus « lobby »).

## [param info] : {diff, place, stage, rounds, rounds_won, secs, abandoned} ; [param acc] : AutochessScreen.game_stats ;
## [param got] : AutochessRewards.last ; [param calls] : {replay, stats, back} (Callable).
func show_results(info: Dictionary, acc: Dictionary, got: Dictionary, calls: Dictionary, podium: Array = []) -> void:
	var place := int(info.get("place", 8))
	var won := place == 1
	var abandoned := bool(info.get("abandoned", false))
	var title := "VICTOIRE !" if won else ("TOP %d" % place if place <= 4 else "PLACE %d" % place)
	var diff := AutochessRewards.diff_name(int(info.get("diff", 0)))
	var sub := "%s · %s" % [diff, "abandon : ta place du moment" if abandoned else ("seul en lice sur %d stratèges" % AutochessData.PLAYERS if won else "%s sur %d" % [AutochessPlayers.place_text(place), AutochessData.PLAYERS])]
	var mvp := AutochessStats.game_mvp(acc)
	var dealt := 0.0
	for id in (acc.get("units", {}) as Dictionary):
		dealt += float(acc.units[id].get("dealt", 0.0))
	var secs := float(info.get("secs", 0.0))
	var tiles: Array = [
		["%d / %d" % [place, AutochessData.PLAYERS], "place", "Meilleure place en %s : %s" % [diff, _best_text(int(info.get("diff", 0)))], won],
		[str(int(info.get("rounds", 0))), "manches", "Dont %d gagnées" % int(info.get("rounds_won", 0))],
		[number(dealt), "dégâts", "Dégâts de tes héros sur toute la partie"],
		[AutochessData.unit_name(mvp) if mvp != "" else "—", "meilleure unité", _mvp_tip(acc, mvp)],
		["%d min %02d s" % [int(secs) / 60, int(secs) % 60], "durée"],
	]
	var gained: Array = []
	var looks := 0
	for c in got.get("chests", []):
		var t: Dictionary = Rewards.TYPES.get(String(c.type), {})
		gained.append(row(String(t.get("name", "Coffre d'apparence")), "", "%s · %s" % [String(c.text),
			"première fois dans cette difficulté" if String(c.kind) == "first" else "coffre du jour"], "chest"))
		looks += 1
	for t in got.get("titles", []):
		gained.append(row("Titre « %s »" % String(t.title), "nouveau" if bool(t.get("new", false)) else "", String(t.text), "user"))
	var notes: Array = []
	if int(got.get("opened", -1)) >= 0:
		notes.append("Difficulté %s ouverte !" % AutochessRewards.diff_name(int(got.opened)))
	var foot := ""
	if bool(got.get("early", false)):
		foot = "Abandon avant l'étape %d : aucune récompense." % AutochessRewards.ABANDON_MIN_STAGE
	elif gained.is_empty():
		foot = "Les quatre premiers gagnent un coffre d'apparence, une fois par difficulté puis chaque jour."
	show_spec({
		"title": title,
		"tone": "win" if place <= 4 else "lose",
		"subtitle": sub,
		"notes": notes,
		"tiles": tiles,
		"gained": gained,
		"footnote": foot,
		"quest": Compass.after("autochess", {"looks": looks, "titles": (got.get("titles", []) as Array).size()}),
		"buttons": [
			{"text": "Rejouer", "primary": true, "call": calls.get("replay", Callable())},
			{"text": "Statistiques", "call": calls.get("stats", Callable())},
			{"text": "Menu principal", "call": calls.get("back", Callable())},
		],
	})
	if not podium.is_empty():
		_add_podium(podium)
	_add_final(info.get("team", []), got.get("chests", []))
	if bool(info.get("daily", false)):
		var dl: Dictionary = got.get("daily", {})
		if not dl.is_empty():
			var t := "Partie du jour : %s" % AutochessPlayers.place_text(int(dl.place))
			t += " · nouveau record du jour !" if bool(dl.get("new_best", false)) else " · record du jour : %s" % AutochessPlayers.place_text(int(dl.best))
			var l := AutochessHud.ink_lbl(t, 15, Color.WHITE, 800)
			l.name = "AcDailyLine"
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_body.add_child(l)
			_body.move_child(l, mini(2, _body.get_child_count() - 1))


## Lot ACX-3 (n° 15) : « Ton équipe finale » (icône de classe sur la couleur du coût, étoiles, objets en mini-cases) et les
## coffres gagnés, révélés un à un (autocollant qui s'ouvre en ressort, rayons, son qui monte, confettis au dernier),
## sur une seule rangée pour tenir dans 1280 × 720.
func _add_final(team: Array, chests: Array) -> void:
	if team.is_empty() and chests.is_empty():
		return
	var row := HBoxContainer.new()
	row.name = "AcFinal"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not team.is_empty():
		var well := PanelContainer.new()
		well.name = "AcTeam"
		well.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ws := AutochessHud.well(14.0, 2.0)
		for side in ["left", "right", "top", "bottom"]:
			ws.set("content_margin_" + side, 6)
		well.add_theme_stylebox_override("panel", ws)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		well.add_child(v)
		v.add_child(AutochessHud.ink_lbl("Ton équipe finale", 14, Color.WHITE, 900))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 4)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(h)
		var list := team.duplicate()
		list.sort_custom(func(a, b):
			var ca := AutochessPool.cost_of(String(a.id)) * 10 + int(a.get("stars", 1))
			var cb := AutochessPool.cost_of(String(b.id)) * 10 + int(b.get("stars", 1))
			return ca > cb)
		for u in list.slice(0, 10):
			h.add_child(_unit_chip(u))
		row.add_child(well)
	if not chests.is_empty():
		var box := HBoxContainer.new()
		box.name = "AcChests"
		box.add_theme_constant_override("separation", 8)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in chests.size():
			var c: Dictionary = chests[k]
			var t: Dictionary = Rewards.TYPES.get(String(c.type), {})
			var ch := ChestSticker.new()
			ch.name = "AcChest_%d" % k
			ch.color = t.get("color", AutochessHud.candy("soleil"))
			ch.tooltip_text = "%s\n%s" % [String(t.get("name", "Coffre d'apparence")), String(c.get("text", ""))]
			box.add_child(ch)
			ch.reveal(0.55 + 0.45 * k, k, k == chests.size() - 1)
		row.add_child(box)
	_body.add_child(row)
	var at := -1
	for i in _body.get_child_count():
		if _body.get_child(i).name == "AcPodium":
			at = i + 1
	if at >= 0:
		_body.move_child(row, at)


## Unité de l'équipe finale : tuile du coût, icône de classe, étoiles dessous, objets en mini-cases.
static func _unit_chip(u: Dictionary) -> Control:
	var id := String(u.get("id", ""))
	var stars := clampi(int(u.get("stars", 1)), 1, AutochessData.MAX_STARS)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	v.tooltip_text = "%s %s" % [AutochessData.unit_name(id), "★".repeat(stars)]
	for it in u.get("items", []):
		v.tooltip_text += "\n· " + AutochessUnitCard.item_name(String(it))
	var tile := PanelContainer.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel", AutochessHud.sticker(AutochessHud.cost_candy(AutochessPool.cost_of(id), 0), 8.0, 2.0, 2.0, 2.0, 2.0))
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(30, 30)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = UiTheme.texture(String(GameData.class_data(id).get("icon", "")))
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(ic)
	v.add_child(tile)
	var st := AutochessHud.ink_lbl("★".repeat(stars), 11, AutochessBoard.STAR_COLORS[stars - 1], 900)
	st.add_theme_constant_override("outline_size", 3)
	st.add_theme_color_override("font_outline_color", AutochessHud.INK)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var items := HBoxContainer.new()
	items.add_theme_constant_override("separation", 1)
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for it in u.get("items", []):
		var r := TextureRect.new()
		r.custom_minimum_size = Vector2(11, 11)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.texture = AutochessUnitCard.item_icon(String(it))
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		items.add_child(r)
	v.add_child(items)
	return v


## Coffre d'apparence autocollant (couleur de sa rareté) : fermé et transparent, puis il s'ouvre en ressort (520 ms),
## rayons tournants derrière, son qui monte d'un coffre à l'autre, confettis au dernier (BIBLE §7, « Récompense »).
class ChestSticker extends Control:
	var color := Color.WHITE
	var opened := false
	var _rays := -1.0

	func _init() -> void:
		custom_minimum_size = Vector2(54, 54)
		mouse_filter = Control.MOUSE_FILTER_PASS
		modulate.a = 0.0
		process_mode = Node.PROCESS_MODE_ALWAYS

	func reveal(delay: float, k: int, last: bool) -> void:
		pivot_offset = custom_minimum_size * 0.5
		scale = Vector2(0.3, 0.3)
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(delay)
		tw.tween_callback(func():
			opened = true
			_rays = 0.0
			UiFeel.cue("confirm", -8.0, 1.0 + 0.08 * k, [0.15, 0.2, 0.08])
			if last and not UiFeel.reduce_motion:
				UiFeel.confetti(get_global_rect().get_center(), 18)
			queue_redraw())
		tw.tween_property(self, "modulate:a", 1.0, 0.12)
		if UiFeel.reduce_motion:
			tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.12)
		else:
			tw.parallel().tween_property(self, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		if _rays >= 0.0:
			_rays += delta
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		if _rays >= 0.0 and not UiFeel.reduce_motion:
			var rot := _rays * TAU / 12.0
			for i in 8:
				var a := rot + i * TAU / 8.0
				var p := PackedVector2Array([c, c + Vector2.from_angle(a - 0.12) * 30.0, c + Vector2.from_angle(a + 0.12) * 30.0])
				draw_colored_polygon(p, Color(AutochessHud.candy("soleil", 0), 0.45))
		var w := 34.0
		var body := Rect2(c.x - w * 0.5, c.y - 4.0, w, 18.0)
		draw_rect(Rect2(body.position + Vector2(0, 3), body.size), AutochessHud.INK)
		draw_rect(body, color)
		draw_rect(body, AutochessHud.INK, false, 2.0)
		var lid := Rect2(c.x - w * 0.5 - 2.0, c.y - 14.0 - (6.0 if opened else 0.0), w + 4.0, 10.0)
		draw_rect(lid, color.lightened(0.25))
		draw_rect(lid, AutochessHud.INK, false, 2.0)
		draw_rect(Rect2(c.x - 3.0, c.y - 6.0, 6.0, 8.0), AutochessHud.candy("soleil"))
		draw_rect(Rect2(c.x - 3.0, c.y - 6.0, 6.0, 8.0), AutochessHud.INK, false, 1.5)


## Podium des stratèges ([param list] : {name, class_id, place, trait, me}, classés) : une pastille papier par stratège,
## dans un puits d'encre, sous les tuiles.
func _add_podium(list: Array) -> void:
	var well := PanelContainer.new()
	well.name = "AcPodium"
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ws := AutochessHud.well(14.0, 2.0)
	ws.content_margin_left = 8
	ws.content_margin_right = 8
	ws.content_margin_top = 6
	ws.content_margin_bottom = 6
	well.add_theme_stylebox_override("panel", ws)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_child(h)
	for e in list:
		var me := bool(e.get("me", false))
		var chip := PanelContainer.new()
		chip.name = "AcPodium_%d" % int(e.place)
		chip.custom_minimum_size = Vector2(96, 0)
		chip.add_theme_stylebox_override("panel", AutochessHud.sticker(AutochessHud.candy("soleil") if me else AutochessHud.PAPER,
			10.0, 3.0, 2.0, 5.0, 3.0))
		chip.tooltip_text = "%s · %s%s" % [String(e.name), AutochessPlayers.place_text(int(e.place)),
			(" · " + String(e.trait)) if String(e.get("trait", "")) != "" else ""]
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(v)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 4)
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(top)
		var pic := TextureRect.new()
		pic.texture = UiTheme.texture(String(GameData.class_data(String(e.class_id)).get("icon", "")))
		pic.custom_minimum_size = Vector2(26, 26)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if int(e.place) > 4:
			pic.modulate = Color(0.75, 0.72, 0.8)
		top.add_child(pic)
		top.add_child(AutochessHud.pop_lbl(str(int(e.place)), 18, AutochessHud.INK))
		var nl := AutochessHud.ink_lbl(String(e.name), 13, AutochessHud.INK, 900)
		nl.clip_text = true
		nl.custom_minimum_size.x = 84
		v.add_child(nl)
		var tl := AutochessHud.ink_lbl(String(e.get("trait", "")), 13, AutochessHud.INK_300, 700)
		tl.clip_text = true
		tl.custom_minimum_size.x = 84
		v.add_child(tl)
		h.add_child(chip)
	var at := -1
	for i in _body.get_child_count():
		if _body.get_child(i) is HBoxContainer:
			at = i + 1
			break
	_body.add_child(well)
	if at >= 0:
		_body.move_child(well, at)


static func _best_text(d: int) -> String:
	var b := AutochessRewards.best(d)
	return AutochessPlayers.place_text(b) if b > 0 else "—"


static func _mvp_tip(acc: Dictionary, id: String) -> String:
	if id == "":
		return ""
	var e: Dictionary = acc.units[id]
	return "%s dégâts · %d élimination%s · meilleure unité de %d manche%s" % [AutochessStats.num(float(e.get("dealt", 0.0))),
		int(e.get("kills", 0)), "s" if int(e.get("kills", 0)) > 1 else "", int(e.get("mvp", 0)), "s" if int(e.get("mvp", 0)) > 1 else ""]
