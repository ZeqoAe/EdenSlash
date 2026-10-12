extends Node
## Paramètres et modes de jeu : touches, modes prêts à l'emploi, sauvegarde,
## déplacement à la souris, attaque et compétences automatiques.
## godot --headless --path game res://tests/test_controls.tscn  (paramètres de test uniquement)

var fails := 0
var world: Node
var player: Player


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _has_key(action: String, key: Key) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.physical_keycode == key:
			return true
	return false


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _ready() -> void:
	check("paramètres de test", Settings.save_path == Settings.TEST_SAVE_PATH)
	Settings.reset_all()
	_test_bindings()
	_test_presets()
	_test_save_load()
	await _test_menu()
	await _test_gameplay()
	Settings.reset_all()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_bindings() -> void:
	check("touches par défaut : compétence 1 = 1 et A (AZERTY)", _has_key("skill_1", KEY_1) and _has_key("skill_1", KEY_Q))
	Settings.bind("skill_1", 0, {"k": KEY_G})
	check("compétence 1 réassignée sur G", _has_key("skill_1", KEY_G) and not _has_key("skill_1", KEY_1))
	var lost := Settings.bind("skill_1", 1, {"k": KEY_E})
	check("touche prise ailleurs : retirée de la compétence 2", not _has_key("skill_2", KEY_E) and _has_key("skill_1", KEY_E) and "Compétence 2" in lost)
	Settings.unbind("skill_1", 1)
	check("effacer une touche", not _has_key("skill_1", KEY_E) and Settings.binds.skill_1.size() == 1)
	check("clic droit partagé déplacement RTS / caméra", Settings._mouse_buttons("move_order") == [MOUSE_BUTTON_RIGHT] and Settings._mouse_buttons("camera_rotate") == [MOUSE_BUTTON_RIGHT])
	check("libellé lisible", Settings.event_label({"m": MOUSE_BUTTON_LEFT}) == "Clic gauche" and Settings.event_label({"k": KEY_SPACE}) == "Espace")
	Settings.reset_bindings()
	check("touches par défaut rétablies", _has_key("skill_1", KEY_1) and _has_key("skill_2", KEY_E))


func _test_presets() -> void:
	check("mode de départ : Classique", Settings.current_preset() == "classic" and Settings.move_mode() == "keyboard")
	check("caméra : clic droit en mode clavier", Settings.camera_rotate_mask() == MOUSE_BUTTON_MASK_RIGHT)
	Settings.apply_preset("rts")
	check("RTS : clic droit pour se déplacer, caméra au clic molette",
		Settings.move_click_action() == "move_order" and Settings.camera_rotate_mask() == MOUSE_BUTTON_MASK_MIDDLE)
	Settings.apply_preset("arpg")
	check("ARPG : le clic gauche déplace au lieu d'attaquer", Settings.move_click_action() == "attack" and not Settings.attack_button_attacks())
	Settings.apply_preset("relax")
	check("Détente : attaque et 4 compétences automatiques", Settings.auto_attack() and Settings.auto_skill(0) and Settings.auto_skill(3))
	Settings.set_auto_skill(2, false)
	check("réglage modifié : mode personnalisé", Settings.current_preset() == "")
	Settings.apply_preset("classic")
	check("retour au Classique", Settings.current_preset() == "classic" and not Settings.auto_skill(0))


func _test_save_load() -> void:
	Settings.set_v("display", "window_mode", "fullscreen")
	Settings.set_v("camera", "rotate_speed", 1.75)
	Settings.bind("jump", 0, {"k": KEY_V})
	Settings.data.display.window_mode = "windowed"
	Settings.data.camera.rotate_speed = 1.0
	Settings.binds.jump = []
	Settings.load_settings()
	check("sauvegarde relue : fenêtre, caméra, touches", Settings.get_v("display", "window_mode") == "fullscreen"
		and is_equal_approx(float(Settings.get_v("camera", "rotate_speed")), 1.75) and Settings.binds.jump == [{"k": KEY_V}])
	Settings.reset_all()


