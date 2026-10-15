class_name DuelDirector
extends Node
## Déroulement d'un duel (voir Duel) : arène éclairée à piliers, les deux héros face à face à
## chaque manche (PV pleins, recharges remises à zéro), 3 s de compte à rebours (l'adversaire
## ne bouge pas), manche gagnée quand l'autre tombe ; 2 manches gagnantes.

const COUNTDOWN := 3.0
const BETWEEN := 2.5  # pause après une manche
const BETWEEN_TEAM := 4.0
const SPAWN_DIST := 9.0

var d: RunDirector
var phase := "countdown"  # countdown, fight, between, done
var _t := 0.0
var _rival: ClassRival  # adversaire scripté
var _foe: Player  # ou héros ennemi piloté par un cerveau d'IA
var _pilot: MlDuelPilot
var _foes: Array = []  # tous les adversaires scriptés de la manche (le premier est _rival)
var _allies: Array = []  # alliés IA du joueur (Arènes)
var _player_out := false  # le joueur est tombé mais ses alliés se battent encore
var _center := Vector3.ZERO
var _obj_t := 0.0
var _bars: TeamBars  # équipes : PV de chaque héros sous le titre (passe M7)
## Manche en cours : dégâts infligés et reçus, K.O. de chaque héros (id d'instance -> {dealt, taken, ko}, PvpCaps.board) ;
## tableau de manche montré entre deux manches en équipe (passe M7).
var board: Dictionary = {}


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
	# titre du HUD : le mode en équipe, en Ligue et au Panthéon ; la classe de l'adversaire en duel libre
	var title := Duel.mode_title() if Duel.mode != "free" else "Duel · %s" % GameData.class_data(Duel.rival_class).get("name_fr", "")
	d.zone_changed.emit({"name": title, "levels": [Duel.level, Duel.level]})
	_start_round()
	if Duel.team_mode():
		_bars = TeamBars.new()
		var stack: Node = d.world.hud.get("_left") if d.world.get("hud") != null else null
		if stack != null:
			stack.add_child(_bars)  # pile de gauche du HUD, sous le titre
			_bars.setup(self)


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
	for n in [_foe, _pilot]:
		if is_instance_valid(n):
			n.queue_free()
	_foe = null
	_pilot = null
	_rival = null
	if Duel.pilot == "" or not _spawn_brain_foe():
		_rival = Duel.make_rival()
		d.add_child(_rival)
		_rival.global_position = _ground(_center - Vector3(0, 0, SPAWN_DIST)) + Vector3.UP * 0.4
		_rival.look_at(Vector3(p.global_position.x, _rival.global_position.y, p.global_position.z), Vector3.UP)
		_rival.rotate_y(PI)
		_rival.passive = true  # immobile pendant le compte à rebours
		_rival.died.connect(_on_rival_died)
	_spawn_team(p)
	if is_instance_valid(_pilot):
		_pilot.others = _allies  # le cerveau vise aussi tes alliés (avant : le joueur seul, figé quand il tombait)
	# tableau de la manche, caméra rendue au joueur (elle suivait un allié s'il était tombé)
	PvpCaps.board = {}
	board = PvpCaps.board
	for c in [p] + _allies + _foes + ([_foe] if is_instance_valid(_foe) else []):
		if is_instance_valid(c) and not c.died.is_connected(_note_ko):
			c.died.connect(_note_ko)
	if d.world.rig != null:
		d.world.rig.target = p
	if _bars != null:
		_bars.rebuild()
	phase = "countdown"
	_t = COUNTDOWN
	_hazard_at = HAZARD_FIRST
	PvpCaps.elapsed = 0.0
	d.message.emit("Manche %d · %d - %d" % [Duel.round_n, Duel.wins, Duel.losses], 1.5)
	if p.autoplay:
		var opp: Combatant = _rival if _rival else _foe
		print("[duel] manche %d contre %s (%s), niveau %d · PV héros %d · PV adversaire %d" % [Duel.round_n, Duel.rival_class,
			("cerveau " + Duel.pilot) if _foe else ClassRival.NAMES[Duel.difficulty], Duel.level, int(p.max_hp), int(opp.max_hp)])


## Équipes : adversaires en plus (Gantelet, Arènes) et alliés IA du joueur, de part et d'autre.
func _spawn_team(p: Player) -> void:
	for n in _foes + _allies:
		if is_instance_valid(n) and n != _rival:
			n.queue_free()
	_foes = [_rival] if is_instance_valid(_rival) else []
	_allies = []
	_player_out = false
	var i := 1
	for cid in Duel.extra_foes:
		var f := Duel.make_extra(String(cid))
		d.add_child(f)
		f.global_position = _ground(_center - Vector3(0, 0, SPAWN_DIST) + Vector3(3.5 * (1 if i % 2 == 1 else -1) * ((i + 1) / 2), 0, 0)) + Vector3.UP * 0.4
		f.passive = true
		f.died.connect(_on_rival_died)
		_foes.append(f)
		i += 1
	i = 1
	for cid in Duel.team_allies:
		var a := Duel.make_ally(String(cid))
		d.add_child(a)
		a.global_position = _ground(_center + Vector3(0, 0, SPAWN_DIST) + Vector3(3.5 * (1 if i % 2 == 1 else -1) * ((i + 1) / 2), 0, 0)) + Vector3.UP * 0.4
		a.passive = true
		_allies.append(a)
		i += 1


