class_name AutochessHud
extends Control
## L'Échiquier (lot AC-G, habillage v2 du lot ACX-1) : cadre de la partie (SPEC §7.1, « Compose ton équipe »), dans la DA
## « autocollant manga » (conception/art/BIBLE.md v2, maquette conception/benchmark/autochess_maquettes/preparation.html) :
## panneaux papier contourés d'encre à ombre dure, bonbons pour les actions, Mochiy Pop One + M PLUS Rounded 1c.
## En haut : frise de l'étape (● combat, ▲ monstres, ◆ choix partagé, rond fraise : gardien, étoile : atout), étape et
## manche, minuteur. À gauche : traits, TOUJOURS visibles (AutochessTraitPanel) ; la fiche d'unité (AutochessUnitCard) est
## une bulle qui sort de ce qu'on vise. À droite : les 8 stratèges (AutochessPlayers). En bas : niveau, XP et barre des taux
## de la boutique (5 couleurs, chiffres en infobulle), la boutique (AutochessShop), [Actualiser], [Verrouiller], [Prêt] ;
## au-dessus, l'onglet de l'or : intérêts, flamme de série, revenu de la prochaine manche (détail en infobulle). En combat la
## boutique est repliée (×1 / ×2). Bandeau de bilan de manche, petits avis, fin de partie.
## L'écran (AutochessScreen) branche les signaux sur la partie (Autochess) ; ce cadre n'appelle jamais la partie en écriture.
## Style partagé par les panneaux du mode (une seule source, branchée sur UiTheme v2 : polices, boutons et panneaux
## autocollants StickerBox ; UiFeel donne le ressenti des clics) : palette (INK, PAPER, candy() = valeurs de tokens.json),
## polices (pop_font, round_font), paper_panel(), sticker() (petites pièces : tuiles, pastilles, lignes), well(), gauge(),
## lbl() / ink_lbl() / pop_lbl() / panel_title(), button(), key_chip(), draw_star(). Tailles : référence 1600 × 900, × k
## (0,8 à 1280 × 720), texte jamais sous 13 px.
## Lot ACX-2 : [Annuler] au bout de l'onglet de l'or (visible s'il y a une action à annuler : Ctrl+Z / Retour arrière,
## bouton Vue de la manette) ; au combat, Pause et Passer à côté de la vitesse (×1 / ×2 / ×3) ; touches dessinées.

signal reroll_pressed
signal xp_pressed
signal lock_pressed
signal ready_pressed
signal speed_pressed
signal choice_pressed
signal replay_pressed
signal back_pressed
signal stats_pressed  ## bilan de la partie (lot AC-V)
signal undo_pressed  ## annuler la dernière action (lot ACX-2)
signal pause_pressed  ## pause (combat compris : lot ACX-2)
signal skip_pressed  ## passer le combat (fin au simulateur : lot ACX-2)

# --- palette v2 (conception/art/tokens.json) --------------------------------------------------------------------
const INK := Color("221a3a")  # encre 700 : contours, texte sur papier, ombres dures
const INK_900 := Color("120c24")
const INK_500 := Color("2e2450")  # puits d'encre
const INK_300 := Color("6b5e86")  # texte secondaire sur papier
const INK_100 := Color("c9bfea")  # texte secondaire sur encre
const PAPER := Color("fff8ec")
const PAPER_200 := Color("ffebc8")
const PAPER_300 := Color("e9dfcb")
const GAIN := Color("3e7f0a")  # texte de gain sur papier
const LOSS := Color("c21e45")
const DISABLED := Color("6f6787")
const GRAY := Color("d6d0e3")
## Bonbons : [clair, base, foncé].
const CANDY := {
	"soleil": [Color("ffe27a"), Color("ffc928"), Color("d9900b")],
	"mandarine": [Color("ffb566"), Color("ff8a1f"), Color("c85f08")],
	"pomme": [Color("c3f07a"), Color("8fd62e"), Color("4f8f10")],
	"lagon": [Color("86ddff"), Color("22b8f0"), Color("0b7db5")],
	"amethyste": [Color("dc92ff"), Color("b43beb"), Color("7a1db0")],
	"fraise": [Color("ff9db0"), Color("ff4d6d"), Color("c21e45")],
	"lilas": [Color("ece8f4"), Color("c9c3d6"), Color("8e86a6")],
}
## Couleur de chaque coût (1 à 5) : lilas, pomme, lagon, améthyste, soleil (code de rareté des icônes du jeu).
const COST_CANDY := ["lilas", "pomme", "lagon", "amethyste", "soleil"]
## Familles (couleurs des icônes de classes) ; les traits d'arme sont en lagon clair.
const FAMILY_CANDY := {1: "soleil", 2: "mandarine", 3: "pomme", 4: "lagon", 5: "amethyste"}

# --- mise en page (px à 1600 × 900, × k) ------------------------------------------------------------------------
const BG := Color(0.055, 0.065, 0.16, 0.95)  # ancien fond (panneaux d'autres lots) : gardé pour compatibilité
const BG_SOFT := Color(0.05, 0.06, 0.15, 0.82)
const MARGIN := 14.0
const TOP_H := 60.0  # bandeau de l'étape
const BOTTOM_H := 196.0  # pied de l'écran réservé (boutique, onglet de l'or, barre d'aide) : plateau et bancs au-dessus
const SHOP_H := 140.0  # hauteur du panneau de la boutique
const BOTTOM_GAP := 40.0  # sous la boutique : barre d'aide de la manette, numéro de version
const SIDE_W := 212.0
const TOP_Y := 80.0  # haut des colonnes
## Combat (lot AC-V) : la frise laisse la place aux barres d'équipe (AutochessTeamBars), les colonnes descendent dessous,
## le pied se réduit au bouton de vitesse (l'arène reste dégagée).
const COMBAT_TOP := 108.0
const COMBAT_BAR_H := 56.0
const KIND_NAMES := {"ouverture": "Ouverture", "monstres": "Monstres", "jcj": "Combat de stratèges",
	"choix": "Choix partagé", "gardien": "Gardien"}

