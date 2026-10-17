extends Node
## L'Échiquier, lot AC-F : plateau (AutochessBoard), bancs (AutochessBench) et curseur de case (AutochessCursor).
## Placement limité au niveau, banc plein, échange, vente, objets, miroir de l'adversaire, curseur qui atteint toutes les
## cases à la manette (UiNav) et au clavier, souris (clic, glisser-déposer, zone « Vendre »), aucune unité hors plateau.
## godot --headless --path game res://tests/test_ac_board.tscn

var fails := 0
var board: AutochessBoard
var cursor: AutochessCursor
var camera: Camera3D
var placed: Array = []
var sold: Array = []
var refused: Array = []
var given: Array = []


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _u(id: String, stars := 1, items: Array = []) -> Dictionary:
	return {"id": id, "stars": stars, "items": items}


func _frames(n := 2) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	Training.active = true
	Profile.reset_all()
	get_window().size = Vector2i(1280, 720)
	board = AutochessBoard.new()
	add_child(board)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	board.frame_camera(camera, 0)
	cursor = AutochessCursor.new()
	add_child(cursor)
	cursor.setup(board, camera)
	board.unit_placed.connect(func(u, f, t): placed.append([u, f, t]))
	board.unit_sold.connect(func(u, f): sold.append([u, f]))
	board.placement_refused.connect(func(w): refused.append(w))
	board.item_given.connect(func(it, u, f): given.append([it, u]))
	await _frames()

	var B := AutochessBoard
	# 1. géométrie : 28 cases à soi, miroir exact de l'adversaire, cases de 2 m
	var mirror_ok := true
	for r in B.ROWS:
		for c in B.COLS:
			var a := AutochessBoard.cell_position(c, r)
			var e := AutochessBoard.cell_position(c, r, true)
			mirror_ok = mirror_ok and absf(a.x + e.x) < 0.001 and absf(a.z + e.z) < 0.001 and a.z > 0.0 and e.z < 0.0
	check("miroir : la case (c, r) adverse est la case (c, r) tournée d'un demi-tour", mirror_ok)
	check("cases de 2 m (voisines d'une même rangée)", absf(AutochessBoard.cell_position(1, 0).x - AutochessBoard.cell_position(0, 0).x - 2.0) < 0.001)
	check("rangée 0 = ligne de front (la plus proche du centre)", AutochessBoard.cell_position(3, 0).z < AutochessBoard.cell_position(3, 3).z)
	check("47 cases au curseur (28 + banc 9 + objets 10)", board.all_slots().size() == 47)

	# 2. placement limité au niveau
	board.set_state({"level": 3, "board": {"0,0": _u("warrior"), "3,1": _u("knight", 2), "6,3": _u("thief")},
		"bench": [_u("hunter"), _u("cleric"), {}, {}, {}, {}, {}, {}, {}], "items": ["lame", "arc"]})
	check("état posé : 3 sur le plateau, cap 3", board.board_count() == 3 and board.cap() == 3)
	check("du banc vers une case libre, plateau plein : refusé", not board.move(B.bench_slot(0), AutochessBoard.board_slot(2, 2)) and refused.size() == 1)
	check("texte du refus en français, court", String(refused[0]).begins_with("Plateau plein") and String(refused[0]).length() < 60)
	placed.clear()
	check("du banc vers une case occupée : échange permis", board.move(B.bench_slot(0), AutochessBoard.board_slot(0, 0)))
	check("échange : deux signaux unit_placed", placed.size() == 2 and String(placed[0][0].id) == "hunter" and String(placed[1][0].id) == "warrior")
	check("échange : le Guerrier est au banc, le Chasseur au front", String(board.unit_at(B.bench_slot(0)).id) == "warrior"
		and String(board.unit_at(AutochessBoard.board_slot(0, 0)).id) == "hunter" and board.board_count() == 3)
	check("du plateau vers le banc libre : une place se libère", board.move(AutochessBoard.board_slot(6, 3), B.bench_slot(4)) and board.board_count() == 2)
	check("puis du banc vers le plateau : permis", board.move(B.bench_slot(1), AutochessBoard.board_slot(2, 2)) and board.board_count() == 3)
	check("sur le plateau : déplacement libre", board.move(AutochessBoard.board_slot(2, 2), AutochessBoard.board_slot(5, 0)) and board.unit_at(AutochessBoard.board_slot(2, 2)).is_empty())
	board.level = 4
	check("niveau 4 : une place de plus", board.move(B.bench_slot(4), AutochessBoard.board_slot(1, 3)) and board.board_count() == 4)
	board.crowns = 1
	check("Couronne : +1 place", board.cap() == 5)
	board.crowns = 0
	check("vers la moitié adverse ou hors grille : refusé", not board.move(AutochessBoard.board_slot(0, 0), AutochessBoard.board_slot(0, 4))
		and not board.move(AutochessBoard.board_slot(0, 0), {"zone": "board", "col": 7, "row": 0}) and not board.move(B.bench_slot(0), B.bench_slot(9)))
	check("case vide : rien ne bouge", not board.move(B.bench_slot(8), B.bench_slot(7)))

	# 3. banc plein
	var st := board.state()
	for i in AutochessData.BENCH_SIZE:
		if (st.bench[i] as Dictionary).is_empty():
			board.add_to_bench(_u("magician"))
	check("banc plein : plus de place", board.first_free_bench() == -1 and board.add_to_bench(_u("ranger")) == -1)
	check("banc plein : un échange plateau ↔ banc reste permis", board.move(AutochessBoard.board_slot(0, 0), B.bench_slot(8)) and board.board_count() == 4)

	# 4. vente : l'unité part, ses objets reviennent au banc d'objets
	board.set_state({"level": 3, "board": {"2,1": _u("knight", 2, ["lame", "transe"])}, "bench": [_u("warrior", 3)], "items": []})
	sold.clear()
	var v := board.sell_value(AutochessBoard.board_slot(2, 1))
	check("prix de vente = AutochessData.sell_value", v == AutochessData.sell_value(int(AutochessData.unit("knight").cost), 2))
	check("vente : unit_sold et case vide", board.sell(AutochessBoard.board_slot(2, 1)) and sold.size() == 1 and board.board_count() == 0)
	check("vente : objets rendus au banc d'objets", board.item_at(B.items_slot(0)) == "lame" and board.item_at(B.items_slot(1)) == "transe")
	check("vendre une case vide : rien", not board.sell(AutochessBoard.board_slot(2, 1)))

	# 5. objets : au héros visé, trois au plus
	board.set_state({"level": 3, "board": {"3,0": _u("warrior", 1, ["lame", "arc"])}, "bench": [], "items": ["baton", "larme", "", "", "", "", "", "", "", ""]})
	check("objet donné au héros", board.move(B.items_slot(0), AutochessBoard.board_slot(3, 0)) and given.size() == 1
		and (board.unit_at(AutochessBoard.board_slot(3, 0)).items as Array).size() == 3 and board.item_at(B.items_slot(0)) == "")
	check("quatrième objet : refusé", not board.move(B.items_slot(1), AutochessBoard.board_slot(3, 0)))
	check("objet sur une case vide : refusé", not board.move(B.items_slot(1), AutochessBoard.board_slot(4, 0)))
	check("objets : échange sur le banc d'objets", board.move(B.items_slot(1), B.items_slot(5)) and board.item_at(B.items_slot(5)) == "larme")
	check("une unité ne va pas sur le banc d'objets", not board.move(AutochessBoard.board_slot(3, 0), B.items_slot(2)))

	# 6. aucune unité hors plateau : cases invalides écartées vers le banc, figurines à leur case
	board.set_state({"level": 9, "board": {"0,0": _u("warrior"), "9,9": _u("knight"), "2,5": _u("thief"), "3,-1": _u("cleric"), "x": _u("hunter")},
		"bench": [], "items": []})
	board.set_enemy({"0,0": _u("magician"), "6,3": _u("ranger", 3), "8,0": _u("thief")}, {"class_id": "cleric", "name": "Ombre"})
	await _frames()
	check("cases invalides : unités renvoyées au banc", board.board_count() == 1 and board.first_free_bench() == 4)
	check("adverse : case invalide écartée", board.enemy.size() == 2)
	var inside := true
	var homes: Array = []
	for r in B.ROWS:
		for c in B.COLS:
			homes.append(AutochessBoard.cell_position(c, r))
			homes.append(AutochessBoard.cell_position(c, r, true))
	for i in AutochessData.BENCH_SIZE:
		homes.append(AutochessBench.slot_position(i))
	var figs := board.get_children().filter(func(n): return n.has_meta("home") and not n.is_queued_for_deletion())
	for f in figs:
		var h: Vector3 = f.get_meta("home")
		inside = inside and homes.any(func(p): return p.distance_to(h) < 0.01) and Vector2(h.x, h.z).length() < B.PLINTH_R
	check("figurines : %d, chacune sur une case du plateau ou du banc" % figs.size(), figs.size() == 7 and inside)
	check("stratège adverse en miroir", board.foe_strategist != null and board.foe_strategist.position.z < 0.0)
	check("stratège du joueur : son nom (ou sa classe)", board.strategist != null and board.strategist.find_children("*", "Label3D", true, false).size() == 1)

	# forme de la partie (AC-B) : liste d'unités avec « cell », banc avec null
	board.set_state({"level": 4, "crowns": 0, "board": [{"uid": 900, "id": "warrior", "stars": 2, "items": [], "cell": [2, 0]},
		{"uid": 901, "id": "knight", "stars": 1, "items": [], "cell": [9, 0]}], "bench": [null, {"uid": 902, "id": "thief", "stars": 1, "items": []}, null],
		"items": ["lame"]})
	check("état de la partie (AC-B) lu tel quel", String(board.unit_at(AutochessBoard.board_slot(2, 0)).id) == "warrior" and int(board.unit_at(AutochessBoard.board_slot(2, 0)).uid) == 900
		and String(board.unit_at(B.bench_slot(1)).id) == "thief" and board.board_count() == 1 and String(board.unit_at(B.bench_slot(0)).id) == "knight")
	board.set_enemy([{"uid": 950, "id": "cleric", "stars": 1, "items": [], "cell": [0, 0]}])
	check("adversaire en liste (AC-B) : en miroir", board.enemy.size() == 1 and not board.enemy.get("0,0", {}).is_empty())

	# 7. curseur à la manette : UiNav atteint les 47 cases par les sauts entre voisines
	board.set_state({"level": 3, "board": {"1,1": _u("warrior")}, "bench": [_u("knight"), _u("hunter")], "items": ["lame"]})
	await _frames()
	var start := cursor.control_of(B.bench_slot(0))
	check("contrôles des cases navigables (UiNav)", UiNav.navigable(start) and UiNav.candidates().has(start))
	var seen := {AutochessBoard.slot_id(start.get_meta("ac_slot")): true}
	var todo: Array = [start]
	while not todo.is_empty():
		var c: Control = todo.pop_back()
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			UiNav._set_cursor(c)
			if UiNav.move(d) and UiNav.cursor.has_meta("ac_slot"):
				var id := AutochessBoard.slot_id(UiNav.cursor.get_meta("ac_slot"))
				if not seen.has(id):
					seen[id] = true
					todo.append(UiNav.cursor)
	check("manette : la croix atteint toutes les cases (%d / 47)" % seen.size(), seen.size() == 47)
	var back_ok := true
	for s in board.all_slots():
		var n := cursor.neighbors(s)
		var opp := {"left": "right", "right": "left", "up": "down", "down": "up"}
		for d in n:
			# sur le plateau et dans une même rangée / colonne, l'aller-retour revient à la case de départ
			if String(s.zone) == String(n[d].zone) and String(s.zone) != "items":
				var b2 := cursor.neighbors(n[d])
				back_ok = back_ok and b2.has(opp[d]) and AutochessBoard.same_slot(b2[opp[d]], s)
	check("aller-retour à la croix : même case", back_ok)
	# clavier : flèches
	cursor.slot = {}
	var kseen := {}
	var kto: Array = [B.bench_slot(4)]
	while not kto.is_empty():
		var s: Dictionary = kto.pop_back()
		kseen[AutochessBoard.slot_id(s)] = true
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			cursor.slot = s
			if cursor.move_dir(d) and not kseen.has(AutochessBoard.slot_id(cursor.slot)):
				kto.append(cursor.slot)
	check("clavier : les flèches atteignent toutes les cases (%d / 47)" % kseen.size(), kseen.size() == 47)
	# souris : le centre de chaque contrôle désigne sa propre case
	var pick_ok := true
	var on_screen := true
	var vr := get_viewport().get_visible_rect()
	for s in board.all_slots():
		var c := cursor.control_of(s)
		var center := c.get_global_rect().get_center()
		pick_ok = pick_ok and AutochessBoard.same_slot(cursor.screen_slot(center), s)
		on_screen = on_screen and vr.encloses(c.get_global_rect())
	check("souris : chaque case se vise à l'écran", pick_ok)
	check("1280 × 720 : toutes les cases à l'écran", on_screen)

	# 8. prendre / poser au clic (A de la manette = clic au centre de la case)
	placed.clear()
	_click(B.bench_slot(0))
	check("clic sur une unité : tenue", AutochessBoard.same_slot(cursor.held, B.bench_slot(0)))
	await _frames()
	check("unité tenue : zone « Vendre » visible avec son prix", cursor._sell.visible and cursor._sell_text.text.contains("+1 or"))
	_click(AutochessBoard.board_slot(4, 2))
	check("clic sur une case libre : posée", cursor.held.is_empty() and String(board.unit_at(AutochessBoard.board_slot(4, 2)).id) == "knight" and placed.size() == 1)
	_click(B.bench_slot(1))
	_click(AutochessBoard.board_slot(5, 2))
	check("deuxième unité posée : plateau plein (3 / 3)", board.board_count() == 3 and cursor.held.is_empty())
	board.add_to_bench(_u("thief"))
	refused.clear()
	_click(B.bench_slot(0))
	_click(AutochessBoard.board_slot(6, 2))
	check("plateau plein : refusé, l'unité reste en main", refused.size() == 1 and AutochessBoard.same_slot(cursor.held, B.bench_slot(0)))
	check("B (annuler) : reposée", cursor.cancel() and cursor.held.is_empty() and String(board.unit_at(B.bench_slot(0)).id) == "thief")
	# glisser-déposer : du plateau vers le banc, puis vers la zone « Vendre »
	_drag(AutochessBoard.board_slot(4, 2), cursor.control_of(B.bench_slot(5)).get_global_rect().get_center())
	check("glisser-déposer : plateau → banc", String(board.unit_at(B.bench_slot(5)).id) == "knight")
	sold.clear()
	_press(B.bench_slot(5))
	_motion(B.bench_slot(5), cursor.control_of(B.bench_slot(5)).get_global_rect().get_center() + Vector2(40, -40))
	await _frames()
	var zone := cursor._sell.get_global_rect().get_center()
	_release(B.bench_slot(5), zone)
	check("glisser sur « Vendre » : vendue", sold.size() == 1 and board.unit_at(B.bench_slot(5)).is_empty())
	check("clavier : E vend l'unité sous le curseur", _key_sell(B.bench_slot(0)) and sold.size() == 2)

	# 9. manette : X maintenu 0,5 s vend (événements réels de manette)
	board.add_to_bench(_u("cleric"))
	var at: int = (board.state().bench as Array).find_custom(func(u): return not (u as Dictionary).is_empty() and String(u.id) == "cleric")
	UiNav._set_cursor(cursor.control_of(B.bench_slot(at)))
	_pad(JOY_BUTTON_DPAD_RIGHT, true)
	_pad(JOY_BUTTON_DPAD_RIGHT, false)
	await _frames(3)
	UiNav._set_cursor(cursor.control_of(B.bench_slot(at)))
	await _frames(2)
	check("manette : le curseur suit le cadre de UiNav", AutochessBoard.same_slot(cursor.slot, B.bench_slot(at)))
	sold.clear()
	_pad(JOY_BUTTON_X, true)
	await get_tree().create_timer(0.2).timeout
	check("X tenu 0,2 s : pas encore vendue", sold.is_empty() and cursor._sell.visible)
	await get_tree().create_timer(0.5).timeout
	_pad(JOY_BUTTON_X, false)
	check("X tenu 0,5 s : vendue", sold.size() == 1 and String(sold[0][0].id) == "cleric")
	cursor.enabled = false
	check("curseur coupé (combat) : cases cachées", not cursor.control_of(B.bench_slot(0)).is_visible_in_tree())
	await _test_arena_style()

	print("\n%s : %d échec(s)" % ["TEST AC BOARD", fails])
	get_tree().quit(1 if fails > 0 else 0)


