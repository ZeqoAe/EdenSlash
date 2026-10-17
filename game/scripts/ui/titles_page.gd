class_name TitlesPage
extends HBoxContainer
## Héros > Titres (lot GX-5, étude BM-GEAR Q9) : le titre porté sous le nom du héros, puis tous les titres du jeu rangés par
## source (Titles.catalog) : obtenu (« Porter » / « Porté ») ou à obtenir, avec la phrase qui dit comment. Un titre ne donne
## aucune stat. Le Carnet > Succès garde sa rangée de titres (les deux disent la même chose).

signal changed  # titre porté changé (l'en-tête de Héros le relit)

const FILTERS := ["Tous", "Obtenus", "À obtenir"]

var _filter := 0
var _query := ""
var _name: Label
var _worn: Label
var _none: Button
var _count: Label
var _chips: HFlowContainer
var _search: LineEdit
var _list: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	add_theme_constant_override("separation", 16)
	# gauche : le héros et son titre
	var left := ItemWidgets.panel(self, 340)
	ItemWidgets.section(left, "Titre porté", 20)
	_name = Hud._label(left, "", 26, UiTheme.GOLD)
	_name.add_theme_font_override("font", UiTheme.title_font())
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_worn = Hud._label(left, "", 18, UiTheme.TEXT)
	_worn.add_theme_font_override("font", UiTheme.bold_font())
	_worn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := Hud._label(left, "Il s'affiche sous ton nom, au menu principal et dans les bilans. Un titre ne donne aucune stat.", 14, UiTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_none = ForgeWidgets.candy_button("N'en porter aucun", "nuit", 16, 42)
	_none.pressed.connect(func():
		Titles.wear("")
		Sfx.ui("cancel")
		refresh()
		changed.emit())
	left.add_child(_none)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(gap)
	_count = Hud._label(left, "", 16, UiTheme.TEXT)
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# droite : la liste
	var right := ItemWidgets.panel(self, 0, true)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	right.add_child(top)
	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 8)
	_chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_chips)
	_search = LineEdit.new()
	_search.placeholder_text = "Chercher un titre"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(200, 36)
	_search.text_changed.connect(func(t: String):
		_query = t
		_fill())
	top.add_child(_search)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)


func refresh() -> void:
	if _list == null:
		return
	_name.text = Profile.hero_name if Profile.hero_name != "" else "Ton héros"
	_worn.text = Titles.worn_text()
	_none.disabled = Profile.title == ""
	var all := Titles.catalog()
	var own := Titles.owned()
	var n_own := all.filter(func(e): return String(e.title) in own).size()
	_count.text = "%d titre%s sur %d" % [n_own, "s" if n_own > 1 else "", all.size()]
	for c in _chips.get_children():
		_chips.remove_child(c)
		c.queue_free()
	var counts := [all.size(), n_own, all.size() - n_own]
	for i in FILTERS.size():
		var b := MenuWidgets.glass_button("%s · %d" % [FILTERS[i], counts[i]], 15, Vector2(0, 36))
		b.toggle_mode = true
		b.set_pressed_no_signal(i == _filter)
		var k := i
		b.pressed.connect(func():
			_filter = k
			refresh())
		_chips.add_child(b)
	_fill()


## Liste filtrée et groupée par source.
func _fill() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var own := Titles.owned()
	var q := ItemWidgets.ItemGrid._plain(_query.strip_edges().to_lower())
	var shown := Titles.catalog().filter(func(e):
		var has := String(e.title) in own
		if (_filter == 1 and not has) or (_filter == 2 and has):
			return false
		return q == "" or ItemWidgets.ItemGrid._plain(("%s %s %s" % [e.title, e.how, e.group]).to_lower()).contains(q))
	if shown.is_empty():
		UiTheme.empty_state(_list, "Aucun titre obtenu pour l'instant.\nLes succès, les jalons du niveau de héros et les activités en donnent." if _filter == 1
			else "Aucun titre ici.", "ico_res_title")
		return
	for grp in Titles.groups(shown):
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		_list.add_child(head)
		var gl := Hud._label(head, String(grp[0]), 17, UiTheme.GOLD)
		gl.add_theme_font_override("font", UiTheme.bold_font())
		var got := (grp[1] as Array).filter(func(e): return String(e.title) in own).size()
		Hud._label(head, "%d / %d" % [got, (grp[1] as Array).size()], 14, UiTheme.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for e in grp[1]:
			_list.add_child(_row(e, String(e.title) in own))


func _row(e: Dictionary, has: bool) -> Control:
	var t := String(e.title)
	var worn := t == Profile.title
	var p := PanelContainer.new()
	var box := InventoryPage.card_box(worn)
	p.add_theme_stylebox_override("panel", box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var ic := Ico.rect("res_title" if has else "lock", 28, Color.WHITE if has else Color(1, 1, 1, 0.55))
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nl := Hud._label(v, t, 17, UiTheme.GOLD if has else UiTheme.TEXT)
	nl.add_theme_font_override("font", UiTheme.bold_font())
	var hl := Hud._label(v, String(e.how), 14, UiTheme.MUTED)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if has:
		var b := ForgeWidgets.candy_button("Porté ✓" if worn else "Porter", "pomme" if worn else "lagon", 15, 38)
		b.custom_minimum_size.x = 120
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = "Un second clic le retire." if worn else "Porter « %s »" % t
		b.pressed.connect(func():
			Titles.wear(t)
			Sfx.ui("confirm")
			refresh()
			changed.emit())
		h.add_child(b)
	else:
		var l := Hud._label(h, "À obtenir", 14, UiTheme.MUTED)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		l.custom_minimum_size.x = 120
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return p
