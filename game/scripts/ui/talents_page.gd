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
var _undo: Button  # lot GX-5 : annule « Tout reprendre »
var _search: LineEdit  # lot GX-5 : recherche dans l'arbre
var _sealed: Label  # lot GX-5 : mode scellé (Survivant, Battle royale…) : les talents n'y comptent pas
var _tree: TreeView  # lot GX-5 : l'arbre et ses liens de prérequis
var _advise: Button  # lot GX-6 : « Conseillé » (aperçu avant / après, puis annulable)
var _focus: Label  # lot GX-6 : « Pensé pour Rempart : PV max, Dégâts, Défense »
var _load_btns: Array = []  # lot GX-6 : les 3 chargements nommés de la classe
var _load_dialog: LoadDialog
var _cells := {}  # id du talent -> cellule (VBox) de l'arbre
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
	_sealed = Hud._label(head, "Mode à part : talents et certificats n'y comptent pas", 15, UiTheme.MUTED)
	_sealed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sealed.visible = false
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
	# lot GX-5 : recherche dans l'arbre (nom et effet), seulement sur l'onglet Talents
	_search = LineEdit.new()
	_search.placeholder_text = "Chercher un talent"
	_search.clear_button_enabled = true
	_search.custom_minimum_size = Vector2(190, 38)
	_search.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_search.text_changed.connect(func(_t): _apply_search())
	tb.add_child(_search)
	# points libres : toujours visibles, quel que soit le sous-onglet (un clic ouvre l'arbre)
	_points = Hud._label(tb, "", 16, UiTheme.GOLD)
	_points.add_theme_font_override("font", UiTheme.bold_font())
	_points.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_points.mouse_filter = Control.MOUSE_FILTER_STOP
	_points.tooltip_text = "2 points par niveau de maîtrise. Les colonnes de droite s'ouvrent à 15, 20, 25, 30 puis 35 points placés."
	_points.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			show_sub("talents"))
	_reset = Button.new()
	_reset.text = "Tout reprendre"
	_reset.tooltip_text = "Rend tous les points de la classe, gratuitement. « Annuler » remet l'arbre d'avant."
	_reset.focus_mode = Control.FOCUS_NONE
	_reset.pressed.connect(func():
		Profile.reset_talents(_cls())
		Sfx.ui("confirm")
		refresh())
	UiTheme.style_button(_reset, "papier", 15)
	tb.add_child(_reset)
	_undo = Button.new()
	_undo.text = "Annuler"
	_undo.tooltip_text = "Remet les points comme avant (« Tout reprendre », « Conseillé » ou un chargement)."
	_undo.focus_mode = Control.FOCUS_NONE
	_undo.pressed.connect(func():
		if Profile.undo_talent_reset(_cls()):
			Sfx.ui("confirm")
		refresh())
	UiTheme.style_button(_undo, "lagon", 15)
	tb.add_child(_undo)
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
	# lot GX-6 : build conseillé et chargements nommés, au-dessus de l'arbre
	var ar := HBoxContainer.new()
	ar.add_theme_constant_override("separation", 10)
	v.add_child(ar)
	_advise = Button.new()
	_advise.text = "Conseillé"
	_advise.focus_mode = Control.FOCUS_NONE
	_advise.custom_minimum_size = Vector2(0, 36)
	_advise.pressed.connect(_ask_advised)
	UiTheme.style_button(_advise, "lagon", 15)
	ar.add_child(_advise)
	_focus = Hud._label(ar, "", 14, UiTheme.MUTED)
	_focus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_focus.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_focus.clip_text = true
	_focus.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var ll := Hud._label(ar, "Chargements", 14, UiTheme.MUTED)
	ll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for i in Profile.TALENT_LOADS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 36)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.pressed.connect(open_load.bind(i))
		UiTheme.style_button(b, "papier", 14)
		ar.add_child(b)
		_load_btns.append(b)
	var cc := CenterContainer.new()
	cc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cc)
	# lot GX-5 : l'arbre dessine ses liens (prérequis) sous les cases ; la 1re rangée dit le palier de chaque colonne
	_tree = TreeView.new()
	_tree.page = self
	cc.add_child(_tree)
	_grid = GridContainer.new()
	_grid.columns = 8
	_grid.add_theme_constant_override("h_separation", 28)
	_grid.add_theme_constant_override("v_separation", 10)
	_tree.add_child(_grid)
	_grid.sort_children.connect(_tree.queue_redraw)


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
	_points.visible = true  # lot GX-5 : les points libres se lisent depuis les trois sous-onglets
	_reset.visible = sub == "talents"
	_undo.visible = sub == "talents" and Profile.can_undo_talents(_cls())
	_search.visible = sub == "talents"


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
	_points.text = points_text(free, Profile.talent_spent(c))
	_points.add_theme_color_override("font_color", UiTheme.color("texte.sur-papier", UiTheme.TEXT) if free > 0 else UiTheme.color("texte.sur-papier-2", UiTheme.MUTED))
	_sub_buttons["talents"].text = "Talents" + ("  (%d)" % free if free > 0 else "")
	_reset.disabled = Profile.talent_spent(c) == 0
	var narrow := get_viewport().get_visible_rect().size.x < 1500.0  # 1280 × 720 : la rangée des sous-onglets tient dans l'écran
	for sb in _sub_buttons.values():
		(sb as Button).custom_minimum_size.x = 118.0 if narrow else 170.0
	_search.custom_minimum_size.x = 140.0 if narrow else 190.0
	_search.placeholder_text = "Chercher" if narrow else "Chercher un talent"
	_reset.text = "Reprendre" if narrow else "Tout reprendre"
	_points.add_theme_font_size_override("font_size", 14 if narrow else 16)
	_sealed.visible = Profile.in_run and Modes.sealed()
	_refresh_track(c, lvl)
	_refresh_spells(c)
	for x in _grid.get_children():
		_grid.remove_child(x)
		x.queue_free()
	_cells.clear()
	var tree: Dictionary = GameData.talents.get(c, {})
	var rows: Array = tree.get("rows", [])
	var cols := 0
	for row in rows:
		cols = maxi(cols, (row as Array).size())
	_grid.columns = maxi(cols, 1)
	for col in cols:
		_grid.add_child(_tier_head(rows, col))
	for row in rows:
		for cell in row:
			_grid.add_child(_cell(cell, tree))
	_tree.queue_redraw()
	_apply_search()
	_refresh_advice(c, narrow)
	_refresh_certs()
	show_sub(sub)


