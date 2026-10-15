class_name Items
extends RefCounted
## Équipement (voir DESIGN.md) :
## - chaque objet a un type de base (stats orientées : katana = physique...) ;
## - à la création, un jet de qualité entre 90 % et 120 % des stats de base,
##   et des affixes tirés dans une fourchette selon la rareté ;
## - amélioration +1 → +10 : +10 % de stats de base par niveau, et aux paliers
##   +4, +6, +8, +10 une stat aléatoire est renforcée (ou un affixe ajouté) ;
## - désassemblage → matériaux, vente → or ;
## - pièces de set (rares et épiques) : bonus à 2 / 4 / 6 pièces portées, dont des
##   effets déclenchés façon Eden (foudre, gel, buffs temporaires...).
## Niveaux : "level" = niveau de l'objet dans Eden (affiché, chronologie des zones). Sa
## puissance (qui règle ses stats) suit le niveau du héros pendant la run, plafonnée au
## niveau de l'objet (power_cap) : un objet 23 n'évolue plus après le niveau 23, un objet 90
## suit toute la run. Hors run : la puissance maximale. Stats fixes, seul le jet de qualité
## varie ; les stats bonus n'arrivent qu'aux améliorations +4, +6, +8, +10 (Craft).

## Emplacements d'équipement (le trophée n'en est plus un depuis 0.1.130 : collection de la run,
## Run.trophies).
const SLOTS := ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]
const SLOT_NAMES := {
	"weapon": "Arme", "head": "Tête", "chest": "Torse", "legs": "Jambes",
	"gloves": "Gants", "boots": "Bottes", "back": "Cape",
	"necklace": "Collier", "ring": "Bague", "trophy": "Trophée", "offhand": "Arme secondaire",
}
## Pièces d'armure et accessoires (bijoux et trophée, comme dans Eden).
const ARMOR := ["head", "chest", "legs", "gloves", "boots", "back"]
const ACCESSORIES := ["necklace", "ring", "trophy"]
## Le trophée ne tombe que des élites et des boss (butin rare ou mieux).
## Types de base : nom, stats de base (niveau 1, qualité 100 %).
const BASES := {
	"weapon": {"name": "Katana", "stats": {"patk": 14.0, "matk": 6.0, "crit": 0.02}},
	"head": {"name": "Kabuto", "stats": {"hp": 35.0, "def": 2.0, "wis": 2.0}},
	"chest": {"name": "Dō", "stats": {"hp": 60.0, "def": 4.0, "str": 2.0}},
	"legs": {"name": "Hakama", "stats": {"hp": 45.0, "def": 3.0, "agi": 2.0}},
	"gloves": {"name": "Kote", "stats": {"patk": 4.0, "matk": 4.0, "atk_speed": 0.02}},
	"boots": {"name": "Suneate", "stats": {"hp": 20.0, "move_speed": 0.04, "agi": 1.0}},
	"back": {"name": "Haori", "stats": {"hp": 30.0, "crit": 0.02, "lck": 2.0}},
	"necklace": {"name": "Collier", "stats": {"hp": 25.0, "matk": 3.0, "wis": 2.0}},
	"ring": {"name": "Bague", "stats": {"patk": 3.0, "crit": 0.015, "lck": 2.0}},
	"trophy": {"name": "Trophée", "stats": {"str": 1.5, "agi": 1.5, "int": 1.5, "wis": 1.5, "lck": 1.5}},
}
## Armes selon la classe (comme dans Eden : attaque physique ET magique, attribut principal).
const WEAPON_BASES := {
	"katana": {"patk": 14.0, "matk": 6.0, "crit": 0.02, "str": 2.0},
	"axe": {"patk": 16.0, "matk": 5.0, "str": 3.0},
	"dagger": {"patk": 12.0, "matk": 5.0, "crit": 0.04, "agi": 3.0},
	"bow": {"patk": 14.0, "matk": 5.0, "agi": 3.0},
	"scepter": {"patk": 8.0, "matk": 13.0, "wis": 3.0},
	"staff": {"patk": 5.0, "matk": 16.0, "int": 3.0},
}
const ATTRIBUTES := ["str", "agi", "int", "wis", "lck"]
## Raretés d'Eden : blanc commun, vert spécial, bleu rare, violet épique, orange mythique,
## or légendaire. Seuls les mythiques et légendaires vont dans l'archive ; ils ne tombent
## que des boss (ou se fabriquent, pour les mythiques).
const RARITIES := [
	{"name": "Commun", "color": Color(0.86, 0.86, 0.86), "affixes": 0},
	{"name": "Spécial", "color": Color(0.42, 0.9, 0.42), "affixes": 1},
	{"name": "Rare", "color": Color(0.4, 0.66, 1.0), "affixes": 2},
	{"name": "Épique", "color": Color(0.78, 0.45, 1.0), "affixes": 3},
	{"name": "Mythique", "color": Color(1.0, 0.55, 0.15), "affixes": 3},
	{"name": "Légendaire", "color": Color(1.0, 0.84, 0.25), "affixes": 4},
]
const MYTHIC := 4
const LEGENDARY := 5
## Raretés archivées (orange et or).
const ARCHIVE_MIN_RARITY := 4
## Jet de qualité (% des stats connues de l'objet d'Eden) : de commun à épique au hasard,
## mythique toujours 100 %, légendaire entre 101 et 120 %.
const QUALITY := [[0.7, 0.9], [0.75, 0.95], [0.8, 1.0], [0.85, 1.0], [1.0, 1.0], [1.01, 1.2]]
const RARITY_MULT := [0.85, 0.93, 1.0, 1.1, 1.22, 1.32]
## Valeurs de référence au niveau 1 d'une stat d'objet d'Eden « moyen » (r = 1).
const REF_FLAT := {"patk": 15.0, "matk": 15.0, "str": 2.5, "agi": 2.5, "int": 2.5, "wis": 2.5, "lck": 2.5}
const REF_SLOT := {"head": {"hp": 35.0, "def": 2.0}, "chest": {"hp": 60.0, "def": 4.0}, "legs": {"hp": 45.0, "def": 3.0},
	"gloves": {"hp": 20.0, "def": 1.5}, "boots": {"hp": 20.0, "def": 1.5}, "back": {"hp": 30.0, "def": 1.5},
	"necklace": {"hp": 25.0, "def": 1.5}, "ring": {"hp": 20.0, "def": 1.0}, "trophy": {"hp": 20.0, "def": 1.0},
	"weapon": {"hp": 30.0, "def": 1.5}}
const REF_PCT := {"crit": 0.03, "mcrit": 0.03, "crit_dmg": 0.1, "eva": 0.02, "parry": 0.03, "atk_speed": 0.04,
	"move_speed": 0.03, "def_pct": 0.03, "cdr": 0.03, "dmg_pct": 0.03}
