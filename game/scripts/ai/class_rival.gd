class_name ClassRival
extends Monster
## Adversaire de la zone d'entraînement : un héros d'une classe (corps, tenue, arme) qui
## enchaîne le combo de son arme et lance les sorts de la classe. Ses coups sont annoncés au
## sol en rouge (comme les monstres) avec la forme du coup ou du sort (cône, cercle, ligne,
## zone visée) et les effets d'Eden ; il esquive parfois quand on le frappe, garde ses
## distances s'il combat à distance. Difficulté : 0 facile, 1 normal, 2 difficile.

const DODGE_EVERY := 3.5  # secondes au plus entre deux esquives (normal)

var cid := "warrior"
var cls: Dictionary = {}
var wtype: Dictionary = {}
var difficulty := 1
var _combo_i := 0
var _skills: Array = []
var _skill_ready := {}  # id -> temps où le sort est de nouveau prêt
var _dodge_ready := 0.0
var _cur: Dictionary = {}  # coup ou sort en cours : {hit_fx, kind, at, yaw, radius}
var _invuln_until := 0.0


## Classe [param class_id] au niveau [param lvl] (PV et dégâts d'un héros de ce niveau).
func setup(class_id: String, lvl: int, diff := 1) -> void:
	cid = class_id
	cls = GameData.class_data(cid)
	wtype = GameData.weapon_type(String(cls.get("weapon_type", "")))
	difficulty = diff
	level = maxi(1, lvl)
	data = {"name": String(cls.get("name_fr", cid)), "model": "", "rank": 3, "level": level}
	is_elite = true
	display_name = "%s · adversaire" % cls.get("name_fr", cid)
	var base: Dictionary = cls.get("base", {})
	max_hp = GameData.player_max_hp(level) * float(base.get("hp", 1.0)) * (3.0 + 1.5 * diff)
	hp = max_hp
	var magic := String(cls.get("dmg_type", "phys")) in ["mag", "magic"]
	atk = GameData.player_atk(level) * float(base.get("matk" if magic else "atk", 1.0)) * (0.35 + 0.15 * diff)
	defense = 4.0 + level * 2.0
	xp_reward = 0
	move_speed = 4.6
	_skills = (cls.get("skills", []) as Array).filter(func(s): return String(s.kind) != "buff" and String(s.kind) != "heal").slice(0, 4)


func _ready() -> void:
	team = Team.MONSTER
	collision_layer = GameData.PHYS_MONSTER
	collision_mask = GameData.PHYS_WORLD | GameData.PHYS_PLAYER
	add_to_group("monsters")
	floor_max_angle = deg_to_rad(55.0)
	floor_snap_length = 0.7
	kfm = "m"
	setup_model(String(cls.get("body_model", cls.get("model", "res://assets/player/body/body_m.glb"))), "", GameData.HERO_SCALE)
	EdenModel.strip_body(model)
	for p in cls.get("parts", []):
		EdenModel.dress(model, String(p))
	EdenModel.attach_weapon(model, EdenModel.weapon_entry(cls, ""))
	_base_scale = model.scale
	_player = get_tree().get_first_node_in_group("player") as Player
	_map = get_tree().get_first_node_in_group("map") as Node3D
	_status_label = Label3D.new()
	_status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_status_label.no_depth_test = true
	_status_label.fixed_size = true
	_status_label.pixel_size = 0.0009
	_status_label.font_size = 26
	_status_label.outline_size = 8
	_status_label.position = Vector3(0, 2.6, 0)
	add_child(_status_label)
	statuses_changed.connect(_refresh_status_label)
	_attacks = ["combo"]  # non vide : Monster._update_chase déclenche _start_attack
	play(_battle_anim())
	_attack_ready_at = 1.0


func _battle_anim() -> String:
	return String(wtype.get("battle", cls.get("anims", {}).get("battle", "battle01")))


func _anim(key: String, fallback: String) -> String:
	return String(cls.get("anims", {}).get(key, fallback))


## Portée : les classes à distance gardent leurs distances.
func _attack_range() -> float:
	return float(cls.get("attack_range", 0.0)) * 0.9 if cls.has("attack_range") else 3.2


func _update_idle(delta: float) -> Vector3:
	var v := super._update_idle(delta)
	if is_passive() or not _can_target():
		play(_anim("idle", "stand01"), 0.3)
	return v


func _update_chase(delta: float) -> Vector3:
	var v := super._update_chase(delta)
	if _state == "chase":
		play(_anim("run", "move02") if v.length() > 0.1 else _battle_anim(), 0.2)
	return v


func is_invulnerable() -> bool:
	return _time < _invuln_until


func take_damage(amount: float, source: Combatant = null, crit := false, dot := false) -> void:
	if is_invulnerable() and not dot:
		DamageNumber.spawn_text(self, "ESQUIVE", Color(0.7, 1.0, 0.7))
		return
	super.take_damage(amount, source, crit, dot)
	# esquive de temps en temps quand on le frappe (plus souvent en difficile)
	if not is_dead and not dot and not is_passive() and _time >= _dodge_ready and _state != "attack" and randf() < 0.18 + 0.12 * difficulty:
		_dodge(source)


