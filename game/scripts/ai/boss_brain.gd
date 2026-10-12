class_name BossBrain
extends Node
## Attaques spéciales d'un boss, toutes annoncées au sol (Telegraph) :
##   écrasements en cercle sur le héros, charge en ligne, balayage en cône au
##   corps à corps, salve de projectiles à distance, onde circulaire.
## Sous 50 % de PV : fureur (annonces plus courtes, onde régulière).

signal enraged_phase

var boss: Monster
var _cooldown := 2.5
var _nova_timer := 0.0
var _phase2 := false
var _busy := false


func _physics_process(delta: float) -> void:
	if boss == null or boss.is_dead or _busy:
		return
	var player := boss._player
	if player == null or player.is_dead:
		return
	if not _phase2 and boss.hp < boss.max_hp * 0.5:
		_phase2 = true
		enraged_phase.emit()
		_cast_nova()
		return
	_cooldown -= delta
	_nova_timer -= delta
	if _cooldown > 0.0 or boss._state == "attack":
		return
	var d := boss.global_position.distance_to(player.global_position)
	if d > 32.0:
		return
	if _phase2 and _nova_timer <= 0.0:
		_cast_nova()
	elif d < 8.0 and randf() < 0.45:
		_cast_cleave()
	elif d > 10.0 and randf() < 0.5:
		_cast_barrage()
	elif randf() < 0.5:
		_cast_charge()
	else:
		_cast_slams()


func _speed() -> float:
	return 0.75 if _phase2 else 1.0


func _begin(anim_name: String, duration: float) -> void:
	_busy = true
	boss.begin_cast()
	for a in [anim_name, "magic01", "attack01"]:
		if boss.has_anim(a):
			boss.play(a, 0.1, 1.0, true)
			break
	await boss.get_tree().create_timer(duration, false).timeout
	if is_instance_valid(boss) and not boss.is_dead:
		boss.end_cast()
	_busy = false
	_cooldown = randf_range(1.6, 2.6) * _speed()


func _dmg(mult: float) -> float:
	return boss.atk * mult


# --- attaques -----------------------------------------------------------------------
func _cast_slams() -> void:
	var delay := 1.3 * _speed()
	_begin("magic01", 0.5 * 3 + delay)
	for i in 3:
		if not is_instance_valid(boss) or boss.is_dead:
			return
		var p := boss._player.global_position
		Telegraph.spawn(boss, p, 0.0, {"shape": "circle", "radius": 4.0, "delay": delay, "damage": _dmg(1.4), "source": boss})
		await boss.get_tree().create_timer(0.5, false).timeout


func _cast_charge() -> void:
	var delay := 1.0 * _speed()
	var to := boss._player.global_position - boss.global_position
	to.y = 0.0
	var yaw := atan2(to.x, to.z)
	boss.face_direction(to, 1.0, 100.0)
	var t := Telegraph.spawn(boss, boss.global_position, yaw, {"shape": "line", "length": 18.0, "width": 3.5, "delay": delay, "damage": _dmg(1.8), "source": boss})
	_begin("move02", delay + 0.4)
	await t.resolved
	if is_instance_valid(boss) and not boss.is_dead:
		var dest := boss.global_position + to.normalized() * 16.0
		boss.create_tween().tween_property(boss, "global_position", Vector3(dest.x, boss.global_position.y, dest.z), 0.3)


func _cast_cleave() -> void:
	var delay := 0.8 * _speed()
	var to := boss._player.global_position - boss.global_position
	boss.face_direction(to, 1.0, 100.0)
	Telegraph.spawn(boss, boss.global_position, atan2(to.x, to.z), {"shape": "cone", "radius": 7.5, "angle": 110.0, "delay": delay, "damage": _dmg(1.7), "source": boss})
	_begin("attack02", delay + 0.3)


func _cast_barrage() -> void:
	var delay := 0.7 * _speed()
	var to := boss._player.global_position - boss.global_position
	to.y = 0.0
	var base := atan2(to.x, to.z)
	boss.face_direction(to, 1.0, 100.0)
	_begin("shoot01", delay + 0.6)
	var dirs: Array[float] = []
	for i in 5:
		var yaw := base + deg_to_rad(-30.0 + 15.0 * i)
		dirs.append(yaw)
		# trait fin : la trajectoire du projectile
		Telegraph.spawn(boss, boss.global_position, yaw, {"shape": "line", "length": 22.0, "width": 0.9, "delay": delay, "damage": 0.0, "source": boss})
	await boss.get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(boss) or boss.is_dead:
		return
	for yaw in dirs:
		Projectile.fire(boss, boss.global_position + Vector3.UP * 1.2, Vector3(sin(yaw), 0, cos(yaw)), _dmg(0.9))


func _cast_nova() -> void:
	_nova_timer = 14.0
	var delay := 1.6 * _speed()
	Telegraph.spawn(boss, boss.global_position, 0.0, {"shape": "ring", "radius": 12.0, "inner": 3.0, "delay": delay, "damage": _dmg(2.0), "source": boss})
	_begin("magic02", delay + 0.3)
