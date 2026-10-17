extends Node3D
## NET-0 : prototype JETABLE de liaison hôte / client (ENet + API multijoueur de haut niveau de Godot 4).
## Rien du jeu n'en dépend ; il prouve la faisabilité de l'architecture recommandée dans
## conception/benchmark/NETWORK.md (hôte autoritaire « listen server », entrées envoyées, instantanés renvoyés) :
## - l'HÔTE simule TOUS les héros avec les vrais `Player` du jeu ; le héros d'un ami est un `Player` piloté par un
##   `BotInput` (le même point d'entrée que l'arène d'IA) rempli par les paquets d'entrées reçus ;
## - le CLIENT ne simule rien : il envoie ses entrées (30 par seconde) et affiche des « marionnettes » (`Player` sans
##   logique, modèle et animations du jeu) placées par interpolation entre les instantanés de l'hôte (30 par seconde).
## Lancement (voir tools/net_probe.py pour plusieurs fenêtres d'un coup, chacune avec son dossier utilisateur) :
##   Godot --path game res://tools/net_probe.tscn -- --net-host [--net-class=warrior]
##   Godot --path game res://tools/net_probe.tscn -- --net-join=127.0.0.1 [--net-class=magician]
## Options : --net-shot=<png> (capture à 10 s), --net-port=24680, --net-pilot (pilote automatique au lieu du clavier), --net-secs=N (mesure puis quitte, ligne
## « [net] {json} »), --net-lag=ms (aller-retour ajouté côté client), --net-loss=% (paquets perdus côté client, dans les deux
## sens), --net-snap=30 (instantanés par seconde), --net-compress (compression ENet range coder, aux deux bouts).
## Clavier (sans --net-pilot) : ZQSD / flèches, clic gauche attaque vers la souris, 1-4 sorts, Maj esquive, Espace saut.

const PORT := 24680
const MAX_CLIENTS := 7  # 8 héros au plus (4 contre 4)
const INPUT_HZ := 30
const INTERP := 0.1  # retard d'affichage du client (s) : 3 instantanés d'avance à 30 par seconde
const PULSES := ["skill_1", "skill_2", "skill_3", "skill_4", "dodge", "jump", "swap_weapon"]
const ARENA := 14.0
const CLIENT_CLASSES := ["magician", "hunter", "cleric", "knight", "thief", "bard", "samurai"]

var is_host := false
var _port := PORT
var _join_ip := ""
var _class := ""
var _pilot := false
var _secs := 0.0
var _lag := 0.0  # s, aller-retour ajouté (moitié à l'aller, moitié au retour)
var _loss := 0.0  # 0..1
var _snap_hz := 30
var _compress := false
var _version := Version.NUMBER  # --net-version=x : essai du refus d'une autre version
var _shot := ""  # --net-shot=<fichier.png> : capture de la fenêtre à 10 s (vérification visuelle)
var _headless := false

var _peer: ENetMultiplayerPeer
var _connected := false
var _t := 0.0  # horloge locale (s, physique)
var _tick := 0
var _rng := RandomNumberGenerator.new()

# héros : id du pair -> Player (vrai héros simulé chez l'hôte, marionnette chez le client)
var heroes := {}
var _classes := {}  # id du pair -> classe
var _labels := {}  # id du pair -> Label3D
# hôte : entrées des pairs distants
var _bots := {}  # id -> BotInput
var _seen := {}  # id -> compteurs d'appuis déjà appliqués
var _ack := {}  # id -> dernier numéro d'entrée appliqué
var _pending := {}  # id -> dernier paquet d'entrée reçu (Dictionary)
# entrées locales
var _counts := {}
var _seq := 0
var _local_bot := BotInput.new()
var _local_seen := {}
var _sent_at := {}  # numéro -> instant d'envoi (s), mesure du retard d'entrée
# noms d'animations : table de l'hôte, apprise par le client
var _anim_ids := {}
var _anim_names := {}
# client : instantanés reçus [{t, heroes: {id: {...}}}] et retards simulés
var _snaps: Array = []
var _render_t := -1.0
var _inbox: Array = []  # [instant de livraison, octets]
var _outbox: Array = []
# mesures
var _m := {"snap_bytes": [], "input_bytes": [], "up": [], "down": [], "pk_up": [], "pk_down": [], "rtt": [],
	"input_lag": [], "fps": [], "phys_ms": [], "proc_ms": [], "mem_mb": [], "encode_us": [], "decode_us": [], "objects": []}
