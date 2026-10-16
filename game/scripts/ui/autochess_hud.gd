class_name AutochessHud
extends Control
## L'Échiquier (lot AC-G) : cadre de la partie (SPEC §7.1, « Compose ton équipe »). En haut : frise de l'étape (● combat,
## ▲ monstres, ◆ choix partagé, gros rond rouge : gardien, point doré : atout), étape et manche, minuteur, ×2 en combat.
## À gauche : traits (AutochessTraitPanel), remplacés par la fiche d'unité (AutochessUnitCard) quand une unité est visée.
## À droite : les 8 stratèges (AutochessPlayers). En bas : niveau + barre d'XP + [Acheter de l'XP], la boutique
## (AutochessShop) avec l'or au centre (onglet au-dessus : or, intérêts), [Actualiser], [Verrouiller], [Prêt] ; en combat
## la boutique est repliée (« Combat contre … », barre, ×2). Bandeau de bilan de manche, petits avis, fin de partie.
## L'écran (AutochessScreen) branche les signaux sur la partie (Autochess) ; ce cadre n'appelle jamais la partie.
## Aides de style partagées par les panneaux du mode : lbl(), box(), button().

signal reroll_pressed
signal xp_pressed
signal lock_pressed
signal ready_pressed
signal speed_pressed
signal choice_pressed
signal replay_pressed
signal back_pressed

const BG := Color(0.055, 0.065, 0.16, 0.95)
const BG_SOFT := Color(0.05, 0.06, 0.15, 0.82)
const BOTTOM_H := 186.0  # pied de l'écran réservé (boutique et onglet de l'or) : plateau et bancs au-dessus (R_AC_F)
const SHOP_H := 130.0  # hauteur du panneau de la boutique
const BOTTOM_GAP := 40.0  # sous la boutique : barre d'aide de la manette, numéro de version
const SIDE_W := 236.0
const TOP_Y := 74.0
const KIND_NAMES := {"ouverture": "Ouverture", "monstres": "Monstres", "jcj": "Combat de stratèges",
	"choix": "Choix partagé", "gardien": "Gardien"}

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
var _toast: Label
var _toast_t := 0.0
var _end: PanelContainer
var _end_place: Label
var _end_lines: Label
var _keys_pad := false


func _init() -> void:
	name = "AcHud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_sides()
	_build_bottom()
	_build_banner()
	_build_end()


# --- style partagé ------------------------------------------------------------------------------------------------
## Étiquette : [param font] « body », « bold » ou « title ».
static func lbl(text: String, size := 16, col := UiTheme.TEXT, font := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == "title":
		UiTheme.title(l, size, col)
	else:
		l.add_theme_font_override("font", UiTheme.bold_font() if font == "bold" else UiTheme.body_font())
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", col)
		l.add_theme_constant_override("outline_size", 4)
		l.add_theme_color_override("font_outline_color", Color(UiTheme.INK, 0.8))
	return l


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


## Bouton du mode : [param kind] « plain » (bleu nuit, filet doré) ou « primary » (or) ; [param key] / [param pad] :
## touche du clavier et bouton de la manette, rappelés dans le coin.
static func button(text: String, kind := "plain", h := 36.0, key := "", pad := "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_override("font", UiTheme.bold_font())
	b.add_theme_font_size_override("font_size", 16 if h >= 36.0 else 15)
	var primary := kind == "primary"
	var bg := UiTheme.GOLD if primary else Color(0.09, 0.1, 0.23, 0.96)
	var n := box(bg, UiTheme.GOLD if primary else UiTheme.GOLD_DIM, 2, 8, 12, 4)
	var hv := box(bg.lightened(0.12), UiTheme.GOLD.lightened(0.2), 2, 8, 12, 4)
	var dis := box(Color(bg, 0.45), Color(UiTheme.GOLD_DIM, 0.4), 2, 8, 12, 4)
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("disabled", dis)
	var fc := UiTheme.INK if primary else UiTheme.TEXT
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_disabled_color", Color(UiTheme.MUTED, 0.6))
	b.pressed.connect(func(): Sfx.ui("click", -8.0))
	if key != "" or pad != "":
		for sb in [n, hv, dis]:
			(sb as StyleBoxFlat).content_margin_right = 26.0
			(sb as StyleBoxFlat).content_margin_left = 16.0
		b.set_meta("key", key)
		b.set_meta("pad", pad)
		var k := lbl(key, 12, Color(UiTheme.INK, 0.6) if primary else Color(UiTheme.MUTED, 0.75), "bold")
		k.name = "Key"
		k.add_theme_constant_override("outline_size", 0)
		k.anchor_left = 1.0
		k.anchor_right = 1.0
		k.offset_left = -60.0
		k.offset_right = -5.0
		k.offset_top = 1.0
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(k)
	return b


# --- construction ---------------------------------------------------------------------------------------------------
func _build_top() -> void:
	_top = PanelContainer.new()
	_top.name = "AcTop"
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	_top.add_theme_stylebox_override("panel", box(BG, UiTheme.GOLD_DIM, 2, 12, 16, 6))
	_top.anchor_left = 0.5
	_top.anchor_right = 0.5
	_top.offset_top = 8.0
	_top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_top)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(h)
	_frieze = Frieze.new()
	h.add_child(_frieze)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_stage = lbl("", 18, UiTheme.GOLD, "title")
	v.add_child(_stage)
	_kind = lbl("", 14, UiTheme.MUTED)
	v.add_child(_kind)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 2)
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	_timer = lbl("", 22, UiTheme.TEXT, "title")
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.custom_minimum_size.x = 64
	tv.add_child(_timer)
	_timer_bar = ProgressBar.new()
	_timer_bar.show_percentage = false
	_timer_bar.custom_minimum_size = Vector2(64, 5)
	_timer_bar.max_value = 1.0
	_timer_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timer_bar.add_theme_stylebox_override("background", box(Color(UiTheme.INK, 0.8), Color(0, 0, 0, 0), 0, 3, 0, 0))
	_timer_bar.add_theme_stylebox_override("fill", box(UiTheme.GOLD, UiTheme.GOLD, 0, 3, 0, 0))
	tv.add_child(_timer_bar)
	choice_button = button("Revenir au choix", "primary", 34.0)
	choice_button.name = "AcChoiceBack"
	choice_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	choice_button.pressed.connect(func(): choice_pressed.emit())
	choice_button.visible = false
	h.add_child(choice_button)


