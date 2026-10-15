class_name Monster
extends Combatant
## Monstre d'Eden Eternal piloté par une petite machine à états :
## errance -> poursuite -> attaque, avec recul et mort animée.

const ATTACK_COOLDOWN := 1.8
const HIT_FRACTION := 0.45

var data: Dictionary
var is_boss := false
var is_elite := false
var enraged := false
var carries_seal := false  # gardien d'élite : lâche un sceau du donjon
var passive := false  # n'attaque pas et ne bouge pas (mannequin d'entraînement)
var cc_immune := false  # insensible aux contrôles (arène ML : on ne peut pas l'empêcher d'attaquer)
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
var _player: Combatant  # cible : le héros hostile le plus proche (le joueur ou un allié IA)
var _retarget_t := 0.0
var _base_scale := Vector3.ONE
var _hit_time := 0.45
var _map: Node3D  # ProcMap ou MapLoader (path_between)
var _path := PackedVector3Array()
var _path_i := 0  # point de passage visé dans _path
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
	if at_level > 0 and at_level != level:
		# niveau effectif de la run (les monstres des zones avancées sont ramenés au niveau voulu)
		k = pow(1.1, at_level - level)
		level = at_level
	# l'auto-attaque seule ne doit pas suffire : il faut kiter et placer ses compétences
	max_hp = float(data.hp) * k * (14.0 if boss else (1.6 if is_elite else 2.4))
	hp = max_hp
	atk = float(data.atk) * k * GameData.MONSTER_DAMAGE_FACTOR * (1.5 if boss else (1.25 if is_elite else 1.0))
	defense = float(data.get("def", 0)) * k
	xp_reward = int(float(data.xp) * k * (8.0 if boss else (4.0 if is_elite else 1.0)))
	move_speed = randf_range(3.4, 4.6) * (0.85 if boss else 1.0)


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
	_player = get_tree().get_first_node_in_group("player") as Combatant
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
var _flash_mat: StandardMaterial3D


## Éclair blanc sur tout le modèle à l'impact.
func _flash() -> void:
	if model == null:
		return
	_ensure_flash_mat()
	_flash_mat.albedo_color = Color(1, 0.95, 0.85, 0.4)
	create_tween().tween_property(_flash_mat, "albedo_color", _overlay_rest(), 0.1)


func _ensure_flash_mat() -> void:
	if _flash_mat != null:
		return
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.albedo_color = Color(1, 0.95, 0.85, 0.0)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_overlay = _flash_mat


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
	var aura := OmniLight3D.new()
	aura.light_color = Color(1.0, 0.15, 0.1)
	aura.light_energy = 0.7
	aura.omni_range = radius * 2.0 + 1.0
	aura.shadow_enabled = false
	aura.position.y = 1.0
	add_child(aura)


## Gel et renversement interrompent l'attaque annoncée (la zone rouge disparaît), sauf si
## le monstre y est insensible (même contrôle reçu il y a peu, voir Combatant.CC_TYPES).
func add_status(status: String, duration: float, source: Combatant = null) -> void:
	if cc_immune and status in ["stun", "freeze", "sleep", "fear", "root", "chill", "disarm"]:
		return
	if is_boss and status in ["freeze", "sleep", "fear", "root"]:
		duration *= 0.35  # le boss résiste au gel, au sommeil, à la terreur et à l'immobilisation
	var refused := cc_refused(status)
	super.add_status(status, duration, source)
	if not refused and status in ["freeze", "stun", "sleep", "fear"] and _state == "attack" and not is_boss:
		if is_instance_valid(_telegraph):
			_telegraph.queue_free()
		_pending_shot = {}
		_pending_dash = Vector3.ZERO
		_attack_ready_at = _time + 0.6
		_set_state("chase")
	_update_tint()


## Couleur de fond du calque d'impact : bleu sous le gel, transparent sinon.
func _overlay_rest() -> Color:
	return Color(0.35, 0.7, 1.0, 0.5) if has_status("freeze") else Color(1, 0.95, 0.85, 0.0)


## Teinte bleue sous le gel (même calque que l'éclair d'impact).
func _update_tint() -> void:
	if model == null or (_flash_mat == null and not has_status("freeze")):
		return
	_ensure_flash_mat()
	_flash_mat.albedo_color = _overlay_rest()


