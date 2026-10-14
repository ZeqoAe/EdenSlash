class_name DuelResults
extends CanvasLayer
## Bilan d'un duel : victoire ou défaite, score des manches, victoires contre cette classe.


## Lignes du résultat classé (Ligue : rang, maîtrise ; Panthéon : récompenses).
func _report_lines() -> Array:
	var r: Dictionary = Duel.last_report
	var out: Array = []
	if r.is_empty():
		return out
	if String(r.get("mode", "")) == "league":
		if bool(r.get("promoted", false)):
			out.append("PROMOTION : rang %s !" % League.rank_name(int(r.rank)))
		if int(r.get("mastery", 0)) > 0:
			out.append("Maîtrise gagnée : +%d" % int(r.mastery))
		out.append("Série : %d / %d" % [League.streak(), League.WINS_PER_RANK])
	else:
		for t in r.get("text", []):
			out.append(String(t))
	return out


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
	var times: PackedStringArray = []
	for tm in PvpCaps.round_times:
		times.append("%d s" % roundi(float(tm)))
	var m := Hud._label(v, "%s niveau %d · manches : %s" % ["À l'arme" if Duel.bare else "Équipé", Duel.level, ", ".join(times) if not times.is_empty() else "—"], 16, UiTheme.MUTED)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hit := Hud._label(v, "Plus gros coup porté : %d %% des PV de l'adversaire · reçu : %d %% de tes PV" % [roundi(PvpCaps.best_dealt * 100.0), roundi(PvpCaps.best_taken * 100.0)], 16, UiTheme.MUTED)
	hit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for ln in _report_lines():
		var rl := Hud._label(v, ln, 16, Color(0.55, 1.0, 0.6))
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var again := Button.new()
	again.text = "Rejouer (même adversaire)"
	again.custom_minimum_size = Vector2(0, 54)
	again.add_theme_font_size_override("font_size", 20)
	again.add_theme_stylebox_override("normal", Hud.style(Color(0.15, 0.3, 0.2)))
	again.add_theme_stylebox_override("hover", Hud.style(Color(0.22, 0.42, 0.3)))
	again.focus_mode = Control.FOCUS_NONE
	again.pressed.connect(func():
		get_tree().paused = false
		Duel.start(Profile.selected_class, Duel.rival_class, Duel.difficulty)
		get_tree().change_scene_to_file("res://scenes/world.tscn"))
	v.add_child(again)
	v.add_child(ok)
