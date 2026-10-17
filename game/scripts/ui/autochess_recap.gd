class_name AutochessRecap
extends Control
## L'Échiquier, lot AC-V : le bilan d'une manche (« Qui a compté ? ») et le bilan de la partie, en surimpression sur l'arène.
## Manche : résultat (Victoire / Défaite / Égalité, PV perdus, or), MVP de la manche (portrait, nom, étoiles, son chiffre),
## les mêmes barres classées que le compteur (AutochessMeter : onglets Dégâts / Subis / Soins / Boucliers, couleur du camp),
## le total de chaque camp. Partie : le cumul de tes héros (AutochessStats.add_round), la classe la plus utile, tes totaux.
## Manette : A Continuer, B ferme, LB / RB onglets (groupe « tab_screens ») ; clavier Entrée / Espace, Échap, Tab.
## L'écran le pose sur son propre calque (la manette n'y voit que lui). Rapport : conception/autochess/R_AC_V.md.

signal closed

const PANEL_W := 600.0
const MAX_ROWS := 10
const ROW_H := 28.0
const MINE := AutochessTeamBars.MINE
const FOE := AutochessTeamBars.FOE

var mode := "round"  # round / game
var tab := "dealt"
var my_side := 0
var continue_button: Button
var _ctx: Dictionary = {}
var _acc: Dictionary = {}
var _names: Array = ["", ""]
var _panel: PanelContainer
var _title: Label
var _line: Label
var _mvp_icon: TextureRect
var _mvp_frame: PanelContainer
var _mvp_head: Label
var _mvp_name: Label
var _mvp_line: Label
var _tabs: Array = []
var _rows_box: VBoxContainer
var _rows: Array = []
var _empty: Label
var _tot: Array = [null, null]
var _mvp_fid := -1


func _init() -> void:
	name = "AcRecap"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("tab_screens")
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.03, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.name = "AcRecapPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", AutochessHud.box(Color(0.05, 0.055, 0.14, 0.98), UiTheme.GOLD, 2, 14, 26, 16))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = PANEL_W
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_title = AutochessHud.lbl("", 30, UiTheme.GOLD, "title")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_line = AutochessHud.lbl("", 16, UiTheme.MUTED)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_line)
	v.add_child(_mvp_block())
	v.add_child(AutochessMeter.tab_row(_tabs, func(t: String): set_tab(t)))
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 2)
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows_box.custom_minimum_size.y = MAX_ROWS * (ROW_H + 2.0)
	v.add_child(_rows_box)
	_empty = AutochessHud.lbl("", 15, UiTheme.MUTED)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows_box.add_child(_empty)
	var th := HBoxContainer.new()
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(th)
	for k in 2:
		var l := AutochessHud.lbl("", 16, MINE if k == 0 else FOE, "bold")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if k == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		th.add_child(l)
		_tot[k] = l
	var bh := HBoxContainer.new()
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(bh)
	continue_button = AutochessHud.button("Continuer", "primary", 40.0, "Entrée", "A")
	continue_button.name = "AcRecapContinue"
	continue_button.custom_minimum_size.x = 200
	continue_button.pressed.connect(close)
	bh.add_child(continue_button)


