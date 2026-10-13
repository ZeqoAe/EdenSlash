class_name Craft
extends RefCounted
## Joaillerie et forge, comme dans Eden Eternal :
## - emplacements de gemmes (2 max) percés aux ciseaux de sertissage, gemmes serties ;
## - parchemins d'enchantement (un enchantement par objet, niveau adapté à l'objet) ;
## - amélioration à risque : chances de réussite décroissantes, stat aléatoire gagnée à
##   chaque réussite, échec qui fait redescendre l'objet à partir de +6, pierres de chance
##   (+10 % de réussite chacune, 3 max) et de protection (empêche la perte de niveau).
## Les consommables sont rangés dans Profile.bag (clé -> quantité), butin de la run.

const MAX_SOCKETS := 2
const SECOND_SOCKET_CHANCE := 0.7

const GEMS := {
	"ruby": {"name": "Rubis", "stat": "str", "base": 4.0},
	"emerald": {"name": "Émeraude", "stat": "agi", "base": 4.0},
	"sapphire": {"name": "Saphir", "stat": "int", "base": 4.0},
	"pearl": {"name": "Perle", "stat": "wis", "base": 4.0},
	"topaz": {"name": "Topaze", "stat": "lck", "base": 4.0},
	"garnet": {"name": "Grenat", "stat": "hp", "base": 40.0},
	"onyx": {"name": "Onyx", "stat": "def", "base": 3.0},
	"amethyst": {"name": "Améthyste", "stat": "crit", "base": 0.01},
}
const GEM_TIERS := ["brut", "taillé", "pur", "parfait", "royal"]
const GEM_MULT := [1.0, 2.0, 3.5, 5.5, 8.0]

## Enchantements d'Eden (« Basic Enchant: … Lv1-4 ») : effets par niveau de parchemin.
const ENCHANTS := {
	"swift_song": {"name": "Chant rapide", "eden": "Swift Song", "stats": {"atk_speed": 0.02}, "armor": false},
	"violence": {"name": "Violence", "eden": "Violence", "stats": {"patk": 6.0}, "armor": false},
	"optimize": {"name": "Optimisation", "eden": "Optimize", "stats": {"matk": 6.0}, "armor": false},
	"muscle": {"name": "Explosion musculaire", "eden": "Muscle Explosion", "stats": {"str": 4.0}, "armor": false},
	"slightness": {"name": "Légèreté", "eden": "Slightness", "stats": {"agi": 3.0, "move_speed": 0.01}, "armor": true},
	"comprehension": {"name": "Compréhension", "eden": "Comprehension", "stats": {"int": 3.0, "wis": 3.0}, "armor": true},
	"rehab": {"name": "Rééducation", "eden": "Rehab", "stats": {"hp": 50.0}, "armor": true},
	"recovery": {"name": "Récupération", "eden": "Recovery", "stats": {"hp": 25.0, "lifesteal": 0.005}, "armor": true},
}
const MAX_SCROLL_LV := 5

## Chances de réussite pour atteindre +1 … +10.
const UPGRADE_CHANCE := [1.0, 1.0, 1.0, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3]
const LUCK_BONUS := 0.1
const MAX_LUCK := 3
const DOWNGRADE_FROM := 6  # un échec vers +6 ou plus fait perdre un niveau (sauf protection)
const UPGRADE_POOL_WEAPON := ["patk", "matk", "crit", "atk_speed", "str", "agi", "int"]
const UPGRADE_POOL_ARMOR := ["hp", "def", "str", "agi", "int", "wis", "lck"]
const UPGRADE_ROLL := {
	"patk": [2.0, 5.0], "matk": [2.0, 5.0], "hp": [15.0, 35.0], "def": [1.0, 3.0],
	"str": [1.0, 3.0], "agi": [1.0, 3.0], "int": [1.0, 3.0], "wis": [1.0, 3.0], "lck": [1.0, 3.0],
	"crit": [0.005, 0.015], "atk_speed": [0.005, 0.015],
}


