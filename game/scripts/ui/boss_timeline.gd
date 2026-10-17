class_name BossTimeline
extends PanelContainer
## Frise « À venir » d'un combat de boss (lot DNG-2, backlog BM-DNG P0-2) : à droite, sous la mini-carte et le compteur de dégâts,
## un puits d'encre de 2 à 4 lignes : la mécanique en cours (« maintenant »), puis les prochaines avec leur compte à rebours
## (« dans 6 s »), puis celles qui tombent à un seuil de PV (« à 35 % »). Tout vient du cerveau du boss (BossBrain.upcoming :
## les vrais minuteurs des briques, rien d'inventé). Affichée par défaut, réglage Paramètres > Caméra & interface
## (interface/boss_timeline). Le nombre de lignes suit la hauteur libre (jamais sur la barre de sorts).

const TOP := 384.0  # sous le compteur de dégâts cumulés (il finit vers y = 370)
const ROW_H := 44.0
const WIDTH := 210.0
const BOTTOM_KEEP := 214.0  # barre d'action en bas (Hud._build_action_bar : 204 px) et une marge
const REFRESH := 0.15

var rows_shown := 0  # (tests) lignes affichées
var _box: VBoxContainer
var _rows: Array = []  # [chip, nom, quand]
var _t := 0.0
var _brain: BossBrain


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", UiTheme.well_style(Vector2(10, 8), 16))
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -WIDTH - 16.0
	offset_right = -16.0
	offset_top = TOP
	custom_minimum_size = Vector2(WIDTH, 0)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 4)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var head := Label.new()
	head.text = "À venir"
	head.add_theme_font_override("font", UiTheme.bold_font())
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", UiTheme.color("papier.100"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(head)
	visible = false


## Réglage du joueur (affichée par défaut).
static func enabled() -> bool:
	var v = Settings.get_v("interface", "boss_timeline")
	return v == null or bool(v)


## Lignes qui tiennent entre le haut de la frise et la barre d'action (2 à 4).
func max_rows() -> int:
	var root := get_parent() as Control
	var vh: float = root.size.y if root != null and root.size.y > 0.0 else get_viewport_rect().size.y
	return clampi(int((vh - BOTTOM_KEEP - TOP - 34.0) / ROW_H), 0, 4)


## Suit le cerveau [param brain] du boss de la barre [param bar] (appelé à chaque image par BossBar).
func follow(brain: BossBrain, bar: Control) -> void:
	_brain = brain
	var n := max_rows()
	if brain == null or not enabled() or not bar.visible or n < 2:
		visible = false
		return
	_t -= get_process_delta_time()
	if _t > 0.0 and visible:
		return
	_t = REFRESH
	var list := brain.upcoming(n)
	if list.is_empty():
		visible = false
		return
	visible = true
	while _rows.size() < list.size():
		_rows.append(_make_row())
	for i in _rows.size():
		var r: Array = _rows[i]
		var on := i < list.size()
		(r[3] as Control).visible = on
		if not on:
			continue
		var e: Dictionary = list[i]
		var type := String(e.type)
		var chip: PanelContainer = r[0]
		if String(chip.get_meta("type", "")) != type:
			chip.set_meta("type", type)
			chip.add_theme_stylebox_override("panel", UiTheme.sticker(BossBar.tone_of(type), {"radius": 9, "shadow": 3, "pad": Vector2(3, 2), "gloss": false}))
			(chip.get_child(0) as TextureRect).texture = BossBar.icon_of(type)
		(r[1] as Label).text = BossBar.mech_name(type)
		(r[2] as Label).text = when_text(e)
		(r[2] as Label).add_theme_color_override("font_color", UiTheme.color("bonbon.fraise.clair") if bool(e.now) else UiTheme.MUTED)
	rows_shown = mini(list.size(), _rows.size())


## « maintenant », « dans 6 s », « à 35 % ».
static func when_text(e: Dictionary) -> String:
	if bool(e.get("now", false)):
		return "maintenant"
	if float(e.get("in", -1.0)) >= 0.0:
		var s := ceili(float(e.in))
		return "dans %d s" % s if s > 0 else "imminent"
	return "à %d %%" % roundi(float(e.get("at", 0.0)) * 100.0)


func _make_row() -> Array:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.custom_minimum_size = Vector2(0, ROW_H - 4.0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(h)
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(36, 36)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(ic)
	h.add_child(chip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nm := Label.new()
	nm.add_theme_font_override("font", UiTheme.bold_font())
	nm.add_theme_font_size_override("font_size", 15)
	nm.add_theme_color_override("font_color", UiTheme.color("papier.100"))
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var wl := Label.new()
	wl.add_theme_font_override("font", UiTheme.label_font())
	wl.add_theme_font_size_override("font_size", UiTheme.MIN_TEXT)
	wl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(wl)
	return [chip, nm, wl, h]
