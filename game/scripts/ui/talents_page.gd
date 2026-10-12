class_name TalentsPage
extends VBoxContainer
## Page Expertise & talents (comme l'onglet « Class » d'Eden) : arbre de talents propre à
## la classe (points gagnés en montant l'expertise run après run) et certificats de
## maîtrise, passifs des classes maîtrisées à équiper avant la run (7 au maximum,
## utilisables par toutes les classes). S'affiche dans un PageScreen.

const CELL := 66

var cls := ""  # classe affichée ("" : classe choisie)
var _tabs: HBoxContainer
var _level_label: Label
var _bar: ProgressBar
var _points: Label
var _grid: GridContainer
var _detail: RichTextLabel
var _add: Button
var _equipped: HBoxContainer
var _certs: HFlowContainer
var _slots: Label
var _selected := 0


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	add_child(_tabs)
	# niveau d'expertise et points
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	add_child(head)
	_level_label = Label.new()
	UiTheme.title(_level_label, 20)
	head.add_child(_level_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(320, 22)
	_bar.show_percentage = false
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_bar)
	_points = Hud._label(head, "", 16, UiTheme.GOLD)
	var reset := Button.new()
	reset.text = "Réinitialiser les talents"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(func():
		Profile.reset_talents(_cls())
		refresh())
	head.add_child(reset)
	Hud._label(self, "L'expertise monte à chaque run jouée avec la classe (niveau atteint, monstres, élites, victoire). Chaque niveau donne 2 points de talent ; les niveaux 3 et 8 débloquent les certificats de la classe.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	add_child(body)
	var tree_panel := PanelContainer.new()
	tree_panel.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 2, 10))
	body.add_child(tree_panel)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	tree_panel.add_child(tv)
	ItemWidgets.section(tv, "Talents de classe")
	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 14)
	tv.add_child(_grid)
	Hud._label(tv, "Paliers : il faut dépenser 15, 20, 25, 30 puis 35 points dans l'arbre pour accéder aux colonnes de droite.", 12, UiTheme.MUTED)
	var right := ItemWidgets.panel(body, 0, true)
	_detail = ItemWidgets.rich(right, 15)
	_add = ItemWidgets.action_button(right, "", func():
		if Profile.add_talent(_cls(), _selected):
			refresh(), 0, true)

	# certificats : 7 emplacements, puis tous les certificats
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 2, 10))
	add_child(cp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cp.add_child(cv)
	var cert_head := HBoxContainer.new()
	cert_head.add_theme_constant_override("separation", 14)
	cv.add_child(cert_head)
	ItemWidgets.section(cert_head, "Certificats de maîtrise")
	_equipped = HBoxContainer.new()
	_equipped.add_theme_constant_override("separation", 6)
	cert_head.add_child(_equipped)
	_slots = Hud._label(cert_head, "", 14, UiTheme.MUTED)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_slots.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_certs = HFlowContainer.new()
	_certs.add_theme_constant_override("h_separation", 8)
	_certs.add_theme_constant_override("v_separation", 8)
	cv.add_child(_certs)


func _cls() -> String:
	return cls if cls != "" else Profile.selected_class


## Affiche la classe [param c] ("" : classe choisie).
func show_class(c := "") -> void:
	cls = c
	_selected = 0
	refresh()


func refresh() -> void:
	if not is_inside_tree():
		return
	var c := _cls()
	for b in _tabs.get_children():
		b.queue_free()
	for id in GameData.classes:
		var cd: Dictionary = GameData.classes[id]
		var b := Button.new()
		b.text = "%s  %d" % [cd.get("name_fr", id), Profile.expertise_level(id)]
		b.icon = UiTheme.texture(String(cd.get("icon", "")))
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 26)
		b.custom_minimum_size = Vector2(150, 40)
		b.toggle_mode = true
		b.button_pressed = id == c
		b.focus_mode = Control.FOCUS_NONE
		var cid: String = id
		b.pressed.connect(func():
			show_class(cid))
		_tabs.add_child(b)
	var lvl := Profile.expertise_level(c)
	var prog := Profile.expertise_progress(c)
	_level_label.text = "%s — expertise niveau %d / %d" % [GameData.class_data(c).get("name_fr", c), lvl, Profile.EXPERTISE_MAX]
	_bar.max_value = prog.y
	_bar.value = prog.x
	_bar.tooltip_text = "%d / %d points d'expertise" % [prog.x, prog.y]
	_points.text = "Points de talent : %d / %d" % [Profile.talent_points(c) - Profile.talent_spent(c), Profile.talent_points(c)]
	# arbre
	for x in _grid.get_children():
		x.queue_free()
	var tree: Dictionary = GameData.talents.get(c, {})
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
	var c := _cls()
	var t: Dictionary = tree.talents.get(str(int(cell.id)), {})
	var rank := Profile.talent_rank(c, cell.id)
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
	var open := Profile.talent_block(c, cell.id) == "" or rank > 0
	var sb := UiTheme.flat_box(Color(0.12, 0.1, 0.2, 0.95), UiTheme.GOLD if int(cell.id) == _selected else (UiTheme.GOLD_DIM if rank > 0 else Color(0.3, 0.28, 0.38)), 3 if int(cell.id) == _selected else 2, 6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	if not open:
		b.modulate = Color(0.45, 0.45, 0.5)
	var id := int(cell.id)
	b.pressed.connect(func():
		_selected = id
		refresh())
	b.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.double_click and ev.button_index == MOUSE_BUTTON_LEFT:
			if Profile.add_talent(c, id):
				refresh())
	v.add_child(b)
	var l := Hud._label(v, "%d / %d" % [rank, int(cell.max)], 13, UiTheme.GOLD if rank > 0 else UiTheme.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return v


func _refresh_detail() -> void:
	var c := _cls()
	var tree: Dictionary = GameData.talents.get(c, {})
	var t: Dictionary = tree.get("talents", {}).get(str(_selected), {})
	if t.is_empty():
		_detail.text = ""
		_add.disabled = true
		_add.text = "—"
		return
	var rank := Profile.talent_rank(c, _selected)
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
	var block := Profile.talent_block(c, _selected)
	if block != "":
		lines.append("")
		lines.append("[color=#ff9a7a]Impossible d'ajouter un point : %s[/color]" % block)
	_detail.text = "\n".join(lines)
	_add.disabled = block != ""
	_add.text = "+1 point (ou double-clic sur l'icône)" if block == "" else "Indisponible"


## Passif d'Eden d'un certificat "classe/id".
static func cert_passive(key: String) -> Dictionary:
	var p := key.split("/")
	if p.size() < 2:
		return {}
	for pp in GameData.class_data(p[0]).get("passives", []):
		if String(pp.id) == p[1]:
			return pp
	return {}


func _refresh_certs() -> void:
	for x in _certs.get_children():
		x.queue_free()
	for x in _equipped.get_children():
		x.queue_free()
	var unlocked := Profile.unlocked_certificates().map(func(x): return x.key)
	var slots := Profile.certificate_slots()
	_slots.text = "%d / %d équipés · %d emplacement(s) ouvert(s) sur %d : +1 tous les 8 niveaux d'expertise cumulés. Clique un certificat pour l'équiper ou le retirer." % [
		Profile.certificates.size(), slots, slots, Profile.CERT_MAX]
	# les 7 emplacements
	for i in Profile.CERT_MAX:
		var box := Panel.new()
		box.custom_minimum_size = Vector2(46, 46)
		var on := i < Profile.certificates.size()
		box.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.1, 0.08, 0.16, 0.95) if i < slots else Color(0.04, 0.04, 0.06, 0.9),
			UiTheme.GOLD if on else (UiTheme.GOLD_DIM if i < slots else Color(0.25, 0.23, 0.3)), 2, 6))
		if on:
			var key := String(Profile.certificates[i])
			var p := cert_passive(key)
			var ic := TextureRect.new()
			ic.texture = UiTheme.texture(String(p.get("icon", "")))
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.set_anchors_preset(Control.PRESET_FULL_RECT)
			ic.offset_left = 4
			ic.offset_top = 4
			ic.offset_right = -4
			ic.offset_bottom = -4
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(ic)
			box.tooltip_text = "%s\n%s\n(clic : retirer)" % [p.get("name", "?"), p.get("desc", "")]
			box.gui_input.connect(func(ev):
				if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
					Profile.toggle_certificate(key)
					_refresh_certs())
		elif i >= slots:
			box.tooltip_text = "Emplacement verrouillé : monte l'expertise de tes classes."
			var lock := Hud._label(box, "🔒", 16, UiTheme.MUTED)
			lock.set_anchors_preset(Control.PRESET_CENTER)
		_equipped.add_child(box)
	for c in GameData.talents:
		var cd := GameData.class_data(c)
		var certs: Array = GameData.talents[c].get("certificates", [])
		for i in certs.size():
			var key := "%s/%s" % [c, certs[i]]
			var p := cert_passive(key)
			var ok: bool = key in unlocked
			var on: bool = key in Profile.certificates
			var b := Button.new()
			b.custom_minimum_size = Vector2(212, 74)
			b.icon = UiTheme.texture(String(p.get("icon", "")))
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 40)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			b.text = "%s%s\n%s" % ["✔ " if on else "", p.get("name", "?"), cd.get("name_fr", c) if ok else "🔒 %s niv. %d" % [cd.get("name_fr", c), Profile.CERT_LEVELS[i]]]
			b.tooltip_text = "%s\n%s" % [p.get("name", "?"), p.get("desc", "")]
			b.clip_text = true
			b.add_theme_font_size_override("font_size", 13)
			var sb := UiTheme.flat_box(Color(0.12, 0.1, 0.2, 0.95), UiTheme.GOLD if on else UiTheme.GOLD_DIM, 3 if on else 1, 6)
			b.add_theme_stylebox_override("normal", sb)
			b.disabled = not ok
			if not ok:
				b.modulate = Color(0.55, 0.55, 0.6)
			b.pressed.connect(func():
				Profile.toggle_certificate(key)
				_refresh_certs())
			_certs.add_child(b)
