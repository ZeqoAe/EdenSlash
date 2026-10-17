class_name MobaData
extends RefCounted
## Les Deux Voies (MOBA 4 contre 4, étude conception/benchmark/MOBA.md § 7, lot MB-A, rapport R_MB_A.md) : toutes les
## règles chiffrées du mode à un seul endroit, réglages en tête (valeurs de départ de la spécification, à mesurer par le
## lot MB-J). Rien ici ne touche à la scène : la carte (MobaMap, MB-B), les structures et les sbires (MobaDirector, MB-C),
## les héros en partie et la boutique (MB-D) lisent ces tables.
##
## Côté joueur, le mot « MOBA » est interdit (BIBLE § 12) : le mode s'appelle « Les Deux Voies » ; « moba » reste le nom
## interne. Mode scellé (fiche « moba » de TeamMatch, Modes.sealed) : rien du compte n'entre en partie.
##
## Combat entre héros : profil « moba » de ModeRules ([constant RULES], enregistré par [method ensure_rules]) lu par PvpCaps
## (échelle 0,09 : un 1 contre 1 égal en 10-16 s, à mesurer). Unités de dégâts des structures : 1 unité = une auto-attaque
## d'un héros de référence au niveau attendu à cet instant de la partie ([method ref_auto]) ; les sbires frappent les
## structures en unités fixes ([constant MINIONS] « struct »).

# --- déroulé (secondes de partie, MOBA.md § 7.2) ------------------------------------------------------------------------
const FIRST_WAVE := 40.0
const WAVE_EVERY := 30.0
const RAM_EVERY := 3  # un bélier toutes les 3 vagues…
const RAM_EVERY_LATE := 2  # … toutes les 2 dès RAM_LATE_AT
const RAM_LATE_AT := 720.0
const CAMPS_AT := 90.0
const GUARDIAN_AT := 180.0
const T1_GUARD_UNTIL := 240.0  # avant : les T1 ne prennent que la moitié des dégâts
const T1_GUARD_MULT := 0.5
const COLOSSUS_AT := 540.0
const RESPAWN_UP_AT := 900.0  # réapparition + 25 %
const TIDE_AT := 1080.0  # Marée finale : réapparition + 50 %, un géant de plus par vague, Cœurs vulnérables (lot MB-F)
const END_AT := 1500.0  # fin au temps : structures détruites, puis Cœur le moins entamé, puis or total
const ANNOUNCE := {"guardian": 45.0, "colossus": 60.0}

# --- héros en partie (§ 7.3) ---------------------------------------------------------------------------------------------
const LEVEL_MAX := 12
## Fiche d'un héros de la classe au niveau 30 + 5 × (niveau de partie − 1) : 30 à 85.
const SHEET_BASE := 30
const SHEET_STEP := 5
## XP pour passer au niveau suivant : 120, 160, 200 … 520 (3 520 au total pour atteindre 12).
const XP_FIRST := 120
const XP_STEP := 40
const XP_GAIN := {"melee": 30, "ranged": 20, "ram": 60, "giant": 90, "camp_small": 60, "camp_buff": 100, "guardian": 150,
	"colossus": 250, "hero_base": 100, "hero_per_level": 25, "per_second": 1.0}
const SHARE_RADIUS := 15.0  # XP et or des sbires partagés entre les héros alliés à 15 m
const CATCHUP := 0.3  # + 30 % d'XP et d'or des sbires…
const CATCHUP_GAP := 2.0  # … sous la moyenne adverse de 2 niveaux
const START_GOLD := 500
const PASSIVE_GOLD := 2.0  # or par seconde, dès FIRST_WAVE
const LAST_HIT := 1.0  # part de l'or d'un sbire au dernier coup…
const NEAR_SHARE := 0.6  # … à chaque autre allié à 15 m
const STRAY_SHARE := 0.5  # … aux héros à 15 m si un sbire ou une tour l'achève
const BOUNTY := {"kill": 300, "first_blood": 100, "assist": 150, "streak_step": 100, "streak_from": 2, "max": 700,
	"t1": 250, "t2": 300, "core": 0}
## Réapparition : 5 + 2 × niveau s (7 à 29 s), × 1,25 dès RESPAWN_UP_AT, × 1,5 dès TIDE_AT.
const RESPAWN_BASE := 5.0
const RESPAWN_PER_LEVEL := 2.0
const RECALL_TIME := 6.0  # touche « S'extraire » : canalisation coupée par un coup
const FOUNTAIN_REGEN := 0.12  # part des PV max par seconde à la fontaine
const FOUNTAIN_RADIUS := 9.0
const START_POTIONS := 2  # potions de soin au départ (core/potions.gd)

## Niveau de partie attendu d'un héros de voie à l'instant t (s) : sert à la force des sbires (ils suivent la partie) et
## à l'unité de dégâts des structures ; lot MB-C : niveau des héros en attendant l'XP du lot MB-D. À mesurer (MB-J).
const EXPECTED_LEVEL := [[0.0, 1.0], [60.0, 1.4], [120.0, 2.4], [180.0, 3.3], [300.0, 4.8], [420.0, 6.2], [540.0, 7.3],
	[660.0, 8.3], [780.0, 9.3], [900.0, 10.4], [1000.0, 11.3], [1080.0, 12.0]]
