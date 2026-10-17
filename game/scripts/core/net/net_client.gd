class_name NetClient
extends NetSession
## Client d'une partie entre amis (lot NET-A) : il ne simule rien. Il envoie ses entrées 30 fois par seconde et affiche
## des FANTÔMES ([NetGhost] : modèle, animations, PV) placés par interpolation entre les instantanés de l'hôte, 100 ms
## dans le passé (NetProtocol.INTERP) ; les événements visuels (NetEvents) sont rejoués au même instant que les fantômes.
## Pas encore de prédiction de son propre héros (lot NET-C) : le retard ressenti est mesuré (R_NET_A.md).
## L'arène fournit [member spawn_fn] (case, classe, nom, moi) -> NetGhost, [member despawn_fn] (case) et les entrées du
## joueur [member intent_fn] () -> Dictionary {move, aim, attack, counts}.

signal welcomed(slot: int)

var spawn_fn: Callable
var despawn_fn: Callable
var intent_fn: Callable
var cid := "warrior"
var hero_name := ""
var address := ""
var port := NetProtocol.PORT

var my_slot := -1
var connected := false
var ghosts := {}  # case -> NetGhost
var names := {}  # indice -> texte (table de l'hôte)
var host_t := 0.0  # dernière horloge de l'hôte reçue
var render_t := -1.0  # horloge d'affichage (celle de l'hôte, INTERP en arrière)
var events_played := 0
var snaps_got := 0
var _snaps: Array = []
var _events: Array = []  # [instant de l'hôte, données]
var _seq := 0
var _sent_at := {}  # numéro -> instant d'envoi (mesure du retard d'entrée)
var _connect_until := 0.0
var _bye_reason := -1


## Lance la connexion. Renvoie "" ou un message d'erreur pour le joueur.
func join(p_address: String, p_port: int) -> String:
	address = p_address
	port = p_port
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		peer = null
		return "Adresse invalide : %s." % address
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	_connect_until = clock + 10.0
	return ""


func peer_ids() -> Array:
	return [1] if connected else []


func _current_rtt() -> int:
	return rtt_to(1)


func _on_peer_connected(pid: int) -> void:
	if pid != 1:
		return
	connected = true
	var pp := peer.get_peer(1)
	if pp:
		pp.set_timeout(32, NetProtocol.TIMEOUT_MS, NetProtocol.TIMEOUT_MS * 2)
	_put(1, NetProtocol.hello(version, cid, hero_name), RELIABLE, NetProtocol.CH_RELIABLE)


func _on_peer_disconnected(pid: int) -> void:
	if pid != 1 or done:
		return
	connected = false
	if closing:
		return
	if _bye_reason == NetProtocol.CLOSED:
		finish(NetProtocol.CLOSED, "L'hôte a fermé la partie.")
	elif my_slot < 0 and _bye_reason == -2:
		pass  # refus : déjà annoncé
	else:
		finish(NetProtocol.LOST, "Connexion perdue avec l'hôte.")


func _on_packet(_from: int, data: PackedByteArray) -> void:
	var b := NetProtocol.reader(data)
	var t0 := Time.get_ticks_usec()
	match b.get_u8():
		NetProtocol.WELCOME:
			my_slot = b.get_u8()
			host_t = b.get_float()
			welcomed.emit(my_slot)
		NetProtocol.REFUSE:
			_bye_reason = -2
			finish(-1, "Refusé par l'hôte : " + NetProtocol.get_str(b))
		NetProtocol.SPAWN:
			var slot := b.get_u8()
			var c := NetProtocol.get_str(b)
			var n := NetProtocol.get_str(b)
			if not ghosts.has(slot) and spawn_fn.is_valid():
				ghosts[slot] = spawn_fn.call(slot, c, n, slot == my_slot)
				if slot != my_slot:
					message.emit("%s est là." % n)
		NetProtocol.DESPAWN:
			var slot := b.get_u8()
			var reason := b.get_u8()
			if ghosts.has(slot):
				var g: Node = ghosts[slot]
				var who := String(g.get("display_name")) if is_instance_valid(g) else "Un joueur"
				ghosts.erase(slot)
				if despawn_fn.is_valid():
					despawn_fn.call(slot)
				message.emit(("%s a quitté la partie." if reason == NetProtocol.LEFT else "Connexion perdue avec %s.") % who)
		NetProtocol.NAME:
			var id := b.get_u16()
			names[id] = NetProtocol.get_str(b)
		NetProtocol.SNAP:
			_on_snap(NetProtocol.decode_snap(b))
			metrics.decode_us.append(Time.get_ticks_usec() - t0)
		NetProtocol.EVENTS:
			var t := b.get_float()
			_events.append([t, data])
		NetProtocol.BYE:
			_bye_reason = b.get_u8()
			if _bye_reason == NetProtocol.CLOSED:
				finish(NetProtocol.CLOSED, "L'hôte a fermé la partie.")


