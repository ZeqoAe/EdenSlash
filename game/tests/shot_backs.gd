extends Node3D
## Gros plan de quelques accessoires de dos, de dos et de profil (diagnostic) :
## godot --path game res://tests/shot_backs.tscn -- back_t845a,back_x6022a
## Image : user://shots/shot_backs.png

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var ids: PackedStringArray = (args[0] if not args.is_empty() else "back_x6022a").split(",")
	var grid := "grid" in args  # planche de dos uniquement : 10 par ligne
	if args[0].begins_with("range="):
		var r := args[0].trim_prefix("range=").split("-")
		ids = PackedStringArray(GameData.cosmetics.filter(func(x): return String(x.get("cat", "")) == "back").slice(int(r[0]), int(r[1])).map(func(x): return String(x.id)))
	EdenModel.use_back_fix = not ("nofix" in args)
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
	var cls := GameData.class_data("warrior")
	var n := ids.size()
	get_viewport().size = Vector2i(400 * mini(n, 10), 400 * ceili(n / 10.0)) if grid else Vector2i(400 * n, 800)
	for i in n:
		var c: Dictionary = {}
		for x in GameData.cosmetics:
			if String(x.id) == ids[i]:
				c = x
		if c.is_empty():
			continue
		for view in (1 if grid else 2):
			var model: Node3D
			if "raw" in args:
				# la pièce seule, telle qu'exportée (repère d'Eden, z vers le haut)
				model = (load(String(c.outfit)) as PackedScene).instantiate()
			else:
				model = EdenModel.instantiate_hero(cls, "", [String(c.outfit)])
			add_child(model)
			for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				if ("onlyrigid" in args and mi.skin != null and mi.has_meta("part")) or ("onlyskin" in args and mi.skin == null and mi.has_meta("part")):
					mi.visible = false
			model.position = Vector3((i % 10) * 4.5, -(i / 10) * 4.5, 0) if grid else Vector3(i * 4.5, -view * 4.5, 0)
			model.rotation.y = PI if view == 0 else PI * 0.5
			var ap := EdenModel.find_anim_player(model)
			if ap and ap.has_animation("stand01") and not ("noanim" in args):
				ap.play("stand01")
		var lbl := Label3D.new()
		lbl.text = "%s\n%s" % [ids[i], String(c.name).left(28)]
		lbl.font_size = 40
		lbl.pixel_size = 0.005
		lbl.position = Vector3((i % 10) * 4.5, -(i / 10) * 4.5 + 2.0, 1.0) if grid else Vector3(i * 4.5, 3.4, 1.0)
		add_child(lbl)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.5
	cam.position = Vector3((n - 1) * 2.25, -1.2, 10.0)
	if grid:
		cam.size = 4.5 * ceili(n / 10.0)
		cam.position = Vector3((mini(n, 10) - 1) * 2.25, 0.4 - (ceili(n / 10.0) - 1) * 2.25, 10.0)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/shot_backs.png")
	get_tree().quit()
