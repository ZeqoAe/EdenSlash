class_name MobaMinion
extends Monster
## Sbire des Deux Voies (lot MB-C, MOBA.md § 7.5, rapport R_MB_C.md ; budgets R_MB0 § 6) : mêlée, tireur, bélier ou géant
## d'un camp, qui suit la courbe de sa voie (MobaMap.lane_wp) vers le Cœur adverse. Mode « horde » du Survivant
## (Monster.lite : sans move_and_slide, animation à demi-cadence, écartement borné ; niveau de détail posé par le directeur
## selon la distance à la caméra), recyclé à sa mort (jamais libéré : aucune création de modèle pendant la partie), cible
## choisie par le directeur (MobaDirector.minion_target, revue toutes les 0,5 s décalées : héros ennemi qui frappe un héros
## allié, sinon sbire, structure, héros). Coup sans zone rouge (lisibilité, MOBA.md P1-20) ; le tireur lance un trait
## recyclé. Force relative au héros attendu à son apparition (MobaData.minion_stats) ; entre sbires, dégâts sans chiffres.

var director: Node  # MobaDirector
var side := 0
var lane := 0
var kind := "melee"
var ranged := false
var wp_i := 1
var lat := 0.0  # décalage latéral dans la voie (m)
var vs_minion := 0.0
var struct_units := 1.0
var reach := 1.6
var aggro := 9.0
var spawned_at := 0.0
## Dernier à l'avoir frappé (prime du dernier coup, lot MB-D).
var last_hitter: Combatant
var _rt := 0.0
var _dead_t := -1.0
var _disc: MeshInstance3D

static var _disc_mesh: Array = [null, null]
static var _disc_mat: Array = [null, null]


## Avant add_child : genre [param k] du camp [param s] sur la voie [param l].
func setup_unit(dir: Node, s: int, l: int, k: String) -> void:
	director = dir
	side = s
	lane = l
	kind = k
	ranged = k == "ranged"
	var m: Dictionary = MobaData.MINIONS[k]
	configure(GameData.monster(int(m.ids[s])), false, 0)
	lite = true
	is_elite = false
	kind_override = "ranged" if ranged else "melee"
	reach = float(m.reach)
	aggro = float(m.aggro)


## Force du moment (MobaData.minion_stats) et vitesse.
func apply_stats(st: Dictionary) -> void:
	max_hp = float(st.hp)
	hp = max_hp
	atk = float(st.atk)
	defense = 0.0
	vs_minion = float(st.vs_minion)
	struct_units = float(st.struct)
	var j := Moba.tune("jitter", MobaData.JITTER)
	move_speed = float(MobaData.MINIONS[kind].speed) * randf_range(1.0 - 0.03 * j, 1.0 + 0.03 * j)
	xp_reward = 0


func _ready() -> void:
	super._ready()
	_retarget_t = 1.0e9  # (cible choisie par le directeur)
	_player = null  # (Monster._ready vise le héros du joueur : jamais ici)
	display_name = String(MobaData.MINIONS[kind].name)
	if kind == "giant":
		model.scale *= 1.35
		_base_scale = model.scale
	_disc = MeshInstance3D.new()
	_disc.mesh = _team_disc_mesh(side)
	_disc.material_override = _team_disc_mat(side)
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_disc.position.y = 0.06
	_disc.scale = Vector3.ONE * clampf(radius / 0.5, 0.8, 2.6)
	add_child(_disc)
	_set_side()
	lat = randf_range(-3.0, 3.0) * minf(Moba.tune("jitter", MobaData.JITTER), 1.0)
	_rt = randf() * MobaData.MINION_RETARGET


## Motif de l'équipe sous le sbire (rond Azur, carré Braise), maillage et matière partagés par camp.
static func _team_disc_mesh(s: int) -> Mesh:
	if _disc_mesh[s] == null:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.55
		cm.bottom_radius = 0.55
		cm.height = 0.02
		cm.radial_segments = 16 if s == 0 else 4
		_disc_mesh[s] = cm
	return _disc_mesh[s]


static func _team_disc_mat(s: int) -> Material:
	if _disc_mat[s] == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(TeamMatch.color(s), 0.85)
		_disc_mat[s] = m
	return _disc_mat[s]


## Camp : ffa_id de l'équipe (ciblage des héros), couche de collision du camp (les alliés du joueur ne le bousculent pas).
func _set_side() -> void:
	team = Team.PLAYER if side == 0 else Team.MONSTER
	collision_layer = GameData.PHYS_PLAYER if side == 0 else GameData.PHYS_MONSTER
	collision_mask = 0  # (horde : aucun move_and_slide)
	set_ffa(TeamMatch.FFA_BASE + side)
	if not is_in_group("monsters"):
		add_to_group("monsters")  # (écartement de la horde)
	if side == 1 and _disc:
		_disc.rotation.y = PI * 0.25


func _physics_process(delta: float) -> void:
	if is_dead:
		if _dead_t >= 0.0:
			_dead_t -= delta
			if _dead_t < 0.0:
				_park()
				director.release_minion(self)
		return
	_rt -= delta
	if _rt <= 0.0:
		_rt = MobaData.MINION_RETARGET
		var t: Combatant = director.minion_target(self, _player)
		if t != _player and _player != null and t == null:
			_rejoin_lane()
		_player = t
	super._physics_process(delta)


