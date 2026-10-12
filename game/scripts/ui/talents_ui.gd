class_name TalentsUi
extends CanvasLayer
## Expertise de classe (comme l'onglet « Class » d'Eden) : arbre de talents propre à la
## classe (points gagnés en montant l'expertise run après run) et certificats, passifs
## des classes maîtrisées à équiper avant la run (utilisables par toutes les classes).

const CELL := 66

var _root: Control
var _cls := "samurai"
var _tabs: HBoxContainer
var _level_label: Label
var _bar: ProgressBar
var _points: Label
var _grid: GridContainer
var _detail: RichTextLabel
var _add: Button
var _certs: HBoxContainer
var _slots: Label
var _selected := 0


func _ready() -> void:
	layer = 22
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.panel_box(20, 16))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_top = 30
	panel.offset_right = -40
	panel.offset_bottom = -30
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var t := Label.new()
	t.text = "Expertise"
	UiTheme.title(t, 30)
	top.add_child(t)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_tabs)
	var close := Button.new()
	close.text = "✕  Fermer (Échap)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_ui)
	top.add_child(close)

	# niveau d'expertise et points
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	v.add_child(head)
	_level_label = Label.new()
	UiTheme.title(_level_label, 20)
	head.add_child(_level_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(320, 22)
	_bar.show_percentage = false
	head.add_child(_bar)
	_points = Hud._label(head, "", 16, UiTheme.GOLD)
	var reset := Button.new()
	reset.text = "Réinitialiser les talents"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func():
		Profile.reset_talents(_cls)
		_refresh())
	head.add_child(reset)
	Hud._label(v, "L'expertise monte à chaque run jouée avec la classe (niveau atteint, monstres, élites, victoire). Chaque niveau donne 2 points de talent ; les niveaux 3 et 8 débloquent les certificats de la classe.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	v.add_child(body)
	var tree_panel := PanelContainer.new()
	tree_panel.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 2, 10))
	body.add_child(tree_panel)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	tree_panel.add_child(tv)
	var tt := Label.new()
	tt.text = "Talents de classe"
	UiTheme.title(tt, 18)
	tv.add_child(tt)
	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 14)
	tv.add_child(_grid)
	Hud._label(tv, "Paliers : il faut dépenser 15, 20, 25, 30 puis 35 points dans l'arbre pour accéder aux colonnes de droite.", 12, UiTheme.MUTED)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("normal_font_size", 15)
	right.add_child(_detail)
	_add = Button.new()
	_add.custom_minimum_size = Vector2(0, 46)
	_add.focus_mode = Control.FOCUS_NONE
	_add.pressed.connect(func():
		if Profile.add_talent(_cls, _selected):
			_refresh())
	right.add_child(_add)

	# certificats
	var cert_head := HBoxContainer.new()
	v.add_child(cert_head)
	var ct := Label.new()
	ct.text = "Certificats"
	UiTheme.title(ct, 18)
	cert_head.add_child(ct)
	_slots = Hud._label(cert_head, "", 15, UiTheme.MUTED)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var cs := ScrollContainer.new()
	cs.custom_minimum_size = Vector2(0, 96)
	cs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(cs)
	_certs = HBoxContainer.new()
	_certs.add_theme_constant_override("separation", 8)
	cs.add_child(_certs)
	_root.visible = false


func open(cls := "") -> void:
	_cls = cls if cls != "" else Profile.selected_class
	_selected = 0
	_root.visible = true
	_refresh()


func close_ui() -> void:
	_root.visible = false


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and event.is_action_pressed("pause"):
		close_ui()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for id in GameData.classes:
		var cd: Dictionary = GameData.classes[id]
		var b := Button.new()
		b.text = "%s  %d" % [cd.get("name_fr", id), Profile.expertise_level(id)]
		b.icon = UiTheme.texture(String(cd.get("icon", "")))
		b.expand_icon = true
		b.custom_minimum_size = Vector2(150, 40)
		b.toggle_mode = true
		b.button_pressed = id == _cls
		b.focus_mode = Control.FOCUS_NONE
		var cid: String = id
		b.pressed.connect(func():
			_cls = cid
			_selected = 0
			_refresh())
		_tabs.add_child(b)
	var lvl := Profile.expertise_level(_cls)
	var prog := Profile.expertise_progress(_cls)
	_level_label.text = "%s — expertise niveau %d / %d" % [GameData.class_data(_cls).get("name_fr", _cls), lvl, Profile.EXPERTISE_MAX]
	_bar.max_value = prog.y
	_bar.value = prog.x
	_bar.tooltip_text = "%d / %d points d'expertise" % [prog.x, prog.y]
	_points.text = "Points de talent : %d / %d" % [Profile.talent_points(_cls) - Profile.talent_spent(_cls), Profile.talent_points(_cls)]
	# arbre
	for c in _grid.get_children():
		c.queue_free()
	var tree: Dictionary = GameData.talents.get(_cls, {})
	for row in tree.get("rows", []):
		for cell in row:
			_grid.add_child(_cell(cell, tree))
	if _selected == 0:
		for row in tree.get("rows", []):
			for cell in row:
				if cell != null and _selected == 0:
					_selected = int(cell.id)
	_refresh_detail()
	_refresh_certs()


