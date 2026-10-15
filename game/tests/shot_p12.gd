extends Node
## Passe P12 : captures de l'autel du géant (invite), du géant en combat (zone au sol), de la pastille « Menace · Pacte »
## du HUD (et son infobulle) et de la légende de la grande carte.
## user://shots/p12/<largeur>x<hauteur>_<nom>.png
## [P12_RES=1280x720] EDEN_PROFILE=user://shot_p12.json godot --path game res://tests/shot_p12.tscn


var world: Node


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait, true).timeout
	if world and not name.begins_with("geant"):
		world.cards._queue.clear()  # (choix de niveau ouverts par l'expérience ramassée)
		world.cards._show_next()
		await get_tree().create_timer(0.3, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots/p12")
	get_viewport().get_texture().get_image().save_png("user://shots/p12/%dx%d_%s.png" % [get_viewport().size.x, get_viewport().size.y, name])


func _ready() -> void:
	if OS.get_environment("P12_RES") != "":
		var wh := OS.get_environment("P12_RES").split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	Profile.selected_zone = String(GameData.zones[0].id)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var d: RunDirector = world.director
	var player: Player = world.player
	player.dev_invincible = true
	world.cards._queue.clear()
	world.cards._show_next()
	d.time = RunDirector.EARLY_RAMP + 5.0
	_clear()
	world.hud.hide_banner()
	# 1. l'autel du géant, invite affichée
	var altar := _station(d, "giant")
	var greed := _station(d, "greed")
	d._found[altar] = true
	d._found[greed] = true
	_place(world, d, altar.global_position + Vector3(0, 0, 3.0))
	await _shot("autel", 1.5)
	# 2. le géant surgit et frappe (zone au sol)
	d._interact(altar)
	_place(world, d, altar.global_position + Vector3(0, 0, 9.0))
	await get_tree().create_timer(1.6).timeout
	world.hud.hide_banner()
	var g: GiantMonster = null
	for m in get_tree().get_nodes_in_group("monsters"):
		if m is GiantMonster:
			g = m
	if g:
		# les trois attaques spéciales, l'une après l'autre (zone à moitié remplie)
		for k in GiantMonster.SPECIALS.size():
			g._special(GiantMonster.SPECIALS[k])
			await _shot("geant_%s" % GiantMonster.SPECIALS[k].id, float(GiantMonster.SPECIALS[k].delay) * 0.55)
			await get_tree().create_timer(1.6).timeout
	# 3. géant vaincu, pacte pris : la pastille du HUD
	if g:
		g.take_damage(g.max_hp * 10.0 + 1e6, player)
	await get_tree().create_timer(0.5).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	d._interact(greed)
	_clear()
	await get_tree().create_timer(4.0).timeout
	world.hud.hide_banner()
	await _shot("hud_menace", 0.5)
	var badge: MenaceBadge = world.hud.find_children("*", "MenaceBadge", true, false)[0]
	get_viewport().warp_mouse(badge.get_global_rect().get_center())
	await _shot("hud_infobulle", 1.6)
	# 4. légende de la grande carte
	world.hud._big_map.visible = true
	await _shot("grande_carte", 0.8)
	get_tree().quit()


func _station(d: RunDirector, kind: String) -> Interactable:
	for it in d.map.interactables:
		if is_instance_valid(it) and it.kind == kind and not it.used:
			return it
	return null


func _place(world: Node, d: RunDirector, at: Vector3) -> void:
	d._place_player(d.ground_point(at, at))
	world.rig.global_position = world.player.global_position


func _clear() -> void:
	for m in get_tree().get_nodes_in_group("monsters"):
		if not m is GiantMonster:
			m.remove_from_group("monsters")
			m.queue_free()
