class_name SpawnDirector
extends RefCounted
## Apparition des monstres de la carte (passe P15, retour du joueur : « des entités DIFFÉRENTES plutôt qu'un pack de
## 10 champignons qui viennent du même côté ; les faire venir de tous les côtés, espacés »). Composant réutilisable :
## il lit la zone (bestiaire), le temps de la carte et le niveau du héros du directeur [member d] ; le Survivant le
## réutilise tel quel (RunDirector._update_spawns) ou en change les tables ([member squads], [member events], [member pace]).
##
## 1. Rôles : chaque monstre du bestiaire de la zone a un rôle (ROLES : essaim léger, mêlée rapide, chargeur, tireur,
##    tank lent, soigneur) d'après son modèle (MODEL_ROLES) ou son identifiant (ID_ROLES) ; le rôle règle ses PV, ses
##    dégâts, sa vitesse, sa taille et son attaque, et sa part dans un groupe (cost : 1 = un monstre ordinaire).
##    Chaque rôle a un plafond de monstres vivants (pas 10 tireurs).
## 2. Groupes : le flux continu envoie des escouades mélangées (SQUADS, débloquées avec le temps) d'un « budget » égal à
##    l'ancien pack (4 + minutes, 8-12 en rage) × PACE ; jamais plus de SAME_SPECIES_MAX fois la même espèce dans un groupe.
## 3. Événements (toutes les 45 s, 30 s en rage, un « dur » puis un « léger ») : encerclement annoncé (cercles au sol),
##    élite escortée, ruée d'essaim, prise en tenaille ; en rage, des élites enragées (flèche d'arrivée).
## 4. Direction : anneau hors écran autour du héros (RING), angle d'or d'un groupe au suivant, 8 secteurs ; un secteur
##    qui vient de servir « chauffe » et attend (HEAT_HALF_LIFE) ; le dos du héros (sens de sa marche) est moins souvent
##    choisi et toujours signalé (flèche au bord de l'écran), le devant aussi (sinon les groupes barrent sa route) ; deux
##    groupes d'un même événement sont à MIN_GAP_DEG au moins. Point refusé hors de la carte, en pente ou derrière un mur
##    (chemin trop long), glissé sur le maillage de navigation (jamais dans le décor) ; jamais de famine (voir _point).
## 5. Puissance : MonsterScaling (niveau suivant celui du héros, PV et dégâts selon l'équipement porté, lissés).
## `--spawn=legacy` : ancien spawn (mesures avant / après) ; les mesures restent relevées (ligne « [spawn] »).

static var legacy := false

