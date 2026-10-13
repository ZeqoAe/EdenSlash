class_name Vfx
extends RefCounted
## Effets visuels simples et lisibles : arcs de lame, ondes, étincelles d'impact.

## Aucun effet visuel, son ni chiffre de dégâts (arène ML sans fenêtre : plus rapide).
static var silent := false


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
	if Vfx.silent:
		return
	var mesh := ImmediateMesh.new()
	var segs := 24
	var half := deg_to_rad(minf(arc, 359.0)) * 0.5
	var base_ang := atan2(fwd.x, fwd.z)
	var inner := radius * 0.5
	var hot := Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 1.0)
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var a := base_ang - half + 2.0 * half * i / segs
		var dir := Vector3(sin(a), 0, cos(a))
		var t := float(i) / segs
		var fade := sin(t * PI)
		mesh.surface_set_color(Color(hot.r, hot.g, hot.b, 0.0))
		mesh.surface_add_vertex(dir * inner)
		mesh.surface_set_color(Color(hot.r, hot.g, hot.b, fade))
		mesh.surface_add_vertex(dir * radius)
	mesh.surface_end()
	_spawn(parent, mesh, pos + Vector3.UP * 0.9, Color(1, 1, 1, 1.0), 0.28, 1.12)
	# cœur blanc fin et brillant au bord de la lame
	var core := ImmediateMesh.new()
	core.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var a := base_ang - half + 2.0 * half * i / segs
		var dir := Vector3(sin(a), 0, cos(a))
		var fade := sin(float(i) / segs * PI)
		core.surface_set_color(Color(1.8, 1.7, 1.4, 0.0))
		core.surface_add_vertex(dir * radius * 0.92)
		core.surface_set_color(Color(1.8, 1.7, 1.4, fade))
		core.surface_add_vertex(dir * radius)
	core.surface_end()
	_spawn(parent, core, pos + Vector3.UP * 0.92, Color(1, 1, 1, 1.0), 0.16, 1.08)


## Onde circulaire au sol (tourbillons, buffs).
static func ring(parent: Node, pos: Vector3, radius: float, color := Color(1.0, 0.75, 0.3, 0.8)) -> void:
	if Vfx.silent:
		return
	var mesh := ImmediateMesh.new()
	var segs := 40
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in segs + 1:
		var a := TAU * i / segs
		var dir := Vector3(sin(a), 0, cos(a))
		mesh.surface_set_color(Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 0.0))
		mesh.surface_add_vertex(dir * radius * 0.78)
		mesh.surface_set_color(Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 1.0))
		mesh.surface_add_vertex(dir * radius)
	mesh.surface_end()
	_spawn(parent, mesh, pos + Vector3.UP * 0.15, Color(1, 1, 1, color.a), 0.4, 1.3)


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


## Onde de choc au sol : double anneau, gerbe de poussière et éclair de lumière.
static func shockwave(parent: Node, pos: Vector3, radius: float, color := Color(1.0, 0.8, 0.45)) -> void:
	if Vfx.silent:
		return
	if parent == null or not parent.is_inside_tree():
		return
	ring(parent, pos, radius, Color(color, 1.0))
	ring(parent, pos, radius * 0.6, Color(1.0, 0.95, 0.8, 0.7))
	parent.get_tree().create_timer(0.08).timeout.connect(func(): ring(parent, pos, radius * 1.35, Color(color, 0.7)))
	flash(parent, pos + Vector3.UP * 0.6, radius * 0.6, color)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 36
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3(0, 0.25, 0)
	p.spread = 180.0
	p.flatness = 0.85
	p.initial_velocity_min = radius * 2.0
	p.initial_velocity_max = radius * 3.2
	p.damping_min = radius * 3.0
	p.damping_max = radius * 4.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 2.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.45)
	var m := _material(Color(0.85, 0.75, 0.6, 0.55))
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = false
	m.albedo_texture = _radial()
	quad.material = m
	p.mesh = quad
	parent.get_tree().current_scene.add_child(p)
	p.global_position = pos + Vector3.UP * 0.3
	p.emitting = true
	p.get_tree().create_timer(1.0).timeout.connect(p.queue_free)


## Éclair de lumière bref à l'impact (billboard qui grossit et s'efface).
static func flash(parent: Node, pos: Vector3, size: float, color := Color(1.0, 0.9, 0.6)) -> void:
	if Vfx.silent:
		return
	if parent == null or not parent.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := _material(Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, 0.7))
	m.vertex_color_use_as_albedo = false
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _radial()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.get_tree().current_scene.add_child(mi)
	mi.global_position = pos
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.8, 0.14)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.14)
	tw.chain().tween_callback(mi.queue_free)


static var _radial_tex: Texture2D


static func _radial() -> Texture2D:
	if _radial_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_radial_tex = t
	return _radial_tex


## Petite gerbe d'étincelles à l'impact.
static func spark(parent: Node, pos: Vector3, color := Color(1.0, 0.9, 0.6), crit := false) -> void:
	if Vfx.silent:
		return
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 22 if crit else 12
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
	quad.size = Vector2(0.16, 0.16)
	var m := _material(Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, 1.0))
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = false
	m.albedo_texture = _radial()
	quad.material = m
	p.mesh = quad
	parent.get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(0.6).timeout.connect(p.queue_free)


## Éclair en zigzag de [param from] à [param to] (foudre des procs).
static func bolt(parent: Node, from: Vector3, to: Vector3, color := Color(0.75, 0.8, 1.0, 1.0)) -> void:
	if Vfx.silent:
		return
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
