extends Node3D
## Lot MB-B (Les Deux Voies, conception/benchmark/R_MB_B.md) : carte MobaMap. Disposition complète (bases, 8 tours, 8 camps,
## 2 fosses, buissons, rochers, arbres), symétrie en miroir, voies de 11 m et tours à leur bord, aucun lieu clé dans un
## obstacle, maillage précuit à jour (identique à une cuisson neuve, tampon de disposition), chemins de base à base en 28-32 s
## à 6,5 m/s (par chaque voie et par la jungle), tout lieu clé atteignable, rochers qui bloquent, bord infranchissable,
## buissons, relief (voies plates, lit de la rivière), mini-carte. Quitte après la synchronisation du maillage (piège T1).
## godot --headless --path game res://tests/test_mb_map.tscn

var fails := 0
var map: MobaMap


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Training.active = true  # aucune sauvegarde
	var t0 := Time.get_ticks_usec()
	map = MobaMap.new()
	map.biome = "rainbowfall"
	add_child(map)
	map.generate_moba(7)
	var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("[mb-b] génération %.0f ms ; navigation %s en %.1f ms" % [gen_ms, map.nav_source, map.nav_ms])
	_layout()
	_symmetry()
	_lanes()
	_clear_spots()
	_relief()
	await _navigation()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _layout() -> void:
	var m := map.moba
	check("2 Cœurs, 2 fontaines, 2 bases", m.cores.size() == 2 and m.fountains.size() == 2 and m.bases.size() == 2)
	check("4 tours par camp (T1 et T2 sur chaque voie)", m.towers.size() == 2 and (m.towers[0] as Array).size() == 4 and (m.towers[1] as Array).size() == 4)
	var camps := {}
	for c in m.camps:
		camps[String(c.id)] = int(camps.get(String(c.id), 0)) + 1
	check("camps : 2 Source, 2 Braise, 4 petits", int(camps.get("source", 0)) == 2 and int(camps.get("braise", 0)) == 2 and int(camps.get("petit", 0)) == 4)
	check("fosses : Gardien (Brumes, bas) et Colosse (Soleil, haut)", m.objectives.has("guardian") and m.objectives.has("colossus")
		and map.local(m.objectives.guardian).y > 0.0 and map.local(m.objectives.colossus).y < 0.0)
	check("buissons, rochers et arbres de la jungle", m.bushes.size() == MobaMap.BUSHES.size() * 2 and m.rocks.size() == MobaMap.ROCKS.size() * 2
		and m.trees.size() == MobaMap.JUNGLE_TREES.size() * 4)
	var all_in := true
	for key in ["cores", "fountains"]:
		for p in m[key]:
			all_in = all_in and map.in_area(map.local(p), 2.0)
	for side in 2:
		for tw in m.towers[side]:
			all_in = all_in and map.in_area(map.local(tw.pos), 2.0)
	for c in m.camps:
		all_in = all_in and map.in_area(map.local(c.pos), 4.0)
	check("tout dans l'aire de jeu 200 × 120 m", all_in and is_equal_approx(MobaMap.HALF.x * 2.0, 200.0) and is_equal_approx(MobaMap.HALF.y * 2.0, 120.0))
	check("bleu à gauche, rouge à droite ; fontaine derrière le Cœur", map.local(m.cores[0]).x < -70.0 and map.local(m.cores[1]).x > 70.0
		and map.local(m.fountains[0]).x < map.local(m.cores[0]).x and map.local(m.fountains[1]).x > map.local(m.cores[1]).x)


func _mirror(p: Vector3) -> Vector3:
	return map.world(Vector2(-map.local(p).x, map.local(p).y))


## Chaque élément du camp bleu a son jumeau rouge en miroir (x -> −x).
func _symmetry() -> void:
	var ok := true
	for key in ["camps", "bushes", "rocks", "trees"]:
		for e in map.moba[key]:
			var twin := _mirror(e.pos)
			var found := false
			for f in map.moba[key]:
				if Vector2(f.pos.x - twin.x, f.pos.z - twin.z).length() < 0.2:
					found = true
			ok = ok and found
	for i in 4:
		var a: Dictionary = map.moba.towers[0][i]
		var twin := _mirror(a.pos)
		var found := false
		for b in map.moba.towers[1]:
			found = found or (int(b.lane) == int(a.lane) and int(b.tier) == int(a.tier) and Vector2(b.pos.x - twin.x, b.pos.z - twin.z).length() < 0.6)
		ok = ok and found
	check("symétrie en miroir (camps, buissons, rochers, arbres, tours)", ok)
	check("voies de même longueur", absf(map.lane_len[0] - map.lane_len[1]) < 0.5)


