class_name Boons
extends RefCounted
## Cartes de build communes à toutes les classes, en plus des passifs de classe
## (data/classes.json). Inspirées des roguelites (Hades, Vampire Survivors, Risk of
## Rain, Diablo) : zone, portée, dégâts ciblés, effets déclenchés (procs), et des
## cartes légendaires qui n'apparaissent qu'avec leurs prérequis (évolutions).
##
## Champs : id, name, desc, max (niveaux : 10 au plus), rarity (fréquence de la carte :
## common, rare, epic, legendary ; la rareté affichée est tirée à chaque offre, voir Cards),
## stat (statistiques par carte commune), procs (effets déclenchés, voir Procs), per_stack
## (bonus des procs par carte commune en plus), requires (cartes nécessaires), instant
## (effet immédiat, pas un passif : Rappel).
## Les cartes sont modifiables dans l'éditeur de cartes du mode dev (Boons.all()).
##
## Statistiques propres aux cartes : area (rayon des zones), reach (portée de l'attaque
## de base et des compétences en ligne / éventail / élan), dmg_pct, elite_dmg, dot_pct,
## proj (projectiles de l'auto-attaque, ou frappes en plus pour la mêlée), pierce
## (perforation), bounce (rebonds), execute (seuil d'exécution des monstres normaux),
## rerolls (relances de cartes). L'auto-attaque de chaque arme réagit à certaines d'entre
## elles (WeaponAttacks : « Grandit avec »).

const RARITY := {
	"common": {"name": "Commune", "color": Color(0.85, 0.85, 0.88), "weight": 1.0},
	"rare": {"name": "Rare", "color": Color(0.4, 0.7, 1.0), "weight": 0.6},
	"epic": {"name": "Épique", "color": Color(0.78, 0.45, 1.0), "weight": 0.3},
	"legendary": {"name": "Légendaire", "color": Color(1.0, 0.6, 0.15), "weight": 0.9},
}

