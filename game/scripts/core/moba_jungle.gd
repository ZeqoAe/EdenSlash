class_name MobaJungle
extends Node
## Jungle neutre et objectifs des Deux Voies (lot MB-F, MOBA.md § 7.2-7.5, rapport conception/benchmark/R_MB_F.md). Monté
## par MobaDirector (_build_jungle, après les héros) ; tout est créé au chargement et recyclé (aucune création de modèle en
## partie, R_MB0 § 6).
##
##   - 8 camps (MobaMap.moba.camps : par moitié Source, Braise, 2 petits) de monstres neutres MobaCamp : apparition à 1:30,
##     laisse et remise à zéro, réapparition 90 s (petits) / 150 s (Source, Braise) ; Source : recharges plus rapides 90 s
##     (Player.timed_stats « cdr » ; MobaRival : ses minuteurs de sorts avancent plus vite), Braise : coups qui brûlent et
##     ralentissent 90 s (on_hit, branché par une ligne gardée dans Combatant.take_damage) ; le bonus passe au tueur d'un
##     héros qui le porte.
##   - Gardien (3:00, revient 3 min après) et Colosse (9:00, revient 4 min après) dans leur fosse : boss de la bibliothèque
##     (BossLibrary.spawn, ce nœud tient lieu de directeur : _spawn_monster, message, _boss) tirés à la graine parmi ceux qui
##     ont assez de briques jouables dans une fosse (MobaData.BOSS_BANNED, PIT_TUNE) ; annoncés 45 / 60 s avant ; Colosse :
##     fureur 90 s après le début du combat. Gardien = un Sceau pour l'équipe (+4 % de dégâts : Combatant.damage_dealt_mult ;
##     +4 % de PV : PV max suivis à chaque refonte de fiche ; 3 au plus) ; Colosse = Bannière 150 s (sbires alliés à 12 m d'un
##     porteur × 1,5 : MobaMinion.banner_mult, sièges compris, plus gros ; rappel en 3 s : recall_time).
##   - Marée finale (18:00) : annonce ; le reste est dans les règles (MobaData.wave / wave_time : géant de plus, vagues
##     resserrées ; MobaStructure.invulnerable : Cœurs vulnérables ; MobaData.respawn_time × 1,5). Fin au temps : annonce
##     une minute avant ; décision dans Moba.decide (structures, Cœur, objectifs, or, sbires).
##
## Interface pour l'IA (lots MB-E / MB-G), sans triche à la charge de l'appelant (vue honnête : MB-G) :
##   camps_alive(moitié) / camp_list() -> [{key, camp, kind, half, pos, state, hp, respawn_in, engaged, danger, ttk}]
##   objectives_state() -> {guardian: {...}, colossus: {...}} (state waiting | alive | dead, spawn_in, hp, engaged, boss…)
##   buffs_of(héros) -> {source: s, braise: s, banner: s} ; seals [bleu, rouge] ; banner_until ; recall_time(héros)
##   signaux neutral_down(entrée, tueur, équipe) et objective_event(clé, quoi) ; récompenses (XP, or) : reward(entrée), versées
##   par le lot MB-D : camp -> MobaDirector.reward_camp(genre, lieu, tueur) ; objectif -> XP à chaque héros de l'équipe
##   (MobaDirector.reward_objective(clé, équipe, tueur) si elle existe, sinon MobaDirector._xp) ; MobaDirector.on_neutral_down
##   si elle existe. Rappel du porteur de la Bannière : recall_time(héros) (à lire par MobaDirector.start_recall).

signal message(text: String, duration: float)  # (BossLibrary.spawn : annonces des briques du boss)
signal neutral_down(entry: Dictionary, killer: Combatant, team: int)
signal objective_event(key: String, what: String)  # announced | spawned | taken | reset

## Réglages des briques dans une fosse de 8 m (rien ne doit déborder sur les voies, à 21 m des fosses).
const PIT_TUNE := {"gaze": {"radius": 16.0}, "sweep": {"length": 20.0, "lines": 4}, "lasers": {"length": 18.0},
	"meteors": {"spread": 7.0}}
## Fureur du Colosse : un cran toutes les FURY_STEP s après MobaData.OBJECTIVES.colossus.fury_at s de combat.
const FURY_STEP := 30.0
const FURY_ATK := 0.12
const FURY_PACE := 0.95
const FURY_MAX := 6
const THINK := 0.5
const BRAISE_CD := 1.0

static var current: MobaJungle
static var active := false

