extends Node
## Passe P9 (notes du joueur) : captures de l'inventaire du Héros (onglets de familles), des activités
## verrouillées de la page Jouer et du HUD en rage (paliers).
## user://shots/p9/<largeur>x<hauteur>_<nom>.png
## [P9_RES=1280x720] godot --path game res://tests/shot_p9.tscn   (APPDATA détourné)


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots/p9")
	get_viewport().get_texture().get_image().save_png("user://shots/p9/%dx%d_%s.png" % [get_viewport().size.x, get_viewport().size.y, name])


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	if OS.get_environment("P9_RES") != "":
		var wh := OS.get_environment("P9_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	await get_tree().create_timer(0.3).timeout
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._show_menu("play")
	await _shot("jouer_neuf")
	lobby._show_menu("")
	lobby._open_hero("equipment")
	await _shot("heros_equipement")
	lobby._hero.close_ui()
	lobby.queue_free()
	await get_tree().process_frame
	# HUD en rage : paliers 1 à 4
	Profile.selected_zone = String(GameData.zones[0].id)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(6.0).timeout
	var d: RunDirector = world.director
	world.cards._queue.clear()
	world.cards._show_next()
	for tier in [0, 2, 3]:
		d.time = RunDirector.RUN_TIME + 60.0 * tier + 20.0
		await _shot("rage_palier_%d" % (tier + 1), 1.2)
	get_tree().quit()
