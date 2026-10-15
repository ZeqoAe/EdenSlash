extends Node
## Passe M5 : captures de la page Quêtes (et de l'étiquette de Jouer), avec une série et des quêtes avancées.
## user://shots/m5/<largeur>x<hauteur>_<nom>.png
## M5_RES=1280x720 godot --path game res://tests/shot_m5.tscn   (APPDATA détourné)
## M5_PREP=1 : prépare seulement le profil (quêtes choisies, série) et quitte, pour une capture du HUD en jeu.

var lobby: Node


func _shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots/m5")
	get_viewport().get_texture().get_image().save_png("user://shots/m5/%dx%d_%s.png" % [get_viewport().size.x, get_viewport().size.y, name])


func _profile() -> void:
	Profile.runs_done = 14
	Profile.runs_won = 4
	Profile.best_level = 48
	Profile.insignia = 2400
	Profile.materials["crystal"] = 520
	Profile.records["epochs_cleared"] = 3
	Profile.records["duel_wins"] = 4
	Profile.selected_class = "warrior"
	for i in 5:
		Profile.reward_chests.append(Rewards.make("gear", 30))
	var st := Quests.state()
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var list: Array = []
	var ids := ["daily_challenge", "dg_clean", "du_win"]
	if OS.get_environment("M5_PREP") != "":
		ids = ["daily_challenge", "sv_kills", "sv_elites"]  # pour le HUD d'une Survie
	for id in ids:
		var q := Quests.make(QuestPool.get_def(id), "daily", list.size(), r)
		list.append(q)
	list[1]["r"] = {"crystal": 50}
	list[2]["r"] = {"mastery": 250}
	list[2]["p"] = 1
	st["daily"] = list
	var wk: Array = []
	for id in ["tw_climb", "sv_elites"]:
		wk.append(Quests.make(QuestPool.get_def(id), "weekly", wk.size(), r))
	wk[0]["p"] = 13
	wk[1]["p"] = 50
	wk[1]["done"] = true
	st["weekly"] = wk
	st["series"] = {"n": 5, "last": Quests.today(), "claimed": [3], "best": 5}
	var c := Contracts.state("warrior")
	c.progress[String(c.active[0])] = 120


func _ready() -> void:
	get_tree().create_timer(240.0).timeout.connect(func(): get_tree().quit(1))
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	if OS.get_environment("M5_RES") != "":
		var wh := OS.get_environment("M5_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().create_timer(0.5).timeout
	_profile()
	if OS.get_environment("M5_PREP") != "":
		Training.active = false  # (l'entraînement n'enregistre rien)
		Profile.save_profile()
		get_tree().quit()
		return
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._show_menu("play")
	await _shot("01_jouer")
	lobby._show_menu("quests")
	await _shot("02_quetes")
	lobby._scroll.scroll_vertical = 600
	await _shot("03_quetes_bas")
	get_tree().quit()
