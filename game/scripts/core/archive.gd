class_name Archive
extends RefCounted
## Archive façon Eden (« Treasure Archive ») : toutes les entrées de l'archive d'Eden
## (c_collection), dans ses catégories : apparences (tête, dos, corps, armes), armes par
## type et boucliers, armures de plates / cuir / tissu et capes, bijoux et trophées, objets
## spéciaux (montures, familiers, boîte arcanique, autres objets dont les auras).
## Équipement (mythiques et légendaires) : on y dépose l'objet (il quitte le coffre ; on peut
## le retirer) ; chaque entrée donne un bonus permanent, des paliers récompensent la
## collection, chaque arme archivée débloque son apparence. Les autres entrées (« trésors de
## collection ») s'obtiennent sur les boss et se portent : apparences, auras.

const TIERS := [4, 5]
## Attribut renforcé par chaque type d'objet archivé.
const ATTR := {
	"katana": "str", "axe": "str", "dagger": "agi", "bow": "agi", "scepter": "wis", "staff": "int",
	"sword": "str", "rapier": "agi", "greatsword": "str", "hammer": "str", "rod": "int", "cestus": "agi",
	"cannon": "agi", "spear": "str", "guitar": "wis", "grimoire": "int", "gunscythe": "agi",
	"head": "int", "chest": "str", "legs": "agi", "gloves": "str", "boots": "agi", "back": "lck",
	"necklace": "wis", "ring": "lck", "shield": "str",
}
## Catégories d'Eden hors équipement (GameData.collection -> cat).
const COLLECTION_CATS := [
	[1, "Tête", "Apparences"], [2, "Dos", "Apparences"], [3, "Corps", "Apparences"], [4, "Armes", "Apparences"],
	[29, "Montures", "Objets spéciaux"], [30, "Familiers", "Objets spéciaux"],
	[31, "Boîte arcanique", "Objets spéciaux"], [32, "Autres objets", "Objets spéciaux"],
]
## Points d'attribut par entrée : mythique 1, légendaire 2 (le trophée donne la moitié à chaque attribut).
const TIER_POINTS := {4: 1.0, 5: 2.0}
## Paliers de collection : nombre d'entrées remplies -> bonus.
const MILESTONES := [
	[10, {"hp_pct": 0.03}],
	[25, {"dmg_pct": 0.02}],
	[50, {"crit": 0.02, "mcrit": 0.02}],
	[100, {"atk_speed": 0.04}],
	[200, {"dmg_pct": 0.04}],
	[400, {"cdr": 0.05}],
	[800, {"hp_pct": 0.06}],
	[1500, {"dmg_pct": 0.1}],
]
const ARMOR_CLASS_FR := {"plates": "Armures de plates", "cuir": "Armures de cuir", "tissu": "Armures de tissu"}

static var _cache_cats: Array = []
static var _cache_entries: Dictionary = {}  # catégorie -> entrées d'Eden


## Catégories : [{id, name, group}] (groupes : Armes, Armures, Accessoires).
static func categories() -> Array:
	if _cache_cats.is_empty():
		for c in COLLECTION_CATS.slice(0, 4):
			_cache_cats.append({"id": "c:%d" % int(c[0]), "name": String(c[1]), "group": String(c[2])})
		for wt in GameData.weapon_types:
			_cache_cats.append({"id": "w:" + String(wt), "name": String(GameData.weapon_types[wt].name), "group": "Armes"})
		_cache_cats.append({"id": "s:shield", "name": "Boucliers", "group": "Armes"})
		for c in ARMOR_CLASS_FR:
			_cache_cats.append({"id": "a:" + c, "name": ARMOR_CLASS_FR[c], "group": "Armures"})
		_cache_cats.append({"id": "s:back", "name": "Capes", "group": "Armures"})
		for s in ["necklace", "ring", "trophy"]:
			_cache_cats.append({"id": "s:" + s, "name": {"necklace": "Colliers", "ring": "Bagues", "trophy": "Trophées"}[s], "group": "Accessoires"})
		for c in COLLECTION_CATS.slice(4):
			_cache_cats.append({"id": "c:%d" % int(c[0]), "name": String(c[1]), "group": String(c[2])})
		# catégories sans objet mythique ou légendaire dans Eden (ex. faux-fusil) : masquées
		_cache_cats = _cache_cats.filter(func(c): return not entries(String(c.id)).is_empty())
	return _cache_cats


## Catégorie d'un objet d'Eden.
static func cat_of(e: Dictionary) -> String:
	if String(e.get("slot", "")) == "weapon":
		return "w:" + String(e.get("wtype", ""))
	if e.has("armor"):
		return "a:" + String(e.armor)
	return "s:" + String(e.get("slot", ""))


