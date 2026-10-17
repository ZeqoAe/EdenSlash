extends CanvasLayer
## Navigation de tous les menus à la manette (autoload UiNav). Quand la dernière entrée vient de la
## manette et qu'on est dans un menu (jeu en pause, lobby, écran titre) :
##   - croix directionnelle ou stick gauche : déplace le curseur (un anneau lagon liseré de blanc, qui glisse en
##     120 ms d'un contrôle à l'autre et respire ; bible de style § 6-7) vers le contrôle le
##     plus proche dans cette direction, parmi ceux de l'écran du dessus (calque le plus haut) ;
##   - A (Croix) : valide (un vrai clic de souris au centre du contrôle, donc rien à réécrire dans
##     les écrans) ; gauche / droite sur un curseur : règle les curseurs de volume, etc. ;
##   - B (Rond) : retour (Échap) ; LB / RB (L1 / R1) : onglet précédent / suivant ;
##   - stick droit : fait défiler ; Y (Triangle) : curseur libre (le stick déplace la souris).
## Le cadre n'apparaît qu'après un premier mouvement de croix / stick (un appui sur A le fait d'abord
## apparaître, sans rien valider) ; l'aide est une petite barre d'icônes dans le coin bas gauche,
## seulement quand la manette est la dernière entrée utilisée.
## Un menu déroulant ouvert (OptionButton) garde la navigation native de Godot.

const REPEAT_FIRST := 0.38
const REPEAT_NEXT := 0.11
const DIRS := {&"left": Vector2.LEFT, &"right": Vector2.RIGHT, &"up": Vector2.UP, &"down": Vector2.DOWN}
const BAR_H := 28.0
const BAR_FONT := 15
## Couleur des boutons de face (Xbox : disque coloré ; PlayStation : symbole coloré sur disque sombre).
const GLYPH_ICON := {"A": "pad_a", "B": "pad_b", "X": "pad_x", "Y": "pad_y", "Croix": "pad_cross", "Rond": "pad_circle", "Carré": "pad_square", "Triangle": "pad_triangle"}  # pictogrammes (lot ICO-1)
const GLYPH_COLORS := {"A": Color(0.45, 0.85, 0.4), "B": Color(0.95, 0.35, 0.3), "X": Color(0.35, 0.6, 0.95), "Y": Color(0.98, 0.82, 0.3),
	"Croix": Color(0.45, 0.7, 1.0), "Rond": Color(0.95, 0.4, 0.4), "Carré": Color(0.95, 0.6, 0.85), "Triangle": Color(0.4, 0.9, 0.7)}

var cursor: Control
var free_mode := false  # curseur libre : le stick gauche déplace la souris (ancien comportement)
var shown := false  # le cadre doré est visible (après un mouvement de croix / stick)
var _frame: Control
var _bar: Control
var _bar_sig := ""
var _tabs_t := 0.0
var _tabs_ok := false
var _held := {}  # direction -> temps avant répétition
var _last_center := Vector2(200, 200)
var _popup_ctl: OptionButton
var _pulse := 0.0
var _frame_rect := Rect2()  # cadre affiché (glisse vers celui du curseur)
var _frame_snap := true  # le prochain cadre se pose sans glisser (il vient d'apparaître)
var _ring_white := StyleBoxFlat.new()
var _ring_lagon := StyleBoxFlat.new()


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_frame.visible = false
	_bar.visible = false
	for sb in [_ring_white, _ring_lagon]:
		sb.draw_center = false
		sb.set_corner_radius_all(18)
		sb.anti_aliasing = true
	_ring_white.border_color = Color.WHITE
	_ring_white.set_border_width_all(6)
	_ring_lagon.border_color = UiTheme.color("bonbon.lagon.fonce", Color(0.04, 0.49, 0.71))
	_ring_lagon.set_border_width_all(3)


## La navigation à la manette est active : dernière entrée = manette, dans un menu, curseur libre coupé.
func nav_on() -> bool:
	return Gamepad.active and Gamepad.menu_mode() and not free_mode and not _popup_open()


func _popup_open() -> bool:
	if _popup_ctl != null and is_instance_valid(_popup_ctl):
		if _popup_ctl.get_popup().visible:
			return true
	_popup_ctl = null
	return false


