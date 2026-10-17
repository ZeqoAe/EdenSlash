class_name SettingsMenu
extends PageScreen
## Paramètres (lobby, écran titre et menu pause), plein écran dans le même cadre que le Carnet :
## six pages à onglets (mode de jeu, combat, touches, affichage, son, caméra et interface).
## Chaque ligne est un titre à gauche et un contrôle à droite (interrupteur à glissière, liste, curseur) ;
## le détail d'un réglage s'affiche dans le cadre fixe du bas quand on le survole (ou que le cadre
## manette est dessus). Chaque changement est appliqué et sauvegardé tout de suite (Settings).

const ACCENT := UiTheme.GOLD
const TEXT := Color(0.95, 0.93, 0.98)
const COL_W := 1180  # largeur de la colonne de réglages
const KEY_W := 230  # largeur d'une case de touche
const OPTION_W := 460
const ROW_H := 46
const HINT_DEFAULT := "Survole un réglage pour en savoir plus."

var _refreshers: Array[Callable] = []
var _switches: Array[UiTheme.Switch] = []
var _hinted: Array[Control] = []  # lignes, cartes et boutons qui portent une infobulle (meta « hint »)
var _hot: Control
var _hint_shown := "\u0001"
var _page_hints: Array[String] = []
var _page_actions: Array[Control] = []
var _footer_actions: HBoxContainer
var _hint: Label
var _status: Label
var _status_t := 0.0
var _listen_action := ""
var _listen_idx := -1
var _listen_button: Button
var _reset_all: Button
var _reset_armed_at := -10.0
var _tester: Label
var _pad_listen := ""  # action de manette en cours d'assignation
var _pad_buttons := {}
var _pad_listen_id := 0

## Touches rangées en quatre groupes.
const KEY_GROUPS := [
	["Déplacement", ["move_forward", "move_back", "move_left", "move_right", "jump", "dodge"]],
	["Combat", ["attack", "move_order", "swap_weapon", "potion_1", "potion_2"]],
	["Sorts", ["skill_1", "skill_2", "skill_3", "skill_4"]],
	["Interface", ["interact", "map", "objectives", "journal", "pause", "camera_rotate", "unstuck", "help", "feedback", "extract", "quick_equip"]],
]


func _init() -> void:
	super("Paramètres", 30)


func _ready() -> void:
	super._ready()
	page_changed.connect(_on_page_changed)
	Settings.changed.connect(_refresh)
	# P2 : 825 nœuds et ~100 ms : les pages se construisent une par image pendant que l'écran s'affiche (ou d'un coup,
	# à l'ouverture, si le joueur n'attend pas) au lieu de figer le chargement du titre, du lobby et de la run.
	_build_steps = [_build_footer, _build_game_page, _build_combat_page, _build_keys_page, _build_display_page,
		_build_audio_page, _build_camera_page]


var _build_steps: Array[Callable] = []
var _build_next := 0


func _build_one() -> void:
	if _build_next < _build_steps.size():
		var step := _build_steps[_build_next]
		_build_next += 1
		step.call()


## Termine la construction des pages (appelé avant tout accès aux pages).
func ensure_built() -> void:
	while _build_next < _build_steps.size():
		_build_one()


func page_count() -> int:
	ensure_built()
	return super.page_count()


func page(i: int) -> Control:
	ensure_built()
	return super.page(i)


func show_page(i: int) -> void:
	ensure_built()
	super.show_page(i)


func step_page(delta: int) -> void:
	ensure_built()
	super.step_page(delta)


func open(tab := -1) -> void:
	ensure_built()
	_say("")
	super.open(tab)
	_refresh()
	for s in _switches:
		s.set_on(s.button_pressed)  # position de départ sans animation


func close() -> void:
	close_ui()


func close_ui() -> void:
	_stop_listening()
	_stop_pad_listening()
	if _hot != null and is_instance_valid(_hot) and _hot.has_meta("row_panel"):
		(_hot as PanelContainer).add_theme_stylebox_override("panel", _row_box(false))
	_hot = null
	super.close_ui()


func _process(delta: float) -> void:
	if _build_next < _build_steps.size():
		_build_one()  # une page par image (voir _ready)
	if _reset_armed_at > 0.0 and Time.get_ticks_msec() / 1000.0 - _reset_armed_at > 4.0:
		_reset_armed_at = -10.0
		_reset_all.text = "Tout réinitialiser"
	if not is_open():
		return
	if _status_t > 0.0:
		_status_t -= delta
		if _status_t <= 0.0:
			_status.text = ""
			_status.visible = false
	_update_hot()