func _build_sides() -> void:
	traits = AutochessTraitPanel.new()
	traits.position = Vector2(16, TOP_Y)
	add_child(traits)
	unit_card = AutochessUnitCard.new()
	unit_card.position = Vector2(16, TOP_Y)
	add_child(unit_card)
	players = AutochessPlayers.new()
	players.anchor_left = 1.0
	players.anchor_right = 1.0
	players.offset_left = -16.0 - SIDE_W
	players.offset_right = -16.0
	players.offset_top = TOP_Y
	add_child(players)


func _build_bottom() -> void:
	_bottom = PanelContainer.new()
	_bottom.name = "AcBottom"
	_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	_bottom.add_theme_stylebox_override("panel", box(BG, UiTheme.GOLD_DIM, 2, 12, 12, 8))
	_bottom.anchor_left = 0.5
	_bottom.anchor_right = 0.5
	_bottom.anchor_top = 1.0
	_bottom.anchor_bottom = 1.0
	_bottom.offset_top = -BOTTOM_GAP - SHOP_H
	_bottom.offset_bottom = -BOTTOM_GAP
	_bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_bottom)
	_prep_row = HBoxContainer.new()
	_prep_row.add_theme_constant_override("separation", 12)
	_prep_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(_prep_row)
	# niveau, XP, acheter de l'XP
	var lv := VBoxContainer.new()
	lv.custom_minimum_size.x = 176
	lv.add_theme_constant_override("separation", 3)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prep_row.add_child(lv)
	_level = lbl("", 22, UiTheme.GOLD, "title")
	lv.add_child(_level)
	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.custom_minimum_size = Vector2(0, 9)
	_xp_bar.max_value = 1.0
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar.add_theme_stylebox_override("background", box(Color(UiTheme.INK, 0.85), Color(UiTheme.GOLD_DIM, 0.5), 1, 4, 0, 0))
	_xp_bar.add_theme_stylebox_override("fill", box(Color(0.45, 0.7, 1.0), Color(0.45, 0.7, 1.0), 0, 4, 0, 0))
	lv.add_child(_xp_bar)
	_xp_text = lbl("", 14, UiTheme.MUTED)
	lv.add_child(_xp_text)
	xp_button = button("Acheter de l'XP", "plain", 34.0, "F", "LB")
	xp_button.name = "AcXp"
	xp_button.pressed.connect(func(): xp_pressed.emit())
	lv.add_child(xp_button)
	# boutique
	shop = AutochessShop.new()
	shop.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_prep_row.add_child(shop)
	# actualiser, verrou, prêt
	var rv := VBoxContainer.new()
	rv.custom_minimum_size.x = 156
	rv.add_theme_constant_override("separation", 5)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prep_row.add_child(rv)
	reroll_button = button("Actualiser", "plain", 34.0, "D", "LT")
	reroll_button.name = "AcReroll"
	reroll_button.pressed.connect(func(): reroll_pressed.emit())
	rv.add_child(reroll_button)
	lock_button = button("Verrouiller", "plain", 30.0, "V", "RT")
	lock_button.name = "AcLock"
	lock_button.pressed.connect(func(): lock_pressed.emit())
	rv.add_child(lock_button)
	ready_button = button("Prêt", "primary", 40.0, "Espace", "Y")
	ready_button.name = "AcReady"
	ready_button.add_theme_font_size_override("font_size", 20)
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
	cv.custom_minimum_size.x = 520
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", 8)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_row.add_child(cv)
	_combat_text = lbl("", 22, UiTheme.GOLD, "title")
	_combat_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(_combat_text)
	_combat_bar = ProgressBar.new()
	_combat_bar.show_percentage = false
	_combat_bar.max_value = 1.0
	_combat_bar.custom_minimum_size = Vector2(0, 10)
	_combat_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_bar.add_theme_stylebox_override("background", box(Color(UiTheme.INK, 0.85), Color(UiTheme.GOLD_DIM, 0.5), 1, 4, 0, 0))
	_combat_bar.add_theme_stylebox_override("fill", box(UiTheme.GOLD, UiTheme.GOLD, 0, 4, 0, 0))
	cv.add_child(_combat_bar)
	speed_button = button("Vitesse ×1", "plain", 40.0, "", "Y")
	speed_button.name = "AcSpeed"
	speed_button.custom_minimum_size.x = 150
	speed_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speed_button.pressed.connect(func(): speed_pressed.emit())
	_combat_row.add_child(speed_button)
	# l'or, au centre, en onglet au-dessus de la boutique
	_gold_tab = PanelContainer.new()
	_gold_tab.name = "AcGold"
	_gold_tab.mouse_filter = Control.MOUSE_FILTER_PASS
	_gold_tab.add_theme_stylebox_override("panel", box(BG, UiTheme.GOLD, 2, 14, 16, 2))
	_gold_tab.anchor_left = 0.5
	_gold_tab.anchor_right = 0.5
	_gold_tab.anchor_top = 1.0
	_gold_tab.anchor_bottom = 1.0
	_gold_tab.offset_top = -BOTTOM_H
	_gold_tab.offset_bottom = -BOTTOM_H + 30.0
	_gold_tab.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_gold_tab)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 8)
	gh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gold_tab.add_child(gh)
	var coin := Coin.new()
	gh.add_child(coin)
	_gold = lbl("", 20, UiTheme.GOLD, "title")
	gh.add_child(_gold)
	_interest = Interest.new()
	gh.add_child(_interest)
	_toast = lbl("", 17, UiTheme.TEXT, "bold")
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.anchor_left = 0.5
	_toast.anchor_right = 0.5
	_toast.offset_left = -300.0
	_toast.offset_right = 300.0
	_toast.offset_top = TOP_Y + 100.0
	_toast.offset_bottom = TOP_Y + 128.0
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.modulate.a = 0.0
	add_child(_toast)


