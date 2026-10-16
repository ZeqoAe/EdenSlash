extends Node
## Captures du lot AC-F (plateau de l'Échiquier), en 1280 × 720 puis 1600 × 900 : vue d'ensemble, unité tenue (zone
## « Vendre »), plateau plein (cases libres en rouge), zoom, curseur à la manette (cadre doré de UiNav).
## Fichiers user://shots/acf_<largeur>_*.png. APPDATA détourné : godot --path game res://tests/shot_acf.tscn

var demo: Node3D


func _shot(name: String) -> void:
	# la vraie souris (hors de la fenêtre) ne doit pas reprendre le curseur pendant la capture
	if demo:
		demo.cursor._last_mouse = get_viewport().get_mouse_position()
	await get_tree().create_timer(0.8).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	var w := get_window().size.x
	get_viewport().get_texture().get_image().save_png("user://shots/acf_%d_%s.png" % [w, name])
	print("[shot] acf_%d_%s" % [w, name])


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "magician"
	Profile.hero_name = "Aelis"
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = res
		await get_tree().process_frame
		if demo:
			demo.queue_free()
			await get_tree().process_frame
		demo = load("res://tools/acf_demo.tscn").instantiate()
		add_child(demo)
		await get_tree().create_timer(1.0).timeout
		var cur: AutochessCursor = demo.cursor
		var board: AutochessBoard = demo.board
		demo.shuffle(11, 6)
		cur._set_slot(AutochessBoard.board_slot(3, 1), "keys")
		await _shot("1_preparation")
		# unité du banc tenue à la souris au-dessus d'une case libre
		board.level = 8
		cur._set_slot(AutochessBoard.bench_slot(1), "keys")
		cur.activate()
		var free := AutochessBoard.board_slot(0, 0)
		for r in AutochessBoard.ROWS:
			for c in AutochessBoard.COLS:
				if board.unit_at(AutochessBoard.board_slot(c, r)).is_empty():
					free = AutochessBoard.board_slot(c, r)
		cur._set_slot(free, "keys")
		await _shot("2_tenue")
		# plateau plein : cases libres en rouge
		board.level = board.board_count()
		await _shot("3_plein")
		cur.cancel()
		board.level = 8
		cur.set_zoom(1)
		cur._set_slot(AutochessBoard.board_slot(2, 2), "keys")
		await _shot("4_zoom")
		cur.set_zoom(0)
		# manette : cadre doré de UiNav sur la case, barre d'aide
		Gamepad._set_active(true)
		UiNav.focus(cur.control_of(AutochessBoard.bench_slot(4)))
		await _shot("5_manette")
		Gamepad._set_active(false)
	get_tree().quit()
