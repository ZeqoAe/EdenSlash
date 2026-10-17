class_name NinjaArts
extends RefCounted
## Sorts du Ninja du Tourbillon (classe maison n° 61, lot CHR-1 ; data/classes_custom.json, rapport conception/art/R_CHR1.md).
## Trois formes de sort nouvelles, lancées par Player comme les autres (recharge, cartes, enchaînements) :
##   clone : « Double de brume » : signe des mains (pose procédurale ProcPose), fumée, puis N doubles du héros (ClassRival
##           alliés, sans sort : taï-jutsu seul) qui frappent et attirent les coups pendant [code]duration[/code] s, puis
##           disparaissent en fumée ;
##   orb   : « Sphère tourbillon » : la sphère se forme dans la main tendue pendant l'élan (dash), puis broie ce qui est
##           devant (ticks qui retiennent) et éclate (onde qui renverse) ;
##   ult   : « Étoile du Tourbillon » : charge bras levé (temps de charge [code]hold[/code] en plus, caméra qui se
##           rapproche), puis une étoile-sphère géante part droit devant, tranche ce qu'elle frôle, explose sur le premier
##           adversaire touché de plein fouet ou au point visé (dôme, ondes, lames de vent), laisse un tourbillon bref.
## « Étoiles filantes » est un sort « bolt » ordinaire (projectile « shuriken » dessiné ici, HeroBolt).
## Dégâts : toujours par Player._hit_monster (critiques, cartes, effets, journal), en part de [code]action.mult[/code].
## Aucun effet sur les 60 autres classes : seules les formes de KINDS passent ici.

const KINDS := ["clone", "orb", "ult"]
const SWIRL := preload("res://shaders/swirl_orb.gdshader")
## Parts de action.mult (réglages mesurés : conception/art/R_CHR1.md § Équilibre).
const ORB_TICKS := 6
const ORB_TICK := 0.4
const ORB_BURST := 2.2
const ULT_PATH := 0.45
const ULT_BLAST := 5.5
const ULT_VORTEX := 0.35
const ULT_SPEED := 15.0
## Doubles : PV (part des PV max du héros) et attaque (part de sa puissance × action.mult).
const CLONE_HP := 0.25
const CLONE_ATK := 1.6


static func handles(kind: String) -> bool:
	return kind in KINDS


# --- lancement (Player._cast_skill, après _begin_action) --------------------------------------------------
static func on_cast(p: Player, s: Dictionary, action: Dictionary, aim := Vector3.INF) -> void:
	var t_hit: float = p._hits[0] if not p._hits.is_empty() else 0.4
	match String(s.get("kind", "")):
		"clone":
			action["clones"] = int(s.get("clones", 2))
			action["duration"] = float(s.get("duration", 6.0))
			_pose(p, "seal", t_hit + 0.1)
			smoke(p, p.global_position + Vector3.UP * 1.1 + p.forward() * 0.4, 0.5)
		"orb":
			_pose(p, "hold_front", t_hit)
			action["_vis"] = HandFx.make(p, "Bip01 R Hand", Vector3(0, 0.05, 0) , 0.32, t_hit, false)
		"ult":
			# point visé (dans la portée, au moins 5 m) : l'étoile y éclate si elle n'a rien touché avant
			var to := (aim - p.global_position) if aim != Vector3.INF else p.forward() * float(action.get("range", 14.0))
			to.y = 0.0
			action["burst_at"] = clampf(to.length(), 5.0, maxf(float(action.get("range", 14.0)), 5.0))
			var hold := float(s.get("hold", 0.8))
			for i in p._hits.size():
				p._hits[i] = float(p._hits[i]) + hold
			p._state_len += hold
			p._skill_lock_until += hold
			t_hit += hold
			_pose(p, "raise", t_hit)
			ClassPremium.play_ult(p, t_hit)  # « Héros détaillé » : charge bras levés puis lancer (animations neuves)
			action["_vis"] = HandFx.make(p, "Bip01 R Hand", Vector3(0, 0.95, 0), 0.62, t_hit, true)
			_camera_punch(p, t_hit)
			p._shake(0.25)


