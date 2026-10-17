extends Node
## Captures du lot CO-C (combat du Colisée) en 1280 × 720 puis 1600 × 900, dans une vraie partie (world.tscn, directeur du
## combat, pilote automatique) : début du combat, annonce du feu (prochain anneau en pointillés), un autre combat regardé
## (« Ailleurs »), le joueur à terre (la caméra suit un allié). Fichiers user://shots/co_<largeur>_*.png.
## APPDATA détourné : godot --path game res://tests/shot_co.tscn

var world: Node


func _shot(name: String) -> void:
	await get_tree().create_timer(0.5).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	var w := get_window().size.x
	get_viewport().get_texture().get_image().save_png("user://shots/co_%d_%s.png" % [w, name])
	print("[shot] co_%d_%s" % [w, name])


func _until(cond: Callable, max_frames := 600) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _ready() -> void:
	Settings.reset_all(false)
	Profile.selected_class = "warrior"
	ColiseeDirector.fallback = false
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = res
		await get_tree().process_frame
		Colisee.begin("warrior", "classique", 2, 11)
		world = load("res://scenes/world.tscn").instantiate()
		world.ready.connect(func(): world.player.autoplay = true)
		get_tree().root.add_child(world)
		await _until(func(): return world.get("director") != null and is_instance_valid(world.director.team) and world.director.team.phase == "fight", 1800)
		var dd: ColiseeDirector = world.director.team
		await get_tree().create_timer(4.0).timeout
		await _shot("1_combat")
		await _until(func(): return dd.phase != "fight" or float(dd.fights[dd.watched].t) > 22.0, 60 * 40)
		await _shot("2_feu")
		var other := (dd.watched + 1) % dd.fights.size()
		dd.watch(other)
		await get_tree().create_timer(1.0).timeout
		await _shot("3_ailleurs")
		for i in dd.fights.size():
			if int(dd.fights[i].a) == TeamMatch.player_team:
				dd.watch(i)
		if not world.player.is_dead:
			world.player.take_damage(world.player.max_hp * 10.0, null, false, true)
		await get_tree().create_timer(2.0).timeout
		await _shot("4_a_terre")
		dd.abandon_stay = true
		dd.abandon()
		get_tree().paused = false
		world.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
		Run.active = false
		Profile.in_run = false
	get_tree().quit()
