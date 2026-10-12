class_name VillagePages
extends RefCounted
## Pages des PNJ du village (voir VillageUI) :
## marchand (Acheter, Vendre), forgeron (Améliorer, Enchanter, Réforger),
## recycleur (Recycler, Convertir), joaillier (Sertissage, Fusion de gemmes).


## Base : grille d'objets à gauche, détail et actions à droite.
class ItemPage extends HBoxContainer:
	var ui: VillageUI
	var multi := false
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
				"Le recycleur rend des [b]fragments[/b], des [b]essences[/b] et des [b]cristaux[/b] selon la rareté, plus 70 % des pierres d'amélioration." if recycle else
				"Le marchand paie en [b]or[/b], plus 70 % des pierres d'amélioration investies."]
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


# --- forgeron : améliorer --------------------------------------------------------------------
class UpgradePage extends ItemPage:
	var luck := 0
	var protect := false

	func _init() -> void:
		title = "Amélioration (+1 à +10)"
		hint = "Chaque niveau renforce les stats de base (+10 %) et ajoute une stat aléatoire. Au-delà de +3, la réussite n'est plus garantie : pierres de chance (+10 % chacune) et de protection (pas de perte de niveau)."

	func show_detail(sel: Array) -> void:
		if sel.is_empty():
			detail.text = "[b]Forge de Bryson[/b]\n\nChoisis une pièce (portée ou dans ton sac)."
			return
		var it: Dictionary = sel[0]
		var up := int(it.get("upgrade", 0))
		if up >= Items.MAX_UPGRADE:
			detail.text = Items.describe(it) + "\n\n[b]Amélioration maximale atteinte.[/b]"
			return
		var cost := Items.upgrade_cost(it)
		luck = mini(luck, mini(Profile.bag_count("luck"), Craft.MAX_LUCK))
		var chance := Craft.success_chance(it, luck)
		var risky: bool = float(Craft.UPGRADE_CHANCE[up]) < 1.0
		detail.text = Items.describe(it) + "\n\n[b]+%d → +%d[/b]   [color=%s]%d %% de réussite[/color]\n%s\n\nCoût : %s" % [up, up + 1,
			"#7fe08a" if chance >= 0.8 else ("#ffcf6b" if chance >= 0.5 else "#ff7a7a"), roundi(chance * 100),
			("[color=#ff9a7a]En cas d'échec : %s.[/color]" % Craft.failure_text(it)) if risky else "[color=#7fe08a]Sans risque.[/color]",
			ItemWidgets.cost_text(cost)]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		actions.add_child(row)
		var minus := ItemWidgets.action_button(row, "−", func():
			luck = maxi(0, luck - 1)
			_on_selection(), 44)
		minus.disabled = luck <= 0
		Hud._label(row, "Pierres de chance : %d / %d (possédées %d)" % [luck, Craft.MAX_LUCK, Profile.bag_count("luck")], 14, Color.WHITE).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var plus := ItemWidgets.action_button(row, "+", func():
			luck = mini(luck + 1, mini(Craft.MAX_LUCK, Profile.bag_count("luck")))
			_on_selection(), 44)
		plus.disabled = luck >= mini(Craft.MAX_LUCK, Profile.bag_count("luck"))
		var can_protect := Profile.bag_count("protect") > 0 and up + 1 >= Craft.DOWNGRADE_FROM
		protect = protect and can_protect
		button("%s Pierre de protection (possédées %d)" % ["☑" if protect else "☐", Profile.bag_count("protect")], func():
			protect = not protect
			_on_selection(), can_protect)
		button("Tenter +%d (%d %%)" % [up + 1, roundi(chance * 100)], func():
			var r := Profile.upgrade_item(it, luck, protect)
			if Profile.bag_count("protect") <= 0:
				protect = false
			done("%s\n%s" % [Items.display_name(it), r.text], 2.4), Profile.can_afford(cost), true)


