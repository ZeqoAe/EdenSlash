class_name RoyaleHudStyle
extends RefCounted
## DA v2 « autocollant manga » du HUD de combat du Battle royale (lot BR-I1) : petites fonctions de dessin à la main
## (flèches, épingles, jauges, pastilles) pour `ui/royale_hud.gd`, `royale_edge.gd`, `royale_map.gd` et `hit_arc.gd`.
## Les boîtes et les boutons viennent d'UiTheme v2 (UiTheme.sticker, panel_style, style_button), les polices aussi
## (Mochiy Pop One, M PLUS Rounded 1c) ; les couleurs ci-dessous sont celles de data/ui_tokens.json (copie de
## conception/art/tokens.json). Les pages du lot BR-I2 ont leurs briques dans RoyaleStyle (mêmes couleurs).

const INK := Color("221a3a")  # encre-700 : contour de tout élément, texte sur papier, ombre dure
const WELL := Color("2e2450")  # encre-500 : puits (tuiles, jauges)
const INK_300 := Color("6b5e86")
const INK_100 := Color("c9bfea")
const PAPER := Color("fff8ec")
const PAPER_200 := Color("ffebc8")
const PAPER_300 := Color("e9dfcb")
const WHITE := Color.WHITE
## Bonbons : [clair, base, foncé].
const SUN := [Color("ffe27a"), Color("ffc928"), Color("d9900b")]
const MANDARIN := [Color("ffb566"), Color("ff8a1f"), Color("c85f08")]
const APPLE := [Color("c3f07a"), Color("8fd62e"), Color("4f8f10")]
const LAGOON := [Color("86ddff"), Color("22b8f0"), Color("0b7db5")]
const AMETHYST := [Color("dc92ff"), Color("b43beb"), Color("7a1db0")]
const STRAWBERRY := [Color("ff9db0"), Color("ff4d6d"), Color("c21e45")]
const COMMON := [Color("ece8f4"), Color("c9c3d6"), Color("8e86a6")]
const VEIL := Color(0.133, 0.102, 0.227, 0.35)  # voile-bilan #221A3A59

## Bandeaux, titres (Mochiy Pop One).
static func title_font() -> Font:
	return UiTheme.title_font()


## Chiffres du HUD (M PLUS Rounded 900).
static func num_font() -> Font:
	return UiTheme.number_font()


## Texte court, libellés (M PLUS Rounded 800).
static func text_font() -> Font:
	return UiTheme.bold_font()


## Contour d'encre selon la taille du texte (Bible § 4).
static func outline_for(size: int) -> int:
	return UiTheme.outline_for(size)


## Étiquette : texte clair contouré d'encre, ou [param on_paper] : texte encre sur papier, sans contour.
static func label(parent: Node, text: String, size: int, color := WHITE, font: Font = null, on_paper := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font != null else text_font())
	l.add_theme_font_size_override("font_size", maxi(size, UiTheme.MIN_TEXT))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0 if on_paper else outline_for(size) * 2)  # (Godot : des deux côtés)
	l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(l)
	return l


## Boîte autocollant d'UiTheme v2 ([param tone] : « papier », « nuit » (puits d'encre), « soleil »…) ; sans reflet ni
## deux tons pour les petites pièces du HUD ([param flat]), marges [param pad] (h, v), ombre dure [param shadow].
static func box(tone: String, pad := Vector2(12, 6), shadow := 4, radius := 14, flat := true) -> StyleBox:
	var opts := {"pad": pad, "shadow": shadow, "radius": radius}
	if flat:
		opts.merge({"gloss": false, "cel_top": 0.0, "cel_bottom": 0.0})
	return UiTheme.sticker(tone, opts)


