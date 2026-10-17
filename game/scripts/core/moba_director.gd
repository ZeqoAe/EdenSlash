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
## Héros en partie (lot MB-D, R_MB_D.md) : un MobaHero par héros ([member info]) ; XP et or des sbires (dernier coup,
## partage à 15 m, rattrapage : [method on_minion_down]), des éliminations (primes, série, premier sang, aides :
## [method on_hero_down]), des structures ([method on_structure_down]) et des camps ([method reward_camp], lot MB-F) ;
## or et XP passifs ; niveaux 1-12 (fiche refaite, enchaînements, ultime au niveau 5 : [method apply_level]) ; choix de
## niveau non bloquant (Ctrl + 1 / 2 / 3) ; réapparition selon le niveau du héros ; rappel (X, 6 s, coupé par un coup ou un
## pas : [method start_recall]) ; boutique ouverte à la fontaine et pendant la mort (MobaItems ; P achète l'étape
## conseillée, Ctrl + Z annule) ; données d'affichage [method hud_data] (le HUD complet est le lot MB-H).
##
## IA des héros (provisoire en MB-C, remplacée au lot MB-E par MobaHeroAi) : toutes les 0,4 s, cible = héros adverse
## proche, sinon sbire, sinon structure assiégeable ; jamais sous une tour adverse qui n'a pas de sbire allié à frapper.
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
## héros -> MobaHero (camp, poste, voie, classe, niveau, XP, or, objets, éliminations, réapparition, rappel…)
var info: Dictionary = {}
var first_blood := false
var _player_state := ""  # (le joueur lance un sort : effets « skill_cast » des objets)
var _hud: Label
var _hud_t := 0.0
var _econ_t := 0.0
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
var _perf_started := false
var _perf_frames := 0  # images physiques mesurées (après _perf_from)
var _phys_t0 := 0
var _logic_ms: Array = []  # temps des scripts de chaque image physique (marques en tête et en queue)
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
	if _perf:
		_marks()
		_perf_from = float(spec.get("perf_from", _perf_from))
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
	MobaItems.begin(self)  # (avant les héros : la fiche du joueur lit ses objets)
	_setup_player()
	_spawn_heroes()
	_build_hud()
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


## Sbire tombé : compté pour le camp du tueur ; XP partagée entre les héros adverses à 15 m (le tueur compris) ; or :
## 100 % au dernier coup d'un héros, 60 % à chaque autre héros proche, 50 % à chacun si un sbire ou une tour l'achève ;
## rattrapage + 30 % sous la moyenne adverse de 2 niveaux.
func on_minion_down(m: MobaMinion, killer: Combatant) -> void:
	var ks := side_of(killer)
	if ks >= 0 and ks != m.side:
		Moba.minion_kills[ks] += 1
	var gs := 1 - m.side
	var kh: Combatant = killer if killer != null and is_instance_valid(killer) and info.has(killer) and ks == gs else null
	var near := units_near(gs, m.global_position, MobaData.SHARE_RADIUS, KIND_HERO)
	if kh != null and not kh in near:
		near.append(kh)
	if near.is_empty():
		return
	var xp_each := MobaHero.minion_xp_each(m.kind, near.size())
	var avg := avg_level(m.side)
	for u in near:
		var hs: MobaHero = info.get(u)
		if hs == null:
			continue
		var c := MobaHero.catchup(hs.level, avg)
		_xp(hs, xp_each * c)
		hs.add_gold(MobaHero.minion_gold(m.kind, "last" if u == kh else ("near" if kh != null else "stray")) * c)
	if kh != null:
		info[kh].cs += 1


## Niveau moyen des héros du camp [param side].
func avg_level(side: int) -> float:
	var s := 0.0
	var n := 0
	for h in heroes:
		var hs: MobaHero = info[h]
		if hs.side == side:
			s += hs.level
			n += 1
	return s / n if n > 0 else 1.0


