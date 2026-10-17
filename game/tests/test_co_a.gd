extends Node
## Lot CO-A : socle du Colisée (core/colisee.gd, rapport conception/benchmark/R_CO_A.md). Machine de partie « au tableau »
## (1 000 parties Classique, 1 000 Éclair, 300 Grand tournoi, sans scène) : fin garantie, places uniques, pas deux fois le même
## adversaire avant d'avoir vu tous les autres, exempt, barème, égalités, éliminations simultanées ; trios ; lancement du mode
## (TeamMatch, règles « colisee », scellé, JcJ, jamais Duel.active ni Royale.active) ; textes du menu pause.
## godot --headless --path game res://tests/test_co_a.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_rules()
	_pairing_rule()
	_mass("classique", 1000, 12)
	_mass("eclair", 1000, 8)
	_mass("grand", 300, 13)
	_ties_and_simultaneous()
	_teams()
	_game_start()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _rules() -> void:
	check("barème Classique : 20 / 25 / 35 / 50 / 100", Colisee.loss_for(Colisee.LOSS_CLASSIC, 1) == 20 and Colisee.loss_for(Colisee.LOSS_CLASSIC, 3) == 20
		and Colisee.loss_for(Colisee.LOSS_CLASSIC, 4) == 25 and Colisee.loss_for(Colisee.LOSS_CLASSIC, 7) == 35
		and Colisee.loss_for(Colisee.LOSS_CLASSIC, 10) == 50 and Colisee.loss_for(Colisee.LOSS_CLASSIC, 12) == 100
		and Colisee.loss_for(Colisee.LOSS_CLASSIC, 40) == 100)
	check("barème Éclair : 25 / 35 / 50 / 100", Colisee.loss_for(Colisee.LOSS_FAST, 2) == 25 and Colisee.loss_for(Colisee.LOSS_FAST, 3) == 35
		and Colisee.loss_for(Colisee.LOSS_FAST, 6) == 50 and Colisee.loss_for(Colisee.LOSS_FAST, 7) == 100)
	check("mort subite : manche 12 (Classique), 7 (Éclair)", Colisee.new("classique", 1).sudden_round() == 12
		and Colisee.new("eclair", 1).sudden_round() == 7)
	check("formats : 6, 4 et 8 équipes ; Grand tournoi ouvert (sonde du lot CO-C)", Colisee.new("classique", 1).n == 6
		and Colisee.new("eclair", 1).n == 4 and Colisee.new("grand", 1).n == 8 and not bool(Colisee.FORMATS.grand.get("locked", false)))
	check("profil de règles : pas d'acharnement ni de mort subite, coup plafonné", float(Colisee.PROFILE.pressure_start) > 1000.0
		and float(Colisee.PROFILE.sudden_after) > 1000.0 and is_equal_approx(float(Colisee.PROFILE.hit_cap), 0.15))


## Combat [a, b] qui revoit trop tôt une équipe (l'un des deux n'a pas encore vu une équipe en lice moins souvent).
func _early(seen: Array, al: Array, a: int, b: int) -> bool:
	for x in [[a, b], [b, a]]:
		var lo := 1 << 30
		for c in al:
			if c != x[0]:
				lo = mini(lo, int(seen[x[0]][c]))
		if int(seen[x[0]][x[1]]) > lo:
			return true
	return false


func _all_matchings(ids: Array) -> Array:
	if ids.is_empty():
		return [[]]
	var outl: Array = []
	for j in range(1, ids.size()):
		var rest := ids.slice(1)
		rest.erase(ids[j])
		for m in _all_matchings(rest):
			outl.append([[ids[0], ids[j]]] + m)
	return outl


