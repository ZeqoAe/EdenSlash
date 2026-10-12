extends Node3D
## Menu principal (lobby) : le héros posé dans la map de la zone choisie ; menu à icônes
## à gauche (Jouer, Classe, Équipement, Collection, Infos, Paramètres, Quitter), sous-menu
## au centre (lancer une run, configuration de la classe, équipement, zone de farm...),
## badge de la classe en haut à droite, zone et prochaine récompense en bas.
## Lancer la run : page Équipement (préréglage ou à la main ; l'arme portée décide du
## combo d'auto-attaque) → Valider → page Expertise & talents (talents, 7 certificats
## de maîtrise au plus) → Valider → la run démarre.
## Les arguments de test (--autoplay, --dungeon, --shots...) lancent la run directement.

const RUN_SCENE := "res://scenes/world.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"
## Menu de gauche : identifiant, texte, icône.
const MENU := [
	["play", "Jouer", "play"], ["class", "Classe", "class"], ["equipment", "Équipement", "equipment"],
	["collection", "Collection", "collection"], ["info", "Infos", "info"], ["settings", "Paramètres", "settings"],
	["quit", "Quitter", "quit"],
]

var backdrop: MapBackdrop
var _equip_screen: PageScreen
var _prep: PageScreen  # préparation de la run : Équipement puis Expertise & talents
var _prep_button: Button
var _talents: PageScreen
var _archive: PageScreen
var _info: PageScreen
var _class_dirty := false
var _launching := false
var _grimoire: Grimoire
var _open_screen := ""  # test : écran ouvert au démarrage (--talents, --prep=1, --archive=1, --info)
var _settings: SettingsMenu
var _menu := {}  # identifiant -> MenuWidgets.SideButton
var _current := "play"  # sous-menu affiché
var _sub: VBoxContainer
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


func _ready() -> void:
	var shot := -1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			Profile.selected_class = arg.trim_prefix("--class=")
		elif arg.begins_with("--zone="):
			Profile.selected_zone = arg.trim_prefix("--zone=")
		elif arg.begins_with("--weapon="):
			Profile.select_weapon_type(arg.trim_prefix("--weapon="))
		elif arg in ["--grimoire", "--talents", "--info"] or arg.begins_with("--prep=") or arg.begins_with("--archive="):
			_open_screen = arg.trim_prefix("--")
		elif arg.begins_with("--expertise="):
			# test : expertise donnée à toutes les classes (profil de test uniquement)
			for cid in GameData.classes:
				Profile.expertise[cid] = int(arg.trim_prefix("--expertise="))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class=") or arg.begins_with("--zone=") or arg.begins_with("--weapon=") or arg in ["--grimoire", "--talents", "--info"] \
				or arg.begins_with("--prep=") or arg.begins_with("--archive=") or arg.begins_with("--expertise="):
			continue
		if arg.begins_with("--lobby-shot="):
			shot = float(arg.trim_prefix("--lobby-shot="))
		elif arg.begins_with("--"):
			_start_run()
			return
	_build_scene()
	_grimoire = Grimoire.new()
	add_child(_grimoire)
	_build_ui()
	if _open_screen == "grimoire":
		_grimoire.open(Profile.selected_class)
	elif _open_screen == "talents":
		_talents.open(0)
	elif _open_screen == "info":
		_info.open(0)
	elif _open_screen.begins_with("prep="):
		_prepare_run()
		_prep.show_page(int(_open_screen.trim_prefix("prep=")))
	elif _open_screen.begins_with("archive="):
		_archive.open(int(_open_screen.trim_prefix("archive=")))
	if shot > 0.0:
		await get_tree().create_timer(shot).timeout
		DirAccess.make_dir_recursive_absolute("user://shots")
		get_viewport().get_texture().get_image().save_png("user://shots/lobby.png")
		get_tree().quit()


## Lancer la run : d'abord l'équipement, puis l'expertise.
func _prepare_run() -> void:
	_class_dirty = false
	_prep.set_title("Préparer la run", "%s · %s" % [GameData.class_data(Profile.selected_class).get("name_fr", ""), GameData.zone(Profile.selected_zone).name])
	_prep.open(0)


func _on_prep_validate() -> void:
	if _prep.current_page() == 0:
		_prep.show_page(1)
		return
	_launching = true
	_prep.close_ui()
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


func _show_hero() -> void:
	if backdrop == null:
		return
	for c in backdrop.hero_root.get_children():
		c.queue_free()
	var cls := GameData.class_data(Profile.selected_class)
	if cls.is_empty() or not ResourceLoader.exists(cls.model):
		return
	var model := EdenModel.instantiate(cls.model)
	model.scale = Vector3.ONE * GameData.HERO_SCALE
	model.rotation.y = -0.45  # trois-quarts, tourné vers le menu
	backdrop.hero_root.add_child(model)
	EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, Profile.weapon_code()))
	var ap := EdenModel.find_anim_player(model)
	var battle: String = cls.anims.get("battle", "stand01")
	if ap and ap.has_animation(battle):
		ap.get_animation(battle).loop_mode = Animation.LOOP_LINEAR
		ap.play(battle)


