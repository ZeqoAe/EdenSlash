extends Node
## Lot GX-3 (fin du backlog BM-GEAR hors GX-2) : objectifs (core/goals.gd : 1 épinglé + 5 suivis, ce qui manque, où aller,
## barre d'objectif, ★ sur les listes, filtre « ★ Objectifs », bilan), fiche d'objet v2 (verdict au profil sans pourcentage,
## stats ★, « Aussi », niveau requis en fraise, panoplie « → N avec celle-ci », provenance, carte portée à côté), sac (cadenas,
## « neuf », pastilles de filtre, pièces inutiles, démontage en masse et annulation), « Le meilleur ▲N », poupée ▲, PE vers la
## difficulté suivante, « Nouveau plan » des coffres, bilan qui nomme les plans, boussole (pièce trop haute), Registre
## (« Monte ton niveau de héros »), textes (plus d'« Armurerie »).
## godot --headless --path game res://tests/test_gx3.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _plain(bb: String) -> String:
	var rx := RegEx.new()
	rx.compile("\\[[^\\]]*\\]")
	return rx.sub(bb, "", true)


func _texts(root: Node) -> String:
	var out: PackedStringArray = []
	for n in [root] + root.find_children("*", "", true, false):
		if n is Label or n is Button:
			out.append(String(n.text))
		elif n is RichTextLabel:
			out.append((n as RichTextLabel).get_parsed_text())
	return "\n".join(out)


func _button_with(root: Node, prefix: String) -> Button:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(prefix) and (b as Button).is_visible_in_tree():
			return b
	return null


func _hero(lv: int) -> void:
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(lv) + 1.0


## Pièce d'Eden de l'emplacement [param slot] (arme : du type de [param wtype]) au niveau le plus proche de [param lv].
func _piece(slot: String, lv: int, wtype := "", rarity := -1) -> Dictionary:
	var best: Dictionary = {}
	for e in GameData.eden_by_slot.get(wtype if slot == "weapon" else slot, []):
		if GameData.is_awakened(e) or int(e.level) > lv or ((e.get("r", {}) as Dictionary).is_empty() and not e.has("passive")):
			continue
		if best.is_empty() or int(e.level) > int(best.level):
			best = e
	var it := Items.from_template(best, int(best.level), int(best.rarity) if rarity < 0 else rarity)
	it["upgrade"] = 0
	return it


func _reset() -> void:
	Training.active = true
	Profile.reset_all()
	Profile.in_run = false
	Profile.selected_class = "warrior"
	HeroLevel.ensure()
	_hero(53)


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Settings.reset_all()
	_reset()
	_test_goals()
	_test_lock_new()
	_test_card()
	_test_useless()
	_test_texts()
	await _test_inventory_ui()
	await _test_workshop_ui()
	_test_run_cards()
	_reset()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


