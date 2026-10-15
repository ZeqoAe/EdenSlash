class_name InfoCard
extends Control
## Petites cartes d'information (passe P8) : remplace les fenêtres natives « Nouveau dans cette version », les
## fiches de découverte et les avis. Une pile de cartes de 400 px de large ancrée dans un coin, sans fond plein
## écran, qui ne bloque que ses propres pixels ; même cadre or sur indigo que le reste du jeu.
##   - une carte = icône + titre court + corps de 2-3 lignes + boutons discrets + croix ;
##   - la première de la pile est celle du dessus : B / Échap (ou la croix) la ferme, A valide son bouton principal ;
##   - la manette voit les cartes (calque 118, au-dessus de tout) et le cadre doré revient où il était à la fermeture ;
##   - `InfoCard.ask(...)` : la vraie confirmation (destructive), petit dialogue centré et compact.
## Spécification d'une carte (Dictionary) : id, title, body (ou lines : Array), icon (nom d'icône ou chemin),
## kicker (petit mot à droite des boutons : « Nouveau »), buttons [{label, kind: "primary" | "plain" | "link", cb: Callable,
## keep: true pour ne pas fermer}] (« Compris » par défaut), duration (secondes, 0 = reste), hint (texte
## discret du bas), on_close (Callable(how)).

signal closed(id: String, how: String)

const W := 400.0
const BODY_W := 304.0
const SLIDE := 44.0
const IN_TIME := 0.28
const OUT_TIME := 0.2
const COLLAPSE_TIME := 0.16
const LAYER := 118
const MAX_LINES := 4
const CARD_H := 132.0  # hauteur d'une carte de deux lignes de texte

## B / Échap ferment la carte du dessus (vrai au lobby ; en jeu Échap est la pause : fermer à la croix ou au bouton).
var cancel_closes := true
## Une carte qui apparaît prend le cadre doré de la manette (vrai au lobby, faux en jeu).
var pad_focus := true

var _box: VBoxContainer
var _entries: Array = []
var _seq := 0
var _prev: Control


# --- création ----------------------------------------------------------------------------
## Pile dans son propre calque, au-dessus de tout (lobby, menus). Placée sous la carte du héros, à droite.
static func in_layer(host: Node, top := 128.0, margin := 28.0) -> InfoCard:
	var l := CanvasLayer.new()
	l.layer = LAYER
	l.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(l)
	var s := InfoCard.new()
	l.add_child(s)
	s.place(top, margin)
	return s


## Pile dans un contrôle existant (le HUD : sous le compteur de dégâts, au milieu à droite).
static func in_control(parent: Control, top := -70.0, margin := 14.0, middle := true) -> InfoCard:
	var s := InfoCard.new()
	s.cancel_closes = false
	s.pad_focus = false
	parent.add_child(s)
	s.place(top, margin, middle)
	return s


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)
	set_process(false)


## Place la pile à droite : [param top] px du haut (ou du milieu de l'écran), [param margin] px du bord.
func place(top: float, margin: float, middle := false) -> void:
	var a := 0.5 if middle else 0.0
	_box.anchor_left = 1.0
	_box.anchor_right = 1.0
	_box.anchor_top = a
	_box.anchor_bottom = a
	_box.offset_left = -(W + margin)
	_box.offset_right = -margin
	_box.offset_top = top
	_box.offset_bottom = top
	_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_box.grow_vertical = Control.GROW_DIRECTION_END


## Combien de cartes tiennent dans la fenêtre sans toucher le pied de l'écran (ressources, version).
func capacity(top := 128.0, reserve := 100.0) -> int:
	return maxi(1, int((get_viewport_rect().size.y - top - reserve) / (CARD_H + 8.0)))


# --- cartes ------------------------------------------------------------------------------
## Ajoute une carte en bas de la pile ; renvoie son panneau (null si une carte de même id est déjà là).
func add_card(spec: Dictionary) -> Control:
	var id := String(spec.get("id", ""))
	if id == "":
		id = "carte_%d" % _seq
	_seq += 1
	for e in _entries:
		if String(e.id) == id and not e.closing:
			return null
	var was_empty := _live().is_empty()
	if was_empty and pad_focus and is_instance_valid(UiNav.cursor):
		_prev = UiNav.cursor
	var e := _build(id, spec)
	_entries.append(e)
	_box.add_child(e.slot)
	_settle(e)
	if float(e.until) >= 0.0:
		set_process(true)
	if was_empty:
		_focus_top()
	return e.panel


## Cartes qui ne sont pas en train de se fermer, de la plus haute à la plus basse.
func _live() -> Array:
	return _entries.filter(func(e): return not e.closing)


func count() -> int:
	return _live().size()


