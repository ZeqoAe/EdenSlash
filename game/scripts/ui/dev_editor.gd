class_name DevEditor
## Éditeur du mode dev : objets possédés (stats bonus, rareté, amélioration, qualité, set,
## passif et buff sous condition), modèles du catalogue (stats, rareté, niveau, set, passif,
## exclusion du butin) et sets (création, pièces, bonus par nombre de pièces).
## Les modèles et les sets sont enregistrés dans data/dev_edits.json (DevEdits).

## Toutes les stats qu'on peut mettre sur un objet : [clé, nom].
static func stat_choices() -> Array:
	var out: Array = []
	for k in Items.STAT_NAMES:
		if k != "atk":
			out.append([String(k), String(Items.STAT_NAMES[k])])
	for k in Items.EXTRA_STAT_NAMES:
		out.append([String(k), String(Items.EXTRA_STAT_NAMES[k]) + (" %" if k in Items.PERCENT_STATS else "")])
	return out


## Stat exprimée en pourcentage (objets et cartes).
static func is_pct(k: String) -> bool:
	return k in Items.PERCENT_STATS or (Cards.STAT_FR.has(k) and String(Cards.STAT_FR[k][1]) == "%")


## Liste des familles de buff sous condition (trophées) : "" = aucun.
static func kind_option(current: String) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.add_item("Aucun buff sous condition")
	o.set_item_metadata(0, "")
	var i := 1
	for k in Trophies.KINDS:
		var p := Trophies.proc_for(String(k), Items.LEGENDARY)
		o.add_item("%s : %s" % [Trophies.KINDS[k].name, Trophies.describe(p)])
		o.set_item_metadata(i, String(k))
		if String(k) == current:
			o.select(i)
		i += 1
	o.fit_to_longest_item = false
	o.clip_text = true
	return o


static func option_value(o: OptionButton) -> String:
	return String(o.get_item_metadata(o.selected)) if o.selected >= 0 else ""


## Sets connus, triés : ceux créés en jeu d'abord.
static func set_option(current: String) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	o.fit_to_longest_item = false
	o.clip_text = true
	o.add_item("Aucun set")
	o.set_item_metadata(0, "")
	var ids := GameData.eden_sets.keys()
	ids.sort_custom(func(a, b): return [not String(a).begins_with("u"), String(GameData.eden_sets[a].get("name", ""))] < [not String(b).begins_with("u"), String(GameData.eden_sets[b].get("name", ""))])
	var i := 1
	for sid in ids:
		o.add_item(("★ " if String(sid).begins_with("u") else "") + String(GameData.eden_sets[sid].get("name", sid)))
		o.set_item_metadata(i, String(sid))
		if String(sid) == current:
			o.select(i)
		i += 1
	return o


static func rarity_option(current: int) -> OptionButton:
	var o := OptionButton.new()
	o.focus_mode = Control.FOCUS_NONE
	for r in Items.RARITIES:
		o.add_item(String(r.name))
	o.select(clampi(current, 0, Items.RARITIES.size() - 1))
	return o


static func spin(min_v: float, max_v: float, step: float, value: float, width := 110.0) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(width, 0)
	return s


