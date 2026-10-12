class_name Grimoire
extends CanvasLayer
## Grimoire des classes, façon page de champion : statistiques de base, passifs,
## combo d'auto-attaque coup par coup, compétences avec infobulle détaillée et rangs.
## S'ouvre depuis le lobby et le menu pause (classe de la run en cours).

const COL_W := 400.0

var _root: Control
var _class_id := "samurai"
var _class_bar: HBoxContainer
var _header_icon: TextureRect
var _header_name: Label
var _header_lore: Label
var _stats: RichTextLabel
var _passives: VBoxContainer
var _combo_row: HBoxContainer
var _weapon_bar: HBoxContainer
var _weapon := ""
var _skills_grid: GridContainer
var _detail: RichTextLabel
var _rank_bar: HBoxContainer
var _skill: Dictionary = {}
var _rank := 1


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

	# barre du haut : titre, classes, fermer
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	var t := Label.new()
	t.text = "Grimoire"
	UiTheme.title(t, 30)
	top.add_child(t)
	_class_bar = HBoxContainer.new()
	_class_bar.add_theme_constant_override("separation", 6)
	_class_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_class_bar)
	var close := Button.new()
	close.text = "✕  Fermer (Échap)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_ui)
	top.add_child(close)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	v.add_child(body)

	# colonne gauche : portrait, histoire, statistiques, passifs
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(340, 0)
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	left.add_child(head)
	_header_icon = TextureRect.new()
	_header_icon.custom_minimum_size = Vector2(72, 72)
	_header_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	head.add_child(_header_icon)
	_header_name = Label.new()
	UiTheme.title(_header_name, 26)
	_header_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_header_name)
	_header_lore = Hud._label(left, "", 14, UiTheme.MUTED)
	_header_lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_header_lore.custom_minimum_size = Vector2(340, 0)
	_section(left, "Statistiques de base")
	_stats = _rich(left, 15)
	_stats.fit_content = true
	_section(left, "Passifs de classe")
	var ps := ScrollContainer.new()
	ps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(ps)
	_passives = VBoxContainer.new()
	_passives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_passives.add_theme_constant_override("separation", 8)
	ps.add_child(_passives)

	# centre : combo puis compétences
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	body.add_child(mid)
	_section(mid, "Combo d'auto-attaque  ·  dépend de l'arme en main (clic gauche répété)")
	_weapon_bar = HBoxContainer.new()
	_weapon_bar.add_theme_constant_override("separation", 4)
	mid.add_child(_weapon_bar)
	_combo_row = HBoxContainer.new()
	_combo_row.add_theme_constant_override("separation", 8)
	mid.add_child(_combo_row)
	_section(mid, "Compétences  ·  à débloquer avec les cartes de niveau (4 par run)")
	_skills_grid = GridContainer.new()
	_skills_grid.columns = 3
	_skills_grid.add_theme_constant_override("h_separation", 8)
	_skills_grid.add_theme_constant_override("v_separation", 8)
	mid.add_child(_skills_grid)

	# droite : détail de la compétence sélectionnée
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(COL_W, 0)
	right.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.07, 0.06, 0.13, 0.95), UiTheme.GOLD_DIM, 2, 10))
	body.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	right.add_child(rv)
	_rank_bar = HBoxContainer.new()
	_rank_bar.add_theme_constant_override("separation", 4)
	rv.add_child(_rank_bar)
	_detail = _rich(rv, 15)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.visible = false


func open(class_id := "") -> void:
	_class_id = class_id if class_id != "" else (Run.class_id if Run.active else Profile.selected_class)
	_weapon = Run.weapon_type() if Run.active else (Items.weapon_type_of(Profile.equipped.weapon) if Profile.equipped.has("weapon") else "")
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


