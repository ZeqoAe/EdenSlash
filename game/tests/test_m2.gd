extends Node
## Passe M2 : bibliothèque de boss (BossLibrary, BossBricks) et donjons à la carte. Données, API, butin de chaque boss,
## puis en jeu : chaque boss apparaît, chacune de ses briques s'exécute, il meurt ; lieutenant de la 3e salle.
## godot --headless --path game res://tests/test_m2.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	_data()
	_dungeons()
	await _in_game()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _data() -> void:
	var ids := BossLibrary.ids()
	check("au moins 40 boss (%d)" % ids.size(), ids.size() >= 40)
	var uniq := {}
	for id in ids:
		uniq[id] = true
	check("identifiants uniques", uniq.size() == ids.size())
	var bad: Array = []
	var fams := {}
	var used := {}
	for id in ids:
		var d := BossLibrary.get_def(id)
		var m := GameData.monster(int(d.monster))
		var types := BossLibrary.brick_types(id)
		if m.is_empty() or not ResourceLoader.exists("res://assets/monsters/%s/%s.glb" % [m.model, m.model]):
			bad.append("%s : modèle" % id)
		if types.size() < 2 or types.size() > 4:
			bad.append("%s : %d briques" % [id, types.size()])
		for t in types:
			if not BossBricks.DEFS.has(t):
				bad.append("%s : brique %s" % [id, t])
			used[t] = true
			fams[BossBricks.family_of(t)] = true
		if not d.get("legacy", false) and BossLibrary.bricks_of(id, 0).size() != types.size():
			bad.append("%s : normalisation" % id)
		if (d.get("slots", []) as Array).size() != 2 or not Items.SETS.has(String(d.get("archetype", ""))):
			bad.append("%s : butin" % id)
		if Dungeons.dungeon_name(id) == "" or BossLibrary.full_name(id) == "":
			bad.append("%s : nom" % id)
	check("chaque boss : un modèle, 2 à 4 briques connues, un butin, un nom %s" % str(bad), bad.is_empty())
	check("au moins 8 familles de mécaniques (%d)" % fams.size(), fams.size() >= 8)
	check("chaque brique sert à au moins un boss", BossBricks.DEFS.keys().all(func(t): return used.has(t)))
	# panoplies : chaque archétype couvre les 9 emplacements sur ses donjons
	var cover_ok := true
	for a in DungeonPage.ARCH_ORDER:
		var slots := {}
		for id in Dungeons.catalog({"archetype": a}):
			for s in BossLibrary.loot(id).slots:
				slots[s] = true
		cover_ok = cover_ok and slots.size() == 9
	check("chaque panoplie s'obtient aux 9 emplacements", cover_ok)
	# les boss de zone gardent leurs mécaniques (Survie inchangée)
	var legacy_ok := true
	for zid in Dungeons.zone_ids():
		var bid := BossLibrary.zone_boss(zid)
		var z := GameData.zone(zid)
		legacy_ok = legacy_ok and bid != "" and int(BossLibrary.get_def(bid).monster) == int(z.dungeon.boss) \
			and BossLibrary.brick_types(bid) == (z.dungeon.mechanics as Array) and BossLibrary.loot(bid).archetype == Dungeons.archetype(zid)
	check("boss de zone : même monstre, mêmes mécaniques, même panoplie qu'avant", legacy_ok)
	var legacy := BossBricks.from_legacy(["adds", "puddles", "reflect", "pet"], {"pet": 58503})
	check("mécaniques d'avant traduites en briques (miroir : minuteur de base)", legacy.size() == 3 and legacy[2].p.monster == 58503 and legacy[1].every == 9.0)
	# PV fixes par palier, Mythique : l'Impatience en plus
	var id0 := String(ids[1])
	check("PV fixes : Héroïque > Normal, indépendants du héros", BossLibrary.hp(id0, 40, 1) > BossLibrary.hp(id0, 40, 0) and is_equal_approx(BossLibrary.hp(id0, 40, 0), Dungeons.boss_hp(40, 0) * float(BossLibrary.get_def(id0).hp)))
	check("Mythique : Impatience ajoutée", BossLibrary.bricks_of(id0, 2).any(func(b): return b.type == "frenzy") and not BossLibrary.bricks_of(id0, 0).any(func(b): return b.type == "frenzy" and not "frenzy" in BossLibrary.brick_types(id0)))
	check("intro lisible pour chaque boss", ids.all(func(id): return BossLibrary.intro(id).length() > 8))


