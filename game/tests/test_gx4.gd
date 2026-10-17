extends Node
## Lot GX-4 (Atelier et Héros, reste du backlog BM-GEAR) : « Tout monter à +5 » à la Forge (règles, arrêt faute de
## ressources, confirmation, séance animée et « Arrêter ») ; gemmes lisibles (valeur sur la pièce, retirer gratuit,
## remplacer sans détruire, tout fusionner) ; 5 préréglages (vieille sauvegarde complétée), noms d'usage, comparaison,
## tenue liée ; recherche (Forge, Fabriquer), pièces portées d'abord ; aperçu de la panoplie ; X dessiné à la manette.
## godot --headless --path game res://tests/test_gx4.tscn

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
	_test_even_rules()
	_test_even_stops()
	await _test_even_ui()
	_test_gems()
	_test_presets()
	await _test_preset_bar()
	await _test_lists()
	_test_compass()
	Training.active = true
	Profile.reset_all()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _piece(level: int, up: int, slot: String) -> Dictionary:
	var it := Items.generate(level, 0.0, slot, "warrior", Items.MYTHIC, "", Items.MYTHIC)
	it["upgrade"] = up
	it["level"] = level  # niveau exact (le modèle d'Eden peut décaler le niveau tiré : parchemins et chances lisibles)
	it["plevel"] = level
	return it


## Un héros neuf avec 9 pièces portées de niveau [param level] à +[param up] (et un trophée), des parchemins et des cristaux.
func _kit(level: int, up: int, crystals: int, scrolls := 200) -> Dictionary:
	Profile.reset_all()
	Profile.in_run = false
	Profile.selected_class = "warrior"
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(90) + 1.0
	var gear := {}
	for s in Items.SLOTS:
		gear[s] = _piece(level, up, s)
	Profile.install_gear(gear)
	Profile.stash = {}
	for s in gear:
		Profile.stash[Craft.fortify_key(Craft.fortify_kind(gear[s]), Craft.fortify_level_for(gear[s]))] = scrolls
	Profile.bag = Profile.stash
	Profile.materials["crystal"] = crystals
	return gear


func _ups() -> Array:
	return Items.SLOTS.map(func(s): return int(Profile.equipped[s].get("upgrade", 0)))


