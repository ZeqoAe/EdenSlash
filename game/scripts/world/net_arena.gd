class_name NetArena
extends Node3D
## Arène d'essai du Mode amis (lot NET-A, conception/benchmark/R_NET_A.md) : « Jouer ensemble » à l'écran titre (réglage
## Paramètres > Caméra & interface > Mode amis) ou lancement direct `EdenSlash.exe --host` / `--join=<adresse>` (voir
## NetLaunch : jamais après « -- »). Un joueur héberge ([NetHost] : il simule tous les héros, vrais [Player] pilotés par un
## BotInput), les autres rejoignent ([NetClient] : fantômes interpolés). Chacun pour soi, niveau 10, 4 premiers sorts de la
## classe, sans équipement ; un héros tombé revient après 3 s. Rien n'est écrit dans la sauvegarde (Training.active pendant
## la scène, comme l'entraînement) et aucun réglage n'est modifié hors du Mode amis.

const ARENA := 14.0
const HERO_LEVEL := 10
const RESPAWN := 3.0
const TITLE := "res://scenes/title.tscn"
const ACTION_WORDS := ["attack", "skill", "cast", "atk"]
## Cartes réseau virtuelles (machines virtuelles, Bluetooth…) : leurs adresses ne servent pas à un ami.
const VIRTUAL_NICS := ["vmware", "virtualbox", "vethernet", "hyper-v", "bluetooth", "loopback", "wsl", "docker"]

var session: NetSession
var host: NetHost
var client: NetClient
var intent := NetIntent.new()
var cid := "warrior"
var hero_name := ""
var heroes := {}  # case -> Player (chez l'hôte) ou NetGhost (chez le client)
var my_slot := -1
var secs := 0.0  # --net-secs : mesure pendant N s à deux ou plus, puis quitte
var report_path := ""  # --net-report
var auto := false  # lancé pour une mesure ou un test (--net-secs, --net-report) : quitte le jeu à la fin de la session
var bind_ip := "*"  # --net-bind=127.0.0.1 : n'écouter que cette machine (tests)
var shot := ""  # --net-shot=<fichier.png> : capture de la fenêtre après 6 s à deux (vérification visuelle)
var cam: Camera3D
var panel: NetPanel
var overlay: NetOverlay
var ended_text := ""
var ended_reason := -99

var _headless := false
var _world: Node3D
var _plates := {}  # case -> Label3D (héros de l'hôte)
var _prev_training := false
var _prev_silent := false
var _t := 0.0
var _with_friends := 0.0  # temps passé à deux ou plus
var _alone_t := 0.0  # hôte : temps seul depuis le départ du dernier ami
var _intent := {"move": Vector3.ZERO, "aim": Vector3.INF, "attack": false, "counts": {}}
var _prev_move := 0.0
var _still_since := 0.0
var _last_disp := Vector3.INF
var _onset_t := -1.0
var _onset_pos := Vector3.ZERO
var _felt: Array = []  # retard ressenti mesuré (ms) : du départ voulu au premier mouvement affiché de son héros
var _seen := {}  # case -> {classe, m, anims, actions, last, anim}
var _ui_t := 0.0
var _finished := false


func _ready() -> void:
	process_physics_priority = -200  # avant la session (-100) et les héros : les entrées sont lues en premier
	_headless = DisplayServer.get_name() == "headless"
	_prev_training = Training.active
	Training.active = true  # comme l'entraînement : aucune sauvegarde pendant l'arène
	_prev_silent = Vfx.silent
	if _headless:
		Vfx.silent = true
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	_build_arena()
	_build_ui()
	var def_cls := String(Settings.get_v("net", "class"))
	if not GameData.classes.has(def_cls):
		def_cls = Profile.selected_class if GameData.classes.has(Profile.selected_class) else "warrior"
	cid = NetLaunch.value("--net-class", def_cls)
	if not GameData.classes.has(cid):
		cid = "warrior"
	hero_name = NetLaunch.value("--net-name", Profile.hero_name)
	intent.pilot = NetLaunch.flag("--net-pilot")
	secs = float(NetLaunch.value("--net-secs", "0"))
	report_path = NetLaunch.value("--net-report")
	bind_ip = NetLaunch.value("--net-bind", "*")
	shot = NetLaunch.value("--net-shot")
	panel.cid = cid
	if NetLaunch.requested():
		NetLaunch.used = true
		auto = secs > 0.0 or report_path != ""  # mesure ou test : on quitte le jeu à la fin de la session
		if NetLaunch.role() == "host":
			start_host(int(NetLaunch.value("--net-port", str(Settings.get_v("net", "port")))))
		else:
			var tgt := NetLaunch.join_target()
			start_join(String(tgt[0]), int(tgt[1]))
	else:
		panel.show_menu()
	if not _headless:
		get_window().title = "Eden Slash — Jouer ensemble"


