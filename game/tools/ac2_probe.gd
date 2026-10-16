extends Node
## AC2 (sonde technique du mode « autochess », conception/autochess/R_AC2.md) : des héros posés sur un plateau de 8 × 8 cases
## (2 m), deux camps, qui se battent seuls ; mesures de coût, de durée, de stabilité et de comportement. Rien n'est écrit.
## Lancer (APPDATA détourné conseillé : aucun profil touché) :
##   Godot --headless --fixed-fps 60 --path game res://tools/ac2_probe.tscn -- --mode=<mode> [options]
## Modes :
##   kits      : les 60 classes, sorts lancés par l'IA scriptée et par le cerveau, alertes (aucun combat)
##   cpu       : coût par image selon le nombre d'unités (--units=6,10,16,24), unités immortelles, --pilot=script|brain
##   fights    : combats NvN (--sizes=3,5,8 --reps=20), --pilot=script|brain|mixed (cerveaux camp A, scriptés camp B)
##   classes   : chaque classe dans --reps combats 3v3 (camp A : elle + 2 au hasard) : tableau par classe
##   bench     : banc « qualité de jeu » : mêmes équipes des deux côtés (miroir), IA v2 (tools/ac2_unit.gd) contre IA v1
##               (ClassRival), côtés alternés ; --sizes=3,5,8 --reps=50 ; témoin --ai=v1 / --ai=v2 (v1 contre v1, v2 contre v2)
##   stars     : paliers d'étoile : 1v1 et 3v3 miroirs, camp A × --k=1.8,3.24 (PV et attaque), et 1 × k contre n × 1
## Options : --level=10 --diff=2 (scripté 0-3) --brain=hardcore|actuel --temp=0 --rules=arena3 (profil ModeRules)
##   --scale=0.05 --heal=0.17 --pressure=15 --sudden=45 : essai d'un réglage du profil (en mémoire seulement)
##   --limit=180 (s) --batch=16 (plateaux simulés ensemble, loin les uns des autres) --camps=ffa|native --seed=1
## Camps : ffa = Combatant.ffa_id = numéro du camp (coups et cibles de l'autre camp seulement) ; native = alliés du joueur
## (ClassRival.ally) contre adversaires (soins et renforts d'équipe de ClassRival), un plateau à la fois, scripté seulement.
## Lignes : [ac2] …

const CELL := 2.0
const COLS := 8
const ROWS := 8
const SPACING := 400.0
const SAMPLE := 0.25
const IDLE_AFTER := 3.0  # sans dégâts infligés depuis IDLE_AFTER s (ennemis debout) : unité inactive
const FAR := 6.0  # plus loin que FAR m de l'ennemi le plus proche
const COL_ORDER := [3, 4, 2, 5, 1, 6, 0, 7]
const AC_UNIT := preload("res://tools/ac2_unit.gd")  # prototype « IA v2 » (R_AC2 §3)

var args := {}
var level := 10
var diff := 2
var limit := 180.0
var batch := 16
var camps := "ffa"
var temp := 0.0
var brain_key := "hardcore"
var brain: MlBrain
var _boards: Array = []  # plateaux en cours (pour le pilotage des cerveaux)
var _brain_usec := 0
var _brain_calls := 0
var _net_usec := 0  # part du réseau (MlBrain.act) dans _brain_usec
var _stagger := 0
var _ffa_next := 0


func _ready() -> void:
	process_physics_priority = -200  # décisions des cerveaux avant le déplacement des héros (comme MlDuelPilot)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			args[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
		elif a.begins_with("--"):
			args[a.substr(2)] = "1"
	level = int(args.get("level", "10"))
	diff = int(args.get("diff", "2"))
	limit = float(args.get("limit", "180"))
	batch = int(args.get("batch", "16"))
	camps = String(args.get("camps", "ffa"))
	temp = float(args.get("temp", "0"))
	brain_key = String(args.get("brain", "hardcore"))
	seed(int(args.get("seed", "1")))
	if String(args.get("pilot", "script")) != "script":
		camps = "ffa"  # les héros pilotés par un cerveau (Player, foe) n'ont de camp que par ffa_id
	_setup_state()
	# réglages de l'IA v2 : --v2=read:0.3,reflex:0,stick:1… (voir tools/ac2_unit.gd, opts)
	for kv in String(args.get("v2", "")).split(",", false):
		AC_UNIT.opts[kv.get_slice(":", 0)] = float(kv.get_slice(":", 1))
	var mode := String(args.get("mode", "fights"))
	print("[ac2] mode %s · niveau %d · scripté %s · cerveau %s · règles %s (échelle %.3f, acharnement dès %d s, mort subite dès %d s) · camps %s" % [
		mode, level, ClassRival.NAMES[diff], brain_key, ModeRules.profile_name(), PvpCaps.damage_scale(), int(PvpCaps.pressure_start()),
		int(ModeRules.num("sudden_after", 100000.0)), camps])
	match mode:
		"kits":
			_kits()
		"cpu":
			await _cpu()
		"fights":
			await _fights()
		"classes":
			await _classes()
		"stars":
			await _stars()
		"bench":
			await _bench()
		_:
			print("[ac2] mode inconnu : ", mode)
	get_tree().quit()