# --- candidats ----------------------------------------------------------------------------
## Contrôle sur lequel on peut se placer et valider.
func navigable(c: Control) -> bool:
	if not c.is_visible_in_tree() or c.size.x < 3.0 or c.size.y < 3.0:
		return false
	if c is BaseButton:
		return not (c as BaseButton).disabled and c.mouse_filter != Control.MOUSE_FILTER_IGNORE
	if c is Range or c is ItemList or c is LineEdit:
		return c.mouse_filter != Control.MOUSE_FILTER_IGNORE
	# panneau cliquable (lignes de liste, cartes) : un signal gui_input relié
	if c.mouse_filter == Control.MOUSE_FILTER_STOP and not (c is ScrollContainer) and c.gui_input.get_connections().size() > 0:
		return true
	return false


## Calque d'un contrôle (les fenêtres et popups passent au-dessus de tout).
static func layer_of(c: Node) -> int:
	var n := c
	while n != null:
		if n is CanvasLayer:
			return (n as CanvasLayer).layer
		if n is Window and n != n.get_tree().root:
			return 10000
		n = n.get_parent()
	return 0


## Candidats de l'écran du dessus (calque le plus haut qui en possède).
func candidates() -> Array:
	var all: Array = []
	_collect(get_tree().root, all)
	var top := -99999
	for c in all:
		top = maxi(top, layer_of(c))
	return all.filter(func(c): return layer_of(c) == top)


func _collect(n: Node, out: Array) -> void:
	if n == self:
		return
	var ci := n as CanvasItem
	if ci != null and not ci.visible:
		return  # tout le sous-arbre est caché
	if n is Control and navigable(n as Control) and _on_screen(n as Control):
		out.append(n)
	for ch in n.get_children():
		_collect(ch, out)


func _on_screen(c: Control) -> bool:
	# loin de l'écran : écarté (les contrôles d'une liste défilante restent candidats, on les fait défiler)
	return get_viewport().get_visible_rect().grow(2400.0).intersects(rect_of(c))


## Rectangle du contrôle dans le repère de l'écran.
static func rect_of(c: Control) -> Rect2:
	return c.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, c.size)


# --- déplacement --------------------------------------------------------------------------
## Place le cadre doré sur [param c] (bouton d'une carte qui apparaît, contrôle retrouvé à sa fermeture) ;
## sans effet quand la manette n'est pas la dernière entrée utilisée.
func focus(c: Control) -> void:
	if c == null or not is_instance_valid(c) or not Gamepad.active:
		return
	_set_cursor(c)
	if Gamepad.menu_mode() and not free_mode:
		shown = true


## Place le curseur sur le candidat le plus proche du dernier point (ou le premier).
func pick_default() -> void:
	var list := candidates()
	if list.is_empty():
		cursor = null
		return
	var best: Control = list[0]
	var best_d := INF
	for c in list:
		var d := rect_of(c).get_center().distance_to(_last_center)
		if d < best_d:
			best_d = d
			best = c
	_set_cursor(best)


func _set_cursor(c: Control) -> void:
	var prev := cursor if cursor != null and is_instance_valid(cursor) else null
	cursor = c
	if prev != c:
		UiFeel.nav_focus(c, prev)  # survol, tic de focus et vibration légère (ressenti du clic)
	_last_center = rect_of(c).get_center()
	var p: Node = c.get_parent()
	while p != null:
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(c)
		p = p.get_parent()
	_pulse = 0.0
	_frame.queue_redraw()


## Les deux rectangles se recouvrent (à 40 px près) sur l'axe perpendiculaire au déplacement.
static func _overlaps_across(a: Rect2, b: Rect2, dir: Vector2) -> bool:
	if absf(dir.x) > 0.5:
		return a.position.y < b.end.y + 40.0 and b.position.y < a.end.y + 40.0
	return a.position.x < b.end.x + 40.0 and b.position.x < a.end.x + 40.0