func _refresh_status_label() -> void:
	_update_tint()
	# états actifs seulement, sans les insensibilités (mécanique invisible), 2 au plus
	var shown: Array = []
	for st in statuses:
		if STATUS_INFO.has(st) and not String(st).begins_with("imm_") and has_status(st):
			shown.append(st)
	# monstres ordinaires : la teinte suffit (en horde, un nom au-dessus de chacun noie l'écran)
	if not (is_elite or is_boss):
		shown = []
	var parts: PackedStringArray = []
	for st in shown.slice(0, 2):
		parts.append(STATUS_INFO[st].name)
	_status_label.text = " · ".join(parts) + (" +%d" % (shown.size() - 2) if shown.size() > 2 else "")
	_status_label.modulate = STATUS_INFO[shown[0]].color if not shown.is_empty() else Color.WHITE


func _physics_process(delta: float) -> void:
	_time += delta
	_state_time += delta
	tick_statuses(delta)
	apply_gravity(delta)
	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget_t = 0.5
		var pool := _hostile_pool()
		if pool.size() > 1 or team == Team.PLAYER or ffa_id >= 0:  # un seul héros : la cible ne change pas
			var t := pick_target(pool, _player)
			if t != null:
				_player = t
	if is_disabled() and not is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		if has_status("freeze"):
			if anim:
				anim.speed_scale = 0.0  # figé dans la glace
		else:
			play("hurt01" if has_anim("hurt01") else "stand01", 0.1)
		move_and_slide()
		return
	if anim and anim.speed_scale == 0.0:
		anim.speed_scale = 1.0
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

	if _time < _dash_until:
		desired = _dash_vel
	desired += _separation() * 1.8
	if has_status("chill"):
		desired *= 0.55
	if has_status("root"):
		desired = Vector3.ZERO
	elif has_status("fear") and _player_alive():
		# terreur : fuit le héros sans attaquer
		var away := global_position - _player.global_position
		away.y = 0.0
		desired = away.normalized() * move_speed * 0.9
		face_direction(away, delta, 8.0)
	_knock = _knock.move_toward(Vector3.ZERO, 14.0 * delta)
	velocity.x = desired.x + _knock.x
	velocity.z = desired.z + _knock.z
	move_and_slide()


func _set_state(s: String) -> void:
	_state = s
	_state_time = 0.0


## Cibles possibles : les héros (le joueur et ses alliés) ; un allié du joueur vise les monstres.
func _hostile_pool() -> Array:
	if ffa_id >= 0:
		var foes := Combatant.ffa_foes(get_tree(), self)
		# Le Siège : celui qui emporte le cœur est la cible de tous
		if Siege.carrier != null and is_instance_valid(Siege.carrier) and Siege.carrier in foes:
			return [Siege.carrier]
		return foes
	if team == Team.PLAYER:
		return get_tree().get_nodes_in_group("monsters") + get_tree().get_nodes_in_group("foe_heroes")  # (passe M7 : héros ennemi d'un cerveau)
	return get_tree().get_nodes_in_group("heroes")


func _player_alive() -> bool:
	return is_instance_valid(_player) and not _player.is_dead


## Le héros peut être pris pour cible (vivant et pas invisible).
func _can_target() -> bool:
	return _player_alive() and not _player.has_status("invisible")


## Entraînement : mannequin, ou ennemis réglés sur passifs.
func is_passive() -> bool:
	return passive or (Training.active and Training.enemies_passive)


func _update_idle(_delta: float) -> Vector3:
	# tous les monstres de la run traquent le héros : pression constante
	if is_passive():
		play("stand01" if has_anim("stand01") else "battle01", 0.3)
		return Vector3.ZERO
	if _can_target():
		_set_state("chase")
	else:
		play("stand01" if has_anim("stand01") else "battle01", 0.3)
	return Vector3.ZERO


## Type d'attaque selon le modèle d'Eden.
const ATTACK_KINDS := {"m018": "charge", "m075": "charge", "m020": "slam", "m024": "ranged", "m029": "ranged"}


func attack_kind() -> String:
	if is_boss:
		return "melee"
	return ATTACK_KINDS.get(String(data.get("model", "")), "melee")


func _attack_range() -> float:
	match attack_kind():
		"ranged":
			return 12.0
		"charge":
			return 8.5
		"slam":
			return radius + 2.4
	return radius + _player.radius + 1.0


