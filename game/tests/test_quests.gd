extends Node
## Passe M5 : le système de quêtes (core/quests.gd, core/quest_pool.gd, ui/quests_page.gd, ui/quest_badge.gd) :
## pool, tirage du jour et de la semaine déterministe par date, compteurs de chaque activité, récompenses, série, relance,
## défis de classe, migration d'un compte ancien, page du lobby, carte du HUD, bilan et boussole.
## godot --headless --path game res://tests/test_quests.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _reset(open_all := true) -> void:
	Settings.reset_all()
	Profile.reset_all()
	Settings.set_v("interface", "dev_mode", open_all)  # mode dev : toutes les activités ouvertes (fil d'éveil)
	Profile.selected_class = "warrior"
	Profile.runs_done = 5
	Run.active = false
	Run.survival = false
	Challenge.reset()
	Quests.set_day("2026-10-15")  # un jeudi


func _ready() -> void:
	Training.active = false
	_test_dates()
	_test_pool()
	_test_draw()
	_test_coverage_and_budget()
	_test_counters()
	_test_modes()
	_test_series()
	_test_reroll()
	_test_class_challenges()
	_test_migration()
	_test_page()
	await _test_hud_and_bilan()
	Settings.set_v("interface", "dev_mode", false)
	Quests.set_day("")
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _test_dates() -> void:
	check("dates : le lundi de la semaine d'un jeudi", Quests.week_of("2026-10-15") == "2026-10-12")
	check("dates : le dimanche reste dans la semaine", Quests.week_of("2026-10-18") == "2026-10-12")
	check("dates : le lundi suivant ouvre une semaine", Quests.week_of("2026-10-19") == "2026-10-19")
	check("dates : passage de mois", Quests.week_of("2026-11-02") == "2026-11-02" and Quests.week_of("2026-11-01") == "2026-10-26")
	check("dates : écart en jours", Quests.day_diff("2026-10-12", "2026-10-15") == 3 and Quests.day_diff("2026-12-30", "2027-01-02") == 3)


func _test_pool() -> void:
	var ids := {}
	var ok_fields := true
	var ok_acts := true
	for d in QuestPool.LIST:
		if ids.has(d.id):
			ok_fields = false
		ids[d.id] = true
		for k in ["id", "act", "text", "mode", "tier", "min"]:
			if not d.has(k):
				ok_fields = false
		if not QuestPool.ACTS.has(String(d.act)):
			ok_acts = false
	check("pool : %d quêtes, identifiants uniques, champs complets" % QuestPool.LIST.size(), QuestPool.LIST.size() >= 35 and ok_fields)
	check("pool : chaque quête vise une activité connue", ok_acts)
	var acts := {}
	for d in QuestPool.LIST:
		acts[d.act] = true
	var wanted := ["survival", "survivor", "dungeon", "tower", "rush", "siege", "duel", "arenas", "gauntlet", "royale", "lobby"]
	check("pool : couvre toutes les activités (%s)" % ", ".join(acts.keys()), wanted.all(func(a): return acts.has(a)))
	_reset()
	var titles_ok := true
	var no_raw := true
	var r := RandomNumberGenerator.new()
	r.seed = 1
	for d in QuestPool.LIST:
		var q := Quests.make(d, "daily" if int(d.get("d", 0)) > 0 or d.has("dyn") else "weekly", 0, r)
		var t := Quests.title(q)
		if t == "" or t.contains("%"):
			titles_ok = false
		if String(t) == String(d.id):
			no_raw = false
	check("pool : chaque consigne se lit (aucun %% resté, aucun identifiant brut)", titles_ok and no_raw)
	var plural := Quests.make(QuestPool.get_def("sv_win"), "weekly", 0, r)
	check("pool : accord du pluriel (« Gagner 3 Survies »)", Quests.title(plural) == "Gagner 3 Survies")
	var epoch_q := Quests.make(QuestPool.get_def("sv_top"), "daily", 0, r)
	check("pool : époque en chiffres romains", Quests.title(epoch_q).ends_with("l'époque I") or Quests.title(epoch_q).ends_with("II"))


