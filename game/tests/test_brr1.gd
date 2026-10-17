extends Node
## Battle royale, lot BR-R1 (contenu et règles du backlog BM-BR) : modificateurs de partie (RoyaleMods), autel du gardien
## (RoyaleEvent), Ligue royale (RoyaleLeague), apparences du mode et couronne (RoyaleLooks), carrière, défis des quêtes, partie
## personnalisée (graine), page du mode v2 (RoyalePage) à 1600×900 et 1280×720, densité (RoyaleDirector.density), remercier l'aigle.
## godot --headless --path game res://tests/test_brr1.tscn

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	Settings.reset_all()
	League.day_override = "2026-10-17"
	_test_mods()
	_test_league()
	_test_looks_and_career()
	_test_quests()
	await _test_page()
	await _test_game()
	League.day_override = ""
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


# --- modificateurs ---------------------------------------------------------------------------------------
func _test_mods() -> void:
	var days := ["2026-10-17", "2026-10-18", "2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22"]
	var seen := {}
	var same := false
	for i in days.size():
		var m := RoyaleMods.today_id(String(days[i]))
		seen[m] = true
		if i > 0 and m == RoyaleMods.today_id(String(days[i - 1])):
			same = true
	check("modificateur du jour : il tourne (%d différents sur 6 jours, jamais deux fois de suite)" % seen.size(), seen.size() == RoyaleMods.LIST.size() and not same)
	check("modificateur du jour : le même toute la journée", RoyaleMods.today_id("2026-10-17") == RoyaleMods.today_id("2026-10-17"))
	check("5 modificateurs, chacun avec un nom et une phrase", RoyaleMods.LIST.size() == 5 and RoyaleMods.LIST.all(func(m): return String(m.name) != "" and String(m.line).length() <= 90))
	check("inconnu ou vide : classique", RoyaleMods.get_def("") == RoyaleMods.CLASSIC and RoyaleMods.get_def("zz") == RoyaleMods.CLASSIC)
	Royale.mod = ""
	var base := Royale.total_time()
	check("classique : coffres, fontaines, anneau et éliminations inchangés", RoyaleMods.chest_tier(0) == 0 and RoyaleMods.chest_tier(1) == 1
		and RoyaleMods.well_count() == 4 and is_equal_approx(base, 590.0) and is_equal_approx(Royale.kill_xp(5, 5), 1.0))
	Royale.mod = "gold"
	check("ruée vers l'or : commun -> rare -> doré, le doré reste doré", RoyaleMods.chest_tier(0) == 1 and RoyaleMods.chest_tier(1) == 2 and RoyaleMods.chest_tier(2) == 2)
	Royale.mod = "fast"
	var fast := Royale.total_time()
	check("anneau pressé : %.0f s au lieu de %.0f (6 min environ)" % [fast, base], fast > 330.0 and fast < 400.0)
	var r := Royale.ring_at(60.0, [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	check("anneau pressé : il se resserre plus tôt (à 60 s : %s)" % String(r.state), String(r.state) == "hold" and float(r.left) < 2.0 or String(r.state) == "shrink")
	Royale.mod = "wells"
	check("sources de vie : %d fontaines" % RoyaleMods.well_count(), RoyaleMods.well_count() == 12)
	Royale.mod = "hunt"
	check("chasse ouverte : une élimination vaut plus (%.2f)" % Royale.kill_xp(5, 5), Royale.kill_xp(5, 5) > 1.4)
	Royale.mod = ""


# --- Ligue royale ----------------------------------------------------------------------------------------
func _test_league() -> void:
	Profile.reset_all()
	check("saison : « Saison d'octobre », 15 jours restants le 17", RoyaleLeague.season_name() == "Saison d'octobre" and RoyaleLeague.days_left() == 15
		and RoyaleLeague.season_name("2026-03") == "Saison de mars")
	check("fin du mois : 1 jour", RoyaleLeague.days_left("2026-10-31") == 1 and RoyaleLeague.days_left("2026-12-31") == 1)
	check("points : place + 2 par élimination, × difficulté (4e, 1 élim., Difficile : 7)", RoyaleLeague.points_for(4, 1, 2) == 7
		and RoyaleLeague.points_for(1, 9, 3) == roundi((14 + 10) * 1.25) and RoyaleLeague.points_for(8, 0, 0) == 1 and RoyaleLeague.points_for(4, 1, -1) == 7)
	check("compte neuf : Bronze, 0 point, jamais classé", RoyaleLeague.rank() == 0 and RoyaleLeague.points() == 0 and RoyaleLeague.best_ever() == -1)
	var chests0 := Profile.reward_chests.size()
	var r1 := RoyaleLeague.report(1, 5, 3)  # 30 points : Argent tout de suite
	check("victoire Hardcore 5 élim. : %d points, Argent, coffre rare et titre" % int(r1.points), int(r1.points) == 30 and int(r1.rank) == 1 and bool(r1.promoted)
		and Profile.reward_chests.size() == chests0 + 1 and "Voltigeur d'argent" in Profile.extra_titles)
	RoyaleLeague.report(1, 5, 3)
	check("même rang : pas de second coffre", Profile.reward_chests.size() == chests0 + 1)
	for i in 3:
		RoyaleLeague.report(1, 5, 3)
	check("150 points : Platine, coffres épique et légendaire (une fois chacun)", RoyaleLeague.rank() == 3 and Profile.reward_chests.size() == chests0 + 3
		and RoyaleLeague.to_next() == 0)
	League.day_override = "2026-11-02"
	check("nouvelle saison : retour à zéro, meilleur rang de l'ancienne gardé", RoyaleLeague.points() == 0 and RoyaleLeague.rank() == 0
		and int(RoyaleLeague.state().best.get("2026-10", -1)) == 3 and RoyaleLeague.best_ever() == 3)
	RoyaleLeague.report(1, 5, 3)
	check("nouvelle saison : le coffre du rang revient, pas le titre", Profile.reward_chests.size() == chests0 + 4
		and Profile.extra_titles.count("Voltigeur d'argent") == 1)
	League.day_override = "2026-10-17"


# --- apparences, couronne, carrière ----------------------------------------------------------------------
func _test_looks_and_career() -> void:
	Profile.reset_all()
	check("voile soleil et sans traînée d'office", String(RoyaleLooks.glider().id) == "soleil" and String(RoyaleLooks.trail().id) == "")
	check("voile fermée refusée", not RoyaleLooks.pick("glider", "amethyste") and String(RoyaleLooks.glider().id) == "soleil")
	Royale.custom = false
	Royale.stats = {"dealt": 1234.0}
	Royale.difficulty = 2
	var got := Royale.settle(1, 3, "magician")
	check("victoire : couronne pour la partie suivante, carrière notée", RoyaleLooks.crowned() and int(Profile.records.royale_podiums) == 1
		and int(Profile.records.royale_best_kills) == 3 and int(Profile.records.royale_class_wins.magician) == 1 and float(Profile.records.royale_dealt) >= 1234.0)
	check("bilan : ligne de la Ligue royale", (got.text as Array).any(func(t): return String(t).begins_with("Ligue royale : +")) and not (got.league as Dictionary).is_empty())
	check("victoire : voile améthyste et traînée étoiles ouvertes, choisies", RoyaleLooks.pick("glider", "amethyste") and RoyaleLooks.pick("trail", "etoiles")
		and String(RoyaleLooks.glider().id) == "amethyste" and String(RoyaleLooks.trail().id) == "etoiles")
	check("traînée : un émetteur (aucune : rien)", RoyaleLooks.make_trail(RoyaleLooks.trail()) != null and RoyaleLooks.make_trail(RoyaleLooks.TRAILS[0]) == null)
	Royale.settle(5, 0, "magician")
	check("partie suivante finie : la couronne tombe", not RoyaleLooks.crowned())
	Royale.settle(1, 0, "magician")
	var ins := Profile.insignia
	var games := int(Profile.records.royale_games)
	var pts := RoyaleLeague.points()
	Royale.custom = true
	var cg := Royale.settle(1, 4, "magician")
	Royale.custom = false
	check("partie personnalisée : ni insignes, ni ligue, ni record, la couronne reste", Profile.insignia == ins and int(Profile.records.royale_games) == games
		and RoyaleLeague.points() == pts and RoyaleLooks.crowned() and (cg.text as Array).size() == 1)
	var crown := RoyaleLooks.make_crown()
	check("couronne : un anneau et cinq pointes", crown.get_child_count() == 6)
	crown.free()
	var vals := RoyalePage.career_values()
	check("carrière : 8 tuiles, classe la plus gagnante", vals.size() == 8 and RoyalePage.best_class().begins_with("Magicien"))


# --- quêtes du mode ------------------------------------------------------------------------------------
func _test_quests() -> void:
	var ids := ["ry_land3", "ry_bounty", "ry_altar", "ry_clean"]
	var defs: Array = QuestPool.LIST.filter(func(q): return String(q.id) in ids)
	check("4 défis du mode dans le pool", defs.size() == 4 and defs.all(func(q): return String(q.act) == "royale"))
	Royale.stats = {"land3": 1, "bounty_kill": 1, "altar": 1}
	var ctx := Quests.run_ctx("royale", true, Royale.quest_extra(1, 2))
	check("partie : ★★★, mis à prix, gardien comptés", Quests.stat_of("land3", ctx) == 1 and Quests.stat_of("bounty_kill", ctx) == 1 and Quests.stat_of("altar", ctx) == 1)
	var clean: Dictionary = defs.filter(func(q): return String(q.id) == "ry_clean")[0]
	check("gagner sans réanimation : vrai sans retour", Quests.when_ok(clean.when, ctx, {}))
	Royale.stats["revived"] = 1
	check("... faux après un retour", not Quests.when_ok(clean.when, Quests.run_ctx("royale", true, Royale.quest_extra(1, 2)), {}))
	Royale.stats = {}


# --- page du mode --------------------------------------------------------------------------------------
func _test_page() -> void:
	Profile.reset_all()
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await _frames(3)
	for res in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_tree().root.size = res
		RoyalePage.pick = "classic"
		lobby._show_menu("royale")
		await _frames(3)
		var rect: Rect2 = lobby._sub_panel.get_global_rect()
		var secs: Array = lobby._sub.get_children().filter(func(c): return c is Label).map(func(l): return (l as Label).text)
		check("page %dx%d : Partie, Adversaires, Règles, Ligue royale, Carrière, Apparence" % [res.x, res.y],
			["Partie", "Adversaires", "Règles", "Carrière", "Apparence"].all(func(s): return s in secs) and secs.any(func(s): return String(s).begins_with("Ligue royale · Saison")))
		check("page %dx%d : largeur fixe (%.0f), dans l'écran" % [res.x, res.y, rect.size.x], absf(rect.size.x - float(lobby.PANEL_W)) < 12.0
			and rect.end.y <= float(res.y) + 0.5 and rect.end.x <= float(res.x))
		var go: Control = lobby._foot.get_child(lobby._foot.get_child_count() - 1)
		check("page %dx%d : « Lancer » épinglé et visible" % [res.x, res.y], go is Button and (go as Button).text.begins_with("Lancer") and go.get_global_rect().end.y <= float(res.y))
		var over := 0
		for c in _all_controls(lobby._sub):
			if c.is_visible_in_tree() and c.get_global_rect().end.x > rect.end.x + 1.0:
				over += 1
		check("page %dx%d : rien ne dépasse à droite (%d)" % [res.x, res.y, over], over == 0)
	# Du jour : la carte dit le modificateur du jour
	RoyalePage._set_pick(lobby, "daily")
	await _frames(2)
	var texts := _all_controls(lobby._sub).filter(func(c): return c is Label).map(func(l): return (l as Label).text)
	check("Du jour : %s, « Aujourd'hui »" % RoyaleMods.name_of(RoyaleMods.today_id()), RoyaleMods.name_of(RoyaleMods.today_id()) in texts and "Aujourd'hui" in texts)
	# Personnalisée : modificateur et graine
	RoyalePage._set_pick(lobby, "custom")
	await _frames(2)
	var ob: Array = _all_controls(lobby._sub).filter(func(c): return c is OptionButton)
	var le: Array = _all_controls(lobby._sub).filter(func(c): return c is LineEdit)
	check("Personnalisée : liste des modificateurs et graine", ob.size() == 1 and (ob[0] as OptionButton).item_count == 6 and le.size() == 1)
	RoyalePage._set_mod(2, lobby, [""] + RoyaleMods.ids())
	RoyalePage.seed_text = "1234"
	RoyalePage.apply()
	check("Personnalisée : Royale.mod, custom, graine posés", Royale.mod == RoyaleMods.ids()[1] and Royale.custom and Royale.custom_seed == 1234)
	RoyalePage.seed_text = "forêt"
	check("graine en mots : un nombre stable", RoyalePage.chosen_seed() > 0 and RoyalePage.chosen_seed() == RoyalePage.chosen_seed())
	var memo := RoyalePage.memo(3)
	RoyalePage.pick = "classic"
	RoyalePage.restore(memo)
	check("Continuer : la partie choisie revient", RoyalePage.pick == "custom" and int(memo.diff) == 3)
	RoyalePage.pick = "classic"
	RoyalePage.seed_text = ""
	RoyalePage.apply()
	check("Classique : aucun modificateur, partie classée", Royale.mod == "" and not Royale.custom and Royale.custom_seed == 0)
	RoyalePage._set_diff(lobby, 3)
	check("difficulté en pastilles", lobby._royale_diff == 3)
	get_tree().root.size = Vector2i(1600, 900)
	lobby.queue_free()
	await _frames(2)


func _all_controls(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Control:
			out.append(c)
		out.append_array(_all_controls(c))
	return out


# --- partie : autel, météores, fontaines, densité, aigle ----------------------------------------------
func _boot() -> RoyaleDirector:
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.mod = ""
	Royale.custom_seed = 0
	Royale.start("magician")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	var waited := 0.0
	while waited < 60.0 and not (world.get("director") != null and world.director.royale != null and world.director.royale.ais.size() == 7):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	await get_tree().create_timer(0.5).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	return world.director.royale


func _test_game() -> void:
	var rd: RoyaleDirector = await _boot()
	var p: Player = world.player
	check("partie montée, autel en attente, aucun gardien", rd.event != null and rd.event.state == "wait" and rd.event.guardian == null)
	# remercier l'aigle : à bord, une fois
	rd.jump.thank()
	rd.jump.thank()
	check("remercier l'aigle : une ligne au fil, une seule fois", rd.kill_feed.filter(func(f): return String(f[0]) == "Tu remercies l'aigle").size() == 1
		and not rd.jump.hint().contains("Merci"))
	rd.jump.land_all()
	await get_tree().physics_frame
	rd.phase = "fight"
	# 2e anneau : l'autel s'éveille
	rd.elapsed = 156.0
	rd.ring = Royale.ring_at(rd.elapsed, rd.centers)
	rd.update(0.01)
	var ev: RoyaleEvent = rd.event
	var g := ev.guardian
	check("2e anneau : l'autel s'éveille, gardien posé (%s)" % (String(g.cid) if g != null else "?"), ev.state == "awake" and g != null and is_instance_valid(g)
		and g.ffa_id == RoyaleEvent.GUARD_ID and g.has_meta("guardian"))
	check("le gardien ne compte pas parmi les héros (%d en vie)" % rd.alive_count(), rd.alive_count() == 8 and not rd.ais.has(g))
	var nc: Vector2 = rd.centers[RoyaleEvent.LEAVE_PHASE]
	var rad := float(Royale.PHASES[RoyaleEvent.LEAVE_PHASE - 1].radius)
	check("autel dans la zone sûre jusqu'au 4e anneau", Vector2(ev.pos.x, ev.pos.z).distance_to(nc) <= rad * 0.5 + 1.0)
	check("repère « altar » sur les cartes, objectif au HUD", rd.markers().any(func(m): return String(m[1]) == "altar") and ev.objective() != ""
		and rd.objective_lines().any(func(l): return String(l).contains("Autel")))
	check("gardien : plus de PV qu'un héros du niveau (%.0f), plaque" % g.max_hp, g.max_hp > GameData.player_max_hp(g.level) * 2.0 and g.get_node_or_null("RoyaleTag") != null)
	# zone gardée : un scripté proche devient sa cible ; personne : il revient à l'autel
	var a: ClassRival = rd.ais[0]
	a.global_position = ev.pos + Vector3(6, 0.5, 0)
	ev._guard(0.25)
	check("un héros dans la zone gardée : le gardien l'attaque", g._player == a and g.goal == Vector3.INF)
	a.global_position = ev.pos + Vector3(60, 0.5, 0)
	for b in rd.ais:
		if b != a:
			b.global_position = ev.pos + Vector3(-90, 0.5, 40)
	p.global_position = ev.pos + Vector3(0, 0.5, 80)
	g.hp = g.max_hp * 0.5
	ev._guard(1.0)
	check("personne dans la zone : il revient à l'autel et se remet", g.goal != Vector3.INF and g.hp > g.max_hp * 0.5)
	# scriptés : un fort y va, un faible non
	var st: Dictionary = a.get_meta("royale")
	st.lv = 20
	a.max_hp = g.max_hp
	a.hp = a.max_hp
	a.atk = g.atk * 2.0
	check("un scripté de taille, en forme, va à l'autel", ev.ai_goal(a, st) != Vector3.INF)
	a.hp = a.max_hp * 0.3
	check("... pas s'il est blessé", ev.ai_goal(a, st) == Vector3.INF)
	a.hp = a.max_hp
	a.atk = 1.0
	check("... ni s'il est bien trop faible", ev.ai_goal(a, st) == Vector3.INF)
	# le joueur l'achève : un niveau, le trésor sur place
	var lv0 := p.level
	var xp0 := p.xp
	g.hp = 1.0
	g.take_damage(1e9, p, false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("gardien vaincu par le joueur : niveau gagné, trésor de l'autel (largage)", ev.state == "won" and ev.player_won and (p.level > lv0 or p.xp > xp0)
		and ev.treasure != null and int(ev.treasure.get_meta("tier", 0)) == Royale.DROP_TIER and rd._chests.has(ev.treasure))
	check("défi « gardien », moment « Gardien » de la chronologie", int(Royale.stats.get("altar", 0)) == 1
		and (Royale.stats.timeline as Array).any(func(e): return String(e.kind) == "altar"))
	check("trésor à prendre : repère et objectif", ev.treasure_open() and not ev.marker().is_empty())
	# météores
	world.cards._queue.clear()
	world.cards._show_next()  # (le niveau gagné a ouvert un choix de carte : la partie est en pause)
	get_tree().paused = false
	Royale.mod = "meteors"
	var v: ClassRival = rd.ais[1]
	v.passive = true
	v.global_position = ev.pos + Vector3(30, 0.5, 30)
	await get_tree().physics_frame
	var read := false
	var tgs: Array = []
	for i in 6:
		var tg := rd.meteor_at(v.global_position)
		tg.global_position = Vector3(v.global_position.x, tg.global_position.y, v.global_position.z)
		tgs.append(tg)
		if rd._meteor_escape(v, 3) != Vector3.INF:
			read = true
	var out := rd._meteor_escape(v, 3)
	check("météore : zone fraise, le scripté qui la lit en sort", read and tgs.size() == 6 and (out == Vector3.INF or Vector2(out.x - v.global_position.x, out.z - v.global_position.z).length() > 2.0))
	var hp0 := v.hp
	var fell0 := int(rd.meteor_stats.hits)
	await get_tree().create_timer(RoyaleMods.METEOR_DELAY + 0.4).timeout
	check("impact : %d coup(s), PV %.0f -> %.0f (12 %% par météore)" % [int(rd.meteor_stats.hits) - fell0, hp0, v.hp], int(rd.meteor_stats.hits) > fell0 and v.hp < hp0
		and rd.env_cause(v) == "meteor")
	v.hp = 1.0
	v.take_damage(v.max_hp, null, false, true)
	await get_tree().physics_frame
	check("éliminé par un météore : ligne du fil", rd.kill_feed.any(func(f): return String(f[0]).contains("météore")))
	# sources de vie : un scripté blessé va boire
	Royale.mod = "wells"
	var w: ClassRival = rd.ais[2]
	var well: Interactable = null
	for it in world.director.map.interactables:
		if is_instance_valid(it) and it.kind == "well" and not it.used and not rd._outside(it.global_position, 0.85):
			well = it
			break
	if well != null:
		w.global_position = well.global_position + Vector3(10, 0.5, 0)
		w.hp = w.max_hp * 0.3
		var found := rd._well_for(w, Vector2(w.global_position.x, w.global_position.z))
		check("sources de vie : le scripté blessé vise une fontaine", found != null)
	Royale.mod = "hunt"
	check("chasse ouverte : les héros sur la carte", rd.markers().filter(func(m): return String(m[1]) == "hero").size() >= 3)
	Royale.mod = ""
	# densité : la ligne de mesure se calcule
	Royale.note_fight(p, rd.ais[3], rd.clock, 10.0)
	var dd := rd.density()
	check("densité : combats, temps mort, lieux, atterrissages, autel", int(dd.fights) >= 1 and float(dd.dead) >= 0.0 and float(dd.dead) <= 1.0
		and (dd.places as Array).size() == 4 and (dd.land as Array).size() == 4 and String(dd.altar.state) == "won")
	# le gardien s'en va au resserrement du 4e anneau (nouvelle partie de l'événement)
	ev.state = "awake"
	ev.treasure = null
	ev._spawn_guardian()
	rd.elapsed = 460.0
	rd.ring = Royale.ring_at(rd.elapsed, rd.centers)
	ev.update(0.3)
	check("4e anneau qui se resserre : le gardien s'en va, le trésor reste à prendre", ev.state == "gone" and ev.treasure_open())
	world.queue_free()
	await get_tree().create_timer(0.5).timeout
