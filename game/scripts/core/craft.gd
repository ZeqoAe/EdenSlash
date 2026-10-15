class_name Craft
extends RefCounted
## Joaillerie et forge, comme dans Eden Eternal :
## - emplacements de gemmes (2 max) percés aux ciseaux de sertissage, gemmes serties ;
## - formules d'enchantement d'Eden (« Enchant-Muscle Explosion Lv4 » : un enchantement par
##   objet, niveau d'objet minimum 25 à 70 selon le niveau de la formule) ;
## - fortification +1 → +10 : chaque tentative consomme un parchemin de puissance (armes) ou de
##   garde (armures) d'un niveau au moins égal à celui de l'objet, plus de l'or ; réussite
##   assurée jusqu'à +2 à +5 selon le parchemin, puis chances décroissantes ; un échec vers +6
##   ou plus fait redescendre l'objet d'un niveau ;
## - pierres de sûreté d'Eden (une par tentative, consommée quel que soit le résultat) : elles
##   protègent toutes l'objet et ajoutent +5 % à +100 % de réussite ;
## - parchemin béni (création du jeu) : une tentative gratuite (ni parchemin ni or) et protégée.
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

## Formules d'enchantement d'Eden (« Enchant-… Lv1-9 », icônes d'Eden). [param pts] : valeurs
## d'Eden par niveau (colonnes de c_item), [param k] : conversion en stat du jeu.
const ENCHANT_PTS := {
	"a": [7, 9, 10, 11, 12, 13, 14, 16, 17],
	"b": [10, 13, 14, 16, 17, 19, 20, 23, 25],
	"c": [7, 10, 12, 15, 17, 19, 22, 27, 31],
}
const ENCHANTS := {
	"swift_song": {"name": "Chant rapide", "eden": "Swift Song", "stat": "move_speed", "pts": "a", "k": 0.002, "icon": "i00322", "eden_stat": "Move SPD"},
	"violence": {"name": "Violence", "eden": "Violence", "stat": "atk_speed", "pts": "b", "k": 0.002, "icon": "i00323", "eden_stat": "ATK SPD"},
	"optimize": {"name": "Optimisation", "eden": "Optimize", "stat": "dmg_pct", "pts": "b", "k": 0.002, "icon": "i00405", "eden_stat": "DMG"},
	"slightness": {"name": "Légèreté", "eden": "Slightness", "stat": "eva", "pts": "a", "k": 0.0015, "icon": "i00406", "eden_stat": "Dodge"},
	"muscle": {"name": "Explosion musculaire", "eden": "Muscle Explosion", "stat": "crit", "pts": "a", "k": 0.0015, "icon": "i00419", "eden_stat": "CRIT Rate"},
	"comprehension": {"name": "Compréhension", "eden": "Comprehension", "stat": "crit_dmg", "pts": "a", "k": 0.004, "icon": "i00418", "eden_stat": "CRIT DMG"},
	"rehab": {"name": "Rééducation", "eden": "Rehab", "stat": "def_pct", "pts": "c", "k": 0.0015, "icon": "i00409", "eden_stat": "DEF"},
	"recovery": {"name": "Récupération", "eden": "Recovery", "stat": "cdr", "pts": "c", "k": 0.001, "icon": "i00410", "eden_stat": "Cooldown"},
}
## Niveau d'objet minimum de chaque niveau de formule (Eden : Lv1 = 25 … Lv9 = 70).
const ENCHANT_MIN_LEVEL := [25, 35, 40, 45, 50, 55, 60, 65, 70]
const MAX_SCROLL_LV := 9

## Parchemins de fortification d'Eden : puissance (armes), garde (armures, bijoux, trophées).
const FORTIFY := {
	"power": {"name": "Parchemin de puissance", "eden": "Power Scroll", "icon": "i00327", "what": "les armes"},
	"guard": {"name": "Parchemin de garde", "eden": "Guard Scroll", "icon": "i00324", "what": "les armures et accessoires"},
}
const FORTIFY_LEVELS := [20, 30, 40, 50, 60, 70, 80, 90, 100]

