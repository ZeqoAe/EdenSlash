class_name MobaDirector
extends Node
## Directeur de scène des Deux Voies (lot MB-C, MOBA.md § 7, rapport R_MB_C.md) : monté par TeamMatch.mount depuis
## RunDirector.start (état « team »). Tient la carte (MobaMap), les 10 structures (MobaStructure), les sbires (MobaMinion,
## mode horde, recyclés, vagues étalées sur plusieurs images), les traits (MobaBolt, recyclés), les 8 héros (toi + 3 alliés
## MobaRival contre 4, ou 8 IA en spectateur, ou aucun pour mesurer les voies), leur mort et leur réapparition, la victoire
## (Cœur détruit, ou décision à 25:00) et la fin de partie. world.gd lui rend la mort du joueur (player_down) et l'abandon.
##
## Ciblage (R_MB0 § 4.8) : le directeur choisit les cibles des sbires et des tours (grille spatiale de 8 m refaite à chaque
## image physique ; aucune recherche par groupes) ; le « camp » d'une unité = son ffa_id (TeamMatch : 100 + équipe) ; les
## sbires et les structures ne sont pas membres de TeamMatch (ClassRival._teammates ne voit que les héros, piège 8 de R_MB0).
##
## IA des héros (provisoire, lot MB-E à venir) : toutes les 0,4 s, cible = héros adverse proche, sinon sbire, sinon structure
## assiégeable (au moins 2 sbires alliés sous elle) ; jamais sous une tour adverse qui n'a pas de sbire allié à frapper ;
## rentre à la fontaine sous 30 % de PV ; sinon se tient 4 m derrière le front de sa vague. Niveau des héros (en attendant
## l'XP du lot MB-D) : le niveau attendu à cet instant (MobaData.expected_level).
##
## Options : voir Moba (TeamMatch.spec). Lignes : [moba] …

const GRID := 8.0
const HERO_THINK := 0.4
const LOD_EVERY := 0.5
const SPAWN_PER_FRAME := 4
const POOL := {"melee": 18, "ranged": 12, "ram": 4, "giant": 3}  # sbires créés au chargement, par camp
const KIND_HERO := 1
const KIND_MINION := 2
const KIND_STRUCT := 4

var d: RunDirector
var map: MobaMap
var rng := RandomNumberGenerator.new()
var mode := "all"  # all | none | watch
var player: Player
var heroes: Array = []  # héros en jeu (le joueur compris s'il joue)
## héros -> {side, role, lane, cid, respawn_at, home, think, deaths, kills}
var info: Dictionary = {}
var structures: Array = []
var cores: Array = [null, null]
var minions: Array = []  # sbires en jeu (vivants ou mourants)
var spare: Dictionary = {}  # « genre:camp » -> sbires prêts à resservir
var bolts_free: Array = []
var bolts_live := 0
var wave_n := 0
var next_wave := MobaData.FIRST_WAVE
var queue: Array = []  # sbires à faire apparaître : {side, lane, kind, order}
var fronts := [[0.0, 0.0], [0.0, 0.0]]  # [camp][voie] : avancée de la vague la plus avancée (m depuis sa base)
var giants := {}  # « camp:voie » -> vrai : ce camp ajoute un géant par vague sur cette voie (T2 adverse tombée)
var level_now := 1
var ended := false
var measured := false  # option « until » atteinte
var watch_target: Node3D
## Mesures : sbires créés pendant la partie (hors chargement), apparitions sautées (plafond), unités vivantes.
var stats := {"created_live": 0, "created_load": 0, "skipped": 0, "spawned": 0, "max_alive": 0, "shots": 0}
var _grid: Dictionary = {}
var _help: Dictionary = {}  # héros -> {t, pos} : il vient de frapper un héros adverse (appel à l'aide)
var _lod_t := 0.0
var _front_t := 0.0
var _level_t := 0.0
var _resheet: Array = []  # héros dont la fiche est à refaire (un par image)
var _bolt_parent: Node3D
var _perf := false
var _perf_from := 60.0
var _last_us := 0
var _frame_ms: Array = []
var _phys_ms: Array = []
var _alive_samples: Array = []
var _trace := "--moba-trace" in OS.get_cmdline_user_args()
var _trace_t := 0.0


