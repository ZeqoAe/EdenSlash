class_name ClassRival
extends Monster
## Adversaire de la zone d'entraînement : un héros d'une classe (corps, tenue, arme) qui
## enchaîne le combo de son arme et lance les sorts de la classe. Ses coups sont annoncés au
## sol en rouge (comme les monstres) avec la forme du coup ou du sort (cône, cercle, ligne,
## zone visée) et les effets d'Eden.
## Il lit les coups du héros (zone et instant d'impact) et esquive au bon moment, se tient
## juste hors de portée en tournant autour de lui, colle ou fuit selon son arme, punit les
## temps morts (récupération d'un sort, esquive en recharge), annule ses coups par une
## esquive ou un saut et vise là où le héros va être.
## Difficulté : 0 facile, 1 normal, 2 difficile, 3 hardcore.

const NAMES := ["Facile", "Normal", "Difficile", "Hardcore"]
## Réglages par difficulté :
##   react : délai de réaction (s) ; read : chance de lire un coup et de l'esquiver ;
##   charges / recharge : esquives d'avance et temps pour en regagner une ;
##   tele : durée minimale de l'annonce rouge ; pause / pause_end : entre deux coups du
##   combo / après le dernier ; cancel : chance d'annuler la fin d'un coup (esquive ou saut) ;
##   hop : envie de sauter / foncer pour se replacer ; lead : anticipation du déplacement du
##   héros ; punish : saute sur les temps morts ; hp / atk : PV et dégâts ; speed : vitesse.
const DIFF := [
	{"react": 0.45, "read": 0.12, "charges": 1, "recharge": 3.5, "tele": 0.6, "pause": 0.4, "pause_end": 1.4,
		"cancel": 0.0, "hop": 0.0, "lead": 0.0, "punish": 0.0, "hp": 3.0, "atk": 0.35, "speed": 4.6, "skill_cd": 1.6},
	{"react": 0.3, "read": 0.35, "charges": 1, "recharge": 2.2, "tele": 0.5, "pause": 0.3, "pause_end": 1.0,
		"cancel": 0.15, "hop": 0.08, "lead": 0.3, "punish": 0.3, "hp": 4.5, "atk": 0.5, "speed": 5.4, "skill_cd": 1.3},
	{"react": 0.16, "read": 0.7, "charges": 2, "recharge": 1.3, "tele": 0.4, "pause": 0.18, "pause_end": 0.55,
		"cancel": 0.5, "hop": 0.25, "lead": 0.6, "punish": 0.7, "hp": 6.0, "atk": 0.65, "speed": 6.2, "skill_cd": 1.0},
	{"react": 0.06, "read": 0.95, "charges": 3, "recharge": 0.7, "tele": 0.32, "pause": 0.08, "pause_end": 0.22,
		"cancel": 0.9, "hop": 0.5, "lead": 0.85, "punish": 1.0, "hp": 8.0, "atk": 0.8, "speed": 7.0, "skill_cd": 0.75},
]
const DASH_SPEED := 17.0
const DASH_TIME := 0.2
const DASH_IFRAMES := 0.28
const JUMP_SPEED := 9.5

var cid := "warrior"
var cls: Dictionary = {}
var wtype: Dictionary = {}
var difficulty := 1
var cfg: Dictionary = DIFF[1]
var _combo_i := 0
var _skills: Array = []
var _skill_ready := {}  # id -> temps où le sort est de nouveau prêt
var _cur: Dictionary = {}  # coup ou sort en cours : {hit_fx, at, yaw}
var _invuln_until := 0.0
var _charges := 1.0  # esquives disponibles
var _air_dash := true  # une esquive en l'air avant de retoucher le sol
var _jump_req := 0.0
var _strafe := 1.0  # sens de rotation autour du héros
var _strafe_flip_at := 0.0
var _seen_action := {}  # coup du héros déjà jugé (une décision par coup)
var _react_at := -1.0  # instant où l'esquive décidée part (délai de réaction)
var _react_dir := Vector3.ZERO
var _hop_ready := 0.0
var _dodge_until := 0.0  # pas de coup pendant le bond d'esquive
var _cancel_roll := false  # ce coup sera annulé juste après son impact
## Fuyard (arène ML) : n'attaque jamais, garde ses distances, s'échappe d'un bond quand le
## héros colle et longe le bord de l'arène (centre [member flee_center], rayon [member flee_radius]).
var flee := false
var flee_center := Vector3.ZERO
var flee_radius := 0.0  # 0 : pas de bord


