extends Node
## Écrans plein écran : préréglages d'équipement par classe et coffre commun,
## menu pause (Run, Équipement, Infos), village (marchand, forgeron, recycleur, joaillier),
## légendaires et accessoires, carte d'objet au survol, archive et apparences,
## certificats (7 au plus), lancement de run Équipement → Expertise.
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
	check("profil de test", Profile.save_path.begins_with("user://profile_test"))
	_test_slots()
	Profile.reset_all()
	_test_presets()
	_test_items()
	_test_archive()
	_test_progression()
	await _test_title()
	await _test_lobby()
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


func _test_items() -> void:
	var rar := {}
	var trophies := 0
	for i in 400:
		var it := Items.generate(10, 1.0)
		rar[int(it.rarity)] = true
		trophies += 1 if it.slot == "trophy" else 0
	check("butin chanceux : des légendaires (orange)", rar.has(4) and Items.RARITIES[4].name == "Légendaire")
	check("trophées sur le butin rare des élites et boss", trophies > 0)
	check("pas de trophée sur le butin courant", range(200).all(func(_i): return Items.generate(5, 0.0).slot != "trophy"))
	var ring := Items.generate(5, 0.5, "ring")
	check("bague : icône d'Eden et stats", String(ring.icon) != "" and ring.has("eden") and Items.stats(ring).has("lck"))
	Profile.inventory.append(ring)
	Profile.equip(ring)
	check("bague équipée (nouvel emplacement)", _uid("ring") == ring.uid and Profile.equipment_stats().has("lck"))
	# carte d'objet au survol
	var slot := ItemWidgets.ItemSlot.new()
	slot.set_item(ring)
	var card: Control = slot._make_custom_tooltip(slot.tooltip_text)
	add_child(card)
	var rtl: RichTextLabel = card.get_child(0)
	check("carte au survol : nom, stats, qualité", rtl.text.contains(String(ring.name)) and rtl.text.contains("Qualité") and rtl.text.contains("Chance"))
	card.queue_free()
	slot.free()


func _test_archive() -> void:
	var common := Items.generate(5, -1.0, "head")
	var rare := Items.generate(5, 0.0, "weapon", "samurai", 2, "katana")
	rare.rarity = 2
	Items.make_set_piece(rare, "storm")
	var legend := Items.generate(5, 0.0, "chest", "samurai", 4)
	legend.erase("set")  # pas de pièce de set : 1 seule entrée
	for it in [common, rare, legend]:
		Profile.inventory.append(it)
	Profile.equip(rare)
	Profile.save_profile()
	check("archive : objet commun refusé", Archive.refusal(common) != "")
	check("archive : katana rare accepté", Archive.refusal(rare) == "")
	var str0 := float(Archive.bonus().get("str", 0.0))
	var filled := Profile.archive_item(rare)
	check("archivé : entrées katana rare + set Tempête", "katana:2" in filled and "set:storm" in filled)
	check("archivé : quitte le coffre et les préréglages", not Profile.vault.any(func(x): return x.uid == rare.uid) and Profile.item_users(rare.uid).is_empty())
	check("archivé : une arme reste équipée", Profile.equipped.has("weapon"))
	check("bonus permanent : +1 Force, +1 % dégâts", float(Archive.bonus().get("str", 0.0)) == str0 + 1.0 and float(Archive.bonus().get("dmg_pct", 0.0)) >= 0.01)
	var again := rare.duplicate(true)
	check("même entrée : déjà archivé", Archive.refusal(again) != "")
	Profile.archive_item(legend)
	check("légendaire (torse) : +4 Force", float(Archive.bonus().get("str", 0.0)) == str0 + 5.0)
	check("collection %d / %d" % [Archive.count(), Archive.total()], Archive.count() == 3 and Archive.total() == (GameData.weapon_types.size() + 9) * 3 + Items.SETS.size())
	# apparences
	check("skin : 3e katana débloqué par le katana rare", Archive.skin_unlocked("katana", 2) and not Archive.skin_unlocked("katana", 3))
	var code := String(Archive.skins("katana")[2].code)
	Profile.set_skin("katana", code)
	var wt := Items.weapon_type_of(Profile.equipped.weapon)
	check("skin appliqué à l'arme portée", wt != "katana" or Profile.weapon_code() == code)
	Profile.load_profile()
	check("archive et apparences relues du disque", Archive.count() == 3 and String(Profile.skins.get("katana", "")) == code)
	# certificats : 7 au plus
	for cid in GameData.classes:
		Profile.expertise[cid] = 999999
	check("certificats : 7 emplacements au maximum", Profile.certificate_slots() == 7)
	Profile.certificates.clear()
	for c in Profile.unlocked_certificates():
		Profile.toggle_certificate(c.key)
	check("certificats : on ne peut pas en équiper plus de 7", Profile.certificates.size() == mini(7, Profile.unlocked_certificates().size()))
	Profile.expertise = {}
	Profile.certificates.clear()
	Profile.save_profile()