## Pierres de sûreté d'Eden : [from, to] = niveaux d'amélioration actuels acceptés.
const STONES := {
	"safety": {"name": "Pierre de sûreté", "eden": "Safety Stone", "bonus": 0.05, "from": 2, "to": 9, "rarity": 1, "icon": "i00528"},
	"lucky": {"name": "Pierre de sûreté chanceuse", "eden": "Lucky Safety Stone", "bonus": 0.10, "from": 2, "to": 9, "rarity": 2, "icon": "i00529"},
	"citrine": {"name": "Pierre halcyon citrine", "eden": "Citrine Halcyon Safety Stone", "bonus": 0.50, "from": 2, "to": 9, "rarity": 3, "icon": "i01202"},
	"viridian": {"name": "Pierre halcyon viridienne", "eden": "Viridian Halcyon Safety Stone", "bonus": 0.75, "from": 3, "to": 6, "rarity": 3, "icon": "i01009"},
	"ultramarine": {"name": "Pierre halcyon outremer", "eden": "Ultramarine Halcyon Safety Stone", "bonus": 0.75, "from": 7, "to": 8, "rarity": 3, "icon": "i01010"},
	"coral": {"name": "Pierre halcyon corail", "eden": "Coral Halcyon Safety Stone", "bonus": 0.75, "from": 9, "to": 9, "rarity": 3, "icon": "i01011"},
	"sublime": {"name": "Pierre sublime sanguine", "eden": "Sanguine Sublime Safety Stone", "bonus": 1.0, "from": 2, "to": 9, "rarity": 4, "icon": "i11145"},
}
## Parchemin béni (création du jeu) : tentative gratuite et protégée.
const BLESSED := "blessed"
const BLESSED_ICON := "i00311"

## Chances de réussite de base pour atteindre +1 … +10 (le parchemin assure les premiers).
const UPGRADE_CHANCE := [1.0, 1.0, 0.95, 0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3]
const DOWNGRADE_FROM := 6  # un échec vers +6 ou plus fait perdre un niveau (sauf pierre ou parchemin béni)
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


static func fortify_key(kind: String, lv: int) -> String:
	return "fortify:%s:%d" % [kind, lv]


static func stone_key(id: String) -> String:
	return "stone:" + id


## Anciennes clés (avant 0.1.41) : pierre de chance et pierre de protection.
static func migrate_key(key: String) -> String:
	return {"luck": "stone:lucky", "protect": "stone:safety"}.get(key, key)


static func migrate_bag(bag: Dictionary) -> Dictionary:
	var out := {}
	for k in bag:
		var nk := migrate_key(String(k))
		out[nk] = int(out.get(nk, 0)) + int(bag[k])
	return out


static func label(key: String) -> String:
	var p := key.split(":")
	match p[0]:
		"gem":
			return "%s %s" % [GEMS[p[1]].name, GEM_TIERS[int(p[2])]]
		"scroll":
			return "Enchantement : %s Lv%d" % [ENCHANTS[p[1]].name, int(p[2])]
		"fortify":
			return "%s Lv%d" % [FORTIFY[p[1]].name, int(p[2])]
		"stone":
			return String(STONES[p[1]].name)
		"blessed":
			return "Parchemin béni"
		"drill":
			return "Ciseaux de sertissage"
		"potion":
			return Potions.label(String(p[1]))
	return key


## Nom d'origine dans Eden (affiché en sous-titre).
static func eden_name(key: String) -> String:
	var p := key.split(":")
	match p[0]:
		"scroll":
			return "Enchant-%s Lv%d" % [ENCHANTS[p[1]].eden, int(p[2])]
		"fortify":
			return "%s Lv%d" % [FORTIFY[p[1]].eden, int(p[2])]
		"stone":
			return String(STONES[p[1]].eden)
	return ""


static func describe_key(key: String) -> String:
	var p := key.split(":")
	match p[0]:
		"gem":
			return "Gemme à sertir : %s." % _stats_text(gem_stats({"type": p[1], "tier": int(p[2])}))
		"scroll":
			var e: Dictionary = ENCHANTS[p[1]]
			var lv := int(p[2])
			return "Formule d'enchantement (%s).\n%s +%d : %s.\nS'applique à une pièce d'équipement de niveau %d ou plus (remplace l'enchantement en place)." % [
				eden_name(key), e.eden_stat, enchant_points(p[1], lv), _stats_text(enchant_stats({"type": p[1], "lv": lv})), enchant_min_level(lv)]
		"fortify":
			var lv := int(p[2])
			return "Fortifie %s de niveau %d ou moins (%s).\nRéussite assurée jusqu'à +%d. Ne sert que de +1 à +10.\nLe parchemin disparaît après la tentative." % [
				FORTIFY[p[1]].what, lv, eden_name(key), fortify_safe(p[1], lv)]
		"stone":
			var s: Dictionary = STONES[p[1]]
			var txt := "Protège l'objet pendant la fortification : il ne redescend pas en cas d'échec."
			if float(s.bonus) > 0.0:
				txt += "\nRéussite +%d %%." % roundi(float(s.bonus) * 100.0)
			txt += "\nUtilisable de +%d à +%d → +%d. Une pierre par tentative, détruite quel que soit le résultat." % [int(s.from), int(s.to), int(s.to) + 1]
			return txt
		"blessed":
			return "Création d'Eden Slash : une tentative de fortification sans parchemin ni or, et protégée (l'objet ne redescend pas). Peut s'accompagner d'une pierre de sûreté."
		"drill":
			return "Perce un emplacement de gemme (2 max ; le 2e réussit à 70 %)."
		"potion":
			var d: Dictionary = Potions.KINDS[p[1]]
			return "%s
