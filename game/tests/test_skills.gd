extends Node
## Lance chaque compétence de la classe devant des monstres (détection d'erreurs) :
## godot --path game res://tests/test_skills.tscn -- warrior

var world: Node
var player: Player


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var cid: String = args[0] if not args.is_empty() else "warrior"
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
	var skills: Array = Run.class_data().skills
	var roster: Array = world.director._roster
	for s in skills:
		for m in get_tree().get_nodes_in_group("monsters"):
			m.queue_free()
		await get_tree().physics_frame
		var fwd := player.forward()
		for i in 4:
			var m: Monster = world.director._spawn_monster(int(roster[0]), player.global_position + fwd.rotated(Vector3.UP, (i - 1.5) * 0.4) * 4.0, 5)
			m.set_physics_process(false)
		Run.skills = [{"id": int(s.id), "rank": 1}]
		player.skill_ready_at.clear()
		player.hp = player.max_hp
		player._state = "idle"
		player.use_skill(0, player.global_position + fwd * 6.0)
		await get_tree().create_timer(1.6).timeout
		print("%s : %s (%s) ok, état %s" % [cid, s.name, s.kind, player._state])
	get_tree().quit()
