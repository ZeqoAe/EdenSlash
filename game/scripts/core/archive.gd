class_name Archive
extends RefCounted
## Archive façon Eden (« Treasure Archive ») : chaque objet mythique (orange) ou légendaire
## (or) d'Eden a son entrée, rangée par catégorie (armes par type, armures de plates / cuir /
## tissu, capes, colliers, bagues, trophées). On y dépose l'objet (il quitte le coffre ; on
## peut le retirer). Chaque entrée remplie donne un bonus permanent à toutes les classes,
## des paliers récompensent la collection, et chaque arme archivée débloque son apparence.

const TIERS := [4, 5]
## Attribut renforcé par chaque type d'objet archivé.
const ATTR := {
	"katana": "str", "axe": "str", "dagger": "agi", "bow": "agi", "scepter": "wis", "staff": "int",
	"sword": "str", "rapier": "agi", "greatsword": "str", "hammer": "str", "rod": "int", "cestus": "agi",
	"cannon": "agi", "spear": "str", "guitar": "wis", "grimoire": "int", "gunscythe": "agi",
	"head": "int", "chest": "str", "legs": "agi", "gloves": "str", "boots": "agi", "back": "lck",
	"necklace": "wis", "ring": "lck",
}
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
		for wt in GameData.weapon_types:
			_cache_cats.append({"id": "w:" + String(wt), "name": String(GameData.weapon_types[wt].name), "group": "Armes"})
		for c in ARMOR_CLASS_FR:
			_cache_cats.append({"id": "a:" + c, "name": ARMOR_CLASS_FR[c], "group": "Armures"})
		_cache_cats.append({"id": "s:back", "name": "Capes", "group": "Armures"})
		for s in ["necklace", "ring", "trophy"]:
			_cache_cats.append({"id": "s:" + s, "name": {"necklace": "Colliers", "ring": "Bagues", "trophy": "Trophées"}[s], "group": "Accessoires"})
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


## Entrées (objets d'Eden mythiques et légendaires) d'une catégorie, par niveau.
static func entries(cat_id: String) -> Array:
	if _cache_entries.is_empty():
		for e: Dictionary in GameData.eden_items:
			if int(e.rarity) >= Items.ARCHIVE_MIN_RARITY:
				var c := cat_of(e)
				if not _cache_entries.has(c):
					_cache_entries[c] = []
				_cache_entries[c].append(e)
	return _cache_entries.get(cat_id, [])


static func key_of(e: Dictionary) -> String:
	return "e%d" % int(e.id)


## Entrées que l'objet remplirait.
static func keys_for(item: Dictionary) -> Array:
	if int(item.get("rarity", 0)) < Items.ARCHIVE_MIN_RARITY or not item.has("eden"):
		return []
	var e: Dictionary = GameData.eden_by_id.get(int(item.eden), {})
	if e.is_empty() or int(e.rarity) < Items.ARCHIVE_MIN_RARITY:
		return []
	return [key_of(e)]


static func is_archived(k: String) -> bool:
	return Profile.archive.has(k)


static func count() -> int:
	return Profile.archive.keys().filter(func(k): return String(k).begins_with("e")).size()


static func total() -> int:
	var n := 0
	for c in categories():
		n += entries(String(c.id)).size()
	return n


## Avancement d'une catégorie : Vector2(remplies, total).
static func rate(cat_id: String) -> Vector2:
	var es := entries(cat_id)
	return Vector2(es.filter(func(e): return Profile.archive.has(key_of(e))).size(), es.size())


## Score d'archive (comme Eden) : 1 par mythique, 2 par légendaire.
static func score() -> int:
	var s := 0
	for k in Profile.archive:
		var e: Dictionary = GameData.eden_by_id.get(int(String(k).trim_prefix("e")), {}) if String(k).begins_with("e") else {}
		s += 2 if int(e.get("rarity", 4)) >= Items.LEGENDARY else 1
	return s


## Pourquoi l'objet ne peut pas être archivé ("" : il peut l'être).
static func refusal(item: Dictionary) -> String:
	if item.is_empty():
		return "Choisis un objet."
	if Profile.in_run:
		return "On n'archive qu'entre les runs (au lobby)."
	if int(item.get("rarity", 0)) < Items.ARCHIVE_MIN_RARITY:
		return "Seuls les objets mythiques (orange) et légendaires (or) s'archivent, comme dans Eden."
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
		var out := {}
		for a in Items.ATTRIBUTES:
			out[a] = pts * 0.5
		return out
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
	var zi := clampi(int(e.get("band", 0)), 0, GameData.zones.size() - 1)
	var zone := String(GameData.zones[zi].get("name", "")) if not GameData.zones.is_empty() else ""
	if int(e.rarity) >= Items.LEGENDARY:
		return "Légendaire : butin du boss de %s (30 %%, 50 %% s'il est enragé)." % zone
	return "Mythique : butin du boss de %s, ou fabrication à la forge du village de cette zone." % zone


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
	return out


static func skin_unlocked(_wtype: String, _index: int) -> bool:
	return true  # les apparences listées sont toutes disponibles


static func skin_hint(index: int) -> String:
	return "modèle de base" if index < 4 else "arme archivée"


## Retire l'objet [param k] de l'archive : il revient dans le coffre (le bonus est perdu).
static func withdraw(k: String) -> Dictionary:
	if Profile.in_run or not Profile.archive.has(k):
		return {}
	var item: Dictionary = Profile.archive[k]
	Profile.archive.erase(k)
	Profile.add_item(item)
	Profile.save_profile()
	return item
