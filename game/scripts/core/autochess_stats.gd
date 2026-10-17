class_name AutochessStats
extends RefCounted
## L'Échiquier, lot AC-V : statistiques de combat façon TFT, lues dans la couche d'effets (AutochessEffects : les compteurs
## ctx.units[fid].stats tenus pour chaque unité, gardés après sa chute). Rien n'est compté ici : un seul moteur de chiffres
## pour le compteur en direct, le bilan de manche et le bilan de partie. Données seulement (l'interface :
## ui/autochess_meter.gd). Rapport : conception/autochess/R_AC_V.md.
##
## Onglets : dégâts infligés (auto-attaques / sorts / autres : effets des objets, brûlures…), dégâts subis (PV perdus, après
## défense et boucliers), soins donnés, boucliers (dégâts arrêtés par les boucliers de l'unité). Somme des dégâts infligés
## = somme des dégâts subis (chaque coup a un auteur). MVP : meilleur score = dégâts + soins + la moitié de ce qu'il a
## encaissé (subis et arrêtés par ses boucliers) : un tank qui tient la ligne compte.

const TABS := ["dealt", "taken", "heal", "shield"]
const TAB_NAMES := {"dealt": "Dégâts", "taken": "Subis", "heal": "Soins", "shield": "Boucliers"}
const TAB_TIPS := {
	"dealt": "Dégâts infligés : auto-attaques, sorts et effets des objets.",
	"taken": "Dégâts reçus, après la défense et les boucliers.",
	"heal": "Points de vie rendus, à soi et aux alliés (sorts et objets).",
	"shield": "Dégâts arrêtés par les boucliers.",
}
const MVP_TANK := 0.5  # poids de ce qu'une unité encaisse (subis + boucliers) dans le score du MVP
const MONSTER_NAMES := {"sbire": "Sbire", "elite": "Élite"}


## Valeur d'un onglet pour les compteurs [param st] d'une unité (ou le cumul d'une partie : mêmes clés).
static func value(st: Dictionary, tab: String) -> float:
	match tab:
		"dealt":
			return float(st.get("dealt", 0.0))
		"taken":
			return float(st.get("taken", 0.0))
		"heal":
			return float(st.get("heal_done", 0.0))
		"shield":
			return float(st.get("blocked", 0.0))
	return 0.0


## Dégâts infligés partagés en [auto-attaques, sorts (zones comprises), autres] ; la somme vaut st.dealt.
static func split(st: Dictionary) -> Array:
	var total := float(st.get("dealt", 0.0))
	var auto := minf(float(st.get("dealt_attack", 0.0)), total)
	var spell := minf(float(st.get("dealt_spell", 0.0)) + float(st.get("zone_dealt", 0.0)), total - auto)
	return [auto, spell, maxf(0.0, total - auto - spell)]


## Score du MVP.
static func score(st: Dictionary) -> float:
	return float(st.get("dealt", 0.0)) + float(st.get("heal_done", 0.0)) \
		+ MVP_TANK * (float(st.get("taken", 0.0)) + float(st.get("blocked", 0.0)))


## Nom court d'une unité de la couche (classe, ou monstre / gardien).
static func label(u: Dictionary) -> String:
	if bool(u.get("guardian", false)):
		return "Gardien"
	var m := String(u.get("monster", ""))
	if m != "":
		return String(MONSTER_NAMES.get(m, "Monstre"))
	return AutochessData.unit_name(String(u.get("id", "")))


## Icône de la classe ("" : monstre, gardien).
static func icon_path(id: String) -> String:
	return String(GameData.class_data(id).get("icon", "")) if id != "" and GameData.classes.has(id) else ""


## Lignes d'un combat pour l'onglet [param tab], classées (la plus grande d'abord) ; [param side] -1 : les deux camps.
## Chaque ligne : fid, side, id, stars, cost, label, value, split (dégâts), kills, alive, score.
static func rows(ctx: Dictionary, tab: String, side := -1) -> Array:
	var out: Array = []
	if ctx.is_empty():
		return out
	for fid in ctx.units:
		var u: Dictionary = ctx.units[fid]
		if side >= 0 and int(u.side) != side:
			continue
		var st: Dictionary = u.stats
		out.append({"fid": int(fid), "side": int(u.side), "id": String(u.id), "stars": int(u.stars), "cost": int(u.cost),
			"label": label(u), "value": value(st, tab), "split": split(st), "kills": int(st.get("kills", 0)),
			"alive": bool(u.alive), "score": score(st), "monster": String(u.monster) != "" or bool(u.guardian)})
	out.sort_custom(func(x, y): return float(x.value) > float(y.value) or (float(x.value) == float(y.value) and int(x.fid) < int(y.fid)))
	return out


## Lignes à montrer : les onglets Soins et Boucliers ne gardent que les unités qui en ont donné / reçu.
static func shown(list: Array, tab: String) -> Array:
	if tab in ["heal", "shield"]:
		return list.filter(func(e): return float(e.value) > 0.0)
	return list


## Texte quand un onglet est vide.
static func empty_text(tab: String) -> String:
	return "Aucun soin pour l'instant." if tab == "heal" else ("Aucun bouclier pour l'instant." if tab == "shield" else "")