# --- impact (Player._resolve_hit) -------------------------------------------------------------------------
static func resolve(p: Player, action: Dictionary) -> void:
	var vis = action.get("_vis")
	match String(action.get("kind", "")):
		"clone":
			var n := int(action.get("clones", 2))
			for i in n:
				var side := (float(i) - (n - 1) * 0.5) * 1.6
				var at := p.global_position + p.forward() * 1.2 + p.forward().cross(Vector3.UP) * side
				spawn_clone(p, at, float(action.get("duration", 6.0)), float(action.mult))
		"orb":
			if vis is HandFx and is_instance_valid(vis):
				(vis as HandFx).queue_free()
			var o := OrbStrike.new()
			o.p = p
			o.action = action.duplicate()
			p.get_tree().current_scene.add_child(o)
			o.global_position = p.global_position + p.forward() * 1.3 + Vector3.UP * 1.0
		"ult":
			var r := RasenStar.new()
			r.p = p
			r.action = action.duplicate()
			r.dir = p.forward()
			r.max_range = float(action.get("burst_at", action.get("range", 14.0)))
			p.get_tree().current_scene.add_child(r)
			r.global_position = p.global_position + p.forward() * 1.0 + Vector3.UP * 1.4
			if vis is HandFx and is_instance_valid(vis):
				(vis as HandFx).queue_free()
			p._shake(0.5)


## Touche tous les adversaires de [param p] à [param radius] m de [param at] ; [param mult] en part de l'action ;
## [param pull] > 0 : attirés vers le centre (vortex). Renvoie le nombre de touchés.
static func hit_area(p: Player, action: Dictionary, at: Vector3, radius: float, mult: float, pull := 0.0, applies := {}) -> int:
	if not is_instance_valid(p) or p.is_dead:
		return 0
	var a := action.duplicate()
	a.erase("_vis")
	a["mult"] = float(action.get("mult", 1.0)) * mult
	a["pull"] = pull
	a["applies"] = applies
	a["fx_count"] = 2  # une seule gerbe d'Eden par vague (lisibilité)
	var n := 0
	for node in p.foes():
		var m := node as Combatant
		if m == null or m.is_dead or not is_instance_valid(m):
			continue
		var to := m.global_position - at
		to.y = 0.0
		if to.length() - m.radius > radius:
			continue
		p._hit_monster(m, to.normalized() if to.length() > 0.05 else p.forward(), a, true)
		n += 1
	if n > 0:
		p._last_combat = p._time
	return n


# --- doubles ----------------------------------------------------------------------------------------------
## Un double de brume : un héros scripté allié de la classe du joueur (taï-jutsu seul), qui vit [param life] s.
static func spawn_clone(p: Player, at: Vector3, life: float, mult: float) -> ClassRival:
	var c := ClassRival.new()
	c.ally = true
	c.setup(p.class_id, p.stat_level(), 2, 1.0, 0)
	c.max_hp = p.max_hp * CLONE_HP
	c.hp = c.max_hp
	c.atk = p.power() * mult * CLONE_ATK
	c.defense = p.defense
	c.crit_chance = p.crit
	c.crit_bonus = p.crit_dmg
	c.display_name = "Double de brume"
	c.set_meta("mist_double", true)
	p.get_parent().add_child(c)
	c.remove_from_group("allies")  # ni barre d'équipe, ni étoile « personne ne tombe » des donjons
	c.global_position = at
	smoke(p, at + Vector3.UP * 0.9, 0.9)
	c.died.connect(func(_w, _k): smoke(p, c.global_position + Vector3.UP * 0.9, 0.8))
	p.get_tree().create_timer(life, false).timeout.connect(func():
		if is_instance_valid(c) and not c.is_dead:
			smoke(c, c.global_position + Vector3.UP * 0.9, 0.9)
			c.queue_free())
	return c


