class_name Rewards
extends RefCounted
## Coffres de récompense, ouverts hors run (menu Coffres) : boss du donjon (100 %), élites
## (20 %), monstres (0,5 %). Ramassés, ils vont tout de suite dans le menu Coffres et ne se
## perdent jamais. **Seule source des objets mythiques et légendaires.**
## Chaque coffre : {id, type, plevel}.
## - équipement : un objet mythique (légendaire : 20 %, 35 % pour un coffre de boss) ;
## - forge : parchemins de fortification, pierres de sûreté, ciseaux, parfois un parchemin béni, cristaux ;
## - joaillier : gemmes et parchemins d'enchantement ;
## - set : choisir 1 pièce mythique parmi 3 pièces d'un même set.
## Objets : au coffre commun ; fournitures : à la réserve (emportée à la prochaine run).
## Les coffres de forge et du joaillier peuvent porter une `focus` (voir ActivityLoot) : la spécialité de
## l'activité qui les donne (parchemins, pierres, gemmes ou formules d'enchantement).

## [code]icon[/code] : pastille de la liste (menu Coffres), pour reconnaître un type sans se fier à sa seule couleur.
const TYPES := {
	"gear": {"name": "Coffre d'équipement", "desc": "Un objet mythique, parfois légendaire.", "color": Color(1.0, 0.55, 0.15), "icon": "weapon"},
	"forge": {"name": "Coffre de forge", "desc": "Parchemins, pierres, ciseaux et cristaux.", "color": Color(0.85, 0.85, 0.9), "icon": "upgrade"},
	"jewel": {"name": "Coffre de joaillier", "desc": "Gemmes et formules d'enchantement.", "color": Color(0.42, 0.9, 0.42), "icon": "gem"},
	"set": {"name": "Coffre de set", "desc": "3 pièces d'un même set : tu en gardes une.", "color": Color(1.0, 0.84, 0.25), "icon": "armor"},
	# coffres d'apparence (boss de Survie, paliers de la Tour) : une apparence au hasard, jamais
	# un doublon ; leur qualité fixe la rareté de l'apparence
	"look_common": {"name": "Coffre d'apparence commun", "desc": "Une apparence commune ou spéciale.", "color": Color(0.75, 0.8, 0.9), "icon": "collection"},
	"look_rare": {"name": "Coffre d'apparence rare", "desc": "Une apparence rare ou épique.", "color": Color(0.4, 0.65, 1.0), "icon": "collection"},
	"look_epic": {"name": "Coffre d'apparence mythique", "desc": "Une apparence mythique.", "color": Color(1.0, 0.55, 0.15), "icon": "collection"},
	"look_legend": {"name": "Coffre d'apparence légendaire", "desc": "Une apparence légendaire.", "color": Color(1.0, 0.86, 0.3), "icon": "collection"},
	# coffres d'auras (Panthéon) : une aura de la collection que tu n'as pas
	"aura_rare": {"name": "Coffre d'aura rare", "desc": "Une aura rare.", "color": Color(0.45, 0.8, 1.0), "icon": "new"},
	"aura_legend": {"name": "Coffre d'aura légendaire", "desc": "Une aura légendaire.", "color": Color(1.0, 0.7, 0.95), "icon": "new"},
}
## Plancher des pièces mythiques d'Eden (niveau 20-23) : un coffre d'équipement ne donne pas de pièce au-delà de
## max(son niveau, ce plancher) + 5.
const LOW_GEAR_FLOOR := 23
const ORDER := ["aura_legend", "aura_rare", "look_legend", "look_epic", "look_rare", "look_common", "set", "gear", "forge", "jewel"]
## Spécialités des coffres de forge et de joaillier (voir ActivityLoot) : le contenu insiste sur une matière.
const FOCUS_ORDER := ["", "scroll", "stone", "gem", "enchant"]
const FOCUS_NAMES := {"scroll": "parchemins", "stone": "pierres", "gem": "gemmes", "enchant": "formules"}
const FOCUS_BLURBS := {
	"forge:scroll": "Surtout des parchemins de fortification.",
	"forge:stone": "Surtout des pierres rares.",
	"jewel:gem": "Surtout des gemmes de haut rang.",
	"jewel:enchant": "Surtout des formules d'enchantement.",
}
## Raretés (de la collection d'Eden) de chaque coffre d'apparence, du commun au légendaire.
const LOOKS := {"look_common": [0, 1], "look_rare": [2, 3], "look_epic": [4], "look_legend": [5]}
const LOOK_TYPES := ["look_common", "look_rare", "look_epic", "look_legend"]
## Raretés d'Eden des auras de chaque coffre d'auras.
const AURAS := {"aura_rare": [2], "aura_legend": [5]}