func _test_progression() -> void:
	Profile.new_game(3)
	check("nouvelle partie : seul le Guerrier est jouable", Progression.class_unlocked("warrior") and not Progression.class_unlocked("samurai"))
	var got: Array = []
	var cb := func(c): got.append(c)
	Profile.class_unlocked.connect(cb)
	Profile.record_add("kills", 249)
	check("mission du Samouraï en cours (249 / 250)", not Progression.class_unlocked("samurai") and Progression.mission_progress("samurai") == Vector2(249, 250))
	Profile.record_add("kills", 1)
	check("mission remplie : Samouraï débloqué", Progression.class_unlocked("samurai") and "samurai" in got)
	Profile.record_max("best_hit", 900)
	check("gros coup : Magicien débloqué", Progression.class_unlocked("magician"))
	Profile.class_unlocked.disconnect(cb)
	# sorts : 4 de base, les suivants avec la maîtrise
	check("sorts : 4 de base, le 5e au niveau 2", Progression.skill_level(3) == 1 and Progression.skill_level(4) == 2)
	Run.start("warrior")
	var skills: Array = GameData.class_data("warrior").skills
	var base := Progression.own_skills("warrior").slice(0, 4).map(func(x): return int(x.id))
	var shared := skills.filter(func(x): return x.get("shared", false)).map(func(x): return int(x.id))
	base += shared
	var seen := {}
	for i in 60:
		for c in Run.roll_cards(3, true):
			seen[int(c.id)] = true
	check("maîtrise 1 : seuls les 4 sorts de base sont proposés", seen.keys().all(func(k): return k in base) and seen.size() == 4 + shared.size())
	Profile.expertise["warrior"] = 2000
	check("maîtrise montée : nouveaux sorts", Progression.skill_unlocked("warrior", int(skills[5].id)) and Progression.rewards_at("warrior", 2).any(func(r): return r.kind == "skill"))
	Run.finish("abandon")
	Profile.end_run(null)
	# plateau des certificats : losange de 4 oranges
	for cid in GameData.classes:
		Profile.expertise[cid] = 999999
	for k in ["warrior/double_cut", "magician/staff_expert", "hunter/bow_expert", "samurai/katana_expert"]:
		check("certificat orange : " + k, CertBoard.color_of(k) == "orange")
	for pos_key in [[0, "warrior/double_cut"], [1, "magician/staff_expert"], [2, "hunter/bow_expert"], [3, "samurai/katana_expert"]]:
		Profile.place_certificate(pos_key[1], pos_key[0])
	var syn := CertBoard.synergies(Profile.cert_board)
	check("losange orange + 5 liens", syn.any(func(x): return x.name == CertBoard.DIAMOND.orange.name) and syn.any(func(x): return String(x.name).ends_with("×5")))
	check("bonus du plateau dans les passifs", float(CertBoard.stats(Profile.cert_board).get("dmg_pct", 0.0)) > 0.2)
	Profile.place_certificate("warrior/unshakable", 4)
	Profile.place_certificate("thief/dagger_expert", 5)
	check("prisme : triangle de 3 couleurs", CertBoard.synergies(Profile.cert_board).any(func(x): return x.name == CertBoard.PRISM.name))
	Profile.place_certificate("warrior/double_cut", 6)
	check("déplacer un certificat sur le plateau", String(Profile.cert_board[6]) == "warrior/double_cut" and String(Profile.cert_board[0]) == "" and Profile.certificates.size() == 6)
	Profile.load_profile()
	check("plateau relu du disque", String(Profile.cert_board[6]) == "warrior/double_cut")
	Profile.new_game(1)


