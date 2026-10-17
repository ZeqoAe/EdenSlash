extends Node
## Lot GX-2 (Atelier) : Forge sans punition (persévérance, plus de rétrogradation, « Viser +N » : coût attendu et au pire,
## enchaîner), Réajuster au choix (ancien ou nouveau jet), sauvegarde relue ; Plans de donjon (aperçu avant fabrication,
## « Fabriquer et porter ») ; Fabriquer v2 (paliers, poupée du palier, « il en manque ≈ N cartes », palier entier).
## godot --headless --path game res://tests/test_gx2.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _buttons(root: Node) -> Array:
	return root.find_children("*", "Button", true, false)


func _button_with(root: Node, prefix: String) -> Button:
	for b in _buttons(root):
		if (b as Button).text.begins_with(prefix) and (b as Button).is_visible_in_tree():
			return b
	return null


func _texts(root: Node) -> String:
	var out: PackedStringArray = []
	for n in [root] + root.find_children("*", "", true, false):
		if n is Label or n is Button:
			out.append(String(n.text))
		elif n is RichTextLabel:
			out.append((n as RichTextLabel).get_parsed_text())
		if n is Control and (n as Control).tooltip_text != "":
			out.append((n as Control).tooltip_text)
	return "\n".join(out)


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.in_run = false
	_test_pity_rules()
	_test_plan()
	_test_reforge()
	await _test_forge_ui()
	_test_save()
	_test_verdict_levels()
	await _test_dungeon_plans()
	await _test_shop_v2()
	Training.active = true
	Profile.reset_all()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _piece(level: int, up: int, slot := "chest") -> Dictionary:
	var it := Items.generate(level, 0.0, slot, "warrior", Items.MYTHIC, "", Items.MYTHIC)
	it["upgrade"] = up
	return it


# --- règles ---------------------------------------------------------------------------------------------------------
func _test_pity_rules() -> void:
	check("persévérance : au pire 5 essais pour un cran à 40 %, 4 pour +10 (30 %)", int(Craft._tries(0.4, 0, 0.0).y) == 5 and int(Craft._tries(0.3, 0, 0.0).y) == 4)
	check("persévérance : un cran sûr = 1 essai", Craft._tries(1.0, 0, 0.0) == Vector2(1, 1))
	check("persévérance : au pire 5 essais pour n'importe quel cran (plancher de remplissage)", Craft.UPGRADE_CHANCE.all(func(b): return int(Craft._tries(float(b), 0, 0.0).y) <= 5))
	var t := _piece(85, 9)
	var base := Craft.base_chance(t)
	check("+9 → +10 d'une pièce niveau 85 : chance de base 30 %", is_equal_approx(base, 0.3) and is_equal_approx(Craft.success_chance(t), 0.3))
	t["pity_n"] = 2
	check("deux échecs : chance +20 % de la base (36 %)", is_equal_approx(Craft.success_chance(t), 0.36))
	t["pity_n"] = 9
	check("bonus de chance plafonné à ×1,5 (45 %)", is_equal_approx(Craft.success_chance(t), 0.45))
	t["pity"] = 1.0
	check("jauge pleine : réussite assurée", Craft.success_chance(t) >= 1.0 and Craft.tries_max(t) == 1)
	check("échec : la pièce reste au même +N (texte)", Craft.failure_text(_piece(85, 7)).begins_with("la pièce reste à +7"))
	# 300 pièces de +9 à +10 : jamais de niveau perdu, toujours réussi en 4 essais au plus ; la jauge repart à zéro
	var worst := 0
	var lost := 0
	var reset_ok := true
	var gauge_ok := true
	for i in 300:
		var p := _piece(85, 9)
		p["up_rolls"] = [["hp", 1.0, 4], ["hp", 1.0, 6], ["hp", 1.0, 8]]
		var n := 0
		while int(p.upgrade) < 10 and n < 20:
			var before := Craft.pity(p)
			var r := Craft.upgrade(p)
			n += 1
			if int(p.upgrade) < 9 or (p.up_rolls as Array).size() < 3:
				lost += 1
			if not bool(r.ok) and not (Craft.pity(p) > before and int(p.pity_n) == n):
				gauge_ok = false
		worst = maxi(worst, n)
		if p.has("pity") or p.has("pity_n"):
			reset_ok = false
	check("300 pièces +9 → +10 : aucune perte (%d), réussite en 4 essais au plus (pire : %d)" % [lost, worst], lost == 0 and worst <= 4 and worst >= 2)
	check("chaque échec remplit la jauge et compte l'échec", gauge_ok)
	check("la réussite vide la jauge de la pièce", reset_ok)
	# la pierre de chance ajoute des chances, sans rien protéger d'autre
	var s := _piece(85, 6)
	check("pierre de chance : +10 % (70 → 80 %)", is_equal_approx(Craft.success_chance(s, Craft.stone_key("lucky")), Craft.base_chance(s) + 0.1))
	check("plus aucune « rétrogradation » dans les textes des pierres", not Craft.describe_key(Craft.stone_key("safety")).contains("redescend") and Craft.label(Craft.stone_key("safety")) == "Pierre de chance")


