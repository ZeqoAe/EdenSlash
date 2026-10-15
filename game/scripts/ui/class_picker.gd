class_name ClassPicker
extends CanvasLayer
## Sélecteur de classe plein écran : les 5 familles en colonnes (Guerrier, Voleur,
## Chasseur, Clerc, Magicien). Dans chaque colonne, les classes vertes (classes de base)
## puis, en retrait sous chacune, ses ascensions orange.
## ClassPicker.button(...) donne le bouton « classe ▾ » qui ouvre le sélecteur.

signal picked(cls: String)

const GREEN := Color(0.45, 0.9, 0.5)
const ORANGE := Color(1.0, 0.62, 0.2)
const FAMILY_NAMES := {1: "Guerrier", 2: "Voleur", 3: "Chasseur", 4: "Clerc", 5: "Magicien"}

var current := ""
var allow_locked := false
var _detail: RichTextLabel
var _detail_icon: TextureRect


## Familles : [{family, name, classes: [id...]}] (vertes puis leurs orange).
static func families() -> Array:
	var out: Array = []
	for fam in [1, 2, 3, 4, 5]:
		var greens: Array = []
		for id in GameData.classes:
			var c: Dictionary = GameData.classes[id]
			if int(c.get("family", 1)) == fam and String(c.get("tier", "green")) == "green":
				greens.append(String(id))
		greens.sort_custom(func(a, b): return _order(a) < _order(b))
		var ids: Array = []
		for g in greens:
			ids.append(g)
			for id in GameData.classes:
				var c: Dictionary = GameData.classes[id]
				if String(c.get("tier", "")) == "orange" and String(c.get("parent", "")) == g:
					ids.append(String(id))
		out.append({"family": fam, "name": FAMILY_NAMES[fam], "classes": ids})
	return out


static func _order(id: String) -> int:
	var c := GameData.class_data(id)
	return Progression.requirement_level(id) * 100 + (50 if String(c.get("tier", "")) == "orange" else 0) + int(c.get("class_id", 0))


static func tier_color(id: String) -> Color:
	return ORANGE if String(GameData.class_data(id).get("tier", "green")) == "orange" else GREEN


## Bouton « icône Nom ▾ » qui ouvre le sélecteur ; [param get_current] rend la classe affichée.
static func button(get_current: Callable, on_pick: Callable, locked_ok := false, min_size := Vector2(260, 46)) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", 32)
	b.add_theme_font_size_override("font_size", 16)
	var upd := func():
		var cid: String = get_current.call()
		var cd := GameData.class_data(cid)
		b.text = "%s   ▾" % cd.get("name_fr", cid)
		b.icon = UiTheme.texture(String(cd.get("icon", "")))
		b.add_theme_color_override("font_color", tier_color(cid))
		b.tooltip_text = "Changer de classe (%d classes)" % GameData.classes.size()
	upd.call()
	b.pressed.connect(func():
		var p := ClassPicker.open(b, String(get_current.call()), locked_ok)
		p.picked.connect(func(cid):
			on_pick.call(cid)
			if is_instance_valid(b):
				upd.call()))
	b.set_meta("refresh", upd)
	return b


static func open(host: Node, cur: String, locked_ok := false) -> ClassPicker:
	var p := ClassPicker.new()
	p.current = cur
	p.allow_locked = locked_ok
	host.get_tree().root.add_child.call_deferred(p)
	return p


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			queue_free())
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.08, 0.07, 0.14, 0.98)))
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_top = 30
	panel.offset_right = -40
	panel.offset_bottom = -30
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	UiTheme.title(Hud._label(head, "Choisir une classe", 28, UiTheme.GOLD), 28)
	var legend := Hud._label(head, "   ● base", 15, GREEN)
	legend.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var legend2 := Hud._label(head, "   ● ascension", 15, ORANGE)
	legend2.tooltip_text = "Les ascensions gardent les sorts de leur classe d'origine."
	legend2.mouse_filter = Control.MOUSE_FILTER_PASS
	legend2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var close := Button.new()
	close.text = "Fermer  ✕"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(queue_free)
	head.add_child(close)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 10)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cols)
	for f in families():
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(col)
		var t := Hud._label(col, String(f.name), 18, UiTheme.GOLD)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for id in f.classes:
			col.add_child(_chip(String(id)))
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_detail_icon = TextureRect.new()
	_detail_icon.custom_minimum_size = Vector2(72, 72)
	_detail_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(_detail_icon)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_theme_font_size_override("normal_font_size", 15)
	_detail.add_theme_font_size_override("bold_font_size", 17)
	right.add_child(_detail)
	_show_detail(current)


func _chip(id: String) -> Button:
	var cd := GameData.class_data(id)
	var open := Progression.class_unlocked(id)
	var orange := String(cd.get("tier", "green")) == "orange"
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.text = ("%s" if open else "🔒 %s") % cd.get("name_fr", id)
	if open and Profile.expertise_level(id) > 1:
		b.text += "  · %d" % Profile.expertise_level(id)
	b.icon = UiTheme.texture(String(cd.get("icon", "")))
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", 28)
	b.add_theme_font_size_override("font_size", 13)
	b.custom_minimum_size = Vector2(0, 38)
	var col := ORANGE if orange else GREEN
	var sb := UiTheme.flat_box(Color(0.13, 0.11, 0.2, 0.95) if id != current else Color(0.26, 0.2, 0.36), Color(col, 0.85 if open else 0.35), 2, 6, false)
	sb.border_width_left = 6
	if orange:
		sb.content_margin_left = 22  # en retrait sous sa classe d'origine
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.24, 0.2, 0.34)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_color_override("font_color", col if open else Color(0.6, 0.6, 0.66))
	b.mouse_entered.connect(_show_detail.bind(id))
	b.pressed.connect(func():
		if not open and not allow_locked:
			_show_detail(id, true)
			return
		picked.emit(id)
		queue_free())
	return b


func _show_detail(id: String, refused := false) -> void:
	var cd := GameData.class_data(id)
	if cd.is_empty():
		return
	_detail_icon.texture = UiTheme.texture(String(cd.get("icon", "")))
	var orange := String(cd.get("tier", "green")) == "orange"
	var open := Progression.class_unlocked(id)
	var lines: PackedStringArray = []
	lines.append("[b][color=#%s]%s[/color][/b]" % [tier_color(id).to_html(false), cd.get("name_fr", id)])
	lines.append(("Ascension de %s" % GameData.class_data(String(cd.get("parent", ""))).get("name_fr", "")) if orange
		else "Classe de base · famille %s" % FAMILY_NAMES.get(int(cd.get("family", 1)), ""))
	lines.append("Arme : %s · %s" % [cd.get("weapon_name", ""), "dégâts magiques" if cd.get("dmg_type", "phys") == "mag" else "dégâts physiques"])
	var skills: Array = cd.get("skills", [])
	var shared := skills.filter(func(s): return s.get("shared", false)).size()
	lines.append("%d sorts dont %d partagés" % [skills.size(), shared])
	lines.append("")
	lines.append(String(cd.get("lore", "")))
	lines.append("")
	if open:
		lines.append("[color=#8fe39a]Débloquée[/color] · maîtrise niveau %d" % Profile.expertise_level(id))
	else:
		lines.append("[color=#ffcf6b]🔒 Pour la débloquer : %s[/color]" % Progression.mission_line(id))
		if refused:
			lines.append("[color=#ff8a8a]Classe encore verrouillée.[/color]")
	_detail.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
