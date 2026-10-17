class_name ForgeWidgets
extends RefCounted
## Éléments de l'Atelier refaits au lot GX-2 (Forge sans punition, Plans de donjon, Fabriquer v2) : piste des 10 crans de
## la Forge, jauge de persévérance, boutons bonbon. Les boutons passent par le thème v2 (`UiTheme.style_button`, tons des
## jetons) ; les couleurs ci-dessous sont les jetons de la DA v2 (BIBLE §3, `data/ui_tokens.json`) pour le dessin (piste,
## jauges), centralisées ici.

# --- jetons v2 (BIBLE §3) ------------------------------------------------------------------------------------------
const SOLEIL := Color("ffc928")
const SOLEIL_CLAIR := Color("ffe27a")
const SOLEIL_FONCE := Color("d9900b")
const MANDARINE := Color("ff8a1f")
const POMME := Color("8fd62e")
const POMME_CLAIR := Color("c3f07a")
const LAGON := Color("22b8f0")
const LAGON_CLAIR := Color("86ddff")
const LAGON_FONCE := Color("0b7db5")
const AMETHYSTE := Color("b43beb")
const AMETHYSTE_CLAIR := Color("dc92ff")
const FRAISE := Color("ff4d6d")
const FRAISE_CLAIR := Color("ff9db0")
const ENCRE := Color("221a3a")
const ENCRE_500 := Color("2e2450")
const ENCRE_300 := Color("6b5e86")
const PAPIER := Color("fff8ec")
const TEXTE := Color("fff8ec")  # texte sur encre
const TEXTE_2 := Color("c9bfea")
const GAIN := Color("c3f07a")  # gain sur encre
const PERTE := Color("ff9db0")  # perte sur encre


## Boîte « autocollant » : aplat, contour d'encre, ombre dure décalée (sans shader).
static func box(fill: Color, border := ENCRE, radius := 12, width := 3, shadow := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if shadow > 0:
		sb.shadow_color = Color(ENCRE, 0.9)
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, shadow)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


## Bouton autocollant du thème v2 au ton [param tone] (« soleil » action principale, « lagon » action douce, « mandarine »
## onglet actif, « pomme » gain, « nuit » neutre sur un puits d'encre), texte contouré (BIBLE §6).
static func candy_button(text: String, tone := "lagon", size := 18, min_h := 46.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, min_h)
	UiTheme.style_button(b, tone, size)
	b.add_theme_font_override("font", UiTheme.bold_font())  # la police de titre reste au bouton primaire de l'écran
	return b


## Étiquette contourée d'encre (texte blanc ou de couleur sur bonbon / encre).
static func ink_label(parent: Control, text: String, size: int, color := TEXTE, outline := 4) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_color_override("font_outline_color", ENCRE)
		l.add_theme_constant_override("outline_size", outline)
	parent.add_child(l)
	return l


## « Fabriquer et porter » : équipe la pièce [param it] qu'on vient de fabriquer si le niveau de héros le permet ;
## renvoie le message (« Fabriqué et porté : … », sinon pourquoi elle reste au coffre).
static func wear_new(it: Dictionary) -> String:
	var nm := Items.display_name(it)
	var lock := HeroLevel.lock_text(it)
	if lock != "":
		return "Fabriqué : %s (dans ton coffre commun). %s" % [nm, lock]
	if Profile.equip(it):
		return "Fabriqué et porté : %s" % nm
	return "Fabriqué : %s (dans ton coffre commun)" % nm


# --- piste des 10 crans (Forge) ----------------------------------------------------------------------------------
## Les dix crans de +1 à +10 : faits (soleil), le prochain (anneau lagon), la cible visée (anneau améthyste), les paliers
## à stat bonus (+4, +6, +8, +10) marqués d'une étoile et de leur numéro.
class Track extends Control:
	var up := 0
	var target := 0

	func _init(cur := 0, aim := 0) -> void:
		up = cur
		target = aim
		custom_minimum_size = Vector2(0, 48)
		mouse_filter = Control.MOUSE_FILTER_PASS
		tooltip_text = "Les crans de la pièce. Étoile : palier à stat bonus (+4, +6, +8, +10)."

	func set_state(cur: int, aim: int) -> void:
		up = cur
		target = aim
		queue_redraw()

	func _draw() -> void:
		var n := Items.MAX_UPGRADE
		var step := size.x / float(n)
		var r := minf(13.0, step * 0.32)
		var y := 15.0
		var font := UiTheme.bold_font()
		for i in n:
			var lv := i + 1
			var c := Vector2(step * (i + 0.5), y)
			if i > 0:
				draw_line(Vector2(step * (i - 0.5) + r, y), c - Vector2(r, 0), ForgeWidgets.SOLEIL_FONCE if lv <= up else ForgeWidgets.ENCRE_300, 3.0)
			var fill := ForgeWidgets.SOLEIL if lv <= up else Color("3a3155")
			draw_circle(c, r + 3.0, ForgeWidgets.ENCRE)
			draw_circle(c, r, fill)
			if lv <= up:
				draw_circle(c + Vector2(-r * 0.3, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.55))  # reflet
			if lv == up + 1:
				draw_arc(c, r + 1.0, 0, TAU, 32, ForgeWidgets.LAGON, 4.0, true)
			elif lv == target and target > up + 1:
				draw_arc(c, r + 1.0, 0, TAU, 32, ForgeWidgets.AMETHYSTE_CLAIR, 3.0, true)
			if lv in Items.MILESTONES:
				ForgeWidgets.star(self, c, r * 0.55, ForgeWidgets.ENCRE if lv <= up else ForgeWidgets.SOLEIL_CLAIR)
				HudWidgets.text_center(self, "+%d" % lv, Vector2(c.x, y + r + 12.0), font, 13, ForgeWidgets.SOLEIL_CLAIR if lv > up else ForgeWidgets.TEXTE_2, 3)


## Étoile à 4 branches (vocabulaire des icônes du jeu).
static func star(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var a := -PI * 0.5 + k * PI / 4.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.38))
	ci.draw_colored_polygon(pts, color)


# --- jauges -------------------------------------------------------------------------------------------------------
## Barre contourée d'encre, remplie de [param fill] jusqu'à [param value] (0-1), texte [param text] au centre ;
## [param ghost] : ce que le prochain échec ajouterait (trace claire).
static func gauge(parent: Control, value: float, fill: Color, text: String, ghost := 0.0, height := 26.0) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = clampf(value, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, height)
	bar.add_theme_stylebox_override("background", box(ENCRE_500, ENCRE, 10, 3, 2))
	var f := box(fill, ENCRE, 10, 3, 0)
	f.content_margin_left = 0
	f.content_margin_right = 0
	bar.add_theme_stylebox_override("fill", f)
	if ghost > 0.0 and value < 1.0:
		var g := ColorRect.new()
		g.color = Color(fill.lightened(0.45), 0.45)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.anchor_left = clampf(value, 0.0, 1.0)
		g.anchor_right = clampf(value + ghost, 0.0, 1.0)
		g.anchor_top = 0.0
		g.anchor_bottom = 1.0
		g.offset_top = 4
		g.offset_bottom = -4
		bar.add_child(g)
	var l := Label.new()
	l.text = text
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", ENCRE)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(l)
	parent.add_child(bar)
	return bar
