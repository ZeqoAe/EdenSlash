class_name AutochessSim
extends RefCounted
## L'Échiquier, lot AC-C : le SIMULATEUR de combats de données (SPEC §4.3, §9 ; rapport conception/autochess/R_AC_C.md).
## Combat déterministe sans scène (aucun nœud, aucune physique) : unités sur le plan du plateau (coordonnées continues en
## mètres, celles de la couche : AutochessEffects.cell_pos, camp 0 en y négatif), déplacement, portée, ciblage simple par
## rôle, rythme des auto-attaques (vitesse d'attaque), mana, sorts selon leur forme (zone posée, cercle autour de soi, cône,
## trait), soins, ★3 enchaîné, sauts des Ombre, relances d'Arcane ; Fureur à 30 s et égalité à 45 s (la couche et
## AutochessDirector.draw_at). Il utilise la MÊME couche d'effets (AutochessEffects : PV, mana, défense, traits, objets,
## atouts) et la MÊME fiche de base (AutochessDirector.base_sheet) que le vrai combat : seul le moteur (déplacement, choix
## des cibles, géométrie des sorts) est simplifié.
##
## Utilisation :
##   partie.fight = AutochessSim.fight                    # combat injecté dans la machine d'AC-B (à la place de power_fight)
##   var r := AutochessSim.fight(plateau_a, plateau_b, ctx)  # {winner 0 / 1 / -1, stars, duration, gold} (+ « mode » « sim »)
##   AutochessSim.run(ctx_effets, t, fin)                 # finir un combat déjà commencé (repli des plateaux cachés,
##                                                        # même signature que AutochessDirector.data_run)
## Calage (outil tools/autochess_fight.tscn, test test_ac_sim) : réglages TUNE ci-dessous (temps d'animation, esquive des
## zones, vitesse), facteur par unité « sim_factor » de data/autochess_units.json (× attaque et sort de l'unité dans le
## simulateur seulement). Quand l'IA fine d'AC-U change le vrai combat : relancer `autochess_fight.tscn -- --calib`, puis
## régler TUNE (ou les sim_factor) jusqu'à ce que l'accord revienne (R_AC_C.md, « Recaler »).

const STEP := 0.1  # s : pas du simulateur (déplacements, coups, sorts)
const TICK_EVERY := 3  # la couche d'effets avance tous les 3 pas (0,3 s : impulsions, bonus, Fureur ; cadence ×1,4)
const RETARGET_EVERY := 0.3  # s : décision de cible (le vrai combat : 0,25 s)
const UNIT_RADIUS := 0.5  # m : rayon d'une unité (Combatant.radius), compte dans les zones
const RANGED_ABOVE := 6.0  # m : au-delà de cette allonge, l'unité garde ses distances (ClassRival._ranged)
const HALF_X := AutochessDirector.HALF_X - AutochessData.BOARD_MARGIN
const HALF_Y := AutochessDirector.HALF_Z - AutochessData.BOARD_MARGIN
const CHAIN_FACTOR := AutochessUnit.CHAIN_FACTOR  # ★3 : 2e sort à 60 %
const ZONE_WAIT := AutochessData.AI_ZONE_WAIT
const HEAL_WAIT := AutochessData.AI_HEAL_WAIT
## Réglages du moteur simplifié, calés sur le vrai combat (R_AC_C.md). Valeurs mesurées sur le squelette d'AC-E.
static var TUNE := {
	"speed": ClassRival.DIFF[AutochessData.UNIT_DIFF].speed,  # m/s : course (× stat « move »)
	"auto_hit": 0.4,  # s : de l'élan à l'impact d'une auto-attaque (ClassRival cfg.tele)
	"auto_lock": 1.8,  # s : durée d'une auto-attaque menée au bout (immobile ; animation et élan)
	"auto_cancel": ClassRival.DIFF[AutochessData.UNIT_DIFF].cancel,  # chance de couper la fin du coup après l'impact
	"spell_hit": 0.5,  # s : de l'élan à l'impact d'un sort (annonce rouge)
	"spell_lock": 1.2,  # s : durée d'un sort (immobile)
	"spell_gap": 0.25,  # s : attente après un sort
	"zone_dodge": 0.7,  # chance qu'une cible prise dans une zone en sorte (esquive de l'IA, charges comprises)
	"reach_k": 0.95,  # allonge utile (AutochessUnit._attack_range)
	"hit_slack": 1.2,  # m : une auto-attaque touche si la cible est encore à allonge + rayon + ça à l'impact
	"focus_hp": 16.0,  # score de cible = distance + focus_hp × part de PV (ClassRival en équipe, Difficile)
	"inertia": 2.5,  # m : on garde sa cible à score presque égal
	"assassin_back": 4.0,  # m : bonus de l'assassin pour l'arrière-ligne (rôles simples)
	"move_fudge": 0.85,  # part de la course vraiment utile (détours, contournements, collisions)
}

