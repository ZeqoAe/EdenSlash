extends Node3D
## Trait (tir de tour, de Cœur ou de sbire tireur) du banc MB-0 (tools/moba_probe.gd) : suit sa cible et frappe à l'arrivée.
## [member shared] (banc --bolts=pool) : maillage et matière partagés, sans lumière, recyclé ; sinon construit comme le
## Projectile du jeu (sphère, matière et OmniLight3D neuves à chaque tir, libéré après). Aucun class_name (banc).

const SPEED := 28.0
static var _mesh: SphereMesh
static var _mat: StandardMaterial3D

var probe: Node
var shared := false
var target: Combatant
var source: Combatant
var damage := 0.0
var live := false
var _life := 0.0


func _ready() -> void:
	var orb := MeshInstance3D.new()
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if shared:
		if _mesh == null:
			_mesh = SphereMesh.new()
			_mesh.radius = 0.3
			_mesh.height = 0.6
			_mesh.radial_segments = 8
			_mesh.rings = 4
			_mat = StandardMaterial3D.new()
			_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_mat.albedo_color = Color(1.0, 0.85, 0.4)
		orb.mesh = _mesh
		orb.material_override = _mat
	else:
		var s := SphereMesh.new()
		s.radius = 0.3
		s.height = 0.6
		orb.mesh = s
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.85, 0.4)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.7, 0.2)
		orb.material_override = m
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.7, 0.3)
		l.omni_range = 3.0
		add_child(l)
	add_child(orb)


func launch(src: Combatant, tgt: Combatant, dmg: float, from: Vector3) -> void:
	source = src
	target = tgt
	damage = dmg
	live = true
	_life = 3.0
	visible = true
	set_physics_process(true)
	global_position = from


func _physics_process(delta: float) -> void:
	if not live:
		return
	var t0 := Time.get_ticks_usec()
	_life -= delta
	if not is_instance_valid(target) or target.is_dead or _life <= 0.0:
		_done()
	else:
		var aim := target.global_position + Vector3.UP
		var to := aim - global_position
		var d := to.length()
		if d <= SPEED * delta + 0.4:
			if damage > 0.0:  # (0 : tir à blanc d'une tour, banc --busy=1)
				target.take_damage(damage, source if is_instance_valid(source) else null)
			_done()
		else:
			global_position += to / d * SPEED * delta
	probe.cost["bolt"] += Time.get_ticks_usec() - t0


func _done() -> void:
	live = false
	visible = false
	set_physics_process(false)
	probe.bolt_done(self)
