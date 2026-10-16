class_name AutochessCursor
extends CanvasLayer
## L'Échiquier (lot AC-F) : curseur de case du plateau (sa moitié, banc, banc d'objets) pour la manette, la souris et le
## clavier. Spécification : conception/autochess/SPEC.md §7.1 ; rapport R_AC_F.md.
##   - Manette : chaque case a un petit contrôle invisible posé sur sa projection à l'écran (gui_input relié) : UiNav y
##     navigue comme dans tout menu (cadre doré, sauts explicites nav_left / right / up / down entre cases voisines),
##     A = un clic au centre de la case : prend / pose (échange si la case est occupée) ; B pose ce qui est tenu (annule) ;
##     X maintenu 0,5 s vend. Si UiNav ne navigue pas (héros en jeu), le curseur lit lui-même la croix, le stick et A.
##   - Souris : clic pour prendre puis clic pour poser, ou glisser-déposer ; déposer sur « Vendre » vend ; molette = zoom.
##   - Clavier : flèches, Entrée prend / pose, Échap annule, E vend.
## Les panneaux de préparation (boutique, AC-G) se posent sur le même calque (LAYER) : la croix passe alors du banc à la
## boutique sans réglage. Le curseur ne touche à aucune donnée : il appelle AutochessBoard.move / sell, qui préviennent.

signal hovered(slot: Dictionary, unit: Dictionary)  ## case sous le curseur (fiche d'unité d'AC-G) ; {} : hors du plateau
signal zoom_changed(zoom: int)

const LAYER := 6
const SELL_HOLD := 0.5  # s : X maintenu pour vendre
const DRAG_PX := 12.0
const REPEAT_FIRST := 0.32
const REPEAT_NEXT := 0.11
const DIRS := {"left": Vector2i.LEFT, "right": Vector2i.RIGHT, "up": Vector2i.UP, "down": Vector2i.DOWN}

var board: AutochessBoard
var camera: Camera3D
var enabled := true:
	set(v):
		enabled = v
		if _root:
			_root.visible = v
		if not v:
			cancel()
			slot = {}
			if _sell:
				_sell.visible = false
			if board:
				board.set_cursor({}, {})
var slot: Dictionary = {}  # case sous le curseur
var held: Dictionary = {}  # case d'origine de ce qui est tenu ({} : rien)
var zoom := 0
var sell_progress := 0.0  # 0 à 1 pendant que X est maintenu

var _root: Control
var _ctrls := {}  # slot_id -> Control
var _sell: PanelContainer
var _sell_text: Label
var _sell_hint: Label
var _sell_bar: ProgressBar
var _press_at := Vector2.INF
var _press_slot: Dictionary = {}
var _dragging := false
var _x_down := false
var _held_dir := Vector2i.ZERO
var _repeat := 0.0
var _last_mouse := Vector2(-1, -1)
var _source := "mouse"  # qui a placé le curseur en dernier : mouse, keys, pad
var _last_hover := "?"


func _init() -> void:
	layer = LAYER
	name = "AutochessCursor"


## Branche le curseur sur [param b] (déjà dans l'arbre) vu par [param cam].
func setup(b: AutochessBoard, cam: Camera3D) -> void:
	board = b
	camera = cam
	_root = Control.new()
	_root.name = "Cells"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	for s in board.all_slots():
		var c := Control.new()
		c.name = "AcCell_" + AutochessBoard.slot_id(s).replace(":", "_").replace(",", "_")
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.set_meta("ac_slot", s)
		c.gui_input.connect(_on_cell_input.bind(c))
		_root.add_child(c)
		_ctrls[AutochessBoard.slot_id(s)] = c
	for id in _ctrls:
		var c: Control = _ctrls[id]
		var n := neighbors(c.get_meta("ac_slot"))
		for d in n:
			c.set_meta("nav_" + String(d), _ctrls[AutochessBoard.slot_id(n[d])])
	_build_sell()
	_place_controls()
	enabled = enabled


func control_of(s: Dictionary) -> Control:
	return _ctrls.get(AutochessBoard.slot_id(s))


