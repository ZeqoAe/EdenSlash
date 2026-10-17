class_name PageScreen
extends CanvasLayer
## Écran plein écran à pages (menu pause, marchand, collection) dans le style du
## grimoire : fond sombre, en-tête doré (titre, onglets, bourse, fermer), pages.
## Une page est un Control ; si elle a une méthode refresh(), elle est appelée à
## l'ouverture et au changement d'onglet. Si elle a une méthode subtitle() -> String, le
## texte renvoyé remplace le sous-titre de l'écran tant que cette page est affichée.
## Ressenti (UiFeel) : onglets autocollants (variation « PageTab » du thème : l'actif en mandarine), contenu qui glisse
## de 24 px dans le sens du changement d'onglet ; à l'ouverture, fondu et feuille qui se pose en ressort (UIK2).
## En partie (pause, Guide, Journal, marchand) : la scène floutée sous un voile d'encre derrière la feuille (bible § 2),
## feuille en retrait sur un grand écran pour que le jeu se voie autour ; au menu principal, le fond clair du ciel.

signal closed
signal page_changed(index: int)

var title := ""
var pause_game := false  # met le jeu en pause tant que l'écran est ouvert
var _root: Control
var _title_label: Label
var _subtitle: Label
var _base_sub := ""  # sous-titre de l'écran (set_title), quand la page n'en donne pas
var _tbox: VBoxContainer  # titre + sous-titre : largeur fixe, les onglets ne bougent pas d'une page à l'autre
var _tabs: HBoxContainer
var _tab_buttons: Array[Button] = []
var _pages: Array[Control] = []
var _content: Control
var _wallet: ItemWidgets.Wallet
var _right: HBoxContainer
var _current := 0
var _bg: TextureRect  # fond clair (menu principal)
var _blur: ColorRect  # scène floutée (en partie)
var _frame: Panel  # feuille de papier
var _sheet: VBoxContainer  # en-tête + pages, posé sur la feuille


func _init(screen_title := "", layer_index := 20) -> void:
	title = screen_title
	layer = layer_index
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	add_to_group("tab_screens")  # L1 / R1 changent d'onglet (UiNav)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.35)
	grad.fill_to = Vector2(1.1, 1.1)
	grad.gradient = Gradient.new()
	# fond : le ciel clair du monde (bible : jamais de fond sombre plein derrière un menu) ; cadre = feuille de papier
	# autocollante, l'en-tête est posé dessus, les pages dans un puits d'encre (« clair dehors, encre dedans », UIK1)
	grad.gradient.set_color(0, UiTheme.color("papier.200"))
	grad.gradient.set_color(1, UiTheme.color("monde.ciel", Color("ccdef3")).darkened(0.12))
	bg.texture = grad
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_bg = bg
	_blur = ColorRect.new()  # en partie : le jeu flouté derrière (UiTheme.blur_material), à la place du fond clair
	_blur.color = Color.WHITE
	_blur.material = UiTheme.blur_material()
	_blur.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur.visible = false
	_root.add_child(_blur)
	var frame := Panel.new()
	_frame = frame
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 10
	frame.offset_top = 10
	frame.offset_right = -10
	frame.offset_bottom = -10
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", UiTheme.panel_style(7))
	_root.add_child(frame)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 28
	v.offset_top = 20
	v.offset_right = -28
	v.offset_bottom = -22
	v.add_theme_constant_override("separation", 10)
	_root.add_child(v)
	_sheet = v
	# en-tête : titre, onglets, bourse, fermer
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	v.add_child(head)
	UiTheme.paper(head)  # en-tête sur le papier : onglets papier (l'actif en mandarine), Fermer papier, textes à l'encre
	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", -2)
	head.add_child(tbox)
	_tbox = tbox
	_title_label = Label.new()
	_title_label.text = title
	UiTheme.title(_title_label, 32)
	_title_label.set_meta("ink_keep", true)  # titre autocollant : soleil contouré d'encre, même sur le papier
	tbox.add_child(_title_label)
	_subtitle = Hud._label(tbox, "", 14, UiTheme.MUTED)
	_subtitle.clip_text = true  # un sous-titre long est abrégé plutôt que de pousser l'écran hors de la fenêtre
	_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	line.color = Color(UiTheme.color("encre.700"), 0.0)  # (le puits d'encre des pages fait la séparation)
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_content)
	_content.clip_contents = true  # une page plus haute que sa place ne déborde jamais sur la feuille (Carnet > Registre, UIK1)
	var well := Panel.new()  # puits d'encre sous les pages (une page sans panneau propre reste lisible)
	well.set_anchors_preset(Control.PRESET_FULL_RECT)
	well.mouse_filter = Control.MOUSE_FILTER_IGNORE
	well.add_theme_stylebox_override("panel", UiTheme.well_style(Vector2.ZERO, 18))
	_content.add_child(well)
	_root.visible = false
	get_viewport().size_changed.connect(_fit_header)
	_fit_header()


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
	b.theme_type_variation = &"PageTab"  # Mochiy, autocollant ; l'onglet actif en mandarine (UiTheme)
	b.set_meta("ui_feel", "tab")
	b.pressed.connect(show_page.bind(i))
	_tabs.add_child(b)
	_tab_buttons.append(b)
	for t in _tab_buttons:  # une seule page : pas d'onglet
		t.visible = _tab_buttons.size() > 1
	_fit_header()
	return i


