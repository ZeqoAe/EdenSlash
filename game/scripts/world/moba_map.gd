class_name MobaMap
extends ProcMap
## Carte des Deux Voies (lot MB-B, conception/benchmark/MOBA.md § 7.4, rapport R_MB_B.md ; croquis moba_maquettes/v2_carte.svg) :
## aire de jeu de 200 × 120 m au centre d'un terrain ProcMap de 256 m fermé par des falaises boisées ; deux bases aux
## extrémités (Cœur bleu à x = −80 m, rouge à + 80 m, fontaine derrière), Voie du Soleil en haut (z < 0) et Voie des Brumes
## en bas, ≈ 196 m de Cœur à Cœur (≈ 30 s de course à 6,5 m/s), 11 m de large ; jungle entre les voies coupée par une rivière
## (gué peu profond, eau translucide) ; rochers (couvert qui bloque le passage et les tirs), buissons (cachettes, lot MB-G),
## 4 camps par moitié (Source, Braise, 2 petits), Colosse dans la rivière côté Soleil et Gardien côté Brumes.
##
## Symétrie : miroir x -> −x (chaque équipe a la Voie du Soleil en haut et le Colosse du même côté ; la rotation de l'étude
## mettrait le Colosse du côté Soleil d'une équipe et du côté Brumes de l'autre). Tout est fixe : la graine ne change que les
## petits décors (plantes, arbres hors de l'aire), jamais la navigation ni le jeu.
##
## Navigation : maillage précuit (assets/maps/moba/navmesh.res, tampon LAYOUT_VERSION) chargé tel quel ; sinon cuit d'un coup
## sur le fil principal avant toute unité (jamais en tâche de fond : un calcul non fini plante la sortie, piège T1).
## Recuire après un changement de l'aire : godot --headless --path game res://tools/moba_map_tool.tscn -- --bake
##
## Coordonnées : « locales » = centrées sur le milieu de la carte (x vers le camp rouge, z vers les Brumes) ; [method world]
## les passe au monde (ProcMap : 0 à size). [member moba] : la disposition en coordonnées du monde (lue par MobaDirector).

const MAP_SIZE := 256.0
const HALF := Vector2(100.0, 60.0)  # demi-aire de jeu (m)
## Tampon de la disposition : à augmenter à tout changement de géométrie (le maillage précuit devient périmé).
const LAYOUT_VERSION := 1
const NAV_PATH := "res://assets/maps/moba/navmesh.res"
const LANE_W := 11.0
const WP_STEP := 4.0
## Voies, du Cœur bleu au Cœur rouge (points de contrôle locaux, courbe de Catmull-Rom) : Soleil (haut), Brumes (bas).
const LANES := [
	[Vector2(-80, -6), Vector2(-74, -24), Vector2(-56, -37), Vector2(-30, -42), Vector2(0, -43), Vector2(30, -42),
		Vector2(56, -37), Vector2(74, -24), Vector2(80, -6)],
	[Vector2(-80, 6), Vector2(-74, 24), Vector2(-56, 37), Vector2(-30, 42), Vector2(0, 43), Vector2(30, 42),
		Vector2(56, 37), Vector2(74, 24), Vector2(80, 6)],
]
const CORE_X := 80.0
const FOUNTAIN_X := 90.0
const BASE_R := 13.0
const RIVER_W := 9.0
const RIVER_DEPTH := 0.6
## Camps du camp bleu (miroir pour le rouge) : Source (lagon), Braise (fraise), 2 petits.
const CAMPS := [
	{"id": "source", "at": Vector2(-50, 17)}, {"id": "braise", "at": Vector2(-50, -17)},
	{"id": "petit", "at": Vector2(-27, -23)}, {"id": "petit", "at": Vector2(-27, 23)},
]
const OBJECTIVES := {"colossus": Vector2(0, -22), "guardian": Vector2(0, 22)}
const PIT_R := 8.0
## Buissons du camp bleu (centre, rayon) : entrées de jungle et bords de rivière.
const BUSHES := [
	[Vector2(-12, -33), 3.4], [Vector2(-12, 33), 3.4], [Vector2(-38, -31), 3.0], [Vector2(-38, 31), 3.0],
	[Vector2(-16, 0), 3.2], [Vector2(-66, -20), 2.8], [Vector2(-66, 20), 2.8],
]
## Arbres de la jungle du camp bleu (centre, rayon de collision) : couvert fin, miroir en x et en z.
const JUNGLE_TREES := [[Vector2(-30, -6), 0.9], [Vector2(-46, -8), 0.9], [Vector2(-56, -27), 0.9], [Vector2(-28, -32), 0.9],
	[Vector2(-9, -14), 0.8], [Vector2(-70, -10), 0.9]]