## Classe [param class_id] au niveau [param lvl] (PV et dégâts d'un héros de ce niveau).
## [param hp_scale] : PV en plus ou en moins (la Tour) ; [param n_skills] : sorts utilisés.
func setup(class_id: String, lvl: int, diff := 1, hp_scale := 1.0, n_skills := 4) -> void:
	cid = class_id
	cls = GameData.class_data(cid)
	wtype = GameData.weapon_type(String(cls.get("weapon_type", "")))
	difficulty = clampi(diff, 0, DIFF.size() - 1)
	cfg = DIFF[difficulty]
	level = maxi(1, lvl)
	data = {"name": String(cls.get("name_fr", cid)), "model": "", "rank": 3, "level": level}
	is_elite = true
	display_name = "%s · adversaire %s" % [cls.get("name_fr", cid), String(NAMES[difficulty]).to_lower()]
	var base: Dictionary = cls.get("base", {})
	max_hp = GameData.player_max_hp(level) * float(base.get("hp", 1.0)) * float(cfg.hp) * hp_scale
	hp = max_hp
	var magic := String(cls.get("dmg_type", "phys")) in ["mag", "magic"]
	atk = GameData.player_atk(level) * float(base.get("matk" if magic else "atk", 1.0)) * float(cfg.atk)
	defense = 4.0 + level * 2.0
	xp_reward = 0
	move_speed = float(cfg.speed)
	_charges = float(cfg.charges)
	_skills = (cls.get("skills", []) as Array).filter(func(s): return String(s.kind) != "buff" and String(s.kind) != "heal").slice(0, clampi(n_skills, 0, 4))


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


func _ranged() -> bool:
	return _attack_range() > 6.0


func is_invulnerable() -> bool:
	return _time < _invuln_until


# --- cerveau ------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_dead and not is_disabled() and not is_passive() and _can_target() and _state != "spawn":
		_charges = minf(float(cfg.charges), _charges + delta / float(cfg.recharge))
		if is_on_floor():
			_air_dash = true
		_read_player()
	super._physics_process(delta)


## Saut : la vitesse verticale est posée à la place de la gravité de cette image.
func apply_gravity(delta: float) -> void:
	if _jump_req > 0.0:
		velocity.y = _jump_req
		_jump_req = 0.0
		return
	super.apply_gravity(delta)


## Juge le coup en cours du héros : si l'adversaire est dans sa zone, il esquive juste avant
## l'impact (après son délai de réaction), et peut annuler son propre coup pour ça.
func _read_player() -> void:
	if _react_at >= 0.0:
		if _time >= _react_at:
			_react_at = -1.0
			if _can_dodge():
				_dodge(_react_dir)
		return
	var th := _threat()
	if th.is_empty():
		return
	var act: Dictionary = _player._action
	if is_same(act, _seen_action):
		return
	_seen_action = act
	if randf() > float(cfg.read) or is_invulnerable():
		return
	# part le plus tard possible (i-frames au moment du coup), sans dépasser l'impact
	var wait := clampf(float(th.t) - DASH_IFRAMES * 0.6, float(cfg.react), maxf(float(th.t) - 0.04, 0.0))
	if float(th.t) < float(cfg.react):
		return  # trop tard pour réagir
	# son propre coup sort avant celui du héros : il le place, puis esquive (annulation)
	if _state == "attack" and not _hit_done and _hit_time - _state_time + 0.03 < float(th.t) - 0.04:
		wait = clampf(maxf(wait, _hit_time - _state_time + 0.03), 0.0, float(th.t) - 0.04)
	_react_dir = th.dir
	_react_at = _time + wait


