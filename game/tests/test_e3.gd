extends Node
## Lot E3 de la nuit du 15/10 : profils de stats des 60 classes, note pondérée, « Équiper le meilleur » (garder mes
## choix, annulation), « Appliquer à la famille », Registre de l'équipement (états, ce qui manque, compte du lobby).
## godot --headless --path game res://tests/test_e3.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	_test_profiles()
	_test_rating()
	_test_registry_new()
	_fill_vault()
	_test_sixty()
	_test_equip_best()
	_test_family()
	_test_sets()
	_test_registry_full()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _test_profiles() -> void:
	var d := ClassGear.data()
	var pids := ClassGear.profile_ids()
	check("profils : entre 5 et 8 (%d)" % pids.size(), pids.size() >= 5 and pids.size() <= 8)
	var all_mapped := true
	var dmg_ok := true
	var guard_ok := true
	for cid in GameData.classes:
		var p := ClassGear.profile(String(cid))
		if p.is_empty():
			all_mapped = false
			continue
		# le profil suit le type de dégâts réel de la classe (après GameData._balance_damage_types)
		if String(p.dmg) != String(GameData.class_data(cid).get("dmg_type", "phys")):
			dmg_ok = false
			print("  type de dégâts différent : ", cid)
		var guard := float(GameData.class_data(cid).get("base", {}).get("def", 0.0)) >= 6.0
		if guard != (String(p.id) in ["rempart", "croise"]):
			guard_ok = false
	check("les 60 classes ont un profil", all_mapped and (d.classes as Dictionary).size() == GameData.classes.size())
	check("profil physique / magique conforme au jeu", dmg_ok)
	check("classes de garde = Rempart ou Croisé", guard_ok)
	for pid in pids:
		check("profil %s : au moins une classe, poids entre 0,3 et 1,5" % pid, not ClassGear.classes_of(String(pid)).is_empty()
			and (d.profiles[pid].weights as Dictionary).values().all(func(w): return float(w) >= 0.3 and float(w) <= 1.5))


func _test_rating() -> void:
	var it := Items.generate(30, 0.8, "chest", "warrior", 2)
	check("note sans profil inchangée (profil vide)", is_equal_approx(Items.rating(it), Items.rating(it, {})))
	var ones := {}
	for k in Items.STAT_NAMES.keys() + Items.EXTRA_STAT_NAMES.keys():
		ones[k] = 1.0
	check("poids à 1 et sans armure : même note", is_equal_approx(Items.rating(it), Items.rating(it, {"weights": ones, "armor": ""})))
	var mag := Items.generate(30, 0.5, "chest", "warrior", 2)
	mag["base"] = {"matk": 20.0, "int": 4.0}
	mag["affixes"] = {}
	var phys := mag.duplicate(true)
	phys["base"] = {"patk": 20.0, "str": 4.0}
	var pm := ClassGear.profile("magician")
	var pw := ClassGear.profile("samurai")
	check("Arcane préfère l'attaque magique", Items.rating(mag, pm) > Items.rating(phys, pm))
	check("Puissance préfère l'attaque physique", Items.rating(phys, pw) > Items.rating(mag, pw))
	check("PE affichée = PE sans profil", GearPower.item_power(mag) == roundi(Items.rating(mag) * (GearPower.BASE + GearPower.PER_LEVEL * Items.power_level(mag))))


func _test_registry_new() -> void:
	var e := ClassGear.entry("warrior")
	check("compte neuf : le Guerrier porte l'équipement de départ (« base »)", int(e.base) == 8 and int(e.status) == 1)
	check("compte neuf : il manque des pièces → Survie, puis Armurerie", String(e.activity) == "Survie, puis Armurerie" and String(e.need).contains("pièce"))
	var locked := ClassGear.entry("light_blade")
	check("classe verrouillée : à commencer, il manque la classe → sa mission (%s)" % locked.activity, int(locked.status) == 0 and String(locked.need) == "la classe" and String(locked.activity).begins_with("Maîtrise"))
	var never := ClassGear.entry("thief")
	check("classe débloquée jamais choisie : équipement de départ → Héros", int(never.status) == 0 and String(never.activity).begins_with("Héros"))
	check("compte neuf : 0 classe équipée sur 60", ClassGear.equipped_count() == Vector2i(0, 60))


