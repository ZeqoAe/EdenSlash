class_name TalentsPage
extends VBoxContainer
## Page Classe : la maîtrise de la classe affichée, en trois sous-onglets.
## - en haut, toujours visibles : le niveau de maîtrise et le parcours (ce que rapporte chaque niveau) ;
## - Sorts : les sorts de la classe (un clic ouvre le Grimoire sur ce sort) ;
## - Talents : l'arbre de talents (détail au survol, clic : +1 point) ;
## - Certificats : le plateau de 7 emplacements (CertBoard) : glisser ou cliquer un certificat pour
##   le poser ; les couleurs reliées, les triangles de 3 couleurs et les losanges donnent des bonus.

const CELL := 88
const SUBS := [["spells", "Sorts"], ["talents", "Talents"], ["certs", "Certificats"]]

var cls := ""  # classe affichée ("" : classe choisie)
var class_bar := true  # sélecteur de classe en haut (non dans l'écran Héros : la classe y est déjà)
var sub := "spells"  # sous-onglet affiché
var open_grimoire: Callable  # func(classe, id du sort ou 0) : grimoire détaillé
var _tabs: HBoxContainer
var _level_label: Label
var _bar: ProgressBar
var _bar_text: Label
var _lesson: Button  # leçon de maîtrise (classe en retard) : 200 insignes, 3 par jour
var _track: HBoxContainer
var _sub_buttons := {}  # id -> Button
var _sub_pages := {}  # id -> Control
var _points: Label
var _reset: Button
var _grid: GridContainer
var _board: BoardView
var _synergy: RichTextLabel
var _slots: Label
var _certs: HFlowContainer
var _spells: GridContainer  # sorts de la classe (débloqués ou maîtrise requise)
var _summary: Label


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	add_child(_tabs)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	add_child(head)
	_level_label = Label.new()
	UiTheme.title(_level_label, 22)
	head.add_child(_level_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(340, 22)
	_bar.show_percentage = false
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.add_theme_stylebox_override("background", UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.95), UiTheme.GOLD_DIM, 1, 6, false))
	_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(Color(0.62, 0.45, 0.14, 1.0), Color(0, 0, 0, 0), 0, 6, false))
	head.add_child(_bar)
	_bar_text = Hud._label(_bar, "", 13, UiTheme.TEXT)
	_bar_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bar_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lesson_gap := Control.new()
	lesson_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(lesson_gap)
	_lesson = MenuWidgets.glass_button("", 15, Vector2(0, 34))
	_lesson.pressed.connect(_buy_lesson)
	head.add_child(_lesson)
	# parcours de maîtrise
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 1, 10))
	add_child(tp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tp.add_child(tv)
	ItemWidgets.section(tv, "Parcours de maîtrise", 16)
	var ts := ScrollContainer.new()
	ts.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ts.custom_minimum_size = Vector2(0, 92)
	tv.add_child(ts)
	_track = HBoxContainer.new()
	_track.add_theme_constant_override("separation", 6)
	ts.add_child(_track)
	# sous-onglets
	var tb := HBoxContainer.new()
	tb.add_theme_constant_override("separation", 8)
	add_child(tb)
	for t in SUBS:
		var b := Button.new()
		b.text = String(t[1])
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 42)
		b.add_theme_font_size_override("font_size", 16)
		b.add_theme_font_override("font", UiTheme.bold_font())
		b.pressed.connect(show_sub.bind(String(t[0])))
		tb.add_child(b)
		_sub_buttons[t[0]] = b
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb.add_child(sp)
	_points = Hud._label(tb, "", 16, UiTheme.GOLD)
	_points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_points.mouse_filter = Control.MOUSE_FILTER_PASS
	_points.tooltip_text = "Paliers : 15, 20, 25, 30 puis 35 points dépensés ouvrent les colonnes de droite."
	_reset = Button.new()
	_reset.text = "Réinitialiser"
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.pressed.connect(func():
		Profile.reset_talents(_cls())
		refresh())
	tb.add_child(_reset)
	_build_spells_page()
	_build_talents_page()
	_build_certs_page()


