class_name UiTheme
extends RefCounted
## Style visuel commun de l'interface, v2 « autocollant manga » (conception/art/BIBLE.md, piste B retenue par le joueur) :
##   - jetons (couleurs, rayons, contours, ombres dures, durées, courbes, sons, vibrations) lus dans data/ui_tokens.json,
##     copie de conception/art/tokens.json : UiTheme.color("bonbon.soleil.base"), UiTheme.tok("mouvement.duree.appui") ;
##   - polices Mochiy Pop One (titres, title_font) et M PLUS Rounded 1c (texte 500 body_font, libellés 700 label_font,
##     boutons 800 bold_font, chiffres 900 number_font), SIL OFL 1.1, repli Nunito puis polices du système ;
##   - StickerBox : boîte « autocollant » (contour d'encre, deux tons cel, reflet blanc, ombre dure, trame), sans shader ;
##     le shader shaders/ui_sticker.gdshader sert aux grands panneaux (StickerPanel) quand la qualité le permet ;
##   - thème global (apply_global, au démarrage) : tout écran existant reste lisible (contenus clairs sur puits d'encre) ;
##     zones papier pour les écrans refaits : UiTheme.scope(conteneur) (textes encre, boutons papier).
## Peau : UiTheme.skin « sticker » (défaut, décision du joueur) ; « night » reste une option technique (--ui-skin=night,
## réglage caché interface/ui_skin) qui passe les panneaux papier en panneaux nuit.

# --- couleurs historiques (API gardée ; valeurs rapprochées des jetons v2) -------------------------
const GOLD := Color("ffc928")  # bonbon soleil (action, récompense)
const GOLD_DIM := Color("c99a3c")
const INK := Color("120c24")  # encre 900
const PANEL_BG := Color(0.18, 0.141, 0.314, 0.94)  # encre 500
const TEXT := Color("fff8ec")  # papier 100 (texte sur encre)
const MUTED := Color("c9bfea")  # encre 100 (texte secondaire sur encre)
## Plancher de lisibilité du texte permanent (px à 1600 × 900) ; 12 seulement pour un chiffre secondaire.
## M PLUS Rounded 1c a un œil plus grand que Nunito (hauteur d'x 0,52 em contre 0,495) : 14 px y valent ≈ 15 px de
## Nunito, la proposition de la DA (15) est donc tenue sans élargir les textes (mesure R_UIK0).
const MIN_TEXT := 14
const HP := Color("ff4d6d")
const BUFF := Color(0.45, 0.92, 0.55)
const DEBUFF := Color(1.0, 0.36, 0.36)

const FONT_TITLE := "res://assets/fonts/MochiyPopOne-Regular.woff2"
const FONT_BODY := "res://assets/fonts/MPLUSRounded1c-Medium.woff2"
const FONT_LABEL := "res://assets/fonts/MPLUSRounded1c-Bold.woff2"
const FONT_BOLD := "res://assets/fonts/MPLUSRounded1c-ExtraBold.woff2"
const FONT_NUMBER := "res://assets/fonts/MPLUSRounded1c-Black.woff2"
const FONT_FALLBACK := "res://assets/fonts/Nunito-SemiBold.woff2"
const FONT_FALLBACK_BOLD := "res://assets/fonts/Nunito-ExtraBold.woff2"
const FRAME_PANEL := "res://assets/ui/frame/panel.png"
const FRAME_SLOT := "res://assets/ui/frame/slot.png"
const TOKENS := "res://data/ui_tokens.json"

## Peau des panneaux : « sticker » (papier crème, défaut) ou « night » (option technique).
static var skin := "sticker"
## Grands panneaux dessinés par le shader (sinon StickerBox, sans shader).
static var use_shader := true
static var _textures := {}
static var _fonts := {}
static var _tokens := {}
static var _dots: Texture2D
static var _knob: Texture2D
static var _knob_hot: Texture2D