var _sec_acc := 0.0
var _seen_dist := {}  # id -> distance parcourue vue sur cet écran
var _seen_last := {}
var _seen_anims := {}  # id -> {nom: 1}
var _seen_actions := {}  # id -> nombre de lancements d'attaque / sort vus
var _hits := 0
var _cam: Camera3D
var _hud: Label
var _status := ""
var _my_id := 1
var _done := false
var _max_heroes := 0
var _class_seen := {}  # id -> classe (gardée après un départ, pour le bilan)


func _ready() -> void:
	process_physics_priority = -100  # entrées posées avant que les héros ne bougent
	_headless = DisplayServer.get_name() == "headless"
	for arg in OS.get_cmdline_user_args():
		if arg == "--net-host":
			is_host = true
		elif arg.begins_with("--net-join="):
			_join_ip = arg.trim_prefix("--net-join=")
		elif arg.begins_with("--net-port="):
			_port = int(arg.trim_prefix("--net-port="))
		elif arg.begins_with("--net-class="):
			_class = arg.trim_prefix("--net-class=")
		elif arg == "--net-pilot":
			_pilot = true
		elif arg.begins_with("--net-secs="):
			_secs = float(arg.trim_prefix("--net-secs="))
		elif arg.begins_with("--net-lag="):
			_lag = float(arg.trim_prefix("--net-lag=")) / 1000.0
		elif arg.begins_with("--net-loss="):
			_loss = clampf(float(arg.trim_prefix("--net-loss=")) / 100.0, 0.0, 0.9)
		elif arg.begins_with("--net-snap="):
			_snap_hz = clampi(int(arg.trim_prefix("--net-snap=")), 5, 60)
		elif arg == "--net-compress":
			_compress = true
		elif arg.begins_with("--net-version="):
			_version = arg.trim_prefix("--net-version=")
		elif arg.begins_with("--net-shot="):
			_shot = arg.trim_prefix("--net-shot=")
	if not is_host and _join_ip == "":
		is_host = true
	if _class == "" or not GameData.classes.has(_class):
		_class = "warrior" if is_host else CLIENT_CLASSES[int(OS.get_process_id()) % CLIENT_CLASSES.size()]
	_rng.seed = OS.get_process_id()
	for a in PULSES:
		_counts[a] = 0
	_setup_game_state()
	_build_arena()
	get_window().title = "Eden Slash — essai réseau (%s, %s)" % ["hôte" if is_host else "client", _class]
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	_peer = ENetMultiplayerPeer.new()
	var err: int
	if is_host:
		err = _peer.create_server(_port, MAX_CLIENTS)
	else:
		err = _peer.create_client(_join_ip, _port)
	if err != OK:
		print("[net] échec : impossible d'ouvrir ENet (%s, port %d, erreur %d)" % ["hôte" if is_host else "client", _port, err])
		get_tree().quit(1)
		return
	if _compress:
		_peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = _peer
	if is_host:
		_connected = true
		_spawn_hero(1, _class)
		_status = "hôte : en attente d'amis sur le port %d" % _port
	else:
		_status = "connexion à %s:%d…" % [_join_ip, _port]
	print("[net] %s prêt (classe %s, port %d, version %s)" % ["hôte" if is_host else "client", _class, _port, Version.NUMBER])


## Comme l'arène d'IA : profil vierge, rien d'écrit sur le disque, pas d'arrêt sur image.
func _setup_game_state() -> void:
	Training.active = true
	Training.hero_god = false
	Training.enemies_immortal = false
	Vfx.silent = _headless
	var ui: Dictionary = Settings.data.get("interface", {})
	ui["hit_stop"] = false
	ui["damage_numbers"] = "off" if _headless else "all"
	Settings.data["interface"] = ui
	Profile.reset_all()
	Profile.selected_class = _class
	Run.start(_class)
	Run.skills = _kit(_class)
	Profile.equipped = {}


