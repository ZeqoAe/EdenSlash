class_name MobaHeroAi
extends RefCounted
## Les Deux Voies, lot MB-E (MOBA.md § 7.8 couches 1, 2 et 4 ; rapport conception/benchmark/R_MB_E.md) : l'IA de poste d'un
## héros scripté (MobaRival : la micro de ClassRival reste la sienne : lecture des zones, esquives, sorts, soins). Une
## décision tous les THINK s (selon la difficulté), posée sur le héros : sa cible (_player), son but (goal), ses zones
## interdites (avoid : portée des tours adverses qui n'ont pas de sbire allié à viser), la plongée permise (dive_ok), le rappel,
## les potions, les achats. Aucune triche : elle lit ce que la carte montre (héros à portée de vue ; le coach d'équipe et la
## vue honnête des 25 m sont le lot MB-G).
##
## Commun à tous les postes : jamais sous une tour adverse qui ne vise pas un de ses sbires (sauf plongée sûre, Difficile :
## cible presque morte, PV ≥ 60 %, tour qui ne le vise pas) ; quitte la portée d'une tour qui le vise ; ne frappe pas un
## héros au milieu de la vague adverse (appel à l'aide des sbires) ; échange quand le rapport de force dépasse 1,1, recule
## sous sa tour sous 0,8 ; potion sous 45 % ; rentre (rappel, ou à pied près de la base) sous 30 % (35 % en Hardcore) sans
## ennemi proche, sinon recule vers sa tour ; rentre acheter dès 4:00 si l'or paie l'objet suivant + 300 et que la voie est
## calme ; à la fontaine : achète le parcours de sa famille (adapté à l'équipe adverse dès Difficile) et repart à 95 % de PV.
## Postes : voie (solo des Brumes, tireur du Soleil) : 4 m derrière le front de sa vague, achève les sbires à portée ;
## soutien : suit son tireur, se place entre lui et la menace, frappe qui le frappe ; jungle : camps de sa moitié dans
## l'ordre des minuteurs (petits d'abord), ceux de l'autre moitié quand ils sont sans garde, embuscade sur une voie quand le
## héros adverse y est sous 60 % de PV de son côté de la carte.
##
## Difficultés (§ 7.8) : décision 0,5 / 0,35 / 0,25 / 0,2 s ; erreurs de position (poursuite sous tour) 30 / 12 / 4 / 0 % des
## occasions ; Facile oublie un retour d'achat sur trois et suit un parcours fixe ; Hardcore vend ses bottes à 20:00.

const THINK := [0.5, 0.35, 0.25, 0.2]
const ERRORS := [0.3, 0.12, 0.04, 0.0]
const LOW_HP := [0.25, 0.3, 0.3, 0.35]  # retour sous cette part des PV
const POTION_AT := 0.45
const TRADE_IN := 1.1
const TRADE_OUT := 0.8
const TOWER_FIGHT := 1.5  # rapport exigé pour se battre près d'une tour adverse
const TRADE_EVEN := 0.9  # à force égale, il échange s'il a au moins autant de PV (harcèlement en voie)
const SIGHT := 16.0  # m : héros adverses pris en compte autour de lui
const TOWER_MARGIN := 1.8
const SHOP_FROM := 240.0  # pas de retour « rien que pour acheter » avant 4:00
const SHOP_SPARE := 300.0
const GANK_HP := 0.6
const GANK_RANGE := 55.0
const GANK_EARLY_HP := 0.35
const GANK_EARLY_RANGE := 28.0
const DIVE_HP := 0.6
const DIVE_TARGET := 0.22

var mode := "lane"  # lane | home | retreat | jungle | gank | follow
var err_until := 0.0
var skip_shop := false
var target_camp := ""
var _camp_hp := 2.0  # (camp en cours : plus bas PV vus, pour sentir un camp qui ne baisse plus)
var _camp_t := 0.0
var _skip: Dictionary = {}  # camp -> instant jusqu'où il est laissé (inaccessible, remis à zéro)
var _bad_unit: Dictionary = {}  # monstre de camp -> instant : on n'arrive pas à l'approcher (un autre d'abord)
var _near_d := INF
var _near_t := 0.0
var _near_u: Object
var cost_us := 0
var cost_n := 0
var _rng := RandomNumberGenerator.new()
var _trace_t := 0.0
static var TRACE := false
static var TRACE_EVERY := 10.0
static var _trace_read := false


