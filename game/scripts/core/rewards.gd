class_name Rewards
extends RefCounted
## Coffres de récompense, ouverts hors run (menu Coffres) : boss du donjon (100 %), élites
## (20 %), monstres (0,5 %). Ramassés, ils vont tout de suite dans le menu Coffres et ne se
## perdent jamais. **Seule source des objets mythiques et légendaires.**
## Chaque coffre : {id, type, plevel}.
## - équipement : un objet mythique (légendaire : 20 %, 35 % pour un coffre de boss) ;
## - forge : parchemins de fortification, pierres de sûreté, ciseaux, parfois un parchemin béni, cristaux ;
## - joaillier : gemmes et parchemins d'enchantement ;
## - set : choisir 1 pièce mythique parmi 3 pièces d'un même set ;
## - trophées : choisir 1 trophée parmi 3.
## Objets : au coffre commun ; fournitures : à la réserve (emportée à la prochaine run).

const TYPES := {
	"gear": {"name": "Coffre d'équipement", "desc": "Un objet mythique (parfois légendaire) de ton niveau.", "color": Color(1.0, 0.55, 0.15)},
	"forge": {"name": "Coffre de forge", "desc": "Pierres de chance et de protection, ciseaux de sertissage, cristaux.", "color": Color(0.85, 0.85, 0.9)},
	"jewel": {"name": "Coffre du joaillier", "desc": "Gemmes et parchemins d'enchantement.", "color": Color(0.42, 0.9, 0.42)},
	"set": {"name": "Coffre de set", "desc": "Choisis 1 pièce mythique (parfois légendaire) parmi 3 pièces d'un même set.", "color": Color(1.0, 0.84, 0.25)},
	"trophy": {"name": "Coffre de trophées", "desc": "Choisis 1 trophée parmi 3.", "color": Color(1.0, 0.82, 0.3)},
	# coffres d'apparence (boss de Survie, paliers de la Tour) : une apparence au hasard, jamais
	# un doublon ; leur qualité fixe la rareté de l'apparence
	"look_common": {"name": "Coffre d'apparence commun", "desc": "Une apparence que tu n'as pas encore, commune ou spéciale.", "color": Color(0.75, 0.8, 0.9)},
	"look_rare": {"name": "Coffre d'apparence rare", "desc": "Une apparence que tu n'as pas encore, rare ou épique.", "color": Color(0.4, 0.65, 1.0)},
	"look_epic": {"name": "Coffre d'apparence mythique", "desc": "Une apparence mythique que tu n'as pas encore.", "color": Color(1.0, 0.55, 0.15)},
	"look_legend": {"name": "Coffre d'apparence légendaire", "desc": "Une apparence légendaire que tu n'as pas encore.", "color": Color(1.0, 0.86, 0.3)},
	# coffres d'auras (Panthéon) : une aura de la collection que tu n'as pas
	"aura_rare": {"name": "Coffre d'auras rare", "desc": "Une aura rare que tu n'as pas encore.", "color": Color(0.45, 0.8, 1.0)},
	"aura_legend": {"name": "Coffre d'auras légendaire", "desc": "Une aura légendaire que tu n'as pas encore.", "color": Color(1.0, 0.7, 0.95)},
}
const ORDER := ["aura_legend", "aura_rare", "look_legend", "look_epic", "look_rare", "look_common", "set", "trophy", "gear", "forge", "jewel"]
## Raretés (de la collection d'Eden) de chaque coffre d'apparence, du commun au légendaire.
const LOOKS := {"look_common": [0, 1], "look_rare": [2, 3], "look_epic": [4], "look_legend": [5]}
const LOOK_TYPES := ["look_common", "look_rare", "look_epic", "look_legend"]
## Raretés d'Eden des auras de chaque coffre d'auras.
const AURAS := {"aura_rare": [2], "aura_legend": [5]}


## Coffre d'apparence de qualité [param tier] (0 commun … 3 légendaire).
static func look_type(tier: int) -> String:
	return LOOK_TYPES[clampi(tier, 0, LOOK_TYPES.size() - 1)]


## Apparence portable (tenue, accessoire, skin d'arme, aura) pas encore obtenue, de la rareté
## du coffre [param type] ; sinon d'une autre rareté (la plus proche) ; {} si tout est obtenu.
static func roll_look(type: String) -> Dictionary:
	var free := GameData.collection.filter(func(x): return not Profile.collected(x) 		and (x.has("aura") or x.has("skin") or (int(x.get("cat", 9)) <= 3 and GameData.cosmetic_by_code.has(String(x.get("code", ""))))) 		and not String(x.get("name", "")).contains("(Alpha)"))
	if free.is_empty():
		return {}
	var want: Array = LOOKS.get(type, [0, 1])
	for gap in 6:
		var pool := free.filter(func(x): return want.any(func(r): return absi(int(x.get("rarity", 0)) - int(r)) <= gap))
		if not pool.is_empty():
			return pool.pick_random()
	return free.pick_random()