## Le héros [param c] est-il un double de brume ?
static func is_double(c: Node) -> bool:
	return c != null and c.has_meta("mist_double")


# --- effets -----------------------------------------------------------------------------------------------
## Bouffée de fumée blanche (apparition, disparition d'un double, signe des mains).
static func smoke(host: Node, pos: Vector3, size := 1.0) -> void:
	if Vfx.silent or host == null or not host.is_inside_tree() or Settings.fx_particles() == "off":
		return
	var ps := CPUParticles3D.new()
	ps.one_shot = true
	ps.emitting = false
	ps.amount = 22 if Settings.fx_particles() != "reduced" else 10
	ps.lifetime = 0.75
	ps.explosiveness = 0.92
	ps.direction = Vector3.UP
	ps.spread = 180.0
	ps.initial_velocity_min = 1.2 * size
	ps.initial_velocity_max = 3.2 * size
	ps.damping_min = 3.0
	ps.damping_max = 5.0
	ps.gravity = Vector3(0, 0.8, 0)
	ps.scale_amount_min = 0.7
	ps.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.45))
	curve.add_point(Vector2(1.0, 1.7))
	ps.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.85))
	ramp.set_color(1, Color(0.82, 0.86, 0.95, 0.0))
	ps.color_ramp = ramp
	var q := QuadMesh.new()
	q.size = Vector2.ONE * 1.0 * size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Vfx._radial()
	m.disable_fog = true
	q.material = m
	ps.mesh = q
	host.get_tree().current_scene.add_child(ps)
	ps.global_position = pos
	ps.emitting = true
	host.get_tree().create_timer(1.2, false).timeout.connect(ps.queue_free)


## Sphère au shader tourbillon (rayon 1, à mettre à l'échelle) ; [param col] : couleur des bandes.
static func swirl_sphere(col := Color(0.2, 0.55, 1.0), arms := 5.0, spin := 6.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	mi.mesh = sm
	var mat := ShaderMaterial.new()
	mat.shader = SWIRL
	mat.set_shader_parameter("swirl_color", Vector3(col.r, col.g, col.b))
	mat.set_shader_parameter("arms", arms)
	mat.set_shader_parameter("spin", spin)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static var _star_mesh: ArrayMesh
static var _blade_mesh: ArrayMesh


## Étoile de lancer à 4 branches, plate (plan XZ), rayon 1 : acier, liseré clair, trou au centre.
static func star_mesh() -> ArrayMesh:
	if _star_mesh:
		return _star_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	for i in 8:
		var a := TAU * float(i) / 8.0
		var r := 1.0 if i % 2 == 0 else 0.3
		pts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
	var hole := 0.1
	for i in 8:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % 8]
		var ia := a.normalized() * hole
		var ib := b.normalized() * hole
		var ca := Color(0.92, 0.95, 1.0) if i % 2 == 0 else Color(0.45, 0.5, 0.6)
		var cb := Color(0.45, 0.5, 0.6) if i % 2 == 0 else Color(0.92, 0.95, 1.0)
		for tri in [[ia, a, b], [ia, b, ib]]:
			for k in 3:
				var v: Vector3 = tri[k]
				st.set_color(Color(0.3, 0.33, 0.42) if v.length() < 0.2 else (ca if v == a else (cb if v == b else Color(0.6, 0.65, 0.75))))
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
	_star_mesh = st.commit()
	return _star_mesh


