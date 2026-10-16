extends Node
## Lot 13 en jeu : un donjon dans la vraie scène (salle, alliés, enchaînement des salles).
## godot --headless --path game res://tests/test_lot13b.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 2
	var zid: String = Dungeons.zone_ids()[0]
	Tower.start_dungeon("warrior", zid, 0, ["cleric"])
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var d: RunDirector = world.director
	var player: Player = world.player
	check("directeur de salles actif, salle 1", d.state == "tower" and Tower.floor_n == 1 and d.tower != null)
	check("un allié IA a été créé et placé près du héros", d.tower._allies.size() == 1 and is_instance_valid(d.tower._allies[0]) and d.tower._allies[0].global_position.distance_to(player.global_position) < 8.0)
	check("salle 1 : des élites (et leur escorte)", d.tower.alive() > 0 and d.tower._elites_alive.size() == 1)  # une à la fois (lot A2)
	world.cards._queue.clear()
	world.cards._show_next()  # ferme le choix de départ (dépause)
	await get_tree().create_timer(0.5).timeout
	var m: Monster = get_tree().get_first_node_in_group("monsters")
	if m != null:
		await get_tree().create_timer(2.0).timeout
		check("un monstre vise un héros (joueur ou allié)", m._player != null)
	# salle vidée : carte, puis passage à la salle suivante sans coffre
	for mm in get_tree().get_nodes_in_group("monsters"):
		mm.queue_free()
	d.tower.left = 0
	d.tower._elites_next = 0  # (lot A2 : les élites suivantes n'entrent pas)
	await get_tree().create_timer(1.0).timeout
	check("salle vidée : choix de carte", d.tower.phase == "cards" or d.tower.phase == "stairs")
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(1.0).timeout
	check("donjon : pas de coffre, directement le passage", d.tower.phase == "stairs")
	d.tower.begin(2)
	await get_tree().create_timer(0.5).timeout
	check("salle 2 : le lieutenant", Tower.floor_type(2) == "lieutenant" and Tower.floor_n == 2 and is_instance_valid(d.tower._lieutenant))
	d.tower.begin(3)
	await get_tree().create_timer(0.5).timeout
	check("salle 3 : le boss de la zone", is_instance_valid(d.tower._boss) and d.tower._boss.is_boss)
	world.queue_free()
	Tower.active = false
	Tower.dungeon = ""
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
