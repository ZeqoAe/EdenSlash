class_name Hud
extends CanvasLayer
## HUD de la run, style or sur indigo (UiTheme) :
## - bas : orbe de vie, 4 compétences (recharge circulaire), esquive, orbe d'expérience
##   (niveau au centre), indicateur de combo ; buffs à gauche et debuffs à droite au-dessus ;
## - haut gauche : objectifs repliés (zone, chrono, sceaux), dépliés avec [Tab] et quelques
##   secondes à chaque découverte ;
## - haut centre : cible (PV, niveau, effets) ; haut droite : mini-carte ronde.

const ACCENT := UiTheme.GOLD
const PANEL := Color(0.07, 0.06, 0.12, 0.82)
const OBJECTIVE_AUTO_SHOW := 5.0  # s de dépliage automatique après une découverte

var player: Player
var director: RunDirector
var minimap: Minimap

var _hp_orb: HudWidgets.Orb
var _xp_orb: HudWidgets.Orb
var _slots: Array[HudWidgets.SkillSlot] = []
var _dodge: HudWidgets.SkillSlot
var _combo: HudWidgets.ComboMeter
var _buff_row: HudWidgets.StatusRow
var _debuff_row: HudWidgets.StatusRow
var _durations := {}  # "cible:effet" -> [fin, durée totale]
var _last_level := 0

var _obj_panel: PanelContainer
var _zone_label: Label
var _clock_label: Label
var _seal_label: Label
var _obj_details: VBoxContainer
var _obj_lines: Array[Label] = []
var _obj_hint: Label
var _obj_pinned := false
var _obj_show_until := 0.0
var _obj_signature := ""
var _zone_text := ""

var _target_box: PanelContainer
var _target_name: Label
var _target_tag: Label
var _target_bar: ProgressBar
var _target_trail: ProgressBar
var _target_row: HudWidgets.StatusRow
var _target_ref: WeakRef

var _center_label: Label
var _prompt_box: PanelContainer
var _better_box: PanelContainer  # objet ramassé meilleur que la pièce portée : [G] Équiper
var _better_label: RichTextLabel
var better_item: Dictionary = {}
var _better_until := 0.0
var _prompt: Label
var _fps_label: Label
var _arrow: Label
var _big_map: Minimap
var _msg_tween: Tween
var _clock := 0.0
var _low_hp: TextureRect
var _root: Control


func setup(p: Player, d: RunDirector) -> void:
	player = p
	director = d
	_build()
	player.health_changed.connect(_on_hp)
	player.xp_changed.connect(_on_xp)
	player.skills_changed.connect(_refresh_skills)
	Settings.changed.connect(_refresh_skills)
	director.zone_changed.connect(func(z): _zone_text = "%s · Nv %d-%d" % [z.name, z.levels[0], z.levels[1]])
	director.message.connect(show_message)
	director.better_item.connect(show_better)
	_on_hp(player.hp, player.max_hp)
	_on_xp(player.xp, GameData.xp_to_next(player.level), player.level)
	_refresh_skills()


