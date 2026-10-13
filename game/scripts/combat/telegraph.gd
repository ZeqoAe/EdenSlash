class_name Telegraph
extends Node3D
## Zone rouge au sol qui annonce une attaque : le contour apparaît, l'intérieur
## se remplit pendant [member delay], puis les dégâts tombent sur le héros s'il
## est encore dedans (l'esquive rend invulnérable).
##   shape : "circle" (rayon), "ring" (rayon intérieur / extérieur),
##           "line" (longueur, largeur), "cone" (rayon, angle)

signal resolved(hit: bool)

const COLOR := Color(1.0, 0.12, 0.08)
const PLAYER_COLOR := Color(0.25, 0.6, 1.0)  # zone des attaques du héros (option)

var shape := "circle"
var radius := 4.0
var inner := 0.0  # ring
var length := 12.0  # line
var width := 3.0  # line
var angle := 90.0  # cone (degrés)
var delay := 1.2
var damage := 100.0
var source: Combatant
var stun_time := 0.0  # étourdit le héros touché
var jumpable := false  # onde au sol : évitée si le héros est en l'air
var small := false  # attaque de monstre ordinaire : annonce plus discrète
var color := COLOR

var _t := 0.0
var _fill: MeshInstance3D


static func spawn(parent: Node, pos: Vector3, yaw: float, props: Dictionary) -> Telegraph:
	var t := Telegraph.new()
	for k in props:
		t.set(k, props[k])
	parent.get_tree().current_scene.add_child(t)
	t.global_position = pos + Vector3.UP * 0.12
	t.rotation.y = yaw
	return t


func _ready() -> void:
	var outline := MeshInstance3D.new()
	outline.mesh = _shape_mesh(1.0)
	outline.material_override = _mat(0.18 if small else 0.28)
	if jumpable:
		# bord jaune : on peut l'éviter en sautant
		var edge := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.25
		torus.outer_radius = radius
		edge.mesh = torus
		edge.scale = Vector3(1, 0.05, 1)
		var em := _mat(0.9)
		em.albedo_color = Color(1.0, 0.85, 0.2, 0.9)
		edge.material_override = em
		add_child(edge)
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outline)
	_fill = MeshInstance3D.new()
	_fill.mesh = outline.mesh
	_fill.material_override = _mat(0.45)
	_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fill.scale = Vector3(0.01, 1, 0.01) if shape != "line" else Vector3(1, 1, 0.01)
	add_child(_fill)


func _mat(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = Color(color, alpha)
	m.render_priority = 1
	return m


## Maillage plat de la forme (repère local : avant = +Z).
func _shape_mesh(k: float) -> Mesh:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	match shape:
		"line":
			var w := width * 0.5
			var pts := [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(w, 0, length * k), Vector3(-w, 0, length * k)]
			for i in [0, 1, 2, 0, 2, 3]:
				im.surface_add_vertex(pts[i])
		"cone":
			var half := deg_to_rad(angle) * 0.5
			var segs := 24
			for i in segs:
				var a0 := -half + 2.0 * half * i / segs
				var a1 := -half + 2.0 * half * (i + 1) / segs
				im.surface_add_vertex(Vector3.ZERO)
				im.surface_add_vertex(Vector3(sin(a0), 0, cos(a0)) * radius * k)
				im.surface_add_vertex(Vector3(sin(a1), 0, cos(a1)) * radius * k)
		_:
			var segs := 40
			var r0 := inner * k if shape == "ring" else 0.0
			for i in segs:
				var a0 := TAU * i / segs
				var a1 := TAU * (i + 1) / segs
				var d0 := Vector3(sin(a0), 0, cos(a0))
				var d1 := Vector3(sin(a1), 0, cos(a1))
				im.surface_add_vertex(d0 * r0)
				im.surface_add_vertex(d0 * radius * k)
				im.surface_add_vertex(d1 * radius * k)
				im.surface_add_vertex(d0 * r0)
				im.surface_add_vertex(d1 * radius * k)
				im.surface_add_vertex(d1 * r0)
	im.surface_end()
	return im


func _process(delta: float) -> void:
	_t += delta
	var p := clampf(_t / delay, 0.0, 1.0)
	if shape == "line":
		_fill.scale = Vector3(1, 1, maxf(p, 0.01))
	else:
		_fill.scale = Vector3(maxf(p, 0.01), 1, maxf(p, 0.01))
	if _t >= delay:
		_resolve()


func _resolve() -> void:
	set_process(false)
	var hit := false
	var player := get_tree().get_first_node_in_group("player") as Player
	if damage > 0.0 and player and not player.is_dead and contains(player.global_position, player.radius):
		var dodged_by_jump := jumpable and player.is_airborne() and player.global_position.y > global_position.y + 0.4
		if dodged_by_jump:
			player.ml_counts.dodged += 1
			DamageNumber.spawn_text(player, "SAUT !", Color(0.6, 0.9, 1.0))
		elif player.is_invulnerable():
			player.ml_counts.dodged += 1
			DamageNumber.spawn_text(player, "ESQUIVE !", Color(0.7, 1.0, 0.7))
		else:
			player.take_damage(damage, source, false)
			if stun_time > 0.0:
				player.stun(stun_time)
			hit = true
	resolved.emit(hit)
	# éclat final puis disparition
	var flash := MeshInstance3D.new()
	flash.mesh = _shape_mesh(1.0)
	flash.material_override = _mat(0.85)
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash.material_override, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


## Le point (monde) est-il dans la zone ?
func contains(p: Vector3, margin := 0.0) -> bool:
	var local := global_transform.affine_inverse() * p
	var flat := Vector2(local.x, local.z)
	match shape:
		"line":
			return absf(local.x) <= width * 0.5 + margin and local.z >= -margin and local.z <= length + margin
		"cone":
			if flat.length() > radius + margin:
				return false
			return rad_to_deg(absf(atan2(local.x, local.z))) <= angle * 0.5 or flat.length() < 1.0
		"ring":
			return flat.length() <= radius + margin and flat.length() >= inner - margin
		_:
			return flat.length() <= radius + margin
