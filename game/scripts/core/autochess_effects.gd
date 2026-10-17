class_name AutochessEffects
extends RefCounted
## L'Échiquier, lot AC-H : la couche d'effets d'un combat, PURE (aucun nœud, aucune scène), partagée par le simulateur de
## données (AC-C) et le vrai combat (AC-E / AC-U). Spécification : conception/autochess/SPEC.md §3.3, §5.3-5.5 ; rapport et
## mode d'emploi : conception/autochess/R_AC_H.md. Les effets de chaque famille sont dans AutochessItems (36 objets,
## composants, emblèmes), AutochessTraits (15 traits) et AutochessAugments (atouts de combat) ; ce fichier tient l'état du
## combat et la résolution des coups, et appelle les trois modules dans cet ordre fixe : traits, objets, atouts.
##
## Partage des rôles :
## - la couche tient les PV, la mana, les boucliers, les bonus temporaires, les contrôles, les brûlures / saignements, les
##   zones et les déclencheurs (TRIGGERS) ; elle résout chaque coup (esquive, parade, critique, défense, plafond de 20 %,
##   Fureur) ;
## - le moteur (simulateur ou vrai combat) tient le déplacement, le choix des cibles, le rythme des attaques
##   (1 / stat(ctx, fid, "as") s) et des sorts, l'affichage ; il pose la position des unités (set_pos) et lit la vérité ici
##   (hp, mana, alive, disabled, stat).
##
## Utilisation (un combat) :
##   var ctx := AutochessEffects.context(fight.ctx, [fight.board_a, fight.board_b])  # fiches finales (apply_stats)
##   AutochessEffects.start(ctx)                                  # « debut_combat »
##   chaque pas : AutochessEffects.tick(ctx, dt)                   # « temps » (+ brûlures, zones, mana continue)
##   attaque qui touche : AutochessEffects.attack(ctx, src, dst)  # « attaque », « coup_recu », « critique », « esquive »…
##   mana pleine : if can_cast(ctx, src): cast(ctx, src), puis spell_hit / spell_heal sur chaque cible du sort
##   fin : AutochessEffects.result(ctx) -> {winner, stars, duration, gold} (format du combat injecté d'AC-B)
## Chaque appel public rend la liste des effets produits pendant l'appel (dictionnaires « type » : damage, heal, shield,
## mana, cc, buff, dodge, parry, death, invuln, zone, gold ; et deux que le MOTEUR doit exécuter : « leap » (saut d'une
## Ombre sur l'arrière ennemi) et « recast » (relancer le sort sans mana : Arcane à 9)). Tout le reste est déjà appliqué.
##
## Garde-fous : profondeur de déclencheurs MAX_DEPTH, MAX_EFFECTS_PER_CALL effets par appel, dégâts « proc » (venus d'un
## effet) qui ne relancent jamais les effets d'attaque ni les renvois (pas de boucle Robustesse contre Robustesse),
## statistiques bornées (CAPS), aucune division par une valeur nulle. Hasard : ctx.rng (graine du combat), tiré seulement
## quand une chance est strictement entre 0 et 1 : même entrées + mêmes appels = même combat.

const MAX_DEPTH := 3
const MAX_EFFECTS_PER_CALL := 96
const PULSE := 0.5  # s : brûlures, saignements, zones et mana continue (Chœur) par impulsions
const MAX_PULSES_PER_TICK := 8
const DEF_SCALE := 100.0  # dégâts × 100 / (100 + défense) : 100 de défense = moitié des dégâts
const SLOW_MOVE := -0.30  # ralentissement des zones (Élémentaire à 6)
const SLOW_DUR := 1.0
## Bornes des statistiques (fiche finale et valeurs du moment).
const CAPS := {
	"hp_pct": [-0.5, 4.0], "atk_pct": [-0.7, 4.0], "as_pct": [-0.7, 3.0], "spell_pct": [-0.5, 4.0],
	"mana_max_pct": [-0.6, 1.0], "crit": [0.0, 1.0], "crit_dmg": [0.0, 3.0], "dodge": [0.0, 0.6], "parry": [0.0, 0.6],
	"armor_pen": [0.0, 0.9], "dmg_taken": [0.3, 3.0], "heal_taken": [0.0, 3.0], "range": [1.0, 7.0], "as": [0.1, 5.0],
	"move": [0.3, 2.5], "def": [0.0, 1000.0], "mdef": [0.0, 1000.0], "scale": [0.5, 2.0], "heal_cut": [0.0, 0.9],
}
## Fiche de base par défaut d'une unité (données seules, provisoire) : le moteur donne la vraie (champ « sheet » de l'unité
## ou Callable base_fn de context()). Clés d'une fiche : hp, atk, as (attaques / s), mana_max, mana_start, def, mdef, crit,
## crit_dmg (bonus : 0,5 = ×1,5), dodge, parry, armor_pen, range (cases), spell_power (×), spell_base (dégâts de base du sort,
## rang compris), dmg_taken (×), heal_taken (×), move (×), scale ; hp_start (facultatif : PV de départ, tests).
const BASE_DEFAULTS := {
	"hp": 600.0, "atk": 50.0, "as": 0.8, "mana_max": 80.0, "mana_start": 0.0, "def": 15.0, "mdef": 15.0, "crit": 0.0,
	"crit_dmg": 0.5, "dodge": 0.0, "parry": 0.0, "armor_pen": 0.0, "range": 1.0, "spell_power": 1.0, "spell_base": 0.0,
	"dmg_taken": 1.0, "heal_taken": 1.0, "move": 1.0, "scale": 1.0,
}
const BASE_HP := 650.0
const BASE_ATK := 55.0
const BASE_SPELL := 2.2  # sort de base = attaque × 2,2 (× rang du sort)
const ROLE_BASE := {
	"tank": {"hp": 1.35, "atk": 0.75, "as": 0.75, "def": 30.0, "mdef": 20.0},
	"combattant": {"hp": 1.1, "atk": 1.0, "as": 0.85, "def": 20.0, "mdef": 15.0},
	"assassin": {"hp": 0.85, "atk": 1.2, "as": 0.95, "def": 10.0, "mdef": 10.0},
	"tireur": {"hp": 0.8, "atk": 1.05, "as": 0.8, "def": 10.0, "mdef": 10.0},
	"mage": {"hp": 0.8, "atk": 0.8, "as": 0.7, "def": 10.0, "mdef": 20.0},
	"soigneur": {"hp": 0.85, "atk": 0.6, "as": 0.7, "def": 10.0, "mdef": 20.0},
	"soutien": {"hp": 0.9, "atk": 0.7, "as": 0.7, "def": 15.0, "mdef": 15.0},
}
const MONSTER_BASE := {
	"sbire": {"hp": 500.0, "atk": 35.0, "as": 0.7, "def": 10.0, "mdef": 10.0, "mana_max": 140.0},
	"elite": {"hp": 1100.0, "atk": 60.0, "as": 0.75, "def": 25.0, "mdef": 25.0, "mana_max": 140.0},
}
const GUARDIAN_HP_PER_STAGE := 1800.0
const GUARDIAN_ATK := 45.0
const GUARDIAN_ATK_PER_STAGE := 0.35
const STAT_ACC_KEYS := ["hp", "hp_pct", "atk_pct", "as_pct", "spell_pct", "mana_start", "def", "mdef", "crit", "crit_dmg",
	"dodge", "range", "dmg_taken", "mana_max_pct", "heal_taken", "armor_pen", "parry", "scale"]
