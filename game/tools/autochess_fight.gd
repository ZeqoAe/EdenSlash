extends Node
## L'Échiquier, lot AC-C : outil de combat isolé (rapport conception/autochess/R_AC_C.md). Deux équipes en ligne de
## commande, vrai combat (AutochessDirector, AutochessUnit) contre simulateur (AutochessSim) ; calage du simulateur sur le
## vrai combat ; cadence du simulateur.
##
## Godot --headless --path game res://tools/autochess_fight.tscn --fixed-fps 60 -- <mode et options>
##   (--fixed-fps 60 : le vrai combat va aussi vite que la machine, au même pas de 1/60 s qu'en jeu)
## Un combat :  --a=warrior:2,knight,priest:1:executeur+transe --b=hunter:3,mage [--seed=7] [--no-real] [--n=5]
##              unité = id[:étoiles[:objet+objet…]][@colonne.rangée] ; --n : graines seed..seed+n-1
## Calage :     --calib [--n=100] [--batch=10] [--seed=1] [--save=user://autochess_calib.json]
##              100 compositions au hasard jouées en vrai (par lots de 10 plateaux en même temps) puis au simulateur ;
##              accord des vainqueurs, durées médianes, survivants, rythme des coups et des sorts
## Relecture :  --compare=user://autochess_calib.json [--tune=auto_lock:1.1,zone_dodge:0.3] [--sweep]
##              rejoue au simulateur les combats vrais enregistrés (réglages TUNE essayés à la volée, ou grille --sweep)
## Cadence :    --bench [--n=2000]   (combats 5 contre 5 au simulateur, combats par minute)
## Lignes : [ac_fight] (un combat), [ac_calib] (bilan), [ac_sweep], [ac_bench].

const SAVE_DEFAULT := "user://autochess_calib.json"

var args := {}
var dir: AutochessDirector


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var s := String(a).trim_prefix("--")
		var i := s.find("=")
		if i >= 0:
			args[s.substr(0, i)] = s.substr(i + 1)
		else:
			args[s] = "1"
	Settings.reset_all()
	var ui: Dictionary = Settings.data.get("interface", {})
	ui["hit_stop"] = false
	Settings.data["interface"] = ui
	var code := 0
	if args.has("bench"):
		bench(int(args.get("n", "2000")))
	elif args.has("compare"):
		compare(String(args.compare))
	elif args.has("calib"):
		await calib()
	elif args.has("a") and args.has("b"):
		await single()
	else:
		print("Usage : voir l'en-tête de tools/autochess_fight.gd")
		code = 1
	get_tree().quit(code)


# --- Équipes ------------------------------------------------------------------------------------------------------
## Équipe lue en ligne de commande : « id[:étoiles[:objet+objet]][@col.rangée] » séparés par des virgules.
static func parse_team(spec: String) -> Array:
	var out: Array = []
	var used := {}
	var k := 0
	for part in spec.split(",", false):
		var p := String(part).strip_edges()
		var cell := []
		var at := p.find("@")
		if at >= 0:
			var c := p.substr(at + 1).split(".")
			cell = [int(c[0]), int(c[1]) if c.size() > 1 else 0]
			p = p.substr(0, at)
		var f := p.split(":")
		var id := String(f[0])
		if AutochessData.unit(id).is_empty():
			push_warning("unité inconnue : " + id)
			continue
		var items: Array = []
		if f.size() > 2 and String(f[2]) != "":
			items = Array(String(f[2]).split("+", false))
		k += 1
		out.append(make_unit(id, int(f[1]) if f.size() > 1 else 1, items, k, cell, used))
	return out


