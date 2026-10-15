extends Node
## Passe P6 : captures de la boussole, des pages d'activité (pastilles de gains) et des bilans (ligne de quête).
## user://shots/p6/<état>_<largeur>x<hauteur>_<nom>.png
## P6_STATE=neuf|debut|avance P6_RES=1280x720 godot --path game res://tests/shot_p6.tscn   (APPDATA détourné)

var state := "neuf"
var lobby: Node


func _shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots/p6")
	get_viewport().get_texture().get_image().save_png("user://shots/p6/%s_%dx%d_%s.png" % [state, get_viewport().size.x, get_viewport().size.y, name])


func _debut() -> void:
	Profile.runs_done = 1
	Profile.insignia = 120
	for box in ["head", "chest", "weapon", "back"]:
		for it in SlotChests.offer(box, 1, 1, 2):
			Profile.seen_gear.append(int(it.eden))


func _advanced() -> void:
	Profile.runs_done = 14
	Profile.runs_won = 4
	Profile.best_level = 48
	Profile.insignia = 2400
	Profile.materials["crystal"] = 520
	Profile.records["epochs_cleared"] = 2
	Profile.records["duel_wins"] = 2
	Profile.plans = ["plan_limestone"]
	for ep in [1, 2]:
		for box in ["head", "chest", "legs", "jewel", "back", "weapon"]:
			for e in SlotChests.pool(box, ep, 2).slice(0, 5):
				Profile.seen_gear.append(int(e.id))
	for t in ["gear", "look_rare", "set"]:
		Profile.reward_chests.append(Rewards.make(t, 40))
	Items.reward_zone = "wetlands"
	var gear := {}
	for slot in Items.SLOTS:
		var it := Items.generate(45, 0.9, slot, "warrior", Items.MYTHIC, "", Items.LEGENDARY)
		it["upgrade"] = 3
		Profile.vault.append(it)
		gear[slot] = it
	Items.reward_zone = ""
	Profile.install_gear(gear)
	Profile._lobby_view()
	Profile.stash = {Craft.fortify_key("power", 40): 4, "stone:safety": 2, Craft.gem_key("ruby", 0): 5, Craft.scroll_key("optimize", 3): 1}


func _clear_bilan() -> void:
	get_tree().paused = false
	for c in get_children():
		if c != lobby:
			c.queue_free()
	await get_tree().process_frame


func _bilans() -> void:
	lobby.queue_free()
	await get_tree().process_frame
	Profile.in_run = false
	Run.start_survival("warrior", 1)
	Run.kills = 212
	Run.elites = 9
	Run.max_level = 17
	Run.stage = 3
	Run.started_at = Time.get_ticks_msec() - 14 * 60 * 1000
	Run.seen_items = [1001, 1002, 1003]
	Run.finish("victoire")
	Run.unlocked_epoch = "Époque II"
	var r := ResultsScreen.new()
	add_child(r)
	r.show_results()
	await _shot("bilan_survie", 2.4)
	await _clear_bilan()
	Run.start("warrior")
	var t := TowerResults.new()
	add_child(t)
	t.show_results("defaite", 14, {"best": 14, "new_record": true, "xp": 130, "levels": 0, "items": 2, "crystals": 15,
		"chests": [Rewards.make("forge", 30, true, "scroll")], "looks": 1})
	await _shot("bilan_tour", 2.4)
	await _clear_bilan()
	var dg := DungeonResults.new()
	add_child(dg)
	var set_chest := Rewards.make("set", 60, true)
	set_chest["archetype"] = "storm"
	dg.show_results({"victory": true, "zone": "limestone", "diff": 1, "rooms": 4, "xp": 300,
		"reward": {"chests": [set_chest, Rewards.make("forge", 60)], "crystals": 90, "plan": "plan_limestone", "title": ""}})
	await _shot("bilan_donjon", 2.4)
	await _clear_bilan()


func _ready() -> void:
	get_tree().create_timer(300.0).timeout.connect(func(): get_tree().quit(1))
	if OS.get_environment("P6_STATE") != "":
		state = OS.get_environment("P6_STATE")
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	if OS.get_environment("P6_RES") != "":
		var wh := OS.get_environment("P6_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().create_timer(0.5).timeout
	if state == "debut":
		_debut()
	elif state == "avance":
		_advanced()
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	await _shot("00_lobby")
	for id in ["play", "survival", "dungeon", "tower", "rush", "siege", "mastery", "duel", "arenas", "royale"]:
		lobby._show_menu(id)
		await _shot("01_" + id)
	lobby._show_menu("")
	if state != "neuf":
		lobby._workshop.open(0)
		await _shot("02_atelier_armurerie")
		lobby._workshop.open(2)
		await _shot("02_atelier_forge")
		lobby._workshop.close_ui()
	lobby._compass_open(lobby._compass_go)
	await _shot("03_apres_clic_boussole")
	await _bilans()
	get_tree().quit()
