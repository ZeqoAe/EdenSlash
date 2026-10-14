extends Node
## Planche de comparaison des effets de sorts : pour chaque sort choisi, l'effet d'incantation à l'échelle
## d'origine (gauche) et à l'échelle ajustée à la zone (droite), avec la zone de dégâts en rouge. Figé à 40 % de
## l'animation, vue de trois quarts comme en jeu. Demande un rendu (pas de --headless) :
##   godot --path game res://tools/fx_sheet.tscn -- --class=samurai [--page=0] [--out=nom]
## Écrit user://shots/fxsheet_<nom>.png

const COLS := 3  # sorts par ligne (chacun : 2 effets côte à côte)
const ROWS := 3
const CELL := 16.0


func _ring(root: Node3D, pos: Vector3, radius: float, col: Color) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 49:
		var a := TAU * i / 48.0
		mesh.surface_add_vertex(Vector3(cos(a), 0.05, sin(a)) * radius)
	mesh.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	mi.material_override = m
	root.add_child(mi)
	mi.position = pos


func _ready() -> void:
	var cls := "samurai"
	var page := 0
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--class="):
			cls = a.get_slice("=", 1)
		elif a.begins_with("--page="):
			page = int(a.get_slice("=", 1))
		elif a.begins_with("--out="):
			out = a.get_slice("=", 1)
	if out == "":
		out = "%s_%d" % [cls, page]
	var skills: Array = (GameData.class_data(cls).get("skills", []) as Array).filter(func(s): return float(s.get("radius", 0.0)) > 0.0 and String(s.get("fx", {}).get("cast", "")) != "" and not String(s.get("kind", "")) in ["buff", "heal"])
	skills = skills.slice(page * COLS * ROWS, (page + 1) * COLS * ROWS)
	var world := Node3D.new()
	add_child(world)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.55, 0.3)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = gm
	world.add_child(ground)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.65, 0.8)
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var cam := Camera3D.new()
	world.add_child(cam)
	var width := COLS * CELL * 2.0
	cam.look_at_from_position(Vector3(width * 0.5 - CELL, 34.0, ROWS * CELL * 0.5 + 24.0), Vector3(width * 0.5 - CELL, 0, ROWS * CELL * 0.5 - 1.0), Vector3.UP)
	cam.fov = 55.0
	var fxs: Array = []
	for i in skills.size():
		var s: Dictionary = skills[i]
		var col := i % COLS
		var row := i / COLS
		var zone := float(s.radius)
		var cast := String(s.fx.cast)
		for variant in 2:
			var pos := Vector3((col * 2 + variant) * CELL * 0.5 * 2.0 / 2.0 * 1.0, 0, row * CELL)
			pos.x = (col * 2 + variant) * CELL
			_ring(world, pos, zone, Color(1, 0.1, 0.1))
			var sc := GameData.HERO_SCALE if variant == 0 else EdenFx.cast_scale(cast, s, zone)
			if not EdenFx._load(cast):
				continue
			var fx := EdenFx.new()
			fx.fx_name = cast
			world.add_child(fx)
			fx.global_transform = Transform3D(Basis(Vector3.UP, 0.0).scaled(Vector3.ONE * sc), pos)
			fx.set_process(false)
			fxs.append([fx, 0.4])
			var lab := Label3D.new()
			lab.text = "%s r=%.1f  %s ×%.2f" % [s.name, zone, "avant" if variant == 0 else "après", sc]
			lab.font_size = 56
			lab.pixel_size = 0.012
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.no_depth_test = true
			lab.position = pos + Vector3(0, 0.2, CELL * 0.42)
			world.add_child(lab)
	await get_tree().process_frame
	for e in fxs:
		var fx: EdenFx = e[0]
		var dur := float(fx._data.get("duration", 1.0))
		fx._t = dur * float(e[1])
		fx._apply(int(fx._t * float(fx._data.get("fps", 30.0))))
	await get_tree().create_timer(0.4).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/fxsheet_%s.png" % out)
	get_tree().quit()