func _all_down(list: Array) -> bool:
	return list.all(func(x): return not is_instance_valid(x) or x.is_dead)


## Héros ennemi piloté par un cerveau d'IA : sa classe, ses 12 sorts, et l'équipement et
## l'apparence de l'adversaire de l'éditeur s'il y en a un. false si le cerveau manque.
func _spawn_brain_foe() -> bool:
	var p := d.player
	var b := Duel.rival_build
	var h := Player.new()
	h.foe = true
	h.class_id = Duel.rival_class
	h.level = Duel.level
	var kit := Duel.kit_from_grid(Duel.rival_class, b.get("spells", []) if not b.is_empty() else Duel.rival_spells)
	h.kit_skills = kit.skills
	h.kit_chains = kit.chains
	Duel.equip_foe(h, Duel.level)  # profil de l'éditeur, build opti, copie ou équipement généré
	d.add_child(h)
	var pilot := MlDuelPilot.new()
	d.add_child(pilot)
	if not pilot.setup(h, p, Duel.pilot, _center):
		h.queue_free()
		pilot.queue_free()
		d.message.emit("Cerveau d'IA introuvable ou d'une ancienne version : adversaire scripté", 3.0)
		return false
	pilot.set_physics_process(false)  # immobile pendant le compte à rebours
	h.global_position = _ground(_center - Vector3(0, 0, SPAWN_DIST)) + Vector3.UP * 0.4
	h.face_direction(p.global_position - h.global_position, 1.0, 100.0)
	h.max_hp *= float(b.get("hp_mult", 1.0)) if not b.is_empty() else 1.0
	h.hp = h.max_hp
	h.display_name = "<Duel> %s · IA %s" % [String(b.get("name", GameData.class_data(Duel.rival_class).get("name_fr", ""))) if not b.is_empty()
		else String(GameData.class_data(Duel.rival_class).get("name_fr", "")), Duel.pilot]
	h.died.connect(_on_rival_died)
	_foe = h
	_pilot = pilot
	return true


func update(delta: float) -> void:
	_t -= delta
	if phase == "fight":
		var was := PvpCaps.elapsed
		PvpCaps.elapsed += delta
		if was < PvpCaps.pressure_start() and PvpCaps.elapsed >= PvpCaps.pressure_start():
			d.message.emit("Acharnement : les coups font plus mal, les soins faiblissent", 2.5)
		var late := ModeRules.num("sudden_after", 100000.0)
		if was <= late and PvpCaps.elapsed > late:
			d.message.emit("Mort subite : les coups font de plus en plus mal", 2.5)  # (passe M7)
	match phase:
		"countdown":
			var n := ceili(_t)
			if n != ceili(_t + delta) and n > 0:
				d.message.emit(str(n), 0.8)
			if _t <= 0.0:
				phase = "fight"
				for f in _foes:
					if is_instance_valid(f):
						f.passive = false
				for a in _allies:
					if is_instance_valid(a):
						a.passive = false
				if is_instance_valid(_rival):
					_rival.passive = false
				if is_instance_valid(_pilot):
					_pilot.set_physics_process(true)
				d.message.emit("COMBAT !", 1.0)
		"between":
			if _t <= 0.0:
				Duel.round_n += 1
				_start_round()
	if phase == "fight" and _player_out:
		_follow_ally()
	if phase == "fight" and Duel.hazards and Duel.team_mode():
		_hazard_tick(delta)
	if phase == "fight" and _player_out and _all_down(_allies):
		_player_out = false
		Duel.losses += 1
		for f in _foes:
			if is_instance_valid(f):
				f.passive = true
		if is_instance_valid(_pilot):
			_pilot.set_physics_process(false)
			_pilot._pilot_bot.clear()
		_end_round(false)
	_obj_t -= delta
	if _obj_t <= 0.0:
		_obj_t = 0.25
		var vs := Duel.mode_title() if Duel.team_mode() else String(GameData.class_data(Duel.rival_class).get("name_fr", ""))
		d.objective_changed.emit("%s · manche %d · %d - %d" % [vs, Duel.round_n, Duel.wins, Duel.losses])


