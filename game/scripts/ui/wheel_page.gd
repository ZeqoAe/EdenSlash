class_name WheelPage
extends HBoxContainer
## Roulette quotidienne (Coffres > Roulette) : la roue (Wheel) tourne, ralentit, et la case désignée
## s'illumine. Le résultat est décidé avant l'animation (Wheel.spin) ; la roue ne fait que le montrer.
## Chaque case porte l'apparence qu'elle donnera (Wheel.board) : on voit le gain à l'avance, dans la
## roue et dans la liste de gauche. Le gain s'affiche en grand 3 secondes.

const REVEAL_SECONDS := 3.0

var _wheel: WheelCanvas
var _info: Label
var _result: Label
var _spin_free: Button
var _spin_paid: Button
var _legend: VBoxContainer
var _reveal: PanelContainer
var _reveal_icon: TextureRect
var _reveal_kind: Label
var _reveal_name: Label
var _reveal_note: Label
var _reveal_tween: Tween
var _busy := false  # la roue tourne
var _showing := false  # lancer ou gain en cours : la roue et la liste gardent la planche d'avant le lancer


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	var left := ItemWidgets.panel(self, 520)
	ItemWidgets.section(left, "Roulette du jour")
	_info = Hud._label(left, "", 17, Color(1.0, 0.9, 0.55))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.mouse_filter = Control.MOUSE_FILTER_PASS
	_spin_free = MenuWidgets.gold_button("Lancer la roue", 22, Vector2(0, 54))
	_spin_free.pressed.connect(_on_spin)
	left.add_child(_spin_free)
	_spin_paid = MenuWidgets.glass_button("Lancer en plus", 16, Vector2(0, 42))
	_spin_paid.pressed.connect(_on_spin)
	left.add_child(_spin_paid)
	ItemWidgets.section(left, "Gains")
	var legend_scroll := ScrollContainer.new()  # 9 gains : la liste défile quand la fenêtre est basse
	legend_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	legend_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(legend_scroll)
	_legend = VBoxContainer.new()
	_legend.add_theme_constant_override("separation", 6)
	_legend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	legend_scroll.add_child(_legend)
	var right := ItemWidgets.panel(self, 0, true)
	_wheel = WheelCanvas.new()
	_wheel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wheel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wheel.custom_minimum_size = Vector2(420, 420)
	right.add_child(_wheel)
	_build_reveal()
	_result = Hud._label(right, "", 22, Color.WHITE)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Affiche en grand, au centre de la roue, l'apparence gagnée (un clic la ferme avant la fin).
func _build_reveal() -> void:
	_reveal = PanelContainer.new()
	_reveal.set_anchors_preset(Control.PRESET_CENTER)
	_reveal.custom_minimum_size = Vector2(300, 0)
	_reveal.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_reveal.grow_vertical = Control.GROW_DIRECTION_BOTH
	_reveal.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal.visible = false
	_reveal.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_end_reveal())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reveal.add_child(v)
	_reveal_kind = Hud._label(v, "", 16, Color.WHITE)
	_reveal_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_icon = TextureRect.new()
	_reveal_icon.custom_minimum_size = Vector2(160, 160)
	_reveal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_reveal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_reveal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_reveal_icon)
	_reveal_name = Hud._label(v, "", 22, Color.WHITE)
	_reveal_name.add_theme_font_override("font", UiTheme.bold_font())
	_reveal_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reveal_note = Hud._label(v, "", 15, UiTheme.MUTED)
	_reveal_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_wheel.add_child(_reveal)


func refresh() -> void:
	if not is_inside_tree():
		return
	var left := Wheel.free_left()
	var cost := Wheel.extra_cost()
	_info.text = "Lancers offerts : %d / %d" % [left, Wheel.FREE_PER_DAY]
	var w := Wheel.state()
	_info.tooltip_text = "Après %d « Perdu » d'affilée (tu en es à %d), tu gagnes au moins du commun.\nAprès %d lancers sans rare (tu en es à %d), un rare est garanti.\nLes gains sont des apparences, jamais de la puissance." % [
		Wheel.PITY_LOST, int(w.misses), Wheel.PITY_RARE, int(w.since_rare)]
	_spin_free.visible = left > 0
	_spin_free.disabled = _busy
	_spin_paid.visible = left <= 0
	if cost > 0:
		_spin_paid.text = "Lancer en plus · %d insignes" % cost
		_spin_paid.tooltip_text = "Tu as %d insignes. Deux lancers de plus par jour au plus." % Profile.insignia
		_spin_paid.disabled = _busy or Profile.insignia < cost
	else:
		_spin_paid.text = "Plus de lancer aujourd'hui"
		_spin_paid.tooltip_text = "Reviens demain."
		_spin_paid.disabled = true
	if not _showing:
		_show_board()


