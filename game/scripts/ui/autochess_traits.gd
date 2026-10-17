class_name AutochessTraitPanel
extends PanelContainer
## L'Échiquier (lot AC-G, v2 du lot ACX-1) : colonne des traits (synergies) du plateau, à gauche, TOUJOURS visible en
## préparation (la fiche d'unité est une bulle à part). Autocollant papier ; une ligne par trait présent : pastille
## hexagonale (couleur de la famille, lagon clair pour les armes ; compte dedans), nom, puis un plot par seuil (soleil =
## atteint). Les traits actifs d'abord, sur papier ; les inactifs en dessous, en grisé.
## Survol (souris) ou cadre de la manette sur une ligne : signal trait_hovered (l'écran illumine les unités du trait sur le
## plateau, le banc et la boutique) ; infobulle : effet court + chiffres ; clic / A : detail_requested (petite carte).
## Aperçu « ce trait monte » (preview) : survol d'une carte de la boutique → « 2 → 3 » en pomme sur les traits qu'elle
## ferait monter, lignes fantômes pour les traits nouveaux. SPEC §5.4, §7.1 ; étude BM-AUTO §7.1.

signal detail_requested(trait_id: String)
signal trait_hovered(trait_id: String)  ## "" quand la souris quitte la ligne

const W := AutochessHud.SIDE_W
const ROW_H := 34.0  # hauteur d'une ligne (pastille de 28 px + marges)
const TIER_COLORS := [Color(0.42, 0.42, 0.5), Color(0.80, 0.52, 0.30), Color(0.78, 0.84, 0.95), Color(0.98, 0.78, 0.35)]

var rows := {}  # trait -> ligne (tests, navigation)
var hovered := ""  # trait sous la souris ("" : aucun)
var marked := ""  # trait dont les unités sont illuminées (cadre posé sur la ligne)
var _list: VBoxContainer
var _empty: Label
var _sig := ""
var _preview: Array = []  # traits qui monteraient (survol d'une carte de la boutique)
var _counts := {}
var _order: Array = []
var _ghosts: VBoxContainer
var _ghost_sig := ""


func _init() -> void:
	name = "AcTraits"
	custom_minimum_size = Vector2(AutochessHud.s(W), 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", AutochessHud.paper_panel(7.0, 10.0, 10.0))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", roundi(AutochessHud.s(3.0)))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	v.add_child(AutochessHud.panel_title("Traits", 22))
	_empty = AutochessHud.ink_lbl("Place des héros pour éveiller leurs traits.", 14, AutochessHud.INK_300, 700)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size.x = AutochessHud.s(W) - 24.0
	v.add_child(_empty)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", roundi(AutochessHud.s(2.0)))
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_list)
	_ghosts = VBoxContainer.new()
	_ghosts.add_theme_constant_override("separation", roundi(AutochessHud.s(2.0)))
	_ghosts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_ghosts)


## Compte de chaque trait du plateau (Autochess.trait_counts) ; reconstruit seulement si quelque chose a changé (l'aperçu
## et la ligne mise en avant se posent sur les lignes existantes : le cadre de la manette n'est jamais perdu).
func refresh(counts: Dictionary) -> void:
	_counts = counts
	var order: Array = counts.keys().filter(func(t): return int(counts[t]) > 0 and AutochessData.TRAITS.has(t))
	order.sort_custom(func(a, b):
		var ta := AutochessData.trait_tier(a, int(counts[a]))
		var tb := AutochessData.trait_tier(b, int(counts[b]))
		if ta != tb:
			return ta > tb
		if int(counts[a]) != int(counts[b]):
			return int(counts[a]) > int(counts[b])
		return String(a) < String(b))
	var sig := str(order) + str(counts)
	if sig != _sig:
		_sig = sig
		_order = order
		for c in _list.get_children():
			_list.remove_child(c)
			c.queue_free()
		rows.clear()
		var shown := 0
		var max_rows := max_rows()
		var split := false
		for t in order:
			if shown >= max_rows - (1 if order.size() > max_rows else 0):
				var more := AutochessHud.ink_lbl("+%d autres" % (order.size() - shown), 14, AutochessHud.INK_300, 800)
				_list.add_child(more)
				break
			var n := int(counts[t])
			if not split and AutochessData.trait_tier(String(t), n) == 0 and shown > 0:
				split = true
				_list.add_child(_divider())
			var row := _row(String(t), n)
			_list.add_child(row)
			rows[t] = row
			shown += 1
		_ghost_sig = "?"
	_apply_marked()
	_apply_preview()


