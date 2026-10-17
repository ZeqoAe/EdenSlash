class_name AutochessRewards
extends RefCounted
## L'Échiquier, lot AC-I (SPEC §7.2) : ce qu'une partie donne. Mode scellé : seulement des coffres d'apparence et des titres,
## jamais de puissance ni de monnaie de progression (ni insignes, ni maîtrise, ni matières, ni XP de héros).
##
## Trois paliers de place, chacun récompensé UNE fois par difficulté (0 Recrue … 3 Légende) :
##   top 4 -> coffre d'apparence commun ; top 2 -> rare ; 1re place -> mythique (légendaire en Champion et Légende)
##   + le titre de victoire de la difficulté. Ensuite, plafond par jour (toutes difficultés) : un commun (top 4) et un rare
##   (top 2, la victoire comprise) au plus. Le total de coffres du mode est donc borné : pas de farm.
## Titres d'exploit (une fois, toute difficulté) : Trois étoiles, Pur sang, Invaincu, Frugal (EXPLOITS).
## Abandon : place du moment, récompenses de place seulement dans les 4 premiers (Autochess.abandon), et seulement à partir
## de l'étape ABANDON_MIN_STAGE : avant, on abandonnerait dès 1-2 pour le coffre du jour (aucune récompense, ni quête).
##
## État dans `Profile.records["ac_rewards"]` (clé neuve : un profil ancien n'a rien à migrer, tout se lit avec des défauts) :
## {day, today: [ids de palier], first: ["top4:<diff>"…], games / top4 / wins / best: {"<diff>": n}, exploits: [ids]}.
## Hub intact : `begin()` prend un instantané des propriétés de progression (Survivor.HUB_KEYS) au lancement de l'écran,
## `finish()` les remet AVANT d'écrire les récompenses (comme Survivor.finish), puis les quêtes et la sauvegarde.

const KEY := "ac_rewards"
const MILESTONES := [
	{"id": "top4", "place": 4, "text": "Finir dans les 4 premiers", "chest": "look_common", "daily": "look_common"},
	{"id": "top2", "place": 2, "text": "Finir dans les 2 premiers", "chest": "look_rare", "daily": "look_rare"},
	{"id": "win", "place": 1, "text": "Gagner la partie", "chest": "look_epic", "daily": ""},
]
## Titre de victoire de chaque difficulté (AutochessData.DIFFICULTIES).
const TITLES := ["Stratège", "Tacticien", "Grand tacticien", "Maître de l'Échiquier"]
## Titres d'exploit : une fois, quelle que soit la difficulté.
const EXPLOITS := [
	{"id": "three_stars", "title": "Trois étoiles", "text": "Une unité de coût 4 ou 5 à trois étoiles"},
	{"id": "pure_blood", "title": "Pur sang", "text": "Un trait de famille à 9"},
	{"id": "unbeaten", "title": "Invaincu", "text": "Gagner avec 70 PV ou plus"},
	{"id": "frugal", "title": "Frugal", "text": "Gagner sans jamais actualiser la boutique"},
]
const UNBEATEN_HP := 70
const ABANDON_MIN_STAGE := 4
const THREE_STARS_COST := 4
const CHEST_LEVEL := 20  # niveau d'un coffre d'apparence (comme ceux des quêtes) : il ne change que la zone d'origine

## Bilan de la dernière partie (rempli par settle, lu par le bilan) : {diff, place, abandoned, chests: [{id, type, text,
## kind}], titles: [{title, text, new}], opened (difficulté ouverte par cette partie, -1 : aucune)}.
static var last := {}
static var _hub := {}


# --- difficultés ----------------------------------------------------------------------------------------------------
static func diff_name(d: int) -> String:
	return String(AutochessData.DIFFICULTIES[clampi(d, 0, AutochessData.DIFFICULTIES.size() - 1)].name)


## Recrue et Vétéran dès le départ ; Champion après un top 4 en Vétéran ; Légende après une 1re place en Champion.
## [param dev] : le mode dev ouvre tout (faux : ce que les parties ont ouvert).
static func diff_open(d: int, dev := true) -> bool:
	if d <= 1:
		return true
	if d >= AutochessData.DIFFICULTIES.size():
		return false
	if dev and bool(Settings.get_v("interface", "dev_mode")):
		return true
	return count("top4", 1) > 0 if d == 2 else count("wins", 2) > 0


## Condition d'ouverture d'une difficulté fermée, en une phrase.
static func diff_condition(d: int) -> String:
	return "Finis dans les 4 premiers en Vétéran." if d == 2 else "Gagne une partie en Champion."


static func top_open(dev := true) -> int:
	var top := 0
	for d in AutochessData.DIFFICULTIES.size():
		if diff_open(d, dev):
			top = d
	return top


