class_name AutochessCarousel
extends Control
## L'Échiquier (lot AC-G, habillage v2 du lot ACX-1 : autocollants papier sur voile d'encre) : le choix partagé (manches x-4, SPEC §5.6, §7.1) : « Prends ton héros ». 9 cartes en anneau
## (unité + composant porté), l'ordre des stratèges en haut (PV les plus bas d'abord) ; les choix des autres apparaissent
## un à un (« Pris par … ») ; à ton tour, 10 s pour choisir (sinon la première carte libre est prise d'office, par l'écran).
## L'écran pilote le rythme (reveal) et appelle Autochess.choose ; ce panneau ne fait qu'afficher et prévenir (picked).

signal picked(option: int)

const CARD := Vector2(158, 112)

var cards: Array = []  # Button par option du choix partagé
var info: Label  # « À toi ! », « Brune choisit… »
var timer_label: Label
var _strip: HBoxContainer
var _title: Label
var _names: Array = []


func _init() -> void:
	name = "AcCarousel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(AutochessHud.INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override("separation", 6)
	_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.anchor_left = 0.0
	_strip.anchor_right = 1.0
	_strip.offset_top = 16.0
	_strip.offset_bottom = 54.0
	add_child(_strip)
	var mid := PanelContainer.new()
	mid.name = "Middle"
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_theme_stylebox_override("panel", AutochessHud.paper_panel(7.0, 26.0, 10.0))
	add_child(mid)
	var mv := VBoxContainer.new()
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_theme_constant_override("separation", 4)
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv.custom_minimum_size.x = 260
	mid.add_child(mv)
	_title = AutochessHud.pop_lbl("Prends ton héros", 28)
	_title.rotation = deg_to_rad(-3.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(_title)
	info = AutochessHud.ink_lbl("", 17, AutochessHud.INK, 800)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(info)
	timer_label = AutochessHud.pop_lbl("", 28, AutochessHud.candy("soleil"))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(timer_label)
	visible = false


## Construit l'anneau pour le choix partagé en cours ([param g].carousel) ; [param names] : nom de chaque stratège.
func open(g: Autochess, names: Array) -> void:
	_names = names
	for b in cards:
		remove_child(b)
		b.queue_free()
	cards.clear()
	var opts: Array = g.carousel.get("options", [])
	for k in opts.size():
		var b := _card(k, opts[k])
		add_child(b)
		cards.append(b)
	_layout()
	visible = true


## Met à jour les cartes : [param revealed] = nombre de stratèges de l'ordre dont le choix est montré ; [param my_turn] :
## le joueur peut choisir ; [param me] : son indice.
func refresh(g: Autochess, revealed: int, my_turn: bool, me: int) -> void:
	if g.carousel.is_empty():
		return
	var order: Array = g.carousel.order
	var shown := {}
	for k in mini(revealed, order.size()):
		shown[int(order[k])] = k
	var opts: Array = g.carousel.options
	for k in mini(opts.size(), cards.size()):
		var b: Button = cards[k]
		var by := int(opts[k].taken_by)
		var taken := by >= 0 and shown.has(by)
		var lbl: Label = b.find_child("Taken", true, false)
		lbl.text = ("Pris par toi" if by == me else "Pris par %s" % _name(by)) if taken else ""
		b.disabled = taken  # (pas à ton tour : la carte reste visable, l'écran ignore le choix)
		b.modulate = Color(1, 1, 1, 0.45) if taken else (Color(1, 1, 1, 1) if my_turn else Color(1, 1, 1, 0.85))
	# ordre en haut
	for c in _strip.get_children():
		_strip.remove_child(c)
		c.queue_free()
	for k in order.size():
		var pi := int(order[k])
		var p: Dictionary = g.players[pi]
		var cur := k == mini(revealed, order.size() - 1) and revealed < order.size()
		var pc := PanelContainer.new()
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var psb := AutochessHud.sticker(AutochessHud.candy("soleil", 0) if pi == me else AutochessHud.PAPER, 10.0, 3.0, 3.0 if cur else 2.0, 8.0, 2.0)
		if cur:
			psb.border_color = AutochessHud.candy("lagon", 2)
		pc.add_theme_stylebox_override("panel", psb)
		if k < revealed:
			pc.modulate = Color(1, 1, 1, 0.6)
		var l := AutochessHud.ink_lbl("%s  %d" % [_name(pi) if pi != me else "Toi", int(p.hp)], 14,
			AutochessHud.INK_300 if k < revealed else AutochessHud.INK, 800)
		pc.add_child(l)
		_strip.add_child(pc)
	_layout()


func _name(pi: int) -> String:
	return String(_names[pi]) if pi >= 0 and pi < _names.size() else "?"


func _card(k: int, o: Dictionary) -> Button:
	var id := String(o.id)
	var d := AutochessData.unit(id)
	var cost := int(d.get("cost", 1))
	var b := Button.new()
	b.name = "AcCarouselCard_%d" % k
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD
	b.size = CARD
	b.pressed.connect(func(): picked.emit(k))
	b.set_meta("ui_feel", "card")
	var n := AutochessHud.sticker(AutochessHud.PAPER, 14.0, 5.0, 3.0, 0.0, 0.0)
	var hv := AutochessHud.sticker(Color.WHITE, 14.0, 8.0, 3.0, 0.0, 0.0)
	var pr := AutochessHud.sticker(AutochessHud.PAPER_300, 14.0, 1.0, 3.0, 0.0, 0.0)
	var dis := AutochessHud.sticker(AutochessHud.GRAY, 14.0, 2.0, 3.0, 0.0, 0.0)
	for st in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", pr)
	var band := Panel.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_right = 1.0
	band.offset_left = 3.0
	band.offset_right = -3.0
	band.offset_top = 3.0
	band.offset_bottom = 12.0
	var bs := StyleBoxFlat.new()
	bs.bg_color = AutochessHud.cost_candy(cost)
	bs.corner_radius_top_left = 10
	bs.corner_radius_top_right = 10
	bs.border_color = AutochessHud.INK
	bs.border_width_bottom = 2
	band.add_theme_stylebox_override("panel", bs)
	b.add_child(band)
	b.tooltip_text = "%s\n%s" % [String(AutochessData.item(String(o.component)).get("name", "")),
		String(AutochessData.item(String(o.component)).get("tip", ""))]
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 8)
	m.add_theme_constant_override("margin_top", 16)
	m.add_theme_constant_override("margin_bottom", 6)
	b.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var tile := PanelContainer.new()
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel", AutochessHud.sticker(AutochessHud.cost_candy(cost, 0), 9.0, 0.0, 2.0, 1.0, 1.0))
	h.add_child(tile)
	var ic := TextureRect.new()
	ic.texture = UiTheme.texture(String(GameData.class_data(id).get("icon", "")))
	ic.custom_minimum_size = Vector2(36, 36)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(ic)
	var nm := AutochessHud.ink_lbl(AutochessData.unit_name(id), 15, AutochessHud.INK, 900)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.max_lines_visible = 2
	h.add_child(nm)
	var comp := HBoxContainer.new()
	comp.add_theme_constant_override("separation", 5)
	comp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cic := TextureRect.new()
	cic.texture = AutochessUnitCard.item_icon(String(o.component))
	cic.custom_minimum_size = Vector2(20, 20)
	cic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ct := PanelContainer.new()  # icône claire du composant : sur une tuile d'encre
	ct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ct.add_theme_stylebox_override("panel", AutochessHud.sticker(AutochessHud.INK_500, 6.0, 0.0, 2.0, 1.0, 1.0))
	ct.add_child(cic)
	comp.add_child(ct)
	var cl := AutochessHud.ink_lbl(String(AutochessData.item(String(o.component)).get("name", "")), 14, AutochessHud.candy("lagon", 2), 800)
	cl.clip_text = true
	cl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comp.add_child(cl)
	v.add_child(comp)
	var tk := AutochessHud.ink_lbl("", 14, AutochessHud.candy("fraise", 2), 900)
	tk.name = "Taken"
	tk.clip_text = true
	tk.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(tk)
	return b


## Cartes posées sur une ellipse autour du centre.
func _layout() -> void:
	var vs := get_viewport_rect().size
	var c := Vector2(vs.x * 0.5, vs.y * 0.5 + 24.0)
	var rx := minf(vs.x * 0.36, 470.0)
	var ry := minf(vs.y * 0.33, 250.0)
	var n := cards.size()
	for k in n:
		var a := -PI * 0.5 + TAU * float(k) / float(maxi(n, 1))
		var p := c + Vector2(cos(a) * rx, sin(a) * ry)
		(cards[k] as Control).position = p - CARD * 0.5
	var mid: Control = get_node("Middle")
	mid.size = mid.get_combined_minimum_size()
	mid.position = c - mid.size * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible:
		_layout()