func _refresh() -> void:
	for r in _refreshers:
		r.call()
	_hint_shown = "\u0001"  # l'infobulle dynamique est relue


func _on_page_changed(i: int) -> void:
	for k in _page_actions.size():
		if _page_actions[k] != null:
			_page_actions[k].visible = k == i
	_hint_shown = "\u0001"


# --- cadre du bas : infobulle fixe, état et actions ------------------------------------------------------
func _build_footer() -> void:
	var v: VBoxContainer = _content.get_parent()
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	foot.custom_minimum_size = Vector2(0, 76)
	v.add_child(foot)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.92), Color(UiTheme.GOLD_DIM, 0.55), 1, 10, false)
	box.content_margin_left = 16
	box.content_margin_right = 16
	panel.add_theme_stylebox_override("panel", box)
	foot.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 0)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(pv)
	_status = _text(pv, "", 15, Color(0.6, 1.0, 0.65))
	_status.visible = false
	_hint = _text(pv, "", 15, UiTheme.MUTED)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(300, 0)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.alignment = BoxContainer.ALIGNMENT_END
	foot.add_child(actions)
	_footer_actions = actions
	_reset_all = _button(actions, "Tout réinitialiser", _on_reset_all, 230)
	var gap := Control.new()  # marge sous le pied : la barre d'aide manette y est posée
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)



## Boutons propres à une page, dans le pied (visibles seulement sur cette page).
func _page_buttons(page: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_footer_actions.add_child(h)
	_footer_actions.move_child(h, 0)
	while _page_actions.size() <= page:
		_page_actions.append(null)
	_page_actions[page] = h
	h.visible = false
	return h


## Ligne ou contrôle sous le pointeur (ou sous le cadre manette) : son détail s'affiche dans le pied.
func _update_hot() -> void:
	var hot: Control = null
	if Gamepad.active and UiNav.shown and UiNav.cursor != null and is_instance_valid(UiNav.cursor) and is_ancestor_of(UiNav.cursor):
		hot = _hinted_parent(UiNav.cursor)
	else:
		var mouse := get_viewport().get_mouse_position()
		if _content.get_global_rect().has_point(mouse):
			for c in _hinted:
				if c.is_visible_in_tree() and c.get_global_rect().has_point(mouse):
					hot = c
					break
	if hot != _hot:
		if _hot != null and is_instance_valid(_hot) and _hot.has_meta("row_panel"):
			(_hot as PanelContainer).add_theme_stylebox_override("panel", _row_box(false))
		_hot = hot
		if _hot != null and _hot.has_meta("row_panel"):
			(_hot as PanelContainer).add_theme_stylebox_override("panel", _row_box(true))
	var text := ""
	if _hot != null:
		var h: Variant = _hot.get_meta("hint")
		text = String(h.call()) if h is Callable else String(h)
	elif current_page() < _page_hints.size():
		text = _page_hints[current_page()]
	if text != _hint_shown:
		_hint_shown = text
		_hint.text = text


func _hinted_parent(c: Node) -> Control:
	var n := c
	while n != null and n != self:
		if n is Control and (n as Control).has_meta("hint"):
			return n as Control
		n = n.get_parent()
	return null


func _say(text: String) -> void:
	_status.text = text
	_status.visible = text != ""
	_status_t = 4.0 if text != "" else 0.0


## 2 clics en 4 s : tous les paramètres (touches comprises) reviennent par défaut.
func _on_reset_all() -> void:
	if _reset_armed_at < 0.0:
		_reset_armed_at = Time.get_ticks_msec() / 1000.0
		_reset_all.text = "Confirmer ?"
		return
	_reset_armed_at = -10.0
	_reset_all.text = "Tout réinitialiser"
	Settings.reset_all()
	_say("Tous les paramètres sont revenus par défaut")


# --- page Mode de jeu ------------------------------------------------------------------------------------
func _build_game_page() -> void:
	var v := _page("Mode de jeu", HINT_DEFAULT)
	_section(v, "Modes prêts à l'emploi")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for id in Settings.PRESETS:
		var p: Dictionary = Settings.PRESETS[id]
		var b := Button.new()
		b.text = String(p.name)
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 17)
		b.set_meta("hint", String(p.desc))
		_hinted.append(b)
		b.pressed.connect(func():
			Settings.apply_preset(id)
			_say("Mode « %s » activé" % p.name))
		grid.add_child(b)
		var normal := UiTheme.flat_box(Color(0.12, 0.1, 0.2, 0.95), Color(0.5, 0.48, 0.6, 0.7), 1, 10, false)
		var chosen := UiTheme.flat_box(Color(0.3, 0.22, 0.1, 1.0), ACCENT, 3, 10, false)
		b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.22, 0.18, 0.34), ACCENT, 1, 10, false))
		_refreshers.append(func():
			var on: bool = Settings.current_preset() == id
			b.add_theme_stylebox_override("normal", chosen if on else normal)
			b.add_theme_color_override("font_color", ACCENT if on else TEXT))
	_section(v, "Réglages détaillés")
	_option(v, "Déplacement", "game", "move_mode", [
		["keyboard", "Clavier (ZQSD / flèches)", "Touches de déplacement, clic gauche pour attaquer (sur un monstre : auto-attaque)."],
		["click", "Souris : clic gauche", "Clic gauche sur le sol : se déplacer (maintenu : suivre le curseur). Clic sur un monstre : l'attaquer. Les touches de déplacement marchent toujours."],
		["rts", "Souris : clic droit (RTS / MOBA)", "Clic droit sur le sol : se déplacer ; sur un monstre : l'attaquer. Clic gauche : attaquer vers le curseur. Caméra au clic molette."]])
	_option(v, "Visée des attaques et sorts", "game", "aim_mode", [
		["smart", "Intelligente", "Cible verrouillée, sinon curseur, sinon monstre le plus proche."],
		["cursor", "Suit le curseur", "Attaques et compétences partent toujours vers la souris : le clic ne verrouille plus de cible."],
		["action", "Action (vue de dos)", "Le héros regarde le curseur ; écarte-le à gauche ou à droite et la caméra tourne derrière lui, d'autant plus vite que le curseur est loin du centre. Molette : zoom."],
		["nearest", "Monstre le plus proche", "Le héros vise toujours le monstre le plus proche."]])