const ROLES := {
	"swarm": {"name": "essaim", "hp": 0.5, "atk": 0.45, "speed": 1.15, "scale": 0.85, "cost": 0.5, "max": 30},
	"melee": {"name": "mêlée", "hp": 1.0, "atk": 1.0, "speed": 1.08, "scale": 1.0, "cost": 1.0, "max": 30},
	"charger": {"name": "chargeur", "hp": 1.1, "atk": 0.9, "speed": 1.0, "scale": 1.05, "cost": 1.1, "max": 6, "kind": "charge"},
	"ranged": {"name": "tireur", "hp": 0.8, "atk": 0.65, "speed": 0.95, "scale": 1.0, "cost": 0.8, "max": 6, "kind": "ranged"},
	"tank": {"name": "tank", "hp": 2.4, "atk": 1.3, "speed": 0.72, "scale": 1.2, "cost": 2.2, "max": 6},
	"support": {"name": "soigneur", "hp": 1.2, "atk": 0.4, "speed": 0.9, "scale": 1.0, "cost": 1.2, "max": 3, "kind": "ranged"},
}
## (PV par point de budget ≈ 1 pour chaque rôle : un groupe mélangé pèse autant que l'ancien pack ; l'expérience
## suit le coût, « cost ».)
## Rôle par modèle d'Eden (le même modèle porte souvent plusieurs noms) ; « melee » par défaut.
const MODEL_ROLES := {
	"m025": "swarm", "m086": "swarm", "m032": "swarm", "m093": "swarm", "m102": "swarm", "m087": "swarm", "m096": "swarm",
	"m018": "charger", "m072": "charger", "m073": "charger", "m074": "charger", "m080": "charger", "m105": "charger", "m035": "charger",
	"m020": "tank", "m019": "tank", "m076": "tank", "m023": "tank", "m083": "tank", "m033": "tank", "m034": "tank",
	"m101": "tank", "m079": "tank", "m058": "tank", "m069": "tank", "m016": "tank", "m014": "tank",
	"m024": "ranged", "m085": "ranged", "m091": "ranged", "m053": "ranged", "m107": "ranged", "m042": "ranged",
	"m015": "ranged", "m062": "ranged", "m132": "ranged", "m090": "ranged", "m028": "ranged",
	"m071": "support", "m129": "support", "m084": "support",
}
## Exceptions par monstre (même modèle, autre rôle) : soigneurs, mages et chasseurs.
const ID_ROLES := {
	56003: "support",  # Angelly arc-en-ciel (Limestone)
	56002: "melee", 56006: "melee",  # yack et golem forgé (Limestone : la mêlée n'est pas un champignon)
	56027: "support",  # Ancien de la forêt
	56081: "support",  # Behelder enchanteur
	56178: "support",  # prêtre de Toroto
	56137: "ranged",  # mage ailé
	56058: "ranged", 56059: "ranged", 56166: "ranged",  # trappeur, sorcier tribal, chasseur du culte
}
## Escouades du flux continu : rôles et parts (mises à l'échelle du budget), minute d'apparition, poids.
const SQUADS := [
	{"id": "meute", "from": 0.0, "w": 3.0, "roles": {"melee": 3, "swarm": 1}},
	{"id": "essaim", "from": 0.0, "w": 1.0, "roles": {"swarm": 3, "melee": 2}},
	{"id": "chargeurs", "from": 0.0, "w": 2.0, "roles": {"charger": 2, "melee": 1, "swarm": 1}},
	{"id": "tireurs", "from": 1.0, "w": 2.0, "roles": {"ranged": 2, "melee": 2}},
	{"id": "mixte", "from": 0.5, "w": 3.0, "roles": {"melee": 1, "charger": 1, "ranged": 1, "swarm": 1}},
	{"id": "rempart", "from": 2.0, "w": 2.0, "roles": {"tank": 1, "ranged": 1, "melee": 2}},
	{"id": "soutien", "from": 3.5, "w": 2.0, "roles": {"support": 1, "tank": 1, "melee": 2}},
]
## Événements : « dur » (encerclement, élite escortée) et « léger » (ruée d'essaim, tenaille), en alternance.
const EVENTS := {"hard": ["encircle", "escort"], "light": ["swarm_rush", "pincer"]}
const SAME_SPECIES_MAX := 3
## Budget × 0,7 : un groupe mélangé (tireurs derrière la mêlée, chargeurs, soigneurs) qui arrive de tous les côtés est
## plus dangereux qu'un pack d'une seule espèce de mêmes PV ; mesuré au pilote (compte neuf, R_P15.md) : ×1 = dégâts
## subis 194-231 % des PV max par minute contre 131 % avant P15, ×0,85 = 134-209 %.
const PACE := 0.7
const SECTORS := 8
const HEAT_HALF_LIFE := 12.0  # s
const MIN_GAP_DEG := 60.0
const RING := [24.0, 31.0]  # m : hors de la vue (caméra par défaut : ≈ 20 m vers le haut de l'écran)
const ENCIRCLE_RING := [19.0, 21.0]  # encerclement : plus près, annoncé par des cercles au sol
const WARN_TIME := 1.1  # s entre les cercles d'alerte et l'arrivée
const WARN_COLOR := Color(1.0, 0.55, 0.1)  # orange : une arrivée, pas une attaque (rouge)
const BACK_WEIGHT := 0.5  # dos du héros (sens de sa marche) : une fois sur deux, et signalé
## Devant le héros (sens de sa marche) : 4 fois sur 10 seulement. Mesuré : avec des arrivées aussi fréquentes devant
## que sur les côtés, les groupes barraient la route du donjon (boss atteint 13-33 % au pilote, contre 60 % avant).
const FRONT_WEIGHT := 0.4
const GOLDEN := 2.39996  # rad : angle d'or entre deux groupes successifs
const JITTER := 0.35  # rad
const SUPPORT_HEAL := 0.06  # PV max rendus aux voisins par impulsion du soigneur
const SUPPORT_EVERY := 6.0
const SUPPORT_RADIUS := 9.0
const NAV_SNAP := 4.0  # m : un point hors du maillage (arbre, rocher, rebord) glisse sur le maillage le plus proche
const PATH_SLACK := 1.7  # chemin jusqu'au héros au plus 1,7 × la ligne droite (+ 8 m) : sinon, derrière un mur
const POWER_SAMPLE := 2.0  # s entre deux mesures de l'équipement du héros

var d: RunDirector
var squads: Array = SQUADS
var events: Dictionary = EVENTS
var pace := PACE  # budget × pace (le Survivant peut l'augmenter avec le temps)
## Horde du Survivant (lot SVX-1) ; les valeurs par défaut sont celles de la Survie (rien n'y change) : plafond de vivants
## par rôle × role_cap_mult ; anneau d'arrivée des escouades (m) ; mark_time > 0 : chaque monstre d'une escouade est annoncé
## par une croix au sol (SpawnMark) mark_time s avant d'apparaître, à l'écran, au lieu d'arriver hors de la vue.
var role_cap_mult := 1.0
var ring: Array = RING
var mark_time := 0.0
static var ablate: Array = []  # mesures de réglage (--spawn-ablate=) : traits de rôle coupés
var power_on := false  # PV et dégâts selon l'équipement (Survie ; le Survivant décide pour lui)
var power := Vector2.ONE  # coefficients lissés [PV, dégâts]
var gear_idx := 0.0

var _by_role := {}  # rôle -> [id]
var _roam := 2.0
var _wave := 60.0
var _wave_hard := false
var _last_event := ""
var _elite_t := 22.0
var _heat := PackedFloat32Array()
var _last_angle := randf() * TAU
var _power_t := 0.0
var _pending := 0  # groupes annoncés pas encore arrivés
# mesures (ligne « [spawn] », journal de run)
var stats := {}
var _win := {"t0": 0.0, "v": Vector2.ZERO, "n": 0, "sectors": {}, "species": {}}
var _group := {"t": -1.0, "pos": Vector3.INF}
var _print_t := 30.0
var _verbose := false