# --- jetons --------------------------------------------------------------------------------
static func tokens() -> Dictionary:
	if _tokens.is_empty():
		var f := FileAccess.open(TOKENS, FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_tokens = d
		if _tokens.is_empty():
			_tokens = {"_vide": true}
	return _tokens


## Valeur d'un jeton par chemin pointé (« forme.rayon.bouton ») ; « $value » est lu tout seul.
static func tok(path: String, default: Variant = null) -> Variant:
	var cur: Variant = tokens()
	for part in path.split("."):
		if cur is Dictionary and (cur as Dictionary).has(part):
			cur = cur[part]
		else:
			return default
	if cur is Dictionary and (cur as Dictionary).has("$value"):
		cur = cur["$value"]
	return default if cur == null else cur


## Couleur d'un jeton de « couleur » (« encre.700 », « bonbon.lagon.fonce », « papier.100 »).
static func color(path: String, fallback := Color.MAGENTA) -> Color:
	var v: Variant = tok("couleur." + path)
	if v is String and Color.html_is_valid(String(v)):
		return Color.html(String(v))
	return fallback


## Durée d'un mouvement en secondes (jeton en ms, « appui », « relache »...).
static func dur(name: String) -> float:
	return float(tok("mouvement.duree." + name, 120)) / 1000.0


## Tons d'une couleur : [clair (reflet), base (aplat), foncé (ombre cel)]. Bonbons des jetons, plus « papier »,
## « nuit » (encre), « gris » (désactivé sur papier), « gris_nuit » (désactivé sur encre).
static func tones(name: String) -> Array:
	match name:
		"papier":
			return [color("papier.blanc"), color("papier.100"), color("papier.300")]
		"papier2":
			return [color("papier.100"), color("papier.200"), color("papier.300")]
		"nuit":
			return [Color("41356c"), color("encre.500"), Color("231b40")]
		"nuit_haut":  # survol d'un bouton nuit
			return [Color("4c3f7d"), Color("3a2f63"), Color("2a2150")]
		"gris":
			return [Color("e8e3f1"), Color("d6d0e3"), Color("c2bbd3")]
		"gris_nuit":
			return [Color("3a3452"), Color("2f2a45"), Color("27223a")]
	return [color("bonbon.%s.clair" % name, Color.WHITE), color("bonbon.%s.base" % name, Color.GRAY), color("bonbon.%s.fonce" % name, Color.DIM_GRAY)]


## Épaisseur du contour d'encre d'un texte de taille [param size] (bible § 4).
static func outline_for(size: int) -> int:
	if size >= 70:
		return 12
	if size >= 44:
		return 9
	if size >= 30:
		return 7
	if size >= 21:
		return 5
	return 3


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


## Police avec ses replis (un signe absent de la police passe à la suivante, puis aux polices du système).
static func _font_chain(path: String, fallbacks: Array) -> Font:
	var key := path + "|chain"
	if _fonts.has(key):
		return _fonts[key]
	var f := font(path)
	if f is FontFile and f != ThemeDB.fallback_font:
		var list: Array[Font] = []
		for p in fallbacks:
			var fb := font(String(p))
			if fb != null and fb != f and fb is FontFile:
				list.append(fb)
		(f as FontFile).fallbacks = list
		(f as FontFile).allow_system_fallback = true
	_fonts[key] = f
	return f


## Variante réglée d'une police (avec ses replis) : [param top] resserre le haut de la ligne (px), [param glyph] l'approche.
## Mochiy et M PLUS Rounded réservent de la place au-dessus des capitales pour le japonais : sans ce réglage, chaque ligne
## serait plus haute qu'avec Cinzel / Nunito et les écrans à 1280 × 720 déborderaient.
static func _variant(key: String, path: String, fallbacks: Array, top: int, glyph: int) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var v := FontVariation.new()
	v.base_font = _font_chain(path, fallbacks)
	v.spacing_top = top
	v.spacing_glyph = glyph
	_fonts[key] = v
	return v


## Titres, logo, boutons primaires, grands chiffres : Mochiy Pop One (toujours contourée d'encre), approche +1 px.
static func title_font() -> Font:
	return _variant("title", FONT_TITLE, [FONT_NUMBER, FONT_FALLBACK_BOLD], -4, 1)


## Texte courant (M PLUS Rounded 1c 500).
static func body_font() -> Font:
	return _variant("body", FONT_BODY, [FONT_FALLBACK], -1, 0)


## Libellés (700).
static func label_font() -> Font:
	return _variant("label", FONT_LABEL, [FONT_FALLBACK_BOLD], -1, 0)


## Boutons, titres de section (800).
static func bold_font() -> Font:
	return _variant("bold", FONT_BOLD, [FONT_FALLBACK_BOLD], -1, 0)


## Chiffres (900, chasse fixe des chiffres de la police).
static func number_font() -> Font:
	return _variant("number", FONT_NUMBER, [FONT_FALLBACK_BOLD], -1, 0)


## Titre en Mochiy avec contour d'encre (épaisseur selon la taille, bible § 4).
static func title(label: Label, size := 28, color_value := GOLD) -> Label:
	label.add_theme_font_override("font", title_font())
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color_value)
	label.add_theme_constant_override("outline_size", outline_for(size))
	label.add_theme_color_override("font_outline_color", color("encre.700"))
	return label