## Camp de la jungle tombé (lot MB-F) : XP et or de son genre (MobaData.CAMPS) au héros qui l'achève (sinon au héros du
## camp le plus proche à 15 m).
func reward_camp(kind: String, at: Vector3, killer: Combatant) -> void:
	var c: Dictionary = MobaData.CAMPS.get(kind, {})
	if c.is_empty():
		return
	var hs: MobaHero = info.get(killer) if killer != null and is_instance_valid(killer) else null
	if hs == null:
		for side in 2:
			var n := _nearest(at, units_near(side, at, MobaData.SHARE_RADIUS, KIND_HERO))
			if n != null:
				hs = info.get(n)
				break
	if hs == null:
		return
	_xp(hs, float(MobaData.XP_GAIN.get(String(c.xp), 0)))
	hs.add_gold(float(c.get("gold", 0)))
	hs.camps += 1
	hs.camp_times.append(snappedf(Moba.t, 0.1))


## Bonus de force d'un sbire : Étendard des voies d'un héros allié proche (Bannière du Colosse : lot MB-F).
func minion_aura(m: MobaMinion) -> float:
	return MobaItems.minion_aura(m, m.side) if MobaItems.active else 1.0


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
	var hs := MobaHero.new(player, 0, role, cid)
	hs.is_player = true
	hs.difficulty = clampi(int(spec.get("diff_allies", spec.get("diff", 2))), 0, 3)
	hs.auto_pick = bool(spec.get("auto", false)) or player.autoplay
	TeamMatch.add(player, 0)
	heroes.append(player)
	info[player] = hs
	Profile.bag[Potions.key("heal")] = MobaData.START_POTIONS  # (mode scellé : le sac est vide au lancement)
	apply_level(hs)
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
			var hs := MobaHero.new(r, side, role, cid)
			hs.difficulty = int(diffs[side])
			hs.auto_pick = true
			hs.prefer = _ai_prefer(cid)
			hs.think = rng.randf() * HERO_THINK
			r.hero = hs
			info[r] = hs
			add_child(r)
			r.global_position = _fountain_spot(side, heroes.size())
			heroes.append(r)
			apply_level(hs)
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


## Niveau de partie du héros [param hs] posé sur son nœud : fiche d'un héros de sa classe à son niveau (objets compris),
## sorts débloqués (cases 1-3, enchaînements choisis, ultime au niveau 5 à sa recharge et sa puissance de partie, son
## enchaînement au niveau 9).
func apply_level(hs: MobaHero) -> void:
	var h := hs.node
	if h == null or not is_instance_valid(h):
		return
	hs.stats = MobaItems.totals(hs)
	if h is MobaRival:
		var r := h as MobaRival
		r.resheet(hs.level)
		r.set_kit(hs.ult)
		r.health_changed.emit(r.hp, r.max_hp)
	elif h is Player:
		var p := h as Player
		var ratio := p.hp / p.max_hp if p.max_hp > 0.0 and not p.is_dead else 1.0
		p.level = MobaData.sheet_level(hs.level)
		Run.hero_level = p.level
		Run.max_level = p.level
		_player_kit(hs)
		p.recalc_stats()
		p.hp = p.max_hp * ratio
		p.health_changed.emit(p.hp, p.max_hp)


## Sorts du joueur (Run.skills / Run.chains) d'après ce que son niveau a débloqué ; l'ultime à sa recharge de partie
## (clé « cd » de Run : multiplicateur de recharge) et sa puissance (clé « dmg »).
func _player_kit(hs: MobaHero) -> void:
	var u := hs.kit_unlocked()
	var k := MobaData.kit(hs.cid)
	var sk: Array = []
	for id in u.mains:
		var e := {"id": int(id), "rank": 1}
		if int(id) == int(u.ult) and bool(u.ult_on):
			var base := float(Run.skill_def(int(id)).get("cooldown", 0.0))
			var cd := float(k.get("ult", {}).get("cooldown", base))
			if base > 0.0:
				e["cd"] = 1.0 - cd / base
			e["dmg"] = float(k.get("ult", {}).get("power", 1.0)) - 1.0
		sk.append(e)
	Run.skills = sk
	var ch := {}
	for slot in u.chains:
		ch[int(slot)] = (u.chains[slot] as Array).map(func(x): return {"id": int(x), "rank": 1})
	Run.chains = ch
	Run.changed.emit()


