class_name MlArena
extends Node3D
## Arène d'apprentissage : un héros piloté par une IA (programme Python du dossier ia/) contre
## un ou plusieurs adversaires, sur un sol plat entouré d'un mur. Le jeu et Python se parlent
## par une connexion locale (une ligne JSON par message) et avancent au même pas : Python
## envoie une action, le jeu simule REPEAT images puis renvoie ce que l'IA voit, la récompense
## et la fin de l'épisode.
## Lancement (voir ia/eden_env.py) :
##   Godot --headless --fixed-fps 60 --path game res://scenes/ml_arena.tscn -- --port=50001
##   --watch : fenêtre en temps réel avec caméra et bandeau (regarder l'IA jouer).
## Scénarios (message « reset ») :
##   dummy   : mannequin qui ne bouge pas (apprendre combos, sorts et enchaînements) ;
##   flee    : adversaire de classe fuyard (jouer agressif, esquives d'annulation pour suivre) ;
##   monster : monstres d'Eden, héros à 1 PV (apprendre à esquiver les zones rouges) ;
##   rival   : adversaire de classe (ClassRival), difficulté 0 à 3.

const RADIUS := 15.0  # rayon de l'arène (m)
const REPEAT := 3  # images physiques par décision : 20 décisions par seconde
const LEVEL := 10
const SCENARIOS := ["dummy", "flee", "monster", "rival"]
const HERO_STATES := ["idle", "attack", "skill", "dodge", "jump", "stun"]
const ENEMY_STATES := ["idle", "chase", "attack", "hurt", "cast"]
const HERO_STATUSES := ["fury", "barrier", "titan", "survival", "frenzy", "scar", "chill", "root"]
const ENEMY_STATUSES := ["stun", "bleed", "scar", "purgatory", "chill", "freeze", "shock"]
const BUTTONS := 8  # rien, attaque, sort 1 à 4, esquive, saut

var player: Player
var enemies: Array[Monster] = []
var _peer := StreamPeerTCP.new()
var _buf := ""
var _watch := false
var _static: Array[Node] = []
var _bot := BotInput.new()
var _wait := 0
var _ep := {}  # paramètres de l'épisode (message reset)
var _t := 0.0
var _max_time := 60.0
var _low_hp := 0.0  # PV max du héros pendant l'épisode (0 : normal)
var _prev_enemy_hp := 0.0
var _prev_hero_hp := 0.0
var _prev_counts := {}
var _total := {}
var _last_button := 0
var _monster_pool: Array = []
var _cam: Camera3D
var _label: Label
var _ep_reward := 0.0
var _results: Array = []
var _capture := ""


func _ready() -> void:
	process_physics_priority = -100  # l'action est posée avant que le héros ne bouge
	var port := 50001
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
		elif arg == "--watch":
			_watch = true
		elif arg.begins_with("--capture="):
			_capture = arg.trim_prefix("--capture=")  # capture d'écran à 4 s du 1er combat
	_setup_game_state()
	_build_arena()
	for m in GameData.monsters.values():
		var model := String(m.get("model", ""))
		if int(m.get("rank", 2)) in [2, 3] and ResourceLoader.exists("res://assets/monsters/%s/%s.glb" % [model, model]):
			_monster_pool.append(int(m.id))
	_static.assign(get_children())
	if _peer.connect_to_host("127.0.0.1", port) != OK:
		push_error("arène ML : connexion impossible au port %d" % port)
		get_tree().quit(1)
		return
	var waited := 0
	while _peer.get_status() == StreamPeerTCP.STATUS_CONNECTING and waited < 30000:
		_peer.poll()
		OS.delay_msec(5)
		waited += 5
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		push_error("arène ML : pas de programme Python sur le port %d" % port)
		get_tree().quit(1)
		return
	_peer.set_no_delay(true)