func _init(director: RunDirector) -> void:
	d = director
	_heat.resize(SECTORS)
	for a in OS.get_cmdline_user_args():
		if a == "--spawn=legacy":
			legacy = true
		elif a == "--spawn=new":
			legacy = false
		elif a in ["--auto-quit", "--trace"]:
			_verbose = true
		elif a.begins_with("--spawn-pace="):
			pace = float(a.trim_prefix("--spawn-pace="))  # mesures de réglage
		elif a.begins_with("--spawn-ablate="):
			ablate = Array(a.trim_prefix("--spawn-ablate=").split(","))  # mesures : ranged, charge, speed, heal sans effet
	power_on = Run.survival and not Survivor.active
	stats = {"spawned": 0, "groups": 0, "roles": {}, "species": {}, "windows": 0, "spread_sum": 0.0, "sectors_sum": 0.0,
		"angles": Vector2.ZERO, "events": {}, "heals": 0, "rejected": 0, "win_species": 0.0, "big_groups": 0, "same_sum": 0.0, "why": {}}
	var roles := roles_of_zone(d.zone)
	for id in roles:
		var r: String = roles[id]
		if not _by_role.has(r):
			_by_role[r] = []
		_by_role[r].append(id)
	if power_on:
		gear_idx = MonsterScaling.gear_index()
		power = MonsterScaling.target(gear_idx, MonsterScaling.epoch_band(Run.epoch))


## Rôle du monstre [param id] (données du bestiaire).
static func role_of(id: int) -> String:
	if ID_ROLES.has(id):
		return String(ID_ROLES[id])
	return String(MODEL_ROLES.get(String(GameData.monster(id).get("model", "")), "melee"))


## Rôles des monstres ordinaires de la zone [param zone] : id -> rôle.
static func roles_of_zone(zone: Dictionary) -> Dictionary:
	var out := {}
	for x in zone.get("monsters", []):
		out[int(x)] = role_of(int(x))
	return out


## Niveau des monstres : décalage du héros (MonsterScaling) ; -1 avec l'ancien spawn.
func level_offset() -> float:
	return -1.0 if legacy else MonsterScaling.level_offset(d.time, RunDirector.RUN_TIME)


# --- interface pour les autres modes (Survivant : SurvivorDirector.update_spawns d'après spawn_plan) -------------
## À chaque image où le mode gère lui-même son rythme : soigneurs, puissance lissée, secteurs, mesures.
func tick(delta: float) -> void:
	_tick_common(delta)


## Une meute : escouade mélangée tirée au hasard (SQUADS) de [param budget] points (1 = un monstre ordinaire) au niveau
## [param level], arrivant hors écran du côté le moins servi. Renvoie l'angle utilisé (INF : rien posé).
func pack(budget: float, level: int) -> float:
	return spawn_squad(_pick_squad(), budget, level, [], ring)


## Une vague : événement dur (encerclement annoncé, élite escortée) ou léger (ruée d'essaim, tenaille), dimensionné
## par [param minutes] (temps de la carte) ; [param rage] : version de la rage.
func wave(hard: bool, minutes: float, rage := false) -> void:
	_event(_pick_event(hard), minutes, rage)


# --- boucle -------------------------------------------------------------------------------
## Flux continu, vagues, élites de la rage. Faux : ancien spawn (le directeur fait comme avant).
func update(delta: float, alive: int, cap: int) -> bool:
	_tick_common(delta)
	if legacy:
		return false
	var rage := d.state == "rage"
	var minutes := d.time / 60.0
	_roam -= delta
	if _roam <= 0.0 and alive < cap:
		_roam = randf_range(1.8, 2.6) if rage else maxf(3.5, 6.0 - minutes * 0.3)
		var budget := (randf_range(8.0, 12.0) if rage else minf(4.0 + floorf(minutes), 9.0) + randf_range(0.0, 2.0)) * pace
		var lvl := d._monster_level(0)
		if budget >= 7.0:
			# deux escouades de deux côtés plutôt qu'un gros pack
			var a := spawn_squad(_pick_squad(), budget * 0.55, lvl)
			spawn_squad(_pick_squad(), budget * 0.45, lvl, [a] if a != INF else [])
		else:
			spawn_squad(_pick_squad(), budget, lvl)
	_wave -= delta
	if _wave <= 0.0:
		_wave = 30.0 if rage else 45.0
		_wave_hard = not _wave_hard
		_event(_pick_event(_wave_hard), minutes, rage)
	if rage and not d._elites.is_empty():
		_elite_t -= delta
		if _elite_t <= 0.0:
			_elite_t = 22.0 * (0.5 if Challenge.has("elites_double") else 1.0)
			var a := _pick_angle([])
			var c := _point(a, RING[0], RING[1] + 4.0)
			if c != Vector3.INF:
				for i in clampi(d._room(), 1, 3):
					d._spawn_monster(d._elites.pick_random(), d._around(c, 5.0), d._monster_level(1))
				ArrivalMarker.mark(d, c, Color(1.0, 0.3, 0.2))
				d.message.emit("Des élites enragées arrivent !", 2.0)
	return true


