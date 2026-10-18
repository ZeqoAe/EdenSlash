class_name AutochessData
extends RefCounted
## L'Échiquier (mode autochess, lot AC-A) : toutes les tables du mode, en données. Spécification :
## conception/autochess/SPEC.md (§2, §3, §5, §6) et ses annexes A (unités) et B (objets). Rapport : R_AC_A.md.
## Aucun code d'effet ici : traits, objets et atouts portent une clé d'effet (« effect ») et ses paramètres (« params »,
## « tiers ») que le lot AC-H applique (AutochessItems / AutochessAugments), le même code pour le simulateur (AC-C) et le
## combat réel (AC-E). Les 60 unités sont dans data/autochess_units.json (généré par tools/autochess_units.py).
## Décision du joueur (16/10) : aucun cerveau neuronal dans ce mode ; toutes les unités suivent l'IA scriptée (SPEC §4.1),
## qui lit « role », « attack_range_m », « preferred_distance_m » et « spell_type » de chaque unité, et UNIT_DIFF / AI_*.
## Textes : « short » = texte permanent (carte, fiche), jamais de pourcentage ; « tip » = infobulle, avec les chiffres.
## Toutes les valeurs sont des réglages de départ ; le lot de mesure AC-J les recale (refaire tests/ac_mesures.json).

const UNITS_PATH := "res://data/autochess_units.json"

# --- Réglages : partie --------------------------------------------------------------------------------------------
const PLAYERS := 8
const PLAYER_HP := 100
const MAX_LEVEL := 10
const MAX_LEVEL_BONUS := 11  # atout « Niveau 11 »
const BENCH_SIZE := 9
const ITEM_BENCH_SIZE := 10
const SHOP_SIZE := 5
const MAX_ITEMS_PER_UNIT := 3
const COPIES_PER_STAR := 3  # 3 copies = une étoile de plus (fusion automatique, même banc plein)
const MAX_STARS := 3
const OPENING_CHOICES := 4  # étape 1-1 : 1 héros de coût 1 parmi 4

# --- Réglages : or et expérience (§5.1) ---------------------------------------------------------------------------
const START_GOLD := 2  # à 1-2
const EARLY_INCOME := {"1-2": 2, "1-3": 2, "1-4": 3}
const BASE_INCOME := 5  # dès 2-1, par manche (JcJ ou gardien)
const INTEREST_STEP := 10  # +1 or par tranche de 10 or
const INTEREST_CAP := 5
const INTEREST_CAP_COMPOUND := 10  # atout « Intérêts composés »
const STREAK_GOLD := [[5, 3], [4, 2], [2, 1]]  # [série au moins, or] : 2-3 : +1 · 4 : +2 · 5 et plus : +3
const PVP_WIN_GOLD := 1
const REROLL_COST := 2
const XP_BUY_COST := 4
const XP_BUY_AMOUNT := 4
const XP_PER_ROUND := 2  # offerts à chaque manche dès 1-2
const LEVEL_AT_START := 1
const LEVEL_AT_FIRST_ROUND := 2  # niveau 2 donné à 1-2
## XP pour passer du niveau N au suivant (10 -> 11 : atout « Niveau 11 » seulement).
const XP_TO_NEXT := {2: 2, 3: 6, 4: 10, 5: 20, 6: 36, 7: 48, 8: 72, 9: 84, 10: 100}

# --- Réglages : boutique et réserve (§5.2, §6) --------------------------------------------------------------------
## Taux de la boutique par niveau, en points sur 100, coûts 1 à 5 (niveau 11 : atout « Niveau 11 »).
const SHOP_ODDS := {
	1: [100, 0, 0, 0, 0], 2: [100, 0, 0, 0, 0], 3: [75, 25, 0, 0, 0], 4: [55, 30, 15, 0, 0], 5: [45, 33, 20, 2, 0],
	6: [30, 40, 25, 5, 0], 7: [19, 30, 40, 10, 1], 8: [18, 25, 32, 22, 3], 9: [10, 20, 25, 35, 10],
	10: [5, 10, 20, 40, 25], 11: [2, 8, 15, 40, 35],
}
const POOL_COPIES := {1: 29, 2: 22, 3: 18, 4: 12, 5: 10}  # copies de chaque unité dans la réserve partagée
const UNITS_PER_COST := {1: 10, 2: 15, 3: 15, 4: 10, 5: 10}

# --- Réglages : PV de joueur (§2.3) -------------------------------------------------------------------------------
const DAMAGE_BASE := {1: 0, 2: 2, 3: 4, 4: 6, 5: 9, 6: 12, 7: 15}  # base de l'étape ; 8 et plus : DAMAGE_BASE_LATE
const DAMAGE_BASE_LATE := 20
const PVE_DAMAGE_BONUS := 2  # défaite contre monstres ou gardien : base + 2 + unités debout
const GUARDIAN_STANDING := 3  # un gardien debout compte pour 3 unités

# --- Réglages : unités (§3.2) -------------------------------------------------------------------------------------
const UNIT_LEVEL := 30  # fiche d'un héros de la classe au niveau 30, nu, arme de sa classe
const COST_MULT := [1.0, 1.15, 1.35, 1.6, 1.9]  # PV et attaque selon le coût (1 à 5)
const STAR_MULT := [1.0, 1.8, 3.24]  # PV et attaque selon les étoiles (★1 à ★3)
const SPELL_RANK_MULT := [1.0, 1.5, 2.25]  # puissance du sort signature (rangs 1 à 3)
const STAR3_CHAIN := true  # ★3 : le 2e sort de l'unité (« second_skill_id ») part juste après, sans mana
## Vente : ★1 coût · ★2 3 × coût (−1 si coût ≥ 2) · ★3 9 × coût (−1 si coût ≥ 2).
const SELL_COPIES := [1, 3, 9]

# --- Réglages : combat (§3.3) -------------------------------------------------------------------------------------
const CELL := 2.0  # m, case hexagonale (pointe en haut)
const COLS := 7
const ROWS := 4  # par camp (7 × 8 au total)
const ARENA_RADIUS := 15.0
const RETARGET_AFTER := 1.5  # s hors de portée alors qu'un autre ennemi est à portée : changement de cible
const HIT_CAP := 0.20  # un coup retire au plus 20 % des PV max (hors gardiens)
const MANA_PER_ATTACK := 10
const MANA_PER_HP_PCT := 1.0  # +1 mana par tranche de 1 % des PV max perdus
const MANA_PER_HIT_CAP := 15
const MANA_PER_COOLDOWN := 10  # mana max = recharge du sort (s, arrondie) × 10
## Mana max selon le rôle, en % de la recharge × 10 (lot AC-J, R_AC_J.md : 2 000 parties entre IA ; sans lui, mages
## 27 % et soigneurs 37 % de top 4 relatif, tanks 67 %, aucune victoire Arcane ni Ferveur) : le sort des lanceurs revient
## plus vite, celui des tanks moins souvent. Rôles absents : 100.
const ROLE_MANA := {"mage": 35, "soigneur": 55, "soutien": 60, "tank": 140}
const MANA_MIN := 40
const MANA_MAX := 140
const FIGHT_TARGET := 25.0  # s, médiane visée (échelle des dégâts du profil « autochess » de ModeRules)
const SUDDEN_AT := 30.0  # « Fureur » : dégâts +50 %, puis +50 % toutes les 5 s ; soins reçus divisés par deux
const FURY_STEP := 5.0
const FURY_DAMAGE := 0.5
const FURY_HEAL_MULT := 0.5
const DRAW_AT := 45.0  # égalité : les deux camps perdent
const SPEEDS := [1.0, 2.0]  # Engine.time_scale pendant le combat seulement

