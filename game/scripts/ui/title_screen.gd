extends Node3D
## Écran titre : une illustration en fond (lot ILL-2 : « titre », puis « menu » quand la fenêtre Jouer s'ouvre) ; gros bouton Jouer
## (continuer, charger une partie, nouvelle partie sur l'un des 3 emplacements),
## Paramètres, Quitter. Les lancements avec arguments (tests, captures) vont droit au lobby.
## Aucun texte superflu : le décor, le logo et les trois boutons suffisent.

const LOBBY := "res://scenes/lobby.tscn"
const BG_TITLE := "res://assets/ui/backdrops/titre.jpg"
const BG_MENU := "res://assets/ui/backdrops/menu.jpg"

var bg_title: TextureRect  # (tests) l'illustration de l'écran titre
var bg_menu: TextureRect  # celle de la fenêtre Jouer, en fondu par-dessus
var _bg_tween: Tween
var _veils: Array[Control] = []  # voiles du titre (cachés quand la fenêtre Jouer a son illustration)
var _settings: SettingsMenu
var _main: VBoxContainer
var _center: Control
var _saves: Control  # fenêtre Jouer
var _saves_title: Label
var _saves_body: VBoxContainer
var _armed := -1  # emplacement à écraser (2e clic)
var friends: Button  # « Jouer ensemble » (Mode amis, lot NET-A), visible si le réglage est actif


func _ready() -> void:
	if NetLaunch.requested():  # (lot NET-A) EdenSlash.exe --host / --join=<adresse> : droit à l'arène entre amis
		get_tree().change_scene_to_file.call_deferred(NetLaunch.SCENE)
		return
	if not OS.get_cmdline_user_args().is_empty():
		get_tree().change_scene_to_file.call_deferred(LOBBY)
		return
	_build_ui()
	_settings = SettingsMenu.new()
	add_child(_settings)
	# P2 : le lobby (scène et scripts) se charge en tâche de fond pendant que le joueur lit le titre
	ResourceLoader.load_threaded_request(LOBBY)


func _build_ui() -> void:
	var art := CanvasLayer.new()  # les illustrations, sous l'interface
	art.layer = 0
	add_child(art)
	bg_title = _bg(art, BG_TITLE, 1.0)
	bg_menu = _bg(art, BG_MENU, 0.0)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	# voile en bas et en haut pour la lisibilité
	for top in [true, false]:
		var g := TextureRect.new()
		var grad := GradientTexture2D.new()
		grad.fill_from = Vector2(0, 0)
		grad.fill_to = Vector2(0, 1)
		grad.gradient = Gradient.new()
		grad.gradient.set_color(0, Color(0.05, 0.02, 0.1, 0.34 if top else 0.0))
		grad.gradient.set_color(1, Color(0.05, 0.02, 0.1, 0.0 if top else 0.62))
		g.texture = grad
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.stretch_mode = TextureRect.STRETCH_SCALE
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		if top:
			g.offset_bottom = 340
		else:
			g.offset_top = -380
		root.add_child(g)
		_veils.append(g)
	# le logo dans le ciel, en haut au centre ; les boutons en bas à gauche, hors du héros et du royaume
	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_center = center
	var logo := MenuWidgets.logo(center, 104, true)
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 44)
	_main = VBoxContainer.new()
	_main.alignment = BoxContainer.ALIGNMENT_CENTER
	_main.add_theme_constant_override("separation", 14)
	center.add_child(_main)
	var play := MenuWidgets.gold_button("Jouer", 38, Vector2(440, 86))
	play.pressed.connect(_open_saves)
	_main.add_child(play)
	friends = MenuWidgets.paper_button("Jouer ensemble", 20, Vector2(440, 54))  # (lot NET-A) Mode amis, réglage « net/friends »
	friends.pressed.connect(func(): get_tree().change_scene_to_file(NetLaunch.SCENE))
	friends.visible = bool(Settings.get_v("net", "friends"))
	Settings.changed.connect(_on_settings_changed)
	_main.add_child(friends)
	for spec in [["Paramètres", func(): _settings.open()], ["Quitter", func(): get_tree().quit()]]:
		var b := MenuWidgets.paper_button(spec[0], 20, Vector2(440, 54))  # boutons papier sur la scène (UIK1)
		b.pressed.connect(spec[1])
		_main.add_child(b)
	_main.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT, Control.PRESET_MODE_MINSIZE, 72)
	_build_saves(root)


## Illustration plein cadre (recadrée, jamais déformée) ; [param alpha] 0 : cachée, pour le fondu.
func _bg(parent: Node, path: String, alpha: float) -> TextureRect:
	var img := TextureRect.new()
	img.texture = load(path)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.modulate.a = alpha
	parent.add_child(img)
	return img


## La fenêtre Jouer passe sur l'illustration du menu (fondu) ; en revenir remet celle du titre.
func _fade_menu(on: bool) -> void:
	for v in _veils:
		v.visible = not on
	if bg_menu == null:
		return
	if _bg_tween != null and _bg_tween.is_valid():
		_bg_tween.kill()
	_bg_tween = create_tween()
	_bg_tween.tween_property(bg_menu, "modulate:a", 1.0 if on else 0.0, 0.35)