## Déplace le curseur dans la direction [param dir] ; renvoie vrai s'il a bougé.
func move(dir: Vector2) -> bool:
	if cursor == null or not is_instance_valid(cursor) or not cursor.is_visible_in_tree():
		pick_default()
		return cursor != null
	# saut explicite : un contrôle peut désigner celui où mène chaque direction (meta « nav_left »...),
	# par exemple de la touche d'une action au bouton de son groupe (Paramètres > Touches)
	var jump_key := "nav_left" if dir.x < -0.5 else ("nav_right" if dir.x > 0.5 else ("nav_up" if dir.y < -0.5 else "nav_down"))
	if cursor.has_meta(jump_key):
		var to: Variant = cursor.get_meta(jump_key)
		if to is Control and is_instance_valid(to) and navigable(to as Control):
			_set_cursor(to as Control)
			return true
	# liste : haut / bas change la sélection (chapitres du Guide...)
	if cursor is ItemList and absf(dir.y) > 0.5 and (cursor as ItemList).item_count > 0:
		var il := cursor as ItemList
		var sel := il.get_selected_items()
		var idx := (sel[0] if not sel.is_empty() else -1) + int(signf(dir.y))
		if idx >= 0 and idx < il.item_count:
			il.select(idx)
			il.item_selected.emit(idx)
			il.ensure_current_is_visible()
			return true
	# curseur de réglage : gauche / droite change la valeur
	if cursor is Range and absf(dir.x) > 0.5 and not (cursor is SpinBox):
		var r := cursor as Range
		r.value += r.step * (10.0 if r.step < (r.max_value - r.min_value) / 50.0 else 1.0) * signf(dir.x)
		return true
	var here := rect_of(cursor)
	var c0 := here.get_center()
	var best: Control = null
	var best_score := INF
	for c in candidates():
		if c == cursor:
			continue
		var r := rect_of(c)
		var d := r.get_center() - c0
		var along := d.dot(dir)
		# bord à bord : un contrôle déjà dans cette direction même s'il est large
		var edge := (r.position.x - here.end.x) if dir.x > 0.5 else ((here.position.x - r.end.x) if dir.x < -0.5 else ((r.position.y - here.end.y) if dir.y > 0.5 else (here.position.y - r.end.y)))
		if along <= 1.0 or edge < -6.0 and absf(along) < 4.0:
			continue
		var across := absf(d.dot(Vector2(dir.y, dir.x)))
		var score := maxf(edge, 0.0) + along * 0.25 + across * 2.2
		if across > absf(along) * 2.5 and not _overlaps_across(here, r, dir):
			continue  # trop de biais : pas dans cette direction
		if score < best_score:
			best_score = score
			best = c
	if best == null:
		return false
	_set_cursor(best)
	return true


## Valide le curseur : un clic de souris au centre du contrôle.
func activate() -> void:
	if cursor == null or not is_instance_valid(cursor) or not cursor.is_visible_in_tree():
		pick_default()
		return
	if cursor is Range and not (cursor is SpinBox):
		return  # un curseur de réglage se règle avec gauche / droite
	var pos := rect_of(cursor).get_center()
	var vp := get_viewport()
	vp.warp_mouse(pos)
	Gamepad.mark_warp(pos)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.position = pos
		e.global_position = pos
		e.pressed = pressed
		e.device = -1
		if pressed:
			e.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(e)
	if is_instance_valid(cursor) and cursor is OptionButton:
		_popup_ctl = cursor as OptionButton


## Clic droit au centre du contrôle (menus contextuels, vendre, déséquiper...).
func right_click() -> void:
	if cursor == null or not is_instance_valid(cursor):
		return
	var pos := rect_of(cursor).get_center()
	get_viewport().warp_mouse(pos)
	Gamepad.mark_warp(pos)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.position = pos
		e.global_position = pos
		e.pressed = pressed
		e.device = -1
		if pressed:
			e.button_mask = MOUSE_BUTTON_MASK_RIGHT
		Input.parse_input_event(e)


