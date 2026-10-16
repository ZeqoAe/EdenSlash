class_name CursorPreview
extends Control
## Aperçu des Paramètres : les quatre formes du jeu de curseurs choisi (flèche, main, texte, poing) et le
## réticule de visée sur un fond clair et un fond sombre, aux réglages actuels. [method refresh] à chaque changement.

const ICON := 48.0
const SWATCH := Vector2(92, 44)

var _icons: Array[Texture2D] = []
var _classic := true


func _init() -> void:
	custom_minimum_size = Vector2(460, 54)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	_icons.clear()
	var id := CursorSets.current()
	_classic = id == CursorSets.DEFAULT
	if not _classic:
		for kind in CursorSets.SHAPES:
			var img := CursorSets.image(id, kind, 48)
			if img != null:
				_icons.append(ImageTexture.create_from_image(img))
	queue_redraw()


func _draw() -> void:
	var mid := size.y * 0.5
	if _icons.is_empty():
		var f := UiTheme.body_font()
		draw_string(f, Vector2(0, mid + 6), "Curseurs du système", HORIZONTAL_ALIGNMENT_LEFT, 220, UiTheme.text_size(16), UiTheme.MUTED)
	for i in _icons.size():
		draw_texture(_icons[i], Vector2(i * (ICON + 8), mid - ICON * 0.5))
	var x0 := size.x - SWATCH.x * 2.0 - 8.0
	for k in 2:
		var r := Rect2(Vector2(x0 + k * (SWATCH.x + 8.0), mid - SWATCH.y * 0.5), SWATCH)
		draw_rect(r, Color(0.9, 0.9, 0.93) if k == 0 else Color(0.09, 0.08, 0.16))
		draw_rect(r, Color(UiTheme.GOLD_DIM, 0.6), false, 1.0)
		AimReticle.draw_shape(self, r.get_center(), AimReticle.shape(), AimReticle.size_factor(), AimReticle.color())
