extends Node
## Battle royale, lot BR-I1 (backlog P0 n° 1 à 5) : HUD d'état v2 (tuiles, barre de l'anneau, fil en pastilles, plus de
## pourcentage ni de mot technique), direction de l'anneau (flèche au bord, ligne sur la mini-carte), flèches des héros
## proches hors de la vue, arc de coup reçu orienté, repère personnel (carte, manette, souris), grande carte v2 (ouverte
## seule pendant le vol, « Sauter » sur A, zoom, mise en page à 1600×900 et 1280×720) et coût du HUD par image.
## godot --headless --path game res://tests/test_bri1.tscn

const BUDGET_MS := 0.3  # coût maximal du HUD du Battle royale par image

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	get_window().size = Vector2i(1600, 900)
	check("action « Poser un repère » : clic molette et L3, réassignable", InputMap.has_action("ping") and Settings.DEFAULT_BINDS.has("ping")
		and Settings.PAD_BINDS.has("ping") and "ping" in Settings.PAD_ACTIONS)
	var rd: RoyaleDirector = await _boot()
	var hud: Hud = world.hud
	var rh: RoyaleHud = hud.get("_royale")
	check("HUD du Battle royale posé", rh != null and rh.edge != null and rh.arc != null and rh.map != null)
	if rh == null:
		_finish()
		return
	await _test_flight(rd, hud, rh)
	await _test_fight(rd, hud, rh)
	await _test_layout(rd, rh)
	_test_perf(rd, rh)
	_finish()


func _finish() -> void:
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _boot() -> RoyaleDirector:
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.start("magician")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	var waited := 0.0
	while waited < 60.0 and not (world.get("director") != null and world.director.royale != null and world.director.royale.ais.size() == 7):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	return world.director.royale


func _cards() -> void:
	if is_instance_valid(world) and world.cards.is_open():
		world.cards._queue.clear()  # (un choix de carte met la partie en pause)
		world.cards._show_next()


