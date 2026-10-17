class_name AssaultMap
extends RefCounted
## Format de carte de L'Assaut (lot TAC-1, rapport conception/benchmark/R_TAC_1.md) : une carte faite à la main,
## décrite par data/assault_maps/<id>.json (relevé du plan masse de l'étude : murs pleins, murets, terrasses et rampes,
## hautes herbes, décor qui arrête les coups, sites, départs, noms des lieux, postes de l'IA), construite dans une ProcMap
## (ProcMap.generate_assault) : sol plat dans l'aire de jeu et falaises autour, maisons aux toits « bonbon », murets de
## pierre, terrasses, herbes ; collisions sur des couches dédiées (vue, coups) ; navigation cuite (sur un fil : attendre
## map._region.navigation_mesh, piège T1) ; mini-carte avec les murs.
##
## Repères : le JSON est en mètres du plan (x vers l'est, z vers le sud, origine au coin nord-ouest de l'aire de jeu) ;
## la carte du monde est un carré de côté size_max + 2 MARGIN, l'aire de jeu centrée (to_world / to_plan).
## La description pour le directeur (ProcMap.assault) : {id, name, offset, plan_size, sites: {A: {pos, radius, rect}},
## spawns: {attack: {pos, half}, defense}, places: [{name, pos}], positions, sanctuary, blocks}.
##
## Couches de physique (lot TAC-2, AssaultVision) : SIGHT = ce qui arrête la vue (murs pleins ; barricades et brume à venir),
## SHOT = ce qui arrête les coups (murs pleins, murets, fontaine). Les deux s'ajoutent à PHYS_WORLD (déplacement,
## navigation) : un rayon de vue ou de tir ne lit que sa couche, jamais le relief.

const DIR := "res://data/assault_maps/%s.json"
const IDS := ["bourg"]
const SIGHT := 512  # couche 10 : arrête la vue
const SHOT := 1024  # couche 11 : arrête les coups
const MARGIN := 14.0
const CLIFF := 9.0  # m : hauteur des falaises autour de l'aire de jeu
const ROOF_COLORS := ["soleil", "mandarine", "pomme", "lagon", "amethyste", "fraise"]

static var _mats: Dictionary = {}


static func load_data(id: String) -> Dictionary:
	var path := DIR % id
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary else {}


## Rectangle du plan [x0, z0, x1, z1] -> Rect2 du plan.
static func rect_of(a: Array) -> Rect2:
	return Rect2(Vector2(float(a[0]), float(a[1])), Vector2(float(a[2]) - float(a[0]), float(a[3]) - float(a[1])))


static func to_world(m: ProcMap, p: Vector2, y := 0.0) -> Vector3:
	var off: Vector2 = m.assault.offset
	return Vector3(p.x + off.x, y, p.y + off.y)


static func to_plan(m: ProcMap, p: Vector3) -> Vector2:
	var off: Vector2 = m.assault.offset
	return Vector2(p.x - off.x, p.z - off.y)


