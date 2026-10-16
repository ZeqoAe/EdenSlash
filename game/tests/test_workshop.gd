extends Node
## Atelier (lot U5, textes du lot A3) : Fabriquer (ex-Armurerie : états, filtres, pages, compteur, prix), Fabrication (cartes, état vide, fabriquer),
## Forge (avant → après, coûts en cristaux, établis), bourse commune et prix de la fusion de gemmes.
## godot --headless --path game res://tests/test_workshop.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _find_buttons(root: Node, out: Array) -> void:
	if root is Button:
		out.append(root)
	for c in root.get_children():
		_find_buttons(c, out)


func _button_with(root: Node, prefix: String) -> Button:
	var all: Array = []
	_find_buttons(root, all)
	for b in all:
		if (b as Button).text.begins_with(prefix):
			return b
	return null


func _label_with(root: Node, part: String) -> Label:
	for c in root.find_children("*", "Label", true, false):
		if (c as Label).text.contains(part):
			return c
	return null


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.in_run = false
	await _test_armory()
	await _test_fabrication()
	await _test_forge()
	await _test_purse()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _test_armory() -> void:
	var heads := SlotChests.pool("head", 1, 2)
	var legs := SlotChests.pool("legs", 2, 2)
	var seen: Array = [int(heads[0].id), int(heads[1].id), int(legs[0].id)]
	Profile.seen_gear = seen
	Profile.insignia = 500
	Profile.inventory = []
	Profile.equipped = {}
	Profile.add_item(GearShopPage.make(GameData.eden_by_id[int(legs[0].id)]))  # déjà achetée
	var page := GearShopPage.new()
	add_child(page)
	await get_tree().process_frame
	page.refresh()
	var total := Completion.armory_total()
	check("armurerie : tout le catalogue est listé (%d pièces)" % total, page._all.size() >= total and total > 100)
	var by := {"buy": 0, "owned": 0, "locked": 0}
	for r in page._all:
		by[r.state] += 1
	check("armurerie : 2 à acheter, 1 possédée, le reste à découvrir", by.buy == 2 and by.owned == 1 and by.locked == page._all.size() - 3)
	check("armurerie : par défaut, seules les pièces à acheter", page._rows.size() == 2 and page._rows.all(func(r): return r.state == "buy"))
	check("armurerie : compteur « découvertes / total » avec le vrai total", page._count.text.contains(GearPower.fmt(total)) and page._count.text.begins_with("%d /" % Completion.armory_done()) and page._count.text.ends_with("plans découverts"))
	check("armurerie : la première pièce est choisie, bouton d'achat avec son prix", page._buy.visible and page._buy.text.begins_with("Fabriquer · ") and page._buy.text.contains("insignes") and page._buy.text.contains(GearPower.fmt(GearShopPage.price(page._row_of(page._sel).e))))
	# A3 : plus jamais « acheter » pour une pièce, statuts et ligne « Plan trouvé »
	check("fabriquer : statuts À fabriquer / Fabriquées / Plans à découvrir / Tous / Portables", STATUS_LABELS == page.STATUSES.map(func(s): return String(s[1])))
	var texts := _page_texts(page)
	check("fabriquer : aucun texte ne parle d'acheter une pièce (%s)" % "|".join(texts.filter(func(t): return t.to_lower().contains("achet"))), texts.all(func(t): return not t.to_lower().contains("achet")))
	var first_id := int(page._row_of(page._sel).id)
	check("fabriquer : le plan dit où il a été trouvé (époque, carte)", Completion.plan_place(first_id).begins_with("Époque ") and Completion.plan_place(first_id).contains(" · ")
		and page._detail_box.find_children("*", "Label", true, false).any(func(l): return (l as Label).text.begins_with("Plan trouvé : Époque ")))
	check("fabriquer : l'époque I commence à Monts Calcaires", Completion.plan_place(int(SlotChests.pool("head", 1, 1)[0].id)) == "Époque I · %s" % String(GameData.zone("limestone").get("name", "")))
	# à découvrir : silhouettes, pas de bouton, époque indiquée
	page._f_status.select(2)
	page._apply()
	check("armurerie : « Plans à découvrir » : que des silhouettes, pas de bouton", not page._rows.is_empty() and page._rows.all(func(r): return r.state == "locked") and not page._buy.visible)
	check("armurerie : les cases à découvrir sont des silhouettes", page._grid.get_child(0) is GearShopPage.Silhouette)
	check("armurerie : le détail d'une pièce à découvrir dit où la trouver", page._detail_box.find_children("*", "Label", true, false).any(func(l): return (l as Label).text.begins_with("Plan à trouver : Époque")))
	# toutes + pages
	page._f_status.select(3)
	page._apply()
	check("armurerie : « Toutes » : possédées et à acheter avant les silhouettes", page._rows[0].state == "buy" and page._rows[2].state == "owned" and page._rows[3].state == "locked")
	check("armurerie : plusieurs pages, la suivante s'ouvre", page._next.visible and page._page == 0)
	page._next.pressed.emit()
	check("armurerie : page 2", page._page == 1 and page._page_label.text.begins_with("2 /"))
	page._page = 0
	# filtres
	page._f_status.select(3)
	page._f_epoch.select(1)
	page._apply()
	check("armurerie : filtre d'époque", not page._rows.is_empty() and page._rows.all(func(r): return int(r.epoch) == 1))
	page._f_epoch.select(0)
	page._f_slot.select(_slot_index(page, "head"))
	page._apply()
	check("armurerie : filtre d'emplacement", not page._rows.is_empty() and page._rows.all(func(r): return r.slot == "head"))
	page._f_slot.select(_slot_index(page, "weapon"))
	page._f_class.select(page._class_ids.find("warrior"))
	page._apply()
	var wt := Items.default_weapon_type("warrior")
	check("armurerie : filtre de classe (les armes de son type seulement : %s)" % wt, not page._rows.is_empty() and page._rows.all(func(r): return String(r.e.get("wtype", "")) == wt))
	page._f_slot.select(0)
	page._f_class.select(0)
	page._f_status.select(0)
	page._apply()
	# insignes insuffisants
	Profile.insignia = 5
	page.refresh()
	check("armurerie : pas assez d'insignes : bouton grisé et ce qui manque", page._buy.disabled and page._short.text.contains("Il te manque"))
	# achat
	Profile.insignia = 500
	page.refresh()
	var id := page._sel
	var p := GearShopPage.price(GameData.eden_by_id[id])
	page._on_buy()
	check("armurerie : achat (%d insignes), la pièce passe en possédée" % p, Profile.insignia == 500 - p and page._row_of(id).state == "owned")
	page._on_buy()
	check("armurerie : une seule fois", Profile.insignia == 500 - p)
	# rien découvert : état vide utile, panneau de détail caché
	Profile.seen_gear = []
	Profile.inventory = []
	page.refresh()
	check("armurerie : rien de découvert : un message utile et pas de panneau vide", page._empty.visible and page._empty.text.contains("Survie") and not page._right.visible)
	page.queue_free()
	await get_tree().process_frame