# --- règles ---------------------------------------------------------------------------------------------------------
func _test_even_rules() -> void:
	_kit(85, 2, 100000)
	var tro := {"uid": "gx4_trophy", "slot": "trophy", "level": 85, "rarity": 3, "upgrade": 0, "name": "Trophée", "affixes": {}}
	Profile.equipped["trophy"] = tro
	Profile.equipped["chest"]["upgrade"] = 6
	var todo := Forge.even_pieces(5)
	check("tout monter : les 8 pièces sous +5 (ni trophée, ni pièce déjà au-dessus)", todo.size() == 8 and not todo.has(tro))
	var plan := Forge.plan_even(5)
	var sum := 0
	for p in plan.pieces:
		sum += int(Craft.plan_upgrade(p.item, 5).cost.crystal)
	check("plan : coût attendu = somme des pièces (%d), au pire ≥ attendu (%d)" % [int(plan.cost.crystal), int(plan.cost_max.crystal)], int(plan.cost.crystal) == sum and int(plan.cost_max.crystal) >= int(plan.cost.crystal))
	check("plan : 24 crans, parchemins de garde et de puissance comptés", int(plan.steps) == 24 and (plan.scrolls as Dictionary).has("guard") and (plan.scrolls as Dictionary).has("power") and int(plan.scrolls.guard[2]) == 200)
	var before := Profile.amount("crystal")
	var r := Forge.even_all(5)
	var ups := _ups()
	check("tout monter : chaque pièce à +5 au moins, le torse reste à +6 (%s)" % str(ups), r.done and ups.all(func(u): return u >= 5) and int(Profile.equipped.chest.upgrade) == 6)
	check("tout monter : jamais au-delà de la cible", ups.filter(func(u): return u > 5).size() == 1)
	var spent := before - Profile.amount("crystal")
	check("tout monter : dépensé %d cristaux, entre « si tout réussit » et « au pire »" % spent, spent <= int(plan.cost_max.crystal) and spent >= Forge.upgrade_crystals(Items.power_level(Profile.equipped.head), 2, 5) * 8 * 0.9)
	check("tout monter : %d essais (%d ratés), au plus le pire prévu (%d)" % [int(r.tries), int(r.fails), int(plan.tries_max)], int(r.tries) <= int(plan.tries_max) and int(r.tries) >= 24)
	check("tout monter : la persévérance est vidée à chaque réussite", Items.SLOTS.all(func(s): return not Profile.equipped[s].has("pity")))
	check("tout monter : stats bonus de +4 notées (%d)" % (r.bonus as Array).size(), (r.bonus as Array).size() == 8)
	# pierres de chance : la plus petite d'abord, une par essai incertain
	_kit(85, 3, 100000)
	Profile.stash[Craft.stone_key("safety")] = 3
	Profile.stash[Craft.stone_key("lucky")] = 5
	check("pierre : la plus petite d'abord", Forge.smallest_stone(Profile.equipped.head) == Craft.stone_key("safety"))
	Forge.even_all(5, true)
	check("pierres : consommées les plus petites d'abord (%d petites, %d grandes restantes)" % [Profile.bag_count(Craft.stone_key("safety")), Profile.bag_count(Craft.stone_key("lucky"))],
		Profile.bag_count(Craft.stone_key("safety")) == 0 and Profile.bag_count(Craft.stone_key("lucky")) < 5)
	_kit(85, 3, 100000)
	Profile.stash[Craft.stone_key("safety")] = 3
	Forge.even_all(5, false)
	check("sans l'option, aucune pierre n'est prise", Profile.bag_count(Craft.stone_key("safety")) == 3)


func _test_even_stops() -> void:
	# cristaux qui manquent : arrêt propre, rien de perdu, ce qui est monté le reste
	_kit(85, 0, 300)
	var r := Forge.even_all(5)
	var ups := _ups()
	check("faute de cristaux : arrêt (%s), aucune pièce au-dessous de +0, cristaux jamais négatifs (%d)" % [String(r.stop), Profile.amount("crystal")],
		not r.done and String(r.stop) == "crystal" and ups.all(func(u): return u >= 0) and Profile.amount("crystal") >= 0)
	check("faute de cristaux : le reste ne paie plus aucun essai", Profile.amount("crystal") < int(Forge.price(int(Items.upgrade_cost(Forge.even_pieces(5)[0]).gold)).crystal))
	check("la moins montée d'abord : les pièces restent à un cran d'écart au plus (%s)" % str(ups), ups.max() - ups.min() <= 1)
	# parchemins de garde absents : les armures attendent, l'arme monte quand même
	_kit(40, 0, 100000)
	for k in Profile.stash.keys():
		if String(k).begins_with("fortify:guard"):
			Profile.stash.erase(k)
	r = Forge.even_all(5)
	check("sans parchemin de garde : l'arme monte à +5, les armures attendent (arrêt « %s »)" % String(r.stop),
		int(Profile.equipped.weapon.upgrade) == 5 and int(Profile.equipped.head.upgrade) == 0 and String(r.stop) == "scroll")


# --- interface de la Forge -------------------------------------------------------------------------------------------
func _ask_layer() -> InfoCard.Ask:
	for c in get_tree().root.find_children("*", "", true, false):
		if c is InfoCard.Ask and not c.is_queued_for_deletion():
			return c
	return null


