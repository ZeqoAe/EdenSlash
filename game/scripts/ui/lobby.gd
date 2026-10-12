extends Node3D
## Lobby : choix de la classe, équipement, lancement d'une run.
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
var _panel_layer: CanvasLayer
var _gold: Label


func _ready() -> void:
	var shot := -1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lobby-shot="):
			shot = float(arg.trim_prefix("--lobby-shot="))
		elif arg.begins_with("--"):
			_start_run()
			return
	_build_scene()
	_build_ui()
	if shot > 0.0:
		await get_tree().create_timer(shot).timeout
		DirAccess.make_dir_recursive_absolute("user://shots")
		get_viewport().get_texture().get_image().save_png("user://shots/lobby.png")
		get_tree().quit()


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
		_gold.text = "Or : %d   ·   Runs : %d (%d victoires)   ·   Meilleur niveau : %d" % [
			Profile.gold, Profile.runs_done, Profile.runs_won, Profile.best_level]


# --- interface ---------------------------------------------------------------------
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.position = Vector2(60, 60)
	v.add_theme_constant_override("separation", 14)
	root.add_child(v)
	var title := Hud._label(v, "EDEN SLASH", 64, ACCENT)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	Hud._label(v, "Hack and slash dans l'univers d'Eden Eternal", 18, Color(0.95, 0.92, 1.0))
	Hud._label(v, " ", 10, Color.WHITE)
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
	Hud._label(v, " ", 6, Color.WHITE)
	_big_button(v, "▶  Lancer la run — Limestone Mtn.", _start_run)
	_big_button(v, "Personnage & équipement", _open_panel)
	_big_button(v, "Quitter", func(): get_tree().quit())
	_gold = Hud._label(v, "", 15, ACCENT)
	var help := Hud._label(root, "Run : monte de niveau sur Limestone Mtn., choisis une carte à chaque niveau (compétences, améliorations, passifs), puis affronte le donjon et son boss.", 14, Color(1, 1, 1, 0.7))
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(60, -50)
	layer.add_child(root)

	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 5
	add_child(_panel_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_layer.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-490, -320)
	_panel_layer.add_child(box)
	box.add_child(CharacterPanel.new())
	var close := Button.new()
	close.text = "Fermer"
	close.custom_minimum_size = Vector2(0, 44)
	close.pressed.connect(func():
		_panel_layer.visible = false
		_show_hero())
	box.add_child(close)
	_panel_layer.visible = false


func _open_panel() -> void:
	_panel_layer.visible = true


func _class_card(id: String, label: String) -> Control:
	var available := not GameData.class_data(id).is_empty()
	var b := Button.new()
	b.custom_minimum_size = Vector2(180, 64)
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


func _big_button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 54)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", Hud.style(Color(0.16, 0.12, 0.26, 0.95)))
	var hover := Hud.style(Color(0.28, 0.2, 0.42, 1.0))
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(cb)
	parent.add_child(b)