## Pièce simple de niveau [param level] (sans modèle d'Eden : niveau de puissance = niveau).
func _plain(level: int, up: int, slot := "weapon") -> Dictionary:
	return {"uid": "gx2_%d_%d_%s" % [level, up, slot], "slot": slot, "level": level, "rarity": Items.MYTHIC, "upgrade": up, "name": "Essai", "affixes": {}}


func _test_plan() -> void:
	var it := _plain(85, 5)
	var plan := Craft.plan_upgrade(it, 8)
	check("viser +8 depuis +5 : 3 crans, attendu ≤ au pire", int(plan.steps) == 3 and float(plan.tries) <= float(plan.tries_max) and float(plan.tries) >= 3.0)
	check("viser : au pire = somme des pires de chaque cran (%d)" % int(plan.tries_max), int(plan.tries_max) == int(Craft._tries(0.7, 0, 0.0).y) + int(Craft._tries(0.6, 0, 0.0).y) + int(Craft._tries(0.5, 0, 0.0).y))
	check("viser : hors partie, en cristaux (attendu %s, au pire %s)" % [str(plan.cost), str(plan.cost_max)], (plan.cost as Dictionary).has("crystal") and int(plan.cost.crystal) <= int(plan.cost_max.crystal) and int(plan.cost.crystal) >= Forge.upgrade_crystals(Items.power_level(it), 5, 8))
	it["pity"] = 1.0
	check("viser : la persévérance de la pièce compte pour le premier cran", int(Craft.plan_upgrade(it, 6).tries_max) == 1)
	var full := Craft.plan_upgrade(_plain(85, 0), 10)
	print("  +0 → +10, niveau 85 (arme) : attendu ≈ %d cristaux, au pire %d, %d crist. si tout réussit" % [int(full.cost.crystal), int(full.cost_max.crystal), Forge.upgrade_crystals(85, 0, 10)])
	check("+0 → +10 d'une pièce niveau 85 : attendu 1 300 à 1 800 cristaux (≈ l'ancien coût avec pierres)", int(full.cost.crystal) >= 1300 and int(full.cost.crystal) <= 1800)
	Profile.in_run = true
	check("en partie : le coût est en or", (Craft.plan_upgrade(_piece(30, 5), 6).cost as Dictionary).has("gold"))
	Profile.in_run = false


func _test_reforge() -> void:
	var it := _piece(60, 6, "weapon")
	it["up_rolls"] = [["patk", 5.0, 4], ["crit", 0.02, 6]]
	Profile.materials["crystal"] = 100
	var txt := Forge.reforge(it, "patk")
	var pend := Forge.reforge_pending(it)
	check("réajuster : le jet est tiré, l'ancien reste en place tant qu'on n'a pas choisi (%s)" % txt, not pend.is_empty() and float(it.up_rolls[0][1]) == 5.0 and txt.contains("→"))
	var paid := 100 - Profile.amount("crystal")
	check("réajuster : payé une fois", paid == int(Forge.reforge_cost(it).crystal))
	check("réajuster : un second tirage attend le choix (rien payé)", Forge.reforge(it, "crit").begins_with("Choisis") and 100 - Profile.amount("crystal") == paid)
	Forge.reforge_choose(it, false)
	check("garder l'ancien : la stat ne change pas, plus rien en attente", float(it.up_rolls[0][1]) == 5.0 and Forge.reforge_pending(it).is_empty() and not it.has("reroll"))
	Forge.reforge(it, "crit")
	var new_v := float(Forge.reforge_pending(it).new)
	Forge.reforge_choose(it, true)
	check("prendre le nouveau : la stat prend le nouveau jet", is_equal_approx(float(it.up_rolls[1][1]), new_v))
	# jet périmé (stat disparue) : oublié
	it["reroll"] = {"stat": "hp", "i": 5, "old": 1.0, "new": 2.0}
	check("jet périmé : oublié", Forge.reforge_pending(it).is_empty())


