class_name CardPicker
extends CanvasLayer
## Choix de cartes (nouvelle compétence, amélioration, passif) au passage de
## niveau et au départ de la run. Met le jeu en pause pendant le choix.

signal picked(card: Dictionary)

const ACCENT := Color(0.98, 0.78, 0.35)
const TYPE_COLORS := {"skill": Color(1.0, 0.55, 0.3), "upgrade": Color(0.45, 0.75, 1.0), "passive": Color(0.6, 0.95, 0.55)}

var _queue: Array = []  # [titre, cartes]
var _cards: Array = []
var _root: Control
var _title: Label
var _row: HBoxContainer


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	v.position = Vector2(-560, -230)
	v.custom_minimum_size = Vector2(1120, 0)
	_root.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	_title.add_theme_color_override("font_color", ACCENT)
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	v.add_child(_title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 28)
	v.add_child(_row)
	var hint := Label.new()
	hint.text = "Clique sur une carte ou appuie sur 1, 2, 3"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.7)
	v.add_child(hint)
	_root.visible = false
	add_child(_root)


## Ajoute un choix à la file (plusieurs niveaux d'un coup = plusieurs choix).
func offer(title: String, cards: Array) -> void:
	if cards.is_empty():
		return
	_queue.append([title, cards])
	if not _root.visible:
		_show_next()


func is_open() -> bool:
	return _root.visible


func _show_next() -> void:
	if _queue.is_empty():
		_root.visible = false
		get_tree().paused = false
		return
	var item: Array = _queue.pop_front()
	_title.text = item[0]
	_cards = item[1]
	for c in _row.get_children():
		c.queue_free()
	for i in _cards.size():
		_row.add_child(_make_card(_cards[i], i))
	_root.visible = true
	get_tree().paused = true


func _make_card(card: Dictionary, i: int) -> Control:
	var col: Color = TYPE_COLORS.get(card.type, ACCENT)
	var b := Button.new()
	b.custom_minimum_size = Vector2(320, 380)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.08, 0.15, 0.97)
	sb.border_color = col
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.13, 0.25, 1.0)
	hover.set_border_width_all(5)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.pressed.connect(_choose.bind(i))
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_right = -18
	v.offset_top = 18
	v.offset_bottom = -18
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var key := Label.new()
	key.text = "%d · %s" % [i + 1, card.subtitle]
	key.add_theme_color_override("font_color", col)
	key.add_theme_font_size_override("font_size", 16)
	v.add_child(key)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(96, 96)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if String(card.get("icon", "")) != "" and ResourceLoader.exists(card.icon):
		icon.texture = load(card.icon)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)
	var t := Label.new()
	t.text = card.title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 22)
	v.add_child(t)
	var d := Label.new()
	d.text = card.desc
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override("font_size", 15)
	d.modulate = Color(0.92, 0.92, 0.95)
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	return b


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or not event is InputEventKey or not event.pressed:
		return
	var n: int = event.physical_keycode - KEY_1
	if n >= 0 and n < _cards.size():
		_choose(n)
		get_viewport().set_input_as_handled()


func _choose(i: int) -> void:
	var card: Dictionary = _cards[i]
	Run.apply_card(card)
	picked.emit(card)
	_show_next()