func _test_even_ui() -> void:
	ForgeBench.fast = true
	_kit(40, 1, 100000)
	var fb := ForgeBench.new()
	add_child(fb)
	await get_tree().process_frame
	fb.refresh()
	await get_tree().process_frame
	var btn := _button_with(fb, "Tout monter à +5")
	check("forge : « Tout monter à +5 · 9 pièces » au-dessus de la grille", btn != null and btn.text.contains("9 pièces") and not btn.disabled)
	var shown: Array = fb.grid.shown()
	check("forge : les pièces portées d'abord dans la grille", shown.size() >= 9 and shown.slice(0, 9).all(func(it): return fb._worn(it)))
	check("forge : pas de ▲ / ▼ sur les cases (le +N reste lisible)", not fb.grid.compare)
	if btn:
		btn.pressed.emit()
	await get_tree().process_frame
	var ask := _ask_layer()
	var at := _texts(ask) if ask else ""
	check("confirmation : coût attendu, au pire, ce qu'on a, parchemins, arrêt possible", ask != null and at.contains("attendu") and at.contains("au pire") and at.contains("tu en as") and at.contains("Parchemins") and at.contains("arrêter"))
	check("confirmation : les 9 pièces en cases avec « +1 → +5 »", ask != null and at.count("+1 → +5") == 9)
	if ask:
		ask.ok_button.pressed.emit()
	for _i in 400:
		await get_tree().process_frame
		if not fb._busy:
			break
	check("séance : tout l'équipement à +5 (%s)" % str(_ups()), _ups().all(func(u): return u == 5))
	check("séance : le bandeau dit « Tout l'équipement à +5 » et les essais", fb._bar.visible and fb._bar._msg.text.contains("Tout l'équipement à +5") and fb._bar._msg.text.contains("essai"))
	check("séance finie : le bouton dit « Tout est à +5 ✓ »", _button_with(fb, "Tout est à +5") != null)
	# viser +7 puis arrêter au premier essai
	var plus: Button = fb._even_plus
	plus.pressed.emit()
	plus.pressed.emit()
	await get_tree().process_frame
	btn = _button_with(fb, "Tout monter à +7")
	check("› : la cible devient +7", btn != null)
	if btn:
		btn.pressed.emit()
	await get_tree().process_frame
	ask = _ask_layer()
	if ask:
		ask.ok_button.pressed.emit()
	await get_tree().process_frame
	var stop := _button_with(fb, "Arrêter")
	check("séance : « Arrêter » remplace l'action principale", stop != null and fb._busy)
	var tab: Button = fb._tab_buttons.get("enchant")
	if tab:
		tab.pressed.emit()
	check("séance : les établis ne changent pas pendant la séance", fb.bench == "upgrade")
	fb.grid.select_item(Profile.equipped.head)
	check("séance : choisir une pièce ne fait pas disparaître « Arrêter »", _button_with(fb, "Arrêter") != null)
	if stop:
		stop.pressed.emit()
	for _i in 200:
		await get_tree().process_frame
		if not fb._busy:
			break
	var ups := _ups()
	check("arrêter : la séance s'arrête après l'essai en cours (%s)" % str(ups), not fb._busy and ups.filter(func(u): return u > 5).size() <= 1 and fb._bar._msg.text.begins_with("Arrêté"))
	check("arrêter : l'action principale revient", _button_with(fb, "Arrêter") == null)
	fb.queue_free()
	await get_tree().process_frame
	ForgeBench.fast = false


# --- gemmes --------------------------------------------------------------------------------------------------------
func _test_gems() -> void:
	Profile.reset_all()
	Profile.in_run = false
	var it := _piece(40, 0, "chest")
	it["sockets"] = [null, null]
	Profile.bag = {Craft.gem_key("ruby", 1): 1, Craft.gem_key("garnet", 0): 1}
	check("gemme : valeur écrite (« Force »)", Craft.gem_value_text(Craft.gem_key("ruby", 1)).contains("Force"))
	Craft.insert_gem(it, Craft.gem_key("ruby", 1), 0)
	var msg := Craft.insert_gem(it, Craft.gem_key("garnet", 0), 0)
	check("sertir sur une gemme : l'ancienne revient au sac (%s)" % msg, Profile.bag_count(Craft.gem_key("ruby", 1)) == 1 and String(it.sockets[0].type) == "garnet" and msg.contains("revient"))
	msg = Craft.remove_gem(it, 0)
	check("retirer : gratuit, la gemme revient, l'emplacement reste percé", Profile.bag_count(Craft.gem_key("garnet", 0)) == 1 and it.sockets.size() == 2 and it.sockets[0] == null)
	check("retirer un emplacement vide : refusé", Craft.remove_gem(it, 1).begins_with("Aucune"))
	Profile.bag = {Craft.gem_key("ruby", 0): 9}
	Profile.materials["crystal"] = 100
	var plan := Forge.fuse_all_plan()
	var r := Forge.fuse_all()
	check("tout fusionner : 9 bruts → 3 taillés → 1 pur (%s)" % String(r.text), int(r.count) == 4 and Profile.bag_count(Craft.gem_key("ruby", 2)) == 1 and Profile.bag_count(Craft.gem_key("ruby", 0)) == 0 and int(plan.count) == 3)
	check("tout fusionner : le texte ne compte que ce qu'on a de plus", String(r.text).contains("Rubis pur ×1") and not String(r.text).contains("taillé"))
	check("tout fusionner : rien à faire", int(Forge.fuse_all().count) == 0)