static var _skills := {}  # id -> [sort signature, 2e sort]


# --- Combat injecté -----------------------------------------------------------------------------------------------
## Combat de données de deux plateaux de la machine (format du combat injecté d'AC-B) : même fiche, même couche.
static func fight(board_a: Array, board_b: Array, fctx: Dictionary) -> Dictionary:
	return run(make_context(board_a, board_b, fctx), 0.0, AutochessDirector.draw_at())


## Contexte d'effets d'un combat (cases d'AutochessDirector._placed, fiche AutochessDirector.base_sheet, sim_factor).
static func make_context(board_a: Array, board_b: Array, fctx: Dictionary) -> Dictionary:
	var ctx := AutochessEffects.context(fctx, [AutochessDirector._placed(board_a, false), AutochessDirector._placed(board_b, true)],
		func(u): return AutochessDirector.base_sheet(u))
	for fid in ctx.units:
		var u: Dictionary = ctx.units[fid]
		var f := sim_factor(String(u.id))
		if f != 1.0:
			u.sheet["atk"] = float(u.sheet.atk) * f
			u.sheet["spell_base"] = float(u.sheet.get("spell_base", 0.0)) * f
	return ctx


## Facteur de calage d'une unité (données « sim_factor », 1 par défaut).
static func sim_factor(id: String) -> float:
	if id == "":
		return 1.0
	return clampf(float(AutochessData.unit(id).get("sim_factor", 1.0)), 0.25, 4.0)


# --- Boucle -------------------------------------------------------------------------------------------------------
## Joue le contexte [param ctx] de [param t_from] à la fin ou à [param t_end] s (pas encore commencé : start ici, sauts
## des Ombre compris). Positions de départ : celles du contexte (cases, ou positions du vrai combat au moment du repli).
## [param opts] : tune (réglages à la place de TUNE), counts (compteurs dans le résultat), bounds (compte dans
## counts.out les positions hors du plateau à chaque pas : tests). Rend le résultat.
static func run(ctx: Dictionary, t_from: float, t_end: float, opts := {}) -> Dictionary:
	var start_fx: Array = []
	if not ctx.started:
		start_fx = AutochessEffects.start(ctx)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ctx.fight.get("seed", 0)) * 7919 + 104729
	var tune: Dictionary = TUNE.duplicate()
	for k in opts.get("tune", {}):
		tune[k] = opts.tune[k]
	var sim := {"ctx": ctx, "rng": rng, "tune": tune, "t": t_from, "st": {}, "order": [],
		"counts": {"autos": 0, "casts": 0, "heals": 0, "spell_hits": 0, "spell_dodged": 0, "chains": 0, "recasts": 0, "leaps": 0, "out": 0}}
	for side in 2:
		for fid in ctx.sides[side]:
			sim.order.append(int(fid))
			sim.st[int(fid)] = _unit_state(ctx, int(fid))
	_on_fx(sim, start_fx)  # sauts des Ombre
	var t := t_from
	var steps := 0
	var check_bounds: bool = opts.get("bounds", false)
	var pending := 0.0  # temps pas encore passé à la couche (elle avance tous les TICK_EVERY pas)
	while t < t_end - 0.0001:
		if _side_down(ctx, 0) or _side_down(ctx, 1):
			break
		t += STEP
		pending += STEP
		steps += 1
		if steps % TICK_EVERY == 0:
			_on_fx(sim, AutochessEffects.tick(ctx, pending))
			pending = 0.0
		sim["t"] = t
		for fid in sim.order:
			_step_unit(sim, fid)
		if check_bounds:
			for fid in sim.order:
				var p: Vector2 = ctx.units[fid].pos
				if absf(p.x) > HALF_X + 0.001 or absf(p.y) > HALF_Y + 0.001:
					sim.counts.out += 1
	if pending > 0.0001:
		_on_fx(sim, AutochessEffects.tick(ctx, pending))
	var r := AutochessEffects.result(ctx)
	r["duration"] = t
	r["mode"] = "sim"
	if opts.get("counts", false):
		r["counts"] = sim.counts
	return r