## XP gagnée par [param hs] ; un niveau gagné refait sa fiche (une par image) et annonce le choix au joueur.
func _xp(hs: MobaHero, amount: float) -> void:
	var up := hs.add_xp(amount)
	if up <= 0:
		return
	if not hs.node in _resheet:
		_resheet.append(hs.node)
	level_now = maxi(level_now, hs.level)
	if hs.is_player and mode == "all":
		var lv := hs.level
		var what := MobaHero.unlock_at(lv)
		var msg := "Niveau %d !" % lv
		if not hs.pending.is_empty():
			msg += "\nCtrl + 1 / 2 / 3 : un enchaînement"
		elif what == "ult":
			msg += "\nUltime débloqué"
		d.message.emit(msg, 2.2)


func _levels() -> void:
	if not _resheet.is_empty():
		var h = _resheet.pop_front()
		if is_instance_valid(h) and info.has(h):
			apply_level(info[h])


## Choix de niveau (non bloquant) : débloque l'enchaînement suivant de la case [param slot] (0-2) pour [param h].
func choose_chain(h: Combatant, slot: int) -> bool:
	var hs: MobaHero = info.get(h)
	if hs == null or not hs.choose(slot):
		return false
	apply_level(hs)
	return true


## Coup d'un héros sur un héros adverse : appel à l'aide des sbires et des tours de la victime ; rappel coupé.
func _on_hero_damaged(_amount: float, source: Combatant, victim: Combatant) -> void:
	var vs: MobaHero = info.get(victim)
	if vs != null:
		vs.last_combat = Moba.t
		if vs.recalling():
			_cancel_recall(vs)
	if source != null and info.has(source) and side_of(source) != side_of(victim):
		_help[source] = {"t": Moba.t, "pos": victim.global_position}
		if vs != null:
			vs.note_damager(source, Moba.t)


## Héros tombé : réapparition selon son niveau ; prime au tueur (série, premier sang ; à défaut le dernier héros adverse
## qui l'a frappé dans les 10 s), aide partagée, XP de l'élimination partagée entre le tueur et les aides ; effets des
## objets « kill_hero ».
func on_hero_down(h: Combatant, killer: Combatant) -> void:
	if not info.has(h):
		return
	var vs: MobaHero = info[h]
	var t := Moba.t
	vs.deaths += 1
	vs.respawn_at = t + MobaData.respawn_time(vs.level, t)
	vs.home = false
	vs.recall_left = -1.0
	TeamMatch.note_ko(h, killer)
	var kh: Combatant = killer if killer != null and is_instance_valid(killer) and info.has(killer) and side_of(killer) != vs.side else null
	if kh == null:
		kh = vs.last_damager(t)
	var ks: MobaHero = info.get(kh) if kh != null else null
	_note_death(vs, killer, kh)
	if ks != null:
		Moba.hero_kills[ks.side] += 1
		var bounty := MobaData.kill_bounty(vs.streak, not first_blood)
		first_blood = true
		ks.kills += 1
		ks.streak += 1
		ks.add_gold(bounty)
		var helpers: Array = []
		for a in vs.assisters(t, kh):
			var hs: MobaHero = info.get(a)
			if hs != null and hs.side != vs.side:
				helpers.append(hs)
		var parts := helpers.size() + 1
		_xp(ks, float(MobaData.hero_xp(vs.level)) / parts)
		for hs in helpers:
			hs.assists += 1
			hs.add_gold(MobaHero.assist_gold(helpers.size()))
			_xp(hs, float(MobaData.hero_xp(vs.level)) / parts)
		MobaItems.on_kill(ks, helpers)
	vs.streak = 0
	vs.damagers.clear()
	Moba.note("ko", vs.side, {"who": vs.cid, "by": ks.cid if ks != null else ""})