const LIST := [
	# --- communes : la base d'un build ---------------------------------------------------
	{"id": "wide_arc", "name": "Lame large", "rarity": "common", "max": 7, "stat": {"area": 0.14},
		"desc": "+14 % de rayon des attaques de zone (attaques, compétences, explosions, foudre et gel), +98 % au plus."},
	{"id": "long_reach", "name": "Allonge", "rarity": "common", "max": 10, "stat": {"reach": 0.15},
		"desc": "+15 % de portée : attaque de base, compétences en ligne, en éventail et élans."},
	{"id": "sharpened", "name": "Fil aiguisé", "rarity": "common", "max": 10, "stat": {"dmg_pct": 0.08},
		"desc": "+8 % de dégâts."},
	{"id": "giant_slayer", "name": "Tueur de géants", "rarity": "common", "max": 10, "stat": {"elite_dmg": 0.2},
		"desc": "+20 % de dégâts contre les élites et les boss."},
	{"id": "combo_flow", "name": "Cadence", "rarity": "common", "max": 10,
		"stat": {"atk_speed": 0.08},
		"desc": "+8 % de vitesse d'attaque : l'auto-attaque part plus souvent."},
	{"id": "incantation", "name": "Incantation vive", "rarity": "common", "max": 10,
		"stat": {"cast_speed": 0.1},
		"desc": "+10 % de vitesse d'incantation : armes à incantation (sceptre, bâton, grimoire) plus rapides, zones qui tombent plus tôt."},
	{"id": "heavy_finisher", "name": "Main lourde", "rarity": "common", "max": 10,
		"stat": {"basic_dmg": 0.12},
		"desc": "+12 % de dégâts de l'auto-attaque (arme principale et secondaire)."},
	{"id": "multishot", "name": "Projectile supplémentaire", "rarity": "epic", "max": 5,
		"stat": {"proj": 1.0},
		"desc": "+1 projectile à l'auto-attaque (une flèche, une zone ou une boule de feu de plus) ; les armes de mêlée frappent une fois de plus."},
	{"id": "piercing", "name": "Perforation", "rarity": "rare", "max": 5,
		"stat": {"pierce": 1.0},
		"desc": "Les projectiles traversent un ennemi de plus."},
	{"id": "ricochet", "name": "Ricochet", "rarity": "rare", "max": 5,
		"stat": {"bounce": 1.0},
		"desc": "Les projectiles rebondissent sur un ennemi proche de plus (8 m)."},
	{"id": "deep_wounds", "name": "Plaies profondes", "rarity": "common", "max": 10, "stat": {"dot_pct": 0.3},
		"desc": "+30 % de dégâts des saignements et des brûlures."},
	{"id": "lingering", "name": "Venin tenace", "rarity": "common", "max": 10, "stat": {"dot_dur": 0.15, "dot_pct": 0.1},
		"desc": "Effets sur la durée (poison, brûlure, saignement) plus longs et plus forts."},
	{"id": "magnet", "name": "Aimant", "rarity": "common", "max": 10, "stat": {"pickup": 0.25},
		"desc": "Agrandit la zone de collecte : orbes d'expérience et objets viennent de plus loin."},
	{"id": "scholar", "name": "Érudit", "rarity": "rare", "max": 10, "stat": {"xp_pct": 0.08},
		"desc": "Plus d'expérience par orbe ramassée."},
	{"id": "recall", "name": "Rappel", "rarity": "rare", "max": 99, "instant": true,
		"desc": "Effet immédiat : toutes les orbes d'expérience et tous les objets de la carte reviennent vers toi."},
	{"id": "fortune", "name": "Bonne étoile", "rarity": "common", "max": 10, "stat": {"rerolls": 1, "crit": 0.03},
		"desc": "+1 relance de cartes et +3 % de critique."},
	{"id": "precision", "name": "Précision", "rarity": "common", "max": 10, "stat": {"crit": 0.025},
		"desc": "+2,5 % de chances de coup critique."},
	{"id": "toughness", "name": "Peau de fer", "rarity": "common", "max": 10, "stat": {"def_pct": 0.06},
		"desc": "+6 % de défense."},
	{"id": "brute", "name": "Force brute", "rarity": "common", "max": 10, "stat": {"atk_pct": 0.05},
		"desc": "+5 % d'attaque (physique et magique)."},
	{"id": "arcana", "name": "Arcanes", "rarity": "common", "max": 10, "stat": {"matk_pct": 0.05},
		"desc": "+5 % d'attaque magique."},
	# --- rares : les effets déclenchés -----------------------------------------------------
	{"id": "static_blade", "name": "Lame statique", "rarity": "rare", "max": 10,
		"procs": [{"trigger": "skill_hit", "chance": 0.35, "cd": 4.0, "effect": "lightning", "mult": 1.5, "chain": 3, "radius": 7.0}],
		"per_stack": {"chance": 0.15, "mult": 0.4, "chain": 1},
		"desc": "35 % de chances à l'impact d'une compétence : la foudre tombe et rebondit sur 3 monstres (150 %, 7 m, recharge 4 s)."},
	{"id": "frost_edge", "name": "Fil de givre", "rarity": "rare", "max": 10,
		"procs": [{"trigger": "hit", "chance": 0.1, "cd": 2.5, "effect": "freeze", "duration": 1.5, "radius": 1.5}],
		"per_stack": {"chance": 0.06, "duration": 0.3},
		"desc": "10 % de chances à l'impact : gèle la cible et ses voisins (1,5 s, recharge 2,5 s)."},
	{"id": "ember", "name": "Braise", "rarity": "rare", "max": 10,
		"procs": [{"trigger": "crit", "chance": 1.0, "cd": 0.5, "effect": "burn", "duration": 4.0, "radius": 2.5}],
		"per_stack": {"radius": 0.8, "duration": 1.0},
		"desc": "Les coups critiques enflamment la zone autour de la cible (2,5 m, brûlure 4 s : 25 % de l'attaque par seconde)."},
	{"id": "volatile", "name": "Cadavres explosifs", "rarity": "rare", "max": 10,
		"procs": [{"trigger": "kill", "chance": 0.3, "cd": 0.25, "effect": "explosion", "mult": 1.2, "radius": 3.5}],
		"per_stack": {"chance": 0.15, "mult": 0.3},
		"desc": "30 % de chances qu'un monstre tué explose (3,5 m, 120 %). Les explosions peuvent s'enchaîner."},
	{"id": "shockwave", "name": "Onde de choc", "rarity": "rare", "max": 10,
		"procs": [{"trigger": "basic_hit", "chance": 0.15, "cd": 1.5, "effect": "explosion", "mult": 1.0, "radius": 4.0,
			"color": Color(1.0, 0.9, 0.5, 0.9)}],
		"per_stack": {"mult": 0.4, "radius": 0.6, "chance": 0.05},
		"desc": "15 % de chances qu'une auto-attaque libère une onde de choc sur sa cible (4 m, 100 %, recharge 1,5 s)."},
	{"id": "wind_step", "name": "Pas du vent", "rarity": "rare", "max": 10,
		"procs": [{"trigger": "dodge", "chance": 1.0, "cd": 5.0, "effect": "buff", "status": "haste", "duration": 3.0,
			"then": [{"effect": "buff", "status": "fury", "duration": 3.0}]}],
		"per_stack": {"duration": 0.4, "cd": -0.3},
		"desc": "Esquiver donne Hâte (+30 % de vitesse) et Fureur (+25 % de dégâts) pendant 3 s (recharge 5 s)."},
	{"id": "battle_trance", "name": "Transe guerrière", "rarity": "rare", "max": 10,
		"procs": [{"trigger": "crit", "chance": 1.0, "cd": 6.0, "effect": "buff", "status": "frenzy", "duration": 4.0}],
		"per_stack": {"duration": 0.4, "cd": -0.4},
		"desc": "Un coup critique donne Frénésie : +30 % de vitesse d'attaque pendant 4 s (recharge 6 s)."},
	{"id": "hunter_eye", "name": "Œil du chasseur", "rarity": "rare", "max": 10,
		"procs": [{"trigger": "kill", "chance": 1.0, "cd": 8.0, "effect": "buff", "status": "keen", "duration": 5.0}],
		"per_stack": {"duration": 0.5, "cd": -0.5},
		"desc": "Tuer un monstre donne Œil acéré : +25 % de critique pendant 5 s (recharge 8 s)."},
	{"id": "second_wind", "name": "Second souffle", "rarity": "rare", "max": 10,
		"procs": [{"trigger": "low_hp", "chance": 1.0, "cd": 60.0, "effect": "heal", "amount": 0.3,
			"then": [{"effect": "buff", "status": "barrier", "duration": 4.0}, {"effect": "nova", "radius": 4.0, "duration": 1.5}]}],
		"per_stack": {"amount": 0.03, "cd": -4.0},
		"desc": "Sous 30 % de PV : rend 30 % des PV, Barrière 4 s et gèle autour de toi (une fois par minute)."},
	{"id": "momentum", "name": "Élan meurtrier", "rarity": "rare", "max": 10,
		"procs": [{"trigger": "kill", "chance": 1.0, "cd": 0.15, "effect": "cdr", "amount": 0.3}],
		"per_stack": {"amount": 0.2},
		"desc": "Chaque monstre tué réduit les recharges de 0,3 s (pas plus de 1,5 s par seconde)."},
	# --- épiques -------------------------------------------------------------------------
	{"id": "executioner", "name": "Exécuteur", "rarity": "epic", "max": 10, "stat": {"execute": 0.12},
		"desc": "Les monstres normaux sous 12 % de PV sont exécutés d'un coup."},
	{"id": "echo", "name": "Écho", "rarity": "epic", "max": 10,
		"procs": [{"trigger": "skill_hit", "chance": 0.25, "cd": 1.0, "effect": "echo", "mult": 0.6}],
		"per_stack": {"chance": 0.15},
		"desc": "25 % de chances qu'une compétence frappe une 2e fois (60 % des dégâts)."},
	{"id": "frost_nova", "name": "Cœur d'hiver", "rarity": "epic", "max": 10,
		"procs": [{"trigger": "perfect", "chance": 1.0, "cd": 0.0, "effect": "nova", "radius": 5.0, "duration": 2.0},
			{"trigger": "hurt", "chance": 0.25, "cd": 8.0, "effect": "nova", "radius": 4.0, "duration": 1.5}],
		"per_stack": {"radius": 0.4, "duration": 0.2},
		"desc": "Annulation parfaite : nova de givre (5 m, gel 2 s). 25 % de chances quand tu es touché (recharge 8 s)."},
	{"id": "glass_cannon", "name": "Canon de verre", "rarity": "epic", "max": 1,
		"stat": {"dmg_pct": 0.35, "hp_pct": -0.2},
		"desc": "+35 % de dégâts, mais -20 % de PV max."},
	# --- légendaires : évolutions (prérequis) ------------------------------------------------
	{"id": "storm_lord", "name": "Seigneur de la tempête", "rarity": "legendary", "max": 1,
		"requires": ["static_blade"],
		"procs": [{"trigger": "crit", "chance": 0.5, "cd": 1.2, "effect": "lightning", "mult": 1.0, "chain": 4, "radius": 8.0}],
		"desc": "Évolution de Lame statique : les coups critiques appellent la foudre (50 %, 4 rebonds, recharge 1,2 s)."},
	{"id": "glacial_shatter", "name": "Éclat glacial", "rarity": "legendary", "max": 1,
		"requires": ["frost_edge"],
		"procs": [{"trigger": "hit", "chance": 1.0, "cd": 0.4, "effect": "explosion", "if_status": "freeze", "mult": 2.0,
			"radius": 3.0, "applies": {"chill": 3.0}, "color": Color(0.55, 0.85, 1.0, 0.9)}],
		"desc": "Évolution de Fil de givre : frapper un monstre gelé le fait voler en éclats (200 %, 3 m, ralentit autour)."},
	{"id": "phoenix_blade", "name": "Lame du phénix", "rarity": "legendary", "max": 1,
		"requires": ["ember", "volatile"],
		"procs": [{"trigger": "kill", "chance": 1.0, "cd": 0.2, "effect": "explosion", "if_status": "burn", "mult": 1.5,
			"radius": 4.0, "applies": {"burn": 4.0}}],
		"desc": "Évolution de Braise + Cadavres explosifs : un monstre en feu explose à sa mort et enflamme ses voisins."},
	{"id": "steel_tempest", "name": "Tempête d'acier", "rarity": "legendary", "max": 1,
		"requires": ["heavy_finisher", "multishot"],
		"stat": {"proj": 2.0, "area": 0.25, "basic_dmg": 0.2},
		"desc": "Évolution de Main lourde + Projectile supplémentaire : +2 projectiles (ou frappes), +25 % de zone et +20 % de dégâts de l'auto-attaque."},
]