## Échelle de l'interface : largeur de la fenêtre / 1600, entre 0,8 et 1 (lue à la construction du cadre).
static var k := 1.0

var traits: AutochessTraitPanel
var unit_card: AutochessUnitCard
var players: AutochessPlayers
var shop: AutochessShop
var reroll_button: Button
var xp_button: Button
var lock_button: Button
var ready_button: Button
var speed_button: Button
var choice_button: Button
var replay_button: Button
var back_button: Button
var stats_button: Button
var undo_button: Button
var pause_button: Button
var skip_button: Button
var odds: OddsBar
var streak: Flame
var income_chip: Label
var mode := "prep"

var _top: PanelContainer
var _frieze: Frieze
var _stage: Label
var _kind: Label
var _timer: Label
var _timer_bar: ProgressBar
var _bottom: PanelContainer
var _prep_row: HBoxContainer
var _combat_row: HBoxContainer
var _combat_text: Label
var _combat_bar: ProgressBar
var _level: Label
var _xp_bar: ProgressBar
var _xp_text: Label
var _gold_tab: PanelContainer
var _gold: Label
var _interest: Interest
var _banner: PanelContainer
var _banner_title: Label
var _banner_line: Label
var _banner_detail: Label
var _banner_t := 0.0
var _toast_box: PanelContainer
var _toast: Label
var _toast_t := 0.0
var _end: PanelContainer
var _end_place: Label
var _end_lines: Label
var _keys_pad := false
var _locked := -1


func _init() -> void:
	name = "AcHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		k = clampf(float(tree.root.get_visible_rect().size.x) / 1600.0, 0.8, 1.0)
	_build_top()
	_build_sides()
	_build_bottom()
	_build_banner()
	_build_end()


# --- style partagé (DA v2) ----------------------------------------------------------------------------------------
## Taille en px à l'échelle de la fenêtre.
static func s(px: float) -> float:
	return roundf(px * k)


## Taille de texte à l'échelle, jamais sous 13 px.
static func fs(px: int) -> int:
	return maxi(13, roundi(px * k))


## Ton d'un bonbon : 0 clair, 1 base, 2 foncé.
static func candy(name: String, tone := 1) -> Color:
	return (CANDY.get(name, CANDY.lilas) as Array)[clampi(tone, 0, 2)]


## Couleur du coût [param cost] (1 à 5), ton [param tone].
static func cost_candy(cost: int, tone := 1) -> Color:
	return candy(COST_CANDY[clampi(cost, 1, 5) - 1], tone)


## Couleur d'un trait : famille (couleur de la famille) ou arme (lagon clair).
static func trait_candy(t: String, tone := 1) -> Color:
	var td: Dictionary = AutochessData.TRAITS.get(t, {})
	if String(td.get("kind", "")) == "famille":
		return candy(String(FAMILY_CANDY.get(int(td.get("family", 0)), "lilas")), tone)
	return candy("lagon", 0) if tone <= 1 else candy("lagon", 2)


## Police des titres et grands chiffres (Mochiy Pop One, UiTheme v2).
static func pop_font() -> Font:
	return UiTheme.title_font()


## Police du texte (M PLUS Rounded 1c, UiTheme v2) : [param weight] 500, 700, 800 ou 900.
static func round_font(weight := 800) -> Font:
	match weight:
		500:
			return UiTheme.body_font()
		700:
			return UiTheme.label_font()
		900:
			return UiTheme.number_font()
	return UiTheme.bold_font()


## Grand panneau papier (UiTheme.StickerBox, toujours papier : les textes du mode sont à l'encre) ; l'ombre dure de
## [param shadow] px est réservée en bas du rectangle.
static func paper_panel(shadow := 7.0, mh := 14.0, mv := 10.0, radius := 18.0, tone := "papier") -> StyleBox:
	var sh := roundi(shadow * k)
	var sb := UiTheme.sticker(tone, {"shadow": sh, "radius": roundi(radius * k), "gloss": false, "cel_top": 0.0,
		"cel_bottom": 0.0, "pad": Vector2(roundf(mh * k), roundf(mv * k))})
	sb.content_margin_top = roundf(mv * k)
	sb.content_margin_bottom = roundf(mv * k) + sh
	return sb


## Boîte « autocollant » : aplat [param fill], contour d'encre, coins ronds, ombre dure décalée vers le bas.
static func sticker(fill: Color, radius := 18.0, shadow := 6.0, border := 3.0, mh := 12.0, mv := 8.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(0 if border <= 0.0 else maxi(2, roundi(border * maxf(k, 0.85))))
	sb.set_corner_radius_all(roundi(radius * k))
	sb.anti_aliasing = true
	if shadow > 0.0:
		sb.shadow_color = INK
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0.0, roundf(shadow * k))
	sb.content_margin_left = roundf(mh * k)
	sb.content_margin_right = roundf(mh * k)
	sb.content_margin_top = roundf(mv * k)
	sb.content_margin_bottom = roundf(mv * k)
	return sb


