class_name EdenFx
extends Node3D
## Lecture d'un effet visuel d'Eden converti par tools/fx2godot.py :
## maillages (.glb) + pistes animées (.fx.json) : transformations, visibilité,
## transparence, couleur, défilement / échelle d'UV, planches de texture.

static var _cache := {}  # nom -> [PackedScene, Dictionary]
## Intensité des effets : les effets d'Eden, pensés pour un MMO, sont renforcés
## (opacité et luminosité) pour des impacts bien marqués ; shaders/eden_fx.gdshader
## les fait briller (lueur) sans virer au blanc et les fond au contact du sol.
const ALPHA_BOOST := 1.5
const GLOW_BOOST := 1.0
const SHADER := preload("res://shaders/eden_fx.gdshader")
static var _tex_cache := {}

var fx_name := ""
var follow: Node3D  # l'effet suit ce nœud (effets d'incantation)
var loop := false  # aura : rejoue l'effet en boucle au lieu de disparaître
var alpha_mul := 1.0  # opacité globale (auras plus discrètes que les sorts)
var on_dark := false  # aura sur fond sombre (aperçus) : lueur additive classique
var _data: Dictionary
var _t := 0.0
var _nodes := {}  # nom -> Node3D
var _mats := {}  # nom -> [ShaderMaterial ou StandardMaterial3D, info]
## Moteur de compatibilité (OpenGL) : matériaux standard (le shader n'y est pas fiable).
static var _legacy := -1
var _offset := Transform3D.IDENTITY


## Joue l'effet [param name] à [param pos], orienté selon [param yaw].
static func play(parent: Node, name: String, pos: Vector3, yaw := 0.0, scale_ := 1.0, p_follow: Node3D = null) -> EdenFx:
	if name == "" or parent == null or not parent.is_inside_tree():
		return null
	if not _load(name):
		return null
	var fx := EdenFx.new()
	fx.fx_name = name
	fx.follow = p_follow
	parent.get_tree().current_scene.add_child(fx)
	fx.global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale_), pos)
	if p_follow:
		fx._offset = p_follow.global_transform.affine_inverse() * fx.global_transform
	return fx


## Effet en boucle attaché à [param parent] (aura autour du héros : pierres étoilées,
## pierres de lune), à l'échelle [param scale_].
static func attach(parent: Node3D, name: String, scale_ := 1.0, dark := false) -> EdenFx:
	if name == "" or parent == null or not _load(name):
		return null
	var fx := EdenFx.new()
	fx.fx_name = name
	fx.loop = true
	fx.on_dark = dark
	fx.alpha_mul = AURA_ALPHA
	fx.scale = Vector3.ONE * scale_
	parent.add_child(fx)
	return fx


## Opacité des auras : effets d'Eden faits pour la ville, atténués pour garder le combat lisible.
const AURA_ALPHA := 0.75
const AURA_INTENSITY := 1.15
## Sorts : part de couleur pleine (0 : lueur seule, 1 : comme les auras) et vitesse de lecture
## (< 1 : l'effet reste plus longtemps à l'écran).
const SPELL_LUM_MIX := 0.55
const SPELL_TIME := 0.85


## Auras portées par la classe [param cls_id], attachées à [param parent].
## [param dark] : aperçu sur fond sombre (la lueur additive y reste lisible).
static func attach_auras(parent: Node3D, cls_id: String, scale_ := 1.0, dark := false) -> void:
	for x in Profile.worn_auras(cls_id):
		var fx := attach(parent, String(x.aura.fx), scale_, dark)
		if fx:
			fx.add_to_group("hero_auras")


