class_name ItemWidgets
extends RefCounted
## Éléments d'interface des objets : case d'objet (rareté, +N, set, gemmes,
## glisser-déposer), grille filtrable à sélection multiple, bourse, textes de
## comparaison et de coût.

const SORTS := ["Rareté", "Niveau", "Emplacement", "Valeur"]


# --- textes --------------------------------------------------------------------------------
## Comparaison avec la pièce portée au même emplacement ("" si identique ou rien de porté).
static func compare_text(item: Dictionary, worn) -> String:
	if worn == null or not (worn is Dictionary) or worn.is_empty() or is_same(worn, item):
		return ""
	return "\n\n[color=#c8c8d4]Par rapport à ta pièce portée (%s) :[/color]\n%s" % [Items.display_name(worn), diff_text(Items.stats(worn), Items.stats(item))]


static func diff_text(before: Dictionary, after: Dictionary) -> String:
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
			shown, " %" if pct else "", Items.STAT_NAMES.get(k, Items.EXTRA_STAT_NAMES.get(k, k))])
	return "   ".join(parts) if not parts.is_empty() else "[color=#c8c8d4]identique[/color]"


static func icon_bb(k: String) -> String:
	var path := Items.material_icon(k)
	return "[img=20x20]%s[/img] " % path if path != "" else ""


## Matériaux en texte : court pour les boutons, avec icônes d'Eden pour le détail.
static func materials_text(m: Dictionary, short := false) -> String:
	const SHORT := {"fragment": "frag.", "essence": "ess.", "crystal": "crist.", "gold": "or"}
	var parts: PackedStringArray = []
	for k in m:
		if short:
			parts.append("%d %s" % [int(m[k]), SHORT.get(k, k)])
		else:
			parts.append("%s%d %s" % [icon_bb(k), int(m[k]), "or" if k == "gold" else Items.MATERIALS.get(k, k)])
	return (" " if short else ", ").join(parts)


## Coût avec ce qui manque en rouge.
static func cost_text(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost:
		var have := Profile.gold if k == "gold" else int(Profile.materials.get(k, 0))
		var ok := have >= int(cost[k])
		parts.append("%s[color=%s]%d %s[/color]" % [icon_bb(k), "#ffffff" if ok else "#ff7a7a", int(cost[k]), "or" if k == "gold" else Items.MATERIALS.get(k, k)])
	return ", ".join(parts)


## Titre de section doré avec un filet.
static func section(parent: Control, text: String, size := 18) -> Label:
	var l := Label.new()
	l.text = text
	UiTheme.title(l, size)
	parent.add_child(l)
	return l


static func rich(parent: Control, size := 15) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = true
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size + 1)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(r)
	return r


## Panneau orné qui remplit son parent, avec une VBox dedans.
static func panel(parent: Control, min_width := 0.0, expand := false) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_box(18, 14))
	p.custom_minimum_size = Vector2(min_width, 0)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if expand:
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	return v


static func action_button(parent: Control, text: String, cb: Callable, min_w := 0.0, accent := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, 44)
	b.add_theme_font_size_override("font_size", 17)
	if accent:
		var sb := UiTheme.flat_box(Color(0.42, 0.28, 0.08, 1.0), UiTheme.GOLD, 2, 8)
		var hv := UiTheme.flat_box(Color(0.55, 0.37, 0.1, 1.0), Color(1, 0.9, 0.6), 2, 8)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", hv)
		b.add_theme_stylebox_override("pressed", hv)
		b.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Carte d'objet affichée au survol : description complète (stats, affixes, amélioration,
## gemmes, enchantement, set et ses effets), comparaison avec la pièce portée, [param extra].
static func item_card(item: Dictionary, extra := "") -> Control:
	var p := PanelContainer.new()
	var sb := UiTheme.flat_box(Color(0.05, 0.04, 0.09, 0.97), Items.color_of(item), 2, 10)
	sb.set_content_margin_all(14)
	p.add_theme_stylebox_override("panel", sb)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(400, 0)
	r.size = Vector2(400, 0)
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_font_size_override("bold_font_size", 16)
	var worn = Profile.equipped.get(String(item.get("slot", "")), null)
	r.text = Items.describe(item) + compare_text(item, worn) + extra
	p.add_child(r)
	return p


