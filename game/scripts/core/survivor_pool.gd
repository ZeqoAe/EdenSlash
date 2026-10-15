class_name SurvivorPool
extends RefCounted
## Ce que les cartes du Survivant peuvent proposer (lot S2, DECISIONS_JOUEUR §1 et §5) : toutes les pièces des sets de
## niveau 90, les 17 types d'arme, les passifs (effets des cartes communes) ; rien ne dépend de la collection du compte.
##
## Lot S1 : squelette.


## Modèles d'Eden de l'emplacement [param slot] proposables ([] : aucun).
static func pieces(_slot: String) -> Array:
	return []


## Types d'arme proposables : les 17 du jeu.
static func weapon_types() -> Array:
	return WeaponAttacks.SPECS.keys()


## Passifs proposables (ids de Boons).
static func boons() -> Array:
	return []