const BUSH_PLANTS := ["ue703", "ue703_1", "ue705", "ue706", "ue707", "ue715", "ue716"]
const SMALL_PLANTS := ["ue701", "ue702", "ue703", "ue703_1", "ue705", "ue706", "ue710", "ue712"]
## Rochers du camp bleu (centre, rayon) : couvert de la jungle, loin des voies, des camps et des fosses.
const ROCKS := [
	[Vector2(-40, 0), 3.6], [Vector2(-60, -6), 2.6], [Vector2(-60, 6), 2.6], [Vector2(-22, -9), 2.4], [Vector2(-22, 9), 2.4],
	[Vector2(-36, -16), 2.0], [Vector2(-36, 16), 2.0], [Vector2(-14, -26), 2.2], [Vector2(-14, 26), 2.2],
	[Vector2(-64, -18), 2.2], [Vector2(-64, 18), 2.2], [Vector2(-48, -30), 1.8], [Vector2(-48, 30), 1.8],
]

## Disposition en coordonnées du monde : center, cores [bleu, rouge], fountains, bases [{pos, radius}], towers (par camp :
## [{lane, tier, pos}], T1 puis T2 par voie), camps [{id, side, pos}], objectives {guardian, colossus}, bushes [{pos, radius}],
## rocks [{pos, radius}], river {x0, x1} (monde), lanes [{name, len}].
var moba: Dictionary = {}
## Voies denses (un point tous les WP_STEP m) : [voie][camp] -> PackedVector3Array dans le sens de marche du camp.
var lane_wp: Array = []
var lane_perp: Array = []  # [voie][camp] -> PackedVector3Array (gauche de la marche)
var lane_cum: Array = []  # [voie][camp] -> PackedFloat32Array (distance parcourue au point)
var lane_len: Array[float] = [0.0, 0.0]
## Navigation : « précuite » (chargée), « cuite » (sur le fil principal) ; durée (ms).
var nav_source := ""
var nav_ms := 0.0
var _lane_poly: Array = []  # [voie] -> PackedVector2Array (locale, dense, bleu -> rouge)


# --- coordonnées ---------------------------------------------------------------------------------

## Point local [param l] (x, z) au sol, en coordonnées du monde.
func world(l: Vector2) -> Vector3:
	var x := size * 0.5 + l.x
	var z := size * 0.5 + l.y
	return Vector3(x, height_at(x, z), z)


func local(p: Vector3) -> Vector2:
	return Vector2(p.x - size * 0.5, p.z - size * 0.5)


## Le point local [param l] est dans l'aire de jeu (marge [param margin] m).
func in_area(l: Vector2, margin := 0.0) -> bool:
	return absf(l.x) <= HALF.x - margin and absf(l.y) <= HALF.y - margin


## Distance (m) du point local [param l] à l'axe de la voie la plus proche ([param lane] >= 0 : de cette voie).
func lane_dist(l: Vector2, lane := -1) -> float:
	var best := INF
	for li in _lane_poly.size():
		if lane >= 0 and li != lane:
			continue
		var pts: PackedVector2Array = _lane_poly[li]
		for i in pts.size() - 1:
			best = minf(best, Geometry2D.get_closest_point_to_segment(l, pts[i], pts[i + 1]).distance_to(l))
	return best