## Arène piégée (passe M7) : passé HAZARD_FIRST s de manche, toutes les HAZARD_EVERY s, une zone de feu par paire de
## héros debout (2 à 3) tombe près d'un héros tiré au sort ; HAZARD_DELAY s d'annonce, puis HAZARD_HIT des PV max à
## chaque héros dedans (tous camps, sans défense : le même danger pour tous), sauf s'il esquive.
const HAZARD_FIRST := 10.0
const HAZARD_EVERY := 8.0
const HAZARD_DELAY := 1.4
const HAZARD_RADIUS := 3.2
const HAZARD_HIT := 0.12
const HAZARD_COLOR := Color(0.78, 0.3, 1.0)  # violet : ni le rouge des coups, ni la couleur du sable
var _hazard_at := HAZARD_FIRST


func _fighters() -> Array:
	var out: Array = []
	for c in [d.player] + _allies + _foes + ([_foe] if is_instance_valid(_foe) else []):
		if is_instance_valid(c) and not c.is_dead and not c in out:
			out.append(c)
	return out


func _hazard_tick(_delta: float) -> void:
	if PvpCaps.elapsed < _hazard_at:
		return
	_hazard_at = PvpCaps.elapsed + HAZARD_EVERY
	var alive := _fighters()
	if alive.is_empty():
		return
	for i in clampi(alive.size() / 2, 1, 3):
		var who: Combatant = alive[randi() % alive.size()]
		var at: Vector3 = _ground(who.global_position + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)))
		var tg := Telegraph.spawn(d, at, 0.0, {"shape": "circle", "radius": HAZARD_RADIUS, "delay": HAZARD_DELAY, "damage": 0.0, "color": HAZARD_COLOR})
		tg.resolved.connect(func(_hit): _hazard_hit(tg))


func _hazard_hit(tg: Telegraph) -> void:
	if not is_instance_valid(tg) or phase != "fight":
		return
	for c in _fighters():
		if not tg.contains(c.global_position, c.radius):
			continue
		if c.has_method("is_invulnerable") and c.is_invulnerable():
			DamageNumber.spawn_text(c, "ESQUIVE", Color(0.7, 1.0, 0.7))
			continue
		c.take_damage(c.max_hp * HAZARD_HIT, null, false, true)


## K.O. du tableau de la manche.
func _note_ko(_who: Combatant, killer: Combatant) -> void:
	if phase == "fight" and killer != null and is_instance_valid(killer):
		PvpCaps.board_add(killer, "ko", 1)


## Le joueur est tombé, ses alliés se battent : la caméra suit le premier allié debout (spectateur jusqu'à la manche suivante).
func _follow_ally() -> void:
	if d.world.rig == null:
		return
	for a in _allies:
		if is_instance_valid(a) and not a.is_dead:
			if d.world.rig.target != a:
				d.world.rig.target = a
			return


func _on_rival_died(_who: Combatant, _killer: Combatant) -> void:
	if phase != "fight":
		return
	if not _all_down(_foes) or (is_instance_valid(_foe) and not _foe.is_dead):
		return  # il reste des adversaires debout (scriptés ou piloté par un cerveau)
	Duel.wins += 1
	_end_round(true)


## Le héros est tombé (world.gd) : manche perdue.
func player_down() -> void:
	if phase != "fight":
		return
	if not _allies.is_empty() and not _all_down(_allies):
		_player_out = true  # les alliés continuent ; la manche est perdue quand ils tombent aussi
		d.message.emit("Tu es tombé : tes alliés se battent encore !", 2.5)
		_follow_ally()
		return
	Duel.losses += 1
	for f in _foes:
		if is_instance_valid(f):
			f.passive = true
	if is_instance_valid(_rival):
		_rival.passive = true
	if is_instance_valid(_pilot):
		_pilot.set_physics_process(false)
		_pilot._pilot_bot.clear()
	_end_round(false)


func _end_round(won: bool) -> void:
	PvpCaps.round_times.append(snappedf(PvpCaps.elapsed, 0.1))
	if d.player.autoplay:
		print("[duel] manche %d %s en %.1f s (%s, %s)" % [Duel.round_n, "gagnée" if won else "perdue", PvpCaps.elapsed, Duel.mode, ClassRival.NAMES[Duel.difficulty]])
	if Duel.wins >= Duel.ROUNDS_TO_WIN or Duel.losses >= Duel.ROUNDS_TO_WIN:
		phase = "done"
		var victory := Duel.wins >= Duel.ROUNDS_TO_WIN
		d.message.emit("VICTOIRE !" if victory else "DÉFAITE…", 2.5)
		if d.player.autoplay:
			print("[duel] fin : %s %d - %d" % ["victoire" if victory else "défaite", Duel.wins, Duel.losses])
		d.get_tree().create_timer(2.5).timeout.connect(func(): d.world.duel_end(victory))
		return
	phase = "between"
	_t = BETWEEN_TEAM if Duel.team_mode() else BETWEEN  # en équipe : le temps de lire le tableau de la manche
	d.message.emit("Manche gagnée ! %d - %d" % [Duel.wins, Duel.losses] if won else "Manche perdue… %d - %d" % [Duel.wins, Duel.losses], 2.0)
