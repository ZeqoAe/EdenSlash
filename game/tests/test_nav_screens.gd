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
	var subs := {}
	for i in lobby._archive.page_count():
		lobby._archive.show_page(i)
		subs[lobby._archive._subtitle.text] = true
		if i >= 2:
			await probe("Carnet : onglet %d" % i, 0.8)
	check("Carnet : un sous-titre différent par onglet", subs.size() == lobby._archive.page_count() and not subs.has(""))
	lobby._archive.show_page(2)
	CarnetPages.open_hero(lobby._archive.page(2), "cards")
	check("Carnet > Cartes : le lien ouvre Héros > Cartes", lobby._hero.is_open() and not lobby._archive.is_open())
	lobby._hero.close_ui()
	lobby._archive.open(0)
	lobby._archive.close_ui()
	lobby._workshop.open(0)
	await probe("Atelier : Armurerie", 0.8)
	lobby._workshop.show_page(1)
	await probe("Atelier : Fabrication", 0.8)
	lobby._workshop.close_ui()
	lobby._show_menu("rush")
	await probe("lobby : Ruée des boss", 0.8)
	lobby._show_menu("royale")
	await probe("lobby : Battle royale", 0.8)
	lobby._show_menu("siege")
	await probe("lobby : Le Siège", 0.8)
	lobby._show_menu("")
	lobby._open_hero("class")
	await probe("Héros : classe", 0.8)
	lobby._hero.close_ui()
	lobby._settings.open()
	for t in lobby._settings._pages.size():
		lobby._settings.show_page(t)
		await probe("Paramètres : page %d (%s)" % [t, lobby._settings._tab_buttons[t].text], 0.95)
	# Touches : un saut de groupe à la croix gauche (de la touche au bouton de son groupe) et retour
	lobby._settings.show_page(2)
	await get_tree().process_frame
	await get_tree().process_frame
	var first_key: Button = null
	for c in UiNav.candidates():
		if c is Button and c.has_meta("nav_left"):
			first_key = c
			break
	check("Paramètres > Touches : un bouton de touche mène à son groupe", first_key != null)
	if first_key != null:
		UiNav.cursor = first_key
		check("croix gauche : saute au groupe", UiNav.move(Vector2.LEFT) and UiNav.cursor == first_key.get_meta("nav_left"))
		check("croix droite : revient à la première touche du groupe", UiNav.move(Vector2.RIGHT) and UiNav.cursor.has_meta("nav_left"))
	# interrupteurs à glissière : valider bascule le réglage et la sauvegarde le garde
	lobby._settings.show_page(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var sw: UiTheme.Switch = null
	for c in UiNav.candidates():
		if c is UiTheme.Switch:
			sw = c
			break
	check("Paramètres > Combat : des interrupteurs navigables", sw != null)
	if sw != null:
		var before := sw.button_pressed
		UiNav.cursor = sw
		UiNav.shown = true
		UiNav.activate()
		await get_tree().process_frame
		await get_tree().process_frame
		check("A sur un interrupteur : il bascule", sw.button_pressed != before)
	lobby._settings.close()
	# barre d'aide et cadre doré
	UiNav.shown = false
	await get_tree().process_frame
	check("cadre doré caché tant qu'aucune croix n'a bougé", not UiNav._frame.visible)
	UiNav.reveal()
	await get_tree().process_frame
	check("reveal() montre le cadre", UiNav.shown and UiNav._frame.visible)
	var labels: Array = UiNav.hint_items().map(func(it): return it[1])
	check("barre d'aide : Valider · Retour (+ Onglets si l'écran en a)", labels.slice(0, 2) == ["Valider", "Retour"] and labels.size() <= 3)
	Gamepad.active = false
	await get_tree().process_frame
	check("souris : barre d'aide et cadre cachés", not UiNav._bar.visible and not UiNav._frame.visible and not UiNav.shown)
	Gamepad.active = true
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
