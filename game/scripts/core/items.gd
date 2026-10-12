class_name Items
extends RefCounted
## Équipement (voir DESIGN.md) :
## - chaque objet a un type de base (stats orientées : katana = physique...) ;
## - à la création, un jet de qualité entre 90 % et 120 % des stats de base,
##   et des affixes tirés dans une fourchette selon la rareté ;
## - amélioration +1 → +10 : +10 % de stats de base par niveau, et aux paliers
##   +4, +6, +8, +10 une stat aléatoire est renforcée (ou un affixe ajouté) ;
## - désassemblage → matériaux, vente → or.

const SLOTS := ["weapon", "head", "chest", "legs", "gloves", "boots", "back"]
const SLOT_NAMES := {
	"weapon": "Arme", "head": "Tête", "chest": "Torse", "legs": "Jambes",
	"gloves": "Gants", "boots": "Bottes", "back": "Cape",
}
## Types de base : nom, stats de base (niveau 1, qualité 100 %).
const BASES := {
	"weapon": {"name": "Katana", "stats": {"atk": 14.0, "crit": 0.02}},
	"head": {"name": "Kabuto", "stats": {"hp": 35.0, "def": 2.0}},
	"chest": {"name": "Dō", "stats": {"hp": 60.0, "def": 4.0}},
	"legs": {"name": "Hakama", "stats": {"hp": 45.0, "def": 3.0}},
	"gloves": {"name": "Kote", "stats": {"atk": 5.0, "atk_speed": 0.02}},
	"boots": {"name": "Suneate", "stats": {"hp": 20.0, "move_speed": 0.04}},
	"back": {"name": "Haori", "stats": {"hp": 30.0, "crit": 0.02}},
}
const RARITIES := [
	{"name": "Commun", "color": Color(0.85, 0.85, 0.85), "affixes": 0},
	{"name": "Magique", "color": Color(0.45, 0.7, 1.0), "affixes": 1},
	{"name": "Rare", "color": Color(1.0, 0.85, 0.3), "affixes": 2},
	{"name": "Épique", "color": Color(0.8, 0.45, 1.0), "affixes": 3},
]
const STAT_NAMES := {
	"atk": "Attaque", "hp": "PV", "def": "Défense", "crit": "Critique",
	"crit_dmg": "Dégâts critiques", "atk_speed": "Vitesse d'attaque",
	"move_speed": "Vitesse", "cdr": "Recharge", "lifesteal": "Vol de vie",
}
const PERCENT_STATS := ["crit", "crit_dmg", "atk_speed", "move_speed", "cdr", "lifesteal"]
## Fourchettes des affixes (niveau 1 pour les stats plates).
const AFFIX_RANGES := {
	"atk": [3.0, 7.0], "hp": [25.0, 50.0], "def": [2.0, 4.0],
	"crit": [0.02, 0.05], "crit_dmg": [0.08, 0.18], "atk_speed": [0.03, 0.07],
	"move_speed": [0.02, 0.04], "cdr": [0.02, 0.05], "lifesteal": [0.01, 0.02],
}
const MAX_UPGRADE := 10
const MILESTONES := [4, 6, 8, 10]
const MATERIALS := {"fragment": "Fragments", "essence": "Essences", "crystal": "Cristaux"}
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
static func generate(level: int, luck := 0.0, slot := "", class_id := "samurai", min_rarity := 0) -> Dictionary:
	if slot == "":
		slot = SLOTS.pick_random()
	var roll := randf() + luck
	var rarity := 0
	if roll > 1.15:
		rarity = 3
	elif roll > 0.92:
		rarity = 2
	elif roll > 0.6:
		rarity = 1
	rarity = maxi(rarity, min_rarity)
	var item := {
		"uid": "%d_%d" % [Time.get_ticks_usec(), randi() % 100000],
		"slot": slot, "level": level, "rarity": rarity,
		"quality": snappedf(randf_range(0.9, 1.2), 0.01),
		"upgrade": 0,
		"affixes": {},
		"name": "%s %s" % [BASES[slot].name, ADJECTIVES.pick_random()],
	}
	if slot == "weapon":
		var weapons: Array = GameData.class_data(class_id).get("weapons", [])
		if not weapons.is_empty():
			var w: Dictionary = weapons[mini(rarity, weapons.size() - 1)]
			item["weapon"] = w.code
			item["icon"] = w.icon
	if not item.has("icon"):
		var list: Array = icons().get(slot, [])
		item["icon"] = list[(level * 3 + rarity * 7 + randi() % 4) % maxi(list.size(), 1)] if not list.is_empty() else ""
	var pool := AFFIX_RANGES.keys()
	pool.shuffle()
	for i in int(RARITIES[rarity].affixes):
		_add_affix(item, pool[i])
	return item