# --- onglets ------------------------------------------------------------------------------
## Y a-t-il des onglets à changer avec LB / RB sur l'écran du dessus ?
func has_tabs() -> bool:
	var best_layer := -99999
	var pages := 0
	for n in get_tree().get_nodes_in_group("tab_screens"):
		if n.has_method("is_open") and n.is_open() and layer_of(n) >= best_layer:
			best_layer = layer_of(n)
			pages = (n as PageScreen)._pages.size() if n is PageScreen else 2
	var tc_layer := -99999
	var tc_count := 0
	for t in get_tree().root.find_children("*", "TabContainer", true, false):
		if (t as TabContainer).is_visible_in_tree() and layer_of(t) >= tc_layer:
			tc_layer = layer_of(t)
			tc_count = (t as TabContainer).get_tab_count()
	if tc_count > 1 and tc_layer >= best_layer:
		return true
	return pages > 1


## Onglet suivant (+1) ou précédent (-1) de l'écran du dessus. Renvoie vrai si un onglet a changé.
func step_tab(delta: int) -> bool:
	var best: Node = null
	var best_layer := -99999
	for n in get_tree().get_nodes_in_group("tab_screens"):
		if n.has_method("is_open") and n.is_open() and layer_of(n) >= best_layer:
			best = n
			best_layer = layer_of(n)
	# onglets d'un TabContainer visible (Paramètres...)
	var tc: TabContainer = null
	var tc_layer := -99999
	for t in get_tree().root.find_children("*", "TabContainer", true, false):
		if (t as TabContainer).is_visible_in_tree() and layer_of(t) >= tc_layer:
			tc = t
			tc_layer = layer_of(t)
	if tc != null and tc_layer >= best_layer:
		var n := tc.get_tab_count()
		if n > 1:
			tc.current_tab = wrapi(tc.current_tab + delta, 0, n)
			cursor = null
			return true
	if best != null and best.has_method("step_page"):
		best.step_page(delta)
		cursor = null
		return true
	return false


# --- boucle -------------------------------------------------------------------------------
func _input(ev: InputEvent) -> void:
	if not nav_on():
		return
	if ev is InputEventJoypadButton:
		match ev.button_index:
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
				get_viewport().set_input_as_handled()  # la navigation native de Godot ne s'en mêle pas
			JOY_BUTTON_A:
				if ev.pressed:
					if shown:
						activate()
					else:
						reveal()  # cadre caché : le premier appui le montre, sans rien valider
				get_viewport().set_input_as_handled()
			JOY_BUTTON_LEFT_SHOULDER:
				if ev.pressed and step_tab(-1):
					get_viewport().set_input_as_handled()
			JOY_BUTTON_RIGHT_SHOULDER:
				if ev.pressed and step_tab(1):
					get_viewport().set_input_as_handled()
			JOY_BUTTON_Y:
				if ev.pressed:
					free_mode = true
					shown = false
					get_viewport().set_input_as_handled()
			JOY_BUTTON_X:
				if ev.pressed and shown and cursor != null and is_instance_valid(cursor):
					right_click()
					get_viewport().set_input_as_handled()
	elif ev is InputEventJoypadMotion and ev.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var menu := Gamepad.active and Gamepad.menu_mode()
	if not Gamepad.active:
		free_mode = false  # la souris reprend la main : retour à la navigation au cadre
	if not menu or free_mode:
		shown = false  # le cadre ne revient qu'après un nouveau mouvement de croix / stick
	var was_visible := _frame.visible
	_frame.visible = menu and shown and cursor != null
	if not _frame.visible:
		_frame_snap = true
	elif not was_visible:
		_frame_snap = true
	_bar.visible = menu
	if not menu:
		cursor = null
		_held.clear()
		return
	_tabs_t -= delta
	if _tabs_t <= 0.0:
		_tabs_t = 0.3
		_tabs_ok = has_tabs()
	_refresh_bar()
	if free_mode:
		return
	if _popup_open():
		_frame.visible = false
		return
	if cursor == null or not is_instance_valid(cursor) or not cursor.is_visible_in_tree():
		pick_default()
	_pulse += delta
	_frame.queue_redraw()
	# direction : croix ou stick gauche, avec répétition
	var dir := Vector2.ZERO
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		dir.x -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		dir.x += 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		dir.y -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		dir.y += 1.0
	var st := Gamepad.stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
	if dir == Vector2.ZERO and st.length() > 0.55:
		dir = Vector2(signf(st.x), 0.0) if absf(st.x) > absf(st.y) else Vector2(0.0, signf(st.y))
	if dir == Vector2.ZERO:
		_held.clear()
		return
	var key: Vector2 = dir.normalized()
	var due: float = _held.get(key, 0.0)
	if not _held.has(key):
		_held.clear()
		_held[key] = REPEAT_FIRST
		if shown:
			move(_axis(dir))
		else:
			reveal()  # premier mouvement : le cadre apparaît sur l'entrée par défaut
	else:
		_held[key] = due - delta
		if _held[key] <= 0.0:
			_held[key] = REPEAT_NEXT
			move(_axis(dir))


