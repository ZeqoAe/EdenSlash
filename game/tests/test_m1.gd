extends Node
## Passe M1 du Battle royale : trajet des héros scriptés (esquives du joueur), choix des coffres, fuite, objets cassés,
## largages, héros mis à prix, réapprovisionnement, spectateur après la mort, calendrier de 9 min 50.
## godot --headless --path game res://tests/test_m1.tscn

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_test_rules()
	await _test_travel_speed()
	await _test_game()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _test_rules() -> void:
	check("partie de 8 à 12 min (%.0f s)" % Royale.total_time(), Royale.total_time() >= 480.0 and Royale.total_time() <= 720.0)
	check("largage : la 4e qualité, la meilleure", Royale.CHEST_TIERS.size() == 4 and int(Royale.CHEST_TIERS[Royale.DROP_TIER].min_r) >= 4
		and float(Royale.CHEST_TIERS[Royale.DROP_TIER].xp) > float(Royale.CHEST_TIERS[2].xp))
	check("un largage par resserrement sauf le dernier : %d" % (Royale.PHASES.size() - 2), Royale.PHASES.size() - 2 >= 3)


## Sur un sol plat, un héros scripté Hardcore file comme un joueur qui enchaîne les esquives (> 10 m/s), le Facile flâne.
func _test_travel_speed() -> void:
	Royale.active = true
	var speeds := []
	for diff in [0, 3]:
		var root := Node3D.new()
		add_child(root)
		var floor_body := StaticBody3D.new()
		floor_body.collision_layer = GameData.PHYS_WORLD
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(600, 2, 600)
		shape.shape = box
		shape.position.y = -1.0
		floor_body.add_child(shape)
		root.add_child(floor_body)
		var r := Royale.make_ai("warrior", diff, 1)
		root.add_child(r)
		r.global_position = Vector3(-200, 0.5, 0)
		r.set_ffa(1)
		var other := Royale.make_ai("magician", diff, 2)
		root.add_child(other)
		other.global_position = Vector3(250, 0.5, 250)
		other.passive = true
		other.set_ffa(2)
		r.goal = Vector3(250, 0.0, 0)
		await get_tree().physics_frame
		var t := 0.0
		while t < 8.0:
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		speeds.append((r.global_position.x + 200.0) / 8.0)
		root.queue_free()
		await get_tree().process_frame
	Royale.active = false
	check("trajet Facile %.1f m/s, Hardcore %.1f m/s (joueur qui court : %.1f)" % [speeds[0], speeds[1], Player.BASE_SPEED],
		speeds[1] > 10.0 and speeds[0] > Player.BASE_SPEED and speeds[0] < speeds[1])


func _boot() -> RoyaleDirector:
	Profile.reset_all()
	Royale.difficulty = 3
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