## Identifiants des cartes affichées, de haut en bas.
func ids() -> Array:
	return _live().map(func(e): return String(e.id))


## Les boutons de la carte [param id] (ou de celle du dessus si vide), dans l'ordre.
func buttons(id := "") -> Array:
	for e in _live():
		if id == "" or String(e.id) == id:
			return e.buttons
	return []


## Bouton principal de la carte du dessus (celui que A valide), null s'il n'y a pas de carte.
func primary_button() -> Button:
	var l := _live()
	return null if l.is_empty() else (l[0].primary as Button)


## Ferme la carte du dessus (B, Échap). Renvoie faux s'il n'y en avait pas.
func dismiss_top(how := "cancel") -> bool:
	var l := _live()
	if l.is_empty():
		return false
	dismiss(String(l[0].id), how)
	return true


## Déclenche le [param n]-ième bouton de la carte du dessus (la manette en jeu : 0 = Compris, 1 = Guide).
func press_top(n: int) -> bool:
	var l := _live()
	if l.is_empty() or n < 0 or n >= (l[0].buttons as Array).size():
		return false
	((l[0].buttons as Array)[n] as Button).pressed.emit()
	return true


func dismiss_all(how := "auto") -> void:
	for e in _live():
		dismiss(String(e.id), how)


func dismiss(id: String, how := "x") -> void:
	var e := _find(id)
	if e.is_empty() or e.closing:
		return
	e.closing = true
	e.panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in e.buttons:
		(b as Button).disabled = true
		(b as Button).mouse_filter = Control.MOUSE_FILTER_IGNORE
	(e.close as Button).disabled = true
	_refocus()
	if (e.on_close as Callable).is_valid():
		(e.on_close as Callable).call(how)
	closed.emit(String(e.id), how)
	if not is_inside_tree():
		_drop(e)
		return
	var slot: Control = e.slot
	var p: Control = e.panel
	var tw := slot.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.set_parallel(true)
	tw.tween_property(slot, "modulate:a", 0.0, OUT_TIME)
	tw.tween_property(p, "offset_left", SLIDE, OUT_TIME)
	tw.tween_property(p, "offset_right", SLIDE, OUT_TIME)
	tw.chain().tween_property(slot, "custom_minimum_size:y", 0.0, COLLAPSE_TIME)
	tw.finished.connect(func(): _drop(e))


func _drop(e: Dictionary) -> void:
	_entries.erase(e)
	if is_instance_valid(e.slot):
		(e.slot as Control).queue_free()


func _find(id: String) -> Dictionary:
	for e in _entries:
		if String(e.id) == id:
			return e
	return {}


# --- manette -----------------------------------------------------------------------------
## Le cadre doré va sur le bouton principal de la carte du dessus.
func _focus_top() -> void:
	if not pad_focus:
		return
	var b := primary_button()
	if b != null:
		UiNav.focus(b)


## Après une fermeture : le cadre passe à la carte suivante, ou revient où il était (jamais perdu).
func _refocus() -> void:
	if not pad_focus:
		return
	var l := _live()
	if not l.is_empty():
		UiNav.focus(l[0].primary as Button)
		return
	if is_instance_valid(_prev) and _prev.is_visible_in_tree():
		UiNav.focus(_prev)
	elif Gamepad.active:
		UiNav.cursor = null
		UiNav.pick_default()
	_prev = null


func _input(event: InputEvent) -> void:
	if not cancel_closes or _live().is_empty() or not is_visible_in_tree():
		return
	var back: bool = event.is_action_pressed("ui_cancel") \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if back:
		get_viewport().set_input_as_handled()
		dismiss_top("cancel")


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return  # cachée (choix de carte en jeu) : le compte à rebours attend
	var timed := false
	for e in _live():
		if float(e.until) < 0.0:
			continue
		timed = true
		# la souris posée sur la carte met le compte à rebours en attente
		var over: bool = (e.panel as Control).get_global_rect().has_point(get_global_mouse_position())
		if not over:
			e.until = float(e.until) - delta
		if float(e.until) <= 0.0:
			dismiss(String(e.id), "auto")
	if not timed:
		set_process(false)


