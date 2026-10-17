class_name Epochs
extends RefCounted
## Époques de la Survie (DESIGN.md, « Boucle de jeu et Survie ») : une run = 3 maps d'une
## même époque. L'époque choisit les pièces d'Eden des coffres d'emplacement (palier et rareté de chaque map)
## et la force des monstres. Battre le boss de la 3e map débloque l'époque suivante.
##
## Lot H4a (NIVEAU_HEROS.md §1.4) : le héros joue au NIVEAU DE HÉROS (`HeroLevel`, fixe pendant la partie :
## `Run.hero_level`, stats de base, puissance des pièces à leur vrai niveau, jusqu'à 90). Chaque carte a une BANDE de
## niveau ([member BANDS]) : ses monstres sont au niveau du héros borné par la bande ([method map_level]) ; PV ×
## [member MAP_MULT], dégâts × [member MAP_ATK] / [member BOSS_ATK] de la carte, × montée dans le temps ([method time_ramp]). Le niveau de run (`Player.level`,
## repart de 1, sans plafond) ne donne plus que des cartes. Plus de plafond 15 / 25 / 35 ni de niveau de départ par carte.

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
## Bande de niveau [bas, haut] de chaque carte (époque × carte, lot H4a, NIVEAU_HEROS.md §1.4) : monstres au niveau du
## héros borné par la bande. Un héros sous la bande y joue à son niveau d'équipement mais affronte des monstres du bas
## de la bande ; au-dessus, il écrase la carte (pas de synchronisation en Aventure).
const BANDS := [
	[[1, 23], [18, 33], [28, 43]],
	[[38, 48], [43, 53], [48, 60]],
	[[55, 65], [60, 70], [65, 75]],
	[[70, 80], [75, 85], [80, 90]],
]
## PV des monstres et des boss de chaque carte (M′ ; remplace l'ancien multiplicateur par époque, lot H4a). Ils s'appliquent
## à des monstres de niveau 1 à 90 (×1,1 par niveau) face à des pièces qui comptent à leur niveau. I-1 : un compte neuf atteint
## le boss une fois sur deux (pilote) ; les autres : le boss tombe en ≈ 1 / 1,5 / 2 min pour un héros au haut de la bande avec
## les pièces de la carte à +5 (sonde tools/boss_ttk.py, scénario « bande »). Creux des 3es cartes III et IV : leurs pièces
## éveillées. Mesures : R_H4a.md.
const MAP_MULT := [
	[0.35, 1.3, 2.1],
	[4.4, 7.0, 24.0],
	[46.0, 121.0, 25.0],
	[410.0, 450.0, 290.0],
]
## Dégâts des monstres de chaque carte (lot H4a) : M′ règle les PV (temps pour tuer, sonde boss_ttk) ; les dégâts ont leur
## table, car les PV et la défense du héros montent plus vite que ses dégâts avec le niveau. BOSS_ATK : dégâts des boss.
const MAP_ATK := [
	[0.35, 0.22, 1.2],
	[0.25, 0.3, 0.45],
	[1.4, 1.0, 0.12],
	[1.1, 0.6, 0.5],
]
const BOSS_ATK := [
	[0.35, 0.22, 1.2],
	[0.15, 0.18, 0.27],
	[0.6, 0.42, 0.05],
	[0.33, 0.18, 0.15],
]
## Montée des monstres dans le temps de chaque carte (lot H4a) : le héros ne prend plus de niveau pendant la carte (seules
## les cartes le font grandir) ; PV et dégâts des monstres qui apparaissent × (1 + TIME_RAMP)^minutes, au plus TIME_RAMP_MAX
## (≈ 7 min de carte : ×1,5 ; la rage garde ses paliers).
const TIME_RAMP := 0.02
const TIME_RAMP_MAX := 2.0
## Défense des monstres de l'Aventure : celle de leur niveau, au plus celle du niveau DEF_LEVEL[carte] (lot H4a). La défense
## d'un monstre suit ×1,1 par niveau et réduit les coups de 100 / (100 + défense) : au niveau 90 elle dépassait 10 000 et
## un coup ne faisait plus que 1 % (sonde boss_ttk, R_H4a.md) ; plafonnée, elle reste celle des cartes d'avant les bandes.
const DEF_LEVEL := [18, 28, 38]
## PE conseillée de chaque carte (page de la Survie) : PE de l'équipement « correct » de la carte (ses pièces à +5, sonde de
## R_H4a) rapportée à la PE attendue (GearPower.expected) au niveau de la carte pour le héros ; carte I-1 : l'équipement de
## départ d'un compte neuf (elle se joue dès le niveau 1).
const ADVISED_RATIO := [[0.66, 1.35, 1.25], [1.2, 1.17, 1.52], [1.39, 1.6, 1.6], [1.75, 1.74, 1.72]]
## Rang des gemmes et des coffres du joaillier de l'Aventure : échelle de niveaux de butin [début, fin] de chaque carte
## (celle d'avant le lot H4a, gardée telle quelle : l'économie des gemmes ne bouge pas avec les bandes). La place du héros
## dans la bande de la carte choisit le point de l'échelle ; + RunDirector.GEM_EPOCH_LEVELS par époque.
const GEM_SCALE := [[1, 15], [13, 25], [23, 35]]
## Modèle d'avant le lot H4a (plafond de niveau 15 / 25 / 35 par carte, monstres ×0,85 / 1,7 / 3,4 / 7 par époque) :
## SANS EFFET dans le jeu. Gardé pour tools/progression_sim (modèle par défaut, sans --heros), tools/hl_probe (« jeu
## d'avant ») et le calcul des PV de boss de référence ([member BOSS_HP_MAP]).
const OLD_CAPS := [15, 25, 35]
const OLD_MONSTER_MULT := [0.85, 1.7, 3.4, 7.0]
## PV des boss de la Survie (passe P11, retour du joueur : « nos dégâts scalent à l'infini, le boss de la 3e carte a des
## PV ridicules ») : FIXES par carte et par époque, jamais calculés d'après la PE du héros ni sa progression dans la run
## (sinon il suffirait de foncer au boss). Lot H4a : ils suivent le NIVEAU du boss (celui du héros borné par la bande + 1,
## fixe pendant la partie) comme tout monstre (×1,1 par niveau) : [method boss_hp].
## PV au niveau de référence (plafond d'avant + 1) = BOSS_HP_MAP[carte] × BOSS_HP_EPOCH[époque] × BOSS_HP_ADJ, puis
## × M′ de la carte / ancien multiplicateur d'époque (même rapport de force que les monstres) × 1,1^(niveau − référence).
## Réglés au pilote (tools/boss_ttk.py, R_P11.md) pour qu'une BONNE run de la carte le tue en ≈ 1 / 1,5 / 2 min ; une run
## « rushée » met 4 à 8 min et se heurte à la rage du boss.
const BOSS_HP_MAP := [80000.0, 370000.0, 1750000.0]
## Facteur d'époque des PV du boss : les dégâts d'une bonne run grandissent avec l'équipement du hub de l'époque
## (mesurés au pilote, combats longs : ×1 / ×1,7-2,4 / ×3,9-4,9 / ×3,9-6,9 selon la carte).
const BOSS_HP_EPOCH := [1.0, 2.0, 4.0, 5.5]
## Réglage par carte des PV des boss (lot H4a, mesuré au pilote : R_H4a.md) : le pilote automatique frappe 2 à 3 fois moins
## que la sonde ; un combat trop long croise la rage du boss (2:30 à la 1re carte), qui tue.
const BOSS_HP_ADJ := [
	[1.0, 1.0, 1.0],
	[0.6, 1.0, 1.0],
	[0.8, 1.0, 1.0],
	[0.7, 0.6, 0.45],
]
## Rage du boss (passe P11) : après BOSS_RAGE_AT[carte] secondes dans l'arène, les dégâts du boss suivent les paliers de
## la rage de la carte (RunDirector.RAGE_TIERS, une minute par palier : ×1,1, ×2, ×11, ×101). Environ deux fois le
## temps d'une bonne run : une run ordinaire passe encore, une run rushée ne finit pas le combat.
const BOSS_RAGE_AT := [150.0, 180.0, 240.0]