const STATUS_LABELS := ["À fabriquer", "Fabriquées", "Plans à découvrir", "Tous", "Portables"]


## Tous les textes lisibles de la page (étiquettes, boutons, listes déroulantes, infobulles).
func _page_texts(node: Node) -> Array:
	var out: Array = []
	for n in [node] + node.find_children("*", "", true, false):
		if n is Label or n is Button:
			out.append(String(n.text))
		if n is OptionButton:
			for i in n.item_count:
				out.append(n.get_item_text(i))
		if n is RichTextLabel:
			out.append(n.get_parsed_text())
		if n is Control and n.tooltip_text != "":
			out.append(String(n.tooltip_text))
	return out


func _slot_index(page: GearShopPage, slot: String) -> int:
	return maxi(page._slot_ids.find(slot), 0)


func _test_fabrication() -> void:
	Profile.plans = []
	Profile.materials["crystal"] = 500
	Profile.inventory = []
	var page := FabricationPage.new()
	add_child(page)
	await get_tree().process_frame
	page.refresh()
	# lot A1 : un plan par boss (48), fabriqué en insignes ; les cristaux ne servent plus ici
	var total := Dungeons.plan_total()
	check("fabrication : sans plan, l'état vide dit quoi faire", page._banner.visible and page._grid.get_child_count() == 0)
	check("fabrication : compteur de plans", page._count.text == "0 / %d plans" % total)
	Profile.plans = ["plan_limestone"]  # ancien plan de zone : converti en plan du boss d'origine
	Profile.insignia = 500
	page.refresh()
	await get_tree().process_frame
	check("fabrication : avec un plan, plus de bandeau, une carte à fabriquer", not page._banner.visible and page._grid.get_child_count() == 1 and page._count.text == "1 / %d plans" % total)
	var price := FabricationPage.cost(BossLibrary.zone_boss("limestone"))
	var b := _button_with(page, "Fabriquer")
	check("fabrication : bouton avec le coût en insignes", b != null and b.text == "Fabriquer · %d insignes" % price and not b.disabled)
	if b:
		b.pressed.emit()
		check("fabrication : une pièce fabriquée, insignes payés, cristaux gardés", Profile.inventory.size() == 1 and Profile.insignia == 500 - price and Profile.amount("crystal") == 500 and page._msg.text.begins_with("Fabriqué"))
	Profile.insignia = price - 5
	page.refresh()
	await get_tree().process_frame
	var b2 := _button_with(page, "Fabriquer")
	check("fabrication : trop peu d'insignes : bouton grisé, ce qui manque dit", b2 != null and b2.disabled and _label_with(page, "il te manque 5 insignes") != null)
	check("fabrication : accord de « insigne »", FabricationPage.insignia_text(1) == "1 insigne" and FabricationPage.insignia_text(2) == "2 insignes")
	page.queue_free()
	await get_tree().process_frame


