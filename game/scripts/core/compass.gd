class_name Compass
extends RefCounted
## La boussole (passe P6, « la quête commune se voit ») : un seul conseil sobre, calculé depuis l'état du compte, qui dit
## quoi faire ensuite pour avancer vers l'équipement optimal de la classe choisie, et où aller. Lu par le lobby (ligne
## cliquable en haut de l'écran) et par les bilans (ResultsPanel, ligne « Pour ta quête »).
##
## [method advice] renvoie {id, text, tip, icon, go}. [code]go[/code] décrit la page où mène le clic :
## {"menu": "dungeon"|"survival"|…, "zone": id, "tab": onglet du Duel}, {"workshop": onglet}, {"chests": true},
## {"registry": true}, {"hero": section}. Rien n'est enregistré : le conseil se recalcule à chaque affichage.
##
## Ordre (le premier qui s'applique) : première Survie ; pièce qui attend dans le coffre ; pièce achetable avec les
## insignes ; coffres à ouvrir ; ce qui manque à la classe (emplacement vide, niveau des pièces, panoplie, +10, gemmes,
## enchantements), avec l'activité qui le donne ; échelon suivant du fil d'éveil ; classe suivante du Registre.

## Un nom qui se lit après « il te manque ».
const SLOT_NOUN := {
	"weapon": "une arme", "head": "un casque", "chest": "un plastron", "legs": "des jambières", "gloves": "des gants",
	"boots": "des bottes", "back": "une cape", "necklace": "un collier", "ring": "une bague",
}
## Échelons du fil d'éveil, dans l'ordre où le joueur les rencontre : [entrée de Unlocks, texte, page].
const LADDER := [
	["forge", "Gagne l'époque I : la Forge et la Tour s'ouvrent", {"menu": "survival"}],
	["dungeons", "Gagne l'époque II : les Donjons s'ouvrent", {"menu": "survival"}],
	["league", "Bats trois duellistes de la Tour : la Ligue s'ouvre", {"menu": "tower"}],
	["royale", "Ligue Argent : ouvre la Battle royale", {"menu": "duel", "tab": "league"}],
	["arenas", "Ligue Or : ouvre les Arènes et le Gantelet", {"menu": "duel", "tab": "league"}],
	["pantheon", "Ligue Platine : ouvre le Panthéon des Esprits", {"menu": "duel", "tab": "league"}],
	["heroic", "Gagne l'époque IV : les rangs héroïques s'ouvrent", {"menu": "survival"}],
]


static func _make(id: String, text: String, go: Dictionary, tip := "", icon := "") -> Dictionary:
	return {"id": id, "text": text, "tip": tip, "icon": icon, "go": go}


