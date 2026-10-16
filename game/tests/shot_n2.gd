extends Node
## Captures de la passe N2 (case de l'arme rangée au HUD, arme trouvée annoncée, arme secondaire en main) :
## godot --path game res://tests/shot_n2.tscn   (images dans user://shots/n2_*.png ; N2_RES=1280x720 possible)

var world: Node


func _ready() -> void:
	Settings.reset_all()
	if OS.get_environment("N2_RES") != "":
		Settings.set_v("display", "resolution", OS.get_environment("N2_RES"))
	Profile.selected_class = "warrior"
	Profile.reset_all()
	var bow := Items.generate(20, 0.0, "weapon", "warrior", Items.MYTHIC, "bow", Items.MYTHIC)
	Profile.inventory.append(bow)
	Profile.equip_offhand(bow)
	Profile.save_profile()
	Run.start_survival("warrior", 1)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(7.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	await get_tree().create_timer(1.0).timeout
	await _shot("n2_1_case_arme")
	Run.apply_card({"type": "offhand", "item": SlotChests.offhand_offer(1, 1)[0]})
	await get_tree().create_timer(0.6).timeout
	await _shot("n2_2_arme_au_sac")
	world.player.swap_weapon()
	await get_tree().create_timer(0.4).timeout
	await _shot("n2_3_arc_en_main")
	get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shots/%s.png" % name)
	print("capture ", ProjectSettings.globalize_path("user://shots/%s.png" % name))