## Clé de regroupement d'un coffre dans la liste : son type, et sa spécialité pour la forge et le joaillier
## (« forge:scroll »). Deux coffres de forge de spécialités différentes ne se confondent pas.
static func kind_of(chest: Dictionary) -> String:
	var t := String(chest.type)
	var f := String(chest.get("focus", ""))
	return "%s:%s" % [t, f] if (t == "forge" or t == "jewel") and FOCUS_NAMES.has(f) else t


## Rang d'affichage de [param kind] (voir [method kind_of]) : l'ordre de [constant ORDER], puis celui des spécialités.
static func kind_rank(kind: String) -> int:
	var p := kind.split(":")
	return ORDER.find(p[0]) * 10 + FOCUS_ORDER.find(p[1] if p.size() > 1 else "")


## Nom d'un coffre de [param kind] : « Coffre de forge », « Coffre de forge · parchemins », « Coffre de joaillier · formules ».
static func kind_name(kind: String) -> String:
	var p := kind.split(":")
	var base := String(TYPES[p[0]].name)
	return "%s · %s" % [base, FOCUS_NAMES[p[1]]] if p.size() > 1 else base


## Une phrase sur le contenu d'un coffre de [param kind], sans chiffre (le détail est dans [method preview]).
static func kind_blurb(kind: String) -> String:
	return String(FOCUS_BLURBS.get(kind, TYPES[kind.split(":")[0]].desc))


static func name_of(chest: Dictionary) -> String:
	return kind_name(kind_of(chest))


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


static func make(type: String, plevel: int, boss := false, focus := "") -> Dictionary:
	var c := {"id": "%d_%d" % [Time.get_ticks_usec(), randi() % 100000], "type": type, "plevel": maxi(plevel, 1),
		"zone": Run.zone_id if Run.active else ""}
	if boss:
		c["boss"] = true
	if focus != "":
		c["focus"] = focus
	return c


## Sauvegarde d'avant 0.1.165 : le coffre de trophées n'existe plus (il donnait des pièces de set, comme un coffre de set).
static func migrate(chests: Array) -> Array:
	for c in chests:
		if String(c.get("type", "")) == "trophy":
			c["type"] = "set"
	return chests


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


## Rareté d'un objet de coffre : mythique, ou légendaire (20 %, 35 % pour un coffre de boss) si ta PE
## atteint GearPower.LEGEND_RATIO fois celle d'un équipement correct du niveau du coffre (sinon : mythique).
static func top_rarity(chest: Dictionary) -> int:
	return Items.LEGENDARY if legendary_open(chest) and randf() < (0.35 if chest.get("boss", false) else 0.2) else Items.MYTHIC


static func legendary_open(chest: Dictionary) -> bool:
	return GearPower.meets(GearPower.required(int(chest.get("plevel", 1)), GearPower.LEGEND_RATIO))


static func _legend_text(chest: Dictionary) -> String:
	if legendary_open(chest):
		return "%d %% de chances" % (35 if chest.get("boss", false) else 20)
	return "il faut une PE de %s, la tienne : %s" % [GearPower.fmt(GearPower.required(int(chest.get("plevel", 1)), GearPower.LEGEND_RATIO)), GearPower.fmt(GearPower.hero_power())]


## Coffre tiré au sort pour un monstre ([param boss], [param elite]).
static func roll_type(boss := false) -> String:
	var r := randf()
	if boss:
		return "set" if r < 0.6 else "gear"  # (plus de coffres de trophées : collection de la run)
	return "gear" if r < 0.45 else ("forge" if r < 0.72 else "jewel")