## Portée d'attaque en cases selon le type d'arme (mêlée 1, lance / faux-fusil 2, sceptre / guitare / bâton de métal 3,
## arc / bâton / canon / grimoire 4). Recopiée dans tools/autochess_units.py.
const WEAPON_RANGE := {
	"sword": 1, "katana": 1, "dagger": 1, "axe": 1, "hammer": 1, "rapier": 1, "cestus": 1, "greatsword": 1,
	"spear": 2, "gunscythe": 2, "scepter": 3, "guitar": 3, "rod": 3, "bow": 4, "staff": 4, "cannon": 4, "grimoire": 4,
}
const MELEE_REACH := 3.2  # m : allonge en mêlée (comme ClassRival) ; à distance : portée × CELL + 0,5
## Rôles de l'IA de combat scriptée (SPEC §4.1, annexe A) ; « distance » : m visés (négatif = sous l'allonge d'autant).
const ROLES := {
	"tank": {"name": "Tank", "distance": 1.6, "short": "Tient la ligne de front et protège les fragiles."},
	"combattant": {"name": "Combattant", "distance": 1.8, "short": "Frappe au corps à corps avec l'équipe."},
	"assassin": {"name": "Assassin", "distance": 1.6, "short": "Plonge sur l'arrière ennemi."},
	"tireur": {"name": "Tireur", "distance": -1.0, "short": "Tire de loin et recule devant la mêlée."},
	"mage": {"name": "Mage", "distance": -1.0, "short": "Lance ses sorts de loin sur les groupes."},
	"soigneur": {"name": "Soigneur", "distance": -0.5, "short": "Soigne les blessés, reste en retrait."},
	"soutien": {"name": "Soutien", "distance": -0.5, "short": "Renforce ses alliés, reste en retrait."},
}
## IA de combat des unités (SPEC §4.1) : même réglage pour toutes (ClassRival.DIFF[2] = Difficile), aucun cerveau.
const UNIT_DIFF := 2
const AI_DECISIONS_PER_S := 4.0  # cible et sort, décalés d'une unité à l'autre
const AI_FOCUS_REFRESH := 1.0  # s : cible désignée du camp (meilleur score atteignable par 2 alliés ou plus)
const AI_FOCUS_BONUS := 0.30  # score de la cible désignée pour qui l'a à portée + 1 case
const AI_MAX_MELEE_PER_TARGET := 3
const AI_RETARGET_MARGIN := 0.25  # changer de cible vivante : nouveau score > ancien de 25 %
const AI_EXECUTE_BELOW := 0.20  # achèvement : cible sous 20 % à portée
const AI_ZONE_MIN_TARGETS := 2
const AI_ZONE_WAIT := 1.5  # s au plus pour une meilleure occasion de zone
const AI_HEAL_BELOW := 0.70  # le soigneur attend (AI_HEAL_WAIT s au plus) qu'un allié passe sous 70 %
const AI_HEAL_WAIT := 2.0
const AI_SUPPORT_ALLIES := 3  # soutien : renfort quand 3 alliés ou plus sont à portée et engagés
const AI_RETREAT_CELLS := 1.5  # tireur / mage : recul quand une mêlée arrive à 1,5 case
const AI_ASSASSIN_FLEE_BELOW := 0.30
const AI_ASSASSIN_RADIUS := 4  # cases : après l'arrière-ligne, le plus fragile à 4 cases ou moins
const BOARD_MARGIN := 0.5  # m : bornes = hexagone du plateau moins 0,5 m
const BOARD_SPACING := 300.0  # m entre deux plateaux du même monde
## Poids du score de cible par rôle : faiblesse (PV effectifs bas), menace (dégâts récents, objets, coût × étoiles),
## achèvement (cible sous AI_EXECUTE_BELOW à portée), distance (temps de trajet, retranché). Réglage (AC-U).
const AI_WEIGHTS := {
	"tank": {"faiblesse": 0.5, "menace": 1.5, "achevement": 0.5, "distance": 1.5},
	"combattant": {"faiblesse": 1.0, "menace": 1.0, "achevement": 1.0, "distance": 1.0},
	"assassin": {"faiblesse": 2.0, "menace": 0.5, "achevement": 1.5, "distance": 0.3},
	"tireur": {"faiblesse": 1.0, "menace": 1.0, "achevement": 1.5, "distance": 1.0},
	"mage": {"faiblesse": 0.8, "menace": 1.2, "achevement": 1.0, "distance": 1.0},
	"soigneur": {"faiblesse": 0.5, "menace": 0.5, "achevement": 0.5, "distance": 2.0},
	"soutien": {"faiblesse": 0.5, "menace": 0.8, "achevement": 0.5, "distance": 2.0},
}
const PLACES := {"avant": "Avant", "milieu": "Milieu", "arriere": "Arrière"}
## Type du sort signature selon le « kind » du sort (classes.json).
const SPELL_TYPES := {
	"ground": "zone", "spin": "zone", "cone": "zone", "fan": "zone", "flurry": "zone",
	"line": "cible", "bolt": "cible", "heal": "soin", "buff": "renfort", "dash": "deplacement", "blink": "deplacement",
}
const SPELL_TYPE_NAMES := {"zone": "Zone", "cible": "Cible unique", "soin": "Soin", "renfort": "Renfort",
	"deplacement": "Déplacement"}

# --- Réglages : déroulé (§2) --------------------------------------------------------------------------------------
const PREP_TIME := 25.0
const PREP_TIME_STAGE1 := 15.0
const PREP_AUGMENT_BONUS := 10.0
const ROUND_RECAP := 3.0
const CAROUSEL_SIZE := 9
const CAROUSEL_PICK_TIME := 10.0
const CAROUSEL_WALK := 0.6
## Manches : étape 1 (apprend), puis 7 manches par étape. Types : ouverture, monstres, jcj, choix (partagé), gardien.
const STAGE1_ROUNDS := ["ouverture", "monstres", "monstres", "monstres"]
const STAGE_ROUNDS := ["jcj", "jcj", "jcj", "choix", "jcj", "jcj", "gardien"]
## Lot ACX-4 (note du joueur : « perdre contre les monstres du tout début avec 3 héros ») : 1-4 passe de 2 élites + 2 sbires
## (41 % de victoires mesurées, Recrue 18 %) à 1 élite + 2 sbires (96 %, Recrue 89 % ; 300 parties arrêtées à 2-1).
const MONSTER_WAVES := {"1-2": {"sbires": 2}, "1-3": {"sbires": 3}, "1-4": {"elites": 1, "sbires": 2}}
const AUGMENT_ROUNDS := ["2-1", "3-2", "4-2"]
const CAROUSEL_COSTS := {2: [1, 3], 3: [2, 4]}  # 4 et plus : CAROUSEL_COSTS_LATE
const CAROUSEL_COSTS_LATE := [3, 5]
## Butin par manche (annexe B). Clés : composants, insigne (chance 0-1), objets_au_choix, marteau, or, heros_cout ; objets
## utilitaires (lot ACX-3) : pince, creuset, miroir.
## Les monstres paient même perdus. Gardien d'une étape au-delà de 7 : celui de 7-7.
const LOOT := {
	"1-2": {"win": {"composants": 1}, "loss": {"composants": 1}},
	"1-3": {"win": {"composants": 1, "or": 2}, "loss": {"composants": 1, "or": 2}},
	"1-4": {"win": {"composants": 1, "or": 3, "heros_cout": 2}, "loss": {"composants": 1, "or": 3, "heros_cout": 2}},
	"2-7": {"win": {"composants": 2}, "loss": {"composants": 1}},
	"3-7": {"win": {"objets_au_choix": 1, "miroir": 1}, "loss": {"composants": 1}},
	"4-7": {"win": {"composants": 2, "insigne": 0.5, "pince": 1}, "loss": {"composants": 1}},
	"5-7": {"win": {"objets_au_choix": 1, "marteau": 1}, "loss": {"composants": 1}},
	"6-7": {"win": {"insigne": 1.0, "composants": 1, "creuset": 1}, "loss": {"composants": 1}},
	"7-7": {"win": {"objets_au_choix": 2}, "loss": {"composants": 1}},
}
const ITEM_CHOICES := 3  # objets au choix : cartes à 3

# --- Réglages : atouts (§5.3) -------------------------------------------------------------------------------------
const AUGMENT_CHOICES := 3
const AUGMENT_REROLLS := 1  # une relance par choix (les 3 cartes)
const AUGMENT_RARITY_WEIGHTS := {"argent": 50, "or": 35, "eclat": 15}  # jamais deux Éclats de suite
const RARITY_NAMES := {"argent": "Argent", "or": "Or", "eclat": "Éclat"}

# --- Stratèges IA (§4.4) ------------------------------------------------------------------------------------------
## « mix » : nombre d'IA de chaque difficulté (Recrue, Vétéran, Champion, Légende) parmi les 7 adversaires.
const DIFFICULTIES := [
	{"id": "recrue", "name": "Recrue", "mix": [5, 2, 0, 0]},
	{"id": "veteran", "name": "Vétéran", "mix": [1, 4, 2, 0]},
	{"id": "champion", "name": "Champion", "mix": [0, 2, 3, 2]},
	{"id": "legende", "name": "Légende", "mix": [0, 0, 3, 4]},
]
## Formats de partie (lot ACX-3, étude BM-AUTO §6 n° 16) : « classique » = les réglages ci-dessus ; « eclair » = partie
## courte (12-15 min visées, mesurées : R_ACX3.md). Clés d'un format (absentes : réglages ci-dessus) : player_hp,
## stage1 (manches de l'étape 1), start_gold (or à 1-2), early_income, base_income, interest (faux : aucun), streak
## (faux : aucune série), xp_per_round, level_at_first (niveau donné à 1-2), augment_rounds, prep_time, prep_stage1,
## damage_mult (PV perdus), loot (butin propre, clés « 1-2 »…), reward_halved (récompenses de place divisées par deux).
const FORMATS := {
	"classique": {"name": "Classique", "short": "La partie entière : huit stratèges, 100 PV, environ 30 minutes."},
	"eclair": {"name": "Éclair", "short": "Partie courte : 40 PV, revenu fixe, l'expérience s'achète.",
		"tip": "40 PV · 7 or par manche, sans intérêts ni séries · aucune XP offerte · atouts en 2-1 et 3-1 · préparation de 18 s ; PV perdus +10 %.",
		"player_hp": 40, "stage1": ["ouverture", "monstres"], "start_gold": 6, "base_income": 7, "interest": false,
		"streak": false, "xp_per_round": 0, "level_at_first": 3, "augment_rounds": ["2-1", "3-1"], "prep_time": 18.0,
		"prep_stage1": 12.0, "damage_mult": 1.1, "reward_halved": true,
		"loot": {"1-2": {"win": {"composants": 2, "heros_cout": 2}, "loss": {"composants": 2, "heros_cout": 2}}}},
}
## Règle du jour (lot ACX-3, n° 17) : une parmi 8, tirée à la graine du jour, la même pour les 8 stratèges (douce, jamais
## injuste). Clés : start_gold_bonus, reroll_cost, xp_cost, pve_components, first_rarity, crowns, interest_cap,
## augment_rerolls.
const DAY_RULES := {
	"tresor": {"name": "Trésor de départ", "short": "Chaque stratège commence avec 8 or de plus.", "start_gold_bonus": 8},
	"boutique": {"name": "Boutique généreuse", "short": "Actualiser la boutique coûte 1 or.", "reroll_cost": 1},
	"ecole": {"name": "Jour d'école", "short": "L'expérience coûte 3 or au lieu de 4.", "xp_cost": 3},
	"forge": {"name": "Jour de forge", "short": "Monstres et gardiens lâchent un composant de plus.", "pve_components": 1},
	"eclats": {"name": "Pluie d'éclats", "short": "Le premier atout est toujours un Éclat.", "first_rarity": "eclat"},
	"grand_plateau": {"name": "Grand plateau", "short": "Une place de plus sur le plateau pour tous.", "crowns": 1},
	"banquiers": {"name": "Banquiers", "short": "Les intérêts montent jusqu'à 7 or.", "interest_cap": 7},
	"indecis": {"name": "Jour d'hésitation", "short": "Chaque choix d'atout se relance deux fois.", "augment_rerolls": 2},
}
const DAILY_DIFF := 1  # partie du jour : sept stratèges du mélange Vétéran (la même pour tous les joueurs)
const DAILY_FORMAT := "eclair"

