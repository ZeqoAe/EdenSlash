class_name Monster
extends Combatant
## Monstre d'Eden Eternal piloté par une petite machine à états :
## errance -> poursuite -> attaque, avec recul et mort animée.

const LEASH_RADIUS := 90.0
const ATTACK_COOLDOWN := 1.8
const HIT_FRACTION := 0.45

var data: Dictionary
var is_boss := false
var is_elite := false
var enraged := false
var aggro_radius := 16.0
var xp_reward := 0
var move_speed := 3.2

var _state := "spawn"  # spawn, idle, chase, attack, hurt, dead
var _state_time := 0.0
var _state_len := 0.0
var _hit_done := false
var _attack_ready_at := 0.0
var _wander_target := Vector3.ZERO
var _knock := Vector3.ZERO
var _time := 0.0
var _attacks: Array[String] = []
var _player: Player
var _base_scale := Vector3.ONE
var _hit_time := 0.45
var _map: Node3D  # ProcMap ou MapLoader (path_between)
var _path := PackedVector3Array()
var _path_timer := 0.0
var _status_label: Label3D


## [param at_level] > 0 : remet le monstre à ce niveau (donjons), en suivant la
## progression des monstres d'Eden (~ +10 % de PV / attaque / XP par niveau).
func configure(monster_data: Dictionary, boss := false, at_level := 0) -> void:
	data = monster_data
	is_boss = boss
	is_elite = int(data.get("rank", 2)) == 3
	display_name = data.name
	level = int(data.level)
	var k := 1.0
	if at_level > level:
		k = pow(1.1, at_level - level)
		level = at_level
	max_hp = float(data.hp) * k * (14.0 if boss else 1.0)
	hp = max_hp
	atk = float(data.atk) * k * GameData.MONSTER_DAMAGE_FACTOR * (1.5 if boss else (1.25 if is_elite else 1.0))
	defense = float(data.get("def", 0)) * k
	xp_reward = int(float(data.xp) * k * (8.0 if boss else (4.0 if is_elite else 1.0)))
	move_speed = randf_range(2.6, 3.6) * (0.85 if boss else 1.0)


