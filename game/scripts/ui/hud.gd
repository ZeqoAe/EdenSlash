class_name Hud
extends CanvasLayer
## Interface épurée : barre de vie / XP, 4 compétences de la run, buffs,
## cible, objectif, mini-carte, messages.

const ACCENT := Color(0.98, 0.78, 0.35)
const PANEL := Color(0.07, 0.06, 0.12, 0.82)

var player: Player
var director: RunDirector
var minimap: Minimap

var _hp_bar: ProgressBar
var _hp_label: Label
var _xp_bar: ProgressBar
var _level_label: Label
var _zone_label: Label
var _objective_label: Label
var _center_label: Label
var _target_box: PanelContainer
var _target_name: Label
var _target_bar: ProgressBar
var _target_status: Label
var _slots: Array = []  # [{icon, shade, time, rank}]
var _buffs: Label
var _fps_label: Label
var _arrow: Label
var _big_map: Minimap
var _prompt: Label
var _msg_tween: Tween


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	_build()
	player.health_changed.connect(_on_hp)
	player.xp_changed.connect(_on_xp)
	player.skills_changed.connect(_refresh_skills)
	Settings.changed.connect(_refresh_skills)
	director.zone_changed.connect(func(z): _zone_label.text = "%s · Nv %d-%d" % [z.name, z.levels[0], z.levels[1]])
	director.objective_changed.connect(func(t):
		_objective_label.text = t
		_objective_label.modulate = Color(1.0, 0.45, 0.4) if director.state == "rage" else Color.WHITE)
	director.message.connect(show_message)
	_on_hp(player.hp, player.max_hp)
	_on_xp(player.xp, GameData.xp_to_next(player.level), player.level)
	_refresh_skills()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# NB : root n'est ajouté qu'à la fin, pour que les positions ancrées
	# (centre, bas, droite) soient relatives à l'ancre.

	# --- objectif (haut gauche) ---
	var top := _panel(root)
	top.position = Vector2(16, 14)
	top.custom_minimum_size = Vector2(380, 0)
	var tv := VBoxContainer.new()
	top.add_child(tv)
	_zone_label = _label(tv, "", 18, ACCENT)
	_objective_label = _label(tv, "", 15, Color.WHITE)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_label.custom_minimum_size = Vector2(356, 0)

	# --- mini-carte (haut droite) ---
	minimap = Minimap.new()
	minimap.process_mode = Node.PROCESS_MODE_ALWAYS
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-236, 14)
	minimap.size = Vector2(220, 220)
	root.add_child(minimap)
	minimap.setup(player, director)
	_fps_label = _label(root, "", 12, Color(1, 1, 1, 0.55))
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.position = Vector2(-236, 238)

	# --- cible (haut centre) ---
	_target_box = _panel(root)
	_target_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_target_box.position = Vector2(-170, 14)
	_target_box.custom_minimum_size = Vector2(340, 0)
	var tg := VBoxContainer.new()
	_target_box.add_child(tg)
	_target_name = _label(tg, "", 15, Color.WHITE)
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_bar = _bar(tg, Color(0.85, 0.2, 0.25), 10)
	_target_status = _label(tg, "", 12, Color(1, 0.8, 0.6))
	_target_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_box.visible = false

	# --- barre principale (bas centre) ---
	var bottom := _panel(root)
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-300, -150)
	bottom.custom_minimum_size = Vector2(600, 0)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 14)
	bottom.add_child(bh)
	# niveau
	var lv := PanelContainer.new()
	var lvs := StyleBoxFlat.new()
	lvs.bg_color = Color(0.16, 0.12, 0.22)
	lvs.border_color = ACCENT
	lvs.set_border_width_all(2)
	lvs.set_corner_radius_all(30)
	lv.add_theme_stylebox_override("panel", lvs)
	lv.custom_minimum_size = Vector2(60, 60)
	lv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bh.add_child(lv)
	_level_label = _label(lv, "1", 24, ACCENT)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# vie + xp + compétences
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	bh.add_child(col)
	_buffs = _label(col, "", 12, Color(1, 0.9, 0.6))
	_hp_bar = _bar(col, Color(0.86, 0.22, 0.3), 16)
	_hp_label = _label(_hp_bar, "", 12, Color.WHITE)
	_hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_bar = _bar(col, ACCENT, 5)
	var skills := HBoxContainer.new()
	skills.add_theme_constant_override("separation", 10)
	skills.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(skills)
	for i in 4:
		skills.add_child(_make_slot(i))

	# --- messages (centre) ---
	_center_label = _label(root, "", 40, ACCENT)
	_center_label.set_anchors_preset(Control.PRESET_CENTER)
	_center_label.position = Vector2(-500, -230)
	_center_label.size = Vector2(1000, 140)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.add_theme_constant_override("outline_size", 10)
	_center_label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	_center_label.modulate.a = 0.0

	_prompt = _label(root, "", 22, Color.WHITE)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-300, -200)
	_prompt.size = Vector2(600, 40)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_constant_override("outline_size", 8)

	_arrow = _label(root, "▲", 36, ACCENT)
	_arrow.add_theme_constant_override("outline_size", 8)
	_arrow.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.15))
	_arrow.pivot_offset = Vector2(13, 25)
	_arrow.visible = false

	# --- grande carte [M] ---
	_big_map = Minimap.new()
	_big_map.big = true
	_big_map.set_anchors_preset(Control.PRESET_CENTER)
	_big_map.position = Vector2(-340, -340)
	_big_map.size = Vector2(680, 680)
	_big_map.visible = false
	root.add_child(_big_map)
	_big_map.setup(player, director)
	add_child(root)