func _assist_hint() -> String:
	var cur := Settings.assist_level()
	return String(Settings.ASSIST[cur].desc) if Settings.ASSIST.has(cur) else "Personnalisée : tes réglages ne correspondent à aucun niveau."


# --- page Combat -----------------------------------------------------------------------------------------
func _build_combat_page() -> void:
	var v := _page("Combat", HINT_DEFAULT)
	_section(v, "Aide au combat")
	var lv := _row(v, "Niveau d'aide", _assist_hint)
	for id in Settings.ASSIST:
		var b := _button(lv, String(Settings.ASSIST[id].name), func():
			Settings.set_assist(id)
			_refresh(), 150)
		b.toggle_mode = true
		b.add_theme_stylebox_override("pressed", UiTheme.flat_box(Color(0.32, 0.23, 0.12, 1.0), ACCENT, 2, 8, false))
		b.add_theme_stylebox_override("hover_pressed", UiTheme.flat_box(Color(0.38, 0.27, 0.14, 1.0), ACCENT, 2, 8, false))
		_refreshers.append(func(): b.set_pressed_no_signal(Settings.assist_level() == id))
	_section(v, "Attaque de base")
	_option(v, "Mode d'attaque", "game", "attack_mode", [
		["manual", "Manuel (clic)", "Tu attaques en cliquant."],
		["auto", "Automatique (au contact)", "Quand tu ne te déplaces pas, le héros frappe le monstre le plus proche à portée. Se déplacer arrête l'attaque, pour esquiver."]])
	_section(v, "Compétences automatiques")
	var cells := _row(v, "Cases en automatique", "Une compétence en AUTO se lance seule dès qu'elle est rechargée et qu'un monstre est à portée. Les autres restent au clavier.")
	cells.add_theme_constant_override("separation", 34)
	for i in 4:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 8)
		cells.add_child(cell)
		var name_lbl := _text(cell, "", 16, TEXT)
		name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var sw := _switch()
		sw.toggled.connect(func(on): Settings.set_auto_skill(i, on))
		cell.add_child(sw)
		_refreshers.append(func():
			sw.set_pressed_no_signal(Settings.auto_skill(i))
			var key := Settings.action_label("skill_%d" % (i + 1), 1)
			name_lbl.text = "Case %d" % (i + 1) if key == str(i + 1) else "Case %d · %s" % [i + 1, key])  # touche par défaut : pas de doublon
	var all := _row(v, "Toutes les cases")
	_button(all, "En automatique", func(): Settings.set_v("game", "auto_skills", [true, true, true, true]), 200)
	_button(all, "En manuel", func(): Settings.set_v("game", "auto_skills", [false, false, false, false]), 200)
	_option(v, "Cible des compétences auto", "game", "auto_target", [
		["any", "Tout monstre à portée", "La compétence part sur n'importe quel monstre à portée."],
		["locked", "Cible verrouillée seulement", "La compétence ne part que sur le monstre sur lequel tu as cliqué."]])
	_section(v, "Prise en main")
	_check(v, "Mémoire des touches", "game", "key_memory",
		"Jusqu'à 3 appuis de sorts sont gardés et joués dans l'ordre : taper 1-2-3 pendant un sort les lance l'un après l'autre. L'esquive et le saut partent tout de suite et vident la mémoire.")
	_check(v, "Tenir une touche enchaîne le sort", "game", "hold_chain",
		"Garder la touche d'une case enfoncée donne toute la chaîne du sort.")
	_check(v, "Anneau d'annulation parfaite", "interface", "perfect_hint",
		"Un anneau bleu annonce le bon moment pour esquiver après un impact de sort (annulation parfaite : recharge réduite). Il n'apparaît jamais en Duel.")
	_section(v, "Jeu automatique")
	_check(v, "Sorts et enchaînements automatiques", "game", "auto_combo",
		"Les 4 sorts de ta barre partent seuls dès qu'ils sont prêts et qu'un monstre est à portée. L'annulation parfaite reste un geste à faire toi-même. Pas dans les duels de la Tour ni en Duel.")
	_check(v, "Déplacement automatique", "game", "auto_move",
		"Le héros va seul vers les monstres (à distance de tir pour un archer ou un mage), puis vers l'objectif, et ouvre coffres et passages. Te déplacer toi-même reprend la main.")
	_check(v, "Choix des cartes automatique", "game", "auto_cards",
		"À chaque choix : un nouveau sort tant qu'une case de la barre est libre, sinon la carte la plus rare. Avec les trois options, le jeu se joue tout seul.")