## Classes de référence (une par famille, + une de plus en Ferveur et en Traque) : fiche moyenne d'un héros.
const REF_CLASSES := ["warrior", "thief", "hunter", "cleric", "magician", "ranger"]

## Postes (§ 7.3, § 7.6) : conseil par famille (1 Rempart, 2 Ombre, 3 Traque, 4 Ferveur, 5 Arcane), jamais imposé.
## lane : 0 = Voie du Soleil (haut), 1 = Voie des Brumes (bas), -1 = jungle.
const ROLES := [
	{"id": "brumes", "name": "Voie des Brumes", "short": "Solo", "lane": 1, "families": [1]},
	{"id": "jungle", "name": "Jungle", "short": "Jungle", "lane": -1, "families": [2]},
	{"id": "soleil_tir", "name": "Voie du Soleil", "short": "Tir", "lane": 0, "families": [3, 5]},
	{"id": "soleil_soutien", "name": "Voie du Soleil", "short": "Soutien", "lane": 0, "families": [4]},
]
const LANE_NAMES := ["Voie du Soleil", "Voie des Brumes"]

# --- combat entre héros : profil « moba » de ModeRules (§ 7.3) -----------------------------------------------------------
## Échelle 0,09 (Arènes 0,024 : manches de 30 à 90 s, trop long pour un échange en voie ; Battle royale 0,055) ; soins
## × 0,6 ; un coup ≤ 22 % des PV max, rafale ≤ 50 % sur 2 s ; pas d'acharnement (les objectifs font pression).
const RULES := {
	"dmg_scale": 0.09, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": 0.6, "max_mitigation": PvpCaps.MAX_MITIGATION,
	"pressure_start": 100000.0, "pressure_step": PvpCaps.PRESSURE_STEP, "pct_weight": 1.0, "sudden_after": 100000.0,
	"hit_cap": 0.22, "burst_cap": 0.5, "burst_window": 2.0, "burst_excess": 0.25, "caps": PvpCaps.CAPS,
}

# --- sbires (§ 7.5, budgets R_MB0 § 6) -----------------------------------------------------------------------------------
## Par genre : ids des monstres (camp bleu, camp rouge) ; hits = auto-attaques d'un héros au niveau attendu pour le tuer ;
## hero = part des PV max d'un héros retirée par un coup (après sa défense) ; minion = part des PV d'un sbire mêlée retirée
## par un coup sur un sbire ; struct = unités de dégâts sur une structure ; tower = part des PV d'un sbire ordinaire retirée
## par un tir de tour ; speed (m/s), aggro (m : portée de recherche), reach (m : portée du coup) ; xp, gold.
## Calibrage du lot MB-C (R_MB_C § 3, 13 réglages × 6 parties de vagues seules) : des combats de sbires courts (un mêlée en
## ≈ 3 coups) pour que deux vagues égales s'annulent avant la suivante (sinon elles s'empilent en grosses vagues qui
## écrasent une tour, des deux côtés), et des coups de siège forts (struct) : un camp × 1,2 fait tomber une T1 adverse en
## 7:14-11:17 (médiane 9:45 sur 6 parties, dans les deux sens), des vagues égales laissent toutes les tours à 94 % ou plus
## après 20 min.
const MINIONS := {
	"melee": {"name": "Sbire", "ids": [56005, 56001], "hits": 4.0, "hero": 0.03, "minion": 0.375, "struct": 3.4, "tower": 0.5,
		"speed": 4.0, "aggro": 9.0, "reach": 1.6, "xp": 30, "gold": 20},
	"ranged": {"name": "Sbire tireur", "ids": [56003, 56003], "hits": 3.0, "hero": 0.025, "minion": 0.3, "struct": 2.72, "tower": 1.0,
		"speed": 4.0, "aggro": 11.0, "reach": 8.0, "xp": 20, "gold": 15},
	"ram": {"name": "Bélier", "ids": [56007, 56002], "hits": 10.0, "hero": 0.05, "minion": 0.6, "struct": 6.8, "tower": 0.25,
		"speed": 3.8, "aggro": 9.0, "reach": 2.2, "xp": 60, "gold": 45},
	"giant": {"name": "Géant", "ids": [56006, 56004], "hits": 25.0, "hero": 0.06, "minion": 0.9, "struct": 10.2, "tower": 0.1,
		"speed": 3.6, "aggro": 9.0, "reach": 2.6, "xp": 90, "gold": 60},
}
## Hasard des sbires (rythme des coups, pas, décalage dans la voie), en part du hasard d'un monstre du jeu : faible, pour que
## deux vagues égales restent égales (lot MB-C).
const JITTER := 0.3
## Vague : 3 mêlées + 2 tireurs ; un bélier une vague sur RAM_EVERY ; un géant par vague dans une voie dont la T2 adverse
## est tombée (et un de plus à la Marée, lot MB-F).
const WAVE := ["melee", "melee", "melee", "ranged", "ranged"]
const MINION_CAP := 60  # sbires vivants au plus (budget R_MB0 § 6)
const MINION_RETARGET := 0.5  # s : cible revue (décalée par sbire)
const HELP_RADIUS := 10.0  # m : un héros ennemi qui frappe un héros allié devient la cible des sbires…
const HELP_TIME := 2.0  # … pendant 2 s