## Buisson qui contient [param p] (monde) : son indice, -1 sinon (lot MB-G : cachettes).
func bush_at(p: Vector3) -> int:
	var bs: Array = moba.get("bushes", [])
	for i in bs.size():
		var b: Dictionary = bs[i]
		if Vector2(p.x - b.pos.x, p.z - b.pos.z).length() <= float(b.radius):
			return i
	return -1


# --- génération ----------------------------------------------------------------------------------

func generate_moba(seed_value: int) -> void:
	_setup(biome, MAP_SIZE, seed_value)
	map_id = "moba"
	_build_lane_polys()
	_build_moba_heights()
	_paint_moba_splat()
	_build_terrain()
	_build_layout()
	_build_moba_decor()
	_build_walls()
	_build_lanes()
	start = moba.fountains[0]
	_build_minimap()
	_setup_navigation()


## Voies locales denses (Catmull-Rom, un point par mètre).
func _build_lane_polys() -> void:
	_lane_poly = []
	for ctrl in LANES:
		var pts := PackedVector2Array()
		var c: Array = ctrl
		for i in c.size() - 1:
			var p0: Vector2 = c[maxi(i - 1, 0)]
			var p1: Vector2 = c[i]
			var p2: Vector2 = c[i + 1]
			var p3: Vector2 = c[mini(i + 2, c.size() - 1)]
			var steps := maxi(2, ceili(p1.distance_to(p2)))
			for k in steps:
				var t := float(k) / steps
				var t2 := t * t
				var t3 := t2 * t
				pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
		pts.append(c[-1])
		_lane_poly.append(pts)


## Masque d'aplanissement autour des voies et des bases (1 = plat).
func _flat_mask(l: Vector2) -> float:
	var f := 1.0 - smoothstep(LANE_W * 0.5, LANE_W * 0.5 + 4.0, lane_dist(l))
	for sx in [-1.0, 1.0]:
		f = maxf(f, 1.0 - smoothstep(BASE_R, BASE_R + 6.0, l.distance_to(Vector2(sx * (CORE_X + 2.0), 0.0))))
	return f


func _build_moba_heights() -> void:
	heights.resize(n * n)
	for j in n:
		for i in n:
			var l := Vector2(i * STEP - size * 0.5, j * STEP - size * 0.5)
			var out_x := absf(l.x) - HALF.x
			var out_z := absf(l.y) - HALF.y
			var out := Vector2(maxf(out_x, 0.0), maxf(out_z, 0.0)).length() + minf(maxf(out_x, out_z), 0.0)
			var h := 0.0
			if out > -1.0:
				# coteaux boisés autour de l'aire (les murs invisibles bloquent ; pas de paroi noire à l'écran)
				var d := out + 1.0
				h = 5.0 * smoothstep(0.0, 9.0, d) + 5.0 * smoothstep(9.0, 30.0, d) \
					+ _noise.get_noise_2d(i * 2.0, j * 2.0) * 2.5 * smoothstep(3.0, 14.0, d)
			else:
				var bump := 0.35 * _noise.get_noise_2d(i * 3.0, j * 3.0) + 0.15 * _noise2.get_noise_2d(i * 5.0, j * 5.0)
				h = bump * (1.0 - _flat_mask(l))
				# rivière : un lit peu profond (gué partout praticable)
				h -= RIVER_DEPTH * (1.0 - smoothstep(RIVER_W * 0.5 - 1.0, RIVER_W * 0.5 + 2.5, absf(l.x))) * (1.0 - smoothstep(HALF.y - 6.0, HALF.y, absf(l.y)))
				# fosses du Colosse et du Gardien : à plat dans le lit
				for k in OBJECTIVES:
					var o: Vector2 = OBJECTIVES[k]
					var w := 1.0 - smoothstep(PIT_R, PIT_R + 3.0, l.distance_to(o))
					h = lerpf(h, -RIVER_DEPTH * 0.7, w)
			heights[j * n + i] = h