func _kit(cid: String) -> Array:
	var out: Array = []
	var all: Array = GameData.class_data(cid).get("skills", [])
	for i in mini(4, all.size()):
		out.append({"id": int(all[i].id), "rank": 1})
	return out


func _build_arena() -> void:
	var ground := StaticBody3D.new()
	ground.collision_layer = GameData.PHYS_WORLD
	var gs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ARENA * 3.0, 1.0, ARENA * 3.0)
	gs.shape = box
	gs.position.y = -0.5
	ground.add_child(gs)
	add_child(ground)
	if _headless:
		return
	var gm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(ARENA * 2.6, ARENA * 2.6)
	gm.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.62, 0.45)
	gm.material_override = mat
	add_child(gm)
	for i in 12:  # piquets de repère : on voit le mouvement même caméra fixe
		var a := TAU * i / 12.0
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.18
		cm.bottom_radius = 0.24
		cm.height = 1.6
		post.mesh = cm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color.from_hsv(i / 12.0, 0.55, 0.95)
		post.material_override = pmat
		post.position = Vector3(sin(a), 0.0, cos(a)) * ARENA + Vector3.UP * 0.8
		add_child(post)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.75, 0.95)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	add_child(env)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.position = Vector3(0, 14, 12)
	_cam.look_at(Vector3.ZERO)
	var layer := CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 18)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)
	add_child(layer)


# --- héros ---------------------------------------------------------------------------
func _spawn_point(pid: int) -> Vector3:
	var i := heroes.size()
	var a := TAU * i / 8.0 + 0.3
	return Vector3(sin(a), 0.0, cos(a)) * 5.0 + Vector3.UP * 0.1 if pid != 1 else Vector3(0, 0.1, 0)


## Chez l'hôte : un vrai héros. Le sien lit Run (comme le joueur du jeu) ; celui d'un ami est un « héros ennemi »
## (`foe`, son propre jeu de sorts, aucune lecture de Run ni de Profile) piloté par un BotInput. Tous en chacun pour soi.
func _spawn_hero(pid: int, cid: String) -> void:
	var h := Player.new()
	h.level = 10
	if pid != 1:
		h.foe = true
		h.class_id = cid
		h.kit_skills = _kit(cid)
	var bot := BotInput.new() if pid != 1 else _local_bot
	h.bot = bot
	h.name = "Hero_%d" % pid
	add_child(h)
	h.global_position = _spawn_point(pid)
	h.set_ffa(heroes.size())  # chacun pour soi : tout le monde peut toucher tout le monde
	h.damaged.connect(_on_hero_damaged.bind(h))
	h.died.connect(_on_hero_died.bind(pid))
	heroes[pid] = h
	_classes[pid] = cid
	_class_seen[pid] = cid
	_max_heroes = maxi(_max_heroes, heroes.size())
	_bots[pid] = bot
	_seen[pid] = {}
	_ack[pid] = 0
	_add_label(pid, h)


## Chez le client : marionnette = héros sans aucune logique (ni physique ni entrées), modèle et animations du jeu.
func _spawn_puppet(pid: int, cid: String) -> void:
	if heroes.has(pid):
		return
	var h := Player.new()
	h.foe = true
	h.class_id = cid
	h.level = 10
	h.kit_skills = _kit(cid)
	h.name = "Hero_%d" % pid
	add_child(h)
	h.set_physics_process(false)
	h.collision_layer = 0
	h.collision_mask = 0
	h.global_position = Vector3(0, -50, 0)
	heroes[pid] = h
	_classes[pid] = cid
	_class_seen[pid] = cid
	_max_heroes = maxi(_max_heroes, heroes.size())
	_add_label(pid, h)


func _add_label(pid: int, h: Player) -> void:
	if _headless:
		return
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3.UP * 2.6
	l.font_size = 48
	l.outline_size = 12
	l.no_depth_test = true
	h.add_child(l)
	_labels[pid] = l


func _on_hero_damaged(_amount: float, _source: Combatant, h: Player) -> void:
	_hits += 1
	if h.hp < h.max_hp * 0.35:
		h.call_deferred("heal", h.max_hp)  # essai : personne ne meurt, on veut voir les coups