## Objet de butin (LootDrop) représentant un coffre.
static func loot_item(chest: Dictionary) -> Dictionary:
	var t: Dictionary = TYPES[chest.type]
	return {"chest": chest, "name": String(t.name), "icon": MenuWidgets.ICONS % "chest", "rarity": 3 if chest.type == "set" else 2}


static func is_choice(chest: Dictionary) -> bool:
	return chest.type == "set"


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
	var pieces := set_pieces(lv)
	var rar := top_rarity(chest)
	for e in pieces:
		out.append(Items.from_template(e, lv, rar))
	while out.size() < 3:
		out.append(Items.generate(lv, 1.0, "", Profile.selected_class, Items.MYTHIC, "", Items.MYTHIC))
	Items.reward_zone = ""
	if String(chest.get("archetype", "")) != "":
		for it in out:
			it["archetype"] = String(chest.archetype)
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


## Cristaux d'un coffre de forge de niveau [param lv] : 1-2 + 1 par 30 niveaux (avant 0.1.165 : 3-6 + 1 par 10,
## quand un cristal valait 5 fois moins d'or).
static func _forge_crystals(lv: int) -> Vector2i:
	return Vector2i(1 + lv / 30, 2 + lv / 30)


## Rang des gemmes d'un coffre du joaillier de niveau [param lv] (0 brut … 4 royal) : le niveau du coffre / 12,
## un rang de plus pour un coffre « gemmes » (Tour, Ruée), un de moins pour un coffre « formules » (Siège).
static func gem_tier(lv: int, focus: String) -> int:
	return clampi(lv / 12 + (1 if focus == "gem" else (-1 if focus == "enchant" else 0)), 0, Craft.GEM_TIERS.size() - 1)


## Contenu possible d'un coffre, en texte (mêmes règles que [method open] : l'aperçu ne ment pas).
static func preview(chest: Dictionary) -> String:
	var lv := int(chest.plevel)
	var t := String(chest.type)
	match t:
		"gear":
			return "Un objet mythique de niveau %d (légendaire : %s)." % [lv, _legend_text(chest)]
		"forge":
			match String(chest.get("focus", "")):
				"scroll":
					return "2-3 parchemins de puissance et 2-4 de garde (niveau %d), 1-2 pierres de sûreté, 1 pierre de chance, 2 pierres, parfois des ciseaux (50 %%) et un parchemin béni (20 %%), %d-%d cristaux." % [
						Craft.fortify_level_at(lv), _forge_crystals(lv).x, _forge_crystals(lv).y]
				"stone":
					return "1 parchemin de puissance et 1 de garde (niveau %d), 2 pierres de sûreté, 1 pierre de chance, 4 pierres choisies parmi les plus rares, %d-%d cristaux." % [
						Craft.fortify_level_at(lv), _forge_crystals(lv).x, _forge_crystals(lv).y]
			return "1-2 parchemins de puissance et 1-3 de garde (niveau %d), 1-2 pierres de sûreté, 1 pierre de chance, 2 pierres, parfois des ciseaux (50 %%) et un parchemin béni (20 %%), %d-%d cristaux." % [
				Craft.fortify_level_at(lv), _forge_crystals(lv).x, _forge_crystals(lv).y]
		"jewel":
			match String(chest.get("focus", "")):
				"gem":
					return "3 gemmes de rang %d et 1 parchemin d'enchantement." % (gem_tier(lv, "gem") + 1)
				"enchant":
					return "3 parchemins d'enchantement (jusqu'au niveau %d) et 1 gemme de rang %d." % [Craft.scroll_level_for(lv), gem_tier(lv, "enchant") + 1]
			return "2 gemmes de rang %d et 1 parchemin d'enchantement." % (gem_tier(lv, "") + 1)
		"set":
			return "3 pièces mythiques d'un même set au choix (déjà possédées : jamais proposées) ; légendaire : %s." % _legend_text(chest)
	if AURAS.has(t):
		var left := GameData.collection.filter(func(x): return x.has("aura") and not Profile.collected(x) and (AURAS[t] as Array).has(int(x.get("rarity", 0)))).size()
		return "Une aura que tu n'as pas encore (%d à trouver)." % left
	if LOOKS.has(t):
		var free := GameData.collection.filter(func(x): return not Profile.collected(x) 			and (x.has("aura") or x.has("skin") or (int(x.get("cat", 9)) <= 3 and GameData.cosmetic_by_code.has(String(x.get("code", ""))))) 			and not String(x.get("name", "")).contains("(Alpha)") and (LOOKS[t] as Array).has(int(x.get("rarity", 0))))
		return "Une apparence que tu n'as pas encore (%d à trouver)." % free.size()
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
	for e in [[scrolls, "parchemin", "parchemins"], [stones, "pierre", "pierres"], [gems, "gemme", "gemmes"], [other, "fourniture", "fournitures"],
			[int(got.get("crystal", 0)), "cristal", "cristaux"], [(got.get("items", []) as Array).size(), "objet", "objets"],
			[(got.get("looks", []) as Array).size(), "apparence", "apparences"]]:
		if int(e[0]) > 0:
			parts.append("%d %s" % [int(e[0]), e[1] if int(e[0]) == 1 else e[2]])
	return ", ".join(parts) if not parts.is_empty() else "rien"