func _paint_moba_splat() -> void:
	_splat = Image.create(n - 1, n - 1, false, Image.FORMAT_RGBA8)
	for j in n - 1:
		for i in n - 1:
			var l := Vector2(i * STEP - size * 0.5, j * STEP - size * 0.5)
			var g2 := smoothstep(0.0, 0.35, _noise2.get_noise_2d(i * 1.0, j * 1.0))
			var ld := lane_dist(l)
			var road := 1.0 - smoothstep(LANE_W * 0.32, LANE_W * 0.5, ld)
			var dirt := (1.0 - smoothstep(LANE_W * 0.45, LANE_W * 0.5 + 2.5, ld)) * 0.8
			if in_area(l, 2.0):
				dirt = maxf(dirt, 0.75 * (1.0 - smoothstep(RIVER_W * 0.5 - 1.0, RIVER_W * 0.5 + 1.5, absf(l.x))))
			for sx in [-1.0, 1.0]:
				var bd := l.distance_to(Vector2(sx * (CORE_X + 2.0), 0.0))
				road = maxf(road, 1.0 - smoothstep(BASE_R - 4.0, BASE_R - 1.0, bd))
				dirt = maxf(dirt, 0.8 * (1.0 - smoothstep(BASE_R, BASE_R + 3.0, bd)))
			for c in CAMPS:
				var ca: Vector2 = c.at
				for cp in [ca, Vector2(-ca.x, ca.y)]:
					dirt = maxf(dirt, 0.6 * (1.0 - smoothstep(3.5, 6.5, l.distance_to(cp))))
			if not in_area(l, -1.0):
				dirt = maxf(dirt, 0.3)
			_splat.set_pixel(i, j, Color(g2, dirt, road, 0.0))


## Disposition (monde) : structures, camps, objectifs, buissons, rochers.
func _build_layout() -> void:
	moba = {"center": world(Vector2.ZERO), "cores": [], "fountains": [], "bases": [], "towers": [[], []], "camps": [],
		"objectives": {}, "bushes": [], "rocks": [], "trees": [], "lanes": [],
		"river": {"x0": size * 0.5 - RIVER_W * 0.5, "x1": size * 0.5 + RIVER_W * 0.5}, "layout": LAYOUT_VERSION}
	for side in 2:
		var sx := -1.0 if side == 0 else 1.0
		moba.cores.append(world(Vector2(sx * CORE_X, 0)))
		moba.fountains.append(world(Vector2(sx * FOUNTAIN_X, 0)))
		moba.bases.append({"pos": world(Vector2(sx * (CORE_X + 2.0), 0)), "radius": BASE_R})
	for c in CAMPS:
		for side in 2:
			var a: Vector2 = c.at
			moba.camps.append({"id": String(c.id), "side": side, "pos": world(Vector2(a.x if side == 0 else -a.x, a.y))})
	for k in OBJECTIVES:
		moba.objectives[k] = world(OBJECTIVES[k])
	for b in BUSHES:
		for side in 2:
			var a: Vector2 = b[0]
			moba.bushes.append({"pos": world(Vector2(a.x if side == 0 else -a.x, a.y)), "radius": float(b[1])})
	for r in ROCKS:
		for side in 2:
			var a: Vector2 = r[0]
			moba.rocks.append({"pos": world(Vector2(a.x if side == 0 else -a.x, a.y)), "radius": float(r[1])})
	moba["trees"] = []
	for tr in JUNGLE_TREES:
		var a: Vector2 = tr[0]
		for q in [a, Vector2(a.x, -a.y), Vector2(-a.x, a.y), Vector2(-a.x, -a.y)]:
			moba.trees.append({"pos": world(q), "radius": float(tr[1])})


