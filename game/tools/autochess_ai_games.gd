extends Node
## L'Échiquier, lot AC-D : banc des stratèges IA (hors suite de tests). Joue des parties complètes entre IA (AutochessAi) sur
## la machine d'AC-B, sans scène, et mesure l'échelle des difficultés, la durée des parties, le temps de décision.
## Rapport : conception/autochess/R_AC_D.md.
##
## godot --headless --path game res://tools/autochess_ai_games.tscn -- [options]
##   --games=N          parties par mise en place (200)
##   --setup=S          legende_vs_recrues | recrue_vs_legendes | echelle | pilote | tout (défaut : tout)
##                      legende_vs_recrues : 1 Légende contre 7 Recrues (cible : top 4 ≥ 75 %) ;
##                      recrue_vs_legendes : 1 Recrue contre 7 Légendes (cible : top 4 ≤ 25 %) ;
##                      echelle : 2 IA de chaque difficulté (place moyenne par difficulté et par tempérament) ;
##                      pilote : une IA Vétéran à la place du joueur contre le mélange de chaque difficulté (SPEC §9).
##   --fight=F          power (combat provisoire Autochess.power_fight, défaut) | effects (combat de données de la couche
##                      d'effets d'AC-H) | sim (simulateur AutochessSim du lot AC-C, s'il existe : fonction statique fight)
##   --seed=N           graine de départ (1)
##   --out=chemin       une ligne JSON par partie (places, IA, manches, durée)
## Lignes « [ac_ai] » : une par mise en place + bilan (parties bloquées, erreurs de réserve, temps de décision).

const SIM_PATH := "res://scripts/core/autochess_sim.gd"

var games := 200
var setup := "tout"
var fight_name := "power"
var seed0 := 1
var out_path := ""
var tune_a := {}
var tune_b := {}
var trace := false  # --trace : état de chaque stratège à chaque préparation (1re partie de chaque mise en place)
var _traced := {}
var _out: FileAccess
var _fight := Callable()
var errors := 0
var stuck := 0
var anomalies := 0
var timing := {}
var fights_by_ratio := {}  # tranche du rapport de puissance (IA observée / adversaire) -> [victoires, combats]
var focal_seat := -1  # difficulté -> [µs décide, appels, µs choix, appels]


## Enveloppe qui mesure le temps de décision d'une IA.
class Timed:
	extends RefCounted
	var ai: AutochessAi
	var bench

	func _init(a: AutochessAi, b) -> void:
		ai = a
		bench = b

	func decide(g: Autochess, pi: int) -> void:
		var t := Time.get_ticks_usec()
		ai.decide(g, pi)
		bench.add_time(ai.difficulty, Time.get_ticks_usec() - t, true)

	func choose(g: Autochess, pi: int, c: Dictionary) -> int:
		var t := Time.get_ticks_usec()
		var r := ai.choose(g, pi, c)
		bench.add_time(ai.difficulty, Time.get_ticks_usec() - t, false)
		return r


func add_time(d: int, us: int, is_decide: bool) -> void:
	if not timing.has(d):
		timing[d] = [0, 0, 0, 0, 0]
	var row: Array = timing[d]
	if is_decide:
		row[0] = int(row[0]) + us
		row[1] = int(row[1]) + 1
		row[4] = maxi(int(row[4]), us)
	else:
		row[2] = int(row[2]) + us
		row[3] = int(row[3]) + 1


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"games":
				games = maxi(1, v.to_int())
			"setup":
				setup = v
			"fight":
				fight_name = v
			"seed":
				seed0 = v.to_int()
			"out":
				out_path = v
			"trace":
				trace = true
			"a":
				tune_a = _parse_tune(v)
			"b":
				tune_b = _parse_tune(v)
	_fight = _make_fight()
	if out_path != "":
		_out = FileAccess.open(out_path, FileAccess.WRITE)
	var t0 := Time.get_ticks_msec()
	print("[ac_ai] banc : %d parties par mise en place, combat %s, graine %d" % [games, fight_name, seed0])
	if setup in ["tout", "legende_vs_recrues"]:
		_one_vs_seven(3, 0, "legende_vs_recrues", ">= 0,75")
	if setup in ["tout", "recrue_vs_legendes"]:
		_one_vs_seven(0, 3, "recrue_vs_legendes", "<= 0,25")
	if setup in ["tout", "echelle"]:
		_ladder()
	if setup == "pilote":
		_pilot()
	if setup.begins_with("ab"):
		_ab(AutochessAi.diff_index(setup.trim_prefix("ab:")) if setup.contains(":") else 3)
	for d in timing:
		var row: Array = timing[d]
		print("[ac_ai] temps %s : décide %.2f ms en moyenne (%d appels, pire %.1f ms) ; choix %.3f ms (%d appels)" % [
			AutochessAi.DIFFS[d], float(row[0]) / maxf(float(row[1]), 1.0) / 1000.0, int(row[1]), float(row[4]) / 1000.0,
			float(row[2]) / maxf(float(row[3]), 1.0) / 1000.0, int(row[3])])
	print("[ac_ai] bilan : %d partie(s) bloquée(s), %d erreur(s) de réserve, %d anomalie(s) de plateau ; %.1f s" % [
		stuck, errors, anomalies, (Time.get_ticks_msec() - t0) / 1000.0])
	if _out:
		_out.close()
	get_tree().quit(0 if stuck == 0 and errors == 0 and anomalies == 0 else 1)


