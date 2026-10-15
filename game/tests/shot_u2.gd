extends Node
## Captures du lot U2 (écran titre, accueil, Guide) : user://shots/u2_<étiquette>_*.png.
## SHOT_TAG=<étiquette> godot --path game res://tests/shot_u2.tscn --resolution 1600x900
## (APPDATA détourné : le test réinitialise le profil.)

var tag := "x"


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/u2_%s_%s.png" % [tag, name])


func _ready() -> void:
	tag = OS.get_environment("SHOT_TAG") if OS.get_environment("SHOT_TAG") != "" else "x"
	Settings.reset_all()
	Profile.reset_all()
	var wh := tag.split("x")
	if wh.size() == 2:
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().create_timer(1.0).timeout
	# écran titre
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await _shot("title", 3.0)
	title._open_saves()
	await _shot("title_jouer")
	title._show_slots(true)
	await _shot("title_slots")
	title.queue_free()
	await get_tree().process_frame
	# accueil
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	var w := Welcome.new()
	lobby.add_child(w)
	await _shot("welcome_1")
	w._step_class()
	await _shot("welcome_2")
	w._step_controls()
	await _shot("welcome_3")
	w.queue_free()
	# Guide (mode guidé : Premiers pas visibles)
	Tutorial.set_mode("guided")
	var g := Guide.open_on(lobby, "commands")
	for i in Guide.CHAPTERS.size():
		g.show_page(i)
		await _shot("guide_%d_%s" % [i, Guide.CHAPTERS[i][0]])
	g.select("anvil")
	await _shot("guide_fiche_enclume", 1.2)
	g.close()
	get_tree().quit()