## Construit la carte [param id] dans [param m] (appelé par ProcMap.generate_assault).
static func build(m: ProcMap, id: String) -> void:
	var data := load_data(id)
	assert(not data.is_empty(), "AssaultMap : carte inconnue " + id)
	var plan := Vector2(float(data.size[0]), float(data.size[1]))
	var side := ceilf((maxf(plan.x, plan.y) + 2.0 * MARGIN) / ProcMap.STEP) * ProcMap.STEP
	m._setup(String(data.get("biome", m.biome)), side, hash(id))
	m.map_id = "assault"
	m.assault = {"id": id, "name": String(data.get("name", id)), "offset": ((Vector2(side, side) - plan) * 0.5).floor(),
		"plan_size": plan, "data": data}
	var area := Rect2(Vector2.ZERO, plan)
	_heights(m, area)
	_splat(m, data, area)
	m._build_terrain()
	var holder := Node3D.new()
	holder.name = "AssaultDecor"
	m.add_child(holder)
	var blocks: Array = []
	var wh := float(data.get("wall_height", 4.5))
	var i := 0
	for w in data.get("walls", []):
		var r := rect_of(w.rect)
		var kind := String(w.get("kind", "house"))
		var h := wh if kind == "house" else wh * 0.8
		_block(m, holder, r, 0.0, h, "wall", _stone_mat("brick_01" if kind == "house" else "brick_16"))
		if kind == "house":
			_roof(m, holder, r, h, String(w.get("roof", ROOF_COLORS[i % ROOF_COLORS.size()])))
		blocks.append({"rect": r, "kind": "wall", "h": h})
		i += 1
	var edges: Dictionary = data.get("edges", {})
	var et := float(edges.get("thickness", 2.0))
	var eh := float(edges.get("height", 3.5))
	for r in [Rect2(-et, -et, plan.x + 2 * et, et), Rect2(-et, plan.y, plan.x + 2 * et, et), Rect2(-et, 0, et, plan.y),
			Rect2(plan.x, 0, et, plan.y)]:
		_block(m, holder, r, 0.0, eh, "wall", _stone_mat("brick_16"))
		blocks.append({"rect": r, "kind": "wall", "h": eh, "edge": true})
	var lh := float(data.get("low_height", 1.15))
	for lw in data.get("low", []):
		var r := rect_of(lw.rect)
		_block(m, holder, r, 0.0, lh, "low", _stone_mat("brick_02"))
		blocks.append({"rect": r, "kind": "low", "h": lh})
	for pr in data.get("props", []):
		var c: Array = pr.circle
		_fountain(m, holder, Vector2(float(c[0]), float(c[1])), float(c[2]), float(pr.get("h", 0.9)))
		blocks.append({"circle": Vector3(float(c[0]), float(c[1]), float(c[2])), "kind": "low", "h": float(pr.get("h", 0.9))})
	for hg in data.get("heights", []):
		var r := rect_of(hg.rect)
		var h := float(hg.h)
		_block(m, holder, r, 0.0, h, "floor", _stone_mat("mount_01"))
		blocks.append({"rect": r, "kind": "floor", "h": h, "name": String(hg.get("name", ""))})
		if hg.has("ramp"):
			var rr := rect_of(hg.ramp.rect)
			_ramp(m, holder, rr, h, String(hg.ramp.get("up", "n")), _stone_mat("mount_01"))
			blocks.append({"rect": rr, "kind": "ramp", "h": h, "up": String(hg.ramp.get("up", "n"))})
	m.assault["blocks"] = blocks
	_grass(m, holder, data)
	_lanterns(m, holder, data)
	m._build_minimap()
	_paint_minimap(m, blocks)
	m._setup_navigation()
	_layout(m, data)


# --- relief et sol ----------------------------------------------------------------------------------

## Sol plat dans l'aire de jeu (+1 m de marge), falaises au-delà (on ne sort pas ; on voit un relief, pas un vide).
static func _heights(m: ProcMap, area: Rect2) -> void:
	var off: Vector2 = m.assault.offset
	m.heights.resize(m.n * m.n)
	for j in m.n:
		for i in m.n:
			var p := Vector2(i * ProcMap.STEP, j * ProcMap.STEP) - off
			var dx := maxf(maxf(area.position.x - p.x, p.x - area.end.x), 0.0)
			var dz := maxf(maxf(area.position.y - p.y, p.y - area.end.y), 0.0)
			var out := Vector2(dx, dz).length()
			var h := 0.0
			if out > 3.0:
				h = minf((out - 3.0) / 6.0, 1.0) * CLIFF + m._noise.get_noise_2d(p.x * 3.0, p.y * 3.0) * 1.5 * minf(out / 8.0, 1.0)
			m.heights[j * m.n + i] = h


