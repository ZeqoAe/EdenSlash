class_name SettingsMenu
extends CanvasLayer
## Menu Paramètres (lobby et menu pause) : mode de jeu, combat automatique,
## touches, affichage, son, caméra et interface. Chaque changement est appliqué
## et sauvegardé tout de suite (Settings).

signal closed

const ACCENT := Color(0.98, 0.78, 0.35)
const LABEL_W := 330

var _root: Control
var _tabs: TabContainer
var _refreshers: Array[Callable] = []
var _status: Label
var _listen_action := ""
var _listen_idx := -1
var _listen_button: Button
var _reset_all: Button
var _reset_armed_at := -10.0


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud.style(Color(0.07, 0.06, 0.12, 0.97)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-540, -370)
	panel.custom_minimum_size = Vector2(1080, 740)
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var title := Hud._label(v, "PARAMÈTRES", 30, ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_font_size_override("font_size", 17)
	v.add_child(_tabs)
	_build_game_tab()
	_build_combat_tab()
	_build_keys_tab()
	_build_display_tab()
	_build_audio_tab()
	_build_camera_tab()
	_status = Hud._label(v, "", 14, Color(0.6, 1.0, 0.65))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 16)
	v.add_child(bottom)
	_reset_all = _button(bottom, "Tout réinitialiser", _on_reset_all, 300)
	_button(bottom, "Fermer", close, 220)
	_root.visible = false
	add_child(_root)
	Settings.changed.connect(_refresh)


func open(tab := -1) -> void:
	if tab >= 0:
		_tabs.current_tab = tab
	_status.text = ""
	_refresh()
	_root.visible = true


func close() -> void:
	_stop_listening()
	_root.visible = false
	closed.emit()


func is_open() -> bool:
	return _root.visible


func _process(_delta: float) -> void:
	if _reset_armed_at > 0.0 and Time.get_ticks_msec() / 1000.0 - _reset_armed_at > 4.0:
		_reset_armed_at = -10.0
		_reset_all.text = "Tout réinitialiser"


func _refresh() -> void:
	for r in _refreshers:
		r.call()


# --- onglet Mode de jeu ----------------------------------------------------------------
func _build_game_tab() -> void:
	var v := _tab("Mode de jeu")
	_section(v, "Modes de jeu prêts à l'emploi")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for id in Settings.PRESETS:
		var p: Dictionary = Settings.PRESETS[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(330, 96)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		var lbl := Label.new()
		lbl.text = "%s\n%s" % [p.name, p.desc]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.offset_left = 10
		lbl.offset_right = -10
		lbl.offset_top = 6
		lbl.offset_bottom = -6
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lbl)
		b.pressed.connect(func():
			Settings.apply_preset(id)
			_say("Mode « %s » activé" % p.name))
		grid.add_child(b)
		var normal := Hud.style(Color(0.12, 0.1, 0.2, 0.95))
		var chosen := Hud.style(Color(0.2, 0.15, 0.3, 1.0))
		chosen.border_color = ACCENT
		chosen.set_border_width_all(3)
		b.add_theme_stylebox_override("hover", Hud.style(Color(0.22, 0.18, 0.34)))
		_refreshers.append(func():
			var on: bool = Settings.current_preset() == id
			b.add_theme_stylebox_override("normal", chosen if on else normal)
			lbl.add_theme_color_override("font_color", ACCENT if on else Color(0.92, 0.92, 0.96)))
	_section(v, "Réglages détaillés")
	_option(v, "Déplacement", "game", "move_mode", [
		["keyboard", "Clavier (ZQSD / flèches)"], ["click", "Souris : clic gauche (maintenu = suivre le curseur)"],
		["rts", "Souris : clic droit (style RTS / MOBA)"]])
	_option(v, "Visée des attaques et compétences", "game", "aim_mode", [
		["smart", "Intelligente : cible verrouillée, sinon curseur, sinon monstre proche"],
		["cursor", "Suit le curseur : le héros regarde toujours la souris"],
		["action", "Action : vue de dos, la caméra tourne vers le curseur"],
		["nearest", "Monstre le plus proche"]])
	var info := _note(v, "")
	_refreshers.append(func():
		var lines: PackedStringArray = []
		match Settings.move_mode():
			"click":
				lines.append("Clic gauche sur le sol : se déplacer (maintenu : suivre le curseur). Clic sur un monstre : l'attaquer. Les touches de déplacement marchent toujours.")
			"rts":
				lines.append("Clic droit sur le sol : se déplacer. Clic droit sur un monstre : l'attaquer. Clic gauche : attaquer vers le curseur. La caméra tourne au clic molette.")
			_:
				lines.append("Touches de déplacement + clic gauche pour attaquer (sur un monstre : auto-attaque).")
		if Settings.aim_mode() == "cursor":
			lines.append("Visée au curseur : attaques et compétences partent toujours vers la souris (le clic ne verrouille plus de cible).")
		elif Settings.aim_mode() == "action":
			lines.append("Mode action : le héros regarde le curseur ; écarte le curseur à gauche ou à droite et la caméra tourne derrière lui (plus le curseur est loin du centre, plus elle tourne vite). Molette : zoom du plan rapproché à la vue large.")
		info.text = "\n".join(lines))


