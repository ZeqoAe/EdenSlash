extends Node3D
## Planche des héros modulaires (corps commun + tenue + cheveux + arme) :
## godot --path game res://tests/test_outfit.tscn -- [classe,classe...] [animation]
## Image : user://shots/outfits.png (une colonne par classe).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var ids: Array = Array(args[0].split(",")) if not args.is_empty() and args[0] != "all" else GameData.classes.keys()
	var anim_name: String = args[1] if args.size() > 1 else ""
	var cam := Camera3D.new()
	add_child(cam)
	var n := ids.size()
	var cols := mini(n, 10)
	var rows := ceili(float(n) / cols)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 3.2 * rows
	cam.position = Vector3((cols - 1) * 1.1 * 0.5, 1.6 * rows - 1.0 - (rows - 1) * 1.6 + (rows - 1) * 1.6 * 0.5, 8.0)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.32)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	add_child(env)
	get_viewport().size = Vector2i(220 * cols, 330 * rows)
	for i in n:
		var cls := GameData.class_data(String(ids[i]))
		if cls.is_empty():
			continue
		var model := EdenModel.instantiate_hero(cls)
		add_child(model)
		model.position = Vector3((i % cols) * 1.1, -(i / cols) * 3.2 * 0.5 * 2.0 / 2.0 * 1.0 - (i / cols) * 0.0, 0)
		model.position.y = -float(i / cols) * 3.2
		var wt := GameData.weapon_type(String(cls.get("weapon_type", "")))
		var ws: Array = wt.get("weapons", [])
		if not ws.is_empty():
			EdenModel.attach_weapon(model, ws[0])
		var ap := EdenModel.find_anim_player(model)
		if ap:
			var a := anim_name if anim_name != "" else String(wt.get("battle", cls.get("anims", {}).get("battle", "stand01")))
			if ap.has_animation(a):
				ap.play(a)
		var lbl := Label3D.new()
		lbl.text = String(cls.get("name_fr", ids[i]))
		lbl.font_size = 40
		lbl.pixel_size = 0.004
		lbl.position = Vector3(0, -0.25, 0.5)
		model.add_child(lbl)
	cam.position = Vector3((cols - 1) * 1.1 * 0.5, 0.8 - (rows - 1) * 1.6, 8.0)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/outfits.png")
	print("planche : ", ProjectSettings.globalize_path("user://shots/outfits.png"))
	get_tree().quit()
