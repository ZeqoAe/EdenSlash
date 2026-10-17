extends Node
## Lot TAC-1 : format de carte de L'Assaut et carte « Le Bourg aux lanternes » (data/assault_maps/bourg.json, AssaultMap,
## ProcMap.generate_assault). Données complètes ; carte construite (murs, murets, terrasses, rampes, fontaine, herbes) ;
## couches de physique (un mur arrête vue et coups, un muret les coups seulement, le relief ni l'un ni l'autre) ; hauteurs
## praticables ; navigation cuite AVANT la fin (piège T1) ; trajets mesurés sur le maillage (départs -> sites, rotation)
## contre le plan masse ; lieux nommés et postes atteignables ; partie réelle sur le Bourg (sites et départs du directeur).
## godot --headless --path game res://tests/test_tac1.tscn

var fails := 0
const SPEED := 6.5  # m/s (Player.BASE_SPEED, temps du plan masse)


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_data()
	await _map()
	await _world()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _data() -> void:
	var d := AssaultMap.load_data("bourg")
	check("bourg.json lu : nom, taille 84 × 100", String(d.get("name", "")) == "Le Bourg aux lanternes"
		and int(d.size[0]) == 84 and int(d.size[1]) == 100)
	check("deux sites A et B, deux départs", (d.sites as Dictionary).has("A") and (d.sites as Dictionary).has("B")
		and (d.spawns as Dictionary).has("attack") and (d.spawns as Dictionary).has("defense"))
	check("au moins 12 lieux nommés (%d)" % (d.places as Array).size(), (d.places as Array).size() >= 12)
	check("murs pleins, murets, terrasses avec rampe, herbes", (d.walls as Array).size() >= 10 and (d.low as Array).size() >= 8
		and (d.heights as Array).all(func(h): return h.has("ramp")) and (d.grass as Array).size() >= 2)
	check("postes de l'IA pour les deux côtés", (d.positions as Array).any(func(p): return p.side == "defense")
		and (d.positions as Array).any(func(p): return p.side == "attack"))
	var bad: Array = []
	for pl in d.places:
		var p := Vector2(float(pl.pos[0]), float(pl.pos[1]))
		for w in d.walls:
			if AssaultMap.rect_of(w.rect).has_point(p):
				bad.append(pl.name)
	check("aucun lieu nommé dans un mur %s" % str(bad), bad.is_empty())
	for s in ["A", "B"]:
		var pl: Array = d.sites[s].plant
		var p := Vector2(float(pl[0]), float(pl[1]))
		check("site %s : point de pose dans le site et hors des murs" % s, AssaultMap.rect_of(d.sites[s].rect).has_point(p)
			and (d.walls + d.low).all(func(w): return not AssaultMap.rect_of(w.rect).grow(0.8).has_point(p)))
	check("ids des cartes", "bourg" in AssaultMap.IDS)


var _m: ProcMap


