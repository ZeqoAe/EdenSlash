class_name SlotChests
extends RefCounted
## Coffres d'emplacement de la Survie (DESIGN.md, « Boucle de jeu et Survie ») : chaque coffre
## payant de la map vise un emplacement (arme, tête, torse…, bijoux, trophée) ou un type de
## carte (sort, passif, certificat). Un coffre d'équipement propose 3 pièces d'Eden tirées
## parmi toutes celles de son emplacement au palier et à la rareté de la map, avec une
## relance par coffre ; les pièces restent à +0 (l'enclume améliore les emplacements).

## name : titre du coffre ; slots : emplacements d'objets ; cards : type de cartes ;
## look : apparence (ProcMap.CHEST_LOOKS : 0 coffre, 1 ouvragé, 2 doré) ; price : × prix.
const BOXES := {
	"weapon": {"name": "Coffre d'arme", "slots": ["weapon"], "look": 0, "price": 1.0},
	"head": {"name": "Coffre de casque", "slots": ["head"], "look": 0, "price": 1.0},
	"chest": {"name": "Coffre de torse", "slots": ["chest"], "look": 0, "price": 1.0},
	"legs": {"name": "Coffre de jambières", "slots": ["legs"], "look": 0, "price": 1.0},
	"gloves": {"name": "Coffre de gants", "slots": ["gloves"], "look": 0, "price": 1.0},
	"boots": {"name": "Coffre de bottes", "slots": ["boots"], "look": 0, "price": 1.0},
	"jewel": {"name": "Coffre de bijoux", "slots": ["ring", "necklace"], "look": 2, "price": 1.3},
	"trophy": {"name": "Coffre de trophée", "slots": ["trophy"], "look": 2, "price": 1.5},
	"spell": {"name": "Coffre de sort", "cards": "spell", "look": 1, "price": 1.2},
	"passive": {"name": "Coffre de passif", "cards": "passive", "look": 1, "price": 1.2},
	"cert": {"name": "Coffre de certificat", "cards": "cert", "look": 1, "price": 1.4},
}
## Les 30 coffres d'une map (mélangés sur la carte).
const LAYOUT := ["weapon", "weapon", "weapon", "head", "head", "head", "chest", "chest", "chest", "legs", "legs", "legs",
	"gloves", "gloves", "gloves", "boots", "boots", "boots", "jewel", "jewel", "jewel", "trophy", "trophy",
	"spell", "spell", "spell", "passive", "passive", "cert", "cert"]


## Types des [param n] coffres d'une map, mélangés avec [param rng].
static func layout(n: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	while out.size() < n:
		out.append_array(LAYOUT)
	out = out.slice(0, n)
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## Toutes les pièces d'Eden que peut donner un coffre [param box] sur la map [param stage]
## de l'époque [param epoch] : son emplacement, au palier de la map (le plus proche en
## dessous s'il n'y en a pas), à sa rareté (pièces « Awaken » pour l'éveillé).
static func pool(box: String, epoch: int, stage: int) -> Array:
	var m := Epochs.map_def(epoch, stage)
	var out: Array = []
	for slot in BOXES[box].get("slots", []):
		var lv := int(m.weapon) if slot == "weapon" else int(m.armor)
		var rarity := int(m.rarity)
		var awakened: bool = m.get("awakened", false) and slot in ["head", "chest", "legs", "gloves", "boots"]
		var main := Profile.main_weapon_type()  # coffre d'arme : l'arme principale, du type de la classe
		var cands: Array = GameData.eden_items.filter(func(e): return String(e.get("slot", "")) == slot \
			and (slot != "weapon" or String(e.get("wtype", "")) == main) and Trophies.in_pool(e) and (int(e.rarity) == rarity or (slot == "trophy" and int(e.rarity) >= Items.MYTHIC)) \
			and String(e.name).begins_with("Awaken ") == awakened)
		if cands.is_empty():
			continue
		# palier exact, sinon le plus haut en dessous, sinon le plus bas au-dessus
		var below := cands.filter(func(e): return int(e.level) <= lv)
		var target := -1
		for e in below:
			target = maxi(target, int(e.level))
		if target < 0:
			target = 999
			for e in cands:
				target = mini(target, int(e.level))
		if slot == "trophy":
			out.append_array(cands.filter(func(e): return int(e.level) <= lv and int(e.level) >= lv - 12) if below.size() > 0 else cands.filter(func(e): return int(e.level) == target))
		else:
			out.append_array(cands.filter(func(e): return int(e.level) == target))
	return out


## [param n] pièces au hasard d'un coffre [param box] (sans doublon), +0, puissance plafonnée
## au niveau maximal de la map.
static func offer(box: String, epoch: int, stage: int, n := 3) -> Array:
	var p := pool(box, epoch, stage)
	if box == "trophy" and Run.active:
		var worn_kind := String(Profile.equipped.get("trophy", {}).get("passive", {}).get("trophy", ""))
		var owned := Profile.equipped.values() + Profile.inventory
		p = p.filter(func(e): return not int(e.id) in Run.seen_items and String(e.get("trophy", "")) != worn_kind \
			and not owned.any(func(it): return int(it.get("eden", -1)) == int(e.id)))
	p.shuffle()
	var m := Epochs.map_def(epoch, stage)
	var out: Array = []
	for e in p.slice(0, n):
		var it := Items.from_template(e, Epochs.cap(stage), int(m.rarity) if String(e.slot) != "trophy" else int(e.rarity))
		it["upgrade"] = 0
		if m.get("awakened", false) and String(e.name).begins_with("Awaken "):
			it["awakened"] = true
		out.append(it)
	return out


## Arme secondaire trouvée en jeu (élites, boss de la Survie) : [param n] armes de types
## différents (aucune du type de la classe), à la rareté et au palier de la map, chacune avec
## une de ses deux variantes au hasard.
static func offhand_offer(epoch: int, stage: int, n := 3) -> Array:
	var m := Epochs.map_def(epoch, stage)
	var main := Profile.main_weapon_type()
	var lv := int(m.weapon)
	var by_type := {}
	for e in GameData.eden_items:
		if String(e.get("slot", "")) != "weapon" or String(e.get("wtype", "")) in ["", main] or not Trophies.in_pool(e) \
				or int(e.rarity) != int(m.rarity) or String(e.name).begins_with("Awaken "):
			continue
		var wt := String(e.wtype)
		if not by_type.has(wt):
			by_type[wt] = []
		by_type[wt].append(e)
	var types := by_type.keys()
	types.shuffle()
	var out: Array = []
	for wt in types.slice(0, n):
		# palier de la map, sinon le plus proche
		var best: Dictionary = {}
		for e in by_type[wt]:
			if best.is_empty() or absi(int(e.level) - lv) < absi(int(best.level) - lv):
				best = e
		var it := Items.from_template(best, Epochs.cap(stage), int(m.rarity))
		it["upgrade"] = 0
		it["auto_variant"] = randi() % 2
		out.append(it)
	return out


static func title(box: String) -> String:
	return String(BOXES.get(box, {}).get("name", "Coffre"))


static func is_cards(box: String) -> bool:
	return BOXES.get(box, {}).has("cards")
