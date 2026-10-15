class_name League
extends RefCounted
## Ligue de duel à l'arme (conception, lots 8 et 14) : cinq rangs, contre l'IA scriptée. Rang 0 :
## non classé ; 1 Bronze (Facile), 2 Argent (Normal), 3 Or (Difficile), 4 Platine (Hardcore).
## Le rang le plus haut atteint est gardé dans `Profile.records["league_rank"]` (jamais perdu).
## Chaque rang se gagne en battant [constant WINS_PER_RANK] adversaires d'affilée (classes tirées au
## hasard) en 2 manches gagnantes, à l'arme, niveau 10 par défaut.

const RANKS := ["Non classé", "Bronze", "Argent", "Or", "Platine"]
const WINS_PER_RANK := 3
const DIFFICULTY := [0, 0, 1, 2, 3]  # difficulté ClassRival de l'IA du rang (index = rang visé)
const MASTERY_PER_ROUND := 150  # maîtrise de la classe jouée par manche gagnée
const MASTERY_BASE := 40  # + 20 par rang, par duel gagné
const MASTERY_PER_TIER := 20

## Maîtrise du JcJ contre l'IA hors Ligue (lot E2) : même formule que la Ligue, × la part du mode, × la
## difficulté choisie (palier = difficulté + 1, comme le rang de Ligue qui l'affronte).
const DIFF_FACTOR := [0.5, 0.7, 0.85, 1.0]  # Facile, Normal, Difficile, Hardcore
const MODE_FACTOR := {"free": 0.5, "arena2": 0.5, "arena3": 0.5, "gauntlet": 0.5, "royale": 0.5, "pantheon": 1.0}
const GAUNTLET_PER_FOE := 0.25  # Gantelet : +25 % par adversaire en plus du premier

## Insignes du JcJ contre l'IA plafonnés (I6) : la 1re victoire du jour de chaque mode paie [constant DAILY_INSIGNIA],
## les suivantes [constant REPEAT_INSIGNIA]. Battle royale : seule la meilleure place du jour paie (la différence
## avec la précédente), plus [constant ROYALE_KILL] par élimination.
const DAILY_INSIGNIA := {"arena2": 50, "arena3": 75, "gauntlet_2": 60, "gauntlet_3": 90}
const REPEAT_INSIGNIA := 10
const ROYALE_PLACE := [0, 110, 70, 45, 28, 18, 11, 7, 4]  # indice = place
const ROYALE_KILL := 3
static var day_override := ""  # tests : jour forcé


## Maîtrise d'un duel gagné en [param rounds_won] manches au palier [param tier] (rang de Ligue visé,
## ou difficulté + 1), × [param factor]. Formule commune à tout le JcJ contre l'IA.
static func mastery_for(rounds_won: int, tier: int, factor := 1.0) -> int:
	return roundi((MASTERY_BASE + MASTERY_PER_TIER * maxi(tier, 0) + MASTERY_PER_ROUND * maxi(rounds_won, 0)) * factor)


## Maîtrise d'une victoire dans le mode [param mode] (hors Ligue) contre l'IA de difficulté [param diff] ;
## [param extra_foes] : adversaires en plus du premier (Gantelet).
static func pvp_mastery(mode: String, rounds_won: int, diff: int, extra_foes := 0) -> int:
	var d := clampi(diff, 0, DIFF_FACTOR.size() - 1)
	var f := float(MODE_FACTOR.get(mode, 0.5)) * float(DIFF_FACTOR[d])
	if mode == "gauntlet":
		f *= 1.0 + GAUNTLET_PER_FOE * maxi(extra_foes, 0)
	return mastery_for(rounds_won, d + 1, f)


static func today() -> String:
	return day_override if day_override != "" else Time.get_date_string_from_system()


## Compteurs du jour (remis à zéro chaque jour) : {day, <clé> : victoires ou meilleure place}.
static func daily() -> Dictionary:
	var d = Profile.records.get("pvp_daily", {})
	if not d is Dictionary or String(d.get("day", "")) != today():
		d = {"day": today()}
		Profile.records["pvp_daily"] = d
	return d


