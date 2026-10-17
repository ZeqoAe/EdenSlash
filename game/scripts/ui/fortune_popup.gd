class_name FortunePopup
extends CanvasLayer
## Fenêtre de l'autel de la fortune (Fortune) : la pyramide (sommet en haut, étage 1 en bas),
## l'échelle des gains à droite, et en bas où en est la série avec Encaisser / Monter.
## Le jeu est en pause ; fermer après une case gagnante encaisse le gain (rien ne se perd).

const CELL := 58.0
const WIN := Color(0.4, 1.0, 0.55)
const LOSE := Color(1.0, 0.3, 0.3)

var level := 1  # niveau du héros (or)
var plevel := 1  # niveau des coffres de récompense
var on_close: Callable
var _floor := 1  # étage à tenter
var _won := 0  # dernier étage gagné (gain en attente)
var _trap := 0  # case piégée de l'étage en cours
var _over := false
var _rows: Dictionary = {}  # étage -> [Button]
var _ladder: Array = []  # Label par étage (1 à 8)
var _status: RichTextLabel
var _bar: HBoxContainer


static func open(parent: Node, hero_level: int, chest_level: int, done: Callable) -> FortunePopup:
	Tutorial.event("fortune")
	var f := FortunePopup.new()
	f.level = hero_level
	f.plevel = chest_level
	f.on_close = done
	parent.get_tree().root.add_child(f)
	return f


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	var dim := ColorRect.new()
	UiTheme.veil(dim, 0.72)  # écran derrière flouté sous un voile d'encre (bible § 2, UIK2)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.04, 0.1, 0.97), UiTheme.GOLD, 2, 14))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1060, 700)
	panel.position = Vector2(-530, -350)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Label.new()
	UiTheme.title(t, 30)
	t.text = "Autel de la fortune"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var rules := Hud._label(v, "Une case piégée par étage. Case gagnante : encaisse le gain, ou monte tenter plus gros. La case piégée fait tout perdre. Passé l'étage 7, le sommet est à toi.", 15, UiTheme.MUTED)
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 30)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(h)
	# pyramide : sommet en haut
	var pyr := VBoxContainer.new()
	pyr.add_theme_constant_override("separation", 6)
	pyr.alignment = BoxContainer.ALIGNMENT_CENTER
	pyr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(pyr)
	for f in range(Fortune.FLOORS + 1, 0, -1):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		pyr.add_child(row)
		var n := 1 if f > Fortune.FLOORS else Fortune.cells(f)
		var btns: Array = []
		for i in n:
			var b := Button.new()
			b.custom_minimum_size = Vector2(CELL, CELL * 0.8)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 20)
			b.text = "★" if f > Fortune.FLOORS else "?"
			b.pressed.connect(_pick.bind(f, i))
			row.add_child(b)
			btns.append(b)
		_rows[f] = btns
	# échelle des gains
	var lad := VBoxContainer.new()
	lad.add_theme_constant_override("separation", 6)
	lad.custom_minimum_size = Vector2(420, 0)
	lad.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(lad)
	ItemWidgets.section(lad, "Gains")
	_ladder.resize(Fortune.FLOORS + 2)
	for f in range(Fortune.FLOORS + 1, 0, -1):
		var l := Hud._label(lad, "", 15, UiTheme.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ladder[f] = l
	_status = ItemWidgets.rich(v, 17)
	_status.fit_content = true
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bc := CenterContainer.new()
	v.add_child(bc)
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 16)
	bc.add_child(_bar)
	_start_floor(1)


func _start_floor(f: int) -> void:
	_floor = f
	_trap = randi() % Fortune.cells(f)
	_refresh()
	_set_status("Étage %d : choisis une case (%d piégée sur %d)." % [f, 1, Fortune.cells(f)])
	_buttons([["Partir sans rien" if _won == 0 else "Encaisser", _leave]])


