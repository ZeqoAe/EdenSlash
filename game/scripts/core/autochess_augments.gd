class_name AutochessAugments
extends RefCounted
## L'Échiquier, lot AC-H : effets des atouts (AutochessData.AUGMENTS). Deux familles :
## - atouts de COMBAT (COMBAT_EFFECTS) : appliqués ici, par AutochessEffects (couche pure, aucun nœud), d'après la liste
##   ctx.augments[camp] donnée par AC-B ;
## - atouts de PARTIE (GAME_EFFECTS : or, XP, objets, unités, places, fusion, intérêts, butin) : appliqués par Autochess
##   (AC-B, _take_augment, income_for, buy, _pve_outcome…) ; les deux qui changent les traits (Cœur de famille, Double
##   trait) arrivent au combat par ctx.traits, Menace par la fiche du gardien (« mult »).
## Rapport : conception/autochess/R_AC_H.md.

## Effet -> où il est appliqué.
const COMBAT_EFFECTS := ["stats_equipe", "premier_coup", "soin_equipe", "mana_equipe", "unite_la_plus_chere", "lignee",
	"contre_attaque", "bouclier_avant", "cout_mana", "depart_rapide"]
const GAME_EFFECTS := ["or", "relance_gratuite", "xp", "composant_au_choix", "unites_famille", "plafond_interets",
	"pv_contre_or", "objet", "achat_double", "trait_compte", "butin_gardien", "place_plateau", "unite_au_choix",
	"gardiens_renforces", "or_sans_interets", "niveau_max", "fusion_rapide", "objets_au_choix"]


## « combat » (ce fichier), « partie » (Autochess) ou « les deux » (Menace : butin et gardien plus fort).
static func scope(id: String) -> String:
	var eff := String(AutochessData.augment(id).get("effect", ""))
	if eff == "gardiens_renforces":
		return "les deux"
	if eff in COMBAT_EFFECTS:
		return "combat"
	return "partie" if eff in GAME_EFFECTS else ""


static func with_effect(ctx: Dictionary, side: int, effect: String) -> Array:
	var out: Array = []
	for aid in ctx.augments[side]:
		var a := AutochessData.augment(String(aid))
		if String(a.get("effect", "")) == effect:
			out.append(a)
	return out


static func _units(u: Dictionary) -> bool:
	return not u.guardian and String(u.monster) == ""


# --- Préparation (avant les fiches) --------------------------------------------------------------------------------
## Rôles d'équipe fixés au début : unité la plus chère (Chef de guerre), lignées (Héritage), 2 plus avancées (Garde du
## corps). Départage : coût, étoiles, puis fid ; rangée la plus avancée, puis colonne la plus centrale, puis fid.
static func prepare_team(ctx: Dictionary) -> void:
	for side in 2:
		var team: Dictionary = ctx.team[side]
		var ids: Array = (ctx.sides[side] as Array).filter(func(f): return _units(ctx.units[f]))
		var chief := -1
		for f in ids:
			var u: Dictionary = ctx.units[f]
			if chief < 0:
				chief = f
				continue
			var c: Dictionary = ctx.units[chief]
			if int(u.cost) > int(c.cost) or (int(u.cost) == int(c.cost) and int(u.stars) > int(c.stars)):
				chief = f
		team["chief"] = chief
		var heirs := {}
		for f in ids:
			var u: Dictionary = ctx.units[f]
			var d := AutochessData.unit(String(u.id))
			if String(d.get("lineage", "")) == "verte":
				continue
			var parent := String(d.get("parent", ""))
			for g in ids:
				if String(ctx.units[g].id) == parent and parent != String(u.id):
					heirs[f] = true
					heirs[g] = true
		team["heirs"] = heirs
		var front := ids.duplicate()
		front.sort_custom(func(x, y):
			var a: Dictionary = ctx.units[x]
			var b: Dictionary = ctx.units[y]
			if int(a.row) != int(b.row):
				return int(a.row) < int(b.row)
			var ca := absi(int(a.col) - 3)
			var cb := absi(int(b.col) - 3)
			return ca < cb or (ca == cb and x < y))
		team["front"] = front


