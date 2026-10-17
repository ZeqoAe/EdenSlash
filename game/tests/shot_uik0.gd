extends Node
## Planche du socle de l'interface (UIK0) : tous les composants autocollants dans tous leurs états, sur papier (peau
## « sticker ») à gauche et sur puits d'encre (écrans actuels) à droite ; captures 1280×720 et 1600×900 dans
## user://shots/uik0/ (APPDATA détourné conseillé). UIK0_SKIN=night pour la peau technique.
##   godot --path game res://tests/shot_uik0.tscn

const STATES := [["normal", "repos"], ["hover", "survol"], ["pressed", "pressé"], ["focus", "focus manette"], ["disabled", "désactivé"], ["selected", "sélectionné"]]

var _root: Control
var _primary: Array[Button] = []


## Anneau de focus de la manette (même dessin que UiNav) autour du contrôle parent.
class FocusRing extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size).grow(5.0)
		var w := StyleBoxFlat.new()
		w.draw_center = false
		w.set_border_width_all(6)
		w.border_color = Color.WHITE
		w.set_corner_radius_all(20)
		w.anti_aliasing = true
		var l := w.duplicate() as StyleBoxFlat
		l.set_border_width_all(3)
		l.border_color = UiTheme.color("bonbon.lagon.fonce")
		l.set_corner_radius_all(17)
		draw_style_box(w, r.grow(3.0))
		draw_style_box(l, r)


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit(1))
	if OS.get_environment("UIK0_SKIN") != "":
		UiTheme.set_skin(OS.get_environment("UIK0_SKIN"))
	Settings.reset_all(false)
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		DisplayServer.window_set_size(res)
		get_window().size = res
		await get_tree().create_timer(0.4).timeout
		_build()
		await get_tree().create_timer(0.6).timeout
		for b in _primary:  # le bouton primaire relâché : anneau et étincelles (UiFeel)
			UiFeel.ring(UiFeel._center(b), maxf(b.size.x, b.size.y) * 0.5)
			UiFeel.sparkle(UiFeel._center(b), 4, ["soleil", "papier", "lagon", "fraise"], maxf(b.size.x, b.size.y) * 0.45)
		await get_tree().create_timer(0.09).timeout
		DirAccess.make_dir_recursive_absolute("user://shots/uik0")
		var path := "user://shots/uik0/planche_%s_%dx%d.png" % [UiTheme.skin, res.x, res.y]
		get_viewport().get_texture().get_image().save_png(path)
		print("[uik0] ", ProjectSettings.globalize_path(path))
	get_tree().quit()


func _build() -> void:
	if _root != null:
		_root.queue_free()
	_primary.clear()
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_root)
	# fond : le ciel clair du monde (couleurs mesurées), comme un menu posé sur la scène
	var bg := TextureRect.new()
	var g := GradientTexture2D.new()
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	g.gradient = Gradient.new()
	g.gradient.set_color(0, UiTheme.color("monde.ciel", Color("ccdef3")))
	g.gradient.set_color(1, Color("acb47f"))
	bg.texture = g
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var w := get_viewport().get_visible_rect().size
	var compact := w.x < 1500.0
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_top = 12
	h.offset_right = -16
	h.offset_bottom = -26
	h.add_theme_constant_override("separation", 16)
	_root.add_child(h)
	var paper := UiTheme.StickerPanel.new("papier" if UiTheme.skin != "night" else "nuit", 7.0)
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(paper)
	UiTheme.scope(paper, false)
	_kit(paper, true, compact)
	var night := PanelContainer.new()
	night.add_theme_stylebox_override("panel", UiTheme.panel_box(18, 14))
	night.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(night)
	_kit(night, false, compact)


func _title(parent: Control, text: String, paper: bool, size := 22) -> void:
	var l := Label.new()
	l.text = text
	parent.add_child(l)
	if paper and UiTheme.skin != "night":
		l.add_theme_font_override("font", UiTheme.title_font())
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", UiTheme.color("encre.700"))
	else:
		UiTheme.title(l, size)


func _caption(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiTheme.label_font())
	l.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
	parent.add_child(l)
	l.add_theme_color_override("font_color", Color(l.get_theme_color("font_color"), 0.75))


