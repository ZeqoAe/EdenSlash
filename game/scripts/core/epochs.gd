class_name Epochs
extends RefCounted
## Époques de la Survie (DESIGN.md, « Boucle de jeu et Survie ») : une run = 3 maps d'une
## même époque. La puissance est normalisée (on repart du niveau 1, plafond de niveau par map) ;
## l'époque choisit les pièces d'Eden des coffres d'emplacement (palier et rareté de chaque map)
## et la force des monstres. Battre le boss de la 3e map débloque l'époque suivante.

## armor / weapon : niveau d'Eden des pièces proposées ; rarity : Items.MYTHIC ou LEGENDARY ;
## awakened : pièces « Awaken » d'Eden (légendaires avec aura).
const LIST := [
	{"name": "Époque I", "zones": ["limestone", "rainbowfall", "beluga"], "maps": [
		{"armor": 23, "weapon": 20, "rarity": 4}, {"armor": 33, "weapon": 30, "rarity": 4}, {"armor": 43, "weapon": 40, "rarity": 4}]},
	{"name": "Époque II", "zones": ["wetlands", "avila", "arid"], "maps": [
		{"armor": 48, "weapon": 45, "rarity": 4}, {"armor": 53, "weapon": 50, "rarity": 4}, {"armor": 60, "weapon": 60, "rarity": 5}]},
	{"name": "Époque III", "zones": ["delphi", "blackflame", "wetlands"], "maps": [
		{"armor": 65, "weapon": 65, "rarity": 5}, {"armor": 70, "weapon": 70, "rarity": 5}, {"armor": 70, "weapon": 75, "rarity": 5, "awakened": true}]},
	{"name": "Époque IV", "zones": ["avila", "arid", "blackflame"], "maps": [
		{"armor": 80, "weapon": 80, "rarity": 5}, {"armor": 85, "weapon": 85, "rarity": 5}, {"armor": 80, "weapon": 90, "rarity": 5, "awakened": true}]},
]
## Niveau maximal du héros (et des monstres hors rage) sur chaque map de la run.
const CAPS := [15, 25, 35]
## Niveau de départ des monstres de chaque map.
const LEVEL_BONUS := [0, 12, 22]
## PV et dégâts des monstres par époque (la difficulté vient des monstres, pas du niveau).
const MONSTER_MULT := [1.0, 1.35, 1.75, 2.2]


static func count() -> int:
	return LIST.size()


static func get_def(epoch: int) -> Dictionary:
	return LIST[clampi(epoch, 1, LIST.size()) - 1]


## Map [param stage] (1 à 3) de l'époque [param epoch].
static func map_def(epoch: int, stage: int) -> Dictionary:
	var maps: Array = get_def(epoch).maps
	return maps[clampi(stage, 1, maps.size()) - 1]


static func zone(epoch: int, stage: int) -> String:
	var z: Array = get_def(epoch).zones
	return String(z[clampi(stage, 1, z.size()) - 1])


static func cap(stage: int) -> int:
	return int(CAPS[clampi(stage, 1, CAPS.size()) - 1])


static func level_bonus(stage: int) -> int:
	return int(LEVEL_BONUS[clampi(stage, 1, LEVEL_BONUS.size()) - 1])


static func monster_mult(epoch: int) -> float:
	return float(MONSTER_MULT[clampi(epoch, 1, MONSTER_MULT.size()) - 1])


## Époques ouvertes : la I, puis une de plus par époque terminée.
static func unlocked() -> int:
	return clampi(1 + int(Profile.records.get("epochs_cleared", 0)), 1, LIST.size())


## Boss de la 3e map battu : l'époque suivante s'ouvre. Renvoie son nom ("" sinon).
static func clear(epoch: int) -> String:
	if epoch > int(Profile.records.get("epochs_cleared", 0)):
		Profile.records["epochs_cleared"] = epoch
		if epoch < LIST.size():
			return String(get_def(epoch + 1).name)
	return ""


## Texte court d'une map : « palier 23 · mythique ».
static func map_text(epoch: int, stage: int) -> String:
	var m := map_def(epoch, stage)
	return "palier %d · %s" % [int(m.armor), rarity_name(m)]


static func rarity_name(m: Dictionary) -> String:
	if m.get("awakened", false):
		return "éveillé"
	return "légendaire" if int(m.rarity) >= Items.LEGENDARY else "mythique"
