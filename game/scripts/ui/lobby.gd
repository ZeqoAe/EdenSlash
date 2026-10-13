extends Node3D
## Menu principal (lobby) : le héros posé dans la map de la zone choisie ; menu à icônes
## à gauche, une fonction = un seul endroit :
## - Jouer : lancer la run (un clic), résumé du héros (ouvre l'écran Héros), zone de farm ;
## - Héros : écran HeroScreen (équipement, talents, apparence, grimoire, classe, aide « ? ») ;
## - Coffres : les coffres de récompense rapportés des runs, à ouvrir (Rewards) ;
## - Collection : l'archive des trésors (une seule page) ;
## - Paramètres, Quitter.
## Badge de la classe en haut à droite, zone et prochaine récompense en bas.
## Les arguments de test (--autoplay, --dungeon, --shots...) lancent la run directement.

const RUN_SCENE := "res://scenes/world.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
## Menu de gauche : identifiant, texte, icône.
const MENU := [
	["play", "Jouer", "play"], ["hero", "Héros", "class"], ["chests", "Coffres", "chest"], ["collection", "Collection", "collection"],
	["settings", "Paramètres", "settings"], ["quit", "Quitter", "quit"],
]
## Arguments de test qui ouvrent un écran au démarrage (captures, tests).
const SCREEN_ARGS := ["--grimoire", "--talents", "--info", "--inventory", "--appearance", "--chests", "--cards"]

var backdrop: MapBackdrop
var _hero: HeroScreen
var _archive: PageScreen
var _chests: PageScreen
var _launching := false
var _open_screen := ""  # test : écran ouvert au démarrage (--inventory, --talents, --appearance, --archive=0...)
var _settings: SettingsMenu
var _menu := {}  # identifiant -> MenuWidgets.SideButton
var _current := ""  # sous-menu affiché ("" : aucun, le panneau est caché)
var _sub: VBoxContainer
var _sub_panel: PanelContainer
var _badge_icon: TextureRect
var _badge_name: Label
var _badge_sub: Label
var _zone_thumb: TextureRect
var _zone_name: Label
var _zone_sub: Label
var _reward_bar: ProgressBar
var _reward_text: Label
var _footer: Label
var _clock: Label
var _snapshot: Texture2D
var _dev_button: Button