## Réglages neutres et rien d'écrit sur le disque : profil vierge sans équipement, combat au
## clavier, pas d'arrêt sur impact (il ralentit le temps), pas de chiffres sans fenêtre.
func _setup_game_state() -> void:
	Training.active = true  # aucune sauvegarde pendant l'apprentissage
	Training.hero_god = false
	Training.enemies_immortal = false
	Training.enemies_passive = false
	Training.no_cd = false
	Vfx.silent = not _watch
	Settings.data["game"] = {"move_mode": "keyboard", "aim_mode": "smart", "attack_mode": "manual",
		"auto_skills": [false, false, false, false], "auto_target": "any"}
	var ui: Dictionary = Settings.data.get("interface", {})
	ui["hit_stop"] = false
	ui["attack_zone"] = false
	ui["move_marker"] = false
	ui["damage_numbers"] = "all" if _watch else "off"
	Settings.data["interface"] = ui
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Run.start("warrior")
	Profile.equipped = {}


func _build_arena() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = GameData.PHYS_WORLD
	var gs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RADIUS * 3.0, 1.0, RADIUS * 3.0)
	gs.shape = box
	gs.position.y = -0.5
	ground.add_child(gs)
	add_child(ground)
	# mur circulaire : 36 pans
	var n := 36
	for i in n:
		var a := TAU * i / n
		var wall := StaticBody3D.new()
		wall.collision_layer = GameData.PHYS_WORLD
		var ws := CollisionShape3D.new()
		var wb := BoxShape3D.new()
		wb.size = Vector3(TAU * RADIUS / n + 0.4, 4.0, 1.0)
		ws.shape = wb
		wall.add_child(ws)
		add_child(wall)
		wall.position = Vector3(sin(a), 0, cos(a)) * (RADIUS + 0.5) + Vector3.UP * 2.0
		wall.rotation.y = a
		if _watch:
			# bordure basse (le mur invisible fait 4 m, il ne cache pas le combat)
			var wm := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(wb.size.x, 0.4, 0.6)
			wm.mesh = bm
			wm.position.y = -1.8
			var cm := StandardMaterial3D.new()
			cm.albedo_color = Color(0.22, 0.2, 0.18)
			wm.material_override = cm
			wall.add_child(wm)
	if not _watch:
		return
	var gm := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RADIUS + 1.0
	disc.bottom_radius = RADIUS + 1.0
	disc.height = 0.1
	gm.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.36, 0.3)
	gm.material_override = mat
	gm.position.y = -0.05
	add_child(gm)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.13, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(env)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(16, 12)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	add_child(layer)


func _process(_delta: float) -> void:
	if not _watch or player == null or not is_instance_valid(player):
		return
	var e := _nearest_enemy()
	var mid := player.global_position
	if e:
		mid = mid.lerp(e.global_position, 0.35)
	_cam.global_position = _cam.global_position.lerp(mid + Vector3(0, 15, 11), 0.1)
	_cam.look_at(mid, Vector3.UP)
	var txt := "IA Eden Slash · scénario %s%s · %.1f s / %d s\n" % [_ep.get("scenario", ""),
		(" (difficulté %s)" % ClassRival.NAMES[int(_ep.get("difficulty", 0))]) if _ep.get("scenario", "") in ["rival", "flee"] else "", _t, int(_max_time)]
	txt += "Héros %d / %d PV" % [player.hp, player.max_hp]
	if e:
		txt += "   ·   %s %d / %d PV" % [e.display_name, e.hp, e.max_hp]
	txt += "\nRécompense de l'épisode : %.2f   ·   parfaits %d, enchaînements %d, esquives %d" % [_ep_reward,
		player.ml_counts.perfect, player.ml_counts.chain, player.ml_counts.dodged]
	if not _results.is_empty():
		txt += "\nDerniers combats : " + " ".join(_results.slice(-12))
	_label.text = txt
	if _capture != "" and _t > 4.0:
		get_viewport().get_texture().get_image().save_png(_capture)
		_capture = ""


# --- boucle d'échange avec Python ---------------------------------------------------------
func _physics_process(delta: float) -> void:
	if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	if _wait > 0:
		_wait -= 1
		_t += delta
		_bot.pulse.clear()  # une touche n'est appuyée qu'à la première image de la décision
		if _low_hp > 0.0 and player and not player.is_dead:
			player.hp = minf(player.hp, _low_hp)
		if _wait > 0:
			return
		_send_step()
	_serve()


