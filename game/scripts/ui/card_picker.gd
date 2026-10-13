class_name CardPicker
extends CanvasLayer
## Choix de cartes (nouvelle compétence, amélioration, passif) au passage de
## niveau et au départ de la run. Met le jeu en pause pendant le choix.
## Cliquer une carte la sélectionne seulement : le choix se confirme avec le
## bouton « Valider » (ou Entrée), pour ne pas choisir par erreur en spammant
## l'auto-attaque au moment du passage de niveau.

signal picked(card: Dictionary)

const ACCENT := Color(0.98, 0.78, 0.35)
const TYPE_COLORS := {"skill": Color(1.0, 0.55, 0.3), "upgrade": Color(0.45, 0.75, 1.0), "passive": Color(0.6, 0.95, 0.55)}
const CONFIRM_DELAY_MS := 400  # Valider inactif juste après l'ouverture (clics en rafale)

var _queue: Array = []  # [titre, cartes, relance (Callable)]
var _reroll_fn: Callable
var _reroll: Button
var _cards: Array = []
var _root: Control
var _title: Label
var _row: HBoxContainer
var _buttons: Array = []
var _selected := -1
var _confirm: Button
var _opened_at := 0


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
	v.position = Vector2(-560, -270)
	v.custom_minimum_size = Vector2(1120, 0)
	_root.add_child(v)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.title(_title, 40, ACCENT)
	v.add_child(_title)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 28)
	v.add_child(_row)
	_confirm = Button.new()
	_confirm.custom_minimum_size = Vector2(260, 56)
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.add_theme_font_size_override("font_size", 24)
	_confirm.add_theme_color_override("font_color", Color(0.1, 0.05, 0.15))
	_confirm.add_theme_color_override("font_hover_color", Color(0.1, 0.05, 0.15))
	_confirm.add_theme_color_override("font_pressed_color", Color(0.1, 0.05, 0.15))
	_confirm.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	var cs := StyleBoxFlat.new()
	cs.bg_color = ACCENT
	cs.set_corner_radius_all(10)
	var ch := cs.duplicate() as StyleBoxFlat
	ch.bg_color = ACCENT.lightened(0.25)
	var cd := cs.duplicate() as StyleBoxFlat
	cd.bg_color = Color(0.2, 0.18, 0.28, 0.9)
	_confirm.add_theme_stylebox_override("normal", cs)
	_confirm.add_theme_stylebox_override("hover", ch)
	_confirm.add_theme_stylebox_override("pressed", ch)
	_confirm.add_theme_stylebox_override("disabled", cd)
	_confirm.pressed.connect(_confirm_choice)
	_reroll = Button.new()
	_reroll.custom_minimum_size = Vector2(200, 56)
	_reroll.focus_mode = Control.FOCUS_NONE
	_reroll.add_theme_font_size_override("font_size", 18)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.16, 0.13, 0.26, 0.95)
	rs.border_color = Color(0.6, 0.55, 0.85)
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(10)
	_reroll.add_theme_stylebox_override("normal", rs)
	var rh := rs.duplicate() as StyleBoxFlat
	rh.bg_color = Color(0.26, 0.2, 0.4)
	_reroll.add_theme_stylebox_override("hover", rh)
	_reroll.add_theme_stylebox_override("pressed", rh)
	_reroll.add_theme_stylebox_override("disabled", cd)
	_reroll.pressed.connect(_do_reroll)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	buttons.add_child(_confirm)
	buttons.add_child(_reroll)
	v.add_child(buttons)
	var hint := Label.new()
	hint.text = "Clique sur une carte (ou 1, 2, 3) puis sur Valider (ou Entrée)"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(1, 1, 1, 0.7)
	v.add_child(hint)
	_root.visible = false
	add_child(_root)


## Ajoute un choix à la file (plusieurs niveaux d'un coup = plusieurs choix).
## [param reroll] : tire de nouvelles cartes (bouton « Relancer », limité par run).
func offer(title: String, cards: Array, reroll := Callable()) -> void:
	if cards.is_empty():
		return
	_queue.append([title, cards, reroll])
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
	_reroll_fn = item[2] if item.size() > 2 else Callable()
	_show_cards(item[1])
	_root.visible = true
	get_tree().paused = true


func _show_cards(cards: Array) -> void:
	_cards = cards
	for c in _row.get_children():
		c.queue_free()
	_buttons.clear()
	for i in _cards.size():
		var b := _make_card(_cards[i], i)
		_buttons.append(b)
		_row.add_child(b)
	_selected = -1
	_opened_at = Time.get_ticks_msec()
	_refresh_confirm()
	_refresh_reroll()


func _refresh_reroll() -> void:
	_reroll.visible = _reroll_fn.is_valid()
	var left := Run.rerolls_left()
	_reroll.text = "Relancer (%d)" % left
	_reroll.disabled = left <= 0


## Nouvelles cartes à la place des cartes proposées (une relance consommée).
func _do_reroll() -> void:
	if not _reroll_fn.is_valid() or Run.rerolls_left() <= 0:
		return
	var cards: Array = _reroll_fn.call()
	if cards.is_empty():
		return
	Run.rerolls_used += 1
	_show_cards(cards)
	_opened_at -= CONFIRM_DELAY_MS  # pas de délai anti-rafale après une relance volontaire


