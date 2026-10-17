class_name Projectile
extends Node3D
## Projectile ennemi visible (orbe), en ligne droite ; touche le héros au contact.

const SPEED := 15.0
const LIFE := 2.2
const HIT_RADIUS := 0.9

var dir := Vector3.FORWARD
var damage := 50.0
var source: Combatant
var speed := SPEED  # orbes lents des motifs de boss (BossBricks)
var life := LIFE
var _t := 0.0


static func fire(from: Node, pos: Vector3, direction: Vector3, dmg: float) -> Projectile:
	var p := Projectile.new()
	p.dir = direction.normalized()
	p.damage = dmg
	p.source = from as Combatant
	from.get_tree().current_scene.add_child(p)
	p.global_position = pos
	return p


func _ready() -> void:
	var orb := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.45
	s.height = 0.9
	orb.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.45, 0.15)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.4, 0.1)
	m.emission_energy_multiplier = 3.0
	orb.material_override = m
	add_child(orb)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.omni_range = 4.0
	add_child(l)


func _physics_process(delta: float) -> void:
	_t += delta
	global_position += dir * speed * delta
	if AssaultVision.current != null and AssaultVision.blocks_segment(global_position - dir * speed * delta, global_position):
		queue_free()  # (lot TAC-2, L'Assaut) l'orbe s'arrête au mur
		return
	var struck := false
	var src: Combatant = source if is_instance_valid(source) else null
	for target in Combatant.hostile_targets(get_tree(), src):
		if global_position.distance_to(target.global_position + Vector3.UP * 1.0) < HIT_RADIUS + target.radius:
			target.take_damage(damage, src, false)
			struck = true
			break
	if struck:
		queue_free()
	elif _t > life:
		queue_free()