## Commun aux deux spawns : soigneurs, puissance lissée, refroidissement des secteurs, mesures.
func _tick_common(delta: float) -> void:
	var decay := pow(0.5, delta / HEAT_HALF_LIFE)
	for i in SECTORS:
		_heat[i] *= decay
	if power_on and not legacy:
		_power_t -= delta
		if _power_t <= 0.0:
			_power_t = POWER_SAMPLE
			gear_idx = MonsterScaling.gear_index()
			power = MonsterScaling.smooth(power, MonsterScaling.target(gear_idx, MonsterScaling.epoch_band(Run.epoch)), POWER_SAMPLE)
	_update_supports(delta)
	if _verbose and d.time >= _print_t:
		_print_t = d.time + 30.0
		print(stats_line())


# --- escouades ----------------------------------------------------------------------------
func _pick_squad() -> Dictionary:
	var minutes := d.time / 60.0
	var pool := squads.filter(func(s): return minutes >= float(s.from) and _squad_possible(s))
	if pool.is_empty():
		return {"id": "meute", "roles": {"melee": 1, "swarm": 1}}
	var total := 0.0
	for s in pool:
		total += float(s.w)
	var r := randf() * total
	for s in pool:
		r -= float(s.w)
		if r <= 0.0:
			return s
	return pool[-1]


## L'escouade a au moins un rôle présent dans la zone.
func _squad_possible(s: Dictionary) -> bool:
	for r in s.roles:
		if _by_role.has(r):
			return true
	return false


## Composition d'une escouade [param squad] pour [param budget] : liste de rôles (un par monstre), plafonds par rôle
## (vivants + déjà prévus) et rôles absents de la zone remplacés (mêlée, puis essaim, puis n'importe lequel).
func compose(squad: Dictionary, budget: float) -> Array:
	var base := 0.0
	for r in squad.roles:
		base += float(squad.roles[r]) * float(ROLES[r].cost)
	var scale_k := budget / maxf(base, 0.1)
	var out: Array = []
	var alive := role_counts()
	for r in squad.roles:
		var n := maxi(1, roundi(float(squad.roles[r]) * scale_k)) if r == squad.roles.keys()[0] else roundi(float(squad.roles[r]) * scale_k)
		for i in n:
			var role := _available(r, alive)
			if role == "":
				continue
			alive[role] = int(alive.get(role, 0)) + 1
			out.append(role)
	return out


## Rôle [param r] s'il est dans la zone et sous son plafond, sinon un remplaçant ("" : aucun).
func _available(r: String, alive: Dictionary) -> String:
	for cand in [r, "melee", "swarm", "charger", "ranged"]:
		if _by_role.has(cand) and int(alive.get(cand, 0)) < role_cap(cand):
			return cand
	return ""


## Plafond de monstres vivants du rôle [param r] (ROLES.max × role_cap_mult).
func role_cap(r: String) -> int:
	return roundi(float(ROLES[r].max) * role_cap_mult)


## Monstres vivants par rôle.
func role_counts() -> Dictionary:
	var out := {}
	for node in d.get_tree().get_nodes_in_group("monsters"):
		var m := node as Monster
		if m == null or m.is_dead or not m.has_meta("role"):
			continue
		var r := String(m.get_meta("role"))
		out[r] = int(out.get(r, 0)) + 1
	return out


## Espèces d'un groupe : pour chaque rôle, l'espèce du bestiaire la moins prise dans le groupe (au hasard entre
## égales), jamais plus de SAME_SPECIES_MAX fois la même quand le rôle en a d'autres.
func species_for(roles: Array) -> Array:
	var used := {}
	var out: Array = []
	for r in roles:
		var all: Array = _by_role.get(r, [])
		if all.is_empty():
			continue
		var least := 999
		for id in all:
			least = mini(least, int(used.get(id, 0)))
		var pool: Array = all.filter(func(id): return int(used.get(id, 0)) == least)
		if least >= SAME_SPECIES_MAX and r != "swarm":
			continue  # toutes les espèces du rôle sont au plafond : le groupe n'en prend pas plus
		var id: int = pool.pick_random()
		used[id] = int(used.get(id, 0)) + 1
		out.append(id)
	return out


## Fait apparaître une escouade ; renvoie l'angle utilisé (INF : aucun point valide). [param avoid] : angles déjà pris.
func spawn_squad(squad: Dictionary, budget: float, level: int, avoid: Array = [], p_ring: Array = RING) -> float:
	var roles := compose(squad, budget)
	if roles.is_empty():
		return INF
	var a := _pick_angle(avoid)
	var c := _point(a, float(p_ring[0]), float(p_ring[1]))
	if c == Vector3.INF:
		return INF
	_spawn_group(roles, c, level)
	if _is_back(a):
		ArrivalMarker.mark(d, c, Color(1.0, 0.85, 0.35))  # arrivée dans le dos : signalée
	return a


