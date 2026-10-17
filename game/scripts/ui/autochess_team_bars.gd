class_name AutochessTeamBars
extends PanelContainer
## L'Échiquier, lot AC-V : les deux équipes en haut de l'écran pendant le combat, comme les barres d'équipe des Arènes
## (TeamBars) : à gauche ton nom et tes unités, à droite l'adversaire ; une pastille par unité (icône de la classe dans un
## cadre de la couleur de son coût, étoiles, PV et mana, grisée à terre) ; au centre le chronomètre de la manche, l'étape,
## la « Fureur » annoncée et la vitesse. Lit le contexte de la couche d'effets du combat regardé (AutochessEffects).
## Rapport : conception/autochess/R_AC_V.md.

const MINE := Color(0.35, 0.9, 0.45)  # comme les barres au-dessus des unités (AutochessUnit.SIDE_COLORS)
const FOE := Color(0.95, 0.3, 0.28)
const MANA := Color(0.35, 0.62, 1.0)
const CHIP := Vector2(38, 62)
const CHIP_MIN := 24.0
const CENTER_W := 132.0
const REFRESH := 0.1  # s

var my_side := 0
var _ctx: Dictionary = {}
var _sides: Array = [null, null]  # HBox des pastilles, côté gauche (toi) et droit
var _names: Array = [null, null]
var _timer: Label
var _sub: Label
var _speed: Label
var _chips: Array = []  # Chip
var _t := 0.0
var _key := ""


func _init() -> void:
	name = "AcTeamBars"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", AutochessHud.box(AutochessHud.BG_SOFT, UiTheme.GOLD_DIM, 2, 12, 14, 6))
	anchor_left = 0.5
	anchor_right = 0.5
	offset_top = 6.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(h)
	for k in 2:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := AutochessHud.lbl("", 16, UiTheme.GOLD if k == 0 else FOE, "bold")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if k == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		n.clip_text = true
		v.add_child(n)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN if k == 0 else BoxContainer.ALIGNMENT_END
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(row)
		_names[k] = n
		_sides[k] = row
		if k == 1:
			h.add_child(_center())
		h.add_child(v)