static func _side_down(ctx: Dictionary, side: int) -> bool:
	for f in ctx.sides[side]:
		if ctx.units[f].alive:
			return false
	return true


static func _unit_state(ctx: Dictionary, fid: int) -> Dictionary:
	var u: Dictionary = ctx.units[fid]
	var sk := skills_of(String(u.id))
	var chain: Dictionary = sk[1] if int(u.stars) >= AutochessData.MAX_STARS and AutochessData.STAR3_CHAIN else {}
	return {"reach": AutochessEffects.stat(ctx, fid, "reach"), "target": -1, "retarget": 0.0, "ready": 0.0, "act": {}, "full_at": -1.0, "sig": sk[0], "chain": chain,
		"chain_next": false, "recast": false, "role": String(u.role), "magic": String((sk[0] as Dictionary).get("dmg_type", "phys")) in ["mag", "magic"]}


## Sort signature et 2e sort (★3) d'une unité, lus une fois (classes.json par AutochessUnit.skill_of).
static func skills_of(id: String) -> Array:
	if _skills.has(id):
		return _skills[id]
	var out := [{}, {}]
	if id != "" and GameData.classes.has(id):
		var d := AutochessData.unit(id)
		out = [AutochessUnit.skill_of(id, int(d.get("skill_id", 0))), AutochessUnit.skill_of(id, int(d.get("second_skill_id", 0)))]
	_skills[id] = out
	return out


## Effets que le moteur exécute : saut des Ombre (leap), relance d'Arcane (recast) ; chutes : la cible se perd.
static func _on_fx(sim: Dictionary, fx: Array) -> void:
	for e in fx:
		match String(e.get("type", "")):
			"leap":
				_leap(sim, int(e.get("src", -1)))
			"recast":
				var s: Dictionary = sim.st.get(int(e.get("src", -1)), {})
				if not s.is_empty():
					s["recast"] = true
					sim.counts.recasts += 1


static func _leap(sim: Dictionary, fid: int) -> void:
	var ctx: Dictionary = sim.ctx
	var u: Dictionary = ctx.units.get(fid, {})
	if u.is_empty() or not u.alive:
		return
	var best := -1
	var by := 0.0
	for f in ctx.sides[1 - int(u.side)]:
		var e: Dictionary = ctx.units[f]
		if not e.alive:
			continue
		var y: float = (e.pos as Vector2).y
		# camp 0 en y négatif : l'arrière adverse est vers les y positifs (et l'inverse)
		if best < 0 or (y > by if int(u.side) == 0 else y < by):
			best = int(f)
			by = y
	if best < 0:
		return
	var p: Vector2 = ctx.units[best].pos
	p.y += 1.2 if int(u.side) == 0 else -1.2
	u["pos"] = _clamp(p)
	sim.st[fid]["target"] = best
	sim.counts.leaps += 1


static func _clamp(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, -HALF_X, HALF_X), clampf(p.y, -HALF_Y, HALF_Y))


