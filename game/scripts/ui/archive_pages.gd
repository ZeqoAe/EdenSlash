class_name ArchivePages
extends RefCounted
## Pages de l'archive (lobby) : la collection (catalogue de tout l'équipement du jeu,
## objets archivés, bonus et paliers, archivage depuis le coffre) et les apparences
## d'armes débloquées.

const TIER_LABELS := {2: "Rare", 3: "Épique", 4: "Légendaire"}


# --- collection --------------------------------------------------------------------------------
class CollectionPage extends HBoxContainer:
	var _catalog: VBoxContainer
	var _count: Label
	var _bar: ProgressBar
	var _bonus: RichTextLabel
	var _grid: ItemWidgets.ItemGrid
	var _detail: RichTextLabel
	var _btn: Button
	var _selected: Dictionary = {}
	var _armed := false

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		var lh := HBoxContainer.new()
		lh.add_theme_constant_override("separation", 12)
		left.add_child(lh)
		ItemWidgets.section(lh, "Catalogue de l'équipement")
		Hud._label(lh, "Survole une case : carte complète de l'objet archivé, ou où le trouver.", 13, UiTheme.MUTED).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(scroll)
		_catalog = VBoxContainer.new()
		_catalog.add_theme_constant_override("separation", 8)
		_catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_catalog)

		var right := ItemWidgets.panel(self, 560)
		var ch := HBoxContainer.new()
		ch.add_theme_constant_override("separation", 12)
		right.add_child(ch)
		ItemWidgets.section(ch, "Collection")
		_bar = ProgressBar.new()
		_bar.show_percentage = false
		_bar.custom_minimum_size = Vector2(200, 18)
		_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ch.add_child(_bar)
		_count = Hud._label(ch, "", 16, UiTheme.GOLD)
		_bonus = ItemWidgets.rich(right, 14)
		_bonus.custom_minimum_size = Vector2(0, 270)
		_bonus.size_flags_vertical = Control.SIZE_FILL
		ItemWidgets.section(right, "Archiver depuis le coffre", 16)
		_grid = ItemWidgets.ItemGrid.new(false, 7, 58.0)
		_grid.source = ""
		_grid.dim_fn = func(it): return Archive.refusal(it) != ""
		_grid.badge_fn = func(it): return "✔" if Archive.refusal(it) != "" else ""
		_grid.card_extra = _archive_extra
		_grid.selection_changed.connect(func():
			_selected = _grid.first_selected()
			_armed = false
			_refresh_detail())
		right.add_child(_grid)
		_detail = ItemWidgets.rich(right, 14)
		_detail.custom_minimum_size = Vector2(0, 96)
		_detail.size_flags_vertical = Control.SIZE_FILL
		_btn = ItemWidgets.action_button(right, "Archiver", _on_archive, 0, true)

	func refresh() -> void:
		if not is_inside_tree():
			return
		_build_catalog()
		var n := Archive.count()
		_bar.max_value = Archive.total()
		_bar.value = n
		_count.text = "%d / %d" % [n, Archive.total()]
		var lines: PackedStringArray = []
		var b := Archive.bonus()
		lines.append("[color=#c8c8d4]Bonus permanent, pour toutes les classes :[/color]")
		lines.append("[b]%s[/b]" % (Archive.bonus_text(b) if not b.is_empty() else "aucun pour l'instant"))
		lines.append("")
		lines.append("[color=#c8c8d4]Chaque entrée : +1 / +2 / +4 points d'attribut (rare / épique / légendaire), +1 % de dégâts par set.[/color]")
		for m in Archive.MILESTONES:
			var ok := n >= int(m[0])
			lines.append("[color=%s]%s %d entrées : %s[/color]" % ["#7fe08a" if ok else "#8a86a0", "✔" if ok else "○", int(m[0]), Archive.bonus_text(m[1])])
		_bonus.text = "\n".join(lines)
		_grid.set_items(Profile.all_items().filter(func(it): return int(it.rarity) >= Items.ARCHIVE_MIN_RARITY))
		_grid.set_empty_text("Aucun objet rare, épique ou légendaire dans le coffre : garde-en en fin de run pour les archiver.")
		_refresh_detail()

	func _build_catalog() -> void:
		for c in _catalog.get_children():
			c.queue_free()
		for g in Archive.groups():
			Hud._label(_catalog, String(g.name), 17, UiTheme.GOLD)
			var grid := GridContainer.new()
			grid.columns = 8
			grid.add_theme_constant_override("h_separation", 6)
			grid.add_theme_constant_override("v_separation", 6)
			_catalog.add_child(grid)
			for i in 2:
				Hud._label(grid, "", 12, UiTheme.MUTED)
				for t in Archive.TIERS:
					var l := Hud._label(grid, ArchivePages.TIER_LABELS[t], 12, Items.RARITIES[t].color)
					l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			for r in g.rows:
				var lbl := Hud._label(grid, String(r.name), 15, Color(0.92, 0.9, 1.0))
				lbl.custom_minimum_size = Vector2(96, 0)
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				for t in Archive.TIERS:
					grid.add_child(_entry_cell(String(r.id), String(r.name), String(r.slot), t))
		Hud._label(_catalog, "Sets", 17, Items.SET_COLOR)
		var sets := HFlowContainer.new()
		sets.add_theme_constant_override("h_separation", 10)
		sets.add_theme_constant_override("v_separation", 6)
		_catalog.add_child(sets)
		for sid in Items.SETS:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 0)
			sets.add_child(cell)
			var k := Archive.set_key(sid)
			var s := ItemWidgets.ItemSlot.new(58.0)
			s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			if Profile.archive.has(k):
				s.set_item(Profile.archive[k])
				s.card_extra = func(_it): return "\n\n[color=#7fe08a]Archivé · %s[/color]" % Archive.bonus_text(Archive.SET_BONUS)
			else:
				s.ghost = Archive.entry_icon("chest", "chest", 3)
				s.tooltip_text = "Set %s : pas encore archivé.\nArchive n'importe quelle pièce de ce set (cadre vert).\nBonus : %s" % [Items.SETS[sid].name, Archive.bonus_text(Archive.SET_BONUS)]
			cell.add_child(s)
			var l := Hud._label(cell, String(Items.SETS[sid].name), 12, Items.SET_COLOR if Profile.archive.has(k) else UiTheme.MUTED)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.custom_minimum_size = Vector2(96, 0)

	func _entry_cell(base: String, base_name: String, slot: String, t: int) -> Control:
		var k := Archive.key(base, t)
		var s := ItemWidgets.ItemSlot.new(58.0)
		if Profile.archive.has(k):
			s.set_item(Profile.archive[k])
			s.card_extra = func(_it): return "\n\n[color=#7fe08a]Archivé · %s[/color]" % Archive.bonus_text(Archive.entry_bonus(k))
		else:
			s.ghost = Archive.entry_icon(base, slot, t)
			s.tooltip_text = "%s : pas encore archivé.\n%s\nBonus à l'archivage : %s" % [Archive.entry_name(base_name, t), Archive.source_text(slot, t), Archive.bonus_text(Archive.entry_bonus(k))]
		return s

	func _archive_extra(it: Dictionary) -> String:
		var why := Archive.refusal(it)
		if why != "":
			return "\n\n[color=#ff9a7a]%s[/color]" % why
		var parts: PackedStringArray = []
		for k in Archive.keys_for(it):
			if not Profile.archive.has(k):
				parts.append(Archive.bonus_text(Archive.entry_bonus(k)))
		return "\n\n[color=#7fe08a]Archiver : %s[/color]" % ", ".join(parts)

	func _refresh_detail() -> void:
		if _selected.is_empty():
			_detail.text = "[color=#c8c8d4]Choisis un objet rare, épique ou légendaire du coffre. Archiver le consomme (il quitte le coffre et tes préréglages) et remplit son entrée du catalogue pour toujours.[/color]"
			_btn.disabled = true
			_btn.text = "Archiver"
			return
		var why := Archive.refusal(_selected)
		var users := Profile.item_users(String(_selected.get("uid", "")))
		_detail.text = "[b][color=#%s]%s[/color][/b]%s%s" % [Items.color_of(_selected).to_html(false), Items.display_name(_selected),
			_archive_extra(_selected), ("\n[color=#f5c75a]★ Utilisé par : %s (il sera retiré)[/color]" % ", ".join(users)) if not users.is_empty() else ""]
		_btn.disabled = why != ""
		_btn.text = "Confirmer : l'objet sera consommé" if _armed else "Archiver"

	func _on_archive() -> void:
		if _selected.is_empty() or Archive.refusal(_selected) != "":
			return
		if not _armed:
			_armed = true
			_refresh_detail()
			return
		_armed = false
		Profile.archive_item(_selected)
		_selected = {}
		_grid.clear_selection()
		refresh()