# --- onglet Combat ---------------------------------------------------------------------
func _build_combat_tab() -> void:
	var v := _tab("Combat")
	_section(v, "Attaque de base")
	_option(v, "Mode d'attaque", "game", "attack_mode", [
		["manual", "Manuel : clic pour attaquer"], ["auto", "Automatique : frappe seul les monstres au contact"]])
	_note(v, "Automatique : quand tu ne te déplaces pas, le héros frappe le monstre le plus proche à portée. Se déplacer arrête l'attaque (pour esquiver).")
	_section(v, "Compétences automatiques")
	_note(v, "Une compétence en AUTO (clique sur son bouton) se lance toute seule dès qu'elle est rechargée et qu'un monstre est à sa portée (« AUTO » sur la barre). Les autres restent au clavier.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	for i in 4:
		var c := _toggle_button(230)
		c.toggled.connect(func(on): Settings.set_auto_skill(i, on))
		row.add_child(c)
		_refreshers.append(func():
			var on := Settings.auto_skill(i)
			c.set_pressed_no_signal(on)
			c.text = "%d (%s) : %s" % [i + 1, Settings.action_label("skill_%d" % (i + 1), 1), "AUTO" if on else "manuel"])
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	_button(buttons, "Toutes en automatique", func(): Settings.set_v("game", "auto_skills", [true, true, true, true]), 260)
	_button(buttons, "Toutes en manuel", func(): Settings.set_v("game", "auto_skills", [false, false, false, false]), 260)
	_option(v, "Cible des compétences automatiques", "game", "auto_target", [
		["any", "N'importe quel monstre à portée"], ["locked", "Seulement la cible verrouillée (clic sur un monstre)"]])


# --- onglet Touches --------------------------------------------------------------------
func _build_keys_tab() -> void:
	var v := _tab("Touches", false)
	_note(v, "Clique sur une case puis appuie sur une touche ou un bouton de souris.  Échap : annuler  ·  Suppr / Retour : effacer.  Une touche déjà prise est retirée de l'autre action.")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	for a in Settings.ACTIONS:
		var action: String = a[0]
		var name_lbl := Hud._label(grid, a[1], 16, Color(0.92, 0.92, 0.96))
		name_lbl.custom_minimum_size = Vector2(LABEL_W + 40, 0)
		for idx in 2:
			var b := Button.new()
			b.custom_minimum_size = Vector2(250, 36)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 15)
			b.add_theme_stylebox_override("normal", Hud.style(Color(0.12, 0.1, 0.2, 0.95)))
			b.add_theme_stylebox_override("hover", Hud.style(Color(0.22, 0.18, 0.34)))
			b.pressed.connect(_start_listening.bind(action, idx, b))
			grid.add_child(b)
			_refreshers.append(func():
				if b == _listen_button:
					return
				var list: Array = Settings.binds.get(action, [])
				b.text = Settings.event_label(list[idx]) if idx < list.size() else "—")
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	_button(h, "Touches par défaut", func():
		Settings.reset_bindings()
		_say("Touches par défaut rétablies"), 280)


func _start_listening(action: String, idx: int, b: Button) -> void:
	_stop_listening()
	_listen_action = action
	_listen_idx = idx
	_listen_button = b
	b.text = "Appuie sur une touche…"
	b.add_theme_color_override("font_color", ACCENT)


