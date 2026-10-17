extends Combatant
## Tour ou Cœur du banc MB-0 (tools/moba_probe.gd) : immobile et indestructible (charge constante), tire sur le sbire ennemi
## le plus proche à portée, sinon sur le héros le plus proche (cible revue toutes les 0,25 s). Tir : trait du banc
## (moba_probe_bolt.gd). Dégâts (MOBA.md § 7.5) : tour = 10 % des PV d'un héros, mêlée en 2 tirs, tireur en 1 ; Cœur = 6 %,
## 2 tirs par seconde. Aucun class_name (banc).

var probe: Node
var side := 0
var is_core := false
var mb_kind := 4
var mb_side := 0
var range_m := 9.0
var period := 1.0
var _cd := 0.0
var _rt := 0.0
var _target: Combatant
var _practice := false


func _ready() -> void:
	team = Team.PLAYER if side == 0 else Team.MONSTER
	collision_layer = GameData.PHYS_PLAYER if side == 0 else GameData.PHYS_MONSTER
	collision_mask = 0
	# (hors des groupes « heroes » / « monsters » : Monster._separation suppose que tout le groupe « monsters » est un Monster ;
	# les coups des héros et des sbires du jeu, résolus par groupes, ne touchent donc pas les structures ; indestructibles ici)
	add_to_group("mb_towers")
	immortal = true
	radius = 3.0 if is_core else 2.0
	period = 0.5 if is_core else 1.0
	max_hp = 100000.0
	hp = max_hp
	display_name = ("Cœur " if is_core else "Tour ") + ("bleu" if side == 0 else "rouge")
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = radius
	cy.height = 8.0
	cs.shape = cy
	cs.position.y = 4.0
	add_child(cs)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.6
	cm.bottom_radius = radius
	cm.height = 8.0 if not is_core else 6.0
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.4, 0.55, 0.95) if side == 0 else Color(0.95, 0.4, 0.4)
	mi.material_override = m
	mi.position.y = cm.height * 0.5
	add_child(mi)
	_rt = randf() * 0.25


func _physics_process(delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	_cd -= delta
	_rt -= delta
	if _rt <= 0.0:
		_rt = 0.25
		_target = probe.tower_target(self)
		_practice = false
		if _target == null and probe.towers_busy:
			# banc --busy=1 : sans cible à portée, la tour tire quand même (à blanc) sur l'ennemi le plus proche à 45 m : les
			# 10 structures tirent en permanence (pire cas du coût des tours et des traits)
			_target = probe.tower_far_target(self)
			_practice = _target != null
	if _cd <= 0.0 and _target != null and is_instance_valid(_target) and not _target.is_dead:
		if _practice:
			probe.fire_bolt(self, _target, 0.0)
			probe.events.tower_practice += 1
			_cd = period
			probe.cost["tower"] += Time.get_ticks_usec() - t0
			return
		var reach := range_m + _target.radius
		if global_position.distance_squared_to(_target.global_position) <= reach * reach:
			var frac := 0.06 if is_core else 0.10
			if int(_target.get("mb_kind")) == 2:
				frac = 1.0 if bool(_target.get("ranged")) else 0.5
			probe.fire_bolt(self, _target, _target.max_hp * frac * (100.0 + maxf(_target.defense, 0.0)) / 100.0)
			probe.events.tower_shots += 1
			_cd = period
	probe.cost["tower"] += Time.get_ticks_usec() - t0
