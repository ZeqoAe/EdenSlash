class_name Goals
extends RefCounted
## Objectifs d'équipement (lot GX-3, P0-6 de l'étude BM-GEAR) : « voici la pièce que je veux, voici ce qui me manque ».
## Une pièce épinglée et cinq suivies au plus (Q5). État dans `Profile.records.goals` = {"pinned": id, "list": [ids]} (aucun
## champ nouveau dans Profile) ; un id est l'id d'Eden d'une pièce de l'Atelier (« 1234 ») ou un plan de donjon et son
## emplacement (« plan_<boss>:<emplacement> »).
## Ce qui manque ([method status]) : le plan (et où le trouver), les insignes (≈ N cartes de Survie), le niveau de héros ;
## l'objectif se montre dans la barre d'objectif (GoalBar : Héros, en-tête de l'Atelier), par ★ sur les cases et listes,
## dans le filtre « Objectifs » de Fabriquer et au bilan de la Survie (plan trouvé).

const KEY := "goals"
## 1 épinglé + 5 suivis.
const MAX := 6
const DUNGEON := "plan_"

static var _previews := {}  # id -> pièce d'aperçu (Atelier : la pièce +0 telle qu'elle se fabrique)


static func _data() -> Dictionary:
	var d = Profile.records.get(KEY, null)
	if not d is Dictionary:
		d = {"pinned": "", "list": []}
		Profile.records[KEY] = d
	if not (d.get("list", null) is Array):
		d["list"] = []
	if not d.has("pinned"):
		d["pinned"] = ""
	return d


## Les objectifs, l'épinglé d'abord.
static func ids() -> Array:
	var d := _data()
	var out: Array = []
	var p := String(d.pinned)
	if p != "" and p in d.list:
		out.append(p)
	for g in d.list:
		if String(g) != p:
			out.append(String(g))
	return out


static func pinned() -> String:
	var d := _data()
	var p := String(d.pinned)
	if p != "" and p in d.list:
		return p
	return String(d.list[0]) if not (d.list as Array).is_empty() else ""


static func has(id: String) -> bool:
	return id in _data().list


static func count() -> int:
	return (_data().list as Array).size()


static func piece_id(eden: int) -> String:
	return str(eden)


static func dungeon_id(bid: String, slot: String) -> String:
	return "%s%s:%s" % [DUNGEON, bid, slot]


static func is_dungeon(id: String) -> bool:
	return id.begins_with(DUNGEON)


## Suit [param id] et l'épingle (le dernier souhait passe devant) ; renvoie le message à montrer.
static func follow(id: String) -> String:
	if id == "":
		return ""
	var d := _data()
	if not id in d.list:
		if (d.list as Array).size() >= MAX:
			return "%d objectifs au plus : retires-en un d'abord." % MAX
		d.list.append(id)
	d.pinned = id
	Profile.save_profile()
	return "★ Objectif : %s" % name_of(id)


static func unfollow(id: String) -> void:
	var d := _data()
	d.list.erase(id)
	if String(d.pinned) == id:
		d.pinned = String(d.list[0]) if not (d.list as Array).is_empty() else ""
	Profile.save_profile()


## Suit ou ne suit plus [param id] ; renvoie le message.
static func toggle(id: String) -> String:
	if has(id):
		unfollow(id)
		return "Objectif retiré : %s" % name_of(id)
	return follow(id)


static func pin(id: String) -> void:
	if has(id):
		_data().pinned = id
		Profile.save_profile()


## Épingle l'objectif suivant de la liste (la barre d'objectif fait défiler les objectifs suivis).
static func pin_next() -> void:
	var l := ids()
	if l.size() < 2:
		return
	pin(String(l[1]))


## Retire les objectifs atteints (pièce fabriquée et portée) ; renvoie les noms retirés.
static func prune_done() -> Array:
	var out: Array = []
	for id in ids():
		var s := status(id)
		if bool(s.get("worn", false)):
			out.append(String(s.name))
			unfollow(id)
	return out


# --- ce qui manque ---------------------------------------------------------------------------------------------------
static func _boss(id: String) -> String:
	return id.trim_prefix(DUNGEON).get_slice(":", 0)


static func _slot(id: String) -> String:
	return id.get_slice(":", 1)


## La pièce visée (aperçu : celle que le plan fabrique), {} si l'id ne correspond à rien.
static func item_of(id: String) -> Dictionary:
	if is_dungeon(id):
		var bid := _boss(id)
		if not BossLibrary.has(bid):
			return {}
		return FabricationPage.preview(bid, _slot(id))
	if not _previews.has(id):
		var e: Dictionary = GameData.eden_by_id.get(int(id), {})
		_previews[id] = GearShopPage.make(e) if not e.is_empty() else {}
	return _previews[id]


static func name_of(id: String) -> String:
	var it := item_of(id)
	return Items.display_name(it) if not it.is_empty() else "?"


## La pièce de l'objectif possédée (coffre commun ou portée), {} sinon.
static func owned_item(id: String) -> Dictionary:
	if is_dungeon(id):
		var arch := String(BossLibrary.loot(_boss(id)).archetype)
		var slot := _slot(id)
		for it in Profile.all_items():
			if String(it.get("archetype", "")) == arch and String(it.get("slot", "")) == slot:
				return it
		return {}
	for it in Profile.all_items():
		if int(it.get("eden", -1)) == int(id):
			return it
	return {}


