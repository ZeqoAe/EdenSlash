extends Node
## Lot A1 de la refonte Aventure : un plan de donjon par boss (48), garanti à la 1re victoire contre lui et jamais en
## double ; migration sans perte des anciens plans par zone (« plan_limestone ») ; fabrication en insignes (prix plein de
## l'Armurerie, aucun cristal), aux deux emplacements du boss, à sa panoplie, au niveau de la meilleure difficulté finie.
## godot --headless --path game res://tests/test_a1.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	_test_reward()
	_test_migration()
	_test_craft()
	await _test_page()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _test_reward() -> void:
	Profile.reset_all()
	Profile.unlocked_features = ["dungeons"]
	check("48 plans à trouver, un par boss", Dungeons.plan_total() == 48 and Dungeons.plan_total() == BossLibrary.ids().size())
	check("compte neuf : aucun plan", Dungeons.plans_known().is_empty())
	var bid := "latif"
	var zid := Dungeons.boss_zone(bid)
	var r := Dungeons.reward(zid, 0, bid)
	check("1re victoire contre %s : son plan tombe" % bid, r.plan == Dungeons.plan_id(bid) and Dungeons.has_plan(bid))
	var r2 := Dungeons.reward(zid, 0, bid)
	var r3 := Dungeons.reward(zid, 1, bid)
	check("victoires suivantes (même ou autre difficulté) : pas de doublon", r2.plan == "" and r3.plan == "" and Profile.plans.count(Dungeons.plan_id(bid)) == 1)
	check("un autre boss de la même zone n'est pas donné", not Dungeons.has_plan(Dungeons.lieutenant_of(bid)))
	var r4 := Dungeons.reward(zid, 0, Dungeons.lieutenant_of(bid))
	check("son propre plan tombe à sa 1re victoire", r4.plan == Dungeons.plan_id(Dungeons.lieutenant_of(bid)) and Dungeons.plans_known().size() == 2)
	check("la meilleure difficulté suit les victoires contre ce boss", Dungeons.plan_diff(bid) == 1 and Dungeons.plan_diff(Dungeons.lieutenant_of(bid)) == 0)
	var r5 := Dungeons.reward("beluga", 2)
	var zb := BossLibrary.zone_boss("beluga")
	check("sans boss choisi : le plan du boss d'origine de la zone", r5.plan == Dungeons.plan_id(zb) and Dungeons.plan_diff(zb) == 2)
	check("aucun ancien plan par zone n'est créé", not Profile.plans.any(func(p): return String(p).trim_prefix(Dungeons.PLAN_PREFIX) in Dungeons.zone_ids()))
	check("texte « Il tombe en battant <boss> »", Dungeons.plan_source(bid) == "Il tombe en battant %s." % BossLibrary.short_name(bid))
	# tous les boss : un plan chacun, 48 au bout
	for id in BossLibrary.ids():
		Dungeons.reward(Dungeons.boss_zone(id), 0, id)
	check("les 48 boss battus : 48 plans, aucun doublon", Dungeons.plans_known().size() == 48 and Profile.plans.size() == 48)


func _test_migration() -> void:
	Profile.reset_all()
	Profile.plans = ["plan_limestone", "plan_delphi", "plan_inconnu"]
	Profile.records["dungeon_limestone_0"] = 3
	Profile.records["dungeon_limestone_1"] = 1
	Profile.records["dungeon_delphi_2"] = 1
	var changed := Dungeons.migrate_plans()
	var mori := BossLibrary.zone_boss("limestone")
	var pross := BossLibrary.zone_boss("delphi")
	check("plan_limestone -> plan du boss d'origine de la zone (%s)" % mori, changed and Dungeons.has_plan(mori) and not Profile.plans.has("plan_limestone"))
	check("plan_delphi -> %s" % pross, Dungeons.has_plan(pross) and not Profile.plans.has("plan_delphi"))
	check("un plan inconnu est gardé tel quel (rien ne se perd)", Profile.plans.has("plan_inconnu"))
	check("le plan converti garde la meilleure difficulté de sa zone", Dungeons.plan_diff(mori) == 1 and Dungeons.plan_diff(pross) == 2)
	check("conversion idempotente", not Dungeons.migrate_plans() and Profile.plans.size() == 3)
	check("le plan converti fabrique au niveau d'avant (Héroïque de Monts Calcaires)", FabricationPage.level_of(mori) == Dungeons.level("limestone", 1))
	check("plan de Delphi fini en Mythique : légendaire", FabricationPage.rarity_of(pross) == Items.LEGENDARY)
	# ancien plan et nouveau plan du même boss : un seul reste
	Profile.plans = ["plan_limestone", Dungeons.plan_id(mori)]
	Dungeons.migrate_plans()
	check("ancien et nouveau plan du même boss : un seul plan", Profile.plans == [Dungeons.plan_id(mori)])
	# vieille sauvegarde (JSON) : le plan est reconnu dès la première lecture
	Profile.plans = JSON.parse_string(JSON.stringify(["plan_limestone"]))
	check("vieille sauvegarde relue : le plan est reconnu", FabricationPage.known() == [mori] and Dungeons.plans_known().size() == 1)


