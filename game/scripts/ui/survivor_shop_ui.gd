class_name SurvivorShopUI
extends CanvasLayer
## Écran de la boutique du gardien (lot SVX-4, BM-SURV SV-R3 ; règles : SurvivorShop). Créé par le directeur du Survivant au
## premier gardien vaincu ; jeu en pause tant qu'il est ouvert (groupe CardPicker.PAUSE_GROUP), le jeu flouté derrière
## (BIBLE § 2). Quatre cartes papier (le rendu court des choix de niveau, SurvivorCardView.build_v2), sous chacune
## « Acheter · prix » (soleil) et « Garder » (lagon : l'offre attend la boutique suivante) ; une barre : Relancer (X / R),
## Continuer (B / Échap). Touches 1 à 4 : acheter l'offre. Tient dans 1280 × 720.

signal closed

const CARD_W := [236.0, 268.0]  # largeur d'une carte : sous / au-dessus de 1500 px
const BAND_H := 38.0

var _root: Control
var _title: Label
var _sub: Label
var _row: HBoxContainer
var _reroll: Button
var _go: Button
var _t := 0.0
var _cols: Array = []


func _ready() -> void:
	layer = 19
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(CardPicker.PAUSE_GROUP)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color.WHITE
	dim.material = UiTheme.blur_material()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.title(_title, 38, UiTheme.color("bonbon.soleil.base"))
	_title.text = "Boutique du gardien"
	_title.rotation_degrees = -3.0
	_title.resized.connect(func(): _title.pivot_offset = _title.size * 0.5)
	v.add_child(_title)
	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_override("font", UiTheme.bold_font())
	_sub.add_theme_font_size_override("font_size", 17)
	_sub.add_theme_color_override("font_color", UiTheme.color("papier.100"))
	_sub.add_theme_constant_override("outline_size", 4)
	_sub.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	v.add_child(_sub)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 16)
	v.add_child(_row)
	var bar := HBoxContainer.new()
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 16)
	v.add_child(bar)
	_reroll = Button.new()
	UiTheme.style_button(_reroll, "lagon", 18)
	_reroll.custom_minimum_size = Vector2(250, 52)
	_reroll.pressed.connect(_do_reroll)
	bar.add_child(_reroll)
	_go = Button.new()
	UiTheme.style_button(_go, "papier", 18)
	_go.custom_minimum_size = Vector2(220, 52)
	_go.pressed.connect(close_shop)
	bar.add_child(_go)


func is_open() -> bool:
	return _root != null and _root.visible


## Ouvre une boutique (SurvivorShop.open) à [param t] secondes de carte.
func open_shop(t: float) -> void:
	_t = t
	SurvivorShop.open()
	_root.visible = true
	get_tree().paused = true
	var host := get_parent()
	if host and "hud" in host and host.hud:
		host.hud.hide_banner()
	_refresh()
	Sfx.ui("confirm", -6.0)
	if Gamepad.active and not _cols.is_empty():
		UiNav.focus((_cols[0] as Dictionary).buy)


func close_shop() -> void:
	if not is_open():
		return
	SurvivorShop.close(_t)
	_root.visible = false
	get_tree().paused = CardPicker.pause_held(get_tree(), self)
	var host := get_parent()
	if host and "player" in host and host.player:
		host.player.recalc_stats()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_B):
		close_shop()
		get_viewport().set_input_as_handled()
	elif (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_R) \
			or (event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_X):
		_do_reroll()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_4:
			_do_buy(k - KEY_1)
			get_viewport().set_input_as_handled()


func _do_buy(i: int) -> void:
	if i < 0 or i >= SurvivorShop.offers.size():
		return
	var o: Dictionary = SurvivorShop.offers[i]
	if SurvivorShop.buy(o):
		Sfx.ui("confirm", -3.0)
		var host := get_parent()
		if host and "player" in host and host.player:
			host.player.recalc_stats()
		SurvivorLog.moment(_t, "Achat : %s" % String(o.card.get("title", "")), "shop")
	else:
		Sfx.ui("cancel", -8.0)
	_refresh()


func _do_reroll() -> void:
	if SurvivorShop.reroll():
		Sfx.ui("ui_tab", -6.0)
	else:
		Sfx.ui("cancel", -8.0)
	_refresh()