func _dungeons() -> void:
	Profile.records["epochs_cleared"] = 4  # tous les donjons ouverts (époques gagnées)
	Profile.records["boss_limestone"] = 1
	var all := Dungeons.catalog()
	check("un donjon par boss (%d)" % all.size(), all.size() == BossLibrary.ids().size())
	var chest := Dungeons.catalog({"slot": "chest"})
	check("filtre « je cherche un torse » : seulement des donjons qui en donnent (%d)" % chest.size(), not chest.is_empty() and chest.all(func(id): return "chest" in BossLibrary.loot(id).slots))
	var both := Dungeons.catalog({"slot": "chest", "archetype": "phoenix"})
	check("filtre torse + Phénix : au moins un donjon", not both.is_empty())
	var fam := Dungeons.catalog({"family": "arena"})
	check("filtre par mécanique (arène qui se resserre)", not fam.is_empty() and fam.all(func(id): return "shrink" in BossLibrary.brick_types(id)))
	check("lieutenant : un autre boss de la même zone", Dungeons.lieutenant_of("latif") != "latif" and Dungeons.boss_zone(Dungeons.lieutenant_of("latif")) == "beluga")
	# lancement et butin de chaque boss
	Tower.start_dungeon("warrior", "beluga", 0, [], "latif")
	check("Tower.start_dungeon : boss choisi", Tower.dungeon_boss == "latif" and Tower.dungeon == "beluga")
	Tower.start_dungeon("warrior", "beluga", 0, [], "mori")
	check("boss d'une autre zone refusé : boss de la zone", Tower.dungeon_boss == BossLibrary.zone_boss("beluga"))
	Tower.start_dungeon("warrior", "beluga", 0, [])
	check("sans boss choisi : celui de la zone", Tower.dungeon_boss == BossLibrary.zone_boss("beluga"))
	Tower.start_siege("warrior", "beluga", 0, [])
	check("le Siège garde son boss de zone (bibliothèque plus tard)", Tower.dungeon_boss == "")
	Tower.start("warrior", 1, 1)
	check("la Tour : pas de boss de donjon", Tower.dungeon_boss == "")
	Tower.active = false
	Run.active = false
	var bad: Array = []
	for id in BossLibrary.ids():
		var zid := Dungeons.boss_zone(id)
		for diff in [0, 2]:
			var n0 := Dungeons.boss_cleared(id, diff)
			var r := Dungeons.reward(zid, diff, id)
			var c: Dictionary = r.chests[0]
			var offer := Rewards.offer(c)
			var slots: Array = BossLibrary.loot(id).slots
			if c.get("slots", []) != slots or String(c.archetype) != String(BossLibrary.loot(id).archetype) or Dungeons.boss_cleared(id, diff) != n0 + 1:
				bad.append("%s/%d coffre" % [id, diff])
			if offer.is_empty() or not offer.all(func(it): return String(it.slot) in slots and String(it.get("archetype", "")) == String(c.archetype)):
				bad.append("%s/%d pièces %s" % [id, diff, str(offer.map(func(it): return it.slot))])
			if offer.any(func(it): return int(it.rarity) < Items.MYTHIC):
				bad.append("%s/%d rareté" % [id, diff])
	check("butin de chaque boss (Normal, Mythique) : ses deux emplacements, sa panoplie, record %s" % str(bad.slice(0, 6)), bad.is_empty())
	check("aperçu du coffre : emplacements et panoplie", Rewards.preview(Dungeons.reward("beluga", 2, "latif").chests[0]).contains("panoplie"))
	# éveillées en Mythique : sur 60 tirages d'armure de haut niveau, au moins une
	var aw := 0
	for i in 20:
		var c2 := Rewards.make("set", 90, true)
		c2["slots"] = ["chest", "legs"]
		c2["diff"] = 2
		c2["archetype"] = "storm"
		for it in Dungeons.slot_pieces(c2):
			if it.get("awakened", false):
				aw += 1
	check("Mythique : des pièces éveillées (%d sur 60)" % aw, aw > 0 and aw < 40)
	Profile.reward_chests.clear()