const STAT_NAMES := {
	"atk": "Attaque", "patk": "Attaque physique", "matk": "Attaque magique",
	"str": "Force", "agi": "Agilité", "int": "Intelligence", "wis": "Sagesse", "lck": "Chance",
	"mcrit": "Critique magique", "hp": "PV", "def": "Défense", "crit": "Critique physique",
	"crit_dmg": "Dégâts critiques", "atk_speed": "Vitesse d'attaque",
	"move_speed": "Vitesse", "cdr": "Recharge", "lifesteal": "Vol de vie",
}
const PERCENT_STATS := ["crit", "mcrit", "crit_dmg", "atk_speed", "move_speed", "cdr", "lifesteal",
	"hp_pct", "dmg_pct", "area", "reach", "elite_dmg", "dot_pct", "def_pct", "atk_pct", "eva", "parry", "matk_pct",
	"cast_speed", "heal_pct", "str_pct", "agi_pct", "int_pct", "wis_pct", "lck_pct"]
const EXTRA_STAT_NAMES := {
	"hp_pct": "PV max", "dmg_pct": "Dégâts", "area": "Zone d'effet", "reach": "Portée",
	"elite_dmg": "Dégâts contre élites et boss", "dot_pct": "Dégâts sur la durée",
	"def_pct": "Défense", "atk_pct": "Attaque", "eva": "Esquive", "parry": "Parade", "matk_pct": "Attaque magique",
	"cast_speed": "Vitesse d'incantation", "heal_pct": "Soins", "str_pct": "Force", "agi_pct": "Agilité",
	"int_pct": "Intelligence", "wis_pct": "Sagesse", "lck_pct": "Chance",
}
## Couleur des pièces de set (vert, comme dans Eden).
const SET_COLOR := Color(0.4, 0.95, 0.55)
## Chances qu'un objet rare ou épique soit une pièce de set.
const SET_CHANCE := 0.3
## Sets : nom, suffixe des objets, bonus à 2 / 4 / 6 pièces (stats et procs).
const SETS := {
	"storm": {"name": "Tempête", "suffix": "de la Tempête", "bonus": {
		2: {"stat": {"atk_speed": 0.08}},
		4: {"procs": [{"trigger": "hit", "chance": 0.12, "cd": 2.5, "effect": "lightning", "mult": 0.9, "chain": 2, "radius": 6.0}]},
		6: {"stat": {"dmg_pct": 0.12}, "procs": [{"trigger": "basic_hit", "chance": 0.25, "cd": 3.0, "effect": "lightning", "mult": 2.0, "chain": 5, "radius": 8.0}]}}},
	"frost": {"name": "Givre éternel", "suffix": "du Givre éternel", "bonus": {
		2: {"stat": {"cdr": 0.06}},
		4: {"procs": [{"trigger": "skill_hit", "chance": 0.35, "cd": 5.0, "effect": "freeze", "duration": 1.5, "radius": 3.5}]},
		6: {"stat": {"area": 0.15}, "procs": [{"trigger": "perfect", "chance": 1.0, "cd": 0.0, "effect": "nova", "radius": 6.0, "duration": 2.5}]}}},
	"blood": {"name": "Lame sanglante", "suffix": "de la Lame sanglante", "bonus": {
		2: {"stat": {"lifesteal": 0.03}},
		4: {"procs": [{"trigger": "crit", "chance": 1.0, "cd": 8.0, "effect": "buff", "status": "frenzy", "duration": 4.0}]},
		6: {"stat": {"crit_dmg": 0.35}, "procs": [{"trigger": "kill", "chance": 0.25, "cd": 0.0, "effect": "heal", "amount": 0.03}]}}},
	"falcon": {"name": "Œil du faucon", "suffix": "de l'Œil du faucon", "bonus": {
		2: {"stat": {"crit": 0.06}},
		4: {"procs": [{"trigger": "kill", "chance": 1.0, "cd": 8.0, "effect": "buff", "status": "keen", "duration": 5.0}]},
		6: {"stat": {"reach": 0.2, "elite_dmg": 0.25}}}},
	"phoenix": {"name": "Phénix", "suffix": "du Phénix", "bonus": {
		2: {"stat": {"hp_pct": 0.1}},
		4: {"procs": [{"trigger": "low_hp", "chance": 1.0, "cd": 60.0, "effect": "heal", "amount": 0.3,
			"then": [{"effect": "explosion", "mult": 1.5, "radius": 5.0, "applies": {"burn": 5.0}}]}]},
		6: {"stat": {"dot_pct": 0.4}, "procs": [{"trigger": "crit", "chance": 0.3, "cd": 1.0, "effect": "burn", "duration": 4.0, "radius": 2.5}]}}},
	# panoplie du Panthéon : des effets de geste, pas de statistiques (jamais en duel à l'arme)
	"pantheon": {"name": "Esprits", "suffix": "des Esprits", "bonus": {
		2: {"procs": [{"trigger": "perfect", "chance": 1.0, "cd": 0.0, "effect": "stat_buff", "status": "t_esprit", "stats": {"dmg_pct": 0.1}, "duration": 5.0}]},
		4: {"procs": [{"trigger": "perfect", "chance": 1.0, "cd": 0.0, "effect": "cdr", "amount": 0.6}]},
		6: {"procs": [{"trigger": "dodge", "chance": 1.0, "cd": 8.0, "effect": "buff", "status": "haste", "duration": 3.0,
			"then": [{"effect": "buff", "status": "fury", "duration": 3.0}]}]}},
		# éveil (lot E2) : avec 6 pièces éveillées portées, le palier 6 devient celui-ci (recharge moitié, effets plus
		# longs, dégâts et critique en plus)
		"awake": {
		6: {"stat": {"dmg_pct": 0.1, "crit": 0.05}, "procs": [{"trigger": "dodge", "chance": 1.0, "cd": 4.0, "effect": "buff", "status": "haste", "duration": 4.0,
			"then": [{"effect": "buff", "status": "fury", "duration": 4.0}]}]}}},
	# archétypes de donjon sans équivalent dans les anciens sets (lot « Donjons », panoplies B9)
	"salvo": {"name": "Salve", "suffix": "de la Salve", "bonus": {
		2: {"stat": {"reach": 0.12}},
		4: {"procs": [{"trigger": "skill_hit", "chance": 0.2, "cd": 4.0, "effect": "echo", "mult": 0.6}]},
		6: {"stat": {"dmg_pct": 0.08}, "procs": [{"trigger": "basic_hit", "chance": 0.2, "cd": 2.5, "effect": "explosion", "mult": 0.9, "radius": 3.5}]}}},
	"rampart": {"name": "Rempart", "suffix": "du Rempart", "bonus": {
		2: {"stat": {"def_pct": 0.1}},
		4: {"procs": [{"trigger": "hurt", "chance": 1.0, "cd": 10.0, "effect": "buff", "status": "barrier", "duration": 3.0}]},
		6: {"stat": {"hp_pct": 0.08}, "procs": [{"trigger": "hurt", "chance": 0.25, "cd": 8.0, "effect": "buff", "status": "thorns", "duration": 4.0}]}}},
	"wind": {"name": "Vent céleste", "suffix": "du Vent céleste", "bonus": {
		2: {"stat": {"move_speed": 0.06}},
		4: {"procs": [{"trigger": "dodge", "chance": 1.0, "cd": 5.0, "effect": "buff", "status": "haste", "duration": 3.0,
			"then": [{"effect": "buff", "status": "fury", "duration": 3.0}]}]},
		6: {"stat": {"atk_speed": 0.1}, "procs": [{"trigger": "perfect", "chance": 1.0, "cd": 0.0, "effect": "cdr", "amount": 1.0}]}}},
}
## Fourchettes des affixes (niveau 1 pour les stats plates).
const AFFIX_RANGES := {
	"patk": [3.0, 7.0], "matk": [3.0, 7.0], "hp": [25.0, 50.0], "def": [2.0, 4.0],
	"str": [2.0, 5.0], "agi": [2.0, 5.0], "int": [2.0, 5.0], "wis": [2.0, 5.0], "lck": [2.0, 5.0],
	"mcrit": [0.02, 0.05],
	"crit": [0.02, 0.05], "crit_dmg": [0.08, 0.18], "atk_speed": [0.03, 0.07],
	"move_speed": [0.02, 0.04], "cdr": [0.02, 0.05], "lifesteal": [0.01, 0.02],
}
const MAX_UPGRADE := 10
const MILESTONES := [4, 6, 8, 10]
const MATERIALS := {"crystal": "Cristaux"}
const ADJECTIVES := ["du Vent", "de Cendre", "du Lotus", "de l'Aube", "du Crépuscule", "de Fer",
	"du Dragon", "de la Grue", "du Renard", "de la Lune", "du Tonnerre", "de Sakura"]

