extends Node
## Battle royale : chacun pour soi (Combatant.ffa_id), calendrier de l'anneau, récompenses, héros scriptés,
## et une partie complète dans le monde (carte, coffres, éliminations, anneau, victoire, défaite).
## godot --headless --path game res://tests/test_royale.tscn

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	await _test_ffa()
	_test_ring()
	_test_rules()
	await _test_ai_duels()
	await _test_game_win()
	await _test_game_loss()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Chacun pour soi : trois héros, tous ennemis les uns des autres, même camp ou non.
func _test_ffa() -> void:
	var root := Node3D.new()
	add_child(root)
	var heroes: Array = []
	for i in 3:
		var r := ClassRival.new()
		r.setup(["warrior", "magician", "cleric"][i], 5, 1)
		r.passive = true
		root.add_child(r)
		r.global_position = Vector3(i * 4.0, 0.4, 0)
		heroes.append(r)
	await get_tree().physics_frame
	var a: ClassRival = heroes[0]
	var b: ClassRival = heroes[1]
	var c: ClassRival = heroes[2]
	check("sans chacun pour soi : un monstre ne vise aucun monstre", Combatant.hostile_targets(get_tree(), a).is_empty())
	for i in 3:
		(heroes[i] as Combatant).set_ffa(i)
	var ta := Combatant.hostile_targets(get_tree(), a)
	check("chacun pour soi : cibles = les deux autres", b in ta and c in ta and not (a in ta) and ta.size() == 2)
	check("hostile_heroes pareil", Combatant.hostile_heroes(get_tree(), b).size() == 2)
	c.is_dead = true
	check("un héros tombé n'est plus une cible", not (c in Combatant.hostile_targets(get_tree(), a)))
	c.is_dead = false
	check("le groupe de cibles du monstre suit le chacun pour soi", a._hostile_pool().size() == 2)
	var hp_b := b.hp
	var hp_a := a.hp
	Telegraph.spawn(root, b.global_position, 0.0, {"damage": 40.0, "delay": 0.05, "shape": "circle", "radius": 2.0, "source": a})
	await get_tree().create_timer(0.4).timeout
	check("un coup au sol touche l'autre héros (PV %d → %d)" % [hp_b, b.hp], b.hp < hp_b)
	check("... et pas son lanceur", is_equal_approx(a.hp, hp_a))
	b.clear_ffa()
	check("clear_ffa : retiré du groupe", not b.is_in_group("ffa") and b.ffa_id == -1)
	root.queue_free()


## Calendrier de l'anneau : 3 min 30, rayons décroissants, centres emboîtés.
func _test_ring() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c0 := Vector2(256, 256)
	var centers := Royale.roll_centers(c0, rng)
	check("5 centres pour 5 phases (+ la carte)", centers.size() == Royale.PHASES.size() + 1 and centers[0] == c0)
	check("calendrier : 3 min 30", is_equal_approx(Royale.total_time(), Royale.DURATION) and Royale.DURATION == 210.0)
	var r0 := Royale.ring_at(0.0, centers)
	check("départ : toute la carte, phase d'attente", is_equal_approx(float(r0.radius), Royale.START_RADIUS) and r0.state == "hold" and int(r0.phase) == 0)
	var prev := 1e9
	var mono := true
	var nested := true
	for t in range(0, 241, 2):
		var rg := Royale.ring_at(float(t), centers)
		if float(rg.radius) > prev + 0.001:
			mono = false
		prev = float(rg.radius)
		# l'anneau reste dans le cercle de départ
		if (rg.center as Vector2).distance_to(c0) + float(rg.radius) > Royale.START_RADIUS + 0.5:
			nested = false
	check("le rayon ne fait que décroître", mono)
	check("chaque anneau reste dans celui de départ", nested)
	var mid := Royale.ring_at(35.0 + 7.5, centers)
	check("à mi-resserrement le rayon est entre les deux (%.0f)" % float(mid.radius), mid.state == "shrink" and float(mid.radius) < 260.0 and float(mid.radius) > 170.0)
	var last := Royale.ring_at(205.0, centers)
	check("dernier cercle : mort subite", last.state == "final" and float(last.dps) >= 0.2 and float(last.radius) <= 14.5)
	var dps := Royale.PHASES.map(func(p): return float(p.dps))
	var rising := true
	for i in range(1, dps.size()):
		if dps[i] <= dps[i - 1]:
			rising = false
	check("dégâts hors anneau croissants", rising)


