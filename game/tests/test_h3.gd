extends Node
## Lot H3 : port des pièces selon le niveau de héros. Une pièce de niveau N ne s'équipe au hub que si le niveau de héros
## ≥ N (Profile.equip / equip_offhand, « Équiper le meilleur », « Appliquer à la famille », arme par défaut) ; les pièces
## déjà portées restent (signalées) ; pièces de départ, du Survivant, du Battle royale et trouvailles de la run jamais
## bloquées ; messages « Niveau N requis · tu es niveau M » (carte, fiche de l'inventaire, Fabriquer, Registre).
## godot --headless --path game res://tests/test_h3.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = false
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	_test_required()
	_test_equip()
	_test_worn_kept()
	_test_best_and_family()
	_test_exempt()
	await _test_inventory_page()
	await _test_shop()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _set_level(lv: int) -> void:
	HeroLevel.ensure()
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(lv)


## Pièce de l'emplacement [param slot] dont le niveau requis est au moins [param lv] (classe guerrier).
## Arme : du type de la classe guerrier, ou [param wtype].
func _piece(slot: String, lv: int, rarity := 2, wtype := "") -> Dictionary:
	if wtype == "" and slot == "weapon":
		wtype = Items.default_weapon_type("warrior")
	var list: Array = GameData.eden_by_slot.get(wtype if slot == "weapon" else slot, [])
	var best: Dictionary = {}
	var lowest: Dictionary = {}
	for e in list:
		if GameData.is_awakened(e) or int(e.level) < 2 or ((e.get("r", {}) as Dictionary).is_empty() and not e.has("passive")):
			continue
		if lowest.is_empty() or int(e.level) < int(lowest.level):
			lowest = e
		if int(e.level) <= lv and (best.is_empty() or int(e.level) > int(best.level)):
			best = e
	if best.is_empty():
		best = lowest
	var it := Items.from_template(best, int(best.level), mini(int(best.rarity), rarity))
	it["upgrade"] = 0
	return it


## Range [param it] au coffre commun (hub) et remet la vue du lobby.
func _store(it: Dictionary) -> Dictionary:
	Profile._sync_vault()
	Profile.vault.append(it)
	Profile._lobby_view()
	for x in Profile.inventory:
		if String(x.uid) == String(it.uid):
			return x
	return it


func _test_required() -> void:
	var it := _piece("head", 60)
	var lv := int(it.get("level", 0)) if it.has("eden") else int(it.get("plevel", it.get("level", 0)))
	check("niveau requis = niveau affiché de la pièce (%d)" % Items.required_level(it), Items.required_level(it) == lv and lv > 1)
	var st := it.duplicate()
	st["starter"] = true
	check("pièce de départ : portable à tout niveau", Items.required_level(st) == 0)
	var sv := it.duplicate()
	sv["sv"] = true
	check("pièce du Survivant / Battle royale : jamais bloquée", Items.required_level(sv) == 0)
	check("objet vide : rien à exiger", Items.required_level({}) == 0)
	check("plafond 90", Items.required_level({"slot": "head", "plevel": 140}) == 90)
	_set_level(1)
	check("compte neuf : niveau 1", HeroLevel.level() == 1)
	check("pièce de départ au niveau 1 : portable", HeroLevel.can_wear(st))
	for cls in ["warrior", "magician", "ranger"]:
		var ok := true
		for g in StarterGear.items(cls).values():
			if not HeroLevel.can_wear(g):
				ok = false
		check("équipement de départ (%s) portable au niveau 1" % cls, ok)


