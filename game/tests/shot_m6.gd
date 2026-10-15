extends Node
## Passe M6 : captures (user://shots/m6_*.png) : pages de la Ruée (Normal, Mythique trop haut, à l'aveugle) et du Siège,
## un combat de la Ruée (boss de la bibliothèque, HUD « Boss n/8 »), une vague du Siège (escouades, lieutenant), le boss du
## Siège, puis les bilans de la Ruée et du Siège.
## godot --path game res://tests/shot_m6.tscn   (APPDATA détourné : rien n'est sauvegardé chez le joueur)
## M6_RES=1280x720 : fenêtre plus petite.

var _world: Node


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/m6_%s.png" % name)
	print("[m6] capture %s" % name)


func _ready() -> void:
	var res := OS.get_environment("M6_RES")
	if res != "":
		var wh := res.split("x")
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.records["epochs_cleared"] = 4
	Profile.records["boss_wetlands"] = 1
	Profile.unlocked_features.append_array(["dungeons", "siege"])
	Profile.install_gear(StarterGear.scenario("3.3.10.4", "warrior"))
	Profile.records["rush_seed"] = 4821
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.5).timeout
	lobby._dg_diff = 0
	lobby._show_menu("rush")
	await _shot("ruee_normal")
	lobby._scroll.scroll_vertical = 400
	await _shot("ruee_normal_bas")
	Settings.set_v("interface", "dev_mode", true)  # le Mythique ouvert malgré la PE : l'avertissement
	lobby._dg_diff = 2
	Rush.toggle("blind")
	Rush.toggle("enraged")
	lobby._show_menu("rush")
	await _shot("ruee_mythique")
	Rush.toggle("blind")
	Rush.toggle("enraged")
	Settings.set_v("interface", "dev_mode", false)
	lobby._dg_zone = "wetlands"
	lobby._dg_diff = 0
	lobby._show_menu("siege")
	await _shot("siege_normal")
	lobby._scroll.scroll_vertical = 500
	await _shot("siege_normal_bas")
	lobby._dg_diff = 1
	lobby._show_menu("siege")
	await _shot("siege_heroique")
	lobby.queue_free()
	await get_tree().create_timer(0.5).timeout
	# --- une Ruée en jeu ---
	Tower.start_dungeon("warrior", Dungeons.RUSH, 0, ["cleric"])
	var world := await _launch()
	var td = world.director.tower
	await _shot("ruee_boss1", 6.0)
	td._boss.hp = 1.0
	td._boss.take_damage(1e12, world.player, false)
	await _wait(func(): return td.phase == "stairs", 8.0)
	await _shot("ruee_escalier", 0.5)
	td.interact(td._goal)
	await _shot("ruee_boss2", 7.0)
	Tower.reached = 3
	world.tower_end("defaite")
	await _shot("ruee_bilan", 2.5)
	world.queue_free()
	await get_tree().create_timer(1.0).timeout
	# --- un Siège en jeu ---
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.install_gear(StarterGear.scenario("2.1.5.2", "warrior"))
	Tower.start_siege("warrior", "wetlands", 0, ["cleric", "knight"])
	world = await _launch()
	var sd: SiegeDirector = world.director.tower
	await _shot("siege_vague1", 9.0)
	for _i in 3000:
		if Tower.floor_n == 3 and sd.phase == "fight":
			break
		if world.cards.is_open():
			world.cards._choose(0)
		if sd.phase == "rest":
			sd._rest_t = 0.0
		if sd.phase == "fight" and Tower.floor_n < 3:
			sd.left = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not m.is_dead:
					m.hp = 1.0
					m.take_damage(1e12, world.player, false)
		await get_tree().physics_frame
	await _shot("siege_vague3_lieutenant", 6.0)
	for _i in 4000:
		if Tower.floor_n == Siege.WAVES + 1 and sd.phase == "fight":
			break
		if world.cards.is_open():
			world.cards._choose(0)
		if sd.phase == "rest":
			sd._rest_t = 0.0
		if sd.phase == "fight" and Tower.floor_n <= Siege.WAVES:
			sd.left = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not m.is_dead:
					m.hp = 1.0
					m.take_damage(1e12, world.player, false)
		await get_tree().physics_frame
	await _shot("siege_boss", 6.0)
	sd._boss.hp = 1.0
	sd._boss.take_damage(1e12, world.player, false)
	await _wait(func(): return sd.phase == "ffa", 10.0)
	await _shot("siege_chacun_pour_soi", 1.0)
	sd._finish("won", "VICTOIRE ! Dernier debout")
	await _shot("siege_bilan", 4.5)
	get_tree().quit()


func _launch() -> Node:
	var world: Node = load("res://scenes/world.tscn").instantiate()
	_world = world
	get_tree().root.add_child.call_deferred(world)
	await _wait(func(): return world.is_inside_tree() and world.director != null and world.director.tower != null and world.player != null, 40.0)
	world.player.dev_invincible = true
	await _wait(func(): return world.cards.is_open(), 5.0)
	world.cards._queue.clear()
	world.cards._show_next()
	return world


func _wait(cond: Callable, secs := 10.0) -> void:
	var t := 0.0
	while t < secs and not cond.call():
		t += get_physics_process_delta_time()
		if is_instance_valid(_world) and _world.get("cards") != null and _world.cards.is_open():
			_world.cards._choose(0)
		await get_tree().physics_frame