## Le conseil du moment ; {} en partie. [param in_bilan] : au bilan d'une partie (le profil est encore « en partie » : l'équipement
## du coffre commun n'est pas lu, seul l'état du hub compte).
static func advice(in_bilan := false) -> Dictionary:
	if Profile.in_run and not in_bilan:
		return {}
	if Profile.runs_done <= 0 and Profile.seen_gear.is_empty():
		return _make("first_run", "Lance ta première Survie pour tout ouvrir", {"menu": "survival"},
			"La Survie donne les pièces, les insignes et la maîtrise. Les coffres, l'Atelier et le Carnet s'ouvrent après.", "piece")
	var cid := Profile.selected_class
	var cname := ClassGear.class_label(cid)
	var missing := missing_slots(cid)
	var armory := Unlocks.is_open("armory")
	if armory and not missing.is_empty():
		var spare := spare_slot(cid, missing) if not Profile.in_run else ""
		if spare != "":
			return _make("equip_spare", "%s : une pièce t'attend dans ton coffre" % cname, {"hero": "equipment"},
				"Une pièce qui te manquait est dans ton coffre commun : Héros > Équipement, ou « Équiper le meilleur ».", "piece")
		var buy := affordable_piece(cid, missing)
		if not buy.is_empty():
			return _make("buy_piece", "%s : une pièce est achetable" % GearPower.plural(Profile.insignia, "insigne"),
				{"workshop": 0}, "Armurerie : %s à %s insignes (tu en as %s)." % [String(SLOT_NOUN.get(buy.slot, "une pièce")), GearPower.fmt(int(buy.price)), GearPower.fmt(Profile.insignia)], "insignia")
	var n_chests := Profile.reward_chests.size()
	if n_chests > 0 and Unlocks.is_open("chests"):
		return _make("chests", "%s à ouvrir" % GearPower.plural(n_chests, "coffre"), {"chests": true},
			"Les coffres de récompense attendent dans Coffres : pièces, fournitures, apparences.", "look")
	var qh := Quests.hint() if not in_bilan else {}
	if not qh.is_empty() and bool(qh.nearly):
		return _make("quest_near", String(qh.text), qh.go, String(qh.tip), "stars")  # une quête presque finie (passe M5)
	var e := ClassGear.entry(cid)
	if int(e.filled) == 0:
		return _make("start_gear", "%s : choisis la classe dans Héros pour recevoir son équipement" % cname, {"hero": "class"},
			"L'équipement de départ est remis au premier choix de la classe.", "piece")
	if not missing.is_empty():
		var slot := String(missing[0])
		var more := missing.size() - 1
		var tip := "Les coffres d'emplacement de la Survie révèlent des pièces : achète-les ensuite à l'Armurerie." \
			+ (("\nIl manque aussi : %s." % ", ".join(missing.slice(1).map(func(s): return String(Items.SLOT_NAMES.get(s, s)).to_lower()))) if more > 0 else "")
		return _make("find_piece", "%s : il te manque %s → Survie" % [cname, String(SLOT_NOUN.get(slot, "une pièce"))], {"menu": "survival"}, tip, "piece")
	if float(e.ratio) < ClassGear.EQUIPPED_RATIO:
		return _make("level_up_gear", "%s : il faut des pièces de plus haut niveau → Armurerie" % cname,
			{"workshop": 0} if armory else {"menu": "survival"},
			"Les époques suivantes de la Survie révèlent des pièces plus puissantes. Les actuelles se montent à la Forge.", "piece")
	var panoply := maxi(int(e.arch), int(e.spirits))
	if panoply < ClassGear.PANOPLY:
		var next := _panoply_step(cid, e)
		if not next.is_empty():
			return next
	if int(e.plus10) < Items.SLOTS.size():
		var forge := _forge_step(cid, e)
		if not forge.is_empty():
			return forge
	if int(e.gems) < int(e.gem_max):
		if Unlocks.is_open("tower"):
			return _make("gems", "%s : des gemmes à sertir → Tour" % cname, {"menu": "tower"},
				"La Tour donne des gemmes tous les dix étages. Forge > Gemmes pour les sertir.", "gem")
		return ladder_step("tower")
	if int(e.enchants) < Items.SLOTS.size():
		if Unlocks.is_open("siege"):
			return _make("enchants", "%s : des enchantements → Siège" % cname, {"menu": "siege"},
				"Le Siège donne les formules hautes. Forge > Enchanter pour les poser.", "formula")
		return ladder_step("siege")
	var step := next_ladder()
	if not step.is_empty():
		return step
	if not qh.is_empty():
		return _make("quest", String(qh.text), qh.go, String(qh.tip), "stars")  # les quêtes du jour (passe M5)
	var other := lagging_class(cid)
	if other != "":
		return _make("other_class", "%s est équipé : prépare %s" % [cname, ClassGear.class_label(other)], {"registry": true},
			"Le Registre de l'équipement montre où en sont les 60 classes.", "piece")
	return _make("done", "Équipement complet : rien d'autre à chercher", {"registry": true}, "Le Registre de l'équipement le confirme.", "stars")


## Emplacements sans pièce du coffre (vides ou tenus par une pièce de départ) de la classe, l'arme d'abord.
static func missing_slots(cid: String) -> Array:
	var g := ClassGear.gear_of(cid)
	var out: Array = []
	for slot in Items.SLOTS:
		var it: Dictionary = g.get(slot, {})
		if it.is_empty() or it.get("starter", false):
			out.append(slot)
	return out


## Un emplacement manquant que « Équiper le meilleur » comblerait avec une pièce du coffre commun, "" sinon (une pièce
## moins bonne que celle portée ne déclenche pas de conseil : il n'y aurait rien à faire).
static func spare_slot(cid: String, missing: Array) -> String:
	if Profile.inventory.is_empty():
		return ""
	var best := ClassGear.best_gear(cid)
	var cur := ClassGear.gear_of(cid)
	for slot in missing:
		var b: Dictionary = best.get(slot, {})
		if b.is_empty() or b.get("starter", false):
			continue
		if String(b.get("uid", "")) != String(cur.get(slot, {}).get("uid", "")):
			return String(slot)
	return ""


