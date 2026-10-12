class_name MerchantPages
extends RefCounted
## Pages du marchand ambulant (voir MerchantUI) : Boutique, Vendre, Fabriquer ; et la Forge
## (ForgePage), ouverte depuis la fiche d'un objet pendant la run : améliorer à l'or,
## réforger et polir avec des cristaux, percer, sertir, enchanter, fusionner des gemmes.


## Base : grille d'objets à gauche, détail et actions à droite.
class ItemPage extends HBoxContainer:
	var ui  # hôte : message(text, duration) et player (MerchantUI, ForgeScreen)
	var multi := false
	var scroll_actions := false  # actions nombreuses : colonne de droite défilante
	var include_equipped := true
	var title := ""
	var hint := ""
	var grid: ItemWidgets.ItemGrid
	var detail: RichTextLabel
	var actions: VBoxContainer
	var _confirm_at := -10.0

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		ItemWidgets.section(left, title)
		var h := Hud._label(left, hint, 13, UiTheme.MUTED)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid = ItemWidgets.ItemGrid.new(multi, 10, 62.0)
		grid.badge_fn = func(it): return "porté" if _worn(it) else ""
		grid.selection_changed.connect(_on_selection)
		left.add_child(grid)
		var right := ItemWidgets.panel(self, 520)
		detail = ItemWidgets.rich(right, 15)
		actions = VBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		if scroll_actions:
			detail.fit_content = false
			detail.scroll_active = true
			detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var sc := ScrollContainer.new()
			sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			right.add_child(sc)
			actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sc.add_child(actions)
		else:
			right.add_child(actions)

	func items() -> Array:
		return (Profile.equipped.values() + Profile.inventory) if include_equipped else Profile.inventory.duplicate()

	func _worn(it: Dictionary) -> bool:
		return Profile.equipped.values().any(func(x): return is_same(x, it))

	func refresh() -> void:
		if grid == null:
			return
		grid.set_items(items())
		_on_selection()

	func _on_selection() -> void:
		for c in actions.get_children():
			c.queue_free()
		show_detail(grid.selection())

	## À redéfinir : remplit [member detail] et [member actions] pour la sélection.
	func show_detail(_sel: Array) -> void:
		pass

	func done(msg: String, duration := 2.0) -> void:
		if ui:
			ui.message(msg, duration)
			if ui.player:
				ui.player.recalc_stats()
		refresh()

	func button(text: String, cb: Callable, enabled := true, accent := false) -> Button:
		var b := ItemWidgets.action_button(actions, text, cb, 0, accent)
		b.disabled = not enabled
		return b

	func now() -> float:
		return Time.get_ticks_msec() / 1000.0


