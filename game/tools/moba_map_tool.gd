extends Node3D
## Outil de la carte des Deux Voies (lot MB-B, rapport conception/benchmark/R_MB_B.md) :
##   --bake      cuit le maillage de navigation et l'enregistre (assets/maps/moba/navmesh.res, tampon MobaMap.LAYOUT_VERSION)
##   --measure   longueurs des voies, chemins de base à base (temps de course à 6,5 m/s), coût de génération
##   --shots=<dossier> vues de la carte (d'en haut, de la base, d'une voie, de la jungle, de la rivière) en jpg ; avec rendu :
##               Godot --path game res://tools/moba_map_tool.tscn -- --res=1280x720 --shots=…
## Lignes : [mb-b] …
## godot --headless --path game res://tools/moba_map_tool.tscn -- --bake --measure

var map: MobaMap
var opt := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			opt[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
		elif a.begins_with("--"):
			opt[a.substr(2)] = "1"
	Training.active = true  # aucune sauvegarde
	if opt.has("res") and DisplayServer.get_name() != "headless":
		var wh := String(opt.res).split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	var t0 := Time.get_ticks_usec()
	map = MobaMap.new()
	map.biome = String(GameData.zone("rainbowfall").get("biome", "rainbowfall"))
	add_child(map)
	map.generate_moba(int(opt.get("seed", "7")))
	var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("[mb-b] carte générée en %.0f ms (navigation %s en %.0f ms, %d polygones)" % [gen_ms, map.nav_source, map.nav_ms,
		map._region.navigation_mesh.get_polygon_count()])
	if opt.has("bake"):
		var nav := map.bake_nav()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MobaMap.NAV_PATH.get_base_dir()))
		var err := ResourceSaver.save(nav, MobaMap.NAV_PATH)
		print("[mb-b] maillage enregistré : %s (%d polygones, erreur %d)" % [MobaMap.NAV_PATH, nav.get_polygon_count(), err])
	var waited := 0
	while not map.nav_ready() and waited < 600:
		await get_tree().physics_frame
		waited += 1
	print("[mb-b] navigation prête après %d images" % waited)
	if opt.has("measure"):
		_measure()
	if opt.has("shots"):
		await _shots(String(opt.shots))
	get_tree().quit()


func _measure() -> void:
	for li in 2:
		print("[mb-b] %s : %.1f m de Cœur à Cœur (%.1f s à 6,5 m/s)" % [MobaData.LANE_NAMES[li], map.lane_len[li], map.lane_len[li] / Player.BASE_SPEED])
	var f0: Vector3 = map.moba.fountains[0]
	var f1: Vector3 = map.moba.fountains[1]
	var direct := _path_len(f0, f1)
	print("[mb-b] fontaine à fontaine, chemin le plus court : %.1f m (%.1f s)" % [direct, direct / Player.BASE_SPEED])
	for li in 2:
		var mid := map.lane_point(0, li, map.lane_len[li] * 0.5)
		var l := _path_len(f0, mid) + _path_len(mid, f1)
		print("[mb-b] fontaine à fontaine par la %s : %.1f m (%.1f s)" % [MobaData.LANE_NAMES[li], l, l / Player.BASE_SPEED])
	for k in map.moba.objectives:
		print("[mb-b] fontaine bleue -> %s : %.1f m" % [k, _path_len(f0, map.moba.objectives[k])])


func _path_len(a: Vector3, b: Vector3) -> float:
	var p := map.path_between(a, b)
	if p.size() < 2:
		return INF
	var s := 0.0
	for i in p.size() - 1:
		s += p[i].distance_to(p[i + 1])
	if Vector2(p[-1].x - b.x, p[-1].z - b.z).length() > 2.0:
		return INF
	return s


func _shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	Gfx.style_sky(sm)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	Gfx.style_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	add_child(sun)
	Gfx.style_sun(sun)
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.far = 600.0
	add_child(cam)
	cam.current = true
	var c: Vector3 = map.moba.center
	var res := get_viewport().get_visible_rect().size
	var tag := "%dx%d" % [int(res.x), int(res.y)]
	var views := [
		["dessus", c + Vector3(0, 150, 60), c],
		["base_bleue", (map.moba.cores[0] as Vector3) + Vector3(16, 14, 16), (map.moba.cores[0] as Vector3) + Vector3(10, 0, 0)],
		["voie_soleil", map.lane_point(0, 0, map.lane_len[0] * 0.3) + Vector3(0, 13, 13), map.lane_point(0, 0, map.lane_len[0] * 0.3)],
		["jungle", map.world(Vector2(-40, 8)) + Vector3(0, 16, 18), map.world(Vector2(-40, 0))],
		["riviere", (map.moba.objectives.colossus as Vector3) + Vector3(-10, 15, 14), map.moba.objectives.colossus],
	]
	for v in views:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for _i in 8:
			await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := dir.path_join("mbb_%s_%s.jpg" % [v[0], tag])
		img.save_jpg(path, 0.85)
		print("[mb-b] capture : ", path)