const TEMPERAMENTS := {
	"econome": {"name": "Économe", "short": "Garde son or pour les intérêts."},
	"relanceur": {"name": "Relanceur", "short": "Cherche des trois étoiles bon marché."},
	"montee_rapide": {"name": "Montée rapide", "short": "Monte vite au niveau 8."},
}

# --- Traits (§5.4) ------------------------------------------------------------------------------------------------
## Famille du code (class_data.family) -> trait de famille (origine : 12 unités, 4 lignées).
const FAMILY_TRAIT := {1: "rempart", 2: "ombre", 3: "traque", 4: "ferveur", 5: "arcane"}
## Lot ACX-4 (traits croisés, R_ACX4.md) : le 2e trait est un STYLE porté par la lignée (classe verte + ses 2 éveils, mêmes
## traits, coûts différents) ; chaque style réunit 2 lignées de 2 familles différentes : les 10 styles sont les 10 paires de
## familles, chaque famille partage un style avec chacune des 4 autres (plus de plateau « tout d'une couleur » forcé par les
## traits). Ids et effets des anciens traits d'arme gardés (« kind » : « arme » = style, pour les sauvegardes et les atouts).
## Recopié dans tools/autochess_units.py (test_ac_data compare).
const LINEAGE_STYLE := {
	"templar": "escrime", "blade_dancer": "escrime", "knight": "estoc", "ranger": "estoc",
	"warrior": "fracas", "sage": "fracas", "dragon_knight": "poudre", "warlock": "poudre",
	"martial_artist": "impact", "luminary": "impact", "thief": "tranchant", "hunter": "tranchant",
	"samurai": "choeur", "bard": "choeur", "inquisitor": "malediction", "cleric": "malediction",
	"engineer": "tir", "illusionist": "tir", "shaman": "elementaire", "magician": "elementaire",
}
## Unités ponts : un éveil de coût 3-4 par famille compte aussi pour une autre famille (3e trait ; cycle Rempart -> Ombre ->
## Ferveur -> Arcane -> Traque -> Rempart).
const BRIDGES := {"executioner": "ombre", "elegant_dancer": "ferveur", "life_worshipper": "arcane",
	"demon_tamer": "traque", "mecha_ares": "rempart"}
const FAMILY_THRESHOLDS := [3, 6, 9]
const WEAPON_THRESHOLDS := [2, 4, 6]
## Un trait : « kind » famille / arme (= style, lot ACX-4), « lineages » (styles : les 2 lignées), « scope » (porteurs : unités du trait ; equipe ; ennemis), « effect » (clé lue par
## AC-H), « tiers » : paramètres de chaque palier (cumul déjà fait : le palier 2 donne ses valeurs, pas un ajout).
const TRAITS := {
	"rempart": {"name": "Rempart", "kind": "famille", "family": 1, "scope": "porteurs", "effect": "trait_rempart",
		"short": "Les Rempart encaissent mieux ; à neuf, toute l'équipe gagne des PV.",
		"tip": "Défense des Rempart +5 / +20 / +40 ; à 9 : PV de toute l'équipe +10 %.",
		"tiers": [{"def": 5}, {"def": 20}, {"def": 40, "team_hp_pct": 0.10}]},
	"ombre": {"name": "Ombre", "kind": "famille", "family": 2, "scope": "porteurs", "effect": "trait_ombre",
		"short": "Les Ombre bondissent sur l'arrière ennemi et frappent plus fort en critique.",
		"tip": "Au début du combat, saut sur la rangée arrière ennemie ; dégâts critiques +20 / 40 / 70 %.",
		"tiers": [{"leap": 1, "crit_dmg": 0.20}, {"leap": 1, "crit_dmg": 0.40}, {"leap": 1, "crit_dmg": 0.70}]},
	"traque": {"name": "Traque", "kind": "famille", "family": 3, "scope": "porteurs", "effect": "trait_traque",
		"short": "Les Traque frappent plus fort de loin ; à six, leur portée grandit.",
		"tip": "Attaque +15 / 30 / 55 % contre une cible à plus de 3 cases ; à 6 et plus : portée +1 case.",
		"tiers": [{"far_cells": 3, "atk_pct": 0.15}, {"far_cells": 3, "atk_pct": 0.30, "range": 1},
			{"far_cells": 3, "atk_pct": 0.55, "range": 1}]},
	"ferveur": {"name": "Ferveur", "kind": "famille", "family": 4, "scope": "equipe", "effect": "trait_ferveur",
		"short": "Soigne régulièrement l'allié le plus blessé.",
		"tip": "Toutes les 4 s, soin de l'allié le plus blessé : 8 / 15 / 25 % de ses PV ; à 9 : soins reçus +30 %.",
		"tiers": [{"every": 4.0, "heal_pct": 0.08}, {"every": 4.0, "heal_pct": 0.15},
			{"every": 4.0, "heal_pct": 0.25, "heal_taken_pct": 0.30}]},
	"arcane": {"name": "Arcane", "kind": "famille", "family": 5, "scope": "porteurs", "effect": "trait_arcane",
		"short": "Les sorts des Arcane frappent plus fort ; à neuf, le premier part deux fois.",
		"tip": "Puissance des sorts des Arcane +70 / 130 / 200 % ; à 9 : le 1er sort de chaque Arcane est lancé deux fois.",
		"tiers": [{"spell_pct": 0.70}, {"spell_pct": 1.30}, {"spell_pct": 2.00, "double_first": 1}]},
	"escrime": {"name": "Escrime", "kind": "arme", "lineages": ["templar", "blade_dancer"], "scope": "porteurs", "effect": "trait_escrime",
		"short": "Bloquent des attaques et ripostent.",
		"tip": "Parade de 5 / 10 / 18 % des attaques, riposte à 80 % de la frappe.",
		"tiers": [{"parry": 0.05, "riposte": 0.8}, {"parry": 0.10, "riposte": 0.8}, {"parry": 0.18, "riposte": 0.8}]},
	"tir": {"name": "Cadence", "kind": "arme", "lineages": ["engineer", "illusionist"], "scope": "porteurs", "effect": "trait_tir",
		"short": "Attaquent de plus en plus vite ; à six, leurs tirs traversent.",
		"tip": "Vitesse d'attaque +15 / 35 / 60 % après 3 s de combat ; à 6 : leurs tirs traversent.",
		"tiers": [{"after": 3.0, "as_pct": 0.15}, {"after": 3.0, "as_pct": 0.35}, {"after": 3.0, "as_pct": 0.60, "pierce": 1}]},
	"elementaire": {"name": "Élémentaire", "kind": "arme", "lineages": ["shaman", "magician"], "scope": "porteurs",
		"effect": "trait_elementaire",
		"short": "Leurs sorts laissent une zone qui brûle ; à six, elle ralentit.",
		"tip": "Le sort laisse une zone : 25 / 50 / 85 % de ses dégâts par seconde pendant 3 s ; à 6 : ralentit.",
		"tiers": [{"zone_pct": 0.25, "dur": 3.0}, {"zone_pct": 0.50, "dur": 3.0}, {"zone_pct": 0.85, "dur": 3.0, "slow": 1}]},
	"tranchant": {"name": "Tranchant", "kind": "arme", "lineages": ["thief", "hunter"], "scope": "porteurs",
		"effect": "trait_tranchant",
		"short": "Achèvent les ennemis presque vaincus.",
		"tip": "Achèvent une cible sous 10 / 15 / 20 % de ses PV.",
		"tiers": [{"execute_below": 0.10}, {"execute_below": 0.15}, {"execute_below": 0.20}]},
	"fracas": {"name": "Fracas", "kind": "arme", "lineages": ["warrior", "sage"], "scope": "porteurs", "effect": "trait_fracas",
		"short": "Étourdissent régulièrement leur cible.",
		"tip": "Toutes les 4 / 3 / 2 attaques, étourdit 0,5 s.",
		"tiers": [{"every": 4, "stun": 0.5}, {"every": 3, "stun": 0.5}, {"every": 2, "stun": 0.5}]},
	"estoc": {"name": "Estoc", "kind": "arme", "lineages": ["knight", "ranger"], "scope": "porteurs", "effect": "trait_estoc",
		"short": "Percent les armures.",
		"tip": "Ignorent 5 / 15 / 30 % de la défense.",
		"tiers": [{"armor_pen": 0.05}, {"armor_pen": 0.15}, {"armor_pen": 0.30}]},
	"poudre": {"name": "Brasier", "kind": "arme", "lineages": ["dragon_knight", "warlock"], "scope": "porteurs",
		"effect": "trait_poudre",
		"short": "Leurs attaques explosent autour de la cible.",
		"tip": "Les attaques explosent à 1 case : 20 / 40 / 70 % des dégâts.",
		"tiers": [{"radius": 1, "splash": 0.20}, {"radius": 1, "splash": 0.40}, {"radius": 1, "splash": 0.70}]},
	"choeur": {"name": "Harmonie", "kind": "arme", "lineages": ["samurai", "bard"], "scope": "equipe", "effect": "trait_choeur",
		"short": "Toute l'équipe regagne de la mana en continu.",
		"tip": "Toute l'équipe gagne 3 / 6 / 10 mana par seconde.",
		"tiers": [{"mana_per_s": 3}, {"mana_per_s": 6}, {"mana_per_s": 10}]},
	"malediction": {"name": "Malédiction", "kind": "arme", "lineages": ["inquisitor", "cleric"], "scope": "ennemis",
		"effect": "trait_malediction",
		"short": "Affaiblissent les ennemis les plus forts.",
		"tip": "À 3 s, les 2 / 4 / tous les ennemis les plus forts : attaque et défense −30 / 40 / 55 %.",
		"tiers": [{"at": 3.0, "targets": 2, "down": 0.30}, {"at": 3.0, "targets": 4, "down": 0.40},
			{"at": 3.0, "targets": 0, "down": 0.55}]},  # targets 0 : tous
	"impact": {"name": "Impact", "kind": "arme", "lineages": ["martial_artist", "luminary"], "scope": "porteurs",
		"effect": "trait_impact",
		"short": "Chaque coup sur la même cible frappe plus fort.",
		"tip": "Chaque coup sur la même cible : +7 / 11 / 16 % de dégâts (10 fois au plus).",
		"tiers": [{"stack_pct": 0.07, "max": 10}, {"stack_pct": 0.11, "max": 10}, {"stack_pct": 0.16, "max": 10}]},
}

