extends Node
## Lot UIK2 : captures des finitions de la peau papier (user://shots/uik2/<largeur>x<hauteur>_<nom>.png).
## UIK2_RES=1280x720 UIK2_WHAT=jeu|lobby godot --path game res://tests/shot_uik2.tscn   (APPDATA détourné)
##   jeu : choix de carte de la Survie et pause sur la scène floutée, confirmation par-dessus ;
##   lobby (compte neuf) : états vides illustrés (Coffres, Carnet > Succès), Paramètres (en-têtes de section).


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots/uik2")
	get_viewport().get_texture().get_image().save_png("user://shots/uik2/%dx%d_%s.png" % [get_viewport().size.x, get_viewport().size.y, name])


func _ready() -> void:
	get_tree().create_timer(240.0, true).timeout.connect(func(): get_tree().quit(1))  # garde-fou
	Settings.reset_all()
	Profile.reset_all()
	if OS.get_environment("UIK2_RES") != "":
		var wh := OS.get_environment("UIK2_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().create_timer(0.5).timeout
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
	if OS.get_environment("UIK2_WHAT") == "jeu":
		Profile.selected_class = "warrior"
		Run.start_survival("warrior", 1)
		var w: Node = load("res://scenes/world.tscn").instantiate()
		add_child(w)
		await get_tree().create_timer(3.0, true).timeout
		if w.get("cards") != null and not w.cards.is_open():
			w.cards.offer("Niveau 2 : choisis une carte", Run.roll_cards(3, true))
		await _shot("01_choix_carte", 1.0)
		if w.get("cards") != null and w.cards.is_open():
			w.cards._choose(0)
		await get_tree().create_timer(0.6, true).timeout
		while w.get("cards") != null and w.cards.is_open():
			w.cards._choose(0)
			await get_tree().create_timer(0.5, true).timeout
		w.pause_menu.open()
		await _shot("02_pause", 1.0)
		w.pause_menu._confirm.ask("Abandonner la partie ?", "L'or, les clés et les fournitures seront perdus.", "Abandonner", Callable())
		await _shot("03_pause_confirmation", 0.8)
		w.pause_menu.close()
		get_tree().paused = false
		await _shot("04_hud", 1.5)
		get_tree().quit()
		return
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._chests.open(0)
	await _shot("10_coffres_vides")
	lobby._chests.close_ui()
	lobby._archive.open(1)
	await _shot("11_carnet_succes")
	lobby._archive.close_ui()
	lobby._settings.open(5)
	await _shot("12_parametres_interface")
	lobby._settings.close_ui()
	lobby._open_hero("class")
	await _shot("13_heros_classe")
	lobby._open_hero("equipment")
	await _shot("14_heros_equipement")
	get_tree().quit()
