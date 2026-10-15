extends Node
## Captures des bilans de fin de partie (Survie, Duel, Tour, Donjon, Siège, Battle royale), compte neuf et avancé :
## user://shots/u9_<cas>.png
## godot --path game res://tests/shot_results.tscn


func _shot(name: String) -> void:
	await get_tree().create_timer(1.1, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/u9_%s.png" % name)


func _clear() -> void:
	get_tree().paused = false
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame


func _survival(name: String, result: String, advanced: bool) -> void:
	Run.start_survival("warrior", 2 if advanced else 1)
	Run.kills = 212 if advanced else 14
	Run.elites = 9 if advanced else 0
	Run.max_level = 17 if advanced else 3
	Run.stage = 3 if advanced else 1
	Run.gold = 480 if advanced else 25
	Run.started_at = Time.get_ticks_msec() - (14 * 60 + 12 if advanced else 2 * 60 + 40) * 1000
	if advanced:
		Run.seen_items = [1001, 1002, 1003]
		Profile.reward_chests.append(Rewards.make("look_rare", 40, true))
		Profile.reward_chests.append(Rewards.make("forge", 40, true))
		Profile.reward_chests.append(Rewards.make("forge", 40, true))
		Profile.keys = 2
		Profile.add_bag("scroll_power_30") if false else null
		Run.combo_best = 18420.0
		Run.new_classes = ["thief"]
		Run.new_costumes = ["Tenue du boss"]
	Run.finish(result)
	if advanced:
		Run.stars_gained = 1
		Run.contracts_done = [{"text": "Vaincre 100 monstres", "reward": 40}]
		Run.unlocked_epoch = "Époque II" if result == "victoire" else ""
		Run.expertise_levels = 1
	var r := ResultsScreen.new()
	add_child(r)
	r.show_results()
	await _shot(name)
	await _clear()


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	# compte neuf
	await _survival("survie_neuf_defaite", "defaite", false)
	await _survival("survie_neuf_abandon", "abandon", false)
	Profile.reset_all()
	await _survival("survie_avance_victoire", "victoire", true)
	Profile.reset_all()
	await _survival("survie_avance_extraction", "extraction", true)
	Run.start("warrior")
	Run.kills = 40
	Run.max_level = 9
	Run.started_at = Time.get_ticks_msec() - 190 * 1000
	var d := DuelResults.new()
	add_child(d)
	d.show_results(true, "2 - 1", "thief", 2, 5)
	await _shot("duel")
	await _clear()
	Duel.last_report = {"mode": "league", "promoted": true, "rank": 2, "mastery": 120}
	d = DuelResults.new()
	add_child(d)
	d.show_results(false, "0 - 2", "mage" if false else "magician", 1, 0)
	await _shot("duel_ligue")
	await _clear()
	Duel.last_report = {}
	var t := TowerResults.new()
	add_child(t)
	t.show_results("defaite", 14, {"best": 14, "new_record": true, "xp": 130, "levels": 1, "items": 2, "crystals": 15,
		"chests": [Rewards.make("forge", 30, true, "scroll"), Rewards.make("jewel", 30, true, "gem")], "looks": 1})
	await _shot("tour")
	await _clear()
	var g := DungeonResults.new()
	add_child(g)
	g.show_results({"victory": true, "zone": "limestone", "diff": 1, "rooms": 4, "xp": 90,
		"reward": {"chests": [Rewards.make("set", 30, true), Rewards.make("forge", 60, true, "scroll")], "crystals": 90, "plan": "x", "title": ""}})
	await _shot("donjon")
	await _clear()
	g = DungeonResults.new()
	add_child(g)
	g.show_results({"victory": false, "zone": "limestone", "diff": 0, "rooms": 2, "xp": 30, "reward": {}})
	await _shot("donjon_echec")
	await _clear()
	g = DungeonResults.new()
	add_child(g)
	g.show_results({"victory": true, "siege": true, "outcome": "won", "zone": "limestone", "diff": 2, "rooms": 5, "xp": 200,
		"reward": {"chests": [Rewards.make("look_legend", 60, true)], "crystals": 200, "plan": "", "title": ""}})
	await _shot("siege")
	await _clear()
	var r := RoyaleResults.new()
	add_child(r)
	r.show_results(3, 2, 7, 6, 171.0, {"text": ["+90 insignes (place 3, 2 éliminations)", "Coffre d'apparence rare"]})
	await _shot("royale")
	await _clear()
	var c := PauseMenu.Confirm.new()
	add_child(c)
	var t2 := PauseMenu.leave_texts()
	c.ask(t2.title, t2.text, t2.ok, Callable())
	await _shot("confirmation")
	await _clear()
	get_tree().quit()