## Quatre lames de vent courbes (plan XZ, rayon 1) : l'anneau de l'Étoile du Tourbillon.
static func blade_mesh() -> ArrayMesh:
	if _blade_mesh:
		return _blade_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 4:
		var a0 := TAU * float(b) / 4.0
		var segs := 10
		for i in segs:
			var t0 := float(i) / segs
			var t1 := float(i + 1) / segs
			# lame en croissant : large à la base (près du cœur), effilée au bout, recourbée vers l'arrière
			var w0 := 0.34 * (1.0 - t0)
			var w1 := 0.34 * (1.0 - t1)
			var r0 := 0.3 + 0.7 * t0
			var r1 := 0.3 + 0.7 * t1
			var g0 := a0 + t0 * 0.9
			var g1 := a0 + t1 * 0.9
			var p0a := Vector3(cos(g0), 0, sin(g0)) * r0
			var p0b := Vector3(cos(g0 - w0), 0, sin(g0 - w0)) * (r0 * 0.82)
			var p1a := Vector3(cos(g1), 0, sin(g1)) * r1
			var p1b := Vector3(cos(g1 - w1), 0, sin(g1 - w1)) * (r1 * 0.82)
			var ca := Color(1, 1, 1, 0.95 * (1.0 - t0 * 0.6))
			var cb := Color(0.55, 0.85, 1.0, 0.5 * (1.0 - t0))
			for tri in [[p0a, p1a, p1b], [p0a, p1b, p0b]]:
				for v: Vector3 in tri:
					st.set_color(ca if v == p0a or v == p1a else cb)
					st.set_normal(Vector3.UP)
					st.add_vertex(v)
	_blade_mesh = st.commit()
	return _blade_mesh


static func _glow_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	return m


## Étoile de lancer pour HeroBolt (style « shuriken »).
static func shuriken_node() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = star_mesh()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_fog = true
	mi.material_override = m
	mi.scale = Vector3.ONE * 0.55
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _pose(p: Player, name: String, duration: float) -> void:
	if p.model == null:
		return
	var pp := ProcPose.on(p.model)
	if pp:
		pp.hold(name, duration)


## Caméra qui se rapproche pendant la charge de l'ultime, puis revient (joueur seulement, jamais en duel ni pilote).
static func _camera_punch(p: Player, t: float) -> void:
	if p.foe or p.bot != null or p.autoplay or Duel.active or TeamMatch.active:
		return
	var cam := p.get_viewport().get_camera_3d() if p.get_viewport() else null
	var rig := cam.get_parent() as CameraRig if cam else null
	if rig == null:
		return
	var d0 := rig.distance
	var tw := rig.create_tween()
	tw.tween_property(rig, "distance", d0 * 0.78, maxf(t * 0.8, 0.15)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(t * 0.2, 0.05) + 0.35)
	tw.tween_property(rig, "distance", d0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# --- nœuds d'effet ----------------------------------------------------------------------------------------
## Sphère qui suit la main du héros (charge) et grossit jusqu'à [member size] en [member grow] s ; [member star] :
## avec l'anneau de lames (ultime).
class HandFx extends Node3D:
	var target: Node3D
	var p: Player
	var offset := Vector3.ZERO
	var size := 0.3
	var grow := 0.4
	var star := false
	var _t := 0.0
	var _core: MeshInstance3D
	var _ring: MeshInstance3D

	static func make(pl: Player, bone: String, off: Vector3, sz: float, g: float, with_star: bool) -> HandFx:
		var h := HandFx.new()
		h.p = pl
		h.offset = off
		h.size = sz
		h.grow = maxf(g, 0.1)
		h.star = with_star
		var sk := pl.model.find_child("Skeleton3D", true, false) as Skeleton3D if pl.model else null
		if sk and sk.find_bone(bone) >= 0:
			var att := BoneAttachment3D.new()
			att.bone_name = bone
			sk.add_child(att)
			h.target = att
		pl.get_tree().current_scene.add_child(h)
		return h

	func _ready() -> void:
		top_level = true
		_core = NinjaArts.swirl_sphere()
		add_child(_core)
		if star:
			_ring = MeshInstance3D.new()
			_ring.mesh = NinjaArts.blade_mesh()
			_ring.material_override = NinjaArts._glow_material()
			_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_ring)
		_follow()
		_scale(0.05)

	func _scale(k: float) -> void:
		_core.scale = Vector3.ONE * size * k
		if _ring:
			_ring.scale = Vector3.ONE * size * 3.2 * k

	func _follow() -> void:
		if is_instance_valid(target):
			global_position = target.global_position + offset
		elif is_instance_valid(p):
			global_position = p.global_position + Vector3.UP * 1.2 + offset

	func _process(delta: float) -> void:
		_t += delta
		if not is_instance_valid(p) or p.is_dead or _t > grow + 1.5:
			queue_free()
			return
		_follow()
		var k := clampf(_t / grow, 0.0, 1.0)
		_scale(0.15 + 0.85 * k * k * (3.0 - 2.0 * k) + 0.04 * sin(_t * 30.0))
		if _ring:
			_ring.rotation.y -= delta * (8.0 + 14.0 * k)

	func _exit_tree() -> void:
		if is_instance_valid(target):
			target.queue_free()