# --- consommables ---------------------------------------------------------------------------
static func gem_key(type: String, tier: int) -> String:
	return "gem:%s:%d" % [type, tier]


static func scroll_key(type: String, lv: int) -> String:
	return "scroll:%s:%d" % [type, lv]


static func label(key: String) -> String:
	var p := key.split(":")
	match p[0]:
		"gem":
			return "%s %s" % [GEMS[p[1]].name, GEM_TIERS[int(p[2])]]
		"scroll":
			return "Parchemin : %s Lv%d" % [ENCHANTS[p[1]].name, int(p[2])]
		"drill":
			return "Ciseaux de sertissage"
		"luck":
			return "Pierre de chance"
		"protect":
			return "Pierre de protection"
	return key


static func describe_key(key: String) -> String:
	var p := key.split(":")
	match p[0]:
		"gem":
			return "Gemme à sertir : %s." % _stats_text(gem_stats({"type": p[1], "tier": int(p[2])}))
		"scroll":
			var e: Dictionary = ENCHANTS[p[1]]
			return "Enchante %s : %s. Objet de niveau %d minimum." % ["une armure" if e.armor else "une arme ou des gants",
				_stats_text(enchant_stats({"type": p[1], "lv": int(p[2])})), scroll_min_level(int(p[2]))]
		"drill":
			return "Perce un emplacement de gemme (2 max ; le 2e réussit à 70 %)."
		"luck":
			return "+10 % de chances de réussite d'amélioration (3 max par tentative)."
		"protect":
			return "Empêche l'objet de perdre un niveau si l'amélioration échoue."
	return ""


static func icon(key: String) -> String:
	var p := key.split(":")
	var craft: Dictionary = Items.icons().get("craft", {})
	match p[0]:
		"gem":
			return String(craft.get(p[1], ""))
		"scroll":
			return String(craft.get("scroll%d" % (ENCHANTS.keys().find(p[1]) % 8), ""))
	return String(craft.get(p[0], ""))


## Rareté affichée (couleur) d'un consommable.
static func rarity(key: String) -> int:
	var p := key.split(":")
	if p[0] == "gem":
		return mini(int(p[2]), 3)
	if p[0] == "scroll":
		return clampi(int(p[2]) - 1, 0, 3)
	return 2 if p[0] == "protect" else 1


# --- stats apportées ---------------------------------------------------------------------------
static func gem_stats(g: Dictionary) -> Dictionary:
	var d: Dictionary = GEMS.get(String(g.get("type", "")), {})
	if d.is_empty():
		return {}
	return {d.stat: float(d.base) * float(GEM_MULT[clampi(int(g.get("tier", 0)), 0, GEM_MULT.size() - 1)])}


static func enchant_stats(e: Dictionary) -> Dictionary:
	var d: Dictionary = ENCHANTS.get(String(e.get("type", "")), {})
	var out := {}
	for s in d.get("stats", {}):
		out[s] = float(d.stats[s]) * int(e.get("lv", 1))
	return out


## Stats ajoutées à un objet par ses gemmes, son enchantement et ses bonus d'amélioration.
static func extra_stats(item: Dictionary) -> Dictionary:
	var out := {}
	for g in item.get("sockets", []):
		if g is Dictionary:
			_merge(out, gem_stats(g))
	if item.has("enchant"):
		_merge(out, enchant_stats(item.enchant))
	var lk := pow(1.08, Items.power_level(item) - 1)
	for r in item.get("up_rolls", []):
		# [stat, valeur au niveau 1, palier] : les stats fixes suivent la puissance de l'objet
		var v := float(r[1]) * (lk if r.size() > 2 and not String(r[0]) in Items.PERCENT_STATS else 1.0)
		out[r[0]] = float(out.get(r[0], 0.0)) + v
	return out


static func _merge(into: Dictionary, add: Dictionary) -> void:
	for k in add:
		into[k] = float(into.get(k, 0.0)) + float(add[k])


