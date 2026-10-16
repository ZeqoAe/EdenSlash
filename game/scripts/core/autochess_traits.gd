class_name AutochessTraits
extends RefCounted
## L'Échiquier, lot AC-H : effets des 15 traits (AutochessData.TRAITS, clé « effect » = trait_<id>, paramètres du palier
## atteint dans « tiers »). Appelé par AutochessEffects (couche pure, aucun nœud) ; rapport : conception/autochess/R_AC_H.md.
## Palier d'un camp : ctx.tiers[camp][trait] (compte d'AC-B : Cœur de famille, Double trait et emblèmes compris).
## Portée (« scope ») : « porteurs » = unités qui ont le trait ; « equipe » = tout le camp ; « ennemis » = le camp adverse.
## Ordre fixe : traits triés par clé (TRAITS), toujours le même.

const MALEDICTION_ID := "malediction"
const POUDRE_TAG := "poudre"
const PIERCE_AHEAD := 2.0  # cases : une flèche qui traverse touche l'ennemi suivant à 2 cases au plus derrière la cible
const PIERCE_SIDE := 0.6  # cases d'écart latéral au plus
const ZONE_RADIUS := 1.0  # case : rayon de la zone laissée par un sort Élémentaire


## Paramètres du palier du trait [param tid] dont profite l'unité ({} : aucun).
static func params(ctx: Dictionary, u: Dictionary, tid: String) -> Dictionary:
	var tier := int(ctx.tiers[int(u.side)].get(tid, 0))
	if tier <= 0:
		return {}
	var tr: Dictionary = AutochessData.TRAITS[tid]
	if String(tr.scope) == "porteurs" and not tid in u.traits:
		return {}
	if String(tr.scope) == "ennemis":
		return {}
	return (tr.tiers as Array)[tier - 1]


## Paramètres du palier d'un camp (pour les traits de camp : Ferveur, Chœur, Malédiction).
static func side_params(ctx: Dictionary, side: int, tid: String) -> Dictionary:
	var tier := int(ctx.tiers[side].get(tid, 0))
	return {} if tier <= 0 else (AutochessData.TRAITS[tid].tiers as Array)[tier - 1]


# --- Fiche ---------------------------------------------------------------------------------------------------------
static func stat_mods(u: Dictionary, ctx: Dictionary, acc: Dictionary) -> void:
	if u.guardian or String(u.monster) != "":
		return
	var p := params(ctx, u, "rempart")
	if not p.is_empty():
		acc["def"] += float(p.def)
	var team := side_params(ctx, int(u.side), "rempart")  # à 9 : PV de toute l'équipe
	if team.has("team_hp_pct"):
		acc["hp_pct"] += float(team.team_hp_pct)
	p = params(ctx, u, "ombre")
	if not p.is_empty():
		acc["crit_dmg"] += float(p.crit_dmg)
	p = params(ctx, u, "traque")
	if not p.is_empty():
		acc["range"] += float(p.get("range", 0))
	p = side_params(ctx, int(u.side), "ferveur")
	if p.has("heal_taken_pct"):
		acc["heal_taken"] += float(p.heal_taken_pct)
	p = params(ctx, u, "arcane")
	if not p.is_empty():
		acc["spell_pct"] += float(p.spell_pct)
	p = params(ctx, u, "escrime")
	if not p.is_empty():
		acc["parry"] += float(p.parry)
	p = params(ctx, u, "estoc")
	if not p.is_empty():
		acc["armor_pen"] += float(p.armor_pen)


# --- Coups ---------------------------------------------------------------------------------------------------------
## Avant un coup de l'attaquant : Traque (cible lointaine), Impact (même cible).
static func pre_hit(ctx: Dictionary, hit: Dictionary) -> void:
	if not hit.attack or hit.proc:
		return
	var a := AutochessEffects.unit(ctx, int(hit.src))
	if a.is_empty():
		return
	var p := params(ctx, a, "traque")
	if not p.is_empty() and AutochessEffects.dist(ctx, int(hit.src), int(hit.dst)) > float(p.far_cells) * AutochessData.CELL:
		hit["mult"] = float(hit.mult) + float(p.atk_pct)
	p = params(ctx, a, "impact")
	if not p.is_empty() and int(a.st.get("impact_target", -1)) == int(hit.dst):
		hit["mult"] = float(hit.mult) + float(p.stack_pct) * float(a.st.get("impact_stacks", 0))


## Parade réussie d'un Escrime : riposte à 80 % de sa frappe (dégâts « proc » : rien ne se relance).
static func on_parry(ctx: Dictionary, parrier: int, attacker: int) -> void:
	var u := AutochessEffects.unit(ctx, parrier)
	var p := params(ctx, u, "escrime")
	if p.is_empty() or not u.alive:
		return
	AutochessEffects.proc_hit(ctx, parrier, attacker, AutochessEffects.stat(ctx, parrier, "atk") * float(p.riposte), "phys", "riposte")


