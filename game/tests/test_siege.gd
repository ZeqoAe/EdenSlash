extends Node
## Le Siège : règles, verrou, ciblage chacun pour soi, butin, et deux parties complètes en scène (dernier debout,
## puis cœur emporté hors de l'anneau).
## godot --headless --path game res://tests/test_siege.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	_test_rules()
	_test_unlock_and_activity()
	_test_settle()
	await _test_ffa_targeting()
	await _test_full_game_won()
	await _test_full_game_escaped()
	await _test_eliminated()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _zone() -> String:
	return String(Dungeons.zone_ids()[0])


## Règles du mode : 5 vagues + boss, monstres ×2 en nombre et en PV, deux alliés toujours présents.
func _test_rules() -> void:
	var zid := _zone()
	Tower.start_siege("warrior", zid, 1, ["cleric"])
	check("Siège : mode donjon avec le drapeau siège, 6 étapes (5 vagues + boss)", Tower.siege and Tower.is_dungeon() and Tower.top() == Siege.WAVES + 1 and Modes.current() == "dungeon")
	check("les vagues 3 et 5 portent des élites, la 6e étape est le boss", Tower.floor_type(1) == "monsters" and Tower.floor_type(3) == "elite" and Tower.floor_type(5) == "elite" and Tower.floor_type(6) == "boss")
	check("toujours deux alliés : celui choisi + un tiré au hasard", Tower.allies.size() == 2 and Tower.allies[0] == "cleric")
	var room14 := 14 + 4 * 1
	check("monstres deux fois plus nombreux qu'une salle de donjon (%d contre %d)" % [Tower.monster_count(1), room14], Tower.monster_count(1) >= room14 * 1.4 and Tower.monster_count(5) > Tower.monster_count(1))
	check("PV des monstres ×2 par rapport au donjon (profil de base)", is_equal_approx(Tower.monster_hp_mult(1), Dungeons.MONSTER_HP * 2.0) and is_equal_approx(Tower.monster_hp_mult(3), Dungeons.ELITE_HP * 2.0))
	check("boss : sac à PV au-dessus d'un boss de donjon à deux alliés", Tower.monster_hp_mult(6, -1, true) > Dungeons.hp_mult(true, false, 2))
	check("le boss est d'un niveau de plus que les vagues", Tower.level_for(6) == Tower.level_for(1) + 1)
	check("fureur à 6 minutes", is_equal_approx(Siege.ENRAGE_AT, 360.0) and is_equal_approx(Siege.RING_TIME, 20.0))
	Tower.start_dungeon("warrior", zid, 0, [])
	check("un donjon ordinaire n'est pas un siège", not Tower.siege and Tower.top() == Dungeons.ROOMS.size())
	Tower.finish()
	check("Siege.fill_allies complète à deux", Siege.fill_allies([]).size() == 2 and Siege.fill_allies(["mage", "x", "y"]).size() == 2)
	Siege.reset()


func _test_unlock_and_activity() -> void:
	var def := Activities.get_def("siege")
	check("activité « Le Siège » dans la liste, verrouillée par « siege »", not def.is_empty() and def.unlock == "siege" and Unlocks.LIST.has("siege"))
	check("son image d'écran de chargement existe", ResourceLoader.exists(Activities.IMG % String(def.get("img", def.id))))
	Settings.set_v("interface", "dev_mode", false)
	Profile.unlocked_features = []
	Profile.records["epochs_cleared"] = 0
	check("verrouillée tant que les Donjons ne sont pas ouverts", not Unlocks.test("siege") and Activities.locked(def))
	Profile.records["epochs_cleared"] = 2
	check("ouverte avec les Donjons", Unlocks.test("siege"))
	var zid := _zone()
	Profile.records["boss_" + zid] = 1
	Profile.unlocked_features = ["dungeons", "siege"]
	check("la PE se vérifie au lancement (Siege.power_ok suit GearPower)", Siege.power_required(zid, 0) > 0 and Siege.power_required(zid, 2) > Siege.power_required(zid, 0))
	check("la PE du Siège dépasse celle d'un donjon de même difficulté", Siege.power_required(zid, 1) > Dungeons.power_required(zid, 1))
	Profile.equipped = {}
	check("sans équipement : le Siège n'est pas jouable (PE)", not Siege.power_ok(zid, 1) or Siege.power_required(zid, 1) == 0)


