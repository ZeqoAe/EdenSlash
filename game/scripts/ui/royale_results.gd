class_name RoyaleResults
extends CanvasLayer
## Bilan d'une partie de Battle royale : place finale, éliminations, niveau, coffres, temps, récompenses.


func show_results(place: int, kills: int, level: int, chests: int, secs: float, got: Dictionary) -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud.style(Color(0.08, 0.07, 0.14, 0.97)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-380, -230)
	panel.custom_minimum_size = Vector2(760, 460)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var won := place == 1
	var t := Hud._label(v, "VICTOIRE !" if won else ("TOP %d" % place if place <= 3 else "ÉLIMINÉ"), 46, Hud.ACCENT if place <= 3 else Color(0.95, 0.45, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := Hud._label(v, "Dernier debout sur %d héros" % Royale.PLAYERS if won else "Place %d sur %d" % [place, Royale.PLAYERS], 24, Color.WHITE)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var st := Hud._label(v, "%d élimination%s · niveau %d · %d coffre%s · %d min %02d s" % [kills, "s" if kills > 1 else "", level,
		chests, "s" if chests > 1 else "", int(secs) / 60, int(secs) % 60], 17, UiTheme.MUTED)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var best := int(Profile.records.get("royale_best", 0))
	if best > 0:
		var b := Hud._label(v, "Meilleure place : %d · victoires : %d" % [best, int(Profile.records.get("royale_wins", 0))], 16, Color(0.6, 0.85, 1.0))
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for ln in got.get("text", []):
		var rl := Hud._label(v, String(ln), 17, Color(0.55, 1.0, 0.6))
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var kept := Hud._label(v, "Seules les récompenses ci-dessus sont gardées (équipement, niveaux et potions de la partie restent dans la partie).", 13, UiTheme.MUTED)
	kept.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kept.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var again := Button.new()
	again.text = "Rejouer"
	again.custom_minimum_size = Vector2(0, 54)
	again.add_theme_font_size_override("font_size", 20)
	again.add_theme_stylebox_override("normal", Hud.style(Color(0.15, 0.3, 0.2)))
	again.add_theme_stylebox_override("hover", Hud.style(Color(0.22, 0.42, 0.3)))
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func():
		get_tree().paused = false
		Royale.start(Profile.selected_class)
		get_tree().change_scene_to_file("res://scenes/world.tscn"))
	v.add_child(again)
	var ok := Button.new()
	ok.text = "Retour au lobby"
	ok.custom_minimum_size = Vector2(0, 54)
	ok.add_theme_font_size_override("font_size", 20)
	ok.add_theme_stylebox_override("normal", Hud.style(Color(0.2, 0.15, 0.3)))
	ok.add_theme_stylebox_override("hover", Hud.style(Color(0.3, 0.22, 0.42)))
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(func(): Royale.leave(get_tree()))
	v.add_child(ok)
