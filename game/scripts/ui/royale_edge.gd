class_name RoyaleEdge
extends Control
## Flèches du Battle royale (lot BR-I1, backlog P0 n° 2, 3 et 4), dessinées au-dessus du monde, sous le reste du HUD :
## - zone sûre : hors de l'anneau (ou hors du prochain quand il va se resserrer), une flèche améthyste au bord de la zone de
##   jeu, avec « Zone sûre · 140 m » ;
## - héros proches hors de la vue (moins de NEAR m) : une flèche fraise avec la couleur de sa famille ;
## - repère personnel (RoyalePing) : l'épingle lagon posée au sol avec sa distance, ou une flèche lagon au bord.
## Les flèches restent dans un cadre qui évite les panneaux du HUD (objectif en haut à gauche, colonne de la mini-carte à
## droite, barre d'action en bas). `arrows` décrit ce qui est affiché (tests).

const NEAR := 40.0  # m : héros signalés hors de la vue
const MARGIN_LEFT := 44.0
const MARGIN_TOP := 124.0
const MARGIN_RIGHT := 286.0  # colonne de la mini-carte, des tuiles et du fil
const MARGIN_BOTTOM := 236.0  # barre d'action, effets
const ARROW := 24.0  # px à 900 de haut

var player: Node3D
var director: Node  # RunDirector
## Ce qui est affiché : [{kind: zone|hero|ping, tip: Vector2, dir: Vector2, on_screen: bool, text: String, who}]
var arrows: Array = []
## Marge du bas en plus (px) : l'aide du largage ou du retour occupe le bas de l'écran (RoyaleHud la règle).
var bottom_extra := 0.0


func setup(p: Node3D, d: Node) -> void:
	player = p
	director = d
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _royale():
	return director.get("royale") if director != null else null


## Cadre où se posent les flèches (écran sans les panneaux du HUD).
func frame_rect() -> Rect2:
	var vp := get_viewport_rect().size
	var r := Rect2(MARGIN_LEFT, MARGIN_TOP, vp.x - MARGIN_LEFT - MARGIN_RIGHT, vp.y - MARGIN_TOP - MARGIN_BOTTOM - bottom_extra)
	if r.size.x < 200.0 or r.size.y < 160.0:
		r = Rect2(Vector2(vp.x * 0.1, vp.y * 0.15), vp * Vector2(0.8, 0.6))
	return r


## Direction à l'écran (vers le haut = devant la caméra) d'un point du monde, vue du héros.
func screen_dir(world: Vector3) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	var to := world - player.global_position
	to.y = 0.0
	if cam == null or to.length() < 0.01:
		return Vector2.ZERO
	var local := to.rotated(Vector3.UP, -cam.global_rotation.y)
	return Vector2(local.x, local.z).normalized()


## Point du bord du cadre [param r] dans la direction [param dir] depuis [param origin] (gardé dans le cadre).
static func edge_point(r: Rect2, origin: Vector2, dir: Vector2) -> Vector2:
	var o := origin.clamp(r.position, r.end)
	var k := INF
	if dir.x > 0.0001:
		k = minf(k, (r.end.x - o.x) / dir.x)
	elif dir.x < -0.0001:
		k = minf(k, (r.position.x - o.x) / dir.x)
	if dir.y > 0.0001:
		k = minf(k, (r.end.y - o.y) / dir.y)
	elif dir.y < -0.0001:
		k = minf(k, (r.position.y - o.y) / dir.y)
	return o + dir * (k if k != INF else 0.0)


## Zone sûre visée : le prochain anneau s'il se resserre (ou va le faire), sinon l'anneau actuel. [centre, rayon, dehors]
func safe_zone() -> Array:
	var rd = _royale()
	if rd == null or (rd.ring as Dictionary).is_empty() or String(rd.phase) != "fight":
		return []
	var ring: Dictionary = rd.ring
	var p := Vector2(player.global_position.x, player.global_position.z)
	var outside_now := p.distance_to(ring.center) > float(ring.radius)
	var soon := String(ring.state) == "shrink" or (String(ring.state) == "hold" and float(ring.left) < 12.0)
	var c: Vector2 = ring.next_center if soon else ring.center
	var r := float(ring.next_radius) if soon else float(ring.radius)
	var outside_safe := p.distance_to(c) > r
	return [c, r, outside_now or (soon and outside_safe)]