# --- boîtes autocollant -------------------------------------------------------------------
## Boîte « autocollant » (bible § 5) : ombre dure d'encre réservée en bas, face en deux tons nets (cel) avec reflet clair
## en haut, trait de reflet blanc, trame de points (désactivé), lueur douce, contour d'encre. Aucun shader : uniquement
## des StyleBoxFlat natifs (les bandes cel sont des bords épais qui suivent les coins ronds), environ 10 µs par dessin.
## [member lift] décale la face (−3 survol, +shadow appui) sans changer la taille du contrôle.
class StickerBox extends StyleBox:
	var fill := Color.WHITE
	var light := Color.WHITE
	var dark := Color.WHITE
	var ink := Color("221a3a")
	var border := 3
	var radius := 14
	var square_bottom := false  # onglet : bas carré et sans contour
	var shadow := 4  # ombre dure réservée en bas (px)
	var lift := 0  # décalage vertical de la face
	var shadow_color := Color("221a3a")
	var gloss := true
	var trame := false
	var glow := Color(0, 0, 0, 0)  # lueur douce autour (bouton primaire survolé)
	var cel_top := 0.12
	var cel_bottom := 0.38
	var _flat_fill: StyleBoxFlat
	var _flat_dark: StyleBoxFlat
	var _flat_light: StyleBoxFlat
	var _flat_shadow: StyleBoxFlat
	var _flat_border: StyleBoxFlat
	var _flat_glow: StyleBoxFlat
	var _flat_gloss: StyleBoxFlat

	## Recalcule les pièces après un changement de propriété. Une seule boîte native dessine ombre dure, aplat et
	## contour ; les deux bandes cel (bords épais qui suivent les coins) se posent à l'intérieur du contour.
	func refresh() -> StickerBox:
		_flat_fill = _flat(fill, true)
		_flat_fill.border_color = ink
		_flat_fill.set_border_width_all(border)
		if square_bottom:
			_flat_fill.border_width_bottom = 0
		_flat_fill.shadow_color = shadow_color
		_flat_fill.shadow_size = 1
		var inner_r := maxi(radius - border, 0)
		_flat_dark = _flat(dark, false)
		_flat_dark.border_color = dark
		_flat_dark.set_corner_radius_all(inner_r)
		_flat_dark.anti_aliasing = false
		_flat_light = _flat(light, false)
		_flat_light.border_color = light
		_flat_light.set_corner_radius_all(inner_r)
		_flat_light.anti_aliasing = false
		if square_bottom:
			for f in [_flat_dark, _flat_light]:
				f.corner_radius_bottom_left = 0
				f.corner_radius_bottom_right = 0
		_flat_shadow = null
		_flat_border = _flat_fill
		_flat_glow = null
		if glow.a > 0.0:
			_flat_glow = _flat(Color(glow, 0.0), true)
			_flat_glow.shadow_color = glow
			_flat_glow.shadow_size = 10
		_flat_gloss = StyleBoxFlat.new()
		_flat_gloss.bg_color = Color(1, 1, 1, 0.9)
		_flat_gloss.set_corner_radius_all(3)
		_flat_gloss.anti_aliasing = true
		emit_changed()
		return self

	func _flat(c: Color, center: bool) -> StyleBoxFlat:
		var f := StyleBoxFlat.new()
		f.bg_color = c
		f.draw_center = center
		f.set_corner_radius_all(radius)
		if square_bottom:
			f.corner_radius_bottom_left = 0
			f.corner_radius_bottom_right = 0
		f.anti_aliasing = true
		f.corner_detail = 6
		return f

	func _draw(ci: RID, rect: Rect2) -> void:
		if _flat_border == null:
			refresh()
		var depth := float(shadow)
		var base := Rect2(rect.position, rect.size - Vector2(0, depth))
		var dy := clampf(float(lift), -8.0, depth)
		var face := Rect2(base.position + Vector2(0, dy), base.size)
		if _flat_glow != null:
			_flat_glow.draw(ci, face)
		# ombre dure (flou de 1 px) : décalée jusqu'au bas réservé, cachée quand la face s'est posée dessus
		var off := depth - dy
		_flat_fill.shadow_size = 1 if off > 0.5 else 0
		_flat_fill.shadow_offset = Vector2(0, off)
		_flat_fill.draw(ci, face)
		# deux tons nets : bandes = bords épais du rectangle arrondi intérieur (ils suivent les coins)
		var inner := face.grow(-float(border))
		if square_bottom:
			inner.size.y += float(border)
		if cel_bottom > 0.0 and dark != fill:
			_flat_dark.border_width_bottom = int(round(inner.size.y * cel_bottom))
			_flat_dark.draw(ci, inner)
		if cel_top > 0.0 and light != fill:
			_flat_light.border_width_top = maxi(2, int(round(inner.size.y * cel_top)))
			_flat_light.draw(ci, inner)
		if trame and UiTheme._dots != null:
			var t := face.grow(-maxf(float(border) + 1.0, float(radius) * 0.45))
			if t.size.x > 2.0 and t.size.y > 2.0:
				RenderingServer.canvas_item_add_texture_rect(ci, t, UiTheme._dots.get_rid(), true, Color(ink, 0.9))
		if gloss and face.size.x > 40.0 and face.size.y > 22.0:
			var p := face.position + Vector2(float(border) + 7.0, float(border) + 3.0)
			RenderingServer.canvas_item_add_set_transform(ci, Transform2D(deg_to_rad(-12.0), p))
			_flat_gloss.draw(ci, Rect2(0, 0, minf(16.0, face.size.x * 0.12), 5.0))
			RenderingServer.canvas_item_add_set_transform(ci, Transform2D())


## Boîte autocollant : [param tone] nom de tons (tones()) ; [param opts] : shadow, lift, radius, border, gloss, trame, glow,
## ink, shadow_color, square_bottom, cel_top, cel_bottom, pad (marge intérieure [h, v]).
static func sticker(tone: String, opts := {}) -> StickerBox:
	_ensure_textures()
	var t := tones(tone)
	var sb := StickerBox.new()
	sb.light = t[0]
	sb.fill = t[1]
	sb.dark = t[2]
	sb.ink = opts.get("ink", color("encre.700"))
	sb.shadow_color = opts.get("shadow_color", sb.ink)
	sb.border = int(opts.get("border", 3))
	sb.radius = int(opts.get("radius", 14))
	sb.shadow = int(opts.get("shadow", 4))
	sb.lift = int(opts.get("lift", 0))
	sb.gloss = bool(opts.get("gloss", true))
	sb.trame = bool(opts.get("trame", false))
	sb.glow = opts.get("glow", Color(0, 0, 0, 0))
	sb.square_bottom = bool(opts.get("square_bottom", false))
	sb.cel_top = float(opts.get("cel_top", 0.12))
	sb.cel_bottom = float(opts.get("cel_bottom", 0.38))
	var pad: Vector2 = opts.get("pad", Vector2(10, 4))  # mêmes marges que les boutons d'avant (pas de page plus large)
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	# la hauteur réservée ne dépend pas de l'état : le texte suit la face (monte au survol, descend à l'appui)
	var lift_c := clampi(sb.lift, -8, sb.shadow)
	sb.content_margin_top = pad.y + lift_c
	sb.content_margin_bottom = pad.y + sb.shadow - lift_c
	return sb.refresh()


