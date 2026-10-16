extends Node
## L'Échiquier, lot AC-U : banc d'essai de l'IA de combat des unités (SPEC §4.2 ; rapport conception/autochess/R_AC_U.md).
## Combats en miroir exact (mêmes unités, étoiles, objets, cases ; le directeur retourne le placement du camp B) : camp testé
## (--ai) contre camp de référence (--vs, IA naïve par défaut), côtés alternés. 40 compositions (8 par archétype :
## plongeurs, tireurs, mur, sorts, soins) × graines × 2 côtés ; une ligne [ac_bench] par combat, puis la synthèse
## [ac_bench] === (victoires, soins perdus, ennemis par zone, portée des tireurs et mages, bornes, inactivité, durée).
##
## Godot --headless --fixed-fps 60 --path game res://tools/autochess_ai_bench.tscn -- [options]
##   --ai=full | naive | roles,target,… | full,-dodge   comportements du camp testé (AutochessUnit.BEHAVIORS)
##   --vs=naive                                         camp de référence (même syntaxe)
##   --comps=40 --seeds=3 --size=5 --batch=12           compositions, graines, unités par camp, combats en même temps
##   --items=0.3 --star2=0.25 --star3=0.05              objets et étoiles tirés (mêmes des deux côtés)
##   --shard=k/n --out=fichier.json                     part k (0..n-1) des combats ; résultats écrits en JSON
##   --merge=a.json,b.json,…                            synthèse de parts déjà jouées (aucun combat)

const ARCHETYPES := {
	"plongeurs": ["assassin", "assassin", "combattant", "tank", "tireur"],
	"tireurs": ["tank", "combattant", "tireur", "tireur", "tireur"],
	"mur": ["tank", "tank", "tank", "combattant", "mage"],
	"sorts": ["tank", "combattant", "mage", "mage", "mage"],
	"soins": ["tank", "combattant", "soigneur", "soutien", "tireur"],
}
const COST_WEIGHTS := [0, 30, 28, 22, 12, 8]  # coût 1 à 5
const SUM_KEYS := ["casts", "autos", "heals", "out", "foreign", "zone_casts", "zone_hits", "line_casts", "line_hits",
	"heal_req", "heal_lost", "samples", "idle", "range_samples", "in_range", "contact", "hops", "dodges", "dives", "retreats"]

var args := {}
var dir: AutochessDirector
var records: Array = []
var out_of_board := 0
var _frame_ms := 0.0  # coût : temps physique des images de combat, et unités vivantes vues
var _frame_units := 0
var _frames := 0


