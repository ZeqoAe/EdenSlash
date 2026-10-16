extends Node
## Captures du lot BR3 (Battle royale) : arme de départ, coffre (emplacements vides), coffre (équipement complet :
## améliorations), pièces au sol et dépouille, fiche d'équipement (user://shots/br3_*.png). Taille : BR3_RES=1280x720.
## godot --path game res://tests/shot_br3.tscn

var world: Node


func _shot(name: String) -> void:
	await get_tree().create_timer(0.9, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/br3_%s.png" % name)
	print("[shot] user://shots/br3_%s.png" % name)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var res := OS.get_environment("BR3_RES")
	if res != "":
		var wh := res.split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
	Settings.reset_all()
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.start("ranger")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	var waited := 0.0
	while waited < 60.0 and not (world.get("director") != null and world.director.royale != null and world.director.royale.ais.size() == 7):
		await get_tree().create_timer(0.5, true).timeout
		waited += 0.5
	await get_tree().create_timer(1.5, true).timeout
	var rd: RoyaleDirector = world.director.royale
	var p: Player = world.player
	await _shot("1_arme")
	if world.cards.is_open():
		world.cards._choose(0)
	world.cards._queue.clear()
	world.cards._show_next()
	if not Profile.equipped.has("weapon"):
		RoyaleLoot.wear(SurvivorGear.adopt(Items.generate(2, 0.0, "weapon", "ranger", 0, Run.weapon_type(), 0)))
	Run.hero_level = 8
	p.level = 8
	world.cards.offer("Coffre doré : choisis une pièce", RoyaleLoot.player_cards(2, 8))
	await _shot("2_coffre_vide")
	world.cards._queue.clear()
	world.cards._show_next()
	while not RoyaleLoot.is_complete(Profile.equipped):
		for c in RoyaleLoot.player_cards(1, 8):
			if String(c.type) == "sv_piece":
				Run.apply_card(c)
				break
	for i in 2:
		Run.apply_card(SurvivorCards.up_card("chest", "common"))
	world.cards.offer("Coffre doré : améliore une pièce", RoyaleLoot.player_cards(2, 8))
	await _shot("3_coffre_complet")
	world.cards._queue.clear()
	world.cards._show_next()
	get_tree().paused = false
	# un héros tombe près du joueur : ses pièces au sol, sa dépouille
	if rd.get("jump") != null and is_instance_valid(rd.jump):
		rd.jump.land_all()  # (largage du lot BR4 : tout le monde au sol)
	await get_tree().create_timer(0.3, true).timeout
	rd.phase = "fight"
	rd.elapsed = 200.0
	var victim: ClassRival = rd.ais[0]
	for k in 8:
		Royale.ai_open_chest(victim, 1)
	victim.global_position = p.global_position + Vector3(6, 0.5, 0)
	victim.hp = 1.0
	victim.take_damage(1e9, p, false)
	await get_tree().create_timer(0.3, true).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	get_tree().paused = false
	p.global_position = rd.ground[0].global_position + Vector3(0.6, 0.3, 0.6) if not rd.ground.is_empty() else p.global_position
	await _shot("4_sol")
	rd.inspect(rd.fallen[0] if not rd.fallen.is_empty() else {})
	await _shot("5_fiche")
	get_tree().paused = false
	get_tree().quit()