# --- structures (§ 7.5) ---------------------------------------------------------------------------------------------------
## Tours : portée 9 m ; un tir = 10 % des PV max d'un héros (× 1,4 par tir de suite sur le même héros, × 2,2 au plus,
## remis à zéro après 5 s) ; sbires : part de leurs PV ([constant MINIONS] « tower ») ; vise les sbires d'abord, puis les
## héros, et bascule sur le héros qui frappe un héros allié à portée. PV en unités : une T1 seule contre une vague tient
## ≈ 60 s ; 2 héros niveau 6 + une vague l'abattent en ≈ 20 s (à mesurer, test_mb_lanes). Sans sbire ennemi à 12 m, une
## structure ne prend qu'un tiers des dégâts (protection) ; une T2 est invulnérable tant que la T1 de sa voie tient ; le
## Cœur l'est tant que ses deux T2 tiennent (et jusqu'à la Marée).
const TOWER := {"range": 9.0, "period": 1.0, "hero_shot": 0.10, "streak": 0.4, "streak_max": 2.2, "streak_reset": 5.0,
	"hp_t1": 110.0, "hp_t2": 130.0, "radius": 2.0, "height": 7.0}
const CORE := {"range": 10.0, "period": 0.5, "hero_shot": 0.06, "hp_mult": 1.5, "radius": 3.2, "height": 6.0}
## Réparation hors combat (lot MB-C) : unités par seconde après REPAIR_DELAY s sans coup, jusqu'au haut du tiers en cours
## (un sbire égaré n'use pas une tour à la longue ; une poussée tenue gagne des tiers pour de bon).
const REPAIR := 0.2
const REPAIR_DELAY := 8.0
const PROTECT_RADIUS := 12.0
const PROTECT_MULT := 0.34  # − 66 % de dégâts subis sans sbire ennemi proche
const TOWER_AT := [0.11, 0.30]  # T2, T1 : part de la voie depuis sa base
const BOLT_SPEED := 28.0

# --- jungle et objectifs (§ 7.4, § 7.5 ; joués par le lot MB-F) -----------------------------------------------------------
## Camps neutres : n'attaquent que qui les a frappés, laisse de 12 m (reviennent et regagnent tous leurs PV).
const CAMPS := {
	"source": {"name": "Source", "kind": "buff", "color": "lagon", "monsters": 1, "secs": 20.0, "respawn": 150.0,
		"effect": "cdr", "buff_time": 90.0, "buff": {"cdr": 0.2}, "xp": "camp_buff", "gold": 100,
		"text": "Tes recharges sont plus rapides."},
	"braise": {"name": "Braise", "kind": "buff", "color": "fraise", "monsters": 1, "secs": 20.0, "respawn": 150.0,
		"effect": "burn_slow", "buff_time": 90.0, "buff": {"burn": 2.0, "chill": 1.0}, "xp": "camp_buff", "gold": 100,
		"text": "Tes auto-attaques brûlent et ralentissent."},
	"petit": {"name": "Petit camp", "kind": "small", "color": "pomme", "monsters": 2, "secs": 12.0, "respawn": 90.0,
		"xp": "camp_small", "gold": 60, "text": "De l'or et de l'expérience pour la jungle."},
}
const CAMP_LEASH := 12.0
## Objectifs de la rivière : boss de la bibliothèque (BossLibrary.spawn), tirés à la graine de la partie.
const OBJECTIVES := {
	"guardian": {"name": "Gardien", "at": GUARDIAN_AT, "respawn": 180.0, "tier": 1, "secs": 25.0, "xp": "guardian",
		"reward": "seal", "color": "mandarine", "text": "Un Sceau pour toute l'équipe : un peu plus de dégâts et de PV."},
	"colossus": {"name": "Colosse", "at": COLOSSUS_AT, "respawn": 240.0, "tier": 3, "secs": 45.0, "fury_at": 90.0,
		"xp": "colossus", "reward": "banner", "color": "amethyste", "text": "La Bannière : les sbires proches de toi grandissent."},
}
const SEAL := {"dmg": 0.04, "hp": 0.04, "max": 3}
const BANNER := {"time": 150.0, "minion_mult": 1.5, "radius": 12.0, "recall": 3.0}

# --- boutique : 40 objets (§ 7.7 ; appliqués par le lot MB-D) -------------------------------------------------------------
## Valeurs en part de la fiche de base de la classe au niveau de partie (« atk » 0,10 = 10 % de l'attaque de base).
## text : la phrase du joueur (jamais de pourcentage) ; tip : les chiffres, pour l'infobulle ; proc : déclencheur de Procs.
## Types : composant, bottes, attaque, magie, défense, soutien, polyvalent, potion. Places : 6 (bottes comprises).
const SLOTS := 6
const SELL_BACK := 0.7
const SELL_HOLD := 0.6  # s : maintien pour vendre
const TABS := [["advised", "Conseillé"], ["attack", "Attaque"], ["magic", "Magie"], ["defense", "Défense"],
	["support", "Soutien"], ["boots", "Bottes"], ["potion", "Potions"]]