func _update_chase(delta: float) -> Vector3:
	if is_passive():
		_set_state("idle")
		return Vector3.ZERO
	if not _can_target():
		_set_state("idle")
		return Vector3.ZERO
	var to := _player.global_position - global_position
	to.y = 0.0
	face_direction(to, delta, 10.0)
	if to.length() <= _attack_range():
		if _time >= _attack_ready_at and not _attacks.is_empty() and not has_status("disarm") and not has_status("fear"):
			_start_attack()
			return Vector3.ZERO
		# les tireurs gardent leurs distances, les autres collent le héros
		if attack_kind() == "ranged" or to.length() <= radius + _player.radius + 0.8:
			play("battle01" if has_anim("battle01") else "stand01", 0.2)
			return Vector3.ZERO
	play("move02" if has_anim("move02") else "move01", 0.2)
	var step := _path_step(_player.global_position)
	step = _unstick(step)
	face_direction(step, delta, 10.0)
	return step * move_speed * catch_up(to.length())


## Rattrapage en run : un monstre distancé accélère (jusqu'à CATCH_UP × sa vitesse à 30 m
## et plus), sinon le héros (6,5 m/s) sème toute la horde en courant ; de près, vitesse
## normale (on peut toujours esquiver et se replacer).
const CATCH_UP := 1.7


func catch_up(dist: float) -> float:
	if not Run.active or is_boss:
		return 1.0
	return lerpf(1.0, CATCH_UP, clampf((dist - 8.0) / 22.0, 0.0, 1.0))


## Décoincement : un monstre qui n'avance presque plus (arbre, rocher, bord de falaise)
## contourne par le côté pendant un moment.
var _stuck_check := 0.0
var _stuck_from := Vector3.ZERO
var _detour_until := 0.0
var _detour := Vector3.ZERO
var _unstick_at := -1.0  # dernier appel : une pause (coup, recul) remet la mesure à zéro


func _unstick(step: Vector3) -> Vector3:
	if _time - _unstick_at > 0.2:
		_stuck_check = _time + 0.5
		_stuck_from = global_position
	_unstick_at = _time
	if _time < _detour_until:
		return (_detour + step * 0.35).normalized()
	if _time >= _stuck_check:
		var moved := Vector2(global_position.x - _stuck_from.x, global_position.z - _stuck_from.z).length()
		if moved < move_speed * 0.5 * 0.25 and _knock.length() < 0.5 and not has_status("chill"):
			var side := step.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
			_detour = side
			_detour_until = _time + randf_range(0.6, 1.0)
			_path_timer = 0.0  # nouveau chemin après le détour
		_stuck_check = _time + 0.5
		_stuck_from = global_position
	return step


## Direction de marche vers [param goal] en suivant le maillage de navigation
## (contourne rochers et piliers) ; ligne droite à courte distance.
func _path_step(goal: Vector3) -> Vector3:
	var to := goal - global_position
	to.y = 0.0
	if to.length() < 3.0 or _map == null:
		return to.normalized()
	_path_timer -= get_physics_process_delta_time()
	if _path_timer <= 0.0:
		_path_timer = randf_range(0.4, 0.7)
		_path = _map.path_between(global_position, goal)
		_path_i = 1  # le 1er point est la position du monstre au calcul
	# Point de passage suivant : on avance dans le chemin et on ne revient jamais en arrière (avant la passe P9,
	# le premier point à plus de 1,2 m était souvent le départ du chemin, resté derrière : le monstre
	# faisait demi-tour à chaque instant et n'avançait qu'à un tiers de sa vitesse).
	while _path_i < _path.size():
		var d := _path[_path_i] - global_position
		d.y = 0.0
		if d.length() > 1.2:
			return d.normalized()
		_path_i += 1
	return to.normalized()


## Attaque annoncée : la zone rouge apparaît, se remplit, puis frappe.
## Le héros qui sort de la zone ou esquive à temps ne prend rien.
func _start_attack() -> void:
	var kind := attack_kind()
	var a: String = _attacks.pick_random()
	if kind == "ranged" and has_anim("shoot01"):
		a = "shoot01"
	elif kind == "slam" and has_anim("magic01"):
		a = "magic01"
	_set_state("attack")
	var keys := keys_of(a)
	var hits: Array = keys.get("hit", [])
	var length := anim_length(a)
	var hit_t := float(hits[0]) if not hits.is_empty() else length * HIT_FRACTION
	# temps de réaction minimal : l'animation est ralentie pour coller à l'annonce
	var delay := maxf(hit_t, 0.55 if not is_elite else 0.7)
	var speed := hit_t / delay
	_state_len = length / speed
	_hit_time = delay
	_hit_done = false
	for snd in keys.get("sounds", []):
		get_tree().create_timer(float(snd[0]) / speed, false).timeout.connect(
			func(): Sfx.play_at(self, global_position, String(snd[1]), -8.0))
	play(a, 0.1, speed, true)
	var to := _player.global_position - global_position
	to.y = 0.0
	var yaw := atan2(to.x, to.z)
	face_direction(to, 1.0, 100.0)
	var dmg := atk * damage_dealt_mult() * randf_range(0.9, 1.1)
	var props := {"delay": delay, "damage": dmg, "source": self, "small": not is_elite}
	match kind:
		"ranged":
			props.merge({"shape": "line", "length": 13.0, "width": 0.8, "damage": 0.0})
			_pending_shot = {"yaw": yaw, "damage": dmg}
		"charge":
			props.merge({"shape": "line", "length": 9.0, "width": radius * 2.0 + 0.6, "damage": dmg * 1.3})
			_pending_dash = to.normalized() * 8.0
		"slam":
			props.merge({"shape": "circle", "radius": radius + 2.6, "damage": dmg * 1.25})
			yaw = 0.0
		_:
			props.merge({"shape": "cone", "radius": radius + 2.0 + (0.8 if is_elite else 0.0), "angle": 100.0})
	_telegraph = Telegraph.spawn(self, global_position, yaw, props)


