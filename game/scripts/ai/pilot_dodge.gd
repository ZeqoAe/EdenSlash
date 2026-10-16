class_name PilotDodge
extends RefCounted
## Mesures seulement (passe M8, option --dodge des outils tools/m8_tower, tools/tower_run, tools/boss_ttk) : le pilote
## automatique (Player.autoplay ou l'aide « Bot ») sort des zones rouges annoncées (Telegraph) d'un adversaire et des
## flaques (Hazard) où il se tient, reste en deçà du mur d'une arène qui se resserre (BossBricks.ArenaWall), et un tireur
## recule quand on l'approche (kite_input), comme un joueur moyen : il réagit après REACT s, lit une zone sur READ (tirage fixe par
## zone), marche vers le bord le plus proche s'il a le temps, sinon esquive (roulade, invulnérable) juste avant l'impact.
## Sans effet en jeu : [member enabled] n'est vrai que si un outil de mesure le demande.

static var enabled := false

const REACT := 0.3  # délai de réaction (s) après l'apparition de la zone
const READ := 0.85  # part des zones lues (les autres sont encaissées)
const DASH_AT := 0.35  # temps restant (s) sous lequel il esquive au lieu de marcher
const MARGIN := 0.6  # marge au bord de la zone (m)
const CHECK := 5  # images physiques entre deux lectures

static var _cache := {}  # identifiant du héros -> {"at": image physique, "res": menace}


## Direction au sol (monde) pour sortir de la zone hostile la plus pressante où se tient [param hero], et le temps
## restant avant son impact : {"dir": Vector3, "left": float} ; vide s'il n'y a rien à fuir.
static func threat(hero: Combatant) -> Dictionary:
	if not enabled or hero == null or not is_instance_valid(hero) or hero.is_dead:
		return {}
	var key := hero.get_instance_id()
	var now := Engine.get_physics_frames()
	var c: Dictionary = _cache.get(key, {})
	if not c.is_empty() and now - int(c.at) < CHECK:
		return c.res
	var best := {}
	var pos := hero.global_position
	var margin := float(hero.get("radius")) + MARGIN if hero.get("radius") != null else MARGIN
	for n in hero.get_tree().get_nodes_in_group("telegraphs"):
		var tg := n as Telegraph
		if tg == null or tg.is_queued_for_deletion():
			continue
		var src = tg.source
		if is_instance_valid(src) and (src == hero or src.team == hero.team):
			continue
		if tg._t < REACT or not tg.contains(pos, margin):
			continue
		if absi(hash([tg.get_instance_id(), "lu"])) % 100 >= int(READ * 100.0):
			continue
		var left := tg.delay - tg._t
		if left < 0.0 or (not best.is_empty() and left >= float(best.left)):
			continue
		best = {"dir": _out_of(tg, pos), "left": left}
	if best.is_empty():
		for n in hero.get_tree().current_scene.get_children():
			if n is BossBricks.ArenaWall:
				# arène qui se resserre : rester en deçà du mur
				var in_dir: Vector3 = n.global_position - pos
				in_dir.y = 0.0
				if in_dir.length() > float(n.r) - margin * 2.0:
					best = {"dir": in_dir.normalized(), "left": 0.5}
					break
				continue
			var hz := n as Hazard
			if hz == null or hz.is_queued_for_deletion():
				continue
			var to := pos - hz.global_position
			to.y = 0.0
			if to.length() <= hz.radius + margin * 0.5:
				best = {"dir": to.normalized() if to.length() > 0.2 else hero.forward(), "left": 99.0}
				break
	_cache[key] = {"at": now, "res": best}
	if _cache.size() > 32:
		_cache.clear()
	return best


## Le pilote doit-il esquiver tout de suite (roulade) ?
static func wants_dash(hero: Combatant) -> bool:
	var th := threat(hero)
	return not th.is_empty() and float(th.left) <= DASH_AT


## Entrée de déplacement du pilote (repère de la caméra, comme Player._autoplay_input) ; Vector2.INF : rien à fuir.
static func move_input(hero: Combatant) -> Vector2:
	var th := threat(hero)
	if th.is_empty():
		return Vector2.INF
	var to: Vector3 = th.dir
	var cam := hero.get_viewport().get_camera_3d()
	var local := to.rotated(Vector3.UP, -cam.global_rotation.y) if cam else to
	return Vector2(local.x, local.z).normalized()


## Tireur (portée d'attaque au-delà de KITE_REACH) : recule KITE_TIME s quand un ennemi arrive à moins de KITE_MIN, puis
## tire au moins KITE_GAP s avant de reculer encore, comme un joueur d'archer ou de mage (l'aide « Bot » seule reste plantée
## au contact ; reculer sans cesse, elle ne tirait plus) ; Vector2.INF sinon.
const KITE_REACH := 6.0
const KITE_MIN := 4.5
const KITE_TIME := 0.8
const KITE_GAP := 2.0

static var _kite := {}  # identifiant du héros -> image physique de fin du recul en cours


static func kite_input(hero: Player) -> Vector2:
	if not enabled or hero.attack_reach() <= KITE_REACH:
		return Vector2.INF
	var now := Engine.get_physics_frames()
	var tps := Engine.physics_ticks_per_second
	var until := int(_kite.get(hero.get_instance_id(), -100000))
	var m := hero.nearest_monster(KITE_MIN)
	if now > until:
		if m == null or now < until + int(KITE_GAP * tps):
			return Vector2.INF
		until = now + int(KITE_TIME * tps)
		_kite[hero.get_instance_id()] = until
	if m == null:
		return Vector2.INF
	var away := hero.global_position - m.global_position
	away.y = 0.0
	if away.length() < 0.1:
		away = -hero.forward()
	var cam := hero.get_viewport().get_camera_3d()
	var local := away.rotated(Vector3.UP, -cam.global_rotation.y) if cam else away
	return Vector2(local.x, local.z).normalized()


## Sortie la plus courte de la zone [param tg] depuis [param pos] (au sol).
static func _out_of(tg: Telegraph, pos: Vector3) -> Vector3:
	var to := pos - tg.global_position
	to.y = 0.0
	var fwd := Vector3(sin(tg.rotation.y), 0.0, cos(tg.rotation.y))
	match tg.shape:
		"line", "cone":
			var side := fwd.cross(Vector3.UP).normalized()
			var s := to.dot(side)
			return side * (signf(s) if absf(s) > 0.05 else 1.0)
		"ring":
			# anneau : vers le centre si le bord intérieur est plus proche, sinon vers l'extérieur
			if to.length() - tg.inner < tg.radius - to.length():
				return -to.normalized() if to.length() > 0.1 else fwd
			return to.normalized() if to.length() > 0.1 else fwd
	return to.normalized() if to.length() > 0.2 else fwd.cross(Vector3.UP).normalized()