func _lanes() -> void:
	var t1 := 0
	var edge_ok := true
	for side in 2:
		for tw in map.moba.towers[side]:
			var d := map.lane_dist(map.local(tw.pos), int(tw.lane))
			edge_ok = edge_ok and d > MobaMap.LANE_W * 0.5 and d < MobaMap.LANE_W * 0.5 + 3.0
			if int(tw.tier) == 1:
				t1 += 1
	check("tours au bord de leur voie (dehors, à moins de 3 m)", edge_ok and t1 == 4)
	var order_ok := true
	for side in 2:
		for li in 2:
			var a1 := -1.0
			var a2 := -1.0
			for tw in map.moba.towers[side]:
				if int(tw.lane) == li:
					if int(tw.tier) == 1:
						a1 = float(tw.along)
					else:
						a2 = float(tw.along)
			order_ok = order_ok and a2 > 0.0 and a1 > a2 * 2.0
	check("T2 à l'angle de la base, T1 au tiers de la voie", order_ok)
	for li in 2:
		var s := map.lane_len[li] / Player.BASE_SPEED
		print("[mb-b] %s : %.1f m de Cœur à Cœur, %.1f s" % [MobaData.LANE_NAMES[li], map.lane_len[li], s])
		check("%s : 28-32 s de Cœur à Cœur" % MobaData.LANE_NAMES[li], s >= 28.0 and s <= 32.0)
	var wp: PackedVector3Array = map.lane_wp[0][0]
	var wr: PackedVector3Array = map.lane_wp[0][1]
	check("points de voie : un tous les 4 m environ, le sens rouge est l'inverse du bleu", wp.size() > 40 and wp[0].distance_to(wr[-1]) < 0.01
		and wp[-1].distance_to(wr[0]) < 0.01)
	var mid := map.lane_point(0, 0, map.lane_len[0] * 0.5)
	check("le milieu de la voie traverse la rivière", absf(map.local(mid).x) < MobaMap.RIVER_W)
	check("avancée sur la voie (lane_progress)", absf(map.lane_progress(0, 0, mid) - map.lane_len[0] * 0.5) < 2.5
		and absf(map.lane_progress(1, 0, mid) - map.lane_len[0] * 0.5) < 2.5)


## Aucun lieu clé dans un rocher ou un arbre, aucun buisson sur une voie.
func _clear_spots() -> void:
	var spots: Array = map.moba.cores + map.moba.fountains + map.moba.objectives.values()
	for side in 2:
		for tw in map.moba.towers[side]:
			spots.append(tw.pos)
	for c in map.moba.camps:
		spots.append(c.pos)
	var bad := 0
	for p in spots:
		for o in map.moba.rocks + map.moba.trees:
			if Vector2(p.x - o.pos.x, p.z - o.pos.z).length() < float(o.radius) + 2.5:
				bad += 1
	check("aucun lieu clé dans un rocher ou un arbre (%d)" % bad, bad == 0)
	var on_lane := 0
	for o in map.moba.rocks + map.moba.trees:
		if map.lane_dist(map.local(o.pos)) < MobaMap.LANE_W * 0.5 + float(o.radius):
			on_lane += 1
	for b in map.moba.bushes:
		if map.lane_dist(map.local(b.pos)) < MobaMap.LANE_W * 0.5 + float(b.radius) * 0.5:
			on_lane += 1
	check("ni rocher, ni arbre, ni buisson sur une voie (%d)" % on_lane, on_lane == 0)
	check("buissons : bush_at dedans, rien sur la voie", map.bush_at(map.moba.bushes[0].pos) == 0 and map.bush_at(mid_lane()) == -1)


func mid_lane() -> Vector3:
	return map.lane_point(0, 1, map.lane_len[1] * 0.3)


