extends Node
## Lot U9 : bilans de fin de partie (un seul composant, ResultsPanel), menu pause (cases occupées, confirmations),
## HUD (AUTO sur case remplie, titres, compteur de dégâts, Premiers pas en Survie seulement).
## godot --headless --path game res://tests/test_results.tscn  (profil de test uniquement)

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


## Textes de toutes les lignes d'une description de bilan.
func _texts(spec: Dictionary) -> Array:
	var out: Array = []
	for k in ["gained", "kept", "lost"]:
		for r in spec.get(k, []):
			out.append(String(r.text))
	return out


func _clear() -> void:
	get_tree().paused = false
	for c in get_children():
		c.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	await _survival()
	await _modes()
	await _pause_and_hud()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


# --- Survie : un bilan sans doublon, avec insignes de participation et coffres de la run ---------------
func _survival() -> void:
	Run.start_survival("warrior", 1)
	Run.kills = 40
	Run.elites = 2
	Run.max_level = 9
	Run.stage = 2
	Run.gold = 90
	Profile.gold = 90  # (le solde de la run : perdu à la fin)
	Run.seen_items = [101, 102]
	Profile.reward_chests.append(Rewards.make("forge", 40, true, "scroll"))
	Profile.reward_chests.append(Rewards.make("forge", 40, true, "scroll"))
	Profile.reward_chests.append(Rewards.make("look_rare", 40, true))
	Run.finish("defaite")
	var rs := ResultsScreen.new()
	add_child(rs)
	rs.show_results()
	await get_tree().process_frame
	var spec := rs.spec()
	var txt := _texts(spec)
	check("Survie : un seul bloc « Insignes » et une seule ligne de pièces (plus de doublon) : %s" % [txt], txt.count("Insignes") == 1 and txt.count("Pièces découvertes") == 1)
	check("Survie : défaite (ton rouge), titre et sous-titre", spec.title == "DÉFAITE" and spec.tone == "lose" and String(spec.subtitle).contains("Époque I"))
	check("Survie : insignes gardés = ceux de la run", spec.kept[0].value == "+%d" % Run.insignia_gain and Run.insignia_gain >= 25)
	var tip := String(spec.kept[0].tip)
	check("Survie : participation (10 monstres) dans l'infobulle des insignes : %s" % [tip.replace("\n", " | ")], tip.contains("Participation : +25") and tip.contains("Cartes atteintes : +50"))
	check("Survie : coffres de la run listés (forge · parchemins ×2, apparence)", txt.has("Coffre de forge · parchemins") and txt.has("Coffre d'apparence rare") and spec.kept.any(func(r): return r.text == "Coffre de forge · parchemins" and r.value == "×2"))
	check("Survie : l'or reste dans la run (bloc Perdu)", spec.lost.any(func(r): return r.text == "Or" and r.value == "90"))
	check("Survie : fournitures perdues en défaite, gardées en victoire", ResultsScreen.lost_rows(true).all(func(r): return r.text != "Fournitures") and ResultsScreen.kept_rows(false).all(func(r): return r.text != "Fournitures"))
	check("Survie : deux boutons, Rejouer en or", spec.buttons.size() == 2 and spec.buttons[0].primary and spec.buttons[1].text == "Retour au lobby")
	check("Survie : « Retour au lobby » gelé à l'ouverture (anti-appui)", rs.buttons.size() == 2 and rs.buttons[1].disabled)
	await get_tree().create_timer(ResultsPanel.LOCK_SECS + 0.3, true).timeout
	check("Survie : boutons actifs après le délai", not rs.buttons[1].disabled)
	check("Survie : le bilan met le jeu en pause et se déclare au HUD", get_tree().paused and get_tree().get_nodes_in_group("results_panel").size() == 1)
	var no_note := true
	for t in txt:
		no_note = no_note and not t.contains("Aide au combat") and not t.contains("n'est pas gardé")
	check("Survie : plus de phrases de justification", no_note)
	await _clear()
	# victoire : l'époque suivante annoncée
	Run.result = "victoire"
	Run.unlocked_epoch = "Époque II"
	var rv := ResultsScreen.new()
	add_child(rv)
	rv.show_results()
	var sv := rv.spec()
	check("Survie : victoire annonce l'époque débloquée", sv.title == "VICTOIRE !" and sv.tone == "win" and sv.notes == ["Époque II débloquée !"])
	Run.unlocked_epoch = ""
	await _clear()
	Profile.end_run_survival()


