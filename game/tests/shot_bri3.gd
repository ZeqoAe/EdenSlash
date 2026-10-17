extends Node
## Captures du lot BR-I3 (Battle royale, backlog P1-P2) : aide du largage à touches dessinées, chute avec altimètre, combat
## (cadre de cible v2, plaques ▲ ▼ et intention, annonce centrale, chiffres sobres, « Voir les sons », noms des lieux sur
## la mini-carte), couleurs pour daltoniens, bandeau du spectateur (user://shots/bri3_*.png).
## Taille : variable BRI3_RES (« 1280x720 », défaut 1600x900).
## godot --path game res://tests/shot_bri3.tscn

var world: Node
var _tag := ""


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/bri3_%s%s.png" % [name, _tag])
	print("[shot] bri3_%s%s %s" % [name, _tag, str(get_viewport().get_visible_rect().size)])


func _cards() -> void:
	if world.get("cards") != null and world.cards.is_open():
		world.cards._queue.clear()
		world.cards._show_next()


func _wait(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit and not cond.call():
		_cards()
		await get_tree().process_frame
		t += get_process_delta_time()


func _frames(n: int) -> void:
	for i in n:
		_cards()
		await get_tree().process_frame


func _place(c: Node3D, at: Vector3) -> void:
	at.y = float(world.director.map.height_at(at.x, at.z)) + 0.1
	c.global_position = at
	if c == world.player and world.rig != null:
		world.rig.global_position = at


func _ready() -> void:
	var res := OS.get_environment("BRI3_RES")
	var sz := Vector2i(1600, 900)
	if res.contains("x"):
		sz = Vector2i(int(res.get_slice("x", 0)), int(res.get_slice("x", 1)))
		_tag = "_%d" % sz.y
	Settings.reset_all()  # (avant la taille : il applique la résolution des réglages)
	DisplayServer.window_set_size(sz)
	get_window().size = sz
	Profile.reset_all()
	Royale.difficulty = 0
	Royale.start("magician")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _wait(func(): return world.get("director") != null and world.director.royale != null and world.director.royale.jump != null, 60.0)
	var rd: RoyaleDirector = world.director.royale
	var j := rd.jump
	var p: Player = world.player
	var rh: RoyaleHud = world.hud.get("_royale")
	await _wait(func(): return rh.map.is_open and j.t > Royale.COUNTDOWN + 1.0, 20.0)
	rh.map.close()
	await _frames(6)
	var ln := rh.drop_hint.line
	print("[bri3] aide du largage : « %s » · visible %s · %s" % [ln.text, str(ln.is_visible_in_tree()), str(ln.get_global_rect())])
	await _shot("1_a_bord")
	var best := Vector3.INF
	for it in rd.d.map.interactables:
		if is_instance_valid(it) and it.kind == "chest" and int(it.get_meta("tier", 0)) >= 1 and rh.map.reachable(it.global_position):
			best = it.global_position
			break
	RoyalePing.toggle(best if best != Vector3.INF else j.b * Vector3(1, 0, 1))
	j.jump(p)
	await _wait(func(): return j.riders.has(p) and float(j.riders[p].air) > 1.0, 6.0)
	await _frames(4)
	await _shot("2_chute")
	j.land_all()
	await _wait(func(): return rd.phase == "fight", 20.0)
	await get_tree().create_timer(1.0).timeout
	# combat : près d'un lieu nommé, une cible verrouillée, un autre héros dans la vue, une annonce, des chiffres, des sons
	var places: Array = rd.places()
	var spot: Vector3 = p.global_position
	if not places.is_empty():
		spot = (places[0].pos as Vector3) + Vector3(22, 0, 14)
	_place(p, spot)
	RoyalePing.reset()
	await _frames(20)
	var cam := get_viewport().get_camera_3d()
	var foes: Array = rd.ais.filter(func(r): return is_instance_valid(r) and not r.is_dead and r.is_in_group("ffa"))
	var a: ClassRival = foes[0] if foes.size() > 0 else null
	var b: ClassRival = foes[1] if foes.size() > 1 else null
	for r in foes:
		r.passive = true
		if r != a and r != b:
			_place(r, p.global_position + Vector3(220, 0, 220))
	if a != null:
		_place(a, p.global_position + Vector3(6, 0, -3).rotated(Vector3.UP, cam.global_rotation.y))
		a.get_meta("royale").mode = "F"
		a.hp = a.max_hp * 0.62
		rd._refresh_tag(a)
		p._target = a
	if b != null:
		_place(b, p.global_position + Vector3(-8, 0, -8).rotated(Vector3.UP, cam.global_rotation.y))
		b.get_meta("royale").mode = "L"
		rd._refresh_tag(b)
	rd.feed("Tu élimines Assassin")
	rd.feed("Chasseur élimine Prêtre")
	Settings.set_v("interface", "sound_cues", true)
	RoyaleCues.heard(p.global_position + Vector3(-30, 0, 4).rotated(Vector3.UP, cam.global_rotation.y), "chest")
	RoyaleCues.heard(p.global_position + Vector3(20, 0, 28).rotated(Vector3.UP, cam.global_rotation.y), "fight")
	await _frames(2)
	if a != null:
		a.set_meta("rc_hit_ms", Time.get_ticks_msec())
		DamageNumber.spawn(a, 184.0, false, false)
		DamageNumber.spawn(a, 96.0, false, false)
		DamageNumber.spawn(a, 61.0, true, false)
	rd.d.message.emit("Mis à prix !\nChasseur : élimine-le, un niveau de plus", 4.0)
	await get_tree().create_timer(0.45).timeout
	await _shot("3_combat")
	# daltoniens : dehors, coup reçu
	Settings.set_v("interface", "colorblind", true)
	var c: Vector2 = rd.ring.center
	var out := c + Vector2(1, 0.2).normalized() * (float(rd.ring.radius) + 25.0)
	_place(p, Vector3(out.x, 0, out.y))
	await _frames(15)
	cam = get_viewport().get_camera_3d()
	if a != null:
		_place(a, p.global_position + Vector3(6, 0, 1).rotated(Vector3.UP, cam.global_rotation.y))
		rd._refresh_tag(a)
		p.evasion_chance = 0.0
		p.parry_chance = 0.0
		p.take_damage(30.0, a, false)
	rd.d.message.emit("Hors de l'anneau !\nSuis la flèche violette", 3.0)
	await get_tree().create_timer(0.45).timeout
	await _shot("4_daltoniens")
	Settings.set_v("interface", "colorblind", false)
	Settings.set_v("interface", "sound_cues", false)
	# spectateur : bandeau à touches dessinées
	_place(p, Vector3(c.x, 0, c.y))
	rd.elapsed = Royale.REVIVE_WINDOW + 5.0
	await _frames(4)
	p.hp = 1.0
	p.take_damage(1e9, a, false)
	await _wait(func(): return rd.spectating and rd.recap_view != null, 6.0)
	if rd.recap_view != null:
		rd.recap_view.watch()
	await get_tree().create_timer(0.6).timeout
	await _shot("5_spectateur")
	get_tree().quit()