## Carte de mélange : rues pavées (route), sites en terre battue, herbe dans les jardins et hors de l'aire de jeu.
static func _splat(m: ProcMap, data: Dictionary, area: Rect2) -> void:
	var off: Vector2 = m.assault.offset
	var sites: Array = []
	for s in data.get("sites", {}).values():
		sites.append(rect_of(s.rect))
	var grass: Array = data.get("grass", []).map(func(g): return rect_of(g.rect))
	m._splat = Image.create(m.n - 1, m.n - 1, false, Image.FORMAT_RGBA8)
	for j in m.n - 1:
		for i in m.n - 1:
			var p := Vector2((i + 0.5) * ProcMap.STEP, (j + 0.5) * ProcMap.STEP) - off
			var g2 := 0.5 + 0.5 * m._noise2.get_noise_2d(p.x * 4.0, p.y * 4.0)
			var dirt := 0.0
			var road := 0.0
			if area.grow(1.0).has_point(p):
				road = 0.75 + 0.2 * m._noise.get_noise_2d(p.x * 5.0, p.y * 5.0)
				for r in sites:
					if (r as Rect2).has_point(p):
						road = 0.15
						dirt = 0.8
				for r in grass:
					if (r as Rect2).grow(1.0).has_point(p):
						road = 0.0
						dirt = 0.1
			m._splat.set_pixel(i, j, Color(g2, dirt, road, 0.0))


# --- décor --------------------------------------------------------------------------------------------

## Matériau du décor d'Eden (shader du décor : relief tramé, trou autour du héros quand le mur le cache) sur une texture
## de pierre des cartes.
static func _stone_mat(tex: String) -> ShaderMaterial:
	if _mats.has(tex):
		return _mats[tex]
	var mat := ShaderMaterial.new()
	mat.shader = MapLoader.OBJECT_SHADER
	mat.set_shader_parameter("albedo_tex", load("res://assets/maps/textures/%s.png" % tex))
	mat.set_shader_parameter("albedo_color", Color(1, 1, 1))
	_mats[tex] = mat
	return mat


## Matériau d'une couleur ([param tex] : texture de tuiles teintée, sinon aplat).
static func _color_mat(c: Color, tex := "") -> ShaderMaterial:
	var key := c.to_html() + tex
	if _mats.has(key):
		return _mats[key]
	var mat := ShaderMaterial.new()
	mat.shader = MapLoader.OBJECT_SHADER
	if tex != "":
		mat.set_shader_parameter("albedo_tex", load("res://assets/maps/textures/%s.png" % tex))
	else:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		mat.set_shader_parameter("albedo_tex", ImageTexture.create_from_image(img))
		mat.set_shader_parameter("bump", 0.0)
	mat.set_shader_parameter("albedo_color", c)
	_mats[key] = mat
	return mat


## Pavé [param r] (plan) de [param y0] à [param y0] + [param h] : maillage (UV en mètres) et collision de sa sorte
## (wall : déplacement, vue, coups ; low : déplacement, coups ; floor : déplacement seul).
static func _block(m: ProcMap, parent: Node3D, r: Rect2, y0: float, h: float, kind: String, mat: Material) -> void:
	var c := to_world(m, r.get_center(), y0 + h * 0.5)
	var size := Vector3(r.size.x, h, r.size.y)
	var mi := MeshInstance3D.new()
	mi.mesh = box_mesh(size, 2.5)
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = c
	var body := StaticBody3D.new()
	body.name = "Assault_" + kind
	body.collision_layer = GameData.PHYS_WORLD | {"wall": SIGHT | SHOT, "low": SHOT, "floor": 0}[kind]
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	parent.add_child(body)
	body.position = c


## Pavé à UV « en mètres » (la texture se répète tous les [param tile] m au lieu de s'étirer).
static func box_mesh(size: Vector3, tile: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hs := size * 0.5
	# 6 faces : normale, axe u, axe v (dans le plan de la face)
	var faces := [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN], [Vector3.LEFT, Vector3.BACK, Vector3.DOWN],
		[Vector3.BACK, Vector3.RIGHT, Vector3.DOWN], [Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN]]
	for f in faces:
		var nrm: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var cu := (u * hs).length()
		var cv := (v * hs).length()
		var center := nrm * (nrm * hs).abs().length()
		var pts := [center - u * cu - v * cv, center + u * cu - v * cv, center + u * cu + v * cv, center - u * cu + v * cv]
		var uvs := [Vector2(0, 0), Vector2(2.0 * cu / tile, 0), Vector2(2.0 * cu / tile, 2.0 * cv / tile), Vector2(0, 2.0 * cv / tile)]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_normal(nrm)
			st.set_uv(uvs[k])
			st.add_vertex(pts[k])
	st.generate_tangents()
	return st.commit()


