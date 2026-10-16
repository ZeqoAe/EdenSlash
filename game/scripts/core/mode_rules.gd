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
	"sudden_after": PvpCaps.SUDDEN_AFTER, "hit_cap": 0.15, "burst_cap": 0.35, "burst_window": 2.0, "burst_excess": 0.25,
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
	"sudden_after": PvpCaps.SUDDEN_AFTER, "hit_cap": 0.15, "burst_cap": 0.35, "burst_window": 2.0, "burst_excess": 0.25,
	"caps": PvpCaps.CAPS,
}

## Profils par nom. La Tour et l'entraînement n'ont pas de règles de duel propres (celles de
## « duel_b » s'appliquent quand Duel.active).
## Arènes à alliés IA : mêmes règles que l'à l'arme, échelle réduite (plus de héros qui frappent) et
## soins moitié moins forts. Le Gantelet (1 contre 2 ou 3) se joue équipé.
## Passe M7 (alliés à la fiche d'un héros, ciblage du plus faible) : manches mesurées 85 s en 2v2 et 104 s en 3v3 (cible
## 30-90 s) : échelle 0,022 -> 0,026 et 0,018 -> 0,024, acharnement dès 25 s et 20 s (une mêlée à six se met en place plus tard,
## et les soins des deux camps l'étirent).
const PVP_A2 := {
	"dmg_scale": 0.026, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": PvpCaps.HEAL_MULT * 0.5,
	"max_mitigation": PvpCaps.MAX_MITIGATION, "pressure_start": 25.0,
	"pressure_step": PvpCaps.PRESSURE_STEP, "pct_weight": 1.0,
	"sudden_after": PvpCaps.SUDDEN_AFTER, "hit_cap": 0.15, "burst_cap": 0.35, "burst_window": 2.0, "burst_excess": 0.25,
	"caps": PvpCaps.CAPS,
}
const PVP_A3 := {
	"dmg_scale": 0.024, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": PvpCaps.HEAL_MULT * 0.5,
	"max_mitigation": PvpCaps.MAX_MITIGATION, "pressure_start": 20.0,
	"pressure_step": PvpCaps.PRESSURE_STEP, "pct_weight": 1.0,
	"sudden_after": PvpCaps.SUDDEN_AFTER, "hit_cap": 0.15, "burst_cap": 0.35, "burst_window": 2.0, "burst_excess": 0.25,
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
## d'acharnement (l'anneau fait pression), soins presque entiers (les potions comptent). Passe M1 : échelle 0,05 -> 0,04
## (parties de 4 à 6 min mesurées ; un combat plus long laisse le temps de fuir ou d'arriver en troisième).
## Lot BR1 (retour du joueur : « deux niveau 9, 2 000 PV, coups de 10 à 50 : interminable ») : échelle 0,04 -> 0,055 et
## plafonds du duel équipé (critiques ×2 au plus, dégâts +100 %) : l'équipement raccourcissait surtout les combats par
## les critiques. Duel entre deux scriptés de même niveau (tools/royale_duel_probe, 8 paires, Hardcore), médiane aux
## niveaux 9 / 20 / 40 : nus 41 / 39 / 37 s -> 28 / 26 / 24 s ; toutes les cases (niveaux 1 à 40, nus à légendaires +10)
## 17-41 s -> 17-31 s.
const ROYALE := {
	"dmg_scale": 0.055, "basic_mult": PvpCaps.BASIC_MULT, "heal_mult": 0.8,
	"max_mitigation": PvpCaps.MAX_MITIGATION, "pressure_start": 100000.0,
	"pressure_step": PvpCaps.PRESSURE_STEP, "pct_weight": 0.75,
	"hit_cap": 0.18, "burst_cap": 0.4, "burst_window": 2.0, "burst_excess": 0.3,
	"caps": PVP["caps"],
}
## Survivant (conception/survivor/SPEC.md, corrigé par DECISIONS_JOUEUR.md) : valeurs de départ, recalées par mesure
## au lot S7. Pas de règle de duel ici (aucun combat entre héros) : ce profil sert aux familles « cartes », « héros »,
## « monstres » et « boss » du mode. Aucune clé de gains de progression (le mode n'en donne pas).
const SURVIVOR := {
	# cartes (§2.2) : poids des familles, pitié, relances, bannissements, « Passer »
	"w_piece_new": 1.0, "w_piece_up": 0.8, "w_weapon_up": 2.5, "w_spell_new": 3.0, "w_spell_up": 1.1, "w_evolution": 4.0,
	# au-delà de spell_up_norm sorts (12 au plus, lot S9), les améliorations de sort se partagent le poids de spell_up_norm sorts
	"spell_up_norm": 6.0,
	"pity_after": 6, "luck_per_min": 0.02, "base_rerolls": 2, "bans": 3, "skip_gold_base": 15, "skip_gold_per_level": 3,
	# pièces (DECISIONS §1) : qualité 100 à 120 %, jet parfait = 120 %
	"quality_min": 1.0, "perfect_quality": 1.2,
	# mélange des propositions de pièces (lot S2, SurvivorPool.weight) : type d'armure de la classe ×armor_pref, set dont le
	# héros porte déjà set_damp_from pièces ×set_damp (4e et 5e pièces rares : 5/5 ≈ 1 run sur 25 pour un joueur qui le
	# cherche, mesuré avec le vrai tirage des cartes, tools/sv_cards_sim, lot S3 ; S7 : 0,14 → 0,17 avec les montées de niveau et
	# coffres mesurés au pilote, 39 et 12 : 1 run sur 23) ; puissance d'un passif de pièce (1 = une
	# carte commune)
	"armor_pref": 2.0, "set_damp": 0.17, "set_damp_from": 3, "passive_power": 1.0,
	# héros, monstres, gardiens, boss, butin, garde-fous : valeurs mesurées au lot S7, documentées en tête de core/survivor.gd
	"xp_start": Survivor.XP_START, "xp_end": Survivor.XP_END, "xp_until": Survivor.XP_UNTIL, "xp_late": Survivor.XP_LATE,
	"xp_late_at": Survivor.XP_LATE_AT, "resurrections": 1, "opening": Survivor.OPENING, "hard_waves_from": Survivor.HARD_WAVES_FROM,
	"camps_from": Survivor.CAMPS_FROM,
	"level_per_min": Survivor.LEVEL_PER_MIN, "hp0": Survivor.HP0, "hp_growth": Survivor.HP_GROWTH, "atk0": Survivor.ATK0,
	"atk_growth": Survivor.ATK_GROWTH, "alive_start": Survivor.ALIVE[0], "alive_end": Survivor.ALIVE[1],
	"pack_every": Survivor.PACK_EVERY, "pack_size": Survivor.PACK_SIZE, "pack_split": Survivor.PACK_SPLIT,
	"wave_every": Survivor.WAVE_EVERY, "spawn_pace": Survivor.SPAWN_PACE, "elites_from": Survivor.ELITES_FROM,
	"elite_every": Survivor.ELITE_EVERY, "power_band": Survivor.POWER_BAND, "power_hp": Survivor.POWER_HP,
	"power_atk": Survivor.POWER_ATK, "guardian_hp": Survivor.GUARDIAN_HP, "boss_hp": Survivor.BOSS_HP,
	"boss_rage_at": Survivor.BOSS_RAGE_AT, "boss_atk": Survivor.BOSS_ATK, "potion_drop": Survivor.POTION_DROP, "crit_cap": Survivor.CRIT_CAP,
	"crit_overflow": Survivor.CRIT_OVERFLOW, "crit_dmg_cap": Survivor.CRIT_DMG_CAP,
	"speed_cap": Survivor.SPEED_CAP, "passive_cap_mult": Survivor.PASSIVE_CAP_MULT, "pity_dry": Survivor.PITY_DRY,
	# paliers I à V (§8.5, lot S8) : PV et dégâts des monstres, gardiens et boss × ; les autres règles de chaque palier
	# (vitesse, soins, Menace, mécaniques du boss, gardiens, rage) sont dans Survivor.PALIERS ; mesures dans R_S8
	"palier_mult": [1.0, 1.45, 1.7, 1.75, 2.1],
}
## L'Échiquier (autochess, lot AC-E) : les unités se battent par la couche d'effets AutochessEffects (pas par PvpCaps).
## dmg_scale = part des PV d'une unité de même coût retirée par une auto-attaque avant défense (même sens que l'échelle du
## duel ; R_AC2 §4 : 0,20 avec le prototype en règles de duel) ; AutochessDirector.base_sheet l'applique à l'attaque et aux
## sorts. Valeur mesurée par test_ac_fight (R_AC_E : 0,10), puis 0,12 au banc de l'IA d'AC-U (miroirs : 28,6 s, 0,4 %
## d'égalités ; 0,10 : 32 s, 3-6 %, R_AC_U). Plafond d'un coup,
## Fureur (mort subite) et égalité : ceux d'AutochessData (la couche d'effets les lit là), recopiés ici pour la lecture.
const AUTOCHESS := {
	"dmg_scale": 0.12, "hit_cap": AutochessData.HIT_CAP, "sudden_after": AutochessData.SUDDEN_AT,
	"fury_step": AutochessData.FURY_STEP, "fury_damage": AutochessData.FURY_DAMAGE, "fury_heal_mult": AutochessData.FURY_HEAL_MULT,
	"draw_at": AutochessData.DRAW_AT, "unit_diff": AutochessData.UNIT_DIFF,
}
const PROFILES := {
	"survivor": SURVIVOR,
	"autochess": AUTOCHESS,
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
