class_name NetIntent
extends RefCounted
## Entrées du joueur local en Mode amis (lot NET-A) : ce qu'il veut faire, envoyé tel quel à l'hôte (et posé dans le
## BotInput de son héros chez l'hôte). Clavier ou manette pour se déplacer (relatif à la caméra), souris pour viser, attaque
## maintenue, compteurs d'appui pour les sorts, l'esquive, le saut et l'échange d'arme (un paquet perdu ne perd pas l'appui).
## Les modes de contrôle complets du jeu (clic pour se déplacer, cible verrouillée, sorts automatiques) viendront avec NET-C.
## [member pilot] : pilote automatique (tests et mesures) qui s'approche du héros le plus proche, tourne autour, frappe, lance
## un sort toutes les 3 s, esquive toutes les 4,5 s, saute toutes les 10 s, et s'arrête 0,8 s toutes les 3,2 s (mesure du
## retard ressenti au redémarrage).

var pilot := false
var idle := false  # menu ouvert : on ne bouge plus
var counts := {}
var tick := 0
var still := false  # (pilote) phase d'arrêt
var _phase := 0.0


func _init() -> void:
	for a in NetProtocol.PULSES:
		counts[a] = 0


## À chaque image de physique : compte les appuis.
func sample(delta: float) -> void:
	tick += 1
	_phase += delta
	if pilot:
		still = fmod(_phase, 3.2) > 2.4
		if still:
			return
		if tick % 180 == 90:
			counts["skill_%d" % (1 + (tick / 180) % 4)] += 1
		if tick % 270 == 200:
			counts["dodge"] += 1
		if tick % 600 == 400:
			counts["jump"] += 1
		return
	if idle or DisplayServer.get_name() == "headless":
		return
	for a in NetProtocol.PULSES:
		if InputMap.has_action(a) and Input.is_action_just_pressed(a):
			counts[a] += 1


## Entrées de l'instant : {move, aim, attack, counts}. [param me] : position du héros ; [param target] : héros le plus proche
## (Vector3.INF sans) ; [param cam] : caméra (déplacement relatif à son cap, visée au curseur).
func read(me: Vector3, target: Vector3, cam: Camera3D, arena_r: float) -> Dictionary:
	var move := Vector3.ZERO
	var aim := Vector3.INF
	var attack := false
	if pilot:
		if still:
			pass
		elif target != Vector3.INF:
			var to := target - me
			to.y = 0.0
			var side := Vector3(-to.z, 0.0, to.x).normalized()
			move = (to.normalized() if to.length() > 3.0 else side * 0.8).normalized()
			aim = target
			attack = to.length() < 4.0 and int(_phase * 2.0) % 3 != 0
		else:
			move = Vector3(sin(_phase * 0.8), 0.0, cos(_phase * 0.8))
		if not still and Vector2(me.x, me.z).length() > arena_r - 2.0:
			move = -Vector3(me.x, 0.0, me.z).normalized()
	elif not idle and DisplayServer.get_name() != "headless":
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var fwd := Vector3.FORWARD
		var right := Vector3.RIGHT
		if cam:
			fwd = -cam.global_transform.basis.z
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
			right = Vector3(-fwd.z, 0.0, fwd.x)
		move = (right * v.x - fwd * v.y).limit_length(1.0)
		attack = Input.is_action_pressed("attack")
		if cam and not Gamepad.active:
			aim = ground_point(cam, me.y)
	return {"move": move, "aim": aim, "attack": attack, "counts": counts.duplicate()}


## Point du sol (hauteur [param y]) sous le curseur.
static func ground_point(cam: Camera3D, y: float) -> Vector3:
	var mp := cam.get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if absf(d.y) < 0.001:
		return Vector3.INF
	var t := (y - o.y) / d.y
	return o + d * t if t > 0.0 else Vector3.INF