func _setup_state() -> void:
	Training.active = true  # aucune sauvegarde (comme l'arène d'IA)
	Training.hero_god = false
	Training.enemies_immortal = false
	Training.enemies_passive = false
	Vfx.silent = true
	var ui: Dictionary = Settings.data.get("interface", {})
	ui["hit_stop"] = false
	ui["damage_numbers"] = "off"
	Settings.data["interface"] = ui
	# règles d'équipe des Arènes : Duel actif (règles JcJ, mode d'équipe de ClassRival : cible le plus faible, lit les
	# zones, se replie) ; héros nus (Duel.bare) au niveau --level
	Duel.active = true
	Duel.mode = "arena3"
	Duel.bare = true
	Duel.extra_foes = ["ac2"]
	Duel.level = level
	Duel.difficulty = diff
	ModeRules.forced = String(args.get("rules", "arena3"))
	# essais de réglage sans toucher au code (DevEdits en mémoire, rien n'est écrit) : --scale=0.05 (dmg_scale),
	# --heal=0.17 (heal_mult), --pressure=15 (pressure_start), --sudden=45 (sudden_after)
	var over := {}
	for pair in [["scale", "dmg_scale"], ["heal", "heal_mult"], ["pressure", "pressure_start"], ["sudden", "sudden_after"]]:
		if args.has(pair[0]):
			over[pair[1]] = float(args[pair[0]])
	if not over.is_empty():
		DevEdits.data["modes"] = {ModeRules.forced: over}
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameData.PHYS_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20000, 2, 20000)
	shape.shape = box
	shape.position.y = -1.0
	floor_body.add_child(shape)
	add_child(floor_body)
	if String(args.get("pilot", "script")) != "script" or String(args.get("mode", "")) == "cpu":
		brain = MlBrain.load_file("res://data/cerveaux/cerveau_%s.json" % brain_key)


# --- plateau et unités ----------------------------------------------------------------------

static func is_ranged(cid: String) -> bool:
	return WeaponAttacks.rival_step(String(GameData.class_data(cid).get("weapon_type", "katana"))).has("range")


## Plateau [param idx] : murs, unités des deux camps placées en formation (mêlée devant, distance derrière).
## spec : {a: [classes], b: [classes], pa / pb: "script"|"brain", ka / kb: multiplicateur PV et attaque (étoiles), immortal}.
func _make_board(idx: int, spec: Dictionary) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var origin := Vector3((idx % 8) * SPACING, 0.0, (idx / 8) * SPACING)
	var half := COLS * CELL * 0.5
	for side in 4:
		var wall := StaticBody3D.new()
		wall.collision_layer = GameData.PHYS_WORLD
		var ws := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(COLS * CELL + 2.0, 6.0, 1.0)
		ws.shape = wb
		wall.add_child(ws)
		root.add_child(wall)
		var ang := side * PI * 0.5
		wall.global_position = origin + Vector3(sin(ang), 0, cos(ang)) * (half + 0.5) + Vector3.UP * 3.0
		wall.rotation.y = ang
	var b := {"root": root, "origin": origin, "half": half, "spec": spec, "units": [], "t": 0.0, "done": false,
		"focus": [0.0, 0.0], "focus_n": [0, 0], "ids": [0, 1], "lost": 0}
	if camps == "ffa":
		b.ids = [_ffa_next, _ffa_next + 1]
		_ffa_next += 2
	for team in 2:
		var list: Array = spec.a if team == 0 else spec.b
		var pilot := String(spec.get("pa" if team == 0 else "pb", "script"))
		var k := float(spec.get("ka" if team == 0 else "kb", 1.0))
		var ai := String(spec.get("ia" if team == 0 else "ib", String(args.get("ai", "v1"))))
		# cases : mêlée de la rangée de devant vers l'arrière, distance de l'arrière vers l'avant
		var melee: Array = list.filter(func(c): return not is_ranged(c))
		var ranged: Array = list.filter(func(c): return is_ranged(c))
		var cells := {}
		var placed: Array = []
		for group in [[melee, 1], [ranged, -1]]:
			for cid in group[0]:
				var cell := _free_cell(cells, team, int(group[1]))
				cells[cell] = true
				placed.append([cid, cell])
		for pc in placed:
			var cell: Vector2i = pc[1]
			var at := origin + Vector3((cell.x - 3.5) * CELL, 0.4, (cell.y - 3.5) * CELL)
			var u := _make_unit(String(pc[0]), team, pilot, k, b, at, ai)
			if spec.get("immortal", false):
				u.node.immortal = true
			b.units.append(u)
	return b


## Case libre du camp [param team] (rangées 0-3 : camp A, 4-7 : camp B) ; dir 1 : de l'avant vers l'arrière.
func _free_cell(cells: Dictionary, team: int, dir: int) -> Vector2i:
	var rows: Array = [3, 2, 1, 0] if team == 0 else [4, 5, 6, 7]
	if dir < 0:
		rows.reverse()
	for r in rows:
		for c in COL_ORDER:
			var cell := Vector2i(c, r)
			if not cells.has(cell):
				return cell
	return Vector2i(0, rows[0])


