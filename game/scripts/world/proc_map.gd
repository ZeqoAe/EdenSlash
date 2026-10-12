class_name ProcMap
extends Node3D
## Map générée pour une run, dans la DA d'Eden Eternal :
## relief doux bordé de falaises, chemins entre les lieux, forêts et rochers,
## village (marchand, forgeron, négociant), entrée du donjon, coffres, camps.
## Collisions simples maîtrisées (sol en heightmap, cylindres pour le décor).
##
## Repère : la map couvre x ∈ [0, size], z ∈ [0, size].

const STEP := 2.0  # mètres entre deux sommets
const CHUNK_CELLS := 32
const REGIONS := 4  # découpage du décor pour le frustum culling
const TERRAIN_SHADER := preload("res://shaders/eden_proc_terrain.gdshader")

## Thèmes : textures d'Eden et ambiance.
const THEMES := {
	"limestone": {"grass": "grass_01", "grass2": "grass_07", "dirt": "dust_01", "road": "road_01", "rock": "mount_01", "tint": Color(0.86, 0.86, 0.84)},
	"mine": {"grass": "dust_05", "grass2": "dust_06", "dirt": "dust_05", "road": "road_05", "rock": "mount_03", "tint": Color(0.95, 0.88, 0.8)},
}

var map_id := "run"
var size := 512.0
var n := 257  # sommets par côté
var theme: Dictionary
var biome := "limestone"
var _trees: Array = PropCatalog.TREES
var _rocks: Array = PropCatalog.ROCKS
var _plants: Array = PropCatalog.PLANTS
var rng := RandomNumberGenerator.new()
var heights := PackedFloat32Array()
var bounds := Rect2()  # x, z
var info := {"events": [], "spawns": []}  # compatibilité avec le reste du jeu

# lieux (positions Godot, au sol)
var start := Vector3.ZERO
var village := Vector3.INF
var dungeon := Vector3.INF
var chests: Array[Vector3] = []
var camps: Array = []  # [{pos, tier, elite}]
var interactables: Array[Interactable] = []

var _splat: Image
var _roads: Array = []  # polylignes (Array[Vector2])
var _occupied: Array = []  # [Vector2 centre, rayon] zones sans décor
var _minimap: ImageTexture
var _noise := FastNoiseLite.new()
var _noise2 := FastNoiseLite.new()


# --- génération ----------------------------------------------------------------------
func generate_run(seed_value: int) -> void:
	_setup(biome, 512.0, seed_value)
	_place_pois()
	_build_heights(true)
	_build_roads()
	_flatten_pois()
	_paint_splat()
	_build_terrain()
	_build_village()
	_build_dungeon_entrance()
	_build_chests()
	_scatter_props()
	_build_minimap()
	_setup_navigation()
	info.events = [{"type": "REVIVE", "pos": [start.x, start.y, start.z]},
		{"type": "REVIVE", "pos": [village.x, village.y, village.z]}]


## Décor des menus : la même map, sans navigation (mini-carte au choix).
func generate_scenery(seed_value: int, with_minimap := false) -> void:
	_setup(biome, 512.0, seed_value)
	remove_from_group("map")
	_place_pois()
	_build_heights(true)
	_build_roads()
	_flatten_pois()
	_paint_splat()
	_build_terrain()
	_build_village()
	_build_dungeon_entrance()
	_build_chests()
	_scatter_props()
	if with_minimap:
		_build_minimap()


