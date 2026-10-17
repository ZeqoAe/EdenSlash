extends Node
## Directeur de démonstration du socle des modes d'équipes (lot MODE-0, test_mode0) : ce que fera le directeur d'un vrai
## mode (Colisée, Deux Voies, Assaut), en tout petit. Une arène de duel, DEUX arènes logiques posées au MÊME endroit
## (arène 0 : le joueur + 1 allié contre 2 ; arène 1 : 2 contre 2 entre IA) : aucun coup ne doit passer d'une arène à
## l'autre. Monté par TeamMatch.mount depuis RunDirector.start ; reçoit la mort du joueur et l'abandon de world.gd.

var d: RunDirector
var center := Vector3.ZERO
var heroes: Array = []
var downs := 0
var abandoned := false
## Coups reçus : [victime, source, montant] (relevés par test_mode0).
var hits: Array = []


func setup(director: RunDirector) -> void:
	d = director
	d.zone = GameData.zone(Duel.ZONE)
	d.map = d.world.new_arena_map(1234)
	d.world._apply_biome_env()
	center = Vector3(d.map.size * 0.5, 0, d.map.size * 0.5)
	center.y = d.map.height_at(center.x, center.z)
	var p := d.player
	p.level = 10
	Run.hero_level = 10
	Run.max_level = 10
	p.recalc_stats()
	TeamMatch.add(p, 0, 0)
	d._place_player(_ground(center + Vector3(0, 0, 8)))
	_watch(p)
	# arène 0 : un allié du joueur, deux adversaires ; arène 1 (même endroit) : deux équipes d'IA de 2
	_spawn("cleric", 0, 0, Vector3(3, 0, 8))
	_spawn("knight", 1, 0, Vector3(-2, 0, -8))
	_spawn("magician", 1, 0, Vector3(2, 0, -8))
	_spawn("warrior", 2, 1, Vector3(-2, 0, 6))
	_spawn("hunter", 2, 1, Vector3(2, 0, 6))
	_spawn("thief", 3, 1, Vector3(-2, 0, -6))
	_spawn("bard", 3, 1, Vector3(2, 0, -6))
	TeamMatch.start_round()
	TeamMatch.set_phase("fight")
	d.zone_changed.emit({"name": TeamMatch.title(), "levels": [10, 10]})


func _spawn(cid: String, t: int, arena: int, off: Vector3) -> void:
	var r := TeamMatch.make_hero(cid, 10, 2, t, arena)
	d.add_child(r)
	r.global_position = _ground(center + off) + Vector3.UP * 0.4
	heroes.append(r)
	_watch(r)


func _watch(c: Combatant) -> void:
	c.damaged.connect(func(amount: float, src: Combatant): hits.append([c, src, amount]))
	c.died.connect(func(_w, k): TeamMatch.note_ko(c, k))


func _ground(p: Vector3) -> Vector3:
	var g: Vector3 = d.map.ground_at(p.x, p.z)
	return g if g != Vector3.INF else center


func update(delta: float) -> void:
	TeamMatch.elapsed += delta
	PvpCaps.elapsed += delta


func player_down(_killer: Combatant) -> void:
	downs += 1


func abandon() -> void:
	abandoned = true
