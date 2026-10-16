extends Node3D
## Captures des coffres du Battle royale (passe BR2) : planche de modèles, puis coffres de chaque qualité vus de près,
## à 25 m et à 50 m sur la carte du Battle royale (user://shots/br2_*.png).
## godot --path game res://tests/shot_br2.tscn -- lineup uc001 uc002 …   (planche de modèles)
## godot --path game res://tests/shot_br2.tscn -- map [graine]           (coffres sur la carte du Battle royale)
## godot --path game res://tests/shot_br2.tscn -- tiers                  (les quatre qualités côte à côte, de près)


func _env(sky := Color(0.55, 0.7, 0.9)) -> void:
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = sky
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	we.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _save(name: String) -> void:
	for f in 8:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/br2_%s.png" % name)
	print("[br2] ", name)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := String(args[0]) if args.size() > 0 else "tiers"
	_env()
	var cam := Camera3D.new()
	cam.fov = 50
	cam.far = 1200.0
	add_child(cam)
	cam.make_current()
	if mode == "lineup":
		var ids := args.slice(1)
		var cols := 8 if ids.size() > 12 else 4
		for i in ids.size():
			var id := String(ids[i])
			var path := "res://assets/maps/objects/%s.glb" % id
			var tex := ""
			if id.begins_with("m"):
				path = "res://assets/monsters/%s/%s.glb" % [id, id]
				tex = "res://assets/monsters/textures/%s01.png" % id
			if not ResourceLoader.exists(path):
				continue
			var n := EdenModel.instantiate(path, tex if ResourceLoader.exists(tex) else "")
			add_child(n)
			n.position = Vector3((i % cols) * 3.0, 0, (i / cols) * 3.0)
			var l := Label3D.new()
			l.text = id
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.pixel_size = 0.012
			l.no_depth_test = true
			l.position = n.position + Vector3(0, 2.2, 0)
			add_child(l)
		var rows := ceili(ids.size() / float(cols))
		var mid := Vector3(cols * 1.5 - 1.5, 0, rows * 1.5 - 1.5)
		cam.global_position = mid + Vector3(0, rows * 1.9 + 3.0, rows * 1.3 + 3.0)
		cam.look_at(mid, Vector3.UP)
		await _save("lineup")
	elif mode == "tiers":
		var floor_mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(80, 80)
		floor_mi.mesh = pm
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.32, 0.45, 0.25)
		floor_mi.material_override = fm
		add_child(floor_mi)
		var tiers: int = 4
		for t in tiers:
			var it: Interactable = ProcMap.make_royale_chest(t)
			add_child(it)
			it.position = Vector3(t * 7.0, 0, 0)
		var mid := Vector3((tiers - 1) * 3.5, 0, 0)
		for d in [[10.0, 0.9, "10m"], [28.0, 0.9, "28m"], [55.0, 0.9, "55m"]]:
			cam.global_position = mid + Vector3(0, float(d[0]) * 0.8, float(d[0]) * float(d[1]))
			cam.look_at(mid, Vector3.UP)
			await _save("tiers_" + String(d[2]))
	else:
		var seed_value := int(args[1]) if args.size() > 1 else 1234
		var m := ProcMap.new()
		m.biome = "limestone"
		add_child(m)
		m.generate_royale(seed_value)
		var ks := [0, 0, 0]
		for k in m.chests.size():
			var tier := int(m.chest_tiers[k])
			if ks[tier] >= 2:
				continue
			ks[tier] += 1
			var c: Vector3 = m.chests[k]
			c.y = m.height_at(c.x, c.z)
			for d in [30.0, 55.0]:
				# camera de jeu : plongeante, derrière le héros
				cam.global_position = c + Vector3(0, d * 0.75, d * 0.65)
				cam.look_at(c + Vector3(0, 0, -d * 0.1), Vector3.UP)
				await _save("map_t%d_%d_%dm" % [tier, ks[tier], int(d)])
		cam.global_position = Vector3(m.size * 0.5, 420.0, m.size * 0.5 + 40.0)
		cam.look_at(Vector3(m.size * 0.5, 0, m.size * 0.5), Vector3.UP)
		await _save("map_overview")
	get_tree().quit()