## Lit les ordres de Python jusqu'à une action (le jeu reste figé en attendant).
func _serve() -> void:
	while true:
		var msg := _read_msg()
		match String(msg.get("cmd", "close")):
			"reset":
				_reset(msg)
				_send({"obs": _obs(), "r": 0.0, "done": false, "info": {}})
			"step":
				_apply(msg.get("a", [0, 0, 0]))
				_wait = REPEAT
				return
			_:
				_peer.disconnect_from_host()
				get_tree().quit()
				return


func _read_msg() -> Dictionary:
	while true:
		var i := _buf.find("\n")
		if i >= 0:
			var line := _buf.substr(0, i)
			_buf = _buf.substr(i + 1)
			var d: Variant = JSON.parse_string(line)
			return d if d is Dictionary else {}
		_peer.poll()
		if _peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return {"cmd": "close"}
		var n := _peer.get_available_bytes()
		if n > 0:
			var got: Array = _peer.get_data(n)
			_buf += (got[1] as PackedByteArray).get_string_from_utf8()
		else:
			OS.delay_usec(30)
	return {}


func _send(d: Dictionary) -> void:
	_peer.put_data((JSON.stringify(d) + "\n").to_utf8_buffer())


# --- épisodes -----------------------------------------------------------------------------
func _reset(msg: Dictionary) -> void:
	for c in get_children():
		if not _static.has(c):
			remove_child(c)
			c.queue_free()
	Engine.time_scale = 1.0
	if msg.has("seed"):
		seed(int(msg.seed))
	_ep = msg
	var scen := String(msg.get("scenario", "dummy"))
	_max_time = float(msg.get("max_time", 60.0))
	_setup_skills(int(msg.get("skills", 4)))
	_bot.clear()
	player = Player.new()
	player.level = LEVEL
	player.bot = _bot
	add_child(player)
	var hero_at := _random_point(5.0)
	player.global_position = hero_at + Vector3.UP * 0.1
	_low_hp = float(msg.get("hero_hp", 0.0))
	if _low_hp > 0.0:
		player.hp = _low_hp
	enemies.clear()
	var diff := int(msg.get("difficulty", 1))
	var enemy_class := String(msg.get("enemy_class", "warrior"))
	var count := int(msg.get("count", 1)) if scen == "monster" else 1
	for i in count:
		var e: Monster
		if scen == "monster":
			var m := Monster.new()
			var pool: Array = msg.get("monsters", _monster_pool)
			m.configure(GameData.monster(int(pool.pick_random())), false, LEVEL)
			e = m
		else:
			var r := ClassRival.new()
			r.setup(enemy_class, LEVEL, 0 if scen == "dummy" else diff)
			r.passive = scen == "dummy"
			r.flee = scen == "flee"
			r.flee_center = Vector3.ZERO
			r.flee_radius = RADIUS
			e = r
		e.max_hp *= float(msg.get("enemy_hp", 1.0))
		e.hp = e.max_hp
		e.atk *= float(msg.get("enemy_atk", 1.0))
		add_child(e)
		var ang := randf() * TAU
		var d := randf_range(float(msg.get("min_dist", 4.0)), float(msg.get("max_dist", 9.0)))
		var at := hero_at + Vector3(sin(ang), 0, cos(ang)) * d
		at = at.limit_length(RADIUS - 2.0)
		e.global_position = at + Vector3.UP * 0.4
		e.face_direction(hero_at - at, 1.0, 100.0)
		enemies.append(e)
	player.face_direction(enemies[0].global_position - hero_at, 1.0, 100.0)
	_t = 0.0
	_wait = 0
	_last_button = 0
	_ep_reward = 0.0
	_prev_enemy_hp = _enemy_hp()
	_prev_hero_hp = player.hp
	_prev_counts = player.ml_counts.duplicate()
	_total = {"dealt": 0.0, "taken": 0.0}