## Bouton figé dans un état (pour la planche) : la boîte de cet état sert de boîte « normal ».
func _frozen(tone: String, state: String, text: String, size: int, min_w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(min_w, 0)
	b.set_meta("ui_feel", "off")
	UiTheme.style_button(b, tone, size)
	var st := UiTheme.button_states(tone)
	var key := {"focus": "normal", "selected": "selected"}.get(state, state) as String
	b.add_theme_stylebox_override("normal", st[key])
	if state == "disabled":
		b.add_theme_color_override("font_color", b.get_theme_color("font_disabled_color"))
		b.text = "🔒 " + text
	if state == "selected":
		var ink := UiTheme.color("encre.900") if not tone.begins_with("nuit") else Color.WHITE
		b.add_theme_color_override("font_color", ink)
		if tone.begins_with("nuit"):
			b.add_theme_constant_override("outline_size", 3)
	if state == "focus":
		b.add_child(FocusRing.new())
	return b


func _cell(parent: Control, c: Control, caption: String) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	parent.add_child(v)
	v.add_child(c)
	_caption(v, caption)


func _kit(panel: Control, paper: bool, compact: bool) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6 if compact else 10)
	panel.add_child(v)
	var tone := ("papier" if UiTheme.skin != "night" else "nuit") if paper else "nuit"
	var bw := 84.0 if compact else 104.0
	var fs := 15 if compact else 18
	_title(v, "Boutons" if paper else "Sur puits d'encre (écrans actuels)", paper, 20 if compact else 24)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	v.add_child(row)
	for s in STATES:
		_cell(row, _frozen(tone, String(s[0]), "Équiper", fs, bw), String(s[1]))
	var row2 := HFlowContainer.new()
	row2.add_theme_constant_override("h_separation", 8)
	v.add_child(row2)
	for s in [["normal", "primaire"], ["hover", "survol"], ["pressed", "pressé"]]:
		var b := _frozen("soleil", String(s[0]), "Jouer", fs + 4, bw + 8)
		_cell(row2, b, String(s[1]))
	var live := MenuWidgets.gold_button("Lancer", fs + 4, Vector2(bw + 16, 0))
	_primary.append(live)
	_cell(row2, live, "relâché")
	_cell(row2, _frozen("lagon", "normal", "Ouvrir", fs, bw - 10), "action douce")
	_cell(row2, _frozen("fraise", "normal", "Vendre", fs, bw - 10), "destructif")
	_title(v, "Onglets, interrupteurs, pastilles", paper, 18 if compact else 22)
	var row3 := HFlowContainer.new()
	row3.add_theme_constant_override("h_separation", 6)
	row3.add_theme_constant_override("v_separation", 6)
	v.add_child(row3)
	for t in [["Équipement", true], ["Classe", false], ["Apparence", false]]:
		var tb := Button.new()
		tb.text = String(t[0])
		tb.toggle_mode = true
		tb.button_pressed = bool(t[1])
		tb.focus_mode = Control.FOCUS_NONE
		tb.theme_type_variation = &"PageTab"
		tb.add_theme_font_size_override("font_size", 14 if compact else 16)
		row3.add_child(tb)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	row3.add_child(gap)
	for on in [false, true]:
		var sw := UiTheme.Switch.new()
		sw.set_on(on)
		row3.add_child(sw)
	var sw_off := UiTheme.Switch.new()
	sw_off.disabled = true
	row3.add_child(sw_off)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.sticker("fraise", {"shadow": 2, "radius": 10, "gloss": false, "pad": Vector2(8, 0)}))
	badge.rotation_degrees = 8.0
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bl := Label.new()
	bl.text = "6"
	bl.add_theme_font_override("font", UiTheme.number_font())
	bl.add_theme_color_override("font_color", Color.WHITE)
	bl.add_theme_constant_override("outline_size", 3)
	bl.add_theme_color_override("font_outline_color", UiTheme.color("encre.700"))
	badge.add_child(bl)
	row3.add_child(badge)
	_title(v, "Jauges et réglage", paper, 18 if compact else 22)
	var gauges := HBoxContainer.new()
	gauges.add_theme_constant_override("separation", 12)
	v.add_child(gauges)
	for p in [[0.68, "Vie 842 / 1 232"], [0.13, "Maîtrise 160 / 1 240"]]:
		var gv := VBoxContainer.new()
		gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gauges.add_child(gv)
		_caption(gv, String(p[1]))
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 20)
		pb.value = float(p[0]) * 100.0
		gv.add_child(pb)
	var sl := HSlider.new()
	sl.custom_minimum_size = Vector2(160, 26)
	sl.value = 60
	sl.size_flags_vertical = Control.SIZE_SHRINK_END
	gauges.add_child(sl)
	_title(v, "Menus", paper, 18 if compact else 22)
	var menus := HBoxContainer.new()
	menus.add_theme_constant_override("separation", 10)
	v.add_child(menus)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	menus.add_child(side)
	var s1 := MenuWidgets.SideButton.new("Héros", "class", 44.0 if compact else 52.0)
	s1.custom_minimum_size.x = 180 if compact else 220
	side.add_child(s1)
	var s2 := MenuWidgets.SideButton.new("Coffres", "chest", 44.0 if compact else 52.0)
	s2.custom_minimum_size.x = 180 if compact else 220
	s2.set_badge("6")
	s2.selected = true
	side.add_child(s2)
	var rb := MenuWidgets.RowButton.new("Survie", "Trois cartes d'une époque : pièces et maîtrise", "", 60.0 if compact else 68.0)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	menus.add_child(rb)
	var txt := Label.new()
	txt.text = "Œuvre « Ça » : Épée, Forêt, Noël — × → ▲ ▼ ★ ✔ 0123456789 · 12 450 insignes"
	txt.add_theme_font_size_override("font_size", 15 if compact else 17)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(txt)
	var glass := HBoxContainer.new()
	glass.add_theme_constant_override("separation", 8)
	v.add_child(glass)
	glass.add_child(MenuWidgets.glass_button("Secondaire", fs, Vector2(0, 40)))
	var plain := Button.new()
	plain.text = "Bouton du thème"
	plain.focus_mode = Control.FOCUS_NONE
	glass.add_child(plain)
	var tog := Button.new()
	tog.text = "À bascule"
	tog.toggle_mode = true
	tog.button_pressed = true
	tog.focus_mode = Control.FOCUS_NONE
	glass.add_child(tog)
	var dis := Button.new()
	dis.text = "Niv. 20"
	dis.disabled = true
	glass.add_child(dis)
