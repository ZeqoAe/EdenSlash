extends Node
## Lot 12 : ciblage par camp (monstres, coups au sol) et allié IA scripté.
## godot --headless --path game res://tests/test_lot12.tscn

var fails := 0
var world: Node
var player: Player


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	player = world.player
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.5).timeout
	check("le joueur est dans le groupe des héros", player.is_in_group("heroes"))
	# allié scripté
	var ally := ClassRival.new()
	ally.ally = true
	ally.setup("cleric", 10, 1)
	world.add_child(ally)
	ally.global_position = player.global_position + Vector3(3, 0.4, 0)
	await get_tree().physics_frame
	check("allié : camp du joueur, groupe des héros, pas des monstres", ally.team == Combatant.Team.PLAYER and ally.is_in_group("heroes") and not ally.is_in_group("monsters"))
	# un monstre
	var id: int = world.director._pick_monster(player.level)
	var mon: Monster = world.director._spawn_monster(id, player.global_position + Vector3(0, 0.4, 30), 1)
	mon.max_hp = 1e9
	mon.hp = 1e9
	await get_tree().physics_frame
	var tm := Combatant.hostile_targets(get_tree(), mon)
	check("cibles d'un monstre : le joueur et l'allié", player in tm and ally in tm and not (mon in tm))
	var ta := Combatant.hostile_targets(get_tree(), ally)
	check("cibles d'un allié : les monstres seulement", mon in ta and not (player in ta) and not (ally in ta))
	# le monstre proche de l'allié le cible
	mon.global_position = ally.global_position + Vector3(2, 0, 0)
	player.global_position += Vector3(-25, 0, 0)
	for i in 50:
		await get_tree().physics_frame
	check("le monstre vise l'allié, plus proche que le joueur", mon._player == ally)
	player.global_position = mon.global_position + Vector3(0.5, 0, 0)
	for i in 3:
		await get_tree().physics_frame
	# coup au sol d'un monstre : l'allié est touché
	var hp0 := ally.hp
	Telegraph.spawn(world, ally.global_position, 0.0, {"damage": 40.0, "delay": 0.05, "shape": "circle", "radius": 3.0, "source": mon})
	await get_tree().create_timer(0.4).timeout
	check("un coup au sol touche l'allié (PV %d → %d)" % [hp0, ally.hp], ally.hp < hp0)
	# soutien : l'allié soigne le héros bas
	player.hp = player.max_hp * 0.2
	ally._support_ready_at = 0.0
	if ally._support.any(func(s): return String(s.kind) == "heal"):
		ally._support_tick()
		check("allié soigneur : le héros sous 50 % est soigné", player.hp > player.max_hp * 0.2)
	else:
		check("(classe sans soin : soutien ignoré)", true)
	# un monstre qui meurt : l'expérience va toujours au joueur (orbes), pas de plantage
	mon.take_damage(1e12, ally, false)
	await get_tree().physics_frame
	check("monstre tué par l'allié", mon.is_dead)
	world.queue_free()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
