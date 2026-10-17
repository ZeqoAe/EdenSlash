extends Node
## Captures du Battle royale (passe M1, remises à jour au lot BR-I2) : page du mode (compte neuf et avancé), arme de
## départ, vol de l'aigle, atterrissage dans un lieu nommé, choix de pièce, largage et mise à prix, grande carte, menu
## pause, dépouille et fenêtre de pile, récapitulatif de mort, spectateur, bilan de défaite, bilan de victoire.
## M1_RES=1280x720 godot --path game res://tests/shot_m1.tscn   ->  user://shots/m1_<largeur>x<hauteur>_*.png
## (APPDATA détourné conseillé : le test ne sauvegarde rien, mais part d'un profil remis à zéro.)
## Lignes « [débord] » : un contrôle sort de l'écran.

var world: Node


func _overflow(name: String) -> void:
	var size := get_viewport().get_visible_rect().size
	var stack: Array = [get_tree().root]
	var found := 0
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is ScrollContainer or (n is CanvasItem and not (n as CanvasItem).visible):
			continue
		if n is Window and n != get_tree().root:
			continue
		for c in n.get_children():
			stack.append(c)
		if n is Control and (n as Control).is_visible_in_tree():
			var r := (n as Control).get_global_rect()
			if r.size.x > 1.0 and r.size.y > 1.0 and (r.end.x > size.x + 1.0 or r.end.y > size.y + 1.0 or r.position.x < -1.0 or r.position.y < -1.0) \
					and not (n is TextureRect and n.get_parent() is Control and (n as Control).get_parent().name == "bg"):
				if found < 6:
					print("[débord] %s : %s %s (%d, %d)-(%d, %d) sur (%d, %d)" % [name, n.get_class(), n.name, r.position.x, r.position.y, r.end.x, r.end.y, size.x, size.y])
				found += 1


func _shot(name: String, wait := 0.9) -> void:
	await get_tree().create_timer(wait, true).timeout
	_overflow(name)
	DirAccess.make_dir_recursive_absolute("user://shots")
	var vs: Vector2i = get_viewport().size
	get_viewport().get_texture().get_image().save_png("user://shots/m1_%dx%d_%s.png" % [vs.x, vs.y, name])
	print("[capture] m1_%dx%d_%s" % [vs.x, vs.y, name])


func _clear_cards() -> void:
	world.cards._queue.clear()
	world.cards._show_next()
	get_tree().paused = false