var director: Node  # MobaDirector
var rng := RandomNumberGenerator.new()
## Camps : {key, camp, kind, name, half, pos, units, state (waiting | alive | dead), respawn_at, aggro {agresseur: t},
## engaged_at, last_hero, cleared [bleu, rouge]}.
var camps: Array = []
## Objectifs : clé -> {key, name, boss_id, pos, unit, state, at, aggro, engaged_at, last_hero, fury, taken [bleu, rouge],
## bricks (types), announced}.
var objectives: Dictionary = {}
var seals := [0, 0]
var banner_until := [-1.0, -1.0]
## Mesures : créations en partie (doit rester 0), temps de script du nœud (µs), monstres éveillés.
var stats := {"created_load": 0, "created_live": 0, "us_sum": 0.0, "us_n": 0, "us_max": 0.0, "over_1ms": 0, "worst": "",
	"camp_us": 0.0, "camp_max": 0.0, "camp_over_1ms": 0, "awake_sum": 0, "awake_n": 0, "awake_max": 0}
## Journal des annonces (test, rapport) : [t, texte].
var said: Array = []
var _boss: Monster  # (BossLibrary.spawn : main = false, jamais posé)
var _pending: Dictionary = {}
var _loading := true
var _think_t := 0.0
var _watch: Dictionary = {}  # héros -> {set (PV max posés), k (part des Sceaux appliquée)}
var _braise_cd: Dictionary = {}  # Vector2i(source, cible) -> instant
var _banner_scaled: Dictionary = {}  # sbire -> vrai
var _said: Dictionary = {}
var _probe: Node
## Héros hors du directeur (sonde, tests) suivis comme les siens : Sceaux, Source, Bannière.
var guests: Array = []
var _trace := "--moba-trace" in OS.get_cmdline_user_args()
var _trace_t := 30.0


func setup(dir: Node) -> void:
	director = dir
	name = "MobaJungle"
	current = self
	active = true
	var spec: Dictionary = TeamMatch.spec
	rng.seed = int(spec.get("seed", director.rng.seed)) * 7919 + 17
	MobaData.warm_ref()
	_build_camps()
	_build_objectives()
	_loading = false
	message.connect(_on_boss_message)
	for h in hero_list():
		_watch_hero(h)
	if spec.has("probe"):
		_probe = load("res://tools/moba_obj_probe.gd").new()
		add_child(_probe)
		_probe.call("start", self, String(spec.probe))


func _exit_tree() -> void:
	if current == self:
		current = null
		active = false


# --- camps ------------------------------------------------------------------------------------------

func _build_camps() -> void:
	var map: MobaMap = director.map
	var n := 0
	for c in map.moba.camps:
		var def: Dictionary = MobaData.CAMPS[String(c.id)]
		var e := {"key": "%s_%d_%d" % [c.id, c.side, n], "camp": String(c.id), "kind": String(def.kind), "name": String(def.name),
			"half": int(c.side), "pos": c.pos, "units": [], "state": "waiting", "respawn_at": MobaData.CAMPS_AT, "aggro": {},
			"engaged_at": -1.0, "last_hero": null, "cleared": [0, 0], "leash": MobaData.CAMP_LEASH}
		var ids: Array = def.ids
		for i in ids.size():
			var off := Vector3.ZERO
			if ids.size() > 1:
				off = Vector3(0, 0, 1.8 if i == 0 else -1.8)
			var u := MobaCamp.new()
			u.setup_camp(self, e, int(ids[i]), c.pos + off, false, 1, float(def.scale))
			add_child(u)
			u.global_position = c.pos + off
			u.park()
			stats.created_load = int(stats.created_load) + 1
			(e.units as Array).append(u)
		camps.append(e)
		n += 1


func _spawn_camp(e: Dictionary) -> void:
	var st := MobaData.camp_stats(String(e.camp), Moba.t)
	for u in e.units:
		(u as MobaCamp).revive(st)
	e.state = "alive"
	e.aggro = {}
	e.engaged_at = -1.0
	e.last_hero = null


## Agresseur le plus proche de [param u] parmi ceux de son camp, encore dans la laisse (les autres sont oubliés).
func camp_target(u: MobaCamp) -> Combatant:
	var e: Dictionary = u.entry
	var ag: Dictionary = e.aggro
	var lim := float(e.leash) + 2.0
	var best: Combatant = null
	var bd := INF
	for a in ag.keys():
		if not is_instance_valid(a) or a.is_dead or not a.visible or not (a as Node3D).is_inside_tree():
			ag.erase(a)
			continue
		var p: Vector3 = a.global_position
		if Vector2(p.x - e.pos.x, p.z - e.pos.z).length() > lim:
			ag.erase(a)
			continue
		var dd := u.global_position.distance_squared_to(p)
		if dd < bd:
			bd = dd
			best = a
	return best


