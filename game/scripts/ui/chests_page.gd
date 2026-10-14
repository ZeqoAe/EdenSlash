class_name ChestsPage
extends HBoxContainer
## Menu Coffres (hors run) : les coffres de récompense rapportés des runs (Rewards), par
## type, avec Ouvrir ; à droite ce qu'ils contiennent, ou les 3 propositions d'un coffre
## à choix (set, trophées) : la proposition reste tant qu'on n'a pas choisi.

var _list: VBoxContainer
var _title: Label
var _detail: RichTextLabel
var _choices: HBoxContainer
var _current: Dictionary = {}  # coffre à choix en cours


var _card_box: CenterContainer


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	var left := ItemWidgets.panel(self, 560)
	ItemWidgets.section(left, "Tes coffres")
	Hud._label(left, "Boss d'étape et stèles du défi : toujours ; élites : 1 fois sur 5 ; monstres : rarement. Gardés si tu t'en sors (victoire ou extraction). Les objets vont au coffre commun, les fournitures à la réserve de la prochaine run.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	right.add_child(_title)
	_detail = ItemWidgets.rich(right, 16)
	_detail.size_flags_vertical = Control.SIZE_FILL
	_detail.fit_content = true
	_choices = HBoxContainer.new()
	_choices.add_theme_constant_override("separation", 14)
	_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(_choices)
	# fiche complète de l'objet sélectionné parmi les propositions
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
	if not _current.is_empty() and not Profile.reward_chests.has(_current):
		_current = {}
	if _current.is_empty():
		_show_text("Ouvre un coffre", "Choisis un coffre à gauche.")


func _row(type: String, chests: Array) -> Control:
	var t: Dictionary = Rewards.TYPES[type]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", InventoryPage.card_box())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var ic := TextureRect.new()
	ic.texture = MenuWidgets.icon("chest")
	ic.modulate = (t.color as Color).lightened(0.15)  # un coffre de la couleur de son type
	ic.custom_minimum_size = Vector2(54, 54)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var n := Hud._label(v, "%s  ×%d" % [t.name, chests.size()], 18, (t.color as Color).lightened(0.25))
	n.add_theme_font_override("font", UiTheme.bold_font())
	var d := Hud._label(v, String(t.desc), 13, UiTheme.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var b := MenuWidgets.glass_button("Ouvrir", 16, Vector2(110, 44))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(open_chest.bind(chests[0]))
	h.add_child(b)
	return p


## Ouvre [param chest] : contenu donné, ou propositions affichées (coffre à choix).
func open_chest(chest: Dictionary) -> void:
	var t: Dictionary = Rewards.TYPES[chest.type]
	if Rewards.is_choice(chest):
		_current = chest
		_show_choices(chest)
		Profile.save_profile()  # la proposition est gardée
		return
	_current = {}
	var got := Rewards.open(chest)
	_show_text("%s ouvert !" % t.name, Rewards.got_text(got))
	refresh()


func _show_text(title: String, text: String) -> void:
	_title.text = title
	_detail.text = text
	for c in _choices.get_children():
		c.queue_free()
	_show_card({})


## Fiche complète de [param it] sous les propositions (vide : rien).
func _show_card(it: Dictionary) -> void:
	for c in _card_box.get_children():
		c.queue_free()
	if not it.is_empty():
		_card_box.add_child(ItemWidgets.item_card(it))


func _show_choices(chest: Dictionary) -> void:
	var t: Dictionary = Rewards.TYPES[chest.type]
	_show_text(String(t.name), "Choisis 1 objet (clic sur une icône : sa fiche complète en dessous). Les autres disparaissent.")
	var items := Rewards.offer(chest)
	for i in items.size():
		var it: Dictionary = items[i]
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		v.custom_minimum_size = Vector2(230, 0)
		_choices.add_child(v)
		var s := ItemWidgets.ItemSlot.new(110.0)
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
			_show_text("Ajouté au coffre commun", Rewards.got_text({"items": [got]}))
			refresh())
		v.add_child(b)
	if not items.is_empty():
		_show_card(items[0])