## Sphère tourbillon posée devant le héros : broie (ticks qui retiennent), puis éclate.
class OrbStrike extends Node3D:
	var p: Player
	var action: Dictionary
	var _t := 0.0
	var _ticks := 0
	var _burst := false
	var _core: MeshInstance3D
	var _wave: MeshInstance3D

	func _ready() -> void:
		_core = NinjaArts.swirl_sphere(Color(0.2, 0.55, 1.0), 6.0, 10.0)
		_core.scale = Vector3.ONE * 0.55
		add_child(_core)
		Vfx.flash(self, global_position, 1.6, Color(0.6, 0.85, 1.0))

	func _physics_process(delta: float) -> void:
		_t += delta
		if not is_instance_valid(p):
			queue_free()
			return
		var pulse := 0.55 + 0.08 * sin(_t * 40.0)
		if not _burst:
			_core.scale = Vector3.ONE * pulse
			_core.rotation.y += delta * 12.0
			if _ticks < NinjaArts.ORB_TICKS and _t >= 0.1 * _ticks:
				_ticks += 1
				NinjaArts.hit_area(p, action, global_position, 1.9, NinjaArts.ORB_TICK, 0.25)
				if _ticks % 2 == 0:
					Vfx.slash(self, global_position - Vector3.UP * 0.6, Vector3.FORWARD.rotated(Vector3.UP, _t * 9.0), 1.8, 300.0, Color(0.55, 0.85, 1.0, 0.8))
			elif _ticks >= NinjaArts.ORB_TICKS and _t >= 0.1 * NinjaArts.ORB_TICKS + 0.05:
				_burst = true
				var r := 3.4 * p.area_mult
				NinjaArts.hit_area(p, action, global_position, r, NinjaArts.ORB_BURST, 0.0, action.get("applies", {}))
				Vfx.shockwave(self, global_position - Vector3.UP * 0.9, r, Color(0.55, 0.85, 1.0))
				Vfx.flash(self, global_position, 3.0, Color(0.75, 0.92, 1.0))
				EdenFx.play(self, String(action.get("hit_fx", "")), global_position - Vector3.UP * 0.9, 0.0, EdenFx.hit_scale(String(action.get("hit_fx", "")), r))
				p._shake(0.4)
				p._hit_pause(0.06)
		else:
			var k := clampf((_t - 0.65) / 0.3, 0.0, 1.0)
			_core.scale = Vector3.ONE * lerpf(0.6, 3.2, k)
			(_core.material_override as ShaderMaterial).set_shader_parameter("intensity", 1.0 - k)
			if k >= 1.0:
				queue_free()


