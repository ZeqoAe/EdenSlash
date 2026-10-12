class_name Boons
extends RefCounted
## Cartes de build communes à toutes les classes, en plus des passifs de classe
## (data/classes.json). Inspirées des roguelites (Hades, Vampire Survivors, Risk of
## Rain, Diablo) : zone, portée, dégâts ciblés, effets déclenchés (procs), et des
## cartes légendaires qui n'apparaissent qu'avec leurs prérequis (évolutions).
##
## Champs : id, name, desc, max (cartes cumulables), rarity (common, rare, epic,
## legendary), stat (statistiques par carte), procs (effets déclenchés, voir Procs),
## per_stack (bonus des procs par carte supplémentaire), requires (cartes nécessaires).
##
## Statistiques propres aux cartes : area (rayon des zones), reach (portée de l'attaque
## de base et des compétences en ligne / éventail / élan), dmg_pct, elite_dmg,
## finisher_dmg (3e coup du combo), finisher_area, combo_window (s), dot_pct,
## execute (seuil d'exécution des monstres normaux), rerolls (relances de cartes).

const RARITY := {
	"common": {"name": "Commune", "color": Color(0.85, 0.85, 0.88), "weight": 1.0},
	"rare": {"name": "Rare", "color": Color(0.4, 0.7, 1.0), "weight": 0.6},
	"epic": {"name": "Épique", "color": Color(0.78, 0.45, 1.0), "weight": 0.3},
	"legendary": {"name": "Légendaire", "color": Color(1.0, 0.6, 0.15), "weight": 0.9},
}