# --- Objets (§5.5, annexe B) --------------------------------------------------------------------------------------
## Clés de stats (composants, objets, atouts) : hp, hp_pct, atk_pct, as_pct, spell_pct, mana_start, def, mdef, crit,
## crit_dmg, dodge, range, dmg_taken. Déclencheurs (« trigger ») d'un effet :
const TRIGGERS := ["passif", "debut_combat", "attaque", "coup_recu", "sort", "critique", "esquive", "elimination",
	"chute_allie", "chute", "seuil_pv", "temps", "achat", "debut_manche", "immediat", "gardien"]
const STAT_KEYS := ["hp", "hp_pct", "atk_pct", "as_pct", "spell_pct", "mana_start", "def", "mdef", "crit", "crit_dmg",
	"dodge", "range", "dmg_taken"]
## Les 9 composants (8 de base + l'Insigne rare). « icon » : icône de passif existante (Boons) réutilisée.
const BASE_COMPONENTS := ["lame", "arc", "baton", "larme", "plastron", "voile", "ceinture", "gant"]
const COMPONENTS := {
	"lame": {"name": "Lame d'acier", "stats": {"atk_pct": 0.10}, "short": "Plus d'attaque.", "tip": "+10 % d'attaque."},
	"arc": {"name": "Arc court", "stats": {"as_pct": 0.10}, "short": "Attaque plus vite.",
		"tip": "+10 % de vitesse d'attaque."},
	"baton": {"name": "Bâton runique", "stats": {"spell_pct": 0.10}, "short": "Sorts plus puissants.",
		"tip": "+10 % de puissance des sorts."},
	"larme": {"name": "Larme de mana", "stats": {"mana_start": 15}, "short": "Commence le combat avec de la mana.",
		"tip": "+15 mana au début du combat."},
	"plastron": {"name": "Plastron", "stats": {"def": 20}, "short": "Plus de défense.", "tip": "+20 défense."},
	"voile": {"name": "Voile", "stats": {"mdef": 20}, "short": "Résiste mieux aux sorts.", "tip": "+20 défense magique."},
	"ceinture": {"name": "Ceinture du géant", "stats": {"hp": 150}, "short": "Plus de PV.", "tip": "+150 PV."},
	"gant": {"name": "Gant de chance", "stats": {"crit": 0.15}, "short": "Plus de critiques.", "tip": "+15 % de critique."},
	"insigne": {"name": "Insigne", "stats": {}, "rare": true, "short": "Rare : crée un Emblème ou une Couronne.",
		"tip": "Avec un composant : Emblème (un trait de plus). Avec un autre Insigne : Couronne (une unité de plus)."},
}
## Les 36 objets complets : « parts » (deux composants de base), stats = somme des composants (item_stats) + « params ».
const ITEMS := {
	"executeur": {"name": "Exécuteur", "parts": ["lame", "lame"], "trigger": "attaque", "effect": "degats_cible_faible",
		"params": {"below": 0.30, "dmg_pct": 0.40}, "icon": "executioner",
		"short": "Frappe plus fort les cibles affaiblies.", "tip": "Dégâts +40 % contre une cible sous 30 % de PV."},
	"transe": {"name": "Transe de combat", "parts": ["lame", "arc"], "trigger": "attaque", "effect": "cadence_cumul",
		"params": {"as_pct": 0.04, "max": 10}, "icon": "battle_trance",
		"short": "Attaque de plus en plus vite.", "tip": "Chaque attaque : +4 % de vitesse d'attaque (10 fois au plus)."},
	"lame_statique": {"name": "Lame statique", "parts": ["lame", "baton"], "trigger": "attaque", "effect": "eclair_chaine",
		"params": {"every": 3, "targets": 2, "ratio": 1.2}, "icon": "static_blade",
		"short": "Ses attaques lancent régulièrement un éclair.",
		"tip": "Toutes les 3 attaques, éclair sur 2 ennemis : 120 % de l'attaque."},
	"echo": {"name": "Écho", "parts": ["lame", "larme"], "trigger": "sort", "effect": "attaque_renforcee",
		"params": {"ratio": 2.0}, "icon": "echo",
		"short": "Après un sort, l'attaque suivante frappe double.", "tip": "Après un sort, l'attaque suivante inflige 200 %."},
	"soif_de_sang": {"name": "Soif de sang", "parts": ["lame", "plastron"], "trigger": "attaque", "effect": "vol_de_vie",
		"params": {"lifesteal": 0.20, "below": 0.40, "shield_pct": 0.15}, "icon": "bloodthirst",
		"short": "Se soigne en frappant ; un bouclier la sauve une fois.",
		"tip": "Vol de vie 20 % ; bouclier de 15 % des PV la 1re fois sous 40 %."},
	"briseur_sorts": {"name": "Briseur de sorts", "parts": ["lame", "voile"], "trigger": "attaque", "effect": "vol_mana",
		"params": {"mana": 10}, "icon": "",
		"short": "Chaque attaque vide la mana de la cible.", "tip": "Chaque attaque retire 10 mana à la cible."},
	"tueur_geants": {"name": "Tueur de géants", "parts": ["lame", "ceinture"], "trigger": "attaque",
		"effect": "degats_cible_robuste", "params": {"dmg_pct": 0.25}, "icon": "giant_slayer",
		"short": "Plus de dégâts contre les cibles robustes.", "tip": "+25 % de dégâts contre une cible qui a plus de PV max."},
	"precision": {"name": "Précision", "parts": ["lame", "gant"], "trigger": "passif", "effect": "stats",
		"params": {"crit": 0.25, "crit_dmg": 0.40}, "icon": "precision",
		"short": "Critiques plus fréquents et plus forts.", "tip": "Critique +25 %, dégâts critiques +40 %."},
	"lame_vive": {"name": "Lame vive", "parts": ["arc", "arc"], "trigger": "temps", "effect": "cadence_montante",
		"params": {"as_pct": 0.30, "after": 6.0, "as_late": 0.30}, "icon": "swift_blade",
		"short": "Attaque très vite, puis encore plus vite.",
		"tip": "+30 % de vitesse d'attaque, encore +30 % après 6 s de combat."},
	"tir_multiple": {"name": "Tir multiple", "parts": ["arc", "baton"], "trigger": "attaque", "effect": "second_tir",
		"params": {"targets": 1, "ratio": 0.70}, "icon": "multishot",
		"short": "Chaque attaque touche un deuxième ennemi.", "tip": "Chaque attaque touche un 2e ennemi à 70 %."},
	"elan": {"name": "Élan", "parts": ["arc", "larme"], "trigger": "attaque", "effect": "mana_par_attaque",
		"params": {"mana": 5}, "icon": "momentum",
		"short": "Plus de mana à chaque attaque.", "tip": "+5 mana de plus par attaque."},
	"pas_du_vent": {"name": "Pas du vent", "parts": ["arc", "plastron"], "trigger": "coup_recu", "effect": "esquive_breve",
		"params": {"dodge": 0.25, "dur": 4.0, "cd": 6.0}, "icon": "wind_step",
		"short": "Touchée, elle devient insaisissable un instant.", "tip": "Touchée : +25 % d'esquive 4 s (recharge 6 s)."},
	"ricochet": {"name": "Ricochet", "parts": ["arc", "voile"], "trigger": "attaque", "effect": "rebond",
		"params": {"bounces": 1, "ratio": 0.60}, "icon": "ricochet",
		"short": "Ses attaques rebondissent sur un autre ennemi.", "tip": "Les attaques rebondissent une fois à 60 %."},
	"second_souffle": {"name": "Second souffle", "parts": ["arc", "ceinture"], "trigger": "seuil_pv",
		"effect": "second_souffle", "params": {"below": 0.50, "heal_pct": 0.20, "as_pct": 0.30}, "icon": "second_wind",
		"short": "Blessée, elle se soigne et accélère, une fois.",
		"tip": "Sous 50 % de PV, une fois : soin de 20 % et +30 % de vitesse d'attaque."},
	"oeil_chasseur": {"name": "Œil du chasseur", "parts": ["arc", "gant"], "trigger": "passif", "effect": "stats",
		"params": {"range": 1, "crit": 0.20}, "icon": "hunter_eye",
		"short": "Plus de portée et plus de critiques.", "tip": "Portée +1 case, critique +20 %."},
	"arcanes": {"name": "Arcanes", "parts": ["baton", "baton"], "trigger": "passif", "effect": "stats",
		"params": {"spell_pct": 0.50}, "icon": "arcana",
		"short": "Sorts bien plus puissants.", "tip": "Puissance des sorts +50 %."},
	"incantation": {"name": "Incantation", "parts": ["baton", "larme"], "trigger": "passif", "effect": "mana_max",
		"params": {"mana_max_pct": -0.20}, "icon": "incantation",
		"short": "Son sort revient plus vite.", "tip": "Mana max −20 %."},
	"onde_de_choc": {"name": "Onde de choc", "parts": ["baton", "plastron"], "trigger": "sort", "effect": "renversement",
		"params": {"radius": 2, "dur": 1.0}, "icon": "shockwave",
		"short": "Son sort renverse les ennemis proches.", "tip": "Le sort renverse les ennemis à 2 cases (1 s)."},
	"nova_givre": {"name": "Nova de givre", "parts": ["baton", "voile"], "trigger": "temps", "effect": "gel_zone",
		"params": {"radius": 2, "dur": 1.5, "every": 8.0}, "icon": "frost_nova",
		"short": "Gèle les ennemis proches, au début puis régulièrement.",
		"tip": "Au début puis toutes les 8 s : gel de 1,5 s des ennemis à 2 cases."},
	"braise": {"name": "Braise", "parts": ["baton", "ceinture"], "trigger": "sort", "effect": "brulure",
		"params": {"hp_pct": 0.15, "dur": 5.0, "heal_cut": 0.40}, "icon": "ember",
		"short": "Ses sorts brûlent et réduisent les soins.",
		"tip": "Les sorts brûlent 15 % des PV max sur 5 s ; soins reçus −40 %."},
	"sort_critique": {"name": "Sort critique", "parts": ["baton", "gant"], "trigger": "passif", "effect": "sort_critique",
		"params": {"crit": 0.20}, "icon": "",
		"short": "Ses sorts peuvent être critiques.", "tip": "Les sorts peuvent critiquer ; critique +20 %."},
	"source": {"name": "Source", "parts": ["larme", "larme"], "trigger": "temps", "effect": "mana_continue",
		"params": {"mana": 10, "every": 3.0}, "icon": "",
		"short": "Regagne de la mana en continu.", "tip": "+10 mana toutes les 3 s."},
	"barriere": {"name": "Barrière", "parts": ["larme", "plastron"], "trigger": "sort", "effect": "bouclier_sort",
		"params": {"shield_pct": 0.20, "dur": 4.0}, "icon": "",
		"short": "Chaque sort lui donne un bouclier.", "tip": "Chaque sort : bouclier de 20 % des PV pendant 4 s."},
	"persistance": {"name": "Persistance", "parts": ["larme", "voile"], "trigger": "sort", "effect": "zone_renforcee",
		"params": {"dur": 2.0, "radius_pct": 0.20}, "icon": "lingering",
		"short": "Zones de ses sorts plus larges et plus longues.", "tip": "Zones des sorts : +2 s, rayon +20 %."},
	"vigueur": {"name": "Vigueur", "parts": ["larme", "ceinture"], "trigger": "sort", "effect": "soin_sort",
		"params": {"heal_pct": 0.12}, "icon": "vigor",
		"short": "Chaque sort la soigne.", "tip": "Chaque sort soigne 12 % des PV max."},
	"flux_combo": {"name": "Flux de combo", "parts": ["larme", "gant"], "trigger": "critique", "effect": "mana_critique",
		"params": {"mana": 8}, "icon": "combo_flow",
		"short": "Chaque critique rend de la mana.", "tip": "Chaque critique rend 8 mana."},
	"robustesse": {"name": "Robustesse", "parts": ["plastron", "plastron"], "trigger": "coup_recu", "effect": "epines",
		"params": {"def": 60, "reflect": 0.15}, "icon": "toughness",
		"short": "Très solide ; renvoie une part des coups.", "tip": "Défense +60, renvoie 15 % des dégâts physiques."},
	"mur_titan": {"name": "Mur du titan", "parts": ["plastron", "voile"], "trigger": "passif", "effect": "stats",
		"params": {"hp_pct": 0.20, "dmg_taken": -0.15}, "icon": "",
		"short": "Plus de PV, moins de dégâts reçus.", "tip": "PV +20 %, dégâts reçus −15 %."},
	"brute": {"name": "Brute", "parts": ["plastron", "ceinture"], "trigger": "debut_combat", "effect": "insensible_debut",
		"params": {"hp": 500, "dur": 10.0}, "icon": "brute",
		"short": "Beaucoup de PV ; insensible aux contrôles au début.",
		"tip": "+500 PV ; insensible aux contrôles les 10 premières secondes."},
	"coup_final": {"name": "Coup final lourd", "parts": ["plastron", "gant"], "trigger": "attaque",
		"effect": "etourdit_regulier", "params": {"every": 3, "stun": 0.75}, "icon": "heavy_finisher",
		"short": "Étourdit régulièrement sa cible.", "tip": "Toutes les 3 attaques, étourdit 0,75 s."},
	"lame_givre": {"name": "Lame de givre", "parts": ["voile", "voile"], "trigger": "attaque", "effect": "ralentit_cadence",
		"params": {"as_pct": -0.25, "dur": 3.0}, "icon": "frost_edge",
		"short": "Ses attaques ralentissent la cible.", "tip": "Les attaques réduisent la vitesse d'attaque de la cible de 25 % (3 s)."},
	"ange_gardien": {"name": "Ange gardien", "parts": ["voile", "ceinture"], "trigger": "seuil_pv", "effect": "invulnerable",
		"params": {"below": 0.40, "dur": 1.5}, "icon": "",
		"short": "Blessée, elle devient invulnérable un instant.", "tip": "Sous 40 % de PV, une fois : invulnérable 1,5 s."},
	"volatile": {"name": "Volatile", "parts": ["voile", "gant"], "trigger": "chute", "effect": "explosion_chute",
		"params": {"hp_pct": 0.25, "radius": 2}, "icon": "volatile",
		"short": "Explose à sa chute.", "tip": "À sa chute, explose : 25 % de ses PV max aux ennemis à 2 cases."},
	"colosse": {"name": "Colosse", "parts": ["ceinture", "ceinture"], "trigger": "passif", "effect": "stats",
		"params": {"hp": 900, "scale": 1.15}, "icon": "",
		"short": "Énormément de PV.", "tip": "+900 PV, taille ×1,15."},
	"plaies": {"name": "Plaies profondes", "parts": ["ceinture", "gant"], "trigger": "attaque", "effect": "saignement",
		"params": {"hp_pct": 0.03, "dur": 4.0, "heal_cut": 0.50}, "icon": "deep_wounds",
		"short": "Fait saigner la cible et réduit ses soins.",
		"tip": "Saignement de 3 % des PV max par seconde (4 s), soins reçus −50 %."},
	"fortune": {"name": "Fortune", "parts": ["gant", "gant"], "trigger": "elimination", "effect": "or_elimination",
		"params": {"crit": 0.35, "gold": 1, "per_round": 2}, "icon": "fortune",
		"short": "Critiques fréquents ; ses éliminations rapportent de l'or.",
		"tip": "Critique +35 % ; chaque élimination : +1 or (2 par manche au plus)."},
}
## Objets spéciaux : Emblème (Insigne + composant : stats du composant + un trait choisi parmi 3), Couronne (deux Insignes :
## une unité de plus sur le plateau, ne s'équipe pas), Marteau de réforge (rend les composants d'une unité au banc).
const SPECIAL_ITEMS := {
	"embleme": {"name": "Emblème", "parts": ["insigne", "*"], "trigger": "passif", "effect": "trait_bonus",
		"params": {"choices": 3}, "short": "Ajoute un trait à son porteur.",
		"tip": "L'unité compte pour un trait qu'elle n'a pas (choix parmi 3). Les stats du composant restent."},
	"couronne": {"name": "Couronne", "parts": ["insigne", "insigne"], "trigger": "immediat", "effect": "place_plateau",
		"params": {"slots": 1}, "short": "Une unité de plus sur le plateau.", "tip": "Ne s'équipe pas : +1 place sur le plateau."},
	"marteau_reforge": {"name": "Marteau de réforge", "parts": [], "trigger": "immediat", "effect": "reforge",
		"params": {}, "short": "Rend au banc les composants d'une unité.", "icon": "heavy_finisher",
		"tip": "Retire les objets d'une unité : leurs composants reviennent au banc d'objets."},
	# objets utilitaires (lot ACX-3, n° 19) : banc d'objets seulement, posés sur une unité comme un objet
	"pince": {"name": "Pince", "parts": [], "trigger": "immediat", "effect": "retire_objets", "params": {}, "icon": "recall",
		"short": "Retire les objets d'une unité, intacts.",
		"tip": "Les objets de l'unité reviennent au banc d'objets tels quels (rien n'est défait)."},
	"creuset": {"name": "Creuset", "parts": [], "trigger": "immediat", "effect": "refonte_objets", "params": {}, "icon": "ember",
		"short": "Change les objets complets d'une unité.",
		"tip": "Chaque objet complet de l'unité devient un autre objet complet, au hasard (emblèmes et composants restent)."},
	"miroir": {"name": "Miroir", "parts": [], "trigger": "immediat", "effect": "copie_unite", "params": {"max_cost": 3},
		"icon": "echo", "short": "Une copie d'un héros bon marché.",
		"tip": "Pose-le sur un héros de coût 3 ou moins : une copie à une étoile arrive (prise à la réserve)."},
}
## Objets qui ne se posent que sur une unité pour agir sur elle (jamais portés).
const UTILITY_ITEMS := ["marteau_reforge", "pince", "creuset", "miroir"]