## Une unité au format des plateaux de la machine (board_snapshot), case selon sa place si [param cell] est vide.
static func make_unit(id: String, stars: int, items: Array, uid: int, cell: Array, used: Dictionary) -> Dictionary:
	var d := AutochessData.unit(id)
	if cell.is_empty():
		var place := String(d.get("place", "milieu"))
		var row := 0 if place == "avant" else (3 if place == "arriere" else 1)
		var cols := [3, 2, 4, 1, 5, 0, 6]
		cell = [-1, -1]
		for r in [row, 1, 2, 0, 3]:
			for c in cols:
				if not used.has(Vector2i(c, r)):
					cell = [c, r]
					break
			if int(cell[0]) >= 0:
				break
	used[Vector2i(int(cell[0]), int(cell[1]))] = true
	return {"uid": uid, "id": id, "stars": clampi(stars, 1, AutochessData.MAX_STARS), "copies": 1, "items": items,
		"cell": cell, "cost": int(d.get("cost", 1)), "traits": (d.get("traits", []) as Array).duplicate()}


## Équipe au hasard (calage, tests) : [param n] unités de coût ≤ [param max_cost], étoiles et objets tirés.
static func random_team(rng: RandomNumberGenerator, n: int, max_cost := 5, star2 := 0.25, star3 := 0.05, item_p := 0.3) -> Array:
	var ids: Array = AutochessData.unit_ids().filter(func(id): return int(AutochessData.unit(id).get("cost", 1)) <= max_cost)
	var items: Array = AutochessData.ITEMS.keys()
	items.sort()
	var used := {}
	var out: Array = []
	for i in n:
		var id := String(ids[rng.randi_range(0, ids.size() - 1)])
		var x := rng.randf()
		var stars := 3 if x < star3 else (2 if x < star3 + star2 else 1)
		var its: Array = []
		while its.size() < 2 and rng.randf() < item_p:
			its.append(String(items[rng.randi_range(0, items.size() - 1)]))
		out.append(make_unit(id, stars, its, i + 1, [], used))
	return out


## Combat au format de Autochess.fights (board_a, board_b, ctx).
static func make_fight(a: Array, b: Array, seed_v: int, stage := 3) -> Dictionary:
	return {"kind": "jcj", "a": 0, "b": 1, "board_a": a, "board_b": b, "ctx": {"stage": stage, "round": 1, "kind": "jcj",
		"seed": seed_v, "a": 0, "b": 1, "ghost_of": -1, "augments": [[], []], "guardian_mult": 1.0}}