const LIST := [
	# --- communes : la base d'un build ---------------------------------------------------
	{"id": "wide_arc", "name": "Lame large", "rarity": "common", "max": 3, "stat": {"area": 0.15},
		"desc": "+15 % de zone d'effet : attaques, compétences, explosions, foudre et gel."},
	{"id": "long_reach", "name": "Allonge", "rarity": "common", "max": 3, "stat": {"reach": 0.15},
		"desc": "+15 % de portée : attaque de base, compétences en ligne, en éventail et élans."},
	{"id": "sharpened", "name": "Fil aiguisé", "rarity": "common", "max": 3, "stat": {"dmg_pct": 0.08},
		"desc": "+8 % de dégâts."},
	{"id": "giant_slayer", "name": "Tueur de géants", "rarity": "common", "max": 3, "stat": {"elite_dmg": 0.2},
		"desc": "+20 % de dégâts contre les élites et les boss."},
	{"id": "combo_flow", "name": "Enchaînement fluide", "rarity": "common", "max": 2,
		"stat": {"combo_window": 0.35, "atk_speed": 0.06},
		"desc": "Combo plus facile à tenir (+0,35 s entre deux coups) et +6 % de vitesse d'attaque."},
	{"id": "heavy_finisher", "name": "Coup de grâce", "rarity": "common", "max": 3,
		"stat": {"finisher_dmg": 0.4, "finisher_area": 0.15},
		"desc": "Le 3e coup du combo : +40 % de dégâts et +15 % de zone."},
	{"id": "deep_wounds", "name": "Plaies profondes", "rarity": "common", "max": 3, "stat": {"dot_pct": 0.3},
		"desc": "+30 % de dégâts des saignements et des brûlures."},
	{"id": "fortune", "name": "Bonne étoile", "rarity": "common", "max": 3, "stat": {"rerolls": 1, "crit": 0.03},
		"desc": "+1 relance de cartes et +3 % de critique."},
	# --- rares : les effets déclenchés -----------------------------------------------------
	{"id": "static_blade", "name": "Lame statique", "rarity": "rare", "max": 3,
		"procs": [{"trigger": "skill_hit", "chance": 0.35, "cd": 4.0, "effect": "lightning", "mult": 1.5, "chain": 3, "radius": 7.0}],
		"per_stack": {"chance": 0.15, "mult": 0.4, "chain": 1},
		"desc": "35 % de chances à l'impact d'une compétence : la foudre tombe et rebondit sur 3 monstres (150 %, 7 m, recharge 4 s)."},
	{"id": "frost_edge", "name": "Fil de givre", "rarity": "rare", "max": 3,
		"procs": [{"trigger": "hit", "chance": 0.1, "cd": 2.5, "effect": "freeze", "duration": 1.5, "radius": 1.5}],
		"per_stack": {"chance": 0.06, "duration": 0.3},
		"desc": "10 % de chances à l'impact : gèle la cible et ses voisins (1,5 s, recharge 2,5 s)."},
	{"id": "ember", "name": "Braise", "rarity": "rare", "max": 3,
		"procs": [{"trigger": "crit", "chance": 1.0, "cd": 0.5, "effect": "burn", "duration": 4.0, "radius": 2.5}],
		"per_stack": {"radius": 0.8, "duration": 1.0},
		"desc": "Les coups critiques enflamment la zone autour de la cible (2,5 m, brûlure 4 s : 25 % de l'attaque par seconde)."},
	{"id": "volatile", "name": "Cadavres explosifs", "rarity": "rare", "max": 3,
		"procs": [{"trigger": "kill", "chance": 0.3, "cd": 0.25, "effect": "explosion", "mult": 1.2, "radius": 3.5}],
		"per_stack": {"chance": 0.15, "mult": 0.3},
		"desc": "30 % de chances qu'un monstre tué explose (3,5 m, 120 %). Les explosions peuvent s'enchaîner."},
	{"id": "shockwave", "name": "Onde de choc", "rarity": "rare", "max": 2,
		"procs": [{"trigger": "finisher", "chance": 1.0, "cd": 0.0, "effect": "explosion", "mult": 1.0, "radius": 5.0,
			"applies": {"stun": 0.5}, "color": Color(1.0, 0.9, 0.5, 0.9)}],
		"per_stack": {"mult": 0.5, "radius": 1.0},
		"desc": "Le 3e coup du combo libère une onde de choc (5 m, 100 %, renverse 0,5 s)."},
	{"id": "wind_step", "name": "Pas du vent", "rarity": "rare", "max": 1,
		"procs": [{"trigger": "dodge", "chance": 1.0, "cd": 5.0, "effect": "buff", "status": "haste", "duration": 3.0,
			"then": [{"effect": "buff", "status": "fury", "duration": 3.0}]}],
		"desc": "Esquiver donne Hâte (+30 % de vitesse) et Fureur (+25 % de dégâts) pendant 3 s (recharge 5 s)."},
	{"id": "battle_trance", "name": "Transe guerrière", "rarity": "rare", "max": 1,
		"procs": [{"trigger": "crit", "chance": 1.0, "cd": 6.0, "effect": "buff", "status": "frenzy", "duration": 4.0}],
		"desc": "Un coup critique donne Frénésie : +30 % de vitesse d'attaque pendant 4 s (recharge 6 s)."},
	{"id": "hunter_eye", "name": "Œil du chasseur", "rarity": "rare", "max": 1,
		"procs": [{"trigger": "kill", "chance": 1.0, "cd": 8.0, "effect": "buff", "status": "keen", "duration": 5.0}],
		"desc": "Tuer un monstre donne Œil acéré : +25 % de critique pendant 5 s (recharge 8 s)."},
	{"id": "second_wind", "name": "Second souffle", "rarity": "rare", "max": 1,
		"procs": [{"trigger": "low_hp", "chance": 1.0, "cd": 60.0, "effect": "heal", "amount": 0.3,
			"then": [{"effect": "buff", "status": "barrier", "duration": 4.0}, {"effect": "nova", "radius": 4.0, "duration": 1.5}]}],
		"desc": "Sous 30 % de PV : rend 30 % des PV, Barrière 4 s et gèle autour de toi (une fois par minute)."},
	{"id": "momentum", "name": "Élan meurtrier", "rarity": "rare", "max": 3,
		"procs": [{"trigger": "kill", "chance": 1.0, "cd": 0.0, "effect": "cdr", "amount": 0.3}],
		"per_stack": {"amount": 0.2},
		"desc": "Chaque monstre tué réduit les recharges de 0,3 s."},
	# --- épiques -------------------------------------------------------------------------
	{"id": "executioner", "name": "Exécuteur", "rarity": "epic", "max": 2, "stat": {"execute": 0.12},
		"desc": "Les monstres normaux sous 12 % de PV sont exécutés d'un coup."},
	{"id": "echo", "name": "Écho", "rarity": "epic", "max": 2,
		"procs": [{"trigger": "skill_hit", "chance": 0.25, "cd": 1.0, "effect": "echo", "mult": 0.6}],
		"per_stack": {"chance": 0.15},
		"desc": "25 % de chances qu'une compétence frappe une 2e fois (60 % des dégâts)."},
	{"id": "frost_nova", "name": "Cœur d'hiver", "rarity": "epic", "max": 1,
		"procs": [{"trigger": "perfect", "chance": 1.0, "cd": 0.0, "effect": "nova", "radius": 5.0, "duration": 2.0},
			{"trigger": "hurt", "chance": 0.25, "cd": 8.0, "effect": "nova", "radius": 4.0, "duration": 1.5}],
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
		"requires": ["heavy_finisher"],
		"stat": {"finisher_area": 0.6, "finisher_hits": 1},
		"desc": "Évolution de Coup de grâce : le 3e coup du combo devient un tourbillon qui frappe deux fois (+60 % de zone)."},
]


static func get_def(id: String) -> Dictionary:
	for b in LIST:
		if b.id == id:
			return b
	return {}


## Procs d'une carte prise [param stacks] fois (bonus par carte supplémentaire).
static func procs_of(def: Dictionary, stacks: int) -> Array:
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
		q.chance = minf(float(q.get("chance", 1.0)), 1.0)
		out.append(q)
		i += 1
	return out
