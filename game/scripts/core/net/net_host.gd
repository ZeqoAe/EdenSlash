class_name NetHost
extends NetSession
## Hôte d'une partie entre amis (lot NET-A) : il simule TOUT avec les vrais héros du jeu. Le héros d'un ami est un vrai
## [Player] piloté par un [BotInput] (le point d'entrée de l'arène d'IA) que l'hôte remplit avec les entrées reçues ; la
## logique de combat n'est pas réécrite. 30 fois par seconde, il envoie à chacun un instantané (34 octets par héros) et les
## événements visuels de l'image (NetEvents). Il refuse un pair d'une autre version du jeu ou d'un autre protocole.
## L'arène (ou, plus tard, un mode) fournit la création des héros : [member spawn_fn] (case, classe, nom) -> Player avec
## son `bot` posé, [member despawn_fn] (case), et les entrées du joueur de l'hôte : [member local_intent] () -> Dictionary.

signal joined(slot: int, cid: String, hero_name: String)
signal left(slot: int, reason: int, hero_name: String)

var spawn_fn: Callable
var despawn_fn: Callable
var local_intent: Callable
var snap_hz := NetProtocol.SNAP_HZ
var port := NetProtocol.PORT
var bind_ip := "*"  # « 127.0.0.1 » : cette machine seulement (tests : pas de fenêtre du pare-feu)

## case -> {peer, cls, name, node: Player, bot: BotInput, seen: {}, ack, pending, bye}
var heroes := {}
var by_peer := {}  # pair ENet -> case
var _names := {}  # texte -> indice (animations, effets, sons)
var _ev := NetProtocol.buf()
var _ev_n := 0
var _node_slot := {}  # id d'instance du héros -> case
var hits := 0  # coups reçus par les héros (mesure)


func is_host() -> bool:
	return true


## Ouvre le port et crée le héros du joueur de l'hôte (case 0). Renvoie "" ou un message d'erreur pour le joueur.
func start(p_port: int, cid: String, hero_name: String) -> String:
	port = p_port
	peer = ENetMultiplayerPeer.new()
	if bind_ip != "*":
		peer.set_bind_ip(bind_ip)
	var err := peer.create_server(port, NetProtocol.MAX_PEERS)
	if err != OK:
		peer = null
		return "Impossible d'héberger sur le port %d (déjà pris par un autre programme ?)." % port
	peer.peer_connected.connect(_on_peer_connected)
	peer.peer_disconnected.connect(_on_peer_disconnected)
	NetEvents.on = true
	NetEvents.sink = _on_event
	_add_hero(0, 1, cid, hero_name)
	return ""


func _exit_tree() -> void:
	NetEvents.on = false
	NetEvents.sink = Callable()
	super._exit_tree()


func peer_ids() -> Array:
	return by_peer.keys()


func _current_rtt() -> int:
	var best := -1
	for pid in by_peer:
		best = maxi(best, rtt_to(pid))
	return best


func _add_hero(slot: int, pid: int, cid: String, hero_name: String) -> void:
	var node: Player = spawn_fn.call(slot, cid, hero_name)
	var e := {"peer": pid, "cls": cid, "name": hero_name, "node": node, "bot": node.bot, "seen": {}, "ack": 0, "pending": {}, "bye": false}
	heroes[slot] = e
	_node_slot[node.get_instance_id()] = slot
	if pid != 1:
		by_peer[pid] = slot
	node.damaged.connect(func(_a, _s): hits += 1)


func _remove_hero(slot: int) -> void:
	var e: Dictionary = heroes.get(slot, {})
	if e.is_empty():
		return
	heroes.erase(slot)
	by_peer.erase(int(e.peer))
	if is_instance_valid(e.node):
		_node_slot.erase((e.node as Node).get_instance_id())
	if despawn_fn.is_valid():
		despawn_fn.call(slot)


func _free_slot() -> int:
	for s in range(1, NetProtocol.MAX_PEERS + 1):
		if not heroes.has(s):
			return s
	return -1


# --- connexion ---------------------------------------------------------------------------------
func _on_peer_connected(pid: int) -> void:
	var pp := peer.get_peer(pid)
	if pp:
		pp.set_timeout(32, NetProtocol.TIMEOUT_MS, NetProtocol.TIMEOUT_MS * 2)