# --- interface de la Forge -------------------------------------------------------------------------------------------
func _test_forge_ui() -> void:
	ForgeBench.fast = true
	var fb := ForgeBench.new()
	add_child(fb)
	await get_tree().process_frame
	var it := _piece(30, 5)
	Profile.inventory = [it]
	Profile.stash = {Craft.fortify_key(Craft.fortify_kind(it), Craft.fortify_level_for(it)): 40}
	Profile.materials["crystal"] = 5000
	fb.refresh()
	fb.grid.select_item(it)
	await get_tree().process_frame
	check("forge : la piste des 10 crans est là", not fb.actions.find_children("*", "Track", true, false).is_empty() or fb.actions.get_children().any(func(c): return c is ForgeWidgets.Track))
	var all := _texts(fb)
	check("forge : persévérance écrite avant l'appui", all.contains("Persévérance"))
	check("forge : conséquence d'un échec non punitive écrite", all.contains("Rien d'autre n'est perdu") and not all.contains("redescend"))
	check("forge : viser +8 avec le coût attendu et au pire", all.contains("attendu") and all.contains("au pire") and _button_with(fb, "Fortifier jusqu'à +8") != null)
	var plus := _button_with(fb._pinned, "›")  # le › de « Viser » (celui de « Tout monter », lot GX-4, est au-dessus de la grille)
	if plus:
		plus.pressed.emit()
		await get_tree().process_frame
	check("forge : › vise un cran plus haut (+9)", _button_with(fb, "Fortifier jusqu'à +9") != null)
	var chain := _button_with(fb, "Fortifier jusqu'à")
	if chain:
		chain.pressed.emit()
		await get_tree().create_timer(0.3).timeout
	check("forge : enchaîner monte la pièce et s'arrête au palier +6 (+%d)" % int(it.upgrade), int(it.upgrade) == 6)
	check("forge : le verdict dit les essais", fb._bar.visible and fb._bar._msg.text.contains("essai"))
	# réajuster : choix après tirage
	it["up_rolls"] = [["hp", 20.0, 4], ["def", 2.0, 6]]
	fb.bench = "reforge"
	fb._on_selection()
	await get_tree().process_frame
	var rb: Button = null
	for b in _buttons(fb):
		if (b as Button).text.begins_with("Réajuster ") and (b as Button).text.contains("·"):
			rb = b
	if rb:
		rb.pressed.emit()
		await get_tree().create_timer(0.3).timeout
	check("réajuster : deux boutons, garder l'ancien ou prendre le nouveau", _button_with(fb, "Garder l'ancien") != null and _button_with(fb, "Prendre le nouveau") != null)
	var keep := _button_with(fb, "Garder l'ancien")
	if keep:
		keep.pressed.emit()
		await get_tree().process_frame
	check("réajuster : choix fait, retour aux boutons de tirage", Forge.reforge_pending(it).is_empty() and _button_with(fb, "Réajuster ") != null)
	fb.queue_free()
	await get_tree().process_frame
	ForgeBench.fast = false


func _test_save() -> void:
	Training.active = false
	Profile.reset_all()
	var it := _piece(40, 7)
	it["pity"] = 0.42
	it["pity_n"] = 2
	it["up_rolls"] = [["hp", 3.0, 4], ["def", 1.0, 6]]
	it["reroll"] = {"stat": "def", "i": 1, "old": 1.0, "new": 2.5}
	Profile.add_item(it)
	Profile.save_profile()
	Profile.load_profile()
	var back: Array = Profile.all_items().filter(func(x): return String(x.get("uid", "")) == String(it.get("uid", "?")))
	check("sauvegarde relue : persévérance et jet en attente gardés", back.size() == 1 and is_equal_approx(Craft.pity(back[0]), 0.42) and Craft.pity_fails(back[0]) == 2 and not Forge.reforge_pending(back[0]).is_empty())
	var old := _piece(40, 7)
	old.erase("pity")
	check("vieille pièce sans jauge : jauge vide", Craft.pity(old) == 0.0 and Craft.pity_fails(old) == 0)