## Arène du boss : cuvette circulaire fermée par des falaises.
func generate_arena(seed_value: int) -> void:
	_setup("mine" if biome == "limestone" else biome, 96.0, seed_value)
	map_id = "arena"
	start = Vector3(size * 0.5, 0, size * 0.5 + 18.0)
	_build_heights(false)
	var c := Vector2(size * 0.5, size * 0.5)
	for j in n:
		for i in n:
			var d := Vector2(i * STEP, j * STEP).distance_to(c)
			heights[j * n + i] = 0.4 * _noise.get_noise_2d(i * 3.0, j * 3.0) + pow(maxf(0.0, d - 26.0) / 12.0, 2.0) * 14.0
	_splat = Image.create(n - 1, n - 1, false, Image.FORMAT_RGBA8)
	for j in n - 1:
		for i in n - 1:
			var d := Vector2(i * STEP, j * STEP).distance_to(c)
			_splat.set_pixel(i, j, Color(0.5 + 0.5 * _noise2.get_noise_2d(i * 4.0, j * 4.0), 0.0, 1.0 if absf(d - 14.0) < 1.2 else 0.0, 0.0))
	start.y = height_at(start.x, start.z)
	_build_terrain()
	var props := Node3D.new()
	add_child(props)
	var batch := {}
	for k in 18:
		var a := TAU * k / 18.0
		var p := Vector3(c.x + cos(a) * 30.0, 0, c.y + sin(a) * 30.0)
		p.y = height_at(p.x, p.z)
		_add_instance(batch, PropCatalog.pick(_rocks.slice(0, 6), rng), p, false)
	for k in 6:
		var a := TAU * k / 6.0 + 0.3
		var t := Vector3(c.x + cos(a) * 22.0, 0, c.y + sin(a) * 22.0)
		t.y = height_at(t.x, t.z)
		_torch(t)
	_flush_batches(batch, props)
	_build_minimap()
	_setup_navigation()


func _setup(theme_name: String, p_size: float, seed_value: int) -> void:
	add_to_group("map")
	if THEMES.has(theme_name):
		theme = THEMES[theme_name]
	else:
		# biome d'Eden (data/biomes.json) : textures du sol, teinte, décors de la map d'origine
		var b: Dictionary = GameData.biomes.get(theme_name, {})
		theme = (b.get("textures", {}) as Dictionary).duplicate()
		var t: Array = b.get("tint", [0.86, 0.86, 0.84])
		theme["tint"] = Color(t[0], t[1], t[2])
		for key in ["trees", "rocks", "plants"]:
			if (b.get(key, []) as Array).is_empty():
				continue
			set("_" + key, b[key])
	size = p_size
	n = int(size / STEP) + 1
	rng.seed = seed_value
	_noise.seed = seed_value
	_noise.frequency = 0.012
	_noise.fractal_octaves = 4
	_noise2.seed = seed_value + 7
	_noise2.frequency = 0.03
	bounds = Rect2(0, 0, size, size)


func _place_pois() -> void:
	var c := Vector2(size, size) * 0.5
	var ang := rng.randf() * TAU
	var dir := Vector2(cos(ang), sin(ang))
	var s2 := c + dir * 175.0
	var d2 := c - dir.rotated(rng.randf_range(-0.6, 0.6)) * 170.0
	# village du côté du départ, loin de l'entrée du donjon (~200 m)
	var v2 := c + dir * rng.randf_range(25.0, 70.0) + dir.orthogonal() * rng.randf_range(-50.0, 50.0)
	start = Vector3(s2.x, 0, s2.y)
	dungeon = Vector3(d2.x, 0, d2.y)
	village = Vector3(v2.x, 0, v2.y)
	_occupied = [[s2, 16.0], [d2, 18.0], [v2, 42.0]]
	for k in 11:
		var p := _free_point(48.0, 55.0)
		if p != Vector2.INF:
			chests.append(Vector3(p.x, 0, p.y))
			_occupied.append([p, 6.0])
	for k in 16:
		var p := _free_point(36.0, 60.0)
		if p == Vector2.INF:
			continue
		# plus on s'éloigne du départ, plus le camp est dangereux
		var tier := clampi(int(p.distance_to(s2) / 90.0), 0, 3)
		camps.append({"pos": Vector3(p.x, 0, p.y), "tier": tier, "elite": k < 4})
		_occupied.append([p, 9.0])


## Point libre à distance des lieux existants, loin des bords.
func _free_point(min_dist: float, margin: float) -> Vector2:
	for attempt in 80:
		var p := Vector2(rng.randf_range(margin, size - margin), rng.randf_range(margin, size - margin))
		var ok := true
		for o in _occupied:
			if p.distance_to(o[0]) < min_dist + float(o[1]) * 0.5:
				ok = false
				break
		if ok:
			return p
	return Vector2.INF


