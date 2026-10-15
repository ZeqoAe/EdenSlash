extends Node
## Passe P5 : captures des pages Donjon, Siège et Ruée avec la jauge de PE (user://shots/p5/<nom>.png).
## APPDATA=<dossier jetable> godot --path game res://tests/shot_p5.tscn  (rien n'est sauvegardé chez le joueur)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.55).timeout
	DirAccess.make_dir_recursive_absolute("user://shots/p5")
	get_viewport().get_texture().get_image().save_png("user://shots/p5/%s.png" % name)


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit(1))  # garde-fou
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.unlocked_features = Unlocks.LIST.keys()
	Profile.records["epochs_cleared"] = 3
	Profile.runs_done = 40
	seed(7)
	Profile.equipped = StarterGear.scenario("3.3.10.4", "warrior")  # PE ≈ 33 000 : Héroïque de la 1re zone, pas le Mythique
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	for d in 3:
		lobby._dg_diff = d
		lobby._show_menu("dungeon")
		await _shot("donjon_%d" % d)
	lobby._dg_diff = 1
	lobby._show_menu("siege")
	await _shot("siege_1")
	lobby._dg_diff = 2
	lobby._show_menu("rush")
	await _shot("ruee_2")
	get_tree().quit()
