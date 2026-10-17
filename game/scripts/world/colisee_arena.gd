class_name ColiseeArena
extends Node3D
## Une arène du Colisée (lot CO-B, R_CO_B.md) : posée sur la carte ProcMap.generate_colisee (son entrée de
## ProcMap.colisee_arenas : nom, centre, piliers, points des fleurs), elle porte l'anneau de feu (ColiseeRing) et les fleurs
## de vie (ColiseeFlower) d'UN combat. Le directeur du combat (lot CO-C) : reset(combattants) à chaque manche,
## tick(delta, combattants) pendant le combat, set_shown(vrai / faux) selon l'arène regardée (rien n'est dessiné ailleurs).

var index := 0
var info: Dictionary = {}
var center := Vector3.ZERO
var ring: ColiseeRing
var flowers: Array = []
var shown := true


## Toutes les arènes de [param map] sous [param parent] (dans l'ordre de ProcMap.colisee_arenas).
static func build_all(map: ProcMap, parent: Node) -> Array:
	var out: Array = []
	for e in map.colisee_arenas:
		var a := ColiseeArena.new()
		a.name = "ColiseeArena%d" % int(e.index)
		parent.add_child(a)
		a.setup(e)
		out.append(a)
	return out


func setup(e: Dictionary) -> void:
	info = e
	index = int(e.index)
	center = e.center
	global_position = center
	ring = ColiseeRing.new()
	add_child(ring)
	ring.setup(center)
	for p in e.get("flowers", []):
		var f := ColiseeFlower.new()
		add_child(f)
		f.global_position = p
		flowers.append(f)


func title() -> String:
	return String(info.get("name", "Arène"))


## Points de départ des deux camps (côtés opposés, à [param dist] m du centre), [param k] = 0..2 dans le camp.
func spawn_point(side: int, k: int, map: ProcMap, dist := 9.0) -> Vector3:
	var z := dist * (1.0 if side == 0 else -1.0)
	var x := 3.5 * (0.0 if k == 0 else (1.0 if k % 2 == 1 else -1.0) * ceilf(k / 2.0))
	var p := center + Vector3(x, 0.0, z)
	var g: Vector3 = map.ground_at(p.x, p.z)
	return g if g != Vector3.INF else p


func reset(fighters: Array = []) -> void:
	ring.reset(fighters)
	for f in flowers:
		(f as ColiseeFlower).reset()


func tick(delta: float, fighters: Array) -> void:
	ring.advance(delta, fighters)
	for f in flowers:
		(f as ColiseeFlower).tick(delta, fighters)


func set_shown(on: bool) -> void:
	shown = on
	visible = on
