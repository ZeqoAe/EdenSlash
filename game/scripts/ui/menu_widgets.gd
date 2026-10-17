class_name MenuWidgets
extends RefCounted
## Éléments des menus (écran titre, menu principal) : logo, boutons à icône du menu
## de gauche, lignes de sous-menu (titre, sous-titre, chevron), panneaux.
## Style « autocollant manga » (UiTheme v2, bible § 5-6) : boutons du menu et lignes en papier (peau « sticker »,
## textes et icônes à l'encre) ou nuit, bouton primaire soleil, boutons secondaires nuit, panneaux = puits d'encre.
## Icônes de traits blancs (assets/ui/icons, tools/make_menu_icons.py), teintées.

const ICONS := "res://assets/ui/icons/%s.png"
const GLASS := Color(0.05, 0.06, 0.13, 0.84)
const LINE := Color(0.38, 0.38, 0.58, 0.85)
const ICON_TINT := Color(0.86, 0.84, 0.95)


static func icon(name: String) -> Texture2D:
	return UiTheme.texture(ICONS % name)


## Peau papier (« sticker ») : boutons du menu et lignes clairs, textes à l'encre.
static func paper() -> bool:
	return UiTheme.skin != "night"


## Puits d'encre (contour d'encre, ombre dure) ; [param border] autre que GOLD_DIM : liseré de mise en avant.
static func glass(radius := 12, border := UiTheme.GOLD_DIM, alpha := 0.84) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UiTheme.color("encre.500"), maxf(alpha, 0.9))
	sb.border_color = UiTheme.color("encre.900") if border == UiTheme.GOLD_DIM else border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius + 2)
	sb.anti_aliasing = true
	sb.shadow_color = Color(UiTheme.color("encre.900"), 0.85)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, 5)
	sb.set_content_margin_all(14)
	return sb


## Couleur des textes des boutons du menu et des lignes : encre sur papier, papier sur nuit ([param secondary] : plus doux).
static func ink_text(secondary := false) -> Color:
	if paper():
		return UiTheme.color("encre.300") if secondary else UiTheme.color("encre.700")
	return UiTheme.MUTED if secondary else UiTheme.TEXT


## Teinte des icônes blanches du menu sur le fond des boutons.
static func ink_tint() -> Color:
	return UiTheme.color("encre.700") if paper() else ICON_TINT


## Logo « Eden Slash » (Mochiy en casse mixte, plus étroite que les capitales de Cinzel : même encombrement) avec son filet.
static func logo(parent: Control, size := 72, centered := false) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(v)
	var t := Label.new()
	t.text = "Eden Slash"
	size = int(size * 0.92)
	UiTheme.title(t, size)  # Mochiy soleil, contour d'encre épais, ombre dure d'encre (autocollant)
	t.add_theme_color_override("font_shadow_color", UiTheme.color("encre.700"))
	t.add_theme_constant_override("shadow_offset_x", 0)
	t.add_theme_constant_override("shadow_offset_y", maxi(3, size / 14))
	t.add_theme_constant_override("shadow_outline_size", UiTheme.outline_for(size))
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


## Filet soleil contouré d'encre avec une étincelle à 4 branches au centre (comme les icônes du jeu).
class Ornament extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var y := size.y * 0.5
		var c := size.x * 0.5
		var ink := UiTheme.color("encre.700")
		for seg in [[size.x * 0.06, c - 16.0], [c + 16.0, size.x * 0.94]]:
			draw_line(Vector2(seg[0], y), Vector2(seg[1], y), ink, 6.0, true)
			draw_line(Vector2(seg[0], y), Vector2(seg[1], y), UiTheme.GOLD, 2.5, true)
		var star := PackedVector2Array()
		var out := PackedVector2Array()
		for i in 8:
			var a := PI * 0.25 * float(i) - PI * 0.5
			star.append(Vector2(c, y) + Vector2(cos(a), sin(a)) * (9.0 if i % 2 == 0 else 3.0))
			out.append(Vector2(c, y) + Vector2(cos(a), sin(a)) * (12.0 if i % 2 == 0 else 5.0))
		draw_colored_polygon(out, ink)
		draw_colored_polygon(star, Color.WHITE)