func _exit_tree() -> void:
	if not _headless:
		get_window().title = String(ProjectSettings.get_setting("application/config/name", "Eden Slash"))
	Training.active = _prev_training
	Vfx.silent = _prev_silent
	NetEvents.on = false
	NetEvents.sink = Callable()


# --- décor ----------------------------------------------------------------------------------
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
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.position = Vector3(0, 13, 11)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	if _headless:
		return
	var gm := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = ARENA + 1.5
	disc.bottom_radius = ARENA + 1.5
	disc.height = 0.2
	disc.radial_segments = 64
	gm.mesh = disc
	gm.position.y = -0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("9fd67a")  # pomme claire
	mat.roughness = 1.0
	gm.material_override = mat
	add_child(gm)
	var inner := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 4.6
	tm.outer_radius = 4.85
	inner.mesh = tm
	inner.scale = Vector3(1.0, 0.05, 1.0)
	var im := StandardMaterial3D.new()
	im.albedo_color = Color("fff8ec")
	inner.material_override = im
	add_child(inner)
	var tones := [Color("ffc928"), Color("ff4d6d"), Color("35c4f0"), Color("8fd62e"), Color("b43beb"), Color("ff8a1f")]
	for i in 12:  # piquets de repère : on voit le mouvement même quand la caméra suit
		var a := TAU * i / 12.0
		var post := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 0.26
		cm.height = 1.8
		post.mesh = cm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = tones[i % tones.size()]
		post.material_override = pmat
		post.position = Vector3(sin(a), 0.0, cos(a)) * ARENA + Vector3.UP * 0.9
		add_child(post)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("bfe6ff")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.74, 0.8)
	add_child(env)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	overlay = NetOverlay.new()
	layer.add_child(overlay)
	overlay.visible = false
	panel = NetPanel.new()
	layer.add_child(panel)
	panel.host_pressed.connect(start_host)
	panel.join_pressed.connect(_on_join_pressed)
	panel.cancel_pressed.connect(_leave)
	panel.back_pressed.connect(_back_to_title)
	panel.resume_pressed.connect(func(): panel.hide_panel())
	panel.quit_pressed.connect(_leave)


# --- héberger / rejoindre --------------------------------------------------------------------
func _remember_class() -> void:
	cid = panel.cid if panel.cid != "" else cid
	if not auto and String(Settings.get_v("net", "class")) != cid:
		Settings.set_v("net", "class", cid)


func start_host(port: int) -> void:
	_remember_class()
	host = NetHost.new()
	host.name = "NetHost"
	host.spawn_fn = _spawn_hero
	host.despawn_fn = _despawn
	host.local_intent = func() -> Dictionary: return _intent
	host.bind_ip = bind_ip
	host.snap_hz = clampi(int(NetLaunch.value("--net-snap", str(NetProtocol.SNAP_HZ))), 5, 60)
	_attach(host)
	var err := host.start(port, cid, _display_name())
	if err != "":
		_drop_session()
		_fail(err)
		return
	my_slot = 0
	panel.hide_panel()
	overlay.visible = true
	overlay.toast("Partie ouverte. Donne ton adresse à tes amis : Échap.")
	print("[net] hôte prêt (classe %s, port %d, version %s, profil %s)" % [cid, port, Version.NUMBER, Profile.save_path])


