class_name HudWidgets
extends RefCounted
## Éléments dessinés du HUD : emplacements de compétence avec recharge circulaire, potions, icônes d'effets (buffs /
## debuffs). Lot HUD-2 : cases autocollantes de la bible ; la vie, le niveau et le cadre de la mini-carte sont dans HudV2.


static func text_center(ci: CanvasItem, text: String, center: Vector2, font: Font, size: int, color: Color, outline := 4) -> void:
	if text == "":
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(center.x - w * 0.5, center.y + (font.get_ascent(size) - font.get_descent(size)) * 0.5)
	if outline > 0:
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0.03, 0.01, 0.05, 0.85 * color.a))  # le contour s'estompe avec le texte
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
		# points confondus (coins du carré) : un polygone dégénéré ne se triangule pas
		if pts[pts.size() - 1].distance_to(p) > 0.5:
			pts.append(p)
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, color)


# --- emplacement de compétence (lot HUD-2 : case autocollante, bible § 5 et § 10) ----------------------------------------
## Case de sort : fond d'encre 500, contour d'encre 3 px et ombre dure ; l'icône du jeu dedans (ses coins passent sous
## l'encre) ; vide = trame de points (jamais « — ») ; recharge en camembert + chiffre contouré ; éclat soleil quand elle
## redevient prête ; touche dessinée en pastille sous la case (papier, ou bonbon de la manette).
class SkillSlot extends Control:
	var icon: Texture2D
	var empty := true
	var key_text := ""
	var rank := 1
	var level_badge := 0  # Survivant : niveau du sort affiché en chiffre (0 : losanges de rang habituels)
	var auto := false
	var round := false  # emplacement rond (esquive)
	var chain_icons: Array = []  # sorts enchaînés de la case (icônes au-dessus)
	var chain_ready := false  # timing parfait ouvert : la case brille
	var chain_bar := -1.0  # barre du bon timing (0-1), -1 : cachée
	var chain_zone := Vector2(0.55, 0.9)
	var queued_main := false  # un appui gardé attend le coup affiché sur la case
	var queued_icons := 0  # appuis gardés pour les icônes d'enchaînement qui suivent
	## Survivant (lot SVX-2) : cases d'enchaînement toujours dessinées (vides : trame), la grille 4 × 3 se lit d'un coup.
	var chain_slots := 0
	## Touche en pastille autocollante (lot SVX-2 ; partout depuis HUD-2, gardé pour les tests).
	var key_sticker := true
	## Anneau intérieur d'une case ronde prête (esquive : pomme) ; « » : contour d'encre seul.
	var ready_tone := "pomme"
	var left := 0.0
	var fraction := 0.0
	var _flash := 0.0
	var _was_cd := false
	var _bg: StyleBoxFlat
	var _frame: StyleBoxFlat
	var _glint: StyleBoxFlat
	var _cell: StyleBoxFlat
	var _cell_frame: StyleBoxFlat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		_bg = HudWidgets.box(HudV2.WELL, 12, 0, Color.TRANSPARENT, 4.0)
		_frame = HudWidgets.box(Color.TRANSPARENT, 12, 3, HudV2.INK)
		_frame.draw_center = false
		_glint = HudWidgets.box(Color.TRANSPARENT, 14, 4, UiTheme.color("bonbon.soleil.clair"))
		_glint.draw_center = false
		_cell = HudWidgets.box(Color(HudV2.WELL, 0.95), 6, 0, Color.TRANSPARENT, 2.0)
		_cell_frame = HudWidgets.box(Color.TRANSPARENT, 6, 2, HudV2.INK)
		_cell_frame.draw_center = false

	func set_cooldown(l: float, total: float) -> void:
		if _was_cd and l <= 0.0:
			_flash = 1.0  # de nouveau prête : éclat soleil
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
		var ink := HudV2.INK
		if round:
			draw_circle(c + Vector2(0, 3), r - 1.0, HudV2.INK_900)  # ombre dure
			draw_circle(c, r - 1.0, HudV2.WELL)
		else:
			draw_style_box(_bg, rect)
		var inner := rect.grow(-3.0)
		var dim := Color(1, 1, 1, 1.0 if fraction <= 0.0 else 0.8)
		if icon and not empty:
			if round:
				var h := (r - 6.0) * 0.82
				draw_texture_rect(icon, Rect2(c - Vector2.ONE * h, Vector2.ONE * h * 2.0), false, dim)
			else:
				draw_texture_rect(icon, inner, false, dim)
		elif empty:
			# case vide : trame de points (bible § 10 : jamais « — » ; la touche reste dessous)
			var dot := Color(UiTheme.color("papier.100"), 0.2)
			var y := inner.position.y + 6.0
			var row := 0
			while y < inner.end.y - 3.0:
				var x := inner.position.x + (6.0 if row % 2 == 0 else 9.5)
				while x < inner.end.x - 3.0:
					draw_circle(Vector2(x, y), 1.3, dot)
					x += 7.0
				y += 7.0
				row += 1
		HudWidgets.sweep(self, inner if not round else rect.grow(-3.0), fraction, Color(HudV2.INK_900, 0.7), round)
		if left > 0.0:
			var t := "%.1f" % left if left < 10.0 else str(int(left))
			HudWidgets.text_center(self, t, c, UiTheme.number_font(), 21 if not round else 16, Color.WHITE, 6)
		if round:
			draw_arc(c, r - 2.0, 0.0, TAU, 64, ink, 3.0, true)
			if fraction <= 0.0 and ready_tone != "":
				draw_arc(c, r - 5.0, 0.0, TAU, 64, UiTheme.color("bonbon.%s.base" % ready_tone), 3.0, true)
		else:
			draw_style_box(_frame, rect)
		if _flash > 0.0:
			var sun := Color(UiTheme.color("bonbon.soleil.clair"), _flash)
			if round:
				draw_arc(c, r + 1.0 + 5.0 * (1.0 - _flash), 0.0, TAU, 64, sun, 4.0, true)
			else:
				draw_style_box(_glint, rect.grow(2.0 + 5.0 * (1.0 - _flash)))
				draw_rect(inner, Color(1, 0.97, 0.8, _flash * 0.3))
		if chain_bar >= 0.0:
			# barre du bon timing : zone soleil, remplissage lagon (pomme au bon moment), curseur blanc
			var br := Rect2(2.0, -15.0, size.x - 4.0, 10.0)
			draw_rect(br.grow(2.0), ink)
			draw_rect(br, HudV2.WELL)
			draw_rect(Rect2(br.position.x + br.size.x * chain_zone.x, br.position.y, br.size.x * (chain_zone.y - chain_zone.x), br.size.y), Color(UiTheme.color("bonbon.soleil.base"), 0.6))
			draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(chain_bar, 0.0, 1.0), br.size.y)), UiTheme.color("bonbon.lagon.base") if not chain_ready else UiTheme.color("bonbon.pomme.base"))
			var cx := br.position.x + br.size.x * clampf(chain_bar, 0.0, 1.0)
			draw_line(Vector2(cx, br.position.y - 2.0), Vector2(cx, br.end.y + 2.0), Color.WHITE, 2.0)
		var icons_y := -42.0 if chain_bar >= 0.0 else -24.0
		for i in range(chain_icons.size(), chain_slots):
			# Survivant : place d'enchaînement libre, tramée (jamais « — »)
			var er := Rect2(4.0 + i * 24.0, icons_y, 21.0, 21.0)
			draw_style_box(_cell, er.grow(1.0))
			for dy in [6.0, 13.0]:
				for dx in [6.0, 13.0]:
					draw_circle(er.position + Vector2(dx + (3.0 if dy > 10.0 else 0.0), dy), 1.2, Color(1, 1, 1, 0.22))
			draw_style_box(_cell_frame, er.grow(1.0))
		for i in chain_icons.size():
			var cr := Rect2(4.0 + i * 24.0, icons_y, 21.0, 21.0)
			draw_style_box(_cell, cr.grow(1.0))
			if chain_icons[i]:
				draw_texture_rect(chain_icons[i], cr, false)
			draw_style_box(_cell_frame, cr.grow(1.0))
			if chain_ready and i == 0:
				draw_rect(cr.grow(2.0), UiTheme.color("bonbon.lagon.clair"), false, 2.0)
			if i < queued_icons:
				# appui gardé : l'icône se remplit (cadre lagon plein, chevron)
				draw_rect(cr, Color(UiTheme.color("bonbon.lagon.base"), 0.5))
				draw_rect(cr.grow(1.0), UiTheme.color("bonbon.lagon.clair"), false, 2.0)
				HudWidgets.text_center(self, "›", cr.get_center(), UiTheme.bold_font(), 16, Color.WHITE, 3)
		if queued_main:
			draw_rect(rect.grow(2.0), UiTheme.color("bonbon.lagon.clair"), false, 3.0)
			HudWidgets.text_center(self, "›", Vector2(size.x - 9.0, size.y * 0.5), UiTheme.bold_font(), 22, Color.WHITE, 4)
		if chain_ready:
			var k := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.025)
			draw_rect(rect.grow(3.0), Color(UiTheme.color("bonbon.lagon.clair"), k), false, 4.0)
		if level_badge > 0 and not round:
			# Survivant : le niveau du sort (1 à 10) en chiffre, en haut à droite (soleil au niveau 10)
			var lt := str(level_badge)
			var lf := UiTheme.number_font()
			var lw := maxf(18.0, lf.get_string_size(lt, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.MIN_TEXT).x + 8.0)
			var lr := Rect2(size.x - lw - 2.0, 2.0, lw, 19.0)
			HudV2.round_rect(self, lr, UiTheme.color("bonbon.soleil.base") if level_badge >= 10 else UiTheme.color("bonbon.lagon.base"), 6, 2, ink)
			HudWidgets.text_center(self, lt, lr.get_center(), lf, UiTheme.MIN_TEXT, Color.WHITE, 4)
		elif rank > 1 and not round:
			for i in mini(rank - 1, 4):
				HudWidgets.diamond(self, Vector2(size.x - 10.0 - i * 9.0, 10.0), 5.0, ink)
				HudWidgets.diamond(self, Vector2(size.x - 10.0 - i * 9.0, 10.0), 3.2, UiTheme.color("bonbon.lagon.clair"))
		if auto:
			var tag := Rect2(4, 4, 40, 17)
			HudV2.round_rect(self, tag, UiTheme.color("bonbon.pomme.base"), 6, 2, ink)
			HudWidgets.text_center(self, "AUTO", tag.get_center(), UiTheme.number_font(), 12, Color.WHITE, 3)
		if key_text != "":
			HudV2.key_pill(self, Vector2(c.x, size.y + 1.0), key_text)


