class_name MenaceBadge
extends PanelContainer
## Pastille du HUD sous les objectifs (passe P12) : « Menace ×1,2 » quand un géant a été vaincu, « Pacte » pendant
## un pacte de cupidité. Le détail chiffré est dans l'infobulle (le texte permanent n'en porte pas). Cachée hors de
## la carte de run (Duel, Tour, Battle royale, entraînement) et quand il n'y a ni Menace ni pacte.

const MENACE_COLOR := Color(1.0, 0.45, 0.32)
const PACT_COLOR := Color(1.0, 0.82, 0.3)

var director: RunDirector
var _menace: Label
var _pact: Label
var _sig := ""
var _t := 0.0


## Pastille ajoutée dans la pile en haut à gauche du HUD ([param stack]), juste sous les objectifs.
static func attach(stack: Control, d: RunDirector) -> MenaceBadge:
	var b := MenaceBadge.new()
	b.director = d
	stack.add_child(b)
	return b


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.1, 0.04, 0.07, 0.86), Color(MENACE_COLOR, 0.7), 1, 10))
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP  # infobulle
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	_menace = _chip(h, MENACE_COLOR)
	_pact = _chip(h, PACT_COLOR)
	visible = false


func _chip(parent: Control, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.05))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.25
	refresh()


## Met la pastille à jour (appelée 4 fois par seconde).
func refresh() -> void:
	var on_map := director != null and director.map != null and director.state in ["explore", "rage", "boss", "cleared"] \
		and not (Duel.active or Tower.active or Royale.active or Training.active)
	var pact: bool = on_map and director.greed
	var lvl := Menace.level if on_map else 0
	var sig := "%d|%s|%s" % [lvl, pact, on_map]
	if sig == _sig:
		return
	_sig = sig
	visible = on_map and (lvl > 0 or pact)
	_menace.visible = lvl > 0
	_menace.text = "☠ Menace %s" % Menace.mult_text()
	_pact.visible = pact
	_pact.text = "⚖ Pacte"
	tooltip_text = Menace.tooltip(pact)