## Cadre sombre d'un sous-onglet (rempli par une VBox).
func _sub_panel(id: String) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 2, 10))
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(pc)
	_sub_pages[id] = pc
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	return v


func _build_spells_page() -> void:
	var v := _sub_panel("spells")
	var sph := HBoxContainer.new()
	sph.add_theme_constant_override("separation", 12)
	v.add_child(sph)
	_summary = Hud._label(sph, "", 14, UiTheme.MUTED)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var gb := Button.new()
	gb.text = "Grimoire détaillé"
	gb.tooltip_text = "Statistiques de base, auto-attaque de l'arme, certificats, rangs de chaque sort, préréglages de sorts"
	gb.focus_mode = Control.FOCUS_NONE
	gb.pressed.connect(func():
		if open_grimoire.is_valid():
			open_grimoire.call(_cls(), 0))
	sph.add_child(gb)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_spells = GridContainer.new()
	_spells.columns = 3
	_spells.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spells.add_theme_constant_override("h_separation", 8)
	_spells.add_theme_constant_override("v_separation", 8)
	sc.add_child(_spells)


func _build_talents_page() -> void:
	var v := _sub_panel("talents")
	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cc)
	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 14)
	cc.add_child(_grid)


func _build_certs_page() -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", StyleBoxEmpty.new())  # les deux cadres ci-dessous suffisent
	pc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(pc)
	_sub_pages["certs"] = pc
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	pc.add_child(body)
	# gauche : le plateau, ses bonus, la légende des couleurs
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 2, 10))
	lp.custom_minimum_size = Vector2(500, 0)
	body.add_child(lp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	lp.add_child(lv)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 12)
	lv.add_child(ch)
	ItemWidgets.section(ch, "Plateau")
	_slots = Hud._label(ch, "", 14, UiTheme.MUTED)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_board = BoardView.new()
	_board.page = self
	_board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lv.add_child(_board)
	_synergy = ItemWidgets.rich(lv, 14)
	_synergy.fit_content = true
	_synergy.scroll_active = false
	_synergy.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var rules := ItemWidgets.rich(lv, 13)
	rules.fit_content = true
	rules.scroll_active = false
	rules.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rules.text = CertBoard.rules_bbcode()
	# droite : les certificats disponibles
	var rp := PanelContainer.new()
	rp.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 2, 10))
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rp)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	rp.add_child(rv)
	var rt := ItemWidgets.section(rv, "Disponibles")
	rt.mouse_filter = Control.MOUSE_FILTER_PASS
	rt.tooltip_text = "Clic ou glisser sur le plateau pour poser, clic sur une case du plateau pour retirer. Posés : acquis dès le début de la run (toutes classes confondues). Les autres peuvent tomber en run comme des cartes."
	var cs := ScrollContainer.new()
	cs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(cs)
	_certs = HFlowContainer.new()
	_certs.add_theme_constant_override("h_separation", 8)
	_certs.add_theme_constant_override("v_separation", 8)
	_certs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cs.add_child(_certs)


func _cls() -> String:
	return cls if cls != "" else Profile.selected_class


## Affiche la classe [param c] ("" : classe choisie).
func show_class(c := "") -> void:
	cls = c
	refresh()


## Change de sous-onglet (Sorts, Talents, Certificats).
func show_sub(id: String) -> void:
	sub = id if _sub_pages.has(id) else "spells"
	for k in _sub_pages:
		_sub_pages[k].visible = k == sub
	for k in _sub_buttons:
		var on: bool = k == sub
		var b: Button = _sub_buttons[k]
		b.set_pressed_no_signal(on)
		var box := EquipmentPage.PresetBar._box(on)
		for st in ["normal", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, box)
		b.add_theme_stylebox_override("hover", EquipmentPage.PresetBar._box(true))
		b.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02) if on else Color(0.92, 0.88, 0.8))
		b.add_theme_color_override("font_pressed_color", Color(0.12, 0.08, 0.02))
		b.add_theme_color_override("font_hover_pressed_color", Color(0.12, 0.08, 0.02))
	_points.visible = sub == "talents"
	_reset.visible = sub == "talents"