## [param src] vient de frapper [param u] : il devient l'agresseur de tout le camp (qui se réveille).
func note_aggro(u: MobaCamp, src: Combatant) -> void:
	var e: Dictionary = u.entry
	if String(e.get("state", "")) != "alive":
		return
	var first := (e.aggro as Dictionary).is_empty()
	e.aggro[src] = Moba.t
	for x in _units_of(e):
		x.lod = 0
	if Combatant.is_hero(src):
		e.last_hero = src
	if float(e.engaged_at) < 0.0:
		e.engaged_at = Moba.t
	for x in _units_of(e):
		x.set_asleep(false)
	if first and e.has("boss_id"):
		objective_event.emit(String(e.key), "engaged")


## Remise à zéro de tout le camp (laisse) : agresseurs oubliés, retour au point du camp, PV pleins, fureur retirée.
func reset_entry(e: Dictionary) -> void:
	e.aggro = {}
	e.engaged_at = -1.0
	e.fury = 0
	for u in _units_of(e):
		if not u.is_dead and not u.parked and not u.resetting:
			u.begin_reset()
	if e.has("boss_id"):
		objective_event.emit(String(e.key), "reset")


func _units_of(e: Dictionary) -> Array:
	if e.has("units"):
		return e.units
	return [e.unit] if e.get("unit") != null else []


## Un monstre neutre tombe : le camp (ou l'objectif) est pris quand tous ses monstres sont tombés.
func on_unit_down(u: MobaCamp, killer: Combatant) -> void:
	var e: Dictionary = u.entry
	for x in _units_of(e):
		if not x.is_dead:
			return
	var hero: Combatant = killer if killer != null and is_instance_valid(killer) and Combatant.is_hero(killer) else null
	if hero == null and is_instance_valid(e.get("last_hero")) and not (e.last_hero as Combatant).is_dead:
		hero = e.last_hero
	var team: int = director.side_of(hero if hero != null else killer)
	if e.has("boss_id"):
		_objective_taken(e, hero, team)
	else:
		_camp_cleared(e, hero, team)
	if team >= 0:
		Moba.neutral_kills[team] += 1
	_pay(e, hero, team)
	if director.has_method("on_neutral_down"):
		director.on_neutral_down(e, hero if hero != null else killer, team)
	neutral_down.emit(e, hero if hero != null else killer, team)


## XP et or (économie du lot MB-D, MobaHero) : un camp à son tueur (MobaDirector.reward_camp), un objectif à chaque héros
## de l'équipe qui le prend, vivant ou non (MobaDirector.reward_objective, sinon MobaDirector._xp).
func _pay(e: Dictionary, hero: Combatant, team: int) -> void:
	if team < 0:
		return
	if not e.has("boss_id"):
		if director.has_method("reward_camp"):
			director.reward_camp(String(e.camp), e.pos, hero)
		return
	if director.has_method("reward_objective"):
		director.reward_objective(String(e.key), team, hero)
		return
	if not director.has_method("_xp"):
		return
	var xp := float(reward(e).xp)
	for h in director.heroes:
		if director.side_of(h) == team and director.info.has(h):
			director._xp(director.info[h], xp)


func _camp_cleared(e: Dictionary, hero: Combatant, team: int) -> void:
	var def: Dictionary = MobaData.CAMPS[String(e.camp)]
	e.state = "dead"
	e.respawn_at = Moba.t + float(def.respawn)
	e.aggro = {}
	e.engaged_at = -1.0
	if team >= 0:
		e.cleared[team] = int(e.cleared[team]) + 1
	Moba.note("camp", team, {"camp": String(e.camp), "half": int(e.half)})
	if String(def.kind) == "buff" and hero != null and is_instance_valid(hero) and not hero.is_dead:
		give_buff(hero, String(e.camp))


## XP et or d'un camp ou d'un objectif (versés par le lot MB-D) : {xp (à chacun des héros proches ou de l'équipe), gold}.
func reward(e: Dictionary) -> Dictionary:
	if e.has("boss_id"):
		var o: Dictionary = MobaData.OBJECTIVES[String(e.key)]
		return {"xp": int(MobaData.XP_GAIN[String(o.xp)]), "gold": 0, "team": true}
	var def: Dictionary = MobaData.CAMPS[String(e.camp)]
	return {"xp": int(MobaData.XP_GAIN[String(def.xp)]), "gold": int(def.gold), "team": false}


# --- bonus des camps ----------------------------------------------------------------------------------

## Bonus de la Source ou de la Braise ([param camp]) pour [param h], MobaData.CAMPS.buff_time s (perdu à la mort : il passe
## à son tueur s'il est un héros adverse).
func give_buff(h: Combatant, camp: String, secs := -1.0) -> void:
	var def: Dictionary = MobaData.CAMPS[camp]
	var st := String(def.status)
	var dur := float(def.buff_time) if secs <= 0.0 else secs
	if h is Player and camp == "source":
		(h as Player).timed_stats[st] = {"cdr": float(def.buff.cdr)}  # (recalc_stats : à chaque changement d'états)
	h.add_status(st, dur, h)
	DamageNumber.spawn_text(h, String(def.name).to_upper() + " !", Color(0.45, 0.85, 1.0) if camp == "source" else Color(1.0, 0.45, 0.4))
	_say(h, "%s : %s" % [def.name, def.text])