# --- page Touches ----------------------------------------------------------------------------------------
func _build_keys_page() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(28, 18))
	var idx := add_page("Touches", panel)
	_page_hints.append("Clique sur une case, puis appuie sur une touche ou un bouton de souris. Échap : annuler · Suppr : effacer. Une touche déjà prise est retirée de l'autre action.")
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	panel.add_child(h)
	# groupes : un bouton chacun, à gauche (la croix gauche d'une touche y mène)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.custom_minimum_size = Vector2(230, 0)
	h.add_child(side)
	_section(side, "Groupes")
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 8)
	h.add_child(main)
	_tester = _text(main, "Test : appuie sur une touche pour voir l'action qu'elle déclenche.", 16, ACCENT)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	scroll.add_child(col)
	var order: Array = []
	for g in KEY_GROUPS:
		order.append(["#", g[0]])
		for aid in g[1]:
			for a in Settings.ACTIONS:
				if a[0] == aid:
					order.append(a)
	for a in Settings.ACTIONS:  # une action oubliée des groupes reste visible
		if not order.any(func(o): return o[0] == a[0]):
			order.append(a)
	var chip: Button
	var first_key: Button
	for a in order:
		if String(a[0]) == "#":
			var header := _group_header(col, String(a[1]))
			chip = _group_chip(side, scroll, header, String(a[1]))
			first_key = null
			continue
		var action: String = a[0]
		var row := _row(col, String(a[1]))
		for i in 2:
			var b := _key_button(row)
			b.pressed.connect(_start_listening.bind(action, i, b))
			if i == 0:
				b.set_meta("nav_left", chip)  # croix gauche : retour au groupe
				if first_key == null:
					first_key = b
					chip.set_meta("nav_right", b)
			var slot := i
			_refreshers.append(func():
				if b == _listen_button:
					return
				var list: Array = Settings.binds.get(action, [])
				b.text = Settings.event_label(list[slot]) if slot < list.size() else "—")
	# manette
	var pad_header := _group_header(col, "Manette")
	var pad_chip := _group_chip(side, scroll, pad_header, "Manette")
	_text(col, "Déplacement : stick gauche (fixe) · caméra : stick droit.", 15, UiTheme.MUTED)
	_option(col, "Noms des boutons", "interface", "pad_labels", [
		["auto", "Automatique"], ["xbox", "Xbox (A B X Y)"], ["ps", "PlayStation"]])
	var pad_first: Button = null
	for a in Settings.PAD_ACTIONS:
		var action: String = a
		var row := _row(col, Settings.action_name(action))
		var b := _key_button(row)
		b.pressed.connect(_start_pad_listening.bind(action, b))
		b.set_meta("nav_left", pad_chip)
		if pad_first == null:
			pad_first = b
			pad_chip.set_meta("nav_right", b)
		_pad_buttons[action] = b
		_refreshers.append(func():
			if _pad_listen != action:
				b.text = Settings.pad_action_label(action))
	# pied : remises à zéro de cette page
	var acts := _page_buttons(idx)
	_button(acts, "Touches par défaut", func():
		Settings.reset_bindings()
		_say("Touches par défaut rétablies"), 230)
	_button(acts, "Manette par défaut", func():
		Settings.reset_pad_bindings()
		_say("Manette par défaut rétablie"), 230)


