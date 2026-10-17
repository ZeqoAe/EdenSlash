extends Node
## Captures du lot CHR-1 (Ninja du Tourbillon, classe maison) : planche du héros (face, trois quarts, profil, dos, gros
## plans du visage, garde) et comparaison avec / sans les ajouts par code (mèches, rubans, traits du visage).
## Les images de ce design restent HORS du dépôt : dossier CHR1_OUT (défaut C:/AI/chr1/captures).
##   godot --path game res://tests/shot_chr1.tscn            (fenêtre obligatoire ; APPDATA détourné conseillé)
##   CHR1_MODE=look|compare|fight (fight : vrai monde, chaque sort en suite d'images <out>/seq/<nom>_NNN.png pour les GIF ;
##   CHR1_ONLY=combo,clone,star,orb,ult pour n'en faire que certains)

const CELL := Vector2i(400, 450)

var _out := "C:/AI/chr1/captures"


func _ready() -> void:
	var o := OS.get_environment("CHR1_OUT")
	if o != "":
		_out = o
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1600, 900)
	await get_tree().process_frame
	var mode := OS.get_environment("CHR1_MODE")
	if mode == "" or mode == "look":
		await _look_plate()
	if mode == "" or mode == "compare":
		await _compare_plate()
	if mode == "fight":
		await _fight()
	if mode == "uv":
		await _uv_plate()
	get_tree().quit()


## Une case : le héros de la classe [param cls] vu de [param yaw] (degrés), caméra à [param dist] m visant [param y] m.
func _cell(grid: Control, cls: Dictionary, label: String, yaw: float, dist: float, y: float, anim := "stand01", t := 0.3, weapon := false, outfit_tex := "") -> void:
	var box := SubViewportContainer.new()
	box.custom_minimum_size = CELL
	box.stretch = true
	grid.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = CELL
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.72, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.82, 0.8, 0.88)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 32.0
	var a := deg_to_rad(yaw)
	cam.position = Vector3(sin(a) * dist, y + 0.15, cos(a) * dist)
	vp.add_child(cam)
	cam.look_at(Vector3(0, y, 0))
	var model := EdenModel.instantiate_hero(cls)
	model.scale = Vector3.ONE * GameData.HERO_SCALE
	vp.add_child(model)
	if outfit_tex != "":
		# essai : texture de la tenue repeinte hors du jeu (fichier hors dépôt), sans la teinture
		var img := Image.load_from_file(outfit_tex)
		var tex := ImageTexture.create_from_image(img)
		for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			if String(mi.get_meta("part", "")) == String(cls.parts[0]):
				for i in mi.mesh.get_surface_count():
					var ov := mi.get_surface_override_material(i)
					if ov is ShaderMaterial:
						var m := (ov as ShaderMaterial).duplicate() as ShaderMaterial
						m.set_shader_parameter("use_dye", 0.0)
						m.set_shader_parameter("use_decal", 0.0)
						m.set_shader_parameter("albedo_tex", tex)
						mi.set_surface_override_material(i, m)
	if weapon and not cls.get("weapon_hidden", false):
		EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, String((cls.get("weapons", [""]) as Array)[0])))
	var ap := EdenModel.find_anim_player(model)
	if ap and ap.has_animation(anim):
		ap.play(anim)
		ap.seek(t, true)
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	box.add_child(l)


func _grid() -> GridContainer:
	var layer := CanvasLayer.new()
	add_child(layer)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 0)
	g.add_theme_constant_override("v_separation", 0)
	layer.add_child(g)
	return g


func _shot(name: String, wait := 1.5) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("[shot_chr1] ", path)


func _look_plate() -> void:
	var cls := GameData.class_data("whirl_ninja")
	var g := _grid()
	_cell(g, cls, "Face", 0.0, 4.2, 1.0)
	_cell(g, cls, "Trois quarts", 40.0, 4.2, 1.0)
	_cell(g, cls, "Profil", 90.0, 4.2, 1.0)
	_cell(g, cls, "Dos", 180.0, 4.2, 1.0)
	_cell(g, cls, "Visage", 0.0, 1.5, 1.55)
	_cell(g, cls, "Visage, trois quarts", 35.0, 1.5, 1.55)
	_cell(g, cls, "Garde (battle10)", 30.0, 4.2, 1.0, "battle10", 0.2, true)
	_cell(g, cls, "Course (move02)", 60.0, 4.2, 1.0, "move02", 0.3, true)
	await _shot("chr1_look_plate")
	g.get_parent().queue_free()


## Même héros : apparence d'Eden seule (tenue et coiffure teintes) puis chaque ajout par code.
func _compare_plate() -> void:
	var base := GameData.class_data("whirl_ninja").duplicate(true)
	var g := _grid()
	var steps: Array = [["Classe d'Eden voisine (Artiste martial)", GameData.class_data("martial_artist")]]
	var c0 := base.duplicate(true)
	c0["look"] = {}
	steps.append(["Pièces d'Eden sans teinture", c0])
	var c1 := base.duplicate(true)
	c1.look = {"dye": base.look.dye, "hair_tint": base.look.hair_tint, "hair_gain": base.look.hair_gain, "band": base.look.band}
	steps.append(["+ teintures, bandeau par code", c1])
	var c2 := c1.duplicate(true)
	c2.look["face_marks"] = base.look.face_marks
	steps.append(["+ traits du visage", c2])
	var c3 := c2.duplicate(true)
	c3.look["spikes"] = base.look.spikes
	steps.append(["+ mèches en pointes", c3])
	steps.append(["+ rubans à ressort (complet)", base])
	for st in steps:
		_cell(g, st[1], String(st[0]), 30.0, 3.0, 1.15)
	_cell(g, base, "Complet, visage", 20.0, 1.5, 1.55)
	_cell(g, base, "Complet, dos", 160.0, 3.0, 1.15)
	await _shot("chr1_compare_plate")
	g.get_parent().queue_free()


