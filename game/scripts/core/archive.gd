class_name Archive
extends RefCounted
## Archive (comme dans Eden Eternal) : on y range définitivement les objets rares (or),
## épiques (violet) et légendaires (orange), bijoux et trophées compris. Chaque entrée
## remplie donne un bonus permanent à toutes les classes, des paliers récompensent la
## collection, et les armes archivées débloquent leur apparence (skin).
## Le catalogue montre tout l'équipement qui existe dans le jeu.

## Raretés archivées (colonnes du catalogue).
const TIERS := [2, 3, 4]
## Attribut renforcé par chaque type d'objet archivé.
const ATTR := {
	"katana": "str", "axe": "str", "dagger": "agi", "bow": "agi", "scepter": "wis", "staff": "int",
	"sword": "str", "rapier": "agi", "greatsword": "str", "hammer": "str", "rod": "int", "cestus": "agi",
	"cannon": "agi", "spear": "str", "guitar": "wis", "grimoire": "int", "gunscythe": "agi",
	"head": "int", "chest": "str", "legs": "agi", "gloves": "str", "boots": "agi", "back": "lck",
	"necklace": "wis", "ring": "lck",
}
## Points d'attribut par rareté archivée (le trophée donne la moitié à chaque attribut).
const TIER_POINTS := {2: 1.0, 3: 2.0, 4: 4.0}
## Paliers de collection : nombre d'entrées -> bonus.
const MILESTONES := [
	[5, {"hp_pct": 0.03}],
	[10, {"dmg_pct": 0.02}],
	[15, {"crit": 0.02, "mcrit": 0.02}],
	[25, {"atk_speed": 0.04}],
	[35, {"dmg_pct": 0.04}],
	[45, {"cdr": 0.05}],
	[51, {"dmg_pct": 0.1}],
]
## Bonus d'une pièce de set archivée.
const SET_BONUS := {"dmg_pct": 0.01}


## Groupes du catalogue : [{name, rows: [{id, name, slot}]}].
static func groups() -> Array:
	var weapons: Array = []
	for wt in GameData.weapon_types:
		weapons.append({"id": wt, "name": String(GameData.weapon_types[wt].name), "slot": "weapon"})
	var armor: Array = Items.ARMOR.map(func(s): return {"id": s, "name": Items.SLOT_NAMES[s], "slot": s})
	var acc: Array = Items.ACCESSORIES.map(func(s): return {"id": s, "name": Items.SLOT_NAMES[s], "slot": s})
	return [{"name": "Armes", "rows": weapons}, {"name": "Armures", "rows": armor}, {"name": "Bijoux et trophées", "rows": acc}]


## Type d'objet dans l'archive : type d'arme (katana...) ou emplacement.
static func base_id(item: Dictionary) -> String:
	return Items.weapon_type_of(item) if item.get("slot", "") == "weapon" else String(item.get("slot", ""))


static func key(base: String, tier: int) -> String:
	return "%s:%d" % [base, tier]


static func set_key(sid: String) -> String:
	return "set:%s" % sid


## Entrées que l'objet remplirait.
static func keys_for(item: Dictionary) -> Array:
	if int(item.get("rarity", 0)) < Items.ARCHIVE_MIN_RARITY:
		return []
	var out := [key(base_id(item), int(item.rarity))]
	if Items.SETS.has(String(item.get("set", ""))):
		out.append(set_key(String(item.set)))
	return out


static func all_keys() -> Array:
	var out: Array = []
	for g in groups():
		for r in g.rows:
			for t in TIERS:
				out.append(key(String(r.id), t))
	for sid in Items.SETS:
		out.append(set_key(sid))
	return out


static func is_archived(k: String) -> bool:
	return Profile.archive.has(k)


static func count() -> int:
	return all_keys().filter(func(k): return Profile.archive.has(k)).size()


static func total() -> int:
	return all_keys().size()


## Pourquoi l'objet ne peut pas être archivé ("" : il peut l'être).
static func refusal(item: Dictionary) -> String:
	if item.is_empty():
		return "Choisis un objet."
	if Profile.in_run:
		return "On n'archive qu'entre les runs (au lobby)."
	if int(item.get("rarity", 0)) < Items.ARCHIVE_MIN_RARITY:
		return "Seuls les objets rares (or), épiques (violet) et légendaires (orange) s'archivent."
	if keys_for(item).all(func(k): return Profile.archive.has(k)):
		return "Déjà archivé : cette entrée de la collection est remplie."
	return ""


## Bonus d'une entrée (stats).
static func entry_bonus(k: String) -> Dictionary:
	if k.begins_with("set:"):
		return SET_BONUS
	var p := k.split(":")
	var pts := float(TIER_POINTS.get(int(p[1]), 1.0))
	if p[0] == "trophy":
		var out := {}
		for a in Items.ATTRIBUTES:
			out[a] = pts * 0.5
		return out
	return {String(ATTR.get(p[0], "str")): pts}


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


## Icône d'une entrée (modèle d'arme de la rareté, ou icône d'armure représentative).
static func entry_icon(base: String, slot: String, tier: int) -> String:
	if slot == "weapon":
		var ws: Array = GameData.weapon_type(base).get("weapons", [])
		return String(ws[mini(tier, ws.size() - 1)].icon) if not ws.is_empty() else ""
	var list: Array = Items.icons().get(slot, [])
	return String(list[(tier * 7 + 3) % list.size()]) if not list.is_empty() else ""


static func entry_name(base_name: String, tier: int) -> String:
	return "%s %s" % [base_name, String(Items.RARITIES[tier].name).to_lower()]


## Où trouver une rareté.
static func source_text(slot: String, tier: int) -> String:
	if slot == "trophy":
		return "Trophée : butin rare des élites et des boss."
	match tier:
		2:
			return "Rare (or) : butin courant des élites, boutique du marchand."
		3:
			return "Épique (violet) : élites enragées, coffres et boss."
	return "Légendaire (orange) : surtout sur les boss (plus encore s'ils sont enragés)."


# --- apparences (skins d'arme) ----------------------------------------------------------------
## Modèles d'un type d'arme : [{code, icon, model}].
static func skins(wtype: String) -> Array:
	return GameData.weapon_type(wtype).get("weapons", [])


## Les 2 premiers modèles sont libres ; les suivants s'obtiennent en archivant une arme
## de ce type de rareté suffisante (rare : 3e modèle, épique ou légendaire : 4e).
static func skin_unlocked(wtype: String, index: int) -> bool:
	if index <= 1:
		return true
	for t in TIERS:
		if Profile.archive.has(key(wtype, t)) and mini(t, 3) >= index:
			return true
	return false


static func skin_hint(index: int) -> String:
	return "libre" if index <= 1 else ("archive une arme rare de ce type" if index == 2 else "archive une arme épique ou légendaire de ce type")