# --- objectifs ------------------------------------------------------------------------------------------------------
func _test_goals() -> void:
	_reset()
	var w := Items.default_weapon_type("warrior")
	var pool := GearShopPage.tier_pool(1, 2, "head", w)
	var a := int(pool[0].id)
	var b := int(GearShopPage.tier_pool(1, 2, "boots", w)[0].id)
	check("aucun objectif au départ", Goals.ids().is_empty() and Goals.pinned() == "" and Goals.line() == "")
	check("suivre : message « ★ Objectif »", Goals.follow(Goals.piece_id(a)).begins_with("★ Objectif"))
	Goals.follow(Goals.piece_id(b))
	check("le dernier souhait est épinglé, l'autre suivi", Goals.pinned() == Goals.piece_id(b) and Goals.count() == 2 and Goals.ids()[0] == Goals.piece_id(b))
	Goals.pin_next()
	check("⇄ : l'objectif suivant passe devant", Goals.pinned() == Goals.piece_id(a))
	# plan à trouver : la première étape, où aller
	var s := Goals.status(Goals.piece_id(a))
	check("plan pas encore trouvé : étape « Plan à trouver », aller en Survie (%s)" % s.line, not bool(s.plan) and String(s.line).begins_with("plan à trouver") and (s.go as Dictionary).has("menu"))
	check("ce qui manque : 3 étapes (plan, insignes, niveau)", (s.steps as Array).size() == 3)
	# plan trouvé, insignes qui manquent : « il en manque ≈ N cartes de Survie »
	Profile.seen_gear = [a]
	Profile.insignia = 0
	s = Goals.status(Goals.piece_id(a))
	check("plan trouvé, insignes qui manquent : « il en manque … cartes de Survie » (%s)" % s.line, bool(s.plan) and String(s.line).contains("il en manque") and String(s.line).contains("carte"))
	Profile.insignia = 100000
	s = Goals.status(Goals.piece_id(a))
	check("tout est réuni : « prête à fabriquer », bouton vers Fabriquer", bool(s.ready) and String(s.line).begins_with("prête à fabriquer") and int((s.go as Dictionary).get("workshop", -1)) == 0)
	check("la boussole met l'objectif épinglé en premier conseil", String(Goals.advice().get("id", "")) == "goal" and String(Goals.advice().text).begins_with("★ Objectif"))
	# fabriquée puis portée : objectif atteint
	var it := GearShopPage.make(GameData.eden_by_id[a])
	Profile.add_item(it)
	s = Goals.status(Goals.piece_id(a))
	check("fabriquée : « porte-la »", bool(s.owned) and String(s.line).contains("porte"))
	Profile.equip(it)
	s = Goals.status(Goals.piece_id(a))
	check("portée : objectif atteint, plus de conseil de boussole", bool(s.worn) and Goals.advice().is_empty())
	check("objectifs atteints retirés (prune_done)", Goals.prune_done().size() == 1 and not Goals.has(Goals.piece_id(a)))
	# plafond : 1 + 5
	for e in GearShopPage.tier_pool(2, 1, "chest", w).slice(0, 8):
		Goals.follow(Goals.piece_id(int(e.id)))
	check("6 objectifs au plus (1 épinglé + 5 suivis)", Goals.count() == Goals.MAX)
	check("au-delà : refus avec un message", Goals.follow("999999").contains("au plus"))
	# sauvegarde relue
	Training.active = false
	Profile.save_profile()
	var saved := Goals.ids().duplicate()
	Profile.load_profile()
	check("sauvegarde relue : objectifs et épinglé gardés (records.goals)", Goals.ids() == saved)
	Training.active = true
	# objectif de plan de donjon
	_reset()
	var mori := BossLibrary.zone_boss("limestone")
	var slot := String(FabricationPage.slots_of(mori)[0])
	var gid := Goals.dungeon_id(mori, slot)
	Goals.follow(gid)
	s = Goals.status(gid)
	check("objectif de donjon : plan à trouver, aller au donjon (%s)" % s.line, Goals.is_dungeon(gid) and not bool(s.plan) and String((s.go as Dictionary).get("menu", "")) == "dungeon")
	Profile.plans = ["plan_limestone"]
	Profile.insignia = 100000
	s = Goals.status(gid)
	check("objectif de donjon : plan trouvé, prêt, vers Plans de donjon", bool(s.plan) and bool(s.ready) and int((s.go as Dictionary).get("workshop", -1)) == 1)
	# bilan : plan d'un objectif trouvé
	Goals.follow(Goals.piece_id(b))
	check("bilan : l'objectif dont le plan vient d'être trouvé est nommé", Goals.found_in([b]).size() == 1)


