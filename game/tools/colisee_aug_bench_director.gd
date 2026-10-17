extends Node
## Directeur du banc des atouts (tools/colisee_aug_bench.gd) : monté par TeamMatch comme celui du Colisée ; le joueur reste
## au repos (aucune arène) ; ARENAS combats simultanés, chacun trio contre le même trio, l'un portant l'atout du plan.

const FIGHT_TIME := Colisee.FIGHT_TIME
const COUNT := 1.0
const PARK := 1000

var d: RunDirector
var map: ProcMap
var arenas: Array = []
var fights: Array = []
var phase := "nav"
var _t := 0.0
var plan: Array = []
var next := 0
var done := 0
var rng := RandomNumberGenerator.new()
var diff := 3
var out_path := ""
var started := 0
var wins := {}  ## atout -> [victoires du porteur, combats]


func setup(director: RunDirector) -> void:
	d = director
	var augs: Array = []
	var n := 40
	var mode := "trio"
	var seed_value := 4242
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--augs="):
			for v in arg.trim_prefix("--augs=").split(",", true):
				augs += _all() if v == "all" else [v]
		elif arg.begins_with("--n="):
			n = int(arg.trim_prefix("--n="))
		elif arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--diff="):
			diff = clampi(int(arg.trim_prefix("--diff=")), 0, 3)
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--out="):
			out_path = arg.trim_prefix("--out=")
	if augs.is_empty():
		augs = _all()
	rng.seed = seed_value
	for a in augs:
		var m := "solo" if String(a) == "trio_parfait" else mode
		for k in n:
			plan.append({"aug": String(a), "mode": m, "side": k % 2})
	for i in range(plan.size() - 1, 0, -1):  # mélangé : la charge de la machine pèse pareil sur tous
		var j := rng.randi_range(0, i)
		var tmp = plan[i]
		plan[i] = plan[j]
		plan[j] = tmp
	d.zone = GameData.zone(Run.zone_id)
	map = ProcMap.new()
	map.biome = String(d.zone.get("biome", "limestone"))
	map.name = "ColiseeBench"
	d.world._swap_map(map)
	map.generate_colisee(seed_value % 100000, maxi(1, int(TeamMatch.team_count() / 2)))
	d.map = map
	d.world._apply_biome_env()
	arenas = ColiseeArena.build_all(map, self)
	var p := d.player
	TeamMatch.add(p, 0, PARK)
	p.visible = false
	p.set_physics_process(false)
	d._place_player(map.start + Vector3.UP * 60.0)
	ColiseeAugments.start()
	started = Time.get_ticks_msec()
	print("[cobench] plan : %d combats (%d atouts × %d), difficulté %d, %d arènes" % [plan.size(), augs.size(), n, diff, arenas.size()])


## Atouts mesurables en combat (l'or et la relève à part) + contrôle sans atout.
static func _all() -> Array:
	var out: Array = [""]
	for id in ColiseeAugments.ids():
		if id in ["tirelire", "mise", "releve_eclair"] or id in ColiseeAugments.RECIPE:
			continue
		out.append(id)
	return out + ColiseeAugments.RECIPE


func update(delta: float) -> void:
	TeamMatch.elapsed += delta
	match phase:
		"nav":
			if map._region.navigation_mesh != null:
				_start_batch()
		"count":
			_t -= delta
			if _t <= 0.0:
				for f in fights:
					for side in 2:
						for c in f.heroes[side]:
							if is_instance_valid(c):
								(c as ClassRival).passive = false
				phase = "fight"
		"fight":
			PvpCaps.elapsed += delta
			ColiseeAugments.tick(delta)
			for f in fights:
				if f.done:
					continue
				f.t = float(f.t) + delta
				var al_a := _alive(f, 0)
				var al_b := _alive(f, 1)
				(f.arena as ColiseeArena).tick(delta, al_a + al_b)
				al_a = _alive(f, 0)
				al_b = _alive(f, 1)
				if al_a.is_empty() or al_b.is_empty():
					_end(f, -1 if al_a.is_empty() and al_b.is_empty() else (0 if not al_a.is_empty() else 1))
				elif float(f.t) >= FIGHT_TIME:
					var la := _left(f, 0)
					var lb := _left(f, 1)
					_end(f, -1 if absf(la - lb) < 0.001 else (0 if la > lb else 1))
			if fights.all(func(x): return x.done):
				ColiseeAugments.end_fight()
				_clear()
				phase = "gap"
				_t = 0.3
		"gap":
			_t -= delta
			if _t <= 0.0:
				if next >= plan.size():
					_finish()
				else:
					_start_batch()


func _alive(f: Dictionary, side: int) -> Array:
	return (f.heroes[side] as Array).filter(func(c): return is_instance_valid(c) and not (c as Combatant).is_dead)


func _left(f: Dictionary, side: int) -> float:
	var s := 0.0
	for c in _alive(f, side):
		s += (c as Combatant).hp
	return s / maxf(float(f.max_hp[side]), 1.0)


