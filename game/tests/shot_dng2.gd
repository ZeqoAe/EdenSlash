extends Node
## Lot DNG-2 : captures de la partie visuelle des modes de boss, en 1600×900 puis 1280×720 (user://shots/dng2_<cas>_<largeur>.png) :
## barre de boss v2, frise « À venir », annonces (critique, moyenne), télégraphes v2 (cercle sûr, anneau immense, météores),
## page Donjons v2 (haut, liste), Carnet > Rencontres, bilans v2 (victoire avec record et butin, défaite « Ce qui t'a battu »).
## godot --path game res://tests/shot_dng2.tscn   (APPDATA détourné : rien n'est sauvegardé chez le joueur)

var res := Vector2i(1600, 900)


func _shot(name: String, wait := 0.8) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	var path := "user://shots/dng2_%s_%d.png" % [name, res.x]
	get_viewport().get_texture().get_image().save_png(path)
	print("[dng2] capture %s" % ProjectSettings.globalize_path(path))


func _size(r: Vector2i) -> void:
	res = r
	DisplayServer.window_set_size(r)
	get_window().size = r
	await get_tree().create_timer(0.5).timeout


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.records["epochs_cleared"] = 2
	Profile.records["dgb_latif_0"] = 3
	Profile.records["dgb_latif_1"] = 1
	Profile.records["dgb_mori_0"] = 2
	Profile.records[BestTimes.KEY] = {BestTimes.boss_key("dungeon", "latif", 0): 118.0, BestTimes.dungeon_key("latif", 0): 252.0}
	Profile.records[Encounters.KEY] = {"latif": {"met": 4, "won": {"dungeon": 4}, "seen": {"meteors": 9, "gale": 5}, "in": {"dungeon": 4, "tower": 1}, "low": 0.41},
		"mori": {"met": 2, "won": {"dungeon": 2}, "seen": {"adds": 3, "puddles": 6}, "in": {"dungeon": 2}, "low": 1.0},
		"argus": {"met": 1, "won": {}, "seen": {"gaze": 2}, "in": {"rush": 1}, "low": 0.37}}
	for r in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		await _size(r)
		await _pages()
		await _results()
	for r in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		await _size(r)
		await _fight()
	get_tree().quit()


func _pages() -> void:
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	DungeonPage.sel = "latif"
	lobby._dg_diff = 0
	lobby._show_menu("dungeon")
	await _shot("page", 2.5)
	lobby._scroll.scroll_vertical = 560
	await _shot("page_bas", 1.2)
	lobby._scroll.scroll_vertical = 1200
	await _shot("page_liste", 1.2)
	lobby._scroll.scroll_vertical = 0
	EncounterJournal.sel = "latif"
	lobby._archive.open(lobby._archive.page_count() - 1)
	await _shot("rencontres", 2.5)
	EncounterJournal.sel = "argus"
	(lobby._archive.page(lobby._archive.page_count() - 1) as EncounterJournal)._pick("argus")
	await _shot("rencontres_argus", 1.5)
	lobby._archive.close_ui()
	lobby.queue_free()
	await get_tree().process_frame


func _results() -> void:
	Run.start("warrior")
	Run.kills = 46
	Run.elites = 3
	Run.max_level = 31
	BestTimes.reset()
	BestTimes.clock = 232.0
	BestTimes.session = [{"key": BestTimes.dungeon_key("latif", 0), "label": "Grotte de Latif", "t": 232.0, "best": 252.0, "new": true},
		{"key": BestTimes.boss_key("dungeon", "latif", 0), "label": "Latif", "t": 104.0, "best": 118.0, "new": true}]
	var c := Rewards.make("set", 46, true)
	c["archetype"] = String(BossLibrary.loot("latif").archetype)
	c["slots"] = (BossLibrary.loot("latif").slots as Array).duplicate()
	var g := DungeonResults.new()
	add_child(g)
	g.show_results({"victory": true, "zone": "beluga", "diff": 0, "rooms": 3, "xp": 520, "boss": "latif", "start_room": 1,
		"reward": {"chests": [c, Rewards.make("forge", 46, true, "scroll")], "crystals": 90, "plan": "plan_latif", "title": ""}})
	await _shot("bilan_victoire", 2.6)
	g.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	HitLog.reset()
	var t := HitLog.clock()
	HitLog._hits = [
		{"t": t - 6.0, "dmg": 900.0, "share": 0.21, "hp": 0.79, "name": "Latif", "brick": "melee", "boss": "latif", "dot": false, "lethal": false},
		{"t": t - 4.0, "dmg": 1300.0, "share": 0.30, "hp": 0.49, "name": "Latif", "brick": "meteors", "boss": "latif", "dot": false, "lethal": false},
		{"t": t - 3.0, "dmg": 700.0, "share": 0.18, "hp": 0.31, "name": "Latif", "brick": "meteors", "boss": "latif", "dot": true, "lethal": false},
		{"t": t - 0.5, "dmg": 1500.0, "share": 0.31, "hp": 0.0, "name": "Latif", "brick": "gale", "boss": "latif", "dot": false, "lethal": true}]
	HitLog._death_at = t - 0.5
	Encounters.last_low = {"latif": 0.22}
	var f := DungeonResults.new()
	add_child(f)
	f.show_results({"victory": false, "zone": "beluga", "diff": 0, "rooms": 2, "xp": 160, "boss": "latif", "start_room": 1, "reward": {}})
	await _shot("bilan_defaite", 2.6)
	f.queue_free()
	get_tree().paused = false
	HitLog.reset()
	Run.active = false
	await get_tree().process_frame


func _fight() -> void:
	Tower.start_dungeon("warrior", "beluga", 0, [], "latif", Dungeons.ROOMS.size())
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var d: RunDirector = world.director
	var p: Player = world.player
	p.dev_invincible = true
	world.cards._queue.clear()
	world.cards._show_next()
	var b: Monster = d.tower._boss
	if b == null:
		print("[dng2] pas de boss")
		world.queue_free()
		return
	b.move_speed = 0.0
	b.hp = b.max_hp * 0.62
	var center: Vector3 = d.tower._center
	p.global_position = center + Vector3(0, 0.5, 8.0)
	b.global_position = center + Vector3(0, 0.3, -2.0)
	await get_tree().create_timer(1.5).timeout
	b.brain._busy = false
	b.brain.note_cast("meteors")
	BossBricks._meteors(b.brain, BossBricks.normalize({"type": "meteors"}).p)
	await _shot("meteores", 1.0)
	await get_tree().create_timer(3.0).timeout
	b.brain._busy = false
	BossBricks.run(b.brain, BossBricks.normalize({"type": "safe_zone"}))
	await _shot("cercle_sur", 1.2)
	await get_tree().create_timer(3.0).timeout
	b.brain._busy = false
	BossBricks.run(b.brain, BossBricks.normalize({"type": "gale"}))
	await _shot("bourrasque", 0.8)
	await get_tree().create_timer(3.5).timeout
	b.global_position = center + Vector3(0, 0.3, -60.0)
	await _shot("hors_vue", 0.6)
	world.queue_free()
	Tower.active = false
	Run.active = false
	await get_tree().create_timer(0.5).timeout