const ITEMS := [
	{"id": "lame_courte", "name": "Lame courte", "type": "composant", "price": 350, "recipe": [], "stats": {"atk": 0.10},
		"text": "Plus d'attaque.", "tip": "+10 % d'attaque"},
	{"id": "grimoire_use", "name": "Grimoire usé", "type": "composant", "price": 350, "recipe": [], "stats": {"matk": 0.10},
		"text": "Plus de magie.", "tip": "+10 % de magie"},
	{"id": "cotte_mailles", "name": "Cotte de mailles", "type": "composant", "price": 400, "recipe": [], "stats": {"def": 0.12},
		"text": "Plus de défense.", "tip": "+12 % de défense"},
	{"id": "gemme_vie", "name": "Gemme de vie", "type": "composant", "price": 400, "recipe": [], "stats": {"hp": 0.10},
		"text": "Plus de PV.", "tip": "+10 % de PV"},
	{"id": "gant_vitesse", "name": "Gant de vitesse", "type": "composant", "price": 450, "recipe": [], "stats": {"atk_speed": 0.12},
		"text": "Tu frappes plus vite.", "tip": "+12 % de vitesse d'attaque"},
	{"id": "oeil_faucon", "name": "Œil de faucon", "type": "composant", "price": 500, "recipe": [], "stats": {"crit": 0.08},
		"text": "Plus de coups critiques.", "tip": "+8 points de critique"},
	{"id": "sablier_fele", "name": "Sablier fêlé", "type": "composant", "price": 500, "recipe": [], "stats": {"cdr": 0.08},
		"text": "Tes recharges raccourcissent.", "tip": "−8 % de recharge"},
	{"id": "plume_soin", "name": "Plume de soin", "type": "composant", "price": 450, "recipe": [], "stats": {"heal_power": 0.12},
		"text": "Tes soins sont plus forts.", "tip": "+12 % de puissance de soin"},
	{"id": "croc_vampire", "name": "Croc vampirique", "type": "composant", "price": 550, "recipe": [], "stats": {"lifesteal": 0.05},
		"text": "Tes coups te soignent un peu.", "tip": "+5 % de vol de vie"},
	{"id": "bottes_marche", "name": "Bottes de marche", "type": "bottes", "price": 300, "recipe": [], "stats": {"move": 0.08},
		"text": "Tu cours plus vite.", "tip": "+8 % de vitesse de déplacement"},
	{"id": "lame_braise", "name": "Lame de braise", "type": "attaque", "price": 2400, "recipe": ["lame_courte", "oeil_faucon"],
		"stats": {"atk": 0.15, "crit": 0.10}, "proc": {"trigger": "crit", "effect": "burn", "chance": 1.0, "cd": 1.0},
		"text": "Tes critiques brûlent.", "tip": "+15 % d'attaque, +10 points de critique ; un critique enflamme la cible"},
	{"id": "croc_chasseur", "name": "Croc du chasseur", "type": "attaque", "price": 2300, "recipe": ["lame_courte", "croc_vampire"],
		"stats": {"atk": 0.15, "lifesteal": 0.06}, "proc": {"trigger": "kill_hero", "effect": "heal", "heal": 0.15, "cd": 5.0},
		"text": "Éliminer un héros te soigne.", "tip": "+15 % d'attaque, +6 % de vol de vie ; une élimination rend 15 % des PV"},
	{"id": "arc_tempete", "name": "Arc-tempête", "type": "attaque", "price": 2600, "recipe": ["gant_vitesse", "oeil_faucon"],
		"stats": {"atk_speed": 0.2, "crit": 0.08}, "proc": {"trigger": "basic_hit", "effect": "lightning", "every": 3, "cd": 0.0},
		"text": "Un coup sur trois fait jaillir la foudre.", "tip": "+20 % de vitesse d'attaque, +8 points de critique ; foudre un coup sur trois"},
	{"id": "faux_lune", "name": "Faux de la Lune", "type": "attaque", "price": 2400, "recipe": ["lame_courte", "sablier_fele"],
		"stats": {"atk": 0.12, "cdr": 0.1}, "proc": {"trigger": "skill_cast", "effect": "empower", "mult": 1.5, "cd": 1.5},
		"text": "Après un sort, ton coup suivant frappe plus fort.", "tip": "+12 % d'attaque, −10 % de recharge ; coup suivant × 1,5"},
	{"id": "brise_garde", "name": "Brise-garde", "type": "attaque", "price": 2500, "recipe": ["lame_courte", "lame_courte"],
		"stats": {"atk": 0.2, "pen": 0.25}, "text": "Tes coups traversent une part de la défense.",
		"tip": "+20 % d'attaque ; ignore 25 % de la défense"},
	{"id": "lame_executeur", "name": "Lame de l'exécuteur", "type": "attaque", "price": 2600, "recipe": ["lame_courte", "gant_vitesse"],
		"stats": {"atk": 0.15, "atk_speed": 0.1, "execute": 0.2}, "text": "Plus fort contre les héros affaiblis.",
		"tip": "+15 % d'attaque, +10 % de vitesse d'attaque ; jusqu'à +20 % de dégâts sur un héros sous la moitié de ses PV"},
	{"id": "orbe_marees", "name": "Orbe des marées", "type": "magie", "price": 2300, "recipe": ["grimoire_use", "sablier_fele"],
		"stats": {"matk": 0.15, "cdr": 0.08}, "proc": {"trigger": "skill_hit_hero", "effect": "shield", "shield": 0.08, "cd": 8.0},
		"text": "Un sort qui touche un héros te protège un instant.", "tip": "+15 % de magie, −8 % de recharge ; bouclier de 8 % des PV"},
	{"id": "baton_eclipse", "name": "Bâton de l'éclipse", "type": "magie", "price": 2800, "recipe": ["grimoire_use", "grimoire_use"],
		"stats": {"matk": 0.2, "matk_total": 0.25}, "text": "Ta magie grandit encore.", "tip": "+20 % de magie, puis +25 % de toute ta magie"},
	{"id": "grimoire_echos", "name": "Grimoire des échos", "type": "magie", "price": 2600, "recipe": ["grimoire_use", "oeil_faucon"],
		"stats": {"matk": 0.15, "crit": 0.06}, "proc": {"trigger": "skill_hit", "effect": "echo", "chance": 0.2, "cd": 2.0},
		"text": "Tes sorts frappent parfois deux fois.", "tip": "+15 % de magie, +6 points de critique ; un sort sur cinq frappe deux fois"},
	{"id": "sceptre_givre", "name": "Sceptre du givre", "type": "magie", "price": 2400, "recipe": ["grimoire_use", "gemme_vie"],
		"stats": {"matk": 0.12, "hp": 0.1}, "proc": {"trigger": "skill_hit", "effect": "chill", "time": 1.5, "cd": 0.0},
		"text": "Tes sorts ralentissent.", "tip": "+12 % de magie, +10 % de PV ; ralentit 1,5 s"},
	{"id": "lanterne_ames", "name": "Lanterne des âmes", "type": "magie", "price": 2300, "recipe": ["grimoire_use", "croc_vampire"],
		"stats": {"matk": 0.12, "spell_vamp": 0.1}, "text": "Tes sorts te soignent.", "tip": "+12 % de magie ; 10 % des dégâts des sorts soignent"},
	{"id": "egide_rempart", "name": "Égide du Rempart", "type": "défense", "price": 2400, "recipe": ["cotte_mailles", "gemme_vie"],
		"stats": {"def": 0.15, "hp": 0.12, "crowd_def": 0.1}, "text": "Plus solide quand ils sont plusieurs sur toi.",
		"tip": "+15 % de défense, +12 % de PV ; +10 % de défense par ennemi proche au-delà du premier"},
	{"id": "coeur_pierre", "name": "Cœur de pierre", "type": "défense", "price": 2500, "recipe": ["gemme_vie", "gemme_vie"],
		"stats": {"hp": 0.25, "ooc_regen": 0.03}, "text": "Hors combat, tu reprends vite des forces.",
		"tip": "+25 % de PV ; hors combat, 3 % des PV par seconde"},
	{"id": "cape_epines", "name": "Cape d'épines", "type": "défense", "price": 2300, "recipe": ["cotte_mailles", "cotte_mailles"],
		"stats": {"def": 0.25, "thorns": 0.15}, "text": "Qui te frappe se blesse.", "tip": "+25 % de défense ; renvoie 15 % des auto-attaques subies"},
	{"id": "bouclier_gardien", "name": "Bouclier du gardien", "type": "défense", "price": 2400, "recipe": ["cotte_mailles", "sablier_fele"],
		"stats": {"def": 0.15, "cdr": 0.06}, "proc": {"trigger": "low_hp", "effect": "shield", "shield": 0.25, "cd": 60.0},
		"text": "Au bord de la chute, un bouclier te sauve.", "tip": "+15 % de défense, −6 % de recharge ; bouclier de 25 % des PV (60 s)"},
	{"id": "armure_vivante", "name": "Armure vivante", "type": "défense", "price": 2200, "recipe": ["gemme_vie", "plume_soin"],
		"stats": {"hp": 0.15, "heal_taken": 0.2}, "text": "Les soins reçus sont plus forts.", "tip": "+15 % de PV ; +20 % de soins reçus"},
	{"id": "heaume_colosse", "name": "Heaume du colosse", "type": "défense", "price": 2300, "recipe": ["cotte_mailles", "gant_vitesse"],
		"stats": {"def": 0.15, "tenacity": 0.3}, "text": "Les contrôles te tiennent moins longtemps.",
		"tip": "+15 % de défense ; contrôles subis 30 % plus courts"},
	{"id": "encensoir", "name": "Encensoir sacré", "type": "soutien", "price": 2200, "recipe": ["plume_soin", "plume_soin"],
		"stats": {"heal_power": 0.25}, "proc": {"trigger": "heal_ally", "effect": "buff", "status": "frenzy", "time": 4.0, "cd": 6.0},
		"text": "Soigner un allié le rend plus rapide à frapper.", "tip": "+25 % de puissance de soin ; l'allié soigné frappe plus vite 4 s"},
	{"id": "medaillon_aurores", "name": "Médaillon des aurores", "type": "soutien", "price": 2300, "recipe": ["plume_soin", "gemme_vie"],
		"stats": {"heal_power": 0.15, "hp": 0.1}, "proc": {"trigger": "heal_ally", "effect": "shield", "shield": 0.1, "cd": 60.0},
		"text": "Ton prochain soin protège aussi.", "tip": "+15 % de puissance de soin, +10 % de PV ; bouclier de 10 % des PV (60 s)"},
	{"id": "harpe_vent", "name": "Harpe du vent", "type": "soutien", "price": 2100, "recipe": ["plume_soin", "bottes_marche"],
		"stats": {"heal_power": 0.15, "move": 0.05}, "proc": {"trigger": "heal_ally", "effect": "buff", "status": "haste", "time": 3.0, "cd": 6.0},
		"text": "Soigner un allié l'accélère.", "tip": "+15 % de puissance de soin, +5 % de vitesse ; l'allié soigné court plus vite 3 s"},
	{"id": "etendard_voies", "name": "Étendard des voies", "type": "soutien", "price": 2200, "recipe": ["gemme_vie", "sablier_fele"],
		"stats": {"hp": 0.12, "cdr": 0.08, "minion_aura": 0.2}, "text": "Les sbires près de toi frappent plus fort.",
		"tip": "+12 % de PV, −8 % de recharge ; sbires alliés à 10 m : +20 % de dégâts"},
	{"id": "sablier_sage", "name": "Sablier du sage", "type": "polyvalent", "price": 2400, "recipe": ["sablier_fele", "sablier_fele"],
		"stats": {"cdr": 0.15}, "proc": {"trigger": "kill_hero", "effect": "cdr", "cdr": 0.3, "cd": 1.0},
		"text": "Une élimination raccourcit tes recharges.", "tip": "−15 % de recharge ; une élimination ou une aide retire 30 % des recharges en cours"},
	{"id": "bottes_elan", "name": "Bottes de l'élan", "type": "bottes", "price": 1000, "recipe": ["bottes_marche", "gant_vitesse"],
		"stats": {"move": 0.12, "atk_speed": 0.15}, "text": "Tu cours et tu frappes plus vite.", "tip": "+12 % de vitesse, +15 % de vitesse d'attaque"},
	{"id": "bottes_rempart", "name": "Bottes du rempart", "type": "bottes", "price": 1000, "recipe": ["bottes_marche", "cotte_mailles"],
		"stats": {"move": 0.12, "def": 0.12}, "text": "Tu cours plus vite et tiens mieux.", "tip": "+12 % de vitesse, +12 % de défense"},
	{"id": "bottes_sage", "name": "Bottes du sage", "type": "bottes", "price": 1000, "recipe": ["bottes_marche", "sablier_fele"],
		"stats": {"move": 0.12, "cdr": 0.1}, "text": "Tu cours plus vite et tes recharges raccourcissent.", "tip": "+12 % de vitesse, −10 % de recharge"},
	{"id": "bottes_vent", "name": "Bottes du vent", "type": "bottes", "price": 1000, "recipe": ["bottes_marche", "bottes_marche"],
		"stats": {"move": 0.14, "ooc_move": 0.12}, "text": "Tu cours vite, encore plus hors combat.", "tip": "+14 % de vitesse, +12 % hors combat"},
	{"id": "potion_soin", "name": "Potion de soin", "type": "potion", "price": 50, "recipe": [], "potion": "heal",
		"text": "Rend des PV d'un coup.", "tip": "Rend 35 % des PV max (touche C)"},
	{"id": "potion_elan", "name": "Potion d'élan", "type": "potion", "price": 75, "recipe": [], "potion": "haste",
		"text": "Tu cours plus vite un moment.", "tip": "+30 % de vitesse 10 s (touche V)"},
	{"id": "potion_rage", "name": "Potion de rage", "type": "potion", "price": 100, "recipe": [], "potion": "frenzy",
		"text": "Tu frappes plus vite un moment.", "tip": "+30 % de vitesse d'attaque 10 s (touche V)"},
	{"id": "potion_acuite", "name": "Potion d'acuité", "type": "potion", "price": 100, "recipe": [], "potion": "keen",
		"text": "Plus de coups critiques un moment.", "tip": "+25 % de chances de critique 10 s (touche V)"},
]
## Types de la boutique par onglet.
const TAB_TYPES := {"attack": ["attaque", "polyvalent"], "magic": ["magie", "polyvalent"], "defense": ["défense"],
	"support": ["soutien"], "boots": ["bottes"], "potion": ["potion"]}