## Journal de la mort (mesures du lot MB-E) : sous une tour adverse, tuée par une tour, un sbire ou un héros.
func _note_death(vs: MobaHero, killer: Combatant, kh: Combatant) -> void:
	var p := vs.node.global_position
	var under := false
	for s in structures:
		if not s.is_dead and s.side != vs.side and p.distance_to(s.global_position) <= s.range_m + 1.0:
			under = true
	var heroes_near := enemies_near(vs.side, p, 15.0, KIND_HERO).size()
	var by := "héros" if killer != null and info.has(killer) else ("tour" if killer is MobaStructure else ("sbire" if killer is MobaMinion else "autre"))
	vs.death_log.append({"t": snappedf(Moba.t, 0.1), "by": by, "under_tower": under, "heroes_near": heroes_near,
		"hero_hit": kh != null, "hp_lvl": vs.level})


func _respawns() -> void:
	for h in heroes:
		var inf: MobaHero = info[h]
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


# --- héros : économie, boutique, rappel (lot MB-D) -----------------------------------------------------

## Chaque image : or et XP passifs, boutique ouverte à la fontaine (annuler s'efface en la quittant), rappel, hors combat
## (Cœur de pierre, Bottes du vent), recharges des potions de l'IA, sorts du joueur (« skill_cast »).
func _heroes_tick(delta: float) -> void:
	var t := Moba.t
	var gold := MobaData.PASSIVE_GOLD * delta if t >= MobaData.FIRST_WAVE else 0.0
	var xp := float(MobaData.XP_GAIN.per_second) * delta
	for h in heroes:
		var hs: MobaHero = info[h]
		hs.add_gold(gold)
		if hs.level < MobaData.LEVEL_MAX:
			_xp(hs, xp)
		for g in hs.potion_cd:
			hs.potion_cd[g] = maxf(0.0, float(hs.potion_cd[g]) - delta)
		var shop: bool = not h.is_dead and h.global_position.distance_to(map.moba.fountains[hs.side]) <= MobaHero.SHOP_RADIUS
		if hs.in_shop and not shop and not h.is_dead:
			MobaItems.leave_shop(hs)
		hs.in_shop = shop
		if h.is_dead:
			continue
		if hs.recalling():
			hs.recall_left -= delta
			var moved: bool = h.global_position.distance_to(hs.recall_from) > 0.8
			if moved:
				_cancel_recall(hs)
			elif hs.recall_left <= 0.0:
				_finish_recall(hs)
		var ooc := not hs.in_combat(t)
		if ooc != hs.ooc:
			hs.ooc = ooc
			if MobaItems.stat(hs, "ooc_move") > 0.0:
				MobaItems.refresh(hs)
		var regen := MobaItems.stat(hs, "ooc_regen")
		if ooc and regen > 0.0 and h.hp < h.max_hp:
			h.hp = minf(h.max_hp, h.hp + h.max_hp * regen * delta)
			h.health_changed.emit(h.hp, h.max_hp)
	if player != null and info.has(player):
		var st: String = player._state
		if st == "skill" and _player_state != "skill":
			MobaItems.on_cast(info[player])
		_player_state = st


## Rappel (« S'extraire », X) : 6 s sans bouger ni être touché, puis la fontaine. false si refusé (mort, déjà à la base).
func start_recall(h: Combatant) -> bool:
	var hs: MobaHero = info.get(h)
	if hs == null or h.is_dead or hs.recalling() or hs.in_shop:
		return false
	hs.recall_left = MobaData.RECALL_TIME
	hs.recall_from = h.global_position
	if h is MobaRival:
		var r := h as MobaRival
		r.goal = Vector3.INF
		r._player = null
		r.passive = true
		r.velocity = Vector3.ZERO
	elif hs.is_player and mode == "all":
		d.message.emit("Retour à la fontaine…", 1.5)
	return true


func _cancel_recall(hs: MobaHero) -> void:
	hs.recall_left = -1.0
	if hs.node is MobaRival:
		(hs.node as MobaRival).passive = false
	elif hs.is_player and mode == "all":
		d.message.emit("Retour coupé", 1.2)