func _make_unit(cid: String, team: int, pilot: String, k: float, b: Dictionary, at: Vector3, ai := "v1") -> Dictionary:
	var u := {"cid": cid, "team": team, "pilot": pilot, "alive_t": 0.0, "idle_t": 0.0, "far_t": 0.0, "away_t": 0.0, "stuck_t": 0.0,
		"dist_sum": 0.0, "coh_sum": 0.0, "coh_n": 0, "samples": 0, "autos": 0, "skills": 0, "dodges": 0, "last_hit": 0.0,
		"last_dealt": 0.0, "pos_mark": at, "pos_t": 0.0, "prev_combo": 0, "prev_state": "", "prev_charges": 0.0,
		"died_at": -1.0, "off": false, "helper": null, "spawn_ms": 0.0}
	var t0 := Time.get_ticks_usec()
	if pilot == "brain" and brain != null:
		var h := Player.new()
		h.foe = true
		h.class_id = cid
		h.level = level
		h.built = true
		h.foe_gear = {}
		h.foe_extra = {} if is_equal_approx(k, 1.0) else {"hp_pct": k - 1.0, "atk_pct": k - 1.0, "matk_pct": k - 1.0}
		var kit := MlDuelPilot.kit_for(cid)
		h.kit_skills = kit.skills
		h.kit_chains = kit.chains
		b.root.add_child(h)
		h.global_position = at
		h.face_direction(b.origin - at, 1.0, 100.0)
		var helper := MlDuelPilot.new()
		b.root.add_child(helper)
		helper.set_physics_process(false)  # piloté par la sonde (_physics_process), une décision toutes les REPEAT images
		helper.foe = h
		helper.center = b.origin
		helper._ep = {"scenario": "duel", "difficulty": 3, "skills": 12}
		helper._max_time = 180.0
		helper.brain = brain
		h.bot = helper._pilot_bot
		helper._pilot_obs = helper._build_class_obs(h)
		if not args.has("sync"):
			# décisions étalées sur les REPEAT images (sinon toutes les unités décident à la même image : pics)
			helper._pilot_wait = _stagger % MlArena.REPEAT
			_stagger += 1
		u.helper = helper
		u.node = h
		u.prev_state = h._state
	else:
		u.pilot = "v2" if ai == "v2" else "script"
		var r: ClassRival = AC_UNIT.new() if ai == "v2" else ClassRival.new()
		r.ally = camps == "native" and team == 0
		r.setup(cid, level, diff)
		var sheet := Royale.sheet(cid, level, {})  # fiche d'un héros nu de ce niveau (comme le Battle royale)
		r.use_sheet(sheet)
		sheet.free()
		r.max_hp *= k
		r.atk *= k
		r.hp = r.max_hp
		if ai == "v2":
			r.ac_tune()
		r.display_name = "%s %s" % ["A" if team == 0 else "B", cid]
		b.root.add_child(r)
		r.global_position = at
		r.look_at(Vector3(b.origin.x, at.y, b.origin.z), Vector3.UP)
		r.rotate_y(PI)
		u.node = r
		u.prev_charges = r._charges
	if camps == "ffa" or pilot == "brain":
		u.node.set_ffa(int(b.ids[team]))
	u.iid = u.node.get_instance_id()  # (les héros scriptés tombés sont libérés : le tableau des dégâts garde leur id)
	u.spawn_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return u


func _enemies(b: Dictionary, u: Dictionary) -> Array:
	var out: Array = []
	for o in b.units:
		if o.team != u.team and is_instance_valid(o.node) and not o.node.is_dead:
			out.append(o.node)
	return out


func _alive(b: Dictionary, team: int) -> Array:
	return b.units.filter(func(o): return o.team == team and is_instance_valid(o.node) and not o.node.is_dead)


func _nearest(from: Node3D, list: Array) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for n in list:
		var d: float = n.global_position.distance_squared_to(from.global_position)
		if d < bd:
			bd = d
			best = n
	return best


## Décisions des cerveaux (avant le déplacement des héros) ; temps de calcul mesuré (observation + réseau + action).
func _physics_process(delta: float) -> void:
	for b in _boards:
		if b.done:
			continue
		for u in b.units:
			if u.helper == null or not is_instance_valid(u.node) or u.node.is_dead:
				continue
			var hp: MlDuelPilot = u.helper
			if hp._pilot_wait > 0:
				hp._pilot_wait -= 1
				hp._pilot_bot.pulse.clear()
				continue
			var opps := _enemies(b, u)
			if opps.is_empty():
				hp._pilot_bot.clear()
				continue
			var t0 := Time.get_ticks_usec()
			hp._t = float(b.t)
			var obs := hp._obs_for(u.node, opps, hp._pilot_obs, hp._pilot_last, 0.0)
			var t1 := Time.get_ticks_usec()
			var act := brain.act(obs, temp)
			_net_usec += Time.get_ticks_usec() - t1
			hp._pilot_last = hp._apply_for(hp._pilot_bot, u.node, opps, act)
			hp._pilot_wait = MlArena.REPEAT - 1
			_brain_usec += Time.get_ticks_usec() - t0
			_brain_calls += 1


