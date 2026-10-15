extends Node
## Lot S6 : captures de la page du mode et des bilans du Survivant (victoire avec build, mort précoce sans coffre).
## SV6_RES=1280x720 godot --path game res://tests/shot_sv6.tscn   -> user://shots/sv6/<largeur>x<hauteur>_<nom>.png

var lobby: Node


func _shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots/sv6")
	get_viewport().get_texture().get_image().save_png("user://shots/sv6/%dx%d_%s.png" % [get_viewport().size.x, get_viewport().size.y, name])


func _clear() -> void:
	get_tree().paused = false
	for c in get_children():
		if c != lobby:
			c.queue_free()
	await get_tree().process_frame


func _end(res: String, time: float, guardians: int, cid: String, tier := 1) -> void:
	Survivor.start(cid, "beluga", tier)
	Run.hero_level = 31
	SurvivorGear.equip(SurvivorGear.make_weapon("staff"))
	for slot in ["head", "chest", "legs", "gloves", "boots", "ring"]:
		SurvivorGear.equip(SurvivorGear.make_piece(slot))
	Profile.equipped["head"]["upgrade"] = 10
	Profile.equipped["chest"]["upgrade"] = 6
	var sk: Array = Run.class_data().skills
	for i in 4:
		Run.skills.append({"id": int(sk[i].id), "rank": [7, 4, 3, 1][i]})
	Run.max_level = 31
	Run.kills = 2812
	Run.elites = 64
	SurvivorRewards.stats = {"time": time, "guardians": guardians, "arena": time >= 1200.0, "early": 0.0}
	RunJournal._time = 30.0
	Run.finish(res)
	var r := ResultsScreen.new()
	add_child(r)
	r.show_results()


func _ready() -> void:
	get_tree().create_timer(300.0).timeout.connect(func(): get_tree().quit(1))
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Settings.set_v("interface", "dev_mode", true)
	Quests.set_day("2026-10-15")
	if OS.get_environment("SV6_RES") != "":
		var wh := OS.get_environment("SV6_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().create_timer(0.5).timeout
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._show_menu("survivor")
	await _shot("page_neuve")
	_end("victoire", 1320.0, 3, "magician")
	await _shot("bilan_victoire", 2.6)
	await _clear()
	_end("defaite", 200.0, 0, "magician")
	await _shot("bilan_defaite_precoce", 2.6)
	await _clear()
	_end("defaite", 930.0, 2, "magician", 2)
	await _shot("bilan_defaite_15min", 2.6)
	await _clear()
	Profile.end_run_survival()
	lobby._show_menu("survivor")
	await _shot("page_apres", 0.6)
	get_tree().quit()