## Lot AC-V : plateau tracé au sol de l'arène (AutochessArena) : sans socle, cases plates au niveau des pieds, juste
## au-dessus du sol aplani, mêmes cases et même miroir ; elles s'allument et s'estompent.
func _test_arena_style() -> void:
	var arena := AutochessArena.new()
	add_child(arena)
	arena.build(AutochessArena.biome_for(1), 3)
	var ab := AutochessBoard.new()
	ab.arena_style = true
	add_child(ab)
	ab.set_state({"level": 3, "board": {"3,0": _u("warrior")}, "bench": [_u("cleric")]})
	await _frames(2)
	var pads: Array = ab._tiles.values() + ab.bench._pads + ab.bench._item_pads
	var flat := pads.size() == 56 + 9 + 10
	for parts in pads:
		for n in parts:
			if not (n as MeshInstance3D).mesh is ArrayMesh or absf((n as Node3D).position.y - AutochessBoard.TOP) > 0.01:
				flat = false
	check("arène : 75 cases plates au niveau des pieds (sans socle)", flat and ab.find_children("*", "MeshInstance3D", false, false).all(
		func(m): return not ((m as MeshInstance3D).mesh is CylinderMesh and ((m as MeshInstance3D).mesh as CylinderMesh).top_radius > 10.0)))
	var g := Vector3(0, AutochessArena.GROUND, 0)
	var ground_ok := true
	for p in [Vector3.ZERO, AutochessBoard.cell_position(0, 3), AutochessBoard.cell_position(6, 3, true), AutochessBench.slot_position(8),
			AutochessBench.item_position(4)]:
		var h: float = arena.map.height_at(p.x + arena.map.size * 0.5, p.z + arena.map.size * 0.5) + AutochessArena.GROUND
		if absf(h - g.y) > 0.005:
			ground_ok = false
	check("arène : sol aplani sous le plateau et les bancs, cases 2 cm au-dessus", ground_ok and AutochessArena.GROUND < AutochessBoard.TOP)
	check("arène : hors du groupe « map » (pas de chemins pour les unités)", not arena.map.is_in_group("map"))
	check("arène : mêmes cases que le socle (miroir compris)", ab.cell_world_position(2, 1, true).is_equal_approx(AutochessBoard.cell_position(2, 1, true)))
	var fill := (ab._tiles["3,0"][0] as MeshInstance3D).material_override as StandardMaterial3D
	var lit := fill.albedo_color.a
	ab.light_up(false, true)
	var dim := fill.albedo_color.a
	ab.light_up(true, true)
	check("arène : cases allumées en préparation (%.2f), estompées au combat (%.2f)" % [lit, dim], lit > 0.4 and dim < lit * 0.5 and is_equal_approx(fill.albedo_color.a, lit))
	ab.set_cursor(AutochessBoard.board_slot(3, 0))
	check("arène : la case visée brille (bord doré)", (ab._tiles["3,0"][1].material_override as StandardMaterial3D).emission_energy_multiplier >= 0.8)
	check("arène : décor de l'étape (biome %s, puis %s)" % [AutochessArena.biome_for(1), AutochessArena.biome_for(2)],
		AutochessArena.biome_for(1) == "arid" and AutochessArena.biome_for(2) != "arid" and arena.biome == "arid")
	ab.queue_free()
	arena.queue_free()
	await _frames(2)