# --- simulation ------------------------------------------------------------------------------

## Simule les plateaux [param boards] jusqu'à la fin de chacun (un camp à terre) ou [member limit] s.
## Rend {frames, usec (temps réel total des images), frame_usec: Array}.
func _simulate(boards: Array, fixed_time := -1.0) -> Dictionary:
	_boards = boards
	PvpCaps.board = {}
	PvpCaps.elapsed = 0.0
	var t := 0.0
	var next_sample := SAMPLE
	var frame_usec: Array = []
	var stop := fixed_time if fixed_time > 0.0 else limit
	while t < stop and (fixed_time > 0.0 or boards.any(func(bb): return not bb.done)):
		var f0 := Time.get_ticks_usec()
		await get_tree().physics_frame
		frame_usec.append(Time.get_ticks_usec() - f0)
		var dt := get_physics_process_delta_time()
		t += dt
		PvpCaps.elapsed = t
		var sample := t >= next_sample
		if sample:
			next_sample += SAMPLE
		for b in boards:
			if b.done:
				continue
			b.t = t
			_frame_track(b, t, sample)
			if fixed_time > 0.0:
				continue
			var a_alive := _alive(b, 0).size()
			var b_alive := _alive(b, 1).size()
			if a_alive == 0 or b_alive == 0 or t >= limit - 0.01:
				_finish(b, t, a_alive, b_alive)
	for b in boards:
		if not b.done:
			_finish(b, t, _alive(b, 0).size(), _alive(b, 1).size())
	_boards = []
	await get_tree().process_frame
	return {"frames": frame_usec.size(), "frame_usec": frame_usec}


func _frame_track(b: Dictionary, t: float, sample: bool) -> void:
	for u in b.units:
		var nv: Variant = u.node
		if not is_instance_valid(nv) or (nv as Combatant).is_dead:
			if u.died_at < 0.0:
				u.died_at = t
			continue
		var n: Combatant = nv
		if n.is_dead:
			if u.died_at < 0.0:
				u.died_at = t
			continue
		# actions : coups de l'arme, sorts, esquives
		if n is ClassRival:
			var r := n as ClassRival
			# camps natifs : un adversaire dont la cible est tombée ne se retourne que s'il reste plus d'un héros
			# (Monster._physics_process) ; la sonde lui redonne l'ennemi le plus proche et compte le cas
			if camps == "native" and (not is_instance_valid(r._player) or r._player.is_dead):
				var nf := _nearest(r, _enemies(b, u))
				if nf != null and r._time > 1.0:
					r._player = nf
					b.lost += 1
			if r._state == "attack" and u.prev_state != "attack":
				if r._combo_i != u.prev_combo:
					u.autos += 1
				else:
					u.skills += 1
			u.prev_combo = r._combo_i
			u.prev_state = r._state
			if r._charges < float(u.prev_charges) - 0.5:
				u.dodges += 1
			u.prev_charges = r._charges
		else:
			var p := n as Player
			if p._state != u.prev_state:
				match String(p._state):
					"attack":
						u.autos += 1
					"skill":
						u.skills += 1
					"dodge", "jump":
						u.dodges += 1
			u.prev_state = p._state
		if not sample:
			continue
		u.alive_t += SAMPLE
		u.samples += 1
		var foes := _enemies(b, u)
		var near := _nearest(n, foes)
		var dealt := float(PvpCaps.board.get(u.iid, {}).get("dealt", 0.0))
		if dealt > float(u.last_dealt) + 0.01:
			u.last_hit = t
			u.last_dealt = dealt
		if near != null and t - float(u.last_hit) > IDLE_AFTER:
			u.idle_t += SAMPLE
		if near != null:
			var to := near.global_position - n.global_position
			to.y = 0.0
			var d := to.length()
			u.dist_sum += d
			if d > FAR:
				u.far_t += SAMPLE
			var v := n.velocity
			v.y = 0.0
			if d > 0.1 and v.dot(to / d) < -2.0:
				u.away_t += SAMPLE  # s'éloigne de l'ennemi le plus proche (fuite, repli, recul de tireur)
		# cohésion : distance au centre des équipiers vivants
		var mates: Array = _alive(b, u.team).filter(func(o): return o.node != n)
		if not mates.is_empty():
			var c := Vector3.ZERO
			for o in mates:
				c += o.node.global_position
			c /= mates.size()
			u.coh_sum += Vector2(c.x - n.global_position.x, c.z - n.global_position.z).length()
			u.coh_n += 1
		# bloqué : a bougé de moins de 0,3 m en 2 s, loin de tout ennemi
		if t - float(u.pos_t) >= 2.0:
			var moved := Vector2(n.global_position.x - u.pos_mark.x, n.global_position.z - u.pos_mark.z).length()
			if moved < 0.3 and near != null and n.global_position.distance_to(near.global_position) > 4.5:
				u.stuck_t += 2.0
			u.pos_mark = n.global_position
			u.pos_t = t
		var off: Vector3 = n.global_position - b.origin
		if absf(off.x) > b.half + 1.0 or absf(off.z) > b.half + 1.0 or n.global_position.y < -3.0:
			u.off = true
	if sample:
		# concentration : cibles distinctes / unités vivantes du camp (1 : chacun la sienne ; petit : tout le camp sur une)
		for team in 2:
			var alive := _alive(b, team)
			if alive.is_empty():
				continue
			var targets := {}
			for o in alive:
				var tg: Variant = null
				if o.node is ClassRival:
					tg = (o.node as ClassRival)._player
				else:
					tg = _nearest(o.node, _enemies(b, o))
				if tg != null and is_instance_valid(tg):
					targets[tg.get_instance_id()] = true
			b.focus[team] += float(targets.size()) / float(alive.size())
			b.focus_n[team] += 1