# --- état ------------------------------------------------------------------------------------------------------------
static func _state() -> Dictionary:
	var s: Variant = Profile.records.get(KEY, {})
	var out: Dictionary = (s as Dictionary).duplicate(true) if s is Dictionary else {}
	if String(out.get("day", "")) != Quests.today():
		out["day"] = Quests.today()
		out["today"] = []
	for k in ["first", "exploits"]:
		if not out.get(k) is Array:
			out[k] = []
	for k in ["games", "top4", "wins", "best"]:
		if not out.get(k) is Dictionary:
			out[k] = {}
	return out


## Compteur [param what] (games, top4, wins) à la difficulté [param d] (-1 : toutes).
static func count(what: String, d := -1) -> int:
	var st := _state()
	var m: Dictionary = st.get(what, {})
	if d >= 0:
		return int(m.get(str(d), 0))
	var n := 0
	for k in m:
		n += int(m[k])
	return n


## Meilleure place à la difficulté [param d] (-1 : toutes) ; 0 si aucune partie finie.
static func best(d := -1) -> int:
	var m: Dictionary = _state().best
	var out := 0
	for k in m:
		if (d < 0 or String(k) == str(d)) and int(m[k]) > 0 and (out == 0 or int(m[k]) < out):
			out = int(m[k])
	return out


static func _first_key(id: String, d: int) -> String:
	return "%s:%d" % [id, d]


static func first_chest(m: Dictionary, d: int) -> String:
	if String(m.id) == "win" and d >= 2:
		return "look_legend"
	return String(m.chest)


static func title_of(d: int) -> String:
	return String(TITLES[clampi(d, 0, TITLES.size() - 1)])


## Les récompenses de la difficulté [param d] pour la page du lobby : [{text, type, done, title}].
static func board(d: int) -> Array:
	var st := _state()
	var out: Array = []
	for m in MILESTONES:
		out.append({"text": String(m.text), "type": first_chest(m, d), "done": _first_key(String(m.id), d) in st.first,
			"title": title_of(d) if String(m.id) == "win" else ""})
	return out


## Exploits : [{id, title, text, done}].
static func exploits() -> Array:
	var st := _state()
	var out: Array = []
	for e in EXPLOITS:
		out.append({"id": String(e.id), "title": String(e.title), "text": String(e.text), "done": String(e.id) in st.exploits})
	return out


## Paliers atteints à la place [param place] (un abandon compte sa place du moment : rien au-delà de la 4e).
static func reached(place: int) -> Array:
	var out: Array = []
	if place <= 0:
		return out
	for m in MILESTONES:
		if place <= int(m.place):
			out.append(String(m.id))
	return out


## Ce que la place [param place] à la difficulté [param d] donnerait : [{id, type, text, kind ("first" | "daily")}].
## Ne change rien.
static func plan(place: int, d: int) -> Array:
	var st := _state()
	var out: Array = []
	var reach := reached(place)
	for m in MILESTONES:
		var id := String(m.id)
		if not id in reach:
			continue
		if not _first_key(id, d) in st.first:
			out.append({"id": id, "type": first_chest(m, d), "text": String(m.text), "kind": "first"})
		elif String(m.daily) != "" and not id in st.today:
			out.append({"id": id, "type": String(m.daily), "text": String(m.text), "kind": "daily"})
	return out


# --- exploits pendant la partie ---------------------------------------------------------------------------------------
## Exploits de plateau vus maintenant chez le stratège [param pi] ([param flags] : ce qui est déjà vu, complété ici).
static func track(g: Autochess, pi: int, flags: Dictionary) -> void:
	if g == null or pi < 0 or pi >= g.players.size():
		return
	for u in g.units_of(pi):
		if int(u.stars) >= 3 and AutochessPool.cost_of(String(u.id)) >= THREE_STARS_COST:
			flags["three_stars"] = true
	var act := g.active_traits(pi)
	for t in act:
		if String(AutochessData.TRAITS.get(t, {}).get("kind", "")) == "famille" and int(act[t]) >= AutochessData.FAMILY_THRESHOLDS.size():
			flags["pure_blood"] = true


## Exploits gagnés par la fin de partie : [ids].
static func exploits_of(place: int, hp: int, rerolls: int, flags: Dictionary) -> Array:
	var out: Array = []
	if bool(flags.get("three_stars", false)):
		out.append("three_stars")
	if bool(flags.get("pure_blood", false)):
		out.append("pure_blood")
	if place == 1 and hp >= UNBEATEN_HP:
		out.append("unbeaten")
	if place == 1 and rerolls == 0:
		out.append("frugal")
	return out


# --- hub et fin ------------------------------------------------------------------------------------------------------
## Lancement de l'écran : instantané de la progression du compte (rien de l'Échiquier ne doit y toucher).
static func begin() -> void:
	_hub = {}
	for k in Survivor.HUB_KEYS:
		var v: Variant = Profile.get(k)
		_hub[k] = v.duplicate(true) if v is Dictionary or v is Array else v
	last = {}


static func has_snapshot() -> bool:
	return not _hub.is_empty()


## Remet la progression du compte telle qu'au lancement ; renvoie les propriétés qui avaient bougé (tests).
static func restore_hub() -> Array:
	var moved: Array = []
	for k in _hub:
		if str(Profile.get(k)) != str(_hub[k]):
			moved.append(k)
		var v: Variant = _hub[k]
		Profile.set(k, v.duplicate(true) if v is Dictionary or v is Array else v)
	_hub = {}
	return moved