## La pièce découverte la moins chère qui comble un emplacement manquant et que les insignes paient : {slot, price} ou {}.
static func affordable_piece(cid: String, missing: Array) -> Dictionary:
	var tiers := Economy.owned_tiers()
	var wtype := Items.default_weapon_type(cid)
	var best := {}
	for id in Profile.seen_gear:
		var e: Dictionary = GameData.eden_by_id.get(int(id), {})
		if e.is_empty():
			continue
		var slot := String(e.get("slot", ""))
		if not slot in missing or (slot == "weapon" and String(e.get("wtype", "")) != wtype):
			continue
		var price := Economy.armory_price(e, tiers)
		if price > Profile.insignia or GearShopPage.owned(int(id)):
			continue
		if best.is_empty() or price < int(best.price):
			best = {"slot": slot, "price": price}
	return best


## Donjon où trouver la panoplie de la classe (ou les Esprits), {} si rien d'utile à proposer.
static func _panoply_step(cid: String, e: Dictionary) -> Dictionary:
	var cname := ClassGear.class_label(cid)
	if int(e.spirits) > int(e.arch) and Unlocks.is_open("pantheon"):
		return _make("spirits", "Esprits %d / %d → Panthéon" % [int(e.spirits), ClassGear.PANOPLY], {"menu": "duel", "tab": "pantheon"},
			"Chaque cerveau battu au Panthéon donne une pièce des Esprits.", "spirit")
	if not Unlocks.is_open("dungeons"):
		return ladder_step("dungeons")
	var counts := {}
	for it in ClassGear.gear_of(cid).values():
		var a := String(it.get("archetype", ""))
		if a != "":
			counts[a] = int(counts.get(a, 0)) + 1
	var pick := ""
	var best := -1
	for zid in Dungeons.zone_ids():
		if not Dungeons.is_open(String(zid)):
			continue
		var n := int(counts.get(Dungeons.archetype(String(zid)), 0))
		if n > best:
			best = n
			pick = String(zid)
	if pick == "":
		return _make("panoply", "%s : une panoplie de donjon → bats un boss en Survie" % cname, {"menu": "survival"},
			"Un donjon s'ouvre quand le boss de sa zone est battu en Survie.", "panoply")
	var set_name := String(Items.SETS.get(Dungeons.archetype(pick), {}).get("name", "de donjon"))
	return _make("panoply", "Panoplie %s %d / %d → %s" % [set_name, maxi(best, 0), ClassGear.PANOPLY, Dungeons.name_of(pick)],
		{"menu": "dungeon", "zone": pick}, "Le coffre de set d'un donjon propose trois pièces de sa panoplie. 2, 4 et 6 pièces portées donnent des bonus.", "panoply")


## Forge ou cristaux : la pièce de la classe la moins montée, et ce que coûte son prochain niveau.
static func _forge_step(cid: String, e: Dictionary) -> Dictionary:
	if not Unlocks.is_open("forge"):
		return ladder_step("forge")
	var cheapest := -1
	for it in ClassGear.gear_of(cid).values():
		var up := int(it.get("upgrade", 0))
		if up >= Items.MAX_UPGRADE or Items.is_unique(it):
			continue
		var cost := Forge.upgrade_crystals(int(it.get("level", 1)), up, up + 1)
		if cheapest < 0 or cost < cheapest:
			cheapest = cost
	if cheapest < 0:
		return {}
	var have := Profile.amount("crystal")
	var left := Items.SLOTS.size() - int(e.plus10)
	if have >= cheapest:
		return _make("forge", "%s : une pièce peut monter → Forge" % GearPower.plural(have, "cristal", "cristaux"), {"workshop": 2},
			"%s à monter à +10. Chaque niveau coûte des cristaux, parfois un parchemin." % GearPower.plural(left, "pièce"), "crystal")
	var where := "Donjons" if Unlocks.is_open("dungeons") else "Tour"
	return _make("crystals", "Forge : il manque des cristaux → %s" % where, {"menu": "dungeon"} if where == "Donjons" else {"menu": "tower"},
		"Prochain niveau : %s. Les cristaux viennent des Donjons, de la Ruée, du Siège et de la Tour." % GearPower.plural(cheapest, "cristal", "cristaux"), "crystal")


## Le conseil « ouvre cette entrée du fil d'éveil » (Unlocks) : le texte de LADDER.
static func ladder_step(unlock: String) -> Dictionary:
	for l in LADDER:
		if String(l[0]) == unlock or (unlock == "siege" and String(l[0]) == "dungeons") or (unlock == "tower" and String(l[0]) == "forge"):
			return _make("ladder_" + String(l[0]), String(l[1]), l[2], Unlocks.condition(String(l[0])), "rank")
	return {}


## Premier échelon encore fermé du fil d'éveil, {} s'ils sont tous ouverts.
static func next_ladder() -> Dictionary:
	for l in LADDER:
		if not Unlocks.is_open(String(l[0])):
			return ladder_step(String(l[0]))
	return {}


