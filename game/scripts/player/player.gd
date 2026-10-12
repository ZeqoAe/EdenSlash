class_name Player
extends Combatant
## Héros contrôlé par le joueur, piloté par les données de sa classe
## (data/classes.json) : modèle, arme, attaques de base, 4 compétences de run.

signal xp_changed(xp: int, xp_next: int, level: int)
signal leveled_up(level: int)
signal skills_changed
signal stats_changed

const JUMP_VELOCITY := 9.5
const STEP_HEIGHT := 0.6
const HERO_RADIUS := 0.33
const BASE_SPEED := 6.5
const DODGE_DISTANCE := 6.0
const DODGE_TIME := 0.32
const DODGE_COOLDOWN := 0.7
const ATTACK_RANGE := 2.6

var class_id := "samurai"
var cls: Dictionary
var xp := 0

# statistiques dérivées (niveau + équipement + passifs + buffs)
var crit := 0.05
var crit_dmg := 0.5
var atk_speed := 1.0
var move_mult := 1.0
var cdr := 0.0
var lifesteal := 0.0

var skill_ready_at := {}  # id compétence -> instant
var autoplay := false
var autoplay_target := Vector3.INF

var _state := "idle"  # idle, attack, skill, dodge, jump, dead
var _state_time := 0.0
var _state_len := 0.0
var _hits: Array = []  # instants d'impact restants de l'action en cours
var _action: Dictionary = {}  # compétence / attaque en cours
var _combo_index := 0
var _target: Combatant  # cible verrouillée par clic (auto-attaque)
var _dodge_dir := Vector3.ZERO
var _dodge_ready_at := 0.0
var _last_combat := -100.0
var _time := 0.0
var _weapon: Node3D
var _blade_tip: Node3D
var _blade_base: Node3D
var _trail: MeshInstance3D
var _trail_points: Array = []
var _trail_on := false

var _stuck_time := 0.0
var _safe_positions: Array[Vector3] = []
var _safe_timer := 0.0
var _torch: OmniLight3D
var _bot_last_pos := Vector3.ZERO
var _bot_check_at := 0.0
var _bot_detour := Vector3.ZERO
var _bot_detour_until := 0.0


func _ready() -> void:
	team = Team.PLAYER
	collision_layer = GameData.PHYS_PLAYER
	collision_mask = GameData.PHYS_WORLD | GameData.PHYS_MONSTER
	add_to_group("player")
	class_id = Run.class_id if Run.active else Profile.selected_class
	cls = GameData.class_data(class_id)
	display_name = cls.get("name_fr", "Héros")
	kfm = "m"
	setup_model(cls.get("model", "res://assets/player/samurai/samurai.glb"), "", GameData.HERO_SCALE)
	_slim_collision()
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.7
	_attach_weapon(Profile.weapon_code())
	_build_trail()
	Run.changed.connect(recalc_stats)
	statuses_changed.connect(recalc_stats)
	Profile.changed.connect(_on_profile_changed)
	recalc_stats()
	hp = max_hp
	health_changed.emit(hp, max_hp)
	play(_anim("idle"))


func _anim(key: String) -> String:
	return String(cls.get("anims", {}).get(key, key))


# --- statistiques -------------------------------------------------------------------
func recalc_stats() -> void:
	var eq := Profile.equipment_stats()
	var ps := Run.passive_stats()
	var ratio := hp / max_hp if max_hp > 0.0 else 1.0
	max_hp = GameData.player_max_hp(level) * (1.0 + ps.get("hp_pct", 0.0)) + eq.get("hp", 0.0)
	atk = (GameData.player_atk(level) + eq.get("atk", 0.0)) * (1.0 + ps.get("atk_pct", 0.0))
	if has_status("marduk"):
		atk *= 1.3
	defense = 4.0 + level * 2.0 + eq.get("def", 0.0)
	crit = 0.05 + eq.get("crit", 0.0) + ps.get("crit", 0.0)
	crit_dmg = 0.5 + eq.get("crit_dmg", 0.0) + ps.get("crit_dmg", 0.0)
	atk_speed = 1.0 + eq.get("atk_speed", 0.0) + ps.get("atk_speed", 0.0) + (0.3 if has_status("marduk") else 0.0)
	move_mult = 1.0 + eq.get("move_speed", 0.0) + ps.get("move_speed", 0.0) + (0.3 if has_status("shrine") else 0.0)
	cdr = clampf(eq.get("cdr", 0.0) + ps.get("cdr", 0.0), 0.0, 0.5)
	lifesteal = eq.get("lifesteal", 0.0) + ps.get("lifesteal", 0.0)
	hp = clampf(max_hp * ratio, 1.0, max_hp)
	health_changed.emit(hp, max_hp)
	xp_changed.emit(xp, GameData.xp_to_next(level), level)
	stats_changed.emit()
	skills_changed.emit()


