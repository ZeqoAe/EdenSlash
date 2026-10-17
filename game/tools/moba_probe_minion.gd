extends Monster
## Sbire (ou monstre de camp) du banc MB-0 (tools/moba_probe.gd) : suit la courbe de sa voie ; vise, à portée d'aggro, le
## sbire ennemi le plus proche, sinon une structure, sinon un héros (réévalué toutes les 0,5 s, décalé). Réglages du banc :
## marche (probe.nav_mode), cibles (grille ou groupes), coup léger sans zone rouge, recyclage. Aucun class_name (banc).

var probe: Node
var side := 0
var lane := 0
var ranged := false
var camp := false
var mb_kind := 2
var mb_side := 0
var wp_i := 1
var lat := 0.0  # décalage latéral dans la voie (m)
var _rt := 0.0
var _agent: NavigationAgent3D
var _safe := Vector3.ZERO
var _dead_t := -1.0


func _ready() -> void:
	super._ready()
	_retarget_t = 1.0e9  # (cible choisie par le banc, voir _physics_process)
	if camp:
		mb_kind = 0
		passive = true
		remove_from_group("monsters")  # neutre : ni cible ni écartement (MB-F fera la neutralité)
		return
	_set_side()
	lat = randf_range(-3.0, 3.0)
	_rt = randf() * 0.5
	if probe.nav_mode == "agent":
		_agent = NavigationAgent3D.new()
		_agent.radius = 0.6
		_agent.height = 1.8
		_agent.max_speed = move_speed * 1.2
		_agent.path_desired_distance = 1.5
		_agent.target_desired_distance = 1.5
		_agent.avoidance_enabled = true
		_agent.neighbor_distance = 6.0
		_agent.max_neighbors = 8
		add_child(_agent)
		_agent.velocity_computed.connect(func(v: Vector3): _safe = v)


func _set_side() -> void:
	mb_side = side
	if side == 0:
		team = Team.PLAYER
		collision_layer = GameData.PHYS_PLAYER
		collision_mask = GameData.PHYS_WORLD | GameData.PHYS_MONSTER
		remove_from_group("monsters")
		add_to_group("heroes")  # (les coups des héros rouges passent par Combatant.hostile_heroes)
	else:
		team = Team.MONSTER
		collision_layer = GameData.PHYS_MONSTER
		collision_mask = GameData.PHYS_WORLD | GameData.PHYS_PLAYER
		remove_from_group("heroes")
		add_to_group("monsters")


func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	if camp:
		super._physics_process(delta)
		probe.cost["camp"] += Time.get_ticks_usec() - t0
		return
	if is_dead:
		if _dead_t >= 0.0:
			_dead_t -= delta
			if _dead_t < 0.0:
				_park()
				probe.release_minion(self)
				probe.cost["minion"] += Time.get_ticks_usec() - t0
				return
	else:
		_rt -= delta
		if _rt <= 0.0:
			_rt = 0.5
			_player = probe.minion_target(self)
	super._physics_process(delta)
	probe.cost["minion"] += Time.get_ticks_usec() - t0


func _update_idle(delta: float) -> Vector3:
	if is_passive():
		return super._update_idle(delta)
	if _can_target():
		_set_state("chase")
		return Vector3.ZERO
	return _lane_step(delta)


func _update_chase(delta: float) -> Vector3:
	if not _can_target():
		_set_state("idle")
		return _lane_step(delta)
	return super._update_chase(delta)


## Marche le long de la voie (vers le Cœur ennemi).
func _lane_step(delta: float) -> Vector3:
	var wps: PackedVector3Array = probe.lane_wp[lane][side]
	var perp: PackedVector3Array = probe.lane_perp[lane][side]
	wp_i = clampi(wp_i, 0, wps.size() - 1)
	var goal := wps[wp_i] + perp[wp_i] * lat
	var to := goal - global_position
	to.y = 0.0
	if to.length() < 2.5 and wp_i < wps.size() - 1:
		wp_i += 1
		goal = wps[wp_i] + perp[wp_i] * lat
		to = goal - global_position
		to.y = 0.0
	if wp_i >= wps.size() - 1 and to.length() < 2.5:
		play("battle01" if has_anim("battle01") else "stand01", 0.2)
		return Vector3.ZERO
	var v := Vector3.ZERO
	match probe.nav_mode:
		"agent":
			if _agent.target_position.distance_squared_to(goal) > 1.0:
				_agent.target_position = goal
			var nxt := _agent.get_next_path_position()
			var d := nxt - global_position
			d.y = 0.0
			_agent.velocity = d.normalized() * move_speed
			v = _safe if _safe.length() > 0.05 else d.normalized() * move_speed
		"path":
			v = super._path_step(goal) * move_speed
		_:
			v = to.normalized() * move_speed
	play("move02" if has_anim("move02") else "move01", 0.2)
	face_direction(v, delta, 8.0)
	return v


