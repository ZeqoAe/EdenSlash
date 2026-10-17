class_name AssaultGadgets
extends Node3D
## Utilitaires et fioles de L'Assaut (lot TAC-5, étude TACTIQUE § 7.4, rapport R_TAC_5.md) : un nœud par objet lancé ou posé,
## dessiné au sol comme les sorts (zones annoncées, couleurs de la bible : brume lilas, feu mandarine, éclats fraise, révélation
## améthyste, glace lagon), jamais masqué par les réglages d'effets. Effets chiffrés de l'étude, fixes (ce sont des objets, pas
## des sorts de classe : les règles de contrôle du mode ne les réduisent pas, l'insensibilité commune les arrête).
##
##   AssaultGadgets.use(directeur, héros, "brume", point)   # lance ou pose ; vrai si l'objet a servi
##   AssaultGadgets.drink(directeur, héros, "soin")          # fiole bue
## Le directeur retire la charge de l'inventaire (AssaultItems) quand use / drink rendent vrai.

const RANGE := 14.0  # portée d'un lancer (m)
const KINDS := ["brume", "eclat", "feu", "bombe", "chouette", "clochette", "piege", "barricade", "leurre", "silence"]

var kind := ""
var dir: Node  # AssaultDirector
var owner_c: Combatant
var team := -1
var t := 0.0
var life := 1.0
var _done := false
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _hit: Dictionary = {}  # id -> vrai (une fois par cible)
var _body: StaticBody3D


## Lance (ou pose, pour la clochette, le piège, la poudre et le leurre) l'utilitaire [param id] de [param who] vers [param at].
static func use(d: Node, who: Combatant, id: String, at: Vector3) -> bool:
	if who == null or who.is_dead or not id in KINDS:
		return false
	var from := who.global_position
	var to := at
	if id in ["clochette", "piege", "silence", "leurre"]:
		to = from
	else:
		var v := Vector3(to.x - from.x, 0, to.z - from.z)
		if v.length() > RANGE:
			to = from + v.normalized() * RANGE
		if AssaultVision.active() and AssaultVision.blocks_shot(from, to):
			to = _stop_short(from, to)  # (un mur arrête le lancer : l'objet tombe devant)
	if d.has_method("_ground"):
		to = d.call("_ground", to)
	var g := AssaultGadgets.new()
	g.kind = id
	g.dir = d
	g.owner_c = who
	g.team = TeamMatch.team_of(who)
	d.add_child(g)
	g.global_position = to
	g._start()
	if AssaultVision.active() and id != "silence":
		AssaultVision.current.noise(from, "fight", g.team, 10.0, who)  # (on entend un lancer de près)
	return true


static func _stop_short(a: Vector3, b: Vector3) -> Vector3:
	var p := a
	var step := (b - a) / 14.0
	for i in 14:
		if AssaultVision.blocks_shot(a, p + step):
			return p
		p += step
	return p


## Fiole [param id] bue par [param who] : soin (30 % en 2 s, annulée par un coup de plus de 5 %), hâte, garde, clarté.
static func drink(d: Node, who: Combatant, id: String) -> bool:
	if who == null or who.is_dead:
		return false
	match id:
		"soin":
			who.set_meta("assault_potion", {"left": 2.0, "hp": who.hp, "per_s": who.max_hp * 0.15})
		"hate":
			who.statuses["haste"] = who.clock + 6.0
			who.statuses_changed.emit()
			if who is Player:
				(who as Player).recalc_stats()
		"garde":
			who.statuses["assault_guard"] = who.clock + 4.0
			who.statuses_changed.emit()
		"clarte":
			for s in AssaultCombat.HARD + ["disarm", "chill"]:
				who.statuses.erase(s)
			who.statuses["imm_cc"] = who.clock + 2.0
			if who is Player and (who as Player)._state == "stun":
				(who as Player)._stun_len = 0.0
			who.statuses_changed.emit()
		_:
			return false
	Vfx.ring(who, who.global_position, 1.8, Color(UiTheme.color("bonbon.pomme.base"), 0.9))
	return true


