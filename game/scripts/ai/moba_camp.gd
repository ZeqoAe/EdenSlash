class_name MobaCamp
extends Monster
## Monstre neutre des Deux Voies (lot MB-F, MOBA.md § 7.5, rapport conception/benchmark/R_MB_F.md) : monstre d'un camp de
## la jungle (Source, Braise, petits camps) ou objectif de la rivière (Gardien, Colosse : boss de la bibliothèque créé par
## BossLibrary.spawn, avec ses briques). Tenu par MobaJungle (entry = son camp ou son objectif).
##
## Neutre (R_MODE0, piège 8) : son propre chacun-pour-soi (MobaData.NEUTRAL_FFA) : les héros des deux équipes le frappent,
## il ne choisit sa cible que parmi les agresseurs de son camp (MobaJungle.camp_target : le plus proche) ; ses zones touchent
## ce qui s'y trouve. Laisse (MobaData.CAMP_LEASH, OBJ_LEASH autour du point du camp) : un agresseur qui s'éloigne au-delà est
## oublié ; plus aucun agresseur (ou le monstre entraîné trop loin) : remise à zéro (retour au point du camp sans prendre de
## coups, PV pleins ; boss : cerveau remis à zéro, rage et fureur retirées).
## Créé au chargement et recyclé (mort : caché jusqu'à sa réapparition ; aucune création de modèle pendant la partie, R_MB0
## § 6) ; mode horde (Monster.lite) ; endormi par MobaJungle sans héros à MobaData.CAMP_WAKE m (ni physique ni animation).

var jungle: Node  # MobaJungle
var entry: Dictionary = {}  # son camp (MobaJungle.camps) ou son objectif (MobaJungle.objectives)
var home := Vector3.ZERO
var leash := MobaData.CAMP_LEASH
var resetting := false
var asleep := false
var parked := true
var scale_k := 1.0
## Valeurs de l'apparition (rage, fureur et barrière retirées à la remise à zéro).
var base_atk := 0.0
var base_speed := 0.0
var base_pace := 1.0
var _dead_t := -1.0
var _rt := 0.0
var _msg_t := -10.0


## Avant add_child : monstre [param monster_id] du camp [param e] de [param j], posé en [param at_home].
func setup_camp(j: Node, e: Dictionary, monster_id: int, at_home: Vector3, boss: bool, lv: int, k := 1.0) -> void:
	jungle = j
	entry = e
	home = at_home
	scale_k = k
	configure(GameData.monster(monster_id), boss, lv)
	lite = true
	is_elite = false
	leash = MobaData.OBJ_LEASH if boss else MobaData.CAMP_LEASH


func _ready() -> void:
	super._ready()
	_retarget_t = 1.0e9  # (cible choisie parmi les agresseurs du camp : MobaJungle.camp_target)
	_player = null  # (Monster._ready vise le héros du joueur)
	if scale_k != 1.0 and model:
		model.scale *= scale_k
		_base_scale = model.scale
		radius = clampf(radius * scale_k, 0.35, 2.4)
	collision_layer = GameData.PHYS_MONSTER
	collision_mask = 0  # (horde : aucun move_and_slide)
	_rt = randf() * 0.25


## Pas de rattrapage de la Survie : un monstre de camp garde son pas.
func catch_up(_dist: float) -> float:
	return 1.0


## Cibles possibles : les agresseurs de son camp seulement (neutre).
func _hostile_pool() -> Array:
	return (entry.get("aggro", {}) as Dictionary).keys().filter(func(a): return is_instance_valid(a) and not a.is_dead)


func _physics_process(delta: float) -> void:
	if parked:
		return
	var t0 := Time.get_ticks_usec()
	_tick(delta)
	var us := float(Time.get_ticks_usec() - t0)  # (mesures : MobaJungle.cost)
	jungle.stats.camp_us = float(jungle.stats.camp_us) + us
	if us > 1000.0:
		jungle.stats.camp_over_1ms = int(jungle.stats.camp_over_1ms) + 1
	if us > float(jungle.stats.camp_max):
		jungle.stats.camp_max = us


func _tick(delta: float) -> void:
	if is_dead:
		if _dead_t >= 0.0:
			_dead_t -= delta
			if _dead_t < 0.0:
				park()
		return
	_rt -= delta
	if _rt <= 0.0 and not resetting:
		_rt = 0.25
		_player = jungle.camp_target(self)
		if _player == null and (hp < max_hp - 0.5 or _away() > 1.5):
			jungle.reset_entry(entry)
		elif _away() > leash + 6.0:
			jungle.reset_entry(entry)  # entraîné trop loin : la laisse casse
	if resetting:
		_reset_step(delta)
		return
	super._physics_process(delta)


func _away() -> float:
	return Vector2(global_position.x - home.x, global_position.z - home.z).length()


# --- remise à zéro ---------------------------------------------------------------------------------

## Retour au point du camp : sans cible, sans prendre de coups ; PV pleins à l'arrivée.
func begin_reset() -> void:
	if is_dead or parked:
		return
	resetting = true
	_player = null
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_set_state("idle")
	if brain:
		brain.end_barrier()
		brain.reflecting = false


