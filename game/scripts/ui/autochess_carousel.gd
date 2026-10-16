class_name AutochessCarousel
extends Control
## L'Échiquier (lot AC-G) : le choix partagé (manches x-4, SPEC §5.6, §7.1) : « Prends ton héros ». 9 cartes en anneau
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
	dim.color = Color(0.02, 0.02, 0.07, 0.72)
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
	mid.add_theme_stylebox_override("panel", AutochessHud.box(Color(AutochessHud.BG, 0.85), Color(UiTheme.GOLD_DIM, 0.7), 1, 14, 26, 10))
	add_child(mid)
	var mv := VBoxContainer.new()
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	mv.add_theme_constant_override("separation", 4)
	mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mv.custom_minimum_size.x = 260
	mid.add_child(mv)
	_title = AutochessHud.lbl("Prends ton héros", 28, UiTheme.GOLD, "title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(_title)
	info = AutochessHud.lbl("", 17, UiTheme.TEXT, "bold")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mv.add_child(info)
	timer_label = AutochessHud.lbl("", 26, UiTheme.GOLD, "title")
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
		var border := UiTheme.GOLD if cur else (Color(UiTheme.GOLD, 0.4) if pi == me else Color(0, 0, 0, 0))
		pc.add_theme_stylebox_override("panel", AutochessHud.box(Color(0.08, 0.09, 0.2, 0.9), border, 2 if border.a > 0.0 else 0, 6, 8, 3))
		var l := AutochessHud.lbl("%s  %d" % [_name(pi) if pi != me else "Toi", int(p.hp)], 14,
			UiTheme.MUTED if k < revealed else UiTheme.TEXT, "bold")
		pc.add_child(l)
		_strip.add_child(pc)
	_layout()


func _name(pi: int) -> String:
	return String(_names[pi]) if pi >= 0 and pi < _names.size() else "?"


func _card(k: int, o: Dictionary) -> Button:
	var id := String(o.id)
	var d := AutochessData.unit(id)
	var cost := int(d.get("cost", 1))
	var col := AutochessBoard.cost_color(cost)
	var b := Button.new()
	b.name = "AcCarouselCard_%d" % k
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD
	b.size = CARD
	b.pressed.connect(func(): picked.emit(k))
	var n := AutochessHud.box(Color(0.07, 0.08, 0.19, 0.97), col.darkened(0.1), 2, 10, 0, 0)
	n.border_width_top = 6
	var hv := n.duplicate() as StyleBoxFlat
	hv.border_color = UiTheme.GOLD
	hv.bg_color = Color(0.11, 0.12, 0.27, 0.98)
	for st in ["normal", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.tooltip_text = "%s\n%s" % [String(AutochessData.item(String(o.component)).get("name", "")),
		String(AutochessData.item(String(o.component)).get("tip", ""))]
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in ["left", "right"]:
		m.add_theme_constant_override("margin_" + s, 8)
	m.add_theme_constant_override("margin_top", 9)
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
	var ic := TextureRect.new()
	ic.texture = UiTheme.texture(String(GameData.class_data(id).get("icon", "")))
	ic.custom_minimum_size = Vector2(36, 36)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var nm := AutochessHud.lbl(AutochessData.unit_name(id), 15, UiTheme.TEXT, "bold")
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
	comp.add_child(cic)
	var cl := AutochessHud.lbl(String(AutochessData.item(String(o.component)).get("name", "")), 14, UiTheme.GOLD)
	cl.clip_text = true
	cl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comp.add_child(cl)
	v.add_child(comp)
	var tk := AutochessHud.lbl("", 14, UiTheme.MUTED)
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
