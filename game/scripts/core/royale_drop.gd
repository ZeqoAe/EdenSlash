class_name RoyaleDrop
extends Node
## Largage du Battle royale (lot BR4, retour du joueur : « plus de spawn fixe, on choisit où atterrir ») : un aigle
## géant traverse la carte en ligne droite, d'un bord à l'autre (direction tirée à la graine de la partie). Les huit
## héros sont à bord ; chacun saute quand il veut (le joueur : touche Sauter, portes ouvertes après Royale.COUNTDOWN s,
## saut automatique en fin de vol), tombe en dirigeant sa chute (Esquive maintenue : piqué), ouvre son planeur à basse
## altitude (seul, ou plus tôt avec Sauter) et prend la main à l'atterrissage. Personne n'attaque ni n'est attaquable en
## l'air : un héros quitte le groupe « ffa » (il garde son identifiant) jusqu'au sol. Les héros scriptés visent chacun
## un coffre, répartis le long du vol (certains sautent tôt, d'autres tard) ; le pilote automatique du joueur fait de même.
## Sert aussi au retour d'un héros réanimé ([method drop_in] : planeur ouvert au-dessus de son point de retour).
## Déplacements sans physique : la position est posée à chaque image ; le corps (physique, IA) est rendu au sol.

signal landed(who: Combatant)

const ALT := 95.0  # hauteur du vol au-dessus du point le plus haut sous sa ligne
const SPEED := 30.0  # vitesse de l'aigle (m/s) : 15 à 22 s de vol selon la ligne
const EDGE := 30.0  # marge entre le vol et le bord de la carte
const FALL := 16.0  # chute libre (m/s)
const DIVE := 34.0  # piqué
const AIR_MOVE := 17.0  # déplacement horizontal en chute libre (m/s)
const GLIDE_AT := 26.0  # le planeur s'ouvre seul à cette hauteur au-dessus du sol
const GLIDE_FALL := 6.0
const GLIDE_MOVE := 12.0
const OPEN_AFTER := 0.4  # le planeur ne s'ouvre pas à la main dans la première fraction de seconde (même touche que le saut)
const LATE := 20.0  # filet de sécurité : passé la fin du vol + LATE s, ceux encore en l'air sont posés au sol
const CAM_FAR := 34.0  # distance de la caméra à bord et au début de la chute
const EAGLE := "res://assets/monsters/m092/m092.glb"
const EAGLE_TEX := "res://assets/monsters/textures/m09201.png"
const EAGLE_SCALE := 4.0
const EAGLE_BELOW := 7.0  # l'aigle vole sous les héros à bord (vue de la caméra : on le voit porter le joueur)

var d: RunDirector
var a := Vector3.ZERO  # départ du vol (altitude comprise)
var b := Vector3.ZERO  # arrivée
var duration := 0.0  # durée du vol (s)
var t := 0.0  # secondes depuis le départ de l'aigle
var eagle: Node3D
var riders := {}  # Combatant -> {state: ride|fall|glide, jump_t, target, air, glider}
var _cam_dist := -1.0


## Trace la ligne du vol, pose l'aigle et embarque [param heroes] (le joueur et les héros scriptés).
func setup(director: RunDirector, rng: RandomNumberGenerator, heroes: Array) -> void:
	d = director
	_roll_line(rng)
	_make_eagle()
	for c in heroes:
		board(c)
	var plans := plan(heroes.size(), rng)
	var k := 0
	for c in heroes:
		riders[c].target = plans[k].target
		riders[c].jump_t = plans[k].jump_t
		k += 1


func _roll_line(rng: RandomNumberGenerator) -> void:
	var bnd: Rect2 = d.map.bounds.grow(-EDGE)
	var c := bnd.get_center()
	var ang := rng.randf() * TAU
	var dir := Vector2(cos(ang), sin(ang))
	var perp := Vector2(-dir.y, dir.x)
	var p0 := c + perp * rng.randf_range(-0.2, 0.2) * minf(bnd.size.x, bnd.size.y)
	var p_a := p0 - dir * _exit(p0, -dir, bnd)
	var p_b := p0 + dir * _exit(p0, dir, bnd)
	var top := -INF
	for i in 25:
		var q := p_a.lerp(p_b, i / 24.0)
		top = maxf(top, d.map.height_at(q.x, q.y))
	a = Vector3(p_a.x, top + ALT, p_a.y)
	b = Vector3(p_b.x, top + ALT, p_b.y)
	duration = p_a.distance_to(p_b) / SPEED