func _group_header(parent: Control, text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	box.add_child(gap)
	var l := _text(box, text, 20, ACCENT)
	l.add_theme_font_override("font", UiTheme.bold_font())
	var line := ColorRect.new()
	line.color = Color(UiTheme.GOLD_DIM, 0.45)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)
	return box


## Bouton de groupe : fait défiler la liste jusqu'à l'en-tête du groupe.
func _group_chip(parent: Control, scroll: ScrollContainer, header: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 17)
	_neutral(b)
	b.pressed.connect(func(): scroll.scroll_vertical = int(header.position.y))
	parent.add_child(b)
	return b


func _key_button(row: Control) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(KEY_W, 38)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.12, 0.1, 0.2, 0.95), Color(0.5, 0.48, 0.6, 0.7), 1, 8, false))
	row.add_child(b)
	return b


func _start_pad_listening(action: String, b: Button) -> void:
	_stop_listening()
	_pad_listen = action
	_pad_listen_id += 1
	var my_id := _pad_listen_id
	b.text = "Appuie sur un bouton…"
	b.add_theme_color_override("font_color", ACCENT)
	# sans appui, l'écoute s'arrête toute seule (pas besoin de clavier pour annuler)
	get_tree().create_timer(6.0).timeout.connect(func():
		if _pad_listen == action and _pad_listen_id == my_id:
			_stop_pad_listening())


func _stop_pad_listening() -> void:
	if _pad_listen != "":
		var b: Button = _pad_buttons.get(_pad_listen)
		if b:
			b.remove_theme_color_override("font_color")
		_pad_listen = ""
		_refresh()


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
	if not is_open():
		return
	if _pad_listen != "":
		var d := Settings.describe_pad(event)
		if not d.is_empty():
			get_viewport().set_input_as_handled()
			var lost := Settings.pad_bind(_pad_listen, d)
			var act := _pad_listen
			_stop_pad_listening()
			_say("%s : %s%s" % [Settings.action_name(act), Settings.pad_label(d), (" (retiré de : %s)" % ", ".join(lost)) if not lost.is_empty() else ""])
		elif event is InputEventKey and event.pressed:
			get_viewport().set_input_as_handled()
			_stop_pad_listening()
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
	if _tester != null and _tester.is_visible_in_tree() and (event is InputEventKey or event is InputEventMouseButton) and event.pressed \
			and not (event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_ESCAPE):
		var hits: PackedStringArray = []
		for a in Settings.ACTIONS:
			if event.is_action_pressed(a[0]):
				hits.append(String(a[1]))
		_tester.text = "Test : cette touche déclenche « %s »." % " / ".join(hits) if not hits.is_empty() else "Test : cette touche n'est liée à aucune action."
	super._input(event)  # Échap : ferme


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