func _test_forge() -> void:
	Profile.reset_all()
	Profile.in_run = false
	ForgeBench.fast = true
	var fb := ForgeBench.new()
	add_child(fb)
	await get_tree().process_frame
	var it := Items.generate(30, 1.0, "chest", "warrior", 0, "", 0)
	it["upgrade"] = 2
	Profile.inventory = [it]
	var need := Craft.fortify_key(Craft.fortify_kind(it), Craft.fortify_level_for(it))
	Profile.stash = {need: 5}
	Profile.materials["crystal"] = 500
	fb.refresh()
	check("forge : sans pièce, un état vide d'une phrase", fb.detail.text.contains("Choisis une pièce") and not fb._bar.visible)
	fb.grid.select_item(it)
	await get_tree().process_frame
	check("forge : avant → après (amélioration +2 → +3)", fb.detail.text.contains("+2") and fb.detail.text.contains("+3") and fb.detail.text.contains("→"))
	check("forge : quatre stats au plus dans le tableau", fb.detail.text.count("→") <= ForgeBench.MAIN_STATS + 2)
	check("forge : le coût en cristaux est visible (tu en as 500)", fb.detail.text.contains("Coût") and fb.detail.text.contains("crist") and fb.detail.text.contains("tu en as 500"))
	var up := _button_with(fb, "Fortifier")
	check("forge : le bouton d'action est rangé en bas (zone épinglée)", up != null and up.get_parent() == fb._pinned)
	check("forge : le prix est en mots", up != null and up.text.contains("crist") and not up.text.contains("crist."))
	# pas assez de cristaux : le coût passe en rouge et le bouton se grise
	Profile.materials["crystal"] = 0
	fb._on_selection()
	await get_tree().process_frame
	var up0 := _button_with(fb, "Fortifier")
	check("forge : sans cristaux, le coût est en rouge et l'action grisée", fb.detail.text.contains("#ff7a7a") and up0 != null and up0.disabled)
	Profile.materials["crystal"] = 500
	# établis : chacun parle de ce qu'il fait
	fb.bench = "polish"
	fb._on_selection()
	await get_tree().process_frame
	check("forge : Polir montre la qualité avant → après et son coût", fb.detail.text.contains("Qualité") and fb.detail.text.contains("jusqu'à") and fb.detail.text.contains("Coût") and _button_with(fb, "Polir ·") != null)
	fb.bench = "dismantle"
	fb._on_selection()
	await get_tree().process_frame
	var dm := _button_with(fb, "Démonter ·")
	check("forge : Démonter montre les cristaux avant → après, bouton en mots", fb.detail.text.contains("Cristaux") and dm != null and dm.text.contains("crist") and not dm.text.contains("crist.") and fb.detail.text.contains("500"))
	fb.bench = "gems"
	fb._on_selection()
	await get_tree().process_frame
	check("forge : Gemmes montre les emplacements", fb.detail.text.contains("Emplacements"))
	# la barre : cachée au repos, visible pendant et après l'action
	fb.bench = "polish"
	fb._on_selection()
	await get_tree().process_frame
	var pol := _button_with(fb, "Polir ·")
	if pol:
		pol.pressed.emit()
		check("forge : la barre apparaît pendant l'action", fb._bar.visible)
		await get_tree().create_timer(0.3).timeout
		check("forge : le verdict reste affiché", fb._bar.visible and fb._bar._title.text in ["RÉUSSI", "RATÉ"])
	# changer de pièce efface le verdict
	fb.grid.clear_selection()
	await get_tree().process_frame
	check("forge : changer de sélection range le verdict", not fb._bar.visible)
	# fusion de gemmes : prix en cristaux hors run, en or en run
	check("fusion : hors run, 2 cristaux pour la plus petite taille", Forge.fuse_price(0) == {"crystal": 2})
	Profile.in_run = true
	check("fusion : en run, de l'or", Forge.fuse_price(0) == {"gold": Forge.fuse_cost(0)})
	Profile.in_run = false
	Profile.stash = {Craft.gem_key("ruby", 0): 3}
	Profile.bag = Profile.stash  # (la page de forge la lie à la réserve quand elle est visible)
	Profile.materials["crystal"] = 10
	check("fusion : le prix affiché est celui qui est payé", MerchantPages.price_words(Forge.fuse_price(0)) == "2 cristaux")
	Forge.fuse("ruby", 0)
	Profile.bag = {}
	check("fusion : payée au même prix", Profile.amount("crystal") == 8)
	check("mots : un cristal, des cristaux, de l'or", MerchantPages.price_words({"crystal": 1}) == "1 cristal" and MerchantPages.price_words({"crystal": 3}) == "3 cristaux" and MerchantPages.price_words({"gold": 90}) == "90 or")
	fb.queue_free()
	await get_tree().process_frame
	ForgeBench.fast = false
	Profile.reset_all()


func _test_purse() -> void:
	Profile.insignia = 1234
	Profile.materials["crystal"] = 1
	var purse := WorkshopPurse.new()
	add_child(purse)
	check("bourse : insignes (milliers séparés) et cristal au singulier", _label_with(purse, "1 234 insignes") != null and _label_with(purse, "1 cristal") != null)
	Profile.materials["crystal"] = 12
	purse.refresh()
	check("bourse : cristaux au pluriel", _label_with(purse, "12 cristaux") != null)
	purse.queue_free()
	await get_tree().process_frame