## Attend (au plus [param limit] s) que [param cond] soit vraie.
func _until(cond: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit and not cond.call():
		_cards()
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		_cards()
		await get_tree().process_frame


func _pad(button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.device = 0
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


## Appui du bouton [param button] en [param from], relâché en [param to].
func _mouse(button: MouseButton, from: Vector2, to: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = from
	ev.global_position = from
	Input.parse_input_event(ev)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = button
	up.pressed = false
	up.position = to
	up.global_position = to
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


static func _inside(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(0.5).encloses(inner)


static func _no_percent(t: String) -> bool:
	return not t.contains("%")


# --- vol : la grande carte ---------------------------------------------------------------------------
func _test_flight(rd: RoyaleDirector, hud: Hud, rh: RoyaleHud) -> void:
	var p: Player = world.player
	var j := rd.jump
	var m := rh.map
	check("panneau d'objectifs remplacé par l'objectif court", not hud.get("_obj_panel").visible and rh._goal.visible)
	await _until(func(): return m.is_open, 6.0)
	check("carte ouverte seule pendant le vol", m.is_open and m.for_ride and m.riding())
	await _frames(2)
	check("objectif court : « %s » / « %s »" % [rh._goal_title.text, rh._goal_sub.text], rh._goal_title.text == "Largage" and rh._goal_sub.text != "")
	var drop_box = hud.get("_drop_box")
	check("aide du largage cachée sous la carte", drop_box == null or not drop_box.visible)
	var vp := Rect2(Vector2.ZERO, m.get_viewport_rect().size)
	print("[bri1] écran %s · carte %s · panneau %s (contenu %.0f px)" % [str(vp.size), str(m.map_rect()), str(m.side_rect()), _side_content(m, true)])
	check("1600×900 : carte et panneau dans l'écran, sans se chevaucher", _inside(vp, m.map_rect()) and _inside(vp, m.side_rect())
		and not m.map_rect().intersects(m.side_rect()))
	check("« Sauter » grisé tant que les portes sont fermées", m._jump_btn.disabled == (j.t < Royale.COUNTDOWN))
	check("panneau : « %s » · « %s »" % [m._title.text, m._timer_label.text], m._title.text == "Où atterrir ?" and m._timer_label.text.ends_with("s")
		and _no_percent(m._timer_label.text))
	# repère d'un clic : point de la vue <-> point du monde
	RoyalePing.reset()
	var at := m._view.size * Vector2(0.4, 0.6)
	m.ping_at(at)
	var w := m.view_to_world(at)
	check("repère posé sur la carte (%.0f ; %.0f)" % [RoyalePing.pos.x, RoyalePing.pos.z], RoyalePing.has() and RoyalePing.pos.distance_to(w) < 0.5)
	check("monde -> carte -> monde (%.2f px)" % m.world_to_view(w).distance_to(at), m.world_to_view(w).distance_to(at) < 1.0)
	m.ping_at(at + Vector2(2, 1))
	check("2e clic au même endroit : repère enlevé", not RoyalePing.has())
	m.ping_at(at)
	var s0 := m._scale()
	m.zoom_at(at, 1)
	check("zoom ×%s (échelle ×%.1f), le point visé reste sous le curseur" % [str(RoyaleMap.ZOOMS[m.zoom_i]), m._scale() / s0],
		m.zoom_i == 1 and absf(m._scale() / s0 - 2.0) < 0.01 and m.world_to_view(w).distance_to(at) < 1.0)
	m.zoom_at(at, -1)
	check("dézoom : carte entière", m.zoom_i == 0 and is_equal_approx(m._scale(), s0))
	m.refresh()
	check("puits : « %s » / « %s »" % [m._info_a.text, m._info_b.text], (m._info_a.text == "Repère posé" or m._info_a.text.begins_with("Ton repère : ")) and m._info_b.text != "")
	var near_line: Vector3 = j.b.lerp(j.eagle_pos(), 0.5)
	check("atteignable en chute : près du vol oui, au bout de la carte non", m.reachable(near_line)
		and not m.reachable(near_line + (j.b - j.a).normalized().cross(Vector3.UP) * (RoyaleMap.reach_m() + 30.0)))
	# manette : A = Sauter (portes ouvertes)
	await _until(func(): return j.t >= Royale.COUNTDOWN + 0.2, 8.0)
	Gamepad.active = true
	await _pad(JOY_BUTTON_A)
	await _frames(2)
	check("A : saut hors de l'aigle, la carte se ferme", not j.on_board(p) and j.airborne(p) and not m.is_open)
	Gamepad.active = false
	rh.edge.compute()
	check("repère visible pendant la chute (« %s »)" % _ping_text(rh), rh.edge.arrows.any(func(a): return a.kind == "ping") and _ping_text(rh).ends_with(" m"))


func _ping_text(rh: RoyaleHud) -> String:
	for a in rh.edge.arrows:
		if a.kind == "ping":
			return String(a.text)
	return ""


# --- combat : HUD d'état, flèches, arc, repère -----------------------------------------------------------
func _test_fight(rd: RoyaleDirector, hud: Hud, rh: RoyaleHud) -> void:
	var p: Player = world.player
	rd.jump.land_all()
	await _until(func(): return rd.phase == "fight", 10.0)
	await _frames(3)
	check("au sol : combat", rd.phase == "fight")
	var tv := rh.tile_values()
	check("tuiles : %s en vie, %s élim., niveau %s" % [tv.alive, tv.kills, tv.level], tv.alive == str(rd.alive_count()) and tv.kills == str(Royale.kills)
		and tv.level == "%d/%d" % [p.level, Royale.level_cap_now])
	var rt := rh.ring_texts()
	check("barre de l'anneau : « %s » · « %s »" % rt, String(rt[0]) in ["Se referme", "Se resserre", "Dernier cercle"]
		and RegEx.create_from_string("^\\d+:\\d\\d$").search(String(rt[1])) != null)
	check("orbe de niveau sans pourcentage, pas de mot technique", hud.get("_xp_orb").small_text == "" and hud.get("_assist_label").text == "")
	check("objectif court : « %s »" % rh._goal_title.text, rh._goal_title.text.begins_with("Anneau ") and _no_percent(rh._goal_sub.text))
	rd.feed("Tu élimines Assassin")
	rd.feed("Paladin élimine Prêtre")
	await _frames(2)
	check("fil en pastilles (%s), l'ancien fil caché" % str(rh.feed_lines()), rh.feed_lines().has("Tu élimines Assassin")
		and rh.feed_lines().size() == 2 and not hud.get("_feed_box").visible)
	# --- flèche de l'anneau
	var ring: Dictionary = rd.ring
	var c: Vector2 = ring.center
	var out := c + Vector2(1, 0.3).normalized() * (float(ring.radius) + 45.0)
	_place(p, Vector3(out.x, 0, out.y))
	await _frames(2)
	rh.edge.compute()
	var za := _arrow(rh, "zone")
	check("hors de l'anneau : flèche vers la zone sûre", not za.is_empty())
	if not za.is_empty():
		var cam := get_viewport().get_camera_3d()
		var toward := p.global_position + (Vector3(c.x, p.global_position.y, c.y) - p.global_position).normalized() * 6.0
		var sdir := (cam.unproject_position(toward) - cam.unproject_position(p.global_position)).normalized()
		check("flèche orientée vers le centre (accord %.2f avec la projection)" % sdir.dot(za.dir), sdir.dot(za.dir) > 0.85)
		var fr := rh.edge.frame_rect()
		var tip: Vector2 = za.tip
		var on_edge := absf(tip.x - fr.position.x) < 1.0 or absf(tip.x - fr.end.x) < 1.0 or absf(tip.y - fr.position.y) < 1.0 or absf(tip.y - fr.end.y) < 1.0
		check("pointe au bord du cadre (%.0f ; %.0f)" % [tip.x, tip.y], on_edge and fr.grow(1.0).has_point(tip))
		check("« %s » sans pourcentage" % za.text, String(za.text).begins_with("Zone sûre · ") and String(za.text).ends_with(" m"))
	rh._update_goal(rd)
	check("objectif : « %s »" % rh._goal_sub.text, rh._goal_sub.text == "Rejoins la zone sûre !")
	check("message hors de l'anneau sans pourcentage", not FileAccess.get_file_as_string("res://scripts/core/royale_director.gd").contains("des PV par seconde"))
	_place(p, Vector3(c.x, 0, c.y))
	await _frames(2)
	rh.edge.compute()
	check("dans l'anneau : pas de flèche (joueur %s, centre %s, %s)" % [str(p.global_position.round()), str(c.round()), str(rh.edge.safe_zone())], _arrow(rh, "zone").is_empty())
	# --- héros proches hors de la vue
	var a: ClassRival = null
	for r in rd.ais:
		if is_instance_valid(r) and not r.is_dead and r.is_in_group("ffa"):
			a = r
			break
	check("un héros scripté au sol", a != null)
	if a != null:
		for r in rd.ais:
			if is_instance_valid(r) and r != a:
				_place(r, p.global_position + Vector3(200, 0, 200))  # (les autres loin)
		a.passive = true
		var c2: Vector2 = rd.ring.center
		_place(p, _free(Vector3(c2.x, 0, c2.y), 75.0))  # (une plaine : aucun rocher à portée des héros posés autour)
		await _frames(2)
		var cam := get_viewport().get_camera_3d()
		var behind := Vector3(0, 0, 34).rotated(Vector3.UP, cam.global_rotation.y)  # vers la caméra : sous le bas de l'écran
		_place(a, p.global_position + behind)
		await _frames(2)
		rh.edge.compute()
		var ha := _arrow(rh, "hero")
		check("héros à 34 m hors de la vue : flèche vers le bas (%s)" % str(ha.get("dir", "")), not ha.is_empty() and Vector2(ha.dir).dot(Vector2.DOWN) > 0.9)
		_place(a, p.global_position + behind * 1.9)
		await _frames(2)
		rh.edge.compute()
		check("héros à 65 m : pas de flèche", _arrow(rh, "hero").is_empty())
		_place(a, p.global_position + Vector3(3, 0, 0).rotated(Vector3.UP, cam.global_rotation.y))
		await _frames(2)
		rh.edge.compute()
		check("héros dans la vue : pas de flèche (sa plaque suffit)", _arrow(rh, "hero").is_empty())
		# --- arc de coup reçu
		p.evasion_chance = 0.0
		p.parry_chance = 0.0
		p.shield_until = 0.0
		rh.arc.arcs.clear()
		_place(a, p.global_position + Vector3(6, 0, 0).rotated(Vector3.UP, cam.global_rotation.y))
		await _frames(1)
		p.take_damage(5.0, a, false)
		check("coup reçu : un arc", rh.arc.arcs.size() == 1)
		if rh.arc.arcs.size() == 1:
			check("arc à droite (%.0f°) : le coup vient de la droite" % rad_to_deg(float(rh.arc.arcs[0].angle)), absf(angle_difference(float(rh.arc.arcs[0].angle), 0.0)) < 0.2)
		_place(a, p.global_position + Vector3(-6, 0, 0).rotated(Vector3.UP, cam.global_rotation.y))
		await _frames(1)
		p.take_damage(5.0, a, false)
		check("coup venu de gauche : un 2e arc (%.0f°)" % (rad_to_deg(float(rh.arc.arcs[-1].angle)) if rh.arc.arcs.size() > 0 else 0.0),
			rh.arc.arcs.size() == 2 and absf(angle_difference(float(rh.arc.arcs[1].angle), PI)) < 0.2)
		p.take_damage(5.0, a, false)
		check("même côté : l'arc est ravivé, pas doublé", rh.arc.arcs.size() == 2)
		p.take_damage(5.0, null, false, true)
		check("dégâts sans auteur (anneau) : pas d'arc", rh.arc.arcs.size() == 2)
		p.hp = p.max_hp
		_place(a, p.global_position + Vector3(150, 0, 150))
	# --- repère à la manette : devant le héros, effacé une fois atteint
	RoyalePing.reset()
	var ev := InputEventAction.new()
	ev.action = "ping"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	check("repère posé devant le héros (%.0f m)" % RoyalePing.distance(p.global_position), RoyalePing.has() and absf(RoyalePing.distance(p.global_position) - RoyalePing.AHEAD) < 2.0)
	rh.edge.compute()
	check("repère à l'écran avec sa distance (« %s »)" % _ping_text(rh), _ping_text(rh).ends_with("%d m" % roundi(RoyalePing.distance(p.global_position))))
	var cam2 := get_viewport().get_camera_3d()
	var spot := RoyalePing.ground(rd.d.map, p.global_position.x, p.global_position.z) + Vector3(7, 0, 0).rotated(Vector3.UP, cam2.global_rotation.y)
	spot = RoyalePing.ground(rd.d.map, spot.x, spot.z)
	var hit := RoyalePing.under_cursor(cam2, cam2.unproject_position(spot), rd.d.map)
	if hit == Vector3.INF:
		print("[bri1] rayon raté : caméra %s · point %s · écran %s · derrière %s" % [str(cam2.global_position), str(spot), str(cam2.unproject_position(spot)), str(cam2.is_position_behind(spot))])
	check("clic molette : point du sol sous le curseur (écart %.1f m)" % Vector2(hit.x - spot.x, hit.z - spot.z).length(),
		hit != Vector3.INF and Vector2(hit.x - spot.x, hit.z - spot.z).length() < 1.5)
	# clic molette : un clic pose le repère sous la souris ; un glisser (caméra du mode « clic droit ») n'en pose pas
	var keep := RoyalePing.pos
	RoyalePing.reset()
	var at := cam2.unproject_position(spot)
	await _mouse(MOUSE_BUTTON_MIDDLE, at, at + Vector2(40, 10))
	check("clic molette glissé : pas de repère", not RoyalePing.has())
	await _mouse(MOUSE_BUTTON_MIDDLE, at, at + Vector2(2, 1))
	check("clic molette : repère sous la souris (écart %.1f m)" % (Vector2(RoyalePing.pos.x - spot.x, RoyalePing.pos.z - spot.z).length() if RoyalePing.has() else -1.0),
		RoyalePing.has() and Vector2(RoyalePing.pos.x - spot.x, RoyalePing.pos.z - spot.z).length() < 2.0)
	RoyalePing.reset()
	RoyalePing.toggle(keep)
	_place(p, RoyalePing.pos)
	await _frames(2)
	rh.edge.compute()
	check("repère atteint : il s'efface", not RoyalePing.has())
	# --- grande carte au sol
	rh.toggle_map()
	await _frames(2)
	var m := rh.map
	check("[Carte] : grande carte au sol (« %s »)" % m._ring_line.text, m.is_open and not m.for_ride and m._title.text == "Carte"
		and m._ring_line.text.begins_with("Anneau") and _no_percent(m._ring_line.text) and m._legend.visible and not m._jump_btn.visible)
	rh.toggle_map()
	check("[Carte] : refermée, caméra rendue", not m.is_open and world.rig.allow_input)


## Hauteur du contenu du panneau de la grande carte (marges comprises), avec le contenu du vol ([param ride]) ou du sol.
func _side_content(m: RoyaleMap, ride: bool) -> float:
	var shown := {m._timer_box: ride, m._jump_btn: ride, m._footer: ride, m._legend: not ride, m._ring_line: not ride}
	var keep := {}
	for c in shown:
		keep[c] = c.visible
		c.visible = shown[c]
	if ride:
		m._footer.text = "À bord : 8 · Sautés : 0"
	var v: Control = m._side.get_child(0)
	var h := v.get_combined_minimum_size().y + m._side.get_theme_stylebox("panel").get_minimum_size().y
	for c in keep:
		c.visible = keep[c]
	return h


func _arrow(rh: RoyaleHud, kind: String) -> Dictionary:
	for a in rh.edge.arrows:
		if a.kind == kind:
			return a
	return {}


## Couvert des lieux nommés (lot BR-I2) : un héros posé dans un rocher en serait éjecté par la physique.
func _covers() -> Array:
	var out: Array = []
	var map: Node = world.director.map
	if "places" in map:
		for pl in map.places:
			for cv in pl.get("cover", []):
				var cq = cv.q
				out.append(Vector2(cq.x, cq.z) if cq is Vector3 else Vector2(cq.x, cq.y))
	return out


## Point près de [param at] (en spirale) dont le sol est praticable et sans couvert à moins de [param clear] m.
func _free(at: Vector3, clear := 7.0) -> Vector3:
	var map: Node = world.director.map
	var covers := _covers()
	for i in 400:
		var q := Vector2(at.x, at.z) + (Vector2.RIGHT.rotated(i * 2.4) * (3.0 * sqrt(float(i))) if i > 0 else Vector2.ZERO)
		if map.ground_at(q.x, q.y) == Vector3.INF:
			continue
		if covers.all(func(cq): return (cq as Vector2).distance_to(q) >= clear):
			return Vector3(q.x, at.y, q.y)
	return at


func _place(c: Node3D, at: Vector3) -> void:
	if c == world.player:
		at = _free(at)
	var g: Vector3 = at
	g.y = float(world.director.map.height_at(at.x, at.z)) + 0.1
	c.global_position = g
	if c == world.player and world.rig != null:
		world.rig.global_position = g  # (la caméra suit sans retard : les projections sont celles de l'écran)
	if c is CharacterBody3D:
		(c as CharacterBody3D).velocity = Vector3.ZERO


# --- mise en page : 1280×720 ------------------------------------------------------------------------------
func _test_layout(rd: RoyaleDirector, rh: RoyaleHud) -> void:
	for res in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_window().size = res
		await _frames(3)
		var vp := Rect2(Vector2.ZERO, rh.get_viewport_rect().size)
		rh.map.open(false)
		await _frames(2)
		check("%d×%d : grande carte et panneau dans l'écran" % [res.x, res.y], _inside(vp, rh.map.map_rect()) and _inside(vp, rh.map.side_rect())
			and not rh.map.map_rect().intersects(rh.map.side_rect()))
		for ride in [false, true]:
			var side_end := _side_content(rh.map, ride)
			check("%d×%d : contenu du panneau %s sans débord (%.0f / %.0f px)" % [res.x, res.y, "du vol" if ride else "au sol", side_end, rh.map.side_rect().size.y],
				side_end <= rh.map.side_rect().size.y + 1.0)
		rh.map.close()
		for i in 4:
			rd.feed("Héros %d élimine un autre héros au nom assez long" % i)
		await _frames(3)
		var col: Rect2 = rh._col.get_global_rect().merge(rh._feed.get_global_rect())
		var bar_top := vp.size.y - 204.0  # haut de la barre d'action (Hud._build_action_bar)
		check("%d×%d : colonne (tuiles, anneau, fil) dans l'écran, au-dessus de la barre d'action (bas %.0f, barre %.0f)" % [res.x, res.y, col.end.y, bar_top],
			_inside(vp, col) and col.end.y <= bar_top)
		var goal: Rect2 = rh._goal.get_global_rect()
		check("%d×%d : fil en une ligne par élimination (%d pastilles)" % [res.x, res.y, rh._feed.get_child_count()],
			rh._feed.get_children().all(func(pl): return (pl as Control).size.y < 40.0))
		check("%d×%d : objectif court dans l'écran, loin de la mini-carte" % [res.x, res.y], _inside(vp, goal) and goal.end.x < rh._col.get_global_rect().position.x)
	get_window().size = Vector2i(1600, 900)
	await _frames(2)


# --- coût par image -----------------------------------------------------------------------------------------
func _test_perf(rd: RoyaleDirector, rh: RoyaleHud) -> void:
	var p: Player = world.player
	var c: Vector2 = rd.ring.center
	_place(p, Vector3(c.x + float(rd.ring.radius) + 30.0, 0, c.y))  # dehors : la flèche est calculée
	RoyalePing.toggle(p.global_position + Vector3(20, 0, 0))
	# 7 séries de 100 images : la meilleure série donne le coût propre (les autres processus de la machine ne font qu'ajouter)
	var runs: Array = []
	for k in 7:
		var t0 := Time.get_ticks_usec()
		for i in 100:
			rh.tick(1.0 / 60.0)
			rh.edge.compute()
			rh.arc._process(1.0 / 60.0)
		runs.append(float(Time.get_ticks_usec() - t0) / 1000.0 / 100.0)
	runs.sort()
	var ms: float = runs[0]
	print("[bri1] coût du HUD du Battle royale : %.3f ms par image (médiane %.3f)" % [ms, float(runs[3])])
	check("coût du HUD par image : %.3f ms (≤ %.1f)" % [ms, BUDGET_MS], ms <= BUDGET_MS)