## Décor : rochers (collisions), buissons, arbres des falaises, bases (sol teinté, bannières, torches), rivière, fosses.
func _build_moba_decor() -> void:
	var props := Node3D.new()
	props.name = "Decor"
	add_child(props)
	var batch := {}
	# rochers du biome (ud00x), sans les racines et troncs couchés (ud1xx, ud3xx)
	var rocks: Array = _rocks.filter(func(pp): return String(pp.model).begins_with("ud00"))
	if rocks.is_empty():
		rocks = PropCatalog.ROCKS.slice(0, 6)
	for r in moba.rocks:
		var prop: Dictionary = PropCatalog.pick(rocks, rng)
		var col := maxf(float(prop.get("col", 3.0)), 0.5)
		var s_mid := (float(prop.scale[0]) + float(prop.scale[1])) * 0.5
		_add_instance(batch, prop, r.pos - Vector3.UP * 0.3, false, INF, float(r.radius) * 1.15 / (col * s_mid))
		_add_collider(r.pos, float(r.radius), 6.0)
		_stamp_shadow(Vector2(r.pos.x, r.pos.z), float(r.radius) * 1.8)
	# buissons : touffes serrées de grandes plantes (cachettes du lot MB-G), sans collision
	var leafy: Array = PropCatalog.PLANTS.filter(func(pp): return String(pp.model) in BUSH_PLANTS)
	for b in moba.bushes:
		var c: Vector3 = b.pos
		var rad := float(b.radius)
		for k in 22:
			var a := TAU * k / 22.0 + rng.randf() * 0.5
			var d := rad * sqrt(rng.randf()) * 0.9
			var p := Vector3(c.x + cos(a) * d, 0, c.z + sin(a) * d)
			p.y = height_at(p.x, p.z)
			_add_instance(batch, PropCatalog.pick(leafy, rng), p, false, INF, 2.1)
	# arbres de la jungle (couvert, collisions) aux places fixes ; arbres des coteaux autour de l'aire (cadre)
	var slim: Array = PropCatalog.TREES.filter(func(pp): return String(pp.model) == "ue302")  # (ue305, ue308_1 : troncs couchés)
	for t in moba.trees:
		_add_instance(batch, PropCatalog.pick(slim, rng), (t.pos as Vector3) - Vector3.UP * 0.1, false, INF, 1.2)
		_add_collider(t.pos, float(t.radius), 6.0)
		_stamp_shadow(Vector2(t.pos.x, t.pos.z), 3.0)
	var trees: Array = _trees if not _trees.is_empty() else PropCatalog.TREES
	var placed := 0
	var tries := 0
	while placed < 220 and tries < 6000:
		tries += 1
		var p := Vector2(rng.randf_range(-size * 0.5 + 4.0, size * 0.5 - 4.0), rng.randf_range(-size * 0.5 + 4.0, size * 0.5 - 4.0))
		if in_area(p, -4.0) or not in_area(p, -34.0):
			continue
		_add_instance(batch, PropCatalog.pick(trees, rng), world(p) - Vector3.UP * 0.2, false)
		placed += 1
	# plantes éparses dans la jungle (hors voies, rivière, bases) : fleurs et herbes basses
	var small: Array = PropCatalog.PLANTS.filter(func(pp): return String(pp.model) in SMALL_PLANTS)
	for k in 140:
		var p := Vector2(rng.randf_range(-HALF.x + 4.0, HALF.x - 4.0), rng.randf_range(-HALF.y + 4.0, HALF.y - 4.0))
		if lane_dist(p) < LANE_W * 0.5 + 1.5 or absf(p.x) < RIVER_W * 0.5 + 1.0 or absf(p.x) > CORE_X - BASE_R:
			continue
		_add_instance(batch, PropCatalog.pick(small, rng), world(p), false)
	_flush_batches(batch, props)
	# bases : sol légèrement teinté et liseré de l'équipe (couleur + motif : rond pour Azur, carré pour Braise), bannières, torches
	for side in 2:
		var base: Dictionary = moba.bases[side]
		var col := TeamMatch.color(side)
		var segs := 48 if side == 0 else 4
		for layer in 2:
			var mi := MeshInstance3D.new()
			if layer == 0:
				var cm := CylinderMesh.new()
				cm.top_radius = BASE_R - 1.0
				cm.bottom_radius = BASE_R - 1.0
				cm.height = 0.04
				cm.radial_segments = segs
				mi.mesh = cm
				mi.material_override = _flat_mat(Color(col, 0.1))
			else:
				var tm := TorusMesh.new()
				tm.inner_radius = BASE_R - 1.5
				tm.outer_radius = BASE_R - 0.8
				tm.ring_segments = segs
				tm.rings = segs
				mi.mesh = tm
				mi.scale = Vector3(1.0, 0.08, 1.0)
				mi.material_override = _flat_mat(Color(col, 0.75))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			props.add_child(mi)
			mi.global_position = (base.pos as Vector3) + Vector3.UP * (0.06 + 0.02 * layer)
			if side == 1:
				mi.rotation.y = PI * 0.25
		var sx := -1.0 if side == 0 else 1.0
		for k in 4:
			var a := (k - 1.5) * 0.62  # éventail tourné vers le centre de la carte
			var fp := local(base.pos) + Vector2(cos(a) * -sx, sin(a)) * (BASE_R + 1.5)
			_banner(props, world(fp), col)
		for zz in [-1.0, 1.0]:
			_torch(world(Vector2(sx * (CORE_X - BASE_R + 2.0), zz * 5.5)))
	# rivière : eau claire translucide sur le lit et les bassins des deux fosses, un seul maillage (pas de double transparence)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(UiTheme.color("bonbon.lagon.clair", Color("8fe0ff")), 0.34)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.1
	wm.metallic_specular = 0.9
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED  # (sens des triangles de l'union : visible des deux côtés)
	var water := MeshInstance3D.new()
	water.mesh = _water_mesh()
	water.material_override = wm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props.add_child(water)
	# fosses des objectifs : anneau de pierres basses (sans collision), teinte de l'objectif
	for k in moba.objectives:
		var o: Vector3 = moba.objectives[k]
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = PIT_R - 0.35
		tm.outer_radius = PIT_R
		tm.rings = 48
		ring.mesh = tm
		var key := String(MobaData.OBJECTIVES[k].color)
		ring.material_override = _flat_mat(Color(UiTheme.color("bonbon.%s.base" % key), 0.6))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		props.add_child(ring)
		ring.global_position = o + Vector3.UP * 0.05
		ring.scale = Vector3(1.0, 0.15, 1.0)