const STAT_NAMES := ["dealt", "dealt_spell", "dealt_proc", "zone_dealt", "taken", "healed", "heal_done", "shielded",
	"blocked", "mana_gained", "mana_lost", "casts", "attacks", "hits", "crits", "dodges", "parries", "cc_done", "cc_taken",
	"kills", "executes", "dealt_attack"]  # dealt_attack : dégâts des auto-attaques (statistiques, lot AC-V)


# --- Contexte ------------------------------------------------------------------------------------------------------
## Contexte d'effets d'un combat. [param fight_ctx] : le ctx d'un combat d'AC-B (stage, kind, seed, augments [a, b],
## traits [a, b] déjà comptés avec Cœur de famille / Double trait / emblèmes ; sans « traits » : comptés ici).
## [param teams] : [plateau_a, plateau_b] (board_snapshot d'AC-B : id, stars, cost, items, cell, traits ; monstres
## {monster} ; gardien {guardian, stage, mult}). Fiche de base d'une unité : son champ « sheet » s'il existe, sinon
## [param base_fn].call(unité) si donné, sinon default_base(). Positions : cases du plateau (voir cell_pos), à mettre à jour
## par set_pos si les unités bougent.
static func context(fight_ctx: Dictionary, teams: Array, base_fn := Callable()) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(fight_ctx.get("seed", 0))
	var ctx := {
		"t": 0.0, "fight": fight_ctx, "rng": rng, "units": {}, "sides": [[], []], "traits": [{}, {}], "tiers": [{}, {}],
		"augments": [[], []], "team": [{}, {}], "gold": [0, 0], "zones": [], "pulse_next": PULSE, "started": false,
		"rules": {"fury": true, "hit_cap": true}, "journal": [], "log": [], "keep_log": false, "budget": 0, "dropped": 0,
		"depth": 0,
	}
	var augs: Array = fight_ctx.get("augments", [[], []])
	for side in 2:
		ctx.augments[side] = (augs[side] as Array).duplicate() if side < augs.size() and augs[side] is Array else []
		var team: Array = teams[side] if side < teams.size() and teams[side] is Array else []
		for u in team:
			var fid: int = (ctx.units as Dictionary).size()
			ctx.units[fid] = _make_unit(fid, side, u, base_fn)
			ctx.sides[side].append(fid)
	var given: Array = fight_ctx.get("traits", [])
	for side in 2:
		var counts: Dictionary = {}
		if fight_ctx.has("traits") and side < given.size() and given[side] is Dictionary:
			counts = (given[side] as Dictionary).duplicate()
		elif not fight_ctx.has("traits"):
			counts = count_traits(ctx, side)
		ctx.traits[side] = counts
		var tiers := {}
		for t in counts:
			if AutochessData.TRAITS.has(t):
				var tier := AutochessData.trait_tier(String(t), int(counts[t]))
				if tier > 0:
					tiers[String(t)] = tier
		ctx.tiers[side] = tiers
	AutochessAugments.prepare_team(ctx)
	for fid in ctx.units:
		var u: Dictionary = ctx.units[fid]
		u["sheet"] = apply_stats(u, ctx)
		u["hp_max"] = float(u.sheet.hp)
		u["hp"] = clampf(float(u.sheet.get("hp_start", u.hp_max)), 1.0, u.hp_max)
		u["mana"] = clampf(float(u.sheet.mana_start), 0.0, float(u.sheet.mana_max))
	return ctx


