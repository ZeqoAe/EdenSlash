extends Node
## Banc de performance de la horde (lot SVX-1, conception/survivor/R_SVX1.md) : lance la scène de jeu (world.tscn, avec
## les arguments « -- » de la ligne de commande : --survivor, --autoplay, --god, --class=…) puis mesure le coût d'une image
## (script, physique, rendu CPU et GPU) pendant [secs] s après [warm] s de mise en route. Avec [horde] = N, le banc garde
## N monstres vivants autour du héros (8 à 22 m, ils convergent) ; sans, il mesure la partie telle quelle.
##
##   SVX1_BENCH="horde=250,warm=8,secs=20,at=0" Godot --path game res://tools/svx1_bench.tscn -- --survivor --autoplay --god
##   (at=N : la carte avance à N s de jeu avant la mesure ; render=0 : pas de mesure GPU, mode --headless)
## Ligne de sortie « [bench] » : moyenne et p95 de chaque coût en ms, monstres vivants, à l'écran et à moins de 15 m.
## « frame » = temps réel d'une image : avec --headless --fixed-fps 60, c'est le coût CPU d'une image de jeu (une image
## physique, sans rendu ni attente), la mesure la plus stable ; en fenêtre, cpu / gpu donnent le coût du rendu.

var opts := {"horde": 0, "warm": 8.0, "secs": 20.0, "at": 0.0, "render": 1, "passive": 0}
var _t := 0.0
var _world: Node
var _samples := {"frame": [], "process": [], "physics": [], "cpu": [], "gpu": [], "alive": [], "screen": [], "near": [], "draws": []}
var _spawn_t := 0.0
var _spawned := 0
var _last_us := 0
var _done := false
var _vp: RID
var _shots: Array = []


func _ready() -> void:
	for kv in OS.get_environment("SVX1_BENCH").split(",", false):
		var p := kv.split("=")
		if p.size() == 2 and opts.has(p[0]):
			opts[p[0]] = float(p[1])
	for s in OS.get_environment("SVX1_SHOTS").split(",", false):
		_shots.append(float(s))
	if not _shots.is_empty():
		opts.secs = 99999.0  # (la fin vient de la dernière capture)
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)  # survit au changement de scène
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _done:
		return
	_world = get_tree().current_scene
	if _world == null or not ("director" in _world) or _world.director == null or _world.player == null:
		return
	var d = _world.director
	if _t == 0.0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		_vp = get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_vp, true)
		if float(opts.at) > 0.0:
			d.time = float(opts.at)
		if int(opts.passive) > 0:
			# héros immobile qui ne frappe pas : on mesure la horde seule (sans morts ni apparitions continues)
			_world.player.dev_invincible = true
			_world.player.set_physics_process(false)
			_world.player.set_process(false)
	_t += delta
	if int(opts.horde) > 0:
		_keep_horde(d, delta)
	# captures au temps de JEU (SVX1_SHOTS="45,150,300,600" : secondes de carte), puis fin du banc
	if not _shots.is_empty() and float(d.time) >= float(_shots[0]):
		var at := float(_shots.pop_front())
		var c: Dictionary = d.sv.density_now() if d.sv else {}
		var img := get_viewport().get_texture().get_image()
		var path := "user://svx1_%04d.png" % int(at)
		img.save_png(path)
		print("[capture] %s · carte %s · %s" % [ProjectSettings.globalize_path(path), SurvivorDirector.clock(d.time), c])
		if _shots.is_empty():
			_done = true
			_report()
			get_tree().quit()
			return
	if _t < float(opts.warm):
		return
	var cam := get_viewport().get_camera_3d()
	var hero: Vector3 = _world.player.global_position
	var alive := 0
	var screen := 0
	var near := 0
	for m in get_tree().get_nodes_in_group("monsters"):
		if (m as Monster).is_dead:
			continue
		alive += 1
		var p: Vector3 = (m as Node3D).global_position
		if Vector2(p.x - hero.x, p.z - hero.z).length() < 15.0:
			near += 1
		if cam and cam.is_position_in_frustum(p + Vector3.UP * 0.5):
			screen += 1
	var now_us := Time.get_ticks_usec()
	_samples.frame.append(float(now_us - _last_us) / 1000.0 if _last_us > 0 else delta * 1000.0)  # temps réel de l'image
	_last_us = now_us
	_samples.process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_samples.physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	if int(opts.render) > 0:
		_samples.cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.get_frame_setup_time_cpu())
		_samples.gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp))
	_samples.alive.append(alive)
	_samples.screen.append(screen)
	_samples.near.append(near)
	_samples.draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _t >= float(opts.warm) + float(opts.secs):
		_done = true
		_report()
		get_tree().quit()


## Garde [opts.horde] monstres vivants : ceux qui manquent apparaissent à 8-22 m du héros (escouades du directeur).
func _keep_horde(d, delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t > 0.0 or d.state not in ["explore", "rage"]:
		return
	_spawn_t = 0.25
	var n := get_tree().get_nodes_in_group("monsters").size()
	var lvl: int = d._monster_level(0) if d.sv == null else d.sv.monster_level(0)
	for i in mini(int(opts.horde) - n, 40):
		var g: Vector3 = d._ring_point(8.0, 22.0)
		if g == Vector3.INF:
			continue
		d._spawn_monster(d._pick_monster(lvl), g, lvl)
		if _t >= float(opts.warm):
			_spawned += 1


func _report() -> void:
	var parts: PackedStringArray = []
	for k in ["frame", "process", "physics", "cpu", "gpu"]:
		var a: Array = _samples[k]
		if a.is_empty():
			continue
		a.sort()
		parts.append("%s=%.2f/%.2f" % [k, _mean(a), float(a[int(a.size() * 0.95)])])
	for k in ["alive", "screen", "near", "draws"]:
		var a: Array = _samples[k]
		if not a.is_empty():
			parts.append("%s=%.0f" % [k, _mean(a)])
	print("[bench] horde=%d%s %s %s images=%d apparitions=%d" % [int(opts.horde), " passif" if int(opts.passive) > 0 else "", "survivant" if Survivor.active else "survie",
		" ".join(parts), (_samples.frame as Array).size(), _spawned])


static func _mean(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += float(x)
	return s / maxf(a.size(), 1.0)