# --- verrou, « neuf » ----------------------------------------------------------------------------------------------
func _test_lock_new() -> void:
	_reset()
	var it := _piece("head", 30)
	Profile.add_item(it)
	check("hors partie : une pièce qui arrive au coffre est « neuve »", Profile.is_new(it))
	check("regardée : plus neuve", Profile.mark_seen(it) and not Profile.is_new(it))
	var it2 := _piece("legs", 30)
	Profile.add_item(it2)
	Profile.equip(it2)
	check("portée : plus neuve", not Profile.is_new(it2))
	var lk := _piece("boots", 30)
	Profile.add_item(lk)
	Profile.set_locked(lk, true)
	var free := _piece("gloves", 30)
	Profile.add_item(free)
	var got := Profile.disassemble_many([lk, free])
	check("démontage en masse : la pièce gardée reste, l'autre part", Profile.inventory.any(func(x): return is_same(x, lk)) and not Profile.inventory.any(func(x): return is_same(x, free)))
	check("démontage d'une pièce gardée seule : refusé (rien gagné)", Profile.disassemble(lk).is_empty() and Profile.inventory.any(func(x): return is_same(x, lk)))
	check("annuler le démontage : la pièce revient, les cristaux sont repris", Profile.undo_disassemble([free], got) and Profile.inventory.any(func(x): return is_same(x, free)))
	Profile.in_run = true
	var run_it := _piece("ring", 30)
	Profile.add_item(run_it)
	check("en partie : pas de pastille « neuf »", not Profile.is_new(run_it))
	Profile.in_run = false


# --- fiche d'objet v2 --------------------------------------------------------------------------------------------------
func _test_card() -> void:
	_reset()
	var worn := _piece("chest", 30)
	Profile.install_gear({"chest": worn})
	worn = Profile.equipped.chest
	var better := _piece("chest", 52, "", Items.MYTHIC)
	var worse := _piece("chest", 15)
	var short := ItemWidgets.card_text(better, "", false)
	var pl := _plain(short)
	check("verdict au profil de la classe : « Meilleure pour Guerrier »", pl.contains("Meilleure pour Guerrier"))
	check("carte courte : aucun pourcentage dans le verdict", not _plain(Items.verdict_line(better, worn, false)).contains("%"))
	check("carte courte : écart de PE (seul chiffre du verdict)", pl.contains("PE +"))
	check("carte courte : écarts ▲ / ▼ sur les lignes", short.contains("▲ +"))
	check("carte courte : « Porté : » puis « Maj : détails »", pl.contains("Porté :") and pl.contains("Maj : détails"))
	check("moins bonne : « Moins bonne pour Guerrier »", _plain(ItemWidgets.card_text(worse, "", false)).contains("Moins bonne pour Guerrier"))
	check("carte complète : l'écart au profil (le seul pourcentage, derrière Maj)", _plain(ItemWidgets.card_text(better, "", true)).contains("% au profil"))
	check("stats ★ de la classe marquées", short.contains("★"))
	var many := Items.generate(40, 1.0, "ring", "warrior", Items.LEGENDARY, "", Items.LEGENDARY)
	many["affixes"] = {"str": 10.0, "agi": 10.0, "int": 10.0, "wis": 10.0, "lck": 10.0}
	check("au-delà de 3 lignes : le reste sur une ligne grise « Aussi : »", _plain(Items.describe(many, false, {})).contains("Aussi :"))
	check("type d'armure dans le sous-titre", Items.armor_type(better) == "" or pl.contains(Items.armor_type(better)))
	check("emplacement libre : verdict « Emplacement libre »", _plain(Items.describe(_piece("back", 30), false, {})).contains("Emplacement libre"))
	# niveau trop haut : bandeau fraise à la place du verdict
	var high := _piece("head", 80)
	var ht := _plain(ItemWidgets.card_text(high, "", false))
	check("niveau trop haut : « Niveau N requis · tu es niveau 53 » à la place du verdict", ht.contains("Niveau %d requis · tu es niveau 53" % Items.required_level(high)) and not ht.contains("Meilleure pour"))
	# provenance
	Completion.armory_ids()
	Profile.seen_gear = [int(better.eden)]
	check("provenance : « Plan ✓ » d'une pièce dont le plan est connu", _plain(Items.describe(better, false, worn)).contains("Plan ✓"))
	# panoplie : ce que la pièce ajoute
	var setp := Items.generate(30, 0.0, "head", "warrior", 3, "", 5)
	setp["archetype"] = "storm"
	check("panoplie : « → 1 avec celle-ci »", _plain(Items.describe(setp, false, {})).contains("→ 1 avec celle-ci"))
	# le widget : la pièce portée à côté
	var card: ItemWidgets.ItemCard = ItemWidgets.item_card(better, "", 0)
	add_child(card)
	check("infobulle : la pièce portée posée à côté (deux panneaux)", card._worn_card != null and card.find_children("*", "RichTextLabel", true, false).size() == 2)
	card.queue_free()