## « 3 points libres · 14 placés » (ou « Tous tes points sont placés »).
static func points_text(free: int, spent: int) -> String:
	if free <= 0:
		return "Tous tes points sont placés (%d)" % spent if spent > 0 else "Aucun point de talent"
	return "%d point%s libre%s · %d placé%s" % [free, "s" if free > 1 else "", "s" if free > 1 else "", spent, "s" if spent > 1 else ""]


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
			b.text += "\n🔒 maîtrise %d" % Progression.skill_level_of(c, int(s.id))  # condition sur sa ligne : jamais abrégée (UIK2)
		var tip := SpellInfo.skill_bbcode(s, 1)
		if s.get("shared", false):
			tip = "[color=#9fd0ff]Sort partagé (classe d'origine)[/color]\n" + tip
		if not ok:
			tip += "\n\n[color=#ffcf6b]" + Ico.LOCK_BB + " Débloqué à la maîtrise %d[/color]" % Progression.skill_level_of(c, int(s.id))
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
	var cs := _cell_size()
	if cell == null:
		var e := Control.new()
		e.custom_minimum_size = Vector2(cs, cs + 18)
		return e
	var c := _cls()
	var id := int(cell.id)
	var t: Dictionary = tree.talents.get(str(id), {})
	var rank := Profile.talent_rank(c, cell.id)
	var block := Profile.talent_block(c, cell.id)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var b := ItemWidgets.TipButton.new()
	b.custom_minimum_size = Vector2(cs, cs)
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
	var full := rank >= int(cell.max)
	# lot GX-5 : bord soleil = points placés, lagon = un point peut aller ici, gris = fermé
	var border: Color = UiTheme.GOLD if rank > 0 else (UiTheme.color("bonbon.lagon.base", Color("2fc3ff")) if block == "" else (UiTheme.GOLD_DIM if open else Color(0.3, 0.28, 0.38)))
	var sb := UiTheme.flat_box(Color(0.12, 0.1, 0.2, 0.95), border, 3 if (rank > 0 or block == "") else 2, 10)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", UiTheme.flat_box(Color(0.18, 0.14, 0.28, 1.0), UiTheme.GOLD, 3, 10))
	b.add_theme_stylebox_override("pressed", sb)
	if not open:
		b.modulate = Color(0.45, 0.45, 0.5)
	b.tooltip_text = " "
	b.tip = _talent_tip(c, id, t, rank, block)
	b.set_meta("pad_x", "−1 point")  # manette : X = clic droit (retirer un point)
	b.pressed.connect(func():
		if Profile.add_talent(c, id):
			Sfx.ui("confirm")
			refresh())
	b.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			if Profile.remove_talent(c, id):
				Sfx.ui("cancel")
				refresh())
	v.add_child(b)
	var l := Hud._label(v, "%d / %d" % [rank, int(cell.max)], 14, (UiTheme.GOLD if not full else CarnetPages.GREEN) if rank > 0 else UiTheme.MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiTheme.bold_font())
	v.set_meta("talent_text", ItemWidgets.ItemGrid._plain(("%s %s" % [t.get("name", ""), t.get("desc", "")]).to_lower()))
	v.set_meta("req", int(cell.req))
	v.set_meta("req_pts", int(cell.req_pts))
	_cells[id] = v
	return v


