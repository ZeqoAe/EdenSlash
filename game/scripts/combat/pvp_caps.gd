class_name PvpCaps
extends RefCounted
## Plafonds des statistiques en combat entre joueurs (JcJ : duel contre un adversaire, plus
## tard contre d'autres joueurs), comme dans Eden : avec un équipement très poussé, vitesse
## d'attaque ou critiques n'ont plus de sens et l'auto-attaque suffit à tout raser. En run,
## dans la Tour, l'exploration et les donjons, rien n'est plafonné.
## Valeurs en multiplicateurs (1.0 = 100 %) ; dégâts critiques : bonus (2.0 = coups critiques ×3,00).

const CAPS := {
	"atk_speed": 3.0,  # vitesse d'attaque 300 %
	"cast_speed": 3.0,  # vitesse d'incantation 300 %
	"crit": 1.0,  # critique physique 100 %
	"mcrit": 1.0,  # critique magique 100 %
	"crit_dmg": 2.0,  # dégâts critiques ×3,00
	"move_mult": 2.0,  # vitesse de déplacement 200 %
	"lifesteal": 0.2,  # vol de vie 20 %
	"heal_power": 3.0,  # puissance de soin 300 %
	"dmg_mult": 3.0,  # dégâts +200 %
	"dot_bonus": 3.0,  # dégâts sur la durée +200 %
	"area_mult": 2.0,  # zone d'effet +100 %
	"reach_mult": 2.0,  # portée +100 %
}


## Combat entre joueurs en cours (mode Duel).
static func active() -> bool:
	return Duel.active


## Ramène les statistiques de [param p] sous les plafonds ; rend les statistiques plafonnées.
static func apply(p: Player) -> Array:
	var capped: Array = []
	for k in CAPS:
		var v := float(p.get(k))
		if v > float(CAPS[k]):
			p.set(k, float(CAPS[k]))
			capped.append(k)
	return capped
