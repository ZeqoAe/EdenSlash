class_name HitArc
extends Control
## Arc de coup reçu (lot BR-I1, backlog P0 n° 3) : quand un autre héros touche le joueur, un arc fraise contouré d'encre
## s'allume autour du héros, du côté d'où vient le coup (Battle royale, Duel, Arènes). Bible § 7-8 : 400 ms pleins puis
## fondu, petite vibration à la manette. Les dégâts sans auteur (anneau, poison) n'en font pas.

const HOLD := 0.4  # s : arc plein
const FADE := 0.35  # s : fondu
const SPREAD := 0.62  # rad : demi-ouverture de l'arc (≈ 35°)
const RADIUS := 118.0  # px à 900 de haut
const WIDTH := 11.0
const MERGE := 0.35  # rad : un coup venu presque du même côté ravive l'arc au lieu d'en ajouter un
const MAX_ARCS := 4

var player: Node3D
## Arcs en cours : {src: Vector3 (position de l'auteur au moment du coup), angle: rad à l'écran (0 = droite, PI/2 = bas), t}
var arcs: Array = []


## Pose un arc de coup reçu sur le HUD [param root] (juste au-dessus du liseré de vie basse) pour [param p].
static func attach(root: Control, p: Node3D) -> HitArc:
	var arc := HitArc.new()
	arc.name = "HitArc"
	root.add_child(arc)
	root.move_child(arc, mini(1, root.get_child_count() - 1))
	arc.setup(p)
	return arc


func setup(p: Node3D) -> void:
	player = p
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if p.has_signal("damaged"):
		p.connect("damaged", _on_damaged)


func _on_damaged(_amount: float, source) -> void:
	if source == null or not is_instance_valid(source) or source == player or not (source is Node3D):
		return
	hit((source as Node3D).global_position)


## Un coup venu de [param src] (position dans le monde).
func hit(src: Vector3) -> void:
	var a := screen_angle(src)
	if is_nan(a):
		return
	for arc in arcs:
		if absf(angle_difference(float(arc.angle), a)) < MERGE:
			arc.angle = a
			arc.src = src
			arc.t = 0.0
			_buzz()
			return
	arcs.append({"src": src, "angle": a, "t": 0.0})
	while arcs.size() > MAX_ARCS:
		arcs.pop_front()
	_buzz()
	queue_redraw()


## Angle à l'écran (depuis le héros) de la direction de [param src] ; NAN si la caméra manque ou si le coup vient d'aplomb.
func screen_angle(src: Vector3) -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or player == null:
		return NAN
	var to := src - player.global_position
	to.y = 0.0
	if to.length() < 0.05:
		return NAN
	var local := to.rotated(Vector3.UP, -cam.global_rotation.y)
	return Vector2(local.x, local.z).angle()


func _buzz() -> void:
	if not Gamepad.active or Input.get_connected_joypads().is_empty():
		return
	if not bool((Settings.data.get("interface", {}) as Dictionary).get("ui_vibration", true)):
		return
	Input.start_joy_vibration(0, 0.0, 0.35, 0.09)  # (faible, fort, durée) : coup reçu (Bible § 7)


func _process(delta: float) -> void:
	if arcs.is_empty():
		return
	for arc in arcs:
		arc.t = float(arc.t) + delta
	arcs = arcs.filter(func(arc): return float(arc.t) < HOLD + FADE)
	queue_redraw()


func _draw() -> void:
	if arcs.is_empty() or player == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp := get_viewport_rect().size
	var k := clampf(vp.y / 900.0, 0.7, 1.4)
	var head := player.global_position + Vector3.UP * 1.1
	if cam.is_position_behind(head):
		return
	var center := cam.unproject_position(head)
	var r := RADIUS * k
	for arc in arcs:
		var t := float(arc.t)
		var alpha := 1.0 if t < HOLD else clampf(1.0 - (t - HOLD) / FADE, 0.0, 1.0)
		var grow := 1.0 + 0.12 * clampf(t / 0.12, 0.0, 1.0)  # petit élan vers l'extérieur à l'arrivée
		var a := float(arc.angle)
		var rr := r * grow
		draw_arc(center, rr, a - SPREAD, a + SPREAD, 28, Color(RoyaleHudStyle.INK, 0.9 * alpha), (WIDTH + 6.0) * k, true)
		draw_arc(center, rr, a - SPREAD * 0.97, a + SPREAD * 0.97, 28, Color(RoyaleHudStyle.STRAWBERRY[1], alpha), WIDTH * k, true)
		draw_arc(center, rr - WIDTH * k * 0.22, a - SPREAD * 0.8, a + SPREAD * 0.8, 24, Color(RoyaleHudStyle.STRAWBERRY[0], 0.85 * alpha), 3.0 * k, true)
		# pointe vers l'extérieur, au milieu de l'arc : on lit d'où vient le coup
		var d := Vector2.RIGHT.rotated(a)
		var tip := center + d * (rr + WIDTH * k * 1.6)
		var base := center + d * (rr + WIDTH * k * 0.2)
		var side := d.orthogonal() * WIDTH * k * 0.9
		RoyaleHudStyle.draw_inked_polygon(self, PackedVector2Array([tip, base + side, base - side]), Color(RoyaleHudStyle.STRAWBERRY[1], alpha), 2.0)
