class_name RoyaleGearSheet
extends CanvasLayer
## Battle royale (lot BR3) : fiche d'équipement d'un adversaire, ouverte près de sa dépouille ([F]) ou, en spectateur,
## sur le héros suivi. Les 9 emplacements en grille (icône, couleur de rareté, +N) ; la pièce désignée s'affiche en
## carte d'objet à droite (comparée à la tienne), avec où elle est : arme gardée, pièce au sol, déjà ramassée.
## Jeu en pause tant qu'elle est ouverte ; B / Échap ou « Fermer » la ferment. Tout se fait à la manette (UiNav).
##
## [param rec] (RoyaleDirector.record_of) : {name, cid, lv, kills, place (0 : en vie), gear: emplacement -> pièce,
## drops: emplacement -> Interactable au sol}.

signal closed

const SLOT_W := 132.0
const SLOT_H := 104.0
const CARD_W := 430.0

var rec: Dictionary = {}
var slot_buttons: Dictionary = {}  # emplacement -> Button
var close_button: Button
var _detail: VBoxContainer
var _root: Control
var _prev: Control
var _done := false


static func open(host: Node, record: Dictionary) -> RoyaleGearSheet:
	var s := RoyaleGearSheet.new()
	s.rec = record
	host.add_child(s)
	return s


func is_open() -> bool:
	return not _done and is_inside_tree()


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(CardPicker.PAUSE_GROUP)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(24, 18))
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var t := Label.new()
	t.text = "%s · niv. %d" % [String(rec.get("name", "?")), int(rec.get("lv", 1))]
	UiTheme.title(t, 26)
	v.add_child(t)
	var sub := Label.new()
	sub.text = subtitle(rec)
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	v.add_child(sub)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	v.add_child(body)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	var first: Button = null
	for s in RoyaleLoot.SLOTS:
		var b := _slot_button(String(s))
		grid.add_child(b)
		slot_buttons[s] = b
		if first == null and not (rec.get("gear", {}) as Dictionary).get(s, {}).is_empty():
			first = b
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(CARD_W, 0)
	_detail.add_theme_constant_override("separation", 8)
	body.add_child(_detail)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(foot)
	close_button = InfoCard._small_button("Fermer", "primary", 36.0)
	close_button.custom_minimum_size.x = 140
	close_button.pressed.connect(close)
	foot.add_child(close_button)
	select(String(RoyaleLoot.SLOTS[0]) if first == null else String(first.get_meta("slot")))
	if is_instance_valid(UiNav.cursor):
		_prev = UiNav.cursor
	UiNav.focus(first if first != null else close_button)
	get_tree().paused = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.14)


## Ligne sous le titre : éliminations et place (ou « En vie »).
static func subtitle(r: Dictionary) -> String:
	var k := int(r.get("kills", 0))
	var kills := "aucune élimination" if k == 0 else "%d élimination%s" % [k, "s" if k > 1 else ""]
	var place := int(r.get("place", 0))
	return ("En vie · %s" % kills) if place <= 0 else ("%de · %s" % [place, kills])


## Où est la pièce de l'emplacement [param slot] : gardée (arme), au sol, ramassée, portée (héros en vie).
func where(slot: String) -> String:
	if int(rec.get("place", 0)) <= 0:
		return "Portée"
	if slot == "weapon":
		return "Arme : elle ne tombe pas"
	var node = (rec.get("drops", {}) as Dictionary).get(slot)
	if node != null and is_instance_valid(node) and node.is_inside_tree():
		return "Au sol, près de sa dépouille"
	return "Déjà ramassée"


func _slot_button(slot: String) -> Button:
	var it: Dictionary = (rec.get("gear", {}) as Dictionary).get(slot, {})
	var b := Button.new()
	b.set_meta("slot", slot)
	b.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
	b.focus_mode = Control.FOCUS_NONE
	var col := Items.color_of(it) if not it.is_empty() else Color(0.4, 0.38, 0.5)
	var n := UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.96), col, 2, 10, false)
	var h := UiTheme.flat_box(Color(0.15, 0.12, 0.26, 1.0), col.lightened(0.3), 3, 10, false)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", h)
	b.set_meta("box", [n, h])
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = UiTheme.texture(String(it.get("icon", ""))) if not it.is_empty() else null
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if it.is_empty():
		icon.modulate = Color(1, 1, 1, 0.0)
	v.add_child(icon)
	var l := Label.new()
	var up := int(it.get("upgrade", 0))
	l.text = String(Items.SLOT_NAMES.get(slot, slot)) + (" +%d" % up if up > 0 else "") if not it.is_empty() else "%s · vide" % Items.SLOT_NAMES.get(slot, slot)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
	l.add_theme_color_override("font_color", col.lightened(0.2) if not it.is_empty() else UiTheme.MUTED)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.pressed.connect(func(): select(slot))
	b.mouse_entered.connect(func(): select(slot))
	return b


## Montre la pièce de [param slot] à droite.
func select(slot: String) -> void:
	for c in _detail.get_children():
		c.queue_free()
	for s in slot_buttons:
		var bx: Array = (slot_buttons[s] as Button).get_meta("box")
		(slot_buttons[s] as Button).add_theme_stylebox_override("normal", bx[1] if s == slot else bx[0])
	var it: Dictionary = (rec.get("gear", {}) as Dictionary).get(slot, {})
	if it.is_empty():
		var l := Label.new()
		l.text = "%s : rien de porté" % Items.SLOT_NAMES.get(slot, slot)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_color", UiTheme.MUTED)
		_detail.add_child(l)
		return
	var w := Label.new()
	w.text = where(slot)
	w.add_theme_font_size_override("font_size", 16)
	w.add_theme_font_override("font", UiTheme.bold_font())
	w.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6) if w.text.begins_with("Au sol") else UiTheme.GOLD)
	_detail.add_child(w)
	var card := ItemWidgets.item_card(it, "", 0)
	card.custom_minimum_size = Vector2(CARD_W, 0)
	_detail.add_child(card)


func close() -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_prev) and _prev.is_visible_in_tree():
		UiNav.focus(_prev)
	elif Gamepad.active:
		UiNav.cursor = null
	get_tree().paused = CardPicker.pause_held(get_tree(), self)
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") \
			or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
		get_viewport().set_input_as_handled()
		close()
