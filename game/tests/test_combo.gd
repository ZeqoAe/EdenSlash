extends Node
## Combo complet d'une classe devant des monstres, avec captures du 3e coup :
## godot --path game res://tests/test_combo.tscn -- samurai 0.3,0.75
## Images : user://shots/combo_<classe>_<i>.png

var world: Node
var player: Player


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cid: String = args[0] if not args.is_empty() else "samurai"
	var times: Array = Array(args[1].split(",")) if args.size() > 1 else ["0.3", "0.75"]
	Profile.selected_class = cid
	Run.start(cid)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	player = world.player
	world.director.set_process(false)
	world.director.set_physics_process(false)
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	await get_tree().create_timer(0.3).timeout
	var roster: Array = world.director._roster
	var fwd := player.forward()
	for i in 6:
		var p := player.global_position + fwd.rotated(Vector3.UP, (i - 2.5) * 0.35) * (3.0 + (i % 3) * 1.4)
		var m: Monster = world.director._spawn_monster(int(roster[0]), p, 5)
		m.set_physics_process(false)
	world.rig.global_position = player.global_position
	await get_tree().create_timer(0.8).timeout
	var aim := player.global_position + fwd * 4.0
	for k in 3:
		player._start_attack(aim)
		if k == 2:
			for i in times.size():
				var t := float(times[i])
				get_tree().create_timer(t).timeout.connect(_shot.bind(cid, i))
		var guard := 0.0
		while player._state == "attack" and guard < 3.0:
			await get_tree().physics_frame
			guard += get_physics_process_delta_time()
	await get_tree().create_timer(0.6).timeout
	print("combo %s terminé, état %s" % [cid, player._state])
	get_tree().quit()


func _shot(cid: String, i: int) -> void:
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/combo_%s_%d.png" % [cid, i])
