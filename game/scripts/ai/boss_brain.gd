class_name BossBrain
extends Node
## Attaques spéciales d'un boss, toutes annoncées au sol (Telegraph) :
##   écrasements en cercle sur le héros, charge en ligne, balayage en cône au
##   corps à corps, salve de projectiles à distance, onde circulaire.
## Sous 50 % de PV : fureur (annonces plus courtes, onde régulière).

signal enraged_phase
## Annonce d'une mécanique propre au boss (texte affiché par le directeur de run).
signal announce(text: String)

var boss: Monster
var _cooldown := 2.5
var _nova_timer := 0.0
var _phase2 := false
var _busy := false
var _reflect_timer := 12.0
var reflecting := false
var _reflect_ring: Node3D
# --- mécaniques propres au boss de la zone (data/zones.json -> dungeon.mechanics) ------------
## adds, puddles, meteors, stomp, clones, totems, lasers, pet, vortex, reflect
var mechanics: Array = []
var hazard_style := "lava"
var director: Node
var _mech_t := {}
var _thresholds_done := {}
var _totems: Array = []


## Mécaniques du boss d'après la salle (zone) ; [param dir] : directeur de run (invocations).
func setup(dungeon: Dictionary, dir: Node) -> void:
	mechanics = dungeon.get("mechanics", [])
	hazard_style = String(dungeon.get("hazard", "lava"))
	director = dir
	if not mechanics.is_empty() and not "reflect" in mechanics:
		_reflect_timer = 1.0e9  # le miroir n'est qu'une mécanique parmi d'autres
	for m in mechanics:
		_mech_t[m] = {"puddles": 6.0, "meteors": 8.0, "stomp": 10.0, "lasers": 12.0, "vortex": 16.0}.get(m, 0.0)
	if "pet" in mechanics and dungeon.has("pet"):
		_summon([int(dungeon.pet)], 1, 5.0, true)
		announce.emit("%s appelle son compagnon !" % boss.display_name)


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
	if _update_mechanics(delta):
		return
	_cooldown -= delta
	_nova_timer -= delta
	_reflect_timer -= delta
	if _reflect_timer <= 0.0:
		_start_reflect()
		return
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


# --- miroir : 3 s pendant lesquelles les coups reçus sont renvoyés ------------------------
func _start_reflect() -> void:
	_reflect_timer = 17.0 if not _phase2 else 12.0
	reflecting = true
	boss.message_reflect()
	_reflect_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = boss.radius + 0.6
	t.outer_radius = boss.radius + 1.0
	(_reflect_ring as MeshInstance3D).mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true  # la brume ne s'ajoute pas aux effets lumineux (carrés pâles)
	m.albedo_color = Color(1.0, 0.85, 0.3, 0.9)
	(_reflect_ring as MeshInstance3D).material_override = m
	boss.add_child(_reflect_ring)
	_reflect_ring.position.y = 1.2
	var tw := _reflect_ring.create_tween().set_loops(6)
	tw.tween_property(_reflect_ring, "scale", Vector3.ONE * 1.15, 0.25)
	tw.tween_property(_reflect_ring, "scale", Vector3.ONE, 0.25)
	await boss.get_tree().create_timer(3.0, false).timeout
	reflecting = false
	if is_instance_valid(_reflect_ring):
		_reflect_ring.queue_free()


# --- attaques -----------------------------------------------------------------------
func _cast_slams() -> void:
	var delay := 1.3 * _speed()
	_begin("magic01", 0.5 * 3 + delay)
	for i in 3:
		if not is_instance_valid(boss) or boss.is_dead:
			return
		var p := boss._player.global_position
		Telegraph.spawn(boss, p, 0.0, {"shape": "circle", "radius": 4.0, "delay": delay, "damage": _dmg(1.4), "source": boss, "stun_time": 1.2})
		await boss.get_tree().create_timer(0.5, false).timeout


