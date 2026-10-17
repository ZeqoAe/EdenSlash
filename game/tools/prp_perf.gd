extends Node3D
## Lot PRP-2 : coût d'image de 20 héros (Battle royale) avec ou sans dos et armes maison.
## godot --path game res://tools/prp_perf.tscn [-- --frames=400 --rounds=2]   (fenêtre : le rendu se mesure)
## Configurations, jouées tour à tour dans le même processus (la carte est partagée : on alterne pour lisser le bruit) :
##   aucun  : 20 héros, arme de la classe, sans dos ;
##   eden   : + ailes d'Eden (« back_a6118a », articulées) ;
##   maison : + ailes maison qui battent (back_prp_*, ≤ 5 000 triangles) et arme maison (≤ 3 000).
## Ligne « [prp-perf] » par configuration et par tour (temps d'image CPU / GPU moyen, triangles dessinés, appels de
## dessin) ; résumé JSON dans user://prp_perf.json.

const N := 20
const EDEN_WINGS := "res://assets/player/outfits/back_a6118a.glb"

var _frames := 400
var _rounds := 2
var _heroes: Array = []
var _cam: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			_frames = int(a.get_slice("=", 1))
		elif a.begins_with("--rounds="):
			_rounds = int(a.get_slice("=", 1))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_window().size = Vector2i(1280, 720)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("ccdef3")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	ground.mesh = pm
	add_child(ground)
	# caméra du jeu : 15 m, 52°
	_cam = Camera3D.new()
	_cam.fov = 52.0
	add_child(_cam)
	_cam.look_at_from_position(Vector3(0, 11.5, 9.6), Vector3(0, 0, 0))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var results: Array = []
	for r in _rounds:
		for mode in ["aucun", "eden", "maison"]:
			_build(mode)
			for i in 60:
				await get_tree().process_frame
			results.append(await _measure(mode, r))
	_clear()
	var f := FileAccess.open("user://prp_perf.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, " "))
	f.close()
	print("[prp-perf] fini : ", ProjectSettings.globalize_path("user://prp_perf.json"))
	get_tree().quit()


func _clear() -> void:
	for h in _heroes:
		h.queue_free()
	_heroes.clear()


func _build(mode: String) -> void:
	_clear()
	var classes := GameData.classes.keys()
	var weapons := PrpLooks.list.filter(func(e): return String(e.slot) == "weapon")
	var backs := PrpLooks.list.filter(func(e): return String(e.slot) == "back" and bool(e.get("flap", false)))
	for i in N:
		var cid := String(classes[(i * 3) % classes.size()])
		var cls := GameData.class_data(cid)
		var extra: Array = []
		if mode == "eden":
			extra = [EDEN_WINGS]
		elif mode == "maison" and not backs.is_empty():
			extra = [String(backs[i % backs.size()].model)]
		var model := EdenModel.instantiate_hero(cls, "", extra)
		model.scale = Vector3.ONE * GameData.HERO_SCALE
		model.position = Vector3((i % 5 - 2) * 2.6, 0, (i / 5 - 1.5) * 2.6)
		model.rotation.y = PI + (i % 4) * 0.4
		add_child(model)
		var code := ""
		if mode == "maison" and not weapons.is_empty():
			code = String(weapons[i % weapons.size()].id)
		else:
			var ws: Array = GameData.weapon_type(String(cls.get("weapon_type", "katana"))).get("weapons", [])
			code = String(ws[0].code) if not ws.is_empty() else ""
		EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, code))
		var ap := EdenModel.find_anim_player(model)
		var run: String = cls.get("anims", {}).get("run", "run01")
		if ap and ap.has_animation(run):
			ap.get_animation(run).loop_mode = Animation.LOOP_LINEAR
			ap.play(run)
		_heroes.append(model)


func _measure(mode: String, round_i: int) -> Dictionary:
	var vp := get_viewport().get_viewport_rid()
	var cpu := 0.0
	var gpu := 0.0
	var wall := 0.0
	var prims := 0
	var draws := 0
	var t0 := Time.get_ticks_usec()
	for i in _frames:
		await get_tree().process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		prims = RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		draws = RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	wall = (Time.get_ticks_usec() - t0) / 1000.0 / _frames
	var out := {"mode": mode, "tour": round_i + 1, "image_ms": snappedf(wall, 0.01), "cpu_rendu_ms": snappedf(cpu / _frames, 0.01),
		"gpu_ms": snappedf(gpu / _frames, 0.01), "triangles": prims, "appels": draws}
	print("[prp-perf] %s tour %d : image %.2f ms, CPU rendu %.2f ms, GPU %.2f ms, %d triangles, %d appels de dessin" % [
		mode, round_i + 1, out.image_ms, out.cpu_rendu_ms, out.gpu_ms, prims, draws])
	return out
