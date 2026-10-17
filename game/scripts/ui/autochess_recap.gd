class_name AutochessRecap
extends Control
## L'Échiquier, lot AC-V : le bilan d'une manche (« Qui a compté ? ») et le bilan de la partie, en surimpression sur l'arène.
## Manche : résultat (Victoire / Défaite / Égalité, PV perdus, or), MVP de la manche (portrait, nom, étoiles, son chiffre),
## les mêmes barres classées que le compteur (AutochessMeter : onglets Dégâts / Subis / Soins / Boucliers, couleur du camp),
## le total de chaque camp. Partie : le cumul de tes héros (AutochessStats.add_round), la classe la plus utile, tes totaux.
## Manette : A Continuer, B ferme, LB / RB onglets (groupe « tab_screens ») ; clavier Entrée / Espace, Échap, Tab.
## L'écran le pose sur son propre calque (la manette n'y voit que lui). Rapport : conception/autochess/R_AC_V.md.
## Lot ACX-2 : DA v2 (panneau papier, lignes dans un puits d'encre, « Meilleur héros ») ; le bilan de manche n'est plus
## imposé : la manche suivante enchaîne et un bandeau léger (RoundStrip, plus bas) résume le résultat 2,5 s, avec
## [Détail] qui ouvre ce bilan (réglage « Toujours montrer le bilan » : l'ancien comportement).

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
	dim.color = Color(AutochessHud.INK_900, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.name = "AcRecapPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", AutochessHud.paper_panel(7.0, 26.0, 16.0))
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = PANEL_W
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_title = AutochessHud.pop_lbl("", 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.rotation = deg_to_rad(-3.0)
	v.add_child(_title)
	_line = AutochessHud.ink_lbl("", 16, AutochessHud.INK_300, 800)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_line)
	v.add_child(_mvp_block())
	v.add_child(AutochessMeter.tab_row(_tabs, func(t: String): set_tab(t)))
	var well := PanelContainer.new()
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ws := AutochessHud.well(12.0, 2.0)
	ws.content_margin_left = 8
	ws.content_margin_right = 8
	ws.content_margin_top = 6
	ws.content_margin_bottom = 6
	well.add_theme_stylebox_override("panel", ws)
	v.add_child(well)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 2)
	_rows_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows_box.custom_minimum_size.y = MAX_ROWS * (ROW_H + 2.0)
	well.add_child(_rows_box)
	_empty = AutochessHud.lbl("", 15, AutochessHud.INK_100)
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows_box.add_child(_empty)
	var th := HBoxContainer.new()
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(th)
	for k in 2:
		var l := AutochessHud.ink_lbl("", 16, AutochessHud.GAIN if k == 0 else AutochessHud.LOSS, 900)
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
	_mvp_head = AutochessHud.ink_lbl("Meilleur héros de la manche", 14, AutochessHud.candy("soleil", 2), 900)
	v.add_child(_mvp_head)
	_mvp_name = AutochessHud.pop_lbl("", 22, AutochessHud.INK)
	v.add_child(_mvp_name)
	_mvp_line = AutochessHud.ink_lbl("", 15, AutochessHud.INK_300, 800)
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
	_title.add_theme_color_override("font_color", AutochessHud._banner_color(col))
	_line.text = line
	_line.visible = line != ""
	_mvp_fid = AutochessStats.mvp(ctx)
	_mvp_head.text = "Meilleur héros de la manche"
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
	_title.add_theme_color_override("font_color", AutochessHud.candy("soleil"))
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
	_mvp_frame.add_theme_stylebox_override("panel", AutochessHud.sticker(AutochessHud.candy("fraise") if monster
		else AutochessHud.cost_candy(cost), 12.0, 4.0, 3.0, 4.0, 4.0))
	_mvp_name.text = "%s  %s" % [label, "★".repeat(clampi(stars, 1, 3))]
	_mvp_name.add_theme_color_override("font_color", AutochessHud.GAIN if mine else AutochessHud.LOSS)
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
		(_tot[1] as Label).add_theme_color_override("font_color", AutochessHud.INK_300)
		return
	for k in 2:
		var side := my_side if k == 0 else 1 - my_side
		var t := AutochessStats.totals(_ctx, side)
		var who := String(_names[k]) if k < _names.size() and String(_names[k]) != "" else ("Ton équipe" if k == 0 else "Adversaire")
		(_tot[k] as Label).text = "%s · %s" % [who, AutochessStats.num(float(t[tab]))]
		(_tot[k] as Label).add_theme_color_override("font_color", AutochessHud.GAIN if k == 0 else AutochessHud.LOSS)
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


