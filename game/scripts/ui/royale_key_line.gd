class_name RoyaleKeyLine
extends Control
## Ligne d'aide sur une pastille de papier, touches dessinées (lot BR-I3, Bible § 6 : « Touches : pastilles rondes de
## couleur ») : « [Espace] Sauter · saut auto dans 9 s » devient une pastille Espace suivie du texte. Sert à l'aide du
## largage (RoyaleDropHint) et au bandeau du spectateur (RoyaleRecap). Taille minimale = celle du texte.

const PAD := Vector2(16, 8)

var text := ""
var font_size := 17
var fill := RoyaleHudStyle.PAPER


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_text(t: String) -> void:
	if t == text:
		return
	text = t
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	if text == "":
		return Vector2.ZERO
	return Vector2(RoyaleHudStyle.key_line_width(text, font_size), float(font_size) + 13.0) + PAD * 2.0 + Vector2(4, 4)


func _draw() -> void:
	if text == "":
		return
	var r := Rect2(Vector2.ZERO, size - Vector2(4, 4))
	RoyaleHudStyle.draw_sticker(self, r, fill, 16.0, 4.0)
	var w := RoyaleHudStyle.key_line_width(text, font_size)
	RoyaleHudStyle.draw_key_line(self, Vector2(r.position.x + (r.size.x - w) * 0.5, r.get_center().y), text, font_size)
