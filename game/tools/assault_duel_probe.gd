extends Node
## Sonde du combat de L'Assaut (lot TAC-4, rapport conception/benchmark/R_TAC_4.md) : règles du profil « assault »
## (TeamMatch « assault » ouvert, AssaultCombat actif), héros scriptés au niveau 50 avec leur kit tactique (signature + cases 2
## et 3 : achat complet), leur rôle et leurs passifs, en terrain plat sans murs. Deux mesures (cibles de l'étude § 7.6) :
##   - duel : un 1 contre 1 dure 7 à 10 s (médiane), du premier coup à la chute ;
##   - focus : 3 héros sur une cible qui ne se défend pas (ni esquive ni coup) : personne ne tombe en moins de ~3,5 s.
## godot --headless --fixed-fps 60 --path game res://tools/assault_duel_probe.tscn [-- --duels=60 --focus=24 --diff=2 --seed=1
##   --scale=0.13 --hit=0.25 --burst=0.55 --basic=0.8 --heal=0.3 --roles=rempart,ouvreur --same-role]
## Lignes [tac4] duel / focus par combat, puis la synthèse (médianes par rôle, part dans 7-10 s, plus court focus).

const LIMIT := 90.0
const BATCH := 24
const GAP := 300.0

var results: Array = []
var args := {}
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	Settings.reset_all(false)
	Profile.reset_all()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
		elif a.begins_with("--"):
			args[a.substr(2)] = "1"
	rng.seed = int(args.get("seed", "1"))
	var over := {}
	for k in [["scale", "dmg_scale"], ["hit", "hit_cap"], ["burst", "burst_cap"], ["basic", "basic_mult"], ["heal", "heal_mult"],
			["cc", "cc_mult"], ["excess", "burst_excess"], ["press", "pressure_start"], ["step", "pressure_step"]]:
		if args.has(k[0]):
			over[k[1]] = float(args[k[0]])
	if not over.is_empty():
		DevEdits.data["modes"] = {"assault": over}
	Assault.ensure_rules()
	TeamMatch.begin("assault", 2, {})
	Run.active = true
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameData.PHYS_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40000, 2, 40000)
	shape.shape = box
	shape.position.y = -1.0
	floor_body.add_child(shape)
	add_child(floor_body)
	print("[tac4] profil %s : échelle %.3f, coup %.2f, rafale %.2f, auto ×%.2f, soins ×%.2f, contrôles ×%.2f" % [ModeRules.profile_name(),
		PvpCaps.damage_scale(), ModeRules.num("hit_cap"), ModeRules.num("burst_cap"), PvpCaps.basic_mult(), ModeRules.num("heal_mult"),
		Assault.num("cc_mult")])
	var diff := int(args.get("diff", "2"))
	var by_role := _classes_by_role()
	var roles: Array = Array(String(args.get("roles", ",".join(AssaultCombat.ROLE_ORDER))).split(","))
	var cases: Array = []
	var n := int(args.get("duels", "60"))
	for i in n:
		var ra := String(roles[i % roles.size()])
		var rb := ra if args.has("same-role") else String(roles[rng.randi() % roles.size()])
		var a := _pick(by_role[ra])
		var b := _pick(by_role[rb])
		while b == a:
			b = _pick(by_role[rb])
		cases.append({"kind": "duel", "a": [a], "b": [b]})
	for i in int(args.get("focus", "24")):
		var victim := _pick(by_role[String(AssaultCombat.ROLE_ORDER[i % 5])])
		var hunters: Array = []
		while hunters.size() < 3:
			var c := _pick(GameData.classes.keys().filter(func(x): return not x in Assault.AI_EXCLUDED))
			if c != victim and not c in hunters:
				hunters.append(c)
		cases.append({"kind": "focus", "a": hunters, "b": [victim]})
	for start in range(0, cases.size(), BATCH):
		await _run_batch(cases.slice(start, start + BATCH), diff)
	_summary()
	TeamMatch.end()
	Run.active = false
	get_tree().quit()


func _classes_by_role() -> Dictionary:
	var out := {}
	for r in AssaultCombat.ROLE_ORDER:
		out[r] = []
	for cid in GameData.classes:
		if cid in Assault.AI_EXCLUDED:
			continue
		out[AssaultCombat.role_of_class(cid)].append(cid)
	for r in out:
		(out[r] as Array).sort()
	return out


func _pick(a: Array) -> String:
	return String(a[rng.randi() % a.size()])