func _make_fight() -> Callable:
	match fight_name:
		"effects":
			return effects_fight
		"sim":
			if ResourceLoader.exists(SIM_PATH):
				var s: Script = load(SIM_PATH)
				return func(a: Array, b: Array, c: Dictionary) -> Dictionary: return s.call("fight", a, b, c)
			push_warning("AutochessSim absent : combat provisoire")
	return Callable()


# --- Mises en place ------------------------------------------------------------------------------------------------
func _one_vs_seven(focal: int, others: int, name: String, target: String) -> void:
	var top4 := 0
	var place_sum := 0
	var rounds := 0
	var minutes := 0.0
	var ms := 0
	var ratio := {}  # étape -> [somme des rapports puissance observée / moyenne des autres vivants, nombre]
	for k in games:
		var gs := seed0 + k
		var r := RandomNumberGenerator.new()
		r.seed = hash([gs, name])
		var seat := k % AutochessData.PLAYERS
		var strats: Array = []
		for i in AutochessData.PLAYERS:
			var d := focal if i == seat else others
			var temper := String(AutochessAi.TEMPERS[(k / AutochessData.PLAYERS) % 3]) if i == seat \
				else String(AutochessAi.TEMPERS[r.randi_range(0, 2)])
			var ai := AutochessAi.make(d, temper, r.randi_range(0, 0x3fffffff))
			if i == seat:
				ai.tune = tune_a  # --a= : réglages d'essai de l'IA observée
				if tune_a.has("temper"):
					ai.temperament = String(tune_a.temper)
			strats.append(Timed.new(ai, self))
		focal_seat = seat
		var res := _play(gs, strats, name)
		focal_seat = -1
		var place := int(res.places[seat])
		place_sum += place
		top4 += 1 if place <= 4 else 0
		rounds += int(res.rounds)
		minutes += float(res.minutes)
		ms += int(res.ms)
		for st in res.powers:
			var pw: Array = res.powers[st]
			if float(pw[seat]) <= 0.0:
				continue
			var rest_pw: Array = []
			for i in pw.size():
				if i != seat and float(pw[i]) >= 0.0:
					rest_pw.append(float(pw[i]))
			if not rest_pw.is_empty() and _mean(rest_pw) > 0.0:
				var acc: Array = ratio.get(st, [0.0, 0])
				ratio[st] = [float(acc[0]) + float(pw[seat]) / _mean(rest_pw), int(acc[1]) + 1]
	var rline := ""
	for st in [2, 3, 4, 5, 6]:
		if ratio.has(st):
			rline += " %d-1 ×%.2f" % [st, float(ratio[st][0]) / maxf(float(ratio[st][1]), 1.0)]
	print("[ac_ai] %s : puissance de l'IA observée / autres vivants :%s" % [name, rline])
	var fl := ""
	for key in ["<0,9", "0,9-1,1", "1,1-1,3", ">1,3"]:
		if fights_by_ratio.has(key):
			var acc: Array = fights_by_ratio[key]
			fl += " %s : %.2f (%d)" % [key, float(acc[0]) / float(acc[1]), int(acc[1])]
	print("[ac_ai] %s : victoires JcJ selon le rapport de puissance :%s" % [name, fl])
	fights_by_ratio.clear()
	print("[ac_ai] %s : top 4 %.2f (cible %s), place moyenne %.2f ; %.1f manches, %.1f min estimées, %.0f ms par partie" % [
		name, float(top4) / games, target, float(place_sum) / games, float(rounds) / games, minutes / games,
		float(ms) / games])