# --- pièces inutiles -------------------------------------------------------------------------------------------------
func _test_useless() -> void:
	_reset()
	var w := Items.default_weapon_type("warrior")
	Profile.install_gear({"weapon": _piece("weapon", 45, w), "head": _piece("head", 45)})
	Profile._sync_vault()
	var best := _piece("head", 52, "", Items.MYTHIC)
	var junk := _piece("head", 28)
	var junk2 := _piece("head", 26)
	var kept := _piece("head", 27)
	kept["locked"] = true
	var up := _piece("head", 29)
	up["upgrade"] = 2
	var goal := _piece("head", 25)
	for it in [best, junk, junk2, kept, up, goal]:
		Profile.vault.append(it)
	Profile._lobby_view()
	Goals.follow(Goals.id_for_item(goal))
	var u := InventoryPage.useless_items()
	var has := func(x): return u.any(func(y): return String(y.uid) == String(x.uid))
	# (une pièce faible qui reste la meilleure de sa case pour un des 7 profils n'est pas « inutile »)
	check("inutiles : des pièces faibles sans amélioration (%d)" % u.size(), has.call(junk) or has.call(junk2))
	check("inutiles : jamais la meilleure de sa case", not has.call(best))
	check("inutiles : jamais une pièce gardée, améliorée, portée ou d'un objectif", not has.call(kept) and not has.call(up) and not has.call(Profile.equipped.head) and not has.call(goal))


# --- textes ------------------------------------------------------------------------------------------------------------
func _test_texts() -> void:
	_reset()
	check("Compass.after : plus d'« Armurerie »", not Compass.after("survival", {"seen": 3}).contains("Armurerie") and Compass.after("survival", {"seen": 3}).contains("plans découverts"))
	check("ResourceHelp : plus d'« Armurerie »", not str(ResourceHelp.tip("piece")).contains("Armurerie") and not str(ResourceHelp.tip("spirit")).contains("Armurerie"))
	# boussole : jamais une pièce trop haute pour le niveau de héros
	_hero(10)
	var w := Items.default_weapon_type("warrior")
	var hi: Dictionary = {}
	for e in GearShopPage.tier_pool(3, 2, "head", w):
		hi = e
		break
	Profile.seen_gear = [int(hi.id)]
	Profile.insignia = 1000000
	check("boussole : une pièce au-dessus du niveau de héros n'est pas « achetable » (niveau %d)" % int(hi.level), Compass.affordable_piece("warrior", ["head"]).is_empty())
	_hero(90)
	check("… au niveau 90 : elle l'est", not Compass.affordable_piece("warrior", ["head"]).is_empty())
	# Registre : « Monte ton niveau de héros »
	_reset()
	_hero(20)
	Profile.best_level = 80
	check("Registre : PE correcte au niveau de héros mais pas au niveau de référence → niveau de héros",
		ClassGear.hero_capped(0.8 * GearPower.expected(20)) and not ClassGear.hero_capped(0.5 * GearPower.expected(20)))
	_hero(80)
	check("… au niveau de référence : ce n'est plus le niveau qui manque", not ClassGear.hero_capped(0.8 * GearPower.expected(20)))