## Pose les monstres [param roles] autour de [param c] : tireurs et soigneurs un peu en retrait, essaim serré. Avec
## mark_time (Survivant) et [param marked] : une croix au sol à chaque place, les monstres y surgissent mark_time s après.
func _spawn_group(roles: Array, c: Vector3, level: int, marked := true) -> void:
	var ids := species_for(roles)
	var out := (c - d.player.global_position)
	out.y = 0.0
	out = out.normalized()
	if mark_time > 0.0 and marked:
		var spots: Array = []
		for i in mini(ids.size(), d._room()):
			var at := c + out * (4.0 if role_of(ids[i]) in ["ranged", "support"] else 0.0)
			spots.append(d._around(at, 2.5 + 0.35 * ids.size()))
			SpawnMark.mark(d, spots[-1], mark_time)
		_later(func():
			for i in mini(spots.size(), d._room()):
				d._spawn_monster(ids[i], spots[i], level), mark_time)
		return
	for i in mini(ids.size(), d._room()):
		var role := role_of(ids[i])
		var at := c + out * (4.0 if role in ["ranged", "support"] else 0.0)
		d._spawn_monster(ids[i], d._around(at, 2.5 + 0.35 * ids.size()), level)


## Monstre d'un rôle tiré au hasard (pondéré, plafonds respectés) : remplace RunDirector._pick_monster hors spawn
## (pression des sanctuaires, extraction, défis, renforts du boss).
func pick_any(_level: int) -> int:
	var weights := {"melee": 3.0, "swarm": 1.2, "charger": 1.5, "ranged": 1.5, "tank": 1.0, "support": 0.4}
	var alive := role_counts()
	var total := 0.0
	var pool := {}
	for r in weights:
		if _by_role.has(r) and int(alive.get(r, 0)) < role_cap(r):
			pool[r] = weights[r]
			total += float(weights[r])
	if pool.is_empty():
		return int(d._roster.pick_random()) if not d._roster.is_empty() else 0
	var x := randf() * total
	for r in pool:
		x -= float(pool[r])
		if x <= 0.0:
			return int((_by_role[r] as Array).pick_random())
	return int((_by_role[pool.keys()[0]] as Array).pick_random())


# --- événements ---------------------------------------------------------------------------
func _pick_event(hard: bool) -> String:
	var pool: Array = (events.hard if hard else events.light).duplicate()
	if d._elites.is_empty():
		pool.erase("escort")
	if pool.size() > 1:
		pool.erase(_last_event)
	_last_event = String(pool.pick_random()) if not pool.is_empty() else "pincer"
	return _last_event


func _event(kind: String, minutes: float, rage: bool) -> void:
	stats.events[kind] = int(stats.events.get(kind, 0)) + 1
	var lvl := d._monster_level(1)
	match kind:
		"encircle":
			d.message.emit("Vague : encerclement !", 2.0)
			var n := 8 if rage else 6
			var budget := (10.0 + 2.0 * minutes + (8.0 if rage else 0.0)) * pace
			var rot := randf() * TAU
			var mix := ["melee", "charger", "swarm", "ranged", "melee", "tank", "swarm", "support"]
			mix.shuffle()
			var elite_at := randi() % n
			for i in n:
				var a := rot + TAU * i / n + randf_range(-0.12, 0.12)
				var c := _point(a, float(ENCIRCLE_RING[0]), float(ENCIRCLE_RING[1]), 4)
				if c == Vector3.INF:
					continue
				var part := {"id": "cercle", "roles": {String(mix[i % mix.size()]): 1, "swarm": 1}}
				var roles := compose(part, budget / n)
				var elite := i == elite_at and not d._elites.is_empty()
				# cercle d'arrivée qui se remplit (sans dégâts) jusqu'à l'apparition du groupe
				Telegraph.spawn(d, c, 0.0, {"shape": "circle", "radius": 2.6, "delay": WARN_TIME, "damage": 0.0, "small": true, "color": WARN_COLOR})
				_later(func():
					_spawn_group(roles, c, lvl, false)  # (déjà annoncé par le cercle)
					if elite and d._room() > 0:
						d._spawn_monster(d._elites.pick_random(), d._around(c, 2.0), lvl))
			if not d._elites.is_empty():
				ArrivalMarker.mark(d, d.player.global_position + Vector3(cos(rot + TAU * elite_at / n), 0, sin(rot + TAU * elite_at / n)) * 20.0, Color(1.0, 0.3, 0.2))
		"escort":
			d.message.emit("Une élite et son escorte arrivent !", 2.2)
			var a := _pick_angle([])
			var c := _point(a, float(ring[0]), float(ring[1]))
			if c == Vector3.INF:
				return
			d._spawn_monster(d._elites.pick_random(), c, lvl)
			var guard := {"id": "escorte", "roles": {"tank": 1, "support": 1 if minutes >= 3.0 else 0, "melee": 2, "ranged": 1}}
			_spawn_group(compose(guard, (5.0 + minutes * 0.6) * pace), c, lvl)
			ArrivalMarker.mark(d, c, Color(1.0, 0.3, 0.2))
		"swarm_rush":
			d.message.emit("Ruée d'essaim !", 1.6)
			var taken: Array = []
			for k in 3:
				var a := spawn_squad({"id": "ruee", "roles": {"swarm": 4, "melee": 2}}, (6.0 + minutes) * 0.75 * pace, maxi(1, lvl - 2), taken, ring)
				if a != INF:
					taken.append(a)
		_:  # pincer
			d.message.emit("Pris en tenaille !", 1.6)
			var a := _pick_angle([])
			var budget := (6.0 + minutes) * 0.8 * pace
			for k in 2:
				var ang := a + PI * k + randf_range(-0.4, 0.4)
				var c := _point(ang, float(ring[0]) - 2.0, float(ring[1]))
				if c == Vector3.INF:
					continue
				_spawn_group(compose(_pick_squad(), budget), c, lvl)
				if _is_back(ang):
					ArrivalMarker.mark(d, c, Color(1.0, 0.85, 0.35))


