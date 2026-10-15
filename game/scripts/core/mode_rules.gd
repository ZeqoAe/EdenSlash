class_name ModeRules
extends RefCounted
## Règles chiffrées de chaque mode, à un seul endroit (conception, lot 4). Un profil par mode ;
## `rule("clé")` lit le profil du mode en cours (Modes.current()), avec dans l'ordre : la valeur du
## mode dev (data/dev_edits.json -> "modes"), puis les modificateurs actifs, puis la valeur du
## profil. Les valeurs de départ sont les chiffres actuels du jeu : rien ne change en jeu.
##
## Famille « héros contre héros » (PvpCaps) : dmg_scale, basic_mult, heal_mult, max_mitigation,
## pressure_start, pressure_step, caps. D'autres familles (monstres, héros, gains) rejoindront les
## profils quand leur consommateur sera branché (Survie, Donjon, Panthéon…).

## Duel équipé (mode B) : tout compte ; plafonds de dégâts +100 % et critiques ×2, bonus en % ramenés
## de moitié (pct_weight 0,5 sur dmg_mult, dot_bonus, heal_power). « duel » est son ancien nom.
## Pas de mort en un coup : au plus hit_cap des PV max par coup, et burst_cap sur burst_window s ; au-delà
## le reste du coup compte burst_excess.
const PVP := {
	"dmg_scale": PvpCaps.DAMAGE_SCALE, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": PvpCaps.HEAL_MULT,
	"max_mitigation": PvpCaps.MAX_MITIGATION, "pressure_start": PvpCaps.PRESSURE_START,
	"pressure_step": PvpCaps.PRESSURE_STEP, "pct_weight": 0.5,
	"hit_cap": 0.15, "burst_cap": 0.35, "burst_window": 2.0, "burst_excess": 0.25,
	"caps": {
		"atk_speed": 2.0, "cast_speed": 3.0, "crit": 0.5, "mcrit": 0.5, "crit_dmg": 1.0, "move_mult": 2.0,
		"lifesteal": 0.2, "heal_power": 1.5, "cdr": 0.3, "dmg_mult": 2.0, "dot_bonus": 3.0, "area_mult": 2.0, "reach_mult": 2.0,
	},
}

## Duel à l'arme (mode A) : aucune pièce ni bonus de méta, niveau choisi ; l'échelle des dégâts
## compense l'équipement absent (manches de 45 à 90 s à tout niveau). Plafonds de stats : ceux de
## base (rien à plafonner sans équipement).
const PVP_A := {
	"dmg_scale": 0.030, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": PvpCaps.HEAL_MULT,
	"max_mitigation": PvpCaps.MAX_MITIGATION, "pressure_start": PvpCaps.PRESSURE_START,
	"pressure_step": PvpCaps.PRESSURE_STEP, "pct_weight": 1.0,
	"hit_cap": 0.15, "burst_cap": 0.35, "burst_window": 2.0, "burst_excess": 0.25,
	"caps": PvpCaps.CAPS,
}