## Coup du héros qui va toucher l'adversaire : {t (s avant l'impact), dir (sortie)} ou {}.
func _threat() -> Dictionary:
	var p := _player
	if not (p._state in ["attack", "skill"]) or p._hits.is_empty():
		return {}
	var a: Dictionary = p._action
	var kind := String(a.get("kind", "cone"))
	if kind in ["buff", "heal"]:
		return {}
	var t: float = float(p._hits[0]) - p._state_time
	var origin := p.global_position
	var fwd := p.forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var to := global_position - origin
	to.y = 0.0
	var r := float(a.get("radius", Player.ATTACK_RANGE)) + radius + 0.7
	var rng := float(a.get("range", 0.0))
	var side := fwd.cross(Vector3.UP).normalized()
	var lateral := to.dot(side)
	var away_side := side * (signf(lateral) if absf(lateral) > 0.2 else (1.0 if randf() < 0.5 else -1.0))
	if kind == "ground" and a.has("target"):
		var c: Vector3 = a.target
		var off := global_position - c
		off.y = 0.0
		if off.length() > float(a.get("radius", 3.0)) + radius + 0.6:
			return {}
		return {"t": t, "dir": (off.normalized() if off.length() > 0.3 else away_side).rotated(Vector3.UP, randf_range(-0.5, 0.5))}
	if kind in ["bolt", "line"] or rng > r:
		var along := to.dot(fwd)
		var w := (maxf(1.2, minf(float(a.get("radius", 1.2)), 3.0)) if kind == "line" else 1.2) * 0.5 + radius + 0.5
		if along < -1.0 or along > maxf(rng, r) + 1.0 or absf(lateral) > w:
			return {}
		if kind == "bolt":
			t += maxf(along, 0.0) / 30.0  # trajet de la flèche
		return {"t": t, "dir": away_side}
	if to.length() > r:
		return {}
	var arc := float(a.get("arc", 150.0))
	if arc < 359.0 and to.length() > 1.2 and rad_to_deg(fwd.angle_to(to.normalized())) > arc * 0.5 + 15.0:
		return {}
	# cône ou cercle : de côté et en arrière, hors de portée
	var out := (to.normalized() * 0.6 + away_side).normalized() if arc < 359.0 else to.normalized()
	return {"t": t, "dir": out}


func _can_dodge() -> bool:
	if _charges < 1.0 or has_status("root"):
		return false
	return is_on_floor() or _air_dash


## Le héros est ouvert : récupération d'un sort, fin d'action, esquive en recharge.
func _player_open() -> bool:
	var p := _player
	if p.is_invulnerable():
		return false
	if p._state in ["attack", "skill"] and p._hits.is_empty():
		return true
	return p._skill_lock_until > p._time or (p._state != "dodge" and p._dodge_ready_at > p._time + 0.15)


## Esquive : petit bond rapide, invulnérable pendant le coup ; annule l'action en cours.
func _dodge(dir: Vector3, iframes := true) -> void:
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = -forward()
	dir = dir.normalized()
	_charges -= 1.0
	if not is_on_floor():
		_air_dash = false
	_cancel_attack()
	_dash_vel = dir * DASH_SPEED
	_dash_until = _time + DASH_TIME
	_dodge_until = _dash_until
	if iframes:
		_invuln_until = _time + DASH_IFRAMES
	face_direction(dir, 1.0, 100.0)
	play(_anim("dodge", "jump02"), 0.05, 1.6, true)
	_set_state("chase")
	# riposte : en difficile et hardcore, l'adversaire ressort aussitôt
	_attack_ready_at = minf(maxf(_attack_ready_at, _time + DASH_TIME), _time + DASH_TIME + 0.4 - 0.1 * difficulty)


func _jump(dir: Vector3) -> void:
	if not is_on_floor():
		return
	_jump_req = JUMP_SPEED
	dir.y = 0.0
	if dir.length() > 0.1:
		_dash_vel = dir.normalized() * move_speed * 1.4
		_dash_until = _time + 0.55
	play(_anim("jump", "jump01"), 0.05, 1.3, true)


## Coup annulé (esquive ou saut) : l'annonce disparaît, rien ne tombe.
func _cancel_attack() -> void:
	if _state == "attack" and not _hit_done and is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_pending_dash = Vector3.ZERO
	_cur = {}
	if _state == "attack":
		_set_state("chase")


func _update_idle(delta: float) -> Vector3:
	var v := super._update_idle(delta)
	if is_passive() or not _can_target():
		play(_anim("idle", "stand01"), 0.3)
	return v