## Distance de [param p] au bord du rectangle [param r] dans la direction [param dir].
static func _exit(p: Vector2, dir: Vector2, r: Rect2) -> float:
	var best := INF
	if dir.x > 0.0001:
		best = minf(best, (r.end.x - p.x) / dir.x)
	elif dir.x < -0.0001:
		best = minf(best, (r.position.x - p.x) / dir.x)
	if dir.y > 0.0001:
		best = minf(best, (r.end.y - p.y) / dir.y)
	elif dir.y < -0.0001:
		best = minf(best, (r.position.y - p.y) / dir.y)
	return maxf(best, 0.0)


func _make_eagle() -> void:
	eagle = Node3D.new()
	eagle.name = "RoyaleEagle"
	d.add_child(eagle)
	if ResourceLoader.exists(EAGLE):
		var m := EdenModel.instantiate(EAGLE, EAGLE_TEX)
		m.scale = Vector3.ONE * EAGLE_SCALE
		eagle.add_child(m)
		var anim := EdenModel.find_anim_player(m)
		if anim:
			for n in ["move01", "move02", "stand01"]:
				if anim.has_animation(n):
					anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
					anim.play(n)
					break
	var dir := b - a
	eagle.rotation.y = atan2(dir.x, dir.z)
	eagle.global_position = eagle_pos() + Vector3.DOWN * EAGLE_BELOW


## Position de l'aigle (il continue tout droit après la fin du vol, puis disparaît).
func eagle_pos() -> Vector3:
	var dir := (b - a).normalized()
	return a + dir * SPEED * t


## Le vol est en cours (l'aigle au-dessus de la carte).
func flying() -> bool:
	return t < duration


func airborne(c) -> bool:
	return riders.has(c)


func on_board(c) -> bool:
	return riders.has(c) and String(riders[c].state) == "ride"


## Héros encore à bord ou en l'air.
func count_airborne() -> int:
	return riders.size()


func board(c: Combatant) -> void:
	riders[c] = {"state": "ride", "jump_t": duration, "target": Vector3.INF, "air": 0.0, "glider": null}
	c.remove_from_group("ffa")  # (il garde son identifiant : ni cible ni combattant jusqu'au sol)
	c.visible = false
	c.set_physics_process(false)
	c.velocity = Vector3.ZERO
	c.global_position = eagle_pos() + Vector3.UP * 1.5
	if c is ClassRival:
		(c as ClassRival).passive = true
	if c == d.player and d.world.rig != null:
		if _cam_dist < 0.0:
			_cam_dist = d.world.rig.distance
		d.world.rig.distance = CAM_FAR


## Retour d'un héros réanimé : planeur ouvert au-dessus de [param ground], il atterrit à peu près là.
func drop_in(c: Combatant, ground: Vector3) -> void:
	board(c)
	var st: Dictionary = riders[c]
	st.target = ground
	c.global_position = ground + Vector3.UP * GLIDE_AT
	c.visible = true
	_open(c, st)