func _build() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # se masque sous les menus qui mettent le jeu en pause
	var root := Control.new()
	_root = root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# liseré rouge sur les bords de l'écran quand la vie est basse
	_low_hp = TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.05, 1.05)
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.7, 0.0, 0.05, 0.0))
	grad.gradient.set_color(1, Color(0.75, 0.0, 0.05, 0.9))
	grad.gradient.add_point(0.5, Color(0.7, 0.0, 0.05, 0.0))
	_low_hp.texture = grad
	_low_hp.set_anchors_preset(Control.PRESET_FULL_RECT)
	_low_hp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_low_hp.stretch_mode = TextureRect.STRETCH_SCALE
	_low_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_low_hp.modulate.a = 0.0
	root.add_child(_low_hp)
	# NB : root n'est ajouté qu'à la fin, pour que les positions ancrées
	# (centre, bas, droite) soient relatives à l'ancre.
	_build_objectives(root)
	_build_minimap(root)
	_build_target(root)
	_build_action_bar(root)

	# --- messages (centre) ---
	_center_label = _label(root, "", 40, ACCENT)
	_center_label.set_anchors_preset(Control.PRESET_CENTER)
	_center_label.position = Vector2(-560, -240)
	_center_label.size = Vector2(1120, 150)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.pivot_offset = _center_label.size * 0.5
	UiTheme.title(_center_label, 40)
	_center_label.modulate.a = 0.0

	# --- invite d'interaction ([F] Ouvrir...) ---
	_prompt_box = PanelContainer.new()
	_prompt_box.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.06, 0.04, 0.1, 0.9), UiTheme.GOLD, 2, 18))
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_box.position = Vector2(0, -270)
	root.add_child(_prompt_box)
	_prompt = _label(_prompt_box, "", 20, Color.WHITE)
	_prompt_box.visible = false

	_better_box = PanelContainer.new()
	_better_box.add_theme_stylebox_override("panel", UiTheme.flat_box(Color(0.05, 0.1, 0.06, 0.92), Color(0.45, 1.0, 0.5), 2, 12))
	_better_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_better_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_better_box.custom_minimum_size = Vector2(420, 0)
	_better_box.offset_left = -210
	_better_box.offset_right = 210
	_better_box.offset_top = -205
	_better_box.offset_bottom = -150
	root.add_child(_better_box)
	_better_label = RichTextLabel.new()
	_better_label.bbcode_enabled = true
	_better_label.fit_content = true
	_better_label.scroll_active = false
	_better_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_better_label.add_theme_font_size_override("normal_font_size", 15)
	_better_box.add_child(_better_label)
	_better_box.visible = false

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


# --- objectifs (haut gauche) -------------------------------------------------------------
func _build_objectives(root: Control) -> void:
	_obj_panel = PanelContainer.new()
	_obj_panel.add_theme_stylebox_override("panel", UiTheme.panel_box(18, 12))
	_obj_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_panel.position = Vector2(14, 12)
	_obj_panel.custom_minimum_size = Vector2(330, 0)
	root.add_child(_obj_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_obj_panel.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	_zone_label = _label(head, "", 15, ACCENT)
	UiTheme.title(_zone_label, 15)
	_zone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock_label = _label(head, "", 16, Color.WHITE)
	_clock_label.add_theme_font_override("font", UiTheme.bold_font())
	var sub := HBoxContainer.new()
	v.add_child(sub)
	_seal_label = _label(sub, "", 14, Color(0.85, 0.75, 1.0))
	_seal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_obj_hint = _label(sub, "", 12, Color(1, 1, 1, 0.5))
	_obj_details = VBoxContainer.new()
	_obj_details.add_theme_constant_override("separation", 3)
	v.add_child(_obj_details)
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	var line := StyleBoxLine.new()
	line.color = Color(UiTheme.GOLD_DIM, 0.7)
	line.thickness = 1
	sep.add_theme_stylebox_override("separator", line)
	_obj_details.add_child(sep)
	for i in 5:
		var l := _label(_obj_details, "", 14, Color.WHITE)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		_obj_lines.append(l)
	_obj_details.visible = false


func _update_objectives() -> void:
	var rage := director.state == "rage"
	_zone_label.text = _zone_text
	var t := director.time_left()
	match director.state:
		"boss":
			_clock_label.text = "BOSS"
		"cleared":
			_clock_label.text = "Victoire"
		"rage":
			_clock_label.text = "RAGE !"
		_:
			_clock_label.text = "⏳ %02d:%02d" % [int(t) / 60, int(t) % 60]
	_clock_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if rage or t < 60.0 else Color.WHITE)
	var need: int = director.SEALS_NEEDED
	_seal_label.text = "Sceaux  " + "◆ ".repeat(mini(director.seals, need)) + "◇ ".repeat(maxi(0, need - director.seals))
	var chests_total: int = director.map.chests.size() if director.map and "chests" in director.map else 0
	var sig := "%s|%s|%d|%d|%d" % [director.state, director.dungeon_found, director.seals, director.chests_opened, director.shrines_captured]
	if _obj_signature != "" and sig != _obj_signature:
		_obj_show_until = _clock + OBJECTIVE_AUTO_SHOW  # nouvelle découverte : on déplie un instant
	_obj_signature = sig
	var open := _obj_pinned or _clock < _obj_show_until
	_obj_details.visible = open
	_obj_hint.text = "[%s] %s" % [Settings.action_label("objectives", 1), "replier" if _obj_pinned else "objectifs"]
	if not open:
		return
	var lines: Array[String] = []
	match director.state:
		"boss":
			lines = ["⚔ Vaincs le boss du donjon", "Évite les zones rouges ([%s] : esquive)" % Settings.action_label("dodge", 1),
				"Miroir : ne frappe pas le boss pendant 3 s", "L'onde au bord jaune se saute"]
		"cleared":
			lines = ["✔ Boss vaincu : ramasse le butin"]
		_:
			lines.append("✔ Entrée du donjon trouvée" if director.dungeon_found else "◇ Trouve l'entrée du donjon")
			lines.append("✔ Sceaux réunis : le donjon est ouvert" if director.seals >= need else "◇ Sceaux du donjon : %d / %d (gardiens d'élite)" % [director.seals, need])
			lines.append("◇ Coffres : %d / %d · prochain : %d or ou 1 clé (clés : %d)" % [director.chests_opened, chests_total, director.chest_price(), Profile.keys])
			lines.append("◇ Sanctuaires capturés : %d / %d (cartes, trophées, clés)" % [director.shrines_captured, director.map.shrines.size() if director.map else 0])
			lines.append("La rage arrive dans %02d:%02d : monstres plus forts, plus de butin" % [int(t) / 60, int(t) % 60] if not rage else "Rage : monstres plus forts, plus d'XP et de butin")
	for i in _obj_lines.size():
		var shown := i < lines.size()
		_obj_lines[i].visible = shown
		_obj_lines[i].text = lines[i] if shown else ""
		_obj_lines[i].add_theme_color_override("font_color", Color(0.55, 1.0, 0.6) if shown and lines[i].begins_with("✔") else Color(0.92, 0.9, 0.98))