## Les six états d'un bouton autocollant : normal, hover, pressed, hover_pressed, disabled, selected (= bouton à bascule
## enfoncé). [param tone] : « papier », « nuit », « soleil » (primaire), « lagon » (action douce), « fraise » (destructif)…
static func button_states(tone: String, opts := {}) -> Dictionary:
	var shadow := int(opts.get("shadow", 4))
	var night := tone.begins_with("nuit")
	var hot_tone := "nuit_haut" if night else tone
	var hover_opts := opts.duplicate()
	hover_opts.lift = -3
	if tone == "soleil":
		hover_opts.glow = Color(color("bonbon.soleil.clair"), 0.55)
	var press_opts := opts.duplicate()
	press_opts.lift = shadow
	var dis_opts := opts.duplicate()
	dis_opts.trame = true
	dis_opts.gloss = false
	dis_opts.shadow = shadow
	dis_opts.ink = color("encre.300") if not night else color("encre.900")
	dis_opts.shadow_color = Color(dis_opts.ink, 0.6)
	var sel_tone: String = opts.get("selected_tone", "lagon")
	var out := {
		"normal": sticker(tone, opts),
		"hover": _hot(sticker(hot_tone, hover_opts), tone),
		"pressed": sticker(tone, press_opts),
		"hover_pressed": sticker(tone, press_opts),
		"disabled": sticker("gris_nuit" if night else "gris", dis_opts),
		"selected": sticker(sel_tone, opts),
		"selected_hover": sticker(sel_tone, hover_opts),
	}
	return out


## Survol d'un bouton clair : un peu plus lumineux (la face monte déjà de 3 px).
static func _hot(sb: StickerBox, tone: String) -> StickerBox:
	if tone.begins_with("nuit"):
		return sb
	sb.fill = sb.fill.lightened(0.07)
	sb.light = sb.light.lightened(0.07)
	sb.dark = sb.dark.lightened(0.05)
	return sb.refresh()


## Couleurs de texte des boutons selon le ton du fond.
static func _button_text(tone: String) -> Dictionary:
	if tone == "papier" or tone == "papier2" or tone == "gris":
		return {"font_color": color("encre.700"), "font_hover_color": color("encre.900"), "font_pressed_color": color("encre.700"),
			"font_hover_pressed_color": color("encre.700"), "font_disabled_color": color("texte.desactive"), "font_focus_color": color("encre.700"),
			"font_outline_color": color("encre.700"), "outline": 0}
	if tone.begins_with("nuit"):
		return {"font_color": color("papier.100"), "font_hover_color": Color.WHITE, "font_pressed_color": Color.WHITE,
			"font_hover_pressed_color": Color.WHITE, "font_disabled_color": Color("8f86aa"), "font_focus_color": color("papier.100"),
			"font_outline_color": color("encre.900"), "outline": 0}
	# bonbon : blanc toujours contouré d'encre (bible § 3)
	return {"font_color": Color.WHITE, "font_hover_color": Color.WHITE, "font_pressed_color": Color.WHITE,
		"font_hover_pressed_color": Color.WHITE, "font_disabled_color": color("texte.desactive"), "font_focus_color": Color.WHITE,
		"font_outline_color": color("encre.700"), "outline": 4}


