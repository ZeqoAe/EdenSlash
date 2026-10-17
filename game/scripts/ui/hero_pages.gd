class_name HeroPages
## Pages de l'écran Héros qui ne sont pas des pages à part entière ailleurs.


# --- apparence : tenue, tête, dos, auras, arme -------------------------------------------------
## Tout ce que le héros porte « pour le style », au même endroit que la classe : costumes
## débloqués (butin des boss, mode dev ; n'importe quelle classe peut porter n'importe quelle
## tenue, « Tenue de la classe » revient à l'apparence d'origine), auras (une seule à la fois) et
## apparence de l'arme (modèles de base, armes mythiques ou légendaires archivées, apparences de
## la collection ; vaut pour tout le type d'arme, quelle que soit la classe). Par défaut, seules
## les pièces débloquées sont montrées (le filtre « Débloqués uniquement » les révèle toutes).
class AppearancePage extends HBoxContainer:
	const CATS := [["body", "Tenue"], ["head", "Tête"], ["back", "Dos"], ["aura", "Auras"], ["weapon", "Arme"]]
	## Emplacements autour du héros (comme l'équipement) : [id, catégorie, nom, type d'aura].
	const LEFT_SLOTS := [["body", "body", "Tenue", ""], ["head", "head", "Tête", ""], ["back", "back", "Dos", ""]]
	## Une seule aura à la fois (pierre étoilée, pierre de lune ou autre : même rôle).
	const RIGHT_SLOTS := [["aura", "aura", "Aura", ""], ["weapon", "weapon", "Arme", ""]]
	## Provenance d'une apparence verrouillée (lot GX-4 : les boss n'en sont qu'une source ; aucun lien avec la puissance).
	const LOOK_FROM := "boss et coffres d'apparence"
	const LOOK_WHERE := "Coffres d'apparence : Tour, Siège, Ruée, Battle royale, Échiquier, Survivant, Roulette."
	var _cat := "body"
	var _slot := "body"
	var _aura_kind := ""  # auras : type de l'emplacement cliqué ("" : toutes)
	var _cat_buttons := {}
	var _slots := {}  # id -> Button
	var _grid: GridContainer
	var _hint: Label
	var _title: Label
	var _preview: EquipmentPage.HeroPreview
	var _info: RichTextLabel
	var _count: Label
	var _shown_code := ""  # modèle d'arme montré dans l'aperçu (essai d'une apparence)
	var _dye_box: VBoxContainer  # couleurs de la pièce portée (tenue, tête, dos)
	var _search: LineEdit
	var _owned_only: Button  # filtre « Débloqués uniquement » (activé par défaut)

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		# --- le héros au centre, les emplacements autour (comme l'équipement) ---
		var doll_panel := ItemWidgets.panel(self, 520)
		var doll := HBoxContainer.new()
		doll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		doll.add_theme_constant_override("separation", 8)
		doll_panel.add_child(doll)
		_slot_column(doll, LEFT_SLOTS)
		var mid := VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		doll.add_child(mid)
		_preview = EquipmentPage.HeroPreview.new()
		_preview.custom_minimum_size = Vector2(300, 440)
		_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_preview.idle_pose = true
		_preview.spin = false
		mid.add_child(_preview)
		_preview.frame(5.3, 0.95, 0.35)  # en pied, de trois-quarts face (glisser pour tourner)
		var tip := Hud._label(mid, "Glisser : tourner · Molette : zoom", 12, UiTheme.MUTED)
		tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_slot_column(doll, RIGHT_SLOTS)
		_info = ItemWidgets.rich(doll_panel, 14)  # bonus de l'aura portée (vide sans aura)
		_info.fit_content = true
		_info.scroll_active = false
		_info.size_flags_vertical = Control.SIZE_SHRINK_END
		# --- à droite : le choix pour l'emplacement cliqué, puis ses couleurs ---
		var right := ItemWidgets.panel(self, 0, true)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		right.add_child(head)
		_title = Hud._label(head, "", 20, UiTheme.GOLD)
		_title.add_theme_font_override("font", UiTheme.title_font())
		_count = Hud._label(head, "", 14, UiTheme.MUTED)
		_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var fl := HBoxContainer.new()
		fl.add_theme_constant_override("separation", 10)
		right.add_child(fl)
		_search = LineEdit.new()
		_search.placeholder_text = "Rechercher…"
		_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_search.text_changed.connect(func(_t): refresh())
		fl.add_child(_search)
		_owned_only = Button.new()
		_owned_only.text = "Débloqués uniquement"
		_owned_only.toggle_mode = true
		_owned_only.button_pressed = true
		_owned_only.focus_mode = Control.FOCUS_NONE
		_owned_only.custom_minimum_size = Vector2(0, 38)
		_owned_only.add_theme_font_size_override("font_size", 14)
		_owned_only.toggled.connect(func(_on):
			_style_filter()
			refresh())
		_style_filter()
		fl.add_child(_owned_only)
		_hint = Hud._label(right, "", 13, UiTheme.MUTED)
		_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		right.add_child(scroll)
		_grid = GridContainer.new()
		_grid.columns = 5
		_grid.add_theme_constant_override("h_separation", 8)
		_grid.add_theme_constant_override("v_separation", 8)
		scroll.add_child(_grid)
		_dye_box = VBoxContainer.new()
		_dye_box.add_theme_constant_override("separation", 6)
		right.add_child(_dye_box)

	## Interrupteur « Débloqués uniquement » : doré quand le filtre est actif.
	func _style_filter() -> void:
		var on := _owned_only.button_pressed
		var sb := UiTheme.flat_box(Color(0.5, 0.36, 0.1, 1.0) if on else Color(0.08, 0.07, 0.16, 0.92), UiTheme.GOLD if on else UiTheme.GOLD_DIM, 1, 7, false)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		for st in ["normal", "pressed", "hover", "hover_pressed"]:
			_owned_only.add_theme_stylebox_override(st, sb)
		_owned_only.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02) if on else Color(0.92, 0.88, 0.8))
		_owned_only.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.02))
		_owned_only.add_theme_color_override("font_hover_pressed_color", Color(0.12, 0.08, 0.02))

	## Colonne d'emplacements (icône de ce qui est porté, nom dessous).
	func _slot_column(parent: Control, slots: Array) -> void:
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 6)
		parent.add_child(col)
		for sl in slots:
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 0)
			col.add_child(cell)
			var b := ItemWidgets.TipButton.new()
			b.custom_minimum_size = Vector2(84, 84)
			b.focus_mode = Control.FOCUS_NONE
			b.expand_icon = true
			var id := String(sl[0])
			var cat := String(sl[1])
			var kind := String(sl[3])
			b.pressed.connect(func():
				_slot = id
				_cat = cat
				_aura_kind = kind
				refresh())
			b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.add_child(b)
			var cap := Hud._label(cell, String(sl[2]), 12, UiTheme.MUTED)
			cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_slots[id] = b

	## Icône et infobulle de chaque emplacement d'après ce que porte la classe.
	func _refresh_slots(cid: String) -> void:
		var w: Dictionary = Profile.worn.get(cid, {})
		for id in _slots:
			var b: ItemWidgets.TipButton = _slots[id]
			var icon := ""
			var name := ""
			var sub := ""  # seconde ligne de l'infobulle
			match id:
				"body", "head", "back":
					var path := Profile.outfit_of(cid) if id == "body" else String(w.get(id, ""))
					for c in GameData.cosmetics:
						if path != "" and String(c.outfit) == path:
							icon = String(c.icon)
							name = String(c.name)
					if path == "" and id == "body":
						icon = String(GameData.class_data(cid).get("icon", ""))
						name = "Tenue de la classe"
				"aura":
					var worn_a := Profile.worn_auras(cid)
					if not worn_a.is_empty():
						icon = String(worn_a[0].icon)
						name = String(worn_a[0].name)
				"weapon":
					# l'apparence choisie pour ce type d'arme, sinon l'arme portée (P16 : l'emplacement montrait
					# toujours l'arme d'origine alors que le héros portait l'apparence)
					var wi: Dictionary = Profile.equipped.get("weapon", {})
					var wt := Items.weapon_type_of(wi) if not wi.is_empty() else String(GameData.class_data(cid).get("weapon_type", ""))
					var sk := Archive.chosen_skin(wt)
					icon = String(sk.get("icon", wi.get("icon", "")))
					name = String(sk.get("name", Items.display_name(wi) if not wi.is_empty() else ""))
					if not sk.is_empty() and not wi.is_empty():
						sub = "\n[color=#c8c8d4]Arme portée : %s[/color]" % Items.display_name(wi)
			b.icon = UiTheme.texture(icon) if icon != "" else null
			b.text = "" if icon != "" else "＋"
			b.tip = "[b]%s[/b]%s" % [name, sub] if name != "" else "[color=#c8c8d4]Vide : clique pour choisir[/color]"
			b.set_meta("report", "Emplacement d'apparence %s : %s%s" % [id, name if name != "" else "vide",
				(" (%s)" % String(w.get(id, ""))) if id in ["head", "back"] and String(w.get(id, "")) != "" else ""])
			var on: bool = id == _slot
			b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.08, 0.06, 0.13, 0.95), UiTheme.GOLD if on else UiTheme.GOLD_DIM, 3 if on else 1, 10))
			b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.15, 0.11, 0.24, 1.0), UiTheme.GOLD, 2, 10))

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
		_refresh_dye(cid)
		_refresh_slots(cid)
		var names := {"body": "Tenue", "head": "Tête", "back": "Dos", "aura": "Aura", "weapon": "Apparence de l'arme"}
		_title.text = String(names.get(_slot, "Apparence"))

	# --- couleurs de la pièce portée ---------------------------------------------------------
	const DYE_NAMES := ["Couleur principale", "Couleur secondaire", "Détails"]

	## Pièce portée dans la catégorie affichée ("" : aucune ou tenue de la classe).
	func _worn_path(cid: String) -> String:
		if _cat == "body":
			return Profile.outfit_of(cid)
		return String(Profile.worn.get(cid, {}).get(_cat, "")) if _cat in ["head", "back"] else ""

	func _refresh_dye(cid: String) -> void:
		for c in _dye_box.get_children():
			c.queue_free()
		if _cat == "aura":
			_refresh_aura_tint(cid)
			return
		var path := _worn_path(cid)
		if path == "":
			return
		if not EdenModel.can_dye(path):
			# texture cuite : pas de nuancier qui ne ferait rien, une ligne qui le dit
			ItemWidgets.section(_dye_box, "Couleurs", 15)
			var fixed := Label.new()
			fixed.text = "Non teintable : cette pièce garde ses couleurs."
			fixed.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
			fixed.add_theme_color_override("font_color", Color(0.72, 0.7, 0.8))
			_dye_box.add_child(fixed)
			return
		var cos := {}
		for c in GameData.cosmetics:
			if String(c.outfit) == path:
				cos = c
		var variants: Array = cos.get("variants", []) if cos.get("variants", []) is Array else []
		var cur := Profile.dye_of(cid, _cat)
		var shown: Array = cur if not cur.is_empty() else (variants[0].colors if not variants.is_empty() else [[200, 200, 200], [150, 150, 150], [80, 80, 80]])
		ItemWidgets.section(_dye_box, "Couleurs", 15)
		if not variants.is_empty():
			var flow := HFlowContainer.new()
			flow.add_theme_constant_override("h_separation", 6)
			flow.add_theme_constant_override("v_separation", 6)
			_dye_box.add_child(flow)
			for v in variants:
				flow.add_child(_swatch(cid, v.colors, String(v.get("name", "")), str(v.colors) == str(shown)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_dye_box.add_child(row)
		var pickers: Array = []
		for i in 3:
			var pb := ColorPickerButton.new()
			pb.custom_minimum_size = Vector2(70, 32)
			pb.focus_mode = Control.FOCUS_NONE
			pb.edit_alpha = false
			pb.tooltip_text = DYE_NAMES[i]
			var c: Array = shown[i]
			pb.color = Color8(int(c[0]), int(c[1]), int(c[2]))
			row.add_child(pb)
			pickers.append(pb)
		for pb in pickers:
			pb.color_changed.connect(func(_c):
				var cols: Array = pickers.map(func(p): return [p.color.r8, p.color.g8, p.color.b8])
				_set_dye(cid, cols, false))
			pb.popup_closed.connect(func(): Profile.save_profile())
		var reset := Button.new()
		reset.text = "Origine"
		reset.tooltip_text = "Couleurs d'origine de la pièce"
		reset.focus_mode = Control.FOCUS_NONE
		reset.pressed.connect(func(): _set_dye(cid, [], true))
		row.add_child(reset)

	func _swatch(cid: String, colors: Array, name: String, on: bool) -> Control:
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 30)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = name if name != "" else "Coloris"
		b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.08, 0.06, 0.13), UiTheme.GOLD if on else UiTheme.GOLD_DIM, 3 if on else 1, 6))
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 5
		h.offset_right = -5
		h.offset_top = 5
		h.offset_bottom = -5
		h.add_theme_constant_override("separation", 0)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		for c in colors:
			var r := ColorRect.new()
			r.color = Color8(int(c[0]), int(c[1]), int(c[2]))
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(r)
		b.pressed.connect(func(): _set_dye(cid, colors.duplicate(true), true))
		return b

	## Teinture de l'aura : une couleur qui remplace la teinte de l'effet (nuances gardées).
	func _refresh_aura_tint(cid: String) -> void:
		if Profile.worn_auras(cid).is_empty():
			return
		ItemWidgets.section(_dye_box, "Couleur de l'aura", 15)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_dye_box.add_child(row)
		var cur := Profile.aura_tint(cid)
		for preset in [[255, 80, 60], [255, 190, 60], [90, 230, 110], [70, 170, 255], [170, 90, 255], [255, 120, 220], [235, 235, 245]]:
			var col := Color8(preset[0], preset[1], preset[2])
			var b := Button.new()
			b.custom_minimum_size = Vector2(30, 30)
			b.focus_mode = Control.FOCUS_NONE
			b.add_theme_stylebox_override("normal", UiTheme.flat_box(col, UiTheme.GOLD if cur.a > 0.0 and cur.is_equal_approx(col) else UiTheme.GOLD_DIM, 2, 6))
			var rgb: Array = preset
			b.pressed.connect(func():
				Profile.set_aura_tint(cid, rgb)
				Profile.save_profile()
				refresh())
			row.add_child(b)
		var pb := ColorPickerButton.new()
		pb.custom_minimum_size = Vector2(70, 30)
		pb.focus_mode = Control.FOCUS_NONE
		pb.edit_alpha = false
		pb.color = cur if cur.a > 0.0 else Color(1, 1, 1)
		pb.tooltip_text = "Couleur libre"
		pb.color_changed.connect(func(c):
			Profile.set_aura_tint(cid, [c.r8, c.g8, c.b8])
			_preview.show_hero(cid, _shown_code if _shown_code != "" else Profile.weapon_code()))
		pb.popup_closed.connect(func(): Profile.save_profile())
		row.add_child(pb)
		var reset := Button.new()
		reset.text = "Origine"
		reset.focus_mode = Control.FOCUS_NONE
		reset.tooltip_text = "Couleurs d'origine de l'aura"
		reset.pressed.connect(func():
			Profile.set_aura_tint(cid, [])
			Profile.save_profile()
			refresh())
		row.add_child(reset)

	## Nouvelles couleurs (vide : origine) ; [param rebuild] : redessine aussi les nuanciers.
	func _set_dye(cid: String, colors: Array, rebuild: bool) -> void:
		Profile.set_dye(cid, _cat, colors)
		if rebuild:
			Profile.save_profile()
			_refresh_dye(cid)
		_preview.show_hero(cid, _shown_code if _shown_code != "" else Profile.weapon_code())

	func _refresh_costumes(cid: String) -> void:
		_grid.columns = _grid_cols()
		var list := GameData.cosmetics.filter(func(c): return cat_of(c) == _cat)
		var owned := list.filter(func(c): return Profile.outfit_unlocked(String(c.id)))
		_count.text = "%d / %d débloqués" % [owned.size(), list.size()]
		_hint.text = "%d à découvrir : %s" % [list.size() - owned.size(), LOOK_FROM] if owned.size() < list.size() else ""
		_hint.visible = _hint.text != ""
		_grid.add_child(_cell({}, cid))
		# débloqués d'abord, puis le reste
		for c in owned:
			if _match(c):
				_grid.add_child(_cell(c, cid))
		if not _owned_only.button_pressed:
			for c in list:
				if not Profile.outfit_unlocked(String(c.id)) and _match(c):
					_grid.add_child(_cell(c, cid))

	## Colonnes de la grille des tenues / dos / auras : 5 cases de 110 px débordaient à 1280×720 (PRP-2), 4 sous 1500 px.
	func _grid_cols() -> int:
		return 5 if get_viewport().get_visible_rect().size.x >= 1500.0 else 4

	## Filtre de recherche (nom).
	func _match(c: Dictionary) -> bool:
		var q := _search.text.strip_edges().to_lower()
		return q == "" or String(c.get("name", "")).to_lower().contains(q)

	func _refresh_auras(cid: String) -> void:
		_grid.columns = _grid_cols()
		var got := GameData.auras.filter(func(x): return Profile.collected(x))
		_count.text = "%d / %d débloquées" % [got.size(), GameData.auras.size()]
		_hint.text = "%d à découvrir : %s" % [GameData.auras.size() - got.size(), LOOK_FROM] if got.size() < GameData.auras.size() else ""
		_hint.visible = _hint.text != ""
		var kinds: Array = ["star", "luna", "other"]
		_grid.add_child(_aura_cell({}, cid, ""))
		for x in got:
			if _match(x) and String(x.aura.kind) in kinds:
				_grid.add_child(_aura_cell(x, cid, String(x.aura.kind)))
		if not _owned_only.button_pressed:
			for x in GameData.auras:
				if not Profile.collected(x) and _match(x) and String(x.aura.kind) in kinds:
					_grid.add_child(_aura_cell(x, cid, String(x.aura.kind)))

	## Apparence de l'arme : l'arme portée (modèles de base, armes archivées), puis les
	## apparences d'armes de la collection (pour n'importe quelle arme), puis les modèles de base
	## des autres types d'armes.
	func _refresh_weapon(cid: String) -> void:
		_grid.columns = 1
		_hint.text = "Le choix vaut pour toutes les armes de ce type, quelle que soit la classe."
		_hint.visible = true
		var w: Dictionary = Profile.equipped.get("weapon", {})
		var mine := Items.weapon_type_of(w) if not w.is_empty() else String(GameData.class_data(cid).get("weapon_type", ""))
		var n := 0
		if GameData.weapon_types.has(mine):
			n += _weapon_row(mine, true)
		# apparences d'armes de la collection : obtenues d'abord, puis les autres (verrouillées)
		# créations maison (PrpLooks) d'abord, puis les apparences d'origine
		var all_skins := GameData.collection.filter(func(x): return x.has("skin"))
		var skins := all_skins.filter(func(x): return x.has("prp")) + all_skins.filter(func(x): return not x.has("prp"))
		var got := skins.filter(func(x): return Profile.collected(x))
		var t := Hud._label(_grid, "Apparences · %d / %d" % [got.size(), skins.size()], 16, UiTheme.GOLD)
		t.add_theme_font_override("font", UiTheme.bold_font())
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 8)
		_grid.add_child(flow)
		for x in got:
			if _match(x):
				flow.add_child(_eden_skin_cell(mine, x, true))
		if not _owned_only.button_pressed:
			for x in skins:
				if not Profile.collected(x) and _match(x):
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
		lbl.custom_minimum_size = Vector2(150 if _grid_cols() == 5 else 84, 0)  # 1280 : nom sur deux lignes, la rangée tient
		if _grid_cols() < 5:
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(_skin_cell(wt, -1, {}))
		var ws := Archive.skins(wt).filter(func(sk): return not GameData.skin_by_code.has(String(sk.code)))
		for i in ws.size():
			row.add_child(_skin_cell(wt, i, ws[i]))
		return ws.size()

	## Case d'une apparence d'arme de la collection (appliquée au type de l'arme portée).
	func _eden_skin_cell(wt: String, x: Dictionary, ok: bool) -> Control:
		var code := String(x.code)
		var on := String(Profile.skins.get(wt, "")) == code
		var b := ItemWidgets.TipButton.new()
		b.custom_minimum_size = Vector2(68, 68)
		b.focus_mode = Control.FOCUS_NONE
		b.set_meta("report", "Apparence d'arme %s « %s » (code %s)" % [wt, String(x.get("name", "")), code])
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
		b.tip = Archive.collection_text(x) + ("" if ok else "\n[color=#ff9a7a]Verrouillée : %s[/color]\n[color=#9a98a8]%s[/color]\n[color=#9a98a8]Clic : aperçu[/color]" % [LOOK_FROM, LOOK_WHERE])
		b.pressed.connect(func():
			_shown_code = code  # aperçu même verrouillée
			if ok:
				Profile.set_skin(wt, "" if on else code)
			refresh())
		return b

	## Bonus de l'aura portée (le reste de ce que porte la classe se lit sur les emplacements).
	func _worn_text(cid: String) -> String:
		var parts: PackedStringArray = []
		var b := Profile.aura_stats(cid)
		for st in b:
			parts.append(Items.stat_text(st, b[st]))
		return "[color=#7fe08a]%s en partie[/color]" % ", ".join(parts) if not parts.is_empty() else ""

	static func _box(on: bool, ok: bool) -> StyleBoxFlat:
		return UiTheme.flat_box(Color(0.08, 0.06, 0.13, 0.95), UiTheme.GOLD if on else (UiTheme.GOLD_DIM if ok else Color(0.25, 0.23, 0.3)), 3 if on else 2, 8)

	## Case d'aura ([param x] vide : retirer l'aura de ce type).
	func _aura_cell(x: Dictionary, cid: String, kind: String) -> Control:
		var ok := x.is_empty() or Profile.collected(x)
		var worn_a := Profile.worn_auras(cid)
		var cur := int(worn_a[0].id) if not worn_a.is_empty() else 0
		var on := (cur == 0) if x.is_empty() else (cur == int(x.id))
		var b := ItemWidgets.TipButton.new()
		b.custom_minimum_size = Vector2(110, 96)
		b.focus_mode = Control.FOCUS_NONE
		if not x.is_empty():
			b.set_meta("report", "Aura %s « %s » (collection %s, effet %s)" % [kind, String(x.get("name", "")), str(x.get("id", "")), str(x.get("aura", {}).get("fx", ""))])
		b.clip_text = true
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 48)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_stylebox_override("normal", _box(on, ok))
		if x.is_empty():
			b.text = "Aucune aura"
		else:
			b.text = String(x.name) if ok else "🔒 " + String(x.name)
			b.icon = UiTheme.texture(String(x.icon))
			b.tip = Archive.collection_text(x) + ("" if ok else "\n[color=#ff9a7a]Verrouillée : %s[/color]\n[color=#9a98a8]%s[/color]" % [LOOK_FROM, LOOK_WHERE])
			if not ok:
				b.modulate = Color(0.6, 0.6, 0.65)
		b.pressed.connect(func():
			if not ok:
				return
			if x.is_empty() or on:
				for k in ["star", "luna", "other"]:
					Profile.set_aura(cid, k, 0)
			else:
				Profile.set_aura(cid, kind, int(x.id))  # retire l'aura portée avant
			Profile.save_profile()
			refresh())
		return b

	func _cell(c: Dictionary, cid: String) -> Control:
		var ok := c.is_empty() or Profile.outfit_unlocked(String(c.id))
		var on := _current(cid) == String(c.get("outfit", ""))
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 108)
		b.focus_mode = Control.FOCUS_NONE
		if not c.is_empty():
			b.set_meta("report", "Apparence %s « %s » (id %s, modèle %s)" % [_cat, String(c.get("name", "")), String(c.get("id", "")), String(c.get("outfit", ""))])
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # nom sur deux lignes plutôt que coupé
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
			b.tooltip_text = String(c.name) + ("" if ok else "\nVerrouillé : %s\n%s" % [LOOK_FROM, LOOK_WHERE])
			if not ok:
				b.modulate = Color(0.6, 0.6, 0.65)
		b.pressed.connect(func():
			if not ok:
				return
			var path := String(c.get("outfit", ""))
			Profile.set_dye(cid, _cat, [])  # autre pièce : ses propres couleurs d'origine
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


# --- cartes : méta-progression ---------------------------------------------------------------
## Toutes les cartes de build : disponibles (en couleur) ou à débloquer (condition et
## avancement, cumulés sur toutes les runs) ; passifs de la classe affichée à part.
class CardsPage extends HBoxContainer:
	var _grid: VBoxContainer  # groupes : titre puis grille de cartes
	var _cur: GridContainer
	var _count: Label
	var _detail: RichTextLabel
	var _filter: OptionButton

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		var left := ItemWidgets.panel(self, 0, true)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		left.add_child(head)
		ItemWidgets.section(head, "Cartes de build")
		_count = Hud._label(head, "", 14, UiTheme.MUTED)
		_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_count.mouse_filter = Control.MOUSE_FILTER_PASS
		_count.tooltip_text = "Cartes communes : pour toutes les classes. Cartes de classe : seulement en partie de cette classe, elles renforcent un sort. Certificats : posés sur le plateau (Classe > Certificats), ils sont acquis dès le début de la partie. Les verrouillées se débloquent pour toujours avec leur exploit. Pendant le choix : Bannir retire une carte de la partie, Garder la repropose au choix suivant (3 fois chacun par partie)."
		_filter = OptionButton.new()
		for t in ["Toutes", "Communes", "De la classe", "À débloquer"]:
			_filter.add_item(t)
		_filter.focus_mode = Control.FOCUS_NONE
		_filter.item_selected.connect(func(_i): refresh())
		head.add_child(_filter)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		left.add_child(sc)
		_grid = VBoxContainer.new()
		_grid.add_theme_constant_override("separation", 8)
		sc.add_child(_grid)
		var right := ItemWidgets.panel(self, 420)
		ItemWidgets.section(right, "Fiche")
		_detail = ItemWidgets.rich(right, 15)

	func _cid() -> String:
		return Run.class_id if Profile.in_run else Profile.selected_class

	func refresh() -> void:
		if not is_inside_tree():
			return
		for c in _grid.get_children():
			c.queue_free()
		var all := Boons.all()
		var open := all.filter(func(d): return Cards.card_unlocked(String(d.id)))
		var cname := String(GameData.class_data(_cid()).get("name_fr", ""))
		var mine: Array = Cards.class_cards(_cid())
		_count.text = "%d / %d communes · %d de classe" % [open.size(), all.size(), mine.size()]
		var f := _filter.selected
		_cur = null
		var commons := all.filter(func(d): return f != 3 or not Cards.card_unlocked(String(d.id)))
		commons.sort_custom(func(a, b): return [not Cards.card_unlocked(String(a.id)), Cards.unlock_progress(String(a.id)).y] < [not Cards.card_unlocked(String(b.id)), Cards.unlock_progress(String(b.id)).y])
		if f in [0, 1, 3]:
			_sep("Cartes communes" if f != 3 else "À débloquer")
			for d in commons:
				_cur.add_child(_cell(d, ""))
		if f in [0, 2]:
			_sep("Certificats %s" % cname)
			for p in GameData.class_data(_cid()).get("passives", []):
				_cur.add_child(_cell(p, "cert"))
			_sep("Cartes %s" % cname)
			for d in mine:
				_cur.add_child(_cell(d, "class"))
		if _detail.text == "":
			# fiche de la première carte d'emblée (pas de panneau vide)
			for g in _grid.get_children():
				if g is GridContainer and g.get_child_count() > 0:
					(g.get_child(0) as Button).pressed.emit()
					break

	## Nouveau groupe : titre puis sa grille de cartes.
	func _sep(text: String) -> void:
		ItemWidgets.section(_grid, text, 15)
		_cur = GridContainer.new()
		_cur.columns = 6 if get_viewport().get_visible_rect().size.x >= 1500.0 else 4  # 1280 : la page ne doit pas sortir de l'écran
		_cur.add_theme_constant_override("h_separation", 8)
		_cur.add_theme_constant_override("v_separation", 8)
		_grid.add_child(_cur)

	func _cell(d: Dictionary, kind: String) -> Control:
		var id := String(d.id)
		var class_card := kind != ""
		var ok := class_card or Cards.card_unlocked(id)
		var rar: Dictionary = Boons.RARITY.get(String(d.get("rarity", "common")), Boons.RARITY.common)
		var b := Button.new()
		b.custom_minimum_size = Vector2(118, 104)
		b.focus_mode = Control.FOCUS_NONE
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 48)
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.08, 0.06, 0.13, 0.95), rar.color if ok else Color(0.25, 0.23, 0.3), 2, 8))
		b.icon = UiTheme.texture(String(d.get("icon", Boons.ICONS.get(id, ""))))
		if ok:
			b.text = String(d.name)
		else:
			var p := Cards.unlock_progress(id)
			b.text = "🔒 %s\n%d / %d" % [d.name, int(p.x), int(p.y)]
			b.modulate = Color(0.65, 0.65, 0.72)
		b.pressed.connect(func():
			var ic := String(d.get("icon", Boons.ICONS.get(id, "")))
			var lines: PackedStringArray = [("[img=48x48]%s[/img]  " % ic if ic != "" else "") + "[font_size=19][b][color=#%s]%s[/color][/b][/font_size]" % [rar.color.to_html(false), d.name],
				"[color=#9a98a8]%s · jusqu'au niveau %d%s[/color]" % [{"cert": "Certificat %s" % String(GameData.class_data(_cid()).get("name_fr", "")), "class": "Carte de classe %s · sort « %s »" % [String(rar.name).to_lower(), d.get("skill_name", "")]}.get(kind, String(rar.name)), mini(int(d.get("max", 1)), Cards.MAX_LEVEL),
					" · effet immédiat" if d.get("instant", false) else ""], "", String(d.get("desc", ""))]
			var tl := Cards.stat_lines(d, 0.0, 1.0)
			if not tl.is_empty():
				lines.append("\n[color=#9fd0ff]Par carte : %s[/color]" % " ; ".join(tl))
			for pr in Boons.procs_of(d, 1.0):
				lines.append("[color=#ffd76a]%s[/color]" % Procs.describe(pr))
			if not ok:
				var p := Cards.unlock_progress(id)
				lines.append("\n[color=#ffcf6b]" + Ico.LOCK_BB + " Pour la débloquer : %s — %d / %d[/color]" % [Cards.unlock_text(id), int(p.x), int(p.y)])
			_detail.text = "\n".join(lines))
		return b