# --- construction ------------------------------------------------------------------------
func _build(id: String, spec: Dictionary) -> Dictionary:
	var slot := Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.custom_minimum_size = Vector2(W, 96)
	slot.modulate.a = 0.0
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(16, 12))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(_icon_frame(String(spec.get("icon", "info"))))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	var t := Label.new()
	t.text = String(spec.get("title", ""))
	UiTheme.title(t, 18)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size = Vector2(BODY_W - 34.0, 0)
	head.add_child(t)
	var x := Button.new()
	x.text = "×"
	x.focus_mode = Control.FOCUS_NONE
	x.tooltip_text = "Fermer"
	x.custom_minimum_size = Vector2(30, 28)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	x.add_theme_font_size_override("font_size", 22)
	x.add_theme_color_override("font_color", UiTheme.MUTED)
	x.add_theme_color_override("font_hover_color", UiTheme.GOLD)
	for st in ["normal", "pressed", "focus", "disabled"]:
		x.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	x.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 0, 6, false))
	x.pressed.connect(func(): dismiss(id, "x"))
	head.add_child(x)
	var body := Label.new()
	var txt := String(spec.get("body", ""))
	if txt == "" and spec.has("lines"):
		txt = " ".join(PackedStringArray(spec.lines))
	body.text = txt
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = MAX_LINES
	body.custom_minimum_size = Vector2(BODY_W, 0)
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", UiTheme.TEXT)
	col.add_child(body)
	var specs: Array = spec.get("buttons", [])
	if specs.is_empty():
		specs = [{"label": "Compris", "kind": "primary"}]
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	var btns: Array = []
	var primary: Button = null
	for bs in specs:
		var kind := String(bs.get("kind", "primary" if btns.is_empty() else "plain"))
		var b := _small_button(String(bs.get("label", "")), kind)
		var cb: Callable = bs.get("cb", Callable())
		var keep: bool = bs.get("keep", false)
		b.pressed.connect(func():
			if cb.is_valid():
				cb.call()
			if not keep:
				dismiss(id, "button"))
		btn_row.add_child(b)
		btns.append(b)
		if primary == null:
			primary = b
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	if String(spec.get("kicker", "")) != "":
		var fill := Control.new()
		fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_row.add_child(fill)
		var k := Label.new()
		k.text = String(spec.kicker).to_upper()
		k.add_theme_font_override("font", UiTheme.bold_font())
		k.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
		k.add_theme_color_override("font_color", UiTheme.GOLD_DIM)
		btn_row.add_child(k)
	col.add_child(btn_row)
	if String(spec.get("hint", "")) != "":
		var hl := Label.new()
		hl.text = String(spec.hint)
		hl.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
		hl.add_theme_color_override("font_color", UiTheme.MUTED)
		col.add_child(hl)
	var dur := float(spec.get("duration", 0.0))
	return {"id": id, "slot": slot, "panel": panel, "buttons": btns, "primary": primary, "close": x,
			"until": dur if dur > 0.0 else -1.0, "closing": false, "on_close": spec.get("on_close", Callable())}


## Mesure la carte une fois disposée, règle la hauteur de son emplacement, puis la fait entrer.
func _settle(e: Dictionary) -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(e.slot) or e.closing:
		return
	var slot: Control = e.slot
	var p: Control = e.panel
	slot.custom_minimum_size = Vector2(W, p.get_combined_minimum_size().y)
	p.offset_left = SLIDE
	p.offset_right = SLIDE
	var tw := slot.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_parallel(true)
	tw.tween_property(slot, "modulate:a", 1.0, IN_TIME)
	tw.tween_property(p, "offset_left", 0.0, IN_TIME)
	tw.tween_property(p, "offset_right", 0.0, IN_TIME)


static func _icon_frame(icon: String) -> Control:
	var f := PanelContainer.new()
	f.custom_minimum_size = Vector2(44, 44)
	f.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	f.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.14, 0.11, 0.24, 0.96), UiTheme.GOLD_DIM, 2, 10, false))
	var tex: Texture2D = null
	if icon.begins_with("res://"):
		tex = UiTheme.texture(icon)
	elif icon != "":
		tex = MenuWidgets.icon(icon)
	if tex == null:
		tex = MenuWidgets.icon("info")
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(28, 28)
	tr.modulate = Color(1.0, 0.9, 0.62)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.add_child(tr)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


