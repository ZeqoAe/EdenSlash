class_name AssaultCues
extends RoyaleCues
## « Voir les sons » de L'Assaut (lot TAC-2, TACTIQUE § 7.7 et Q7 : activé dans ce mode) : les bruits que TON équipe entend
## (AssaultVision.noise : pas, esquives, coups et sorts, pose et désamorçage) deviennent des arcs autour du héros regardé,
## dans la direction d'où ils viennent, avec leur nom. Mêmes arcs et même dessin que le Battle royale (RoyaleCues), mais
## autour de n'importe quel héros (le joueur, ou l'allié qu'il regarde après sa mort) et sans écoute des pas : la vision
## de l'Assaut ne signale que ce qu'on entend vraiment (honnête : rien derrière un mur au-delà de la portée du bruit).

const KINDS_A := {
	"steps": ["Pas", RoyaleHudStyle.COMMON], "fight": ["Combat", RoyaleHudStyle.STRAWBERRY], "drop": ["Charge", RoyaleHudStyle.SUN],
}

var viewer: Node3D
var vision: AssaultVision


func setup_assault(v: AssaultVision) -> void:
	vision = v
	name = "AssaultCues"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RoyaleCues.events.clear()


func _process(_delta: float) -> void:
	viewer = vision.viewer if vision != null and is_instance_valid(vision) else null
	if viewer == null or not is_instance_valid(viewer):
		if not shown.is_empty():
			shown.clear()
			queue_redraw()
		return
	compute()
	queue_redraw()


func compute() -> void:
	shown.clear()
	var cam := get_viewport().get_camera_3d()
	if cam == null or viewer == null:
		return
	var now := Time.get_ticks_msec()
	RoyaleCues.events = RoyaleCues.events.filter(func(e): return float(now - int(e.at)) / 1000.0 < LIFE)
	var right := cam.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for e in RoyaleCues.events:
		var to: Vector3 = (e.pos as Vector3) - viewer.global_position
		to.y = 0.0
		var dist := to.length()
		if dist < 1.0:
			continue
		var sd := Vector2(to.dot(right), -to.dot(fwd))
		var age := float(now - int(e.at)) / 1000.0
		shown.append({"kind": String(e.kind), "angle": sd.angle(), "alpha": clampf(1.0 - maxf(0.0, age - LIFE * 0.6) / (LIFE * 0.4), 0.0, 1.0),
			"dist": dist})


func _draw() -> void:
	if shown.is_empty() or viewer == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(viewer.global_position):
		return
	var c := get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(viewer.global_position + Vector3.UP * 1.0)
	var k := clampf(size.y / 900.0, 0.8, 1.2) if size.y > 1.0 else 1.0
	var r := RADIUS * k
	for s in shown:
		var info: Array = KINDS_A.get(String(s.kind), ["Son", RoyaleHudStyle.COMMON])
		var tones: Array = RoyaleHudStyle.danger() if String(s.kind) == "fight" else info[1]
		var a := float(s.alpha)
		var ang := float(s.angle)
		_arc(c, r, ang, 10.0 if float(s.dist) < 20.0 else 7.0, Color(tones[1], a))
		var label := String(info[0])
		var f := RoyaleHudStyle.text_font()
		var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var dir := Vector2.from_angle(ang)
		var at := c + dir * (r + 14.0 + absf(dir.x) * (tw * 0.5 + 9.0) + absf(dir.y) * 11.0)
		var box := Rect2(at - Vector2(tw * 0.5 + 9.0, 11.0), Vector2(tw + 18.0, 22.0))
		RoyaleHudStyle.draw_sticker(self, box, Color(RoyaleHudStyle.PAPER, a), 11.0, 2.0, 2.0)
		draw_string(f, Vector2(box.position.x + 9.0, at.y + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(RoyaleHudStyle.INK, a))