func _on_join_pressed(address: String) -> void:
	if not auto:
		Settings.set_v("net", "join", address)
	var tgt := NetLaunch.parse_address(address, int(Settings.get_v("net", "port")))
	start_join(String(tgt[0]), int(tgt[1]))


func start_join(address: String, port: int) -> void:
	_remember_class()
	client = NetClient.new()
	client.name = "NetClient"
	client.cid = cid
	client.hero_name = _display_name()
	client.version = NetLaunch.value("--net-version", Version.NUMBER)
	client.lag = float(NetLaunch.value("--net-lag", "0")) / 1000.0
	client.loss = clampf(float(NetLaunch.value("--net-loss", "0")) / 100.0, 0.0, 0.9)
	client.spawn_fn = _spawn_ghost
	client.despawn_fn = _despawn
	client.intent_fn = func() -> Dictionary: return _intent
	client.welcomed.connect(_on_welcomed)
	_attach(client)
	var err := client.join(address, port)
	if err != "":
		_drop_session()
		_fail(err)
		return
	panel.show_connecting("Connexion à %s:%d…" % [address, port])
	print("[net] client : connexion à %s:%d (classe %s, profil %s)" % [address, port, cid, Profile.save_path])


func _attach(s: NetSession) -> void:
	session = s
	s.message.connect(_on_message)
	s.ended.connect(_on_ended)
	add_child(s)


func _display_name() -> String:
	return hero_name if hero_name != "" else String(GameData.class_data(cid).get("name_fr", "Héros"))


func _fail(text: String) -> void:
	print("[net] échec : " + text)
	if auto:
		_finish_auto(1, {"echec": text})
		return
	panel.show_menu(text, true)


func _on_welcomed(slot: int) -> void:
	my_slot = slot
	panel.hide_panel()
	overlay.visible = true
	overlay.toast("Connecté. Échap : menu.")
	print("[net] client accueilli (case %d)" % slot)


func _on_message(text: String) -> void:
	print("[net] " + text)
	if overlay:
		overlay.toast(text)


func _on_ended(reason: int, text: String) -> void:
	ended_reason = reason
	ended_text = text
	print("[net] fin de session : " + text)
	if auto:
		var code := 0 if reason in [NetProtocol.LEFT, NetProtocol.CLOSED] else (2 if text.begins_with("Refusé") else 1)
		_finish_auto(code, {"fin": text})
		return
	_drop_session()
	overlay.visible = false
	panel.show_menu(text if reason != NetProtocol.LEFT else "Tu as quitté la partie.", reason == NetProtocol.LOST or reason == -1)


## Ferme la session et efface les héros (retour au menu de l'arène).
func _drop_session() -> void:
	for s in heroes.keys():
		_despawn(s)
	if session and is_instance_valid(session):
		session.queue_free()
	session = null
	host = null
	client = null
	my_slot = -1
	_seen.clear()


func _leave() -> void:
	if host:
		host.close_game()
	elif client:
		client.leave(NetProtocol.LEFT, "Tu as quitté la partie.")
	else:
		panel.show_menu()


func _back_to_title() -> void:
	NetLaunch.used = true
	_drop_session()
	get_tree().change_scene_to_file(TITLE)


# --- héros -----------------------------------------------------------------------------------
static func kit(class_id: String) -> Array:
	var out: Array = []
	var all: Array = GameData.class_data(class_id).get("skills", [])
	for i in mini(4, all.size()):
		out.append({"id": int(all[i].id), "rank": 1})
	return out


func spawn_point(slot: int) -> Vector3:
	var a := TAU * slot / 8.0 + 0.4
	return Vector3(sin(a), 0.0, cos(a)) * 4.0 + Vector3.UP * 0.1