## Entrées d'une catégorie : objets d'Eden de l'archive (par niveau, comme dans Eden) ou
## trésors de collection (catégories "c:N").
static func entries(cat_id: String) -> Array:
	if _cache_entries.is_empty():
		for e: Dictionary in GameData.eden_items:
			if e.has("arch"):
				var c := cat_of(e)
				if not _cache_entries.has(c):
					_cache_entries[c] = []
				_cache_entries[c].append(e)
		for c in _cache_entries:
			_cache_entries[c].sort_custom(func(a, b): return [int(a.level), int(a.get("ord", 0))] < [int(b.level), int(b.get("ord", 0))])
		for x: Dictionary in GameData.collection:
			var c := "c:%d" % int(x.cat)
			if not _cache_entries.has(c):
				_cache_entries[c] = []
			_cache_entries[c].append(x)
	return _cache_entries.get(cat_id, [])


## Trésor de collection (apparence, monture, familier, aura...) plutôt qu'équipement.
static func is_collection(e: Dictionary) -> bool:
	return e.has("cat") and not e.has("slot")


static func key_of(e: Dictionary) -> String:
	return ("c%d" if is_collection(e) else "e%d") % int(e.id)


## Entrée obtenue : équipement archivé, ou trésor de collection obtenu.
static func owned(e: Dictionary) -> bool:
	return Profile.collected(e) if is_collection(e) else Profile.archive.has(key_of(e))


## Entrées que l'objet remplirait.
static func keys_for(item: Dictionary) -> Array:
	if int(item.get("rarity", 0)) < Items.ARCHIVE_MIN_RARITY or not item.has("eden"):
		return []
	var e: Dictionary = GameData.eden_by_id.get(int(item.eden), {})
	if e.is_empty() or not e.has("arch"):
		return []
	return [key_of(e)]


static func is_archived(k: String) -> bool:
	return Profile.archive.has(k)


static func count() -> int:
	return Profile.archive.keys().filter(func(k): return String(k).begins_with("e")).size()


## Toutes les entrées (équipement et trésors de collection).
static func total() -> int:
	var n := 0
	for c in categories():
		n += entries(String(c.id)).size()
	return n


## Entrées d'équipement (celles qui comptent pour les paliers).
static func total_gear() -> int:
	var n := 0
	for c in categories():
		if not String(c.id).begins_with("c:"):
			n += entries(String(c.id)).size()
	return n


## Entrées obtenues, toutes catégories.
static func count_all() -> int:
	var n := count()
	for c in COLLECTION_CATS:
		n += int(rate("c:%d" % int(c[0])).x)
	return n


## Avancement d'une catégorie : Vector2(remplies, total).
static func rate(cat_id: String) -> Vector2:
	var es := entries(cat_id)
	return Vector2(es.filter(func(e): return owned(e)).size(), es.size())


## Score d'archive (comme Eden) : 1 par mythique, 2 par légendaire, 1 par trésor de collection.
static func score() -> int:
	var s := 0
	for k in Profile.archive:
		var e: Dictionary = GameData.eden_by_id.get(int(String(k).trim_prefix("e")), {}) if String(k).begins_with("e") else {}
		s += 2 if int(e.get("rarity", 4)) >= Items.LEGENDARY else 1
	for c in COLLECTION_CATS:
		s += int(rate("c:%d" % int(c[0])).x)
	return s


## Pourquoi l'objet ne peut pas être archivé ("" : il peut l'être).
static func refusal(item: Dictionary) -> String:
	if item.is_empty():
		return "Choisis un objet."
	if Profile.in_run:
		return "On n'archive qu'entre les runs (au lobby)."
	if int(item.get("rarity", 0)) < Items.ARCHIVE_MIN_RARITY:
		return "Seuls les objets mythiques (orange) et légendaires (or) s'archivent, comme dans Eden."
	if not item.has("eden") or not GameData.eden_by_id.get(int(item.eden), {}).has("arch"):
		return "Cet objet n'a pas d'entrée dans l'archive d'Eden."
	var keys := keys_for(item)
	if keys.is_empty():
		return "Cet objet n'a pas d'entrée dans l'archive."
	if keys.all(func(k): return Profile.archive.has(k)):
		return "Déjà archivé : cette entrée est remplie."
	return ""


## Bonus d'une entrée (stats).
static func entry_bonus(k: String) -> Dictionary:
	var e: Dictionary = GameData.eden_by_id.get(int(k.trim_prefix("e")), {}) if k.begins_with("e") else {}
	if e.is_empty():
		return {}
	var pts := float(TIER_POINTS.get(mini(int(e.rarity), Items.LEGENDARY), 1.0))
	var base := String(e.get("wtype", e.get("slot", "")))
	if base == "trophy":
		return {"lck": pts}  # trophées : de la chance (les trophées n'ont presque plus de stats fixes)
	return {String(ATTR.get(base, "str")): pts}


## Bonus permanent de l'archive (entrées + paliers atteints), pour toutes les classes.
static func bonus() -> Dictionary:
	var out := {}
	for k in Profile.archive:
		var b := entry_bonus(String(k))
		for s in b:
			out[s] = float(out.get(s, 0.0)) + float(b[s])
	var n := count()
	for m in MILESTONES:
		if n >= int(m[0]):
			for s in m[1]:
				out[s] = float(out.get(s, 0.0)) + float(m[1][s])
	return out


