class_name SpawnMark
extends MeshInstance3D
## Croix d'apparition (lot SVX-1, Survivant ; idée de Brotato) : une croix mandarine contourée d'encre posée au sol à la
## place exacte où un monstre va surgir, mark_time s avant (SpawnDirector.mark_time). Mandarine = une arrivée ; la fraise
## reste aux attaques (télégraphes). Une seule maille et un seul matériau partagés : quelques dizaines de croix à la fois
## ne coûtent presque rien (opaques, sans ombre).

const INK := Color(0.133, 0.102, 0.227)  # encre-700 #221A3A
const FILL := Color(1.0, 0.541, 0.122)  # mandarine #FF8A1F
const ARM := 0.55  # demi-longueur d'une branche (m)
const WIDTH := 0.11  # demi-largeur d'une branche (m)
const EDGE := 0.06  # contour d'encre (m)

static var _mesh: ArrayMesh
static var made := 0  # croix posées depuis le lancement (tests)


## Croix au sol en [param pos] (déjà posé sur le relief) pendant [param t] s, enfant de [param parent].
static func mark(parent: Node, pos: Vector3, t: float) -> SpawnMark:
	if Vfx.silent or parent == null or not parent.is_inside_tree() or pos == Vector3.INF:
		return null
	var m := SpawnMark.new()
	made += 1
	m.mesh = cross_mesh()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = pos + Vector3.UP * 0.08
	m.scale = Vector3.ONE * 0.35
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE, minf(0.25, t * 0.4)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "scale", Vector3.ONE * 0.8, maxf(0.05, t - 0.25)).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(m.queue_free)
	return m


## Maille partagée : deux branches en X, chacune doublée d'un contour d'encre dessous.
static func cross_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in 2:
		var grow := EDGE if layer == 0 else 0.0
		var col := INK if layer == 0 else FILL
		var y := 0.0 if layer == 0 else 0.015
		for a in [PI / 4.0, -PI / 4.0]:
			var u := Vector3(cos(a), 0, sin(a)) * (ARM + grow)
			var v := Vector3(-sin(a), 0, cos(a)) * (WIDTH + grow)
			var p := [-u - v, u - v, u + v, -u + v]
			for i in [0, 2, 1, 0, 3, 2]:
				st.set_color(col)
				st.add_vertex(p[i] + Vector3.UP * y)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	_mesh = st.commit()
	return _mesh