func _ready() -> void:
	var shot := -1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			Profile.selected_class = arg.trim_prefix("--class=")
		elif arg.begins_with("--zone="):
			Profile.selected_zone = arg.trim_prefix("--zone=")
		elif arg.begins_with("--weapon="):
			Profile.select_weapon_type(arg.trim_prefix("--weapon="))
		elif arg in SCREEN_ARGS or arg.begins_with("--archive=") or arg.begins_with("--appearance=") or arg.begins_with("--dev="):
			_open_screen = arg.trim_prefix("--")
		elif arg.begins_with("--wear-back="):
			# test : porte la pièce de dos d'Eden de ce nom, --dye-back=r,g,b;r,g,b;r,g,b
			for c in GameData.cosmetics:
				if String(c.name) == arg.trim_prefix("--wear-back="):
					Profile.unlock_outfit(String(c.id))
					Profile.set_worn(Profile.selected_class, "back", String(c.outfit))
		elif arg.begins_with("--orbit="):
			# test : caméra de l'accueil (degrés, degrés, distance, hauteur)
			_test_orbit = Array(arg.trim_prefix("--orbit=").split(",")).map(func(x): return float(x))
		elif arg.begins_with("--dye-back="):
			var cols: Array = []
			for part in arg.trim_prefix("--dye-back=").split(";"):
				cols.append(Array(part.split(",")).map(func(x): return int(x)))
			Profile.set_dye(Profile.selected_class, "back", cols)
		elif arg.begins_with("--wear-head="):
			# test : porte l'accessoire de tête d'Eden de ce nom (profil de test uniquement)
			for c in GameData.cosmetics:
				if String(c.name) == arg.trim_prefix("--wear-head="):
					Profile.unlock_outfit(String(c.id))
					Profile.set_worn(Profile.selected_class, "head", String(c.outfit))
		elif arg == "--wear-aura":
			# test : une pierre étoilée et une pierre de lune portées (profil de test uniquement)
			for kind in ["star", "luna"]:
				var xs := GameData.auras.filter(func(x): return String(x.aura.kind) == kind)
				if not xs.is_empty():
					Profile.collect(xs[0])
					Profile.set_aura(Profile.selected_class, kind, int(xs[0].id))
		elif arg.begins_with("--expertise="):
			# test : expertise donnée à toutes les classes (profil de test uniquement)
			for cid in GameData.classes:
				Profile.expertise[cid] = int(arg.trim_prefix("--expertise="))
	if not Profile.in_run:
		Profile.save_profile()  # classe choisie en argument : son préréglage (et son arme)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class=") or arg.begins_with("--zone=") or arg.begins_with("--weapon=") or arg in SCREEN_ARGS \
				or arg.begins_with("--archive=") or arg.begins_with("--appearance=") or arg.begins_with("--expertise=") or arg.begins_with("--dev=") \
				or arg == "--wear-aura" or arg == "--class-menu" or arg.begins_with("--wear-head=") or arg.begins_with("--wear-back=") or arg.begins_with("--dye-back=") or arg.begins_with("--archive-cat=") or arg.begins_with("--shot-out=") or arg.begins_with("--orbit="):
			continue
		if arg.begins_with("--lobby-shot="):
			shot = float(arg.trim_prefix("--lobby-shot="))
		elif arg.begins_with("--"):
			_start_run()
			return
	_build_scene()
	_build_ui()
	match _open_screen.get_slice("=", 0):
		"grimoire":
			_open_hero("grimoire")
		"talents":
			_open_hero("class")
			for arg in OS.get_cmdline_user_args():
				if arg == "--class-menu":  # test : menu des classes ouvert
					_hero.get_node(".").call_deferred("_test_class_menu")
		"info":
			_open_hero("help")
		"inventory":
			_open_hero("equipment")
		"cards":
			_open_hero("cards")
		"appearance":
			# test : catégorie de l'apparence (--appearance=aura, --appearance=weapon...)
			if _open_screen.contains("="):
				_hero.appearance._cat = _open_screen.get_slice("=", 1)
				_hero.appearance._slot = {"aura": "star"}.get(_hero.appearance._cat, _hero.appearance._cat)
				_hero.appearance._aura_kind = "star" if _hero.appearance._cat == "aura" else ""
			_open_hero("appearance")
		"dev":
			# test : écran du mode dev, page N (paramètres de test uniquement)
			Settings.set_v("interface", "dev_mode", true)
			Dev.open(int(_open_screen.get_slice("=", 1)))
			match int(_open_screen.get_slice("=", 1)):
				1:  # éditeur : le premier objet possédé
					var ed: DevEditor.EditPage = Dev.screen.page(1)
					ed._select(ed._entries[0])
				2:  # sets : un set d'Eden
					Dev.screen.page(2)._open(String(GameData.eden_sets.keys()[0]))
				3:  # cartes : Lame statique (stats et effets déclenchés)
					Dev.screen.page(3)._open("static_blade")
		"chests":
			# test (profil de test) : un coffre de chaque type, la proposition d'un coffre de set ouverte
			if Profile.reward_chests.is_empty():
				for t in Rewards.ORDER:
					Profile.reward_chests.append(Rewards.make(t, 25))
			_chests.open(0)
			_chests.page(0).open_chest(Profile.reward_chests.filter(func(c): return c.type == "set")[0])
		"archive":
			_archive.open(0)
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--archive-cat="):  # test : catégorie de l'archive
					_archive.page(0)._cat = arg.trim_prefix("--archive-cat=")
					_archive.page(0).refresh()
	if shot > 0.0:
		await get_tree().create_timer(shot).timeout
		DirAccess.make_dir_recursive_absolute("user://shots")
		var out := "lobby"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--shot-out="):
				out = arg.trim_prefix("--shot-out=")
		get_viewport().get_texture().get_image().save_png("user://shots/%s.png" % out)
		get_tree().quit()