# --- les autres modes : même composant, mêmes blocs ------------------------------------------------------
func _modes() -> void:
	Run.start("warrior")
	Run.kills = 12
	var d := DuelResults.new()
	add_child(d)
	Duel.last_report = {"mode": "league", "promoted": true, "rank": 2, "mastery": 120}
	d.show_results(true, "2 - 1", "thief", 2, 5)
	check("Duel : c'est un ResultsPanel avec Rejouer + Retour", d is ResultsPanel and d.buttons.size() == 2 and d.buttons[0].text.begins_with("Rejouer"))
	var rep: Dictionary = d._report_rows()
	check("Duel : Ligue = promotion, maîtrise et série dans « Gagné »", rep.gained.size() == 3 and rep.gained[0].text == "Promotion" and rep.kept.is_empty())
	await _clear()
	Duel.last_report = {"mode": "pantheon", "text": ["+80 insignes (victoire sur le cerveau Facile)", "Pièce « bottes »"]}
	d = DuelResults.new()
	add_child(d)
	d.show_results(true, "2 - 0", "thief", 1, 1)
	rep = d._report_rows()
	check("Duel : Panthéon = récompenses dans « Gardé », insignes en ligne de valeur", rep.kept.size() == 2 and rep.kept[0].text == "Insignes" and rep.kept[0].value == "+80" and rep.kept[1].text == "Pièce « bottes »")
	await _clear()
	Duel.last_report = {"mode": "arena2", "mastery": 50, "text": ["+40 insignes (1re victoire du jour)", "Titre : « Arène à deux »", "Maîtrise : +50"]}
	d = DuelResults.new()
	add_child(d)
	d.show_results(true, "2 - 0", "thief", 1, 1)
	rep = d._report_rows()
	check("Duel : Arènes = maîtrise et titre dans « Gagné », insignes dans « Gardé » (sans doublon de maîtrise)",
		rep.gained.size() == 2 and rep.gained[0].value == "+50" and rep.gained[1].text.begins_with("Titre") and rep.kept.size() == 1 and rep.kept[0].value == "+40")
	Duel.last_report = {}
	await _clear()
	var t := TowerResults.new()
	add_child(t)
	t.show_results("defaite", 14, {"best": 14, "new_record": true, "xp": 130, "levels": 1, "items": 2, "crystals": 15,
		"chests": [Rewards.make("forge", 30, true, "scroll"), Rewards.make("jewel", 30, true, "gem")], "looks": 1})
	check("Tour : même composant, 2 boutons", t is ResultsPanel and t.buttons.size() == 2)
	await _clear()
	var rows := ResultsPanel.chest_rows([Rewards.make("forge", 30, true, "scroll"), Rewards.make("forge", 30, true, "scroll"), Rewards.make("forge", 30, true, "stone"), Rewards.make("jewel", 30, true, "gem")])
	check("coffres de matières (E1) : un type et une spécialité par ligne : %s" % [rows.map(func(r): return r.text + " " + r.value)], rows.size() == 3
		and rows.any(func(r): return r.text == "Coffre de forge · parchemins" and r.value == "×2") and rows.any(func(r): return r.text == "Coffre de forge · pierres") and rows.any(func(r): return r.text.begins_with("Coffre de joaillier")))
	var g := DungeonResults.new()
	add_child(g)
	g.show_results({"victory": true, "zone": "limestone", "diff": 1, "rooms": 4, "xp": 90,
		"reward": {"chests": [Rewards.make("set", 30, true), Rewards.make("forge", 60, true, "scroll")], "crystals": 90, "plan": "x", "title": "Brise-donjon"}})
	check("Donjon : 2 boutons, Rejouer (même donjon)", g.buttons.size() == 2 and g.buttons[0].text == "Rejouer (même donjon)")
	await _clear()
	g = DungeonResults.new()
	add_child(g)
	g.show_results({"victory": false, "zone": "limestone", "diff": 0, "rooms": 1, "xp": 10, "reward": {}})
	check("Donjon : un échec sans butin s'affiche", g.buttons.size() == 2)
	await _clear()
	g = DungeonResults.new()
	add_child(g)
	g.show_results({"victory": true, "siege": true, "outcome": "won", "zone": "limestone", "diff": 2, "rooms": 5, "xp": 200, "reward": {"chests": [], "crystals": 200}})
	check("Siège : Rejouer (même siège)", g.buttons[0].text == "Rejouer (même siège)")
	await _clear()
	var r := RoyaleResults.new()
	add_child(r)
	r.show_results(1, 3, 9, 7, 400.0, {"text": ["+120 insignes (victoire, 3 éliminations)"]})
	check("Royale : même composant, Rejouer + Retour", r is ResultsPanel and r.buttons.size() == 2 and r.buttons[1].text == "Retour au lobby")
	await _clear()
	var rr := ResultsPanel.reward_row("+90 insignes (place 3)")
	check("récompenses en texte : « +90 insignes (place 3) » devient Insignes +90", rr.text == "Insignes" and rr.value == "+90" and rr.tip == "Place 3" and ResultsPanel.reward_row("Coffre rare").text == "Coffre rare")
	Run.active = false


