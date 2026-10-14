class_name Trophies
extends RefCounted
## Trophées : un effet sous condition, sans stats fixes. Depuis 0.1.130 ils ne sont plus de
## l'équipement : c'est une collection de la run (Run.trophies, jusqu'à Run.MAX_TROPHIES, tous
## d'effets différents), trouvée dans les coffres de trophée et les sanctuaires. Chaque trophée
## d'Eden a une famille (« trophy » dans data/eden_catalog.json, écrite par
## tools/rework_trophies.py d'après son texte d'Eden) ; sa rareté et son niveau règlent la force
## de l'effet (chance, valeurs). Les objets marqués « nopool » (familiers, tests, bonus de sorts
## d'autres classes) restent dans l'archive mais ne tombent jamais.

## Ancien trophée de départ (Eden : Departure Crystal) : plus donné depuis 0.1.130.
const STARTER_ID := 35199
const STARTER_RARITY := 1
## Force selon le niveau du trophée d'Eden : × (LEVEL_MIN … LEVEL_MIN + LEVEL_SPAN au niveau 90).
const LEVEL_MIN := 0.75
const LEVEL_SPAN := 0.5
## Force du buff selon la rareté (commun … légendaire) : chance × et valeurs ×.
const CHANCE_MULT := [0.7, 0.8, 0.9, 1.0, 1.1, 1.25]
const VALUE_MULT := [0.5, 0.6, 0.75, 0.9, 1.0, 1.2]
## Familles : nom, déclencheur, chance, recharge, effet et paramètres.
## stat_buff : bonus de stats temporaire (« stats » : clés de Player.recalc_stats).
const KINDS := {
	"agi": {"name": "Vivacité", "trigger": "hit", "chance": 0.075, "cd": 5.0, "effect": "stat_buff", "status": "t_agi", "stats": {"agi_pct": 0.3}, "duration": 8.0},
	"agi_int": {"name": "Esprit vif", "trigger": "hit", "chance": 0.075, "cd": 5.0, "effect": "stat_buff", "status": "t_mind", "stats": {"agi_pct": 0.2, "int_pct": 0.2}, "duration": 8.0},
	"str": {"name": "Rage du guerrier", "trigger": "hit", "chance": 0.075, "cd": 5.0, "effect": "stat_buff", "status": "t_str", "stats": {"str_pct": 0.3}, "duration": 8.0},
	"int_wis": {"name": "Arcanes", "trigger": "hit", "chance": 0.075, "cd": 5.0, "effect": "stat_buff", "status": "t_arcane", "stats": {"int_pct": 0.25, "wis_pct": 0.25}, "duration": 8.0},
	"all": {"name": "Éveil", "trigger": "hit", "chance": 0.075, "cd": 5.0, "effect": "stat_buff", "status": "t_all", "stats": {"str_pct": 0.12, "agi_pct": 0.12, "int_pct": 0.12, "wis_pct": 0.12, "lck_pct": 0.12}, "duration": 10.0},
	"luck": {"name": "Bonne étoile", "trigger": "kill", "chance": 0.2, "effect": "stat_buff", "status": "t_luck", "stats": {"lck_pct": 0.4}, "duration": 10.0},
	"crit": {"name": "Instinct du prédateur", "trigger": "hit", "chance": 0.075, "cd": 5.0, "effect": "stat_buff", "status": "t_crit", "stats": {"crit": 0.15, "mcrit": 0.15, "crit_dmg": 0.3}, "duration": 8.0},
	"speed": {"name": "Frénésie", "trigger": "crit", "chance": 0.25, "cd": 4.0, "effect": "stat_buff", "status": "t_speed", "stats": {"atk_speed": 0.25, "cast_speed": 0.15}, "duration": 6.0},
	"might": {"name": "Puissance", "trigger": "basic_hit", "chance": 0.1, "cd": 4.0, "effect": "stat_buff", "status": "t_power", "stats": {"dmg_pct": 0.2}, "duration": 6.0},
	"guard": {"name": "Carapace", "trigger": "hurt", "chance": 0.2, "cd": 12.0, "effect": "stat_buff", "status": "t_guard", "stats": {"def_pct": 0.6}, "duration": 6.0},
	"evade": {"name": "Pas de l'ombre", "trigger": "dodge", "chance": 1.0, "cd": 6.0, "effect": "stat_buff", "status": "t_evade", "stats": {"eva": 0.15, "move_speed": 0.2}, "duration": 4.0},
	"regen": {"name": "Sève vivante", "trigger": "kill", "chance": 0.15, "cd": 2.0, "effect": "heal", "amount": 0.05},
	"resolve": {"name": "Volonté", "trigger": "hurt", "chance": 0.15, "cd": 15.0, "effect": "buff", "status": "resolve", "duration": 4.0},
	"double": {"name": "Double frappe", "trigger": "hit", "chance": 0.09, "cd": 1.0, "effect": "double_hit", "mult": 0.8},
	"storm": {"name": "Orage", "trigger": "hit", "chance": 0.05, "cd": 1.0, "effect": "lightning", "mult": 0.9, "chain": 3, "radius": 6.0},
	"fire": {"name": "Braise", "trigger": "hit", "chance": 0.05, "cd": 1.0, "effect": "burn", "radius": 3.0, "duration": 4.0},
	"frost": {"name": "Givre", "trigger": "hit", "chance": 0.04, "cd": 2.0, "effect": "freeze", "radius": 3.0, "duration": 1.5},
	"venom": {"name": "Venin", "trigger": "hit", "chance": 0.05, "cd": 1.0, "effect": "explosion", "mult": 0.7, "radius": 3.0, "applies": {"poison": 4.0}, "color": Color(0.55, 0.9, 0.3, 0.9)},
	"stun": {"name": "Choc", "trigger": "hit", "chance": 0.03, "cd": 3.0, "effect": "stun", "radius": 1.5, "duration": 1.5},
	# --- trophées de build (0.1.37) : esquive, critique, élimination, tank, sorts, auto-attaque ---
	"dodge_wave": {"name": "Onde d'esquive", "trigger": "dodge", "chance": 1.0, "cd": 3.0, "effect": "explosion", "mult": 1.2, "radius": 4.0, "color": Color(0.7, 1.0, 0.9, 0.9)},
	"dodge_crit": {"name": "Riposte", "trigger": "dodge", "chance": 1.0, "cd": 5.0, "effect": "stat_buff", "status": "t_riposte", "stats": {"crit": 0.4, "crit_dmg": 0.4}, "duration": 3.0},
	"wind_dance": {"name": "Danse du vent", "trigger": "dodge", "chance": 1.0, "cd": 6.0, "effect": "stat_buff", "status": "t_wind", "stats": {"agi_pct": 0.25, "atk_speed": 0.15}, "duration": 5.0},
	"shadow_blades": {"name": "Lames d'ombre", "trigger": "dodge", "chance": 1.0, "cd": 4.0, "effect": "explosion", "mult": 0.8, "radius": 3.0, "applies": {"bleed": 4.0}, "color": Color(0.6, 0.4, 0.9, 0.9)},
	"perfect_nova": {"name": "Miroir de givre", "trigger": "perfect", "chance": 1.0, "cd": 2.0, "effect": "nova", "radius": 5.0, "duration": 1.5},
	"crit_chain": {"name": "Arc électrique", "trigger": "crit", "chance": 0.3, "cd": 1.5, "effect": "lightning", "mult": 0.8, "chain": 4, "radius": 7.0},
	"crit_heal": {"name": "Sang vif", "trigger": "crit", "chance": 0.3, "cd": 2.0, "effect": "heal", "amount": 0.02},
	"quake": {"name": "Séisme", "trigger": "basic_hit", "chance": 0.2, "cd": 3.0, "effect": "explosion", "mult": 1.0, "radius": 4.5, "color": Color(0.95, 0.75, 0.4, 0.9)},
	"berserk": {"name": "Fureur du désespoir", "trigger": "low_hp", "chance": 1.0, "cd": 30.0, "effect": "stat_buff", "status": "t_berserk", "stats": {"dmg_pct": 0.4, "atk_speed": 0.3}, "duration": 8.0},
	"arcane_echo": {"name": "Écho arcanique", "trigger": "skill_hit", "chance": 0.2, "cd": 2.0, "effect": "echo", "mult": 0.5},
	"mana_surge": {"name": "Afflux", "trigger": "skill_hit", "chance": 0.25, "cd": 3.0, "effect": "cdr", "amount": 0.5},
	"thorns": {"name": "Épines", "trigger": "hurt", "chance": 0.25, "cd": 10.0, "effect": "buff", "status": "thorns", "duration": 6.0},
	"last_stand": {"name": "Dernier rempart", "trigger": "low_hp", "chance": 1.0, "cd": 45.0, "effect": "heal", "amount": 0.25, "then": [{"effect": "buff", "status": "barrier", "duration": 4.0}]},
	"vampire": {"name": "Soif de sang", "trigger": "kill", "chance": 0.2, "cd": 6.0, "effect": "stat_buff", "status": "t_vamp", "stats": {"lifesteal": 0.06}, "duration": 6.0},
	"soul_burst": {"name": "Âmes explosives", "trigger": "kill", "chance": 0.25, "cd": 0.5, "effect": "explosion", "mult": 1.0, "radius": 3.5},
	"momentum": {"name": "Élan", "trigger": "kill", "chance": 0.3, "cd": 1.0, "effect": "cdr", "amount": 0.3},
	"harvest": {"name": "Moisson", "trigger": "kill", "chance": 0.2, "cd": 4.0, "effect": "stat_buff", "status": "t_harvest", "stats": {"move_speed": 0.25, "dmg_pct": 0.1}, "duration": 5.0},
	# --- trophées de collection (0.1.130) : 12 par run, tous d'effets différents ---
	# éléments à l'impact
	"chill_touch": {"name": "Toucher glacial", "trigger": "hit", "chance": 0.08, "cd": 1.0, "effect": "chill", "radius": 3.0, "duration": 3.0},
	"shock_strike": {"name": "Électrocution", "trigger": "hit", "chance": 0.06, "cd": 1.5, "effect": "shock", "radius": 3.0, "duration": 4.0},
	"hit_def": {"name": "Bastion", "trigger": "hit", "chance": 0.06, "cd": 6.0, "effect": "stat_buff", "status": "t_bastion", "stats": {"def_pct": 0.35}, "duration": 6.0},
	# sorts
	"ember_skill": {"name": "Sorts ardents", "trigger": "skill_hit", "chance": 0.35, "cd": 1.5, "effect": "burn", "radius": 3.5, "duration": 4.0},
	"frost_skill": {"name": "Sorts gelés", "trigger": "skill_hit", "chance": 0.25, "cd": 4.0, "effect": "freeze", "radius": 3.0, "duration": 1.2},
	"storm_skill": {"name": "Sorts orageux", "trigger": "skill_hit", "chance": 0.3, "cd": 2.0, "effect": "lightning", "mult": 0.8, "chain": 4, "radius": 7.0},
	"skill_power": {"name": "Maîtrise", "trigger": "skill_hit", "chance": 0.2, "cd": 6.0, "effect": "stat_buff", "status": "t_mastery", "stats": {"dmg_pct": 0.15, "cast_speed": 0.1}, "duration": 6.0},
	"skill_heal": {"name": "Sorts vitaux", "trigger": "skill_hit", "chance": 0.2, "cd": 3.0, "effect": "heal", "amount": 0.025},
	# auto-attaque de l'arme
	"basic_storm": {"name": "Lame foudroyante", "trigger": "basic_hit", "chance": 0.12, "cd": 1.0, "effect": "lightning", "mult": 0.7, "chain": 3, "radius": 6.0},
	"basic_burn": {"name": "Lame ardente", "trigger": "basic_hit", "chance": 0.15, "cd": 1.0, "effect": "burn", "radius": 2.5, "duration": 4.0},
	"basic_bleed": {"name": "Lame dentelée", "trigger": "basic_hit", "chance": 0.2, "cd": 0.8, "effect": "explosion", "mult": 0.3, "radius": 2.0, "applies": {"bleed": 4.0}, "color": Color(0.9, 0.25, 0.25, 0.9)},
	"basic_haste": {"name": "Rythme", "trigger": "basic_hit", "chance": 0.08, "cd": 8.0, "effect": "stat_buff", "status": "t_rhythm", "stats": {"atk_speed": 0.3}, "duration": 6.0},
	# critiques
	"crit_burst": {"name": "Éclat critique", "trigger": "crit", "chance": 0.25, "cd": 1.0, "effect": "explosion", "mult": 0.8, "radius": 3.0, "color": Color(1.0, 0.9, 0.5, 0.9)},
	"crit_frost": {"name": "Morsure du froid", "trigger": "crit", "chance": 0.2, "cd": 1.5, "effect": "chill", "radius": 3.5, "duration": 3.0},
	"crit_cdr": {"name": "Concentration", "trigger": "crit", "chance": 0.15, "cd": 3.0, "effect": "cdr", "amount": 0.3},
	"luck_crit": {"name": "Fortune", "trigger": "crit", "chance": 0.15, "cd": 6.0, "effect": "stat_buff", "status": "t_fortune", "stats": {"lck_pct": 0.3, "crit_dmg": 0.15}, "duration": 8.0},
	# éliminations
	"kill_frost": {"name": "Tombe glacée", "trigger": "kill", "chance": 0.25, "cd": 3.0, "effect": "nova", "radius": 4.0, "duration": 1.2},
	"kill_storm": {"name": "Décharge", "trigger": "kill", "chance": 0.25, "cd": 1.0, "effect": "lightning", "mult": 0.8, "chain": 3, "radius": 7.0},
	"kill_shield": {"name": "Trophée de chasse", "trigger": "kill", "chance": 0.1, "cd": 10.0, "effect": "buff", "status": "barrier", "duration": 3.0},
	"kill_crit": {"name": "Prédateur", "trigger": "kill", "chance": 0.2, "cd": 6.0, "effect": "stat_buff", "status": "t_predator", "stats": {"crit": 0.2, "mcrit": 0.2, "crit_dmg": 0.2}, "duration": 6.0},
	# esquive et annulation parfaite
	"dodge_heal": {"name": "Souffle", "trigger": "dodge", "chance": 1.0, "cd": 5.0, "effect": "heal", "amount": 0.04},
	"dodge_cdr": {"name": "Pas vif", "trigger": "dodge", "chance": 1.0, "cd": 5.0, "effect": "cdr", "amount": 0.25},
	"dodge_frost": {"name": "Sillage glacé", "trigger": "dodge", "chance": 1.0, "cd": 6.0, "effect": "nova", "radius": 3.5, "duration": 1.0},
	"perfect_storm": {"name": "Contre foudroyant", "trigger": "perfect", "chance": 1.0, "cd": 2.0, "effect": "lightning", "mult": 1.2, "chain": 5, "radius": 7.0},
	"perfect_power": {"name": "Contre parfait", "trigger": "perfect", "chance": 1.0, "cd": 4.0, "effect": "stat_buff", "status": "t_parry", "stats": {"dmg_pct": 0.3}, "duration": 4.0},
	# dégâts subis et PV bas
	"hurt_frost": {"name": "Cœur de glace", "trigger": "hurt", "chance": 0.2, "cd": 10.0, "effect": "nova", "radius": 4.0, "duration": 1.5},
	"hurt_storm": {"name": "Représailles", "trigger": "hurt", "chance": 0.3, "cd": 4.0, "effect": "lightning", "mult": 1.0, "chain": 3, "radius": 7.0},
	"hurt_heal": {"name": "Seconde peau", "trigger": "hurt", "chance": 0.15, "cd": 8.0, "effect": "heal", "amount": 0.04},
	"hurt_haste": {"name": "Repli", "trigger": "hurt", "chance": 0.2, "cd": 10.0, "effect": "buff", "status": "haste", "duration": 3.0},
	"low_frost": {"name": "Dernier hiver", "trigger": "low_hp", "chance": 1.0, "cd": 40.0, "effect": "nova", "radius": 6.0, "duration": 2.5},
	"low_speed": {"name": "Instinct de survie", "trigger": "low_hp", "chance": 1.0, "cd": 40.0, "effect": "stat_buff", "status": "t_survive", "stats": {"move_speed": 0.4, "eva": 0.25}, "duration": 6.0},
}
## Statuts des buffs de trophée : nom, couleur, icône reprise d'un buff proche.
const STATUSES := {
	"t_agi": {"name": "Vivacité", "color": Color(0.6, 1.0, 0.9), "icon": "swift"},
	"t_mind": {"name": "Esprit vif", "color": Color(0.7, 0.9, 1.0), "icon": "grace"},
	"t_str": {"name": "Rage du guerrier", "color": Color(1.0, 0.6, 0.4), "icon": "might"},
	"t_arcane": {"name": "Arcanes", "color": Color(0.7, 0.8, 1.0), "icon": "grace"},
	"t_all": {"name": "Éveil", "color": Color(1.0, 0.95, 0.6), "icon": "solar"},
	"t_luck": {"name": "Bonne étoile", "color": Color(1.0, 0.9, 0.4), "icon": "keen"},
	"t_crit": {"name": "Instinct du prédateur", "color": Color(1.0, 0.95, 0.5), "icon": "keen"},
	"t_speed": {"name": "Frénésie", "color": Color(1.0, 0.6, 0.3), "icon": "frenzy"},
	"t_power": {"name": "Puissance", "color": Color(1.0, 0.35, 0.35), "icon": "fury"},
	"t_guard": {"name": "Carapace", "color": Color(0.7, 0.85, 1.0), "icon": "barrier"},
	"t_evade": {"name": "Pas de l'ombre", "color": Color(0.7, 1.0, 0.7), "icon": "evasion"},
	"t_riposte": {"name": "Riposte", "color": Color(1.0, 0.85, 0.5), "icon": "keen"},
	"t_wind": {"name": "Danse du vent", "color": Color(0.6, 1.0, 0.85), "icon": "haste"},
	"t_berserk": {"name": "Fureur du désespoir", "color": Color(1.0, 0.3, 0.25), "icon": "fury"},
	"t_vamp": {"name": "Soif de sang", "color": Color(0.9, 0.2, 0.3), "icon": "regen"},
	"t_harvest": {"name": "Moisson", "color": Color(0.9, 0.8, 0.4), "icon": "haste"},
	"t_bastion": {"name": "Bastion", "color": Color(0.7, 0.85, 1.0), "icon": "barrier"},
	"t_mastery": {"name": "Maîtrise", "color": Color(0.75, 0.7, 1.0), "icon": "grace"},
	"t_rhythm": {"name": "Rythme", "color": Color(1.0, 0.7, 0.35), "icon": "frenzy"},
	"t_fortune": {"name": "Fortune", "color": Color(1.0, 0.9, 0.4), "icon": "keen"},
	"t_predator": {"name": "Prédateur", "color": Color(1.0, 0.5, 0.4), "icon": "keen"},
	"t_parry": {"name": "Contre parfait", "color": Color(1.0, 0.85, 0.5), "icon": "fury"},
	"t_survive": {"name": "Instinct de survie", "color": Color(0.6, 1.0, 0.7), "icon": "haste"},
}
const STAT_FR := {"str_pct": "Force", "agi_pct": "Agilité", "int_pct": "Intelligence", "wis_pct": "Sagesse", "lck_pct": "Chance",
	"crit": "chances de critique", "mcrit": "", "crit_dmg": "dégâts critiques", "atk_speed": "vitesse d'attaque",
	"cast_speed": "vitesse d'incantation", "dmg_pct": "dégâts", "def_pct": "défense", "eva": "esquive", "move_speed": "vitesse de déplacement",
	"lifesteal": "vol de vie"}


