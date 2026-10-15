class_name SlotChests
extends RefCounted
## Coffres d'emplacement de la Survie (DESIGN.md, « Boucle de jeu et Survie ») : chaque coffre
## payant de la map vise un emplacement (arme, tête, torse…, cape, bijoux, trophée) ou un type de
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
	"back": {"name": "Coffre de cape", "slots": ["back"], "look": 0, "price": 1.0},
	"jewel": {"name": "Coffre de bijoux", "slots": ["ring", "necklace"], "look": 2, "price": 1.3},
	"trophy": {"name": "Coffre de trophée", "slots": ["trophy"], "look": 2, "price": 1.5},
	"spell": {"name": "Coffre de sort", "cards": "spell", "look": 1, "price": 1.2},
	"passive": {"name": "Coffre de passif", "cards": "passive", "look": 1, "price": 1.2},
	"cert": {"name": "Coffre de certificat", "cards": "cert", "look": 1, "price": 1.4},
}
## Les 30 coffres d'une map (mélangés sur la carte ; autant que ProcMap.CHEST_COUNT).
## 4 coffres de trophée par map : jusqu'à 12 trophées par run (Run.MAX_TROPHIES). Capes (0.1.179) : 2 coffres
## pris aux gants et aux bottes, les 9 emplacements de la PE se trouvent tous en Survie.
const LAYOUT := ["weapon", "weapon", "head", "head", "head", "chest", "chest", "chest", "legs", "legs", "legs",
	"gloves", "gloves", "boots", "boots", "back", "back", "jewel", "jewel", "jewel", "trophy", "trophy", "trophy", "trophy",
	"spell", "spell", "spell", "passive", "passive", "cert"]


## Écart maximal (niveaux) entre le palier de la map et une pièce prise en dessous faute de pièce exacte.
const POOL_WINDOW := 20


## Types des [param n] coffres d'une map, mélangés avec [param rng].
static func layout(n: int, rng: RandomNumberGenerator) -> Array:
	var base: Array = LAYOUT
	if "--no-cape" in OS.get_cmdline_user_args():
		base = LAYOUT.duplicate()  # mesures : la répartition d'avant les capes (3 gants, 3 bottes)
		base[base.find("back")] = "gloves"
		base[base.find("back")] = "boots"
	var out: Array = []
	while out.size() < n:
		out.append_array(base)
	out = out.slice(0, n)
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = out[i]
		out[i] = out[j]
		out[j] = t
	return out


## Toutes les pièces d'Eden que peut donner un coffre [param box] sur la map [param stage]
## de l'époque [param epoch] : son emplacement, au palier de la map (le plus proche en
## dessous s'il n'y en a pas), à sa rareté (pièces « Awaken » pour l'éveillé). Coffre d'arme : armes
## du type [param wtype] (par défaut celui de la classe jouée ou affichée).
static func pool(box: String, epoch: int, stage: int, wtype := "") -> Array:
	var m := Epochs.map_def(epoch, stage)
	var out: Array = []
	for slot in BOXES[box].get("slots", []):
		var lv := int(m.weapon) if slot == "weapon" else int(m.armor)
		var rarity := int(m.rarity)
		var awakened: bool = m.get("awakened", false) and slot in ["head", "chest", "legs", "gloves", "boots"]
		var main := wtype if wtype != "" else Profile.main_weapon_type()  # coffre d'arme : l'arme principale, du type de la classe
		var cands: Array = GameData.eden_items.filter(func(e): return String(e.get("slot", "")) == slot \
			and (slot != "weapon" or String(e.get("wtype", "")) == main) and Trophies.in_pool(e) and (int(e.rarity) == rarity or (slot == "trophy" and int(e.rarity) >= Items.MYTHIC)) \
			and GameData.is_awakened(e) == awakened)
		if cands.is_empty():
			continue
		# palier exact, sinon le plus haut en dessous (à POOL_WINDOW niveaux au plus), sinon le plus bas
		# au-dessus, sinon le plus haut en dessous (0.1.179 : plus de légendaire de niveau 1 au palier 60)
		var below := cands.filter(func(e): return int(e.level) <= lv)
		var target := -1
		for e in below:
			if slot == "trophy" or int(e.level) >= lv - POOL_WINDOW:
				target = maxi(target, int(e.level))
		if target < 0:
			var above := cands.filter(func(e): return int(e.level) > lv)
			for e in (above if not above.is_empty() else below):
				target = int(e.level) if target < 0 else (mini(target, int(e.level)) if not above.is_empty() else maxi(target, int(e.level)))
		if slot == "trophy":
			out.append_array(cands.filter(func(e): return int(e.level) <= lv and int(e.level) >= lv - 12) if below.size() > 0 else cands.filter(func(e): return int(e.level) == target))
		else:
			out.append_array(cands.filter(func(e): return int(e.level) == target))
	return out


