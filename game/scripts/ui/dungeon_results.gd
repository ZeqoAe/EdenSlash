class_name DungeonResults
extends CanvasLayer
## Bilan d'un donjon : salles franchies, butin (coffre de set, cristaux, plan), maîtrise gagnée.

const TITLES := {true: "DONJON TERMINÉ !", false: "ÉCHEC DANS LE DONJON"}


func show_results(got: Dictionary) -> void:
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
	panel.position = Vector2(-400, -230)
	panel.custom_minimum_size = Vector2(800, 460)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var victory := bool(got.get("victory", false))
	var t := Hud._label(v, TITLES[victory], 42, Hud.ACCENT if victory else Color(0.95, 0.45, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var zid := String(got.get("zone", ""))
	var info := Hud._label(v, "%s · %s · salles franchies : %d / %d" % [Dungeons.name_of(zid), Dungeons.DIFF_NAMES[int(got.get("diff", 0))], int(got.get("rooms", 0)), Dungeons.rush_floors() if bool(got.get("rush", false)) else Dungeons.ROOMS.size()], 22, Color.WHITE)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ex := Hud._label(v, "Maîtrise %s : +%d" % [Run.class_data().get("name_fr", ""), int(got.get("xp", 0))], 17, Color(0.6, 0.85, 1.0))
	ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if victory or bool(got.get("rush", false)):
		var r: Dictionary = got.get("reward", {})
		var lines: PackedStringArray = []
		for c in r.get("chests", []):
			lines.append(String(Rewards.TYPES[c.type].name))
		lines.append("%d cristaux" % int(r.get("crystals", 0)))
		if String(r.get("plan", "")) != "":
			lines.append("un plan de fabrication !")
		if String(r.get("title", "")) != "":
			lines.append("le titre « %s »" % String(r.title))
		var l := Hud._label(v, "Butin : " + ", ".join(lines) + "  (menu Coffres)", 20, Color(0.55, 1.0, 0.6))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var again := Button.new()
	again.text = "Rejouer (la Ruée)" if bool(got.get("rush", false)) else "Rejouer (même donjon)"
	again.custom_minimum_size = Vector2(0, 54)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func():
		get_tree().paused = false
		Tower.start_dungeon(Profile.selected_class, zid, int(got.get("diff", 0)), Dungeons.last_allies)
		get_tree().change_scene_to_file("res://scenes/world.tscn"))
	row.add_child(again)
	var ok := Button.new()
	ok.text = "Retour au lobby"
	ok.custom_minimum_size = Vector2(0, 54)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/lobby.tscn"))
	row.add_child(ok)
