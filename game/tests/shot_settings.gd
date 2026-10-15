extends Node
## Captures des Paramètres avec la manette (cadre doré, barre d'aide, infobulle fixe) : user://shots/set_*.png
## godot --path game res://tests/shot_settings.tscn


func _shot(name: String) -> void:
	await get_tree().create_timer(0.4).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/set_%s.png" % name)


## Contrôle navigable dont le texte ou la classe correspond.
func _find(pred: Callable) -> Control:
	for c in UiNav.candidates():
		if pred.call(c):
			return c
	return null


## Ligne de Paramètres (PanelContainer « row_panel ») dont le titre est [param text].
func _find_row(text: String) -> Control:
	for n in get_tree().root.find_children("*", "PanelContainer", true, false):
		if n.has_meta("row_panel") and n.is_visible_in_tree():
			for l in n.find_children("*", "Label", true, false):
				if (l as Label).text == text:
					return n
	return null


func _ready() -> void:
	Settings.reset_all()
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var menu := SettingsMenu.new()
	add_child(menu)
	menu.open(1)
	await get_tree().create_timer(0.6).timeout
	await _shot("1_souris")  # sans manette : ni barre d'aide ni cadre
	Gamepad.active = true
	await get_tree().process_frame
	await _shot("2_manette_sans_cadre")  # barre d'aide seule
	var sw := _find(func(c): return c is UiTheme.Switch)
	UiNav.cursor = sw
	UiNav.reveal()
	await _shot("3_combat_cadre")
	menu.show_page(2)
	await get_tree().process_frame
	await get_tree().process_frame
	var key := _find(func(c): return c is Button and c.has_meta("nav_left"))
	UiNav.cursor = key
	UiNav.reveal()
	await _shot("4_touches_cadre")
	var chip: Button = key.get_meta("nav_left")
	for c in UiNav.candidates():
		if c is Button and c.text == "Manette":
			c.pressed.emit()  # saute à la section Manette
	await get_tree().create_timer(0.3).timeout
	UiNav.cursor = _find(func(c): return c is Button and c.has_meta("nav_left") and c.is_visible_in_tree() and c.global_position.y > 150)
	await _shot("4b_touches_manette")
	chip = null
	menu.show_page(4)
	await get_tree().process_frame
	await _shot("4c_son")
	menu.show_page(5)
	await get_tree().process_frame
	await get_tree().process_frame
	UiNav.cursor = _find(func(c): return c is HSlider)
	UiNav.reveal()
	await _shot("5_camera_curseur")
	Settings.set_v("interface", "pad_labels", "ps")
	menu.show_page(0)
	await get_tree().process_frame
	await get_tree().process_frame
	UiNav.cursor = _find(func(c): return c is Button and c.text == "Détente")
	UiNav.reveal()
	await _shot("6_mode_ps")
	# souris : survol d'une ligne (fond clair, détail dans le pied)
	Gamepad.active = false
	menu.show_page(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var row := _find_row("Mémoire des touches")
	get_viewport().warp_mouse(row.get_global_rect().get_center() - Vector2(300, 0))
	await _shot("7_survol_souris")
	Settings.reset_all()
	get_tree().quit()