## Bonus en cours de [param h] (secondes restantes) : {source, braise, banner}.
func buffs_of(h: Combatant) -> Dictionary:
	var out := {}
	if h == null or not is_instance_valid(h):
		return out
	for k in [["source", String(MobaData.CAMPS.source.status)], ["braise", String(MobaData.CAMPS.braise.status)],
			["banner", String(MobaData.BANNER.status)]]:
		var left := float(h.statuses.get(k[1], -1.0)) - h.clock
		if left > 0.0:
			out[k[0]] = left
	return out


## Coup de [param src] sur [param victim] (Combatant.take_damage, gardé par MobaJungle.active) : la Braise brûle et ralentit
## (une fois par seconde et par cible ; jamais une structure, jamais un effet sur la durée).
static func on_hit(src: Combatant, victim: Combatant, dot: bool) -> void:
	var j := current
	if j == null or dot or src == null or not is_instance_valid(src) or src == victim or victim.is_dead:
		return
	if not src.has_status(String(MobaData.CAMPS.braise.status)) or victim is MobaStructure:
		return
	var key := Vector2i(src.get_instance_id() % 1000003, victim.get_instance_id() % 1000003)
	if float(j._braise_cd.get(key, -1.0)) > Moba.t:
		return
	j._braise_cd[key] = Moba.t + BRAISE_CD
	var b: Dictionary = MobaData.CAMPS.braise.buff
	victim.add_status("burn", float(b.burn), src)
	victim.add_status("chill", float(b.chill), src)


## Part des dégâts infligés par [param c] (Combatant.damage_dealt_mult, gardé par MobaJungle.active) : les Sceaux de son équipe.
static func dealt_mult(c: Combatant) -> float:
	var j := current
	if j == null or not (c is Player or c is ClassRival):
		return 1.0
	var s := c.ffa_id - TeamMatch.FFA_BASE
	if s < 0 or s > 1:
		return 1.0
	return 1.0 + float(MobaData.SEAL.dmg) * int(j.seals[s])


## Rappel (« S'extraire », lot MB-D) : 3 s pour un porteur de la Bannière, sinon MobaData.RECALL_TIME.
func recall_time(h: Combatant) -> float:
	if h != null and is_instance_valid(h) and h.has_status(String(MobaData.BANNER.status)):
		return float(MobaData.BANNER.recall)
	return MobaData.RECALL_TIME


## Force d'un sbire (MobaDirector.minion_aura) : × 1,5 près d'un héros allié qui porte la Bannière du Colosse.
func minion_aura(m: MobaMinion) -> float:
	if float(banner_until[m.side]) < Moba.t:
		return 1.0
	var r2 := float(MobaData.BANNER.radius) * float(MobaData.BANNER.radius)
	var st := String(MobaData.BANNER.status)
	for h in hero_list():
		if not h.is_dead and director.side_of(h) == m.side and h.has_status(st) and h.global_position.distance_squared_to(m.global_position) <= r2:
			return float(MobaData.BANNER.minion_mult)
	return 1.0


# --- objectifs ------------------------------------------------------------------------------------------

## Briques jouables d'un boss dans une fosse (ni invocation, ni bouclier à invoquer, ni arène, ni fureur : celle du Colosse est
## tenue ici), réglées pour la fosse (PIT_TUNE).
static func pit_bricks(id: String) -> Array:
	var out: Array = []
	for b in BossLibrary.get_def(id).get("bricks", []):
		var t := String(b.get("type", ""))
		if t == "frenzy" or t in (MobaData.BOSS_BANNED.types as Array) or BossBricks.family_of(t) in (MobaData.BOSS_BANNED.families as Array):
			continue
		var raw: Dictionary = (b as Dictionary).duplicate()
		raw.merge(PIT_TUNE.get(t, {}), true)
		var n := BossBricks.normalize(raw)
		if not n.is_empty():
			out.append(n)
	return out


## Gardien et Colosse de la partie : tirés à la graine parmi les boss qui ont assez de briques jouables (2 et 3).
func pick_bosses() -> Dictionary:
	var ids: Array = BossLibrary.ids()
	ids.sort()
	var out := {}
	for key in ["guardian", "colossus"]:
		var need := int(MobaData.OBJECTIVES[key].bricks)
		var pool: Array = []
		for id in ids:
			if id in out.values() or GameData.monster(int(BossLibrary.get_def(id).monster)).is_empty():
				continue
			if pit_bricks(id).size() >= need:
				pool.append(id)
		out[key] = String(pool[rng.randi() % pool.size()]) if not pool.is_empty() else String(ids[0])
	return out