func _finish(b: Dictionary, t: float, a_alive: int, b_alive: int) -> void:
	b.done = true
	b.t = t
	b.winner = "A" if b_alive == 0 and a_alive > 0 else ("B" if a_alive == 0 and b_alive > 0 else "=")
	b.survivors = maxi(a_alive, b_alive)
	var dealt := [0.0, 0.0]
	var taken := [0.0, 0.0]
	for u in b.units:
		var e: Dictionary = PvpCaps.board.get(u.iid, {})
		u.dealt = float(e.get("dealt", 0.0))
		dealt[u.team] += u.dealt
		taken[u.team] += float(e.get("taken", 0.0))
		u.won = b.winner == ("A" if u.team == 0 else "B")
	# dégâts reçus par un camp qui ne viennent pas de l'autre camp (tirs alliés, zones sans source) : part du total
	b.stray = (absf(taken[1] - dealt[0]) + absf(taken[0] - dealt[1])) / maxf(taken[0] + taken[1], 1.0)
	b.dealt = dealt
	if is_instance_valid(b.root):
		b.root.queue_free()


# --- modes -----------------------------------------------------------------------------------

func _all_classes() -> Array:
	var c: Array = GameData.classes.keys()
	c.sort()
	return c


func _random_team(n: int, avoid: Array = []) -> Array:
	var pool: Array = _all_classes().filter(func(c): return not c in avoid)
	pool.shuffle()
	return pool.slice(0, n)


func _run_specs(specs: Array) -> Array:
	var done: Array = []
	var bs := batch if camps == "ffa" else 1
	for start in range(0, specs.size(), bs):
		var boards: Array = []
		var i := 0
		for s in specs.slice(start, start + bs):
			boards.append(_make_board(i, s))
			i += 1
		await _simulate(boards)
		for b in boards:
			_print_board(b)
		done.append_array(boards)
	return done


func _print_board(b: Dictionary) -> void:
	var s: Dictionary = b.spec
	var pil := "%s/%s" % [s.get("pa", "script"), s.get("pb", "script")]
	var off: int = b.units.filter(func(u): return u.off).size()
	var stuck := 0.0
	for u in b.units:
		stuck += float(u.stuck_t)
	print("[ac2] combat %dv%d %s%s : %5.1f s · gagnant %s · survivants %d · mort subite %s · bloqué %.0f s · hors plateau %d · dégâts égarés %.1f%% · cibles perdues %d · A %s · B %s" % [
		s.a.size(), s.b.size(), pil, (" k=%.2f/%.2f" % [float(s.get("ka", 1.0)), float(s.get("kb", 1.0))]) if s.has("ka") or s.has("kb") else "",
		b.t, b.winner, b.survivors, "oui" if b.t > ModeRules.num("sudden_after", 100000.0) else "non", stuck, off, b.stray * 100.0, b.lost,
		",".join(s.a), ",".join(s.b)])


func _median(xs: Array) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	return float(s[s.size() / 2])


func _pct(xs: Array, q: float) -> float:
	if xs.is_empty():
		return 0.0
	var s := xs.duplicate()
	s.sort()
	return float(s[clampi(int(q * (s.size() - 1)), 0, s.size() - 1)])


