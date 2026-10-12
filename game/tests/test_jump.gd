extends Node
## Mesure du saut et des enchaînements saut / esquive :
## godot --path game res://tests/test_jump.tscn
## Affiche hauteur max, temps en l'air et distance parcourue pour chaque manœuvre.

var world: Node
var player: Player


func _ready() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	player = world.player
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.director.set_physics_process(false)
	world.cards._queue.clear()
	world.cards._show_next()  # ferme le choix de cartes du départ (dépause)
	await _test("saut simple", [["jump", 0.0, 0.6]])
	await _test("petit saut (relâché tôt)", [["jump", 0.0, 0.06]])
	await _test("esquive au sol", [["dodge", 0.0, 0.05]])
	await _test("esquive puis saut", [["dodge", 0.0, 0.05], ["jump", 0.1, 0.6]])
	await _test("saut puis esquive aérienne", [["jump", 0.0, 0.6], ["dodge", 0.15, 0.05]])
	Run.passives["air_jump"] = 1
	await _test("double saut", [["jump", 0.0, 0.2], ["jump", 0.32, 0.5]])
	Run.passives["featherfall"] = 2
	await _test("saut Apesanteur x2", [["jump", 0.0, 1.0]])
	Run.passives.clear()
	await _combo_test()
	get_tree().quit()


## Saut -> compétence en l'air -> esquive juste après l'impact (annulation parfaite).
func _combo_test() -> void:
	var sk: Dictionary = Run.class_data().skills[0]
	Run.skills = [{"id": int(sk.id), "rank": 1}]
	await get_tree().create_timer(0.8).timeout
	var y0 := player.global_position.y
	var peak := 0.0
	_schedule("jump", 0.0, 0.4)
	_schedule("skill_1", 0.15, 0.05)
	var t := 0.0
	var dodged := false
	var air := 0.0
	while t < 4.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		peak = maxf(peak, player.global_position.y - y0)
		if not player.is_on_floor():
			air += dt
		if not dodged and player._state == "skill" and player._action.get("hit_done", false):
			dodged = true
			print("impact de %s à %.2f s, en l'air : %s" % [sk.name, t, not player.is_on_floor()])
			_schedule("dodge", 0.05, 0.05)
			get_tree().create_timer(0.16).timeout.connect(func():
				DirAccess.make_dir_recursive_absolute("user://shots")
				get_viewport().get_texture().get_image().save_png("user://shots/combo_cancel.png"))
		if dodged and t > 0.5 and player.is_on_floor():
			break
	print("saut > sort > esquive : hauteur %.2f m, en l'air %.2f s, fluidité %d, recharge restante %.1f s" % [
		peak, air, player.flow_stacks, player.cooldown_left(0)])


func _test(label: String, presses: Array) -> void:
	await get_tree().create_timer(0.6).timeout
	var start := player.global_position
	var y0 := start.y
	var peak := 0.0
	var air := 0.0
	var t := 0.0
	Input.action_press("move_right")
	for p in presses:
		_schedule(p[0], p[1], p[2])
	while t < 3.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		peak = maxf(peak, player.global_position.y - y0)
		if not player.is_on_floor():
			air += dt
		elif t > 0.3 and air > 0.0:
			break
	Input.action_release("move_right")
	var d := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	print("%-28s hauteur %.2f m   en l'air %.2f s   distance %.1f m (%.2f s)" % [label, peak, air, d, t])


func _schedule(action: String, at: float, hold: float) -> void:
	get_tree().create_timer(at).timeout.connect(func():
		Input.action_press(action)
		get_tree().create_timer(hold).timeout.connect(func(): Input.action_release(action)))