func _stop_listening() -> void:
	if _listen_button:
		_listen_button.remove_theme_color_override("font_color")
	_listen_button = null
	_listen_action = ""
	_refresh()


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if _listen_action != "":
		var key := event as InputEventKey
		if key and key.pressed and not key.echo:
			get_viewport().set_input_as_handled()
			if key.physical_keycode == KEY_ESCAPE:
				_stop_listening()
				return
			if key.physical_keycode in [KEY_DELETE, KEY_BACKSPACE]:
				Settings.unbind(_listen_action, _listen_idx)
				_stop_listening()
				return
			_assign(event)
		elif event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			_assign(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.is_action("pause") or event.physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close()


func _assign(event: InputEvent) -> void:
	var e := Settings.describe_event(event)
	if e.is_empty():
		return
	var action := _listen_action
	var idx := _listen_idx
	_listen_button.remove_theme_color_override("font_color")
	_listen_button = null
	_listen_action = ""
	var lost := Settings.bind(action, idx, e)
	var msg := "%s : %s" % [Settings.action_name(action), Settings.event_label(e)]
	if not lost.is_empty():
		msg += "   (retiré de : %s)" % ", ".join(lost)
	_say(msg)


# --- onglet Affichage ------------------------------------------------------------------
func _build_display_tab() -> void:
	var v := _tab("Affichage")
	_option(v, "Mode de fenêtre", "display", "window_mode", [
		["windowed", "Fenêtré"], ["maximized", "Fenêtré agrandi"],
		["fullscreen", "Plein écran (fenêtre sans bordure)"], ["exclusive", "Plein écran exclusif"]])
	var res := _option(v, "Résolution (mode fenêtré)", "display", "resolution",
		Settings.RESOLUTIONS.map(func(r): return [r, r.replace("x", " × ")]))
	_refreshers.append(func(): res.disabled = Settings.get_v("display", "window_mode") != "windowed")
	_check(v, "Synchronisation verticale (VSync)", "display", "vsync")
	_option(v, "Limite d'images par seconde", "display", "max_fps", [
		[0, "Illimitée"], [30, "30"], [60, "60"], [120, "120"], [144, "144"], [165, "165"], [240, "240"]])
	_option(v, "Qualité graphique", "display", "quality", [["low", "Basse (PC modeste)"], ["medium", "Moyenne"],
		["high", "Haute"], ["ultra", "Ultra"]])
	_option(v, "Anticrénelage (MSAA)", "display", "msaa", [[0, "Désactivé"], [2, "2×"], [4, "4×"], [8, "8×"]])
	_option(v, "Taille de l'interface", "display", "ui_scale", [
		[0.75, "75 %"], [0.85, "85 %"], [1.0, "100 %"], [1.1, "110 %"], [1.25, "125 %"], [1.5, "150 %"]])


# --- onglet Son ------------------------------------------------------------------------
func _build_audio_tab() -> void:
	var v := _tab("Son")
	_slider(v, "Volume général", "audio", "master", 0.0, 1.0, 0.05, func(x): return "%d %%" % roundi(x * 100))
	_slider(v, "Effets sonores", "audio", "sfx", 0.0, 1.0, 0.05, func(x): return "%d %%" % roundi(x * 100))


# --- onglet Caméra et interface ----------------------------------------------------------
func _build_camera_tab() -> void:
	var v := _tab("Caméra & interface")
	_section(v, "Caméra")
	_slider(v, "Sensibilité de rotation", "camera", "rotate_speed", 0.25, 3.0, 0.05, func(x): return "× %.2f" % x)
	_check(v, "Inverser l'inclinaison (haut / bas)", "camera", "invert_y")
	_slider(v, "Distance de départ (zoom)", "camera", "distance", 7.0, 28.0, 1.0, func(x): return "%d m" % roundi(x))
	_slider(v, "Tremblements de l'écran", "camera", "shake", 0.0, 1.5, 0.05, func(x): return "%d %%" % roundi(x * 100))
	_slider(v, "Mode action : vitesse de rotation au curseur", "camera", "action_turn", 0.3, 2.5, 0.05, func(x): return "%d %%" % roundi(x * 100))
	_section(v, "Interface et ressenti")
	_option(v, "Chiffres de dégâts", "interface", "damage_numbers", [
		["all", "Tous"], ["dealt", "Seulement les dégâts infligés"], ["crit", "Coups critiques et dégâts subis"], ["off", "Masqués"]])
	_check(v, "Arrêt sur image à l'impact (poids des coups)", "interface", "hit_stop")
	_check(v, "Afficher les FPS", "interface", "show_fps")
	_check(v, "Marqueur au sol des clics de déplacement", "interface", "move_marker")
	_check(v, "Zone de mes attaques au sol (en bleu, pour apprendre la portée des sorts)", "interface", "attack_zone")
	_check(v, "Mode dev (F10 : objets, ressources, progression, actions en run — pour tester)", "interface", "dev_mode")


# --- briques d'interface ---------------------------------------------------------------
func _tab(title: String, scroll := true) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.name = title
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	_tabs.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	if scroll:
		var sc := ScrollContainer.new()
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		margin.add_child(sc)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(v)
	else:
		margin.add_child(v)
	return v


func _section(parent: Control, text: String) -> void:
	Hud._label(parent, text, 19, ACCENT)


func _note(parent: Control, text: String) -> Label:
	var l := Hud._label(parent, text, 14, Color(0.8, 0.8, 0.88))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1000, 0)
	return l


