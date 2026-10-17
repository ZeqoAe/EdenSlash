class_name NetEvents
extends RefCounted
## Bus d'événements visuels du Mode amis (lot NET-A, début de NET-C) : chez l'HÔTE, les points d'entrée des effets
## (EdenFx.play, Vfx.slash / ring / flash / spark, DamageNumber.spawn / spawn_text, Telegraph.spawn, Sfx.play_at,
## HeroBolt.fire) appellent [method emit] en première ligne quand [member on] est vrai ; l'hôte les range dans un paquet
## EVENTS par image ; le CLIENT les rejoue au même instant que ses fantômes (horloge d'affichage, 100 ms dans le passé).
## [member on] n'est vrai que chez l'hôte d'une partie entre amis : partout ailleurs, rien ne change (un test de booléen).

const FX := 1
const SLASH := 2
const RING := 3
const FLASH := 4
const SPARK := 5
const DMG := 6
const TEXT := 7
const TELE := 8
const SFX := 9
const BOLT := 10

const NONE := 255  # pas de héros (le monde)

static var on := false
static var sink := Callable()  # NetHost._on_event(kind, parent, args)


static func emit(kind: int, parent: Node, args: Array) -> void:
	if sink.is_valid():
		sink.call(kind, parent, args)


## Hôte : écrit un événement dans [param b]. [param slot_of] : Callable(nœud) -> case du héros (NONE sinon) ;
## [param name_id] : Callable(texte) -> indice de la table des noms. Renvoie faux si l'événement est ignoré.
static func encode(b: StreamPeerBuffer, kind: int, parent: Node, args: Array, slot_of: Callable, name_id: Callable) -> bool:
	var owner := int(slot_of.call(parent))
	match kind:
		FX:
			if String(args[0]) == "":
				return false
			b.put_u8(kind)
			b.put_u8(owner)
			b.put_u16(int(name_id.call(String(args[0]))))
			NetProtocol.put_vec(b, args[1])
			b.put_half(float(args[2]))
			b.put_half(float(args[3]))
			b.put_u8(int(slot_of.call(args[4])) if args[4] != null else NONE)
		SLASH:
			b.put_u8(kind)
			b.put_u8(owner)
			NetProtocol.put_vec(b, args[0])
			var fwd: Vector3 = args[1]
			b.put_half(atan2(fwd.x, fwd.z))
			b.put_half(float(args[2]))
			b.put_half(float(args[3]))
			NetProtocol.put_color(b, args[4])
		RING, FLASH:
			b.put_u8(kind)
			b.put_u8(owner)
			NetProtocol.put_vec(b, args[0])
			b.put_half(float(args[1]))
			NetProtocol.put_color(b, args[2])
		SPARK:
			b.put_u8(kind)
			b.put_u8(owner)
			NetProtocol.put_vec(b, args[0])
			NetProtocol.put_color(b, args[1])
			b.put_u8(1 if bool(args[2]) else 0)
		DMG:
			if owner == NONE:
				return false
			b.put_u8(kind)
			b.put_u8(owner)
			b.put_float(float(args[0]))
			b.put_u8((1 if bool(args[1]) else 0) | (2 if bool(args[3]) else 0) | (4 if bool(args[4]) else 0))
		TEXT:
			if owner == NONE:
				return false
			b.put_u8(kind)
			b.put_u8(owner)
			NetProtocol.put_color(b, args[1])
			NetProtocol.put_str(b, String(args[0]))
		TELE:
			var props := {}
			var src: Dictionary = args[2]
			for k in src:
				if typeof(src[k]) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_COLOR]:
					props[k] = src[k]
			b.put_u8(kind)
			b.put_u8(owner)
			NetProtocol.put_vec(b, args[0])
			b.put_half(float(args[1]))
			var raw := var_to_bytes(props)
			b.put_u16(raw.size())
			b.put_data(raw)
		SFX:
			if String(args[1]) == "":
				return false
			b.put_u8(kind)
			b.put_u8(owner)
			NetProtocol.put_vec(b, args[0])
			b.put_u16(int(name_id.call(String(args[1]))))
			b.put_half(float(args[2]))
		BOLT:
			var act: Dictionary = args[2]
			b.put_u8(kind)
			b.put_u8(owner)
			NetProtocol.put_vec(b, args[0])
			var d: Vector3 = args[1]
			b.put_half(atan2(d.x, d.z))
			b.put_half(float(act.get("range", 13.0)))
			b.put_u16(int(name_id.call(String(act.get("projectile", "arrow")))))
		_:
			return false
	return true


