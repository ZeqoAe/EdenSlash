class_name ColiseeCoach
extends RefCounted
## Le Colisée, lot CO-D (conception/benchmark/R_CO_D.md ; ARENA.md § 6.9) : CHEF D'ÉQUIPE d'un trio pendant un combat.
## Un chef par camp et par combat, créé par le directeur (ColiseeDirector._start_fights) ; il décide 4 fois par seconde (TICK)
## et donne à chaque héros scripté (ClassRival) un ORDRE (ClassRival.coach_order) que le héros lit à sa façon :
##   target   adversaire à frapper (cible commune du trio, ou celui qui plonge sur son tireur / son soigneur) ;
##   goal     point à rejoindre avant tout (fleur de vie, esquive d'un plongeur, attente du groupe), Vector3.INF : aucun ;
##   safe_c / safe_r   cercle sûr (anneau de feu, avec l'avance du resserrement suivant) ; react : s passées dehors avant d'y
##            rentrer ; slide : longe le bord au lieu d'en sortir (esquives comprises) ;
##   heal_at  part des PV sous laquelle son soigneur soigne un équipier (ClassRival._support_tick).
## Le héros garde tout le reste de son jeu (esquive des zones rouges, combos, sorts, retraite) : le chef ne pilote rien
## image par image. Rien ici ne lit le joueur autrement qu'un autre héros (il compte dans son trio : force, centre).
##
## Niveaux (= difficulté du trio, ClassRival.DIFF ; l'étude : Facile = aucun chef, Normal = cible commune, Difficile = tout
## sauf combos, Hardcore = tout) : voir LEVELS. Niveau 0 (Recrue) : seulement le réflexe de sortir du feu, tard.
## Point d'extension (lots CO-E / CO-F, équipe CO-3) : choose_augment(offers, …) et choose_anvil(offers, …) rendent l'indice
## de l'offre choisie par un héros scripté (note par rôle + synergie du trio + hasard selon la difficulté).
## Relève (lot CO-J) : revive_fn (Callable(allié) -> point de relève ou Vector3.INF) ; tant qu'elle est vide, rien.

const NAMES := ["Recrue", "Vétéran", "Champion", "Légende"]
const TICK := 0.25
const TICK_HIDDEN := 0.5  # combat caché (pas regardé) : une décision toutes les 0,5 s (budget d'image, R_CO_D.md § 5)
## Réglages par niveau de chef :
##   focus : "" (chacun le sien), "simple" (le plus bas en PV, près), "full" (danger ÷ temps pour l'abattre et pour l'atteindre) ;
##   noise : hasard de la note de cible ; switch : s avant de changer de cible commune ;
##   react / slide / anticip / margin : anneau de feu (voir l'en-tête) ; flower_hp : sous cette part de PV, va à une fleur ;
##   peel : protège tireurs et soigneur (le tank et la mêlée frappent le plongeur, le tireur s'écarte) ; cohesion : ne part
##   pas seul devant ; wait : attend un adversaire plus fort au plus WAIT_MAX s ; combo : frappe d'abord un adversaire
##   contrôlé ; edge : un adversaire dans le feu vaut plus ; chase_out : la mêlée le suit dans le feu ; heal_at : soins.
const LEVELS := [
	{"focus": "", "noise": 1.0, "switch": 9.0, "react": 0.9, "slide": false, "anticip": 0.0, "margin": 0.3, "flower_hp": 0.0,
		"peel": false, "cohesion": false, "wait": false, "combo": false, "edge": false, "chase_out": true, "heal_at": 0.5},
	{"focus": "simple", "noise": 0.35, "switch": 2.5, "react": 0.35, "slide": true, "anticip": 1.0, "margin": 0.8,
		"flower_hp": 0.35, "peel": false, "cohesion": false, "wait": false, "combo": false, "edge": false, "chase_out": true,
		"heal_at": 0.5},
	{"focus": "full", "noise": 0.15, "switch": 1.5, "react": 0.1, "slide": true, "anticip": 2.5, "margin": 1.2,
		"flower_hp": 0.5, "peel": true, "cohesion": true, "wait": false, "combo": false, "edge": true, "chase_out": false,
		"heal_at": 0.6},
	{"focus": "full", "noise": 0.0, "switch": 1.0, "react": 0.0, "slide": true, "anticip": 4.0, "margin": 1.5,
		"flower_hp": 0.55, "peel": true, "cohesion": true, "wait": true, "combo": true, "edge": true, "chase_out": false,
		"heal_at": 0.65},
]
## Poids du danger d'un adversaire selon son rôle (l'étude : soigneur > tireur > mêlée isolée ; le tank en dernier).
const ROLE_DANGER := {"soin": 1.35, "tireur": 1.2, "melee": 1.0, "tank": 0.7}
const PEEL_R := 4.5  # un adversaire au corps à corps à moins de PEEL_R m d'un tireur / soigneur le « plonge »
const EVADE_R := 3.2  # le tireur / soigneur plongé s'écarte (entre deux coups : il tire dès que son coup est prêt)
const PEEL_HOLD := 1.5  # s pendant lesquelles le tank / la mêlée garde le plongeur
const ENGAGE_R := 10.0  # au-delà (tous les écarts trio-adversaires), on est encore en approche
const AHEAD := 4.5  # cohésion : plus de AHEAD m devant le centre du trio en approche -> il attend le groupe
const WAIT_MAX := 10.0
const WAIT_RATIO := 0.8
const FLOWER_REACH := 18.0
## Attention partagée d'un héros scripté visé par plusieurs adversaires (ClassRival._attention) : × attention par adversaire de
## plus sur sa lecture des coups. Réglages d'essai du banc (--co-tune=clé:valeur, ColiseeDirector) : tune (clés de LEVELS).
## Mesuré au banc (R_CO_D.md § 4) : 0,5, et une lecture d'au plus read_cap quand on est visé par plusieurs adversaires (sans
## ce plafond, deux trios Légende se lisaient tout et finissaient au temps une fois sur trois).
static var attention := 0.5
static var read_cap := 0.75
static var tune := {}

