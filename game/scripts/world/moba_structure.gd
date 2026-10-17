class_name MobaStructure
extends Combatant
## Tour ou Cœur des Deux Voies (lot MB-C, MOBA.md § 7.5, rapport R_MB_C.md). Immobile ; camp = ffa_id de son équipe (les
## coups des héros adverses la touchent par Combatant.ffa_foes), hors des groupes « heroes » / « monsters » (piège 7 de
## R_MB0 : Monster._separation suppose que tout le groupe « monsters » est un Monster). Cible choisie par le directeur
## (MobaDirector.tower_target, revue toutes les 0,25 s) : sbires d'abord, puis héros, et bascule sur le héros qui frappe un
## héros allié à portée ; tirs de suite sur un même héros de plus en plus forts (Moba.tower_streak).
##
## PV et dégâts en « points » : 100 points = une unité = une auto-attaque d'un héros de référence au niveau attendu à cet
## instant (MobaData.ref_auto) ; un sbire frappe en unités fixes (MobaData.MINIONS « struct »). Protections : sans sbire
## ennemi à 12 m, un tiers des dégâts ; T1 à moitié avant 4:00 ; T2 invulnérable tant que la T1 de sa voie tient ; Cœur
## invulnérable tant que ses deux T2 tiennent (et jusqu'à la Marée, lot MB-F).

const BAR_W := 3.2
const BAR_H := 0.34

var director: Node  # MobaDirector
var side := 0
var kind := "tower"  # « tower » | « core »
var lane := -1
var tier := 0
var range_m := 9.0
var period := 1.0
var target: Combatant
var shots := 0
var fell_at := -1.0
## Dégâts reçus par source (« hero », « minion ») en points : mesures.
var taken := {"hero": 0.0, "minion": 0.0}
var _cd := 0.0
var _rt := 0.0
var _streak_target: Combatant
var _streak := 0
var _streak_t := -100.0
var _visual: Node3D
var _gem: MeshInstance3D
var _bar: Node3D
var _fill: MeshInstance3D
var _ring: MeshInstance3D
var _msg_t := -10.0
var _hit_t := -100.0

static var _mesh_cache := {}


## À appeler avant add_child : [param s] camp, [param k] « tower » / « core », [param l] voie, [param tr] 1 (T1) / 2 (T2).
func setup(dir: Node, s: int, k: String, l := -1, tr := 0) -> void:
	director = dir
	side = s
	kind = k
	lane = l
	tier = tr


func _ready() -> void:
	team = Team.PLAYER if side == 0 else Team.MONSTER
	collision_layer = GameData.PHYS_WORLD  # (personne ne la traverse)
	collision_mask = 0
	set_ffa(TeamMatch.FFA_BASE + side)
	add_to_group("moba_structures")
	var core := kind == "core"
	var spec: Dictionary = MobaData.CORE if core else MobaData.TOWER
	radius = float(spec.radius)
	range_m = float(spec.range)
	period = float(spec.period)
	max_hp = Moba.structure_hp(kind, tier)
	hp = max_hp
	level = 1
	if core:
		display_name = "Cœur bleu" if side == 0 else "Cœur rouge"
	else:
		display_name = "Tour %d %s" % [tier, "bleue" if side == 0 else "rouge"]
	var cs := CollisionShape3D.new()
	var cy := CylinderShape3D.new()
	cy.radius = radius * 0.8
	cy.height = float(spec.height)
	cs.shape = cy
	cs.position.y = cy.height * 0.5
	add_child(cs)
	_build_visual()
	_build_bar()
	_build_ring()
	_rt = randf() * 0.25


# --- apparence ------------------------------------------------------------------------------------

func _team_color(tone := "base") -> Color:
	return TeamMatch.color(side, tone)


