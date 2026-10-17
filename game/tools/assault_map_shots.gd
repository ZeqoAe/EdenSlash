extends Node3D
## Aperçu d'une carte de L'Assaut (lot TAC-1) : mini-carte (marche sans fenêtre), vue d'ensemble de dessus, puis vues à
## l'angle de la caméra de jeu (départs, sites, lieux nommés), avec les sites, départs et lieux posés au sol. Pour juger
## une carte sans jouer (lisibilité, couverts, hauteurs).
## godot --path game res://tools/assault_map_shots.tscn -- [id=bourg] [--res=1600x900]   -> user://shots/assault_<id>_*.png

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var id := "bourg"
	for a in args:
		if not a.begins_with("--"):
			id = a
		elif a.begins_with("--res="):
			var wh := a.trim_prefix("--res=").split("x")
			get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.62, 0.78, 0.93)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.78, 0.78, 0.82)
	we.environment.ambient_light_energy = 0.7
	we.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	var m := ProcMap.new()
	m.biome = "limestone"
	add_child(m)
	var t0 := Time.get_ticks_msec()
	m.generate_assault(id)
	print("[assault_map] %s construite en %d ms" % [id, Time.get_ticks_msec() - t0])
	_marks(m)
	DirAccess.make_dir_recursive_absolute("user://shots")
	var mm: Image = m._minimap.get_image()
	mm.resize(768, 768, Image.INTERPOLATE_NEAREST)
	mm.save_png("user://shots/assault_%s_minimap.png" % id)
	print("mini-carte : ", ProjectSettings.globalize_path("user://shots/assault_%s_minimap.png" % id))
	while m._region.navigation_mesh == null:
		await get_tree().physics_frame  # (piège T1 : la navigation cuit sur un fil)
	if DisplayServer.get_name() == "headless":
		get_tree().quit()
		return
	var cam := Camera3D.new()
	cam.fov = 45
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	var c := AssaultMap.to_world(m, (m.assault.plan_size as Vector2) * 0.5)
	var views: Array = [["ensemble", c, 0.0, 0.0]]
	views.append(["depart_attaque", m.assault.spawns.attack.pos, 15.0, 52.0])
	views.append(["depart_defense", m.assault.spawns.defense.pos, 15.0, 52.0])
	for s in ["A", "B"]:
		views.append(["site_" + s.to_lower(), m.assault.sites[s].pos, 15.0, 52.0])
		views.append(["site_%s_large" % s.to_lower(), m.assault.sites[s].pos, 32.0, 60.0])
	for pl in m.assault.places:
		if String(pl.name) in ["Place", "Carrefour", "Ruelle ouest", "Quai est", "Halle"]:
			views.append([String(pl.name).to_lower().replace(" ", "_"), pl.pos, 15.0, 52.0])
	for i in views.size():
		var v: Array = views[i]
		var at: Vector3 = v[1]
		if float(v[2]) == 0.0:
			cam.projection = Camera3D.PROJECTION_ORTHOGONAL
			cam.size = maxf((m.assault.plan_size as Vector2).x, (m.assault.plan_size as Vector2).y) + 8.0
			cam.global_position = at + Vector3(0, 120, 0)
			cam.look_at(at, Vector3.FORWARD)
		else:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			var pitch := deg_to_rad(float(v[3]))
			cam.global_position = at + Vector3(0, sin(pitch), cos(pitch)) * float(v[2])
			cam.look_at(at, Vector3.UP)
		for f in 6:
			await RenderingServer.frame_post_draw
		var path := "user://shots/assault_%s_%02d_%s.png" % [id, i, String(v[0])]
		get_viewport().get_texture().get_image().save_png(path)
		print("vue : ", ProjectSettings.globalize_path(path))
	get_tree().quit()


## Sites (disque soleil et lettre), départs (lagon / mandarine) et noms des lieux posés au sol pour l'aperçu.
func _marks(m: ProcMap) -> void:
	for s in m.assault.sites:
		var sd: Dictionary = m.assault.sites[s]
		var r: Rect2 = sd.rect
		_plate(Vector3(r.get_center().x, 0.05, r.get_center().y), r.size, Color(UiTheme.color("bonbon.soleil.base"), 0.25))
		_label(s, (sd.pos as Vector3) + Vector3.UP * 4.0, 220, UiTheme.color("bonbon.soleil.base"))
	for k in m.assault.spawns:
		var sp: Dictionary = m.assault.spawns[k]
		var col := UiTheme.color("bonbon.mandarine.base") if k == "attack" else UiTheme.color("bonbon.lagon.base")
		_plate((sp.pos as Vector3) + Vector3.UP * 0.05, (sp.half as Vector2) * 2.0, Color(col, 0.35))
		_label("Attaque" if k == "attack" else "Défense", (sp.pos as Vector3) + Vector3.UP * 2.5, 90, col)
	for pl in m.assault.places:
		if not String(pl.name).begins_with("Site"):
			_label(String(pl.name), (pl.pos as Vector3) + Vector3.UP * 1.8, 64, Color.WHITE)


func _plate(at: Vector3, size: Vector2, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	mi.material_override = mat
	add_child(mi)
	mi.global_position = at


func _label(text: String, at: Vector3, size: int, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = size
	l.pixel_size = 0.01
	l.outline_size = maxi(8, size / 6)
	l.modulate = col
	l.outline_modulate = UiTheme.color("encre.900", Color("221a3a"))
	add_child(l)
	l.global_position = at