func _on_snap(snap: Dictionary) -> void:
	snaps_got += 1
	var mine: Dictionary = snap.heroes.get(my_slot, {})
	if not mine.is_empty():
		var ack := int(mine.ack)
		if _sent_at.has(ack):
			metrics.input_lag.append((clock - float(_sent_at[ack])) * 1000.0)
			for k in _sent_at.keys():
				if int(k) <= ack:
					_sent_at.erase(k)
	if not _snaps.is_empty() and float(snap.t) <= float(_snaps[-1].t):
		return  # en retard sur le précédent (non fiable ordonné : rare)
	host_t = float(snap.t)
	_snaps.append(snap)
	while _snaps.size() > 40:
		_snaps.pop_front()


# --- boucle -----------------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	clock += delta
	tick += 1
	poll()
	if closing_step() or done:
		return
	if not connected and clock > _connect_until:
		finish(-1, "Pas de réponse de %s:%d. Vérifie l'adresse, que l'hôte a lancé la partie et que Tailscale est allumé des deux côtés." % [address, port])
		return
	if my_slot >= 0 and tick % (60 / NetProtocol.INPUT_HZ) == 0 and intent_fn.is_valid():
		var inp: Dictionary = intent_fn.call()
		_seq += 1
		inp["seq"] = _seq
		var data := NetProtocol.encode_input(inp)
		metrics.input_bytes.append(data.size())
		_sent_at[_seq] = clock
		send(1, data, UNRELIABLE_ORDERED, NetProtocol.CH_INPUT)
	measure(delta, ghosts.size() > 1)


## Affichage (chaque image rendue) : horloge d'affichage, fantômes, événements dus.
func _process(delta: float) -> void:
	if done or _snaps.is_empty():
		return
	var latest := float(_snaps[-1].t)
	if render_t < 0.0:
		render_t = latest - NetProtocol.INTERP
	render_t += delta
	render_t += (latest - NetProtocol.INTERP - render_t) * 0.05  # recalage doux sur le dernier instantané
	var a: Dictionary = _snaps[0]
	var c: Dictionary = _snaps[-1]
	for i in range(_snaps.size() - 1):
		if float(_snaps[i].t) <= render_t and float(_snaps[i + 1].t) >= render_t:
			a = _snaps[i]
			c = _snaps[i + 1]
			break
	var span := maxf(0.0001, float(c.t) - float(a.t))
	var k := clampf((render_t - float(a.t)) / span, 0.0, 1.0)
	for slot in c.heroes:
		var g: NetGhost = ghosts.get(slot)
		if g == null or not is_instance_valid(g):
			continue
		var ec: Dictionary = c.heroes[slot]
		g.show_state(a.heroes.get(slot, ec), ec, k, names)
	var root: Node = get_parent()
	while not _events.is_empty() and float(_events[0][0]) <= render_t:
		var data: PackedByteArray = _events.pop_front()[1]
		var b := NetProtocol.reader(data)
		b.get_u8()
		b.get_float()
		var n := b.get_u8()
		for i in n:
			if NetEvents.replay(b, root, _ghost_of, _name_of, my_slot) == 0:
				break
			events_played += 1


func _ghost_of(slot: int) -> Node3D:
	var g: Node3D = ghosts.get(slot)
	return g if g != null and is_instance_valid(g) else null


func _name_of(id: int) -> String:
	return String(names.get(id, ""))


## Résumé des mesures (ligne « [net] »).
func report() -> Dictionary:
	return {"role": "client", "adresse": "%s:%d" % [address, port], "case": my_slot, "heros": ghosts.size(),
		"instantanes_recus": snaps_got, "evenements_joues": events_played, "lag_ms": roundi(lag * 1000.0), "perte": loss,
		"envoi_ko_s": stats(metrics.up), "reception_ko_s": stats(metrics.down), "paquets_envoyes_s": stats(metrics.pk_up),
		"paquets_recus_s": stats(metrics.pk_down), "rtt_ms": stats(metrics.rtt), "entree_octets": stats(metrics.input_bytes),
		"retard_entree_ms": stats(metrics.input_lag), "affichage_retard_ms": roundi(NetProtocol.INTERP * 1000.0),
		"decodage_us": stats(metrics.decode_us), "fps": stats(metrics.fps), "image_ms": stats(metrics.frame_ms), "physique_ms": stats(metrics.phys_ms)}