func _center(s: Dictionary) -> Vector2:
	return cursor.control_of(s).get_global_rect().get_center()


func _mouse_ev(c: Control, global: Vector2, pressed: bool, device := 0) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.device = device
	e.position = global - c.get_global_rect().position
	return e


func _click(s: Dictionary) -> void:
	var c := cursor.control_of(s)
	cursor._on_cell_input(_mouse_ev(c, _center(s), true, -1), c)
	cursor._on_cell_input(_mouse_ev(c, _center(s), false, -1), c)


func _press(s: Dictionary) -> void:
	var c := cursor.control_of(s)
	cursor._on_cell_input(_mouse_ev(c, _center(s), true), c)


func _motion(s: Dictionary, to: Vector2) -> void:
	var c := cursor.control_of(s)
	var m := InputEventMouseMotion.new()
	m.position = to - c.get_global_rect().position
	cursor._on_cell_input(m, c)


func _release(s: Dictionary, at: Vector2) -> void:
	var c := cursor.control_of(s)
	cursor._on_cell_input(_mouse_ev(c, at, false), c)


func _drag(s: Dictionary, to: Vector2) -> void:
	_press(s)
	_motion(s, to)
	_release(s, to)


func _key_sell(s: Dictionary) -> bool:
	cursor.slot = s
	var had := not board.unit_at(s).is_empty()
	var e := InputEventKey.new()
	e.keycode = KEY_E
	e.pressed = true
	cursor._unhandled_input(e)
	return had and board.unit_at(s).is_empty()


func _pad(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	e.device = 0
	Input.parse_input_event(e)