# --- page Affichage --------------------------------------------------------------------------------------
func _build_display_page() -> void:
	var v := _page("Affichage", HINT_DEFAULT)
	_section(v, "Fenêtre")
	_option(v, "Mode de fenêtre", "display", "window_mode", [
		["windowed", "Fenêtré"], ["maximized", "Fenêtré agrandi"],
		["fullscreen", "Plein écran (sans bordure)"], ["exclusive", "Plein écran exclusif"]])
	var res := _option(v, "Résolution (mode fenêtré)", "display", "resolution",
		Settings.RESOLUTIONS.map(func(r): return [r, r.replace("x", " × ")]))
	_refreshers.append(func(): res.disabled = Settings.get_v("display", "window_mode") != "windowed")
	_check(v, "Synchronisation verticale (VSync)", "display", "vsync", "Évite les déchirures d'image ; peut ajouter un léger délai.")
	_option(v, "Limite d'images par seconde", "display", "max_fps", [
		[0, "Illimitée"], [30, "30"], [60, "60"], [120, "120"], [144, "144"], [165, "165"], [240, "240"]])
	_section(v, "Image")
	_option(v, "Qualité graphique", "display", "quality", [["low", "Basse (PC modeste)"], ["medium", "Moyenne"],
		["high", "Haute"], ["ultra", "Ultra"]])
	_option(v, "Anticrénelage (MSAA)", "display", "msaa", [[0, "Désactivé"], [2, "2×"], [4, "4×"], [8, "8×"]])
	_option(v, "Taille de l'interface", "display", "ui_scale", [
		[0.75, "75 %"], [0.85, "85 %"], [1.0, "100 %"], [1.1, "110 %"], [1.25, "125 %"], [1.5, "150 %"]])
	# lot HUB-1, P0-9 : le HUD en partie a sa propre taille et son opacité (les menus gardent la taille de l'interface)
	_section(v, "HUD en partie")
	_slider(v, "Taille du HUD", "interface", "hud_scale", 0.8, 1.4, 0.05, func(x): return "%d %%" % roundi(x * 100),
		"Agrandit ou réduit tout le HUD en partie (vie, sorts, objectifs, mini-carte), sans toucher aux menus.")
	_slider(v, "Opacité du HUD", "interface", "hud_opacity", 0.4, 1.0, 0.05, func(x): return "%d %%" % roundi(x * 100),
		"Plus bas, le HUD laisse mieux voir le combat derrière lui.")


# --- page Son --------------------------------------------------------------------------------------------
func _build_audio_page() -> void:
	var v := _page("Son")
	_section(v, "Volumes")
	_slider(v, "Volume général", "audio", "master", 0.0, 1.0, 0.05, func(x): return "%d %%" % roundi(x * 100))
	_slider(v, "Effets sonores", "audio", "sfx", 0.0, 1.0, 0.05, func(x): return "%d %%" % roundi(x * 100))
	_slider(v, "Musique", "audio", "music", 0.0, 1.0, 0.05, func(x): return "%d %%" % roundi(x * 100))