# --- mini-carte ronde (haut droite) ------------------------------------------------------
func _build_minimap(root: Control) -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	holder.position = Vector2(-246, 12)
	holder.size = Vector2(230, 230)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var mask := Control.new()  # découpe ronde : seuls les pixels du disque sont gardés
	mask.size = holder.size
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.draw.connect(func(): mask.draw_circle(mask.size * 0.5, mask.size.x * 0.5 - 6.0, Color.WHITE))
	holder.add_child(mask)
	minimap = Minimap.new()
	minimap.round = true
	minimap.process_mode = Node.PROCESS_MODE_ALWAYS
	minimap.size = holder.size
	mask.add_child(minimap)
	minimap.setup(player, director)
	var ring := Control.new()
	ring.size = holder.size
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(func():
		var c := ring.size * 0.5
		var r := ring.size.x * 0.5 - 6.0
		ring.draw_arc(c, r, 0.0, TAU, 128, Color(0.04, 0.02, 0.07, 0.95), 7.0, true)
		ring.draw_arc(c, r, 0.0, TAU, 128, UiTheme.GOLD, 2.5, true)
		ring.draw_arc(c, r + 4.0, 0.0, TAU, 128, UiTheme.GOLD_DIM, 1.2, true)
		for k in 8:
			var a := TAU * k / 8.0
			HudWidgets.diamond(ring, c + Vector2(cos(a), sin(a)) * r, 5.0 if k % 2 == 0 else 3.0, UiTheme.GOLD))
	holder.add_child(ring)
	_fps_label = _label(root, "", 12, Color(1, 1, 1, 0.55))
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.position = Vector2(-150, 244)