func _refresh() -> void:
	_sub.text = "Ton or : %s  ·  « Garder » met une offre de côté pour la prochaine boutique" % Items.fmt_num(Profile.gold)
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	_cols.clear()
	var vw := get_viewport().get_visible_rect().size.x
	var vh := get_viewport().get_visible_rect().size.y
	var w: float = CARD_W[1] if vw >= 1500.0 else CARD_W[0]
	var card_h := clampf(vh - 300.0, 250.0, 420.0)
	for i in SurvivorShop.offers.size():
		_cols.append(_column(SurvivorShop.offers[i], i, w, card_h))
	var rp := SurvivorShop.reroll_price()
	_reroll.text = "Relancer · %s or" % Items.fmt_num(rp)
	_reroll.disabled = Profile.gold < rp
	_reroll.tooltip_text = "De nouvelles offres à la place de celles qui ne sont ni achetées ni gardées. Le prix monte à chaque relance."
	_go.text = "Continuer"
	_go.tooltip_text = "Ferme la boutique : la partie reprend. Les offres gardées t'attendent à la prochaine."


func _column(o: Dictionary, i: int, w: float, card_h: float) -> Dictionary:
	var card: Dictionary = o.card
	var tones := SurvivorCardView.tones_of(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_row.add_child(col)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, card_h)
	p.add_theme_stylebox_override("panel", UiTheme.sticker("papier", {"shadow": 6, "radius": 18, "gloss": false, "cel_top": 0.0, "cel_bottom": 0.06, "pad": Vector2.ZERO}))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.modulate.a = 0.55 if bool(o.get("sold", false)) else 1.0
	col.add_child(p)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)
	var band := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = tones[1]
	sb.border_color = UiTheme.color("encre.700")
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.content_margin_left = 12
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	band.add_theme_stylebox_override("panel", sb)
	band.custom_minimum_size = Vector2(0, BAND_H)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(band)
	var bh := HBoxContainer.new()
	bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(bh)
	var key := Label.new()
	key.text = "%d" % (i + 1)
	key.add_theme_font_override("font", UiTheme.title_font())
	key.add_theme_font_size_override("font_size", 18)
	key.add_theme_color_override("font_color", Color.WHITE)
	key.add_theme_constant_override("outline_size", 4)
	key.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	bh.add_child(key)
	var rank := SurvivorCardView.shape_rank(card)
	if rank >= 0:  # forme de la rareté (jamais la couleur seule)
		var shp := Control.new()
		shp.custom_minimum_size = Vector2(22, 22)
		shp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shp.draw.connect(func(): SurvivorCardView.draw_shape(shp, shp.size * 0.5, 6.0, rank))
		bh.add_child(shp)
	var bt := Label.new()
	bt.text = SurvivorCardView.band_text(card)
	bt.add_theme_font_override("font", UiTheme.bold_font())
	bt.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
	bt.add_theme_color_override("font_color", Color.WHITE)
	bt.add_theme_constant_override("outline_size", 4)
	bt.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	bt.clip_text = true
	bt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bh.add_child(bt)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	inner.add_child(scroll)
	var m := MarginContainer.new()
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 12)
	m.add_theme_constant_override("margin_bottom", 8)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(m)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(content)
	SurvivorCardView.build_v2(content, card, tones)
	var foot := content.get_child(content.get_child_count() - 1) as Label
	if foot != null and foot.text.begins_with("Maj"):
		foot.queue_free()  # (pas de carte complète à la boutique)
	var buy := Button.new()
	var sold := bool(o.get("sold", false))
	buy.text = ("Plus proposée" if bool(o.get("gone", false)) else "Achetée !") if sold else "Acheter · %s or" % Items.fmt_num(int(o.price))
	UiTheme.style_button(buy, "soleil", 17)
	buy.custom_minimum_size = Vector2(w, 46)
	buy.disabled = sold or Profile.gold < int(o.price)
	buy.tooltip_text = "Prends cette carte tout de suite." if not sold else ""
	buy.pressed.connect(_do_buy.bind(i))
	col.add_child(buy)
	var keep := Button.new()
	keep.text = "Gardée pour la suivante ✓" if bool(o.get("kept", false)) else "Garder"
	UiTheme.style_button(keep, "lagon" if bool(o.get("kept", false)) else "papier", 16)
	keep.custom_minimum_size = Vector2(w, 40)
	keep.disabled = sold
	keep.tooltip_text = "Gratuit : l'offre t'attend à la prochaine boutique du gardien (elle ne part pas à la relance)."
	keep.pressed.connect(_do_keep.bind(i))
	col.add_child(keep)
	return {"buy": buy, "keep": keep, "panel": p}


func _do_keep(i: int) -> void:
	if i >= 0 and i < SurvivorShop.offers.size():
		SurvivorShop.toggle_keep(SurvivorShop.offers[i])
		Sfx.ui("click", -8.0)
	_refresh()
