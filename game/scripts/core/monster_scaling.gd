class_name MonsterScaling
extends RefCounted
## Niveau et puissance des monstres de la carte (passe P15, retour du joueur : « leur niveau doit suivre le nôtre, et
## leur donner des PV et des dégâts quand on commence à être stuffé : je sens que je peux rouler sur le contenu »).
## Monstres normaux et élites seulement : les boss gardent leurs PV fixes (passe P11, Epochs.boss_hp).
##
## 1. Niveau : Aventure (lot H4a) : niveau de héros + décalage, borné par la bande de la carte (Epochs.BANDS), + palier
##    (élite, camp), +3 en rage ; ailleurs : max(courbe du temps, niveau du héros + décalage) + palier, plafonné par la
##    zone. Le décalage va de LEVEL_OFFSET[0] au début de la carte à LEVEL_OFFSET[1] à l'heure de la rage.
## 2. Puissance : l'indice d'équipement du héros (gear_index : PE de l'équipement porté, trouvailles de la carte
##    comprises, rapportée à la PE attendue au niveau du héros : un nombre sans niveau, ≈ note moyenne / 10)
##    est comparé à la bande pour laquelle l'époque est réglée (EPOCH_BAND). Dans la bande : rien ne change (l'équipement
##    attendu de l'époque et les trouvailles ordinaires de la carte ne rendent pas les monstres plus forts). Au-dessus,
##    PV et dégâts montent de HP_SLOPE / ATK_SLOPE par unité de ln(indice / haut de la bande) ; en dessous, ils baissent
##    de même ; bornes HP_RANGE / ATK_RANGE. Les cartes, trophées et améliorations d'arme n'y comptent pas : ils sont la
##    progression attendue de la run (courbe du temps, bâtir son jeu doit payer). La valeur suivie est lissée
##    (SMOOTH_TIME) et ne s'applique qu'aux monstres qui apparaissent : jamais de saut.
##
## Empilement des PV d'un monstre normal (Survie) : niveau (×1,1 par niveau) × carte (Epochs.MAP_MULT) × montée dans le
## temps (Epochs.time_ramp) × rangs héroïques × montée du début de carte (EARLY_EASE) × rôle (SpawnDirector.ROLES) ×
## [puissance × Menace × pacte, plafonné à STACK_HP_CAP] × rage (paliers voulus démesurés : c'est un chronomètre).
## Dégâts : niveau × zone (ZONE_DAMAGE) × carte × temps × rangs × montée × rôle × [puissance × pacte ≤ STACK_ATK_CAP] × rage.

const LEVEL_OFFSET := [-1.0, -0.5]  # niveau du monstre - niveau du héros : début de carte, heure de la rage
const HP_RANGE := [0.9, 1.6]
const ATK_RANGE := [0.9, 1.4]
const HP_SLOPE := 0.6  # PV : +42 % pour un indice double du haut de la bande (avant bornes)
const ATK_SLOPE := 0.35  # dégâts : +24 % pour un indice double
## Bande d'indice [bas, haut] pour laquelle chaque époque est réglée (tools/power_probe.tscn, médiane de 5 classes ;
## départ 0,68, pièces de la carte 1 à +0 0,94, à +3 1,2, époque I à +5 1,28, époque I optimisée 1,9, époque II
## optimisée 2,4, époques III-IV 2,5-2,7). Époque I : du compte neuf (passe P5) aux pièces trouvées sur la carte ;
## II : pièces de l'époque I à +0 à +5 ; III : pièces de l'époque II à +10 ; IV : équipement complet (passe E6, R_E6.md).
const EPOCH_BAND := [[0.6, 0.95], [1.0, 1.35], [1.9, 2.45], [2.2, 2.7]]
const SMOOTH_TIME := 45.0  # s : constante de temps du lissage (63 % du chemin en 45 s)
const STACK_HP_CAP := 2.6  # puissance × Menace × pacte, PV
const STACK_ATK_CAP := 1.6  # puissance × pacte, dégâts


## Décalage de niveau monstre / héros au temps [param t] d'une carte dont la rage arrive à [param rage_at].
static func level_offset(t: float, rage_at: float) -> float:
	return lerpf(float(LEVEL_OFFSET[0]), float(LEVEL_OFFSET[1]), clampf(t / maxf(rage_at, 1.0), 0.0, 1.0))


## Indice d'équipement du héros en run : PE de l'équipement porté / PE attendue à son niveau. ≈ 0,4 pour
## l'équipement de départ, ≈ 1 pour des mythiques améliorés, ≈ 2 pour un équipement optimisé.
static func gear_index(gear: Dictionary = {}) -> float:
	var g := gear if not gear.is_empty() else Profile.equipped
	var lv := Run.hero_level if Run.active and Run.hero_level > 0 else GearPower.target_level()
	return float(GearPower.gear_power(g)) / maxf(float(GearPower.expected(lv)), 1.0)


static func epoch_band(epoch: int) -> Array:
	return EPOCH_BAND[clampi(epoch, 1, EPOCH_BAND.size()) - 1]


## Coefficients visés [PV, dégâts] pour un indice [param index] face à la bande [param band] ([bas, haut]).
static func target(index: float, band: Array) -> Vector2:
	var x := 0.0
	if index > float(band[1]):
		x = log(index / float(band[1]))
	elif index < float(band[0]):
		x = log(maxf(index, 0.01) / float(band[0]))
	return Vector2(clampf(1.0 + HP_SLOPE * x, HP_RANGE[0], HP_RANGE[1]), clampf(1.0 + ATK_SLOPE * x, ATK_RANGE[0], ATK_RANGE[1]))


## Un pas de lissage de [param cur] vers [param goal] en [param dt] secondes.
static func smooth(cur: Vector2, goal: Vector2, dt: float) -> Vector2:
	return cur.lerp(goal, 1.0 - exp(-dt / SMOOTH_TIME))


## Coefficients [PV, dégâts] à appliquer, plafonnés avec les autres multiplicateurs dynamiques : [param other_hp]
## (Menace × pacte) et [param other_atk] (pacte). Le plafond ne fait jamais descendre sous 1 un coefficient > 1.
static func capped(k: Vector2, other_hp: float, other_atk: float) -> Vector2:
	var hp := k.x if k.x <= 1.0 else maxf(1.0, minf(k.x, STACK_HP_CAP / maxf(other_hp, 0.01)))
	var atk := k.y if k.y <= 1.0 else maxf(1.0, minf(k.y, STACK_ATK_CAP / maxf(other_atk, 0.01)))
	return Vector2(hp, atk)