# --- apparences ------------------------------------------------------------------------------
class SkinsPage extends HBoxContainer:
	var _list: VBoxContainer
	var _preview: EquipmentPage.HeroPreview
	var _info: RichTextLabel
	var _shown_code := ""

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		ItemWidgets.section(left, "Apparences d'armes")
		Hud._label(left, "Les 2 premiers modèles de chaque arme sont libres ; archiver une arme rare débloque le 3e, une arme épique ou légendaire le 4e. L'apparence s'applique à toutes les armes de ce type, quelle que soit la classe.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(scroll)
		_list = VBoxContainer.new()
		_list.add_theme_constant_override("separation", 10)
		scroll.add_child(_list)
		var right := ItemWidgets.panel(self, 420)
		ItemWidgets.section(right, "Aperçu")
		_preview = EquipmentPage.HeroPreview.new()
		_preview.custom_minimum_size = Vector2(380, 460)
		_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(_preview)
		_info = ItemWidgets.rich(right, 14)
		_info.custom_minimum_size = Vector2(0, 90)
		_info.size_flags_vertical = Control.SIZE_FILL

	func refresh() -> void:
		if not is_inside_tree():
			return
		for c in _list.get_children():
			c.queue_free()
		for wt in GameData.weapon_types:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			_list.add_child(row)
			var lbl := Hud._label(row, String(GameData.weapon_types[wt].name), 17, Color(0.92, 0.9, 1.0))
			lbl.custom_minimum_size = Vector2(110, 0)
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(_cell(wt, -1, {}))
			var ws := Archive.skins(wt)
			for i in ws.size():
				row.add_child(_cell(wt, i, ws[i]))
		if _shown_code == "":
			_shown_code = Profile.weapon_code()
		_preview.show_hero(Profile.selected_class, _shown_code)
		var w: Dictionary = Profile.equipped.get("weapon", {})
		_info.text = "[color=#c8c8d4]Arme portée par %s : [/color][b]%s[/b]\n[color=#c8c8d4]Clique un modèle débloqué pour le choisir (« Auto » : le modèle de l'arme elle-même).[/color]" % [
			GameData.class_data(Profile.selected_class).get("name_fr", ""), Items.display_name(w) if not w.is_empty() else "aucune"]

	## Case d'apparence ([param i] = -1 : modèle de l'arme elle-même).
	func _cell(wt: String, i: int, w: Dictionary) -> Control:
		var current := String(Profile.skins.get(wt, ""))
		var code := String(w.get("code", ""))
		var on := current == code
		var ok := i < 0 or Archive.skin_unlocked(wt, i)
		var b := Button.new()
		b.custom_minimum_size = Vector2(76, 76)
		b.focus_mode = Control.FOCUS_NONE
		var sb := UiTheme.flat_box(Color(0.08, 0.06, 0.13, 0.95), UiTheme.GOLD if on else (UiTheme.GOLD_DIM if ok else Color(0.25, 0.23, 0.3)), 3 if on else 2, 8)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.15, 0.11, 0.24, 1.0), UiTheme.GOLD, 2, 8))
		if i < 0:
			b.text = "Auto"
			b.tooltip_text = "Modèle de l'arme portée"
		else:
			var ic := TextureRect.new()
			ic.texture = UiTheme.texture(String(w.get("icon", "")))
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.set_anchors_preset(Control.PRESET_FULL_RECT)
			ic.offset_left = 8
			ic.offset_top = 8
			ic.offset_right = -8
			ic.offset_bottom = -8
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic.modulate = Color.WHITE if ok else Color(0.25, 0.25, 0.3, 0.8)
			b.add_child(ic)
			if not ok:
				b.text = "🔒"
			b.tooltip_text = "Modèle %d (%s)%s" % [i + 1, code, "" if ok else "\nVerrouillé : " + Archive.skin_hint(i)]
		b.pressed.connect(func():
			_shown_code = code if code != "" else String(Profile.equipped.get("weapon", {}).get("weapon", ""))
			if ok:
				Profile.set_skin(wt, code)
			refresh())
		return b