## Butin : cristaux selon la progression, coffre d'équipement si le boss tombe, apparence légendaire pour le
## dernier debout (+ titre la 1re fois), épique pour le cœur emporté.
func _test_settle() -> void:
	var zid := _zone()
	Profile.reward_chests = []
	Profile.extra_titles = []
	Profile.materials["crystal"] = 0
	var lost := Siege.settle(zid, 0, 3, "")
	check("siège perdu en vague 3 : des cristaux, aucun coffre", int(lost.crystals) == 36 and lost.chests.is_empty() and Profile.reward_chests.is_empty())
	var boss := Siege.settle(zid, 0, Siege.WAVES + 1, "eliminated")
	check("boss tombé puis éliminé : coffre d'équipement seul", boss.chests.size() == 1 and boss.chests[0].type == "gear")
	var esc := Siege.settle(zid, 0, Siege.WAVES + 1, "escaped")
	check("cœur emporté : équipement + coffre d'apparence épique", esc.chests.size() == 2 and esc.chests[1].type == "look_epic")
	var won := Siege.settle(zid, 1, Siege.WAVES + 1, "won")
	check("dernier debout : équipement + coffre d'apparence LÉGENDAIRE + titre", won.chests.size() == 2 and won.chests[1].type == "look_legend" and won.title == Siege.TITLE and Siege.TITLE in Profile.extra_titles)
	var won2 := Siege.settle(zid, 1, Siege.WAVES + 1, "won")
	check("2e victoire : plus de titre, mais toujours le coffre légendaire", won2.title == "" and won2.chests[1].type == "look_legend" and Siege.wins() == 2)
	check("records : meilleure vague et siège gagné", int(Profile.records.get("siege_best_1", 0)) == Siege.WAVES + 1 and Siege.clears(zid, 1) == 2)


## Chacun pour soi : trois héros d'un même camp deviennent tous ennemis ; les règles du JcJ s'appliquent.
func _test_ffa_targeting() -> void:
	var root := Node3D.new()
	add_child(root)
	var hs: Array = []
	for i in 3:
		var r := ClassRival.new()
		r.ally = true
		r.setup(["warrior", "magician", "cleric"][i], 10, 2)
		r.passive = true
		root.add_child(r)
		r.global_position = Vector3(i * 4.0, 0.4, 0)
		hs.append(r)
	await get_tree().physics_frame
	var a: ClassRival = hs[0]
	var b: ClassRival = hs[1]
	check("avant : trois alliés du même camp, aucune cible entre eux", Combatant.hostile_heroes(get_tree(), a).is_empty())
	Siege.ffa = true
	for i in 3:
		(hs[i] as Combatant).set_ffa(i)
	check("chacun pour soi : les deux autres sont des cibles", Combatant.hostile_targets(get_tree(), a).size() == 2 and a._hostile_pool().size() == 2)
	check("règles du JcJ actives (profil siège, pas de potions)", PvpCaps.active() and ModeRules.profile_name() == "siege" and not Potions.allowed())
	check("soins réduits comme en arène", PvpCaps.heal_mult() < PvpCaps.HEAL_MULT)
	Siege.carrier = b
	check("celui qui porte le cœur est la seule cible de l'autre", a._hostile_pool() == [b])
	Siege.carrier = null
	var hp := b.hp
	a.atk = 1e9
	b.take_damage(1e9, a)
	check("un coup d'un héros sur l'autre est plafonné (pas de mort en un coup, PV %d → %d)" % [hp, b.hp], b.hp > 0.0 and b.hp < hp and b.hp >= hp - ceilf(b.max_hp * 0.16))
	Siege.reset()
	for h in hs:
		(h as Combatant).clear_ffa()
	check("après : règles du JcJ éteintes", not PvpCaps.active() and Combatant.hostile_heroes(get_tree(), a).is_empty())
	root.queue_free()


# --- parties en scène ----------------------------------------------------------------------------
func _launch(diff: int) -> Node:
	Settings.set_v("interface", "dev_mode", false)
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 2
	Tower.start_siege("warrior", _zone(), diff, ["cleric", "knight"])
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var d: RunDirector = world.director
	var player: Player = world.player
	player.immortal = true  # les vagues ne doivent pas nous tuer pendant le test
	world.cards._queue.clear()
	world.cards._show_next()  # ferme le choix de départ (dépause)
	await get_tree().create_timer(3.0).timeout
	return world


## Vide la vague en cours, prend la carte, saute le répit ; s'arrête quand [param until] est vrai.
func _drive(world: Node, until: Callable, frames := 7000) -> void:
	var td: SiegeDirector = world.director.tower
	for _i in frames:
		if until.call():
			return
		if world.cards.is_open():
			world.cards._select(0)
			world.cards._confirm_choice()
		if td.phase == "rest":
			td._rest_t = 0.0
		for m in get_tree().get_nodes_in_group("monsters"):
			if not m.is_dead:
				m.hp = 1.0
				m.take_damage(1e12, world.player, false)
		await get_tree().physics_frame


func _to_ring(world: Node) -> void:
	var td: SiegeDirector = world.director.tower
	var seen := {}
	await _drive(world, func():
		seen[Tower.floor_n] = true
		return td.phase == "ring")
	check("les 5 vagues puis le boss ont été jouées dans l'ordre", seen.size() == Siege.WAVES + 1 and Tower.reached == Siege.WAVES + 1)


