extends Node
## Planches d'animations du héros (lot CHR-1) : chaque case = le corps commun (body_m.glb) figé à un instant d'une animation
## (l'impact lu dans data/motion_keys.json, sinon 55 % de la durée), pour choisir à l'œil les coups de poing, de pied,
## les gestes de sort. Aussi des bandes : une animation à N instants (pour juger le mouvement).
## Fenêtre obligatoire (pas --headless : rendu factice).
##   godot --path game res://tools/anim_sheet.tscn -- --prefix=attack,shoot [--class=martial_artist] [--out=C:/AI/chr1/anims]
##   godot --path game res://tools/anim_sheet.tscn -- --strip=shoot24,attack21 --frames=8
## Sortie : <out>/sheet_<n>.png (6 × 4 cases, 1600 × 900) ou <out>/strip_<anim>.png.

const COLS := 6
const ROWS := 4
const CELL := Vector2i(264, 214)

var _out := "user://anim_sheet"
var _cls := "martial_artist"
var _pose := ""  # --pose=kick : calque ProcPose tenu sur chaque case


func _ready() -> void:
	var prefixes: Array = ["attack", "shoot"]
	var strips: Array = []
	var frames := 8
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--prefix="):
			prefixes = Array(a.trim_prefix("--prefix=").split(","))
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--class="):
			_cls = a.trim_prefix("--class=")
		elif a.begins_with("--strip="):
			strips = Array(a.trim_prefix("--strip=").split(","))
		elif a.begins_with("--pose="):
			_pose = a.trim_prefix("--pose=")
		elif a.begins_with("--frames="):
			frames = int(a.trim_prefix("--frames="))
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(COLS * CELL.x, ROWS * CELL.y)
	await get_tree().process_frame
	if not strips.is_empty():
		# bandes : 4 animations par page, une rangée de COLS instants chacune
		var p := 0
		while p * ROWS < strips.size():
			var cells: Array = []
			for s in strips.slice(p * ROWS, (p + 1) * ROWS):
				cells.append_array(_strip_cells(String(s), COLS))
			await _page(cells, "%s/strips_%d.png" % [_out, p])
			p += 1
		get_tree().quit()
		return
	var keys: Dictionary = GameData.motion_keys.get("m", {})
	var have = JSON.parse_string(FileAccess.get_file_as_string("res://assets/player/body/body_m.anims.json"))  # animations du corps commun
	if not have is Dictionary:
		have = {}
	var names: Array = []
	for k in keys:
		if not have.is_empty() and not have.has(k):
			continue  # absente du corps commun (elle n'existe que dans un .kfm d'Eden non converti)
		for p in prefixes:
			if String(k).begins_with(String(p)):
				names.append(String(k))
				break
	names.sort()
	var page := 0
	while page * COLS * ROWS < names.size():
		var slice := names.slice(page * COLS * ROWS, (page + 1) * COLS * ROWS)
		var cells: Array = []
		for n in slice:
			var info: Dictionary = keys.get(n, {})
			var hits: Array = info.get("hit", [])
			var t := float(hits[0]) if not hits.is_empty() else float(info.get("len", 1.0)) * 0.55
			cells.append([n, t, "%s  %.2f s / %.2f" % [n, t, float(info.get("len", 0.0))]])
		await _page(cells, "%s/sheet_%d.png" % [_out, page])
		page += 1
	get_tree().quit()


## Une animation à [param n] instants répartis sur sa durée.
func _strip_cells(anim: String, n: int) -> Array:
	var info: Dictionary = GameData.motion_keys.get("m", {}).get(anim, {})
	var length := float(info.get("len", 1.0))
	var cells: Array = []
	for i in n:
		var t := length * float(i) / maxf(n - 1, 1)
		cells.append([anim, t, "%s  %.2f s" % [anim, t]])
	return cells


func _page(cells: Array, path: String) -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	layer.add_child(grid)
	var cls := GameData.class_data(_cls)
	var posed: Array = []  # [AnimationPlayer, instant] : remis à l'instant à chaque image (le calque ProcPose suit)
	for c in cells:
		var box := SubViewportContainer.new()
		box.custom_minimum_size = CELL
		box.stretch = true
		grid.add_child(box)
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.size = CELL
		box.add_child(vp)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.2, 0.16, 0.34)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.8, 0.76, 0.86)
		vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35, 30, 0)
		vp.add_child(sun)
		var cam := Camera3D.new()
		cam.fov = 38.0
		# trois quarts face, un peu en hauteur : on lit bras et jambes
		cam.transform = Transform3D(Basis(), Vector3(2.3, 1.35, 1.25)).looking_at(Vector3(0, 0.85, 0.35))
		vp.add_child(cam)
		var model := EdenModel.instantiate_hero(cls)
		model.scale = Vector3.ONE * GameData.HERO_SCALE
		vp.add_child(model)
		var ap := EdenModel.find_anim_player(model)
		if ap and ap.has_animation(String(c[0])):
			ap.play(String(c[0]))
			ap.seek(float(c[1]), true)
			ap.speed_scale = 0.0
			posed.append([ap, float(c[1])])
		if _pose != "":
			ProcPose.on(model).hold(_pose, 999.0)
		var l := Label.new()
		l.text = String(c[2])
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 5)
		box.add_child(l)
	for _i in 10:
		await get_tree().process_frame
		for e in posed:
			(e[0] as AnimationPlayer).seek(float(e[1]) + 0.001 * float(_i % 2), true)  # un instant qui change : le squelette se remet à jour (et le calque avec)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("[anim_sheet] ", path)
	layer.queue_free()
	await get_tree().process_frame