## Eau : le lit de la rivière (aire de jeu) et les bassins ronds des deux fosses, en un seul polygone (union) triangulé.
func _water_mesh() -> ArrayMesh:
	var y := -RIVER_DEPTH * 0.3
	var hw := RIVER_W * 0.5 + 0.8
	var shape := PackedVector2Array([Vector2(-hw, -HALF.y), Vector2(hw, -HALF.y), Vector2(hw, HALF.y), Vector2(-hw, HALF.y)])
	for k in OBJECTIVES:
		var circle := PackedVector2Array()
		var o: Vector2 = OBJECTIVES[k]
		for i in 48:
			var a := TAU * i / 48.0
			circle.append(o + Vector2(cos(a), sin(a)) * (PIT_R + 0.6))
		var merged := Geometry2D.merge_polygons(shape, circle)
		if not merged.is_empty():
			shape = merged[0]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var tri := Geometry2D.triangulate_polygon(shape)
	for idx in tri:
		var q: Vector2 = shape[idx]
		st.add_vertex(Vector3(size * 0.5 + q.x, y, size * 0.5 + q.y))
	return st.commit()


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if c.a < 0.99 else BaseMaterial3D.TRANSPARENCY_DISABLED
	m.albedo_color = c
	return m


## Bannière d'équipe : mât d'encre, étoffe de la couleur de l'équipe.
func _banner(parent: Node3D, at: Vector3, col: Color) -> void:
	var pole := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.08
	cy.bottom_radius = 0.1
	cy.height = 4.2
	pole.mesh = cy
	pole.material_override = _flat_mat(UiTheme.color("encre.700", Color("221a3a")))
	parent.add_child(pole)
	pole.global_position = at + Vector3.UP * 2.1
	var cloth := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.8)
	cloth.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.9
	cloth.material_override = m
	parent.add_child(cloth)
	cloth.global_position = at + Vector3(0.7, 3.2, 0)


## Murs invisibles au bord de l'aire (les falaises suffisent à l'œil ; les murs empêchent de grimper au saut).
func _build_walls() -> void:
	var c := Vector3(size * 0.5, 0, size * 0.5)
	for sx in [-1.0, 1.0]:
		_add_box_collider(c + Vector3(sx * (HALF.x + 2.0), -2.0, 0), Vector3(2.0, 12.0, HALF.y + 4.0), 0.0)
		_add_box_collider(c + Vector3(0, -2.0, sx * (HALF.y + 2.0)), Vector3(HALF.x + 4.0, 12.0, 2.0), 0.0)


