extends Node
## Navigation à la manette dans les menus (UiNav) et manette réassignable.
## godot --headless --path game res://tests/test_nav.tscn

var fails := 0
var clicks := []


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Gamepad.active = true
	get_tree().root.size = Vector2i(1600, 900)
	# --- grille 3 x 2 de boutons dans un calque
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(100, 100)
	layer.add_child(grid)
	var btns := []
	for i in 6:
		var b := Button.new()
		b.text = "B%d" % i
		b.custom_minimum_size = Vector2(120, 50)
		var k := i
		b.pressed.connect(func(): clicks.append(k))
		grid.add_child(b)
		btns.append(b)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(300, 30)
	slider.max_value = 1.0
	slider.step = 0.1
	slider.value = 0.5
	grid.add_child(slider)
	await get_tree().process_frame
	await get_tree().process_frame
	check("7 contrôles navigables", UiNav.candidates().size() == 7)
	UiNav.cursor = null
	UiNav._last_center = Vector2.ZERO
	UiNav.pick_default()
	check("curseur par défaut : le premier", UiNav.cursor == btns[0])
	check("droite : B1", UiNav.move(Vector2.RIGHT) and UiNav.cursor == btns[1])
	check("bas : B4", UiNav.move(Vector2.DOWN) and UiNav.cursor == btns[4])
	check("gauche : B3", UiNav.move(Vector2.LEFT) and UiNav.cursor == btns[3])
	check("haut : B0", UiNav.move(Vector2.UP) and UiNav.cursor == btns[0])
	check("haut au bord : on reste", not UiNav.move(Vector2.UP) and UiNav.cursor == btns[0])
	UiNav.cursor = btns[4]
	UiNav.move(Vector2.DOWN)
	check("bas depuis B4 : le curseur de réglage", UiNav.cursor == slider)
	var v0 := slider.value
	UiNav.move(Vector2.RIGHT)
	check("droite sur un curseur : règle la valeur", slider.value > v0 and UiNav.cursor == slider)
	# validation : un clic de souris au centre
	UiNav.cursor = btns[2]
	UiNav.activate()
	await get_tree().process_frame
	await get_tree().process_frame
	check("A valide : le bouton reçoit le clic", clicks == [2])
	# l'écran du dessus l'emporte
	var layer2 := CanvasLayer.new()
	layer2.layer = 9
	add_child(layer2)
	var top := Button.new()
	top.text = "Dessus"
	top.position = Vector2(700, 300)
	top.custom_minimum_size = Vector2(150, 60)
	layer2.add_child(top)
	await get_tree().process_frame
	check("seuls les contrôles du calque le plus haut sont navigables", UiNav.candidates() == [top])
	layer2.queue_free()
	await get_tree().process_frame
	# curseur libre : le cadre disparaît
	UiNav.free_mode = true
	check("curseur libre : pas de navigation au cadre", not UiNav.nav_on())
	UiNav.free_mode = false
	check("navigation au cadre active avec la manette dans un menu", UiNav.nav_on())
	Gamepad.active = false
	check("souris : pas de navigation au cadre", not UiNav.nav_on())
	Gamepad.active = true
	# onglets
	var tc := TabContainer.new()
	for n in 3:
		var c := Control.new()
		c.name = "T%d" % n
		tc.add_child(c)
	tc.size = Vector2(400, 200)
	layer.add_child(tc)
	await get_tree().process_frame
	check("R1 : onglet suivant", UiNav.step_tab(1) and tc.current_tab == 1)
	check("L1 : onglet précédent, puis tour complet", UiNav.step_tab(-1) and UiNav.step_tab(-1) and tc.current_tab == 2)
	# manette réassignable
	check("disposition automatique : Xbox par défaut", Settings.pad_layout() == "xbox" and Settings.pad_action_label("interact") == "A" and Settings.pad_action_label("skill_2") == "RT")
	Settings.set_v("interface", "pad_labels", "ps")
	check("disposition PlayStation", Settings.pad_action_label("interact") == "Croix" and Settings.pad_action_label("skill_2") == "R2")
	Settings.set_v("interface", "pad_labels", "xbox")
	var lost := Settings.pad_bind("jump", {"b": JOY_BUTTON_X})
	check("réassigner : Saut prend X, Attaque le perd", Settings.pad_binds["jump"] == [{"b": JOY_BUTTON_X}] and "Attaquer (clic principal)" in lost and Settings.pad_binds["attack"].is_empty())
	check("l'InputMap suit", InputMap.action_get_events("jump").any(func(e): return e is InputEventJoypadButton and e.button_index == JOY_BUTTON_X))
	Settings.save_settings()
	Settings.pad_binds = {}
	Settings.load_settings()
	check("manette sauvegardée et rechargée", Settings.pad_binds.get("jump") == [{"b": JOY_BUTTON_X}] or Settings.pad_binds.get("jump", [{}])[0].get("b") == JOY_BUTTON_X)
	Settings.reset_pad_bindings()
	check("manette par défaut rétablie", Settings.pad_binds["attack"] == [{"b": JOY_BUTTON_X}] and Settings.pad_binds["jump"] == [{"b": JOY_BUTTON_Y}])
	check("gâchette décrite", Settings.describe_pad(_trigger(JOY_AXIS_TRIGGER_RIGHT)) == {"a": JOY_AXIS_TRIGGER_RIGHT, "v": 1.0})
	check("un stick ne s'assigne pas", Settings.describe_pad(_trigger(JOY_AXIS_LEFT_X)).is_empty())
	Gamepad.active = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _trigger(axis: int) -> InputEventJoypadMotion:
	var m := InputEventJoypadMotion.new()
	m.axis = axis as JoyAxis
	m.axis_value = 1.0
	return m
