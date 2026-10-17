extends Node
## Lot TAC-3 : la Charge de L'Assaut (AssaultCharge + AssaultDirector). Bips qui accélèrent (pur) ; partie réelle sur le
## Bourg, 8 IA, héros tenus à la main (passifs, posés) : porteur choisi (pas celui qui ouvre), la Charge sur son dos ; porteur
## à terre -> Charge au sol, vue par l'Attaque toujours, par la Défense seulement si elle voit l'endroit ; ramassée en passant ;
## pose annulée par un contrôle, puis faite (mèche, bips, mini-carte) ; désamorçage interrompu -> repris à la moitié, puis
## réussi ; manche suivante : la mèche va au bout, l'explosion emporte les héros proches. Puis le joueur : il porte la
## Charge quand il attaque, la lâche ([G]) et la ramasse.
## godot --headless --path game res://tests/test_tac3.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_pure()
	await _watch_game()
	await _player_game()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _pure() -> void:
	var a := AssaultCharge.beep_interval(40.0, 40.0)
	var b := AssaultCharge.beep_interval(20.0, 40.0)
	var c := AssaultCharge.beep_interval(11.0, 40.0)
	var e := AssaultCharge.beep_interval(9.0, 40.0)
	var z := AssaultCharge.beep_interval(0.2, 40.0)
	check("bips : 1 s au début, de plus en plus serrés (%.2f %.2f %.2f %.2f %.2f)" % [a, b, c, e, z],
		is_equal_approx(a, 1.0) and b < a and c < b and e < c * 0.6 and z <= 0.15 and z >= AssaultCharge.BEEP_FAST)
	check("règles de la Charge dans le profil assault", is_equal_approx(Assault.num("pickup_radius"), 1.5)
		and is_equal_approx(Assault.num("blast_radius"), 9.0))


func _launch(o: Dictionary) -> AssaultDirector:
	Assault.launch("warrior", o)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	await _until(func(): return world.director.map != null and world.director.map._region.navigation_mesh != null, 3600)
	_world = world
	return world.director.team


var _world: Node


func _watch_game() -> void:
	Profile.selected_class = "warrior"
	var dd: AssaultDirector = await _launch({"map": "bourg", "watch": true, "seed": 31, "speed": 2.0, "win": 2, "half": 6,
		"buy_time": 1.0, "buy_time_first": 1.0, "round_time": 90.0, "banner": 0.5, "fuse": 30.0, "overtime": false})
	await _until(func(): return Assault.phase == "live", 600)
	_freeze(dd)
	var att := Assault.attack
	var def := Assault.defense()
	check("porteur : un attaquant, pas celui qui ouvre (%s)" % dd.carrier, Assault.team_of(dd.carrier) == att
		and not dd.carrier.ends_with("_0"))
	var c0 := dd.hero(dd.carrier)
	check("la Charge est sur son dos", dd.charge != null and dd.charge.state == "carried" and c0 != null
		and c0.has_node("AssaultChargePack") and dd.charge.holder == c0)
	# porteur à terre : la Charge tombe à ses pieds
	var where := c0.global_position
	var was := dd.carrier
	c0.take_damage(c0.max_hp * 50.0, null, false, true)
	await _frames(4)
	check("porteur à terre : la Charge au sol, sans porteur", dd.charge.state == "ground" and dd.carrier == ""
		and _flat(dd.charge.global_position, where) < 1.5 and not Assault.alive.get(was, true))
	# vue : l'Attaque la voit toujours ; la Défense seulement si elle voit l'endroit
	_park(dd, def, dd.layout.spawns.defense.pos)
	await _frames(3)
	var far := _flat(dd.layout.spawns.defense.pos, dd.charge.global_position)
	check("l'Attaque voit la Charge au sol", dd.charge_seen(att))
	check("la Défense loin (%.0f m) ne la voit pas" % far, far < AssaultVision.RANGE or not dd.charge_seen(def))
	var d0 := dd.hero(String(Assault.alive_keys(def)[0]))
	d0.global_position = dd.charge.global_position + Vector3(2.5, 0.5, 0)
	await _frames(3)
	check("un défenseur tout près la voit", dd.charge_seen(def))
	check("mini-carte : la Charge pour l'équipe regardée qui la voit", dd.markers().size() == 1 and String(dd.markers()[0][1]) == "drop")
	_park(dd, def, dd.layout.spawns.defense.pos)
	# ramassée en passant
	var picker := String(Assault.alive_keys(att)[0])
	dd.hero(picker).global_position = dd.charge.global_position + Vector3(0.6, 0.4, 0)
	await _until(func(): return dd.carrier != "", 60)
	check("ramassée en passant par %s" % picker, dd.carrier == picker and dd.charge.state == "carried")
	# pose : le porteur au point de pose de A, la Défense au loin ; un contrôle annule la pose
	var site_a := dd.site_pos("A")
	var h := dd.hero(picker) as ClassRival
	h.global_position = site_a + Vector3.UP * 0.4
	h.velocity = Vector3.ZERO
	h.passive = false
	await _until(func(): return dd.plant_t > 1.2 or Assault.phase != "live", 900)
	check("le porteur pose (%.1f s)" % dd.plant_t, dd.plant_by == picker and dd.plant_t > 1.2)
	h.add_status("stun", 1.5, null)
	await _frames(2)
	check("un contrôle subi annule la pose", dd.plant_t == 0.0 and Assault.phase == "live")
	await _until(func(): return Assault.phase == "planted", 1800)
	check("Charge posée en A (%s, %s, %.1f m, porteur « %s »)" % [Assault.phase, Assault.site, _flat(dd.charge.global_position, site_a),
		dd.carrier], Assault.phase == "planted" and Assault.site == "A" and dd.charge.state == "planted"
		and dd.site_at(dd.charge.global_position) == "A" and dd.carrier == "")
	var b0 := dd.charge.beeps
	await _until(func(): return dd.charge.beeps >= b0 + 2, 600)
	check("bips après la pose (%d)" % dd.charge.beeps, dd.charge.beeps >= b0 + 2)
	check("posée : la Défense la connaît (mini-carte, vue)", dd.charge_seen(def) and dd.markers().size() == 1)
	_freeze(dd)
	_park(dd, att, dd.layout.spawns.attack.pos)  # (un attaquant à moins de 9 m empêche de désamorcer)
	# désamorçage interrompu à plus de la moitié -> repris à la moitié
	var dk := String(Assault.alive_keys(def)[0])
	var dh := dd.hero(dk) as ClassRival
	dh.global_position = dd.charge.global_position + Vector3(0.8, 0.4, 0)
	dh.velocity = Vector3.ZERO  # (il reste passif : il désamorce sans se battre)
	await _until(func(): return dd.defuse_t > 4.2 or Assault.phase != "planted", 900)
	check("un défenseur désamorce (%.1f s)" % dd.defuse_t, dd.defuse_by == dk and dd.defuse_t > 4.2)
	dh.add_status("stun", 1.2, null)
	await _frames(2)
	check("interrompu après la moitié : sauvegarde à 3,5 s (%.2f)" % dd.defuse_t, dd.defuse_by == ""
		and is_equal_approx(dd.defuse_t, 3.5))
	await _until(func(): return Assault.phase != "planted", 1800)
	check("puis désamorcée : la Défense gagne la manche", Assault.history.size() >= 1 and String(Assault.history[0].how) == "defuse"
		and dd.charge.state == "defused")
	# manche 2 : la mèche (raccourcie) va au bout, l'explosion emporte les héros proches
	Assault.opts["fuse"] = 4.0
	await _until(func(): return Assault.round_n >= 2 and Assault.phase == "live", 900)
	_freeze(dd)
	att = Assault.attack
	def = Assault.defense()
	_park(dd, def, dd.layout.spawns.defense.pos)
	var ck := dd.carrier
	var near := ""
	for k in Assault.alive_keys(att):
		if String(k) != ck:
			near = String(k)
			break
	var site_b := dd.site_pos("B")
	var ch := dd.hero(ck) as ClassRival
	ch.global_position = site_b + Vector3.UP * 0.4
	ch.velocity = Vector3.ZERO
	ch.passive = false
	dd.hero(near).global_position = site_b + Vector3(3.0, 0.4, 0.0)
	await _until(func(): return Assault.phase != "live", 1800)
	check("manche 2 : posée en B", Assault.phase == "planted" and Assault.site == "B")
	_freeze(dd)
	await _until(func(): return Assault.phase != "planted", 900)
	check("la mèche va au bout : l'Attaque gagne (Charge)", Assault.history.size() >= 2 and String(Assault.history[1].how) == "charge"
		and dd.charge.state == "exploded")
	check("l'explosion emporte les héros proches (%s)" % str(dd.blasted), near in dd.blasted and ck in dd.blasted
		and not Assault.alive.get(near, true))
	check("les défenseurs au loin survivent", Assault.alive_keys(def).size() == 4)
	await _until(func(): return dd._ended, 2400)
	check("partie finie", dd._ended)
	check("aucun coup entre équipiers", dd.friendly_hits == 0)
	await _close()


