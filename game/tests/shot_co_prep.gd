extends Node
## Capture de la page minimale de préparation du Colisée (lots CO-E / CO-F) : une partie Classique, manche 1 (offre d'atouts,
## enclumes), puis la même page après un choix d'atout et l'ouverture d'une enclume. Fenêtre (pas --headless) :
## godot --path game res://tests/shot_co_prep.tscn -- --out=C:/dossier [--res=1280x720]

var out := "user://"


func _ready() -> void:
	var res := Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--res="):
			var p := arg.trim_prefix("--res=").split("x")
			res = Vector2i(int(p[0]), int(p[1]))
	get_window().size = res
	Settings.reset_all(false)
	Profile.selected_class = "warrior"
	ColiseeDirector.fallback = false
	Colisee.begin("warrior", "classique", 2, 77)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	for i in 1200:
		await get_tree().process_frame
		if world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team) \
				and world.director.team.prep_page != null:
			break
	var dd = world.director.team
	for i in 40:
		await get_tree().process_frame
	_shot("co_prep_offre_%dx%d.png" % [res.x, res.y])
	var page: ColiseePrepPage = dd.prep_page
	page._take_augment(0)
	page.b.gold = 40  # (capture : de quoi ouvrir une enclume de pièce)
	page._open("piece", false)
	for i in 10:
		await get_tree().process_frame
	_shot("co_prep_enclume_%dx%d.png" % [res.x, res.y])
	page._choose(0)
	for i in 10:
		await get_tree().process_frame
	_shot("co_prep_piece_%dx%d.png" % [res.x, res.y])
	print("[shot_co_prep] fini")
	get_tree().quit()


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	var path := out.path_join(name)
	img.save_png(path)
	print("[shot_co_prep] ", path)
