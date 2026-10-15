extends Node
## Passe M3 : captures de la Tour (user://shots/m3_*.png) : page des étages (icônes de type, légende), fiches d'un étage
## de monstres, d'ombre, maudit et de boss, puis un étage de chaque type en jeu (HUD : horloge « Étage n · type », objectif).
## godot --path game res://tests/shot_m3.tscn   (APPDATA détourné : rien n'est sauvegardé chez le joueur)


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/m3_%s.png" % name)
	print("[m3] capture %s" % name)


func _first(t: String, kind := "") -> int:
	for f in range(1, Tower.FLOORS + 1):
		if Tower.floor_type(f) == t and (kind == "" or Tower.shadow_kind(f) == kind):
			return f
	return 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.records["epochs_cleared"] = 1
	Profile.records[Tower.record_key(1)] = 23
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.5).timeout
	lobby._show_menu("tower")
	await _shot("difficulte")
	lobby._tower_diff = 1
	lobby._tower_sel = 24
	lobby._tower_page = 4
	lobby._show_menu("tower_floors")
	await _shot("etages")
	lobby._tower_page = 5
	lobby._tower_sel = 26
	lobby._show_menu("tower_floors")
	await _shot("etages_2")
	for f in [2, _first("shadow"), _first("cursed"), 10]:
		var sheet: CanvasLayer = TowerPages.info_popup(lobby._sub, Tower.spec(f, 1))
		await _shot("fiche_%d" % f, 0.9)
		sheet.queue_free()
	lobby.queue_free()
	Training.active = false
	# en jeu : un étage de chaque type
	Tower.start("warrior", 1, 1)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var td: TowerDirector = world.director.tower
	var p: Player = world.player
	p.dev_invincible = true
	world.cards._queue.clear()
	world.cards._show_next()
	await _shot("duelliste", 2.0)
	for f in [2, 5, _first("cursed"), _first("shadow"), _first("shadow", "self"), 10]:
		td.begin(f)
		await _shot("etage_%d_%s" % [f, Tower.floor_type(f)], 7.5)
	td.begin(9)
	await _shot("halte", 1.5)
	world.cards._queue.clear()
	world.cards._show_next()
	Tower.difficulty = 3
	var bf := 0
	for f in range(100, Tower.FLOORS + 1):
		if Tower.shadow_kind(f, 3) == "brain":
			bf = f
			break
	td.begin(bf)
	await _shot("ombre_eveillee", 4.0)
	get_tree().quit()
