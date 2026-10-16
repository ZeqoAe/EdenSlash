extends Node
## Captures du largage du Battle royale (lot BR4) : à bord de l'aigle, en chute, en planeur, au sol, retour après
## une élimination (user://shots/br4_*.png). Taille : variable BR4_RES (« 1280x720 », défaut 1600x900).
## godot --path game res://tests/shot_br4.tscn

var world: Node


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/br4_%s.png" % name)
	print("[shot] br4_%s" % name)


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


func _ready() -> void:
	var res := OS.get_environment("BR4_RES")
	var sz := Vector2i(1600, 900)
	if res.contains("x"):
		sz = Vector2i(int(res.get_slice("x", 0)), int(res.get_slice("x", 1)))
	DisplayServer.window_set_size(sz)
	Settings.reset_all()
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.start("magician")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _wait(func(): return world.get("director") != null and world.director.royale != null and world.director.royale.jump != null, 60.0)
	var rd: RoyaleDirector = world.director.royale
	var j := rd.jump
	var p: Player = world.player
	await _wait(func(): return j.t > Royale.COUNTDOWN + 1.5, 20.0)
	await _shot("1_a_bord")
	j.jump(p)
	await _wait(func(): return j.riders.has(p) and float(j.riders[p].air) > 1.2, 5.0)
	await _shot("2_chute")
	await _wait(func(): return not j.riders.has(p) or String(j.riders[p].state) == "glide", 20.0)
	await get_tree().create_timer(0.8).timeout
	await _shot("3_planeur")
	await _wait(func(): return not j.airborne(p), 20.0)
	await get_tree().create_timer(1.0).timeout
	await _shot("4_au_sol")
	await _wait(func(): return rd.phase == "fight", 40.0)
	rd.elapsed = 20.0
	p.hp = 1.0
	p.take_damage(1e9, rd.ais[0], false)
	await get_tree().create_timer(1.5).timeout
	await _shot("5_retour")
	await _wait(func(): return not p.is_dead and j.airborne(p), 10.0)
	await get_tree().create_timer(0.6).timeout
	await _shot("6_revenant")
	get_tree().quit()