# --- marchand : vendre ----------------------------------------------------------------------
class SellPage extends ItemPage:
	var recycle := false  # recycleur : désassembler au lieu de vendre

	func _init(is_recycle := false) -> void:
		recycle = is_recycle
		multi = true
		include_equipped = false
		title = "Désassembler tes objets" if recycle else "Vendre tes objets"
		hint = "Clic : un objet · Ctrl+clic : plusieurs · Maj+clic : une plage · Ctrl+A : tout ce qui est affiché. Les pièces portées ne sont pas proposées."

	func _gain(it: Dictionary) -> Dictionary:
		return Items.disassemble_yield(it) if recycle else Items.sell_value(it)

	func show_detail(sel: Array) -> void:
		var verb := "Désassembler" if recycle else "Vendre"
		var quick := HBoxContainer.new()
		quick.add_theme_constant_override("separation", 6)
		actions.add_child(quick)
		for spec in [["Communs", 0], ["Jusqu'à magique", 1], ["Jusqu'à rare", 2]]:
			var r: int = spec[1]
			var b := ItemWidgets.action_button(quick, spec[0], func(): grid.select_up_to_rarity(r))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.add_theme_font_size_override("font_size", 14)
		if sel.is_empty():
			detail.text = "[b]%s[/b]\n\n%s\n\nChoisis des objets dans la grille, ou utilise les sélections rapides ci-dessous (les pièces de set ne sont jamais sélectionnées automatiquement)." % [verb,
				"Le démontage rend des [b]cristaux[/b] selon la rareté (réforge et polissage)." if recycle else
				"Le marchand paie en [b]or[/b], plus la moitié de l'or investi dans les améliorations."]
			button("Choisis des objets", func(): pass, false)
			return
		var mats := {}
		var counts := {}
		for it in sel:
			var y := _gain(it)
			for m in y:
				mats[m] = int(mats.get(m, 0)) + int(y[m])
			counts[int(it.rarity)] = int(counts.get(int(it.rarity), 0)) + 1
		if sel.size() == 1:
			var it: Dictionary = sel[0]
			detail.text = Items.describe(it) + ItemWidgets.compare_text(it, Profile.equipped.get(it.slot)) + "\n\n%s : [b]%s[/b]" % ["Donne" if recycle else "Vente", ItemWidgets.materials_text(_gain(it))]
		else:
			var lines := ["[b]%d objets sélectionnés[/b]\n" % sel.size()]
			for r in range(Items.RARITIES.size()):
				if counts.has(r):
					lines.append("[color=#%s]●[/color] %d %s" % [Color(Items.RARITIES[r].color).to_html(false), counts[r], Items.RARITIES[r].name])
			lines.append("\nTotal : [b]%s[/b]" % ItemWidgets.materials_text(mats))
			if sel.any(func(x): return int(x.rarity) >= 2 or x.has("set")):
				lines.append("\n[color=#ff9a7a]Attention : la sélection contient des objets rares, épiques ou de set.[/color]")
			detail.text = "\n".join(lines)
		var confirming := now() - _confirm_at < 3.0 and sel.size() > 1
		button(("Confirmer : %s %d objets ?" % [verb.to_lower(), sel.size()]) if confirming else "%s %s · %s" % [verb, ("%d objets" % sel.size()) if sel.size() > 1 else "", ItemWidgets.materials_text(mats, true)],
			func():
				if sel.size() > 1 and now() - _confirm_at > 3.0:
					_confirm_at = now()
					_on_selection()
					return
				_confirm_at = -10.0
				var items := sel.duplicate()
				var got := Profile.disassemble_many(items) if recycle else Profile.sell_many(items)
				grid.clear_selection()
				done("%d objet(s) %s : %s" % [items.size(), "désassemblé(s)" if recycle else "vendu(s)", ItemWidgets.materials_text(got, true)]), true, true)


# --- marchand : acheter ----------------------------------------------------------------------
class ShopPage extends HBoxContainer:
	var ui: MerchantUI
	var _grid: GridContainer
	var _detail: RichTextLabel
	var _actions: VBoxContainer
	var _selected = null

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		ItemWidgets.section(left, "Boutique du marchand ambulant")
		var h := Hud._label(left, "Ses offres : cartes d'amélioration de la run, clés, équipement rare ou épique, fournitures. Payées en or (perdu en fin de run : dépense-le !).", 13, UiTheme.MUTED)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_grid = GridContainer.new()
		_grid.columns = 3
		_grid.add_theme_constant_override("h_separation", 10)
		_grid.add_theme_constant_override("v_separation", 10)
		left.add_child(_grid)
		var right := ItemWidgets.panel(self, 520)
		_detail = ItemWidgets.rich(right, 15)
		_actions = VBoxContainer.new()
		right.add_child(_actions)

	func refresh() -> void:
		for c in _grid.get_children():
			c.queue_free()
		for o in ui.offers:
			_grid.add_child(_offer_card(o))
		_show()

	func _offer_card(o: Dictionary) -> Control:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(240, 92)
		b.toggle_mode = true
		b.button_pressed = _selected != null and is_same(_selected, o)
		b.disabled = o.get("sold", false)
		var col: Color = Items.color_of(o.item) if o.has("item") else (Boons.RARITY.get(String(o.card.get("rarity", "common")), Boons.RARITY.common).color if o.card.has("rarity") else UiTheme.GOLD_DIM)
		var sb := UiTheme.flat_box(Color(0.07, 0.06, 0.12, 0.95), col, 2, 10)
		b.add_theme_stylebox_override("normal", sb)
		var on := UiTheme.flat_box(Color(0.2, 0.15, 0.3, 1.0), UiTheme.GOLD, 3, 10)
		b.add_theme_stylebox_override("pressed", on)
		b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.15, 0.12, 0.24, 1.0), col, 2, 10))
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 10
		h.offset_right = -10
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 10)
		b.add_child(h)
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(o.item.get("icon", "")) if o.has("item") else String(o.card.get("icon", "")))
		ic.custom_minimum_size = Vector2(60, 60)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var t := Hud._label(v, Items.display_name(o.item) if o.has("item") else String(o.card.title), 14, col.lightened(0.2))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.add_theme_font_override("font", UiTheme.bold_font())
		Hud._label(v, "Vendu" if o.get("sold", false) else "%d or" % int(o.price), 14, UiTheme.GOLD if Profile.gold >= int(o.price) else Color(1, 0.45, 0.45))
		b.pressed.connect(func():
			_selected = o
			refresh())
		return b

	func _show() -> void:
		for c in _actions.get_children():
			c.queue_free()
		if _selected == null:
			_detail.text = "[b]Boutique[/b]\n\nChoisis une offre.\n\nTon or : [b]%d[/b]" % Profile.gold
			return
		var o: Dictionary = _selected
		_detail.text = (Items.describe(o.item) + ItemWidgets.compare_text(o.item, Profile.equipped.get(o.item.slot)) if o.has("item") else
			"[b]%s[/b]\n%s\n\n%s" % [o.card.title, o.card.get("subtitle", ""), o.card.desc]) + "\n\nPrix : [b]%d or[/b]  ·  ton or : %d" % [int(o.price), Profile.gold]
		var b := ItemWidgets.action_button(_actions, "Déjà acheté" if o.get("sold", false) else "Acheter (%d or)" % int(o.price), func():
			ui.buy(o)
			refresh(), 0, true)
		b.disabled = o.get("sold", false) or Profile.gold < int(o.price)