## Boîte plate (API des panneaux d'autres lots : bilan, atouts, compteur, barres d'équipe) : fond, bord, rayon, marges.
static func box(bg: Color, border := UiTheme.GOLD_DIM, width := 2, radius := 10, mh := 12, mv := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.content_margin_left = mh
	sb.content_margin_right = mh
	sb.content_margin_top = mv
	sb.content_margin_bottom = mv
	return sb


## Puits d'encre (listes, jauges, zones denses dans un panneau papier).
static func well(radius := 10.0, border := 2.0) -> StyleBoxFlat:
	var sb := sticker(INK_500, radius, 0.0, border, 0.0, 0.0)
	return sb


## Jauge : creux d'encre contouré, remplissage [param col] à bord droit d'encre.
static func gauge(bar: ProgressBar, col: Color, h := 10.0) -> ProgressBar:
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.y = roundf(h * k)
	bar.add_theme_stylebox_override("background", well(roundf(h * 0.5), 2.0))
	var f := StyleBoxFlat.new()
	f.bg_color = col
	f.set_corner_radius_all(roundi(h * 0.5 * k))
	f.border_color = INK
	f.border_width_right = 2
	f.anti_aliasing = true
	f.expand_margin_left = 0.0
	bar.add_theme_stylebox_override("fill", f)
	return bar


## Étiquette (texte clair sur encre, contour d'encre) : [param font] « body », « bold », « title » ou « number ».
## Gardée telle quelle pour les panneaux d'autres lots (bilan, atouts, compteur) ; police v2.
static func lbl(text: String, size := 16, col := UiTheme.TEXT, font := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == "title":
		return UiTheme.title(l, size, col)
	l.add_theme_font_override("font", round_font(800 if font == "bold" else (900 if font == "number" else 500)))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(INK, 0.85))
	return l


## Texte d'encre sur papier (sans contour) : [param weight] 500 à 900.
static func ink_lbl(text: String, size := 16, col := INK, weight := 800) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", round_font(weight))
	l.add_theme_font_size_override("font_size", fs(size))
	l.add_theme_color_override("font_color", col)
	return l


## Titre / chiffre « pop » (Mochiy) : blanc contouré d'encre par défaut ([param col] encre : sans contour).
static func pop_lbl(text: String, size := 22, col := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sz := fs(size)
	l.add_theme_font_override("font", pop_font())
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if col != INK:
		l.add_theme_constant_override("outline_size", UiTheme.outline_for(sz))
		l.add_theme_color_override("font_outline_color", INK)
	return l


## Titre de panneau « collé » : Mochiy blanc contouré, incliné de −3°, posé à cheval sur le bord haut du panneau.
static func panel_title(text: String, size := 22) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.custom_minimum_size = Vector2(0, s(size * 0.9))
	var l := pop_lbl(text, size)
	l.name = "Title"
	l.rotation = deg_to_rad(-3.0)
	l.position = Vector2(s(2), -s(size * 0.55))
	holder.add_child(l)
	return holder


## Bouton du mode : [param kind] « plain » (papier), « primary » (soleil, Mochiy), « soft » (lagon), « danger » (fraise),
## « sun » (soleil sans le ressenti du primaire : verrou allumé) ; [param key] / [param pad] : touche du clavier et bouton de
## la manette, rappelés en pastille dans le coin. Autocollant de UiTheme v2 (UiTheme.style_button).
static func button(text: String, kind := "plain", h := 36.0, key := "", pad := "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, roundf(h * k))
	style_button(b, kind)
	b.pressed.connect(func(): Sfx.ui("click", -8.0))
	if key != "" or pad != "":
		b.set_meta("key", key)
		b.set_meta("pad", pad)
		var kc := key_chip(key)
		kc.name = "Key"
		b.add_child(kc)
	return b


## (Re)style d'un bouton selon [param kind] (le verrou passe de papier à soleil).
static func style_button(b: Button, kind: String) -> void:
	b.set_meta("kind", kind)
	var tone := "papier"
	match kind:
		"primary":
			tone = "soleil"
		"soft":
			tone = "lagon"
		"danger":
			tone = "fraise"
		"sun":
			tone = "soleil"
			b.set_meta("ui_feel", "toggle")
	var h := b.custom_minimum_size.y
	var size := fs(22) if kind == "primary" and h >= 44.0 * k else (fs(19) if kind == "primary" else (fs(16) if h >= 34.0 * k else fs(15)))
	UiTheme.style_button(b, tone, size)
	if kind == "sun" or kind == "soft":
		b.add_theme_font_override("font", round_font(900))
		b.add_theme_constant_override("outline_size", 4)


## Pastille de touche (coin d'un bouton) : clavier = autocollant papier ; manette = rond de couleur (A pomme, B fraise,
## X lagon, Y soleil) ou étiquette d'encre (gâchettes).
static func key_chip(text: String) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", round_font(900))
	l.add_theme_font_size_override("font_size", 13)
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	set_key_chip(l, text, false)
	return l


static func set_key_chip(l: Label, text: String, pad: bool) -> void:
	l.text = text
	l.visible = text != ""
	var round_pad := pad and text in ["A", "B", "X", "Y"]
	var col := PAPER
	if round_pad:
		col = candy({"A": "pomme", "B": "fraise", "X": "lagon", "Y": "soleil"}[text])
	elif pad:
		col = INK_500
	var sb := sticker(col, 10.0 if round_pad else 7.0, 0.0, 2.0, 4.0 if not round_pad else 0.0, 0.0)
	l.add_theme_stylebox_override("normal", sb)
	var light := round_pad or pad
	l.add_theme_color_override("font_color", Color.WHITE if light else INK)
	l.add_theme_constant_override("outline_size", 3 if round_pad else 0)
	l.add_theme_color_override("font_outline_color", INK)
	var w := 20.0 if round_pad else maxf(20.0, 9.0 * text.length() + 10.0)
	l.offset_left = -w + 6.0
	l.offset_right = 6.0
	l.offset_top = -8.0
	l.offset_bottom = 12.0


## Points d'une étoile à [param n] branches (centre [param c], rayons extérieur / intérieur).
static func star_points(c: Vector2, r_out: float, r_in: float, n := 5, rot := -PI * 0.5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := rot + PI * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * (r_out if i % 2 == 0 else r_in))
	return pts


## Dessine une étoile autocollant (aplat + contour d'encre) sur [param ci].
static func draw_star(ci: CanvasItem, c: Vector2, r: float, col: Color, outline := 2.0) -> void:
	var pts := star_points(c, r, r * 0.48)
	ci.draw_colored_polygon(pts, col)
	pts.append(pts[0])
	ci.draw_polyline(pts, INK, outline, true)


# --- construction ---------------------------------------------------------------------------------------------------
func _build_top() -> void:
	_top = PanelContainer.new()
	_top.name = "AcTop"
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	_top.add_theme_stylebox_override("panel", paper_panel(6.0, 16.0, 8.0))
	_top.anchor_left = 0.5
	_top.anchor_right = 0.5
	_top.offset_top = s(8.0)
	_top.custom_minimum_size.y = s(TOP_H)
	_top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_top)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", roundi(s(14)))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(h)
	_frieze = Frieze.new()
	_frieze.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_frieze)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_stage = pop_lbl("", 20, INK)
	v.add_child(_stage)
	_kind = ink_lbl("", 14, INK_300, 700)
	v.add_child(_kind)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	_timer = pop_lbl("", 28, INK)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.custom_minimum_size.x = s(64)
	tv.add_child(_timer)
	_timer_bar = gauge(ProgressBar.new(), candy("soleil"), 8.0)
	_timer_bar.custom_minimum_size.x = s(64)
	_timer_bar.max_value = 1.0
	tv.add_child(_timer_bar)
	choice_button = button("Revenir au choix", "primary", 40.0)
	choice_button.name = "AcChoiceBack"
	choice_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_button.pressed.connect(func(): choice_pressed.emit())
	choice_button.visible = false
	h.add_child(choice_button)


func _build_sides() -> void:
	traits = AutochessTraitPanel.new()
	traits.position = Vector2(s(MARGIN), s(TOP_Y))
	add_child(traits)
	players = AutochessPlayers.new()
	players.anchor_left = 1.0
	players.anchor_right = 1.0
	players.offset_left = -s(MARGIN) - s(SIDE_W)
	players.offset_right = -s(MARGIN)
	players.offset_top = s(TOP_Y)
	add_child(players)
	unit_card = AutochessUnitCard.new()  # bulle flottante : au-dessus des colonnes
	unit_card.position = Vector2(s(MARGIN) + s(SIDE_W) + s(12), s(TOP_Y))
	add_child(unit_card)


func _build_bottom() -> void:
	_bottom = PanelContainer.new()
	_bottom.name = "AcBottom"
	_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	_bottom.add_theme_stylebox_override("panel", paper_panel(7.0, 12.0, 8.0))
	_bottom.anchor_left = 0.5
	_bottom.anchor_right = 0.5
	_bottom.anchor_top = 1.0
	_bottom.anchor_bottom = 1.0
	_bottom.offset_top = -BOTTOM_GAP - s(SHOP_H)
	_bottom.offset_bottom = -BOTTOM_GAP
	_bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_bottom)
	_prep_row = HBoxContainer.new()
	_prep_row.add_theme_constant_override("separation", roundi(s(12)))
	_prep_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(_prep_row)
	# niveau, XP, taux de la boutique, acheter de l'XP
	var lv := VBoxContainer.new()
	lv.custom_minimum_size.x = s(176)
	lv.add_theme_constant_override("separation", roundi(s(5)))
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prep_row.add_child(lv)
	var lh := HBoxContainer.new()
	lh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.add_child(lh)
	_level = pop_lbl("", 20, INK)
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lh.add_child(_level)
	_xp_text = ink_lbl("", 14, INK_300, 800)
	_xp_text.size_flags_vertical = Control.SIZE_SHRINK_END
	lh.add_child(_xp_text)
	_xp_bar = gauge(ProgressBar.new(), candy("lagon"), 10.0)
	_xp_bar.max_value = 1.0
	lv.add_child(_xp_bar)
	odds = OddsBar.new()
	odds.name = "AcOdds"
	lv.add_child(odds)
	xp_button = button("Acheter de l'XP · 4", "soft", 38.0, "F", "LB")
	xp_button.name = "AcXp"
	xp_button.pressed.connect(func(): xp_pressed.emit())
	lv.add_child(xp_button)
	# boutique
	shop = AutochessShop.new()
	shop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prep_row.add_child(shop)
	# actualiser, verrou, prêt
	var rv := VBoxContainer.new()
	rv.custom_minimum_size.x = s(160)
	rv.add_theme_constant_override("separation", roundi(s(9)))
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prep_row.add_child(rv)
	reroll_button = button("Actualiser", "soft", 36.0, "D", "LT")
	reroll_button.name = "AcReroll"
	reroll_button.pressed.connect(func(): reroll_pressed.emit())
	rv.add_child(reroll_button)
	lock_button = button("Verrouiller", "plain", 32.0, "V", "RT")
	lock_button.name = "AcLock"
	lock_button.pressed.connect(func(): lock_pressed.emit())
	rv.add_child(lock_button)
	ready_button = button("Prêt", "primary", 46.0, "Espace", "Y")
	ready_button.name = "AcReady"
	ready_button.pressed.connect(func(): ready_pressed.emit())
	rv.add_child(ready_button)
	# combat : boutique repliée
	_combat_row = HBoxContainer.new()
	_combat_row.add_theme_constant_override("separation", 16)
	_combat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_combat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_row.visible = false
	_bottom.add_child(_combat_row)
	var cv := VBoxContainer.new()
	cv.custom_minimum_size.x = s(520)
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 8)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_row.add_child(cv)
	_combat_text = pop_lbl("", 20, INK)
	_combat_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(_combat_text)
	_combat_bar = gauge(ProgressBar.new(), candy("soleil"), 10.0)
	_combat_bar.max_value = 1.0
	cv.add_child(_combat_bar)
	pause_button = button("Pause", "plain", 40.0, "Échap", "Start")
	pause_button.name = "AcPause"
	pause_button.custom_minimum_size.x = s(120)
	pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pause_button.tooltip_text = "Tout s'arrête, combat compris."
	pause_button.pressed.connect(func(): pause_pressed.emit())
	_combat_row.add_child(pause_button)
	speed_button = button("Vitesse ×1", "plain", 40.0, "1 2 3", "Y")
	speed_button.name = "AcSpeed"
	speed_button.custom_minimum_size.x = s(150)
	speed_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speed_button.tooltip_text = "×1, ×2 ou ×3 (gardée entre les parties)."
	speed_button.pressed.connect(func(): speed_pressed.emit())
	_combat_row.add_child(speed_button)
	skip_button = button("Passer", "soft", 40.0, "P", "X")
	skip_button.name = "AcSkip"
	skip_button.custom_minimum_size.x = s(130)
	skip_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip_button.tooltip_text = "Fin du combat tout de suite : résultat calculé."
	skip_button.pressed.connect(func(): skip_pressed.emit())
	_combat_row.add_child(skip_button)
	# l'or, au centre, en onglet soleil au-dessus de la boutique : intérêts, série, revenu de la prochaine manche
	_gold_tab = PanelContainer.new()
	_gold_tab.name = "AcGold"
	_gold_tab.mouse_filter = Control.MOUSE_FILTER_STOP
	var gsb := UiTheme.sticker("soleil", {"shadow": 0, "radius": roundi(14.0 * k), "square_bottom": true, "cel_bottom": 0.0,
		"pad": Vector2(roundf(14.0 * k), roundf(2.0 * k))})
	gsb.content_margin_top = roundf(2.0 * k)
	gsb.content_margin_bottom = roundf(2.0 * k)
	_gold_tab.add_theme_stylebox_override("panel", gsb)
	_gold_tab.anchor_left = 0.5
	_gold_tab.anchor_right = 0.5
	_gold_tab.anchor_top = 1.0
	_gold_tab.anchor_bottom = 1.0
	_gold_tab.offset_top = -BOTTOM_GAP - s(SHOP_H) - s(38.0) + 3.0
	_gold_tab.offset_bottom = -BOTTOM_GAP - s(SHOP_H) + 3.0
	_gold_tab.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_gold_tab.z_index = 1  # au-dessus d'une carte de la boutique grossie par le survol (UiFeel)
	add_child(_gold_tab)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", roundi(s(8)))
	gh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gold_tab.add_child(gh)
	gh.add_child(Coin.new())
	_gold = pop_lbl("", 24)
	_gold.name = "AcGoldValue"
	gh.add_child(_gold)
	_interest = Interest.new()
	_interest.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gh.add_child(_interest)
	streak = Flame.new()
	streak.name = "AcStreak"
	gh.add_child(streak)
	income_chip = ink_lbl("", 15, GAIN, 900)
	income_chip.name = "AcIncome"
	income_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	income_chip.add_theme_stylebox_override("normal", sticker(PAPER, 10.0, 0.0, 2.0, 6.0, 0.0))
	income_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gh.add_child(income_chip)
	undo_button = button("Annuler · Ctrl+Z", "plain", 28.0)  # touche écrite dans le bouton (_update_keys) : l'onglet est bas
	undo_button.name = "AcUndo"
	undo_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	undo_button.tooltip_text = "Annule le dernier achat, la dernière vente ou le dernier déplacement."
	undo_button.pressed.connect(func(): undo_pressed.emit())
	undo_button.visible = false
	gh.add_child(undo_button)
	# petits avis : bulle papier sous le bandeau
	_toast_box = PanelContainer.new()
	_toast_box.name = "AcToast"
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_theme_stylebox_override("panel", paper_panel(4.0, 16.0, 4.0, 14.0))
	_toast_box.anchor_left = 0.5
	_toast_box.anchor_right = 0.5
	_toast_box.offset_top = s(TOP_Y) + s(96.0)
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_box.modulate.a = 0.0
	add_child(_toast_box)
	_toast = ink_lbl("", 17, INK, 800)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_box.add_child(_toast)


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.name = "AcBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_stylebox_override("panel", paper_panel(7.0, 28.0, 10.0))
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_top = s(TOP_Y) + s(6.0)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_banner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(v)
	_banner_title = pop_lbl("", 30)
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.rotation = deg_to_rad(-2.0)
	v.add_child(_banner_title)
	_banner_line = ink_lbl("", 19, INK, 900)
	_banner_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_banner_line)
	_banner_detail = ink_lbl("", 15, INK_300, 700)
	_banner_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_banner_detail)
	_banner.visible = false