## Synthèse d'une série de combats : durées, mort subite, nuls, comportement des unités.
func _summary(label: String, boards: Array) -> void:
	var ts: Array = boards.map(func(b): return float(b.t))
	var late := ModeRules.num("sudden_after", 100000.0)
	var sudden := boards.filter(func(b): return float(b.t) > late).size()
	var draws := boards.filter(func(b): return b.winner == "=").size()
	var in_band := boards.filter(func(b): return float(b.t) >= 20.0 and float(b.t) <= 40.0).size()
	var wins_a := boards.filter(func(b): return b.winner == "A").size()
	print("[ac2] === %s : %d combats · durée médiane %.1f s [p25 %.1f · p75 %.1f · min %.1f · max %.1f] · 20-40 s : %d%% · mort subite : %d%% · nuls (%d s) : %d%% · camp A gagne %d%%" % [
		label, boards.size(), _median(ts), _pct(ts, 0.25), _pct(ts, 0.75), _pct(ts, 0.0), _pct(ts, 1.0),
		roundi(100.0 * in_band / maxf(boards.size(), 1)), roundi(100.0 * sudden / maxf(boards.size(), 1)), int(limit),
		roundi(100.0 * draws / maxf(boards.size(), 1)), roundi(100.0 * wins_a / maxf(boards.size(), 1))])
	for pilot in ["script", "v2", "brain"]:
		var us: Array = []
		for b in boards:
			us.append_array(b.units.filter(func(u): return u.pilot == pilot))
		if us.is_empty():
			continue
		var m := _unit_means(us)
		print("[ac2]     %-6s : inactif %d%% · loin (> %d m) %d%% · s'éloigne %d%% · bloqué %d%% · distance à l'ennemi %.1f m · aux équipiers %.1f m · coups/s %.2f · sorts/s %.2f · esquives/s %.2f · hors plateau %d" % [
			{"script": "IA v1", "v2": "IA v2", "brain": "cerveau"}[pilot], m.idle, int(FAR), m.far, m.away, m.stuck, m.dist, m.coh, m.autos, m.skills, m.dodges, m.off])
	var f := [0.0, 0.0]
	var fn := [0, 0]
	for b in boards:
		for team in 2:
			f[team] += float(b.focus[team])
			fn[team] += int(b.focus_n[team])
	var stray := 0.0
	for b in boards:
		stray = maxf(stray, float(b.stray))
	print("[ac2]     concentration (cibles distinctes / unités, 1 = chacun la sienne) : A %.2f · B %.2f · dégâts égarés (max) %.2f%%" % [
		f[0] / maxf(fn[0], 1), f[1] / maxf(fn[1], 1), stray * 100.0])


func _unit_means(us: Array) -> Dictionary:
	var alive := 0.0
	var m := {"idle": 0.0, "far": 0.0, "away": 0.0, "stuck": 0.0, "dist": 0.0, "coh": 0.0, "autos": 0.0, "skills": 0.0, "dodges": 0.0, "off": 0}
	var samples := 0
	var coh_n := 0
	for u in us:
		alive += float(u.alive_t)
		m.idle += float(u.idle_t)
		m.far += float(u.far_t)
		m.away += float(u.away_t)
		m.stuck += float(u.stuck_t)
		m.dist += float(u.dist_sum)
		samples += int(u.samples)
		m.coh += float(u.coh_sum)
		coh_n += int(u.coh_n)
		m.autos += float(u.autos)
		m.skills += float(u.skills)
		m.dodges += float(u.dodges)
		m.off += 1 if u.off else 0
	var a := maxf(alive, 0.01)
	return {"idle": roundi(100.0 * m.idle / a), "far": roundi(100.0 * m.far / a), "away": roundi(100.0 * m.away / a),
		"stuck": roundi(100.0 * m.stuck / a), "dist": m.dist / maxf(samples, 1), "coh": m.coh / maxf(coh_n, 1),
		"autos": m.autos / a, "skills": m.skills / a, "dodges": m.dodges / a, "off": m.off}


func _fights() -> void:
	var sizes: Array = Array(String(args.get("sizes", "3,5,8")).split(",")).map(func(x): return int(x))
	var reps := int(args.get("reps", "20"))
	var pilot := String(args.get("pilot", "script"))
	for n in sizes:
		var specs: Array = []
		for r in reps:
			var a := _random_team(n)
			var bb := _random_team(n)
			if args.has("team"):  # --team=warrior,hunter : mêmes classes des deux côtés (diagnostic)
				a = Array(String(args.team).split(",")).slice(0, n)
				bb = a.duplicate()
			var pa := "brain" if pilot in ["brain", "mixed"] else "script"
			var pb := "brain" if pilot == "brain" else "script"
			specs.append({"a": a, "b": bb, "pa": pa, "pb": pb})
		var t0 := Time.get_ticks_msec()
		var boards: Array = await _run_specs(specs)
		_summary("%dv%d %s" % [n, n, pilot], boards)
		print("[ac2]     temps réel : %.1f s pour %d combats" % [(Time.get_ticks_msec() - t0) / 1000.0, reps])


