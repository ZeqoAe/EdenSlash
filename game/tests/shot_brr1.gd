extends Node
## Captures du lot BR-R1 (Battle royale : contenu et règles) : page du mode (classique, du jour, personnalisée, bas de page),
## à bord (merci l'aigle), autel du gardien et son gardien, grande carte avec l'autel, météore, trésor de l'autel, bilan avec
## la Ligue royale (user://shots/brr1_*.png). Taille : variable BRR1_RES (« 1280x720 », défaut 1600x900).
## godot --path game res://tests/shot_brr1.tscn

var world: Node
var _tag := ""


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/brr1_%s%s.png" % [name, _tag])
	print("[shot] brr1_%s%s %s" % [name, _tag, str(get_viewport().get_visible_rect().size)])


func _cards() -> void:
	if world != null and is_instance_valid(world) and world.get("cards") != null and world.cards.is_open():
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
	var res := OS.get_environment("BRR1_RES")
	var sz := Vector2i(1600, 900)
	if res.contains("x"):
		sz = Vector2i(int(res.get_slice("x", 0)), int(res.get_slice("x", 1)))
		_tag = "_%d" % sz.y
	Settings.reset_all()  # (avant la taille : il applique la résolution des réglages)
	DisplayServer.window_set_size(sz)
	get_window().size = sz
	Profile.reset_all()
	League.day_override = "2026-10-17"
	await _page()
	await _game()
	get_tree().quit()


## Page du mode : un profil qui a déjà joué (ligue Argent, carrière, voiles ouvertes).
func _page() -> void:
	Profile.records["royale_games"] = 14
	Profile.records["royale_wins"] = 2
	Profile.records["royale_podiums"] = 6
	Profile.records["royale_best"] = 1
	Profile.records["royale_kills"] = 23
	Profile.records["royale_best_kills"] = 5
	Profile.records["royale_dealt"] = 184500.0
	Profile.records["royale_altars"] = 3
	Profile.records["royale_class_wins"] = {"magician": 2}
	for i in 5:
		RoyaleLeague.report(3, 1, 2)
	Profile.records["royale_crown"] = true
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await _frames(8)
	RoyalePage.pick = "classic"
	lobby._show_menu("royale")
	await _frames(6)
	await _shot("1_page")
	lobby._scroll.scroll_vertical = 100000
	await _frames(4)
	await _shot("2_page_bas")
	RoyalePage._set_pick(lobby, "daily")
	await _frames(6)
	await _shot("3_page_du_jour")
	RoyalePage.custom_mod = "meteors"
	RoyalePage._set_pick(lobby, "custom")
	await _frames(6)
	await _shot("4_page_perso")
	RoyalePage.pick = "classic"
	lobby.queue_free()
	await _frames(4)


func _game() -> void:
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.mod = "meteors"
	Royale.start("magician")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _wait(func(): return world.get("director") != null and world.director.royale != null and world.director.royale.jump != null, 60.0)
	var rd: RoyaleDirector = world.director.royale
	var p: Player = world.player
	var rh: RoyaleHud = world.hud.get("_royale")
	await _wait(func(): return rh.map.is_open and rd.jump.t > Royale.COUNTDOWN + 1.0, 20.0)
	await _frames(4)
	await _shot("5_a_bord_carte")
	rh.map.close()
	rd.jump.thank()
	await _frames(8)
	await _shot("6_merci_aigle")
	rd.jump.land_all()
	await _frames(4)
	rd.phase = "fight"
	rd.elapsed = 156.0
	rd.ring = Royale.ring_at(rd.elapsed, rd.centers)
	rd.update(0.01)
	var ev: RoyaleEvent = rd.event
	for a in rd.ais:
		a.passive = true
		_place(a, ev.pos + Vector3(120, 0, 60))
	_place(p, ev.pos + Vector3(-9, 0, -9))
	p.rotation.y = atan2(ev.pos.x - p.global_position.x, ev.pos.z - p.global_position.z) + PI
	await _wait(func(): return rh.announce.current.is_empty() or String(rh.announce.current.title).contains("autel"), 3.0)
	await _frames(30)
	await _shot("7_autel_gardien")
	rh.map.open()
	await _frames(6)
	await _shot("8_carte_autel")
	rh.map.close()
	await _frames(2)
	# météore près du joueur
	var tg := rd.meteor_at(p.global_position + Vector3(3, 0, 2))
	await get_tree().create_timer(RoyaleMods.METEOR_DELAY * 0.6).timeout
	await _shot("9_meteore")
	await get_tree().create_timer(RoyaleMods.METEOR_DELAY).timeout
	# le gardien tombe : trésor de l'autel
	if is_instance_valid(ev.guardian):
		ev.guardian.hp = 1.0
		ev.guardian.take_damage(1e9, p, false)
	await _frames(40)
	_cards()
	await _shot("10_tresor")
	if tg != null and is_instance_valid(tg):
		tg.queue_free()
	# bilan : partie gagnée
	for a in rd.ais:
		if is_instance_valid(a) and not a.is_dead:
			a.hp = 1.0
			a.take_damage(1e9, p, false)
	await _wait(func(): return world.get("_ended") == true, 8.0)
	await _frames(70)
	await _shot("11_bilan")