## L'Étoile du Tourbillon lancée : file droit devant, tranche, explose, laisse un tourbillon.
class RasenStar extends Node3D:
	var p: Player
	var action: Dictionary
	var dir := Vector3.FORWARD
	var max_range := 14.0
	var _travel := 0.0
	var _tick := 0.0
	var _boom := -1.0  # instant de l'explosion (-1 : en vol)
	var _t := 0.0
	var _core: MeshInstance3D
	var _ring: MeshInstance3D
	var _vortex_ticks := 0

	func _ready() -> void:
		_core = NinjaArts.swirl_sphere(Color(0.25, 0.6, 1.0), 5.0, 9.0)
		_core.scale = Vector3.ONE * 0.62
		add_child(_core)
		_ring = MeshInstance3D.new()
		_ring.mesh = NinjaArts.blade_mesh()
		_ring.material_override = NinjaArts._glow_material()
		_ring.scale = Vector3.ONE * 2.0
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ring)

	func _physics_process(delta: float) -> void:
		_t += delta
		if not is_instance_valid(p):
			queue_free()
			return
		_ring.rotation.y -= delta * 22.0
		if _boom < 0.0:
			var step := NinjaArts.ULT_SPEED * delta
			global_position += dir * step
			_travel += step
			_tick -= delta
			if _tick <= 0.0:
				_tick = 0.12
				NinjaArts.hit_area(p, action, global_position, 2.2, NinjaArts.ULT_PATH, 0.15)
			if _travel >= max_range or _blocker():
				_explode()
		else:
			var e := _t - _boom
			var k := clampf(e / 0.45, 0.0, 1.0)
			_core.scale = Vector3.ONE * lerpf(0.8, 6.2 * p.area_mult, k * (2.0 - k))
			var mat := _core.material_override as ShaderMaterial
			mat.set_shader_parameter("intensity", 1.0 - 0.7 * k if e < 1.2 else maxf(0.0, 0.3 - (e - 1.2)))
			_ring.scale = Vector3.ONE * lerpf(2.0, 7.0, k)
			# tourbillon : 6 coups sur 1,2 s qui attirent vers le centre
			if _vortex_ticks < 6 and e >= 0.25 + 0.2 * _vortex_ticks:
				_vortex_ticks += 1
				NinjaArts.hit_area(p, action, global_position, 4.5 * p.area_mult, NinjaArts.ULT_VORTEX, 0.35)
				Vfx.slash(self, global_position - Vector3.UP * 1.2, Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU), 4.0, 200.0, Color(0.7, 0.9, 1.0, 0.85))
			if e > 1.6:
				queue_free()

	## Premier adversaire touché de plein fouet (centre de l'étoile sur lui) : elle éclate sur lui.
	func _blocker() -> bool:
		for node in p.foes():
			var m := node as Combatant
			if m == null or m.is_dead:
				continue
			var to := m.global_position - global_position
			to.y = 0.0
			if to.length() <= m.radius + 1.0:
				return true
		return false

	func _explode() -> void:
		_boom = _t
		var r := 6.0 * p.area_mult
		var ground := global_position
		ground.y = p.global_position.y
		NinjaArts.hit_area(p, action, global_position, r, NinjaArts.ULT_BLAST, 0.0, action.get("applies", {}))
		Vfx.shockwave(self, ground, r, Color(0.65, 0.88, 1.0))
		Vfx.shockwave(self, ground, r * 0.6, Color(1.0, 1.0, 1.0))
		Vfx.flash(self, global_position, 6.0, Color(0.85, 0.95, 1.0))
		for i in 5:
			Vfx.slash(self, ground + Vector3.UP * 0.3, Vector3.FORWARD.rotated(Vector3.UP, TAU * i / 5.0), r, 70.0, Color(0.8, 0.95, 1.0, 0.9))
		EdenFx.play(self, String(action.get("hit_fx", "")), ground, 0.0, EdenFx.hit_scale(String(action.get("hit_fx", "")), r))
		p._shake(1.2)
		p._hit_pause(0.08)