func _axis(d: Vector2) -> Vector2:
	if absf(d.x) >= absf(d.y):
		return Vector2(signf(d.x), 0.0)
	return Vector2(0.0, signf(d.y))


## Montre le cadre doré sur le contrôle courant (ou celui par défaut).
func reveal() -> void:
	shown = true
	if cursor == null or not is_instance_valid(cursor) or not cursor.is_visible_in_tree():
		pick_default()
	_pulse = 0.0
	_frame.queue_redraw()


# --- barre d'aide -------------------------------------------------------------------------
## Entrées de la barre d'aide : [noms des boutons, libellé]. Valider, Retour, et Onglets s'il y en a.
func hint_items() -> Array:
	var a := Settings.pad_name(JOY_BUTTON_A)
	var b := Settings.pad_name(JOY_BUTTON_B)
	if free_mode:
		return [[[a], "Clic"], [[b], "Retour"], [[Settings.pad_name(JOY_BUTTON_Y)], "Cadre"]]
	var items: Array = [[[a], "Valider"], [[b], "Retour"]]
	# lot GX-4 : ce que fait X (clic droit) sur le contrôle visé, dessiné dans la barre (meta « pad_x » du contrôle ou d'un parent :
	# « Équiper » dans le sac, « Retirer » sur la poupée…)
	var x := x_hint()
	if x != "":
		items.append([[Settings.pad_name(JOY_BUTTON_X)], x])
	if _tabs_ok:
		items.append([[Settings.pad_name(JOY_BUTTON_LEFT_SHOULDER), Settings.pad_name(JOY_BUTTON_RIGHT_SHOULDER)], "Onglets"])
	return items


## Action du bouton X sur le contrôle visé (meta « pad_x » du contrôle ou du plus proche parent qui en a une), "" sinon.
func x_hint() -> String:
	if not shown or cursor == null or not is_instance_valid(cursor):
		return ""
	var n: Node = cursor
	for _i in 6:
		if n == null:
			break
		if n.has_meta("pad_x"):
			return String(n.get_meta("pad_x"))
		n = n.get_parent()
	return ""


## Recalcule la taille de la barre quand son contenu change.
func _refresh_bar() -> void:
	var items := hint_items()
	var sig := str(items) + Settings.pad_layout()
	if sig == _bar_sig:
		return
	_bar_sig = sig
	var w := 14.0
	var font := UiTheme.bold_font()
	for it in items:
		w += _glyphs_width(it[0]) + 6.0 + font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, BAR_FONT).x + 16.0
	_bar.offset_left = 14.0
	_bar.offset_right = 14.0 + w
	_bar.offset_bottom = -6.0
	_bar.offset_top = -6.0 - BAR_H
	_bar.queue_redraw()


func _glyphs_width(names: Array) -> float:
	var w := 0.0
	for n in names:
		w += _glyph_width(String(n)) + 4.0
	return w - 4.0


func _glyph_width(n: String) -> float:
	if GLYPH_COLORS.has(n):
		return 22.0
	return UiTheme.bold_font().get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 14.0