## Traits que ferait monter une unité (survol d'une carte de la boutique) ; [] : aucun aperçu.
func preview(traits: Array) -> void:
	if traits == _preview:
		return
	_preview = traits.duplicate()
	_apply_preview()


## Ligne mise en avant (ses unités sont illuminées) : fond lagon clair, anneau lagon.
func set_marked(t: String) -> void:
	if t == marked:
		return
	marked = t
	_apply_marked()


func _apply_marked() -> void:
	for t in rows:
		var row: PanelContainer = rows[t]
		var on := String(t) == marked
		var tier := int(row.get_meta("tier", 0))
		var sb := AutochessHud.sticker(AutochessHud.candy("lagon", 0) if on else (AutochessHud.PAPER_200 if tier > 0 else Color(0, 0, 0, 0)),
			10.0, 0.0, 3.0 if on else 0.0, 4.0, 1.0)
		if on:
			sb.border_color = AutochessHud.candy("lagon", 2)
		row.add_theme_stylebox_override("panel", sb)


## « 2 → 3 » en pomme sur les traits qui monteraient ; lignes fantômes (sous la liste) pour les traits nouveaux.
func _apply_preview() -> void:
	for t in rows:
		var row: Control = rows[t]
		var up: Label = row.find_child("Rising", true, false)
		var plots: Control = row.find_child("Plots", true, false)
		var on := _preview.has(t)
		up.visible = on
		plots.visible = not on
		if on:
			var n := int(row.get_meta("count", 0))
			up.text = "%d → %d" % [n, n + 1]
			var wakes := AutochessData.trait_thresholds(String(t)).has(n + 1)
			up.add_theme_color_override("font_color", AutochessHud.candy("pomme", 2) if wakes else AutochessHud.GAIN)
	var ghosts: Array = _preview.filter(func(t): return not rows.has(t) and AutochessData.TRAITS.has(t))
	_empty.visible = rows.is_empty() and ghosts.is_empty()
	var gsig := str(ghosts)
	if gsig == _ghost_sig:
		return
	_ghost_sig = gsig
	for c in _ghosts.get_children():
		_ghosts.remove_child(c)
		c.queue_free()
	for t in ghosts:
		var g := _row(String(t), 0)
		(g.find_child("Rising", true, false) as Label).visible = true
		(g.find_child("Rising", true, false) as Label).text = "0 → 1"
		(g.find_child("Plots", true, false) as Control).visible = false
		_ghosts.add_child(g)


## Lignes qui tiennent entre le haut de la colonne et la boutique.
func max_rows() -> int:
	var avail := get_viewport_rect().size.y - AutochessHud.s(AutochessHud.TOP_Y) - AutochessHud.BOTTOM_H * AutochessHud.k \
		- AutochessHud.s(70.0)
	return maxi(4, floori(avail / AutochessHud.s(ROW_H + 2.0)))