# --- préréglages ---------------------------------------------------------------------------------------------------
func _test_presets() -> void:
	_kit(30, 0, 0)
	check("5 préréglages par classe", Profile.preset_names("warrior").size() == 5)
	# vieille sauvegarde à 3 préréglages : complétée, rien de perdu
	Profile.presets["mage_test"] = {"active": 2, "sets": [{"name": "A", "slots": {}}, {"name": "B", "slots": {"head": "x"}}, {"name": "Boss", "slots": {}}]}
	var names := Profile.preset_names("mage_test")
	check("vieille sauvegarde : 3 → 5, noms et préréglage actif gardés (%s)" % str(names), names.size() == 5 and names[2] == "Boss" and Profile.active_preset("mage_test") == 2 and Profile.presets.mage_test.sets[1].slots.head == "x")
	Profile.presets.erase("mage_test")
	check("nom d'origine reconnu (la barre n'en montre que le numéro)", Profile.preset_default_name("Préréglage 4") and not Profile.preset_default_name("Boss") and not Profile.preset_default_name("Préréglage du soir"))
	# comparaison : préréglage 2 = le même équipement sauf le casque
	Profile.copy_active_preset("warrior", 1)
	var helm := _piece(60, 4, "head")
	Profile.add_item(helm)
	Profile.presets.warrior.sets[1].slots["head"] = helm.uid
	var cmp := EquipmentPage.PresetBar.compare_plan("warrior", 1)
	check("comparer : un emplacement change (le casque), 8 pièces en commun", (cmp.rows as Array).size() == 1 and String(cmp.rows[0].slot) == "head" and int(cmp.same) == 8)
	check("comparer : la PE de l'autre est plus haute", int(cmp.pe_b) > int(cmp.pe_a))
	check("équipement d'un autre préréglage relu", String(Profile.preset_gear("warrior", 1).head.uid) == helm.uid)
	# tenue liée au préréglage
	Profile.outfits["warrior"] = "res://tenue_a.glb"
	Profile.bind_preset_look("warrior", true)
	check("tenue liée au préréglage actif", Profile.preset_has_look("warrior") and not Profile.preset_has_look("warrior", 1))
	Profile.set_active_preset("warrior", 1)
	check("préréglage sans tenue liée : l'apparence ne change pas", Profile.outfit_of("warrior") == "res://tenue_a.glb")
	Profile.outfits["warrior"] = "res://tenue_b.glb"
	Profile.set_active_preset("warrior", 0)
	check("retour au préréglage lié : sa tenue revient", Profile.outfit_of("warrior") == "res://tenue_a.glb")
	Training.active = false  # l'entraînement n'écrit rien
	Profile.save_profile()
	Profile.load_profile()
	Training.active = true
	check("tenue liée relue du disque", Profile.preset_has_look("warrior", 0))
	Profile.bind_preset_look("warrior", false)
	check("délier : la clé disparaît", not Profile.preset_has_look("warrior"))


