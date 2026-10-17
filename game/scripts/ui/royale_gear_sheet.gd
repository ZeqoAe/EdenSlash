class_name RoyaleGearSheet
extends CanvasLayer
## Battle royale : fiche d'équipement d'un héros (lot BR3) et fenêtre de pile de sa dépouille (lot BR-I2), une seule fenêtre.
##   - Inspection (adversaire en vie suivi en spectateur, ou dépouille quand on ne peut plus rien prendre) : les 9
##     emplacements en grille (icône, couleur de rareté, +N) ; la pièce désignée en carte d'objet à droite, comparée à la
##     tienne, avec où elle est (arme gardée, dans la dépouille, déjà prise, portée).
##   - Pile (dépouille, joueur debout) : chaque pièce encore dans la dépouille porte ▲ (meilleure que la tienne) ou ▼ ;
##     « Prendre » (bouton, [F]) porte la pièce désignée, la tienne rejoint la dépouille ; « Tout le meilleur » (X, [G])
##     prend d'un coup toutes celles qui battent les tiennes.
## Jeu en pause tant qu'elle est ouverte (comme le choix de carte : partie solo contre des héros scriptés) ; B / Échap ou
## « Fermer » la ferment. Tout se fait à la manette (UiNav).
##
## [param rec] (RoyaleDirector.record_of / fallen) : {name, title?, cid, lv, kills, place (0 : en vie), gear: emplacement ->
## pièce portée à sa mort, bag?: Interactable (sa dépouille, RoyaleLoot.make_bag)} ; [param take] : prise d'une pièce
## (Callable(item)), vide en inspection.

signal closed

const SLOT_W := 132.0
const SLOT_H := 104.0
const CARD_W := 430.0

var rec: Dictionary = {}
var take: Callable
var slot_buttons: Dictionary = {}  # emplacement -> Button
var close_button: Button
var take_button: Button  # « Prendre » (pile seulement, pièce désignée dans la dépouille)
var best_button: Button  # « Tout le meilleur » (pile seulement)
var selected := ""
var _detail: VBoxContainer
var _root: Control
var _panel_box: VBoxContainer
var _sub: Label
var _prev: Control
var _done := false


static func open(host: Node, record: Dictionary, p_take := Callable()) -> RoyaleGearSheet:
	var s := RoyaleGearSheet.new()
	s.rec = record
	s.take = p_take
	host.add_child(s)
	return s


func is_open() -> bool:
	return not _done and is_inside_tree()


## Fenêtre de pile (on peut prendre des pièces) ?
func pile_mode() -> bool:
	return take.is_valid() and bag() != null


func bag() -> Interactable:
	var b = rec.get("bag")
	return b if b != null and is_instance_valid(b) else null


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(CardPicker.PAUSE_GROUP)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(RoyaleStyle.INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", RoyaleStyle.paper(Vector2(24, 18)))
	center.add_child(panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 12)
	panel.add_child(_panel_box)
	selected = _first_slot()
	_build()
	if is_instance_valid(UiNav.cursor):
		_prev = UiNav.cursor
	UiNav.focus(slot_buttons.get(selected, close_button))
	get_tree().paused = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.14)


## Emplacement montré à l'ouverture : la meilleure pièce à prendre, sinon la première pièce.
func _first_slot() -> String:
	if pile_mode():
		var ups := RoyaleLoot.bag_upgrades(bag(), Profile.equipped, Run.class_id, Run.hero_level)
		if not ups.is_empty():
			return String(ups[0].slot)
		var items := RoyaleLoot.bag_items(bag())
		if not items.is_empty():
			return String(items[0].slot)
	for s in RoyaleLoot.SLOTS:
		if not (rec.get("gear", {}) as Dictionary).get(s, {}).is_empty():
			return String(s)
	return String(RoyaleLoot.SLOTS[0])