Se boit en run : touche %s. Recharge de %d s. Gardée en cas de victoire ou d'extraction." % [d.desc, Settings.action_label("potion_1" if p[1] == "heal" else "potion_2", 1), int(Potions.COOLDOWN)]
	return ""


static func _icon_path(code: String) -> String:
	return "res://assets/ui/items/%s.png" % code


static func icon(key: String) -> String:
	var p := key.split(":")
	var craft: Dictionary = Items.icons().get("craft", {})
	match p[0]:
		"gem":
			return String(craft.get(p[1], ""))
		"scroll":
			return _icon_path(String(ENCHANTS[p[1]].icon))
		"fortify":
			return _icon_path(String(FORTIFY[p[1]].icon))
		"stone":
			return _icon_path(String(STONES[p[1]].icon))
		"blessed":
			return _icon_path(BLESSED_ICON)
		"potion":
			return Potions.icon_path(String(p[1]))
	return String(craft.get(p[0], ""))


## Rareté affichée (couleur) d'un consommable.
static func rarity(key: String) -> int:
	var p := key.split(":")
	match p[0]:
		"gem":
			return mini(int(p[2]), 3)
		"scroll":
			return clampi((int(p[2]) - 1) / 2, 0, 3)
		"fortify":
			return 1
		"stone":
			return int(STONES[p[1]].rarity)
		"blessed":
			return 4
		"potion":
			return 1
	return 1


# --- stats apportées ---------------------------------------------------------------------------
static func gem_stats(g: Dictionary) -> Dictionary:
	var d: Dictionary = GEMS.get(String(g.get("type", "")), {})
	if d.is_empty():
		return {}
	return {d.stat: float(d.base) * float(GEM_MULT[clampi(int(g.get("tier", 0)), 0, GEM_MULT.size() - 1)])}


## Survie : les valeurs PLATES des gemmes (force, PV, défense…) suivent le niveau du héros exactement comme
## les stats des pièces (×1,08 par niveau) : GEM_RUN_SHARE × 1,08^(niveau − 1), soit ×0,09 au niveau 1, ×0,27 au
## niveau 15, ×0,57 au 25, ×1,24 au 35. Une gemme royale de PV vaut alors environ la moitié des PV d'un torse
## +0 du même niveau, à tout niveau. (0.1.164 : ×1 au niveau 15, jusqu'à ×2 : mesure E6, deux gemmes royales par
## pièce triplaient la puissance d'un héros en carte 1, plus que l'écart de toutes les époques.) Hors Survie : valeur
## pleine (duels inchangés).
const GEM_RUN_SHARE := 0.09
static func gem_run_factor() -> float:
	if not (Run.active and Run.survival and Run.hero_level > 0):
		return 1.0
	return GEM_RUN_SHARE * pow(1.08, Run.hero_level - 1)


## Valeur d'Eden de la formule [param type] au niveau [param lv].
static func enchant_points(type: String, lv: int) -> int:
	var d: Dictionary = ENCHANTS.get(type, {})
	if d.is_empty():
		return 0
	var pts: Array = ENCHANT_PTS[d.pts]
	return int(pts[clampi(lv, 1, pts.size()) - 1])


static func enchant_stats(e: Dictionary) -> Dictionary:
	var type := String(e.get("type", ""))
	var d: Dictionary = ENCHANTS.get(type, {})
	if d.is_empty():
		return {}
	return {d.stat: snappedf(enchant_points(type, int(e.get("lv", 1))) * float(d.k), 0.0001)}