## Bouton du menu de gauche : icône, texte, chevron quand il est choisi.
class SideButton extends Button:
	var selected := false:
		set(v):
			selected = v
			_restyle()
	## Ton du bouton quand il n'est pas choisi ("" : papier ; « lagon » : action douce, comme « Continuer »).
	var accent := "":
		set(v):
			accent = v
			_restyle()
	var _icon: TextureRect
	var _label: Label
	var _chevron: Label
	var _badge: PanelContainer
	var _badge_label: Label
	var _style_key := ""

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
		# pastille de notification (coffres à ouvrir…)
		_badge = PanelContainer.new()  # pastille fraise contourée d'encre (bible § 5)
		_badge.add_theme_stylebox_override("panel", UiTheme.sticker("fraise", {"shadow": 2, "radius": 10, "gloss": false, "pad": Vector2(7, 0)}))
		_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_badge.visible = false
		_badge_label = Hud._label(_badge, "", 14, Color.WHITE)
		_badge_label.add_theme_font_override("font", UiTheme.number_font())
		_badge_label.add_theme_constant_override("outline_size", 3)
		_badge_label.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
		h.add_child(_badge)
		_chevron = Label.new()
		_chevron.text = "›"
		_chevron.add_theme_font_override("font", UiTheme.bold_font())
		_chevron.add_theme_font_size_override("font_size", int(height * 0.5))
		_chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_chevron.size_flags_vertical = Control.SIZE_FILL
		h.add_child(_chevron)
		mouse_entered.connect(_restyle)
		mouse_exited.connect(_restyle)
		button_down.connect(_place)
		button_up.connect(_place)
		_restyle()

	## Pastille à droite du texte ("" : aucune).
	func set_badge(text_value: String) -> void:
		_badge_label.text = text_value
		_badge.visible = text_value != ""

	func _restyle() -> void:
		if _label == null:
			return
		var paper := MenuWidgets.paper()
		var tone := "mandarine" if selected and accent != "" else ("lagon" if selected else (accent if accent != "" else ("papier" if paper else "nuit")))
		var key := tone + str(disabled)
		if key != _style_key:  # les boîtes ne changent qu'avec l'état choisi (le survol est dans la boîte « hover »)
			_style_key = key
			var st := UiTheme.button_states(tone, {"shadow": 4, "pad": Vector2(0, 0)})
			for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
				add_theme_stylebox_override(k, st[k])
			add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var ink := UiTheme.color("encre.700")
		var col := ink if (paper or selected or accent != "") else UiTheme.TEXT
		if disabled:
			col = UiTheme.color("texte.desactive")
		_label.add_theme_color_override("font_color", col)
		_icon.modulate = col
		_chevron.visible = selected
		_chevron.add_theme_color_override("font_color", ink)
		_place()

	## Le contenu suit la face de l'autocollant : monte de 3 px au survol, descend sur l'ombre à l'appui.
	func _place() -> void:
		if get_child_count() == 0:
			return
		var y := 4.0 if is_pressed() and not toggle_mode else (-3.0 if is_hovered() and not disabled else 0.0)
		var box := get_child(0) as Control
		box.offset_top = y
		box.offset_bottom = y - 4.0