## Bandeau de manche NON bloquant (lot ACX-2, étude BM-AUTO §6 n° 7 et §7.3) : autocollant papier en haut au centre,
## « Victoire » / « Défaite » / « Égalité » en Mochiy incliné sur sa pastille (pomme / fraise / lilas), la ligne du
## résultat (« +6 or », « −7 PV »), puis le revenu de la manche suivante en petits plots (base, intérêts, série, atout) ;
## [Détail] ouvre le bilan complet (AutochessRecap). Il glisse, tient LIFE s (plus longtemps tant qu'il est survolé ou
## visé), puis repart : rien n'attend un clic.
class RoundStrip extends PanelContainer:
	signal detail_pressed

	const LIFE := 3.2

	var detail_button: Button
	var title: Label
	var line: Label
	var plots: HBoxContainer
	var _t := 0.0
	var _y0 := 0.0

	func _init() -> void:
		name = "AcRoundStrip"
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_stylebox_override("panel", AutochessHud.paper_panel(7.0, 16.0, 8.0))
		anchor_left = 0.5
		anchor_right = 0.5
		offset_top = AutochessHud.s(AutochessHud.TOP_Y) + AutochessHud.s(4.0)
		_y0 = offset_top
		grow_horizontal = Control.GROW_DIRECTION_BOTH
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", roundi(AutochessHud.s(14)))
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(h)
		title = AutochessHud.pop_lbl("", 30)
		title.rotation = deg_to_rad(-4.0)
		title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(title)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", roundi(AutochessHud.s(3)))
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(v)
		line = AutochessHud.ink_lbl("", 19, AutochessHud.INK, 900)
		v.add_child(line)
		plots = HBoxContainer.new()
		plots.add_theme_constant_override("separation", roundi(AutochessHud.s(5)))
		plots.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(plots)
		detail_button = AutochessHud.button("Détail", "plain", 36.0, "Tab", "")
		detail_button.name = "AcStripDetail"
		detail_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		detail_button.tooltip_text = "Le bilan complet du combat : meilleur héros, dégâts de chacun."
		detail_button.pressed.connect(func(): detail_pressed.emit())
		h.add_child(detail_button)
		visible = false

	## Résultat : [param head] (Victoire…), [param tone] (pomme, fraise, lilas), [param text] (« +6 or · −7 PV ») ;
	## [param detail] : bouton Détail.
	func show_result(head: String, tone: String, text: String, detail := true) -> void:
		title.text = head
		title.add_theme_color_override("font_color", AutochessHud.candy(tone) if tone != "lilas" else AutochessHud.candy("lilas", 2))
		line.text = text
		line.visible = text != ""
		for c in plots.get_children():
			c.queue_free()
		plots.visible = false
		detail_button.visible = detail
		_open()

	## Revenu de la manche qui commence : plots « 5 de base », « 2 d'intérêts »… ([param parts] : [[texte, bonbon]…]).
	func add_income(total: int, parts: Array) -> void:
		for c in plots.get_children():
			c.queue_free()
		var lead := AutochessHud.ink_lbl("+%d or" % total, 15, AutochessHud.GAIN, 900)
		plots.add_child(lead)
		for p in parts:
			var l := AutochessHud.ink_lbl(String(p[0]), 13, AutochessHud.INK, 800)
			l.add_theme_stylebox_override("normal", AutochessHud.sticker(AutochessHud.candy(String(p[1]), 0), 8.0, 0.0, 2.0, 6.0, 0.0))
			plots.add_child(l)
		plots.visible = true
		if not visible:
			title.text = ""
			line.visible = false
			detail_button.visible = false
			_open()
		_t = maxf(_t, LIFE * 0.8)
		reset_size()

	func _open() -> void:
		visible = true
		modulate.a = 1.0
		_t = LIFE
		reset_size()
		if not UiFeel.reduce_motion:
			var y0 := _y0
			offset_top = y0 - AutochessHud.s(30.0)
			modulate.a = 0.0
			var tw := create_tween()
			tw.set_parallel()
			tw.tween_property(self, "offset_top", y0, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(self, "modulate:a", 1.0, 0.15)

	func hide_now() -> void:
		visible = false
		_t = 0.0

	## Texte montré (tests) : « titre|ligne ».
	func text() -> String:
		return "%s|%s" % [title.text, line.text] if visible else ""

	func _process(delta: float) -> void:
		if not visible:
			return
		var held := get_global_rect().has_point(get_global_mouse_position()) or (UiNav.cursor == detail_button and UiNav.shown)
		if held:
			_t = maxf(_t, 0.4)
			modulate.a = 1.0
			return
		_t -= delta
		if _t < 0.3:
			modulate.a = maxf(_t / 0.3, 0.0)
		if _t <= 0.0:
			visible = false

	func _unhandled_input(ev: InputEvent) -> void:
		var ke := ev as InputEventKey
		if visible and detail_button.visible and ke != null and ke.pressed and not ke.echo and ke.keycode == KEY_TAB:
			detail_pressed.emit()
			get_viewport().set_input_as_handled()