## Placement : au corps-à-corps, il tourne autour du héros juste hors de sa portée et
## fonce dès que son coup est prêt ; à distance, il recule en gardant le héros à portée.
func _update_chase(delta: float) -> Vector3:
	if is_passive() or not _can_target():
		_set_state("idle")
		return Vector3.ZERO
	if flee:
		return _update_flee(delta)
	var to := _player.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else forward()
	face_direction(to, delta, 16.0)
	if _time >= _strafe_flip_at:
		_strafe = -_strafe if randf() < 0.6 else _strafe
		_strafe_flip_at = _time + randf_range(0.6, 1.6)
	var tangent := dir.cross(Vector3.UP) * _strafe
	var reach := _attack_range()
	# temps mort du héros : l'adversaire frappe tout de suite (aussitôt en hardcore)
	if _time >= _dodge_until and _player_open() and (float(cfg.punish) >= 1.0 or randf() < float(cfg.punish) * delta * 6.0):
		_attack_ready_at = minf(_attack_ready_at, _time)
	var ready := _time >= _attack_ready_at and _time >= _dodge_until and not has_status("disarm") and not has_status("fear")
	var v := Vector3.ZERO
	# tireur collé par le héros : recule d'un bond avant de tirer
	if ready and _ranged() and dist < 4.0 and difficulty >= 2 and _charges >= 1.2 and _time >= _hop_ready:
		_hop_ready = _time + 0.6
		_dodge((-dir + tangent * 0.7).normalized(), false)
		_attack_ready_at = _time + DASH_TIME + 0.02
		return _dash_vel
	if ready and dist <= reach + 0.3:
		_start_attack()
		return Vector3.ZERO
	if ready:
		# coup prêt mais trop loin : fonce (bond ou saut en difficile et hardcore)
		if dist > reach + 3.0 and _time >= _hop_ready and randf() < float(cfg.hop):
			_hop_ready = _time + 0.5
			if _charges >= 2.0 or (_charges >= 1.0 and difficulty < 3):
				_dodge(dir.rotated(Vector3.UP, randf_range(-0.35, 0.35)), false)
				return _dash_vel
			_jump(dir)
			return _dash_vel
		v = _path_step(_player.global_position) * move_speed
	elif _ranged():
		# garde ses distances : recule si le héros approche, sinon tourne autour
		var want := reach * 0.75
		if dist < 4.5 and _can_dodge() and _charges >= 1.5 and _time >= _hop_ready and randf() < float(cfg.hop) * 2.0:
			_hop_ready = _time + 0.4
			_dodge((-dir + tangent * 0.6).normalized(), false)
			return _dash_vel
		v = (tangent + (-dir if dist < want else dir) * clampf(absf(dist - want) / 2.0, 0.0, 1.0)).normalized() * move_speed
	else:
		# hors de portée du héros en attendant son coup, en tournant autour de lui
		var want := maxf(_player.attack_reach() + radius + 1.0, reach + 0.6)
		var radial := clampf((dist - want) / 1.5, -1.0, 1.0)
		v = (tangent * (0.5 + 0.5 * float(difficulty >= 2)) + dir * radial).normalized() * move_speed * (0.55 + 0.15 * difficulty)
		if difficulty >= 2 and _time >= _hop_ready and randf() < float(cfg.hop) * 0.04:
			_hop_ready = _time + 0.8
			_jump(tangent)
	if _time >= _dash_until and is_on_floor():
		play(_anim("run", "move02") if v.length() > 0.1 else _battle_anim(), 0.15)
	return v


## Fuite : s'éloigne du héros en tournant autour de lui, se rabat vers le centre près du
## bord (sinon il se ferait coincer) et bondit hors de portée quand le héros colle.
func _update_flee(delta: float) -> Vector3:
	var away := global_position - _player.global_position
	away.y = 0.0
	var dist := away.length()
	away = away.normalized() if dist > 0.01 else -forward()
	if _time >= _strafe_flip_at:
		_strafe = -_strafe if randf() < 0.5 else _strafe
		_strafe_flip_at = _time + randf_range(0.8, 2.0)
	var tangent := away.cross(Vector3.UP) * _strafe
	var v := away + tangent * 0.7
	if flee_radius > 0.0:
		var off := global_position - flee_center
		off.y = 0.0
		var edge := clampf((off.length() - (flee_radius - 5.0)) / 4.0, 0.0, 1.0)
		if edge > 0.0:
			# près du bord : longe le mur du côté opposé au héros
			var along := off.normalized().cross(Vector3.UP)
			if along.dot(away) < 0.0:
				along = -along
			v = v.lerp(along * 1.2 - off.normalized() * 0.6, edge)
	if dist < 3.6 and _can_dodge() and _time >= _hop_ready and randf() < 0.25 + float(cfg.hop):
		_hop_ready = _time + 0.7
		var esc := v.normalized()
		_dodge(esc.rotated(Vector3.UP, randf_range(-0.4, 0.4)), false)
		return _dash_vel
	face_direction(v, delta, 12.0)
	if _time >= _dash_until and is_on_floor():
		play(_anim("run", "move02"), 0.15)
	return v.normalized() * move_speed * (0.75 if dist > 9.0 else 1.0)