## Parcours conseillés (2 par famille, § 7.7) : objets finis dans l'ordre d'achat (les composants viennent avant).
const BUILDS := {
	1: [["bottes_rempart", "egide_rempart", "cape_epines", "coeur_pierre"], ["bottes_rempart", "heaume_colosse", "bouclier_gardien", "egide_rempart"]],
	2: [["bottes_elan", "lame_braise", "brise_garde", "croc_chasseur"], ["bottes_sage", "faux_lune", "lame_executeur", "bouclier_gardien"]],
	3: [["bottes_elan", "arc_tempete", "lame_braise", "lame_executeur"], ["bottes_elan", "croc_chasseur", "arc_tempete", "brise_garde"]],
	4: [["bottes_sage", "encensoir", "medaillon_aurores", "armure_vivante"], ["bottes_vent", "harpe_vent", "etendard_voies", "medaillon_aurores"]],
	5: [["bottes_sage", "baton_eclipse", "grimoire_echos", "orbe_marees"], ["bottes_sage", "sceptre_givre", "lanterne_ames", "baton_eclipse"]],
}

const KITS_PATH := "res://data/moba_kits.json"

static var _kits: Dictionary = {}
static var _items: Dictionary = {}
static var _ref: Dictionary = {}  # niveau de fiche -> {hp, def, auto}


