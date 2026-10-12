class_name ResultsScreen
extends CanvasLayer
## Bilan de fin de run (victoire, défaite, abandon) puis retour au lobby.

const TITLES := {"victoire": "VICTOIRE !", "defaite": "DÉFAITE", "abandon": "RUN ABANDONNÉE"}


func show_results() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud.style(Color(0.08, 0.07, 0.14, 0.97)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-320, -260)
	panel.custom_minimum_size = Vector2(640, 0)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Hud._label(v, TITLES.get(Run.result, "FIN"), 42,
		Hud.ACCENT if Run.result == "victoire" else Color(0.95, 0.4, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cls := Run.class_data()
	Hud._label(v, "%s · niveau atteint %d · %s" % [cls.get("name_fr", ""), Run.max_level, Run.duration_text()], 17, Color.WHITE)
	Hud._label(v, "Monstres vaincus : %d   ·   Élites : %d   ·   Or : +%d" % [Run.kills, Run.elites, Run.gold], 16, Color(0.85, 0.85, 0.9))
	Hud._label(v, "Butin (déjà dans ton inventaire) :", 16, Hud.ACCENT)
	if Run.loot.is_empty():
		Hud._label(v, "aucun objet", 14, Color(0.7, 0.7, 0.75))
	var grid := GridContainer.new()
	grid.columns = 2
	v.add_child(grid)
	for item in Run.loot:
		var l := Hud._label(grid, "• %s (%s, niv. %d)" % [item.name, Items.RARITIES[int(item.rarity)].name, int(item.level)], 14,
			Items.RARITIES[int(item.rarity)].color)
		l.custom_minimum_size = Vector2(300, 0)
	var b := Button.new()
	b.text = "Retour au lobby"
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", Hud.style(Color(0.2, 0.15, 0.3)))
	b.add_theme_stylebox_override("hover", Hud.style(Color(0.3, 0.22, 0.42)))
	b.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	v.add_child(b)
	add_child(root)
