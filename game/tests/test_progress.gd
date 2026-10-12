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
	Profile.reset_all()
	check("nouvelle partie : 1 katana d'héritage", Profile.vault.size() == 1 and Profile.equipped.has("weapon"))
	var w_uid: String = Profile.equipped.weapon.uid
	Run.start("samurai")
	check("run : or et butin à zéro", Profile.gold == 0 and Profile.inventory.is_empty() and Profile.in_run)
	check("run : katana copié", Profile.equipped.weapon.uid == w_uid and not is_same(Profile.equipped.weapon, Profile.vault[0]))
	for i in 5:
		Profile.add_item(Items.generate(3, 0.5))
	Profile.gain({"gold": 5000, "fragment": 200, "essence": 50, "crystal": 5})
	var w: Dictionary = Profile.equipped.weapon
	# amélioration à risque : avec 3 pierres de chance et une protection à chaque essai
	Profile.gain({"gold": 200000, "fragment": 5000, "essence": 500, "crystal": 50})
	Profile.add_bag("luck", 300)
	Profile.add_bag("protect", 100)
	var tries := 0
	while int(w.upgrade) < 8 and tries < 100:
		Profile.upgrade_item(w, 3, true)
		tries += 1
	check("katana amélioré en +8 (%d essais, protégé)" % tries, int(w.upgrade) == 8 and (w.up_rolls as Array).size() == 8)
	check("stat aléatoire gagnée à chaque réussite", Items.stats(w).has(String(w.up_rolls[0][0])))
	# échecs sans protection : l'objet peut redescendre (statistique sur 400 essais vers +6)
	var downs := 0
	var protected_downs := 0
	for i in 400:
		var t := Items.generate(5, 0.0, "chest")
		t.upgrade = 5
		t["up_rolls"] = [["hp", 1.0], ["hp", 1.0], ["hp", 1.0], ["hp", 1.0], ["hp", 1.0]]
		var r := Craft.upgrade(t, 0, false)
		if int(t.upgrade) == 4:
			downs += 1
		var t2 := Items.generate(5, 0.0, "chest")
		t2.upgrade = 5
		Craft.upgrade(t2, 0, true)
		if int(t2.upgrade) == 4:
			protected_downs += 1
	check("vers +6 sans protection : ~30 %% de pertes de niveau (%d / 400)" % downs, downs > 80 and downs < 160)
	check("pierre de protection : aucune perte (%d)" % protected_downs, protected_downs == 0)
	# joaillier : emplacements, gemmes, parchemins
	var armor := Items.generate(12, 0.0, "chest")
	Profile.add_bag("drill", 20)
	while (armor.get("sockets", []) as Array).size() < 2 and Profile.bag_count("drill") > 0:
		Craft.drill(armor)
	check("2 emplacements percés", (armor.sockets as Array).size() == 2)
	var str_before := float(Items.stats(armor).get("str", 0.0))
	Profile.add_bag(Craft.gem_key("ruby", 2))
	Craft.insert_gem(armor, Craft.gem_key("ruby", 2), 0)
	check("rubis pur serti : +14 force", absf(float(Items.stats(armor).get("str", 0.0)) - str_before - 14.0) < 0.01)
	Profile.add_bag(Craft.scroll_key("violence", 1))
	check("parchemin d'arme refusé sur une armure", Craft.apply_scroll(armor, Craft.scroll_key("violence", 1)) != "" and not armor.has("enchant"))
	Profile.add_bag(Craft.scroll_key("rehab", 2))
	Craft.apply_scroll(armor, Craft.scroll_key("rehab", 2))
	check("enchantement Rééducation Lv2 : +100 PV", armor.has("enchant") and absf(float(Craft.extra_stats(armor).get("hp", 0.0)) - 100.0) < 0.01)
	check("parchemin Lv5 refusé sur un objet niveau 12", Craft.can_enchant(armor, Craft.scroll_key("rehab", 5)) != "")
	var spent := {}
	for u in 8:
		var c := Items.upgrade_cost({"level": int(w.level), "upgrade": u})
		for k in c:
			spent[k] = int(spent.get(k, 0)) + int(c[k])
	var refund := Items.upgrade_refund(w)
	print("  pierres dépensées ", spent, "  rendues ", refund)
	check("remboursement 70 % des pierres", int(refund.fragment) == roundi(spent.fragment * 0.7) and not refund.has("gold"))
	var sv := Items.sell_value(w)
	check("vente : or + pierres", sv.has("gold") and int(sv.fragment) == int(refund.fragment))
	var item: Dictionary = Profile.inventory[0]
	var before := int(Profile.materials.fragment)
	var got := Profile.disassemble(item)
	check("désassemblage crédité", int(Profile.materials.fragment) == before + int(got.fragment) and Profile.inventory.size() == 4)
	Run.finish("defaite")
	Profile.end_run(w)
	check("fin de run : héritage mis à jour (+8), rien d'autre", Profile.vault.size() == 1 and int(Profile.vault[0].upgrade) == 8)
	check("lobby : or et matériaux remis à zéro", Profile.gold == 0 and int(Profile.materials.fragment) == 0)
	Run.start("samurai")
	var loot := Items.generate(4, 1.0, "head")
	Profile.add_item(loot)
	Run.finish("victoire")
	Profile.end_run(loot)
	check("nouvel objet gardé et porté (emplacement libre)", Profile.vault.size() == 2 and Profile.equipped.has("head"))
	Profile.load_profile()
	check("rechargé du disque", Profile.vault.size() == 2 and int(Profile.equipped.weapon.upgrade) == 8 and Profile.runs_done == 2)
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
	check("les certificats ne sont plus des cartes", not Run.roll_cards(30).any(func(c): return str(c.id) == "unshakable"))
	Run.finish("defaite")
	Profile.end_run(null)
	Profile.reset_all()
	check("nouvelle partie : expertise remise à zéro", Profile.expertise.is_empty() and Profile.certificates.is_empty())
	# armes indépendantes de la classe
	Profile.selected_class = "magician"
	Profile.select_weapon_type("axe")
	check("magicien à la hache : arme de départ créée", Items.weapon_type_of(Profile.equipped.weapon) == "axe")
	Run.start("magician")
	check("en run : le combo suit l'arme", Run.weapon_type() == "axe" and GameData.weapon_type(Run.weapon_type()).combo[0].name == "Coup de hache")
	var loot_w := Items.generate(4, 0.0, "weapon", "magician")
	check("le butin d'armes suit l'arme en main", Items.weapon_type_of(loot_w) == "axe" and String(loot_w.name).begins_with("Hache"))
	check("ancienne arme sans type : type de sa classe", Items.weapon_type_of({"slot": "weapon", "wclass": "hunter"}) == "bow")
	# extraction : tout l'inventaire est gardé
	for i in 4:
		Profile.add_item(Items.generate(5, 0.5))
	var n_before := Profile.vault.size()
	Run.finish("extraction")
	var kept := Profile.end_run_extract()
	check("extraction : %d objets gardés" % kept, kept == 5 and Profile.vault.size() == n_before + 4 and not Profile.in_run)
	check("extraction : l'arme portée reste l'arme de départ", Items.weapon_type_of(Profile.equipped.weapon) == "axe")
	# fournitures : gardées par l'extraction, emportées à la run suivante, perdues à la mort
	Run.start("magician")
	Profile.add_bag("drill", 2)
	Profile.add_bag(Craft.gem_key("ruby", 1))
	Run.finish("extraction")
	Profile.end_run_extract()
	check("extraction : fournitures en réserve", Profile.stash_count() == 3 and Profile.bag.is_empty())
	Run.start("magician")
	check("nouvelle run : la réserve part dans le sac", Profile.bag_count("drill") == 2 and Profile.stash_count() == 0)
	Run.finish("defaite")
	Profile.end_run(null)
	check("mort : fournitures emportées perdues", Profile.stash_count() == 0)
	Run.start("magician")
	Profile.add_bag("luck", 1)
	Run.finish("victoire")
	Profile.end_run(null)
	check("victoire : fournitures en réserve", Profile.stash.get("luck", 0) == 1)
	Profile.reset_all()
	check("nouvelle partie : réserve vidée", Profile.stash_count() == 0)
	print("échecs : ", fails)
	get_tree().quit(fails)
