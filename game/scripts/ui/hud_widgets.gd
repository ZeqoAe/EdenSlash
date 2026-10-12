class_name HudWidgets
extends RefCounted
## Éléments dessinés du HUD : orbes (vie, expérience), emplacements de compétence avec
## recharge circulaire, indicateur de combo, icônes d'effets (buffs / debuffs).


static func text_center(ci: CanvasItem, text: String, center: Vector2, font: Font, size: int, color: Color, outline := 4) -> void:
	if text == "":
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(center.x - w * 0.5, center.y + (font.get_ascent(size) - font.get_descent(size)) * 0.5)
	if outline > 0:
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0.03, 0.01, 0.05, 0.85))
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func diamond(ci: CanvasItem, c: Vector2, r: float, color: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)]), color)


## Secteur sombre de recharge : part [param fraction] de [param rect], dans le sens horaire
## à partir de midi, découpée au rectangle (ou au cercle si [param round]).
static func sweep(ci: CanvasItem, rect: Rect2, fraction: float, color: Color, round := false) -> void:
	if fraction <= 0.001:
		return
	var c := rect.get_center()
	var r := rect.size.length() * 0.5 if not round else minf(rect.size.x, rect.size.y) * 0.5
	var pts := PackedVector2Array([c])
	var start := -PI * 0.5 + (1.0 - fraction) * TAU
	var steps := maxi(3, int(48 * fraction))
	for i in steps + 1:
		var a := start + (TAU * fraction) * i / steps
		var p := c + Vector2(cos(a), sin(a)) * r
		if not round:
			p = p.clamp(rect.position, rect.end)
		pts.append(p)
	ci.draw_colored_polygon(pts, color)


# --- orbe (vie, expérience) -----------------------------------------------------------------
class Orb extends Control:
	var value := 1.0  # remplissage 0..1
	var trail := 1.0  # traîne claire des dégâts récents
	var top_color := Color(1.0, 0.32, 0.38)
	var bottom_color := Color(0.4, 0.02, 0.08)
	var caption := ""
	var big_text := ""
	var small_text := ""
	var big_font: Font
	var big_size := 28
	var pulse_low := false  # pulsation sous 30 %
	var flash := 0.0  # éclat (montée de niveau)
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_value(v: float) -> void:
		v = clampf(v, 0.0, 1.0)
		if v > value:
			trail = v
		value = v

	func _process(delta: float) -> void:
		_t += delta
		trail = move_toward(trail, value, delta * 0.4) if trail > value else value
		flash = maxf(0.0, flash - delta * 1.2)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 8.0
		draw_circle(c, r + 7.0, Color(0.04, 0.02, 0.07, 0.96))
		draw_circle(c, r, Color(0.02, 0.01, 0.04, 1.0))
		if trail > value + 0.002:
			_liquid(c, r, trail, Color(1, 0.95, 0.85, 0.4), Color(1, 0.9, 0.8, 0.25), false)
		var top := top_color
		if pulse_low and value < 0.3:
			top = top_color.lightened(0.35 * (0.5 + 0.5 * sin(_t * 7.0)))
		_liquid(c, r, value, top, bottom_color, true)
		draw_arc(c, r - 3.0, 0.0, TAU, 64, Color(0, 0, 0, 0.45), 6.0, true)
		var hl := PackedVector2Array()
		for i in 25:
			var a := PI + PI * i / 24.0
			hl.append(c + Vector2(cos(a) * r * 0.6, sin(a) * r * 0.36) + Vector2(-r * 0.06, -r * 0.3))
		draw_colored_polygon(hl, Color(1, 1, 1, 0.14))
		draw_arc(c, r + 1.5, 0.0, TAU, 96, UiTheme.GOLD, 3.0, true)
		draw_arc(c, r + 5.5, 0.0, TAU, 96, UiTheme.GOLD_DIM, 1.5, true)
		for k in 4:
			var a := TAU * k / 4.0 + PI * 0.25
			HudWidgets.diamond(self, c + Vector2(cos(a), sin(a)) * (r + 4.0), 5.0, UiTheme.GOLD)
		if flash > 0.0:
			draw_arc(c, r + 8.0 + (1.0 - flash) * 14.0, 0.0, TAU, 96, Color(UiTheme.GOLD, flash), 5.0, true)
			draw_circle(c, r, Color(1, 0.9, 0.6, flash * 0.35))
		var bold := UiTheme.bold_font()
		HudWidgets.text_center(self, caption, c + Vector2(0, -r * 0.45), bold, 13, Color(1, 1, 1, 0.8), 3)
		HudWidgets.text_center(self, big_text, c + Vector2(0, 2), big_font if big_font else bold, big_size, Color.WHITE, 6)
		HudWidgets.text_center(self, small_text, c + Vector2(0, r * 0.48), bold, 13, Color(1, 1, 1, 0.85), 3)

	func _liquid(c: Vector2, r: float, v: float, top: Color, bottom: Color, wave: bool) -> void:
		if v <= 0.002:
			return
		var level_y := c.y + r - 2.0 * r * minf(v, 0.999)
		var dy := level_y - c.y
		var w := sqrt(maxf(r * r - dy * dy, 0.0))
		var pts := PackedVector2Array()
		for i in 25:
			var x := c.x - w + 2.0 * w * i / 24.0
			var amp := 2.4 * (1.0 - absf(x - c.x) / maxf(w, 1.0)) if wave and v < 0.995 else 0.0
			pts.append(Vector2(x, level_y + sin(x * 0.11 + _t * 3.2) * amp))
		var th_r := asin(clampf(dy / r, -1.0, 1.0))
		var th_l := PI - th_r
		for i in range(1, 48):
			var th := th_r + (th_l - th_r) * i / 48.0
			pts.append(c + Vector2(cos(th), sin(th)) * r)
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bottom, clampf((p.y - (c.y - r)) / (2.0 * r), 0.0, 1.0)))
		draw_polygon(pts, cols)