## Toit à deux pans d'une maison (le long de son grand côté), couleur bonbon de la DA (BIBLE § 3).
static func _roof(m: ProcMap, parent: Node3D, r: Rect2, h: float, color: String) -> void:
	# tuiles teintées de la couleur bonbon, adoucie vers la terre cuite (un toit, pas un aplat d'interface)
	var base := UiTheme.color("bonbon.%s.base" % color, Color("ffc928")).lerp(Color(0.62, 0.46, 0.4), 0.3)
	var along_x := r.size.x >= r.size.y
	var l := (r.size.x if along_x else r.size.y) + 0.6
	var w := (r.size.y if along_x else r.size.x) + 0.6
	var rise := minf(w * 0.35, 2.4)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hl := l * 0.5
	var hw := w * 0.5
	# repère local : x le long du faîte, z en travers ; deux pans + deux pignons
	var a := Vector3(-hl, 0, -hw)
	var b := Vector3(hl, 0, -hw)
	var c := Vector3(hl, 0, hw)
	var d := Vector3(-hl, 0, hw)
	var e := Vector3(-hl, rise, 0)
	var f := Vector3(hl, rise, 0)
	for tri in [[a, e, f], [a, f, b], [d, c, f], [d, f, e], [a, d, e], [b, f, c]]:
		var n: Vector3 = ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3)).normalized()
		if n.y < -0.01 or (absf(n.y) <= 0.01 and n.dot(((tri[0] as Vector3) + (tri[1] as Vector3) + (tri[2] as Vector3)) / 3.0) < 0.0):
			n = -n
		else:
			tri = [tri[0], tri[2], tri[1]]  # (Godot : face avant = sens horaire vue de dehors)
		for p in tri:
			st.set_normal(n)
			st.set_uv(Vector2((p as Vector3).x, (p as Vector3).z) * 0.5)
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _color_mat(base, "brick_02")
	parent.add_child(mi)
	mi.position = to_world(m, r.get_center(), h)
	mi.rotation.y = 0.0 if along_x else PI * 0.5


## Rampe (prisme) qui monte jusqu'à [param h] du côté [param up] (n, s, e, w) : collision exacte et maillage.
static func _ramp(m: ProcMap, parent: Node3D, r: Rect2, h: float, up: String, mat: Material) -> void:
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var hy := func(px: float, pz: float) -> float: return h * _ramp_k(px, pz, r, up)
	var pts: Array = []
	for p in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]:
		pts.append(to_world(m, p, 0.0))
	var top: Array = []
	for p in [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]:
		top.append(to_world(m, p, hy.call(p.x, p.y)))
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(pts + top)
	var body := StaticBody3D.new()
	body.name = "Assault_ramp"
	body.collision_layer = GameData.PHYS_WORLD
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[top[0], top[2], top[1]], [top[0], top[3], top[2]], [pts[0], top[0], top[1]], [pts[0], top[1], pts[1]],
			[pts[1], top[1], top[2]], [pts[1], top[2], pts[2]], [pts[2], top[2], top[3]], [pts[2], top[3], pts[3]],
			[pts[3], top[3], top[0]], [pts[3], top[0], pts[0]]]:
		var n: Vector3 = ((tri[1] as Vector3) - (tri[0] as Vector3)).cross((tri[2] as Vector3) - (tri[0] as Vector3))
		if n.length() < 0.0001:
			continue
		n = n.normalized()
		for p in tri:
			st.set_normal(n)
			st.set_uv(Vector2((p as Vector3).x + (p as Vector3).y, (p as Vector3).z) / 2.5)
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _two_sided(mat)
	parent.add_child(mi)


## Copie du matériau du décor vue des deux côtés (rampes : faces construites à la main).
static func _two_sided(mat: Material) -> Material:
	var sm := mat as ShaderMaterial
	if sm == null:
		return mat
	var key := "2s_%d" % sm.get_instance_id()
	if not _mats.has(key):
		var m2 := sm.duplicate() as ShaderMaterial
		m2.shader = MapLoader._two_sided_shader()
		_mats[key] = m2
	return _mats[key]


