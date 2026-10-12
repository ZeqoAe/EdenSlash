class_name MapLoader
extends Node3D
## Charge une map convertie par tools/fsm2godot.py : terrain par blocs de 64 m
## (shader multi-couches), eau, objets de décor avec leurs collisions, points clés.

const CHUNK := 33
const CHUNK_SIZE := 64.0
const TERRAIN_SHADER := preload("res://shaders/eden_terrain.gdshader")
const WATER_SHADER := preload("res://shaders/eden_water.gdshader")
const OBJECT_SHADER := preload("res://shaders/eden_object.gdshader")

static var _object_shader_2sided: Shader
static var _object_mats := {}  # id matériau glTF -> ShaderMaterial

var info: Dictionary
var map_id := ""
var bounds := Rect2()  # en x / -z (coordonnées Eden), pour limiter le joueur

var _heights := {}  # Vector2i(bloc) -> PackedFloat32Array (33x33)
var _alphas := {}  # Vector2i(bloc) -> PackedFloat32Array : alpha < 0.5 = trou
var _water_level := {}  # Vector2i(bloc) -> hauteur moyenne de l'eau
var _tex_cache := {}
static var _scene_cache := {}


func load_map(id: String) -> void:
	map_id = id
	add_to_group("map")
	var base := "res://assets/maps/%s/" % id
	info = JSON.parse_string(FileAccess.get_file_as_string(base + "map.json"))
	if info.has("scene"):
		_load_scene(base + String(info.scene))
		setup_navigation()
		return
	var raw := FileAccess.get_file_as_bytes(base + "terrain.bin").to_float32_array()
	var indices := _grid_indices()
	var first := true
	for c: Dictionary in info.chunks:
		var off := int(c.index) * CHUNK * CHUNK * 10
		var mesh := _chunk_mesh(raw, off, indices)
		var origin := Vector2(c.origin[0], -c.origin[1])
		var key := Vector2i(roundi(origin.x / CHUNK_SIZE), roundi(origin.y / CHUNK_SIZE))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		add_child(mi)
		if c.kind == "water":
			var wm := ShaderMaterial.new()
			wm.shader = WATER_SHADER
			mi.material_override = wm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_water_level[key] = mesh.get_aabb().get_center().y
			continue
		mi.material_override = _terrain_material(base, c)
		_heights[key] = _extract_heights(raw, off)
		_alphas[key] = _extract_alphas(raw, off)
		var r := Rect2(origin, Vector2(CHUNK_SIZE, CHUNK_SIZE))
		bounds = r if first else bounds.merge(r)
		first = false
		var body := StaticBody3D.new()
		body.collision_layer = GameData.PHYS_WORLD
		var col := CollisionShape3D.new()
		col.shape = _collision_shape(raw, off, indices)
		body.add_child(col)
		add_child(body)
	_spawn_objects()
	setup_navigation()


func _grid_indices() -> PackedInt32Array:
	var idx := PackedInt32Array()
	for j in CHUNK - 1:
		for i in CHUNK - 1:
			var v0 := j * CHUNK + i
			# ordre horaire = face avant dans Godot
			idx.append_array([v0, v0 + CHUNK, v0 + 1, v0 + 1, v0 + CHUNK, v0 + CHUNK + 1])
	return idx


func _chunk_mesh(raw: PackedFloat32Array, off: int, indices: PackedInt32Array) -> ArrayMesh:
	var n := CHUNK * CHUNK
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(n)
	normals.resize(n)
	colors.resize(n)
	uvs.resize(n)
	for k in n:
		var o := off + k * 10
		verts[k] = Vector3(raw[o], raw[o + 1], raw[o + 2])
		normals[k] = Vector3(raw[o + 3], raw[o + 4], raw[o + 5]).normalized()
		colors[k] = Color(raw[o + 6], raw[o + 7], raw[o + 8], raw[o + 9])
		uvs[k] = Vector2(float(k % CHUNK) / (CHUNK - 1), float(k / CHUNK) / (CHUNK - 1))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Collision du bloc sans les triangles marqués comme trous.