## Points de saut : un coffre visé par héros, à portée de chute depuis la ligne du vol, éloignés les uns des autres ;
## les instants de saut sont répartis sur le vol (tôt, au milieu, tard). [{target, jump_t}]
func plan(n: int, rng: RandomNumberGenerator) -> Array:
	var reach := (AIR_MOVE * (ALT - GLIDE_AT) / FALL + GLIDE_MOVE * GLIDE_AT / GLIDE_FALL) * 0.6
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var len := maxf(ab.length(), 1.0)
	var u := ab / len
	var cands: Array = []
	for it in d.map.interactables:
		if not is_instance_valid(it) or it.kind != "chest" or it.used:
			continue
		var p: Vector3 = it.global_position
		var q := Vector2(p.x - a.x, p.z - a.z)
		var along := q.dot(u)
		var side := absf(q.dot(Vector2(-u.y, u.x)))
		var jt := along / SPEED
		if side > reach or jt < Royale.COUNTDOWN + 0.5 or jt > duration - 0.5:
			continue
		cands.append({"pos": p, "jump_t": jt, "tier": int(it.get_meta("tier", 0)), "dir": Vector2(p.x, p.z) - (Vector2(a.x, a.z) + u * along)})
	var slots: Array = []
	var open_t := Royale.COUNTDOWN + 0.5
	for i in n:
		slots.append(lerpf(open_t, duration - 0.5, (i + rng.randf_range(0.2, 0.8)) / float(n)))
	# (ordre mélangé à la graine : on ne sait pas qui saute tôt)
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = slots[i]
		slots[i] = slots[j]
		slots[j] = tmp
	var out: Array = []
	var taken: Array = []
	for i in n:
		var best: Dictionary = {}
		var best_s := -INF
		for c in cands:
			var cp: Vector3 = c.pos
			if taken.any(func(o): return Vector2(o.x - cp.x, o.z - cp.z).length() < 55.0):
				continue
			var s := float(c.tier) * 1.2 - absf(float(c.jump_t) - float(slots[i])) * 0.35 + rng.randf() * 0.8
			if s > best_s:
				best_s = s
				best = c
		if best.is_empty():
			# aucun coffre libre à portée : un point au sol sous le vol, le plus loin possible des autres (lot BR-I3 :
			# avant, un point tiré au hasard sans regarder les autres tombait parfois à 8-15 m d'un héros, test_royale)
			var fb := _free_spot(float(slots[i]), u, reach, taken, rng.randf_range(-1.0, 1.0))
			out.append(fb)
			taken.append(fb.target)
			continue
		# atterrir à côté du coffre, du côté du vol (pas dessus)
		var off: Vector2 = -(best.dir as Vector2).normalized() * 2.5 if (best.dir as Vector2).length() > 0.5 else Vector2(2.5, 0)
		var tp: Vector3 = best.pos + Vector3(off.x, 0, off.y)
		tp.y = d.map.height_at(tp.x, tp.z)
		out.append({"target": tp, "jump_t": maxf(open_t, float(best.jump_t) - 0.6)})
		taken.append(tp)
	return out


## Écart visé entre deux points de saut (comme pour les coffres) ; au-delà, un point plus proche de son instant de saut
## vaut mieux qu'un point encore plus isolé.
const SPREAD := 55.0


## Point de saut sans coffre (lot BR-I3) : sur une grille de la bande atteignable sous le vol (instants de saut entre
## l'ouverture des portes et la fin, écart latéral dans [param reach]), celui qui est le plus loin des points déjà pris
## ([param taken], plafonné à SPREAD), puis le plus proche de l'instant prévu [param slot_t] ; [param jitter] (-1 à 1,
## tiré à la graine) décale la grille d'un tirage à l'autre. Toujours au sol et dans la carte. {target, jump_t}
func _free_spot(slot_t: float, u: Vector2, reach: float, taken: Array, jitter: float) -> Dictionary:
	var open_t := Royale.COUNTDOWN + 0.5
	var last_t := maxf(open_t, duration - 0.5)
	var side := Vector2(-u.y, u.x)
	var bnd: Rect2 = d.map.bounds.grow(-12.0)
	var best := {}
	var best_s := -INF
	var lat := reach * 0.7
	for k in 25:
		var jt := lerpf(open_t, last_t, (float(k) + 0.5 + jitter * 0.4) / 25.0)
		for m in 7:
			var off := lerpf(-lat, lat, float(m) / 6.0) + jitter * lat * 0.12
			var q := Vector2(a.x, a.z) + u * SPEED * jt + side * off
			if not bnd.has_point(q):
				continue
			var gap := SPREAD
			for o in taken:
				gap = minf(gap, Vector2((o as Vector3).x - q.x, (o as Vector3).z - q.y).length())
			var s := gap * 10.0 - absf(jt - slot_t) * 0.35 - absf(off) * 0.01
			if s > best_s:
				best_s = s
				best = {"q": q, "jump_t": jt}
	if best.is_empty():  # (vol hors de la carte : jamais en pratique) le point sous l'aigle à l'instant prévu
		best = {"q": (Vector2(a.x, a.z) + u * SPEED * slot_t).clamp(bnd.position, bnd.end), "jump_t": slot_t}
	var q: Vector2 = best.q
	var g: Vector3 = d.map.ground_at(q.x, q.y)
	if g == Vector3.INF:
		g = Vector3(q.x, d.map.height_at(q.x, q.y), q.y)
	return {"target": g, "jump_t": float(best.jump_t)}


