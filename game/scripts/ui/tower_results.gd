class_name TowerResults
extends CanvasLayer
## Bilan de fin d'ascension de la Tour : étage atteint, record, expertise gagnée, cartes et
## équipement de la dernière tentative, puis retour au lobby.

const TITLES := {"victoire": "SOMMET DE LA TOUR !", "defaite": "CHUTE DANS LA TOUR", "abandon": "ASCENSION ARRÊTÉE"}


## [param got] : Tower.finish() {best, new_record, xp, levels}.
func show_results(result: String, floor_reached: int, got: Dictionary) -> void:
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
	panel.position = Vector2(-430, -250)
	panel.custom_minimum_size = Vector2(860, 500)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := Hud._label(v, TITLES.get(result, "FIN DE L'ASCENSION"), 42, Hud.ACCENT if result == "victoire" else Color(0.95, 0.45, 0.4))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var f := Hud._label(v, "Étage atteint : %d / %d  ·  %s  ·  duels gagnés : %d / %d" % [floor_reached, Tower.FLOORS,
		Tower.DIFF_NAMES[Tower.difficulty], Tower.duel_index(floor_reached), Tower.duel_count()], 26, Color.WHITE)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rec := Hud._label(v, "NOUVEAU RECORD (%s) !" % Tower.DIFF_NAMES[Tower.difficulty] if got.get("new_record", false) else "Record %s : étage %d" % [Tower.DIFF_NAMES[Tower.difficulty], int(got.get("best", 0))], 22,
		Color(0.55, 1.0, 0.6) if got.get("new_record", false) else Color(0.75, 0.75, 0.85))
	rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cls := Run.class_data()
	var s := Hud._label(v, "%s · niveau %d · %s · monstres vaincus : %d · élites : %d" % [cls.get("name_fr", ""), Run.max_level, Run.duration_text(), Run.kills, Run.elites], 16, Color(0.9, 0.9, 0.95))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ex := Hud._label(v, "Expertise %s : +%d%s" % [cls.get("name_fr", ""), int(got.get("xp", 0)),
		("   ·   NIVEAU %d !" % Profile.expertise_level(Run.class_id)) if int(got.get("levels", 0)) > 0 else ""], 17, Color(0.6, 0.85, 1.0))
	ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var build: PackedStringArray = []
	for e in Run.all_skills():
		build.append("%s r%d" % [Run.skill_def(int(e.id)).get("name", "?"), int(e.rank)])
	for id in Run.passives:
		build.append("%s ×%d" % [Run.passive_def(String(id)).get("name", id), int(Run.passives[id])])
	if not build.is_empty():
		var b := Hud._label(v, "Build : " + "  ·  ".join(build), 15, Color(0.8, 0.8, 0.9))
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := Hud._label(v, "L'équipement trouvé dans la Tour ne sert que pour l'ascension : ton héros garde le sien.", 14, Color(0.65, 0.65, 0.75))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	ok.pressed.connect(func(): Tower.leave(get_tree()))
	v.add_child(ok)
	print("[tour] fin : %s, étage %d, record %d" % [result, floor_reached, int(got.get("best", 0))])