## Bouton discret : « primary » (doré), « plain » (verre), « link » (texte seul).
static func _small_button(text: String, kind: String, height := 30.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_override("font", UiTheme.bold_font())
	b.add_theme_font_size_override("font_size", 15)
	var n: StyleBoxFlat
	var hv: StyleBoxFlat
	match kind:
		"primary":
			n = UiTheme.flat_box(Color(0.42, 0.27, 0.07, 0.96), UiTheme.GOLD, 2, 8, false)
			hv = UiTheme.flat_box(Color(0.58, 0.38, 0.1, 1.0), Color(1, 0.92, 0.62), 2, 8, false)
			b.add_theme_color_override("font_color", Color(1, 0.96, 0.86))
		"danger":
			n = UiTheme.flat_box(Color(0.38, 0.1, 0.12, 0.95), Color(1.0, 0.5, 0.45), 2, 8, false)
			hv = UiTheme.flat_box(Color(0.55, 0.14, 0.16, 1.0), Color(1.0, 0.7, 0.6), 2, 8, false)
			b.add_theme_color_override("font_color", Color(1, 0.94, 0.9))
		"link":
			n = UiTheme.flat_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 8, false)
			hv = UiTheme.flat_box(Color(1, 1, 1, 0.07), Color(0, 0, 0, 0), 0, 8, false)
			b.add_theme_color_override("font_color", UiTheme.MUTED)
		_:
			n = UiTheme.flat_box(Color(MenuWidgets.GLASS, 0.82), MenuWidgets.LINE, 1, 8, false)
			hv = UiTheme.flat_box(Color(0.13, 0.12, 0.26, 0.95), UiTheme.GOLD_DIM, 2, 8, false)
			b.add_theme_color_override("font_color", UiTheme.TEXT)
	for s in [n, hv]:
		(s as StyleBoxFlat).content_margin_left = 12
		(s as StyleBoxFlat).content_margin_right = 12
		(s as StyleBoxFlat).content_margin_top = 3
		(s as StyleBoxFlat).content_margin_bottom = 3
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hv)
	b.add_theme_stylebox_override("pressed", hv)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_color_override("font_hover_color", UiTheme.GOLD if kind in ["link", "plain"] else Color(1, 1, 0.95))
	b.pressed.connect(func(): Sfx.ui("click", -8.0))
	return b


# --- confirmation ------------------------------------------------------------------------
## Vraie confirmation (geste destructif) : petit dialogue centré, compact. B / Échap = annuler, le cadre de la
## manette part sur « Annuler » (le choix prudent). [param on_ok] est appelé après la fermeture.
static func ask(host: Node, title: String, text: String, ok_text: String, on_ok: Callable, danger := true,
		cancel_text := "Annuler", on_cancel := Callable()) -> Ask:
	var a := Ask.new(title, text, ok_text, cancel_text, danger, on_ok, on_cancel)
	host.add_child(a)
	return a


class Ask extends CanvasLayer:
	signal answered(ok: bool)
	var cancel_button: Button
	var ok_button: Button
	var title_label: Label
	var _root: Control
	var _prev: Control
	var _on_ok: Callable
	var _on_cancel: Callable
	var _done := false

	func _init(title: String, text: String, ok_text: String, cancel_text: String, danger: bool, on_ok: Callable, on_cancel: Callable) -> void:
		layer = InfoCard.LAYER + 1
		process_mode = Node.PROCESS_MODE_ALWAYS
		_on_ok = on_ok
		_on_cancel = on_cancel
		_root = Control.new()
		_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_root.modulate.a = 0.0
		add_child(_root)
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.01, 0.05, 0.55)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				_finish(false))
		_root.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(center)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiTheme.panel_box(26, 20))
		panel.custom_minimum_size = Vector2(440, 0)
		center.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		panel.add_child(v)
		var t := Label.new()
		t.text = title
		UiTheme.title(t, 22)
		title_label = t
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		var b := Label.new()
		b.text = text
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(388, 0)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_color_override("font_color", UiTheme.TEXT)
		v.add_child(b)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)
		cancel_button = InfoCard._small_button(cancel_text, "plain", 38.0)
		cancel_button.custom_minimum_size.x = 150
		cancel_button.pressed.connect(func(): _finish(false))
		row.add_child(cancel_button)
		ok_button = InfoCard._small_button(ok_text, "danger" if danger else "primary", 38.0)
		ok_button.custom_minimum_size.x = 170
		ok_button.pressed.connect(func(): _finish(true))
		row.add_child(ok_button)

	func _ready() -> void:
		if is_instance_valid(UiNav.cursor):
			_prev = UiNav.cursor
		UiNav.focus(cancel_button)
		create_tween().tween_property(_root, "modulate:a", 1.0, 0.16)

	func _finish(ok: bool) -> void:
		if _done:
			return
		_done = true
		if is_instance_valid(_prev) and _prev.is_visible_in_tree():
			UiNav.focus(_prev)
		elif Gamepad.active:
			UiNav.cursor = null
			UiNav.pick_default()
		answered.emit(ok)
		var cb := _on_ok if ok else _on_cancel
		var tw := create_tween()
		tw.tween_property(_root, "modulate:a", 0.0, 0.12)
		tw.finished.connect(queue_free)
		_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for c in _root.get_children():
			if c is Control:
				(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if cb.is_valid():
			cb.call()

	func _input(event: InputEvent) -> void:
		if _done:
			return
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") \
				or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
			get_viewport().set_input_as_handled()
			_finish(false)
