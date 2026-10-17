class_name NetSession
extends Node
## Socle commun de [NetHost] et [NetClient] (lot NET-A) : liaison ENet en paquets bruts (ENetMultiplayerPeer utilisé seul,
## sans SceneMultiplayer ni @rpc : l'API multijoueur de l'arbre n'est jamais touchée), envoi par canal et mode, retard et
## pertes simulés (essais), mesures (débit, paquets, aller-retour), départ propre (paquet BYE puis fermeture).
## Le nœud tourne avant les héros (process_physics_priority = -100) : les entrées sont posées avant qu'ils ne bougent.

signal message(text: String)  ## annonce courte (« Léa a rejoint la partie »)
signal ended(reason: int, text: String)  ## session finie : NetProtocol.LEFT / LOST / CLOSED, ou -1 (refus, échec)

const RELIABLE := MultiplayerPeer.TRANSFER_MODE_RELIABLE
const UNRELIABLE_ORDERED := MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED

var peer: ENetMultiplayerPeer
var clock := 0.0  # horloge de la session (s), avancée par les images de physique
var tick := 0
var version := Version.NUMBER  # (--net-version : essai du refus d'une autre version)
var lag := 0.0  # aller-retour ajouté (s) : moitié à l'envoi, moitié à la réception (essais, côté client)
var loss := 0.0  # part des paquets non fiables perdus, dans les deux sens (essais, côté client)
var rng := RandomNumberGenerator.new()
var done := false

# mesures (une valeur par seconde)
var up_kbs := 0.0
var down_kbs := 0.0
var rtt_ms := -1
var metrics := {"up": [], "down": [], "pk_up": [], "pk_down": [], "rtt": [], "snap_bytes": [], "input_bytes": [],
	"event_bytes": [], "events": [], "encode_us": [], "decode_us": [], "input_lag": [], "fps": [], "frame_ms": [], "phys_ms": []}
var _sec := 0.0
var _measuring := false  # on ne compte qu'à partir de deux héros

var _outbox: Array = []  # [instant, cible, données, mode, canal]
var _inbox: Array = []  # [instant, pair, données]


func _init() -> void:
	process_physics_priority = -100
	rng.randomize()


func is_host() -> bool:
	return false


## Envoie [param data] à [param to] (0 : à tous). Retard et pertes simulés s'il y en a.
func send(to: int, data: PackedByteArray, mode: int, ch: int) -> void:
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	if loss > 0.0 and mode != RELIABLE and rng.randf() < loss:
		return
	if lag > 0.0:
		_outbox.append([clock + lag * 0.5, to, data, mode, ch])
		return
	_put(to, data, mode, ch)


func _put(to: int, data: PackedByteArray, mode: int, ch: int) -> void:
	peer.set_target_peer(to)
	peer.transfer_mode = mode
	peer.transfer_channel = ch
	peer.put_packet(data)


## Relève les paquets reçus (et livre ceux que le retard simulé retenait).
func poll() -> void:
	if peer == null:
		return
	while not _outbox.is_empty() and float(_outbox[0][0]) <= clock:
		var o: Array = _outbox.pop_front()
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_put(o[1], o[2], o[3], o[4])
	peer.poll()
	while peer != null and peer.get_available_packet_count() > 0:
		var from := peer.get_packet_peer()
		var mode := peer.get_packet_mode()
		var data := peer.get_packet()
		if data.is_empty():
			continue
		if loss > 0.0 and mode != RELIABLE and rng.randf() < loss:
			continue
		if lag > 0.0:
			_inbox.append([clock + lag * 0.5, from, data])
		else:
			_on_packet(from, data)
	while not _inbox.is_empty() and float(_inbox[0][0]) <= clock:
		var i: Array = _inbox.pop_front()
		_on_packet(i[1], i[2])


## À redéfinir : un paquet de [param from].
func _on_packet(_from: int, _data: PackedByteArray) -> void:
	pass


## Aller-retour ENet vers [param pid] (ms, -1 si inconnu).
func rtt_to(pid: int) -> int:
	if peer == null:
		return -1
	var pp := peer.get_peer(pid)
	return int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if pp else -1