func _init(seed_v := 0) -> void:
	_rng.seed = seed_v


## Une décision pour [param r] (état [param hs]) ; [param d] : MobaDirector.
func think(d: MobaDirector, hs: MobaHero, r: MobaRival) -> void:
	var t0 := Time.get_ticks_usec()
	_think(d, hs, r)
	cost_us += Time.get_ticks_usec() - t0
	cost_n += 1
	if not _trace_read:
		_trace_read = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--moba-trace-ai"):
				TRACE = true
				TRACE_EVERY = float(a.get_slice("=", 1)) if "=" in a else 10.0
	if TRACE and Moba.t >= _trace_t:
		_trace_t = Moba.t + TRACE_EVERY
		var foes: Array = d.enemies_near(hs.side, r.global_position, SIGHT, MobaDirector.KIND_HERO)
		var tg: String = "-" if r._player == null else ("héros" if Combatant.is_hero(r._player) else String(r._player.display_name))
		if r._player != null and is_instance_valid(r._player):
			tg += " (%d%% à %.1f m, état %s, prêt %.1f, %s %s)" % [roundi(100.0 * r._player.hp / maxf(r._player.max_hp, 1.0)), r.global_position.distance_to(r._player.global_position), r._state,
				r._attack_ready_at - r._time, str(r.statuses.keys()), "passif" if r.is_passive() else ""]
		print("[moba-ia] t=%d %s%d %s %s pv=%d%% cible=%s but=%s ennemis=%d au plus près %.1f m rapport %.2f" % [int(Moba.t), "BR"[hs.side], hs.role, hs.cid, mode,
			roundi(100.0 * r.hp / r.max_hp), tg, "oui" if r.goal != Vector3.INF else "non", foes.size(), _closest_dist(r.global_position, foes),
			_ratio(d, hs, r, foes) if not foes.is_empty() else 0.0])


func _think(d: MobaDirector, hs: MobaHero, r: MobaRival) -> void:
	var t := Moba.t
	var side := hs.side
	var p := r.global_position
	var diff := clampi(hs.difficulty, 0, 3)
	_set_avoid(d, hs, r)
	r.dive_ok = false
	if diff < 3 and t >= err_until and _rng.randf() < ERRORS[diff] * 0.25:
		err_until = t + 2.0  # (erreur de position : il poursuit sous la tour un moment)
	if t < err_until:
		r.dive_ok = true
	# --- à la fontaine : achats, soins ---------------------------------------------------------------
	if hs.in_shop:
		_shop(d, hs, diff)
		if mode == "home" and r.hp < r.max_hp * 0.95:
			_go(r, d._fountain_spot(side, d.heroes.find(r)), null)
			return
		if mode == "home":
			mode = _role_mode(hs)
	if mode == "home":
		_go(r, d.map.moba.fountains[side], null)
		return
	var foes: Array = d.enemies_near(side, p, SIGHT, MobaDirector.KIND_HERO)
	var hp := r.hp / maxf(r.max_hp, 1.0)
	# --- une tour adverse le vise : il sort de sa portée avant tout (sauf plongée en cours) ---------------
	var shooter := _tower_on_me(d, hs, r)
	if shooter != null and not (r.dive_ok and hp > 0.45):
		_escape_tower(d, hs, r, shooter)
		return
	# --- PV bas : potion, retour ----------------------------------------------------------------------
	if hp < POTION_AT and not hs.in_shop:
		d.ai_potion(hs)
	var close := _closest_dist(p, foes)
	if hp < LOW_HP[diff]:
		if close > 12.0 and not _in_avoid(r, p, 3.0) and Moba.t - hs.last_combat > 1.5:
			if p.distance_to(d.map.moba.fountains[side]) > 40.0:
				if d.start_recall(r):
					return
			mode = "home"
			_go(r, d.map.moba.fountains[side], null)
			return
		_retreat(d, hs, r, foes)
		return
	# --- une vague le prend pour cible alors qu'il est entamé : il recule derrière ses sbires ----------------
	if hp < 0.5:
		var on_me := 0
		for m in d.enemies_near(side, p, 9.0, MobaDirector.KIND_MINION):
			if (m as MobaMinion)._player == r:
				on_me += 1
		if on_me >= 3:
			_retreat(d, hs, r, foes)
			return
	# --- retour d'achat (dès 4:00, voie calme, or suffisant) -------------------------------------------
	if t >= SHOP_FROM and close > 15.0 and not _in_avoid(r, p, 3.0) and Moba.t - hs.last_combat > 3.0 and _wants_shop(d, hs, diff):
		if d.start_recall(r):
			return
	# --- combat entre héros -------------------------------------------------------------------------------
	var tgt := _fight_target(d, hs, r, foes)
	if tgt == null and not foes.is_empty() and _ratio(d, hs, r, foes) < TRADE_OUT and close < 9.0:
		_retreat(d, hs, r, foes)
		return
	if tgt == null and not foes.is_empty() and close < 14.0 and _enemy_tower_near(d, hs, p, 3.0) != null:
		_retreat(d, hs, r, foes)  # (des héros adverses arrivent pendant qu'il est sous leur tour : il en sort)
		return
	if tgt != null:
		mode = _role_mode(hs) if mode in ["retreat", "home"] else mode
		_attack(r, tgt)
		return
	if mode == "retreat":
		mode = _role_mode(hs)
	# --- poste ---------------------------------------------------------------------------------------------
	match hs.role:
		1:
			_jungle(d, hs, r)
		3:
			_support(d, hs, r)
		_:
			_lane(d, hs, r)