func _relief() -> void:
	var flat := true
	for li in 2:
		for p in map.lane_wp[li][0]:
			if absf(map.local(p).x) > MobaMap.RIVER_W:
				flat = flat and absf(p.y) < 0.08
	check("voies plates hors du gué", flat)
	check("lit de la rivière plus bas que la rive", map.height_at(map.size * 0.5, map.size * 0.5) < -0.3)
	check("coteaux hors de l'aire", map.world(Vector2(0, MobaMap.HALF.y + 20.0)).y > 3.0)
	check("mini-carte dessinée", map.minimap_info().texture != null)


func _path_len(a: Vector3, b: Vector3) -> float:
	var p := map.path_between(a, b)
	if p.size() < 2 or Vector2(p[-1].x - b.x, p[-1].z - b.z).length() > 2.5:
		return INF
	var s := 0.0
	for i in p.size() - 1:
		s += p[i].distance_to(p[i + 1])
	return s


func _navigation() -> void:
	check("maillage précuit à jour, chargé tel quel", map.nav_source == "précuite")
	var fresh := map.bake_nav()
	var pre: NavigationMesh = map._region.navigation_mesh
	check("précuit identique à une cuisson neuve (%d / %d polygones)" % [pre.get_polygon_count(), fresh.get_polygon_count()],
		pre.get_polygon_count() == fresh.get_polygon_count() and pre.get_vertices().size() == fresh.get_vertices().size())
	var waited := 0
	while not map.nav_ready() and waited < 600:
		await get_tree().physics_frame
		waited += 1
	check("serveur de navigation prêt (%d images)" % waited, map.nav_ready())
	var f0: Vector3 = map.moba.fountains[0]
	var f1: Vector3 = map.moba.fountains[1]
	var direct := _path_len(f0, f1)
	print("[mb-b] fontaine à fontaine (jungle) : %.1f m, %.1f s" % [direct, direct / Player.BASE_SPEED])
	check("de base à base par la jungle : 28-32 s", direct / Player.BASE_SPEED >= 27.5 and direct / Player.BASE_SPEED <= 32.0)
	for li in 2:
		var mid := map.lane_point(0, li, map.lane_len[li] * 0.5)
		var l := _path_len(f0, mid) + _path_len(mid, f1)
		print("[mb-b] fontaine à fontaine par la %s : %.1f m, %.1f s" % [MobaData.LANE_NAMES[li], l, l / Player.BASE_SPEED])
		check("de base à base par la %s : 28-32 s" % MobaData.LANE_NAMES[li], l / Player.BASE_SPEED >= 28.0 and l / Player.BASE_SPEED <= 32.0)
	var reach := 0
	var total := 0
	var spots: Array = map.moba.objectives.values()
	for c in map.moba.camps:
		spots.append(c.pos)
	for side in 2:
		for tw in map.moba.towers[side]:
			spots.append(map.lane_point(side, int(tw.lane), float(tw.along)))
	for p in spots:
		total += 1
		if _path_len(f0, p) < INF:
			reach += 1
	check("camps, fosses et tours atteignables depuis la fontaine (%d / %d)" % [reach, total], reach == total)
	# rocher central de la jungle : le chemin le contourne
	var rock: Dictionary = map.moba.rocks[0]
	var a := (rock.pos as Vector3) + Vector3(-6, 0, 0)
	var b := (rock.pos as Vector3) + Vector3(6, 0, 0)
	var around := map.path_between(a, b)
	var inside := false
	for q in around:
		inside = inside or Vector2(q.x - rock.pos.x, q.z - rock.pos.z).length() < float(rock.radius) - 0.2
	check("un rocher bloque le passage (détour, aucun point dedans)", _path_len(a, b) > 12.4 and not inside)
	var far := map.path_between(f0, map.world(Vector2(-MobaMap.HALF.x - 12.0, -MobaMap.HALF.y - 12.0)))
	var end := map.local(far[-1]) if far.size() > 0 else Vector2.ZERO
	check("aucun chemin ne sort de l'aire (%.1f, %.1f)" % [end.x, end.y], far.size() > 0 and map.in_area(end, -0.6))
