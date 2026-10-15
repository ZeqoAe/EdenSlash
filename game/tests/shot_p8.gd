extends Node
## Passe P8 : captures des petites cartes d'information (nouveautés du lobby, fiche en jeu, confirmation).
## user://shots/p8/<état>_<largeur>x<hauteur>_<nom>.png
## P8_STATE=neuf|avance P8_RES=1280x720 P8_WHAT=lobby|jeu godot --path game res://tests/shot_p8.tscn   (APPDATA détourné)

var state := "avance"
var lobby: Node


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots/p8")
	get_viewport().get_texture().get_image().save_png("user://shots/p8/%s_%dx%d_%s.png" % [state, get_viewport().size.x, get_viewport().size.y, name])


func _ready() -> void:
	get_tree().create_timer(200.0).timeout.connect(func(): get_tree().quit(1))
	if OS.get_environment("P8_STATE") != "":
		state = OS.get_environment("P8_STATE")
	Settings.reset_all()
	Profile.reset_all()
	if OS.get_environment("P8_RES") != "":
		var wh := OS.get_environment("P8_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().create_timer(0.5).timeout
	if state == "avance":
		Profile.runs_done = 14
		Profile.runs_won = 4
		Profile.best_level = 48
		Profile.insignia = 2400
		Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": "0.1.140"}
	if OS.get_environment("P8_WHAT") == "jeu":
		Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
		Tutorial.pending_card = OS.get_environment("P8_CARD") if OS.get_environment("P8_CARD") != "" else "results"
		Profile.selected_class = "warrior"
		Run.start_survival("warrior", 1)
		var w: Node = load("res://scenes/world.tscn").instantiate()
		add_child(w)
		await _shot("jeu_00", 3.0)
		await _shot("jeu_01_fiche", 2.5)
		var wd: Node = get_child(get_child_count() - 1)
		if wd.get("cards") != null and wd.cards.is_open():
			wd.cards._choose(0)
			await _shot("jeu_02_apres_choix", 2.5)
		get_tree().quit()
		return
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.5).timeout
	await _shot("00_lobby")
	if state == "neuf":
		lobby.info_cards().add_card({"id": "save_notice", "kicker": "Sauvegarde", "title": "Copie saine rechargée", "body": SafeFile.take_notice() if false else "Ta sauvegarde était abîmée. La dernière copie saine a été rechargée ; tu perds au plus la dernière partie.", "icon": "save"})
		await _shot("01_avis", 1.0)
	else:
		lobby._show_news(Tutorial.news_sorted(Tutorial.news_to_show()))
		await _shot("01_nouveautes", 1.2)
		lobby.info_cards().dismiss_top()
		await _shot("02_apres_fermeture", 1.0)
	InfoCard.ask(lobby, "Abandonner la run ?", "L'or, les clés et les fournitures seront perdus.\nLes coffres ramassés et les insignes sont gardés.", "Abandonner", Callable())
	await _shot("03_confirmation", 0.8)
	get_tree().quit()
