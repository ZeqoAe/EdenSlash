class_name ArchivePages
extends RefCounted
## Pages de l'archive : la collection (catalogue de tout l'équipement du jeu, objets
## archivés, bonus et paliers, archivage depuis le coffre), seule page de l'écran
## Collection, et l'encyclopédie de tous les objets d'Eden (écran du mode dev).

const TIER_LABELS := {4: "Mythique", 5: "Légendaire"}


# --- collection --------------------------------------------------------------------------------
## Archive des trésors (comme dans Eden) : à gauche les catégories et leur taux, au centre
## toutes les entrées de la catégorie (équipements mythiques et légendaires, apparences,
## montures, familiers, boîte arcanique, autres objets), à droite la liste de l'archive
## (score, taux par groupe, bonus) et le dépôt depuis le coffre.
class CollectionPage extends HBoxContainer:
	const PER_PAGE := 120
	var _tree: VBoxContainer
	var _cat := ""
	var _head: Label
	var _rate: Label
	var _owned_only: CheckBox
	var _origin: OptionButton
	var _reverse: CheckBox
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
		ItemWidgets.section(left, "Archive des trésors")
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
		_origin = OptionButton.new()
		_origin.fit_to_longest_item = false
		_origin.custom_minimum_size = Vector2(150, 0)
		for t in ["Tous les trésors", "Trésors du jeu", "Trésors de la boutique"]:
			_origin.add_item(t)
		_origin.focus_mode = Control.FOCUS_NONE
		_origin.item_selected.connect(func(_i): _refresh_grid(0))
		fl.add_child(_origin)
		var fl2 := HBoxContainer.new()
		fl2.add_theme_constant_override("separation", 12)
		mid.add_child(fl2)
		_owned_only = CheckBox.new()
		_owned_only.text = "Obtenus uniquement"
		_owned_only.focus_mode = Control.FOCUS_NONE
		_owned_only.toggled.connect(func(_on): _refresh_grid(0))
		fl2.add_child(_owned_only)
		_reverse = CheckBox.new()
		_reverse.text = "Ordre inversé"
		_reverse.focus_mode = Control.FOCUS_NONE
		_reverse.toggled.connect(func(_on): _refresh_grid(0))
		fl2.add_child(_reverse)
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
		_detail = ItemWidgets.rich(mid, 13)
		_detail.custom_minimum_size = Vector2(0, 90)
		_detail.size_flags_vertical = Control.SIZE_FILL
		# liste de l'archive et dépôt
		var right := ItemWidgets.panel(self, 400)
		ItemWidgets.section(right, "Liste de l'archive")
		_list_text = ItemWidgets.rich(right, 13)
		_list_text.custom_minimum_size = Vector2(0, 250)
		_list_text.size_flags_vertical = Control.SIZE_FILL
		ItemWidgets.section(right, "Archiver depuis le coffre", 16)
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

	func refresh() -> void:
		if not is_inside_tree():
			return
		if _cat == "":
			_cat = String(Archive.categories()[0].id)
		_build_tree()
		_refresh_grid(_page)
		_refresh_list()
		_vault_grid.set_items(Profile.all_items().filter(func(it): return int(it.rarity) >= Items.ARCHIVE_MIN_RARITY))
		_vault_grid.set_empty_text("Aucun objet mythique ou légendaire dans le coffre : ils tombent des boss (et les mythiques se fabriquent).")
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
		_head.text = "Archive : " + cat_name
		_rate.text = "Taux : %.1f %%  (%d / %d)" % [100.0 * r.x / maxf(r.y, 1.0), int(r.x), int(r.y)]
		var q := _search.text.strip_edges().to_lower()
		var origin := _origin.selected
		var list := Archive.entries(_cat).filter(func(e):
			return (not _owned_only.button_pressed or Archive.owned(e)) and (q == "" or String(e.name).to_lower().contains(q)) \
				and (origin <= 0 or bool(e.get("mall", false)) == (origin == 2)))
		if _reverse.button_pressed:
			list.reverse()
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
		var info := "\n\n%s\n[color=#9a98a8]%s[/color]\n[color=#7fe08a]Bonus d'archive : %s[/color]" % [
			"[color=#7fe08a]Archivé[/color]" if owned else "[color=#ff9a7a]Pas encore archivé[/color]", Archive.source_text(e), Archive.bonus_text(Archive.entry_bonus(k))]
		s.card_extra = func(_it): return info
		s.pressed.connect(func():
			_selected_entry = e
			_selected_item = {}
			_armed = false
			_refresh_action())
		return s

	func _refresh_list() -> void:
		var lines: PackedStringArray = []
		lines.append("[b]Score total de l'archive : %d[/b]" % Archive.score())
		lines.append("Entrées : [b]%d[/b] / %d   (équipement : %d / %d)" % [Archive.count_all(), Archive.total(), Archive.count(), Archive.total_gear()])
		var groups := {}
		for c in Archive.categories():
			var r := Archive.rate(String(c.id))
			var g: Vector2 = groups.get(c.group, Vector2.ZERO)
			groups[c.group] = g + r
		for g in groups:
			var v: Vector2 = groups[g]
			lines.append("%s : %d / %d  (%.1f %%)" % [g, int(v.x), int(v.y), 100.0 * v.x / maxf(v.y, 1.0)])
		var b := Archive.bonus()
		lines.append("")
		lines.append("[color=#c8c8d4]Bonus permanent, toutes classes :[/color] [b]%s[/b]" % (Archive.bonus_text(b) if not b.is_empty() else "aucun pour l'instant"))
		lines.append("[color=#c8c8d4]Chaque entrée : +1 point d'attribut (mythique) ou +2 (légendaire).[/color]")
		var n := Archive.count()
		for m in Archive.MILESTONES:
			var ok := n >= int(m[0])
			lines.append("[color=%s]%s %d équipements : %s[/color]" % ["#7fe08a" if ok else "#8a86a0", "✔" if ok else "○", int(m[0]), Archive.bonus_text(m[1])])
		_list_text.text = "\n".join(lines)

	func _refresh_action() -> void:
		_btn.disabled = true
		if not _selected_item.is_empty():
			var why := Archive.refusal(_selected_item)
			_detail.text = "[b][color=#%s]%s[/color][/b]  %s" % [Items.color_of(_selected_item).to_html(false), Items.display_name(_selected_item),
				("[color=#ff9a7a]%s[/color]" % why) if why != "" else "[color=#7fe08a]Archiver : %s[/color]" % Archive.bonus_text(Archive.entry_bonus(Archive.keys_for(_selected_item)[0]))]
			_btn.text = "Confirmer : l'objet rejoint l'archive" if _armed else "Archiver"
			_btn.disabled = why != ""
			return
		if not _selected_entry.is_empty() and Archive.is_collection(_selected_entry):
			var got := Archive.owned(_selected_entry)
			var where := "onglet Tenues" if _selected_entry.has("aura") or int(_selected_entry.cat) <= 3 else ("onglet Apparences d'armes" if _selected_entry.has("skin") else "")
			_detail.text = "[b]%s[/b] — %s%s" % [_selected_entry.name, "[color=#7fe08a]obtenu[/color]" if got else Archive.source_text(_selected_entry),
				(" · se porte dans l'%s." % where) if got and where != "" else ""]
			_btn.text = "Archiver"
			return
		if not _selected_entry.is_empty():
			var k := Archive.key_of(_selected_entry)
			if Profile.archive.has(k):
				_detail.text = "[b]%s[/b] est archivé. Tu peux le retirer : il revient dans le coffre (son bonus est perdu)." % _selected_entry.name
				_btn.text = "Retirer de l'archive"
				_btn.disabled = Profile.in_run
			else:
				_detail.text = "[b]%s[/b] (niveau %d dans Eden) — %s" % [_selected_entry.name, int(_selected_entry.level), Archive.source_text(_selected_entry)]
				_btn.text = "Archiver"
			return
		_detail.text = "[color=#c8c8d4]Choisis une entrée (survol : fiche complète) ou un objet mythique / légendaire du coffre. Archiver retire l'objet du coffre et des préréglages ; on peut le retirer plus tard.[/color]"
		_btn.text = "Archiver"

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


