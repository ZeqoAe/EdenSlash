extends Node
## Lot CO-B : carte du Colisée (ProcMap.generate_colisee), anneau de feu (ColiseeRing), fleurs de vie (ColiseeFlower),
## arènes (ColiseeArena). Rapport conception/benchmark/R_CO_B.md.
## godot --headless --path game res://tests/test_co_b.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	await _map(6)
	await _map(8)
	await _map(4)
	_ring_curve()
	await _ring_damage()
	await _flower()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _map(count: int) -> void:
	var t0 := Time.get_ticks_msec()
	var m := ProcMap.new()
	m.biome = String(GameData.zone(Duel.ZONE).get("biome", "limestone"))
	add_child(m)
	m.generate_colisee(4242 + count, count)
	var gen_ms := Time.get_ticks_msec() - t0
	for _i in 3600:
		if m._region.navigation_mesh != null:
			break
		await get_tree().physics_frame
	print("[co_b] %d arènes : carte %d m, génération %d ms, navigation %d ms" % [count, int(m.size), gen_ms, Time.get_ticks_msec() - t0])
	check("%d arènes : navigation cuite" % count, m._region.navigation_mesh != null and m._region.navigation_mesh.get_polygon_count() > 0)
	var described := m.colisee_arenas.size() == count
	for e in m.colisee_arenas:
		described = described and String(e.name) != "" and (e.pillars as Array).size() == ProcMap.COLISEE_PILLARS \
			and (e.flowers as Array).size() >= 1 and (e.flowers as Array).size() <= 2
	check("%d arènes décrites (nom, centre, 4 piliers, 1-2 fleurs)" % count, described)
	var names := {}
	var flat := true
	var walls := true
	var pillar_r := true
	for e in m.colisee_arenas:
		names[String(e.name)] = true
		var c: Vector3 = e.center
		for k in 16:
			var a := TAU * k / 16.0
			for r in [0.0, 8.0, 16.0, 22.0]:
				if absf(m.height_at(c.x + cos(a) * r, c.z + sin(a) * r) - c.y) > 0.05:
					flat = false
		for p in e.pillars:
			if absf(Vector2(p.x - c.x, p.z - c.z).length() - ProcMap.COLISEE_PILLAR_R) > 0.1:
				pillar_r = false
	# entre deux arènes voisines (même rangée) : une falaise infranchissable
	var cols := 2 if count <= 4 else 3
	for e in m.colisee_arenas:
		var k := int(e.index)
		if k % cols < cols - 1 and k + 1 < count:
			var a: Vector3 = e.center
			var b: Vector3 = m.colisee_arenas[k + 1].center
			var mid := (a + b) * 0.5
			if m.height_at(mid.x, mid.z) - a.y < 30.0 or absf(b.x - a.x - ProcMap.COLISEE_SPACING) > 0.1:
				walls = false
	check("%d arènes : noms différents" % count, names.size() == count)
	check("%d arènes : sol plat jusqu'à 22 m du centre (anneau de feu)" % count, flat)
	check("%d arènes : piliers à %d m du centre" % [count, int(ProcMap.COLISEE_PILLAR_R)], pillar_r)
	check("%d arènes : falaise de plus de 30 m entre deux arènes voisines, %d m d'écart" % [count, int(ProcMap.COLISEE_SPACING)], walls)
	# arènes posées sous un nœud : anneau et fleurs
	var holder := Node3D.new()
	add_child(holder)
	var arenas := ColiseeArena.build_all(m, holder)
	var built := arenas.size() == count
	for a in arenas:
		built = built and a.ring != null and a.flowers.size() == (a.info.flowers as Array).size()
	check("%d ColiseeArena, chacune avec son anneau et ses fleurs" % count, built)
	var a0: ColiseeArena = arenas[0]
	var s0 := a0.spawn_point(0, 0, m)
	var s1 := a0.spawn_point(1, 2, m)
	check("points de départ : camps face à face, dans l'anneau", s0.distance_to(a0.center) < ColiseeRing.START_R
		and s1.distance_to(a0.center) < ColiseeRing.START_R and signf(s0.z - a0.center.z) != signf(s1.z - a0.center.z))
	a0.set_shown(false)
	check("arène cachée : rien de dessiné", not a0.ring.is_visible_in_tree() and not (a0.flowers[0] as Node3D).is_visible_in_tree())
	holder.queue_free()
	m.queue_free()
	await get_tree().process_frame


