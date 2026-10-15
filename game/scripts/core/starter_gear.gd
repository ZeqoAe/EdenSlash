class_name StarterGear
extends RefCounted
## Équipement de départ (0.1.164) : la Survie part avec l'équipement du hub, donc un compte neuf doit
## en avoir un. Pour chaque classe : 8 pièces d'Eden communes, spéciales ou rares (la plus rare qui
## existe pour l'emplacement) d'un palier de l'époque I (niveau 10 à 30, le plus proche de 20 : plafond de
## puissance ≥ celui de la 1re map), à +0, qualité fixe. Remises une seule fois par classe (`Profile.starter_done`) quand son préréglage
## actif n'a aucune pièce d'armure. Au-delà, le joueur progresse par l'Armurerie (pièces mythiques
## vues en coffre, achetées avec les insignes) et par l'Atelier (+N, gemmes, enchantements).

const SLOTS := ["weapon", "head", "chest", "legs", "gloves", "boots", "ring", "necklace"]
const ARMOR := ["head", "chest", "legs", "gloves", "boots"]
const TARGET_LEVEL := 20
const MAX_RARITY := 2
const QUALITY := 1.0


## Pièces de départ de la classe [param cid] : emplacement -> objet neuf.
static func items(cid: String) -> Dictionary:
	var out := {}
	var wtype := Items.default_weapon_type(cid)
	for slot in SLOTS:
		var it := _pick(slot, wtype)
		if not it.is_empty():
			out[slot] = it
	return out


static func _pick(slot: String, wtype: String) -> Dictionary:
	var list: Array = GameData.eden_by_slot.get(wtype if slot == "weapon" else slot, [])
	for window in [[10, 30], [5, 35], [1, 45]]:
		var cands := list.filter(func(e): return int(e.rarity) <= MAX_RARITY and Trophies.in_pool(e) \
			and (not (e.get("r", {}) as Dictionary).is_empty() or e.has("passive")) \
			and not GameData.is_awakened(e) and int(e.level) >= int(window[0]) and int(e.level) <= int(window[1]))
		if cands.is_empty():
			continue
		var rmax := 0  # la plus rare d'abord, puis le palier le plus proche de TARGET_LEVEL
		for e in cands:
			rmax = maxi(rmax, int(e.rarity))
		var rares := cands.filter(func(e): return int(e.rarity) == rmax)
		var best := 999
		for e in rares:
			best = mini(best, absi(int(e.level) - TARGET_LEVEL))
		var near := rares.filter(func(e): return absi(int(e.level) - TARGET_LEVEL) <= best + 2)
		var e: Dictionary = near.pick_random()
		var it := Items.from_template(e, int(e.level), int(e.rarity))
		it["upgrade"] = 0
		it["quality"] = QUALITY
		it["starter"] = true
		return it
	return {}


## Équipement de mesure (arguments --hub= des mesures d'équilibrage, tests) : « E.C.N[.G] » = pièces
## des coffres de l'époque E, carte C, améliorées à +N, avec 2 gemmes de palier G par pièce (G < 0 ou
## absent : aucune) et un enchantement sur l'arme. Sans cohérence de panoplie (pièces au hasard).
## Cape comprise (0.1.179) ; « E.C.N.G.0 » : sans cape (mesure de ce qu'elle apporte).
static func scenario(spec: String, cid: String) -> Dictionary:
	var p := spec.split(".")
	var epoch := int(p[0]) if p.size() > 0 else 1
	var stage := int(p[1]) if p.size() > 1 else 3
	var up := int(p[2]) if p.size() > 2 else 10
	var gem := int(p[3]) if p.size() > 3 else -1
	var cape := int(p[4]) != 0 if p.size() > 4 else true
	var out := {}
	var jewels := ["ring", "necklace"]
	for box in ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "jewel", "jewel"]:
		if box == "back" and not cape:
			continue
		var offer := SlotChests.offer("jewel" if box == "jewel" else box, epoch, stage, 6)
		if box == "jewel":
			offer = offer.filter(func(it): return String(it.slot) == String(jewels[0]))
			jewels.pop_front()
		if offer.is_empty():
			continue
		var it: Dictionary = offer[0]
		it["upgrade"] = clampi(up, 0, Items.MAX_UPGRADE)
		if gem >= 0:
			var ga := "garnet" if String(it.slot) != "weapon" else ("sapphire" if Items.weapon_type_of(it) in ["staff", "scepter"] else "ruby")
			var gb := "onyx" if String(it.slot) != "weapon" else "amethyst"
			it["sockets"] = [{"type": ga, "tier": gem}, {"type": gb, "tier": gem}]
		if String(it.slot) == "weapon":
			it["enchant"] = {"type": "optimize", "lv": clampi(1 + epoch * 2, 1, 9)} if gem >= 0 else it.get("enchant", {})
			if (it.enchant as Dictionary).is_empty():
				it.erase("enchant")
		out[String(it.slot)] = it
	return out


## Le préréglage actif de la classe n'a aucune pièce d'armure (compte neuf, ou équipement à refaire).
static func needs(slots: Dictionary) -> bool:
	for slot in ARMOR:
		if slots.has(slot):
			return false
	return true