## En-tête d'une colonne de l'arbre : le nombre de points à placer pour l'ouvrir (rien pour les colonnes ouvertes d'office).
func _tier_head(rows: Array, col: int) -> Control:
	var need := 0
	for row in rows:
		if col < (row as Array).size() and row[col] != null:
			need = maxi(need, int(row[col].get("spent", 0)))
	var box := CenterContainer.new()
	box.custom_minimum_size = Vector2(_cell_size(), 26)
	if need <= 0:
		return box
	var spent := Profile.talent_spent(_cls())
	var ok := spent >= need
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	h.tooltip_text = "Colonne ouverte : %d points placés." % need if ok else "S'ouvre à %d points placés dans l'arbre (encore %d)." % [need, need - spent]
	box.add_child(h)
	if not ok:
		Ico.mark(h, "lock", 14)
	var l := Hud._label(h, "%d pts" % need, 14, CarnetPages.GREEN if ok else UiTheme.MUTED)
	l.add_theme_font_override("font", UiTheme.bold_font())
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return box


## Taille d'une case de l'arbre : plus petite sous 800 px de haut (l'arbre tient dans 1280×720).
func _cell_size() -> float:
	return float(CELL) if get_viewport() == null or get_viewport().get_visible_rect().size.y >= 800.0 else 70.0


## Recherche (nom ou effet, sans accents ni casse) : les cases qui ne répondent pas pâlissent.
func _apply_search() -> void:
	if _search == null:
		return
	var q := ItemWidgets.ItemGrid._plain(_search.text.strip_edges().to_lower())
	for id in _cells:
		var v: Control = _cells[id]
		if is_instance_valid(v):
			v.modulate.a = 1.0 if q == "" or String(v.get_meta("talent_text", "")).contains(q) else 0.22
	if _tree:
		_tree.queue_redraw()


## Effet d'un talent [param t] au rang [param rank] : « +4 % de défense » (« +1 % de défense par niveau » × 4).
static func effect_at(t: Dictionary, rank: int) -> String:
	var desc := String(t.get("desc", ""))
	if rank <= 0:
		return "aucun effet"
	if not desc.contains(" par niveau"):
		return desc  # talent à un seul niveau : son texte est l'effet
	var eff: Dictionary = t.get("effect", {})
	var per := float(eff.get("per_level", 0.0))
	var v := per * rank * (1.0 if String(eff.get("type", "")) == "skill_duration" else 100.0)
	var rx := RegEx.new()
	rx.compile("([+\\-−])(\\d+(?:[.,]\\d+)?)")
	var m := rx.search(desc)
	var txt := desc.replace(" par niveau", "")
	if m == null:
		return txt
	var num := str(roundi(v)) if is_equal_approx(v, roundf(v)) else ("%.1f" % v).replace(".", ",")
	return txt.substr(0, m.get_start()) + m.get_string(1) + num + txt.substr(m.get_end())