static func _make_unit(fid: int, side: int, u: Dictionary, base_fn: Callable) -> Dictionary:
	var base: Dictionary = BASE_DEFAULTS.duplicate()
	var given: Dictionary = {}
	if u.get("sheet") is Dictionary:
		given = u.sheet
	elif base_fn.is_valid():
		given = base_fn.call(u)
	else:
		given = default_base(u)
	for k in given:
		base[k] = given[k]
	var cell: Array = u.get("cell", [3, 0]) if u.get("cell") is Array else [3, 0]
	var id := String(u.get("id", ""))
	var icount := {}
	var items: Array = []
	for s in u.get("items", []):
		var info: Dictionary = Autochess.parse_item(String(s))
		items.append(String(s))
		icount[String(info.id)] = int(icount.get(String(info.id), 0)) + 1
	var traits: Array = u.get("traits", []) if u.get("traits") is Array else \
		(AutochessData.unit(id).get("traits", []) as Array).duplicate()
	var col := int(cell[0]) if cell.size() > 0 else 3
	var row := int(cell[1]) if cell.size() > 1 else 0
	var stats := {}
	for k in STAT_NAMES:
		stats[k] = 0.0
	return {
		"fid": fid, "side": side, "id": id, "uid": int(u.get("uid", -1)), "cost": int(u.get("cost", AutochessPool.cost_of(id) if id != "" else 1)),
		"stars": int(u.get("stars", 1)), "items": items, "icount": icount, "traits": traits, "col": col, "row": row,
		"monster": String(u.get("monster", "")), "guardian": bool(u.get("guardian", false)), "mult": float(u.get("mult", 1.0)),
		"role": String(AutochessData.unit(id).get("role", "combattant")), "base": base, "sheet": {}, "hp": 1.0, "hp_max": 1.0,
		"mana": 0.0, "alive": true, "pos": cell_pos(side, col, row), "mods": [], "shields": [], "dots": [], "cuts": [],
		"cc_until": 0.0, "cc_kind": "", "immune_until": 0.0, "invuln_until": 0.0, "st": {"attacks": 0, "casts": 0}, "stats": stats,
	}


## Fiche de base d'une unité à partir des données seules (provisoire : le moteur peut donner la vraie). Unités : coût,
## étoiles, rôle ; monstres et gardien : MONSTER_BASE, GUARDIAN_*.
static func default_base(u: Dictionary) -> Dictionary:
	if u.get("guardian", false):
		var st := float(u.get("stage", 2))
		return {"hp": GUARDIAN_HP_PER_STAGE * st, "atk": GUARDIAN_ATK * (1.0 + GUARDIAN_ATK_PER_STAGE * st), "as": 0.6,
			"def": 40.0, "mdef": 40.0, "mana_max": 140.0, "range": 2.0, "spell_base": GUARDIAN_ATK * st}
	if u.has("monster"):
		var m: Dictionary = MONSTER_BASE.get(String(u.monster), MONSTER_BASE.sbire)
		var out := m.duplicate()
		out["spell_base"] = float(m.atk) * BASE_SPELL
		return out
	var id := String(u.get("id", ""))
	var d := AutochessData.unit(id)
	var stars := int(u.get("stars", 1))
	var cost := int(u.get("cost", d.get("cost", 1)))
	var mult := AutochessData.stat_mult(cost, stars)
	var r: Dictionary = ROLE_BASE.get(String(d.get("role", "combattant")), ROLE_BASE.combattant)
	var atk := BASE_ATK * float(r.atk) * mult
	return {"hp": BASE_HP * float(r.hp) * mult, "atk": atk, "as": float(r.as), "def": float(r.def), "mdef": float(r.mdef),
		"crit": 0.05, "mana_max": float(d.get("mana", 80)), "range": float(d.get("range", 1)),
		"spell_base": atk * BASE_SPELL * AutochessData.spell_mult(stars)}


## Position (m) d'une case, plateau centré en 0 : camp 0 côté y négatif, camp 1 en miroir ; rangée 0 = front.
static func cell_pos(side: int, col: int, row: int) -> Vector2:
	var x := (float(col) - 3.0) * AutochessData.CELL + (AutochessData.CELL * 0.5 if row % 2 == 1 else 0.0)
	var y := (float(row) + 0.5) * AutochessData.CELL * 0.866
	return Vector2(x, -y if side == 0 else y)


## Compte des traits d'un camp d'après ses unités (une unité par trait) : quand le ctx d'AC-B n'en donne pas.
static func count_traits(ctx: Dictionary, side: int) -> Dictionary:
	var sets := {}
	for fid in ctx.sides[side]:
		var u: Dictionary = ctx.units[fid]
		for t in u.traits:
			if not sets.has(t):
				sets[t] = {}
			sets[t][u.id] = true
	var out := {}
	for t in sets:
		out[t] = (sets[t] as Dictionary).size()
	return out


# --- Fiche ---------------------------------------------------------------------------------------------------------
## Fiche finale d'une unité du contexte (base + objets + traits + atouts + gardien) : accumulation additive des bonus
## (même résultat quel que soit l'ordre des objets), puis un seul calcul et les bornes CAPS.
static func apply_stats(unit: Dictionary, ctx: Dictionary) -> Dictionary:
	var b: Dictionary = unit.base
	var acc := {}
	for k in STAT_ACC_KEYS:
		acc[k] = 0.0
	AutochessTraits.stat_mods(unit, ctx, acc)
	AutochessItems.stat_mods(unit, ctx, acc)
	AutochessAugments.stat_mods(unit, ctx, acc)
	if unit.get("guardian", false) and float(unit.get("mult", 1.0)) != 1.0:  # Menace : gardien × 2
		acc["hp_pct"] += float(unit.mult) - 1.0
		acc["atk_pct"] += float(unit.mult) - 1.0
	var s := b.duplicate()
	s["hp"] = maxf(1.0, (float(b.hp) + acc.hp) * (1.0 + _cap("hp_pct", acc.hp_pct)))
	s["atk"] = maxf(0.0, float(b.atk) * (1.0 + _cap("atk_pct", acc.atk_pct)))
	s["as"] = _cap("as", float(b.as) * (1.0 + _cap("as_pct", acc.as_pct)))
	s["spell_power"] = maxf(0.1, float(b.spell_power) * (1.0 + _cap("spell_pct", acc.spell_pct)))
	s["mana_max"] = clampf(float(b.mana_max) * (1.0 + _cap("mana_max_pct", acc.mana_max_pct)), 10.0,
		float(AutochessData.MANA_MAX))
	s["mana_start"] = clampf(float(b.mana_start) + acc.mana_start, 0.0, s.mana_max)
	for k in ["def", "mdef"]:
		s[k] = _cap(k, float(b[k]) + acc[k])
	for k in ["crit", "crit_dmg", "dodge", "parry", "armor_pen", "range", "scale"]:
		s[k] = _cap(k, float(b[k]) + acc[k])
	s["dmg_taken"] = _cap("dmg_taken", float(b.dmg_taken) + acc.dmg_taken)
	s["heal_taken"] = _cap("heal_taken", float(b.heal_taken) + acc.heal_taken)
	return s