func _ladder() -> void:
	var by_d := {}
	var by_t := {}
	var top4_d := {}
	var rounds := 0
	var minutes := 0.0
	for k in games:
		var gs := seed0 + 10000 + k
		var r := RandomNumberGenerator.new()
		r.seed = hash([gs, "echelle"])
		var levels: Array = [0, 0, 1, 1, 2, 2, 3, 3]
		for i in range(levels.size() - 1, 0, -1):
			var j := r.randi_range(0, i)
			var t: Variant = levels[i]
			levels[i] = levels[j]
			levels[j] = t
		var strats: Array = []
		for i in AutochessData.PLAYERS:
			strats.append(Timed.new(AutochessAi.make(int(levels[i]), String(AutochessAi.TEMPERS[r.randi_range(0, 2)]),
				r.randi_range(0, 0x3fffffff)), self))
		var res := _play(gs, strats, "echelle")
		rounds += int(res.rounds)
		minutes += float(res.minutes)
		for i in AutochessData.PLAYERS:
			var ai: AutochessAi = strats[i].ai
			var pl := int(res.places[i])
			var kd := String(AutochessAi.DIFFS[ai.difficulty])
			var kt := "%s/%s" % [kd, ai.temperament]
			by_d[kd] = (by_d.get(kd, []) as Array) + [pl]
			by_t[kt] = (by_t.get(kt, []) as Array) + [pl]
			top4_d[kd] = int(top4_d.get(kd, 0)) + (1 if pl <= 4 else 0)
	var line := "[ac_ai] echelle (2 de chaque) : place moyenne"
	for kd in AutochessAi.DIFFS:
		var a: Array = by_d.get(kd, [])
		line += " %s %.2f (top 4 %.2f)" % [kd, _mean(a), float(top4_d.get(kd, 0)) / maxf(float(a.size()), 1.0)]
	print(line + " ; %.1f manches, %.1f min estimées" % [float(rounds) / games, minutes / games])
	var keys := by_t.keys()
	keys.sort()
	var line2 := "[ac_ai] echelle par tempérament :"
	for kt in keys:
		line2 += " %s %.2f" % [kt, _mean(by_t[kt])]
	print(line2)


## A / B : 4 IA de la difficulté avec les réglages --a=, 4 avec --b= (même tempérament de part et d'autre).
func _ab(d: int) -> void:
	var pa: Array = []
	var pb: Array = []
	for k in games:
		var gs := seed0 + 30000 + k
		var r := RandomNumberGenerator.new()
		r.seed = hash([gs, "ab"])
		var seats: Array = [0, 0, 0, 0, 1, 1, 1, 1]
		for i in range(seats.size() - 1, 0, -1):
			var j := r.randi_range(0, i)
			var t: Variant = seats[i]
			seats[i] = seats[j]
			seats[j] = t
		var strats: Array = []
		for i in AutochessData.PLAYERS:
			var ai := AutochessAi.make(d, String(AutochessAi.TEMPERS[i % 3]) if not tune_a.has("temper") else "", r.randi_range(0, 0x3fffffff))
			ai.tune = tune_a if int(seats[i]) == 0 else tune_b
			if ai.tune.has("temper"):
				ai.temperament = String(ai.tune.temper)
			strats.append(Timed.new(ai, self))
		var res := _play(gs, strats, "ab")
		for i in AutochessData.PLAYERS:
			(pa if int(seats[i]) == 0 else pb).append(int(res.places[i]))
	print("[ac_ai] A/B %s : A %s place %.2f · B %s place %.2f" % [AutochessAi.DIFFS[d], str(tune_a), _mean(pa), str(tune_b),
		_mean(pb)])