func _make_card(card: Dictionary, i: int) -> Button:
	# couleur : rareté tirée de la carte (Cards), sinon type de carte
	var col: Color = Cards.tier(String(card.tier)).color if card.has("tier") and card.tier != "common" 		else (Boons.RARITY[card.rarity].color if card.has("rarity") and card.rarity != "common" else TYPE_COLORS.get(card.type, ACCENT))
	var b := Button.new()
	b.custom_minimum_size = Vector2(320, 380)
	b.focus_mode = Control.FOCUS_NONE
	b.pivot_offset = b.custom_minimum_size * 0.5
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
	var chosen := hover.duplicate() as StyleBoxFlat
	chosen.bg_color = Color(0.22, 0.17, 0.32, 1.0)
	chosen.border_color = col.lightened(0.35)
	chosen.set_border_width_all(7)
	chosen.shadow_color = Color(col, 0.6)
	chosen.shadow_size = 18
	b.set_meta("style_normal", sb)
	b.set_meta("style_hover", hover)
	b.set_meta("style_selected", chosen)
	b.pressed.connect(_select.bind(i))
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
	icon.texture = UiTheme.texture(String(card.get("icon", "")))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(icon)
	var t := Label.new()
	t.text = card.title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.add_theme_font_size_override("font_size", 22)
	t.add_theme_font_override("font", UiTheme.bold_font())
	v.add_child(t)
	# description et totaux avant → après (texte enrichi)
	var d := RichTextLabel.new()
	d.bbcode_enabled = true
	d.text = card.desc
	d.scroll_active = false
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_theme_font_size_override("normal_font_size", 14)
	d.add_theme_font_size_override("bold_font_size", 15)
	d.add_theme_font_override("bold_font", UiTheme.bold_font())
	d.modulate = Color(0.92, 0.92, 0.95)
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(d)
	# bannir (la carte quitte la run, une autre la remplace) / garder (revient au prochain choix)
	if String(card.get("type", "")) in ["skill", "upgrade", "passive"] and _reroll_fn.is_valid():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		v.add_child(row)
		var ban := Button.new()
		ban.text = "Bannir (%d)" % (Cards.BANS_PER_RUN - Run.bans_used)
		ban.tooltip_text = "Cette carte ne sera plus proposée pendant la run ; une autre la remplace."
		ban.focus_mode = Control.FOCUS_NONE
		ban.add_theme_font_size_override("font_size", 13)
		ban.disabled = Run.bans_used >= Cards.BANS_PER_RUN or String(card.type) == "upgrade"
		ban.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ban.pressed.connect(func(): _ban(i))
		row.add_child(ban)
		var keep := Button.new()
		var is_kept: bool = Run.kept.any(func(k): return String(k.type) == String(card.type) and str(k.id) == str(card.id))
		keep.text = "Gardée ✔" if is_kept else "Garder (%d)" % (Cards.LOCKS_PER_RUN - Run.locks_used)
		keep.tooltip_text = "La carte revient au prochain choix, avec la même rareté, si tu en prends une autre maintenant."
		keep.focus_mode = Control.FOCUS_NONE
		keep.add_theme_font_size_override("font_size", 13)
		keep.disabled = is_kept or Run.locks_used >= Cards.LOCKS_PER_RUN
		keep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keep.pressed.connect(func():
			if Run.keep_card(card):
				_show_cards(_cards))
		row.add_child(keep)
	return b


func _ban(i: int) -> void:
	var rep := Run.ban_card(_cards[i], _cards)
	if rep.is_empty():
		_cards.remove_at(i)
	else:
		_cards[i] = rep
	_show_cards(_cards)
	_opened_at -= CONFIRM_DELAY_MS


func _process(_delta: float) -> void:
	# fin du délai anti-rafale : réactive Valider
	if _root.visible and _confirm.disabled and _selected >= 0:
		_refresh_confirm()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	# 1, 2, 3 sélectionnent seulement (ce sont aussi les touches de compétences)
	var n: int = event.physical_keycode - KEY_1
	if n >= 0 and n < _cards.size():
		_select(n)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_confirm_choice()
		get_viewport().set_input_as_handled()


func _select(i: int) -> void:
	_selected = i
	for j in _buttons.size():
		var b: Button = _buttons[j]
		var on := j == i
		b.add_theme_stylebox_override("normal", b.get_meta("style_selected" if on else "style_normal"))
		b.add_theme_stylebox_override("hover", b.get_meta("style_selected" if on else "style_hover"))
		b.add_theme_stylebox_override("pressed", b.get_meta("style_selected" if on else "style_hover"))
		b.scale = Vector2.ONE * (1.04 if on else 1.0)
	_refresh_confirm()


func _refresh_confirm() -> void:
	var ok := _selected >= 0 and Time.get_ticks_msec() - _opened_at >= CONFIRM_DELAY_MS
	_confirm.disabled = not ok
	_confirm.text = "Valider" if _selected >= 0 else "Choisis une carte"


func _confirm_choice() -> void:
	if _selected < 0 or _selected >= _cards.size() or Time.get_ticks_msec() - _opened_at < CONFIRM_DELAY_MS:
		return
	var card: Dictionary = _cards[_selected]
	_selected = -1
	# carte gardée puis prise maintenant : elle ne revient pas
	Run.kept = Run.kept.filter(func(k): return not (String(k.type) == String(card.type) and str(k.id) == str(card.id)))
	Run.apply_card(card)
	picked.emit(card)
	_show_next()