static func _cap(key: String, v: float) -> float:
	var c: Array = CAPS.get(key, [])
	if c.is_empty() or is_nan(v):
		return 0.0 if is_nan(v) else v
	return clampf(v, float(c[0]), float(c[1]))


# --- Lecture -------------------------------------------------------------------------------------------------------
static func unit(ctx: Dictionary, fid: int) -> Dictionary:
	return ctx.units.get(fid, {})


static func alive(ctx: Dictionary, fid: int) -> bool:
	return bool(unit(ctx, fid).get("alive", false))


static func hp(ctx: Dictionary, fid: int) -> float:
	return float(unit(ctx, fid).get("hp", 0.0))


static func hp_max(ctx: Dictionary, fid: int) -> float:
	return float(unit(ctx, fid).get("hp_max", 1.0))


static func hp_frac(u: Dictionary) -> float:
	return float(u.hp) / maxf(float(u.hp_max), 1.0)


static func mana(ctx: Dictionary, fid: int) -> float:
	return float(unit(ctx, fid).get("mana", 0.0))


## Étourdie, gelée ou renversée : ni attaque, ni sort, ni déplacement.
static func disabled(ctx: Dictionary, fid: int) -> bool:
	return float(unit(ctx, fid).get("cc_until", 0.0)) > float(ctx.t)


## Valeur du moment d'une statistique : fiche + bonus temporaires (« atk », « as », « def », « mdef », « dodge », « move »
## en tiennent compte ; « range » en cases ; les autres = fiche).
static func stat(ctx: Dictionary, fid: int, key: String) -> float:
	var u := unit(ctx, fid)
	if u.is_empty():
		return 0.0
	var s: Dictionary = u.sheet
	match key:
		"atk":
			return maxf(0.0, float(s.atk) * (1.0 + _cap("atk_pct", _mod_sum(ctx, u, "atk_pct"))))
		"as":
			return _cap("as", float(s.as) * (1.0 + _cap("as_pct", _mod_sum(ctx, u, "as_pct"))))
		"def", "mdef":
			return maxf(0.0, float(s[key]) * (1.0 + maxf(-0.9, _mod_sum(ctx, u, "def_pct"))))
		"dodge":
			return _cap("dodge", float(s.dodge) + _mod_sum(ctx, u, "dodge"))
		"move":
			return _cap("move", float(s.move) * (1.0 + _mod_sum(ctx, u, "move_pct")))
		"reach":
			return AutochessData.reach_m(int(round(float(s.range))))
	return float(s.get(key, 0.0))


static func _mod_sum(ctx: Dictionary, u: Dictionary, key: String) -> float:
	var t := float(ctx.t)
	var v := 0.0
	for m in u.mods:
		if m.stat == key and (float(m.until) < 0.0 or float(m.until) > t):
			v += float(m.value)
	return v


static func set_pos(ctx: Dictionary, fid: int, pos: Vector2) -> void:
	if ctx.units.has(fid):
		ctx.units[fid]["pos"] = pos


static func dist(ctx: Dictionary, a: int, b: int) -> float:
	return (unit(ctx, a).pos as Vector2).distance_to(unit(ctx, b).pos)


static func living(ctx: Dictionary, side: int) -> Array:
	return (ctx.sides[side] as Array).filter(func(f): return bool(ctx.units[f].alive))


## Ennemis vivants de [param side] (ou alliés : [param allies]) triés par distance à [param pos], puis par fid.
static func near(ctx: Dictionary, side: int, pos: Vector2, radius_m := INF, exclude: Array = [], allies := false) -> Array:
	var other := side if allies else 1 - side
	var out: Array = []
	for f in living(ctx, other):
		if f in exclude:
			continue
		var d := (ctx.units[f].pos as Vector2).distance_to(pos)
		if d <= radius_m + 0.001:
			out.append([d, f])
	out.sort_custom(func(x, y): return x[0] < y[0] or (x[0] == y[0] and x[1] < y[1]))
	return out.map(func(x): return x[1])


## Résultat au format du combat injecté d'AC-B : {winner 0 / 1 / -1, stars, duration, gold}.
static func result(ctx: Dictionary) -> Dictionary:
	var alive_s := [living(ctx, 0), living(ctx, 1)]
	var winner := -1
	if not alive_s[0].is_empty() and alive_s[1].is_empty():
		winner = 0
	elif alive_s[0].is_empty() and not alive_s[1].is_empty():
		winner = 1
	var stars := [[], []]
	for side in 2:
		for f in alive_s[side]:
			stars[side].append(int(ctx.units[f].stars))
	return {"winner": winner, "stars": stars, "duration": float(ctx.t), "gold": (ctx.gold as Array).duplicate()}


# --- Appels du moteur ----------------------------------------------------------------------------------------------
## Déclencheur générique (TRIGGERS) : « debut_combat », « temps », « attaque »… ; [param event] : src, dst et le reste
## selon le déclencheur. Les déclencheurs de partie (achat, debut_manche, immediat, gardien) sont joués par Autochess
## (AC-B) : ici ils ne font rien. Rend les effets produits.
static func on_trigger(trigger: String, event: Dictionary, ctx: Dictionary) -> Array:
	var outer := _begin(ctx)
	_fire(ctx, trigger, event)
	return _end(ctx, outer)


## Début du combat (« debut_combat ») : boucliers, gel de départ, sauts des Ombre, Ordre de bataille…
static func start(ctx: Dictionary) -> Array:
	if ctx.started:
		return []
	ctx["started"] = true
	var outer := _begin(ctx)
	_fire(ctx, "debut_combat", {})
	return _end(ctx, outer)