func _make_slot(i: int) -> Control:
	var box := Panel.new()
	box.custom_minimum_size = Vector2(62, 62)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.18)
	sb.border_color = Color(ACCENT, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	box.add_theme_stylebox_override("panel", sb)
	var icon := TextureRect.new()
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 4
	icon.offset_top = 4
	icon.offset_right = -4
	icon.offset_bottom = -4
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box.add_child(icon)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(shade)
	var t := _label(box, "", 18, Color.WHITE)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var key := _label(box, "", 12, ACCENT)
	key.position = Vector2(4, 44)
	var rank := _label(box, "", 11, Color(0.6, 0.85, 1.0))
	rank.position = Vector2(44, 2)
	var auto := _label(box, "", 10, Color(0.55, 1.0, 0.6))
	auto.position = Vector2(4, 2)
	_slots.append({"icon": icon, "shade": shade, "time": t, "rank": rank, "key": key, "auto": auto})
	return box


func _refresh_skills() -> void:
	for i in 4:
		var s := player.skill_in_slot(i)
		var slot: Dictionary = _slots[i]
		slot.key.text = Settings.action_label("skill_%d" % (i + 1), 1)
		slot.auto.text = "AUTO" if Settings.auto_skill(i) else ""
		if s.is_empty():
			slot.icon.texture = null
			slot.rank.text = ""
			continue
		slot.icon.texture = load(s.icon) if ResourceLoader.exists(String(s.icon)) else null
		var r := Run.skill_rank(int(s.id))
		slot.rank.text = "R%d" % r if r > 1 else ""


func _process(_delta: float) -> void:
	if player == null:
		return
	_fps_label.visible = Settings.get_v("interface", "show_fps")
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	# recharges
	for i in 4:
		var slot: Dictionary = _slots[i]
		var s := player.skill_in_slot(i)
		var left := player.cooldown_left(i)
		slot.shade.visible = s.is_empty() or left > 0.0
		slot.time.text = "" if left <= 0.0 else ("%.1f" % left if left < 10.0 else str(int(left)))
	# buffs actifs
	var parts: PackedStringArray = []
	for st in player.statuses:
		if Combatant.STATUS_INFO.has(st):
			parts.append("%s %d s" % [Combatant.STATUS_INFO[st].name, ceili(float(player.statuses[st]) - player.clock)])
	_buffs.text = "  ·  ".join(parts)
	# cible : verrouillée, sinon la plus proche
	var t := player.current_target()
	if t == null:
		t = player.nearest_monster(9.0)
	if t != null:
		_target_box.visible = true
		_target_name.text = "%s  ·  Nv %d" % [t.display_name, t.level]
		_target_bar.max_value = t.max_hp
		_target_bar.value = t.hp
		var st: PackedStringArray = []
		for s in t.statuses:
			if Combatant.STATUS_INFO.has(s):
				st.append(Combatant.STATUS_INFO[s].name)
		_target_status.text = " · ".join(st)
	else:
		_target_box.visible = false
	_update_arrow()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		_big_map.visible = not _big_map.visible


## Flèche autour du héros pointant vers l'objectif.
func _update_arrow() -> void:
	var target := director.objective_target()
	var cam := get_viewport().get_camera_3d()
	if target == Vector3.INF or cam == null:
		_arrow.visible = false
		return
	var to := target - player.global_position
	to.y = 0.0
	if to.length() < 8.0:
		_arrow.visible = false
		return
	var local := to.rotated(Vector3.UP, -cam.global_rotation.y)
	var dir := Vector2(local.x, local.z).normalized()
	var center := cam.unproject_position(player.global_position + Vector3.UP * 1.0)
	_arrow.visible = true
	_arrow.position = center + dir * 90.0 - _arrow.pivot_offset
	_arrow.rotation = dir.angle() + PI / 2.0


func show_prompt(text: String) -> void:
	_prompt.text = text


func show_message(text: String, duration: float) -> void:
	_center_label.text = text
	if _msg_tween:
		_msg_tween.kill()
	_center_label.modulate.a = 0.0
	_msg_tween = create_tween()
	_msg_tween.tween_property(_center_label, "modulate:a", 1.0, 0.2)
	_msg_tween.tween_interval(duration)
	_msg_tween.tween_property(_center_label, "modulate:a", 0.0, 0.5)


func _on_hp(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_label.text = "%d / %d" % [hp, max_hp]


func _on_xp(xp: int, xp_next: int, level: int) -> void:
	_xp_bar.max_value = xp_next
	_xp_bar.value = xp
	_level_label.text = str(level)


# --- fabrique de widgets ---
static func style(color := PANEL) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	sb.border_color = Color(ACCENT, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


static func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Control, color: Color, height: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(height / 2)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(height / 2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	parent.add_child(b)
	return b