var level := 1
var cfg: Dictionary = LEVELS[1]
var arena: ColiseeArena
var members: Array = []  ## le trio (morts compris : la liste du directeur)
var foes: Array = []  ## le trio adverse
var side := 0
var t := 0.0
var focus: Combatant = null
var revive_fn: Callable = Callable()  ## (lot CO-J) allié à terre -> point de relève (Vector3.INF : pas de relève)
## Décisions du combat (banc) : changements de cible commune, protections (peel), fleurs, écarts, secondes d'attente.
var stats := {"switches": 0, "peels": 0, "flowers": 0, "evades": 0, "hold_s": 0.0, "wait_s": 0.0}
var _acc := TICK  # première décision tout de suite
var period := TICK  ## intervalle des décisions (le directeur : TICK_HIDDEN hors du combat regardé)
var _focus_since := -INF
var _roles := {}  # id d'instance -> rôle
var _claims := {}  # fleur (id d'instance) -> héros qui y va
var _evade_until := {}  # id d'instance -> fin de l'écart
var _peel_on := {}  # id d'instance -> plongeur qu'il frappe
var _peel_until := {}  # id d'instance -> fin minimale de la protection
var _rng := RandomNumberGenerator.new()


## Chef de niveau [param p_level] (0-3) du camp [param p_side] d'un combat dans [param p_arena].
func _init(p_level := 1, p_arena: ColiseeArena = null, p_members: Array = [], p_foes: Array = [], p_side := 0, seed_value := 0) -> void:
	level = clampi(p_level, 0, LEVELS.size() - 1)
	cfg = (LEVELS[level] as Dictionary).duplicate()
	cfg.merge(tune, true)
	arena = p_arena
	members = p_members
	foes = p_foes
	side = p_side
	_rng.seed = seed_value if seed_value != 0 else randi()
	for c in members + foes:
		if is_instance_valid(c):
			_roles[(c as Object).get_instance_id()] = role_of(c)


# --- rôles ------------------------------------------------------------------------------------------------------------

## Rôle d'une classe dans un trio : tank (Guerriers), soin (Soutiens), tireur (allonge de plus de 6 m), mêlée.
static func role_of_class(cid: String) -> String:
	var cls := GameData.class_data(cid)
	match int(cls.get("family", 0)):
		1:
			return "tank"
		4:
			return "soin"
	return "tireur" if float(cls.get("attack_range", 0.0)) > 6.0 else "melee"


static func role_of(c) -> String:
	if c is ClassRival:
		return role_of_class((c as ClassRival).cid)
	if c is Player:
		return role_of_class((c as Player).class_id)
	return "melee"


