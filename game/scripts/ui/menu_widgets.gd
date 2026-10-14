class_name MenuWidgets
extends RefCounted
## Éléments des menus (écran titre, menu principal) : logo, boutons à icône du menu
## de gauche, lignes de sous-menu (titre, sous-titre, chevron), panneaux translucides.
## Icônes de traits blancs (assets/ui/icons, tools/make_menu_icons.py), teintées.

const ICONS := "res://assets/ui/icons/%s.png"
const GLASS := Color(0.05, 0.06, 0.13, 0.84)
const LINE := Color(0.38, 0.38, 0.58, 0.85)
const ICON_TINT := Color(0.86, 0.84, 0.95)


static func icon(name: String) -> Texture2D:
	return UiTheme.texture(ICONS % name)


## Panneau translucide à bord doré.
static func glass(radius := 12, border := UiTheme.GOLD_DIM, alpha := 0.84) -> StyleBoxFlat:
	var sb := UiTheme.flat_box(Color(GLASS, alpha), border, 2, radius)
	sb.set_content_margin_all(14)
	return sb


## Logo « EDEN SLASH » avec son filet orné.
static func logo(parent: Control, size := 72, centered := false) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	var t := Label.new()
	t.text = "EDEN SLASH"
	UiTheme.title(t, size)
	t.add_theme_color_override("font_outline_color", Color(0.18, 0.08, 0.02))
	t.add_theme_constant_override("outline_size", maxi(6, size / 7))
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	t.add_theme_constant_override("shadow_offset_y", 4)
	v.add_child(t)
	var orn := Ornament.new()
	orn.custom_minimum_size = Vector2(size * 6.4, 14)
	v.add_child(orn)
	if centered:
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		orn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		orn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return v


## Filet doré avec un losange au centre.
class Ornament extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var c := size.x * 0.5
		draw_line(Vector2(size.x * 0.04, y), Vector2(c - 14, y), Color(UiTheme.GOLD, 0.9), 2.0, true)
		draw_line(Vector2(c + 14, y), Vector2(size.x * 0.96, y), Color(UiTheme.GOLD, 0.9), 2.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(c, y - 7), Vector2(c + 9, y), Vector2(c, y + 7), Vector2(c - 9, y)]), UiTheme.GOLD)
		draw_circle(Vector2(size.x * 0.04, y), 2.5, UiTheme.GOLD)
		draw_circle(Vector2(size.x * 0.96, y), 2.5, UiTheme.GOLD)


## Bouton du menu de gauche : icône, texte, chevron quand il est choisi.
class SideButton extends Button:
	var selected := false:
		set(v):
			selected = v
			_restyle()
	var _icon: TextureRect
	var _label: Label
	var _chevron: Label

	func _init(text_value: String, icon_name: String, height := 62.0) -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(300, height)
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 14
		h.offset_right = -14
		h.add_theme_constant_override("separation", 16)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		_icon = TextureRect.new()
		_icon.texture = MenuWidgets.icon(icon_name)
		_icon.custom_minimum_size = Vector2(height * 0.58, height * 0.58)
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(_icon)
		_label = Label.new()
		_label.text = text_value
		_label.add_theme_font_override("font", UiTheme.bold_font())
		_label.add_theme_font_size_override("font_size", int(height * 0.36))
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.size_flags_vertical = Control.SIZE_FILL
		h.add_child(_label)
		_chevron = Label.new()
		_chevron.text = "›"
		_chevron.add_theme_font_override("font", UiTheme.bold_font())
		_chevron.add_theme_font_size_override("font_size", int(height * 0.5))
		_chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_chevron.size_flags_vertical = Control.SIZE_FILL
		h.add_child(_chevron)
		mouse_entered.connect(_restyle)
		mouse_exited.connect(_restyle)
		_restyle()

	func _restyle() -> void:
		if _label == null:
			return
		var hover := is_hovered()
		var sb := UiTheme.flat_box(Color(0.1, 0.09, 0.2, 0.92) if selected else Color(MenuWidgets.GLASS, 0.8 if not hover else 0.92),
			UiTheme.GOLD if selected else (UiTheme.GOLD_DIM if hover else MenuWidgets.LINE), 3 if selected else (2 if hover else 1), 12)
		if selected:
			sb.shadow_color = Color(UiTheme.GOLD, 0.45)
			sb.shadow_size = 10
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, sb)
		_label.add_theme_color_override("font_color", Color(1, 0.96, 0.86) if selected or hover else UiTheme.TEXT)
		_icon.modulate = UiTheme.GOLD if selected else MenuWidgets.ICON_TINT
		_chevron.visible = selected
		_chevron.add_theme_color_override("font_color", UiTheme.GOLD)