func _divider() -> Control:
	var s := ColorRect.new()
	s.color = Color(AutochessHud.INK, 0.25)
	s.custom_minimum_size = Vector2(0, 2)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _row(t: String, n: int) -> Control:
	var td: Dictionary = AutochessData.TRAITS[t]
	var tier := AutochessData.trait_tier(t, n)
	var ghost := n == 0
	var row := PanelContainer.new()
	row.name = "AcTrait_" + t
	row.set_meta("ac_trait", t)
	row.custom_minimum_size.y = AutochessHud.s(ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_STOP if not ghost else Control.MOUSE_FILTER_IGNORE
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.tooltip_text = "%s\n%s" % [String(td.short), String(td.tip)]
	row.set_meta("tier", tier)
	row.set_meta("count", n)
	row.add_theme_stylebox_override("panel", AutochessHud.sticker(Color(0, 0, 0, 0), 10.0, 0.0, 0.0, 4.0, 1.0))
	if ghost:
		row.modulate.a = 0.85
	if not ghost:
		UiFeel.attach(row, "row")
		row.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
					and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				detail_requested.emit(t)
				row.accept_event())
		row.mouse_entered.connect(func():
			hovered = t
			trait_hovered.emit(t))
		row.mouse_exited.connect(func():
			if hovered == t:
				hovered = ""
				trait_hovered.emit(""))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", roundi(AutochessHud.s(7.0)))
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var bd := badge(n, tier, t)
	h.add_child(bd)
	var nm := AutochessHud.ink_lbl(String(td.name), 15, AutochessHud.INK if tier > 0 else AutochessHud.INK_300, 800)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nm)
	var plots := Plots.make(AutochessData.trait_thresholds(t), n)
	plots.name = "Plots"
	h.add_child(plots)
	var up := AutochessHud.ink_lbl("", 14, AutochessHud.GAIN, 900)
	up.name = "Rising"
	up.visible = false
	h.add_child(up)
	return row


## Pastille hexagonale : compte du trait ; couleur de la famille (armes : lagon clair), grisée si le trait est inactif.
## [param t] "" : couleur du palier (ancienne fiche).
static func badge(n: int, tier: int, t := "") -> Control:
	var b := Badge.new()
	b.count = n
	b.tier = tier
	b.trait_id = t
	return b


class Badge extends Control:
	var count := 0
	var tier := 0
	var trait_id := ""

	func _init() -> void:
		custom_minimum_size = Vector2(AutochessHud.s(28.0), AutochessHud.s(30.0))
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.5
		var pts := PackedVector2Array()
		for i in 6:
			var a := deg_to_rad(60.0 * i - 90.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var col := AutochessHud.trait_candy(trait_id) if trait_id != "" else Color(AutochessTraitPanel.TIER_COLORS[clampi(tier, 0, 3)])
		if tier <= 0:
			col = AutochessHud.PAPER_300
		draw_colored_polygon(pts, col)
		pts.append(pts[0])
		draw_polyline(pts, AutochessHud.INK, 2.0, true)
		if count > 0:
			var f := AutochessHud.round_font(900)
			var s := str(count)
			var fs := AutochessHud.fs(15)
			var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at := Vector2(c.x - w * 0.5, c.y + fs * 0.36)
			if tier > 0:
				draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, AutochessHud.INK)
				draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
			else:
				draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, AutochessHud.INK_300)


## Plots des seuils : un rond par seuil (soleil = atteint), contour d'encre ; infobulle portée par la ligne.
class Plots extends Control:
	var thresholds: Array = []
	var count := 0

	static func make(list: Array, n: int) -> Plots:
		var p := Plots.new()
		p.thresholds = list
		p.count = n
		p.custom_minimum_size = Vector2(list.size() * AutochessHud.s(13.0) + 2.0, AutochessHud.s(14.0))
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return p

	func _draw() -> void:
		var r := AutochessHud.s(4.6)
		for i in thresholds.size():
			var c := Vector2(r + 1.5 + i * AutochessHud.s(13.0), size.y * 0.5)
			draw_circle(c, r, AutochessHud.candy("soleil") if count >= int(thresholds[i]) else AutochessHud.PAPER)
			draw_arc(c, r, 0.0, TAU, 16, AutochessHud.INK, 1.6, true)
