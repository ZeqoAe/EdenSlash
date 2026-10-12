extends Node3D
## Planche des auras d'Eden (pierres étoilées, pierres de lune) autour du héros :
## godot --path game res://tests/test_aura.tscn -- [effet,effet...] [secondes]
## Image : user://shots/auras.png (un héros par effet, vu de trois quarts).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var names: Array = Array(args[0].split(",")) if not args.is_empty() and args[0] != "" else ["s80213", "s80512", "s80613", "s80711"]
	var t := float(args[1]) if args.size() > 1 else 1.5
	var cam := Camera3D.new()
	add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.13, 0.17)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	add_child(env)
	var n := names.size()
	get_viewport().size = Vector2i(380 * n, 520)
	var cls := GameData.class_data("warrior")
	for i in n:
		var root := Node3D.new()
		root.position = Vector3(i * 3.2, 0, 0)
		add_child(root)
		var model := EdenModel.instantiate_hero(cls)
		model.scale = Vector3.ONE * GameData.HERO_SCALE
		root.add_child(model)
		EdenFx.attach(root, String(names[i]), GameData.HERO_SCALE)
		var lbl := Label3D.new()
		lbl.text = String(names[i])
		lbl.font_size = 48
		lbl.pixel_size = 0.005
		lbl.position = Vector3(0, -0.3, 1.0)
		root.add_child(lbl)
	cam.fov = 40
	cam.position = Vector3((n - 1) * 3.2 * 0.5, 2.6, 6.0 + n * 1.2)
	cam.look_at(Vector3((n - 1) * 3.2 * 0.5, 1.1, 0))
	await get_tree().create_timer(t).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/auras.png")
	print("planche : ", ProjectSettings.globalize_path("user://shots/auras.png"))
	get_tree().quit()
