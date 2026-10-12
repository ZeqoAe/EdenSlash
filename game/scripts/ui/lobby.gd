extends Node3D
## Lobby : choix de la classe et de la zone, archive, infos, lancement d'une run.
## Lancer la run : page Équipement (préréglage ou à la main ; l'arme portée décide du
## combo d'auto-attaque) → Valider → page Expertise & talents (talents, 7 certificats
## de maîtrise au plus) → Valider → la run démarre.
## Les arguments de test (--autoplay, --dungeon, --shots...) lancent la run directement.

const ACCENT := Color(0.98, 0.78, 0.35)
const RUN_SCENE := "res://scenes/world.tscn"
# classes d'Eden prévues (seul le Samouraï est jouable pour l'instant)
const ROSTER := [
	["samurai", "Samouraï"], ["warrior", "Guerrier"], ["magician", "Magicien"],
	["hunter", "Chasseur"], ["cleric", "Clerc"], ["thief", "Voleur"],
]

var _hero_root: Node3D
var _cam_pivot: Node3D
var _equip_screen: PageScreen
var _prep: PageScreen  # préparation de la run : Équipement puis Expertise & talents
var _prep_button: Button
var _talents: PageScreen
var _archive: PageScreen
var _info: PageScreen
var _class_dirty := false
var _launching := false
var _gold: Label
var _reset_button: Button
var _zone_box: GridContainer
var _grimoire: Grimoire
var _open_screen := ""  # test : écran ouvert au démarrage (--talents, --prep=1, --archive=1, --info)
var _run_button: Button
var _reset_armed_at := -10.0
var _settings: SettingsMenu


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
	Run.start(Profile.selected_class)
	get_tree().change_scene_to_file.call_deferred(RUN_SCENE)


# --- décor 3D ------------------------------------------------------------------------
func _build_scene() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.2, 0.25, 0.5)
	sm.sky_horizon_color = Color(0.85, 0.65, 0.55)
	sm.ground_bottom_color = Color(0.1, 0.1, 0.15)
	sm.ground_horizon_color = Color(0.6, 0.5, 0.5)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.72, 0.8)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_color = Color(1.0, 0.88, 0.75)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = 3.0
	disk.bottom_radius = 3.2
	disk.height = 0.3
	ground.mesh = disk
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = load("res://assets/terrain/akgrass_05.png")
	gm.uv1_scale = Vector3(3, 3, 1)
	gm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	ground.material_override = gm
	ground.position.y = -0.15
	add_child(ground)
	_hero_root = Node3D.new()
	add_child(_hero_root)
	_show_hero()
	_cam_pivot = Node3D.new()
	add_child(_cam_pivot)
	var cam := Camera3D.new()
	cam.position = Vector3(1.6, 1.6, 4.6)
	cam.fov = 40.0
	_cam_pivot.add_child(cam)
	cam.look_at(Vector3(-1.3, 1.0, 0))


func _show_hero() -> void:
	for c in _hero_root.get_children():
		c.queue_free()
	var cls := GameData.class_data(Profile.selected_class)
	if cls.is_empty() or not ResourceLoader.exists(cls.model):
		return
	var model := EdenModel.instantiate(cls.model)
	model.scale = Vector3.ONE * GameData.HERO_SCALE
	_hero_root.add_child(model)
	EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, Profile.weapon_code()))
	var ap := EdenModel.find_anim_player(model)
	var battle: String = cls.anims.get("battle", "stand01")
	if ap and ap.has_animation(battle):
		ap.get_animation(battle).loop_mode = Animation.LOOP_LINEAR
		ap.play(battle)


func _process(delta: float) -> void:
	if _hero_root:
		_hero_root.rotation.y += delta * 0.35
	if _gold:
		_gold.text = "Héritage : %d objet(s)   ·   Réserve : %d fourniture(s)   ·   Runs : %d (%d victoires)   ·   Meilleur niveau : %d" % [
			Profile.vault.size(), Profile.stash_count(), Profile.runs_done, Profile.runs_won, Profile.best_level]
	if _reset_button and _reset_armed_at > 0.0 and _now() - _reset_armed_at > 4.0:
		_reset_armed_at = -10.0
		_reset_button.text = "Nouvelle partie (tout effacer)"


