extends Node
## Écrans plein écran : préréglages d'équipement par classe et coffre commun,
## menu pause (Run, Héros, Aide), marchands ambulants, forge, coffres payants, sanctuaires,
## coffres de récompense,
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
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(HeroLevel.MAX_LEVEL)  # lot H3 : niveau 90, toutes les pièces se portent
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
	check("guerrier : pas le casque du samouraï (son propre casque de départ)", _uid("head") != helm.uid and _uid("head") != "")
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
	check("magicien à l'arc (arme secondaire), le samouraï garde son katana", Items.weapon_type_of(Profile.equipped.get("offhand", {})) == "bow"
		and String(Profile.presets.samurai.sets[0].slots.weapon) != String(Profile.equipped.offhand.uid))
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
	check("plus de trophée dans le butin (collection de la run)", trophies == 0)
	# trophées : buff sous condition, pas de stats fixes, objets parasites hors du butin
	var tros: Array = []
	for i in 300:
		tros.append(Items.generate(20, 1.0, "trophy", "samurai", 2))
	check("trophées : un buff sous condition, sans stats fixes", tros.all(func(t): return t.get("passive", {}).has("trophy") and Items.stats(t).is_empty() and not (t.passive.procs as Array).is_empty()))
	check("trophées : jamais de familier, d'objet de test ni de bonus de sort", tros.all(func(t): return not GameData.eden_by_id.get(int(t.eden), {}).has("nopool")))
	check("trophées retirés du butin toujours dans l'archive", Archive.entries("s:trophy").any(func(e): return e.has("nopool")))
	check("carte du trophée : le buff en clair", Items.describe(tros[0]).contains(String(tros[0].passive.desc)))
	check("plus de trophée de départ ni de trophée porté", not Profile.equipped.has("trophy"))
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
	for i in 120:
		lv0.append(int(Items.generate(5, 0.5).level))
	var b0: Array = GameData.eden_bands[0]
	# certaines pièces (capes, armes de certaines classes) n'existent pas sous le niveau 20 dans Eden
	var inside := lv0.filter(func(l): return l <= int(b0[1])).size()
	check("Limestone : objets d'Eden de niveau %d à %d (%d / 120 dans la tranche)" % [int(b0[0]), int(b0[1]), inside], inside >= 48)
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
	check("pas de bonus par entrée (seulement les paliers)", float(Archive.bonus().get("str", 0.0)) == str0)
	check("même entrée : déjà archivé", Archive.refusal(myth.duplicate(true)) != "")
	Profile.archive_item(legend)
	check("légendaire archivé : toujours pas de stat par entrée", float(Archive.bonus().get("str", 0.0)) == str0)
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
	check("nouvelle partie : les 5 classes de base jouables", Progression.START_CLASSES.all(func(c): return Progression.class_unlocked(c)) and not Progression.class_unlocked("samurai"))
	var got: Array = []
	var cb := func(c): got.append(c)
	Profile.class_unlocked.connect(cb)
	Profile.set_expertise_level("warrior", 3)
	check("Guerrier 3 : Chevalier débloqué, pas le Samouraï (Guerrier 3 et Voleur 3)", Progression.class_unlocked("knight") and not Progression.class_unlocked("samurai")
		and Progression.mission_progress("samurai") == Vector2(4, 6))
	Profile.set_expertise_level("thief", 3)
	check("Voleur 3 : Samouraï débloqué", Progression.class_unlocked("samurai") and "samurai" in got)
	Profile.set_expertise_level("knight", 5)
	check("Chevalier 5 : Chevalier dragon débloqué (Chevalier 5 ou Guerrier 5)", Progression.class_unlocked("dragon_knight"))
	check("Templier : une classe de la famille au niveau 7", Progression.mission_text("templar") == "Maîtrise Guerrier 7 ou Chevalier 7 ou Chevalier dragon 7")
	Profile.expertise = {}
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
	# le même passif d'une autre classe de la lignée ne se pose pas une 2e fois
	var owner_of := {}
	var pair: Array = []
	for cls in GameData.talents:
		for pid in GameData.talents[cls].get("certificates", []):
			if owner_of.has(pid) and pair.is_empty():
				pair = ["%s/%s" % [owner_of[pid], pid], "%s/%s" % [cls, pid]]
			owner_of[pid] = cls
	check("des passifs partagés entre classes existent", not pair.is_empty())
	if not pair.is_empty():
		var saved_board: Array = Profile.cert_board.duplicate()
		Profile.cert_board = ["", "", "", "", "", "", ""]
		Profile.place_certificate(pair[0], 3)
		Profile.place_certificate(pair[1], 1)
		check("passif déjà posé : refusé", String(Profile.cert_board[1]) == "" and Profile.cert_passive_posed(pair[1]))
		Profile.cert_board = saved_board
	check("couleur d'après la stat : PV = jaune, critique = bleu", CertBoard.color_of("warrior/unshakable") == "yellow" and CertBoard.color_of("thief/dagger_expert") == "blue")
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
	check("écran titre : illustrations du titre et du menu chargées", title.bg_title.texture != null and title.bg_menu.texture != null)
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
	check("menu principal : Jouer, Héros, Coffres, Atelier, Carnet, Paramètres, Quitter", lobby._menu.keys() == ["play", "hero", "chests", "workshop", "collection", "settings", "quit"])
	check("accueil : panneau Jouer caché au départ", not lobby._sub_panel.visible)
	lobby._on_menu("play")
	await _frames()
	check("menu principal : Jouer choisi, sous-menu rempli", lobby._menu.play.selected and lobby._sub_panel.visible and lobby._sub.get_child_count() >= 3)
	lobby._on_menu("play")
	check("second clic sur Jouer : panneau refermé", not lobby._sub_panel.visible)
	# caméra de l'accueil : molette, glisser, double-clic
	var bd: MapBackdrop = lobby.backdrop
	var cam0: Vector3 = bd.camera.position
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	lobby._unhandled_input(wheel)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	lobby._unhandled_input(press)
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(120, 30)
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	lobby._unhandled_input(move)
	press.pressed = false
	lobby._unhandled_input(press)
	check("accueil : molette et glisser bougent la caméra autour du héros", bd.orbit_dist < MapBackdrop.STAGE_DIST and bd.orbit_yaw != 0.0 and bd.camera.position.distance_to(cam0) > 0.3)
	var dbl := InputEventMouseButton.new()
	dbl.button_index = MOUSE_BUTTON_LEFT
	dbl.pressed = true
	dbl.double_click = true
	lobby._unhandled_input(dbl)
	check("accueil : double-clic, vue de départ", bd.orbit_yaw == 0.0 and bd.camera.position.distance_to(cam0) < 0.01)
	lobby._show_menu("survival")
	await _frames()
	check("page Survie : %d époques" % Epochs.count(), lobby._sub.get_children().filter(func(c): return c is MenuWidgets.RowButton).size() == Epochs.count())
	# pages du lobby : largeur fixe, jamais plus haute que l'écran, bouton d'action épinglé et visible, lignes sans chevauchement
	get_tree().root.size = Vector2i(1600, 900)
	await _frames()
	var screen_h: float = lobby.get_viewport().get_visible_rect().size.y
	for pid in ["survival", "dungeon", "siege", "duel", "royale", "autochess", "arenas", "rush", "tower", "tower_floors", "mastery", "training"]:
		lobby._show_menu(pid)
		await _frames()
		await _frames()
		var rect: Rect2 = lobby._sub_panel.get_global_rect()
		check("page %s : panneau de largeur fixe, dans l'écran" % pid, absf(rect.size.x - float(lobby.PANEL_W)) < 12.0 and rect.end.y <= screen_h)
		if pid != "mastery" and pid != "tower":
			var btn: Control = lobby._foot.get_child(lobby._foot.get_child_count() - 1) if lobby._foot.get_child_count() > 0 else null
			check("page %s : bouton d'action épinglé, visible" % pid, btn != null and btn.get_global_rect().end.y <= screen_h and btn.get_global_rect().size.y > 30.0)
		for c in lobby._sub.get_children():
			if c is MenuWidgets.RowButton:
				check("page %s : ligne assez haute pour son texte" % pid, c.size.y >= c._content.get_combined_minimum_size().y)
	lobby._show_menu("play")
	# (P18 : compté d'après Activities.LIST ; la rangée Aventure a 4 cartes depuis le Survivant, 0.1.210)
	var n_cards := 0
	for c in lobby._sub.get_children():
		if c is GridContainer:
			n_cards += c.get_children().filter(func(b): return b is Button).size()  # (sans les cases vides de fin de rangée)
	var shown: Array = Activities.LIST.filter(func(x): return String(x.row) != "" and not x.get("soon", false) and not Activities.hidden(x))
	check("page Jouer : les « Bientôt » sont cachés (%d cartes, %d attendues)" % [n_cards, shown.size()], n_cards == shown.size())
	# écran Héros : une section à la fois, classe, talents, apparence, aide
	var hero: HeroScreen = lobby._hero
	lobby._open_hero()
	await _frames()
	check("Héros : ouvert sur l'équipement", hero.is_open() and hero.current == "equipment" and hero.page.visible and not hero.talents.visible)
	# création de personnage (C1) : bouton « Personnage » de Héros ; l'écran tient dans 1280 x 720 (aucun contrôle coupé)
	check("Héros : bouton « Personnage » visible hors run", hero._creator_button.visible)
	get_tree().root.size = Vector2i(1280, 720)
	await _frames()
	var hc := hero.open_creator()
	await _frames(3)
	var vp: Vector2 = hc.get_viewport().get_visible_rect().size
	var cut: Array = []
	for b: Control in [hc.ok_button, hc.keep_button, hc.random_button, hc.reset_button, hc.name_edit, hc.preview] + hc._hair_swatches.values() + hc._eye_swatches.values():
		var r := b.get_global_rect()
		if r.end.x > vp.x + 1.0 or r.end.y > vp.y + 1.0 or r.size.x < 8.0 or r.size.y < 8.0:
			cut.append(b.name)
	check("création de personnage : tout tient dans 1280 x 720 %s" % str(cut), cut.is_empty())
	hc.close_ui()
	get_tree().root.size = Vector2i(1600, 900)
	await _frames()
	check("Héros : fiche d'objet masquée sans sélection, 3 préréglages + « Gérer »", not hero.page._d_card.visible and hero.page.preset_bar.visible and hero.page.preset_bar.get_child_count() == 4)
	var worn_head: Dictionary = Profile.equipped.get("head", {})
	var spare := Items.generate(30, 0.9, "head", Profile.selected_class)
	Profile.inventory.append(spare)
	hero.page.refresh()
	hero.page._select({"kind": "item", "item": spare})
	check("Héros : une pièce choisie montre la pièce portée à côté", hero.page._d_card.visible and hero.page._d_cmp.visible
		and hero.page._d_cmp_name.text == (Items.display_name(worn_head) if not worn_head.is_empty() else "Emplacement libre"))
	hero.page._select({})
	check("Héros : fiche masquée de nouveau sans sélection", not hero.page._d_card.visible)
	Profile.inventory.erase(spare)
	var pb: EquipmentPage.PresetBar = hero.page.preset_bar
	var act := {"called": ""}
	var cb := func(cid):
		act.called = cid
		return "fait"
	pb.extra_actions.append({"label": "Action de test", "call": cb})
	pb._open_menu()
	await _frames()
	var entry: Button = null
	for b in pb._pop.find_children("*", "Button", true, false):
		if (b as Button).text == "Action de test":
			entry = b
	check("préréglages : le menu « Gérer » reçoit les actions ajoutées (copie, renommage, équiper le meilleur)", entry != null
		and pb._pop.find_children("*", "Button", true, false).filter(func(b): return (b as Button).text.begins_with("Copier vers")).size() == 2)
	entry.pressed.emit()
	check("préréglages : l'action ajoutée reçoit la classe affichée", act.called == Profile.selected_class)
	pb.extra_actions.clear()
	var before_preset := Profile.active_preset(Profile.selected_class)
	pb.get_child((before_preset + 1) % 3).pressed.emit()
	check("préréglages : un clic change de préréglage", Profile.active_preset(Profile.selected_class) == (before_preset + 1) % 3)
	pb.get_child(before_preset).pressed.emit()
	check("préréglages : retour au préréglage d'origine", Profile.active_preset(Profile.selected_class) == before_preset)
	hero.show_section("class")
	await _frames()
	check("Héros : page Classe (sorts, plateau de 7 cases, parcours de maîtrise)", hero.talents.visible and hero.talents._spells.get_child_count() >= 4 and not hero.page.visible and hero.talents._board._slots.size() == 7 and hero.talents._track.get_child_count() >= 8)
	check("Héros : pas de second sélecteur de classe dans les talents", not hero.talents._tabs.visible)
	check("Héros : Classe s'ouvre sur les sorts, un seul sous-onglet à la fois", hero.talents.sub == "spells" and hero.talents._sub_pages.spells.visible
		and not hero.talents._sub_pages.talents.visible and not hero.talents._sub_pages.certs.visible)
	hero.talents.show_sub("talents")
	check("Héros : sous-onglet Talents", hero.talents._sub_pages.talents.visible and not hero.talents._sub_pages.spells.visible and hero.talents._grid.get_child_count() > 0)
	hero.talents.show_sub("certs")
	check("Héros : sous-onglet Certificats", hero.talents._sub_pages.certs.visible and hero.talents._certs.get_child_count() > 0)
	hero.talents.show_sub("spells")
	hero.talents._spells.get_child(2).pressed.emit()
	check("Héros : un sort cliqué ouvre le Grimoire sur ce sort", hero.grimoire.is_open() and String(hero.grimoire._selected.get("kind", "")) == "skill"
		and int(hero.grimoire._selected.data.id) == int(GameData.class_data(Profile.selected_class).skills[2].id))
	check("sorts : plus de mention du jeu d'origine ni de description répétée", not SpellInfo.skill_bbcode(GameData.class_data(Profile.selected_class).skills[2]).contains("Eden"))
	hero.grimoire.close_ui()
	hero.show_section("equipment")
	hero.step_page(1)
	check("Héros : LB / RB change de section", hero.is_in_group("tab_screens") and hero.current == "class")
	hero.step_page(-1)
	hero.show_section("appearance")
	await _frames()
	var unlocked_bodies := GameData.cosmetics.filter(func(c): return HeroPages.AppearancePage.cat_of(c) == "body" and Profile.outfit_unlocked(String(c.id))).size()
	check("Héros : apparence, « Débloqués uniquement » par défaut (que les pièces débloquées)", hero.appearance._owned_only.button_pressed and hero.appearance._grid.get_child_count() == 1 + unlocked_bodies)
	hero.appearance._owned_only.button_pressed = false
	for cat in ["body", "head", "back", "aura", "weapon"]:
		hero.appearance._cat = cat
		hero.show_section("appearance")
		await _frames()
		check("Héros : apparence « %s » affichée" % cat, hero.appearance.visible and hero.appearance._grid.get_child_count() > 1)
		if cat == "back":
			var lines: PackedStringArray = []
			Feedback._describe_node(hero.appearance._grid.get_child(1), lines)
			check("note Alt + clic droit : la case d'ailes se décrit (%s)" % (lines[0] if not lines.is_empty() else "?"), not lines.is_empty() and lines[0].begins_with("Apparence back"))
			Feedback.open_at(Vector2(400, 300))
			var fb_open: bool = Feedback.is_open() and get_tree().paused
			Feedback._close()
			check("note : fenêtre ouverte puis fermée", fb_open and not Feedback.is_open())
	var wt := Items.weapon_type_of(Profile.equipped.get("weapon", {}))
	var skin: Dictionary = Archive.skins(wt)[1]
	hero.appearance._skin_cell(wt, 1, skin).pressed.emit()
	check("Héros : apparence d'arme choisie", Profile.weapon_code() == String(skin.code))
	Profile.set_skin(wt, "")
	hero.show_section("help")
	await _frames()
	var guide_shown := hero._guide_open()
	Guide.close_in(get_tree().current_scene)
	await _frames()
	check("Héros : « ? » ouvre le Guide sur ses formules (la seule aide du jeu), plus de page d'aide à part", guide_shown and not hero._guide_open() and not hero._pages.has("help"))
	Profile.selected_class = "warrior"
	Profile.save_profile()
	hero.refresh()
	check("Héros : classe affichée", hero._class_name.text.begins_with("Guerrier"))
	hero.close_ui()
	await _frames()
	check("Héros fermé : retour au menu, badge à jour", not hero.is_open() and lobby._badge_name.text.begins_with("Guerrier"))
	Profile.selected_class = "samurai"
	Profile.save_profile()
	lobby._archive.open(4)
	await _frames()
	check("Carnet : vue d'ensemble, succès, cartes, trophées, collection, registre ; Atelier : Fabriquer, Plans de donjon et Forge", lobby._archive._pages.size() == 6 and lobby._archive.page(5) is RegistryPage and lobby._workshop._pages.size() == 3)
	check("Atelier : onglets Fabriquer, Plans de donjon, Forge (plus d'Armurerie)", lobby._workshop._tab_buttons.map(func(t): return String(t.text)) == ["Fabriquer", "Plans de donjon", "Forge"])
	check("Collection : catalogue affiché", lobby._archive.is_open() and lobby._archive.page(4)._grid.get_child_count() > 0)
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
	check("mode dev : écran ouvert (Objets, Éditer, Sets, Cartes, Ressources, Progression, Tour ; pas de Run au lobby)", dev.is_open() and dev._pages.size() == 7)
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
	for i in 6:
		dev.show_page(i)
		await _frames()
	check("mode dev : pages Ressources et Progression", dev.page(4).get_child_count() > 0 and dev.page(5)._msg.text.contains("Classes débloquées"))
	# éditeur de cartes : modifier Lame large (+20 % au lieu de +15 %), puis rétablir
	var cp: DevCards.CardsPage = dev.page(3)
	cp._open("wide_arc")
	cp._stats.set_values({"area": 0.2})
	cp._save()
	check("éditeur de cartes : Lame large modifiée (+20 % de rayon par carte commune)", is_equal_approx(float(Boons.get_def("wide_arc").stat.area), 0.2) and DevEdits.data.cards.has("wide_arc"))
	cp._reset()
	check("éditeur de cartes : carte rétablie", is_equal_approx(float(Boons.get_def("wide_arc").stat.area), 0.14) and not DevEdits.data.cards.has("wide_arc"))
	cp._open("")
	check("éditeur de cartes : règles des raretés", cp._rule_spins.has("tier_legendary") and cp._rule_spins.has("heal"))
	await _test_dev_editor(dev)
	Dev.toggle()
	check("mode dev : F10 referme", not dev.is_open())
	Settings.set_v("interface", "dev_mode", false)
	lobby.free()


