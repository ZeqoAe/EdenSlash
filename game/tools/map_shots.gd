extends Node3D
## Vues de la carte d'une run (graine fixe) : vue d'ensemble, lieux de décor, coffres, lieux
## utilisables, bord de chemin. Pour juger la densité de la carte sans jouer.
## godot --path game res://tools/map_shots.tscn -- [graine] [zone]  -> user://shots/map_<n>.png

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := int(args[0]) if args.size() > 0 else 1234
	var zone := String(args[1]) if args.size() > 1 else "limestone"
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.55, 0.7, 0.9)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	we.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var m := ProcMap.new()
	m.biome = String(GameData.zone(zone).get("biome", "limestone"))
	add_child(m)
	m.generate_run(seed_value)
	var cam := Camera3D.new()
	cam.fov = 50
	cam.far = 1200.0
	add_child(cam)
	cam.make_current()
	var views: Array = [[Vector3(m.size * 0.5, 0, m.size * 0.5), 420.0, 0.0]]
	for k in mini(4, m.sites.size()):
		views.append([m.sites[k].pos, 34.0, 0.8])
	for k in mini(2, m.chests.size()):
		views.append([m.chests[k], 24.0, 0.8])
	for k in mini(3, m.stations.size()):
		views.append([m.stations[k * 3 % m.stations.size()].pos, 22.0, 0.8])
	for camp in m.camps:
		if camp.elite:
			views.append([camp.pos, 30.0, 0.8])
			break
	views.append([m.start, 40.0, 0.8])
	DirAccess.make_dir_recursive_absolute("user://shots")
	for i in views.size():
		var c: Vector3 = views[i][0]
		var d: float = views[i][1]
		var tilt: float = views[i][2]
		c.y = m.height_at(c.x, c.z)
		cam.global_position = c + Vector3(0, d, d * tilt)
		cam.look_at(c, Vector3.FORWARD if tilt == 0.0 else Vector3.UP)
		for f in 6:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://shots/map_%d.png" % i)
		print("vue %d : %s" % [i, c])
	get_tree().quit()
