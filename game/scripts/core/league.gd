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
	var out := {"promoted": false, "rank": rank_index(), "mastery": 0}
	if won:
		Profile.records["league_streak"] = streak() + 1
		out.mastery = MASTERY_BASE + 20 * target_rank() + MASTERY_PER_ROUND * rounds_won
		Profile.add_expertise(class_id, int(out.mastery))
		var next := target_rank()
		if streak() >= WINS_PER_RANK and next > rank_index():
			Profile.records["league_rank"] = next
			Profile.records["league_streak"] = 0
			Profile.insignia += 40 * next
			out.promoted = true
			out.rank = next
	else:
		Profile.records["league_streak"] = 0
	return out
