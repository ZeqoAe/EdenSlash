class_name ChestStage
extends SubViewportContainer
## Coffre de récompense en 3D (page Coffres) : le coffre d'Eden posé sur un halo de la couleur
## de son type, qui tourne doucement. [method open] : il se tourne vers toi, tremble, s'ouvre
## (coffre d'Eden fermé uc020 remplacé par sa version ouverte uc020_1) et un éclat de
## lumière jaillit ; [signal burst] à ce moment (les récompenses peuvent apparaître).
## Fond transparent.

signal burst

const CLOSED := "res://assets/maps/objects/uc020.glb"
const OPEN := "res://assets/maps/objects/uc020_1.glb"
const HEIGHT := 1.0  # hauteur du coffre (m) dans la scène

var spin := true
var _vp: SubViewport
var _pivot: Node3D
var _closed: Node3D
var _open: Node3D
var _light: OmniLight3D
var _halo: MeshInstance3D
var _beam: MeshInstance3D
var _color := Color.WHITE
var _busy := false


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.7, 0.85)
	env.environment.ambient_light_energy = 0.5
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.glow_enabled = true
	env.environment.glow_intensity = 0.6
	env.environment.glow_bloom = 0.15
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_color = Color(1.0, 0.93, 0.84)
	sun.light_energy = 0.9
	_vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.transform = Transform3D(Basis(), Vector3(0, 1.35, 3.6)).looking_at(Vector3(0, 0.5, 0))
	_vp.add_child(cam)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	# lumière de la couleur du coffre, juste devant et au-dessus
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 1.1, 0.9)
	_light.omni_range = 4.0
	_light.light_energy = 0.7
	_vp.add_child(_light)
	# halo au sol (disque additif en dégradé)
	_halo = MeshInstance3D.new()
	var disc := PlaneMesh.new()
	disc.size = Vector2(2.6, 2.6)
	_halo.mesh = disc
	_halo.material_override = _glow_material(_radial_texture())
	_halo.position.y = 0.01
	_vp.add_child(_halo)
	# colonne de lumière à l'ouverture
	_beam = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.35
	cyl.height = 3.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	_beam.mesh = cyl
	_beam.material_override = _glow_material(_beam_texture())
	_beam.position.y = 1.5
	_beam.visible = false
	_vp.add_child(_beam)


## Coffre fermé de la couleur [param c] (type du coffre).
func show_chest(c: Color) -> void:
	_color = c
	_busy = false
	spin = true
	if _closed == null and ResourceLoader.exists(CLOSED):
		_closed = EdenModel.instantiate(CLOSED)
		_pivot.add_child(_closed)
		# même cadrage pour les deux versions (celui du coffre fermé)
		var box := EdenModel.bounds(_closed)
		var k := HEIGHT / maxf(box.size.y, 0.01)
		var off := Vector3(-box.get_center().x, -box.position.y, -box.get_center().z) * k
		_closed.scale = Vector3.ONE * k
		_closed.position = off
		if ResourceLoader.exists(OPEN):
			_open = EdenModel.instantiate(OPEN)
			_open.scale = Vector3.ONE * k
			_open.position = off
			_pivot.add_child(_open)
	if _closed:
		_closed.visible = true
	if _open:
		_open.visible = false
	_pivot.position = Vector3.ZERO
	_pivot.scale = Vector3.ONE
	_light.light_color = c.lightened(0.2)
	_light.light_energy = 0.7
	(_halo.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.4)
	(_beam.material_override as StandardMaterial3D).albedo_color = Color(c.r, c.g, c.b, 0.0)
	_beam.visible = false


## Ouverture : face à toi, tremblement, couvercle (animation d'Eden), éclat de lumière.
func open() -> void:
	if _busy:
		return
	_busy = true
	spin = false
	var tw := create_tween()
	var face := roundf(_pivot.rotation.y / TAU) * TAU
	tw.tween_property(_pivot, "rotation:y", face, 0.25).set_trans(Tween.TRANS_SINE)
	for i in 6:
		var a := 0.05 * (1.0 - i / 6.0) * (1 if i % 2 == 0 else -1)
		tw.tween_property(_pivot, "position:x", a, 0.04)
	tw.tween_property(_pivot, "position:x", 0.0, 0.04)
	tw.tween_property(_pivot, "scale", Vector3(1.08, 0.9, 1.08), 0.08)
	tw.tween_callback(func():
		if _open:
			_closed.visible = false
			_open.visible = true
		Sfx.ui("chest")
		_burst())
	tw.tween_property(_pivot, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _burst() -> void:
	burst.emit()
	_beam.visible = true
	_beam.scale = Vector3(0.4, 0.2, 0.4)
	var bm := _beam.material_override as StandardMaterial3D
	var tw := create_tween().set_parallel()
	tw.tween_property(_light, "light_energy", 4.0, 0.12)
	tw.tween_property(_beam, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bm, "albedo_color:a", 0.85, 0.15)
	tw.chain().tween_interval(0.25)
	tw.chain().set_parallel().tween_property(_light, "light_energy", 1.2, 0.9)
	tw.tween_property(bm, "albedo_color:a", 0.25, 0.9)


func _process(delta: float) -> void:
	if spin:
		_pivot.rotation.y += delta * 0.45
	# le halo respire doucement
	var t := Time.get_ticks_msec() / 1000.0
	_halo.scale = Vector3.ONE * (1.0 + 0.04 * sin(t * 2.2))


static func _glow_material(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_texture = tex
	return m


static var _radial: Texture2D
static var _vertical: Texture2D


static func _radial_texture() -> Texture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 128
		t.height = 128
		_radial = t
	return _radial


static func _beam_texture() -> Texture2D:
	if _vertical == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0))
		g.add_point(0.25, Color(1, 1, 1, 1))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill_from = Vector2(0, 1)
		t.fill_to = Vector2(0, 0)
		t.width = 8
		t.height = 64
		_vertical = t
	return _vertical