# --- Une unité, un pas --------------------------------------------------------------------------------------------
static func _step_unit(sim: Dictionary, fid: int) -> void:
	var ctx: Dictionary = sim.ctx
	var u: Dictionary = ctx.units[fid]
	if not u.alive:
		return
	var s: Dictionary = sim.st[fid]
	var t: float = sim.t
	var tune: Dictionary = sim.tune
	var stunned: bool = float(u.cc_until) > float(ctx.t)
	var act: Dictionary = s.act
	if not act.is_empty():
		if stunned and String(act.mode) == "auto" and not act.done:
			s["act"] = {}  # un contrôle annule l'auto-attaque en préparation (les sorts, eux, tombent)
			return
		if not act.done and t + 0.0001 >= float(act.hit_at):
			act["done"] = true
			_impact(sim, fid, act)
		if t + 0.0001 >= float(act.end_at):
			s["act"] = {}
			if String(act.mode) == "auto":
				s["ready"] = maxf(t, float(act.start) + 1.0 / maxf(AutochessEffects.stat(ctx, fid, "as"), 0.1))
			elif s.chain_next:
				s["ready"] = t
			else:
				s["ready"] = t + float(tune.spell_gap)
		return
	if stunned:
		return
	# cible
	var tgt: int = s.target
	if tgt < 0 or not ctx.units[tgt].alive or t >= float(s.retarget):
		tgt = _pick_target(sim, fid, tgt)
		s["target"] = tgt
		s["retarget"] = t + RETARGET_EVERY
	if tgt < 0:
		return
	var reach := float(s.reach) * float(tune.reach_k)
	var pos: Vector2 = u.pos
	var tp: Vector2 = ctx.units[tgt].pos
	var d := pos.distance_to(tp)
	var ready: bool = t + 0.0001 >= float(s.ready)
	if ready and d <= reach + 0.3:
		_start_action(sim, fid, tgt)
		return
	# déplacement : vers la cible jusqu'à l'allonge ; un tireur qui attend son coup garde ses distances
	var spd := float(tune.speed) * float(tune.move_fudge) * AutochessEffects.stat(ctx, fid, "move") * STEP
	var want := reach
	if not ready and reach > RANGED_ABOVE:
		want = reach * 0.75
	elif not ready:
		want = reach  # mêlée : reste au contact
	if d > want:
		u["pos"] = _clamp(pos.move_toward(tp, minf(spd, d - want + 0.05)))
	elif reach > RANGED_ABOVE and d < want - 0.5:
		u["pos"] = _clamp(pos + (pos - tp).normalized() * minf(spd, want - d))


## Cible : ennemi au meilleur score (ClassRival en équipe : distance + part de PV × focus_hp, inertie) ; assassin :
## l'arrière-ligne d'abord ; soigneur et soutien : le plus proche.
static func _pick_target(sim: Dictionary, fid: int, cur: int) -> int:
	var ctx: Dictionary = sim.ctx
	var tune: Dictionary = sim.tune
	var u: Dictionary = ctx.units[fid]
	var pos: Vector2 = u.pos
	var role: String = sim.st[fid].role
	var fh := float(tune.focus_hp)
	if role == "soigneur" or role == "soutien":
		fh *= 0.5
	var best := -1
	var bs := INF
	for f in ctx.sides[1 - int(u.side)]:
		var e: Dictionary = ctx.units[f]
		if not e.alive:
			continue
		var sc := pos.distance_to(e.pos) + fh * float(e.hp) / maxf(float(e.hp_max), 1.0)
		if role == "assassin":
			sc -= float(tune.assassin_back) * float(e.row) / 3.0
		if int(f) == cur:
			sc -= float(tune.inertia)
		if sc < bs:
			bs = sc
			best = int(f)
	return best