func _finish_recall(hs: MobaHero) -> void:
	hs.recall_left = -1.0
	hs.recalls += 1
	var at := _fountain_spot(hs.side, heroes.find(hs.node))
	var h := hs.node
	if h is MobaRival:
		var r := h as MobaRival
		r.passive = false
		r.global_position = at
		r.velocity = Vector3.ZERO
		r.goal = Vector3.INF
	elif h is Player:
		d._place_player(at)
	hs.in_shop = true


## Potion de soin d'un héros IA (35 % des PV, 20 s de recharge, comme Potions) ; false si rien.
func ai_potion(hs: MobaHero) -> bool:
	if int(hs.potions.get("heal", 0)) <= 0 or float(hs.potion_cd.heal) > 0.0 or hs.node.is_dead:
		return false
	hs.potions.heal = int(hs.potions.heal) - 1
	hs.potion_cd.heal = Potions.COOLDOWN
	hs.node.heal(hs.node.max_hp * Potions.HEAL_PCT)
	Vfx.ring(hs.node, hs.node.global_position, 2.2, Color(0.4, 1.0, 0.5, 0.8))
	return true


## Familles de l'équipe adverse de [param hs] (parcours d'objets adapté).
func foe_families(hs: MobaHero) -> Array:
	var out: Array = []
	for h in heroes:
		var o: MobaHero = info[h]
		if o.side != hs.side:
			out.append(o.family)
	return out


## Ordre des cases quand l'IA choisit ses enchaînements : la case dont le 1er enchaînement frappe le plus fort d'abord.
func _ai_prefer(cid: String) -> Array:
	var k := MobaData.kit(cid)
	var by := {}
	for s in GameData.class_data(cid).get("skills", []):
		by[int(s.id)] = s
	var score := {}
	for i in 3:
		var ch: Array = k.get("slots", [])[i].chains if (k.get("slots", []) as Array).size() > i else []
		var v := 0.0
		for id in ch:
			var s: Dictionary = by.get(int(id), {})
			v += float(s.get("mult", 1.0)) * maxf(1.0, float(s.get("radius", 1.0))) + float(s.get("heal", 0.0)) * 10.0
		score[i] = v
	var order := [0, 1, 2]
	order.sort_custom(func(a, b): return float(score[a]) > float(score[b]))
	return order


# --- données d'affichage (lot MB-H) ----------------------------------------------------------------

## Tout ce qu'un HUD affiche pour le héros [param h] (le joueur par défaut) : MobaHero.view + parcours conseillé, objet
## conseillé (prix, or), tableau des 8 héros (niveau, K / M / A, mort et réapparition), temps, score.
func hud_data(h: Combatant = null) -> Dictionary:
	if h == null:
		h = player
	var hs: MobaHero = info.get(h)
	if hs == null:
		return {}
	var v := hs.view(Moba.t)
	var r := MobaItems.route(hs, foe_families(hs))
	v["route"] = r
	v["advice"] = MobaItems.advice(hs, r)
	v["time"] = Moba.t
	v["score"] = [Moba.hero_kills[0], Moba.hero_kills[1]]
	var board: Array = []
	for x in heroes:
		var o: MobaHero = info[x]
		board.append({"cid": o.cid, "side": o.side, "role": o.role, "level": o.level, "kda": [o.kills, o.deaths, o.assists],
			"dead": x.is_dead, "respawn_in": maxf(0.0, o.respawn_at - Moba.t) if x.is_dead else 0.0, "items": o.items.duplicate()})
	v["board"] = board
	return v


## Interface minimale de test (le HUD du mode est le lot MB-H) : une ligne d'état en haut à gauche.
func _build_hud() -> void:
	if mode != "all" or DisplayServer.get_name() == "headless":
		return
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16, 120)
	_hud.add_theme_font_size_override("font_size", 16)
	_hud.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)


