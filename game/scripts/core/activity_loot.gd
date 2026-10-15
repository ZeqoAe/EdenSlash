class_name ActivityLoot
extends RefCounted
## Matières et cristaux des activités hors Survie (0.1.165, lot E1 de la nuit du 15/10) : le pipeline
## « fournitures » de la quête commune. Chaque activité donne ses cristaux (monnaie de la Forge) et des
## coffres de forge / du joaillier AU NIVEAU DE L'ACTIVITÉ (un parchemin de fortification doit avoir un niveau
## au moins égal à celui de la pièce : sans ça, aucune pièce de niveau > 40 ne passe +1).
##
## Rôles (conception/nuit_15_10/A1_progression.md, §5.3) :
## - Donjons : matières moyennes (niveau du donjon : 14-60 en Normal, 29-75 en Héroïque, 90 en Mythique) ;
## - Ruée des boss : matières de haut niveau (niveau du dernier boss, 60 / 75 / 90), parchemins en nombre
##   et pierres rares ;
## - Siège : formules d'enchantement hautes (niveau 1-9 selon le niveau du siège) ;
## - Tour : cristaux et gemmes (un coffre de gemmes tous les 10 étages montés, un coffre de forge tous les 50).
## Cible de la Forge : un clear Mythique ≈ 170 à 270 cristaux ; une pièce niveau 85 à +10 ≈ 750 cristaux
## (`Forge.upgrade_crystals`), soit 4 à 5 clears.

## Cristaux d'un donjon terminé (Normal, Héroïque, Mythique).
const DUNGEON_CRYSTALS := [30, 90, 170]
## Cristaux par boss de la Ruée (huit boss : 64 / 144 / 272).
const RUSH_PER_BOSS := [8, 18, 34]
## Cristaux du Siège : par vague vaincue (cinq au plus), puis en plus quand le boss tombe.
const SIEGE_PER_WAVE := [4, 10, 18]
const SIEGE_BOSS := [10, 40, 110]
## Cristaux de la Tour : par étage monté, selon la difficulté (Facile, Normal, Difficile, Hardcore).
## Passe E6 (avant 1 / 1,5 / 2 / 2,5) : la Tour s'ouvre à l'époque I gagnée, les Donjons à l'époque II ; entre les deux
## elle est la seule source de cristaux (≈ 45 / h en Normal à 2 min l'étage : un +5 sur une pièce de l'époque I en
## demandait ≈ 2 h). Maintenant ≈ 120 / h en Normal, toujours sous un Donjon Normal (180) et loin du Mythique (≈ 1 000).
const TOWER_PER_FLOOR := [3.0, 4.0, 5.0, 6.0]
## Un coffre de gemmes tous les [TOWER_GEM_EVERY] étages montés, un coffre de forge tous les [TOWER_FORGE_EVERY].
const TOWER_GEM_EVERY := 10
const TOWER_FORGE_EVERY := 50


static func dungeon_crystals(diff: int) -> int:
	return int(DUNGEON_CRYSTALS[clampi(diff, 0, 2)])


static func rush_crystals(reached: int, diff: int) -> int:
	return reached * int(RUSH_PER_BOSS[clampi(diff, 0, 2)])


static func siege_crystals(reached: int, diff: int, boss_down: bool) -> int:
	var d := clampi(diff, 0, 2)
	return int(SIEGE_PER_WAVE[d]) * mini(reached, Siege.WAVES) + (int(SIEGE_BOSS[d]) if boss_down else 0)


static func tower_crystals(climbed: int, diff: int) -> int:
	return roundi(float(climbed) * float(TOWER_PER_FLOOR[clampi(diff, 0, TOWER_PER_FLOOR.size() - 1)]))


## Ajoute [param n] coffres [param type] (focus [param focus]) de niveau [param lv] au menu Coffres ;
## renvoie les coffres créés.
static func _give(type: String, lv: int, n: int, focus := "") -> Array:
	var out: Array = []
	for i in n:
		var c := Rewards.make(type, lv, false, focus)
		Profile.reward_chests.append(c)
		out.append(c)
	return out


## Coffres de matières d'un donjon terminé : 1 de forge en Normal ; + 1 du joaillier en Héroïque ;
## 2 de forge et 1 du joaillier en Mythique.
static func dungeon_chests(lv: int, diff: int) -> Array:
	var out := _give("forge", lv, 2 if diff >= 2 else 1)
	if diff >= 1:
		out.append_array(_give("jewel", lv, 1))
	return out


## Coffres de matières de la Ruée : à 4 boss, un coffre de forge ; si les 8 sont tombés, deux de parchemins,
## un de pierres rares et un de gemmes (Normal : un seul de parchemins), au niveau du dernier boss [param lv].
static func rush_chests(lv: int, reached: int, diff: int) -> Array:
	var out: Array = []
	if reached >= Dungeons.rush_floors():
		out.append_array(_give("forge", lv, 1 if diff == 0 else 2, "scroll"))
		out.append_array(_give("forge", lv, 1, "stone"))
		out.append_array(_give("jewel", lv, 1, "gem"))
	elif reached >= Dungeons.rush_floors() / 2:
		out.append_array(_give("forge", lv, 1))
	return out


## Coffres de matières du Siège (boss tombé) : des formules d'enchantement (1 coffre en Normal, 2 en Héroïque,
## 3 en Mythique) et, en Héroïque et Mythique, un coffre de forge.
static func siege_chests(lv: int, diff: int) -> Array:
	var out := _give("jewel", lv, clampi(diff, 0, 2) + 1, "enchant")
	if diff >= 1:
		out.append_array(_give("forge", lv, 1))
	return out


## Coffres de matières d'une ascension de la Tour : étages montés de [param first] à [param last] ; le niveau
## d'un coffre est celui de l'étage où il tombe ([param level_of] : Callable étage -> niveau).
static func tower_chests(first: int, last: int, level_of: Callable) -> Array:
	var out: Array = []
	for f in range(maxi(first, 1), last + 1):
		if f % TOWER_FORGE_EVERY == 0:
			out.append_array(_give("forge", int(level_of.call(f)), 1))
		elif f % TOWER_GEM_EVERY == 0:
			out.append_array(_give("jewel", int(level_of.call(f)), 1, "gem"))
	return out


## Texte court des coffres de matières d'un butin : « 2 coffres de forge, 1 coffre du joaillier ».
static func chests_text(chests: Array) -> String:
	var counts := {}
	for c in chests:
		counts[c.type] = int(counts.get(c.type, 0)) + 1
	var parts: PackedStringArray = []
	for t in Rewards.ORDER:
		if counts.has(t):
			parts.append(String(Rewards.TYPES[t].name) if int(counts[t]) == 1 else "%s ×%d" % [Rewards.TYPES[t].name, int(counts[t])])
	return ", ".join(parts)