func _build_banner() -> void:
	_banner = PanelContainer.new()
	_banner.name = "AcBanner"
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_theme_stylebox_override("panel", box(BG, UiTheme.GOLD, 2, 14, 28, 10))
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_top = TOP_Y + 6.0
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_banner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(v)
	_banner_title = lbl("", 28, UiTheme.GOLD, "title")
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_banner_title)
	_banner_line = lbl("", 18, UiTheme.TEXT, "bold")
	_banner_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_banner_line)
	_banner_detail = lbl("", 15, UiTheme.MUTED)
	_banner_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_banner_detail)
	_banner.visible = false


func _build_end() -> void:
	_end = PanelContainer.new()
	_end.name = "AcEnd"
	_end.mouse_filter = Control.MOUSE_FILTER_STOP
	_end.add_theme_stylebox_override("panel", UiTheme.panel_box(40, 26))
	_end.set_anchors_preset(Control.PRESET_CENTER)
	_end.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_end.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_end)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.custom_minimum_size.x = 380
	_end.add_child(v)
	var t := lbl("Ta place", 22, UiTheme.MUTED, "title")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_end_place = lbl("", 64, UiTheme.GOLD, "title")
	_end_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_place)
	_end_lines = lbl("", 17, UiTheme.TEXT)
	_end_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_lines)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	replay_button = button("Rejouer", "primary", 42.0)
	replay_button.name = "AcReplay"
	replay_button.custom_minimum_size.x = 160
	replay_button.pressed.connect(func(): replay_pressed.emit())
	row.add_child(replay_button)
	back_button = button("Retour", "plain", 42.0)
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
	if AutochessData.is_augment_round(g.stage, g.round_i):
		_kind.text += " · atout"
	_frieze.set_stage(g.stage, g.round_i)
	_level.text = "Niveau %d" % int(p.level)
	var need := AutochessData.xp_to_next(int(p.level))
	var maxed := int(p.level) >= int(p.max_level)
	if maxed:
		_xp_bar.value = 1.0
		_xp_text.text = "Niveau maximal"
	elif need <= 0:  # niveau 1 : le niveau 2 est donné à la manche suivante
		_xp_bar.value = 0.0
		_xp_text.text = "Niveau 2 à la prochaine manche"
	else:
		_xp_bar.value = float(p.xp) / float(need)
		_xp_text.text = "%d / %d XP" % [int(p.xp), need]
	xp_button.text = "Acheter de l'XP · %d" % AutochessData.XP_BUY_COST
	xp_button.disabled = maxed or need <= 0
	xp_button.tooltip_text = "+%d XP pour %d or" % [AutochessData.XP_BUY_AMOUNT, AutochessData.XP_BUY_COST]
	var free := int(p.free_rerolls)
	reroll_button.text = "Actualiser · offert" if free > 0 else "Actualiser · %d" % AutochessData.REROLL_COST
	reroll_button.tooltip_text = "Cinq nouvelles offres."
	lock_button.text = "Verrouillée" if bool(p.locked) else "Verrouiller"
	lock_button.tooltip_text = "La boutique reste la même à la manche suivante." if not bool(p.locked) else "Clique pour la libérer."
	lock_button.add_theme_color_override("font_color", UiTheme.GOLD if bool(p.locked) else UiTheme.TEXT)
	_gold.text = "%d" % int(p.gold)
	var cap := int(g._interest_cap(p)) if not g._has_effect(p, "or_sans_interets") else 0
	_interest.cap = cap
	_interest.custom_minimum_size.x = maxf(cap, 1) * 12.0 + 4.0
	_interest.have = AutochessData.interest(int(p.gold), cap)
	_interest.queue_redraw()
	_gold_tab.tooltip_text = "Intérêts : +1 or par tranche de 10, %d au plus." % cap if cap > 0 else "Plus aucun intérêt."
	shop.refresh(g, me)
	traits.refresh(g.trait_counts(me))
	players.refresh(g, me, foe, scouted)
	_update_keys()