func setup(director: RunDirector) -> void:
	d = director
	var spec: Dictionary = TeamMatch.spec
	rng.seed = int(spec.get("seed", randi()))
	if spec.has("seed"):
		seed(int(spec.seed))  # (mesures : les sbires tirent leur décalage et leur pas au hasard global)
	mode = String(spec.get("heroes", "all"))
	_perf = bool(spec.get("perf", false))
	if spec.has("speed"):
		Engine.time_scale = float(spec.speed)
	Monster.attack_slots = 0  # (réglages statiques de la horde du Survivant : jamais ici)
	Monster.lite_height = 0.0
	PvpCaps.board = {}
	PvpCaps.elapsed = 0.0
	d.zone = GameData.zone(Run.zone_id)
	var t0 := Time.get_ticks_msec()
	_build_map()
	MobaData.warm_ref()
	_build_structures()
	_prewarm()
	_setup_player()
	_spawn_heroes()
	_bolt_parent = Node3D.new()
	_bolt_parent.name = "MobaBolts"
	add_child(_bolt_parent)
	print("[moba] prêt en %d ms : %s, %d héros, %d structures, %d sbires préparés, navigation %s" % [Time.get_ticks_msec() - t0,
		mode, heroes.size(), structures.size(), int(stats.created_load), map.nav_source])
	d.zone_changed.emit({"name": TeamMatch.title(), "levels": [1, MobaData.LEVEL_MAX]})
	Music.play_zone(Run.zone_id)
	TeamMatch.start_round()
	TeamMatch.set_phase("fight")
	if d.world.rig != null:
		d.world.rig.distance = 22.0  # (caméra du mode, MOBA.md § 7.9)
	if mode == "all":
		d.message.emit("Les Deux Voies\nDéfendez votre Cœur, détruisez le leur !", 4.0)


# --- carte et structures -------------------------------------------------------------------------

func _build_map() -> void:
	var m := MobaMap.new()
	m.biome = String(GameData.zone(Run.zone_id).get("biome", "rainbowfall"))
	m.name = "MobaMap"
	d.world._swap_map(m)
	m.generate_moba(rng.randi())
	map = m
	d.map = m
	d.world._apply_biome_env()


func _build_structures() -> void:
	for side in 2:
		for tw in map.moba.towers[side]:
			var s := MobaStructure.new()
			s.setup(self, side, "tower", int(tw.lane), int(tw.tier))
			add_child(s)
			s.global_position = tw.pos
			structures.append(s)
		var c := MobaStructure.new()
		c.setup(self, side, "core")
		add_child(c)
		c.global_position = map.moba.cores[side]
		structures.append(c)
		cores[side] = c


## Tour [param tier] de la voie [param lane] du camp [param side] encore debout.
func structure_alive(side: int, lane: int, tier: int) -> bool:
	for s in structures:
		if s.side == side and s.kind == "tower" and s.lane == lane and s.tier == tier:
			return not s.is_dead
	return false


func structure_of(side: int, lane: int, tier: int) -> MobaStructure:
	for s in structures:
		if s.side == side and s.kind == "tower" and s.lane == lane and s.tier == tier:
			return s
	return null


# --- sbires --------------------------------------------------------------------------------------

## Sbires créés au chargement (aucune création de modèle pendant la partie tant que la réserve suffit).
## Bleus et rouges créés en alternance : l'ordre de traitement de l'image physique suit l'ordre des nœuds, et un camp créé
## d'abord frapperait toujours le premier quand deux coups tombent dans la même image (biais mesuré : sans alternance, les
## T1 rouges tombaient dans les parties à vagues égales).
func _prewarm() -> void:
	for kind in POOL:
		for _i in int(POOL[kind]):
			for side in ([0, 1] if _i % 2 == 0 else [1, 0]):
				var m := _new_minion(kind, side)
				m._park()
				spare_add(m)
				stats.created_load = int(stats.created_load) + 1


func _new_minion(kind: String, side: int) -> MobaMinion:
	var m := MobaMinion.new()
	m.setup_unit(self, side, 0, kind)
	m.apply_stats(MobaData.minion_stats(kind, Moba.t, Moba.power(side)))
	add_child(m)
	return m


func spare_add(m: MobaMinion) -> void:
	var key := "%s:%d" % [m.kind, m.side]
	if not spare.has(key):
		spare[key] = []
	(spare[key] as Array).append(m)


## Sbire mort (fin de son animation) : retiré des actifs, gardé pour la prochaine vague.
func release_minion(m: MobaMinion) -> void:
	minions.erase(m)
	spare_add(m)