# --- cible (haut centre) -----------------------------------------------------------------
func _build_target(root: Control) -> void:
	_target_box = PanelContainer.new()
	_target_box.add_theme_stylebox_override("panel", UiTheme.panel_box(18, 10))
	_target_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_target_box.position = Vector2(-190, 12)
	_target_box.custom_minimum_size = Vector2(380, 0)
	root.add_child(_target_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_target_box.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_target_name = _label(head, "", 16, Color.WHITE)
	_target_name.add_theme_font_override("font", UiTheme.bold_font())
	_target_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_tag = _label(head, "", 13, ACCENT)
	var bars := Control.new()
	bars.custom_minimum_size = Vector2(0, 12)
	v.add_child(bars)
	_target_trail = _bar(bars, Color(1, 0.9, 0.75, 0.6), 12)
	_target_trail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_bar = _bar(bars, Color(0.86, 0.18, 0.24), 12)
	_target_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_target_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	_target_row = HudWidgets.StatusRow.new(false, 24.0, false)
	_target_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_target_row)
	_target_box.visible = false


# --- barre d'action (bas) ----------------------------------------------------------------
func _build_action_bar(root: Control) -> void:
	var bottom := Control.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-450, -204)
	bottom.size = Vector2(900, 196)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom)
	var bar := Panel.new()
	bar.add_theme_stylebox_override("panel", UiTheme.panel_box())
	bar.position = Vector2(150, 104)
	bar.size = Vector2(600, 82)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(bar)
	_hp_orb = HudWidgets.Orb.new()
	_hp_orb.position = Vector2(30, 56)
	_hp_orb.size = Vector2(136, 136)
	_hp_orb.pulse_low = true
	bottom.add_child(_hp_orb)
	_xp_orb = HudWidgets.Orb.new()
	_xp_orb.position = Vector2(734, 56)
	_xp_orb.size = Vector2(136, 136)
	_xp_orb.top_color = Color(1.0, 0.85, 0.4)
	_xp_orb.bottom_color = Color(0.55, 0.32, 0.04)
	_xp_orb.caption = "NIVEAU"
	_xp_orb.big_font = UiTheme.title_font()
	_xp_orb.big_size = 38
	bottom.add_child(_xp_orb)
	var x0 := 266.0
	for i in 4:
		var s := HudWidgets.SkillSlot.new()
		s.position = Vector2(x0 + i * 76.0, 114)
		s.size = Vector2(62, 62)
		bottom.add_child(s)
		_slots.append(s)
	_dodge = HudWidgets.SkillSlot.new()
	_dodge.round = true
	_dodge.empty = false
	_dodge.icon = UiTheme.texture("res://assets/ui/status/haste.png")
	_dodge.position = Vector2(x0 + 4 * 76.0 + 10.0, 120)
	_dodge.size = Vector2(50, 50)
	_dodge.tooltip_text = "Esquive (invulnérable)"
	bottom.add_child(_dodge)
	_combo = HudWidgets.ComboMeter.new()
	_combo.position = Vector2(300, 78)
	_combo.size = Vector2(300, 26)
	bottom.add_child(_combo)
	_buff_row = HudWidgets.StatusRow.new(true)
	_buff_row.position = Vector2(30, 0)
	_buff_row.size = Vector2(400, 54)
	bottom.add_child(_buff_row)
	_debuff_row = HudWidgets.StatusRow.new(false)
	_debuff_row.alignment = BoxContainer.ALIGNMENT_END
	_debuff_row.position = Vector2(470, 0)
	_debuff_row.size = Vector2(400, 54)
	bottom.add_child(_debuff_row)


func _refresh_skills() -> void:
	for i in 4:
		var s := player.skill_in_slot(i)
		var slot := _slots[i]
		slot.key_text = Settings.action_label("skill_%d" % (i + 1), 1)
		slot.auto = Settings.auto_skill(i)
		slot.empty = s.is_empty()
		slot.icon = null if s.is_empty() else UiTheme.texture(String(s.icon))
		slot.rank = Run.skill_rank(int(s.id)) if not s.is_empty() else 1
		if s.is_empty():
			slot.tooltip_text = "Emplacement libre : les compétences s'obtiennent avec les cartes de niveau."
		else:
			slot.tooltip_text = "%s — rang %d\n%s\nRecharge : %.1f s" % [s.name, slot.rank, s.desc, player.skill_cooldown(s)]
	_dodge.key_text = Settings.action_label("dodge", 1)


