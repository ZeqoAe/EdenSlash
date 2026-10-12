class_name Shrine
extends Node3D
## Zone à capturer (sanctuaire) : rester dans le cercle CAPTURE_TIME secondes pendant que
## les monstres affluent (le directeur de run les envoie). Hors du cercle, la capture
## redescend lentement. Capturée : une récompense pour la run en cours (choix de cartes,
## choix de trophées ou clés), selon [member reward].

const RADIUS := 7.0
const CAPTURE_TIME := 14.0
const REWARDS := {
	"card": {"name": "Sanctuaire des cartes", "color": Color(0.55, 0.8, 1.0), "desc": "un choix de cartes d'amélioration"},
	"trophy": {"name": "Sanctuaire des trophées", "color": Color(1.0, 0.75, 0.3), "desc": "un choix de 3 trophées"},
	"keys": {"name": "Sanctuaire des clés", "color": Color(0.6, 1.0, 0.6), "desc": "2 clés et de l'or"},
}

var reward := "card"
var progress := 0.0  # 0 → 1
var captured := false
var _ring: MeshInstance3D
var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D
var _label: Label3D
var _light: OmniLight3D


func setup(p_reward: String) -> void:
	reward = p_reward
	var col: Color = REWARDS[reward].color
	# cercle au sol (bord lumineux) et disque de progression
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RADIUS - 0.25
	torus.outer_radius = RADIUS
	torus.rings = 48
	_ring.mesh = torus
	_ring.material_override = _glow(col, 1.0)
	_ring.position.y = 0.15
	add_child(_ring)
	_fill = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = RADIUS - 0.3
	disk.bottom_radius = RADIUS - 0.3
	disk.height = 0.04
	disk.radial_segments = 48
	_fill.mesh = disk
	_fill_mat = _glow(col, 0.0)
	_fill.material_override = _fill_mat
	_fill.position.y = 0.1
	add_child(_fill)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.light_energy = 1.2
	_light.omni_range = RADIUS * 1.6
	_light.position.y = 3.0
	add_child(_light)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.001
	_label.font_size = 28
	_label.outline_size = 9
	_label.modulate = col.lightened(0.3)
	_label.position.y = 4.2
	_label.visibility_range_end = 70.0
	add_child(_label)
	update_visual()


static func _glow(col: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(col, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func update_visual() -> void:
	if _label == null:
		return
	var info: Dictionary = REWARDS[reward]
	if captured:
		_label.text = "%s\nCapturé ✔" % info.name
		_fill_mat.albedo_color = Color(info.color, 0.12)
		_light.light_energy = 0.4
		return
	_label.text = "%s\n%s" % [info.name, ("Capture : %d %%" % roundi(progress * 100)) if progress > 0.0 else "Reste dans le cercle : %s" % info.desc]
	_fill_mat.albedo_color = Color(info.color, 0.08 + 0.32 * progress)
	_fill.scale = Vector3(maxf(progress, 0.02), 1.0, maxf(progress, 0.02))


## Le héros en [param pos] est-il dans le cercle ?
func contains(pos: Vector3) -> bool:
	var d := pos - global_position
	d.y = 0.0
	return d.length() <= RADIUS