## Lancer la run : un clic (le héros se prépare dans l'écran Héros).
func _launch() -> void:
	if _launching:
		return
	_launching = true
	_start_run()


func _start_run() -> void:
	if backdrop:
		backdrop.release()
	Run.start(Profile.selected_class)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


# --- décor 3D : la map de la zone, le héros au premier plan ---------------------------------
func _build_scene() -> void:
	if not Profile.zone_unlocked(Profile.selected_zone):
		Profile.selected_zone = "limestone"
	backdrop = MapBackdrop.new()
	add_child(backdrop)
	backdrop.show_zone(Profile.selected_zone, true)
	backdrop.stage_hero()
	_snapshot = backdrop.snapshot()
	_show_hero()
	if _test_orbit.size() >= 4:
		backdrop.orbit_yaw = deg_to_rad(_test_orbit[0])
		backdrop.orbit_pitch = deg_to_rad(_test_orbit[1])
		backdrop.orbit_dist = _test_orbit[2]
		backdrop.orbit_lift = _test_orbit[3]
		backdrop.place_stage_camera()


func _show_hero() -> void:
	if backdrop == null:
		return
	for c in backdrop.hero_root.get_children():
		c.queue_free()
	var cls := GameData.class_data(Profile.selected_class)
	if cls.is_empty() or not ResourceLoader.exists(cls.model):
		return
	var model := EdenModel.instantiate_hero(cls, Profile.outfit_of(Profile.selected_class), Profile.worn_parts(Profile.selected_class), Profile.dye_map(Profile.selected_class))
	model.scale = Vector3.ONE * GameData.HERO_SCALE
	model.rotation.y = -0.45  # trois-quarts, tourné vers le menu
	backdrop.hero_root.add_child(model)
	EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, Profile.weapon_code()))
	EdenFx.attach_auras(backdrop.hero_root, Profile.selected_class, GameData.HERO_SCALE)
	var ap := EdenModel.find_anim_player(model)
	var battle: String = cls.anims.get("battle", "stand01")
	if ap and ap.has_animation(battle):
		ap.get_animation(battle).loop_mode = Animation.LOOP_LINEAR
		ap.play(battle)


var _tick := 0.0
var _orbit_drag := 0  # bouton tenu pour bouger la caméra (0 : aucun)
var _test_orbit: Array = []


## Caméra autour du héros, dans le décor (hors des menus) : glisser pour tourner, molette pour
## zoomer, clic droit glissé pour monter ou descendre, double-clic pour revenir à la vue de départ.
func _unhandled_input(event: InputEvent) -> void:
	if backdrop == null or _screen_open():
		_orbit_drag = 0
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.double_click and mb.button_index == MOUSE_BUTTON_LEFT:
			backdrop.reset_orbit()
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_orbit_drag = mb.button_index if mb.pressed else 0
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			backdrop.orbit_dist = clampf(backdrop.orbit_dist * (0.88 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14), 1.6, 10.0)
			backdrop.place_stage_camera()
	elif event is InputEventMouseMotion and _orbit_drag != 0:
		if not Input.is_mouse_button_pressed(_orbit_drag) and not (event as InputEventMouseMotion).button_mask:
			_orbit_drag = 0  # bouton relâché au-dessus d'un menu
			return
		var mm := event as InputEventMouseMotion
		if _orbit_drag == MOUSE_BUTTON_LEFT:
			backdrop.orbit_yaw -= mm.relative.x * 0.008
			backdrop.orbit_pitch = clampf(backdrop.orbit_pitch + mm.relative.y * 0.005, -0.25, 1.1)
		else:
			backdrop.orbit_lift = clampf(backdrop.orbit_lift + mm.relative.y * 0.006, -1.0, 1.2)
		backdrop.place_stage_camera()


## Un écran plein écran (Héros, Collection, Coffres, Paramètres, mode dev) est-il ouvert ?
func _screen_open() -> bool:
	for n in [_hero, _archive, _chests, _settings]:
		if n and n.has_method("is_open") and n.is_open():
			return true
	return Dev.is_open() if Dev.has_method("is_open") else false