func _process(delta: float) -> void:
	if player == null:
		return
	if _better_box.visible and Time.get_ticks_msec() / 1000.0 > _better_until:
		_better_box.visible = false
	_root.visible = not _menu_open()
	if not _root.visible:
		return
	_clock += delta
	# vie basse : bords de l'écran qui pulsent en rouge
	var hp_ratio := player.hp / maxf(player.max_hp, 1.0)
	_low_hp.modulate.a = 0.0 if hp_ratio >= 0.3 or player.is_dead else (0.5 + 0.5 * (1.0 - hp_ratio / 0.3)) * (0.65 + 0.35 * sin(_clock * 6.0))
	_fps_label.visible = Settings.get_v("interface", "show_fps")
	_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	for i in 4:
		var s := player.skill_in_slot(i)
		_slots[i].set_cooldown(player.cooldown_left(i), player.skill_cooldown(s) if not s.is_empty() else 1.0)
	var dc := player.dodge_cooldown()
	_dodge.set_cooldown(dc.x, dc.y)
	var cs := player.combo_state()
	_combo.set_state(cs.x, cs.y)
	_update_statuses()
	_update_target()
	_update_objectives()
	_update_arrow()


# --- buffs / debuffs -----------------------------------------------------------------------
func _update_statuses() -> void:
	var buffs: Array = []
	var debuffs: Array = []
	for st in player.statuses:
		var left := float(player.statuses[st]) - player.clock
		if left <= 0.0 or not Combatant.STATUS_INFO.has(st):
			continue
		var e := {"id": st, "left": left, "total": _total("p", st, float(player.statuses[st]), left)}
		if StatusDb.is_buff(st):
			buffs.append(e)
		else:
			debuffs.append(e)
	var flow := player.flow_state()
	if flow.x > 0:
		buffs.append({"id": "flow", "left": flow.y, "total": 3.0, "stacks": int(flow.x)})
	var stun := player.stun_left()
	if stun > 0.0:
		debuffs.append({"id": "stun", "left": stun, "total": _total("p", "stun_state", player.clock + stun, stun)})
	_buff_row.sync(buffs)
	_debuff_row.sync(debuffs)


## Durée totale d'un effet (pour le balayage) : retenue quand il apparaît ou est prolongé.
func _total(who: String, st: String, end: float, left: float) -> float:
	var key := who + ":" + st
	var rec: Array = _durations.get(key, [-1.0, 1.0])
	if absf(end - float(rec[0])) > 0.05:
		rec = [end, maxf(left, 0.1) if end > float(rec[0]) else float(rec[1])]
		_durations[key] = rec
	return float(rec[1])


# --- cible -------------------------------------------------------------------------------
func _update_target() -> void:
	var t := player.current_target()
	if t == null:
		t = player.nearest_monster(9.0)
	if t == null:
		_target_box.visible = false
		return
	var prev: Object = _target_ref.get_ref() if _target_ref else null
	var ratio := t.hp / maxf(t.max_hp, 1.0)
	if prev != t:
		_target_ref = weakref(t)
		_target_trail.value = ratio
	_target_box.visible = true
	_target_name.text = t.display_name
	var m := t as Monster
	var tag := "Nv %d" % t.level
	if m and m.is_boss:
		tag = "BOSS · " + tag
	elif m and m.is_elite:
		tag = "Élite · " + tag
	_target_tag.text = tag
	_target_tag.add_theme_color_override("font_color", Color(0.85, 0.45, 1.0) if m and m.is_boss else (Color(1.0, 0.6, 0.2) if m and m.is_elite else ACCENT))
	_target_bar.max_value = 1.0
	_target_trail.max_value = 1.0
	_target_bar.value = ratio
	if _target_trail.value > ratio:
		_target_trail.value = move_toward(_target_trail.value, ratio, get_process_delta_time() * 0.5)
	else:
		_target_trail.value = ratio
	var effects: Array = []
	var id := str(t.get_instance_id())
	for st in t.statuses:
		var left := float(t.statuses[st]) - t.clock
		if left > 0.0 and Combatant.STATUS_INFO.has(st):
			effects.append({"id": st, "left": left, "total": _total(id, st, float(t.statuses[st]), left)})
	_target_row.sync(effects)