## Tableau des statistiques affiché dans le menu Personnage.
func stat_sheet() -> Array:
	return [
		["Niveau", str(level)], ["PV", "%d / %d" % [hp, max_hp]], ["Attaque", str(int(atk))],
		["Défense", str(int(defense))], ["Critique", "%d %%" % roundi(crit * 100)],
		["Dégâts critiques", "+%d %%" % roundi(crit_dmg * 100)],
		["Vitesse d'attaque", "%d %%" % roundi(atk_speed * 100)],
		["Vitesse", "%d %%" % roundi(move_mult * 100)], ["Recharge", "-%d %%" % roundi(cdr * 100)],
		["Vol de vie", "%d %%" % roundi(lifesteal * 100)],
	]


func _on_profile_changed() -> void:
	_attach_weapon(Profile.weapon_code())
	recalc_stats()


func gain_xp(amount: int) -> void:
	if is_dead:
		return
	xp += amount
	while xp >= GameData.xp_to_next(level):
		xp -= GameData.xp_to_next(level)
		level += 1
		Run.max_level = maxi(Run.max_level, level)
		recalc_stats()
		hp = max_hp
		health_changed.emit(hp, max_hp)
		leveled_up.emit(level)
	xp_changed.emit(xp, GameData.xp_to_next(level), level)


# --- arme et traînée --------------------------------------------------------------
func _attach_weapon(code: String) -> void:
	if _weapon:
		_weapon.queue_free()
		_weapon = null
	_weapon = EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, code))
	if _weapon:
		_blade_base = _weapon.find_child("W1", true, false) as Node3D
		_blade_tip = _weapon.find_child("W2", true, false) as Node3D


func _build_trail() -> void:
	_trail = MeshInstance3D.new()
	_trail.mesh = ImmediateMesh.new()
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	_trail.material_override = m
	add_child(_trail)


func _update_trail() -> void:
	var mesh := _trail.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if _blade_base == null or _blade_tip == null:
		return
	if _trail_on:
		_trail_points.append([_blade_base.global_position, _blade_tip.global_position])
	if _trail_points.size() > 10 or (not _trail_on and not _trail_points.is_empty()):
		_trail_points.pop_front()
	if _trail_points.size() < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _trail_points.size():
		var a := float(i) / (_trail_points.size() - 1)
		var c := Color(1.0, 0.9, 0.75, a * 0.75)
		mesh.surface_set_color(Color(c.r, c.g, c.b, 0.0))
		mesh.surface_add_vertex(_trail_points[i][0])
		mesh.surface_set_color(c)
		mesh.surface_add_vertex(_trail_points[i][1])
	mesh.surface_end()


# --- boucle -------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_time += delta
	_state_time += delta
	tick_statuses(delta)
	apply_gravity(delta)
	if is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	var input_dir := _read_move_input()
	if input_dir.length() > 0.1:
		_target = null  # se déplacer annule l'auto-attaque
	match _state:
		"idle":
			_update_idle(input_dir, delta)
		"attack", "skill":
			_update_action(input_dir, delta)
		"dodge":
			_update_dodge()
		"jump":
			_update_jump(input_dir, delta)
	var before := global_position
	move_and_slide()
	_handle_obstacles(input_dir, before, delta)
	_update_trail()
	if _time - _last_combat > 5.0 and hp < max_hp:
		heal(max_hp * 0.04 * delta)


func _speed() -> float:
	return BASE_SPEED * move_mult


func _read_move_input() -> Vector3:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if autoplay:
		v = _autoplay_input()
	var cam := get_viewport().get_camera_3d()
	if cam == null or v == Vector2.ZERO:
		return Vector3(v.x, 0, v.y)
	return Vector3(v.x, 0, v.y).rotated(Vector3.UP, cam.global_rotation.y)