## Règles du mode et récompenses.
func _test_rules() -> void:
	Profile.reset_all()
	Royale.active = true
	check("mode « royale », règles JcJ", Modes.current() == "royale" and Modes.is_pvp() and PvpCaps.active() and ModeRules.profile_name() == "royale")
	check("pas d'acharnement (l'anneau fait pression)", is_equal_approx(PvpCaps.pressure(), 1.0))
	Royale.active = false
	check("hors partie : mode normal", Modes.current() != "royale")
	var before := Profile.insignia
	var win := Royale.settle(1, 3, "warrior")
	check("1re victoire : titre « Dernier debout », coffre d'apparence légendaire", win.first_win and "Dernier debout" in Profile.extra_titles and win.chest == "look_legend")
	check("insignes : 220 + 15 par élimination", Profile.insignia - before == 220 + 45 and int(win.insignia) == 265)
	var again := Royale.settle(1, 0, "warrior")
	check("2e victoire : pas de second titre", not again.first_win and again.title == "")
	var third := Royale.settle(3, 1, "warrior")
	check("3e place : coffre d'apparence rare", third.chest == "look_rare")
	var fifth := Royale.settle(5, 0, "warrior")
	check("5e place : insignes seulement", fifth.chest == "" and int(fifth.insignia) == 35)
	check("records : parties, victoires, meilleure place", int(Profile.records.royale_games) == 4 and int(Profile.records.royale_wins) == 2 and int(Profile.records.royale_best) == 1)
	check("le butin suit le niveau, plafonné", Royale.loot_level(1) == 2 and Royale.loot_level(500) == Royale.LEVEL_CAP)
	check("3 pièces par coffre", Royale.chest_items(2, 10, "warrior").size() == 3)


## Deux héros scriptés de même niveau et de même équipement (règles du royale) se battent 20 à 70 s.
func _test_ai_duels() -> void:
	Royale.active = true
	for lv in [1, 12]:
		var t: float = await _ai_duel("warrior", "magician", lv, lv / 3, 2)
		check("duel scripté niveau %d : %.0f s (20 à 70 s)" % [lv, t], t >= 20.0 and t <= 70.0)
	Royale.active = false


func _ai_duel(cid_a: String, cid_b: String, lv: int, chests: int, diff: int) -> float:
	var root := Node3D.new()
	add_child(root)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameData.PHYS_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 2, 200)
	shape.shape = box
	shape.position.y = -1.0
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var ais: Array = []
	for i in 2:
		var r := Royale.make_ai([cid_a, cid_b][i], diff, i + 1)
		var st: Dictionary = r.get_meta("royale")
		for k in chests:
			Royale.ai_open_chest(r, 1)
		st.lv = lv
		Royale.refresh_ai(r, false)
		root.add_child(r)
		r.global_position = Vector3(-4.0 + 8.0 * i, 0.5, 0)
		r.set_ffa(i + 1)
		ais.append(r)
	await get_tree().physics_frame
	var t := 0.0
	while t < 240.0 and not (ais[0].is_dead or ais[1].is_dead):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		PvpCaps.elapsed = t
	root.queue_free()
	await get_tree().process_frame
	return t