func _ready() -> void:
	team = Team.MONSTER
	collision_layer = GameData.PHYS_MONSTER
	collision_mask = GameData.PHYS_WORLD | GameData.PHYS_PLAYER
	add_to_group("monsters")
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.7
	var base := "res://assets/monsters/%s/%s" % [data.model, data.model]
	var tex := "res://assets/monsters/textures/%s.png" % data.texture
	var s := float(data.scale) * GameData.MONSTER_SCALE * (1.6 if is_boss else (1.25 if is_elite else 1.0))
	setup_model(base + ".glb", tex if ResourceLoader.exists(tex) else "", s)
	_base_scale = model.scale
	for a in ["attack01", "attack02", "attack03"]:
		if has_anim(a):
			_attacks.append(a)
	_player = get_tree().get_first_node_in_group("player") as Player
	_map = get_tree().get_first_node_in_group("map") as Node3D
	_status_label = Label3D.new()
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	_status_label.fixed_size = true
	_status_label.pixel_size = 0.0009
	_status_label.font_size = 26
	_status_label.outline_size = 8
	_status_label.position = Vector3(0, radius * 2.2 + 1.8, 0)
	add_child(_status_label)
	statuses_changed.connect(_refresh_status_label)
	_wander_target = global_position
	# apparition : le monstre surgit du sol
	model.position.y = -2.0
	create_tween().tween_property(model, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	play("battle01" if has_anim("battle01") else "stand01")
	_attack_ready_at = randf_range(0.5, 1.5)
	if is_boss:
		brain = BossBrain.new()
		brain.boss = self
		add_child(brain)


var brain: BossBrain


## Attaque spéciale en cours (boss) : le monstre reste sur place.
func begin_cast() -> void:
	_set_state("cast")


func end_cast() -> void:
	if _state == "cast":
		_set_state("chase")


## Rage (après 10 minutes de run) : plus fort, plus rapide, rapporte plus.
func enrage() -> void:
	if enraged or is_dead:
		return
	enraged = true
	atk *= 1.3
	move_speed *= 1.25
	xp_reward = int(xp_reward * 1.5)
	aggro_radius = maxf(aggro_radius, 40.0)
	var aura := OmniLight3D.new()
	aura.light_color = Color(1.0, 0.15, 0.1)
	aura.light_energy = 0.7
	aura.omni_range = radius * 2.0 + 1.0
	aura.shadow_enabled = false
	aura.position.y = 1.0
	add_child(aura)


func _refresh_status_label() -> void:
	var parts: PackedStringArray = []
	for s in statuses:
		if STATUS_INFO.has(s):
			parts.append(STATUS_INFO[s].name)
	_status_label.text = " · ".join(parts)
	_status_label.modulate = STATUS_INFO[statuses.keys()[0]].color if not statuses.is_empty() and STATUS_INFO.has(statuses.keys()[0]) else Color.WHITE


func _physics_process(delta: float) -> void:
	_time += delta
	_state_time += delta
	tick_statuses(delta)
	apply_gravity(delta)
	if has_status("stun") and not is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		play("hurt01" if has_anim("hurt01") else "stand01", 0.1)
		move_and_slide()
		return
	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var desired := Vector3.ZERO
	match _state:
		"spawn":
			if _state_time > 0.5:
				_set_state("idle")
		"idle":
			desired = _update_idle(delta)
		"chase":
			desired = _update_chase(delta)
		"attack":
			_update_attack(delta)
		"cast":
			if _player_alive():
				face_direction(_player.global_position - global_position, delta, 2.0)
		"hurt":
			if _state_time > 0.28:
				_set_state("chase")

	desired += _separation() * 1.8
	_knock = _knock.move_toward(Vector3.ZERO, 14.0 * delta)
	velocity.x = desired.x + _knock.x
	velocity.z = desired.z + _knock.z
	move_and_slide()


func _set_state(s: String) -> void:
	_state = s
	_state_time = 0.0


func _player_alive() -> bool:
	return _player != null and not _player.is_dead


func _update_idle(delta: float) -> Vector3:
	if _player_alive() and global_position.distance_to(_player.global_position) < aggro_radius:
		_set_state("chase")
		return Vector3.ZERO
	if global_position.distance_to(_wander_target) < 0.6 or _state_time > 5.0:
		_wander_target = global_position + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		_state_time = 0.0
	var to := _wander_target - global_position
	to.y = 0.0
	if to.length() > 0.6 and _state_time > 1.2:
		face_direction(to, delta, 6.0)
		play("move01", 0.2)
		return to.normalized() * move_speed * 0.4
	play("stand01" if has_anim("stand01") else "battle01", 0.3)
	return Vector3.ZERO


func _update_chase(delta: float) -> Vector3:
	if not _player_alive() or global_position.distance_to(_player.global_position) > LEASH_RADIUS:
		_set_state("idle")
		return Vector3.ZERO
	var to := _player.global_position - global_position
	to.y = 0.0
	var reach := radius + _player.radius + 0.9
	face_direction(to, delta, 10.0)
	if to.length() <= reach:
		if _time >= _attack_ready_at and not _attacks.is_empty():
			_start_attack()
		else:
			play("battle01" if has_anim("battle01") else "stand01", 0.2)
		return Vector3.ZERO
	play("move02" if has_anim("move02") else "move01", 0.2)
	var step := _path_step(_player.global_position)
	face_direction(step, delta, 10.0)
	return step * move_speed


## Direction de marche vers [param goal] en suivant le maillage de navigation
## (contourne rochers et piliers) ; ligne droite à courte distance.
func _path_step(goal: Vector3) -> Vector3:
	var to := goal - global_position
	to.y = 0.0
	if to.length() < 5.0 or _map == null:
		return to.normalized()
	_path_timer -= get_physics_process_delta_time()
	if _path_timer <= 0.0:
		_path_timer = randf_range(0.4, 0.7)
		_path = _map.path_between(global_position, goal)
	for p in _path:
		var d := p - global_position
		d.y = 0.0
		if d.length() > 1.2:
			return d.normalized()
	return to.normalized()

func _start_attack() -> void:
	var a: String = _attacks.pick_random()
	_set_state("attack")
	_state_len = anim_length(a)
	_hit_done = false
	var keys := keys_of(a)
	var hits: Array = keys.get("hit", [])
	_hit_time = float(hits[0]) if not hits.is_empty() else _state_len * HIT_FRACTION
	for snd in keys.get("sounds", []):
		get_tree().create_timer(float(snd[0]), false).timeout.connect(
			func(): Sfx.play_at(self, global_position, String(snd[1]), -8.0))
	play(a, 0.1, 1.0, true)


func _update_attack(delta: float) -> void:
	if _player_alive():
		face_direction(_player.global_position - global_position, delta, 4.0)
	if not _hit_done and _state_time >= _hit_time:
		_hit_done = true
		if _player_alive():
			var d := global_position.distance_to(_player.global_position)
			if d <= radius + _player.radius + 1.4:
				var crit := randf() < 0.05
				_player.take_damage(atk * damage_dealt_mult() * randf_range(0.85, 1.15) * (1.5 if crit else 1.0), self, crit)
	if _state_time >= _state_len:
		_attack_ready_at = _time + ATTACK_COOLDOWN * randf_range(0.8, 1.3)
		_set_state("chase")


## Évite que les monstres s'empilent les uns sur les autres.
func _separation() -> Vector3:
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("monsters"):
		if node == self:
			continue
		var o := node as Monster
		var to := global_position - o.global_position
		to.y = 0.0
		var min_d := radius + o.radius
		var d := to.length()
		if d < min_d and d > 0.001:
			push += to / d * (min_d - d)
	return push


func knockback(impulse: Vector3) -> void:
	if is_boss or is_elite:
		impulse *= 0.2
	_knock += Vector3(impulse.x, 0, impulse.z)


func _on_damaged(_amount: float, _source: Combatant) -> void:
	if randf() < 0.5:
		for snd in keys_of("hurt01").get("sounds", []):
			Sfx.play_at(self, global_position, String(snd[1]), -10.0)
	# petit gonflement à l'impact
	if model:
		model.scale = _base_scale * 1.08
		create_tween().tween_property(model, "scale", _base_scale, 0.12)
	if _state != "attack" and not is_boss and not is_elite:
		_set_state("hurt")
		play("hurt01" if has_anim("hurt01") else "battle01", 0.05, 1.0, true)
	elif _state == "idle":
		_set_state("chase")


func _on_death(_killer: Combatant) -> void:
	_set_state("dead")
	remove_from_group("monsters")
	collision_layer = 0
	collision_mask = GameData.PHYS_WORLD
	play("death01", 0.05, 1.0, true)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(model, "position:y", -1.5, 0.8)
	tw.tween_callback(queue_free)