# --- emplacement de compétence ----------------------------------------------------------------
class SkillSlot extends Control:
	var icon: Texture2D
	var empty := true
	var key_text := ""
	var rank := 1
	var auto := false
	var round := false  # emplacement rond (esquive)
	var left := 0.0
	var fraction := 0.0
	var _flash := 0.0
	var _was_cd := false
	var _bg: StyleBoxFlat
	var _badge: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		_bg = UiTheme.flat_box(Color(0.05, 0.04, 0.09, 0.96), Color(0, 0, 0, 0), 0, 9, false)
		_badge = UiTheme.flat_box(Color(0.08, 0.05, 0.12, 0.96), UiTheme.GOLD_DIM, 1, 5, false)

	func set_cooldown(l: float, total: float) -> void:
		if _was_cd and l <= 0.0:
			_flash = 1.0  # de nouveau prête : éclat
		_was_cd = l > 0.0
		left = l
		fraction = clampf(l / total, 0.0, 1.0) if total > 0.0 else 0.0

	func _process(delta: float) -> void:
		_flash = maxf(0.0, _flash - delta * 2.5)
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		if round:
			draw_circle(c, r - 1.0, Color(0.05, 0.04, 0.09, 0.96))
		else:
			draw_style_box(_bg, rect)
		var inner := rect.grow(-5.0)
		if icon and not empty:
			if round:
				draw_texture_rect(icon, Rect2(c - Vector2.ONE * (r - 7.0), Vector2.ONE * (r - 7.0) * 2.0), false)
			else:
				draw_texture_rect(icon, inner, false, Color(1, 1, 1, 1.0 if fraction <= 0.0 else 0.8))
		elif empty:
			HudWidgets.text_center(self, "—", c, UiTheme.bold_font(), 20, Color(1, 1, 1, 0.25), 0)
		HudWidgets.sweep(self, inner if not round else rect.grow(-3.0), fraction, Color(0.02, 0.0, 0.06, 0.72), round)
		if left > 0.0:
			var t := "%.1f" % left if left < 10.0 else str(int(left))
			HudWidgets.text_center(self, t, c, UiTheme.bold_font(), 20 if not round else 15, Color.WHITE, 5)
		if round:
			draw_arc(c, r - 1.5, 0.0, TAU, 64, UiTheme.GOLD if fraction <= 0.0 else UiTheme.GOLD_DIM, 2.5, true)
		else:
			var frame := UiTheme.texture(UiTheme.FRAME_SLOT)
			if frame:
				draw_texture_rect(frame, rect, false, Color(1, 1, 1, 1.0 if fraction <= 0.0 and not empty else 0.75))
		if _flash > 0.0:
			if round:
				draw_arc(c, r + 3.0 * (1.0 - _flash), 0.0, TAU, 64, Color(1, 0.95, 0.7, _flash), 4.0, true)
			else:
				draw_rect(rect.grow(2.0 * (1.0 - _flash)), Color(1, 0.95, 0.7, _flash), false, 3.0)
				draw_rect(inner, Color(1, 0.95, 0.75, _flash * 0.35))
		if rank > 1 and not round:
			for i in mini(rank - 1, 4):
				HudWidgets.diamond(self, Vector2(size.x - 10.0 - i * 9.0, 10.0), 3.5, Color(0.6, 0.85, 1.0))
		if auto:
			var tag := Rect2(4, 4, 34, 15)
			draw_style_box(UiTheme.flat_box(Color(0.1, 0.35, 0.15, 0.95), UiTheme.BUFF, 1, 4, false), tag)
			HudWidgets.text_center(self, "AUTO", tag.get_center(), UiTheme.bold_font(), 10, Color(0.85, 1.0, 0.85), 0)
		if key_text != "":
			var font := UiTheme.bold_font()
			var w := maxf(22.0, font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0)
			var badge := Rect2(c.x - w * 0.5, size.y - 10.0, w, 18.0)
			draw_style_box(_badge, badge)
			HudWidgets.text_center(self, key_text, badge.get_center(), font, 12, UiTheme.GOLD, 0)


