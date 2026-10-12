class_name Hazard
extends Node3D
## Zone dangereuse persistante au sol (lave, poison, gel, foudre) posée par un boss ou
## par la salle : tant que le héros est dedans (et au sol), il perd des PV par
## demi-seconde et subit l'effet associé. [member lifetime] <= 0 : permanente.

const STYLES := {
	"lava": {"color": Color(1.0, 0.35, 0.08), "status": "burn", "name": "Lave"},
	"poison": {"color": Color(0.45, 0.95, 0.25), "status": "poison", "name": "Poison"},
	"frost": {"color": Color(0.55, 0.85, 1.0), "status": "chill", "name": "Givre"},
	"shock": {"color": Color(0.75, 0.6, 1.0), "status": "shock", "name": "Foudre"},
	"shadow": {"color": Color(0.55, 0.2, 0.75), "status": "scar", "name": "Ombre"},
}

var style := "lava"
var radius := 3.0
var dps := 20.0  # dégâts par seconde
var lifetime := 8.0
var grow := 0.6  # temps d'apparition (inoffensive pendant ce temps)
var source: Combatant

var _t := 0.0
var _tick := 0.0
var _disc: MeshInstance3D
var _mat: StandardMaterial3D


static func spawn(parent: Node, pos: Vector3, props: Dictionary) -> Hazard:
	var h := Hazard.new()
	for k in props:
		h.set(k, props[k])
	parent.get_tree().current_scene.add_child(h)
	h.global_position = pos + Vector3.UP * 0.08
	return h


func _ready() -> void:
	var st: Dictionary = STYLES.get(style, STYLES.lava)
	_disc = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.06
	cyl.radial_segments = 40
	_disc.mesh = cyl
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(st.color, 0.0)
	_mat.emission_enabled = true
	_mat.emission = st.color
	_mat.emission_energy_multiplier = 1.6
	_disc.material_override = _mat
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	var light := OmniLight3D.new()
	light.light_color = st.color
	light.light_energy = 0.8
	light.omni_range = radius * 1.6
	light.shadow_enabled = false
	light.position.y = 0.6
	add_child(light)
	create_tween().tween_property(_mat, "albedo_color:a", 0.55, grow)


func _physics_process(delta: float) -> void:
	_t += delta
	if lifetime > 0.0 and _t >= lifetime:
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_property(_mat, "albedo_color:a", 0.0, 0.5)
		tw.tween_callback(queue_free)
		return
	_mat.emission_energy_multiplier = 1.3 + 0.5 * sin(_t * 5.0)
	if _t < grow:
		return
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = 0.5
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null or p.is_dead or not p.is_on_floor():
		return
	var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
	if d <= radius:
		var src: Combatant = source if is_instance_valid(source) else null
		p.take_damage(dps * 0.5, src, false, true)
		var st := String(STYLES.get(style, STYLES.lava).status)
		p.add_status(st, 2.0, src)