func _test_equip() -> void:
	_set_level(20)
	var high := _store(_piece("head", 60))
	var req := Items.required_level(high)
	check("pièce de niveau %d bloquée au niveau 20" % req, HeroLevel.wear_block(high) == req)
	check("message court : « Niveau %d requis · tu es niveau 20 »" % req, HeroLevel.lock_text(high) == "Niveau %d requis · tu es niveau 20" % req)
	check("Profile.equip refuse (false)", not Profile.equip(high))
	check("… et rien ne bouge", not Profile.equipped.values().any(func(x): return is_same(x, high)) and high in Profile.inventory)
	check("carte de l'objet : la ligne rouge", HeroLevel.lock_line(high).contains("Niveau %d requis" % req) and not HeroLevel.lock_line(high).contains("Déjà portée"))
	var low := _store(_piece("head", 12))
	check("pièce de niveau %d portable au niveau 20" % Items.required_level(low), HeroLevel.can_wear(low) and HeroLevel.lock_text(low) == "")
	check("Profile.equip accepte une pièce portable", Profile.equip(low) and is_same(Profile.equipped.get("head"), low))
	var other := "staff" if Items.default_weapon_type("warrior") != "staff" else "bow"
	var foreign := _store(_piece("weapon", 70, 2, other))
	check("arme d'un autre type (%s, niveau %d)" % [Items.weapon_type_of(foreign), Items.required_level(foreign)], not Profile.can_be_main(foreign) and Items.required_level(foreign) > 20)
	check("arme secondaire au-dessus du niveau : refusée", not Profile.equip_offhand(foreign) and not is_same(Profile.equipped.get("offhand"), foreign))
	check("outil de développement : force passe outre", Profile.equip(high, true) and is_same(Profile.equipped.get("head"), high))
	Profile.unequip("head")
	_set_level(req)
	check("au niveau %d : la pièce s'équipe" % req, Profile.equip(high) and is_same(Profile.equipped.get("head"), high))
	_set_level(20)


func _test_worn_kept() -> void:
	# compte d'avant le niveau de héros : une pièce portée au-dessus du niveau reste portée
	var high := _piece("chest", 70)
	Profile.install_gear({"chest": high})
	_set_level(20)
	Profile._lobby_view()
	var worn: Dictionary = Profile.equipped.get("chest", {})
	check("pièce portée au-dessus du niveau : toujours portée", String(worn.get("uid", "")) == String(high.uid))
	check("… signalée (carte : déjà portée, elle reste)", HeroLevel.lock_line(worn).contains("Déjà portée"))
	check("Registre : la pièce est comptée au-dessus du niveau", int(ClassGear.entry("warrior").get("over", 0)) >= 1)
	check("« Équiper le meilleur » ne la retire pas d'office", ClassGear.best_gear("warrior").has("chest"))
	Profile.set_active_preset("warrior", 1)
	Profile.set_active_preset("warrior", 0)
	check("changer de préréglage et revenir : elle est encore là", String(Profile.equipped.get("chest", {}).get("uid", "")) == String(high.uid))


func _test_best_and_family() -> void:
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile._lobby_view()
	_set_level(25)
	for slot in ["head", "gloves", "boots"]:
		_store(_piece(slot, 80, 3))
		_store(_piece(slot, 15, 1))
	var msg := ClassGear.equip_best("warrior")
	var ok := true
	for slot in ["head", "gloves", "boots"]:
		var it: Dictionary = Profile.equipped.get(slot, {})
		if it.is_empty() or not HeroLevel.can_wear(it):
			ok = false
	check("Équiper le meilleur : seulement des pièces portables (%s)" % msg, ok)
	var best_any := ClassGear.best_gear("warrior")
	check("meilleur équipement : aucune pièce au-dessus du niveau", best_any.values().all(func(x): return HeroLevel.can_wear(x)))
	# la famille : une pièce au-dessus du niveau portée par la source n'est pas copiée
	var high := _piece("legs", 80, 3)
	Profile.install_gear({"legs": high})
	Profile._lobby_view()
	var plan := ClassGear.family_plan("warrior")
	var copied := false
	for t in plan.gears:
		if String((plan.gears[t] as Dictionary).get("legs", {}).get("uid", "")) == String(high.uid):
			copied = true
	check("Appliquer à la famille : la pièce au-dessus du niveau n'est pas copiée", not copied and int(plan.get("over", 0)) >= 1)
	if not (plan.to as Array).is_empty():
		var m := ClassGear.apply_family("warrior")
		check("message de la famille : dit pourquoi (%s)" % m, m.contains("au-dessus de ton niveau"))
	# arme par défaut d'une classe sans arme : la meilleure PORTABLE
	var wtype := Items.default_weapon_type("magician")
	var w_high := _piece("weapon", 80, 3)
	w_high["wtype"] = wtype
	Profile._sync_vault()
	Profile.vault.append(w_high)
	Profile.selected_class = "magician"
	Profile._lobby_view()
	check("arme par défaut : jamais au-dessus du niveau", HeroLevel.can_wear(Profile.equipped.get("weapon", {})))
	Profile.selected_class = "warrior"
	Profile._lobby_view()


