class_name ChestsPage
extends HBoxContainer
## Menu Coffres (hors run) : les coffres de récompense rapportés des runs (Rewards), par
## type, avec Ouvrir. À droite, le coffre en 3D (ChestStage) : à l'ouverture il s'ouvre dans
## un éclat de lumière, puis ce qu'il contient apparaît pièce par pièce (objets, fournitures,
## cristaux), ou les 3 propositions d'un coffre à choix (set, trophées) : la proposition reste
## tant qu'on n'a pas choisi.

var _list: VBoxContainer
var _title: Label
var _detail: RichTextLabel
var _stage: ChestStage
var _open_btn: Button
var _loot: HFlowContainer  # contenu d'un coffre ouvert
var _choices: HBoxContainer
var _card_box: CenterContainer
var _all_btn: Button
var _current: Dictionary = {}  # coffre à choix en cours
var _shown: Dictionary = {}  # coffre affiché (fermé) à droite


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	var left := ItemWidgets.panel(self, 560)
	ItemWidgets.section(left, "Tes coffres")
	_all_btn = MenuWidgets.glass_button("Ouvrir tous les coffres sans choix", 16, Vector2(0, 42))
	_all_btn.tooltip_text = "Ouvre d'un coup les coffres de forge, de joaillier, d'équipement et d'apparence (les coffres à choix restent à part), puis affiche un récapitulatif."
	_all_btn.pressed.connect(func(): open_many(Profile.reward_chests.filter(func(c): return not Rewards.is_choice(c))))
	left.add_child(_all_btn)
	Hud._label(left, "Survie : chaque boss (un coffre d'apparence, plus un coffre de forge ou de joaillier), stèles du défi, élites 1 fois sur 5, monstres rarement, autel de la fortune. Tour : paliers 50, 100, 150 et 200 (apparence). Un coffre ramassé est toujours gardé. Les objets vont au coffre commun, les fournitures à ta réserve.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	var right := ItemWidgets.panel(self, 0, true)
	_title = Label.new()
	UiTheme.title(_title, 22)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(_title)
	_stage = ChestStage.new()
	_stage.custom_minimum_size = Vector2(0, 270)
	_stage.burst.connect(_on_burst)
	right.add_child(_stage)
	_detail = ItemWidgets.rich(right, 16)
	_detail.fit_content = true
	_detail.size_flags_vertical = Control.SIZE_FILL
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bc := CenterContainer.new()
	right.add_child(bc)
	_open_btn = MenuWidgets.gold_button("Ouvrir", 20, Vector2(240, 48))
	_open_btn.pressed.connect(func():
		if not _shown.is_empty():
			open_chest(_shown))
	bc.add_child(_open_btn)
	_loot = HFlowContainer.new()
	_loot.alignment = FlowContainer.ALIGNMENT_CENTER
	_loot.add_theme_constant_override("h_separation", 14)
	_loot.add_theme_constant_override("v_separation", 10)
	right.add_child(_loot)
	_choices = HBoxContainer.new()
	_choices.add_theme_constant_override("separation", 14)
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(_choices)
	# fiche complète de l'objet sélectionné
	var sc2 := ScrollContainer.new()
	sc2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc2)
	_card_box = CenterContainer.new()
	_card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc2.add_child(_card_box)


