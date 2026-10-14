extends CanvasLayer
## Navigation de tous les menus à la manette (autoload UiNav). Quand la dernière entrée vient de la
## manette et qu'on est dans un menu (jeu en pause, lobby, écran titre) :
##   - croix directionnelle ou stick gauche : déplace le curseur (un cadre doré) vers le contrôle le
##     plus proche dans cette direction, parmi ceux de l'écran du dessus (calque le plus haut) ;
##   - A (Croix) : valide (un vrai clic de souris au centre du contrôle, donc rien à réécrire dans
##     les écrans) ; gauche / droite sur un curseur : règle les curseurs de volume, etc. ;
##   - B (Rond) : retour (Échap) ; LB / RB (L1 / R1) : onglet précédent / suivant ;
##   - stick droit : fait défiler ; Y (Triangle) : curseur libre (le stick déplace la souris).
## Un menu déroulant ouvert (OptionButton) garde la navigation native de Godot.

const REPEAT_FIRST := 0.38
const REPEAT_NEXT := 0.11
const DIRS := {&"left": Vector2.LEFT, &"right": Vector2.RIGHT, &"up": Vector2.UP, &"down": Vector2.DOWN}

var cursor: Control
var free_mode := false  # curseur libre : le stick gauche déplace la souris (ancien comportement)
var _frame: Control
var _hint: Label
var _held := {}  # direction -> temps avant répétition
var _last_center := Vector2(200, 200)
var _popup_ctl: OptionButton
var _pulse := 0.0


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_frame = Control.new()
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(1, 0.93, 0.7))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.offset_top = -34
	_hint.offset_bottom = -8
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_frame.visible = false
	_hint.visible = false


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
	cursor = c
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
					activate()
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
					get_viewport().set_input_as_handled()
			JOY_BUTTON_X:
				if ev.pressed and cursor != null and is_instance_valid(cursor):
					right_click()
					get_viewport().set_input_as_handled()
	elif ev is InputEventJoypadMotion and ev.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var menu := Gamepad.active and Gamepad.menu_mode()
	if not Gamepad.active:
		free_mode = false  # la souris reprend la main : retour à la navigation au cadre
	_frame.visible = menu and not free_mode and cursor != null
	_hint.visible = menu
	if not menu:
		cursor = null
		_held.clear()
		return
	_hint.text = hint_text()
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
		move(_axis(dir))
	else:
		_held[key] = due - delta
		if _held[key] <= 0.0:
			_held[key] = REPEAT_NEXT
			move(_axis(dir))


func _axis(d: Vector2) -> Vector2:
	if absf(d.x) >= absf(d.y):
		return Vector2(signf(d.x), 0.0)
	return Vector2(0.0, signf(d.y))


## Aide en bas de l'écran, avec les boutons de la manette branchée.
func hint_text() -> String:
	if free_mode:
		return "%s : valider (clic)   ·   %s : retour   ·   stick gauche : souris   ·   %s : revenir au cadre" % [Settings.pad_name(JOY_BUTTON_A), Settings.pad_name(JOY_BUTTON_B), Settings.pad_name(JOY_BUTTON_Y)]
	return "%s : valider   ·   %s : retour   ·   %s : clic droit   ·   %s / %s : onglets   ·   croix : naviguer   ·   stick droit : défiler   ·   %s : souris" % [
		Settings.pad_name(JOY_BUTTON_A), Settings.pad_name(JOY_BUTTON_B), Settings.pad_name(JOY_BUTTON_X), Settings.pad_name(JOY_BUTTON_LEFT_SHOULDER),
		Settings.pad_name(JOY_BUTTON_RIGHT_SHOULDER), Settings.pad_name(JOY_BUTTON_Y)]


func _draw_frame() -> void:
	if cursor == null or not is_instance_valid(cursor) or not cursor.is_visible_in_tree():
		return
	var r := rect_of(cursor).grow(4.0)
	var a := 0.75 + 0.25 * sin(_pulse * 7.0)
	_frame.draw_rect(r, Color(1.0, 0.85, 0.35, 0.10 * a))
	_frame.draw_rect(r, Color(1.0, 0.88, 0.4, a), false, 3.0)
	_frame.draw_rect(r.grow(3.0), Color(1.0, 1.0, 1.0, 0.25 * a), false, 1.5)
