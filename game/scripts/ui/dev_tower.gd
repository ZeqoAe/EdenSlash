class_name DevTower
extends RefCounted
## Mode dev, page Tour : règles générales de la Tour (monstres, duellistes, boss, soins,
## niveaux) et réglages étage par étage (type, classe du duelliste, niveau, PV, dégâts,
## nombre de monstres, sorts du duelliste), avec la fiche de l'étage à jour à côté.
## Enregistré dans data/dev_edits.json -> "tower" (bouton Enregistrer).


class TowerPage extends HBoxContainer:
	var _rules: VBoxContainer
	var _floor_box: VBoxContainer
	var _preview: RichTextLabel
	var _msg: Label
	var _floor := 1
	var _diff := 1
	var _building := false

	func _ready() -> void:
		add_theme_constant_override("separation", 16)
		_rules = DevPages.column(self, "Règles de la Tour", 520)
		_floor_box = DevPages.column(self, "Étage", 0)

	func refresh() -> void:
		if not is_inside_tree():
			return
		_build_rules()
		_build_floor()

	# --- règles générales ---------------------------------------------------------------
	func _build_rules() -> void:
		for c in _rules.get_children().slice(1):
			c.queue_free()
		var unlock := CheckBox.new()
		unlock.text = "Tous les étages de la Tour débloqués (toutes difficultés)"
		unlock.focus_mode = Control.FOCUS_NONE
		unlock.button_pressed = bool(Settings.get_v("interface", "tower_unlock_all"))
		unlock.tooltip_text = "Tant que le mode dev est activé : on peut commencer à n'importe quel étage, sans toucher aux records."
		unlock.toggled.connect(func(on): Settings.set_v("interface", "tower_unlock_all", on))
		_rules.add_child(unlock)
		Hud._label(_rules, "Valeur par défaut au survol. Les changements s'appliquent tout de suite ; « Enregistrer » les garde (data/dev_edits.json).", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_rules.add_child(scroll)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(v)
		for k in Tower.RULES:
			var key: String = k
			var def: Array = Tower.RULES[k]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			v.add_child(row)
			var changed: bool = Tower.edits().rules.has(key)
			var l := Hud._label(row, String(def[1]), 14, UiTheme.GOLD if changed else UiTheme.TEXT)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.tooltip_text = "Par défaut : %s" % str(def[0])
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			var sp := SpinBox.new()
			sp.step = float(def[2])
			sp.min_value = 0.0
			sp.max_value = 1000.0
			sp.custom_minimum_size = Vector2(120, 0)
			sp.value = Tower.rule(key)
			sp.value_changed.connect(func(x):
				if is_equal_approx(x, float(def[0])):
					Tower.edits().rules.erase(key)
				else:
					Tower.edits().rules[key] = x
				l.add_theme_color_override("font_color", UiTheme.GOLD if Tower.edits().rules.has(key) else UiTheme.TEXT)
				_changed())
			row.add_child(sp)
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 8)
		_rules.add_child(bar)
		DevPages.button(bar, "Enregistrer", func(): _msg.text = DevEdits.save(), 140)
		DevPages.button(bar, "Règles par défaut", func():
			Tower.edits().rules.clear()
			_changed()
			_build_rules(), 170)
		_msg = Hud._label(_rules, "", 14, UiTheme.BUFF)

	# --- étage ------------------------------------------------------------------------------
	func _build_floor() -> void:
		_building = true
		for c in _floor_box.get_children().slice(1):
			c.queue_free()
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 8)
		_floor_box.add_child(top)
		Hud._label(top, "Étage", 15, UiTheme.TEXT)
		var fs := SpinBox.new()
		fs.min_value = 1
		fs.max_value = Tower.FLOORS
		fs.value = _floor
		fs.value_changed.connect(func(x):
			_floor = int(x)
			_build_floor.call_deferred())
		top.add_child(fs)
		Hud._label(top, "Fiche en", 15, UiTheme.TEXT)
		var ds := OptionButton.new()
		ds.focus_mode = Control.FOCUS_NONE
		for n in Tower.DIFF_NAMES:
			ds.add_item(n)
		ds.select(_diff)
		ds.item_selected.connect(func(i):
			_diff = i
			_refresh_preview())
		top.add_child(ds)
		DevPages.button(top, "Réinitialiser l'étage", func():
			Tower.edits().floors.erase(str(_floor))
			_changed()
			_build_floor.call_deferred(), 180)
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 10)
		_floor_box.add_child(grid)
		var e := Tower.floor_edit(_floor)
		# type
		Hud._label(grid, "Type", 14, UiTheme.TEXT)
		var ty := OptionButton.new()
		ty.focus_mode = Control.FOCUS_NONE
		ty.add_item("Par défaut (%s)" % Tower.TYPE_NAMES[Tower.default_type(_floor)])
		for t in Tower.TYPES:
			ty.add_item(String(Tower.TYPE_NAMES[t]))
		ty.select(Tower.TYPES.find(String(e.get("type", ""))) + 1)
		ty.item_selected.connect(func(i): _set_field("type", Tower.TYPES[i - 1] if i > 0 else null))
		grid.add_child(ty)
		# classe du duelliste
		Hud._label(grid, "Duelliste", 14, UiTheme.TEXT)
		var cl := OptionButton.new()
		cl.focus_mode = Control.FOCUS_NONE
		var ids: Array = GameData.classes.keys()
		ids.sort()
		cl.add_item("Par défaut")
		for id in ids:
			cl.add_item(String(GameData.class_data(String(id)).get("name_fr", id)))
		cl.select(ids.find(String(e.get("class", ""))) + 1)
		cl.item_selected.connect(func(i): _set_field("class", ids[i - 1] if i > 0 else null))
		grid.add_child(cl)
		_spin(grid, "Niveau (0 : auto)", "level", 0, 200, 1, 0)
		_spin(grid, "Monstres (-1 : auto)", "count", -1, 200, 1, -1)
		_spin(grid, "PV ×", "hp", 0.05, 20, 0.05, 1.0)
		_spin(grid, "Dégâts ×", "atk", 0.05, 20, 0.05, 1.0)
		_spin(grid, "Sorts du duelliste (-1 : auto)", "skills", -1, 4, 1, -1)
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_floor_box.add_child(scroll)
		_preview = RichTextLabel.new()
		_preview.bbcode_enabled = true
		_preview.fit_content = true
		_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_preview)
		_building = false
		_refresh_preview()

	## Champ numérique de l'étage : la valeur [param unset] retire le réglage.
	func _spin(grid: GridContainer, label: String, key: String, lo: float, hi: float, step: float, unset: float) -> void:
		Hud._label(grid, label, 14, UiTheme.TEXT)
		var sp := SpinBox.new()
		sp.min_value = lo
		sp.max_value = hi
		sp.step = step
		sp.custom_minimum_size = Vector2(110, 0)
		sp.value = float(Tower.floor_edit(_floor).get(key, unset))
		sp.value_changed.connect(func(x): _set_field(key, null if is_equal_approx(x, unset) else x))
		grid.add_child(sp)

	func _set_field(key: String, value) -> void:
		if _building:
			return
		var fl: Dictionary = Tower.edits().floors
		var e: Dictionary = fl.get(str(_floor), {})
		if value == null:
			e.erase(key)
		else:
			e[key] = value
		if e.is_empty():
			fl.erase(str(_floor))
		else:
			fl[str(_floor)] = e
		_changed()

	func _changed() -> void:
		Tower.edited()
		if _msg:
			_msg.text = "Modifié (pas encore enregistré)"
		_refresh_preview()

	func _refresh_preview() -> void:
		if _preview and not _building:
			_preview.text = TowerPages.info_text(Tower.spec(_floor, _diff))