## Stats ajoutées à un objet par ses gemmes, son enchantement et ses bonus d'amélioration.
static func extra_stats(item: Dictionary) -> Dictionary:
	var out := {}
	var gk := gem_run_factor()
	for g in item.get("sockets", []):
		if g is Dictionary:
			var gs := gem_stats(g)
			if gk != 1.0:
				for s in gs:
					if not String(s) in Items.PERCENT_STATS:
						gs[s] = float(gs[s]) * gk
			_merge(out, gs)
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
	if Items.is_unique(item):
		return Items.UNIQUE_TEXT
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
	if Items.is_unique(item):
		return Items.UNIQUE_TEXT
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
## Niveau d'objet minimum pour une formule Lv[param lv].
static func enchant_min_level(lv: int) -> int:
	return int(ENCHANT_MIN_LEVEL[clampi(lv, 1, ENCHANT_MIN_LEVEL.size()) - 1])


## Ancien nom, gardé pour les appels existants.
static func scroll_min_level(lv: int) -> int:
	return enchant_min_level(lv)


## Niveau de formule le plus haut utilisable sur un objet (ou un monstre) de niveau [param level]
## (0 : aucun, sous le niveau 25).
static func scroll_level_for(level: int) -> int:
	var lv := 0
	for i in ENCHANT_MIN_LEVEL.size():
		if level >= int(ENCHANT_MIN_LEVEL[i]):
			lv = i + 1
	return lv


## Passe E6 : niveau de formule le plus haut qui tombe en Survie, par époque (I à IV). Les formules Lv8-9 restent
## le butin propre du Siège (et des coffres du joaillier de niveau 70 ou plus : Donjons Héroïques hauts et
## Mythiques, Ruée) : sans plafond, une carte d'époque IV en donnait une dizaine, plus qu'un Siège Mythique.
const SURVIVAL_SCROLL_MAX := [2, 4, 6, 7]


## Niveau de formule des fournitures tirées au niveau [param level] : plafonné en Survie (SURVIVAL_SCROLL_MAX).
static func loot_scroll_level(level: int) -> int:
	var slv := scroll_level_for(level)
	if Run.active and Run.survival:
		slv = mini(slv, int(SURVIVAL_SCROLL_MAX[clampi(Run.epoch, 1, SURVIVAL_SCROLL_MAX.size()) - 1]))
	return slv


static func _item_level(item: Dictionary) -> int:
	return mini(Items.power_cap(item), 999) if int(item.get("level", 0)) <= 0 else int(item.level)


static func can_enchant(item: Dictionary, key: String) -> String:
	if Items.is_unique(item):
		return Items.UNIQUE_TEXT
	var p := key.split(":")
	if not ENCHANTS.has(p[1]):
		return "Formule inconnue."
	var need := enchant_min_level(int(p[2]))
	if maxi(_item_level(item), mini(Items.power_cap(item), 999)) < need:  # niveau de l'objet (pas sa puissance du moment)
		return "Objet de niveau %d minimum." % need
	return ""


static func apply_scroll(item: Dictionary, key: String) -> String:
	var why := can_enchant(item, key)
	if why != "":
		return why
	if not Profile.take_bag(key):
		return "Formule introuvable."
	var p := key.split(":")
	var replaced := item.has("enchant")
	item["enchant"] = {"type": p[1], "lv": int(p[2])}
	Profile.save_profile()
	return "Enchantement %s Lv%d appliqué%s." % [ENCHANTS[p[1]].name, int(p[2]), " (remplace l'ancien)" if replaced else ""]


# --- fortification -----------------------------------------------------------------------------
static func fortify_kind(item: Dictionary) -> String:
	return "power" if String(item.get("slot", "")) == "weapon" else "guard"


## Niveau du parchemin nécessaire (le plus petit au moins égal au niveau de l'objet).
static func fortify_level_for(item: Dictionary) -> int:
	var lv := _item_level(item)
	for f in FORTIFY_LEVELS:
		if int(f) >= lv:
			return int(f)
	return int(FORTIFY_LEVELS[-1])


## Réussite assurée jusqu'à +N (Eden : garde +5 / +4 / +3, puissance +4 / +3 / +2).
static func fortify_safe(kind: String, lv: int) -> int:
	if kind == "power":
		return 4 if lv <= 30 else (3 if lv <= 50 else 2)
	return 5 if lv <= 30 else (4 if lv <= 70 else 3)


static func fortify_fits(item: Dictionary, key: String) -> bool:
	var p := key.split(":")
	return p.size() == 3 and p[0] == "fortify" and p[1] == fortify_kind(item) and int(p[2]) >= _item_level(item)