## Arrivée annoncée : [param f] après [param delay] s (WARN_TIME par défaut), si la carte est toujours en cours.
func _later(f: Callable, delay := WARN_TIME) -> void:
	_pending += 1
	d.get_tree().create_timer(delay, false).timeout.connect(func():
		_pending -= 1
		if is_instance_valid(d) and d.state in ["explore", "rage"] and d.player and not d.player.is_dead:
			f.call())


# --- direction et points ------------------------------------------------------------------
## Direction de marche du héros (sinon, celle où il regarde).
func _heading() -> Vector2:
	var v := Vector2(d.player.velocity.x, d.player.velocity.z)
	if v.length() > 1.0:
		return v.normalized()
	var f := d.player.forward()
	return Vector2(f.x, f.z).normalized() if Vector2(f.x, f.z).length() > 0.01 else Vector2.RIGHT


## Angle [param a] (monde, autour du héros) dans le dos du héros (±45°).
func _is_back(a: float) -> bool:
	var h := _heading()
	return absf(angle_difference(a, atan2(h.y, h.x) + PI)) < deg_to_rad(45.0)


## Angle d'arrivée : on tourne de l'angle d'or (137,5°, ± JITTER) depuis le groupe précédent, ce qui répartit les
## arrivées tout autour du héros ; parmi quelques candidats, le moins « chaud » (secteur servi récemment), loin des
## angles [param avoid], et le dos du héros (sens de marche) seulement une fois sur deux (BACK_WEIGHT).
func _pick_angle(avoid: Array) -> float:
	var h := _heading()
	var hd := atan2(h.y, h.x)
	var best := 0.0
	var best_score := INF
	var base := _last_angle + GOLDEN + randf_range(-JITTER, JITTER)
	for k in 5:
		var a := fposmod(base + GOLDEN * k, TAU)
		var score := _heat[_sector(a)] + 0.5 * k
		var diff := absf(angle_difference(a, hd))
		if diff > PI * 0.75 and randf() > BACK_WEIGHT:
			score += 2.0
		elif diff < PI * 0.25 and randf() > FRONT_WEIGHT:
			score += 2.0
		for b in avoid:
			if absf(angle_difference(a, float(b))) < deg_to_rad(MIN_GAP_DEG):
				score += 10.0
		if score < best_score:
			best_score = score
			best = a
	_last_angle = best
	_heat[_sector(best)] += 1.0
	return best


func _sector(a: float) -> int:
	return posmod(floori(fposmod(a, TAU) / TAU * SECTORS), SECTORS)


## Point au sol à l'angle [param a] et à une distance de [param min_d] à [param max_d] du héros ; si le point est
## mauvais (bord, pente, décor, mur), d'autres angles proches puis le secteur opposé. INF : aucun.
func _point(a: float, min_d: float, max_d: float, tries := 8) -> Vector3:
	var hero := d.player.global_position
	for t in tries * 2:
		# 2e tour : sans le test du chemin (héros hors du maillage, sur un rebord) plutôt qu'aucun monstre
		var k := t % tries
		var ang := a + (0.0 if k == 0 else randf_range(-0.5, 0.5) * (1.0 + k * 0.25)) + (PI if tries >= 6 and k >= tries - 2 else 0.0)
		var p := hero + Vector3(cos(ang), 0, sin(ang)) * randf_range(min_d, max_d)
		var g := _valid(p, hero, t < tries)
		if g != Vector3.INF:
			return g
		stats.rejected = int(stats.rejected) + 1
	# dernier recours (ne jamais affamer la carte) : l'ancien tirage, sol seulement
	stats.fallback = int(stats.get("fallback", 0)) + 1
	return d._ring_point(min_d, max_d)