# --- encyclopédie : tous les objets d'Eden + mode dev ----------------------------------------
## Tous les équipements d'Eden (data/eden_items.json) et les cosmétiques, filtrables ;
## le mode dev ajoute n'importe quel objet au coffre (ou au sac pendant une run), règle
## l'or et les matériaux de départ, la réserve de fournitures, la maîtrise et les déblocages.
class EncyclopediaPage extends HBoxContainer:
	const PER_PAGE := 128
	var _cat: OptionButton
	var _rar: OptionButton
	var _search: LineEdit
	var _count: Label
	var _page_lbl: Label
	var _grid: GridContainer
	var _page := 0
	var _list: Array = []
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
		for s in Items.ARMOR + Items.ACCESSORIES:
			_cats.append([String(Items.SLOT_NAMES[s]), "s:" + String(s)])
		_cats.append(["Cosmétiques (tenues)", "cosmetic"])
		for c in _cats:
			_cat.add_item(String(c[0]))
		_cat.item_selected.connect(func(_i): _apply_filters())
		filters.add_child(_cat)
		_rar = OptionButton.new()
		_rar.add_item("Toutes raretés")
		for r in Items.RARITIES:
			_rar.add_item(String(r.name))
		_rar.item_selected.connect(func(_i): _apply_filters())
		filters.add_child(_rar)
		_search = LineEdit.new()
		_search.placeholder_text = "Rechercher un nom…"
		_search.custom_minimum_size = Vector2(240, 0)
		_search.text_changed.connect(func(_t): _apply_filters())
		filters.add_child(_search)
		var prev := Button.new()
		prev.text = "◀"
		prev.focus_mode = Control.FOCUS_NONE
		prev.pressed.connect(func(): _goto(_page - 1))
		filters.add_child(prev)
		_page_lbl = Hud._label(filters, "", 14, UiTheme.TEXT)
		_page_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nxt := Button.new()
		nxt.text = "▶"
		nxt.focus_mode = Control.FOCUS_NONE
		nxt.pressed.connect(func(): _goto(_page + 1))
		filters.add_child(nxt)
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(scroll)
		_grid = GridContainer.new()
		_grid.columns = 16
		_grid.add_theme_constant_override("h_separation", 6)
		_grid.add_theme_constant_override("v_separation", 6)
		scroll.add_child(_grid)

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

	func refresh() -> void:
		if not is_inside_tree():
			return
		_dev_toggle.set_pressed_no_signal(bool(Profile.dev.get("enabled", false)))
		_apply_filters()
		_build_dev()

	func _source() -> Array:
		var key := String(_cats[_cat.selected][1]) if _cat.selected >= 0 else ""
		if key == "cosmetic":
			return GameData.cosmetics
		if key == "":
			return GameData.eden_items
		if key == "weapon":
			return GameData.eden_items.filter(func(e): return e.slot == "weapon")
		return GameData.eden_by_slot.get(key.substr(2), [])

	func _apply_filters() -> void:
		var r := _rar.selected - 1
		var q := _search.text.strip_edges().to_lower()
		_list = _source().filter(func(e):
			return (r < 0 or int(e.get("rarity", 0)) == r) and (q == "" or String(e.name).to_lower().contains(q)))
		_count.text = "%d objets  (%d équipements et %d cosmétiques d'Eden)" % [_list.size(), GameData.eden_items.size(), GameData.cosmetics.size()]
		_goto(0)

	func _goto(p: int) -> void:
		var pages := maxi(1, ceili(float(_list.size()) / PER_PAGE))
		_page = clampi(p, 0, pages - 1)
		_page_lbl.text = "page %d / %d" % [_page + 1, pages]
		for c in _grid.get_children():
			c.queue_free()
		for e in _list.slice(_page * PER_PAGE, (_page + 1) * PER_PAGE):
			_grid.add_child(_cell(e))

	## Objet de démonstration (toujours le même pour une entrée) pour la carte au survol.
	func _demo(e: Dictionary) -> Dictionary:
		if e.has("outfit"):
			return {"uid": "cos_%s" % e.id, "name": e.name, "icon": e.get("icon", ""), "rarity": int(e.get("rarity", 3)),
				"slot": "chest", "level": 1, "quality": 1.0, "upgrade": 0, "affixes": {}}
		seed(int(e.id))
		var it := Items.from_eden(e)
		randomize()
		return it

	func _cell(e: Dictionary) -> Control:
		var s := ItemWidgets.ItemSlot.new(58.0)
		var demo := _demo(e)
		s.set_item(demo)
		s.badge = ("Nv %d" % int(e.get("level", 1))) if not e.has("outfit") else "skin"
		var info := "\n\n[color=#9a98a8]Eden : %s · niveau %d%s[/color]" % [e.name, int(e.get("level", 1)),
			(" · " + String(e.cn)) if String(e.get("cn", "")) != "" else ""]
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
			_detail.text = "[b]%s[/b]\n[color=#c8c8d4]Cosmétique d'Eden : tenue utilisable comme skin de n'importe quelle classe (onglet Apparences).[/color]%s" % [
				e.name, "\n[color=#7fe08a]Débloquée[/color]" if Profile.outfit_unlocked(String(e.id)) else ""]
			return
		_detail.text = Items.describe(_preview) + "\n\n[color=#9a98a8]Objet d'Eden n° %d · niveau requis dans Eden : %d[/color]" % [int(e.id), int(e.level)]

	func _give(e: Dictionary, n := 1) -> void:
		var added := 0
		for i in n:
			if e.has("outfit"):
				Profile.unlock_outfit(String(e.id))
				added = 1
				break
			if Profile.add_item(Items.from_eden(e)):
				added += 1
		Profile.save_profile()
		_msg.text = ("%s × %d ajouté %s." % [e.name, added, "au sac" if Profile.in_run else "au coffre"]) if added > 0 else "Plus de place !"
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


