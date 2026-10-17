class_name RoyaleTarget
extends PanelContainer
## Cadre de cible du Battle royale dans la DA v2 (lot BR-I3, backlog P1 n° 16 et 18) : en haut au centre, un autocollant
## de papier contouré d'encre (Bible § 5) : tuile de la classe aux couleurs de sa famille avec son icône, nom et niveau,
## force relative (« ▲ plus fort », « ▼ plus faible », « = égal » : niveau et équipement, à PV pleins), étoile du mis à
## prix, jauge de vie deux tons (fraise, trace claire des dégâts) avec les PV en chiffres contourés, effets en cours.
## Remplace le cadre commun de Hud (même cible : verrouillée, sinon le héros le plus proche) ; mis à jour par RoyaleHud.

const W := 380.0
const STRONGER := 1.3  # rapport de forces à PV pleins au-dessus duquel la cible est « plus forte »
const WEAKER := 0.77

var target: Combatant
var _tile: Control
var _icon: TextureRect
var _name: Label
var _level: Label
var _force_box: PanelContainer
var _force: Label
var _star: Label
var _gauge: Control
var _row: HudWidgets.StatusRow
var _ratio := 1.0
var _trail := 1.0
var _hp_text := ""
var _tones: Array = RoyaleHudStyle.SUN
var _force_key := ""
var _durations := {}


func _init() -> void:
	name = "RoyaleTarget"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", RoyaleHudStyle.box("papier", Vector2(12, 7), 5, 16))
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -W * 0.5
	offset_right = W * 0.5
	offset_top = 10.0
	custom_minimum_size = Vector2(W, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	_tile = Control.new()
	_tile.custom_minimum_size = Vector2(32, 32)
	_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tile.draw.connect(_draw_tile)
	head.add_child(_tile)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.position = Vector2(4, 3)
	_icon.size = Vector2(23, 23)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tile.add_child(_icon)
	_name = RoyaleHudStyle.label(head, "", 18, RoyaleHudStyle.INK, RoyaleHudStyle.text_font(), true)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_star = RoyaleHudStyle.label(head, "★", 22, RoyaleHudStyle.SUN[1], RoyaleHudStyle.title_font())
	_star.visible = false
	_force_box = PanelContainer.new()
	_force_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_force_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_force_box)
	_force = RoyaleHudStyle.label(_force_box, "", 15, RoyaleHudStyle.WHITE)
	var lv_box := PanelContainer.new()
	lv_box.add_theme_stylebox_override("panel", RoyaleHudStyle.box("nuit", Vector2(8, 1), 2, 10))
	lv_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(lv_box)
	_level = RoyaleHudStyle.label(lv_box, "", 16, RoyaleHudStyle.PAPER, RoyaleHudStyle.num_font())
	_gauge = Control.new()
	_gauge.custom_minimum_size = Vector2(0, 24)
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	v.add_child(_gauge)
	_row = HudWidgets.StatusRow.new(false, 24.0, false)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_row)
	visible = false


## Rapport de forces à PV pleins de [param t] contre [param p] (niveau et équipement : PV max × frappe).
static func force_of(t: Combatant, p: Combatant) -> float:
	if t == null or p == null:
		return 1.0
	return (t.max_hp * Royale.strike(t)) / maxf(p.max_hp * Royale.strike(p), 0.001)


## Texte et tons de la force relative : [texte, tons] (« ▲ plus fort » danger, « ▼ plus faible » sûr, « = égal » papier).
static func force_label(ratio: float) -> Array:
	if ratio >= STRONGER:
		return ["▲ plus fort", RoyaleHudStyle.danger()]
	if ratio <= WEAKER:
		return ["▼ plus faible", RoyaleHudStyle.safe()]
	return ["= égal", RoyaleHudStyle.COMMON]