## Le modèle d'Eden peut-il tomber en butin ?
static func in_pool(e: Dictionary) -> bool:
	return not e.has("nopool")


## Passif d'un trophée de rareté [param rarity] fait d'après le modèle d'Eden [param e].
static func passive_for(e: Dictionary, rarity: int) -> Dictionary:
	var kind := String(e.get("trophy", "agi"))
	var p := proc_for(kind, rarity, int(e.get("level", 0)))
	return {"name": String(KINDS.get(kind, KINDS.agi).name), "desc": describe(p), "stat": {}, "procs": [p], "trophy": kind}


static func proc_for(kind: String, rarity: int, level := 0) -> Dictionary:
	var r := clampi(rarity, 0, 5)
	var p: Dictionary = KINDS.get(kind, KINDS.agi).duplicate(true)
	p.erase("name")
	p["id"] = "trophy_" + kind
	var lk := level_mult(level)
	if float(p.chance) < 1.0:
		p.chance = snappedf(minf(float(p.chance) * float(CHANCE_MULT[r]) * sqrt(lk), 0.95), 0.005)
	var vm := float(VALUE_MULT[r]) * lk
	if p.has("stats"):
		var st := {}
		for s in p.stats:
			st[s] = snappedf(float(p.stats[s]) * vm, 0.01)
		p.stats = st
	for k in ["mult", "amount"]:
		if p.has(k):
			p[k] = snappedf(float(p[k]) * vm, 0.01)
	return p