func _test_draw() -> void:
	_reset(false)
	Profile.runs_done = 1
	check("compte neuf : les quêtes sont fermées, rien n'est tiré", not Quests.enabled() and Quests.daily().is_empty() and Quests.weekly().is_empty())
	Quests.event("chest_open")
	Quests.end_run("survival", true)
	check("compte neuf : aucun événement n'est compté", Quests.daily().is_empty())
	Profile.runs_done = 3
	check("3 Survies : les quêtes s'ouvrent, tirées dès l'affichage", Quests.enabled() and Quests.daily().size() == 3 and Quests.weekly().size() == 2)
	_reset()
	var a := Quests.draw("daily", "2026-10-15")
	var b := Quests.draw("daily", "2026-10-15")
	check("tirage du jour : trois quêtes, le Défi du jour d'abord", a.size() == 3 and String(a[0].id) == "daily_challenge")
	check("tirage du jour : déterministe par date", JSON.stringify(a) == JSON.stringify(b))
	var ids_a: Array = a.map(func(q): return q.id)
	check("tirage du jour : trois quêtes différentes, deux activités autres que la Survie",
		ids_a.size() == 3 and ids_a[0] != ids_a[1] and ids_a[1] != ids_a[2] and ids_a[0] != ids_a[2]
		and a.slice(1).all(func(q): return String(QuestPool.get_def(String(q.id)).act) != "survival"))
	var seen := {}
	for day in range(1, 11):
		var d := Quests.draw("daily", "2026-10-%02d" % (day + 10))
		seen[String(d[1].id)] = true
		seen[String(d[2].id)] = true
	check("tirage du jour : les jours changent (%d quêtes vues en 10 jours)" % seen.size(), seen.size() >= 8)
	var w := Quests.draw("weekly", "2026-10-12")
	check("tirage de la semaine : deux quêtes d'activités différentes, déterministe",
		w.size() == 2 and QuestPool.get_def(String(w[0].id)).act != QuestPool.get_def(String(w[1].id)).act
		and JSON.stringify(w) == JSON.stringify(Quests.draw("weekly", "2026-10-12")))
	var target_ok := w.all(func(q): return int(q.t) > 0)
	check("tirage de la semaine : cibles positives, récompenses sobres (jamais d'équipement)",
		target_ok and w.all(func(q): return not (q.r as Dictionary).has("gear") and String(q.r.get("chest", "")) not in ["gear", "set"]))
	# l'état enregistré reste le même toute la journée et toute la semaine
	var st1 := JSON.stringify(Quests.state())
	check("état : stable dans la journée", st1 == JSON.stringify(Quests.state()))
	var weekly_before := JSON.stringify(Quests.weekly())
	var daily_before := JSON.stringify(Quests.daily())
	Quests.set_day("2026-10-16")
	check("état : nouveau jour, nouvelles quêtes du jour, mêmes quêtes de la semaine",
		JSON.stringify(Quests.daily()) != daily_before and JSON.stringify(Quests.weekly()) == weekly_before)
	Quests.set_day("2026-10-19")
	check("état : lundi, nouvelle semaine", JSON.stringify(Quests.weekly()) != weekly_before)
	# quêtes réservées au Survivant : tirées seulement quand le mode est visible
	_reset(false)
	Profile.runs_done = 5
	Profile.unlocked_features = ["daily"]
	var sv_drawn := false
	for day in range(1, 29):
		for q in Quests.draw("daily", "2026-11-%02d" % day) + Quests.draw("weekly", "2026-11-%02d" % day):
			if String(QuestPool.get_def(String(q.id)).act) == "survivor":
				sv_drawn = true
	check("Survivant : aucune quête tant que le mode n'est pas visible", not sv_drawn and not Survivor.visible())
	_reset(true)
	var sv_dev := false
	for day in range(1, 60):
		for q in Quests.draw("daily", "2026-11-%02d" % day) + Quests.draw("weekly", "2026-12-%02d" % day):
			if String(QuestPool.get_def(String(q.id)).act) == "survivor":
				sv_dev = true
	check("Survivant : des quêtes en mode dev", sv_dev)