## Voies denses du monde par camp (sens de marche), perpendiculaires et longueurs cumulées.
func _build_lanes() -> void:
	lane_wp = []
	lane_perp = []
	lane_cum = []
	for li in 2:
		var src: PackedVector2Array = _lane_poly[li]
		var dense := PackedVector3Array()
		var acc := 0.0
		dense.append(world(src[0]))
		for i in range(1, src.size()):
			acc += src[i].distance_to(src[i - 1])
			if acc >= WP_STEP or i == src.size() - 1:
				dense.append(world(src[i]))
				acc = 0.0
		var per_side := []
		var perp_side := []
		var cum_side := []
		for side in 2:
			var wp := dense.duplicate()
			if side == 1:
				wp.reverse()
			var perp := PackedVector3Array()
			var cum := PackedFloat32Array()
			var d := 0.0
			for i in wp.size():
				if i > 0:
					var a := wp[i - 1]
					var b := wp[i]
					d += Vector2(b.x - a.x, b.z - a.z).length()
				cum.append(d)
				var t := wp[mini(i + 1, wp.size() - 1)] - wp[maxi(i - 1, 0)]
				t.y = 0.0
				perp.append(t.normalized().cross(Vector3.UP))
			per_side.append(wp)
			perp_side.append(perp)
			cum_side.append(cum)
		lane_wp.append(per_side)
		lane_perp.append(perp_side)
		lane_cum.append(cum_side)
		lane_len[li] = (cum_side[0] as PackedFloat32Array)[-1]
		moba.lanes.append({"name": MobaData.LANE_NAMES[li], "len": lane_len[li]})
	# tours : T1 au tiers de la voie, T2 à l'angle de la base, sur le bord extérieur de la voie
	for side in 2:
		for li in 2:
			for tier in [1, 2]:
				var f: float = MobaData.TOWER_AT[1] if tier == 1 else MobaData.TOWER_AT[0]
				var d: float = f * lane_len[li]
				var p := lane_point(side, li, d)
				var perp: Vector3 = lane_perp[li][side][lane_index(side, li, d)]
				var outward := 1.0 if (li == 0) == (side == 0) else -1.0
				var tp := p + perp * (LANE_W * 0.5 + 1.0) * outward
				tp.y = height_at(tp.x, tp.z)
				moba.towers[side].append({"lane": li, "tier": tier, "pos": tp, "along": d})


## Point de la voie [param li] à [param dist] m de la base du camp [param side].
func lane_point(side: int, li: int, dist: float) -> Vector3:
	var wp: PackedVector3Array = lane_wp[li][side]
	var cum: PackedFloat32Array = lane_cum[li][side]
	dist = clampf(dist, 0.0, cum[-1])
	var i := cum.bsearch(dist)
	if i <= 0:
		return wp[0]
	var u := (dist - cum[i - 1]) / maxf(cum[i] - cum[i - 1], 0.001)
	return wp[i - 1].lerp(wp[i], u)


## Indice du point de passage de la voie [param li] (sens du camp [param side]) à [param dist] m.
func lane_index(side: int, li: int, dist: float) -> int:
	return clampi((lane_cum[li][side] as PackedFloat32Array).bsearch(dist), 1, (lane_wp[li][side] as PackedVector3Array).size() - 1)


## Avancée (m depuis la base de [param side]) du point de la voie [param li] le plus proche de [param p].
func lane_progress(side: int, li: int, p: Vector3) -> float:
	var wp: PackedVector3Array = lane_wp[li][side]
	var cum: PackedFloat32Array = lane_cum[li][side]
	var best := INF
	var at := 0.0
	for i in wp.size() - 1:
		var a := Vector2(wp[i].x, wp[i].z)
		var b := Vector2(wp[i + 1].x, wp[i + 1].z)
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x, p.z), a, b)
		var dd := q.distance_squared_to(Vector2(p.x, p.z))
		if dd < best:
			best = dd
			at = cum[i] + q.distance_to(a)
	return at