func _reset_step(delta: float) -> void:
	if anim:
		anim.advance(delta)  # (horde : l'animation est avancée à la main)
	var to := home - global_position
	to.y = 0.0
	hp = minf(max_hp, hp + max_hp * 0.25 * delta)
	if to.length() < 1.0:
		_end_reset()
		return
	play("move02" if has_anim("move02") else "move01", 0.2)
	face_direction(to, delta, 10.0)
	velocity = to.normalized() * maxf(move_speed, 3.0) * MobaData.RESET_SPEED
	_lite_move(delta)


func _end_reset() -> void:
	resetting = false
	hp = max_hp
	statuses.clear()
	_dots.clear()
	statuses_changed.emit()
	_burst.clear()
	atk = base_atk
	move_speed = base_speed
	shielded = false
	if brain:
		_reset_brain()
	velocity = Vector3.ZERO
	_set_state("idle")
	play("stand01" if has_anim("stand01") else "battle01", 0.2)
	health_changed.emit(hp, max_hp)


## Cerveau du boss comme à l'apparition : seuils, 2e phase, minuteurs des briques, rythme, rage (lumière comprise).
func _reset_brain() -> void:
	var b: BossBrain = brain
	b._phase2 = false
	b._thresholds_done.clear()
	b._stagger = 0.0
	b._cooldown = 2.5
	b._nova_timer = 0.0
	b.age = 0.0
	b.pace = base_pace
	b.end_barrier()
	b.reflecting = false
	b._brick_t = []
	for br in b.bricks:
		b._brick_t.append(float(br.first))
	for c in get_children():
		if c is OmniLight3D:
			c.queue_free()  # (aura de la rage)


# --- coups et mort ---------------------------------------------------------------------------------

func take_damage(amount: float, source: Combatant = null, crit := false, dot := false) -> void:
	if is_dead or parked:
		return
	if resetting:
		if not dot and source is Player and Moba.t - _msg_t > 1.5:
			_msg_t = Moba.t
			DamageNumber.spawn_text(self, "RETOUR", Color(0.8, 0.85, 1.0))
		return
	if source != null and is_instance_valid(source) and source != self and source.ffa_id != MobaData.NEUTRAL_FFA:
		jungle.note_aggro(self, source)
	super.take_damage(amount, source, crit, dot)


func _on_death(killer: Combatant) -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_set_state("dead")
	lod = 0
	if anim:
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE  # (l'animation de mort à pleine cadence)
	remove_from_group("monsters")
	clear_ffa()
	collision_layer = 0
	play("death01", 0.05, 1.0, true)
	_dead_t = 1.8
	if brain:
		brain.end_barrier()
		brain.reflecting = false
	jungle.on_unit_down(self, killer)


## Mis en réserve : caché, hors de toute cible, sans physique (jusqu'à sa réapparition).
func park() -> void:
	parked = true
	is_dead = true  # (le cerveau du boss et les briques en attente s'arrêtent : BossBricks._alive)
	resetting = false
	asleep = false
	remove_from_group("monsters")
	clear_ffa()
	collision_layer = 0
	visible = false
	set_physics_process(false)
	_player = null
	statuses.clear()
	_dots.clear()
	global_position = Vector3(home.x, -60.0, home.z)


## Remis en jeu à son point, avec la force [param st] du moment ({hp, atk}).
func revive(st: Dictionary) -> void:
	parked = false
	is_dead = false
	resetting = false
	asleep = false
	max_hp = float(st.hp)
	hp = max_hp
	atk = float(st.atk)
	defense = 0.0
	base_atk = atk
	if base_speed <= 0.0:
		base_speed = move_speed
	move_speed = base_speed
	shielded = false
	statuses.clear()
	_dots.clear()
	_burst.clear()
	_state = "spawn"
	_state_time = 0.0
	_attack_ready_at = _time + 1.0
	_player = null
	_pending_shot = {}
	_pending_dash = Vector3.ZERO
	_hit_done = true
	_knock = Vector3.ZERO
	_dash_until = 0.0
	_dead_t = -1.0
	lod = 0
	if not is_in_group("monsters"):
		add_to_group("monsters")
	set_ffa(MobaData.NEUTRAL_FFA)
	collision_layer = GameData.PHYS_MONSTER
	visible = true
	set_physics_process(true)
	global_position = home + Vector3.UP * 0.2
	rotation.y = randf() * TAU
	if model:
		model.scale = _base_scale
		model.position.y = -2.0
		create_tween().tween_property(model, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if anim:
		anim.speed_scale = 1.0
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if brain:
		_reset_brain()
	play("battle01" if has_anim("battle01") else "stand01", 0.0, 1.0, true)
	health_changed.emit(hp, max_hp)


## Endormi (aucun héros proche) : ni physique ni animation ; réveillé par MobaJungle ou par un coup.
func set_asleep(v: bool) -> void:
	if parked or is_dead or asleep == v:
		return
	asleep = v
	set_physics_process(not v)
