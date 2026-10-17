extends Node
## L'Échiquier, lot AC-J : mesure de masse (SPEC §9 ; rapport conception/autochess/R_AC_J.md). Joue des parties complètes
## entre IA (AutochessAi) sur la machine d'AC-B, combats au simulateur (AutochessSim, calé sur le vrai combat), et écrit une
## ligne JSON par partie : places, compositions finales, traits, objets, atouts proposés et pris, économie, éliminations,
## durées des combats et de la partie. `python tools/autochess_report.py <fichiers>` en tire les tableaux du §9.
##
## Godot --headless --path game res://tools/autochess_games.tscn --quit-after 3 -- [options]
##   --games=N      parties (100)
##   --seed=N       graine de la 1re partie (1) : parties seed .. seed+N-1 ; plusieurs copies en parallèle = graines disjointes
##   --setup=S      echelle  : 2 IA de chaque difficulté, places mélangées (mesure principale : unités, traits, objets, atouts)
##                  l7r      : 1 Légende contre 7 Recrues (cible : top 4 ≥ 75 %)
##                  r7l      : 1 Recrue contre 7 Légendes (cible : top 4 ≤ 25 %)
##                  pilote   : 1 Vétéran contre les 7 IA du mélange Vétéran (cible : top 4 ≈ 50 %)
##                  legendes : 8 Légendes (méta des meilleures IA)
##   --fight=F      sim (défaut, AutochessSim) | power (combat provisoire d'AC-B)
##   --out=chemin   fichier JSONL, lignes ajoutées (défaut user://autochess_games.jsonl)
##   --ai=clé:val,… réglages d'essai de toutes les IA (AutochessAi.tune)
## Ligne « [ac_games] » de bilan (parties, bloquées, secondes par partie).

const DEFAULT_OUT := "user://autochess_games.jsonl"
const SETUPS := ["echelle", "l7r", "r7l", "pilote", "legendes"]

var games := 100
var seed0 := 1
var setup := "echelle"
var fight_name := "sim"
var out_path := DEFAULT_OUT
var ai_tune := {}
var stuck := 0
var _fight := Callable()
var _out: FileAccess


## Enveloppe d'une IA : relève ce que la partie ne garde pas (revenu de chaque manche, or à 4-1, atouts proposés).
class Rec:
	extends RefCounted
	var ai: AutochessAi
	var econ := {"rounds": 0, "income": 0, "interest": 0, "streak": 0, "gold": 0, "gold41": -1, "level41": -1, "level_end": 0}
	var offers: Array = []  # [[options…], pris (« » : relancé)]

	func _init(a: AutochessAi) -> void:
		ai = a

	func decide(g: Autochess, pi: int) -> void:
		var p: Dictionary = g.players[pi]
		var inc: Dictionary = p.get("income", {})
		if int(inc.get("base", 0)) > 0:
			econ.rounds += 1
			econ.income += int(inc.get("total", 0))
			econ.interest += int(inc.get("interest", 0))
			econ.streak += int(inc.get("streak", 0))
			econ.gold += int(p.gold)
		if g.stage == 4 and g.round_i == 1:
			econ.gold41 = int(p.gold)
		ai.decide(g, pi)
		if g.stage == 4 and g.round_i == 1:
			econ.level41 = int(p.level)
		econ.level_end = int(p.level)

	func choose(g: Autochess, pi: int, c: Dictionary) -> int:
		var idx := ai.choose(g, pi, c)
		if String(c.get("kind", "")) == "atout":
			var opts: Array = (c.options as Array).duplicate()
			offers.append([opts, String(opts[idx]) if idx >= 0 and idx < opts.size() else ""])
		return idx


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).trim_prefix("--").split("=", true, 1)
		var v := kv[1] if kv.size() > 1 else ""
		match kv[0]:
			"games":
				games = maxi(1, v.to_int())
			"seed":
				seed0 = v.to_int()
			"setup":
				setup = v
			"fight":
				fight_name = v
			"out":
				out_path = v
			"ai":
				ai_tune = parse_tune(v)
	if not setup in SETUPS:
		print("[ac_games] mise en place inconnue : %s (%s)" % [setup, ", ".join(SETUPS)])
		get_tree().quit(1)
		return
	if fight_name == "sim":
		_fight = AutochessSim.fight
	_out = FileAccess.open(out_path, FileAccess.READ_WRITE) if FileAccess.file_exists(out_path) else FileAccess.open(out_path, FileAccess.WRITE)
	if _out == null:
		print("[ac_games] impossible d'écrire %s" % out_path)
		get_tree().quit(1)
		return
	_out.seek_end()
	var t0 := Time.get_ticks_msec()
	for k in games:
		var line := play(seed0 + k, setup)
		_out.store_line(JSON.stringify(line))
		_out.flush()
		if (k + 1) % 25 == 0:
			print("[ac_games] %d / %d parties (%.1f s par partie)" % [k + 1, games, (Time.get_ticks_msec() - t0) / 1000.0 / (k + 1)])
	_out.close()
	print("[ac_games] %s : %d parties, %d bloquée(s), %.2f s par partie ; %s" % [setup, games, stuck,
		(Time.get_ticks_msec() - t0) / 1000.0 / games, ProjectSettings.globalize_path(out_path)])
	get_tree().quit(0 if stuck == 0 else 1)