## Icône des cartes (icônes d'effets, assets/ui/status ; icônes d'Eden pour la zone et la portée).
const ICONS := {
	"wide_arc": "res://assets/ui/skills/e0460.png", "long_reach": "res://assets/ui/skills/e0466.png",
	"sharpened": "res://assets/ui/skills/j615.png", "giant_slayer": "res://assets/ui/skills/e0465.png",
	"combo_flow": "res://assets/ui/status/frenzy.png", "heavy_finisher": "res://assets/ui/skills/e0464.png",
	"incantation": "res://assets/ui/status/flow.png", "multishot": "res://assets/ui/skills/e0466.png",
	"piercing": "res://assets/ui/skills/e0461.png", "ricochet": "res://assets/ui/status/shock.png",
	"deep_wounds": "res://assets/ui/skills/e0459.png", "fortune": "res://assets/ui/skills/j616.png",
	"static_blade": "res://assets/ui/status/shock.png", "frost_edge": "res://assets/ui/status/freeze.png",
	"ember": "res://assets/ui/status/burn.png", "volatile": "res://assets/ui/status/fury.png",
	"shockwave": "res://assets/ui/status/stun.png", "wind_step": "res://assets/ui/status/haste.png",
	"battle_trance": "res://assets/ui/status/frenzy.png", "hunter_eye": "res://assets/ui/status/keen.png",
	"second_wind": "res://assets/ui/status/barrier.png", "momentum": "res://assets/ui/status/chill.png",
	"executioner": "res://assets/ui/skills/e0461.png", "echo": "res://assets/ui/skills/e0463.png",
	"frost_nova": "res://assets/ui/status/freeze.png", "glass_cannon": "res://assets/ui/skills/e0462.png",
	"storm_lord": "res://assets/ui/status/shock.png", "glacial_shatter": "res://assets/ui/status/freeze.png",
	"phoenix_blade": "res://assets/ui/status/burn.png", "steel_tempest": "res://assets/ui/skills/e0460.png",
	"lingering": "res://assets/ui/status/poison.png", "magnet": "res://assets/ui/status/flow.png",
	"scholar": "res://assets/ui/status/regen.png", "recall": "res://assets/ui/status/haste.png",
	"precision": "res://assets/ui/status/keen.png", "toughness": "res://assets/ui/status/barrier.png",
	"brute": "res://assets/ui/skills/j615.png", "arcana": "res://assets/ui/status/shock.png",
	# passifs communs (data/classes.json)
	"vigor": "res://assets/ui/status/regen.png", "swift_blade": "res://assets/ui/status/frenzy.png",
	"bloodthirst": "res://assets/ui/status/fury.png", "light_step": "res://assets/ui/status/haste.png",
	"keen_edge": "res://assets/ui/status/keen.png", "focus": "res://assets/ui/status/flow.png",
	"air_jump": "res://assets/ui/status/evasion.png", "high_jump": "res://assets/ui/status/evasion.png",
	"dive_strike": "res://assets/ui/status/stun.png", "featherfall": "res://assets/ui/status/chill.png",
	"air_dash": "res://assets/ui/status/haste.png",
}