static func _stats_text(st: Dictionary) -> String:
	var parts: PackedStringArray = []
	for s in st:
		parts.append(Items.stat_text(s, st[s]))
	return ", ".join(parts)


# --- sertissage ---------------------------------------------------------------------------------
## Perce un emplacement avec des ciseaux de sertissage. Renvoie un message.
static func drill(item: Dictionary) -> String:
	var sockets: Array = item.get("sockets", [])
	if sockets.size() >= MAX_SOCKETS:
		return "Déjà %d emplacements." % MAX_SOCKETS
	if not Profile.take_bag("drill"):
		return "Il faut des ciseaux de sertissage."
	if sockets.size() == 1 and randf() > SECOND_SOCKET_CHANCE:
		Profile.save_profile()
		return "Échec : les ciseaux se brisent, l'objet est intact."
	sockets.append(null)
	item["sockets"] = sockets
	Profile.save_profile()
	return "Emplacement percé (%d / %d)." % [sockets.size(), MAX_SOCKETS]


## Sertit la gemme [param key] dans l'emplacement [param slot] (l'ancienne gemme est détruite).
static func insert_gem(item: Dictionary, key: String, slot: int) -> String:
	var sockets: Array = item.get("sockets", [])
	if slot < 0 or slot >= sockets.size():
		return "Pas d'emplacement : perce-le d'abord."
	if not Profile.take_bag(key):
		return "Gemme introuvable."
	var p := key.split(":")
	var old = sockets[slot]
	sockets[slot] = {"type": p[1], "tier": int(p[2])}
	Profile.save_profile()
	return "%s sertie%s." % [label(key), " (l'ancienne gemme est détruite)" if old is Dictionary else ""]


# --- enchantement --------------------------------------------------------------------------------
## Niveau d'objet minimum pour un parchemin Lv[param lv].
static func scroll_min_level(lv: int) -> int:
	return maxi(1, (lv - 1) * 10)


## Niveau de parchemin adapté à un niveau de monstre ou d'objet.
static func scroll_level_for(level: int) -> int:
	return clampi(1 + level / 10, 1, MAX_SCROLL_LV)


static func can_enchant(item: Dictionary, key: String) -> String:
	var p := key.split(":")
	var e: Dictionary = ENCHANTS.get(p[1], {})
	var armor: bool = item.slot != "weapon" and item.slot != "gloves"
	if bool(e.get("armor", false)) != armor:
		return "Ce parchemin s'applique %s." % ("aux armures" if e.get("armor", false) else "aux armes et aux gants")
	if mini(Items.power_cap(item), 999) < scroll_min_level(int(p[2])):  # niveau de l'objet (pas sa puissance du moment)
		return "Objet de niveau %d minimum." % scroll_min_level(int(p[2]))
	return ""


static func apply_scroll(item: Dictionary, key: String) -> String:
	var why := can_enchant(item, key)
	if why != "":
		return why
	if not Profile.take_bag(key):
		return "Parchemin introuvable."
	var p := key.split(":")
	var replaced := item.has("enchant")
	item["enchant"] = {"type": p[1], "lv": int(p[2])}
	Profile.save_profile()
	return "Enchantement %s Lv%d appliqué%s." % [ENCHANTS[p[1]].name, int(p[2]), " (remplace l'ancien)" if replaced else ""]


# --- amélioration à risque -----------------------------------------------------------------------
## Chance de réussite pour l'amélioration suivante avec [param luck] pierres de chance.
static func success_chance(item: Dictionary, luck: int) -> float:
	var up := int(item.get("upgrade", 0))
	if up >= Items.MAX_UPGRADE:
		return 0.0
	return minf(1.0, float(UPGRADE_CHANCE[up]) + LUCK_BONUS * clampi(luck, 0, MAX_LUCK))