## Sort prêt (le plus utile à cette distance), sinon le coup suivant du combo.
## Les coups visent là où le héros sera à l'impact.
func _start_attack() -> void:
	var to := _player.global_position - global_position
	to.y = 0.0
	var sk: Dictionary = {}
	var finisher := _combo_i == 0
	for s in _skills:
		var ready := _time >= float(_skill_ready.get(int(s.id), 1.0 + randf() * 2.0 / (1.0 + difficulty)))
		# hardcore : les sorts tombent en fin de combo ou quand le héros est ouvert
		var want := randf() < 0.55 + 0.15 * difficulty if difficulty < 3 else (finisher or _player_open() or to.length() > _attack_range() + 2.0)
		if ready and want:
			sk = s
			break
	var act: Dictionary
	var anim_name: String
	var mult: float
	if not sk.is_empty():
		_skill_ready[int(sk.id)] = _time + float(sk.cooldown) * float(cfg.skill_cd)
		act = sk
		anim_name = String(sk.get("anim", "attack01"))
		mult = float(sk.get("mult", 1.5))
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
	var delay := maxf(hit_t * (1.0 if difficulty < 3 else 0.7), float(cfg.tele))
	var speed := hit_t / delay
	_state_len = length / speed + 0.15
	_hit_time = delay
	_hit_done = false
	# vise où le héros sera à l'impact
	var pv := _player.velocity
	pv.y = 0.0
	var aim := _player.global_position + pv * delay * float(cfg.lead)
	to = aim - global_position
	to.y = 0.0
	var yaw := atan2(to.x, to.z)
	face_direction(to, 1.0, 100.0)
	if not sk.is_empty():
		EdenFx.play(self, String(sk.get("fx", {}).get("cast", "")), global_position, yaw, GameData.HERO_SCALE, self)
	for snd in keys.get("sounds", []):
		get_tree().create_timer(float(snd[0]) / speed, false).timeout.connect(func():
			if _state == "attack":
				Sfx.play_at(self, global_position, String(snd[1]), -6.0))
	play(anim_name, 0.06, speed, true)
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
	var fx: Variant = act.get("fx")
	_cur = {"hit_fx": String(act.get("hit_fx", fx.get("hit", "s00141") if fx is Dictionary else "s00141")), "at": at, "yaw": yaw}
	_telegraph = Telegraph.spawn(self, at, yaw, props)


func _update_attack(delta: float) -> void:
	var was := _hit_done
	super._update_attack(delta)
	if _hit_done and not was:
		_cancel_roll = randf() < float(cfg.cancel)
	if _hit_done and not was and not _cur.is_empty():
		var hf := String(_cur.hit_fx)
		if hf != "":
			EdenFx.play(self, hf, _cur.at + Vector3.UP * 0.2, float(_cur.yaw), GameData.HERO_SCALE * 1.2)
		_cur = {}
	# annulation : juste après l'impact, la fin du coup est coupée par une esquive, un saut
	# ou directement le coup suivant
	if _state == "attack" and _hit_done and _state_time >= _hit_time + 0.06 and _time >= _dash_until:
		if _cancel_roll:
			_cancel_roll = false
			_cancel_after_hit()
			return
	if _state == "chase":
		_end_of_hit()


func _cancel_after_hit() -> void:
	_set_state("chase")
	var to := _player.global_position - global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.01 else forward()
	var side := dir.cross(Vector3.UP) * _strafe
	var roll := randf()
	if _ranged():
		if _charges >= 1.5 and roll < 0.5:
			_dodge((-dir + side).normalized(), true)  # recule en tirant
		elif roll < 0.8:
			_jump(-dir)
	elif _charges >= 1.5 and roll < 0.45:
		_dodge((side * 1.4 + dir * 0.4).normalized(), true)  # passe sur le flanc
	elif roll < 0.7 and difficulty >= 2:
		_jump(side)
	_end_of_hit()


## Pause avant le coup suivant : courte dans le combo, plus longue après le dernier.
func _end_of_hit() -> void:
	var pause := float(cfg.pause) if _combo_i != 0 else float(cfg.pause_end)
	_attack_ready_at = _time + pause * randf_range(0.85, 1.15)


func take_damage(amount: float, source: Combatant = null, crit := false, dot := false) -> void:
	if is_invulnerable() and not dot:
		DamageNumber.spawn_text(self, "ESQUIVE", Color(0.7, 1.0, 0.7))
		return
	super.take_damage(amount, source, crit, dot)
	# touché sans l'avoir vu venir (flèche, sort) : sort du combo du héros
	if not is_dead and not dot and not is_passive() and _react_at < 0.0 and _can_dodge() \
			and randf() < 0.1 + 0.25 * difficulty and (_state != "attack" or randf() < float(cfg.cancel)):
		var away := global_position - (source.global_position if source else global_position - forward())
		away.y = 0.0
		_dodge(away.normalized().rotated(Vector3.UP, randf_range(-1.0, 1.0)))


## Le héros adverse ne gonfle pas et ne recule pas comme un monstre.
func _on_damaged(_amount: float, _source: Combatant) -> void:
	_flash()