## Aura de la collection pas encore obtenue, de la rareté du coffre d'auras [param type].
static func roll_aura(type: String) -> Dictionary:
	var want: Array = AURAS.get(type, [2])
	var free := GameData.collection.filter(func(x): return x.has("aura") and not Profile.collected(x) and want.has(int(x.get("rarity", 0))))
	return free.pick_random() if not free.is_empty() else {}


static func make(type: String, plevel: int, boss := false) -> Dictionary:
	var c := {"id": "%d_%d" % [Time.get_ticks_usec(), randi() % 100000], "type": type, "plevel": maxi(plevel, 1),
		"zone": Run.zone_id if Run.active else ""}
	if boss:
		c["boss"] = true
	return c


## Zone d'où vient [param chest] (objets de son époque d'Eden) ; anciens coffres : la
## première zone dont les niveaux de run couvrent son niveau.
static func zone_of(chest: Dictionary) -> String:
	var z := String(chest.get("zone", ""))
	if z != "" and GameData.zones.any(func(x): return String(x.id) == z):
		return z
	var lv := int(chest.get("plevel", 1))
	for i in GameData.zones.size():
		if lv <= GameData.zone_run_levels(i).y:
			return String(GameData.zones[i].id)
	return String(GameData.zones[-1].id) if not GameData.zones.is_empty() else ""


## Rareté d'un objet de coffre : mythique, ou légendaire (20 %, 35 % pour un coffre de boss).
static func top_rarity(chest: Dictionary) -> int:
	return Items.LEGENDARY if randf() < (0.35 if chest.get("boss", false) else 0.2) else Items.MYTHIC


## Coffre tiré au sort pour un monstre ([param boss], [param elite]).
static func roll_type(boss := false) -> String:
	var r := randf()
	if boss:
		return "set" if r < 0.6 else "gear"  # (plus de coffres de trophées : collection de la run)
	return "gear" if r < 0.45 else ("forge" if r < 0.72 else "jewel")


## Objet de butin (LootDrop) représentant un coffre.
static func loot_item(chest: Dictionary) -> Dictionary:
	var t: Dictionary = TYPES[chest.type]
	return {"chest": chest, "name": String(t.name), "icon": MenuWidgets.ICONS % "chest", "rarity": 3 if chest.type in ["set", "trophy"] else 2}


static func is_choice(chest: Dictionary) -> bool:
	return chest.type in ["set", "trophy"]


## Propositions d'un coffre à choix (tirées une fois, gardées dans le coffre).
static func offer(chest: Dictionary) -> Array:
	if not chest.has("zone"):
		# coffre d'avant 0.1.119 : propositions tirées dans la zone du lobby, retirées une fois
		chest.erase("offer")
		chest["zone"] = zone_of(chest)
	if chest.has("offer"):
		return chest.offer
	var out: Array = []
	var lv := int(chest.plevel)
	Items.reward_zone = zone_of(chest)
	if false:
		pass  # (ancien coffre de trophées : il donne des pièces de set, comme un coffre de set)
	else:
		var pieces := set_pieces(lv)
		var rar := top_rarity(chest)
		for e in pieces:
			out.append(Items.from_template(e, lv, rar))
		while out.size() < 3:
			out.append(Items.generate(lv, 1.0, "", Profile.selected_class, Items.MYTHIC, "", Items.MYTHIC))
	Items.reward_zone = ""
	chest["offer"] = out
	return out


## 3 pièces d'un set d'Eden qui existe au niveau visé (chronologie des zones).
static func set_pieces(plevel: int) -> Array:
	var target := Items.eden_target(plevel)
	var sets: Array = GameData.eden_sets.keys().filter(func(k):
		var ps: Array = GameData.eden_sets[k].get("pieces", [])
		if ps.size() < 3:
			return false
		var e: Dictionary = GameData.eden_by_id.get(int(ps[0]), {})
		return not e.is_empty() and int(e.level) <= maxi(target, 30))
	if sets.is_empty():
		return []
	sets.sort_custom(func(a, b): return int(GameData.eden_by_id[int(GameData.eden_sets[a].pieces[0])].level) > int(GameData.eden_by_id[int(GameData.eden_sets[b].pieces[0])].level))
	var sid: String = sets.slice(0, mini(6, sets.size())).pick_random()
	var ps: Array = (GameData.eden_sets[sid].pieces as Array).duplicate()
	ps.shuffle()
	var out: Array = []
	for pid in ps:
		var e: Dictionary = GameData.eden_by_id.get(int(pid), {})
		if not e.is_empty() and not GearShopPage.owned(int(pid)) and not Archive.owned(e):
			out.append(e)  # une pièce déjà possédée (coffre commun, archive) n'est plus proposée
		if out.size() >= 3:
			break
	return out