# --- règles --------------------------------------------------------------------------------------

## Enregistre le profil « moba » de ModeRules (une fois ; lu par PvpCaps quand TeamMatch joue les Deux Voies).
static func ensure_rules() -> void:
	if not ModeRules.has_profile("moba"):
		ModeRules.register("moba", RULES)


## Règle de combat [param key] du profil « moba » (mode dev et modificateurs compris).
static func rule(key: String) -> Variant:
	ensure_rules()
	return ModeRules.rule(key, RULES.get(key), "moba")


# --- niveaux, XP, réapparition --------------------------------------------------------------------

## Niveau de fiche (30 à 85) d'un héros au niveau de partie [param lv] (1 à 12).
static func sheet_level(lv: int) -> int:
	return SHEET_BASE + SHEET_STEP * (clampi(lv, 1, LEVEL_MAX) - 1)


## XP pour passer du niveau [param lv] au suivant (0 au niveau maximal).
static func xp_to_next(lv: int) -> int:
	if lv >= LEVEL_MAX:
		return 0
	return XP_FIRST + XP_STEP * (maxi(lv, 1) - 1)


## XP totale pour atteindre le niveau [param lv] depuis le niveau 1.
static func xp_total(lv: int) -> int:
	var s := 0
	for l in range(1, clampi(lv, 1, LEVEL_MAX)):
		s += xp_to_next(l)
	return s


