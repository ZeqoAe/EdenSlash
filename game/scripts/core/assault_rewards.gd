class_name AssaultRewards
extends RefCounted
## L'Assaut, lot TAC-8 (TACTIQUE § 7.11) : ce qu'une partie donne. Mode scellé : seulement des coffres d'apparence et des
## titres, jamais de puissance ni de monnaie de progression (ni insignes, ni maîtrise, ni matières, ni XP de héros).
##
## Victoire : un coffre d'apparence selon la difficulté adverse (Facile commun, Normal rare, Difficile mythique, Expert
## légendaire ; Éclair : un cran de moins). La PREMIÈRE victoire à chaque difficulté le donne toujours ; ensuite, DAILY_CAP coffres
## de victoire par jour au plus (toutes difficultés) : pas de farm. Titre de victoire de la difficulté (Normal et au-dessus).
## Titres d'exploit (une fois) : « Démineur » (10 désamorçages au total), « Dernier rempart » (gagner une manche seul contre
## trois ou plus), « Sans une perte » (gagner une partie Classique 7 à 0). Abandon : rien, sauf les quêtes qui comptent la partie.
##
## État dans Profile.records["as_rewards"] : {day, today (coffres de victoire donnés aujourd'hui), first: ["win:<diff>"…],
## games / wins: {"<diff>": n}, defuses (total), exploits: [ids]}. Écrit APRÈS Assault.finish (sauvegarde rechargée, piège 11
## de R_MODE0) : rien d'autre du compte n'a bougé.

const KEY := "as_rewards"
const DAILY_CAP := 2
const DIFFS := ["Facile", "Normal", "Difficile", "Expert"]
const CHESTS := ["look_common", "look_rare", "look_epic", "look_legend"]
const TITLES := ["", "Sapeur", "Artificier", "Maître de l'Assaut"]
const EXPLOITS := [
	{"id": "demineur", "title": "Démineur", "text": "Désamorcer 10 Charges"},
	{"id": "rempart", "title": "Dernier rempart", "text": "Gagner une manche seul contre trois"},
	{"id": "parfait", "title": "Sans une perte", "text": "Gagner une partie 7 à 0"},
]
const DEMINEUR := 10
const CHEST_LEVEL := 20

## Bilan de la dernière partie : {diff, won, chests: [{type, text, kind}], titles: [{title, text, new}], defuses, abandoned}.
static var last := {}


static func diff_name(d: int) -> String:
	return String(DIFFS[clampi(d, 0, DIFFS.size() - 1)])


static func _state() -> Dictionary:
	var s: Variant = Profile.records.get(KEY, {})
	var out: Dictionary = (s as Dictionary).duplicate(true) if s is Dictionary else {}
	if String(out.get("day", "")) != Quests.today():
		out["day"] = Quests.today()
		out["today"] = 0
	for k in ["first", "exploits"]:
		if not out.get(k) is Array:
			out[k] = []
	for k in ["games", "wins"]:
		if not out.get(k) is Dictionary:
			out[k] = {}
	out["today"] = int(out.get("today", 0))
	out["defuses"] = int(out.get("defuses", 0))
	return out


static func count(what: String, d := -1) -> int:
	var m: Dictionary = _state().get(what, {})
	if d >= 0:
		return int(m.get(str(d), 0))
	var n := 0
	for k in m:
		n += int(m[k])
	return n


## Coffre d'une victoire à la difficulté [param d] (Éclair : [param short], un cran de moins).
static func chest_for(d: int, short := false) -> String:
	return String(CHESTS[clampi(d - (1 if short else 0), 0, CHESTS.size() - 1)])


## Ce qu'une victoire à la difficulté [param d] donnerait maintenant : {type, kind ("first" | "daily" | ""), left (coffres du jour
## restants)}. Ne change rien (page du lobby, bilan).
static func plan(d: int, short := false) -> Dictionary:
	var st := _state()
	var left := maxi(0, DAILY_CAP - int(st.today))
	if not ("win:%d" % d) in st.first:
		return {"type": chest_for(d, short), "kind": "first", "left": left}
	return {"type": chest_for(d, short) if left > 0 else "", "kind": "daily" if left > 0 else "", "left": left}