func _build_objectives() -> void:
	var map: MobaMap = director.map
	var picks := pick_bosses()
	for key in ["guardian", "colossus"]:
		var o: Dictionary = MobaData.OBJECTIVES[key]
		var id := String(picks[key])
		var list := pit_bricks(id).slice(0, int(o.bricks))
		var e := {"key": key, "name": String(o.name), "boss_id": id, "pos": map.moba.objectives[key], "unit": null, "state": "waiting",
			"at": float(o.at), "aggro": {}, "engaged_at": -1.0, "last_hero": null, "fury": 0, "taken": [0, 0],
			"bricks": list.map(func(b): return String(b.type)), "announced": false, "leash": MobaData.OBJ_LEASH}
		_pending = e
		var st := MobaData.objective_stats(key, float(o.at))
		var m: Monster = BossLibrary.spawn(id, int(o.lib_tier), {"director": self, "pos": e.pos, "level": int(st.level), "main": false,
			"hit_cap": float(o.hit_cap), "bricks": list})
		_pending = {}
		var u := m as MobaCamp
		if u == null:
			push_error("MobaJungle : %s introuvable" % id)
			continue
		u.display_name = "<Boss> %s, %s" % [BossLibrary.short_name(id), o.name]
		u.base_pace = u.brain.pace if u.brain else 1.0
		u.park()
		e.unit = u
		objectives[key] = e


## (BossLibrary.spawn) Le boss d'un objectif : un MobaCamp de l'objectif en cours de préparation (jamais pendant la partie).
func _spawn_monster(id: int, pos: Vector3, lv: int, boss := false, _into: Monster = null) -> Monster:
	var u := MobaCamp.new()
	u.setup_camp(self, _pending, id, pos, boss, lv, 1.0)
	add_child(u)
	u.global_position = pos + Vector3.UP * 0.4
	if _loading:
		stats.created_load = int(stats.created_load) + 1
	else:
		stats.created_live = int(stats.created_live) + 1
	return u


func _spawn_objective(e: Dictionary) -> void:
	var u: MobaCamp = e.unit
	if u == null:
		return
	var st := MobaData.objective_stats(String(e.key), Moba.t)
	u.revive(st)
	e.state = "alive"
	e.aggro = {}
	e.engaged_at = -1.0
	e.fury = 0
	e.announced = false
	e.last_hero = null
	_say(null, "%s apparaît dans la rivière !" % e.name, 3.0)
	objective_event.emit(String(e.key), "spawned")


## Objectif [param key] tout de suite (outils, tests) : il apparaît à la prochaine image.
func force_spawn(key: String) -> void:
	var e: Dictionary = objectives.get(key, {})
	if e.is_empty():
		return
	if String(e.state) == "alive":
		var u: MobaCamp = e.unit
		if u.is_dead or u.parked:
			e.state = "dead"
	e.at = Moba.t
	if String(e.state) != "alive":
		e.state = "waiting"


func _objective_taken(e: Dictionary, hero: Combatant, team: int) -> void:
	var o: Dictionary = MobaData.OBJECTIVES[String(e.key)]
	e.state = "dead"
	e.at = Moba.t + float(o.respawn)
	e.aggro = {}
	e.engaged_at = -1.0
	e.fury = 0
	Moba.note(String(e.key), team, {"boss": String(e.boss_id)})
	if team < 0:
		return
	e.taken[team] = int(e.taken[team]) + 1
	Moba.objectives_taken[team] += 1
	var mine: bool = team == TeamMatch.player_team
	if String(o.reward) == "seal":
		seals[team] = mini(int(seals[team]) + 1, int(MobaData.SEAL.max))
		_say(null, ("Le Gardien est à vous : un Sceau !" if mine else "L'équipe adverse prend le Gardien.") , 3.0)
	else:
		banner_until[team] = Moba.t + float(MobaData.BANNER.time)
		for h in hero_list():
			if not h.is_dead and director.side_of(h) == team:
				h.add_status(String(MobaData.BANNER.status), float(MobaData.BANNER.time), h)
		_say(null, ("Le Colosse est à vous : la Bannière !" if mine else "L'équipe adverse prend le Colosse !"), 3.0)
	objective_event.emit(String(e.key), "taken")
	print("[moba] %s pris par %s à %d:%02d" % [e.name, ["bleu", "rouge"][team], int(Moba.t) / 60, int(Moba.t) % 60])