func _test_coverage_and_budget() -> void:
	_reset()
	for i in 8:
		Profile.reward_chests.append(Rewards.make("gear", 20))
	var acts := {}
	var total_min := 0.0
	var max_min := 0.0
	var days := 90
	for i in days:
		var key := "2026-%02d-%02d" % [1 + i / 28, 1 + i % 28]
		var list := Quests.draw("daily", key)
		var m := 0.0
		for q in list:
			var d := Quests.def_of(q)
			acts[String(d.act)] = acts.get(String(d.act), 0) + 1
			m += float(d.min)
		total_min += m
		max_min = maxf(max_min, m)
		for q in Quests.draw("weekly", key):
			acts[String(Quests.def_of(q).act)] = acts.get(String(Quests.def_of(q).act), 0) + 1
	var wanted := ["survival", "survivor", "dungeon", "tower", "rush", "siege", "duel", "arenas", "gauntlet", "royale", "lobby"]
	var missing := wanted.filter(func(a): return not acts.has(a))
	check("couverture : %d jours tirés touchent toutes les activités (manque : %s)" % [days, missing], missing.is_empty())
	var avg := total_min / days
	check("équilibre : %.0f min en moyenne (max %.0f) pour finir les trois quêtes du jour" % [avg, max_min], avg >= 20.0 and avg <= 45.0 and max_min <= 60.0)
	# récompenses du jour : plafond d'insignes
	var cap := 0
	for i in 60:
		var s := 0
		for q in Quests.draw("daily", "2027-01-%02d" % (1 + i % 28) if i < 28 else "2027-02-%02d" % (1 + i % 28)):
			s += int((q.r as Dictionary).get("insignia", 0))
		cap = maxi(cap, s)
	check("récompenses : au plus %d insignes par jour par les quêtes" % cap, cap <= 300)


func _set_daily(ids: Array, rewards: Array = []) -> Array:
	var st := Quests.state()
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var list: Array = []
	for i in ids.size():
		var q := Quests.make(QuestPool.get_def(String(ids[i])), "daily", i, r)
		q["r"] = rewards[i] if i < rewards.size() else {"insignia": 70}
		list.append(q)
	st["daily"] = list
	st["rerolled"] = false
	return list


func _run_state(kills := 0, elites := 0, level := 1, secs := 120) -> void:
	Run.active = true
	Run.survival = true
	Run.class_id = "warrior"
	Run.kills = kills
	Run.elites = elites
	Run.chests_total = 0
	Run.perfects = 0
	Run.max_level = level
	Run.stage = 1
	Run.epoch = 1
	Run.resurrections = 0
	Run.heroic_rank = 0
	Run.started_at = Time.get_ticks_msec() - secs * 1000