var _telegraph: Telegraph
var _dash_vel := Vector3.ZERO
var _dash_until := 0.0
var _pending_shot := {}
var _pending_dash := Vector3.ZERO


func _update_attack(_delta: float) -> void:
	if not _hit_done and _state_time >= _hit_time:
		_hit_done = true
		if not _pending_shot.is_empty():
			var y: float = _pending_shot.yaw
			Projectile.fire(self, global_position + Vector3.UP * 1.0, Vector3(sin(y), 0, cos(y)), float(_pending_shot.damage))
			_pending_shot = {}
		if _pending_dash != Vector3.ZERO:
			# charge physique (respecte les collisions)
			_dash_vel = _pending_dash / 0.22
			_dash_until = _time + 0.22
			_pending_dash = Vector3.ZERO
	if _state_time >= _state_len:
		_attack_ready_at = _time + ATTACK_COOLDOWN * randf_range(0.8, 1.3)
		_set_state("chase")


## Évite que les monstres s'empilent les uns sur les autres.
## Écartement entre monstres : grille de cases construite une fois par image physique
## (chaque monstre ne regarde que ses voisins, au lieu de toute la foule).
const SEP_CELL := 3.0
static var _sep_grid := {}
static var _sep_frame := -1


func _separation() -> Vector3:
	var f := Engine.get_physics_frames()
	if f != _sep_frame:
		_sep_frame = f
		_sep_grid.clear()
		for node in get_tree().get_nodes_in_group("monsters"):
			var p: Vector3 = (node as Node3D).global_position
			var k := Vector2i(floori(p.x / SEP_CELL), floori(p.z / SEP_CELL))
			if not _sep_grid.has(k):
				_sep_grid[k] = []
			_sep_grid[k].append(node)
	var push := Vector3.ZERO
	var c := Vector2i(floori(global_position.x / SEP_CELL), floori(global_position.z / SEP_CELL))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for node in _sep_grid.get(c + Vector2i(dx, dz), []):
				if node == self or not is_instance_valid(node):
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


signal reflect_started


func message_reflect() -> void:
	reflect_started.emit()
	DamageNumber.spawn_text(self, "MIROIR !", Color(1.0, 0.85, 0.3))


## Bouclier du boss (totems à détruire) : insensible aux dégâts.
var shielded := false


func take_damage(amount: float, source: Combatant = null, crit := false, dot := false) -> void:
	if shielded:
		if not dot and randf() < 0.3:
			DamageNumber.spawn_text(self, "BOUCLIER", Color(0.6, 0.85, 1.0))
		return
	# miroir du boss : renvoie 60 % des dégâts au héros
	if brain and brain.reflecting and source is Player and not dot:
		source.take_damage(amount * 0.6, self, false, true)
		DamageNumber.spawn_text(source, "RENVOI", Color(1.0, 0.75, 0.3))
		amount *= 0.2
	super.take_damage(amount, source, crit, dot)


func _on_damaged(_amount: float, _source: Combatant) -> void:
	if randf() < 0.5:
		for snd in keys_of("hurt01").get("sounds", []):
			Sfx.play_at(self, global_position, String(snd[1]), -10.0)
	_flash()
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
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()  # un monstre mort ne frappe plus
	_set_state("dead")
	remove_from_group("monsters")
	collision_layer = 0
	collision_mask = GameData.PHYS_WORLD
	play("death01", 0.05, 1.0, true)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(model, "position:y", -1.5, 0.8)
	tw.tween_callback(queue_free)