## Ouvre un coffre sans choix : le contenu est donné, le coffre retiré. Renvoie le contenu
## {items, supplies, crystal}.
static func open(chest: Dictionary) -> Dictionary:
	Quests.event("chest_open")  # quêtes (passe M5)
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
			# emplacement tiré au hasard ; les capes mythiques d'Eden commencent au niveau 33 : un coffre de bas niveau
			# en retire une autre pièce plutôt qu'une cape bien au-dessus de lui (passe P11, test_p9 aléatoire)
			var it := Items.generate(lv, 0.8, "", Profile.selected_class, rar, "", rar)
			for i in 6:
				if int(it.get("level", 0)) <= maxi(lv, LOW_GEAR_FLOOR) + 5:
					break
				it = Items.generate(lv, 0.8, "", Profile.selected_class, rar, "", rar)
			got.items.append(it)
		"forge":
			# parchemins de fortification du niveau du coffre et pierres de sûreté
			var flv := Craft.fortify_level_at(lv)
			var focus := String(chest.get("focus", ""))
			var scrolls := [randi_range(1, 2), randi_range(1, 3)]
			if focus == "scroll":
				scrolls = [randi_range(2, 3), randi_range(2, 4)]
			elif focus == "stone":
				scrolls = [1, 1]
			got.supplies = {Craft.fortify_key("power", flv): scrolls[0], Craft.fortify_key("guard", flv): scrolls[1],
				Craft.stone_key("safety"): 2 if focus == "stone" else randi_range(1, 2), Craft.stone_key("lucky"): 1}
			for i in (4 if focus == "stone" else 2):
				var st := Craft.random_stone(4 if focus == "stone" else 2)
				got.supplies[st] = int(got.supplies.get(st, 0)) + 1
			if focus != "stone" and randf() < 0.5:
				got.supplies["drill"] = 1
			if randf() < 0.2:
				got.supplies[Craft.BLESSED] = 1
			got.crystal = randi_range(_forge_crystals(lv).x, _forge_crystals(lv).y)
		"jewel":
			var focus := String(chest.get("focus", ""))
			var tier := gem_tier(lv, focus)
			for i in (1 if focus == "enchant" else (3 if focus == "gem" else 2)):
				var g := Craft.gem_key(Craft.GEMS.keys().pick_random(), tier)
				got.supplies[g] = int(got.supplies.get(g, 0)) + 1
			var slv := Craft.scroll_level_for(lv)
			for i in (3 if focus == "enchant" else 1):
				var sc := Craft.scroll_key(Craft.ENCHANTS.keys().pick_random(), slv) if slv > 0 else Craft.random_stone(1)
				got.supplies[sc] = int(got.supplies.get(sc, 0)) + 1
	Items.reward_zone = ""
	_give(got)
	Profile.reward_chests.erase(chest)
	Profile.save_profile()
	return got


## Coffre à choix : l'objet [param index] des propositions rejoint le coffre commun.
static func choose(chest: Dictionary, index: int) -> Dictionary:
	var items := offer(chest)
	Quests.event("chest_open")  # quêtes (passe M5)
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