## Vérification indépendante de la règle d'appariement, relue dans l'historique d'une partie : à chaque manche, le nombre de
## combats qui revoient trop tôt une équipe doit être le plus petit possible (recherche exhaustive, même règle d'exempt :
## l'une des équipes les moins exemptées) ; 0 tant que c'est possible (tours complets, test plus haut). Rend {bad (écart au
## minimum), unavoidable (revoir trop tôt était inévitable), bye_twice}.
func _check_history(g: Colisee) -> Dictionary:
	var seen: Array = []
	for t in g.n:
		var row: Array = []
		row.resize(g.n)
		row.fill(0)
		seen.append(row)
	var byes: Array = []
	byes.resize(g.n)
	byes.fill(0)
	var out := {}
	var bad := 0
	var unavoidable := 0
	var bye_twice := 0
	var last_bye := -1
	for h in g.history:
		var al: Array = []
		for t in g.n:
			if not out.has(t):
				al.append(t)
		var in_round := {}
		var viol := 0
		for p in h.pairs:
			var a := int(p[0])
			var b := int(p[1])
			in_round[a] = true
			in_round[b] = true
			if _early(seen, al, a, b):
				viol += 1
		var best := 1 << 30
		var opts: Array = [-1]
		if al.size() % 2 == 1:
			var least := 1 << 30
			for t in al:
				least = mini(least, int(byes[t]))
			opts = al.filter(func(t): return int(byes[t]) == least)
		for bye in opts:
			for m in _all_matchings(al.filter(func(t): return t != bye)):
				var v := 0
				for p in m:
					if _early(seen, al, int(p[0]), int(p[1])):
						v += 1
				best = mini(best, v)
		bad += maxi(0, viol - best)
		unavoidable += best
		if int(h.bye) >= 0:
			byes[int(h.bye)] += 1
		var exp_bye := 1 if al.size() % 2 == 1 else 0
		if in_round.size() != al.size() - exp_bye or (exp_bye == 1) != (int(h.bye) >= 0):
			bad += 100  # une équipe en lice sans combat ni exemption, ou un exempt de trop
		if int(h.bye) >= 0 and int(h.bye) == last_bye and al.size() > 1:
			bye_twice += 1
		last_bye = int(h.bye)
		for p in h.pairs:
			seen[p[0]][p[1]] += 1
			seen[p[1]][p[0]] += 1
		for e in h.eliminated:
			out[int(e[0])] = true
	return {"bad": bad, "unavoidable": unavoidable, "bye_twice": bye_twice}


func _pairing_rule() -> void:
	# 6 équipes sans élimination : 5 manches = un tour complet, chacune voit les 5 autres une fois
	var g := Colisee.new("classique", 77)
	var all_once := true
	for r in 5:
		var pr := g.next_round()
		var res: Array = []
		for p in pr.pairs:
			res.append({"a": p[0], "b": p[1], "winner": p[0]})
		g.hp.fill(Colisee.TEAM_HP)  # (personne n'est éliminé pendant ce tour)
		g.report(res)
		g.hp.fill(Colisee.TEAM_HP)
	for a in 6:
		for b in 6:
			if a != b and int(g.met[a][b]) != 1:
				all_once = false
	check("6 équipes, 5 manches : chacune a vu les 5 autres une fois (tour complet)", all_once and g.rematch_violations == 0)
	# 8 équipes, 7 manches
	g = Colisee.new("grand", 91)
	for r in 7:
		var pr := g.next_round()
		var res: Array = []
		for p in pr.pairs:
			res.append({"a": p[0], "b": p[1], "winner": p[1]})
		g.report(res)
		g.hp.fill(Colisee.TEAM_HP)
	var ok8 := true
	for a in 8:
		for b in 8:
			if a != b and int(g.met[a][b]) != 1:
				ok8 = false
	check("8 équipes, 7 manches : tour complet", ok8 and g.rematch_violations == 0)
	# nombre impair : un exempt par manche, jamais deux fois de suite
	g = Colisee.new("classique", 5)
	g.out[5] = true
	g.place[5] = 6
	var byes: Array = []
	for r in 10:
		var pr := g.next_round()
		byes.append(int(pr.bye))
		g.report([])
		g.hp.fill(Colisee.TEAM_HP)
	var twice := 0
	for i in range(1, byes.size()):
		if byes[i] == byes[i - 1]:
			twice += 1
	var counts := {}
	for b in byes:
		counts[b] = int(counts.get(b, 0)) + 1
	check("5 équipes : un exempt à chaque manche, jamais deux fois de suite, 2 fois chacune en 10 manches %s" % str(counts),
		not -1 in byes and twice == 0 and counts.size() == 5 and counts.values().all(func(v): return v == 2))