## Totaux d'un camp : dealt, taken, heal, shield, kills, units, alive.
static func totals(ctx: Dictionary, side: int) -> Dictionary:
	var t := {"dealt": 0.0, "taken": 0.0, "heal": 0.0, "shield": 0.0, "kills": 0, "units": 0, "alive": 0}
	if ctx.is_empty():
		return t
	for fid in ctx.units:
		var u: Dictionary = ctx.units[fid]
		if int(u.side) != side:
			continue
		for tab in TABS:
			t[tab] = float(t[tab]) + value(u.stats, tab)
		t["kills"] = int(t.kills) + int(u.stats.get("kills", 0))
		t["units"] = int(t.units) + 1
		t["alive"] = int(t.alive) + (1 if bool(u.alive) else 0)
	return t


## MVP du combat (fid, -1 si aucun) : meilleur score parmi les unités du camp [param side] (-1 : des deux camps).
static func mvp(ctx: Dictionary, side := -1) -> int:
	var best := -1
	var best_s := 0.0
	if ctx.is_empty():
		return best
	for fid in ctx.units:
		var u: Dictionary = ctx.units[fid]
		if side >= 0 and int(u.side) != side:
			continue
		var s := score(u.stats)
		if s > best_s or (s == best_s and best >= 0 and int(fid) < best):
			best = int(fid)
			best_s = s
	return best


## Combat de données (comme AutochessDirector.data_fight, même fiche, même couche) qui garde aussi son contexte :
## {"result": résultat au format de la machine, "ctx": contexte d'effets (compteurs)}.
static func data_fight(board_a: Array, board_b: Array, fctx: Dictionary) -> Dictionary:
	var ctx := AutochessEffects.context(fctx, [AutochessDirector._placed(board_a, false), AutochessDirector._placed(board_b, true)],
		func(u): return AutochessDirector.base_sheet(u))
	AutochessEffects.start(ctx)
	var r := AutochessDirector.data_run(ctx, 0.0, AutochessDirector.draw_at())
	return {"result": r, "ctx": ctx}


# --- Cumul d'une partie ----------------------------------------------------------------------------------------------
## Cumul vide d'une partie : {rounds, won, units: {id -> compteurs}, mvp_id}.
static func new_game_stats() -> Dictionary:
	return {"rounds": 0, "units": {}}


## Ajoute au cumul [param acc] le combat [param ctx] du camp [param side] (le joueur) : une entrée par classe (étoiles :
## la plus haute vue), MVP de la manche compté pour sa classe.
static func add_round(acc: Dictionary, ctx: Dictionary, side: int) -> void:
	if ctx.is_empty():
		return
	acc["rounds"] = int(acc.get("rounds", 0)) + 1
	var units: Dictionary = acc.get("units", {})
	acc["units"] = units
	var best := mvp(ctx, side)
	for fid in ctx.units:
		var u: Dictionary = ctx.units[fid]
		if int(u.side) != side or String(u.id) == "":
			continue
		var id := String(u.id)
		var e: Dictionary = units.get(id, {"id": id, "stars": 1, "cost": int(u.cost), "rounds": 0, "mvp": 0, "dealt": 0.0,
			"taken": 0.0, "heal_done": 0.0, "blocked": 0.0, "kills": 0, "dealt_attack": 0.0, "dealt_spell": 0.0, "zone_dealt": 0.0})
		e["stars"] = maxi(int(e.stars), int(u.stars))
		e["rounds"] = int(e.rounds) + 1
		for k in ["dealt", "taken", "heal_done", "blocked", "dealt_attack", "dealt_spell", "zone_dealt"]:
			e[k] = float(e[k]) + float(u.stats.get(k, 0.0))
		e["kills"] = int(e.kills) + int(u.stats.get("kills", 0))
		if int(fid) == best:
			e["mvp"] = int(e.mvp) + 1
		units[id] = e


## Lignes du cumul d'une partie (mêmes champs que rows ; side 0), classées.
static func game_rows(acc: Dictionary, tab: String) -> Array:
	var out: Array = []
	for id in (acc.get("units", {}) as Dictionary):
		var e: Dictionary = acc.units[id]
		out.append({"fid": -1, "side": 0, "id": String(id), "stars": int(e.stars), "cost": int(e.cost),
			"label": AutochessData.unit_name(String(id)), "value": value(e, tab), "split": split(e), "kills": int(e.kills),
			"alive": true, "score": score(e), "monster": false, "rounds": int(e.rounds), "mvp": int(e.mvp)})
	out.sort_custom(func(x, y): return float(x.value) > float(y.value) or (float(x.value) == float(y.value) and String(x.id) < String(y.id)))
	return out


## Totaux du cumul : dealt, taken, heal, shield, kills.
static func game_totals(acc: Dictionary) -> Dictionary:
	var t := {"dealt": 0.0, "taken": 0.0, "heal": 0.0, "shield": 0.0, "kills": 0}
	for id in (acc.get("units", {}) as Dictionary):
		var e: Dictionary = acc.units[id]
		for tab in TABS:
			t[tab] = float(t[tab]) + value(e, tab)
		t["kills"] = int(t.kills) + int(e.kills)
	return t


## Classe la plus utile de la partie (score cumulé) : id, "" si aucune.
static func game_mvp(acc: Dictionary) -> String:
	var best := ""
	var best_s := 0.0
	for id in (acc.get("units", {}) as Dictionary):
		var s := score(acc.units[id])
		if s > best_s:
			best = String(id)
			best_s = s
	return best


## Nombre lisible (espaces des milliers), comme le HUD.
static func num(v: float) -> String:
	return Hud._big_number(v)