# --- indicateur de combo ----------------------------------------------------------------------
class ComboMeter extends Control:
	var step := 0
	var total := 3
	var _alpha := 0.0
	var _burst := 0.0
	var _last := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(s: int, n: int) -> void:
		if s >= n and n > 0 and _last < n:
			_burst = 1.0  # coup final
		_last = s
		step = s
		total = n

	func _process(delta: float) -> void:
		_alpha = move_toward(_alpha, 1.0 if step > 0 else 0.0, delta * (6.0 if step > 0 else 2.0))
		_burst = maxf(0.0, _burst - delta * 2.0)
		if _alpha > 0.0 or _burst > 0.0:
			queue_redraw()

	func _draw() -> void:
		if _alpha <= 0.0 and _burst <= 0.0:
			return
		var c := size * 0.5
		var gap := 28.0
		var x0 := c.x - gap * (total - 1) * 0.5 + 34.0
		HudWidgets.text_center(self, "COMBO", Vector2(x0 - 52.0, c.y), UiTheme.title_font(), 15, Color(UiTheme.GOLD, _alpha), 4)
		for i in total:
			var p := Vector2(x0 + gap * i, c.y)
			var finisher := i == total - 1
			var r := 11.0 if finisher else 8.5
			var lit := i < step
			HudWidgets.diamond(self, p, r + 2.5, Color(0.05, 0.02, 0.08, 0.85 * _alpha))
			var col := (Color(1.0, 0.45, 0.2) if finisher else UiTheme.GOLD) if lit else Color(0.4, 0.33, 0.25, 0.8)
			HudWidgets.diamond(self, p, r, Color(col, col.a * _alpha))
			if lit:
				HudWidgets.diamond(self, p + Vector2(0, -r * 0.35), r * 0.35, Color(1, 1, 1, 0.5 * _alpha))
		if _burst > 0.0:
			var p := Vector2(x0 + gap * (total - 1), c.y)
			var rr := 12.0 + (1.0 - _burst) * 26.0
			var pts := PackedVector2Array([p + Vector2(0, -rr), p + Vector2(rr, 0), p + Vector2(0, rr), p + Vector2(-rr, 0), p + Vector2(0, -rr)])
			draw_polyline(pts, Color(1.0, 0.6, 0.25, _burst), 3.0, true)