func _talent_tip(c: String, _id: int, t: Dictionary, rank: int, block: String) -> String:
	var lines: PackedStringArray = []
	var icon := String(t.get("icon", ""))
	var mx := int(t.get("max", 1))
	lines.append(("[img=40x40]%s[/img]  " % icon if icon != "" else "") + "[font_size=19][b]%s[/b][/font_size]" % t.get("name", ""))
	lines.append("[color=#b8b4c8]Niveau %d / %d[/color]" % [rank, mx])
	# lot GX-5 : l'effet chiffré avant / après en tête
	if mx > 1:
		lines.append("Maintenant : [b]%s[/b]" % effect_at(t, rank))
		if rank < mx:
			lines.append("[color=#7fe08a]Avec un point de plus : [b]%s[/b][/color]" % effect_at(t, rank + 1))
		lines.append("[color=#b8b4c8]%s · niveau %d : %s[/color]" % [t.get("desc", ""), mx, effect_at(t, mx)])
	else:
		lines.append("[b]%s[/b]" % t.get("desc", ""))
		lines.append("[color=#7fe08a]Acquis[/color]" if rank > 0 else "")
	var cell := Profile._talent_cell(c, _id)
	if int(cell.get("req", 0)) > 0:
		var rt: Dictionary = GameData.talents.get(c, {}).get("talents", {}).get(str(int(cell.req)), {})
		var ok := Profile.talent_rank(c, cell.req) >= int(cell.req_pts)
		lines.append("[color=#%s]Demande : %s niveau %d %s[/color]" % ["7fe08a" if ok else "ff9a7a", rt.get("name", "?"), int(cell.req_pts), "✓" if ok else "✗"])
	if int(cell.get("spent", 0)) > 0:
		var ok2 := Profile.talent_spent(c) >= int(cell.spent)
		lines.append("[color=#%s]Colonne : %d points placés %s[/color]" % ["7fe08a" if ok2 else "ff9a7a", int(cell.spent), "✓" if ok2 else "✗"])
	if block == "":
		lines.append("[color=#ffcf6b]Clic : +1 point[/color]")
	elif block == "niveau maximal":
		lines.append("[color=#7fe08a]Niveau maximal[/color]")
	else:
		lines.append("[color=#ff9a7a]%s[/color]" % (block.left(1).to_upper() + block.substr(1)))
	if rank > 0:
		var rb := Profile.talent_remove_block(c, _id)
		lines.append("[color=#ffcf6b]Clic droit : −1 point (gratuit)[/color]" if rb == "" else "[color=#b8b4c8]Clic droit impossible : %s[/color]" % rb)
	var out: PackedStringArray = []
	for x in lines:
		if x != "":
			out.append(x)
	return "\n".join(out)


# --- build conseillé et chargements (lot GX-6) -------------------------------------------------------
func _refresh_advice(c: String, narrow: bool) -> void:
	var pts := Profile.talent_points(c)
	var same := Profile.talent_norm(Profile.talents.get(c, {})) == Profile.advised_talents(c)
	_advise.disabled = pts <= 0 or same
	_advise.text = "Conseillé ✓" if same and pts > 0 else "Conseillé"
	if pts <= 0:
		_advise.tooltip_text = "Aucun point de talent : monte la maîtrise de la classe."
	elif same:
		_advise.tooltip_text = "Tes points suivent déjà l'arbre conseillé."
	else:
		_advise.tooltip_text = "Place tes %d points selon l'arbre conseillé de la classe. Aperçu avant / après d'abord, puis « Annuler » si besoin." % pts
	_focus.text = TalentBuild.focus_line(c)
	_focus.tooltip_text = "L'arbre conseillé suit le profil de la classe (Registre) : ses stats ★ d'abord, puis les sorts renforcés du bout de l'arbre."
	_focus.mouse_filter = Control.MOUSE_FILTER_PASS
	var loads := Profile.talent_loads_of(c)
	for i in _load_btns.size():
		var b: Button = _load_btns[i]
		var e: Dictionary = loads[i]
		b.custom_minimum_size.x = 120.0 if narrow else 150.0
		b.text = "%d · %s" % [i + 1, String(e.name)] if not e.is_empty() else "%d · vide" % (i + 1)
		b.modulate = Color.WHITE if not e.is_empty() else Color(1, 1, 1, 0.75)
		if e.is_empty():
			b.tooltip_text = "Emplacement libre. Clic : y enregistrer ton arbre actuel."
		else:
			b.tooltip_text = "« %s » : %d points. Clic : charger, renommer, remplacer ou effacer." % [String(e.name), _sum(e.ranks)]