# --- voisins (déplacement à la croix, aux flèches) -----------------------------------------------------------------
## Cases voisines de [param s] à l'écran (caméra de son côté : haut = vers l'adversaire) : {"left": case, ...}.
## Haut / bas sur le plateau : même colonne, rangée voisine (les rangées décalées font un léger zigzag, l'aller-retour
## revient toujours à la même case) ; du fond vers le banc, du banc vers le fond ; à gauche, le banc d'objets.
func neighbors(s: Dictionary) -> Dictionary:
	var out := {}
	var R := AutochessBoard.ROWS
	var C := AutochessBoard.COLS
	match String(s.get("zone", "")):
		"board":
			var c := int(s.col)
			var r := int(s.row)
			if c > 0:
				out["left"] = AutochessBoard.board_slot(c - 1, r)
			else:
				out["left"] = _nearest(_item_column(1), board.slot_position(s), true)
			if c < C - 1:
				out["right"] = AutochessBoard.board_slot(c + 1, r)
			if r > 0:
				out["up"] = AutochessBoard.board_slot(c, r - 1)
			if r < R - 1:
				out["down"] = AutochessBoard.board_slot(c, r + 1)
			else:
				out["down"] = _nearest(_bench_row(), board.slot_position(s), false)
		"bench":
			var i := int(s.index)
			if i > 0:
				out["left"] = AutochessBoard.bench_slot(i - 1)
			else:
				out["left"] = AutochessBoard.items_slot(AutochessData.ITEM_BENCH_SIZE - 1)
			if i < AutochessData.BENCH_SIZE - 1:
				out["right"] = AutochessBoard.bench_slot(i + 1)
			out["up"] = _nearest(_back_row(), board.slot_position(s), false)
		"items":
			var i := int(s.index)
			var col := i / 5
			var row := i % 5
			if row > 0:
				out["up"] = AutochessBoard.items_slot(i - 1)
			out["down"] = AutochessBoard.items_slot(i + 1) if row < 4 else AutochessBoard.bench_slot(0)
			if col == 1:
				out["left"] = AutochessBoard.items_slot(i - 5)
				out["right"] = _nearest(_col0() + [AutochessBoard.bench_slot(0)], board.slot_position(s), true)
			else:
				out["right"] = AutochessBoard.items_slot(i + 5)
	return out


func _bench_row() -> Array:
	var out: Array = []
	for i in AutochessData.BENCH_SIZE:
		out.append(AutochessBoard.bench_slot(i))
	return out


func _back_row() -> Array:
	var out: Array = []
	for c in AutochessBoard.COLS:
		out.append(AutochessBoard.board_slot(c, AutochessBoard.ROWS - 1))
	return out


func _col0() -> Array:
	var out: Array = []
	for r in AutochessBoard.ROWS:
		out.append(AutochessBoard.board_slot(0, r))
	return out


func _item_column(col: int) -> Array:
	var out: Array = []
	for k in 5:
		out.append(AutochessBoard.items_slot(col * 5 + k))
	return out


