class_name AutochessTraitPanel
extends PanelContainer
## L'Échiquier (lot AC-G) : colonne des traits (synergies) du plateau, à gauche. Une ligne par trait présent : pastille
## (compte, couleur du palier : gris, bronze, argent, or), nom, seuils « 2 · 4 · 6 » (les atteints en or). Les traits actifs
## d'abord. Infobulle : effet court + chiffres ; une ligne cliquable (souris, A à la manette) demande le détail
## (signal detail_requested : petite carte InfoCard ouverte par l'écran). SPEC §5.4, §7.1.

signal detail_requested(trait_id: String)

const W := 236.0
const ROW_H := 33.0  # hauteur d'une ligne (pastille de 26 px + marges)
const TIER_COLORS := [Color(0.42, 0.42, 0.5), Color(0.80, 0.52, 0.30), Color(0.78, 0.84, 0.95), Color(0.98, 0.78, 0.35)]

var rows := {}  # trait -> ligne (tests)
var _list: VBoxContainer
var _title: Label
var _empty: Label
var _sig := ""


func _init() -> void:
	name = "AcTraits"
	custom_minimum_size = Vector2(W, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", AutochessHud.box(AutochessHud.BG_SOFT, Color(UiTheme.GOLD_DIM, 0.6), 1, 10, 10, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_title = AutochessHud.lbl("Traits", 18, UiTheme.GOLD, "title")
	v.add_child(_title)
	_empty = AutochessHud.lbl("Place des héros pour éveiller leurs traits.", 14, UiTheme.MUTED)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty.custom_minimum_size.x = W - 24.0
	v.add_child(_empty)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_list)


## Compte de chaque trait du plateau (Autochess.trait_counts) ; reconstruit seulement si quelque chose a changé.
func refresh(counts: Dictionary) -> void:
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
	if sig == _sig:
		return
	_sig = sig
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	rows.clear()
	_empty.visible = order.is_empty()
	var shown := 0
	var max_rows := max_rows()
	for t in order:
		if shown >= max_rows - (1 if order.size() > max_rows else 0):
			var more := AutochessHud.lbl("+%d autres" % (order.size() - shown), 14, UiTheme.MUTED)
			_list.add_child(more)
			break
		var row := _row(String(t), int(counts[t]))
		_list.add_child(row)
		rows[t] = row
		shown += 1


## Lignes qui tiennent entre le haut de la colonne et la boutique.
func max_rows() -> int:
	var avail := get_viewport_rect().size.y - AutochessHud.TOP_Y - AutochessHud.BOTTOM_H - 16.0 - 44.0
	return maxi(4, floori(avail / ROW_H))


func _row(t: String, n: int) -> Control:
	var td: Dictionary = AutochessData.TRAITS[t]
	var tier := AutochessData.trait_tier(t, n)
	var row := PanelContainer.new()
	row.name = "AcTrait_" + t
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.tooltip_text = "%s\n%s" % [String(td.short), String(td.tip)]
	var sb := AutochessHud.box(Color(TIER_COLORS[tier], 0.12) if tier > 0 else Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 4, 2)
	row.add_theme_stylebox_override("panel", sb)
	row.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
				and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			detail_requested.emit(t)
			row.accept_event())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	h.add_child(badge(n, tier))
	var nm := AutochessHud.lbl(String(td.name), 15, UiTheme.TEXT if tier > 0 else UiTheme.MUTED, "bold")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	h.add_child(nm)
	var ths := HBoxContainer.new()
	ths.add_theme_constant_override("separation", 3)
	ths.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list: Array = AutochessData.trait_thresholds(t)
	for k in list.size():
		if k > 0:
			ths.add_child(AutochessHud.lbl("·", 14, Color(UiTheme.MUTED, 0.5)))
		var reached := n >= int(list[k])
		ths.add_child(AutochessHud.lbl(str(int(list[k])), 14, UiTheme.GOLD if reached else Color(UiTheme.MUTED, 0.7),
			"bold" if reached else "body"))
	h.add_child(ths)
	return row


## Pastille hexagonale : compte du trait, couleur du palier (0 = inactif).
static func badge(n: int, tier: int) -> Control:
	var b := Badge.new()
	b.count = n
	b.tier = tier
	return b


class Badge extends Control:
	var count := 0
	var tier := 0

	func _init() -> void:
		custom_minimum_size = Vector2(26, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		var pts := PackedVector2Array()
		for i in 6:
			var a := deg_to_rad(60.0 * i - 90.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var col: Color = AutochessTraitPanel.TIER_COLORS[clampi(tier, 0, 3)]
		draw_colored_polygon(pts, Color(col, 0.9) if tier > 0 else Color(0.14, 0.15, 0.26))
		pts.append(pts[0])
		draw_polyline(pts, col.lightened(0.2), 1.5, true)
		if count > 0:
			var f := UiTheme.bold_font()
			var s := str(count)
			var fs := 14
			var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, Vector2(c.x - w * 0.5, c.y + fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
				UiTheme.INK if tier > 0 else UiTheme.MUTED)