func _spawn(e: Dictionary) -> void:
	if minions.size() >= MobaData.MINION_CAP:
		stats.skipped = int(stats.skipped) + 1
		return
	var side := int(e.side)
	var li := int(e.lane)
	var kind := String(e.kind)
	var dist := 5.0 + 1.6 * int(e.order)
	var at := map.lane_point(side, li, dist) + Vector3.UP * 0.2
	var st := MobaData.minion_stats(kind, Moba.t, Moba.power(side))
	st.struct = float(st.struct) * Moba.tune("struct", 1.0)
	st.vs_minion = float(st.vs_minion) * Moba.tune("vs_minion", 1.0)
	var key := "%s:%d" % [kind, side]
	var m: MobaMinion = null
	if spare.has(key) and not (spare[key] as Array).is_empty():
		m = (spare[key] as Array).pop_back()
	else:
		m = _new_minion(kind, side)
		stats.created_live = int(stats.created_live) + 1
	m.lane = li
	m.spawned_at = Moba.t
	m.level = MobaData.sheet_level(floori(MobaData.expected_level(Moba.t)))  # (affiché : le niveau des héros du moment)
	m.reuse(at, map.lane_index(side, li, dist), st)
	minions.append(m)
	stats.spawned = int(stats.spawned) + 1


func _waves() -> void:
	if Moba.t >= next_wave:
		wave_n += 1
		next_wave = MobaData.wave_time(wave_n + 1)
		# file entrelacée (bleu, rouge, bleu…) : aucun camp ne part avant l'autre
		var comps := {}
		var longest := 0
		for side in 2:
			for li in 2:
				comps["%d:%d" % [side, li]] = MobaData.wave(wave_n, Moba.t, 1 if giants.get("%d:%d" % [side, li], false) else 0)
				longest = maxi(longest, (comps["%d:%d" % [side, li]] as Array).size())
		for i in longest:
			for li in 2:
				for side in ([0, 1] if (wave_n + i) % 2 == 0 else [1, 0]):
					var comp: Array = comps["%d:%d" % [side, li]]
					if i < comp.size():
						queue.append({"side": side, "lane": li, "kind": comp[i], "order": i})
	var n := 0
	while not queue.is_empty() and n < SPAWN_PER_FRAME:
		_spawn(queue.pop_front())
		n += 1


## Sbire tombé : compté pour le camp du tueur.
func on_minion_down(m: MobaMinion, killer: Combatant) -> void:
	var ks := side_of(killer)
	if ks >= 0 and ks != m.side:
		Moba.minion_kills[ks] += 1


## Bonus de force d'un sbire (Étendard des voies, Bannière du Colosse : lots MB-D et MB-F).
func minion_aura(_m: MobaMinion) -> float:
	return 1.0


# --- héros ---------------------------------------------------------------------------------------

func _setup_player() -> void:
	player = d.player
	var spec: Dictionary = TeamMatch.spec
	if mode != "all":
		# vagues seules ou 8 IA : le héros du joueur est mis à l'écart, hors de tout camp
		player.visible = false
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.global_position = Vector3(0, -40, 0)
		watch_target = Node3D.new()
		add_child(watch_target)
		watch_target.global_position = map.lane_point(0, 0, map.lane_len[0] * 0.5)
		if d.world.rig != null:
			d.world.rig.target = watch_target
		return
	var cid := Run.class_id
	var fam := int(GameData.class_data(cid).get("family", 1))
	var role := int(spec.get("role", MobaData.role_for_family(fam)))
	_set_level(player, 1)
	TeamMatch.add(player, 0)
	heroes.append(player)
	info[player] = {"side": 0, "role": role, "lane": int(MobaData.ROLES[role].lane), "cid": cid, "respawn_at": -1.0,
		"home": false, "think": 0.0, "deaths": 0, "kills": 0}
	d._place_player(map.moba.fountains[0])
	player.damaged.connect(_on_hero_damaged.bind(player))


## Équipes : une classe par poste (Brumes = Rempart, jungle = Ombre, tir = Traque ou Arcane, soutien = Ferveur), sans
## doublon ; le joueur prend le poste de sa famille (ou l'option « role »).
func _spawn_heroes() -> void:
	if mode == "none":
		return
	var spec: Dictionary = TeamMatch.spec
	var diffs := [clampi(int(spec.get("diff_allies", spec.get("diff", 2))), 0, 3), clampi(int(spec.get("diff_foes", spec.get("diff", 2))), 0, 3)]
	var taken: Array = [Run.class_id] if mode == "all" else []
	for side in 2:
		var imposed: Array = (spec.get("allies" if side == 0 else "foes", []) as Array).duplicate()
		for role in MobaData.ROLES.size():
			if side == 0 and mode == "all" and role == int(info[player].role):
				continue
			var cid := ""
			if not imposed.is_empty():
				cid = String(imposed.pop_front())
			else:
				cid = _pick_class(MobaData.ROLES[role].families, taken)
			taken.append(cid)
			var r := MobaRival.make(self, cid, 1, int(diffs[side]), side)
			add_child(r)
			r.global_position = _fountain_spot(side, heroes.size())
			heroes.append(r)
			info[r] = {"side": side, "role": role, "lane": int(MobaData.ROLES[role].lane), "cid": cid, "respawn_at": -1.0,
				"home": false, "think": rng.randf() * HERO_THINK, "deaths": 0, "kills": 0}
			r.damaged.connect(_on_hero_damaged.bind(r))
			if mode == "watch" and side == 0 and watch_target != null and d.world.rig != null and d.world.rig.target == watch_target:
				d.world.rig.target = r