## Fin d'une partie : hub remis, récompenses, quêtes, sauvegarde. [param info] : {diff, place, hp, rerolls, rounds,
## rounds_won, secs, abandoned, flags}. Renvoie `last`.
static func finish(info: Dictionary) -> Dictionary:
	if has_snapshot():
		restore_hub()
	settle(info)
	var place := reward_place(info)
	var q := quest_extra(info)
	q["place"] = place
	q["ac_first"] = 1 if place == 1 else 0
	Quests.end_run("autochess", place <= 4, q)
	Profile.save_profile()
	return last


## Ce que les quêtes lisent de la partie (Quests.end_run) : rien de Run (le mode n'en a pas).
static func quest_extra(info: Dictionary) -> Dictionary:
	var place := int(info.get("place", 8))
	return {"place": place, "rounds_won": int(info.get("rounds_won", 0)), "ac_first": 1 if place == 1 else 0,
		"diff": int(info.get("diff", 0)), "secs": float(info.get("secs", 0.0)), "class": "", "kills": 0, "elites": 0,
		"chests": 0, "perfects": 0, "level": 0, "stage": 0, "revives": 0, "epoch": 0, "heroic": 0, "zone_hits": 0}


## Place qui compte pour les récompenses et les quêtes : la vraie, sauf un abandon avant l'étape ABANDON_MIN_STAGE (dernière).
static func reward_place(info: Dictionary) -> int:
	var place := clampi(int(info.get("place", AutochessData.PLAYERS)), 1, AutochessData.PLAYERS)
	if bool(info.get("abandoned", false)) and int(info.get("stage", ABANDON_MIN_STAGE)) < ABANDON_MIN_STAGE:
		return AutochessData.PLAYERS
	return place


## Écrit les récompenses de la partie (coffres rangés dans le menu Coffres, titres) et les records de la page.
static func settle(info: Dictionary) -> Dictionary:
	var d := clampi(int(info.get("diff", 0)), 0, AutochessData.DIFFICULTIES.size() - 1)
	var place := reward_place(info)
	var abandoned := bool(info.get("abandoned", false))
	var opened := -1
	for k in range(d + 1, AutochessData.DIFFICULTIES.size()):
		if not diff_open(k, false):
			opened = k
			break
	var st := _state()
	var dk := str(d)
	st.games[dk] = int(st.games.get(dk, 0)) + 1
	if place <= 4:
		st.top4[dk] = int(st.top4.get(dk, 0)) + 1
	if place == 1:
		st.wins[dk] = int(st.wins.get(dk, 0)) + 1
	if int(st.best.get(dk, 0)) == 0 or place < int(st.best.get(dk, 0)):
		st.best[dk] = place
	var given: Array = []
	for g in plan(place, d):
		Profile.chest_add(String(g.type), CHEST_LEVEL)
		if String(g.kind) == "first":
			(st.first as Array).append(_first_key(String(g.id), d))
		else:
			(st.today as Array).append(String(g.id))
		given.append(g)
	var titles: Array = []
	if place == 1:
		var t := title_of(d)
		titles.append({"title": t, "text": "Victoire en %s" % diff_name(d), "new": not t in Profile.extra_titles})
		Profile.add_title(t)
	for id in exploits_of(place, int(info.get("hp", 0)), int(info.get("rerolls", 1)), info.get("flags", {})):
		if id in st.exploits:
			continue
		(st.exploits as Array).append(id)
		for e in EXPLOITS:
			if String(e.id) == id:
				titles.append({"title": String(e.title), "text": String(e.text), "new": not String(e.title) in Profile.extra_titles})
				Profile.add_title(String(e.title))
	Profile.records[KEY] = st
	if opened >= 0 and not diff_open(opened, false):
		opened = -1
	last = {"diff": d, "place": place, "abandoned": abandoned, "early": place != clampi(int(info.get("place", 8)), 1, AutochessData.PLAYERS),
		"chests": given, "titles": titles, "opened": opened}
	return last


## Valeur [param v] de la propriété du hub [param k] sans ce que l'Échiquier a le droit de donner (coffres d'apparence,
## titres, ses records) ni l'état des quêtes : sert aux tests « le hub est intact ».
static func hub_view(k: String, v: Variant) -> Variant:
	match k:
		"reward_chests":
			return (v as Array).filter(func(c): return not String(c.type).begins_with("look_"))
		"records":
			var r: Dictionary = (v as Dictionary).duplicate(true)
			r.erase(KEY)
			r.erase("quests")
			r.erase("quests_done")  # (une quête accomplie par la partie : permis, elle ne donne que de l'apparence)
			r.erase("quest_series_best")
			return r
		"extra_titles":
			var names: Array = TITLES.duplicate()
			for e in EXPLOITS:
				names.append(String(e.title))
			return (v as Array).filter(func(t): return not String(t) in names)
	return v
