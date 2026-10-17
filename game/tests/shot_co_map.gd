extends Node3D
## Captures du lot CO-B (carte du Colisée) : chacune des 6 arènes vue d'en haut, anneau de feu à 37 s (16 m, prochain à 11 m
## en pointillés), piliers, fleurs de vie ; puis la carte entière. Fichiers user://shots/co_map_<largeur>_*.png.
## APPDATA détourné : godot --path game res://tests/shot_co_map.tscn   (CO_MAP_N=8 : le Grand tournoi)

var cam: Camera3D


func _shot(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	var w := get_window().size.x
	get_viewport().get_texture().get_image().save_png("user://shots/co_map_%d_%s.png" % [w, name])
	print("[shot] co_map_%d_%s" % [w, name])


func _env() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.58, 0.9)
	sky_mat.sky_horizon_color = Color(0.82, 0.88, 0.95)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.78, 0.82)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.82
	Gfx.style_sky(sky_mat)
	Gfx.style_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)


func _ready() -> void:
	Settings.reset_all()
	var count := int(OS.get_environment("CO_MAP_N")) if OS.get_environment("CO_MAP_N") != "" else 6
	_env()
	var m := ProcMap.new()
	m.biome = String(GameData.zone(Duel.ZONE).get("biome", "limestone"))
	add_child(m)
	m.generate_colisee(4242, count)
	var arenas := ColiseeArena.build_all(m, self)
	for a in arenas:
		for _i in int(37.0 * 30):
			(a as ColiseeArena).ring.advance(1.0 / 30.0, [])
	cam = Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.current = true
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = res
		await get_tree().process_frame
		for a in arenas:
			var c: Vector3 = (a as ColiseeArena).center
			cam.global_position = c + Vector3(0, 30, 27)
			cam.look_at(c, Vector3.UP)
			await _shot("arene%d_%s" % [(a as ColiseeArena).index, String((a as ColiseeArena).info.kind)])
		var mid := Vector3(m.size * 0.5, 0, m.size * 0.5)
		cam.global_position = mid + Vector3(0, m.size * 0.9, m.size * 0.45)
		cam.look_at(mid, Vector3.UP)
		cam.far = 2000.0
		await _shot("carte")
		cam.far = 4000.0
	get_tree().quit()