func _on_peer_disconnected(pid: int) -> void:
	if not by_peer.has(pid):
		return
	var slot := int(by_peer[pid])
	var e: Dictionary = heroes[slot]
	var reason := NetProtocol.LEFT if bool(e.bye) else NetProtocol.LOST
	var who := String(e.name)
	_remove_hero(slot)
	if closing or done:
		return
	_broadcast(NetProtocol.despawn(slot, reason))
	left.emit(slot, reason, who)
	message.emit(("%s a quitté la partie." if reason == NetProtocol.LEFT else "Connexion perdue avec %s.") % who)


func _on_packet(from: int, data: PackedByteArray) -> void:
	var b := NetProtocol.reader(data)
	match b.get_u8():
		NetProtocol.HELLO:
			_on_hello(from, NetProtocol.read_hello(b))
		NetProtocol.INPUT:
			if by_peer.has(from):
				var inp := NetProtocol.decode_input(b)
				var e: Dictionary = heroes[int(by_peer[from])]
				if int(inp.seq) > int(e.ack) and (e.pending.is_empty() or int(inp.seq) > int(e.pending.seq)):
					e.pending = inp
		NetProtocol.BYE:
			if by_peer.has(from):
				heroes[int(by_peer[from])].bye = true


func _on_hello(pid: int, h: Dictionary) -> void:
	if by_peer.has(pid):
		return
	var why := ""
	if int(h.protocol) != NetProtocol.PROTOCOL or String(h.version) != version:
		why = "version %s attendue (tu as %s). Mettez-vous tous à jour." % [version, String(h.version)]
	var slot := _free_slot()
	if why == "" and slot < 0:
		why = "la partie est pleine (%d joueurs)." % (NetProtocol.MAX_PEERS + 1)
	if why == "" and closing:
		why = "la partie se termine."
	if why != "":
		_put(pid, NetProtocol.refuse(why), RELIABLE, NetProtocol.CH_RELIABLE)
		var pp := peer.get_peer(pid)
		if pp:
			pp.peer_disconnect_later()
		message.emit("Un joueur a été refusé : " + why)
		return
	var cid := String(h["class"])
	if not GameData.classes.has(cid):
		cid = "warrior"
	var hero_name := String(h.name).strip_edges().substr(0, 20)
	if hero_name == "":
		hero_name = String(GameData.class_data(cid).get("name_fr", "Héros"))
	_put(pid, NetProtocol.welcome(slot, clock), RELIABLE, NetProtocol.CH_RELIABLE)
	for n in _names:
		_put(pid, NetProtocol.name_entry(int(_names[n]), String(n)), RELIABLE, NetProtocol.CH_RELIABLE)
	for s in heroes:
		_put(pid, NetProtocol.spawn(s, String(heroes[s].cls), String(heroes[s].name)), RELIABLE, NetProtocol.CH_RELIABLE)
	_add_hero(slot, pid, cid, hero_name)
	_broadcast(NetProtocol.spawn(slot, cid, hero_name))
	joined.emit(slot, cid, hero_name)
	message.emit("%s a rejoint la partie." % hero_name)


func _broadcast(data: PackedByteArray) -> void:
	for pid in by_peer:
		_put(pid, data, RELIABLE, NetProtocol.CH_RELIABLE)


## Indice de [param text] dans la table des noms (envoyé une fois à tous, en fiable).
func name_id(text: String) -> int:
	if not _names.has(text):
		_names[text] = _names.size()
		_broadcast(NetProtocol.name_entry(int(_names[text]), text))
	return int(_names[text])


## Case du héros qui porte [param n] (lui-même ou un de ses enfants) ; NetEvents.NONE sinon.
func slot_of(n: Variant) -> int:
	var node := n as Node
	var depth := 0
	while node != null and depth < 4:
		var id := node.get_instance_id()
		if _node_slot.has(id):
			return int(_node_slot[id])
		node = node.get_parent()
		depth += 1
	return NetEvents.NONE


func _on_event(kind: int, parent: Node, args: Array) -> void:
	if by_peer.is_empty():
		return  # personne pour le voir
	if _ev_n >= 250:
		return
	if NetEvents.encode(_ev, kind, parent, args, slot_of, name_id):
		_ev_n += 1


