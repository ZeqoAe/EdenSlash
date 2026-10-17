class_name AutochessMeter
extends PanelContainer
## L'Échiquier, lot AC-V : le compteur de dégâts en direct (façon TFT), à gauche de l'écran pendant le combat. Une ligne par
## unité du combat regardé, classées : icône de la classe (cadre de la couleur du coût, étoiles), nom, chiffre et barre de
## la couleur de son camp (dégâts : auto-attaques, sorts, autres, en trois tons). Onglets Dégâts / Subis / Soins /
## Boucliers : clic, A, Tab ou LB / RB (UiNav, groupe « tab_screens ») ; repliable (bouton du titre). Chiffres :
## AutochessStats (compteurs de la couche d'effets). Les lignes (Row) et les onglets servent aussi au bilan
## (AutochessRecap). Rapport : conception/autochess/R_AC_V.md.

signal tab_changed(tab: String)

const W := 262.0
const ROW_H := 30.0
const REFRESH := 0.25  # s
const MINE := AutochessTeamBars.MINE
const FOE := AutochessTeamBars.FOE

var tab := "dealt"
var collapsed := false
var my_side := 0
var max_rows := 12
var _ctx: Dictionary = {}
var _body: VBoxContainer
var _rows_box: VBoxContainer
var _rows: Array = []
var _tabs: Array = []
var _toggle: Button
var _empty: Label
var _t := 0.0


func _init() -> void:
	name = "AcMeter"
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size.x = W
	add_to_group("tab_screens")
	add_theme_stylebox_override("panel", AutochessHud.box(AutochessHud.BG_SOFT, UiTheme.GOLD_DIM, 2, 10, 10, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_toggle = AutochessHud.button("Compteur ▾", "plain", 30.0)
	_toggle.name = "AcMeterToggle"
	_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_toggle.tooltip_text = "Replier ou ouvrir le compteur."
	_toggle.pressed.connect(func(): set_collapsed(not collapsed))
	v.add_child(_toggle)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_body)
	var row := tab_row(_tabs, func(t: String): set_tab(t))
	_body.add_child(row)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 2)
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(_rows_box)
	_empty = AutochessHud.lbl("", 14, UiTheme.MUTED)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(_empty)
	set_tab(tab)