func _in_game() -> void:
	Tower.start_dungeon("warrior", "beluga", 0, [], "latif")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var d: RunDirector = world.director
	var p: Player = world.player
	p.dev_invincible = true
	world.revives_left = 9
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.3).timeout
	# salle du lieutenant
	d.tower.begin(Dungeons.LIEUTENANT_ROOM)
	await get_tree().create_timer(0.5).timeout
	var lts := get_tree().get_nodes_in_group("monsters").filter(func(m): return m.is_boss)
	check("2e salle : un lieutenant (un boss de la zone, une seule mécanique)", lts.size() == 1 and lts[0].brain.bricks.size() <= 1 and lts[0].display_name.contains("lieutenant"))
	# salle du boss : le boss choisi
	d.tower.begin(Tower.top())
	await get_tree().create_timer(0.5).timeout
	check("3e salle : le boss choisi (Latif)", is_instance_valid(d.tower._boss) and d.tower._boss.get_meta("boss_id", "") == "latif" and d._boss == d.tower._boss)
	check("PV du boss : ceux de la bibliothèque", is_instance_valid(d._boss) and absf(d._boss.max_hp - BossLibrary.hp("latif", Tower.level_for(Tower.top()), 0)) < BossLibrary.hp("latif", Tower.level_for(Tower.top()), 0) * 0.5)
	d.tower.phase = "done"  # salle figée : retirer les boss ne termine pas le donjon
	_clear()
	# chaque boss : apparition, chaque brique, mort
	var center: Vector3 = d.tower._center
	var bad: Array = []
	var one_shot: Array = []
	Engine.time_scale = 2.0
	for id in BossLibrary.ids():
		for tier in [0, 2]:
			if tier == 2 and BossLibrary.ids().find(id) % 8 != 0:
				continue  # Mythique : un boss sur huit (durée du test)
			var m := BossLibrary.spawn(id, tier, {"director": d, "pos": center + Vector3(0, 0, 4), "level": 40})
			if m == null or m.brain == null:
				bad.append("%s : apparition" % id)
				continue
			await get_tree().physics_frame
			if m.brain.bricks.size() != BossLibrary.bricks_of(id, tier).size():
				bad.append("%s : briques" % id)
			if m.brain._dmg(9.0) > p.max_hp * BossLibrary.HIT_CAP + 0.5:
				one_shot.append(id)
			for br in m.brain.bricks:
				m.brain._busy = false
				BossBricks.run(m.brain, br)
				await get_tree().create_timer(0.6).timeout
				if not is_instance_valid(m):
					bad.append("%s : disparu pendant %s" % [id, br.type])
					break
			if not is_instance_valid(m):
				continue
			m.shielded = false
			m.brain.end_barrier()
			m.take_damage(m.max_hp * 50.0, p)
			await get_tree().create_timer(0.2).timeout
			if not m.is_dead:
				bad.append("%s : ne meurt pas" % id)
			_clear()
	Engine.time_scale = 1.0
	check("chaque boss apparaît, chaque brique s'exécute, il meurt %s" % str(bad.slice(0, 6)), bad.is_empty())
	check("jamais de mort en un coup : un coup ≤ %d %% des PV max %s" % [int(BossLibrary.HIT_CAP * 100), str(one_shot)], one_shot.is_empty())
	# barrière : absorbe, puis brisée
	var b := BossLibrary.spawn("argus", 0, {"director": d, "pos": center, "level": 40})
	await get_tree().physics_frame
	var hp0 := b.hp
	b.brain.start_barrier(1000.0)
	b.take_damage(400.0, p)
	check("barrière : les coups la vident, pas les PV", is_equal_approx(b.hp, hp0) and b.brain.barrier_left < 1000.0)
	b.take_damage(1.0e7, p)
	check("barrière brisée : le surplus passe", b.brain.barrier_left <= 0.0 and b.hp < hp0)
	_clear()
	world.queue_free()
	Tower.active = false
	Tower.dungeon = ""
	Tower.dungeon_boss = ""
	Run.active = false


func _clear() -> void:
	for n in get_tree().get_nodes_in_group("monsters"):
		n.remove_from_group("monsters")
		n.queue_free()
	for n in get_tree().current_scene.get_children() if get_tree().current_scene else []:
		if n is Telegraph or n is Hazard or n is Projectile or n is BossBricks.ArenaWall:
			n.queue_free()