static func _role_mode(hs: MobaHero) -> String:
	return "jungle" if hs.role == 1 else ("follow" if hs.role == 3 else "lane")


# --- tours -------------------------------------------------------------------------------------------

## Zones interdites : portée (+ marge) de chaque tour ou Cœur adverse debout, sauf si elle vise un sbire allié et que
## 2 sbires alliés au moins sont sous elle (ils l'occupent) ; toujours interdite si elle le vise lui.
func _set_avoid(d: MobaDirector, hs: MobaHero, r: MobaRival) -> void:
	r.avoid.clear()
	for s in d.structures:
		if s.is_dead or s.side == hs.side:
			continue
		var busy: bool = s.target != null and is_instance_valid(s.target) and s.target is MobaMinion and s.target != r \
			and d.units_near(hs.side, s.global_position, s.range_m, MobaDirector.KIND_MINION).size() >= 2
		if s.target == r or not busy:
			r.avoid.append([s.global_position, float(s.range_m) + TOWER_MARGIN + r.radius])


## Tour (ou Cœur) adverse dont il est la cible, à portée (+ 2 m) ; null sinon.
func _tower_on_me(d: MobaDirector, hs: MobaHero, r: MobaRival) -> MobaStructure:
	for s in d.structures:
		if not s.is_dead and s.side != hs.side and s.target == r and r.global_position.distance_to(s.global_position) < s.range_m + 2.0 + r.radius:
			return s
	return null


## Sortie de portée d'une tour qui le vise : droit vers l'extérieur, du côté de sa base.
func _escape_tower(d: MobaDirector, hs: MobaHero, r: MobaRival, s: MobaStructure) -> void:
	mode = "retreat"
	var out := r.global_position - s.global_position
	out.y = 0.0
	var home: Vector3 = d.map.moba.fountains[hs.side] - s.global_position
	home.y = 0.0
	var dir := (out.normalized() + home.normalized() * 0.7).normalized()
	r.goal = s.global_position + dir * (s.range_m + TOWER_MARGIN + 3.0)
	r._player = d.cores[1 - hs.side]


func _in_avoid(r: MobaRival, pos: Vector3, extra := 0.0) -> bool:
	for z in r.avoid:
		var off: Vector3 = pos - (z[0] as Vector3)
		off.y = 0.0
		if off.length() < float(z[1]) + extra:
			return true
	return false


# --- combat ---------------------------------------------------------------------------------------------

## Force d'un héros : PV restants × attaque (niveau et objets compris).
static func power_of(c: Combatant) -> float:
	return maxf(c.hp, 1.0) * maxf(MobaItems.attack_of(c), 1.0)


