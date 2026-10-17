class_name NetProtocol
extends RefCounted
## Format des paquets du Mode amis (lot NET-A ; architecture : conception/benchmark/NETWORK.md § 2.3, mesures : R_NET_A.md).
## Hôte autoritaire : le client envoie ses ENTRÉES (30 par seconde), l'hôte simule tout et renvoie des INSTANTANÉS
## (30 par seconde) et des ÉVÉNEMENTS visuels (effets, chiffres, sons : NetEvents). Paquets bruts sur ENet (pas de @rpc :
## aucun chemin de nœud à garder identique), premier octet = type. Toute modification du format augmente PROTOCOL : un pair
## d'un autre protocole OU d'une autre version du jeu (Version.NUMBER) est refusé à la connexion.

const PROTOCOL := 1
const PORT := 24680
const MAX_PEERS := 7  # 8 héros au plus
const INPUT_HZ := 30
const SNAP_HZ := 30
const INTERP := 0.1  # le client affiche l'état d'il y a 100 ms (3 instantanés d'avance)
const TIMEOUT_MS := 6000  # pair muet plus longtemps : connexion perdue
## Appuis comptés (un paquet perdu ne perd pas l'appui : on envoie des compteurs, pas des booléens).
const PULSES := ["skill_1", "skill_2", "skill_3", "skill_4", "dodge", "jump", "swap_weapon"]

# canaux ENet (0 : canal par défaut du mode, fiable)
const CH_RELIABLE := 0
const CH_INPUT := 1
const CH_SNAP := 2
const CH_EVENTS := 3

# types de paquets
const HELLO := 1  # client -> hôte (fiable) : protocole, version, classe, nom
const WELCOME := 2  # hôte -> client (fiable) : ta case, horloge de l'hôte
const REFUSE := 3  # hôte -> client (fiable) : raison
const SPAWN := 4  # hôte -> clients (fiable) : un héros arrive
const DESPAWN := 5  # hôte -> clients (fiable) : un héros part (raison)
const NAME := 6  # hôte -> clients (fiable) : table des noms (animations, effets, sons)
const INPUT := 7  # client -> hôte (non fiable ordonné)
const SNAP := 8  # hôte -> clients (non fiable ordonné)
const EVENTS := 9  # hôte -> clients (non fiable ordonné)
const BYE := 10  # dans les deux sens (fiable) : départ propre

# raisons d'un départ
const LEFT := 0  # a quitté la partie
const LOST := 1  # connexion perdue
const CLOSED := 2  # l'hôte a fermé la partie

## Octets par héros dans un instantané.
const HERO_BYTES := 34


static func buf() -> StreamPeerBuffer:
	var b := StreamPeerBuffer.new()
	b.big_endian = false
	return b


static func reader(data: PackedByteArray) -> StreamPeerBuffer:
	var b := buf()
	b.data_array = data
	return b


static func put_str(b: StreamPeerBuffer, s: String) -> void:
	var u := s.to_utf8_buffer()
	b.put_u16(mini(u.size(), 65535))
	b.put_data(u.slice(0, 65535))


static func get_str(b: StreamPeerBuffer) -> String:
	var n := b.get_u16()
	if n <= 0 or b.get_available_bytes() < n:
		return ""
	var r: Array = b.get_data(n)
	return (r[1] as PackedByteArray).get_string_from_utf8() if int(r[0]) == OK else ""


static func put_color(b: StreamPeerBuffer, c: Color) -> void:
	for v in [c.r, c.g, c.b, c.a]:
		b.put_u8(clampi(roundi(clampf(v, 0.0, 2.0) * 127.5), 0, 255))  # jusqu'à 2 (couleurs « chaudes » des effets)


static func get_color(b: StreamPeerBuffer) -> Color:
	return Color(b.get_u8() / 127.5, b.get_u8() / 127.5, b.get_u8() / 127.5, b.get_u8() / 127.5)


static func put_vec(b: StreamPeerBuffer, v: Vector3) -> void:
	b.put_float(v.x)
	b.put_float(v.y)
	b.put_float(v.z)


static func get_vec(b: StreamPeerBuffer) -> Vector3:
	return Vector3(b.get_float(), b.get_float(), b.get_float())


# --- poignée de main ---------------------------------------------------------------------
static func hello(version: String, cid: String, hero_name: String) -> PackedByteArray:
	var b := buf()
	b.put_u8(HELLO)
	b.put_u16(PROTOCOL)
	put_str(b, version)
	put_str(b, cid)
	put_str(b, hero_name)
	return b.data_array


