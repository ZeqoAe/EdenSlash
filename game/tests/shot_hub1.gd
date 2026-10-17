extends Node
## Lot HUB-1 : captures du menu principal (Continuer, pastilles, « Aujourd'hui », bulle « Ta quête »), de Jouer (« Conseillé »),
## du Journal (5 onglets) et des Paramètres (HUD en partie) dans user://shots/hub1/ ; lignes « [débord] » comme shot_p1.
##   HUB1_STATE=neuf|avance HUB1_RES=1280x720 godot --path game res://tests/shot_hub1.tscn
## HUD en partie (quête épinglée, file de cartes, taille du HUD HUB1_HUD_SCALE) : une Survie au pilote automatique :
##   HUB1_HUD_SCALE=1.2 godot --path game res://tests/shot_hub1.tscn -- --hud --autoplay --god --shots=6,14 --shot-prefix=hub1_hud --quit-at=16
## APPDATA détourné : rien n'est écrit chez le joueur.

var state := "avance"
var lobby: Node


func _overflow(name: String) -> void:
	var size := get_viewport().get_visible_rect().size
	var stack: Array = [get_tree().root]
	var found := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is ScrollContainer or (n is CanvasItem and not (n as CanvasItem).visible):
			continue
		for c in n.get_children():
			stack.append(c)
		if n is Control and (n as Control).is_visible_in_tree():
			var r := (n as Control).get_global_rect()
			if r.size.x > 1.0 and r.size.y > 1.0 and (r.end.x > size.x + 1.0 or r.end.y > size.y + 1.0):
				if found < 6:
					print("[débord] %s : %s %s fin (%d, %d) sur (%d, %d)" % [name, n.get_class(), n.name, r.end.x, r.end.y, size.x, size.y])
				found += 1


func _shot(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	_overflow(name)
	DirAccess.make_dir_recursive_absolute("user://shots/hub1")
	var path := "user://shots/hub1/%s_%dx%d_%s.png" % [state, get_viewport().size.x, get_viewport().size.y, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("[capture] ", ProjectSettings.globalize_path(path))


func _advanced() -> void:
	Profile.unlocked_features = Unlocks.LIST.keys()
	Profile.runs_done = 14
	Profile.runs_won = 4
	Profile.insignia = 2400
	Profile.materials["crystal"] = 520
	Profile.records["epochs_cleared"] = 2
	for t in ["gear", "look_rare", "set"]:
		Profile.reward_chests.append(Rewards.make(t, 40))
	Profile.expertise["warrior"] = 9000
	var daily: Array = Quests.daily()
	if daily.size() >= 3:
		daily[0]["done"] = true
		daily[1]["p"] = maxi(1, int(daily[1].t) - 1)
		Quests.toggle_pin("daily", daily[1])
	Quests.state().series["n"] = 5
	Quests.state().series["last"] = Quests.today()
	LastActivity.record("survival", {"epoch": 2})
	# pastilles : une activité, une apparence, un succès nouveaux depuis la dernière visite
	NewsDots.count("play")
	Profile.records.news.seen.play.erase("act:tower")
	Profile.owned_outfits.append("hub1_demo_look")
	Profile.achievements["hub1_demo"] = Quests.today()


func _ready() -> void:
	get_tree().create_timer(240.0).timeout.connect(func(): get_tree().quit(1))
	if OS.get_environment("HUB1_STATE") != "":
		state = OS.get_environment("HUB1_STATE")
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Quests.set_day("2026-10-15")
	if "--hud" in OS.get_cmdline_user_args():
		_hud()
		return
	if OS.get_environment("HUB1_RES") != "":
		var wh := OS.get_environment("HUB1_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().create_timer(0.5).timeout
	Training.active = true  # (le lobby ne lance rien au premier argument)
	if state == "avance":
		_advanced()
	Training.active = false
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby.info_cards().dismiss_all()
	await _shot("00_menu")
	lobby._show_menu("play")
	await _shot("01_jouer")
	lobby._show_menu("")
	var j: QuestJournal = lobby._open_journal()
	for i in j.page_count():
		j.show_page(i)
		await _shot("02_journal_%d" % i)
	j.close_ui()
	lobby._settings.open(3)
	await get_tree().create_timer(1.0).timeout  # (les pages des Paramètres se construisent une par image)
	await _shot("03_parametres_affichage")
	var sc: ScrollContainer = null
	for n in lobby._settings.page(3).find_children("*", "ScrollContainer", true, false):
		sc = n
	if sc != null:
		sc.scroll_vertical = 2000
		await _shot("03_parametres_affichage_bas")
	lobby._settings.close_ui()
	get_tree().quit()


## Une Survie au pilote, quêtes ouvertes et une quête épinglée, taille du HUD réglable (HUB1_HUD_SCALE).
func _hud() -> void:
	Profile.unlocked_features = Unlocks.LIST.keys()
	Profile.runs_done = 5
	var daily: Array = Quests.daily()
	if daily.size() >= 3:
		Quests.toggle_pin("daily", daily[2])
	if OS.get_environment("HUB1_HUD_SCALE") != "":
		Settings.set_v("interface", "hud_scale", float(OS.get_environment("HUB1_HUD_SCALE")))
	if OS.get_environment("HUB1_HUD_OPACITY") != "":
		Settings.set_v("interface", "hud_opacity", float(OS.get_environment("HUB1_HUD_OPACITY")))
	Profile.save_profile()
	Run.start_survival("warrior", 1, 0)
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