func _map() -> void:
	var root := Node3D.new()
	add_child(root)
	_m = ProcMap.new()
	_m.biome = "limestone"
	root.add_child(_m)
	var t0 := Time.get_ticks_msec()
	_m.generate_assault("bourg")
	print("[tac1] carte construite en %d ms" % (Time.get_ticks_msec() - t0))
	check("description de la carte : sites, départs, lieux, postes", _m.assault.sites.size() == 2 and _m.assault.spawns.size() == 2
		and _m.assault.places.size() >= 12 and not _m.assault.positions.is_empty())
	check("carré du monde : aire de jeu centrée", _m.size >= 100.0 + 2.0 * AssaultMap.MARGIN - 0.01)
	await _until(func(): return _m._region.navigation_mesh != null, 3600)
	check("navigation cuite (piège T1)", _m._region.navigation_mesh != null)
	for _i in 4:
		await get_tree().physics_frame
	var space := _m.get_world_3d().direct_space_state
	var w := func(x: float, z: float, y: float) -> Vector3: return AssaultMap.to_world(_m, Vector2(x, z), y)
	# mur plein : la halle ouest (30-40, 26-36) ; muret : (34-39, 52-53,2) ; rue dégagée : x = 42
	check("un mur plein arrête la vue", not _ray(space, w.call(25.0, 31.0, 1.5), w.call(45.0, 31.0, 1.5), AssaultMap.SIGHT).is_empty())
	check("un mur plein arrête les coups", not _ray(space, w.call(25.0, 31.0, 1.0), w.call(45.0, 31.0, 1.0), AssaultMap.SHOT).is_empty())
	check("un muret n'arrête pas la vue", _ray(space, w.call(36.5, 49.0, 1.5), w.call(36.5, 57.0, 1.5), AssaultMap.SIGHT).is_empty())
	check("un muret arrête les coups au sol", not _ray(space, w.call(36.5, 49.0, 1.0), w.call(36.5, 57.0, 1.0), AssaultMap.SHOT).is_empty())
	check("depuis 3 m de haut, on tire par-dessus un muret", _ray(space, w.call(36.5, 44.0, 4.0), w.call(36.5, 57.0, 1.0), AssaultMap.SHOT).is_empty())
	# (à 1,8 m du centre : la margelle, pas la statue du milieu, qui coupe aussi la vue)
	check("la fontaine arrête les coups, pas la vue", not _ray(space, w.call(38.0, 61.8, 0.6), w.call(46.0, 61.8, 0.6), AssaultMap.SHOT).is_empty()
		and _ray(space, w.call(38.0, 61.8, 1.5), w.call(46.0, 61.8, 1.5), AssaultMap.SIGHT).is_empty())
	check("la statue de la fontaine coupe la vue de l'axe nord-sud", not _ray(space, w.call(42.0, 40.0, 1.5), w.call(42.0, 80.0, 1.5), AssaultMap.SIGHT).is_empty())
	check("le relief n'arrête ni la vue ni les coups (couches à part)", _ray(space, w.call(42.0, 50.0, 1.0), w.call(42.0, 44.0, 1.0),
		AssaultMap.SIGHT | AssaultMap.SHOT).is_empty())
	var tp: Vector3 = w.call(7.5, 13.5, 0.0)
	var rp: Vector3 = w.call(17.0, 12.0, 0.0)
	check("terrasse du beffroi à +3 m, rampe à mi-hauteur (%.2f / %.2f)" % [_m.floor_at(tp.x, tp.z), _m.floor_at(rp.x, rp.z)],
		is_equal_approx(_m.floor_at(tp.x, tp.z), 3.0) and absf(_m.floor_at(rp.x, rp.z) - 1.5) < 0.05)
	# trajets du maillage contre le plan masse (temps à 6,5 m/s)
	var att: Vector3 = _m.assault.spawns.attack.pos
	var def: Vector3 = _m.assault.spawns.defense.pos
	var a: Vector3 = _m.assault.sites.A.pos
	var b: Vector3 = _m.assault.sites.B.pos
	var t := {"att_A": _secs(att, a), "att_B": _secs(att, b), "def_A": _secs(def, a), "def_B": _secs(def, b), "rot_AB": _secs(a, b)}
	print("[tac1] trajets (s) : %s" % str(t))
	var plan: Dictionary = AssaultMap.load_data("bourg").routes
	for k in t:
		var want := float(plan[k][2])
		check("trajet %s : %.1f s (plan %.1f s, ±50 %%)" % [k, float(t[k]), want], float(t[k]) > 0.0 and absf(float(t[k]) - want) <= want * 0.5)
	for s in ["A", "B"]:
		var gap := float(t["att_" + s]) - float(t["def_" + s])
		check("site %s : la Défense arrive %.1f s avant l'Attaque (règle du plan : 6 à 9 s, toléré 4 à 11)" % [s, gap], gap >= 4.0 and gap <= 11.0)
	var top := _m.path_between(att, w.call(7.5, 13.5, 3.0))
	check("terrasse atteinte par sa rampe (fin du trajet à %.1f m de haut)" % (top[-1].y if not top.is_empty() else -1.0),
		not top.is_empty() and top[-1].y > 2.5)
	var unreachable: Array = []
	for pl in _m.assault.places + _m.assault.positions:
		var p := _m.path_between(att, pl.pos)
		if p.is_empty() or Vector2(p[-1].x - pl.pos.x, p[-1].z - pl.pos.z).length() > 2.0:
			unreachable.append(pl.name)
	check("lieux nommés et postes atteignables depuis le départ de l'Attaque %s" % str(unreachable), unreachable.is_empty())
	# plus longues vues dégagées (relevé, pas une règle : la rue centrale passe sous la halle)
	var longest := 0.0
	for z in range(4, 100, 6):
		for x in range(4, 84, 6):
			for ang in 8:
				var dir := Vector2.from_angle(TAU * ang / 8.0)
				var p0: Vector3 = w.call(float(x), float(z), 1.5)
				var hit := _ray(space, p0, p0 + Vector3(dir.x, 0, dir.y) * 120.0, AssaultMap.SIGHT)
				if not hit.is_empty():
					longest = maxf(longest, (hit.position as Vector3).distance_to(p0))
	print("[tac1] plus longue vue dégagée relevée : %.0f m" % longest)
	var img: Image = _m._minimap.get_image()
	var wc: Vector3 = w.call(35.0, 31.0, 0.0)
	var px := img.get_pixelv(Vector2i(int(wc.x * ProcMap.MINIMAP_RES / _m.size), int(wc.z * ProcMap.MINIMAP_RES / _m.size)))
	check("mini-carte : les murs en encre", px.get_luminance() < 0.3)
	root.queue_free()
	await get_tree().process_frame