func _process(delta: float) -> void:
	_tick -= delta
	if _clock and _tick <= 0.0:
		_tick = 1.0
		_clock.text = Time.get_time_string_from_system().left(5)


# --- interface ------------------------------------------------------------------------------
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	# voile à gauche pour la lisibilité des menus
	var veil := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.02, 0.02, 0.07, 0.62))
	grad.gradient.set_color(1, Color(0.02, 0.02, 0.07, 0.0))
	veil.texture = grad
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE
	veil.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	veil.offset_right = 980
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var logo_box := Control.new()
	logo_box.position = Vector2(48, 22)
	logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(logo_box)
	MenuWidgets.logo(logo_box, 64)
	# menu de gauche
	var left := VBoxContainer.new()
	left.position = Vector2(44, 196)
	left.add_theme_constant_override("separation", 12)
	root.add_child(left)
	for m in MENU:
		var b := MenuWidgets.SideButton.new(m[1], m[2], 60.0)
		b.pressed.connect(_on_menu.bind(String(m[0])))
		left.add_child(b)
		_menu[m[0]] = b
	# sous-menu central
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", MenuWidgets.glass(14))
	sp.position = Vector2(372, 196)
	sp.custom_minimum_size = Vector2(450, 0)
	sp.visible = false
	root.add_child(sp)
	_sub_panel = sp
	_sub = VBoxContainer.new()
	_sub.add_theme_constant_override("separation", 10)
	sp.add_child(_sub)
	# badge de la classe (en haut à droite)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", MenuWidgets.glass(12))
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -380
	badge.offset_right = -28
	badge.offset_top = 24
	badge.offset_bottom = 104
	badge.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	badge.tooltip_text = "Changer de classe"
	root.add_child(badge)
	# clic : menu compact des classes par famille (comme dans l'écran Héros)
	badge.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			HeroPages.class_menu(badge, Profile.selected_class, _select_class))
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 14)
	badge.add_child(bh)
	_badge_icon = _tex(bh, Vector2(56, 56))
	var bv := VBoxContainer.new()
	bv.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_theme_constant_override("separation", 0)
	bh.add_child(bv)
	_badge_name = Hud._label(bv, "", 21, Color(1, 0.97, 0.9))
	_badge_name.add_theme_font_override("font", UiTheme.bold_font())
	_badge_sub = Hud._label(bv, "", 14, UiTheme.MUTED)
	# zone et prochaine récompense (en bas à gauche)
	var zc := PanelContainer.new()
	zc.add_theme_stylebox_override("panel", MenuWidgets.glass(14, UiTheme.GOLD, 0.88))
	zc.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	zc.offset_left = 44
	zc.offset_right = 760
	zc.offset_top = -136
	zc.offset_bottom = -28
	root.add_child(zc)
	var zh := HBoxContainer.new()
	zh.add_theme_constant_override("separation", 16)
	zc.add_child(zh)
	_zone_thumb = _tex(zh, Vector2(150, 80))
	_zone_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var zv := VBoxContainer.new()
	zv.alignment = BoxContainer.ALIGNMENT_CENTER
	zv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zh.add_child(zv)
	var zr := HBoxContainer.new()
	zr.add_theme_constant_override("separation", 8)
	zv.add_child(zr)
	var pin := _tex(zr, Vector2(26, 26))
	pin.texture = MenuWidgets.icon("pin")
	pin.modulate = UiTheme.GOLD
	_zone_name = Hud._label(zr, "", 22, Color(1, 0.97, 0.9))
	_zone_name.add_theme_font_override("font", UiTheme.bold_font())
	_zone_sub = Hud._label(zv, "", 14, UiTheme.MUTED)
	zh.add_child(VSeparator.new())
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.custom_minimum_size = Vector2(250, 0)
	zh.add_child(rv)
	Hud._label(rv, "Prochaine récompense", 14, UiTheme.MUTED)
	var rr := HBoxContainer.new()
	rr.add_theme_constant_override("separation", 10)
	rv.add_child(rr)
	var chest := _tex(rr, Vector2(34, 34))
	chest.texture = MenuWidgets.icon("chest")
	_reward_bar = ProgressBar.new()
	_reward_bar.show_percentage = false
	_reward_bar.custom_minimum_size = Vector2(190, 14)
	_reward_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_reward_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_bar.add_theme_stylebox_override("background", UiTheme.flat_box(Color(0.03, 0.03, 0.08, 0.9), MenuWidgets.LINE, 1, 7, false))
	_reward_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(UiTheme.GOLD, UiTheme.GOLD, 0, 7, false))
	rr.add_child(_reward_bar)
	_reward_text = Hud._label(rv, "", 12, UiTheme.MUTED)
	# sauvegarde, héritage et heure (en bas à droite)
	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", MenuWidgets.glass(12, MenuWidgets.LINE))
	info.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info.offset_left = -560
	info.offset_right = -28
	info.offset_top = -86
	info.offset_bottom = -36
	var orbit_hint := Hud._label(root, "Glisser : tourner autour du héros · molette : zoom · clic droit glissé : hauteur · double-clic : vue de départ", 12, Color(1, 1, 1, 0.7))
	orbit_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	orbit_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	orbit_hint.offset_left = -760
	orbit_hint.offset_right = -32
	orbit_hint.offset_top = -112
	orbit_hint.offset_bottom = -92
	orbit_hint.add_theme_constant_override("outline_size", 4)
	orbit_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	orbit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(info)
	var ih := HBoxContainer.new()
	ih.add_theme_constant_override("separation", 10)
	ih.alignment = BoxContainer.ALIGNMENT_END
	info.add_child(ih)
	var user := _tex(ih, Vector2(22, 22))
	user.texture = MenuWidgets.icon("user")
	user.modulate = MenuWidgets.ICON_TINT
	_footer = Hud._label(ih, "", 14, UiTheme.TEXT)
	ih.add_child(VSeparator.new())
	var clock := _tex(ih, Vector2(22, 22))
	clock.texture = MenuWidgets.icon("clock")
	clock.modulate = MenuWidgets.ICON_TINT
	_clock = Hud._label(ih, "", 14, UiTheme.TEXT)
	# mode dev (activé dans les Paramètres) : bouton au-dessus du pied de page
	_dev_button = MenuWidgets.glass_button("Mode dev  (F10)", 15, Vector2(200, 38))
	_dev_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_dev_button.offset_left = -228
	_dev_button.offset_right = -28
	_dev_button.offset_top = -136
	_dev_button.offset_bottom = -98
	_dev_button.pressed.connect(func(): Dev.open())
	root.add_child(_dev_button)
	Settings.changed.connect(func(): _dev_button.visible = Dev.enabled())

	# écrans plein écran
	_hero = HeroScreen.new(6)
	add_child(_hero)
	_hero.closed.connect(func():
		if _launching:
			return
		_show_hero()  # classe, arme ou apparence ont pu changer
		_refresh_ui())
	_archive = _screen("Collection", [["Collection", ArchivePages.CollectionPage.new()]])
	_archive.set_title("Collection", "Archive des trésors : chaque entrée donne un bonus permanent à tous les héros")
	_chests = _screen("Coffres", [["Coffres", ChestsPage.new()]])
	_chests.set_title("Coffres", "Coffres de récompense rapportés des runs : équipement, forge, joaillier, set au choix, trophée au choix")
	_settings = SettingsMenu.new()
	add_child(_settings)
	_refresh_ui()