## Parchemin du sac utilisé pour la prochaine tentative : le plus petit qui convient ("" : aucun).
static func fortify_for(item: Dictionary) -> String:
	var best := ""
	for k in Profile.bag_keys("fortify:" + fortify_kind(item)):
		if fortify_fits(item, k) and (best == "" or int(k.split(":")[2]) < int(best.split(":")[2])):
			best = k
	return best


static func stone_usable(item: Dictionary, key: String) -> bool:
	var p := key.split(":")
	if p.size() != 2 or p[0] != "stone" or not STONES.has(p[1]):
		return false
	var up := int(item.get("upgrade", 0))
	return up >= int(STONES[p[1]].from) and up <= int(STONES[p[1]].to)


## Chance de réussite de la prochaine tentative avec la pierre [param stone] et le parchemin
## [param scroll] ("" : le parchemin qu'il faudrait ; BLESSED : parchemin béni).
static func success_chance(item: Dictionary, stone := "", scroll := "") -> float:
	var up := int(item.get("upgrade", 0))
	if up >= Items.MAX_UPGRADE:
		return 0.0
	var c := float(UPGRADE_CHANCE[up])
	if scroll == "":
		scroll = fortify_key(fortify_kind(item), fortify_level_for(item))
	var safe := 3
	if scroll.begins_with("fortify:"):
		var p := scroll.split(":")
		safe = fortify_safe(p[1], int(p[2]))
	if up + 1 <= safe:
		c = 1.0
	if stone != "" and stone_usable(item, stone):
		c += float(STONES[stone.split(":")[1]].bonus)
	return minf(1.0, c)


## Ce qu'un échec coûterait (texte).
static func failure_text(item: Dictionary, protected := false) -> String:
	var target := int(item.get("upgrade", 0)) + 1
	if target >= DOWNGRADE_FROM and not protected:
		return "l'objet redescend à +%d" % maxi(0, target - 2)
	return "l'objet reste à +%d" % (target - 1)


## Tentative de fortification : {ok, text, stat, value}. Parchemin, pierre et or sont consommés
## par l'appelant (Profile.upgrade_item) ; une pierre ou le parchemin béni protègent l'objet.
static func upgrade(item: Dictionary, stone := "", scroll := "") -> Dictionary:
	if Items.is_unique(item):
		return {"ok": false, "error": true, "text": Items.UNIQUE_TEXT}
	var chance := success_chance(item, stone, scroll)
	var protect := stone != "" or scroll == BLESSED
	var target := int(item.get("upgrade", 0)) + 1
	if randf() < chance:
		return _upgrade_success(item, target)
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
	var saved := protect and target >= DOWNGRADE_FROM
	return {"ok": false, "text": "Échec. %s" % (("%s a protégé l'objet." % ("Le parchemin béni" if stone == "" else label(stone))) if saved else "L'objet est intact.")}


## Amélioration réussie d'office (enclume de la carte) : +1 sans parchemin ni or, sans risque.
static func upgrade_free(item: Dictionary) -> Dictionary:
	if Items.is_unique(item):
		return {"ok": false, "text": Items.UNIQUE_TEXT}
	var target := int(item.get("upgrade", 0)) + 1
	if target > Items.MAX_UPGRADE:
		return {"ok": false, "text": "Déjà +%d" % Items.MAX_UPGRADE}
	return _upgrade_success(item, target)


static func _upgrade_success(item: Dictionary, target: int) -> Dictionary:
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


## Stat bonus aléatoire gagnée au palier +[param target] (+4, +6, +8, +10) : [stat, valeur au
## niveau 1 (suit la puissance de l'objet), palier]. Aléatoire pour qu'un objet parfait soit rare.
static func _upgrade_roll(item: Dictionary, target: int) -> Array:
	var pool: Array = UPGRADE_POOL_WEAPON if item.slot in ["weapon", "gloves"] else UPGRADE_POOL_ARMOR
	var stat: String = pool.pick_random()
	var r: Array = UPGRADE_ROLL[stat]
	var v := randf_range(r[0], r[1]) * 2.0
	return [stat, snappedf(v, 0.001 if stat in Items.PERCENT_STATS else 0.1), target]


# --- butin ----------------------------------------------------------------------------------------
## Niveau de parchemin de fortification adapté à un niveau de butin.
static func fortify_level_at(level: int) -> int:
	for f in FORTIFY_LEVELS:
		if int(f) >= level:
			return int(f)
	return int(FORTIFY_LEVELS[-1])