func _center() -> Control:
	var c := VBoxContainer.new()
	c.custom_minimum_size.x = CENTER_W
	c.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_theme_constant_override("separation", -2)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(top)
	_timer = AutochessHud.lbl("0:00", 28, UiTheme.TEXT, "title")
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_timer)
	_speed = AutochessHud.lbl("×2", 16, UiTheme.GOLD, "bold")
	_speed.tooltip_text = "Vitesse du combat"
	top.add_child(_speed)
	_sub = AutochessHud.lbl("", 14, UiTheme.MUTED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(_sub)
	return c


## Montre le combat de contexte [param ctx] (AutochessEffects), vu du camp [param side] ; [param names] : [toi, adversaire].
func show_fight(ctx: Dictionary, side: int, names: Array) -> void:
	_ctx = ctx
	my_side = side
	for k in 2:
		(_names[k] as Label).text = String(names[k]) if k < names.size() else ""
	_rebuild()
	visible = true
	_t = 0.0


func _rebuild() -> void:
	for row in _sides:
		for ch in (row as Node).get_children():
			ch.queue_free()
	_chips = []
	if _ctx.is_empty():
		return
	var lists := [[], []]
	for fid in _ctx.units:
		var u: Dictionary = _ctx.units[fid]
		lists[0 if int(u.side) == my_side else 1].append(int(fid))
	var vw := get_viewport_rect().size.x if is_inside_tree() else 1280.0
	var n := maxi((lists[0] as Array).size(), (lists[1] as Array).size())
	var w := clampf((vw - 2.0 * 16.0 - CENTER_W - 80.0) * 0.5 / maxf(float(n), 1.0) - 3.0, CHIP_MIN, CHIP.x)
	for k in 2:
		(_names[k] as Label).custom_minimum_size.x = maxf(160.0, (w + 3.0) * float((lists[k] as Array).size()))
		for fid in lists[k]:
			var chip := Chip.new()
			chip.fid = fid
			chip.mine = k == 0
			chip.custom_minimum_size = Vector2(w, CHIP.y)
			var u: Dictionary = _ctx.units[fid]
			chip.icon = UiTheme.texture(AutochessStats.icon_path(String(u.id)))
			chip.stars = int(u.stars)
			chip.cost_col = AutochessBoard.cost_color(int(u.cost)) if String(u.monster) == "" and not bool(u.guardian) else UiTheme.HP
			chip.tooltip_text = AutochessStats.label(u)
			(_sides[k] as Node).add_child(chip)
			_chips.append(chip)
	_refresh()


## Chronomètre [param t] s, Fureur, vitesse, ligne de l'étape.
func set_clock(t: float, speed: float, stage_text: String) -> void:
	_timer.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	var fury := t >= AutochessData.SUDDEN_AT
	_timer.add_theme_color_override("font_color", UiTheme.DEBUFF if fury else UiTheme.TEXT)
	_sub.text = "Fureur" if fury else stage_text
	_sub.add_theme_color_override("font_color", UiTheme.DEBUFF if fury else UiTheme.MUTED)
	_sub.tooltip_text = "Les coups font de plus en plus mal, les soins faiblissent." if fury else ""
	_speed.visible = speed > 1.0
	_speed.text = "×%d" % int(speed)


func _process(delta: float) -> void:
	if not visible:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = REFRESH
	_refresh()


func _refresh() -> void:
	if _ctx.is_empty():
		return
	for c in _chips:
		var chip := c as Chip
		if not _ctx.units.has(chip.fid):
			continue
		var u: Dictionary = _ctx.units[chip.fid]
		chip.alive = bool(u.alive)
		chip.hp = clampf(float(u.hp) / maxf(float(u.hp_max), 1.0), 0.0, 1.0) if chip.alive else 0.0
		var need := AutochessEffects.mana_needed(_ctx, chip.fid)
		chip.mana = clampf(float(u.mana) / maxf(need, 1.0), 0.0, 1.0) if need < INF and chip.alive else 0.0
		chip.queue_redraw()


## Pastille d'une unité : icône dans un cadre de la couleur du coût, étoiles, PV, mana.
class Chip extends Control:
	var fid := -1
	var mine := true
	var icon: Texture2D
	var stars := 1
	var cost_col := Color.WHITE
	var hp := 1.0
	var mana := 0.0
	var alive := true

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var w := size.x
		var star_h := 13.0
		var pic := Rect2(1.0, star_h, w - 2.0, w - 2.0)
		draw_rect(pic, Color(0.04, 0.04, 0.1, 0.9))
		if icon != null:
			draw_texture_rect(icon, pic.grow(-2.0), false, Color(1, 1, 1, 1.0 if alive else 0.3))
		draw_rect(pic, Color(cost_col, 1.0 if alive else 0.35), false, 2.0)
		if not alive:
			draw_line(pic.position + Vector2(5, 5), pic.end - Vector2(5, 5), Color(UiTheme.DEBUFF, 0.85), 2.0)
			draw_line(Vector2(pic.end.x - 5, pic.position.y + 5), Vector2(pic.position.x + 5, pic.end.y - 5), Color(UiTheme.DEBUFF, 0.85), 2.0)
		var font := UiTheme.bold_font()
		var st := "★".repeat(clampi(stars, 1, 3))
		var fs := 12
		var sw := font.get_string_size(st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(font, Vector2((w - sw) * 0.5, star_h - 2.0), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(UiTheme.INK, 0.9))
		draw_string(font, Vector2((w - sw) * 0.5, star_h - 2.0), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			AutochessBoard.STAR_COLORS[clampi(stars, 1, 3) - 1])
		var y := pic.end.y + 2.0
		draw_rect(Rect2(1.0, y, w - 2.0, 5.0), Color(0.08, 0.08, 0.13, 0.95))
		draw_rect(Rect2(1.0, y, (w - 2.0) * hp, 5.0), AutochessTeamBars.MINE if mine else AutochessTeamBars.FOE)
		draw_rect(Rect2(1.0, y + 6.0, w - 2.0, 3.0), Color(0.08, 0.08, 0.13, 0.95))
		draw_rect(Rect2(1.0, y + 6.0, (w - 2.0) * mana, 3.0), AutochessTeamBars.MANA)