## Pastille de nouveauté (NewsDot) sur l'onglet [param i], lue dans les groupes [param groups] de NewsDots ;
## [param with_action] : coche pomme quand une action est possible. API officielle des onglets (au lieu de _tab_buttons).
func set_tab_badge(i: int, groups: Array, with_action := false) -> NewsDot:
	if i < 0 or i >= _tab_buttons.size():
		return null
	var d := NewsDot.attach(_tab_buttons[i], groups)
	d.with_action = with_action
	d.refresh()
	return d


## En-tête adapté à la largeur de la fenêtre : à 1280 px, six onglets de 150 px et un titre de 340 px
## ne tiennent plus (la page entière débordait de l'écran) ; la largeur du titre ne dépend jamais de la page.
func _fit_header() -> void:
	if _tbox == null or not is_inside_tree():
		return
	var wide := get_viewport().get_visible_rect().size.x >= 1500.0
	_tbox.custom_minimum_size.x = 340.0 if wide else 230.0
	for b in _tab_buttons:
		var many := _tab_buttons.size() > 6  # sept onglets (Carnet > Rencontres, lot DNG-2) : sans largeur minimale, un cran plus petits
		b.custom_minimum_size = Vector2(150.0 if wide and not many else 0.0, 42.0)
		b.add_theme_font_size_override("font_size", (17 if wide else 15) - (1 if many else 0))
		if many and not wide:
			b.add_theme_font_override("font", UiTheme.bold_font())  # Mochiy est large : M PLUS Rounded 800 à 1280 px
		b.remove_theme_font_override("font")
	# l'en-tête ne déborde jamais (UIK1) : Mochiy (titres) est large ; si les onglets ne tiennent pas, ils passent en
	# M PLUS Rounded 800, puis sans largeur minimale, puis en 14 px
	_place_sheet(wide)
	var room := get_viewport().get_visible_rect().size.x - 2.0 * (_frame.offset_left + 18.0)
	var head := _tbox.get_parent() as Control
	for step in 3:
		if head == null or head.get_combined_minimum_size().x <= room:
			break
		for b in _tab_buttons:
			b.add_theme_font_override("font", UiTheme.bold_font())
			if step >= 1:
				b.custom_minimum_size.x = 0.0
			if step >= 2:
				b.add_theme_font_size_override("font_size", 14)


## En partie, la scène floutée derrière la feuille ; sur un grand écran (≥ 1500 px), la feuille en retrait (34 / 22 px)
## pour que le jeu se voie autour. À 1280 × 720 les marges restent de 10 px (les pages tiennent, shot_p1).
func _place_sheet(wide: bool) -> void:
	if _frame == null:
		return
	var in_game := Profile.in_run or pause_game
	_blur.visible = in_game
	_bg.visible = not in_game
	var mx := 34.0 if in_game and wide else 10.0
	var my := 22.0 if in_game and wide else 10.0
	_frame.offset_left = mx
	_frame.offset_right = -mx
	_frame.offset_top = my
	_frame.offset_bottom = -my
	_sheet.offset_left = mx + 18.0
	_sheet.offset_right = -(mx + 18.0)
	_sheet.offset_top = my + 10.0
	_sheet.offset_bottom = -(my + 12.0)


## Page suivante (+1) ou précédente (-1) : L1 / R1 (LB / RB) à la manette.
func step_page(delta: int) -> void:
	if _pages.size() > 1:
		show_page(wrapi(_current + delta, 0, _pages.size()))


func page(i: int) -> Control:
	return _pages[i]


func current_page() -> int:
	return _current


func show_page(i: int) -> void:
	var before := _current
	_current = clampi(i, 0, _pages.size() - 1)
	if before != _current and is_open():
		UiFeel.slide_in(_pages[_current], signi(_current - before))
	for k in _pages.size():
		_pages[k].visible = k == _current
		_tab_buttons[k].set_pressed_no_signal(k == _current)
	refresh()
	_update_subtitle()
	page_changed.emit(_current)


func set_title(t: String, sub := "") -> void:
	title = t
	_title_label.text = t
	_base_sub = sub
	_update_subtitle()


## Sous-titre de la page affichée (sa méthode subtitle()), sinon celui de l'écran.
func _update_subtitle() -> void:
	var sub := _base_sub
	if not _pages.is_empty() and _pages[_current].has_method("subtitle"):
		sub = String(_pages[_current].subtitle())
	_subtitle.text = sub
	_subtitle.tooltip_text = sub
	_subtitle.mouse_filter = Control.MOUSE_FILTER_PASS
	_subtitle.visible = sub != ""


func page_count() -> int:
	return _pages.size()


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
	if not _root.visible:
		UiFeel.page_sound(true)
		_fit_header()  # (fond flou ou clair selon qu'une partie est en cours)
		UiFeel.screen_in(_root, [_frame, _sheet])  # fondu, feuille qui se pose en ressort (même geste que le Héros)
	_root.visible = true
	if pause_game:
		get_tree().paused = true
	if not _pages.is_empty():
		show_page(_current if i < 0 else i)


func close_ui() -> void:
	if not is_open():
		return
	_root.visible = false
	UiFeel.page_sound(false)
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