# --- Actions ------------------------------------------------------------------------------------------------------
static func _start_action(sim: Dictionary, fid: int, tgt: int) -> void:
	var ctx: Dictionary = sim.ctx
	var s: Dictionary = sim.st[fid]
	var t: float = sim.t
	var tune: Dictionary = sim.tune
	var sk: Dictionary = {}
	var mode := "auto"
	if s.chain_next:
		s["chain_next"] = false
		sk = s.chain
		mode = "chain"
		sim.counts.chains += 1
	elif _wants_cast(sim, fid, tgt):
		sk = s.sig
		mode = "spell"
		if s.recast:
			s["recast"] = false
		else:
			_on_fx(sim, AutochessEffects.cast(ctx, fid))
			sim.counts.casts += 1
		s["full_at"] = -1.0
		if not (s.chain as Dictionary).is_empty():
			s["chain_next"] = true
	if sk.is_empty():
		# fin de l'animation, ou coupée juste après l'impact (ClassRival : annulation, chance cfg.cancel) ; le coup suivant
		# attend aussi 1 / vitesse d'attaque depuis l'élan
		var hit := t + float(tune.auto_hit)
		var cut: bool = (sim.rng as RandomNumberGenerator).randf() < float(tune.auto_cancel)
		s["act"] = {"mode": "auto", "start": t, "hit_at": hit, "end_at": hit + 0.06 if cut else t + float(tune.auto_lock),
			"target": tgt, "done": false}
		return
	var act := {"mode": mode, "skill": sk, "start": t, "hit_at": t + float(tune.spell_hit), "end_at": t + float(tune.spell_lock),
		"target": tgt, "done": false}
	if _is_heal(sk):
		act["heal_to"] = _heal_target(ctx, fid, true)
	else:
		_aim(sim, fid, tgt, sk, act)
	s["act"] = act


## Le sort part-il ? Mana pleine (ou relance), cible à l'allonge du sort (ou attente de ZONE_WAIT s) ; soin : un allié
## blessé (ou après HEAL_WAIT s).
static func _wants_cast(sim: Dictionary, fid: int, tgt: int) -> bool:
	var ctx: Dictionary = sim.ctx
	var s: Dictionary = sim.st[fid]
	if (s.sig as Dictionary).is_empty():
		return false
	if not s.recast and not AutochessEffects.can_cast(ctx, fid):
		s["full_at"] = -1.0
		return false
	var t: float = sim.t
	if float(s.full_at) < 0.0:
		s["full_at"] = t
	var waited := t - float(s.full_at)
	if _is_heal(s.sig):
		return _heal_target(ctx, fid, waited >= HEAL_WAIT) >= 0
	return waited >= ZONE_WAIT or AutochessEffects.dist(ctx, fid, tgt) <= skill_reach(s.sig)


static func _is_heal(sk: Dictionary) -> bool:
	return String(sk.get("kind", "")) == "heal"


## Allié le plus bas en part de PV (blessé, ou n'importe lequel si [param any]).
static func _heal_target(ctx: Dictionary, fid: int, any: bool) -> int:
	var best := -1
	var bf := INF
	for f in ctx.sides[int(ctx.units[fid].side)]:
		var a: Dictionary = ctx.units[f]
		if not a.alive:
			continue
		var fr := float(a.hp) / maxf(float(a.hp_max), 1.0)
		if (any or fr < 0.999) and fr < bf:
			bf = fr
			best = int(f)
	return best


## Allonge d'un sort (AutochessUnit.skill_reach, sans le rayon de l'unité pour les cercles autour de soi).
static func skill_reach(sk: Dictionary) -> float:
	var kind := String(sk.get("kind", "cone"))
	var r := float(sk.get("radius", 3.0))
	var rng := float(sk.get("range", 0.0))
	if kind in ["bolt", "ground", "line", "fan", "blink"] or rng > r + 1.0:
		return maxf(rng, r) + 0.5
	if kind == "dash":
		return maxf(rng, 6.0) + r
	return r + UNIT_RADIUS + 0.6