func _tex(parent: Control, px: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.custom_minimum_size = px
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


## Menu de gauche : sous-menu (Jouer, Quitter) ou écran plein écran.
func _on_menu(id: String) -> void:
	match id:
		"hero":
			_open_hero()
		"collection":
			_archive.open(0)
		"chests":
			_chests.open(0)
		"settings":
			_settings.open()
		_:
			# Jouer, Quitter : le panneau s'ouvre au clic et se referme au second clic
			_show_menu("" if id == _current else id)


func _show_menu(id: String) -> void:
	_current = id
	if _sub_panel:
		_sub_panel.visible = id != ""
	for k in _menu:
		_menu[k].selected = k == ("play" if id == "zones" else id)
	for c in _sub.get_children():
		c.queue_free()
	match id:
		"play":
			_menu_play()
		"zones":
			_menu_zones()
		"quit":
			_menu_quit()


func _sub_title(t: String) -> void:
	var l := Label.new()
	l.text = t
	UiTheme.title(l, 22)
	_sub.add_child(l)


func _row(title: String, sub: String, icon: String, cb: Callable, height := 70.0) -> MenuWidgets.RowButton:
	var r := MenuWidgets.RowButton.new(title, sub, icon, height)
	r.pressed.connect(cb)
	_sub.add_child(r)
	return r


func _menu_play() -> void:
	var cls := GameData.class_data(Profile.selected_class)
	var zone := GameData.zone(Profile.selected_zone)
	# carte « Lancer une run » sur l'image de la zone
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(0, 136)
	card.clip_contents = true
	var n := UiTheme.flat_box(Color(0.08, 0.07, 0.16, 1.0), UiTheme.GOLD, 2, 12)
	var hv := UiTheme.flat_box(Color(0.12, 0.1, 0.22, 1.0), Color(1, 0.92, 0.62), 3, 12)
	hv.shadow_color = Color(UiTheme.GOLD, 0.5)
	hv.shadow_size = 12
	card.add_theme_stylebox_override("normal", n)
	card.add_theme_stylebox_override("hover", hv)
	card.add_theme_stylebox_override("pressed", hv)
	card.pressed.connect(_launch)
	_sub.add_child(card)
	var img := TextureRect.new()
	img.texture = _snapshot
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.offset_left = 3
	img.offset_top = 3
	img.offset_right = -3
	img.offset_bottom = -3
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(img)
	var shade := TextureRect.new()
	var g := GradientTexture2D.new()
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0, 0, 0, 0.0))
	g.gradient.set_color(1, Color(0.02, 0.02, 0.08, 0.85))
	shade.texture = g
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(shade)
	var tv := VBoxContainer.new()
	tv.set_anchors_preset(Control.PRESET_FULL_RECT)
	tv.offset_left = 18
	tv.offset_right = -40
	tv.offset_bottom = -12
	tv.alignment = BoxContainer.ALIGNMENT_END
	tv.add_theme_constant_override("separation", 0)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tv)
	var t := Hud._label(tv, "Lancer une run", 26, Color(1, 0.98, 0.92))
	t.add_theme_font_override("font", UiTheme.bold_font())
	Hud._label(tv, "%s · %s · niveau %d+" % [zone.get("name", ""), cls.get("name_fr", ""), 1 + int(zone.get("level_bonus", 0))], 14, Color(0.95, 0.93, 1.0))
	var ch := Hud._label(card, "›", 40, Color(1, 0.98, 0.92))
	ch.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	ch.offset_left = -34
	ch.offset_bottom = -10
	ch.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	# le héros tel qu'il partira : un clic ouvre l'écran Héros
	var w: Dictionary = Profile.equipped.get("weapon", {})
	var free := Profile.talent_points(Profile.selected_class) - Profile.talent_spent(Profile.selected_class)
	var hr := _row("Héros : %s" % cls.get("name_fr", ""), "%s · puissance %d%s" % [Items.display_name(w) if not w.is_empty() else "sans arme", Profile.equipped.values().reduce(func(acc, it): return acc + EquipmentPage._power_of(it), 0),
		" · %d point(s) de talent à dépenser" % free if free > 0 else ""], String(cls.get("icon", "")), _open_hero.bind(""))
	hr.mark(free > 0)
	_row("Zone de farm", "%s · niveau %d+" % [zone.get("name", ""), 1 + int(zone.get("level_bonus", 0))], "pin", _show_menu.bind("zones"))