## Force selon le niveau du trophée (variantes de niveau d'un même effet ; 0 : sans niveau).
static func level_mult(level: int) -> float:
	if level <= 0:
		return 1.0
	return LEVEL_MIN + LEVEL_SPAN * clampf(float(level) / 90.0, 0.0, 1.0)


## Texte lisible du buff (fiche de l'objet).
static func describe(p: Dictionary) -> String:
	if String(p.effect) != "stat_buff":
		if String(p.effect) == "double_hit":
			return "%d %% de chances que chaque coup frappe une 2e fois (%d %% des dégâts)" % [roundi(float(p.chance) * 100), roundi(float(p.mult) * 100)]
		if String(p.effect) == "stun":
			return "%d %% de chances %s : renverse la cible (%.1f s, pas les boss)" % [roundi(float(p.chance) * 100), Procs.TRIGGER_TEXT.get(String(p.trigger), ""), float(p.duration)]
		return Procs.describe(p)
	var parts: PackedStringArray = []
	for s in p.stats:
		var fr := String(STAT_FR.get(s, s))
		if fr != "":
			parts.append("+%d %% %s%s" % [roundi(float(p.stats[s]) * 100), "d'" if fr.left(1).to_lower() in ["a", "e", "i", "o", "u", "é"] else "de ", fr])
	var chance := float(p.chance)
	var head := ("%d %% de chances " % roundi(chance * 100) if chance < 1.0 else "") + String(Procs.TRIGGER_TEXT.get(String(p.trigger), ""))
	return "%s : %s pendant %d s" % [head, ", ".join(parts), roundi(float(p.duration))]