func _pick_class(fams: Array, taken: Array) -> String:
	var pool: Array = []
	for c in GameData.classes.keys():
		if int(GameData.class_data(String(c)).get("family", 0)) in fams and not c in taken and not c in Assault.AI_EXCLUDED:
			pool.append(c)
	pool.sort()
	if pool.is_empty():
		pool = GameData.classes.keys().filter(func(c): return not c in taken)
	return String(pool[rng.randi() % pool.size()])


func _fountain_spot(side: int, i: int) -> Vector3:
	var f: Vector3 = map.moba.fountains[side]
	var a := TAU * i / 5.0
	return f + Vector3(cos(a), 0, sin(a)) * 2.5 + Vector3.UP * 0.4


## Camp d'une unité (0 bleu, 1 rouge) d'après son ffa_id ; -1 : hors partie.
func side_of(c) -> int:
	if c == null or not is_instance_valid(c) or not (c is Combatant):
		return -1
	var s: int = (c as Combatant).ffa_id - TeamMatch.FFA_BASE
	if s == 0 or s == 1:
		return s
	if info.has(c):
		return int(info[c].side)
	if c is MobaMinion:
		return (c as MobaMinion).side
	if c is MobaStructure:
		return (c as MobaStructure).side
	return -1


## Niveau de partie [param lv] d'un héros (en attendant l'XP du lot MB-D : le niveau attendu).
func _set_level(h: Combatant, lv: int) -> void:
	if h is MobaRival:
		(h as MobaRival).resheet(lv)
		if lv >= 5 and not (h as MobaRival).ult_on:
			(h as MobaRival).set_kit(true)
	elif h is Player:
		var p := h as Player
		var ratio := p.hp / p.max_hp if p.max_hp > 0.0 and not p.is_dead else 1.0
		p.level = MobaData.sheet_level(lv)
		Run.hero_level = p.level
		Run.max_level = p.level
		p.recalc_stats()
		p.hp = p.max_hp * ratio
		p.health_changed.emit(p.hp, p.max_hp)
		if lv >= 5 and Run.skills.size() < 4:
			var ult := int(MobaData.kit(Run.class_id).get("ult", {}).get("id", 0))
			if ult > 0:
				Run.skills.append({"id": ult, "rank": 1})
				Run.changed.emit()


func _levels() -> void:
	var lv := clampi(floori(MobaData.expected_level(Moba.t)), 1, MobaData.LEVEL_MAX)
	if lv > level_now:
		level_now = lv
		_resheet = heroes.duplicate()
	if not _resheet.is_empty():
		var h = _resheet.pop_front()
		if is_instance_valid(h):
			_set_level(h, level_now)


## Coup d'un héros sur un héros adverse : appel à l'aide des sbires et des tours de la victime.
func _on_hero_damaged(_amount: float, source: Combatant, victim: Combatant) -> void:
	if source != null and info.has(source) and side_of(source) != side_of(victim):
		_help[source] = {"t": Moba.t, "pos": victim.global_position}


func on_hero_down(h: Combatant, killer: Combatant) -> void:
	if not info.has(h):
		return
	var inf: Dictionary = info[h]
	inf.deaths = int(inf.deaths) + 1
	inf.respawn_at = Moba.t + MobaData.respawn_time(level_now, Moba.t)
	inf.home = false
	TeamMatch.note_ko(h, killer)
	var ks := side_of(killer)
	if ks >= 0 and ks != int(inf.side):
		Moba.hero_kills[ks] += 1
		if info.has(killer):
			info[killer].kills = int(info[killer].kills) + 1
	Moba.note("ko", int(inf.side), {"who": String(inf.cid)})


