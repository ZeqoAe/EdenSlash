class_name Modifiers
extends RefCounted
## Table commune des modificateurs de règles (conception, §3.2) : lue par les rangs héroïques, le
## Défi du jour et les étages-épreuves de la Tour. Chaque modificateur change des clés d'un profil de
## ModeRules : "mul" multiplie, "add" ajoute, "set" remplace. `cost` : difficulté ajoutée (pour les
## récompenses par rang). Les clés dont le consommateur n'existe pas encore (élites, enclume…) seront
## lues quand leur mode arrivera.

const LIST := {
	"heal_half": {"text": "Soins reçus divisés par deux", "cost": 1, "effect": {"heal_mult": ["mul", 0.5]}},
	"elites_double": {"text": "Élites deux fois plus nombreuses", "cost": 2, "effect": {"elite_count": ["mul", 2.0]}},
	"chests_plus": {"text": "Coffres +30 % (et monstres plus durs)", "cost": 1, "effect": {"chest_gold": ["mul", 1.3], "mob_hp": ["mul", 1.15]}},
	"anvil_cap": {"text": "Enclume plafonnée à +6", "cost": 1, "effect": {"anvil_max": ["set", 6]}},
	"one_life": {"text": "Une seule vie", "cost": 3, "effect": {"resurrections": ["set", 0]}},
	"double_bolts": {"text": "Projectiles des monstres doublés", "cost": 2, "effect": {"mob_projectiles": ["mul", 2.0]}},
}


## Applique les modificateurs [param ids] à la valeur [param value] de la clé [param key].
static func apply(key: String, value: Variant, ids: Array) -> Variant:
	for id in ids:
		var e: Array = Modifiers.LIST.get(String(id), {}).get("effect", {}).get(key, [])
		if e.is_empty():
			continue
		match String(e[0]):
			"mul":
				value = float(value) * float(e[1])
			"add":
				value = float(value) + float(e[1])
			"set":
				value = e[1]
	return value


## Difficulté ajoutée par une liste de modificateurs.
static func cost(ids: Array) -> int:
	var c := 0
	for id in ids:
		c += int(Modifiers.LIST.get(String(id), {}).get("cost", 0))
	return c
