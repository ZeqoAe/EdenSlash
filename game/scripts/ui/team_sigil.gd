class_name TeamSigil
extends Control
## Blason d'équipe (lot MODE-0) : pastille autocollant de la couleur de l'équipe (contour d'encre 3 px, ombre cel, reflet)
## et son MOTIF en blanc contouré (rond, carré, triangle, losange, étoile, croix, hexagone, anneau). La couleur ne suffit
## jamais : le motif dit l'équipe aux daltoniens (jetons couleur.equipe, contrôle tools/team_palette_check.py).
##   var s := TeamSigil.make(t, 28)          # équipe t de la partie en cours (ou de la palette hors partie)
## Sert au classement, aux cadres des héros, aux annonces ; jamais aux barres de vie (pomme / fraise : TeamMatch.bar_color).

const MOTIFS := ["rond", "carre", "triangle", "losange", "etoile", "croix", "hexagone", "anneau"]

var team := 0:
	set(v):
		team = v
		queue_redraw()
## Motif imposé ("" : celui de l'équipe).
var motif_override := ""


static func make(t: int, px := 28) -> TeamSigil:
	var s := TeamSigil.new()
	s.team = t
	s.custom_minimum_size = Vector2(px, px)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5
	if r < 2.0:
		return
	var c := size * 0.5
	var ink := UiTheme.color("encre.700", Color("221A3A"))
	var line := clampf(r * 0.16, 1.5, 3.0)
	draw_circle(c + Vector2(0, line), r - 0.5, ink)  # ombre dure
	draw_circle(c, r - 0.5, ink)
	draw_circle(c, r - line, TeamMatch.color(team, "base"))
	# ombre cel du bas (38 %) et reflet du haut
	var shade := TeamMatch.color(team, "fonce")
	shade.a = 0.55
	draw_arc(c, (r - line) * 0.82, deg_to_rad(20), deg_to_rad(160), 18, shade, (r - line) * 0.32, true)
	var hl := Color(1, 1, 1, 0.75)
	draw_arc(c, (r - line) * 0.72, deg_to_rad(205), deg_to_rad(250), 8, hl, maxf(1.0, r * 0.1), true)
	var m := motif_override if motif_override != "" else TeamMatch.motif(team)
	var pts := shape(m, c, (r - line) * 0.55)
	if m == "anneau":
		draw_arc(c, (r - line) * 0.42, 0.0, TAU, 32, ink, (r - line) * 0.34, true)
		draw_arc(c, (r - line) * 0.42, 0.0, TAU, 32, Color.WHITE, (r - line) * 0.18, true)
	elif m == "rond":
		draw_circle(c, (r - line) * 0.46, ink)
		draw_circle(c, (r - line) * 0.46 - line * 0.7, Color.WHITE)
	elif not pts.is_empty():
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_colored_polygon(pts, Color.WHITE)
		draw_polyline(closed, ink, line * 0.8, true)


## Points du motif [param m] centré en [param c], rayon [param r] (vide pour rond et anneau, dessinés en cercles).
static func shape(m: String, c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match m:
		"carre":
			var h := r * 0.78
			pts = PackedVector2Array([c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)])
		"triangle":
			for i in 3:
				var a := -PI / 2.0 + TAU * i / 3.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * 1.05 + Vector2(0, r * 0.12))
		"losange":
			pts = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.72, 0), c + Vector2(0, r), c + Vector2(-r * 0.72, 0)])
		"etoile":
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r * 1.05 if i % 2 == 0 else r * 0.45))
		"croix":
			var w := r * 0.36
			pts = PackedVector2Array([c + Vector2(-w, -r), c + Vector2(w, -r), c + Vector2(w, -w), c + Vector2(r, -w), c + Vector2(r, w),
				c + Vector2(w, w), c + Vector2(w, r), c + Vector2(-w, r), c + Vector2(-w, w), c + Vector2(-r, w), c + Vector2(-r, -w),
				c + Vector2(-w, -w)])
		"hexagone":
			for i in 6:
				var a := TAU * i / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