## Avance le temps de [param dt] s : fin des bonus, impulsions (brûlures, saignements, zones, Chœur), « temps ».
static func tick(ctx: Dictionary, dt: float) -> Array:
	var outer := _begin(ctx)
	ctx["t"] = float(ctx.t) + clampf(dt, 0.0, 1.0)
	var n := 0
	while float(ctx.t) + 0.0001 >= float(ctx.pulse_next) and n < MAX_PULSES_PER_TICK:
		_pulse(ctx)
		ctx["pulse_next"] = float(ctx.pulse_next) + PULSE
		n += 1
	if n >= MAX_PULSES_PER_TICK:
		ctx["pulse_next"] = float(ctx.t) + PULSE
	_fire(ctx, "temps", {"t": ctx.t, "dt": dt})
	_cleanup(ctx)
	return _end(ctx, outer)


## Une auto-attaque de [param src] touche [param dst] (au moment de l'impact) : mana, esquive, parade, critique, dégâts,
## puis les effets « attaque » (vol de vie, éclairs, étourdissements…).
static func attack(ctx: Dictionary, src: int, dst: int) -> Array:
	var outer := _begin(ctx)
	var a := unit(ctx, src)
	var d := unit(ctx, dst)
	if a.is_empty() or d.is_empty() or not a.alive or not d.alive or a.side == d.side:
		return _end(ctx, outer)
	a.st["attacks"] = int(a.st.attacks) + 1
	a.stats["attacks"] += 1
	gain_mana(ctx, src, AutochessData.MANA_PER_ATTACK, "attaque")
	var hit := new_hit(ctx, src, dst, stat(ctx, src, "atk"), "phys", "attaque")
	hit["attack"] = true
	_pre_hit(ctx, hit)
	var res := resolve(ctx, hit)
	if res.landed:
		_fire(ctx, "attaque", {"src": src, "dst": dst, "dealt": res.dealt, "crit": res.crit, "hit": hit})
	return _end(ctx, outer)


## Mana nécessaire au prochain sort (Ordre de bataille : le 1er à mi-mana).
static func mana_needed(ctx: Dictionary, fid: int) -> float:
	var u := unit(ctx, fid)
	return float(u.sheet.mana_max) * AutochessAugments.mana_factor(u, ctx) if not u.is_empty() else INF


static func can_cast(ctx: Dictionary, fid: int) -> bool:
	var u := unit(ctx, fid)
	return not u.is_empty() and u.alive and not disabled(ctx, fid) and float(u.mana) + 0.001 >= mana_needed(ctx, fid)


## Le sort signature part (« sort ») : mana à 0, effets de lancement (bouclier, soin, renversement, double sort).
## Le moteur résout ensuite le sort lui-même par spell_hit / spell_heal ; un effet « recast » = le relancer sans mana.
static func cast(ctx: Dictionary, fid: int) -> Array:
	var outer := _begin(ctx)
	if can_cast(ctx, fid):
		var u := unit(ctx, fid)
		var first := int(u.st.casts) == 0
		u["mana"] = 0.0
		u.st["casts"] = int(u.st.casts) + 1
		u.st["zone_cast"] = -1
		u.stats["casts"] += 1
		_fire(ctx, "sort", {"src": fid, "first": first})
	return _end(ctx, outer)


## Dégâts d'un sort de [param src] sur [param dst] : [param base] = dégâts de base (rang compris ; 0 : fiche
## « spell_base »), × puissance des sorts ; opts : kind (« magic » par défaut, « phys », « true »), can_crit.
static func spell_hit(ctx: Dictionary, src: int, dst: int, base := 0.0, opts := {}) -> Array:
	var outer := _begin(ctx)
	var a := unit(ctx, src)
	var d := unit(ctx, dst)
	if a.is_empty() or d.is_empty() or not d.alive or a.side == d.side:
		return _end(ctx, outer)
	var amount := (base if base > 0.0 else float(a.sheet.spell_base)) * float(a.sheet.spell_power)
	var hit := new_hit(ctx, src, dst, amount, String(opts.get("kind", "magic")), "sort")
	hit["spell"] = true
	hit["can_crit"] = bool(opts.get("can_crit", false))
	_pre_hit(ctx, hit)
	var res := resolve(ctx, hit)
	if res.landed:
		a.stats["dealt_spell"] += res.dealt
		_fire(ctx, "sort_impact", {"src": src, "dst": dst, "dealt": res.dealt, "crit": res.crit, "hit": hit})
	return _end(ctx, outer)


## Soin d'un sort de [param src] sur l'allié [param dst] ([param base] × puissance des sorts).
static func spell_heal(ctx: Dictionary, src: int, dst: int, base: float) -> Array:
	var outer := _begin(ctx)
	var a := unit(ctx, src)
	if not a.is_empty():
		heal(ctx, src, dst, base * float(a.sheet.spell_power), "sort")
	return _end(ctx, outer)


## Contrôle venu du moteur (sort, gardien) : refusé pendant une insensibilité (Brute). Rend vrai s'il est posé.
static func apply_cc(ctx: Dictionary, src: int, dst: int, kind: String, dur: float) -> bool:
	var outer := _begin(ctx)
	var ok := cc(ctx, src, dst, kind, dur, "moteur")
	_end(ctx, outer)
	return ok


## Dégâts directs venus du moteur (mécanique de gardien, zone d'un sort) : même résolution qu'un coup.
static func damage(ctx: Dictionary, src: int, dst: int, amount: float, opts := {}) -> Array:
	var outer := _begin(ctx)
	if alive(ctx, dst):
		var hit := new_hit(ctx, src, dst, amount, String(opts.get("kind", "magic")), String(opts.get("tag", "moteur")))
		hit["proc"] = bool(opts.get("proc", false))
		hit["can_crit"] = bool(opts.get("can_crit", false))
		resolve(ctx, hit)
	return _end(ctx, outer)