# --- choix de la classe : menu compact par famille ---------------------------------------------
## Menu déroulant sous [param anchor] : les 5 familles en colonnes, de petites étiquettes par
## classe (débloquées en couleur, les autres grisées avec leur condition au survol).
static func class_menu(anchor: Control, current: String, on_pick: Callable) -> PopupPanel:
	var pop := PopupPanel.new()
	pop.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.98), UiTheme.GOLD, 2, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pop.add_child(row)
	for fam in ClassPicker.families():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		row.add_child(col)
		var t := Hud._label(col, String(fam.name), 15, UiTheme.GOLD)
		t.add_theme_font_override("font", UiTheme.bold_font())
		for id in fam.classes:
			var cid := String(id)
			var cd := GameData.class_data(cid)
			var ok := Progression.class_unlocked(cid)
			var b := Button.new()
			b.text = String(cd.get("name_fr", cid))
			b.icon = UiTheme.texture(String(cd.get("icon", "")))
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 22)
			b.add_theme_font_size_override("font_size", 12)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			b.custom_minimum_size = Vector2(176, 28)
			var orange := String(cd.get("tier", "")) == "orange"
			b.add_theme_color_override("font_color", (ClassPicker.ORANGE if orange else ClassPicker.GREEN) if ok else Color(0.55, 0.53, 0.6))
			b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.1, 0.08, 0.18, 0.95) if cid != current else Color(0.3, 0.22, 0.08, 0.95),
				UiTheme.GOLD if cid == current else Color(0, 0, 0, 0), 1, 6))
			b.tooltip_text = ("Maîtrise %d" % Profile.expertise_level(cid)) if ok else "🔒 " + Progression.mission_line(cid)
			if orange:
				b.text = "   " + b.text
			b.pressed.connect(func():
				pop.hide()
				pop.queue_free()
				on_pick.call(cid))
			col.add_child(b)
	anchor.add_child(pop)
	pop.popup_hide.connect(pop.queue_free)
	var r := anchor.get_global_rect()
	pop.reset_size()
	var vp := anchor.get_viewport_rect().size
	pop.position = Vector2i(int(clampf(r.end.x - pop.size.x, 8.0, vp.x - pop.size.x - 8.0)), int(r.end.y + 6.0))
	pop.popup()
	return pop