func _test_game() -> void:
	var rd: RoyaleDirector = await _boot()
	var d: RunDirector = world.director
	var p: Player = world.player
	rd.phase = "fight"
	for a in rd.ais:
		a.passive = true
	var a0: ClassRival = rd.ais[0]
	var a1: ClassRival = rd.ais[1]
	# rapport de forces
	var hp1 := a1.hp
	a1.hp = a1.max_hp * 0.1
	var low := Royale.power_ratio(a1, a0)
	a1.hp = hp1
	check("rapport de forces : PV × frappe (soi-même : 1 ; adversaire à 10 %% de PV : %.2f)" % low, absf(Royale.power_ratio(a0, a0) - 1.0) < 0.01 and low < 0.5)
	# choix des coffres : un Hardcore préfère un coffre doré un peu plus loin à un coffre simple tout près
	var spot := Vector3(256, 0, 256)
	var g: Vector3 = d.map.ground_at(spot.x, spot.z)
	spot = g if g != Vector3.INF else spot
	for a in rd.ais:
		a.global_position = Vector3(30, 5, 30) + Vector3(a.get_meta("royale").index * 3.0, 0, 0)
	a0.global_position = spot + Vector3.UP * 0.5
	var near := rd._spawn_chest(spot + Vector3(8, 0, 0), 0)
	var gold := rd._spawn_chest(spot + Vector3(-22, 0, 0), 2)
	var smart := rd._pick_chest(a0, Vector2(spot.x, spot.z), Vector2(spot.x, spot.z), 60.0, [], true)
	rd._release(a0)
	var diff0: int = a0.get_meta("royale").diff
	a0.get_meta("royale").diff = 0  # un Facile
	var naive := rd._pick_chest(a0, Vector2(spot.x, spot.z), Vector2(spot.x, spot.z), 60.0, [], false)
	a0.get_meta("royale").diff = diff0
	rd._release(a0)
	check("choix pondéré : le coffre doré à 22 m plutôt que le simple à 8 m", smart == gold)
	check("sans pondération (Facile) : le plus proche", naive == near)
	# fuite : un Hardcore au contact d'un adversaire bien plus fort fuit (mode E) ; à force égale il se bat
	a1.global_position = a0.global_position + Vector3(4, 0, 0)
	a1.passive = false
	a0.passive = false
	a1.hp = a1.max_hp
	a0.hp = a0.max_hp * 0.2
	a0.get_meta("royale").potions = 0
	rd.ring = Royale.ring_at(0.0, rd.centers)
	rd._order(a0)
	check("Hardcore dépassé au contact : il fuit (%s)" % a0.get_meta("royale").get("mode", "?"), String(a0.get_meta("royale").mode) == "E" and a0.goal != Vector3.INF)
	a0.hp = a0.max_hp
	a0.get_meta("royale").flee_until = 0.0
	rd._order(a0)
	check("à force égale au contact : il se bat (%s)" % a0.get_meta("royale").get("mode", "?"), String(a0.get_meta("royale").mode) == "F" and a0.goal == Vector3.INF)
	a0.passive = true
	a1.passive = true
	# objets cassés : un héros scripté gagne l'expérience du joueur
	var st0: Dictionary = a0.get_meta("royale")
	var prog0 := float(st0.lv) + float(st0.prog)
	var plv := p.level
	rd._breaker = a0
	rd._on_broken("pot", a0.global_position)
	rd._breaker = null
	check("jarre cassée par un héros scripté : +%.2f niveau pour lui, rien pour le joueur" % Royale.BREAK_XP,
		is_equal_approx(float(st0.lv) + float(st0.prog), prog0 + Royale.BREAK_XP) and p.level == plv)
	# réapprovisionnement
	var before := rd.chests_left()
	rd._restock()
	check("réapprovisionnement : %d nouveaux coffres dans l'anneau" % (rd.chests_left() - before), rd.chests_left() - before >= 12
		and rd._chests.slice(rd._chests.size() - 3).all(func(it): return not rd._outside(it.global_position)))
	# largage : annoncé, en l'air, puis au sol
	rd.ring = Royale.ring_at(float(Royale.PHASES[0].hold) + 1.0, rd.centers)
	rd._announce_drop()
	var dr := rd.active_drop()
	check("largage annoncé : coffre de la 4e qualité, en l'air, repère sur la carte", not dr.is_empty() and (dr.node as Interactable).used
		and int(dr.node.get_meta("tier")) == Royale.DROP_TIER and rd.markers().any(func(m): return m[1] == "drop"))
	check("... dans le prochain anneau", Vector2(dr.pos.x, dr.pos.z).distance_to(rd.ring.next_center) <= float(rd.ring.next_radius))
	rd.elapsed = float(dr.land) + 0.1
	rd._update_drops()
	check("largage atterri : il s'ouvre", not (dr.node as Interactable).used and (dr.node as Interactable).global_position.distance_to(dr.pos) < 0.5)
	var lv_before := p.level
	rd.open_chest(dr.node)
	check("largage ouvert par le joueur : niveau %d → %d, plus de repère" % [lv_before, p.level], p.level >= lv_before + 1 and rd.active_drop().is_empty())
	world.cards._queue.clear()
	world.cards._show_next()
	# mis à prix : 3 éliminations
	a1.get_meta("royale").kills = Royale.BOUNTY_KILLS
	rd._update_bounty()
	check("mis à prix à %d éliminations, visible de partout" % Royale.BOUNTY_KILLS, rd.bounty == a1 and rd.markers().any(func(m): return m[1] == "bounty"))
	var k0 := float(st0.lv) + float(st0.prog)
	var gain := Royale.kill_xp(a0.level, a1.level, true)  # (lot BR1 : selon l'écart de niveau, plafonné par l'anneau)
	a1.hp = 1.0
	a1.take_damage(1e9, a0, false)
	await get_tree().physics_frame
	check("prime : l'éliminer rapporte %.0f niveau de plus (%.1f → %.1f)" % [Royale.BOUNTY_XP, k0, float(st0.lv) + float(st0.prog)],
		float(st0.lv) + float(st0.prog) >= minf(k0 + gain, float(Royale.level_cap_now)) - 0.01 and gain >= Royale.KILL_XP_MIN + Royale.BOUNTY_XP - 0.01
		and rd.bounty == null)
	check("fil des éliminations : « X élimine Y : la prime tombe »", rd.kill_feed.any(func(e): return String(e[0]).ends_with("la prime tombe")))
	# spectateur : le joueur tombe avec 6 adversaires en vie
	var alive := rd.alive_count()
	p.hp = 1.0
	p.take_damage(1e9, rd.ais[2], false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("éliminé : spectateur, place %d fixée" % alive, rd.spectating and rd._place == alive and rd.phase == "fight" and rd.leave_place() == alive)
	check("la caméra suit un héros en vie", world.rig.target != p and world.rig.target is ClassRival and not world.rig.target.is_dead)
	check("panneau : « Tu regardes … »", rd.objective_lines()[0].begins_with("◉ Tu regardes"))
	# les autres tombent : la partie finit sans lui, à sa place
	var living: Array = rd.ais.filter(func(a): return not a.is_dead)
	for i in range(living.size() - 1):
		living[i].hp = 1.0
		living[i].take_damage(1e9, null, false)
	await get_tree().physics_frame
	check("dernier héros debout : partie finie, place du joueur gardée (%d)" % rd._place, rd.phase == "over" and rd._place == alive)
	await get_tree().create_timer(3.6).timeout
	check("bilan : place %d, durée = temps du joueur" % alive, world._ended and Royale.rank == alive)
	world.queue_free()
	await get_tree().create_timer(0.5).timeout