func _classes() -> void:
	var reps := int(args.get("reps", "3"))
	var size := int(args.get("size", "3"))
	var specs: Array = []
	for cid in _all_classes():
		for r in reps:
			var a: Array = [cid] + _random_team(size - 1, [cid])
			specs.append({"a": a, "b": _random_team(size, a)})
	var boards: Array = await _run_specs(specs)
	_summary("classes %dv%d" % [size, size], boards)
	var by := {}
	for b in boards:
		for u in b.units:
			if not by.has(u.cid):
				by[u.cid] = []
			by[u.cid].append(u)
	var rows: Array = []
	for cid in by:
		var us: Array = by[cid]
		var m := _unit_means(us)
		var wins := us.filter(func(u): return u.won).size()
		var deaths := us.filter(func(u): return float(u.died_at) >= 0.0).size()
		# part des dégâts de son camp (1/taille = moyenne)
		var share := 0.0
		for u in us:
			share += float(u.dealt) / maxf(_team_dealt(boards, u), 1.0)
		rows.append([cid, us.size(), 100.0 * wins / us.size(), 100.0 * deaths / us.size(), share / us.size() * size, m])
	rows.sort_custom(func(x, y): return x[4] > y[4])
	print("[ac2] --- par classe (part des dégâts de son camp × %d : 1,00 = moyenne) ---" % size)
	for row in rows:
		var m: Dictionary = row[5]
		print("[ac2] classe %-20s %-14s n=%2d · victoires %3.0f%% · morts %3.0f%% · dégâts ×%.2f · inactif %2d%% · loin %2d%% · s'éloigne %2d%% · coups/s %.2f · sorts/s %.2f · esquives/s %.2f · distance %.1f m" % [
			row[0], String(GameData.class_data(row[0]).get("name_fr", "")), row[1], row[2], row[3], row[4], m.idle, m.far, m.away, m.autos, m.skills, m.dodges, m.dist])


func _team_dealt(boards: Array, u: Dictionary) -> float:
	for b in boards:
		if u in b.units:
			return float(b.dealt[u.team])
	return 1.0


func _stars() -> void:
	var reps := int(args.get("reps", "4"))
	var ks: Array = Array(String(args.get("k", "1.8,3.24")).split(",")).map(func(x): return float(x))
	var cls := ["warrior", "magician", "cleric", "hunter", "assassin", "paladin", "berserker", "knight"]
	for k in [1.0] + ks:
		for n in [1, 3]:
			var specs: Array = []
			for r in reps:
				for c in cls:
					var team: Array = [c] if n == 1 else [c] + _random_team(2, [c])
					specs.append({"a": team, "b": team.duplicate(), "ka": k, "kb": 1.0})
			var boards: Array = await _run_specs(specs)
			_summary("étoiles %dv%d miroir, camp A ×%.2f" % [n, n, k], boards)
	# une unité étoilée contre plusieurs unités simples de la même classe (en autochess : 3 unités = 1 étoile de plus)
	for kn in [[1.8, 2], [1.8, 3], [3.24, 3], [3.24, 5]]:
		var specs: Array = []
		for r in reps:
			for c in cls:
				var b_team: Array = []
				for i in int(kn[1]):
					b_team.append(c)
				specs.append({"a": [c], "b": b_team, "ka": float(kn[0]), "kb": 1.0})
		var boards: Array = await _run_specs(specs)
		_summary("1 × %.2f contre %d × 1 (même classe)" % [float(kn[0]), int(kn[1])], boards)


func _cpu() -> void:
	var counts: Array = Array(String(args.get("units", "6,10,16,24")).split(",")).map(func(x): return int(x))
	var pilot := String(args.get("pilot", "script"))
	var secs := float(args.get("secs", "20"))
	# image à vide (aucune unité) : référence
	var empty: Dictionary = await _simulate([], 2.0)
	var base := _median(empty.frame_usec)
	print("[ac2] image à vide : %.3f ms (médiane)" % (base / 1000.0))
	for n in counts:
		var half: int = int(n) / 2
		var spec := {"a": _random_team(half), "b": _random_team(n - half), "pa": pilot, "pb": pilot, "immortal": true}
		var t0 := Time.get_ticks_usec()
		var b := _make_board(0, spec)
		var spawn_ms := (Time.get_ticks_usec() - t0) / 1000.0
		_brain_usec = 0
		_brain_calls = 0
		_net_usec = 0
		var res: Dictionary = await _simulate([b], secs)
		var fu: Array = res.frame_usec
		var med := _median(fu)
		var p95 := _pct(fu, 0.95)
		var mean := 0.0
		for x in fu:
			mean += float(x)
		mean /= maxf(fu.size(), 1)
		var per_dec := float(_brain_usec) / maxf(_brain_calls, 1)
		var budget := 16667.0
		print("[ac2] cpu %-6s %2d unités : image %.2f ms (moyenne %.2f, p95 %.2f) · par unité %.3f ms · création %.0f ms (%.0f ms/unité) · %s · tiendrait %d unités à 60 i/s (sans rendu)" % [
			pilot, n, med / 1000.0, mean / 1000.0, p95 / 1000.0, (med - base) / 1000.0 / n, spawn_ms, spawn_ms / n,
			("décision %.0f µs dont réseau %.0f µs (%d décisions/s, %.2f ms/image)" % [per_dec, float(_net_usec) / maxf(_brain_calls, 1), roundi(_brain_calls / secs), float(_brain_usec) / 1000.0 / maxf(fu.size(), 1)]) if pilot != "script" else "pas de cerveau",
			int((budget - base) / maxf((mean - base) / n, 1.0))])
		if is_instance_valid(b.root):
			b.root.queue_free()
		await get_tree().process_frame