func _build() -> void:
	for c in _panel_box.get_children():
		_panel_box.remove_child(c)
		c.queue_free()
	slot_buttons.clear()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	_panel_box.add_child(head)
	var t := RoyaleStyle.label(head, title_text(rec), 26, RoyaleStyle.INK, "title", 0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	RoyaleStyle.pill(head, subtitle(rec), RoyaleStyle.PAPER_200, 15).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if pile_mode():
		var n := RoyaleLoot.bag_items(bag()).size()
		_sub = RoyaleStyle.label(_panel_box, "Dans sa dépouille : %d pièce%s. ▲ : mieux que la tienne." % [n, "s" if n > 1 else ""] if n > 0
			else "Sa dépouille est vide.", 16, RoyaleStyle.INK_300, "bold", 0)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	_panel_box.add_child(body)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for s in RoyaleLoot.SLOTS:
		var b := _slot_button(String(s))
		grid.add_child(b)
		slot_buttons[s] = b
	_detail = VBoxContainer.new()
	_detail.custom_minimum_size = Vector2(CARD_W, 0)
	_detail.add_theme_constant_override("separation", 8)
	body.add_child(_detail)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 12)
	_panel_box.add_child(foot)
	best_button = null
	if pile_mode():
		var ups := RoyaleLoot.bag_upgrades(bag(), Profile.equipped, Run.class_id, Run.hero_level).size()
		best_button = RoyaleStyle.button("Tout le meilleur%s" % (" (%d)" % ups if ups > 0 else ""), "sun", "X", 52.0)
		best_button.custom_minimum_size.x = 280
		best_button.tooltip_text = "Prend toutes les pièces qui battent les tiennes [%s]" % Settings.action_label("quick_equip", 1)
		best_button.disabled = ups == 0
		best_button.pressed.connect(take_all_best)
		foot.add_child(best_button)
	close_button = RoyaleStyle.button("Fermer", "paper", "B", 52.0)
	close_button.custom_minimum_size.x = 160
	close_button.pressed.connect(close)
	foot.add_child(close_button)
	select(selected)


## Titre : « Paladin · niv. 14 » (ta dépouille : « Ta dépouille »).
static func title_text(r: Dictionary) -> String:
	if String(r.get("title", "")) != "":
		return String(r.title)
	return "%s · niv. %d" % [String(r.get("name", "?")), int(r.get("lv", 1))]


## Ligne sous le titre : place et éliminations (ou « En vie »).
static func subtitle(r: Dictionary) -> String:
	if bool(r.get("own", false)):
		return "Tes pièces"
	var k := int(r.get("kills", 0))
	var kills := "aucune élimination" if k == 0 else "%d élimination%s" % [k, "s" if k > 1 else ""]
	var place := int(r.get("place", 0))
	return ("En vie · %s" % kills) if place <= 0 else ("%de · %s" % [place, kills])


## Pièce montrée pour l'emplacement [param slot] : celle de la dépouille, sinon celle qu'il portait.
func item_at(slot: String) -> Dictionary:
	var b := bag()
	if b != null:
		var it := RoyaleLoot.bag_item(b, slot)
		if not it.is_empty():
			return it
	return (rec.get("gear", {}) as Dictionary).get(slot, {})


func in_bag(slot: String) -> bool:
	return bag() != null and not RoyaleLoot.bag_item(bag(), slot).is_empty()


## Où est la pièce de l'emplacement [param slot] : portée (héros en vie), arme gardée, dans la dépouille, déjà prise.
func where(slot: String) -> String:
	if int(rec.get("place", 0)) <= 0 and not bool(rec.get("own", false)):
		return "Portée"
	if slot == "weapon":
		return "Arme : elle ne tombe pas"
	if in_bag(slot):
		return "Dans sa dépouille" if not bool(rec.get("own", false)) else "Dans ta dépouille"
	return "Déjà prise"


## Comparaison de la pièce de la dépouille avec la tienne : 1 (▲ mieux), -1 (▼ moins bien), 0 (pas dans la dépouille).
func compare(slot: String) -> int:
	if not in_bag(slot):
		return 0
	return 1 if RoyaleLoot.better(item_at(slot), Profile.equipped, Run.class_id, Run.hero_level) else -1


