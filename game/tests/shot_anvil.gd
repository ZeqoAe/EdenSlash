extends Node
## Capture du choix de l'enclume de la Survie (9 emplacements depuis la cape, lot E4) et d'un coffre de cape :
## godot --path game res://tests/shot_anvil.tscn  → user://shots/anvil_*.png


func _shot(name: String) -> void:
	await get_tree().create_timer(0.8).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/anvil_%s.png" % name)


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Run.start_survival("warrior", 2)
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var picker := CardPicker.new()
	add_child(picker)
	var d := RunDirector.new()
	var all := d.anvil_slot_cards()
	picker.offer("Enclume : choisis un emplacement", all.slice(0, RunDirector.ANVIL_PAGE), func(): return all.slice(3, 6), 4)
	await _shot("1_emplacements")
	picker._choose(0)
	await get_tree().create_timer(0.6).timeout
	picker.offer("Coffre de cape (%s) : choisis une pièce" % Epochs.map_text(2, 1),
		SlotChests.offer("back", 2, 1).map(func(it): return RunDirector.item_card(it, "gear")))
	await _shot("2_coffre_cape")
	d.free()
	Run.finish("abandon")
	Profile.end_run_survival()
	Profile.reset_all()
	get_tree().quit()