## Part de la hauteur d'une rampe au point (plan) : 0 en bas, 1 du côté [param up].
static func _ramp_k(px: float, pz: float, r: Rect2, up: String) -> float:
	match up:
		"n":
			return clampf((r.end.y - pz) / maxf(r.size.y, 0.01), 0.0, 1.0)
		"s":
			return clampf((pz - r.position.y) / maxf(r.size.y, 0.01), 0.0, 1.0)
		"e":
			return clampf((px - r.position.x) / maxf(r.size.x, 0.01), 0.0, 1.0)
	return clampf((r.end.x - px) / maxf(r.size.x, 0.01), 0.0, 1.0)


## Fontaine de la place : margelle (arrête les coups, pas la vue) et eau lagon.
static func _fountain(m: ProcMap, parent: Node3D, c: Vector2, r: float, h: float) -> void:
	var at := to_world(m, c, h * 0.5)
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r
	cyl.bottom_radius = r * 1.05
	cyl.height = h
	cyl.radial_segments = 24
	mi.mesh = cyl
	mi.material_override = _stone_mat("brick_02")
	parent.add_child(mi)
	mi.position = at
	var water := MeshInstance3D.new()
	var wc := CylinderMesh.new()
	wc.top_radius = r * 0.82
	wc.bottom_radius = r * 0.82
	wc.height = 0.05
	water.mesh = wc
	water.material_override = _color_mat(UiTheme.color("bonbon.lagon.base", Color("22b8f0")))
	parent.add_child(water)
	water.position = to_world(m, c, h + 0.01)
	var body := StaticBody3D.new()
	body.name = "Assault_low"
	body.collision_layer = GameData.PHYS_WORLD | SHOT
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)
	body.position = at


## Hautes herbes : touffes du biome serrées (sans collision) ; elles cachent au-delà de 3 m (AssaultVision).
static func _grass(m: ProcMap, parent: Node3D, data: Dictionary) -> void:
	var batch := {}
	var plants: Array = m._plants if not m._plants.is_empty() else PropCatalog.PLANTS
	for g in data.get("grass", []):
		var r := rect_of(g.rect)
		var k := int(r.get_area() / 1.6)
		for i in k:
			var p := Vector2(m.rng.randf_range(r.position.x, r.end.x), m.rng.randf_range(r.position.y, r.end.y))
			m._add_instance(batch, PropCatalog.pick(plants, m.rng), to_world(m, p, 0.0), false, INF, 1.6)
	m._flush_batches(batch, parent)


## Lanternes du bourg (le nom de la carte) aux noms de lieux : un poteau du décor d'Eden et une lumière chaude.
static func _lanterns(m: ProcMap, parent: Node3D, data: Dictionary) -> void:
	var batch := {}
	var n := 0
	for pl in data.get("places", []):
		if n >= 8 or String(pl.name).begins_with("Site"):
			continue
		var p := to_world(m, Vector2(float(pl.pos[0]), float(pl.pos[1])) + Vector2(1.6, 1.6), 0.0)
		if _inside_block(m, Vector2(p.x, p.z)):
			continue
		m._add_instance(batch, {"model": "uc308", "scale": [1.0, 1.0]}, p, false, 0.0)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.55)
		l.light_energy = 1.2
		l.omni_range = 9.0
		parent.add_child(l)
		l.position = p + Vector3.UP * 3.0
		n += 1
	m._flush_batches(batch, parent)


## Le point (monde, xz) est-il dans un mur, un muret ou une terrasse ?
static func _inside_block(m: ProcMap, p: Vector2) -> bool:
	var q := to_plan(m, Vector3(p.x, 0, p.y))
	for b in m.assault.get("blocks", []):
		if b.has("rect") and (b.rect as Rect2).grow(0.6).has_point(q):
			return true
	return false


## Mini-carte : les murs en encre, les murets en gris, les terrasses claires, les sites soleil.
static func _paint_minimap(m: ProcMap, blocks: Array) -> void:
	var tex: ImageTexture = m._minimap
	if tex == null:
		return
	var img := tex.get_image()
	var ppm := ProcMap.MINIMAP_RES / m.size
	var ink := UiTheme.color("encre.700", Color("2e2450"))
	var cols := {"wall": ink, "low": Color("c9bfea"), "floor": Color("ffebc8"), "ramp": Color("ffebc8")}
	for s in m.assault.data.get("sites", {}).values():
		_fill(img, m, rect_of(s.rect), ppm, Color(UiTheme.color("bonbon.soleil.base", Color("ffc928")), 0.35))
	for b in blocks:
		if b.has("rect"):
			_fill(img, m, b.rect, ppm, cols.get(String(b.kind), ink))
	tex.update(img)