## État de l'objectif [param id] : {id, name, item, dungeon, plan (plan connu), place (où trouver le plan), price, short
## (insignes qui manquent), req (niveau requis), level (niveau de héros), owned, worn, ready (fabricable maintenant), steps
## [{text, ok}], line (ce qui manque, une phrase), go (où aller : {"workshop": i} ou {"menu": …})}.
static func status(id: String) -> Dictionary:
	var it := item_of(id)
	var dg := is_dungeon(id)
	var out := {"id": id, "item": it, "dungeon": dg, "name": Items.display_name(it) if not it.is_empty() else "?"}
	if it.is_empty():
		out.merge({"plan": false, "place": "", "price": 0, "short": 0, "req": 0, "level": HeroLevel.level(), "owned": false,
			"worn": false, "ready": false, "steps": [], "line": "pièce inconnue", "go": {}})
		return out
	var bid := _boss(id) if dg else ""
	var plan := Dungeons.has_plan(bid) if dg else int(id) in Profile.seen_gear
	var place := ""
	if dg:
		place = Dungeons.plan_source(bid)
	elif not Completion._armory_ids.is_empty() or not Profile.in_run:
		place = Completion.plan_place(int(id))
	var price := FabricationPage.cost(bid) if dg else Economy.armory_price(GameData.eden_by_id.get(int(id), {}))
	var short := maxi(0, price - Profile.insignia)
	var req := Items.required_level(it)
	var hl := HeroLevel.level()
	var mine := owned_item(id)
	var worn := not mine.is_empty() and Profile.slot_of(mine) != ""
	var steps: Array = []
	if not mine.is_empty():
		steps.append({"text": "Fabriquée", "ok": true})
	else:
		steps.append({"text": "Plan ✓" if plan else "Plan à trouver", "ok": plan})
		steps.append({"text": "Insignes %s / %s" % [GearPower.fmt(mini(Profile.insignia, price)), GearPower.fmt(price)], "ok": short == 0})
	steps.append({"text": "Niveau %d / %d" % [mini(hl, maxi(req, 1)), maxi(req, 1)], "ok": hl >= req})
	var line := ""
	var go := {}
	if worn:
		line = "objectif atteint : la pièce est portée"
		go = {"hero": "equipment"}
	elif not mine.is_empty():
		line = "fabriquée : porte-la (Héros)" if hl >= req else "fabriquée · à porter au niveau %d" % req
		go = {"hero": "equipment"}
	elif not plan:
		line = "plan à trouver : %s" % (place.trim_suffix(".") if place != "" else "coffres d'emplacement de la Survie")
		go = {"menu": "dungeon", "zone": Dungeons.boss_zone(bid)} if dg else {"menu": "survival"}
	elif short > 0:
		line = Economy.missing_text(price)
		go = {"menu": "survival"}
	elif hl < req:
		line = "prête à fabriquer · à porter au niveau %d" % req
		go = {"workshop": 1 if dg else 0}
	else:
		line = "prête à fabriquer · %s" % GearPower.plural(price, "insigne")
		go = {"workshop": 1 if dg else 0}
	out.merge({"plan": plan, "place": place, "price": price, "short": short, "req": req, "level": hl, "owned": not mine.is_empty(),
		"worn": worn, "ready": plan and short == 0 and mine.is_empty(), "steps": steps, "line": line, "go": go})
	return out


## Ligne courte de l'objectif épinglé : « ★ Casque du Bouclier antique · il en manque 37 ≈ 1 carte de Survie » ("" sans objectif).
static func line() -> String:
	var p := pinned()
	if p == "":
		return ""
	var s := status(p)
	return "★ %s · %s" % [String(s.name), String(s.line)]


## Conseil de la boussole pour l'objectif épinglé (même forme que Compass._make), {} sans objectif ou s'il est atteint.
static func advice() -> Dictionary:
	var p := pinned()
	if p == "" or Profile.in_run:
		return {}
	var s := status(p)
	if bool(s.worn) or (s.go as Dictionary).is_empty():
		return {}
	return {"id": "goal", "text": "★ Objectif : %s · %s" % [String(s.name), String(s.line)], "tip": "Ton objectif épinglé (Atelier > Fabriquer, « ★ Objectif »).",
		"icon": "piece", "go": s.go, "family": "gear"}


## Bilan : les objectifs dont le plan vient d'être trouvé parmi [param eden_ids] (ids d'Eden des plans découverts).
static func found_in(eden_ids: Array) -> Array:
	var out: Array = []
	for id in ids():
		if not is_dungeon(String(id)) and int(id) in eden_ids:
			out.append(name_of(String(id)))
	return out


## Id d'objectif de la pièce [param item] (pièce d'Eden de l'Atelier), "" sinon.
static func id_for_item(item: Dictionary) -> String:
	if item.has("eden") and not item.get("sv", false):
		return piece_id(int(item.eden))
	return ""


## La pièce [param item] est-elle la pièce d'un objectif ?
static func is_goal_item(item: Dictionary) -> bool:
	var g := id_for_item(item)
	return g != "" and has(g)
