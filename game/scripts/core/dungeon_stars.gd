class_name DungeonStars
extends RefCounted
## Étoiles de donjon (lot DNG-3, backlog BM-DNG P1-1) : trois objectifs facultatifs par donjon (un par boss de la bibliothèque) et
## par difficulté, comme ceux du Siège. Jamais requis pour le butin (le coffre, les cristaux et le plan ne bougent pas) : une
## étoile ne donne qu'une médaille, et les paliers d'étoiles des titres et des coffres d'apparence (cosmétiques).
##   ★ « Le boss tombe » : le donjon est fini (une reprise au boss compte) ;
##   ★ « Sous 7:30 » : le donjon d'une traite (pas une reprise) sous le temps affiché à l'avance sur la page ([method par]) ;
##   ★ « Personne ne tombe » : ni toi (aucune relève, Relief) ni un allié IA.
## Stockage : Profile.records["dgs_<boss>_<diff>"] = bits (clé neuve : rien à migrer). Écrit après le rechargement du profil
## (Tower._finish_dungeon), comme le butin.
##
## Temps affiché ([method par]) : médiane du pilote (R_A2 : 5:48 en Normal, ≈ 4:45 en Héroïque et Mythique, héros invincible) × 1,3,
## comme le recommande l'étude ; + 45 s pour un boss à objets à casser (totems, cristaux, tourelles : le pilote les ignore), au
## quart de minute près. Les PV des boss (Dungeons.boss_hp, × le boss) ne sont pas touchés.

const STARS := [
	{"id": "clear", "name": "Le boss tombe", "tip": "Termine le donjon (une reprise au boss compte)."},
	{"id": "time", "name": "Sous %s", "tip": "Termine le donjon d'une traite, sans reprise au boss, en moins de %s."},
	{"id": "safe", "name": "Personne ne tombe", "tip": "Termine le donjon sans relève, et sans qu'un allié tombe."},
]
const PAR := [450.0, 375.0, 375.0]  # Normal, Héroïque, Mythique (s)
const PAR_BREAK := 45.0
const BREAK_BRICKS := ["totems", "crystals", "turrets"]
const KEY := "dgs_"
## Paliers (nombre de donjons à trois étoiles, toutes difficultés ; le dernier : en Mythique) : titre et, pour les deux
## derniers, un coffre d'apparence. Rien d'autre.
const MILESTONES := [
	{"n": 1, "title": "Étoilé", "look": 0, "mythic": false},
	{"n": 12, "title": "Constellation", "look": 2, "mythic": false},
	{"n": 48, "title": "Firmament", "look": 3, "mythic": true},
]

## Un allié IA est tombé pendant le donjon en cours (TowerDirector._make_ally).
static var ally_fell := false


static func reset() -> void:
	ally_fell = false


## Temps à battre pour l'étoile « Sous … » (s) du donjon de [param bid] en difficulté [param diff].
static func par(bid: String, diff: int) -> float:
	var t := float(PAR[clampi(diff, 0, PAR.size() - 1)])
	for b in BossLibrary.brick_types(bid):
		if String(b) in BREAK_BRICKS:
			t += PAR_BREAK
			break
	return roundf(t / 15.0) * 15.0


static func star_name(i: int, bid: String, diff: int) -> String:
	var n := String(STARS[i].name)
	return n % BestTimes.fmt(par(bid, diff)) if n.contains("%s") else n


static func star_tip(i: int, bid: String, diff: int) -> String:
	var n := String(STARS[i].tip)
	return n % BestTimes.fmt(par(bid, diff)) if n.contains("%s") else n


static func _key(bid: String, diff: int) -> String:
	return "%s%s_%d" % [KEY, bid, diff]


## Étoiles déjà gagnées (ids de STARS) pour le donjon de [param bid] en [param diff].
static func got(bid: String, diff: int) -> Array:
	var bits := int(Profile.records.get(_key(bid, diff), 0))
	var out: Array = []
	for i in STARS.size():
		if (bits >> i) & 1 == 1:
			out.append(String(STARS[i].id))
	return out