func _process(_delta: float) -> void:
	compute()
	queue_redraw()


## Recalcule les flèches (appelé à chaque image ; les tests l'appellent aussi).
func compute() -> void:
	arrows.clear()
	var rd = _royale()
	if player == null or rd == null or not Royale.active:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var r := frame_rect()
	var head := player.global_position + Vector3.UP * 1.0
	var origin := r.get_center() if cam.is_position_behind(head) else cam.unproject_position(head)  # (à bord : la caméra est sur le héros)
	var vp := Rect2(Vector2.ZERO, get_viewport_rect().size).grow(-16.0)
	var dead: bool = bool(player.get("is_dead")) or bool(rd.spectating)
	# zone sûre
	var z := safe_zone()
	if not dead and not z.is_empty() and bool(z[2]):
		var c: Vector2 = z[0]
		var p2 := Vector2(player.global_position.x, player.global_position.z)
		var dist := maxf(0.0, p2.distance_to(c) - float(z[1]))
		var target := Vector3(c.x, player.global_position.y, c.y)
		var d := screen_dir(target)
		if d != Vector2.ZERO:
			arrows.append({"kind": "zone", "tip": edge_point(r, origin, d), "dir": d, "on_screen": false,
				"text": "Zone sûre · %d m" % roundi(dist), "who": null})
	# héros proches hors de la vue
	if not dead and not (rd.jump != null and rd.jump.airborne(player)):
		for a in rd.ais:
			if not is_instance_valid(a) or a.is_dead or not a.visible or not a.is_in_group("ffa"):
				continue
			var gp: Vector3 = a.global_position
			if gp.distance_to(player.global_position) > NEAR:
				continue
			if not cam.is_position_behind(gp + Vector3.UP) and vp.has_point(cam.unproject_position(gp + Vector3.UP)):
				continue  # dans la vue : sa plaque suffit
			var d := screen_dir(gp)
			if d != Vector2.ZERO:
				arrows.append({"kind": "hero", "tip": edge_point(r, origin, d), "dir": d, "on_screen": false, "text": "", "who": a})
	# repère personnel
	if RoyalePing.has():
		if not dead and RoyalePing.distance(player.global_position) < RoyalePing.REACHED and _grounded(rd):
			RoyalePing.reset()  # atteint : il s'efface
		else:
			var pp := RoyalePing.pos
			var up := pp + Vector3.UP * 0.5
			var s := Vector2.INF if cam.is_position_behind(up) else cam.unproject_position(up)
			var text := RoyalePing.text(player.global_position)
			if s != Vector2.INF and r.grow(30.0).has_point(s):
				arrows.append({"kind": "ping", "tip": s, "dir": Vector2.DOWN, "on_screen": true, "text": text, "who": null})
			else:
				var d := screen_dir(pp)
				if d != Vector2.ZERO:
					arrows.append({"kind": "ping", "tip": edge_point(r, origin, d), "dir": d, "on_screen": false, "text": text, "who": null})


func _grounded(rd) -> bool:
	return rd.jump == null or not rd.jump.airborne(player)