## Multiplicateur des soins reçus par [param fid] en ce moment (soins du moteur : déjà compris dans heal()).
static func heal_mult(ctx: Dictionary, fid: int) -> float:
	var u := unit(ctx, fid)
	if u.is_empty():
		return 0.0
	var cut := 0.0
	for c in u.cuts:
		if float(c.until) > float(ctx.t):
			cut = maxf(cut, float(c.value))
	var m := float(u.sheet.heal_taken) * (1.0 - _cap("heal_cut", cut))
	if ctx.rules.fury and float(ctx.t) >= AutochessData.SUDDEN_AT:
		m *= AutochessData.FURY_HEAL_MULT
	return maxf(0.0, m)


## Fureur (mort subite) : dégâts +50 % à 30 s, puis encore +50 % toutes les 5 s.
static func fury_mult(t: float) -> float:
	if t < AutochessData.SUDDEN_AT:
		return 1.0
	return 1.0 + AutochessData.FURY_DAMAGE * (1.0 + floorf((t - AutochessData.SUDDEN_AT) / AutochessData.FURY_STEP))


# --- Résolution (utilisée aussi par les modules) -------------------------------------------------------------------
## Un coup en préparation : les modules le modifient (mult, chances, pénétration) avant resolve().
static func new_hit(ctx: Dictionary, src: int, dst: int, base: float, kind: String, tag: String) -> Dictionary:
	var a := unit(ctx, src)
	var s: Dictionary = a.get("sheet", BASE_DEFAULTS)
	return {"src": src, "dst": dst, "base": maxf(0.0, base), "mult": 1.0, "kind": kind, "tag": tag, "attack": false,
		"spell": false, "proc": false, "can_crit": true, "crit_chance": float(s.get("crit", 0.0)),
		"crit_dmg": float(s.get("crit_dmg", 0.5)), "pen": float(s.get("armor_pen", 0.0)), "no_cap": false}


## Résout un coup préparé : esquive et parade (attaques seulement), critique, défense, dégâts reçus, Fureur, plafond de
## 20 % des PV max (hors gardiens), puis dégâts. Rend {landed, dealt, crit}.
static func resolve(ctx: Dictionary, hit: Dictionary) -> Dictionary:
	var out := {"landed": false, "dealt": 0.0, "crit": false}
	var src := int(hit.src)
	var dst := int(hit.dst)
	var a := unit(ctx, src)
	var d := unit(ctx, dst)
	if d.is_empty() or not d.alive:
		return out
	if hit.attack and not hit.proc:
		if _roll(ctx, stat(ctx, dst, "dodge")):
			d.stats["dodges"] += 1
			emit(ctx, {"type": "dodge", "src": src, "dst": dst})
			_fire(ctx, "esquive", {"src": dst, "dst": src, "hit": hit})
			return out
		if _roll(ctx, float(d.sheet.parry)):
			d.stats["parries"] += 1
			emit(ctx, {"type": "parry", "src": src, "dst": dst})
			AutochessTraits.on_parry(ctx, dst, src)
			return out
	var amount := float(hit.base) * maxf(0.0, float(hit.mult))
	if hit.can_crit and _roll(ctx, _cap("crit", float(hit.crit_chance))):
		out["crit"] = true
		amount *= 1.0 + _cap("crit_dmg", float(hit.crit_dmg))
	if hit.kind != "true":
		var defense := stat(ctx, dst, "mdef" if hit.kind == "magic" else "def") * (1.0 - _cap("armor_pen", float(hit.pen)))
		amount *= DEF_SCALE / (DEF_SCALE + maxf(0.0, defense))
	amount *= float(d.sheet.dmg_taken)
	if ctx.rules.fury:
		amount *= fury_mult(float(ctx.t))
	var guardian_hit: bool = (not a.is_empty() and a.guardian) or d.guardian
	if ctx.rules.hit_cap and not guardian_hit and not hit.no_cap:
		amount = minf(amount, AutochessData.HIT_CAP * float(d.hp_max))
	out["landed"] = true
	if out.crit and not a.is_empty():
		a.stats["crits"] += 1
	hit["crit_hit"] = out.crit  # (lot ACX-2 : l'événement « damage » le dit, pour les chiffres du combat montré)
	out["dealt"] = deal(ctx, src, dst, amount, hit)
	if hit.attack and not hit.proc and not a.is_empty():
		a.stats["dealt_attack"] += float(out.dealt)
	if out.crit and not a.is_empty() and a.alive:
		_fire(ctx, "critique", {"src": src, "dst": dst, "hit": hit})
	return out


## Retire [param amount] PV (après défense) : invulnérabilité, boucliers, mana gagnée par les PV perdus, puis
## « coup_recu », « seuil_pv » et, à 0 PV, « chute », « elimination », « chute_allie ». Rend les PV retirés.
static func deal(ctx: Dictionary, src: int, dst: int, amount: float, hit: Dictionary) -> float:
	var d := unit(ctx, dst)
	var a := unit(ctx, src)
	if d.is_empty() or not d.alive or is_nan(amount) or amount <= 0.0:
		return 0.0
	if float(d.invuln_until) > float(ctx.t):
		d.stats["blocked"] += amount
		return 0.0
	var left := amount
	for sh in d.shields:
		if left <= 0.0:
			break
		if float(sh.until) <= float(ctx.t):
			continue
		var take := minf(float(sh.amount), left)
		sh["amount"] = float(sh.amount) - take
		left -= take
		d.stats["blocked"] += take
	var lost := minf(left, float(d.hp))
	if hit.get("execute", false):
		lost = float(d.hp)
	var before := hp_frac(d)
	d["hp"] = float(d.hp) - lost
	d.stats["taken"] += lost
	if not a.is_empty():
		a.stats["dealt"] += lost
		a.stats["hits"] += 1
		if hit.proc:
			a.stats["dealt_proc"] += lost
		if String(hit.tag) == "zone":
			a.stats["zone_dealt"] += lost
	emit(ctx, {"type": "damage", "src": src, "dst": dst, "amount": lost, "kind": hit.kind, "tag": hit.tag,
		"proc": hit.proc, "crit": bool(hit.get("crit_hit", false))})
	if lost > 0.0:
		var pct := lost / maxf(float(d.hp_max), 1.0) * 100.0
		gain_mana(ctx, dst, minf(pct * AutochessData.MANA_PER_HP_PCT, AutochessData.MANA_PER_HIT_CAP), "coup")
	if float(d.hp) <= 0.0001:
		_kill(ctx, src, dst)
		return lost
	_fire(ctx, "coup_recu", {"src": src, "dst": dst, "dealt": lost, "kind": hit.kind, "proc": hit.proc, "hit": hit})
	if d.alive and hp_frac(d) < before:
		_fire(ctx, "seuil_pv", {"dst": dst, "before": before, "frac": hp_frac(d)})
	return lost