## Ce qu'un échec coûterait (texte).
static func failure_text(item: Dictionary) -> String:
	var target := int(item.get("upgrade", 0)) + 1
	if float(UPGRADE_CHANCE[target - 1]) >= 1.0:
		return "aucun risque"
	if target >= DOWNGRADE_FROM:
		return "matériaux perdus et l'objet redescend à +%d (sauf pierre de protection)" % maxi(0, target - 2)
	return "matériaux perdus"


## Tentative d'amélioration : {ok, text, stat, value}. Les coûts sont payés par l'appelant.
static func upgrade(item: Dictionary, luck: int, protect: bool) -> Dictionary:
	var chance := success_chance(item, luck)
	var target := int(item.get("upgrade", 0)) + 1
	if randf() < chance:
		item.upgrade = target
		if not target in Items.MILESTONES:
			# entre les paliers : +10 % des stats de l'objet, pas de stat bonus
			return {"ok": true, "stat": "", "value": 0.0, "text": "Réussite ! +%d : stats de l'objet +10 %%" % target}
		var roll := _upgrade_roll(item, target)
		var rolls: Array = item.get("up_rolls", [])
		rolls.append(roll)
		item["up_rolls"] = rolls
		var shown := float(roll[1]) * (1.0 if String(roll[0]) in Items.PERCENT_STATS else pow(1.08, Items.power_level(item) - 1))
		return {"ok": true, "stat": roll[0], "value": shown,
			"text": "Réussite ! +%d : stat bonus %s" % [target, Items.stat_text(roll[0], shown)]}
	if target >= DOWNGRADE_FROM and not protect and int(item.upgrade) > 0:
		var lost := int(item.upgrade)
		item.upgrade = lost - 1
		# un palier perdu (+4, +6…) emporte sa stat bonus
		var rolls: Array = item.get("up_rolls", [])
		for i in range(rolls.size() - 1, -1, -1):
			if (rolls[i].size() > 2 and int(rolls[i][2]) == lost) or (rolls[i].size() <= 2 and i == rolls.size() - 1):
				rolls.remove_at(i)
				break
		return {"ok": false, "text": "Échec… l'objet redescend à +%d." % int(item.upgrade)}
	return {"ok": false, "text": "Échec. %s" % ("La pierre de protection a préservé l'objet." if protect and target >= DOWNGRADE_FROM else "L'objet est intact.")}


## Stat bonus aléatoire gagnée au palier +[param target] (+4, +6, +8, +10) : [stat, valeur au
## niveau 1 (suit la puissance de l'objet), palier]. Aléatoire pour qu'un objet parfait soit rare.
static func _upgrade_roll(item: Dictionary, target: int) -> Array:
	var pool: Array = UPGRADE_POOL_WEAPON if item.slot in ["weapon", "gloves"] else UPGRADE_POOL_ARMOR
	var stat: String = pool.pick_random()
	var r: Array = UPGRADE_ROLL[stat]
	var v := randf_range(r[0], r[1]) * 2.0
	return [stat, snappedf(v, 0.001 if stat in Items.PERCENT_STATS else 0.1), target]


# --- butin ----------------------------------------------------------------------------------------
## Consommable aléatoire adapté au niveau ([param bonus] : coffres rares, élites, boss).
static func random_loot(level: int, bonus := 0) -> String:
	var r := randf() * 100.0
	var tier := clampi(level / 8 + bonus + (1 if randf() < 0.25 else 0) - (1 if randf() < 0.3 else 0), 0, GEM_TIERS.size() - 1)
	if r < 35.0:
		return gem_key(GEMS.keys().pick_random(), tier)
	if r < 60.0:
		return scroll_key(ENCHANTS.keys().pick_random(), clampi(scroll_level_for(level) + (1 if bonus > 0 and randf() < 0.3 else 0), 1, MAX_SCROLL_LV))
	if r < 75.0:
		return "drill"
	if r < 90.0:
		return "luck"
	return "protect"


## Objet de butin (LootDrop) représentant un consommable.
static func loot_item(key: String) -> Dictionary:
	return {"consumable": key, "name": label(key), "icon": icon(key), "rarity": rarity(key)}