func _menu_zones() -> void:
	_sub_title("Zone de farm")
	for i in GameData.zones.size():
		var z: Dictionary = GameData.zones[i]
		var open := i < Profile.unlocked_zones
		var r := _row(String(z.name), ("Niveau %d+" % (1 + int(z.get("level_bonus", 0)))) if open else "Verrouillée : bats le boss de %s" % GameData.zones[i - 1].name,
			"pin", _select_zone.bind(String(z.id)), 54.0)
		r.disabled = not open
		if not open:
			r.modulate = Color(1, 1, 1, 0.5)
		r.mark(z.id == Profile.selected_zone)
	var back := MenuWidgets.glass_button("‹  Retour", 16, Vector2(160, 40))
	back.pressed.connect(_show_menu.bind("play"))
	_sub.add_child(back)


func _menu_quit() -> void:
	_sub_title("Quitter")
	_row("Écran titre", "Changer de sauvegarde, nouvelle partie", "save", func():
		backdrop.release()
		get_tree().change_scene_to_file.call_deferred(TITLE_SCENE))
	_row("Quitter le jeu", "Ta progression est sauvegardée", "quit", func(): get_tree().quit())


func _select_class(id: String) -> void:
	if id == Profile.selected_class or not Progression.class_unlocked(id):
		return
	Profile.selected_class = id
	Profile.save_profile()
	_show_hero()
	_refresh_ui()