var _tick := 0.0


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
	root.add_child(sp)
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
	root.add_child(badge)
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

	# écrans plein écran
	_equip_screen = _screen("Équipement", [["Équipement", _equipment_page()]])
	# préparation de la run : Équipement → Valider → Expertise & talents → Valider → run
	_prep = _screen("Préparer la run", [["1 · Équipement", _equipment_page()], ["2 · Expertise & talents", TalentsPage.new()]])
	_prep_button = Button.new()
	_prep_button.focus_mode = Control.FOCUS_NONE
	_prep_button.custom_minimum_size = Vector2(300, 44)
	_prep_button.add_theme_font_size_override("font_size", 18)
	_prep_button.add_theme_font_override("font", UiTheme.title_font())
	_prep_button.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.42, 0.28, 0.08, 1.0), UiTheme.GOLD, 2, 8))
	_prep_button.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.55, 0.37, 0.1, 1.0), Color(1, 0.9, 0.6), 2, 8))
	_prep_button.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_prep_button.pressed.connect(_on_prep_validate)
	_prep.add_header_control(_prep_button)
	_prep.page_changed.connect(func(i):
		_prep_button.text = "Valider l'équipement  ▶" if i == 0 else "Valider et lancer la run  ▶")
	_talents = _screen("Expertise & talents", [["Talents et certificats", TalentsPage.new()]])
	_talents.set_title("Expertise & talents", "Talents de classe et certificats de maîtrise (7 au plus)")
	_archive = _screen("Archive", [["Collection", ArchivePages.CollectionPage.new()], ["Apparences", ArchivePages.SkinsPage.new()]])
	_archive.set_title("Collection", "Archive : range tes objets rares, épiques et légendaires pour des bonus permanents ; apparences d'armes")
	_info = _screen("Infos", [["Guide des statistiques", InfoPage.new()]])
	_info.set_title("Infos", "Comment chaque statistique est calculée, ce que vaut un point, formule des dégâts et de la défense")
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


## Menu de gauche : sous-menu (Jouer, Classe, Quitter) ou écran plein écran.
func _on_menu(id: String) -> void:
	match id:
		"equipment":
			_open_panel()
		"collection":
			_archive.open(0)
		"info":
			_info.open(0)
		"settings":
			_settings.open()
		_:
			_show_menu(id)


func _show_menu(id: String) -> void:
	_current = id
	for k in _menu:
		_menu[k].selected = k == ("play" if id == "zones" else id)
	for c in _sub.get_children():
		c.queue_free()
	match id:
		"play":
			_menu_play()
		"class":
			_menu_class()
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
	card.pressed.connect(_prepare_run)
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
	_row("Configuration de la classe", "Talents et certificats de maîtrise (7 au plus)", "expertise", func(): _talents.open(0))
	_row("Armes & équipement", "Préréglages, coffre commun ; l'arme portée décide du combo", "equipment", _open_panel)
	_row("Zone de farm", "%s · niveau %d+" % [zone.get("name", ""), 1 + int(zone.get("level_bonus", 0))], "pin", _show_menu.bind("zones"))
	_row("Grimoire", "Sorts de la classe et combos d'arme", "grimoire", func(): _grimoire.open(Profile.selected_class))


func _menu_class() -> void:
	_sub_title("Classe")
	for id in GameData.classes:
		var cd := GameData.class_data(id)
		var wt := String(GameData.weapon_type(Items.default_weapon_type(id)).get("name", ""))
		var r := _row(String(cd.get("name_fr", id)), "Expertise niv. %d · arme d'origine : %s" % [Profile.expertise_level(id), wt],
			String(cd.get("icon", "")), _select_class.bind(String(id)), 58.0)
		r.mark(id == Profile.selected_class)
	var lore := Hud._label(_sub, String(GameData.class_data(Profile.selected_class).get("lore", "")), 14, UiTheme.MUTED)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.custom_minimum_size = Vector2(420, 0)


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
	if id == Profile.selected_class:
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
	_badge_name.text = String(cd.get("name_fr", cid))
	var w: Dictionary = Profile.equipped.get("weapon", {})
	_badge_sub.text = "Expertise niv. %d · %s" % [Profile.expertise_level(cid), GameData.weapon_type(Items.weapon_type_of(w)).get("name", "") if not w.is_empty() else "sans arme"]
	var zone := GameData.zone(Profile.selected_zone)
	_zone_name.text = String(zone.get("name", ""))
	_zone_sub.text = "Niv. %d+ · zone %d / %d · %d débloquée(s)" % [1 + int(zone.get("level_bonus", 0)), GameData.zone_index(Profile.selected_zone) + 1, GameData.zones.size(), Profile.unlocked_zones]
	_zone_thumb.texture = _snapshot
	var prog := Profile.expertise_progress(cid)
	_reward_bar.max_value = maxf(prog.y, 1.0)
	_reward_bar.value = prog.x
	var lvl := Profile.expertise_level(cid)
	_reward_text.text = ("Expertise %s niv. %d : +2 points de talent" % [cd.get("name_fr", cid), lvl + 1]) if lvl < Profile.EXPERTISE_MAX else "Expertise maximale"
	_footer.text = "Sauvegarde %d · héritage %d objet(s) · %d run(s), %d victoire(s)" % [Profile.slot, Profile.vault.size(), Profile.runs_done, Profile.runs_won]
	_show_menu(_current)


func _equipment_page() -> EquipmentPage:
	var page := EquipmentPage.new()
	page.class_changed.connect(func(): _class_dirty = true)
	return page


## Écran plein écran du lobby ; à sa fermeture, le lobby suit (classe, arme, apparence).
func _screen(t: String, pages: Array) -> PageScreen:
	var s := PageScreen.new(t, 5)
	add_child(s)
	for p in pages:
		s.add_page(p[0], p[1])
	s.closed.connect(func():
		if _launching:
			return
		_class_dirty = false
		_show_hero()  # classe, arme ou apparence ont pu changer
		_refresh_ui())
	return s


func _open_panel() -> void:
	_class_dirty = false
	_equip_screen.set_title("Équipement", "Coffre commun à toutes les classes · 3 préréglages d'équipement par classe · l'arme portée décide du combo d'auto-attaque")
	_equip_screen.open(0)