func _on_hero_died(_who: Combatant, _killer: Combatant, pid: int) -> void:
	get_tree().create_timer(2.0).timeout.connect(_respawn.bind(pid))


func _respawn(pid: int) -> void:
	if heroes.has(pid):
		heroes[pid].respawn(_spawn_point(pid))


func _remove_hero(pid: int) -> void:
	if heroes.has(pid):
		heroes[pid].queue_free()
	for d in [heroes, _classes, _labels, _bots, _seen, _ack, _pending]:
		d.erase(pid)


# --- connexion -------------------------------------------------------------------------
func _on_connected() -> void:
	_connected = true
	_my_id = multiplayer.get_unique_id()
	_status = "connecté à %s:%d" % [_join_ip, _port]
	print("[net] client connecté (id %d)" % _my_id)
	_rpc_hello.rpc_id(1, _version, _class)


func _on_failed() -> void:
	print("[net] échec : connexion impossible à %s:%d" % [_join_ip, _port])
	get_tree().quit(1)


func _on_server_gone() -> void:
	if not _done:
		print("[net] l'hôte a fermé la partie")
	_finish()


func _on_peer_connected(pid: int) -> void:
	if is_host:
		print("[net] pair %d connecté" % pid)


func _on_peer_disconnected(pid: int) -> void:
	if is_host:
		print("[net] pair %d parti" % pid)
		_remove_hero(pid)
		_rpc_despawn.rpc(pid)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hello(ver: String, cid: String) -> void:
	if not is_host:
		return
	var pid := multiplayer.get_remote_sender_id()
	if ver != Version.NUMBER:  # amis avec une autre version : refus net (sinon désynchronisation garantie)
		_rpc_refused.rpc_id(pid, "version %s attendue (tu as %s)" % [Version.NUMBER, ver])
		_peer.get_peer(pid).peer_disconnect_later()
		return
	if not GameData.classes.has(cid):
		cid = "warrior"
	for other in heroes:  # le nouveau venu reçoit l'état complet
		_rpc_spawn.rpc_id(pid, other, String(_classes[other]))
	for n in _anim_ids:
		_rpc_anim_name.rpc_id(pid, int(_anim_ids[n]), String(n))
	_spawn_hero(pid, cid)
	_rpc_spawn.rpc(pid, cid)
	_status = "hôte : %d héros" % heroes.size()


@rpc("authority", "call_remote", "reliable")
func _rpc_refused(msg: String) -> void:
	print("[net] refusé par l'hôte : " + msg)
	get_tree().quit(2)


@rpc("authority", "call_remote", "reliable")
func _rpc_spawn(pid: int, cid: String) -> void:
	_spawn_puppet(pid, cid)


@rpc("authority", "call_remote", "reliable")
func _rpc_despawn(pid: int) -> void:
	_remove_hero(pid)


@rpc("authority", "call_remote", "reliable")
func _rpc_anim_name(idx: int, n: String) -> void:
	_anim_names[idx] = n


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _rpc_snap(data: PackedByteArray) -> void:
	if _loss > 0.0 and _rng.randf() < _loss:
		return
	_inbox.append([_t + _lag * 0.5, data])


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _rpc_input(data: PackedByteArray) -> void:
	if not is_host:
		return
	var pid := multiplayer.get_remote_sender_id()
	if not heroes.has(pid):
		return
	var inp := _decode_input(data)
	if int(inp.seq) > int(_ack.get(pid, 0)):
		_pending[pid] = inp


# --- boucle ----------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_t += delta
	_tick += 1
	if not _connected:
		if _t > 20.0:
			print("[net] échec : pas de réponse de l'hôte en 20 s")
			get_tree().quit(1)
		return
	_sample_counts()
	if is_host:
		_host_step()
	else:
		_client_step(delta)
	_measure(delta)
	if _shot != "" and _t >= 10.0 and not _headless:
		get_viewport().get_texture().get_image().save_png(_shot)
		print("[net] capture : " + _shot)
		_shot = ""
	if _secs > 0.0 and _t >= _secs + (1.5 if is_host else 0.0):
		_finish()


