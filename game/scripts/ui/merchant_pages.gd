class_name MerchantPages
extends RefCounted
## Pages du marchand ambulant (voir MerchantUI) : Boutique et Vendre ; et la Forge (ForgePage), ouverte depuis
## la fiche d'un objet : améliorer (à l'or en run, en cristaux hors run), réforger et polir avec des cristaux,
## percer, sertir, enchanter, fusionner des gemmes. L'Atelier du lobby en tire ForgeBench (un établi à la fois).


## Prix ou gain en mots (boutons) : « 90 or », « 4 cristaux ».
static func price_words(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	for k in cost:
		var n := int(cost[k])
		match String(k):
			"gold":
				parts.append("%d or" % n)
			"crystal":
				parts.append("%d %s" % [n, "cristal" if n < 2 else "cristaux"])
			"keys":
				parts.append("%d %s" % [n, "clé" if n < 2 else "clés"])
			_:
				parts.append("%d %s" % [n, String(Items.MATERIALS.get(k, k)).to_lower()])
	return " + ".join(parts)


## Base : grille d'objets à gauche, détail et actions à droite.
class ItemPage extends HBoxContainer:
	var ui  # hôte : message(text, duration) et player (MerchantUI, ForgeScreen)
	var multi := false
	var scroll_actions := false  # actions nombreuses : colonne de droite défilante
	var include_equipped := true
	var grid_cols := 10  # colonnes de la grille d'objets
	var right_width := 640.0  # largeur de la colonne de droite (fiche et actions)
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
		if hint != "":
			Hud._label(left, hint, 14, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		grid = ItemWidgets.ItemGrid.new(multi, grid_cols, 62.0)
		grid.badge_fn = func(it): return "porté" if _worn(it) else ""
		grid.selection_changed.connect(_on_selection)
		left.add_child(grid)
		var right := ItemWidgets.panel(self, right_width)  # la fiche et ses actions (forge) : la place utile
		detail = ItemWidgets.rich(right, 15)
		actions = VBoxContainer.new()
		actions.add_theme_constant_override("separation", 8)
		if scroll_actions:
			# fiche et actions dans un seul défilement (pas de trou entre les deux)
			var sc := ScrollContainer.new()
			sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
			sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			right.add_child(sc)
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 10)
			sc.add_child(col)
			detail.reparent(col)
			detail.fit_content = true
			detail.scroll_active = false
			actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(actions)
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
			actions.remove_child(c)
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
		hint = "Ctrl+clic : plusieurs · Maj+clic : une plage"

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
			detail.text = "[b]%s[/b]\n\nChoisis des objets, ou une sélection rapide.\n\n%s" % [verb,
				"Le démontage rend des [b]cristaux[/b]." if recycle else "Le marchand paie en [b]or[/b]."]
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
				lines.append("\n[color=#ff9a7a]Des objets rares, épiques ou de set sont sélectionnés.[/color]")
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
				if int(got.get("gold", 0)) > 0:
					UiFeel.cue("ui_coin", -10.0)  # or gagné (lot SND-2)
				grid.clear_selection()
				done("%s %s : %s" % [GearPower.plural(items.size(), "objet"), ("désassemblé" if items.size() < 2 else "désassemblés") if recycle else ("vendu" if items.size() < 2 else "vendus"), ItemWidgets.materials_text(got, true)]), true, true)


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
		ItemWidgets.section(left, "Boutique")
		Hud._label(left, "L'or est perdu en fin de partie : dépense-le.", 14, UiTheme.MUTED)
		_grid = GridContainer.new()
		_grid.columns = 3
		_grid.add_theme_constant_override("h_separation", 10)
		_grid.add_theme_constant_override("v_separation", 10)
		left.add_child(_grid)
		var right := ItemWidgets.panel(self, 560)
		_detail = ItemWidgets.rich(right, 15)
		_actions = VBoxContainer.new()
		right.add_child(_actions)

	func refresh() -> void:
		for c in _grid.get_children():
			c.queue_free()
		if _selected == null:
			# la première offre encore en vente : sa fiche s'affiche tout de suite
			for o in ui.offers:
				if not o.get("sold", false):
					_selected = o
					break
		for o in ui.offers:
			_grid.add_child(_offer_card(o))
		_show()

	func _offer_card(o: Dictionary) -> Control:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(280, 104)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
			_detail.text = "[b]Boutique[/b]\n\nChoisis une offre."
			return
		var o: Dictionary = _selected
		_detail.text = (Items.describe(o.item) + ItemWidgets.compare_text(o.item, Profile.equipped.get(o.item.slot)) if o.has("item") else
			"[b]%s[/b]\n%s\n\n%s" % [o.card.title, o.card.get("subtitle", ""), o.card.desc])
		var b := ItemWidgets.action_button(_actions, "Déjà acheté" if o.get("sold", false) else "Acheter (%d or)" % int(o.price), func():
			ui.buy(o)
			refresh(), 0, true)
		b.disabled = o.get("sold", false) or Profile.gold < int(o.price)