func _select_zone(id: String) -> void:
	if id == Profile.selected_zone or not Profile.zone_unlocked(id):
		return
	Profile.selected_zone = id
	Profile.save_profile()
	backdrop.change_zone(id, func():
		_snapshot = backdrop.snapshot()
		_refresh_ui())
	_refresh_ui()


## Badge, zone, récompense, pied de page, sous-menu courant.
func _refresh_ui() -> void:
	if _sub == null:
		return
	var cid := Profile.selected_class
	var cd := GameData.class_data(cid)
	_badge_icon.texture = UiTheme.texture(String(cd.get("icon", "")))
	_badge_name.text = String(cd.get("name_fr", cid)) + "  ▾"
	var w: Dictionary = Profile.equipped.get("weapon", {})
	_badge_sub.text = "Maîtrise niv. %d · %s" % [Profile.expertise_level(cid), GameData.weapon_type(Items.weapon_type_of(w)).get("name", "") if not w.is_empty() else "sans arme"]
	var zone := GameData.zone(Profile.selected_zone)
	_zone_name.text = String(zone.get("name", ""))
	_zone_sub.text = "Niv. %d+ · zone %d / %d · %d débloquée(s)" % [1 + int(zone.get("level_bonus", 0)), GameData.zone_index(Profile.selected_zone) + 1, GameData.zones.size(), Profile.unlocked_zones]
	_zone_thumb.texture = _snapshot
	var prog := Profile.expertise_progress(cid)
	_reward_bar.max_value = maxf(prog.y, 1.0)
	_reward_bar.value = prog.x
	var lvl := Profile.expertise_level(cid)
	var next := Progression.rewards_at(cid, lvl + 1).filter(func(r): return r.kind != "talent")
	_reward_text.text = ("Maîtrise %s niv. %d : %s" % [cd.get("name_fr", cid), lvl + 1, String(next[0].name) if not next.is_empty() else "+2 points de talent"]) if lvl < Profile.EXPERTISE_MAX else "Maîtrise maximale"
	_dev_button.visible = Dev.enabled()
	_menu.chests._label.text = "Coffres" + ("  (%d)" % Profile.reward_chests.size() if not Profile.reward_chests.is_empty() else "")
	_footer.text = "Sauvegarde %d · héritage %d objet(s) · %d run(s), %d victoire(s)" % [Profile.slot, Profile.vault.size(), Profile.runs_done, Profile.runs_won]
	_show_menu(_current)


## Écran plein écran du lobby ; à sa fermeture, le lobby suit (classe, arme, apparence).
func _screen(t: String, pages: Array) -> PageScreen:
	var s := PageScreen.new(t, 5)
	add_child(s)
	for p in pages:
		s.add_page(p[0], p[1])
	s.closed.connect(func():
		if _launching:
			return
		_show_hero()  # classe, arme ou apparence ont pu changer
		_refresh_ui())
	return s


func _open_hero(section := "") -> void:
	_hero.zone_texture = _snapshot
	_hero.open(section)
