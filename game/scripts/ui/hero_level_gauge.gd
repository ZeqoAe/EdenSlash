class_name HeroLevelGauge
extends HBoxContainer
## Petite jauge du niveau de héros (lot H1) : « Niv. 34 » et une barre d'XP fine, détail en infobulle. Se met à jour seule
## (à l'affichage et à chaque gain). Sert au badge du lobby et à l'en-tête de l'écran Héros.

var _label: Label
var _bar: ProgressBar
var _font_size := 14
var _bar_w := 150.0
var _prefix := "Niv."


## [param prefix] : « Niv. » (écran Héros) ou « Héros niv. » (badge de classe du lobby : ne pas le prendre pour la maîtrise).
func _init(font_size := 14, bar_width := 150.0, prefix := "Niv.") -> void:
	_font_size = font_size
	_bar_w = bar_width
	_prefix = prefix
	name = "HeroLevelGauge"
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_PASS  # l'infobulle ; le clic passe au parent (badge du lobby)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label = Hud._label(self, "", _font_size, UiTheme.GOLD)
	_label.add_theme_font_override("font", UiTheme.bold_font())
	_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.custom_minimum_size = Vector2(_bar_w, 8)
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_bar.add_theme_stylebox_override("background", UiTheme.flat_box(Color(0.03, 0.03, 0.08, 0.9), MenuWidgets.LINE, 1, 4, false))
	_bar.add_theme_stylebox_override("fill", UiTheme.flat_box(UiTheme.GOLD, UiTheme.GOLD, 0, 4, false))
	add_child(_bar)


func _enter_tree() -> void:
	if not HeroLevel.events.xp_changed.is_connected(_on_xp):
		HeroLevel.events.xp_changed.connect(_on_xp)
	refresh()


func _exit_tree() -> void:
	if HeroLevel.events.xp_changed.is_connected(_on_xp):
		HeroLevel.events.xp_changed.disconnect(_on_xp)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		refresh()


func _on_xp(_total: float) -> void:
	refresh()


func refresh() -> void:
	if _label == null:
		return
	_label.text = "%s %d" % [_prefix, HeroLevel.level()]
	_bar.value = HeroLevel.progress()
	tooltip_text = HeroLevel.tooltip()
	_label.tooltip_text = tooltip_text
	_bar.tooltip_text = tooltip_text
