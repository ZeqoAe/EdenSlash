extends ClassRival
## Héros du banc MB-0 (tools/moba_probe.gd) : le ClassRival du jeu, cibles prises parmi les héros et sbires ennemis à
## 22 m (structures ignorées) ; sans adversaire, il marche vers le front de sa vague (Battle royale : [member goal]). Mort :
## caché 5 s puis remis à sa voie, sans recréer le modèle (le banc garde une charge constante). Aucun class_name (banc).

var probe: Node
var side := 0
var role_lane := 0  # 0 Soleil, 1 Brumes, -1 jungle
var mb_kind := 1
var mb_side := 0
var attacks := 0
var _rt := 0.0
var _dead_t := -1.0
var respawn := 5.0  # s (MOBA.md : 7 à 29 s ; court ici pour garder les 8 héros en jeu)


func _ready() -> void:
	super._ready()
	_retarget_t = 1.0e9  # (cible choisie par le banc)
	_rt = randf() * 0.5


func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	if is_dead:
		_dead_t -= delta
		if _dead_t <= 0.0:
			_revive()
		probe.cost["hero"] += Time.get_ticks_usec() - t0
		return
	_rt -= delta
	if _rt <= 0.0 or not _player_alive():
		_rt = 0.5
		var pool: Array = probe.hero_pool(self)
		if pool.is_empty():
			goal = probe.hero_goal(self)
			_player = probe.cores[1 - side]  # (toujours debout : garde la machine à états en marche vers le but)
		else:
			goal = Vector3.INF
			_player = pick_target(pool, _player if _player_alive() else null)
	super._physics_process(delta)
	probe.cost["hero"] += Time.get_ticks_usec() - t0


func _start_attack() -> void:
	attacks += 1
	super._start_attack()


func _on_death(_killer: Combatant) -> void:
	probe.events.hero_deaths += 1
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_set_state("dead")
	visible = false
	collision_layer = 0
	global_position = probe.fountain(side)
	_dead_t = respawn


func _revive() -> void:
	is_dead = false
	hp = max_hp
	statuses.clear()
	statuses_changed.emit()
	_burst.clear()
	visible = true
	collision_layer = GameData.PHYS_PLAYER if ally else GameData.PHYS_MONSTER
	_state = "idle"
	_state_time = 0.0
	_player = null
	_rt = 0.0
	global_position = probe.spawn_point(self)