## Minuteur : [param left] secondes sur [param total] (total <= 0 : caché).
func set_timer(left: float, total: float) -> void:
	_timer.visible = total > 0.0
	_timer_bar.visible = total > 0.0
	_timer.text = "%d" % ceili(maxf(left, 0.0))
	_timer.add_theme_color_override("font_color", UiTheme.DEBUFF if left <= 5.0 else UiTheme.TEXT)
	_timer_bar.value = clampf(left / maxf(total, 0.01), 0.0, 1.0)


## « prep » : boutique ; « combat » : boutique repliée ; « over » : fin de partie.
func set_mode(m: String) -> void:
	mode = m
	_prep_row.visible = m == "prep"
	_combat_row.visible = m != "prep"
	_gold_tab.visible = m == "prep"
	_bottom.visible = m != "over"
	if m != "over":
		_end.visible = false


func set_combat(text: String, progress: float, speed: float) -> void:
	_combat_text.text = text
	_combat_bar.value = clampf(progress, 0.0, 1.0)
	speed_button.text = "Vitesse ×%d" % int(speed)


## Les cartes de choix sont ouvertes : la fiche d'unité se cache ; [param top] : la frise aussi (choix partagé).
func set_overlay(on: bool, top := false) -> void:
	_top.visible = not (on and top)
	if on:
		unit_card.hide_card()


