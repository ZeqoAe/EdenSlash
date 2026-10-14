class_name UiTheme
extends RefCounted
## Style visuel commun de l'interface : palette or sur indigo, polices (Cinzel pour
## les titres, Nunito pour le texte), cadres ornés (tools/make_ui_assets.py) et
## thème global appliqué à toute l'interface au démarrage (Settings).
##
## Les polices et les cadres dessinés n'ont pas besoin d'être importés par l'éditeur :
## sans import, ils sont lus directement depuis les fichiers.

const GOLD := Color(0.98, 0.78, 0.35)
const GOLD_DIM := Color(0.72, 0.55, 0.26)
const INK := Color(0.05, 0.04, 0.09)
const PANEL_BG := Color(0.09, 0.07, 0.16, 0.94)
const TEXT := Color(0.95, 0.93, 0.98)
const MUTED := Color(0.72, 0.70, 0.80)
const HP := Color(0.9, 0.16, 0.24)
const BUFF := Color(0.45, 0.92, 0.55)
const DEBUFF := Color(1.0, 0.36, 0.36)

const FONT_TITLE := "res://assets/fonts/Cinzel-Bold.woff2"
const FONT_BODY := "res://assets/fonts/Nunito-SemiBold.woff2"
const FONT_BOLD := "res://assets/fonts/Nunito-ExtraBold.woff2"
const FRAME_PANEL := "res://assets/ui/frame/panel.png"
const FRAME_SLOT := "res://assets/ui/frame/slot.png"

static var _textures := {}
static var _fonts := {}


# --- chargement --------------------------------------------------------------------------
## Texture d'un fichier image : ressource importée si possible, sinon lecture directe.
static func texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _textures.has(path):
		return _textures[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path) and FileAccess.file_exists(path + ".import"):
		tex = load(path) as Texture2D
	if tex == null and FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(path)) == OK:
			tex = ImageTexture.create_from_image(img)
	_textures[path] = tex
	return tex


static func font(path: String) -> Font:
	if _fonts.has(path):
		return _fonts[path]
	var f: Font = null
	if ResourceLoader.exists(path) and FileAccess.file_exists(path + ".import"):
		f = load(path) as Font
	if f == null and FileAccess.file_exists(path):
		var ff := FontFile.new()
		if ff.load_dynamic_font(ProjectSettings.globalize_path(path)) == OK:
			f = ff
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[path] = f
	return f


static func title_font() -> Font:
	return font(FONT_TITLE)


static func body_font() -> Font:
	return font(FONT_BODY)


static func bold_font() -> Font:
	return font(FONT_BOLD)


## Titre en Cinzel avec contour sombre.
static func title(label: Label, size := 28, color := GOLD) -> Label:
	label.add_theme_font_override("font", title_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", maxi(6, size / 4))
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.12))
	return label


# --- cadres ------------------------------------------------------------------------------
## Panneau orné (fond indigo dégradé, double filet doré, coins en losange).
static func panel_box(margin_h := 16, margin_v := 12) -> StyleBox:
	var tex := texture(FRAME_PANEL)
	if tex == null:
		var flat := flat_box(PANEL_BG, GOLD, 2, 12)
		flat.content_margin_left = margin_h
		flat.content_margin_right = margin_h
		flat.content_margin_top = margin_v
		flat.content_margin_bottom = margin_v
		return flat
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 24)
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	return sb


