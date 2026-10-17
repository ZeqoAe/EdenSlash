class_name BossPortrait
extends Control
## Médaillon d'un boss (lot DNG-2, backlog BM-DNG P0-1 / P0-8 / P0-9) : le rendu de son modèle d'Eden sur des rayons de soleil,
## dans un cadre autocollant (contour d'encre, ombre dure). Le rendu est fait une fois par modèle, dans une SubViewport hors
## de l'écran, puis gardé ([member _cache]) ; sans rendu (serveur sans écran, tests) ou en attendant, l'initiale du boss en
## Mochiy sur la couleur [member tone]. Rond (barre de boss) ou carré arrondi (listes, fiches).
##   BossPortrait.for_boss(id, 64)  (boss de la bibliothèque) · BossPortrait.for_monster(données, 64, "Latif")  (boss de zone)

const RENDER_PX := 192
static var _cache := {}  # modèle -> Texture2D
static var _waiting := {}  # modèle -> [BossPortrait] qui attendent son rendu
static var _mask_shader: Shader

var tone := "amethyste"
var circle := true
var letter := ""
var model_key := ""
var dim := false  # boss à découvrir : silhouette grise
var _tex: TextureRect
var _letter: Label
var _front: Control


static func for_boss(bid: String, px: float, p_round := false) -> BossPortrait:
	var def := BossLibrary.get_def(bid)
	var data: Dictionary = GameData.monster(int(def.get("monster", 0))) if not def.is_empty() else {}
	var fam := BossLibrary.families_of(bid)
	var p := for_monster(data, px, BossLibrary.short_name(bid), p_round)
	p.tone = BossBar.family_tone(String(fam[0])) if not fam.is_empty() else "amethyste"
	return p


static func for_monster(data: Dictionary, px: float, p_name: String, p_round := true) -> BossPortrait:
	var p := BossPortrait.new()
	p.circle = p_round
	p.custom_minimum_size = Vector2(px, px)
	p.letter = p_name.strip_edges().left(1).to_upper()
	p.model_key = String(data.get("model", ""))
	p.set_meta("tex_name", String(data.get("texture", "")))
	return p


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex = TextureRect.new()
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset := 4.0
	_tex.offset_left = inset
	_tex.offset_top = inset
	_tex.offset_right = -inset - 3.0
	_tex.offset_bottom = -inset - 3.0
	_tex.material = _mask_material()
	(_tex.material as ShaderMaterial).set_shader_parameter("round_mask", circle)
	add_child(_tex)
	_letter = Label.new()
	UiTheme.title(_letter, int(clampf(size.y * 0.42, 16.0, 40.0)) if size.y > 0 else 22, Color.WHITE)
	_letter.set_anchors_preset(Control.PRESET_FULL_RECT)
	_letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_letter.offset_bottom = -3.0
	_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letter.text = letter if not dim else "?"
	add_child(_letter)
	_front = Control.new()
	_front.set_anchors_preset(Control.PRESET_FULL_RECT)
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.draw.connect(_draw_front)
	add_child(_front)
	resized.connect(func():
		_letter.add_theme_font_size_override("font_size", int(clampf(size.y * 0.42, 16.0, 40.0)))
		queue_redraw()
		_front.queue_redraw())
	_request()


## Le médaillon d'un autre boss (barre de boss : le boss change).
func set_boss(data: Dictionary, p_name: String, p_tone: String) -> void:
	tone = p_tone
	letter = p_name.strip_edges().left(1).to_upper()
	var key := String(data.get("model", ""))
	set_meta("tex_name", String(data.get("texture", "")))
	if _letter != null:
		_letter.text = letter
	if key != model_key:
		model_key = key
		if _tex != null:
			_tex.texture = null
			_request()
	queue_redraw()


func _request() -> void:
	if dim or model_key == "" or _tex == null:
		_show(null)
		return
	if _cache.has(model_key):
		_show(_cache[model_key])
		return
	_show(null)
	if not can_render() or not is_inside_tree():
		return
	if _waiting.has(model_key):
		(_waiting[model_key] as Array).append(self)
		return
	_waiting[model_key] = [self]
	_queue.append([model_key, String(get_meta("tex_name", ""))])
	_pump(get_tree())


func _show(t: Texture2D) -> void:
	_tex.texture = t
	_tex.visible = t != null
	_letter.visible = t == null


## Peut-on rendre un modèle 3D ici ? (pas sur un serveur sans écran : le médaillon garde l'initiale)
static func can_render() -> bool:
	return DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() != "dummy"


static var _queue: Array = []  # [[modèle, texture]] à rendre, un à la fois (une liste de 48 boss ne fige pas l'écran)
static var _busy := false


static func _pump(tree: SceneTree) -> void:
	if _busy or _queue.is_empty() or tree == null:
		return
	_busy = true
	var job: Array = _queue.pop_front()
	var t: Texture2D = await _render(tree, String(job[0]), String(job[1]))
	_cache[String(job[0])] = t
	for p in _waiting.get(String(job[0]), []):
		if is_instance_valid(p) and p.model_key == String(job[0]):
			p._show(t)
	_waiting.erase(String(job[0]))
	_busy = false
	_pump(tree)