# --- bourse --------------------------------------------------------------------------------
class Wallet extends HBoxContainer:
	var _labels := {}

	func _init() -> void:
		add_theme_constant_override("separation", 6)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for k in ["gold", "fragment", "essence", "crystal"]:
			var ic := TextureRect.new()
			ic.texture = UiTheme.texture(Items.material_icon(k))
			ic.custom_minimum_size = Vector2(26, 26)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.tooltip_text = "Or" if k == "gold" else Items.MATERIALS[k]
			ic.mouse_filter = Control.MOUSE_FILTER_PASS
			add_child(ic)
			var l := Hud._label(self, "0", 16, Color.WHITE)
			l.custom_minimum_size = Vector2(46, 0)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_labels[k] = l

	func refresh() -> void:
		for k in _labels:
			_labels[k].text = str(Profile.gold if k == "gold" else int(Profile.materials.get(k, 0)))


## Carte d'infobulle riche (texte BBCode, cadre de couleur).
static func tip_card(bbcode: String, border := UiTheme.GOLD_DIM, width := 360.0) -> Control:
	var p := PanelContainer.new()
	var sb := UiTheme.flat_box(Color(0.05, 0.04, 0.09, 0.97), border, 2, 10)
	sb.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", sb)
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(width, 0)
	r.size = Vector2(width, 0)
	r.add_theme_font_size_override("normal_font_size", 15)
	r.add_theme_font_size_override("bold_font_size", 16)
	r.text = bbcode
	p.add_child(r)
	return p


## Bouton avec une carte riche au survol ([member tip], BBCode).
class TipButton extends Button:
	var tip := ""
	var tip_border := UiTheme.GOLD_DIM

	func _make_custom_tooltip(_for_text: String) -> Object:
		return ItemWidgets.tip_card(tip, tip_border) if tip != "" else null


## Bouton d'objet (listes) avec la carte d'objet au survol.
class CardButton extends Button:
	var item: Dictionary = {}

	func _make_custom_tooltip(_for_text: String) -> Object:
		return ItemWidgets.item_card(item) if not item.is_empty() else null


# --- case d'objet ---------------------------------------------------------------------------
class ItemSlot extends Button:
	signal activated  # double-clic ou clic droit

	var item: Dictionary = {}
	var placeholder := ""  # emplacement vide : nom de la pièce
	var ghost := ""  # emplacement vide : icône fantôme (entrée d'archive non remplie)
	var slot_id := ""  # emplacement d'équipement (cases de la poupée)
	var selected := false
	var dim := false  # objet non disponible (filtre, prix trop élevé...)
	var badge := ""  # petit texte en bas (prix, classe qui l'utilise...)
	var source := ""  # "equipped", "inventory"... (glisser-déposer)
	var can_drop: Callable  # func(data) -> bool
	var on_drop: Callable  # func(data)
	var card_extra: Callable  # func(item) -> String : lignes ajoutées à la carte au survol
	var card_text := ""  # carte au survol entièrement fournie (trésors de collection)

	func _init(size_px := 64.0) -> void:
		custom_minimum_size = Vector2(size_px, size_px)
		focus_mode = Control.FOCUS_NONE
		flat = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_item(it: Dictionary) -> void:
		item = it
		if not it.is_empty():
			tooltip_text = Items.display_name(it)  # déclenche la carte d'objet au survol
		queue_redraw()

	func _make_custom_tooltip(for_text: String) -> Object:
		if item.is_empty():
			return null
		var extra := String(card_extra.call(item)) if card_extra.is_valid() else ""
		if card_text != "":
			return ItemWidgets.tip_card(card_text + extra, Items.color_of(item))
		if for_text != Items.display_name(item):
			extra += "\n\n[color=#c8c8d4]%s[/color]" % for_text  # consigne propre à la case
		return ItemWidgets.item_card(item, extra)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and event.double_click):
				activated.emit()
				accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var col: Color = Items.color_of(item) if not item.is_empty() else Color(0.35, 0.3, 0.25)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.06, 0.05, 0.1, 0.95) if not is_hovered() else Color(0.13, 0.1, 0.2, 1.0)
		bg.border_color = UiTheme.GOLD if selected else (col if not item.is_empty() else Color(0.3, 0.26, 0.2, 0.8))
		bg.set_border_width_all(3 if selected else 2)
		bg.set_corner_radius_all(8)
		if selected:
			bg.shadow_color = Color(UiTheme.GOLD, 0.5)
			bg.shadow_size = 8
		draw_style_box(bg, r)
		if item.is_empty():
			var gt := UiTheme.texture(ghost) if ghost != "" else null
			if gt:
				draw_texture_rect(gt, r.grow(-8.0), false, Color(0.45, 0.42, 0.55, 0.35))
			if placeholder != "":
				HudWidgets.text_center(self, placeholder, r.get_center(), UiTheme.bold_font(), 12, Color(1, 1, 1, 0.35), 0)
			return
		# lueur de rareté sous l'icône
		var glow := Color(col, 0.18)
		draw_rect(r.grow(-4.0), glow)
		var tex := UiTheme.texture(String(item.get("icon", "")))
		if tex:
			draw_texture_rect(tex, r.grow(-6.0), false, Color(1, 1, 1, 0.45 if dim else 1.0))
		var font := UiTheme.bold_font()
		var up := int(item.get("upgrade", 0))
		if up > 0:
			HudWidgets.text_center(self, "+%d" % up, Vector2(size.x - 13.0, 11.0), font, 13, Color(1, 0.88, 0.45), 4)
		if item.has("set"):
			HudWidgets.diamond(self, Vector2(9, 9), 5.0, Items.SET_COLOR)
		var sockets: Array = item.get("sockets", [])
		for i in sockets.size():
			var p := Vector2(9.0 + i * 11.0, size.y - 9.0)
			draw_circle(p, 4.5, Color(0, 0, 0, 0.8))
			draw_circle(p, 3.2, Color(0.75, 0.55, 1.0) if sockets[i] != null else Color(0.35, 0.33, 0.4))
		if badge != "":
			HudWidgets.text_center(self, badge, Vector2(size.x * 0.5, size.y - 8.0), font, 11, Color(1, 1, 1, 0.9), 4)
		elif int(item.get("level", 1)) > 0:
			HudWidgets.text_center(self, str(int(item.get("level", 1))), Vector2(size.x - 11.0, size.y - 9.0), font, 11, Color(1, 1, 1, 0.75), 3)

	func _get_drag_data(_at: Vector2) -> Variant:
		if item.is_empty() or source == "":
			return null
		var preview := TextureRect.new()
		preview.texture = UiTheme.texture(String(item.get("icon", "")))
		preview.custom_minimum_size = Vector2(56, 56)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.modulate.a = 0.85
		set_drag_preview(preview)
		return {"item": item, "source": source, "slot": slot_id}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("item") and can_drop.is_valid() and bool(can_drop.call(data))

	func _drop_data(_at: Vector2, data: Variant) -> void:
		if on_drop.is_valid():
			on_drop.call(data)


