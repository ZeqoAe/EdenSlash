class_name Rewards
extends RefCounted
## Coffres de récompense, ouverts hors run (menu Coffres) : ils tombent des monstres
## (rarement), des élites et des boss, et se gardent après une victoire ou une extraction
## (perdus si le héros tombe). Chaque coffre : {id, type, plevel}.
## - équipement : un objet rare à épique (parfois mythique) ;
## - forge : pierres de chance et de protection, ciseaux, cristaux ;
## - joaillier : gemmes et parchemins d'enchantement ;
## - set : choisir 1 pièce mythique parmi 3 pièces d'un même set ;
## - trophées : choisir 1 trophée parmi 3.
## Objets : au coffre commun ; fournitures : à la réserve (emportée à la prochaine run).

const TYPES := {
	"gear": {"name": "Coffre d'équipement", "desc": "Un objet rare à épique (parfois mythique) de ton niveau.", "color": Color(0.4, 0.66, 1.0)},
	"forge": {"name": "Coffre de forge", "desc": "Pierres de chance et de protection, ciseaux de sertissage, cristaux.", "color": Color(0.85, 0.85, 0.9)},
	"jewel": {"name": "Coffre du joaillier", "desc": "Gemmes et parchemins d'enchantement.", "color": Color(0.42, 0.9, 0.42)},
	"set": {"name": "Coffre de set", "desc": "Choisis 1 pièce mythique parmi 3 pièces d'un même set.", "color": Color(1.0, 0.55, 0.15)},
	"trophy": {"name": "Coffre de trophées", "desc": "Choisis 1 trophée parmi 3.", "color": Color(1.0, 0.82, 0.3)},
}
const ORDER := ["set", "trophy", "gear", "forge", "jewel"]


static func make(type: String, plevel: int) -> Dictionary:
	return {"id": "%d_%d" % [Time.get_ticks_usec(), randi() % 100000], "type": type, "plevel": maxi(plevel, 1)}


## Coffre tiré au sort pour un monstre ([param boss], [param elite]).
static func roll_type(boss := false) -> String:
	var r := randf()
	if boss:
		return "set" if r < 0.45 else ("trophy" if r < 0.8 else "gear")
	return "gear" if r < 0.4 else ("forge" if r < 0.65 else ("jewel" if r < 0.85 else "trophy"))


## Objet de butin (LootDrop) représentant un coffre.
static func loot_item(chest: Dictionary) -> Dictionary:
	var t: Dictionary = TYPES[chest.type]
	return {"chest": chest, "name": String(t.name), "icon": MenuWidgets.ICONS % "chest", "rarity": 3 if chest.type in ["set", "trophy"] else 2}


static func is_choice(chest: Dictionary) -> bool:
	return chest.type in ["set", "trophy"]


## Propositions d'un coffre à choix (tirées une fois, gardées dans le coffre).
static func offer(chest: Dictionary) -> Array:
	if chest.has("offer"):
		return chest.offer
	var out: Array = []
	var lv := int(chest.plevel)
	if chest.type == "trophy":
		for i in 3:
			out.append(Items.generate(lv, 1.0, "trophy", Profile.selected_class, 2, "", Items.MYTHIC))
	else:
		var pieces := set_pieces(lv)
		for e in pieces:
			out.append(Items.from_template(e, lv, Items.MYTHIC))
		while out.size() < 3:
			out.append(Items.generate(lv, 1.0, "", Profile.selected_class, Items.MYTHIC, "", Items.MYTHIC))
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
		if not e.is_empty():
			out.append(e)
		if out.size() >= 3:
			break
	return out


## Ouvre un coffre sans choix : le contenu est donné, le coffre retiré. Renvoie le contenu
## {items, supplies, crystal}.
static func open(chest: Dictionary) -> Dictionary:
	var got := {"items": [], "supplies": {}, "crystal": 0}
	var lv := int(chest.plevel)
	match String(chest.type):
		"gear":
			got.items.append(Items.generate(lv, 0.8, "", Profile.selected_class, 2, "", Items.MYTHIC if randf() < 0.15 else 3))
		"forge":
			got.supplies = {"luck": randi_range(1, 2), "protect": 1 if randf() < 0.6 else 0, "drill": 1 if randf() < 0.5 else 0}
			got.crystal = randi_range(3, 6) + lv / 10
		"jewel":
			for i in 2:
				var g := Craft.gem_key(Craft.GEMS.keys().pick_random(), clampi(lv / 12, 0, Craft.GEM_TIERS.size() - 1))
				got.supplies[g] = int(got.supplies.get(g, 0)) + 1
			var sc := Craft.scroll_key(Craft.ENCHANTS.keys().pick_random(), Craft.scroll_level_for(lv))
			got.supplies[sc] = 1
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
	for k in got.get("supplies", {}):
		if int(got.supplies[k]) > 0:
			lines.append("[img=20x20]%s[/img] %s ×%d" % [Craft.icon(k), Craft.label(k), int(got.supplies[k])])
	if int(got.get("crystal", 0)) > 0:
		lines.append("%s%d cristaux" % [ItemWidgets.icon_bb("crystal"), int(got.crystal)])
	return "\n".join(lines)