static func read_hello(b: StreamPeerBuffer) -> Dictionary:
	return {"protocol": b.get_u16(), "version": get_str(b), "class": get_str(b), "name": get_str(b)}


static func refuse(msg: String) -> PackedByteArray:
	var b := buf()
	b.put_u8(REFUSE)
	put_str(b, msg)
	return b.data_array


static func welcome(slot: int, host_t: float) -> PackedByteArray:
	var b := buf()
	b.put_u8(WELCOME)
	b.put_u8(slot)
	b.put_float(host_t)
	return b.data_array


static func spawn(slot: int, cid: String, hero_name: String) -> PackedByteArray:
	var b := buf()
	b.put_u8(SPAWN)
	b.put_u8(slot)
	put_str(b, cid)
	put_str(b, hero_name)
	return b.data_array


static func despawn(slot: int, reason: int) -> PackedByteArray:
	var b := buf()
	b.put_u8(DESPAWN)
	b.put_u8(slot)
	b.put_u8(reason)
	return b.data_array


static func name_entry(id: int, text: String) -> PackedByteArray:
	var b := buf()
	b.put_u8(NAME)
	b.put_u16(id)
	put_str(b, text)
	return b.data_array


static func bye(reason: int) -> PackedByteArray:
	var b := buf()
	b.put_u8(BYE)
	b.put_u8(reason)
	return b.data_array


# --- entrées (client -> hôte) -------------------------------------------------------------
## Numéro u32, déplacement 2 × f16, drapeaux (attaque maintenue, visée présente), visée 3 × f32, 7 compteurs d'appui :
## 17 octets sans visée, 29 avec.
static func encode_input(inp: Dictionary) -> PackedByteArray:
	var b := buf()
	b.put_u8(INPUT)
	b.put_u32(int(inp.seq))
	var mv: Vector3 = inp.move
	b.put_half(mv.x)
	b.put_half(mv.z)
	var aim: Vector3 = inp.aim
	var has_aim := aim != Vector3.INF
	b.put_u8((1 if bool(inp.attack) else 0) | (2 if has_aim else 0))
	if has_aim:
		put_vec(b, aim)
	var counts: Dictionary = inp.counts
	for a in PULSES:
		b.put_u8(int(counts.get(a, 0)) & 255)
	return b.data_array


static func decode_input(b: StreamPeerBuffer) -> Dictionary:
	var out := {"seq": b.get_u32()}
	out["move"] = Vector3(b.get_half(), 0.0, b.get_half()).limit_length(1.0)
	var fl := b.get_u8()
	out["attack"] = fl & 1 != 0
	out["aim"] = get_vec(b) if fl & 2 != 0 else Vector3.INF
	var counts := {}
	for a in PULSES:
		counts[a] = b.get_u8()
	out["counts"] = counts
	return out


# --- instantanés (hôte -> clients) ----------------------------------------------------------
## En-tête : type, horloge de l'hôte (f32), nombre de héros ; puis par héros (HERO_BYTES = 34 octets) : case u8, drapeaux u8
## (mort, arme secondaire en main), position 3 × f32, cap f16, animation (indice u16 de la table des noms, position f16,
## vitesse f16), PV et PV max f32, dernier numéro d'entrée appliqué u32.
static func encode_snap(host_t: float, rows: Array) -> PackedByteArray:
	var b := buf()
	b.put_u8(SNAP)
	b.put_float(host_t)
	b.put_u8(rows.size())
	for r in rows:
		b.put_u8(int(r.slot))
		b.put_u8(int(r.flags))
		put_vec(b, r.pos)
		b.put_half(wrapf(float(r.yaw), -PI, PI))
		b.put_u16(int(r.anim))
		b.put_half(float(r.apos))
		b.put_half(float(r.aspeed))
		b.put_float(float(r.hp))
		b.put_float(float(r.max_hp))
		b.put_u32(int(r.ack))
	return b.data_array


static func decode_snap(b: StreamPeerBuffer) -> Dictionary:
	var snap := {"t": b.get_float(), "heroes": {}}
	var n := b.get_u8()
	for i in n:
		if b.get_available_bytes() < HERO_BYTES:
			break
		var slot := b.get_u8()
		snap.heroes[slot] = {"flags": b.get_u8(), "pos": get_vec(b), "yaw": b.get_half(), "anim": b.get_u16(), "apos": b.get_half(),
			"aspeed": b.get_half(), "hp": b.get_float(), "max_hp": b.get_float(), "ack": b.get_u32()}
	return snap
