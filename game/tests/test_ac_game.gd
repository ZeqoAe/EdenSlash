extends Node
## L'Échiquier, lot AC-B : la partie sans scène (Autochess, AutochessPool). Parties au hasard (combat injecté simple),
## invariant de la réserve, fusion banc plein, revenu par manche, même graine = même partie, reprise après sauvegarde,
## places et égalités, appariement et fantôme.
## godot --headless --path game res://tests/test_ac_game.tscn   (AC_GAMES=50 : moins de parties au hasard)

const SAVE_TEST := "user://acb_test_ac_game.json"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_test_merge()
	_test_income()
	_test_pairing_and_draws()
	_test_places()
	_test_same_seed()
	_test_resume()
	_test_random_games()
	print("durée : %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("TOUT OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# --- Outils -------------------------------------------------------------------------------------------------------
func _new(game_seed: int, strats: Array = [], fight := Callable()) -> Autochess:
	var g := Autochess.new()
	g.save_path = ""
	g.start(game_seed, strats, fight)
	return g


func _ais() -> Array:
	var out: Array = []
	for _i in AutochessData.PLAYERS:
		out.append(Autochess.RandomStrategist.new())
	return out


## Donne au stratège une unité prise dans la réserve (banc d'abord).
func _grant(g: Autochess, pi: int, id: String, stars := 1) -> Dictionary:
	var n := int(pow(3, stars - 1))
	var got := g.pool.take(id, n)
	var u := g._make_unit(id, stars, got)
	if not g._add_unit(pi, u):
		g.pool.give(id, got)
		return {}
	return u


## Met [param id] dans la case [param slot] de la boutique (la copie précédente revient à la réserve).
func _set_shop(g: Autochess, pi: int, slot: int, id: String) -> void:
	g.pool.give(String(g.players[pi].shop[slot]))
	g.players[pi].shop[slot] = id if g.pool.take(id) == 1 else ""


func _of_cost(cost: int, n: int, skip: Array = []) -> Array:
	return AutochessData.units_of_cost(cost).filter(func(id): return not id in skip).slice(0, n)


func _bench_count(g: Autochess, pi: int) -> int:
	return g.bench_units(pi).size()


## Contrôles de cohérence d'une partie ("" si tout va bien).
func _invariants(g: Autochess) -> String:
	var errs := g.pool_errors()
	if not errs.is_empty():
		return "réserve : " + str(errs.slice(0, 3))
	var uids := {}
	for p in g.players:
		var pi := int(p.id)
		if (p.bench as Array).size() != AutochessData.BENCH_SIZE:
			return "banc de %d : %d cases" % [pi, (p.bench as Array).size()]
		if not p.alive:
			if int(p.place) < 1 or not g.units_of(pi).is_empty():
				return "éliminé %d : place %d, %d unités" % [pi, int(p.place), g.units_of(pi).size()]
			continue
		if (p.board as Array).size() > g.board_cap(pi):
			return "plateau de %d : %d > %d" % [pi, (p.board as Array).size(), g.board_cap(pi)]
		if int(p.gold) < 0 or int(p.level) < 1 or int(p.level) > int(p.max_level):
			return "or / niveau de %d : %d / %d" % [pi, int(p.gold), int(p.level)]
		if (p.items as Array).size() > AutochessData.ITEM_BENCH_SIZE:
			return "banc d'objets de %d" % pi
		var cells := {}
		for u in p.board:
			var c := Vector2i(int(u.cell[0]), int(u.cell[1]))
			if not Autochess.cell_ok(c) or cells.has(c):
				return "case de %d : %s" % [pi, str(c)]
			cells[c] = true
		for u in g.units_of(pi):
			if uids.has(int(u.uid)):
				return "uid en double : %d" % int(u.uid)
			uids[int(u.uid)] = true
			if int(u.stars) < 1 or int(u.stars) > 3 or (u.items as Array).size() > AutochessData.MAX_ITEMS_PER_UNIT:
				return "unité de %d : %s" % [pi, str(u)]
	if g.phase == "combat":
		var seen := {}
		var ghosts := 0
		for f in g.fights:
			for side in [int(f.a), int(f.b)]:
				if side >= 0:
					if seen.has(side):
						return "%d combat deux fois" % side
					seen[side] = true
			if f.kind == "jcj" and int(f.b) < 0:
				ghosts += 1
		if seen.size() != g.alive_ids().size():
			return "combats : %d stratèges sur %d" % [seen.size(), g.alive_ids().size()]
		if g.round_kind() == "jcj" and ghosts != g.alive_ids().size() % 2:
			return "fantômes : %d" % ghosts
	return ""


# --- 1. Fusion, même banc plein -----------------------------------------------------------------------------------
func _test_merge() -> void:
	var g := _new(5)
	var p: Dictionary = g.players[0]
	p.gold = 100
	var x := String(AutochessData.units_of_cost(1)[0])
	var others := _of_cost(1, 7, [x])
	for id in others:
		_grant(g, 0, id)
	_grant(g, 0, x)
	_grant(g, 0, x)
	check("banc plein (9 unités)", _bench_count(g, 0) == 9)
	_set_shop(g, 0, 0, x)
	var gold0 := int(p.gold)
	check("achat possible banc plein quand il fait une ★2", g.can_receive(0, x) and g.buy(0, 0))
	var stars2 := g.units_of(0).filter(func(u): return u.id == x)
	check("une seule %s ★2 de 3 copies, banc à 8, or −1" % x, stars2.size() == 1 and int(stars2[0].stars) == 2
		and int(stars2[0].copies) == 3 and _bench_count(g, 0) == 8 and int(p.gold) == gold0 - 1)
	var y := String(_of_cost(1, 1, others + [x])[0])
	var z := String(_of_cost(1, 1, others + [x, y])[0])
	_grant(g, 0, y)
	_set_shop(g, 0, 1, z)
	check("achat refusé banc plein sans fusion", not g.buy(0, 1) and int(p.gold) == gold0 - 1)
	check("réserve juste après fusion", g.pool_ok())

	# ★3 en chaîne : 2 ★2 (dont une au plateau) + 2 ★1 + l'achat ; la ★3 prend la case du plateau et garde les objets
	var g2 := _new(6)
	var q: Dictionary = g2.players[0]
	q.gold = 100
	q.level = 5
	var w := String(AutochessData.units_of_cost(2)[0])
	var on_board := _grant(g2, 0, w, 2)
	check("pose au plateau", g2.place(0, int(on_board.uid), Vector2i(3, 0)))
	on_board.items = ["lame"]
	_grant(g2, 0, w, 2)
	var w1 := _grant(g2, 0, w)
	w1.items = ["plastron"]
	_grant(g2, 0, w)
	for id in _of_cost(2, 5, [w]):
		_grant(g2, 0, id)
	check("banc plein avant la ★3", _bench_count(g2, 0) == 8 and (q.board as Array).size() == 1)
	_grant(g2, 0, String(_of_cost(1, 1)[0]))
	_set_shop(g2, 0, 2, w)
	check("achat de la 9e copie banc plein", g2.buy(0, 2))
	var w3 := g2.units_of(0).filter(func(u): return u.id == w)
	check("★3 de 9 copies sur la case du plateau, objets combinés (%s)" % str(w3), w3.size() == 1 and int(w3[0].stars) == 3
		and int(w3[0].copies) == 9 and w3[0].has("cell") and int(w3[0].cell[0]) == 3 and w3[0].items == ["soif_de_sang"])
	check("banc libéré de 3 cases", _bench_count(g2, 0) == 6 and g2.pool_ok())
	var gold1 := int(q.gold)
	check("vente de la ★3 : 9 × coût − 1, copies rendues", g2.sell(0, int(w3[0].uid))
		and int(q.gold) == gold1 + 9 * 2 - 1 and g2.pool.remaining(w) == AutochessPool.total(w) and g2.pool_ok()
		and (q.items as Array).has("soif_de_sang"))

	# Étoile filante : ★2 avec 2 copies pour les coûts 1-2 seulement
	var g3 := _new(7)
	var r: Dictionary = g3.players[0]
	r.gold = 50
	r.pending = []
	(r.augments as Array).append("etoile_filante")
	var c1 := String(AutochessData.units_of_cost(1)[3])
	var c3 := String(AutochessData.units_of_cost(3)[0])
	_grant(g3, 0, c1)
	_set_shop(g3, 0, 0, c1)
	g3.buy(0, 0)
	var f1 := g3.units_of(0).filter(func(u): return u.id == c1)
	_grant(g3, 0, c3)
	_grant(g3, 0, c3)
	check("Étoile filante : coût 1 ★2 avec 2 copies, coût 3 inchangé", f1.size() == 1 and int(f1[0].stars) == 2
		and int(f1[0].copies) == 2 and g3.units_of(0).filter(func(u): return u.id == c3).size() == 2 and g3.pool_ok())

	# Objets : deux composants se combinent ; Insigne + Insigne = Couronne ; Marteau de réforge
	var u := g3.units_of(0)[0] as Dictionary
	r.items = ["lame", "arc", "insigne", "insigne", "marteau_reforge"]
	var cap0 := g3.board_cap(0)
	check("lame + arc = Transe de combat", g3.equip(0, 0, int(u.uid)) and g3.equip(0, 0, int(u.uid))
		and u.items == ["transe"])
	check("Insigne + Insigne = une place de plus", g3.equip(0, 0, int(u.uid)) and g3.equip(0, 0, int(u.uid))
		and g3.board_cap(0) == cap0 + 1 and u.items == ["transe"])
	check("Marteau : composants rendus au banc", g3.equip(0, 0, int(u.uid)) and (u.items as Array).is_empty()
		and r.items == ["lame", "arc"])
	r.items = ["insigne", "voile"]
	g3.equip(0, 0, int(u.uid))
	g3.equip(0, 0, int(u.uid))
	var pend := g3.pending(0)
	check("Insigne + composant : Emblème, choix d'un trait que l'unité n'a pas", pend.get("kind", "") == "embleme"
		and (pend.options as Array).size() == 3 and not (pend.options as Array).any(func(t): return t in Autochess.unit_traits(u)))
	var tr := String(pend.options[0])
	check("Emblème posé : l'unité compte pour le trait", g3.choose(0, 0) and tr in Autochess.unit_traits(u)
		and u.items == ["embleme:voile:%s" % tr])


# --- 2. Revenu par manche -----------------------------------------------------------------------------------------
func _test_income() -> void:
	var g := _new(9)
	var p: Dictionary = g.players[0]
	p.gold = 37
	p.streak = 4
	var inc := g.income_for(0, 3, 1)
	check("37 or, 4 victoires : 5 + 3 intérêts + 2 de série = 10 (%s)" % str(inc), inc.base == 5 and inc.interest == 3
		and inc.streak == 2 and inc.total == 10 and inc.xp == AutochessData.XP_PER_ROUND)
	p.streak = -5
	check("5 défaites : +3 de série", int(g.income_for(0, 3, 1).streak) == 3)
	p.streak = 1
	check("série de 1 : rien", int(g.income_for(0, 3, 1).streak) == 0)
	p.gold = 120
	check("intérêts plafonnés à 5", int(g.income_for(0, 3, 1).interest) == 5)
	(p.augments as Array).append("interets_composes")
	check("Intérêts composés : plafond 10", int(g.income_for(0, 3, 1).interest) == 10)
	p.augments = ["tresor_du_dragon", "tirelire", "apprenti"]
	var t := g.income_for(0, 3, 1)
	check("Trésor du dragon : aucun intérêt ; Tirelire +1 ; Apprenti +1 XP", t.interest == 0 and t.bonus == 1
		and t.xp == AutochessData.XP_PER_ROUND + 1)
	var c := g.income_for(0, 3, 4)
	check("choix partagé : pas de revenu de base (Tirelire seule)", c.base == 0 and c.streak == 0 and c.total == 1)
	p.augments = []
	p.gold = 0
	p.streak = 0
	check("étape 1 : 2 / 2 / 3 or ; XP dès 1-3", g.income_for(0, 1, 2).total == AutochessData.START_GOLD
		and g.income_for(0, 1, 3).total == 2 and g.income_for(0, 1, 4).total == 3 and g.income_for(0, 1, 2).xp == 0
		and g.income_for(0, 1, 3).xp == 2 and g.income_for(0, 1, 1).total == 0)

	# partie entière de 8 humains (choix d'office) : l'or de chaque préparation = or d'avant + revenu prévu
	var h := _new(10)
	var bad: Array = []
	var guard := 0
	while h.phase != "over" and guard < 400:
		guard += 1
		if h.phase == "recap":
			var st := h.stage
			var rd := h.round_i + 1
			if rd > AutochessData.rounds_in(st):
				st += 1
				rd = 1
			var expect := {}
			for pi in h.alive_ids():
				expect[pi] = int(h.players[pi].gold) + int(h.income_for(pi, st, rd).total)
			h.next_round()
			for pi in expect:
				if int(h.players[pi].gold) != int(expect[pi]):
					bad.append("%s j%d : %d au lieu de %d" % [h.round_key(), pi, int(h.players[pi].gold), int(expect[pi])])
			if h.round_key() == "1-2":
				for pi in h.alive_ids():
					if int(h.players[pi].level) != 2 or int(h.players[pi].gold) != AutochessData.START_GOLD:
						bad.append("1-2 j%d : niveau %d, or %d" % [pi, int(h.players[pi].level), int(h.players[pi].gold)])
		else:
			h.step()
	check("revenu de chaque manche = prévision, partie entière (%s)" % str(bad.slice(0, 3)), bad.is_empty() and h.phase == "over")
	var lv: int = h.players.map(func(q): return int(q.level)).max()
	check("les niveaux montent avec l'XP offerte (niveau max atteint %d)" % lv, lv >= 6)


# --- 3. Appariement, fantôme, égalités ----------------------------------------------------------------------------
func _test_pairing_and_draws() -> void:
	var g := _new(12)
	while not (g.phase == "combat" and g.round_kind() == "jcj"):
		g.step()
	check("2-1 : 4 combats, chaque vivant une fois, aucun fantôme", g.fights.size() == 4 and _invariants(g) == ""
		and g.fights.all(func(f): return int(f.b) >= 0))
	var hp0 := g.players.map(func(q): return int(q.hp))
	var gold0 := g.players.map(func(q): return int(q.gold))
	var res: Array = []
	for f in g.fights:
		res.append({"winner": -1, "stars": [[1, 1, 1], [2]], "duration": 45.0, "gold": [1, 0]})
	g.finish_combat(res)
	var ok := true
	for f in g.fights:
		var a := int(f.a)
		var b := int(f.b)
		ok = ok and int(g.players[a].hp) == hp0[a] - AutochessData.pvp_damage(2, [2])
		ok = ok and int(g.players[b].hp) == hp0[b] - AutochessData.pvp_damage(2, [1, 1, 1])
		ok = ok and g.players[a].last.result == "egalite" and int(g.players[a].streak) == -1 and int(g.players[b].streak) == -1
		ok = ok and int(g.players[a].gold) == gold0[a] + 1 and int(g.players[b].gold) == gold0[b]
	check("égalité : les deux perdent ce qui reste en face (4 et 5 PV), série de défaites ; or de combat compté", ok)

	# un éliminé : 7 vivants, un combat contre un fantôme ; le propriétaire ne gagne ni ne perd rien de plus
	g.players[7].hp = 0
	g._eliminate_dead()
	check("éliminé : 8e place, unités rendues", int(g.players[7].place) == 8 and g.pool_ok())
	g.next_round()
	g.end_prep()
	var ghost: Array = g.fights.filter(func(f): return int(f.b) < 0)
	check("7 vivants : 4 combats dont un contre un fantôme", g.fights.size() == 4 and ghost.size() == 1
		and int(ghost[0].ghost_of) >= 0 and int(ghost[0].ghost_of) != int(ghost[0].a) and g.players[int(ghost[0].ghost_of)].alive)
	var owner := int(ghost[0].ghost_of)
	check("le fantôme est l'équipe de son propriétaire", JSON.stringify(ghost[0].board_b) == JSON.stringify(g.board_snapshot(owner)))
	var played := g.players.map(func(q): return int(q.stats.won) + int(q.stats.lost))
	res.clear()
	for f in g.fights:
		res.append({"winner": 1, "stars": [[], [1, 1]], "duration": 30.0})
	g.finish_combat(res)
	var once := true
	for pi in g.alive_ids():
		once = once and int(g.players[pi].stats.won) + int(g.players[pi].stats.lost) == played[pi] + 1
	var fighter := int(ghost[0].a)
	check("chaque vivant compte un seul combat (propriétaire du fantôme compris)", once)
	check("perdre contre le fantôme coûte des PV au seul combattant", g.players[fighter].last.ghost == true
		and g.players[fighter].last.result == "defaite" and int(g.players[fighter].recent.back()) == owner)


# --- 4. Places --------------------------------------------------------------------------------------------------
func _test_places() -> void:
	var g := _new(3)
	for pi in g.players.size():
		g.players[pi].level = 3
	var hb := {5: 10, 6: 20, 7: 20}
	var hp := {5: 0, 6: -3, 7: -10}
	for pi in hb:
		g.players[pi].hp_before = hb[pi]
		g.players[pi].hp = hp[pi]
	var u6 := _grant(g, 6, String(AutochessData.units_of_cost(3)[0]))
	g.place(6, int(u6.uid), Vector2i(0, 0))
	var u7 := _grant(g, 7, String(AutochessData.units_of_cost(1)[0]))
	g.place(7, int(u7.uid), Vector2i(0, 0))
	g._eliminate_dead()
	check("même manche : PV d'avant, puis valeur d'équipe (6e, 7e, 8e)", g.players[6].place == 6 and g.players[7].place == 7
		and g.players[5].place == 8 and not g.players[6].alive and g.pool_ok() and (g.players[6].final_board as Array).size() == 1)
	for pi in [2, 3, 4]:
		g.players[pi].hp_before = pi - 1
		g.players[pi].hp = 0
	g._eliminate_dead()
	check("trois d'un coup : 3e, 4e, 5e", g.players[4].place == 3 and g.players[3].place == 4 and g.players[2].place == 5
		and not g._check_over())
	g.players[0].hp_before = 5
	g.players[0].hp = -1
	g.players[1].hp_before = 9
	g.players[1].hp = -2
	g._eliminate_dead()
	check("les deux derniers tombent ensemble : le mieux placé est 1er", g.players[1].place == 1 and g.players[0].place == 2
		and g._check_over())
	var places := g.players.map(func(q): return int(q.place))
	places.sort()
	check("places 1 à 8", places == [1, 2, 3, 4, 5, 6, 7, 8])
	var ab := _new(4)
	ab.players[0].hp = 35
	for pi in range(1, 8):
		ab.players[pi].hp = 100 - pi * 10
	check("abandon : place parmi les vivants selon les PV (7e)", ab.abandon(0) == 7 and ab.is_over() and ab.pool_ok())


# --- 5. Même graine = même partie ---------------------------------------------------------------------------------
func _test_same_seed() -> void:
	var a := _new(77, _ais())
	a.play_to_end()
	var b := _new(77, _ais())
	b.play_to_end()
	check("même graine : même partie (%d manches, %d combats)" % [a.rounds_played, a.history.size()],
		a.is_over() and a.history == b.history and JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()))
	var c := _new(78, _ais())
	c.play_to_end()
	check("autre graine : autre partie", c.history != a.history)


