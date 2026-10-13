extends Node3D
## Icônes des cosmétiques sans icône d'Eden (pièces « secrètes ») : rendu du héros portant la
## pièce (de dos pour les ailes, en buste pour la tête), 128 px, fond transparent :
## godot --path game res://tests/make_cosmetic_icons.tscn  -> res://assets/ui/items/cos_<id>.png
## (relu par tools/build_cosmetics.py).

func _ready() -> void:
	var list := GameData.cosmetics.filter(func(c): return String(c.get("icon", "")) == "")
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.85, 0.82, 0.9)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	var cls := GameData.class_data("warrior")
	var done := 0
	for c in list:
		var cat := String(c.get("cat", "body"))
		var model := EdenModel.instantiate_hero(cls, String(c.outfit) if cat == "body" else "", [] if cat == "body" else [String(c.outfit)])
		vp.add_child(model)
		model.rotation.y = PI if cat == "back" else 0.35
		# cadrage fixe centré sur le héros (les boîtes des maillages animés sont trompeuses)
		var center := Vector3(0, 0.75, 0)
		var dist := 2.6
		if cat == "back":
			center = Vector3(0, 0.95, 0)
			dist = 4.2
		elif cat == "head":
			center = Vector3(0, 1.3, 0)
			dist = 1.4
		cam.transform = Transform3D(Basis(), center + Vector3(0, 0.15, dist)).looking_at(center)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(128, 128, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/ui/items/cos_%s.png" % String(c.id))
		model.queue_free()
		done += 1
	print("icônes rendues : ", done)
	get_tree().quit()
