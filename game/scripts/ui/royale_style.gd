class_name RoyaleStyle
extends RefCounted
## Battle royale (lot BR-I2) : les briques « autocollant manga » de la Bible (`conception/art/BIBLE.md`) pour le
## récapitulatif de mort, la fenêtre de pile et le bilan, posées sur UiTheme v2 (jetons, StickerBox, polices Mochiy Pop One
## et M PLUS Rounded 1c) : papier contouré d'encre avec ombre dure, puits d'encre, boutons bonbon, chiffres contourés.

const INK := Color("221a3a")
const INK_500 := Color("2e2450")
const INK_300 := Color("6b5e86")
const INK_100 := Color("c9bfea")
const PAPER := Color("fff8ec")
const PAPER_200 := Color("ffebc8")
const SUN := Color("ffc928")
const SUN_LIGHT := Color("ffe27a")
const LAGOON := Color("22b8f0")
const LAGOON_DARK := Color("0b7db5")
const APPLE := Color("8fd62e")
const APPLE_LIGHT := Color("c3f07a")
const STRAWBERRY := Color("ff4d6d")
const STRAWBERRY_LIGHT := Color("ff9db0")
const MANDARIN := Color("ff8a1f")
const AMETHYST := Color("b43beb")
const GAIN_ON_PAPER := Color("3e7f0a")
## Code de rareté de la Bible (§ 3) : Commun, Spécial, Rare, Épique, Mythique, Légendaire ; et les tons UiTheme qui vont avec.
const RARITY := [Color("c9c3d6"), Color("8fd62e"), Color("22b8f0"), Color("b43beb"), Color("ff8a1f"), Color("ffc928")]
const RARITY_TONES := ["gris", "pomme", "lagon", "amethyste", "mandarine", "soleil"]
## Les 5 bonbons et la fraise (confettis).
const CANDIES := [Color("ffc928"), Color("ff8a1f"), Color("8fd62e"), Color("22b8f0"), Color("b43beb"), Color("ff4d6d")]
## Tons des boutons (noms courts de ce fichier -> tons d'UiTheme).
const TONES := {"sun": "soleil", "lagoon": "lagon", "apple": "pomme", "paper": "papier", "strawberry": "fraise"}


static func rarity_color(it: Dictionary) -> Color:
	return RARITY[clampi(int(it.get("rarity", 0)), 0, RARITY.size() - 1)]


static func rarity_tone(it: Dictionary) -> String:
	return RARITY_TONES[clampi(int(it.get("rarity", 0)), 0, RARITY_TONES.size() - 1)]


static func title_font() -> Font:
	return UiTheme.title_font()


static func number_font() -> Font:
	return UiTheme.number_font()


static func bold_font() -> Font:
	return UiTheme.bold_font()


## Boîte autocollant de couleur libre [param fill] (pastilles, chronologie) : aplat, contour d'encre de 3 px, coins de
## [param radius], ombre dure de [param shadow] px.
static func box(fill: Color, radius := 14, shadow := 5, pad := Vector2(14, 10), border := INK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if shadow > 0:
		sb.shadow_color = INK
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, shadow)
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y + maxf(0.0, shadow)
	return sb


## Autocollant d'un ton d'UiTheme (« soleil », « lagon », rareté…) : deux tons cel, reflet, ombre dure.
static func sticker(tone: String, shadow := 4, pad := Vector2(10, 4), radius := 14) -> StyleBox:
	return UiTheme.sticker(tone, {"shadow": shadow, "pad": pad, "radius": radius})


## Panneau de papier (fenêtres, récapitulatif).
static func paper(pad := Vector2(22, 18)) -> StyleBox:
	return UiTheme.panel_style(7, pad)


## Puits d'encre (tuiles, listes) dans un panneau de papier.
static func well(pad := Vector2(12, 8)) -> StyleBox:
	return UiTheme.well_style(pad)


## Étiquette contourée d'encre : [param font] (title, number, bold), taille, couleur ; contour d'encre selon la taille
## pour les couleurs claires (bible § 4), aucun pour l'encre sur papier.
static func label(parent: Node, text: String, size: int, color: Color, font := "bold", outline := -1) -> Label:
	var l := Label.new()
	l.text = text
	match font:
		"title":
			l.add_theme_font_override("font", title_font())
		"number":
			l.add_theme_font_override("font", number_font())
		_:
			l.add_theme_font_override("font", bold_font())
	l.add_theme_font_size_override("font_size", maxi(size, UiTheme.MIN_TEXT))
	l.add_theme_color_override("font_color", color)
	var o := outline if outline >= 0 else (0 if color.get_luminance() < 0.35 else UiTheme.outline_for(size))
	l.add_theme_constant_override("outline_size", o)
	if o > 0:
		l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if parent != null:
		parent.add_child(l)
	return l


## Tuile chiffrée : grande valeur papier sur puits d'encre, légende dessous.
static func tile(parent: Node, value: String, caption: String, min_w := 120.0, accent := PAPER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", well(Vector2(10, 6)))
	p.custom_minimum_size = Vector2(min_w, 0)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var big := label(v, value, 26, accent, "number")
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cap := label(v, caption, 15, INK_100, "bold", 0)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return p


## Bouton bonbon ([param tone] : sun, lagoon, apple, paper, strawberry) avec sa touche de manette ([param key] : A, B, X, Y)
## quand la manette est active.
static func button(text: String, tone := "paper", key := "", height := 52.0) -> Button:
	var b := Button.new()
	b.text = text + ("   " + key if key != "" and Gamepad.active else "")
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	UiTheme.style_button(b, String(TONES.get(tone, "papier")), 22 if tone == "sun" else 19)
	b.pressed.connect(func(): Sfx.ui("confirm" if tone == "sun" else "click", -8.0))
	return b


## Pastille de papier (texte court en encre) : « Il lui restait 410 PV ».
static func pill(parent: Node, text: String, fill := PAPER_200, size := 16) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(fill, 12, 3, Vector2(12, 3)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	var l := label(p, text, size, INK, "bold", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return p


## Pose [param c] incliné de [param degrees] (titres et bandeaux de la Bible, −3 à −4°) dans [param parent] : un support
## simple garde l'inclinaison (un conteneur la remettrait à zéro) et prend la taille de [param c], centré.
static func tilt(parent: Node, c: Control, degrees: float) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	holder.add_child(c)
	var sync := func():
		var ms := c.get_combined_minimum_size()
		holder.custom_minimum_size = ms
		c.size = ms
		c.pivot_offset = ms * 0.5
		c.position = ((holder.size - ms) * 0.5).floor()
	c.minimum_size_changed.connect(sync)
	holder.resized.connect(sync)
	c.rotation_degrees = degrees
	sync.call()
	return holder


## Nombre en groupes de trois chiffres (« 3 410 »).
static func number(v: float) -> String:
	return Hud._big_number(v)


## Durée « 6:12 ».
static func clock(secs: float) -> String:
	var s := maxi(0, int(secs))
	return "%d:%02d" % [s / 60, s % 60]