func _draw_bar() -> void:
	_bar.draw_style_box(UiTheme.flat_box(Color(0.04, 0.03, 0.08, 0.85), Color(UiTheme.GOLD_DIM, 0.55), 1, 14, false), Rect2(Vector2.ZERO, _bar.size))
	var font := UiTheme.bold_font()
	var x := 14.0
	var cy := _bar.size.y * 0.5
	for it in hint_items():
		for n in it[0]:
			x += _draw_glyph(String(n), x, cy) + 4.0
		x += 2.0
		var ty := cy + (font.get_ascent(BAR_FONT) - font.get_descent(BAR_FONT)) * 0.5
		_bar.draw_string(font, Vector2(x, ty), it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, BAR_FONT, Color(1, 0.93, 0.7))
		x += font.get_string_size(it[1], HORIZONTAL_ALIGNMENT_LEFT, -1, BAR_FONT).x + 16.0


## Icône d'un bouton : disque coloré (Xbox), symbole coloré sur disque sombre (PlayStation) ou pastille
## de texte (LB / RB, L1 / R1). Renvoie sa largeur.
func _draw_glyph(n: String, x: float, cy: float) -> float:
	var w := _glyph_width(n)
	var font := UiTheme.bold_font()
	if not GLYPH_COLORS.has(n):
		_bar.draw_style_box(UiTheme.flat_box(Color(0.3, 0.28, 0.38), Color(0.75, 0.72, 0.85), 1, 7, false), Rect2(x, cy - 10.0, w, 20.0))
		var ty := cy + (font.get_ascent(13) - font.get_descent(13)) * 0.5
		_bar.draw_string(font, Vector2(x, ty), n, HORIZONTAL_ALIGNMENT_CENTER, w, 13, Color(1, 1, 1))
		return w
	var c := Vector2(x + 11.0, cy)
	var col: Color = GLYPH_COLORS[n]
	var gt := Ico.tex(String(GLYPH_ICON.get(n, "")), 24)
	if gt != null:
		_bar.draw_texture_rect(gt, Rect2(x - 1.0, cy - 12.0, 24.0, 24.0), false)
		return w
	if Settings.pad_layout() == "ps":
		_bar.draw_circle(c, 11.0, Color(0.12, 0.12, 0.18))
		match n:
			"Croix":
				_bar.draw_line(c + Vector2(-5, -5), c + Vector2(5, 5), col, 2.4)
				_bar.draw_line(c + Vector2(-5, 5), c + Vector2(5, -5), col, 2.4)
			"Rond":
				_bar.draw_arc(c, 5.2, 0.0, TAU, 20, col, 2.4)
			"Carré":
				_bar.draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), col, false, 2.4)
			_:
				_bar.draw_polyline(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 5), c + Vector2(-6, 5), c + Vector2(0, -6)]), col, 2.4)
	else:
		_bar.draw_circle(c, 11.0, col)
		var ty := cy + (font.get_ascent(14) - font.get_descent(14)) * 0.5
		_bar.draw_string(font, Vector2(x, ty), n, HORIZONTAL_ALIGNMENT_CENTER, 22.0, 14, Color(0.06, 0.05, 0.1))
	return w


## Cadre de focus (bible § 6) : liseré blanc de 6 px et anneau lagon foncé de 3 px, coins ronds ; il glisse d'un contrôle
## à l'autre (120 ms, sortie cubique) et respire doucement ; « Réduire les animations » : il saute et ne respire pas.
func _draw_frame() -> void:
	if cursor == null or not is_instance_valid(cursor) or not cursor.is_visible_in_tree():
		return
	var target := rect_of(cursor).grow(5.0)
	var calm := UiFeel.reduce_motion
	if _frame_snap or calm or _frame_rect.size == Vector2.ZERO:
		_frame_rect = target
		_frame_snap = false
	else:
		var k := 1.0 - exp(-get_process_delta_time() * 28.0)
		_frame_rect = Rect2(_frame_rect.position.lerp(target.position, k), _frame_rect.size.lerp(target.size, k))
	var breath := 0.0 if calm else 1.5 * (0.5 + 0.5 * sin(_pulse * 4.2))
	var r := _frame_rect.grow(breath)
	var rad := clampi(int(minf(r.size.y, r.size.x) * 0.5), 6, 18)
	_ring_white.set_corner_radius_all(rad + 3)
	_ring_lagon.set_corner_radius_all(rad)
	_frame.draw_style_box(_ring_white, r.grow(3.0))
	_frame.draw_style_box(_ring_lagon, r)
