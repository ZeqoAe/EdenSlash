extends Node
## Passe P15 : captures du spawn de la Survie, caméra reculée : escouades mélangées qui arrivent de plusieurs côtés
## (1re minute, 5e minute), encerclement (cercles d'alerte puis arrivée), élite escortée (flèche au bord de l'écran).
## user://shots/p15/<nom>.png
## EDEN_PROFILE=user://shot_p15.json godot --path game res://tests/shot_p15.tscn


var world: Node


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait, true).timeout
	world.cards._queue.clear()  # (choix de niveau ouverts par l'expérience)
	world.cards._show_next()
	world.hud.hide_banner()
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("user://shots/p15")
	get_viewport().get_texture().get_image().save_png("user://shots/p15/%s.png" % name)
	print("[shot] ", name, " monstres=", get_tree().get_nodes_in_group("monsters").size())


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	get_window().size = Vector2i(1600, 900)
	Profile.selected_zone = String(GameData.zones[0].id)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var d: RunDirector = world.director
	var player: Player = world.player
	player.dev_invincible = true
	player.autoplay = true
	player.autoplay_idle = true  # immobile : on voit les groupes converger
	d.set_process(false)
	world.cards._queue.clear()
	world.cards._show_next()
	print("[shot] pause au départ : ", get_tree().paused)
	get_tree().paused = false
	world.rig.allow_input = false
	world.rig.distance = 34.0
	world.rig.pitch_deg = 72.0
	_clear()
	d.state = "explore"
	var sp := d.spawner
	# 1. première minute : trois escouades successives (rotation d'or)
	d.time = 60.0
	for i in 3:
		sp._roam = 0.0
		sp.update(0.1, 0, 999)
		await get_tree().create_timer(1.2, true).timeout
	await _shot("1_premiere_minute", 0.6)
	await _shot("1b_premiere_minute", 2.0)
	_clear()
	# 2. encerclement : cercles d'alerte, puis arrivée de tous les côtés
	d.time = 200.0
	sp._event("encircle", 3.3, false)
	await _shot("2_encerclement_alerte", 0.4)
	await _shot("3_encerclement_arrivee", 2.5)
	_clear()
	# 3. élite escortée : flèche au bord de l'écran
	world.rig.distance = 15.0
	world.rig.pitch_deg = 52.0
	sp._event("escort", 4.0, false)
	await _shot("4_elite_fleche", 0.6)
	world.rig.distance = 34.0
	world.rig.pitch_deg = 72.0
	await _shot("5_elite_escorte", 4.0)
	_clear()
	# 4. cinquième minute : tanks, tireurs, soigneurs (lueur verte)
	d.time = 320.0
	for i in 4:
		sp._roam = 0.0
		sp.update(0.1, 0, 999)
		await get_tree().create_timer(1.0, true).timeout
	await _shot("6_cinquieme_minute", 0.6)
	get_tree().quit()


func _clear() -> void:
	for n in get_tree().get_nodes_in_group("monsters"):
		n.remove_from_group("monsters")
		n.queue_free()