# --- forgeron : enchanter --------------------------------------------------------------------
class EnchantPage extends ItemPage:
	func _init() -> void:
		title = "Enchantement"
		hint = "Applique un parchemin d'enchantement à une pièce (un enchantement par objet ; le parchemin doit convenir au niveau de l'objet)."

	func show_detail(sel: Array) -> void:
		var scrolls := Profile.bag_keys("scroll")
		if sel.is_empty():
			detail.text = "[b]Enchantement[/b]\n\nChoisis une pièce.\n\n" + VillagePages.bag_text("scroll", "Aucun parchemin : ils tombent des monstres et des coffres, et se vendent chez le marchand.")
			return
		var it: Dictionary = sel[0]
		detail.text = Items.describe(it)
		for k in scrolls:
			var key: String = k
			var why := Craft.can_enchant(it, key)
			var b := button("Appliquer %s ×%d" % [Craft.label(key), Profile.bag_count(key)], func(): done(Craft.apply_scroll(it, key)), why == "")
			b.icon = UiTheme.texture(Craft.icon(key))
			b.add_theme_constant_override("icon_max_width", 26)
			b.tooltip_text = why if why != "" else Craft.describe_key(key)
		if scrolls.is_empty():
			Hud._label(actions, "Aucun parchemin dans ton sac.", 14, UiTheme.MUTED)


# --- forgeron : réforger / polir -------------------------------------------------------------
class ReforgePage extends ItemPage:
	func _init() -> void:
		title = "Réforge et polissage"
		hint = "Optimise une pièce : nouveau jet d'une stat dans sa fourchette (essences), ou polissage de la qualité (cristal, gardé seulement s'il est meilleur)."

	func show_detail(sel: Array) -> void:
		if sel.is_empty():
			detail.text = "[b]Optimiser une pièce[/b]\n\nChoisis une pièce : tu pourras retirer une de ses stats bonus (affixes) ou polir sa qualité."
			return
		var it: Dictionary = sel[0]
		var rc := Forge.reforge_cost(it)
		var pc := Forge.polish_cost(it)
		detail.text = Items.describe(it) + "\n\nRéforge d'une stat : %s\nPolissage : %s" % [ItemWidgets.cost_text(rc), ItemWidgets.cost_text(pc)]
		for stat in Forge.reforgeable(it):
			var s: String = stat
			var r: Array = Items.AFFIX_RANGES[s]
			var lo := float(r[0]) * (1.0 if s in Items.PERCENT_STATS else Items._level_k(int(it.level)))
			var hi := float(r[1]) * (1.0 if s in Items.PERCENT_STATS else Items._level_k(int(it.level)))
			button("Réforger %s (%s, fourchette %s à %s)" % [Items.STAT_NAMES.get(s, s), Items.stat_text(s, it.affixes[s]), Items.stat_text(s, lo), Items.stat_text(s, hi)],
				func(): done(Forge.reforge(it, s)), Profile.can_afford(rc))
		if Forge.reforgeable(it).is_empty():
			Hud._label(actions, "Pas de stat bonus à réforger sur cette pièce (les objets magiques et plus en ont).", 14, UiTheme.MUTED)
		button("Polir la qualité (%d %% actuellement)" % roundi(float(it.get("quality", 1.0)) * 100), func(): done(Forge.polish(it)),
			Profile.can_afford(pc) and float(it.get("quality", 1.0)) < 1.2, true)