# --- Atouts (§5.3) ------------------------------------------------------------------------------------------------
## « trigger » : moment de l'effet (immediat : à la prise ; debut_manche ; debut_combat ; passif…), « effect » + « params »
## lus par AC-H ; « icon » : icône de passif du jeu (Boons.ICONS) montrée sur la carte d'atout (lot ACX-2). Sans capitaine ni cerveau (décision du joueur du 16/10) : « Chef de guerre » et « Ordre de bataille »
## remplacent les deux atouts du capitaine (SPEC §5.3 révisée).
const AUGMENTS := {
	"tirelire": {"icon": "fortune", "rarity": "argent", "name": "Tirelire", "trigger": "debut_manche", "effect": "or",
		"params": {"gold": 1}, "short": "Un peu d'or à chaque manche.", "tip": "+1 or au début de chaque manche."},
	"relance_offerte": {"icon": "recall", "rarity": "argent", "name": "Relance offerte", "trigger": "debut_manche", "effect": "relance_gratuite",
		"params": {"rerolls": 1}, "short": "Une actualisation gratuite à chaque manche.",
		"tip": "1 actualisation gratuite par manche."},
	"apprenti": {"icon": "scholar", "rarity": "argent", "name": "Apprenti", "trigger": "debut_manche", "effect": "xp",
		"params": {"xp_now": 3, "xp_round": 1}, "short": "De l'expérience tout de suite, puis à chaque manche.",
		"tip": "+3 XP tout de suite et +1 XP par manche."},
	"composant": {"icon": "sharpened", "rarity": "argent", "name": "Composant", "trigger": "immediat", "effect": "composant_au_choix",
		"params": {"choices": 3}, "short": "Un composant au choix.", "tip": "Un composant au choix parmi 3."},
	"renfort": {"icon": "wind_step", "rarity": "argent", "name": "Renfort", "trigger": "immediat", "effect": "unites_famille",
		"params": {"count": 2, "cost": 1}, "short": "Deux recrues de ta famille la plus nombreuse.",
		"tip": "2 unités de coût 1 de ta famille la plus nombreuse."},
	"peau_dure": {"icon": "toughness", "rarity": "argent", "name": "Peau dure", "trigger": "passif", "effect": "stats_equipe",
		"params": {"hp": 120}, "short": "Tes unités ont plus de PV.", "tip": "+120 PV à tes unités."},
	"premier_sang": {"icon": "deep_wounds", "rarity": "argent", "name": "Premier sang", "trigger": "attaque", "effect": "premier_coup",
		"params": {"atk_pct": 0.30}, "short": "Ta première unité à toucher frappe plus fort.",
		"tip": "La 1re unité à toucher : +30 % d'attaque pour le combat."},
	"esquive_aiguisee": {"icon": "air_jump", "rarity": "argent", "name": "Esquive aiguisée", "trigger": "passif", "effect": "stats_equipe",
		"params": {"dodge": 0.10}, "short": "Tes unités esquivent plus souvent.", "tip": "+10 % d'esquive à tes unités."},
	"ralliement": {"icon": "vigor", "rarity": "argent", "name": "Ralliement", "trigger": "chute_allie", "effect": "soin_equipe",
		"params": {"heal_pct": 0.08}, "short": "Quand un allié tombe, les autres se soignent.",
		"tip": "Quand un allié tombe, les autres récupèrent 8 % de leurs PV."},
	"mana_vive": {"icon": "focus", "rarity": "argent", "name": "Mana vive", "trigger": "debut_combat", "effect": "mana_equipe",
		"params": {"mana": 15}, "short": "Tes unités commencent avec de la mana.", "tip": "+15 mana au début de chaque combat."},
	"interets_composes": {"icon": "fortune", "rarity": "or", "name": "Intérêts composés", "trigger": "passif", "effect": "plafond_interets",
		"params": {"cap": 10}, "short": "Tes intérêts peuvent doubler.", "tip": "Plafond des intérêts : 5 → 10 (à 100 or)."},
	"pacte_de_sang": {"icon": "bloodthirst", "rarity": "or", "name": "Pacte de sang", "trigger": "immediat", "effect": "pv_contre_or",
		"params": {"player_hp": -15, "gold": 25}, "short": "Échange des PV de joueur contre beaucoup d'or.",
		"tip": "−15 PV de joueur, +25 or tout de suite."},
	"insigne": {"icon": "precision", "rarity": "or", "name": "Insigne", "trigger": "immediat", "effect": "objet",
		"params": {"item": "insigne", "count": 1}, "short": "Un Insigne tout de suite.", "tip": "Un Insigne tout de suite."},
	"chef_de_guerre": {"icon": "brute", "rarity": "or", "name": "Chef de guerre", "trigger": "debut_combat", "effect": "unite_la_plus_chere",
		"params": {"hp_pct": 0.30, "atk_pct": 0.30}, "short": "Ton unité la plus chère est plus forte.",
		"tip": "Ton unité la plus chère (puis la plus étoilée) : +30 % de PV et d'attaque."},
	"heritage": {"icon": "echo", "rarity": "or", "name": "Héritage", "trigger": "debut_combat", "effect": "lignee",
		"params": {"hp_pct": 0.20, "atk_pct": 0.20}, "short": "Une classe et son ascension réunies se renforcent.",
		"tip": "Une classe verte et une de ses ascensions sur le plateau : +20 % de PV et d'attaque aux deux."},
	"echo_recrue": {"icon": "multishot", "rarity": "or", "name": "Écho de recrue", "trigger": "achat", "effect": "achat_double",
		"params": {"every": 4}, "short": "De temps en temps, une recrue arrive en double.",
		"tip": "Chaque 4e unité achetée arrive en double."},
	"riposte": {"icon": "piercing", "rarity": "or", "name": "Riposte", "trigger": "esquive", "effect": "contre_attaque",
		"params": {"ratio": 0.60}, "short": "Une esquive est suivie d'une riposte.",
		"tip": "Quand une de tes unités esquive, elle rend 60 % de sa frappe."},
	"garde_du_corps": {"icon": "second_wind", "rarity": "or", "name": "Garde du corps", "trigger": "debut_combat", "effect": "bouclier_avant",
		"params": {"count": 2, "shield_pct": 0.25, "dur": 8.0}, "short": "Tes deux unités de tête reçoivent un bouclier.",
		"tip": "Tes 2 unités les plus avancées : bouclier de 25 % des PV pendant 8 s."},
	"coeur_de_famille": {"icon": "hunter_eye", "rarity": "or", "name": "Cœur de famille", "trigger": "immediat", "effect": "trait_compte",
		"params": {"kind": "famille", "count": 1, "choices": 5}, "short": "Une famille au choix compte une unité de plus.",
		"tip": "+1 au compte d'une famille au choix (parmi les 5)."},
	"forge_de_campagne": {"icon": "heavy_finisher", "rarity": "or", "name": "Forge de campagne", "trigger": "gardien", "effect": "butin_gardien",
		"params": {"items": 1}, "short": "Chaque gardien donne un objet de plus.",
		"tip": "Chaque gardien donne un objet complet de plus."},
	"main_sure": {"icon": "incantation", "rarity": "or", "name": "Main sûre", "trigger": "passif", "effect": "cout_mana",
		"params": {"mana_max_pct": -0.20}, "short": "Les sorts de tes unités reviennent plus vite.",
		"tip": "Tes sorts signature coûtent 20 % de mana de moins."},
	"couronne": {"icon": "giant_slayer", "rarity": "eclat", "name": "Couronne", "trigger": "immediat", "effect": "place_plateau",
		"params": {"slots": 1}, "short": "Une unité de plus sur le plateau.", "tip": "+1 unité sur le plateau."},
	"heros_legendaire": {"icon": "steel_tempest", "rarity": "eclat", "name": "Héros légendaire", "trigger": "immediat", "effect": "unite_au_choix",
		"params": {"cost": 5, "stars": 2, "choices": 3}, "short": "Un héros parmi les plus chers, déjà deux étoiles.",
		"tip": "Une unité de coût 5 ★2 au choix parmi 3."},
	"ordre_de_bataille": {"icon": "battle_trance", "rarity": "eclat", "name": "Ordre de bataille", "trigger": "debut_combat",
		"effect": "depart_rapide", "params": {"dur": 6.0, "as_pct": 0.25, "move_pct": 0.25, "first_spell_mana": 0.5},
		"short": "Tes unités démarrent le combat à toute allure.",
		"tip": "Les 6 premières secondes : +25 % de vitesse d'attaque et de déplacement ; le 1er sort de chaque unité part à mi-mana."},
	"menace": {"icon": "volatile", "rarity": "eclat", "name": "Menace", "trigger": "gardien", "effect": "gardiens_renforces",
		"params": {"guardian_mult": 2.0, "loot_mult": 2, "gold": 2}, "short": "Gardiens plus forts, butin doublé.",
		"tip": "Gardiens deux fois plus forts, butin doublé ; +2 or par gardien vaincu."},
	"tresor_du_dragon": {"icon": "phoenix_blade", "rarity": "eclat", "name": "Trésor du dragon", "trigger": "immediat", "effect": "or_sans_interets",
		"params": {"gold": 40}, "short": "Beaucoup d'or tout de suite, mais plus d'intérêts.",
		"tip": "+40 or tout de suite ; plus aucun intérêt."},
	"niveau_11": {"icon": "storm_lord", "rarity": "eclat", "name": "Niveau 11", "trigger": "immediat", "effect": "niveau_max",
		"params": {"max_level": 11, "xp_now": 10}, "short": "Tu peux monter un niveau plus haut.",
		"tip": "Niveau maximal 11 ; +10 XP tout de suite."},
	"etoile_filante": {"icon": "arcana", "rarity": "eclat", "name": "Étoile filante", "trigger": "passif", "effect": "fusion_rapide",
		"params": {"max_cost": 2, "copies": 2}, "short": "Tes recrues bon marché montent plus vite en étoiles.",
		"tip": "Tes unités de coût 1-2 passent ★2 avec 2 copies au lieu de 3."},
	"arsenal": {"icon": "wide_arc", "rarity": "eclat", "name": "Arsenal", "trigger": "immediat", "effect": "objets_au_choix",
		"params": {"count": 2, "choices": 3}, "short": "Deux objets complets au choix.",
		"tip": "2 objets complets au choix (cartes à 3)."},
	"double_trait": {"icon": "glass_cannon", "rarity": "eclat", "name": "Double trait", "trigger": "passif", "effect": "trait_compte",
		"params": {"kind": "tous", "count": 1, "active_only": 0}, "short": "Tous tes traits comptent une unité de plus.",
		"tip": "+1 au compte de chacun de tes traits présents sur le plateau (familles et armes)."},
	# --- lot ACX-3 (n° 20) : 15 atouts de plus, de trait et d'unité ---
	"maitre_armes": {"icon": "keen_edge", "rarity": "argent", "name": "Maître d'armes", "trigger": "immediat",
		"effect": "trait_au_choix", "params": {"kind": "arme", "count": 1, "choices": 3},
		"short": "Un trait d'arme au choix compte une unité de plus.", "tip": "+1 au compte d'un trait d'arme au choix (parmi 3)."},
	"recrue_doree": {"icon": "light_step", "rarity": "argent", "name": "Recrue dorée", "trigger": "immediat",
		"effect": "unite_au_choix", "params": {"cost": 3, "stars": 1, "choices": 3},
		"short": "Un héros de coût 3 au choix.", "tip": "Une unité de coût 3 au choix parmi 3."},
	"atelier": {"icon": "magnet", "rarity": "argent", "name": "Atelier", "trigger": "immediat", "effect": "objet",
		"params": {"items": ["pince", "creuset"]}, "short": "Une Pince et un Creuset pour tes objets.",
		"tip": "Une Pince (retire les objets intacts) et un Creuset (change les objets complets) tout de suite."},
	"ligne_de_boucliers": {"icon": "featherfall", "rarity": "argent", "name": "Ligne de boucliers", "trigger": "debut_combat",
		"effect": "bouclier_equipe", "params": {"shield_pct": 0.12, "dur": 5.0},
		"short": "Tes unités commencent le combat sous un bouclier.",
		"tip": "Au début du combat : bouclier de 12 % des PV pendant 5 s pour toutes tes unités."},
	"porte_etendard": {"icon": "long_reach", "rarity": "argent", "name": "Porte-étendard", "trigger": "debut_combat",
		"effect": "porteur", "params": {"atk_pct": 0.25, "spell_pct": 0.25},
		"short": "Ton héros le mieux équipé frappe plus fort.",
		"tip": "Ton unité qui porte le plus d'objets (puis la plus chère) : +25 % d'attaque et de puissance des sorts."},
	"serment_rempart": {"icon": "toughness", "rarity": "or", "name": "Serment du Rempart", "trigger": "passif",
		"effect": "trait_plus", "params": {"trait": "rempart", "count": 1, "stats": {"hp": 150}},
		"short": "Un Rempart de plus ; les Rempart ont plus de PV.", "tip": "+1 au compte de Rempart ; Rempart : +150 PV."},
	"pacte_ombre": {"icon": "dive_strike", "rarity": "or", "name": "Pacte de l'Ombre", "trigger": "passif",
		"effect": "trait_plus", "params": {"trait": "ombre", "count": 1, "stats": {"crit": 0.15}},
		"short": "Une Ombre de plus ; les Ombre critiquent plus souvent.", "tip": "+1 au compte d'Ombre ; Ombre : +15 % de critique."},
	"piste_traque": {"icon": "hunter_eye", "rarity": "or", "name": "Piste de la Traque", "trigger": "passif",
		"effect": "trait_plus", "params": {"trait": "traque", "count": 1, "stats": {"as_pct": 0.15}},
		"short": "Une Traque de plus ; les Traque tirent plus vite.",
		"tip": "+1 au compte de Traque ; Traque : +15 % de vitesse d'attaque."},
	"flamme_ferveur": {"icon": "vigor", "rarity": "or", "name": "Flamme de la Ferveur", "trigger": "passif",
		"effect": "trait_plus", "params": {"trait": "ferveur", "count": 1, "stats": {"hp_pct": 0.12}},
		"short": "Une Ferveur de plus ; les Ferveur sont plus robustes.", "tip": "+1 au compte de Ferveur ; Ferveur : +12 % de PV."},
	"savoir_arcane": {"icon": "arcana", "rarity": "or", "name": "Savoir arcane", "trigger": "passif",
		"effect": "trait_plus", "params": {"trait": "arcane", "count": 1, "stats": {"mana_start": 20}},
		"short": "Un Arcane de plus ; les Arcane commencent avec de la mana.",
		"tip": "+1 au compte d'Arcane ; Arcane : +20 mana au début du combat."},
	"jumeaux": {"icon": "air_dash", "rarity": "or", "name": "Jumeaux", "trigger": "immediat", "effect": "copie_unite",
		"params": {"max_cost": 4}, "short": "Une copie de ton héros le plus cher.",
		"tip": "Une copie à une étoile de ton unité la plus chère du plateau (coût 4 au plus), prise à la réserve."},
	"grand_grimoire": {"icon": "lingering", "rarity": "eclat", "name": "Grand grimoire", "trigger": "passif",
		"effect": "stats_equipe", "params": {"spell_pct": 0.35, "mana_start": 30},
		"short": "Les sorts de tes unités frappent plus fort et partent plus tôt.",
		"tip": "+35 % de puissance des sorts et +30 mana au début du combat pour toutes tes unités."},
	"trinite": {"icon": "high_jump", "rarity": "eclat", "name": "Trinité", "trigger": "debut_combat", "effect": "trio_de_tete",
		"params": {"count": 3, "hp_pct": 0.25, "atk_pct": 0.25}, "short": "Tes trois héros les plus chers sont plus forts.",
		"tip": "Tes 3 unités les plus chères (puis les plus étoilées) : +25 % de PV et d'attaque."},
	"miroir_des_ames": {"icon": "echo", "rarity": "eclat", "name": "Miroir des âmes", "trigger": "immediat", "effect": "objet",
		"params": {"items": ["miroir", "miroir", "pince"]}, "short": "Deux Miroirs et une Pince.",
		"tip": "Deux Miroirs (copie à une étoile d'une unité de coût 3 ou moins) et une Pince, tout de suite."},
	"grand_coeur": {"icon": "glacial_shatter", "rarity": "eclat", "name": "Grand cœur", "trigger": "immediat",
		"effect": "trait_compte", "params": {"kind": "famille", "count": 2, "choices": 3},
		"short": "Une famille au choix compte deux unités de plus.", "tip": "+2 au compte d'une famille au choix (parmi 3)."},
}