# --- boucle -----------------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if director == null or director.ended:
		return
	var t0 := Time.get_ticks_usec()
	var t := Moba.t
	var spawns := 0
	for e in camps:
		if String(e.state) != "alive" and t >= float(e.respawn_at) and spawns < 2:
			spawns += 1  # (2 camps par image au plus : l'apparition de 1:30 étalée sur 4 images)
			_spawn_camp(e)
			if not _said.has("camps"):
				_said["camps"] = true
				_say(null, "La jungle s'éveille : Source et Braise donnent un bonus.", 3.0)
	for key in objectives:
		var e: Dictionary = objectives[key]
		var o: Dictionary = MobaData.OBJECTIVES[key]
		if String(e.state) == "alive":
			_fury(e, o)
			continue
		var ann := float(MobaData.ANNOUNCE.get(key, 30.0))
		if not bool(e.announced) and t >= float(e.at) - ann and t < float(e.at):
			e.announced = true
			_say(null, "%s arrive dans %d s" % [e.name, ceili(float(e.at) - t)], 3.0)
			objective_event.emit(String(key), "announced")
		if t >= float(e.at):
			_spawn_objective(e)
	var t1 := Time.get_ticks_usec()
	_heroes(delta)
	var t2 := Time.get_ticks_usec()
	_think_t -= delta
	if _think_t <= 0.0:
		_think_t = THINK
		_sleep_wake()
		_banner_look()
		_timeline(t)
	var t3 := Time.get_ticks_usec()
	var us := float(t3 - t0)
	stats.us_sum = float(stats.us_sum) + us
	stats.us_n = int(stats.us_n) + 1
	if us > 1000.0:
		stats.over_1ms = int(stats.over_1ms) + 1
	if us > float(stats.us_max):
		stats.us_max = us
		stats.worst = "%d:%02d apparitions %d µs, héros %d µs, revue %d µs" % [int(t) / 60, int(t) % 60, t1 - t0, t2 - t1, t3 - t2]
	if _trace and t >= _trace_t:
		_trace_t = t + 30.0
		var c := cost()
		print("[moba] jungle t=%d µs=%.1f/%.0f camps_us=%.1f/%.0f sup1ms=%d/%d éveillés=%.1f (au plus %d) sceaux=%s bannière=%s pris=%s" % [int(t),
			float(c.us_avg), float(c.us_max), float(c.camps_avg), float(c.camp_max), int(c.over_1ms), int(c.camp_over_1ms), float(c.awake_avg),
			int(c.awake_max), str(seals), str(banner_until.map(func(x): return int(x))), str(Moba.objectives_taken)])


## Fureur du Colosse : un cran toutes les FURY_STEP s après « fury_at » s de combat (remise à zéro : retirée).
func _fury(e: Dictionary, o: Dictionary) -> void:
	if not o.has("fury_at") or float(e.engaged_at) < 0.0:
		return
	var u: MobaCamp = e.unit
	if u == null or u.is_dead or u.resetting:
		return
	var since := Moba.t - float(e.engaged_at) - float(o.fury_at)
	if since < 0.0:
		return
	var want := mini(int(since / FURY_STEP) + 1, FURY_MAX)
	while int(e.fury) < want:
		e.fury = int(e.fury) + 1
		u.atk *= 1.0 + FURY_ATK
		if u.brain:
			u.brain.pace *= FURY_PACE
		if int(e.fury) == 1:
			_say(u, "%s entre en fureur !" % e.name, 2.5)


## Héros de la partie (ceux du directeur et les invités).
func hero_list() -> Array:
	return director.heroes + guests if not guests.is_empty() else director.heroes


func _heroes(delta: float) -> void:
	for h in hero_list():
		if not is_instance_valid(h):
			continue
		if not _watch.has(h):
			_watch_hero(h)
		if not h.is_dead:
			tend_hero(h, delta)


## Un héros vivant : bonus des Sceaux de son équipe sur ses PV max (suivis : une fiche refaite ailleurs donne de nouveaux PV
## de base, le bonus y est remis) ; Source d'un héros scripté (ses minuteurs de sorts avancent plus vite).
func tend_hero(h: Combatant, delta: float) -> void:
	if not _watch.has(h):
		_watch_hero(h)
	var side: int = director.side_of(h)
	var k := 1.0 + float(MobaData.SEAL.hp) * (int(seals[side]) if side >= 0 else 0)
	var w: Dictionary = _watch[h]
	if not is_equal_approx(h.max_hp, float(w.set)):
		w.k = 1.0  # (fiche refaite ailleurs : de nouveaux PV de base)
	if not is_equal_approx(float(w.k), k):
		var r := k / float(w.k)
		h.max_hp *= r
		h.hp = minf(h.max_hp, h.hp * r)
		w.k = k
		h.health_changed.emit(h.hp, h.max_hp)
	w.set = h.max_hp
	if h is ClassRival and h.has_status(String(MobaData.CAMPS.source.status)):
		var rv := h as ClassRival
		var cdr := float(MobaData.CAMPS.source.buff.cdr)
		var step := delta * cdr / (1.0 - cdr)  # (recharge × (1 − cdr))
		for id in rv._skill_ready:
			rv._skill_ready[id] = float(rv._skill_ready[id]) - step
		rv._support_ready_at -= step


