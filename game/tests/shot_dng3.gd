extends Node
## Lot DNG-3 : captures, en 1600×900 puis 1280×720 (user://shots/dng3_<cas>_<largeur>.png) : page Donjons (objectifs ★,
## « S'entraîner »), page Ruée (« Tes temps »), bilans (victoire avec étoiles, chute avec S'entraîner), combat de donjon (pastille
## « Relève 1 », zones en améthyste, mur d'arène mandarine), salle d'entraînement, fil des temps de la Ruée, tableau du Siège.
## godot --path game res://tests/shot_dng3.tscn   (APPDATA détourné : rien n'est sauvegardé chez le joueur ; DNG3_RES=1280x720 + --resolution)

var res := Vector2i(1600, 900)


func _shot(name: String, wait := 0.8) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	var path := "user://shots/dng3_%s_%d.png" % [name, res.x]
	get_viewport().get_texture().get_image().save_png(path)
	print("[dng3] capture %s" % ProjectSettings.globalize_path(path))


func _size(r: Vector2i) -> void:
	res = r
	DisplayServer.window_set_size(r)
	get_window().size = r
	await get_tree().create_timer(0.5, true).timeout


func _profile() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.records["epochs_cleared"] = 2
	Profile.records["dgb_mori_0"] = 3
	Profile.records["dgs_mori_0"] = 5
	Profile.records["dgs_latif_0"] = 7
	Profile.records[BestTimes.KEY] = {BestTimes.boss_key("dungeon", "mori", 0): 118.0, BestTimes.dungeon_key("mori", 0): 402.0}
	var s := Rush.current_seed()
	RushBoard.add(s, 0, 731.0, [], int(Profile.records.get("rush_prev", 0)))
	RushBoard.add(s, 0, 802.0, ["blind"], int(Profile.records.get("rush_prev", 0)))
	RushBoard.add(4821, 0, 655.0, ["enraged"], 0)
	Profile.save_profile()


## Tailles : 1600×900 puis 1280×720 ; variable d'environnement DNG3_RES=1280x720 (avec « --resolution 1280x720 ») : une seule,
## si la fenêtre ne se redimensionne pas d'elle-même (pas d'argument « -- » : le menu principal le prendrait pour un lancement).
func _sizes() -> Array:
	var e := OS.get_environment("DNG3_RES")
	if e.contains("x"):
		var p := e.split("x")
		return [Vector2i(int(p[0]), int(p[1]))]
	return [Vector2i(1600, 900), Vector2i(1280, 720)]


func _ready() -> void:
	for r in _sizes():
		await _size(r)
		_profile()
		await _pages()
		await _results()
	for r in _sizes():
		await _size(r)
		_profile()
		await _fight()
		_profile()
		await _practice()
		_profile()
		await _rush()
		_profile()
		await _siege()
	get_tree().quit()


func _pages() -> void:
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0, true).timeout
	DungeonPage.sel = "mori"
	lobby._dg_diff = 0
	lobby._show_menu("dungeon")
	await _shot("page", 2.5)
	lobby._scroll.scroll_vertical = 380
	await _shot("page_objectifs", 1.2)
	lobby._scroll.scroll_vertical = 0
	lobby._show_menu("rush")
	await _shot("page_ruee", 1.5)
	lobby._scroll.scroll_vertical = 600
	await _shot("page_ruee_bas", 1.2)
	lobby.queue_free()
	get_tree().paused = false  # (le menu principal peut mettre en pause : fondu, accueil)
	await get_tree().process_frame


