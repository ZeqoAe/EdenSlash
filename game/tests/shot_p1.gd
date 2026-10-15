extends Node
## Passe P1 : captures de toutes les pages du lobby et du Carnet (user://shots/p1/<état>_<nom>.png).
## P1_STATE=neuf|avance P1_RES=1280x720 godot --path game res://tests/shot_p1.tscn
## APPDATA détourné : le test ne sauvegarde rien chez le joueur.

var state := "neuf"


## Contrôles visibles hors de l'écran (hors zones qui défilent) : une ligne « [débord] » par contrôle.
func _overflow(name: String) -> void:
	var size := get_viewport().get_visible_rect().size
	var stack: Array = [get_tree().root]
	var found := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is ScrollContainer or (n is CanvasItem and not (n as CanvasItem).visible):
			continue
		if n is Window and n != get_tree().root:
			continue
		for c in n.get_children():
			stack.append(c)
		if n is Control and (n as Control).is_visible_in_tree():
			var r := (n as Control).get_global_rect()
			if r.size.x > 1.0 and r.size.y > 1.0 and (r.end.x > size.x + 1.0 or r.end.y > size.y + 1.0) and not (n is TextureRect and n.get_parent() is Control and (n as Control).get_parent().name == "bg"):
				if found < 6:
					print("[débord] %s : %s %s fin (%d, %d) sur (%d, %d)" % [name, n.get_class(), n.get_path().get_name(n.get_path().get_name_count() - 1), r.end.x, r.end.y, size.x, size.y])
				found += 1
	if found > 6:
		print("[débord] %s : … et %d autres" % [name, found - 6])


func _shot(name: String) -> void:
	await get_tree().create_timer(0.55).timeout
	_overflow(name)
	DirAccess.make_dir_recursive_absolute("user://shots/p1")
	get_viewport().get_texture().get_image().save_png("user://shots/p1/%s_%dx%d_%s.png" % [state, get_viewport().size.x, get_viewport().size.y, name])


func _advanced() -> void:
	Profile.unlocked_features = Unlocks.LIST.keys()
	Profile.runs_done = 14
	Profile.runs_won = 4
	Profile.best_level = 48
	Profile.insignia = 2400
	Profile.materials["crystal"] = 520
	Profile.records["kills"] = 3200
	Profile.records["epochs_cleared"] = 2
	Profile.plans = ["plan_limestone", "plan_rainbowfall"]
	var ids: Array = []
	for ep in [1, 2]:
		for box in ["head", "chest", "legs", "jewel"]:
			for e in SlotChests.pool(box, ep, 2).slice(0, 5):
				ids.append(int(e.id))
	Profile.seen_gear = ids
	for t in ["gear", "look_rare", "set", "aura_rare"]:
		Profile.reward_chests.append(Rewards.make(t, 40))
	Profile.reward_chests.append(Rewards.make("forge", 60, false, "scroll"))
	Profile.reward_chests.append(Rewards.make("jewel", 60, false, "gem"))
	for i in 3:
		Profile.inventory.append(Items.generate(40 + i, 1.0, ["weapon", "chest", "head"][i], "samurai", 1, "", 3))
	Profile.stash = {Craft.fortify_key("power", 40): 4, "stone:safety": 2, Craft.gem_key("ruby", 0): 5}
	for cid in ["warrior", "samurai"]:
		Profile.expertise[cid] = 9000
	Profile.title = "Habitué"


func _ready() -> void:
	get_tree().create_timer(300.0).timeout.connect(func(): get_tree().quit(1))  # garde-fou : jamais de fenêtre qui reste ouverte
	if OS.get_environment("P1_STATE") != "":
		state = OS.get_environment("P1_STATE")  # pas d'argument : le lobby lance une run au premier « -- » inconnu
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	if OS.get_environment("P1_RES") != "":
		var wh := OS.get_environment("P1_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().create_timer(0.5).timeout
	if state == "avance":
		_advanced()
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	await _shot("00_lobby")
	for id in ["play", "survival", "training", "dungeon", "arenas", "royale", "rush", "siege", "trials", "mastery", "tower", "tower_floors", "duel", "quit"]:
		lobby._show_menu(id)
		await _shot("01_menu_" + id)
	for t in ["league", "pantheon", "gauntlet"]:
		lobby._duel_tab = t
		lobby._show_menu("duel")
		await _shot("01_menu_duel_" + t)
	lobby._show_menu("")
	for sec in ["equipment", "class", "appearance", "cards"]:
		lobby._open_hero(sec)
		await _shot("02_hero_" + sec)
	lobby._hero.close_ui()
	for i in lobby._chests.page_count():
		lobby._chests.open(i)
		await _shot("03_coffres_%d" % i)
	lobby._chests.open(0)
	lobby._chests.page(0)._set_shop(1)
	await _shot("03_coffres_boutique")
	lobby._chests.page(0)._set_shop(0)
	lobby._chests.close_ui()
	if state == "avance":  # classe en retard : le bouton de leçon de maîtrise
		Profile.selected_class = "hunter"
		lobby._open_hero("class")
		await _shot("02_hero_class_retard")
		lobby._hero.close_ui()
		Profile.selected_class = "warrior"
	for i in lobby._archive.page_count():
		lobby._archive.open(i)
		await _shot("04_carnet_%02d" % i)
	lobby._archive.close_ui()
	for i in lobby._workshop.page_count():
		lobby._workshop.open(i)
		await _shot("05_atelier_%d" % i)
	lobby._workshop.close_ui()
	for i in lobby._settings.page_count():
		lobby._settings.open(i)
		await _shot("06_params_%d" % i)
	lobby._settings.close_ui()
	var g := Guide.open_on(lobby)
	for i in g.page_count():
		g.show_page(i)
		await _shot("07_guide_%d" % i)
	get_tree().quit()
