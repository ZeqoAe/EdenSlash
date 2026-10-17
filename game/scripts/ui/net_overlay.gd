class_name NetOverlay
extends Control
## Bandeau réseau du Mode amis (lot NET-A) : en haut à gauche, rôle, joueurs, ping et débit (une ligne) ; F11 déplie le
## détail (retard d'entrée, retard ressenti, instantanés, images par seconde, profil de l'instance). Au centre en haut, les
## annonces (« Léa a rejoint la partie »). En bas, l'aide des touches. Ne capte jamais la souris.

const KEY := KEY_F11

var detailed := false
var _chip: PanelContainer
var _line: Label
var _detail: Label
var _toast: Label
var _toast_tw: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip = PanelContainer.new()
	UiTheme.paper(_chip, 4, Vector2(14, 8), 12)
	_chip.position = Vector2(16, 14)
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chip.add_child(v)
	_line = Hud._label(v, "", 16, UiTheme.TEXT)
	_detail = Hud._label(v, "", 14, UiTheme.MUTED)
	_detail.visible = false
	_toast = Hud._label(self, "", 22, UiTheme.GOLD)
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.offset_top = 70.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.modulate.a = 0.0
	var help := Hud._label(self, "Échap : menu · F11 : détails réseau", 14, UiTheme.TEXT)
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 16.0
	help.offset_top = -40.0
	help.offset_bottom = -14.0
	help.add_theme_constant_override("outline_size", 6)


## [param line] : la ligne toujours visible ; [param detail] : le détail (F11).
func set_text(line: String, detail: String) -> void:
	_line.text = line
	_detail.text = detail
	_detail.visible = detailed and detail != ""


func toast(text: String) -> void:
	_toast.text = text
	if _toast_tw and _toast_tw.is_valid():
		_toast_tw.kill()
	_toast.modulate.a = 1.0
	_toast_tw = create_tween()
	_toast_tw.tween_interval(3.0)
	_toast_tw.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY:
		detailed = not detailed
		_detail.visible = detailed and _detail.text != ""
		get_viewport().set_input_as_handled()
