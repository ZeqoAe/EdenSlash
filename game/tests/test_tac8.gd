extends Node
## Lot TAC-8 : mort, spectateur, ordres, fin de manche, bilan, récompenses, activité et page du lobby de L'Assaut.
## Pur : récompenses scellées (coffre selon la difficulté, première victoire puis plafond du jour, Éclair un cran plus bas,
## titres de victoire et d'exploit, abandon, partie regardée), « Meilleur héros », lignes du récapitulatif, quêtes du mode
## (tirées seulement quand l'activité est montrée, apparences seulement), activité cachée hors mode dev, aide aux ressources.
## Partie réelle sur le Bourg : chute du joueur -> récapitulatif (tueur, coup), spectateur d'un allié (changement d'allié), ordres
## aux alliés (réponses, l'allié rejoint B), carte de fin de manche (or gagné), bilan (frise, tableau des 8, Meilleur héros,
## coffre gagné, Rejouer / Menu principal) qui tient dans 1280 × 720 ; page du lobby (format, difficultés, carte, Lancer).
## godot --headless --path game res://tests/test_tac8.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	_pure()
	await _world()
	await _page()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _info(won: bool, diff: int, fmt := "assault", defuses := 0, clutch := 0, score := [7, 3]) -> Dictionary:
	return {"won": won, "forfeit": false, "format": fmt, "diff_foes": diff, "score": score, "clutch": clutch, "history": [],
		"heroes": [{"key": "t0_0", "team": 0, "me": true, "kills": 3, "deaths": 2, "assists": 1, "plants": 1, "defuses": defuses,
			"gold": 9000, "dmg": 5000.0, "cid": "warrior", "name": "Toi", "role": "rempart"}], "cid": "warrior", "secs": 900.0}


func _pure() -> void:
	# récompenses scellées
	check("coffre selon la difficulté : Facile commun, Expert légendaire, Éclair un cran plus bas",
		AssaultRewards.chest_for(0) == "look_common" and AssaultRewards.chest_for(3) == "look_legend" and AssaultRewards.chest_for(2, true) == "look_rare")
	var chests0 := Profile.reward_chests.size()
	var got := AssaultRewards.settle(_info(true, 1))
	check("1re victoire en Normal : coffre rare (première fois) et titre « Sapeur »", (got.chests as Array).size() == 1
		and String(got.chests[0].type) == "look_rare" and String(got.chests[0].kind) == "first" and "Sapeur" in Profile.extra_titles
		and Profile.reward_chests.size() == chests0 + 1)
	got = AssaultRewards.settle(_info(true, 1))
	check("2e victoire : coffre du jour", (got.chests as Array).size() == 1 and String(got.chests[0].kind) == "daily")
	got = AssaultRewards.settle(_info(true, 1))
	got = AssaultRewards.settle(_info(true, 1))
	check("plafond du jour (%d coffres de victoire)" % AssaultRewards.DAILY_CAP, (got.chests as Array).is_empty() and int(got.left) == 0)
	got = AssaultRewards.settle(_info(true, 3))
	check("1re victoire en Expert : passe le plafond (première fois), coffre légendaire", (got.chests as Array).size() == 1
		and String(got.chests[0].type) == "look_legend")
	got = AssaultRewards.settle(_info(false, 2, "assault", 10, 1))
	check("défaite : aucun coffre ; exploits « Démineur » (10 désamorçages) et « Dernier rempart »", (got.chests as Array).is_empty()
		and "Démineur" in Profile.extra_titles and "Dernier rempart" in Profile.extra_titles)
	got = AssaultRewards.settle(_info(true, 0, "assault", 0, 0, [7, 0]))
	check("7 à 0 : « Sans une perte »", "Sans une perte" in Profile.extra_titles)
	var ab := _info(true, 2)
	ab.forfeit = true
	check("abandon : rien", (AssaultRewards.settle(ab).chests as Array).is_empty())
	var watch := _info(true, 2)
	watch.watch = true
	check("partie regardée (8 IA) : rien", AssaultRewards.finish(watch).is_empty())
	var q := AssaultRewards.quest_extra(_info(true, 1, "assault", 2))
	check("quêtes : poses + désamorçages comptés", int(q.charge_acts) == 3 and q.has("rounds_won"))
	# Meilleur héros
	var a := {"key": "a", "kills": 8, "assists": 2, "plants": 1, "defuses": 0, "dmg": 9000.0, "deaths": 4}
	var b := {"key": "b", "kills": 2, "assists": 1, "plants": 0, "defuses": 0, "dmg": 3000.0, "deaths": 7}
	check("Meilleur héros : le plus d'éliminations et de dégâts", AssaultResults.best_of([b, a]) == "a")
	# récapitulatif
	check("récapitulatif : « par Kage · Ouvreur »", AssaultRecap.headline({"name": "Kage", "role": "ouvreur"}) == "par Kage · Ouvreur")
	check("récapitulatif : coup dans le dos et PV restants", AssaultRecap.how_line({"move": "Lame d'ombre", "back": true, "killer_hp": 410})
		== "Lame d'ombre, dans le dos · il lui reste 410 PV")
	check("récapitulatif : l'explosion", AssaultRecap.headline({"blast": true}).contains("explosion"))
	# activité, quêtes, aide
	Settings.set_v("interface", "dev_mode", false)
	var act := Activities.get_def("assault")
	check("activité : plus « Bientôt », mais cachée hors mode dev", not act.get("soon", false) and Activities.hidden(act))
	check("quêtes du mode : jamais tirées tant que l'activité est cachée", not QuestPool.gate_ok("assault")
		and not QuestPool.available(QuestPool.get_def("as_rounds"), "daily"))
	check("aide aux ressources : pas de mention cachée", not ResourceHelp.tip("look").contains("Assaut"))
	Settings.set_v("interface", "dev_mode", true)
	check("mode dev : activité montrée, quêtes possibles, aide qui la cite", not Activities.hidden(act) and QuestPool.gate_ok("assault")
		and QuestPool.ACTS.has("assault") and ResourceHelp.tip("look").contains("L'Assaut"))
	var rw := Quests._roll_reward(QuestPool.get_def("as_win"), "weekly", 0, RandomNumberGenerator.new())
	check("quêtes du mode : apparences seulement (%s)" % str(rw), rw.has("chest") and not rw.has("mastery"))


