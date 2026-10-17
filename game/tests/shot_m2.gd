extends Node
## Passe M2 : captures de la page Donjons (liste, filtre « torse », donjon choisi) et de boss de la bibliothèque en
## combat, une mécanique en cours (user://shots/m2_*.png).
## godot --path game res://tests/shot_m2.tscn   (APPDATA détourné : rien n'est sauvegardé chez le joueur)

const FIGHTS := [["latif", "meteors"], ["argus", "gaze"], ["belmont", "shrink"], ["kozbane", "ring_burst"], ["lalo", "grid"],
	["alonzo", "safe_zone"], ["bukabuka", "barrier"], ["lanka", "sweep"]]


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/m2_%s.png" % name)
	print("[m2] capture %s" % name)


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 2
	Profile.records["boss_avila"] = 1
	Profile.records["dgb_latif_0"] = 3
	Profile.records["dgb_latif_1"] = 1
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.5).timeout
	DungeonPage.sel = "latif"
	lobby._show_menu("dungeon")
	await _shot("page")
	lobby._scroll.scroll_vertical = 520
	await _shot("page_liste")
	DungeonPage.f_slot = "chest"
	lobby._show_menu("dungeon")
	lobby._scroll.scroll_vertical = 0
	await _shot("torse")
	lobby._scroll.scroll_vertical = 520
	await _shot("torse_liste")
	DungeonPage.f_slot = ""
	DungeonPage.f_family = "arena"
	DungeonPage.sel = "belmont"
	lobby._dg_diff = 2
	lobby._show_menu("dungeon")
	await _shot("arene_mythique")
	DungeonPage.f_family = ""
	lobby.queue_free()
	Training.active = false
	# combats : un monde de donjon, puis chaque boss au centre avec une mécanique lancée
	Tower.start_dungeon("warrior", "beluga", 0, [], "latif")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var d: RunDirector = world.director
	var p: Player = world.player
	p.dev_invincible = true
	world.cards._queue.clear()
	world.cards._show_next()
	d.tower.begin(Dungeons.ROOMS.size())  # salle du boss (3 salles depuis le lot A2 : « Salle 3/3 »)
	d.tower.phase = "done"  # salle figée : retirer les boss ne termine pas le donjon
	await get_tree().create_timer(0.5).timeout
	var center: Vector3 = d.tower._center
	for f in FIGHTS:
		for m in get_tree().get_nodes_in_group("monsters"):
			m.remove_from_group("monsters")
			m.queue_free()
		await get_tree().create_timer(0.3).timeout
		var b := BossLibrary.spawn(String(f[0]), 0, {"director": d, "pos": center, "level": 40})
		p.global_position = center + Vector3(0, 0.5, 9.0)
		await get_tree().create_timer(1.2).timeout
		b.brain._busy = false
		for br in b.brain.bricks:
			if br.type == f[1]:
				BossBricks.run(b.brain, br)
		await _shot("boss_%s" % f[0], 1.0 if f[1] != "shrink" else 4.0)
	get_tree().quit()