# --- écran Équipement ---------------------------------------------------------------------------------------------------
func _test_inventory_ui() -> void:
	_reset()
	var w := Items.default_weapon_type("warrior")
	Profile.install_gear({"weapon": _piece("weapon", 40, w), "chest": _piece("chest", 40), "head": _piece("head", 40)})
	Profile._sync_vault()
	var better := _piece("chest", 52, "", Items.MYTHIC)
	var junk := _piece("head", 28)
	Profile.vault.append(better)
	Profile.vault.append(junk)
	Profile.vault.append(_piece("head", 26))
	Profile._lobby_view()
	Profile.mark_new(better)
	var page := InventoryPage.new()
	add_child(page)
	await get_tree().process_frame
	page.refresh()
	await get_tree().process_frame
	var txt := _texts(page)
	check("sac : pastilles Ma classe, Portables, Nouveautés, Gardées, Inutiles", txt.contains("Ma classe") and txt.contains("Portables") and txt.contains("Nouveautés") and txt.contains("Gardées") and txt.contains("Inutiles"))
	check("tri « Pour ma classe »", txt.contains("Pour ma classe") or page._sort.get_item_text(InventoryPage.SORTS.size() - 1).contains("Pour ma classe"))
	check("poupée : ▲ sur le torse (le coffre a mieux)", page._doll.chest.better)
	check("« Le meilleur ▲N » hors de « Gérer »", page._best_btn.visible and page._best_btn.text.contains("▲"))
	page._chip = "new"
	page._refresh_grid()
	await get_tree().process_frame
	var shown: Array = page._grid.get_children().filter(func(c): return c is InventoryPage.StackSlot and not c.is_queued_for_deletion())
	check("pastille « Nouveautés » : seulement la pièce neuve", shown.size() == 1 and is_same(shown[0].entry.item, better))
	page._select({"kind": "item", "item": better})
	check("choisie : plus « neuve »", not Profile.is_new(better))
	check("fiche : bouton « Garder »", page._b_lock.visible and page._b_lock.text == "Garder")
	page._on_lock()
	check("cadenas posé : « Gardée », Démonter grisé", Profile.is_locked(better) and page._b_lock.text == "Gardée" and page._b_dismantle.disabled)
	page._on_dismantle()
	page._on_dismantle()
	check("démonter une pièce gardée : rien ne se passe", Profile.inventory.any(func(x): return is_same(x, better)))
	page._on_lock()
	check("cadenas retiré", not Profile.is_locked(better))
	# démontage en masse puis annulation
	page._chip = "useless"
	page._refresh_grid()
	var n := InventoryPage.useless_items().size()
	check("pastille « Inutiles » : bouton « Démonter les N pièces inutiles » (%d)" % n, n > 0 and page._mass_btn.visible and page._mass_btn.text.begins_with("Démonter les"))
	InventoryPage.skip_confirm = true
	var before := Profile.inventory.size()
	page._on_mass_dismantle()
	check("démontage en masse : %d pièce(s) en moins, « Annuler le démontage » proposé" % n, Profile.inventory.size() == before - n and page._undo_btn.visible)
	page._on_undo_dismantle()
	check("annuler : les pièces reviennent", Profile.inventory.size() == before)
	InventoryPage.skip_confirm = false
	# stats au survol
	page._preview_stats(better)
	var any_delta := false
	for k in page._stat_deltas:
		if String(page._stat_deltas[k].text).begins_with("▲") or String(page._stat_deltas[k].text).begins_with("▼"):
			any_delta = true
	check("survol : l'écart sur les stats du héros", any_delta)
	page._preview_stats({})
	check("fin du survol : les intitulés reviennent", String(page._stat_deltas.hp.text) == "PV")
	# « Le meilleur » : la liste avant / après
	var plan := EquipmentPage.PresetBar.best_plan("warrior")
	check("« Le meilleur » : le torse change pour la meilleure pièce", plan.any(func(r): return r.slot == "chest" and is_same(r.new, better)))
	page.preset_bar._open_best()
	await get_tree().process_frame
	var ask: InfoCard.Ask = null
	for c in page.preset_bar.get_children():
		if c is InfoCard.Ask:
			ask = c
	check("« Le meilleur » : aperçu avant d'appliquer (liste et Appliquer)", ask != null and ask.ok_button.text == "Appliquer" and _texts(ask).contains("→"))
	if ask:
		ask._finish(true)
		await get_tree().process_frame
	check("appliqué : le torse porté est la meilleure pièce", is_same(Profile.equipped.get("chest"), better))
	page.queue_free()
	await get_tree().process_frame