## Classe jouable la moins équipée du Registre (sous « équipée »), "" si toutes le sont ; [param except] est ignorée.
static func lagging_class(except: String) -> String:
	var worst := ""
	var worst_status := ClassGear.STATUS_EQUIPPED
	for e in ClassGear.entries():
		var c := String(e.cid)
		if c == except or not Progression.class_unlocked(c):
			continue
		if int(e.status) < worst_status:
			worst_status = int(e.status)
			worst = c
	return worst


# --- bilans : « ce que ce gain change pour la quête » ---------------------------------------------------
## Une ligne pour le bilan d'une activité ([param mode] : survival, dungeon, rush, siege, tower, duel, royale), d'après ce
## que l'activité vient de donner ([param got] : crystals, plan, title, looks, chests, seen, unlocked, rank…).
## Toujours une phrase (la boussole, à défaut) ; "" si rien d'utile.
static func after(mode: String, got: Dictionary = {}) -> String:
	var parts: PackedStringArray = []
	var quest_line := Quests.report_line()  # « Quête accomplie : … » ou la quête la plus avancée (passe M5)
	if quest_line != "":
		parts.append(quest_line)
	match mode:
		"survival":
			if String(got.get("unlocked", "")) != "":
				parts.append("%s ouverte : de nouvelles activités" % String(got.unlocked))
			var seen := int(got.get("seen", 0))
			if seen > 0:
				parts.append("%s à l'Armurerie" % GearPower.plural(seen, "pièce", "pièces"))
		"dungeon", "rush":
			if String(got.get("plan", "")) != "":
				parts.append("plan obtenu : Atelier > Plans de donjon")
			var arch := String(got.get("archetype", ""))
			if arch != "" and Items.SETS.has(arch):
				parts.append("panoplie %s %d / %d : un coffre de set à ouvrir" % [String(Items.SETS[arch].name), archetype_count(arch), ClassGear.PANOPLY])
			if int(got.get("crystals", 0)) > 0:
				parts.append(_crystal_phrase(int(got.crystals)))
			if String(got.get("title", "")) != "":
				parts.append("titre « %s » gagné" % String(got.title))
		"siege":
			if int(got.get("crystals", 0)) > 0:
				parts.append(_crystal_phrase(int(got.crystals)))
			if bool(got.get("formulas", false)):
				parts.append("formules : Forge > Enchanter")
			if int(got.get("looks", 0)) > 0:
				parts.append("apparence gagnée : Héros > Apparence")
		"tower":
			if int(got.get("crystals", 0)) > 0:
				parts.append(_crystal_phrase(int(got.crystals)))
			if int(got.get("looks", 0)) > 0:
				parts.append("apparence gagnée : Héros > Apparence")
		"duel":
			if bool(got.get("spirit", false)):
				parts.append("Esprits %d / %d : la pièce se rachète à l'Armurerie" % [spirit_count(), ClassGear.PANOPLY])
			if bool(got.get("promoted", false)):
				parts.append("rang %s atteint" % String(got.get("rank_name", League.rank_name())))
			elif League.rank_index() < League.RANKS.size() - 1 and Unlocks.is_open("league"):
				parts.append("série de Ligue : %d / 3 vers %s" % [League.streak(), League.rank_name(League.target_rank())])
		"royale":
			if int(got.get("looks", 0)) > 0:
				parts.append("apparence de prestige gagnée : Héros > Apparence")
	var line := " · ".join(parts.slice(0, 2))  # deux gains au plus : la ligne reste lisible
	var next := advice(true)
	if parts.size() < 2 and not next.is_empty() and String(next.id) != "first_run":
		line = (line + "  ›  " if line != "" else "Ensuite : ") + String(next.text)
	return line


## Pièces de la panoplie [param arch] possédées (un emplacement compte une fois), au plus ClassGear.PANOPLY.
static func archetype_count(arch: String) -> int:
	var slots := {}
	for it in Profile.vault + Profile.all_items():
		if String(it.get("archetype", "")) == arch:
			slots[String(it.get("slot", ""))] = true
	return mini(slots.size(), ClassGear.PANOPLY)


## Pièces des Esprits découvertes (Armurerie), au plus ClassGear.PANOPLY.
static func spirit_count() -> int:
	var n := 0
	for id in Profile.seen_gear:
		if Pantheon.is_shop_id(int(id)):
			n += 1
	return mini(n, ClassGear.PANOPLY)


static func _crystal_phrase(gained: int) -> String:
	var have := Profile.amount("crystal")
	return "%s pour la Forge (tu en as %s)" % [GearPower.plural(gained, "cristal", "cristaux"), GearPower.fmt(have)]