static func _parse_tune(v: String) -> Dictionary:
	var out := {}
	for part in v.split(",", false):
		var kv := part.split(":", true, 1)
		if kv.size() == 2:
			out[kv[0]] = kv[1].to_float() if kv[1].is_valid_float() else kv[1]
	return out


## Une IA Vétéran à la place du joueur contre les 7 IA du mélange de chaque difficulté (SPEC §9 : ≈ 50 % de top 4 en Vétéran).
func _pilot() -> void:
	for d in AutochessAi.DIFFS.size():
		var top4 := 0
		var place_sum := 0
		for k in games:
			var gs := seed0 + 20000 + k
			var strats := AutochessAi.lineup(d, gs, 0)
			strats[0] = AutochessAi.make(1, String(AutochessAi.TEMPERS[k % 3]), gs)
			for i in strats.size():
				strats[i] = Timed.new(strats[i], self)
			var res := _play(gs, strats, "pilote")
			var pl := int(res.places[0])
			place_sum += pl
			top4 += 1 if pl <= 4 else 0
		print("[ac_ai] pilote Vétéran contre le mélange %s : top 4 %.2f, place moyenne %.2f" % [AutochessAi.DIFFS[d],
			float(top4) / games, float(place_sum) / games])


# --- Une partie ----------------------------------------------------------------------------------------------------
func _play(gs: int, strats: Array, name: String) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var g := Autochess.new()
	g.save_path = ""
	g.start(gs, strats, _fight)
	var minutes := 0.0
	var guard := 0
	var powers := {}  # étape -> puissance de chaque stratège au début de l'étape (après ses décisions)
	while not g.is_over() and guard < Autochess.MAX_ROUNDS * 3 + 10:
		guard += 1
		if g.phase == "prep":
			minutes += g.prep_time() + AutochessData.ROUND_RECAP
			_check_boards(g)
			if trace and not _traced.has(name):
				_trace(g, strats)
			if g.round_i == 1 and g.stage >= 2:
				var pw: Array = []
				for p in g.players:
					pw.append(Autochess.team_power(g.board_snapshot(int(p.id))) if bool(p.alive) else -1.0)
				powers[g.stage] = pw
		var ph := g.step()
		if ph == "recap" or ph == "over":
			_count_fights(g)
			var longest := 0.0
			for r in g.results:
				longest = maxf(longest, float(r.duration))
			minutes += longest
			if ph == "recap" and not g.pool_ok():
				errors += 1
				push_error("réserve fausse (partie %d) : %s" % [gs, str(g.pool_errors().slice(0, 3))])
	_traced[name] = true
	if not g.is_over():
		stuck += 1
		push_error("partie %d bloquée à %s" % [gs, g.round_key()])
	var places: Array = []
	for p in g.players:
		places.append(int(p.place))
	var res := {"places": places, "rounds": g.rounds_played, "minutes": minutes / 60.0, "ms": Time.get_ticks_msec() - t0,
		"powers": powers}
	if _out:
		var ais: Array = []
		for s in strats:
			ais.append(s.ai.label() if s is Timed else (s.label() if s is AutochessAi else "joueur"))
		_out.store_line(JSON.stringify({"setup": name, "seed": gs, "fight": fight_name, "ais": ais, "places": places,
			"rounds": g.rounds_played, "minutes": snappedf(minutes / 60.0, 0.1)}))
	return res


func _count_fights(g: Autochess) -> void:
	if focal_seat < 0:
		return
	for i in g.fights.size():
		var f: Dictionary = g.fights[i]
		if String(f.kind) != "jcj" or (int(f.a) != focal_seat and int(f.b) != focal_seat):
			continue
		var side := 0 if int(f.a) == focal_seat else 1
		var pa := Autochess.team_power(f.board_a)
		var pb := Autochess.team_power(f.board_b)
		var ratio := (pa / maxf(pb, 0.01)) if side == 0 else (pb / maxf(pa, 0.01))
		var key := "<0,9" if ratio < 0.9 else ("0,9-1,1" if ratio < 1.1 else ("1,1-1,3" if ratio < 1.3 else (">1,3")))
		var acc: Array = fights_by_ratio.get(key, [0, 0])
		fights_by_ratio[key] = [int(acc[0]) + (1 if int(g.results[i].winner) == side else 0), int(acc[1]) + 1]