func _role(c) -> String:
	return String(_roles.get((c as Object).get_instance_id(), "melee"))


static func _backline(role: String) -> bool:
	return role == "tireur" or role == "soin"


# --- décision ---------------------------------------------------------------------------------------------------------

static func _alive(arr: Array) -> Array:
	return arr.filter(func(c): return is_instance_valid(c) and not (c as Combatant).is_dead)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _invuln(c: Combatant) -> bool:
	return c.has_method("is_invulnerable") and bool(c.call("is_invulnerable"))


## Cercle sûr de l'instant : l'anneau, ou le prochain s'il se resserre dans moins de « anticip » s, moins une marge.
func safe_radius() -> float:
	if arena == null or arena.ring == null:
		return INF
	var r := arena.ring.radius
	var nx := arena.ring.next_info()
	if not nx.is_empty() and float(nx["in"]) <= float(cfg.anticip):
		r = minf(r, float(nx.radius))
	return maxf(1.5, r - float(cfg.margin))


func center() -> Vector3:
	return arena.center if arena != null else Vector3.ZERO


## Une image du combat : décide toutes les TICK s.
func tick(delta: float) -> void:
	t += delta
	_acc += delta
	if _acc < period:
		return
	_acc = 0.0
	decide()


func decide() -> void:
	var mine := _alive(members)
	var them := _alive(foes)
	if mine.is_empty() or them.is_empty():
		return
	var sr := safe_radius()
	var c0 := center()
	if String(cfg.focus) != "":
		_update_focus(mine, them, sr)
	var my_c := _centroid(mine)
	var foe_c := _centroid(them)
	var gap := INF
	for m in mine:
		for e in them:
			gap = minf(gap, _flat((m as Node3D).global_position, (e as Node3D).global_position))
	var approach := gap > ENGAGE_R
	var waiting := bool(cfg.wait) and t < WAIT_MAX and approach and _power(mine) < _power(them) * WAIT_RATIO
	if waiting:
		stats.wait_s = float(stats.wait_s) + period
	for k in _claims.keys():
		var who = _claims[k]
		if not is_instance_valid(who) or (who as Combatant).is_dead:
			_claims.erase(k)
	for m in mine:
		if not (m is ClassRival):
			continue  # le joueur décide seul
		var r := m as ClassRival
		var o := {"target": null, "goal": Vector3.INF, "kind": "", "safe_c": c0, "safe_r": sr, "react": float(cfg.react),
			"slide": bool(cfg.slide), "heal_at": float(cfg.heal_at)}
		var tgt := _target_for(r, mine, them, sr)
		o.target = tgt
		var goal := _goal_for(r, mine, them, sr, my_c, foe_c, approach, waiting)
		if goal.size() == 2:
			o.goal = goal[0]
			o.kind = goal[1]
		r.coach_order = o
		if tgt != null and r._player != tgt and not r.is_passive():
			r._player = tgt  # tout de suite (sans attendre le reciblage de Monster, 0,5 s)


func _centroid(arr: Array) -> Vector3:
	var s := Vector3.ZERO
	for c in arr:
		s += (c as Node3D).global_position
	return s / maxf(1.0, arr.size())


## Force d'un trio : PV × frappe (comme Colisee.resolve_board).
static func _power(arr: Array) -> float:
	var hp_sum := 0.0
	var hit := 0.0
	for c in arr:
		hp_sum += (c as Combatant).hp
		hit += Royale.strike(c)
	return hp_sum * hit


## Cible commune : garde la sienne tant qu'elle reste prenable (inertie, délai « switch »), sinon la meilleure note.
func _update_focus(mine: Array, them: Array, sr: float) -> void:
	var ok := focus != null and is_instance_valid(focus) and not focus.is_dead and not focus.has_status("invisible")
	var best: Combatant = null
	var best_s := -INF
	var cur_s := -INF
	var scores := _scores(mine, them, sr)
	for e in scores:
		var s: float = scores[e]
		if e == focus:
			cur_s = s
		if s > best_s:
			best_s = s
			best = e
	if best == null:
		return
	if not ok or (best != focus and t >= _focus_since + float(cfg.switch) and best_s > cur_s * 1.3):
		if focus != best:
			stats.switches = int(stats.switches) + 1
		focus = best
		_focus_since = t


