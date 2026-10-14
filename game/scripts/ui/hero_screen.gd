class_name HeroScreen
extends CanvasLayer
## Écran Héros plein écran (maquette de l'utilisateur) : tout ce qui concerne le héros au
## même endroit. Barre du haut (retour, titre, aide « ? », carte de la classe), sections à
## gauche, puis la section choisie :
## - Équipement : InventoryPage (héros équipé, coffre commun, statistiques et « Détail ») ;
## - Talents : TalentsPage (talents de classe, parcours de maîtrise, certificats) ;
## - Apparence : HeroPages.AppearancePage (tenue, tête, dos, auras, apparence d'arme) ;
## - Grimoire : sorts de la classe et auto-attaques des armes (livre ouvert par-dessus) ;
## - Classe : sélecteur des classes (aussi en cliquant la carte de la classe) ;
## - « ? » : guide des statistiques (InfoPage).
## Échap : ferme la fenêtre ouverte par-dessus, sinon revient au menu.

signal closed

## Équipement, Classe (sorts, maîtrise, talents, certificats ; grimoire détaillé en bouton),
## Apparence, Cartes. La classe se choisit avec la carte en haut à droite (menu par famille) :
## elle vaut pour toutes les sections (préréglages d'équipement, apparence, talents).
const SECTIONS := [["equipment", "Équipement", "equipment"], ["class", "Classe", "class"],
	["appearance", "Apparence", "jewel"], ["cards", "Cartes", "stats"]]

var page: InventoryPage
var talents: TalentsPage
var appearance: HeroPages.AppearancePage
var cards: HeroPages.CardsPage
var help: InfoPage
var grimoire: Grimoire
var back_text := "Retour au menu"
var zone_texture: Texture2D
var pause_game := false
var current := "equipment"
var _root: Control
var _title: Label
var _subtitle: Label
var _class_icon: TextureRect
var _class_name: Label
var _class_level: Label
var _zone_name: Label
var _zone_level: Label
var _zone_thumb: TextureRect
var _side: VBoxContainer
var _nav := {}  # section -> Button
var _pages := {}  # section -> Control
var _help_button: Button


func _init(layer_index := 6) -> void:
	layer = layer_index
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var bg := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.45)
	grad.fill_to = Vector2(1.15, 1.15)
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.06, 0.05, 0.14, 1.0))
	grad.gradient.set_color(1, Color(0.02, 0.02, 0.06, 1.0))
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
	var content := Control.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(content)
	page = InventoryPage.new()
	page.class_card = false
	talents = TalentsPage.new()
	talents.class_bar = false
	appearance = HeroPages.AppearancePage.new()
	cards = HeroPages.CardsPage.new()
	help = InfoPage.new()
	talents.open_grimoire = func(cid): grimoire.open(cid)
	for k in [["equipment", page], ["class", talents], ["appearance", appearance], ["cards", cards], ["help", help]]:
		var p: Control = k[1]
		p.set_anchors_preset(Control.PRESET_FULL_RECT)
		p.visible = false
		content.add_child(p)
		_pages[k[0]] = p
	_build_side()
	grimoire = Grimoire.new()
	add_child(grimoire)
	page.class_changed.connect(refresh)
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
	top.add_child(InventoryPage.gold_icon("class", 54))
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", -4)
	top.add_child(tv)
	_title = Label.new()
	_title.text = "Héros"
	UiTheme.title(_title, 42, UiTheme.GOLD)
	tv.add_child(_title)
	_subtitle = Hud._label(tv, "", 15, UiTheme.TEXT)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_help_button = Button.new()
	_help_button.text = "?"
	_help_button.tooltip_text = "Aide : comment chaque statistique est calculée"
	_help_button.focus_mode = Control.FOCUS_NONE
	_help_button.toggle_mode = true
	_help_button.custom_minimum_size = Vector2(52, 52)
	_help_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_help_button.add_theme_font_override("font", UiTheme.title_font())
	_help_button.add_theme_font_size_override("font_size", 26)
	_help_button.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.06, 0.05, 0.12, 0.9), UiTheme.GOLD_DIM, 2, 26, false))
	_help_button.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.25, 0.18, 0.07, 0.95), UiTheme.GOLD, 2, 26, false))
	_help_button.add_theme_stylebox_override("pressed", UiTheme.flat_box(Color(0.32, 0.22, 0.07, 0.95), UiTheme.GOLD, 2, 26, false))
	_help_button.pressed.connect(func(): show_section("equipment" if current == "help" else "help"))
	top.add_child(_help_button)
	var cc := Button.new()  # carte de la classe : ouvre le sélecteur
	cc.focus_mode = Control.FOCUS_NONE
	cc.tooltip_text = "Changer de classe"
	cc.add_theme_stylebox_override("normal", InventoryPage.card_box())
	cc.add_theme_stylebox_override("hover", InventoryPage.card_box(true))
	cc.add_theme_stylebox_override("pressed", InventoryPage.card_box(true))
	cc.custom_minimum_size = Vector2(250, 66)
	cc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cc.pressed.connect(func(): HeroPages.class_menu(cc, _cls(), func(cid):
		if Progression.class_unlocked(cid) and cid != Profile.selected_class and not Profile.in_run:
			Profile.selected_class = cid
			Profile.save_profile()
			refresh()))
	top.add_child(cc)
	var ch := HBoxContainer.new()
	ch.set_anchors_preset(Control.PRESET_FULL_RECT)
	ch.offset_left = 12
	ch.offset_right = -10
	ch.add_theme_constant_override("separation", 10)
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(ch)
	_class_icon = TextureRect.new()
	_class_icon.custom_minimum_size = Vector2(48, 48)
	_class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_class_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_class_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(_class_icon)
	var cv := VBoxContainer.new()
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_theme_constant_override("separation", -2)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(cv)
	_class_name = Hud._label(cv, "", 18, UiTheme.TEXT)
	_class_name.add_theme_font_override("font", UiTheme.bold_font())
	_class_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_class_level = Hud._label(cv, "", 14, UiTheme.MUTED)
	_class_level.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build_side() -> void:
	for s in SECTIONS:
		var b := _nav_button(String(s[1]), String(s[2]))
		b.pressed.connect(show_section.bind(String(s[0])))
		_side.add_child(b)
		_nav[s[0]] = b
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.add_child(sp)
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


