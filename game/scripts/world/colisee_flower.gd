class_name ColiseeFlower
extends Node3D
## Fleur de vie d'une arène du Colisée (lot CO-B, ARENA.md § 6.4) : le premier héros vivant qui marche dessus est soigné de
## HEAL de ses PV max (les soins du JcJ, moitié moins forts, sont compensés : c'est bien HEAL ; l'anneau de feu les divise
## encore par deux dehors) et protégé (statut « barrier » : dégâts subis réduits) pendant BARRIER s ; elle repousse en REGROW s.
## Dessin autocollant : 5 pétales pomme contourés d'encre, cœur soleil, halo au sol ; bouton fermé quand elle repousse.
## Le directeur appelle tick(delta, combattants de l'arène) à chaque image du combat et reset() à chaque manche.

signal picked(who: Combatant)

const HEAL := 0.15
const BARRIER := 4.0
const REGROW := 20.0
const RADIUS := 1.4
const SIZE := 1.7  # taille du dessin (lisible de la caméra de combat, à 25 m)

var ready_now := true
var regrow_left := 0.0
var _bloom: Node3D
var _halo: MeshInstance3D
var _spin := 0.0


func _ready() -> void:
	_build()


func _mat(c: Color, unshaded := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _build() -> void:
	var ink := UiTheme.color("encre.900", Color(0.12, 0.08, 0.16))
	var green := UiTheme.color("bonbon.pomme.base", Color(0.56, 0.84, 0.18))
	var green_l := UiTheme.color("bonbon.pomme.clair", Color(0.76, 0.94, 0.48))
	var sun := UiTheme.color("bonbon.soleil.base", Color(1.0, 0.79, 0.16))
	_halo = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS
	disc.bottom_radius = RADIUS
	disc.height = 0.02
	_halo.mesh = disc
	_halo.material_override = _mat(Color(green.r, green.g, green.b, 0.38))
	_halo.position.y = 0.05
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	var stem := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.05
	sm.bottom_radius = 0.07
	sm.height = 0.6 * SIZE
	stem.mesh = sm
	stem.material_override = _mat(green.darkened(0.35))
	stem.position.y = 0.3 * SIZE
	add_child(stem)
	_bloom = Node3D.new()
	_bloom.position.y = 0.62 * SIZE
	add_child(_bloom)
	for k in 5:
		var a := TAU * k / 5.0
		# contour d'encre : la même forme, un peu plus grande, derrière (face arrière seulement)
		for layer in 2:
			var p := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = (0.22 if layer == 1 else 0.25) * SIZE
			sp.height = (0.12 if layer == 1 else 0.15) * SIZE
			p.mesh = sp
			var m := _mat(green_l if layer == 1 else ink)
			if layer == 0:
				m.cull_mode = BaseMaterial3D.CULL_FRONT
			p.material_override = m
			p.position = Vector3(cos(a) * 0.24, 0.0, sin(a) * 0.24) * SIZE
			p.rotation.y = -a
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_bloom.add_child(p)
	var heart := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.13 * SIZE
	hm.height = 0.16 * SIZE
	heart.mesh = hm
	heart.material_override = _mat(sun)
	heart.position.y = 0.05 * SIZE
	_bloom.add_child(heart)


func reset() -> void:
	ready_now = true
	regrow_left = 0.0
	if _bloom:
		_bloom.scale = Vector3.ONE
		_halo.visible = true


## Une image : repousse, ou soigne le premier héros vivant sur la fleur parmi [param fighters].
func tick(delta: float, fighters: Array) -> void:
	_spin += delta
	if _bloom:
		_bloom.rotation.y = _spin * 0.6
	if not ready_now:
		regrow_left -= delta
		if _bloom:
			var k := clampf(1.0 - regrow_left / REGROW, 0.0, 1.0)
			_bloom.scale = Vector3.ONE * lerpf(0.25, 0.6, k)
		if regrow_left <= 0.0:
			reset()
		return
	for n in fighters:
		var c := n as Combatant
		if c == null or not is_instance_valid(c) or c.is_dead:
			continue
		var off := c.global_position - global_position
		off.y = 0.0
		if off.length() <= RADIUS + c.radius * 0.5:
			pick(c)
			return


func pick(c: Combatant) -> void:
	var k := PvpCaps.heal_mult() if PvpCaps.active() else 1.0
	c.heal(c.max_hp * HEAL / maxf(k, 0.05))
	c.add_status("barrier", BARRIER, c)
	ready_now = false
	regrow_left = REGROW
	if _bloom:
		_bloom.scale = Vector3.ONE * 0.25
		_halo.visible = false
	if is_inside_tree() and is_visible_in_tree():
		Vfx.ring(c, global_position, 2.0, Color(0.56, 0.84, 0.18, 0.9))
	picked.emit(c)