static var _all: Array = []


## Toutes les cartes communes, avec les modifications de l'éditeur de cartes (dev_edits.json
## -> "cards" : id -> champs remplacés ; cartes créées en jeu : « custom »).
static func all() -> Array:
	if _all.is_empty():
		var edits: Dictionary = DevEdits.data.get("cards", {})
		for b in LIST + GameData.common_passives.map(func(p): return _common(p)):
			var d: Dictionary = b.duplicate(true)
			var e = edits.get(String(b.id))
			if e is Dictionary:
				if e.get("deleted", false):
					continue
				d.merge(e, true)
			_all.append(d)
		for id in edits:
			var e = edits[id]
			if e is Dictionary and e.get("custom", false) and not e.get("deleted", false) and get_base(String(id)).is_empty():
				var d: Dictionary = e.duplicate(true)
				d["id"] = String(id)
				_all.append(d)
	return _all


## Recharge après modification (éditeur de cartes).
static func reset_cache() -> void:
	_all = []


## Carte telle que définie dans le code (sans les modifications).
static func get_base(id: String) -> Dictionary:
	for b in LIST:
		if b.id == id:
			return b
	for p in GameData.common_passives:
		if p.id == id:
			return _common(p)
	return {}


## Passif commun (data/classes.json) présenté comme une carte commune.
static func _common(p: Dictionary) -> Dictionary:
	var d := p.duplicate(true)
	d["rarity"] = String(p.get("rarity", "common"))
	return d


static func get_def(id: String) -> Dictionary:
	for b in all():
		if b.id == id:
			return b
	return {}


## Procs d'une carte de puissance [param stacks] (somme des multiplicateurs de rareté des
## cartes prises : 1 = une carte commune) ; bonus par carte commune en plus (per_stack).
static func procs_of(def: Dictionary, stacks: float) -> Array:
	var out: Array = []
	var i := 0
	for p: Dictionary in def.get("procs", []):
		var q := p.duplicate(true)
		q["id"] = "%s_%d" % [def.id, i]
		var bonus: Dictionary = def.get("per_stack", {})
		for k in bonus:
			q[k] = float(q.get(k, 0.0)) + float(bonus[k]) * (stacks - 1)
		if q.has("chain"):
			q.chain = int(q.chain)
		if float(p.get("cd", 0.0)) > 0.0:
			q.cd = maxf(float(q.cd), float(p.cd) * 0.25)  # recharge réduite, jamais nulle
		q.chance = minf(float(q.get("chance", 1.0)), 1.0)
		out.append(q)
		i += 1
	return out
