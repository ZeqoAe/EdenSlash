extends Node
## Lot E4 (nuit du 15/10) : capes dans les coffres d'emplacement de la Survie, armes de tous les types
## découvertes avec une arme choisie (Armurerie), fournitures au niveau des pièces de la carte d'époque :
## godot --headless --path game res://tests/test_e4.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(HeroLevel.MAX_LEVEL)  # lot H3 : niveau 90, toutes les pièces se portent

	# --- capes (A6) -----------------------------------------------------------------------------------
	check("coffre de cape", SlotChests.BOXES.has("back") and SlotChests.title("back") == "Coffre de cape")
	check("30 coffres par carte, dont 2 de cape", SlotChests.LAYOUT.size() == ProcMap.CHEST_COUNT and SlotChests.LAYOUT.count("back") == 2)
	check("4 coffres de trophée (12 trophées par run)", SlotChests.LAYOUT.count("trophy") * 3 >= Run.MAX_TROPHIES)
	var capes_ok := true
	for ep in range(1, Epochs.count() + 1):
		for st in range(1, 4):
			var p := SlotChests.pool("back", ep, st)
			var m := Epochs.map_def(ep, st)
			if p.is_empty() or not p.all(func(e): return String(e.slot) == "back" and int(e.rarity) == int(m.rarity)):
				capes_ok = false
				print("      pas de cape : époque %d carte %d" % [ep, st])
	check("une cape mythique ou légendaire sur les 12 cartes", capes_ok)
	var offer := SlotChests.offer("back", 2, 1)
	check("coffre de cape : 3 capes à +0", offer.size() == 3 and offer.all(func(it): return String(it.slot) == "back" and int(it.upgrade) == 0))
	check("les capes comptent dans l'Armurerie", Completion.armory_ids().has(int(SlotChests.pool("back", 1, 1)[0].id)))
	var with_cape := StarterGear.scenario("2.3.10.4", "warrior")
	check("mesures : équipement optimisé avec cape (9 pièces), « .0 » sans", with_cape.has("back") and with_cape.size() == 9 \
		and not StarterGear.scenario("2.3.10.4.0", "warrior").has("back"))
	var no_cape := with_cape.duplicate()
	no_cape.erase("back")
	var pe_gain := float(GearPower.hero_power(with_cape)) / maxf(float(GearPower.hero_power(no_cape)), 1.0) - 1.0
	print("      PE optimisée de l'époque II : %d sans cape, %d avec (+%d %%)" % [GearPower.hero_power(no_cape), GearPower.hero_power(with_cape), roundi(pe_gain * 100.0)])
	check("une cape ajoute de 5 à 20 % de PE", pe_gain > 0.05 and pe_gain < 0.2)

	# --- les types d'arme (B3) ------------------------------------------------------------------------------
	var types := SlotChests.weapon_types()
	print("      types : %s" % [types])
	var class_types := {}
	for cid in GameData.classes:
		class_types[Items.default_weapon_type(String(cid))] = true
	check("chaque type d'arme des pièces est celui d'une classe (%d types)" % types.size(), types.size() >= 16 and types.all(func(t): return class_types.has(t)))
	var all_types_ok := true
	var per_map: PackedStringArray = []
	var all_seen := {}
	for ep in range(1, Epochs.count() + 1):
		for st in range(1, 4):
			var fam := SlotChests.weapon_family(ep, st)
			var m := Epochs.map_def(ep, st)
			var seen_types := {}
			for id in fam:
				var e: Dictionary = GameData.eden_by_id.get(int(id), {})
				if String(e.get("slot", "")) != "weapon" or int(e.rarity) != int(m.rarity) or absi(int(e.level) - int(m.weapon)) > SlotChests.POOL_WINDOW:
					all_types_ok = false
					print("      arme hors palier : %s (%d, rareté %d) époque %d carte %d" % [e.get("name", id), int(e.get("level", 0)), int(e.get("rarity", 0)), ep, st])
				seen_types[String(e.get("wtype", ""))] = true
				all_seen["%s:%d" % [e.get("wtype", ""), int(e.rarity)]] = true
			per_map.append("%d.%d:%d" % [ep, st, seen_types.size()])
			if seen_types.size() < 8:
				all_types_ok = false
	print("      types découverts par carte : %s" % " ".join(per_map))
	check("famille d'armes : à la rareté et au palier de la carte, 8 types au moins par carte", all_types_ok)
	var full := 0
	for t in types:
		if all_seen.has("%s:%d" % [t, Items.MYTHIC]) and all_seen.has("%s:%d" % [t, Items.LEGENDARY]):
			full += 1
	check("chaque type a une arme mythique et une légendaire à découvrir en Survie (%d / %d)" % [full, types.size()], full >= types.size() - 1)
	var off := SlotChests.offhand_offer(1, 1)
	check("arme secondaire : tirée comme un coffre d'arme de son type", off.size() == 3 and off.all(func(it): \
		return int(it.eden) in SlotChests.pool("weapon", 1, 1, Items.weapon_type_of(it)).map(func(e): return int(e.id))))

	# en run : une arme choisie fait découvrir les armes de tous les types
	Profile.seen_gear = []
	Run.start_survival("warrior", 1)
	var weapon: Dictionary = SlotChests.offer("weapon", 1, 1)[0]
	Run.apply_card({"type": "gear", "item": weapon})
	check("arme choisie : %d armes découvertes" % Run.seen_family.size(), Run.seen_family.size() >= 15)
	Run.kills = 20
	Run.finish("defaite")
	Profile.end_run_survival()
	var sword: Dictionary = {}
	for id in Profile.seen_gear:
		var e: Dictionary = GameData.eden_by_id.get(int(id), {})
		if String(e.get("wtype", "")) == "sword":
			sword = e
	check("fin de run : une épée est à l'Armurerie pour un guerrier (hache)", not sword.is_empty() and Items.default_weapon_type("warrior") != "sword")
	# achetée, elle sert d'arme principale à une classe d'épée et d'arme secondaire à toute autre classe
	var bought := GearShopPage.make(sword)
	Profile.add_item(bought)
	Profile.equip(bought)
	check("guerrier : l'épée devient l'arme secondaire", is_same(Profile.equipped.get("offhand"), bought) and Items.weapon_type_of(Profile.equipped.weapon) == "axe")
	var sword_class := ""
	for cid in GameData.classes:
		if Items.default_weapon_type(String(cid)) == "sword":
			sword_class = String(cid)
			break
	check("classe d'épée (%s) : la même épée peut être son arme principale" % sword_class, sword_class != "" and Profile._main_weapon_ok(String(bought.uid), sword_class))

	# --- fournitures au niveau de la carte (A1 b) ---------------------------------------------------------
	var d := RunDirector.new()
	Run.start_survival("warrior", 1)
	var fits := true
	var report: PackedStringArray = []
	for ep in range(1, Epochs.count() + 1):
		Run.epoch = ep
		var top := 0  # parchemin le plus haut de l'époque
		var pieces: Array = []
		for st in range(1, 4):
			Run.stage = st
			var flv := Craft.fortify_level_at(d.supply_level(1))
			top = maxi(top, flv)
			report.append("%d.%d→%d" % [ep, st, flv])
			var m := Epochs.map_def(ep, st)
			# pièces au palier de la carte ou en dessous (une pièce prise au-dessus, faute de mieux pour son type,
			# attend les parchemins de l'époque suivante)
			for box in ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "jewel"]:
				pieces.append_array(SlotChests.pool(box, ep, st).filter(func(e): return int(e.level) <= maxi(int(m.armor), int(m.weapon))))
			pieces.append_array(SlotChests.weapon_family(ep, st).map(func(id): return GameData.eden_by_id[int(id)]).filter(func(e): return int(e.level) <= int(m.weapon)))
		for e in pieces:
			if int(e.level) > top:
				fits = false
				print("      %s (niveau %d) : parchemins de l'époque %d trop bas (%d)" % [e.name, int(e.level), ep, top])
	print("      parchemins de fortification par carte : %s" % " ".join(report))
	check("parchemins de fortification de chaque époque : assez hauts pour ses pièces de l'Armurerie", fits)
	Run.epoch = 4
	Run.stage = 3
	var drops := {}
	var lv90 := true
	for i in 400:
		var k := Craft.loot_for("crate", d.supply_level(1), 0, d.gem_level(1))
		drops[k.get_slice(":", 0)] = int(drops.get(k.get_slice(":", 0), 0)) + 1
		if k.begins_with("fortify:") and int(k.get_slice(":", 2)) != 90:
			lv90 = false
	check("époque IV carte 3 : parchemins de niveau 90 (pièces 80-90), plus de plafond à 40", lv90 and int(drops.get("fortify", 0)) > 100)
	check("autel du scribe de l'époque IV : formules de niveau 9", Craft.scroll_level_for(d.supply_level(1)) == Craft.MAX_SCROLL_LV)
	Run.epoch = 1
	Run.stage = 1
	var hl_was := Run.hero_level
	Run.hero_level = 1  # lot H4a : le rang des gemmes suit la place du héros dans la bande de la carte
	var gem_e1 := d.gem_level(1)
	Run.epoch = 3
	check("gemmes : un rang de plus par époque (héros niveau 1 : %d en époque I, %d en III)" % [gem_e1, d.gem_level(1)],
		gem_e1 == 1 and d.gem_level(1) == 1 + 2 * RunDirector.GEM_EPOCH_LEVELS)
	Run.hero_level = hl_was
	Run.survival = false
	check("hors Survie : fournitures au niveau du butin, comme avant", d.supply_level(12) == d.loot_level(12) and d.gem_level(12) == d.loot_level(12))
	d.free()
	Run.finish("abandon")
	Profile.end_run_survival()

	Profile.reset_all()
	print("\n%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