## Contenu possible d'un coffre, en texte (mêmes règles que [method open] : l'aperçu ne ment pas).
static func preview(chest: Dictionary) -> String:
	var lv := int(chest.plevel)
	var t := String(chest.type)
	match t:
		"gear":
			return "Un objet mythique de niveau %d (légendaire : %d %% de chances)." % [lv, 35 if chest.get("boss", false) else 20]
		"forge":
			return "1-2 parchemins de puissance et 1-3 de garde (niveau %d), 1-2 pierres de sûreté, 1 pierre de chance, 2 pierres, parfois des ciseaux (50 %%) et un parchemin béni (20 %%), %d-%d cristaux." % [
				Craft.fortify_level_at(lv), 3 + lv / 10, 6 + lv / 10]
		"jewel":
			return "2 gemmes de rang %d et 1 parchemin d'enchantement." % (clampi(lv / 12, 0, Craft.GEM_TIERS.size() - 1) + 1)
		"set", "trophy":
			return "3 pièces mythiques d'un même set au choix (déjà possédées : jamais proposées) ; légendaire : %d %%." % (35 if chest.get("boss", false) else 20)
	if AURAS.has(t):
		var left := GameData.collection.filter(func(x): return x.has("aura") and not Profile.collected(x) and (AURAS[t] as Array).has(int(x.get("rarity", 0)))).size()
		return "Une aura que tu n'as pas (%d encore à trouver à cette rareté) ; toutes obtenues : 60 insignes." % left
	if LOOKS.has(t):
		var free := GameData.collection.filter(func(x): return not Profile.collected(x) 			and (x.has("aura") or x.has("skin") or (int(x.get("cat", 9)) <= 3 and GameData.cosmetic_by_code.has(String(x.get("code", ""))))) 			and not String(x.get("name", "")).contains("(Alpha)") and (LOOKS[t] as Array).has(int(x.get("rarity", 0))))
		return "Une apparence que tu n'as pas (%d encore à trouver à cette rareté) ; tout obtenu : 30 cristaux." % free.size()
	return String(TYPES[t].desc)


## Additionne le contenu de plusieurs coffres ouverts.
static func merge_got(a: Dictionary, b: Dictionary) -> Dictionary:
	a["items"] = (a.get("items", []) as Array) + (b.get("items", []) as Array)
	a["looks"] = (a.get("looks", []) as Array) + (b.get("looks", []) as Array)
	var sup: Dictionary = a.get("supplies", {})
	for k in b.get("supplies", {}):
		sup[k] = int(sup.get(k, 0)) + int(b.supplies[k])
	a["supplies"] = sup
	a["crystal"] = int(a.get("crystal", 0)) + int(b.get("crystal", 0))
	return a


## Ouvre tous les coffres sans choix de [param chests] ; renvoie le récapitulatif additionné et le nombre ouvert.
static func open_all(chests: Array) -> Dictionary:
	var total := {"items": [], "looks": [], "supplies": {}, "crystal": 0, "opened": 0}
	for c in chests.duplicate():
		if is_choice(c) or not Profile.reward_chests.has(c):
			continue
		merge_got(total, open(c))
		total["opened"] = int(total.opened) + 1
	return total


## Phrase de récapitulatif (« 14 parchemins, 9 pierres, 47 cristaux, 2 apparences »).
static func summary(got: Dictionary) -> String:
	var scrolls := 0
	var stones := 0
	var gems := 0
	var other := 0
	for k in got.get("supplies", {}):
		var n := int(got.supplies[k])
		var lab := Craft.label(k).to_lower()
		if lab.contains("parchemin"):
			scrolls += n
		elif lab.contains("pierre"):
			stones += n
		elif lab.contains("gemme"):
			gems += n
		else:
			other += n
	var parts: PackedStringArray = []
	for e in [[scrolls, "parchemin(s)"], [stones, "pierre(s)"], [gems, "gemme(s)"], [other, "autre(s) fourniture(s)"],
			[int(got.get("crystal", 0)), "cristaux"], [(got.get("items", []) as Array).size(), "objet(s)"], [(got.get("looks", []) as Array).size(), "apparence(s)"]]:
		if int(e[0]) > 0:
			parts.append("%d %s" % [int(e[0]), e[1]])
	return ", ".join(parts) if not parts.is_empty() else "rien"