## Rapport de force autour de lui : alliés (lui compris) contre [param foes] ; × 1,5 au camp qui a sa tour à côté.
func _ratio(d: MobaDirector, hs: MobaHero, r: MobaRival, foes: Array) -> float:
	var mine := 0.0
	for a in d.units_near(hs.side, r.global_position, SIGHT, MobaDirector.KIND_HERO):
		mine += power_of(a)
	var theirs := 0.0
	for f in foes:
		theirs += power_of(f)
	if theirs <= 0.0:
		return 99.0
	if _near_own_tower(d, hs, r.global_position):
		mine *= 1.5
	if _enemy_tower_near(d, hs, r.global_position, 3.0) != null:
		theirs *= 1.5  # (sous une tour adverse, même occupée : elle peut se retourner contre lui)
	return mine / theirs


## Tour ou Cœur adverse debout dont la portée (+ [param extra] m) couvre [param pos] ; null sinon.
func _enemy_tower_near(d: MobaDirector, hs: MobaHero, pos: Vector3, extra: float) -> MobaStructure:
	for s in d.structures:
		if not s.is_dead and s.side != hs.side and pos.distance_to(s.global_position) < s.range_m + extra:
			return s
	return null


func _near_own_tower(d: MobaDirector, hs: MobaHero, pos: Vector3) -> bool:
	for s in d.structures:
		if not s.is_dead and s.side == hs.side and pos.distance_to(s.global_position) < s.range_m + 2.0:
			return true
	return false


## Héros adverse à frapper : le plus intéressant à portée d'engagement s'il est hors des zones interdites (ou plongée
## sûre), que le rapport de force le permet, et qu'il n'est pas au milieu de sa vague (sauf s'il frappe déjà un allié).
func _fight_target(d: MobaDirector, hs: MobaHero, r: MobaRival, foes: Array) -> Combatant:
	if foes.is_empty():
		return null
	var diff := hs.difficulty
	var reach := r._attack_range() + (5.0 if hs.role != 1 else 8.0)
	var ratio := _ratio(d, hs, r, foes)
	var hp := r.hp / maxf(r.max_hp, 1.0)
	var best: Combatant = null
	var best_s := INF
	for f in foes:
		var c := f as Combatant
		if c.is_dead or c.has_status("invisible"):
			continue
		var dist := r.global_position.distance_to(c.global_position)
		if dist > reach:
			continue
		var low := c.hp / maxf(c.max_hp, 1.0)
		var hitting_us: bool = d._help.has(c) and Moba.t - float(d._help[c].t) < 1.5
		var want := ratio >= TRADE_IN or low < 0.25 or (hitting_us and ratio >= TRADE_OUT) or (ratio >= TRADE_EVEN and hp >= low - 0.02)
		if _enemy_tower_near(d, hs, r.global_position, 3.0) != null or _enemy_tower_near(d, hs, c.global_position, 2.0) != null:
			want = ratio >= TOWER_FIGHT  # (près d'une tour adverse : seulement en nette supériorité)
		if not want:
			continue
		if _in_avoid(r, c.global_position) and not r.dive_ok:
			if not _safe_dive(d, hs, r, c, hp):
				continue
			r.dive_ok = true
		if diff >= 1 and not hitting_us and low > 0.3:
			var wave := d.units_near(1 - hs.side, c.global_position, 6.0, MobaDirector.KIND_MINION).size()
			var ours := d.units_near(hs.side, c.global_position, 6.0, MobaDirector.KIND_MINION).size()
			if wave >= 3 and wave > ours + 1:
				continue  # (au milieu de sa vague : ses sbires viendraient à son secours)
		var s := dist + 14.0 * low
		if c == r._player:
			s -= 2.0
		if s < best_s:
			best_s = s
			best = c
	return best


## Plongée sûre (Difficile) : cible presque morte, PV ≥ 60 %, la tour ne le vise pas, aucun autre héros adverse à côté.
func _safe_dive(d: MobaDirector, hs: MobaHero, r: MobaRival, c: Combatant, hp: float) -> bool:
	if hs.difficulty != 2 or hp < DIVE_HP or c.hp / maxf(c.max_hp, 1.0) > DIVE_TARGET:
		return false
	for s in d.structures:
		if not s.is_dead and s.side != hs.side and s.target == r:
			return false
	return d.enemies_near(hs.side, c.global_position, 9.0, MobaDirector.KIND_HERO).size() <= 1


func _attack(r: MobaRival, c: Combatant) -> void:
	r.goal = Vector3.INF
	r._player = c