func _build_end() -> void:
	_end = PanelContainer.new()
	_end.name = "AcEnd"
	_end.mouse_filter = Control.MOUSE_FILTER_STOP
	_end.add_theme_stylebox_override("panel", paper_panel(7.0, 40.0, 26.0))
	_end.set_anchors_preset(Control.PRESET_CENTER)
	_end.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_end)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.custom_minimum_size.x = 380
	_end.add_child(v)
	var t := pop_lbl("Ta place", 22, INK)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_end_place = pop_lbl("", 56, candy("soleil"))
	_end_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_place)
	_end_lines = ink_lbl("", 17, INK, 700)
	_end_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_lines)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	replay_button = button("Rejouer", "primary", 46.0)
	replay_button.name = "AcReplay"
	replay_button.custom_minimum_size.x = 160
	replay_button.pressed.connect(func(): replay_pressed.emit())
	row.add_child(replay_button)
	stats_button = button("Statistiques", "plain", 46.0)
	stats_button.name = "AcStats"
	stats_button.custom_minimum_size.x = 160
	stats_button.tooltip_text = "Ce que tes héros ont fait pendant la partie."
	stats_button.pressed.connect(func(): stats_pressed.emit())
	row.add_child(stats_button)
	back_button = button("Menu principal", "plain", 46.0)
	back_button.name = "AcBack"
	back_button.custom_minimum_size.x = 160
	back_button.pressed.connect(func(): back_pressed.emit())
	row.add_child(back_button)
	_end.visible = false


