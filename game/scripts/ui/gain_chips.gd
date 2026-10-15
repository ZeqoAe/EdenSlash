class_name GainChips
extends RefCounted
## Les gains propres à chaque activité (Activities.LIST, clé « gives ») en pastilles d'icônes : sur l'étiquette de la page
## Jouer (icônes seules), et sur la page de l'activité (icône et nom). Chaque pastille dit au survol où la ressource se
## trouve et à quoi elle sert (ResourceHelp). Une activité fermée les montre grisées.


## Une pastille : l'icône de la ressource ; [param with_name] ajoute son nom à droite.
static func chip(kind: String, px := 20, with_name := false, dim := false) -> Control:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_PASS  # le survol donne l'infobulle, le clic passe à l'étiquette dessous
	box.tooltip_text = ResourceHelp.tip(kind)
	var ic := TextureRect.new()
	ic.texture = ResourceHelp.icon(kind)
	ic.custom_minimum_size = Vector2(px, px)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.modulate = Color.WHITE if ResourceHelp.is_item_icon(kind) else MenuWidgets.ICON_TINT
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ic)
	if with_name:
		var l := Hud._label(box, ResourceHelp.name_of(kind), 14, UiTheme.TEXT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		box.modulate = Color(1, 1, 1, 0.45)
	return box


## Rangée d'icônes seules, sur un fond sombre (lisible sur l'illustration d'une étiquette).
static func icons(a: Dictionary, px := 20, dim := false) -> Control:
	var gives: Array = a.get("gives", [])
	if gives.is_empty():
		return null
	var p := PanelContainer.new()
	var sb := UiTheme.flat_box(Color(0.03, 0.02, 0.07, 0.78), Color(UiTheme.GOLD_DIM, 0.7), 1, 8, false)
	sb.set_content_margin_all(3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	p.add_child(h)
	for k in gives:
		h.add_child(chip(String(k), px, false, dim))
	return p


## « Donne : » puis les pastilles avec leur nom, sous le bandeau d'une page d'activité.
static func line(a: Dictionary, dim := false) -> Control:
	var gives: Array = a.get("gives", [])
	if gives.is_empty():
		return null
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 14)
	h.add_theme_constant_override("v_separation", 4)
	var l := Hud._label(h, "Donne", 14, UiTheme.MUTED)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in gives:
		h.add_child(chip(String(k), 20, true, dim))
	return h