# --- Atelier : ★ Objectif, filtre, poupée du palier -----------------------------------------------------------------------
func _test_workshop_ui() -> void:
	_reset()
	var w := Items.default_weapon_type("warrior")
	var e: Dictionary = GearShopPage.tier_pool(1, 2, "head", w)[0]
	Profile.seen_gear = [int(e.id)]
	Profile.insignia = 5
	var shop := GearShopPage.new()
	add_child(shop)
	await get_tree().process_frame
	shop.refresh()
	shop._tier = Vector2i(1, 2)
	shop._show_tier()
	shop._select(int(e.id))
	var gb := _button_with(shop, "★ Objectif")
	check("Fabriquer : bouton « ★ Objectif »", gb != null)
	if gb:
		gb.pressed.emit()
		await get_tree().process_frame
	check("★ Objectif : la pièce est suivie et épinglée", Goals.pinned() == Goals.piece_id(int(e.id)))
	check("la barre d'objectif s'affiche en haut de la colonne", shop._goal_bar.visible and _texts(shop._goal_bar).contains(Items.display_name(Goals.item_of(Goals.piece_id(int(e.id))))))
	check("barre d'objectif : ce qui manque (insignes)", _texts(shop._goal_bar).to_lower().contains("il en manque"))
	shop.set_view("catalog")
	shop._f_status.select(GearShopPage.STATUSES.size() - 1)
	shop._apply()
	check("filtre « ★ Objectifs » : seulement l'objectif", shop._rows.size() == 1 and int(shop._rows[0].id) == int(e.id))
	shop.set_view("tiers")
	# un plan à trouver qui est un objectif : la poupée du palier le montre
	var locked: Dictionary = GearShopPage.tier_pool(1, 2, "boots", w)[-1]
	Goals.follow(Goals.piece_id(int(locked.id)))
	var k := GearShopPage.kit(1, 2, "warrior")
	check("poupée du palier : le plan visé est la case de son emplacement (★)", k.any(func(x): return x.slot == "boots" and int(x.e.id) == int(locked.id)))
	shop.queue_free()
	# Plans de donjon : ★
	_reset()
	Profile.unlocked_features = ["dungeons"]
	Profile.plans = ["plan_limestone"]
	var page := FabricationPage.new()
	add_child(page)
	await get_tree().process_frame
	page.refresh()
	await get_tree().process_frame
	var star := _button_with(page._grid, "★")
	if star:
		star.pressed.emit()
		await get_tree().process_frame
	var mori := BossLibrary.zone_boss("limestone")
	check("Plans de donjon : ★ suit la pièce de l'emplacement choisi", Goals.has(Goals.dungeon_id(mori, String(FabricationPage.slots_of(mori)[0]))))
	page.queue_free()
	await get_tree().process_frame


# --- Survie : « Nouveau plan », bilan ---------------------------------------------------------------------------------------
func _test_run_cards() -> void:
	_reset()
	Run.start_survival("warrior", 1)
	var w := Items.default_weapon_type("warrior")
	var pool := GearShopPage.tier_pool(1, 1, "head", w)
	var fresh := Items.from_template(pool[0], int(pool[0].level), int(pool[0].rarity))
	var known := Items.from_template(pool[-1], int(pool[-1].level), int(pool[-1].rarity))
	Profile.seen_gear.append(int(pool[-1].id))
	var c1: Dictionary = RunDirector.item_card(fresh, "gear")
	var c2: Dictionary = RunDirector.item_card(known, "gear")
	check("coffre d'emplacement : « Nouveau plan » sur une pièce jamais vue", String(c1.desc).contains("Nouveau plan"))
	check("coffre d'emplacement : « Plan connu » sinon", String(c2.desc).contains("Plan connu") or int(pool[0].id) == int(pool[-1].id))
	check("carte de pièce : plus de pourcentage dans la comparaison", not _plain(String(c1.desc).get_slice("\n", 0)).contains("%"))
	Run.seen_items = [int(pool[0].id)]
	Goals.follow(Goals.piece_id(int(pool[0].id)))
	var rows := ResultsScreen.kept_rows(true)
	var labels := rows.map(func(r): return String(r.text))
	check("bilan : « ★ Objectif : plan trouvé » en tête", labels.size() > 0 and String(labels[0]).begins_with("★ Objectif"))
	check("bilan : les plans découverts sont nommés", labels.any(func(t): return String(t).begins_with("Plans : ") and String(t).contains(String(pool[0].name))))
	Run.active = false
	Profile.in_run = false