# --- mise à jour ----------------------------------------------------------------------------------------------------
## Tout le cadre pour le stratège [param me] ; [param foe] : son adversaire de la manche ; [param scouted] : plateau regardé.
func refresh(g: Autochess, me: int, foe := -1, scouted := -1) -> void:
	var p: Dictionary = g.players[me]
	_stage.text = "Étape %d · manche %d" % [g.stage, g.round_i]
	_kind.text = String(KIND_NAMES.get(g.round_kind(), ""))
	if g.is_augment_round():
		_kind.text += " · atout"
	if g.format != "classique":  # lot ACX-3 : format court
		_kind.text = "%s · %s" % [String(AutochessData.FORMATS.get(g.format, {}).get("name", "")), _kind.text]
	_kind.tooltip_text = String(AutochessData.FORMATS.get(g.format, {}).get("tip", ""))
	if g.day_rule != "":
		var rd: Dictionary = AutochessData.DAY_RULES.get(g.day_rule, {})
		_kind.tooltip_text = ("%s\n" % _kind.tooltip_text if _kind.tooltip_text != "" else "") + "Règle du jour : %s. %s" % [String(rd.get("name", "")), String(rd.get("short", ""))]
	_kind.mouse_filter = Control.MOUSE_FILTER_PASS if _kind.tooltip_text != "" else Control.MOUSE_FILTER_IGNORE
	_frieze.rules = g.rules
	_frieze.set_stage(g.stage, g.round_i)
	_level.text = "Niveau %d" % int(p.level)
	var need := AutochessData.xp_to_next(int(p.level))
	var maxed := int(p.level) >= int(p.max_level)
	if maxed:
		_xp_bar.value = 1.0
		_xp_text.text = "max"
		_xp_text.tooltip_text = "Niveau maximal"
	elif need <= 0:  # niveau 1 : le niveau 2 est donné à la manche suivante
		_xp_bar.value = 0.0
		_xp_text.text = ""
	else:
		_xp_bar.value = float(p.xp) / float(need)
		_xp_text.text = "%d / %d" % [int(p.xp), need]
	_xp_bar.tooltip_text = "Niveau 2 à la prochaine manche" if need <= 0 and not maxed else ("%d / %d XP" % [int(p.xp), need] if not maxed else "Niveau maximal")
	odds.set_level(int(p.level))
	xp_button.text = "Acheter de l'XP · %d" % g.xp_cost()
	xp_button.disabled = maxed or need <= 0
	xp_button.tooltip_text = "+%d XP pour %d or" % [AutochessData.XP_BUY_AMOUNT, g.xp_cost()]
	var free := int(p.free_rerolls)
	reroll_button.text = "Actualiser · offert" if free > 0 else "Actualiser · %d" % g.reroll_cost()
	reroll_button.tooltip_text = "Cinq nouvelles offres."
	var locked := bool(p.locked)
	lock_button.text = "Verrouillée" if locked else "Verrouiller"
	lock_button.tooltip_text = "La boutique reste la même à la manche suivante." if not locked else "Clique pour la libérer."
	if int(locked) != _locked:
		_locked = int(locked)
		style_button(lock_button, "sun" if locked else "plain")
	_gold.text = "%d" % int(p.gold)
	var cap := g.interest_cap(me)
	_interest.cap = cap
	_interest.custom_minimum_size = Vector2(maxf(cap, 1) * s(13.0) + 4.0, s(26.0))
	_interest.have = AutochessData.interest(int(p.gold), cap)
	_interest.visible = cap > 0
	_interest.queue_redraw()
	_interest.tooltip_text = "Intérêts : +1 or par tranche de 10, %d au plus." % cap
	streak.set_streak(int(p.streak))
	_refresh_income(g, me, cap)
	shop.refresh(g, me)
	traits.refresh(g.trait_counts(me))
	players.refresh(g, me, foe, scouted)
	_update_keys()