## Habille un bouton existant en autocollant (surcharges locales) : [param tone] comme button_states ; [param size] taille
## du texte (0 = inchangée). Le bouton primaire (soleil) prend Mochiy et le ressenti « primaire » de UiFeel.
static func style_button(b: Button, tone := "papier", size := 0, opts := {}) -> Button:
	var st := button_states(tone, opts)
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(k, st[k])
	if b.toggle_mode:
		b.add_theme_stylebox_override("pressed", st.selected)
		b.add_theme_stylebox_override("hover_pressed", st.selected_hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var tx := _button_text(tone)
	for k in tx:
		if k == "outline":
			b.add_theme_constant_override("outline_size", int(tx[k]))
		else:
			b.add_theme_color_override(k, tx[k])
	if tone == "soleil" or tone == "mandarine" or tone == "fraise":
		b.add_theme_font_override("font", title_font())
		var fs := size if size > 0 else 22
		b.add_theme_constant_override("outline_size", outline_for(fs) + 1)
		if tone == "soleil" and not b.has_meta("ui_feel"):
			b.set_meta("ui_feel", "primary")
	else:
		b.add_theme_font_override("font", bold_font())
	if size > 0:
		b.add_theme_font_size_override("font_size", size)
	return b


## Panneau (fenêtre, carte) selon la peau : papier crème (sticker) ou nuit. [param shadow] ombre dure (7 = panneau).
static func panel_style(shadow := 7, pad := Vector2(18, 14), radius := 18) -> StyleBox:
	var night := skin == "night"
	var sb := sticker("nuit" if night else "papier", {"shadow": shadow, "radius": radius, "gloss": false,
		"cel_top": 0.0, "cel_bottom": 0.0, "pad": pad, "ink": color("encre.900") if night else color("encre.700")})
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y + shadow
	return sb


## Puits d'encre (listes, grilles, tuiles) : encre 500, contour d'encre, sans ombre ; texte papier.
static func well_style(pad := Vector2(14, 10), radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color("encre.500")
	sb.border_color = color("encre.900")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y
	return sb


## Zone papier : [param c] reçoit le panneau de la peau et un thème où textes, boutons, onglets et jauges sont faits pour
## ce fond (textes encre, boutons papier). Les enfants héritent du thème : rien à régler un par un.
static func scope(c: Control, with_panel := true) -> Control:
	c.theme = scope_theme()
	if with_panel and c is PanelContainer:
		c.add_theme_stylebox_override("panel", panel_style())
	return c


static var _scope_theme: Theme
static var _scope_skin := ""


static func scope_theme() -> Theme:
	if _scope_theme != null and _scope_skin == skin:
		return _scope_theme
	_scope_skin = skin
	var night := skin == "night"
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 17
	var ink := color("encre.700")
	t.set_color("font_color", "Label", color("papier.100") if night else ink)
	t.set_color("font_outline_color", "Label", color("encre.900"))
	t.set_color("default_color", "RichTextLabel", color("papier.100") if night else ink)
	t.set_font("normal_font", "RichTextLabel", body_font())
	t.set_font("bold_font", "RichTextLabel", bold_font())
	_theme_buttons(t, "nuit" if night else "papier")
	if not night:  # sur papier : texte à l'encre sans contour ; choisi = blanc contouré (UiFeel pose le contour)
		for type in ["ToggleButton", "PageTab"]:
			t.set_constant("outline_size", type, 0)
			t.set_constant("sel_outline", type, 4)
			t.set_color("font_pressed_color", type, Color.WHITE)
			t.set_color("font_hover_pressed_color", type, Color.WHITE)
			t.set_color("font_outline_color", type, ink)
		t.set_color("font_color", "PageTab", ink)
		t.set_color("font_hover_color", "PageTab", color("encre.900"))
	t.set_stylebox("panel", "PanelContainer", well_style())
	_theme_bars(t, night)
	_scope_theme = t
	return t


# --- thème global ------------------------------------------------------------------------
## Appliqué une fois au démarrage : polices et styles par défaut de tous les contrôles
## (les écrans qui définissent leurs propres styles les gardent).
static func apply_global() -> void:
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if String(a).begins_with("--ui-skin="):
			skin = String(a).trim_prefix("--ui-skin=")
	var body := body_font()
	ThemeDB.fallback_font = body
	ThemeDB.fallback_font_size = 16
	var t := ThemeDB.get_default_theme()
	t.default_font = body
	t.default_font_size = 16
	t.merge_with(build_theme())
	_add_version_overlay()


## Change de peau (« sticker » / « night ») et refait le thème global ; les zones papier suivent au prochain scope().
static func set_skin(s: String) -> void:
	if s != "sticker" and s != "night":
		s = "sticker"
	if s == skin:
		return
	skin = s
	ThemeDB.get_default_theme().merge_with(build_theme())


## Numéro de version discret en bas à droite de tous les écrans.
static func _add_version_overlay() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.name = "VersionOverlay"
	var l := Label.new()
	l.text = Version.label()  # (Alt + clic droit pour noter un problème : dans l'aide F1, plus en permanence à l'écran)
	l.add_theme_font_size_override("font_size", MIN_TEXT)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.anchor_left = 1.0
	l.anchor_top = 1.0
	l.anchor_right = 1.0
	l.anchor_bottom = 1.0
	l.offset_left = -560.0
	l.offset_top = -24.0
	l.offset_right = -8.0
	l.offset_bottom = -4.0
	layer.add_child(l)
	tree.root.add_child.call_deferred(layer)


## Boutons d'un thème : Button (et listes déroulantes) au ton [param tone] ; variation « ToggleButton » (bouton à
## bascule : enfoncé = sélectionné, lagon) posée par UiFeel sur les boutons à bascule sans variation.
static func _theme_buttons(t: Theme, tone: String) -> void:
	var st := button_states(tone)
	var tx := _button_text(tone)
	for type in ["Button", "OptionButton", "MenuButton"]:
		for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(k, type, st[k])
		t.set_stylebox("focus", type, StyleBoxEmpty.new())
		for k in tx:
			if k == "outline":
				t.set_constant("outline_size", type, int(tx[k]))
			else:
				t.set_color(k, type, tx[k])
		t.set_font("font", type, bold_font())
	t.set_type_variation("ToggleButton", "Button")
	t.set_stylebox("pressed", "ToggleButton", st.selected)
	t.set_stylebox("hover_pressed", "ToggleButton", st.selected_hover)
	# choisi : blanc contouré d'encre (le contour n'est posé que sur le bouton choisi : constante « sel_outline », UiFeel)
	t.set_color("font_pressed_color", "ToggleButton", Color.WHITE)
	t.set_color("font_hover_pressed_color", "ToggleButton", Color.WHITE)
	t.set_color("font_outline_color", "ToggleButton", color("encre.700"))
	t.set_constant("outline_size", "ToggleButton", 0)
	t.set_constant("sel_outline", "ToggleButton", 4)
	# onglets d'écran (PageScreen) : nuit ou papier, l'actif en mandarine « sort » du bandeau
	t.set_type_variation("PageTab", "Button")
	var tab_opts := {"radius": 12, "square_bottom": false, "shadow": 3, "pad": Vector2(16, 3)}
	var tabs := button_states(tone, tab_opts)
	for k in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(k, "PageTab", tabs[k])
	var active := sticker("mandarine", tab_opts)
	var active_hot := sticker("mandarine", tab_opts.merged({"lift": -2}))
	t.set_stylebox("pressed", "PageTab", active)
	t.set_stylebox("hover_pressed", "PageTab", active_hot)
	t.set_color("font_pressed_color", "PageTab", Color.WHITE)
	t.set_color("font_hover_pressed_color", "PageTab", Color.WHITE)
	t.set_constant("outline_size", "PageTab", 4)
	t.set_color("font_outline_color", "PageTab", color("encre.700"))
	t.set_font("font", "PageTab", title_font())


## Jauges, curseurs, défilement, onglets de TabContainer.
static func _theme_bars(t: Theme, night: bool) -> void:
	# jauge : creux d'encre, remplissage soleil en deux tons contouré (bible § 5)
	var hollow := StyleBoxFlat.new()
	hollow.bg_color = color("encre.500")
	hollow.border_color = color("encre.900") if night else color("encre.700")
	hollow.set_border_width_all(2)
	hollow.set_corner_radius_all(8)
	hollow.anti_aliasing = true
	t.set_stylebox("background", "ProgressBar", hollow)
	t.set_stylebox("fill", "ProgressBar", sticker("soleil", {"shadow": 0, "radius": 8, "border": 2, "gloss": false, "pad": Vector2(0, 0)}))
	t.set_color("font_color", "ProgressBar", Color.WHITE)
	t.set_color("font_outline_color", "ProgressBar", color("encre.700"))
	t.set_constant("outline_size", "ProgressBar", 3)
	# curseur de réglage : piste d'encre contourée, partie réglée lagon, bouton blanc contouré
	var track := hollow.duplicate() as StyleBoxFlat
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var area := StyleBoxFlat.new()
	area.bg_color = color("bonbon.lagon.base")
	area.set_corner_radius_all(6)
	area.anti_aliasing = true
	area.content_margin_top = 4
	area.content_margin_bottom = 4
	var area_hot := area.duplicate() as StyleBoxFlat
	area_hot.bg_color = color("bonbon.lagon.clair")
	t.set_stylebox("grabber_area", "HSlider", area)
	t.set_stylebox("grabber_area_highlight", "HSlider", area_hot)
	t.set_icon("grabber", "HSlider", _knob)
	t.set_icon("grabber_highlight", "HSlider", _knob_hot)
	# barres de défilement fines et arrondies : la poignée s'allume en lagon au survol
	var thin := func(c: Color) -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = c
		b.set_corner_radius_all(4)
		b.anti_aliasing = true
		b.set_content_margin_all(3)
		return b
	for sb_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", sb_type, thin.call(Color(color("encre.900"), 0.35)))
		t.set_stylebox("grabber", sb_type, thin.call(Color(color("encre.100"), 0.55)))
		t.set_stylebox("grabber_highlight", sb_type, thin.call(color("bonbon.lagon.base")))
		t.set_stylebox("grabber_pressed", sb_type, thin.call(color("bonbon.lagon.clair")))
	# TabContainer : onglets nuit (ou papier), l'actif mandarine contouré
	var tab_opts := {"radius": 12, "square_bottom": true, "shadow": 0, "gloss": false, "pad": Vector2(16, 5)}
	var tab_tone := "nuit" if night else "papier2"
	t.set_stylebox("tab_selected", "TabContainer", sticker("mandarine", tab_opts))
	t.set_stylebox("tab_unselected", "TabContainer", sticker(tab_tone, tab_opts))
	t.set_stylebox("tab_hovered", "TabContainer", _hot(sticker(tab_tone, tab_opts.merged({"lift": -2})), tab_tone))
	t.set_stylebox("tab_disabled", "TabContainer", sticker("gris_nuit" if night else "gris", tab_opts.merged({"trame": true})))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", color("papier.100") if night else color("encre.700"))
	t.set_color("font_hovered_color", "TabContainer", Color.WHITE if night else color("encre.900"))
	t.set_color("font_outline_color", "TabContainer", color("encre.700"))
	t.set_constant("outline_size", "TabContainer", 3 if night else 0)
	t.set_font("font", "TabContainer", bold_font())


static func build_theme() -> Theme:
	_ensure_textures()
	var t := Theme.new()
	var night := skin == "night"
	var body := body_font()
	var bold := bold_font()
	t.set_font("normal_font", "RichTextLabel", body)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", color("encre.900"))
	# les écrans actuels posent des textes clairs sur des fonds d'encre : leurs boutons sont des autocollants « nuit »
	# (contour d'encre, deux tons, reflet, ombre dure) ; les zones papier (scope) ont des boutons papier.
	_theme_buttons(t, "nuit")
	# panneaux par défaut : puits d'encre (les contenus existants sont clairs), même marge intérieure qu'avant
	t.set_stylebox("panel", "PanelContainer", panel_box())
	t.set_stylebox("panel", "TabContainer", well_style(Vector2(12, 10), 12))
	_theme_bars(t, true)
	# menus déroulants, infobulles : papier (sticker) ou nuit ; tout leur texte vient du thème
	var pop_bg := "nuit" if night else "papier"
	var popup := sticker(pop_bg, {"shadow": 4, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.0, "pad": Vector2(8, 6)})
	t.set_stylebox("panel", "PopupMenu", popup)
	var pop_hover := StyleBoxFlat.new()
	pop_hover.bg_color = color("bonbon.lagon.base") if not night else color("bonbon.lagon.fonce")
	pop_hover.set_corner_radius_all(8)
	pop_hover.anti_aliasing = true
	t.set_stylebox("hover", "PopupMenu", pop_hover)
	t.set_color("font_color", "PopupMenu", color("papier.100") if night else color("encre.700"))
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE if night else color("encre.900"))
	t.set_color("font_disabled_color", "PopupMenu", color("texte.desactive"))
	t.set_font("font", "PopupMenu", label_font())
	var tip := sticker(pop_bg, {"shadow": 4, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.0, "pad": Vector2(12, 8)})
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", color("papier.100") if night else color("encre.700"))
	t.set_font_size("font_size", "TooltipLabel", 15)
	t.set_font("font", "TooltipLabel", label_font())
	var field := well_style(Vector2(10, 6), 10)
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = color("bonbon.lagon.fonce")
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", color("bonbon.lagon.clair"))
	t.set_color("selection_color", "LineEdit", Color(color("bonbon.lagon.base"), 0.5))
	# fenêtres de confirmation
	t.set_stylebox("embedded_border", "Window", panel_style())
	t.set_stylebox("panel", "AcceptDialog", StyleBoxEmpty.new())
	t.set_color("title_color", "Window", color("encre.700") if not night else GOLD)
	t.set_font("title_font", "Window", title_font())
	return t


## Panneau par défaut des écrans existants : puits d'encre contouré, ombre dure (contenus clairs) ; mêmes marges qu'avant.
static func panel_box(margin_h := 16, margin_v := 12) -> StyleBox:
	var sb := well_style(Vector2(margin_h, margin_v), 16)
	sb.bg_color = Color(color("encre.500"), 0.96)
	sb.shadow_color = Color(color("encre.900"), 0.85)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0, 5)
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


