class_name WorkshopPurse
extends HBoxContainer
## Bourse commune de l'Atelier (en-tête de l'écran, quel que soit l'onglet) : insignes pour fabriquer
## (Fabriquer, Plans de donjon), cristaux pour optimiser (Forge). Se met à jour seule.

var _insignia: Label
var _crystals: Label
var _since := 0.0


func _init() -> void:
	add_theme_constant_override("separation", 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insignia = Hud._label(self, "", 17, UiTheme.GOLD)
	_insignia.tooltip_text = ResourceHelp.tip("insignia")
	_insignia.mouse_filter = Control.MOUSE_FILTER_PASS
	var ic := TextureRect.new()
	ic.texture = UiTheme.texture(Items.material_icon("crystal"))
	ic.custom_minimum_size = Vector2(26, 26)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ic)
	_crystals = Hud._label(self, "", 17, Color(0.75, 0.88, 1.0))
	_crystals.tooltip_text = ResourceHelp.tip("crystal")
	_crystals.mouse_filter = Control.MOUSE_FILTER_PASS
	refresh()


## Un montant qui change (achat, fabrication) défile jusqu'à sa nouvelle valeur (UiFeel.number, UIK2).
func refresh() -> void:
	UiFeel.number(_insignia, float(Profile.insignia), _fmt_insignia)
	UiFeel.number(_crystals, float(Profile.amount("crystal")), _fmt_crystals)


static func _fmt_insignia(x: float) -> String:
	return "%s insignes" % GearPower.fmt(roundi(x))


static func _fmt_crystals(x: float) -> String:
	var c := roundi(x)
	return "%s %s" % [GearPower.fmt(c), "cristal" if c < 2 else "cristaux"]


func _process(delta: float) -> void:
	_since += delta
	if _since >= 0.25 and is_visible_in_tree():
		_since = 0.0
		refresh()
