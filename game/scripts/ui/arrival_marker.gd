class_name ArrivalMarker
extends CanvasLayer
## Signal d'arrivée (passe P15) : une flèche au bord de l'écran montre d'où vient une élite ou un groupe qui surgit
## hors de la vue (les monstres apparaissent hors écran) ; au-dessus du point quand il est dans la vue.
## Un seul calque par directeur : ArrivalMarker.mark(parent, position, couleur).

const LIFE := 2.6  # s
const EDGE := 56.0  # px : marge au bord de l'écran
const EDGE_TOP := 110.0  # px : sous les cadres du haut (carte, cible, mini-carte)
const EDGE_BOTTOM := 170.0  # px : au-dessus de la barre de sorts et des orbes de vie / niveau
const SIZE := 24.0
const OUTLINE := Color(0.08, 0.05, 0.04, 0.85)

var _marks: Array = []  # {pos: Vector3, t: float, color: Color}
var _canvas: Control


static func mark(parent: Node, pos: Vector3, color := Color(1.0, 0.55, 0.2)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var layer: ArrivalMarker = parent.get_node_or_null("ArrivalMarker")
	if layer == null:
		layer = ArrivalMarker.new()
		layer.name = "ArrivalMarker"
		parent.add_child(layer)
	layer._marks.append({"pos": pos, "t": 0.0, "color": color})


func _ready() -> void:
	layer = 5
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_marks)
	add_child(_canvas)


func _process(delta: float) -> void:
	for m in _marks:
		m.t += delta
	_marks = _marks.filter(func(m): return float(m.t) < LIFE)
	_canvas.queue_redraw()


func _draw_marks() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var vp := get_viewport().get_visible_rect().size
	if vp.x < EDGE * 4.0 or vp.y < EDGE_TOP + EDGE_BOTTOM + 100.0:
		return  # pas d'écran (mesures sans affichage)
	var center := vp * 0.5
	for m in _marks:
		var p: Vector3 = m.pos + Vector3.UP * 1.5
		var behind := cam.is_position_behind(p)
		var s := cam.unproject_position(p)
		if behind:
			s = center - (s - center) * 1000.0
		var inner := Rect2(Vector2(EDGE, EDGE_TOP), vp - Vector2(EDGE * 2.0, EDGE_TOP + EDGE_BOTTOM))
		center = inner.get_center()
		# clignote doucement, s'efface à la fin
		var a := clampf((LIFE - float(m.t)) / 0.6, 0.0, 1.0) * (0.75 + 0.25 * sin(float(m.t) * 12.0))
		var col: Color = m.color
		col.a = a
		var dark := OUTLINE
		dark.a *= a
		if not behind and inner.has_point(s):
			# dans la vue : un chevron qui pointe vers le bas, au-dessus du point d'arrivée
			var chev := PackedVector2Array([s + Vector2(-SIZE * 0.7, -SIZE * 1.6), s + Vector2(SIZE * 0.7, -SIZE * 1.6), s + Vector2(0, -SIZE * 0.4)])
			_canvas.draw_colored_polygon(chev, col)
			chev.append(chev[0])
			_canvas.draw_polyline(chev, dark, 2.5, true)
			continue
		var dir := (s - center).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		# point du bord de l'écran dans cette direction
		var half := inner.size * 0.5
		var k := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
		var tip := center + dir * k
		var side := dir.orthogonal() * SIZE * 0.75
		var back := tip - dir * SIZE * 1.4
		var arrow := PackedVector2Array([tip, back + side, back - side])
		_canvas.draw_colored_polygon(arrow, col)
		arrow.append(tip)
		_canvas.draw_polyline(arrow, dark, 2.5, true)
		_canvas.draw_circle(back - dir * SIZE * 0.55, SIZE * 0.34, dark)
		_canvas.draw_circle(back - dir * SIZE * 0.55, SIZE * 0.26, col)