func _pick(f: int, i: int) -> void:
	if _over or f != _floor:
		return
	var b: Button = _rows[f][i]
	if i == _trap:
		_over = true
		_won = 0
		_paint(b, LOSE, "✗")
		for j in (_rows[f] as Array).size():
			if j != i:
				(_rows[f][j] as Button).disabled = true
		Sfx.ui("rock")
		_shake(b)
		_set_status("[color=#ff6a6a][b]Case piégée ![/b][/color] La série s'arrête : le gain est perdu.")
		_refresh()
		_buttons([["Fermer", _close]])
		return
	_won = f
	_paint(b, WIN, "✓")
	_pop(b)
	Sfx.ui("confirm")
	for j in (_rows[f] as Array).size():
		if j != i:
			(_rows[f][j] as Button).disabled = true
	if f == Fortune.FLOORS:
		# étage 7 franchi : le sommet
		_won = Fortune.FLOORS + 1
		var top: Button = _rows[Fortune.FLOORS + 1][0]
		_paint(top, UiTheme.GOLD, "★")
		_pop(top)
		Sfx.ui("level_up", -4.0)
		_claim("[color=#ffd75a][b]SOMMET ATTEINT ![/b][/color] ")
		return
	_refresh()
	var nxt := f + 1
	_set_status("[color=#7dff9a][b]Gagné ![/b][/color] Encaisse [b]%s[/b], ou monte à l'étage %d (%d piégée sur %d) pour [b]%s[/b]." % [
		Fortune.prize_text(f, level), nxt, 1, Fortune.cells(nxt) if nxt <= Fortune.FLOORS else 1, Fortune.prize_text(nxt, level)])
	_buttons([["Encaisser", _leave], ["Monter à l'étage %d" % nxt, func(): _start_floor(nxt)]])


## Encaisse le gain en attente.
func _claim(prefix := "") -> void:
	_over = true
	var got := Fortune.give(_won, level, plevel)
	_set_status(prefix + "Obtenu : [b]%s[/b]." % got)
	_refresh()
	_buttons([["Fermer", _close]])


func _leave() -> void:
	if _won > 0 and not _over:
		_claim()
	else:
		_close()


func _close() -> void:
	if _won > 0 and not _over:
		Fortune.give(_won, level, plevel)  # fermé avec un gain en attente : encaissé
	get_tree().paused = false
	if on_close.is_valid():
		on_close.call()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _over:
			_close()
		else:
			_leave()


## Étages : celui en cours brille, les autres sont éteints ; échelle des gains.
func _refresh() -> void:
	for f in _rows:
		for b: Button in _rows[f]:
			var active := int(f) == _floor and not _over and _won < int(f)
			if b.text == "?" or (b.text == "★" and int(f) > Fortune.FLOORS and _won <= Fortune.FLOORS):
				b.disabled = not active
				b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.16, 0.12, 0.24) if active else Color(0.08, 0.07, 0.12),
					UiTheme.GOLD if active else Color(0.3, 0.26, 0.36), 2, 8))
				b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.3, 0.22, 0.42), UiTheme.GOLD, 3, 8))
				b.add_theme_stylebox_override("disabled", UiTheme.flat_box(Color(0.08, 0.07, 0.12, 0.7), Color(0.25, 0.22, 0.3, 0.6), 1, 8))
	for f in range(1, Fortune.FLOORS + 2):
		var l: Label = _ladder[f]
		var name := "Sommet" if f > Fortune.FLOORS else "Étage %d" % f
		l.text = "%s %s : %s" % ["✓" if f <= _won else ("▶" if f == _floor and not _over else "·"), name, Fortune.prize_text(f, level)]
		var col := UiTheme.TEXT
		if f <= _won:
			col = WIN
		elif f == _floor and not _over:
			col = UiTheme.GOLD
		elif f > Fortune.FLOORS:
			col = Color(1.0, 0.85, 0.4, 0.8)
		else:
			col = UiTheme.MUTED
		l.add_theme_color_override("font_color", col)


func _paint(b: Button, c: Color, txt: String) -> void:
	b.text = txt
	b.disabled = false
	var box := UiTheme.flat_box(Color(c.r * 0.3, c.g * 0.3, c.b * 0.3, 1.0), c, 3, 8)
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, box)
	b.add_theme_color_override("font_color", c)
	b.add_theme_color_override("font_disabled_color", c)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _pop(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2.ONE * 1.35
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _shake(c: Control) -> void:
	var x := c.position.x
	var tw := c.create_tween()
	for k in 6:
		tw.tween_property(c, "position:x", x + (6.0 if k % 2 == 0 else -6.0), 0.04)
	tw.tween_property(c, "position:x", x, 0.04)


func _set_status(t: String) -> void:
	_status.text = t


func _buttons(defs: Array) -> void:
	for c in _bar.get_children():
		c.queue_free()
	for i in defs.size():
		var d: Array = defs[i]
		var b := MenuWidgets.gold_button(String(d[0]), 18, Vector2(240, 46)) if i == defs.size() - 1 else MenuWidgets.glass_button(String(d[0]), 17, Vector2(220, 46))
		b.pressed.connect(d[1])
		_bar.add_child(b)