func _arg(k: String, def: String) -> String:
	return String(args.get(k, def))


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	Training.active = false
	if args.has("merge"):
		for path in _arg("merge", "").split(","):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				var d: Variant = JSON.parse_string(f.get_as_text())
				if d is Array:
					records.append_array(d)
		_summary()
		get_tree().quit(0)
		return
	seed(int(_arg("seed", "7")))
	dir = AutochessDirector.new()
	dir.owns_mode = true
	dir.fallback_ms = 0.0  # tous les combats en vrai
	add_child(dir)
	var fights := _plan()
	var shard := _arg("shard", "0/1").split("/")
	var k := int(shard[0])
	var n := maxi(1, int(shard[1]))
	var mine: Array = []
	for i in fights.size():
		if i % n == k:
			mine.append(fights[i])
	print("[ac_bench] %d combats (part %d/%d), camp testé %s contre %s" % [mine.size(), k, n, _arg("ai", "full"), _arg("vs", "naive")])
	var batch := maxi(1, int(_arg("batch", "12")))
	var t0 := Time.get_ticks_msec()
	var i := 0
	while i < mine.size():
		await _play(mine.slice(i, i + batch))
		i += batch
		print("[ac_bench] … %d / %d combats (%.0f s)" % [mini(i, mine.size()), mine.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	if args.has("out"):
		var f := FileAccess.open(_arg("out", ""), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(records))
	_summary()
	get_tree().quit(0)


## Comportements d'après la syntaxe « full,-dodge » / « roles,target » / « naive ».
static func parse_ai(s: String) -> Dictionary:
	var d := AutochessUnit.ai_naive()
	for tok in s.split(","):
		var t := tok.strip_edges()
		if t == "full":
			d = AutochessUnit.ai_full()
		elif t == "naive" or t == "":
			continue
		elif t.begins_with("-"):
			d[t.substr(1)] = false
		else:
			d[t] = true
	return d


# --- Compositions ----------------------------------------------------------------------------------------------------
func _plan() -> Array:
	var comps := int(_arg("comps", "40"))
	var seeds := int(_arg("seeds", "3"))
	var size := int(_arg("size", "5"))
	var ai_a := parse_ai(_arg("ai", "full"))
	var ai_b := parse_ai(_arg("vs", "naive"))
	var arch: Array = ARCHETYPES.keys()
	var out: Array = []
	for c in comps:
		for s in seeds:
			var rng := RandomNumberGenerator.new()
			rng.seed = 1000 * c + s + 1
			var aname := String(arch[c % arch.size()])
			var team := _team(rng, ARCHETYPES[aname], size)
			for side in 2:
				var f := {"kind": "jcj", "a": 0, "b": 1, "board_a": team, "board_b": team.duplicate(true),
					"ctx": {"stage": 3, "round": 1, "kind": "jcj", "seed": 1000 * c + s, "a": 0, "b": 1, "ghost_of": -1,
						"augments": [[], []], "guardian_mult": 1.0},
					"ai": [ai_a, ai_b] if side == 0 else [ai_b, ai_a]}
				out.append({"fight": f, "comp": c, "arch": aname, "seed": s, "tested": side,
					"units": team.map(func(u): return "%s★%d" % [u.id, int(u.stars)])})
	return out


## Équipe d'un archétype (rôles [param roles], complétée au besoin) : coûts tirés, étoiles, objets, cases selon la place.
func _team(rng: RandomNumberGenerator, roles: Array, size: int) -> Array:
	var by_role := {}
	for id in AutochessData.unit_ids():
		var d := AutochessData.unit(String(id))
		var r := String(d.get("role", "combattant"))
		if not by_role.has(r):
			by_role[r] = []
		by_role[r].append(String(id))
	var items: Array = AutochessData.ITEMS.keys()
	items.sort()
	var out: Array = []
	var cells := {}
	for i in size:
		var role := String(roles[i % roles.size()])
		var pool: Array = by_role.get(role, by_role.combattant)
		var want := _cost(rng)
		var ids := pool.filter(func(x): return int(AutochessData.unit(x).cost) == want)
		if ids.is_empty():
			ids = pool
		ids.sort()
		var id := String(ids[rng.randi_range(0, ids.size() - 1)])
		var d := AutochessData.unit(id)
		var row := 0 if String(d.get("place", "milieu")) == "avant" else (3 if String(d.get("place", "")) == "arriere" else 1)
		if role == "assassin":
			row = 1
		var cell := Vector2i(rng.randi_range(0, 6), row)
		var guard := 0
		while cells.has(cell) and guard < 100:
			guard += 1
			cell = Vector2i(rng.randi_range(0, 6), row if guard < 30 else rng.randi_range(0, 3))
		cells[cell] = true
		var x := rng.randf()
		var st := 3 if x < float(_arg("star3", "0.05")) else (2 if x < float(_arg("star3", "0.05")) + float(_arg("star2", "0.25")) else 1)
		var it: Array = []
		if rng.randf() < float(_arg("items", "0.3")):
			it.append(String(items[rng.randi_range(0, items.size() - 1)]))
		out.append({"uid": i + 1, "id": id, "stars": st, "copies": 1, "items": it, "cell": [cell.x, cell.y],
			"cost": int(d.get("cost", 1)), "traits": (d.get("traits", []) as Array).duplicate()})
	return out


func _cost(rng: RandomNumberGenerator) -> int:
	var total := 0
	for w in COST_WEIGHTS:
		total += int(w)
	var x := rng.randi_range(1, total)
	for c in range(1, COST_WEIGHTS.size()):
		x -= int(COST_WEIGHTS[c])
		if x <= 0:
			return c
	return 1


# --- Combats ---------------------------------------------------------------------------------------------------------
func _play(batch: Array) -> void:
	dir.begin(batch.map(func(b): return b.fight), 0)
	if dir.running:
		await dir.round_finished
	for i in batch.size():
		var b: Dictionary = batch[i]
		var a: Dictionary = dir.arenas[i]
		var r: Dictionary = a.result
		var tested := int(b.tested)
		var sums := [{}, {}]
		for side in 2:
			for k in SUM_KEYS:
				sums[side][k] = 0.0
		for fid in a.stats:
			var side := int(a.ctx.units[fid].side)
			var st: Dictionary = a.stats[fid]
			for k in SUM_KEYS:
				sums[side][k] = float(sums[side][k]) + float(st.get(k, 0.0))
		var w := int(r.winner)
		var rec := {"comp": b.comp, "arch": b.arch, "seed": b.seed, "tested": tested, "win": w == tested, "draw": w < 0,
			"duration": float(r.duration), "t": sums[tested], "r": sums[1 - tested], "units": b.units}
		records.append(rec)
		print("[ac_bench] combat %s #%d.%d côté %d : %s en %.1f s ; zones %d/%d, soins perdus %.0f/%.0f, bornes %d" % [
			b.arch, int(b.comp), int(b.seed), tested, "gagné" if rec.win else ("égalité" if rec.draw else "perdu"), rec.duration,
			int(sums[tested].zone_hits), int(sums[tested].zone_casts), float(sums[tested].heal_lost), float(sums[tested].heal_req),
			int(sums[tested].out) + int(sums[1 - tested].out)])


## Toutes les unités de tous les combats : sur leur plateau (marge comprise), à chaque image.
func _physics_process(_delta: float) -> void:
	if dir == null or not dir.running:
		return
	var lim := AutochessUnit.limits() + Vector2(0.01, 0.01)
	_frames += 1
	_frame_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	for a in dir.arenas:
		var o: Vector3 = a.origin
		for side in 2:
			for u in a.nodes[side]:
				if is_instance_valid(u):
					_frame_units += 1
					var p: Vector3 = (u as Node3D).global_position - o
					if absf(p.x) > lim.x or absf(p.z) > lim.y or p.y < -0.5:
						out_of_board += 1


# --- Synthèse --------------------------------------------------------------------------------------------------------
static func _ratio(a: float, b: float) -> float:
	return a / b if b > 0.0 else 0.0


func _summary() -> void:
	if records.is_empty():
		print("[ac_bench] aucun combat")
		return
	var n := records.size()
	var wins := 0
	var draws := 0
	var durs: Array = []
	var t := {}
	var r := {}
	for k in SUM_KEYS:
		t[k] = 0.0
		r[k] = 0.0
	var by_arch := {}
	for rec in records:
		wins += 1 if rec.win else 0
		draws += 1 if rec.draw else 0
		durs.append(float(rec.duration))
		for k in SUM_KEYS:
			t[k] += float(rec.t.get(k, 0.0))
			r[k] += float(rec.r.get(k, 0.0))
		var ar := String(rec.arch)
		if not by_arch.has(ar):
			by_arch[ar] = [0, 0]
		by_arch[ar][0] += 1 if rec.win else 0
		by_arch[ar][1] += 1
	durs.sort()
	var med: float = durs[durs.size() / 2]
	var arch_s := []
	for ar in by_arch:
		arch_s.append("%s %d %%" % [ar, int(round(100.0 * by_arch[ar][0] / maxf(by_arch[ar][1], 1)))])
	print("[ac_bench] === %d combats, %s contre %s : victoires %.1f %%, égalités %.1f %%, durée médiane %.1f s (p10 %.1f, p90 %.1f)" % [
		n, _arg("ai", "full"), _arg("vs", "naive"), 100.0 * wins / n, 100.0 * draws / n, med, durs[int(n * 0.1)], durs[mini(n - 1, int(n * 0.9))]])
	print("[ac_bench] === par archétype : %s" % ", ".join(arch_s))
	for side in [["testé", t], ["référence", r]]:
		var s: Dictionary = side[1]
		print("[ac_bench] === %s : soins perdus %.1f %% (%d soins), ennemis par zone %.2f (%d zones), par trait %.2f, tireurs/mages à portée %.1f %% / au contact %.1f %%, inactivité %.1f %%, bornes %.1f par combat, bonds %.1f, esquives %.1f, plongées %d, replis %d" % [
			side[0], 100.0 * _ratio(s.heal_lost, s.heal_req), int(s.heals), _ratio(s.zone_hits, s.zone_casts), int(s.zone_casts),
			_ratio(s.line_hits, s.line_casts), 100.0 * _ratio(s.in_range, s.range_samples), 100.0 * _ratio(s.contact, s.range_samples),
			100.0 * _ratio(s.idle, s.samples), s.out / n, s.hops / n, s.dodges / n, int(s.dives), int(s.retreats)])
	print("[ac_bench] === hors du plateau : %d image(s) ; coups étrangers %d" % [out_of_board, int(t.foreign + r.foreign)])
	if _frames > 0:
		print("[ac_bench] === coût : image physique %.2f ms en moyenne, %.3f ms par unité (%.0f unités par image)" % [
			_frame_ms / _frames, _frame_ms / maxf(_frame_units, 1.0), float(_frame_units) / _frames])