# --- forge : tout ce qui se fait sur un objet ----------------------------------------------
## Une page, l'objet choisi au centre et ses actions en sections : améliorer (or en run, cristaux hors run),
## réforger une stat bonus et polir (cristaux), percer et sertir (joaillerie), enchanter. Sans objet
## choisi : la fusion des gemmes du sac. ForgeBench (Atelier) en fait un établi à la fois, avec avant → après.
class ForgePage extends ItemPage:
	var stone := ""  # pierre de chance choisie pour la prochaine tentative
	var blessed := false  # tentative avec un parchemin béni
	var heads := true  # titres de section (l'établi de l'Atelier les remplace par son tableau avant → après)
	var aim := 0  # « Viser +N » (lot GX-2) : 0 = le prochain palier à stat bonus
	var _aim_uid := ""  # pièce pour laquelle [member aim] a été choisi

	func _init() -> void:
		title = "Forge"
		scroll_actions = true

	func show_detail(sel: Array) -> void:
		if sel.is_empty():
			detail.text = "[b]Forge[/b]\n\nChoisis une pièce dans la grille.\n\nTes cristaux : [b]%d[/b]%s" % [Profile.amount("crystal"),
				(" · ton or : [b]%d[/b]" % Profile.gold) if Profile.in_run else ""]
			_fusion()
			return
		var it: Dictionary = sel[0]
		detail.text = Items.describe(it)
		if Items.is_unique(it):
			detail.text += "\n\n[color=#ffb347]%s[/color]" % Items.UNIQUE_TEXT
			return
		_upgrade(it)
		_crystals(it)
		_gems(it)
		_enchant(it)

	## Titre de section (sauf pour l'établi, qui n'en a pas besoin).
	func _head(text: String) -> void:
		if heads:
			_section(text)

	func _section(text: String) -> void:
		var l := ItemWidgets.section(actions, text, 16)
		l.add_theme_constant_override("line_spacing", 0)

	func _note(text: String, parent: Control = null) -> void:
		var l := Hud._label(parent if parent else actions, text, 14, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	## Tableau « avant → après » en BBCode : lignes [libellé, avant, après, ton] (ton : 1 mieux, -1 moins bien, 0 neutre).
	static func ba_table(rows: Array) -> String:
		var t := "[table=4]"
		for r in rows:
			var col := "#7fe08a" if int(r[3]) > 0 else ("#ff7a7a" if int(r[3]) < 0 else "#ffffff")
			t += "[cell padding=0,3,22,3][color=#c8c8d4]%s[/color][/cell][cell padding=0,3,12,3]%s[/cell][cell padding=0,3,12,3][color=#9a98a8]%s[/color][/cell][cell padding=0,3,0,3][b][color=%s]%s[/color][/b][/cell]" % [r[0], r[1], "→" if String(r[2]) != "" else "", col, r[2]]
		return t + "[/table]"

	## Un nombre de stat lisible (milliers séparés, % pour les stats en pourcentage).
	static func stat_num(s: String, v: float) -> String:
		return ("%d %%" % roundi(v * 100.0)) if s in Items.PERCENT_STATS else GearPower.fmt(roundi(v))

	## Ligne de coût : ce que l'action demande, en rouge s'il manque quelque chose, et ce qu'on a.
	static func cost_line(cost: Dictionary) -> String:
		var parts: PackedStringArray = []
		for k in cost:
			var have := Profile.amount(k)
			var ok := have >= int(cost[k])
			parts.append("%s[b][color=%s]%s[/color][/b]  [color=#9a98a8](tu en as %s)[/color]" % [ItemWidgets.icon_bb(k), "#ffffff" if ok else "#ff7a7a",
				MerchantPages.price_words({k: cost[k]}), GearPower.fmt(have)])
		return "[color=#c8c8d4]Coût[/color]   " + "   ".join(parts)

	## Case de consommable (icône, bordure de rareté, quantité, fiche au survol).
	func _tile(parent: Control, key: String, count: int, on := false, enabled := true, cb := Callable()) -> Button:
		var b := ItemWidgets.TipButton.new()
		b.custom_minimum_size = Vector2(58, 58)
		b.focus_mode = Control.FOCUS_NONE
		b.icon = UiTheme.texture(Craft.icon(key))
		b.expand_icon = true
		var col: Color = Items.RARITIES[clampi(Craft.rarity(key), 0, Items.RARITIES.size() - 1)].color
		var bg := Color(0.08, 0.06, 0.13, 0.95)
		b.add_theme_stylebox_override("normal", UiTheme.flat_box(bg, UiTheme.GOLD if on else col.darkened(0.3), 3 if on else 1, 8, false))
		b.add_theme_stylebox_override("pressed", UiTheme.flat_box(bg, UiTheme.GOLD, 3, 8, false))
		b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.15, 0.11, 0.24, 1.0), UiTheme.GOLD, 2, 8, false))
		b.add_theme_stylebox_override("disabled", UiTheme.flat_box(Color(0.05, 0.04, 0.08, 0.9), Color(0.22, 0.21, 0.27), 1, 8, false))
		if not enabled:
			b.disabled = true
			b.modulate = Color(0.55, 0.55, 0.6)
		b.tip = "[b][color=#%s]%s[/color][/b]\n%s\n[color=#c8c8d4]Dans ton sac : %d[/color]" % [col.to_html(false), Craft.label(key), Craft.describe_key(key), count]
		b.tip_border = col
		var n := Label.new()
		n.text = str(count)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.add_theme_font_size_override("font_size", 14)
		n.add_theme_constant_override("outline_size", 4)
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.add_theme_color_override("font_color", Color.WHITE if count > 0 else Color(1, 0.5, 0.5))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.anchor_left = 1.0
		n.anchor_top = 1.0
		n.anchor_right = 1.0
		n.anchor_bottom = 1.0
		n.offset_left = -34
		n.offset_top = -19
		n.offset_right = -4
		n.offset_bottom = -2
		b.add_child(n)
		if cb.is_valid():
			b.pressed.connect(cb)
		parent.add_child(b)
		return b

	## Fortification (lot GX-2) : la piste des 10 crans, le parchemin, la pierre de chance, la chance et la persévérance, ce
	## qu'un échec coûte (jamais un niveau), « Viser +N » avec le coût attendu et au pire, puis le bouton. Renvoie le coût
	## de la tentative.
	func _upgrade(it: Dictionary) -> Dictionary:
		var up := int(it.get("upgrade", 0))
		if up >= Items.MAX_UPGRADE:
			_head("Fortification")
			actions.add_child(ForgeWidgets.Track.new(up, up))
			_note("Fortification maximale atteinte (+%d)." % up)
			return {}
		_head("Fortification   +%d → +%d" % [up, up + 1])
		if blessed and Profile.bag_count(Craft.BLESSED) <= 0:
			blessed = false
		if stone != "" and not (Profile.bag_count(stone) > 0 and Craft.stone_usable(it, stone)):
			stone = ""
		if _aim_uid != String(it.get("uid", "")):
			_aim_uid = String(it.get("uid", ""))
			aim = 0
		var target := clampi(aim if aim > up else default_aim(up), up + 1, Items.MAX_UPGRADE)
		actions.add_child(ForgeWidgets.Track.new(up, target))
		var scroll := Craft.BLESSED if blessed else Craft.fortify_for(it)
		var need := Craft.fortify_key(Craft.fortify_kind(it), Craft.fortify_level_for(it))
		var cost := Forge.price(int(Items.upgrade_cost(it).gold))
		# 1) le parchemin qui sert de ressource (le plus petit qui convient, pris dans le sac)
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 10)
		actions.add_child(srow)
		_tile(srow, scroll if scroll != "" else need, Profile.bag_count(scroll if scroll != "" else need), scroll != "", scroll != "")
		var stxt := ItemWidgets.rich(srow, 15)
		stxt.fit_content = true
		stxt.scroll_active = false
		stxt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if blessed:
			stxt.text = "[b]Parchemin béni[/b] ×%d\nTentative gratuite." % Profile.bag_count(Craft.BLESSED)
		elif scroll != "":
			var p := scroll.split(":")
			stxt.text = "[b]%s[/b] ×%d\n[color=#c8c8d4]Réussite assurée jusqu'à +%d[/color]" % [Craft.label(scroll), Profile.bag_count(scroll), Craft.fortify_safe(p[1], int(p[2]))]
		else:
			stxt.text = "[color=#ff8a7a]Il te faut un %s (ou de niveau supérieur).[/color]\n[color=#c8c8d4]Butin des monstres, coffres de forge, marchands.[/color]" % Craft.label(need)
		if Profile.bag_count(Craft.BLESSED) > 0:
			button("%s Parchemin béni ×%d : tentative gratuite" % ["☑" if blessed else "☐", Profile.bag_count(Craft.BLESSED)], func():
				blessed = not blessed
				_on_selection())
		var chance := Craft.success_chance(it, stone, scroll)
		var base := Craft.base_chance(it, scroll)
		# 2) la chance, la persévérance et ce qu'un échec coûterait (écrits avant l'appui)
		var ccol := ForgeWidgets.POMME if chance >= 0.999 else (ForgeWidgets.SOLEIL if chance >= 0.6 else ForgeWidgets.MANDARINE)
		var top := _aim_parent()  # Atelier : zone épinglée, toujours visible au-dessus de « Fortifier »
		var bar := ForgeWidgets.gauge(top, chance, ccol, "Réussite assurée" if chance >= 0.999 else "Réussite : %d %%" % roundi(chance * 100.0))
		bar.tooltip_text = "Chance de base %d %%, +%d %% par échec déjà subi sur ce cran (jusqu'à +%d %%), plus la pierre." % [
			roundi(base * 100.0), roundi(base * Craft.PITY_STEP * 100.0), roundi(base * Craft.PITY_STEP_MAX * 100.0)]
		if base < 1.0:
			var pity := Craft.pity(it)
			var left := Craft.tries_max(it, scroll if not blessed else "")
			var pg := ForgeWidgets.gauge(top, pity, ForgeWidgets.AMETHYSTE,
				"Persévérance : réussite assurée au prochain essai" if left <= 1 else "Persévérance : assurée dans %d essais au plus" % left,
				Craft.pity_gain(it, stone, scroll) if chance < 0.999 else 0.0, 24.0)
			pg.tooltip_text = "Chaque échec remplit la jauge (la trace claire : le prochain) et monte la chance. Pleine : réussite assurée. Elle se vide à la réussite."
			if chance < 0.999:
				_note("Échec : %s. Rien d'autre n'est perdu." % Craft.failure_text(it), top)
		# 3) viser +N : coût attendu et au pire, puis fortifier d'affilée (arrêt à chaque palier à stat bonus)
		if not blessed:
			_aim_row(it, up, target)
		# 4) la pierre de chance (en option) : une par tentative, elle ajoute des chances
		if base < 1.0:
			_note("Pierre de chance (en option) · une par tentative")
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 6)
			actions.add_child(flow)
			for id in Craft.STONES:
				var key := Craft.stone_key(id)
				var n := Profile.bag_count(key)
				var ok := n > 0 and Craft.stone_usable(it, key)
				var t := _tile(flow, key, n, key == stone, ok, func():
					stone = "" if stone == key else key
					_on_selection())
				var pct := Label.new()
				pct.text = "+%d %%" % roundi(float(Craft.STONES[id].bonus) * 100.0)
				pct.mouse_filter = Control.MOUSE_FILTER_IGNORE
				pct.add_theme_font_size_override("font_size", 13)
				pct.add_theme_constant_override("outline_size", 4)
				pct.add_theme_color_override("font_outline_color", Color.BLACK)
				pct.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65))
				pct.position = Vector2(4, 2)
				t.add_child(pct)
		var can: bool = blessed or (scroll != "" and Profile.can_afford(cost))
		var label := "Fortifier avec le parchemin béni" if blessed else ("Fortifier · %s" % MerchantPages.price_words(cost))
		button(label + ("" if chance >= 0.999 else "  (%d %%)" % roundi(chance * 100.0)), func():
			var r := Profile.upgrade_item(it, stone, blessed)
			if stone != "" and Profile.bag_count(stone) <= 0:
				stone = ""
			done("%s\n%s" % [Items.display_name(it), r.text], 2.4), can, true)
		return {} if blessed else cost

	## Cible par défaut de « Viser » : le prochain palier à stat bonus au moins deux crans plus haut (+5 → +8), sinon +10.
	static func default_aim(up: int) -> int:
		for m in Items.MILESTONES:
			if int(m) >= up + 2:
				return int(m)
		return Items.MAX_UPGRADE

	## Rangée « Viser +N » : ‹ +N ›, le coût attendu et au pire, ce qu'on a, et le bouton qui enchaîne les essais.
	func _aim_row(it: Dictionary, up: int, target: int) -> void:
		var plan := Craft.plan_upgrade(it, target)
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", ForgeWidgets.box(ForgeWidgets.ENCRE_500, ForgeWidgets.ENCRE, 12, 3, 3))
		_aim_parent().add_child(pc)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		pc.add_child(row)
		var lab := ForgeWidgets.ink_label(row, "Viser", 16, ForgeWidgets.TEXTE_2, 0)
		lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var minus := ItemWidgets.action_button(row, "‹", func():
			aim = maxi(up + 1, target - 1)
			_on_selection(), 40)
		minus.custom_minimum_size.y = 34
		minus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		minus.disabled = target <= up + 1
		var val := ForgeWidgets.ink_label(row, "+%d" % target, 22, ForgeWidgets.SOLEIL, 4)
		val.custom_minimum_size = Vector2(44, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		val.add_theme_font_override("font", UiTheme.bold_font())
		var plus := ItemWidgets.action_button(row, "›", func():
			aim = mini(Items.MAX_UPGRADE, target + 1)
			_on_selection(), 40)
		plus.custom_minimum_size.y = 34
		plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		plus.disabled = target >= Items.MAX_UPGRADE
		var key := "crystal" if (plan.cost as Dictionary).has("crystal") else "gold"
		var have := Profile.amount(key)
		var e_cost := int((plan.cost as Dictionary).get(key, 0))
		var worst := int((plan.cost_max as Dictionary).get(key, 0))
		var info := ItemWidgets.rich(row, 14)
		info.fit_content = true
		info.scroll_active = false
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.text = "[color=#c9bfea]attendu ≈[/color] [b]%s[/b] [color=#c9bfea]· au pire[/color] [b]%s[/b]\n[color=%s]tu en as %s %s[/color]" % [
			_nb(GearPower.fmt(e_cost)), _nb(GearPower.fmt(worst)), "#c3f07a" if have >= worst else ("#ffe27a" if have >= e_cost else "#ff9db0"),
			GearPower.fmt(have), "or" if key == "gold" else ("cristal" if have < 2 else "cristaux")]
		info.tooltip_text = "Sans pierre : attendu ≈ %.1f essais, au pire %d (la persévérance garantit la fin) ; %s au plus." % [
			float(plan.tries), int(plan.tries_max), GearPower.plural(int(plan.scrolls_max), "parchemin", "parchemins")]
		info.mouse_filter = Control.MOUSE_FILTER_PASS
		var price := Forge.price(int(Items.upgrade_cost(it).gold))
		var can := Craft.fortify_for(it) != "" and Profile.can_afford(price)
		var go := button_in(row, "Fortifier jusqu'à +%d" % target, func(): done(_chain(it, target), 3.0), can and target > up)
		go.add_theme_font_size_override("font_size", 15)
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		go.tooltip_text = "Enchaîne les essais sans pierre ; s'arrête à chaque palier à stat bonus pour te la montrer."

	## Nombre sans coupure de ligne entre ses milliers (espace insécable).
	static func _nb(s: String) -> String:
		return s.replace(" ", String.chr(0xA0))

	## Où se range la rangée « Viser » (la Forge de l'Atelier la met dans la zone épinglée, au-dessus du bouton principal).
	func _aim_parent() -> Control:
		return actions

	## Bouton d'action rangé dans [param parent] (l'établi de l'Atelier le fait passer par sa barre de forge).
	func button_in(parent: Control, text: String, cb: Callable, enabled := true) -> Button:
		var b := ItemWidgets.action_button(parent, text, cb)
		b.disabled = not enabled
		return b

	## Enchaîne les essais jusqu'à +[param target] (sans pierre) ; s'arrête à chaque palier à stat bonus atteint (pour la
	## montrer), quand un parchemin ou le prix manque. Renvoie le résumé.
	func _chain(it: Dictionary, target: int) -> String:
		var start := int(it.get("upgrade", 0))
		var tries := 0
		var fails := 0
		var last := ""
		var why := ""
		while int(it.get("upgrade", 0)) < target and tries < 60:
			if Craft.fortify_for(it) == "":
				why = "plus de parchemin"
				break
			if not Profile.can_afford(Forge.price(int(Items.upgrade_cost(it).gold))):
				why = "plus assez d'or" if Profile.in_run else "plus assez de cristaux"
				break
			var r := Profile.upgrade_item(it)
			if r.get("error", false):
				why = String(r.text)
				break
			tries += 1
			if not bool(r.ok):
				fails += 1
			elif int(it.upgrade) in Items.MILESTONES:
				last = String(r.text)
				if int(it.upgrade) < target:
					why = "palier +%d" % int(it.upgrade)
				break
		var head := "%s : +%d → +%d en %s" % [Items.display_name(it), start, int(it.get("upgrade", 0)), GearPower.plural(tries, "essai", "essais")]
		if fails > 0:
			head += " (%s)" % GearPower.plural(fails, "raté", "ratés")
		if last != "":
			head += "\n" + last
		if why != "" and int(it.get("upgrade", 0)) < target:
			head += "\nArrêt : %s." % why
		return head if tries > 0 else "Échec : %s." % (why if why != "" else "rien à faire")

	func _crystals(it: Dictionary) -> void:
		var rc := Forge.reforge_cost(it)
		var pc := Forge.polish_cost(it)
		_head("Cristaux : réforger, polir (tu en as %d)" % Profile.amount("crystal"))
		if reroll_choice(it):
			return
		for stat in Forge.reforgeable(it):
			var s: String = stat
			var cur := float(it.base[s]) if it.has("base") else float(it.affixes[s])
			var k := 1.0 if s in Items.PERCENT_STATS or not it.has("base") else Items._level_k(Items.power_level(it))
			button("Réforger %s (%s) · %s" % [Items.STAT_NAMES.get(s, Items.EXTRA_STAT_NAMES.get(s, s)), Items.stat_text(s, cur * k), MerchantPages.price_words(rc)],
				func(): done(Forge.reforge(it, s)), Profile.can_afford(rc))
		if Forge.reforgeable(it).is_empty():
			_note("Pas de stat bonus à réforger (les mythiques et légendaires ont des stats fixes).")
		button("Polir la qualité (%d %%) · %s" % [roundi(float(it.get("quality", 1.0)) * 100), MerchantPages.price_words(pc)], func(): done(Forge.polish(it)),
			Profile.can_afford(pc) and float(it.get("quality", 1.0)) < float(Items.QUALITY[clampi(int(it.get("rarity", 0)), 0, Items.QUALITY.size() - 1)][1]))

	## Réajustement en attente (lot GX-2) : l'ancien et le nouveau jet côte à côte, le joueur garde l'un des deux. Renvoie
	## vrai s'il y en a un (les autres réajustements attendent ce choix).
	func reroll_choice(it: Dictionary) -> bool:
		var p := Forge.reforge_pending(it)
		if p.is_empty():
			return false
		var better := float(p.new) > float(p.old)
		_note("Nouveau jet de %s : garde celui que tu préfères." % Forge.stat_name(String(p.stat)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		actions.add_child(row)
		for take_new in [false, true]:
			var v := float(p.new) if take_new else float(p.old)
			var b := ForgeWidgets.candy_button("%s · %s" % ["Prendre le nouveau" if take_new else "Garder l'ancien", Forge.reroll_text(it, v)],
				("pomme" if better else "lagon") if take_new else ("lagon" if better else "pomme"), 16)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func(): done(Forge.reforge_choose(it, take_new)))
			row.add_child(b)
		return true

	func _gems(it: Dictionary) -> void:
		var sockets: Array = it.get("sockets", [])
		_head("Gemmes (%d / %d emplacements)" % [sockets.size(), Craft.MAX_SOCKETS])
		if sockets.size() < Craft.MAX_SOCKETS:
			var b := button("Percer un emplacement (%s) · ciseaux ×%d" % ["sûr" if sockets.is_empty() else "70 %", Profile.bag_count("drill")], func(): done(Craft.drill(it)), Profile.bag_count("drill") > 0)
			b.icon = UiTheme.texture(Craft.icon("drill"))
			b.add_theme_constant_override("icon_max_width", 26)
		# lot GX-4 : chaque gemme sertie avec ce qu'elle donne sur cette pièce, et « Retirer » (gratuit : elle revient au sac)
		for i in sockets.size():
			var g = sockets[i]
			if not g is Dictionary:
				continue
			var idx: int = i
			var gk := Craft.gem_key(String(g.type), int(g.tier))
			var rb := button("Retirer %s (%s) · gratuit" % [Craft.label(gk), Craft.gem_value_text(gk)], func(): done(Craft.remove_gem(it, idx)))
			rb.icon = UiTheme.texture(Craft.icon(gk))
			rb.add_theme_constant_override("icon_max_width", 26)
			rb.tooltip_text = "La gemme revient dans ton sac ; l'emplacement reste percé."
		var slot := sockets.find(null)
		for k in Profile.bag_keys("gem"):
			var key: String = k
			var target := slot if slot >= 0 else 0
			var b := button("Sertir %s · %s ×%d%s" % [Craft.label(key), Craft.gem_value_text(key), Profile.bag_count(key), "" if slot >= 0 or sockets.is_empty() else " (l'emplacement 1 revient au sac)"],
				func(): done(Craft.insert_gem(it, key, target)), not sockets.is_empty())
			b.icon = UiTheme.texture(Craft.icon(key))
			b.add_theme_constant_override("icon_max_width", 26)
			b.tooltip_text = Craft.describe_key(key)
		if Profile.bag_keys("gem").is_empty():
			_note("Aucune gemme : butin, coffres de joaillier, marchands.")
		elif sockets.is_empty():
			_note("Perce d'abord un emplacement pour sertir une gemme.")

	func _enchant(it: Dictionary) -> void:
		var scrolls := Profile.bag_keys("scroll")
		var cur := ""
		if it.has("enchant"):
			var e: Dictionary = it.enchant
			cur = " · actuel : %s niv. %d" % [String(Craft.ENCHANTS.get(String(e.get("type", "")), {}).get("name", "?")), int(e.get("lv", 1))]
		_head("Enchantement" + cur)
		for k in scrolls:
			var key: String = k
			var why := Craft.can_enchant(it, key)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			actions.add_child(row)
			_tile(row, key, Profile.bag_count(key), false, why == "")
			var p := key.split(":")
			var txt := ItemWidgets.rich(row, 15)
			txt.fit_content = true
			txt.scroll_active = false
			txt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			txt.text = "[b]%s[/b]\n[color=#c8c8d4]%s[/color]%s" % [Craft.label(key), Craft._stats_text(Craft.enchant_stats({"type": p[1], "lv": int(p[2])})),
				("  [color=#ff8a7a]%s[/color]" % why) if why != "" else ""]
			var b := ItemWidgets.action_button(row, "Appliquer", func(): done(Craft.apply_scroll(it, key)), 120)
			b.disabled = why != ""
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if scrolls.is_empty():
			_note("Aucune formule d'enchantement : les coffres de joaillier en donnent.")

	## Fusion de gemmes du sac : trois gemmes identiques donnent une gemme de la taille au-dessus.
	func _fusion() -> void:
		_section("Fusion de gemmes · %d identiques → la taille au-dessus" % Forge.FUSE_COUNT)
		var list := Forge.fusable()
		# lot GX-4 : « Tout fusionner » (les plus petites d'abord, les gemmes obtenues refusionnent si elles le peuvent)
		var all := Forge.fuse_all_plan()
		if int(all.count) > 1:
			var fb := button("Tout fusionner · %s · %s" % [GearPower.plural(int(all.count), "fusion", "fusions"), MerchantPages.price_words(all.cost)],
				func(): done(String(Forge.fuse_all().text), 2.2), Profile.can_afford(Forge.fuse_price(0)))
			fb.tooltip_text = "Les plus petites tailles d'abord ; une gemme obtenue fusionne à son tour s'il y en a trois. S'arrête si le prix manque."
		for g in list:
			var type: String = g.type
			var tier: int = g.tier
			var fp := Forge.fuse_price(tier)
			var b := button("%s ×%d → %s · %s" % [Craft.label(g.key), int(g.count), Craft.label(Craft.gem_key(type, tier + 1)), MerchantPages.price_words(fp)], func():
				done(Forge.fuse(type, tier), 1.8), int(g.count) >= Forge.FUSE_COUNT and Profile.can_afford(fp))
			b.icon = UiTheme.texture(Craft.icon(g.key))
			b.add_theme_constant_override("icon_max_width", 26)
		if list.is_empty():
			_note("Aucune gemme dans ton sac.")