static func _sum(r: Dictionary) -> int:
	var n := 0
	for k in r:
		n += int(r[k])
	return n


## Texte de l'aperçu avant / après de [param after] sur l'arbre actuel.
func preview_text(c: String, after: Dictionary) -> String:
	var lines := TalentBuild.compare_lines(c, Profile.talents.get(c, {}), after)
	return "Avant → après\n%s\n\nTes points placés sont remplacés. « Annuler » remet l'arbre d'avant." % "\n".join(lines)


## « Conseillé » : aperçu avant / après, puis l'arbre conseillé posé (annulable).
func _ask_advised() -> void:
	var c := _cls()
	var adv := Profile.advised_talents(c)
	InfoCard.ask(self, "Arbre conseillé · %d points" % _sum(adv), preview_text(c, adv), "Placer ces points", _apply_ranks.bind(c, adv), false, "Garder mon arbre")


func _apply_ranks(c: String, r: Dictionary) -> void:
	if Profile.apply_talents(c, r):
		Sfx.ui("confirm")
	refresh()


## Ouvre la fiche du chargement [param slot] (charger, renommer, enregistrer l'arbre actuel, effacer).
func open_load(slot: int) -> void:
	if is_instance_valid(_load_dialog):
		_load_dialog.queue_free()
	_load_dialog = LoadDialog.new(self, slot)
	add_child(_load_dialog)


## Pose le chargement [param slot] après un aperçu avant / après.
func ask_load(slot: int) -> void:
	var c := _cls()
	var e: Dictionary = Profile.talent_loads_of(c)[slot]
	if e.is_empty() or Profile.talent_load_block(c, slot) != "":
		return
	InfoCard.ask(self, "Charger « %s »" % String(e.name), preview_text(c, e.ranks), "Charger", _apply_load.bind(c, slot), false, "Garder mon arbre")


func _apply_load(c: String, slot: int) -> void:
	if Profile.load_talent_load(c, slot):
		Sfx.ui("confirm")
	refresh()


## Fiche d'un chargement : son nom (modifiable), ce qu'il contient, et les gestes possibles.
class LoadDialog extends CanvasLayer:
	var page: TalentsPage
	var slot := 0
	var name_edit: LineEdit
	var _root: Control
	var _closed := false

	func _init(p: TalentsPage, i: int) -> void:
		page = p
		slot = i
		layer = InfoCard.LAYER
		process_mode = Node.PROCESS_MODE_ALWAYS
		_root = Control.new()
		_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_root)
		var dim := ColorRect.new()
		UiTheme.veil(dim, 0.45)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.gui_input.connect(_on_dim)
		_root.add_child(dim)
		var center := CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(center)
		var panel := PanelContainer.new()
		UiTheme.paper(panel, 7, Vector2(26, 20))
		panel.custom_minimum_size = Vector2(460, 0)
		center.add_child(panel)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		panel.add_child(v)
		var c := page._cls()
		var e: Dictionary = Profile.talent_loads_of(c)[slot]
		var t := Label.new()
		t.text = "Chargement %d" % (slot + 1)
		UiTheme.title(t, 22)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		name_edit = LineEdit.new()
		name_edit.max_length = Profile.TALENT_LOAD_NAME_MAX
		name_edit.placeholder_text = "Nom (Donjons, Duel…)"
		name_edit.text = String(e.get("name", ""))
		name_edit.custom_minimum_size = Vector2(0, 38)
		v.add_child(name_edit)
		var info := Label.new()
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.custom_minimum_size = Vector2(400, 0)
		info.add_theme_font_size_override("font_size", 15)
		info.add_theme_color_override("font_color", UiTheme.TEXT)
		v.add_child(info)
		var mine := Profile.talent_norm(Profile.talents.get(c, {}))
		if e.is_empty():
			info.text = "Emplacement libre." + ("" if not mine.is_empty() else "\nPlace d'abord des points dans l'arbre.")
		else:
			var block := Profile.talent_load_block(c, slot)
			info.text = "%d points · surtout %s" % [TalentsPage._sum(e.ranks), TalentBuild.main_stats(c, e.ranks)] + ("" if block == "" else "\nImpossible à charger : %s." % block)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		if not e.is_empty():
			var lb := _btn(row, "Charger", "soleil", _load)
			lb.disabled = Profile.talent_load_block(c, slot) != "" or Profile.talent_norm(e.ranks) == mine
		var sv := _btn(row, "Enregistrer ici" if e.is_empty() else "Remplacer par l'arbre actuel", "lagon", _save)
		sv.disabled = mine.is_empty()
		var row2 := HBoxContainer.new()
		row2.alignment = BoxContainer.ALIGNMENT_CENTER
		row2.add_theme_constant_override("separation", 8)
		v.add_child(row2)
		if not e.is_empty():
			_btn(row2, "Renommer", "papier", _rename)
			_btn(row2, "Effacer", "papier", _clear)
		_btn(row2, "Fermer", "papier", close)

	func _ready() -> void:
		UiNav.focus(name_edit)

	func _btn(parent: Control, text: String, tone: String, cb: Callable) -> Button:
		var b := Button.new()
		b.text = text
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(cb)
		UiTheme.style_button(b, tone, 15)
		parent.add_child(b)
		return b

	func _on_dim(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			close()

	func _input(event: InputEvent) -> void:
		if _closed:
			return
		if event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B):
			get_viewport().set_input_as_handled()
			close()

	func close() -> void:
		if _closed:
			return
		_closed = true
		queue_free()
		page.refresh()

	func _load() -> void:
		var p := page
		var i := slot
		close()
		p.ask_load(i)

	func _save() -> void:
		if Profile.save_talent_load(page._cls(), slot, name_edit.text):
			Sfx.ui("confirm")
		close()

	func _rename() -> void:
		if Profile.rename_talent_load(page._cls(), slot, name_edit.text):
			Sfx.ui("confirm")
		close()

	func _clear() -> void:
		if Profile.clear_talent_load(page._cls(), slot):
			Sfx.ui("cancel")
		close()


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
			var m := Ico.rect("lock", 16)
			add_child(m)
			m.position = Vector2(40, 40)
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