## Les 60 classes : ce que lance l'IA scriptée (ClassRival : 4 premiers sorts d'attaque, soins et renforts à part) et le
## cerveau (MlDuelPilot.kit_for : les 12 premiers sorts, renforts compris), et ce qui posera problème sur un plateau.
func _kits() -> void:
	var tot := {"ranged": 0, "cls_ranged": 0, "melee_gun": 0, "far_melee": 0, "support": 0, "move": 0, "short": 0, "brain_buffs": 0, "ground": 0}
	for cid in _all_classes():
		var c: Dictionary = GameData.class_data(cid)
		var all: Array = c.get("skills", [])
		var att: Array = all.filter(func(s): return not String(s.kind) in ["buff", "heal"]).slice(0, 4)
		var sup: Array = all.filter(func(s): return String(s.kind) in ["buff", "heal"])
		var kit := MlDuelPilot.kit_for(cid)
		var ids: Array = kit.skills.map(func(s): return int(s.id))
		for slot in kit.chains:
			for e in kit.chains[slot]:
				ids.append(int(e.id))
		var bk := {"att": 0, "buff": 0, "heal": 0}
		for s in all:
			if int(s.id) in ids:
				var kd := String(s.kind)
				bk[kd if kd in ["buff", "heal"] else "att"] += 1
		var alerts: Array = []
		var ranged := is_ranged(cid)
		var cls_range := float(c.get("attack_range", 0.0))
		if ranged:
			tot.ranged += 1
		if cls_range > 6.0:
			tot.cls_ranged += 1
		if ranged and cls_range <= 6.0:
			alerts.append("arme à distance jouée au contact (pas de attack_range)")
			tot.melee_gun += 1
		if not ranged and cls_range > 6.0:
			alerts.append("tient %d m mais son auto-attaque est de mêlée (coups dans le vide)" % int(cls_range))
			tot.far_melee += 1
		var kinds: Array = att.map(func(s): return String(s.kind))
		if kinds.any(func(k): return k in ["blink", "dash"]):
			alerts.append("sort de déplacement (quitte la formation)")
			tot.move += 1
		if att.size() < 4:
			alerts.append("%d sorts d'attaque seulement" % att.size())
			tot.short += 1
		if sup.any(func(s): return String(s.kind) == "heal"):
			alerts.append("soigneur (équipe : camps natifs seulement)")
			tot.support += 1
		if bk.buff + bk.heal >= 6:
			alerts.append("cerveau : %d renforts / soins sur 12" % (bk.buff + bk.heal))
			tot.brain_buffs += 1
		if kinds.has("ground"):
			tot.ground += 1
		print("[ac2] kit %-20s %-16s fam %d · %-10s %s · script : %s · soutien %d (%d soins) · cerveau : %d attaques, %d renforts, %d soins%s" % [
			cid, String(c.get("name_fr", "")), int(c.get("family", 0)), String(c.get("weapon_type", "")), "distance" if ranged else "mêlée",
			"/".join(kinds), sup.size(), sup.filter(func(s): return String(s.kind) == "heal").size(), bk.att, bk.buff, bk.heal,
			(" · ALERTES : " + " ; ".join(alerts)) if not alerts.is_empty() else ""])
	print("[ac2] --- portée : arme à distance %d · attack_range > 6 m %d · arme à distance jouée au contact %d · tient à distance avec une auto-attaque de mêlée %d" % [
		tot.ranged, tot.cls_ranged, tot.melee_gun, tot.far_melee])
	print("[ac2] --- 60 classes : arme à distance %d · sort de déplacement dans les 4 du script %d · moins de 4 sorts d'attaque %d · soigneurs %d · cerveau ≥ 6 renforts/soins sur 12 : %d · zone visée (ground) dans les 4 : %d" % [
		tot.ranged, tot.move, tot.short, tot.support, tot.brain_buffs, tot.ground])


## Banc « qualité de jeu » : chaque composition tirée au sort est jouée en miroir (mêmes classes des deux côtés), l'IA v2
## d'un côté et l'IA v1 de l'autre, en alternant les côtés ; taux de victoire de la v2 (50 % = pas mieux).
func _bench() -> void:
	var sizes: Array = Array(String(args.get("sizes", "3,5,8")).split(",")).map(func(x): return int(x))
	var reps := int(args.get("reps", "50"))
	for n in sizes:
		var specs: Array = []
		for r in reps:
			var team := _random_team(n)
			var v2_a := r % 2 == 0
			specs.append({"a": team, "b": team.duplicate(), "ia": "v2" if v2_a else "v1", "ib": "v1" if v2_a else "v2"})
		var boards: Array = await _run_specs(specs)
		var wins := 0
		var losses := 0
		for b in boards:
			var v2_side := "A" if b.spec.ia == "v2" else "B"
			if b.winner == v2_side:
				wins += 1
			elif b.winner != "=":
				losses += 1
		_summary("banc %dv%d miroir, IA v2 contre IA v1" % [n, n], boards)
		print("[ac2]     IA v2 gagne %d / %d (%d%%), perd %d, nuls %d" % [wins, boards.size(), roundi(100.0 * wins / maxf(boards.size(), 1)), losses, boards.size() - wins - losses])