func refresh() -> void:
	if not is_inside_tree():
		return
	var c := _cls()
	for b in _tabs.get_children():
		_tabs.remove_child(b)
		b.queue_free()
	_tabs.visible = class_bar
	if class_bar:
		_tabs.add_child(ClassPicker.button(func(): return _cls(), func(cid): show_class(cid), true))
	var lvl := Profile.expertise_level(c)
	var prog := Profile.expertise_progress(c)
	_level_label.text = "Maîtrise niveau %d / %d" % [lvl, Profile.EXPERTISE_MAX]
	_bar.max_value = prog.y
	_bar.value = prog.x
	_bar_text.text = "%d / %d" % [prog.x, prog.y] if lvl < Profile.EXPERTISE_MAX else "Niveau maximal"
	_bar.tooltip_text = "Points de maîtrise de la classe : chaque run en rapporte."
	_refresh_lesson(c)
	var free := Profile.talent_points(c) - Profile.talent_spent(c)
	_points.text = "Points de talent : %d / %d" % [free, Profile.talent_points(c)]
	_sub_buttons["talents"].text = "Talents" + ("  (%d)" % free if free > 0 else "")
	_refresh_track(c, lvl)
	_refresh_spells(c)
	for x in _grid.get_children():
		_grid.remove_child(x)
		x.queue_free()
	var tree: Dictionary = GameData.talents.get(c, {})
	for row in tree.get("rows", []):
		for cell in row:
			_grid.add_child(_cell(cell, tree))
	_refresh_certs()
	show_sub(sub)


## Leçon de maîtrise : seulement pour une classe en retard sur la meilleure du compte.
func _refresh_lesson(c: String) -> void:
	_lesson.visible = Economy.lagging(c) and Progression.class_unlocked(c) and not Run.active
	if not _lesson.visible:
		return
	var left := Economy.lessons_left()
	_lesson.text = "Leçon · %s · %d restante%s" % [GearPower.plural(Economy.LESSON_COST, "insigne"), left, "s" if left > 1 else ""]
	_lesson.disabled = not Economy.can_buy_lesson(c)
	if left == 0:
		_lesson.tooltip_text = "Reviens demain."
	elif Profile.insignia < Economy.LESSON_COST:
		_lesson.tooltip_text = "Il te manque %s." % GearPower.plural(Economy.LESSON_COST - Profile.insignia, "insigne")
	else:
		_lesson.tooltip_text = "+%d points de maîtrise pour cette classe. %d leçons par jour." % [Economy.LESSON_MASTERY, Economy.LESSONS_PER_DAY]


func _buy_lesson() -> void:
	if Economy.buy_lesson(_cls()) >= 0:
		Sfx.ui("confirm")
		refresh()


# --- sorts de la classe ----------------------------------------------------------------------
func _refresh_spells(c: String) -> void:
	for x in _spells.get_children():
		_spells.remove_child(x)
		x.queue_free()
	var cd := GameData.class_data(c)
	var skills: Array = cd.get("skills", [])
	var open := skills.filter(func(s): return Progression.skill_unlocked(c, int(s.id))).size()
	_summary.text = "%s · %s · %d / %d sorts" % [
		cd.get("weapon_name", ""), "dégâts magiques" if String(cd.get("dmg_type", "phys")) in ["mag", "magic"] else "dégâts physiques", open, skills.size()]
	for s in skills:
		var ok := Progression.skill_unlocked(c, int(s.id))
		var b := ItemWidgets.TipButton.new()
		b.custom_minimum_size = Vector2(0, 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.icon = UiTheme.texture(String(s.get("icon", "")))
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 42)
		b.add_theme_constant_override("h_separation", 10)
		b.add_theme_font_size_override("font_size", 16)
		b.text = String(s.get("name", ""))
		var sb := UiTheme.flat_box(Color(0.1, 0.08, 0.18, 0.95), UiTheme.GOLD_DIM if ok else Color(0.25, 0.23, 0.3), 1, 8, false)
		sb.content_margin_left = 12
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.22, 0.16, 0.08, 1.0), UiTheme.GOLD, 2, 8, false))
		if not ok:
			b.modulate = Color(0.55, 0.55, 0.6)
			b.text += "   🔒 maîtrise %d" % Progression.skill_level_of(c, int(s.id))
		var tip := SpellInfo.skill_bbcode(s, 1)
		if s.get("shared", false):
			tip = "[color=#9fd0ff]Sort partagé (classe d'origine)[/color]\n" + tip
		if not ok:
			tip += "\n\n[color=#ffcf6b]🔒 Débloqué à la maîtrise %d[/color]" % Progression.skill_level_of(c, int(s.id))
		tip += "\n[color=#ffcf6b]Clic : ouvrir dans le Grimoire[/color]"
		b.tooltip_text = " "
		b.tip = "[img=48x48]%s[/img]  [b]%s[/b]\n%s" % [String(s.get("icon", "")), s.get("name", ""), tip]
		var sid := int(s.id)
		b.pressed.connect(func():
			if open_grimoire.is_valid():
				open_grimoire.call(_cls(), sid))
		_spells.add_child(b)


