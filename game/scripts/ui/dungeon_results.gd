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
	var siege := bool(got.get("siege", false))
	var title_text: String = TITLES[victory]
	if siege:
		title_text = siege_title(got)
	var t := Hud._label(v, title_text, 42, Hud.ACCENT if victory else Color(0.95, 0.45, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var zid := String(got.get("zone", ""))
	var info_text := "%s · %s · salles franchies : %d / %d" % [Dungeons.name_of(zid), Dungeons.DIFF_NAMES[int(got.get("diff", 0))], int(got.get("rooms", 0)), Dungeons.rush_floors() if bool(got.get("rush", false)) else Dungeons.ROOMS.size()]
	if siege:
		info_text = "Le Siège · %s · %s · vagues vaincues : %d / %d%s" % [Dungeons.name_of(zid), Dungeons.DIFF_NAMES[int(got.get("diff", 0))], mini(int(got.get("rooms", 0)), Siege.WAVES), Siege.WAVES, " · boss vaincu" if victory else ""]
	var info := Hud._label(v, info_text, 22, Color.WHITE)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ex := Hud._label(v, "Maîtrise %s : +%d" % [Run.class_data().get("name_fr", ""), int(got.get("xp", 0))], 17, Color(0.6, 0.85, 1.0))
	ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if siege and String(got.get("outcome", "")) != "":
		var oc := Hud._label(v, siege_outcome_text(got), 20, Color(1.0, 0.8, 0.45))
		oc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		oc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if victory or bool(got.get("rush", false)) or siege:
		var r: Dictionary = got.get("reward", {})
		var lines: PackedStringArray = []
		if not (r.get("chests", []) as Array).is_empty():
			lines.append(ActivityLoot.chests_text(r.chests))  # « Coffre de set, Coffre de forge ×2… »
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
	again.text = "Rejouer (la Ruée)" if bool(got.get("rush", false)) else ("Rejouer (même siège)" if siege else "Rejouer (même donjon)")
	again.custom_minimum_size = Vector2(0, 54)
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func():
		get_tree().paused = false
		if siege:
			Tower.start_siege(Profile.selected_class, zid, int(got.get("diff", 0)), Dungeons.last_allies)
		else:
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


## Titre du bilan d'un siège selon l'issue du chacun pour soi.
static func siege_title(got: Dictionary) -> String:
	match String(got.get("outcome", "")):
		"won":
			return "DERNIER DEBOUT !"
		"escaped":
			return "TU QUITTES LE DUEL"
		"eliminated":
			return "ÉLIMINÉ (%de)" % maxi(2, int(got.get("rank", 3)))
	return "SIÈGE TERMINÉ" if bool(got.get("victory", false)) else "SIÈGE PERDU"


static func siege_outcome_text(got: Dictionary) -> String:
	match String(got.get("outcome", "")):
		"won":
			return "Tu as battu tes deux compagnons : coffre d'apparence légendaire."
		"escaped":
			return "Tu as emporté le cœur hors de l'anneau : récompense moindre, mais saine et sauve."
		"eliminated":
			return "Le boss est tombé, mais tu n'as pas survécu au chacun pour soi."
	return ""