static func _kill(ctx: Dictionary, src: int, dst: int) -> void:
	var d := unit(ctx, dst)
	d["hp"] = 0.0
	d["alive"] = false
	d["mana"] = 0.0
	emit(ctx, {"type": "death", "src": src, "dst": dst})
	_fire(ctx, "chute", {"src": src, "dst": dst})
	var a := unit(ctx, src)
	if not a.is_empty() and a.side != d.side:
		a.stats["kills"] += 1
		_fire(ctx, "elimination", {"src": src, "dst": dst})
	_fire(ctx, "chute_allie", {"src": src, "dst": dst, "side": d.side})


## Soin (× soins reçus, coupures de soin, Fureur), borné aux PV manquants. Rend les PV rendus.
static func heal(ctx: Dictionary, src: int, dst: int, amount: float, tag: String) -> float:
	var d := unit(ctx, dst)
	if d.is_empty() or not d.alive or amount <= 0.0 or is_nan(amount):
		return 0.0
	var v := minf(amount * heal_mult(ctx, dst), float(d.hp_max) - float(d.hp))
	if v <= 0.0:
		return 0.0
	d["hp"] = float(d.hp) + v
	d.stats["healed"] += v
	var a := unit(ctx, src)
	if not a.is_empty():
		a.stats["heal_done"] += v
	emit(ctx, {"type": "heal", "src": src, "dst": dst, "amount": v, "tag": tag})
	return v


static func shield(ctx: Dictionary, dst: int, amount: float, dur: float, tag: String) -> void:
	var d := unit(ctx, dst)
	if d.is_empty() or not d.alive or amount <= 0.0:
		return
	d.shields.append({"amount": amount, "until": float(ctx.t) + dur, "tag": tag})
	d.stats["shielded"] += amount
	emit(ctx, {"type": "shield", "dst": dst, "amount": amount, "dur": dur, "tag": tag})


## Mana (négative : retirée), bornée entre 0 et la mana max.
static func gain_mana(ctx: Dictionary, fid: int, amount: float, tag: String) -> void:
	var u := unit(ctx, fid)
	if u.is_empty() or not u.alive or amount == 0.0 or is_nan(amount):
		return
	var before := float(u.mana)
	u["mana"] = clampf(before + amount, 0.0, float(u.sheet.mana_max))
	var v := float(u.mana) - before
	if v > 0.0:
		u.stats["mana_gained"] += v
	elif v < 0.0:
		u.stats["mana_lost"] += -v
	if tag != "attaque" and tag != "coup" and v != 0.0:
		emit(ctx, {"type": "mana", "dst": fid, "amount": v, "tag": tag})


## Contrôle (stun, freeze, knockup) : refusé si la cible est insensible (Brute) ; prend la plus longue des durées.
static func cc(ctx: Dictionary, src: int, dst: int, kind: String, dur: float, tag: String) -> bool:
	var d := unit(ctx, dst)
	if d.is_empty() or not d.alive or dur <= 0.0 or float(d.immune_until) > float(ctx.t):
		return false
	d["cc_until"] = maxf(float(d.cc_until), float(ctx.t) + dur)
	d["cc_kind"] = kind
	d.stats["cc_taken"] += 1
	var a := unit(ctx, src)
	if not a.is_empty():
		a.stats["cc_done"] += 1
	emit(ctx, {"type": "cc", "src": src, "dst": dst, "kind": kind, "dur": dur, "tag": tag})
	return true


## Bonus ou malus de statistique (« atk_pct », « as_pct », « def_pct », « dodge », « move_pct ») ; [param dur] < 0 :
## pour tout le combat ; [param id] non vide : remplace le précédent de même id (pas de cumul d'un même effet).
static func add_mod(ctx: Dictionary, fid: int, stat_key: String, value: float, dur: float, id := "") -> void:
	var u := unit(ctx, fid)
	if u.is_empty() or not u.alive:
		return
	if id != "":
		u["mods"] = (u.mods as Array).filter(func(m): return String(m.id) != id)
	u.mods.append({"stat": stat_key, "value": value, "until": (float(ctx.t) + dur) if dur >= 0.0 else -1.0, "id": id})
	emit(ctx, {"type": "buff", "dst": fid, "stat": stat_key, "value": value, "dur": dur, "tag": id})


## Brûlure / saignement : [param dps] PV par seconde pendant [param dur] s (dégâts bruts, par impulsions) ; même [param
## tag] et même source : rafraîchi, pas cumulé.
static func dot(ctx: Dictionary, src: int, dst: int, dps: float, dur: float, tag: String) -> void:
	var d := unit(ctx, dst)
	if d.is_empty() or not d.alive or dps <= 0.0:
		return
	d["dots"] = (d.dots as Array).filter(func(x): return not (String(x.tag) == tag and int(x.src) == src))
	d.dots.append({"src": src, "dps": dps, "until": float(ctx.t) + dur, "tag": tag})