## Notes des adversaires : « simple » = PV bas et proche ; « full » = danger (rôle × frappe) ÷ (temps pour l'abattre, relatif,
## + temps pour l'atteindre) ; dans le feu (edge) ou contrôlé (combo) : plus vite abattu.
func _scores(mine: Array, them: Array, sr: float) -> Dictionary:
	var out := {}
	var my_c := _centroid(mine)
	var strike := 0.0
	for m in mine:
		strike += Royale.strike(m)
	strike = maxf(strike, 1.0)
	var ttk := {}
	var danger := {}
	var sum_ttk := 0.0
	var sum_d := 0.0
	var n := 0
	for x in them:
		var e := x as Combatant
		if e.has_status("invisible"):
			continue
		var ehp := e.hp / maxf(0.25, e.damage_taken_mult())
		if _invuln(e):
			ehp *= 1.6
		ttk[e] = ehp / strike
		danger[e] = Royale.strike(e)
		sum_ttk += float(ttk[e])
		sum_d += float(danger[e])
		n += 1
	if n == 0:
		return out
	var mean_ttk := maxf(sum_ttk / n, 0.0001)
	var mean_strike := maxf(sum_d / n, 0.0001)
	# danger = rôle × frappe relative amortie de moitié (un soigneur frappe peu mais ses soins comptent)
	sum_d = 0.0
	for e in danger:
		danger[e] = float(ROLE_DANGER.get(_role(e), 1.0)) * lerpf(1.0, float(danger[e]) / mean_strike, 0.5)
		sum_d += float(danger[e])
	var mean_d := maxf(sum_d / n, 0.0001)
	for e in ttk:
		var dist := _flat(my_c, e.global_position)
		var s := 0.0
		if String(cfg.focus) == "simple":
			s = 1.0 / (e.hp / maxf(e.max_hp, 1.0) + dist / 25.0 + 0.2)
		else:
			var tr := float(ttk[e]) / mean_ttk
			if bool(cfg.edge) and _flat(e.global_position, center()) > sr + 0.5:
				tr *= 0.75
			if bool(cfg.combo) and (e.is_disabled() or e.has_status("root") or e.has_status("chill")):
				tr *= 0.45
			s = (float(danger[e]) / mean_d) / (tr + maxf(0.0, dist - 4.0) / 6.5 * 0.35 + 0.35)
		if float(cfg.noise) > 0.0:
			s *= 1.0 + _rng.randf_range(-float(cfg.noise), float(cfg.noise))
		out[e] = s
	return out


## Cible d'un héros : la cible commune, sauf (peel) un plongeur sur un tireur / soigneur à portée du tank ou de la mêlée, et
## sauf (chase_out faux) une cible de mêlée partie dans le feu quand un autre adversaire reste dedans.
func _target_for(r: ClassRival, mine: Array, them: Array, sr: float) -> Combatant:
	var role := _role(r)
	var tgt: Combatant = focus if String(cfg.focus) != "" and is_instance_valid(focus) and not focus.is_dead else null
	if tgt == null:
		return null
	if role == "tank" or role == "melee":
		if bool(cfg.peel):
			var diver: Combatant = null
			var dd := INF
			for m in mine:
				if m == r or not _backline(_role(m)):
					continue
				for e in them:
					if _backline(_role(e)):
						continue
					var d := _flat((e as Node3D).global_position, (m as Node3D).global_position)
					if d < PEEL_R and d < dd:
						dd = d
						diver = e
			var held = _peel_on.get(r.get_instance_id())
			if diver == null and held != null and is_instance_valid(held) and not (held as Combatant).is_dead 					and t < float(_peel_until.get(r.get_instance_id(), -1.0)):
				diver = held  # (il garde le plongeur un moment : pas de va-et-vient à chaque décision)
			if diver != null and diver != tgt:
				var reach := _flat(r.global_position, diver.global_position)
				var far := _flat(r.global_position, tgt.global_position)
				if reach < 14.0 and (role == "tank" or far > 8.0 or reach < far):
					if _peel_on.get(r.get_instance_id()) != diver:
						stats.peels = int(stats.peels) + 1
						_peel_until[r.get_instance_id()] = t + PEEL_HOLD
					_peel_on[r.get_instance_id()] = diver
					return diver
			_peel_on.erase(r.get_instance_id())
		if not bool(cfg.chase_out) and _flat(tgt.global_position, center()) > sr + 1.0:
			var alt: Combatant = null
			var ad := INF
			for e in them:
				var d := _flat((e as Node3D).global_position, r.global_position)
				if _flat((e as Node3D).global_position, center()) <= sr and d < 12.0 and d < ad:
					ad = d
					alt = e
			if alt != null:
				return alt
	return tgt