func _dodge(from: Combatant) -> void:
	_dodge_ready = _time + DODGE_EVERY / (0.6 + 0.4 * difficulty)
	var away := global_position - (from.global_position if from else global_position - forward())
	away.y = 0.0
	away = away.normalized().rotated(Vector3.UP, randf_range(-0.9, 0.9))
	_dash_vel = away * 14.0
	_dash_until = _time + 0.25
	_invuln_until = _time + 0.35
	face_direction(away, 1.0, 100.0)
	play(_anim("dodge", "jump02"), 0.05, 1.4, true)
	_attack_ready_at = maxf(_attack_ready_at, _time + 0.4)


## Sort prêt (le premier dans l'ordre de la classe), sinon le coup suivant du combo.
func _start_attack() -> void:
	var to := _player.global_position - global_position
	to.y = 0.0
	var yaw := atan2(to.x, to.z)
	face_direction(to, 1.0, 100.0)
	var sk: Dictionary = {}
	for s in _skills:
		if _time >= float(_skill_ready.get(int(s.id), 1.5 + randf() * 2.0)) and randf() < 0.55 + 0.15 * difficulty:
			sk = s
			break
	var act: Dictionary
	var anim_name: String
	var mult: float
	if not sk.is_empty():
		_skill_ready[int(sk.id)] = _time + float(sk.cooldown) * (1.6 - 0.3 * difficulty)
		act = sk
		anim_name = String(sk.get("anim", "attack01"))
		mult = float(sk.get("mult", 1.5))
		EdenFx.play(self, String(sk.get("fx", {}).get("cast", "")), global_position, yaw, GameData.HERO_SCALE, self)
	else:
		var chain: Array = wtype.get("combo", [])
		if chain.is_empty():
			return
		act = chain[_combo_i % chain.size()]
		_combo_i = (_combo_i + 1) % chain.size()
		anim_name = String(act.get("anim", "attack01"))
		mult = float(act.get("mult", 1.0))
	_set_state("attack")
	var keys := keys_of(anim_name)
	var hits: Array = keys.get("hit", [])
	var length := maxf(anim_length(anim_name), 0.5)
	var hit_t := float(hits[0]) if not hits.is_empty() else length * HIT_FRACTION
	# temps de réaction : l'annonce dure au moins 0,5 s (0,4 s en difficile)
	var delay := maxf(hit_t, 0.6 - 0.1 * difficulty)
	var speed := hit_t / delay
	_state_len = length / speed + 0.15
	_hit_time = delay
	_hit_done = false
	for snd in keys.get("sounds", []):
		get_tree().create_timer(float(snd[0]) / speed, false).timeout.connect(
			func(): Sfx.play_at(self, global_position, String(snd[1]), -6.0))
	play(anim_name, 0.08, speed, true)
	var dmg := atk * mult * damage_dealt_mult() * randf_range(0.9, 1.1)
	var kind := String(act.get("kind", "cone"))
	var r := float(act.get("radius", 3.0))
	var rng := float(act.get("range", 0.0))
	var at := global_position
	var props := {"delay": delay, "damage": dmg, "source": self}
	if kind == "ground":
		at = global_position + to.limit_length(maxf(rng, 4.0))
		props.merge({"shape": "circle", "radius": r})
	elif kind in ["bolt", "line", "fan"] or rng > r + 1.0:
		props.merge({"shape": "line", "length": maxf(rng, r), "width": 1.4 if kind != "line" else maxf(1.4, minf(r, 3.0))})
	elif float(act.get("arc", 120.0)) >= 359.0 or kind == "spin":
		props.merge({"shape": "circle", "radius": r})
	else:
		props.merge({"shape": "cone", "radius": r, "angle": float(act.get("arc", 120.0))})
	if kind == "dash":
		_pending_dash = to.normalized() * minf(to.length(), maxf(rng, 6.0))
	_cur = {"hit_fx": String(act.get("hit_fx", act.get("fx", {}).get("hit", "s00141") if act.get("fx") is Dictionary else "s00141")), "at": at, "yaw": yaw, "r": r}
	_telegraph = Telegraph.spawn(self, at, yaw, props)


func _update_attack(delta: float) -> void:
	var was := _hit_done
	super._update_attack(delta)
	if _hit_done and not was and not _cur.is_empty():
		var hf := String(_cur.hit_fx)
		if hf != "":
			EdenFx.play(self, hf, _cur.at + Vector3.UP * 0.2, float(_cur.yaw), GameData.HERO_SCALE * 1.2)
		_cur = {}
	if _state == "chase":
		# combo : le coup suivant arrive vite, puis une pause après le dernier
		var pause := 0.25 if _combo_i != 0 else 1.1
		_attack_ready_at = _time + pause / (0.7 + 0.3 * difficulty)


## Le héros adverse ne gonfle pas et ne recule pas comme un monstre.
func _on_damaged(_amount: float, _source: Combatant) -> void:
	_flash()