func _world() -> void:
	Profile.records.erase(AssaultRewards.KEY)  # (les contrôles purs ont pris la première victoire et le plafond du jour)
	Profile.save_profile()
	Profile.selected_class = "warrior"
	Assault.launch("warrior", {"map": "bourg", "seed": 21, "speed": 1.0, "first_attack": 0, "buy_time": 1.0, "buy_time_first": 1.0,
		"round_time": 600.0, "diff_foes": 1})
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	await _until(func(): return world.director.map != null and world.director.map._region.navigation_mesh != null, 3600)
	var dd: AssaultDirector = world.director.team
	var p: Player = world.player
	var ah: AssaultHud = world.hud.get("_assault")
	await _until(func(): return Assault.phase == "live", 600)
	await get_tree().process_frame
	for k in Assault.members[1]:
		var h := dd.hero(String(k)) as ClassRival
		if h != null:
			h.passive = true
	# chute du joueur
	var foe := dd.hero("t1_0")
	p.set_meta("assault_shield", 0.0)
	p.hp = 1.0
	p.take_damage(400.0, foe, false, true)
	await _until(func(): return ah.recap != null, 120)
	check("chute : récapitulatif ouvert", ah.recap != null and ah.recap.is_card_open())
	if ah.recap == null:
		return
	check("récapitulatif : le tueur (%s)" % str(ah.recap.data.get("name")), String(ah.recap.data.get("killer", "")) == "t1_0"
		and String(ah.recap.data.get("name", "")) != "")
	check("barre d'action cachée pendant la chute", not (world.hud.get("_action_root") as Control).visible)
	var w0 := TeamMatch.watched
	check("spectateur : un allié debout est suivi", w0 != null and Assault.team_of(dd.key_of(w0)) == 0 and world.rig.target == w0)
	var w1 := ah.recap.watch_next(1)
	check("[▶] / RB : un autre allié", w1 != null and w1 != w0 and world.rig.target == w1 and dd.view_hero() == w1)
	check("le bandeau du spectateur nomme l'allié et les ordres", ah.recap.bar_text().contains("Tu regardes") and ah.recap.bar_text().contains("Ordres"))
	# ordres
	ah.recap.toggle_orders(1)
	check("ordres : 6 ordres, la carte s'ouvre", ah.recap.orders.visible and ah.recap.order_buttons.size() == 6)
	var replies := ah.recap.give("go_b")
	check("« Va en B » à toute l'équipe : 3 réponses (%s)" % str(replies.map(func(r): return r.text)), replies.size() == 3
		and dd.orders.size() >= 1 and ah.recap.orders.visible == false)
	check("les réponses s'écrivent dans la colonne de droite", ah.column.lines.any(func(l): return String(l.text).contains("« ")))
	var ordered := String(dd.orders.keys()[0]) if not dd.orders.is_empty() else ""
	await get_tree().create_timer(0.5).timeout
	var r := dd.hero(ordered)
	var goal := Vector3.INF
	if r != null:
		goal = r.get("anchor") if "anchor" in r else (r as ClassRival).goal
	check("l'allié reçoit le point de B comme but", goal != Vector3.INF and Vector2(goal.x - dd.site_pos("B").x, goal.z - dd.site_pos("B").z).length() < 4.0)
	check("« Va au repère » sans repère : grisé", ah.recap.order_buttons.any(func(e): return String(e[1]) == "go_ping") and dd.ping == Vector3.INF)
	# fin de manche : carte, or gagné
	var cards0 := dd.round_cards.size()
	dd._handle(Assault.end_round(0, "elim"))
	await get_tree().process_frame
	await get_tree().process_frame
	check("fin de manche : une carte (gagnée, or)", dd.round_cards.size() == cards0 + 1 and ah.round_card.visible
		and bool(dd.round_cards[-1].winner == 0))
	# bilan
	Assault.winner = 0
	dd._finish()
	await _until(func(): return world.get_children().any(func(c): return c is AssaultResults), 120)
	var res: AssaultResults
	for c in world.get_children():
		if c is AssaultResults:
			res = c
	check("bilan : AssaultResults (ResultsPanel)", res != null)
	if res != null:
		check("bilan : frise des manches et tableau des 8", res.frieze != null and res.board != null and (res.board.heroes as Array).size() == 8)
		check("bilan : Meilleur héros désigné", res.mvp != "")
		check("bilan : Rejouer et Menu principal", res.buttons.size() == 2 and res.buttons[0].text.contains("Rejouer"))
		check("bilan : coffre d'apparence de la victoire", (AssaultRewards.last.get("chests", []) as Array).size() == 1)
		get_tree().root.size = Vector2i(1280, 720)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var pr: Rect2 = res._panel.get_global_rect()
		check("bilan tenu dans 1280 × 720 (%s)" % str(pr), Rect2(0, 0, 1280, 720).grow(1.0).encloses(pr))
		get_tree().root.size = Vector2i(1600, 900)
	check("partie finie : TeamMatch fermé, rien de scellé", not TeamMatch.active and not Assault.active)
	check("récompenses enregistrées (records.as_rewards)", Profile.records.has(AssaultRewards.KEY))
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false


func _page() -> void:
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.0).timeout
	lobby._show_menu("play")
	await get_tree().process_frame
	check("menu Jouer (mode dev) : L'Assaut parmi les activités", Activities.LIST.any(func(x): return x.id == "assault" and not Activities.hidden(x)))
	lobby._show_menu("assault")
	await get_tree().process_frame
	var go := lobby.find_child("AssaultGo", true, false) as Button
	check("page du mode : « Lancer l'Assaut »", go != null)
	var ecl := lobby.find_child("AssaultFormat_eclair", true, false) as Button
	check("page du mode : formats, adversaires, alliés, carte", ecl != null and lobby.find_child("AssaultFoes_3", true, false) != null
		and lobby.find_child("AssaultAllies_0", true, false) != null and lobby.find_child("AssaultMap_bourg", true, false) != null)
	if ecl != null:
		ecl.pressed.emit()
		await get_tree().process_frame
	check("Éclair choisi : options de la partie", AssaultPage.options().format == "eclair")
	var pont := lobby.find_child("AssaultMap_pont", true, false) as Button
	check("cartes à venir : grisées", pont != null and pont.disabled)
	AssaultPage.format = "assault"
	lobby.queue_free()
	await get_tree().process_frame


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
