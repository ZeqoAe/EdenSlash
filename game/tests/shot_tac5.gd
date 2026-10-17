extends Node
## Captures de l'écran d'achat de L'Assaut (lot TAC-5), en 1280 × 720 puis 1600 × 900 : onglet Sorts à l'ouverture, Arme
## après l'achat conseillé, Utilitaires, Fioles et outils. Fichiers user://shots/tac5_<largeur>_*.png.
## APPDATA détourné : godot --path game res://tests/shot_tac5.tscn

var world: Node
var dd: AssaultDirector


func _shot(name: String) -> void:
	await get_tree().create_timer(0.7).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	var w := get_window().size.x
	get_viewport().get_texture().get_image().save_png("user://shots/tac5_%d_%s.png" % [w, name])
	print("[shot] tac5_%d_%s" % [w, name])


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	Assault.launch("warrior", {"map": "bourg", "seed": 12, "first_attack": 0, "buy_time": 900.0, "buy_time_first": 900.0})
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	for _i in 3600:
		await get_tree().process_frame
		if world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team) \
				and world.director.map != null and world.director.map._region.navigation_mesh != null:
			break
	dd = world.director.team
	for _i in 120:
		await get_tree().process_frame
		if is_instance_valid(dd.shop):
			break
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().size = res
		await get_tree().process_frame
		await get_tree().process_frame
		AssaultItems.sell_all("t0_0")
		dd._close_shop()
		await get_tree().process_frame
		dd._open_shop()
		await _shot("1_sorts")
		Assault.give("t0_0", 2600)
		dd.shop._advise()
		dd.shop.set_tab(1)
		await _shot("2_arme_conseille")
		dd.shop.set_tab(3)
		await _shot("3_utilitaires")
		dd.shop.set_tab(4)
		await _shot("4_fioles")
		Assault.spend("t0_0", 2600)
	TeamMatch.abandon()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