func _update_hud(delta: float) -> void:
	if _hud == null:
		return
	_hud_t -= delta
	if _hud_t > 0.0:
		return
	_hud_t = 0.25
	var v := hud_data()
	if v.is_empty():
		return
	var names: Array = (v.items as Array).map(func(id): return String(MobaData.item(String(id)).name))
	var lines := ["Niveau %d · XP %d / %d · Or %d · %d / %d / %d" % [v.level, int(v.xp), int(v.xp_next), int(v.gold), v.kda[0], v.kda[1], v.kda[2]],
		"Objets : %s" % (", ".join(names) if not names.is_empty() else "aucun")]
	if not (v.pending as Dictionary).is_empty():
		lines.append("Choix de niveau : Ctrl + %s" % " / ".join((v.pending.options as Array).map(func(s): return str(int(s) + 1))))
	if not (v.advice as Dictionary).is_empty():
		lines.append("Conseil : %s %d / %d%s" % [v.advice.name, int(v.advice.gold), int(v.advice.cost), " (P : acheter)" if bool(v.shop_open) else ""])
	if bool(v.shop_open):
		lines.append("Boutique ouverte · Ctrl + Z : annuler")
	if float(v.recall) >= 0.0:
		lines.append("Retour : %d %%" % roundi(float(v.recall) * 100.0))
	_hud.text = "\n".join(lines)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or mode != "all" or ended or player == null or not info.has(player):
		return
	var hs: MobaHero = info[player]
	if k.ctrl_pressed and k.physical_keycode in [KEY_1, KEY_2, KEY_3]:
		if choose_chain(player, k.physical_keycode - KEY_1):
			d.message.emit("Enchaînement débloqué", 1.2)
		get_viewport().set_input_as_handled()
	elif k.ctrl_pressed and k.physical_keycode == KEY_Z:
		if MobaItems.undo(hs):
			d.message.emit("Achat annulé", 1.0)
		get_viewport().set_input_as_handled()
	elif k.physical_keycode == KEY_P:
		var id := MobaItems.next_step(hs, MobaItems.route(hs, foe_families(hs)))
		if id != "" and MobaItems.buy(hs, id):
			d.message.emit("%s acheté" % String(MobaData.item(id).name), 1.2)
		elif not MobaItems.shop_open(hs):
			d.message.emit("La boutique ouvre à la fontaine.", 1.2)
		get_viewport().set_input_as_handled()


# --- IA simple des héros (lot MB-E à venir) ----------------------------------------------------------

func _think_all(delta: float) -> void:
	for h in heroes:
		if h.is_dead:
			continue
		var inf: MobaHero = info[h]
		inf.think = float(inf.think) - delta
		if inf.think > 0.0:
			continue
		inf.think = HERO_THINK
		if inf.recalling():
			continue
		if inf.in_shop and (h is MobaRival or (h as Player).autoplay or inf.auto_pick):
			MobaItems.auto_shop(inf, MobaItems.route(inf, foe_families(inf), inf.difficulty >= 2))
		if h is MobaRival:
			if h.hp < h.max_hp * 0.45 and not inf.in_shop:
				ai_potion(inf)
			_think(h as MobaRival, inf)
		elif h is Player and (h as Player).autoplay:
			(h as Player).autoplay_target = _home_or_lane(h, inf)


func _think(h: MobaRival, inf: MobaHero) -> void:
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


func _home_or_lane(h: Combatant, inf: MobaHero) -> Vector3:
	if h.hp < h.max_hp * 0.25:
		return map.moba.fountains[int(inf.side)]
	return _lane_goal(h, inf)


## Place d'un héros sans adversaire : 4 m derrière le front de sa vague (jamais plus loin que sa T1 si la vague est chez
## lui), hors de portée d'une tour adverse sans sbires alliés ; le jungler soutient la voie la plus en retard.
func _lane_goal(_h: Combatant, inf: MobaHero) -> Vector3:
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
	_heroes_tick(delta)
	_think_all(delta)
	_update_hud(delta)
	if mode == "all" and player != null and not player.is_dead and Input.is_action_just_pressed("extract"):
		start_recall(player)
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
		_finish(Moba.decide(hp, team_gold()), "time")
		return
	var until := float(TeamMatch.spec.get("until", 0.0))
	if until > 0.0 and Moba.t >= until and not measured:
		measured = true
		_report("mesure")
		if "--auto-quit" in OS.get_cmdline_user_args():
			get_tree().quit()