## Case de potion : une case de compétence avec le nombre de fioles restantes en pastille fraise dans le coin.
class PotionSlot extends SkillSlot:
	var count := 0
	var tint := Color.WHITE

	func _draw() -> void:
		super._draw()
		if empty:
			return
		var t := str(count)
		var f := UiTheme.number_font()
		var w := maxf(20.0, f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10.0)
		var r := Rect2(size.x - w + 6.0, -6.0, w, 20.0)
		HudV2.round_rect(self, r, UiTheme.color("bonbon.fraise.base") if count > 0 else UiTheme.color("encre.300"), 10, 2, HudV2.INK)
		HudWidgets.text_center(self, t, r.get_center(), f, 13, Color.WHITE, 4)


## Sorts d'autres cases gardés par la mémoire des touches : 2 pastilles avec l'icône et la touche,
## dans l'ordre où ils partiront.
class QueueStrip extends Control:
	var items: Array = []  # [{icon: Texture2D, key: String}]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(60, 26)

	func set_items(list: Array) -> void:
		if list.size() != items.size() or str(list) != str(items):
			items = list
			queue_redraw()

	func _draw() -> void:
		for i in mini(items.size(), 2):
			var r := Rect2(i * 30.0, 0.0, 26.0, 26.0)
			draw_rect(r.grow(2.0), HudV2.INK)
			if items[i].icon:
				draw_texture_rect(items[i].icon, r, false)
			draw_rect(r.grow(0.5), UiTheme.color("bonbon.lagon.clair"), false, 2.0)
			HudWidgets.text_center(self, String(items[i].key), Vector2(r.position.x + 20.0, r.end.y - 2.0), UiTheme.number_font(), 12, Color.WHITE, 4)