func _respawns() -> void:
	for h in heroes:
		var inf: Dictionary = info[h]
		if not h.is_dead or float(inf.respawn_at) < 0.0 or Moba.t < float(inf.respawn_at):
			continue
		inf.respawn_at = -1.0
		var at := _fountain_spot(int(inf.side), heroes.find(h))
		if h is MobaRival:
			(h as MobaRival).revive(at)
		elif h is Player:
			(h as Player).respawn(at)
			d._place_player(at)
			if d.world.rig != null:
				d.world.rig.target = h


## Fontaine : 12 % des PV max par seconde aux héros de son camp (sans les règles de soin du JcJ).
func _fountains(delta: float) -> void:
	for h in heroes:
		if h.is_dead or h.hp >= h.max_hp:
			continue
		var f: Vector3 = map.moba.fountains[int(info[h].side)]
		if h.global_position.distance_squared_to(f) < MobaData.FOUNTAIN_RADIUS * MobaData.FOUNTAIN_RADIUS:
			h.hp = minf(h.max_hp, h.hp + h.max_hp * MobaData.FOUNTAIN_REGEN * delta)
			h.health_changed.emit(h.hp, h.max_hp)


# --- IA simple des héros (lot MB-E à venir) ----------------------------------------------------------

func _think_all(delta: float) -> void:
	for h in heroes:
		if h.is_dead:
			continue
		var inf: Dictionary = info[h]
		inf.think = float(inf.think) - delta
		if inf.think > 0.0:
			continue
		inf.think = HERO_THINK
		if h is MobaRival:
			_think(h as MobaRival, inf)
		elif h is Player and (h as Player).autoplay:
			(h as Player).autoplay_target = _home_or_lane(h, inf)


func _think(h: MobaRival, inf: Dictionary) -> void:
	var side := int(inf.side)
	var p := h.global_position
	var enemy_core: MobaStructure = cores[1 - side]
	if bool(inf.home):
		if h.hp >= h.max_hp * 0.95:
			inf.home = false
		else:
			h.goal = map.moba.fountains[side]
			h._player = enemy_core
			return
	if h.hp < h.max_hp * 0.3:
		inf.home = true
		h.goal = map.moba.fountains[side]
		h._player = enemy_core
		return
	var foes := enemies_near(side, p, 13.0, KIND_HERO)
	var safe: Array = foes.filter(func(f): return not _tower_danger(f.global_position, side))
	var target: Combatant = null
	if not safe.is_empty():
		target = h.pick_target(safe, h._player if h._player in safe else null)
	if target == null:
		var ms := enemies_near(side, p, 10.0, KIND_MINION).filter(func(f): return not _tower_danger(f.global_position, side))
		if not ms.is_empty():
			target = _weakest(ms)
	if target == null:
		for s in enemies_near(side, p, 16.0, KIND_STRUCT):
			if not (s as MobaStructure).invulnerable() and _allied_minions_near(s.global_position, side, (s as MobaStructure).range_m) >= 2:
				target = s
				break
	if target != null:
		h.goal = Vector3.INF
		h._player = target
	else:
		h.goal = _lane_goal(h, inf)
		h._player = enemy_core


func _weakest(list: Array) -> Combatant:
	var best: Combatant = null
	for c in list:
		if best == null or c.hp < best.hp:
			best = c
	return best


func _home_or_lane(h: Combatant, inf: Dictionary) -> Vector3:
	if h.hp < h.max_hp * 0.25:
		return map.moba.fountains[int(inf.side)]
	return _lane_goal(h, inf)


## Place d'un héros sans adversaire : 4 m derrière le front de sa vague (jamais plus loin que sa T1 si la vague est chez
## lui), hors de portée d'une tour adverse sans sbires alliés ; le jungler soutient la voie la plus en retard.
func _lane_goal(_h: Combatant, inf: Dictionary) -> Vector3:
	var side := int(inf.side)
	var li := int(inf.lane)
	if li < 0:
		li = 0 if float(fronts[side][0]) <= float(fronts[side][1]) else 1
	var t1 := structure_of(side, li, 1)
	var own := float(MobaData.TOWER_AT[1]) * map.lane_len[li] - 6.0
	if t1 != null and t1.is_dead:
		own = float(MobaData.TOWER_AT[0]) * map.lane_len[li] - 6.0
	var dist := maxf(float(fronts[side][li]) - 4.0, own)
	var at := map.lane_point(side, li, dist)
	var guard := 0
	while _tower_danger(at, side) and guard < 12:
		dist -= 5.0
		at = map.lane_point(side, li, dist)
		guard += 1
	return at