## Ligne de sous-menu : icône, titre, sous-titre, chevron.
class RowButton extends Button:
	var _title: Label
	var _sub: Label
	var _icon: TextureRect
	var _box: StyleBoxFlat
	var _hover_box: StyleBoxFlat

	func _init(title_text: String, sub_text: String, icon_name := "", height := 72.0) -> void:
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, height)
		_box = UiTheme.flat_box(Color(0.07, 0.08, 0.17, 0.9), MenuWidgets.LINE, 1, 10, false)
		_hover_box = UiTheme.flat_box(Color(0.13, 0.12, 0.26, 0.96), UiTheme.GOLD_DIM, 2, 10, false)
		add_theme_stylebox_override("normal", _box)
		add_theme_stylebox_override("hover", _hover_box)
		add_theme_stylebox_override("pressed", _hover_box)
		add_theme_stylebox_override("disabled", _box)
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 16
		h.offset_right = -16
		h.add_theme_constant_override("separation", 16)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		if icon_name != "":
			_icon = TextureRect.new()
			_icon.texture = MenuWidgets.icon(icon_name) if not icon_name.begins_with("res://") else UiTheme.texture(icon_name)
			_icon.modulate = MenuWidgets.ICON_TINT if not icon_name.begins_with("res://") else Color.WHITE
			_icon.custom_minimum_size = Vector2(height * 0.5, height * 0.5)
			_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(_icon)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		_title = Hud._label(v, title_text, 18, UiTheme.TEXT)
		_title.add_theme_font_override("font", UiTheme.bold_font())
		_sub = Hud._label(v, sub_text, 13, UiTheme.MUTED)
		_sub.visible = sub_text != ""
		_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var ch := Hud._label(h, "›", 30, UiTheme.TEXT)
		ch.add_theme_font_override("font", UiTheme.bold_font())
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_texts(title_text: String, sub_text: String) -> void:
		_title.text = title_text
		_sub.text = sub_text
		_sub.visible = sub_text != ""

	## Ligne choisie (classe, zone) : cadre doré.
	func mark(on: bool) -> void:
		var sb := UiTheme.flat_box(Color(0.14, 0.11, 0.24, 0.96), UiTheme.GOLD, 2, 10, false) if on else _box
		add_theme_stylebox_override("normal", sb)
		_title.add_theme_color_override("font_color", UiTheme.GOLD if on else UiTheme.TEXT)


## Gros bouton doré (Jouer, Lancer).
static func gold_button(text: String, font_size := 30, min_size := Vector2(420, 80)) -> Button:
	var b := Button.new()
	b.pressed.connect(func(): Sfx.ui("confirm", -6.0))
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", UiTheme.title_font())
	b.add_theme_font_size_override("font_size", font_size)
	var n := UiTheme.flat_box(Color(0.42, 0.27, 0.07, 0.96), UiTheme.GOLD, 3, 14)
	n.shadow_color = Color(UiTheme.GOLD, 0.35)
	n.shadow_size = 12
	var hv := UiTheme.flat_box(Color(0.58, 0.38, 0.1, 1.0), Color(1, 0.92, 0.62), 3, 14)
	hv.shadow_color = Color(UiTheme.GOLD, 0.6)
	hv.shadow_size = 18
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.95))
	b.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.0))
	b.add_theme_constant_override("outline_size", 6)
	return b


## Bouton secondaire translucide.
static func glass_button(text: String, font_size := 20, min_size := Vector2(320, 52)) -> Button:
	var b := Button.new()
	b.pressed.connect(func(): Sfx.ui("click", -8.0))
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_override("font", UiTheme.bold_font())
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(MenuWidgets.GLASS, 0.82), MenuWidgets.LINE, 1, 12))
	b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.13, 0.12, 0.26, 0.95), UiTheme.GOLD_DIM, 2, 12))
	b.add_theme_stylebox_override("pressed", UiTheme.flat_box(Color(0.13, 0.12, 0.26, 0.95), UiTheme.GOLD, 2, 12))
	return b