static var _units: Dictionary = {}


# --- Unités -------------------------------------------------------------------------------------------------------
## Les 60 unités (id de classe -> fiche), lues une fois dans data/autochess_units.json.
static func units() -> Dictionary:
	if _units.is_empty():
		var f := FileAccess.open(UNITS_PATH, FileAccess.READ)
		if f == null:
			push_error("AutochessData : %s introuvable" % UNITS_PATH)
			return _units
		var doc: Variant = JSON.parse_string(f.get_as_text())
		if doc is Dictionary:
			_units = (doc as Dictionary).get("units", {})
	return _units


static func unit(id: String) -> Dictionary:
	return units().get(id, {})


static func unit_ids() -> Array:
	return units().keys()


static func units_of_cost(cost: int) -> Array:
	return unit_ids().filter(func(id): return int(units()[id].cost) == cost)


static func units_with_trait(trait_id: String) -> Array:
	return unit_ids().filter(func(id): return trait_id in (units()[id].traits as Array))


## Nom affiché : celui de la classe (français) dans GameData, sinon celui du fichier.
static func unit_name(id: String) -> String:
	var cd: Dictionary = GameData.classes.get(id, {})
	return String(cd.get("name_fr", unit(id).get("name", id)))


## Multiplicateur de PV et d'attaque d'une unité (coût 1-5, étoiles 1-3).
static func stat_mult(cost: int, stars: int) -> float:
	return float(COST_MULT[clampi(cost, 1, 5) - 1]) * float(STAR_MULT[clampi(stars, 1, MAX_STARS) - 1])