## Sorts du guerrier : 4 cases, puis 2 enchaînements par case (12 sorts).
func _setup_skills(n: int) -> void:
	var all: Array = Run.class_data().get("skills", [])
	Run.skills.clear()
	Run.chains.clear()
	for i in mini(4, all.size()):
		Run.skills.append({"id": int(all[i].id), "rank": 1})
	if n > 4:
		for slot in 4:
			var ch: Array = []
			for k in 2:
				var idx := 4 + slot * 2 + k
				if idx < all.size() and idx < n:
					ch.append({"id": int(all[idx].id), "rank": 1})
			if not ch.is_empty():
				Run.chains[slot] = ch


func _random_point(r: float) -> Vector3:
	var a := randf() * TAU
	var d := sqrt(randf()) * r
	return Vector3(sin(a) * d, 0.0, cos(a) * d)


func _apply(a: Array) -> void:
	var move := int(a[0]) if a.size() > 0 else 0
	var button := int(a[1]) if a.size() > 1 else 0
	var aim := int(a[2]) if a.size() > 2 else 0
	var f := _fwd()
	var s := _side(f)
	_bot.hold.clear()
	_bot.pulse.clear()
	_bot.move = Vector3.ZERO
	if move > 0:
		var ang := (move - 1) * PI / 4.0
		_bot.move = (f * cos(ang) + s * sin(ang)).normalized()
	match button:
		1:
			_bot.hold["attack"] = true
		2, 3, 4, 5:
			_bot.pulse["skill_%d" % (button - 1)] = true
		6:
			_bot.pulse["dodge"] = true
		7:
			_bot.pulse["jump"] = true
	_last_button = button
	var e := _nearest_enemy()
	if e:
		var v := e.velocity
		v.y = 0.0
		_bot.aim = e.global_position + v * (0.25 * aim)
	else:
		_bot.aim = player.global_position + player.forward() * 3.0


func _send_step() -> void:
	var r := 0.0
	var e_hp := _enemy_hp()
	var dealt := maxf(0.0, _prev_enemy_hp - e_hp)
	var taken := maxf(0.0, _prev_hero_hp - player.hp)
	_prev_enemy_hp = e_hp
	_prev_hero_hp = player.hp
	_total.dealt += dealt
	_total.taken += taken
	r += 10.0 * dealt / maxf(_enemy_max_hp(), 1.0)
	r -= float(_ep.get("w_taken", 1.0)) * 10.0 * taken / maxf(player.max_hp, 1.0)
	var bonus: Dictionary = _ep.get("bonus", {})
	for k in player.ml_counts:
		var dk: int = int(player.ml_counts[k]) - int(_prev_counts.get(k, 0))
		if dk > 0:
			r += dk * float(bonus.get(k, 0.0))
	_prev_counts = player.ml_counts.duplicate()
	r -= float(_ep.get("time_penalty", 0.002))
	var done := false
	var result := ""
	if _nearest_enemy() == null:
		done = true
		result = "win"
		r += float(_ep.get("win_bonus", 5.0))
	elif player.is_dead:
		done = true
		result = "loss"
		r -= float(_ep.get("loss_penalty", 5.0))
	elif _t >= _max_time:
		done = true
		result = "timeout"
		r += float(_ep.get("timeout_reward", -1.0))
	_ep_reward += r
	var info := {}
	if done:
		info = {"result": result, "t": _t, "dealt": _total.dealt / maxf(_enemy_max_hp(), 1.0),
			"taken": _total.taken / maxf(player.max_hp, 1.0), "perfect": player.ml_counts.perfect,
			"chain": player.ml_counts.chain, "dodged": player.ml_counts.dodged, "reward": _ep_reward}
		_results.append({"win": "V", "loss": "D", "timeout": "-"}[result])
	_send({"obs": _obs(), "r": r, "done": done, "info": info})


func _enemy_hp() -> float:
	var t := 0.0
	for e in enemies:
		if is_instance_valid(e):
			t += maxf(e.hp, 0.0)
	return t


func _enemy_max_hp() -> float:
	var t := 0.0
	for e in enemies:
		if is_instance_valid(e):
			t += e.max_hp
	return t


func _nearest_enemy() -> Monster:
	var best: Monster = null
	var bd := INF
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead:
			var d := e.global_position.distance_squared_to(player.global_position)
			if d < bd:
				bd = d
				best = e
	return best