## Hôte : un vrai héros « à sa fiche » (aucune lecture de Run, de Profile ni du clavier), piloté par un BotInput.
func _spawn_hero(slot: int, class_id: String, who: String) -> Player:
	var h := Player.new()
	h.foe = true
	h.class_id = class_id
	h.level = HERO_LEVEL
	h.kit_skills = kit(class_id)
	h.bot = BotInput.new()
	h.name = "Hero_%d" % slot
	_world.add_child(h)
	h.display_name = who
	h.global_position = spawn_point(slot)
	h.set_ffa(slot)  # chacun pour soi
	h.died.connect(_on_hero_died.bind(slot))
	for c in h.get_children():
		if c is Decal:
			(c as Decal).modulate = Color(1.0, 0.82, 0.35, 0.6) if slot == 0 else Color(0.35, 0.8, 1.0, 0.6)
	heroes[slot] = h
	_watch_init(slot, class_id)
	if not _headless:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = true
		l.pixel_size = 0.0009
		l.font_size = 26
		l.outline_size = 10
		l.outline_modulate = UiTheme.INK
		l.modulate = UiTheme.GOLD if slot == 0 else UiTheme.TEXT
		l.position = Vector3.UP * 2.75
		h.add_child(l)
		_plates[slot] = l
	return h


## Client : un fantôme (modèle et animations, aucune logique).
func _spawn_ghost(slot: int, class_id: String, who: String, mine: bool) -> NetGhost:
	var g := NetGhost.new()
	g.class_id = class_id
	g.level = HERO_LEVEL
	g.kit_skills = kit(class_id)
	g.slot = slot
	g.mine = mine
	g.hero_label = who
	g.name = "Ghost_%d" % slot
	_world.add_child(g)
	heroes[slot] = g
	_watch_init(slot, class_id)
	if mine:
		my_slot = slot
	return g


func _despawn(slot: int) -> void:
	var n: Node = heroes.get(slot)
	heroes.erase(slot)
	_plates.erase(slot)
	if n and is_instance_valid(n):
		n.queue_free()


func _on_hero_died(_who: Combatant, _killer: Combatant, slot: int) -> void:
	get_tree().create_timer(RESPAWN).timeout.connect(_respawn.bind(slot))


func _respawn(slot: int) -> void:
	var h: Player = heroes.get(slot)
	if h and is_instance_valid(h) and h.is_dead:
		h.respawn(spawn_point(slot))


## Mon héros tel qu'il est affiché (vrai héros chez l'hôte, fantôme chez le client).
func my_hero() -> Node3D:
	var h: Node3D = heroes.get(my_slot)
	return h if h != null and is_instance_valid(h) else null


func _nearest_other(from: Vector3) -> Vector3:
	var best := Vector3.INF
	var bd := INF
	for s in heroes:
		if s == my_slot:
			continue
		var h: Node3D = heroes[s]
		if not is_instance_valid(h) or h.global_position.y < -10.0 or bool(h.get("is_dead")):
			continue
		var d := from.distance_to(h.global_position)
		if d < bd:
			bd = d
			best = h.global_position
	return best


# --- boucle ----------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_t += delta
	intent.idle = panel.visible
	intent.sample(delta)
	var me := my_hero()
	var pos := me.global_position if me else Vector3.ZERO
	_intent = intent.read(pos, _nearest_other(pos), cam, ARENA)
	_track_felt(me)
	if session and heroes.size() >= 2:
		_with_friends += delta
		_alone_t = 0.0
	elif host and _with_friends > 0.0:
		_alone_t += delta
		if auto and secs > 0.0 and _alone_t >= 2.0 and not _finished:
			_finish_measure()  # mesure : tous les amis sont partis, l'hôte rend son rapport
	if shot != "" and session == null and not NetLaunch.used and _t >= 2.5 and not _headless:
		get_viewport().get_texture().get_image().save_png(shot)  # sans --host / --join : capture du menu, puis on quitte
		print("[net] capture : " + shot)
		get_tree().quit()
	if shot != "" and _with_friends >= 6.0 and not _headless:
		get_viewport().get_texture().get_image().save_png(shot)
		print("[net] capture : " + shot)
		shot = ""
	if secs > 0.0 and _with_friends >= secs and not _finished:
		_finish_measure()