func _run_batch(cases: Array, diff: int) -> void:
	var fights: Array = []
	for idx in cases.size():
		var c: Dictionary = cases[idx]
		var center := Vector3((idx % 6) * GAP, 0.5, (idx / 6) * GAP)
		var sides: Array = [[], []]
		for side in 2:
			var list: Array = c.a if side == 0 else c.b
			for j in list.size():
				var r := TeamMatch.make_hero(String(list[j]), 50, diff, side, idx)
				AssaultCombat.arm_rival(r, String(list[j]))
				add_child(r)
				r.global_position = center + Vector3(-5.0 + 10.0 * side, 0, (j - 1) * 2.5)
				if c.kind == "focus" and side == 1:
					r.passive = true  # la cible ne se défend pas
				sides[side].append(r)
		fights.append({"case": c, "sides": sides, "t0": -1.0, "t": 0.0, "done": false,
			"hp0": (sides[1][0] as Combatant).max_hp})
	var t := 0.0
	PvpCaps.board = {}
	while t < LIMIT and fights.any(func(f): return not f.done):
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		PvpCaps.elapsed = t
		for f in fights:
			if f.done:
				continue
			var a_dead := (f.sides[0] as Array).all(func(h): return not is_instance_valid(h) or (h as Combatant).is_dead)
			var b_dead := (f.sides[1] as Array).all(func(h): return not is_instance_valid(h) or (h as Combatant).is_dead)
			if f.t0 < 0.0:
				for side in f.sides:
					for h in side:
						if is_instance_valid(h) and float(PvpCaps.board.get((h as Node).get_instance_id(), {}).get("taken", 0.0)) > 0.0:
							f.t0 = t
			if a_dead or b_dead or t >= LIMIT - 0.05:
				f.done = true
				f.t = t - maxf(f.t0, 0.0)
				var c: Dictionary = f.case
				var winner := "-" if not (a_dead or b_dead) else ("b" if a_dead else "a")
				var e := {"kind": c.kind, "a": c.a, "b": c.b, "time": snappedf(f.t, 0.01), "winner": winner,
					"ra": AssaultCombat.role_of_class(String(c.a[0])), "rb": AssaultCombat.role_of_class(String(c.b[0]))}
				results.append(e)
				print("[tac4] %s %s/%s %s contre %s : %.2f s · gagnant %s" % [c.kind, e.ra, e.rb, "+".join(c.a), "+".join(c.b), f.t, winner])
	for f in fights:
		for side in f.sides:
			for h in side:
				if is_instance_valid(h):
					TeamMatch.remove(h)
					(h as Node).queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _med(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return float(s[s.size() / 2])


func _summary() -> void:
	var duels := results.filter(func(e): return e.kind == "duel" and e.winner != "-")
	var focus := results.filter(func(e): return e.kind == "focus" and e.winner != "-")
	var times: Array = duels.map(func(e): return float(e.time))
	var inside := times.filter(func(x): return x >= 7.0 and x <= 10.0).size()
	var unfinished := results.filter(func(e): return e.winner == "-").size()
	print("[tac4] --- duels : %d finis, %d inachevés (%d s) ---" % [duels.size(), unfinished, int(LIMIT)])
	if not times.is_empty():
		var s := times.duplicate()
		s.sort()
		print("[tac4] duel médian %.1f s (10e %.1f, 90e %.1f) ; dans 7-10 s : %d sur %d" % [_med(times), s[s.size() / 10],
			s[mini(s.size() - 1, s.size() * 9 / 10)], inside, times.size()])
	for r in AssaultCombat.ROLE_ORDER:
		var mine := duels.filter(func(e): return e.ra == r or e.rb == r)
		var wins := duels.filter(func(e): return (e.ra == r and e.winner == "a" and e.rb != r) or (e.rb == r and e.winner == "b" and e.ra != r)).size()
		var cross := duels.filter(func(e): return (e.ra == r) != (e.rb == r)).size()
		print("[tac4] rôle %-10s : %2d duels, médiane %.1f s, victoires contre les autres rôles %d / %d" % [r, mine.size(),
			_med(mine.map(func(e): return float(e.time))), wins, cross])
	if not focus.is_empty():
		var ft: Array = focus.map(func(e): return float(e.time))
		ft.sort()
		print("[tac4] --- focus (3 sur 1, cible passive) : médiane %.1f s, plus court %.2f s, sous 3,5 s : %d sur %d ---" % [_med(ft),
			ft[0], ft.filter(func(x): return x < 3.5).size(), ft.size()])
		for r in AssaultCombat.ROLE_ORDER:
			var m := focus.filter(func(e): return e.rb == r).map(func(e): return float(e.time))
			if not m.is_empty():
				m.sort()
				print("[tac4] cible %-10s : médiane %.1f s, plus court %.2f s" % [r, _med(m), m[0]])
	print("[tac4] mesure : " + JSON.stringify({"duel_med": _med(times), "duel_in": inside, "duels": times.size(),
		"focus_min": (focus.map(func(e): return float(e.time)).min() if not focus.is_empty() else 0.0),
		"focus_med": _med(focus.map(func(e): return float(e.time)))}))