func _update_idle(input_dir: Vector3, delta: float) -> void:
	var move := input_dir
	# auto-attaque : on rejoint la cible verrouillée puis on frappe
	if _target and (not is_instance_valid(_target) or _target.is_dead):
		_target = null
	if _target and move.length() < 0.1:
		var to := _target.global_position - global_position
		to.y = 0.0
		if to.length() > ATTACK_RANGE + _target.radius:
			move = to.normalized()
		else:
			face_direction(to, delta, 30.0)
			_start_attack(_target.global_position)
			return
	velocity.x = move.x * _speed()
	velocity.z = move.z * _speed()
	if move.length() > 0.1:
		face_direction(move, delta)
		play(_anim("run"), 0.12, move_mult)
	else:
		play(_anim("battle") if _time - _last_combat < 4.0 else _anim("idle"), 0.25)
	if _time - _last_combat > 1.2:
		_combo_index = 0

	if _wants("jump") and is_on_floor():
		_start_jump()
	elif _wants("dodge") and _time >= _dodge_ready_at:
		_start_dodge(input_dir)
	else:
		for i in 4:
			if _wants("skill_%d" % (i + 1)):
				use_skill(i)
				return
		if _wants("attack"):
			_on_attack_pressed()


func _wants(action: String) -> bool:
	if autoplay:
		return _autoplay_wants(action)
	if action == "attack":
		return Input.is_action_pressed(action) and not _ui_has_mouse()
	return Input.is_action_just_pressed(action)


func _ui_has_mouse() -> bool:
	return get_viewport().gui_get_hovered_control() != null


## Clic gauche : verrouille le monstre sous le curseur (auto-attaque),
## sinon frappe en direction du curseur.
func _on_attack_pressed() -> void:
	if Input.is_action_just_pressed("attack"):
		var m := monster_under_mouse()
		if m:
			_target = m
			return
	var aim := mouse_ground_point() if not autoplay else Vector3.INF
	if aim == Vector3.INF:
		var n := nearest_monster(6.0)
		aim = n.global_position if n else global_position + forward()
	_start_attack(aim)


