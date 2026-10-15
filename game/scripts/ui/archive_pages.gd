class_name ArchivePages
extends RefCounted
## Page Collection du Carnet : le catalogue de tout l'équipement et des trésors du jeu, les objets
## archivés, les paliers de bonus et l'archivage depuis le coffre. L'encyclopédie de tous les
## objets est dans le mode dev (DevPages).

const TIER_LABELS := {4: "Mythique", 5: "Légendaire"}


# --- collection --------------------------------------------------------------------------------
## À gauche les catégories et leur avancement, au centre les entrées de la catégorie
## (équipements mythiques et légendaires, apparences, montures, familiers, boîte arcanique,
## autres objets), à droite l'avancement par groupe, les paliers et le dépôt depuis le coffre.
class CollectionPage extends HBoxContainer:
	const PER_PAGE := 120
	var _tree: VBoxContainer
	var _cat := ""
	var _head: Label
	var _rate: Label
	var _show: OptionButton  # Tous / Obtenus / Manquants
	var _sort: OptionButton  # Obtenus d'abord / Ordre du catalogue / Ordre inversé
	var _search: LineEdit
	var _grid: GridContainer
	var _page := 0
	var _page_lbl: Label
	var _list_text: RichTextLabel
	var _vault_grid: ItemWidgets.ItemGrid
	var _detail: RichTextLabel
	var _btn: Button
	var _selected_item: Dictionary = {}
	var _selected_entry: Dictionary = {}
	var _armed := false

	func _ready() -> void:
		add_theme_constant_override("separation", 14)
		# catégories
		var left := ItemWidgets.panel(self, 250)
		ItemWidgets.section(left, "Catégories")
		var ts := ScrollContainer.new()
		ts.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ts.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(ts)
		_tree = VBoxContainer.new()
		_tree.add_theme_constant_override("separation", 2)
		_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ts.add_child(_tree)
		# entrées de la catégorie
		var mid := ItemWidgets.panel(self, 0, true)
		var mh := HBoxContainer.new()
		mh.add_theme_constant_override("separation", 10)
		mid.add_child(mh)
		_head = Hud._label(mh, "", 20, UiTheme.GOLD)
		_head.add_theme_font_override("font", UiTheme.title_font())
		_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rate = Hud._label(mh, "", 15, UiTheme.TEXT)
		var fl := HBoxContainer.new()
		fl.add_theme_constant_override("separation", 12)
		mid.add_child(fl)
		_show = _option(["Tous", "Obtenus", "Manquants"])
		fl.add_child(_show)
		_sort = _option(["Obtenus d'abord", "Ordre du catalogue", "Ordre inversé"])
		fl.add_child(_sort)
		_search = LineEdit.new()
		_search.placeholder_text = "Recherche…"
		_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_search.text_changed.connect(func(_t): _refresh_grid(0))
		fl.add_child(_search)
		var prev := Button.new()
		prev.text = "◀"
		prev.focus_mode = Control.FOCUS_NONE
		prev.pressed.connect(func(): _refresh_grid(_page - 1))
		fl.add_child(prev)
		_page_lbl = Hud._label(fl, "", 13, UiTheme.MUTED)
		var nxt := Button.new()
		nxt.text = "▶"
		nxt.focus_mode = Control.FOCUS_NONE
		nxt.pressed.connect(func(): _refresh_grid(_page + 1))
		fl.add_child(nxt)
		var gs := ScrollContainer.new()
		gs.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		mid.add_child(gs)
		_grid = GridContainer.new()
		_grid.columns = 9
		_grid.add_theme_constant_override("h_separation", 6)
		_grid.add_theme_constant_override("v_separation", 6)
		gs.add_child(_grid)
		_detail = ItemWidgets.rich(mid, 14)
		_detail.custom_minimum_size = Vector2(0, 70)
		_detail.size_flags_vertical = Control.SIZE_FILL
		_detail.visible = false  # n'apparaît qu'avec une entrée choisie
		# liste de l'archive et dépôt
		var right := ItemWidgets.panel(self, 400)
		ItemWidgets.section(right, "Avancement")
		_list_text = ItemWidgets.rich(right, 13)
		_list_text.custom_minimum_size = Vector2(0, 230)
		_list_text.size_flags_vertical = Control.SIZE_FILL
		ItemWidgets.section(right, "Coffre", 16)
		_vault_grid = ItemWidgets.ItemGrid.new(false, 6, 56.0)
		_vault_grid.source = ""
		_vault_grid.dim_fn = func(it): return Archive.refusal(it) != ""
		_vault_grid.selection_changed.connect(func():
			_selected_item = _vault_grid.first_selected()
			_selected_entry = {}
			_armed = false
			_refresh_action())
		right.add_child(_vault_grid)
		_btn = ItemWidgets.action_button(right, "Archiver", _on_action, 0, true)

	func subtitle() -> String:
		return "Les trésors à rassembler"

	func _option(items: Array) -> OptionButton:
		var o := OptionButton.new()
		o.fit_to_longest_item = false
		o.focus_mode = Control.FOCUS_NONE
		for t in items:
			o.add_item(String(t))
		o.item_selected.connect(func(_i): _refresh_grid(0))
		return o

	func refresh() -> void:
		if not is_inside_tree():
			return
		if _cat == "":
			_cat = String(Archive.categories()[0].id)
		_build_tree()
		_refresh_grid(_page)
		_refresh_list()
		_vault_grid.set_empty_text("Aucun objet mythique ou légendaire à archiver.")  # avant set_items : lu à la reconstruction
		_vault_grid.set_items(Profile.all_items().filter(func(it): return int(it.rarity) >= Items.ARCHIVE_MIN_RARITY))
		_refresh_action()

	func _build_tree() -> void:
		for c in _tree.get_children():
			c.queue_free()
		var group := ""
		for c in Archive.categories():
			if String(c.group) != group:
				group = String(c.group)
				var g := Hud._label(_tree, "▼ " + group, 15, UiTheme.GOLD)
				g.add_theme_font_override("font", UiTheme.bold_font())
			var r := Archive.rate(String(c.id))
			var b := Button.new()
			b.text = "   %s  %d/%d" % [c.name, int(r.x), int(r.y)]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.toggle_mode = true
			b.button_pressed = String(c.id) == _cat
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_font_size_override("font_size", 13)
			b.custom_minimum_size = Vector2(0, 28)
			var id := String(c.id)
			b.pressed.connect(func():
				_cat = id
				_build_tree()
				_refresh_grid(0))
			_tree.add_child(b)

	func _refresh_grid(p: int) -> void:
		var cat_name := ""
		for c in Archive.categories():
			if String(c.id) == _cat:
				cat_name = String(c.name)
		var r := Archive.rate(_cat)
		_head.text = cat_name
		_rate.text = "%d / %d" % [int(r.x), int(r.y)]
		var q := _search.text.strip_edges().to_lower()
		var list: Array = []
		var got: Array = []  # « obtenu » évalué une seule fois par entrée
		for e in Archive.entries(_cat):
			if q != "" and not String(e.name).to_lower().contains(q):
				continue
			var own := Archive.owned(e)
			if (_show.selected == 1 and not own) or (_show.selected == 2 and own):
				continue
			list.append(e)
			got.append(own)
		if _sort.selected == 2:
			list.reverse()
		elif _sort.selected == 0:
			var firsts: Array = []
			var lasts: Array = []
			for i in list.size():
				(firsts if got[i] else lasts).append(list[i])
			list = firsts + lasts
		var pages := maxi(1, ceili(float(list.size()) / PER_PAGE))
		_page = clampi(p, 0, pages - 1)
		_page_lbl.text = "%d / %d" % [_page + 1, pages]
		for c in _grid.get_children():
			c.queue_free()
		for e in list.slice(_page * PER_PAGE, (_page + 1) * PER_PAGE):
			_grid.add_child(_cell(e))

	func _cell(e: Dictionary) -> Control:
		var k := Archive.key_of(e)
		var s := ItemWidgets.ItemSlot.new(58.0)
		if Archive.is_collection(e):
			var got := Archive.owned(e)
			s.set_item(ArchivePages.treasure_item(e))
			s.dim = not got
			s.badge = "✔" if got else ""
			s.card_text = Archive.collection_text(e) + "\n\n%s\n[color=#9a98a8]%s[/color]" % [
				"[color=#7fe08a]Obtenu[/color]" if got else "[color=#ff9a7a]Pas encore obtenu[/color]", Archive.source_text(e)]
			s.pressed.connect(func():
				_selected_entry = e
				_selected_item = {}
				_armed = false
				_refresh_action())
			return s
		var owned := Profile.archive.has(k)
		var item: Dictionary = Profile.archive[k] if owned else ArchivePages.demo_item(e)
		s.set_item(item)
		s.dim = not owned
		s.badge = "✔" if owned else ""
		var info := "\n\n%s\n[color=#9a98a8]%s[/color]" % [
			"[color=#7fe08a]Archivé[/color]" if owned else "[color=#ff9a7a]Pas encore archivé[/color]", Archive.source_text(e)]
		s.card_extra = func(_it): return info
		s.pressed.connect(func():
			_selected_entry = e
			_selected_item = {}
			_armed = false
			_refresh_action())
		return s

	func _refresh_list() -> void:
		var lines: PackedStringArray = []
		lines.append("[font_size=22][b]%s[/b][/font_size] / %s trésors" % [CarnetPages.num(Archive.count_all()), CarnetPages.num(Archive.total())])
		var groups := {}
		for c in Archive.categories():
			var r := Archive.rate(String(c.id))
			var g: Vector2 = groups.get(c.group, Vector2.ZERO)
			groups[c.group] = g + r
		for g in groups:
			var v: Vector2 = groups[g]
			lines.append("[color=#c8c8d4]%s[/color]  %d / %d" % [g, int(v.x), int(v.y)])
		var b := Archive.bonus()
		lines.append("")
		lines.append("[b]Bonus permanent[/b] : %s" % (Archive.bonus_text(b) if not b.is_empty() else "aucun"))
		var n := Archive.count()
		for m in Archive.MILESTONES:
			var ok := n >= int(m[0])
			lines.append("[color=%s]%s %d équipements : %s[/color]" % ["#7fe08a" if ok else "#8a86a0", "✔" if ok else "○", int(m[0]), Archive.bonus_text(m[1])])
		_list_text.text = "\n".join(lines)

	func _refresh_action() -> void:
		_btn.disabled = true
		_btn.text = "Archiver"
		_detail.visible = not _selected_item.is_empty() or not _selected_entry.is_empty()
		if not _selected_item.is_empty():
			var why := Archive.refusal(_selected_item)
			_detail.text = "[b][color=#%s]%s[/color][/b]  %s" % [Items.color_of(_selected_item).to_html(false), Items.display_name(_selected_item),
				("[color=#ff9a7a]%s[/color]" % why) if why != "" else "[color=#7fe08a]Rapproche du prochain palier[/color]"]
			_btn.text = "Confirmer l'archivage" if _armed else "Archiver"
			_btn.disabled = why != ""
			return
		if _selected_entry.is_empty():
			return
		if Archive.is_collection(_selected_entry):
			var got := Archive.owned(_selected_entry)
			_detail.text = "[b]%s[/b] — %s%s" % [_selected_entry.name, "[color=#7fe08a]obtenu[/color]" if got else Archive.source_text(_selected_entry),
				" · se porte dans Héros > Apparence" if got and _wearable(_selected_entry) else ""]
			return
		var k := Archive.key_of(_selected_entry)
		if Profile.archive.has(k):
			_detail.text = "[b]%s[/b] est archivé. Le retirer le remet dans le coffre et lui enlève son bonus." % _selected_entry.name
			_btn.text = "Retirer de l'archive"
			_btn.disabled = Profile.in_run
		else:
			_detail.text = "[b]%s[/b] — %s" % [_selected_entry.name, Archive.source_text(_selected_entry)]

	## Les apparences (tête, dos, corps, armes) et les auras se portent depuis l'écran Héros.
	static func _wearable(e: Dictionary) -> bool:
		return e.has("aura") or e.has("skin") or int(e.get("cat", 0)) <= 3

	func _on_action() -> void:
		if not _selected_item.is_empty():
			if Archive.refusal(_selected_item) != "":
				return
			if not _armed:
				_armed = true
				_refresh_action()
				return
			_armed = false
			Profile.archive_item(_selected_item)
			_selected_item = {}
			_vault_grid.clear_selection()
			refresh()
			return
		if not _selected_entry.is_empty() and Profile.archive.has(Archive.key_of(_selected_entry)):
			Archive.withdraw(Archive.key_of(_selected_entry))
			_selected_entry = {}
			refresh()


## Case d'un trésor de collection (icône et rareté, sans stats).
static func treasure_item(x: Dictionary) -> Dictionary:
	return {"uid": "c%d" % int(x.id), "name": String(x.name), "icon": String(x.icon), "rarity": clampi(int(x.get("rarity", 0)), 0, 5),
		"slot": "trophy", "level": 0, "quality": 1.0, "upgrade": 0, "affixes": {}}


## Objet de démonstration (toujours le même) pour une entrée du catalogue.
static func demo_item(e: Dictionary) -> Dictionary:
	seed(int(e.id))
	var it := Items.from_eden(e)
	randomize()
	return it