# --- pause et HUD ---------------------------------------------------------------------------------------
func _pause_and_hud() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Tutorial.set_mode("guided")
	Run.start_survival("warrior", 1)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var hud: Hud = world.hud
	world.cards._queue.clear()
	world.cards._show_next()
	Run.apply_card(Run.roll_cards(3, true)[0])  # un sort dans la case 1 : les autres restent vides
	Settings.data["game"]["auto_combo"] = true
	hud._refresh_skills()
	var empties := hud._slots.filter(func(s): return s.empty)
	var filled := hud._slots.filter(func(s): return not s.empty)
	check("HUD : sorts auto => AUTO sur les cases remplies seulement (%d vides, %d remplies)" % [empties.size(), filled.size()],
		not empties.is_empty() and not filled.is_empty() and empties.all(func(s): return not s.auto) and filled.all(func(s): return s.auto))
	Settings.data["game"]["auto_combo"] = false
	check("HUD : FPS caché par défaut", not bool(Settings.get_v("interface", "show_fps")) and not hud._fps_label.visible)
	await get_tree().create_timer(0.3).timeout
	check("HUD : Premiers pas visibles en Survie", hud._survival_mode() and hud._steps_panel.visible)
	check("HUD : titre sans intervalle de niveaux en Survie", not hud._zone_label.text.contains(" Nv "))
	var prev := Duel.active
	Duel.active = true
	check("HUD : titre de duel « Nv 20 » (pas « 20-20 »)", Hud.zone_title({"name": "Duel · Voleur", "levels": [20, 20]}) == "Duel · Voleur · Nv 20")
	Run.combo_damage = 500.0
	Run._combo_last = Time.get_ticks_msec()
	hud._dmg_box.modulate.a = 1.0
	for i in 30:
		hud._update_damage_counter(0.1)
	check("HUD : compteur de dégâts caché en duel", hud._dmg_box.modulate.a < 0.5)
	check("HUD : pas de Premiers pas en duel", not hud._survival_mode())
	Duel.active = prev
	var ra := Royale.active
	Royale.active = true
	check("HUD : pas de Premiers pas au Battle royale (même avec le drapeau de la Survie)", not hud._survival_mode() and Hud.zone_title({"name": "x", "levels": [1, 40]}) == "")
	Royale.active = ra
	# pause : cases occupées, confirmations
	world.pause_menu.open()
	await get_tree().process_frame
	var run_page: RunPage = world.pause_menu._run
	run_page.refresh()
	await get_tree().process_frame
	var free_rows := 0
	for l in run_page._skills.find_children("*", "Label", true, false):
		if (l as Label).text.contains("libre") and (l as Label).is_visible_in_tree():  # (les positions d'enchaînement libres sont cachées hors glisser)
			free_rows += 1
	check("pause : une seule case libre affichée (pas 8 lignes vides) : %d" % free_rows, free_rows <= 1)
	var all_text := ""
	for l in run_page.find_children("*", "Label", true, false):
		all_text += (l as Label).text + "\n"
	check("pause : plus de phrases d'état vide", not all_text.contains("Quand les 4 cases") and not all_text.contains("s'obtiennent avec les cartes") and not all_text.contains("Glisse un sort"))
	run_page.quit_requested.emit()
	await get_tree().process_frame
	check("pause : « Quitter le jeu » demande confirmation (rien n'est quitté)", world.pause_menu._confirm.visible)
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	world.pause_menu._confirm._input(ev)
	check("pause : Échap / B annule la confirmation", not world.pause_menu._confirm.visible)
	run_page.lobby_requested.emit()
	await get_tree().process_frame
	check("pause : « Abandonner » demande aussi confirmation", world.pause_menu._confirm.visible and world.pause_menu._confirm._title.text == "Abandonner la run ?")
	world.pause_menu.close()
	check("pause : fermer la pause ferme la confirmation", not world.pause_menu._confirm.visible)
	var lt: Dictionary = PauseMenu.leave_texts()
	check("pause : textes d'abandon de la Survie", lt.button == "Abandonner la run" and lt.ok == "Abandonner")
	world.queue_free()
	await get_tree().process_frame