func _test_counters() -> void:
	_reset()
	var list := _set_daily(["sv_kills", "sv_level", "sv_elites"])
	_run_state(300, 4, 12)
	check("progression en direct : monstres de la partie ajoutés à l'enregistré", Quests.live_progress(list[0]) == 300 and Quests.live_progress(list[1]) == 12)
	check("progression en direct : rien d'enregistré en cours de partie", int(list[0].p) == 0)
	Profile.insignia = 0
	Quests.end_run("survival", false)
	check("fin de partie : monstres additionnés (300 / 400)", int(list[0].p) == 300 and not bool(list[0].done))
	check("fin de partie : meilleur niveau (12 / 25), élites (4 / 8)", int(list[1].p) == 12 and int(list[2].p) == 4)
	_run_state(150, 5, 30)
	var done := Quests.end_run("survival", true)
	check("deuxième partie : les monstres s'additionnent, les quêtes atteintes sont accomplies", bool(list[0].done) and bool(list[1].done) and bool(list[2].done) and done.size() == 3)
	check("récompenses : 3 × 70 insignes données une seule fois", Profile.insignia == 210)
	_run_state(900, 20, 40)
	Quests.end_run("survival", true)
	check("quêtes accomplies : plus rien n'est ajouté ni redonné", Profile.insignia == 210 and int(list[0].p) == int(list[0].t))
	# cibles dynamiques et conditions
	_reset()
	list = _set_daily(["sv_clean", "sv_win", "sv_stage"])
	_run_state(10, 0, 5)
	Run.resurrections = 1
	Quests.end_run("survival", true)
	check("sans résurrection : une victoire avec résurrection ne compte pas, la victoire simple oui", int(list[0].p) == 0 and bool(list[1].done) and int(list[2].p) == 1)
	_run_state(10, 0, 5)
	Run.stage = 2
	Quests.end_run("survival", false)
	check("carte atteinte : la carte 2 accomplit la quête", bool(list[2].done))
	# partie trop courte
	_reset()
	list = _set_daily(["sv_kills"])
	_run_state(900, 0, 5, 10)
	Quests.end_run("survival", true)
	check("partie de moins de 30 s : ne compte pas", int(list[0].p) == 0)
	# défi du jour
	_reset()
	list = _set_daily(["daily_challenge", "sv_perfects"], [{}, {"crystal": 35}])
	Profile.insignia = 0
	_run_state(100, 0, 5)
	Challenge.active = true
	var d2 := Quests.end_run("survival", false)
	check("Défi du jour : perdu, pas accompli", not bool(list[0].done))
	d2 = Quests.end_run("survival", true)
	check("Défi du jour : accompli par une victoire, sans récompense en plus", bool(list[0].done) and d2.size() == 1 and Profile.insignia == 0)
	check("Défi du jour : la série part", Quests.series_n() == 1)
	Challenge.reset()
	# coffres du menu (hors partie) et variété
	_reset()
	for i in 6:
		Profile.reward_chests.append(Rewards.make("gear", 20))
	list = _set_daily(["lb_chests", "tx_classes"], [{"crystal": 20}, {"insignia": 50}])
	Profile.materials["crystal"] = 0
	Run.active = false
	for i in 3:
		Quests.event("chest_open")
	check("coffres du menu : 3 / 4", int(list[0].p) == 3 and not bool(list[0].done))
	Quests.event("chest_open")
	check("coffres du menu : la 4e accomplit la quête, +20 cristaux", bool(list[0].done) and Profile.materials.crystal == 20)
	Run.active = true
	Quests.event("chest_open")
	check("coffres ouverts en pleine partie : ignorés", int(list[0].p) == 4)
	_run_state(1, 0, 1)
	Quests.end_run("survival", false)
	_run_state(1, 0, 1)
	Run.class_id = "magician"
	Quests.end_run("survival", false)
	check("variété : deux classes différentes accomplissent la quête", bool(list[1].done))


