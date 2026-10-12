class_name Vfx
extends RefCounted
## Effets visuels simples et lisibles : arcs de lame, ondes, étincelles d'impact.


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	return m


## Arc horizontal (portée [param radius], ouverture [param arc] en degrés) devant [param fwd].
static func slash(parent: Node, pos: Vector3, fwd: Vector3, radius: float, arc: float, color := Color(1.0, 0.85, 0.6, 0.9)) -> void:
	var mesh := ImmediateMesh.new()
	var segs := 24
	var half := deg_to_rad(minf(arc, 359.0)) * 0.5
	var base_ang := atan2(fwd.x, fwd.z)
	var inner := radius * 0.78
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var a := base_ang - half + 2.0 * half * i / segs
		var dir := Vector3(sin(a), 0, cos(a))
		var t := float(i) / segs
		var fade := sin(t * PI)
		mesh.surface_set_color(Color(color.r, color.g, color.b, 0.0))
		mesh.surface_add_vertex(dir * inner)
		mesh.surface_set_color(Color(color.r, color.g, color.b, color.a * fade))
		mesh.surface_add_vertex(dir * radius)
	mesh.surface_end()
	_spawn(parent, mesh, pos + Vector3.UP * 0.9, Color(color, color.a * 0.6), 0.2, 1.1)


## Onde circulaire au sol (tourbillons, buffs).
static func ring(parent: Node, pos: Vector3, radius: float, color := Color(1.0, 0.75, 0.3, 0.8)) -> void:
	var mesh := ImmediateMesh.new()
	var segs := 40
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var a := TAU * i / segs
		var dir := Vector3(sin(a), 0, cos(a))
		mesh.surface_set_color(Color(color.r, color.g, color.b, 0.0))
		mesh.surface_add_vertex(dir * radius * 0.7)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(dir * radius)
	mesh.surface_end()
	_spawn(parent, mesh, pos + Vector3.UP * 0.15, color, 0.35, 1.25)


static func _spawn(parent: Node, mesh: Mesh, pos: Vector3, color: Color, life: float, grow: float) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.get_tree().current_scene.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * grow, life)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)


## Petite gerbe d'étincelles à l'impact.
static func spark(parent: Node, pos: Vector3, color := Color(1.0, 0.9, 0.6), crit := false) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 14 if crit else 8
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0 if crit else 5.0
	p.gravity = Vector3(0, -12, 0)
	# taille portée par le quad (certains rendus ignorent scale_amount)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var m := _material(color)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = m
	p.mesh = quad
	parent.get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(0.6).timeout.connect(p.queue_free)


## Éclair en zigzag de [param from] à [param to] (foudre des procs).
static func bolt(parent: Node, from: Vector3, to: Vector3, color := Color(0.75, 0.8, 1.0, 1.0)) -> void:
	var mesh := ImmediateMesh.new()
	var segs := 9
	var dir := to - from
	var side := dir.cross(Vector3.UP).normalized() if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var t := float(i) / segs
		var jitter := Vector3.ZERO if i == 0 or i == segs else (side * randf_range(-0.5, 0.5) + Vector3.UP * randf_range(-0.3, 0.3))
		var p := dir * t + jitter
		var w := 0.12 * (1.0 - t * 0.5)
		mesh.surface_set_color(color)
		mesh.surface_add_vertex(p - side * w)
		mesh.surface_add_vertex(p + side * w)
	mesh.surface_end()
	_spawn(parent, mesh, from, color, 0.22, 1.0)