# --- parcours de maîtrise --------------------------------------------------------------------
func _refresh_track(c: String, lvl: int) -> void:
	for x in _track.get_children():
		x.queue_free()
	var last := mini(maxi(Progression.last_reward_level(c), lvl + 2), Profile.EXPERTISE_MAX)
	for l in range(1, last + 1):
		var rw := Progression.rewards_at(c, l)
		var got := l <= lvl
		var b := ItemWidgets.TipButton.new()
		b.custom_minimum_size = Vector2(78, 84)
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		var border := UiTheme.GOLD if l == lvl else (UiTheme.GOLD_DIM if got else Color(0.3, 0.28, 0.38))
		var sb := UiTheme.flat_box(Color(0.14, 0.11, 0.22, 0.95) if got else Color(0.06, 0.05, 0.1, 0.9), border, 3 if l == lvl else 1, 8)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var t := Hud._label(v, "Niv. %d" % l, 13, UiTheme.GOLD if got else UiTheme.MUTED)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var icons := HBoxContainer.new()
		icons.alignment = BoxContainer.ALIGNMENT_CENTER
		icons.add_theme_constant_override("separation", 2)
		icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(icons)
		var lines: PackedStringArray = ["[b]Maîtrise niveau %d[/b]%s" % [l, "  [color=#7fe08a]✔ obtenu[/color]" if got else ""]]
		var special := 0
		for r in rw:
			lines.append("• [b]%s[/b]%s" % [r.name, ("\n  [color=#b8b4c8]%s[/color]" % String(r.desc).replace("\n", "\n  ")) if r.kind != "talent" else ""])
			if String(r.icon) != "" and special < 2:
				special += 1
				var ic := TextureRect.new()
				ic.texture = UiTheme.texture(String(r.icon))
				ic.custom_minimum_size = Vector2(32, 32)
				ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ic.modulate = Color.WHITE if got else Color(0.5, 0.5, 0.55)
				ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icons.add_child(ic)
		if special == 0:
			var pts := Hud._label(icons, "+2", 18, UiTheme.GOLD if got else UiTheme.MUTED)
			pts.add_theme_font_override("font", UiTheme.bold_font())
		var cap := Hud._label(v, "sort" if rw.any(func(r): return r.kind == "skill") else ("certificat" if rw.any(func(r): return r.kind == "cert") else "talents"), 11, UiTheme.MUTED)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text = " "
		b.tip = "\n".join(lines)
		_track.add_child(b)


