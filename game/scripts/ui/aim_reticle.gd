class_name AimReticle
extends Control
## Réticule de visée : un petit repère à la position de la souris, en jeu, quand le héros vise au curseur
## (visée « Curseur » ou mode « Action »). Point, croix ou cercle, taille et couleur au choix (Paramètres >
## Caméra & interface). Jamais gênant : aucun clic ne passe par lui, le centre reste vide (croix, cercle),
## trait cerné de sombre pour se lire sur un fond clair comme sombre. Créé par Settings (un calque au-dessus
## de l'interface), absent des lancements sans fenêtre.

const SHAPES := [["dot", "Point"], ["cross", "Croix"], ["circle", "Cercle"], ["off", "Aucun"]]
const COLORS := [["gold", "Or", UiTheme.GOLD], ["white", "Blanc", Color(1, 1, 1)], ["cyan", "Cyan", Color(0.35, 0.9, 1.0)],
	["red", "Rouge", Color(1.0, 0.3, 0.3)], ["green", "Vert", Color(0.45, 0.95, 0.5)], ["violet", "Violet", Color(0.75, 0.55, 1.0)]]
const DEFAULT_SHAPE := "dot"
const DEFAULT_COLOR := "gold"
const SIZE_MIN := 0.6
const SIZE_MAX := 2.0
const BOX := 64.0


## Forme choisie ; une valeur inconnue redonne le défaut.
static func shape() -> String:
	var s := str(Settings.get_v("interface", "reticle"))
	return s if SHAPES.any(func(e): return e[0] == s) else DEFAULT_SHAPE


static func size_factor() -> float:
	var v: Variant = Settings.get_v("interface", "reticle_size")
	return clampf(float(v), SIZE_MIN, SIZE_MAX) if (v is float or v is int) else 1.0


static func color() -> Color:
	var c := str(Settings.get_v("interface", "reticle_color"))
	for e in COLORS:
		if e[0] == c:
			return e[2]
	return UiTheme.GOLD


## Faut-il montrer le réticule maintenant : un héros en jeu, visée au curseur, pas en pause ni à la manette.
static func wanted(tree: SceneTree) -> bool:
	if shape() == "off" or not Settings.cursor_aim() or Gamepad.active or tree.paused:
		return false
	return tree.get_first_node_in_group("player") != null


## Dessine la forme [param shape] centrée en [param c] sur [param ci] (jeu et aperçu des Paramètres).
static func draw_shape(ci: CanvasItem, c: Vector2, shape_id: String, factor: float, col: Color) -> void:
	var ink := Color(0.04, 0.03, 0.09, 0.85)
	match shape_id:
		"dot":
			var r := 2.8 * factor
			ci.draw_circle(c, r + 1.7, ink)
			ci.draw_circle(c, r, col)
		"cross":
			var gap := 4.0 * factor
			var far := 11.0 * factor
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * (gap - 1.0), c + d * (far + 1.0), ink, 4.4, true)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * gap, c + d * far, col, 2.0, true)
		"circle":
			var r := 10.0 * factor
			ci.draw_arc(c, r, 0.0, TAU, 48, ink, 4.2, true)
			ci.draw_arc(c, r, 0.0, TAU, 48, col, 2.0, true)
			ci.draw_circle(c, 1.6, ink)
			ci.draw_circle(c, 0.9, col)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(BOX, BOX)
	visible = false


func _process(_delta: float) -> void:
	var on := wanted(get_tree()) and DisplayServer.window_is_focused()
	if on:
		var mp := get_viewport().get_mouse_position()
		position = (mp - size * 0.5).round()
		queue_redraw()
	if on != visible:
		visible = on


func _draw() -> void:
	draw_shape(self, size * 0.5, shape(), size_factor(), color())