## Profils par nom. La Tour et l'entraînement n'ont pas de règles de duel propres (celles de
## « duel_b » s'appliquent quand Duel.active).
## Arènes à alliés IA : mêmes règles que l'à l'arme, échelle réduite (plus de héros qui frappent) et
## soins moitié moins forts. Le Gantelet (1 contre 2 ou 3) se joue équipé.
const PVP_A2 := {
	"dmg_scale": 0.022, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": PvpCaps.HEAL_MULT * 0.5,
	"max_mitigation": PvpCaps.MAX_MITIGATION, "pressure_start": PvpCaps.PRESSURE_START,
	"pressure_step": PvpCaps.PRESSURE_STEP, "pct_weight": 1.0,
	"hit_cap": 0.15, "burst_cap": 0.35, "burst_window": 2.0, "burst_excess": 0.25,
	"caps": PvpCaps.CAPS,
}
const PVP_A3 := {
	"dmg_scale": 0.018, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": PvpCaps.HEAL_MULT * 0.5,
	"max_mitigation": PvpCaps.MAX_MITIGATION, "pressure_start": PvpCaps.PRESSURE_START,
	"pressure_step": PvpCaps.PRESSURE_STEP, "pct_weight": 1.0,
	"hit_cap": 0.15, "burst_cap": 0.35, "burst_window": 2.0, "burst_excess": 0.25,
	"caps": PvpCaps.CAPS,
}
## Le Siège, chacun pour soi à trois (après le boss) : mêmes règles que l'arène à trois, héros équipés (plafonds de
## l'équipé, bonus en % ramenés de moitié), soins moitié moins forts.
const PVP_SIEGE := {
	"dmg_scale": 0.018, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": PvpCaps.HEAL_MULT * 0.5,
	"max_mitigation": PvpCaps.MAX_MITIGATION, "pressure_start": PvpCaps.PRESSURE_START,
	"pressure_step": PvpCaps.PRESSURE_STEP, "pct_weight": 0.5,
	"hit_cap": 0.15, "burst_cap": 0.35, "burst_window": 2.0, "burst_excess": 0.25,
	"caps": PVP["caps"],
}
## Battle royale : héros nus qui montent de niveau en pillant ; huit héros qui se frappent (échelle réduite), pas
## d'acharnement (l'anneau fait pression), soins presque entiers (les potions comptent).
const ROYALE := {
	"dmg_scale": 0.05, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": 0.8,
	"max_mitigation": PvpCaps.MAX_MITIGATION, "pressure_start": 100000.0,
	"pressure_step": PvpCaps.PRESSURE_STEP, "pct_weight": 0.75,
	"hit_cap": 0.18, "burst_cap": 0.4, "burst_window": 2.0, "burst_excess": 0.3,
	"caps": PvpCaps.CAPS,
}
## Survivant (conception/survivor/SPEC.md, corrigé par DECISIONS_JOUEUR.md) : valeurs de départ, recalées par mesure
## au lot S7. Pas de règle de duel ici (aucun combat entre héros) : ce profil sert aux familles « cartes », « héros »,
## « monstres » et « boss » du mode. Aucune clé de gains de progression (le mode n'en donne pas).
const SURVIVOR := {
	# cartes (§2.2) : poids des familles, pitié, relances, bannissements, « Passer »
	"w_piece_new": 1.0, "w_piece_up": 0.8, "w_weapon_up": 2.5, "w_spell_new": 3.0, "w_spell_up": 1.1, "w_evolution": 4.0,
	"pity_after": 6, "luck_per_min": 0.02, "base_rerolls": 2, "bans": 3, "skip_gold_base": 15, "skip_gold_per_level": 3,
	# pièces (DECISIONS §1) : qualité 100 à 120 %, jet parfait = 120 %
	"quality_min": 1.0, "perfect_quality": 1.2,
	# mélange des propositions de pièces (lot S2, SurvivorPool.weight) : type d'armure de la classe ×armor_pref, set dont le
	# héros porte déjà set_damp_from pièces ×set_damp (4e et 5e pièces rares : 5/5 ≈ 1 run sur 25, tools/sv_set_sim) ;
	# puissance d'un passif de pièce (1 = une carte commune)
	"armor_pref": 2.0, "set_damp": 0.3, "set_damp_from": 3, "passive_power": 1.0,
	# héros (§8.1) : expérience ×2 au niveau 1, ×1,15 à partir du niveau 10 ; une résurrection
	"xp_start": 2.0, "xp_end": 1.15, "xp_until": 10, "resurrections": 1,
	# monstres (§8.2) : PV hp0 × hp_growth^minutes, dégâts atk0 × atk_growth^minutes, vivants au plus
	"hp0": 0.5, "hp_growth": 1.12, "atk0": 0.5, "atk_growth": 1.07, "alive_start": 18, "alive_end": 110,
	# gardiens (5 / 10 / 15 min) et boss final (§8.2-8.3) : PV fixes, rage du boss après boss_rage_at s
	"guardian_hp": [40000.0, 150000.0, 450000.0], "boss_hp": 1500000.0, "boss_rage_at": 240.0,
	# paliers I à V (§8.5, lot S8) : monstres, gardiens et boss ×
	"palier_mult": [1.0, 1.5, 2.2, 3.2, 4.5],
}
const PROFILES := {
	"survivor": SURVIVOR,
	"royale": ROYALE,
	"siege": PVP_SIEGE,
	"duel": PVP,
	"duel_a": PVP_A,
	"duel_b": PVP,
	"arena2": PVP_A2,
	"arena3": PVP_A3,
	"gauntlet": PVP,
}

## Profil imposé (arène d'IA : --rules=duel_a), prioritaire sur le mode en cours.
static var forced := ""
## Modificateurs actifs (ids de Modifiers.LIST).
static var modifiers: Array = []


static func profile_name() -> String:
	if forced != "":
		return forced
	if Siege.ffa:
		return "siege"
	var m := Modes.current()
	if m == "duel":
		if Duel.mode in ["arena2", "arena3", "gauntlet"]:
			return Duel.mode
		return "duel_a" if Duel.bare else "duel_b"
	return m if PROFILES.has(m) else ""


## Valeur de la règle [param key] pour le profil [param profile] (défaut : celui du mode en cours) ;
## [param fallback] si le mode n'a pas de profil ou pas cette clé.
static func rule(key: String, fallback: Variant = null, profile := "") -> Variant:
	var p := profile if profile != "" else profile_name()
	if p == "":
		p = "duel"  # hors mode : les chiffres du duel (fiches, comparaisons)
	var base: Variant = PROFILES.get(p, {}).get(key, fallback)
	var edits: Dictionary = DevEdits.data.get("modes", {}).get(p, {})
	if edits.has(key):
		base = edits[key]
	return Modifiers.apply(key, base, modifiers)


static func num(key: String, fallback := 0.0, profile := "") -> float:
	return float(rule(key, fallback, profile))
