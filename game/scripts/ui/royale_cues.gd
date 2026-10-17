class_name RoyaleCues
extends Control
## « Voir les sons » du Battle royale (lot BR-I3, backlog P2 n° 21 ; réglage interface/sound_cues, coupé par défaut) :
## chaque son important proche devient un arc autour du héros, dans la direction d'où il vient, avec son nom en
## sous-titre (« Coffre », « Combat », « Pas », « Largage », « Anneau ») ; 1,6 s puis il s'efface. Pour jouer sans le son
## ou malentendant. Les sons sont signalés par le jeu (heard : coffre ouvert par un scripté, coups entre héros, largage,
## resserrement de l'anneau) ; les pas sont ceux des héros proches hors de la vue.

const LIFE := 1.6
const RANGE := 50.0  # m
const STEPS_RANGE := 22.0
const RADIUS := 104.0  # px autour du héros (à 1600×900)
const ARC := 0.5  # rad
## Sorte -> [nom, couleurs]
const KINDS := {
	"chest": ["Coffre", RoyaleHudStyle.SUN], "fight": ["Combat", RoyaleHudStyle.STRAWBERRY], "steps": ["Pas", RoyaleHudStyle.COMMON],
	"drop": ["Largage", RoyaleHudStyle.SUN], "ring": ["Anneau", RoyaleHudStyle.AMETHYST],
}

static var events: Array = []  # [{pos: Vector3, kind, at (ms)}]

var player: Player
var director: RunDirector
var shown: Array = []  # [{kind, angle, alpha, dist}] : dessinés à cette image (tests)
var _steps_t := 0.0


## Un son [param kind] s'est fait entendre en [param pos] (fusionné avec le même son proche de moins d'une demi-seconde).
static func heard(pos: Vector3, kind: String) -> void:
	var now := Time.get_ticks_msec()
	for e in events:
		if String(e.kind) == kind and now - int(e.at) < 500 and (e.pos as Vector3).distance_to(pos) < 4.0:
			e.at = now
			return
	events.append({"pos": pos, "kind": kind, "at": now})
	if events.size() > 24:
		events.pop_front()


static func enabled() -> bool:
	return bool(Settings.get_v("interface", "sound_cues"))


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	name = "RoyaleCues"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	events.clear()


func _process(delta: float) -> void:
	if not enabled() or player == null or not is_instance_valid(player) or director == null or director.royale == null:
		if not shown.is_empty():
			shown.clear()
			queue_redraw()
		return
	_steps_t -= delta
	if _steps_t <= 0.0:
		_steps_t = 0.3
		_listen_steps()
	compute()
	queue_redraw()


## Pas des héros proches, en mouvement, hors de la vue.
func _listen_steps() -> void:
	var rd: RoyaleDirector = director.royale
	var cam := get_viewport().get_camera_3d()
	if cam == null or player.is_dead:
		return
	var vp := get_viewport_rect()
	for a in rd.ais:
		if not is_instance_valid(a) or a.is_dead or not a.visible or not a.is_in_group("ffa"):
			continue
		var p: Vector3 = a.global_position
		if p.distance_to(player.global_position) > STEPS_RANGE or (a as CharacterBody3D).velocity.length() < 2.0:
			continue
		if not cam.is_position_behind(p) and vp.has_point(cam.unproject_position(p)):
			continue
		heard(p, "steps")


## Arcs à dessiner : direction (angle à l'écran, 0 = droite), opacité selon l'âge.
func compute() -> void:
	shown.clear()
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var now := Time.get_ticks_msec()
	events = events.filter(func(e): return float(now - int(e.at)) / 1000.0 < LIFE)
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()  # devant la caméra, à plat : le haut de l'écran
	for e in events:
		var to: Vector3 = (e.pos as Vector3) - player.global_position
		to.y = 0.0
		var dist := to.length()
		var lim := STEPS_RANGE if String(e.kind) == "steps" else RANGE
		if dist > lim or dist < 1.0:
			continue
		var sd := Vector2(to.dot(right), -to.dot(fwd))
		var age := float(now - int(e.at)) / 1000.0
		shown.append({"kind": String(e.kind), "angle": sd.angle(), "alpha": clampf(1.0 - maxf(0.0, age - LIFE * 0.6) / (LIFE * 0.4), 0.0, 1.0),
			"dist": dist})


func _draw() -> void:
	if shown.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(player.global_position):
		return
	var c := get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(player.global_position + Vector3.UP * 1.0)
	var k := clampf(size.y / 900.0, 0.8, 1.2) if size.y > 1.0 else 1.0
	var r := RADIUS * k
	for s in shown:
		var info: Array = KINDS.get(String(s.kind), ["Son", RoyaleHudStyle.COMMON])
		var tones: Array = RoyaleHudStyle.danger() if String(s.kind) == "fight" else info[1]
		var a := float(s.alpha)
		var ang := float(s.angle)
		var w := 10.0 if float(s.dist) < 20.0 else 7.0  # plus proche : plus épais
		_arc(c, r, ang, w, Color(tones[1], a))
		# sous-titre : le nom du son, au-delà de l'arc
		var label := String(info[0])
		var f := RoyaleHudStyle.text_font()
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var dir := Vector2.from_angle(ang)
		var at := c + dir * (r + 14.0 + absf(dir.x) * (tw * 0.5 + 9.0) + absf(dir.y) * 11.0)  # (le nom ne couvre jamais l'arc)
		var box := Rect2(at - Vector2(tw * 0.5 + 9.0, 11.0), Vector2(tw + 18.0, 22.0))
		RoyaleHudStyle.draw_sticker(self, box, Color(RoyaleHudStyle.PAPER, a), 11.0, 2.0, 2.0)
		draw_string(f, Vector2(box.position.x + 9.0, at.y + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(RoyaleHudStyle.INK, a))


## Arc épais contouré d'encre (un polygone : draw_arc n'a pas de contour), centré sur [param ang].
func _arc(c: Vector2, r: float, ang: float, w: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 10
	for i in n + 1:
		pts.append(c + Vector2.from_angle(ang - ARC * 0.5 + ARC * float(i) / n) * (r + w * 0.5))
	for i in range(n, -1, -1):
		pts.append(c + Vector2.from_angle(ang - ARC * 0.5 + ARC * float(i) / n) * (r - w * 0.5))
	RoyaleHudStyle.draw_inked_polygon(self, pts, col, 2.5)