static func count(bid: String, diff: int) -> int:
	return got(bid, diff).size()


## Donjons à trois étoiles ([param diff] -1 : à au moins une difficulté).
static func full_count(diff := -1) -> int:
	var n := 0
	for id in BossLibrary.ids():
		for d in Dungeons.DIFF_NAMES.size():
			if (diff < 0 or d == diff) and count(String(id), d) >= STARS.size():
				n += 1
				break
	return n


## Toutes les étoiles gagnées (les 48 donjons × 3 difficultés × 3).
static func total() -> int:
	var n := 0
	for id in BossLibrary.ids():
		for d in Dungeons.DIFF_NAMES.size():
			n += count(String(id), d)
	return n


static func total_max() -> int:
	return BossLibrary.ids().size() * Dungeons.DIFF_NAMES.size() * STARS.size()


## Objectifs du donjon qui vient de finir (appelé après le rechargement du profil, avant la sauvegarde) : [param victory],
## [param full_run] (pas une reprise au boss), [param secs] (temps de la partie), [param reliefs] (relèves utilisées).
## Renvoie {stars: ids tenus, new: ids neufs, titles: titres neufs, chests: coffres d'apparence} ; rien hors d'un donjon à la carte.
static func score(bid: String, diff: int, victory: bool, full_run: bool, secs: float, reliefs: int) -> Dictionary:
	var out := {"stars": [], "new": [], "titles": [], "chests": []}
	if not BossLibrary.has(bid) or not victory:
		return out
	out.stars.append("clear")
	if full_run and secs > 0.5 and secs <= par(bid, diff):
		out.stars.append("time")
	if reliefs <= 0 and not ally_fell:
		out.stars.append("safe")
	var key := _key(bid, diff)
	var bits := int(Profile.records.get(key, 0))
	var before_full := full_count()
	var before_myth := full_count(2)
	for i in STARS.size():
		if String(STARS[i].id) in out.stars and (bits >> i) & 1 == 0:
			bits |= 1 << i
			out.new.append(String(STARS[i].id))
	Profile.records[key] = bits
	# paliers : titres et coffres d'apparence (cosmétiques), une fois chacun
	var now_full := full_count()
	var now_myth := full_count(2)
	for m in MILESTONES:
		var was := before_myth if bool(m.mythic) else before_full
		var now := now_myth if bool(m.mythic) else now_full
		if was < int(m.n) and now >= int(m.n) and not String(m.title) in Profile.extra_titles:
			Profile.add_title(String(m.title))
			out.titles.append(String(m.title))
			if int(m.look) > 0:
				var c := Rewards.make(Rewards.look_type(int(m.look)), Dungeons.level(Dungeons.boss_zone(bid), diff), true)
				Profile.reward_chests.append(c)
				out.chests.append(c)
	return out


## Objectifs du bilan (ResultsPanel, clé « stars ») : [{label, done, new, tip}].
static func spec_rows(bid: String, diff: int, sc: Dictionary) -> Array:
	var out: Array = []
	for i in STARS.size():
		var id := String(STARS[i].id)
		out.append({"label": star_name(i, bid, diff), "done": id in (sc.get("stars", []) as Array), "new": id in (sc.get("new", []) as Array),
			"tip": star_tip(i, bid, diff)})
	return out


## « ★★☆ » des étoiles gagnées.
static func glyphs(bid: String, diff: int) -> String:
	var g := got(bid, diff)
	return "".join(STARS.map(func(s): return "★" if String(s.id) in g else "☆"))


## Prochain palier : « Encore 3 donjons à trois étoiles : titre « Constellation » » ("" : tout est pris).
static func next_line() -> String:
	for m in MILESTONES:
		var now := full_count(2) if bool(m.mythic) else full_count()
		if now < int(m.n):
			var left := int(m.n) - now
			return "Encore %d donjon%s à trois étoiles%s : titre « %s »%s" % [left, "s" if left > 1 else "", " en Mythique" if bool(m.mythic) else "",
				String(m.title), " et un coffre d'apparence" if int(m.look) > 0 else ""]
	return ""
