extends Node
## Captures du lot CHR-2 (« Héros détaillé » du Ninja du Tourbillon, ClassPremium) : avant / après, et planches des
## animations neuves. Les images de ce design restent HORS du dépôt : dossier CHR2_OUT (défaut C:/AI/chr2/captures).
##   godot --path game res://tests/shot_chr2.tscn            (fenêtre obligatoire ; APPDATA détourné conseillé)
##   CHR2_MODE=look (avant / après) | anims (8 instants par animation neuve, à côté de celle d'Eden qu'elle remplace)
##           | seq (suite d'images d'une animation neuve pour un GIF : CHR2_ANIM=ninja_kick, CHR2_YAW=40)

const CELL := Vector2i(400, 450)

var _out := "C:/AI/chr2/captures"


func _ready() -> void:
	var o := OS.get_environment("CHR2_OUT")
	if o != "":
		_out = o
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1600, 900)
	await get_tree().process_frame
	var mode := OS.get_environment("CHR2_MODE")
	if mode == "" or mode == "look":
		await _look_plate()
	if mode == "" or mode == "anims":
		await _anim_plates()
	if mode == "seq":
		await _seq(OS.get_environment("CHR2_ANIM"), float(OS.get_environment("CHR2_YAW")) if OS.get_environment("CHR2_YAW") != "" else 40.0)
	get_tree().quit()


func _vp(grid: Control, size: Vector2i) -> SubViewport:
	var box := SubViewportContainer.new()
	box.custom_minimum_size = size
	box.stretch = true
	grid.add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = size
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.72, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.82, 0.8, 0.88)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	vp.add_child(sun)
	return vp


func _label(vp: SubViewport, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	vp.get_parent().add_child(l)


## Une case : le héros (réglage « Héros détaillé » [param detail]) vu de [param yaw], animation [param anim] à [param t] s.
func _cell(grid: Control, detail: bool, label: String, yaw: float, dist: float, y: float, anim := "stand01", t := 0.3) -> Node3D:
	Settings.data["display"] = Settings.data.get("display", {})
	Settings.data.display["hero_detail"] = detail
	var vp := _vp(grid, CELL)
	var cam := Camera3D.new()
	cam.fov = 32.0
	var a := deg_to_rad(yaw)
	cam.position = Vector3(sin(a) * dist, y + 0.15, cos(a) * dist)
	vp.add_child(cam)
	cam.look_at(Vector3(0, y, 0))
	var model := EdenModel.instantiate_hero(GameData.class_data("whirl_ninja"))
	model.scale = Vector3.ONE * GameData.HERO_SCALE
	vp.add_child(model)
	var ap := EdenModel.find_anim_player(model)
	var real := ClassPremium.remapped(model, anim)
	var name := real if real != "" else anim
	if ap and ap.has_animation(name):
		ap.play(name)
		ap.seek(t, true)
		ap.pause()
	_label(vp, label)
	return model


func _grid(cols := 4) -> GridContainer:
	var layer := CanvasLayer.new()
	add_child(layer)
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 0)
	g.add_theme_constant_override("v_separation", 0)
	layer.add_child(g)
	return g


func _shot(name: String, wait := 1.5) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("[shot_chr2] ", path)


func _look_plate() -> void:
	for detail in [false, true]:
		var g := _grid()
		var tag := "détaillé" if detail else "CHR-1"
		_cell(g, detail, "Trois quarts (%s)" % tag, 35.0, 4.2, 1.0, "stand01", 0.3)
		_cell(g, detail, "Dos (%s)" % tag, 160.0, 4.2, 1.0, "stand01", 0.3)
		_cell(g, detail, "Visage (%s)" % tag, 0.0, 1.45, 1.55, "stand01", 0.3)
		_cell(g, detail, "Visage, profil (%s)" % tag, 70.0, 1.6, 1.55, "stand01", 0.3)
		_cell(g, detail, "Garde (%s)" % tag, 30.0, 4.2, 1.0, "battle10", 0.6)
		_cell(g, detail, "Course (%s)" % tag, 70.0, 4.2, 1.0, "move02", 0.3)
		_cell(g, detail, "Coup de pied (%s)" % tag, 20.0, 4.2, 1.0, "attack20", 0.32)
		_cell(g, detail, "Signe (%s)" % tag, 20.0, 4.2, 1.0, "magic01", 0.3)
		await _shot("chr2_look_%s" % ("apres" if detail else "avant"))
		g.get_parent().queue_free()
		await get_tree().process_frame


