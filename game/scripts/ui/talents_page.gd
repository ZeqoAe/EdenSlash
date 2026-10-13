class_name TalentsPage
extends VBoxContainer
## Page Expertise & talents (onglet « Class » d'Eden) :
## - parcours de maîtrise : ce que rapporte chaque niveau d'expertise de la classe
##   (points de talent, sorts, certificats...) ;
## - à gauche, l'arbre de talents (détail au survol, clic : +1 point) ;
## - à droite, le plateau des certificats de maîtrise (CertBoard, 7 emplacements en
##   1-2-1-2-1) : glisser ou cliquer un certificat pour le poser ; les couleurs
##   reliées, les triangles de 3 couleurs et les losanges donnent des bonus.

const CELL := 64

var cls := ""  # classe affichée ("" : classe choisie)
var class_bar := true  # sélecteur de classe en haut (non dans l'écran Héros : la classe y est déjà)
var _tabs: HBoxContainer
var _level_label: Label
var _bar: ProgressBar
var _points: Label
var _track: HBoxContainer
var _grid: GridContainer
var _board: BoardView
var _synergy: RichTextLabel
var _slots: Label
var _certs: HFlowContainer
var _spells: HBoxContainer  # sorts de la classe (débloqués ou maîtrise requise)
var _summary: RichTextLabel
var open_grimoire: Callable  # grimoire détaillé (stats, combo, passifs, rangs)


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	add_child(_tabs)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	add_child(head)
	_level_label = Label.new()
	UiTheme.title(_level_label, 20)
	head.add_child(_level_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(300, 20)
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
	# parcours de maîtrise
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 1, 10))
	add_child(tp)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 4)
	tp.add_child(tv)
	var th := HBoxContainer.new()
	tv.add_child(th)
	ItemWidgets.section(th, "Parcours de maîtrise", 16)
	var tl0 := Hud._label(th, "   Chaque run fait monter la maîtrise de la classe jouée : points de talent, nouveaux sorts, certificats... (survole un niveau)", 13, UiTheme.MUTED)
	tl0.clip_text = true
	tl0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ts := ScrollContainer.new()
	ts.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ts.custom_minimum_size = Vector2(0, 92)
	tv.add_child(ts)
	_track = HBoxContainer.new()
	_track.add_theme_constant_override("separation", 6)
	ts.add_child(_track)

	# sorts de la classe et résumé (ce que contenait le grimoire)
	var spp := PanelContainer.new()
	spp.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 1, 10))
	add_child(spp)
	var spv := VBoxContainer.new()
	spv.add_theme_constant_override("separation", 4)
	spp.add_child(spv)
	var sph := HBoxContainer.new()
	sph.add_theme_constant_override("separation", 12)
	spv.add_child(sph)
	ItemWidgets.section(sph, "Sorts de la classe", 16)
	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.scroll_active = false
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.add_theme_font_size_override("normal_font_size", 13)
	sph.add_child(_summary)
	var gb := Button.new()
	gb.text = "Grimoire détaillé"
	gb.tooltip_text = "Statistiques de base, combo de l'arme, passifs et rangs de chaque sort"
	gb.focus_mode = Control.FOCUS_NONE
	gb.pressed.connect(func():
		if open_grimoire.is_valid():
			open_grimoire.call(_cls()))
	sph.add_child(gb)
	var sps := ScrollContainer.new()
	sps.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sps.custom_minimum_size = Vector2(0, 74)
	spv.add_child(sps)
	_spells = HBoxContainer.new()
	_spells.add_theme_constant_override("separation", 6)
	sps.add_child(_spells)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	add_child(body)
	# talents
	var tree_panel := PanelContainer.new()
	tree_panel.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 2, 10))
	body.add_child(tree_panel)
	var tl := VBoxContainer.new()
	tl.add_theme_constant_override("separation", 6)
	tree_panel.add_child(tl)
	ItemWidgets.section(tl, "Talents de classe")
	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	tl.add_child(_grid)
	Hud._label(tl, "Clic : +1 point · survol : détail. Paliers : 15, 20, 25, 30 puis 35 points dépensés pour les colonnes de droite.", 12, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# certificats
	var cp := ItemWidgets.panel(body, 0, true)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 12)
	cp.add_child(ch)
	ItemWidgets.section(ch, "Certificats de maîtrise")
	_slots = Hud._label(ch, "", 13, UiTheme.MUTED)
	_slots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 16)
	cp.add_child(bh)
	_board = BoardView.new()
	_board.page = self
	bh.add_child(_board)
	_synergy = ItemWidgets.rich(bh, 14)
	_synergy.custom_minimum_size = Vector2(200, 0)
	var rules := ItemWidgets.rich(cp, 13)
	rules.fit_content = true
	rules.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rules.text = CertBoard.rules_bbcode()
	Hud._label(cp, "Certificats disponibles (clic ou glisser sur le plateau ; clic sur une case du plateau pour retirer)", 13, UiTheme.MUTED)
	var cs := ScrollContainer.new()
	cs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cs.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cp.add_child(cs)
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


