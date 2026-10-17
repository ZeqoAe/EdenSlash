class_name NewsDot
extends Control
## Pastille de nouveauté posée dans le coin d'un bouton, d'un onglet ou d'une carte de Jouer (lot HUB-1, P0-1) :
## « ! » mandarine (nouveau), un nombre fraise (compteur), une coche pomme (action possible). Elle lit NewsDots
## ([member groups]) et se met à jour seule une fois par seconde tant qu'elle est visible ; [method refresh] la met à
## jour tout de suite. Couleurs : jetons v2 de `data/ui_tokens.json` (bonbon.*.base, encre.700), à reprendre par
## UiTheme v2 quand le socle UIK-0 sera là.

const NEW := Color("#FF8A1F")  # bonbon.mandarine.base : nouveauté
const COUNT := Color("#FF4D6D")  # bonbon.fraise.base : compteur
const ACTION := Color("#8FD62E")  # bonbon.pomme.base : action possible
const INK := Color("#221A3A")  # encre.700 : contour
const R := 11.0

var groups: Array = []  # groupes de NewsDots additionnés ; vide : texte posé à la main (set_text)
var counter := false  # vrai : le nombre (fraise) ; faux : « ! » (mandarine)
var with_action := false  # une action possible (NewsDots.action) donne la coche pomme
var text := ""
var tone := NEW
var _t := 0.0


## Pastille dans le coin haut droit de [param parent] (décalée de [param inset] vers l'intérieur).
static func attach(parent: Control, group_list: Array, as_counter := false, inset := Vector2(4, 4)) -> NewsDot:
	var d := NewsDot.new()
	d.groups = group_list
	d.counter = as_counter
	d.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	d.offset_left = -R * 2.0 - inset.x
	d.offset_right = -inset.x
	d.offset_top = inset.y
	d.offset_bottom = inset.y + R * 2.0
	parent.add_child(d)
	d.refresh()
	return d


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(R * 2.0, R * 2.0)
	visible = false


## Texte posé à la main ("" : cachée).
func set_text(t: String, color := NEW) -> void:
	text = t
	tone = color
	visible = t != ""
	queue_redraw()


func refresh() -> void:
	if groups.is_empty():
		return
	var n := NewsDots.count_of(groups)
	if n > 0:
		set_text((str(n) if n < 10 else "9+") if counter else "!", COUNT if counter else NEW)
	elif with_action and groups.any(func(g): return NewsDots.action(String(g))):
		set_text("✓", ACTION)
	else:
		set_text("")


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or groups.is_empty():
		return
	_t = 1.0
	if get_parent() is CanvasItem and (get_parent() as CanvasItem).is_visible_in_tree():
		refresh()


func _draw() -> void:
	if text == "":
		return
	var font := UiTheme.bold_font()
	var fs := 14 if text.length() < 2 else 12
	var w := maxf(R * 2.0, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0)
	var rect := Rect2(Vector2(size.x - w, 0.0), Vector2(w, R * 2.0))
	var sb := StyleBoxFlat.new()
	sb.bg_color = tone
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(R))
	sb.shadow_color = Color(INK, 0.6)
	sb.shadow_offset = Vector2(0, 2)
	sb.shadow_size = 0
	draw_style_box(sb, rect)
	var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := rect.position + Vector2((rect.size.x - ts.x) * 0.5, (rect.size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, INK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