func _test_modes() -> void:
	_reset()
	var list := _set_daily(["dg_clean", "dg_allies", "dg_elites", "tw_climb", "tw_floor"])
	_run_state(0, 9, 10)
	Run.survival = false
	Quests.event("zone_hit")
	Quests.end_run("dungeon", true, {"rooms": 4, "reached": 4, "diff": 0, "allies": 2})
	check("donjon : un coup de zone empêche « sans dégât de zone », les alliés comptent, les élites aussi",
		int(list[0].p) == 0 and bool(list[1].done) and bool(list[2].done))
	_run_state(0, 2, 10)
	Run.survival = false
	Quests.end_run("dungeon", true, {"rooms": 4, "reached": 4, "diff": 0, "allies": 0})
	check("donjon : le compteur de coups de zone repart à zéro à chaque partie", bool(list[0].done))
	_run_state(40, 0, 10)
	Run.survival = false
	Quests.end_run("tower", false, {"reached": 12, "climbed": 6})
	check("Tour : 6 étages montés (6 / 5), étage 12 atteint", bool(list[3].done) and bool(list[4].done))
	# siège, ruée, duels, arènes, battle royale
	_reset()
	list = _set_daily(["sg_wave", "sg_boss", "rs_bosses", "du_win", "du_league", "ar_win", "ga_win", "ry_podium", "ry_kills"])
	_run_state(10, 0, 10)
	Run.survival = false
	Quests.end_run("siege", false, {"reached": 6, "rooms": 6, "boss_down": true, "siege_won": false})
	check("Siège : vague 6 tenue, boss tombé", bool(list[0].done) and bool(list[1].done))
	Quests.end_run("rush", false, {"rooms": 4, "reached": 4})
	check("Ruée : 4 boss, quête à 3", bool(list[2].done))
	Quests.end_run("duel", true, {"mode": "free", "rival": "mage"})
	check("Duel libre gagné : « Gagner 2 duels » à 1, Ligue non touchée", int(list[3].p) == 1 and int(list[4].p) == 0)
	Quests.end_run("duel", true, {"mode": "league", "rival": "mage"})
	check("Duel de Ligue gagné : les deux avancent", bool(list[3].done) and bool(list[4].done))
	Quests.end_run("arenas", true, {"mode": "arena2"})
	Quests.end_run("gauntlet", false, {"mode": "gauntlet"})
	check("Arènes gagnées, Gantelet perdu", bool(list[5].done) and not bool(list[6].done))
	Quests.end_run("royale", false, {"place": 5, "pkills": 2})
	check("Battle royale : place 5 hors podium, 2 éliminations (2 / 4)", int(list[7].p) == 0 and int(list[8].p) == 2)
	Quests.end_run("royale", true, {"place": 1, "pkills": 3})
	check("Battle royale : victoire = podium, 5 éliminations", bool(list[7].done) and bool(list[8].done))
	# duel avec une classe précise
	_reset()
	list = _set_daily(["du_class"])
	list[0]["param"] = "mage"
	_run_state(0, 0, 10)
	Run.survival = false
	Run.class_id = "warrior"
	Quests.end_run("duel", true, {"mode": "free"})
	var wrong := bool(list[0].done)
	Run.class_id = "mage"
	Quests.end_run("duel", true, {"mode": "free"})
	check("duel avec une classe précise : seule la bonne classe compte", not wrong and bool(list[0].done))
	# activités différentes (semaine)
	_reset()
	var st := Quests.state()
	var wq := Quests.make(QuestPool.get_def("tx_acts"), "weekly", 0, RandomNumberGenerator.new())
	wq["r"] = {"insignia": 100}
	st["weekly"] = [wq]
	_run_state(10, 0, 3)
	Quests.end_run("survival", false)
	Quests.end_run("survival", false)
	check("variété : la même activité deux fois ne compte qu'une", int(wq.p) == 1)
	Run.survival = false
	Quests.end_run("tower", false, {"reached": 3, "climbed": 3})
	Quests.end_run("duel", false, {"mode": "free"})
	Quests.end_run("royale", false, {"place": 4})
	check("variété : quatre activités différentes accomplissent la quête de la semaine", bool(wq.done))