## Point d'apparition valide près de [param p] : dans la carte, sol praticable, sur le maillage de navigation (pas dans
## un arbre ou un rocher), relié au héros sans grand détour (pas derrière un mur ou une falaise) si [param strict].
func _valid(p: Vector3, hero: Vector3, strict := true) -> Vector3:
	var map = d.map
	var g: Vector3 = map.ground_at(p.x, p.z)
	if g == Vector3.INF:
		return _reject("sol")
	if "bounds" in map and not (map.bounds as Rect2).grow(-6.0).has_point(Vector2(g.x, g.z)):
		return _reject("bord")
	var nav: RID = d.get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav) == 0:
		return g  # maillage pas encore prêt (premières secondes) : le sol suffit
	var close := NavigationServer3D.map_get_closest_point(nav, g)  # point praticable le plus proche (hors arbres, rochers)
	if close.is_zero_approx():
		return g  # maillage en cours de calcul (asynchrone : long quand la machine est chargée) : le sol suffit
	if Vector2(close.x - g.x, close.z - g.z).length() > NAV_SNAP or absf(close.y - g.y) > 2.0:
		return _reject("décor")
	g = close
	if not strict:
		return g
	var hero_nav := NavigationServer3D.map_get_closest_point(nav, hero)  # le héros peut être sur un rebord hors du maillage
	var path := NavigationServer3D.map_get_path(nav, close, hero_nav, true)
	if path.size() < 2 or Vector2(path[-1].x - hero_nav.x, path[-1].z - hero_nav.z).length() > 4.0:
		return _reject("chemin")
	var length := 0.0
	for i in path.size() - 1:
		length += path[i].distance_to(path[i + 1])
	if length > Vector2(g.x - hero.x, g.z - hero.z).length() * PATH_SLACK + 8.0:
		return _reject("mur")
	return g


func _reject(why: String) -> Vector3:
	stats.why[why] = int(stats.why.get(why, 0)) + 1
	return Vector3.INF


# --- monstres -----------------------------------------------------------------------------
## Appelé par RunDirector._spawn_monster avant l'entrée en scène (ni boss, ni géant) : rôle, puissance, mesures.
func prepare(m: Monster, pos: Vector3) -> void:
	if d.state == "training":
		return
	if not legacy:
		if not m.is_elite:
			apply_role(m, role_of(int(m.data.get("id", 0))))
		if power_on:
			var greed_k := RunDirector.GREED_MONSTERS if d.greed else 1.0
			var k := MonsterScaling.capped(power, Menace.hp_mult() * greed_k, greed_k)
			m.max_hp *= k.x
			m.hp = m.max_hp
			m.atk *= k.y
			m.set_meta("power", k)
	if d.state in ["explore", "rage"]:
		_record(m, pos)


## Rôle [param role] (ROLES) appliqué au monstre [param m] juste configuré.
static func apply_role(m: Monster, role: String) -> void:
	var r: Dictionary = ROLES.get(role, ROLES.melee)
	m.max_hp *= float(r.hp)
	m.hp = m.max_hp
	m.atk *= float(r.atk)
	if not "speed" in ablate:
		m.move_speed *= float(r.speed)
	m.xp_reward = maxi(1, roundi(m.xp_reward * float(r.cost)))
	if not is_equal_approx(float(r.scale), 1.0):
		m.data = m.data.duplicate()
		m.data["scale"] = float(m.data.get("scale", 1.0)) * float(r.scale)
	m.kind_override = String(r.get("kind", ""))
	if m.kind_override in ablate:
		m.kind_override = ""
	m.set_meta("role", role)
	if role == "support":
		var glow := OmniLight3D.new()  # le soigneur se repère : une lueur verte
		glow.light_color = Color(0.35, 1.0, 0.5)
		glow.light_energy = 1.2
		glow.omni_range = 3.5
		glow.shadow_enabled = false
		glow.position.y = 1.2
		m.add_child(glow)


## Soigneurs : toutes les SUPPORT_EVERY s, rendent SUPPORT_HEAL de leurs PV max aux monstres blessés proches.
func _update_supports(delta: float) -> void:
	if "heal" in ablate:
		return
	for node in d.get_tree().get_nodes_in_group("monsters"):
		var m := node as Monster
		if m == null or m.is_dead or String(m.get_meta("role", "")) != "support":
			continue
		var t := float(m.get_meta("heal_t", randf_range(1.0, 3.0))) - delta
		if t > 0.0:
			m.set_meta("heal_t", t)
			continue
		m.set_meta("heal_t", SUPPORT_EVERY)
		var healed := 0
		for other in d.get_tree().get_nodes_in_group("monsters"):
			var o := other as Monster
			if o == null or o == m or o.is_dead or o.is_boss or o.team != m.team or o.hp >= o.max_hp:
				continue
			if o.global_position.distance_to(m.global_position) <= SUPPORT_RADIUS:
				o.hp = minf(o.max_hp, o.hp + o.max_hp * SUPPORT_HEAL)
				healed += 1
		if healed > 0:
			stats.heals = int(stats.heals) + healed
			Vfx.ring(d, m.global_position, SUPPORT_RADIUS * 0.6, Color(0.4, 1.0, 0.55, 0.8))