## [param pos] est à portée d'une structure adverse qui n'a pas au moins 2 sbires du camp [param side] à frapper.
func _tower_danger(pos: Vector3, side: int) -> bool:
	for s in structures:
		if s.is_dead or s.side == side:
			continue
		var r: float = s.range_m + 2.0
		if pos.distance_squared_to(s.global_position) < r * r and _allied_minions_near(s.global_position, side, s.range_m) < 2:
			return true
	return false


func _allied_minions_near(pos: Vector3, side: int, r: float) -> int:
	var n := 0
	for u in units_near(side, pos, r, KIND_MINION):
		n += 1
	return n


func _update_fronts() -> void:
	for side in 2:
		for li in 2:
			fronts[side][li] = 0.0
	for m in minions:
		if m.is_dead:
			continue
		var cum: PackedFloat32Array = map.lane_cum[m.lane][m.side]
		fronts[m.side][m.lane] = maxf(float(fronts[m.side][m.lane]), cum[clampi(m.wp_i - 1, 0, cum.size() - 1)])


# --- cibles : grille spatiale ----------------------------------------------------------------------

static func kind_of(u) -> int:
	if u is MobaMinion:
		return KIND_MINION
	if u is MobaStructure:
		return KIND_STRUCT
	return KIND_HERO


func _rebuild_grid() -> void:
	_grid.clear()
	for list in [heroes, minions, structures]:
		for u in list:
			if u.is_dead or not u.visible:
				continue
			var s := side_of(u)
			if s < 0:
				continue
			var p: Vector3 = u.global_position
			var k := Vector3i(floori(p.x / GRID), floori(p.z / GRID), s)
			if _grid.has(k):
				(_grid[k] as Array).append(u)
			else:
				_grid[k] = [u]


## Unités du camp [param side] (genres [param kinds]) à moins de [param r] m de [param p].
func units_near(side: int, p: Vector3, r: float, kinds: int) -> Array:
	var out: Array = []
	var c0 := Vector2i(floori((p.x - r) / GRID), floori((p.z - r) / GRID))
	var c1 := Vector2i(floori((p.x + r) / GRID), floori((p.z + r) / GRID))
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var cell: Variant = _grid.get(Vector3i(cx, cz, side))
			if cell == null:
				continue
			for u in cell:
				if (kind_of(u) & kinds) == 0 or u.is_dead:
					continue
				var rr: float = r + u.radius
				if p.distance_squared_to(u.global_position) <= rr * rr:
					out.append(u)
	return out


func enemies_near(side: int, p: Vector3, r: float, kinds: int) -> Array:
	return units_near(1 - side, p, r, kinds)


func _nearest(p: Vector3, list: Array) -> Combatant:
	var best: Combatant = null
	var bd := INF
	for u in list:
		var dd: float = p.distance_squared_to(u.global_position)
		if dd < bd:
			bd = dd
			best = u
	return best


## Un héros adverse de [param side] vient de frapper un héros de [param side] près de [param p] (rayon [param r]).
func _helper_target(side: int, p: Vector3, r: float) -> Combatant:
	var best: Combatant = null
	var bd := INF
	for h in _help:
		if not is_instance_valid(h) or h.is_dead or side_of(h) == side or Moba.t - float(_help[h].t) > MobaData.HELP_TIME:
			continue
		var dd: float = p.distance_to(h.global_position)
		if dd <= r and (_help[h].pos as Vector3).distance_to(p) <= r + 2.0 and dd < bd:
			bd = dd
			best = h
	return best


## Cible d'un sbire : le héros adverse qui frappe un héros allié près de lui, sinon le sbire ennemi le plus proche, sinon
## une structure, sinon un héros ; la cible en cours est gardée tant qu'elle reste à portée de recherche (+ 4 m).
func minion_target(m: MobaMinion, current: Combatant) -> Combatant:
	var p := m.global_position
	var helper := _helper_target(m.side, p, MobaData.HELP_RADIUS)
	if helper != null:
		return helper
	if current != null and is_instance_valid(current) and not current.is_dead and side_of(current) == 1 - m.side \
			and kind_of(current) != KIND_HERO and p.distance_to(current.global_position) <= m.aggro + 4.0 + current.radius:
		return current
	var near := enemies_near(m.side, p, m.aggro, KIND_MINION | KIND_STRUCT | KIND_HERO)
	if near.is_empty():
		return null
	var order := [KIND_MINION, KIND_STRUCT, KIND_HERO]
	if Moba.tune("prio_struct", 0.0) > 0.0:
		order = [KIND_STRUCT, KIND_MINION, KIND_HERO]
	for kind in order:
		var best := _nearest(p, near.filter(func(u): return kind_of(u) == kind))
		if best != null:
			return best
	return null


