extends Node
## Captures du Carnet : chaque onglet, compte neuf puis compte avancé (user://shots/carnet_*.png).
## godot --path game res://tests/shot_carnet.tscn   (APPDATA détourné : le test ne sauvegarde rien)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/carnet_%s.png" % name)


func _tabs(lobby: Node, prefix: String) -> void:
	for i in lobby._archive.page_count():
		lobby._archive.open(i)
		await _shot("%s_%d" % [prefix, i])


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	await _tabs(lobby, "neuf")
	# compte avancé : records, trophées, titre, quelques entrées d'archive
	Profile.runs_done = 12
	Profile.runs_won = 3
	Profile.records["kills"] = 1500
	Profile.records["elite_kills"] = 40
	Profile.records["epochs_cleared"] = 2
	Profile.title = "Habitué"
	for k in ["storm", "frost", "vampire"]:
		if Trophies.KINDS.has(k):
			Profile.note_trophy(k)
	for e in Archive.entries("w:katana").slice(0, 6):
		Profile.archive[Archive.key_of(e)] = ArchivePages.demo_item(e)
	await _tabs(lobby, "avance")
	lobby._archive.open(4)
	lobby._archive.page(4)._selected_entry = Archive.entries("w:katana")[8]
	lobby._archive.page(4)._refresh_action()
	await _shot("avance_4_choix")
	get_tree().quit()
