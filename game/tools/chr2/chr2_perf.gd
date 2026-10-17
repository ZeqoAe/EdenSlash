extends Node3D
## Lot CHR-2 : coût du « Héros détaillé » (ClassPremium) : 20 héros à l'écran comme en Battle royale, caméra du jeu.
##   godot --path game res://tools/chr2/chr2_perf.tscn [-- --frames=400 --rounds=3]   (fenêtre : le rendu se mesure)
## Configurations jouées tour à tour dans le même processus (carte partagée : on alterne pour lisser le bruit) :
##   eden     : 20 héros de 20 classes d'Eden (référence) ;
##   ninja    : 20 Ninja du Tourbillon, réglage coupé (look de CHR-1 : mèches, bandeau et rubans par code) ;
##   detaille : 20 Ninja, « Héros détaillé » (tête 2048 et mèches 3D, ressorts, tenue 2048, course neuve) ;
##   detaille_ailes : idem + ailes d'Eden articulées.
## Puis temps de chargement : premier héros (froid : lecture des fichiers) et suivants (chaud), réglage coupé / mis.
## Ligne « [chr2-perf] » par configuration et par tour ; résumé JSON dans user://chr2_perf.json.

const N := 20
const EDEN_WINGS := "res://assets/player/outfits/back_a6118a.glb"

var _frames := 400
var _rounds := 3
var _heroes: Array = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			_frames = int(a.get_slice("=", 1))
		elif a.begins_with("--rounds="):
			_rounds = int(a.get_slice("=", 1))
	var results: Array = []
	results.append_array(_load_times())
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
	var cam := Camera3D.new()
	cam.fov = 52.0
	add_child(cam)
	cam.look_at_from_position(Vector3(0, 11.5, 9.6), Vector3(0, 0, 0))
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	for r in _rounds:
		for mode in ["eden", "ninja", "detaille", "detaille_ailes"]:
			_build(mode)
			for i in 60:
				await get_tree().process_frame
			results.append(await _measure(mode, r))
	_clear()
	var f := FileAccess.open("user://chr2_perf.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(results, " "))
	f.close()
	print("[chr2-perf] fini : ", ProjectSettings.globalize_path("user://chr2_perf.json"))
	get_tree().quit()


func _detail(on: bool) -> void:
	if not Settings.data.has("display"):
		Settings.data["display"] = {}
	Settings.data.display["hero_detail"] = on


## Temps de construction d'un héros Ninja (EdenModel.instantiate_hero) : 1er (froid) puis moyenne de 10 (chaud).
func _load_times() -> Array:
	var out: Array = []
	var cls := GameData.class_data("whirl_ninja")
	for on in [false, true]:
		_detail(on)
		var t0 := Time.get_ticks_usec()
		var m := EdenModel.instantiate_hero(cls)
		var cold := (Time.get_ticks_usec() - t0) / 1000.0
		m.free()
		t0 = Time.get_ticks_usec()
		for i in 10:
			EdenModel.instantiate_hero(cls).free()
		var warm := (Time.get_ticks_usec() - t0) / 10000.0
		print("[chr2-perf] chargement %s : premier héros %.1f ms, suivants %.1f ms" % ["détaillé" if on else "CHR-1", cold, warm])
		out.append({"mode": "chargement_" + ("detaille" if on else "chr1"), "premier_ms": snappedf(cold, 0.1), "suivant_ms": snappedf(warm, 0.1)})
	return out


func _clear() -> void:
	for h in _heroes:
		h.queue_free()
	_heroes.clear()


func _build(mode: String) -> void:
	_clear()
	_detail(mode.begins_with("detaille"))
	var classes := GameData.classes.keys()
	for i in N:
		var cid := "whirl_ninja" if mode != "eden" else String(classes[(i * 3) % classes.size()])
		var cls := GameData.class_data(cid)
		var extra: Array = [EDEN_WINGS] if mode == "detaille_ailes" else []
		var model := EdenModel.instantiate_hero(cls, "", extra)
		model.scale = Vector3.ONE * GameData.HERO_SCALE
		model.position = Vector3((i % 5 - 2) * 2.6, 0, (i / 5 - 1.5) * 2.6)
		model.rotation.y = PI + (i % 4) * 0.4
		add_child(model)
		var ap := EdenModel.find_anim_player(model)
		var run: String = cls.get("anims", {}).get("run", "run01")
		var real := ClassPremium.remapped(model, run)
		if real != "":
			run = real
		if ap and ap.has_animation(run):
			ap.get_animation(run).loop_mode = Animation.LOOP_LINEAR
			ap.play(run)
		_heroes.append(model)


func _measure(mode: String, round_i: int) -> Dictionary:
	var vp := get_viewport().get_viewport_rid()
	var cpu := 0.0
	var gpu := 0.0
	var prims := 0
	var draws := 0
	var t0 := Time.get_ticks_usec()
	for i in _frames:
		# les héros se déplacent en rond : les ressorts travaillent comme en course
		for k in _heroes.size():
			var h: Node3D = _heroes[k]
			var a := Time.get_ticks_msec() / 1000.0 * 1.3 + k
			h.position = Vector3((k % 5 - 2) * 2.6 + cos(a) * 0.6, 0, (k / 5 - 1.5) * 2.6 + sin(a) * 0.6)
			h.rotation.y = -a
		await get_tree().process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		prims = RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
		draws = RenderingServer.viewport_get_render_info(vp, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
	var wall := (Time.get_ticks_usec() - t0) / 1000.0 / _frames
	var out := {"mode": mode, "tour": round_i + 1, "image_ms": snappedf(wall, 0.01), "cpu_rendu_ms": snappedf(cpu / _frames, 0.01),
		"gpu_ms": snappedf(gpu / _frames, 0.01), "triangles": prims, "appels": draws,
		"vram_textures_mo": snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1)}
	print("[chr2-perf] %s tour %d : image %.2f ms, CPU rendu %.2f ms, GPU %.2f ms, %d triangles, %d appels, textures %.0f Mo" % [
		mode, round_i + 1, out.image_ms, out.cpu_rendu_ms, out.gpu_ms, prims, draws, out.vram_textures_mo])
	return out
