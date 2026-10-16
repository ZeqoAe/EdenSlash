extends Node
## Lot S8 : captures du Survivant ouvert à tous (sans mode dev) : menu Jouer (carte illustrée), page du mode sur un compte neuf
## puis avec trois paliers gagnés (sélecteur), bilan de victoire qui ouvre un palier, puis une vraie run au palier IV : premier
## choix, carte en cours (Menace 2), arène (mécanique de boss en plus), bilan d'abandon.
## SV8_RES=1280x720 godot --path game res://tests/shot_sv8.tscn   -> user://shots/sv8/<largeur>x<hauteur>_<nom>.png

const WORLD := "res://scenes/world.tscn"

var lobby: Node


func _shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots/sv8")
	get_viewport().get_texture().get_image().save_png("user://shots/sv8/%dx%d_%s.png" % [get_viewport().size.x, get_viewport().size.y, name])


func _until(cond: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit and not cond.call():
		await get_tree().create_timer(0.1, true, false, true).timeout
		t += 0.1
	return cond.call()


func _world() -> Node:
	var s := get_tree().current_scene
	return s if s != null and s.has_method("end_run") and s.get("director") != null and s.get("hud") != null else null


func _ready() -> void:
	if name != "Sv8Shots":
		var d: Node = (load("res://tests/shot_sv8.gd") as GDScript).new()
		d.name = "Sv8Shots"
		get_tree().root.add_child.call_deferred(d)
		return
	get_tree().create_timer(600.0, true, false, true).timeout.connect(func(): get_tree().quit(1))
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Settings.set_v("interface", "dev_mode", false)
	Quests.set_day("2026-10-25")
	if OS.get_environment("SV8_RES") != "":
		var wh := OS.get_environment("SV8_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
	await get_tree().create_timer(2.5).timeout
	lobby = get_tree().current_scene
	lobby._show_menu("")
	lobby._on_menu("play")
	await _shot("jouer", 1.0)
	lobby._show_menu("survivor")
	await _shot("page_compte_neuf")
	Profile.records[SurvivorRewards.KEY] = {"wins": {"1": 2, "2": 1, "3": 1}, "first": ["time:1", "guardians:1", "win:1", "time:2"], "day": "", "today": []}
	lobby._sv_palier = 0
	lobby._show_menu("survivor")
	await _shot("page_paliers")
	# une vraie run au palier IV
	lobby._sv_zone = "beluga"
	lobby._start_survivor()
	if not await _until(func(): return _world() != null, 90.0):
		get_tree().quit(1)
		return
	var w := _world()
	await _until(func(): return w.cards.is_open(), 30.0)
	await _shot("premier_choix", 1.2)
	w.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
	w.cards._choose(0)
	w.player.autoplay = true
	w.player.dev_invincible = true
	await get_tree().create_timer(25.0, true, false, true).timeout
	for i in 4:
		if w.cards.is_open():
			w.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
			w.cards._choose(0)
			await get_tree().create_timer(0.4, true, false, true).timeout
	await _shot("carte_palier_iv", 0.3)
	var d: RunDirector = w.director
	d.time = 1199.8
	await _until(func(): return d.state == "boss" and is_instance_valid(d._boss), 20.0)
	await _shot("arene_palier_iv", 1.4)
	w.pause_menu.abandon_requested.emit()
	await _until(func(): return get_tree().current_scene.get_children().any(func(c): return c is ResultsPanel), 25.0)
	await _shot("bilan_abandon", 2.8)
	get_tree().quit()
