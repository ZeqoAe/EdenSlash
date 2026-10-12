class_name GrassField
extends Node3D
## Herbe 3D d'une map générée (ProcMap) : touffes de brins instanciées par carrés de
## 16 m, construites seulement autour de la caméra (et gardées en mémoire), sur
## l'herbe du terrain (ni chemin, ni terre, ni roche, ni bâtiment). Densité selon la
## qualité graphique et le biome.

const SHADER := preload("res://shaders/eden_grass.gdshader")
const CELL := 16.0
const RADIUS := 40.0
## Herbe plus ou moins présente selon le biome.
const BIOME_DENSITY := {"limestone": 1.0, "rainbowfall": 1.0, "wetlands": 0.9, "beluga": 0.6, "avila": 0.12, "arid": 0.2, "mine": 0.0}

var map: ProcMap
var density := 1.0  # touffes par m²
var _mat: ShaderMaterial
var _mesh: ArrayMesh
var _cells := {}  # Vector2i -> MultiMeshInstance3D (ou null : vide)
var _blocked := PackedByteArray()  # occupation (bâtiments, lieux) au pas de la map
var _check := 0.0


## Prépare l'herbe de [param m] ; renvoie null si le biome ou la qualité n'en veulent pas.
static func create(m: ProcMap) -> GrassField:
	var d := Gfx.grass_density() * float(BIOME_DENSITY.get(m.biome, 0.8))
	if d <= 0.01 or m.map_id == "arena":
		return null
	var g := GrassField.new()
	g.name = "Grass"
	g.map = m
	g.density = 2.6 * d
	m.add_child(g)
	return g


func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var tex_name := String(map.theme.get("grass", "grass_01"))
	_mat.set_shader_parameter("tex_grass", load("res://assets/maps/textures/%s.png" % tex_name))
	_mat.set_shader_parameter("tint", map.theme.get("tint", Color(1, 1, 1)))
	_mesh = _clump_mesh()
	_mesh.surface_set_material(0, _mat)
	# occupation : lieux et bâtiments sans herbe
	var n := map.n
	_blocked.resize(n * n)
	for o in map._occupied:
		# village et entrée du donjon (bâtiments), coffres ; départ et camps gardent l'herbe
		var c: Vector2 = o[0]
		var r := float(o[1])
		if r >= 18.0:
			r *= 0.75
		elif r <= 6.0:
			r = 2.5
		else:
			continue
		var rc := int(r / ProcMap.STEP) + 1
		var ci := int(c.x / ProcMap.STEP)
		var cj := int(c.y / ProcMap.STEP)
		for j in range(maxi(cj - rc, 0), mini(cj + rc + 1, n)):
			for i in range(maxi(ci - rc, 0), mini(ci + rc + 1, n)):
				if Vector2(i * ProcMap.STEP, j * ProcMap.STEP).distance_to(c) < r:
					_blocked[j * n + i] = 1


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 0.25
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	# centre : le point du sol que regarde la caméra
	var f := -cam.global_basis.z
	var c := cam.global_position
	if f.y < -0.05:
		c += f * clampf((cam.global_position.y - map.height_at(c.x, c.z)) / -f.y, 0.0, 60.0)
	# carrés proches d'abord ; au premier passage, tout est construit d'un coup
	var budget := 1000 if _cells.is_empty() else 4
	var r := int(ceil(RADIUS / CELL))
	var cc := Vector2i(int(c.x / CELL), int(c.z / CELL))
	var todo: Array = []
	for dj in range(-r, r + 1):
		for di in range(-r, r + 1):
			var k := cc + Vector2i(di, dj)
			var center := (Vector2(k) + Vector2(0.5, 0.5)) * CELL
			var dist := center.distance_to(Vector2(c.x, c.z))
			var near := dist < RADIUS + CELL * 0.7
			if near and not _cells.has(k):
				todo.append([dist, k])
			if _cells.has(k) and _cells[k] != null:
				(_cells[k] as Node3D).visible = near
	todo.sort_custom(func(a, b): return a[0] < b[0])
	for t in todo.slice(0, budget):
		_cells[t[1]] = _build(t[1])


func _build(k: Vector2i) -> MultiMeshInstance3D:
	if k.x < 0 or k.y < 0 or k.x * CELL >= map.size or k.y * CELL >= map.size:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k) ^ 7919
	var xf: Array[Transform3D] = []
	var count := int(CELL * CELL * density)
	var n := map.n
	for i in count:
		var x := k.x * CELL + rng.randf() * CELL
		var z := k.y * CELL + rng.randf() * CELL
		var gi := clampi(int(x / ProcMap.STEP), 0, n - 2)
		var gj := clampi(int(z / ProcMap.STEP), 0, n - 2)
		if _blocked[gj * n + gi] == 1:
			continue
		var s := map._splat.get_pixel(gi, gj)
		var bare := maxf(s.g, s.b * 1.6)  # terre, chemin
		if rng.randf() < bare * 1.4 or map._slope(x, z) > 0.3:
			continue
		var y := map.height_at(x, z)
		var sc := rng.randf_range(0.7, 1.25) * (1.0 - 0.35 * s.a)
		xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.8, 1.2), sc)), Vector3(x, y - 0.03, z)))
	if xf.is_empty():
		return null
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


## Touffe de 9 brins effilés et courbés (3 segments chacun).
static func _clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for b in 9:
		var a := rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-dir.z, 0, dir.x)
		var off := Vector3(rng.randf_range(-0.12, 0.12), 0, rng.randf_range(-0.12, 0.12))
		var h := rng.randf_range(0.25, 0.5)
		var w := rng.randf_range(0.05, 0.08)
		var lean := rng.randf_range(0.05, 0.22)
		var rows: Array[PackedVector3Array] = []
		for r in 4:
			var t := r / 3.0
			var p := off + Vector3.UP * h * t + dir * lean * t * t
			var hw := w * (1.0 - t * 0.9)
			rows.append(PackedVector3Array([p - side * hw, p + side * hw]))
		for r in 3:
			var t0 := r / 3.0
			var t1 := (r + 1) / 3.0
			var q := [[rows[r][0], t0, 0.0], [rows[r][1], t0, 1.0], [rows[r + 1][1], t1, 1.0],
				[rows[r][0], t0, 0.0], [rows[r + 1][1], t1, 1.0], [rows[r + 1][0], t1, 0.0]]
			for v in q:
				st.set_uv(Vector2(v[2], v[1]))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
	return st.commit()