# --- interface ---------------------------------------------------------------------
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.position = Vector2(60, 30)
	v.add_theme_constant_override("separation", 7)
	root.add_child(v)
	var title := Hud._label(v, "EDEN SLASH", 52, ACCENT)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	Hud._label(v, "Hack and slash dans l'univers d'Eden Eternal", 18, Color(0.95, 0.92, 1.0))
	Hud._label(v, "Classe", 22, ACCENT)
	var classes := GridContainer.new()
	classes.columns = 3
	classes.add_theme_constant_override("h_separation", 10)
	classes.add_theme_constant_override("v_separation", 10)
	v.add_child(classes)
	for entry in ROSTER:
		classes.add_child(_class_card(entry[0], entry[1]))
	var cls := GameData.class_data(Profile.selected_class)
	var lore := Hud._label(v, cls.get("lore", ""), 15, Color(0.9, 0.9, 0.95))
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore.custom_minimum_size = Vector2(560, 0)
	Hud._label(v, "Les sorts suivent la classe ; le combo d'auto-attaque suit l'arme équipée (choisie au lancement de la run).", 14, UiTheme.MUTED)
	Hud._label(v, "Zone", 22, ACCENT)
	var zones := GridContainer.new()
	zones.columns = 3
	zones.add_theme_constant_override("h_separation", 10)
	zones.add_theme_constant_override("v_separation", 10)
	v.add_child(zones)
	_zone_box = zones
	_refresh_zones()
	_run_button = _big_button(v, "", _prepare_run)
	_refresh_run_button()
	# boutons secondaires sur deux colonnes
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 7)
	v.add_child(grid)
	for spec in [["Équipement", _open_panel], ["Grimoire (sorts, combos)", func(): _grimoire.open(Profile.selected_class)],
			["Expertise & talents", func(): _talents.open(0)], ["Archive (collection, apparences)", func(): _archive.open(0)],
			["Infos : statistiques et dégâts", func(): _info.open(0)], ["Paramètres", func(): _settings.open()],
			["Nouvelle partie (tout effacer)", _on_reset], ["Quitter", func(): get_tree().quit()]]:
		var b := _big_button(grid, spec[0], spec[1])
		b.custom_minimum_size = Vector2(276, 42)
		b.add_theme_font_size_override("font_size", 16)
		if spec[0].begins_with("Nouvelle partie"):
			_reset_button = b
	_gold = Hud._label(v, "", 15, ACCENT)
	var help := Hud._label(root, "Run : chaque run repart de zéro. Monte de niveau, réunis 3 sceaux, affronte le boss. À la fin, garde 1 objet en héritage (avec son amélioration).", 14, Color(1, 1, 1, 0.7))
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(60, -34)
	layer.add_child(root)

	# équipement : page plein écran (préréglages par classe, coffre commun)
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
	_archive.set_title("Archive", "Range tes objets rares, épiques et légendaires : bonus permanents pour toutes les classes")
	_info = _screen("Infos", [["Guide des statistiques", InfoPage.new()]])
	_info.set_title("Infos", "Comment chaque statistique est calculée, ce que vaut un point, formule des dégâts et de la défense")
	_settings = SettingsMenu.new()
	add_child(_settings)


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
		if _class_dirty:
			get_tree().reload_current_scene()  # classe changée : tout le lobby suit
		else:
			_show_hero())
	return s


func _open_panel() -> void:
	_class_dirty = false
	_equip_screen.set_title("Équipement", "Coffre commun à toutes les classes · 3 préréglages d'équipement par classe · l'arme portée décide du combo d'auto-attaque")
	_equip_screen.open(0)


func _class_card(id: String, label: String) -> Control:
	var available := not GameData.class_data(id).is_empty()
	var b := Button.new()
	b.custom_minimum_size = Vector2(180, 52)
	b.text = label if available else "%s\n(bientôt)" % label
	b.disabled = not available
	b.add_theme_font_size_override("font_size", 17)
	var sb := Hud.style(Color(0.12, 0.1, 0.2, 0.95))
	if id == Profile.selected_class:
		sb.border_color = ACCENT
		sb.set_border_width_all(3)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("disabled", Hud.style(Color(0.08, 0.08, 0.1, 0.8)))
	b.add_theme_stylebox_override("hover", Hud.style(Color(0.22, 0.18, 0.34)))
	var icon_path := String(GameData.class_data(id).get("icon", ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
	b.pressed.connect(func():
		Profile.selected_class = id
		Profile.save_profile()
		_show_hero())
	return b


## Zones : débloquées dans l'ordre en battant le boss de la précédente.
func _refresh_zones() -> void:
	for c in _zone_box.get_children():
		c.queue_free()
	if not Profile.zone_unlocked(Profile.selected_zone):
		Profile.selected_zone = "limestone"
	for i in GameData.zones.size():
		var z: Dictionary = GameData.zones[i]
		var open := i < Profile.unlocked_zones
		var b := Button.new()
		b.custom_minimum_size = Vector2(180, 50)
		b.text = "%s\nNiv. %d+" % [z.name, 1 + int(z.get("level_bonus", 0))] if open else "🔒 %s" % z.name
		b.disabled = not open
		b.tooltip_text = "" if open else "Bats le boss de %s pour débloquer cette zone." % GameData.zones[i - 1].name
		b.add_theme_font_size_override("font_size", 15)
		var sb := Hud.style(Color(0.12, 0.1, 0.2, 0.95))
		if z.id == Profile.selected_zone:
			sb.border_color = ACCENT
			sb.set_border_width_all(3)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("disabled", Hud.style(Color(0.08, 0.08, 0.1, 0.8)))
		b.add_theme_stylebox_override("hover", Hud.style(Color(0.22, 0.18, 0.34)))
		var zid: String = z.id
		b.pressed.connect(func():
			Profile.selected_zone = zid
			Profile.save_profile()
			_refresh_zones()
			_refresh_run_button())
		_zone_box.add_child(b)


func _refresh_run_button() -> void:
	if _run_button:
		_run_button.text = "▶  Lancer la run — %s" % GameData.zone(Profile.selected_zone).name


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Nouvelle partie : 2 clics en 4 s (héritage et statistiques effacés).
func _on_reset() -> void:
	if _reset_armed_at < 0.0:
		_reset_armed_at = _now()
		_reset_button.text = "Confirmer : effacer l'héritage et les statistiques ?"
		return
	_reset_armed_at = -10.0
	_reset_button.text = "Nouvelle partie (tout effacer)"
	Profile.reset_all()
	_show_hero()


func _big_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", Hud.style(Color(0.16, 0.12, 0.26, 0.95)))
	var hover := Hud.style(Color(0.28, 0.2, 0.42, 1.0))
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b