func _collision_shape(raw: PackedFloat32Array, off: int, indices: PackedInt32Array) -> ConcavePolygonShape3D:
	var faces := PackedVector3Array()
	for t in range(0, indices.size(), 3):
		var ok := true
		for k in 3:
			if raw[off + indices[t + k] * 10 + 9] < 0.5:
				ok = false
				break
		if ok:
			for k in 3:
				var o := off + indices[t + k] * 10
				faces.append(Vector3(raw[o], raw[o + 1], raw[o + 2]))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	return shape


func _extract_alphas(raw: PackedFloat32Array, off: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(CHUNK * CHUNK)
	for k in CHUNK * CHUNK:
		a[k] = raw[off + k * 10 + 9]
	return a


func _extract_heights(raw: PackedFloat32Array, off: int) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	h.resize(CHUNK * CHUNK)
	for k in CHUNK * CHUNK:
		h[k] = raw[off + k * 10 + 1]
	return h


func _terrain_material(base: String, c: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter("blend_map", _tex(base + "blend/%d.png" % int(c.index)))
	if c.get("dark", false):
		m.set_shader_parameter("dark_map", _tex(base + "dark/%d.png" % int(c.index)))
	var reps := [4.0, 4.0, 4.0, 4.0, 4.0]
	var enabled := [0.0, 0.0, 0.0, 0.0]
	for k in 5:
		var layer = c.layers[k]
		if layer == null:
			continue
		var tex := _tex("res://assets/maps/textures/%s.png" % layer.texture)
		if tex == null:
			continue
		m.set_shader_parameter("layer%d" % k, tex)
		reps[k] = float(layer.repeat) if float(layer.repeat) > 0.0 else 4.0
		if k > 0:
			enabled[k - 1] = 1.0
	m.set_shader_parameter("repeats", Vector4(reps[0], reps[1], reps[2], reps[3]))
	m.set_shader_parameter("repeat4", reps[4])
	m.set_shader_parameter("enabled", Vector4(enabled[0], enabled[1], enabled[2], enabled[3]))
	return m


func _tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


func _spawn_objects() -> void:
	var holder := Node3D.new()
	holder.name = "Objects"
	add_child(holder)
	for o: Dictionary in info.objects:
		var path := "res://assets/maps/objects/%s.glb" % o.model
		if not _scene_cache.has(path):
			_scene_cache[path] = load(path) if ResourceLoader.exists(path) else null
		var scene: PackedScene = _scene_cache[path]
		if scene == null:
			continue
		var node: Node3D = scene.instantiate()
		var q := Quaternion(o.rot[0], o.rot[1], o.rot[2], o.rot[3])
		node.transform = Transform3D(Basis(q).scaled(Vector3.ONE * float(o.scale)), Vector3(o.pos[0], o.pos[1], o.pos[2]))
		_setup_collisions(node)
		_tune_object_collisions(node, float(o.scale))
		_convert_materials(node)
		holder.add_child(node)


## Collisions importées (formes sans texture d'Eden) : leurs faces sont orientées
## au hasard, on les rend donc solides des deux côtés.
func _setup_collisions(root: Node) -> void:
	for body: StaticBody3D in root.find_children("*", "StaticBody3D", true, false):
		body.collision_layer = GameData.PHYS_WORLD
		for col: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
			if col.shape is ConcavePolygonShape3D:
				(col.shape as ConcavePolygonShape3D).backface_collision = true


## Dans les donjons d'Eden on marche sur le maillage visible : chaque surface
## opaque devient aussi une collision (les effets transparents sont ignorés).
func _add_visual_collisions(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var mat := mi.mesh.surface_get_material(0) as BaseMaterial3D
		if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		var shape := mi.mesh.create_trimesh_shape()
		if shape == null:
			continue
		shape.backface_collision = true
		var body := StaticBody3D.new()
		body.collision_layer = GameData.PHYS_WORLD
		body.collision_mask = 0
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		mi.add_child(body)


## Collisions du décor pensées pour un MMO au clic : en hack and slash on retire
## celles des petits objets et on resserre les autres pour élargir les passages.
const MIN_BLOCK_FOOTPRINT := 1.6
const MIN_BLOCK_HEIGHT := 0.9
const COLLISION_SHRINK := 0.75


func _tune_object_collisions(root: Node3D, inst_scale: float) -> void:
	for body: StaticBody3D in root.find_children("*", "StaticBody3D", true, false):
		for col: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
			var shape := col.shape as ConcavePolygonShape3D
			if shape == null:
				continue
			var xf := EdenModel._relative_xform(root, col)
			var faces := shape.get_faces()
			var box := AABB(xf * faces[0], Vector3.ZERO)
			for v in faces:
				box = box.expand(xf * v)
			var footprint := maxf(box.size.x, box.size.z) * inst_scale
			if footprint < MIN_BLOCK_FOOTPRINT or box.size.y * inst_scale < MIN_BLOCK_HEIGHT:
				col.disabled = true
				continue
			var c := box.get_center()
			var inv := xf.affine_inverse()
			var out := PackedVector3Array()
			out.resize(faces.size())
			for i in faces.size():
				var p := xf * faces[i]
				p.x = c.x + (p.x - c.x) * COLLISION_SHRINK
				p.z = c.z + (p.z - c.z) * COLLISION_SHRINK
				out[i] = inv * p
			var tuned := ConcavePolygonShape3D.new()
			tuned.set_faces(out)
			tuned.backface_collision = true
			col.shape = tuned


## Donjon : une grande scène NIF convertie (salles, murs, sols de collision).
func _load_scene(path: String) -> void:
	var scene: PackedScene = load(path)
	var node: Node3D = scene.instantiate()
	_setup_collisions(node)
	_add_visual_collisions(node)
	_convert_materials(node)
	add_child(node)
	var box := EdenModel.bounds(node)
	bounds = Rect2(box.position.x, -box.end.z, box.size.x, box.size.z)


func is_scene() -> bool:
	return info.has("scene")


## Altitude du sol pour un camp de monstres (terrain ou rayon dans les donjons).
func spawn_ground(x: float, z: float, ref_y: float) -> Vector3:
	if not is_scene():
		var h := height_at(x, z)
		if not is_nan(h):
			return ground_at(x, z, h, 3.0, 6.0)
	# dans une grotte, le rayon part juste au-dessus du héros pour ne pas toucher le plafond
	return ground_at(x, z, ref_y, 2.5, 30.0)


func spawns() -> Array:
	return info.get("spawns", [])


## Remplace les matériaux importés par le shader de décor (toon + trou autour du héros).
func _convert_materials(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if src != null:
				mi.set_surface_override_material(s, decor_material(src))


## Matériau de décor (toon + trou autour du héros) pour un matériau glTF importé.
static func decor_material(src: BaseMaterial3D) -> ShaderMaterial:
	var key := src.get_instance_id()
	if not _object_mats.has(key):
		var m := ShaderMaterial.new()
		var two_sided := src.cull_mode == BaseMaterial3D.CULL_DISABLED
		m.shader = _two_sided_shader() if two_sided else OBJECT_SHADER
		m.set_shader_parameter("albedo_tex", src.albedo_texture)
		m.set_shader_parameter("albedo_color", src.albedo_color)
		if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			m.set_shader_parameter("alpha_cutoff", maxf(src.alpha_scissor_threshold, 0.3))
		_object_mats[key] = m
	return _object_mats[key]


static func _two_sided_shader() -> Shader:
	if _object_shader_2sided == null:
		_object_shader_2sided = Shader.new()
		_object_shader_2sided.code = OBJECT_SHADER.code.replace("cull_back", "cull_disabled")
	return _object_shader_2sided


## Réglages du maillage de navigation (héros : rayon 0,35 m, marche 0,6 m, pente 55°).
static func make_navmesh_settings() -> NavigationMesh:
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_collision_mask = GameData.PHYS_WORLD
	nav.cell_size = 0.5
	nav.cell_height = 0.25
	nav.agent_radius = 0.5
	nav.agent_height = 2.0
	nav.agent_max_climb = 0.75
	nav.agent_max_slope = 55.0
	nav.region_min_size = 8.0
	return nav


## Charge le maillage de navigation précalculé (tools/bake_navmesh.gd).
func setup_navigation() -> void:
	var path := "res://assets/maps/%s/navmesh.res" % map_id
	if not ResourceLoader.exists(path):
		push_warning("pas de navmesh pour %s" % map_id)
		return
	var region := NavigationRegion3D.new()
	var nav: NavigationMesh = load(path)
	region.navigation_mesh = nav
	add_child(region)
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, nav.cell_size)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, nav.cell_height)


## Chemin praticable entre deux points (vide si la navigation est absente).
func path_between(from: Vector3, to: Vector3) -> PackedVector3Array:
	var nav_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(nav_map, from, to, true)


## Hauteur du terrain en (x, z) Godot, ou NAN hors de la map.
func height_at(x: float, z: float) -> float:
	var ex := x
	var ey := -z
	var key := Vector2i(floori(ex / CHUNK_SIZE), floori(ey / CHUNK_SIZE))
	if not _heights.has(key):
		return NAN
	var h: PackedFloat32Array = _heights[key]
	var fx := (ex - key.x * CHUNK_SIZE) / 2.0
	var fy := (ey - key.y * CHUNK_SIZE) / 2.0
	var i := clampi(floori(fx), 0, CHUNK - 2)
	var j := clampi(floori(fy), 0, CHUNK - 2)
	var tx := clampf(fx - i, 0.0, 1.0)
	var ty := clampf(fy - j, 0.0, 1.0)
	var al: PackedFloat32Array = _alphas[key]
	if minf(minf(al[j * CHUNK + i], al[j * CHUNK + i + 1]), minf(al[(j + 1) * CHUNK + i], al[(j + 1) * CHUNK + i + 1])) < 0.5:
		return NAN  # trou
	var a := lerpf(h[j * CHUNK + i], h[j * CHUNK + i + 1], tx)
	var b := lerpf(h[(j + 1) * CHUNK + i], h[(j + 1) * CHUNK + i + 1], tx)
	return lerpf(a, b, ty)


## Sol réel (terrain ou objets) sous (x, z) autour de l'altitude [param ref_y],
## par lancer de rayon physique. Renvoie INF si rien de praticable.
func ground_at(x: float, z: float, ref_y: float, up := 4.0, down := 14.0) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, ref_y + up, z), Vector3(x, ref_y - down, z), GameData.PHYS_WORLD)
	var hit := space.intersect_ray(q)
	if hit.is_empty() or hit.normal.y < 0.72:
		return Vector3.INF
	var p: Vector3 = hit.position
	var key := Vector2i(floori(x / CHUNK_SIZE), floori(-z / CHUNK_SIZE))
	if _water_level.has(key) and p.y < float(_water_level[key]) + 0.2:
		return Vector3.INF
	return p


## Vrai si le point est au sec et pas trop pentu (apparition des monstres).
func is_walkable(x: float, z: float) -> bool:
	var h := height_at(x, z)
	if is_nan(h):
		return false
	var key := Vector2i(floori(x / CHUNK_SIZE), floori(-z / CHUNK_SIZE))
	if _water_level.has(key) and h < float(_water_level[key]) + 0.2:
		return false
	var slope := absf(height_at(x + 1.5, z) - h) + absf(height_at(x, z + 1.5) - h)
	return not is_nan(slope) and slope < 1.6


func event(type: String, label_contains := "") -> Dictionary:
	for e: Dictionary in info.events:
		if e.type == type and (label_contains == "" or String(e.label).contains(label_contains)):
			return e
	return {}


func event_pos(e: Dictionary) -> Vector3:
	return Vector3(e.pos[0], e.pos[1], e.pos[2])
