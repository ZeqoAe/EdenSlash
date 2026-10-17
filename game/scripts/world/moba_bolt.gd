class_name MobaBolt
extends Node3D
## Trait des Deux Voies (lot MB-C) : tir de tour, de Cœur ou de sbire tireur ; suit sa cible et frappe à l'arrivée. Recyclé
## par le directeur, maillage et matière partagés, sans lumière (R_MB0 § 4.6 : le Projectile du jeu crée maillage, matière et
## lumière à chaque tir).

const SPEED := MobaData.BOLT_SPEED

static var _meshes := {}
static var _mats := {}

var director: Node
var target: Combatant
var source: Combatant
var damage := 0.0
var units := 0.0  # coup d'un sbire sur une structure : unités
var live := false
var _life := 0.0
var _orb: MeshInstance3D


func _ready() -> void:
	_orb = MeshInstance3D.new()
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_orb)


static func _mesh(style: String) -> Mesh:
	if not _meshes.has(style):
		var s := SphereMesh.new()
		s.radius = 0.38 if style == "tower" else 0.2
		s.height = s.radius * 2.0
		s.radial_segments = 8
		s.rings = 4
		_meshes[style] = s
	return _meshes[style]


static func _mat(style: String, side: int) -> Material:
	var key := "%s%d" % [style, side]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = UiTheme.color("bonbon.soleil.clair", Color("ffe27a")) if style == "tower" else TeamMatch.color(side, "clair")
		_mats[key] = m
	return _mats[key]


func launch(src: Combatant, tgt: Combatant, dmg: float, from: Vector3, style: String, side: int) -> void:
	source = src
	target = tgt
	damage = dmg
	units = (src as MobaMinion).struct_units if src is MobaMinion and tgt is MobaStructure else 0.0
	live = true
	_life = 3.0
	_orb.mesh = _mesh(style)
	_orb.material_override = _mat(style, side)
	visible = true
	set_physics_process(true)
	global_position = from


func _physics_process(delta: float) -> void:
	if not live:
		return
	_life -= delta
	if not is_instance_valid(target) or target.is_dead or _life <= 0.0:
		_done()
		return
	var aim := target.global_position + Vector3.UP * 1.0
	var to := aim - global_position
	var d := to.length()
	if d <= SPEED * delta + 0.5:
		var src: Combatant = source if is_instance_valid(source) else null  # (un tireur mort garde son coup en vol)
		if target is MobaStructure and units > 0.0:
			(target as MobaStructure).take_units(units, src)
		elif damage > 0.0:
			target.take_damage(damage, src)
		_done()
	else:
		global_position += to / d * SPEED * delta


func _done() -> void:
	live = false
	visible = false
	set_physics_process(false)
	director.bolt_done(self)