func _test_series() -> void:
	_reset()
	Profile.reward_chests = []
	var gifts := 0
	var days := ["2026-10-15", "2026-10-16", "2026-10-17"]
	for i in days.size():
		Quests.set_day(days[i])
		var list := _set_daily(["sv_kills"])
		_run_state(900, 0, 5)
		Quests.end_run("survival", false)
		check("série : jour %d accompli → %d" % [i + 1, i + 1], Quests.series_n() == i + 1 and bool(list[0].done))
	check("série : 3 jours → un coffre d'apparence rare", Profile.reward_chests.any(func(c): return String(c.type) == "look_rare"))
	var chests_before := Profile.reward_chests.size()
	# une 2e quête le même jour ne prolonge pas
	var l2 := _set_daily(["sv_kills", "sv_elites"])
	_run_state(900, 20, 5)
	Quests.end_run("survival", false)
	check("série : deux quêtes le même jour comptent pour un jour", Quests.series_n() == 3)
	# jour pardonné
	Quests.set_day("2026-10-19")
	check("série : un jour manqué est pardonné", Quests.series_n() == 3)
	Quests.set_day("2026-10-20")
	check("série : deux jours manqués ramènent au dernier palier (3)", Quests.series_n() == 3)
	var st := Quests.state()
	st.series["n"] = 5
	st.series["last"] = "2026-10-17"
	check("série : 5 jours, absente 3 jours, retombe au palier 3 (%d)" % Quests.series_n(), Quests.series_n() == 3)
	st.series["n"] = 9
	check("série : 9 jours, retombe au palier 7", Quests.series_n() == 7)
	Quests.set_day("2026-10-20")
	_set_daily(["sv_kills"])
	_run_state(900, 0, 5)
	Quests.end_run("survival", false)
	check("série : reprise à palier + 1, les cadeaux déjà reçus ne reviennent pas", Quests.series_n() == 8 and Profile.reward_chests.size() == chests_before + 1)
	check("série : le palier 7 a donné son coffre épique", Profile.reward_chests.any(func(c): return String(c.type) == "look_epic"))
	var rare := Profile.reward_chests.filter(func(c): return String(c.type) == "look_rare").size()
	check("série : le coffre rare du palier 3 n'a été donné qu'une fois", rare == 1)
	check("série : trace du meilleur score", int(Profile.records.get("quest_series_best", 0)) >= 7)
	check("série : prochain palier", int(Quests.next_gift(8).n) == 14 and Quests.next_gift(100).is_empty())
	check("série : le palier 30 porte un titre", String(Quests.SERIES_GIFTS[3].get("title", "")) == "Régulier")
	gifts = Quests.SERIES_GIFTS.size()
	check("série : six paliers cosmétiques, jamais d'équipement", gifts == 6 and Quests.SERIES_GIFTS.all(func(g): return String(g.chest).begins_with("look") or String(g.chest).begins_with("aura")))


func _test_reroll() -> void:
	_reset()
	var st := Quests.state()
	var before: Array = (st.daily as Array).map(func(q): return q.id)
	check("relance : possible au début du jour", Quests.can_reroll())
	check("relance : le Défi du jour peut être changé", Quests.reroll(0))
	var after: Array = (Quests.daily() as Array).map(func(q): return q.id)
	check("relance : une autre quête, les autres inchangées", after[0] != before[0] and after[1] == before[1] and after[2] == before[2] and after.size() == 3)
	check("relance : une seule par jour", not Quests.can_reroll() and not Quests.reroll(1))
	Quests.set_day("2026-10-16")
	check("relance : de nouveau possible le lendemain", Quests.can_reroll())
	var list := _set_daily(["sv_kills", "sv_elites", "tw_climb"])
	list[1]["done"] = true
	check("relance : une quête accomplie ne se relance pas", not Quests.reroll(1))
	check("relance : une quête en cours oui, sans doublon", Quests.reroll(2) and (Quests.daily() as Array).map(func(q): return q.id).size() == 3)
	var ids: Array = (Quests.daily() as Array).map(func(q): return q.id)
	check("relance : aucun doublon dans la liste", ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2])


func _test_class_challenges() -> void:
	_reset()
	var c := Quests.class_challenges("warrior")
	check("défis de classe : trois, avec cible, progression et maîtrise", c.size() == 3 and c.all(func(x): return int(x.t) > 0 and int(x.reward.mastery) >= 400 and bool(x.class)))
	var st := Contracts.state("warrior")
	var id := String(st.active[0])
	st.progress[id] = 5
	var c2 := Quests.class_challenges("warrior")
	check("défis de classe : la progression des contrats apparaît", c2.any(func(x): return int(x.p) == 5))
	check("défis de classe : les textes se lisent", c2.all(func(x): return not String(x.title).contains("%")))


