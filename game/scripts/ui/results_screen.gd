class_name ResultsScreen
extends CanvasLayer
## Bilan de fin d'une run de Survie (victoire, défaite, abandon, extraction), puis retour au
## lobby. La Tour, le Duel et l'entraînement ont leur propre bilan.

const TITLES := {"victoire": "VICTOIRE !", "defaite": "DÉFAITE", "abandon": "RUN ABANDONNÉE", "extraction": "EXTRACTION RÉUSSIE"}
const MUTED := Color(0.72, 0.72, 0.8)

var _confirm: Button


func show_results() -> void:
	Tutorial.event("results")
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud.style(Color(0.08, 0.07, 0.14, 0.97)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-560, -360)
	panel.custom_minimum_size = Vector2(1120, 720)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Hud._label(v, TITLES.get(Run.result, "FIN"), 42,
		Hud.ACCENT if Run.result == "victoire" else (Color(0.5, 0.9, 1.0) if Run.result == "extraction" else Color(0.95, 0.4, 0.4)))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cls := Run.class_data()
	# résultats en tuiles : grand chiffre et légende
	var tiles := HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 10)
	v.add_child(tiles)
	var data := [[String(cls.get("name_fr", "")), "classe"], [str(Run.max_level), "niveau atteint"], [Run.duration_text(), "durée"],
		[str(Run.kills), "monstres"], [str(Run.elites), "élites"], [str(Run.gold), "or gagné"]]
	data.append(["%d / %d" % [Run.stage, RunDirector.STAGES], "%s · map" % Epochs.get_def(Run.epoch).name])
	for d in data:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.08, 0.06, 0.14, 0.95), UiTheme.GOLD_DIM, 1, 8))
		p.custom_minimum_size = Vector2(118, 0)
		tiles.add_child(p)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		p.add_child(tv)
		var big := Hud._label(tv, String(d[0]), 21, UiTheme.GOLD)
		big.add_theme_font_override("font", UiTheme.bold_font())
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var cap := Hud._label(tv, String(d[1]), 12, UiTheme.MUTED)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.clip_text = true
	if Run.unlocked_epoch != "":
		var u := Hud._label(v, "%s débloquée !" % Run.unlocked_epoch, 22, Color(0.55, 1.0, 0.6))
		u.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ex := Hud._label(v, "Expertise %s : +%d%s" % [cls.get("name_fr", ""), Run.expertise_gain,
		("   ·   NIVEAU %d ! (+%d points de talent)" % [Profile.expertise_level(Run.class_id), 2 * Run.expertise_levels]) if Run.expertise_levels > 0 else ""],
		17, Color(0.6, 0.85, 1.0))
	ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if Run.challenge_first:
		var ch := Hud._label(v, "Défi de maîtrise réussi : +%d points de maîtrise (première réussite du jour)" % Challenge.BONUS_FIRST, 16, Color(1.0, 0.85, 0.35))
		ch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for c in Run.contracts_done:
		var cl := Hud._label(v, "Contrat terminé : %s (+%d maîtrise)" % [c.text, int(c.reward)], 16, Color(0.55, 1.0, 0.6))
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var assist := Settings.assist_level()
	var al := Hud._label(v, "Aide au combat : %s" % String(Settings.ASSIST[assist].name if Settings.ASSIST.has(assist) else "Personnalisée"), 14, UiTheme.MUTED)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# récompenses de maîtrise gagnées (sorts, certificats) et classes débloquées
	var gained: PackedStringArray = []
	var lvl := Profile.expertise_level(Run.class_id)
	for l in range(lvl - Run.expertise_levels + 1, lvl + 1):
		for r in Progression.rewards_at(Run.class_id, l):
			if r.kind != "talent":
				gained.append(String(r.name) if r.kind == "cert" else "Sort : " + String(r.name))
	for c in Run.new_classes:
		gained.append("Nouvelle classe : " + String(GameData.class_data(c).get("name_fr", c)))
	if Run.combo_best > 0.0:
		gained.append("Dégâts cumulés : %s%s" % [Hud._big_number(Run.combo_best), " (nouveau record !)" if Run.combo_best >= float(Profile.records.get("best_combo", 0.0)) else ""])
	for id in Run.new_cards():
		gained.append("Carte : " + String(Boons.get_def(id).get("name", id)))
	for c in Run.new_costumes:
		gained.append("Trésor : " + String(c))
	if not gained.is_empty():
		var g := Hud._label(v, "Débloqué : " + "  ·  ".join(gained), 18, Color(0.55, 1.0, 0.6))
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Survie : l'équipement de la run reste dans la run ; ses pièces s'achètent au hub
	var kept := Run.result in ["victoire", "extraction"]
	# gardé (vert) et perdu (rouge) : ce que cette run rapporte vraiment
	var keep_row := HBoxContainer.new()
	keep_row.alignment = BoxContainer.ALIGNMENT_CENTER
	keep_row.add_theme_constant_override("separation", 26)
	v.add_child(keep_row)
	var green := Color(0.55, 1.0, 0.6)
	var red := Color(1.0, 0.5, 0.45)
	var supplies := 0
	for k in Profile.bag:
		supplies += int(Profile.bag[k])
	for e in [
			["%d insignes" % Run.insignia_gain, green], ["%d pièce(s) découverte(s)" % Run.seen_items.size(), green],
			["%d coffre(s) à ouvrir" % Run.chests_found.size(), green],
			["%d fourniture(s) %s" % [supplies, "gardées" if kept else "perdues"], green if kept else red],
			["or et clés perdus", red]]:
		Hud._label(keep_row, String(e[0]), 17, e[1])
	var sh := Hud._label(v, "Gardé : %d insignes · %d pièce(s) découverte(s) dans les coffres" % [Run.insignia_gain, Run.seen_items.size()], 22, Hud.ACCENT)
	sh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ss := Hud._label(v, "L'équipement de la run n'est pas gardé : chaque pièce choisie dans un coffre devient achetable à l'Armurerie avec tes insignes. "
		+ ("Les fournitures de la run (ciseaux, parchemins, pierres) rejoignent ta réserve." if kept else "Les fournitures de la run, l'or et les clés sont perdus.")
		+ " Les coffres de récompense ramassés sont toujours gardés.", 14, MUTED)
	ss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ss.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm = Button.new()
	_confirm.custom_minimum_size = Vector2(0, 54)
	_confirm.add_theme_font_size_override("font_size", 20)
	_confirm.add_theme_stylebox_override("normal", Hud.style(Color(0.2, 0.15, 0.3)))
	_confirm.add_theme_stylebox_override("hover", Hud.style(Color(0.3, 0.22, 0.42)))
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.text = "Retour au lobby"
	_confirm.pressed.connect(_finish)
	var again := Button.new()
	again.custom_minimum_size = Vector2(0, 54)
	again.add_theme_font_size_override("font_size", 20)
	again.add_theme_stylebox_override("normal", Hud.style(Color(0.15, 0.3, 0.2)))
	again.add_theme_stylebox_override("hover", Hud.style(Color(0.22, 0.42, 0.3)))
	again.focus_mode = Control.FOCUS_NONE
	again.text = "Rejouer (%s)" % Epochs.get_def(Run.epoch).name
	again.disabled = not Run.survival or Run.epoch > Epochs.unlocked()
	again.pressed.connect(_replay)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(again)
	btns.add_child(_confirm)
	v.add_child(btns)
	add_child(root)


## Rejouer : même classe, même époque, sans repasser par le lobby.
func _replay() -> void:
	var epoch := Run.epoch
	Profile.end_run_survival()
	get_tree().paused = false
	Run.start_survival(Profile.selected_class, epoch)
	get_tree().change_scene_to_file("res://scenes/world.tscn")


func _finish() -> void:
	Profile.end_run_survival()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/lobby.tscn")