func _cast_charge() -> void:
	var delay := 1.0 * _speed()
	var to := boss._player.global_position - boss.global_position
	to.y = 0.0
	var yaw := atan2(to.x, to.z)
	boss.face_direction(to, 1.0, 100.0)
	var t := Telegraph.spawn(boss, boss.global_position, yaw, {"shape": "line", "length": 18.0, "width": 3.5, "delay": delay, "damage": _dmg(1.8), "source": boss, "stun_time": 1.4})
	_begin("move02", delay + 0.4)
	await t.resolved
	if is_instance_valid(boss) and not boss.is_dead:
		var dest := boss.global_position + to.normalized() * 16.0
		boss.create_tween().tween_property(boss, "global_position", Vector3(dest.x, boss.global_position.y, dest.z), 0.3)


func _cast_cleave() -> void:
	var delay := 0.8 * _speed()
	var to := boss._player.global_position - boss.global_position
	boss.face_direction(to, 1.0, 100.0)
	Telegraph.spawn(boss, boss.global_position, atan2(to.x, to.z), {"shape": "cone", "radius": 7.5, "angle": 110.0, "delay": delay, "damage": _dmg(1.7), "source": boss, "stun_time": 1.0})
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
	Telegraph.spawn(boss, boss.global_position, 0.0, {"shape": "ring", "radius": 12.0, "inner": 3.0, "delay": delay, "damage": _dmg(2.0), "source": boss, "jumpable": true, "stun_time": 1.5})
	_begin("magic02", delay + 0.3)


# --- mécaniques de salle ---------------------------------------------------------------------
## Renvoie true si une mécanique vient d'être lancée (le boss est occupé).
func _update_mechanics(delta: float) -> bool:
	var ratio := boss.hp / boss.max_hp
	var k := 0.7 if _phase2 else 1.0
	# seuils de PV : renforts, clones, totems
	for m in mechanics:
		match m:
			"adds":
				for th in [0.75, 0.5, 0.25]:
					if ratio < th and not _thresholds_done.has("adds%s" % th):
						_thresholds_done["adds%s" % th] = true
						_summon([], 3 + int((1.0 - th) * 4.0), 7.0)
						announce.emit("%s appelle des renforts !" % boss.display_name)
						return false
			"clones":
				for th in [0.66, 0.33]:
					if ratio < th and not _thresholds_done.has("clones%s" % th):
						_thresholds_done["clones%s" % th] = true
						_cast_clones()
						return true
			"totems":
				if ratio < 0.5 and not _thresholds_done.has("totems"):
					_thresholds_done["totems"] = true
					_cast_totems()
					return true
	if boss.shielded:
		_totems = _totems.filter(func(t): return is_instance_valid(t) and not t.is_dead)
		if _totems.is_empty():
			boss.shielded = false
			announce.emit("Bouclier brisé : %s est vulnérable !" % boss.display_name)
	# mécaniques périodiques
	for m in _mech_t:
		if not m in ["puddles", "meteors", "stomp", "lasers", "vortex"]:
			continue
		_mech_t[m] = float(_mech_t[m]) - delta
		if float(_mech_t[m]) > 0.0 or _busy:
			continue
		match m:
			"puddles":
				_mech_t[m] = 9.0 * k
				_cast_puddles()
			"meteors":
				_mech_t[m] = 12.0 * k
				_cast_meteors()
				return true
			"stomp":
				_mech_t[m] = 13.0 * k
				_cast_stomp()
				return true
			"lasers":
				_mech_t[m] = 14.0 * k
				_cast_lasers()
				return true
			"vortex":
				_mech_t[m] = 18.0 * k
				_cast_vortex()
				return true
	return false


func _summon(ids: Array, count: int, dist: float, elite := false) -> Array:
	var out: Array = []
	if director == null or not director.has_method("summon_for_boss"):
		return out
	for i in count:
		var a := TAU * i / maxf(count, 1) + randf() * 0.4
		var p := boss.global_position + Vector3(cos(a), 0, sin(a)) * dist
		var m = director.summon_for_boss(int(ids.pick_random()) if not ids.is_empty() else 0, p, elite)
		if m != null:
			out.append(m)
	return out


## Flaques persistantes sous le héros (lave, poison...).
func _cast_puddles() -> void:
	var p := boss._player.global_position
	for i in 3:
		var off := Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)) if i > 0 else Vector3.ZERO
		var at := p + off
		Telegraph.spawn(boss, at, 0.0, {"shape": "circle", "radius": 3.0, "delay": 1.0, "damage": _dmg(0.6), "source": boss})
		_hazard_later(at, 3.0, 9.0, 1.0)