# --- 6. Sauvegarde et reprise -------------------------------------------------------------------------------------
func _test_resume() -> void:
	Autochess.clear_save(SAVE_TEST)
	var a := Autochess.new()
	a.save_path = SAVE_TEST
	a.start(4242, _ais())
	while not (a.stage == 3 and a.round_i == 1 and a.phase == "prep") and not a.is_over():
		a.step()
	var saved := JSON.stringify(a.to_dict())
	check("sauvegarde écrite au début de la préparation de 3-1", Autochess.has_save(SAVE_TEST) and a.round_key() == "3-1")
	var b := Autochess.load_game(SAVE_TEST, _ais())
	check("reprise : état identique", b != null and JSON.stringify(b.to_dict()) == saved and b.phase == "prep")
	a.save_path = ""
	b.save_path = ""
	a.play_to_end()
	b.play_to_end()
	check("reprise : même suite et même fin (%d combats)" % a.history.size(), a.is_over() and a.history == b.history
		and JSON.stringify(a.to_dict()) == JSON.stringify(b.to_dict()))

	# joueur humain : quitter après avoir relancé = même boutique qu'au début de la préparation
	var h := Autochess.new()
	h.save_path = SAVE_TEST
	var strats := _ais()
	strats[0] = null
	h.start(31, strats)
	while not (h.round_key() == "2-1" and h.phase == "prep"):
		h.step()
	var shop: Array = (h.players[0].shop as Array).duplicate()
	h.players[0].gold = int(h.players[0].gold) + 10
	h.reroll(0)
	var back := Autochess.load_game(SAVE_TEST, strats)
	check("reprise du joueur : même boutique, même or, choix d'atout toujours en attente", back != null
		and back.players[0].shop == shop and back.players[0].gold == int(h.players[0].gold) - 10 + AutochessData.REROLL_COST
		and back.pending(0).get("kind", "") == "atout" and back.strategists[0] == null and back.players[0].human)
	h.play_to_end()
	check("partie finie : sauvegarde effacée", h.is_over() and not Autochess.has_save(SAVE_TEST))
	Autochess.clear_save(SAVE_TEST)