func _results() -> void:
	Run.start("warrior")
	Run.kills = 46
	Run.elites = 3
	Run.max_level = 31
	BestTimes.reset()
	BestTimes.clock = 402.0
	BestTimes.session = [{"key": BestTimes.dungeon_key("mori", 0), "label": "Grotte de Mori", "t": 402.0, "best": 0.0, "new": true}]
	var c := Rewards.make("set", 46, true)
	c["archetype"] = String(BossLibrary.loot("mori").archetype)
	c["slots"] = (BossLibrary.loot("mori").slots as Array).duplicate()
	var g := DungeonResults.new()
	add_child(g)
	g.show_results({"victory": true, "zone": "limestone", "diff": 0, "rooms": 3, "xp": 520, "boss": "mori", "start_room": 1,
		"dstars": {"stars": ["clear", "time"], "new": ["time"], "titles": [], "chests": []}, "reliefs": 1,
		"reward": {"chests": [c], "crystals": 90, "plan": "", "title": ""}})
	await _shot("bilan_victoire", 2.6)
	g.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	HitLog.reset()
	var t := HitLog.clock()
	HitLog._hits = [
		{"t": t - 4.0, "dmg": 1300.0, "share": 0.45, "hp": 0.55, "name": "Mori", "brick": "puddles", "boss": "mori", "dot": true, "lethal": false},
		{"t": t - 0.5, "dmg": 1500.0, "share": 0.55, "hp": 0.0, "name": "Mori", "brick": "adds", "boss": "mori", "dot": false, "lethal": true}]
	HitLog._death_at = t - 0.5
	var f := DungeonResults.new()
	add_child(f)
	f.show_results({"victory": false, "zone": "limestone", "diff": 0, "rooms": 2, "xp": 160, "boss": "mori", "start_room": 1, "reward": {}})
	await _shot("bilan_chute", 2.6)
	f.queue_free()
	get_tree().paused = false
	HitLog.reset()
	Run.active = false
	await get_tree().process_frame


func _world() -> Node:
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0, true).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	return world


func _end(world: Node) -> void:
	world.queue_free()
	Tower.active = false
	Run.active = false
	BossPractice.active = false
	get_tree().paused = false
	await get_tree().create_timer(0.5, true).timeout


func _fight() -> void:
	Settings.set_v("interface", "tele_palette", "amethyste")
	Tower.start_dungeon("warrior", "limestone", 0, [], "mori", Dungeons.ROOMS.size())
	var world: Node = await _world()
	var d: RunDirector = world.director
	var p: Player = world.player
	p.dev_invincible = true
	var b: Monster = d.tower._boss
	b.move_speed = 0.0
	b.hp = b.max_hp * 0.62
	var center: Vector3 = d.tower._center
	p.global_position = center + Vector3(0, 0.5, 8.0)
	b.global_position = center + Vector3(0, 0.3, -2.0)
	await get_tree().create_timer(1.5, true).timeout
	b.brain._busy = false
	b.brain.note_cast("meteors")
	BossBricks._meteors(b.brain, BossBricks.normalize({"type": "meteors"}).p)
	await _shot("combat_releve_amethyste", 1.0)
	await get_tree().create_timer(3.0, true).timeout
	b.brain._busy = false
	BossBricks.run(b.brain, BossBricks.normalize({"type": "shrink"}))
	await _shot("mur_mandarine", 4.0)
	Settings.set_v("interface", "tele_palette", "auto")
	await _end(world)


func _practice() -> void:
	BossPractice.start("warrior", "mori", 0)
	var world: Node = await _world()
	await _shot("entrainement", 1.5)
	await _end(world)


func _rush() -> void:
	Tower.start_dungeon("warrior", Dungeons.RUSH, 0, [])
	var world: Node = await _world()
	var td = world.director.tower
	var p: Player = world.player
	p.dev_invincible = true
	await get_tree().create_timer(2.0, true).timeout
	td._boss.take_damage(td._boss.max_hp * 50.0, p)
	await get_tree().create_timer(1.0, true).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	td._spawn_stairs()
	td.interact(td._goal)
	await get_tree().create_timer(3.0, true).timeout
	await _shot("ruee_fil", 0.8)
	await _end(world)


func _siege() -> void:
	Tower.start_siege("warrior", "limestone", 0, ["priest", "warrior"])
	var world: Node = await _world()
	var td = world.director.tower
	var p: Player = world.player
	p.dev_invincible = true
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	Tower.reached = Siege.WAVES
	td.begin(Siege.WAVES + 1)
	await get_tree().create_timer(1.0, true).timeout
	var b: Monster = td._boss
	b.move_speed = 0.0
	p.global_position = td._center + Vector3(0, 0.5, 7.0)
	b.global_position = td._center + Vector3(0, 0.3, -2.0)
	b.take_damage(b.max_hp * 0.15, p)
	for a in td._allies:
		b.take_damage(b.max_hp * 0.1, a)
	await _shot("siege_tableau", 6.0)
	b.take_damage(b.max_hp * 50.0, p)
	await _shot("siege_anneau", 3.0)
	await _end(world)