## Boutique masquée pendant qu'une unité est tenue (la zone « Vendre » du curseur apparaît à sa place).
func set_holding(on: bool) -> void:
	_bottom.visible = not on and mode != "over"
	_gold_tab.visible = not on and mode == "prep"


func show_banner(title: String, line := "", detail := "", col := UiTheme.GOLD, secs := AutochessData.ROUND_RECAP) -> void:
	_banner_title.text = title
	_banner_title.add_theme_color_override("font_color", col)
	_banner_line.text = line
	_banner_line.visible = line != ""
	_banner_detail.text = detail
	_banner_detail.visible = detail != ""
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner_t = secs
	_banner.reset_size()


func banner_text() -> String:
	return "%s|%s|%s" % [_banner_title.text, _banner_line.text, _banner_detail.text] if _banner.visible else ""


func toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast_t = 2.2


func toast_text() -> String:
	return _toast.text if _toast.modulate.a > 0.0 else ""


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
	for b in [xp_button, reroll_button, lock_button, ready_button, speed_button]:
		var k: Label = (b as Button).get_node_or_null("Key")
		if k == null:
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
		k.text = pk if pad else String(b.get_meta("key", ""))


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t < 0.3:
			_banner.modulate.a = maxf(_banner_t / 0.3, 0.0)
		if _banner_t <= 0.0:
			_banner.visible = false
	if _toast_t > 0.0:
		_toast_t -= delta
		_toast.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
	if Gamepad.active != _keys_pad:
		_update_keys()
		shop.refresh_keys()


# --- petits dessins -------------------------------------------------------------------------------------------------
## Frise de l'étape : une marque par manche, selon son type ; la manche en cours cerclée d'or.
class Frieze extends Control:
	var stage := 1
	var round_i := 1

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size = Vector2(160, 30)

	func set_stage(st: int, rd: int) -> void:
		if st == stage and rd == round_i:
			return
		stage = st
		round_i = rd
		var n := AutochessData.rounds_in(st)
		custom_minimum_size = Vector2(n * 22.0 + 6.0, 30)
		var parts: Array = []
		for r in range(1, n + 1):
			parts.append(String(AutochessHud.KIND_NAMES.get(AutochessData.round_kind(st, r), "")))
		tooltip_text = "Étape %d : %s" % [st, ", ".join(parts).to_lower()]
		queue_redraw()

	func _draw() -> void:
		var n := AutochessData.rounds_in(stage)
		var cy := size.y * 0.5 + 2.0
		for r in range(1, n + 1):
			var c := Vector2(14.0 + (r - 1) * 22.0, cy)
			var past := r < round_i
			var cur := r == round_i
			var col := UiTheme.GOLD if cur else (Color(UiTheme.MUTED, 0.45) if past else UiTheme.MUTED)
			if r > 1:
				draw_line(c - Vector2(16, 0), c - Vector2(7, 0), Color(UiTheme.GOLD_DIM, 0.5), 1.5)
			match AutochessData.round_kind(stage, r):
				"jcj":
					draw_circle(c, 5.0, col)
				"monstres":
					draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 5), c + Vector2(-6, 5)]), col)
				"choix":
					draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)]), col)
				"gardien":
					draw_circle(c, 7.0, Color(UiTheme.HP, 0.9 if not past else 0.4))
					draw_circle(c, 3.0, UiTheme.INK)
				_:
					draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), col)
			if cur:
				draw_arc(c, 10.0, 0.0, TAU, 24, UiTheme.GOLD, 1.5, true)
			if AutochessData.is_augment_round(stage, r):
				draw_circle(c + Vector2(0, -12), 2.5, UiTheme.GOLD)


## Pièce d'or.
class Coin extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(22, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 9.0, UiTheme.GOLD_DIM)
		draw_circle(c, 7.0, UiTheme.GOLD)
		draw_arc(c, 4.5, 0.0, TAU, 16, UiTheme.GOLD_DIM, 1.5, true)


## Intérêts : une pastille par tranche de 10 or, jusqu'au plafond.
class Interest extends Control:
	var have := 0
	var cap := 5

	func _init() -> void:
		custom_minimum_size = Vector2(70, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for i in cap:
			var c := Vector2(7.0 + i * 12.0, size.y * 0.5)
			if i < have:
				draw_circle(c, 4.0, UiTheme.GOLD)
			else:
				draw_arc(c, 4.0, 0.0, TAU, 12, Color(UiTheme.GOLD_DIM, 0.7), 1.2, true)
