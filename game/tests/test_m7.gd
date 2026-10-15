extends Node
## Passe M7 (Arènes, Duel, Gantelet) : équipes de familles variées, réglages du duel libre rendus, alliés à la fiche
## d'un héros, insignes selon la difficulté, promotion de Ligue avec coffre d'apparence, cerveau adverse qui vise les
## alliés (et que les alliés touchent), ciblage du plus faible, PV des équipes et tableau de manche, arène piégée,
## « Rejouer » d'une arène, page du Gantelet aux conditions de l'équipé, bilan d'une arène.
## godot --headless --path game res://tests/test_m7.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	_preset("warrior")
	# --- équipes : familles différentes, jamais la classe du joueur ---
	var ok := true
	for _i in 30:
		var t := Duel.team_classes(3, ["cleric"])
		var fams := {}
		for c in t:
			fams[Duel.family_of(c)] = true
		ok = ok and t.size() == 3 and fams.size() == 3 and not "warrior" in t and not "cleric" in t
	check("équipes de 3 : trois familles, ni ta classe ni les classes exclues", ok)
	var five := Duel.team_classes(5)
	var f5 := {}
	for c in five:
		f5[Duel.family_of(c)] = true
	check("5 classes : les 5 familles", five.size() == 5 and f5.size() == 5)
	var avoid := Duel.team_classes(2, [], [1, 2])
	check("familles à éviter respectées tant que possible", avoid.all(func(c): return not Duel.family_of(c) in [1, 2]))
	# --- réglages du duel libre mis de côté puis rendus ---
	Duel.bare = false
	Duel.bare_level = 42
	Duel.pilot = "normal"
	Duel.rival_build = {"class": "bard", "name": "Mon barde"}
	Duel.save_free()
	Duel.mode = "league"
	Duel.bare = true
	Duel.bare_level = 10
	Duel.pilot = ""
	Duel.rival_build = {}
	Duel.save_free()  # une 2e sauvegarde ne doit pas écraser la première
	Duel.restore_free()
	check("réglages du duel libre rendus (cerveau, éditeur, équipé, niveau)", Duel.mode == "free" and not Duel.bare and Duel.bare_level == 42
		and Duel.pilot == "normal" and String(Duel.rival_build.get("name", "")) == "Mon barde")
	Duel.pilot = ""
	Duel.rival_build = {}
	Duel.bare = true
	# --- insignes selon la difficulté, promotion de Ligue ---
	League.day_override = "2099-01-01"
	check("1re victoire du jour : Facile < Difficile (75) < Hardcore", League.daily_insignia("arena3", 0) < 75 and League.daily_insignia("arena3", 2) == 75
		and League.daily_insignia("arena3", 3) > 75)
	check("1re victoire du jour à prendre, puis prise", League.daily_open("arena3") and League.win_insignia("arena3", 3) == League.daily_insignia("arena3", 3)
		and not League.daily_open("arena3") and League.win_insignia("arena3", 3) == League.REPEAT_INSIGNIA)
	Profile.records["league_rank"] = 2
	Profile.records["league_streak"] = League.WINS_PER_RANK - 1
	var chests := Profile.reward_chests.size()
	var ins := Profile.insignia
	var rep := League.report(true, "warrior", 2)
	check("promotion Or : insignes, coffre d'apparence mythique, ligne du bilan", bool(rep.promoted) and Profile.insignia - ins == League.promo_insignia(3)
		and Profile.reward_chests.size() == chests + 1 and "look_epic" in rep.chests and (rep.text as Array).size() == 1)
	Profile.records["league_rank"] = 3
	# --- page du Gantelet : conditions de l'équipé, même si le duel libre est à l'arme ---
	Duel.bare = true
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.0).timeout
	lobby._duel_tab = "gauntlet"
	lobby._show_menu("duel")
	await get_tree().process_frame
	var go := _find_button(lobby, "Entrer dans le Gantelet")
	check("Gantelet sans armure : bouton fermé (conditions de l'équipé)", go != null and go.disabled)
	check("Gantelet : la page n'a pas changé le mode du duel libre", Duel.bare)
	lobby._show_menu("arenas")
	await get_tree().process_frame
	check("Arènes : difficulté, arène piégée, niveau et record", _find_button(lobby, "Hardcore") != null and _find_button(lobby, "Arène piégée") != null
		and _find_label(lobby, "1re victoire du jour") != null)
	lobby.queue_free()
	await get_tree().process_frame
	# --- arène 3v3 avec un cerveau en premier adversaire ---
	Duel.save_free()  # (comme le lobby)
	Duel.mode = "arena3"
	Duel.team_allies = ["cleric", "hunter"]
	Duel.extra_foes = ["assassin", "magician"]
	var brain := "hardcore" if MlDuelPilot.available().any(func(b): return b[0] == "hardcore") else ""
	Duel.pilot = brain
	Duel.hazards = true
	Duel.start("warrior", "knight", 2)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(8.0).timeout
	var dd: DuelDirector = world.director.duel
	var ally: ClassRival = dd._allies[0]
	var foe: ClassRival = dd._foes[-1]
	var mirror := Duel.make_extra("cleric")
	check("allié à la fiche d'un héros (mêmes PV qu'un adversaire de sa classe)", absf(ally.max_hp - mirror.max_hp) < 1.0)
	mirror.free()
	check("allié de la difficulté des adversaires", ally.difficulty == Duel.difficulty)
	check("titre du HUD : le mode", Duel.mode_title() == "Arène 3 contre 3")
	check("PV des équipes : 6 lignes", dd._bars != null and dd._bars._rows.size() == 6)
	if brain != "":
		check("cerveau : premier adversaire, il vise aussi les alliés", is_instance_valid(dd._foe) and dd._pilot.others == dd._allies)
		check("les alliés peuvent toucher le héros du cerveau", dd._foe in Combatant.hostile_targets(get_tree(), ally))
		check("le héros du cerveau peut toucher les alliés", ally in dd._foe.foes())
	else:
		print("(cerveau hardcore absent : contrôles du cerveau sautés)")
	# ciblage du plus faible : à distance égale, la cible la plus basse en PV
	var a: ClassRival = dd._foes[0]
	var p: Player = world.player
	ally.global_position = a.global_position + Vector3(4, 0, 0)
	p.global_position = a.global_position + Vector3(-4, 0, 0)
	ally.hp = ally.max_hp * 0.2
	p.hp = p.max_hp
	check("en équipe, l'adversaire vise le plus faible", a.pick_target([p, ally], null) == ally)
	a.difficulty = 0
	check("en Facile, le plus proche (pas de ciblage du plus faible)", a.pick_target([p, ally], null) != null)
	a.difficulty = 2
	ally.hp = ally.max_hp
	# arène piégée : une zone de feu touche tout le monde dedans
	await _until(func(): return dd.phase == "fight", 600)
	var before := foe.hp
	var tg := Telegraph.spawn(dd.d, foe.global_position, 0.0, {"shape": "circle", "radius": 3.0, "delay": 5.0, "damage": 0.0})
	await get_tree().process_frame
	foe._invuln_until = 0.0
	dd._hazard_hit(tg)
	check("zone de feu : touche un héros dedans (tous camps)", foe.hp < before)
	tg.queue_free()
	# tableau de la manche : coups notés
	PvpCaps.note_hit(p, foe, 10.0)
	check("tableau de manche : dégâts notés", float(dd.board.get(p.get_instance_id(), {}).get("dealt", 0.0)) >= 10.0)
	# fin : bilan d'arène, puis « nouvelle équipe adverse »
	Duel.wins = 2
	world.duel_end(true)
	await get_tree().create_timer(0.5).timeout
	check("bilan d'arène : sous-titre au nom du mode", _find_label(get_tree().root, "Arène 3 contre 3") != null)
	check("bilan d'arène : bouton « Nouvelle équipe adverse »", _find_button(get_tree().root, "Nouvelle équipe adverse") != null)
	var allies_before: Array = Duel.team_allies.duplicate()
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Duel.replay()
	check("Rejouer : même mode, mêmes alliés, 3 adversaires", Duel.mode == "arena3" and Duel.team_allies == allies_before and Duel.extra_foes.size() == 2 and Duel.active)
	Duel.active = false
	Run.active = false
	Duel.restore_free()  # (ce que fait Duel.leave au retour au lobby)
	check("retour au lobby : duel libre", Duel.mode == "free" and Duel.team_allies.is_empty())
	Duel.hazards = false
	League.day_override = ""
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _preset(cid: String) -> void:
	var ids: Array = (GameData.class_data(cid).get("skills", []) as Array).slice(0, 4).map(func(x): return int(x.id))
	SpellPresets.store(cid, "M7", [[ids[0], 0, 0], [ids[1], 0, 0], [ids[2], 0, 0], [ids[3], 0, 0]])


func _find_button(root: Node, text: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if String((n as Button).text).contains(text):
			return n
	return null


func _find_label(root: Node, text: String) -> Label:
	for n in root.find_children("*", "Label", true, false):
		if String((n as Label).text).contains(text):
			return n
	return null


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