static func row(parent: Control, label: String, ctrl: Control, label_w := 170.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	var l := Hud._label(h, label, 15, UiTheme.TEXT)
	l.custom_minimum_size = Vector2(label_w, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ctrl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(ctrl)
	return h


# --- éditeur de stats --------------------------------------------------------------------------
## Liste de stats éditable : une ligne par stat (choix, valeur, ✕) et « + Ajouter une stat ».
## [member ratio] : rapports relatifs du catalogue (1,0 = valeur normale de l'emplacement) ;
## sinon les stats en % s'affichent en %.
class StatEditor extends VBoxContainer:
	signal changed
	var ratio := false
	var _rows: VBoxContainer
	var _choices: Array

	func _init(is_ratio := false, extra: Array = []) -> void:
		ratio = is_ratio
		_choices = DevEditor.stat_choices() + extra
		add_theme_constant_override("separation", 4)
		_rows = VBoxContainer.new()
		_rows.add_theme_constant_override("separation", 4)
		add_child(_rows)
		var add := Button.new()
		add.text = "+ Ajouter une stat"
		add.focus_mode = Control.FOCUS_NONE
		add.pressed.connect(func():
			_add_row("str", 1.0 if ratio else 10.0)
			changed.emit())
		add_child(add)

	func set_values(d: Dictionary) -> void:
		for c in _rows.get_children():
			c.free()
		for k in d:
			_add_row(String(k), float(d[k]))

	func get_values() -> Dictionary:
		var out := {}
		for r in _rows.get_children():
			var o: OptionButton = r.get_child(0)
			var sp: SpinBox = r.get_child(1)
			var k := String(_choices[o.selected][0])
			var v := float(sp.value)
			if not ratio and DevEditor.is_pct(k):
				v /= 100.0
			if absf(v) > 0.00001:
				out[k] = float(out.get(k, 0.0)) + v
		return out

	func _add_row(key: String, value: float) -> void:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		_rows.add_child(h)
		var o := OptionButton.new()
		o.focus_mode = Control.FOCUS_NONE
		o.fit_to_longest_item = false
		o.custom_minimum_size = Vector2(230, 0)
		for i in _choices.size():
			o.add_item(String(_choices[i][1]))
			if String(_choices[i][0]) == key:
				o.select(i)
		h.add_child(o)
		var pct := not ratio and DevEditor.is_pct(key)
		var sp := DevEditor.spin(-100000.0, 100000.0, 0.01 if ratio else (0.5 if pct else 1.0), value * (100.0 if pct else 1.0), 130.0)
		sp.suffix = "×" if ratio else ("%" if pct else "")
		h.add_child(sp)
		o.item_selected.connect(func(i):
			# passage d'une stat fixe à une stat en % (ou l'inverse) : l'unité change
			if not ratio:
				sp.suffix = "%" if DevEditor.is_pct(String(_choices[i][0])) else ""
				sp.step = 0.5 if sp.suffix == "%" else 1.0
			changed.emit())
		sp.value_changed.connect(func(_v): changed.emit())
		var x := Button.new()
		x.text = "✕"
		x.focus_mode = Control.FOCUS_NONE
		x.pressed.connect(func():
			h.queue_free()
			changed.emit.call_deferred())
		h.add_child(x)


# --- page Éditer : objets possédés et modèles du catalogue ------------------------------------
class EditPage extends HBoxContainer:
	var _mode: OptionButton
	var _search: LineEdit
	var _list: ItemList
	var _entries: Array = []  # objets possédés ou modèles affichés dans la liste
	var _form: VBoxContainer
	var _preview: RichTextLabel
	var _msg: Label
	var _item: Dictionary = {}  # objet possédé édité
	var _tpl: Dictionary = {}  # modèle du catalogue édité
	# champs du formulaire
	var _name: LineEdit
	var _rar: OptionButton
	var _level: SpinBox
	var _up: SpinBox
	var _quality: SpinBox
	var _power: SpinBox
	var _set: OptionButton
	var _nopool: CheckBox
	var _stats: StatEditor
	var _pname: LineEdit
	var _pstats: StatEditor
	var _kind: OptionButton

	func _ready() -> void:
		add_theme_constant_override("separation", 14)
		var left := ItemWidgets.panel(self, 360)
		_mode = OptionButton.new()
		_mode.focus_mode = Control.FOCUS_NONE
		_mode.add_item("Mes objets (coffre, sac, porté)")
		_mode.add_item("Modèles du catalogue (tous les objets)")
		_mode.item_selected.connect(func(_i): _refresh_list())
		left.add_child(_mode)
		_search = LineEdit.new()
		_search.placeholder_text = "Rechercher un nom…"
		_search.text_changed.connect(func(_t): _refresh_list())
		left.add_child(_search)
		_list = ItemList.new()
		_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_list.fixed_icon_size = Vector2i(32, 32)
		_list.item_selected.connect(func(i): _select(_entries[i]))
		left.add_child(_list)
		var mid := ItemWidgets.panel(self, 0, true)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		mid.add_child(sc)
		_form = VBoxContainer.new()
		_form.add_theme_constant_override("separation", 8)
		_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(_form)
		_msg = Hud._label(mid, "", 14, UiTheme.BUFF)
		_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var right := ItemWidgets.panel(self, 380)
		ItemWidgets.section(right, "Aperçu")
		_preview = ItemWidgets.rich(right, 14)

	func refresh() -> void:
		if is_inside_tree():
			_refresh_list()

	## Ouvre directement le modèle [param e] (bouton « Éditer ce modèle » du catalogue).
	func edit_template(e: Dictionary) -> void:
		_mode.select(1)
		_search.text = String(e.name)
		_refresh_list()
		_select(e)

	func _refresh_list() -> void:
		_list.clear()
		var q := _search.text.strip_edges().to_lower()
		if _mode.selected == 0:
			_entries = DevEdits.owned_items().filter(func(it): return q == "" or Items.display_name(it).to_lower().contains(q))
		else:
			_entries = GameData.eden_items.filter(func(e): return q == "" or String(e.name).to_lower().contains(q)).slice(0, 300)
		for x in _entries:
			var label := Items.display_name(x) if _mode.selected == 0 else "%s · niv. %d%s" % [x.name, int(x.level), "  ✎" if DevEdits.is_edited(int(x.id)) else ""]
			var i := _list.add_item(label, UiTheme.texture(String(x.get("icon", ""))))
			_list.set_item_custom_fg_color(i, Items.RARITIES[clampi(int(x.get("rarity", 0)), 0, 5)].color)
		if _entries.is_empty():
			_list.add_item("Rien à afficher")
		_select_none()

	func _select_none() -> void:
		_item = {}
		_tpl = {}
		for c in _form.get_children():
			c.queue_free()
		Hud._label(_form, "Choisis un objet dans la liste.", 15, UiTheme.MUTED)
		_preview.text = ""

	func _select(x: Dictionary) -> void:
		for c in _form.get_children():
			c.free()
		_msg.text = ""
		if _mode.selected == 0:
			_item = x
			_tpl = {}
			_build_owned_form()
		else:
			_tpl = x
			_item = {}
			_build_template_form()
		_update_preview()

	func _common_fields(name: String, rarity: int, set_id: String) -> void:
		_name = LineEdit.new()
		_name.text = name
		_name.text_changed.connect(func(_t): _update_preview())
		DevEditor.row(_form, "Nom", _name)
		_rar = DevEditor.rarity_option(rarity)
		_rar.item_selected.connect(func(_i): _update_preview())
		DevEditor.row(_form, "Rareté", _rar)
		_set = DevEditor.set_option(set_id)
		_set.item_selected.connect(func(_i): _update_preview())
		DevEditor.row(_form, "Set", _set)

	func _passive_fields(p: Dictionary, kind: String) -> void:
		ItemWidgets.section(_form, "Passif : bonus fixes et buff sous condition", 16)
		_pname = LineEdit.new()
		_pname.text = String(p.get("name", ""))
		_pname.placeholder_text = "(nom du buff si vide)"
		_pname.text_changed.connect(func(_t): _update_preview())
		DevEditor.row(_form, "Nom du passif", _pname)
		_pstats = StatEditor.new(false)
		_pstats.set_values(p.get("stat", {}))
		_pstats.changed.connect(_update_preview)
		_form.add_child(_pstats)
		_kind = DevEditor.kind_option(kind)
		_kind.item_selected.connect(func(_i): _update_preview())
		DevEditor.row(_form, "Buff sous condition", _kind)
		Hud._label(_form, "La force du buff suit la rareté de l'objet (commun : faible, légendaire : fort).", 12, UiTheme.MUTED)

	func _build_owned_form() -> void:
		var it := _item
		ItemWidgets.section(_form, "Objet possédé", 18)
		_common_fields(String(it.get("name", "")), int(it.rarity), String(it.get("set", "")))
		_up = DevEditor.spin(0, Items.MAX_UPGRADE, 1, int(it.get("upgrade", 0)))
		_up.value_changed.connect(func(_v): _update_preview())
		DevEditor.row(_form, "Amélioration (+)", _up)
		_quality = DevEditor.spin(10, 300, 1, roundi(float(it.get("quality", 1.0)) * 100))
		_quality.suffix = "%"
		_quality.value_changed.connect(func(_v): _update_preview())
		DevEditor.row(_form, "Qualité", _quality)
		_power = DevEditor.spin(1, 200, 1, Items.power_level(it))
		_power.value_changed.connect(func(_v): _update_preview())
		DevEditor.row(_form, "Puissance (niveau de run)", _power)
		ItemWidgets.section(_form, "Stats bonus (valeurs ajoutées telles quelles)", 16)
		_stats = StatEditor.new(false)
		_stats.set_values(it.get("affixes", {}))
		_stats.changed.connect(_update_preview)
		_form.add_child(_stats)
		var pv: Dictionary = it.get("passive", {})
		_passive_fields(pv, String(pv.get("trophy", "")))
		var acts := HBoxContainer.new()
		acts.add_theme_constant_override("separation", 8)
		_form.add_child(acts)
		DevPages.button(acts, "Enregistrer l'objet", _save_owned, 220)
		DevPages.button(acts, "Dupliquer", func():
			var copy := _apply_owned(_item.duplicate(true))
			copy.uid = "%d_%d" % [Time.get_ticks_usec(), randi() % 100000]
			Profile.add_item(copy)
			Profile.save_profile()
			_msg.text = "Copie ajoutée %s." % ("au sac" if Profile.in_run else "au coffre"), 140)

	## Applique le formulaire à [param it] et le renvoie.
	func _apply_owned(it: Dictionary) -> Dictionary:
		it.name = _name.text
		it.rarity = _rar.selected
		it.upgrade = int(_up.value)
		it.quality = float(_quality.value) / 100.0
		it.plevel = int(_power.value)
		it.affixes = _stats.get_values()
		var sid := DevEditor.option_value(_set)
		if sid == "":
			it.erase("set")
		else:
			it["set"] = sid
		var kind := DevEditor.option_value(_kind)
		var pst := _pstats.get_values()
		var old: Dictionary = it.get("passive", {})
		var base_procs: Array = old.get("procs", []) if not old.has("trophy") else []
		if kind == "" and pst.is_empty() and base_procs.is_empty():
			it.erase("passive")
		else:
			it["passive"] = DevEdits.make_passive(_pname.text, pst, kind, int(it.rarity), base_procs)
		return it

	func _save_owned() -> void:
		_apply_owned(_item)
		Profile.save_profile()
		Profile.changed.emit()
		_msg.text = "Objet enregistré."
		_refresh_names()

	func _build_template_form() -> void:
		var e := _tpl
		ItemWidgets.section(_form, "Modèle du catalogue n° %d%s" % [int(e.id), "  (modifié)" if DevEdits.is_edited(int(e.id)) else ""], 18)
		Hud._label(_form, "Change ce modèle pour tous les objets qui tomberont ensuite. « Appliquer aux objets possédés » met à jour ceux que tu as déjà.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_common_fields(String(e.name), int(e.rarity), String(e.get("set", "")))
		_level = DevEditor.spin(0, 100, 1, int(e.level))
		_level.value_changed.connect(func(_v): _update_preview())
		DevEditor.row(_form, "Niveau d'Eden", _level)
		_nopool = CheckBox.new()
		_nopool.text = "Ne tombe jamais (reste dans l'archive)"
		_nopool.button_pressed = e.has("nopool")
		_nopool.focus_mode = Control.FOCUS_NONE
		_form.add_child(_nopool)
		ItemWidgets.section(_form, "Stats de base (rapport : 1,0 = valeur normale de l'emplacement)", 16)
		_stats = StatEditor.new(true)
		_stats.set_values(e.get("r", {}))
		_stats.changed.connect(_update_preview)
		_form.add_child(_stats)
		_passive_fields(e.get("passive", {}), String(e.get("trophy", "")))
		var acts := HFlowContainer.new()
		acts.add_theme_constant_override("h_separation", 8)
		acts.add_theme_constant_override("v_separation", 8)
		_form.add_child(acts)
		DevPages.button(acts, "Enregistrer le modèle", _save_template, 220)
		var n := DevEdits.owned_items().filter(func(it): return int(it.get("eden", 0)) == int(e.id)).size()
		DevPages.button(acts, "Appliquer aux objets possédés (%d)" % n, func():
			_save_template()
			_msg.text += " %d objet(s) possédé(s) mis à jour." % DevEdits.refresh_owned(int(_tpl.id)), 280)
		DevPages.button(acts, "Ajouter ×1 au coffre / sac", func():
			Profile.add_item(Items.from_template(_tpl, 20))
			Profile.save_profile()
			_msg.text = "Ajouté.", 220)
		DevPages.button(acts, "Annuler les modifications", func():
			DevPages.confirm(self, "Revenir au modèle d'Eden d'origine pour « %s » ?" % _tpl.name, func():
				DevEdits.reset_item(int(_tpl.id))
				_msg.text = DevEdits.save()
				_select(_tpl)), 240)

	func _template_fields() -> Dictionary:
		var f := {"name": _name.text, "rarity": _rar.selected, "level": int(_level.value), "r": _stats.get_values()}
		var sid := DevEditor.option_value(_set)
		f["set"] = sid if sid != "" else null
		f["nopool"] = "dev" if _nopool.button_pressed else null
		var kind := DevEditor.option_value(_kind)
		f["trophy"] = kind if kind != "" else null
		var old: Dictionary = _tpl.get("passive", {})
		var pst := _pstats.get_values()
		if pst.is_empty() and _pname.text == "" and (old.get("procs", []) as Array).is_empty():
			f["passive"] = null
		else:
			f["passive"] = {"name": _pname.text, "stat": pst, "procs": old.get("procs", []), "eden": old.get("eden", "")}
		return f

	func _save_template() -> void:
		var f := _template_fields()
		var old_set := String(_tpl.get("set", ""))
		DevEdits.edit_item(int(_tpl.id), f)
		# le set garde la liste de ses pièces à jour
		var new_set := String(_tpl.get("set", ""))
		if old_set != new_set:
			if old_set != "" and GameData.eden_sets.has(old_set):
				var d: Dictionary = GameData.eden_sets[old_set].duplicate(true)
				d.pieces = (d.pieces as Array).filter(func(p): return int(p) != int(_tpl.id))
				DevEdits.edit_set(old_set, d)
			if new_set != "" and GameData.eden_sets.has(new_set):
				var d2: Dictionary = GameData.eden_sets[new_set].duplicate(true)
				if not int(_tpl.id) in (d2.pieces as Array).map(func(p): return int(p)):
					d2.pieces.append(int(_tpl.id))
				DevEdits.edit_set(new_set, d2)
		_msg.text = DevEdits.save()
		_refresh_names()

	func _refresh_names() -> void:
		var i := _entries.find(_item if not _item.is_empty() else _tpl)
		if i >= 0 and i < _list.item_count:
			var x: Dictionary = _entries[i]
			_list.set_item_text(i, Items.display_name(x) if _mode.selected == 0 else "%s · niv. %d%s" % [x.name, int(x.level), "  ✎" if DevEdits.is_edited(int(x.id)) else ""])

	func _update_preview() -> void:
		if not _item.is_empty():
			_preview.text = Items.describe(_apply_owned(_item.duplicate(true)))
		elif not _tpl.is_empty():
			# aperçu : le modèle avec les champs du formulaire, à la puissance 20
			var e := _tpl.duplicate(true)
			var f := _template_fields()
			for k in f:
				if f[k] == null:
					e.erase(k)
				else:
					e[k] = f[k]
			e["dev"] = true
			seed(int(e.id))
			var it := Items.from_template(e, 20, int(e.rarity))
			randomize()
			_preview.text = "[color=#9a98a8]Aperçu à la puissance 20 :[/color]\n" + Items.describe(it)


# --- page Sets ----------------------------------------------------------------------------------
## Créer et modifier des sets : nom, pièces (n'importe quels objets du catalogue), bonus à
## 2, 3, 4, 5 et 6 pièces (stats et buff sous condition).
class SetsPage extends HBoxContainer:
	const TIERS := [2, 3, 4, 5, 6]
	var _list: ItemList
	var _ids: Array = []
	var _sid := ""
	var _form: VBoxContainer
	var _name: LineEdit
	var _pieces: Array = []  # ids d'Eden
	var _pieces_box: VBoxContainer
	var _search: LineEdit
	var _results: ItemList
	var _found: Array = []
	var _tiers := {}  # n -> {on: CheckBox, stats: StatEditor, kind: OptionButton}
	var _preview: RichTextLabel
	var _msg: Label

	func _ready() -> void:
		add_theme_constant_override("separation", 14)
		var left := ItemWidgets.panel(self, 340)
		ItemWidgets.section(left, "Sets")
		DevPages.button(left, "+ Nouveau set", _new_set)
		_list = ItemList.new()
		_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_list.item_selected.connect(func(i): _open(String(_ids[i])))
		left.add_child(_list)
		var mid := ItemWidgets.panel(self, 0, true)
		var sc := ScrollContainer.new()
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		mid.add_child(sc)
		_form = VBoxContainer.new()
		_form.add_theme_constant_override("separation", 8)
		_form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(_form)
		_msg = Hud._label(mid, "", 14, UiTheme.BUFF)
		var right := ItemWidgets.panel(self, 380)
		ItemWidgets.section(right, "Aperçu")
		_preview = ItemWidgets.rich(right, 14)

	func refresh() -> void:
		if not is_inside_tree():
			return
		_list.clear()
		_ids = GameData.eden_sets.keys()
		_ids.sort_custom(func(a, b): return [not String(a).begins_with("u"), String(GameData.eden_sets[a].get("name", ""))] < [not String(b).begins_with("u"), String(GameData.eden_sets[b].get("name", ""))])
		for sid in _ids:
			var d: Dictionary = GameData.eden_sets[sid]
			_list.add_item("%s%s (%d)" % ["★ " if String(sid).begins_with("u") else "", d.get("name", sid), (d.get("pieces", []) as Array).size()])
		if _sid == "":
			for c in _form.get_children():
				c.queue_free()
			Hud._label(_form, "Choisis un set, ou crée-en un nouveau. ★ : sets créés en jeu (leurs pièces comptent à toute rareté).", 15, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	func _new_set() -> void:
		var sid := DevEdits.new_set_id()
		DevEdits.edit_set(sid, {"name": "Nouveau set", "pieces": [], "bonus": {}})
		_msg.text = DevEdits.save()
		_sid = ""
		refresh()
		_open(sid)

	func _open(sid: String) -> void:
		_sid = sid
		var d: Dictionary = GameData.eden_sets.get(sid, {})
		for c in _form.get_children():
			c.free()
		ItemWidgets.section(_form, "Set %s" % sid, 18)
		_name = LineEdit.new()
		_name.text = String(d.get("name", ""))
		_name.text_changed.connect(func(_t): _update_preview())
		DevEditor.row(_form, "Nom", _name, 120)
		ItemWidgets.section(_form, "Pièces", 16)
		_pieces = (d.get("pieces", []) as Array).map(func(p): return int(p))
		_pieces_box = VBoxContainer.new()
		_form.add_child(_pieces_box)
		_search = LineEdit.new()
		_search.placeholder_text = "Ajouter une pièce : tape un nom d'objet…"
		_search.text_changed.connect(_search_items)
		_form.add_child(_search)
		_results = ItemList.new()
		_results.custom_minimum_size = Vector2(0, 140)
		_results.fixed_icon_size = Vector2i(28, 28)
		_results.item_activated.connect(func(i): _add_piece(int(_found[i].id)))
		_results.item_selected.connect(func(i): _add_piece(int(_found[i].id)))
		_form.add_child(_results)
		ItemWidgets.section(_form, "Bonus selon le nombre de pièces portées", 16)
		var bonus: Dictionary = d.get("bonus", {})
		_tiers = {}
		for n in TIERS:
			var b: Dictionary = bonus.get(str(n), bonus.get(n, {}))
			var box := VBoxContainer.new()
			box.add_theme_constant_override("separation", 4)
			_form.add_child(box)
			var on := CheckBox.new()
			on.text = "%d pièces" % n
			on.button_pressed = not b.is_empty()
			on.focus_mode = Control.FOCUS_NONE
			box.add_child(on)
			var st := StatEditor.new(false)
			st.set_values(b.get("stat", {}))
			box.add_child(st)
			var kind := ""
			for p in b.get("procs", []):
				kind = String(p.get("kind", ""))
			var ko := DevEditor.kind_option(kind)
			box.add_child(ko)
			for w in [st, ko]:
				w.visible = on.button_pressed
			on.toggled.connect(func(v):
				st.visible = v
				ko.visible = v
				_update_preview())
			st.changed.connect(_update_preview)
			ko.item_selected.connect(func(_i): _update_preview())
			_tiers[n] = {"on": on, "stats": st, "kind": ko}
		var acts := HBoxContainer.new()
		acts.add_theme_constant_override("separation", 8)
		_form.add_child(acts)
		DevPages.button(acts, "Enregistrer le set", _save, 200)
		DevPages.button(acts, "Supprimer le set", func():
			DevPages.confirm(self, "Supprimer le set « %s » ? Ses pièces n'en feront plus partie." % _name.text, func():
				DevEdits.delete_set(_sid)
				_msg.text = DevEdits.save()
				_sid = ""
				refresh()), 180)
		_refresh_pieces()
		_update_preview()

	func _search_items(q: String) -> void:
		_results.clear()
		q = q.strip_edges().to_lower()
		_found = [] if q.length() < 2 else GameData.eden_items.filter(func(e): return String(e.name).to_lower().contains(q) and not int(e.id) in _pieces).slice(0, 60)
		for e in _found:
			var i := _results.add_item("%s · %s · niv. %d" % [e.name, Items.SLOT_NAMES.get(e.slot, e.slot), int(e.level)], UiTheme.texture(String(e.get("icon", ""))))
			_results.set_item_custom_fg_color(i, Items.RARITIES[clampi(int(e.rarity), 0, 5)].color)

	func _add_piece(id: int) -> void:
		if not id in _pieces:
			_pieces.append(id)
		_search_items(_search.text)
		_refresh_pieces()
		_update_preview()

	func _refresh_pieces() -> void:
		for c in _pieces_box.get_children():
			c.queue_free()
		for id in _pieces:
			var e: Dictionary = GameData.eden_by_id.get(int(id), {})
			var h := HBoxContainer.new()
			h.add_theme_constant_override("separation", 8)
			_pieces_box.add_child(h)
			var ic := TextureRect.new()
			ic.texture = UiTheme.texture(String(e.get("icon", "")))
			ic.custom_minimum_size = Vector2(28, 28)
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			h.add_child(ic)
			var l := Hud._label(h, "%s · %s" % [e.get("name", id), Items.SLOT_NAMES.get(e.get("slot", ""), "")], 14, Items.RARITIES[clampi(int(e.get("rarity", 0)), 0, 5)].color)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var pid: int = int(id)
			DevPages.button(h, "✕", func():
				_pieces.erase(pid)
				_refresh_pieces()
				_update_preview(), 40)
		if _pieces.is_empty():
			Hud._label(_pieces_box, "Aucune pièce : cherche des objets ci-dessous.", 13, UiTheme.MUTED)

	func _def() -> Dictionary:
		var bonus := {}
		for n in TIERS:
			var t: Dictionary = _tiers[n]
			if not t.on.button_pressed:
				continue
			var b := {"stat": t.stats.get_values()}
			var kind := DevEditor.option_value(t.kind)
			if kind != "":
				var p := Trophies.proc_for(kind, Items.LEGENDARY)
				p["kind"] = kind
				b["procs"] = [p]
			bonus[str(n)] = b
		return {"name": _name.text, "pieces": _pieces.duplicate(), "bonus": bonus}

	func _save() -> void:
		DevEdits.edit_set(_sid, _def())
		_msg.text = DevEdits.save()
		var keep := _sid
		_sid = ""
		refresh()
		_sid = keep

	func _update_preview() -> void:
		var d := _def()
		var lines: PackedStringArray = ["[b]%s[/b]  ·  %d pièce(s)\n" % [d.name, d.pieces.size()]]
		for id in d.pieces:
			lines.append("• %s" % GameData.eden_by_id.get(int(id), {}).get("name", id))
		lines.append("")
		for n in d.bonus:
			lines.append("[color=#ffd76a]%s pièces :[/color] %s" % [n, ", ".join(Items.bonus_lines(d.bonus[n]))])
		if d.bonus.is_empty():
			lines.append("[color=#9a98a8]Aucun bonus : coche un palier.[/color]")
		_preview.text = "\n".join(lines)