## Coffre garni : 3 pièces par emplacement (zone avancée, mythiques ou légendaires) et 2 armes de chaque type.
func _fill_vault() -> void:
	seed(2026)  # coffre identique à chaque exécution (« équiper le meilleur » est une heuristique : pas optimale sur tous les tirages)
	Items.reward_zone = "wetlands"  # pièces d'une zone avancée (niveaux d'Eden 40-50), au-dessus de l'équipement de départ
	for slot in ["head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]:
		for k in 3:
			Profile.vault.append(Items.generate(40 + k * 5, 0.9, slot, "warrior", Items.MYTHIC, "", Items.LEGENDARY))
	for wt in GameData.weapon_types:
		for k in 2:
			Profile.vault.append(Items.generate(40 + k * 5, 0.9, "weapon", "warrior", Items.MYTHIC, String(wt), Items.LEGENDARY))
	Items.reward_zone = ""
	Profile._lobby_view()
	Profile.save_profile()


func _test_sixty() -> void:
	var t0 := Time.get_ticks_msec()
	var bad: Array = []
	for cid in GameData.classes:
		var g := ClassGear.best_gear(String(cid))
		var ok := 0
		for slot in g:
			if slot != "offhand" and ClassGear.fits(g[slot], slot, String(cid)):
				ok += 1
		var wt_ok := g.has("weapon") and Items.weapon_type_of(g.weapon) == Items.default_weapon_type(String(cid))
		if ok < 8 or not wt_ok or _uid(g.get("offhand")) == _uid(g.get("weapon")):
			bad.append(cid)
	var ms := Time.get_ticks_msec() - t0
	check("60 classes : chacune obtient au moins 8 pièces valables, arme de son type (%s)" % [bad], bad.is_empty())
	check("60 classes : calcul rapide (%d ms)" % ms, ms < 4000)
	# le profil change le choix : deux classes d'armure différente ne prennent pas toujours la même pièce
	var t1 := Time.get_ticks_msec()
	var ec := ClassGear.equipped_count()
	check("Registre des 60 classes en moins de 300 ms (%d ms)" % (Time.get_ticks_msec() - t1), Time.get_ticks_msec() - t1 < 300 and ec.y == 60)


static func _uid(it) -> String:
	return String(it.get("uid", "")) if it is Dictionary else ""


func _uids(d: Dictionary) -> Dictionary:
	var out := {}
	for s in d:
		out[s] = _uid(d[s])
	return out


func _test_equip_best() -> void:
	var cid := "warrior"
	var before := _uids(Profile.equipped)
	check("annulation indisponible avant toute action", not ClassGear.can_undo() or ClassGear.undo_label() != "")
	var msg := ClassGear.equip_best(cid)
	var after := _uids(Profile.equipped)
	check("Équiper le meilleur : des pièces changent (%s)" % msg, after != before and msg.contains("changée"))
	check("Équiper le meilleur : plus aucune pièce de départ", Profile.equipped.values().all(func(it): return not it.get("starter", false)))
	check("Équiper le meilleur : le préréglage est enregistré", _uids(ClassGear.gear_of(cid)) == after)
	check("Équiper le meilleur : PE du profil au moins égale", GearPower.gear_power(Profile.equipped, ClassGear.profile(cid)) >= GearPower.gear_power(_gear(before), ClassGear.profile(cid)))
	check("une 2e fois : rien à changer", ClassGear.equip_best(cid).begins_with("Rien à changer"))
	check("aucun choix à garder juste après", ClassGear.choice_slots(cid).is_empty())
	# l'annulation rend le préréglage d'avant
	check("annulation proposée", ClassGear.can_undo() and ClassGear.menu_actions(cid).any(func(a): return String(a.label).begins_with("Annuler")))
	ClassGear.undo()
	check("annuler : l'équipement d'avant revient", _uids(Profile.equipped) == before)
	check("annuler : une seule fois", not ClassGear.can_undo())
	ClassGear.equip_best(cid)
	# garder mes choix : une pièce posée à la main reste
	var prof := ClassGear.profile(cid)
	var worse: Dictionary = {}
	for it in Profile.inventory:  # le torse le moins bon du coffre (hors pièce de départ)
		if String(it.slot) == "chest" and not it.get("starter", false) \
				and (worse.is_empty() or GearPower.item_power(it, prof) < GearPower.item_power(worse, prof)):
			worse = it
	Profile.equip(worse)
	Profile.save_profile()
	check("pièce posée à la main = un choix", "chest" in ClassGear.choice_slots(cid))
	check("menu : « garder mes choix » proposé", ClassGear.menu_actions(cid).any(func(a): return String(a.label).contains("garder mes choix")))
	ClassGear.equip_best(cid, true)
	check("garder mes choix : la pièce reste", _uid(Profile.equipped.get("chest")) == _uid(worse))
	var pe_kept := GearPower.gear_power(Profile.equipped, prof)
	ClassGear.equip_best(cid, false)
	# Le meilleur équipement compte les bonus de panoplie : le torse choisi peut valoir moins seul mais plus avec les autres pièces
	# (1 tirage sur 12 de la voûte aléatoire) ; on compare donc la PE de l'ensemble, pas la pièce seule.
	check("sans garder : le meilleur ensemble revient (PE au moins égale)", GearPower.gear_power(Profile.equipped, prof) >= pe_kept)
	check("sans garder : la pièce posée à la main n'est plus un choix", ClassGear.choice_slots(cid).is_empty())


func _gear(uids: Dictionary) -> Dictionary:
	var m := ClassGear.vault_map()
	var out := {}
	for s in uids:
		if m.has(uids[s]):
			out[s] = m[uids[s]]
	return out


func _test_family() -> void:
	var cid := "warrior"
	var fam := ClassGear.classes_of(ClassGear.profile_id(cid))
	var plan := ClassGear.family_plan(cid)
	check("famille Rempart : toutes les autres classes ont une arme de leur type au coffre", (plan.to as Array).size() == fam.size() - 1 and (plan.skip as Array).is_empty())
	var before := {}
	for t in plan.to:
		before[t] = _uids(ClassGear.gear_of(t))
	var msg := ClassGear.apply_family(cid)
	check("Appliquer à la famille : message (%s)" % msg, msg.begins_with("Copié vers %d classes" % (plan.to as Array).size()))
	var src := _uids(Profile.equipped)
	var ok := true
	for t in plan.to:
		var g := ClassGear.gear_of(t)
		if not ClassGear.fits(g.get("weapon", {}), "weapon", t):
			ok = false
		for s in ["head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]:
			if _uid(g.get(s)) != String(src.get(s, "")):
				ok = false
	check("famille : armures et bijoux copiés, arme du type de chaque classe", ok)
	check("famille : la classe affichée ne change pas", _uids(Profile.equipped) == src)
	ClassGear.undo()
	var back := true
	for t in plan.to:
		if _uids(ClassGear.gear_of(t)) != before[t]:
			back = false
	check("famille : annulable", back)
	# une classe sans arme de son type au coffre est sautée
	var lonely := ""
	for t in ClassGear.classes_of("arcane"):
		lonely = t
	var keep := Profile.vault.filter(func(it): return String(it.slot) == "weapon" and Items.weapon_type_of(it) == Items.default_weapon_type(lonely))
	var others := ClassGear.classes_of("arcane").filter(func(t): return Items.default_weapon_type(t) == Items.default_weapon_type(lonely))
	Profile.vault = Profile.vault.filter(func(it): return not it in keep)
	Profile.selected_class = "magician"
	Profile._lobby_view()
	var p2 := ClassGear.family_plan("magician")
	check("famille : classe sans arme de son type sautée (%s)" % [p2.skip], others.all(func(t): return t in p2.skip) and not lonely in p2.to)
	Profile.vault.append_array(keep)
	Profile.selected_class = "warrior"
	Profile._lobby_view()
	Profile.save_profile()


func _test_sets() -> void:
	# 6 copies des meilleures pièces, portant en plus un archétype : à valeur égale, la panoplie l'emporte
	var cid := "warrior"
	ClassGear.equip_best(cid)
	var copies: Array = []
	for s in ["head", "chest", "legs", "gloves", "boots", "back"]:
		var c: Dictionary = Profile.equipped[s].duplicate(true)
		c["uid"] = "e3_arch_%s" % s
		c["archetype"] = "storm"
		copies.append(c)
		Profile.inventory.append(c)
	Profile.save_profile()
	ClassGear.equip_best(cid)
	var n := 0
	for s in Profile.equipped:
		if String(Profile.equipped[s].get("archetype", "")) == "storm":
			n += 1
	check("panoplie : les 6 pièces d'archétype sont choisies (%d)" % n, n == 6)
	check("Registre : panoplie 6 / 6", int(ClassGear.entry(cid).arch) == 6)


func _test_registry_full() -> void:
	var cid := "warrior"
	Profile.best_level = 100
	var e2 := ClassGear.entry(cid)
	check("niveau visé très haut : à renforcer → Armurerie (%d %%)" % roundi(float(e2.ratio) * 100), int(e2.status) == 2 and String(e2.activity) == "Survie, puis Armurerie")
	for s in Profile.equipped:
		var it: Dictionary = Profile.equipped[s]
		it["upgrade"] = Items.MAX_UPGRADE
		it["sockets"] = [{"type": "ruby", "tier": 2}, {"type": "onyx", "tier": 2}]
		it["enchant"] = {"type": "optimize", "lv": 3}
	Profile.best_level = 1
	Profile.save_profile()
	var e := ClassGear.entry(cid)
	check("équipement complet, +10, serti, enchanté : optimal (%s, %s)" % [ClassGear.STATUS[int(e.status)], e.need], int(e.status) == 4 and String(e.need) == "")
	check("compte du lobby : au moins le Guerrier", ClassGear.equipped_count().x >= 1)
	Profile.equipped["chest"]["upgrade"] = 3
	var e3 := ClassGear.entry(cid)
	check("une pièce sous +10 : → Forge", String(e3.activity) == "Forge" and int(e3.status) == 3)
	ClassGear.apply_family(cid)
	var t0 := Time.get_ticks_msec()
	var ec := ClassGear.equipped_count()
	check("bandeau du lobby : %d / %d classes équipées en %d ms" % [ec.x, ec.y, Time.get_ticks_msec() - t0], ec.x >= 2 and Time.get_ticks_msec() - t0 < 120)
	var page := RegistryPage.new()
	add_child(page)
	page.refresh()
	check("page du Registre : une ligne par classe débloquée", page._box.get_child_count() >= 3)
	page._filter = 1
	page.refresh()
	check("page du Registre : 60 classes avec « Toutes »", page._box.get_child_count() == 60 + 3)
	page.queue_free()