## Fiole de soin en cours (le directeur l'appelle à chaque image) : rend la vie peu à peu, s'arrête à un coup de plus de 5 %.
static func tick_potion(who: Combatant, delta: float) -> void:
	if who == null or not who.has_meta("assault_potion") or who.is_dead:
		return
	var p: Dictionary = who.get_meta("assault_potion")
	if who.hp < float(p.hp) - who.max_hp * 0.05:
		who.remove_meta("assault_potion")  # un coup l'interrompt
		DamageNumber.spawn_text(who, "INTERROMPUE", UiTheme.color("bonbon.fraise.base"))
		return
	var amt := AssaultCombat.heal_amount(who, float(p.per_s) * delta)  # (le plafond de soins de la manche compte)
	who.hp = minf(who.max_hp, who.hp + amt)
	who.health_changed.emit(who.hp, who.max_hp)
	p.hp = who.hp
	p.left = float(p.left) - delta
	if float(p.left) <= 0.0:
		who.remove_meta("assault_potion")


func _start() -> void:
	name = "Gadget_" + kind
	match kind:
		"brume":
			life = 10.0
			_disc(5.0, Color(UiTheme.color("bonbon.amethyste.clair", Color("e2b6ff")), 0.55), 2.2)
			if AssaultVision.active():
				AssaultVision.current.smokes.append({"pos": Vector2(global_position.x, global_position.z), "r": 5.0,
					"until": AssaultVision.current.time + life})
		"eclat":
			life = 0.9
			_disc(0.6, Color(1, 1, 1, 0.9), 0.4)
		"feu":
			life = 6.0
			_disc(4.0, Color(UiTheme.color("bonbon.mandarine.base"), 0.45), 0.08)
		"bombe":
			life = 0.8
			Telegraph.spawn(self, global_position, 0.0, {"shape": "circle", "radius": 5.0, "delay": 0.8, "damage": 0.0})
		"chouette":
			life = 3.0
			_disc(12.0, Color(UiTheme.color("bonbon.amethyste.base"), 0.18), 0.05)
			_reveal_around(12.0, 3.0)
		"clochette":
			life = 60.0
			_disc(0.45, UiTheme.color("bonbon.soleil.base"), 0.5)
		"piege":
			life = 60.0
			_disc(0.7, Color(UiTheme.color("encre.700", Color("3b2f5a")), 0.9), 0.06)
		"barricade":
			life = 12.0
			_wall()
		"leurre":
			life = 4.0
			_disc(0.5, Color(TeamMatch.color(team), 0.8), 1.7)
		"silence":
			life = 6.0
			if owner_c != null:
				owner_c.statuses["silent"] = owner_c.clock + 6.0
			queue_free()


func _disc(r: float, col: Color, h: float) -> void:
	_mesh = MeshInstance3D.new()
	var m: Mesh
	if h >= 0.3:
		var s := SphereMesh.new()
		s.radius = r
		s.height = h * 2.0 if h < r else r * 2.0
		m = s
	else:
		var c := CylinderMesh.new()
		c.top_radius = r
		c.bottom_radius = r
		c.height = maxf(h, 0.04)
		m = c
	_mesh.mesh = m
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = col
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.position.y = minf(h, r) * 0.5 if h >= 0.3 else 0.05
	add_child(_mesh)