static func _load(name: String) -> bool:
	if _cache.has(name):
		return _cache[name] != null
	var js := "res://assets/fx/%s.fx.json" % name
	if not FileAccess.file_exists(js):
		_cache[name] = null
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(js))
	# variante de couleur : maillage d'un autre effet ("glb"), textures propres ("tex")
	var glb := "res://assets/fx/%s.glb" % (String(data.get("glb", name)) if data is Dictionary else name)
	if not ResourceLoader.exists(glb):
		_cache[name] = null
		return false
	var scene := load(glb) as PackedScene
	if scene == null or typeof(data) != TYPE_DICTIONARY:
		_cache[name] = null  # effet vide ou illisible : ignoré
		return false
	_cache[name] = [scene, data]
	return true


func _ready() -> void:
	var entry: Array = _cache[fx_name]
	_data = entry[1]
	var root: Node3D = (entry[0] as PackedScene).instantiate()
	add_child(root)
	for n: Node in root.find_children("*", "Node3D", true, false):
		_nodes[String(n.name)] = n
	var mats: Dictionary = _data.get("materials", {})
	for name in mats:
		var mi := _nodes.get(name) as MeshInstance3D
		if mi == null:
			continue
		var info: Dictionary = mats[name]
		if info.get("hide", false):
			# quad à bords durs (voir tools/fx2godot.py) : jamais affiché
			mi.queue_free()
			_nodes.erase(name)
			continue
		var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if _legacy < 0:
			_legacy = 1 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 0
		if _legacy == 1:
			_mats[name] = [_legacy_material(src, info), info]
			(_mats[name][0] as StandardMaterial3D).albedo_color.a *= alpha_mul
			mi.material_override = _mats[name][0]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if info.has("tex"):
				_set_tex(_mats[name][0], _texture("res://assets/fx/" + String(info.tex)))
			continue
		var m := ShaderMaterial.new()
		m.shader = SHADER
		var add: bool = info.get("blend", "mix") == "add"
		m.set_shader_parameter("additive", 1.0 if add else 0.0)
		m.set_shader_parameter("use_vertex_color", 1.0 if bool(info.get("vcol", true)) else 0.0)
		if loop:
			# auras : sur un décor clair, une lueur purement additive vire au voile blanc ; on
			# assombrit le fond sous les seules parties vives (courbe forte : pas de rectangles
			# sombres derrière les grands plans) et on garde les couleurs saturées
			m.set_shader_parameter("darken", 0.0)
			if not on_dark:
				# décor clair (accueil, run) : couleur pleine posée selon la luminosité, sinon la
				# lueur additive vire au voile blanc
				m.set_shader_parameter("lum_mix", 1.0)
				m.set_shader_parameter("intensity", AURA_INTENSITY)
				m.set_shader_parameter("saturation", 1.4)
		else:
			# sorts et impacts : à moitié en couleur pleine, plus d'impact sur un sol clair
			m.set_shader_parameter("lum_mix", SPELL_LUM_MIX)
		if info.has("tex"):
			m.set_shader_parameter("tex", _texture("res://assets/fx/" + String(info.tex)))
		elif src:
			m.set_shader_parameter("tex", src.albedo_texture)
		var c: Array = info.get("color", [1, 1, 1])
		var k := GLOW_BOOST if add else 1.0
		m.set_shader_parameter("color", Color(c[0] * k, c[1] * k, c[2] * k, minf(1.0, float(info.get("alpha", 1.0)) * ALPHA_BOOST) * alpha_mul))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mats[name] = [m, info]
	_apply(0)


func _process(delta: float) -> void:
	_t += delta * (1.0 if loop else SPELL_TIME)
	var dur := float(_data.get("duration", 1.0))
	if _t >= dur:
		if not loop:
			queue_free()
			return
		_t = fmod(_t, maxf(dur, 0.01))
	if follow and is_instance_valid(follow):
		global_transform = follow.global_transform * _offset
	_apply(int(_t * float(_data.get("fps", 30.0))))


