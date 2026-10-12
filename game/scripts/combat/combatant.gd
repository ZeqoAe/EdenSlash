class_name Combatant
extends CharacterBody3D
## Base commune du joueur et des monstres : PV, dégâts, mort, modèle animé.

signal died(who: Combatant, killer: Combatant)
signal health_changed(hp: float, max_hp: float)

enum Team { PLAYER, MONSTER }

const GRAVITY := 24.0

var team: Team = Team.MONSTER
var display_name := ""
var level := 1
var max_hp := 100.0
var hp := 100.0
var atk := 10.0
var defense := 0.0
var is_dead := false
var radius := 0.5

var model: Node3D
var anim: AnimationPlayer
var kfm := ""  # nom du modèle Eden, pour les clés de motion.ini
var _current_anim := ""

# --- effets d'état ---------------------------------------------------------------
## Effets connus : bleed (saignement), purgatory, cranes (dégâts subis +),
## scar (dégâts infligés -), stun ; solar, shrine, marduk (buffs du héros).
const STATUS_INFO := {
	"bleed": {"name": "Saignement", "color": Color(0.95, 0.25, 0.25)},
	"purgatory": {"name": "Purgatoire", "color": Color(1.0, 0.55, 0.15)},
	"cranes": {"name": "Mille grues", "color": Color(0.6, 0.85, 1.0)},
	"scar": {"name": "Cicatrice", "color": Color(0.85, 0.5, 0.9)},
	"stun": {"name": "Renversé", "color": Color(1.0, 1.0, 0.4)},
	"solar": {"name": "Bénédiction solaire", "color": Color(1.0, 0.85, 0.3)},
	"shrine": {"name": "Volonté du sanctuaire", "color": Color(0.7, 1.0, 0.7)},
	"marduk": {"name": "Langue de Marduk", "color": Color(1.0, 0.4, 0.3)},
}
signal statuses_changed

var statuses := {}  # nom -> instant de fin
var clock := 0.0
var _bleed_dps := 0.0
var _bleed_source: Combatant
var _bleed_tick := 0.0


func add_status(status: String, duration: float, source: Combatant = null) -> void:
	statuses[status] = maxf(float(statuses.get(status, 0.0)), clock + duration)
	if status == "bleed" and source:
		_bleed_source = source
		_bleed_dps = source.atk * 0.15
	statuses_changed.emit()


func has_status(status: String) -> bool:
	return float(statuses.get(status, -1.0)) > clock


func tick_statuses(delta: float) -> void:
	clock += delta
	if has_status("bleed") and not is_dead:
		_bleed_tick += delta
		if _bleed_tick >= 1.0:
			_bleed_tick -= 1.0
			take_damage(_bleed_dps, _bleed_source, false, true)
	var expired := false
	for s in statuses.keys():
		if float(statuses[s]) <= clock:
			statuses.erase(s)
			expired = true
	if expired:
		statuses_changed.emit()


## Multiplicateur des dégâts subis (débuffs ennemis, buffs du héros).
func damage_taken_mult() -> float:
	var m := 1.0
	if has_status("purgatory"):
		m *= 1.2
	if has_status("cranes"):
		m *= 1.15
	if has_status("solar"):
		m *= 0.75
	if has_status("shrine"):
		m *= 0.7
	return m


func damage_dealt_mult() -> float:
	return 0.7 if has_status("scar") else 1.0


## Clés d'animation d'Eden (impacts, sons, traînée) de l'animation [param anim_name].
func keys_of(anim_name: String) -> Dictionary:
	return GameData.anim_keys(kfm, anim_name)


func setup_model(glb_path: String, texture_path := "", model_scale := 1.0) -> void:
	if kfm == "":
		kfm = glb_path.get_file().get_basename()
	model = EdenModel.instantiate(glb_path, texture_path)
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	anim = EdenModel.find_anim_player(model)
	var box := EdenModel.bounds(model)
	radius = clampf(maxf(box.size.x, box.size.z) * 0.38 * model_scale, 0.35, 1.8)
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = maxf(radius * 2.0, box.size.y * model_scale * 0.8)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = shape.height * 0.5
	add_child(col)


func play(anim_name: String, blend := 0.15, speed := 1.0, restart := false) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	if anim_name == _current_anim and not restart and anim.is_playing():
		return
	_current_anim = anim_name
	anim.play(anim_name, blend, speed)
	if restart:
		anim.seek(0.0, true)


func anim_length(anim_name: String) -> float:
	if anim and anim.has_animation(anim_name):
		return anim.get_animation(anim_name).length
	return 1.0


func has_anim(anim_name: String) -> bool:
	return anim != null and anim.has_animation(anim_name)


## Les modèles d'Eden regardent vers +Z : on oriente le corps vers [param dir].
func face_direction(dir: Vector3, delta: float, turn_speed := 14.0) -> void:
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return
	var target := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(turn_speed * delta, 0.0, 1.0))


func forward() -> Vector3:
	return global_transform.basis.z.normalized()


func take_damage(amount: float, source: Combatant = null, crit := false, dot := false) -> void:
	if is_dead:
		return
	var dmg := maxf(1.0, round(amount * damage_taken_mult() - (0.0 if dot else defense * 0.5)))
	hp = maxf(0.0, hp - dmg)
	health_changed.emit(hp, max_hp)
	DamageNumber.spawn(self, dmg, crit, team == Team.PLAYER)
	_on_damaged(dmg, source)
	if hp <= 0.0:
		is_dead = true
		_on_death(source)
		died.emit(self, source)


func heal(amount: float) -> void:
	if is_dead:
		return
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)


func _on_damaged(_amount: float, _source: Combatant) -> void:
	pass


func _on_death(_killer: Combatant) -> void:
	pass


func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