func _trace(g: Autochess, strats: Array) -> void:
	var line := "[trace] %s" % g.round_key()
	for p in g.players:
		if not bool(p.alive):
			line += " | --"
			continue
		var stars := 0
		for u in p.board:
			stars += int(u.stars)
		var s: Variant = strats[int(p.id)]
		var who: String = s.ai.label().substr(0, 3) if s is Timed else "?"
		line += " | %s pv%d or%d nv%d u%d e%d p%.1f o%d" % [who, int(p.hp), int(p.gold), int(p.level),
			(p.board as Array).size(), stars, Autochess.team_power(g.board_snapshot(int(p.id))), (p.items as Array).size()]
	print(line)


## Contrôles de fin de préparation (après les décisions des IA) : plateau dans la limite, cases distinctes, or positif.
func _check_boards(g: Autochess) -> void:
	for p in g.players:
		if not bool(p.alive):
			continue
		var cells := {}
		for u in p.board:
			cells["%d,%d" % [int(u.cell[0]), int(u.cell[1])]] = true
		if (p.board as Array).size() > g.board_cap(int(p.id)) or cells.size() != (p.board as Array).size() or int(p.gold) < 0:
			anomalies += 1
			push_error("plateau anormal : stratège %d à %s" % [int(p.id), g.round_key()])


static func _mean(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += float(x)
	return s / maxf(float(a.size()), 1.0)


# --- Combat de données (couche d'effets d'AC-H) ---------------------------------------------------------------------
## Combat de données simple : cible la plus proche, marche, attaque au rythme de la fiche, sort à mana pleine (soin du plus
## bas pour les soigneurs). Plus fidèle que power_fight (traits, objets, atouts comptent) ; le vrai est AC-C / AC-E.
static func effects_fight(a: Array, b: Array, c: Dictionary) -> Dictionary:
	var ctx := AutochessEffects.context(c, [a, b])
	AutochessEffects.start(ctx)
	var timers := {}
	var ids: Array = (ctx.units as Dictionary).keys()
	var dt := 0.1
	for _i in int(AutochessData.DRAW_AT / dt):
		AutochessEffects.tick(ctx, dt)
		if AutochessEffects.living(ctx, 0).is_empty() or AutochessEffects.living(ctx, 1).is_empty():
			break
		for fid in ids:
			var u: Dictionary = ctx.units[fid]
			if not u.alive or AutochessEffects.disabled(ctx, fid):
				continue
			var foes := AutochessEffects.near(ctx, int(u.side), u.pos)
			if foes.is_empty():
				break
			var tgt: int = foes[0]
			if AutochessEffects.can_cast(ctx, fid):
				var fx := AutochessEffects.cast(ctx, fid)
				var casts := 1
				for e in fx:
					if String(e.get("type", "")) == "recast":
						casts += 1
				for _k in casts:
					if String(AutochessData.unit(String(u.id)).get("spell_type", "")) == "soin":
						var low: int = fid
						for f in AutochessEffects.living(ctx, int(u.side)):
							if AutochessEffects.hp_frac(ctx.units[f]) < AutochessEffects.hp_frac(ctx.units[low]):
								low = f
						AutochessEffects.spell_heal(ctx, fid, low, float(u.sheet.get("spell_base", 0.0)))
					else:
						for f in AutochessEffects.near(ctx, int(u.side), ctx.units[tgt].pos, AutochessData.CELL):
							AutochessEffects.spell_hit(ctx, fid, f, 0.0)
				continue
			if AutochessEffects.dist(ctx, fid, tgt) > AutochessEffects.stat(ctx, fid, "reach"):
				var p: Vector2 = u.pos
				AutochessEffects.set_pos(ctx, fid, p.move_toward(ctx.units[tgt].pos, 0.3 * AutochessEffects.stat(ctx, fid, "move")))
				continue
			timers[fid] = float(timers.get(fid, 0.0)) + dt * AutochessEffects.stat(ctx, fid, "as")
			if float(timers[fid]) >= 1.0:
				timers[fid] = float(timers[fid]) - 1.0
				AutochessEffects.attack(ctx, fid, tgt)
	return AutochessEffects.result(ctx)