func _watch_hero(h: Combatant) -> void:
	_watch[h] = {"set": -1.0, "k": 1.0}
	if not h.died.is_connected(_on_hero_died):
		h.died.connect(_on_hero_died)


## Héros tombé : ses bonus de camp passent à son tueur s'il est un héros adverse (le temps qui leur restait).
func _on_hero_died(h: Combatant, killer: Combatant) -> void:
	if killer == null or not is_instance_valid(killer) or not Combatant.is_hero(killer) or killer.is_dead:
		return
	if director.side_of(killer) == director.side_of(h) or director.side_of(killer) < 0:
		return
	var b := buffs_of(h)
	for camp in ["source", "braise"]:
		if b.has(camp):
			give_buff(killer, camp, float(b[camp]))


## Camps sans héros à MobaData.CAMP_WAKE m (ni la caméra) : endormis.
func _sleep_wake() -> void:
	var near_pts: Array = []
	for h in hero_list():
		if not h.is_dead:
			near_pts.append(h.global_position)
	var rig = director.d.world.rig if director.d != null and director.d.world != null else null
	if rig != null and is_instance_valid(rig.target):
		near_pts.append((rig.target as Node3D).global_position)
	var r2 := MobaData.CAMP_WAKE * MobaData.CAMP_WAKE
	var awake := 0
	for e in camps + objectives.values():
		if String(e.state) != "alive":
			continue
		var near := not (e.aggro as Dictionary).is_empty()
		if not near:
			for p in near_pts:
				if (p as Vector3).distance_squared_to(e.pos) <= r2:
					near = true
					break
		for u in _units_of(e):
			var cu := u as MobaCamp
			if cu.is_dead or cu.parked:
				continue
			cu.set_asleep(not near and not cu.resetting and cu.hp >= cu.max_hp - 0.5 and cu._away() < 1.5)
			if not cu.asleep:
				awake += 1
				# éveillé sans combat (un héros passe) : il pense une image sur 2 ; au combat, à chaque image
				cu.lod = 0 if cu.resetting or not (e.aggro as Dictionary).is_empty() else 1
	stats.awake_sum = int(stats.awake_sum) + awake
	stats.awake_n = int(stats.awake_n) + 1
	stats.awake_max = maxi(int(stats.awake_max), awake)


## Sbires renforcés par la Bannière : plus gros.
func _banner_look() -> void:
	var any := float(banner_until[0]) >= Moba.t or float(banner_until[1]) >= Moba.t
	if not any and _banner_scaled.is_empty():
		return
	var k := float(MobaData.BANNER.scale)
	for m in director.minions:
		var mm := m as MobaMinion
		var up := not mm.is_dead and any and minion_aura(mm) > 1.0
		if up and not _banner_scaled.has(mm):
			_banner_scaled[mm] = true
			if mm.model:
				mm.model.scale = mm._base_scale * k
		elif not up and _banner_scaled.has(mm):
			_banner_scaled.erase(mm)
			if mm.model and not mm.is_dead:
				mm.model.scale = mm._base_scale
	for b in _braise_cd.keys():
		if float(_braise_cd[b]) < Moba.t:
			_braise_cd.erase(b)


## Annonces de la Marée finale et de la fin au temps.
func _timeline(t: float) -> void:
	if t >= MobaData.TIDE_AT - MobaData.TIDE_WARN and t < MobaData.TIDE_AT and not _said.has("tide_warn"):
		_said["tide_warn"] = true
		_say(null, "La Marée monte dans %d s" % ceili(MobaData.TIDE_AT - t), 3.0)
	if t >= MobaData.TIDE_AT and not _said.has("tide"):
		_said["tide"] = true
		_say(null, "Marée finale ! Les Cœurs sont vulnérables", 4.0)
		Moba.note("tide", -1)
	if t >= MobaData.END_AT - MobaData.END_WARN and t < MobaData.END_AT and not _said.has("end_warn"):
		_said["end_warn"] = true
		_say(null, "Plus qu'une minute : les structures détruites décideront", 3.0)


