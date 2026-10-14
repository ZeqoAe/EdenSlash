extends Node
## Mémoire des touches : appuis gardés, enchaînement sans « Trop tôt », esquive qui vide la file.
## godot --headless --path game res://tests/test_memory.tscn

var fails := 0
var world: Node
var player: Player


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


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
	world.cards._show_next()
	var sk: Array = Run.class_data().skills
	Run.skills = [{"id": int(sk[0].id), "rank": 1}, {"id": int(sk[1].id), "rank": 1}]
	Run.chains = {0: [{"id": int(sk[2].id), "rank": 1}, {"id": int(sk[3].id), "rank": 1}]}
	Settings.reset_all()
	await get_tree().create_timer(0.5).timeout

	# marteler 4 fois la case 1 : le sort et ses 2 enchaînements partent, le 4e appui est ignoré
	await _reset()
	for i in 4:
		await _tap("skill_1", 6)
	check("4e appui dans le vide : file à 3 au plus", player._queue.size() <= 3)
	await _wait(3.5)
	check("marteler la case 1 : toute la chaîne part (%d enchaînements)" % player.ml_counts.chain, int(player.ml_counts.chain) == 2)
	check("file vide ensuite", player._queue.is_empty())

	# mémoire coupée : marteler casse la chaîne (« Trop tôt »)
	Settings.set_v("game", "key_memory", false)
	await _reset()
	for i in 4:
		await _tap("skill_1", 6)
	await _wait(3.5)
	check("sans mémoire : marteler casse la chaîne", int(player.ml_counts.chain) == 0)
	Settings.set_v("game", "key_memory", true)

	# 1 puis 2 pendant le sort : le sort de la case 2 part tout seul à la fin de la récupération
	await _reset()
	await _tap("skill_1", 4)
	await _tap("skill_2", 4)
	check("appui sur la case 2 gardé pendant le sort 1", player._queue.size() == 1)
	await _wait(2.2)
	check("le sort de la case 2 est parti sans rappuyer", player.cooldown_left(1) > 0.0 and player._queue.is_empty())

	# l'esquive vide la mémoire
	await _reset()
	await _tap("skill_1", 4)
	await _tap("skill_2", 4)
	await _tap("dodge", 3)
	check("l'esquive vide la mémoire des touches", player._queue.is_empty())

	# un appui qui ne peut pas partir s'efface après 1,2 s
	await _reset()
	player.skill_ready_at[int(Run.skills[1].id)] = player._time + 0.2
	await _tap("skill_2", 3)
	check("sort presque rechargé : gardé", player._queue.size() == 1 or player.cooldown_left(1) > 0.0)

	# touche tenue : toute la chaîne
	await _reset()
	Input.action_press("skill_1")
	await _wait(4.0)
	Input.action_release("skill_1")
	check("touche tenue : la chaîne entière part (%d)" % player.ml_counts.chain, int(player.ml_counts.chain) == 2)

	# aide Détente : sorts et enchaînements partent seuls, jamais d'annulation parfaite
	Settings.set_assist("relax")
	await _reset()
	player.ml_counts.perfect = 0
	var id: int = world.director._pick_monster(player.level)
	var m: Monster = world.director._spawn_monster(id, player.global_position + player.forward() * 2.0, 1)
	m.max_hp = 1e9
	m.hp = 1e9
	m.set_physics_process(false)
	m.set_process(false)
	await _wait(6.0)
	check("Détente : les sorts partent seuls (%d enchaînements)" % player.ml_counts.chain, int(player.ml_counts.chain) >= 1)
	check("Détente : aucune annulation parfaite automatique", int(player.ml_counts.perfect) == 0)
	Settings.set_assist("assisted")

	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _reset() -> void:
	player.skill_ready_at.clear()
	player._chain.clear()
	player._queue.clear()
	player._skill_lock_until = 0.0
	player._dodge_ready_at = 0.0
	player.ml_counts.chain = 0
	player._state = "idle"
	await _wait(0.6)


func _wait(t: float) -> void:
	var n := int(t * Engine.physics_ticks_per_second)
	for i in n:
		await get_tree().physics_frame


func _tap(action: String, frames_after: int) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	Input.action_release(action)
	for i in frames_after:
		await get_tree().physics_frame