func _test_craft() -> void:
	Profile.reset_all()
	Profile.inventory = []
	var bid := "appacka"  # arme et collier
	var slots: Array = BossLibrary.loot(bid).slots
	check("le plan d'%s fabrique ses deux emplacements" % bid, FabricationPage.slots_of(bid) == slots and slots.size() == 2)
	Profile.insignia = 100000
	check("sans plan : refusé", FabricationPage.craft(bid, String(slots[0])).has("error"))
	Dungeons.reward(Dungeons.boss_zone(bid), 0, bid)
	var lv := Dungeons.level(Dungeons.boss_zone(bid), 0)
	var price := Economy.base_price({"level": lv, "rarity": Items.MYTHIC})
	check("prix en insignes = prix plein d'une pièce mythique du niveau du donjon (%d)" % price, FabricationPage.cost(bid) == price and price == 30 + lv)
	Profile.insignia = price + 7
	Profile.materials["crystal"] = 500
	Profile.selected_class = "magician"
	var it := FabricationPage.craft(bid, "weapon")
	check("arme fabriquée : panoplie du boss, type de la classe choisie, mythique",
		not it.has("error") and String(it.slot) == "weapon" and String(it.get("archetype", "")) == String(BossLibrary.loot(bid).archetype)
		and Items.weapon_type_of(it) == Items.default_weapon_type("magician") and int(it.rarity) == Items.MYTHIC)
	check("insignes payés, aucun cristal", Profile.insignia == 7 and Profile.amount("crystal") == 500)
	check("le plan n'est pas consommé", Dungeons.has_plan(bid))
	check("trop peu d'insignes : refusé, rien payé", FabricationPage.craft(bid, "necklace").has("error") and Profile.insignia == 7)
	Profile.insignia = 100000
	check("un emplacement hors du boss : refusé", FabricationPage.craft(bid, "head").has("error"))
	# Mythique fini contre ce boss : légendaire, niveau 90, prix légendaire
	Dungeons.reward(Dungeons.boss_zone(bid), 2, bid)
	var leg := FabricationPage.craft(bid, "necklace")
	check("après un Mythique : pièce légendaire, prix légendaire (%d)" % FabricationPage.cost(bid),
		int(leg.get("rarity", 0)) == Items.LEGENDARY and FabricationPage.cost(bid) == 80 + 2 * Dungeons.MYTHIC_LEVEL)
	check("FabricationPage accepte encore une zone (boss d'origine)", FabricationPage.resolve("limestone") == BossLibrary.zone_boss("limestone"))


func _test_page() -> void:
	Profile.reset_all()
	Profile.unlocked_features = ["dungeons"]
	Profile.records["boss_limestone"] = 1
	Profile.inventory = []
	var page := FabricationPage.new()
	add_child(page)
	await get_tree().process_frame
	page.refresh()
	check("compteur « 0 / 48 »", page._count.text == "0 / 48 plans")
	var open := BossLibrary.for_zone("limestone").size()
	check("plans à trouver des donjons ouverts : %d fiches, le reste en une ligne" % open, page._todo_grid.get_child_count() == open and page._closed.visible and page._closed.text.begins_with("%d autres plans" % (48 - open)))
	Profile.plans = ["plan_limestone"]
	Profile.insignia = 1000
	page.refresh()
	await get_tree().process_frame
	check("compteur « 1 / 48 », une fiche à fabriquer", page._count.text == "1 / 48 plans" and page._grid.get_child_count() == 1 and page._todo_grid.get_child_count() == open - 1)
	var b := _button_with(page, "Fabriquer")
	var mori := BossLibrary.zone_boss("limestone")
	check("bouton « Fabriquer · N insignes »", b != null and b.text == "Fabriquer · %s" % FabricationPage.insignia_text(FabricationPage.cost(mori)))
	var todo_texts: Array = page._todo_grid.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	check("fiche à trouver : « Il tombe en battant <boss> »", todo_texts.any(func(t): return String(t).begins_with("Il tombe en battant ")))
	if b:
		b.pressed.emit()
		check("une pièce fabriquée, insignes payés", Profile.inventory.size() == 1 and Profile.insignia == 1000 - FabricationPage.cost(mori) and page._msg.text.begins_with("Fabriqué"))
	check("accord : 1 insigne, 2 insignes", FabricationPage.insignia_text(1) == "1 insigne" and FabricationPage.insignia_text(2) == "2 insignes")
	page.queue_free()
	await get_tree().process_frame


func _button_with(root: Node, txt: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if (n as Button).text.contains(txt):
			return n
	return null
