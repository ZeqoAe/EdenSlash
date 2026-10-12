extends Node
## Écrans plein écran : préréglages d'équipement par classe et coffre commun,
## menu pause (Run, Personnage), village (marchand, forgeron, recycleur, joaillier).
## godot --headless --path game res://tests/test_pages.tscn  (profil de test uniquement)

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Profile.reset_all()
	_test_presets()
	await _test_run_screens()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _uid(slot: String) -> String:
	return String(Profile.equipped.get(slot, {}).get("uid", ""))


func _test_presets() -> void:
	Profile.selected_class = "samurai"
	Profile.save_profile()
	check("arme de départ du samouraï", _uid("weapon") != "")
	var helm := Items.generate(5, 0.5, "head")
	Profile.inventory.append(helm)
	Profile.equip(helm)
	check("casque équipé (samouraï, préréglage 1)", _uid("head") == helm.uid)
	# autre classe : autre équipement, même coffre
	Profile.selected_class = "warrior"
	Profile.save_profile()
	check("guerrier : sans le casque du samouraï", _uid("head") == "")
	check("guerrier : sa propre arme (hache)", Items.weapon_type_of(Profile.equipped.get("weapon", {})) == "axe")
	check("coffre commun : le casque est disponible", Profile.inventory.any(func(it): return it.uid == helm.uid))
	Profile.equip(Profile.inventory.filter(func(it): return it.uid == helm.uid)[0])
	check("le guerrier peut aussi porter le casque", _uid("head") == helm.uid)
	check("objet partagé : utilisé par 2 classes", Profile.item_users(helm.uid).size() == 2)
	# préréglages
	Profile.set_active_preset("warrior", 1)
	check("préréglage 2 du guerrier : vide sauf l'arme", _uid("head") == "" and _uid("weapon") != "")
	Profile.set_active_preset("warrior", 0)
	check("retour au préréglage 1", _uid("head") == helm.uid)
	Profile.copy_active_preset("warrior", 2)
	Profile.rename_preset("warrior", 2, "Boss")
	check("copie et renommage", Profile.preset_names("warrior")[2] == "Boss" and Profile.presets.warrior.sets[2].slots.get("head", "") == helm.uid)
	Profile.selected_class = "samurai"
	Profile.save_profile()
	check("retour au samouraï : son équipement", _uid("head") == helm.uid and Items.weapon_type_of(Profile.equipped.weapon) == "katana")
	# choisir une arme juste après avoir changé de classe (lobby) : va dans la nouvelle classe
	Profile.selected_class = "magician"
	Profile.select_weapon_type("bow")
	check("magicien à l'arc, le samouraï garde son katana", Items.weapon_type_of(Profile.equipped.weapon) == "bow"
		and String(Profile.presets.samurai.sets[0].slots.weapon) != String(Profile.equipped.weapon.uid))
	Profile.selected_class = "samurai"
	Profile.save_profile()
	# sauvegarde et rechargement
	Profile.load_profile()
	check("préréglages relus du disque", Profile.preset_names("warrior")[2] == "Boss" and _uid("head") == helm.uid)


