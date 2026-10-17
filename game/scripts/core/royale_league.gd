class_name RoyaleLeague
extends RefCounted
## Ligue royale (lot BR-R1, backlog BM-BR P1 n° 14 ; question ouverte n° 3 : « une ligue légère, points de place + éliminations,
## rangs de League, une apparence par saison ») : une saison par mois du calendrier, des points à chaque partie (jamais perdus,
## aucune connexion quotidienne demandée : sans corvée), quatre rangs (Bronze dès la 1re partie, Argent, Or, Platine).
## Récompenses d'apparence et de titre seulement (mode scellé, aucune puissance) : un coffre d'apparence par rang atteint dans la
## saison (une fois par saison), et la 1re fois de toutes : un titre et une voile de planeur du mode (RoyaleLooks).
## Les parties personnalisées (Royale.custom) ne comptent pas. État : Profile.records.royale_league = {season, points, rank,
## games, best (meilleur rang de chaque saison passée : {saison: rang}), paid: [rangs payés cette saison]}.

const RANKS := ["Bronze", "Argent", "Or", "Platine"]
## Points pour atteindre chaque rang (Bronze : la 1re partie).
const STEPS := [0, 30, 80, 150]
## Points d'une partie : selon la place (indice = place), plus KILL_PTS par élimination (KILL_MAX au plus), × la difficulté
## des scriptés (Facile, Normal, Difficile, Hardcore ; le mélange compte comme Difficile). Mesure de conception : une partie
## Difficile moyenne (4e, une élimination) vaut 7 points ; Platine demande une vingtaine de parties moyennes dans le mois
## (environ 3 h 30), une dizaine de bonnes.
const PLACE_PTS := [0, 14, 10, 8, 5, 4, 3, 2, 1]
const KILL_PTS := 2
const KILL_MAX := 5
const DIFF_MULT := [0.5, 0.75, 1.0, 1.25]
## Coffre d'apparence de chaque rang atteint dans une saison (Bronze : rien) et titre de la 1re fois.
const RANK_CHEST := [-1, 1, 2, 3]
const RANK_TITLE := ["", "Voltigeur d'argent", "Voltigeur d'or", "Voltigeur de platine"]
const MONTHS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]


## Saison du jour [param day] (« AAAA-MM »).
static func season(day := "") -> String:
	return (day if day != "" else League.today()).substr(0, 7)


## Nom de la saison : « Saison d'octobre ».
static func season_name(s := "") -> String:
	var key := s if s != "" else season()
	var m := clampi(int(key.substr(5, 2)) - 1, 0, 11)
	var month: String = MONTHS[m]
	return "Saison %s%s" % ["d'" if month.substr(0, 1) in ["a", "o"] else "de ", month]


## Jours avant la fin de la saison (le dernier jour du mois compte : 1).
static func days_left(day := "") -> int:
	var dd := day if day != "" else League.today()
	var y := int(dd.substr(0, 4))
	var m := int(dd.substr(5, 2))
	var ny := y + (1 if m == 12 else 0)
	var nm := 1 if m == 12 else m + 1
	var end := Time.get_unix_time_from_datetime_string("%04d-%02d-01T00:00:00" % [ny, nm])
	var now := Time.get_unix_time_from_datetime_string(dd + "T00:00:00")
	return maxi(1, int(ceil((end - now) / 86400.0)))


## État de la saison en cours (une nouvelle saison repart de zéro, l'ancienne garde son meilleur rang dans « best »).
static func state() -> Dictionary:
	var st = Profile.records.get("royale_league", {})
	if not st is Dictionary:
		st = {}
	var s := season()
	if String(st.get("season", "")) != s:
		var best: Dictionary = st.get("best", {})
		if String(st.get("season", "")) != "" and int(st.get("games", 0)) > 0:
			best[String(st.season)] = int(st.get("rank", 0))
		st = {"season": s, "points": 0, "rank": 0, "games": 0, "best": best, "paid": []}
		Profile.records["royale_league"] = st
	return st


static func points() -> int:
	return int(state().get("points", 0))


## Rang pour [param pts] points (0 Bronze … 3 Platine).
static func rank_for(pts: int) -> int:
	var r := 0
	for i in STEPS.size():
		if pts >= int(STEPS[i]):
			r = i
	return r


static func rank() -> int:
	return rank_for(points())


static func rank_name(r := -1) -> String:
	return String(RANKS[clampi(rank() if r < 0 else r, 0, RANKS.size() - 1)])


## Points qui manquent pour le rang suivant (0 : Platine).
static func to_next() -> int:
	var r := rank()
	return 0 if r >= RANKS.size() - 1 else int(STEPS[r + 1]) - points()


## Rang le plus haut atteint dans toutes les saisons (-1 : jamais joué).
static func best_ever() -> int:
	var st := state()
	var b := int(st.get("rank", 0)) if int(st.get("games", 0)) > 0 else -1
	for k in st.get("best", {}):
		b = maxi(b, int(st.best[k]))
	return b


## Points d'une partie finie en [param place] avec [param n_kills] éliminations contre des scriptés de difficulté [param diff]
## (-1 : mélange).
static func points_for(place: int, n_kills: int, diff: int) -> int:
	var base := int(PLACE_PTS[clampi(place, 1, PLACE_PTS.size() - 1)]) + KILL_PTS * clampi(n_kills, 0, KILL_MAX)
	var k := float(DIFF_MULT[clampi(diff if diff >= 0 else 2, 0, DIFF_MULT.size() - 1)])
	return maxi(1, roundi(base * k))


## Une partie (classée) est finie : points, rang, récompenses d'apparence et titres. Renvoie {points, gained, rank, promoted,
## text: [lignes du bilan], title, chests}.
static func report(place: int, n_kills: int, diff: int) -> Dictionary:
	var st := state()
	var before := rank_for(int(st.points))
	var gain := points_for(place, n_kills, diff)
	st.points = int(st.points) + gain
	st.games = int(st.get("games", 0)) + 1
	var now := rank_for(int(st.points))
	st.rank = now
	var out := {"points": int(st.points), "gained": gain, "rank": now, "promoted": now > before or int(st.games) == 1, "text": [], "title": "", "chests": []}
	out.text.append("Ligue royale : +%d points (%s)" % [gain, rank_name(now)])
	var paid: Array = st.get("paid", [])
	for r in range(1, now + 1):
		if r in paid:
			continue
		paid.append(r)
		var tier := int(RANK_CHEST[r])
		if tier > 0:
			var look := Rewards.look_type(tier)
			Profile.chest_add(look, 20)
			out.chests.append(look)
			out.text.append("Coffre d'apparence %s (rang %s)" % [["rare", "épique", "légendaire"][clampi(tier - 1, 0, 2)], rank_name(r)])
		var title := String(RANK_TITLE[r])
		if title != "" and not title in Profile.extra_titles:
			Profile.add_title(title)
			out.title = title
			out.text.append("Titre : « %s »" % title)
	st.paid = paid
	return out