func update(delta: float) -> void:
	t += delta
	if is_instance_valid(eagle):
		eagle.global_position = eagle_pos() + Vector3.DOWN * EAGLE_BELOW
		if t > duration + 6.0:
			eagle.queue_free()
	for c in riders.keys():
		if not is_instance_valid(c) or c.is_dead:
			_forget(c)
			continue
		var st: Dictionary = riders[c]
		if String(st.state) == "ride":
			c.global_position = eagle_pos() + Vector3.UP * 1.5
			if _wants_jump(c, st):
				jump(c)
		else:
			_fall(c, st, delta)
		if t > duration + LATE and riders.has(c):
			var p: Vector3 = c.global_position
			_land(c, riders[c], Vector3(p.x, d.map.height_at(p.x, p.z), p.z))  # filet de sécurité
	_camera(delta)


func _wants_jump(c: Combatant, st: Dictionary) -> bool:
	if t >= duration:
		return true  # saut automatique en fin de vol
	if t < Royale.COUNTDOWN:
		return false  # portes fermées
	if c == d.player and not d.player.autoplay:
		return Input.is_action_just_pressed("jump") and not get_tree().paused
	return t >= float(st.jump_t)


## Saut hors de l'aigle.
func jump(c: Combatant) -> void:
	var st: Dictionary = riders.get(c, {})
	if st.is_empty() or String(st.state) != "ride":
		return
	st.state = "fall"
	st.air = 0.0
	c.visible = true
	c.global_position = eagle_pos() + Vector3.DOWN * 2.0
	if (b - a).length() > 1.0:
		c.rotation.y = atan2(b.x - a.x, b.z - a.z)
	_pose(c, "jump", "jump01")
	if c == d.player:
		Sfx.ui("chest", -10.0)


func _fall(c: Combatant, st: Dictionary, delta: float) -> void:
	st.air = float(st.air) + delta
	var pos := c.global_position
	var ground: float = d.map.height_at(pos.x, pos.z)
	var gl := String(st.state) == "glide"
	var dir := Vector3.ZERO
	var dive := false
	if c == d.player and not d.player.autoplay:
		var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var cam := get_viewport().get_camera_3d()
		dir = Vector3(v.x, 0, v.y).rotated(Vector3.UP, cam.global_rotation.y) if cam else Vector3(v.x, 0, v.y)
		dive = Input.is_action_pressed("dodge")
		if not gl and Input.is_action_just_pressed("jump") and float(st.air) > OPEN_AFTER:
			_open(c, st)
			gl = true
	elif st.target != Vector3.INF:
		var to := Vector3(st.target.x - pos.x, 0, st.target.z - pos.z)
		var dist := to.length()
		var hs0 := GLIDE_MOVE if gl else AIR_MOVE
		if dist > 0.3:
			dir = to / dist * minf(1.0, dist / maxf(hs0 * delta, 0.001))
		# piqué dès que la chute restante suffit au trajet
		dive = not gl and dist / AIR_MOVE < maxf(0.0, pos.y - ground - GLIDE_AT) / DIVE
	if not gl and pos.y - ground <= GLIDE_AT:
		_open(c, st)
		gl = true
	var hs := GLIDE_MOVE if gl else AIR_MOVE
	var vs := GLIDE_FALL if gl else (DIVE if dive else FALL)
	pos += dir * hs * delta
	pos.y -= vs * delta
	var bnd: Rect2 = d.map.bounds.grow(-4.0)
	pos.x = clampf(pos.x, bnd.position.x, bnd.end.x)
	pos.z = clampf(pos.z, bnd.position.y, bnd.end.y)
	if dir.length() > 0.1:
		c.rotation.y = lerp_angle(c.rotation.y, atan2(dir.x, dir.z), clampf(8.0 * delta, 0.0, 1.0))
	var g: float = d.map.height_at(pos.x, pos.z)
	if pos.y <= g + 0.05:
		_land(c, st, Vector3(pos.x, g, pos.z))
		return
	c.global_position = pos


## Planeur ouvert : descente lente, on se dirige moins vite.
func _open(c: Combatant, st: Dictionary) -> void:
	st.state = "glide"
	if st.glider == null:
		st.glider = _make_glider(Color(1.0, 0.76, 0.32) if c == d.player else Color(0.6, 0.46, 1.0))
		c.add_child(st.glider)
	_pose(c, "idle", "stand01")