func _can_target() -> bool:
	return _player != null and is_instance_valid(_player) and not _player.is_dead and not _player.has_status("invisible")


func _update_idle(delta: float) -> Vector3:
	if _can_target():
		_set_state("chase")
		return Vector3.ZERO
	return _lane_step(delta)


func _update_chase(delta: float) -> Vector3:
	if not _can_target():
		_set_state("idle")
		_rejoin_lane()
		return _lane_step(delta)
	return super._update_chase(delta)


## Pas de rattrapage de la Survie : un sbire garde son pas.
func catch_up(_dist: float) -> float:
	return 1.0


## Portée du coup : la sienne, plus les rayons.
func _attack_range() -> float:
	if _player == null:
		return reach
	return reach + _player.radius + (0.0 if ranged else radius * 0.5)


## Marche sur la voie, vers le Cœur adverse, avec son décalage latéral.
func _lane_step(delta: float) -> Vector3:
	var map: MobaMap = director.map
	var wps: PackedVector3Array = map.lane_wp[lane][side]
	var perp: PackedVector3Array = map.lane_perp[lane][side]
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
	play("move02" if has_anim("move02") else "move01", 0.2)
	face_direction(to, delta, 8.0)
	return to.normalized() * move_speed


## Retour sur la voie après une poursuite : le point de passage devant lui.
func _rejoin_lane() -> void:
	var map: MobaMap = director.map
	var d := map.lane_progress(side, lane, global_position)
	wp_i = mini(map.lane_index(side, lane, d) + 1, (map.lane_wp[lane][side] as PackedVector3Array).size() - 1)


## Poursuite : en ligne droite de près (la voie est dégagée), chemin de navigation de loin.
func _path_step(goal: Vector3) -> Vector3:
	var to := goal - global_position
	to.y = 0.0
	if to.length() < 12.0:
		return to.normalized()
	return super._path_step(goal)


# --- coups -------------------------------------------------------------------------------------------

## Coup sans zone rouge : l'animation, puis le coup (ou le trait du tireur) à l'impact.
func _start_attack() -> void:
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


func _update_attack(_delta: float) -> void:
	if not _hit_done and _state_time >= _hit_time:
		_hit_done = true
		if _can_target():
			if ranged:
				director.fire_bolt(self, _player, hit_amount(_player), global_position + Vector3.UP * 1.0, "minion")
			elif global_position.distance_to(_player.global_position) <= _attack_range() + 0.6:
				deal(_player)
	if _state_time >= _state_len:
		var j := Moba.tune("jitter", MobaData.JITTER)
		_attack_ready_at = _time + ATTACK_COOLDOWN * randf_range(1.0 - 0.2 * j, 1.0 + 0.2 * j)
		_set_state("chase")


## Dégâts d'un coup sur [param target] : héros = attaque (sa défense s'applique), sbire = part d'un mêlée, structure = unités.
func hit_amount(target: Combatant) -> float:
	if target is MobaMinion:
		return vs_minion * director.minion_aura(self)
	if target is MobaStructure:
		return struct_units
	return atk * director.minion_aura(self)


func deal(target: Combatant) -> void:
	if target is MobaStructure:
		(target as MobaStructure).take_units(struct_units, self)
	else:
		target.take_damage(hit_amount(target), self)


## Entre sbires et des structures : PV retirés sans chiffre ni effet (les héros gardent le coup complet du jeu).
func take_damage(amount: float, source: Combatant = null, crit := false, dot := false) -> void:
	if is_dead:
		return
	last_hitter = source
	if source is MobaMinion or source is MobaStructure:
		hp = maxf(0.0, hp - amount)
		health_changed.emit(hp, max_hp)
		damaged.emit(amount, source)
		if hp <= 0.0:
			is_dead = true
			_on_death(source)
			died.emit(self, source)
		return
	super.take_damage(amount, source, crit, dot)


# --- mort et recyclage -------------------------------------------------------------------------------

func _on_death(killer: Combatant) -> void:
	director.on_minion_down(self, killer)
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_set_state("dead")
	lod = 0
	if anim:
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	remove_from_group("monsters")
	clear_ffa()
	collision_layer = 0
	play("death01", 0.05, 1.0, true)
	_dead_t = 1.4


func _park() -> void:
	remove_from_group("monsters")  # (réserve : ni écartement, ni cible)
	clear_ffa()
	visible = false
	set_physics_process(false)
	global_position = Vector3(0, -60, 0)


## Remis en jeu (vague suivante) à [param at], point de passage [param i], avec la force [param st] du moment.
func reuse(at: Vector3, i: int, st: Dictionary) -> void:
	is_dead = false
	apply_stats(st)
	statuses.clear()
	_dots.clear()
	_state = "spawn"
	_state_time = 0.0
	_attack_ready_at = _time + 0.8 + randf_range(-0.4, 0.4) * Moba.tune("jitter", MobaData.JITTER)
	_player = null
	last_hitter = null
	_pending_shot = {}
	_hit_done = true
	_knock = Vector3.ZERO
	_dash_until = 0.0
	_dead_t = -1.0
	wp_i = i
	lat = randf_range(-3.0, 3.0) * minf(Moba.tune("jitter", MobaData.JITTER), 1.0)
	_rt = randf() * MobaData.MINION_RETARGET
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
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	play("battle01" if has_anim("battle01") else "stand01", 0.0, 1.0, true)