func _apply(i: int) -> void:
	var nodes: Dictionary = _data.get("nodes", {})
	for name in nodes:
		var n := _nodes.get(name) as Node3D
		if n == null:
			continue
		var tr: Dictionary = nodes[name]
		if tr.has("t"):
			var v: Array = tr.t[mini(i, tr.t.size() - 1)]
			n.position = Vector3(v[0], v[1], v[2])
		if tr.has("r"):
			var q: Array = tr.r[mini(i, tr.r.size() - 1)]
			n.quaternion = Quaternion(q[0], q[1], q[2], q[3]).normalized()
		if tr.has("s"):
			var s := float(tr.s[mini(i, tr.s.size() - 1)])
			n.scale = Vector3.ONE * maxf(s, 0.0001)
		if tr.has("vis"):
			n.visible = float(tr.vis[mini(i, tr.vis.size() - 1)]) > 0.5
	for name in _mats:
		var m: Material = _mats[name][0]
		var info: Dictionary = _mats[name][1]
		var col := _get_color(m)
		if info.has("alpha_t"):
			col.a = minf(1.0, float(info.alpha_t[mini(i, info.alpha_t.size() - 1)]) * ALPHA_BOOST) * alpha_mul
		if info.has("color_t"):
			var c: Array = info.color_t[mini(i, info.color_t.size() - 1)]
			var k := (GLOW_BOOST if _legacy == 0 else 1.3) if info.get("blend", "mix") == "add" else 1.0
			col = Color(c[0] * k, c[1] * k, c[2] * k, col.a)
		if info.has("alpha_t") or info.has("color_t"):
			_set_color(m, col)
		var su := float(_track(info, "uv_su", i, 1.0))
		var sv := float(_track(info, "uv_sv", i, 1.0))
		var u := float(_track(info, "uv_u", i, 0.0))
		var v := float(_track(info, "uv_v", i, 0.0))
		if info.has("uv_su") or info.has("uv_sv") or info.has("uv_u") or info.has("uv_v"):
			# échelle autour du centre de la texture, comme Gamebryo
			_set_uv(m, Vector2(su, sv), Vector2(0.5 * (1.0 - su) + u, 0.5 * (1.0 - sv) + v))
		if info.has("flip"):
			var f: Dictionary = info.flip
			var uri: String = f.textures[int(f.frames[mini(i, f.frames.size() - 1)])]
			_set_tex(m, _texture("res://assets/fx/" + uri))


static func _legacy_material(src: BaseMaterial3D, info: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if info.get("blend", "mix") == "add" else BaseMaterial3D.BLEND_MODE_MIX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = bool(info.get("vcol", true))
	if src:
		m.albedo_texture = src.albedo_texture
	var c: Array = info.get("color", [1, 1, 1])
	var k := 1.3 if info.get("blend", "mix") == "add" else 1.0
	m.albedo_color = Color(c[0] * k, c[1] * k, c[2] * k, minf(1.0, float(info.get("alpha", 1.0)) * ALPHA_BOOST))
	return m


## Paramètres animés, quel que soit le matériau (shader ou standard).
static func _set_color(m: Material, col: Color) -> void:
	if m is ShaderMaterial:
		m.set_shader_parameter("color", col)
	else:
		(m as StandardMaterial3D).albedo_color = col


static func _get_color(m: Material) -> Color:
	return m.get_shader_parameter("color") if m is ShaderMaterial else (m as StandardMaterial3D).albedo_color


static func _set_uv(m: Material, sc: Vector2, off: Vector2) -> void:
	if m is ShaderMaterial:
		m.set_shader_parameter("uv_scale", sc)
		m.set_shader_parameter("uv_offset", off)
	else:
		(m as StandardMaterial3D).uv1_scale = Vector3(sc.x, sc.y, 1.0)
		(m as StandardMaterial3D).uv1_offset = Vector3(off.x, off.y, 0.0)


static func _set_tex(m: Material, t: Texture2D) -> void:
	if m is ShaderMaterial:
		m.set_shader_parameter("tex", t)
	else:
		(m as StandardMaterial3D).albedo_texture = t


static func _track(info: Dictionary, key: String, i: int, default: float) -> float:
	if not info.has(key):
		return default
	var a: Array = info[key]
	return float(a[mini(i, a.size() - 1)])


static func _texture(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]