# --- 7. Parties au hasard -----------------------------------------------------------------------------------------
func _test_random_games() -> void:
	var n := int(OS.get_environment("AC_GAMES")) if OS.get_environment("AC_GAMES") != "" else 500
	var errors: Array = []
	var rounds: Array = []
	var stages: Array = []
	var pairs := 0
	var repeats := 0
	var stars3 := 0
	for k in n:
		var g := _new(1000 + k, _ais())
		while not g.is_over() and g.rounds_played < Autochess.MAX_ROUNDS:
			if g.phase == "combat" and g.round_kind() == "jcj" and g.alive_ids().size() == 8:
				for f in g.fights:
					pairs += 1
					if g._recent(int(f.a), int(f.b), AutochessData.avoid_recent(8)):
						repeats += 1
			g.step()
			var e := _invariants(g)
			if e != "":
				errors.append("partie %d, %s %s : %s" % [k, g.round_key(), g.phase, e])
				break
		if not g.is_over():
			errors.append("partie %d pas finie" % k)
		var places := g.players.map(func(q): return int(q.place))
		places.sort()
		if places != [1, 2, 3, 4, 5, 6, 7, 8]:
			errors.append("partie %d : places %s" % [k, str(places)])
		rounds.append(g.rounds_played)
		stages.append(g.stage)
		for p in g.players:
			for u in p.final_board:
				if int(u.stars) == 3:
					stars3 += 1
	var avg := 0.0
	for r in rounds:
		avg += float(r) / maxf(1.0, float(n))
	print("[ac_game] %d parties : %.1f manches en moyenne (%d à %d), étape finale %d à %d ; ★3 en fin : %d ; adversaire récent à 8 : %d / %d"
		% [n, avg, rounds.min(), rounds.max(), stages.min(), stages.max(), stars3, repeats, pairs])
	check("%d parties au hasard sans erreur, réserve juste à chaque phase, places 1 à 8 %s" % [n, str(errors.slice(0, 3))],
		errors.is_empty())
	check("à 8 vivants, jamais un des 3 derniers adversaires", repeats == 0)