func _test_full_game_won() -> void:
	var world := await _launch(0)
	var td: SiegeDirector = world.director.tower
	var player: Player = world.player
	check("en scène : directeur du Siège, arène, vague 1, deux alliés IA", td is SiegeDirector and Tower.floor_n == 1 and td._allies.size() == 2 and td.alive() > 0)
	check("la vague 1 compte deux fois plus de monstres qu'un donjon", Tower.monster_count(1) >= 22)
	check("potions de départ", Potions.count("heal") >= 2)
	await _to_ring(world)
	check("boss mort : anneau, cœur au centre, trêve", td.phase == "ring" and is_instance_valid(td._wall) and is_instance_valid(td._core) and td._core.kind == "siege_core")
	check("les trois héros sont debout et à pleine vie", td._alive_allies().size() == 2 and is_equal_approx(player.hp, player.max_hp))
	check("pas encore hostiles pendant la trêve", not Siege.ffa and player.ffa_id == -1)
	var r0 := td._ring_r
	td._ffa_t = Siege.TRUCE + 0.1
	await get_tree().create_timer(0.3).timeout
	check("trêve finie : chacun pour soi, trois ffa_id distincts", Siege.ffa and td.phase == "ffa" and player.ffa_id == 0 and td._allies[0].ffa_id == 1 and td._allies[1].ffa_id == 2)
	check("le joueur peut frapper les alliés devenus rivaux", td._allies[0] in player.foes() and td._allies[1] in player.foes())
	check("les alliés visent le joueur et l'autre allié", player in td._allies[0]._hostile_pool() and td._allies[1] in td._allies[0]._hostile_pool())
	td._ffa_t = Siege.RING_TIME
	await get_tree().create_timer(0.3).timeout
	check("l'anneau a rétréci (%.1f → %.1f m)" % [r0, td._ring_r], is_equal_approx(td._ring_r, Siege.RING_TO))
	# hors de l'anneau : le joueur brûle
	player.immortal = false
	player.hp = player.max_hp
	player.global_position = td._center + Vector3(Siege.RING_TO + 6.0, 1.0, 0)
	await get_tree().create_timer(1.2).timeout
	check("hors de l'anneau : le joueur perd des PV", player.hp < player.max_hp)
	player.global_position = td._center + Vector3(2.0, 1.0, 0)
	player.immortal = true
	# les deux alliés tombent : victoire
	for a in td._allies:
		a.hp = 1.0
		a.take_damage(1000.0, player)
	await get_tree().create_timer(0.4).timeout
	check("les deux rivaux tombés : dernier debout", td.phase == "done" and Siege.outcome == "won" and not Siege.ffa)
	await get_tree().create_timer(3.2).timeout
	var legend := Profile.reward_chests.filter(func(c): return c.type == "look_legend")
	check("bilan : un coffre d'apparence légendaire dans les coffres, titre gagné", legend.size() == 1 and Siege.TITLE in Profile.extra_titles)
	check("moteur remis à zéro, bilan affiché", not Tower.siege and not Tower.is_dungeon() and world.get_children().any(func(c): return c is DungeonResults))
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Tower.active = false


func _test_full_game_escaped() -> void:
	var world := await _launch(0)
	var td: SiegeDirector = world.director.tower
	var player: Player = world.player
	await _to_ring(world)
	td.interact(td._core)
	check("le joueur prend le cœur : il est le porteur, sa lueur est posée", Siege.carrier == player and td._core.used and is_instance_valid(td._orb))
	td._ffa_t = Siege.TRUCE + 0.1
	await get_tree().create_timer(0.3).timeout
	check("les IA visent le porteur", td._allies[0]._hostile_pool() == [player] and td._allies[1]._hostile_pool() == [player])
	td._ffa_t = Siege.RING_TIME
	player.global_position = td._center + Vector3(Siege.RING_TO + 1.0, 1.0, 0)
	await get_tree().create_timer(0.4).timeout
	check("le porteur franchit l'anneau : il quitte le duel", Siege.outcome == "escaped" or Tower.siege == false)
	await get_tree().create_timer(3.2).timeout
	var epic := Profile.reward_chests.filter(func(c): return c.type == "look_epic")
	var legend := Profile.reward_chests.filter(func(c): return c.type == "look_legend")
	check("récompense moindre : apparence épique, pas de légendaire", epic.size() == 1 and legend.is_empty())
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Tower.active = false


func _test_eliminated() -> void:
	var world := await _launch(0)
	var td: SiegeDirector = world.director.tower
	var player: Player = world.player
	await _to_ring(world)
	td._ffa_t = Siege.TRUCE + 0.1
	await get_tree().create_timer(0.3).timeout
	player.immortal = false
	player.hp = 1.0
	player.take_damage(1e9, td._allies[0])
	await get_tree().create_timer(0.5).timeout
	check("joueur éliminé en chacun pour soi : classé 3e, partie finie", Siege.outcome == "eliminated" and Siege.rank == 3 and td.phase == "done")
	await get_tree().create_timer(3.2).timeout
	var legend := Profile.reward_chests.filter(func(c): return c.type == "look_legend")
	var gear := Profile.reward_chests.filter(func(c): return c.type == "gear")
	check("éliminé : le boss compte (coffre d'équipement), pas de légendaire", gear.size() == 1 and legend.is_empty())
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Tower.active = false