func refresh() -> void:
	if not is_inside_tree():
		return
	var c := _cls()
	for b in _tabs.get_children():
		b.queue_free()
	_tabs.visible = class_bar
	if class_bar:
		_tabs.add_child(ClassPicker.button(func(): return _cls(), func(cid): show_class(cid), true))
	var lvl := Profile.expertise_level(c)
	var prog := Profile.expertise_progress(c)
	_level_label.text = "%s — maîtrise niveau %d / %d" % [GameData.class_data(c).get("name_fr", c), lvl, Profile.EXPERTISE_MAX]
	_bar.max_value = prog.y
	_bar.value = prog.x
	_bar.tooltip_text = "%d / %d points d'expertise" % [prog.x, prog.y]
	_points.text = "Points de talent : %d / %d" % [Profile.talent_points(c) - Profile.talent_spent(c), Profile.talent_points(c)]
	_refresh_track(c, lvl)
	_refresh_spells(c)
	for x in _grid.get_children():
		x.queue_free()
	var tree: Dictionary = GameData.talents.get(c, {})
	for row in tree.get("rows", []):
		for cell in row:
			_grid.add_child(_cell(cell, tree))
	_refresh_certs()


# --- sorts de la classe ----------------------------------------------------------------------
func _refresh_spells(c: String) -> void:
	for x in _spells.get_children():
		x.queue_free()
	var cd := GameData.class_data(c)
	var skills: Array = cd.get("skills", [])
	var open := skills.filter(func(s): return Progression.skill_unlocked(c, int(s.id))).size()
	_summary.text = "[color=#c8c8d4]%s · %s · %d / %d sorts débloqués · survol : détail[/color]" % [
		cd.get("weapon_name", ""), "dégâts magiques" if String(cd.get("dmg_type", "phys")) in ["mag", "magic"] else "dégâts physiques", open, skills.size()]
	for s in skills:
		var ok := Progression.skill_unlocked(c, int(s.id))
		var b := ItemWidgets.TipButton.new()
		b.custom_minimum_size = Vector2(60, 60)
		b.focus_mode = Control.FOCUS_NONE
		b.icon = UiTheme.texture(String(s.get("icon", "")))
		b.expand_icon = true
		b.add_theme_stylebox_override("normal", UiTheme.flat_box(Color(0.08, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM if ok else Color(0.25, 0.23, 0.3), 2, 8))
		if not ok:
			b.modulate = Color(0.45, 0.45, 0.5)
			b.text = str(Progression.skill_level_of(c, int(s.id)))
		var tip := SpellInfo.skill_bbcode(s, 1)
		if s.get("shared", false):
			tip = "[color=#9fd0ff]Sort partagé (classe d'origine)[/color]\n" + tip
		if not ok:
			tip += "\n\n[color=#ffcf6b]🔒 Débloqué à la maîtrise %d[/color]" % Progression.skill_level_of(c, int(s.id))
		b.tip = "[img=48x48]%s[/img]  [b]%s[/b]\n%s" % [String(s.get("icon", "")), s.get("name", ""), tip]
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
	lines.append("[color=#8a86a0]Eden Eternal : %s[/color]" % t.get("eden", ""))
	lines.append("[color=#ff9a7a]%s[/color]" % block if block != "" else "[color=#ffcf6b]Clic : +1 point[/color]")
	return "\n".join(lines)


# --- certificats -----------------------------------------------------------------------------
## Passif d'Eden d'un certificat "classe/id".
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
	if not unlocked:
		lines.append("[color=#ff9a7a]🔒 Maîtrise %s niveau %d[/color]" % [GameData.class_data(parts[0]).get("name_fr", parts[0]), cert_level])
	return "\n".join(lines)


func _refresh_certs() -> void:
	var slots := Profile.certificate_slots()
	_slots.text = "%d / %d posés · %d emplacements sur 7" % [Profile.certificates.size(), slots, slots]
	_slots.tooltip_text = "+1 emplacement tous les 8 niveaux de maîtrise cumulés"
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