## Point à rejoindre d'abord ([point, genre]) ou [] : fleur de vie, écart d'un plongeur, attente du groupe, attente d'un
## adversaire plus fort, relève (lot CO-J).
func _goal_for(r: ClassRival, mine: Array, them: Array, sr: float, my_c: Vector3, foe_c: Vector3, approach: bool, waiting: bool) -> Array:
	var role := _role(r)
	var pos := r.global_position
	var id := r.get_instance_id()
	# relève d'un équipier à terre (règle du lot CO-J)
	if revive_fn.is_valid():
		var spot := _revive_spot(r, mine, them)
		if spot != Vector3.INF:
			return [spot, "revive"]
	# fleur de vie : le plus bas en PV, si la voie est libre
	if float(cfg.flower_hp) > 0.0 and r.hp < r.max_hp * float(cfg.flower_hp) and arena != null:
		var best: ColiseeFlower = null
		var bd := INF
		for fl in arena.flowers:
			var f := fl as ColiseeFlower
			if not f.ready_now:
				continue
			var fid := f.get_instance_id()
			if _claims.has(fid) and _claims[fid] != r:
				continue
			var d := _flat(pos, f.global_position)
			if d > FLOWER_REACH or _flat(f.global_position, center()) > sr:
				continue
			var blocked := false
			for e in them:
				var de := _flat((e as Node3D).global_position, f.global_position)
				if de < 4.0 and de < d - 1.0:
					blocked = true
			if not blocked and d < bd:
				bd = d
				best = f
		if best != null:
			if not _claims.has(best.get_instance_id()):
				stats.flowers = int(stats.flowers) + 1
			_claims[best.get_instance_id()] = r
			return [best.global_position, "flower"]
	# tireur / soigneur plongé : s'écarte vers son trio (dans le cercle sûr)
	if bool(cfg.peel) and _backline(role):
		if float(_evade_until.get(id, -1.0)) > t:
			return [_evade_point(r, them, my_c, sr), "evade"]
		for e in them:
			if not _backline(_role(e)) and _flat((e as Node3D).global_position, pos) < EVADE_R:
				_evade_until[id] = t + 0.6
				stats.evades = int(stats.evades) + 1
				return [_evade_point(r, them, my_c, sr), "evade"]
	# approche : personne ne part seul devant (cohésion), on attend un adversaire plus fort (wait)
	if approach:
		var dir := foe_c - my_c
		dir.y = 0.0
		if dir.length() > 0.1:
			dir = dir.normalized()
			if waiting:
				var home := center() + (my_c - center()).normalized() * minf(5.0, sr - 1.0) if _flat(my_c, center()) > 0.5 else my_c
				return [home, "hold"]
			if bool(cfg.cohesion) and (pos - my_c).dot(dir) > AHEAD and mine.size() > 1:
				stats.hold_s = float(stats.hold_s) + period
				return [my_c + dir * 2.0, "hold"]
	return []


func _evade_point(r: ClassRival, them: Array, my_c: Vector3, sr: float) -> Vector3:
	var away := Vector3.ZERO
	for e in them:
		var off := r.global_position - (e as Node3D).global_position
		off.y = 0.0
		var d := off.length()
		if d < 8.0 and d > 0.01:
			away += off / d * (8.0 - d)
	var to_mates := my_c - r.global_position
	to_mates.y = 0.0
	var dir := (away.normalized() + to_mates.normalized() * 0.5).normalized() if away.length() > 0.01 else to_mates.normalized()
	var p := r.global_position + dir * 5.0
	var off_c := p - center()
	off_c.y = 0.0
	if off_c.length() > sr - 0.5:
		p = center() + off_c.normalized() * maxf(0.5, sr - 0.5) + Vector3(0.0, p.y - center().y, 0.0)
	return p