# --- tenues (skins cosmétiques) ------------------------------------------------------------
## Costumes d'Eden débloqués (butin des boss, mode dev) : n'importe quelle classe peut
## porter n'importe quelle tenue ; « Tenue de la classe » revient à l'apparence d'origine.
class CostumesPage extends HBoxContainer:
	var _grid: GridContainer
	var _preview: EquipmentPage.HeroPreview
	var _info: RichTextLabel
	var _count: Label

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		left.add_child(head)
		ItemWidgets.section(head, "Tenues")
		_count = Hud._label(head, "", 14, UiTheme.MUTED)
		_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(ClassPicker.button(func(): return Profile.selected_class, func(cid):
			Profile.selected_class = cid
			Profile.save_profile()
			refresh(), false, Vector2(240, 40)))
		Hud._label(left, "Les costumes d'Eden se débloquent sur les boss (1 chance sur 4, plus s'ils sont enragés). Une tenue débloquée se porte avec n'importe quelle classe.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(scroll)
		_grid = GridContainer.new()
		_grid.columns = 6
		_grid.add_theme_constant_override("h_separation", 8)
		_grid.add_theme_constant_override("v_separation", 8)
		scroll.add_child(_grid)
		var right := ItemWidgets.panel(self, 420)
		ItemWidgets.section(right, "Aperçu")
		_preview = EquipmentPage.HeroPreview.new()
		_preview.custom_minimum_size = Vector2(380, 460)
		_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(_preview)
		_info = ItemWidgets.rich(right, 14)
		_info.custom_minimum_size = Vector2(0, 80)
		_info.size_flags_vertical = Control.SIZE_FILL

	func refresh() -> void:
		if not is_inside_tree():
			return
		for c in _grid.get_children():
			c.queue_free()
		var cid := Profile.selected_class
		var owned := GameData.cosmetics.filter(func(c): return Profile.outfit_unlocked(String(c.id)))
		_count.text = "%d / %d débloquées" % [owned.size(), GameData.cosmetics.size()]
		_grid.add_child(_cell({}, cid))
		for c in GameData.cosmetics:
			_grid.add_child(_cell(c, cid))
		_preview.show_hero(cid, Profile.weapon_code())
		var cur := Profile.outfit_of(cid)
		var name := "tenue de la classe"
		for c in GameData.cosmetics:
			if String(c.outfit) == cur:
				name = String(c.name)
		_info.text = "[b]%s[/b] porte : %s" % [GameData.class_data(cid).get("name_fr", cid), name]

	func _cell(c: Dictionary, cid: String) -> Control:
		var ok := c.is_empty() or Profile.outfit_unlocked(String(c.id))
		var on := Profile.outfit_of(cid) == String(c.get("outfit", ""))
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 96)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 48)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.08, 0.06, 0.13, 0.95), UiTheme.GOLD if on else (UiTheme.GOLD_DIM if ok else Color(0.25, 0.23, 0.3)), 3 if on else 2, 8))
		if c.is_empty():
			b.text = "Tenue de la classe"
			b.icon = UiTheme.texture(String(GameData.class_data(cid).get("icon", "")))
		else:
			b.text = String(c.name) if ok else "🔒 " + String(c.name)
			b.icon = UiTheme.texture(String(c.get("icon", "")))
			b.tooltip_text = String(c.name) + ("" if ok else "\nVerrouillée : butin des boss")
			if not ok:
				b.modulate = Color(0.6, 0.6, 0.65)
		b.pressed.connect(func():
			if not ok:
				return
			if c.is_empty():
				Profile.outfits.erase(cid)
			else:
				Profile.outfits[cid] = String(c.outfit)
			Profile.save_profile()
			refresh())
		return b