func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if c.a < 0.99:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Tour : la tour de guet d'Eden (décor ub018) ramenée à 7 m, une gemme de la couleur de l'équipe au sommet, son motif au sol.
## Cœur : socle de pierre d'encre et trois cristaux de la couleur de l'équipe.
func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var h := float((MobaData.CORE if kind == "core" else MobaData.TOWER).height)
	if kind == "tower":
		var parts := ProcMap.model_meshes("ub018")
		if not parts.is_empty():
			var box := AABB()
			var first := true
			for e in parts:
				var b: AABB = (e[1] as Transform3D) * (e[0] as Mesh).get_aabb()
				box = b if first else box.merge(b)
				first = false
			var k := h * 0.85 / maxf(box.size.y, 0.01)
			for e in parts:
				var mi := MeshInstance3D.new()
				mi.mesh = e[0]
				mi.transform = Transform3D(Basis().scaled(Vector3.ONE * k), Vector3(-box.get_center().x * k, -box.position.y * k, -box.get_center().z * k)) * (e[1] as Transform3D)
				_visual.add_child(mi)
		else:
			var body := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = radius * 0.6
			cm.bottom_radius = radius
			cm.height = h
			body.mesh = cm
			body.material_override = _mat(Color("c9bfa8"))
			body.position.y = h * 0.5
			_visual.add_child(body)
		_gem = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.75
		sm.height = 1.9
		sm.radial_segments = 4
		sm.rings = 2
		_gem.mesh = sm
		var gm := _mat(_team_color("clair"))
		gm.emission_enabled = true
		gm.emission = _team_color()
		gm.emission_energy_multiplier = 0.6
		_gem.material_override = gm
		_gem.position.y = h + 0.7
		_visual.add_child(_gem)
	else:
		var base := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius * 0.9
		cm.bottom_radius = radius * 1.1
		cm.height = 1.2
		cm.radial_segments = 8
		base.mesh = cm
		base.material_override = _mat(UiTheme.color("encre.500", Color("2e2450")))
		base.position.y = 0.6
		_visual.add_child(base)
		for i in 3:
			var c := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.9 if i == 0 else 0.6
			sm.height = h - 1.0 if i == 0 else h * 0.55
			sm.radial_segments = 5
			sm.rings = 2
			c.mesh = sm
			var gm := _mat(_team_color("clair" if i == 0 else "base"))
			gm.emission_enabled = true
			gm.emission = _team_color()
			gm.emission_energy_multiplier = 0.5
			c.material_override = gm
			var a := TAU * i / 3.0
			c.position = Vector3(cos(a), 0, sin(a)) * (0.0 if i == 0 else 1.1) + Vector3.UP * (1.2 + sm.height * 0.5)
			c.rotation.z = 0.0 if i == 0 else 0.25 * (1.0 if i == 1 else -1.0)
			_visual.add_child(c)
		_gem = _visual.get_child(1) as MeshInstance3D
	# motif de l'équipe au sol (rond Azur, carré Braise)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = radius + 0.6
	dm.bottom_radius = radius + 0.6
	dm.height = 0.03
	dm.radial_segments = 32 if side == 0 else 4
	disc.mesh = dm
	disc.material_override = _mat(Color(_team_color(), 0.55), true)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = 0.05
	if side == 1:
		disc.rotation.y = PI * 0.25
	_visual.add_child(disc)


## Barre de PV au-dessus (encre + pomme pour ton équipe, fraise pour l'autre ; jamais la couleur d'équipe, BIBLE § 3).
func _build_bar() -> void:
	_bar = Node3D.new()
	add_child(_bar)
	_bar.position.y = float((MobaData.CORE if kind == "core" else MobaData.TOWER).height) + 2.2
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(BAR_W + 0.16, BAR_H + 0.16)
	bg.mesh = q
	var bm := _mat(UiTheme.color("encre.700", Color("221a3a")), true)
	bm.no_depth_test = true
	bm.render_priority = 1
	bg.material_override = bm
	_bar.add_child(bg)
	_fill = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(BAR_W, BAR_H)
	fq.center_offset = Vector3(BAR_W * 0.5, 0, 0)
	_fill.mesh = fq
	var fm := _mat(UiTheme.color("bonbon.pomme.base") if side == TeamMatch.player_team else UiTheme.color("bonbon.fraise.base"), true)
	fm.no_depth_test = true
	fm.render_priority = 2
	_fill.material_override = fm
	_fill.position = Vector3(-BAR_W * 0.5, 0, 0.01)
	_bar.add_child(_fill)


## Anneau de portée (fraise), montré quand le héros du joueur approche d'une structure adverse.
func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = range_m - 0.15
	tm.outer_radius = range_m + 0.15
	tm.rings = 64
	_ring.mesh = tm
	_ring.material_override = _mat(Color(UiTheme.color("bonbon.fraise.base"), 0.55), true)
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.position.y = 0.08
	_ring.visible = false
	add_child(_ring)


func _process(_delta: float) -> void:
	if _bar == null or not _bar.visible:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		_bar.global_basis = cam.global_basis
	_fill.scale.x = clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)


# --- règles ---------------------------------------------------------------------------------------

## Invulnérable : T2 tant que la T1 de sa voie tient ; Cœur tant que ses deux T2 tiennent (et avant la Marée).
func invulnerable() -> bool:
	if is_dead:
		return true
	if kind == "tower":
		return tier == 2 and director.structure_alive(side, lane, 1)
	return Moba.t < MobaData.TIDE_AT and director.structure_alive(side, 0, 2) and director.structure_alive(side, 1, 2)


## Coup en unités (un sbire, un trait de tireur).
func take_units(units: float, source: Combatant = null) -> void:
	if is_dead:
		return
	var d := Moba.structure_damage(units, kind, tier, director.minion_near(self), invulnerable(), Moba.t)
	taken.minion += d
	_apply(d, source, false)