## Mesures d'équilibrage seulement (arguments --mult-scale= / --boss-scale= du monde, tools/sim_survie.py --extra) : facteurs
## sur M′ et sur les PV des boss, pour essayer un réglage sans toucher aux tables. 1 en jeu.
static var test_mult := 1.0
static var test_boss := 1.0
static var test_atk := 1.0


## PV fixes du boss de la carte [param stage] de l'époque [param epoch] (sans rang héroïque ni Menace), au niveau
## [param level] du boss (par défaut : le haut de la bande + 1, héros au sommet de la carte).
static func boss_hp(epoch: int, stage: int, level := -1) -> float:
	var e := clampi(epoch, 1, BANDS.size())
	var s := clampi(stage, 1, 3)
	var ref := int(OLD_CAPS[s - 1]) + 1
	var lv := level if level > 0 else int(band(e, s).y) + 1
	return float(BOSS_HP_MAP[s - 1]) * float(BOSS_HP_EPOCH[e - 1]) * float(BOSS_HP_ADJ[e - 1][s - 1]) * test_boss \
		* float(MAP_MULT[e - 1][s - 1]) / float(OLD_MONSTER_MULT[e - 1]) * pow(1.1, lv - ref)


## Partie d'Aventure en cours (la Survie : ni Survivant, ni Battle royale, qui gardent le socle de la Survie).
static func adventure() -> bool:
	return Run.active and Run.survival and not Survivor.active and not Royale.active