## Relève (lot CO-J) : le plus proche du tombé qui n'a pas d'adversaire à moins de 6 m, ou n'importe qui si le trio est
## plus fort ; un seul à la fois.
func _revive_spot(r: ClassRival, mine: Array, them: Array) -> Vector3:
	var stronger := _power(mine) > _power(them)
	for m in members:
		if not is_instance_valid(m) or not (m as Combatant).is_dead:
			continue
		var spot = revive_fn.call(m)
		if not (spot is Vector3) or spot == Vector3.INF:
			continue
		var best: Combatant = null
		var bd := INF
		for x in mine:
			if not (x is ClassRival):
				continue
			var safe := true
			for e in them:
				if _flat((e as Node3D).global_position, (x as Node3D).global_position) < 6.0:
					safe = false
			var d := _flat((x as Node3D).global_position, spot)
			if (safe or stronger) and d < bd:
				bd = d
				best = x
		if best == r:
			return spot
	return Vector3.INF


# --- choix entre les manches (point d'extension des lots CO-E / CO-F) --------------------------------------------------

## Bruit de la note d'un choix, par difficulté (0 : au hasard parmi les offres ; 3 : aucun).
const CHOICE_NOISE := [-1.0, 0.6, 0.25, 0.0]


## Note d'une offre pour un héros de rôle [param role] dans un trio aux rôles [param trio_roles] : sa note propre (« score »,
## « note » ou « gain », sinon 1 ; une offre déjà notée selon le rôle, comme celles de ColiseeAugments.offer_dicts, ne garde
## que l'interdit du soin et la synergie) × l'accord de ses étiquettes (« tags » : melee, ranged, healer, tank, sorts, equipe…) avec
## le rôle (une offre de soin pour un non-soigneur ne vaut presque rien), + la synergie de trio (étiquette « equipe » ;
## « famille » si les trois familles diffèrent) au niveau Champion et plus.
static func offer_score(o: Dictionary, role: String, trio_roles: Array = [], synergy := true) -> float:
	var base := float(o.get("score", o.get("note", o.get("gain", 1.0))))
	var rated := o.has("score") or o.has("note")  # déjà notée selon le rôle (ColiseeAugments.score) : pas deux fois
	var tags: Array = o.get("tags", [])
	var k := 1.0
	var want := {"tank": ["tank", "melee", "survie"], "melee": ["melee", "coups"], "tireur": ["ranged", "coups", "sorts"],
		"soin": ["healer", "sorts", "equipe", "survie"]}
	for tg in tags:
		var s := String(tg)
		if s == "healer" and role != "soin":
			k *= 0.15
		elif rated:
			pass
		elif s in want.get(role, []):
			k += 0.5
		elif s == "tank" and role == "tireur":
			k *= 0.6
		elif s == "ranged" and (role == "melee" or role == "tank"):
			k *= 0.4
		elif s == "melee" and role == "tireur":
			k *= 0.4
		if synergy and s == "equipe":
			k += 0.15 * float(trio_roles.size())
		if synergy and s == "famille" and trio_roles.size() >= 3:
			k += 0.4
	return base * k if base > 0.0 else base


## Atout choisi par un héros scripté (lot CO-E) : indice dans [param offers] (-1 si vide). [param difficulty] 0 = au hasard,
## 1 = note simple bruitée, 2 = note + synergie de trio un peu bruitée, 3 = note + synergie sans bruit ; [param trio] : classes
## du trio (synergie).
static func choose_augment(offers: Array, cid: String, difficulty := 3, trio: Array = [], rng: RandomNumberGenerator = null) -> int:
	return _choose(offers, role_of_class(cid), difficulty, trio, rng)


## Pièce choisie dans une enclume par un héros scripté (lot CO-F) : même règle ; une offre de RoyaleLoot.offer a son « gain ».
static func choose_anvil(offers: Array, cid: String, difficulty := 3, trio: Array = [], rng: RandomNumberGenerator = null) -> int:
	return _choose(offers, role_of_class(cid), difficulty, trio, rng)


static func _choose(offers: Array, role: String, difficulty: int, trio: Array, rng: RandomNumberGenerator) -> int:
	if offers.is_empty():
		return -1
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var noise := float(CHOICE_NOISE[clampi(difficulty, 0, 3)])
	if noise < 0.0:
		return r.randi_range(0, offers.size() - 1)
	var roles: Array = trio.map(func(c): return role_of_class(String(c)))
	var best := 0
	var best_s := -INF
	for i in offers.size():
		var o = offers[i]
		var s := offer_score(o if o is Dictionary else {}, role, roles, difficulty >= 2)
		if noise > 0.0:
			s *= 1.0 + r.randf_range(-noise, noise)
		if s > best_s:
			best_s = s
			best = i
	return best