## Vers [param at] (ClassRival ne suit son but que s'il a une cible : le Cœur adverse par défaut, qu'il ne frappe pas).
func _go(r: MobaRival, at: Vector3, look: Combatant) -> void:
	r.goal = at
	if look == null or not is_instance_valid(look) or look.is_dead:
		look = r.director.cores[1 - r.side]
	r._player = look


## Recul : vers sa tour la plus proche en arrière (ou la fontaine), en gardant un œil sur la menace.
func _retreat(d: MobaDirector, hs: MobaHero, r: MobaRival, foes: Array) -> void:
	mode = "retreat"
	var side := hs.side
	var p := r.global_position
	var fountain: Vector3 = d.map.moba.fountains[side]
	var best := fountain
	var bd := INF
	var my_d := p.distance_to(fountain)
	for s in d.structures:
		if s.is_dead or s.side != side:
			continue
		var fd: float = s.global_position.distance_to(fountain)
		if fd < my_d - 4.0:
			var dd: float = p.distance_to(s.global_position)
			if dd < bd:
				bd = dd
				best = s.global_position + (fountain - s.global_position).normalized() * 3.0
	var threat: Combatant = null
	for f in foes:
		if threat == null or p.distance_to(f.global_position) < p.distance_to(threat.global_position):
			threat = f
	r.goal = best
	r._player = threat if threat != null else d.cores[1 - side]  # (sans cible, ClassRival ne suit pas son but : piège 1 de R_MB_D)


# --- postes ---------------------------------------------------------------------------------------------

func _lane(d: MobaDirector, hs: MobaHero, r: MobaRival) -> void:
	mode = "lane"
	var side := hs.side
	var tgt := _farm_target(d, hs, r, r._attack_range() + 4.0)
	if tgt != null:
		_attack(r, tgt)
		return
	_go(r, d._lane_goal(r, hs), null)


## Sbire (ou structure assiégeable) à frapper : le plus faible à portée, hors des zones interdites.
func _farm_target(d: MobaDirector, hs: MobaHero, r: MobaRival, reach: float) -> Combatant:
	var p := r.global_position
	var best: Combatant = null
	for m in d.enemies_near(hs.side, p, reach, MobaDirector.KIND_MINION):
		if _in_avoid(r, m.global_position, -1.0):
			continue
		if best == null or m.hp < best.hp:
			best = m
	if best != null:
		return best
	for s in d.enemies_near(hs.side, p, reach + 6.0, MobaDirector.KIND_STRUCT):
		var st := s as MobaStructure
		if st.invulnerable() or st.target == r or r.hp < r.max_hp * 0.5:
			continue
		if not d.enemies_near(hs.side, st.global_position, st.range_m + 8.0, MobaDirector.KIND_HERO).is_empty():
			continue  # (pas de siège quand un héros adverse défend)
		if d.units_near(hs.side, st.global_position, st.range_m, MobaDirector.KIND_MINION).size() >= 2 and st.target is MobaMinion:
			return st
	return null


func _support(d: MobaDirector, hs: MobaHero, r: MobaRival) -> void:
	mode = "follow"
	var carry: Combatant = null
	for h in d.heroes:
		var o: MobaHero = d.info[h]
		if o.side == hs.side and o.role == 2 and not h.is_dead:
			carry = h
	if carry == null or carry.global_position.distance_to(r.global_position) > 45.0 or (d.info[carry] as MobaHero).in_shop:
		_lane(d, hs, r)
		return
	# entre le tireur et la menace la plus proche (sinon un peu derrière lui, côté base)
	var threat: Combatant = null
	for f in d.enemies_near(hs.side, carry.global_position, 12.0, MobaDirector.KIND_HERO):
		if threat == null or carry.global_position.distance_to(f.global_position) < carry.global_position.distance_to(threat.global_position):
			threat = f
	var back: Vector3 = (d.map.moba.fountains[hs.side] - carry.global_position).normalized()
	var at := carry.global_position + back * 2.5
	if threat != null:
		at = carry.global_position + (threat.global_position - carry.global_position).normalized() * 2.0
	if _in_avoid(r, at):
		at = carry.global_position + back * 4.0
	var tgt := _farm_target(d, hs, r, r._attack_range() + 1.0) if carry.global_position.distance_to(r.global_position) < 8.0 else null
	if tgt != null and tgt is MobaMinion and (tgt as MobaMinion).hp > (tgt as MobaMinion).max_hp * 0.5:
		tgt = null  # (le soutien laisse les sbires au tireur, sauf pour finir une vague)
	if tgt != null:
		_attack(r, tgt)
		return
	_go(r, at, null)