## Bande de niveau de la carte [param stage] de l'époque [param epoch] : (bas, haut).
static func band(epoch: int, stage: int) -> Vector2i:
	var b: Array = BANDS[clampi(epoch, 1, BANDS.size()) - 1][clampi(stage, 1, 3) - 1]
	return Vector2i(int(b[0]), int(b[1]))


## Niveau de la carte pour un héros de niveau [param hero_level] : son niveau borné par la bande (monstres, butin).
static func map_level(epoch: int, stage: int, hero_level: int) -> int:
	var b := band(epoch, stage)
	return clampi(hero_level, b.x, b.y)


## PV des monstres de la carte (M′).
static func map_mult(epoch: int, stage: int) -> float:
	return float(MAP_MULT[clampi(epoch, 1, MAP_MULT.size()) - 1][clampi(stage, 1, 3) - 1]) * test_mult


## Dégâts des monstres (ou du boss, [param boss]) de la carte.
static func map_atk(epoch: int, stage: int, boss := false) -> float:
	var t: Array = BOSS_ATK if boss else MAP_ATK
	return float(t[clampi(epoch, 1, t.size()) - 1][clampi(stage, 1, 3) - 1]) * test_atk


## Montée des monstres au temps [param t] (s) de la carte.
static func time_ramp(t: float) -> float:
	return minf(pow(1.0 + TIME_RAMP, maxf(t, 0.0) / 60.0), TIME_RAMP_MAX)


## Niveau de butin du rang des gemmes ([member GEM_SCALE]) pour un héros de niveau [param hero_level] sur la carte.
static func gem_scale_level(epoch: int, stage: int, hero_level: int) -> int:
	var b := band(epoch, stage)
	var g: Array = GEM_SCALE[clampi(stage, 1, 3) - 1]
	var t := clampf(float(map_level(epoch, stage, hero_level) - b.x) / float(maxi(b.y - b.x, 1)), 0.0, 1.0)
	return roundi(lerpf(float(g[0]), float(g[1]), t))


## PE conseillée de la carte [param stage] de l'époque [param epoch] pour un héros de niveau [param hero_level].
static func advised_power(epoch: int, stage: int, hero_level: int) -> int:
	var r := float(ADVISED_RATIO[clampi(epoch, 1, ADVISED_RATIO.size()) - 1][clampi(stage, 1, 3) - 1])
	return GearPower.required(map_level(epoch, stage, hero_level), r)


## « Niv. 18-33 » : la bande d'une carte en texte court.
static func band_text(epoch: int, stage: int) -> String:
	var b := band(epoch, stage)
	return "Niv. %d-%d" % [b.x, b.y]


static func boss_rage_at(stage: int) -> float:
	return float(BOSS_RAGE_AT[clampi(stage, 1, BOSS_RAGE_AT.size()) - 1])


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


## Plafond de niveau de la carte d'avant le lot H4a (sans effet dans le jeu : outils de mesure, voir [member OLD_CAPS]).
static func old_cap(stage: int) -> int:
	return int(OLD_CAPS[clampi(stage, 1, OLD_CAPS.size()) - 1])


## Multiplicateur d'époque des monstres d'avant le lot H4a (sans effet dans le jeu, voir [member OLD_MONSTER_MULT]).
static func old_monster_mult(epoch: int) -> float:
	return float(OLD_MONSTER_MULT[clampi(epoch, 1, OLD_MONSTER_MULT.size()) - 1])


## Étoiles d'époque (3 par époque) : ★1 gagner l'époque, ★2 la gagner sans résurrection, ★3 réussir le défi
## de l'époque. Elles sont gardées dans `Profile.records["epoch_stars_<n>"]` (masque de bits).
const CHALLENGES := [
	"Vaincre le boss de la 3e carte avant la rage",
	"Finir avec 12 trophées",
	"Finir sans changer d'arme",
	"Ouvrir 45 coffres",
]
## Défi de l'époque IV (passe N2 : plus d'enclume en Survie) : coffres ouverts sur la run (texte ci-dessus).
const CHEST_CHALLENGE := 45


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
			ok = Run.chests_total >= CHEST_CHALLENGE
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


## Texte court d'une map : « niveau 23 · mythique » (niveau des pièces de ses coffres : en Aventure, jamais au-dessus du
## niveau de héros de la partie, lot H4a).
static func map_text(epoch: int, stage: int) -> String:
	var m := map_def(epoch, stage)
	var lv := int(m.armor)
	if adventure() and Run.hero_level > 0:
		lv = mini(lv, Run.hero_level)
	return "niveau %d · %s" % [lv, rarity_name(m)]


static func rarity_name(m: Dictionary) -> String:
	if m.get("awakened", false):
		return "éveillé"
	return "légendaire" if int(m.rarity) >= Items.LEGENDARY else "mythique"