## Appuis comptés à chaque image de physique : un paquet perdu ne perd pas l'appui (compteurs, pas des booléens).
func _sample_counts() -> void:
	if _pilot:
		var k := _tick
		if k % 180 == 90:
			_counts["skill_%d" % (1 + (k / 180) % 4)] += 1
		if k % 270 == 200:
			_counts["dodge"] += 1
		if k % 600 == 400:
			_counts["jump"] += 1
		return
	if _headless:
		return
	for a in PULSES:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			_counts[a] += 1


## Entrées locales : déplacement (repère du monde, caméra fixe vers -Z), point visé, attaque maintenue.
func _local_input() -> Dictionary:
	var me: Node3D = heroes.get(_my_id)
	var my_pos := me.global_position if me else Vector3.ZERO
	var target := _nearest_other(my_pos)
	var move := Vector3.ZERO
	var aim := Vector3.INF
	var attack := false
	if _pilot:
		if target != Vector3.INF:
			var to := target - my_pos
			to.y = 0.0
			var side := Vector3(-to.z, 0.0, to.x).normalized() * (1.0 if _my_id % 2 == 0 else -1.0)
			move = (to.normalized() if to.length() > 3.0 else side * 0.8).normalized()
			aim = target
			attack = to.length() < 4.0 and int(_t * 2.0) % 3 != 0
		else:
			move = Vector3(sin(_t * 0.8), 0.0, cos(_t * 0.8))
		if my_pos.length() > ARENA - 2.0:
			move = -my_pos.normalized()
	elif not _headless:
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		move = Vector3(v.x, 0.0, v.y)
		attack = Input.is_action_pressed("attack")
		aim = _mouse_ground()
	return {"move": move, "aim": aim, "attack": attack, "counts": _counts.duplicate()}