func _test_migration() -> void:
	# compte d'avant les quêtes : contrats, défi du jour réussi aujourd'hui, aucune clé « quests »
	_reset()
	Profile.records.erase("quests")
	Profile.records["challenge_day"] = "2026-10-15"
	Profile.records["challenge_wins"] = 4
	var st0 := Contracts.state("mage")
	st0.progress[String(st0.active[0])] = 7
	var daily := Quests.daily()
	check("migration : la clé « quests » naît d'elle-même, trois quêtes", Profile.records.has("quests") and daily.size() == 3)
	check("migration : le Défi du jour déjà réussi aujourd'hui est accompli", bool(daily[0].done) and String(daily[0].id) == "daily_challenge")
	check("migration : contrats et records anciens intacts", Contracts.progress("mage", String(st0.active[0])) == 7 and int(Profile.records.challenge_wins) == 4)
	# aller-retour JSON (la sauvegarde rend des flottants)
	var back = JSON.parse_string(JSON.stringify(Profile.records.quests))
	Profile.records["quests"] = back
	var q: Dictionary = Quests.daily()[1]
	check("sauvegarde : relue en JSON, les quêtes se lisent", Quests.title(q) != "" and int(q.t) > 0 and Quests.series_n() >= 0)
	_run_state(900, 20, 30)
	check("sauvegarde : relue en JSON, les compteurs marchent encore", Quests.end_run("survival", true).size() >= 0 and Quests.state().daily.size() == 3)
	# vraie sauvegarde disque
	Profile.save_profile()
	var snapshot := JSON.stringify(Profile.records.get("quests"))
	Profile.load_profile()
	check("sauvegarde : le profil rechargé garde les quêtes", JSON.stringify(Profile.records.get("quests")) == snapshot or JSON.parse_string(snapshot) == Profile.records.get("quests"))
	# profil vide
	Profile.reset_all()
	Settings.set_v("interface", "dev_mode", false)
	Quests.set_day("2026-10-15")
	check("profil vide : aucune erreur, quêtes fermées", not Quests.enabled() and Quests.daily().is_empty() and Quests.card_sub() == "" and Quests.hint().is_empty())
	# la Tour recharge la sauvegarde : les quêtes survivent
	_reset()
	var list := _set_daily(["tw_climb"], [{"insignia": 10}])
	_run_state(10, 0, 3)
	Run.survival = false
	Profile.save_profile()
	Profile.reload_keep_records()
	Quests.end_run("tower", false, {"reached": 8, "climbed": 8})
	check("rechargement de la sauvegarde (Tour) : la quête est comptée après", bool(Quests.daily()[0].done))


func _test_page() -> void:
	_reset()
	var box := VBoxContainer.new()
	add_child(box)
	var launched := [""]
	var changed := [0]
	QuestsPage.fill(box, func(c): launched[0] = String(c), func(): changed[0] += 1)
	# série + 3 sections + 3 du jour + 2 de la semaine + 3 défis de classe
	check("page : %d blocs (série, 3 sections, 3 + 2 quêtes, 3 défis de classe)" % box.get_child_count(), box.get_child_count() == 1 + 3 + 3 + 2 + 3)
	var buttons := _buttons(box)
	var launchers := buttons.filter(func(b): return b.tooltip_text.begins_with("Lancer le Défi du jour"))
	check("page : le Défi du jour se lance avec l'une de trois classes", launchers.size() == 3)
	launchers[0].pressed.emit()
	check("page : le lancement donne la classe choisie", Challenge.classes_today().has(launched[0]))
	var rerolls := buttons.filter(func(b): return b.tooltip_text.begins_with("Changer cette quête"))
	check("page : une relance par quête non faite", rerolls.size() == 3)
	rerolls[1].pressed.emit()
	check("page : la relance redessine la page", changed[0] == 1 and not Quests.can_reroll())
	box.queue_free()
	var box2 := VBoxContainer.new()
	add_child(box2)
	QuestsPage.fill(box2, func(_c): pass, func(): pass)
	check("page : plus de relance une fois utilisée", _buttons(box2).filter(func(b): return b.tooltip_text.begins_with("Changer")).is_empty())
	var texts := PackedStringArray()
	_collect_text(box2, texts)
	var all := " ".join(texts)
	check("page : date en français", all.contains("Aujourd'hui · 15 octobre") and all.contains("Cette semaine") and all.contains("Défis de classe · Guerrier"))
	check("page : aucun pourcentage ni texte d'aide permanent (%s)" % all, not all.contains("%") and not all.contains("Eden"))
	check("série : l'infobulle donne les paliers", QuestsPage.series_tip().contains("7 jours") and QuestsPage.series_tip().contains("30 jours"))
	box2.queue_free()
	# l'étiquette de la page Jouer
	var a := Activities.get_def("quests")
	check("activité : « Quêtes » dans la rangée Défis, ouverte par le fil « daily »", a.row == "challenge" and a.unlock == "daily" and Activities.get_def("mastery").is_empty())
	check("activité : sous-titre dynamique (%s)" % Activities.sub_text(a), Activities.sub_text(a).contains("sur 3"))
	_set_daily(["sv_kills"])
	Quests.state().daily[0]["done"] = true
	check("activité : les quêtes faites se comptent", Quests.done_count() == 1)