# --- Fiche ---------------------------------------------------------------------------------------------------------
static func stat_mods(u: Dictionary, ctx: Dictionary, acc: Dictionary) -> void:
	if not _units(u):
		return
	var side := int(u.side)
	var team: Dictionary = ctx.team[side]
	for aid in ctx.augments[side]:
		var a := AutochessData.augment(String(aid))
		var p: Dictionary = a.get("params", {})
		match String(a.get("effect", "")):
			"stats_equipe":  # Peau dure, Esquive aiguisée
				for k in p:
					if acc.has(k):
						acc[k] = float(acc[k]) + float(p[k])
			"mana_equipe":  # Mana vive
				acc["mana_start"] += float(p.mana)
			"cout_mana":  # Main sûre
				acc["mana_max_pct"] += float(p.mana_max_pct)
			"unite_la_plus_chere":  # Chef de guerre
				if int(team.get("chief", -1)) == int(u.fid):
					acc["hp_pct"] += float(p.hp_pct)
					acc["atk_pct"] += float(p.atk_pct)
			"lignee":  # Héritage
				if (team.get("heirs", {}) as Dictionary).has(int(u.fid)):
					acc["hp_pct"] += float(p.hp_pct)
					acc["atk_pct"] += float(p.atk_pct)


## Mana du prochain sort, en part de la mana max (Ordre de bataille : 1er sort à mi-mana).
static func mana_factor(u: Dictionary, ctx: Dictionary) -> float:
	if int(u.st.get("casts", 0)) > 0 or not _units(u):
		return 1.0
	var f := 1.0
	for a in with_effect(ctx, int(u.side), "depart_rapide"):
		f = minf(f, float(a.params.first_spell_mana))
	return f


static func pre_hit(_ctx: Dictionary, _hit: Dictionary) -> void:
	pass


# --- Déclencheurs --------------------------------------------------------------------------------------------------
static func on_event(trigger: String, ev: Dictionary, ctx: Dictionary) -> void:
	match trigger:
		"debut_combat":
			for side in 2:
				for a in with_effect(ctx, side, "bouclier_avant"):  # Garde du corps
					var p: Dictionary = a.params
					for f in (ctx.team[side].get("front", []) as Array).slice(0, int(p.count)):
						AutochessEffects.shield(ctx, f, float(ctx.units[f].hp_max) * float(p.shield_pct), float(p.dur), "garde_du_corps")
				for a in with_effect(ctx, side, "depart_rapide"):  # Ordre de bataille
					var p: Dictionary = a.params
					for f in AutochessEffects.living(ctx, side):
						if _units(ctx.units[f]):
							AutochessEffects.add_mod(ctx, f, "as_pct", float(p.as_pct), float(p.dur), "ordre_vitesse")
							AutochessEffects.add_mod(ctx, f, "move_pct", float(p.move_pct), float(p.dur), "ordre_pas")
		"attaque":  # Premier sang : la 1re unité du camp à toucher
			var u := AutochessEffects.unit(ctx, int(ev.src))
			if u.is_empty() or float(ev.dealt) <= 0.0:
				return
			var team: Dictionary = ctx.team[int(u.side)]
			if team.get("first_blood", false):
				return
			for a in with_effect(ctx, int(u.side), "premier_coup"):
				team["first_blood"] = true
				AutochessEffects.add_mod(ctx, int(ev.src), "atk_pct", float(a.params.atk_pct), -1.0, "premier_sang")
		"esquive":  # Riposte : ev.src a esquivé le coup de ev.dst
			var u := AutochessEffects.unit(ctx, int(ev.src))
			if u.is_empty() or not u.alive:
				return
			for a in with_effect(ctx, int(u.side), "contre_attaque"):
				AutochessEffects.proc_hit(ctx, int(ev.src), int(ev.dst), AutochessEffects.stat(ctx, int(ev.src), "atk") * float(a.params.ratio), "phys",
					"riposte_atout")
		"chute_allie":  # Ralliement
			var side := int(ev.side)
			for a in with_effect(ctx, side, "soin_equipe"):
				for f in AutochessEffects.living(ctx, side):
					AutochessEffects.heal(ctx, -1, f, float(ctx.units[f].hp_max) * float(a.params.heal_pct), "ralliement")