## La planche du jour sur la roue et dans la liste : une ligne par case qui donne une apparence, la plus rare d'abord.
func _show_board() -> void:
	var board := Wheel.board()
	_wheel.looks = board
	for c in _legend.get_children():
		c.queue_free()
	var order: Array = range(Wheel.SLICES.size()).filter(func(i): return String(Wheel.SLICES[i][0]) != "lost")
	order.sort_custom(func(a, b): return int(Wheel.KINDS[Wheel.SLICES[a][0]].rank) > int(Wheel.KINDS[Wheel.SLICES[b][0]].rank))
	for i in order:
		_legend.add_child(_legend_row(String(Wheel.SLICES[i][0]), board[i], int(Wheel.SLICES[i][1])))
	var lost := Wheel.SLICES.filter(func(s): return s[0] == "lost")
	var l := Hud._label(_legend, "Perdu · %d cases sur %d" % [lost.size(), Wheel.SLICES.size()], 14, UiTheme.MUTED)
	l.tooltip_text = "%d %% de chances." % lost.reduce(func(acc, s): return acc + int(s[1]), 0)


func _legend_row(kind: String, look: Dictionary, weight: int) -> Control:
	var col: Color = Wheel.KINDS[kind].color
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.05, 0.1, 0.85), col.darkened(0.2), 2, 10))
	p.tooltip_text = "%d %% de chances." % weight
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var ic := TextureRect.new()
	ic.texture = UiTheme.texture(String(look.get("icon", "")))
	ic.custom_minimum_size = Vector2(44, 44)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var name := String(look.get("name", "")) if not look.is_empty() else "%d insignes" % int(Wheel.CONSOLATION[kind])
	var n := Hud._label(v, name, 16, col.lightened(0.25))
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	Hud._label(v, String(Wheel.KINDS[kind].name), 12, UiTheme.MUTED)
	return p


## [param roll] : tirage imposé entre 0 et 1 (tests et captures) ; -1 : au hasard.
func _on_spin(roll := -1.0) -> void:
	if _busy or not Wheel.can_spin():
		return
	_end_reveal()  # la roue montre la planche du jour avant le lancer
	var r := Wheel.spin(roll)
	if not r.ok:
		_result.text = String(r.text)
		return
	_busy = true
	_showing = true  # la planche reste celle d'avant le lancer jusqu'à la fin de l'annonce du gain
	_spin_free.disabled = true
	_spin_paid.disabled = true
	_result.text = ""
	_wheel.spin_to(int(r.slice), func():
		_busy = false
		_show_reveal(r)
		refresh())
	refresh()


## Gain en grand pendant [constant REVEAL_SECONDS] puis la roue passe à la nouvelle planche.
func _show_reveal(r: Dictionary) -> void:
	var kind := String(r.kind)
	var col: Color = Wheel.KINDS[kind].color
	var look: Dictionary = r.look
	_reveal.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.96), col, 4, 16))
	_reveal_kind.text = String(Wheel.KINDS[kind].name)
	_reveal_kind.add_theme_color_override("font_color", col.lightened(0.2))
	_reveal_icon.texture = UiTheme.texture(String(look.get("icon", "")))
	_reveal_icon.visible = not look.is_empty()
	_reveal_name.text = String(look.name) if not look.is_empty() else String(r.text)
	_reveal_note.text = String(r.pity) if String(r.pity) != "" else ("Dans Héros > Apparence" if not look.is_empty() else "")
	_reveal.modulate.a = 0.0
	_reveal.visible = true
	Sfx.ui("confirm")
	if _reveal_tween != null:
		_reveal_tween.kill()
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(_reveal, "modulate:a", 1.0, 0.25)
	_reveal_tween.tween_interval(REVEAL_SECONDS)
	_reveal_tween.tween_property(_reveal, "modulate:a", 0.0, 0.5)
	_reveal_tween.tween_callback(_end_reveal)