# --- Déclencheurs --------------------------------------------------------------------------------------------------
static func on_event(trigger: String, ev: Dictionary, ctx: Dictionary) -> void:
	match trigger:
		"debut_combat":
			for fid in _sorted_units(ctx):
				var u: Dictionary = ctx.units[fid]
				if not params(ctx, u, "ombre").is_empty():
					AutochessEffects.emit(ctx, {"type": "leap", "src": fid, "to": "arriere"})
		"temps":
			_on_time(ctx)
		"attaque":
			_after_attack(ctx, ev)
		"sort":
			var u := AutochessEffects.unit(ctx, int(ev.src))
			var p := params(ctx, u, "arcane")
			if p.has("double_first") and ev.get("first", false):
				AutochessEffects.emit(ctx, {"type": "recast", "src": int(ev.src), "tag": "arcane"})
		"sort_impact":
			_spell_zone(ctx, ev)


static func _on_time(ctx: Dictionary) -> void:
	var t := float(ctx.t)
	for side in 2:
		var team: Dictionary = ctx.team[side]
		# Tir : vitesse d'attaque après 3 s
		var tir := side_params(ctx, side, "tir")
		if not tir.is_empty() and t >= float(tir.after) and not team.get("tir_done", false):
			team["tir_done"] = true
			for fid in AutochessEffects.living(ctx, side):
				if not params(ctx, ctx.units[fid], "tir").is_empty():
					AutochessEffects.add_mod(ctx, fid, "as_pct", float(tir.as_pct), -1.0, "trait_tir")
		# Ferveur : soin de l'allié le plus blessé toutes les 4 s
		var fv := side_params(ctx, side, "ferveur")
		if not fv.is_empty():
			if not team.has("ferveur_next"):
				team["ferveur_next"] = float(fv.every)
			var n := 0
			while t + 0.0001 >= float(team.ferveur_next) and n < 4:
				team["ferveur_next"] = float(team.ferveur_next) + float(fv.every)
				n += 1
				var low := _most_injured(ctx, side)
				if low >= 0:
					AutochessEffects.heal(ctx, -1, low, float(ctx.units[low].hp_max) * float(fv.heal_pct), "ferveur")
		# Malédiction : à 3 s, les ennemis les plus forts perdent attaque et défense
		var md := side_params(ctx, side, MALEDICTION_ID)
		if not md.is_empty() and t >= float(md.at) and not team.get("malediction_done", false):
			team["malediction_done"] = true
			var foes := _strongest(ctx, 1 - side)
			var k := int(md.targets)
			if k > 0:
				foes = foes.slice(0, k)
			for f in foes:
				AutochessEffects.add_mod(ctx, f, "atk_pct", -float(md.down), -1.0, "malediction_atk")
				AutochessEffects.add_mod(ctx, f, "def_pct", -float(md.down), -1.0, "malediction_def")


## Chœur : mana continue de toute l'équipe (par impulsions).
static func pulse(ctx: Dictionary) -> void:
	for side in 2:
		var ch := side_params(ctx, side, "choeur")
		if ch.is_empty():
			continue
		for fid in AutochessEffects.living(ctx, side):
			AutochessEffects.gain_mana(ctx, fid, float(ch.mana_per_s) * AutochessEffects.PULSE, "choeur")


static func _after_attack(ctx: Dictionary, ev: Dictionary) -> void:
	var src := int(ev.src)
	var dst := int(ev.dst)
	var a := AutochessEffects.unit(ctx, src)
	if a.is_empty() or not a.alive:
		return
	# Impact : cumul sur la même cible
	var p := params(ctx, a, "impact")
	if not p.is_empty():
		if int(a.st.get("impact_target", -1)) == dst:
			a.st["impact_stacks"] = mini(int(a.st.get("impact_stacks", 0)) + 1, int(p.max))
		else:
			a.st["impact_target"] = dst
			a.st["impact_stacks"] = 1
	# Fracas : étourdit toutes les N attaques
	p = params(ctx, a, "fracas")
	if not p.is_empty() and int(a.st.attacks) % maxi(1, int(p.every)) == 0:
		AutochessEffects.cc(ctx, src, dst, "stun", float(p.stun), "fracas")
	# Poudre : explosion autour de la cible
	p = params(ctx, a, "poudre")
	if not p.is_empty() and float(ev.dealt) > 0.0:
		var d := AutochessEffects.unit(ctx, dst)
		for f in AutochessEffects.near(ctx, int(a.side), d.pos, float(p.radius) * AutochessData.CELL, [dst]):
			AutochessEffects.proc_hit(ctx, src, f, float(ev.dealt) * float(p.splash), "phys", POUDRE_TAG)
	# Tir à 6 : la flèche traverse (ennemi suivant derrière la cible)
	p = params(ctx, a, "tir")
	if p.has("pierce") and float(ev.dealt) > 0.0:
		var behind := _behind(ctx, src, dst)
		if behind >= 0:
			AutochessEffects.proc_hit(ctx, src, behind, AutochessEffects.stat(ctx, src, "atk"), "phys", "traverse")
	# Tranchant : achève sous le seuil (jamais un gardien)
	p = params(ctx, a, "tranchant")
	if not p.is_empty():
		_execute(ctx, src, dst, float(p.execute_below))