## Niveau atteint avec [param xp] points d'XP.
static func level_for_xp(xp: float) -> int:
	var lv := 1
	while lv < LEVEL_MAX and xp >= xp_total(lv + 1):
		lv += 1
	return lv


## XP donnée par l'élimination d'un héros de niveau [param lv].
static func hero_xp(lv: int) -> int:
	return int(XP_GAIN.hero_base) + int(XP_GAIN.hero_per_level) * lv


## Réapparition (s) d'un héros de niveau [param lv] à l'instant [param t].
static func respawn_time(lv: int, t: float) -> float:
	var s := RESPAWN_BASE + RESPAWN_PER_LEVEL * clampi(lv, 1, LEVEL_MAX)
	if t >= TIDE_AT:
		s *= 1.5
	elif t >= RESPAWN_UP_AT:
		s *= 1.25
	return s


## Niveau de partie attendu (fractionnaire) à l'instant [param t] (voir [constant EXPECTED_LEVEL]).
static func expected_level(t: float) -> float:
	var pts: Array = EXPECTED_LEVEL
	if t <= float(pts[0][0]):
		return float(pts[0][1])
	for i in range(1, pts.size()):
		if t <= float(pts[i][0]):
			var a: Array = pts[i - 1]
			var b: Array = pts[i]
			return lerpf(float(a[1]), float(b[1]), (t - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(pts[-1][1])


## Prime d'une élimination : base, premier sang, série de la victime (au-delà de 2), plafond.
static func kill_bounty(victim_streak: int, first_blood := false) -> int:
	var g := int(BOUNTY.kill) + (int(BOUNTY.first_blood) if first_blood else 0)
	g += maxi(0, victim_streak - int(BOUNTY.streak_from)) * int(BOUNTY.streak_step)
	return mini(g, int(BOUNTY.max))


# --- héros de référence (force des sbires, unité des structures) -----------------------------------

## Fiche moyenne des héros de [constant REF_CLASSES] au niveau de partie [param lv] (fractionnaire : interpolée) :
## {hp, def, auto (dégâts bruts d'une auto-attaque, avant défense)}. Calculée une fois par niveau (fiches hors scène).
static func ref_hero(lv: float) -> Dictionary:
	var lo := clampi(floori(lv), 1, LEVEL_MAX)
	var hi := clampi(lo + 1, 1, LEVEL_MAX)
	var a := _ref_at(lo)
	var b := _ref_at(hi)
	var u := clampf(lv - lo, 0.0, 1.0)
	return {"hp": lerpf(a.hp, b.hp, u), "def": lerpf(a.def, b.def, u), "auto": lerpf(a.auto, b.auto, u)}


## Précalcule les fiches de référence des 12 niveaux (écran de chargement : aucune fiche pendant la partie).
static func warm_ref() -> void:
	for lv in range(1, LEVEL_MAX + 1):
		_ref_at(lv)


static func _ref_at(lv: int) -> Dictionary:
	var sl := sheet_level(lv)
	if _ref.has(sl):
		return _ref[sl]
	var hp := 0.0
	var df := 0.0
	var auto := 0.0
	for cid in REF_CLASSES:
		var h := TeamMatch.hero_sheet(cid, sl)
		var step := WeaponAttacks.rival_step(String(GameData.class_data(cid).get("weapon_type", "katana")))
		hp += h.max_hp
		df += h.defense
		auto += h.power() * h.dmg_mult * float(step.get("mult", 1.0)) * PvpCaps.basic_mult()
		h.free()
	var n := float(REF_CLASSES.size())
	_ref[sl] = {"hp": hp / n, "def": df / n, "auto": auto / n}
	return _ref[sl]


## Unité de dégâts des structures à l'instant [param t] : l'auto-attaque d'un héros de référence au niveau attendu.
static func ref_auto(t: float) -> float:
	return maxf(1.0, float(ref_hero(expected_level(t)).auto))


## Force d'un sbire du genre [param kind] apparu à l'instant [param t], × [param mult] (essais : « un camp × 1,2 ») :
## {hp, atk (contre un héros, avant sa défense), vs_minion (dégâts sur un sbire), struct (unités sur une structure)}.
static func minion_stats(kind: String, t: float, mult := 1.0) -> Dictionary:
	var m: Dictionary = MINIONS[kind]
	var ref := ref_hero(expected_level(t))
	var melee_hp := float(MINIONS.melee.hits) * float(ref.auto)
	return {"hp": float(m.hits) * float(ref.auto) * mult,
		"atk": float(ref.hp) * float(m.hero) * (100.0 + maxf(float(ref.def), 0.0)) / 100.0 * mult,
		"vs_minion": melee_hp * float(m.minion) * mult, "struct": float(m.struct) * mult}


## Composition de la vague n° [param n] (1 = la première) à l'instant [param t] ; [param giants] géants en plus (T2
## adverse tombée, Marée).
static func wave(n: int, t: float, giants := 0) -> Array:
	var out: Array = WAVE.duplicate()
	var every := RAM_EVERY_LATE if t >= RAM_LATE_AT else RAM_EVERY
	if n > 0 and n % every == 0:
		out.append("ram")
	for _i in giants:
		out.append("giant")
	return out


## Instant d'apparition de la vague n° [param n].
static func wave_time(n: int) -> float:
	return FIRST_WAVE + WAVE_EVERY * (n - 1)


# --- kits -------------------------------------------------------------------------------------------

## Kit de partie de la classe [param cid] (data/moba_kits.json, généré par tools/moba_kits.py) :
## {slots: [{main, chains}] × 4 (la 4e = l'ultime), ult: {id, kind, cooldown, power}, family, has}.
static func kit(cid: String) -> Dictionary:
	if _kits.is_empty():
		var f := FileAccess.open(KITS_PATH, FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_kits = d
	return _kits.get(cid, {})


## Sorts de départ (niveau 1 : les sorts principaux des cases 1 à 3) au format de Run.skills.
static func start_skills(cid: String) -> Array:
	var out: Array = []
	for s in (kit(cid).get("slots", []) as Array).slice(0, 3):
		out.append({"id": int(s.main), "rank": 1})
	return out


## Poste conseillé d'une famille (indice dans [constant ROLES]).
static func role_for_family(fam: int) -> int:
	for i in ROLES.size():
		if fam in (ROLES[i].families as Array):
			return i
	return 2


# --- objets -----------------------------------------------------------------------------------------

static func item(id: String) -> Dictionary:
	if _items.is_empty():
		for it in ITEMS:
			_items[String(it.id)] = it
	return _items.get(id, {})


static func item_ids() -> Array:
	return ITEMS.map(func(it): return String(it.id))


## Coût de la recette seule (prix − composants) : ce qu'on paie quand on a déjà les composants.
static func recipe_cost(id: String) -> int:
	var it := item(id)
	var c := int(it.get("price", 0))
	for r in it.get("recipe", []):
		c -= int(item(String(r)).get("price", 0))
	return c


## Objets du type d'onglet [param tab] (« advised » : tous les objets finis).
static func tab_items(tab: String) -> Array:
	var types: Array = TAB_TYPES.get(tab, [])
	return ITEMS.filter(func(it): return (tab == "advised" and not String(it.type) in ["composant", "potion"]) or String(it.type) in types)


# --- contrôle (test_mb_data) --------------------------------------------------------------------------

## Problèmes des tables (liste vide : tout est cohérent) : objets, recettes, textes, kits, postes, sbires, objectifs.
static func validate() -> Array:
	var bad: Array = []
	var ids := {}
	for it in ITEMS:
		var id := String(it.id)
		if ids.has(id):
			bad.append("objet en double : " + id)
		ids[id] = true
		if "%" in String(it.text) or "%" in String(it.name):
			bad.append("pourcentage dans le texte de " + id)
		if int(it.price) <= 0:
			bad.append("prix nul : " + id)
		for r in it.recipe:
			if item(String(r)).is_empty():
				bad.append("composant inconnu %s dans %s" % [r, id])
			elif String(item(String(r)).type) == "potion":
				bad.append("potion en composant : " + id)
		if not (it.recipe as Array).is_empty() and recipe_cost(id) <= 0:
			bad.append("recette gratuite : " + id)
		if it.has("potion") and not Potions.KINDS.has(String(it.potion)):
			bad.append("potion inconnue : " + id)
	for fam in BUILDS:
		for b in BUILDS[fam]:
			for id in b:
				if item(String(id)).is_empty():
					bad.append("parcours %d : objet inconnu %s" % [fam, id])
	for cid in GameData.classes:
		var k := kit(String(cid))
		if k.is_empty() or (k.get("slots", []) as Array).size() != 4:
			bad.append("kit absent ou incomplet : " + String(cid))
			continue
		var own := {}
		for s in GameData.class_data(String(cid)).get("skills", []):
			own[int(s.id)] = s
		var seen := {}
		for s in k.slots:
			for id in [int(s.main)] + Array(s.chains).map(func(x): return int(x)):
				if not own.has(id):
					bad.append("%s : sort %d hors de la classe" % [cid, id])
				if seen.has(id):
					bad.append("%s : sort %d en double" % [cid, id])
				seen[id] = true
		if int(k.ult.id) != int(k.slots[3].main):
			bad.append("%s : l'ultime n'est pas en case 4" % cid)
		if float(k.ult.cooldown) < 60.0 or float(k.ult.cooldown) > 90.0:
			bad.append("%s : recharge de l'ultime hors de 60-90 s" % cid)
	for r in ROLES:
		if int(r.lane) < -1 or int(r.lane) > 1:
			bad.append("poste mal placé : " + String(r.id))
	for kind in MINIONS:
		for mid in MINIONS[kind].ids:
			if GameData.monster(int(mid)).is_empty():
				bad.append("sbire %s : monstre %d inconnu" % [kind, mid])
	return bad