## Coupure de soin (la plus forte du moment compte, pas de cumul).
static func cut_heal(ctx: Dictionary, dst: int, value: float, dur: float) -> void:
	var d := unit(ctx, dst)
	if not d.is_empty() and d.alive:
		d.cuts.append({"value": value, "until": float(ctx.t) + dur})


## Zone au sol d'un camp : [param dps] aux ennemis de [param src] à [param radius_m] de [param pos] pendant [param dur].
static func zone(ctx: Dictionary, src: int, pos: Vector2, radius_m: float, dps: float, dur: float, slow: bool) -> void:
	var a := unit(ctx, src)
	if a.is_empty() or dps <= 0.0:
		return
	ctx.zones.append({"src": src, "side": a.side, "pos": pos, "radius": radius_m, "dps": dps, "until": float(ctx.t) + dur,
		"slow": slow})
	emit(ctx, {"type": "zone", "src": src, "pos": pos, "radius": radius_m, "dps": dps, "dur": dur, "slow": slow})


static func invuln(ctx: Dictionary, fid: int, dur: float) -> void:
	var u := unit(ctx, fid)
	if not u.is_empty() and u.alive:
		u["invuln_until"] = maxf(float(u.invuln_until), float(ctx.t) + dur)
		emit(ctx, {"type": "invuln", "dst": fid, "dur": dur})


## Coup secondaire (« proc ») de [param src] sur [param dst] : sans esquive, sans relancer les effets d'attaque.
static func proc_hit(ctx: Dictionary, src: int, dst: int, amount: float, kind: String, tag: String, can_crit := false) -> float:
	if not alive(ctx, dst):
		return 0.0
	var hit := new_hit(ctx, src, dst, amount, kind, tag)
	hit["proc"] = true
	hit["can_crit"] = can_crit
	return float(resolve(ctx, hit).dealt)


## Enregistre un effet (journal de l'appel en cours ; ctx.log si keep_log). Rend faux au-delà du budget.
static func emit(ctx: Dictionary, e: Dictionary) -> bool:
	if int(ctx.budget) >= MAX_EFFECTS_PER_CALL:
		ctx["dropped"] = int(ctx.dropped) + 1
		return false
	ctx["budget"] = int(ctx.budget) + 1
	e["t"] = ctx.t
	ctx.journal.append(e)
	if ctx.keep_log:
		ctx.log.append(e)
	return true


static func over_budget(ctx: Dictionary) -> bool:
	return int(ctx.budget) >= MAX_EFFECTS_PER_CALL


# --- Interne -------------------------------------------------------------------------------------------------------
static func _begin(ctx: Dictionary) -> int:
	var outer := int(ctx.journal.size()) if int(ctx.depth) > 0 else -1
	if outer < 0:
		ctx["journal"] = []
		ctx["budget"] = 0
	return outer


static func _end(ctx: Dictionary, outer: int) -> Array:
	if outer >= 0:
		return (ctx.journal as Array).slice(outer)
	return (ctx.journal as Array).duplicate()


## Passe un déclencheur aux trois modules (traits, objets, atouts), profondeur bornée.
static func _fire(ctx: Dictionary, trigger: String, ev: Dictionary) -> void:
	if int(ctx.depth) >= MAX_DEPTH or over_budget(ctx):
		return
	ctx["depth"] = int(ctx.depth) + 1
	AutochessTraits.on_event(trigger, ev, ctx)
	AutochessItems.on_event(trigger, ev, ctx)
	AutochessAugments.on_event(trigger, ev, ctx)
	ctx["depth"] = int(ctx.depth) - 1


static func _pre_hit(ctx: Dictionary, hit: Dictionary) -> void:
	AutochessTraits.pre_hit(ctx, hit)
	AutochessItems.pre_hit(ctx, hit)
	AutochessAugments.pre_hit(ctx, hit)


static func _roll(ctx: Dictionary, chance: float) -> bool:
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return (ctx.rng as RandomNumberGenerator).randf() < chance


## Impulsion : brûlures et saignements, zones (et leur ralentissement).
static func _pulse(ctx: Dictionary) -> void:
	var t := float(ctx.t)
	for fid in ctx.units:
		var u: Dictionary = ctx.units[fid]
		if not u.alive:
			continue
		for x in (u.dots as Array).duplicate():
			if float(x.until) + 0.0001 >= t and u.alive:
				var h := new_hit(ctx, int(x.src), int(fid), float(x.dps) * PULSE, "true", String(x.tag))
				h["proc"] = true
				h["can_crit"] = false
				resolve(ctx, h)
	for z in (ctx.zones as Array).duplicate():
		if float(z.until) + 0.0001 < t:
			continue
		for f in near(ctx, int(z.side), z.pos, float(z.radius)):
			var h := new_hit(ctx, int(z.src), int(f), float(z.dps) * PULSE, "magic", "zone")
			h["proc"] = true
			h["can_crit"] = false
			resolve(ctx, h)
			if z.slow:
				add_mod(ctx, int(f), "move_pct", SLOW_MOVE, SLOW_DUR, "zone_lente")
	AutochessTraits.pulse(ctx)
	AutochessItems.pulse(ctx)


static func _cleanup(ctx: Dictionary) -> void:
	var t := float(ctx.t)
	ctx["zones"] = (ctx.zones as Array).filter(func(z): return float(z.until) + 0.0001 >= t)
	for fid in ctx.units:
		var u: Dictionary = ctx.units[fid]
		u["mods"] = (u.mods as Array).filter(func(m): return float(m.until) < 0.0 or float(m.until) > t)
		u["shields"] = (u.shields as Array).filter(func(s): return float(s.until) > t and float(s.amount) > 0.0)
		u["dots"] = (u.dots as Array).filter(func(x): return float(x.until) + 0.0001 >= t)
		u["cuts"] = (u.cuts as Array).filter(func(c): return float(c.until) > t)