# --- boucle (avant les héros) -------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	clock += delta
	tick += 1
	poll()
	if closing_step() or done:
		return
	# entrées : le joueur de l'hôte chaque image, les amis au dernier paquet reçu ; un appui ne vaut qu'une image
	if heroes.has(0) and local_intent.is_valid():
		_apply(heroes[0], local_intent.call())
	for s in heroes:
		var e: Dictionary = heroes[s]
		if s == 0:
			continue
		(e.bot as BotInput).pulse.clear()
		if not e.pending.is_empty():
			_apply(e, e.pending)
			e.ack = int(e.pending.seq)
			e.pending = {}
	if tick % maxi(1, 60 / snap_hz) == 0 and not by_peer.is_empty():
		_send_snapshot()
	measure(delta, not by_peer.is_empty())


func _apply(e: Dictionary, inp: Dictionary) -> void:
	var bot: BotInput = e.bot
	bot.pulse.clear()
	bot.move = inp.move
	bot.aim = inp.aim
	bot.hold["attack"] = bool(inp.attack)
	var seen: Dictionary = e.seen
	var counts: Dictionary = inp.counts
	for a in NetProtocol.PULSES:
		var c := int(counts.get(a, 0))
		if seen.has(a) and c != int(seen[a]):
			bot.pulse[a] = true
		seen[a] = c


func _send_snapshot() -> void:
	var t0 := Time.get_ticks_usec()
	var rows: Array = []
	for s in heroes:
		var e: Dictionary = heroes[s]
		var h: Player = e.node
		if not is_instance_valid(h):
			continue
		var an := String(h.anim.current_animation) if h.anim else ""
		var playing := h.anim != null and an != ""
		rows.append({"slot": s, "flags": (1 if h.is_dead else 0) | (2 if h.hand_off else 0), "pos": h.global_position,
			"yaw": h.rotation.y, "anim": name_id(an), "apos": h.anim.current_animation_position if playing else 0.0,
			"aspeed": h.anim.get_playing_speed() if playing else 1.0, "hp": h.hp, "max_hp": h.max_hp, "ack": int(e.ack)})
	var data := NetProtocol.encode_snap(clock, rows)
	metrics.encode_us.append(Time.get_ticks_usec() - t0)
	metrics.snap_bytes.append(data.size())
	for pid in by_peer:
		send(pid, data, UNRELIABLE_ORDERED, NetProtocol.CH_SNAP)
	if _ev_n > 0:
		var b := NetProtocol.buf()
		b.put_u8(NetProtocol.EVENTS)
		b.put_float(clock)
		b.put_u8(_ev_n)
		b.put_data(_ev.data_array)
		metrics.event_bytes.append(b.data_array.size())
		metrics.events.append(_ev_n)
		for pid in by_peer:
			send(pid, b.data_array, UNRELIABLE_ORDERED, NetProtocol.CH_EVENTS)
	_ev = NetProtocol.buf()
	_ev_n = 0


## L'hôte ferme la partie (départ propre : chaque ami reçoit « L'hôte a fermé la partie »).
func close_game() -> void:
	NetEvents.on = false
	NetEvents.sink = Callable()
	leave(NetProtocol.CLOSED, "Partie fermée.")


## Résumé des mesures (ligne « [net] »).
func report() -> Dictionary:
	var friends := {}
	for s in heroes:
		friends[str(s)] = {"classe": heroes[s].cls, "nom": heroes[s].name, "rtt": rtt_to(int(heroes[s].peer)) if s != 0 else 0}
	return {"role": "hôte", "port": port, "heros": heroes.size(), "coups": hits, "noms": _names.size(),
		"envoi_ko_s": stats(metrics.up), "reception_ko_s": stats(metrics.down), "paquets_envoyes_s": stats(metrics.pk_up),
		"paquets_recus_s": stats(metrics.pk_down), "rtt_ms": stats(metrics.rtt), "instantane_octets": stats(metrics.snap_bytes),
		"evenements_par_paquet": stats(metrics.events), "evenements_octets": stats(metrics.event_bytes), "encodage_us": stats(metrics.encode_us),
		"fps": stats(metrics.fps), "image_ms": stats(metrics.frame_ms), "physique_ms": stats(metrics.phys_ms), "joueurs": friends}
