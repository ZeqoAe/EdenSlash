class_name RoyaleRecap
extends CanvasLayer
## Battle royale (lot BR-I2) : récapitulatif de mort, puis bandeau du spectateur.
##   - Carte en haut au centre : « Éliminé · 4e », qui t'a éliminé (classe, niveau), le coup de grâce (sort, dégâts), les
##     PV qui lui restaient, tes dégâts donnés / reçus et le temps survécu ; « Regarder » (A, Entrée) la ferme, « Bilan »
##     (B, Échap) ouvre le bilan. Tombé dans les deux premières minutes, la carte dit seulement « Retour dans N s » et
##     disparaît au retour (RoyaleDirector la ferme).
##   - En bas : « ◀ Tu regardes : Assassin · niv. 14 ▶ · [F] son équipement » tant que le joueur regarde la fin.
## Le jeu continue derrière (les autres héros se battent) ; rien ici ne met en pause. [param data] : RoyaleDirector.death_recap.

signal watch_requested
signal results_requested

const CARD_W := 720.0

var data: Dictionary = {}
var director: Node  # RoyaleDirector (bandeau du spectateur)
var card: PanelContainer
var watch_button: Button
var results_button: Button
var _bar: PanelContainer
var _bar_line: RoyaleKeyLine  # (lot BR-I3 : touches dessinées en pastilles)
var _countdown: Label
var _t := 0.0


static func open(host: Node, p_director: Node, recap: Dictionary) -> RoyaleRecap:
	var r := RoyaleRecap.new()
	r.director = p_director
	r.data = recap
	host.add_child(r)
	return r


func _ready() -> void:
	layer = 24
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_card(root)
	_build_bar(root)


func revive_mode() -> bool:
	return bool(data.get("revive", false))


func _build_card(root: Control) -> void:
	var top := CenterContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 104  # (sous le cadre de la cible, en haut au centre)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", RoyaleStyle.paper(Vector2(26, 18)))
	card.custom_minimum_size = Vector2(CARD_W if not revive_mode() else 560.0, 0)
	top.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var place := int(data.get("place", 0))
	var t := RoyaleStyle.label(null, "Éliminé !" if revive_mode() or place <= 0 else "Éliminé · %de" % place, 40, RoyaleStyle.STRAWBERRY_LIGHT, "title", 7)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	RoyaleStyle.tilt(v, t, -3.0)  # (titre incliné, bible § 4)
	# qui, avec quoi
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 14)
	v.add_child(who)
	var cid := String(data.get("cid", ""))
	if cid != "":
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", RoyaleStyle.box(_family_color(cid), 14, 4, Vector2(4, 4)))
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		who.add_child(tile)
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(64, 64)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = UiTheme.texture(String(GameData.class_data(cid).get("icon", "")))
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(ic)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.add_child(lines)
	RoyaleStyle.label(lines, headline(data), 22, RoyaleStyle.INK, "bold", 0)
	var how := how_line(data)
	if how != "":
		RoyaleStyle.label(lines, how, 17, RoyaleStyle.INK_300, "bold", 0)
	if int(data.get("killer_hp", -1)) >= 0:
		var pill := RoyaleStyle.pill(who, "Il lui restait %s PV" % RoyaleStyle.number(float(data.killer_hp)))
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# chiffres
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	v.add_child(tiles)
	RoyaleStyle.tile(tiles, RoyaleStyle.number(float(data.get("dealt", 0.0))), "dégâts donnés")
	RoyaleStyle.tile(tiles, RoyaleStyle.number(float(data.get("taken", 0.0))), "dégâts reçus")
	RoyaleStyle.tile(tiles, RoyaleStyle.clock(float(data.get("survived", 0.0))), "survécu")
	if revive_mode():
		_countdown = RoyaleStyle.label(v, "", 22, RoyaleStyle.LAGOON_DARK, "bold", 0)
		_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tick_countdown()
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	watch_button = RoyaleStyle.button("Regarder", "sun", "A", 58.0)
	watch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	watch_button.size_flags_stretch_ratio = 1.25
	watch_button.pressed.connect(watch)
	row.add_child(watch_button)
	results_button = RoyaleStyle.button("Bilan", "paper", "B", 58.0)
	results_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_button.pressed.connect(func(): results_requested.emit())
	row.add_child(results_button)
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.18)


