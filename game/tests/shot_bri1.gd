extends Node
## Captures du lot BR-I1 (HUD v2 du Battle royale) : grande carte du vol, chute avec repère, HUD de combat (tuiles, anneau,
## fil, flèche de la zone sûre, héros hors de la vue, arc de coup reçu, repère), grande carte au sol
## (user://shots/bri1_*.png). Taille : variable BRI1_RES (« 1280x720 », défaut 1600x900). Mesure aussi le coût du HUD
## par image avec le rendu (ligne « [bri1] »).
## godot --path game res://tests/shot_bri1.tscn

var world: Node
var _tag := ""


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/bri1_%s%s.png" % [name, _tag])
	print("[shot] bri1_%s%s" % [name, _tag])


func _cards() -> void:
	if world.get("cards") != null and world.cards.is_open():
		world.cards._queue.clear()
		world.cards._show_next()


func _wait(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit and not cond.call():
		_cards()
		await get_tree().process_frame
		t += get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		_cards()
		await get_tree().process_frame


func _place(c: Node3D, at: Vector3) -> void:
	at.y = float(world.director.map.height_at(at.x, at.z)) + 0.1
	c.global_position = at
	if c == world.player and world.rig != null:
		world.rig.global_position = at


func _ready() -> void:
	var res := OS.get_environment("BRI1_RES")
	var sz := Vector2i(1600, 900)
	if res.contains("x"):
		sz = Vector2i(int(res.get_slice("x", 0)), int(res.get_slice("x", 1)))
		_tag = "_%d" % sz.y
	Settings.reset_all()  # (avant la taille : il applique la résolution des réglages)
	DisplayServer.window_set_size(sz)
	get_window().size = sz
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.start("magician")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _wait(func(): return world.get("director") != null and world.director.royale != null and world.director.royale.jump != null, 60.0)
	var rd: RoyaleDirector = world.director.royale
	var j := rd.jump
	var p: Player = world.player
	var rh: RoyaleHud = world.hud.get("_royale")
	await _wait(func(): return rh.map.is_open and j.t > Royale.COUNTDOWN + 1.0, 20.0)
	# repère sur un coffre doré proche du vol, s'il y en a
	var best := Vector3.INF
	for it in rd.d.map.interactables:
		if is_instance_valid(it) and it.kind == "chest" and int(it.get_meta("tier", 0)) >= 1 and rh.map.reachable(it.global_position):
			best = it.global_position
			break
	if best != Vector3.INF:
		RoyalePing.toggle(best)
	rh.map.cursor = rh.map.world_to_view(best if best != Vector3.INF else j.b) + Vector2(60, -40)
	rh.map.cursor_shown = true
	await _frames(3)
	await _shot("1_vol_carte")
	rh.map.press_jump()
	await _wait(func(): return j.riders.has(p) and float(j.riders[p].air) > 1.0, 6.0)
	await _frames(2)
	await _shot("2_chute_repere")
	j.land_all()
	await _wait(func(): return rd.phase == "fight", 20.0)
	await get_tree().create_timer(1.0).timeout
	# combat : 2e anneau, dehors, un héros derrière, un coup reçu de la droite, deux éliminations au fil
	rd.elapsed = float(Royale.PHASES[0].hold) + float(Royale.PHASES[0].shrink) + 20.0
	await _frames(3)
	var c: Vector2 = rd.ring.center
	var out := c + Vector2(1, 0.2).normalized() * (float(rd.ring.radius) + 30.0)
	_place(p, Vector3(out.x, 0, out.y))
	await _frames(20)
	var cam := get_viewport().get_camera_3d()
	var a: ClassRival = null
	for r in rd.ais:
		if is_instance_valid(r) and not r.is_dead and r.is_in_group("ffa"):
			a = r
			break
	var b: ClassRival = null
	for r in rd.ais:
		if is_instance_valid(r) and not r.is_dead and r.is_in_group("ffa") and r != a:
			b = r
			break
	if a != null:
		a.passive = true
		_place(a, p.global_position + Vector3(7, 0, -2).rotated(Vector3.UP, cam.global_rotation.y))
	if b != null:
		b.passive = true
		_place(b, p.global_position + Vector3(-12, 0, 30).rotated(Vector3.UP, cam.global_rotation.y))
	RoyalePing.reset()
	RoyalePing.toggle(RoyalePing.ground(rd.d.map, p.global_position.x - 20.0, p.global_position.z - 18.0))
	rd.feed("Tu élimines Assassin")
	rd.feed("Chasseur élimine Prêtre")
	await _frames(4)
	p.evasion_chance = 0.0
	p.parry_chance = 0.0
	if a != null:
		p.take_damage(20.0, a, false)
	await _frames(3)
	await _shot("3_combat")
	# coût du HUD avec le rendu : temps de traitement des nœuds du HUD du Battle royale (moyenne sur 120 images)
	var t0 := Time.get_ticks_usec()
	for i in 120:
		rh.tick(1.0 / 60.0)
		rh.edge.compute()
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 120.0
	print("[bri1] HUD du Battle royale (mise à jour) : %.3f ms par image" % ms)
	# rendu : temps processeur du rendu de la fenêtre, HUD du Battle royale affiché puis caché (120 images chacun)
	var vrid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vrid, true)
	var parts: Array = [rh, rh.edge, rh.arc]
	var avg := {}
	for shown in [true, false, true, false]:
		for n in parts:
			(n as CanvasItem).visible = shown
		await _frames(10)
		var sum := 0.0
		for i in 120:
			await get_tree().process_frame
			sum += RenderingServer.viewport_get_measured_render_time_cpu(vrid)
		avg[shown] = minf(float(avg.get(shown, INF)), sum / 120.0)
	for n in parts:
		(n as CanvasItem).visible = true
	print("[bri1] rendu (processeur) : %.3f ms avec le HUD du Battle royale, %.3f ms sans (écart %.3f ms)" % [avg[true], avg[false], avg[true] - avg[false]])
	rh.toggle_map()
	await _frames(4)
	await _shot("4_carte_sol")
	rh.toggle_map()
	await _frames(2)
	get_tree().quit()