## Contenu du sac (préfixe "gem", "scroll"... ou "" pour tout) en texte avec icônes.
static func bag_text(prefix: String, empty_text: String) -> String:
	var keys: Array = Profile.bag.keys().filter(func(k): return prefix == "" or String(k).begins_with(prefix))
	if keys.is_empty():
		return "[color=#b8b4c8]%s[/color]" % empty_text
	var parts: PackedStringArray = ["[b]Sac[/b]"]
	for k in keys:
		parts.append("[img=20x20]%s[/img] %s ×%d" % [Craft.icon(k), Craft.label(k), Profile.bag_count(k)])
	return "\n".join(parts)


# --- fabrication des objets mythiques -------------------------------------------
## Plans d'Eden : les objets mythiques (orange, dont les pièces de set) de la zone se
## fabriquent ici (les légendaires ne tombent que des boss).
class CraftPage extends HBoxContainer:
	var ui: MerchantUI
	var _filter: OptionButton
	var _keys: Array = []
	var _grid: GridContainer
	var _detail: RichTextLabel
	var _btn: Button
	var _selected: Dictionary = {}
	var _demo: Dictionary = {}

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		ItemWidgets.section(left, "Fabrication d'objets mythiques")
		Hud._label(left, "Plans d'Eden de cette zone : objets mythiques (orange) jusqu'au niveau d'Eden atteint, pièces de set comprises. Toujours 100 % de qualité.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_filter = OptionButton.new()
		_keys = [""]
		_filter.add_item("Tous les plans")
		for wt in GameData.weapon_types:
			_keys.append(String(wt))
			_filter.add_item(String(GameData.weapon_types[wt].name))
		for s in Items.ARMOR + Items.ACCESSORIES:
			_keys.append(String(s))
			_filter.add_item(String(Items.SLOT_NAMES[s]))
		_filter.item_selected.connect(func(_i): refresh())
		left.add_child(_filter)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(sc)
		_grid = GridContainer.new()
		_grid.columns = 9
		_grid.add_theme_constant_override("h_separation", 6)
		_grid.add_theme_constant_override("v_separation", 6)
		sc.add_child(_grid)
		var right := ItemWidgets.panel(self, 520)
		_detail = ItemWidgets.rich(right, 14)
		_btn = ItemWidgets.action_button(right, "Fabriquer", _craft, 0, true)

	static func cost(level: int) -> Dictionary:
		return {"gold": 300 + 60 * level, "crystal": 4 + level / 8}

	## Plans : mythiques d'Eden de la zone et de la précédente, jusqu'au niveau d'Eden atteint
	## dans la run (chronologie) ; au moins les premiers mythiques qui existent (niveau 25).
	func _plans() -> Array:
		var zi := Items.zone_band()
		var lo := int(GameData.eden_bands[maxi(zi - 1, 0)][0]) if not GameData.eden_bands.is_empty() else 1
		var hi := maxi(Items.eden_target(_level()), 25)
		var key := String(_keys[maxi(_filter.selected, 0)])
		return GameData.eden_items.filter(func(e):
			return int(e.rarity) == Items.MYTHIC and int(e.level) >= mini(lo, hi - 10) and int(e.level) <= hi \
				and (key == "" or String(e.get("wtype", e.slot)) == key))

	func refresh() -> void:
		for c in _grid.get_children():
			c.queue_free()
		for e in _plans():
			var s := ItemWidgets.ItemSlot.new(58.0)
			s.set_item(ArchivePages.demo_item(e))
			var ee: Dictionary = e
			s.pressed.connect(func():
				_selected = ee
				_demo = ArchivePages.demo_item(ee)
				_show())
			_grid.add_child(s)
		_show()

	func _level() -> int:
		return ui.director.loot_level(ui.player.level) if ui and ui.director and ui.player else 1

	func _show() -> void:
		if _selected.is_empty():
			_detail.text = "[b]Fabrication[/b]\n\nChoisis un plan. Coût au niveau %d : %s" % [_level(), ItemWidgets.cost_text(cost(_level()))]
			_btn.disabled = true
			return
		var c := cost(_level())
		_detail.text = Items.describe(_demo) + "\n\n[b]Coût :[/b] " + ItemWidgets.cost_text(c)
		_btn.disabled = not Profile.can_afford(c)

	func _craft() -> void:
		if _selected.is_empty():
			return
		var c := cost(_level())
		if not Profile.pay(c):
			return
		var item := Items.from_template(_selected, _level(), Items.MYTHIC)
		Profile.add_item(item)
		_detail.text = "[color=#7fe08a]Fabriqué : %s[/color]\n\n" % Items.display_name(item) + Items.describe(item)
		_btn.disabled = not Profile.can_afford(c)


# --- forge : tout ce qui se fait sur un objet ----------------------------------------------
## Une page, l'objet choisi au centre et ses actions en sections : améliorer (or), réforger
## une stat bonus et polir (cristaux), percer et sertir (joaillerie), enchanter. Sans objet
## choisi : la fusion des gemmes du sac.
class ForgePage extends ItemPage:
	var luck := 0
	var protect := false

	func _init() -> void:
		title = "Forge"
		hint = "Choisis une pièce (portée ou dans ton sac). Améliorer : or seulement (+1 à +10, risque au-delà de +3). Réforger une stat et polir la qualité : cristaux (démontage, gardés entre les runs)."
		scroll_actions = true

	func show_detail(sel: Array) -> void:
		if sel.is_empty():
			detail.text = "[b]Forge[/b]\n\nChoisis une pièce dans la grille.\n\nTes cristaux : [b]%d[/b] · ton or : [b]%d[/b]" % [Profile.amount("crystal"), Profile.gold]
			_fusion()
			return
		var it: Dictionary = sel[0]
		detail.text = Items.describe(it)
		_upgrade(it)
		_crystals(it)
		_gems(it)
		_enchant(it)

	func _head(text: String) -> void:
		var l := ItemWidgets.section(actions, text, 16)
		l.add_theme_constant_override("line_spacing", 0)

	func _note(text: String) -> void:
		var l := Hud._label(actions, text, 13, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	func _upgrade(it: Dictionary) -> void:
		var up := int(it.get("upgrade", 0))
		_head("Améliorer (or)")
		if up >= Items.MAX_UPGRADE:
			_note("Amélioration maximale atteinte (+%d)." % up)
			return
		var cost := Items.upgrade_cost(it)
		luck = mini(luck, mini(Profile.bag_count("luck"), Craft.MAX_LUCK))
		var chance := Craft.success_chance(it, luck)
		var risky: bool = float(Craft.UPGRADE_CHANCE[up]) < 1.0
		_note("+%d → +%d · %d %% de réussite · coût %d or%s" % [up, up + 1, roundi(chance * 100), int(cost.gold),
			(" · échec : %s" % Craft.failure_text(it)) if risky else " · sans risque"])
		if risky:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			actions.add_child(row)
			var minus := ItemWidgets.action_button(row, "−", func():
				luck = maxi(0, luck - 1)
				_on_selection(), 44)
			minus.disabled = luck <= 0
			Hud._label(row, "Pierres de chance : %d / %d (sac : %d)" % [luck, Craft.MAX_LUCK, Profile.bag_count("luck")], 14, Color.WHITE).size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var plus := ItemWidgets.action_button(row, "+", func():
				luck = mini(luck + 1, mini(Craft.MAX_LUCK, Profile.bag_count("luck")))
				_on_selection(), 44)
			plus.disabled = luck >= mini(Craft.MAX_LUCK, Profile.bag_count("luck"))
			var can_protect := Profile.bag_count("protect") > 0 and up + 1 >= Craft.DOWNGRADE_FROM
			protect = protect and can_protect
			button("%s Pierre de protection (sac : %d)" % ["☑" if protect else "☐", Profile.bag_count("protect")], func():
				protect = not protect
				_on_selection(), can_protect)
		button("Tenter +%d (%d %%) · %d or" % [up + 1, roundi(chance * 100), int(cost.gold)], func():
			var r := Profile.upgrade_item(it, luck, protect)
			if Profile.bag_count("protect") <= 0:
				protect = false
			done("%s\n%s" % [Items.display_name(it), r.text], 2.4), Profile.can_afford(cost), true)

	func _crystals(it: Dictionary) -> void:
		var rc := Forge.reforge_cost(it)
		var pc := Forge.polish_cost(it)
		_head("Cristaux : réforger, polir (tu en as %d)" % Profile.amount("crystal"))
		for stat in Forge.reforgeable(it):
			var s: String = stat
			var cur := float(it.base[s]) if it.has("base") else float(it.affixes[s])
			var k := 1.0 if s in Items.PERCENT_STATS or not it.has("base") else Items._level_k(Items.power_level(it))
			button("Réforger %s (%s) · %s" % [Items.STAT_NAMES.get(s, Items.EXTRA_STAT_NAMES.get(s, s)), Items.stat_text(s, cur * k), ItemWidgets.materials_text(rc, true)],
				func(): done(Forge.reforge(it, s)), Profile.can_afford(rc))
		if Forge.reforgeable(it).is_empty():
			_note("Pas de stat bonus à réforger (les mythiques et légendaires ont des stats fixes).")
		button("Polir la qualité (%d %%) · %s" % [roundi(float(it.get("quality", 1.0)) * 100), ItemWidgets.materials_text(pc, true)], func(): done(Forge.polish(it)),
			Profile.can_afford(pc) and float(it.get("quality", 1.0)) < float(Items.QUALITY[clampi(int(it.get("rarity", 0)), 0, Items.QUALITY.size() - 1)][1]))

	func _gems(it: Dictionary) -> void:
		var sockets: Array = it.get("sockets", [])
		_head("Gemmes (%d / %d emplacements)" % [sockets.size(), Craft.MAX_SOCKETS])
		if sockets.size() < Craft.MAX_SOCKETS:
			var b := button("Percer un emplacement (%s) · ciseaux ×%d" % ["sûr" if sockets.is_empty() else "70 %", Profile.bag_count("drill")], func(): done(Craft.drill(it)), Profile.bag_count("drill") > 0)
			b.icon = UiTheme.texture(Craft.icon("drill"))
			b.add_theme_constant_override("icon_max_width", 26)
		var slot := sockets.find(null)
		for k in Profile.bag_keys("gem"):
			var key: String = k
			var target := slot if slot >= 0 else 0
			var b := button("Sertir %s ×%d%s" % [Craft.label(key), Profile.bag_count(key), "" if slot >= 0 else " (remplace l'emplacement 1)"],
				func(): done(Craft.insert_gem(it, key, target)), not sockets.is_empty())
			b.icon = UiTheme.texture(Craft.icon(key))
			b.add_theme_constant_override("icon_max_width", 26)
			b.tooltip_text = Craft.describe_key(key)
		if Profile.bag_keys("gem").is_empty():
			_note("Aucune gemme dans ton sac (butin, coffres, marchands).")

	func _enchant(it: Dictionary) -> void:
		var scrolls := Profile.bag_keys("scroll")
		_head("Enchantement")
		for k in scrolls:
			var key: String = k
			var why := Craft.can_enchant(it, key)
			var b := button("Appliquer %s ×%d" % [Craft.label(key), Profile.bag_count(key)], func(): done(Craft.apply_scroll(it, key)), why == "")
			b.icon = UiTheme.texture(Craft.icon(key))
			b.add_theme_constant_override("icon_max_width", 26)
			b.tooltip_text = why if why != "" else Craft.describe_key(key)
		if scrolls.is_empty():
			_note("Aucun parchemin dans ton sac.")

	func _fusion() -> void:
		_head("Fusion de gemmes (%d identiques → qualité supérieure)" % Forge.FUSE_COUNT)
		var list := Forge.fusable()
		for g in list:
			var type: String = g.type
			var tier: int = g.tier
			var b := button("%s ×%d → %s · %d or" % [Craft.label(g.key), int(g.count), Craft.label(Craft.gem_key(type, tier + 1)), Forge.fuse_cost(tier)], func():
				done(Forge.fuse(type, tier), 1.8), int(g.count) >= Forge.FUSE_COUNT and Profile.gold >= Forge.fuse_cost(tier))
			b.icon = UiTheme.texture(Craft.icon(g.key))
			b.add_theme_constant_override("icon_max_width", 26)
		if list.is_empty():
			_note("Aucune gemme dans ton sac.")