# --- grille d'objets ------------------------------------------------------------------------
## Grille filtrable (rareté, emplacement), triable, à sélection simple ou multiple
## (clic, Ctrl+clic, Maj+clic, Ctrl+A).
class ItemGrid extends VBoxContainer:
	signal selection_changed
	signal item_activated(item: Dictionary)

	var multi := false
	var source := "inventory"
	var cell := 64.0
	var badge_fn: Callable  # func(item) -> String
	var dim_fn: Callable  # func(item) -> bool
	var can_drop: Callable
	var on_drop: Callable
	var card_extra: Callable  # func(item) -> String : ajout à la carte au survol
	var _items: Array = []
	var _shown: Array = []
	var _selection: Array = []
	var _anchor := -1
	var _grid: GridContainer
	var _rarity: OptionButton
	var _slot: OptionButton
	var _sort: OptionButton
	var _count: Label
	var _empty_text := "Aucun objet."
	var _empty: Label

	func _init(multi_select := false, columns := 8, cell_px := 64.0) -> void:
		multi = multi_select
		cell = cell_px
		add_theme_constant_override("separation", 8)
		size_flags_vertical = Control.SIZE_EXPAND_FILL
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 6)
		add_child(bar)
		_rarity = _option(bar, ["Toutes raretés"] + Items.RARITIES.map(func(r): return r.name) + ["Pièces de set"])
		_slot = _option(bar, ["Tous types"] + Items.SLOTS.map(func(s): return Items.SLOT_NAMES[s]))
		_sort = _option(bar, ItemWidgets.SORTS.map(func(s): return "Tri : " + s))
		_count = Hud._label(bar, "", 14, UiTheme.MUTED)
		_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		_grid = GridContainer.new()
		_grid.columns = columns
		_grid.add_theme_constant_override("h_separation", 6)
		_grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(_grid)
		_empty = Hud._label(self, "", 14, UiTheme.MUTED)
		_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	func _option(parent: Control, labels: Array) -> OptionButton:
		var o := OptionButton.new()
		o.focus_mode = Control.FOCUS_NONE
		o.add_theme_font_size_override("font_size", 14)
		for l in labels:
			o.add_item(String(l))
		o.item_selected.connect(func(_i): refresh())
		parent.add_child(o)
		return o

	func set_empty_text(t: String) -> void:
		_empty_text = t

	func set_items(items: Array) -> void:
		_items = items
		_selection = _selection.filter(func(x): return _items.any(func(y): return is_same(x, y)))
		refresh()

	func selection() -> Array:
		return _selection

	func shown() -> Array:
		return _shown

	func first_selected() -> Dictionary:
		return _selection[0] if not _selection.is_empty() else {}

	func clear_selection() -> void:
		_selection.clear()
		_anchor = -1
		refresh()
		selection_changed.emit()

	func select_item(it: Dictionary) -> void:
		_selection = [it] if not it.is_empty() else []
		refresh()
		selection_changed.emit()

	## Sélectionne tout ce qui est visible jusqu'à la rareté [param r] incluse.
	func select_up_to_rarity(r: int) -> void:
		_selection = _shown.filter(func(it): return int(it.rarity) <= r and not it.has("set"))
		refresh()
		selection_changed.emit()

	func select_all_shown() -> void:
		_selection = _shown.duplicate()
		refresh()
		selection_changed.emit()

	func refresh() -> void:
		var rf := _rarity.selected - 1
		var sf := _slot.selected - 1
		_shown = _items.filter(func(it):
			if rf >= 0 and rf < Items.RARITIES.size() and int(it.rarity) != rf:
				return false
			if rf == Items.RARITIES.size() and not it.has("set"):
				return false
			if sf >= 0 and it.slot != Items.SLOTS[sf]:
				return false
			return true)
		var key := _sort.selected
		_shown.sort_custom(func(a, b): return _sort_key(a, key) > _sort_key(b, key))
		for c in _grid.get_children():
			c.queue_free()
		for i in _shown.size():
			var it: Dictionary = _shown[i]
			var s := ItemWidgets.ItemSlot.new(cell)
			s.set_item(it)
			s.source = source
			s.selected = _selection.any(func(x): return is_same(x, it))
			s.badge = String(badge_fn.call(it)) if badge_fn.is_valid() else ""
			s.dim = bool(dim_fn.call(it)) if dim_fn.is_valid() else false
			s.can_drop = can_drop
			s.on_drop = on_drop
			s.card_extra = card_extra
			s.pressed.connect(_on_pressed.bind(it, i))
			s.activated.connect(func(): item_activated.emit(it))
			_grid.add_child(s)
		# cases vides : on peut y déposer un objet porté
		if can_drop.is_valid():
			for i in maxi(0, _grid.columns * 2 - _shown.size() % _grid.columns):
				var e := ItemWidgets.ItemSlot.new(cell)
				e.disabled = true
				e.can_drop = can_drop
				e.on_drop = on_drop
				_grid.add_child(e)
		_count.text = "%d objet(s)%s" % [_shown.size(), (" · %d sélectionné(s)" % _selection.size()) if multi and not _selection.is_empty() else ""]
		_empty.text = _empty_text if _items.is_empty() else ""
		_empty.visible = _items.is_empty()

	func _sort_key(it: Dictionary, key: int) -> float:
		match key:
			1:
				return float(it.level) * 100.0 + float(it.rarity)
			2:
				return float(Items.SLOTS.size() - Items.SLOTS.find(it.slot)) * 100.0 + float(it.rarity)
			3:
				return float(Items.sell_price(it)) + 4.0 * float(int(it.get("upgrade", 0)))
		return float(it.rarity) * 1000.0 + float(Items.power_level(it)) * 10.0 + float(it.get("upgrade", 0)) + (500.0 if it.has("set") else 0.0)

	func _on_pressed(it: Dictionary, index: int) -> void:
		if multi and Input.is_key_pressed(KEY_SHIFT) and _anchor >= 0 and _anchor < _shown.size():
			var a := mini(_anchor, index)
			var b := maxi(_anchor, index)
			for k in range(a, b + 1):
				if not _selection.any(func(x): return is_same(x, _shown[k])):
					_selection.append(_shown[k])
		elif multi and (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)):
			var found := _selection.find_custom(func(x): return is_same(x, it))
			if found >= 0:
				_selection.remove_at(found)
			else:
				_selection.append(it)
			_anchor = index
		else:
			_selection = [it]
			_anchor = index
		refresh()
		selection_changed.emit()

	func _unhandled_key_input(event: InputEvent) -> void:
		if multi and is_visible_in_tree() and event is InputEventKey and event.pressed and event.keycode == KEY_A and event.ctrl_pressed:
			select_all_shown()
			get_viewport().set_input_as_handled()