static var _icons: Dictionary = {}


static func icons() -> Dictionary:
	if _icons.is_empty():
		_icons = JSON.parse_string(FileAccess.get_file_as_string("res://data/item_icons.json"))
	return _icons


static func material_icon(mat: String) -> String:
	return String(icons().get("materials", {}).get(mat, ""))


## Objet aléatoire de niveau [param level] ; [param luck] augmente la rareté.
## [param min_rarity] : rareté minimale (boutique).
## Nom du type de base ; l'arme dépend de la classe (Katana, Hache, Arc...).
static func _base_name(slot: String, class_id: String, wtype := "") -> String:
	if slot == "weapon":
		return String(GameData.weapon_type(wtype if wtype != "" else default_weapon_type(class_id)).get("name", BASES.weapon.name))
	return String(BASES[slot].name)


## Type d'arme de départ d'une classe (celui de son arme d'origine dans Eden).
## Objet à effet unique (trophée) : ne s'améliore pas (forge, enclume, gemmes, enchantements).
static func is_unique(item: Dictionary) -> bool:
	return String(item.get("slot", "")) == "trophy"


const UNIQUE_TEXT := "Trophée : un effet unique, il ne s'améliore pas."


static func default_weapon_type(class_id: String) -> String:
	return String(GameData.class_data(class_id).get("weapon_type", "katana"))


## Type d'une arme (les anciennes armes n'avaient que leur classe d'origine).
static func weapon_type_of(item: Dictionary) -> String:
	if item.has("wtype"):
		return String(item.wtype)
	return default_weapon_type(String(item.get("wclass", "samurai")))


static func generate(level: int, luck := 0.0, slot := "", class_id := "samurai", min_rarity := 0, wtype := "", max_rarity := 3) -> Dictionary:
	if wtype == "":
		# en run : le butin d'armes suit l'arme en main ; sinon l'arme de la classe
		wtype = Run.weapon_type() if Run.active and class_id == Run.class_id else default_weapon_type(class_id)
	var rarity := roll_rarity(luck, min_rarity, max_rarity)
	var free_slot := slot == ""
	if slot == "":
		slot = SLOTS.pick_random()  # jamais de trophée (collection de la run, Run.trophies)
	# objet d'Eden de la zone : nom, icône, stats connues, set, passif
	if not GameData.eden_by_slot.is_empty():
		var target := eden_target(level)
		var tpl := eden_template(slot, wtype, target, rarity)
		if free_slot and slot != "trophy" and not tpl.is_empty() and int(tpl.level) > target:
			# pas de modèle assez bas pour cet emplacement (anneaux, trophées…) : un autre
			# emplacement plutôt qu'un objet au-dessus du niveau du héros
			var others := SLOTS.filter(func(x): return x != slot and x != "trophy")
			others.shuffle()
			for other in others:
				var t2 := eden_template(other, wtype, target, rarity)
				if not t2.is_empty() and int(t2.level) <= target:
					tpl = t2
					break
		if not tpl.is_empty():
			return from_template(tpl, level, rarity)
	var item := {
		"uid": "%d_%d" % [Time.get_ticks_usec(), randi() % 100000],
		"slot": slot, "level": level, "rarity": rarity, "rv": 2,
		"quality": snappedf(randf_range(0.9, 1.2), 0.01),
		"upgrade": 0,
		"affixes": {},
		"name": "%s %s" % [_base_name(slot, class_id, wtype), ADJECTIVES.pick_random()],
	}
	if slot == "weapon":
		item["wtype"] = wtype
		var weapons: Array = GameData.weapon_type(wtype).get("weapons", [])
		if not weapons.is_empty():
			var w: Dictionary = weapons[mini(rarity, weapons.size() - 1)]
			item["weapon"] = w.code
			item["icon"] = w.icon
	# identité d'un vrai objet d'Eden (nom, icône, modèle d'arme pour les épiques et légendaires)
	var base := eden_base(slot, wtype, level, rarity)
	if not base.is_empty():
		item["eden"] = int(base.id)
		item["name"] = String(base.name)
		item["icon"] = String(base.icon)
		if slot == "weapon" and base.has("model"):
			item["weapon"] = String(base.code)
	if not item.has("icon"):
		var list: Array = icons().get(slot, [])
		item["icon"] = list[(level * 3 + rarity * 7 + randi() % 4) % maxi(list.size(), 1)] if not list.is_empty() else ""
	var pool := AFFIX_RANGES.keys()
	pool.shuffle()
	for i in int(RARITIES[rarity].affixes):
		_add_affix(item, pool[i])
	if rarity >= 2 and randf() < SET_CHANCE:
		make_set_piece(item, SETS.keys().pick_random())
	return item


## Rareté tirée : 0 commun … 3 épique (butin courant) ; 4 mythique et 5 légendaire
## seulement si [param max_r] le permet (boss, fabrication).
static func roll_rarity(luck: float, min_r := 0, max_r := 3) -> int:
	var roll := randf() + luck
	var r := 0
	for t in [[1.6, 5], [1.38, 4], [1.12, 3], [0.85, 2], [0.55, 1]]:
		if roll > float(t[0]):
			r = int(t[1])
			break
	return clampi(maxi(r, min_r), 0, maxi(max_r, min_r))


## Zone jouée (indice dans zones.json).
## Coffre de récompense ouvert hors run (Rewards) : zone d'où vient le coffre (sinon la zone
## choisie au lobby donnerait des objets d'une autre époque, niveau 90 pour un débutant).
static var reward_zone := ""