# --- talents ----------------------------------------------------------------------------------
func _cell(cell, tree: Dictionary) -> Control:
	if cell == null:
		var e := Control.new()
		e.custom_minimum_size = Vector2(CELL, CELL + 18)
		return e
	var c := _cls()
	var id := int(cell.id)
	var t: Dictionary = tree.talents.get(str(id), {})
	var rank := Profile.talent_rank(c, cell.id)
	var block := Profile.talent_block(c, cell.id)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var b := ItemWidgets.TipButton.new()
	b.custom_minimum_size = Vector2(CELL, CELL)
	b.focus_mode = Control.FOCUS_NONE
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
	var open := block == "" or rank > 0
	var sb := UiTheme.flat_box(Color(0.12, 0.1, 0.2, 0.95), UiTheme.GOLD if rank > 0 else (UiTheme.GOLD_DIM if open else Color(0.3, 0.28, 0.38)), 2, 6)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.18, 0.14, 0.28, 1.0), UiTheme.GOLD, 2, 6))
	if not open:
		b.modulate = Color(0.45, 0.45, 0.5)
	b.tooltip_text = " "
	b.tip = _talent_tip(c, id, t, rank, block)
	b.pressed.connect(func():
		if Profile.add_talent(c, id):
			refresh())
	v.add_child(b)
	var l := Hud._label(v, "%d / %d" % [rank, int(cell.max)], 13, UiTheme.GOLD if rank > 0 else UiTheme.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return v


func _talent_tip(_c: String, _id: int, t: Dictionary, rank: int, block: String) -> String:
	var eff: Dictionary = t.get("effect", {})
	var lines: PackedStringArray = []
	var icon := String(t.get("icon", ""))
	lines.append(("[img=40x40]%s[/img]  " % icon if icon != "" else "") + "[font_size=19][b]%s[/b][/font_size]" % t.get("name", ""))
	lines.append("[color=#b8b4c8]Niveau %d / %d[/color]" % [rank, int(t.get("max", 1))])
	lines.append("[b]%s[/b]" % t.get("desc", ""))
	if rank > 0 and eff.get("type", "") in ["stat", "skill_dmg", "skill_cd"]:
		lines.append("[color=#7fe08a]Actuellement : %s%d %%[/color]" % ["-" if eff.type == "skill_cd" else "+", roundi(float(eff.per_level) * rank * 100)])
	elif rank > 0 and eff.get("type", "") == "skill_duration":
		lines.append("[color=#7fe08a]Actuellement : +%d s[/color]" % roundi(float(eff.per_level) * rank))
	lines.append("[color=#ff9a7a]%s[/color]" % block if block != "" else "[color=#ffcf6b]Clic : +1 point[/color]")
	return "\n".join(lines)


# --- certificats -----------------------------------------------------------------------------
## Passif de classe d'un certificat "classe/id".
static func cert_passive(key: String) -> Dictionary:
	var p := key.split("/")
	if p.size() < 2:
		return {}
	for pp in GameData.class_data(p[0]).get("passives", []):
		if String(pp.id) == p[1]:
			return pp
	return {}


static func cert_tip(key: String, unlocked: bool, cert_level := 0) -> String:
	var p := cert_passive(key)
	var parts := key.split("/")
	var c := CertBoard.color_of(key)
	var lines: PackedStringArray = []
	lines.append(("[img=40x40]%s[/img]  " % p.icon if String(p.get("icon", "")) != "" else "") + "[font_size=19][b]%s[/b][/font_size]" % p.get("name", "?"))
	lines.append("[color=#%s]■ %s[/color] · certificat %s" % [Color(CertBoard.COLORS[c].color).to_html(false), CertBoard.COLORS[c].name,
		GameData.class_data(parts[0]).get("name_fr", parts[0])])
	lines.append("[b]%s[/b]" % p.get("desc", ""))
	lines.append("[color=#c8c8d4]Posé : acquis dès le début de la run.[/color]")
	if not unlocked:
		lines.append("[color=#ff9a7a]🔒 Maîtrise %s niveau %d[/color]" % [GameData.class_data(parts[0]).get("name_fr", parts[0]), cert_level])
	return "\n".join(lines)


func _refresh_certs() -> void:
	var slots := Profile.certificate_slots()
	_slots.text = "%d / %d posés" % [Profile.certificates.size(), slots]
	_slots.tooltip_text = "%d emplacements ouverts sur 7 : +1 tous les 8 niveaux de maîtrise cumulés." % slots
	_slots.mouse_filter = Control.MOUSE_FILTER_PASS
	_board.refresh()
	# bonus de placement
	var syn := CertBoard.synergies(Profile.cert_board)
	var lines: PackedStringArray = ["[b]Bonus de placement[/b]"]
	for s in syn:
		var col := Color(CertBoard.COLORS[s.color].color).to_html(false) if String(s.color) != "" else "e6d7ff"
		lines.append("[color=#%s]%s[/color] : %s" % [col, s.name, CertBoard.stat_text(s.stat)])
	if syn.is_empty():
		lines.append("[color=#8a86a0]Aucun : relie des certificats de même couleur.[/color]")
	_synergy.text = "\n".join(lines)
	for x in _certs.get_children():
		x.queue_free()
	var unlocked := Profile.unlocked_certificates().map(func(x): return x.key)
	# 60 classes : on liste les certificats débloqués et ceux de la classe affichée
	for c in GameData.talents:
		var certs: Array = GameData.talents[c].get("certificates", [])
		for i in certs.size():
			var key := "%s/%s" % [c, certs[i]]
			if not key in unlocked and c != _cls():
				continue
			_certs.add_child(CertChip.new(self, key, key in unlocked, int(Profile.CERT_LEVELS[mini(i, Profile.CERT_LEVELS.size() - 1)])))


func _on_board_changed() -> void:
	_refresh_certs()


## Certificat de la liste (clic : poser / retirer ; glisser sur une case du plateau).
class CertChip extends ItemWidgets.TipButton:
	var page: TalentsPage
	var key := ""
	var ok := false

	func _init(p: TalentsPage, k: String, unlocked: bool, lvl: int) -> void:
		page = p
		key = k
		ok = unlocked
		var cp := TalentsPage.cert_passive(k)
		var on := k in Profile.certificates
		custom_minimum_size = Vector2(66, 66)
		focus_mode = Control.FOCUS_NONE
		var col := CertBoard.color_value(k)
		var sb := UiTheme.flat_box(Color(0.1, 0.08, 0.16, 0.95), col if ok else Color(0.3, 0.28, 0.38), 3 if on else 2, 8)
		for st in ["normal", "hover", "pressed", "disabled"]:
			add_theme_stylebox_override(st, sb)
		var ic := TextureRect.new()
		ic.texture = UiTheme.texture(String(cp.get("icon", "")))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.set_anchors_preset(Control.PRESET_FULL_RECT)
		ic.offset_left = 7
		ic.offset_top = 7
		ic.offset_right = -7
		ic.offset_bottom = -7
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.modulate = Color.WHITE if ok and not on else Color(0.4, 0.4, 0.45)
		add_child(ic)
		if on:
			var m := Hud._label(self, "✔", 18, Color(0.5, 1.0, 0.6))
			m.position = Vector2(44, 2)
		elif not ok:
			var m := Hud._label(self, "🔒", 14, UiTheme.MUTED)
			m.position = Vector2(42, 44)
		tooltip_text = " "
		tip = TalentsPage.cert_tip(k, ok, lvl) + ("\n[color=#ffcf6b]Clic : poser sur le plateau (ou glisser)[/color]" if ok and not on else ("\n[color=#ffcf6b]Clic : retirer[/color]" if on else ""))
		tip_border = col
		pressed.connect(func():
			if ok:
				Profile.toggle_certificate(key)
				page._on_board_changed())

	func _get_drag_data(_at: Vector2) -> Variant:
		if not ok:
			return null
		var prev := TextureRect.new()
		prev.texture = UiTheme.texture(String(TalentsPage.cert_passive(key).get("icon", "")))
		prev.custom_minimum_size = Vector2(52, 52)
		prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		set_drag_preview(prev)
		return {"cert": key}


## Plateau 1-2-1-2-1 : cases, liens colorés entre certificats de même couleur.
class BoardView extends Control:
	const STEP := Vector2(92, 82)
	const SLOT := 70.0
	var page: TalentsPage
	var _slots: Array = []

	func _init() -> void:
		custom_minimum_size = Vector2(STEP.x * 4 + SLOT + 8, STEP.y + SLOT + 8)
		for i in CertBoard.POS.size():
			var s := Slot.new(self, i)
			s.position = _slot_pos(i)
			add_child(s)
			_slots.append(s)

	func _slot_pos(i: int) -> Vector2:
		var p: Vector2 = CertBoard.POS[i]
		return Vector2(4 + p.x * STEP.x, 4 + p.y * STEP.y)

	func refresh() -> void:
		for s in _slots:
			s.refresh()
		queue_redraw()

	func changed() -> void:
		page._on_board_changed()

	func _draw() -> void:
		var b := Profile.cert_board
		var c := func(i: int) -> Vector2:
			return _slot_pos(i) + Vector2(SLOT, SLOT) * 0.5
		# liens : gris si vides, couleur vive si deux certificats de même couleur
		for l in CertBoard.LINKS:
			var a := String(b[l[0]])
			var z := String(b[l[1]])
			var same := a != "" and z != "" and CertBoard.color_of(a) == CertBoard.color_of(z)
			var col: Color = CertBoard.color_value(a) if same else Color(0.35, 0.32, 0.45, 0.5)
			if same:
				draw_line(c.call(l[0]), c.call(l[1]), Color(col, 0.35), 12.0, true)
			draw_line(c.call(l[0]), c.call(l[1]), col, 4.0 if same else 2.0, true)

	## Case du plateau.
	class Slot extends ItemWidgets.TipButton:
		var board: BoardView
		var index := 0
		var _icon: TextureRect
		var _lock: Label

		func _init(b: BoardView, i: int) -> void:
			board = b
			index = i
			custom_minimum_size = Vector2(TalentsPage.BoardView.SLOT, TalentsPage.BoardView.SLOT)
			size = custom_minimum_size
			focus_mode = Control.FOCUS_NONE
			_icon = TextureRect.new()
			_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			_icon.offset_left = 7
			_icon.offset_top = 7
			_icon.offset_right = -7
			_icon.offset_bottom = -7
			_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_icon)
			_lock = Hud._label(self, "🔒", 18, UiTheme.MUTED)
			_lock.set_anchors_preset(Control.PRESET_CENTER)
			_lock.position = Vector2(24, 22)
			pressed.connect(func():
				if String(Profile.cert_board[index]) != "":
					Profile.remove_certificate_at(index)
					board.changed())

		func refresh() -> void:
			var key := String(Profile.cert_board[index])
			var open := Profile.is_cert_open(index)
			var col := CertBoard.color_value(key) if key != "" else (UiTheme.GOLD_DIM if open else Color(0.25, 0.23, 0.3))
			var sb := UiTheme.flat_box(Color(0.1, 0.08, 0.17, 0.97) if open else Color(0.04, 0.04, 0.07, 0.9), col, 3 if key != "" else 2, 35)
			if key != "":
				sb.shadow_color = Color(col, 0.45)
				sb.shadow_size = 8
			for st in ["normal", "hover", "pressed", "disabled"]:
				add_theme_stylebox_override(st, sb)
			_icon.texture = UiTheme.texture(String(TalentsPage.cert_passive(key).get("icon", ""))) if key != "" else null
			_lock.visible = not open
			tooltip_text = " "
			if key != "":
				tip = TalentsPage.cert_tip(key, true) + "\n[color=#ffcf6b]Clic : retirer · glisser : déplacer[/color]"
				tip_border = col
			elif open:
				tip = "[b]Emplacement libre[/b]\nGlisse un certificat ici, ou clique un certificat de la liste."
			else:
				tip = "[b]Emplacement verrouillé[/b]\nIl s'ouvre avec la maîtrise cumulée de tes classes (+1 tous les 8 niveaux)."

		func _get_drag_data(_at: Vector2) -> Variant:
			var key := String(Profile.cert_board[index])
			if key == "":
				return null
			var prev := TextureRect.new()
			prev.texture = _icon.texture
			prev.custom_minimum_size = Vector2(52, 52)
			prev.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			set_drag_preview(prev)
			return {"cert": key}

		func _can_drop_data(_at: Vector2, data: Variant) -> bool:
			return data is Dictionary and data.has("cert") and Profile.is_cert_open(index)

		func _drop_data(_at: Vector2, data: Variant) -> void:
			Profile.place_certificate(String(data.cert), index)
			board.changed()