## Client : lit et rejoue l'événement suivant de [param b]. [param ghost_of] : Callable(case) -> fantôme (ou null) ;
## [param name_of] : Callable(indice) -> texte ; [param mine] : case du héros du joueur (dégâts « subis »). Renvoie le type lu
## (0 si le paquet est fini ou abîmé).
static func replay(b: StreamPeerBuffer, root: Node, ghost_of: Callable, name_of: Callable, mine: int) -> int:
	if b.get_available_bytes() < 2:
		return 0
	var kind := b.get_u8()
	var owner := b.get_u8()
	var ghost: Node3D = ghost_of.call(owner) if owner != NONE else null
	var parent: Node = ghost if ghost != null else root
	match kind:
		FX:
			var fx_name := String(name_of.call(b.get_u16()))
			var pos := NetProtocol.get_vec(b)
			var yaw := b.get_half()
			var sc := b.get_half()
			var fslot := b.get_u8()
			var follow: Node3D = ghost_of.call(fslot) if fslot != NONE else null
			if fx_name != "":
				EdenFx.play(parent, fx_name, pos, yaw, sc, follow)
		SLASH:
			var pos := NetProtocol.get_vec(b)
			var yaw := b.get_half()
			var r := b.get_half()
			var arc := b.get_half()
			var col := NetProtocol.get_color(b)
			Vfx.slash(parent, pos, Vector3(sin(yaw), 0.0, cos(yaw)), r, arc, col)
		RING:
			var pos := NetProtocol.get_vec(b)
			var r := b.get_half()
			Vfx.ring(parent, pos, r, NetProtocol.get_color(b))
		FLASH:
			var pos := NetProtocol.get_vec(b)
			var s := b.get_half()
			Vfx.flash(parent, pos, s, NetProtocol.get_color(b))
		SPARK:
			var pos := NetProtocol.get_vec(b)
			var col := NetProtocol.get_color(b)
			Vfx.spark(parent, pos, col, b.get_u8() != 0)
		DMG:
			var amount := b.get_float()
			var fl := b.get_u8()
			if ghost != null:
				DamageNumber.spawn(ghost, amount, fl & 1 != 0, owner == mine, fl & 2 != 0, fl & 4 != 0)
		TEXT:
			var col := NetProtocol.get_color(b)
			var txt := NetProtocol.get_str(b)
			if ghost != null and txt != "":
				DamageNumber.spawn_text(ghost, txt, col)
		TELE:
			var pos := NetProtocol.get_vec(b)
			var yaw := b.get_half()
			var n := b.get_u16()
			var r: Array = b.get_data(n)
			var props: Variant = bytes_to_var(r[1]) if int(r[0]) == OK else null
			if props is Dictionary and parent.is_inside_tree():
				Telegraph.spawn(parent, pos, yaw, props)  # sans source : chez le client, une zone ne touche personne
		SFX:
			var pos := NetProtocol.get_vec(b)
			var wav := String(name_of.call(b.get_u16()))
			var vol := b.get_half()
			Sfx.play_at(parent, pos, wav, vol)
		BOLT:
			var pos := NetProtocol.get_vec(b)
			var yaw := b.get_half()
			var rng := b.get_half()
			var style := String(name_of.call(b.get_u16()))
			if ghost is Player:
				HeroBolt.fire(ghost as Player, pos, Vector3(sin(yaw), 0.0, cos(yaw)), {"range": rng, "projectile": style})
		_:
			return 0
	return kind