## Or gagné par camp ([bleu, rouge] : décision à la fin au temps).
func team_gold() -> Array:
	var g := [0, 0]
	for h in heroes:
		var hs: MobaHero = info[h]
		g[hs.side] += int(hs.gold_earned)
	return g


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
	if s.kind == "tower":
		var bounty := float(MobaData.BOUNTY.get("t%d" % s.tier, 0))
		for h in heroes:
			if (info[h] as MobaHero).side == by:
				(info[h] as MobaHero).add_gold(bounty)  # (prime de tour : à chacun du camp)
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
	for h in heroes:
		var hs: MobaHero = info[h]
		print("[moba] héros %s%d %s niv %d xp %d or %d (gagné %d) objets %d [%s] %d/%d/%d sbires %d rappels %d" % ["BR"[hs.side], hs.role,
			hs.cid, hs.level, int(hs.xp), int(hs.gold), int(hs.gold_earned), hs.items.size(), ",".join(hs.items), hs.kills, hs.deaths,
			hs.assists, hs.cs, hs.recalls])
	var sheet := []
	for h in heroes:
		var hs: MobaHero = info[h]
		sheet.append({"side": hs.side, "role": hs.role, "cid": hs.cid, "diff": hs.difficulty, "level": hs.level, "gold": int(hs.gold_earned),
			"items": hs.items.size(), "k": hs.kills, "d": hs.deaths, "a": hs.assists, "cs": hs.cs, "camps": hs.camps,
			"camp_times": hs.camp_times, "recalls": hs.recalls, "deaths": hs.death_log})
	print("[moba] bilan " + JSON.stringify({"what": what, "t": snappedf(Moba.t, 0.1), "winner": Moba.winner, "how": Moba.how,
		"structures": Moba.structures_down, "kills": Moba.hero_kills, "heroes": sheet}))
	if _perf:
		print("[moba] image : %s ; sbires vivants : %s" % [JSON.stringify(_stats(_frame_ms)), JSON.stringify(_stats(_alive_samples))])
		print("[moba] logique : %s" % JSON.stringify(_stats(_logic_ms)))
		var hc := []
		for h in heroes:
			if h is MobaRival:
				var r := h as MobaRival
				var hs: MobaHero = info[h]
				var ai_us := float(hs.ai.get("cost_us")) if hs.ai != null else 0.0
				var n := maxf(1.0, float(r.cost_n))
				hc.append([snappedf((float(r.cost_us) + ai_us) / n, 0.1), snappedf(ai_us / n, 0.1)])
		print("[moba] héros µs : %s" % JSON.stringify(hc))
		print("[moba] mesure fin images=%d" % _perf_frames)


## Mesure (--moba-perf) : deux marques autour de tous les scripts de l'image physique (priorités extrêmes).
class _Mark extends Node:
	var cb: Callable

	func _physics_process(_d: float) -> void:
		cb.call()


func _marks() -> void:
	var a := _Mark.new()
	a.process_physics_priority = -1000000
	a.cb = func(): _phys_t0 = Time.get_ticks_usec()
	add_child(a)
	var b := _Mark.new()
	b.process_physics_priority = 1000000
	b.cb = _mark_end
	add_child(b)


func _mark_end() -> void:
	if ended or Moba.t < _perf_from:
		return
	if not _perf_started:
		_perf_started = true
		print("[moba] mesure début")
		for h in heroes:
			if h is MobaRival:
				(h as MobaRival).cost_us = 0
				(h as MobaRival).cost_n = 0
				var hs: MobaHero = info[h]
				if hs.ai != null:
					hs.ai.set("cost_us", 0)
	_perf_frames += 1
	_logic_ms.append((Time.get_ticks_usec() - _phys_t0) / 1000.0)


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
	MobaItems.stop()
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