func _test_preset_bar() -> void:
	_kit(30, 0, 0)
	Profile.rename_preset("warrior", 2, "Donjons")
	var bar := EquipmentPage.PresetBar.new()
	add_child(bar)
	bar.refresh("warrior")
	await get_tree().process_frame
	var chips := _buttons(bar)
	check("barre : 5 préréglages + « Gérer »", bar.get_child_count() == 6)
	check("barre : l'actif garde son nom, les autres d'origine ne montrent que leur numéro, un nom choisi s'affiche",
		chips.size() >= 5 and (chips[0] as Button).text == "Préréglage 1" and (chips[1] as Button).text == "2" and (chips[2] as Button).text == "Donjons")
	bar._open_menu()
	await get_tree().process_frame
	var t := _texts(bar._pop)
	check("Gérer : copier ici et comparer pour chaque autre préréglage", t.count("Copier ici") == 4 and t.count("Comparer") >= 4)
	check("Gérer : noms d'usage en un clic", t.contains("Survie") and t.contains("Duel") and t.contains("Essai"))
	check("Gérer : lier la tenue (aucune stat)", t.contains("Lier ma tenue") and t.contains("aucune stat"))
	var survie: Button = null
	for b in _buttons(bar._pop):
		if (b as Button).text == "Survie":
			survie = b
	if survie:
		survie.pressed.emit()
	check("nom d'usage : le préréglage actif devient « Survie »", Profile.preset_names("warrior")[0] == "Survie")
	bar.queue_free()
	await get_tree().process_frame


# --- listes, recherche, panoplie, manette --------------------------------------------------------------------------
func _test_lists() -> void:
	check("recherche : sans accents ni casse", ItemWidgets.ItemGrid.name_matches({"name": "Épée du Lotus", "slot": "weapon"}, "epee") and ItemWidgets.ItemGrid.name_matches({"name": "Bottes", "slot": "boots"}, "BOT"))
	check("recherche : par emplacement aussi", ItemWidgets.ItemGrid.name_matches({"name": "Peau du Tigre", "slot": "chest"}, "torse"))
	check("recherche : rien ne correspond", not ItemWidgets.ItemGrid.name_matches({"name": "Bottes", "slot": "boots"}, "anneau"))
	var g := ItemWidgets.ItemGrid.new(false, 6, 48.0)
	add_child(g)
	var s := g.enable_search("Chercher")
	g.set_items([{"uid": "a", "name": "Casque rouge", "slot": "head", "level": 1, "rarity": 0}, {"uid": "b", "name": "Bottes", "slot": "boots", "level": 1, "rarity": 0}])
	s.text = "casque"
	s.text_changed.emit("casque")
	check("grille : la recherche filtre (%d)" % g.shown().size(), g.shown().size() == 1 and String(g.shown()[0].uid) == "a")
	g.queue_free()
	# manette : X dessiné quand le contrôle visé (ou un parent) dit ce qu'il fait
	var box := Control.new()
	box.set_meta("pad_x", "Équiper")
	var child := Button.new()
	box.add_child(child)
	add_child(box)
	var was: Control = UiNav.cursor
	var was_shown := UiNav.shown
	UiNav.cursor = child
	UiNav.shown = true
	check("manette : X « Équiper » lu sur un parent", UiNav.x_hint() == "Équiper")
	UiNav.cursor = was
	UiNav.shown = was_shown
	box.queue_free()
	# Fabriquer : recherche dans les plans découverts
	Profile.reset_all()
	var shop := GearShopPage.new()
	add_child(shop)
	await get_tree().process_frame
	check("Fabriquer : un champ de recherche", shop._f_search != null)
	shop.queue_free()
	await get_tree().process_frame


func _test_compass() -> void:
	_kit(40, 1, 100000)
	Settings.set_v("interface", "dev_mode", true)  # Forge ouverte
	var step := Compass._forge_step("warrior", {"plus10": 0})
	Settings.set_v("interface", "dev_mode", false)
	check("boussole : la Forge conseille « Tout monter à +5 » (%s)" % String(step.get("tip", "")), String(step.get("tip", "")).contains("Tout monter à +5"))