static func bonus_text(b: Dictionary) -> String:
	var parts: PackedStringArray = []
	for s in b:
		parts.append(Items.stat_text(s, b[s]))
	return ", ".join(parts)


## Où trouver l'objet.
static func source_text(e: Dictionary) -> String:
	var eden := (" Dans Eden : %s." % String(e.src)) if String(e.get("src", "")) != "" else ""
	if is_collection(e):
		return "Trésor de collection : butin des boss (1 chance sur 4, 1 sur 2 s'ils sont enragés).%s" % eden
	var zi := GameData.zone_of_eden_level(int(e.level))
	var zone := String(GameData.zones[zi].get("name", "")) if not GameData.zones.is_empty() else ""
	if int(e.rarity) >= Items.LEGENDARY:
		return "Niveau %d d'Eden. Légendaire : butin du boss de %s (30 %%, 50 %% s'il est enragé).%s" % [int(e.level), zone, eden]
	if int(e.rarity) >= Items.MYTHIC:
		return "Niveau %d d'Eden. Mythique : butin du boss de %s, ou fabrication chez un marchand ambulant de cette zone.%s" % [int(e.level), zone, eden]
	return "Niveau %d d'Eden : tombe dans %s.%s" % [int(e.level), zone, eden]


## Description d'un trésor de collection (carte au survol).
static func collection_text(x: Dictionary) -> String:
	var cat := ""
	for c in COLLECTION_CATS:
		if int(c[0]) == int(x.cat):
			cat = "%s · %s" % [c[2], c[1]]
	var lines := ["[img=52x52]%s[/img]  [font_size=20][b][color=#%s]%s[/color][/b][/font_size]" % [x.icon, Items.RARITIES[clampi(int(x.get("rarity", 0)), 0, 5)].color.to_html(false), x.name],
		"[color=#9a98a8]%s%s[/color]" % [cat, " · boutique d'Eden" if x.get("mall", false) else ""]]
	if x.has("aura"):
		var parts: PackedStringArray = []
		for s in x.aura.stat:
			parts.append(Items.stat_text(s, x.aura.stat[s]))
		lines.append("[color=#ffd76a]✶ Aura (%s) : %s pendant les runs[/color]" % [AURA_KINDS.get(String(x.aura.kind), "aura"), ", ".join(parts)])
		lines.append("[color=#c8c8d4]Effet lumineux d'Eden autour du héros ; une pierre étoilée et une pierre de lune se portent ensemble (onglet Tenues).[/color]")
	elif x.has("skin"):
		lines.append("[color=#c8c8d4]Apparence d'arme : se choisit dans « Apparences d'armes » pour %s.[/color]" % (
			"n'importe quelle arme" if String(x.skin.wtype) == "" else String(GameData.weapon_type(String(x.skin.wtype)).get("name", "son type d'arme"))))
	elif GameData.cosmetic_by_code.has(String(x.get("code", ""))):
		lines.append("[color=#c8c8d4]Se porte avec n'importe quelle classe (onglet Tenues).[/color]")
	elif x.has("mount"):
		lines.append("[color=#c8c8d4]Monture d'Eden (vitesse +%d %% dans Eden) : pièce de collection.[/color]" % int(x.mount.speed))
	else:
		lines.append("[color=#c8c8d4]Pièce de collection.[/color]")
	return "\n".join(lines)


const AURA_KINDS := {"star": "pierre étoilée", "luna": "pierre de lune", "other": "aura"}


# --- apparences (skins d'arme) ----------------------------------------------------------------
## Modèles d'un type d'arme : les 4 modèles de base (libres), puis l'apparence de chaque arme
## mythique ou légendaire archivée de ce type : [{code, icon, model, texture, name}].
static func skins(wtype: String) -> Array:
	var out: Array = []
	for w in GameData.weapon_type(wtype).get("weapons", []):
		out.append(w)
	for e in entries("w:" + wtype):
		if Profile.archive.has(key_of(e)) and e.has("model"):
			out.append({"code": e.code, "icon": e.icon, "model": e.model, "texture": e.texture, "name": e.name})
	# apparences d'armes de l'archive d'Eden (trésors de collection)
	for x in entries("c:4"):
		if x.has("skin") and String(x.skin.wtype) in ["", wtype] and Profile.collected(x):
			out.append({"code": x.code, "icon": x.icon, "model": x.skin.model, "texture": x.skin.texture, "name": x.name})
	return out


static func skin_unlocked(_wtype: String, _index: int) -> bool:
	return true  # les apparences listées sont toutes disponibles


static func skin_hint(index: int) -> String:
	return "modèle de base" if index < 4 else "arme archivée ou apparence de l'archive"


## Retire l'objet [param k] de l'archive : il revient dans le coffre (le bonus est perdu).
static func withdraw(k: String) -> Dictionary:
	if Profile.in_run or not Profile.archive.has(k):
		return {}
	var item: Dictionary = Profile.archive[k]
	Profile.archive.erase(k)
	Profile.add_item(item)
	Profile.save_profile()
	return item