# --- combat : suites d'images (GIF assemblés par tools/art/chr1_gif.py, hors dépôt) ------------------------------------
var world: Node
var player: Player


func _seq(name: String, frames: int, step: float) -> void:
	DirAccess.make_dir_recursive_absolute(_out + "/seq")
	for i in frames:
		await get_tree().create_timer(step).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/seq/%s_%03d.png" % [_out, name, i])
	print("[shot_chr1] suite ", name, " (", frames, " images)")


func _foes(n: int, dist: float, moving := true) -> void:
	for m in get_tree().get_nodes_in_group("monsters") + get_tree().get_nodes_in_group("heroes").filter(func(x): return NinjaArts.is_double(x)):
		m.queue_free()
	await get_tree().physics_frame
	var roster: Array = world.director._roster
	var fwd := player.forward()
	for i in n:
		var m: Monster = world.director._spawn_monster(int(roster[i % roster.size()]), player.global_position + fwd.rotated(Vector3.UP, (i - (n - 1) * 0.5) * 0.45) * dist, 5)
		m.max_hp *= 40.0
		m.hp = m.max_hp
		m.set_physics_process(moving)


func _punches(n: int) -> void:
	for i in n:
		player._state = "idle"
		var near := player.nearest_monster(10.0)
		player._start_attack(near.global_position if near else player.global_position + player.forward())
		await get_tree().create_timer(0.36).timeout


func _cast(id: int) -> void:
	Run.skills = [{"id": id, "rank": 1}]
	player.skill_ready_at.clear()
	player._state = "idle"
	player._skill_lock_until = 0.0
	var near := player.nearest_monster(20.0)
	player.use_skill(0, near.global_position if near else player.global_position + player.forward() * 6.0)


func _fight() -> void:
	get_window().size = Vector2i(1280, 720)
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "whirl_ninja"
	Run.start("whirl_ninja")
	world = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(6.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	player = world.player
	player.dev_invincible = true
	world.director.set_process(false)
	world.director.set_physics_process(false)
	world.rig.distance = float(OS.get_environment("CHR1_CAM")) if OS.get_environment("CHR1_CAM") != "" else 10.0
	world.rig.allow_input = false
	var only := OS.get_environment("CHR1_ONLY")
	var want := func(k: String) -> bool: return only == "" or k in only.split(",")
	if want.call("combo"):
		Settings.set_v("interface", "fx_intensity", 0.5)  # le minimum des Paramètres : on voit les gestes sous les impacts
		await _foes(2, 2.6, false)
		player.face_direction(player.forward(), 1.0)
		_punches(6)
		await _seq("combo", 26, 0.05)
		Settings.set_v("interface", "fx_intensity", 1.0)
	if want.call("clone"):
		await _foes(5, 6.0)
		_cast(990101)
		await _seq("clone", 34, 0.12)
	if want.call("star"):
		await _foes(5, 9.0, false)
		_cast(990102)
		await _seq("star", 16, 0.05)
	if want.call("orb"):
		await _foes(3, 6.5, false)
		_cast(990103)
		await _seq("orb", 24, 0.06)
	if want.call("ult"):
		await _foes(6, 8.0, false)
		_cast(990104)
		await _seq("ult", 40, 0.07)
	if want.call("still"):
		await _foes(6, 7.0)
		_cast(990101)
		await get_tree().create_timer(1.2).timeout
		_cast(990104)
		await get_tree().create_timer(1.0).timeout
		await _shot("chr1_fight_still", 0.1)



## Essai de texture repeinte par IA (atlas d'UV de la tenue en image vers image, C:/AI/chr1/uvpaint) : face et dos.
func _uv_plate() -> void:
	var cls := GameData.class_data("whirl_ninja")
	var g := _grid()
	var dir := "C:/AI/chr1/uvpaint/"
	for e in [["Teinture du jeu (masque R/V/B)", ""], ["IA, débruitage 0,3", dir + "repeint_30_512.png"],
			["IA, débruitage 0,5", dir + "repeint_50_512.png"], ["IA, débruitage 0,7", dir + "repeint_70_512.png"]]:
		_cell(g, cls, String(e[0]), 25.0, 3.2, 0.95, "stand01", 0.3, false, String(e[1]))
	for e in [["Teinture du jeu, dos", ""], ["IA 0,3, dos", dir + "repeint_30_512.png"], ["IA 0,5, dos", dir + "repeint_50_512.png"],
			["IA 0,7, dos", dir + "repeint_70_512.png"]]:
		_cell(g, cls, String(e[0]), 200.0, 3.2, 0.95, "stand01", 0.3, false, String(e[1]))
	await _shot("chr1_uv_plate")
	g.get_parent().queue_free()