## Barricade de glace : mur de 4 × 2 m face au lanceur, qui arrête passage (PHYS_WORLD), vue (SIGHT) et coups (SHOT).
func _wall() -> void:
	_body = StaticBody3D.new()
	_body.collision_layer = GameData.PHYS_WORLD | AssaultMap.SIGHT | AssaultMap.SHOT
	_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(4.0, 2.0, 0.6)
	cs.shape = bx
	cs.position.y = 1.0
	_body.add_child(cs)
	add_child(_body)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bx.size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(UiTheme.color("bonbon.lagon.clair", Color("9be3ff")), 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.position.y = 1.0
	_body.add_child(mi)
	if owner_c != null:
		var f := global_position - owner_c.global_position
		f.y = 0.0
		if f.length() > 0.1:
			rotation.y = atan2(f.x, f.z)


func _foes() -> Array:
	var out: Array = []
	for k in dir.heroes:
		var h = dir.call("hero", String(k))
		if h != null and not (h as Combatant).is_dead and TeamMatch.team_of(h) != team:
			out.append(h)
	return out


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _reveal_around(r: float, secs: float) -> void:
	if not AssaultVision.active() or team < 0:
		return
	for f in _foes():
		if _flat((f as Node3D).global_position, global_position) <= r:
			AssaultVision.current.reveal(team, f, secs, owner_c)


func _physics_process(delta: float) -> void:
	t += delta
	match kind:
		"eclat":
			if t >= 0.6 and not _done:
				_done = true
				_blind()
		"feu":
			for f in _foes():
				var c := f as Combatant
				if _flat(c.global_position, global_position) <= 4.0:
					var id := c.get_instance_id()
					var acc := float(_hit.get(id, 0.0)) + delta
					if acc >= 0.5:
						acc -= 0.5
						c.take_damage(c._burst_limit(c.max_hp * 0.03), null, false, true)  # 6 % des PV max par seconde (dans la rafale du JcJ)
					_hit[id] = acc
		"bombe":
			if t >= 0.8 and not _done:
				_done = true
				Vfx.shockwave(self, global_position, 5.0, UiTheme.color("bonbon.fraise.base"))
				for f in _foes():
					var c := f as Combatant
					if _flat(c.global_position, global_position) <= 5.0 and not AssaultVision.blocks_shot(global_position, c.global_position):
						c.take_damage(c._burst_limit(c.max_hp * 0.25), null, false, true)  # (compte dans la rafale : jamais à terre en un instant)
		"clochette", "piege":
			for f in _foes():
				var c := f as Combatant
				var reach := 5.0 if kind == "clochette" else 1.2
				if _flat(c.global_position, global_position) <= reach:
					_trigger(c)
					return
			if kind == "piege" and _mesh != null:
				_mesh.visible = _seen_by_viewer()
		"leurre":
			global_position += _decoy_dir() * 6.5 * delta
			if AssaultVision.active() and fmod(t, 0.5) < delta:
				AssaultVision.current.noise(global_position, "steps", team, -1.0, null)
	if _mat != null and kind in ["brume", "feu", "chouette"]:
		_mat.albedo_color.a = minf(_mat.albedo_color.a, clampf((life - t) / 1.0, 0.0, 1.0) * 0.6)
	if t >= life:
		queue_free()


var _ddir := Vector3.ZERO


func _decoy_dir() -> Vector3:
	if _ddir == Vector3.ZERO:
		_ddir = owner_c.forward() if owner_c != null and is_instance_valid(owner_c) else Vector3.FORWARD
		_ddir.y = 0.0
		_ddir = _ddir.normalized()
	return _ddir


## Le piège ne se voit qu'à moins de 4 m (pour l'autre équipe) : l'équipe du poseur le voit toujours.
func _seen_by_viewer() -> bool:
	var v = dir.call("view_hero") if dir.has_method("view_hero") else null
	if v == null:
		return true
	return TeamMatch.team_of(v) == team or _flat((v as Node3D).global_position, global_position) <= 4.0


func _trigger(c: Combatant) -> void:
	if AssaultVision.active() and team >= 0:
		AssaultVision.current.reveal(team, c, 2.0, owner_c)
		AssaultVision.current.noise(global_position, "fight", 1 - team, INF, c)
	if kind == "piege":
		if AssaultCombat.cc_gate(c, "root", 0.8):
			if c is Player:
				(c as Player).stun(0.8)
			else:
				c.statuses["root"] = c.clock + 0.8
			c.statuses_changed.emit()
	if dir.has_method("gadget_alarm"):
		dir.call("gadget_alarm", kind, c, team)
	queue_free()


## Éclat aveuglant : tout héros à moins de 12 m qui le voit (ligne de vue) et lui fait face est ébloui 1,2 s.
func _blind() -> void:
	Vfx.flash(self, global_position + Vector3.UP * 1.0, 6.0, Color.WHITE)
	for k in dir.heroes:
		var h = dir.call("hero", String(k))
		if h == null or (h as Combatant).is_dead:
			continue
		var c := h as Combatant
		var d := _flat(c.global_position, global_position)
		if d > 12.0:
			continue
		if AssaultVision.active() and not AssaultVision.current.los(c.global_position, global_position):
			continue
		var to := global_position - c.global_position
		to.y = 0.0
		if d > 1.5 and c.forward().dot(to.normalized()) < 0.0:
			continue  # dos tourné : évité
		c.statuses["blind"] = c.clock + 1.2
		c.statuses_changed.emit()
		if dir.has_method("gadget_blind"):
			dir.call("gadget_blind", c)