# --- page Caméra et interface ----------------------------------------------------------------------------
func _build_camera_page() -> void:
	var v := _page("Caméra & interface", HINT_DEFAULT)
	_section(v, "Caméra")
	_slider(v, "Sensibilité de rotation", "camera", "rotate_speed", 0.25, 3.0, 0.05, func(x): return "× %.2f" % x)
	_check(v, "Inverser l'inclinaison (haut / bas)", "camera", "invert_y")
	_slider(v, "Distance de départ (zoom)", "camera", "distance", 7.0, 28.0, 1.0, func(x): return "%d m" % roundi(x))
	_slider(v, "Tremblements de l'écran", "camera", "shake", 0.0, 1.5, 0.05, func(x): return "%d %%" % roundi(x * 100))
	_slider(v, "Rotation au curseur (mode Action)", "camera", "action_turn", 0.3, 2.5, 0.05, func(x): return "%d %%" % roundi(x * 100))
	_section(v, "Interface et ressenti")
	_option(v, "Chiffres de dégâts", "interface", "damage_numbers", [
		["all", "Tous"], ["dealt", "Dégâts infligés seulement"], ["crit", "Critiques et dégâts subis"], ["off", "Masqués"]])
	_check(v, "Arrêt sur image à l'impact", "interface", "hit_stop", "Une très courte pause à chaque coup lourd donne du poids aux frappes.")
	_check(v, "Afficher les FPS", "interface", "show_fps")
	_check(v, "Afficher la boussole d'objectif", "interface", "compass", "Dans le menu principal, une pastille te dit la prochaine chose utile à faire.")
	_check(v, "Marqueur des clics de déplacement", "interface", "move_marker", "Un repère au sol à l'endroit où tu as cliqué pour te déplacer.")
	_check(v, "Zone de mes attaques au sol", "interface", "attack_zone", "Montre en bleu la zone des sorts que tu lances, pour apprendre leur portée.")
	# lot BR-I3 : confort et accessibilité (Battle royale d'abord ; l'arc de coup reçu du Duel suit aussi les couleurs)
	_section(v, "Accessibilité")
	_check(v, "Voir les sons", "interface", "sound_cues", "Battle royale : un arc autour du héros montre d'où vient un son important (coffre, combat, pas, anneau), avec son nom.")
	_check(v, "Couleurs pour daltoniens", "interface", "colorblind", "Le danger passe en orange et le « plus faible » en bleu, au lieu du rouge et du vert. Les formes ▲ ▼ restent.")
	_check(v, "Vibration en combat", "interface", "combat_vibration", "À la manette, une courte vibration aux coups donnés et reçus, au saut et à l'atterrissage.")
	_section(v, "Menus")
	_check(v, "Réduire les animations", "interface", "ui_reduce_motion", "Boutons et fenêtres sans rebond ni étincelles. Les sons et la vibration restent.")
	_check(v, "Vibration manette", "interface", "ui_vibration", "Une courte vibration à chaque clic et à chaque pas du cadre dans les menus.")
	_slider(v, "Intensité des effets d'interface", "interface", "ui_fx", 0.0, 1.5, 0.05, func(x): return "%d %%" % roundi(x * 100),
		"Force du rebond des boutons, des étincelles et des sons des menus.")
	_build_cursor_rows(v)
	_section(v, "Effets visuels")
	var who := [["all", "Tout afficher"], ["dim_others", "Atténuer ceux des autres"], ["hide_others", "Masquer ceux des autres"],
		["hide_mine", "Masquer les miens"], ["hide_all", "Tout masquer"]]
	var fx_hint := "Les zones d'attaque (avertissements rouges, cercles au sol) restent toujours visibles : seuls les décors lumineux des sorts et des skins sont concernés."
	_option(v, "Effets de sorts et d'impacts", "interface", "fx_spells", who.map(func(w): return [w[0], w[1], fx_hint]))
	_slider(v, "Intensité des effets de sorts", "interface", "fx_intensity", 0.5, 1.6, 0.05, func(x): return "%d %%" % roundi(x * 100),
		"Opacité et éclat des effets de sorts : plus haut, plus d'impact ; plus bas, plus de lisibilité.")
	_option(v, "Auras de skin", "interface", "fx_auras", who.map(func(w): return [w[0], w[1], "Pierres étoilées, auras de collection… " + fx_hint]))
	_option(v, "Étincelles, poussière et éclairs", "interface", "fx_particles", [
		["all", "Tous"], ["reduced", "Réduits de moitié"], ["off", "Aucun"]])
	_section(v, "Développement")
	_check(v, "Mode dev (F10)", "interface", "dev_mode", "Objets, ressources, progression et actions en run, pour tester.")


## Curseur de souris et réticule de visée (CursorSets, AimReticle) : aperçu direct à droite de chaque réglage.
func _build_cursor_rows(v: Control) -> void:
	_section(v, "Curseur et visée")
	_option(v, "Curseur de la souris", "interface", "cursor_set", CursorSets.LIST)
	var reticle_hint := "S'affiche en jeu avec la visée « Curseur » ou le mode Action. Il ne gêne jamais les clics."
	_option(v, "Réticule de visée", "interface", "reticle", AimReticle.SHAPES.map(func(e): return [e[0], e[1], reticle_hint]))
	_slider(v, "Taille du réticule", "interface", "reticle_size", AimReticle.SIZE_MIN, AimReticle.SIZE_MAX, 0.1, func(x): return "%d %%" % roundi(x * 100), reticle_hint)
	_option(v, "Couleur du réticule", "interface", "reticle_color", AimReticle.COLORS.map(func(e): return [e[0], e[1], reticle_hint]))
	var row := _row(v, "Aperçu", "Les quatre formes du curseur, puis le réticule sur fond clair et sur fond sombre.")
	var prev := CursorPreview.new()
	row.add_child(prev)
	_refreshers.append(prev.refresh)


# --- briques d'interface ---------------------------------------------------------------------------------
## Une page : cadre orné, défilement, colonne centrée. Renvoie la colonne où poser les lignes.
func _page(title: String, hint := "") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(28, 18))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var h := HBoxContainer.new()
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(h)
	var left := Control.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(COL_W, 0)
	col.add_theme_constant_override("separation", 2)
	h.add_child(col)
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	add_page(title, panel)
	_page_hints.append(hint)
	return col