static func _fill(img: Image, m: ProcMap, r: Rect2, ppm: float, c: Color) -> void:
	var a := to_world(m, r.position)
	var x0 := clampi(int(a.x * ppm), 0, img.get_width() - 1)
	var z0 := clampi(int(a.z * ppm), 0, img.get_height() - 1)
	var x1 := clampi(int((a.x + r.size.x) * ppm), 0, img.get_width() - 1)
	var z1 := clampi(int((a.z + r.size.y) * ppm), 0, img.get_height() - 1)
	for y in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, img.get_pixel(x, y).blend(c) if c.a < 1.0 else c)


# --- description pour le directeur -----------------------------------------------------------------------

static func _layout(m: ProcMap, data: Dictionary) -> void:
	var sites := {}
	for s in data.get("sites", {}):
		var sd: Dictionary = data.sites[s]
		var r := rect_of(sd.rect)
		var pl: Array = sd.get("plant", [r.get_center().x, r.get_center().y])
		var pw := to_world(m, Vector2(float(pl[0]), float(pl[1])))
		pw.y = floor_at(m, pw.x, pw.z)
		sites[s] = {"pos": pw, "radius": maxf(r.size.x, r.size.y) * 0.5, "rect": Rect2(Vector2(r.position.x + m.assault.offset.x,
			r.position.y + m.assault.offset.y), r.size)}
	var spawns := {}
	for k in data.get("spawns", {}):
		var r := rect_of(data.spawns[k].rect)
		var c := to_world(m, r.get_center())
		c.y = floor_at(m, c.x, c.z)
		spawns[k] = {"pos": c, "half": r.size * 0.5 - Vector2(1.0, 1.0)}
	var places: Array = []
	for pl in data.get("places", []):
		var p := to_world(m, Vector2(float(pl.pos[0]), float(pl.pos[1])))
		p.y = floor_at(m, p.x, p.z)
		places.append({"name": String(pl.name), "pos": p})
	var positions: Array = []
	for po in data.get("positions", []):
		var p := to_world(m, Vector2(float(po.pos[0]), float(po.pos[1])))
		p.y = floor_at(m, p.x, p.z)
		positions.append({"name": String(po.name), "pos": p, "look": Vector3(float(po.look[0]), 0, float(po.look[1])).normalized(),
			"side": String(po.get("side", "")), "site": String(po.get("site", ""))})
	var sa: Array = data.get("sanctuary", [])
	m.assault.merge({"sites": sites, "spawns": spawns, "places": places, "positions": positions,
		"sanctuary": to_world(m, Vector2(float(sa[0]), float(sa[1]))) if sa.size() >= 2 else Vector3.INF,
		"sanctuary_radius": float(sa[2]) if sa.size() >= 3 else 4.0}, true)


## Hauteur du sol praticable en (x, z) monde : terrasse ou rampe si l'on est dessus, sinon le relief.
static func floor_at(m: ProcMap, x: float, z: float) -> float:
	var q := to_plan(m, Vector3(x, 0, z))
	var y := m.height_at(x, z)
	for b in m.assault.get("blocks", []):
		if not b.has("rect") or not (b.rect as Rect2).has_point(q):
			continue
		match String(b.kind):
			"floor":
				y = maxf(y, float(b.h))
			"ramp":
				y = maxf(y, float(b.h) * _ramp_k(q.x, q.y, b.rect, String(b.up)))
	return y


## Nom du lieu le plus proche de [param p] (monde) : annonces et radar (« Ennemi aperçu · Halle »).
static func place_name(m: ProcMap, p: Vector3) -> String:
	var best := ""
	var bd := INF
	for pl in m.assault.get("places", []):
		var dd := Vector2(p.x - (pl.pos as Vector3).x, p.z - (pl.pos as Vector3).z).length()
		if dd < bd:
			bd = dd
			best = String(pl.name)
	return best
