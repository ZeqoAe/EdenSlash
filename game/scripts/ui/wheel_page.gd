class_name WheelPage
extends HBoxContainer
## Roulette quotidienne (Coffres > Roulette) : la roue (Wheel) tourne, ralentit, et la case désignée
## s'illumine. Le résultat est décidé avant l'animation (Wheel.spin) ; la roue ne fait que le montrer.

var _wheel: WheelCanvas
var _info: Label
var _result: Label
var _spin_free: Button
var _spin_paid: Button
var _pity: Label
var _busy := false


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	var left := ItemWidgets.panel(self, 520)
	ItemWidgets.section(left, "Roulette du jour")
	_info = Hud._label(left, "", 17, Color(1.0, 0.9, 0.55))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spin_free = MenuWidgets.gold_button("Lancer la roue", 22, Vector2(0, 54))
	_spin_free.pressed.connect(_on_spin)
	left.add_child(_spin_free)
	_spin_paid = MenuWidgets.glass_button("Lancer en plus", 16, Vector2(0, 42))
	_spin_paid.pressed.connect(_on_spin)
	left.add_child(_spin_paid)
	_pity = Hud._label(left, "", 13, UiTheme.MUTED)
	_pity.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ItemWidgets.section(left, "Les gains (la largeur de la case = sa chance)")
	for kind in ["jackpot", "legend", "epic", "rare", "common", "lost"]:
		var pct := 0
		for s in Wheel.SLICES:
			if s[0] == kind:
				pct += int(s[1])
		var l := Hud._label(left, "■ %s : %d %%" % [Wheel.KINDS[kind].name, pct], 15, Wheel.KINDS[kind].color)
		l.tooltip_text = "Chance de tomber sur ce gain à chaque lancer."
	Hud._label(left, "Trois lancers par jour, offerts. Les gains sont des apparences (jamais de puissance). Deux lancers de plus par jour s'achètent en insignes. Après 6 « Perdu » d'affilée, tu gagnes au moins du commun ; après 25 lancers sans rare, un rare est garanti.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var right := ItemWidgets.panel(self, 0, true)
	_wheel = WheelCanvas.new()
	_wheel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_wheel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wheel.custom_minimum_size = Vector2(420, 420)
	right.add_child(_wheel)
	_result = Hud._label(right, "", 22, Color.WHITE)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func refresh() -> void:
	if not is_inside_tree():
		return
	var left := Wheel.free_left()
	var cost := Wheel.extra_cost()
	_info.text = "Lancers offerts restants aujourd'hui : %d / %d" % [left, Wheel.FREE_PER_DAY]
	_spin_free.visible = left > 0
	_spin_free.disabled = _busy
	_spin_paid.visible = left <= 0
	if cost > 0:
		_spin_paid.text = "Lancer en plus (%d insignes · tu as %d)" % [cost, Profile.insignia]
		_spin_paid.disabled = _busy or Profile.insignia < cost
	else:
		_spin_paid.text = "Plus de lancer aujourd'hui, reviens demain"
		_spin_paid.disabled = true
	var w := Wheel.state()
	_pity.text = "Série sans gain : %d / %d · lancers depuis le dernier rare : %d / %d" % [int(w.misses), Wheel.PITY_LOST, int(w.since_rare), Wheel.PITY_RARE]


func _on_spin() -> void:
	if _busy or not Wheel.can_spin():
		return
	var r := Wheel.spin()
	if not r.ok:
		_result.text = String(r.text)
		return
	_busy = true
	_spin_free.disabled = true
	_spin_paid.disabled = true
	_result.text = ""
	_wheel.spin_to(int(r.slice), func():
		_busy = false
		var col: Color = Wheel.KINDS[String(r.kind)].color
		_result.add_theme_color_override("font_color", col)
		_result.text = (String(Wheel.KINDS[String(r.kind)].name) + "\n" + String(r.text) + ("\n" + String(r.pity) if String(r.pity) != "" else ""))
		refresh())
	refresh()


## La roue dessinée : cases colorées, libellés, aiguille en haut, moyeu doré.
class WheelCanvas extends Control:
	var rot := 0.0  # rotation de la roue (radians, sens horaire)
	var win := -1  # case désignée (éclat)
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
				var pos := c + Vector2(cos(mid), sin(mid)) * rad * 0.68
				draw_set_transform(pos, mid + PI * 0.5 * 0.0 + (PI if cos(mid) < 0.0 else 0.0), Vector2.ONE)
				var fs := 17
				var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(font, Vector2(-w * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.05, 0.04, 0.1) if kind != "lost" else Color(0.85, 0.85, 0.9))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(c, rad, 0.0, TAU, 96, Color(0.95, 0.8, 0.35), 3.0, true)
		draw_circle(c, rad * 0.12, Color(0.95, 0.8, 0.35))
		draw_circle(c, rad * 0.08, Color(0.15, 0.1, 0.25))
		# aiguille en haut
		var tip := c + Vector2(0, -rad + 16.0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -34), tip + Vector2(14, -34)]), Color(1.0, 0.95, 0.7))
		draw_polyline(PackedVector2Array([tip, tip + Vector2(-14, -34), tip + Vector2(14, -34), tip]), Color(0.3, 0.2, 0.05), 2.0)
