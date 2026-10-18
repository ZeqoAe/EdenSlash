extends Node
## Captures du lot MB-H (HUD des Deux Voies) : partie en voie (tableau, minuteurs, alliés, mini-carte, choix de niveau,
## annonce, repère, or et objet conseillé), boutique à la fontaine, tableau des scores, écran de mort, grande carte, bilan
## (user://shots/mbh_*.png). Taille : variable MBH_RES (« 1280x720 », défaut 1600x900). Mesure aussi le coût du HUD par image
## avec le rendu (ligne « [mbh] »).
## godot --path game res://tests/shot_mbh.tscn

var world: Node
var _tag := ""


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/mbh_%s%s.png" % [name, _tag])
	print("[shot] mbh_%s%s" % [name, _tag])


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit and not cond.call():
		await get_tree().process_frame
		t += get_process_delta_time()


func _place(c: Node3D, at: Vector3, dd: MobaDirector) -> void:
	at.y = float(dd.map.height_at(at.x, at.z)) + 0.1
	c.global_position = at
	if c == world.player and world.rig != null:
		world.rig.global_position = at


func _ready() -> void:
	var res := OS.get_environment("MBH_RES")
	var sz := Vector2i(1600, 900)
	if res.contains("x"):
		sz = Vector2i(int(res.get_slice("x", 0)), int(res.get_slice("x", 1)))
		_tag = "_%d" % sz.y
	Settings.reset_all()
	DisplayServer.window_set_size(sz)
	get_window().size = sz
	Profile.reset_all()
	seed(33)
	Profile.selected_class = "magician"
	Moba.launch("magician", {"heroes": "all", "diff": 1, "seed": 33, "clock": 160.0})
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.get("director") != null and is_instance_valid(world.director.team), 60.0)
	var dd: MobaDirector = world.director.team as MobaDirector
	await _until(func(): return dd.map != null and dd.map.nav_ready(), 60.0)
	var mh: MobaHud = world.hud.get("_moba")
	var p: Player = dd.player
	var ps: MobaHero = dd.info[p]
	await get_tree().create_timer(1.0).timeout
	# partie : niveau 3 (un enchaînement déjà pris, un choix en attente), un objet, en voie près d'une vague
	dd._xp(ps, float(MobaData.xp_total(3)) - ps.xp + 5.0)
	await _frames(4)
	dd.choose_chain(p, 0)
	ps.gold = 1240.0
	MobaItems.buy(ps, "grimoire_use")
	ps.gold = 1240.0
	var lane_at := dd.map.lane_point(0, 0, dd.map.lane_len[0] * 0.38)
	_place(p, lane_at, dd)
	var foe: MobaRival = null
	for h in dd.heroes:
		if h is MobaRival and (h as MobaRival).side == 1 and foe == null:
			foe = h
	if foe != null:
		foe.passive = true
		_place(foe, lane_at + Vector3(9, 0, -3), dd)
	await get_tree().create_timer(2.5).timeout
	if foe != null:
		mh._update_seen(dd)
		mh.place_ping("", foe.global_position)
	dd.d.message.emit("Gardien arrive dans 20 s", 3.0)
	await _frames(20)
	await _shot("1_partie")
	# coût : mise à jour du HUD (moyenne sur 120 images), puis rendu processeur avec et sans le HUD du mode
	var t0 := Time.get_ticks_usec()
	for i in 120:
		mh.tick(1.0 / 60.0)
	print("[mbh] HUD des Deux Voies (mise à jour) : %.3f ms par image" % (float(Time.get_ticks_usec() - t0) / 1000.0 / 120.0))
	var vrid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vrid, true)
	var avg := {}
	for shown in [true, false, true, false]:
		mh.visible = shown
		await _frames(10)
		var sum := 0.0
		for i in 120:
			await get_tree().process_frame
			sum += RenderingServer.viewport_get_measured_render_time_cpu(vrid)
		avg[shown] = minf(float(avg.get(shown, INF)), sum / 120.0)
	mh.visible = true
	print("[mbh] rendu (processeur) : %.3f ms avec le HUD des Deux Voies, %.3f ms sans (écart %.3f ms)" % [avg[true], avg[false], avg[true] - avg[false]])
	# boutique à la fontaine
	_place(p, dd.map.moba.fountains[0] + Vector3(2, 0, 0), dd)
	await _until(func(): return ps.in_shop, 3.0)
	ps.gold = 2480.0
	mh.toggle_store(false)
	mh.store.selected = "orbe_marees"
	mh.store.refresh(true)
	await _frames(8)
	await _shot("2_boutique")
	mh.store.set_tab(1)
	mh.store.selected = "lame_braise"
	mh.store.refresh(true)
	await _frames(6)
	await _shot("2b_boutique_attaque")
	mh.store.close()
	# tableau des scores
	_place(p, lane_at, dd)
	Input.action_press("objectives")
	await _frames(8)
	await _shot("3_scores")
	Input.action_release("objectives")
	# grande carte
	mh.minimap.big = true
	await _frames(6)
	await _shot("5_carte")
	mh.minimap.big = false
	# mort
	if foe != null:
		foe.passive = false
		p.evasion_chance = 0.0
		p.parry_chance = 0.0
		p.take_damage(p.max_hp * 0.2, foe, false, true)
		p.hp = 1.0
		p.take_damage(p.max_hp, foe, false, true)
	await _frames(14)
	await _shot("4_mort")
	# bilan
	Moba.decided_by = "structures"
	Moba.structures_down = [3, 1]
	dd._finish(0, "time")
	await _frames(30)
	await get_tree().create_timer(2.0, true).timeout
	await _shot("6_bilan")
	get_tree().quit()
