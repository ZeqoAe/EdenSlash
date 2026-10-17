class_name HudAlert
extends Control
## Annonces à 3 niveaux d'un combat de boss (lot DNG-2, backlog BM-DNG P0-3 ; bible § 8) : au centre, au-dessus du héros,
##   0 mineure  : texte seul, contouré d'encre ;
##   1 moyenne  : bulle lagon ;
##   2 critique : bulle fraise inclinée de −3°, plus grande, et un son court (jamais de vibration pendant un télégraphe).
## Une annonce à la fois (la nouvelle remplace l'ancienne), 28 signes au plus (BossBar.SHORT), toujours dans l'écran : la
## largeur est bornée à l'écran et le texte passe à la ligne s'il le faut.

const LEVEL_TONE := ["", "lagon", "fraise"]
const LEVEL_SIZE := [24, 26, 30]
const Y_AT := 0.33  # hauteur du centre de l'annonce (part de l'écran) : au-dessus du héros, sous la barre de boss

var level := -1  # (tests) niveau de la dernière annonce
var text := ""  # (tests)
var box: PanelContainer
var _label: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	box = PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_label)
	box.modulate.a = 0.0


func show_alert(p_text: String, p_level: int, duration := 2.0) -> void:
	level = clampi(p_level, 0, 2)
	text = p_text
	var fs: int = LEVEL_SIZE[level]
	UiTheme.title(_label, fs, Color.WHITE)
	_label.add_theme_constant_override("outline_size", UiTheme.outline_for(fs) + (2 if level == 0 else 0))
	_label.text = p_text
	if level == 0:
		box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		box.add_theme_stylebox_override("panel", UiTheme.sticker(LEVEL_TONE[level], {"radius": 14, "shadow": 5, "pad": Vector2(22, 6), "gloss": true}))
	_place()
	if level == 2:
		Sfx.ui("alert_crit", -6.0, 0.9)
	elif level == 1:
		Sfx.ui("alert_mid", -12.0)
	if _tween:
		_tween.kill()
	box.modulate.a = 0.0
	box.scale = Vector2(1.18, 1.18) if level == 2 else Vector2(1.06, 1.06)
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(box, "modulate:a", 1.0, 0.12)
	_tween.tween_property(box, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(duration)
	_tween.chain().tween_property(box, "modulate:a", 0.0, 0.35)


## L'annonce est-elle à l'écran ?
func shown() -> bool:
	return box != null and box.modulate.a > 0.05


## Centrée en largeur, bornée à l'écran (passe à la ligne au besoin), inclinée en critique.
func _place() -> void:
	var vr := size if size.x > 1.0 else get_viewport_rect().size
	var room := maxf(vr.x - 120.0, 240.0)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.custom_minimum_size = Vector2.ZERO
	box.reset_size()
	var w := box.get_combined_minimum_size().x
	if w > room:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size.x = room - 50.0
		box.reset_size()
		w = box.get_combined_minimum_size().x
	var h := box.get_combined_minimum_size().y
	box.size = Vector2(w, h)
	box.position = Vector2((vr.x - w) * 0.5, vr.y * Y_AT - h * 0.5)
	box.pivot_offset = box.size * 0.5
	box.rotation_degrees = -3.0 if level == 2 else 0.0