## Annonce au joueur (bandeau du HUD) : les annonces de partie toujours, celles d'un boss ou d'un héros seulement près de lui.
func _say(near: Node3D, text: String, secs := 2.5) -> void:
	said.append([snappedf(Moba.t, 0.1), text])
	if director.mode != "all" or director.d == null:
		return
	var p: Combatant = director.player
	if near != null and is_instance_valid(near) and p != null and is_instance_valid(p) and near != p \
			and p.global_position.distance_to(near.global_position) > 30.0:
		return
	director.d.message.emit(text, secs)


## (BossLibrary.spawn : annonces des briques) relayées près du joueur seulement (le boss vivant le plus proche de lui).
func _on_boss_message(text: String, secs: float) -> void:
	var from: Node3D = null
	var bd := INF
	var p: Combatant = director.player
	for e in objectives.values():
		var u: MobaCamp = e.unit
		if u != null and not u.is_dead and not u.parked:
			var dd := u.global_position.distance_squared_to(p.global_position) if p != null and is_instance_valid(p) else 0.0
			if dd < bd:
				bd = dd
				from = u
	_say(from, text, secs)


# --- interface pour l'IA (lots MB-E, MB-G) ------------------------------------------------------------

## Danger d'un camp pour un héros seul au niveau attendu : part de ses PV perdue par seconde à le tenir (≈ un coup toutes les
## Monster.ATTACK_COOLDOWN s par monstre) ; ttk : temps visé pour le tuer seul (MobaData « secs »).
func danger(e: Dictionary) -> Dictionary:
	var ref := MobaData.ref_hero(MobaData.expected_level(Moba.t))
	var dps := 0.0
	for u in _units_of(e):
		if not u.is_dead and not u.parked:
			dps += u.atk * 100.0 / (100.0 + maxf(float(ref.def), 0.0)) / Monster.ATTACK_COOLDOWN
	var secs := float((MobaData.OBJECTIVES[String(e.key)] if e.has("boss_id") else MobaData.CAMPS[String(e.camp)]).secs)
	return {"hp_per_s": dps / maxf(float(ref.hp), 1.0), "ttk": secs}


func _entry_view(e: Dictionary) -> Dictionary:
	var hp := 0.0
	var mx := 0.0
	for u in _units_of(e):
		if not u.is_dead and not u.parked:
			hp += u.hp
			mx += u.max_hp
	var dg := danger(e)
	var v := {"key": String(e.key), "pos": e.pos, "state": String(e.state), "hp": hp / mx if mx > 0.0 else 0.0,
		"engaged": not (e.aggro as Dictionary).is_empty(), "danger": float(dg.hp_per_s), "ttk": float(dg.ttk)}
	if e.has("boss_id"):
		v.merge({"name": String(e.name), "boss": String(e.boss_id), "bricks": e.bricks, "fury": int(e.fury), "taken": (e.taken as Array).duplicate(),
			"spawn_in": maxf(0.0, float(e.at) - Moba.t) if String(e.state) != "alive" else 0.0})
	else:
		v.merge({"camp": String(e.camp), "kind": String(e.kind), "half": int(e.half),
			"respawn_in": maxf(0.0, float(e.respawn_at) - Moba.t) if String(e.state) != "alive" else 0.0})
	return v


## Tous les camps (vivants ou non) : voir l'en-tête.
func camp_list() -> Array:
	return camps.map(func(e): return _entry_view(e))


## Camps vivants, de la moitié [param half] (0 bleue, 1 rouge ; -1 : toutes).
func camps_alive(half := -1) -> Array:
	var out: Array = []
	for e in camps:
		if String(e.state) == "alive" and (half < 0 or int(e.half) == half):
			out.append(_entry_view(e))
	return out


## État des objectifs : {guardian, colossus} -> vue (+ seals, banner).
func objectives_state() -> Dictionary:
	var out := {}
	for key in objectives:
		out[key] = _entry_view(objectives[key])
	out["seals"] = seals.duplicate()
	out["banner_until"] = banner_until.duplicate()
	return out


## Coût moyen et au pire du nœud par image physique (µs) et celui des monstres neutres (leur _physics_process, cumulé
## par image), images au-dessus de 1 ms, monstres éveillés en moyenne (mesures).
func cost() -> Dictionary:
	var n := maxi(int(stats.us_n), 1)
	return {"us_avg": snappedf(float(stats.us_sum) / n, 0.1), "us_max": snappedf(float(stats.us_max), 1.0),
		"camps_avg": snappedf(float(stats.camp_us) / n, 0.1), "camp_max": snappedf(float(stats.camp_max), 1.0),
		"over_1ms": int(stats.over_1ms), "camp_over_1ms": int(stats.camp_over_1ms), "frames": int(stats.us_n), "worst": String(stats.worst),
		"awake_avg": snappedf(float(stats.awake_sum) / maxf(1.0, float(stats.awake_n)), 0.1), "awake_max": int(stats.awake_max)}