## Lot GX-3 : le verdict « Meilleure / Moins bonne pour <classe> » compare la valeur au profil × le niveau (comme « Équiper
## le meilleur ») : une pièce de niveau 1 n'est jamais « meilleure » qu'une pièce de niveau 40 de même rareté.
func _test_verdict_levels() -> void:
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(90) + 1.0
	var high := Items.generate(40, 0.0, "chest", "warrior", Items.MYTHIC, "", Items.MYTHIC)
	high["quality"] = 1.0
	var low := high.duplicate(true)  # la même pièce, au niveau 1 et de meilleure qualité : sa note seule est plus haute
	low["uid"] = "gx3_low"
	low["level"] = 1
	low["plevel"] = 1
	low.erase("eden")
	low["quality"] = 1.2
	Profile.install_gear({"chest": high})
	check("verdict (GX-3) : une pièce de niveau 1 n'est pas « meilleure » qu'une de niveau %d" % int(high.level),
		String(Items.verdict(low, Profile.equipped.chest).tone) == "loss" and FabricationPage.verdict_text(low).contains("Moins bonne"))


# --- Plans de donjon : voir la pièce avant de la fabriquer ----------------------------------------------------------
func _hero(lv: int) -> void:
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(lv) + 1.0


func _test_dungeon_plans() -> void:
	Profile.reset_all()
	Profile.in_run = false
	Profile.unlocked_features = ["dungeons"]
	Profile.plans = ["plan_limestone"]
	Profile.insignia = 1000
	Profile.inventory = []
	_hero(90)
	var mori := BossLibrary.zone_boss("limestone")
	var slots := FabricationPage.slots_of(mori)
	var page := FabricationPage.new()
	add_child(page)
	await get_tree().process_frame
	page.refresh()
	await get_tree().process_frame
	var cells: Array = page._grid.find_children("*", "", true, false).filter(func(n): return n is ItemWidgets.ItemSlot)
	var shown := FabricationPage.preview(mori, String(slots[0]))
	check("plans de donjon : la pièce se voit avant d'être fabriquée (case de l'objet)", cells.size() == 1 and int((cells[0] as ItemWidgets.ItemSlot).item.get("eden", -1)) == int(shown.get("eden", -2)))
	var txt := _texts(page)
	check("plans de donjon : rareté, emplacement, niveau et verdict écrits", txt.contains("niveau %d" % int(shown.level)) and (txt.contains("Emplacement libre") or txt.contains("Meilleure") or txt.contains("Moins bonne") or txt.contains("Équivalente")))
	check("plans de donjon : pas de pourcentage dans l'aperçu", not FabricationPage.preview_text(shown).contains("%"))
	check("plans de donjon : « Fabriquer » puis « Fabriquer et porter »", _button_with(page, "Fabriquer · ") != null and _button_with(page, "Fabriquer et porter") != null)
	# l'autre emplacement du boss : l'aperçu suit
	var other := _button_with(page, String(Items.SLOT_NAMES.get(slots[1], slots[1])))
	if other:
		other.pressed.emit()
		await get_tree().process_frame
	cells = page._grid.find_children("*", "", true, false).filter(func(n): return n is ItemWidgets.ItemSlot)
	check("plans de donjon : choisir l'autre emplacement change l'aperçu (%s)" % slots[1], cells.size() == 1 and String((cells[0] as ItemWidgets.ItemSlot).item.get("slot", "")) == String(slots[1]))
	# ce qui est montré est ce qui est fabriqué
	var want := FabricationPage.preview(mori, String(slots[1]))
	var wear := _button_with(page, "Fabriquer et porter")
	if wear:
		wear.pressed.emit()
		await get_tree().process_frame
	var worn: Dictionary = Profile.equipped.get(String(slots[1]), {})
	check("fabriquer et porter : la pièce montrée est fabriquée et portée", int(worn.get("eden", -1)) == int(want.get("eden", -2)) and is_equal_approx(float(worn.get("quality", 0.0)), float(want.get("quality", 1.0))) and page._msg.text.begins_with("Fabriqué et porté"))
	check("fabriquer et porter : payé une fois", Profile.insignia == 1000 - FabricationPage.cost(mori))
	check("après fabrication : un nouvel aperçu est tiré", FabricationPage.preview(mori, String(slots[1])) != want)
	# niveau trop haut : on fabrique, on ne porte pas
	_hero(1)
	page.refresh()
	await get_tree().process_frame
	var w2 := _button_with(page, "Fabriquer et porter")
	check("niveau de héros trop bas : « Fabriquer et porter » grisé, la raison écrite", w2 != null and w2.disabled and _texts(page).contains("fabriquer reste permis"))
	page.queue_free()
	await get_tree().process_frame