## Cible d'une tour : le héros adverse qui frappe un héros allié à portée, sinon la cible en cours, sinon le sbire le plus
## proche, sinon le héros le plus proche.
func tower_target(tw: MobaStructure, current: Combatant) -> Combatant:
	var p := tw.global_position
	var helper := _helper_target(tw.side, p, tw.range_m)
	if helper != null:
		return helper
	var reach := tw.range_m
	if current != null and is_instance_valid(current) and not current.is_dead and current.visible \
			and p.distance_to(current.global_position) <= reach + current.radius:
		return current
	var ms := enemies_near(tw.side, p, reach, KIND_MINION)
	if not ms.is_empty():
		return _nearest(p, ms)
	return _nearest(p, enemies_near(tw.side, p, reach, KIND_HERO))


## Un sbire de l'autre camp est à 12 m de [param s] (sinon la structure est protégée).
func minion_near(s: MobaStructure) -> bool:
	return enemies_near(s.side, s.global_position, MobaData.PROTECT_RADIUS, KIND_MINION).size() >= int(Moba.tune("siege_n", 1.0))


# --- traits ------------------------------------------------------------------------------------------

func fire_bolt(src: Combatant, target: Combatant, dmg: float, from: Vector3, style: String) -> void:
	var b: MobaBolt = null
	if not bolts_free.is_empty():
		b = bolts_free.pop_back()
	else:
		b = MobaBolt.new()
		b.director = self
		_bolt_parent.add_child(b)
	b.launch(src, target, dmg, from, style, maxi(side_of(src), 0))
	bolts_live += 1
	if style == "tower":
		stats.shots = int(stats.shots) + 1


func bolt_done(b: MobaBolt) -> void:
	bolts_live -= 1
	bolts_free.append(b)


# --- boucle -----------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if ended or map == null:
		return
	Moba.t += delta
	TeamMatch.elapsed = Moba.t
	PvpCaps.elapsed = Moba.t
	_rebuild_grid()
	_waves()
	_levels()
	_respawns()
	_fountains(delta)
	_think_all(delta)
	_front_t -= delta
	if _front_t <= 0.0:
		_front_t = 0.5
		_update_fronts()
	_lod_t -= delta
	if _lod_t <= 0.0:
		_lod_t = LOD_EVERY
		_update_lod()
		var alive := 0
		for m in minions:
			if not m.is_dead:
				alive += 1
		stats.max_alive = maxi(int(stats.max_alive), alive)
		if _perf and Moba.t >= _perf_from:
			_alive_samples.append(alive)
	if _trace and Moba.t >= _trace_t:
		_trace_t = Moba.t + 30.0
		var alive := minions.filter(func(m): return not m.is_dead).size()
		var hp: Array = structures.map(func(s): return int(s.hp / s.max_hp * 100.0))
		print("[moba] t=%d vagues=%d sbires=%d (file %d, apparus %d, créés %d) tirs=%d structures=%s %.1f img/s nœuds=%d traits=%d" % [int(Moba.t), wave_n,
			alive, queue.size(), int(stats.spawned), int(stats.created_live), int(stats.shots), str(hp), Engine.get_frames_per_second(),
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), bolts_live])
	if Moba.t >= MobaData.END_AT:
		var hp := [cores[0].hp / cores[0].max_hp, cores[1].hp / cores[1].max_hp]
		_finish(Moba.decide(hp), "time")
		return
	var until := float(TeamMatch.spec.get("until", 0.0))
	if until > 0.0 and Moba.t >= until and not measured:
		measured = true
		_report("mesure")
		if "--auto-quit" in OS.get_cmdline_user_args():
			get_tree().quit()


## Loin de la caméra, les sbires réfléchissent une image sur 2 (au-delà de 35 m) ou sur 4 (70 m).
func _update_lod() -> void:
	var cam := get_viewport().get_camera_3d()
	var f: Vector3 = cam.global_position if cam else map.moba.center
	if d.world.rig != null and is_instance_valid(d.world.rig.target):
		f = (d.world.rig.target as Node3D).global_position
	for m in minions:
		if m.is_dead:
			continue
		var dd := f.distance_to(m.global_position)
		m.lod = 0 if dd < 35.0 else (1 if dd < 70.0 else 2)


func _process(_delta: float) -> void:
	if not _perf or ended:
		return
	var now := Time.get_ticks_usec()
	if _last_us > 0 and Moba.t >= _perf_from:
		_frame_ms.append((now - _last_us) / 1000.0)
	_last_us = now


## Appelé par RunDirector à chaque image (état « team ») : rien d'autre que le temps de la partie (la logique est en
## _physics_process, au pas de la physique).
func update(_delta: float) -> void:
	pass