## Insignes d'une victoire dans le mode [param key] (« arena2 », « gauntlet_3 »…) : pleins à la 1re du jour,
## × la difficulté [param diff] des adversaires rapportée à Difficile (passe M7 : la difficulté se choisit ; une
## 1re victoire en Facile paie environ 60 %, en Hardcore 118 %).
static func win_insignia(key: String, diff := 2) -> int:
	var d := daily()
	var n := int(d.get(key, 0))
	d[key] = n + 1
	return daily_insignia(key, diff) if n == 0 else REPEAT_INSIGNIA


## Insignes de la 1re victoire du jour dans le mode [param key] à la difficulté [param diff] (sans la compter).
static func daily_insignia(key: String, diff := 2) -> int:
	var k := float(DIFF_FACTOR[clampi(diff, 0, DIFF_FACTOR.size() - 1)]) / float(DIFF_FACTOR[2])
	return roundi(float(DAILY_INSIGNIA.get(key, REPEAT_INSIGNIA)) * k)


## Insignes de la promotion au rang [param rank].
static func promo_insignia(rank: int) -> int:
	return 40 * rank


## La 1re victoire du jour du mode [param key] est-elle encore à prendre ?
static func daily_open(key: String) -> bool:
	return int(daily().get(key, 0)) == 0


## Coffre d'apparence de la promotion au rang [param rank] (passe M7 : rang gardé à vie, donc une seule fois) :
## Bronze et Argent rare, Or mythique, Platine légendaire.
const PROMO_LOOK := ["", "look_rare", "look_rare", "look_epic", "look_legend"]


## Insignes d'une partie de Battle royale : la meilleure place du jour paie la différence avec la précédente.
static func royale_insignia(place: int, n_kills: int) -> int:
	var d := daily()
	var p := clampi(place, 1, ROYALE_PLACE.size() - 1)
	var best := int(d.get("royale_best", ROYALE_PLACE.size()))
	var paid := int(ROYALE_PLACE[best]) if best < ROYALE_PLACE.size() else 0
	var gain := maxi(int(ROYALE_PLACE[p]) - paid, 0)
	if p < best:
		d["royale_best"] = p
	return gain + ROYALE_KILL * maxi(n_kills, 0)


static func rank_index() -> int:
	return clampi(int(Profile.records.get("league_rank", 0)), 0, RANKS.size() - 1)


static func rank_name(i := -1) -> String:
	return RANKS[clampi(rank_index() if i < 0 else i, 0, RANKS.size() - 1)]


## Rang visé par le prochain palier (jamais au-delà de Platine).
static func target_rank() -> int:
	return mini(rank_index() + 1, RANKS.size() - 1)


## Victoires de la série en cours vers le rang visé.
static func streak() -> int:
	return int(Profile.records.get("league_streak", 0))


## Un duel de Ligue est terminé : [param won] ; renvoie {promoted, rank, mastery}.
static func report(won: bool, class_id: String, rounds_won: int) -> Dictionary:
	var out := {"promoted": false, "rank": rank_index(), "mastery": 0, "text": [], "chests": []}
	if won:
		Profile.records["league_streak"] = streak() + 1
		out.mastery = mastery_for(rounds_won, target_rank())
		Profile.add_expertise(class_id, int(out.mastery))
		var next := target_rank()
		if streak() >= WINS_PER_RANK and next > rank_index():
			Profile.records["league_rank"] = next
			Profile.records["league_streak"] = 0
			Profile.insignia += promo_insignia(next)
			(out.text as Array).append("+%d insignes (promotion)" % promo_insignia(next))
			var look := String(PROMO_LOOK[next])
			if look != "":
				Profile.chest_add(look, Pantheon.LEVEL)
				(out.chests as Array).append(look)
			out.promoted = true
			out.rank = next
	else:
		Profile.records["league_streak"] = 0
	return out