## Pierre de sûreté aléatoire ([param bonus] > 0 : les plus rares sortent plus souvent).
static func random_stone(bonus := 0) -> String:
	var r := randf() * 100.0 / (1.0 + 0.6 * bonus)
	if r < 2.0:
		return stone_key("sublime")
	if r < 12.0:
		return stone_key(["viridian", "ultramarine", "coral"].pick_random())
	if r < 25.0:
		return stone_key("citrine")
	if r < 55.0:
		return stone_key("lucky")
	return stone_key("safety")


## Consommable aléatoire adapté au niveau ([param bonus] : coffres rares, élites, boss) ; les gemmes
## suivent [param gem_level] s'il est donné (Survie : RunDirector.gem_level), sinon [param level].
static func random_loot(level: int, bonus := 0, gem_level := -1) -> String:
	var r := randf() * 100.0
	var tier := clampi((gem_level if gem_level >= 0 else level) / 8 + bonus + (1 if randf() < 0.25 else 0) - (1 if randf() < 0.3 else 0), 0, GEM_TIERS.size() - 1)
	if r < 26.0:
		return gem_key(GEMS.keys().pick_random(), tier)
	if r < 52.0:
		return fortify_key(["power", "guard"].pick_random(), fortify_level_at(level))
	if r < 64.0:
		var slv := loot_scroll_level(level)
		if slv > 0:
			return scroll_key(ENCHANTS.keys().pick_random(), clampi(slv + (1 if bonus > 0 and randf() < 0.3 else 0) - (1 if randf() < 0.35 else 0), 1, slv))
		return fortify_key(["power", "guard"].pick_random(), fortify_level_at(level))
	if r < 72.0:
		return "drill"
	if r < 99.0 - 1.5 * bonus:
		return random_stone(bonus)
	return BLESSED


## Spécialité des sources de fournitures (mode farm) : poids de chaque famille.
## gem : gemmes · fortify : parchemins de fortification (pour chaque +1) · scroll : parchemins
## d'enchantement · drill : ciseaux · stone : pierres de sûreté · blessed : parchemin béni.
const LOOT_SOURCES := {
	"crate": {"fortify": 55, "drill": 20, "stone": 20, "gem": 5},  # caisses et tonneaux : la forge
	"pot": {"gem": 40, "fortify": 30, "stone": 15, "drill": 15},  # jarres : un peu de tout
	"chest0": {"fortify": 45, "stone": 25, "gem": 15, "scroll": 10, "drill": 5},
	"chest1": {"fortify": 30, "stone": 30, "scroll": 20, "gem": 15, "blessed": 5},
	"chest2": {"stone": 30, "scroll": 25, "fortify": 20, "blessed": 15, "gem": 10},
	"challenge": {"stone": 40, "blessed": 25, "scroll": 20, "fortify": 15},
}


## Fournitures de la source [param source] (LOOT_SOURCES ; sinon le tirage général) ; gemmes au
## niveau [param gem_level] s'il est donné.
static func loot_for(source: String, level: int, bonus := 0, gem_level := -1) -> String:
	var w: Dictionary = LOOT_SOURCES.get(source, {})
	if w.is_empty():
		return random_loot(level, bonus, gem_level)
	var total := 0
	for k in w:
		total += int(w[k])
	var r := randi() % maxi(total, 1)
	var fam := ""
	for k in w:
		r -= int(w[k])
		if r < 0:
			fam = String(k)
			break
	var tier := clampi((gem_level if gem_level >= 0 else level) / 8 + bonus + (1 if randf() < 0.25 else 0) - (1 if randf() < 0.3 else 0), 0, GEM_TIERS.size() - 1)
	match fam:
		"gem":
			return gem_key(GEMS.keys().pick_random(), tier)
		"scroll":
			var slv := loot_scroll_level(level)
			if slv > 0:
				return scroll_key(ENCHANTS.keys().pick_random(), clampi(slv - (1 if randf() < 0.35 - 0.15 * bonus else 0), 1, slv))
			return fortify_key(["power", "guard"].pick_random(), fortify_level_at(level))
		"drill":
			return "drill"
		"stone":
			return random_stone(bonus)
		"blessed":
			return BLESSED
	return fortify_key(["power", "guard"].pick_random(), fortify_level_at(level))


## Objet de butin (LootDrop) représentant un consommable.
static func loot_item(key: String) -> Dictionary:
	return {"consumable": key, "name": label(key), "icon": icon(key), "rarity": rarity(key)}