## Revenu de la prochaine manche (Autochess.income_for) : chiffre sur l'onglet de l'or, détail en infobulle.
func _refresh_income(g: Autochess, me: int, cap: int) -> void:
	var st := g.stage
	var rd := g.round_i + 1
	if rd > g.rounds_in(st):
		st += 1
		rd = 1
	var inc := g.income_for(me, st, rd)
	var total := int(inc.total)
	income_chip.text = "+%d" % total
	income_chip.visible = total > 0
	var parts: Array = []
	if int(inc.base) > 0:
		parts.append("%d de base" % int(inc.base))
	if int(inc.interest) > 0:
		parts.append("%d d'intérêts" % int(inc.interest))
	if int(inc.streak) > 0:
		parts.append("%d de série" % int(inc.streak))
	if int(inc.bonus) > 0:
		parts.append("%d d'atout" % int(inc.bonus))
	var tip := "Prochaine manche : +%d or" % total
	if not parts.is_empty():
		tip += "\n" + " · ".join(parts)
	if g.kind_at(st, rd) == "jcj" or g.round_kind() == "jcj":
		tip += "\nVictoire contre un stratège : +%d or" % AutochessData.PVP_WIN_GOLD
	income_chip.tooltip_text = tip
	_gold_tab.tooltip_text = tip + ("\nIntérêts : +1 or par tranche de 10, %d au plus." % cap if cap > 0 else "\nPlus aucun intérêt.")
	_gold.tooltip_text = _gold_tab.tooltip_text


## Minuteur : [param left] secondes sur [param total] (total <= 0 : caché).
func set_timer(left: float, total: float) -> void:
	_timer.visible = total > 0.0
	_timer_bar.visible = total > 0.0
	_timer.text = "%d" % ceili(maxf(left, 0.0))
	var hurry := left <= 5.0
	_timer.add_theme_color_override("font_color", candy("fraise", 2) if hurry else INK)
	_timer_bar.value = clampf(left / maxf(total, 0.01), 0.0, 1.0)
	var fill := _timer_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		fill.bg_color = candy("fraise") if hurry else candy("soleil")


## « prep » : boutique ; « combat » : boutique repliée ; « over » : fin de partie.
func set_mode(m: String) -> void:
	mode = m
	_prep_row.visible = m == "prep"
	_combat_row.visible = m != "prep"
	_gold_tab.visible = m == "prep"
	_bottom.visible = m != "over"
	if m != "over":
		_end.visible = false
	var fight := m == "combat"
	_top.visible = not fight
	_combat_text.get_parent().visible = not fight  # combat : chronomètre et noms dans les barres d'équipe (AC-V)
	_bottom.offset_top = -BOTTOM_GAP - (s(COMBAT_BAR_H) if fight else s(SHOP_H))
	players.offset_top = COMBAT_TOP if fight else s(TOP_Y)


func set_combat(text: String, progress: float, speed: float) -> void:
	_combat_text.text = text
	_combat_bar.value = clampf(progress, 0.0, 1.0)
	speed_button.text = "Vitesse ×%d" % int(speed)


## Les cartes de choix sont ouvertes : la fiche d'unité se cache ; [param top] : la frise aussi (choix partagé).
func set_overlay(on: bool, top := false) -> void:
	_top.visible = not (on and top) and mode != "combat"
	if on:
		unit_card.hide_card()


