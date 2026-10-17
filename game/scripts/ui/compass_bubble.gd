class_name CompassBubble
extends PanelContainer
## Bulle « Ta quête » du menu principal (lot HUB-1, P0-3 : boussole v2) : le conseil de Compass avec son pourquoi en une
## ou deux phrases, le bouton « Y aller », puis « Ou bien : » et deux autres conseils de familles différentes
## (Compass.advices). Un clic émet [signal go] avec la page où aller (le lobby l'ouvre, `Lobby._compass_open`).
## Remplace la pilule du haut de l'écran (une seule bulle par écran, bible § 8). Habillage provisoire (puits sombre, or) : à
## rhabiller avec UiTheme v2 (bulle autocollant, queue vers le héros) au lot UIK.

signal go(where: Dictionary)

const W := 352.0

var go_button: Button
var alt_buttons: Array[Button] = []
var advice: Dictionary = {}
var _icon: TextureRect
var _title: Label
var _why: Label
var _alts: VBoxContainer
var _alt_head: Label


func _init() -> void:
	custom_minimum_size = Vector2(W, 0)
	UiTheme.paper(self, 5, Vector2(12, 8), 16)  # bulle papier autocollant (UIK1, bible § 8 : avis du menu en bulle)
	mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(30, 30)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_icon)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	var kick := Hud._label(tv, "Ta quête", 13, UiTheme.GOLD)
	kick.add_theme_font_override("font", UiTheme.bold_font())
	_title = Hud._label(tv, "", 16, Color(1, 0.97, 0.9))
	_title.add_theme_font_override("font", UiTheme.bold_font())
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(W - 80.0, 0)
	_why = Hud._label(v, "", 14, UiTheme.MUTED)
	_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_why.max_lines_visible = 3
	_why.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_why.custom_minimum_size = Vector2(W - 30.0, 0)
	go_button = MenuWidgets.gold_button("Y aller", 18, Vector2(0, 40))
	go_button.pressed.connect(func(): go.emit(advice.get("go", {})))
	v.add_child(go_button)
	_alts = VBoxContainer.new()
	_alts.add_theme_constant_override("separation", 4)
	v.add_child(_alts)
	_alt_head = Hud._label(_alts, "Ou bien :", 13, UiTheme.MUTED)
	visible = false


## Montre les conseils [param list] (Compass.advices : le premier en grand, les autres en « Ou bien ») ; vide : cachée.
## [param compact] : un seul autre choix (petite fenêtre).
func show_advices(list: Array, compact := false) -> void:
	visible = not list.is_empty()
	if list.is_empty():
		advice = {}
		return
	advice = list[0]
	_title.text = String(advice.text)
	_why.text = String(advice.get("tip", ""))
	_why.visible = _why.text != ""
	var ic := String(advice.get("icon", ""))
	_icon.texture = ResourceHelp.icon(ic) if ResourceHelp.has(ic) else MenuWidgets.icon("pin")
	tooltip_text = "%s\n%s" % [advice.text, advice.tip] if String(advice.get("tip", "")) != "" else String(advice.text)
	for b in alt_buttons:
		_alts.remove_child(b)
		b.queue_free()
	alt_buttons.clear()
	var others: Array = list.slice(1, 2 if compact else 3)
	_alts.visible = not others.is_empty()
	for a in others:
		var b := MenuWidgets.paper_button("› " + String(a.text), 14, Vector2(0, 32))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = "%s\n%s" % [a.text, a.tip] if String(a.get("tip", "")) != "" else String(a.text)
		var where: Dictionary = a.get("go", {})
		b.pressed.connect(func(): go.emit(where))
		_alts.add_child(b)
		alt_buttons.append(b)
