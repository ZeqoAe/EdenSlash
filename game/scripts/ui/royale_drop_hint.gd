class_name RoyaleDropHint
extends Control
## Aide du largage du Battle royale dans la DA v2 (lot BR-I3, spec v2 § 7 n° 3) : remplace la ligne de texte de Hud.
## - en bas au centre, l'aide sur une pastille de papier, touches dessinées (RoyaleKeyLine : « [Espace] Sauter ») ;
## - pendant la chute et le planeur, un altimètre à droite du héros : hauteur au-dessus du sol et cran d'ouverture seule
##   du planeur (la distance au repère est sur son épingle, RoyaleEdge).

const ALT_H := 220.0  # hauteur de la jauge (à 1600×900)
const ALT_W := 18.0

var player: Player
var director: RunDirector
var line: RoyaleKeyLine
var height := -1.0  # hauteur du héros au-dessus du sol pendant la chute (-1 : au sol ou à bord)
var _shown_h := -2.0


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	name = "RoyaleDropHint"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -280  # (juste au-dessus de la barre d'action, loin du héros au centre)
	holder.offset_bottom = -224
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	line = RoyaleKeyLine.new()
	line.font_size = 19
	holder.add_child(line)


## Mise à jour (RoyaleHud.tick) ; [param hidden] : la grande carte du vol est ouverte (elle dit déjà tout).
func update(hidden: bool) -> void:
	var rd: RoyaleDirector = director.royale if director != null else null
	var txt: String = rd.drop_hint() if rd != null else ""
	line.set_text("" if hidden else txt)
	line.visible = txt != "" and not hidden
	height = -1.0
	if rd != null and rd.jump != null and rd.jump.airborne(player) and not rd.jump.on_board(player) and not hidden:
		var p := player.global_position
		height = maxf(0.0, p.y - float(director.map.height_at(p.x, p.z)))
	if absf(height - _shown_h) > 0.4:
		_shown_h = height
		queue_redraw()


func _draw() -> void:
	if height < 0.0:
		return
	var k := clampf(size.y / 900.0, 0.8, 1.2) if size.y > 1.0 else 1.0
	var h := ALT_H * k
	var r := Rect2(Vector2(size.x * 0.5 + 260.0 * k, size.y * 0.5 - h * 0.5 - 70.0 * k), Vector2(ALT_W, h))  # (au-dessus de l'aide)
	var top_alt := RoyaleDrop.ALT + 10.0
	RoyaleHudStyle.draw_sticker(self, r, RoyaleHudStyle.WELL, 9.0, 3.0)
	var inner := r.grow(-3.0)
	var fill := clampf(height / top_alt, 0.0, 1.0)
	var glide: bool = height <= RoyaleDrop.GLIDE_AT + 0.5
	var tones: Array = RoyaleHudStyle.LAGOON if glide else RoyaleHudStyle.SUN
	var fr := Rect2(Vector2(inner.position.x, inner.end.y - inner.size.y * fill), Vector2(inner.size.x, inner.size.y * fill))
	draw_rect(fr, tones[1])
	draw_rect(Rect2(fr.position, Vector2(fr.size.x * 0.35, fr.size.y)), tones[0])
	# cran : le planeur s'ouvre seul ici
	var gy := inner.end.y - inner.size.y * clampf(RoyaleDrop.GLIDE_AT / top_alt, 0.0, 1.0)
	draw_line(Vector2(r.position.x - 6.0, gy), Vector2(r.end.x + 6.0, gy), RoyaleHudStyle.INK, 3.0)
	RoyaleHudStyle.draw_text(self, Vector2(r.end.x + 10.0, gy + 5.0), "planeur", 15, RoyaleHudStyle.LAGOON[0])
	# hauteur : pastille qui suit le niveau
	var hy := inner.end.y - inner.size.y * fill
	RoyaleHudStyle.draw_pill(self, Vector2(r.end.x + 44.0, clampf(hy, r.position.y + 10.0, gy - 22.0) if not glide else hy), "%d m" % roundi(height),
		RoyaleHudStyle.PAPER, 16, RoyaleHudStyle.INK)
