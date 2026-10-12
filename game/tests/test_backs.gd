extends Node3D
## Planche des accessoires cosmétiques (dos, tête) sur le héros :
## godot --path game res://tests/test_backs.tscn -- [back|head|skin] [début] [nombre]
## (skin : apparences d'armes d'Eden tenues en main)
## Image : user://shots/backs.png (de dos, trois quarts).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cat: String = args[0] if not args.is_empty() else "back"
	var start := int(args[1]) if args.size() > 1 else 0
	var count := int(args[2]) if args.size() > 2 else 20
	var list := (GameData.collection.filter(func(x): return x.has("skin")) if cat == "skin" 		else GameData.cosmetics.filter(func(c): return String(c.get("cat", "")) == cat)).slice(start, start + count)
	var cam := Camera3D.new()
	add_child(cam)
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
	var cols := 10
	var n := list.size()
	var rows := ceili(float(n) / cols)
	get_viewport().size = Vector2i(200 * cols, 300 * rows)
	var cls := GameData.class_data("warrior")
	for i in n:
		var c: Dictionary = list[i]
		var model := EdenModel.instantiate_hero(cls, "", [] if cat == "skin" else [String(c.outfit)])
		add_child(model)
		if cat == "skin":
			EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, String(c.code)))
		model.position = Vector3((i % cols) * 1.4, -float(i / cols) * 2.2, 0)
		model.rotation.y = 0.5 if cat in ["skin", "head"] else PI * 0.8
		var ap := EdenModel.find_anim_player(model)
		var anim := String(cls.get("anims", {}).get("battle", "stand01")) if cat == "skin" else "stand01"
		if ap and ap.has_animation(anim):
			ap.play(anim)
		var lbl := Label3D.new()
		lbl.text = "%d %s" % [start + i, String(c.get("code", c.id)) if cat == "skin" else String(c.id)]
		lbl.font_size = 36
		lbl.pixel_size = 0.004
		lbl.position = Vector3((i % cols) * 1.4, -float(i / cols) * 2.2 - 0.2, 0.6)
		add_child(lbl)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 2.2 * rows
	cam.position = Vector3((cols - 1) * 1.4 * 0.5, 0.9 - (rows - 1) * 1.1, 8.0)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/backs.png")
	print("planche : ", ProjectSettings.globalize_path("user://shots/backs.png"))
	get_tree().quit()