func _build_bar(root: Control) -> void:
	var bottom := CenterContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -96
	bottom.offset_bottom = -52
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_bar)
	_bar_line = RoyaleKeyLine.new()
	_bar.add_child(_bar_line)
	_bar.visible = false


## Ligne du tueur : « Assassin · niv. 14 » (l'anneau : « L'anneau t'a rattrapé »).
static func headline(r: Dictionary) -> String:
	if String(r.get("name", "")) == "":
		return "Un météore t'a écrasé" if String(r.get("cause", "")) == "meteor" else "L'anneau t'a rattrapé"  # (lot BR-R1)
	return "%s · niv. %d" % [String(r.name), int(r.get("lv", 1))]


## Ligne du coup de grâce : « Coup de grâce : Lame de l'ombre · 312 » ("" si inconnu).
static func how_line(r: Dictionary) -> String:
	if String(r.get("move", "")) == "":
		return ""
	var dmg := float(r.get("dmg", 0.0))
	return "Coup de grâce : %s%s" % [String(r.move), " · %s" % RoyaleStyle.number(dmg) if dmg >= 1.0 else ""]


## Couleur de la famille de la classe (Bible § 3 : Rempart soleil, Ombre mandarine, Traque pomme, Ferveur lagon, Arcane améthyste).
static func _family_color(cid: String) -> Color:
	var fam := Duel.family_of(cid) if cid != "" else 0
	return [RoyaleStyle.PAPER_200, RoyaleStyle.SUN, RoyaleStyle.MANDARIN, RoyaleStyle.APPLE, RoyaleStyle.LAGOON, RoyaleStyle.AMETHYST][clampi(fam, 0, 5)]


func is_card_open() -> bool:
	return card != null and is_instance_valid(card) and card.visible


## « Regarder » : la carte se ferme, le bandeau du spectateur reste.
func watch() -> void:
	if not is_card_open():
		return
	card.visible = false
	watch_requested.emit()


func _process(delta: float) -> void:
	_t += delta
	if _countdown != null:
		_tick_countdown()
	var spect := director != null and is_instance_valid(director) and bool(director.get("spectating")) and String(director.get("phase")) != "over"
	_bar.visible = spect and not revive_mode()
	if _bar.visible:
		_bar_line.set_text(bar_text())
	# la carte se replie seule au bout de 12 s (la vue reste au spectateur)
	if not revive_mode() and is_card_open() and _t > 12.0:
		watch()


func _tick_countdown() -> void:
	var left := 0.0
	if director != null and is_instance_valid(director):
		for rv in director.get("revives"):
			if (rv as Dictionary).has("player"):
				left = float(rv.t)
	_countdown.text = "Retour dans %d s" % maxi(1, ceili(left)) if left > 0.0 else "De retour !"


## Bandeau du spectateur : héros regardé et touches.
func bar_text() -> String:
	var w = director.get("watched")
	var who := "—"
	if w != null and is_instance_valid(w):
		var st: Dictionary = (w as Node).get_meta("royale", {})
		who = "%s · niv. %d" % [(w as Combatant).display_name.get_slice(" ·", 0), int(st.get("lv", (w as Combatant).level))]
	var prev := Settings.pad_name(JOY_BUTTON_LEFT_SHOULDER) if Gamepad.active else Settings.action_label("move_left", 1)
	var next := Settings.pad_name(JOY_BUTTON_RIGHT_SHOULDER) if Gamepad.active else Settings.action_label("move_right", 1)
	return "[%s] ◀  Tu regardes : %s  ▶ [%s]    [%s] son équipement    [%s] bilan" % [prev, who, next,
		Settings.action_label("interact", 1), Settings.action_label("pause", 1)]


func close() -> void:
	queue_free()


func _input(event: InputEvent) -> void:
	if revive_mode() or not is_card_open():
		return
	var pad := event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed
	if (pad and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A) or (not pad and event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		watch()
	elif (pad and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B) or event.is_action_pressed("pause") \
			or (not pad and event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		results_requested.emit()