func _mass(fmt: String, games: int, max_round_expected: int) -> void:
	var rounds: Array = []
	var minutes: Array = []
	var bad_places := 0
	var viol := 0
	var bad_hist := 0
	var unavoid := 0
	var bye_twice := 0
	var over := 0
	var t0 := Time.get_ticks_msec()
	for k in games:
		var s := Colisee.simulate(fmt, 1000 + k)
		var g: Colisee = s.game
		rounds.append(int(s.rounds))
		minutes.append(float(s.minutes))
		var pl: Array = (s.places as Array).duplicate()
		pl.sort()
		if pl != range(1, g.n + 1) or int(s.winner) < 0:
			bad_places += 1
		viol += int(s.violations)
		var h := _check_history(g)
		bad_hist += int(h.bad)
		unavoid += int(h.unavoidable)
		bye_twice += int(h.bye_twice)
		if int(s.rounds) > max_round_expected:
			over += 1
	rounds.sort()
	minutes.sort()
	var med_r: int = rounds[rounds.size() / 2]
	var p90_r: int = rounds[int(rounds.size() * 0.9)]
	var med_m: float = minutes[minutes.size() / 2]
	print("[co_a] %s : %d parties en %d ms ; manches médiane %d, p90 %d, max %d ; partie médiane %.1f min (p10 %.1f, p90 %.1f) ; au-delà de la manche %d : %d"
		% [fmt, games, Time.get_ticks_msec() - t0, med_r, p90_r, rounds[-1], med_m, minutes[int(minutes.size() * 0.1)],
			minutes[int(minutes.size() * 0.9)], max_round_expected, over])
	check("%s : %d parties, places uniques de 1 à n, un vainqueur" % [fmt, games], bad_places == 0)
	# après des éliminations, revoir une équipe trop tôt peut devenir inévitable (4 équipes dont 3 n'ont pas vu la même) :
	# la machine en fait alors le moins possible, manche par manche (recherche exhaustive indépendante)
	print("[co_a] %s : combats qui revoient une équipe trop tôt : %d (%.2f par partie), tous inévitables : %s" % [fmt, viol,
		float(viol) / games, str(viol == unavoid)])
	check("%s : pas deux fois le même adversaire avant d'avoir vu tous les autres, sauf inévitable (écart au minimum %d, machine %d, minimum %d)"
		% [fmt, bad_hist, viol, unavoid], bad_hist == 0 and viol == unavoid)
	check("%s : jamais exempt deux fois de suite (%d)" % [fmt, bye_twice], bye_twice == 0)
	check("%s : fin au plus tard manche %d (%d au-delà)" % [fmt, max_round_expected, over], over == 0)


func _ties_and_simultaneous() -> void:
	var g := Colisee.new("classique", 3)
	g.next_round()
	var elim := g.report([{"a": 0, "b": 1, "winner": -1, "left_a": 0.4, "left_b": 0.7}, {"a": 2, "b": 3, "winner": -1, "left_a": 0.5, "left_b": 0.5},
		{"a": 4, "b": 5, "winner": 4}])
	check("égalité au temps : la plus grande part de PV restants gagne", g.hp[0] == 80 and g.hp[1] == 100 and g.round_wins[1] == 1)
	check("égalité exacte : les deux perdent la moitié du barème", g.hp[2] == 90 and g.hp[3] == 90 and elim.is_empty())
	# éliminations simultanées : la plus basse en PV d'abord, places uniques
	g = Colisee.new("eclair", 4)
	g.hp = [10, 30, 20, 100]
	g.round_n = 6
	g.next_round()
	g.current.pairs = [[0, 3], [1, 2]]
	g.round_n = 7  # mort subite
	elim = g.report([{"a": 0, "b": 3, "winner": 3}, {"a": 1, "b": 2, "winner": 1}])
	check("éliminations simultanées : la plus basse en PV d'abord (%s)" % str(elim), elim.size() == 2 and int(elim[0][1]) == 4
		and int(elim[1][1]) == 3 and g.hp[int(elim[0][0])] <= g.hp[int(elim[1][0])])
	# finale : les deux dernières tombent ensemble, la mieux placée en PV prend la 1re place
	g = Colisee.new("eclair", 6)
	g.out = [true, true, false, false]
	g.place = [4, 3, 0, 0]
	g.hp = [0, 0, 20, 40]
	g.round_n = 8
	g.next_round()
	elim = g.report([{"a": 2, "b": 3, "winner": -1, "left_a": 0.5, "left_b": 0.5}])
	check("finale nulle, les deux à terre : 2e et 1re selon les PV (%s, places %s)" % [str(elim), str(g.place)],
		g.place[2] == 2 and g.place[3] == 1 and g.winner() == 3 and g.is_over())


