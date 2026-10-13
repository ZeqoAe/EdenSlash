class_name DuelResults
extends CanvasLayer
## Bilan d'un duel : victoire ou défaite, score des manches, victoires contre cette classe.


func show_results(won: bool, score: String, opponent: String, diff: int, total: int) -> void:
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
	panel.position = Vector2(-380, -190)
	panel.custom_minimum_size = Vector2(760, 380)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var t := Hud._label(v, "VICTOIRE !" if won else "DÉFAITE", 46, Hud.ACCENT if won else Color(0.95, 0.45, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cd := GameData.class_data(opponent)
	var s := Hud._label(v, "Manches %s contre %s (%s)" % [score, cd.get("name_fr", opponent), ClassRival.NAMES[diff]], 22, Color.WHITE)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var w := Hud._label(v, "Victoires contre cette classe dans cette difficulté : %d" % total, 17, Color(0.6, 0.85, 1.0))
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var ok := Button.new()
	ok.text = "Retour au lobby"
	ok.custom_minimum_size = Vector2(0, 54)
	ok.add_theme_font_size_override("font_size", 20)
	ok.add_theme_stylebox_override("normal", Hud.style(Color(0.2, 0.15, 0.3)))
	ok.add_theme_stylebox_override("hover", Hud.style(Color(0.3, 0.22, 0.42)))
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(func(): Duel.leave(get_tree()))
	v.add_child(ok)