## Menu pause, marchand ou bilan ouvert : le HUD laisse la place (le choix de cartes le garde).
func _menu_open() -> bool:
	if not get_tree().paused:
		return false
	var w := get_parent()
	for key in ["pause_menu", "merchant_ui"]:
		var menu = w.get(key) if w else null
		if menu and menu.has_method("is_open") and menu.is_open():
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event.is_action_pressed("map"):
		_big_map.visible = not _big_map.visible
	elif event.is_action_pressed("objectives"):
		_obj_pinned = not _obj_pinned
		_obj_show_until = 0.0


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


## Objet ramassé meilleur que la pièce portée : 8 s pour l'équiper avec [G].
func show_better(item: Dictionary) -> void:
	better_item = item
	_better_until = Time.get_ticks_msec() / 1000.0 + 8.0
	var c := Items.compare_to_equipped(item)
	_better_label.text = "[img=34x34]%s[/img]  [b][color=#%s]%s[/color][/b]  [color=#7fe08a]▲ %+d %%[/color]\n[color=#c8c8d4]Meilleur que ta pièce portée — [b]%s[/b] : équiper[/color]" % [
		String(item.get("icon", "")), Items.color_of(item).to_html(false), Items.display_name(item), roundi(c * 100.0), Settings.action_label("quick_equip", 1)]
	_better_box.visible = true


## [G] : équipe l'objet signalé (s'il est encore dans le sac).
func quick_equip() -> bool:
	if better_item.is_empty() or not _better_box.visible:
		return false
	if Profile.inventory.any(func(x): return is_same(x, better_item)):
		Profile.equip(better_item)
		show_message("Équipé : %s" % Items.display_name(better_item), 1.5)
	better_item = {}
	_better_box.visible = false
	return true


func show_prompt(text: String) -> void:
	_prompt.text = text
	_prompt_box.visible = text != ""
	_prompt_box.reset_size()
	# ancré en bas au centre : décalages relatifs à l'ancre
	_prompt_box.offset_left = -_prompt_box.size.x * 0.5
	_prompt_box.offset_right = _prompt_box.size.x * 0.5


func show_message(text: String, duration: float) -> void:
	_center_label.text = text
	if _msg_tween:
		_msg_tween.kill()
	_center_label.modulate.a = 0.0
	_center_label.scale = Vector2.ONE * 1.15
	_msg_tween = create_tween()
	_msg_tween.set_parallel()
	_msg_tween.tween_property(_center_label, "modulate:a", 1.0, 0.2)
	_msg_tween.tween_property(_center_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_msg_tween.chain().tween_interval(duration)
	_msg_tween.chain().tween_property(_center_label, "modulate:a", 0.0, 0.5)


func _on_hp(hp: float, max_hp: float) -> void:
	_hp_orb.set_value(hp / maxf(max_hp, 1.0))
	_hp_orb.caption = "VIE"
	_hp_orb.big_text = str(int(hp))
	_hp_orb.small_text = "/ %d" % int(max_hp)
	_hp_orb.tooltip_text = "Vie : %d / %d" % [hp, max_hp]


func _on_xp(xp: int, xp_next: int, level: int) -> void:
	var ratio := float(xp) / maxf(float(xp_next), 1.0)
	if _last_level != 0 and level > _last_level:
		_xp_orb.flash = 1.0  # montée de niveau : éclat doré
	_xp_orb.value = clampf(ratio, 0.0, 1.0)
	_xp_orb.trail = _xp_orb.value
	_last_level = level
	_xp_orb.big_text = str(level)
	_xp_orb.small_text = "%d %%" % floori(ratio * 100.0)
	_xp_orb.tooltip_text = "Niveau %d\nExpérience : %d / %d (%d %%)" % [level, xp, xp_next, floori(ratio * 100.0)]


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
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
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
	if size >= 26:
		l.add_theme_font_override("font", UiTheme.title_font())  # grands titres en Cinzel
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
	b.step = 0.0
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