## Lignes de la page du lobby : [{text, done}] (titres d'exploit et de victoire).
static func board() -> Array:
	var st := _state()
	var out: Array = []
	for e in EXPLOITS:
		out.append({"title": String(e.title), "text": String(e.text), "done": String(e.id) in st.exploits})
	return out


## Fin de partie (après Assault.finish) : récompenses, quêtes, sauvegarde. [param info] : AssaultDirector.match_info.
## Rend [member last].
static func finish(info: Dictionary) -> Dictionary:
	last = {}
	if bool(info.get("watch", false)):
		return last  # (8 IA, mesures : le joueur ne jouait pas)
	settle(info)
	Quests.end_run("assault", bool(info.get("won", false)), quest_extra(info))
	Profile.save_profile()
	return last


## Ce que les quêtes lisent de la partie (Quests.end_run).
static func quest_extra(info: Dictionary) -> Dictionary:
	var me := _me(info)
	var won_rounds := 0
	for h in info.get("history", []):
		if int(h.winner) == TeamMatch.player_team:
			won_rounds += 1
	return {"rounds_won": won_rounds, "charge_acts": int(me.get("plants", 0)) + int(me.get("defuses", 0)),
		"pkills": int(me.get("kills", 0)), "diff": int(info.get("diff_foes", 0)), "secs": float(info.get("secs", 0.0)),
		"class": String(info.get("cid", "")), "kills": 0, "elites": 0, "chests": 0, "perfects": 0, "level": 0, "stage": 0,
		"revives": 0, "epoch": 0, "heroic": 0, "zone_hits": 0}


static func _me(info: Dictionary) -> Dictionary:
	for h in info.get("heroes", []):
		if bool(h.get("me", false)):
			return h
	return {}


## Écrit les récompenses de la partie (coffres rangés dans le menu Coffres, titres) et les compteurs de la page.
static func settle(info: Dictionary) -> Dictionary:
	var d := clampi(int(info.get("diff_foes", 1)), 0, DIFFS.size() - 1)
	var won := bool(info.get("won", false))
	var forfeit := bool(info.get("forfeit", false))
	var short := String(info.get("format", "assault")) == "eclair"
	var st := _state()
	var dk := str(d)
	var me := _me(info)
	st.games[dk] = int(st.games.get(dk, 0)) + 1
	st.defuses = int(st.defuses) + int(me.get("defuses", 0))
	var chests: Array = []
	var titles: Array = []
	if won and not forfeit:
		st.wins[dk] = int(st.wins.get(dk, 0)) + 1
		var p := plan(d, short)
		if String(p.type) != "":
			Profile.chest_add(String(p.type), CHEST_LEVEL)
			if String(p.kind) == "first":
				(st.first as Array).append("win:%d" % d)
			else:
				st.today = int(st.today) + 1
			chests.append({"type": String(p.type), "kind": String(p.kind),
				"text": "Victoire en %s" % diff_name(d) + (" · première fois" if String(p.kind) == "first" else " · coffre du jour")})
		var t := String(TITLES[d])
		if t != "":
			titles.append({"title": t, "text": "Victoire en %s" % diff_name(d), "new": not t in Profile.extra_titles})
			Profile.add_title(t)
	var got: Array = []
	if int(st.defuses) >= DEMINEUR:
		got.append("demineur")
	if int(info.get("clutch", 0)) > 0:
		got.append("rempart")
	var sc: Array = info.get("score", [0, 0])
	if won and not forfeit and not short and int(sc[1 - TeamMatch.player_team]) == 0 and int(sc[TeamMatch.player_team]) >= 7:
		got.append("parfait")
	for id in got:
		if id in st.exploits:
			continue
		(st.exploits as Array).append(id)
		for e in EXPLOITS:
			if String(e.id) == id:
				titles.append({"title": String(e.title), "text": String(e.text), "new": not String(e.title) in Profile.extra_titles})
				Profile.add_title(String(e.title))
	Profile.records[KEY] = st
	last = {"diff": d, "won": won, "abandoned": forfeit, "chests": chests, "titles": titles, "defuses": int(st.defuses),
		"left": maxi(0, DAILY_CAP - int(st.today))}
	return last