func monster_under_mouse() -> Combatant:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var to := from + cam.project_ray_normal(mp) * 120.0
	var q := PhysicsRayQueryParameters3D.create(from, to, GameData.PHYS_MONSTER | GameData.PHYS_WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var m := hit.collider as Monster
	return m if m and not m.is_dead else null


# --- attaques de base ---------------------------------------------------------------
func _start_attack(aim: Vector3) -> void:
	var attacks: Array = cls.get("anims", {}).get("attacks", ["attack01"])
	var anim_name: String = attacks[_combo_index % attacks.size()]
	_combo_index += 1
	face_direction(aim - global_position, 1.0, 100.0)
	_begin_action("attack", anim_name, atk_speed * 1.25, {
		"mult": 1.0 + 0.1 * ((_combo_index - 1) % attacks.size()), "radius": ATTACK_RANGE, "arc": 150.0})


func _begin_action(state: String, anim_name: String, speed: float, action: Dictionary) -> void:
	_state = state
	_state_time = 0.0
	_action = action
	var keys := keys_of(anim_name)
	var length := anim_length(anim_name)
	_state_len = length / speed
	_hits = []
	var key_hits: Array = keys.get("hit", [])
	var n_hits := int(action.get("hits", maxi(key_hits.size(), 1)))
	if key_hits.size() >= n_hits:
		for t in key_hits.slice(key_hits.size() - n_hits):
			_hits.append(float(t) / speed)
	else:
		# coups répartis sur la partie active de l'animation
		var t0 := float(key_hits[0]) if not key_hits.is_empty() else length * 0.4
		for i in n_hits:
			_hits.append(lerpf(t0, length * 0.8, float(i) / maxf(n_hits - 1, 1)) / speed)
	for snd in keys.get("sounds", []):
		get_tree().create_timer(float(snd[0]) / speed, false).timeout.connect(
			func(): Sfx.play_at(self, global_position, String(snd[1]), -4.0))
	var trail: Array = keys.get("trail", [])
	_action["trail"] = [float(trail[0]) / speed, float(trail[-1]) / speed] if trail.size() >= 2 else [_hits[0] - 0.12, _hits[-1] + 0.08]
	_last_combat = _time
	play(anim_name, 0.06, speed, true)


func _update_action(input_dir: Vector3, delta: float) -> void:
	var dash: float = _action.get("dash", 0.0)
	var push := Vector3.ZERO
	if dash > 0.0 and not _hits.is_empty():
		push = forward() * (dash / maxf(_hits[0], 0.1))
	elif _state == "attack" and _state_time < _state_len * 0.35:
		push = forward() * 1.2
	velocity.x = push.x + input_dir.x * 0.8
	velocity.z = push.z + input_dir.z * 0.8
	var tr: Array = _action.get("trail", [0.0, 0.0])
	_trail_on = _state_time >= tr[0] and _state_time <= tr[1]
	while not _hits.is_empty() and _state_time >= _hits[0]:
		_hits.pop_front()
		_resolve_hit()
	# l'esquive annule l'action après le premier impact
	if _wants("dodge") and _time >= _dodge_ready_at and _action.get("hit_done", false):
		_trail_on = false
		_start_dodge(input_dir)
		return
	var end := _state_len * (0.75 if _state == "attack" else 0.92)
	if _state_time >= end and _hits.is_empty():
		_trail_on = false
		_state = "idle"


## Applique les dégâts de l'action en cours à tous les monstres de la zone.
func _resolve_hit() -> void:
	_action["hit_done"] = true
	var radius: float = _action.get("radius", ATTACK_RANGE)
	var arc: float = _action.get("arc", 150.0)
	var fwd := forward()
	var hits := 0
	if _action.get("kind", "") != "buff":
		Vfx.slash(self, global_position, fwd, radius, arc,
			Color(1.0, 0.8, 0.5, 0.85) if _state == "attack" else Color(1.0, 0.45, 0.25, 0.9))
	for node in get_tree().get_nodes_in_group("monsters"):
		var m := node as Monster
		if m == null or m.is_dead:
			continue
		var to := m.global_position - global_position
		to.y = 0.0
		var dist := to.length() - m.radius
		if dist > radius:
			continue
		if arc < 360.0 and dist > 0.6 and rad_to_deg(fwd.angle_to(to.normalized())) > arc * 0.5:
			continue
		_hit_monster(m, to.normalized())
		hits += 1
	if hits > 0:
		_last_combat = _time
		_hit_pause(0.04 if hits < 4 else 0.06)


func _hit_monster(m: Monster, dir: Vector3) -> void:
	var mult: float = _action.get("mult", 1.0)
	var combo: Dictionary = _action.get("combo", {})
	var combo_ok: bool = not combo.is_empty() and m.has_status(String(combo.get("requires", "")))
	if combo_ok and combo.get("double", false):
		mult *= 2.0
	var is_crit := randf() < crit
	var dmg := atk * mult * randf_range(0.92, 1.08) * damage_dealt_mult() * (1.0 + crit_dmg if is_crit else 1.0)
	m.take_damage(dmg, self, is_crit)
	if lifesteal > 0.0:
		heal(dmg * lifesteal)
	Vfx.spark(self, m.global_position + Vector3.UP * 1.0, Color(1.0, 0.85, 0.5), is_crit)
	m.knockback(dir * (2.5 if _state == "skill" else 1.0))
	for s in _action.get("applies", {}):
		m.add_status(s, float(_action.applies[s]), self)
	if combo_ok:
		for s in combo.get("applies", {}):
			m.add_status(s, float(combo.applies[s]), self)
		for b in combo.get("buff", {}):
			add_status(b, float(combo.buff[b]), self)
			recalc_stats()


## Micro-arrêt sur impact : donne du poids aux coups.
func _hit_pause(duration: float) -> void:
	Engine.time_scale = 0.15
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


# --- compétences --------------------------------------------------------------------
func skill_in_slot(slot: int) -> Dictionary:
	if slot >= Run.skills.size():
		return {}
	return Run.skill_def(int(Run.skills[slot].id))


func skill_cooldown(s: Dictionary) -> float:
	return float(s.cooldown) * Run.skill_cooldown_mult(int(s.id)) * (1.0 - cdr)


func cooldown_left(slot: int) -> float:
	var s := skill_in_slot(slot)
	if s.is_empty():
		return 0.0
	return maxf(0.0, float(skill_ready_at.get(int(s.id), 0.0)) - _time)


func use_skill(slot: int) -> void:
	var s := skill_in_slot(slot)
	if s.is_empty() or cooldown_left(slot) > 0.0:
		return
	skill_ready_at[int(s.id)] = _time + skill_cooldown(s)
	var aim := mouse_ground_point() if not autoplay else Vector3.INF
	if _target and is_instance_valid(_target):
		aim = _target.global_position
	elif aim == Vector3.INF or aim.distance_to(global_position) > 14.0:
		var n := nearest_monster(10.0)
		aim = n.global_position if n else global_position + forward()
	face_direction(aim - global_position, 1.0, 100.0)
	var action := {
		"kind": s.kind, "mult": float(s.mult) * Run.skill_damage_mult(int(s.id)),
		"radius": float(s.radius), "arc": float(s.arc), "hits": int(s.get("hits", 1)),
		"dash": float(s.get("dash", 0.0)), "applies": s.get("applies", {}), "combo": s.get("combo", {}),
	}
	for b in s.get("buff", {}):
		add_status(b, float(s.buff[b]), self)
	if s.kind == "buff" or s.kind == "spin":
		Vfx.ring(self, global_position, maxf(float(s.radius), 2.5), Color(1.0, 0.8, 0.35, 0.8))
	recalc_stats()
	_begin_action("skill", String(s.anim), 1.15 * atk_speed, action)


# --- déplacements spéciaux ----------------------------------------------------------
func _start_jump() -> void:
	_state = "jump"
	_state_time = 0.0
	velocity.y = JUMP_VELOCITY
	play(_anim("jump"), 0.05, 1.25, true)


func _update_jump(input_dir: Vector3, delta: float) -> void:
	velocity.x = input_dir.x * _speed()
	velocity.z = input_dir.z * _speed()
	if input_dir.length() > 0.1:
		face_direction(input_dir, delta)
	if _state_time > 0.2 and is_on_floor():
		_state = "idle"


func _start_dodge(input_dir: Vector3) -> void:
	_dodge_dir = input_dir.normalized() if input_dir.length() > 0.1 else forward()
	face_direction(_dodge_dir, 1.0, 100.0)
	_state = "dodge"
	_state_time = 0.0
	_dodge_ready_at = _time + DODGE_COOLDOWN
	collision_mask = GameData.PHYS_WORLD
	play(_anim("dodge"), 0.05, 1.8, true)


func _update_dodge() -> void:
	var v := _dodge_dir * (DODGE_DISTANCE / DODGE_TIME)
	velocity.x = v.x
	velocity.z = v.z
	if _state_time >= DODGE_TIME:
		_state = "idle"
		collision_mask = GameData.PHYS_WORLD | GameData.PHYS_MONSTER


func is_invulnerable() -> bool:
	return _state == "dodge"


func take_damage(amount: float, source: Combatant = null, is_crit := false, dot := false) -> void:
	if is_invulnerable():
		return
	_last_combat = _time
	super.take_damage(amount, source, is_crit, dot)


func _on_death(_killer: Combatant) -> void:
	_state = "dead"
	_target = null
	_trail_on = false
	play(_anim("death"), 0.1)


func respawn(at: Vector3) -> void:
	is_dead = false
	_state = "idle"
	statuses.clear()
	global_position = at
	velocity = Vector3.ZERO
	hp = max_hp
	health_changed.emit(hp, max_hp)
	play(_anim("idle"), 0.2)


## Lumière qui suit le héros dans les grottes.
func set_torch(on: bool) -> void:
	if on and _torch == null:
		_torch = OmniLight3D.new()
		_torch.light_color = Color(1.0, 0.85, 0.65)
		_torch.light_energy = 2.2
		_torch.omni_range = 16.0
		_torch.position = Vector3(0, 3.0, 0)
		add_child(_torch)
	if _torch:
		_torch.visible = on


# --- collisions et blocages ---------------------------------------------------------
## Capsule plus fine que la silhouette : on se faufile entre les obstacles.
func _slim_collision() -> void:
	for c in get_children():
		if c is CollisionShape3D and c.shape is CapsuleShape3D:
			var cap := c.shape as CapsuleShape3D
			cap.radius = HERO_RADIUS
			cap.height = 1.6
			c.position.y = 0.8
	radius = HERO_RADIUS


## Marches, bords et coincements : ce qui rend un hack and slash frustrant.
func _handle_obstacles(input_dir: Vector3, before: Vector3, delta: float) -> void:
	if is_on_floor():
		_safe_timer -= delta
		if _safe_timer <= 0.0:
			_safe_timer = 0.5
			_safe_positions.append(global_position)
			if _safe_positions.size() > 12:
				_safe_positions.pop_front()
	var wants_move := input_dir.length() > 0.1 and _state in ["idle", "jump"]
	if not wants_move:
		_stuck_time = 0.0
		return
	var motion := Vector3(input_dir.x, 0, input_dir.z) * _speed() * delta
	if is_on_wall() and is_on_floor():
		var up := global_transform.translated(Vector3.UP * STEP_HEIGHT)
		if not test_move(global_transform, Vector3.UP * STEP_HEIGHT) and not test_move(up, motion * 2.0):
			global_position += Vector3.UP * STEP_HEIGHT + motion
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if moved < motion.length() * 0.15:
		_stuck_time += delta
	else:
		_stuck_time = maxf(0.0, _stuck_time - delta * 2.0)
	if _stuck_time > 0.8 and is_on_floor() and _state == "idle":
		_start_jump()
	if _stuck_time > 2.0:
		unstuck()


## Ramène le héros à une position libre récente (touche F4 ou automatique).
func unstuck() -> void:
	_stuck_time = 0.0
	var target := global_position + Vector3.UP * 1.5
	for i in range(_safe_positions.size() - 1, -1, -1):
		if _safe_positions[i].distance_to(global_position) > 1.5:
			target = _safe_positions[i] + Vector3.UP * 0.3
			break
	global_position = target
	velocity = Vector3.ZERO


# --- visée ---------------------------------------------------------------------------
func mouse_ground_point() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector3.INF
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t := (global_position.y - from.y) / dir.y
	return from + dir * t if t > 0.0 else Vector3.INF


func nearest_monster(max_dist: float) -> Combatant:
	var best: Combatant = null
	var best_d := max_dist
	for node in get_tree().get_nodes_in_group("monsters"):
		var m := node as Combatant
		if m and not m.is_dead:
			var d := global_position.distance_to(m.global_position)
			if d < best_d:
				best_d = d
				best = m
	return best


func current_target() -> Combatant:
	return _target if _target and is_instance_valid(_target) and not _target.is_dead else null


# --- bot de test (captures d'écran automatiques) ------------------------------------
func _autoplay_input() -> Vector2:
	var m := nearest_monster(40.0)
	var to := Vector3.ZERO
	if autoplay_target != Vector3.INF and (m == null or global_position.distance_to(m.global_position) > 4.0):
		to = autoplay_target - global_position
		if _time > _bot_check_at:
			if global_position.distance_to(_bot_last_pos) < 1.0:
				_bot_detour = to.normalized().rotated(Vector3.UP, PI / 2 * (1 if randf() < 0.5 else -1))
				_bot_detour_until = _time + 1.5
			_bot_last_pos = global_position
			_bot_check_at = _time + 1.0
		if _time < _bot_detour_until:
			to = _bot_detour
	elif m == null:
		return Vector2.ZERO
	else:
		to = m.global_position - global_position
		if to.length() < 2.2 + m.radius:
			return Vector2.ZERO
		var map := get_tree().get_first_node_in_group("map") as Node3D
		if map and to.length() > 5.0:
			for pt: Vector3 in map.call("path_between", global_position, m.global_position):
				var d := pt - global_position
				d.y = 0.0
				if d.length() > 1.2:
					to = d
					break
	to.y = 0.0
	var cam := get_viewport().get_camera_3d()
	var local := to.rotated(Vector3.UP, -cam.global_rotation.y) if cam else to
	return Vector2(local.x, local.z).normalized()


func _autoplay_wants(action: String) -> bool:
	var m := nearest_monster(40.0)
	if m == null:
		return false
	var close := global_position.distance_to(m.global_position) < 2.6 + m.radius
	if action == "attack":
		return close
	if action.begins_with("skill_"):
		var slot := int(action.trim_prefix("skill_")) - 1
		return close and cooldown_left(slot) <= 0.0 and randf() < 0.1
	return false