## [param n] pièces au hasard d'un coffre [param box] (sans doublon), +0, puissance plafonnée
## au niveau maximal de la map.
static func offer(box: String, epoch: int, stage: int, n := 3) -> Array:
	if box == "trophy":
		return trophy_offer(epoch, stage, n)
	var p := pool(box, epoch, stage)
	p.shuffle()
	var m := Epochs.map_def(epoch, stage)
	var out: Array = []
	for e in p.slice(0, n):
		var it := Items.from_template(e, Epochs.cap(stage), int(m.rarity) if String(e.slot) != "trophy" else int(e.rarity))
		it["upgrade"] = 0
		if m.get("awakened", false) and GameData.is_awakened(e):
			it["awakened"] = true
		out.append(it)
	return out


## Trophées proposés : [param n] effets différents que la collection de la run n'a pas encore ;
## pour chaque effet, le trophée d'Eden dont le niveau est le plus proche de celui de la map
## (variantes de niveau : plus forts aux époques avancées).
static func trophy_offer(epoch: int, stage: int, n := 3) -> Array:
	var lv := int(Epochs.map_def(epoch, stage).armor)
	var owned: Array = Run.trophy_kinds() if Run.active else []
	var by_kind := {}
	for e in GameData.eden_items:
		if String(e.get("slot", "")) != "trophy" or not Trophies.in_pool(e) or String(e.get("trophy", "")) in owned \
				or (Run.active and int(e.id) in Run.seen_items):
			continue
		var k := String(e.trophy)
		if not by_kind.has(k):
			by_kind[k] = []
		by_kind[k].append(e)
	var kinds := by_kind.keys()
	kinds.shuffle()
	var out: Array = []
	for k in kinds.slice(0, n):
		var best: Dictionary = {}
		for e in by_kind[k]:
			var d := absi(int(e.level) - lv)
			if best.is_empty() or d < absi(int(best.level) - lv) or (d == absi(int(best.level) - lv) and randf() < 0.5):
				best = e
		out.append(Items.from_template(best, Epochs.cap(stage), int(best.rarity)))
	return out


## Arme secondaire trouvée en jeu (élites, boss de la Survie) : [param n] armes de types
## différents (aucune du type de la classe), tirées comme un coffre d'arme de ce type sur la map
## (même palier, même rareté : la pièce rejoint l'Armurerie comme les autres), chacune avec une de
## ses deux variantes au hasard.
static func offhand_offer(epoch: int, stage: int, n := 3) -> Array:
	var main := Profile.main_weapon_type()
	var types := weapon_types().filter(func(wt): return wt != main)
	types.shuffle()
	var out: Array = []
	for wt in types:
		if out.size() >= n:
			break
		var p := pool("weapon", epoch, stage, wt)
		if p.is_empty():
			continue
		var it := Items.from_template(p.pick_random(), Epochs.cap(stage), int(Epochs.map_def(epoch, stage).rarity))
		it["upgrade"] = 0
		it["auto_variant"] = randi() % 2
		out.append(it)
	return out


static var _wtypes: Array = []


## Types d'arme qui ont des pièces d'Eden (les 17 types des classes), dans un ordre fixe.
static func weapon_types() -> Array:
	if _wtypes.is_empty():
		var seen := {}
		for e in GameData.eden_items:
			if String(e.get("slot", "")) == "weapon" and String(e.get("wtype", "")) != "":
				seen[String(e.wtype)] = true
		_wtypes = seen.keys()
		_wtypes.sort()
	return _wtypes.duplicate()


## Les armes « sœurs » de la map [param stage] de l'époque [param epoch] : pour chacun des types d'arme,
## les pièces qu'un coffre d'arme de ce type y proposerait (id d'Eden). Une arme choisie en Survie les
## fait toutes découvrir (Armurerie) : n'importe quelle classe peut ainsi viser l'arme de son type, et toute
## classe s'équiper d'une arme secondaire de n'importe quel type (DESIGN.md, « Les types d'arme »).
## Un type sans pièce près du palier (la seule de cette rareté est bien plus haut) n'en donne pas : elle
## sera découverte à l'époque de son niveau, pas à l'Armurerie dès l'époque I.
static func weapon_family(epoch: int, stage: int) -> Array:
	var lv := int(Epochs.map_def(epoch, stage).weapon)
	var out: Array = []
	for wt in weapon_types():
		for e in pool("weapon", epoch, stage, wt):
			if absi(int(e.level) - lv) <= POOL_WINDOW:
				out.append(int(e.id))
	return out


static func title(box: String) -> String:
	return String(BOXES.get(box, {}).get("name", "Coffre"))


static func is_cards(box: String) -> bool:
	return BOXES.get(box, {}).has("cards")