func _hazard_later(at: Vector3, r: float, life: float, wait: float) -> void:
	await boss.get_tree().create_timer(wait, false).timeout
	if is_instance_valid(boss) and not boss.is_dead:
		Hazard.spawn(boss, at, {"style": hazard_style, "radius": r, "lifetime": life, "dps": boss.atk * 0.45, "source": boss})


## Pluie de météores autour du héros ; un impact sur deux laisse une flaque.
func _cast_meteors() -> void:
	announce.emit("Pluie de météores !")
	_begin("magic02", 2.2)
	var c := boss._player.global_position
	for i in 7:
		var at := c + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9)) if i > 0 else c
		Telegraph.spawn(boss, at, 0.0, {"shape": "circle", "radius": 3.2, "delay": 1.3 + i * 0.12, "damage": _dmg(1.3), "source": boss, "stun_time": 0.8})
		if i % 2 == 0:
			_hazard_later(at, 2.4, 7.0, 1.4 + i * 0.12)


## Trois ondes de choc successives (bord jaune : saute au bon moment).
func _cast_stomp() -> void:
	announce.emit("Ondes de choc : saute par-dessus !")
	_begin("attack02", 2.6)
	for i in 3:
		var r := 7.0 + i * 6.0
		Telegraph.spawn(boss, boss.global_position, 0.0, {"shape": "ring", "radius": r, "inner": r - 2.5, "delay": 1.0 + i * 0.6,
			"damage": _dmg(1.2), "source": boss, "jumpable": true, "stun_time": 1.0})


## Rayons en croix depuis le boss, puis en diagonale.
func _cast_lasers() -> void:
	announce.emit("Rayons !")
	_begin("magic01", 2.4)
	var base := randf() * TAU
	for wave in 2:
		for i in 4:
			var yaw := base + i * PI * 0.5 + wave * PI * 0.25
			Telegraph.spawn(boss, boss.global_position, yaw, {"shape": "line", "length": 26.0, "width": 2.4, "delay": 1.1 + wave * 0.9,
				"damage": _dmg(1.4), "source": boss})


## Tourbillon : attire le héros 2,5 s puis explose au centre.
func _cast_vortex() -> void:
	announce.emit("Tourbillon : éloigne-toi du boss !")
	_begin("magic02", 3.0)
	Telegraph.spawn(boss, boss.global_position, 0.0, {"shape": "circle", "radius": 6.5, "delay": 2.6, "damage": _dmg(2.2), "source": boss, "stun_time": 1.2})
	var t := 0.0
	while t < 2.5:
		await boss.get_tree().physics_frame
		if not is_instance_valid(boss) or boss.is_dead or boss._player.is_dead:
			return
		var dt := boss.get_physics_process_delta_time()
		t += dt
		var to := boss.global_position - boss._player.global_position
		to.y = 0.0
		if to.length() > 1.5 and not boss._player.is_invulnerable():
			boss._player.global_position += to.normalized() * 2.6 * dt


## Le boss disparaît et laisse 2 illusions (fragiles mais qui frappent).
func _cast_clones() -> void:
	announce.emit("%s se dédouble !" % boss.display_name)
	_begin("magic01", 0.8)
	var c := boss.global_position
	var a := randf() * TAU
	var dest := c + Vector3(cos(a), 0, sin(a)) * 9.0
	if director and director.has_method("ground_point"):
		dest = director.ground_point(dest, c)
	boss.global_position = dest
	for m in _summon([int(boss.data.id)], 2, 6.0):
		m.max_hp = boss.max_hp * 0.06
		m.hp = m.max_hp
		m.atk = boss.atk * 0.45
		m.display_name = "Illusion de " + boss.display_name.trim_prefix("<Boss> ")


## Bouclier : 3 totems à détruire avant de pouvoir toucher le boss.
func _cast_totems() -> void:
	announce.emit("%s s'entoure d'un bouclier : détruis les 3 totems !" % boss.display_name)
	_begin("magic02", 1.0)
	boss.shielded = true
	_totems = _summon([], 3, 11.0, true)
	for t in _totems:
		t.display_name = "Totem du bouclier"
		t.move_speed = 0.0
		t.max_hp = boss.max_hp * 0.05
		t.hp = t.max_hp
	if _totems.is_empty():
		boss.shielded = false