func _nearest_other(from: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for pid in heroes:
		if pid == _my_id:
			continue
		var p: Vector3 = heroes[pid].global_position
		if p.y < -10.0:
			continue
		var d := from.distance_to(p)
		if d < bd:
			bd = d
			best = p
	return best


func _mouse_ground() -> Vector3:
	if _cam == null:
		return Vector3.INF
	var mp := get_viewport().get_mouse_position()
	var o := _cam.project_ray_origin(mp)
	var dir := _cam.project_ray_normal(mp)
	if absf(dir.y) < 0.001:
		return Vector3.INF
	var t := -o.y / dir.y
	return o + dir * t if t > 0.0 else Vector3.INF


## Hôte : pose les entrées de chacun dans son BotInput, laisse les vrais héros jouer, envoie un instantané.
func _host_step() -> void:
	_apply_input(1, _local_input(), _local_bot)
	_ack[1] = _tick
	for pid in _pending:
		_apply_input(pid, _pending[pid], _bots[pid])
		_ack[pid] = int(_pending[pid].seq)
	_pending.clear()
	if _tick % maxi(1, 60 / _snap_hz) == 0 and heroes.size() > 1:
		var t0 := Time.get_ticks_usec()
		var data := _encode_snap()
		_m.encode_us.append(Time.get_ticks_usec() - t0)
		_m.snap_bytes.append(data.size())
		_rpc_snap.rpc(data)
	_watch_heroes()


func _apply_input(pid: int, inp: Dictionary, bot: BotInput) -> void:
	bot.pulse.clear()
	bot.move = inp.move
	bot.aim = inp.aim
	bot.hold["attack"] = bool(inp.attack)
	var seen: Dictionary = _seen.get(pid, _local_seen)
	for a in PULSES:
		var c := int(inp.counts.get(a, 0))
		if c != int(seen.get(a, c)):
			bot.pulse[a] = true
		seen[a] = c
	_seen[pid] = seen


## Client : envoie ses entrées, livre les paquets retardés, place les marionnettes.
func _client_step(delta: float) -> void:
	if _tick % (60 / INPUT_HZ) == 0:
		_seq += 1
		var inp := _local_input()
		inp["seq"] = _seq
		var data := _encode_input(inp)
		_m.input_bytes.append(data.size())
		_sent_at[_seq] = _t
		if not (_loss > 0.0 and _rng.randf() < _loss):
			_outbox.append([_t + _lag * 0.5, data])
	while not _outbox.is_empty() and float(_outbox[0][0]) <= _t:
		_rpc_input.rpc_id(1, _outbox.pop_front()[1])
	while not _inbox.is_empty() and float(_inbox[0][0]) <= _t:
		var t0 := Time.get_ticks_usec()
		_receive_snap(_inbox.pop_front()[1])
		_m.decode_us.append(Time.get_ticks_usec() - t0)
	_place_puppets(delta)
	_watch_heroes()


# --- format des paquets (octets) ---------------------------------------------------------------
## Entrée : numéro u32, déplacement 2 × f16, visée 3 × f32 (ou absente), attaque, 7 compteurs d'appui u8 : 26 à 32 octets.
func _encode_input(inp: Dictionary) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u32(int(inp.seq))
	b.put_half(inp.move.x)
	b.put_half(inp.move.z)
	var has_aim: bool = inp.aim != Vector3.INF
	b.put_u8((1 if inp.attack else 0) | (2 if has_aim else 0))
	if has_aim:
		b.put_float(inp.aim.x)
		b.put_float(inp.aim.y)
		b.put_float(inp.aim.z)
	for a in PULSES:
		b.put_u8(int(inp.counts.get(a, 0)) & 255)
	return b.data_array


func _decode_input(data: PackedByteArray) -> Dictionary:
	var b := StreamPeerBuffer.new()
	b.data_array = data
	var out := {"seq": b.get_u32()}
	out["move"] = Vector3(b.get_half(), 0.0, b.get_half()).limit_length(1.0)
	var fl := b.get_u8()
	out["attack"] = fl & 1 != 0
	out["aim"] = Vector3(b.get_float(), b.get_float(), b.get_float()) if fl & 2 != 0 else Vector3.INF
	var counts := {}
	for a in PULSES:
		counts[a] = b.get_u8()
	out["counts"] = counts
	return out


## Instantané : instant (f32) puis par héros : id, position 3 × f32, cap f16, animation (indice u16, position f16,
## vitesse f16), PV et PV max (f32), dernier numéro d'entrée appliqué (u32) : 34 octets par héros.
func _encode_snap() -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_float(_t)
	b.put_u8(heroes.size())
	for pid in heroes:
		var h: Player = heroes[pid]
		var an := String(h.anim.current_animation) if h.anim else ""
		if not _anim_ids.has(an):
			_anim_ids[an] = _anim_ids.size()
			_rpc_anim_name.rpc(int(_anim_ids[an]), an)
		b.put_u32(pid)
		b.put_float(h.global_position.x)
		b.put_float(h.global_position.y)
		b.put_float(h.global_position.z)
		b.put_half(wrapf(h.rotation.y, -PI, PI))
		b.put_u16(int(_anim_ids[an]))
		b.put_half(h.anim.current_animation_position if h.anim and an != "" else 0.0)
		b.put_half(h.anim.get_playing_speed() if h.anim and an != "" else 1.0)
		b.put_float(h.hp)
		b.put_float(h.max_hp)
		b.put_u32(int(_ack.get(pid, 0)))
	return b.data_array


func _receive_snap(data: PackedByteArray) -> void:
	var b := StreamPeerBuffer.new()
	b.data_array = data
	var snap := {"t": b.get_float(), "heroes": {}}
	var n := b.get_u8()
	for i in n:
		var pid := b.get_u32()
		var e := {"pos": Vector3(b.get_float(), b.get_float(), b.get_float()), "yaw": b.get_half(), "anim": b.get_u16(),
			"apos": b.get_half(), "aspeed": b.get_half(), "hp": b.get_float(), "max_hp": b.get_float(), "ack": b.get_u32()}
		snap.heroes[pid] = e
		if pid == _my_id:
			var ack := int(e.ack)
			if _sent_at.has(ack):
				_m.input_lag.append((_t - float(_sent_at[ack])) * 1000.0)
				for k in _sent_at.keys():
					if int(k) <= ack:
						_sent_at.erase(k)
	if not _snaps.is_empty() and float(snap.t) <= float(_snaps[-1].t):
		return
	_snaps.append(snap)
	while _snaps.size() > 40:
		_snaps.pop_front()


## Interpolation : on affiche l'état d'il y a INTERP secondes (horloge de l'hôte), entre les deux instantanés qui
## l'encadrent ; l'horloge d'affichage avance avec le temps local et se recale doucement sur le dernier instantané.
func _place_puppets(delta: float) -> void:
	if _snaps.is_empty():
		return
	var latest := float(_snaps[-1].t)
	if _render_t < 0.0:
		_render_t = latest - INTERP
	_render_t += delta
	_render_t += (latest - INTERP - _render_t) * 0.05
	var a: Dictionary = _snaps[0]
	var c: Dictionary = _snaps[-1]
	for i in range(_snaps.size() - 1):
		if float(_snaps[i].t) <= _render_t and float(_snaps[i + 1].t) >= _render_t:
			a = _snaps[i]
			c = _snaps[i + 1]
			break
	var span := maxf(0.0001, float(c.t) - float(a.t))
	var k := clampf((_render_t - float(a.t)) / span, 0.0, 1.0)
	for pid in c.heroes:
		if not heroes.has(pid):
			continue
		var h: Player = heroes[pid]
		var ec: Dictionary = c.heroes[pid]
		var ea: Dictionary = a.heroes.get(pid, ec)
		h.global_position = (ea.pos as Vector3).lerp(ec.pos, k)
		h.rotation.y = lerp_angle(float(ea.yaw), float(ec.yaw), k)
		h.hp = lerpf(float(ea.hp), float(ec.hp), k)
		h.max_hp = float(ec.max_hp)
		var e: Dictionary = ec if k > 0.5 else ea
		var an := String(_anim_names.get(int(e.anim), ""))
		if an != "" and h.anim and h.anim.has_animation(an):
			var restarted := an == h._current_anim and float(e.apos) + 0.08 < h.anim.current_animation_position - 0.25
			if an != h._current_anim or restarted or not h.anim.is_playing():
				h.play(an, 0.08, float(e.aspeed), true)
				h.anim.seek(float(e.apos), true)
			elif absf(h.anim.current_animation_position - float(e.apos)) > 0.2:
				h.anim.seek(float(e.apos), true)


# --- mesures ----------------------------------------------------------------------------------
func _watch_heroes() -> void:
	for pid in heroes:
		var h: Player = heroes[pid]
		var p := h.global_position
		if p.y < -10.0:
			continue
		if _seen_last.has(pid):
			_seen_dist[pid] = float(_seen_dist.get(pid, 0.0)) + p.distance_to(_seen_last[pid])
		_seen_last[pid] = p
		var an := String(h._current_anim)
		var bag: Dictionary = _seen_anims.get(pid, {})
		if an != "" and not bag.has(an):
			bag[an] = 1
		if an != String(bag.get("_last", "")):
			if an.contains("attack") or an.contains("skill") or an.contains("cast") or an.contains("atk"):
				_seen_actions[pid] = int(_seen_actions.get(pid, 0)) + 1
			bag["_last"] = an
		_seen_anims[pid] = bag


func _measure(delta: float) -> void:
	_sec_acc += delta
	if _cam and heroes.has(_my_id):
		var me: Node3D = heroes[_my_id]
		if me.global_position.y > -10.0:
			_cam.global_position = _cam.global_position.lerp(me.global_position + Vector3(0, 11, 9), 0.15)
			_cam.look_at(_cam.global_position - Vector3(0, 11, 9))
	for pid in _labels:
		var h: Player = heroes[pid]
		_labels[pid].text = "%s%s\n%d / %d" % ["(moi) " if pid == _my_id else "", h.display_name, roundi(h.hp), roundi(h.max_hp)]
	if _sec_acc < 1.0:
		return
	_sec_acc -= 1.0
	var host: ENetConnection = _peer.host
	if heroes.size() < 2:
		if host:  # pas encore d'ami : on vide les compteurs sans les noter (mesures à 2 héros ou plus)
			for st in [ENetConnection.HOST_TOTAL_SENT_DATA, ENetConnection.HOST_TOTAL_RECEIVED_DATA,
					ENetConnection.HOST_TOTAL_SENT_PACKETS, ENetConnection.HOST_TOTAL_RECEIVED_PACKETS]:
				host.pop_statistic(st)
		host = null
	if host:
		_m.up.append(host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / 1024.0)
		_m.down.append(host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / 1024.0)
		_m.pk_up.append(host.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS))
		_m.pk_down.append(host.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS))
	if not is_host and _peer.get_peer(1):
		_m.rtt.append(_peer.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	elif is_host:
		for pid in heroes:
			if pid != 1 and _peer.get_peer(pid):
				_m.rtt.append(_peer.get_peer(pid).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
	_m.fps.append(Performance.get_monitor(Performance.TIME_FPS))
	_m.phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_m.proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_m.mem_mb.append(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	_m.objects.append(Performance.get_monitor(Performance.OBJECT_COUNT))
	if _hud:
		_hud.text = "%s · %s\nhéros %d · ping %s ms · envoi %.1f Ko/s · réception %.1f Ko/s · %d i/s%s" % [
			_status, "pilote auto" if _pilot else "clavier", heroes.size(), str(_m.rtt[-1]) if not _m.rtt.is_empty() else "—",
			_m.up[-1] if not _m.up.is_empty() else 0.0, _m.down[-1] if not _m.down.is_empty() else 0.0, roundi(_m.fps[-1]),
			"" if _lag <= 0.0 and _loss <= 0.0 else " · simulé : +%d ms, %d %% perdus" % [roundi(_lag * 1000.0), roundi(_loss * 100.0)]]


static func _stats(a: Array) -> Dictionary:
	if a.is_empty():
		return {}
	var s := a.duplicate()
	s.sort()
	var tot := 0.0
	for v in s:
		tot += float(v)
	return {"med": snappedf(float(s[s.size() / 2]), 0.01), "p95": snappedf(float(s[mini(s.size() - 1, int(s.size() * 0.95))]), 0.01),
		"max": snappedf(float(s[-1]), 0.01), "moy": snappedf(tot / s.size(), 0.01), "n": s.size()}


func _finish() -> void:
	if _done:
		return
	_done = true
	var skip := 2  # la 1re seconde mesure le démarrage (chargement des modèles)
	var cut := func(a: Array) -> Array: return a.slice(skip) if a.size() > skip + 2 else a
	var seen := {}
	for pid in _seen_dist:
		seen[str(pid)] = {"classe": _class_seen.get(pid, "?"), "m": snappedf(float(_seen_dist[pid]), 0.1),
			"anims": (_seen_anims.get(pid, {}) as Dictionary).keys().filter(func(x): return x != "_last").size(),
			"actions": int(_seen_actions.get(pid, 0)), "moi": pid == _my_id}
	var out := {"role": "hôte" if is_host else "client", "id": _my_id, "classe": _class, "secs": snappedf(_t, 0.1),
		"heros": _max_heroes, "snap_hz": _snap_hz, "input_hz": INPUT_HZ, "lag_ms": roundi(_lag * 1000.0), "perte": _loss,
		"compression": _compress, "envoi_ko_s": _stats(cut.call(_m.up)), "reception_ko_s": _stats(cut.call(_m.down)),
		"paquets_envoyes_s": _stats(cut.call(_m.pk_up)), "paquets_recus_s": _stats(cut.call(_m.pk_down)),
		"instantane_octets": _stats(_m.snap_bytes), "entree_octets": _stats(_m.input_bytes), "rtt_ms": _stats(cut.call(_m.rtt)),
		"retard_entree_ms": _stats(_m.input_lag), "affichage_retard_ms": roundi(INTERP * 1000.0), "fps": _stats(cut.call(_m.fps)),
		"physique_ms": _stats(cut.call(_m.phys_ms)), "image_ms": _stats(cut.call(_m.proc_ms)), "memoire_mo": _stats(cut.call(_m.mem_mb)),
		"objets": _stats(cut.call(_m.objects)), "encodage_us": _stats(_m.encode_us), "decodage_us": _stats(_m.decode_us),
		"coups_simules": _hits, "vus": seen}
	print("[net] " + JSON.stringify(out))
	_secs = 0.0
	set_physics_process(false)
	if _peer and _peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		_peer.close()
	get_tree().quit(0)
