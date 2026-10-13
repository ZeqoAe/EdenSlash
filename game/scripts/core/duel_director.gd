class_name DuelDirector
extends Node
## Déroulement d'un duel (voir Duel) : arène éclairée à piliers, les deux héros face à face à
## chaque manche (PV pleins, recharges remises à zéro), 3 s de compte à rebours (l'adversaire
## ne bouge pas), manche gagnée quand l'autre tombe ; 2 manches gagnantes.

const COUNTDOWN := 3.0
const BETWEEN := 2.5  # pause après une manche
const SPAWN_DIST := 9.0

var d: RunDirector
var phase := "countdown"  # countdown, fight, between, done
var _t := 0.0
var _rival: ClassRival
var _center := Vector3.ZERO
var _obj_t := 0.0


func setup(director: RunDirector) -> void:
	d = director
	var z := GameData.zone(Duel.ZONE)
	d.zone = z
	d.map = d.world.new_arena_map(randi())
	d.world._apply_biome_env()
	_center = Vector3(d.map.size * 0.5, 0, d.map.size * 0.5)
	_center.y = d.map.height_at(_center.x, _center.z)
	var p := d.player
	p.level = Duel.level
	Run.hero_level = Duel.level
	Run.max_level = Duel.level
	p.recalc_stats()
	d.zone_changed.emit({"name": "Duel · %s" % GameData.class_data(Duel.rival_class).get("name_fr", ""), "levels": [Duel.level, Duel.level]})
	_start_round()


func _ground(p: Vector3) -> Vector3:
	var g: Vector3 = d.map.ground_at(p.x, p.z)
	return g if g != Vector3.INF else _center


## Nouvelle manche : héros et adversaire face à face, PV pleins, compte à rebours.
func _start_round() -> void:
	d._clear_monsters()
	var p := d.player
	if p.is_dead:
		p.respawn(_ground(_center + Vector3(0, 0, SPAWN_DIST)))
	d._place_player(_ground(_center + Vector3(0, 0, SPAWN_DIST)))
	p.heal(p.max_hp)
	p.skill_ready_at.clear()
	p.statuses.clear()
	_rival = Duel.make_rival()
	d.add_child(_rival)
	_rival.global_position = _ground(_center - Vector3(0, 0, SPAWN_DIST)) + Vector3.UP * 0.4
	_rival.look_at(Vector3(p.global_position.x, _rival.global_position.y, p.global_position.z), Vector3.UP)
	_rival.rotate_y(PI)
	_rival.passive = true  # immobile pendant le compte à rebours
	_rival.died.connect(_on_rival_died)
	phase = "countdown"
	_t = COUNTDOWN
	d.message.emit("Manche %d · %d - %d" % [Duel.round_n, Duel.wins, Duel.losses], 1.5)
	if p.autoplay:
		print("[duel] manche %d contre %s (%s), niveau %d · PV héros %d · PV adversaire %d" % [Duel.round_n, Duel.rival_class,
			ClassRival.NAMES[Duel.difficulty], Duel.level, int(p.max_hp), int(_rival.max_hp)])


func update(delta: float) -> void:
	_t -= delta
	match phase:
		"countdown":
			var n := ceili(_t)
			if n != ceili(_t + delta) and n > 0:
				d.message.emit(str(n), 0.8)
			if _t <= 0.0:
				phase = "fight"
				if is_instance_valid(_rival):
					_rival.passive = false
				d.message.emit("COMBAT !", 1.0)
		"between":
			if _t <= 0.0:
				Duel.round_n += 1
				_start_round()
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.25
		d.objective_changed.emit("Duel · manche %d · toi %d - %d %s" % [Duel.round_n, Duel.wins, Duel.losses, GameData.class_data(Duel.rival_class).get("name_fr", "")])


func _on_rival_died(_who: Combatant, _killer: Combatant) -> void:
	if phase != "fight":
		return
	Duel.wins += 1
	_end_round(true)


## Le héros est tombé (world.gd) : manche perdue.
func player_down() -> void:
	if phase != "fight":
		return
	Duel.losses += 1
	if is_instance_valid(_rival):
		_rival.passive = true
	_end_round(false)


func _end_round(won: bool) -> void:
	if Duel.wins >= Duel.ROUNDS_TO_WIN or Duel.losses >= Duel.ROUNDS_TO_WIN:
		phase = "done"
		var victory := Duel.wins >= Duel.ROUNDS_TO_WIN
		d.message.emit("VICTOIRE !" if victory else "DÉFAITE…", 2.5)
		if d.player.autoplay:
			print("[duel] fin : %s %d - %d" % ["victoire" if victory else "défaite", Duel.wins, Duel.losses])
		d.get_tree().create_timer(2.5).timeout.connect(func(): d.world.duel_end(victory))
		return
	phase = "between"
	_t = BETWEEN
	d.message.emit("Manche gagnée ! %d - %d" % [Duel.wins, Duel.losses] if won else "Manche perdue… %d - %d" % [Duel.wins, Duel.losses], 2.0)