func _start_batch() -> void:
	fights = []
	ColiseeAugments.reset_round()
	for k in arenas.size():
		if next >= plan.size():
			break
		var spec: Dictionary = plan[next]
		next += 1
		fights.append(_make(k, spec))
	var all: Array = []
	for f in fights:
		all += f.heroes[0] + f.heroes[1]
		(f.arena as ColiseeArena).reset(f.heroes[0] + f.heroes[1])
		for side in 2:
			f.max_hp[side] = 0.0
			for c in f.heroes[side]:
				f.max_hp[side] = float(f.max_hp[side]) + (c as Combatant).max_hp
	PvpCaps.elapsed = 0.0
	PvpCaps.board = {}
	ColiseeAugments.begin_fight(self, fights)
	phase = "count"
	_t = COUNT


func _make(k: int, spec: Dictionary) -> Dictionary:
	var arena: ColiseeArena = arenas[k]
	var trio: Array = Colisee.compose_teams(1, "", rng)[0]
	var f := {"index": k, "arena": arena, "spec": spec, "trio": trio, "heroes": [[], []], "max_hp": [0.0, 0.0], "t": 0.0, "done": false}
	for side in 2:
		var t := 1 + 2 * k + side
		var builds: Array = []
		for j in trio.size():
			var b := ColiseeBuild.new()
			b.cid = String(trio[j])
			b.team = t
			b.slot = j
			b.role = ColiseeBuild.role_of(b.cid)
			b.family = Duel.family_of(b.cid)
			b.diff = diff
			if side == int(spec.side) and (String(spec.mode) == "trio" or j == 0):
				_give(b, String(spec.aug))
			builds.append(b)
		for j in trio.size():
			var b: ColiseeBuild = builds[j]
			var r := TeamMatch.make_hero(b.cid, Colisee.LEVEL, diff, t, k, b.gear)
			r.passive = true
			add_child(r)
			r.global_position = arena.spawn_point(side, j, map) + Vector3.UP * 0.4
			r.look_at(Vector3(arena.center.x, r.global_position.y, arena.center.z), Vector3.UP)
			r.rotate_y(PI)
			ColiseeAugments.apply_hero(r, b, builds)
			ColiseeAnvil.grant_spells(r, b)
			(f.heroes[side] as Array).append(r)
	return f


## Construction du porteur : l'atout (Maître des sorts : le sort de plus pris tout de suite), ou des pièces / bonus d'enclume.
func _give(b: ColiseeBuild, aug: String) -> void:
	if aug == "":
		return
	if aug.begins_with("gear:") or aug.begins_with("stat:"):
		var kind := "piece" if aug.begins_with("gear:") else "stat"
		b.gold = 999
		for i in int(aug.get_slice(":", 1)):
			if ColiseeAnvil.open_anvil(b, kind, null):
				ColiseeAnvil.choose(b, ColiseeAnvil.choose_anvil(b.anvil.options, b), null)
		return
	b.augments.append(aug)
	if aug == "maitre_des_sorts":
		b.spell_slots = 1
		ColiseeAnvil.open_spells(b, rng)
		if not b.spell_offer.is_empty():
			ColiseeAnvil.take_spell(b, ColiseeAnvil.choose_spell(b.spell_offer, b))


func _end(f: Dictionary, w: int) -> void:
	f.done = true
	var spec: Dictionary = f.spec
	var holder := int(spec.side)
	var rec := {"aug": spec.aug, "mode": spec.mode, "side": holder, "winner": w, "holder_won": 1 if w == holder else (0 if w >= 0 else -1),
		"t": snappedf(float(f.t), 0.1), "left": [snappedf(_left(f, 0), 0.01), snappedf(_left(f, 1), 0.01)], "trio": f.trio, "diff": diff}
	done += 1
	var line := JSON.stringify(rec)
	print("[cobench] " + line)
	if out_path != "":
		var fa := FileAccess.open(out_path, FileAccess.READ_WRITE) if FileAccess.file_exists(out_path) else FileAccess.open(out_path, FileAccess.WRITE)
		if fa != null:
			fa.seek_end()
			fa.store_line(line)
			fa.close()
	var wl: Array = wins.get(String(spec.aug), [0, 0])
	wl[0] = int(wl[0]) + (1 if w == holder else 0)
	wl[1] = int(wl[1]) + 1
	wins[String(spec.aug)] = wl


func _clear() -> void:
	for f in fights:
		for side in 2:
			for c in f.heroes[side]:
				if is_instance_valid(c):
					TeamMatch.remove(c)
					(c as Node).queue_free()


func _finish() -> void:
	phase = "done"
	var keys := wins.keys()
	keys.sort()
	for k in keys:
		print("[cobench] bilan %-20s %d / %d" % [String(k) if String(k) != "" else "(aucun)", int(wins[k][0]), int(wins[k][1])])
	print("[cobench] fin : %d combats en %.1f min réelles" % [done, (Time.get_ticks_msec() - started) / 60000.0])
	ColiseeAugments.stop()
	get_tree().quit()


func player_down(_killer: Combatant) -> void:
	pass


func abandon() -> void:
	ColiseeAugments.stop()
	get_tree().quit()