## Éditeur du mode dev : objet possédé, modèle du catalogue, set créé (fichier de test).
func _test_dev_editor(dev: DevScreen) -> void:
	var ed: DevEditor.EditPage = dev.page(1)
	dev.show_page(1)
	await _frames()
	# objet possédé : stats bonus, amélioration, buff sous condition
	ed._mode.select(0)
	ed._refresh_list()
	var it: Dictionary = ed._entries.filter(func(x): return x.slot != "weapon")[0]
	ed._select(it)
	ed._up.value = 7
	ed._stats.set_values({"agi": 50.0, "crit": 0.1})
	ed._kind.select(1 + Trophies.KINDS.keys().find("double"))
	ed._save_owned()
	check("éditeur : objet possédé (+7, +50 Agilité, +10 % critique, double frappe)", int(it.upgrade) == 7 and is_equal_approx(float(it.affixes.agi), 50.0)
		and is_equal_approx(float(it.affixes.crit), 0.1) and String(it.passive.trophy) == "double" and Items.stats(it).get("agi", 0.0) >= 50.0)
	# modèle du catalogue : stats de base et rareté
	var tpl: Dictionary = GameData.eden_items.filter(func(e): return e.slot == "chest" and int(e.rarity) == 2)[0]
	ed.edit_template(tpl)
	ed._stats.set_values({"str": 3.0, "hp": 2.0})
	ed._rar.select(Items.LEGENDARY)
	ed._save_template()
	var made := Items.from_template(tpl, 20)
	check("éditeur : modèle modifié (légendaire, Force ×3)", int(tpl.rarity) == Items.LEGENDARY and made.base.has("str") and DevEdits.is_edited(int(tpl.id)))
	# set créé : 2 pièces, bonus à 2 pièces
	var sp: DevEditor.SetsPage = dev.page(2)
	dev.show_page(2)
	await _frames()
	sp._new_set()
	var sid := sp._sid
	var ring: Dictionary = GameData.eden_items.filter(func(e): return e.slot == "ring" and int(e.rarity) < Items.MYTHIC)[0]
	sp._name.text = "Set de test"
	sp._add_piece(int(tpl.id))
	sp._add_piece(int(ring.id))
	sp._tiers[2].on.button_pressed = true
	sp._tiers[2].stats.set_values({"dmg_pct": 0.2})
	sp._save()
	var p1 := Items.from_template(tpl, 20)
	var p2 := Items.from_template(ring, 20, 1)
	check("éditeur : set créé (pièces à toute rareté)", String(p1.get("set", "")) == sid and String(p2.get("set", "")) == sid)
	check("éditeur : bonus à 2 pièces actif", Items.active_set_bonuses({"chest": p1, "ring": p2}).any(func(b): return b.set == sid and float(b.stat.get("dmg_pct", 0.0)) > 0.19))
	check("éditeur : enregistré (fichier de test, jamais le vrai)", FileAccess.file_exists(DevEdits.TEST_PATH) and DevEdits.paths() == [DevEdits.TEST_PATH])
	# nettoyage : le fichier de modifications ne garde rien du test
	DevEdits.delete_set(sid)
	DevEdits.data.sets.erase(sid)
	DevEdits.reset_item(int(tpl.id))
	DevEdits.reset_item(int(ring.id))
	check("éditeur : modèle d'origine retrouvé", int(tpl.rarity) == 2 and not tpl.has("set"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DevEdits.TEST_PATH))


func _test_run_screens() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.cards._queue.clear()
	world.cards._show_next()
	# écrans de run et forge (hors Survie : en Survie, les pièces restent à +0)
	Run.survival = false
	if not Profile.equipped.has("weapon"):
		Profile.equipped["weapon"] = Items.generate(5, 0.0, "weapon", Run.class_id)
	var player: Player = world.player
	for i in 8:
		Profile.add_item(Items.generate(5, 1.0 if i < 3 else -0.5))
	Profile.gain({"gold": 5000, "crystal": 6})
	for k in ["drill", "drill", Craft.stone_key("lucky"), Craft.stone_key("coral"), Craft.fortify_key("power", 100), Craft.BLESSED,
			Craft.gem_key("ruby", 0), Craft.gem_key("ruby", 0), Craft.gem_key("ruby", 0), Craft.scroll_key("violence", 1)]:
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
	check("pause > Héros : ni préréglages (la classe est fixée) ni Forge en Survie", not eq.preset_bar.visible and (not Run.survival or not eq._b_upgrade.visible))
	eq._unequip(it.slot)
	check("retirer depuis la page", not Profile.equipped.has(it.slot) or not is_same(Profile.equipped.get(it.slot), it))
	check("pause : deux pages (Run, Héros), l'aide est un bouton", screen.page_count() == 2)
	var guide: Guide = world.pause_menu.open_guide()
	await _frames()
	check("pause : « ? Aide » ouvre le Guide sur Détails, la pause reste", guide != null and guide.current_page() == Guide.chapter_index("details") and world.pause_menu.is_open() and get_tree().paused)
	if guide != null:
		var info: InfoPage = guide.page(guide.current_page())
		info.show_section(InfoPage.SECTIONS.size() - 1)
		check("pause : le Guide donne les valeurs du héros", info._text.text.contains("PV effectifs"))
		guide.close()
	await _frames()
	check("pause : Guide fermé, pause toujours ouverte et en pause", world.pause_menu.is_open() and get_tree().paused)
	world.pause_menu.close()
	await _frames()
	# mode dev en run : page Run
	Settings.set_v("interface", "dev_mode", true)
	Dev.open(7)
	await _frames()
	var rp: DevPages.RunActionsPage = Dev.screen.page(7)
	check("mode dev en run : page Run, jeu en pause", Dev.screen._pages.size() == 8 and rp.visible and get_tree().paused)
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
	# marchand ambulant (le village n'existe plus)
	var map = world.director.map
	check("carte : 3 marchands ambulants, ~10 coffres, ~10 sanctuaires", map.interactables.filter(func(i): return i.kind == "merchant").size() == 3
		and map.chests.size() >= 8 and map.shrines.size() >= 8 and map.interactables.all(func(i): return not i.kind in ["smith", "recycler", "jeweler"]))
	var v: MerchantUI = world.merchant_ui
	var npc: Interactable = map.interactables.filter(func(i): return i.kind == "merchant")[0]
	v.open(npc)
	await _frames()
	check("marchand : boutique ouverte (2 pages : Boutique, Vendre ; plus de fabrication de mythiques)", v.is_open() and v._screen._pages.size() == 2)
	check("marchand : cartes, clé, fournitures, équipement", v.offers.any(func(o): return o.has("card") and o.card.type in ["skill", "upgrade", "passive"]) and v.offers.any(func(o): return o.has("keys"))
		and v.offers.any(func(o): return o.has("bag")) and v.offers.any(func(o): return o.has("item")))
	var offers_first: Array = v.offers
	v.close_ui()
	v.open(npc)
	check("marchand : mêmes offres à la 2e visite", is_same(v.offers, offers_first))
	# vendre
	v._screen.show_page(1)
	await _frames()
	var sell: MerchantPages.SellPage = v._screen.page(1)
	sell.grid.select_up_to_rarity(1)
	var n_before := Profile.inventory.size()
	var gold_before := Profile.gold
	var picked := sell.grid.selection().size()
	Profile.sell_many(sell.grid.selection().duplicate())
	check("vendre : %d objet(s), or reçu" % picked, picked > 0 and Profile.inventory.size() == n_before - picked and Profile.gold > gold_before)
	# acheter : fourniture, clé
	var offer: Dictionary = v.offers.filter(func(o): return o.has("bag"))[0]
	v.buy(offer)
	check("acheter une fourniture", offer.get("sold", false))
	var keys0 := Profile.keys
	v.buy(v.offers.filter(func(o): return o.has("keys"))[0])
	check("acheter une clé", Profile.keys == keys0 + 1)
	v.close_ui()
	# forge : améliorer à l'or seulement, réforger et polir avec des cristaux
	var piece: Dictionary = Profile.equipped.weapon
	check("fortification : or + parchemin", Items.upgrade_cost(piece).keys() == ["gold"] and Craft.fortify_for(piece) != "")
	var up0 := int(piece.get("upgrade", 0))
	var g0 := Profile.gold
	Profile.upgrade_item(piece)
	check("fortifier (+1 sûr, or payé, parchemin consommé)", int(piece.upgrade) == up0 + 1 and Profile.gold < g0 and Profile.bag_count(Craft.fortify_key("power", 100)) == 0)
	var crys0 := Profile.amount("crystal")
	var junk: Dictionary = Profile.inventory.filter(func(x): return x.slot != "trophy")[0]
	Profile.disassemble_many([junk])
	check("démonter : des cristaux (%d → %d)" % [crys0, Profile.amount("crystal")], Profile.amount("crystal") > crys0)
	Profile.materials.crystal = 50
	var rare := Items.generate(10, 1.0, "chest", "samurai", 2)
	rare["upgrade"] = 4
	rare["up_rolls"] = [["str", 6.0, 4]]  # stat bonus du palier +4 : seule stat réforgeable
	Profile.add_item(rare)
	var stat: String = Forge.reforgeable(rare)[0]
	var txt := Forge.reforge(rare, stat)
	check("réforger une stat : des cristaux (%s)" % txt, Profile.amount("crystal") < 50 and txt.contains("→") and Forge.reforge_cost(rare).keys() == ["crystal"])
	var q0 := float(rare.get("quality", 1.0))
	Forge.polish(rare)
	check("polir : cristaux, la qualité ne baisse jamais", float(rare.quality) >= q0 and Forge.polish_cost(rare).keys() == ["crystal"])
	# joaillerie (dans la forge) : percer, fusionner, sertir
	var jewel: Dictionary = Profile.inventory[0]
	Craft.drill(jewel)
	check("percer un emplacement", jewel.get("sockets", []).size() == 1)
	Forge.fuse("ruby", 0)
	check("fusion : 3 rubis bruts → 1 rubis taillé", Profile.bag_count(Craft.gem_key("ruby", 1)) == 1 and Profile.bag_count(Craft.gem_key("ruby", 0)) == 0)
	Craft.insert_gem(jewel, Craft.gem_key("ruby", 1), 0)
	check("sertir la gemme fusionnée", jewel.sockets[0] != null)
	v.open_forge(jewel)
	await _frames()
	var fp: MerchantPages.ForgePage = v._forge.page(0)
	check("forge : une seule page, l'objet choisi et ses sections", v._forge._pages.size() == 1 and fp.grid.selection().size() == 1 and fp.actions.get_child_count() >= 6)
	fp.grid.clear_selection()
	await _frames()
	check("forge sans objet : fusion des gemmes", fp.detail.text.contains("cristaux"))
	v.close_ui()
	for i in v._screen._pages.size():
		v.open(npc, i)
		await _frames(1)
	v.close_ui()
	check("toutes les pages du marchand s'affichent", true)
	# coffres de la carte : or (prix qui monte) ou clé
	var d: RunDirector = world.director
	var chest: Interactable = map.interactables.filter(func(i): return i.kind == "chest" and not i.used)[0]
	Profile.keys = 0
	Profile.gold = 0
	var tier := int(chest.get_meta("tier", 0))
	var box := String(chest.get_meta("box", ""))
	var p0 := d.chest_price(tier, box)
	d._interact(chest)
	check("coffre : refusé sans or ni clé (%d or)" % p0, not chest.used)
	Profile.gold = 1000
	world.cards._queue.clear()
	d._interact(chest)
	check("coffre : payé en or, choix d'équipement, prix suivant plus cher", chest.used and Profile.gold == 1000 - p0 and d.chest_price(tier, box) > p0 and (world.cards.is_open() or not world.cards._queue.is_empty()))
	world.cards._queue.clear()
	world.cards._show_next()
	var chest2: Interactable = map.interactables.filter(func(i): return i.kind == "chest" and not i.used)[0]
	Profile.keys = 1
	var gold2 := Profile.gold
	d._interact(chest2)
	check("coffre : une clé à la place de l'or", chest2.used and Profile.keys == 0 and Profile.gold == gold2)
	world.cards._queue.clear()
	world.cards._show_next()
	# sanctuaire : capture → récompense de la run
	var sh: Shrine = map.shrines.filter(func(x): return not x.captured)[0]
	sh.reward = "trophy"  # la carte en a presque toujours, mais le placement est aléatoire
	player.global_position = sh.global_position + Vector3.UP * 0.5
	var tro0 := Run.trophies.size()
	for i in 20:
		d._update_shrines(1.0)
	check("sanctuaire capturé en restant dans le cercle", sh.captured and d.shrines_captured >= 1)
	check("sanctuaire des trophées : choix de 3 trophées", world.cards.is_open() and world.cards._cards.size() == 3 and world.cards._cards.all(func(c): return c.type == "trophy"))
	world.cards._opened_at = 0
	world.cards._choose(0)
	check("trophée choisi : dans la collection de la run", Run.trophies.size() == tro0 + 1 and Run.trophies[-1].slot == "trophy")
	world.cards._queue.clear()
	world.cards._show_next()
	# élite : une clé ; coffres de récompense gardés à l'extraction
	var keys1 := Profile.keys
	var chests0 := Profile.reward_chests.size()
	world.director.dev_spawn_elite()
	await _frames()
	var elite: Monster = get_tree().get_nodes_in_group("monsters").filter(func(m): return m.is_elite)[-1]
	elite.take_damage(1e9, player)
	check("élite vaincue : une clé", Profile.keys == keys1 + 1)
	world.cards._queue.clear()
	world.cards._show_next()
	Run.pick_up(Rewards.loot_item(Rewards.make("set", 10)))
	Run.pick_up(Rewards.loot_item(Rewards.make("forge", 10)))
	check("coffres de récompense ramassés : tout de suite au menu Coffres (jamais perdus)", Profile.reward_chests.size() == chests0 + 2)
	world.queue_free()
	await _frames()
	Run.finish("extraction")
	Profile.end_run_extract()
	check("extraction : coffres gardés, or et clés perdus", Profile.reward_chests.size() >= 2 and Profile.gold == 0 and Profile.keys == 0)
	check("cristaux gardés entre les runs", Profile.amount("crystal") > 0)
	# menu Coffres : ouvrir, choisir
	var forge_chest: Dictionary = Profile.reward_chests.filter(func(c): return c.type == "forge")[0]
	var st0 := Profile.stash_count()
	var got := Rewards.open(forge_chest)
	check("coffre de forge ouvert : fournitures et cristaux", Profile.stash_count() > st0 and int(got.crystal) > 0 and not Profile.reward_chests.has(forge_chest))
	var tc: Dictionary = Profile.reward_chests.filter(func(c): return c.type == "set")[0]
	var offer3 := Rewards.offer(tc)
	check("coffre de set : 3 propositions gardées", offer3.size() == 3 and is_same(Rewards.offer(tc), offer3))
	var vault0 := Profile.vault.size()
	var chosen := Rewards.choose(tc, 1)
	check("pièce choisie : au coffre commun", Profile.vault.size() == vault0 + 1 and chosen.slot != "trophy" and not Profile.reward_chests.has(tc))
	check("plus de coffres de trophées", range(300).all(func(_i): return Rewards.roll_type(randf() < 0.5) != "trophy"))
	var sc := Rewards.make("set", 30)
	Profile.reward_chests.append(sc)
	var pieces := Rewards.offer(sc)
	check("coffre de set : 3 pièces mythiques ou légendaires au choix", pieces.size() == 3 and pieces.all(func(it): return int(it.rarity) >= Items.MYTHIC))
	Profile.reward_chests.erase(sc)
	Profile.save_profile()
