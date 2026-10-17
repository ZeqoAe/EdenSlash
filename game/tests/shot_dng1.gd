extends Node
## Lot DNG-1 : captures des bilans enrichis (temps contre record, butin en cases, pièces qui manquent, objectifs du Siège,
## « Ce qui t'a battu », Réessayer le boss / Reprendre) : user://shots/dng1_<cas>_<largeur>.png, en 1600×900 puis 1280×720.
## godot --path game res://tests/shot_dng1.tscn   (APPDATA détourné : rien n'est sauvegardé chez le joueur)


func _shot(name: String) -> void:
	await get_tree().create_timer(2.4, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	var path := "user://shots/dng1_%s_%d.png" % [name, get_viewport().size.x]
	get_viewport().get_texture().get_image().save_png(path)
	print("[dng1] capture %s" % ProjectSettings.globalize_path(path))


func _clear() -> void:
	get_tree().paused = false
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame


func _fake_fall() -> void:
	HitLog.reset()
	var t := HitLog.clock()
	HitLog._hits = [
		{"t": t - 6.0, "dmg": 900.0, "share": 0.21, "hp": 0.79, "name": "Latif", "brick": "melee", "boss": "latif", "dot": false, "lethal": false},
		{"t": t - 4.0, "dmg": 1300.0, "share": 0.30, "hp": 0.49, "name": "Latif", "brick": "meteors", "boss": "latif", "dot": false, "lethal": false},
		{"t": t - 3.0, "dmg": 700.0, "share": 0.18, "hp": 0.31, "name": "Latif", "brick": "meteors", "boss": "latif", "dot": true, "lethal": false},
		{"t": t - 0.5, "dmg": 1500.0, "share": 0.31, "hp": 0.0, "name": "Latif", "brick": "marks", "boss": "latif", "dot": false, "lethal": true},
	]
	HitLog._death_at = t - 0.5


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Run.start("warrior")
	Run.kills = 46
	Run.elites = 3
	Run.max_level = 31
	for res in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		DisplayServer.window_set_size(res)
		get_window().size = res
		await get_tree().create_timer(0.5).timeout
		# victoire : temps contre record, butin en cases, pièce qui manque
		BestTimes.reset()
		BestTimes.clock = 252.0
		BestTimes.session = [{"key": BestTimes.dungeon_key("latif", 1), "label": "Grotte de Latif", "t": 252.0, "best": 271.0, "new": true},
			{"key": BestTimes.boss_key("dungeon", "latif", 1), "label": "Latif", "t": 118.0, "best": 140.0, "new": true}]
		var c := Rewards.make("set", 46, true)
		c["archetype"] = String(BossLibrary.loot("latif").archetype)
		c["slots"] = (BossLibrary.loot("latif").slots as Array).duplicate()
		var g := DungeonResults.new()
		add_child(g)
		g.show_results({"victory": true, "zone": "beluga", "diff": 1, "rooms": 3, "xp": 520, "boss": "latif", "start_room": 1,
			"reward": {"chests": [c, Rewards.make("forge", 46, true, "scroll")], "crystals": 90, "plan": "plan_latif", "title": ""}})
		await _shot("donjon_victoire")
		await _clear()
		# chute devant le boss : ce qui t'a battu, réessayer le boss
		BestTimes.reset()
		BestTimes.clock = 340.0
		_fake_fall()
		Encounters.last_low = {"latif": 0.22}
		Profile.records[Encounters.KEY] = {"latif": {"met": 4, "low": 0.41, "won": {}, "seen": {"meteors": 9}, "in": {"dungeon": 4}}}
		g = DungeonResults.new()
		add_child(g)
		g.show_results({"victory": false, "zone": "beluga", "diff": 1, "rooms": 2, "xp": 160, "boss": "latif", "reward": {}})
		await _shot("donjon_chute")
		await _clear()
		# Tour : chute à l'étage 12, partie de l'étage 1
		Tower.start_floor = 1
		Tower.difficulty = 1
		Profile.records[Tower.record_key(1)] = 11
		Tower.found = [Items.generate(24, 0.0, "head", "warrior", 4, "", 0), Items.generate(24, 0.0, "gloves", "warrior", 3, "", 0)]
		_fake_fall()
		BestTimes.session = [{"key": BestTimes.tower_key(1, 0), "label": "Étages 1-10", "t": 431.0, "best": 466.0, "new": true}]
		var t := TowerResults.new()
		add_child(t)
		t.show_results("defaite", 11, {"best": 11, "new_record": true, "xp": 130, "levels": 1, "items": 2, "crystals": 15,
			"chests": [Rewards.make("forge", 30, true, "scroll")], "looks": 0})
		await _shot("tour_chute")
		await _clear()
		# Siège : objectifs ★
		HitLog.reset()
		BestTimes.reset()
		g = DungeonResults.new()
		add_child(g)
		g.show_results({"victory": true, "siege": true, "outcome": "won", "zone": "limestone", "diff": 0, "rooms": 6, "xp": 200,
			"reward": {"chests": [], "crystals": 120, "stars": ["boss", "fast"], "new_stars": ["fast"]}})
		await _shot("siege")
		await _clear()
	get_tree().quit()
