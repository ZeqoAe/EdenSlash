extends Node
## Captures du Battle royale : page Jouer, page de l'activité, bilan (user://shots/royale_ui_*.png).
## godot --path game res://tests/shot_royale.tscn


func _shot(name: String) -> void:
	await get_tree().create_timer(0.8).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/royale_ui_%s.png" % name)


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.records["league_rank"] = 2
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._show_menu("play")
	await _shot("1_play")
	lobby._show_menu("royale")
	await _shot("2_page")
	lobby.queue_free()
	var r := RoyaleResults.new()
	add_child(r)
	r.show_results(3, 2, 7, 6, 171.0, {"text": ["+90 insignes (place 3, 2 éliminations)", "Coffre d'apparence rare"]})
	await _shot("3_bilan")
	get_tree().paused = false
	get_tree().quit()
