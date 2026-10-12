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