# --- jungle -----------------------------------------------------------------------------------------------

func _jungle(d: MobaDirector, hs: MobaHero, r: MobaRival) -> void:
	var j = d.get("jungle")  # (MobaJungle, lot MB-F ; null sans jungle)
	if j == null or not is_instance_valid(j):
		_lane(d, hs, r)  # (sans jungle : il soutient la voie la plus en retard)
		return
	# embuscade : un héros adverse affaibli de notre côté d'une voie
	var prey := _gank_target(d, hs, r)
	if prey != null:
		mode = "gank"
		if r.global_position.distance_to(prey.global_position) < r._attack_range() + 6.0 and not (_in_avoid(r, prey.global_position) and not r.dive_ok):
			_attack(r, prey)
		else:
			_go(r, prey.global_position, null)
		return
	mode = "jungle"
	var e := _next_camp(d, hs, r, j)
	if e.is_empty():
		_go(r, d._lane_goal(r, hs), null)
		return
	if String(e.key) != target_camp:
		target_camp = String(e.key)
		_camp_hp = 2.0
		_camp_t = Moba.t
	var pos: Vector3 = e.pos
	if String(e.state) != "alive":
		var wait := float(e.respawn_at) - Moba.t - r.global_position.distance_to(pos) / maxf(r.travel_speed, 4.0)
		if wait > 25.0:
			_lane(d, hs, r)  # (longue attente : il aide la voie la plus en retard et revient à temps)
			mode = "jungle"
			return
		_go(r, pos, null)  # (il attend le camp qui revient le plus tôt)
		return
	var unit: Combatant = null
	var sum := 0.0
	var mx := 0.0
	for u in e.units:
		if not u.is_dead and not u.get("parked"):
			sum += u.hp
			mx += u.max_hp
			if not u.get("resetting") and float(_bad_unit.get(u, -1.0)) < Moba.t and (unit == null or u.hp < unit.hp):
				unit = u
	if unit == null:
		_go(r, pos, null)
		return
	var frac := sum / maxf(mx, 1.0)
	if frac < _camp_hp - 0.04:
		_camp_hp = frac
		_camp_t = Moba.t
	elif Moba.t - _camp_t > 12.0 and r.global_position.distance_to(unit.global_position) < 20.0:
		_skip[target_camp] = Moba.t + 25.0  # (il ne baisse plus : inaccessible ou remis à zéro ; il passe au suivant)
		target_camp = ""
		return
	var dd := r.global_position.distance_to(unit.global_position)
	if unit != _near_u:
		_near_u = unit
		_near_d = dd
		_near_t = Moba.t
	elif dd < _near_d - 0.5 or r._state == "attack":
		_near_d = dd
		_near_t = Moba.t
	elif Moba.t - _near_t > 2.5 and dd > r._attack_range() + 0.5:
		_bad_unit[unit] = Moba.t + 10.0  # (il n'avance plus vers ce monstre : bloqué ; l'autre du camp d'abord)
		_near_u = null
		return
	if dd > r._attack_range() + 8.0:
		_go(r, unit.global_position, null)
	else:
		_attack(r, unit)