# --- recycleur : convertir -------------------------------------------------------------------
class ConvertPage extends HBoxContainer:
	var ui: VillageUI
	var _rows: VBoxContainer
	var _info: RichTextLabel

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		ItemWidgets.section(left, "Conversion des matériaux")
		var h := Hud._label(left, "Le recycleur échange tes matériaux : monter de catégorie coûte cher, redescendre en rend moins.", 13, UiTheme.MUTED)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rows = VBoxContainer.new()
		_rows.add_theme_constant_override("separation", 10)
		left.add_child(_rows)
		var right := ItemWidgets.panel(self, 520)
		_info = ItemWidgets.rich(right, 15)

	func refresh() -> void:
		for c in _rows.get_children():
			c.queue_free()
		for i in Forge.CONVERSIONS.size():
			var conv: Array = Forge.CONVERSIONS[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_rows.add_child(row)
			var l := RichTextLabel.new()
			l.bbcode_enabled = true
			l.fit_content = true
			l.scroll_active = false
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.text = "%s%d %s  →  %s%d %s" % [ItemWidgets.icon_bb(conv[0]), conv[1], Items.MATERIALS[conv[0]], ItemWidgets.icon_bb(conv[2]), conv[3], Items.MATERIALS[conv[2]]]
			row.add_child(l)
			for times in [1, 5]:
				var t: int = times
				var b := ItemWidgets.action_button(row, "×%d" % t, func():
					ui.message(Forge.convert(i, t), 1.6)
					refresh(), 70)
				b.disabled = not Forge.can_convert(i, t)
		_info.text = "[b]Tes matériaux[/b]\n\n%s" % ItemWidgets.materials_text({"fragment": Profile.materials.fragment, "essence": Profile.materials.essence, "crystal": Profile.materials.crystal})


# --- joaillier : sertissage ------------------------------------------------------------------
class SocketPage extends ItemPage:
	func _init() -> void:
		title = "Sertissage"
		hint = "Perce jusqu'à 2 emplacements avec des ciseaux de sertissage (le 2e : 70 % de réussite), puis serti tes gemmes."

	func show_detail(sel: Array) -> void:
		if sel.is_empty():
			detail.text = "[b]Atelier de Lertia[/b]\n\nChoisis une pièce.\n\n" + VillagePages.bag_text("", "Ton sac est vide : ciseaux et gemmes tombent des monstres et des coffres, et se vendent chez le marchand.")
			return
		var it: Dictionary = sel[0]
		var sockets: Array = it.get("sockets", [])
		detail.text = Items.describe(it)
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


# --- joaillier : fusion ----------------------------------------------------------------------
class FusePage extends HBoxContainer:
	var ui: VillageUI
	var _rows: VBoxContainer
	var _info: RichTextLabel

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		ItemWidgets.section(left, "Fusion de gemmes")
		var h := Hud._label(left, "%d gemmes identiques donnent une gemme de la qualité supérieure (brut → taillé → pur → parfait → royal)." % Forge.FUSE_COUNT, 13, UiTheme.MUTED)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(sc)
		_rows = VBoxContainer.new()
		_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_rows.add_theme_constant_override("separation", 8)
		sc.add_child(_rows)
		var right := ItemWidgets.panel(self, 520)
		_info = ItemWidgets.rich(right, 15)

	func refresh() -> void:
		for c in _rows.get_children():
			c.queue_free()
		var list := Forge.fusable()
		for g in list:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_rows.add_child(row)
			var ic := TextureRect.new()
			ic.texture = UiTheme.texture(Craft.icon(g.key))
			ic.custom_minimum_size = Vector2(40, 40)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			row.add_child(ic)
			var l := Hud._label(row, "%s ×%d  →  %s" % [Craft.label(g.key), int(g.count), Craft.label(Craft.gem_key(g.type, int(g.tier) + 1))], 15, Color.WHITE)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			var type: String = g.type
			var tier: int = g.tier
			var b := ItemWidgets.action_button(row, "Fusionner (%d or)" % Forge.fuse_cost(tier), func():
				ui.message(Forge.fuse(type, tier), 1.8)
				refresh(), 190)
			b.disabled = int(g.count) < Forge.FUSE_COUNT or Profile.gold < Forge.fuse_cost(tier)
		if list.is_empty():
			Hud._label(_rows, "Aucune gemme dans ton sac.", 14, UiTheme.MUTED)
		_info.text = "[b]Gemmes du sac[/b]\n\n" + VillagePages.bag_text("gem", "Aucune gemme.")


# --- marchand : acheter ----------------------------------------------------------------------
class ShopPage extends HBoxContainer:
	var ui: VillageUI
	var _grid: GridContainer
	var _detail: RichTextLabel
	var _actions: VBoxContainer
	var _selected = null

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		ItemWidgets.section(left, "Boutique d'Alec")
		var h := Hud._label(left, "Offres de cette run : compétences, améliorations et cartes, équipement rare ou épique, fournitures de joaillier.", 13, UiTheme.MUTED)
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


# --- forgeron : fabrication des objets mythiques -------------------------------------------
## Plans d'Eden : les objets mythiques (orange, dont les pièces de set) de la zone se
## fabriquent ici (les légendaires ne tombent que des boss).
class CraftPage extends HBoxContainer:
	var ui: VillageUI
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
		Hud._label(left, "Plans d'Eden de cette zone : objets mythiques (orange), pièces de set comprises. Toujours 100 % de qualité.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		return {"gold": 300 + 60 * level, "fragment": 30 + 2 * level, "essence": 6 + level / 6, "crystal": 2 + level / 15}

	func _plans() -> Array:
		var band := Items.zone_band()
		var key := String(_keys[maxi(_filter.selected, 0)])
		return GameData.eden_items.filter(func(e):
			return int(e.rarity) == Items.MYTHIC and int(e.band) in [band, band - 1] \
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