## Boutique masquée pendant qu'une unité est tenue (la zone « Vendre » du curseur apparaît à sa place).
func set_holding(on: bool) -> void:
	_bottom.visible = not on and mode != "over"
	_gold_tab.visible = not on and mode == "prep"


## Rectangles occupés par le cadre au repos (préparation) : la bulle de la fiche les évite, la caméra cadre le plateau
## dans ce qui reste (AutochessScreen._fit_board).
func frame_rects() -> Array:
	var out: Array = []
	for c in [_top, traits, players, _bottom, _gold_tab]:
		if (c as Control).is_visible_in_tree():
			out.append((c as Control).get_global_rect())
	return out


func show_banner(title: String, line := "", detail := "", col := UiTheme.GOLD, secs := AutochessData.ROUND_RECAP) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", _banner_color(col))
	_banner_line.text = line
	_banner_line.visible = line != ""
	_banner_detail.text = detail
	_banner_detail.visible = detail != ""
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner_t = secs
	_banner.reset_size()


## Couleur de titre du bandeau : les couleurs historiques (or, rouge, gris) passent aux bonbons (soleil, fraise, lilas).
static func _banner_color(col: Color) -> Color:
	if col == UiTheme.GOLD:
		return candy("soleil")
	if col == UiTheme.DEBUFF or col == UiTheme.HP:
		return candy("fraise")
	if col == UiTheme.MUTED:
		return candy("lilas", 2)
	return col


func banner_text() -> String:
	return "%s|%s|%s" % [_banner_title.text, _banner_line.text, _banner_detail.text] if _banner.visible else ""


func toast(text: String) -> void:
	_toast.text = text
	_toast_box.modulate.a = 1.0
	_toast_box.reset_size()
	_toast_t = 2.2


func toast_text() -> String:
	return _toast.text if _toast_box.modulate.a > 0.0 else ""


func show_end(place: int, lines: String) -> void:
	set_mode("over")
	_banner.visible = false
	_banner_t = 0.0
	_end_place.text = AutochessPlayers.place_text(place)
	_end_lines.text = lines
	_end.visible = true
	_end.reset_size()
	UiNav.focus(replay_button)


func is_end_shown() -> bool:
	return _end.visible


func _update_keys() -> void:
	var pad := Gamepad.active
	if pad == _keys_pad and xp_button.get_node_or_null("Key") != null and (xp_button.get_node("Key") as Label).text != "":
		return
	_keys_pad = pad
	var lt := "LT" if Settings.pad_name(JOY_BUTTON_LEFT_SHOULDER) == "LB" else "L2"
	var rt := "RT" if lt == "LT" else "R2"
	undo_button.text = "Annuler · %s" % (Settings.pad_name(JOY_BUTTON_BACK) if pad else "Ctrl+Z")
	for b in [xp_button, reroll_button, lock_button, ready_button, speed_button, pause_button, skip_button]:
		var kl: Label = (b as Button).get_node_or_null("Key")
		if kl == null:
			continue
		var pk := String(b.get_meta("pad", ""))
		match pk:
			"LT":
				pk = lt
			"RT":
				pk = rt
			"LB":
				pk = Settings.pad_name(JOY_BUTTON_LEFT_SHOULDER)
			"Y":
				pk = Settings.pad_name(JOY_BUTTON_Y)
			"X":
				pk = Settings.pad_name(JOY_BUTTON_X)
			"Start":
				pk = Settings.pad_name(JOY_BUTTON_START)
			"Vue":
				pk = Settings.pad_name(JOY_BUTTON_BACK)
		set_key_chip(kl, pk if pad else String(b.get_meta("key", "")), pad)


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t < 0.3:
			_banner.modulate.a = maxf(_banner_t / 0.3, 0.0)
		if _banner_t <= 0.0:
			_banner.visible = false
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast_box.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
	if Gamepad.active != _keys_pad:
		_update_keys()
		shop.refresh_keys()


# --- petits dessins -------------------------------------------------------------------------------------------------
## Frise de l'étape : une pastille par manche (contour d'encre), selon son type ; la manche en cours en soleil, plus grande.
class Frieze extends Control:
	var stage := 1
	var round_i := 1
	var rules: Dictionary = {}  # règles de la partie (Autochess.rules : format Éclair, lot ACX-3)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(160, AutochessHud.s(34.0))

	func set_stage(st: int, rd: int) -> void:
		if st == stage and rd == round_i and tooltip_text != "":
			return
		stage = st
		round_i = rd
		var n := AutochessData.rounds_in(st, rules)
		custom_minimum_size = Vector2(n * AutochessHud.s(24.0) + AutochessHud.s(10.0), AutochessHud.s(34.0))
		var parts: Array = []
		for r in range(1, n + 1):
			parts.append(String(AutochessHud.KIND_NAMES.get(AutochessData.round_kind(st, r, rules), "")))
		tooltip_text = "Étape %d : %s" % [st, ", ".join(parts).to_lower()]
		queue_redraw()

	func _draw() -> void:
		var n := AutochessData.rounds_in(stage, rules)
		var step := AutochessHud.s(24.0)
		var cy := size.y * 0.5 + AutochessHud.s(3.0)
		var ink := AutochessHud.INK
		for r in range(1, n + 1):
			var c := Vector2(AutochessHud.s(14.0) + (r - 1) * step, cy)
			if r > 1:
				draw_line(c - Vector2(step - AutochessHud.s(8.0), 0), c - Vector2(AutochessHud.s(8.0), 0), Color(ink, 0.45), 2.0)
		for r in range(1, n + 1):
			var c := Vector2(AutochessHud.s(14.0) + (r - 1) * step, cy)
			var past := r < round_i
			var cur := r == round_i
			var kind := AutochessData.round_kind(stage, r, rules)
			var col := AutochessHud.PAPER_300
			if cur:
				col = AutochessHud.candy("soleil")
			elif past:
				col = AutochessHud.INK_300
			var rad := AutochessHud.s(10.0 if cur else 7.0)
			var pts := PackedVector2Array()
			match kind:
				"monstres":
					pts = PackedVector2Array([c + Vector2(0, -rad * 1.1), c + Vector2(rad, rad * 0.75), c + Vector2(-rad, rad * 0.75)])
				"choix":
					pts = PackedVector2Array([c + Vector2(0, -rad * 1.15), c + Vector2(rad, 0), c + Vector2(0, rad * 1.15), c + Vector2(-rad, 0)])
				"ouverture":
					pts = PackedVector2Array([c + Vector2(-rad, -rad) * 0.85, c + Vector2(rad, -rad) * 0.85, c + Vector2(rad, rad) * 0.85, c + Vector2(-rad, rad) * 0.85])
				"gardien":
					rad = AutochessHud.s(11.0 if cur else 9.0)
					if not cur:
						col = AutochessHud.candy("fraise") if not past else AutochessHud.candy("fraise", 2)
			if pts.is_empty():
				draw_circle(c, rad, col)
				draw_arc(c, rad, 0.0, TAU, 28, ink, 2.0, true)
				if kind == "gardien":
					draw_circle(c, rad * 0.35, ink)
			else:
				draw_colored_polygon(pts, col)
				pts.append(pts[0])
				draw_polyline(pts, ink, 2.0, true)
			if AutochessData.is_augment_round(stage, r, rules):
				AutochessHud.draw_star(self, c + Vector2(0, -rad - AutochessHud.s(7.0)), AutochessHud.s(6.0),
					AutochessHud.candy("soleil"), 1.5)