func _nav_button(text: String, icon_name: String) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.icon = MenuWidgets.icon(icon_name)
	b.expand_icon = false
	b.toggle_mode = true
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
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("icon_normal_color", UiTheme.GOLD)
	b.add_theme_color_override("icon_hover_color", Color(1, 0.92, 0.65))
	b.add_theme_color_override("icon_pressed_color", Color(1, 0.92, 0.65))
	b.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	return b


## Affiche une section ; Grimoire et Classe s'ouvrent par-dessus la section courante.
func show_section(id: String) -> void:
	if id == "talents":
		id = "class"  # anciens raccourcis : les talents sont dans la page Classe
	match id:
		"grimoire":
			grimoire.open(_cls())
		_:
			current = id
			for k in _pages:
				_pages[k].visible = k == current
			refresh()
	for k in _nav:
		_nav[k].set_pressed_no_signal(k == current)
	_help_button.set_pressed_no_signal(current == "help")


func _cls() -> String:
	return Run.class_id if Profile.in_run else Profile.selected_class


func refresh() -> void:
	var cid := _cls()
	var cd := GameData.class_data(cid)
	_class_icon.texture = UiTheme.texture(String(cd.get("icon", "")))
	_class_name.text = "%s   ▾" % cd.get("name_fr", cid)
	_class_name.add_theme_color_override("font_color", ClassPicker.tier_color(cid))
	var zone := GameData.zone(Run.zone_id if Profile.in_run else Profile.selected_zone)
	_class_level.text = ("Niv. %d" % page.player.level) if page.player else "Maîtrise niv. %d" % Profile.expertise_level(cid)
	_zone_name.text = String(zone.get("name", ""))
	_zone_level.text = "Niv. %d+" % (1 + int(zone.get("level_bonus", 0)))
	_zone_thumb.texture = zone_texture
	_zone_thumb.visible = zone_texture != null
	var free := Profile.talent_points(cid) - Profile.talent_spent(cid)
	_nav["class"].text = "  Classe" + ("  (%d)" % free if free > 0 else "")
	_subtitle.text = {"equipment": "Équipement, coffre commun et statistiques de la classe.",
		"class": "Sorts de la classe, parcours de maîtrise, talents et certificats (7 au plus).",
		"appearance": "Tenue, tête, dos, auras et apparence de l'arme portée.",
		"cards": "Cartes de build : celles qui sont débloquées, et l'exploit qui débloque les autres.",
		"help": "Comment chaque statistique est calculée."}.get(current, "")
	var p: Control = _pages.get(current)
	if p and p.has_method("refresh"):
		p.refresh()


## Test (--class-menu) : ouvre le menu des classes sous la carte de la classe.
func _test_class_menu() -> void:
	var cc: Control = _class_icon.get_parent().get_parent()
	HeroPages.class_menu(cc, _cls(), func(_c): pass)


func is_open() -> bool:
	return _root != null and _root.visible


func open(section := "") -> void:
	_root.visible = true
	if pause_game:
		get_tree().paused = true
	show_section(section if section != "" else current)


func close_ui() -> void:
	if not is_open():
		return
	_root.visible = false
	if pause_game:
		get_tree().paused = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or grimoire.is_open():
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if current == "help":
			show_section("equipment")
		else:
			close_ui()