static func zone_band() -> int:
	if reward_zone != "":
		return GameData.zone_index(reward_zone)
	return GameData.zone_index(Run.zone_id if Run.active else Profile.selected_zone)


## Niveau d'Eden visé par le butin au niveau de run [param level] dans la zone jouée.
static func eden_target(level: int) -> int:
	var t := GameData.eden_level_at(zone_band(), level)
	if Run.active and Run.hero_level > 0 and not GameData.eden_bands.is_empty():
		# en run : pas d'objet au-dessus du niveau du héros (sauf le bas de la tranche de la zone :
		# une zone avancée garde ses propres objets dès le niveau 1)
		var low := int(GameData.eden_bands[clampi(zone_band(), 0, GameData.eden_bands.size() - 1)][0])
		t = mini(t, maxi(Run.hero_level, low))
	return t


## Modèle d'Eden : même emplacement (ou type d'arme), niveau d'Eden le plus haut sans
## dépasser [param target] (chronologie : pas d'objet d'une zone plus avancée), même rareté
## si possible. Dans Eden, les objets non mythiques s'arrêtent vers le niveau 40 : au-delà,
## le butin courant prend un modèle courant du bon niveau (il garde sa rareté tirée).
## Mythiques et légendaires gardent un modèle d'archive : sans modèle assez bas (premières
## zones), le plus bas qui existe. Les trophées sans niveau (0) conviennent partout.
static func eden_template(slot: String, wtype: String, target: int, rarity: int) -> Dictionary:
	var list: Array = GameData.eden_by_slot.get(wtype if slot == "weapon" else slot, []).filter(
		func(e): return (not (e.get("r", {}) as Dictionary).is_empty() or e.has("passive") or e.has("trophy")) and Trophies.in_pool(e))
	if list.is_empty():
		return {}
	var archive := rarity >= MYTHIC
	var same := list.filter(func(e): return int(e.rarity) == rarity)
	var family := list.filter(func(e): return (int(e.rarity) >= MYTHIC) == archive)
	var pools: Array = [same]
	if rarity == 3:
		pools.append(list.filter(func(e): return int(e.rarity) == 2))  # pas de violet dans Eden
	pools.append(family)
	if not archive:
		pools.append(list)
	for pool: Array in pools:
		var near := pool.filter(func(e): return (int(e.level) == 0 and slot == "trophy") or (int(e.level) <= target and int(e.level) >= target - 12))
		if not near.is_empty():
			return near.pick_random()
	for pool: Array in pools:
		var below := pool.filter(func(e): return int(e.level) <= target)
		if not below.is_empty():
			var top := 0
			for e in below:
				top = maxi(top, int(e.level))
			return below.filter(func(e): return int(e.level) >= top - 5).pick_random()
	for pool: Array in pools:
		if pool.is_empty():
			continue
		var lowest := 1000
		for e in pool:
			lowest = mini(lowest, int(e.level))
		return pool.filter(func(e): return int(e.level) <= lowest + 4).pick_random()
	return list.pick_random()


static func _ref(slot: String, stat: String) -> float:
	if REF_PCT.has(stat):
		return float(REF_PCT[stat])
	if stat == "hp" or stat == "def":
		return float(REF_SLOT.get(slot, REF_SLOT.weapon).get(stat, 0.0))
	return float(REF_FLAT.get(stat, 0.0))


## Objet du jeu tiré d'un objet d'Eden : niveau d'Eden de l'objet, stats connues
## rapportées au niveau de puissance [param level] (niveau de run), × rareté × jet de
## qualité ; set et passif d'arme pour les mythiques et légendaires.
static func from_template(e: Dictionary, level: int, rarity := -1) -> Dictionary:
	var r := int(e.rarity) if rarity < 0 else rarity
	var slot := String(e.slot)
	var q: Array = QUALITY[r]
	var item := {"uid": "%d_%d" % [Time.get_ticks_usec(), randi() % 100000], "slot": slot, "level": int(e.level),
		"plevel": level, "rarity": r,
		"quality": snappedf(randf_range(float(q[0]), float(q[1])), 0.01), "upgrade": 0, "affixes": {},
		"name": String(e.name), "icon": String(e.icon), "eden": int(e.id), "rv": 3}
	if slot == "weapon":
		item["wtype"] = String(e.wtype)
		if e.has("model"):
			item["weapon"] = String(e.code)
		else:
			var ws: Array = GameData.weapon_type(String(e.wtype)).get("weapons", [])
			if not ws.is_empty():
				item["weapon"] = String(ws[mini(r, ws.size() - 1)].code)
	var base := {}
	for s in e.get("r", {}):
		var ref := _ref(slot, String(s))
		if ref > 0.0:
			base[s] = ref * float(e.r[s]) * float(RARITY_MULT[r])  # stats fixes : seule la qualité varie
	item["base"] = base
	# sets : pièces mythiques et légendaires ; les sets créés en mode dev (« u… ») à toute rareté
	if e.has("set") and (r >= MYTHIC or String(e.set).begins_with("u")):
		item["set"] = String(e.set)
	if e.has("dev") and (e.has("passive") or e.has("trophy")):
		# modèle modifié en mode dev : bonus fixes + buff sous condition (force selon la rareté)
		var pv: Dictionary = e.get("passive", {})
		item["passive"] = DevEdits.make_passive(String(pv.get("name", "")), pv.get("stat", {}), String(e.get("trophy", "")), r, pv.get("procs", []))
	elif slot == "trophy":
		item["passive"] = Trophies.passive_for(e, r)  # buff sous condition, force selon la rareté
	elif e.has("passive") and r >= MYTHIC:
		item["passive"] = e.passive
	return item


## Définition d'un set : sets d'Eden (data/eden_catalog.json) ou anciens sets du jeu.
static func set_def(sid: String) -> Dictionary:
	if Survivor.active and sid.begins_with("e"):
		var sv := SurvivorPool.set_def(sid)  # Survivant : bonus à 2 / 3 / 5 pièces (règle par famille de set)
		if not sv.is_empty():
			return sv
	return SETS.get(sid, GameData.eden_sets.get(sid, {}))


## Paliers d'un set (nombre de pièces), dans l'ordre.
static func set_tiers(sid: String) -> Array:
	var out: Array = []
	for n in set_def(sid).get("bonus", {}):
		out.append(int(n))
	out.sort()
	return out


static func set_bonus(sid: String, n: int) -> Dictionary:
	var b: Dictionary = set_def(sid).get("bonus", {})
	return b.get(n, b.get(str(n), {}))


## Objet d'Eden qui sert de modèle à un objet généré : même emplacement (ou type d'arme),
## même rareté si possible, niveau d'Eden le plus proche (le niveau du jeu × 1,5).
static func eden_base(slot: String, wtype: String, level: int, rarity: int) -> Dictionary:
	var list: Array = GameData.eden_by_slot.get(wtype if slot == "weapon" else slot, []).filter(Trophies.in_pool)
	if list.is_empty():
		return {}
	var target := float(level) * 1.5 + 1.0
	var cands := list.filter(func(e): return int(e.rarity) == rarity)
	if cands.size() < 3:
		cands = list.duplicate()
	cands.sort_custom(func(a, b): return absf(float(a.level) - target) < absf(float(b.level) - target))
	return cands[randi() % mini(6, cands.size())]