## Montre [param t] (null : rien) ; [param p] : le joueur, [param bounty] : le mis à prix.
func show_target(t: Combatant, p: Player, bounty: Combatant) -> void:
	if t == null or not is_instance_valid(t) or t.is_dead:
		visible = false
		target = null
		return
	var fresh := t != target
	target = t
	visible = true
	var ratio := t.hp / maxf(t.max_hp, 1.0)
	if fresh:
		_trail = ratio
		var cid := String(t.get_meta("royale", {}).get("cid", ""))
		_tones = RoyaleHudStyle.family_tones(cid)
		_icon.texture = UiTheme.texture(String(GameData.class_data(cid).get("icon", ""))) if cid != "" else null
		_tile.queue_redraw()
		_durations.clear()
	var nm := t.display_name.get_slice(" ·", 0).trim_prefix("<Duel> ").trim_prefix("<Boss> ")
	if _name.text != nm:
		_name.text = nm
	var lv := "niv. %d" % t.level
	if _level.text != lv:
		_level.text = lv
	_star.visible = t == bounty
	var fl := force_label(force_of(t, p)) if Combatant.is_hero(t) else ["", RoyaleHudStyle.COMMON]
	var key := String(fl[0]) + str(RoyaleHudStyle.colorblind())
	if key != _force_key:
		_force_key = key
		_force.text = String(fl[0])
		_force_box.visible = String(fl[0]) != ""
		var tones: Array = fl[1]
		_force_box.add_theme_stylebox_override("panel", _pill(tones[1]))
		var paper := tones == RoyaleHudStyle.COMMON
		_force.add_theme_color_override("font_color", RoyaleHudStyle.INK if paper else RoyaleHudStyle.WHITE)
		_force.add_theme_constant_override("outline_size", 0 if paper else RoyaleHudStyle.outline_for(15) * 2)
	var hp := "%s / %s" % [Hud._big_number(minf(ceilf(t.hp), ceilf(t.max_hp))), Hud._big_number(ceilf(t.max_hp))]
	_trail = move_toward(_trail, ratio, get_process_delta_time() * 0.5) if _trail > ratio else ratio
	if absf(ratio - _ratio) > 0.001 or hp != _hp_text or _trail > ratio + 0.001:
		_ratio = ratio
		_hp_text = hp
		_gauge.queue_redraw()
	_sync_statuses(t)


static func _pill(fill: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = RoyaleHudStyle.INK
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.anti_aliasing = true
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 0
	sb.content_margin_bottom = 1
	return sb


func _sync_statuses(t: Combatant) -> void:
	var effects: Array = []
	for st in t.statuses:
		var left := float(t.statuses[st]) - t.clock
		if left > 0.0 and Combatant.STATUS_INFO.has(st) and not String(st).begins_with("imm_"):
			var end := float(t.statuses[st])
			var rec: Array = _durations.get(st, [-1.0, 1.0])
			if absf(end - float(rec[0])) > 0.05:
				rec = [end, maxf(left, 0.1) if end > float(rec[0]) else float(rec[1])]
				_durations[st] = rec
			effects.append({"id": st, "left": left, "total": float(rec[1])})
	_row.sync(effects)
	_row.visible = not effects.is_empty()


func _draw_tile() -> void:
	RoyaleHudStyle.draw_sticker(_tile, Rect2(Vector2.ZERO, _tile.size - Vector2(2, 2)), _tones[1], 9.0, 2.0, 2.0)


func _draw_gauge() -> void:
	var r := Rect2(Vector2.ZERO, _gauge.size - Vector2(3, 3))
	var tones := RoyaleHudStyle.danger()
	RoyaleHudStyle.draw_sticker(_gauge, r, RoyaleHudStyle.WELL, minf(12.0, r.size.y * 0.5), 3.0)
	var inner := r.grow(-3.0)
	if _trail > _ratio:  # trace claire des dégâts (Bible § 5)
		_gauge.draw_rect(Rect2(inner.position + Vector2(inner.size.x * _ratio, 0), Vector2(inner.size.x * (_trail - _ratio), inner.size.y)), Color(1, 1, 1, 0.75))
	var w := inner.size.x * clampf(_ratio, 0.0, 1.0)
	if w >= 1.0:
		var top := inner.size.y * 0.3
		_gauge.draw_rect(Rect2(inner.position, Vector2(w, top)), tones[0])
		_gauge.draw_rect(Rect2(inner.position + Vector2(0, top), Vector2(w, inner.size.y - top)), tones[1])
		if w < inner.size.x - 1.0:
			_gauge.draw_line(Vector2(inner.position.x + w, inner.position.y), Vector2(inner.position.x + w, inner.end.y), RoyaleHudStyle.INK, 2.0)
	RoyaleHudStyle.draw_text(_gauge, Vector2(r.position.x, r.get_center().y + 15 * 0.36), _hp_text, 15, RoyaleHudStyle.WHITE,
		RoyaleHudStyle.num_font(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Textes du cadre (tests) : {name, level, force, hp}.
func texts() -> Dictionary:
	return {"name": _name.text, "level": _level.text, "force": _force.text if _force_box.visible else "", "hp": _hp_text, "star": _star.visible}