func _test_exempt() -> void:
	_set_level(5)
	var high := _piece("ring", 80)
	Profile.in_run = true
	check("pendant une partie aussi : port vérifié (lot H4a : les coffres ne donnent rien au-dessus du niveau)", HeroLevel.wear_block(high) == 80)
	Profile.in_run = false
	Survivor.active = true
	check("Survivant : jamais bloqué", HeroLevel.wear_block(high) == 0)
	Survivor.active = false
	Royale.active = true
	check("Battle royale : jamais bloqué", HeroLevel.wear_block(high) == 0)
	Royale.active = false
	check("au hub : bloqué", HeroLevel.wear_block(high) > 0)


func _test_inventory_page() -> void:
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile._lobby_view()
	_set_level(10)
	var high := _store(_piece("gloves", 60))
	var page := InventoryPage.new()
	add_child(page)
	await get_tree().process_frame
	page.refresh()
	page._select({"kind": "item", "item": high})
	check("fiche : bouton « Niveau N requis » désactivé", page._b_equip.disabled and page._b_equip.text == "Niveau %d requis" % Items.required_level(high))
	check("fiche : niveau en rouge, la phrase en infobulle", page._d_level.tooltip_text.contains("tu es niveau 10")
		and page._d_level.get_theme_color("font_color") == ItemWidgets.LOCK_TEXT)
	page._equip(high)
	check("double-clic refusé : message court au-dessus de la grille", page._msg.visible and page._msg.text == HeroLevel.lock_text(high))
	check("… la pièce reste au coffre", not Profile.equipped.values().any(func(x): return is_same(x, high)))
	var cell_locked := false
	for c in page._grid.get_children():
		if c is ItemWidgets.ItemSlot and is_same(c.item, high):
			cell_locked = c.wear_check
	check("grille : la case signale le niveau requis", cell_locked)
	# pièce portée au-dessus du niveau : la retirer demande une confirmation
	Profile.install_gear({"boots": _piece("boots", 70)})
	_set_level(10)
	page.refresh()
	page._unequip("boots")
	check("retirer une pièce au-dessus du niveau : confirmation d'abord", Profile.equipped.has("boots"))
	for c in get_tree().root.get_children() + page.get_children():
		if c is InfoCard.Ask:
			c.queue_free()
	page._unequip("boots", true)
	check("… confirmée : retirée", not Profile.equipped.has("boots"))
	page.queue_free()
	await get_tree().process_frame


func _test_shop() -> void:
	check("Fabriquer : filtre « Portables »", GearShopPage.STATUSES.any(func(s): return String(s[0]) == "wear"))
	var e: Dictionary = {}
	for id in GameData.eden_by_id:
		var x: Dictionary = GameData.eden_by_id[id]
		if String(x.get("slot", "")) == "head" and int(x.get("level", 0)) >= 60:
			e = x
			break
	if e.is_empty():
		return
	_set_level(10)
	var it := GearShopPage.make(e)
	check("Fabriquer : pièce au-dessus du niveau signalée (se fabrique quand même)", HeroLevel.wear_block(it) > 0 and HeroLevel.lock_line(it).contains("requis"))
