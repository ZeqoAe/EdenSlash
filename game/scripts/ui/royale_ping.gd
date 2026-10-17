class_name RoyalePing
extends RefCounted
## Repère personnel du Battle royale (lot BR-I1, backlog P0 n° 4) : une épingle lagon posée au sol (clic molette, L3 à la
## manette : devant le héros) ou sur la grande carte (clic, X à la manette). Visible à l'écran avec la distance
## (RoyaleEdge), sur la mini-carte et sur la grande carte (RoyaleMap). Reposer le repère près du précédent l'enlève ;
## il s'efface quand on l'atteint (au sol). Un seul repère ; aucune règle de jeu n'en dépend.

const TOGGLE_RADIUS := 8.0  # m : un nouveau repère plus près de l'ancien l'enlève
const REACHED := 5.0  # m : repère atteint (au sol) : il s'efface
const AHEAD := 30.0  # m : repère posé à la manette, devant le héros

static var pos := Vector3.INF
static var placed_at := 0  # instant (ms) : petit rebond à la pose
static var place := "Repère"  # nom du lieu du repère, calculé à la pose (pas à chaque image)


static func reset() -> void:
	pos = Vector3.INF
	place = "Repère"


static func has() -> bool:
	return pos != Vector3.INF


## Pose le repère en [param p], ou l'enlève si [param p] est tout près de l'ancien. Renvoie true s'il est posé.
## [param src] : le directeur du Battle royale (nom du lieu nommé le plus proche, voir places()).
static func toggle(p: Vector3, src: Node = null) -> bool:
	if has() and Vector2(p.x - pos.x, p.z - pos.z).length() < TOGGLE_RADIUS:
		reset()
		Sfx.ui("click", -10.0)
		return false
	pos = p
	place = place_name(src)
	placed_at = Time.get_ticks_msec()
	Sfx.ui("confirm", -10.0)
	return true


## Distance au sol (m) entre [param from] et le repère.
static func distance(from: Vector3) -> float:
	return Vector2(pos.x - from.x, pos.z - from.z).length() if has() else INF


## « Repère · 86 m » (ou le nom du lieu s'il y en a un : « Ruines du col · 86 m ») ; [param src] : voir places().
static func text(from: Vector3) -> String:
	if not has():
		return ""
	return "%s · %d m" % [place, roundi(distance(from))]


## Nom du lieu du repère : celui d'un lieu nommé à moins de 40 m, sinon « Repère ».
static func place_name(src: Node) -> String:
	for pl in places(src):
		var q: Vector3 = pl.get("pos", Vector3.INF)
		if q != Vector3.INF and Vector2(q.x - pos.x, q.z - pos.z).length() < 40.0:
			return String(pl.get("name", "Repère"))
	return "Repère"


## Lieux nommés (lot BR-I2 : RoyaleDirector.places() -> [{name, pos, stars, aimed…}]) ; [] tant que la partie n'en a pas.
## [param src] : le directeur du Battle royale (ou tout nœud qui a places()).
static func places(src: Node) -> Array:
	if src != null and is_instance_valid(src) and src.has_method("places"):
		var out = src.call("places")
		return out if out is Array else []
	return []


## Point au sol devant [param hero] (repère posé à la manette, hors de la grande carte).
static func ahead_of(hero: Node3D, map: Node) -> Vector3:
	var f := -hero.global_transform.basis.z
	if hero.has_method("forward"):
		f = hero.call("forward")
	f.y = 0.0
	if f.length() < 0.1:
		f = Vector3.FORWARD
	var p := hero.global_position + f.normalized() * AHEAD
	return ground(map, p.x, p.z)


## Sol de la carte en (x, z).
static func ground(map: Node, x: float, z: float) -> Vector3:
	if map != null and map.has_method("height_at"):
		return Vector3(x, float(map.call("height_at", x, z)), z)
	return Vector3(x, 0.0, z)


## Point du sol sous le curseur [param screen] (clic molette) : rayon de la caméra jusqu'au relief (pas de 2 m, puis affiné).
static func under_cursor(cam: Camera3D, screen: Vector2, map: Node) -> Vector3:
	if cam == null:
		return Vector3.INF
	var o := cam.project_ray_origin(screen)
	var dir := cam.project_ray_normal(screen)
	var t := 0.0
	var prev := 0.0
	while t < 400.0:
		var p := o + dir * t
		var h := ground(map, p.x, p.z).y
		if p.y <= h:
			var lo := prev
			var hi := t
			for i in 10:
				var mid := (lo + hi) * 0.5
				var q := o + dir * mid
				if q.y <= ground(map, q.x, q.z).y:
					hi = mid
				else:
					lo = mid
			var hit := o + dir * hi
			return ground(map, hit.x, hit.z)
		prev = t
		t += 2.0
	return Vector3.INF
