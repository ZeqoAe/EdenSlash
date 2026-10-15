extends Node
## Chaque écran est-il entièrement atteignable à la manette ? (croix directionnelle seulement)
## godot --headless --path game res://tests/test_nav_screens.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


## Part du premier candidat et explore en déplaçant le curseur ; renvoie [atteints, total].
func reach() -> Array:
	var all: Array = UiNav.candidates()
	if all.is_empty():
		return [0, 0]
	UiNav.cursor = null
	UiNav._last_center = Vector2.ZERO
	UiNav.pick_default()
	var seen := {UiNav.cursor: true}
	var todo: Array = [UiNav.cursor]
	while not todo.is_empty():
		var c: Control = todo.pop_back()
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			UiNav.cursor = c
			if UiNav.move(d) and not seen.has(UiNav.cursor):
				seen[UiNav.cursor] = true
				todo.append(UiNav.cursor)
	return [seen.size(), all.size()]


func probe(label: String, min_ratio := 0.9) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var r := reach()
	var ok: bool = r[1] > 0 and float(r[0]) / float(r[1]) >= min_ratio
	check("%s : %d / %d contrôles atteignables" % [label, r[0], r[1]], ok)


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Gamepad.active = true
	get_tree().root.size = Vector2i(1600, 900)
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.5).timeout
	await probe("lobby : menu de gauche")
	lobby._on_menu("play")
	await probe("lobby : Jouer")
	lobby._show_menu("survival")
	await probe("lobby : Survie")
	lobby._show_menu("duel")
	await probe("lobby : Duel")
	lobby._show_menu("")
	lobby._chests.open(0)
	await probe("Coffres")
	lobby._chests.close_ui()
	lobby._archive.open(0)
	await probe("Carnet : vue d'ensemble")
	lobby._archive.show_page(1)
	await probe("Carnet : succès", 0.8)
	lobby._archive.close_ui()
	lobby._workshop.open(0)
	await probe("Atelier : Armurerie", 0.8)
	lobby._workshop.show_page(1)
	await probe("Atelier : Fabrication", 0.8)
	lobby._workshop.close_ui()
	lobby._show_menu("rush")
	await probe("lobby : Ruée des boss", 0.8)
	lobby._show_menu("siege")
	await probe("lobby : Le Siège", 0.8)
	lobby._show_menu("")
	lobby._open_hero("class")
	await probe("Héros : classe", 0.8)
	lobby._hero.close_ui()
	lobby._settings.open()
	for t in 6:
		lobby._settings._tabs.current_tab = t
		await probe("Paramètres : onglet %d" % t, 0.8)
	lobby._settings.close()
	var w := Welcome.new()
	lobby.add_child(w)
	await probe("accueil : 3 départs")
	w._step_class()
	await probe("accueil : classes")
	w._step_controls()
	await probe("accueil : contrôles")
	w.queue_free()
	var g := Guide.open_on(lobby, "commands")
	await probe("Guide")
	g.close()
	lobby.queue_free()
	await get_tree().process_frame
	# en run : choix de cartes, menu pause
	Run.start_survival("warrior", 1)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	await probe("run : choix de l'arme au départ", 0.9)
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.5).timeout
	world.pause_menu.open()
	await probe("pause : Run", 0.8)
	world.pause_menu._screen.show_page(1)
	await probe("pause : Héros", 0.7)
	world.pause_menu.close()
	var r := ResultsScreen.new()
	world.add_child(r)
	Run.result = "victoire"
	r.show_results()
	await probe("bilan de Survie", 0.9)
	var fp := FortunePopup.open(world, 10, 10, Callable())
	await probe("autel de la fortune", 0.7)
	fp.queue_free()
	world.queue_free()
	await get_tree().process_frame
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().create_timer(1.0).timeout
	await probe("écran titre")
	title._open_saves()
	await probe("écran titre : sauvegardes")
	Gamepad.active = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