## Rectangle arrondi « autocollant » dessiné à la main : ombre dure, fond, contour.
static func draw_sticker(ci: CanvasItem, rect: Rect2, fill: Color, radius := 12.0, shadow := 3.0, border := 3.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if shadow > 0.0:
		sb.bg_color = INK
		ci.draw_style_box(sb, Rect2(rect.position + Vector2(shadow, shadow), rect.size))
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(int(border))
	ci.draw_style_box(sb, rect)


## Jauge deux tons (cel) : creux d'encre, remplissage [param ratio] clair en haut, base, foncé en bas, bord droit d'encre.
static func draw_gauge(ci: CanvasItem, rect: Rect2, ratio: float, tones: Array) -> void:
	draw_sticker(ci, rect, WELL, minf(12.0, rect.size.y * 0.5), 3.0)
	var inner := rect.grow(-3.0)
	var w := inner.size.x * clampf(ratio, 0.0, 1.0)
	if w < 1.0:
		return
	var f := Rect2(inner.position, Vector2(w, inner.size.y))
	var top := f.size.y * 0.25
	var bottom := f.size.y * 0.3
	ci.draw_rect(Rect2(f.position, Vector2(w, top)), tones[0])
	ci.draw_rect(Rect2(f.position + Vector2(0, top), Vector2(w, f.size.y - top - bottom)), tones[1])
	ci.draw_rect(Rect2(f.position + Vector2(0, f.size.y - bottom), Vector2(w, bottom)), tones[2])
	if w < inner.size.x - 1.0:
		ci.draw_line(Vector2(f.end.x, f.position.y), Vector2(f.end.x, f.end.y), INK, 3.0)


## Trame manga (points) dans [param rect] : cases vides, états désactivés (Bible § 5, pas 7 px, point 1,3 px).
static func draw_halftone(ci: CanvasItem, rect: Rect2, color := Color(0.133, 0.102, 0.227, 0.16), step := 7.0, dot := 1.3) -> void:
	var y := rect.position.y + step * 0.5
	var row := 0
	while y < rect.end.y:
		var x := rect.position.x + step * (0.5 if row % 2 == 0 else 1.0)
		while x < rect.end.x:
			ci.draw_circle(Vector2(x, y), dot, color)
			x += step
		y += step
		row += 1


## Polygone plein contouré d'encre (flèches, épingles) : l'encre déborde de [param ink] px.
static func draw_inked_polygon(ci: CanvasItem, pts: PackedVector2Array, fill: Color, ink := 3.0) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color(INK, fill.a), ink * 2.0, true)
	ci.draw_colored_polygon(pts, fill)


## Texte contouré d'encre dessiné à la main.
static func draw_text(ci: CanvasItem, pos: Vector2, text: String, size: int, color := WHITE, font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var f := font if font != null else text_font()
	ci.draw_string_outline(f, pos, text, align, width, size, outline_for(size) * 2, INK)
	ci.draw_string(f, pos, text, align, width, size, color)


## Pastille de texte (pilule contourée) centrée sur [param center] ; renvoie son rectangle.
static func draw_pill(ci: CanvasItem, center: Vector2, text: String, fill := PAPER, size := 15, color := INK) -> Rect2:
	var f := text_font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 24.0
	var h := float(size) + 12.0
	var r := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	draw_sticker(ci, r, fill, h * 0.5, 3.0)
	ci.draw_string(f, Vector2(r.position.x + 12.0, center.y + size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return r


## Pastille de touche (Bible § 6 : A pomme, B fraise, X lagon, Y soleil ; autres : papier) avec son libellé.
static func draw_key(ci: CanvasItem, center: Vector2, key: String, size := 15) -> Rect2:
	var fills := {"A": APPLE[1], "B": STRAWBERRY[1], "X": LAGOON[1], "Y": SUN[1], "Croix": LAGOON[1], "Rond": STRAWBERRY[1],
		"Carré": AMETHYST[0], "Triangle": APPLE[1]}
	var f := num_font()
	var w := maxf(float(size) + 13.0, f.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 14.0)
	var h := float(size) + 13.0
	var r := Rect2(center - Vector2(w, h) * 0.5, Vector2(w, h))
	var round_key := fills.has(key)
	draw_sticker(ci, r, fills.get(key, PAPER), h * 0.5 if round_key else 8.0, 2.0)
	var tc := WHITE if round_key else INK
	if round_key:
		ci.draw_string_outline(f, Vector2(r.position.x, center.y + size * 0.36), key, HORIZONTAL_ALIGNMENT_CENTER, w, size, 4, INK)
	ci.draw_string(f, Vector2(r.position.x, center.y + size * 0.36), key, HORIZONTAL_ALIGNMENT_CENTER, w, size, tc)
	return r


## Couleurs [clair, base, foncé] de la famille de la classe [param cid] (Bible § 3) ; lilas-gris si elle est inconnue.
static func family_tones(cid: String) -> Array:
	var tones := [SUN, MANDARIN, APPLE, LAGOON, AMETHYST]  # familles 1 à 5 (Duel.family_of)
	var fam := Duel.family_of(cid) if cid != "" else 0
	return tones[fam - 1] if fam >= 1 and fam <= 5 else COMMON