func _build_heights(with_border: bool) -> void:
	heights.resize(n * n)
	for j in n:
		for i in n:
			var x := i * STEP
			var z := j * STEP
			var h := _noise.get_noise_2d(x, z) * 9.0 + _noise2.get_noise_2d(x, z) * 1.5
			if with_border:
				var d := minf(minf(x, z), minf(size - x, size - z))
				if d < 50.0:
					h += pow((50.0 - d) / 50.0, 2.0) * 30.0
			heights[j * n + i] = h


func _build_roads() -> void:
	var s2 := Vector2(start.x, start.z)
	var v2 := Vector2(village.x, village.z)
	var d2 := Vector2(dungeon.x, dungeon.z)
	var links := [[s2, v2], [v2, d2]]
	# quelques chemins secondaires vers des coffres
	var others := chests.duplicate()
	others.shuffle()
	for k in mini(3, others.size()):
		links.append([v2, Vector2(others[k].x, others[k].z)])
	for l in links:
		var road := _wiggle(l[0], l[1])
		_roads.append(road)
		_flatten_along(road, 4.5)


## Chemin naturel : points intermédiaires décalés par du bruit.
func _wiggle(a: Vector2, b: Vector2) -> Array:
	var pts: Array = []
	var steps := maxi(4, int(a.distance_to(b) / 24.0))
	var normal := (b - a).normalized().orthogonal()
	for k in steps + 1:
		var t := float(k) / steps
		var off := 0.0 if k == 0 or k == steps else _noise2.get_noise_2d(t * 40.0, a.x) * 22.0
		pts.append(a.lerp(b, t) + normal * off)
	return pts


func _flatten_along(road: Array, width: float) -> void:
	for k in road.size() - 1:
		var a: Vector2 = road[k]
		var b: Vector2 = road[k + 1]
		var seg := a.distance_to(b)
		var t := 0.0
		while t <= seg:
			var p := a.lerp(b, t / seg)
			_flatten_disk(p, width, _raw_height(p.x, p.y), 0.6)
			t += STEP


func _flatten_pois() -> void:
	_flatten_disk(Vector2(start.x, start.z), 14.0, _raw_height(start.x, start.z), 1.0)
	_flatten_disk(Vector2(village.x, village.z), 38.0, _raw_height(village.x, village.z), 1.0)
	_flatten_disk(Vector2(dungeon.x, dungeon.z), 16.0, _raw_height(dungeon.x, dungeon.z), 1.0)
	for c in chests:
		_flatten_disk(Vector2(c.x, c.z), 4.0, _raw_height(c.x, c.z), 0.8)
	for camp in camps:
		_flatten_disk(Vector2(camp.pos.x, camp.pos.z), 9.0, _raw_height(camp.pos.x, camp.pos.z), 0.7)
	start.y = height_at(start.x, start.z)
	village.y = height_at(village.x, village.z)
	dungeon.y = height_at(dungeon.x, dungeon.z)
	for k in chests.size():
		chests[k].y = height_at(chests[k].x, chests[k].z)
	for camp in camps:
		camp.pos.y = height_at(camp.pos.x, camp.pos.z)