## Ligne de sous-menu : icône, titre, sous-titre, chevron. [param height] est la hauteur minimale :
## la ligne grandit toute seule quand le texte prend plus de place (deux ou trois lignes).
class RowButton extends Button:
	const PAD := 18.0  # marge verticale autour du texte
	var _title: Label
	var _sub: Label
	var _icon: TextureRect
	var _box: StyleBox
	var _hover_box: StyleBox
	var _states := {}
	var _base_h := 72.0
	var _content: HBoxContainer

	func _init(title_text: String, sub_text: String, icon_name := "", height := 72.0) -> void:
		focus_mode = Control.FOCUS_NONE
		_base_h = height
		custom_minimum_size = Vector2(0, height)
		# autocollant papier (ou nuit) : contour d'encre, deux tons, ombre dure de 4 px
		_states = UiTheme.button_states("papier" if MenuWidgets.paper() else "nuit", {"shadow": 4, "radius": 14})
		_box = _states.normal
		_hover_box = _states.hover
		for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(k, _states[k])
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 16
		h.offset_right = -16
		h.offset_bottom = -4.0  # l'ombre dure
		h.add_theme_constant_override("separation", 16)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		_content = h
		h.minimum_size_changed.connect(_fit)
		if icon_name != "":
			_icon = TextureRect.new()
			_icon.texture = MenuWidgets.icon(icon_name) if not icon_name.begins_with("res://") else UiTheme.texture(icon_name)
			_icon.modulate = MenuWidgets.ink_tint() if not icon_name.begins_with("res://") else Color.WHITE
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
		_title = Hud._label(v, title_text, 18, MenuWidgets.ink_text())
		_title.add_theme_font_override("font", UiTheme.bold_font())
		_sub = Hud._label(v, sub_text, 13, MenuWidgets.ink_text(true))
		_sub.add_theme_font_override("font", UiTheme.label_font())
		_sub.visible = sub_text != ""
		_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_sub.custom_minimum_size.x = 120.0  # une largeur minimale pour que le retour à la ligne se calcule
		var ch := Hud._label(h, "›", 30, MenuWidgets.ink_text())
		ch.add_theme_font_override("font", UiTheme.bold_font())
		ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if MenuWidgets.paper():  # texte à l'encre sur papier : pas de contour (Hud._label en met un pour les fonds sombres)
			for l in [_title, _sub, ch]:
				l.add_theme_constant_override("outline_size", 0)
		mouse_entered.connect(_place)
		mouse_exited.connect(_place)
		button_down.connect(_place)
		button_up.connect(_place)

	func set_texts(title_text: String, sub_text: String) -> void:
		_title.text = title_text
		_sub.text = sub_text
		_sub.visible = sub_text != ""
		_fit()

	## Hauteur = celle du texte (le texte à la ligne ne connaît sa hauteur qu'une fois la largeur posée).
	func _fit() -> void:
		var need := _content.get_combined_minimum_size().y + PAD
		var want := maxf(_base_h, need)
		if absf(custom_minimum_size.y - want) > 0.5:
			custom_minimum_size.y = want

	## Le contenu suit la face de l'autocollant : monte de 3 px au survol, descend sur l'ombre à l'appui.
	func _place() -> void:
		var y := 4.0 if is_pressed() else (-3.0 if is_hovered() and not disabled else 0.0)
		_content.offset_top = y
		_content.offset_bottom = y - 4.0

	## Ligne choisie (classe, zone) : autocollant lagon (sélection), textes à l'encre.
	func mark(on: bool) -> void:
		var st: Dictionary = UiTheme.button_states("lagon", {"shadow": 4, "radius": 14}) if on else _states
		add_theme_stylebox_override("normal", st.normal)
		add_theme_stylebox_override("hover", st.hover)
		var ink := UiTheme.color("encre.700")
		_title.add_theme_color_override("font_color", ink if on else MenuWidgets.ink_text())
		_sub.add_theme_color_override("font_color", UiTheme.color("encre.900") if on else MenuWidgets.ink_text(true))


## Gros bouton primaire (Jouer, Lancer) : autocollant soleil, Mochiy blanc contouré d'encre, ressenti « primaire ».
static func gold_button(text: String, font_size := 30, min_size := Vector2(420, 80)) -> Button:
	var b := Button.new()
	b.pressed.connect(func(): Sfx.ui("confirm", -6.0))
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	UiTheme.style_button(b, "soleil", font_size, {"shadow": 5})
	return b


## Bouton secondaire papier (texte à l'encre) : sur la scène 3D ou sur un panneau papier (écran titre, bilans).
static func paper_button(text: String, font_size := 20, min_size := Vector2(320, 52)) -> Button:
	var b := glass_button(text, font_size, min_size)
	UiTheme.style_button(b, "papier", font_size)
	return b


## Bouton secondaire : autocollant nuit (texte clair contouré), lisible sur les puits d'encre des pages.
static func glass_button(text: String, font_size := 20, min_size := Vector2(320, 52)) -> Button:
	var b := Button.new()
	b.pressed.connect(func(): Sfx.ui("click", -8.0))
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	UiTheme.style_button(b, "nuit", font_size)
	return b