# --- contenu ---------------------------------------------------------------------------------
func _refresh() -> void:
	var cls := GameData.class_data(_class_id)
	for c in _class_bar.get_children():
		c.queue_free()
	_class_bar.add_child(ClassPicker.button(func(): return _class_id, func(cid):
		_class_id = cid
		_skill = {}
		_refresh(), true))
	_header_icon.texture = UiTheme.texture(String(cls.get("icon", "")))
	_header_name.text = String(cls.get("name_fr", ""))
	_header_lore.text = String(cls.get("lore", ""))
	_stats.text = SpellInfo.class_stats_bbcode(cls)
	var atk := _atk()
	# passifs : ceux de la classe d'abord (icône d'Eden), puis les communs
	for c in _passives.get_children():
		c.queue_free()
	for p in cls.get("passives", []):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(36, 36)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.texture = UiTheme.texture(String(p.get("icon", Boons.ICONS.get(p.id, ""))))
		row.add_child(ic)
		var r := _rich(row, 13)
		r.fit_content = true
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.text = SpellInfo.passive_bbcode(p)
		_passives.add_child(row)
	# combo
	for c in _combo_row.get_children():
		c.queue_free()
	if _weapon == "":
		_weapon = Items.default_weapon_type(_class_id)
	for c in _weapon_bar.get_children():
		c.queue_free()
	for wt in GameData.weapon_types:
		var wb := Button.new()
		wb.text = String(GameData.weapon_types[wt].name)
		wb.icon = UiTheme.texture(String(GameData.weapon_types[wt].get("icon", "")))
		wb.add_theme_constant_override("icon_max_width", 22)
		wb.toggle_mode = true
		wb.button_pressed = wt == _weapon
		wb.focus_mode = Control.FOCUS_NONE
		var wid: String = wt
		wb.pressed.connect(func():
			_weapon = wid
			_refresh())
		_weapon_bar.add_child(wb)
	var wdata := GameData.weapon_type(_weapon)
	var chain: Array = wdata.get("combo", [])
	for i in chain.size():
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fin: bool = chain[i].get("finisher", false)
		card.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.1, 0.08, 0.17, 0.95), UiTheme.GOLD if fin else UiTheme.GOLD_DIM, 2 if fin else 1, 8))
		var r := _rich(card, 13)
		r.fit_content = true
		r.text = SpellInfo.combo_step_bbcode(chain[i], i, wdata, _atk(String(wdata.get("dmg_type", "phys"))))
		_combo_row.add_child(card)
		if i < chain.size() - 1:
			var arrow := Hud._label(_combo_row, "➜", 22, UiTheme.GOLD)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# compétences
	for c in _skills_grid.get_children():
		c.queue_free()
	var skills: Array = cls.get("skills", [])
	for s in skills:
		var b := Button.new()
		b.text = "  " + String(s.name)
		b.icon = UiTheme.texture(String(s.get("icon", "")))
		b.expand_icon = false
		b.add_theme_constant_override("icon_max_width", 40)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 52)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		var owned := _owned_rank(int(s.id))
		if Run.active and owned > 0:
			b.text += "  (rang %d)" % owned
		# sorts débloqués par la maîtrise de la classe
		var need := Progression.skill_level_of(_class_id, int(s.id))
		if not Progression.skill_unlocked(_class_id, int(s.id)):
			b.text += "   🔒 maîtrise niv. %d" % need
			b.modulate = Color(0.7, 0.7, 0.75)
		b.tooltip_text = "Sort de base" if need <= 1 else "Débloqué au niveau %d de maîtrise de la classe" % need
		var sd: Dictionary = s
		b.pressed.connect(func():
			_skill = sd
			_rank = maxi(1, _owned_rank(int(sd.id)))
			_refresh_detail())
		_skills_grid.add_child(b)
	if _skill.is_empty() and not skills.is_empty():
		_skill = skills[0]
		_rank = maxi(1, _owned_rank(int(_skill.id)))
	_refresh_detail()


func _refresh_detail() -> void:
	for c in _rank_bar.get_children():
		c.queue_free()
	if _skill.is_empty():
		_detail.text = ""
		return
	var cls := GameData.class_data(_class_id)
	for i in _skills_grid.get_child_count():
		(_skills_grid.get_child(i) as Button).set_pressed_no_signal(i < cls.skills.size() and int(cls.skills[i].id) == int(_skill.id))
	Hud._label(_rank_bar, "Rang :", 14, UiTheme.MUTED)
	for r in range(1, Run.MAX_RANK + 1):
		var b := Button.new()
		b.text = str(r)
		b.toggle_mode = true
		b.button_pressed = r == _rank
		b.custom_minimum_size = Vector2(34, 30)
		b.focus_mode = Control.FOCUS_NONE
		var rr := r
		b.pressed.connect(func():
			_rank = rr
			_refresh_detail())
		_rank_bar.add_child(b)
	var icon := String(_skill.get("icon", ""))
	_detail.text = ("[img=64x64]%s[/img]\n" % icon if icon != "" else "") + SpellInfo.skill_bbcode(_skill, _rank, _atk(String(_skill.get("dmg_type", "phys"))))


## Attaque actuelle du héros (physique ou magique) pour chiffrer les dégâts, sinon estimation niveau 1.
func _atk(dmg_type := "") -> float:
	var cls := GameData.class_data(_class_id)
	if dmg_type == "":
		dmg_type = String(cls.get("dmg_type", "phys"))
	var p := get_tree().get_first_node_in_group("player") as Player
	if p and p.class_id == _class_id:
		return p.matk if dmg_type == "mag" else p.atk
	var base: Dictionary = cls.get("base", {})
	return GameData.player_atk(1) * float(base.get("matk" if dmg_type == "mag" else "atk", 0.5 if dmg_type == "mag" else 1.0))


func _owned_rank(id: int) -> int:
	return Run.skill_rank(id) if Run.active and _class_id == Run.class_id else 0


func _section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	UiTheme.title(l, 17)
	parent.add_child(l)


func _rich(parent: Control, size: int) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_font_size_override("italics_font_size", size)
	r.scroll_active = true
	r.selection_enabled = false
	parent.add_child(r)
	return r
