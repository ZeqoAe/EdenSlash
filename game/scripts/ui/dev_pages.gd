class_name DevPages
## Pages de l'écran du mode dev (DevScreen, touche F10) : catalogue complet, ressources,
## progression et actions pendant la run.


# --- objets : tout le catalogue ---------------------------------------------------------------
## Tous les équipements d'Eden (data/eden_catalog.json), les trésors de collection et les
## cosmétiques, filtrables (catégorie, type d'armure, rareté, niveaux, sets, archive, tri),
## par pièce ou regroupés par set et niveau ; ajoute n'importe quel objet au coffre (ou au
## sac pendant une run) ×1 / ×5, avec la rareté et le niveau de puissance choisis.
class ItemsPage extends HBoxContainer:
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
	var _give_rar: OptionButton
	var _give_power: SpinBox
	var _give_buttons: Array[Button] = []
	var _msg: Label

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		left.add_child(head)
		ItemWidgets.section(head, "Catalogue complet")
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
		ItemWidgets.section(right, "Ajouter", 16)
		var g1 := HBoxContainer.new()
		g1.add_theme_constant_override("separation", 8)
		right.add_child(g1)
		Hud._label(g1, "Rareté", 14, UiTheme.TEXT).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_give_rar = OptionButton.new()
		_give_rar.add_item("Celle d'Eden")
		for r in Items.RARITIES:
			_give_rar.add_item(String(r.name))
		_give_rar.focus_mode = Control.FOCUS_NONE
		_give_rar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g1.add_child(_give_rar)
		var g2 := HBoxContainer.new()
		g2.add_theme_constant_override("separation", 8)
		right.add_child(g2)
		var pl := Hud._label(g2, "Niveau de puissance (0 : auto)", 14, UiTheme.TEXT)
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pl.tooltip_text = "Niveau de run où l'objet serait tombé : il règle la force de ses stats.\n0 : d'après son niveau d'Eden."
		pl.mouse_filter = Control.MOUSE_FILTER_PASS
		_give_power = SpinBox.new()
		_give_power.min_value = 0
		_give_power.max_value = 100
		_give_power.custom_minimum_size = Vector2(90, 0)
		g2.add_child(_give_power)
		var g3 := HBoxContainer.new()
		g3.add_theme_constant_override("separation", 8)
		right.add_child(g3)
		for n in [1, 5]:
			var b := Button.new()
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(0, 40)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var nn: int = n
			b.pressed.connect(func():
				if not _selected.is_empty():
					_give(_selected, nn))
			g3.add_child(b)
			_give_buttons.append(b)
		Hud._label(right, "Double-clic sur un objet : ×1. Les trésors et tenues sont ajoutés à la collection.", 12, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		for i in _give_buttons.size():
			_give_buttons[i].text = "Ajouter ×%d %s" % [[1, 5][i], "au sac" if Profile.in_run else "au coffre"]
		_apply_filters()
		_show_detail()

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
			_give(e))
		return s

	func _show_detail() -> void:
		if _selected.is_empty():
			_detail.text = "[color=#c8c8d4]Clique un objet pour voir sa fiche ; double-clic (ou bouton) pour l'ajouter.[/color]"
			return
		var e := _selected
		if _preview.is_empty():
			_preview = _demo(e)
		if e.has("outfit"):
			_detail.text = "[b]%s[/b]\n[color=#c8c8d4]Cosmétique d'Eden : se porte avec n'importe quelle classe (Héros > Apparence).[/color]%s" % [
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
			if Profile.add_item(make_item(e)):
				added += 1
		Profile.save_profile()
		_msg.text = ("%s × %d ajouté %s." % [e.name, added, "à la collection" if Archive.is_collection(e) else ("au sac" if Profile.in_run else "au coffre")]) if added > 0 else "Plus de place !"
		_show_detail()

	## Objet d'Eden avec la rareté et le niveau de puissance choisis.
	func make_item(e: Dictionary) -> Dictionary:
		var power := int(_give_power.value)
		var it := Items.from_template(e, power if power > 0 else GameData.power_level_of(int(e.level)), _give_rar.selected - 1)
		return it


## Bouton de la page (texte, action).
static func button(parent: Control, text: String, cb: Callable, width := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, 38)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Demande confirmation avant de toucher à la sauvegarde du joueur.
static func confirm(host: Node, text: String, cb: Callable) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Mode dev"
	d.dialog_text = text + "\n\nCela modifie ta sauvegarde (%d)." % Profile.slot
	d.ok_button_text = "Confirmer"
	d.cancel_button_text = "Annuler"
	d.process_mode = Node.PROCESS_MODE_ALWAYS
	d.confirmed.connect(cb)
	d.visibility_changed.connect(func():
		if not d.visible:
			d.queue_free())
	host.add_child(d)
	d.popup_centered()


static func column(parent: Control, title: String, width := 0.0) -> VBoxContainer:
	var v := ItemWidgets.panel(parent, width, width == 0.0)
	ItemWidgets.section(v, title)
	return v


# --- ressources --------------------------------------------------------------------------------
## Or et matériaux (de la run en cours, ou donnés au départ de chaque run en mode dev),
## fournitures (sac de la run ou réserve emportée à la run suivante).
class ResourcesPage extends HBoxContainer:
	var _box: VBoxContainer
	var _supplies: VBoxContainer
	var _msg: Label

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		_box = DevPages.column(self, "Or, clés, cristaux, coffres", 560)
		_supplies = DevPages.column(self, "Fournitures")
		_msg = Hud._label(_supplies, "", 14, UiTheme.BUFF)

	func refresh() -> void:
		if not is_inside_tree():
			return
		for c in _box.get_children().slice(1):
			c.queue_free()
		for c in _supplies.get_children().slice(1):
			if c != _msg:
				c.queue_free()
		Hud._label(_box, ("Valeurs de la run en cours." if Profile.in_run else "Or et clés : donnés au départ de chaque run tant que le mode dev est activé.") + " Cristaux : ceux de la sauvegarde (gardés entre les runs).", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var names := {"gold": "Or", "keys": "Clés", "crystal": "Cristaux"}
		for k in ["gold", "keys", "crystal"]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			_box.add_child(row)
			var l := Hud._label(row, String(names[k]), 16, UiTheme.TEXT)
			l.custom_minimum_size = Vector2(140, 0)
			var sp := SpinBox.new()
			sp.max_value = 10000000
			sp.step = 1
			sp.custom_minimum_size = Vector2(180, 0)
			sp.value = Profile.amount(k) if Profile.in_run or k == "crystal" else int(Profile.dev.get(k, 0))
			var key: String = k
			sp.value_changed.connect(func(v): _set_res(key, int(v)))
			row.add_child(sp)
			for add in [100, 1000] if k == "gold" else ([1, 5] if k == "keys" else [10, 100]):
				var a: int = add
				DevPages.button(row, "+%d" % a, func(): sp.value += a, 70)
		ItemWidgets.section(_box, "Coffres de récompense (hors run)", 15)
		var cg := GridContainer.new()
		cg.columns = 2
		_box.add_child(cg)
		for t in Rewards.ORDER:
			var tt: String = t
			DevPages.button(cg, "+1 %s" % Rewards.TYPES[t].name, func():
				var ch := Rewards.make(tt, 20)
				if Profile.in_run:
					Run.chests_found.append(ch)
				else:
					Profile.reward_chests.append(ch)
					Profile.save_profile()
				_msg.text = "%s ajouté %s" % [Rewards.TYPES[tt].name, "(gardé si tu t'en sors)" if Profile.in_run else "au menu Coffres"], 250)
		var sv := HBoxContainer.new()
		_supplies.add_child(sv)
		_supplies.move_child(_msg, -1)
		Hud._label(sv, "Dans le sac de la run" if Profile.in_run else "Dans la réserve (emportée à la prochaine run)", 13, UiTheme.MUTED)
		var keys: Array = ["drill", "luck", "protect"]
		for g in Craft.GEMS:
			for t in Craft.GEM_TIERS.size():
				keys.append(Craft.gem_key(g, t))
		for en in Craft.ENCHANTS:
			for lv in range(1, Craft.MAX_SCROLL_LV + 1):
				keys.append(Craft.scroll_key(en, lv))
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_supplies.add_child(scroll)
		_supplies.move_child(_msg, -1)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 24)
		scroll.add_child(grid)
		for k in keys:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			grid.add_child(row)
			var have := int(Profile.bag.get(k, 0)) if Profile.in_run else int(Profile.stash.get(k, 0))
			var l := Hud._label(row, "%s  (%d)" % [Craft.label(String(k)), have], 14, UiTheme.TEXT)
			l.custom_minimum_size = Vector2(260, 0)
			for n in [1, 10]:
				var nn: int = n
				var kk := String(k)
				DevPages.button(row, "+%d" % n, func():
					if Profile.in_run:
						Profile.add_bag(kk, nn)
					else:
						Profile.stash[kk] = int(Profile.stash.get(kk, 0)) + nn
					Profile.save_profile()
					_msg.text = "%s +%d" % [Craft.label(kk), nn]
					l.text = "%s  (%d)" % [Craft.label(kk), int(Profile.bag.get(kk, 0)) if Profile.in_run else int(Profile.stash.get(kk, 0))], 54)

	func _set_res(key: String, v: int) -> void:
		if Profile.in_run or key == "crystal":
			Profile.set_amount(key, v)
			Profile.changed.emit()
		else:
			Profile.dev[key] = v
		Profile.save_profile()


# --- progression ------------------------------------------------------------------------------
## Maîtrise de la classe, déblocages (classes, zones, tenues, trésors) ; chaque action
## demande confirmation.
class ProgressPage extends HBoxContainer:
	var _box: VBoxContainer
	var _msg: Label
	var _mastery: SpinBox

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		_box = DevPages.column(self, "Progression du joueur", 620)
		var right := DevPages.column(self, "État de la sauvegarde")
		_msg = Hud._label(right, "", 14, UiTheme.BUFF)
		_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	func refresh() -> void:
		if not is_inside_tree():
			return
		for c in _box.get_children().slice(1):
			c.queue_free()
		var cid := Profile.selected_class
		var mrow := HBoxContainer.new()
		mrow.add_theme_constant_override("separation", 10)
		_box.add_child(mrow)
		Hud._label(mrow, "Maîtrise de %s :" % GameData.class_data(cid).get("name_fr", cid), 16, UiTheme.TEXT)
		_mastery = SpinBox.new()
		_mastery.min_value = 1
		_mastery.max_value = Profile.EXPERTISE_MAX
		_mastery.value = Profile.expertise_level(cid)
		mrow.add_child(_mastery)
		DevPages.button(mrow, "Appliquer", func():
			var lv := int(_mastery.value)
			DevPages.confirm(self, "Maîtrise de %s au niveau %d ?" % [GameData.class_data(cid).get("name_fr", cid), lv], func():
				Profile.set_expertise_level(cid, lv)
				Profile.save_profile()
				_done("Maîtrise réglée au niveau %d." % lv)), 120)
		for a in [
			["Débloquer toutes les classes", "Débloquer les %d classes ?" % GameData.classes.size(), func():
				for c in GameData.classes:
					if c != Progression.START_CLASS and not c in Profile.unlocked_classes:
						Profile.unlocked_classes.append(c)
				return "Toutes les classes sont débloquées."],
			["Débloquer toutes les zones", "Débloquer les %d zones ?" % GameData.zones.size(), func():
				Profile.unlocked_zones = GameData.zones.size()
				return "Toutes les zones sont débloquées."],
			["Débloquer toutes les tenues", "Débloquer les %d tenues, chapeaux et dos ?" % GameData.cosmetics.size(), func():
				for c in GameData.cosmetics:
					Profile.unlock_outfit(String(c.id))
				return "%d tenues débloquées." % GameData.cosmetics.size()],
			["Obtenir tous les trésors de collection", "Obtenir les %d trésors (auras, apparences…) ?" % GameData.collection.size(), func():
				for x in GameData.collection:
					Profile.collect(x)
				return "%d trésors obtenus." % GameData.collection.size()],
		]:
			var act: Callable = a[2]
			var q := String(a[1])
			DevPages.button(_box, String(a[0]), func():
				DevPages.confirm(self, q, func():
					var t: String = act.call()
					Profile.save_profile()
					_done(t)))
		_done("")

	func _done(t: String) -> void:
		_msg.text = ("%s\n\n" % t if t != "" else "") + "Classes débloquées : %d / %d\nZones : %d / %d\nTenues : %d / %d\nTrésors : %d / %d\nMaîtrise de la classe : %d" % [
			GameData.classes.keys().filter(func(c): return Progression.class_unlocked(c)).size(), GameData.classes.size(),
			Profile.unlocked_zones, GameData.zones.size(),
			GameData.cosmetics.filter(func(c): return Profile.outfit_unlocked(String(c.id))).size(), GameData.cosmetics.size(),
			GameData.collection.filter(func(x): return Profile.collected(x)).size(), GameData.collection.size(),
			Profile.expertise_level(Profile.selected_class)]


# --- run ---------------------------------------------------------------------------------------
## Actions pendant la run : niveau, invincibilité, soins, monstres, apparitions, donjon, rage.
class RunActionsPage extends HBoxContainer:
	var world: Node  # world.gd
	var _box: VBoxContainer
	var _msg: Label

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		_box = DevPages.column(self, "Héros et monstres", 520)
		var right := DevPages.column(self, "Apparitions et carte")
		var p: Player = world.player
		var d: RunDirector = world.director
		var lv := HBoxContainer.new()
		lv.add_theme_constant_override("separation", 8)
		_box.add_child(lv)
		for n in [1, 5, 10]:
			var nn: int = n
			DevPages.button(lv, "Niveau +%d" % n, func():
				for i in nn:
					p.gain_xp(GameData.xp_to_next(p.level) - p.xp)
				_say("Niveau %d" % p.level), 130)
		var inv := CheckButton.new()
		inv.text = "Invincible"
		inv.focus_mode = Control.FOCUS_NONE
		inv.button_pressed = p.dev_invincible
		inv.toggled.connect(func(on):
			p.dev_invincible = on
			_say("Invincible" if on else "Invincibilité retirée"))
		_box.add_child(inv)
		DevPages.button(_box, "Soigner complètement", func():
			p.heal(p.max_hp)
			_say("PV au maximum"))
		DevPages.button(_box, "Tuer tous les monstres", func(): _say("%d monstre(s) tué(s)" % d.dev_kill_all()))
		_msg = Hud._label(_box, "", 15, UiTheme.BUFF)
		for a in [["Faire apparaître une élite", func(): d.dev_spawn_elite(), "Élite"],
				["Faire apparaître le boss de la zone", func(): d.dev_spawn_boss(), "Boss"],
				["Faire apparaître un coffre", func(): d.dev_spawn_chest(), "Coffre"],
				["Faire apparaître un marchand ambulant", func(): d.dev_spawn_merchant(), "Marchand"],
				["Capturer le sanctuaire le plus proche", func(): d.dev_capture_nearest(), "Sanctuaire capturé"],
				["Passer en rage", func(): d.debug_start_rage(), "Rage dans un instant"],
				["Téléporter à l'entrée du donjon", func(): d.teleport_to_gateway(), "Téléporté"],
				["Entrer dans le donjon (salle du boss)", func(): d.debug_enter_dungeon(), "Donjon"]]:
			var cb: Callable = a[1]
			var t := String(a[2])
			DevPages.button(right, String(a[0]), func():
				cb.call()
				_say(t))

	func _say(t: String) -> void:
		_msg.text = t