## Rendu du modèle [param key] (assets/monsters/<key>/<key>.glb) dans une SubViewport posée hors de l'écran, puis copie de l'image.
static func _render(tree: SceneTree, key: String, tex_name: String) -> Texture2D:
	var glb := "res://assets/monsters/%s/%s.glb" % [key, key]
	if not ResourceLoader.exists(glb):
		return null
	var tex_path := "res://assets/monsters/textures/%s.png" % tex_name
	var vp := SubViewport.new()
	vp.size = Vector2i(RENDER_PX, RENDER_PX)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.92, 0.9, 0.96)
	env.environment.ambient_light_energy = 0.9
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 25, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var model := EdenModel.instantiate(glb, tex_path if ResourceLoader.exists(tex_path) else "")
	if model == null:
		vp.queue_free()
		return null
	vp.add_child(model)
	var ap := EdenModel.find_anim_player(model)
	if ap != null:
		for a in ["stand01", "battle01"]:
			if ap.has_animation(a):
				ap.play(a)
				ap.seek(0.4, true)
				ap.pause()
				break
	var box := EdenModel.bounds(model)
	var h := maxf(box.size.y, 0.5)
	var w := maxf(maxf(box.size.x, box.size.z), 0.5)
	# cadrage du buste : le haut du modèle, de trois quarts face
	var focus := box.position + Vector3(box.size.x * 0.5, box.size.y * 0.62, box.size.z * 0.5)
	var cam := Camera3D.new()
	cam.fov = 30.0
	var dist := maxf(h * 0.8, w * 0.9) / tan(deg_to_rad(cam.fov * 0.5)) * 0.5
	cam.position = focus + Vector3(0.35, 0.12, 1.0).normalized() * dist
	vp.add_child(cam)
	cam.look_at(focus)
	cam.current = true
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image() if is_instance_valid(vp) else null
	if is_instance_valid(vp):
		vp.queue_free()
	return ImageTexture.create_from_image(img) if img != null and not img.is_empty() else null


static func _mask_material() -> ShaderMaterial:
	if _mask_shader == null:
		_mask_shader = Shader.new()
		_mask_shader.code = "shader_type canvas_item;\nuniform bool round_mask = true;\nuniform float radius = 0.2;\n" \
			+ "void fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat a = 1.0;\n" \
			+ "\tif (round_mask) { a = smoothstep(0.5, 0.47, distance(UV, vec2(0.5))); }\n" \
			+ "\telse { vec2 q = abs(UV - 0.5) - (0.5 - radius); a = smoothstep(radius, radius - 0.03, length(max(q, 0.0))); }\n" \
			+ "\tCOLOR = vec4(c.rgb, c.a * a);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = _mask_shader
	return m


## Fond : ombre dure, aplat en deux tons, rayons de soleil (comme le fond des icônes du jeu).
func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var s := size - Vector2(3, 3)
	var ink := UiTheme.color("encre.700")
	var t := UiTheme.tones("gris" if dim else tone)
	if circle:
		var c := s * 0.5
		var r := minf(s.x, s.y) * 0.5
		draw_circle(c + Vector2(3, 3), r, ink)
		draw_circle(c, r, t[1])
		draw_circle(c + Vector2(0, r * 0.25), r * 0.75, Color(t[2], 0.55))
		if not dim:
			for k in 8:
				var a := TAU * k / 8.0 + 0.2
				var pts := PackedVector2Array([c, c + Vector2(cos(a - 0.12), sin(a - 0.12)) * r * 0.95, c + Vector2(cos(a + 0.12), sin(a + 0.12)) * r * 0.95])
				draw_colored_polygon(pts, Color(1, 1, 1, 0.18))
	else:
		var rad := minf(s.x, s.y) * 0.2
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(rad))
		sb.anti_aliasing = true
		sb.bg_color = ink
		draw_style_box(sb, Rect2(Vector2(3, 3), s))
		sb.bg_color = t[1]
		draw_style_box(sb, Rect2(Vector2.ZERO, s))
		var low := sb.duplicate() as StyleBoxFlat
		low.bg_color = Color(t[2], 0.5)
		low.corner_radius_top_left = 0
		low.corner_radius_top_right = 0
		draw_style_box(low, Rect2(Vector2(0, s.y * 0.62), Vector2(s.x, s.y * 0.38)))
		if not dim:
			var c := s * 0.5
			for k in 8:
				var a := TAU * k / 8.0 + 0.2
				var pts := PackedVector2Array([c, c + Vector2(cos(a - 0.12), sin(a - 0.12)) * s.x * 0.62, c + Vector2(cos(a + 0.12), sin(a + 0.12)) * s.x * 0.62])
				draw_colored_polygon(pts, Color(1, 1, 1, 0.16))
		if dim:
			UiTheme._ensure_textures()
			if UiTheme._dots != null:
				draw_texture_rect(UiTheme._dots, Rect2(Vector2(6, 6), s - Vector2(12, 12)), true, Color(ink, 0.5))


## Devant : le contour d'encre (par-dessus le rendu).
func _draw_front() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var s := size - Vector2(3, 3)
	var ink := UiTheme.color("encre.700") if not dim else UiTheme.color("encre.300")
	if circle:
		_front.draw_arc(s * 0.5, minf(s.x, s.y) * 0.5 - 1.5, 0.0, TAU, 64, ink, 3.0, true)
		_front.draw_arc(s * 0.5 + Vector2(-0.5, -0.5), minf(s.x, s.y) * 0.5 - 5.0, PI * 1.1, PI * 1.45, 12, Color(1, 1, 1, 0.75), 2.0, true)
	else:
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_corner_radius_all(int(minf(s.x, s.y) * 0.2))
		sb.set_border_width_all(3)
		sb.border_color = ink
		sb.anti_aliasing = true
		_front.draw_style_box(sb, Rect2(Vector2.ZERO, s))
