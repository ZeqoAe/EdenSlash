extends Node
## Écrans plein écran : préréglages d'équipement par classe et coffre commun,
## menu pause (Run, Héros, Aide), village (marchand, forgeron, recycleur, joaillier),
## légendaires et accessoires, carte d'objet au survol, archive et apparences,
## certificats (7 au plus), menu principal et écran Héros.
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
	_test_eden_levels()
	_test_treasures()
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
	check("butin courant : jusqu'à épique, jamais mythique ni légendaire", rar.has(3) and not rar.has(4) and not rar.has(5))
	check("6 raretés d'Eden (mythique orange, légendaire or)", Items.RARITIES.size() == 6 and Items.RARITIES[4].name == "Mythique" and Items.RARITIES[5].name == "Légendaire")
	check("trophées sur le butin rare des élites et boss", trophies > 0)
	check("pas de trophée sur le butin courant", range(200).all(func(_i): return Items.generate(5, 0.0).slot != "trophy"))
	# trophées : buff sous condition, pas de stats fixes, objets parasites hors du butin
	var tros: Array = []
	for i in 300:
		tros.append(Items.generate(20, 1.0, "trophy", "samurai", 2))
	check("trophées : un buff sous condition, sans stats fixes", tros.all(func(t): return t.get("passive", {}).has("trophy") and Items.stats(t).is_empty() and not (t.passive.procs as Array).is_empty()))
	check("trophées : jamais de familier, d'objet de test ni de bonus de sort", tros.all(func(t): return not GameData.eden_by_id.get(int(t.eden), {}).has("nopool")))
	check("trophées retirés du butin toujours dans l'archive", Archive.entries("s:trophy").any(func(e): return e.has("nopool")))
	check("carte du trophée : le buff en clair", Items.describe(tros[0]).contains(String(tros[0].passive.desc)))
	var st_uid := Profile.starter_trophy
	check("trophée de départ équipé", st_uid != "" and String(Profile.equipped.get("trophy", {}).get("uid", "")) == st_uid)
	var old_t := {"uid": "old_t", "slot": "trophy", "eden": 34164, "rarity": 5, "rv": 3, "level": 59, "plevel": 20, "quality": 1.0, "upgrade": 0, "affixes": {},
		"base": {"str": 30.0}, "passive": {"name": "Banks", "desc": "x", "procs": []}}
	Profile._migrate(old_t)
	check("ancien trophée : buff sous condition, stats fixes retirées", (old_t.base as Dictionary).is_empty() and old_t.passive.has("trophy"))
	var boss := Items.generate(10, 0.5, "", "samurai", Items.MYTHIC, "", Items.LEGENDARY)
	check("butin de boss : mythique ou légendaire", int(boss.rarity) >= Items.MYTHIC)
	var myth := Items.generate(10, 0.0, "chest", "samurai", Items.MYTHIC, "", Items.MYTHIC)
	var leg := Items.generate(10, 0.0, "chest", "samurai", Items.LEGENDARY, "", Items.LEGENDARY)
	var com := Items.generate(10, -2.0, "chest")
	check("qualité : mythique 100 %%, légendaire %d %%, commun %d %%" % [roundi(float(leg.quality) * 100), roundi(float(com.quality) * 100)],
		is_equal_approx(float(myth.quality), 1.0) and float(leg.quality) >= 1.01 and float(leg.quality) <= 1.2 and float(com.quality) <= 0.9)
	check("objet d'Eden : nom, stats connues", myth.has("eden") and not (myth.base as Dictionary).is_empty() and not Items.stats(myth).is_empty())
	var ring := Items.generate(5, 0.5, "ring")
	check("bague : icône d'Eden et stats", String(ring.icon) != "" and ring.has("eden") and not Items.stats(ring).is_empty())
	Profile.inventory.append(ring)
	Profile.equip(ring)
	check("bague équipée (nouvel emplacement)", _uid("ring") == ring.uid and not Profile.equipment_stats().is_empty())
	# passif d'arme légendaire
	var tpl: Dictionary = GameData.eden_items.filter(func(e): return e.has("passive") and not (e.passive.procs as Array).is_empty())[0]
	var w := Items.from_template(tpl, 10)
	check("arme %s : passif « %s »" % [w.name, w.passive.name], w.has("passive") and Items.describe(w).contains("Passif"))
	# set d'Eden : 2 pièces mythiques portées -> bonus
	var sid: String = GameData.eden_sets.keys().filter(func(k): return (GameData.eden_sets[k].pieces as Array).size() >= 2 and Items.set_tiers(k).has(2))[0]
	var pieces: Array = GameData.eden_sets[sid].pieces
	for pid in pieces.slice(0, 2):
		var e: Dictionary = GameData.eden_by_id.get(int(pid), {})
		if not e.is_empty():
			var p := Items.from_template(e, 10, Items.MYTHIC)
			Profile.inventory.append(p)
			Profile.equip(p)
	check("set d'Eden %s : bonus 2 pièces actif" % Items.set_def(sid).name, Items.active_set_bonuses(Profile.equipped).any(func(b): return b.set == sid))
	# carte d'objet au survol
	var slot := ItemWidgets.ItemSlot.new()
	slot.set_item(ring)
	var card: Control = slot._make_custom_tooltip(slot.tooltip_text)
	add_child(card)
	var rtl: RichTextLabel = card.get_child(0)
	check("carte au survol : nom, stats, qualité", rtl.text.contains(String(ring.name)) and rtl.text.contains("Qualité"))
	card.queue_free()
	slot.free()