static func spell_mult(stars: int) -> float:
	return float(SPELL_RANK_MULT[clampi(stars, 1, MAX_STARS) - 1])


## Mana max d'un sort de recharge [param cooldown] s (arrondie à la seconde, × 10, bornée à 40-140), puis × ROLE_MANA du
## rôle [param role] (en %, arrondi à la dizaine, bornée à 40-140 ; calcul entier recopié dans tools/autochess_units.py).
static func mana_for(cooldown: float, role := "") -> int:
	var m := clampi(int(floor(cooldown + 0.5)) * MANA_PER_COOLDOWN, MANA_MIN, MANA_MAX)
	var k := int(ROLE_MANA.get(role, 100))
	return clampi((m * k + 500) / 1000 * 10, MANA_MIN, MANA_MAX) if k != 100 else m


## Allonge en mètres d'une portée en cases (mêlée : MELEE_REACH).
static func reach_m(range_cells: int) -> float:
	return MELEE_REACH if range_cells <= 1 else range_cells * CELL + 0.5


## Or rendu à la vente d'une unité.
static func sell_value(cost: int, stars: int) -> int:
	var n: int = SELL_COPIES[clampi(stars, 1, MAX_STARS) - 1]
	return cost * n - (1 if n > 1 and cost >= 2 else 0)


# --- Économie -----------------------------------------------------------------------------------------------------
static func xp_to_next(level: int) -> int:
	return int(XP_TO_NEXT.get(level, 0))


static func shop_odds(level: int) -> Array:
	return SHOP_ODDS[clampi(level, 1, MAX_LEVEL_BONUS)]


static func interest(gold: int, cap := INTEREST_CAP) -> int:
	return mini(floori(maxf(float(gold), 0.0) / INTEREST_STEP), cap)