## Pièce d'or (autocollant).
class Coin extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(AutochessHud.s(26.0), AutochessHud.s(30.0))
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := AutochessHud.s(10.5)
		draw_circle(c + Vector2(0, 2), r, AutochessHud.INK)
		draw_circle(c, r, AutochessHud.candy("soleil", 0))
		draw_arc(c, r, 0.0, TAU, 28, AutochessHud.INK, 2.0, true)
		draw_arc(c, r * 0.58, 0.0, TAU, 20, AutochessHud.candy("soleil", 2), 2.0, true)


## Intérêts : une pastille par tranche de 10 or, jusqu'au plafond (pomme = acquise).
class Interest extends Control:
	var have := 0
	var cap := 5

	func _init() -> void:
		custom_minimum_size = Vector2(70, 26)
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var step := AutochessHud.s(13.0)
		var r := AutochessHud.s(4.6)
		for i in cap:
			var c := Vector2(r + 2.0 + i * step, size.y * 0.5)
			draw_circle(c, r, AutochessHud.candy("pomme") if i < have else AutochessHud.PAPER)
			draw_arc(c, r, 0.0, TAU, 16, AutochessHud.INK, 1.6, true)


## Flamme de série (2 victoires ou plus : mandarine ; 2 défaites ou plus : lagon), avec le nombre ; infobulle : l'or gagné.
class Flame extends HBoxContainer:
	var value := 0
	var _icon: FlameIcon
	var _num: Label

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		add_theme_constant_override("separation", 1)
		_icon = FlameIcon.new()
		add_child(_icon)
		_num = AutochessHud.pop_lbl("", 18)
		_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_num)
		visible = false

	func set_streak(st: int) -> void:
		value = st
		var n := absi(st)
		visible = n >= 2
		_icon.win = st > 0
		_icon.queue_redraw()
		_num.text = str(n)
		var gold := AutochessData.streak_gold(st)
		tooltip_text = ("Série de %d victoires" if st > 0 else "Série de %d défaites") % n + (" : +%d or par manche." % gold if gold > 0 else ".")


class FlameIcon extends Control:
	var win := true

	func _init() -> void:
		custom_minimum_size = Vector2(AutochessHud.s(20.0), AutochessHud.s(28.0))
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.62)
		var tone: String = "mandarine" if win else "lagon"
		var outer := _flame(c, AutochessHud.s(8.0), AutochessHud.s(13.0))
		draw_colored_polygon(outer, AutochessHud.candy(tone))
		var inner := _flame(c + Vector2(0, AutochessHud.s(2.0)), AutochessHud.s(4.2), AutochessHud.s(7.0))
		draw_colored_polygon(inner, AutochessHud.candy("soleil", 0) if win else Color.WHITE)
		outer.append(outer[0])
		draw_polyline(outer, AutochessHud.INK, 2.0, true)

	static func _flame(c: Vector2, r: float, h: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 15:
			var a := lerpf(-0.12 * PI, 1.12 * PI, float(i) / 14.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		pts.append(c + Vector2(-r * 0.55, -h * 0.55))
		pts.append(c + Vector2(-r * 0.1, -h * 0.35))
		pts.append(c + Vector2(r * 0.15, -h))
		return pts


## Taux de la boutique au niveau du stratège : 5 segments aux couleurs des coûts, largeur proportionnelle ; les
## pourcentages sont seulement dans l'infobulle (aucun % dans le texte permanent).
class OddsBar extends Control:
	var level := 1
	var odds: Array = [100, 0, 0, 0, 0]

	func _init() -> void:
		custom_minimum_size = Vector2(0, AutochessHud.s(12.0))
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_level(lv: int) -> void:
		if lv == level and tooltip_text != "":
			return
		level = lv
		odds = AutochessData.shop_odds(lv)
		var lines: Array = ["Chances de la boutique au niveau %d :" % lv]
		for i in odds.size():
			if int(odds[i]) > 0:
				lines.append("coût %d : %d %%" % [i + 1, int(odds[i])])
		tooltip_text = "\n".join(lines)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var total := 0.0
		for o in odds:
			total += float(o)
		var x := 0.0
		for i in odds.size():
			var w := size.x * float(odds[i]) / maxf(total, 1.0)
			if w <= 0.0:
				continue
			draw_rect(Rect2(x, 0.0, w, size.y), AutochessHud.cost_candy(i + 1))
			if x > 0.0:
				draw_line(Vector2(x, 0), Vector2(x, size.y), AutochessHud.INK, 1.5)
			x += w
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.border_color = AutochessHud.INK
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(3)
		draw_style_box(sb, r)