# --- navigation -----------------------------------------------------------------------------------

## Réglages du maillage (une seule source : la cuisson et le précuit doivent être identiques).
static func nav_settings() -> NavigationMesh:
	var nav := MapLoader.make_navmesh_settings()
	nav.cell_size = 0.5
	nav.cell_height = 0.25
	nav.agent_radius = 0.5
	nav.agent_max_slope = 40.0
	nav.filter_baking_aabb = AABB(Vector3(MAP_SIZE * 0.5 - HALF.x - 4.0, -10.0, MAP_SIZE * 0.5 - HALF.y - 4.0),
		Vector3(HALF.x * 2.0 + 8.0, 40.0, HALF.y * 2.0 + 8.0))
	return nav


## Maillage précuit s'il est à jour (tampon LAYOUT_VERSION), sinon cuisson d'un coup sur le fil principal.
func _setup_navigation() -> void:
	var t0 := Time.get_ticks_usec()
	_region = NavigationRegion3D.new()
	add_child(_region)
	var nav: NavigationMesh = null
	if ResourceLoader.exists(NAV_PATH):
		var pre: Variant = load(NAV_PATH)
		if pre is NavigationMesh and int((pre as NavigationMesh).get_meta("layout", -1)) == LAYOUT_VERSION:
			nav = pre
			nav_source = "précuite"
	if nav == null:
		nav = bake_nav()
		nav_source = "cuite"
		if ResourceLoader.exists(NAV_PATH):
			push_warning("MobaMap : maillage précuit périmé (LAYOUT_VERSION %d) : recuire avec tools/moba_map_tool.tscn -- --bake" % LAYOUT_VERSION)
	var nav_map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(nav_map, nav.cell_size)
	NavigationServer3D.map_set_cell_height(nav_map, nav.cell_height)
	_region.navigation_mesh = nav
	nav_ms = (Time.get_ticks_usec() - t0) / 1000.0


## Le serveur de navigation a pris le maillage (quelques images après la génération : synchronisation du serveur) : les
## chemins répondent. Un test ou le directeur attend ceci avant de demander un chemin (et avant de quitter : piège T1).
func nav_ready() -> bool:
	if _region == null or _region.navigation_mesh == null or not is_inside_tree():
		return false
	var nm := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(nm) == 0:
		return false
	var f: Vector3 = moba.fountains[0]
	return NavigationServer3D.map_get_closest_point(nm, f).distance_to(f) < 2.5


## Cuisson du maillage sur le fil principal (bloquante, quelques centaines de ms) ; tampon de la disposition posé.
func bake_nav() -> NavigationMesh:
	var nav := nav_settings()
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, src, self)
	NavigationServer3D.bake_from_source_geometry_data(nav, src)
	nav.set_meta("layout", LAYOUT_VERSION)
	return nav


# --- mini-carte -----------------------------------------------------------------------------------

## Mini-carte : celle de ProcMap (relief, voies), plus la rivière et le sol des bases aux couleurs des équipes.
func _build_minimap() -> void:
	super._build_minimap()
	var img := _minimap.get_image()
	var k := size / MINIMAP_RES
	var water := UiTheme.color("bonbon.lagon.base", Color("2fc3ff"))
	for y in MINIMAP_RES:
		for x in MINIMAP_RES:
			var l := Vector2(x * k - size * 0.5, y * k - size * 0.5)
			var c := img.get_pixel(x, y)
			if absf(l.x) < RIVER_W * 0.5 and in_area(l):
				c = c.lerp(water, 0.55)
			for side in 2:
				var bc := Vector2((-1.0 if side == 0 else 1.0) * (CORE_X + 2.0), 0.0)
				if l.distance_to(bc) < BASE_R:
					c = c.lerp(TeamMatch.color(side), 0.35)
			if not in_area(l, -2.0):
				c = c.darkened(0.35)
			img.set_pixel(x, y, c)
	_minimap = ImageTexture.create_from_image(img)