static func flat_box(bg: Color, border := GOLD_DIM, width := 2, radius := 8, shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 5
		sb.shadow_offset = Vector2(0, 2)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


# --- thème global ------------------------------------------------------------------------
## Appliqué une fois au démarrage : polices et styles par défaut de tous les contrôles
## (les écrans qui définissent leurs propres styles les gardent).
static func apply_global() -> void:
	var body := body_font()
	ThemeDB.fallback_font = body
	ThemeDB.fallback_font_size = 16
	var t := ThemeDB.get_default_theme()
	t.default_font = body
	t.default_font_size = 16
	t.merge_with(build_theme())
	_add_version_overlay()


## Numéro de version discret en bas à droite de tous les écrans.
static func _add_version_overlay() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.name = "VersionOverlay"
	var l := Label.new()
	l.text = "Alt + clic droit : noter un problème   ·   " + Version.label()
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.anchor_left = 1.0
	l.anchor_top = 1.0
	l.anchor_right = 1.0
	l.anchor_bottom = 1.0
	l.offset_left = -520.0
	l.offset_top = -22.0
	l.offset_right = -8.0
	l.offset_bottom = -4.0
	layer.add_child(l)
	tree.root.add_child.call_deferred(layer)


static func build_theme() -> Theme:
	var t := Theme.new()
	var body := body_font()
	var bold := bold_font()
	t.set_font("normal_font", "RichTextLabel", body)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_color", "Label", TEXT)
	# boutons
	var normal := flat_box(Color(0.14, 0.11, 0.24, 0.96), GOLD_DIM, 2, 8)
	var hover := flat_box(Color(0.24, 0.18, 0.38, 1.0), GOLD, 2, 8)
	var pressed := flat_box(Color(0.32, 0.23, 0.12, 1.0), GOLD, 2, 8)
	var disabled := flat_box(Color(0.1, 0.09, 0.14, 0.85), Color(0.35, 0.33, 0.42), 1, 8, false)
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color(1, 0.95, 0.8))
		t.set_color("font_pressed_color", type, GOLD)
		t.set_color("font_disabled_color", type, Color(0.55, 0.53, 0.6))
		t.set_font("font", type, bold)
	# panneaux et onglets
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "TabContainer", flat_box(Color(0.08, 0.06, 0.14, 0.9), GOLD_DIM, 1, 8, false))
	t.set_stylebox("tab_selected", "TabContainer", _tab(Color(0.26, 0.19, 0.4), GOLD))
	t.set_stylebox("tab_unselected", "TabContainer", _tab(Color(0.11, 0.09, 0.18), Color(0.4, 0.33, 0.25)))
	t.set_stylebox("tab_hovered", "TabContainer", _tab(Color(0.2, 0.15, 0.3), GOLD_DIM))
	t.set_color("font_selected_color", "TabContainer", GOLD)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", TEXT)
	t.set_font("font", "TabContainer", bold)
	# menus déroulants, infobulles, champs, barres de défilement, curseurs
	var popup := flat_box(Color(0.08, 0.06, 0.14, 0.98), GOLD_DIM, 2, 8)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_stylebox("hover", "PopupMenu", flat_box(Color(0.26, 0.19, 0.4), GOLD, 1, 6, false))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", GOLD)
	t.set_stylebox("panel", "TooltipPanel", flat_box(Color(0.06, 0.05, 0.11, 0.97), GOLD, 2, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 15)
	t.set_stylebox("normal", "LineEdit", flat_box(Color(0.05, 0.04, 0.1, 0.95), GOLD_DIM, 1, 6, false))
	t.set_stylebox("focus", "LineEdit", flat_box(Color(0.05, 0.04, 0.1, 0.95), GOLD, 2, 6, false))
	# barres de défilement fines (6 px) et discrètes : la poignée s'allume au survol
	var thin := func(c: Color) -> StyleBoxFlat:
		var b := flat_box(c, Color(0, 0, 0, 0), 0, 3, false)
		b.content_margin_left = 3
		b.content_margin_right = 3
		b.content_margin_top = 3
		b.content_margin_bottom = 3
		return b
	for sb_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_type, thin.call(Color(0, 0, 0, 0.25)))
		t.set_stylebox("grabber", sb_type, thin.call(Color(GOLD_DIM, 0.55)))
		t.set_stylebox("grabber_highlight", sb_type, thin.call(GOLD))
		t.set_stylebox("grabber_pressed", sb_type, thin.call(GOLD))
	var track := flat_box(Color(0, 0, 0, 0.5), GOLD_DIM, 1, 4, false)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", flat_box(GOLD_DIM, Color(0, 0, 0, 0), 0, 4, false))
	t.set_stylebox("grabber_area_highlight", "HSlider", flat_box(GOLD, Color(0, 0, 0, 0), 0, 4, false))
	t.set_stylebox("background", "ProgressBar", flat_box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 6, false))
	t.set_stylebox("fill", "ProgressBar", flat_box(GOLD, Color(0, 0, 0, 0), 0, 6, false))
	# fenêtres de confirmation
	t.set_stylebox("embedded_border", "Window", panel_box())
	t.set_stylebox("panel", "AcceptDialog", flat_box(Color(0.08, 0.06, 0.14, 0.98), Color(0, 0, 0, 0), 0, 0, false))
	t.set_color("title_color", "Window", GOLD)
	t.set_font("title_font", "Window", title_font())
	return t


static func _tab(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := flat_box(bg, border, 2, 0, false)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.border_width_bottom = 0
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb
