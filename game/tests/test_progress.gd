extends Node
## Cycle roguelite : nouvelle partie, run, amélioration, objet gardé, rechargement.
## godot --headless --path game res://tests/test_progress.tscn  (profil de test uniquement)

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	# zone d'entraînement : la sauvegarde n'est jamais écrite, le compteur de DPS compte
	Profile.save_profile()
	var before_txt := FileAccess.get_file_as_string(Profile.save_path)
	Training.active = true
	var g_keep := Profile.selected_zone
	Profile.selected_zone = "zone_test_entrainement"
	Profile.save_profile()
	check("entraînement : sauvegarde non écrite", FileAccess.get_file_as_string(Profile.save_path) == before_txt)
	Training.reset_meter()
	Training.record(100.0)
	Training.record(50.0)
	check("entraînement : compteur de dégâts (150, DPS > 0)", is_equal_approx(Training.total, 150.0) and Training.dps() > 0.0)
	Training.active = false
	Profile.selected_zone = g_keep
	Profile.reset_all()
	var n_start := Profile.vault.size()
	check("nouvelle partie : équipement de départ (%d pièces), plus de trophée de départ" % n_start, n_start == StarterGear.SLOTS.size() and Profile.equipped.has("weapon") and not Profile.equipped.has("trophy"))
	var w_uid: String = Profile.equipped.weapon.uid
	Run.start("samurai")
	check("run : or et butin à zéro", Profile.gold == 0 and Profile.inventory.is_empty() and Profile.in_run)
	check("run : katana copié", Profile.equipped.weapon.uid == w_uid and not is_same(Profile.equipped.weapon, Profile.vault[0]))
	for i in 5:
		Profile.add_item(Items.generate(3, 0.5))
	Profile.gain({"gold": 5000, "crystal": 5})
	var w: Dictionary = Profile.equipped.weapon
	# fortification à la Eden : sans parchemin, rien ; parchemin consommé à chaque essai
	Profile.gain({"gold": 200000, "crystal": 50})
	var g_before := Profile.gold
	var r0 := Profile.upgrade_item(w)
	check("fortifier sans parchemin : refusé, rien payé", r0.get("error", false) and Profile.gold == g_before and int(w.upgrade) == 0)
	var low := Craft.fortify_key("power", 20)
	Profile.add_bag(low)
	var lvl_w := int(w.level)
	check("parchemin de puissance Lv20 : %s pour une arme niveau %d" % ["accepté" if lvl_w <= 20 else "refusé", lvl_w], Craft.fortify_fits(w, low) == (lvl_w <= 20))
	check("parchemin de garde refusé sur une arme", not Craft.fortify_fits(w, Craft.fortify_key("guard", 100)))
	Profile.take_bag(low)
	var scroll := Craft.fortify_key("power", 100)
	Profile.add_bag(scroll, 100)
	Profile.add_bag(Craft.stone_key("lucky"), 300)
	Profile.upgrade_item(w, Craft.stone_key("lucky"))
	check("+1 : parchemin consommé, pierre gardée (inutile avant +2)", int(w.upgrade) == 1 and Profile.bag_count(scroll) == 99 and Profile.bag_count(Craft.stone_key("lucky")) == 300)
	var tries := 1
	while int(w.upgrade) < 8 and tries < 100:
		Profile.upgrade_item(w, Craft.stone_key("lucky"))
		tries += 1
	check("katana amélioré en +8 (%d essais, protégé) : stats bonus aux paliers +4, +6, +8 seulement" % tries, int(w.upgrade) == 8 and (w.up_rolls as Array).size() == 3)
	check("stat aléatoire gagnée à chaque réussite", Items.stats(w).has(String(w.up_rolls[0][0])))
	# lot GX-2 : plus jamais de niveau perdu ; un échec remplit la persévérance (statistique sur 400 essais vers +6 et +10)
	var downs := 0
	var fails6 := 0
	for i in 400:
		var t := Items.generate(5, 0.0, "chest")
		t.upgrade = 5
		t["up_rolls"] = [["hp", 1.0], ["hp", 1.0], ["hp", 1.0], ["hp", 1.0], ["hp", 1.0]]
		var r := Craft.upgrade(t)
		if int(t.upgrade) < 5 or (t.up_rolls as Array).size() < 5:
			downs += 1
		if not bool(r.ok):
			fails6 += 1
		var t9 := Items.generate(5, 0.0, "chest")
		t9.upgrade = 9
		Craft.upgrade(t9)
		if int(t9.upgrade) < 9:
			downs += 1
	check("vers +6 et +10 sans pierre : aucune perte de niveau ni de stat bonus (%d), des échecs quand même (%d / 400)" % [downs, fails6], downs == 0 and fails6 > 80 and fails6 < 160)
	# pierres d'Eden : bonus et niveaux d'emploi
	var t9 := Items.generate(5, 0.0, "chest")
	t9.upgrade = 9
	check("pierre halcyon corail : +75 %% de +9 à +10 (%d %%)" % roundi(Craft.success_chance(t9, Craft.stone_key("coral")) * 100),
		absf(Craft.success_chance(t9, Craft.stone_key("coral")) - minf(1.0, Craft.UPGRADE_CHANCE[9] + 0.75)) < 0.001)
	check("pierre halcyon viridienne : inutilisable à +9", not Craft.stone_usable(t9, Craft.stone_key("viridian")))
	check("pierre sublime : 100 %", Craft.success_chance(t9, Craft.stone_key("sublime")) >= 1.0)
	check("parchemin de garde Lv20 : réussite assurée jusqu'à +5", Craft.fortify_safe("guard", 20) == 5 and Craft.fortify_safe("power", 70) == 2)
	# parchemin béni : gratuit (ni parchemin ni or)
	var tb := Items.generate(5, 0.0, "chest")
	tb.upgrade = 7
	Profile.add_bag(Craft.BLESSED, 30)
	var gb := Profile.gold
	var b_downs := 0
	for i in 30:
		tb.upgrade = 7
		Profile.upgrade_item(tb, "", true)
		if int(tb.upgrade) < 7:
			b_downs += 1
	check("parchemin béni : 30 essais sans or ni perte de niveau", Profile.gold == gb and b_downs == 0 and Profile.bag_count(Craft.BLESSED) == 0)
	check("anciennes pierres converties", Craft.migrate_bag({"luck": 2, "protect": 1}) == {"stone:lucky": 2, "stone:safety": 1})
	# joaillier : emplacements, gemmes, parchemins
	var armor := Items.generate(12, 0.0, "chest")
	armor["level"] = 40  # formule Lv2 : objet de niveau 35 minimum (niveau de l'objet, pas sa puissance)
	Profile.add_bag("drill", 20)
	while (armor.get("sockets", []) as Array).size() < 2 and Profile.bag_count("drill") > 0:
		Craft.drill(armor)
	check("2 emplacements percés", (armor.sockets as Array).size() == 2)
	var str_before := float(Items.stats(armor).get("str", 0.0))
	Profile.add_bag(Craft.gem_key("ruby", 2))
	Craft.insert_gem(armor, Craft.gem_key("ruby", 2), 0)
	check("rubis pur serti : +14 force", absf(float(Items.stats(armor).get("str", 0.0)) - str_before - 14.0) < 0.01)
	Profile.add_bag(Craft.scroll_key("muscle", 9))
	check("formule Lv9 (objets 70+) refusée sur un objet niveau 40", Craft.apply_scroll(armor, Craft.scroll_key("muscle", 9)) != "" and not armor.has("enchant"))
	Profile.add_bag(Craft.scroll_key("muscle", 2))
	Craft.apply_scroll(armor, Craft.scroll_key("muscle", 2))
	check("Explosion musculaire Lv2 (Eden : CRIT +9) : critique +1,35 %", armor.has("enchant") and absf(float(Craft.extra_stats(armor).get("crit", 0.0)) - 0.0135) < 0.0001)
	check("formule Lv4 : objets de niveau 45 (comme Eden)", Craft.enchant_min_level(4) == 45 and Craft.enchant_points("muscle", 4) == 11)
	var spent := {}
	for u in 8:
		var c := Items.upgrade_cost({"level": Items.power_level(w), "upgrade": u})
		for k in c:
			spent[k] = int(spent.get(k, 0)) + int(c[k])
	var refund := Items.upgrade_refund(w)
	print("  or dépensé ", spent, "  rendu ", refund)
	check("amélioration : de l'or seulement, la moitié rendue à la vente", spent.keys() == ["gold"] and int(refund.gold) == roundi(spent.gold * 0.5))
	var sv := Items.sell_value(w)
	check("vente : or (prix + or investi)", sv.keys() == ["gold"] and int(sv.gold) > int(refund.gold))
	var item: Dictionary = Profile.inventory[0]
	var before := Profile.amount("crystal")
	var got := Profile.disassemble(item)
	check("désassemblage : des cristaux", got.keys() == ["crystal"] and Profile.amount("crystal") == before + int(got.crystal) and Profile.inventory.size() == 4)
	var crystals_end := Profile.amount("crystal")
	Run.finish("defaite")
	Profile.end_run(w)
	check("fin de run : héritage mis à jour (+8), rien d'autre", Profile.vault.size() == n_start and int(Profile.vault.filter(func(it): return it.slot == "weapon")[0].upgrade) == 8)
	check("lobby : or et clés perdus, cristaux gardés", Profile.gold == 0 and Profile.keys == 0 and Profile.amount("crystal") == crystals_end)
	Run.start("samurai")
	var loot := Items.generate(4, 1.0, "head")
	Profile.add_item(loot)
	Run.finish("victoire")
	Profile.end_run(loot)
	check("nouvel objet gardé (le casque de départ reste porté)", Profile.vault.size() == n_start + 1 and Profile.vault.any(func(it): return it.uid == loot.uid) and Profile.equipped.has("head"))
	Profile.load_profile()
	check("rechargé du disque", Profile.vault.size() == n_start + 1 and int(Profile.equipped.weapon.upgrade) == 8 and Profile.runs_done == 2)
	# zones : la victoire débloque la suivante, la nouvelle partie remet à zéro
	check("une seule zone au départ", Profile.unlocked_zones >= 1 and Profile.zone_unlocked("limestone"))
	Profile.unlocked_zones = 1
	var next := Profile.unlock_after("limestone")
	check("victoire Limestone -> %s" % next, next != "" and Profile.zone_unlocked(GameData.zones[1].id) and not Profile.zone_unlocked(GameData.zones[2].id))
	check("rejouer une zone déjà battue ne débloque rien", Profile.unlock_after("limestone") == "")
	Profile.reset_all()
	check("nouvelle partie : zones verrouillées", Profile.unlocked_zones == 1 and Profile.selected_zone == "limestone")
	# expertise, talents, certificats
	check("expertise niveau 1 au départ, 2 points", Profile.expertise_level("warrior") == 1 and Profile.talent_points("warrior") == 2)
	var ups := Profile.add_expertise("warrior", 1200)
	check("1200 points d'expertise -> %d niveaux" % ups, ups == 3 and Profile.talent_points("warrior") == 2 * Profile.expertise_level("warrior"))
	check("talent de 1re colonne disponible", Profile.add_talent("warrior", 52582) and Profile.talent_rank("warrior", 52582) == 1)
	check("talent avec prérequis bloqué", Profile.talent_block("warrior", 54699) != "")
	Run.start("warrior")
	check("talent appliqué en run (+1 % déf)", absf(float(Run.passive_stats().get("def_pct", 0.0)) - 0.01) < 0.0001)
	check("certificat Guerrier débloqué (niv. 3)", Profile.unlocked_certificates().any(func(c): return c.key == "warrior/unshakable"))
	Profile.toggle_certificate("warrior/unshakable")
	check("certificat équipé appliqué (+20 % PV)", absf(float(Run.passive_stats().get("hp_pct", 0.0)) - 0.2) < 0.0001)
	check("certificat posé : jamais proposé en carte", not Run.certificate_pool().any(func(d): return d.cert == "warrior/unshakable"))
	Profile.toggle_certificate("warrior/unshakable")
	check("certificat retiré du plateau : il peut tomber en run", Run.certificate_pool().any(func(d): return d.cert == "warrior/unshakable"))
	Profile.toggle_certificate("warrior/unshakable")
	Run.finish("defaite")
	Profile.end_run(null)
	Profile.reset_all()
	check("nouvelle partie : expertise remise à zéro", Profile.expertise.is_empty() and Profile.certificates.is_empty())
	# arme principale = arme de la classe ; un autre type = arme secondaire (0.1.128)
	Profile.selected_class = "magician"
	Profile.select_weapon_type("axe")
	check("magicien à la hache : hache en arme secondaire, bâton en principale", Items.weapon_type_of(Profile.equipped.get("offhand", {})) == "axe"
		and Items.weapon_type_of(Profile.equipped.weapon) == "staff")
	Run.start("magician")
	check("en run : l'arme principale reste celle de la classe", Run.weapon_type() == "staff")
	var loot_w := Items.generate(4, 0.0, "weapon", "magician")
	check("le butin d'armes suit l'arme de la classe (objet d'Eden : %s)" % loot_w.name, Items.weapon_type_of(loot_w) == "staff" and GameData.eden_by_id.get(int(loot_w.get("eden", 0)), {}).get("wtype", "") == "staff")
	check("ancienne arme sans type : type de sa classe", Items.weapon_type_of({"slot": "weapon", "wclass": "hunter"}) == "bow")
	# extraction : tout l'inventaire est gardé
	for i in 4:
		Profile.add_item(Items.generate(5, 0.5))
	var n_before := Profile.vault.size()
	var n_worn := Profile.equipped.size()
	Run.finish("extraction")
	var kept := Profile.end_run_extract()
	check("extraction : %d objets gardés" % kept, kept == n_worn + 4 and Profile.vault.size() == n_before + 4 and not Profile.in_run)
	check("extraction : les armes portées restent en place", Items.weapon_type_of(Profile.equipped.weapon) == "staff"
		and Items.weapon_type_of(Profile.equipped.get("offhand", {})) == "axe")
	# fournitures : gardées par l'extraction, emportées à la run suivante, perdues à la mort
	Run.start("magician")
	Profile.add_bag("drill", 2)
	Profile.add_bag(Craft.gem_key("ruby", 1))
	Run.finish("extraction")
	Profile.end_run_extract()
	var potions := func(): return int(Profile.stash.get("potion:heal", 0))  # les 2 potions de soin de départ reviennent aussi en réserve
	check("extraction : fournitures en réserve", Profile.stash_count() - potions.call() == 3 and Profile.bag.is_empty())
	Run.start("magician")
	check("nouvelle run : la réserve part dans le sac", Profile.bag_count("drill") == 2 and Profile.stash_count() == 0 and Profile.bag_count("potion:heal") >= Potions.START_HEAL)
	Run.finish("defaite")
	Profile.end_run(null)
	check("mort : fournitures emportées perdues", Profile.stash_count() == 0)
	Run.start("magician")
	Profile.add_bag(Craft.stone_key("lucky"), 1)
	Run.finish("victoire")
	Profile.end_run(null)
	check("victoire : fournitures en réserve", Profile.stash.get(Craft.stone_key("lucky"), 0) == 1)
	Profile.reset_all()
	check("nouvelle partie : réserve vidée", Profile.stash_count() == 0)
	print("échecs : ", fails)
	get_tree().quit(fails)