func _test_menu() -> void:
	var menu := SettingsMenu.new()
	add_child(menu)
	for t in menu._tabs.get_tab_count():
		menu.open(t)
		await get_tree().process_frame
	check("menu : 6 onglets", menu._tabs.get_tab_count() == 6 and menu.is_open())
	var b := Button.new()
	menu._start_listening("interact", 0, b)
	menu._input(_key(KEY_G))
	check("menu : assigner Interagir à G", _has_key("interact", KEY_G) and not _has_key("interact", KEY_F))
	menu._start_listening("interact", 0, b)
	menu._input(_key(KEY_ESCAPE))
	check("menu : Échap annule l'écoute", _has_key("interact", KEY_G) and menu.is_open())
	menu._input(_key(KEY_ESCAPE))
	check("menu : Échap ferme", not menu.is_open())
	b.free()
	menu.queue_free()
	Settings.reset_all()


func _test_gameplay() -> void:
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
	var sk: Dictionary = Run.class_data().skills[2]  # cône au corps à corps
	Run.skills = [{"id": int(sk.id), "rank": 1}]
	await get_tree().create_timer(0.5).timeout

	# déplacement vers un point cliqué
	Settings.apply_preset("arpg")
	var start := player.global_position
	player._move_goal = start + Vector3(5, 0, 0)
	await get_tree().create_timer(2.0).timeout
	var flat := player.global_position - start
	flat.y = 0.0
	check("clic de déplacement : le héros rejoint le point", flat.distance_to(Vector3(5, 0, 0)) < 1.0 and player.move_goal() == Vector3.INF)
	player._move_goal = player.global_position + Vector3(0, 0, 8)
	Input.action_press("move_left")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("move_left")
	check("le clavier annule le clic de déplacement", player.move_goal() == Vector3.INF)

	# manuel : rien ne part tout seul
	Settings.apply_preset("classic")
	var m := _spawn_dummy(2.0)
	await get_tree().create_timer(1.0).timeout
	check("manuel : ni attaque ni compétence automatiques", player._state == "idle" and player.cooldown_left(0) <= 0.0)
	# compétence automatique
	Settings.set_auto_skill(0, true)
	await get_tree().create_timer(0.6).timeout
	check("compétence automatique lancée sur le monstre à portée", player.cooldown_left(0) > 0.0)
	Settings.set_auto_skill(0, false)
	await get_tree().create_timer(1.5).timeout
	# attaque automatique
	Settings.set_v("game", "attack_mode", "auto")
	var attacked := false
	for i in 40:
		await get_tree().physics_frame
		attacked = attacked or player._state == "attack"
	check("attaque automatique sur le monstre au contact", attacked)
	# cible verrouillée uniquement : pas de cible, pas de compétence auto
	Settings.set_v("game", "attack_mode", "manual")
	Settings.set_v("game", "auto_target", "locked")
	player.skill_ready_at.clear()
	Settings.set_auto_skill(0, true)
	await get_tree().create_timer(0.8).timeout
	check("cible verrouillée exigée : rien sans cible", player.cooldown_left(0) <= 0.0)
	player._target = m
	await get_tree().create_timer(0.8).timeout
	check("cible verrouillée : compétence lancée", player.cooldown_left(0) > 0.0)
	# visée sur le monstre le plus proche
	Settings.set_v("game", "aim_mode", "nearest")
	check("visée « monstre le plus proche »", player._skill_aim().distance_to(m.global_position) < 0.01)
	world.queue_free()


## Monstre immobile et inoffensif devant le héros.
func _spawn_dummy(dist: float) -> Monster:
	var id: int = world.director._pick_monster(player.level)
	var pos := player.global_position + player.forward() * dist
	var m: Monster = world.director._spawn_monster(id, pos, 1)
	m.max_hp = 1e9
	m.hp = 1e9
	m.set_physics_process(false)
	m.set_process(false)
	return m
