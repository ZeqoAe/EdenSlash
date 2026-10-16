extends Node3D
## L'Échiquier (lot AC-F) : démonstration du plateau, sans machine de partie. Pose des unités au hasard (plateau, banc,
## objets, adversaire en miroir) et affiche les signaux du plateau dans la console.
##   godot --path game res://tools/acf_demo.tscn [-- --seed=N --level=N]
## Touches : R nouvelles unités · Page haut / bas : niveau · flèches, Entrée, E, Échap : curseur · molette : zoom.

var board: AutochessBoard
var cursor: AutochessCursor
var camera: Camera3D
var rng := RandomNumberGenerator.new()
var _info: Label


func _ready() -> void:
	var seed_ := 7
	var lv := 6
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_ = int(a.get_slice("=", 1))
		elif a.begins_with("--level="):
			lv = int(a.get_slice("=", 1))
	build_scene(self)
	board = AutochessBoard.new()
	add_child(board)
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	board.frame_camera(camera, 0)
	cursor = AutochessCursor.new()
	add_child(cursor)
	cursor.setup(board, camera)
	board.unit_placed.connect(func(u, f, t): _log("placée : %s %s -> %s" % [AutochessData.unit_name(u.id), _s(f), _s(t)]))
	board.unit_sold.connect(func(u, f): _log("vendue : %s (%s)" % [AutochessData.unit_name(u.id), _s(f)]))
	board.item_given.connect(func(it, u, _f): _log("objet : %s -> %s" % [AutochessData.item(it).get("name", it), AutochessData.unit_name(u.id)]))
	board.placement_refused.connect(func(why): _log("refusé : " + why))
	_info = Label.new()
	_info.position = Vector2(16, 12)
	_info.add_theme_color_override("font_color", UiTheme.MUTED)
	var ui := CanvasLayer.new()
	ui.add_child(_info)
	add_child(ui)
	shuffle(seed_, lv)


## Décor commun de la démo et des captures : fond bleu nuit, lumière, sol sombre.
static func build_scene(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.04, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.85)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(-28.0), 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	parent.add_child(sun)
	var floor_ := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = AutochessData.ARENA_RADIUS + 25.0
	cm.bottom_radius = cm.top_radius
	cm.height = 0.2
	cm.radial_segments = 64
	floor_.mesh = cm
	floor_.position.y = -0.6
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.045, 0.05, 0.12)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_.material_override = m
	parent.add_child(floor_)


## État au hasard : [param lv] unités sur le plateau, 6 au banc, 4 objets, un adversaire de même niveau.
static func random_state(r: RandomNumberGenerator, lv: int) -> Dictionary:
	var ids := AutochessData.unit_ids()
	var pick := func() -> Dictionary:
		var st := 1 + int(r.randf() < 0.35) + int(r.randf() < 0.12)
		var items: Array = []
		if r.randf() < 0.3:
			items = [["executeur", "transe", "lame", "baton"][r.randi() % 4]]
		return {"id": String(ids[r.randi() % ids.size()]), "stars": st, "items": items}
	var cells_ := {}
	var free: Array = []
	for row in AutochessBoard.ROWS:
		for c in AutochessBoard.COLS:
			free.append(AutochessBoard.key(c, row))
	var mine := free.duplicate()
	for i in mini(lv, free.size()):
		var k: String = mine.pop_at(r.randi() % mine.size())
		cells_[k] = pick.call()
	var bench_: Array = []
	for i in AutochessData.BENCH_SIZE:
		bench_.append(pick.call() if i < 6 else {})
	var foe := {}
	var theirs := free.duplicate()
	for i in mini(lv, free.size()):
		var k: String = theirs.pop_at(r.randi() % theirs.size())
		foe[k] = pick.call()
	return {"level": lv, "crowns": 0, "board": cells_, "bench": bench_, "items": ["lame", "arc", "baton", "executeur", "", "", "", "", "", ""],
		"foe": foe}


func shuffle(seed_: int, lv: int) -> void:
	rng.seed = seed_
	var st := random_state(rng, lv)
	board.set_state(st)
	board.set_enemy(st.foe, {"class_id": String(AutochessData.unit_ids()[rng.randi() % 60]), "name": "Stratège adverse"})
	_info.text = "R : nouvelles unités · Page haut / bas : niveau %d" % board.level


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match (ev as InputEventKey).keycode:
			KEY_R:
				shuffle(rng.randi(), board.level)
			KEY_PAGEUP:
				board.level += 1
				_info.text = "R : nouvelles unités · Page haut / bas : niveau %d" % board.level
			KEY_PAGEDOWN:
				board.level -= 1
				_info.text = "R : nouvelles unités · Page haut / bas : niveau %d" % board.level


func _log(s: String) -> void:
	print("[acf] " + s)


static func _s(slot: Dictionary) -> String:
	return AutochessBoard.slot_id(slot)