## Lance la partie dans le monde et attend que le directeur ait monté la carte et les sept héros.
func _boot_game() -> RoyaleDirector:
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.start("magician")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	var waited := 0.0
	while waited < 60.0 and not (world.get("director") != null and world.director.royale != null and world.director.royale.ais.size() == 7):
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	await get_tree().create_timer(1.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	return world.director.royale


func _test_game_win() -> void:
	var rd: RoyaleDirector = await _boot_game()
	var d: RunDirector = world.director
	var p: Player = world.player
	check("partie montée : mode, état, 7 héros IA", Royale.active and d.state == "royale" and rd.ais.size() == 7 and Run.active)
	var ids := {}
	for n in get_tree().get_nodes_in_group("ffa"):
		ids[(n as Combatant).ffa_id] = true
	check("8 héros en chacun pour soi, identifiants distincts", get_tree().get_nodes_in_group("ffa").size() == 8 and ids.size() == 8)
	var closest := INF
	var pts: Array = [p.global_position]
	for a in rd.ais:
		pts.append(a.global_position)
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			closest = minf(closest, Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length())
	check("spawns distincts et éloignés (plus proches : %.0f m)" % closest, closest >= 25.0)
	var naked := true
	for a in rd.ais:
		var st: Dictionary = a.get_meta("royale")
		naked = naked and st.gear.is_empty() and int(st.lv) == 1
	check("tous nus au niveau 1", p.level == 1 and Profile.equipped.is_empty() and naked)
	check("2 potions de soin au départ", Potions.count("heal") == 2)
	var tiers := [0, 0, 0]
	var n_chests := 0
	for it in d.map.interactables:
		if it.kind == "chest":
			n_chests += 1
			tiers[int(it.get_meta("tier", 0))] += 1
	check("64 coffres en 3 qualités (%s)" % [tiers], n_chests == 64 and tiers[1] == 18 and tiers[2] == 8 and tiers[0] == 38)
	check("ni camps, ni sanctuaires, ni marchands sur la carte", d.map.camps.is_empty() and d.map.shrines.is_empty() and d.map.merchant_spots.is_empty())
	check("le décompte est en cours", rd.phase == "countdown" and rd.ais.all(func(a): return a.passive))
	# coffre doré ouvert par le joueur
	var gold: Interactable = null
	for it in d.map.interactables:
		if it.kind == "chest" and int(it.get_meta("tier", 0)) == 2:
			gold = it
			break
	var loot_before := get_tree().get_nodes_in_group("loot").size()
	rd.open_chest(gold)
	await get_tree().physics_frame
	check("coffre ouvert : utilisé, niveau gagné, choix proposé", gold.used and p.level >= 2 and (world.cards.is_open() or not world.cards._queue.is_empty()))
	check("coffre doré : deux potions au sol", get_tree().get_nodes_in_group("loot").size() >= loot_before + 2)
	world.cards._queue.clear()
	world.cards._show_next()
	# la pièce choisie dans un coffre est portée tout de suite, au niveau du héros + 1
	var pick: Dictionary = Royale.chest_items(2, p.level, Run.class_id)[0]
	Run.apply_card(RunDirector.item_card(pick, "gear"))
	check("pièce de coffre portée (%s, niveau d'objet %d)" % [pick.slot, int(pick.level)], Profile.equipped.has(String(pick.slot)) and int(pick.level) >= 1)
	# anneau : un héros hors de l'anneau perd des PV
	rd.phase = "fight"
	var victim: ClassRival = rd.ais[0]
	victim.global_position = Vector3(8, 5, 8)
	var hp0 := victim.hp
	rd.ring = Royale.ring_at(0.0, rd.centers)
	rd._ring_damage()
	check("hors de l'anneau : %d → %d PV" % [hp0, victim.hp], victim.hp < hp0)
	victim.global_position = Vector3(256, 5, 256)
	# élimination
	var kills0 := Royale.kills
	var lv0 := p.level
	rd.ais[1].hp = 1.0
	rd.ais[1].take_damage(1e9, p, false)  # (un coup entre héros est plafonné : PV à 1)
	await get_tree().physics_frame
	check("élimination comptée, niveau gagné", Royale.kills == kills0 + 1 and p.level > lv0 and rd.alive_count() == 7)
	check("... et l'adversaire quitte le chacun pour soi", get_tree().get_nodes_in_group("ffa").size() == 7)
	# tous les autres tombent : victoire
	for i in range(2, 7):
		rd.ais[i].hp = 1.0
		rd.ais[i].take_damage(1e9, p, false)
	victim.hp = 1.0
	victim.take_damage(1e9, p, false)
	await get_tree().physics_frame
	check("dernier debout : partie finie, 1re place", rd.phase == "over" and rd._place == 1)
	world.cards._queue.clear()
	world.cards._show_next()  # (le niveau gagné a ouvert un choix de carte : la partie est en pause)
	var ins := Profile.insignia
	await get_tree().create_timer(3.6).timeout
	check("bilan affiché, partie terminée", world._ended and not Royale.active and Royale.rank == 1 and not Run.active)
	check("récompenses : insignes, titre, coffre d'apparence", Profile.insignia > ins and "Dernier debout" in Profile.extra_titles and Profile.reward_chests.any(func(c): return String(c.type).begins_with("look")))
	check("l'équipement de la partie n'est pas gardé", not Profile.in_run)
	world.queue_free()
	await get_tree().create_timer(0.5).timeout


func _test_game_loss() -> void:
	var rd: RoyaleDirector = await _boot_game()
	var p: Player = world.player
	rd.phase = "fight"
	var killer: ClassRival = rd.ais[3]
	p.hp = 1.0
	p.take_damage(1e9, killer, false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("joueur tombé avec 7 adversaires : 8e place", rd.phase == "over" and rd._place == 8)
	await get_tree().create_timer(3.6).timeout
	check("bilan de défaite : partie terminée, place 8", world._ended and Royale.rank == 8 and not Royale.active)
	world.queue_free()
	await get_tree().create_timer(0.5).timeout