# --- Fabriquer v2 : paliers, poupée, palier entier -----------------------------------------------------------------
func _test_shop_v2() -> void:
	Profile.reset_all()
	Profile.in_run = false
	Profile.selected_class = "warrior"
	Profile.inventory = []
	_hero(30)
	var wt := Items.default_weapon_type("warrior")
	var seen: Array = []
	for slot in ["weapon", "head", "chest", "ring"]:
		var pool := GearShopPage.tier_pool(1, 1, slot, wt)
		if not pool.is_empty():
			seen.append(int(pool[0].id))
	Profile.seen_gear = seen
	Profile.insignia = 5
	var page := GearShopPage.new()
	add_child(page)
	await get_tree().process_frame
	page.refresh()
	page._tier = Vector2i(1, 1)
	page._show_tier()
	await get_tree().process_frame
	check("paliers : vue par défaut, douze cartes dans la colonne", page.view == "tiers" and page._tier_list.get_child_count() == 12)
	check("poupée du palier : les neuf emplacements du kit d'un coup", page._kit_grid.get_child_count() == 9 and page._kit.size() == 9)
	var buy := page._kit.filter(func(k): return k.state == "buy").size()
	check("poupée : %d plans connus, le reste à trouver avec le lieu" % buy, buy == seen.size() and page._kit.filter(func(k): return k.state == "locked").size() == 9 - seen.size() 		and _texts(page._kit_grid).contains(GearShopPage.tier_zone(1, 1)))
	var todo := GearShopPage.kit_to_craft(page._kit)
	check("palier entier : « Fabriquer les %d plans connus · %d insignes »" % [seen.size(), int(todo.total)], page._kit_all.visible and page._kit_all.text.begins_with("Fabriquer les %d plans connus" % seen.size()) and page._kit_all.text.contains(GearPower.fmt(int(todo.total))))
	check("palier entier : trop peu d'insignes : grisé, « il en manque N ≈ X cartes de Survie »", page._kit_all.disabled and page._kit_miss.text.begins_with("il en manque") and page._kit_miss.text.contains("carte"))
	check("fiche : « Il te manque N insignes ≈ X cartes »", page._short.text.begins_with("Il te manque") and page._short.text.contains("≈"))
	check("conversion : une carte de Survie ≈ le tiers d'une victoire (%d insignes)" % Economy.insignia_per_map(1), Economy.insignia_per_map(1) == roundi(Economy.survival_insignia(3, Economy.SURVIVAL_KILLS, Economy.SURVIVAL_ELITES, 1, true) / 3.0) and Economy.maps_for(1) == 1)
	Profile.insignia = int(todo.total) + 40
	GearShopPage.skip_confirm = true
	page.refresh()
	page._tier = Vector2i(1, 1)
	page._show_tier()
	page._kit_all.pressed.emit()
	await get_tree().process_frame
	GearShopPage.skip_confirm = false
	check("palier entier : %d pièces fabriquées, coût exact payé" % seen.size(), Profile.inventory.size() == seen.size() and Profile.insignia == 40)
	check("palier : jauge %d / 9 et plus rien à fabriquer" % GearShopPage.kit_done(1, 1, "warrior", GearShopPage.owned_ids()), GearShopPage.kit_done(1, 1, "warrior", GearShopPage.owned_ids()) == seen.size() and not page._kit_all.visible)
	# fabriquer et porter depuis la fiche
	var more := GearShopPage.tier_pool(1, 1, "legs", wt)
	if not more.is_empty():
		Profile.seen_gear.append(int(more[0].id))
		Profile.insignia = 500
		page.refresh()
		page._tier = Vector2i(1, 1)
		page._show_tier()
		page._select(int(page._kit.filter(func(k): return k.slot == "legs")[0].e.id))
		check("fiche : « Fabriquer et porter » visible", page._wear.visible and not page._wear.disabled and page._wear.text == "Fabriquer et porter")
		var want := page._sel
		page._wear.pressed.emit()
		await get_tree().process_frame
		check("fabriquer et porter : jambières portées", int(Profile.equipped.get("legs", {}).get("eden", -1)) == want and page._short.text.begins_with("Fabriqué et porté"))
	# catalogue toujours là
	page.set_view("catalog")
	check("catalogue complet : les filtres reviennent", page._bar.visible and not page._kit_box.visible and page._rows.size() >= 0)
	page.set_view("tiers")
	check("retour aux paliers", page._kit_box.visible and not page._bar.visible)
	page.queue_free()
	await get_tree().process_frame
