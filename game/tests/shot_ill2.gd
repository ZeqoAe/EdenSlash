extends Node
## Lot ILL-2 : captures des illustrations intégrées (écran titre, menu principal, cartes de Jouer, bandeaux, bilans de fin)
## dans user://shots/ill2/<étiquette>_<état>_<largeur>x<hauteur>_<nom>.png.
##   ILL2_STATE=neuf|avance ILL2_RES=1280x720 ILL2_TAG=avant|apres ILL2_ONLY=titre,lobby,jouer,bilans godot --path game res://tests/shot_ill2.tscn
## APPDATA détourné : rien n'est écrit chez le joueur. Lignes « [débord] » comme shot_p1.

var state := "avance"
var tag := "x"
var only: PackedStringArray = []


func _overflow(name: String) -> void:
	var size := get_viewport().get_visible_rect().size
	var stack: Array = [get_tree().root]
	var found := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is ScrollContainer or (n is CanvasItem and not (n as CanvasItem).visible):
			continue
		for c in n.get_children():
			stack.append(c)
		if n is Control and (n as Control).is_visible_in_tree():
			var r := (n as Control).get_global_rect()
			if r.size.x > 1.0 and r.size.y > 1.0 and (r.end.x > size.x + 1.0 or r.end.y > size.y + 1.0) and not (n is TextureRect):
				if found < 6:
					print("[débord] %s : %s %s fin (%d, %d) sur (%d, %d)" % [name, n.get_class(), n.name, r.end.x, r.end.y, size.x, size.y])
				found += 1


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait, true).timeout
	_overflow(name)
	DirAccess.make_dir_recursive_absolute("user://shots/ill2")
	var path := "user://shots/ill2/%s_%s_%dx%d_%s.png" % [tag, state, get_viewport().size.x, get_viewport().size.y, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("[capture] ", ProjectSettings.globalize_path(path))


func _want(k: String) -> bool:
	return only.is_empty() or k in only


func _advanced() -> void:
	Profile.unlocked_features = Unlocks.LIST.keys()
	Profile.runs_done = 14
	Profile.runs_won = 4
	Profile.best_level = 48
	Profile.insignia = 2400
	Profile.records["epochs_cleared"] = 2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(280.0, true, false, true).timeout.connect(func(): get_tree().quit(1))
	if OS.get_environment("ILL2_STATE") != "":
		state = OS.get_environment("ILL2_STATE")
	if OS.get_environment("ILL2_TAG") != "":
		tag = OS.get_environment("ILL2_TAG")
	if OS.get_environment("ILL2_ONLY") != "":
		only = OS.get_environment("ILL2_ONLY").split(",")
	Training.active = true  # (le lobby ne lance rien au premier argument)
	Settings.reset_all()
	Profile.reset_all()
	if OS.get_environment("ILL2_RES") != "":
		var wh := OS.get_environment("ILL2_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().create_timer(0.5, true).timeout
	if state == "avance":
		_advanced()
	if _want("titre"):
		var title: Node = load("res://scenes/title.tscn").instantiate()
		add_child(title)
		await _shot("00_titre", 3.0)
		title._open_saves()
		await _shot("01_titre_jouer")
		title._show_slots(true)
		await _shot("02_titre_slots")
		title.queue_free()
		await get_tree().process_frame
	if _want("lobby") or _want("jouer"):
		var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
		add_child(lobby)
		await get_tree().create_timer(2.0, true).timeout
		if _want("lobby"):
			await _shot("10_lobby")
		if _want("jouer"):
			lobby._show_menu("play")
			await _shot("11_jouer")
			for id in ["survival", "dungeon", "tower", "rush", "siege", "duel", "arenas", "royale", "autochess"]:
				lobby._show_menu(id)
				await _shot("12_page_" + id)
		lobby.queue_free()
		await get_tree().process_frame
	if _want("bilans"):
		await _results()
	get_tree().quit()


## Un bilan par fond : victoire, défaite, record, boss (butin), égalité (extraction), étoile d'époque.
func _results() -> void:
	var tiles := [["14", "niveau atteint"], ["212", "monstres"], ["9", "élites"], ["12:40", "durée"]]
	var gained := [ResultsPanel.row("Maîtrise Guerrier", "+1 250", "", "expertise"), ResultsPanel.row("Insignes", "+340", "", "upgrade")]
	var kept := [ResultsPanel.row("Pièces", "×4", "", "chest"), ResultsPanel.row("Cristaux", "+12", "", "crystal")]
	var lost := [ResultsPanel.row("Or de la run", "480", "", "gold")]
	var cases := {
		"victoire": {"title": "VICTOIRE !", "tone": "win"},
		"defaite": {"title": "DÉFAITE", "tone": "lose"},
		"record": {"title": "VICTOIRE !", "tone": "win", "gained": [ResultsPanel.row("Nouveau record", "étage 42", "", "stats")] + gained},
		"boss": {"title": "BOSS VAINCU !", "tone": "win", "loot": []},
		"egalite": {"title": "EXTRACTION", "tone": "info"},
		"etoiles": {"title": "VICTOIRE !", "tone": "win", "gained": [ResultsPanel.row("Étoile d'époque", "+1", "", "new")] + gained},
	}
	for k in cases:
		var spec: Dictionary = {"subtitle": "Guerrier · Époque II", "tiles": tiles, "gained": gained, "kept": kept, "lost": lost,
			"buttons": [{"text": "Rejouer", "primary": true}, {"text": "Retour au lobby"}]}
		spec.merge(cases[k], true)
		if k == "boss":
			spec["loot"] = [ResultsPanel.loot_entry(Items.generate(40, 1.0, "chest", "warrior", 2, "", 3))]
		var p := ResultsPanel.new()
		add_child(p)
		p.show_spec(spec)
		await get_tree().create_timer(2.6, true).timeout
		await _shot("20_bilan_" + k, 0.1)
		p.queue_free()
		get_tree().paused = false
		await get_tree().process_frame
