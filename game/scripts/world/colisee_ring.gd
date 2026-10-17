class_name ColiseeRing
extends Node3D
## Anneau de feu d'une arène du Colisée (lot CO-B, conception/benchmark/R_CO_B.md ; ARENA.md § 6.3). Rayon START_R m au début
## du combat, puis 4 resserrements (STEPS : [instant, rayon]) annoncés WARN s avant (signal warned, prochain anneau en
## pointillés) et faits en SHRINK s. Hors de l'anneau : DPS des PV max par seconde, + DPS_RAMP par seconde passée dehors
## (remis à zéro en rentrant), soins reçus × HEAL_OUT (Combatant.heal_taken). Dégâts sans source ni défense (un danger
## pour tous), versés par paquets toutes les TICK s (pas un chiffre par image).
## Dessin : un disque au sol (shaders/colisee_ring.gdshader) : bord blanc net + liseré mandarine, dehors voile mandarine à
## 32 % au plus (BIBLE § 10), prochain anneau en pointillés. Rien n'est dessiné quand l'arène est cachée (visible faux).
##
## Utilisation (directeur du combat) : ring.setup(centre) ; à chaque manche ring.reset() ; chaque image du combat
## ring.advance(delta, combattants de l'arène) ; ring.radius, ring.next_info() pour le HUD (« Feu · 4 s »).

signal warned(seconds: float, next_radius: float)  ## un resserrement arrive dans WARN s
signal shrunk(radius: float)  ## un resserrement est fini

const START_R := 22.0
const STEPS := [[25.0, 16.0], [40.0, 11.0], [55.0, 6.0], [70.0, 3.0]]
const WARN := 4.0
const SHRINK := 2.0
const DPS := 0.05
const DPS_RAMP := 0.02
const HEAL_OUT := 0.5
const TICK := 0.25
const EXTENT := 30.0
const SHADER := preload("res://shaders/colisee_ring.gdshader")

var center := Vector3.ZERO
var radius := START_R
var t := 0.0
var running := false
var _out: Dictionary = {}  # id d'instance -> [secondes dehors, dégâts en attente]
var _tick := 0.0
var _warned := -1
var _shrunk := -1
var _mat: ShaderMaterial
var mesh: MeshInstance3D


func setup(p_center: Vector3) -> void:
	center = p_center
	global_position = p_center
	mesh = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(EXTENT * 2.0, EXTENT * 2.0)
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	mesh.mesh = pm
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("fire", UiTheme.color("bonbon.mandarine.base", Color(1.0, 0.541, 0.122)))
	_mat.set_shader_parameter("fire_dark", UiTheme.color("bonbon.mandarine.fonce", Color(0.784, 0.373, 0.031)))
	_mat.set_shader_parameter("extent", EXTENT)
	mesh.material_override = _mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = Vector3.UP * 0.07
	add_child(mesh)
	reset()


## Nouvelle manche : grand anneau, compteurs remis à zéro (les soins des héros restent à 1).
func reset(fighters: Array = []) -> void:
	t = 0.0
	radius = START_R
	running = false
	_tick = 0.0
	_warned = -1
	_shrunk = -1
	for c in fighters:
		if is_instance_valid(c):
			(c as Combatant).heal_taken = 1.0
	_out = {}
	_draw(-1.0, 0.0)


## Rayon de l'anneau [param at] s après le début du combat.
static func radius_at(at: float) -> float:
	var r := START_R
	for s in STEPS:
		var t0 := float(s[0])
		if at < t0:
			break
		r = lerpf(r, float(s[1]), clampf((at - t0) / SHRINK, 0.0, 1.0))
	return r


## Prochain resserrement : {in (s avant le début), radius} ; {} s'il n'y en a plus.
static func next_after(at: float) -> Dictionary:
	for s in STEPS:
		if at < float(s[0]):
			return {"in": float(s[0]) - at, "radius": float(s[1])}
	return {}


func next_info() -> Dictionary:
	return next_after(t)


## Une image du combat : temps, rayon, dégâts et soins réduits hors de l'anneau pour [param fighters] (ceux de l'arène).
func advance(delta: float, fighters: Array) -> void:
	running = true
	t += delta
	radius = radius_at(t)
	for k in STEPS.size():
		var t0 := float(STEPS[k][0])
		if k > _warned and t >= t0 - WARN:
			_warned = k
			warned.emit(maxf(0.0, t0 - t), float(STEPS[k][1]))
		if k > _shrunk and t >= t0 + SHRINK:
			_shrunk = k
			shrunk.emit(float(STEPS[k][1]))
	_tick += delta
	var pay := _tick >= TICK
	if pay:
		_tick = 0.0
	for n in fighters:
		var c := n as Combatant
		if c == null or not is_instance_valid(c) or c.is_dead:
			continue
		var id := c.get_instance_id()
		var off := c.global_position - center
		off.y = 0.0
		if off.length() <= radius:
			if _out.has(id):
				var rest: float = _out[id][1]
				_out.erase(id)
				if rest >= 1.0:
					c.take_damage(rest, null, false, true)
			c.heal_taken = 1.0
			continue
		c.heal_taken = HEAL_OUT
		var e: Array = _out.get(id, [0.0, 0.0])
		e[0] = float(e[0]) + delta
		e[1] = float(e[1]) + c.max_hp * (DPS + DPS_RAMP * float(e[0])) * delta
		_out[id] = e
		if pay and float(e[1]) >= 1.0:
			var dmg := floorf(float(e[1]))
			e[1] = float(e[1]) - dmg
			c.take_damage(dmg, null, false, true)
	var nx := next_after(t)
	var shrinking := false
	for s in STEPS:
		if t >= float(s[0]) and t < float(s[0]) + SHRINK:
			shrinking = true
	_draw(float(nx.radius) if not nx.is_empty() and float(nx["in"]) <= WARN else (-1.0 if not shrinking else _target_now()), 1.0 if shrinking else 0.0)


func _target_now() -> float:
	for s in STEPS:
		if t >= float(s[0]) and t < float(s[0]) + SHRINK:
			return float(s[1])
	return -1.0


## Secondes passées dehors par [param c] (0 : dedans).
func outside_time(c: Combatant) -> float:
	return float(_out.get(c.get_instance_id(), [0.0])[0])


func is_outside(c: Combatant) -> bool:
	var off := c.global_position - center
	off.y = 0.0
	return off.length() > radius


func _draw(next_r: float, pulse: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("radius", radius)
	_mat.set_shader_parameter("next_radius", next_r)
	_mat.set_shader_parameter("pulse", pulse)