## Poursuite : en ligne droite avec la courbe de voie (« flow » : la cible est à moins de 11 m) ; chemin de navigation sinon.
func _path_step(goal: Vector3) -> Vector3:
	if probe.nav_mode == "flow":
		var to := goal - global_position
		to.y = 0.0
		return to.normalized()
	return super._path_step(goal)


func _separation() -> Vector3:
	if probe.grid_on:
		return probe.separation(self)
	return super._separation()


func _separation_lite() -> Vector3:
	if probe.grid_on:
		return probe.separation(self)
	return super._separation_lite()


# --- coups ----------------------------------------------------------------------------------

## Coup léger (banc --light=1) : l'animation et le coup, sans zone rouge (Telegraph) ni Projectile du jeu.
func _start_attack() -> void:
	if not probe.light_on:
		super._start_attack()
		return
	var a: String = "shoot01" if ranged and has_anim("shoot01") else String(_attacks.pick_random())
	_set_state("attack")
	var length := maxf(anim_length(a), 0.4)
	_state_len = length
	_hit_time = minf(length * HIT_FRACTION, 0.6)
	_hit_done = false
	play(a, 0.1, 1.0, true)
	var to := _player.global_position - global_position
	to.y = 0.0
	face_direction(to, 1.0, 100.0)


func _update_attack(delta: float) -> void:
	if probe.light_on:
		if not _hit_done and _state_time >= _hit_time:
			_hit_done = true
			if _player_alive():
				var dmg := atk * damage_dealt_mult()
				if ranged:
					probe.fire_bolt(self, _player, dmg)
				elif global_position.distance_to(_player.global_position) <= radius + _player.radius + 1.8:
					_player.take_damage(dmg, self)
		if _state_time >= _state_len:
			_attack_ready_at = _time + ATTACK_COOLDOWN * randf_range(0.8, 1.3)
			_set_state("chase")
		return
	if probe.pool_bolts and not _pending_shot.is_empty() and not _hit_done and _state_time >= _hit_time:
		# (zone rouge du jeu gardée, tir remplacé par un trait du banc)
		_hit_done = true
		_pending_shot = {}
		if _player_alive():
			probe.fire_bolt(self, _player, atk * damage_dealt_mult())
	super._update_attack(delta)


# --- mort et recyclage ----------------------------------------------------------------------

func _on_death(killer: Combatant) -> void:
	probe.on_minion_death(self)
	if not probe.pool_on:
		tree_exited.connect(func(): probe.forget_minion(self))
		super._on_death(killer)
		return
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_set_state("dead")
	if lite:
		lod = 0
		if anim:
			anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	remove_from_group("monsters")
	remove_from_group("heroes")
	collision_layer = 0
	collision_mask = GameData.PHYS_WORLD
	play("death01", 0.05, 1.0, true)
	_dead_t = 1.6


func _park() -> void:
	visible = false
	set_physics_process(false)
	global_position = Vector3(0, -50, 0)


## Remis en jeu par le banc (vague suivante) à [param at], point de passage [param i].
func reuse(at: Vector3, i: int) -> void:
	is_dead = false
	hp = max_hp
	statuses.clear()
	_state = "spawn"
	_state_time = 0.0
	_attack_ready_at = _time + randf_range(0.5, 1.5)
	_player = null
	_pending_shot = {}
	_hit_done = true
	_knock = Vector3.ZERO
	_dash_until = 0.0
	_dead_t = -1.0
	wp_i = i
	lat = randf_range(-3.0, 3.0)
	_rt = randf() * 0.5
	lod = 0
	_set_side()
	visible = true
	set_physics_process(true)
	global_position = at
	if model:
		model.position.y = 0.0
		model.scale = _base_scale
	if anim:
		anim.speed_scale = 1.0
		if lite:
			anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	play("battle01" if has_anim("battle01") else "stand01", 0.0, 1.0, true)