## Aplanit vers [param target] dans un disque, avec un bord adouci.
func _flatten_disk(c: Vector2, r: float, target: float, strength: float) -> void:
	var r2 := r + 10.0
	var i0 := maxi(0, int((c.x - r2) / STEP))
	var i1 := mini(n - 1, int((c.x + r2) / STEP) + 1)
	var j0 := maxi(0, int((c.y - r2) / STEP))
	var j1 := mini(n - 1, int((c.y + r2) / STEP) + 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var d := Vector2(i * STEP, j * STEP).distance_to(c)
			var w := (1.0 - smoothstep(r, r2, d)) * strength
			if w > 0.0:
				var k := j * n + i
				heights[k] = lerpf(heights[k], target, w)


func _raw_height(x: float, z: float) -> float:
	var i := clampi(roundi(x / STEP), 0, n - 1)
	var j := clampi(roundi(z / STEP), 0, n - 1)
	return heights[j * n + i]


func _paint_splat() -> void:
	_splat = Image.create(n - 1, n - 1, false, Image.FORMAT_RGBA8)
	var road_mask := PackedFloat32Array()
	road_mask.resize((n - 1) * (n - 1))
	for road in _roads:
		for k in road.size() - 1:
			var a: Vector2 = road[k]
			var b: Vector2 = road[k + 1]
			var seg := a.distance_to(b)
			var t := 0.0
			while t <= seg:
				var p := a.lerp(b, t / seg) / STEP
				for dj in range(-2, 3):
					for di in range(-2, 3):
						var i := int(p.x) + di
						var j := int(p.y) + dj
						if i >= 0 and j >= 0 and i < n - 1 and j < n - 1:
							var w := 1.0 - clampf(Vector2(di, dj).length() / 2.4, 0.0, 1.0)
							road_mask[j * (n - 1) + i] = maxf(road_mask[j * (n - 1) + i], w)
				t += 1.0
	for j in n - 1:
		for i in n - 1:
			var x := i * STEP
			var z := j * STEP
			var g2 := smoothstep(0.0, 0.35, _noise2.get_noise_2d(x * 0.5, z * 0.5))
			var dirt := smoothstep(0.25, 0.6, _noise.get_noise_2d(x * 2.0 + 100.0, z * 2.0))
			var p := Vector2(x, z)
			if p.distance_to(Vector2(village.x, village.z)) < 18.0:
				dirt = maxf(dirt, 0.85)
			for camp in camps:
				dirt = maxf(dirt, 0.7 * (1.0 - smoothstep(4.0, 9.0, p.distance_to(Vector2(camp.pos.x, camp.pos.z)))))
			_splat.set_pixel(i, j, Color(g2, dirt, road_mask[j * (n - 1) + i], 0.0))


# --- terrain ---------------------------------------------------------------------------
func _build_terrain() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("map_size", Vector2(size, size))
	for key in ["grass", "grass2", "dirt", "road", "rock"]:
		mat.set_shader_parameter("tex_" + key, load("res://assets/maps/textures/%s.png" % theme[key]))
	mat.set_shader_parameter("tint", theme.tint)
	_terrain_mat = mat
	_refresh_splat()
	var chunks := ceili(float(n - 1) / CHUNK_CELLS)
	for cj in chunks:
		for ci in chunks:
			var mi := MeshInstance3D.new()
			mi.mesh = _chunk_mesh(ci * CHUNK_CELLS, cj * CHUNK_CELLS)
			mi.material_override = mat
			add_child(mi)
	# collision : une seule heightmap (échelle 2 uniforme, hauteurs divisées par 2)
	var hm := HeightMapShape3D.new()
	hm.map_width = n
	hm.map_depth = n
	var data := PackedFloat32Array()
	data.resize(n * n)
	for k in n * n:
		data[k] = heights[k] / STEP
	hm.map_data = data
	var body := StaticBody3D.new()
	body.collision_layer = GameData.PHYS_WORLD
	var col := CollisionShape3D.new()
	col.shape = hm
	col.scale = Vector3.ONE * STEP
	col.position = Vector3(size * 0.5, 0, size * 0.5)
	body.add_child(col)
	add_child(body)


var _terrain_mat: ShaderMaterial


func _refresh_splat() -> void:
	_terrain_mat.set_shader_parameter("splat_map", ImageTexture.create_from_image(_splat))


func _chunk_mesh(i0: int, j0: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cx := mini(CHUNK_CELLS, n - 1 - i0)  # dernier bloc éventuellement incomplet
	var cz := mini(CHUNK_CELLS, n - 1 - j0)
	var w := cx + 1
	for j in range(j0, j0 + cz + 1):
		for i in range(i0, i0 + w):
			st.set_normal(_normal(i, j))
			st.add_vertex(Vector3(i * STEP, heights[j * n + i], j * STEP))
	for j in cz:
		for i in cx:
			var a := j * w + i
			# face avant vers le haut (z croît avec j)
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + w)
			st.add_index(a + 1)
			st.add_index(a + w + 1)
			st.add_index(a + w)
	return st.commit()


func _normal(i: int, j: int) -> Vector3:
	var hl := heights[j * n + maxi(i - 1, 0)]
	var hr := heights[j * n + mini(i + 1, n - 1)]
	var hd := heights[maxi(j - 1, 0) * n + i]
	var hu := heights[mini(j + 1, n - 1) * n + i]
	return Vector3(hl - hr, 2.0 * STEP, hd - hu).normalized()


# --- décor -------------------------------------------------------------------------------
static var _model_meshes := {}  # modèle -> [[Mesh, Transform3D local]]


## Maillages d'un modèle de décor (matériaux convertis au style du jeu).
static func model_meshes(model: String) -> Array:
	if _model_meshes.has(model):
		return _model_meshes[model]
	var out: Array = []
	var path := "res://assets/maps/objects/%s.glb" % model
	if ResourceLoader.exists(path):
		var root: Node3D = (load(path) as PackedScene).instantiate()
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var mesh := mi.mesh.duplicate() as Mesh
			for s in mesh.get_surface_count():
				var src := mesh.surface_get_material(s) as BaseMaterial3D
				if src:
					mesh.surface_set_material(s, MapLoader.decor_material(src))
			out.append([mesh, EdenModel._relative_xform(root, mi)])
		root.free()
	_model_meshes[model] = out
	return out


func _region_of(p: Vector3) -> int:
	var rs := size / REGIONS
	return clampi(int(p.z / rs), 0, REGIONS - 1) * REGIONS + clampi(int(p.x / rs), 0, REGIONS - 1)


## Ajoute une instance de décor au lot (et sa collision si demandé).
func _add_instance(batch: Dictionary, prop: Dictionary, pos: Vector3, collide := true, yaw := INF, scale_mult := 1.0) -> void:
	var s := rng.randf_range(prop.scale[0], prop.scale[1]) * scale_mult
	var basis := Basis(Vector3.UP, rng.randf() * TAU if yaw == INF else yaw).scaled(Vector3.ONE * s)
	var xf := Transform3D(basis, pos)
	var key := "%s|%d" % [prop.model, _region_of(pos)]
	if not batch.has(key):
		batch[key] = {"model": prop.model, "xforms": []}
	batch[key].xforms.append(xf)
	if collide and float(prop.get("col", 0.0)) > 0.0:
		_add_collider(pos, float(prop.col) * s, 6.0)
	# ombre au sol sous les arbres (canal A de la carte de mélange)
	if prop.has("col") and float(prop.col) >= 1.5:
		_stamp_shadow(Vector2(pos.x, pos.z), float(prop.col) * s * 2.2)


func _stamp_shadow(c: Vector2, r: float) -> void:
	var rc := int(r / STEP) + 1
	for dj in range(-rc, rc + 1):
		for di in range(-rc, rc + 1):
			var i := int(c.x / STEP) + di
			var j := int(c.y / STEP) + dj
			if i < 0 or j < 0 or i >= n - 1 or j >= n - 1:
				continue
			var w := 1.0 - clampf(Vector2(di, dj).length() * STEP / r, 0.0, 1.0)
			var px := _splat.get_pixel(i, j)
			px.a = maxf(px.a, w * 0.9)
			_splat.set_pixel(i, j, px)


var _colliders: StaticBody3D


func _body() -> StaticBody3D:
	if _colliders == null:
		_colliders = StaticBody3D.new()
		_colliders.collision_layer = GameData.PHYS_WORLD
		add_child(_colliders)
	return _colliders


func _add_collider(pos: Vector3, r: float, h: float) -> void:
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = maxf(r, 0.3)
	cyl.height = h
	col.shape = cyl
	col.position = pos + Vector3.UP * (h * 0.5 - 0.5)
	_body().add_child(col)


func _add_box_collider(pos: Vector3, half: Vector3, yaw: float) -> void:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = half * 2.0
	col.shape = box
	col.transform = Transform3D(Basis(Vector3.UP, yaw), pos + Vector3.UP * half.y)
	_body().add_child(col)


func _flush_batches(batch: Dictionary, parent: Node3D) -> void:
	for key in batch:
		var b: Dictionary = batch[key]
		for entry in model_meshes(b.model):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = entry[0]
			mm.instance_count = b.xforms.size()
			for k in b.xforms.size():
				mm.set_instance_transform(k, b.xforms[k] * entry[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			parent.add_child(mmi)


func _is_free(p: Vector2, extra: float) -> bool:
	for o in _occupied:
		if p.distance_to(o[0]) < float(o[1]) + extra:
			return false
	for road in _roads:
		for k in road.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, road[k], road[k + 1]).distance_to(p) < 4.0 + extra:
				return false
	return true


func _scatter_props() -> void:
	var holder := Node3D.new()
	holder.name = "Decor"
	add_child(holder)
	var batch := {}
	var placed: Array[Vector2] = []
	# arbres : par grappes (forêts) selon un bruit, plus denses près des bords
	var attempts := 9000
	for k in attempts:
		var p := Vector2(rng.randf_range(4, size - 4), rng.randf_range(4, size - 4))
		var edge := minf(minf(p.x, p.y), minf(size - p.x, size - p.y))
		var forest := _noise.get_noise_2d(p.x * 1.7 + 300.0, p.y * 1.7)
		var density := 0.35 + forest * 1.2 + (0.5 if edge < 60.0 else 0.0)
		if rng.randf() > density:
			continue
		if not _is_free(p, 2.0) or _near(placed, p, 5.5):
			continue
		var pos := Vector3(p.x, height_at(p.x, p.y) - 0.2, p.y)
		if _slope(p.x, p.y) > 0.55:
			continue
		placed.append(p)
		_add_instance(batch, PropCatalog.pick(_trees, rng), pos)
		if placed.size() > 520:
			break
	# rochers
	for k in 90:
		var p := Vector2(rng.randf_range(20, size - 20), rng.randf_range(20, size - 20))
		if not _is_free(p, 4.0) or _near(placed, p, 6.0):
			continue
		placed.append(p)
		_add_instance(batch, PropCatalog.pick(_rocks, rng), Vector3(p.x, height_at(p.x, p.y) - 0.4, p.y))
	# plantes et fleurs (pas de collision), y compris en bord de chemin
	for k in 2600:
		var p := Vector2(rng.randf_range(6, size - 6), rng.randf_range(6, size - 6))
		if _noise2.get_noise_2d(p.x * 2.0, p.y * 2.0) < -0.1:
			continue
		var on_road := false
		for road in _roads:
			for s in road.size() - 1:
				if Geometry2D.get_closest_point_to_segment(p, road[s], road[s + 1]).distance_to(p) < 2.5:
					on_road = true
					break
		if on_road:
			continue
		_add_instance(batch, PropCatalog.pick(_plants, rng), Vector3(p.x, height_at(p.x, p.y), p.y), false)
	_flush_batches(batch, holder)
	_refresh_splat()


func _near(list: Array[Vector2], p: Vector2, d: float) -> bool:
	for q in list:
		if q.distance_squared_to(p) < d * d:
			return true
	return false


func _slope(x: float, z: float) -> float:
	var h := height_at(x, z)
	return (absf(height_at(x + 2, z) - h) + absf(height_at(x, z + 2) - h)) / 4.0


# --- lieux -------------------------------------------------------------------------------
func _build_village() -> void:
	var holder := Node3D.new()
	holder.name = "Village"
	add_child(holder)
	var batch := {}
	var c := village
	# puits au centre de la place
	_add_instance(batch, {"model": "uc405", "scale": [1.0, 1.0], "col": 1.2}, c, true, 0.0)
	# maisons en anneau, entrées tournées vers la place
	var houses := PropCatalog.VILLAGE_HOUSES.duplicate()
	houses.shuffle()
	var count := 6
	for k in count:
		var a := TAU * k / count + rng.randf_range(-0.15, 0.15)
		var p := c + Vector3(cos(a), 0, sin(a)) * 27.0
		p.y = height_at(p.x, p.z) - 0.3
		var yaw := atan2(c.x - p.x, c.z - p.z)
		_add_instance(batch, {"model": houses[k % houses.size()], "scale": [0.55, 0.65]}, p, false, yaw)
		_add_box_collider(p, Vector3(4.2, 4.0, 4.2), yaw)
		# un peu de bazar devant chaque maison
		for m in 2:
			var q := p + Vector3(cos(a + 0.5 - m), 0, sin(a + 0.5 - m)) * 6.5
			q.y = height_at(q.x, q.z)
			_add_instance(batch, {"model": PropCatalog.VILLAGE_CLUTTER.pick_random(), "scale": [0.9, 1.1]}, q, false)
	# étals et PNJ
	var stalls := [
		["merchant", "uc322", 0.0, "Alec, marchand"],
		["smith", "uc340", TAU / 4.0, "Bryson, forgeron"],
		["recycler", "uc323", TAU / 2.0, "Starnoc, recycleur"],
		["jeweler", "uc322", 3.0 * TAU / 4.0, "Lertia, joaillière"],
	]
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json"))
	for s in stalls:
		var a: float = s[2] + 0.5
		var p := c + Vector3(cos(a), 0, sin(a)) * 11.0
		p.y = height_at(p.x, p.z)
		var yaw := atan2(c.x - p.x, c.z - p.z)
		_add_instance(batch, {"model": s[1], "scale": [0.8, 0.8]}, p + Vector3(cos(a), 0, sin(a)) * 2.0, false, yaw)
		var npc := Interactable.new()
		var data: Dictionary = npcs.get(s[0], {})
		npc.setup(s[0], s[3], "res://assets/monsters/%s/%s.glb" % [data.get("model", ""), data.get("model", "")],
			"res://assets/monsters/textures/%s.png" % data.get("texture", ""), float(data.get("scale", 1.0)), 4.0)
		holder.add_child(npc)
		npc.global_position = p
		npc.rotation.y = yaw
		interactables.append(npc)
	# palissade avec trois ouvertures (chemins)
	for k in 36:
		var a := TAU * k / 36.0
		if _gap_for_road(c, a):
			continue
		var p := c + Vector3(cos(a), 0, sin(a)) * 36.0
		p.y = height_at(p.x, p.z)
		_add_instance(batch, {"model": "ub003", "scale": [1.3, 1.3]}, p, false, -a)
	_flush_batches(batch, holder)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 1.5
	light.omni_range = 30.0
	light.position = c + Vector3.UP * 6.0
	holder.add_child(light)


## Laisse une ouverture dans la palissade là où passe un chemin.
func _gap_for_road(c: Vector3, a: float) -> bool:
	var p := Vector2(c.x, c.z) + Vector2(cos(a), sin(a)) * 36.0
	for road in _roads:
		for k in road.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, road[k], road[k + 1]).distance_to(p) < 7.0:
				return true
	return false


func _build_dungeon_entrance() -> void:
	var holder := Node3D.new()
	holder.name = "Dungeon"
	add_child(holder)
	var batch := {}
	var to_center := Vector3(size * 0.5 - dungeon.x, 0, size * 0.5 - dungeon.z).normalized()
	var yaw := atan2(to_center.x, to_center.z)
	_add_instance(batch, {"model": "ub101", "scale": [0.9, 0.9]}, dungeon - to_center * 3.0, false, yaw)
	_add_box_collider(dungeon - to_center * 6.0, Vector3(5.0, 5.0, 2.0), yaw)
	for k in 7:
		var a := yaw + PI + rng.randf_range(-1.6, 1.6)
		var p := dungeon + Vector3(sin(a), 0, cos(a)) * rng.randf_range(9.0, 14.0)
		p.y = height_at(p.x, p.z) - 0.5
		_add_instance(batch, PropCatalog.pick(_rocks.slice(0, 6), rng), p)
	_flush_batches(batch, holder)
	for side: float in [-1.0, 1.0]:
		var t := dungeon + to_center * 2.0 + to_center.cross(Vector3.UP) * 4.0 * side
		t.y = height_at(t.x, t.z)
		_torch(t)
	var portal := Interactable.new()
	portal.setup("dungeon", "Entrée du donjon", "", "", 1.0, 6.0)
	holder.add_child(portal)
	portal.global_position = dungeon
	interactables.append(portal)


func _torch(p: Vector3) -> void:
	var batch := {}
	_add_instance(batch, {"model": "uc308", "scale": [1.0, 1.0]}, p, false, 0.0)
	_flush_batches(batch, self)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.light_energy = 2.0
	l.omni_range = 10.0
	l.position = p + Vector3.UP * 2.2
	add_child(l)


func _build_chests() -> void:
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json"))
	var data: Dictionary = npcs.get("chest", {})
	for c in chests:
		var chest := Interactable.new()
		chest.setup("chest", "Coffre", "res://assets/monsters/%s/%s.glb" % [data.model, data.model],
			"res://assets/monsters/textures/%s.png" % data.texture, 1.0, 3.0)
		add_child(chest)
		chest.global_position = c
		chest.rotation.y = rng.randf() * TAU
		interactables.append(chest)


# --- requêtes ----------------------------------------------------------------------------
func height_at(x: float, z: float) -> float:
	var fx := clampf(x / STEP, 0.0, n - 1.001)
	var fz := clampf(z / STEP, 0.0, n - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := lerpf(heights[j * n + i], heights[j * n + i + 1], tx)
	var b := lerpf(heights[(j + 1) * n + i], heights[(j + 1) * n + i + 1], tx)
	return lerpf(a, b, tz)


func ground_at(x: float, z: float, _ref_y := 0.0, _up := 0.0, _down := 0.0) -> Vector3:
	if x < 2.0 or z < 2.0 or x > size - 2.0 or z > size - 2.0:
		return Vector3.INF
	if _slope(x, z) > 0.6:
		return Vector3.INF
	return Vector3(x, height_at(x, z), z)


func spawn_ground(x: float, z: float, ref_y: float) -> Vector3:
	return ground_at(x, z, ref_y)


func is_walkable(x: float, z: float) -> bool:
	return ground_at(x, z) != Vector3.INF


func spawns() -> Array:
	return []


func event(_type: String, _label := "") -> Dictionary:
	return {}


func event_pos(e: Dictionary) -> Vector3:
	return Vector3(e.pos[0], e.pos[1], e.pos[2])


# --- navigation -------------------------------------------------------------------------
var _region: NavigationRegion3D


func _setup_navigation() -> void:
	_region = NavigationRegion3D.new()
	var nav := MapLoader.make_navmesh_settings()
	nav.cell_size = 1.0
	nav.cell_height = 0.25
	nav.agent_radius = 1.0
	nav.agent_max_slope = 40.0
	add_child(_region)
	var nav_map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(nav_map, nav.cell_size)
	NavigationServer3D.map_set_cell_height(nav_map, nav.cell_height)
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, src, self)
	NavigationServer3D.bake_from_source_geometry_data_async(nav, src, func():
		if is_instance_valid(_region):
			_region.navigation_mesh = nav)


func path_between(from: Vector3, to: Vector3) -> PackedVector3Array:
	var nav_map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(nav_map, from, to, true)


# --- mini-carte -------------------------------------------------------------------------
const MINIMAP_RES := 256


func _build_minimap() -> void:
	var img := Image.create(MINIMAP_RES, MINIMAP_RES, false, Image.FORMAT_RGBA8)
	var k := float(n - 1) / MINIMAP_RES
	var grass := Color(0.45, 0.68, 0.32)
	var grass2 := Color(0.55, 0.75, 0.38)
	var dirt := Color(0.72, 0.6, 0.42)
	var road := Color(0.86, 0.78, 0.55)
	var rock := Color(0.55, 0.5, 0.48)
	if map_id == "arena":
		grass = Color(0.55, 0.45, 0.35)
		grass2 = grass
	for y in MINIMAP_RES:
		for x in MINIMAP_RES:
			var i := mini(int(x * k), n - 2)
			var j := mini(int(y * k), n - 2)
			var s := _splat.get_pixel(i, j)
			var c := grass.lerp(grass2, s.r).lerp(dirt, s.g).lerp(road, s.b)
			c = c.lerp(rock, smoothstep(0.35, 0.6, _slope(i * STEP, j * STEP)))
			c = c.darkened(s.a * 0.35)
			# relief : ombrage simple
			var dh := heights[j * n + i] - heights[(j + 1) * n + i + 1]
			c = c.lightened(clampf(dh * 0.08, 0.0, 0.25)).darkened(clampf(-dh * 0.08, 0.0, 0.25))
			img.set_pixel(x, y, c)
	_minimap = ImageTexture.create_from_image(img)


## Informations pour la mini-carte : texture et passage monde -> pixel.
func minimap_info() -> Dictionary:
	return {"texture": _minimap, "ppm": MINIMAP_RES / size}


func world_to_minimap(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) * (MINIMAP_RES / size)
