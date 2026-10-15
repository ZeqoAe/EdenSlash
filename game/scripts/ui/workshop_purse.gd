class_name WorkshopPurse
extends HBoxContainer
## Bourse commune de l'Atelier (en-tête de l'écran, quel que soit l'onglet) : insignes pour acquérir
## (Armurerie), cristaux pour optimiser (Fabrication, Forge). Se met à jour seule.

var _insignia: Label
var _crystals: Label
var _since := 0.0


func _init() -> void:
	add_theme_constant_override("separation", 14)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insignia = Hud._label(self, "", 17, UiTheme.GOLD)
	_insignia.tooltip_text = "Insignes : gagnés en Survie, ils achètent des pièces à l'Armurerie"
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
	_crystals.tooltip_text = "Cristaux : gardés d'une partie à l'autre, ils paient la forge et la fabrication"
	_crystals.mouse_filter = Control.MOUSE_FILTER_PASS
	refresh()


func refresh() -> void:
	var c := Profile.amount("crystal")
	_insignia.text = "%s insignes" % GearPower.fmt(Profile.insignia)
	_crystals.text = "%s %s" % [GearPower.fmt(c), "cristal" if c < 2 else "cristaux"]


func _process(delta: float) -> void:
	_since += delta
	if _since >= 0.25 and is_visible_in_tree():
		_since = 0.0
		refresh()
