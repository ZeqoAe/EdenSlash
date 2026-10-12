class_name VillageUI
extends CanvasLayer
## Interface des PNJ du village : vendre, désassembler, améliorer, boutique.
## Alec ouvre « Vendre », Bryson « Améliorer », Abel « Boutique ».

const ACCENT := Color(0.98, 0.78, 0.35)
const TABS := ["Vendre", "Désassembler", "Améliorer", "Boutique"]
const TAB_OF := {"merchant": 0, "smith": 2, "trader": 3}

var player: Player
var director: RunDirector
var offers: Array = []  # offres de la boutique pour la run

var _root: Control
var _tab := 0
var _tab_buttons: Array[Button] = []
var _list: GridContainer
var _detail: RichTextLabel
var _action: Button
var _wallet: Label
var _title: Label
var _selected = null  # objet ou offre sélectionné


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud.style(Color(0.07, 0.06, 0.12, 0.97)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-520, -320)
	panel.custom_minimum_size = Vector2(1040, 640)
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	_title = Hud._label(top, "Village", 24, ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wallet = Hud._label(top, "", 16, Color.WHITE)
	var close := Button.new()
	close.text = "Fermer (Échap)"
	close.pressed.connect(close_ui)
	top.add_child(close)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for i in TABS.size():
		var b := Button.new()
		b.text = TABS[i]
		b.custom_minimum_size = Vector2(170, 40)
		b.toggle_mode = true
		b.pressed.connect(_set_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	_list = GridContainer.new()
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 8)
	_list.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("normal_font_size", 16)
	right.add_child(_detail)
	_action = Button.new()
	_action.custom_minimum_size = Vector2(0, 52)
	_action.add_theme_font_size_override("font_size", 18)
	_action.add_theme_stylebox_override("normal", Hud.style(Color(0.2, 0.15, 0.32)))
	_action.add_theme_stylebox_override("hover", Hud.style(Color(0.3, 0.22, 0.45)))
	_action.pressed.connect(_do_action)
	right.add_child(_action)
	_root.visible = false
	add_child(_root)


func is_open() -> bool:
	return _root.visible


func open(kind: String, npc_name: String) -> void:
	if offers.is_empty():
		_roll_offers()
	_title.text = npc_name
	_root.visible = true
	get_tree().paused = true
	_set_tab(TAB_OF.get(kind, 0))


func close_ui() -> void:
	_root.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("pause"):
		close_ui()
		get_viewport().set_input_as_handled()


func _set_tab(i: int) -> void:
	_tab = i
	for k in _tab_buttons.size():
		_tab_buttons[k].button_pressed = k == i
	_selected = null
	_refresh()


func _refresh() -> void:
	_wallet.text = "Or %d   ·   Fragments %d   ·   Essences %d   ·   Cristaux %d" % [
		Profile.gold, Profile.materials.fragment, Profile.materials.essence, Profile.materials.crystal]
	for c in _list.get_children():
		c.queue_free()
	var entries: Array = offers if _tab == 3 else (Profile.all_items() if _tab == 2 else Profile.inventory)
	for e in entries:
		_list.add_child(_entry_button(e))
	if entries.is_empty():
		Hud._label(_list, "Rien ici pour l'instant.", 15, Color(0.75, 0.75, 0.8))
	_refresh_detail()


func _entry_button(e: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(270, 58)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.expand_icon = true
	var is_offer := _tab == 3
	var item: Dictionary = e.get("item", {}) if is_offer else e
	var color := Color(1, 1, 1)
	if not item.is_empty():
		color = Items.RARITIES[int(item.rarity)].color
		b.text = Items.display_name(item)
		if Profile.equipped.values().has(item):
			b.text += "  (porté)"
	else:
		b.text = e.card.title
		color = CardPicker.TYPE_COLORS.get(e.card.type, ACCENT)
	if is_offer:
		b.text += "\n%d or%s" % [e.price, "  ✔ acheté" if e.get("sold", false) else ""]
	var icon_path := String(item.get("icon", e.get("card", {}).get("icon", "")))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
	var sb := Hud.style(Color(0.12, 0.1, 0.18, 0.95))
	sb.border_color = color
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.18, 0.32)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_color_override("font_color", color)
	b.pressed.connect(func():
		_selected = e
		_refresh_detail())
	return b


func _refresh_detail() -> void:
	_action.disabled = true
	if _selected == null:
		_detail.text = ["Choisis un objet à vendre.", "Choisis un objet à désassembler en matériaux.",
			"Choisis un objet à améliorer (+1 à +10). Aux paliers +4, +6, +8 et +10, une stat aléatoire est renforcée.",
			"Offres de la boutique pour cette run."][_tab]
		_action.text = "—"
		return
	match _tab:
		0:
			_detail.text = Items.describe(_selected) + "\n\nPrix de vente : [b]%d or[/b]" % Items.sell_price(_selected)
			_action.text = "Vendre"
			_action.disabled = false
		1:
			_detail.text = Items.describe(_selected) + "\n\nDonne : " + _materials_text(Items.disassemble_yield(_selected))
			_action.text = "Désassembler"
			_action.disabled = false
		2:
			var up := int(_selected.get("upgrade", 0))
			if up >= Items.MAX_UPGRADE:
				_detail.text = Items.describe(_selected) + "\n\n[b]Amélioration maximale atteinte.[/b]"
				_action.text = "Max"
				return
			var cost := Items.upgrade_cost(_selected)
			_detail.text = Items.describe(_selected) + "\n\nAmélioration +%d → +%d\nCoût : %s" % [up, up + 1, _materials_text(cost)]
			_action.text = "Améliorer"
			_action.disabled = not Profile.can_afford(cost)
		3:
			var o: Dictionary = _selected
			_detail.text = (Items.describe(o.item) if o.has("item") else "[b]%s[/b]\n%s\n\n%s" % [o.card.title, o.card.subtitle, o.card.desc]) + "\n\nPrix : [b]%d or[/b]" % o.price
			_action.text = "Déjà acheté" if o.get("sold", false) else "Acheter"
			_action.disabled = o.get("sold", false) or Profile.gold < int(o.price)


func _materials_text(m: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in m:
		parts.append("%d %s" % [int(m[k]), "or" if k == "gold" else Items.MATERIALS.get(k, k)])
	return ", ".join(parts)


func _do_action() -> void:
	if _selected == null:
		return
	match _tab:
		0:
			var price := Profile.sell(_selected)
			director.message.emit("Vendu : +%d or" % price, 1.5)
			_selected = null
		1:
			var y := Profile.disassemble(_selected)
			director.message.emit("Désassemblé : %s" % _materials_text(y), 1.8)
			_selected = null
		2:
			var s := Profile.upgrade_item(_selected)
			if s == "!":
				return
			var msg := "%s amélioré en +%d !" % [_selected.name, int(_selected.upgrade)]
			if s != "":
				msg += "\nPalier : %s renforcé" % Items.STAT_NAMES.get(s, s)
			director.message.emit(msg, 2.2)
			player.recalc_stats()
		3:
			_buy(_selected)
	_refresh()


func _buy(o: Dictionary) -> void:
	if o.get("sold", false) or Profile.gold < int(o.price):
		return
	if o.has("item"):
		if not Profile.buy(o.item, int(o.price)):
			director.message.emit("Inventaire plein", 1.5)
			return
	else:
		Profile.gold -= int(o.price)
		Profile.save_profile()
		Run.apply_card(o.card)
	o["sold"] = true
	director.message.emit("Acheté !", 1.2)


## 6 offres : compétences (si les 4 ne sont pas trouvées), améliorations,
## passifs, et équipement rare ou épique du niveau de la zone.
func _roll_offers() -> void:
	offers.clear()
	var lvl := player.level
	var cards := Run.roll_cards(4)
	for c in cards:
		var base: int = {"skill": 60, "upgrade": 50, "passive": 70}.get(c.type, 60)
		offers.append({"card": c, "price": int(base + 14 * lvl)})
	while offers.size() < 6:
		var item := Items.generate(lvl + 1, 0.4, "", Run.class_id, 2)
		offers.append({"item": item, "price": Items.buy_price(item)})