func _ready() -> void:
	get_tree().create_timer(400.0, true).timeout.connect(func(): get_tree().quit(1))  # garde-fou
	Settings.reset_all()  # (avant la taille de fenêtre : les réglages remettent la leur)
	Profile.reset_all()
	if OS.get_environment("M1_RES") != "":
		var wh := OS.get_environment("M1_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
		await get_tree().create_timer(0.5).timeout
	# page du mode, compte neuf (verrouillé) puis avancé
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._show_menu("royale")
	await _shot("01_page_neuf")
	lobby.queue_free()
	Profile.records["league_rank"] = 2
	Profile.records["royale_wins"] = 3
	Profile.records["royale_best"] = 1
	Profile.records["royale_kills"] = 17
	Royale.difficulty = 3
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._show_menu("royale")
	await _shot("02_page_avance")
	lobby.queue_free()
	await get_tree().process_frame
	# partie
	Royale.start("samurai")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	while not (world.get("director") != null and world.director.royale != null and world.director.royale.ais.size() == 7):
		await get_tree().create_timer(0.3).timeout
	var rd: RoyaleDirector = world.director.royale
	var d: RunDirector = world.director
	var p: Player = world.player
	await _shot("03_arme", 1.5)
	_clear_cards()
	await _shot("04_vol", 1.2)
	# tout le monde au sol (lot BR4 : le combat ne commence qu'après le largage) ; le héros dans le lieu ★★★
	var rich: Dictionary = {}
	for pl in d.map.places:
		if int(pl.stars) == 3:
			rich = pl
	rd.jump.land_all()
	await get_tree().create_timer(2.4).timeout  # (« Tout le monde est au sol » passe d'abord)
	if not rich.is_empty():
		p.global_position = rich.pos + Vector3(13.5, 0.5, 0)  # (entre le couvert et la couronne de coffres)
		rd._on_landed(p)  # annonce « Tu atterris … »
	await _shot("05_atterrissage", 0.8)
	# un coffre doré près du héros : choix de pièce
	var gold: Interactable = rd._spawn_chest(p.global_position + Vector3(3, 0, 0), 2)
	await get_tree().create_timer(0.5).timeout
	rd.open_chest(gold)
	await _shot("06_coffre_choix")
	_clear_cards()
	# largage annoncé, fil des éliminations, mis à prix
	rd.elapsed = float(Royale.PHASES[0].hold) + 1.0
	rd.ring = Royale.ring_at(rd.elapsed, rd.centers)
	rd._announce_drop()
	var a: ClassRival = rd.ais[0]
	a.get_meta("royale").kills = Royale.BOUNTY_KILLS
	rd._update_bounty()
	a.global_position = p.global_position + Vector3(6, 0.5, 4)
	rd.feed("%s élimine %s" % [rd.ais[1].display_name.get_slice(" ·", 0), rd.ais[2].display_name.get_slice(" ·", 0)])
	rd.feed("Tu élimines %s" % rd.ais[3].display_name.get_slice(" ·", 0))
	await _shot("07_largage_prime", 1.4)
	world.hud._big_map.visible = true
	await _shot("08_grande_carte")
	world.hud._big_map.visible = false
	world.pause_menu.open()
	await _shot("09_pause")
	world.pause_menu.close()
	get_tree().paused = false
	# dépouille d'un héros éliminé (après les deux premières minutes : pas de retour) et fenêtre de pile
	rd.elapsed = Royale.REVIVE_WINDOW + 30.0
	rd.ring = Royale.ring_at(0.0, rd.centers)
	for x in rd.ais:
		x.passive = true
	var victim: ClassRival = rd.ais[5]
	for k in 8:
		Royale.ai_open_chest(victim, 2)
	victim.global_position = p.global_position + Vector3(-5, 0.3, 6)  # (loin du coffre doré posé plus haut)
	p.global_position += Vector3(-4, 0, 4)
	victim.hp = 1.0
	victim.take_damage(1e9, p, false)
	await get_tree().physics_frame
	_clear_cards()
	await _shot("10_depouille", 1.0)
	if not rd.ground.is_empty():
		rd.interact(rd.ground.back())
		await _shot("11_pile", 0.8)
		if rd._sheet != null and is_instance_valid(rd._sheet):
			rd._sheet.close()
	get_tree().paused = false
	# mort définitive : récapitulatif, puis spectateur
	var killer: ClassRival = rd.ais[4]
	killer.global_position = p.global_position + Vector3(-5, 0.3, 2)
	killer.set_meta("move", {"name": String((GameData.class_data(String(killer.get_meta("royale").cid)).get("skills", [{}]) as Array)[0].get("name", "")), "icon": ""})
	Royale.note_fight(killer, p, rd.clock, 312.0)
	p.hp = 1.0
	p.evasion_chance = 0.0
	p.parry_chance = 0.0
	p.shield_until = 0.0
	p.take_damage(1e9, killer, false)
	await _shot("12_recap_mort", 1.6)
	if rd.recap_view != null:
		rd.recap_view.watch()
	rd.spectate_step(1)
	await _shot("13_spectateur", 1.6)
	# « Bilan » : bilan de défaite
	rd.request_results()
	await _shot("14_bilan_defaite", 4.5)
	get_tree().paused = false
	world.queue_free()
	await get_tree().create_timer(0.5).timeout
	# bilan de victoire (chronologie complète)
	Royale.reset_stats()
	Royale.stats.dealt = 7820.0
	Royale.stats.clock = 600.0
	for e in [["jump", 15.0, "Temple"], ["kill", 120.0, ""], ["drop", 300.0, ""], ["bounty", 420.0, ""], ["win", 590.0, "N°1"]]:
		Royale.timeline_add(String(e[0]), float(e[1]), String(e[2]))
	var r := RoyaleResults.new()
	add_child(r)
	r.show_results(1, 4, 23, 11, 581.0, {"text": ["+110 insignes (victoire, 4 éliminations)", "Coffre d'apparence légendaire", "Titre : « Dernier debout »"], "mastery": 30})
	await _shot("15_bilan_victoire", 0.5)
	r.finish_now()
	await _shot("16_bilan_victoire_fin", 1.2)
	get_tree().paused = false
	get_tree().quit()
