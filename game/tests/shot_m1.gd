extends Node
## Captures de la passe M1 (Battle royale) : lobby (compte neuf et avancé), compte à rebours, pillage et choix de pièce,
## largage, fil des éliminations et mis à prix, grande carte, menu pause, spectateur, bilan.
## godot --path game res://tests/shot_m1.tscn   ->  user://shots/m1_*.png

var world: Node


func _shot(name: String, wait := 0.9) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/m1_%s.png" % name)


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	# lobby, compte neuf (verrouillé) puis avancé
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._show_menu("royale")
	await _shot("01_page_neuf")
	lobby.queue_free()
	Profile.records["league_rank"] = 2
	Profile.records["royale_wins"] = 3
	Profile.records["royale_best"] = 1
	Profile.records["royale_kills"] = 17
	Royale.difficulty = 3
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._show_menu("royale")
	await _shot("02_page_avance")
	lobby.queue_free()
	await get_tree().process_frame
	# partie
	Royale.start("samurai")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	while not (world.get("director") != null and world.director.royale != null and world.director.royale.ais.size() == 7):
		await get_tree().create_timer(0.3).timeout
	var rd: RoyaleDirector = world.director.royale
	var p: Player = world.player
	await _shot("03_arme", 1.5)
	world.cards._queue.clear()
	world.cards._show_next()
	await _shot("04_decompte", 0.6)
	while rd.phase == "countdown":
		await get_tree().create_timer(0.3).timeout
	# un coffre doré près du héros : choix de pièce
	var gold: Interactable = rd._spawn_chest(p.global_position + Vector3(3, 0, 0), 2)
	await get_tree().create_timer(0.5).timeout
	rd.open_chest(gold)
	await _shot("05_coffre_choix")
	world.cards._queue.clear()
	world.cards._show_next()
	# largage annoncé, puis le fil des éliminations et un mis à prix
	rd.elapsed = float(Royale.PHASES[0].hold) + 1.0
	rd.ring = Royale.ring_at(rd.elapsed, rd.centers)
	rd._announce_drop()
	var a: ClassRival = rd.ais[0]
	a.get_meta("royale").kills = Royale.BOUNTY_KILLS
	rd._update_bounty()
	a.global_position = p.global_position + Vector3(6, 0.5, 4)
	rd.feed("%s élimine %s" % [rd.ais[1].display_name.get_slice(" ·", 0), rd.ais[2].display_name.get_slice(" ·", 0)])
	rd.feed("Tu élimines %s" % rd.ais[3].display_name.get_slice(" ·", 0))
	await _shot("06_largage_prime", 1.4)
	world.hud._big_map.visible = true
	await _shot("07_grande_carte")
	world.hud._big_map.visible = false
	world.pause_menu.open()
	await _shot("08_pause")
	world.pause_menu.close()
	# mort du joueur : spectateur
	p.hp = 1.0
	p.take_damage(1e9, rd.ais[4], false)
	await _shot("09_spectateur", 2.5)
	# Échap : bilan
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _shot("10_bilan", 2.5)
	get_tree().paused = false
	get_tree().quit()
