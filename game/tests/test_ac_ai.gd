extends Node
## L'Échiquier, lot AC-D : les stratèges IA (AutochessAi). Une partie complète de 8 IA mêlées sans erreur, placement selon
## les rôles, aucune triche (l'IA n'agit que par les actions publiques, rejouées à l'identique sur une copie ; elle ne lit
## ni la réserve ni le hasard de la partie), déterminisme et reprise identique, échelle des difficultés sur quelques
## graines fixes, temps de décision. Le banc long (200 parties) : res://tools/autochess_ai_games.tscn (hors suite).
## godot --headless --path game res://tests/test_ac_ai.tscn

const AI_SRC := "res://scripts/core/autochess_ai.gd"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	_test_factory()
	_test_full_game()
	_test_placement()
	_test_no_cheat_source()
	_test_no_cheat_replay()
	_test_determinism_and_resume()
	_test_ladder()
	print("durée : %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("TOUT OK" if fails == 0 else "%d ÉCHEC(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# --- Outils -------------------------------------------------------------------------------------------------------
func _mixed(game_seed: int) -> Array:
	var out: Array = []
	for i in AutochessData.PLAYERS:
		out.append(AutochessAi.make(i % 4, String(AutochessAi.TEMPERS[(i / 4 + i) % 3]), game_seed * 31 + i))
	return out


func _new_game(game_seed: int, strats: Array) -> Autochess:
	var g := Autochess.new()
	g.save_path = ""
	g.start(game_seed, strats)
	return g


## Donne au stratège une unité prise dans la réserve (comme le ferait un achat).
func _grant(g: Autochess, pi: int, id: String, stars := 1) -> Dictionary:
	var n := int(pow(3, stars - 1))
	var got := g.pool.take(id, n)
	var u := g._make_unit(id, stars, got)
	if not g._add_unit(pi, u):
		g.pool.give(id, got)
		return {}
	return u


func _play_until(g: Autochess, st: int, rd: int) -> void:
	var guard := 0
	while not g.is_over() and guard < 400 and not (g.phase == "prep" and g.stage == st and g.round_i == rd):
		guard += 1
		g.step()


# --- 1. fabrique ---------------------------------------------------------------------------------------------------
func _test_factory() -> void:
	var a := AutochessAi.make("legende", "relanceur", 7)
	var b := AutochessAi.make(1, "", 4)
	check("make : difficulté et tempérament (%s, %s)" % [a.label(), b.label()],
		a.difficulty == 3 and a.temperament == "relanceur" and b.difficulty == 1 and b.temperament in AutochessAi.TEMPERS)
	var line := AutochessAi.lineup(2, 99, 0)
	var mix := [0, 0, 0, 0]
	for i in range(1, line.size()):
		mix[(line[i] as AutochessAi).difficulty] += 1
	check("lineup : le joueur en 0, 7 IA au mélange de la difficulté (%s)" % str(mix),
		line.size() == 8 and line[0] == null and mix == AutochessData.DIFFICULTIES[2].mix)
	var line2 := AutochessAi.lineup(2, 99, 0)
	var same := true
	for i in range(1, 8):
		same = same and (line[i] as AutochessAi).label() == (line2[i] as AutochessAi).label() \
			and (line[i] as AutochessAi).seed_value == (line2[i] as AutochessAi).seed_value
	check("lineup : même graine, mêmes IA", same)


# --- 2. une partie complète ----------------------------------------------------------------------------------------
func _test_full_game() -> void:
	var g := _new_game(4242, _mixed(4242))
	var pool_ok := true
	var boards_ok := true
	var guard := 0
	var us := 0
	var calls := 0
	while not g.is_over() and guard < 600:
		guard += 1
		if g.phase == "prep":
			for p in g.players:
				if not bool(p.alive):
					continue
				var cells := {}
				for u in p.board:
					cells["%d,%d" % [int(u.cell[0]), int(u.cell[1])]] = true
				boards_ok = boards_ok and (p.board as Array).size() <= g.board_cap(int(p.id)) \
					and cells.size() == (p.board as Array).size() and int(p.gold) >= 0 and (p.pending as Array).is_empty()
		var t := Time.get_ticks_usec()
		g.step()
		if g.phase == "prep":
			us += Time.get_ticks_usec() - t
			calls += g.alive_ids().size()
		pool_ok = pool_ok and g.pool_ok()
	var places: Array = []
	for p in g.players:
		places.append(int(p.place))
	places.sort()
	check("partie complète de 8 IA mêlées : finie en %d manches, places 1 à 8 (%s)" % [g.rounds_played, str(places)],
		g.is_over() and places == [1, 2, 3, 4, 5, 6, 7, 8])
	check("réserve juste à chaque phase", pool_ok)
	check("plateaux valides après chaque préparation (places, cases distinctes, or ≥ 0, aucun choix en suspens)", boards_ok)
	var ms := float(us) / maxf(float(calls), 1.0) / 1000.0
	check("temps de préparation par stratège : %.2f ms (banc : sous 5 ms en moyenne)" % ms, ms < 10.0)
	var all_ai := true
	for p in g.players:
		all_ai = all_ai and (p.meta as Dictionary).has("ai") and (p.meta as Dictionary).has("plan")
	check("chaque IA tient son plan et son identité dans meta (sauvegardés)", all_ai)


# --- 3. placement selon les rôles ----------------------------------------------------------------------------------
func _setup_board(diff: int) -> Array:
	var g := _new_game(77, [])  # 8 joueurs humains : aucune décision automatique
	for p in g.players:
		p.level = 6
	for id in ["warrior", "hunter", "cleric", "thief", "magician"]:
		_grant(g, 0, id)
	var ai := AutochessAi.make(diff, "econome", 5)
	ai._bind(g, 0)
	ai._arrange()
	return [g, ai]


func _cell_of(g: Autochess, id: String) -> Vector2i:
	for u in g.players[0].board:
		if String(u.id) == id:
			return Vector2i(int(u.cell[0]), int(u.cell[1]))
	return Vector2i(-1, -1)


func _test_placement() -> void:
	var r := _setup_board(2)
	var g: Autochess = r[0]
	var tank := _cell_of(g, "warrior")
	var archer := _cell_of(g, "hunter")
	var mage := _cell_of(g, "magician")
	var healer := _cell_of(g, "cleric")
	var assassin := _cell_of(g, "thief")
	check("Champion : les 5 unités sur le plateau", (g.players[0].board as Array).size() == 5)
	check("tank devant (%s)" % str(tank), tank.y == 0)
	check("tireur et mage au fond (%s, %s)" % [str(archer), str(mage)], archer.y == 3 and mage.y == 3)
	check("soigneur derrière la ligne (%s)" % str(healer), healer.y >= 2)
	check("assassin sur un flanc, devant (%s)" % str(assassin), assassin.y <= 1 and assassin.x in [0, 6])
	# Contre des Ombres : le porteur va dans un coin du fond
	var g2 := _new_game(78, [])
	for p in g2.players:
		p.level = 6
	for id in ["warrior", "hunter", "cleric", "magician"]:
		_grant(g2, 0, id)
	for id in ["thief", "assassin", "samurai"]:
		var u := _grant(g2, 1, id)
		g2.place(1, int(u.uid), g2.free_cell(1, "avant"))
	var ai2 := AutochessAi.make(2, "econome", 6)
	ai2._bind(g2, 0)
	ai2._arrange()
	var carry := -1
	for u in g2.players[0].board:
		if int(u.uid) == ai2._carry_uid(g2.players[0].board):
			carry = int(u.uid)
	var cc := Vector2i(-1, -1)
	for u in g2.players[0].board:
		if int(u.uid) == carry:
			cc = Vector2i(int(u.cell[0]), int(u.cell[1]))
	check("contre les Ombres, le porteur se met dans un coin du fond (%s)" % str(cc), cc in [Vector2i(0, 3), Vector2i(6, 3)])
	# Recrue : devant ou derrière selon la portée
	var r3 := _setup_board(0)
	var g3: Autochess = r3[0]
	check("Recrue : mêlée devant, distance au fond (%s, %s)" % [str(_cell_of(g3, "warrior")), str(_cell_of(g3, "hunter"))],
		_cell_of(g3, "warrior").y == 0 and _cell_of(g3, "hunter").y == 3)


# --- 4. aucune triche : le code ------------------------------------------------------------------------------------
func _test_no_cheat_source() -> void:
	var src := FileAccess.get_file_as_string(AI_SRC)
	var bad: Array = []
	var rx := RegEx.new()
	# ni la réserve, ni le hasard de la partie, ni une fonction privée de la partie, ni une écriture directe dans l'état
	for pat in ["_g\\.pool", "\\bg\\.pool", "_g\\.rng", "\\bg\\.rng", "_g\\._", "\\bg\\._",
			"_p\\.(gold|hp|level|xp|board|bench|shop|items|augments|crowns|locked|pending|trait_bonus)\\s*=[^=]",
			"_p\\[\"(gold|hp|level|xp|board|bench|shop|items|augments|crowns|locked|pending)\"\\]\\s*="]:
		rx.compile(pat)
		for m in rx.search_all(src):
			bad.append(m.get_string())
	check("code de l'IA : aucune lecture de la réserve ni du hasard de la partie, aucune écriture directe (%s)" % str(bad),
		bad.is_empty() and src.length() > 1000)


# --- 5. aucune triche : rejouer les actions ------------------------------------------------------------------------
## Partie espionne : note chaque action publique de préparation, puis la fait.
class SpyGame:
	extends Autochess
	var actions: Array = []

	func buy(pi: int, slot: int) -> bool:
		actions.append(["buy", [pi, slot]])
		return super(pi, slot)

	func sell(pi: int, uid: int) -> bool:
		actions.append(["sell", [pi, uid]])
		return super(pi, uid)

	func reroll(pi: int) -> bool:
		actions.append(["reroll", [pi]])
		return super(pi)

	func buy_xp(pi: int) -> bool:
		actions.append(["buy_xp", [pi]])
		return super(pi)

	func toggle_lock(pi: int) -> bool:
		actions.append(["toggle_lock", [pi]])
		return super(pi)

	func place(pi: int, uid: int, cell: Vector2i) -> bool:
		actions.append(["place", [pi, uid, cell]])
		return super(pi, uid, cell)

	func to_bench(pi: int, uid: int, slot := -1) -> bool:
		actions.append(["to_bench", [pi, uid, slot]])
		return super(pi, uid, slot)

	func equip(pi: int, item_idx: int, uid: int) -> bool:
		actions.append(["equip", [pi, item_idx, uid]])
		return super(pi, item_idx, uid)


## Enregistre les réponses de l'IA aux choix (emblème né d'un objet…), puis les rend dans le même ordre.
class Recorder:
	extends RefCounted
	var ai: AutochessAi
	var answers: Array = []
	var replay := false

	func decide(g: Autochess, pi: int) -> void:
		if not replay:
			ai.decide(g, pi)

	func choose(g: Autochess, pi: int, c: Dictionary) -> int:
		if replay:
			return int(answers.pop_front()) if not answers.is_empty() else 0
		var r := ai.choose(g, pi, c)
		answers.append(r)
		return r


func _test_no_cheat_replay() -> void:
	var base := _new_game(9090, _mixed(9090))
	var ok_all := true
	var acted := 0
	var tested := 0
	for target in [[1, 4], [2, 1], [2, 4], [3, 1], [3, 6], [4, 2], [5, 3]]:
		_play_until(base, int(target[0]), int(target[1]))
		if base.is_over():
			break
		base.step()  # fin de préparation
		if base.phase == "combat":
			base.step()  # combats -> bilan
		if base.phase != "recap":
			break
		# état au bilan : la manche suivante commence (revenu, boutique, décisions) dans deux copies
		var snap: Dictionary = JSON.parse_string(JSON.stringify(base.to_dict()))
		for pi in base.alive_ids():
			var spy := SpyGame.new()
			spy.save_path = ""
			spy.from_dict(snap)
			var rec := Recorder.new()
			rec.ai = AutochessAi.restore(spy)[pi]
			var strats: Array = []
			strats.resize(8)
			strats[pi] = rec
			spy.set_strategists(strats)
			spy.next_round()  # l'IA décide ici, seule
			acted += spy.actions.size()
			tested += 1
			# mêmes actions rejouées sur une copie sans IA : même état pour TOUS les stratèges (hors meta, carnet de l'IA)
			var plain := Autochess.new()
			plain.save_path = ""
			plain.from_dict(snap)
			var rep := Recorder.new()
			rep.replay = true
			rep.answers = rec.answers.duplicate()
			var strats2: Array = []
			strats2.resize(8)
			strats2[pi] = rep
			plain.set_strategists(strats2)
			plain.next_round()
			for a in spy.actions:
				plain.callv(String(a[0]), a[1])
			var same := spy.pool.to_dict() == plain.pool.to_dict() and spy.rng.state == plain.rng.state
			for q in AutochessData.PLAYERS:
				var p1: Dictionary = (spy.players[q] as Dictionary).duplicate(true)
				var p2: Dictionary = (plain.players[q] as Dictionary).duplicate(true)
				p1.erase("meta")
				p2.erase("meta")
				p1.erase("human")
				p2.erase("human")
				p1.erase("ready")
				p2.erase("ready")
				same = same and p1 == p2
			if not same:
				ok_all = false
				print("  IA %d à %s : l'état ne se refait pas avec ses seules actions" % [pi, spy.round_key()])
		base.step()  # manche suivante
	check("aucune triche : %d décisions refaites à l'identique avec les seules actions publiques (%d actions), autres stratèges intacts" % [tested, acted],
		ok_all and acted > 100 and tested >= 30)


# --- 6. déterminisme et reprise -----------------------------------------------------------------------------------
func _test_determinism_and_resume() -> void:
	var a := _new_game(31337, _mixed(31337))
	a.play_to_end()
	var b := _new_game(31337, _mixed(31337))
	b.play_to_end()
	check("même graine, mêmes IA : même partie (%d combats)" % a.history.size(), a.history == b.history and a.history.size() > 50)
	# reprise : sauvegarde (JSON) au début d'une préparation, IA refaites depuis meta, suite identique
	var c := _new_game(2718, _mixed(2718))
	_play_until(c, 3, 3)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	c.play_to_end()
	var d := Autochess.new()
	d.save_path = ""
	d.from_dict(saved)
	d.set_strategists(AutochessAi.restore(d))
	d.play_to_end()
	var pc: Array = c.players.map(func(p): return int(p.place))
	var pd: Array = d.players.map(func(p): return int(p.place))
	check("reprise après sauvegarde : IA refaites par restore(), même suite (%s)" % str(pd), c.history == d.history and pc == pd)


# --- 7. échelle des difficultés (graines fixes, combat provisoire) -------------------------------------------------
func _test_ladder() -> void:
	var leg := 0.0
	var top4 := 0
	var n := 16
	for k in n:
		var strats: Array = []
		for i in 8:
			strats.append(AutochessAi.make(3 if i == k % 8 else 0, String(AutochessAi.TEMPERS[(k + i) % 3]), k * 8 + i))
		var g := _new_game(500 + k, strats)
		g.play_to_end()
		var pl := int(g.players[k % 8].place)
		leg += pl
		top4 += 1 if pl <= 4 else 0
	check("Légende contre 7 Recrues (%d parties) : place moyenne %.2f, top 4 %d" % [n, leg / n, top4], leg / n <= 3.6 and top4 >= 10)
	var rec := 0.0
	var m := 8
	for k in m:
		var strats: Array = []
		for i in 8:
			strats.append(AutochessAi.make(0 if i == k % 8 else 3, String(AutochessAi.TEMPERS[(k + i) % 3]), k * 8 + i + 1000))
		var g := _new_game(700 + k, strats)
		g.play_to_end()
		rec += int(g.players[k % 8].place)
	check("Recrue contre 7 Légendes (%d parties) : place moyenne %.2f" % [m, rec / m], rec / m >= 5.0)