## Case de [param list] la plus proche de [param p] en z ([param by_z]) ou en x.
func _nearest(list: Array, p: Vector3, by_z: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for s in list:
		var q := board.slot_position(s)
		var d := absf(q.z - p.z) if by_z else absf(q.x - p.x)
		if d < best_d - 0.001:
			best_d = d
			best = s
	return best


# --- actions --------------------------------------------------------------------------------------------------------
## Déplace le curseur d'une case ([param dir] : Vector2i.LEFT…) ; vrai s'il a bougé.
func move_dir(dir: Vector2i) -> bool:
	if not enabled or board == null:
		return false
	if slot.is_empty():
		_set_slot(AutochessBoard.bench_slot(AutochessData.BENCH_SIZE / 2))
		return true
	var name_ := ""
	for d in DIRS:
		if DIRS[d] == dir:
			name_ = d
	var n := neighbors(slot)
	if not n.has(name_):
		return false
	_set_slot(n[name_])
	return true


## Prendre / poser sur la case du curseur (A, Entrée, clic sans glisser).
func activate() -> void:
	if not enabled or board == null or slot.is_empty():
		return
	if held.is_empty():
		if not board.unit_at(slot).is_empty() or board.item_at(slot) != "":
			held = slot.duplicate()
		return
	if AutochessBoard.same_slot(held, slot):
		cancel()
		return
	if board.move(held, slot):
		held = {}
	# refusé (plateau plein…) : on garde l'unité en main pour choisir une autre case


## Repose ce qui est tenu à sa place ; vrai s'il y avait quelque chose.
func cancel() -> bool:
	var had := not held.is_empty()
	held = {}
	_dragging = false
	_x_down = false
	sell_progress = 0.0
	return had


## Vend l'unité tenue, sinon celle sous le curseur ; vrai si vendue.
func sell_current() -> bool:
	var from := held if not held.is_empty() and String(held.zone) != "items" else slot
	if not enabled or from.is_empty() or board.unit_at(from).is_empty():
		return false
	var ok := board.sell(from)
	if ok:
		held = {}
	_x_down = false
	sell_progress = 0.0
	return ok


func set_zoom(z: int) -> void:
	zoom = clampi(z, 0, 1)
	if camera and board:
		board.frame_camera(camera, zoom)
	zoom_changed.emit(zoom)


func _set_slot(s: Dictionary, source := "keys") -> void:
	slot = s.duplicate()
	_source = source
	if source != "pad" and Gamepad.active and UiNav.nav_on() and control_of(s):
		UiNav.focus(control_of(s))


# --- souris ---------------------------------------------------------------------------------------------------------
## Case sous un point de l'écran ({} : aucune).
func screen_slot(pos: Vector2) -> Dictionary:
	var g := _ground(pos)
	return board.pick(g) if g != Vector3.INF else {}


## Point du sol du plateau (repère du plateau) sous un point de l'écran.
func _ground(pos: Vector2) -> Vector3:
	if camera == null or board == null:
		return Vector3.INF
	var o := camera.project_ray_origin(pos)
	var d := camera.project_ray_normal(pos)
	var plane_y := board.to_global(Vector3(0.0, AutochessBoard.TOP, 0.0)).y
	if absf(d.y) < 0.0001:
		return Vector3.INF
	var t := (plane_y - o.y) / d.y
	if t <= 0.0:
		return Vector3.INF
	return board.to_local(o + d * t)


func _on_cell_input(ev: InputEvent, c: Control) -> void:
	if not enabled:
		return
	var pos: Vector2 = c.get_global_transform_with_canvas() * (ev as InputEventMouse).position if ev is InputEventMouse else Vector2.ZERO
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if mb.pressed:
				set_zoom(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 0)
			c.accept_event()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		var at := screen_slot(pos)
		if at.is_empty() and mb.device == -1:
			at = c.get_meta("ac_slot")  # clic simulé (UiNav) au centre de la case
		if mb.pressed:
			_press_at = pos
			_press_slot = at
			_dragging = false
		else:
			if _dragging:
				_drop(pos)
			elif not at.is_empty():
				_set_slot(at, "pad" if mb.device == -1 else "mouse")
				activate()
			_press_at = Vector2.INF
			_dragging = false
		c.accept_event()
	elif ev is InputEventMouseMotion and _press_at != Vector2.INF and not _dragging:
		if pos.distance_to(_press_at) > DRAG_PX and held.is_empty() and not _press_slot.is_empty() \
				and (not board.unit_at(_press_slot).is_empty() or board.item_at(_press_slot) != ""):
			held = _press_slot.duplicate()
			_dragging = true


func _drop(pos: Vector2) -> void:
	_dragging = false
	if held.is_empty():
		return
	if _sell.visible and _sell.get_global_rect().has_point(pos) and String(held.zone) != "items":
		sell_current()
		return
	var at := screen_slot(pos)
	if not at.is_empty() and not AutochessBoard.same_slot(at, held):
		_set_slot(at, "mouse")
		board.move(held, at)
	held = {}  # glissé : refusé ou posé, l'unité revient à sa case


func _on_sell_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not (ev as InputEventMouseButton).pressed and not held.is_empty():
		sell_current()
		_sell.accept_event()


# --- entrées --------------------------------------------------------------------------------------------------------
## Manette : le curseur lit lui-même la croix et A quand UiNav ne navigue pas (héros en jeu, pas de menu).
func _pad_self() -> bool:
	return Gamepad.active and not UiNav.nav_on()


func _input(ev: InputEvent) -> void:
	if not enabled or board == null:
		return
	if ev is InputEventJoypadButton:
		var jb := ev as InputEventJoypadButton
		var ours := _pad_self() or (UiNav.cursor != null and is_instance_valid(UiNav.cursor) and UiNav.cursor.has_meta("ac_slot"))
		match jb.button_index:
			JOY_BUTTON_B:
				if jb.pressed and not held.is_empty():
					cancel()
					get_viewport().set_input_as_handled()
			JOY_BUTTON_X:
				if jb.pressed and ours and (not board.unit_at(held if not held.is_empty() else slot).is_empty()):
					_x_down = true
					sell_progress = 0.0
					get_viewport().set_input_as_handled()
				elif not jb.pressed and _x_down:
					_x_down = false
					sell_progress = 0.0
					get_viewport().set_input_as_handled()
			JOY_BUTTON_A:
				if jb.pressed and _pad_self():
					activate()
					get_viewport().set_input_as_handled()
	elif ev is InputEventKey and (ev as InputEventKey).pressed and (ev as InputEventKey).keycode == KEY_ESCAPE and not held.is_empty():
		cancel()
		get_viewport().set_input_as_handled()


func _unhandled_input(ev: InputEvent) -> void:
	if not enabled or board == null:
		return
	var ke := ev as InputEventKey
	if ke != null and ke.pressed:
		var k := ke.keycode
		if ke.echo and not k in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
			return  # touche tenue : seules les flèches se répètent
		var used := true
		match k:
			KEY_LEFT:
				move_dir(Vector2i.LEFT)
			KEY_RIGHT:
				move_dir(Vector2i.RIGHT)
			KEY_UP:
				move_dir(Vector2i.UP)
			KEY_DOWN:
				move_dir(Vector2i.DOWN)
			KEY_ENTER, KEY_KP_ENTER:
				activate()
			KEY_E:
				sell_current()
			_:
				used = false
		if used:
			_source = "keys"
			get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			set_zoom(1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 0)


func _process(delta: float) -> void:
	if not enabled or board == null or camera == null:
		return
	_place_controls()
	# qui mène le curseur ?
	if UiNav.nav_on() and UiNav.cursor != null and is_instance_valid(UiNav.cursor) and UiNav.cursor.has_meta("ac_slot"):
		var s: Dictionary = UiNav.cursor.get_meta("ac_slot")
		if not AutochessBoard.same_slot(s, slot):
			_set_slot(s, "pad")
	elif _pad_self():
		_poll_pad(delta)
	elif not Gamepad.active:
		var m := get_viewport().get_mouse_position()
		if m.distance_to(_last_mouse) > 1.0 or _dragging:
			_last_mouse = m
			var at := screen_slot(m)
			if not at.is_empty() or _source == "mouse":
				slot = at
				_source = "mouse"
	# vente à la manette : X maintenu
	if _x_down:
		if Input.is_joy_button_pressed(0, JOY_BUTTON_X):
			sell_progress = minf(1.0, sell_progress + delta / SELL_HOLD)
			if sell_progress >= 1.0:
				sell_current()
		else:
			_x_down = false
			sell_progress = 0.0
	var at3 := Vector3.INF
	if not held.is_empty() and _source == "mouse" and not Gamepad.active:
		at3 = _ground(get_viewport().get_mouse_position())
	board.set_cursor(slot, held, at3)
	var id := AutochessBoard.slot_id(slot)
	if id != _last_hover:
		_last_hover = id
		hovered.emit(slot, board.unit_at(slot) if not slot.is_empty() else {})
	_refresh_sell()


func _poll_pad(delta: float) -> void:
	var dir := Vector2i.ZERO
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		dir = Vector2i.LEFT
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		dir = Vector2i.RIGHT
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		dir = Vector2i.UP
	elif Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		dir = Vector2i.DOWN
	else:
		var st := Gamepad.stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)
		if st.length() > 0.55:
			dir = Vector2i(int(signf(st.x)), 0) if absf(st.x) > absf(st.y) else Vector2i(0, int(signf(st.y)))
	if dir == Vector2i.ZERO:
		_held_dir = Vector2i.ZERO
		return
	if dir != _held_dir:
		_held_dir = dir
		_repeat = REPEAT_FIRST
		move_dir(dir)
		_source = "pad"
		return
	_repeat -= delta
	if _repeat <= 0.0:
		_repeat = REPEAT_NEXT
		move_dir(dir)
		_source = "pad"


