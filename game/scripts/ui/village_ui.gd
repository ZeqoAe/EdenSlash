class_name VillageUI
extends CanvasLayer
## Interface des PNJ du village : vendre, désassembler, améliorer, boutique.
## Alec ouvre « Vendre », Bryson « Améliorer », Abel « Boutique ».
## Vendre / désassembler : sélection multiple (clic, Ctrl+clic, Maj+clic, Ctrl+A),
## filtres par rareté et type de pièce, tri, actions groupées.

const ACCENT := Color(0.98, 0.78, 0.35)
const TABS := ["Vendre", "Désassembler", "Améliorer", "Boutique"]
const TAB_OF := {"merchant": 0, "smith": 2, "trader": 3}
const SORTS := ["Rareté", "Niveau", "Type", "Valeur"]
const MUTED := Color(0.72, 0.72, 0.8)

var player: Player
var director: RunDirector
var offers: Array = []  # offres de la boutique pour la run

var _root: Control
var _tab := 0
var _tab_buttons: Array[Button] = []
var _list: GridContainer
var _detail: RichTextLabel
var _action: Button
var _wallet := {}  # ressource -> Label
var _title: Label
var _toolbar: HBoxContainer
var _bulk_row: HBoxContainer
var _rarity_filter: OptionButton
var _slot_filter: OptionButton
var _sort: OptionButton
var _count: Label
var _hint: Label
var _bulk_all: Button
var _selected = null  # objet ou offre affiché (améliorer / boutique)
var _selection: Array = []  # objets sélectionnés (vendre / désassembler)
var _shown: Array = []  # entrées visibles après filtre et tri
var _anchor := -1  # point de départ de Maj+clic
var _confirm_at := -10.0  # confirmation de l'action « tout » (2 clics en 3 s)


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Hud.style(Color(0.07, 0.06, 0.12, 0.97)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-640, -370)
	panel.custom_minimum_size = Vector2(1280, 740)
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	# en-tête : nom du PNJ, bourse, fermer
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	_title = Hud._label(top, "Village", 26, ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# bourse : icônes d'Eden + quantités
	for k in ["gold", "fragment", "essence", "crystal"]:
		var ic := TextureRect.new()
		var path := Items.material_icon(k)
		if path != "" and ResourceLoader.exists(path):
			ic.texture = load(path)
		ic.custom_minimum_size = Vector2(28, 28)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.tooltip_text = "Or" if k == "gold" else Items.MATERIALS[k]
		top.add_child(ic)
		var l := Hud._label(top, "0", 17, Color.WHITE)
		l.custom_minimum_size = Vector2(54, 0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_wallet[k] = l
	var close := _button("✕  Fermer (Échap)", Color(0.25, 0.12, 0.16))
	close.pressed.connect(close_ui)
	top.add_child(close)

	# onglets
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for i in TABS.size():
		var b := _button(TABS[i], Color(0.13, 0.11, 0.2))
		b.custom_minimum_size = Vector2(180, 42)
		b.toggle_mode = true
		var on := Hud.style(Color(0.32, 0.24, 0.12))
		on.border_color = ACCENT
		b.add_theme_stylebox_override("pressed", on)
		b.pressed.connect(_set_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	v.add_child(body)

	# colonne gauche : filtres, liste, actions groupées
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(780, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 8)
	left.add_child(_toolbar)
	Hud._label(_toolbar, "Rareté", 14, MUTED)
	_rarity_filter = _option(["Toutes"] + Items.RARITIES.map(func(r): return r.name))
	for i in Items.RARITIES.size():
		_rarity_filter.set_item_icon(i + 1, _dot(Items.RARITIES[i].color))
	Hud._label(_toolbar, "Type", 14, MUTED)
	_slot_filter = _option(["Tous"] + Items.SLOTS.map(func(s): return Items.SLOT_NAMES[s]))
	Hud._label(_toolbar, "Tri", 14, MUTED)
	_sort = _option(SORTS)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar.add_child(spacer)
	_count = Hud._label(_toolbar, "", 14, MUTED)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = GridContainer.new()
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 8)
	_list.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_list)

	_bulk_row = HBoxContainer.new()
	_bulk_row.add_theme_constant_override("separation", 8)
	left.add_child(_bulk_row)
	for spec in [["Tout sélectionner", _select_all], ["Communs", _select_max_rarity.bind(0)],
			["Jusqu'à Magique", _select_max_rarity.bind(1)], ["Aucun", _clear_selection]]:
		var b := _button(spec[0], Color(0.13, 0.11, 0.2))
		b.pressed.connect(spec[1])
		_bulk_row.add_child(b)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bulk_row.add_child(spacer2)
	_bulk_all = _button("", Color(0.35, 0.14, 0.12))
	_bulk_all.pressed.connect(_do_all)
	_bulk_row.add_child(_bulk_all)
	_hint = Hud._label(left, "Clic : choisir   ·   Ctrl+clic : ajouter / retirer   ·   Maj+clic : plage   ·   Ctrl+A : tout le filtre", 13, MUTED)

	# colonne droite : détail et action
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	var detail_panel := PanelContainer.new()
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", Hud.style(Color(0.1, 0.08, 0.16, 0.9)))
	right.add_child(detail_panel)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.add_theme_font_size_override("normal_font_size", 16)
	_detail.add_theme_font_size_override("bold_font_size", 16)
	detail_panel.add_child(_detail)
	_action = _button("", Color(0.2, 0.15, 0.32))
	_action.custom_minimum_size = Vector2(0, 56)
	_action.add_theme_font_size_override("font_size", 18)
	_action.pressed.connect(_do_action)
	right.add_child(_action)
	_root.visible = false
	add_child(_root)


func _button(text: String, bg: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_stylebox_override("normal", Hud.style(bg))
	var hover := Hud.style(bg.lightened(0.18))
	hover.border_color = ACCENT
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", Hud.style(bg.lightened(0.3)))
	b.add_theme_stylebox_override("disabled", Hud.style(Color(bg.darkened(0.4), 0.7)))
	b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
	b.focus_mode = Control.FOCUS_NONE
	return b


func _option(labels: Array) -> OptionButton:
	var o := OptionButton.new()
	for l in labels:
		o.add_item(String(l))
	o.custom_minimum_size = Vector2(140, 36)
	o.focus_mode = Control.FOCUS_NONE
	o.item_selected.connect(func(_i): _on_filter_changed())
	_toolbar.add_child(o)
	return o


## Petite pastille de couleur (icône des raretés dans le filtre).
func _dot(c: Color) -> Texture2D:
	var img := Image.create(14, 14, false, Image.FORMAT_RGBA8)
	for y in 14:
		for x in 14:
			if Vector2(x - 6.5, y - 6.5).length() < 6.0:
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


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
	if not _root.visible:
		return
	if event.is_action_pressed("pause"):
		close_ui()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_A and event.ctrl_pressed and _multi():
		_select_all()
		get_viewport().set_input_as_handled()


func _multi() -> bool:
	return _tab <= 1


func _set_tab(i: int) -> void:
	_tab = i
	for k in _tab_buttons.size():
		_tab_buttons[k].button_pressed = k == i
	_selected = null
	_selection.clear()
	_anchor = -1
	_confirm_at = -10.0
	_toolbar.visible = _tab != 3
	_bulk_row.visible = _multi()
	_hint.visible = _multi()
	_refresh()


func _on_filter_changed() -> void:
	# la sélection ne garde que ce qui reste visible
	_refresh()
	_selection = _selection.filter(func(it): return _shown.any(func(e): return is_same(e, it)))
	_refresh()


# --- liste --------------------------------------------------------------------------
func _entries() -> Array:
	if _tab == 3:
		return offers
	var items: Array = Profile.all_items() if _tab == 2 else Profile.inventory.duplicate()
	var r := _rarity_filter.selected - 1
	var slot: String = "" if _slot_filter.selected <= 0 else Items.SLOTS[_slot_filter.selected - 1]
	items = items.filter(func(it): return (r < 0 or int(it.rarity) == r) and (slot == "" or it.slot == slot))
	var key := _sort.selected
	items.sort_custom(func(a, b):
		var ka := _sort_key(a, key)
		var kb := _sort_key(b, key)
		return ka > kb if ka != kb else String(a.name) < String(b.name))
	return items


func _sort_key(it: Dictionary, key: int) -> float:
	match key:
		1:
			return float(it.level) * 10.0 + float(it.rarity)
		2:
			return -float(Items.SLOTS.find(it.slot)) * 10.0 + float(it.rarity)
		3:
			return float(Items.sell_price(it)) + 4.0 * float(int(it.get("upgrade", 0)))
	return float(it.rarity) * 1000.0 + float(it.level) * 10.0 + float(it.get("upgrade", 0))


func _refresh() -> void:
	_wallet.gold.text = str(Profile.gold)
	for k in ["fragment", "essence", "crystal"]:
		_wallet[k].text = str(int(Profile.materials.get(k, 0)))
	for c in _list.get_children():
		c.queue_free()
	_shown = _entries()
	for i in _shown.size():
		_list.add_child(_entry_button(_shown[i], i))
	if _shown.is_empty():
		var total := Profile.inventory.size() if _tab <= 1 else 1
		Hud._label(_list, "Aucun objet ne correspond aux filtres." if total > 0 and _tab != 3 else "Rien ici pour l'instant.", 15, MUTED)
	if _tab != 3:
		var n := Profile.inventory.size() if _tab <= 1 else Profile.all_items().size()
		_count.text = "%d / %d objets" % [_shown.size(), n] + ("   ·   %d sélectionné(s)" % _selection.size() if _multi() and not _selection.is_empty() else "")
	_refresh_bulk()
	_refresh_detail()


func _is_selected(e) -> bool:
	if _multi():
		return _selection.any(func(it): return is_same(it, e))
	return _selected != null and is_same(_selected, e)


func _entry_button(e: Dictionary, index: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(382, 64)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.expand_icon = false
	b.focus_mode = Control.FOCUS_NONE
	b.clip_text = true
	var is_offer := _tab == 3
	var item: Dictionary = e.get("item", {}) if is_offer else e
	var color := Color(1, 1, 1)
	var sub := ""
	if not item.is_empty():
		color = Items.RARITIES[int(item.rarity)].color
		b.text = Items.display_name(item)
		sub = "%s · %s · nv %d" % [Items.SLOT_NAMES[item.slot], Items.RARITIES[int(item.rarity)].name, int(item.level)]
		if Profile.equipped.values().any(func(x): return is_same(x, item)):
			sub += " · porté"
		match _tab:
			0:
				sub += "   ·   " + _materials_text(Items.sell_value(item), true)
			1:
				sub += "   ·   " + _materials_text(Items.disassemble_yield(item), true)
	else:
		b.text = e.card.title
		sub = String(e.card.get("subtitle", ""))
		color = CardPicker.TYPE_COLORS.get(e.card.type, ACCENT)
	if is_offer:
		sub = "%d or%s" % [e.price, "   ·   ✔ acheté" if e.get("sold", false) else ""]
	b.text = ("✔  " if _is_selected(e) else "") + b.text + "\n" + sub
	var icon_path := String(item.get("icon", e.get("card", {}).get("icon", "")))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		b.icon = load(icon_path)
		b.add_theme_constant_override("icon_max_width", 44)
	var sel := _is_selected(e)
	var sb := Hud.style(Color(0.2, 0.16, 0.3, 0.98) if sel else Color(0.11, 0.09, 0.17, 0.95))
	sb.border_color = color if sel else Color(color, 0.45)
	sb.set_border_width_all(3 if sel else 2)
	sb.border_width_left = 7
	b.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.24, 0.2, 0.34)
	hover.border_color = color
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", color.lightened(0.2))
	b.add_theme_font_size_override("font_size", 15)
	if is_offer and e.get("sold", false):
		b.modulate = Color(1, 1, 1, 0.5)
	b.pressed.connect(_on_entry_pressed.bind(e, index))
	return b


func _on_entry_pressed(e, index: int) -> void:
	_confirm_at = -10.0
	if not _multi():
		_selected = e
	elif Input.is_key_pressed(KEY_SHIFT) and _anchor >= 0 and _anchor < _shown.size():
		for i in range(mini(_anchor, index), maxi(_anchor, index) + 1):
			if not _is_selected(_shown[i]):
				_selection.append(_shown[i])
	elif Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		if _is_selected(e):
			_selection = _selection.filter(func(it): return not is_same(it, e))
		else:
			_selection.append(e)
		_anchor = index
	else:
		_selection = [e]
		_anchor = index
	_refresh()


func _select_all() -> void:
	_selection = _shown.duplicate()
	_refresh()


func _select_max_rarity(r: int) -> void:
	_selection = _shown.filter(func(it): return int(it.rarity) <= r)
	_refresh()


func _clear_selection() -> void:
	_selection.clear()
	_anchor = -1
	_refresh()


# --- détail -------------------------------------------------------------------------
func _refresh_bulk() -> void:
	if not _multi():
		return
	var verb := "vendre" if _tab == 0 else "désassembler"
	var confirming := _time() - _confirm_at < 3.0
	_bulk_all.disabled = _shown.is_empty()
	_bulk_all.text = ("Confirmer : %s %d objet(s) ?" % [verb, _shown.size()]) if confirming else ("Tout %s (%d)" % [verb, _shown.size()])


func _time() -> float:
	return Time.get_ticks_msec() / 1000.0


func _refresh_detail() -> void:
	_action.disabled = true
	if _multi():
		_detail_multi()
		return
	if _selected == null:
		_detail.text = ["", "", "[b]Améliorer[/b]\n\nChoisis un objet (+1 à +10). Chaque niveau renforce ses stats de base ; aux paliers [color=#f5c75a]+4, +6, +8 et +10[/color], une stat aléatoire est en plus renforcée.",
			"[b]Boutique[/b]\n\n6 offres pour cette run : compétences, améliorations, passifs et équipement de rareté supérieure."][_tab]
		_action.text = "Choisis un objet" if _tab == 2 else "Choisis une offre"
		return
	match _tab:
		2:
			var up := int(_selected.get("upgrade", 0))
			if up >= Items.MAX_UPGRADE:
				_detail.text = Items.describe(_selected) + "\n\n[b]Amélioration maximale atteinte.[/b]"
				_action.text = "Maximum atteint"
				return
			var cost := Items.upgrade_cost(_selected)
			var next: Dictionary = _selected.duplicate(true)
			next.upgrade = up + 1
			_detail.text = Items.describe(_selected) + "\n\n[b]+%d → +%d[/b]%s\n%s\n\nCoût : %s" % [up, up + 1,
				"   [color=#f5c75a]palier : stat bonus aléatoire[/color]" if up + 1 in Items.MILESTONES else "",
				_diff_text(Items.stats(_selected), Items.stats(next)), _cost_text(cost)]
			_action.text = "Améliorer en +%d" % (up + 1)
			_action.disabled = not Profile.can_afford(cost)
		3:
			var o: Dictionary = _selected
			_detail.text = (Items.describe(o.item) + _compare_text(o.item) if o.has("item") else "[b]%s[/b]\n%s\n\n%s" % [o.card.title, o.card.subtitle, o.card.desc]) + "\n\nPrix : [b]%d or[/b]" % o.price
			_action.text = "Déjà acheté" if o.get("sold", false) else "Acheter (%d or)" % o.price
			_action.disabled = o.get("sold", false) or Profile.gold < int(o.price)


func _detail_multi() -> void:
	var verb := "Vendre" if _tab == 0 else "Désassembler"
	if _selection.is_empty():
		_detail.text = "[b]%s[/b]\n\nClique un objet pour le voir. [color=#c8c8d4]Ctrl+clic[/color] pour en choisir plusieurs, [color=#c8c8d4]Maj+clic[/color] pour une plage, ou utilise les boutons du bas.\n\nFiltre par rareté et par type pour retrouver vite tes pièces." % verb
		_action.text = "Choisis des objets"
		return
	_action.disabled = false
	if _selection.size() == 1:
		var it: Dictionary = _selection[0]
		var refund := Items.upgrade_refund(it)
		_detail.text = Items.describe(it) + _compare_text(it) + "\n\n%s : [b]%s[/b]" % [
			"Vente" if _tab == 0 else "Donne", _materials_text(_gain(it))] + (
			"\n[color=#c8c8d4](dont 70 %% des pierres d'amélioration : %s)[/color]" % _materials_text(refund) if not refund.is_empty() else "")
		_action.text = "%s · %s" % [verb, _materials_text(_gain(it), true)]
		return
	var counts := [0, 0, 0, 0]
	var mats := {}
	for it in _selection:
		counts[int(it.rarity)] += 1
		var y := _gain(it)
		for m in y:
			mats[m] = int(mats.get(m, 0)) + int(y[m])
	var lines := ["[b]%d objets sélectionnés[/b]\n" % _selection.size()]
	for r in counts.size():
		if counts[r] > 0:
			lines.append("[color=#%s]●[/color] %d %s" % [Color(Items.RARITIES[r].color).to_html(false), counts[r], Items.RARITIES[r].name])
	lines.append("\nTotal : [b]%s[/b]" % _materials_text(mats))
	if counts[3] > 0 or counts[2] > 0:
		lines.append("\n[color=#ff9a7a]Attention : la sélection contient des objets rares ou épiques.[/color]")
	_detail.text = "\n".join(lines)
	_action.text = "%s %d objets · %s" % [verb, _selection.size(), _materials_text(mats, true)]


## Ce que rapporte un objet dans l'onglet courant (vente ou désassemblage).
func _gain(it: Dictionary) -> Dictionary:
	return Items.sell_value(it) if _tab == 0 else Items.disassemble_yield(it)


## Comparaison avec la pièce portée au même emplacement.
func _compare_text(item: Dictionary) -> String:
	var worn = Profile.equipped.get(item.slot)
	if worn == null or is_same(worn, item):
		return ""
	return "\n\n[color=#c8c8d4]Par rapport à ta pièce portée (%s) :[/color]\n%s" % [Items.display_name(worn), _diff_text(Items.stats(worn), Items.stats(item))]


func _diff_text(before: Dictionary, after: Dictionary) -> String:
	var keys := before.keys()
	for k in after:
		if not k in keys:
			keys.append(k)
	var parts: PackedStringArray = []
	for k in keys:
		var d := float(after.get(k, 0.0)) - float(before.get(k, 0.0))
		var pct: bool = k in Items.PERCENT_STATS
		var shown := roundi(d * 100.0) if pct else roundi(d)
		if shown == 0:
			continue
		parts.append("[color=%s]%s%d%s %s[/color]" % ["#7fe08a" if d > 0 else "#ff7a7a", "+" if d > 0 else "",
			shown, " %" if pct else "", Items.STAT_NAMES.get(k, k)])
	return "   ".join(parts) if not parts.is_empty() else "[color=#c8c8d4]identique[/color]"


func _cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost:
		var have := Profile.gold if k == "gold" else int(Profile.materials.get(k, 0))
		var ok := have >= int(cost[k])
		parts.append("%s[color=%s]%d %s[/color]" % [_icon_bb(k), "#ffffff" if ok else "#ff7a7a", int(cost[k]), "or" if k == "gold" else Items.MATERIALS.get(k, k)])
	return ", ".join(parts)


## Matériaux en texte : court pour les boutons, avec icônes d'Eden pour le détail.
func _materials_text(m: Dictionary, short := false) -> String:
	const SHORT := {"fragment": "frag.", "essence": "ess.", "crystal": "crist.", "gold": "or"}
	var parts: PackedStringArray = []
	for k in m:
		if short:
			parts.append("%d %s" % [int(m[k]), SHORT.get(k, k)])
		else:
			parts.append("%s%d %s" % [_icon_bb(k), int(m[k]), "or" if k == "gold" else Items.MATERIALS.get(k, k)])
	return (" " if short else ", ").join(parts)


func _icon_bb(k: String) -> String:
	var path := Items.material_icon(k)
	return "[img=20x20]%s[/img] " % path if path != "" else ""


# --- actions ------------------------------------------------------------------------
func _do_action() -> void:
	match _tab:
		0, 1:
			_apply(_selection.duplicate())
		2:
			if _selected == null:
				return
			var s := Profile.upgrade_item(_selected)
			if s == "!":
				return
			var msg := "%s amélioré en +%d !" % [_selected.name, int(_selected.upgrade)]
			if s != "":
				msg += "\nPalier : %s renforcé" % Items.STAT_NAMES.get(s, s)
			director.message.emit(msg, 2.2)
			player.recalc_stats()
		3:
			if _selected != null:
				_buy(_selected)
	_refresh()


## Bouton « Tout vendre / désassembler » : tout ce que montre le filtre, après confirmation.
func _do_all() -> void:
	if _time() - _confirm_at > 3.0:
		_confirm_at = _time()
		_refresh_bulk()
		get_tree().create_timer(3.05, true, false, true).timeout.connect(func():
			if _root.visible:
				_refresh_bulk())
		return
	_confirm_at = -10.0
	_apply(_shown.duplicate())
	_refresh()


func _apply(items: Array) -> void:
	if items.is_empty():
		return
	if _tab == 0:
		var got := Profile.sell_many(items)
		director.message.emit("%d objet(s) vendu(s) : %s" % [items.size(), _materials_text(got, true)], 1.8)
	else:
		var y := Profile.disassemble_many(items)
		director.message.emit("%d objet(s) désassemblé(s) : %s" % [items.size(), _materials_text(y)], 2.0)
	_selection.clear()
	_anchor = -1


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
