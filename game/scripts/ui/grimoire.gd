class_name Grimoire
extends CanvasLayer
## Grimoire des classes, façon page de champion :
## - à gauche : portrait, statistiques de base, attributs par niveau, arme de la classe ;
## - au centre : compétences de la classe, puis ses passifs ;
## - à droite : le détail de ce qu'on a cliqué (compétence et ses rangs, combo de l'arme
##   coup par coup, passif).
## S'ouvre depuis la page Classe du héros et le menu pause (classe de la run en cours).

const LEFT_W := 330.0
const RIGHT_W := 430.0

var _root: Control
var _class_id := "samurai"
var _class_bar: HBoxContainer
var _header_icon: TextureRect
var _header_name: Label
var _header_lore: Label
var _stats: RichTextLabel
var _weapon_box: VBoxContainer
var _skills_grid: GridContainer
var _passives_grid: GridContainer
var _detail: RichTextLabel
var _rank_bar: HBoxContainer
var _selected := {}  # {kind: "skill" | "weapon" | "passive", data}
var _rank := 1
var _buttons: Array = []  # [Button, sélection] pour l'état enfoncé


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
	panel.offset_left = 32
	panel.offset_top = 26
	panel.offset_right = -32
	panel.offset_bottom = -26
	panel.clip_contents = true
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	# barre du haut : titre, classe, fermer
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

	# --- gauche : portrait, statistiques, attributs par niveau, arme de la classe ---
	var lscroll := ScrollContainer.new()
	lscroll.custom_minimum_size = Vector2(LEFT_W, 0)
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(lscroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	lscroll.add_child(left)
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
	_header_lore.custom_minimum_size = Vector2(LEFT_W - 20, 0)
	_section(left, "Statistiques de base")
	_stats = _rich(left, 15)
	_stats.fit_content = true
	_stats.scroll_active = false
	_stats.custom_minimum_size = Vector2(LEFT_W - 20, 0)
	_section(left, "Arme de la classe")
	Hud._label(left, "Combo d'auto-attaque (clic gauche répété) : clique pour le détail.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weapon_box = VBoxContainer.new()
	left.add_child(_weapon_box)

	# --- centre : compétences puis passifs ---
	var mscroll := ScrollContainer.new()
	mscroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(mscroll)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	mscroll.add_child(mid)
	_section(mid, "Compétences de la classe")
	Hud._label(mid, "À débloquer avec les cartes de niveau (4 par run) ; certaines demandent un niveau de maîtrise.", 13, UiTheme.MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skills_grid = GridContainer.new()
	_skills_grid.columns = 2
	_skills_grid.add_theme_constant_override("h_separation", 8)
	_skills_grid.add_theme_constant_override("v_separation", 8)
	mid.add_child(_skills_grid)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	mid.add_child(gap)
	_section(mid, "Passifs de la classe (certificats d'Eden, choisis avant la run)")
	_passives_grid = GridContainer.new()
	_passives_grid.columns = 3
	_passives_grid.add_theme_constant_override("h_separation", 8)
	_passives_grid.add_theme_constant_override("v_separation", 6)
	mid.add_child(_passives_grid)

	# --- droite : détail de la sélection ---
	var right := PanelContainer.new()
	right.custom_minimum_size = Vector2(RIGHT_W, 0)
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
	_selected = {}
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
## Grand bouton (icône + nom) qui sélectionne [param sel] pour le panneau de droite.
func _entry(parent: Control, icon: String, text: String, sel: Dictionary, height := 52.0) -> Button:
	var b := Button.new()
	b.text = "  " + text
	b.icon = UiTheme.texture(icon)
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", int(height) - 12)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.custom_minimum_size = Vector2(0, height)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		_selected = sel
		if sel.kind == "skill":
			_rank = maxi(1, _owned_rank(int(sel.data.id)))
		_refresh_detail())
	parent.add_child(b)
	_buttons.append([b, sel])
	return b


func _refresh() -> void:
	var cls := GameData.class_data(_class_id)
	for c in _class_bar.get_children():
		c.queue_free()
	_class_bar.add_child(ClassPicker.button(func(): return _class_id, func(cid):
		_class_id = cid
		_selected = {}
		_refresh(), true))
	_header_icon.texture = UiTheme.texture(String(cls.get("icon", "")))
	_header_name.text = String(cls.get("name_fr", ""))
	_header_lore.text = String(cls.get("lore", ""))
	_stats.text = SpellInfo.class_stats_bbcode(cls)
	_buttons.clear()
	# arme de la classe : son combo s'affiche à droite
	for c in _weapon_box.get_children():
		c.queue_free()
	var wt := Items.default_weapon_type(_class_id)
	var wdata := GameData.weapon_type(wt)
	var weapon_sel := {"kind": "weapon", "data": wt}
	_entry(_weapon_box, String(wdata.get("icon", "")), "%s  ·  combo en %d coups" % [String(wdata.get("name", wt)), (wdata.get("combo", []) as Array).size()], weapon_sel, 56.0)
	# compétences
	for c in _skills_grid.get_children():
		c.queue_free()
	var skills: Array = cls.get("skills", [])
	for s in skills:
		var label := String(s.name)
		var owned := _owned_rank(int(s.id))
		if Run.active and owned > 0:
			label += "  (rang %d)" % owned
		var need := Progression.skill_level_of(_class_id, int(s.id))
		var locked := not Progression.skill_unlocked(_class_id, int(s.id))
		if locked:
			label += "   🔒 maîtrise %d" % need
		var b := _entry(_skills_grid, String(s.get("icon", "")), label, {"kind": "skill", "data": s})
		if locked:
			b.modulate = Color(0.7, 0.7, 0.75)
		b.tooltip_text = String(s.name) + ("  ·  sort de base" if need <= 1 else "  ·  débloqué au niveau %d de maîtrise de la classe" % need)
	# passifs : ceux de la classe d'abord (icône d'Eden), puis les communs
	for c in _passives_grid.get_children():
		c.queue_free()
	for p in cls.get("passives", []):
		var label := String(p.get("name", "?"))
		if int(p.get("max", 1)) > 1:
			label += "  ×%d" % int(p.max)
		var b := _entry(_passives_grid, String(p.get("icon", Boons.ICONS.get(p.get("id", ""), ""))), label, {"kind": "passive", "data": p}, 44.0)
		b.tooltip_text = label
	if _selected.is_empty():
		_selected = {"kind": "skill", "data": skills[0]} if not skills.is_empty() else weapon_sel
		if _selected.kind == "skill":
			_rank = maxi(1, _owned_rank(int(_selected.data.id)))
	_refresh_detail()


func _same(a: Dictionary, b: Dictionary) -> bool:
	if a.is_empty() or b.is_empty() or a.kind != b.kind:
		return false
	if a.kind == "weapon":
		return a.data == b.data
	return is_same(a.data, b.data) or (a.data is Dictionary and b.data is Dictionary and a.data.get("id") == b.data.get("id") and a.data.get("name") == b.data.get("name"))


func _refresh_detail() -> void:
	for c in _rank_bar.get_children():
		c.queue_free()
	for pair in _buttons:
		if is_instance_valid(pair[0]):
			(pair[0] as Button).set_pressed_no_signal(_same(pair[1], _selected))
	if _selected.is_empty():
		_detail.text = ""
		return
	match String(_selected.kind):
		"skill":
			var sk: Dictionary = _selected.data
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
			var icon := String(sk.get("icon", ""))
			var txt := ("[img=64x64]%s[/img]\n" % icon if icon != "" else "") + SpellInfo.skill_bbcode(sk, _rank, _atk(String(sk.get("dmg_type", "phys"))))
			var cards := Cards.class_cards(_class_id).filter(func(d): return int(d.skill) == int(sk.id))
			if not cards.is_empty():
				txt += "

[b]Cartes de classe pour ce sort[/b] (en run, une fois le sort pris)"
				for d in cards:
					txt += "
• %s : %s (jusqu'à %d fois)" % [String(d.name).get_slice(" : ", 1), " ; ".join(Cards.skill_mod_lines(d, 0.0, 1.0)), int(d.max)]
			var need := Progression.skill_level_of(_class_id, int(sk.id))
			if not Progression.skill_unlocked(_class_id, int(sk.id)):
				txt += "\n\n[color=#ffcf6b]🔒 Débloqué au niveau %d de maîtrise de la classe[/color]" % need
			_detail.text = txt
		"weapon":
			var wt := String(_selected.data)
			var wdata := GameData.weapon_type(wt)
			var chain: Array = wdata.get("combo", [])
			var atk := _atk(String(wdata.get("dmg_type", "phys")))
			var parts: PackedStringArray = []
			var icon := String(wdata.get("icon", ""))
			parts.append(("[img=56x56]%s[/img]  " % icon if icon != "" else "") + "[font_size=22][b]%s[/b][/font_size]" % String(wdata.get("name", wt)))
			parts.append("[color=#c8c8d4]Combo d'auto-attaque en %d coups (clic gauche répété). Une autre arme équipée change le combo.[/color]" % chain.size())
			for i in chain.size():
				parts.append(("[color=#ffcf6b]━━━━━━━━━━[/color]\n" if i > 0 else "") + SpellInfo.combo_step_bbcode(chain[i], i, wdata, atk))
			_detail.text = "\n\n".join(parts)
		"passive":
			var p: Dictionary = _selected.data
			var icon := String(p.get("icon", Boons.ICONS.get(p.get("id", ""), "")))
			_detail.text = ("[img=64x64]%s[/img]\n" % icon if icon != "" else "") + "[font_size=17]" + SpellInfo.passive_bbcode(p) + "[/font_size]" + \
				"

[color=#c8c8d4]Certificat de la classe : à placer sur le plateau de la page Classe avant la run (7 au plus) ; une fois la classe maîtrisée, utilisable par les autres classes.[/color]"


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