## Achèvement d'une cible sous [param below] de ses PV (ni gardien ni cible invulnérable).
static func _execute(ctx: Dictionary, src: int, dst: int, below: float) -> void:
	var d := AutochessEffects.unit(ctx, dst)
	if d.is_empty() or not d.alive or d.guardian or AutochessEffects.hp_frac(d) >= below:
		return
	var h := AutochessEffects.new_hit(ctx, src, dst, float(d.hp), "true", "acheve")
	h["proc"] = true
	h["can_crit"] = false
	h["no_cap"] = true
	h["execute"] = true
	if AutochessEffects.deal(ctx, src, dst, float(d.hp), h) > 0.0:
		ctx.units[src].stats["executes"] += 1


## Élémentaire : le sort laisse une zone à l'endroit de sa 1re cible (une par sort).
static func _spell_zone(ctx: Dictionary, ev: Dictionary) -> void:
	var src := int(ev.src)
	var a := AutochessEffects.unit(ctx, src)
	var p := params(ctx, a, "elementaire")
	if p.is_empty() or int(a.st.get("zone_cast", -1)) == int(a.st.casts) or float(ev.dealt) <= 0.0:
		return
	a.st["zone_cast"] = int(a.st.casts)
	var zm := AutochessItems.zone_mods(a)
	var d := AutochessEffects.unit(ctx, int(ev.dst))
	AutochessEffects.zone(ctx, src, d.pos, ZONE_RADIUS * AutochessData.CELL * (1.0 + float(zm.radius_pct)),
		float(ev.dealt) * float(p.zone_pct), float(p.dur) + float(zm.dur), p.has("slow"))
	# Tranchant aussi sur les sorts
	var tr := params(ctx, a, "tranchant")
	if not tr.is_empty():
		_execute(ctx, src, int(ev.dst), float(tr.execute_below))


# --- Outils --------------------------------------------------------------------------------------------------------
static func _sorted_units(ctx: Dictionary) -> Array:
	var ids: Array = (ctx.units as Dictionary).keys()
	ids.sort()
	return ids


static func _most_injured(ctx: Dictionary, side: int) -> int:
	var best := -1
	var best_f := 1.0
	for f in AutochessEffects.living(ctx, side):
		var fr := AutochessEffects.hp_frac(ctx.units[f])
		if fr < best_f - 0.0001:
			best = f
			best_f = fr
	return best


## Ennemis du camp [param side] du plus fort au plus faible (PV max × attaque, puis fid).
static func _strongest(ctx: Dictionary, side: int) -> Array:
	var l: Array = []
	for f in AutochessEffects.living(ctx, side):
		var u: Dictionary = ctx.units[f]
		l.append([float(u.hp_max) * float(u.sheet.atk), f])
	l.sort_custom(func(x, y): return x[0] > y[0] or (x[0] == y[0] and x[1] < y[1]))
	return l.map(func(x): return x[1])


## Ennemi suivant derrière la cible, dans l'axe du tir (-1 : aucun).
static func _behind(ctx: Dictionary, src: int, dst: int) -> int:
	var a_pos: Vector2 = ctx.units[src].pos
	var d_pos: Vector2 = ctx.units[dst].pos
	var dir := d_pos - a_pos
	if dir.length() < 0.001:
		return -1
	dir = dir.normalized()
	var best := -1
	var best_d := INF
	for f in AutochessEffects.living(ctx, int(ctx.units[dst].side)):
		if f == dst:
			continue
		var rel: Vector2 = (ctx.units[f].pos as Vector2) - d_pos
		var ahead := rel.dot(dir)
		var lateral := absf(rel.cross(dir))
		if ahead > 0.0 and ahead <= PIERCE_AHEAD * AutochessData.CELL and lateral <= PIERCE_SIDE * AutochessData.CELL \
				and ahead < best_d:
			best = f
			best_d = ahead
	return best