## Rangée des 4 onglets (boutons rangés dans [param out]) ; [param pick] reçoit l'onglet choisi.
static func tab_row(out: Array, pick: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in AutochessStats.TABS:
		var b := AutochessHud.button(String(AutochessStats.TAB_NAMES[t]), "plain", 28.0)
		b.name = "AcTab_" + String(t)
		b.add_theme_font_size_override("font_size", 14)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.tooltip_text = String(AutochessStats.TAB_TIPS[t])
		b.set_meta("tab", t)
		b.pressed.connect(func(): pick.call(String(t)))
		h.add_child(b)
		out.append(b)
	return h


## Onglet choisi en or, les autres discrets.
static func paint_tabs(buttons: Array, current: String) -> void:
	for b in buttons:
		var on := String((b as Button).get_meta("tab", "")) == current
		var col := UiTheme.GOLD if on else UiTheme.MUTED
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			(b as Button).add_theme_color_override(k, col)
		var sb := AutochessHud.box(Color(0.14, 0.13, 0.28, 0.96) if on else Color(0.09, 0.1, 0.23, 0.9),
			UiTheme.GOLD if on else Color(UiTheme.GOLD_DIM, 0.5), 2, 8, 8, 2)
		for st in ["normal", "focus", "hover", "pressed"]:
			(b as Button).add_theme_stylebox_override(st, sb)


## Combat à suivre : contexte de la couche d'effets [param ctx], vu du camp [param side].
func show_fight(ctx: Dictionary, side: int) -> void:
	_ctx = ctx
	my_side = side
	_t = 0.0
	refresh()


func set_tab(t: String) -> void:
	if not t in AutochessStats.TABS:
		return
	tab = t
	paint_tabs(_tabs, tab)
	_toggle.text = ("%s ▸" if collapsed else "%s ▾") % String(AutochessStats.TAB_NAMES[tab])
	refresh()
	tab_changed.emit(tab)


func set_collapsed(on: bool) -> void:
	collapsed = on
	_body.visible = not on
	_toggle.text = ("%s ▸" if collapsed else "%s ▾") % String(AutochessStats.TAB_NAMES[tab])
	reset_size()


## UiNav (LB / RB) : onglet suivant ou précédent.
func is_open() -> bool:
	return is_visible_in_tree() and not collapsed


func step_page(d: int) -> void:
	var i := AutochessStats.TABS.find(tab)
	set_tab(String(AutochessStats.TABS[posmod(i + d, AutochessStats.TABS.size())]))


func refresh() -> void:
	if _rows_box == null:
		return
	var list := AutochessStats.shown(AutochessStats.rows(_ctx, tab), tab)
	fill_rows(_rows_box, _rows, list, mini(list.size(), max_rows), my_side, tab, -1, ROW_H)
	_empty.text = AutochessStats.empty_text(tab)
	_empty.visible = list.is_empty() and _empty.text != ""


## Remplit [param box] avec [param n] lignes de [param list] (lignes réutilisées, rangées dans [param pool]) ;
## [param mvp] : fid du MVP (étoile dorée), -1 aucun.
static func fill_rows(box: Container, pool: Array, list: Array, n: int, side: int, t: String, mvp := -1, h := ROW_H) -> void:
	while pool.size() < n:
		var r := Row.new()
		r.custom_minimum_size = Vector2(0, h)
		box.add_child(r)
		pool.append(r)
	var top := 0.0
	for e in list:
		top = maxf(top, float(e.value))
	for i in pool.size():
		var r := pool[i] as Row
		r.visible = i < n
		if i < n:
			r.set_row(list[i], top, int(list[i].side) == side, t, int(list[i].fid) == mvp and mvp >= 0)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or collapsed:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = REFRESH
	refresh()


func _unhandled_input(ev: InputEvent) -> void:
	var ke := ev as InputEventKey
	if ke != null and ke.pressed and not ke.echo and ke.keycode == KEY_TAB and is_open():
		step_page(-1 if ke.shift_pressed else 1)
		get_viewport().set_input_as_handled()


## Une ligne : icône (cadre du coût, étoiles), nom, chiffre, barre de la couleur du camp (dégâts : 3 tons).
class Row extends Control:
	var label := ""
	var value := 0.0
	var ratio := 0.0
	var parts: Array = []  # parts de la barre (dégâts : auto, sorts, autres), somme = ratio
	var mine := true
	var stars := 1
	var cost_col := Color.WHITE
	var icon: Texture2D
	var alive := true
	var mvp := false
	var extra := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func set_row(e: Dictionary, top: float, is_mine: bool, t: String, is_mvp: bool) -> void:
		label = String(e.label)
		value = float(e.value)
		ratio = value / top if top > 0.0 else 0.0
		parts = []
		if t == "dealt" and value > 0.0:
			for s in e.split:
				parts.append(float(s) / top)
		mine = is_mine
		stars = int(e.stars)
		cost_col = UiTheme.HP if bool(e.get("monster", false)) else AutochessBoard.cost_color(int(e.cost))
		icon = UiTheme.texture(AutochessStats.icon_path(String(e.id)))
		alive = bool(e.alive)
		mvp = is_mvp
		extra = ("MVP ×%d" % int(e.mvp)) if int(e.get("mvp", 0)) > 0 else ""
		var tip := "%s : %s" % [label, AutochessStats.num(value)]
		if t == "dealt" and value > 0.0:
			tip += "\nAuto-attaques %s · sorts %s · autres %s" % [AutochessStats.num(e.split[0]), AutochessStats.num(e.split[1]),
				AutochessStats.num(e.split[2])]
		if int(e.kills) > 0:
			tip += "\nÉliminations : %d" % int(e.kills)
		tooltip_text = tip
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var col := AutochessTeamBars.MINE if mine else AutochessTeamBars.FOE
		var a := 1.0 if alive else 0.55
		var pic := Rect2(1.0, 2.0, h - 4.0, h - 4.0)
		draw_rect(pic, Color(0.04, 0.04, 0.1, 0.9))
		if icon != null:
			draw_texture_rect(icon, pic.grow(-2.0), false, Color(1, 1, 1, a))
		draw_rect(pic, Color(cost_col, a), false, 2.0)
		var font := UiTheme.bold_font()
		var fs := 14
		var x0 := pic.end.x + 6.0
		var st := "★".repeat(clampi(stars, 1, 3))
		draw_string_outline(font, Vector2(pic.position.x + 1.0, pic.end.y + 1.0), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, UiTheme.INK)
		draw_string(font, Vector2(pic.position.x + 1.0, pic.end.y + 1.0), st, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			AutochessBoard.STAR_COLORS[clampi(stars, 1, 3) - 1])
		var num := AutochessStats.num(value)
		var nw := font.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var name_col := Color(UiTheme.TEXT, a)
		var shown := ("✦ " if mvp else "") + label + (("  · " + extra) if extra != "" else "")
		draw_string(font, Vector2(x0, 15.0), shown, HORIZONTAL_ALIGNMENT_LEFT, maxf(10.0, w - x0 - nw - 8.0), fs,
			UiTheme.GOLD if mvp else name_col)
		draw_string(font, Vector2(w - nw - 2.0, 15.0), num, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(col.lightened(0.25), a))
		var bar := Rect2(x0, h - 10.0, w - x0 - 2.0, 6.0)
		draw_rect(bar, Color(0.08, 0.08, 0.14, 0.9))
		if parts.is_empty():
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(ratio, 0.0, 1.0), bar.size.y)), Color(col, a))
		else:
			var x := bar.position.x
			var tones := [col, col.lightened(0.4), col.darkened(0.35)]
			for i in parts.size():
				var pw := bar.size.x * clampf(float(parts[i]), 0.0, 1.0)
				draw_rect(Rect2(Vector2(x, bar.position.y), Vector2(pw, bar.size.y)), Color(tones[i], a))
				x += pw