func _player_game() -> void:
	Profile.selected_class = "warrior"
	var dd: AssaultDirector = await _launch({"map": "bourg", "seed": 5, "speed": 2.0, "win": 1, "first_attack": 0,
		"buy_time": 1.0, "buy_time_first": 1.0, "round_time": 60.0, "banner": 0.5})
	await _until(func(): return Assault.phase == "live", 600)
	_freeze(dd)
	var p := _world.player as Player
	check("tu attaques : tu portes la Charge", dd.carrier == "t0_0" and dd.charge.holder == p and p.has_node("AssaultChargePack"))
	await _frames(3)
	check("invite : [G] la lâcher", dd._prompt.begins_with("Tu portes la Charge"))
	dd._drop_charge(p.global_position + Vector3(3.0, 0, 0), "drop")
	check("lâchée : au sol, plus sur ton dos", dd.charge.state == "ground" and dd.carrier == "" and not p.has_node("AssaultChargePack"))
	p.global_position = dd.charge.global_position + Vector3(0, 0.4, 0)
	await _until(func(): return dd.carrier != "", 60)
	check("ramassée en passant", dd.carrier == "t0_0" and dd.charge.state == "carried")
	TeamMatch.abandon()
	await _until(func(): return dd._ended, 300)
	check("abandon : partie finie", dd._ended and not TeamMatch.active)
	await _close()


func _close() -> void:
	get_tree().paused = false
	if is_instance_valid(_world):
		_world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false


func _freeze(dd: AssaultDirector) -> void:
	for k in dd.heroes:
		var h := dd.hero(String(k)) as ClassRival
		if h != null:
			h.passive = true
			h.velocity = Vector3.ZERO


## Héros debout de l'équipe [param t] posés en rang près de [param at], passifs.
func _park(dd: AssaultDirector, t: int, at: Vector3) -> void:
	var i := 0
	for k in Assault.alive_keys(t):
		var h := dd.hero(String(k)) as ClassRival
		if h != null:
			h.passive = true
			h.velocity = Vector3.ZERO
			h.global_position = at + Vector3((i - 1.5) * 2.5, 0.5, 0)
		i += 1


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