## Or de série (victoires ou défaites JcJ d'affilée).
static func streak_gold(streak: int) -> int:
	for row in STREAK_GOLD:
		if absi(streak) >= int(row[0]):
			return int(row[1])
	return 0


## Revenu de base d'une manche (« 1-2 » … ; 0 à l'ouverture) ; [param r] : règles de la partie (rules_for).
static func base_income(stage: int, round_i: int, r: Dictionary = {}) -> int:
	if stage <= 1:
		return int((r.get("early_income", EARLY_INCOME) as Dictionary).get("%d-%d" % [stage, round_i], 0))
	return int(r.get("base_income", BASE_INCOME))


# --- Formats et règle du jour (lot ACX-3) -------------------------------------------------------------------------------
## Règles d'une partie : le format [param format] (FORMATS) puis la règle du jour [param day_rule] (DAY_RULES, "" : aucune),
## en un seul dictionnaire (clés absentes : réglages par défaut). « format » et « rule » y sont rappelés.
static func rules_for(format := "classique", day_rule := "") -> Dictionary:
	var out: Dictionary = (FORMATS.get(format, FORMATS.classique) as Dictionary).duplicate(true)
	out["format"] = format if FORMATS.has(format) else "classique"
	out["rule"] = day_rule if DAY_RULES.has(day_rule) else ""
	if out.rule != "":
		out.merge((DAY_RULES[day_rule] as Dictionary).duplicate(true), true)
	return out


## Jour (« 2026-10-17 ») -> graine de la partie du jour (la même pour tous les joueurs ce jour-là ; > 0).
static func daily_seed(day: String) -> int:
	var h := 0
	for c in ("echiquier:" + day).to_utf8_buffer():
		h = (h * 131 + int(c)) % 2147483629
	return maxi(h, 1)


## Règle du jour [param day] : une des 8 de DAY_RULES, tirée par la graine du jour (ordre fixe des clés).
static func daily_rule(day: String) -> String:
	var keys := DAY_RULES.keys()
	keys.sort()
	return String(keys[daily_seed(day) % keys.size()])


# --- PV de joueur -------------------------------------------------------------------------------------------------
static func stage_damage(stage: int) -> int:
	return int(DAMAGE_BASE.get(stage, DAMAGE_BASE_LATE if stage > 7 else 0))


## Défaite en JcJ : base + 1 par unité adverse debout + 1 par étoile au-delà de la première (= somme des étoiles).
static func pvp_damage(stage: int, survivor_stars: Array) -> int:
	var d := stage_damage(stage)
	for s in survivor_stars:
		d += clampi(int(s), 1, MAX_STARS)
	return d


## Défaite contre monstres (unités debout) ou gardien (compte pour GUARDIAN_STANDING).
static func pve_damage(stage: int, standing: int, guardian := false) -> int:
	return stage_damage(stage) + PVE_DAMAGE_BONUS + (GUARDIAN_STANDING if guardian else standing)


# --- Déroulé ------------------------------------------------------------------------------------------------------
static func rounds_in(stage: int, r: Dictionary = {}) -> int:
	return (r.get("stage1", STAGE1_ROUNDS) as Array).size() if stage <= 1 else STAGE_ROUNDS.size()


## Type de la manche « étape-manche » : ouverture, monstres, jcj, choix, gardien ; [param r] : règles (rules_for).
static func round_kind(stage: int, round_i: int, r: Dictionary = {}) -> String:
	var list: Array = r.get("stage1", STAGE1_ROUNDS) if stage <= 1 else STAGE_ROUNDS
	return String(list[clampi(round_i, 1, list.size()) - 1])


static func is_augment_round(stage: int, round_i: int, r: Dictionary = {}) -> bool:
	return ("%d-%d" % [stage, round_i]) in (r.get("augment_rounds", AUGMENT_ROUNDS) as Array)


static func prep_time(stage: int, round_i: int, r: Dictionary = {}) -> float:
	return (float(r.get("prep_stage1", PREP_TIME_STAGE1)) if stage <= 1 else float(r.get("prep_time", PREP_TIME))) \
		+ (PREP_AUGMENT_BONUS if is_augment_round(stage, round_i, r) else 0.0)


## Coûts [min, max] des unités du choix partagé d'une étape.
static func carousel_costs(stage: int) -> Array:
	return CAROUSEL_COSTS.get(stage, CAROUSEL_COSTS_LATE)


## Nombre de derniers adversaires à éviter à l'appariement selon les vivants (3, puis 2, puis 1 à 4 vivants ou moins).
static func avoid_recent(alive: int) -> int:
	return 3 if alive >= 7 else (2 if alive >= 5 else 1)


## Butin d'une manche ({} si rien) ; [param won] : victoire. Gardien au-delà de 7 : celui de 7-7.
static func loot(stage: int, round_i: int, won: bool, r: Dictionary = {}) -> Dictionary:
	var key := "%d-%d" % [stage, round_i]
	var own: Dictionary = r.get("loot", {})
	if own.has(key):
		return (own[key] as Dictionary).get("win" if won else "loss", {})
	if not LOOT.has(key) and stage > 7 and round_kind(stage, round_i, r) == "gardien":
		key = "7-7"
	return (LOOT.get(key, {}) as Dictionary).get("win" if won else "loss", {})


# --- Traits -------------------------------------------------------------------------------------------------------
static func trait_thresholds(trait_id: String) -> Array:
	return FAMILY_THRESHOLDS if String(TRAITS.get(trait_id, {}).get("kind", "")) == "famille" else WEAPON_THRESHOLDS


## Palier atteint (0 = inactif, 1 à 3) pour [param count] unités distinctes du trait.
static func trait_tier(trait_id: String, count: int) -> int:
	var t := 0
	for th in trait_thresholds(trait_id):
		if count >= int(th):
			t += 1
	return t


## Paramètres du palier atteint ({} si inactif).
static func trait_params(trait_id: String, count: int) -> Dictionary:
	var t := trait_tier(trait_id, count)
	return {} if t == 0 else (TRAITS[trait_id].tiers as Array)[t - 1]


static func family_traits() -> Array:
	return TRAITS.keys().filter(func(k): return String(TRAITS[k].kind) == "famille")


static func weapon_traits() -> Array:
	return TRAITS.keys().filter(func(k): return String(TRAITS[k].kind) == "arme")


## Lot ACX-4 : genre affiché d'un trait (« Famille » / « Style »).
static func trait_kind_name(trait_id: String) -> String:
	return "Famille" if String(TRAITS.get(trait_id, {}).get("kind", "")) == "famille" else "Style"


## Familles reliées par un style (ses deux lignées) ; [] pour une famille.
static func style_families(trait_id: String) -> Array:
	var out: Array = []
	for lin in TRAITS.get(trait_id, {}).get("lineages", []):
		var f := String((unit(String(lin)).get("traits", [""]) as Array)[0])
		if f != "" and not f in out:
			out.append(f)
	return out


## Ligne d'explication d'un trait (fiche du trait, infobulle de la colonne) : genre, familles reliées, héros (coût croissant).
static func trait_blurb(trait_id: String, full := true) -> String:
	var ids := units_with_trait(trait_id)
	if not full:  # version courte (fiche du trait) : genre et familles reliées
		if String(TRAITS.get(trait_id, {}).get("kind", "")) == "famille":
			var bridges: Array = ids.filter(func(id): return String((units()[id].traits as Array)[0]) != trait_id)
			return "Famille : %d héros%s." % [ids.size() - bridges.size(), " + %s (pont)" % unit_name(String(bridges[0])) if bridges.size() == 1 else ""]
		return "Style : relie %s (%d héros)." % [" et ".join(style_families(trait_id).map(func(f): return String(TRAITS[f].name))), ids.size()]
	ids.sort_custom(func(a, b): return [int(units()[a].cost), unit_name(a)] < [int(units()[b].cost), unit_name(b)])
	var names: Array = ids.map(func(id): return "%s (%d)" % [unit_name(id), int(units()[id].cost)])
	if String(TRAITS.get(trait_id, {}).get("kind", "")) == "famille":
		return "Famille · %s" % ", ".join(names)
	var fams: Array = style_families(trait_id).map(func(f): return String(TRAITS[f].name))
	return "Style %s · %s" % [" et ".join(fams), ", ".join(names)]


# --- Objets -------------------------------------------------------------------------------------------------------
## Objet complet né de deux composants (« » si aucun) ; Insigne + composant : « embleme », deux Insignes : « couronne ».
static func combine(a: String, b: String) -> String:
	if a == "insigne" or b == "insigne":
		if a == b:
			return "couronne"
		return "embleme" if COMPONENTS.has(a) and COMPONENTS.has(b) else ""
	for id in ITEMS:
		var p: Array = ITEMS[id].parts
		if (p[0] == a and p[1] == b) or (p[0] == b and p[1] == a):
			return String(id)
	return ""


static func item(id: String) -> Dictionary:
	if ITEMS.has(id):
		return ITEMS[id]
	if SPECIAL_ITEMS.has(id):
		return SPECIAL_ITEMS[id]
	return COMPONENTS.get(id, {})


## Stats d'un objet complet = somme des stats de ses deux composants (l'effet est à part : « effect » / « params »).
static func item_stats(id: String) -> Dictionary:
	if COMPONENTS.has(id):
		return (COMPONENTS[id].stats as Dictionary).duplicate()
	var out := {}
	for p in item(id).get("parts", []):
		for k in (COMPONENTS.get(p, {}).get("stats", {}) as Dictionary):
			out[k] = out.get(k, 0) + COMPONENTS[p].stats[k]
	return out


# --- Atouts -------------------------------------------------------------------------------------------------------
static func augment(id: String) -> Dictionary:
	return AUGMENTS.get(id, {})


static func augments_of(rarity: String) -> Array:
	return AUGMENTS.keys().filter(func(k): return String(AUGMENTS[k].rarity) == rarity)
