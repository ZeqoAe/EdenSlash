class_name HeroBolt
extends Node3D
## Projectile du héros (flèche, projectile magique, trait sacré) : file en ligne
## droite, touche les monstres sur son passage, traverse [member pierce] cibles, puis
## rebondit [member bounce] fois vers l'ennemi le plus proche (auto-attaques, cartes).
## Les dégâts sont appliqués par le héros (Player.bolt_hit) avec l'action d'origine.

const STYLES := {
	"arrow": {"color": Color(1.0, 0.92, 0.7), "size": Vector3(0.07, 0.07, 1.1), "speed": 34.0},
	"magic": {"color": Color(0.55, 0.75, 1.0), "size": Vector3(0.38, 0.38, 0.38), "speed": 24.0},
	"fire": {"color": Color(1.0, 0.5, 0.2), "size": Vector3(0.42, 0.42, 0.42), "speed": 24.0},
	"ice": {"color": Color(0.6, 0.9, 1.0), "size": Vector3(0.18, 0.18, 0.9), "speed": 28.0},
	"lightning": {"color": Color(0.85, 0.8, 1.0), "size": Vector3(0.14, 0.14, 1.3), "speed": 40.0},
	"dark": {"color": Color(0.6, 0.3, 0.85), "size": Vector3(0.4, 0.4, 0.4), "speed": 22.0},
	"nature": {"color": Color(0.5, 1.0, 0.45), "size": Vector3(0.34, 0.34, 0.34), "speed": 24.0},
	"holy": {"color": Color(1.0, 0.95, 0.6), "size": Vector3(0.3, 0.3, 0.8), "speed": 28.0},
	"shadow": {"color": Color(0.7, 0.45, 1.0), "size": Vector3(0.1, 0.1, 0.8), "speed": 34.0},
	"shuriken": {"color": Color(0.85, 0.92, 1.0), "size": Vector3(0.3, 0.3, 0.3), "speed": 22.0},  # étoile qui tourne (lot CHR-1)
}

var shooter: Player
var action: Dictionary
var dir := Vector3.FORWARD
var max_range := 13.0
var pierce := 0
var bounce := 0
const BOUNCE_RANGE := 8.0
var style := "arrow"
var _speed := 30.0
var _travel := 0.0
var _hit: Array = []
var _spin: Node3D  # étoile de lancer : tourne sur elle-même


static func fire(p: Player, pos: Vector3, direction: Vector3, act: Dictionary) -> HeroBolt:
	if NetEvents.on:
		NetEvents.emit(NetEvents.BOLT, p, [pos, direction, act])  # (lot NET-A) Mode amis : l'hôte rejoue l'effet chez ses amis
	var b := HeroBolt.new()
	b.shooter = p
	b.action = act
	b.dir = Vector3(direction.x, 0.0, direction.z).normalized()
	b.max_range = float(act.get("range", 13.0))
	b.pierce = int(act.get("pierce", 0))
	b.bounce = int(act.get("bounce", 0))
	b.style = String(act.get("projectile", "arrow"))
	p.get_tree().current_scene.add_child(b)
	b.global_position = pos
	b.look_at(pos + b.dir, Vector3.UP)
	return b


func _ready() -> void:
	var st: Dictionary = STYLES.get(style, STYLES.arrow)
	_speed = float(st.speed)
	var mesh := MeshInstance3D.new()
	var size: Vector3 = st.size
	if style == "shuriken":
		_spin = NinjaArts.shuriken_node()  # étoile de lancer à 4 branches (lot CHR-1) à la place de la boule
		add_child(_spin)
	elif size.x == size.z:
		var s := SphereMesh.new()
		s.radius = size.x * 0.5
		s.height = size.x
		mesh.mesh = s
	else:
		var bx := BoxMesh.new()
		bx.size = size
		mesh.mesh = bx
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = st.color
	m.emission_enabled = true
	m.emission = st.color
	m.emission_energy_multiplier = 2.5
	mesh.material_override = m
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _spin == null:
		add_child(mesh)
	else:
		mesh.free()
	# traînée lumineuse
	var trail := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(size.x * 0.6, size.y * 0.6, 1.6)
	trail.mesh = tb
	var tm := StandardMaterial3D.new()
	tm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	tm.disable_fog = true  # la brume ne s'ajoute pas aux effets lumineux (carrés pâles)
	tm.albedo_color = Color(st.color, 0.35)
	trail.material_override = tm
	trail.position.z = 0.9
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)


func _physics_process(delta: float) -> void:
	if shooter == null or not is_instance_valid(shooter):
		queue_free()
		return
	var step := _speed * delta
	global_position += dir * step
	if _spin:
		_spin.rotate_y(delta * 26.0)
	_travel += step
	if AssaultVision.current != null and AssaultVision.blocks_segment(global_position - dir * step, global_position):
		queue_free()  # (lot TAC-2, L'Assaut) le projectile s'arrête au mur ou au muret
		return
	for node in shooter.foes():
		var mo := node as Combatant
		if mo == null or mo.is_dead or _hit.has(mo):
			continue
		var to := mo.global_position - global_position
		if absf(to.y + 0.8) > 2.6:
			continue
		to.y = 0.0
		if to.length() <= mo.radius + 0.55:
			_hit.append(mo)
			shooter.bolt_hit(mo, dir, action)
			if pierce > 0:
				pierce -= 1
			elif bounce > 0 and _bounce_from(mo):
				bounce -= 1
				return
			else:
				queue_free()
				return
	if _travel >= max_range:
		queue_free()


## Rebond : repart de [param from] vers l'ennemi le plus proche pas encore touché.
func _bounce_from(from: Combatant) -> bool:
	if not is_instance_valid(shooter):
		return false
	var best: Combatant = null
	var best_d := BOUNCE_RANGE
	for node in shooter.foes():
		var mo := node as Combatant
		if mo == null or mo.is_dead or _hit.has(mo) or mo == from:
			continue
		var d := mo.global_position.distance_to(from.global_position)
		if d < best_d:
			best_d = d
			best = mo
	if best == null:
		return false
	var to := best.global_position - global_position
	to.y = 0.0
	dir = to.normalized()
	look_at(global_position + dir, Vector3.UP)
	_travel = maxf(0.0, max_range - BOUNCE_RANGE - 1.0)
	return true
