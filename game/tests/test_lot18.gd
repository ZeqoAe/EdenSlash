extends Node
## Panoplies-archétypes des donjons, Fabrication des plans, Ruée des boss.
## godot --headless --path game res://tests/test_lot18.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	# --- archétypes
	check("8 donjons, 8 archétypes différents, tous définis", Dungeons.ARCHETYPES.size() == 8 and Dungeons.ARCHETYPES.values().all(func(a): return Items.SETS.has(a)) and Dungeons.ARCHETYPES.values().size() == 8 and _distinct(Dungeons.ARCHETYPES.values()))
	check("les 2 nouveaux archétypes ont 2 / 4 / 6 pièces", Items.set_tiers("salvo") == [2, 4, 6] and Items.set_tiers("rampart") == [2, 4, 6])
	Profile.unlocked_features = ["dungeons"]
	var r := Dungeons.reward("delphi", 1)
	var chest: Dictionary = r.chests[0]
	check("le coffre de set d'un donjon porte l'archétype de sa zone", chest.get("archetype", "") == "salvo")
	var offer := Rewards.offer(chest)
	check("les pièces proposées portent l'archétype", not offer.is_empty() and offer.all(func(it): return it.get("archetype", "") == "salvo"))
	var gear := {}
	var n := 0
	for slot in ["head", "chest", "legs", "gloves"]:
		var it := Items.generate(40, 1.0, slot, "warrior", Items.MYTHIC, "", Items.MYTHIC)
		it["archetype"] = "frost"
		gear[slot] = it
		n += 1
	check("4 pièces d'archétype : bonus de la panoplie à 4", int(Items.set_counts(gear).get("frost", 0)) == 4 and Items.active_set_bonuses(gear).any(func(b): return b.set == "frost" and b.pieces == 4))
	check("l'infobulle montre la panoplie de donjon", Items.describe(gear["head"]).contains("Panoplie de donjon"))
	# --- fabrication
	# lot A1 : plan du boss d'origine de Delphi (l'ancien « plan_delphi » est converti), payé en insignes
	var pross := BossLibrary.zone_boss("delphi")
	var pslot := String(FabricationPage.slots_of(pross)[0])
	Profile.plans = []
	Profile.insignia = 1000
	check("sans plan : rien à fabriquer", FabricationPage.craft("delphi", pslot).has("error"))
	Profile.plans = ["plan_delphi"]
	Profile.records["dungeon_delphi_1"] = 1
	var before := Profile.inventory.size()
	var price := FabricationPage.cost(pross)
	var made := FabricationPage.craft("delphi", pslot)
	check("avec le plan : une pièce mythique de l'archétype, %d insignes" % price, not made.has("error") and made.archetype == "salvo" and int(made.rarity) == Items.MYTHIC and Profile.insignia == 1000 - price and Profile.inventory.size() == before + 1)
	Profile.insignia = 10
	check("sans insignes : refusé", FabricationPage.craft("delphi", pslot).has("error"))
	Profile.insignia = 1000
	Profile.records[Dungeons.boss_key(pross, 2)] = 1
	check("donjon fini en Mythique : pièce légendaire", int(FabricationPage.craft("delphi", String(FabricationPage.slots_of(pross)[1])).rarity) == Items.LEGENDARY)
	# --- Ruée des boss
	Tower.start_dungeon("warrior", Dungeons.RUSH, 1, [])
	check("Ruée : 8 étages, tous des boss, un par zone", Tower.rush and Tower.top() == 8 and Tower.floor_type(5) == "boss" and Tower.zone_for(5).id == GameData.zones[4].id and Tower.is_boss_floor(1))
	check("Ruée : niveau du boss = celui du donjon de la zone", Tower.level_for(3) == Dungeons.level(String(GameData.zones[2].id), 1))
	var part := Dungeons.rush_reward(3, 0)
	check("Ruée arrêtée à 3 boss : cristaux seulement, pas de titre", int(part.crystals) == ActivityLoot.rush_crystals(3, 0) and part.chests.is_empty() and part.title == "" and int(Profile.records.rush_best_0) == 3)
	var full := Dungeons.rush_reward(8, 0)
	check("Ruée finie : équipement + apparence + 3 coffres de matières, titre", full.chests.size() == 5 and full.title == "Briseur de boss" and "Briseur de boss" in Profile.extra_titles)
	var again := Dungeons.rush_reward(8, 0)
	check("2e victoire : plus de coffre d'apparence", again.chests.size() == 4)
	var res := Tower.finish()
	check("fin de la Ruée : le moteur est remis à zéro", res.get("rush", false) == true and not Tower.rush and not Tower.is_dungeon())
	# en scène : le 1er boss de la Ruée apparaît, tombe, la salle est franchie
	Tower.start_dungeon("warrior", Dungeons.RUSH, 0, [])
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var td: TowerDirector = world.director.tower
	check("Ruée en scène : un boss au centre, salle 1 / 8", td != null and is_instance_valid(td._boss) and Tower.floor_n == 1 and Tower.top() == 8)
	world.player.max_hp = 1e9  # le boss ne doit pas nous tuer pendant le test
	world.player.hp = 1e9
	var boss: Combatant = td._boss
	for _i in 6:
		if boss.is_dead:
			break
		boss.hp = 1.0
		boss.take_damage(1e12, world.player, false)
		await get_tree().physics_frame
	for _i in 120:
		if Tower.reached >= 1:
			break
		if world.cards.is_open() and Tower.reached == 0:  # carte de niveau éventuelle : on prend la première
			world.cards._choose(0)
		for m in get_tree().get_nodes_in_group("monsters"):  # les renforts du boss aussi
			if not m.is_dead:
				m.hp = 1.0
				m.take_damage(1e12, world.player, false)
		await get_tree().physics_frame
	await get_tree().create_timer(1.0).timeout
	check("boss tombé : première salle franchie, étage suivant après la carte", Tower.reached == 1 and td.phase == "cards")
	world.queue_free()
	Tower.finish()
	check("l'activité Ruée n'est plus « à venir »", not bool(_activity("rush").get("soon", false)))
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _distinct(a: Array) -> bool:
	var seen := {}
	for x in a:
		seen[x] = true
	return seen.size() == a.size()


func _activity(id: String) -> Dictionary:
	for a in Activities.LIST:
		if a.id == id:
			return a
	return {}
