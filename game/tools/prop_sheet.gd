extends Node3D
## Planche d'aperçus des décors d'Eden (repérage) :
## godot --path game res://tools/prop_sheet.tscn -- <préfixe> [début]  -> user://shots/props_<préfixe>_<début>.png
## 48 modèles par planche (8 × 6), dans l'ordre alphabétique ; noms affichés dans la console.

const CELL := 200
const COLS := 8
const ROWS := 6


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var prefix := String(args[0]) if args.size() > 0 else "uc"
	var first := int(args[1]) if args.size() > 1 else 0
	var names: Array = []
	for f in DirAccess.get_files_at("res://assets/maps/objects"):
		if f.begins_with(prefix) and f.ends_with(".glb"):
			names.append(f.trim_suffix(".glb"))
	names.sort()
	names = names.slice(first, first + COLS * ROWS)
	var vp := SubViewport.new()
	vp.size = Vector2i(CELL, CELL)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.35, 0.4, 0.45)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 35
	vp.add_child(cam)
	var sheet := Image.create(CELL * COLS, CELL * ROWS, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i in names.size():
		var scene: PackedScene = load("res://assets/maps/objects/%s.glb" % names[i])
		if scene == null:
			continue
		var node := scene.instantiate() as Node3D
		vp.add_child(node)
		var box := _aabb(node)
		var c := box.get_center()
		var r := maxf(box.size.length() * 0.5, 0.1)
		cam.position = c + Vector3(0.6, 0.55, 1.0).normalized() * r * 3.0
		cam.look_at(c, Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i((i % COLS) * CELL, (i / COLS) * CELL))
		print("%d %s taille %.1f x %.1f x %.1f" % [i, names[i], box.size.x, box.size.y, box.size.z])
		node.queue_free()
	DirAccess.make_dir_recursive_absolute("user://shots")
	sheet.save_png("user://shots/props_%s_%d.png" % [prefix, first])
	get_tree().quit()


func _aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
