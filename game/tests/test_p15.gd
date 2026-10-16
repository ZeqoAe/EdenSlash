extends Node
## Passe P15 (conception/nuit_15_10/R_P15.md) : apparition des monstres de la Survie (SpawnDirector) : rôles et
## espèces mélangés, arrivées réparties autour du héros, points valides ; niveau et puissance des monstres
## (MonsterScaling) : niveau qui suit le héros, PV et dégâts selon l'équipement, bornés, lissés, plafonnés avec la
## Menace et le pacte ; boss jamais touchés.
## godot --headless --path game res://tests/test_p15.tscn

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	_test_roles()
	_test_scaling_rules()
	Profile.selected_zone = String(GameData.zones[0].id)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	var d: RunDirector = world.director
	d.set_process(false)
	world.player.immortal = true
	check("le directeur de la carte a son SpawnDirector (ancien spawn : non)", d.spawner != null and not SpawnDirector.legacy)
	_clear()
	d.state = "explore"
	d.time = RunDirector.EARLY_RAMP + 1.0
	await _test_composition(d)
	_test_angles(d)
	await _test_points(d)
	await _test_events(d)
	await _test_interface(d)
	await _test_support(d)
	_test_power(d)
	_test_level(d)
	_test_boss(d)
	print("TOUS LES TESTS PASSENT" if fails == 0 else "%d ÉCHEC(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _clear() -> void:
	for n in get_tree().get_nodes_in_group("monsters"):
		n.remove_from_group("monsters")
		n.queue_free()


func _alive() -> Array:
	return get_tree().get_nodes_in_group("monsters").filter(func(n): return not (n as Monster).is_dead)


## Rôles du bestiaire : chaque zone a au moins 4 rôles, Limestone a ses 6 (la carte 1 n'est pas que des champignons).
func _test_roles() -> void:
	var worst := 99
	var worst_zone := ""
	for z in GameData.zones:
		var roles := {}
		for r in SpawnDirector.roles_of_zone(z).values():
			roles[r] = true
		if roles.size() < worst:
			worst = roles.size()
			worst_zone = String(z.id)
	check("chaque zone a au moins 4 rôles de monstres (le moins : %s, %d)" % [worst_zone, worst], worst >= 4)
	var lime := {}
	for r in SpawnDirector.roles_of_zone(GameData.zones[0]).values():
		lime[r] = true
	check("Limestone : les 6 rôles (%s)" % [lime.keys()], lime.size() == 6)
	for r in SpawnDirector.ROLES:
		var def: Dictionary = SpawnDirector.ROLES[r]
		var per_point := float(def.hp) / float(def.cost)
		if per_point < 0.7 or per_point > 1.2:
			check("rôle %s : PV par point de budget %.2f (entre 0,7 et 1,2)" % [r, per_point], false)
	check("plafond de tireurs vivants ≤ 8, de soigneurs ≤ 3", int(SpawnDirector.ROLES.ranged.max) <= 8 and int(SpawnDirector.ROLES.support.max) <= 3)


## Bornes et lissage de la puissance, plafond de l'empilement, décalage de niveau.
func _test_scaling_rules() -> void:
	var ok := true
	var mono := true
	for e in range(1, 5):
		var band := MonsterScaling.epoch_band(e)
		var prev := Vector2.ZERO
		for i in 60:
			var idx := 0.05 + i * 0.1
			var k := MonsterScaling.target(idx, band)
			if k.x < MonsterScaling.HP_RANGE[0] - 0.001 or k.x > MonsterScaling.HP_RANGE[1] + 0.001 or k.y < MonsterScaling.ATK_RANGE[0] - 0.001 or k.y > MonsterScaling.ATK_RANGE[1] + 0.001:
				ok = false
			if i > 0 and (k.x < prev.x - 0.0001 or k.y < prev.y - 0.0001):
				mono = false
			prev = k
	check("PV ×0,9 à ×1,6, dégâts ×0,9 à ×1,4 pour tout indice et toute époque", ok)
	check("coefficients croissants avec l'indice d'équipement", mono)
	var band1 := MonsterScaling.epoch_band(1)
	check("dans la bande de l'époque : ×1 (compte neuf 0,68, pièces de la carte 0,94)",
		MonsterScaling.target(0.68, band1) == Vector2.ONE and MonsterScaling.target(0.94, band1) == Vector2.ONE)
	var opt := MonsterScaling.target(1.9, band1)
	check("équipement optimisé de l'époque I en époque I : PV ×%.2f, dégâts ×%.2f (plus forts, sous les bornes)" % [opt.x, opt.y], opt.x > 1.3 and opt.y > 1.15 and opt.x < 1.6 and opt.y < 1.4)
	var weak := MonsterScaling.target(0.68, MonsterScaling.epoch_band(3))
	check("héros faible pour l'époque III : monstres adoucis, jamais sous ×0,9 (%s)" % weak, weak.x < 1.0 and weak.x >= 0.899)
	# lissage : jamais de saut
	var k := Vector2.ONE
	var biggest := 0.0
	for i in 60:
		var nk := MonsterScaling.smooth(k, Vector2(1.6, 1.4), 2.0)
		biggest = maxf(biggest, nk.x - k.x)
		k = nk
	check("lissage : +%.3f au plus par mesure de 2 s, ×%.2f après 2 min" % [biggest, k.x], biggest < 0.03 and k.x > 1.5)
	# plafond de l'empilement (Menace au maximum et pacte)
	var c := MonsterScaling.capped(Vector2(1.6, 1.4), Menace.hp_mult(Menace.MAX) * RunDirector.GREED_MONSTERS, RunDirector.GREED_MONSTERS)
	check("Menace ×2 et pacte : puissance ramenée à ×%.2f / ×%.2f (empilement ≤ ×%.1f PV, ×%.1f dégâts)" % [c.x, c.y, MonsterScaling.STACK_HP_CAP, MonsterScaling.STACK_ATK_CAP],
		c.x * Menace.hp_mult(Menace.MAX) * RunDirector.GREED_MONSTERS <= MonsterScaling.STACK_HP_CAP + 0.001 and c.y * RunDirector.GREED_MONSTERS <= MonsterScaling.STACK_ATK_CAP + 0.001 and c.x >= 1.0)
	check("le plafond ne fait jamais baisser un héros faible sous son coefficient", MonsterScaling.capped(Vector2(0.9, 0.9), 2.5, 1.25) == Vector2(0.9, 0.9))
	check("niveau : héros %+.1f au début, %+.1f à l'heure de la rage" % [MonsterScaling.LEVEL_OFFSET[0], MonsterScaling.LEVEL_OFFSET[1]],
		is_equal_approx(MonsterScaling.level_offset(0.0, 600.0), MonsterScaling.LEVEL_OFFSET[0]) and is_equal_approx(MonsterScaling.level_offset(600.0, 600.0), MonsterScaling.LEVEL_OFFSET[1])
		and MonsterScaling.LEVEL_OFFSET[1] >= MonsterScaling.LEVEL_OFFSET[0])


## Escouades : plusieurs espèces et rôles, jamais 10 identiques, plafonds par rôle.
func _test_composition(d: RunDirector) -> void:
	var sp := d.spawner
	var worst_same := 0.0
	var roles_seen := {}
	for i in 40:
		var squad := sp._pick_squad()
		var roles := sp.compose(squad, 9.0)
		var ids := sp.species_for(roles)
		var count := {}
		for id in ids:
			count[id] = int(count.get(id, 0)) + 1
			roles_seen[SpawnDirector.role_of(id)] = true
		for id in count:
			if SpawnDirector.role_of(id) != "swarm":
				worst_same = maxf(worst_same, float(count[id]))
	check("escouades : jamais plus de %d fois la même espèce (hors essaim) (au plus %d)" % [SpawnDirector.SAME_SPECIES_MAX, int(worst_same)], worst_same <= SpawnDirector.SAME_SPECIES_MAX)
	check("40 escouades à la 5e minute : au moins 5 rôles (%s)" % [roles_seen.keys()], roles_seen.size() >= 5)
	# plafond des tireurs : 12 demandés, 8 au plus vivants
	_clear()
	await get_tree().process_frame
	var many := sp.compose({"id": "t", "roles": {"ranged": 12}}, 12.0 * float(SpawnDirector.ROLES.ranged.cost))
	check("12 tireurs demandés : %d tireurs, le reste en d'autres rôles" % many.count("ranged"), many.count("ranged") <= int(SpawnDirector.ROLES.ranged.max) and many.size() >= 10)
	# flux réel : 3 minutes de spawn
	_clear()
	await get_tree().process_frame
	var species := {}
	var biggest_same := 0
	d.time = 240.0
	for i in 12:
		sp._roam = 0.0
		sp.update(0.1, 0, 999)
		await get_tree().process_frame
		for m in _alive():
			var mo := m as Monster
			if not mo.is_elite:
				species[int(mo.data.id)] = true
		_clear()
		await get_tree().process_frame
	check("12 apparitions du flux à 4 min : %d espèces différentes (≥ 4)" % species.size(), species.size() >= 4)


## Angles : rotation d'or, de tous les côtés, deux arrivées de suite jamais du même côté.
func _test_angles(d: RunDirector) -> void:
	var sp := d.spawner
	var v := Vector2.ZERO
	var close := 0
	var prev := INF
	var sectors := {}
	for i in 40:
		var a := sp._pick_angle([])
		v += Vector2(cos(a), sin(a))
		sectors[posmod(floori(fposmod(a, TAU) / TAU * 8.0), 8)] = true
		if prev != INF and absf(angle_difference(a, prev)) < deg_to_rad(45.0):
			close += 1
		prev = a
	var r := v.length() / 40.0
	check("40 arrivées : vecteur moyen %.2f (0 = de tous les côtés ; < 0,2), %d secteurs sur 8" % [r, sectors.size()], r < 0.2 and sectors.size() == 8)
	check("deux arrivées de suite à moins de 45° : %d fois sur 39 (≤ 4)" % close, close <= 4)
	var a0 := sp._pick_angle([])
	var b := sp._pick_angle([a0])
	check("deux groupes d'un même événement à 60° au moins (%.0f°)" % rad_to_deg(absf(angle_difference(a0, b))), absf(angle_difference(a0, b)) >= deg_to_rad(SpawnDirector.MIN_GAP_DEG))


## Points : dans la carte, sur le sol, hors de la vue (≥ 18 m), reliés au héros ; hors carte refusé.
func _test_points(d: RunDirector) -> void:
	var sp := d.spawner
	var hero := d.player.global_position
	var bad := 0
	var n := 0
	for i in 30:
		var p := sp._point(randf() * TAU, SpawnDirector.RING[0], SpawnDirector.RING[1])
		if p == Vector3.INF:
			continue
		n += 1
		var dist := Vector2(p.x - hero.x, p.z - hero.z).length()
		if dist < 18.0 or not d.map.bounds.has_point(Vector2(p.x, p.z)) or d.map.ground_at(p.x, p.z) == Vector3.INF:
			bad += 1
	check("30 points d'apparition : %d trouvés, %d hors règles (dans la carte, au sol, à 18 m au moins)" % [n, bad], n >= 25 and bad == 0)
	check("point hors de la carte refusé", sp._valid(Vector3(-50, 0, -50), hero) == Vector3.INF)
	# héros collé au bord : les arrivées viennent de l'intérieur
	var was := d.player.global_position
	var mid: float = d.map.size * 0.5
	var edge_x := 8.0
	while edge_x < 150.0 and (d.map.ground_at(edge_x, mid) == Vector3.INF or d.map.ground_at(edge_x + 6.0, mid) == Vector3.INF):
		edge_x += 2.0
	d.player.global_position = Vector3(edge_x + 2.0, d.map.height_at(edge_x + 2.0, mid), mid)
	var inside := 0
	var tried := 0
	for i in 10:
		var p := sp._point(sp._pick_angle([]), SpawnDirector.RING[0], SpawnDirector.RING[1])
		if p == Vector3.INF:
			continue
		tried += 1
		if d.map.bounds.grow(-6.0).has_point(Vector2(p.x, p.z)):
			inside += 1
	check("héros au bord de la carte (x = %.0f) : %d / %d arrivées valides, toutes dans la carte" % [edge_x + 2.0, inside, tried], tried >= 6 and inside == tried)
	d.player.global_position = was
	await get_tree().process_frame


## Événements : encerclement annoncé (arrivée après les cercles), élite escortée, ruée, tenaille.
func _test_events(d: RunDirector) -> void:
	var sp := d.spawner
	for kind in ["encircle", "escort", "swarm_rush", "pincer"]:
		_clear()
		await get_tree().process_frame
		sp._event(kind, 5.0, false)
		var now := _alive().size()
		await get_tree().create_timer(SpawnDirector.WARN_TIME + 0.3).timeout
		var ms := _alive()
		var species := {}
		var elites := 0
		var sectors := {}
		var hero := d.player.global_position
		for m in ms:
			var mo := m as Monster
			if mo.is_elite:
				elites += 1
			else:
				species[int(mo.data.id)] = true
			sectors[posmod(floori(fposmod(atan2(mo.global_position.z - hero.z, mo.global_position.x - hero.x), TAU) / TAU * 8.0), 8)] = true
		match kind:
			"encircle":
				check("encerclement : rien avant les cercles d'alerte (%d), puis %d monstres sur %d secteurs, %d espèces, une élite" % [now, ms.size(), sectors.size(), species.size()],
					now == 0 and sectors.size() >= 5 and species.size() >= 3 and elites == 1)
			"escort":
				check("élite escortée : %d élite, escorte de %d espèces" % [elites, species.size()], elites == 1 and species.size() >= 2)
			"swarm_rush":
				check("ruée d'essaim : %d monstres de %d côtés" % [ms.size(), sectors.size()], ms.size() >= 8 and sectors.size() >= 3)
			_:
				check("tenaille : %d monstres de %d côtés" % [ms.size(), sectors.size()], ms.size() >= 4 and sectors.size() >= 2)


## Interface du Survivant (SurvivorDirector.update_spawns) : meute et vague à la demande.
func _test_interface(d: RunDirector) -> void:
	_clear()
	await get_tree().process_frame
	var sp := d.spawner
	sp.tick(0.1)
	var a := sp.pack(6.0, 8)
	await get_tree().process_frame
	var n := _alive().size()
	sp.wave(false, 6.0)
	await get_tree().create_timer(SpawnDirector.WARN_TIME + 0.3).timeout
	check("interface : pack() pose une escouade (%d monstres), wave() un événement (%d en tout)" % [n, _alive().size()], a != INF and n >= 4 and _alive().size() > n)


## Soigneur : soigne les monstres blessés proches.
func _test_support(d: RunDirector) -> void:
	_clear()
	await get_tree().process_frame
	var sp := d.spawner
	var heal_id := int((sp._by_role.get("support", [0]) as Array)[0])
	var melee_id := int((sp._by_role.get("melee", [0]) as Array)[0])
	var at := d.player.global_position + Vector3(12, 0, 0)
	var s := d._spawn_monster(heal_id, d.ground_point(at, at), 10)
	var m := d._spawn_monster(melee_id, d.ground_point(at + Vector3(2, 0, 0), at), 10)
	await get_tree().physics_frame
	check("le soigneur a son rôle et sa lueur", String(s.get_meta("role", "")) == "support" and s.find_children("*", "OmniLight3D", false, false).size() > 0)
	check("le soigneur garde ses distances (attaque à distance)", s.attack_kind() == "ranged")
	m.hp = m.max_hp * 0.5
	s.set_meta("heal_t", 0.0)
	sp._update_supports(0.1)
	check("impulsion du soigneur : PV de 50 %% à %.0f %%" % (m.hp / m.max_hp * 100.0), m.hp > m.max_hp * 0.55)


## Puissance : équipement optimisé = monstres plus forts ; compte neuf = inchangés ; boss jamais.
func _test_power(d: RunDirector) -> void:
	var sp := d.spawner
	var was := Profile.equipped.duplicate()
	var was_on := sp.power_on
	sp.power_on = true
	Run.hero_level = 15
	Profile.equipped = StarterGear.items(Run.class_id)
	var idx_new := MonsterScaling.gear_index()
	Profile.equipped = StarterGear.scenario("1.3.10.3", Run.class_id)
	var idx_opt := MonsterScaling.gear_index()
	check("indice d'équipement : départ %.2f, époque I optimisée %.2f" % [idx_new, idx_opt], idx_new < 0.95 and idx_opt > 1.5)
	var id := int(d._roster[0])
	sp.power = Vector2.ONE
	var base := d._spawn_monster(id, d.player.global_position + Vector3(14, 0, 0), 10)
	sp.power = MonsterScaling.target(idx_opt, MonsterScaling.epoch_band(1))
	var strong := d._spawn_monster(id, d.player.global_position + Vector3(15, 0, 0), 10)
	check("même monstre, héros optimisé : PV ×%.2f, dégâts ×%.2f" % [strong.max_hp / base.max_hp, strong.atk / base.atk],
		strong.max_hp > base.max_hp * 1.25 and strong.atk > base.atk * 1.1 and strong.max_hp <= base.max_hp * 1.601)
	Profile.equipped = was
	sp.power_on = was_on
	sp.power = Vector2.ONE


## Niveau : suit celui du héros (décalage -1 au début, 0 à l'heure de la rage), plafonné. Lot H4a : en Aventure, le niveau de
## héros de la partie (Run.hero_level), borné par la bande de la carte.
func _test_level(d: RunDirector) -> void:
	var was := Run.hero_level
	Run.hero_level = 12
	d.time = 0.0
	var early := d._monster_level(0)
	d.time = RunDirector.RUN_TIME
	var late := d._monster_level(0)
	Run.hero_level = 3
	d.time = 0.0
	var low := d._monster_level(0)
	var want_late := roundi(12.0 + MonsterScaling.LEVEL_OFFSET[1])
	check("niveau des monstres : héros 12 → %d au début, %d à 10 min ; héros 3 → %d" % [early, late, low], early == 11 and late == want_late and low <= 3)
	Run.hero_level = was
	d.time = RunDirector.EARLY_RAMP + 1.0


## Boss : ni rôle, ni puissance (PV fixes de la passe P11).
func _test_boss(d: RunDirector) -> void:
	d.spawner.power = Vector2(1.6, 1.4)
	var b := d._spawn_monster(int(d.zone.dungeon.boss), d.player.global_position + Vector3(20, 0, 0), 10, true)
	check("boss : ni rôle ni puissance appliqués", not b.has_meta("role") and not b.has_meta("power"))
	d.spawner.power = Vector2.ONE
	_clear()