## Bouton discret : filet gris, or au survol (l'or est réservé à ce qui est choisi).
func _neutral(b: Button) -> void:
	b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.12, 0.1, 0.2, 0.95), Color(0.5, 0.48, 0.6, 0.7), 1, 8, false))
	b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.22, 0.18, 0.34), ACCENT, 1, 8, false))


func _text(parent: Control, text: String, size: int, color: Color) -> Label:
	return Hud._label(parent, text, UiTheme.text_size(size), color)


func _section(parent: Control, text: String) -> void:
	if parent.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 12)
		parent.add_child(gap)
	var l := _text(parent, text, 20, ACCENT)
	l.add_theme_font_override("font", UiTheme.bold_font())
	var line := ColorRect.new()
	line.color = Color(UiTheme.GOLD_DIM, 0.45)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _row_box(hot: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.06) if hot else Color(1, 1, 1, 0.0)
	sb.border_color = Color(UiTheme.GOLD_DIM, 0.28)
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 14
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


## Ligne : titre à gauche, contrôles à droite (renvoie la boîte des contrôles). [param hint] : texte
## du pied quand on survole la ligne, ou Callable qui le calcule.
func _row(parent: Control, text: String, hint: Variant = "") -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, ROW_H)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _row_box(false))
	panel.set_meta("row_panel", true)
	parent.add_child(panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	panel.add_child(h)
	var l := _text(h, text, 17, TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	controls.alignment = BoxContainer.ALIGNMENT_END
	controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(controls)
	if (hint is String and hint != "") or hint is Callable:
		panel.set_meta("hint", hint)
		_hinted.append(panel)
	return controls


## La valeur courante [param cur] est-elle le choix [param value] ?
static func _same(value: Variant, cur: Variant) -> bool:
	if cur is float or value is float:
		return (cur is float or cur is int) and (value is float or value is int) and is_equal_approx(float(value), float(cur))
	return typeof(value) == typeof(cur) and value == cur


## Liste déroulante. Chaque choix : [valeur, libellé, détail (facultatif, affiché dans le pied)].
func _option(parent: Control, text: String, section: String, key: String, choices: Array) -> OptionButton:
	var hint: Variant = ""
	if choices.any(func(c): return c.size() > 2):
		hint = func() -> String:
			var cur: Variant = Settings.get_v(section, key)
			for c in choices:
				if c.size() > 2 and _same(c[0], cur):
					return String(c[2])
			return ""
	var row := _row(parent, text, hint)
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(OPTION_W, 38)
	o.focus_mode = Control.FOCUS_NONE
	o.add_theme_font_size_override("font_size", 16)
	_neutral(o)
	o.add_theme_stylebox_override("pressed", o.get_theme_stylebox("hover"))
	for c in choices:
		o.add_item(String(c[1]))
	o.item_selected.connect(func(i): Settings.set_v(section, key, choices[i][0]))
	row.add_child(o)
	_refreshers.append(func():
		var cur: Variant = Settings.get_v(section, key)
		for i in choices.size():
			if _same(choices[i][0], cur):
				o.select(i))
	return o


## Interrupteur à glissière.
func _check(parent: Control, text: String, section: String, key: String, hint := "") -> UiTheme.Switch:
	var row := _row(parent, text, hint)
	var c := _switch()
	c.toggled.connect(func(on): Settings.set_v(section, key, on))
	row.add_child(c)
	_refreshers.append(func(): c.set_pressed_no_signal(bool(Settings.get_v(section, key))))
	return c


func _switch() -> UiTheme.Switch:
	var s := UiTheme.Switch.new()
	_switches.append(s)
	return s


func _slider(parent: Control, text: String, section: String, key: String, lo: float, hi: float, step: float, fmt: Callable, hint := "") -> HSlider:
	var row := _row(parent, text, hint)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.scrollable = false  # la molette fait défiler la page, elle ne règle pas le curseur
	s.custom_minimum_size = Vector2(380, 30)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	row.add_child(s)
	var val := _text(row, "", 17, ACCENT)
	val.custom_minimum_size = Vector2(80, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.value_changed.connect(func(x):
		val.text = fmt.call(x)
		Settings.set_v(section, key, x))
	_refreshers.append(func():
		var cur: Variant = Settings.get_v(section, key)
		s.set_value_no_signal(float(cur) if cur != null else clampf(1.0, lo, hi))  # réglage absent de Settings.DEFAULTS : 1 (100 %)
		val.text = fmt.call(s.value))
	return s


func _button(parent: Control, text: String, cb: Callable, width := 250) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 42)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	_neutral(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