## Forme du sort posée au lancement (comme AutochessUnit._begin_action) : cercle visé, trait, cercle autour de soi, cône.
static func _aim(sim: Dictionary, fid: int, tgt: int, sk: Dictionary, act: Dictionary) -> void:
	var ctx: Dictionary = sim.ctx
	var pos: Vector2 = ctx.units[fid].pos
	var to: Vector2 = (ctx.units[tgt].pos as Vector2) - pos
	var kind := String(sk.get("kind", "cone"))
	var r := float(sk.get("radius", 3.0))
	var rng := float(sk.get("range", 0.0))
	var far := to.length() > skill_reach(sk) + 0.5
	var dir := to.normalized() if to.length() > 0.01 else Vector2(0.0, 1.0 if int(ctx.units[fid].side) == 0 else -1.0)
	act["dir"] = dir
	if kind == "ground" or (far and not kind in ["bolt", "line", "fan", "dash", "blink"]):
		act["shape"] = "circle"
		act["at"] = pos + to.limit_length(maxf(rng, to.length() if far else 4.0))
		act["radius"] = maxf(r, 2.0)
	elif kind in ["bolt", "line", "fan", "blink"] or rng > r + 1.0:
		act["shape"] = "line"
		act["at"] = pos
		act["length"] = maxf(maxf(rng, r), to.length() + 1.0)
		act["width"] = 1.4 if kind != "line" else maxf(1.4, minf(r, 3.0))
	elif float(sk.get("arc", 120.0)) >= 359.0 or kind == "spin":
		act["shape"] = "circle"
		act["at"] = pos
		act["radius"] = r
	else:
		act["shape"] = "cone"
		act["at"] = pos
		act["radius"] = r
		act["angle"] = float(sk.get("arc", 120.0))
	if kind == "dash":
		ctx.units[fid]["pos"] = _clamp(pos + dir * minf(to.length(), maxf(rng, 6.0)))


static func _inside(act: Dictionary, p: Vector2) -> bool:
	var at: Vector2 = act.at
	var m := UNIT_RADIUS
	match String(act.shape):
		"line":
			var dir: Vector2 = act.dir
			var rel := p - at
			var along := rel.dot(dir)
			var lat := absf(rel.cross(dir))
			return lat <= float(act.width) * 0.5 + m and along >= -m and along <= float(act.length) + m
		"cone":
			var rel := p - at
			var l := rel.length()
			if l > float(act.radius) + m:
				return false
			return l < 1.0 or rad_to_deg(absf((act.dir as Vector2).angle_to(rel))) <= float(act.angle) * 0.5
	return p.distance_to(at) <= float(act.radius) + m


## Impact : auto-attaque (cible encore à portée), soin, ou zone du sort (chaque ennemi dedans, sauf esquive).
static func _impact(sim: Dictionary, fid: int, act: Dictionary) -> void:
	var ctx: Dictionary = sim.ctx
	var u: Dictionary = ctx.units[fid]
	if not u.alive:
		return
	var tune: Dictionary = sim.tune
	var mode := String(act.mode)
	if mode == "auto":
		var tgt := int(act.target)
		var e: Dictionary = ctx.units[tgt]
		if e.alive and (u.pos as Vector2).distance_to(e.pos) <= float(sim.st[fid].reach) * float(tune.reach_k) + UNIT_RADIUS + float(tune.hit_slack):
			sim.counts.autos += 1
			_on_fx(sim, AutochessEffects.attack(ctx, fid, tgt))
		return
	var sk: Dictionary = act.skill
	var k := CHAIN_FACTOR if mode == "chain" else 1.0
	if act.has("heal_to"):
		var h := int(act.heal_to)
		if h >= 0 and ctx.units[h].alive:
			var amount := AutochessEffects.hp_max(ctx, h) * clampf(float(sk.get("heal", 0.25)), 0.1, 0.4) \
				* AutochessData.spell_mult(int(u.stars)) * k
			sim.counts.heals += 1
			_on_fx(sim, AutochessEffects.spell_heal(ctx, fid, h, amount))
		return
	var base := maxf(1.0, float(u.sheet.get("spell_base", 0.0)) * k)
	var kind := "magic" if sim.st[fid].magic else "phys"
	var dodge := float(tune.zone_dodge)
	var rng: RandomNumberGenerator = sim.rng
	for f in (ctx.sides[1 - int(u.side)] as Array).duplicate():
		var e: Dictionary = ctx.units[f]
		if not e.alive or not _inside(act, e.pos):
			continue
		if dodge > 0.0 and rng.randf() < dodge:
			sim.counts.spell_dodged += 1
			continue
		sim.counts.spell_hits += 1
		_on_fx(sim, AutochessEffects.spell_hit(ctx, fid, int(f), base, {"kind": kind}))
		if not u.alive:
			return