## Boîte arrondie du HUD (fond, rayon, contour d'encre, ombre dure en bas) ; gardée par l'appelant (rien créé par image).
static func box(fill: Color, radius: int, border := 0, ink := Color.TRANSPARENT, shadow := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if border > 0:
		sb.border_color = ink
		sb.set_border_width_all(border)
	if shadow > 0.0:
		sb.shadow_color = Color(HudV2.INK_900, 0.9)
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, shadow)
	return sb


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

	## Effet positif : bord pomme (lagon pour les daltoniens) ; négatif : bord fraise (mandarine) ; contour d'encre, ombre
	## dure (lot HUD-2, bible § 5). Boîtes gardées par teinte : rien n'est créé à chaque image.
	static var _boxes := {}

	static func _tone_box(tone: Color) -> Array:
		var key := tone.to_html()
		if not _boxes.has(key):
			var fill := HudWidgets.box(tone, 8, 0, Color.TRANSPARENT, 3.0)
			var frame := HudWidgets.box(Color.TRANSPARENT, 8, 2, HudV2.INK)
			frame.draw_center = false
			_boxes[key] = [fill, frame]
		return _boxes[key]

	func _draw() -> void:
		var rect := Rect2(1, 1, box, box)
		var cb := bool(Settings.get_v("interface", "colorblind"))
		var tone := UiTheme.color("bonbon.%s.base" % (("lagon" if cb else "pomme") if buff else ("mandarine" if cb else "fraise")))
		var boxes := _tone_box(tone)
		draw_style_box(boxes[0], rect.grow(1.0))
		var tex := StatusDb.icon(status)
		if tex:
			draw_texture_rect(tex, rect.grow(-2.5), false)
		else:
			draw_rect(rect.grow(-3.0), StatusDb.color(status))
			HudWidgets.text_center(self, StatusDb.display_name(status).substr(0, 2), rect.get_center(), UiTheme.bold_font(), int(box * 0.4), Color.WHITE)
		HudWidgets.sweep(self, rect.grow(-2.5), 1.0 - clampf(left / total, 0.0, 1.0), Color(HudV2.INK_900, 0.5))
		draw_style_box(boxes[1], rect.grow(1.0))
		if stacks > 1:
			HudWidgets.text_center(self, str(stacks), rect.end - Vector2(9, 10), UiTheme.number_font(), int(box * 0.5), UiTheme.color("bonbon.soleil.clair"), 5)
		if show_timer:
			var t := ("%d" % ceili(left) if left < 60.0 else "%dm" % int(left / 60.0)) + ("s" if left < 60.0 else "")
			HudWidgets.text_center(self, t, Vector2(rect.get_center().x, box + 9.0), UiTheme.number_font(), 12, UiTheme.color("bonbon.fraise.clair") if left < 3.0 else Color.WHITE, 4)


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
