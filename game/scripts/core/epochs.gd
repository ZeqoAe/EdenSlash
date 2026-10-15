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
## Passe E6 (avant 1,35 / 1,75 / 2,2) : l'équipement du hub multiplie la puissance du héros en Survie par
## ≈ 6 à 7 entre les pièces +0 de l'époque I et un équipement complet d'époque IV (+10, gemmes, enchantements) ; avec
## l'ancien écart, l'époque IV tombait ≈ 10 h après le premier lancement (simulation tools/progression_sim). Chaque
## époque demande maintenant l'équipement de la précédente bien monté : II ≈ pièces de l'époque I à +5 et
## quelques gemmes, III ≈ pièces de l'époque II à +10, IV ≈ un équipement complet (R_E6.md).
const MONSTER_MULT := [1.0, 1.7, 3.4, 7.0]


## Premiers niveaux de la Survie plus vite (0.1.164) : l'expérience gagnée est multipliée par ce facteur,
## 2,0 au niveau 1 jusqu'à 1,0 au niveau 10 (un niveau = des PV rendus et une carte, donc des sorts).
static func xp_boost(level: int) -> float:
	return 1.0 + 1.0 * clampf(float(10 - level) / 9.0, 0.0, 1.0)


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


## Étoiles d'époque (3 par époque) : ★1 gagner l'époque, ★2 la gagner sans résurrection, ★3 réussir le défi
## de l'époque. Elles sont gardées dans `Profile.records["epoch_stars_<n>"]` (masque de bits).
const CHALLENGES := [
	"Vaincre le boss de la 3e carte avant la rage",
	"Finir avec 12 trophées",
	"Finir sans arme secondaire",
	"Utiliser l'enclume sur les 3 cartes",
]


static func star_mask(epoch: int) -> int:
	return int(Profile.records.get("epoch_stars_%d" % epoch, 0))


static func stars(epoch: int) -> int:
	var m := star_mask(epoch)
	return (m & 1) + ((m >> 1) & 1) + ((m >> 2) & 1)


static func total_stars() -> int:
	var n := 0
	for ep in range(1, count() + 1):
		n += stars(ep)
	return n


static func star_text(epoch: int) -> String:
	var m := star_mask(epoch)
	var s := ""
	for b in 3:
		s += "★" if (m >> b) & 1 else "☆"
	return s


## Les trois conditions de la run qui vient de finir (victoire à la 3e carte) : bits des étoiles gagnées.
static func earned_mask(epoch: int) -> int:
	var m := 1
	if Run.resurrections == 0:
		m |= 2
	var ok := false
	match epoch:
		1:
			ok = not Run.stage in Run.rage_stages
		2:
			ok = Run.trophies.size() >= Run.MAX_TROPHIES
		3:
			ok = not Run.offhand_used
		4:
			ok = Run.anvil_stages.size() >= 3
	if ok:
		m |= 4
	return m


## Rang héroïque le plus haut terminé sur l'époque [param epoch].
static func heroic_best(epoch: int) -> int:
	return int(Profile.records.get("heroic_best_%d" % epoch, 0))


## Rangs héroïques ouverts par l'époque IV ; au plus 10 ; chaque rang demande le précédent terminé.
static func heroic_open() -> bool:
	return Unlocks.is_open("heroic")


const HEROIC_MAX := 10
const HEROIC_HP := 0.12
const HEROIC_ATK := 0.08
const HEROIC_INSIGNIA := 0.15


## Contraintes cumulées d'un rang héroïque : une de plus tous les 3 rangs.
static func heroic_mods(rank: int) -> Array:
	return Challenge.SURVIVAL_MODS.slice(0, mini(rank / 3, Challenge.SURVIVAL_MODS.size()))


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