static func _level_k(level: int) -> float:
	return pow(1.08, level - 1)


static func _add_affix(item: Dictionary, stat: String) -> void:
	var r: Array = AFFIX_RANGES[stat]
	var v := randf_range(r[0], r[1])
	if not stat in PERCENT_STATS:
		v *= _level_k(int(item.level))
	item.affixes[stat] = float(item.affixes.get(stat, 0.0)) + v


## Statistiques finales : base × niveau × qualité × amélioration + affixes.
static func stats(item: Dictionary) -> Dictionary:
	var out := {}
	var base: Dictionary = BASES.get(item.get("slot", "weapon"), BASES.weapon).stats
	var k := _level_k(int(item.level)) * float(item.get("quality", 1.0)) * (1.0 + 0.1 * int(item.get("upgrade", 0)))
	for s in base:
		out[s] = float(base[s]) * (k if not s in PERCENT_STATS else float(item.get("quality", 1.0)) * (1.0 + 0.1 * int(item.get("upgrade", 0))))
	var aff: Dictionary = item.get("affixes", {})
	for s in aff:
		out[s] = out.get(s, 0.0) + float(aff[s])
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


static func upgrade_cost(item: Dictionary) -> Dictionary:
	var up := int(item.get("upgrade", 0))
	var cost := {"gold": int(20.0 * pow(up + 1, 1.5) * (1.0 + int(item.level) / 5.0)), "fragment": 3 * (up + 1)}
	if up >= 4:
		cost["essence"] = up - 3
	if up >= 7:
		cost["crystal"] = 1
	return cost


static func disassemble_yield(item: Dictionary) -> Dictionary:
	var r := int(item.rarity)
	var up := int(item.get("upgrade", 0))
	var out := {"fragment": (2 + int(item.level) / 3) * (r + 1) + up * 2}
	if r >= 2:
		out["essence"] = r - 1 + up / 3
	if r == 3:
		out["crystal"] = 1 + up / 5
	return out


static func sell_price(item: Dictionary) -> int:
	return int(5 * (int(item.level) + 1) * (int(item.rarity) + 1) * (1.0 + 0.2 * int(item.get("upgrade", 0))))


static func buy_price(item: Dictionary) -> int:
	return sell_price(item) * 4


static func display_name(item: Dictionary) -> String:
	var up := int(item.get("upgrade", 0))
	return ("+%d " % up if up > 0 else "") + String(item.name)


static func stat_text(stat: String, value) -> String:
	var n: String = STAT_NAMES.get(stat, stat)
	if stat in PERCENT_STATS:
		return "+%d %% %s" % [roundi(float(value) * 100.0), n]
	return "+%d %s" % [roundi(float(value)), n]


static func describe(item: Dictionary) -> String:
	var r: Dictionary = RARITIES[int(item.rarity)]
	var lines := ["[color=#%s]%s[/color]" % [Color(r.color).to_html(false), display_name(item)],
		"%s · %s · niveau %d" % [SLOT_NAMES[item.slot], r.name, int(item.level)],
		"Qualité %d %%" % roundi(float(item.get("quality", 1.0)) * 100.0)]
	var base: Dictionary = BASES.get(item.slot, {}).get("stats", {})
	var st := stats(item)
	for s in st:
		var tag := "" if base.has(s) and not item.affixes.has(s) else ("  [color=#9fd0ff](affixe)[/color]" if not base.has(s) else "")
		lines.append(stat_text(s, st[s]) + tag)
	var up := int(item.get("upgrade", 0))
	if up < MAX_UPGRADE:
		var next_m := -1
		for m in MILESTONES:
			if m > up:
				next_m = m
				break
		if next_m > 0:
			lines.append("[color=#aaaaaa]Palier +%d : une stat renforcée[/color]" % next_m)
	return "\n".join(lines)
