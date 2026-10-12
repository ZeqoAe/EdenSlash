class_name PageScreen
extends CanvasLayer
## Écran plein écran à pages (menu pause, personnage, village) dans le style du
## grimoire : fond sombre, en-tête doré (titre, onglets, bourse, fermer), pages.
## Une page est un Control ; si elle a une méthode refresh(), elle est appelée à
## l'ouverture et au changement d'onglet.

signal closed
signal page_changed(index: int)

var title := ""
var pause_game := false  # met le jeu en pause tant que l'écran est ouvert
var _root: Control
var _title_label: Label
var _subtitle: Label
var _tabs: HBoxContainer
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _content: Control
var _wallet: ItemWidgets.Wallet
var _right: HBoxContainer
var _current := 0


func _init(screen_title := "", layer_index := 20) -> void:
	title = screen_title
	layer = layer_index
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.35)
	grad.fill_to = Vector2(1.1, 1.1)
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.13, 0.09, 0.22, 0.97))
	grad.gradient.set_color(1, Color(0.02, 0.01, 0.05, 0.99))
	bg.texture = grad
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var frame := Panel.new()  # cadre doré tout autour de l'écran
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 10
	frame.offset_top = 10
	frame.offset_right = -10
	frame.offset_bottom = -10
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fs := StyleBoxFlat.new()
	fs.bg_color = Color(0, 0, 0, 0)
	fs.border_color = Color(UiTheme.GOLD_DIM, 0.8)
	fs.set_border_width_all(2)
	fs.set_corner_radius_all(14)
	frame.add_theme_stylebox_override("panel", fs)
	_root.add_child(frame)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 28
	v.offset_top = 20
	v.offset_right = -28
	v.offset_bottom = -22
	v.add_theme_constant_override("separation", 10)
	_root.add_child(v)
	# en-tête : titre, onglets, bourse, fermer
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", -2)
	head.add_child(tbox)
	_title_label = Label.new()
	_title_label.text = title
	UiTheme.title(_title_label, 32)
	tbox.add_child(_title_label)
	_subtitle = Hud._label(tbox, "", 14, UiTheme.MUTED)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(_tabs)
	_right = HBoxContainer.new()
	_right.add_theme_constant_override("separation", 12)
	head.add_child(_right)
	_wallet = ItemWidgets.Wallet.new()
	_wallet.visible = false
	_right.add_child(_wallet)
	var close := Button.new()
	close.text = "✕  Fermer (Échap)"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(close_ui)
	_right.add_child(close)
	var line := ColorRect.new()
	line.color = Color(UiTheme.GOLD_DIM, 0.6)
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_content)
	_root.visible = false


## Ajoute une page (onglet [param name]) et renvoie son indice.
func add_page(name: String, page: Control) -> int:
	var i := _pages.size()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.visible = false
	_content.add_child(page)
	_pages.append(page)
	var b := Button.new()
	b.text = name
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(150, 42)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_font_override("font", UiTheme.title_font())
	b.pressed.connect(show_page.bind(i))
	_tabs.add_child(b)
	_tab_buttons.append(b)
	return i


func page(i: int) -> Control:
	return _pages[i]


func current_page() -> int:
	return _current


func show_page(i: int) -> void:
	_current = clampi(i, 0, _pages.size() - 1)
	for k in _pages.size():
		_pages[k].visible = k == _current
		_tab_buttons[k].set_pressed_no_signal(k == _current)
	refresh()
	page_changed.emit(_current)


func set_title(t: String, sub := "") -> void:
	title = t
	_title_label.text = t
	_subtitle.text = sub
	_subtitle.visible = sub != ""


## Bourse (or et matériaux de la run) dans l'en-tête.
func show_wallet(on: bool) -> void:
	_wallet.visible = on
	_wallet.refresh()


## Ajoute un contrôle à droite de l'en-tête (avant le bouton Fermer).
func add_header_control(c: Control) -> void:
	_right.add_child(c)
	_right.move_child(c, 0)


func refresh() -> void:
	_wallet.refresh()
	if _pages.is_empty():
		return
	var p := _pages[_current]
	if p.has_method("refresh"):
		p.refresh()


func is_open() -> bool:
	return _root != null and _root.visible


func open(i := -1) -> void:
	_root.visible = true
	if pause_game:
		get_tree().paused = true
	if not _pages.is_empty():
		show_page(_current if i < 0 else i)


func close_ui() -> void:
	if not is_open():
		return
	_root.visible = false
	if pause_game:
		get_tree().paused = false
	closed.emit()


## Une fenêtre ouverte par-dessus (paramètres, grimoire...) garde la touche Échap.
func _overlay_open() -> bool:
	for c in get_children():
		if c is CanvasLayer and c.has_method("is_open") and c.is_open():
			return true
	return false


func _input(event: InputEvent) -> void:
	if not is_open() or _overlay_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.is_action("pause") or event.physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		close_ui()