func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, mask: int) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(a, b, mask))


## Temps (s, à 6,5 m/s) du trajet de [param a] à [param b] sur le maillage ; -1 si le trajet n'arrive pas.
func _secs(a: Vector3, b: Vector3) -> float:
	var p := _m.path_between(a, b)
	if p.size() < 2 or Vector2(p[-1].x - b.x, p[-1].z - b.z).length() > 2.0:
		return -1.0
	var l := 0.0
	for i in p.size() - 1:
		l += Vector2(p[i + 1].x - p[i].x, p[i + 1].z - p[i].z).length()
	return l / SPEED


func _world() -> void:
	Profile.selected_class = "warrior"
	Assault.launch("warrior", {"map": "bourg", "watch": true, "seed": 77, "speed": 3.0, "win": 1, "buy_time": 1.0,
		"buy_time_first": 1.0, "round_time": 25.0, "banner": 0.5})
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	var dd: AssaultDirector = world.director.team
	await _until(func(): return world.director.map != null and world.director.map._region.navigation_mesh != null, 3600)
	check("partie sur le Bourg : la carte du directeur", String(dd.layout.get("id", "")) == "bourg" and dd.map is ProcMap
		and not (dd.map as ProcMap).assault.is_empty())
	check("site_at : le point de pose est dans son site", dd.site_at(dd.site_pos("A")) == "A" and dd.site_at(dd.site_pos("B")) == "B")
	var inside := 0
	for k in dd.heroes:
		var h := dd.hero(String(k))
		var t := Assault.team_of(String(k))
		var sp: Dictionary = dd.layout.spawns["attack" if t == Assault.attack else "defense"]
		if h != null and Vector2(h.global_position.x - sp.pos.x, h.global_position.z - sp.pos.z).abs() <= (sp.half as Vector2) + Vector2(1.5, 1.5):
			inside += 1
	check("8 héros dans leur départ (%d)" % inside, inside == 8)
	var start_d := INF
	await _until(func(): return Assault.phase == "live", 3000)
	var c0 := dd.hero(dd.carrier)
	if c0 != null:
		start_d = Vector2(c0.global_position.x - dd.site_pos(dd.target_site).x, c0.global_position.z - dd.site_pos(dd.target_site).z).length()
	await _until(func(): return Assault.round_time > 6.0 or Assault.phase != "live", 3000)
	var c1 := dd.hero(dd.carrier)
	var now_d := INF if c1 == null else Vector2(c1.global_position.x - dd.site_pos(dd.target_site).x, c1.global_position.z - dd.site_pos(dd.target_site).z).length()
	check("le porteur avance vers son site par les rues (%.0f m -> %.0f m)" % [start_d, now_d], now_d < start_d - 15.0 or Assault.phase != "live")
	await _until(func(): return dd._ended, 20000)
	check("partie finie sur le Bourg (%s)" % " | ".join(dd.round_lines), dd._ended)
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