## Repère de l'IA : avant = vers l'adversaire le plus proche (horizontal).
func _fwd() -> Vector3:
	var e := _nearest_enemy()
	var to := (e.global_position - player.global_position) if e else player.forward()
	to.y = 0.0
	return to.normalized() if to.length() > 0.01 else Vector3.FORWARD


func _side(f: Vector3) -> Vector3:
	return Vector3(f.z, 0.0, -f.x)


# --- ce que voit l'IA ----------------------------------------------------------------------
func _obs() -> Array:
	var o: Array = []
	var p := player
	var f := _fwd()
	var s := _side(f)
	var scen := String(_ep.get("scenario", "dummy"))
	_one_hot(o, SCENARIOS.find(scen), SCENARIOS.size())
	o.append(float(_ep.get("difficulty", 0)) / 3.0)
	o.append(1.0 if int(_ep.get("skills", 4)) > 4 else 0.0)
	o.append(1.0 if _low_hp > 0.0 else 0.0)
	o.append(clampf(_t / maxf(_max_time, 1.0), 0.0, 1.0))
	# --- héros
	o.append(p.hp / maxf(p.max_hp, 1.0))
	_one_hot(o, HERO_STATES.find(p._state), HERO_STATES.size())
	var acting := p._state in ["attack", "skill"]
	o.append(clampf(p._state_time / 2.0, 0.0, 1.0))
	o.append(clampf((float(p._hits[0]) - p._state_time) / 1.5, 0.0, 1.0) if acting and not p._hits.is_empty() else 0.0)
	o.append(1.0 if acting and p._action.get("hit_done", false) else 0.0)
	o.append(1.0 if p._state == "skill" and p._action.get("hit_done", false) and p._time - p._last_hit_at <= Player.PERFECT_WINDOW else 0.0)
	o.append(clampf(p._state_len / 2.0, 0.0, 1.0) if acting else 0.0)
	var cs := p.combo_state()
	o.append(float(cs.x) / maxf(cs.y, 1.0))
	o.append(clampf(p._combo_expire - p._time, 0.0, 1.0))
	o.append(p.dodge_cooldown().x / Player.DODGE_COOLDOWN)
	o.append(clampf((p._skill_lock_until - p._time) / 1.5, 0.0, 1.0))
	o.append(1.0 if p.is_on_floor() else 0.0)
	o.append(clampf(p.velocity.y / 15.0, -1.0, 1.0))
	o.append(p._jumps_used / 2.0)
	o.append(p._air_dashes / 2.0)
	o.append(p.flow_state().x / 4.0)
	for slot in 4:
		var sk := p.skill_in_slot(slot)
		if sk.is_empty():
			o.append_array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
			continue
		var cd := p.cooldown_left(slot)
		var ch := p.chain_state(slot)
		o.append(1.0 if cd <= 0.0 else 0.0)
		o.append(clampf(cd / 20.0, 0.0, 1.0))
		o.append(1.0 if not ch.is_empty() and ch.phase == "lock" else 0.0)
		o.append(float(ch.p) if not ch.is_empty() and ch.phase == "bar" else 0.0)
		o.append(1.0 if not ch.is_empty() else 0.0)
		o.append(Run.chain_of(slot).size() / 2.0)
	for st in HERO_STATUSES:
		o.append(1.0 if p.has_status(st) else 0.0)
	var off := p.global_position
	off.y = 0.0
	o.append(off.dot(s) / RADIUS)
	o.append(off.dot(f) / RADIUS)
	o.append(clampf((RADIUS - off.length()) / RADIUS, 0.0, 1.0))
	var pf := p.forward()
	o.append(pf.dot(s))
	o.append(pf.dot(f))
	o.append(clampf(p.velocity.dot(s) / 15.0, -1.5, 1.5))
	o.append(clampf(p.velocity.dot(f) / 15.0, -1.5, 1.5))
	o.append(clampf(p.attack_reach() / 10.0, 0.0, 1.0))
	# --- adversaire le plus proche
	var e := _nearest_enemy()
	if e == null:
		o.append_array(_zeros(29))
	else:
		var to := e.global_position - p.global_position
		to.y = 0.0
		o.append(e.hp / maxf(e.max_hp, 1.0))
		o.append(clampf(to.length() / 20.0, 0.0, 1.5))
		o.append(clampf((to.length() - e.radius - p.attack_reach()) / 5.0, -1.0, 1.0))
		var ef := e.forward()
		o.append(ef.dot(s))
		o.append(ef.dot(f))
		o.append(clampf(e.velocity.dot(s) / 15.0, -1.5, 1.5))
		o.append(clampf(e.velocity.dot(f) / 15.0, -1.5, 1.5))
		var eo := e.global_position
		eo.y = 0.0
		o.append(eo.dot(s) / RADIUS)
		o.append(eo.dot(f) / RADIUS)
		_one_hot(o, ENEMY_STATES.find(e._state), ENEMY_STATES.size())
		o.append(clampf((e._hit_time - e._state_time) / 1.5, 0.0, 1.0) if e._state == "attack" and not e._hit_done else 0.0)
		var rival := e as ClassRival
		o.append(1.0 if rival and rival.is_invulnerable() else 0.0)
		o.append(rival._charges / 3.0 if rival else 0.0)
		o.append(1.0 if e._time < e._dash_until else 0.0)
		o.append(1.0 if e.is_disabled() else 0.0)
		o.append(0.0 if e.is_on_floor() else 1.0)
		for st in ENEMY_STATUSES:
			o.append(1.0 if e.has_status(st) else 0.0)
		o.append(clampf(e.radius, 0.0, 2.0) / 2.0)
		o.append(minf(enemies.filter(func(x): return is_instance_valid(x) and not x.is_dead).size(), 4) / 4.0)
	# --- menaces : les 2 zones rouges les plus proches de l'impact
	var tels: Array = []
	for c in get_children():
		var tg := c as Telegraph
		if tg and tg.is_processing() and tg.color != Telegraph.PLAYER_COLOR:
			tels.append(tg)
	tels.sort_custom(func(a, b): return a.delay - a._t < b.delay - b._t)
	for i in 2:
		if i >= tels.size():
			o.append_array(_zeros(11))
			continue
		var tg: Telegraph = tels[i]
		var rel := tg.global_position - p.global_position
		rel.y = 0.0
		var dir := Vector3(sin(tg.rotation.y), 0.0, cos(tg.rotation.y))
		o.append(1.0)
		o.append(clampf((tg.delay - tg._t) / 1.5, 0.0, 1.0))
		o.append(1.0 if tg.contains(p.global_position, p.radius) else 0.0)
		_one_hot(o, ["circle", "cone", "line"].find("circle" if tg.shape == "ring" else tg.shape), 3)
		o.append(clampf(rel.dot(s) / RADIUS, -2.0, 2.0))
		o.append(clampf(rel.dot(f) / RADIUS, -2.0, 2.0))
		o.append(dir.dot(s))
		o.append(dir.dot(f))
		o.append(clampf((tg.length if tg.shape == "line" else tg.radius) / 12.0, 0.0, 1.5))
	# --- projectile le plus proche
	var proj: Projectile = null
	var pd := INF
	for c in get_children():
		var pr := c as Projectile
		if pr:
			var d := pr.global_position.distance_squared_to(p.global_position)
			if d < pd:
				pd = d
				proj = pr
	if proj:
		var rel := proj.global_position - p.global_position
		rel.y = 0.0
		o.append_array([1.0, clampf(rel.dot(s) / RADIUS, -2.0, 2.0), clampf(rel.dot(f) / RADIUS, -2.0, 2.0), proj.dir.dot(s), proj.dir.dot(f)])
	else:
		o.append_array(_zeros(5))
	_one_hot(o, _last_button, BUTTONS)
	return o


func _one_hot(o: Array, i: int, n: int) -> void:
	for k in n:
		o.append(1.0 if k == i else 0.0)


func _zeros(n: int) -> Array:
	var z: Array = []
	z.resize(n)
	z.fill(0.0)
	return z