## Ouvre un coffre sans choix : le contenu est donné, le coffre retiré. Renvoie le contenu
## {items, supplies, crystal}.
static func open(chest: Dictionary) -> Dictionary:
	var got := {"items": [], "supplies": {}, "crystal": 0}
	var lv := int(chest.plevel)
	Items.reward_zone = zone_of(chest)
	if AURAS.has(String(chest.type)):
		var a := roll_aura(String(chest.type))
		if not a.is_empty():
			Profile.collect(a)
			got["looks"] = [a]
		else:
			Profile.insignia += 60  # toutes les auras de cette rareté sont obtenues : des insignes
	if LOOKS.has(String(chest.type)):
		# apparence au hasard, jamais un doublon (toute la collection obtenue : des cristaux)
		var x := roll_look(String(chest.type))
		if not x.is_empty():
			Profile.collect(x)
			got["looks"] = [x]
		else:
			got.crystal = 30
	match String(chest.type):
		"gear":
			var rar := top_rarity(chest)
			got.items.append(Items.generate(lv, 0.8, "", Profile.selected_class, rar, "", rar))
		"forge":
			# parchemins de fortification du niveau du coffre et pierres de sûreté
			var flv := Craft.fortify_level_at(lv)
			got.supplies = {Craft.fortify_key("power", flv): randi_range(1, 2), Craft.fortify_key("guard", flv): randi_range(1, 3),
				Craft.stone_key("safety"): randi_range(1, 2), Craft.stone_key("lucky"): 1}
			for i in 2:
				var st := Craft.random_stone(2)
				got.supplies[st] = int(got.supplies.get(st, 0)) + 1
			if randf() < 0.5:
				got.supplies["drill"] = 1
			if randf() < 0.2:
				got.supplies[Craft.BLESSED] = 1
			got.crystal = randi_range(3, 6) + lv / 10
		"jewel":
			for i in 2:
				var g := Craft.gem_key(Craft.GEMS.keys().pick_random(), clampi(lv / 12, 0, Craft.GEM_TIERS.size() - 1))
				got.supplies[g] = int(got.supplies.get(g, 0)) + 1
			var slv := Craft.scroll_level_for(lv)
			var sc := Craft.scroll_key(Craft.ENCHANTS.keys().pick_random(), slv) if slv > 0 else Craft.random_stone(1)
			got.supplies[sc] = 1
	Items.reward_zone = ""
	_give(got)
	Profile.reward_chests.erase(chest)
	Profile.save_profile()
	return got


## Coffre à choix : l'objet [param index] des propositions rejoint le coffre commun.
static func choose(chest: Dictionary, index: int) -> Dictionary:
	var items := offer(chest)
	var it: Dictionary = items[clampi(index, 0, items.size() - 1)]
	_give({"items": [it], "supplies": {}, "crystal": 0})
	Profile.reward_chests.erase(chest)
	Profile.save_profile()
	return it


static func _give(got: Dictionary) -> void:
	for it in got.items:
		Profile.inventory.append(it)  # hors run : l'inventaire affiché = le coffre commun
	for k in got.supplies:
		if int(got.supplies[k]) > 0:
			Profile.stash[k] = int(Profile.stash.get(k, 0)) + int(got.supplies[k])
	Profile.materials["crystal"] = int(Profile.materials.get("crystal", 0)) + int(got.crystal)


## Contenu en texte (BBCode).
static func got_text(got: Dictionary) -> String:
	var lines: PackedStringArray = []
	for it in got.get("items", []):
		lines.append("[color=#%s]%s[/color]" % [Items.color_of(it).to_html(false), Items.display_name(it)])
	for x in got.get("looks", []):
		lines.append("Apparence : %s" % String(x.name))
	for k in got.get("supplies", {}):
		if int(got.supplies[k]) > 0:
			lines.append("[img=20x20]%s[/img] %s ×%d" % [Craft.icon(k), Craft.label(k), int(got.supplies[k])])
	if int(got.get("crystal", 0)) > 0:
		lines.append("%s%d cristaux" % [ItemWidgets.icon_bb("crystal"), int(got.crystal)])
	return "\n".join(lines)