func _test_eden_levels() -> void:
	# niveau affiché = niveau d'Eden ; chronologie des zones (pas d'objet d'une zone plus avancée)
	Profile.selected_zone = "limestone"
	var lv0: Array = []
	for i in 60:
		lv0.append(int(Items.generate(5, 0.5).level))
	var b0: Array = GameData.eden_bands[0]
	lv0.sort()
	check("Limestone : objets d'Eden de niveau %d à %d (médiane %d)" % [int(b0[0]), int(b0[1]), lv0[30]], int(lv0[30]) <= int(b0[1]))
	Profile.selected_zone = "blackflame"
	var top := GameData.zone_run_levels(GameData.zone_index("blackflame")).y
	var lv7: Array = []
	for i in 60:
		lv7.append(int(Items.generate(top, 0.5).level))
	lv7.sort()
	check("Blackflame en fin de run : objets de haut niveau d'Eden (médiane %d)" % lv7[30], int(lv7[30]) >= 52)
	var set23: Array = GameData.eden_items.filter(func(e): return int(e.level) == 23 and e.has("set"))
	if not set23.is_empty():
		var it := Items.from_eden(set23[0])
		check("objet d'un set de niveau 23 : niveau 23 dans le jeu (puissance %d)" % Items.power_level(it), int(it.level) == 23 and it.has("plevel"))
	var old := {"uid": "x", "slot": "head", "level": 7, "rarity": 2, "rv": 2, "eden": int(set23[0].id) if not set23.is_empty() else 0, "quality": 1.0}
	Profile._migrate(old)
	check("ancienne sauvegarde : niveau d'Eden affiché, puissance conservée", int(old.get("plevel", 0)) == 7 and int(old.rv) == 3)
	Profile.selected_zone = "limestone"


func _test_treasures() -> void:
	check("archive : %d entrées (équipement %d) dans les catégories d'Eden" % [Archive.total(), Archive.total_gear()], Archive.total() > 9000 and Archive.total_gear() > 3000)
	check("catégories d'apparences et d'objets spéciaux", Archive.categories().any(func(c): return c.id == "c:32") and Archive.categories().any(func(c): return c.id == "c:1"))
	var aura: Dictionary = GameData.auras.filter(func(x): return String(x.aura.kind) == "star")[0]
	check("aura « %s » : effet %s" % [aura.name, aura.aura.fx], FileAccess.file_exists("res://assets/fx/%s.fx.json" % aura.aura.fx))
	Profile.collect(aura)
	Profile.set_aura(Profile.selected_class, "star", int(aura.id))
	check("aura portée : bonus %s" % Archive.bonus_text(Profile.aura_stats(Profile.selected_class)), not Profile.aura_stats(Profile.selected_class).is_empty())
	var root := Node3D.new()
	add_child(root)
	EdenFx.attach_auras(root, Profile.selected_class, 1.3)
	check("aura : effet en boucle autour du héros", root.get_child_count() == 1 and (root.get_child(0) as EdenFx).loop)
	root.queue_free()
	var skin: Dictionary = GameData.collection.filter(func(x): return x.has("skin") and String(x.skin.wtype) == "")[0]
	Profile.collect(skin)
	check("apparence d'arme « %s » disponible pour toutes les armes" % skin.name, Archive.skins("katana").any(func(w): return String(w.code) == String(skin.code)))
	check("apparence d'arme : modèle en main", String(EdenModel.weapon_entry(GameData.class_data("warrior"), String(skin.code)).get("model", "")) == String(skin.skin.model))
	var head: Dictionary = GameData.collection.filter(func(x): return int(x.cat) == 1 and GameData.cosmetic_by_code.has(String(x.code)))[0]
	Profile.collect(head)
	check("apparence de tête obtenue : chapeau portable", Profile.outfit_unlocked(String(GameData.cosmetic_by_code[String(head.code)].id)))
	Profile.save_profile()
	Profile.load_profile()
	check("trésors relus du disque", Profile.collected(aura) and Profile.worn_auras(Profile.selected_class).size() == 1)