func _end_reveal() -> void:
	if _reveal_tween != null:
		_reveal_tween.kill()
		_reveal_tween = null
	_reveal.visible = false
	_result.text = ""
	if _showing:
		_showing = false
		_wheel.win = -1
		refresh()


## La roue dessinée : cases colorées, libellés, apparence promise par chaque case, aiguille en haut, moyeu doré.
class WheelCanvas extends Control:
	var rot := 0.0  # rotation de la roue (radians, sens horaire)
	var win := -1  # case désignée (éclat)
	var looks: Array = []  # apparence promise par chaque case (Wheel.board)
	var _glow := 0.0

	func spin_to(slice: int, done: Callable) -> void:
		win = -1
		var sp := Wheel.span(slice)
		var target := lerpf(sp.x, sp.y, randf_range(0.15, 0.85))  # où l'aiguille s'arrête dans la case
		var end := rot + TAU * 5.0 + fposmod(-target - rot, TAU)  # 5 tours de plus, l'aiguille tombe dans la case
		var tw := create_tween()
		tw.tween_property(self, "rot", end, 4.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			win = slice
			var g := create_tween().set_loops(4)
			g.tween_property(self, "_glow", 1.0, 0.18)
			g.tween_property(self, "_glow", 0.0, 0.18)
			done.call())

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.46
		var font := get_theme_default_font()
		draw_circle(c, rad + 10.0, Color(0.55, 0.42, 0.12))
		draw_circle(c, rad + 5.0, Color(0.1, 0.07, 0.16))
		for i in Wheel.SLICES.size():
			var sp := Wheel.span(i)
			var kind := String(Wheel.SLICES[i][0])
			var col: Color = Wheel.KINDS[kind].color
			if i == win:
				col = col.lerp(Color.WHITE, 0.35 + 0.4 * _glow)
			elif win >= 0:
				col = col.darkened(0.35)
			var pts := PackedVector2Array([c])
			var n := maxi(3, int((sp.y - sp.x) / 0.06))
			for k in n + 1:
				var a := lerpf(sp.x, sp.y, float(k) / n) + rot - PI * 0.5
				pts.append(c + Vector2(cos(a), sin(a)) * rad)
			draw_colored_polygon(pts, col)
			draw_polyline(PackedVector2Array([c, pts[1]]), Color(0.05, 0.04, 0.1), 2.0)
			var mid := (sp.x + sp.y) * 0.5 + rot - PI * 0.5
			var label := "Perdu" if kind == "lost" else ("★" if kind == "jackpot" else String(Wheel.KINDS[kind].name).replace("Apparence ", "").capitalize())
			if font:
				var pos := c + Vector2(cos(mid), sin(mid)) * rad * 0.40
				draw_set_transform(pos, mid + (PI if cos(mid) < 0.0 else 0.0), Vector2.ONE)
				var fs := 17
				var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, Vector2(-w * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.04, 0.1) if kind != "lost" else Color(0.85, 0.85, 0.9))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			# l'apparence promise, droite, vers le bord de la case
			if i < looks.size() and not (looks[i] as Dictionary).is_empty():
				var tex := UiTheme.texture(String(looks[i].get("icon", "")))
				if tex != null:
					var ip := c + Vector2(cos(mid), sin(mid)) * rad * 0.78
					var r := clampf(rad * 0.105, 14.0, 30.0)
					var dim := 0.45 if (win >= 0 and i != win) else 1.0
					draw_circle(ip, r + 3.0, Color(0.05, 0.04, 0.1, 0.9 * dim))
					draw_arc(ip, r + 3.0, 0.0, TAU, 24, Color(1, 1, 1, 0.85 * dim), 2.0, true)
					draw_texture_rect(tex, Rect2(ip - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1, 1, 1, dim))
		draw_arc(c, rad, 0.0, TAU, 96, Color(0.95, 0.8, 0.35), 3.0, true)
		draw_circle(c, rad * 0.12, Color(0.95, 0.8, 0.35))
		draw_circle(c, rad * 0.08, Color(0.15, 0.1, 0.25))
		# aiguille en haut
		var tip := c + Vector2(0, -rad + 16.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -34), tip + Vector2(14, -34)]), Color(1.0, 0.95, 0.7))
		draw_polyline(PackedVector2Array([tip, tip + Vector2(-14, -34), tip + Vector2(14, -34), tip]), Color(0.3, 0.2, 0.05), 2.0)
