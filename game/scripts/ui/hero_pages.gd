class_name HeroPages
## Pages de l'écran Héros qui ne sont pas des pages à part entière ailleurs.


# --- apparence : tenue, tête, dos, auras, arme -------------------------------------------------
## Tout ce que le héros porte « pour le style », au même endroit que la classe : costumes
## d'Eden débloqués (butin des boss, mode dev ; n'importe quelle classe peut porter n'importe
## quelle tenue, « Tenue de la classe » revient à l'apparence d'origine), auras (une pierre
## étoilée et une pierre de lune à la fois) et apparence de l'arme (modèles de base, armes
## mythiques ou légendaires archivées, apparences de l'archive ; vaut pour tout le type
## d'arme, quelle que soit la classe).
class AppearancePage extends HBoxContainer:
	const CATS := [["body", "Tenue"], ["head", "Tête"], ["back", "Dos"], ["aura", "Auras"], ["weapon", "Arme"]]
	var _cat := "body"
	var _cat_buttons := {}
	var _grid: GridContainer
	var _hint: Label
	var _preview: EquipmentPage.HeroPreview
	var _info: RichTextLabel
	var _count: Label
	var _shown_code := ""  # modèle d'arme montré dans l'aperçu (essai d'une apparence)

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		left.add_child(head)
		ItemWidgets.section(head, "Apparence")
		_count = Hud._label(head, "", 14, UiTheme.MUTED)
		_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 6)
		left.add_child(tabs)
		for c in CATS:
			var b := Button.new()
			b.text = String(c[1])
			b.toggle_mode = true
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(120, 36)
			var id := String(c[0])
			b.pressed.connect(func():
				_cat = id
				refresh())
			tabs.add_child(b)
			_cat_buttons[id] = b
		_hint = Hud._label(left, "", 13, UiTheme.MUTED)
		_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(scroll)
		_grid = GridContainer.new()
		_grid.columns = 7
		_grid.add_theme_constant_override("h_separation", 8)
		_grid.add_theme_constant_override("v_separation", 8)
		scroll.add_child(_grid)
		var right := ItemWidgets.panel(self, 420)
		ItemWidgets.section(right, "Aperçu")
		_preview = EquipmentPage.HeroPreview.new()
		_preview.custom_minimum_size = Vector2(380, 440)
		_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_preview.idle_pose = true
		_preview.spin = false
		right.add_child(_preview)
		_preview.frame(5.3, 0.95, 0.35)  # en pied, de trois-quarts face (glisser pour tourner)
		_info = ItemWidgets.rich(right, 14)
		_info.custom_minimum_size = Vector2(0, 110)
		_info.size_flags_vertical = Control.SIZE_FILL

	static func cat_of(c: Dictionary) -> String:
		return String(c.get("cat", "body"))

	func _cid() -> String:
		return Run.class_id if Profile.in_run else Profile.selected_class

	func _current(cid: String) -> String:
		if _cat == "body":
			return Profile.outfit_of(cid)
		return String(Profile.worn.get(cid, {}).get(_cat, ""))

	func refresh() -> void:
		if not is_inside_tree():
			return
		for id in _cat_buttons:
			_cat_buttons[id].set_pressed_no_signal(id == _cat)
		for c in _grid.get_children():
			c.queue_free()
		var cid := _cid()
		if _cat != "weapon":
			_shown_code = ""
		match _cat:
			"aura":
				_refresh_auras(cid)
			"weapon":
				_refresh_weapon(cid)
			_:
				_refresh_costumes(cid)
		_preview.show_hero(cid, _shown_code if _shown_code != "" else Profile.weapon_code())
		_info.text = _worn_text(cid)

	func _refresh_costumes(cid: String) -> void:
		_grid.columns = 7
		_hint.text = "Costumes d'Eden : trésors de collection des boss (1 chance sur 4, plus s'ils sont enragés). Ils se portent avec n'importe quelle classe."
		var list := GameData.cosmetics.filter(func(c): return cat_of(c) == _cat)
		var owned := list.filter(func(c): return Profile.outfit_unlocked(String(c.id)))
		_count.text = "%d / %d débloqués" % [owned.size(), list.size()]
		_grid.add_child(_cell({}, cid))
		# débloqués d'abord, puis le reste
		for c in owned:
			_grid.add_child(_cell(c, cid))
		for c in list:
			if not Profile.outfit_unlocked(String(c.id)):
				_grid.add_child(_cell(c, cid))

	func _refresh_auras(cid: String) -> void:
		_grid.columns = 7
		_hint.text = "Une pierre étoilée et une pierre de lune à la fois : effet lumineux autour du héros et bonus pendant les runs."
		var got := GameData.auras.filter(func(x): return Profile.collected(x))
		_count.text = "%d / %d auras obtenues" % [got.size(), GameData.auras.size()]
		for kind in ["star", "luna", "other"]:
			_grid.add_child(_aura_cell({}, cid, kind))
		for x in got:
			_grid.add_child(_aura_cell(x, cid, String(x.aura.kind)))
		for x in GameData.auras:
			if not Profile.collected(x):
				_grid.add_child(_aura_cell(x, cid, String(x.aura.kind)))

	## Apparence de l'arme : l'arme portée (modèles de base, armes archivées), puis les
	## apparences d'armes d'Eden (trésors de collection, pour n'importe quelle arme), puis
	## les modèles de base des autres types d'armes.
	func _refresh_weapon(cid: String) -> void:
		_grid.columns = 1
		_hint.text = "Arme portée : « Auto » garde son propre modèle ; les modèles de base et les armes mythiques ou légendaires archivées de ce type sont libres. Les apparences d'armes d'Eden (trésors de collection des boss) se portent avec n'importe quelle arme. Le choix vaut pour toutes les armes de ce type, quelle que soit la classe."
		var w: Dictionary = Profile.equipped.get("weapon", {})
		var mine := Items.weapon_type_of(w) if not w.is_empty() else String(GameData.class_data(cid).get("weapon_type", ""))
		var n := 0
		if GameData.weapon_types.has(mine):
			n += _weapon_row(mine, true)
		# apparences d'armes d'Eden : obtenues d'abord, puis les autres (verrouillées)
		var skins := GameData.collection.filter(func(x): return x.has("skin"))
		var got := skins.filter(func(x): return Profile.collected(x))
		var t := Hud._label(_grid, "Apparences d'armes d'Eden : %d / %d obtenues (pour %s)" % [got.size(), skins.size(), String(GameData.weapon_type(mine).get("name", "l'arme portée")).to_lower()], 16, UiTheme.GOLD)
		t.add_theme_font_override("font", UiTheme.bold_font())
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		_grid.add_child(flow)
		for x in got:
			flow.add_child(_eden_skin_cell(mine, x, true))
		for x in skins:
			if not Profile.collected(x):
				flow.add_child(_eden_skin_cell(mine, x, false))
		n += got.size()
		var o := Hud._label(_grid, "Autres types d'armes", 16, UiTheme.GOLD)
		o.add_theme_font_override("font", UiTheme.bold_font())
		for wt in GameData.weapon_types:
			if wt != mine:
				n += _weapon_row(String(wt), false)
		_count.text = "%d modèles disponibles" % n

	## Ligne d'un type d'arme : « Auto », modèles de base et armes archivées.
	func _weapon_row(wt: String, worn: bool) -> int:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_grid.add_child(row)
		var lbl := Hud._label(row, String(GameData.weapon_types[wt].name) + ("  (portée)" if worn else ""), 16, UiTheme.GOLD if worn else Color(0.92, 0.9, 1.0))
		lbl.custom_minimum_size = Vector2(150, 0)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(_skin_cell(wt, -1, {}))
		var ws := Archive.skins(wt).filter(func(sk): return not GameData.skin_by_code.has(String(sk.code)))
		for i in ws.size():
			row.add_child(_skin_cell(wt, i, ws[i]))
		return ws.size()

	## Case d'une apparence d'arme d'Eden (appliquée au type de l'arme portée).
	func _eden_skin_cell(wt: String, x: Dictionary, ok: bool) -> Control:
		var code := String(x.code)
		var on := String(Profile.skins.get(wt, "")) == code
		var b := ItemWidgets.TipButton.new()
		b.custom_minimum_size = Vector2(68, 68)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", _box(on, ok))
		b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.15, 0.11, 0.24, 1.0), UiTheme.GOLD, 2, 8))
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(x.icon))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 7
		ic.offset_top = 7
		ic.offset_right = -7
		ic.offset_bottom = -7
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.modulate = Color.WHITE if ok else Color(0.35, 0.35, 0.4, 0.8)
		b.add_child(ic)
		b.tip = Archive.collection_text(x) + ("" if ok else "
[color=#ff9a7a]Verrouillée : trésor de collection des boss[/color]") 			+ ("
[color=#9a98a8]Clique pour l'aperçu.[/color]" if not ok else "")
		b.pressed.connect(func():
			_shown_code = code  # aperçu même verrouillée
			if ok:
				Profile.set_skin(wt, "" if on else code)
			refresh())
		return b

	## Ce que porte la classe et le bonus des auras.
	func _worn_text(cid: String) -> String:
		var lines: PackedStringArray = []
		for k in [["body", "Tenue"], ["head", "Tête"], ["back", "Dos"]]:
			var path := Profile.outfit_of(cid) if k[0] == "body" else String(Profile.worn.get(cid, {}).get(k[0], ""))
			var name := "tenue de la classe" if k[0] == "body" else "aucun"
			for c in GameData.cosmetics:
				if String(c.outfit) == path and path != "":
					name = String(c.name)
			lines.append("%s : [b]%s[/b]" % [k[1], name])
		var w: Dictionary = Profile.equipped.get("weapon", {})
		var skin := String(Profile.skins.get(Items.weapon_type_of(w), "")) if not w.is_empty() else ""
		lines.append("Arme : [b]%s[/b]%s" % [Items.display_name(w) if not w.is_empty() else "aucune", " (apparence choisie)" if skin != "" else ""])
		var auras := Profile.worn_auras(cid)
		var names := auras.map(func(x): return String(x.name))
		lines.append("Auras : [b]%s[/b]" % (", ".join(names) if not names.is_empty() else "aucune"))
		var b := Profile.aura_stats(cid)
		var parts: PackedStringArray = []
		for s in b:
			parts.append(Items.stat_text(s, b[s]))
		if not parts.is_empty():
			lines.append("[color=#7fe08a]%s en run[/color]" % ", ".join(parts))
		return "[b]%s[/b]\n%s" % [GameData.class_data(cid).get("name_fr", cid), "\n".join(lines)]

	static func _box(on: bool, ok: bool) -> StyleBoxFlat:
		return UiTheme.flat_box(Color(0.08, 0.06, 0.13, 0.95), UiTheme.GOLD if on else (UiTheme.GOLD_DIM if ok else Color(0.25, 0.23, 0.3)), 3 if on else 2, 8)

	## Case d'aura ([param x] vide : retirer l'aura de ce type).
	func _aura_cell(x: Dictionary, cid: String, kind: String) -> Control:
		var ok := x.is_empty() or Profile.collected(x)
		var cur := int(Profile.worn.get(cid, {}).get("aura_" + kind, 0))
		var on := (cur == 0) if x.is_empty() else (cur == int(x.id))
		var b := ItemWidgets.TipButton.new()
		b.custom_minimum_size = Vector2(110, 96)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 48)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_stylebox_override("normal", _box(on, ok))
		if x.is_empty():
			b.text = "Aucune " + String(Archive.AURA_KINDS.get(kind, "aura"))
		else:
			b.text = String(x.name) if ok else "🔒 " + String(x.name)
			b.icon = UiTheme.texture(String(x.icon))
			b.tip = Archive.collection_text(x) + ("" if ok else "\n[color=#ff9a7a]Verrouillée : trésor de collection des boss[/color]")
			if not ok:
				b.modulate = Color(0.6, 0.6, 0.65)
		b.pressed.connect(func():
			if not ok:
				return
			Profile.set_aura(cid, kind, 0 if x.is_empty() or on else int(x.id))
			Profile.save_profile()
			refresh())
		return b

	func _cell(c: Dictionary, cid: String) -> Control:
		var ok := c.is_empty() or Profile.outfit_unlocked(String(c.id))
		var on := _current(cid) == String(c.get("outfit", ""))
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 96)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 48)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_stylebox_override("normal", _box(on, ok))
		if c.is_empty():
			b.text = "Tenue de la classe" if _cat == "body" else "Aucun"
			b.icon = UiTheme.texture(String(GameData.class_data(cid).get("icon", "")))
		else:
			b.text = String(c.name) if ok else "🔒 " + String(c.name)
			b.icon = UiTheme.texture(String(c.get("icon", "")))
			b.tooltip_text = String(c.name) + ("" if ok else "\nVerrouillé : butin des boss")
			if not ok:
				b.modulate = Color(0.6, 0.6, 0.65)
		b.pressed.connect(func():
			if not ok:
				return
			var path := String(c.get("outfit", ""))
			if _cat == "body":
				if path == "":
					Profile.outfits.erase(cid)
				else:
					Profile.outfits[cid] = path
			else:
				Profile.set_worn(cid, _cat, path)
			Profile.save_profile()
			refresh())
		return b

	## Case d'apparence d'arme ([param i] = -1 : modèle de l'arme elle-même).
	func _skin_cell(wt: String, i: int, w: Dictionary) -> Control:
		var current := String(Profile.skins.get(wt, ""))
		var code := String(w.get("code", ""))
		var on := current == code
		var b := Button.new()
		b.custom_minimum_size = Vector2(68, 68)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", _box(on, true))
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
			ic.offset_left = 7
			ic.offset_top = 7
			ic.offset_right = -7
			ic.offset_bottom = -7
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(ic)
			b.tooltip_text = "%s\n(%s)" % [String(w.get("name", "Modèle %d" % (i + 1))), Archive.skin_hint(i)]
		b.pressed.connect(func():
			var worn: Dictionary = Profile.equipped.get("weapon", {})
			_shown_code = code if code != "" else String(worn.get("weapon", ""))
			Profile.set_skin(wt, code)
			refresh())
		return b