# --- fenêtre Jouer : continuer, charger, nouvelle partie -----------------------------------
func _build_saves(root: Control) -> void:
	_saves = Control.new()
	_saves.set_anchors_preset(Control.PRESET_FULL_RECT)
	_saves.visible = false
	root.add_child(_saves)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.1, 0.22)  # (l'illustration du menu reste claire)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_saves.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_saves.add_child(cc)
	var p := PanelContainer.new()
	UiTheme.paper(p, 7, Vector2(22, 18))  # fenêtre papier autocollant (UIK1)
	p.custom_minimum_size = Vector2(760, 0)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	_saves_title = Label.new()
	UiTheme.title(_saves_title, 30)
	_saves_title.set_meta("ink_keep", true)  # titre autocollant contouré sur le papier (UIK1)
	_saves_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_saves_title)
	var orn := MenuWidgets.Ornament.new()
	orn.custom_minimum_size = Vector2(420, 12)
	orn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(orn)
	_saves_body = VBoxContainer.new()
	_saves_body.add_theme_constant_override("separation", 10)
	v.add_child(_saves_body)


func _open_saves() -> void:
	_fade_menu(true)
	_saves.visible = true
	_center.visible = false
	_show_root()


func _close_saves() -> void:
	_fade_menu(false)
	_saves.visible = false
	_center.visible = true


func _clear_body() -> void:
	for c in _saves_body.get_children():
		c.queue_free()
	_armed = -1


func _back_button(cb: Callable) -> void:
	var b := MenuWidgets.paper_button("Retour", 18, Vector2(200, 46))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	_saves_body.add_child(b)


func _show_root() -> void:
	_clear_body()
	_saves_title.text = "Jouer"
	var last := Profile.last_slot()
	var any := range(1, Profile.SLOT_COUNT + 1).any(func(i): return Profile.slot_exists(i))
	if Profile.slot_exists(last):
		var row := MenuWidgets.RowButton.new("Continuer", "Sauvegarde %d · %s" % [last, _summary_text(Profile.slot_summary(last))], "continue", 84)
		row.pressed.connect(_load.bind(last))
		_saves_body.add_child(row)
	var load_row := MenuWidgets.RowButton.new("Charger une partie", "" if any else "Aucune sauvegarde", "save", 76)
	load_row.disabled = not any
	load_row.pressed.connect(_show_slots.bind(false))
	_saves_body.add_child(load_row)
	var new_row := MenuWidgets.RowButton.new("Nouvelle partie", "", "new", 76)
	new_row.pressed.connect(_show_slots.bind(true))
	_saves_body.add_child(new_row)
	_back_button(_close_saves)


func _summary_text(s: Dictionary) -> String:
	if s.is_empty():
		return "vide"
	var who := String(GameData.class_data(String(s["class"])).get("name_fr", s["class"]))
	if String(s.get("name", "")) != "":
		who = "%s · %s" % [s.name, who]  # nom du héros (création de personnage)
	return "%s · %d run%s · %d victoire%s · niveau max %d" % [
		who, int(s.runs), "s" if int(s.runs) > 1 else "",
		int(s.wins), "s" if int(s.wins) > 1 else "", int(s.best)]


## « 2026-10-15T21:30:12 » -> « 15/10/2026 à 21 h 30 ».
static func date_fr(iso: String) -> String:
	if iso.length() < 16 or iso[10] != "T":
		return ""
	return "%s/%s/%s à %s h %s" % [iso.substr(8, 2), iso.substr(5, 2), iso.substr(0, 4), iso.substr(11, 2), iso.substr(14, 2)]


func _show_slots(new_game: bool) -> void:
	_clear_body()
	_saves_title.text = "Nouvelle partie" if new_game else "Charger une partie"
	for i in range(1, Profile.SLOT_COUNT + 1):
		_saves_body.add_child(_slot_card(i, new_game))
	_back_button(_show_root)


func _slot_card(i: int, new_game: bool) -> Control:
	var s := Profile.slot_summary(i)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.08, 0.17, 0.92), MenuWidgets.LINE, 1, 12, false))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(64, 64)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if s.is_empty():
		ic.texture = MenuWidgets.icon("save")
		ic.modulate = Color(1, 1, 1, 0.35)
	else:
		ic.texture = UiTheme.texture(String(GameData.class_data(String(s["class"])).get("icon", "")))
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var t := Hud._label(v, "Sauvegarde %d" % i, 19, UiTheme.GOLD)
	t.add_theme_font_override("font", UiTheme.bold_font())
	if s.is_empty():
		Hud._label(v, "Emplacement libre", 14, UiTheme.MUTED)
	else:
		Hud._label(v, _summary_text(s), 14, UiTheme.TEXT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var when := date_fr(String(s.saved_at))
		if when != "":
			Hud._label(v, "Dernière partie : %s" % when, 14, UiTheme.MUTED)
	var b: Button
	if new_game:
		b = MenuWidgets.gold_button("Commencer" if s.is_empty() else "Remplacer", 18, Vector2(170, 52))
		b.pressed.connect(func():
			if not s.is_empty() and _armed != i:
				_armed = i
				b.text = "Confirmer ?"
				t.text = "Sauvegarde %d — sera effacée !" % i
				t.add_theme_color_override("font_color", UiTheme.DEBUFF)
				return
			_new(i))
	else:
		b = MenuWidgets.gold_button("Charger", 18, Vector2(170, 52))
		b.disabled = s.is_empty()
		if s.is_empty():
			b.modulate = Color(1, 1, 1, 0.35)
		b.pressed.connect(_load.bind(i))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return p


func _load(i: int) -> void:
	Profile.load_slot(i)
	_go()


func _new(i: int) -> void:
	Profile.new_game(i)
	_go()


func _go() -> void:
	get_tree().change_scene_to_file.call_deferred(LOBBY)


func _on_settings_changed() -> void:
	friends.visible = bool(Settings.get_v("net", "friends"))


func _unhandled_input(event: InputEvent) -> void:
	if _saves and _saves.visible and event.is_action_pressed("pause") and not _settings.is_open():
		_close_saves()
		get_viewport().set_input_as_handled()