## Objet d'Eden donné (archive, mode dev) : nouvel objet du jeu à son image.
static func from_eden(e: Dictionary, level := 0) -> Dictionary:
	# puissance : place du niveau d'Eden de l'objet dans la tranche de sa zone
	return from_template(e, level if level > 0 else GameData.power_level_of(int(e.level)))


## Transforme l'objet en pièce du set [param set_id].
static func make_set_piece(item: Dictionary, set_id: String) -> void:  # anciens sets du jeu
	item["set"] = set_id
	var base := String(GameData.eden_by_id.get(int(item.get("eden", 0)), {}).get("name", ""))
	if base == "":
		base = _base_name(String(item.slot), "", weapon_type_of(item) if item.slot == "weapon" else "")
	item["name"] = "%s %s" % [base, SETS[set_id].suffix]


## Nombre de pièces portées par set (emplacement -> objet).
static func set_counts(equipped: Dictionary) -> Dictionary:
	var out := {}
	for slot in equipped:
		var sid := String(equipped[slot].get("set", ""))
		if sid != "":
			out[sid] = int(out.get(sid, 0)) + 1
		var arch := String(equipped[slot].get("archetype", ""))  # panoplie de donjon : compte en plus du set d'Eden
		if arch != "" and arch != sid and SETS.has(arch):
			out[arch] = int(out.get(arch, 0)) + 1
	return out


## Pièces éveillées du set [param sid] parmi [param equipped] (panoplie des Esprits : Pantheon.piece_awake).
static func awakened_count(equipped: Dictionary, sid: String) -> int:
	var n := 0
	for slot in equipped:
		var it: Dictionary = equipped[slot]
		if String(it.get("set", "")) == sid and (Pantheon.piece_awake(it) if sid == "pantheon" else bool(it.get("awakened", false))):
			n += 1
	return n


## Bonus de set actifs : [{set, pieces, stat, procs}].
static func active_set_bonuses(equipped: Dictionary) -> Array:
	var out: Array = []
	var counts := set_counts(equipped)
	for sid in counts:
		for n in set_tiers(sid):
			if int(counts[sid]) >= n:
				var b: Dictionary = set_bonus(sid, n)
				var aw: Dictionary = set_def(sid).get("awake", {}).get(n, {})
				if not aw.is_empty() and awakened_count(equipped, sid) >= n:
					b = aw  # palier éveillé (panoplie des Esprits)
				var procs: Array = []
				var i := 0
				for p: Dictionary in b.get("procs", []):
					var q := p.duplicate(true)
					q["id"] = "set_%s_%d_%d" % [sid, n, i]
					procs.append(q)
					i += 1
				out.append({"set": sid, "pieces": n, "stat": b.get("stat", {}), "procs": procs})
	return out


## Effets déclenchés d'un équipement (emplacement -> objet) : bonus de set actifs, passifs des
## armes mythiques et légendaires d'Eden et des trophées.
static func gear_procs(equipped: Dictionary) -> Array:
	var out: Array = []
	for b in active_set_bonuses(equipped):
		out.append_array(b.procs)
	for slot in equipped:
		if slot == "trophy" or String(equipped[slot].get("slot", "")) == "trophy":
			continue  # anciens trophées portés : plus de l'équipement
		var i := 0
		for p: Dictionary in equipped[slot].get("passive", {}).get("procs", []):
			var q := p.duplicate(true)
			q["id"] = "passive_%s_%d" % [slot, i]
			out.append(q)
			i += 1
	return out