## Retard ressenti : du moment où l'on veut repartir (entrée qui passe de l'arrêt au mouvement) au premier déplacement
## affiché de son propre héros (> 15 cm), seulement si le héros affiché était immobile depuis 0,25 s.
func _track_felt(me: Node3D) -> void:
	if me == null:
		return
	var disp := me.global_position
	if _last_disp != Vector3.INF and disp.distance_to(_last_disp) > 0.01:
		_still_since = _t
	_last_disp = disp
	var mv := (_intent.move as Vector3).length()
	if mv >= 0.5 and _prev_move < 0.1 and _t - _still_since >= 0.25 and _onset_t < 0.0:
		_onset_t = _t
		_onset_pos = disp
	_prev_move = mv
	if _onset_t >= 0.0:
		if disp.distance_to(_onset_pos) > 0.15:
			if _with_friends > 1.0:
				_felt.append(roundi((_t - _onset_t) * 1000.0))
			_onset_t = -1.0
		elif _t - _onset_t > 1.5:
			_onset_t = -1.0


func _process(delta: float) -> void:
	var me := my_hero()
	if me and me.global_position.y > -10.0:
		var want := me.global_position + Vector3(0, 13, 11)
		cam.global_position = cam.global_position.lerp(want, clampf(delta * 8.0, 0.0, 1.0))
		cam.look_at(cam.global_position - Vector3(0, 13, 11))
	for s in _plates:
		var h: Player = heroes.get(s)
		if h and is_instance_valid(h):
			(_plates[s] as Label3D).text = "%s\n%d / %d" % [h.display_name, roundi(h.hp), roundi(h.max_hp)]
	_watch()
	_ui_t -= delta
	if _ui_t <= 0.0 and overlay and overlay.visible and session:
		_ui_t = 0.25
		_update_overlay()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if session == null:
		if panel.state == "menu":
			_back_to_title()
		return
	if panel.visible and panel.state == "game":
		panel.hide_panel()
	elif not panel.visible:
		panel.show_game("Partie entre amis", _info_lines())


# --- affichage ----------------------------------------------------------------------------------
static func local_addresses() -> Array:
	var ts: Array = []
	var lan: Array = []
	for itf in IP.get_local_interfaces():
		var low := String(itf.get("friendly", itf.get("name", ""))).to_lower()
		var virtual := VIRTUAL_NICS.any(func(k): return low.contains(k))
		for a in itf.get("addresses", []):
			var s := String(a)
			if s.contains(":") or s.begins_with("127.") or s.begins_with("169.254."):
				continue
			if is_tailscale(s):
				ts.append(s + " (Tailscale)")
			elif not virtual and not lan.has(s):
				lan.append(s)
	return ts + lan


## 100.64.0.0/10 : adresses du réseau privé Tailscale.
static func is_tailscale(ip: String) -> bool:
	var p := ip.split(".")
	return p.size() == 4 and p[0] == "100" and int(p[1]) >= 64 and int(p[1]) <= 127