## Mesures de la seconde écoulée (appelée à chaque image de physique).
func measure(delta: float, active: bool) -> void:
	_sec += delta
	if _sec < 1.0:
		return
	_sec -= 1.0
	if peer == null or peer.host == null:
		return
	var h := peer.host
	up_kbs = h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_DATA) / 1024.0
	down_kbs = h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_DATA) / 1024.0
	var pu := h.pop_statistic(ENetConnection.HOST_TOTAL_SENT_PACKETS)
	var pd := h.pop_statistic(ENetConnection.HOST_TOTAL_RECEIVED_PACKETS)
	rtt_ms = _current_rtt()
	if not active:
		_measuring = false
		return
	if not _measuring:
		_measuring = true  # 1re seconde à deux : démarrage, pas comptée
		return
	metrics.up.append(up_kbs)
	metrics.down.append(down_kbs)
	metrics.pk_up.append(pu)
	metrics.pk_down.append(pd)
	if rtt_ms >= 0:
		metrics.rtt.append(rtt_ms)
	metrics.fps.append(Performance.get_monitor(Performance.TIME_FPS))
	metrics.frame_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	metrics.phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)


func _current_rtt() -> int:
	return -1


## Pairs connectés (ids ENet).
func peer_ids() -> Array:
	return []


## Départ propre : BYE fiable à tous, déconnexion « quand tout est parti » (ENet), fermeture au plus tard 1,5 s après ;
## puis [signal ended]. [param reason] : NetProtocol.LEFT (je quitte) ou CLOSED (l'hôte ferme).
func leave(reason: int, text: String) -> void:
	if closing or done:
		return
	closing = true
	_close_reason = reason
	_close_text = text
	_close_at = clock + 1.5
	if peer == null or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		_close_at = clock
		return
	_put(0 if is_host() else 1, NetProtocol.bye(reason), RELIABLE, NetProtocol.CH_RELIABLE)
	for pid in peer_ids():
		var pp := peer.get_peer(pid)
		if pp:
			pp.peer_disconnect_later()


var closing := false
var _close_at := 0.0
var _close_reason := 0
var _close_text := ""


## Fin d'un départ propre (à appeler à chaque image) : vrai quand la session est close.
func closing_step() -> bool:
	if not closing or done:
		return done
	var any := false
	for pid in peer_ids():
		var pp := peer.get_peer(pid) if peer else null
		if pp and pp.get_state() != ENetPacketPeer.STATE_DISCONNECTED:
			any = true
	if any and clock < _close_at:
		return false
	finish(_close_reason, _close_text)
	return true


## Session finie : liaison coupée, [signal ended] émis une fois.
func finish(reason: int, text: String) -> void:
	if done:
		return
	done = true
	shutdown()
	ended.emit(reason, text)


func _exit_tree() -> void:
	if not done:
		done = true
		shutdown(NetProtocol.bye(NetProtocol.CLOSED if is_host() else NetProtocol.LEFT))


## Coupe la liaison après avoir envoyé [param last] (paquet BYE) : il part avant la fermeture.
func shutdown(last := PackedByteArray()) -> void:
	if peer == null:
		return
	if not last.is_empty() and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_put(0 if is_host() else 1, last, RELIABLE, NetProtocol.CH_RELIABLE)
		peer.poll()
		if peer.host:
			peer.host.flush()
	peer.close()
	peer = null


## Médiane, 95e centile, moyenne, maximum d'une série.
static func stats(a: Array) -> Dictionary:
	if a.is_empty():
		return {}
	var s := a.duplicate()
	s.sort()
	var tot := 0.0
	for v in s:
		tot += float(v)
	return {"med": snappedf(float(s[s.size() / 2]), 0.01), "p95": snappedf(float(s[mini(s.size() - 1, int(s.size() * 0.95))]), 0.01),
		"max": snappedf(float(s[-1]), 0.01), "moy": snappedf(tot / s.size(), 0.01), "n": s.size()}