func _ring_curve() -> void:
	var r := ColiseeRing
	check("anneau : 22 m au départ et jusqu'à 25 s", is_equal_approx(r.radius_at(0.0), 22.0) and is_equal_approx(r.radius_at(24.9), 22.0))
	check("anneau : 22 -> 16 m entre 25 et 27 s", is_equal_approx(r.radius_at(26.0), 19.0) and is_equal_approx(r.radius_at(27.0), 16.0))
	check("anneau : 11 m à 42 s, 6 m à 57 s, 3 m à 72 s et après", is_equal_approx(r.radius_at(42.0), 11.0)
		and is_equal_approx(r.radius_at(57.0), 6.0) and is_equal_approx(r.radius_at(72.0), 3.0) and is_equal_approx(r.radius_at(200.0), 3.0))
	check("prochain resserrement : dans 5 s vers 16 m (à 20 s), plus rien après 70 s", is_equal_approx(float(r.next_after(20.0)["in"]), 5.0)
		and is_equal_approx(float(r.next_after(20.0).radius), 16.0) and r.next_after(71.0).is_empty())


func _dummy(at: Vector3) -> Combatant:
	var c := Combatant.new()
	add_child(c)
	c.set_physics_process(false)
	c.global_position = at
	c.max_hp = 1000.0
	c.hp = 1000.0
	return c


func _ring_damage() -> void:
	var ring := ColiseeRing.new()
	add_child(ring)
	ring.setup(Vector3.ZERO)
	var inside := _dummy(Vector3(5, 0, 0))
	var out := _dummy(Vector3(25, 0, 0))
	var warned: Array = []
	ring.warned.connect(func(s, nr): warned.append([snappedf(s, 0.01), nr]))
	var dt := 1.0 / 60.0
	for _i in 60:
		ring.advance(dt, [inside, out])
	var lost := 1000.0 - out.hp + float(ring._out[out.get_instance_id()][1])  # (versé par paquets de 0,25 s : + ce qui attend)
	# 1 s dehors : 5 % + rampe (2 %/s, moyenne 1 %) ≈ 6 %
	check("1 s hors de l'anneau : ≈ 6 %% des PV (%d)" % int(lost), lost >= 50.0 and lost <= 65.0)
	check("dedans : aucun dégât", is_equal_approx(inside.hp, 1000.0))
	check("dehors : soins reçus divisés par deux", is_equal_approx(out.heal_taken, ColiseeRing.HEAL_OUT) and is_equal_approx(inside.heal_taken, 1.0))
	out.hp = 500.0
	out.heal(100.0)
	check("soin dehors : 50 au lieu de 100", is_equal_approx(out.hp, 550.0))
	out.hp = 1000.0
	for _i in 120:
		ring.advance(dt, [inside, out])
	lost = 1000.0 - out.hp
	# de 1 à 3 s : 2 × 5 % + 2 % × (9 - 1) / 2 = 18 %
	check("la rampe monte : 2 s de plus dehors ≈ 18 %% (%d)" % int(lost), lost >= 160.0 and lost <= 195.0)
	out.global_position = Vector3(3, 0, 0)
	ring.advance(dt, [inside, out])
	check("rentrer remet le compteur à zéro et les soins à 1", is_equal_approx(ring.outside_time(out), 0.0) and is_equal_approx(out.heal_taken, 1.0))
	for _i in int(60 * 30):
		ring.advance(dt, [inside, out])
	check("annonce 4 s avant le 1er resserrement (%s)" % str(warned), warned.size() >= 1 and absf(float(warned[0][0]) - 4.0) < 0.05
		and is_equal_approx(float(warned[0][1]), 16.0))
	check("à 33 s : rayon 16 m, la cible à 5 m n'est pas touchée", is_equal_approx(ring.radius, 16.0) and is_equal_approx(inside.hp, 1000.0))
	ring.reset([inside, out])
	check("nouvelle manche : 22 m, temps 0", is_equal_approx(ring.radius, 22.0) and is_equal_approx(ring.t, 0.0))
	ring.queue_free()
	inside.queue_free()
	out.queue_free()
	await get_tree().process_frame


func _flower() -> void:
	var f := ColiseeFlower.new()
	add_child(f)
	f.global_position = Vector3(50, 0, 0)
	var far := _dummy(Vector3(55, 0, 0))
	var on := _dummy(Vector3(50.5, 0, 0))
	on.hp = 400.0
	var dead := _dummy(Vector3(50, 0, 0.2))
	dead.is_dead = true
	f.tick(0.016, [dead, far, on])
	check("fleur : le héros vivant dessus est soigné de 15 %% (%d PV)" % int(on.hp), is_equal_approx(on.hp, 550.0))
	check("fleur : bouclier (barrière) et elle repousse", on.has_status("barrier") and not f.ready_now)
	var hp := on.hp
	f.tick(0.016, [on])
	check("fleur : une seule fois avant de repousser", is_equal_approx(on.hp, hp))
	for _i in int(20.0 / 0.25) + 1:
		f.tick(0.25, [])
	check("fleur : repoussée après 20 s", f.ready_now)
	f.queue_free()
	far.queue_free()
	on.queue_free()
	dead.queue_free()
	await get_tree().process_frame