## Coup d'un héros (ou d'un effet) : converti en unités par l'auto-attaque du héros de référence du moment.
func take_damage(amount: float, source: Combatant = null, crit := false, dot := false) -> void:
	if is_dead:
		return
	if source is MobaMinion:
		take_units((source as MobaMinion).struct_units, source)
		return
	var units := amount / MobaData.ref_auto(Moba.t)
	var inv := invulnerable()
	var near: bool = director.minion_near(self)
	var d := Moba.structure_damage(units, kind, tier, near, inv, Moba.t)
	taken.hero += d
	if source != null and is_instance_valid(source) and source == director.player and Moba.t - _msg_t > 2.0:
		if inv:
			_msg_t = Moba.t
			DamageNumber.spawn_text(self, "INVULNÉRABLE", Color(0.8, 0.85, 1.0))
		elif not near:
			_msg_t = Moba.t
			DamageNumber.spawn_text(self, "PROTÉGÉE", Color(0.8, 0.85, 1.0))
	if d > 0.0 and not dot:
		DamageNumber.spawn(self, d, crit, team == Team.PLAYER, dot, false)
	_apply(d, source, dot)


func _apply(d: float, source: Combatant, _dot: bool) -> void:
	if d <= 0.0:
		return
	_hit_t = Moba.t
	hp = maxf(0.0, hp - d)
	health_changed.emit(hp, max_hp)
	damaged.emit(d, source)
	if hp <= 0.0:
		is_dead = true
		_on_death(source)
		died.emit(self, source)


func _on_death(killer: Combatant) -> void:
	fell_at = Moba.t
	target = null
	clear_ffa()
	remove_from_group("moba_structures")
	collision_layer = 0
	_bar.visible = false
	_ring.visible = false
	# effondrement : la gemme tombe, la tour penche et se ternit
	var tw := create_tween()
	if _gem:
		tw.tween_property(_gem, "position:y", 0.6, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_visual, "rotation:z", 0.35 * (1.0 if side == 0 else -1.0), 0.7).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_visual, "position:y", -1.6, 0.9)
	for c in _visual.find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).transparency = 0.25
	Vfx.shockwave(self, global_position, 6.0, _team_color())
	director.on_structure_down(self, killer)


## Réparation hors combat (lot MB-C, mesures R_MB_C § 3) : sans coup reçu depuis MobaData.REPAIR_DELAY s, une structure
## regagne MobaData.REPAIR unités par seconde, jusqu'au haut du tiers de PV où elle se trouve : un sbire égaré ne l'use pas
## à la longue, une poussée tenue gagne des tiers pour de bon.
func _repair(delta: float) -> void:
	if hp >= max_hp or Moba.t - _hit_t < MobaData.REPAIR_DELAY:
		return
	var cap := ceilf(hp / max_hp * 3.0 - 0.0001) / 3.0 * max_hp
	if hp < cap:
		hp = minf(cap, hp + Moba.tune("repair", MobaData.REPAIR) * 100.0 * delta)
		health_changed.emit(hp, max_hp)


func _physics_process(delta: float) -> void:
	if is_dead or director == null:
		return
	_repair(delta)
	_cd -= delta
	_rt -= delta
	if _rt <= 0.0:
		_rt = 0.25
		target = director.tower_target(self, target)
		var p: Combatant = director.player
		_ring.visible = p != null and is_instance_valid(p) and not p.is_dead and director.side_of(p) != side \
			and p.global_position.distance_to(global_position) < range_m + 7.0
	if _cd > 0.0 or target == null or not is_instance_valid(target) or target.is_dead:
		return
	var reach := range_m + target.radius
	if global_position.distance_squared_to(target.global_position) > reach * reach:
		return
	_cd = period
	shots += 1
	var dmg := 0.0
	if target is MobaMinion:
		# part des PV d'un sbire ordinaire du moment (un sbire renforcé, × 1,2, tient plus de tirs : sa poussée compte)
		var mk := (target as MobaMinion).kind
		dmg = float(MobaData.minion_stats(mk, Moba.t).hp) * float(MobaData.MINIONS[mk].tower) * Moba.tune("tower_minion", 1.0)
	else:
		if target == _streak_target and Moba.t - _streak_t < float(MobaData.TOWER.streak_reset):
			_streak += 1
		else:
			_streak = 1
		_streak_target = target
		_streak_t = Moba.t
		var frac := float((MobaData.CORE if kind == "core" else MobaData.TOWER).hero_shot)
		dmg = target.max_hp * frac * (100.0 + maxf(target.defense, 0.0)) / 100.0 * Moba.tower_streak(_streak)
	var top := global_position + Vector3.UP * (float((MobaData.CORE if kind == "core" else MobaData.TOWER).height) + 0.6)
	director.fire_bolt(self, target, dmg, top, "tower")