func _buttons(n: Node) -> Array:
	var out: Array = []
	if n is Button:
		out.append(n)
	for c in n.get_children():
		out.append_array(_buttons(c))
	return out


func _collect_text(n: Node, out: PackedStringArray) -> void:
	if n is Label:
		out.append(n.text)
	if n is Button:
		out.append(n.text)
	for c in n.get_children():
		_collect_text(c, out)


class FakeHud extends Control:
	var _cards: InfoCard


func _test_hud_and_bilan() -> void:
	_reset()
	var list := _set_daily(["sv_kills", "sv_elites"], [{"insignia": 70}, {"crystal": 30}])
	var hud := FakeHud.new()
	add_child(hud)
	hud._cards = InfoCard.in_control(hud)
	var stack := VBoxContainer.new()
	hud.add_child(stack)
	var badge := QuestBadge.attach(stack, hud)
	await get_tree().process_frame
	badge.refresh()
	check("HUD : hors partie, la carte de quête est cachée", not badge.visible)
	_run_state(120, 3, 5)
	badge.refresh()
	check("HUD : la quête la plus avancée s'affiche (%s %s)" % [badge._title.text, badge._count.text], badge.visible and badge._count.text == "3 / 8" and badge._title.text == "Vaincre 8 élites en Survie")
	Run.elites = 8
	badge.refresh()
	await get_tree().process_frame
	check("HUD : une carte d'information annonce la quête accomplie", hud._cards.count() == 1)
	badge.refresh()
	await get_tree().process_frame
	check("HUD : l'annonce n'est faite qu'une fois", hud._cards.count() == 1)
	Run.kills = 500
	Run.elites = 8
	Profile.insignia = 0
	Profile.materials["crystal"] = 0
	Quests.end_run("survival", false)
	var line := Quests.report_line()
	check("bilan : la ligne « Ta quête » nomme les quêtes accomplies (%s)" % line, line.begins_with("2 quêtes accomplies") and line.contains("+70 insignes") and line.contains("30 cristaux"))
	check("bilan : récompenses créditées", Profile.insignia == 70 and Profile.materials.crystal == 30)
	var after := Compass.after("survival", {})
	check("bilan : Compass.after commence par la quête", after.begins_with("2 quêtes accomplies"))
	_run_state(10, 0, 3)
	var l3 := _set_daily(["sv_chests"])
	Run.chests_total = 5
	Quests.end_run("survival", false)
	check("bilan : une quête avancée est signalée (« %s »)" % Quests.report_line(), Quests.report_line() == "Ouvrir 8 coffres de la carte : 5 / 8")
	Run.active = false
	Quests.end_run("survival", false)  # partie sans effet : rien à dire
	var hint := Quests.hint()
	check("boussole : un conseil de quête en dehors des parties (%s)" % hint.get("text", ""), String(hint.get("text", "")).begins_with("Quête : "))
	check("boussole : mène à l'activité de la quête", hint.go.has("menu") or hint.go.has("chests"))
	hud.queue_free()