# --- contrôles des cases --------------------------------------------------------------------------------------------
## Pose chaque contrôle invisible sur la projection de sa case (UiNav y dessine son cadre doré).
func _place_controls() -> void:
	for id in _ctrls:
		var c: Control = _ctrls[id]
		var s: Dictionary = c.get_meta("ac_slot")
		var p := board.to_global(board.slot_position(s))
		if camera.is_position_behind(p):
			c.visible = false
			continue
		var half := AutochessBoard.HEX_W * 0.5 if String(s.zone) == "board" else (
			AutochessBench.SLOT_R if String(s.zone) == "bench" else AutochessBench.ITEM_R)
		var basis := board.global_transform.basis
		var cx := camera.unproject_position(p)
		var w := (camera.unproject_position(p + basis.x.normalized() * half) - cx).length() * 2.0 * 0.92
		var h := (camera.unproject_position(p + basis.z.normalized() * half) - camera.unproject_position(p - basis.z.normalized() * half)).length() * 0.92
		c.size = Vector2(maxf(w, 8.0), maxf(h, 8.0))
		c.position = cx - c.size * 0.5
		c.visible = true


func _build_sell() -> void:
	_sell = PanelContainer.new()
	_sell.name = "SellZone"
	_sell.mouse_filter = Control.MOUSE_FILTER_STOP
	_sell.add_theme_stylebox_override("panel", UiTheme.panel_box(26, 10))
	_sell.anchor_left = 0.5
	_sell.anchor_right = 0.5
	_sell.anchor_top = 1.0
	_sell.anchor_bottom = 1.0
	_sell.offset_left = -170.0
	_sell.offset_right = 170.0
	_sell.offset_top = -112.0
	_sell.offset_bottom = -24.0
	_sell.gui_input.connect(_on_sell_input)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell.add_child(box)
	_sell_text = Label.new()
	_sell_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sell_text.add_theme_font_override("font", UiTheme.title_font())
	_sell_text.add_theme_font_size_override("font_size", 24)
	_sell_text.add_theme_color_override("font_color", UiTheme.GOLD)
	box.add_child(_sell_text)
	_sell_hint = Label.new()
	_sell_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sell_hint.add_theme_font_override("font", UiTheme.body_font())
	_sell_hint.add_theme_font_size_override("font_size", 15)
	_sell_hint.add_theme_color_override("font_color", UiTheme.MUTED)
	box.add_child(_sell_hint)
	_sell_bar = ProgressBar.new()
	_sell_bar.show_percentage = false
	_sell_bar.custom_minimum_size = Vector2(0, 6)
	_sell_bar.max_value = 1.0
	_sell_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_bar.add_theme_stylebox_override("background", UiTheme.flat_box(Color(UiTheme.INK, 0.8), UiTheme.GOLD_DIM, 1, 3, false))
	_sell_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(UiTheme.GOLD, UiTheme.GOLD, 0, 3, false))
	box.add_child(_sell_bar)
	_sell.visible = false
	add_child(_sell)


## Zone « Vendre » : visible pendant qu'une unité est tenue ou que X est maintenu.
func _refresh_sell() -> void:
	var from := held if not held.is_empty() else slot
	var unit_held := not held.is_empty() and String(held.zone) != "items"
	var show := unit_held or (_x_down and not board.unit_at(from).is_empty())
	_sell.visible = show
	if not show:
		return
	_sell_text.text = "Vendre  ·  +%d or" % board.sell_value(from)
	_sell_hint.text = ("Maintiens " + Settings.pad_name(JOY_BUTTON_X)) if Gamepad.active else ("Touche E" if _source == "keys" else "Dépose ici")
	_sell_bar.visible = _x_down
	_sell_bar.value = sell_progress