static func parse_tune(v: String) -> Dictionary:
	var out := {}
	for part in v.split(",", false):
		var kv := part.split(":", true, 1)
		if kv.size() == 2:
			out[kv[0]] = kv[1].to_float() if kv[1].is_valid_float() else kv[1]
	return out


# --- Stratèges d'une mise en place ----------------------------------------------------------------------------------
## Les 8 IA d'une partie : [[difficulté, tempérament, graine], …].
static func seats_for(name: String, gs: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash([gs, "ac_games", name])
	var levels: Array = []
	match name:
		"echelle":
			levels = [0, 0, 1, 1, 2, 2, 3, 3]
		"l7r":
			levels = [3, 0, 0, 0, 0, 0, 0, 0]
		"r7l":
			levels = [0, 3, 3, 3, 3, 3, 3, 3]
		"legendes":
			levels = [3, 3, 3, 3, 3, 3, 3, 3]
		"pilote":
			levels = [1]
			var mix: Array = AutochessData.DIFFICULTIES[1].mix
			for k in mix.size():
				for _n in int(mix[k]):
					levels.append(k)
	# l'IA observée (l7r, r7l, pilote : la 1re) change de place d'une partie à l'autre
	var focal := gs % AutochessData.PLAYERS
	if name in ["l7r", "r7l", "pilote"]:
		var f: Variant = levels[0]
		var rest := levels.slice(1)
		for i in range(rest.size() - 1, 0, -1):
			var j := r.randi_range(0, i)
			var t: Variant = rest[i]
			rest[i] = rest[j]
			rest[j] = t
		rest.insert(focal, f)
		levels = rest
	else:
		for i in range(levels.size() - 1, 0, -1):
			var j := r.randi_range(0, i)
			var t: Variant = levels[i]
			levels[i] = levels[j]
			levels[j] = t
	var out: Array = []
	for i in AutochessData.PLAYERS:
		out.append([int(levels[i]), String(AutochessAi.TEMPERS[r.randi_range(0, 2)]), r.randi_range(0, 0x3fffffff),
			i == focal and name in ["l7r", "r7l", "pilote"]])
	return out


# --- Une partie ----------------------------------------------------------------------------------------------------
func play(gs: int, name: String) -> Dictionary:
	var t_start := Time.get_ticks_msec()
	var seats := seats_for(name, gs)
	var recs: Array = []
	for s in seats:
		var ai := AutochessAi.make(int(s[0]), String(s[1]), int(s[2]))
		ai.tune = ai_tune
		recs.append(Rec.new(ai))
	var g := Autochess.new()
	g.save_path = ""
	g.start(gs, recs, _fight)
	var t_prep := 0.0
	var t_recap := 0.0
	var t_fight := 0.0
	var t_fight_pve := 0.0
	var jcj: Array = []  # durées des combats JcJ
	var draws := 0
	var pve := [0, 0]  # [manches de monstres / gardiens gagnées, jouées]
	var last := {}  # stratège -> {board, traits, level} au dernier combat
	var out_at := {}  # stratège -> [manche, minutes]
	var guard := 0
	while not g.is_over() and guard < Autochess.MAX_ROUNDS * 3 + 10:
		guard += 1
		if g.phase == "prep":
			t_prep += g.prep_time()
			t_recap += AutochessData.ROUND_RECAP
		var ph := g.step()
		if ph == "combat":
			for pi in g.alive_ids():
				var tr := {}  # trait actif -> [palier, compte]
				var counts := g.trait_counts(pi)
				var tiers := g.active_traits(pi)
				for t in tiers:
					tr[t] = [int(tiers[t]), int(counts.get(t, 0))]
				last[pi] = {"board": _compact(g.board_snapshot(pi)), "traits": tr, "level": int(g.players[pi].level),
					"hp": int(g.players[pi].hp)}
		elif ph == "recap" or ph == "over":
			var longest := 0.0
			for i in g.results.size():
				var r: Dictionary = g.results[i]
				var d := float(r.duration)
				longest = maxf(longest, d)
				if String(g.fights[i].kind) == "jcj":
					jcj.append(snappedf(d, 0.1))
					draws += 1 if int(r.winner) < 0 else 0
				else:
					pve[1] += 1
					pve[0] += 1 if int(r.winner) == 0 else 0
			if not g.results.is_empty():
				t_fight += longest
				if g.round_kind() != "jcj":
					t_fight_pve += longest
			var now := (t_prep + t_recap + t_fight) / 60.0
			for p in g.players:
				if not bool(p.alive) and not out_at.has(int(p.id)):
					out_at[int(p.id)] = [g.round_key(), snappedf(now, 0.01), g.rounds_played]
	if not g.is_over():
		stuck += 1
		push_error("partie %d bloquée à %s" % [gs, g.round_key()])
	var total := (t_prep + t_recap + t_fight) / 60.0
	var players: Array = []
	for p in g.players:
		var pi := int(p.id)
		var rec: Rec = recs[pi]
		var l: Dictionary = last.get(pi, {})
		var oa: Array = out_at.get(pi, ["", snappedf(total, 0.01), g.rounds_played])
		var stars3 := 0
		for u in l.get("board", []):
			stars3 += 1 if int(u[1]) >= 3 else 0
		players.append({"ai": rec.ai.label(), "d": rec.ai.difficulty, "t": rec.ai.temperament, "focal": bool(seats[pi][3]),
			"place": int(p.place), "out": oa[0], "out_min": oa[1], "out_n": oa[2], "hp": int(p.hp), "level": rec.econ.level_end,
			"board": l.get("board", []), "traits": l.get("traits", {}), "augs": p.augments, "offers": rec.offers,
			"econ": rec.econ, "stats": p.stats, "s3": stars3})
	return {"v": Version.NUMBER, "setup": name, "seed": gs, "fight": fight_name, "rounds": g.rounds_played,
		"last": g.round_key(), "min": {"prep": snappedf(t_prep / 60.0, 0.01), "recap": snappedf(t_recap / 60.0, 0.01),
		"fight": snappedf(t_fight / 60.0, 0.01), "fight_pve": snappedf(t_fight_pve / 60.0, 0.01), "total": snappedf(total, 0.01)},
		"jcj": jcj, "draws": draws, "pve": pve, "players": players, "ms": Time.get_ticks_msec() - t_start}


## Plateau compact : [id, étoiles, [objets]].
static func _compact(board: Array) -> Array:
	var out: Array = []
	for u in board:
		out.append([String(u.id), int(u.stars), (u.get("items", []) as Array).duplicate()])
	return out
