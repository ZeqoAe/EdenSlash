class_name InventoryScreen
extends CanvasLayer
## Écran Inventaire plein écran (maquette de l'utilisateur) : barre du haut (retour, titre,
## carte de la classe), raccourcis vers les autres écrans du jeu à gauche (et la zone en
## bas), puis la page InventoryPage (héros équipé et inventaire).
## L'hôte (lobby, menu pause) fournit les raccourcis : [[libellé, icône, Callable]].

signal closed

var page: InventoryPage
var shortcuts: Array = []
var back_text := "Retour au hub"
var zone_texture: Texture2D
var pause_game := false
var _root: Control
var _class_icon: TextureRect
var _class_name: Label
var _class_level: Label
var _zone_name: Label
var _zone_level: Label
var _zone_thumb: TextureRect
var _side: VBoxContainer


func _init(layer_index := 6) -> void:
	layer = layer_index
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	# fond : la scène du lobby reste visible sur les bords, assombrie au centre
	var bg := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.45)
	grad.fill_to = Vector2(1.15, 1.15)
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.06, 0.05, 0.14, 0.99))
	grad.gradient.set_color(1, Color(0.02, 0.02, 0.06, 0.985))
	bg.texture = grad
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 18
	v.offset_top = 12
	v.offset_right = -18
	v.offset_bottom = -16
	v.add_theme_constant_override("separation", 10)
	_root.add_child(v)
	_build_top(v)
	var line := ColorRect.new()
	line.color = Color(UiTheme.GOLD_DIM, 0.55)
	line.custom_minimum_size = Vector2(0, 2)
	v.add_child(line)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)
	_side = VBoxContainer.new()
	_side.custom_minimum_size = Vector2(200, 0)
	_side.add_theme_constant_override("separation", 10)
	body.add_child(_side)
	page = InventoryPage.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(page)
	_root.visible = false


func _build_top(parent: Control) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	top.custom_minimum_size = Vector2(0, 74)
	parent.add_child(top)
	var back := Button.new()
	back.text = "  " + back_text
	back.icon = MenuWidgets.icon("back")
	back.expand_icon = false
	back.add_theme_constant_override("icon_max_width", 20)
	back.focus_mode = Control.FOCUS_NONE
	back.custom_minimum_size = Vector2(190, 44)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_override("font", UiTheme.bold_font())
	back.add_theme_font_size_override("font_size", 16)
	back.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.06, 0.05, 0.12, 0.9), UiTheme.GOLD_DIM, 2, 22, false))
	back.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.25, 0.18, 0.07, 0.95), UiTheme.GOLD, 2, 22, false))
	back.pressed.connect(close_ui)
	top.add_child(back)
	var chest := InventoryPage.gold_icon("chest", 58)
	top.add_child(chest)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", -4)
	top.add_child(tv)
	var t := Label.new()
	t.text = "Inventaire"
	UiTheme.title(t, 42, UiTheme.GOLD)
	tv.add_child(t)
	Hud._label(tv, "Gérez votre équipement, vos objets et personnalisez votre personnage.", 15, UiTheme.TEXT)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var cc := PanelContainer.new()
	cc.add_theme_stylebox_override("panel", InventoryPage.card_box())
	cc.custom_minimum_size = Vector2(230, 0)
	cc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(cc)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 10)
	cc.add_child(ch)
	_class_icon = TextureRect.new()
	_class_icon.custom_minimum_size = Vector2(48, 48)
	_class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ch.add_child(_class_icon)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", -2)
	ch.add_child(cv)
	_class_name = Hud._label(cv, "", 18, UiTheme.TEXT)
	_class_name.add_theme_font_override("font", UiTheme.bold_font())
	_class_level = Hud._label(cv, "", 15, UiTheme.MUTED)


func _build_side() -> void:
	for c in _side.get_children():
		c.queue_free()
	_side.add_child(_nav("Inventaire", "chest", Callable(), true))
	for s in shortcuts:
		_side.add_child(_nav(String(s[0]), String(s[1]), s[2]))
	_side.add_child(_nav(back_text, "home", close_ui))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.add_child(sp)
	# zone choisie
	var zc := PanelContainer.new()
	zc.add_theme_stylebox_override("panel", InventoryPage.card_box())
	_side.add_child(zc)
	var zh := HBoxContainer.new()
	zh.add_theme_constant_override("separation", 8)
	zc.add_child(zh)
	_zone_thumb = TextureRect.new()
	_zone_thumb.custom_minimum_size = Vector2(96, 64)
	_zone_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_zone_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	zh.add_child(_zone_thumb)
	var zv := VBoxContainer.new()
	zv.alignment = BoxContainer.ALIGNMENT_CENTER
	zv.add_theme_constant_override("separation", 0)
	zh.add_child(zv)
	zv.add_child(InventoryPage.gold_icon("pin", 18))
	_zone_name = Hud._label(zv, "", 12, UiTheme.TEXT)
	_zone_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_zone_name.custom_minimum_size = Vector2(90, 0)
	_zone_level = Hud._label(zv, "", 11, UiTheme.MUTED)


func _nav(text: String, icon_name: String, cb: Callable, active := false) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.icon = MenuWidgets.icon(icon_name)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 30)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_override("font", UiTheme.bold_font())
	b.add_theme_font_size_override("font_size", 17)
	var n := UiTheme.flat_box(Color(0.06, 0.05, 0.13, 0.88), Color(0.5, 0.4, 0.24, 0.85), 1, 10, false)
	n.content_margin_left = 16
	var on := UiTheme.flat_box(Color(0.32, 0.22, 0.07, 0.95), UiTheme.GOLD, 2, 10, false)
	on.content_margin_left = 16
	on.shadow_color = Color(UiTheme.GOLD, 0.45)
	on.shadow_size = 8
	var hov := UiTheme.flat_box(Color(0.18, 0.13, 0.07, 0.95), UiTheme.GOLD, 1, 10, false)
	hov.content_margin_left = 16
	b.add_theme_stylebox_override("normal", on if active else n)
	b.add_theme_stylebox_override("hover", on if active else hov)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_color_override("icon_normal_color", UiTheme.GOLD)
	b.add_theme_color_override("icon_hover_color", Color(1, 0.92, 0.65))
	b.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func refresh() -> void:
	var cid := Run.class_id if Profile.in_run else Profile.selected_class
	var cd := GameData.class_data(cid)
	_class_icon.texture = UiTheme.texture(String(cd.get("icon", "")))
	_class_name.text = String(cd.get("name_fr", cid))
	_class_name.add_theme_color_override("font_color", ClassPicker.tier_color(cid))
	var zone := GameData.zone(Run.zone_id if Profile.in_run else Profile.selected_zone)
	_class_level.text = ("Niv. %d" % page.player.level) if page.player else "Niv. %d+  ·  maîtrise %d" % [1 + int(zone.get("level_bonus", 0)), Profile.expertise_level(cid)]
	_zone_name.text = String(zone.get("name", ""))
	_zone_level.text = "Niv. %d+" % (1 + int(zone.get("level_bonus", 0)))
	_zone_thumb.texture = zone_texture
	_zone_thumb.visible = zone_texture != null
	page.refresh()


func is_open() -> bool:
	return _root != null and _root.visible


func open() -> void:
	_build_side()
	_root.visible = true
	if pause_game:
		get_tree().paused = true
	page.class_changed.connect(refresh, CONNECT_REFERENCE_COUNTED) if not page.class_changed.is_connected(refresh) else null
	refresh()


func close_ui() -> void:
	if not is_open():
		return
	_root.visible = false
	if pause_game:
		get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		close_ui()