func _slot_button(slot: String) -> Button:
	var it := item_at(slot)
	# pièce qui n'est plus là (déjà prise) ; l'arme, gardée par son porteur, est grisée sans pastille
	var gone := not it.is_empty() and bag() != null and not in_bag(slot) and (int(rec.get("place", 0)) > 0 or bool(rec.get("own", false)))
	var b := Button.new()
	b.set_meta("slot", slot)
	b.custom_minimum_size = Vector2(SLOT_W, SLOT_H)
	b.focus_mode = Control.FOCUS_NONE
	# case d'objet de la Bible (§ 5) : deux tons de la rareté ; vide ou déjà prise : papier / gris
	var tone := "papier2" if it.is_empty() else ("gris" if gone else RoyaleStyle.rarity_tone(it))
	var candy := tone != "papier2" and tone != "gris"
	var n := UiTheme.sticker(tone, {"shadow": 4, "pad": Vector2(4, 2)})
	var h := UiTheme.sticker(tone, {"shadow": 4, "lift": -3, "pad": Vector2(4, 2), "ink": RoyaleStyle.LAGOON_DARK, "border": 4})
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.set_meta("box", [n, h])
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(46, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = UiTheme.texture(String(it.get("icon", ""))) if not it.is_empty() else null
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1, 1, 1, 0.45 if gone else 1.0) if not it.is_empty() else Color(1, 1, 1, 0.0)
	v.add_child(icon)
	var up := int(it.get("upgrade", 0))
	var name := String(Items.SLOT_NAMES.get(slot, slot))
	var l := RoyaleStyle.label(v, (name + (" +%d" % up if up > 0 else "")) if not it.is_empty() else "%s · vide" % name, 15,
		Color.WHITE if candy else RoyaleStyle.INK, "bold", 3 if candy else 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.custom_minimum_size.x = SLOT_W - 10.0
	match compare(slot):
		1:
			_badge(b, "▲ mieux", RoyaleStyle.APPLE)
		-1:
			_badge(b, "▼ moins", RoyaleStyle.STRAWBERRY_LIGHT)
		_:
			if gone and slot != "weapon":
				_badge(b, "prise", Color("d9d3e3"))
	b.pressed.connect(func(): select(slot))
	b.mouse_entered.connect(func(): select(slot))
	return b


## Petite pastille autocollante en haut à droite d'une case (▲ mieux, ▼ moins, prise).
func _badge(on: Control, text: String, fill: Color) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", RoyaleStyle.box(fill, 9, 2, Vector2(6, 0)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = Vector2(SLOT_W - 74.0, -8.0)
	p.rotation_degrees = 6.0
	on.add_child(p)
	RoyaleStyle.label(p, text, 14, RoyaleStyle.INK, "bold", 0)


## Montre la pièce de [param slot] à droite (avec « Prendre » si elle est dans la dépouille).
func select(slot: String) -> void:
	selected = slot
	for c in _detail.get_children():
		_detail.remove_child(c)
		c.queue_free()
	for s in slot_buttons:
		var bx: Array = (slot_buttons[s] as Button).get_meta("box")
		(slot_buttons[s] as Button).add_theme_stylebox_override("normal", bx[1] if s == slot else bx[0])
	take_button = null
	var it := item_at(slot)
	if it.is_empty():
		RoyaleStyle.label(_detail, "%s : rien de porté" % Items.SLOT_NAMES.get(slot, slot), 16, RoyaleStyle.INK_300, "bold", 0)
		return
	var w := RoyaleStyle.label(_detail, where(slot), 17, RoyaleStyle.GAIN_ON_PAPER if in_bag(slot) else RoyaleStyle.INK_300, "bold", 0)
	w.name = "Where"
	var card := ItemWidgets.item_card(it, "", 0)
	card.custom_minimum_size = Vector2(CARD_W, 0)
	_detail.add_child(card)
	if pile_mode() and in_bag(slot):
		var cmp := compare(slot)
		take_button = RoyaleStyle.button("Prendre" if cmp > 0 else "Prendre quand même", "apple" if cmp > 0 else "paper", "", 48.0)
		take_button.tooltip_text = "Tu la portes tout de suite ; ta pièce reste dans la dépouille [%s]" % Settings.action_label("interact", 1)
		take_button.pressed.connect(func(): take_selected())
		_detail.add_child(take_button)


## « Prendre » : la pièce désignée (si elle est dans la dépouille).
func take_selected() -> void:
	if not pile_mode() or not in_bag(selected):
		return
	take.call(item_at(selected))
	_after_take()


## « Tout le meilleur » : toutes les pièces de la dépouille qui battent les tiennes ; renvoie leur nombre.
func take_all_best() -> int:
	if not pile_mode():
		return 0
	var n := 0
	for i in RoyaleLoot.SLOTS.size():
		var ups := RoyaleLoot.bag_upgrades(bag(), Profile.equipped, Run.class_id, Run.hero_level)
		if ups.is_empty():
			break
		take.call(ups[0])
		n += 1
	if n > 0:
		Sfx.ui("confirm", -6.0)
		_after_take()
	return n


func _after_take() -> void:
	_build()
	UiNav.focus(best_button if best_button != null and not best_button.disabled else slot_buttons.get(selected, close_button))


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
	elif pile_mode() and ((event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X)
			or (event is InputEventKey and event.is_action_pressed("quick_equip"))):
		get_viewport().set_input_as_handled()
		take_all_best()
	elif pile_mode() and event is InputEventKey and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		take_selected()