func _test_run_screens() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.cards._queue.clear()
	world.cards._show_next()
	var player: Player = world.player
	for i in 8:
		Profile.add_item(Items.generate(5, 1.0 if i < 3 else -0.5))
	Profile.gain({"gold": 5000, "fragment": 300, "essence": 60, "crystal": 6})
	for k in ["drill", "drill", "luck", "protect", Craft.gem_key("ruby", 0), Craft.gem_key("ruby", 0), Craft.gem_key("ruby", 0), Craft.scroll_key("violence", 1)]:
		Profile.add_bag(k)
	# menu pause
	world.pause_menu.open()
	await _frames()
	check("pause : plein écran ouvert, jeu en pause", world.pause_menu.is_open() and get_tree().paused)
	var screen: PageScreen = world.pause_menu._screen
	screen.show_page(1)
	await _frames()
	var eq: EquipmentPage = screen.page(1)
	check("page Personnage : sac de la run affiché", eq._grid.shown().size() == Profile.inventory.size())
	var it: Dictionary = Profile.inventory.filter(func(x): return x.slot != "weapon")[0]
	eq._equip(it)
	check("équiper depuis la page", is_same(Profile.equipped.get(it.slot), it))
	eq._unequip(it.slot)
	check("retirer depuis la page", not Profile.equipped.has(it.slot) or not is_same(Profile.equipped.get(it.slot), it))
	world.pause_menu.close()
	await _frames()
	check("pause fermée, jeu repris", not world.pause_menu.is_open() and not get_tree().paused)
	# village
	var v: VillageUI = world.village_ui
	for kind in ["merchant", "smith", "recycler", "jeweler", "trader"]:
		v.open(kind)
		await _frames()
		check("village : %s ouvert" % kind, v.is_open())
		v.close_ui()
		await _frames()
	# marchand : vendre
	v.open("merchant")
	var ms: PageScreen = v._screens.merchant
	ms.show_page(1)
	await _frames()
	var sell: VillagePages.SellPage = ms.page(1)
	sell.grid.select_up_to_rarity(1)
	var n_before := Profile.inventory.size()
	var gold_before := Profile.gold
	var picked := sell.grid.selection().size()
	Profile.sell_many(sell.grid.selection().duplicate())
	check("vendre : %d objet(s), or reçu" % picked, picked > 0 and Profile.inventory.size() == n_before - picked and Profile.gold > gold_before)
	# marchand : acheter
	ms.show_page(0)
	await _frames()
	var offer: Dictionary = v.offers.filter(func(o): return o.has("bag"))[0]
	v.buy(offer)
	check("acheter une fourniture", offer.get("sold", false))
	v.close_ui()
	# forgeron : améliorer, réforger, polir
	var piece: Dictionary = Profile.equipped.weapon
	var up0 := int(piece.get("upgrade", 0))
	Profile.upgrade_item(piece)
	check("améliorer (+1 sûr)", int(piece.upgrade) == up0 + 1)
	var rare: Dictionary = Profile.inventory.filter(func(x): return not Forge.reforgeable(x).is_empty())[0]
	var stat: String = Forge.reforgeable(rare)[0]
	var ess := int(Profile.materials.essence)
	var txt := Forge.reforge(rare, stat)
	check("réforger une stat (%s)" % txt, int(Profile.materials.essence) < ess and txt.contains("→"))
	var q0 := float(rare.get("quality", 1.0))
	Forge.polish(rare)
	check("polir : la qualité ne baisse jamais", float(rare.quality) >= q0)
	# recycleur : désassembler et convertir
	var frag := int(Profile.materials.fragment)
	Profile.disassemble_many([Profile.inventory[0]])
	check("recycler un objet", int(Profile.materials.fragment) > frag)
	var e0 := int(Profile.materials.essence)
	Forge.convert(0, 1)
	check("convertir 10 fragments → 1 essence", int(Profile.materials.essence) == e0 + 1)
	# joaillier : percer, sertir, fusionner
	var jewel: Dictionary = Profile.inventory[0]
	Craft.drill(jewel)
	check("percer un emplacement", jewel.get("sockets", []).size() == 1)
	Forge.fuse("ruby", 0)
	check("fusion : 3 rubis bruts → 1 rubis taillé", Profile.bag_count(Craft.gem_key("ruby", 1)) == 1 and Profile.bag_count(Craft.gem_key("ruby", 0)) == 0)
	Craft.insert_gem(jewel, Craft.gem_key("ruby", 1), 0)
	check("sertir la gemme fusionnée", jewel.sockets[0] != null)
	# pages : rafraîchissement sans erreur
	for kind in ["smith", "recycler", "jeweler"]:
		v.open(kind)
		var s: PageScreen = v._screens[kind]
		for i in s._pages.size():
			s.show_page(i)
			await _frames(1)
		v.close_ui()
	check("toutes les pages du village s'affichent", true)
	world.queue_free()