func _cell(cell, tree: Dictionary) -> Control:
	if cell == null:
		var e := Control.new()
		e.custom_minimum_size = Vector2(CELL, CELL + 18)
		return e
	var t: Dictionary = tree.talents.get(str(int(cell.id)), {})
	var rank := Profile.talent_rank(_cls, cell.id)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var b := Button.new()
	b.custom_minimum_size = Vector2(CELL, CELL)
	b.focus_mode = Control.FOCUS_NONE
	# icône d'Eden posée dans la case (marges du cadre)
	var ic := TextureRect.new()
	ic.texture = UiTheme.texture(String(t.get("icon", "")))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = 6
	ic.offset_top = 6
	ic.offset_right = -6
	ic.offset_bottom = -6
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.tooltip_text = "%s\n%s" % [t.get("name", ""), t.get("desc", "")]
	var open := Profile.talent_block(_cls, cell.id) == "" or rank > 0
	var sb := UiTheme.flat_box(Color(0.12, 0.1, 0.2, 0.95), UiTheme.GOLD if int(cell.id) == _selected else (UiTheme.GOLD_DIM if rank > 0 else Color(0.3, 0.28, 0.38)), 3 if int(cell.id) == _selected else 2, 6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	if not open:
		b.modulate = Color(0.45, 0.45, 0.5)
	var id := int(cell.id)
	b.pressed.connect(func():
		_selected = id
		_refresh())
	b.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
			if Profile.add_talent(_cls, id):
				_refresh())
	v.add_child(b)
	var l := Hud._label(v, "%d / %d" % [rank, int(cell.max)], 13, UiTheme.GOLD if rank > 0 else UiTheme.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return v


func _refresh_detail() -> void:
	var tree: Dictionary = GameData.talents.get(_cls, {})
	var t: Dictionary = tree.get("talents", {}).get(str(_selected), {})
	if t.is_empty():
		_detail.text = ""
		_add.disabled = true
		return
	var rank := Profile.talent_rank(_cls, _selected)
	var eff: Dictionary = t.effect
	var lines: PackedStringArray = []
	var icon := String(t.get("icon", ""))
	lines.append(("[img=56x56]%s[/img]  " % icon if icon != "" else "") + "[font_size=22][b]%s[/b][/font_size]" % t.name)
	lines.append("[color=#b8b4c8]Niveau %d / %d[/color]" % [rank, int(t.max)])
	lines.append("")
	lines.append("[b]%s[/b]" % t.desc)
	if rank > 0 and eff.get("type", "") in ["stat", "skill_dmg", "skill_cd"]:
		var total := float(eff.per_level) * rank
		lines.append("[color=#7fe08a]Actuellement : %s%d %%[/color]" % ["-" if eff.type == "skill_cd" else "+", roundi(total * 100)])
	elif rank > 0 and eff.get("type", "") == "skill_duration":
		lines.append("[color=#7fe08a]Actuellement : +%d s[/color]" % roundi(float(eff.per_level) * rank))
	lines.append("")
	lines.append("[color=#b8b4c8]Eden Eternal : %s[/color]" % t.get("eden", ""))
	var block := Profile.talent_block(_cls, _selected)
	if block != "":
		lines.append("")
		lines.append("[color=#ff9a7a]Impossible d'ajouter un point : %s[/color]" % block)
	_detail.text = "\n".join(lines)
	_add.disabled = block != ""
	_add.text = "+1 point (double-clic sur l'icône)" if block == "" else "Indisponible"


func _refresh_certs() -> void:
	for c in _certs.get_children():
		c.queue_free()
	var unlocked := Profile.unlocked_certificates().map(func(x): return x.key)
	_slots.text = "Équipés : %d / %d emplacements (1 de plus tous les 10 niveaux d'expertise cumulés)" % [Profile.certificates.size(), Profile.certificate_slots()]
	for cls in GameData.talents:
		var cd := GameData.class_data(cls)
		var certs: Array = GameData.talents[cls].get("certificates", [])
		for i in certs.size():
			var p: Dictionary = {}
			for pp in cd.get("passives", []):
				if pp.id == certs[i]:
					p = pp
			var key := "%s/%s" % [cls, certs[i]]
			var ok: bool = key in unlocked
			var on: bool = key in Profile.certificates
			var b := Button.new()
			b.custom_minimum_size = Vector2(200, 84)
			b.icon = UiTheme.texture(String(p.get("icon", "")))
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 40)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			b.text = "%s%s\n%s\n%s" % ["✔ " if on else "", p.get("name", "?"), cd.get("name_fr", cls),
				p.get("desc", "") if ok else "🔒 expertise %s niv. %d" % [cd.get("name_fr", cls), Profile.CERT_LEVELS[i]]]
			b.clip_text = true
			b.add_theme_font_size_override("font_size", 12)
			var sb := UiTheme.flat_box(Color(0.12, 0.1, 0.2, 0.95), UiTheme.GOLD if on else UiTheme.GOLD_DIM, 3 if on else 1, 6)
			b.add_theme_stylebox_override("normal", sb)
			b.disabled = not ok
			if not ok:
				b.modulate = Color(0.55, 0.55, 0.6)
			b.pressed.connect(func():
				Profile.toggle_certificate(key)
				_refresh_certs())
			_certs.add_child(b)