func _mvp_block() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mvp_frame = PanelContainer.new()
	_mvp_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mvp_frame.custom_minimum_size = Vector2(64, 64)
	h.add_child(_mvp_frame)
	_mvp_icon = TextureRect.new()
	_mvp_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mvp_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mvp_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mvp_frame.add_child(_mvp_icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_mvp_head = AutochessHud.lbl("MVP de la manche", 14, UiTheme.GOLD, "bold")
	v.add_child(_mvp_head)
	_mvp_name = AutochessHud.lbl("", 22, UiTheme.TEXT, "title")
	v.add_child(_mvp_name)
	_mvp_line = AutochessHud.lbl("", 15, UiTheme.MUTED)
	v.add_child(_mvp_line)
	return h


## Bilan d'une manche : [param ctx] = contexte de la couche du combat du joueur (camp [param side]) ; [param title] /
## [param line] / [param col] : résultat ; [param names] : [toi, adversaire].
func open_round(ctx: Dictionary, side: int, title: String, line: String, col: Color, names: Array) -> void:
	mode = "round"
	_ctx = ctx
	my_side = side
	_names = names
	_title.text = title
	_title.add_theme_color_override("font_color", col)
	_line.text = line
	_line.visible = line != ""
	_mvp_fid = AutochessStats.mvp(ctx)
	_mvp_head.text = "MVP de la manche"
	if _mvp_fid >= 0:
		var u: Dictionary = ctx.units[_mvp_fid]
		var mine := int(u.side) == side
		_set_mvp(String(u.id), int(u.stars), int(u.cost), AutochessStats.label(u), u.stats, mine,
			String(u.monster) != "" or bool(u.guardian))
	else:
		_set_mvp("", 1, 1, "", {}, true, false)
	continue_button.text = "Continuer"
	_open()


## Bilan de la partie : cumul [param acc] (AutochessStats.add_round) ; [param title] : place ; [param line] : résumé.
func open_game(acc: Dictionary, title: String, line: String, my_name: String) -> void:
	mode = "game"
	_acc = acc
	_ctx = {}
	my_side = 0
	_names = [my_name, ""]
	_title.text = title
	_title.add_theme_color_override("font_color", UiTheme.GOLD)
	_line.text = line
	_line.visible = line != ""
	_mvp_fid = -1
	_mvp_head.text = "Héros de la partie"
	var best := AutochessStats.game_mvp(acc)
	if best != "":
		var e: Dictionary = acc.units[best]
		_set_mvp(best, int(e.stars), int(e.cost), AutochessData.unit_name(best), e, true, false)
	else:
		_set_mvp("", 1, 1, "", {}, true, false)
	continue_button.text = "Fermer"
	_open()


func _set_mvp(id: String, stars: int, cost: int, label: String, st: Dictionary, mine: bool, monster: bool) -> void:
	_mvp_frame.get_parent().visible = label != ""
	_mvp_icon.texture = UiTheme.texture(AutochessStats.icon_path(id))
	_mvp_frame.add_theme_stylebox_override("panel", AutochessHud.box(Color(0.04, 0.04, 0.1, 0.95),
		UiTheme.HP if monster else AutochessBoard.cost_color(cost), 3, 6, 4, 4))
	_mvp_name.text = "%s  %s" % [label, "★".repeat(clampi(stars, 1, 3))]
	_mvp_name.add_theme_color_override("font_color", MINE if mine else FOE)
	var parts: Array = []
	if AutochessStats.value(st, "dealt") > 0.0:
		parts.append("%s dégâts" % AutochessStats.num(AutochessStats.value(st, "dealt")))
	if AutochessStats.value(st, "heal") > 0.0:
		parts.append("%s soins" % AutochessStats.num(AutochessStats.value(st, "heal")))
	if parts.size() < 2 and AutochessStats.value(st, "taken") > 0.0:
		parts.append("%s encaissés" % AutochessStats.num(AutochessStats.value(st, "taken") + AutochessStats.value(st, "shield")))
	var k := int(st.get("kills", 0))
	if k > 0:
		parts.append("%d élimination%s" % [k, "s" if k > 1 else ""])
	_mvp_line.text = " · ".join(parts)


func _open() -> void:
	visible = true
	set_tab(tab)
	_panel.reset_size()
	UiNav.focus(continue_button)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func set_tab(t: String) -> void:
	if not t in AutochessStats.TABS:
		return
	tab = t
	AutochessMeter.paint_tabs(_tabs, tab)
	_refresh()


func is_open() -> bool:
	return is_visible_in_tree()


func step_page(d: int) -> void:
	var i := AutochessStats.TABS.find(tab)
	set_tab(String(AutochessStats.TABS[posmod(i + d, AutochessStats.TABS.size())]))


## Lignes affichées (pour les tests) : [{label, value, side}…].
func shown_rows() -> Array:
	var out: Array = []
	for r in _rows:
		if (r as Control).visible:
			out.append({"label": r.label, "value": r.value, "mine": r.mine})
	return out


func _refresh() -> void:
	var list: Array = AutochessStats.shown(AutochessStats.game_rows(_acc, tab) if mode == "game" else AutochessStats.rows(_ctx, tab), tab)
	AutochessMeter.fill_rows(_rows_box, _rows, list, mini(list.size(), MAX_ROWS), my_side, tab, _mvp_fid, ROW_H)
	_empty.text = AutochessStats.empty_text(tab).replace(" pour l'instant", "")
	_empty.visible = list.is_empty() and _empty.text != ""
	var name_t := String(AutochessStats.TAB_NAMES[tab]).to_lower()
	if mode == "game":
		var t := AutochessStats.game_totals(_acc)
		(_tot[0] as Label).text = "Tes héros · %s %s" % [AutochessStats.num(float(t[tab])), name_t]
		(_tot[1] as Label).text = "%d manches" % int(_acc.get("rounds", 0))
		(_tot[1] as Label).add_theme_color_override("font_color", UiTheme.MUTED)
		return
	for k in 2:
		var side := my_side if k == 0 else 1 - my_side
		var t := AutochessStats.totals(_ctx, side)
		var who := String(_names[k]) if k < _names.size() and String(_names[k]) != "" else ("Ton équipe" if k == 0 else "Adversaire")
		(_tot[k] as Label).text = "%s · %s" % [who, AutochessStats.num(float(t[tab]))]
		(_tot[k] as Label).add_theme_color_override("font_color", MINE if k == 0 else FOE)
		(_tot[k] as Label).tooltip_text = "Total de l'équipe (%s)" % name_t


func _input(ev: InputEvent) -> void:
	if not visible:
		return
	var ke := ev as InputEventKey
	if ke != null and ke.pressed and not ke.echo:
		match ke.keycode:
			KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				close()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				step_page(-1 if ke.shift_pressed else 1)
				get_viewport().set_input_as_handled()
	var jb := ev as InputEventJoypadButton
	if jb != null and jb.pressed and jb.button_index == JOY_BUTTON_B:
		close()
		get_viewport().set_input_as_handled()