## Une planche par animation neuve : rangée du haut = celle d'Eden (avec la pose procédurale de CHR-1 absente ici),
## rangée du bas = la neuve, 8 instants chacune, même caméra.
func _anim_plates() -> void:
	var lib := load("res://assets/player/anims/chr2_ninja.res") as AnimationLibrary
	var spec := ClassPremium.spec(GameData.class_data("whirl_ninja"))
	var inv := {}
	for k in spec.remap:
		inv[String(spec.remap[k])] = "battle10" if k == "battle" else String(k)
	for n in lib.get_animation_list():
		var g := _grid(8)
		var length := lib.get_animation(n).length
		for row in 2:
			var eden := String(inv.get(String(n), ""))
			for i in 8:
				var t := length * i / 7.0
				var size := Vector2i(200, 225)
				var vp := _vp(g, size)
				var cam := Camera3D.new()
				cam.fov = 32.0
				var yaw := deg_to_rad(35.0 if not String(n).contains("run") else 75.0)
				cam.position = Vector3(sin(yaw) * 4.6, 1.15, cos(yaw) * 4.6)
				vp.add_child(cam)
				cam.look_at(Vector3(0, 1.0, 0))
				Settings.data["display"] = Settings.data.get("display", {})
				Settings.data.display["hero_detail"] = row == 1
				var model := EdenModel.instantiate_hero(GameData.class_data("whirl_ninja"))
				model.scale = Vector3.ONE * GameData.HERO_SCALE
				vp.add_child(model)
				var ap := EdenModel.find_anim_player(model)
				var name := ("chr2/" + String(n)) if row == 1 else eden
				if ap and name != "" and ap.has_animation(name):
					var tt := t if row == 1 else t * ap.get_animation(name).length / length
					ap.play(name)
					ap.seek(tt, true)
					ap.pause()
				if i == 0:
					_label(vp, ("%s" % n) if row == 1 else ("Eden : %s" % (eden if eden != "" else "-")))
		await _shot("chr2_anim_%s" % n, 1.0)
		g.get_parent().queue_free()
		await get_tree().process_frame


## Suite d'images (GIF) : le héros détaillé joue [param anim] en temps réel, ressorts actifs, 30 images/s.
func _seq(anim: String, yaw: float) -> void:
	var g := _grid(1)
	Settings.data["display"] = Settings.data.get("display", {})
	Settings.data.display["hero_detail"] = OS.get_environment("CHR2_DETAIL") != "0"
	var vp := _vp(g, Vector2i(480, 540))
	var cam := Camera3D.new()
	cam.fov = 32.0
	var a := deg_to_rad(yaw)
	cam.position = Vector3(sin(a) * 4.6, 1.15, cos(a) * 4.6)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))
	var model := EdenModel.instantiate_hero(GameData.class_data("whirl_ninja"))
	model.scale = Vector3.ONE * GameData.HERO_SCALE
	vp.add_child(model)
	var ap := EdenModel.find_anim_player(model)
	var name := anim if ap.has_animation(anim) else "chr2/" + anim
	Engine.max_fps = 30
	ap.play(name)
	var dir := "%s/seq_%s" % [_out, anim.replace("/", "_")]
	DirAccess.make_dir_recursive_absolute(dir)
	var n := int(ceil(ap.get_animation(name).length * 30.0)) * 2
	for i in n:
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("%s/%03d.png" % [dir, i])
	print("[shot_chr2] ", dir, " ", n)