## Voile de parapente : un dôme aplati et allongé (le joueur en or, les autres en violet), deux suspentes.
static func _make_glider(col: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Glider"
	var canopy := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 2.4
	dome.height = 1.2
	dome.is_hemisphere = true
	dome.radial_segments = 24
	dome.rings = 6
	canopy.mesh = dome
	canopy.scale = Vector3(1.0, 0.7, 0.32)
	canopy.position = Vector3(0, 3.5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col * 0.25
	mat.roughness = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	canopy.material_override = mat
	root.add_child(canopy)
	# bord plus sombre : la voile se lit de haut (sinon une simple tache de couleur)
	var trim := StandardMaterial3D.new()
	trim.albedo_color = col.darkened(0.45)
	trim.roughness = 0.6
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.25
	torus.outer_radius = 2.5
	torus.rings = 32
	torus.ring_segments = 6
	rim.mesh = torus
	rim.scale = Vector3(1.0, 1.0, 0.32)
	rim.position = Vector3(0, 3.5, 0)
	rim.material_override = trim
	root.add_child(rim)
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.9, 0.88, 0.8)
	cord.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx in [-1.0, 1.0]:
		var a := Vector3(0.25 * sx, 1.5, 0)
		var b := Vector3(2.2 * sx, 3.5, 0)
		var line := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.025
		cyl.bottom_radius = 0.025
		cyl.height = a.distance_to(b)
		cyl.radial_segments = 4
		cyl.rings = 1
		line.mesh = cyl
		line.material_override = cord
		line.position = (a + b) * 0.5
		line.rotation.z = -atan2(b.x - a.x, b.y - a.y)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(line)
	return root


func _land(c: Combatant, st: Dictionary, g: Vector3) -> void:
	riders.erase(c)
	if st.glider != null and is_instance_valid(st.glider):
		(st.glider as Node).queue_free()
	c.visible = true
	c.set_physics_process(true)
	c.velocity = Vector3.ZERO
	if c == d.player:
		d._place_player(g)
		if _cam_dist > 0.0 and d.world.rig != null:
			d.world.rig.distance = _cam_dist
	else:
		c.global_position = g + Vector3.UP * 0.5
		if c is ClassRival:
			(c as ClassRival).passive = false
	if c.ffa_id >= 0:
		c.add_to_group("ffa")  # (de nouveau une cible et un combattant)
	_pose(c, "idle", "stand01")
	Vfx.ring(d, g + Vector3.UP * 0.15, 2.6, Color(1.0, 0.85, 0.45, 0.8) if c == d.player else Color(0.7, 0.55, 1.0, 0.6))
	landed.emit(c)


## Pose tout le monde au sol (fin du filet de sécurité, tests).
func land_all() -> void:
	for c in riders.keys():
		if not is_instance_valid(c):
			riders.erase(c)
			continue
		var p: Vector3 = c.global_position
		if String(riders[c].state) == "ride" and riders[c].target != Vector3.INF:
			p = riders[c].target
		_land(c, riders[c], Vector3(p.x, d.map.height_at(p.x, p.z), p.z))


func _forget(c) -> void:
	var st: Dictionary = riders[c]
	riders.erase(c)
	if st.glider != null and is_instance_valid(st.glider):
		(st.glider as Node).queue_free()


func _pose(c: Combatant, key: String, fallback: String) -> void:
	if c is Player:
		c.play((c as Player)._anim(key), 0.1, 1.0, true)
	elif c is ClassRival:
		c.play((c as ClassRival)._anim(key, fallback), 0.1, 1.0, true)


## Caméra du joueur : large à bord et au début de la chute, puis elle revient à sa distance en approchant du sol.
func _camera(_delta: float) -> void:
	var p := d.player
	if not riders.has(p) or d.world.rig == null or _cam_dist < 0.0:
		return
	var st: Dictionary = riders[p]
	if String(st.state) == "ride":
		d.world.rig.distance = CAM_FAR
		return
	var h: float = p.global_position.y - d.map.height_at(p.global_position.x, p.global_position.z)
	d.world.rig.distance = lerpf(_cam_dist, CAM_FAR, clampf((h - GLIDE_AT * 0.5) / (ALT - GLIDE_AT * 0.5), 0.0, 1.0))


## Aide à l'écran pour le joueur (vide : rien à dire).
func hint() -> String:
	var p := d.player
	if not riders.has(p):
		return ""
	var st: Dictionary = riders[p]
	match String(st.state):
		"ride":
			if t < Royale.COUNTDOWN:
				return "Saut possible dans %d" % ceili(Royale.COUNTDOWN - t)
			return "[%s] Sauter · saut auto dans %d s" % [Settings.action_label("jump", 1), maxi(0, ceili(duration - t))]
		"fall":
			return "Dirige ta chute · [%s] Piqué · [%s] Planeur" % [Settings.action_label("dodge", 1), Settings.action_label("jump", 1)]
	return "Dirige ton planeur"