func _test_archive() -> void:
	var common := Items.generate(5, -1.0, "head")
	var wtpl: Dictionary = GameData.eden_items.filter(func(e): return e.slot == "weapon" and e.get("wtype", "") == "katana" and int(e.rarity) == Items.MYTHIC and e.has("model") and e.has("arch"))[0]
	var myth := Items.from_template(wtpl, 5)
	var ltpl: Dictionary = GameData.eden_items.filter(func(e): return e.slot == "chest" and int(e.rarity) == Items.LEGENDARY and e.has("arch"))[0]
	var legend := Items.from_template(ltpl, 5)
	for it in [common, myth, legend]:
		Profile.inventory.append(it)
	Profile.equip(myth)
	Profile.save_profile()
	check("archive : objet commun refusé", Archive.refusal(common) != "")
	check("archive : katana mythique accepté", Archive.refusal(myth) == "")
	var str0 := float(Archive.bonus().get("str", 0.0))
	var filled := Profile.archive_item(myth)
	check("archivé : entrée de l'objet d'Eden", filled == ["e%d" % int(wtpl.id)])
	check("archivé : quitte le coffre et les préréglages", not Profile.vault.any(func(x): return x.uid == myth.uid) and Profile.item_users(myth.uid).is_empty())
	check("archivé : une arme reste équipée", Profile.equipped.has("weapon"))
	check("bonus permanent : +1 Force (mythique)", float(Archive.bonus().get("str", 0.0)) == str0 + 1.0)
	check("même entrée : déjà archivé", Archive.refusal(myth.duplicate(true)) != "")
	Profile.archive_item(legend)
	check("légendaire (torse) : +2 Force", float(Archive.bonus().get("str", 0.0)) == str0 + 3.0)
	check("collection %d / %d, score %d" % [Archive.count(), Archive.total(), Archive.score()], Archive.count() == 2 and Archive.total() > 1000 and Archive.score() == 3)
	# apparences : l'arme archivée ajoute son modèle
	var skins := Archive.skins("katana")
	check("skin : l'arme archivée ajoute son apparence", skins.any(func(sk): return String(sk.code) == String(wtpl.code)))
	var code := String(wtpl.code)
	Profile.set_skin("katana", code)
	Profile.load_profile()
	check("archive et apparences relues du disque", Archive.count() == 2 and String(Profile.skins.get("katana", "")) == code)
	var back := Archive.withdraw("e%d" % int(ltpl.id))
	check("retrait de l'archive : l'objet revient au coffre", not back.is_empty() and Archive.count() == 1 and Profile.vault.any(func(x): return x.uid == back.uid))
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
	check("menu principal : 5 entrées (Jouer, Héros, Collection, Paramètres, Quitter)", lobby._menu.keys() == ["play", "hero", "collection", "settings", "quit"])
	check("menu principal : Jouer choisi, sous-menu rempli", lobby._menu.play.selected and lobby._sub.get_child_count() >= 3)
	lobby._show_menu("zones")
	await _frames()
	check("menu Zone de farm : %d zones" % GameData.zones.size(), lobby._sub.get_children().filter(func(c): return c is MenuWidgets.RowButton).size() == GameData.zones.size())
	lobby._show_menu("play")
	# écran Héros : une section à la fois, classe, talents, apparence, aide
	var hero: HeroScreen = lobby._hero
	lobby._open_hero()
	await _frames()
	check("Héros : ouvert sur l'équipement", hero.is_open() and hero.current == "equipment" and hero.page.visible and not hero.talents.visible)
	hero.show_section("talents")
	await _frames()
	check("Héros : talents (plateau de 7 cases, parcours de maîtrise)", hero.talents.visible and not hero.page.visible and hero.talents._board._slots.size() == 7 and hero.talents._track.get_child_count() >= 8)
	check("Héros : pas de second sélecteur de classe dans les talents", not hero.talents._tabs.visible)
	for cat in ["body", "head", "back", "aura", "weapon"]:
		hero.appearance._cat = cat
		hero.show_section("appearance")
		await _frames()
		check("Héros : apparence « %s » affichée" % cat, hero.appearance.visible and hero.appearance._grid.get_child_count() > 1)
	var wt := Items.weapon_type_of(Profile.equipped.get("weapon", {}))
	var skin: Dictionary = Archive.skins(wt)[1]
	hero.appearance._skin_cell(wt, 1, skin).pressed.emit()
	check("Héros : apparence d'arme choisie", Profile.weapon_code() == String(skin.code))
	Profile.set_skin(wt, "")
	hero.show_section("help")
	await _frames()
	for i in InfoPage.SECTIONS.size():
		hero.help.show_section(i)
	check("Héros : aide « ? » (guide des statistiques)", hero.help.visible and hero.help._text.text.length() > 50)
	Profile.selected_class = "warrior"
	Profile.save_profile()
	hero.refresh()
	check("Héros : classe affichée", hero._class_name.text.begins_with("Guerrier"))
	hero.close_ui()
	await _frames()
	check("Héros fermé : retour au menu, badge à jour", not hero.is_open() and lobby._badge_name.text == "Guerrier")
	Profile.selected_class = "samurai"
	Profile.save_profile()
	lobby._archive.open(0)
	await _frames()
	check("Collection : une seule page, sans onglet", lobby._archive._pages.size() == 1 and not lobby._archive._tab_buttons[0].visible)
	check("Collection : catalogue affiché", lobby._archive.is_open() and lobby._archive.page(0)._grid.get_child_count() > 0)
	lobby._archive.close_ui()
	# mode dev : rien sans l'activer dans les Paramètres, puis écran F10
	Settings.set_v("interface", "dev_mode", false)
	Dev.toggle()
	check("mode dev : invisible sans l'activer", not is_instance_valid(Dev.screen) and not lobby._dev_button.visible)
	Settings.set_v("interface", "dev_mode", true)
	check("mode dev : bouton du lobby", lobby._dev_button.visible)
	Dev.toggle()
	await _frames()
	var dev: DevScreen = Dev.screen
	check("mode dev : écran ouvert (Objets, Ressources, Progression ; pas de Run au lobby)", dev.is_open() and dev._pages.size() == 3)
	var items: DevPages.ItemsPage = dev.page(0)
	var tpl: Dictionary = GameData.eden_items.filter(func(e): return e.slot == "ring")[0]
	items._selected = tpl
	items._give_rar.select(Items.LEGENDARY + 1)
	items._give_power.value = 30
	var before := Profile.vault.size()
	items._give(tpl, 5)
	var got: Array = Profile.vault.slice(before)
	check("mode dev : ×5 au coffre, rareté et puissance choisies", got.size() == 5 and got.all(func(it): return int(it.rarity) == Items.LEGENDARY and int(it.plevel) == 30))
	for it in got:
		Profile.vault.erase(it)
	for i in 3:
		dev.show_page(i)
		await _frames()
	check("mode dev : pages Ressources et Progression", dev.page(1).get_child_count() > 0 and dev.page(2)._msg.text.contains("Classes débloquées"))
	Dev.toggle()
	check("mode dev : F10 referme", not dev.is_open())
	Settings.set_v("interface", "dev_mode", false)
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
	var eq: InventoryPage = screen.page(1)
	var shown := eq._grid.get_children().filter(func(c): return c is InventoryPage.StackSlot and c.entry.kind == "item").size()
	check("inventaire : sac de la run affiché (%d)" % shown, shown == Profile.inventory.size())
	check("inventaire : fournitures et matériaux en piles", eq._grid.get_children().any(func(c): return c is InventoryPage.StackSlot and c.entry.kind == "stack"))
	var it: Dictionary = Profile.inventory.filter(func(x): return x.slot != "weapon")[0]
	eq._equip(it)
	check("équiper depuis la page", is_same(Profile.equipped.get(it.slot), it))
	eq._unequip(it.slot)
	check("retirer depuis la page", not Profile.equipped.has(it.slot) or not is_same(Profile.equipped.get(it.slot), it))
	screen.show_page(2)
	var info: InfoPage = screen.page(2)
	info.show_section(InfoPage.SECTIONS.size() - 1)
	check("pause : page Aide avec les valeurs du héros", info._text.text.contains("PV effectifs"))
	world.pause_menu.close()
	await _frames()
	# mode dev en run : page Run
	Settings.set_v("interface", "dev_mode", true)
	Dev.open(3)
	await _frames()
	var rp: DevPages.RunActionsPage = Dev.screen.page(3)
	check("mode dev en run : page Run, jeu en pause", Dev.screen._pages.size() == 4 and rp.visible and get_tree().paused)
	var lv := player.level
	rp._box.get_child(1).get_child(1).pressed.emit()
	check("mode dev : niveau +5", player.level == lv + 5)
	player.dev_invincible = true
	var hp := player.hp
	player.take_damage(99999.0)
	check("mode dev : invincible", player.hp == hp)
	player.dev_invincible = false
	var n0 := get_tree().get_nodes_in_group("monsters").size()
	world.director.dev_spawn_elite()
	world.director.dev_spawn_chest()
	check("mode dev : élite et coffre apparus", get_tree().get_nodes_in_group("monsters").size() == n0 + 1 and world.director.map.interactables[-1].kind == "chest")
	await _frames()
	check("mode dev : tuer tous les monstres", world.director.dev_kill_all() >= 1)
	Dev.screen.close_ui()
	Settings.set_v("interface", "dev_mode", false)
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
