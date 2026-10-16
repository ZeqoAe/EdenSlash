extends Node
## Captures du lot AC-E (combat réel de l'Échiquier) en 1280 × 720 : début du combat (barres, noms, étoiles), mêlée à 6 s,
## Fureur après 30 s. Fichiers user://shots/ace_<largeur>_*.png. APPDATA détourné : godot --path game res://tests/shot_ac_fight.tscn

var dir: AutochessDirector


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	var w := get_window().size.x
	get_viewport().get_texture().get_image().save_png("user://shots/ace_%d_%s.png" % [w, name])
	print("[shot] ace_%d_%s" % [w, name])


func _team(ids: Array, front: bool) -> Array:
	var out: Array = []
	for i in ids.size():
		var d := AutochessData.unit(String(ids[i]))
		out.append({"uid": i + 1, "id": ids[i], "stars": 1 + (i % 3 if i < 3 else 0), "copies": 1, "items": [],
			"cell": [1 + i, 0 if front and i < 3 else 2], "cost": int(d.get("cost", 1)), "traits": d.get("traits", [])})
	return out


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	load("res://tools/acf_demo.gd").build_scene(self)
	var board := AutochessBoard.new()
	add_child(board)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	board.frame_camera(cam, 0)
	dir = AutochessDirector.new()
	dir.view = board
	dir.camera = cam
	dir.fallback_ms = 0.0
	add_child(dir)
	var a := _team(["warrior", "knight", "hunter", "magician", "cleric"], true)
	var b := _team(["thief", "berserker", "ranger", "warlock", "bard"], true)
	dir.begin([{"board_a": a, "board_b": b, "ctx": {"seed": 5, "kind": "jcj", "stage": 3, "augments": [[], []]}}], 0)
	await get_tree().create_timer(0.6).timeout
	await _shot("1_debut")
	await get_tree().create_timer(6.0).timeout
	await _shot("2_melee")
	dir.set_speed(4.0)
	await get_tree().create_timer(6.0).timeout
	await _shot("3_suite")
	get_tree().quit()