func refresh() -> void:
	if not is_inside_tree():
		return
	if not _current.is_empty() and not Profile.reward_chests.has(_current):
		_current = {}
	if _current.is_empty() and (_shown.is_empty() or not Profile.reward_chests.has(_shown)) and _loot.get_child_count() == 0:
		_preview(Profile.reward_chests.filter(func(c): return Rewards.ORDER.has(c.type))
			.reduce(func(a, c): return c if a.is_empty() or Rewards.ORDER.find(c.type) < Rewards.ORDER.find(a.type) else a, {}))
	_all_btn.visible = Profile.reward_chests.any(func(c): return not Rewards.is_choice(c))
	for c in _list.get_children():
		c.queue_free()
	var by := {}
	for ch in Profile.reward_chests:
		if not by.has(ch.type):
			by[ch.type] = []
		by[ch.type].append(ch)
	for t in Rewards.ORDER:
		if by.has(t):
			_list.add_child(_row(t, by[t]))
	if Profile.reward_chests.is_empty():
		Hud._label(_list, "Aucun coffre pour l'instant : bats des boss et des élites, puis ramène-les (victoire ou extraction).", 15, UiTheme.TEXT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _row(type: String, chests: Array) -> Control:
	var t: Dictionary = Rewards.TYPES[type]
	var p := PanelContainer.new()
	var box := InventoryPage.card_box()
	if not _shown.is_empty() and _shown.type == type:
		box = box.duplicate()
		box.border_color = (t.color as Color)
		box.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", box)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_preview(chests[0])
			refresh())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var ic := TextureRect.new()
	ic.texture = MenuWidgets.icon("chest")
	ic.modulate = (t.color as Color).lightened(0.15)  # un coffre de la couleur de son type
	ic.custom_minimum_size = Vector2(54, 54)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var n := Hud._label(v, "%s  ×%d" % [t.name, chests.size()], 18, (t.color as Color).lightened(0.25))
	n.add_theme_font_override("font", UiTheme.bold_font())
	var d := Hud._label(v, String(t.desc), 13, UiTheme.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := MenuWidgets.glass_button("Ouvrir", 16, Vector2(110, 44))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = "Ctrl + clic : ouvre tous les coffres de ce type d'un coup" if not Rewards.is_choice(chests[0]) else "Choisis une pièce parmi trois"
	b.pressed.connect(func():
		if Input.is_key_pressed(KEY_CTRL) and not Rewards.is_choice(chests[0]):
			open_many(chests)
		else:
			open_chest(chests[0]))
	if chests.size() > 1 and not Rewards.is_choice(chests[0]):
		var all := MenuWidgets.glass_button("Tout", 16, Vector2(70, 44))
		all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		all.tooltip_text = "Ouvre les %d coffres de ce type" % chests.size()
		all.pressed.connect(func(): open_many(chests))
		h.add_child(all)
	h.add_child(b)
	return p


## Coffre fermé [param chest] à droite (rien : « Choisis un coffre »).
func _preview(chest: Dictionary) -> void:
	_shown = chest
	_current = {}
	_clear()
	if chest.is_empty():
		_title.text = "Coffres"
		_title.add_theme_color_override("font_color", UiTheme.GOLD)
		_detail.text = "[color=#a8a2b8]Aucun coffre à ouvrir.[/color]"
		_stage.show_chest(Color(0.5, 0.45, 0.6))
		_open_btn.visible = false
		return
	var t: Dictionary = Rewards.TYPES[chest.type]
	_title.text = String(t.name)
	_title.add_theme_color_override("font_color", (t.color as Color).lightened(0.2))
	_detail.text = "[color=#c8c8d4]Niveau %d · %s[/color]
[color=#a8a2b8]%s[/color]" % [int(chest.plevel), String(t.desc), Rewards.preview(chest)]
	_stage.show_chest(t.color)
	_open_btn.visible = true


## Ouvre [param chest] : animation, puis contenu donné ou propositions (coffre à choix).
func open_chest(chest: Dictionary) -> void:
	if not Profile.reward_chests.has(chest):
		return
	if _shown != chest or not _stage.spin:
		_preview(chest)
	_shown = chest
	_open_btn.visible = false
	if Rewards.is_choice(chest):
		_current = chest
		Rewards.offer(chest)  # tirée tout de suite : gardée même si on quitte pendant l'animation
		Profile.save_profile()
	else:
		_current = {}
		chest["_got"] = Rewards.open(chest)
	if not is_inside_tree() or not is_visible_in_tree():
		_on_burst()
		return
	_stage.open()


## Ouvre plusieurs coffres sans choix d'un coup : une seule présentation, puis le récapitulatif.
func open_many(chests: Array) -> void:
	var todo := chests.filter(func(c): return not Rewards.is_choice(c) and Profile.reward_chests.has(c))
	if todo.is_empty():
		return
	_current = {}
	_shown = {}
	var got := Rewards.open_all(todo)
	_clear()
	_open_btn.visible = false
	_title.text = "%d coffre(s) ouvert(s)" % int(got.opened)
	_title.add_theme_color_override("font_color", UiTheme.GOLD)
	_detail.text = "[color=#e6d7ff]%s[/color]
[color=#a8a2b8]Objets : au coffre commun · fournitures : à la réserve de ta prochaine run[/color]" % Rewards.summary(got)
	_stage.show_chest(Color(1.0, 0.86, 0.3))
	Sfx.ui("confirm")
	_show_loot(got)
	refresh()


## Couvercle ouvert : le contenu apparaît.
func _on_burst() -> void:
	var chest := _shown
	if chest.is_empty():
		return
	var t: Dictionary = Rewards.TYPES[chest.type]
	if Rewards.is_choice(chest):
		_show_choices(chest)
	else:
		var got: Dictionary = chest.get("_got", {})
		chest.erase("_got")
		_title.text = "%s ouvert !" % t.name
		_detail.text = "[color=#a8a2b8]%s[/color]" % ("Ajoutée à ta collection : à porter dans Héros > Apparence" if not got.get("looks", []).is_empty()
			else "Objets : au coffre commun · fournitures : à la réserve de ta prochaine run")
		_show_loot(got)
		_shown = {}
	refresh()


func _clear() -> void:
	for c in _choices.get_children():
		c.queue_free()
	for c in _loot.get_children():
		c.queue_free()
	_show_card({})


## Contenu d'un coffre ouvert : une case par objet ou fourniture, qui apparaissent l'une
## après l'autre ; la fiche du premier objet en dessous.
func _show_loot(got: Dictionary) -> void:
	_clear()
	var tiles: Array = []
	for x in got.get("looks", []):
		# apparence débloquée : grande case à la couleur de sa rareté
		var col: Color = Items.RARITIES[clampi(int(x.get("rarity", 0)), 0, Items.RARITIES.size() - 1)].color
		var v := _tile()
		v.custom_minimum_size = Vector2(220, 0)
		var frame := PanelContainer.new()
		frame.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.05, 0.1, 0.95), col, 3, 10))
		frame.custom_minimum_size = Vector2(120, 120)
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(frame)
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(x.get("icon", "")))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		frame.add_child(ic)
		var nl := Hud._label(v, String(x.name), 16, col)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var kind := "Aura" if x.has("aura") else ("Apparence d'arme" if x.has("skin") else "Apparence")
		var sl := Hud._label(v, "%s · %s · nouvelle !" % [kind, Items.RARITIES[clampi(int(x.get("rarity", 0)), 0, 5)].name], 13, UiTheme.MUTED)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tiles.append(v)
	for it in got.get("items", []):
		var v := _tile()
		var s := ItemWidgets.ItemSlot.new(84.0)
		s.set_item(it)
		s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		s.pressed.connect(func(): _show_card(it))
		v.add_child(s)
		var l := Hud._label(v, Items.display_name(it), 14, Items.color_of(it))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tiles.append(v)
	for k in got.get("supplies", {}):
		if int(got.supplies[k]) > 0:
			tiles.append(_supply_tile(UiTheme.texture(Craft.icon(k)), "%s ×%d" % [Craft.label(k), int(got.supplies[k])]))
	if int(got.get("crystal", 0)) > 0:
		tiles.append(_supply_tile(UiTheme.texture(Items.material_icon("crystal")), "%d cristaux" % int(got.crystal)))
	for i in tiles.size():
		var tile: Control = tiles[i]
		_loot.add_child(tile)
		tile.modulate.a = 0.0
		var tw := tile.create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_callback(func():
			tile.pivot_offset = tile.size * 0.5
			tile.scale = Vector2.ONE * 0.6
			if i < 6:
				Sfx.ui("pickup", -8.0))
		tw.set_parallel()
		tw.tween_property(tile, "modulate:a", 1.0, 0.2)
		tw.tween_property(tile, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var items: Array = got.get("items", [])
	if not items.is_empty():
		_show_card(items[0])


func _tile() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.custom_minimum_size = Vector2(130, 0)
	return v


func _supply_tile(tex: Texture2D, text: String) -> Control:
	var v := _tile()
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.05, 0.1, 0.95), Color(0.45, 0.4, 0.3, 0.9), 2, 8))
	frame.custom_minimum_size = Vector2(84, 84)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(frame)
	var ic := TextureRect.new()
	ic.texture = tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(ic)
	var l := Hud._label(v, text, 14, UiTheme.TEXT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return v


## Fiche complète de [param it] sous les propositions (vide : rien).
func _show_card(it: Dictionary) -> void:
	for c in _card_box.get_children():
		c.queue_free()
	if not it.is_empty():
		_card_box.add_child(ItemWidgets.item_card(it))


func _show_choices(chest: Dictionary) -> void:
	var t: Dictionary = Rewards.TYPES[chest.type]
	_clear()
	_title.text = String(t.name)
	_detail.text = "[color=#c8c8d4]Choisis 1 objet (clic sur une icône : sa fiche complète en dessous). Les autres disparaissent.[/color]"
	var items := Rewards.offer(chest)
	for i in items.size():
		var it: Dictionary = items[i]
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		v.custom_minimum_size = Vector2(230, 0)
		_choices.add_child(v)
		var s := ItemWidgets.ItemSlot.new(96.0)
		s.set_item(it)
		s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		s.pressed.connect(func(): _show_card(it))
		v.add_child(s)
		var name := Hud._label(v, Items.display_name(it), 15, Items.color_of(it))
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var info := String(it.get("passive", {}).get("desc", "")) if it.slot == "trophy" else "%s · niv. %d" % [Items.SLOT_NAMES[it.slot], int(it.level)]
		var l := Hud._label(v, info, 13, UiTheme.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var b := MenuWidgets.glass_button("Choisir", 16, Vector2(150, 42))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var idx := i
		b.pressed.connect(func():
			var got := Rewards.choose(chest, idx)
			_current = {}
			_shown = {}
			_title.text = "Ajouté au coffre commun"
			_title.add_theme_color_override("font_color", UiTheme.GOLD)
			_detail.text = ""
			Sfx.ui("confirm")
			_show_loot({"items": [got]})
			refresh())
		v.add_child(b)
		v.modulate.a = 0.0
		var tw := v.create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_property(v, "modulate:a", 1.0, 0.25)
	if not items.is_empty():
		_show_card(items[0])