# --- icône d'effet (buff / debuff) ---------------------------------------------------------
class StatusIcon extends Control:
	var status := ""
	var buff := true
	var left := 0.0
	var total := 1.0
	var stacks := 0
	var box := 36.0
	var show_timer := true
	var _t := 0.0

	func _init(size_px := 36.0, timer := true) -> void:
		box = size_px
		show_timer = timer
		custom_minimum_size = Vector2(box + 2.0, box + (16.0 if timer else 2.0))
		mouse_filter = Control.MOUSE_FILTER_PASS

	func update(l: float, tot: float, st: int) -> void:
		left = l
		total = maxf(tot, 0.1)
		stacks = st
		tooltip_text = StatusDb.tooltip(status, left, stacks)

	func _process(delta: float) -> void:
		_t += delta
		# clignote pendant les 3 dernières secondes
		modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * cos(_t * TAU * 2.2)) if left < 3.0 else 1.0
		queue_redraw()

	func _draw() -> void:
		var rect := Rect2(1, 1, box, box)
		var border := UiTheme.BUFF if buff else UiTheme.DEBUFF
		draw_style_box(UiTheme.flat_box(Color(0.03, 0.02, 0.06, 0.95), border, 2, 6, false), rect.grow(1.0))
		var tex := StatusDb.icon(status)
		if tex:
			draw_texture_rect(tex, rect.grow(-2.0), false)
		else:
			draw_rect(rect.grow(-3.0), StatusDb.color(status))
			HudWidgets.text_center(self, StatusDb.display_name(status).substr(0, 2), rect.get_center(), UiTheme.bold_font(), int(box * 0.4), Color.WHITE)
		HudWidgets.sweep(self, rect.grow(-2.0), 1.0 - clampf(left / total, 0.0, 1.0), Color(0, 0, 0, 0.5))
		if stacks > 1:
			HudWidgets.text_center(self, str(stacks), rect.end - Vector2(9, 10), UiTheme.bold_font(), int(box * 0.5), Color(1, 0.95, 0.6), 5)
		if show_timer:
			var t := ("%d" % ceili(left) if left < 60.0 else "%dm" % int(left / 60.0)) + ("s" if left < 60.0 else "")
			HudWidgets.text_center(self, t, Vector2(rect.get_center().x, box + 9.0), UiTheme.bold_font(), 12, Color(1, 0.4, 0.4) if left < 3.0 else Color(1, 1, 1, 0.9), 3)


## Rangée d'icônes d'effets, synchronisée à partir d'une liste [{id, left, total, stacks}].
class StatusRow extends HBoxContainer:
	var buff := true
	var icon_size := 36.0
	var timers := true
	var _icons := {}

	func _init(is_buff := true, px := 36.0, with_timers := true) -> void:
		buff = is_buff
		icon_size = px
		timers = with_timers
		add_theme_constant_override("separation", 5)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func sync(entries: Array) -> void:
		var seen := {}
		for e: Dictionary in entries:
			var id := String(e.id)
			seen[id] = true
			var ic: StatusIcon = _icons.get(id)
			if ic == null:
				ic = StatusIcon.new(icon_size, timers)
				ic.status = id
				ic.buff = buff
				_icons[id] = ic
				add_child(ic)
				ic.scale = Vector2.ONE * 1.4
				ic.pivot_offset = Vector2(icon_size, icon_size) * 0.5
				ic.create_tween().tween_property(ic, "scale", Vector2.ONE, 0.18)
			ic.update(float(e.left), float(e.total), int(e.get("stacks", 0)))
		for id in _icons.keys():
			if not seen.has(id):
				_icons[id].queue_free()
				_icons.erase(id)