func _draw() -> void:
	if arrows.is_empty():
		return
	var k := clampf(get_viewport_rect().size.y / 900.0, 0.75, 1.3)
	var r := frame_rect()
	for a in arrows:
		match String(a.kind):
			"zone":
				_arrow(a.tip, a.dir, RoyaleHudStyle.AMETHYST, 1.25 * k)
				_label_beside(a.tip, a.dir, ARROW * 1.25 * k, String(a.text), RoyaleHudStyle.AMETHYST[0], r)
			"hero":
				_arrow(a.tip, a.dir, RoyaleHudStyle.STRAWBERRY, 0.9 * k)
				var who = a.who
				if who != null and is_instance_valid(who) and who.has_meta("royale"):
					var tones := RoyaleHudStyle.family_tones(String(who.get_meta("royale").get("cid", "")))
					var dot: Vector2 = a.tip - (a.dir as Vector2) * ARROW * 1.9 * k
					draw_circle(dot, 9.0 * k, RoyaleHudStyle.INK)
					draw_circle(dot, 6.5 * k, tones[1])
			"ping":
				if bool(a.on_screen):
					_pin(a.tip, k)
					_label_inside(a.tip + Vector2(0, 22.0 * k), String(a.text), RoyaleHudStyle.LAGOON[0], Rect2(Vector2.ZERO, get_viewport_rect().size))
				else:
					_arrow(a.tip, a.dir, RoyaleHudStyle.LAGOON, 1.05 * k)
					_label_beside(a.tip, a.dir, ARROW * 1.05 * k, String(a.text), RoyaleHudStyle.LAGOON[0], r)


## Flèche autocollant (pointe vers l'extérieur) : contour d'encre, deux tons.
func _arrow(tip: Vector2, dir: Vector2, tones: Array, scale_: float) -> void:
	var s := ARROW * scale_
	var side := dir.orthogonal() * s * 0.72
	var back := tip - dir * s * 1.35
	var notch := tip - dir * s * 1.0
	var pts := PackedVector2Array([tip, back + side, notch, back - side])
	RoyaleHudStyle.draw_inked_polygon(self, pts, tones[1], 3.0)
	# reflet clair sur la moitié haute (cel)
	var hl := PackedVector2Array([tip, back + side, notch])
	draw_colored_polygon(hl, Color(tones[0], 0.85))


## Épingle du repère posée au sol : goutte lagon contourée, pointe vers le bas (sur [param at]).
func _pin(at: Vector2, k: float) -> void:
	var age := (Time.get_ticks_msec() - RoyalePing.placed_at) / 1000.0
	var bounce := 1.0 + 0.25 * maxf(0.0, 1.0 - age / 0.3)
	var r := 13.0 * k * bounce
	var head := at - Vector2(0, r * 2.1)
	var pts := PackedVector2Array()
	for i in 21:
		var ang := PI * 0.75 + i * (PI * 1.5) / 20.0
		pts.append(head + Vector2(cos(ang), sin(ang)) * r)
	pts.append(at)
	RoyaleHudStyle.draw_inked_polygon(self, pts, RoyaleHudStyle.LAGOON[1], 3.0)
	draw_circle(head, r * 0.42, RoyaleHudStyle.WHITE)
	draw_circle(head - Vector2(r * 0.35, r * 0.4), r * 0.18, Color(1, 1, 1, 0.8))
	draw_arc(at, 9.0 * k, 0.0, TAU, 20, Color(RoyaleHudStyle.LAGOON[2], 0.8), 2.0, true)


## Pastille de texte posée derrière la flèche (côté écran), sans la chevaucher, gardée dans [param bounds].
func _label_beside(tip: Vector2, dir: Vector2, arrow_len: float, text: String, fill: Color, bounds: Rect2) -> void:
	var size := 15
	var w := RoyaleHudStyle.text_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 24.0
	var h := float(size) + 12.0
	var reach := arrow_len * 1.45 + absf(dir.x) * w * 0.5 + absf(dir.y) * h * 0.5 + 6.0
	_label_inside(tip - dir * reach, text, fill, bounds)


## Pastille de texte centrée sur [param at], gardée dans [param bounds].
func _label_inside(at: Vector2, text: String, fill: Color, bounds: Rect2) -> void:
	if text == "":
		return
	var f := RoyaleHudStyle.text_font()
	var size := 15
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 24.0
	var h := float(size) + 12.0
	var c := at.clamp(bounds.position + Vector2(w, h) * 0.5, bounds.end - Vector2(w, h) * 0.5)
	RoyaleHudStyle.draw_pill(self, c, text, fill, size, RoyaleHudStyle.INK)