## Case d'un trésor de collection (icône et rareté d'Eden, sans stats).
static func treasure_item(x: Dictionary) -> Dictionary:
	return {"uid": "c%d" % int(x.id), "name": String(x.name), "icon": String(x.icon), "rarity": clampi(int(x.get("rarity", 0)), 0, 5),
		"slot": "trophy", "level": 0, "quality": 1.0, "upgrade": 0, "affixes": {}}


## Objet de démonstration (toujours le même) pour une entrée d'Eden.
static func demo_item(e: Dictionary) -> Dictionary:
	seed(int(e.id))
	var it := Items.from_eden(e)
	randomize()
	return it


# --- encyclopédie : tous les objets d'Eden + mode dev ----------------------------------------
## Tous les équipements d'Eden (data/eden_catalog.json), les trésors de collection et les
## cosmétiques, filtrables (catégorie, type d'armure, rareté, niveaux, sets, archive, tri),
## par pièce ou regroupés par set et niveau ; le mode dev ajoute n'importe quel objet au
## coffre (ou au sac pendant une run), règle l'or et les matériaux de départ, la réserve de
## fournitures, la maîtrise et les déblocages.
class EncyclopediaPage extends HBoxContainer:
	const PER_PAGE := 128
	const GROUPS_PER_PAGE := 24
	var _cat: OptionButton
	var _armor: OptionButton
	var _rar: OptionButton
	var _view: OptionButton
	var _sort: OptionButton
	var _lvl_min: SpinBox
	var _lvl_max: SpinBox
	var _sets_only: CheckBox
	var _arch_only: CheckBox
	var _search: LineEdit
	var _count: Label
	var _page_lbl: Label
	var _body: VBoxContainer
	var _page := 0
	var _list: Array = []
	var _groups: Array = []  # [{title, items}]
	var _cats: Array = []  # [libellé, clé]
	var _selected: Dictionary = {}  # entrée d'Eden choisie
	var _preview: Dictionary = {}
	var _detail: RichTextLabel
	var _dev_box: VBoxContainer
	var _dev_toggle: CheckButton
	var _msg: Label

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		left.add_child(head)
		ItemWidgets.section(head, "Encyclopédie des objets d'Eden")
		_count = Hud._label(head, "", 14, UiTheme.MUTED)
		_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var filters := HBoxContainer.new()
		filters.add_theme_constant_override("separation", 8)
		left.add_child(filters)
		_cat = OptionButton.new()
		_cats = [["Tout l'équipement", ""], ["Armes (toutes)", "weapon"]]
		for wt in GameData.weapon_types:
			_cats.append(["  " + String(GameData.weapon_types[wt].name), "w:" + String(wt)])
		_cats.append(["  Boucliers", "s:shield"])
		for k in Archive.ARMOR_CLASS_FR:
			_cats.append([String(Archive.ARMOR_CLASS_FR[k]) + " (toutes pièces)", "a:" + String(k)])
		for sl in Items.ARMOR + Items.ACCESSORIES:
			_cats.append([String(Items.SLOT_NAMES[sl]), "s:" + String(sl)])
		for c in Archive.COLLECTION_CATS:
			_cats.append(["Trésors : %s (%s)" % [String(c[1]).to_lower(), String(c[2]).to_lower()], "c:%d" % int(c[0])])
		_cats.append(["Cosmétiques portables", "cosmetic"])
		for c in _cats:
			_cat.add_item(String(c[0]))
		_cat.item_selected.connect(func(_i):
			# armures : regroupées par set et niveau par défaut
			_view.select(1 if _key().begins_with("a:") else _view.selected)
			_apply_filters())
		filters.add_child(_cat)
		_cat.fit_to_longest_item = false
		_cat.clip_text = true
		_cat.custom_minimum_size = Vector2(250, 0)
		_armor = _option(filters, ["Toute armure", "Plates", "Cuir", "Tissu"])
		_armor.custom_minimum_size = Vector2(130, 0)
		_rar = OptionButton.new()
		_rar.add_item("Toutes raretés")
		for r in Items.RARITIES:
			_rar.add_item(String(r.name))
		_rar.item_selected.connect(func(_i): _apply_filters())
		_rar.fit_to_longest_item = false
		_rar.custom_minimum_size = Vector2(130, 0)
		filters.add_child(_rar)
		_search = LineEdit.new()
		_search.placeholder_text = "Rechercher un nom…"
		_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_search.text_changed.connect(func(_t): _apply_filters())
		filters.add_child(_search)
		var f2 := HBoxContainer.new()
		f2.add_theme_constant_override("separation", 8)
		left.add_child(f2)
		_view = _option(f2, ["Par pièce", "Par set et niveau"])
		_view.custom_minimum_size = Vector2(170, 0)
		_sort = _option(f2, ["Niveau ↑", "Niveau ↓", "Rareté", "Nom"])
		_sort.custom_minimum_size = Vector2(110, 0)
		Hud._label(f2, "Niveaux", 14, UiTheme.TEXT).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_lvl_min = _spin(f2, 1)
		Hud._label(f2, "à", 14, UiTheme.TEXT).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_lvl_max = _spin(f2, 100)
		_sets_only = CheckBox.new()
		_sets_only.text = "Sets"
		_sets_only.focus_mode = Control.FOCUS_NONE
		_sets_only.toggled.connect(func(_on): _apply_filters())
		f2.add_child(_sets_only)
		_arch_only = CheckBox.new()
		_arch_only.text = "Archive"
		_arch_only.tooltip_text = "Seulement les objets de l'archive d'Eden"
		_arch_only.focus_mode = Control.FOCUS_NONE
		_arch_only.toggled.connect(func(_on): _apply_filters())
		f2.add_child(_arch_only)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		f2.add_child(sp)
		var prev := Button.new()
		prev.text = "◀"
		prev.focus_mode = Control.FOCUS_NONE
		prev.pressed.connect(func(): _goto(_page - 1))
		f2.add_child(prev)
		_page_lbl = Hud._label(f2, "", 14, UiTheme.TEXT)
		_page_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nxt := Button.new()
		nxt.text = "▶"
		nxt.focus_mode = Control.FOCUS_NONE
		nxt.pressed.connect(func(): _goto(_page + 1))
		f2.add_child(nxt)
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(scroll)
		_body = VBoxContainer.new()
		_body.add_theme_constant_override("separation", 6)
		_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_body)

		var right := ItemWidgets.panel(self, 460)
		ItemWidgets.section(right, "Fiche")
		_detail = ItemWidgets.rich(right, 14)
		_detail.custom_minimum_size = Vector2(0, 220)
		_detail.size_flags_vertical = Control.SIZE_FILL
		_dev_toggle = CheckButton.new()
		_dev_toggle.text = "Mode dev"
		_dev_toggle.focus_mode = Control.FOCUS_NONE
		_dev_toggle.toggled.connect(func(on):
			Profile.dev["enabled"] = on
			Profile.save_profile()
			_build_dev())
		right.add_child(_dev_toggle)
		var dscroll := ScrollContainer.new()
		dscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		dscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		right.add_child(dscroll)
		_dev_box = VBoxContainer.new()
		_dev_box.add_theme_constant_override("separation", 6)
		_dev_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dscroll.add_child(_dev_box)
		_msg = Hud._label(right, "", 13, UiTheme.BUFF)

	func _option(parent: Control, labels: Array) -> OptionButton:
		var o := OptionButton.new()
		o.fit_to_longest_item = false
		o.clip_text = true
		for t in labels:
			o.add_item(String(t))
		o.focus_mode = Control.FOCUS_NONE
		o.item_selected.connect(func(_i): _apply_filters())
		parent.add_child(o)
		return o

	func _spin(parent: Control, v: int) -> SpinBox:
		var s := SpinBox.new()
		s.min_value = 1
		s.max_value = 100
		s.value = v
		s.custom_minimum_size = Vector2(64, 0)
		s.value_changed.connect(func(_v): _apply_filters())
		parent.add_child(s)
		return s

	func refresh() -> void:
		if not is_inside_tree():
			return
		_dev_toggle.set_pressed_no_signal(bool(Profile.dev.get("enabled", false)))
		_apply_filters()
		_build_dev()

	func _key() -> String:
		return String(_cats[_cat.selected][1]) if _cat.selected >= 0 else ""

	func _source() -> Array:
		var key := _key()
		if key == "cosmetic":
			return GameData.cosmetics
		if key.begins_with("c:"):
			return Archive.entries(key)
		if key == "":
			return GameData.eden_items
		if key == "weapon":
			return GameData.eden_items.filter(func(e): return e.slot == "weapon")
		if key.begins_with("a:"):
			return GameData.eden_items.filter(func(e): return String(e.get("armor", "")) == key.substr(2))
		return GameData.eden_by_slot.get(key.substr(2), [])

	func _apply_filters() -> void:
		var r := _rar.selected - 1
		var q := _search.text.strip_edges().to_lower()
		var armor: String = ["", "plates", "cuir", "tissu"][maxi(_armor.selected, 0)]
		var lo := int(_lvl_min.value)
		var hi := int(_lvl_max.value)
		var sets := _sets_only.button_pressed
		var arch := _arch_only.button_pressed
		_list = _source().filter(func(e):
			var lv := int(e.get("level", 0))
			return (r < 0 or int(e.get("rarity", 0)) == r) and (q == "" or String(e.name).to_lower().contains(q)) \
				and (armor == "" or not e.has("slot") or String(e.get("armor", armor)) == armor) \
				and (not e.has("level") or (lv >= lo and lv <= hi)) \
				and (not sets or e.has("set")) and (not arch or e.has("arch") or e.has("cat")))
		match _sort.selected:
			1:
				_list.sort_custom(func(a, b): return int(a.get("level", 0)) > int(b.get("level", 0)))
			2:
				_list.sort_custom(func(a, b): return [int(b.get("rarity", 0)), int(a.get("level", 0))] < [int(a.get("rarity", 0)), int(b.get("level", 0))])
			3:
				_list.sort_custom(func(a, b): return String(a.name) < String(b.name))
			_:
				_list.sort_custom(func(a, b): return [int(a.get("level", 0)), int(a.get("rarity", 0))] < [int(b.get("level", 0)), int(b.get("rarity", 0))])
		_groups = _make_groups(_list) if _view.selected == 1 else []
		_count.text = "%d entrées  (%d équipements, %d trésors de collection, %d cosmétiques d'Eden)" % [
			_list.size(), GameData.eden_items.size(), GameData.collection.size(), GameData.cosmetics.size()]
		_goto(0)

	## Regroupement par set (pièces d'un même set d'Eden), sinon par niveau et nom commun
	## (« Highland Supreme Helmet / Chestplate… » : même ensemble de ce niveau).
	func _make_groups(list: Array) -> Array:
		var by := {}
		var order: Array = []
		for e in list:
			var k := String(e.get("set", ""))
			if k == "":
				var words := String(e.name).split(" ")
				var prefix := " ".join(words.slice(0, words.size() - 1)) if words.size() > 1 and e.has("slot") else String(e.name)
				k = "L%03d|%s" % [int(e.get("level", 0)), prefix]
			if not by.has(k):
				by[k] = []
				order.append(k)
			by[k].append(e)
		var out: Array = []
		for k in order:
			var items: Array = by[k]
			var lv := int(items[0].get("level", 0))
			var rar := String(Items.RARITIES[clampi(int(items[0].get("rarity", 0)), 0, 5)].name)
			var title := ""
			if String(k).begins_with("e"):
				var sd := Items.set_def(String(k))
				title = "Niv. %d · Set « %s » · %s · %d / %d pièces" % [lv, String(sd.get("name", "?")), rar, items.size(), (sd.get("pieces", []) as Array).size()]
			else:
				var rars: PackedStringArray = []
				for it in items:
					var rn := String(Items.RARITIES[clampi(int(it.get("rarity", 0)), 0, 5)].name)
					if not rn in rars:
						rars.append(rn)
				var prefix := String(k).get_slice("|", 1)
				title = ("Niv. %d · « %s » · %s (%d)" % [lv, prefix, ", ".join(rars), items.size()]) if lv > 0 else "%s (%d)" % [prefix, items.size()]
			out.append({"title": title, "items": items})
		return out

	func _goto(p: int) -> void:
		for c in _body.get_children():
			c.queue_free()
		if _view.selected == 1:
			var pages := maxi(1, ceili(float(_groups.size()) / GROUPS_PER_PAGE))
			_page = clampi(p, 0, pages - 1)
			_page_lbl.text = "page %d / %d" % [_page + 1, pages]
			for g in _groups.slice(_page * GROUPS_PER_PAGE, (_page + 1) * GROUPS_PER_PAGE):
				var t := Hud._label(_body, String(g.title), 14, UiTheme.GOLD)
				t.add_theme_font_override("font", UiTheme.bold_font())
				var row := HFlowContainer.new()
				row.add_theme_constant_override("h_separation", 6)
				row.add_theme_constant_override("v_separation", 6)
				_body.add_child(row)
				for e in g.items:
					row.add_child(_cell(e))
			return
		var pages2 := maxi(1, ceili(float(_list.size()) / PER_PAGE))
		_page = clampi(p, 0, pages2 - 1)
		_page_lbl.text = "page %d / %d" % [_page + 1, pages2]
		var grid := GridContainer.new()
		grid.columns = 16
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		_body.add_child(grid)
		for e in _list.slice(_page * PER_PAGE, (_page + 1) * PER_PAGE):
			grid.add_child(_cell(e))

	## Objet de démonstration (toujours le même pour une entrée) pour la carte au survol.
	func _demo(e: Dictionary) -> Dictionary:
		if e.has("outfit"):
			return {"uid": "cos_%s" % e.id, "name": e.name, "icon": e.get("icon", ""), "rarity": int(e.get("rarity", 3)),
				"slot": "chest", "level": 0, "quality": 1.0, "upgrade": 0, "affixes": {}}
		if Archive.is_collection(e):
			return ArchivePages.treasure_item(e)
		seed(int(e.id))
		var it := Items.from_eden(e)
		randomize()
		return it

	func _cell(e: Dictionary) -> Control:
		var s := ItemWidgets.ItemSlot.new(58.0)
		var demo := _demo(e)
		s.set_item(demo)
		if Archive.is_collection(e):
			s.card_text = Archive.collection_text(e) + "\n\n[color=#9a98a8]%s[/color]" % ("Obtenu" if Profile.collected(e) else Archive.source_text(e))
			s.dim = not Profile.collected(e)
		elif e.has("outfit"):
			s.badge = "skin"
		else:
			s.badge = "Nv %d" % int(e.get("level", 1))
			var info := "\n\n[color=#9a98a8]%s[/color]" % Archive.source_text(e)
			s.card_extra = func(_it): return info
		s.pressed.connect(func():
			_selected = e
			_preview = demo
			_show_detail())
		s.activated.connect(func():
			_selected = e
			_preview = demo
			_show_detail()
			if Profile.dev.get("enabled", false):
				_give(e))
		return s

	func _show_detail() -> void:
		if _selected.is_empty():
			_detail.text = "[color=#c8c8d4]Clique un objet pour voir sa fiche. En mode dev : double-clic (ou bouton) pour l'ajouter.[/color]"
			return
		var e := _selected
		if e.has("outfit"):
			_detail.text = "[b]%s[/b]\n[color=#c8c8d4]Cosmétique d'Eden : se porte avec n'importe quelle classe (onglet Tenues).[/color]%s" % [
				e.name, "\n[color=#7fe08a]Débloquée[/color]" if Profile.outfit_unlocked(String(e.id)) else ""]
			return
		if Archive.is_collection(e):
			_detail.text = Archive.collection_text(e) + "\n\n" + ("[color=#7fe08a]Obtenu[/color]" if Profile.collected(e) else "[color=#9a98a8]%s[/color]" % Archive.source_text(e))
			return
		_detail.text = Items.describe(_preview) + "\n\n[color=#9a98a8]Objet d'Eden n° %d · %s[/color]" % [int(e.id), Archive.source_text(e)]

	func _give(e: Dictionary, n := 1) -> void:
		var added := 0
		for i in n:
			if e.has("outfit"):
				Profile.unlock_outfit(String(e.id))
				added = 1
				break
			if Archive.is_collection(e):
				Profile.collect(e)
				added = 1
				break
			if Profile.add_item(Items.from_eden(e)):
				added += 1
		Profile.save_profile()
		_msg.text = ("%s × %d ajouté %s." % [e.name, added, "à la collection" if Archive.is_collection(e) else ("au sac" if Profile.in_run else "au coffre")]) if added > 0 else "Plus de place !"
		_show_detail()

	func _build_dev() -> void:
		for c in _dev_box.get_children():
			c.queue_free()
		_show_detail()
		if not Profile.dev.get("enabled", false):
			Hud._label(_dev_box, "Mode dev : ajouter n'importe quel objet, régler l'or et les matériaux de départ, les fournitures, la maîtrise et les déblocages (pour tester).", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			return
		var give := HBoxContainer.new()
		_dev_box.add_child(give)
		for n in [1, 5]:
			var b := Button.new()
			b.text = "Ajouter ×%d %s" % [n, "au sac" if Profile.in_run else "au coffre"]
			b.focus_mode = Control.FOCUS_NONE
			var nn: int = n
			b.pressed.connect(func():
				if not _selected.is_empty():
					_give(_selected, nn))
			give.add_child(b)
		ItemWidgets.section(_dev_box, "Ressources au départ des runs" if not Profile.in_run else "Ressources de la run", 15)
		var names := {"gold": "Or", "fragment": "Fragments", "essence": "Essences", "crystal": "Cristaux"}
		for k in ["gold", "fragment", "essence", "crystal"]:
			var row := HBoxContainer.new()
			_dev_box.add_child(row)
			var l := Hud._label(row, String(names[k]), 14, UiTheme.TEXT)
			l.custom_minimum_size = Vector2(120, 0)
			var sp := SpinBox.new()
			sp.max_value = 10000000
			sp.step = 100 if k == "gold" else 10
			sp.value = int(Profile.dev.get(k, 0))
			sp.custom_minimum_size = Vector2(160, 0)
			var key: String = k
			sp.value_changed.connect(func(v):
				Profile.dev[key] = int(v)
				if Profile.in_run:
					if key == "gold":
						Profile.gold = int(v)
					else:
						Profile.materials[key] = int(v)
					Profile.changed.emit()
				Profile.save_profile())
			row.add_child(sp)
		ItemWidgets.section(_dev_box, "Fournitures (%s)" % ("sac" if Profile.in_run else "réserve"), 15)
		var srow := HBoxContainer.new()
		_dev_box.add_child(srow)
		var sup := OptionButton.new()
		var keys: Array = ["drill", "luck", "protect"]
		for g in Craft.GEMS:
			for t in Craft.GEM_TIERS.size():
				keys.append(Craft.gem_key(g, t))
		for en in Craft.ENCHANTS:
			for lv in range(1, Craft.MAX_SCROLL_LV + 1):
				keys.append(Craft.scroll_key(en, lv))
		for k in keys:
			sup.add_item(Craft.label(String(k)))
		sup.custom_minimum_size = Vector2(230, 0)
		srow.add_child(sup)
		for n in [1, 10]:
			var b := Button.new()
			b.text = "+%d" % n
			b.focus_mode = Control.FOCUS_NONE
			var nn: int = n
			b.pressed.connect(func():
				var k := String(keys[sup.selected])
				if Profile.in_run:
					Profile.add_bag(k, nn)
				else:
					Profile.stash[k] = int(Profile.stash.get(k, 0)) + nn
				Profile.save_profile()
				_msg.text = "%s +%d" % [Craft.label(k), nn])
			srow.add_child(b)
		ItemWidgets.section(_dev_box, "Maîtrise et déblocages", 15)
		var mrow := HBoxContainer.new()
		_dev_box.add_child(mrow)
		Hud._label(mrow, "Maîtrise de %s :" % GameData.class_data(Profile.selected_class).get("name_fr", ""), 14, UiTheme.TEXT)
		var ms := SpinBox.new()
		ms.min_value = 1
		ms.max_value = Profile.EXPERTISE_MAX
		ms.value = Profile.expertise_level(Profile.selected_class)
		ms.value_changed.connect(func(v):
			Profile.set_expertise_level(Profile.selected_class, int(v))
			Profile.save_profile())
		mrow.add_child(ms)
		var all_cls := Button.new()
		all_cls.text = "Débloquer toutes les classes"
		all_cls.focus_mode = Control.FOCUS_NONE
		all_cls.pressed.connect(func():
			for cid in GameData.classes:
				if cid != Progression.START_CLASS and not cid in Profile.unlocked_classes:
					Profile.unlocked_classes.append(cid)
			Profile.save_profile()
			_msg.text = "Toutes les classes sont débloquées.")
		_dev_box.add_child(all_cls)
		var all_z := Button.new()
		all_z.text = "Débloquer toutes les zones"
		all_z.focus_mode = Control.FOCUS_NONE
		all_z.pressed.connect(func():
			Profile.unlocked_zones = GameData.zones.size()
			Profile.save_profile()
			_msg.text = "Toutes les zones sont débloquées.")
		_dev_box.add_child(all_z)
		var all_o := Button.new()
		all_o.text = "Débloquer toutes les tenues (skins)"
		all_o.focus_mode = Control.FOCUS_NONE
		all_o.pressed.connect(func():
			for c in GameData.cosmetics:
				Profile.unlock_outfit(String(c.id))
			Profile.save_profile()
			_msg.text = "%d tenues débloquées." % GameData.cosmetics.size())
		_dev_box.add_child(all_o)
		var all_t := Button.new()
		all_t.text = "Obtenir tous les trésors de collection (auras, apparences…)"
		all_t.focus_mode = Control.FOCUS_NONE
		all_t.pressed.connect(func():
			for x in GameData.collection:
				Profile.collect(x)
			Profile.save_profile()
			_msg.text = "%d trésors obtenus." % GameData.collection.size())
		_dev_box.add_child(all_t)
