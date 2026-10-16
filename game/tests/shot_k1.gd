extends Node
## Captures K1 : Paramètres > Caméra & interface > Curseur et visée, avec plusieurs jeux de curseurs.
## APPDATA=<dossier> godot --path game --resolution 1280x720 res://tests/shot_k1.tscn  -> user://shots/k1_*.png


func _shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/k1_%s.png" % name)


func _ready() -> void:
	Settings.reset_all()
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var menu := SettingsMenu.new()
	add_child(menu)
	menu.open(5)
	await get_tree().create_timer(0.6).timeout
	for n in menu.find_children("*", "PanelContainer", true, false):
		if n.has_meta("row_panel") and n.is_visible_in_tree():
			for l in n.find_children("*", "Label", true, false):
				if (l as Label).text == "Aperçu":
					var sc := n
					while sc != null and not sc is ScrollContainer:
						sc = sc.get_parent()
					if sc:
						(sc as ScrollContainer).scroll_vertical = 100000
	await _shot("1_classique")
	Settings.set_v("interface", "cursor_set", "gauntlet")
	Settings.set_v("interface", "reticle", "cross")
	Settings.set_v("interface", "reticle_color", "cyan")
	await _shot("2_gantelet_croix")
	Settings.set_v("interface", "cursor_set", "shadow")
	Settings.set_v("interface", "reticle", "circle")
	Settings.set_v("interface", "reticle_size", 1.6)
	Settings.set_v("interface", "reticle_color", "red")
	await _shot("3_ombre_cercle")
	Settings.reset_all()
	get_tree().quit()