## Camp suivant : vivant de sa moitié le plus proche (petits d'abord avant 2:00) ; sinon (avant 5:00, seulement si sa moitié
## n'a rien sous 45 s) de l'autre moitié sans héros
## adverse à 20 m ; sinon celui qui revient le plus tôt (s'il revient avant qu'on y soit, on l'attend sur place).
func _next_camp(d: MobaDirector, hs: MobaHero, r: MobaRival, j: Node) -> Dictionary:
	var p := r.global_position
	var best: Dictionary = {}
	var bs := INF
	var own_soon := false  # (avant 5:00, il ne va chez l'adversaire que si sa moitié n'a rien à offrir sous 45 s)
	for e in j.get("camps"):
		if int(e.half) == hs.side and (String(e.state) == "alive" or float(e.respawn_at) - Moba.t < 45.0):
			own_soon = true
	for e in j.get("camps"):
		var own := int(e.half) == hs.side
		if not own and (Moba.t < SHOP_FROM or (own_soon and Moba.t < 300.0)):
			continue  # (pas de vol de camps avant 4:00 : chacun fait sa moitié)
		if float(_skip.get(String(e.key), -1.0)) > Moba.t:
			continue
		var dist: float = p.distance_to(e.pos)
		var s := INF
		if String(e.state) == "alive":
			if not own and not d.enemies_near(hs.side, e.pos, 20.0, MobaDirector.KIND_HERO).is_empty():
				continue
			s = dist + (0.0 if own else 30.0) + (60.0 if String(e.kind) == "buff" and Moba.t < 150.0 else 0.0)  # (petits d'abord : ils reviennent avant 4:00)
			if String(e.key) == target_camp:
				s -= 8.0
		else:
			var left := float(e.respawn_at) - Moba.t
			var travel := dist / maxf(r.travel_speed, 4.0)
			if not own or left > travel + 12.0:
				continue
			s = 40.0 + maxf(left, travel) * 6.0 + dist * 0.2  # (il attend celui qui sera prêt le premier)
		if s < bs:
			bs = s
			best = e
	return best


func _gank_target(d: MobaDirector, hs: MobaHero, r: MobaRival) -> Combatant:
	if r.hp < r.max_hp * 0.6:
		return null
	var best: Combatant = null
	for h in d.heroes:
		var o: MobaHero = d.info[h]
		if o.side == hs.side or h.is_dead or o.lane < 0 or h.has_status("invisible"):
			continue
		var early := Moba.t < SHOP_FROM  # (avant 4:00, la jungle d'abord : seulement une proie presque morte et proche)
		if h.hp > h.max_hp * (GANK_EARLY_HP if early else GANK_HP) or r.global_position.distance_to(h.global_position) > (GANK_EARLY_RANGE if early else GANK_RANGE):
			continue
		var prog: float = d.map.lane_progress(hs.side, o.lane, h.global_position)
		if prog > d.map.lane_len[o.lane] * 0.55 or _in_avoid(r, h.global_position, 2.0):
			continue
		var allies: int = d.units_near(hs.side, h.global_position, 14.0, MobaDirector.KIND_HERO).size()
		var guards: int = d.enemies_near(hs.side, h.global_position, 12.0, MobaDirector.KIND_HERO).size()
		if allies + 1 < guards:
			continue
		if best == null or h.hp < best.hp:
			best = h
	return best


# --- économie ------------------------------------------------------------------------------------------

func _shop(d: MobaDirector, hs: MobaHero, diff: int) -> void:
	var r := MobaItems.route(hs, d.foe_families(hs), diff >= 2)
	if diff >= 3 and Moba.t >= 1200.0 and hs.items.size() >= MobaData.SLOTS:
		for i in hs.items.size():
			if String(MobaData.item(String(hs.items[i])).type) == "bottes":
				MobaItems.sell(hs, i)  # (Hardcore : les bottes cèdent la place à un objet de plus en fin de partie)
				r = r + ["coeur_pierre", "egide_rempart", "bouclier_gardien"]
				break
	MobaItems.auto_shop(hs, r, 2 if diff >= 2 else 1)
	skip_shop = false


## Retour d'achat : l'or paie l'objet suivant + 300 ; Facile en oublie un sur trois.
func _wants_shop(d: MobaDirector, hs: MobaHero, diff: int) -> bool:
	var adv := MobaItems.advice(hs, MobaItems.route(hs, d.foe_families(hs), diff >= 2))
	if adv.is_empty() or hs.gold < float(adv.cost) + SHOP_SPARE:
		return false
	if diff == 0:
		if skip_shop:
			return false
		if _rng.randf() < 1.0 / 3.0:
			skip_shop = true  # (oublié jusqu'au prochain passage à la base)
			return false
	if hs.lane >= 0:
		var mine: float = d.fronts[hs.side][hs.lane]
		var theirs: float = d.map.lane_len[hs.lane] - float(d.fronts[1 - hs.side][hs.lane])
		if mine < theirs - 25.0:
			return false  # (sa vague recule : il la défend d'abord)
	return true


static func _closest_dist(p: Vector3, list: Array) -> float:
	var best := INF
	for c in list:
		best = minf(best, p.distance_to(c.global_position))
	return best