## Compositions de calage : 3 à 8 unités par camp, coûts, étoiles et objets variés, graines fixes.
static func calib_fights(n: int, seed0: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed0
	var out: Array = []
	for i in n:
		var size := rng.randi_range(3, 8)
		var mc := rng.randi_range(2, 5)
		var a := random_team(rng, size + rng.randi_range(-1, 1), mc)
		var b := random_team(rng, size + rng.randi_range(-1, 1), mc)
		out.append(make_fight(a, b, seed0 * 1000 + i))
	return out


# --- Mesures ------------------------------------------------------------------------------------------------------
## Mesures d'un combat fini (vrai ou simulé, même lecture de la couche) : vainqueur, durée, survivants, coups.
static func measures(ctx: Dictionary, r: Dictionary) -> Dictionary:
	var autos := 0
	var casts := 0
	var alive_t := 0.0
	for fid in ctx.units:
		var u: Dictionary = ctx.units[fid]
		autos += int(u.stats.attacks)
		casts += int(u.st.casts)
	var spell_hits := 0
	var heals := 0
	for e in ctx.log:
		if String(e.type) == "damage" and String(e.get("tag", "")) == "sort" and not bool(e.get("proc", false)):
			spell_hits += 1
		elif String(e.type) == "heal" and String(e.get("tag", "")) == "sort":
			heals += 1
	var dead_at := {}
	for e in ctx.log:
		if String(e.type) == "death":
			dead_at[int(e.dst)] = float(e.t)
	for fid in ctx.units:
		alive_t += float(dead_at.get(int(fid), float(r.duration)))
	var per_unit := {}  # id -> [dégâts infligés, secondes debout] (calage par unité)
	for fid in ctx.units:
		var u: Dictionary = ctx.units[fid]
		var id := String(u.id)
		if id == "":
			continue
		var e: Array = per_unit.get(id, [0.0, 0.0])
		e[0] += float(u.stats.dealt)
		e[1] += float(dead_at.get(int(fid), float(r.duration)))
		per_unit[id] = e
	return {"winner": int(r.winner), "duration": float(r.duration), "surv": [(r.stars[0] as Array).size(), (r.stars[1] as Array).size()],
		"autos": autos, "casts": casts, "spell_hits": spell_hits, "heals": heals, "unit_s": alive_t, "units": per_unit}


## Combat simulé d'une entrée de Autochess.fights, avec ses mesures.
static func sim_one(f: Dictionary, tune := {}) -> Dictionary:
	var ctx := AutochessSim.make_context(f.board_a, f.board_b, f.ctx)
	ctx["keep_log"] = true
	var r := AutochessSim.run(ctx, 0.0, AutochessDirector.draw_at(), {"tune": tune})
	return measures(ctx, r)


## Combats vrais (un lot de plateaux en même temps), avec leurs mesures.
func real_batch(fights: Array) -> Array:
	if dir == null:
		dir = AutochessDirector.new()
		dir.owns_mode = true
		add_child(dir)
	dir.fallback_ms = 0.0
	dir.set_speed(float(args.get("speed", "1")))
	dir.begin(fights, 0)
	for a in dir.arenas:
		a.ctx["keep_log"] = true
	if dir.running:
		await dir.round_finished
	var out: Array = []
	for a in dir.arenas:
		out.append(measures(a.ctx, a.result))
	dir.clear()
	return out


static func median(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	return float(s[s.size() / 2]) if s.size() % 2 == 1 else (float(s[s.size() / 2 - 1]) + float(s[s.size() / 2])) * 0.5


## Accord du simulateur avec le vrai combat sur des paires (vrai, simulé).
static func agreement(real: Array, sim: Array) -> Dictionary:
	var same := 0
	var surv := 0.0
	var dr: Array = []
	var ds: Array = []
	var tot := {"autos": [0.0, 0.0], "casts": [0.0, 0.0], "spell_hits": [0.0, 0.0], "heals": [0.0, 0.0], "unit_s": [0.0, 0.0]}
	var draws := [0, 0]
	for i in real.size():
		var r: Dictionary = real[i]
		var s: Dictionary = sim[i]
		if int(r.winner) == int(s.winner):
			same += 1
		draws[0] += 1 if int(r.winner) < 0 else 0
		draws[1] += 1 if int(s.winner) < 0 else 0
		surv += absf(float(r.surv[0]) - float(s.surv[0])) + absf(float(r.surv[1]) - float(s.surv[1]))
		dr.append(float(r.duration))
		ds.append(float(s.duration))
		for k in tot:
			tot[k][0] += float(r[k])
			tot[k][1] += float(s[k])
	var n := maxi(real.size(), 1)
	var mr := median(dr)
	var ms := median(ds)
	var out := {"n": real.size(), "agree": float(same) / n, "dur_real": mr, "dur_sim": ms,
		"dur_gap": absf(ms - mr) / maxf(mr, 0.001), "surv_gap": surv / (2.0 * n), "draws": draws}
	# rythmes par unité et par seconde debout (coups, sorts) ; touches par sort
	for k in ["autos", "casts", "heals"]:
		out[k] = [tot[k][0] / maxf(tot.unit_s[0], 1.0), tot[k][1] / maxf(tot.unit_s[1], 1.0)]
	out["hits_per_cast"] = [tot.spell_hits[0] / maxf(tot.casts[0], 1.0), tot.spell_hits[1] / maxf(tot.casts[1], 1.0)]
	return out


static func agreement_line(g: Dictionary) -> String:
	return "%d combats : même vainqueur %.0f %%, durée médiane vrai %.1f s / simulé %.1f s (écart %.0f %%), survivants ±%.2f, égalités %d / %d ; auto-attaques par unité-s %.3f / %.3f, sorts %.3f / %.3f, soins %.3f / %.3f, touches par sort %.2f / %.2f" % [
		int(g.n), 100.0 * float(g.agree), float(g.dur_real), float(g.dur_sim), 100.0 * float(g.dur_gap), float(g.surv_gap),
		int(g.draws[0]), int(g.draws[1]), g.autos[0], g.autos[1], g.casts[0], g.casts[1], g.heals[0], g.heals[1],
		g.hits_per_cast[0], g.hits_per_cast[1]]


static func parse_tune(spec: String) -> Dictionary:
	var out := {}
	for part in spec.split(",", false):
		var kv := String(part).split(":")
		if kv.size() == 2:
			out[String(kv[0])] = float(kv[1])
	return out


# --- Modes --------------------------------------------------------------------------------------------------------
func single() -> void:
	var a := parse_team(String(args.a))
	var b := parse_team(String(args.b))
	var s0 := int(args.get("seed", "1"))
	var n := int(args.get("n", "1"))
	var fights: Array = []
	for i in n:
		fights.append(make_fight(a, b, s0 + i))
	var real: Array = []
	if not args.has("no-real"):
		real = await real_batch(fights)
	for i in n:
		var s := sim_one(fights[i], parse_tune(String(args.get("tune", ""))))
		var line := "[ac_fight] graine %d : simulé vainqueur %d en %.1f s (survivants %s, sorts %d)" % [s0 + i, int(s.winner), float(s.duration), str(s.surv), int(s.casts)]
		if not real.is_empty():
			var r: Dictionary = real[i]
			line += " ; vrai vainqueur %d en %.1f s (survivants %s, sorts %d)" % [int(r.winner), float(r.duration), str(r.surv), int(r.casts)]
		print(line)


func calib() -> void:
	var n := int(args.get("n", "100"))
	var batch := int(args.get("batch", "10"))
	var fights := calib_fights(n, int(args.get("seed", "1")))
	var real: Array = []
	var t0 := Time.get_ticks_msec()
	var i := 0
	while i < fights.size():
		real.append_array(await real_batch(fights.slice(i, i + batch)))
		i += batch
		print("[ac_calib] vrais combats : %d / %d (%.0f s)" % [real.size(), fights.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	var path := String(args.get("save", SAVE_DEFAULT))
	var fa := FileAccess.open(path, FileAccess.WRITE)
	if fa:
		fa.store_string(JSON.stringify({"version": Version.NUMBER, "fights": fights, "real": real}))
		fa.close()
		print("[ac_calib] enregistré : %s" % ProjectSettings.globalize_path(path))
	_report(fights, real, parse_tune(String(args.get("tune", ""))))


func compare(path: String) -> void:
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		print("introuvable : " + path)
		return
	var data: Dictionary = JSON.parse_string(fa.get_as_text())
	var fights: Array = _fix_json(data.fights)
	var real: Array = data.real
	if args.has("sweep"):
		sweep(fights, real)
		return
	_report(fights, real, parse_tune(String(args.get("tune", ""))))


## JSON rend des nombres flottants : cases et identifiants remis en entiers.
static func _fix_json(fights: Array) -> Array:
	for f in fights:
		f.ctx["seed"] = int(f.ctx.seed)
		f.ctx["stage"] = int(f.ctx.stage)
		for k in ["board_a", "board_b"]:
			for u in f[k]:
				u["cell"] = [int(u.cell[0]), int(u.cell[1])]
				u["stars"] = int(u.stars)
				u["cost"] = int(u.cost)
				u["uid"] = int(u.uid)
	return fights


func _report(fights: Array, real: Array, tune: Dictionary) -> void:
	var sim: Array = []
	var t0 := Time.get_ticks_usec()
	for f in fights:
		sim.append(sim_one(f, tune))
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var g := agreement(real, sim)
	print("[ac_calib] " + agreement_line(g) + " ; simulateur %.1f ms par combat" % (ms / maxf(fights.size(), 1)))
	if args.has("units"):
		unit_factors(real, sim)
	if args.has("detail"):
		for i in fights.size():
			if int(real[i].winner) != int(sim[i].winner):
				print("   écart #%d : vrai %d (%.1f s, %s) simulé %d (%.1f s, %s)" % [i, int(real[i].winner), float(real[i].duration),
					str(real[i].surv), int(sim[i].winner), float(sim[i].duration), str(sim[i].surv)])


## Calage par unité : dégâts par seconde debout, vrai contre simulé, pour chaque unité vue dans 5 combats au moins ;
## facteur conseillé (« sim_factor » = vrai / simulé × facteur actuel) pour celles qui s'écartent de plus de 25 %.
static func unit_factors(real: Array, sim: Array) -> Dictionary:
	var acc := {}
	for i in real.size():
		for k in 2:
			var m: Dictionary = (real[i] if k == 0 else sim[i]).get("units", {})
			for id in m:
				var e: Array = acc.get(id, [0.0, 0.0, 0.0, 0.0, 0])
				e[k * 2] += float(m[id][0])
				e[k * 2 + 1] += float(m[id][1])
				if k == 0:
					e[4] += 1
				acc[id] = e
	var out := {}
	var rows: Array = []
	for id in acc:
		var e: Array = acc[id]
		if int(e[4]) < 5 or float(e[1]) <= 0.0 or float(e[3]) <= 0.0:
			continue
		var ratio := (float(e[0]) / float(e[1])) / maxf(float(e[2]) / float(e[3]), 0.001)
		out[id] = ratio
		rows.append([absf(log(maxf(ratio, 0.001))), id, ratio, int(e[4])])
	rows.sort_custom(func(x, y): return x[0] > y[0])
	var far := 0
	for r in rows:
		if absf(float(r[2]) - 1.0) > 0.25:
			far += 1
			print("[ac_units] %s : vrai / simulé %.2f (%d combats) ; sim_factor conseillé %.2f" % [r[1], float(r[2]), int(r[3]),
				clampf(float(r[2]) * AutochessSim.sim_factor(String(r[1])), 0.25, 4.0)])
	print("[ac_units] %d unités mesurées, %d à plus de 25 %% d'écart" % [rows.size(), far])
	return out


## Grille de réglages : chaque combinaison rejouée sur les combats vrais enregistrés ; les meilleures d'abord.
func sweep(fights: Array, real: Array) -> void:
	var grid := {
		"auto_lock": [0.8, 1.0, 1.2], "zone_dodge": [0.2, 0.35, 0.5], "move_fudge": [0.7, 0.85, 1.0], "spell_hit": [0.5],
	}
	if args.has("grid"):
		grid = {}
		for part in String(args.grid).split(";", false):
			var kv := String(part).split(":")
			grid[String(kv[0])] = Array(String(kv[1]).split("/")).map(func(x): return float(x))
	var combos: Array = [{}]
	for k in grid:
		var next: Array = []
		for c in combos:
			for v in grid[k]:
				var d: Dictionary = c.duplicate()
				d[k] = v
				next.append(d)
		combos = next
	var rows: Array = []
	for c in combos:
		var sim: Array = []
		for f in fights:
			sim.append(sim_one(f, c))
		var g := agreement(real, sim)
		var loss := (1.0 - float(g.agree)) + float(g.dur_gap) + 0.1 * float(g.surv_gap)
		rows.append([loss, c, g])
	rows.sort_custom(func(x, y): return x[0] < y[0])
	for i in mini(rows.size(), 12):
		print("[ac_sweep] %.3f %s : %s" % [rows[i][0], JSON.stringify(rows[i][1]), agreement_line(rows[i][2])])


## Cadence du simulateur : combats 5 contre 5 (coûts 1-4) joués de bout en bout.
static func bench(n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var fights: Array = []
	for i in n:
		fights.append(make_fight(random_team(rng, 5, 4, 0.2, 0.03, 0.2), random_team(rng, 5, 4, 0.2, 0.03, 0.2), 5000 + i))
	var t0 := Time.get_ticks_usec()
	var durs: Array = []
	for f in fights:
		durs.append(float(AutochessSim.fight(f.board_a, f.board_b, f.ctx).duration))
	var s := (Time.get_ticks_usec() - t0) / 1e6
	var per_min := n / maxf(s, 0.000001) * 60.0
	print("[ac_bench] %d combats 5 contre 5 en %.1f s : %.0f combats par minute (%.1f ms par combat), durée médiane %.1f s" % [
		n, s, per_min, s * 1000.0 / maxf(n, 1), median(durs)])
	return {"per_min": per_min, "ms": s * 1000.0 / maxf(n, 1), "median": median(durs)}