## Lot GX-5 : l'arbre de talents (une GridContainer dedans) dessine sous ses cases les liens de prérequis : de la case
## demandée vers celle qui la demande, pomme quand le prérequis est tenu, gris sinon, avec le niveau demandé au milieu.
class TreeView extends MarginContainer:
	var page: TalentsPage

	func _draw() -> void:
		if page == null:
			return
		var c := page._cls()
		var origin := get_global_rect().position
		var font := UiTheme.bold_font()
		for id in page._cells:
			var v: Control = page._cells[id]
			var req := int(v.get_meta("req", 0))
			if req <= 0 or not page._cells.has(req) or not is_instance_valid(v):
				continue
			var from_v: Control = page._cells[req]
			if from_v.get_child_count() == 0 or v.get_child_count() == 0:
				continue
			var a := (from_v.get_child(0) as Control).get_global_rect()
			var z := (v.get_child(0) as Control).get_global_rect()
			var p0 := Vector2(a.end.x, a.get_center().y) - origin
			var p1 := Vector2(z.position.x, z.get_center().y) - origin
			if absf(a.get_center().y - z.get_center().y) > 4.0:  # autre rangée : du bas (ou du haut) de la case demandée
				p0 = Vector2(a.get_center().x, a.end.y if z.get_center().y > a.get_center().y else a.position.y) - origin
			var ok := Profile.talent_rank(c, req) >= int(v.get_meta("req_pts", 0))
			var alpha := minf(v.modulate.a, from_v.modulate.a)
			var col := Color(CarnetPages.GREEN, alpha) if ok else Color(0.42, 0.4, 0.52, alpha)
			draw_line(p0, p1, Color(0.13, 0.1, 0.23, alpha), 8.0, true)  # contour d'encre
			draw_line(p0, p1, col, 4.0, true)
			var mid := (p0 + p1) * 0.5
			draw_circle(mid, 10.0, Color(0.13, 0.1, 0.23, alpha))
			draw_circle(mid, 8.0, col)
			var txt := str(int(v.get_meta("req_pts", 0)))
			var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
			draw_string(font, mid + Vector2(-sz.x * 0.5, 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.13, 0.1, 0.23, alpha))


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