## Textures générées une fois : trame de points (désactivé), bouton rond des curseurs de réglage.
static func _ensure_textures() -> void:
	if _dots != null:
		return
	var pitch := int(tok("forme.trame.pas-px", 7))
	var img := Image.create(pitch, pitch, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var a := float(tok("forme.trame.opacite", 0.13)) * 1.8
	img.set_pixel(pitch / 2, pitch / 2, Color(1, 1, 1, a))
	img.set_pixel(pitch / 2 + 1, pitch / 2, Color(1, 1, 1, a * 0.5))
	img.set_pixel(pitch / 2, pitch / 2 + 1, Color(1, 1, 1, a * 0.5))
	_dots = ImageTexture.create_from_image(img)
	_knob = _make_knob(Color.WHITE)
	_knob_hot = _make_knob(color("bonbon.lagon.clair"))


static func _make_knob(fill: Color) -> Texture2D:
	var n := 22
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var ink := color("encre.700")
	var c := Vector2(n, n) * 0.5 - Vector2(0.5, 0.5)
	for y in n:
		for x in n:
			var d := Vector2(x, y).distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d <= 10.5:
				col = ink
				col.a = clampf(10.5 - d + 0.5, 0.0, 1.0)
			if d <= 7.5:
				col = fill.lerp(ink, clampf(d - 7.0, 0.0, 1.0))
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## Taille de texte jamais sous le plancher de lisibilité.
static func text_size(size: int) -> int:
	return maxi(size, MIN_TEXT)


## Interrupteur à glissière (remplace les gros boutons « Activé / Désactivé ») : un Button à bascule, donc
## navigable à la manette et lu comme un BaseButton (pressed, toggled). Dessin autocollant (bible § 6) : piste d'encre
## contourée (pomme quand il est allumé), bouton blanc contouré qui s'aplatit à l'appui (UiFeel).
class Switch extends Button:
	const W := 60.0
	const H := 30.0
	var _t := 0.0  # position du bouton : 0 = éteint, 1 = allumé
	var squash := 1.0  # aplatissement du bouton (UiFeel : 1,2 à l'appui)
	var _track := StyleBoxFlat.new()

	func _init() -> void:
		toggle_mode = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(W, H)
		size_flags_horizontal = Control.SIZE_SHRINK_END
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			add_theme_stylebox_override(st, empty)
		_track.set_corner_radius_all(int(H * 0.5))
		_track.set_border_width_all(3)
		_track.anti_aliasing = true
		set_meta("ui_feel", "toggle")

	func _process(delta: float) -> void:
		var goal := 1.0 if button_pressed else 0.0
		if not is_equal_approx(_t, goal):
			_t = move_toward(_t, goal, delta * 9.0)
			queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_ENTER or what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_VISIBILITY_CHANGED:
			queue_redraw()

	## Position de départ sans animation (valeur lue depuis les réglages).
	func set_on(on: bool) -> void:
		set_pressed_no_signal(on)
		_t = 1.0 if on else 0.0
		queue_redraw()

	func _draw() -> void:
		var area := Rect2((size - Vector2(W, H)) * 0.5, Vector2(W, H))
		var ink := UiTheme.color("encre.700")
		var off := UiTheme.color("encre.500")
		var on := UiTheme.color("bonbon.pomme.base")
		_track.bg_color = off.lerp(on, _t)
		_track.border_color = ink if not disabled else UiTheme.color("encre.300")
		if is_hovered() and not disabled:
			_track.bg_color = _track.bg_color.lightened(0.12)
		draw_style_box(_track, area)
		# reflet du haut de la piste
		draw_line(area.position + Vector2(H * 0.5, 6), Vector2(area.end.x - H * 0.5, area.position.y + 6), Color(1, 1, 1, 0.18 + 0.12 * _t), 2.0, true)
		var r := H * 0.5 - 6.0
		var cx := lerpf(area.position.x + H * 0.5, area.end.x - H * 0.5, _t)
		var cy := area.position.y + H * 0.5
		var col := Color.WHITE if not disabled else Color("cfc8de")
		var sq := clampf(squash, 0.6, 1.6)
		draw_set_transform(Vector2(cx, cy), 0.0, Vector2(sq, 1.0 / sq))
		draw_circle(Vector2.ZERO, r + 2.5, ink)
		draw_circle(Vector2.ZERO, r, col)
		draw_circle(Vector2(-r * 0.3, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.9) if not disabled else Color(1, 1, 1, 0.4))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Grand panneau autocollant dessiné par le shader ui_sticker (contour, deux tons, trame, relief, lueur) sur un élément de
## dessin à part, derrière le contenu (le texte des enfants n'est pas touché) ; sans shader (UiTheme.use_shader faux,
## rendu de compatibilité), il prend un StickerBox équivalent.
class StickerPanel extends PanelContainer:
	const SHADER := "res://shaders/ui_sticker.gdshader"
	var tone := "papier"
	var shadow_px := 7.0
	var _mat: ShaderMaterial
	var _ci := RID()
	var glow := 0.0:  # lueur intérieure (0 à 1), animable
		set(v):
			glow = v
			if _mat != null:
				_mat.set_shader_parameter("glow", v)

	func _init(tone_name := "papier", shadow := 7.0) -> void:
		tone = tone_name
		shadow_px = shadow

	func _ready() -> void:
		var shader := load(SHADER) as Shader if UiTheme.use_shader and ResourceLoader.exists(SHADER) else null
		var pad := Vector2(20, 16)
		var t := UiTheme.tones(tone)
		var bottom: Color = (t[1] as Color).lerp(t[2], 0.55)
		if shader == null:
			var sb := UiTheme.sticker(tone, {"shadow": int(shadow_px), "radius": 18, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.18, "pad": pad})
			sb.dark = bottom
			sb.content_margin_top = pad.y
			sb.content_margin_bottom = pad.y + shadow_px
			add_theme_stylebox_override("panel", sb.refresh())
			return
		_mat = ShaderMaterial.new()
		_mat.shader = shader
		_mat.set_shader_parameter("fill", t[1])
		_mat.set_shader_parameter("light", t[0])
		_mat.set_shader_parameter("dark", bottom)
		_mat.set_shader_parameter("cel_top", 0.0)
		_mat.set_shader_parameter("cel_bottom", 0.18)
		_mat.set_shader_parameter("ink", UiTheme.color("encre.700") if tone != "nuit" else UiTheme.color("encre.900"))
		_mat.set_shader_parameter("radius", 18.0)
		_mat.set_shader_parameter("border", 3.0)
		_mat.set_shader_parameter("shadow", shadow_px)
		_mat.set_shader_parameter("glow", glow)
		var empty := StyleBoxEmpty.new()
		empty.content_margin_left = pad.x
		empty.content_margin_right = pad.x
		empty.content_margin_top = pad.y
		empty.content_margin_bottom = pad.y + shadow_px
		add_theme_stylebox_override("panel", empty)
		_ci = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(_ci, get_canvas_item())
		RenderingServer.canvas_item_set_draw_behind_parent(_ci, true)
		RenderingServer.canvas_item_set_material(_ci, _mat.get_rid())
		resized.connect(_paint)
		_paint()

	func _paint() -> void:
		if not _ci.is_valid():
			return
		RenderingServer.canvas_item_clear(_ci)
		RenderingServer.canvas_item_add_rect(_ci, Rect2(Vector2.ZERO, size), Color.WHITE)
		_mat.set_shader_parameter("size", size)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE and _ci.is_valid():
			RenderingServer.free_rid(_ci)


static func _tab(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := flat_box(bg, border, 2, 0, false)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.border_width_bottom = 0
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	return sb