static func kbs(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")


func _info_lines() -> Array:
	var lines: Array = []
	if host:
		var ad := local_addresses()
		lines.append("Ton adresse : %s · port %d" % [" · ".join(ad) if not ad.is_empty() else "inconnue", host.port])
		lines.append("Tes amis : Jouer ensemble > Rejoindre, puis cette adresse.")
	elif client:
		lines.append("Connecté à %s:%d" % [client.address, client.port])
	var who: Array = []
	for s in heroes:
		var h: Node = heroes[s]
		if is_instance_valid(h):
			var ping := ""
			if host and s != 0:
				ping = " (%d ms)" % host.rtt_to(int(host.heroes[s].peer)) if host.heroes.has(s) else ""
			who.append(String(h.get("display_name")) + ping)
	lines.append("Joueurs : " + ", ".join(who))
	return lines


func _update_overlay() -> void:
	var n := heroes.size()
	var line := ""
	var detail := ""
	var ping := "—" if session.rtt_ms < 0 else "%d ms" % session.rtt_ms
	if host:
		line = "Tu héberges · %d joueur%s · ping %s · envoi %s Ko/s · réception %s Ko/s" % [n, "s" if n > 1 else "", ping,
			kbs(session.up_kbs), kbs(session.down_kbs)]
		detail = "Port %d · %d instantanés par seconde · %d images par seconde" % [host.port, host.snap_hz,
			roundi(Performance.get_monitor(Performance.TIME_FPS))]
	elif client:
		line = "Connecté · %d joueur%s · ping %s · envoi %s Ko/s · réception %s Ko/s" % [n, "s" if n > 1 else "", ping,
			kbs(session.up_kbs), kbs(session.down_kbs)]
		var il: Array = client.metrics.input_lag
		var lag_ms := roundi(float(il[-1])) if not il.is_empty() else -1
		var felt := "—" if _felt.is_empty() else "%d ms" % int(NetSession.stats(_felt.slice(-10)).med)
		detail = "Retard d'entrée %s · affichage + %d ms · retard ressenti %s · %d images par seconde" % [
			"—" if lag_ms < 0 else "%d ms" % lag_ms, roundi(NetProtocol.INTERP * 1000.0), felt,
			roundi(Performance.get_monitor(Performance.TIME_FPS))]
		if client.lag > 0.0 or client.loss > 0.0:
			detail += "\nSimulé : + %d ms, %d %% de paquets perdus" % [roundi(client.lag * 1000.0), roundi(client.loss * 100.0)]
	if NetLaunch.instance() != "":
		detail += "\nProfil de cette fenêtre : %s" % NetLaunch.instance()
	overlay.set_text(line, detail)


# --- mesures et fin automatique ----------------------------------------------------------------
func _watch_init(slot: int, class_id: String) -> void:
	if not _seen.has(slot):
		_seen[slot] = {"classe": class_id, "m": 0.0, "anims": {}, "actions": 0, "last": Vector3.INF, "anim": ""}


func _watch() -> void:
	for s in heroes:
		var h: Node3D = heroes[s]
		if not is_instance_valid(h) or h.global_position.y < -10.0 or not _seen.has(s):
			continue
		var w: Dictionary = _seen[s]
		if w.last != Vector3.INF:
			w.m = float(w.m) + h.global_position.distance_to(w.last)
		w.last = h.global_position
		var an := String(h.get("_current_anim"))
		if an != "" and an != String(w.anim):
			(w.anims as Dictionary)[an] = 1
			for word in ACTION_WORDS:
				if an.contains(word):
					w.actions = int(w.actions) + 1
					break
			w.anim = an


func _finish_measure() -> void:
	_finished = true
	var out := _report()
	print("[net] " + JSON.stringify(out))
	_write_report(out)
	if host:
		host.close_game()
	elif client:
		client.leave(NetProtocol.LEFT, "Mesure terminée.")


func _report() -> Dictionary:
	var out: Dictionary = session.call("report") if session else {}
	var seen := {}
	for s in _seen:
		var w: Dictionary = _seen[s]
		seen[str(s)] = {"classe": w.classe, "m": snappedf(float(w.m), 0.1), "anims": (w.anims as Dictionary).size(),
			"actions": int(w.actions), "moi": s == my_slot}
	out["vus"] = seen
	out["ressenti_ms"] = NetSession.stats(_felt)
	out["classe"] = cid
	out["version"] = Version.NUMBER
	out["secs"] = snappedf(_with_friends, 0.1)
	out["mode_test"] = Profile.save_path.get_file().begins_with("profile_test")
	out["profil"] = Profile.save_path
	out["reglages"] = Settings.save_path
	out["instance"] = NetLaunch.instance()
	if client:
		out["evenements_joues"] = client.events_played
	return out


func _write_report(out: Dictionary) -> void:
	if report_path == "":
		return
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))
		f.close()


## Fin d'un lancement en ligne de commande : rapport (si demandé et pas encore écrit), puis on quitte.
func _finish_auto(code: int, extra: Dictionary) -> void:
	if not _finished:
		_finished = true
		var out := _report() if session else {}
		out.merge(extra, true)
		print("[net] " + JSON.stringify(out))
		_write_report(out)
	elif report_path != "" and FileAccess.file_exists(report_path):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		if d is Dictionary:
			(d as Dictionary).merge(extra, true)
			_write_report(d)
	get_tree().quit(code)
