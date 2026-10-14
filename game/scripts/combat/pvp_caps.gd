class_name PvpCaps
extends RefCounted
## Plafonds des statistiques en combat entre joueurs (JcJ : duel contre un adversaire, plus
## tard contre d'autres joueurs), comme dans Eden : avec un équipement très poussé, vitesse
## d'attaque ou critiques n'ont plus de sens et l'auto-attaque suffit à tout raser. En run,
## dans la Tour, l'exploration et les donjons, rien n'est plafonné.
## Valeurs en multiplicateurs (1.0 = 100 %) ; dégâts critiques : bonus (2.0 = coups critiques ×3,00).

const CAPS := {
	"atk_speed": 2.0,  # vitesse d'attaque 200 % (au-delà, l'auto-attaque en boucle écrase tout)
	"cast_speed": 3.0,  # vitesse d'incantation 300 %
	"crit": 0.5,  # critique physique 50 % (un coup sur deux, pas tous)
	"mcrit": 0.5,  # critique magique 50 %
	"crit_dmg": 1.5,  # dégâts critiques ×2,50
	"move_mult": 2.0,  # vitesse de déplacement 200 %
	"lifesteal": 0.2,  # vol de vie 20 %
	"heal_power": 1.5,  # puissance de soin 150 %
	"cdr": 0.3,  # recharges réduites de 30 % au plus
	"dmg_mult": 3.0,  # dégâts +200 %
	"dot_bonus": 3.0,  # dégâts sur la durée +200 %
	"area_mult": 2.0,  # zone d'effet +100 %
	"reach_mult": 2.0,  # portée +100 %
}


## Soins reçus en duel (sorts, régénération, vol de vie) : un tiers environ, sinon deux
## soigneurs ne se tuent jamais (un sort de soin rend 25 % des PV × la puissance de soin).
const HEAL_MULT := 0.35
## Acharnement : passé [constant PRESSURE_START] s de combat, les dégâts entre héros doublent
## toutes les [constant PRESSURE_STEP] s et les soins baissent d'autant ; même deux tanks
## soigneurs finissent par tomber (vers 1 min 30).
const PRESSURE_START := 30.0
const PRESSURE_STEP := 20.0
## Échelle des dégâts entre héros en duel : en miroir (même build), un coup de multiplicateur
## 1 retire 1,2 % des PV de la cible avant défense, quel que soit le niveau. Les stats comptent
## toujours : entre deux héros, l'avantage suit le produit puissance × PV, en racine (voir
## [method damage_mult]). Sans ça, l'équipement change tout d'un niveau à l'autre : au niveau 25
## il triple l'attaque, au 90 il multiplie les PV par 60 (combats de 4 s ou éternels).
const DAMAGE_SCALE := 0.012  # 0.009 avant 0.1.118 (critiques à 100 % et auto-attaque pleine)
## Auto-attaque (coups du combo de l'arme) entre héros en duel : dégâts × BASIC_MULT et sans
## contrôle (renversement, gel…) ni attraction : elle n'interrompt plus l'adversaire, les sorts
## restent l'outil pour le faire. Sinon, avec la vitesse d'attaque au plafond, l'auto-attaque
## en boucle du Guerrier (crochet qui renverse 1 s) bat tous les builds.
const BASIC_MULT := 0.7
## Réduction des dégâts par la défense en duel : 60 % au plus.
const MAX_MITIGATION := 0.6

## Temps de combat de la manche en cours (avancé par le duel ou l'arène d'IA).
static var elapsed := 0.0


## Combat entre joueurs en cours (mode Duel).
static func active() -> bool:
	return Duel.active


## Multiplicateur d'acharnement (1 avant [constant PRESSURE_START] s).
static func pressure() -> float:
	return pow(2.0, maxf(0.0, elapsed - PRESSURE_START) / PRESSURE_STEP)


## Multiplicateur des dégâts d'un héros [param src] sur un héros [param dst] en duel
## (acharnement compris) : le coup (déjà proportionnel à la puissance de l'attaquant) est
## ramené à l'échelle √(PV cible × PV attaquant) / √(puissance attaquant × puissance cible).
static func damage_mult(dst: Combatant, src: Combatant) -> float:
	var hp := sqrt(maxf(dst.max_hp, 1.0) * maxf(src.max_hp, 1.0))
	var pw := sqrt(maxf(src.power(), 1.0) * maxf(dst.power(), 1.0))
	return DAMAGE_SCALE * pressure() * hp / pw


## Part d'un coup subie en duel par un héros de défense [param def] face à un attaquant de
## défense [param src_def] : la référence est leur moyenne géométrique (la défense d'un
## équipement complet va de quelques centaines au niveau 25 à des centaines de milliers au 90).
## Même défense : 50 % ; deux fois plus : 41 % ; quatre fois plus : 33 % (60 % de réduction au plus).
static func taken(def: float, src_def: float) -> float:
	var d := maxf(def, 1.0)
	var k := sqrt(d * maxf(src_def, 1.0))
	return maxf(k / (k + d), 1.0 - MAX_MITIGATION)


## Soins reçus en duel.
static func heal_mult() -> float:
	return HEAL_MULT / pressure()


## Coup de [param src] sur [param dst] entre deux héros en duel.
static func between_heroes(src: Combatant, dst: Combatant) -> bool:
	return active() and src != dst and Combatant.is_hero(src) and Combatant.is_hero(dst)


## Ramène les statistiques de [param p] sous les plafonds ; rend les statistiques plafonnées.
static func apply(p: Player) -> Array:
	var capped: Array = []
	for k in CAPS:
		var v := float(p.get(k))
		if v > float(CAPS[k]):
			p.set(k, float(CAPS[k]))
			capped.append(k)
	return capped