## Lignes de description d'un bonus de set.
static func bonus_lines(b: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = []
	for s in b.get("stat", {}):
		out.append(stat_text(s, b.stat[s]))
	for p in b.get("procs", []):
		out.append(Procs.describe(p))
	return out


static func _level_k(level: int) -> float:
	return pow(1.08, level - 1)


## Niveau de puissance d'un objet (niveau de run où il est tombé) : règle ses stats,
## ses coûts et sa valeur. Le niveau affiché ("level") est celui d'Eden.
static func power_level(item: Dictionary) -> int:
	if item.get("sv", false):
		# pièce du Survivant : un seul niveau, celui du héros de la run, plafonné à 90 (hors run : 90)
		return clampi(Run.hero_level if Run.active and Run.hero_level > 0 else Survivor.MAX_ITEM_LEVEL, 1, Survivor.MAX_ITEM_LEVEL)
	var cap := power_cap(item)
	return mini(Run.hero_level, cap) if Run.active and Run.hero_level > 0 else cap


## Plafond de puissance : le niveau de l'objet d'Eden, ramené à l'échelle des niveaux de run
## de sa zone s'il est plus haut (les objets de Limestone, niveaux d'Eden 1-13, vont jusqu'au
## niveau 18 de la zone) ; les objets sans niveau (trophées) suivent toujours le héros.
static func power_cap(item: Dictionary) -> int:
	var lv := int(item.get("level", 1))
	if not item.has("eden"):
		return maxi(int(item.get("plevel", lv)), 1)
	if lv <= 0:
		return 999
	return maxi(lv, GameData.power_level_of(lv))


## Note d'un objet (comparaison) : chaque stat rapportée à la valeur habituelle de son
## emplacement au même niveau ; passif +1, pièce de set +0,5.
## [param profile] (profil de stats d'une classe, ClassGear.profile) : chaque stat × son poids, et
## +ARMOR_PREF_BONUS pour une pièce du type d'armure préféré. Sans profil : la note commune (PE, comparaisons).
static func rating(item: Dictionary, profile: Dictionary = {}) -> float:
	if item.is_empty():
		return 0.0
	var slot := String(item.get("slot", "weapon"))
	var lk := _level_k(power_level(item))
	var st := stats(item)
	var w: Dictionary = profile.get("weights", {})
	var r := 0.0
	for s in st:
		var ref := _ref(slot, String(s))
		if ref <= 0.0:
			ref = float(AFFIX_RANGES.get(s, [0.0, 0.0])[1])
		if ref <= 0.0:
			continue
		r += float(w.get(s, 1.0)) * float(st[s]) / (ref * (1.0 if s in PERCENT_STATS else lk))
	if item.has("passive"):
		r += 1.0
	if item.has("set"):
		r += 0.5
	if not profile.is_empty() and armor_type(item) != "" and armor_type(item) == String(profile.get("armor", "")):
		r += ARMOR_PREF_BONUS
	return r


## Bonus de note d'une pièce du type d'armure préféré du profil (autant qu'une pièce de set).
const ARMOR_PREF_BONUS := 0.5


## Type d'armure d'une pièce d'Eden (« tissu », « cuir », « plates ») ; "" pour le reste.
static func armor_type(item: Dictionary) -> String:
	if not item.has("eden"):
		return ""
	return String(GameData.eden_by_id.get(int(item.eden), {}).get("armor", ""))


## Écart avec la pièce portée au même emplacement (+0,15 = 15 % mieux) ; 1 si l'emplacement
## est vide ; 0 pour ce qui ne s'équipe pas.
static func compare_to_equipped(item: Dictionary) -> float:
	var slot := String(item.get("slot", ""))
	if not slot in SLOTS:
		return 0.0
	var worn: Dictionary = Profile.equipped.get(slot, {})
	if worn.is_empty():
		return 1.0
	if String(worn.get("uid", "")) == String(item.get("uid", "-")):
		return 0.0
	var a := rating(anvil_applied(worn, slot))  # en Survie, l'enclume de l'emplacement compte pour les deux pièces
	return (rating(anvil_applied(item, slot)) - a) / maxf(a, 0.01)


static func _add_affix(item: Dictionary, stat: String) -> void:
	var r: Array = AFFIX_RANGES.get(stat, [3.0, 7.0])  # « atk » des anciennes sauvegardes
	var v := randf_range(r[0], r[1])
	if not stat in PERCENT_STATS:
		v *= _level_k(power_level(item))
	item.affixes[stat] = float(item.affixes.get(stat, 0.0)) + v


## Statistiques finales : base × niveau × qualité × amélioration + affixes.
## Stats du type de base de l'objet (l'arme dépend de la classe pour laquelle elle a été créée).
static func base_stats(item: Dictionary) -> Dictionary:
	if item.has("base"):
		return item.base  # stats connues de l'objet d'Eden (niveau 1, rareté comprise)
	if item.get("slot", "weapon") == "weapon":
		return WEAPON_BASES.get(weapon_type_of(item), WEAPON_BASES.katana)
	return BASES.get(item.get("slot", "weapon"), BASES.weapon).stats


static func stats(item: Dictionary, with_extras := true) -> Dictionary:
	var out := {}
	var base := base_stats(item)
	var k := _level_k(power_level(item)) * float(item.get("quality", 1.0)) * (1.0 + 0.1 * int(item.get("upgrade", 0)))
	for s in base:
		out[s] = float(base[s]) * (k if not s in PERCENT_STATS else float(item.get("quality", 1.0)) * (1.0 + 0.1 * int(item.get("upgrade", 0))))
	var aff: Dictionary = item.get("affixes", {})
	for s in aff:
		if s == "atk":
			# ancien affixe d'attaque : compte pour l'attaque physique et magique
			out["patk"] = out.get("patk", 0.0) + float(aff[s])
			out["matk"] = out.get("matk", 0.0) + float(aff[s])
		else:
			out[s] = out.get(s, 0.0) + float(aff[s])
	for s in item.get("passive", {}).get("stat", {}):
		out[s] = out.get(s, 0.0) + float(item.passive.stat[s])
	if with_extras:
		# gemmes serties, enchantement, bonus aléatoires des améliorations
		var ex := Craft.extra_stats(item)
		for s in ex:
			out[s] = out.get(s, 0.0) + float(ex[s])
	return out


## Amélioration d'un niveau (+1). Renvoie la stat renforcée au palier (ou "").
static func upgrade(item: Dictionary) -> String:
	if int(item.get("upgrade", 0)) >= MAX_UPGRADE:
		return ""
	item.upgrade = int(item.get("upgrade", 0)) + 1
	if int(item.upgrade) in MILESTONES:
		var aff: Dictionary = item.affixes
		# moins de 4 affixes : on en ajoute un, sinon on renforce un existant
		if aff.size() < 4 and randf() < 0.5:
			var free := AFFIX_RANGES.keys().filter(func(s): return not aff.has(s))
			var s: String = free.pick_random()
			_add_affix(item, s)
			return s
		var keys := aff.keys()
		if keys.is_empty():
			var s2: String = AFFIX_RANGES.keys().pick_random()
			_add_affix(item, s2)
			return s2
		var pick: String = keys.pick_random()
		_add_affix(item, pick)
		return pick
	return ""


## Amélioration +1 → +10 : seulement de l'or (de plus en plus cher).
static func upgrade_cost(item: Dictionary) -> Dictionary:
	var up := int(item.get("upgrade", 0))
	return {"gold": int(30.0 * pow(up + 1, 1.6) * (1.0 + power_level(item) / 5.0))}


## Part de l'or investi dans les améliorations rendue à la vente.
const UPGRADE_REFUND := 0.5


## Or dépensé pour amener l'objet à son niveau d'amélioration, × 50 %.
static func upgrade_refund(item: Dictionary) -> Dictionary:
	var spent := 0
	var tmp := {"level": power_level(item), "upgrade": 0}
	for u in int(item.get("upgrade", 0)):
		tmp.upgrade = u
		spent += int(upgrade_cost(tmp).gold)
	var n := roundi(float(spent) * UPGRADE_REFUND)
	return {"gold": n} if n > 0 else {}


static func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k in b:
		out[k] = int(out.get(k, 0)) + int(b[k])
	return out


## Désassemblage : un peu de cristaux selon la rareté (et l'amélioration de l'objet) : 1 à 3, +1 par 3 niveaux
## d'amélioration. Avant 0.1.165 c'était 1 à 8, mais un cristal vaut maintenant 5 fois plus d'or
## (`Forge.GOLD_PER_CRYSTAL`) : le démontage reste un complément, pas la source (les clears de Donjon, de Ruée,
## de Siège et de Tour en donnent 30 à 320, voir ActivityLoot).
## Passe E6 : une pièce rachetable à l'Armurerie (découverte : Profile.seen_gear) ne rend que la part de ses
## améliorations. Sinon acheter une pièce d'un palier déjà entamé (15 % du prix, 8 insignes au plus bas) puis la
## démonter (3 cristaux), en boucle, changeait les insignes en cristaux sans limite (≈ 3 insignes le cristal).
static func disassemble_yield(item: Dictionary) -> Dictionary:
	var r := int(item.rarity)
	var base := 0 if item.has("eden") and int(item.eden) in Profile.seen_gear else 1 + r / 2
	return {"crystal": base + int(item.get("upgrade", 0)) / 3}


static func sell_price(item: Dictionary) -> int:
	return int(5 * (power_level(item) + 1) * (int(item.rarity) + 1))


## Vente : or + 70 % des pierres d'amélioration.
static func sell_value(item: Dictionary) -> Dictionary:
	return _merge({"gold": sell_price(item)}, upgrade_refund(item))


static func buy_price(item: Dictionary) -> int:
	return sell_price(item) * 4


static func display_name(item: Dictionary) -> String:
	var up := int(item.get("upgrade", 0))
	return ("+%d " % up if up > 0 else "") + String(item.name)


static func stat_text(stat: String, value) -> String:
	var n: String = STAT_NAMES.get(stat, EXTRA_STAT_NAMES.get(stat, stat))
	if stat in PERCENT_STATS:
		return "+%d %% %s" % [roundi(float(value) * 100.0), n]
	return "+%d %s" % [roundi(float(value)), n]


## Couleur d'affichage : vert pour une pièce de set, sinon celle de la rareté.
static func color_of(item: Dictionary) -> Color:
	return RARITIES[clampi(int(item.get("rarity", 0)), 0, RARITIES.size() - 1)].color


## Type affiché : nom de l'arme de la classe (Katana, Arc...) ou emplacement.
static func _weapon_or_slot(item: Dictionary) -> String:
	if item.slot == "weapon":
		return "Arme (%s)" % String(GameData.weapon_type(weapon_type_of(item)).get("name", "?"))
	return String(SLOT_NAMES.get(item.slot, "Bouclier (collection)"))


## Filet horizontal des cartes.
const SEPARATOR := "[hr color=#4a4562]"


## Entier avec espace insécable entre les milliers (2 272).
static func fmt_num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


## Statistique en pourcentage rattachée à une statistique plate du même nom (« Défense » 231 et « Défense » 4 % :
## une seule ligne sur la carte).
const PCT_OF := {"def_pct": "def", "matk_pct": "matk", "atk_pct": "patk", "str_pct": "str", "agi_pct": "agi",
	"int_pct": "int", "wis_pct": "wis", "lck_pct": "lck"}
## Statistique mise en gros sur la carte, par emplacement : la première présente (« atk » = la plus forte des deux attaques).
const MAIN_STAT := {"weapon": ["atk"], "gloves": ["atk"], "ring": ["atk", "crit"], "necklace": ["hp", "atk"],
	"head": ["def", "hp"], "chest": ["def", "hp"], "legs": ["def", "hp"], "back": ["def", "hp"], "boots": ["def", "hp"],
	"offhand": ["atk", "def"]}
## Lignes secondaires affichées sur la carte courte (les autres derrière « Maj : détails »).
const CARD_ROWS := 5


## Poids d'une statistique pour son emplacement (valeur rapportée à la valeur habituelle) : classe les lignes.
static func stat_weight(slot: String, stat: String, value: float, lk: float) -> float:
	var ref := _ref(slot, stat)
	if ref <= 0.0:
		ref = float(AFFIX_RANGES.get(stat, [0.0, 0.0])[1])
	if ref <= 0.0:
		return 0.5
	return absf(value) / (ref * (1.0 if stat in PERCENT_STATS else lk))


## Clé de la statistique principale (celle qu'on met en gros), "" si l'objet n'en a pas.
static func main_stat_key(item: Dictionary, st: Dictionary) -> String:
	var slot := String(item.get("slot", ""))
	for c in MAIN_STAT.get(slot, []):
		if c == "atk":
			var a := "patk" if float(st.get("patk", 0.0)) >= float(st.get("matk", 0.0)) else "matk"
			if float(st.get(a, 0.0)) > 0.0:
				return a
		elif float(st.get(c, 0.0)) > 0.0:
			return String(c)
	var best := ""
	var bw := 0.0
	var lk := _level_k(power_level(item))
	for s in st:
		var w := stat_weight(slot, String(s), float(st[s]), lk)
		if w > bw and not PCT_OF.has(String(s)):
			bw = w
			best = String(s)
	return best


## Lignes de statistiques : [{k, name, val, bonus, aff, w, pct}] (valeur finale, écart dû à la qualité et à
## l'amélioration, affixe hors type de base, poids, statistique en % fusionnée).
static func stat_rows(item: Dictionary) -> Array:
	var base := base_stats(item)
	var st := stats(item, false)
	var ref_item := item.duplicate()
	ref_item["quality"] = 1.0
	ref_item["upgrade"] = 0
	ref_item.erase("passive")
	var ref := stats(ref_item, false)
	var slot := String(item.get("slot", ""))
	var lk := _level_k(power_level(item))
	var rows: Array = []
	for pass_aff in [false, true]:
		for s in st:
			if base.has(s) == pass_aff:
				continue
			var pct: bool = s in PERCENT_STATS
			var bonus := float(st[s]) - float(ref.get(s, 0.0)) if not pass_aff else 0.0
			var shown := roundi(bonus * (100.0 if pct else 1.0))
			rows.append({"k": String(s), "name": String(STAT_NAMES.get(s, EXTRA_STAT_NAMES.get(s, s))),
				"val": ("%d %%" % roundi(float(st[s]) * 100.0)) if pct else fmt_num(roundi(float(st[s]))),
				"bonus": ("(%s%d%s)" % ["+" if bonus > 0 else "", shown, " %" if pct else ""]) if shown != 0 else "",
				"bonus_ok": bonus > 0, "aff": pass_aff, "w": stat_weight(slot, String(s), float(st[s]), lk), "pct": ""})
	# statistique en % et statistique plate du même nom : une seule ligne
	for pk in PCT_OF:
		var pi := rows.find_custom(func(r): return r.k == pk)
		var fi := rows.find_custom(func(r): return r.k == PCT_OF[pk])
		if pi >= 0 and fi >= 0:
			rows[fi]["pct"] = "+%s" % String(rows[pi].val)
			rows[fi]["w"] = float(rows[fi].w) + float(rows[pi].w)
			rows.remove_at(pi)
	return rows


static func _row_text(r: Dictionary, size := 0) -> String:
	var bonus := ("  [color=%s]%s[/color]" % ["#7fe08a" if r.bonus_ok else "#ff7a7a", r.bonus]) if r.bonus != "" else ""
	var pct := ("  [color=#9fd0ff]%s[/color]" % r.pct) if r.pct != "" else ""
	var name_col := "#9fd0ff" if r.aff else "#e6e4ee"
	if size > 0:
		return "[font_size=%d][b]%s[/b][/font_size]  [color=%s]%s[/color]%s%s" % [size, r.val, name_col, r.name, bonus, pct]
	return "[color=%s]%s[/color]  [b]%s[/b]%s%s" % [name_col, r.name, r.val, bonus, pct]


## Bloc d'une panoplie : titre avec le nombre de pièces portées, puis les paliers (tous, ou seulement le prochain).
static func _set_block(sid: String, title: String, detailed: bool) -> Array:
	var tiers := set_tiers(sid)
	if tiers.is_empty():
		return []
	var worn := int(set_counts(Profile.equipped).get(sid, 0))
	var sc := SET_COLOR.to_html(false)
	var out := ["", "[color=#%s]◆ %s  [b]%d / %d[/b][/color]" % [sc, title, worn, int(tiers.max())]]
	var shown_next := false
	for n in tiers:
		var active: bool = worn >= int(n)
		if not detailed:
			if active or shown_next:
				continue
			shown_next = true
		out.append("[color=#%s]%d pièces : %s[/color]" % [sc if active else "8a86a0", n, " ; ".join(bonus_lines(set_bonus(sid, n)))])
	if detailed:
		var aw: Dictionary = set_def(sid).get("awake", {})
		for n in aw:
			var on := worn >= int(n) and awakened_count(Profile.equipped, sid) >= int(n)
			out.append("[color=#%s]%d pièces éveillées : %s[/color]" % [sc if on else "8a86a0", int(n), " ; ".join(bonus_lines(aw[n]))])
	return out


## Pièce portée dans [param slot] telle qu'elle compte pour le héros : en Survie, avec le bonus d'enclume de
## l'emplacement ajouté à son +N (copie ; la pièce d'origine ne change pas).
static func anvil_applied(item: Dictionary, slot: String) -> Dictionary:
	if item.is_empty() or not (Run.active and Run.survival and Run.slot_bonus.has(slot)):
		return item
	var it := item.duplicate()
	it["upgrade"] = Run.slot_upgrade(int(item.get("upgrade", 0)), slot)
	it["anvil"] = int(Run.slot_bonus.get(slot, 0))
	return it


## Nom en tête de carte : pour une pièce de panoplie, sans le nom de la panoplie entre parenthèses (il est
## écrit plus bas, avec le nombre de pièces portées).
static func card_name(item: Dictionary) -> String:
	var n := display_name(item)
	if item.has("set") and n.ends_with(")") and n.contains(" ("):
		return n.substr(0, n.rfind(" (")).strip_edges()
	return n


## Carte d'un objet en BBCode. [param detailed] faux : la carte courte (statistique principale, 5 lignes,
## passif, gemmes, panoplie) ; vrai : tout (bonus d'amélioration, paliers de panoplie, puissance de la pièce).
static func describe(item: Dictionary, detailed := true) -> String:
	var r: Dictionary = RARITIES[clampi(int(item.get("rarity", 0)), 0, RARITIES.size() - 1)]
	var col := color_of(item).to_html(false)
	var icon := String(item.get("icon", ""))
	var slot := String(item.get("slot", ""))
	var q := float(item.get("quality", 1.0))
	var up := int(item.get("upgrade", 0))
	var lvl := int(item.get("level", 0))
	var lines := ["%s[font_size=21][b][color=#%s]%s[/color][/b][/font_size]" % [
			"[img=52x52]%s[/img]  " % icon if icon != "" else "", col, card_name(item)],
		"[color=#%s]%s[/color] · %s%s" % [col, ("Éveillé" if item.get("awakened", false) else r.name), _weapon_or_slot(item),
			(" · niveau %d" % lvl) if lvl > 0 else ""]]
	var bits: PackedStringArray = []
	if slot != "trophy":
		bits.append("[color=#ffd76a][b]PE %s[/b][/color]" % GearPower.fmt(GearPower.item_power(item)))
	bits.append("Qualité [color=%s]%d %%[/color]" % ["#7fe08a" if q >= 1.0 else "#ff9a7a", roundi(q * 100.0)])
	lines.append(" · ".join(bits))
	lines.append(SEPARATOR)
	# statistique principale en gros, puis les lignes secondaires
	var rows := stat_rows(item)
	var main := main_stat_key(item, stats(item, false))
	var mi := rows.find_custom(func(x): return x.k == main)
	if mi >= 0:
		lines.append(_row_text(rows[mi], 30))
		rows.remove_at(mi)
	var hidden := 0
	if not detailed and rows.size() > CARD_ROWS:
		var order := range(rows.size())
		order.sort_custom(func(a, b): return float(rows[a].w) > float(rows[b].w))
		var keep := order.slice(0, CARD_ROWS)
		var kept: Array = []
		for i in rows.size():
			if i in keep:
				kept.append(rows[i])
		hidden = rows.size() - kept.size()
		rows = kept
	for row in rows:
		lines.append(_row_text(row))
	if hidden > 0:
		lines.append("[color=#8a86a0]+ %d autre%s statistique%s[/color]" % [hidden, "s" if hidden > 1 else "", "s" if hidden > 1 else ""])
	if item.has("passive"):
		lines.append("")
		# passif d'Eden : son nom d'origine est un libellé anglais sans intérêt (souvent le nom de la pièce), seul l'effet est écrit
		if item.passive.has("eden") or String(item.passive.get("name", "")) == "":
			lines.append("[color=#ffd76a]✶ Passif : %s[/color]" % item.passive.get("desc", ""))
		else:
			lines.append("[color=#ffd76a]✶ Passif — %s : %s[/color]" % [item.passive.get("name", ""), item.passive.get("desc", "")])
	if item.has("sv_passives"):  # Survivant : passif fixe, puis ceux des paliers +6 / +8 / +10
		lines.append("")
		for l in SurvivorGear.passive_lines(item):
			lines.append("[color=#ffd76a]✶ %s[/color]" % l)
		if SurvivorGear.item_locked(item):
			lines.append("[color=#8a86a0]%s[/color]" % SurvivorGear.LOCK_TEXT)
	# joaillerie et forge (Craft)
	var extra_lines: Array = []
	var rolls: Array = item.get("up_rolls", [])
	if detailed and not rolls.is_empty():
		var acc := {}
		for rl in rolls:
			acc[rl[0]] = float(acc.get(rl[0], 0.0)) + float(rl[1])
		var parts: PackedStringArray = []
		for k in acc:
			parts.append(stat_text(k, acc[k]))
		extra_lines.append("[color=#ffcf6b]Bonus d'amélioration : %s[/color]" % ", ".join(parts))
	var sockets: Array = item.get("sockets", [])
	for i in sockets.size():
		var g = sockets[i]
		if g is Dictionary:
			var key := Craft.gem_key(String(g.type), int(g.tier))
			extra_lines.append("[img=18x18]%s[/img] [color=#ff9ad0]%s : %s[/color]" % [Craft.icon(key), Craft.label(key), Craft._stats_text(Craft.gem_stats(g))])
		else:
			extra_lines.append("[color=#8a86a0]◇ Emplacement de gemme vide[/color]")
	if item.has("enchant"):
		var e: Dictionary = item.enchant
		extra_lines.append("[color=#8fd8ff]✦ %s niv. %d : %s[/color]" % [Craft.ENCHANTS.get(String(e.type), {}).get("name", "?"), int(e.lv), Craft._stats_text(Craft.enchant_stats(e))])
	if not extra_lines.is_empty():
		lines.append("")
		lines.append_array(extra_lines)
	# panoplies : celle de la pièce, puis l'archétype de donjon
	var sid := String(item.get("set", ""))
	var sdef := set_def(sid)
	if not sdef.is_empty():
		lines.append_array(_set_block(sid, "Panoplie %s" % sdef.name, detailed))
	var arch := String(item.get("archetype", ""))
	if SETS.has(arch):
		lines.append_array(_set_block(arch, "Panoplie de donjon · %s" % SETS[arch].name, detailed))
	if detailed:
		var foot: Array = []
		if int(item.get("anvil", 0)) > 0:
			foot.append("Enclume de la run : +%d" % int(item.anvil))
		if up < MAX_UPGRADE and not Run.active and not is_unique(item):
			foot.append("Prochaine amélioration : %d %% de réussite" % roundi(Craft.success_chance(item) * 100))
		if item.has("eden"):
			var cap := power_cap(item)
			foot.append("Niveau de puissance %d%s" % [power_level(item), "" if cap >= 999 or not Run.active else " (suit ton niveau, plafond %d)" % cap])
		if not foot.is_empty():
			lines.append("")
			for f in foot:
				lines.append("[color=#8a86a0]%s[/color]" % f)
	return "\n".join(lines)