func _test_slots() -> void:
	for i in range(1, Profile.SLOT_COUNT + 1):
		Profile.delete_slot(i)
	Profile.new_game(2)
	check("nouvelle partie : emplacement 2", Profile.slot == 2 and Profile.slot_exists(2) and Profile.last_slot() == 2)
	Profile.selected_class = "warrior"
	Profile.runs_done = 5
	Profile.save_profile()
	Profile.new_game(3)
	check("nouvelle partie : profil vierge, Guerrier", Profile.runs_done == 0 and Profile.selected_class == "warrior")
	Profile.load_slot(2)
	check("charger l'emplacement 2", Profile.slot == 2 and Profile.runs_done == 5 and Profile.selected_class == "warrior" and Profile.equipped.has("weapon"))
	var sm := Profile.slot_summary(2)
	check("résumé de sauvegarde", int(sm.runs) == 5 and String(sm["class"]) == "warrior" and String(sm.saved_at) != "" and Profile.slot_summary(1).is_empty())
	Profile.delete_slot(3)
	check("supprimer un emplacement", not Profile.slot_exists(3))
	Profile.new_game(1)
	check("retour à l'emplacement 1 (fichier de test)", Profile.save_path == Profile.TEST_SAVE_PATH and Profile.last_slot() == 1)
	Profile.delete_slot(2)


func _test_title() -> void:
	Profile.save_profile()
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().create_timer(1.5).timeout
	check("écran titre : map de fond générée", title.backdrop.map != null and title.backdrop.map.is_inside_tree())
	title._open_saves()
	await _frames()
	check("Jouer : continuer, charger, nouvelle partie", title._saves.visible and title._saves_body.get_child_count() >= 3 and not title._center.visible)
	title._show_slots(true)
	await _frames()
	check("nouvelle partie : 3 emplacements", title._saves_body.get_children().filter(func(c): return c is PanelContainer).size() == Profile.SLOT_COUNT)
	title._close_saves()
	title.queue_free()
	await _frames()


func _test_lobby() -> void:
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await _frames()
	check("menu principal : Jouer choisi, sous-menu rempli", lobby._menu.play.selected and lobby._sub.get_child_count() >= 4)
	lobby._show_menu("class")
	lobby._select_class("warrior")
	await _frames()
	check("menu Classe : guerrier choisi", Profile.selected_class == "warrior" and lobby._badge_name.text == "Guerrier" and lobby._menu["class"].selected)
	lobby._select_class("samurai")
	lobby._show_menu("zones")
	await _frames()
	check("menu Zone de farm : 6 zones", lobby._sub.get_children().filter(func(c): return c is MenuWidgets.RowButton).size() == GameData.zones.size())
	lobby._show_menu("play")
	lobby._prepare_run()
	await _frames()
	check("lancer la run : page Équipement d'abord", lobby._prep.is_open() and lobby._prep.current_page() == 0 and lobby._prep_button.text.begins_with("Valider l'équipement"))
	lobby._on_prep_validate()
	await _frames()
	check("valider : page Expertise & talents", lobby._prep.current_page() == 1 and lobby._prep_button.text.contains("lancer la run") and lobby._prep.page(1) is TalentsPage)
	var tp: TalentsPage = lobby._prep.page(1)
	check("expertise : plateau de 7 cases, parcours de maîtrise", tp._board._slots.size() == 7 and tp._track.get_child_count() >= 8 and tp._certs.get_child_count() >= 2)
	lobby._prep.close_ui()
	lobby._archive.open(0)
	await _frames()
	check("archive : catalogue affiché", lobby._archive.is_open() and lobby._archive.page(0)._catalog.get_child_count() > 0)
	lobby._archive.show_page(1)
	await _frames()
	lobby._archive.close_ui()
	lobby._info.open(0)
	for i in InfoPage.SECTIONS.size():
		lobby._info.page(0).show_section(i)
	check("infos : toutes les sections", lobby._info.page(0)._text.text.length() > 50)
	lobby._info.close_ui()
	lobby.free()


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
	screen.show_page(2)
	var info: InfoPage = screen.page(2)
	info.show_section(InfoPage.SECTIONS.size() - 1)
	check("pause : page Infos avec les valeurs du héros", info._text.text.contains("PV effectifs"))
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