# --- mesures ------------------------------------------------------------------------------
## Relevé d'un monstre qui apparaît en [param pos] : rôle, espèce, groupe (même instant, à moins de 9 m), angle
## autour du héros par fenêtre de 20 s (dispersion : longueur du vecteur moyen, 0 = de tous les côtés, 1 = d'un seul).
func _record(m: Monster, pos: Vector3) -> void:
	if m.is_boss:
		return
	stats.spawned = int(stats.spawned) + 1
	var role := String(m.get_meta("role", "elite" if m.is_elite else role_of(int(m.data.get("id", 0)))))
	stats.roles[role] = int(stats.roles.get(role, 0)) + 1
	var id := -1 if m.is_elite else int(m.data.get("id", 0))
	if id >= 0:
		stats.species[id] = int(stats.species.get(id, 0)) + 1
	if not (is_equal_approx(float(_group.t), d.time) and Vector2(pos.x - _group.pos.x, pos.z - _group.pos.z).length() < 9.0):
		_close_group()
		stats.groups = int(stats.groups) + 1
		_group = {"t": d.time, "pos": pos, "ids": {}}
	_group.ids[id] = int(_group.ids.get(id, 0)) + 1
	_win.species[id] = true
	var hero := d.player.global_position
	var v := Vector2(pos.x - hero.x, pos.z - hero.z)
	if v.length() < 0.5:
		return
	v = v.normalized()
	if d.time - float(_win.t0) >= 20.0:
		_close_window()
		_win = {"t0": d.time, "v": Vector2.ZERO, "n": 0, "sectors": {}, "species": {}}
	_win.v += v
	_win.n = int(_win.n) + 1
	_win.sectors[posmod(floori(fposmod(v.angle(), TAU) / TAU * SECTORS), SECTORS)] = true
	stats.angles += v


func _close_window() -> void:
	if int(_win.n) < 5:
		return
	stats.windows = int(stats.windows) + 1
	stats.spread_sum = float(stats.spread_sum) + (_win.v as Vector2).length() / float(_win.n)
	stats.sectors_sum = float(stats.sectors_sum) + float((_win.sectors as Dictionary).size())
	var sp: Dictionary = _win.species
	stats.win_species = float(stats.win_species) + float(sp.size() - (1 if sp.has(-1) else 0))


## Groupe de 3 monstres ou plus : part de son espèce la plus nombreuse (1 = tous identiques).
func _close_group() -> void:
	var ids: Dictionary = _group.get("ids", {})
	var n := 0
	var top := 0
	for k in ids:
		n += int(ids[k])
		top = maxi(top, int(ids[k]))
	if n >= 3:
		stats.big_groups = int(stats.big_groups) + 1
		stats.same_sum = float(stats.same_sum) + float(top) / float(n)


## Résumé des mesures : espèces vues, monstres par point, dispersion par fenêtre de 20 s (0 = tous les côtés),
## secteurs couverts par fenêtre (sur 8), écart-type circulaire de tous les angles (degrés), puissance.
func summary() -> Dictionary:
	var w := maxi(int(stats.windows), 1)
	var n := maxi(int(stats.spawned), 1)
	var r := (stats.angles as Vector2).length() / float(n)
	var top := 0
	for id in stats.species:
		top = maxi(top, int(stats.species[id]))
	var normal := 0
	for id in stats.species:
		normal += int(stats.species[id])
	return {"species": (stats.species as Dictionary).size(), "top_species": snappedf(float(top) / maxf(float(normal), 1.0), 0.01),
		"per_point": snappedf(float(stats.spawned) / maxf(float(stats.groups), 1.0), 0.1),
		"spread": snappedf(float(stats.spread_sum) / w, 0.01), "sectors": snappedf(float(stats.sectors_sum) / w, 0.1),
		"circ_std": roundi(rad_to_deg(sqrt(-2.0 * log(maxf(r, 0.0001))))), "power_hp": snappedf(power.x, 0.01),
		"win_species": snappedf(float(stats.win_species) / w, 0.1),
		"same": snappedf(float(stats.same_sum) / maxf(float(stats.big_groups), 1.0), 0.01),
		"power_atk": snappedf(power.y, 0.01), "gear_index": snappedf(gear_idx, 0.01), "spawned": int(stats.spawned)}


## Champs du journal de run (une ligne par carte).
func journal() -> Dictionary:
	var s := summary()
	return {"spawn_species": s.species, "spawn_per_point": s.per_point, "spawn_spread": s.spread, "spawn_sectors": s.sectors,
		"power_hp": s.power_hp, "power_atk": s.power_atk, "gear_index": s.gear_index, "spawn_legacy": legacy}


## Ligne de mesure (pilote automatique : --auto-quit, --trace) : spawn, rôles, et pression (journal de run).
func stats_line() -> String:
	var s := summary()
	var c := RunJournal.counters
	var taken := 0.0
	for k in ["normal", "elite", "boss", "autre"]:
		taken += float(c.get("dmg_taken_" + k, 0.0))
	var ttk_n := float(c.get("ttk_normal_n", 0.0))
	return "[spawn] t=%d %s espèces=%d top=%.2f espèces_fenêtre=%.1f identiques=%.2f par_point=%.1f dispersion=%.2f secteurs=%.1f std=%d pv×%.2f dég×%.2f indice=%.2f monstres=%d rôles=%s événements=%s soins=%d rejetés=%d %s dégâts_subis_min=%.0f pv_max=%d ttk=%.2f niv=%d" % [
		int(d.time), "ancien" if legacy else "nouveau", s.species, s.top_species, s.win_species, s.same, s.per_point, s.spread, s.sectors, s.circ_std,
		s.power_hp, s.power_atk, s.gear_index, s.spawned, stats.roles, stats.events, int(stats.heals), int(stats.rejected), str(stats.why).replace(" ", ""),
		taken / maxf(RunJournal.map_minutes(), 0.01), int(d.player.max_hp),
		float(c.get("ttk_normal_sum", 0.0)) / ttk_n if ttk_n > 0.0 else -1.0, d.player.level]