func _row(parent: Control, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	parent.add_child(h)
	var l := Hud._label(h, text, 16, Color(0.92, 0.92, 0.96))
	l.custom_minimum_size = Vector2(LABEL_W, 0)
	return h


func _option(parent: Control, text: String, section: String, key: String, choices: Array) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(560, 34)
	o.focus_mode = Control.FOCUS_NONE
	o.add_theme_font_size_override("font_size", 15)
	for c in choices:
		o.add_item(String(c[1]))
	o.item_selected.connect(func(i): Settings.set_v(section, key, choices[i][0]))
	_row(parent, text).add_child(o)
	_refreshers.append(func():
		var cur: Variant = Settings.get_v(section, key)
		for i in choices.size():
			if typeof(choices[i][0]) == typeof(cur) and choices[i][0] == cur or (cur is float and is_equal_approx(float(choices[i][0]), cur)):
				o.select(i))
	return o


func _check(parent: Control, text: String, section: String, key: String) -> Button:
	var c := _toggle_button(200)
	c.toggled.connect(func(on): Settings.set_v(section, key, on))
	_row(parent, text).add_child(c)
	_refreshers.append(func():
		var on := bool(Settings.get_v(section, key))
		c.set_pressed_no_signal(on)
		c.text = "✔  Activé" if on else "Désactivé")
	return c


## Bouton bascule bien lisible (vert si activé).
func _toggle_button(width: int) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(width, 34)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	var off := Hud.style(Color(0.14, 0.12, 0.2, 0.95))
	off.border_color = Color(0.5, 0.5, 0.6, 0.6)
	off.set_border_width_all(1)
	var on := Hud.style(Color(0.16, 0.36, 0.2, 1.0))
	on.border_color = Color(0.55, 1.0, 0.6)
	on.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", off)
	b.add_theme_stylebox_override("hover", Hud.style(Color(0.22, 0.18, 0.34)))
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_pressed_color", Color(0.75, 1.0, 0.78))
	b.add_theme_color_override("font_hover_pressed_color", Color(0.75, 1.0, 0.78))
	return b


func _slider(parent: Control, text: String, section: String, key: String, lo: float, hi: float, step: float, fmt: Callable) -> HSlider:
	var h := _row(parent, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size = Vector2(420, 28)
	s.focus_mode = Control.FOCUS_NONE
	h.add_child(s)
	var val := Hud._label(h, "", 15, ACCENT)
	s.value_changed.connect(func(x):
		val.text = fmt.call(x)
		Settings.set_v(section, key, x))
	_refreshers.append(func():
		s.set_value_no_signal(float(Settings.get_v(section, key)))
		val.text = fmt.call(s.value))
	return s


func _button(parent: Control, text: String, cb: Callable, width := 250) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 42)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", Hud.style(Color(0.16, 0.12, 0.26, 0.95)))
	b.add_theme_stylebox_override("hover", Hud.style(Color(0.28, 0.2, 0.42, 1.0)))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _say(text: String) -> void:
	_status.text = text


## 2 clics en 4 s : tous les paramètres (touches comprises) reviennent par défaut.
func _on_reset_all() -> void:
	if _reset_armed_at < 0.0:
		_reset_armed_at = Time.get_ticks_msec() / 1000.0
		_reset_all.text = "Confirmer : tout réinitialiser ?"
		return
	_reset_armed_at = -10.0
	_reset_all.text = "Tout réinitialiser"
	Settings.reset_all()
	_say("Tous les paramètres sont revenus par défaut")