func _teams() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 12
	var t := Colisee.compose_teams(6, "warrior", r)
	var all := {}
	var fam_ok := true
	for trio in t:
		var fams := {}
		for c in trio:
			all[c] = true
			fams[Duel.family_of(String(c))] = true
		fam_ok = fam_ok and fams.size() == 3 and (trio as Array).size() == 3
	check("6 trios, 18 classes différentes, 3 familles par trio, le joueur en tête de l'équipe 0", t.size() == 6 and all.size() == 18
		and fam_ok and String(t[0][0]) == "warrior")
	var t8 := Colisee.compose_teams(8, "cleric", r)
	var all8 := {}
	for trio in t8:
		for c in trio:
			all8[c] = true
	check("8 trios : 24 classes différentes", all8.size() == 24)
	var d := Colisee.team_difficulties(4, 6, r)
	check("Mélange : alliés en Normal, une difficulté par équipe adverse", d.size() == 6 and int(d[0]) == 1 and d.all(func(x): return x >= 0 and x <= 3))
	check("difficulté fixe : la même partout", Colisee.team_difficulties(3, 6, r) == [3, 3, 3, 3, 3, 3])


func _game_start() -> void:
	Profile.selected_class = "warrior"
	var g := Colisee.begin("warrior", "classique", 2, 4242)
	check("lancement : mode colisee, type équipes, 6 équipes", Modes.current() == "colisee" and Modes.kind() == "teams"
		and TeamMatch.team_count() == 6 and Colisee.game == g)
	check("scellé, JcJ, partie entre héros ; jamais Duel.active ni Royale.active", Modes.sealed() and Modes.is_pvp() and Modes.hero_match()
		and not Duel.active and not Royale.active)
	check("profil de règles « colisee » lu par ModeRules et PvpCaps", ModeRules.profile_name() == "colisee"
		and is_equal_approx(PvpCaps.damage_scale(), float(Colisee.PROFILE.dmg_scale)))
	check("équipement mis de côté, ni or ni sac (comme le Battle royale)", Profile.equipped.is_empty() and Profile.gold == 0 and Profile.bag.is_empty())
	check("ni potions, ni cartes de niveau, ni journal, ni sauvegarde", not Potions.allowed() and not TeamMatch.allows("level_cards")
		and not TeamMatch.allows("journal") and not TeamMatch.allows("save"))
	check("directeur du combat déclaré", String(TeamMatch.spec.director).ends_with("colisee_director.gd"))
	check("activité des quêtes : colisee", Quests.current_act() == "colisee")
	var lt := PauseMenu.leave_texts()
	check("menu pause : abandon du Colisée (« %s »)" % String(lt.get("title", "")), String(lt.get("title", "")).contains("Colisée"))
	Colisee.finish()
	Run.active = false
	Profile.in_run = false
	Profile.reload_keep_records()
	check("fin : menu, rien de scellé, plus de partie", Modes.current() == "menu" and not Modes.sealed() and Colisee.game == null)
	check("le profil « colisee » ne vit qu'à l'exécution (pas dans PROFILES)", not ModeRules.PROFILES.has("colisee"))
	ModeRules._extra.erase("colisee")
