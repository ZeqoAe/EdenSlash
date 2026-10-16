extends Node
## Battle royale, lot BR4 : largage depuis l'aigle (saut à la touche, chute dirigée, piqué, planeur, atterrissage,
## saut automatique en fin de vol, héros scriptés et pilote automatique qui visent un coffre) et réanimation
## (une fois dans les deux premières minutes, arme seule, protégé à l'atterrissage ; définitive ensuite).
## godot --headless --path game res://tests/test_br4.tscn

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	await _test_manual_and_revive()
	await _test_auto_jump()
	await _test_autoplay()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _boot() -> RoyaleDirector:
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.start("magician")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	var waited := 0.0
	while waited < 60.0 and not (world.get("director") != null and world.director.royale != null and world.director.royale.ais.size() == 7):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	world.cards._queue.clear()
	world.cards._show_next()
	return world.director.royale


func _end() -> void:
	world.queue_free()
	Royale.active = false
	Run.active = false
	Profile.in_run = false
	await get_tree().create_timer(0.5).timeout


## Attend (au plus [param limit] s) que [param cond] soit vraie.
func _until(cond: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit and not cond.call():
		if is_instance_valid(world) and world.cards.is_open():
			world.cards._queue.clear()  # (un niveau gagné ouvre un choix de carte qui met la partie en pause)
			world.cards._show_next()
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(action)


func _test_manual_and_revive() -> void:
	var rd: RoyaleDirector = await _boot()
	var p: Player = world.player
	var j := rd.jump
	var bnd: Rect2 = rd.d.map.bounds
	check("vol tracé d'un bord à l'autre (%.0f s)" % j.duration, j.duration >= 8.0 and j.duration <= 30.0
		and bnd.has_point(Vector2(j.a.x, j.a.z)) and bnd.has_point(Vector2(j.b.x, j.b.z)) and Vector2(j.a.x - j.b.x, j.a.z - j.b.z).length() > 250.0)
	check("aigle posé, joueur à bord, caché, sans physique", is_instance_valid(j.eagle) and j.on_board(p) and not p.visible and not p.is_physics_processing())
	check("personne n'est attaquable à bord (chacun pour soi vide)", get_tree().get_nodes_in_group("ffa").is_empty())
	check("aide : portes fermées (« %s »)" % rd.drop_hint(), rd.drop_hint().begins_with("Saut possible"))
	check("horloge du HUD : largage", rd.clock_text().begins_with("Largage"))
	var jts: Array = rd.ais.map(func(a): return float(j.riders[a].jump_t))
	check("sauts répartis sur le vol (%.0f à %.0f s)" % [jts.min(), jts.max()], float(jts.max()) - float(jts.min()) > j.duration * 0.35)
	await _until(func(): return j.t > Royale.COUNTDOWN + 0.3, 10.0)
	check("aide : touche Sauter (« %s »)" % rd.drop_hint(), rd.drop_hint().contains("Sauter"))
	check("à bord, le joueur suit l'aigle", Vector2(p.global_position.x - j.eagle_pos().x, p.global_position.z - j.eagle_pos().z).length() < 1.0)
	# saut manuel
	await _tap("jump")
	check("touche Sauter : le joueur saute (%s)" % String(j.riders.get(p, {}).get("state", "sol")), j.airborne(p) and String(j.riders[p].state) == "fall" and p.visible)
	check("aide en chute : piqué et planeur", rd.drop_hint().contains("Piqué"))
	# chute dirigée
	var y0 := p.global_position.y
	var x0 := Vector2(p.global_position.x, p.global_position.z)
	Input.action_press("move_right")
	await get_tree().create_timer(0.8).timeout
	Input.action_release("move_right")
	var moved := Vector2(p.global_position.x, p.global_position.z).distance_to(x0)
	check("chute dirigée : %.1f m à l'horizontale en 0,8 s" % moved, moved > 6.0)
	var fall_free := y0 - p.global_position.y
	y0 = p.global_position.y
	Input.action_press("dodge")
	await get_tree().create_timer(0.8).timeout
	Input.action_release("dodge")
	var fall_dive := y0 - p.global_position.y
	check("piqué : chute plus rapide (%.1f m contre %.1f m)" % [fall_dive, fall_free], fall_dive > fall_free * 1.5)
	check("en l'air : ni coffre ni chacun pour soi", not p.is_in_group("ffa") and not rd.player_grounded())
	await _until(func(): return not j.airborne(p) or String(j.riders[p].state) == "glide", 20.0)
	var h: float = p.global_position.y - rd.d.map.height_at(p.global_position.x, p.global_position.z)
	check("planeur ouvert seul à basse altitude (%.0f m)" % h, j.airborne(p) and String(j.riders[p].state) == "glide" and h <= RoyaleDrop.GLIDE_AT + 1.0
		and j.riders[p].glider != null)
	await _until(func(): return not j.airborne(p), 20.0)
	var g: float = rd.d.map.height_at(p.global_position.x, p.global_position.z)
	check("atterrissage : la main au joueur (physique, chacun pour soi, au sol)", p.is_physics_processing() and p.is_in_group("ffa") and p.ffa_id == 0
		and absf(p.global_position.y - g) < 2.0 and rd.player_grounded())
	check("caméra revenue à sa distance", absf(world.rig.distance - float(Settings.get_v("camera", "distance"))) < 0.5)
	# tout le monde au sol : l'anneau démarre
	await _until(func(): return rd.phase == "fight", 45.0)
	check("tous au sol : l'anneau démarre (combat %.1f s, horloge %.1f s)" % [rd.elapsed, rd.clock], rd.phase == "fight" and j.count_airborne() == 0 and rd.elapsed < rd.clock)
	var near := 0
	for a in rd.ais:
		if is_instance_valid(a) and not a.passive and a.is_in_group("ffa"):
			near += 1
	check("les héros scriptés ont atterri et jouent (%d / 7)" % near, near >= 6)
	for a in rd.ais:
		if is_instance_valid(a):
			a.passive = true  # (la suite compte les vivants : plus de combats entre eux)
	# --- réanimation d'un héros scripté (avant 2 min)
	rd.elapsed = 30.0
	var k := 2
	var victim: ClassRival = rd.ais[k]
	var st: Dictionary = victim.get_meta("royale")
	st.lv = 6
	st.gear["weapon"] = Items.generate(6, 0.5, "weapon", String(st.cid), 0, "", 2)
	st.gear["chest"] = Items.generate(6, 0.5, "chest", String(st.cid), 0, "", 2)
	Royale.refresh_ai(victim)
	var alive0 := rd.alive_count()
	var kills0 := Royale.kills
	victim.hp = 1.0
	victim.take_damage(1e9, p, false)
	await get_tree().physics_frame
	check("scripté tombé avant 2 min : il reviendra (pas de place, toujours compté en vie)", not st.has("place") and rd.alive_count() == alive0 and rd.revives.size() == 1)
	check("élimination comptée une fois (%d)" % Royale.kills, Royale.kills == kills0 + 1 and String(rd.kill_feed.back()[0]).contains("reviendra"))
	await _until(func(): return rd.ais[k] != victim, Royale.REVIVE_DELAY + 3.0)
	var back: ClassRival = rd.ais[k]
	check("retour après %d s : nouveau corps, même fiche, niveau gardé" % int(Royale.REVIVE_DELAY), back != victim and is_instance_valid(back) and not back.is_dead
		and back.get_meta("royale") == st and int(st.lv) == 6 and back.level == 6)
	check("revenant : arme seule (pièces lâchées)", st.gear.has("weapon") and st.gear.size() == 1)
	check("retour en planeur, hors d'atteinte", j.airborne(back) and String(j.riders[back].state) == "glide" and not back.is_in_group("ffa"))
	await _until(func(): return not j.airborne(back), 15.0)
	check("revenant au sol : protégé quelques secondes", back.is_in_group("ffa") and back.is_invulnerable())
	back.passive = true
	back._invuln_until = 0.0
	back.hp = 1.0
	back.take_damage(1e9, p, false)
	await get_tree().physics_frame
	check("2e chute : définitive, place fixée, élimination pas comptée deux fois", st.has("place") and Royale.kills == kills0 + 1 and rd.alive_count() == alive0 - 1)
	# --- réanimation du joueur (avant 2 min), arme seule
	Profile.equipped["chest"] = Items.generate(6, 0.5, "chest", "magician", 0, "", 2)
	var lv := p.level
	var alive1 := rd.alive_count()
	p.hp = 1.0
	p.take_damage(1e9, rd.ais[4], false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("joueur tombé avant 2 min : pas spectateur, retour annoncé (« %s »)" % rd.drop_hint(), p.is_dead and not rd.spectating and rd.drop_hint().begins_with("Tu es éliminé : retour dans")
		and rd.alive_count() == alive1)
	await _until(func(): return not p.is_dead, Royale.REVIVE_DELAY + 3.0)
	check("retour : PV pleins, niveau gardé, en planeur", not p.is_dead and is_equal_approx(p.hp, p.max_hp) and p.level == lv and j.airborne(p))
	check("joueur revenant : arme seule", not Profile.equipped.has("chest"))
	await _until(func(): return not j.airborne(p), 15.0)
	var hp1 := p.hp
	rd.ais[4].passive = true
	p.take_damage(500.0, rd.ais[4], false)
	check("joueur revenant au sol : protégé (%d -> %d PV)" % [hp1, p.hp], p.is_invulnerable() and is_equal_approx(p.hp, hp1))
	# --- après 2 min : mort définitive
	rd.elapsed = Royale.REVIVE_WINDOW + 5.0
	var other: ClassRival = rd.ais[5]
	var st5: Dictionary = other.get_meta("royale")
	other.hp = 1.0
	other.take_damage(1e9, p, false)
	await get_tree().physics_frame
	check("scripté tombé après 2 min : définitif", st5.has("place") and rd.revives.is_empty())
	p.shield_until = 0.0
	p.hp = 1.0
	p.take_damage(1e9, rd.ais[6], false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("joueur déjà revenu : 2e chute définitive (spectateur, place %d)" % rd._place, rd.spectating and rd._place >= 2 and rd.revives.is_empty())
	await _end()


func _test_auto_jump() -> void:
	var rd: RoyaleDirector = await _boot()
	var p: Player = world.player
	rd.jump.t = rd.jump.duration - 0.3
	await _until(func(): return not rd.jump.on_board(p), 3.0)
	check("fin du vol : saut automatique", rd.jump.airborne(p) and not rd.jump.on_board(p))
	await _until(func(): return rd.phase == "fight", 45.0)
	check("tout le monde au sol après le vol", rd.phase == "fight" and rd.jump.count_airborne() == 0 and rd.player_grounded())
	await _end()


func _test_autoplay() -> void:
	var rd: RoyaleDirector = await _boot()
	var p: Player = world.player
	p.autoplay = true
	var target: Vector3 = rd.jump.riders[p].target
	await _until(func(): return not rd.jump.airborne(p), 45.0)
	var dd := Vector2(p.global_position.x - target.x, p.global_position.z - target.z).length()
	check("pilote automatique : saute et atterrit près de son coffre (%.1f m)" % dd, not rd.jump.airborne(p) and dd < 6.0)
	await _until(func(): return rd.chests_opened >= 1, 15.0)
	check("... puis ouvre un coffre", rd.chests_opened >= 1)
	await _end()