## Structure tombée : comptée pour le camp adverse ; T2 : ses sbires ajoutent un géant par vague sur cette voie ; Cœur : fin.
func on_structure_down(s: MobaStructure, _killer: Combatant) -> void:
	var by := 1 - s.side
	Moba.structures_down[by] += 1
	Moba.note(s.kind, s.side, {"lane": s.lane, "tier": s.tier})
	print("[moba] %s tombe à %d:%02d" % [s.display_name, int(Moba.t) / 60, int(Moba.t) % 60])
	if s.kind == "tower" and s.tier == 2:
		giants["%d:%d" % [by, s.lane]] = true
	if String(TeamMatch.spec.get("stop", "")) == "tower" and not measured:
		measured = true  # (mesures : arrêt à la première tour tombée)
		_report("tour")
		if "--auto-quit" in OS.get_cmdline_user_args():
			get_tree().quit()
	if mode == "all" and s.kind == "tower":
		var mine := s.side == TeamMatch.player_team
		d.message.emit(("%s tombe !" % s.display_name) if mine else ("%s détruite !" % s.display_name), 2.5)
	if s.kind == "core":
		_finish(by, "core")


# --- fin -------------------------------------------------------------------------------------------

func _report(what: String) -> void:
	var hp := structures.map(func(x): return "%s%d%s:%d" % ["BR"[x.side], x.lane + 1 if x.kind == "tower" else 0, "abc"[x.tier], int(100.0 * x.hp / x.max_hp)])
	var line := "[moba] %s : %s ; vagues %d ; sbires apparus %d (créés en partie %d, sautés %d, vivants au plus %d) ; tirs %d ; PV %s" % [
		what, Moba.summary(), wave_n, int(stats.spawned), int(stats.created_live), int(stats.skipped), int(stats.max_alive), int(stats.shots), " ".join(hp)]
	print(line)
	if _perf:
		print("[moba] image : %s ; sbires vivants : %s" % [JSON.stringify(_stats(_frame_ms)), JSON.stringify(_stats(_alive_samples))])


static func _stats(a: Array) -> Dictionary:
	var arr := a.duplicate()
	if arr.is_empty():
		return {"n": 0}
	arr.sort()
	var s := 0.0
	for v in arr:
		s += float(v)
	var n := arr.size()
	return {"n": n, "moy": snappedf(s / n, 0.01), "p50": snappedf(float(arr[int(0.5 * (n - 1))]), 0.01),
		"p95": snappedf(float(arr[int(0.95 * (n - 1))]), 0.01), "max": snappedf(float(arr[n - 1]), 0.01)}


## Mort du joueur (world.gd) : réapparition à la fontaine après le délai du niveau.
func player_down(killer: Combatant) -> void:
	if not info.has(player):
		return
	on_hero_down(player, killer)
	d.message.emit("Tu es tombé : retour dans %d s" % ceili(float(info[player].respawn_at) - Moba.t), 2.5)


## Abandon (menu pause) : la partie est perdue.
func abandon() -> void:
	if ended:
		return
	_finish(1 - TeamMatch.player_team, "abandon")


func _finish(w: int, how: String) -> void:
	if ended:
		return
	ended = true
	Moba.winner = w
	Moba.how = how
	d.world._ended = true
	d.world.pause_menu.close()
	TeamMatch.finish([w, 1 - w] if w >= 0 else [])
	var won := w == TeamMatch.player_team and mode == "all"
	_report("fin")
	var tiles := [[str(Moba.structures_down[0]), "structures détruites", "", true], ["%d:%02d" % [int(Moba.t) / 60, int(Moba.t) % 60], "durée"],
		[str(Moba.hero_kills[0]), "éliminations"]]
	Moba.finish()  # TeamMatch.end() d'abord (piège 11), puis le profil rendu
	if "--auto-quit" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	if not is_inside_tree():
		return
	get_tree().paused = true
	var r := ResultsPanel.new()
	d.world.add_child(r)
	r.show_spec({"title": "VICTOIRE !" if won else ("ABANDON" if how == "abandon" else "DÉFAITE"), "tone": "win" if won else "lose",
		"subtitle": "Les Deux Voies", "tiles": tiles,
		"buttons": [{"text": "Rejouer", "primary": true, "call": _replay.bind(Run.class_id)},
			{"text": "Menu principal", "call": _to_lobby}]})


func _replay(cid: String) -> void:
	get_tree().paused = false
	Moba.launch(cid, {})
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")


func _to_lobby() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred("res://scenes/lobby.tscn")
