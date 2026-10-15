class_name RoyaleDirector
extends Node
## Déroulement d'une partie de Battle royale (voir Royale) : la carte de Survie remplie de coffres, huit héros
## (le joueur et sept héros scripté) parachutés à des points tirés au sort, nus et au niveau 1, un anneau qui se
## referme en quatre phases, le dernier debout gagne. Les héros scriptés pillent les coffres, fuient l'anneau et
## se battent quand un adversaire est proche (ClassRival.goal) ; leur niveau et leur équipement montent comme ceux
## du joueur (Royale.ai_open_chest).

const AI_COUNT := Royale.PLAYERS - 1
const FIGHT_RANGE := 22.0  # un héros scripté se bat dès qu'un adversaire est plus près
const CHEST_RANGE := 3.2
const ORDER_EVERY := 0.4
const WALL_HEIGHT := 140.0

var d: RunDirector
var phase := "countdown"  # countdown, fight, over
var elapsed := 0.0  # secondes de combat (après le compte à rebours)
var ais: Array = []  # ClassRival
var centers: Array = []
var ring: Dictionary = {}
var chests_opened := 0
var rng := RandomNumberGenerator.new()
var _t := Royale.COUNTDOWN
var _chests: Array = []  # coffres de la carte (Interactable)
var _claims := {}  # coffre -> héros scripté qui s'y rend
var _wall: MeshInstance3D
var _next_wall: MeshInstance3D
var _ring_tick := 1.0
var _order_t := 0.0
var _obj_t := 0.0
var _warn_t := 0.0
var _spawns: Array = []
var _end_t := -1.0
var _place := 0


func setup(director: RunDirector) -> void:
	d = director
	rng.randomize()
	d.zone = GameData.zone(Run.zone_id)
	d.map = d.world.new_royale_map(randi())
	d.world._apply_biome_env()
	Music.play(Music.DUEL)
	d.state = "royale"
	d._fog = Image.create(RunDirector.FOG_RES, RunDirector.FOG_RES, false, Image.FORMAT_LA8)
	d._fog.fill(Color(0, 0, 0, 0))
	d._fog_tex = ImageTexture.create_from_image(d._fog)
	var c := Vector2(d.map.size * 0.5, d.map.size * 0.5)
	centers = Royale.roll_centers(c, rng)
	ring = Royale.ring_at(0.0, centers)
	for it in d.map.interactables:
		if is_instance_valid(it) and it.kind == "chest":
			_chests.append(it)
	if d.map.breakables:
		d.map.breakables.broken.connect(_on_broken)
	_spawns = spawn_points(Royale.PLAYERS)
	var p := d.player
	p.set_ffa(0)
	p.level = 1
	Run.hero_level = 1
	p.recalc_stats()
	p.hp = p.max_hp
	d._place_player(_spawns[0])
	_spawn_ais()
	_build_walls()
	d.zone_changed.emit({"name": "Battle royale · %s" % d.zone.get("name", ""), "levels": [1, Royale.LEVEL_CAP]})
	d.message.emit("Battle royale\n%d héros, un seul survivant. Pille les coffres, reste dans l'anneau !" % Royale.PLAYERS, 4.0)
	d.world._offer("Ton arme de %s : choisis sa variante" % String(GameData.weapon_type(Run.weapon_type()).get("name", "classe")).to_lower(),
		d.start_weapon_cards())
	if p.autoplay:
		print("[royale] %s contre %s · carte %s · %d coffres" % [Run.class_id, ais.map(func(a): return String(a.get_meta("royale").cid)), Run.zone_id, _chests.size()])


## Points de largage éloignés les uns des autres (au moins ~90 m si la carte le permet), dans l'anneau de départ.
func spawn_points(n: int) -> Array:
	var c := Vector2(d.map.size * 0.5, d.map.size * 0.5)
	var pts: Array = []
	var tries := 0
	while pts.size() < n and tries < 4000:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * (Royale.START_RADIUS - 40.0)
		var q := c + Vector2(cos(a), sin(a)) * r
		var g: Vector3 = d.map.ground_at(q.x, q.y)
		if g == Vector3.INF:
			continue
		var min_d := maxf(30.0, 95.0 - tries * 0.03)
		if pts.all(func(o): return Vector2(o.x, o.z).distance_to(q) >= min_d):
			pts.append(g)
	while pts.size() < n:  # carte trop encombrée : on complète au hasard
		pts.append(d.map.start + Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)))
	return pts


func _spawn_ais() -> void:
	var classes: Array = GameData.classes.keys().filter(func(x): return x != Run.class_id)
	classes.shuffle()
	for i in AI_COUNT:
		var r := Royale.make_ai(String(classes[i]), Royale.difficulty_for(i), i + 1)
		d.add_child(r)
		r.set_ffa(i + 1)
		r.global_position = (_spawns[i + 1] as Vector3) + Vector3.UP * 0.5
		r.passive = true  # immobile pendant le compte à rebours
		r.died.connect(_on_ai_died)
		_tag(r)
		ais.append(r)
	# les centres de chaque anneau étant tirés, les héros scriptés partent tous à la recherche d'un coffre
	for r in ais:
		r.rotation.y = rng.randf() * TAU


## Plaque au-dessus d'un héros scripté : son nom et son niveau.
func _tag(r: ClassRival) -> void:
	var l := Label3D.new()
	l.name = "RoyaleTag"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
	l.pixel_size = 0.0011
	l.font_size = 26
	l.outline_size = 8
	l.position = Vector3(0, 3.1, 0)
	l.visibility_range_end = 35.0
	l.text = r.display_name
	r.add_child(l)


func _build_walls() -> void:
	_wall = _make_wall(Color(0.55, 0.35, 1.0, 0.2))
	_next_wall = _make_wall(Color(1.0, 1.0, 1.0, 0.12))
	_apply_walls()


func _make_wall(col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = WALL_HEIGHT
	cyl.radial_segments = 128
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	m.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	mat.albedo_color = col
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	d.add_child(m)
	return m


func _apply_walls() -> void:
	var c: Vector2 = ring.center
	var r: float = ring.radius
	_wall.position = Vector3(c.x, WALL_HEIGHT * 0.25, c.y)
	_wall.scale = Vector3(r, 1.0, r)
	var nr: float = ring.next_radius
	var nc: Vector2 = ring.next_center
	_next_wall.visible = nr < r - 1.0
	_next_wall.position = Vector3(nc.x, WALL_HEIGHT * 0.25 - 30.0, nc.y)
	_next_wall.scale = Vector3(nr, 0.55, nr)


# --- boucle -----------------------------------------------------------------------------
func update(delta: float) -> void:
	_obj_t -= delta
	if phase == "countdown":
		_t -= delta
		var n := ceili(_t)
		if n != ceili(_t + delta) and n > 0 and n <= 5:
			d.message.emit(str(n), 0.8)
		if _t <= 0.0:
			phase = "fight"
			for a in ais:
				if is_instance_valid(a):
					a.passive = false
			d.message.emit("C'EST PARTI !", 1.2)
	elif phase == "fight":
		elapsed += delta
		PvpCaps.elapsed = elapsed
		d.time = elapsed
		var was_phase := int(ring.get("phase", 0))
		var was_state := String(ring.get("state", ""))
		ring = Royale.ring_at(elapsed, centers)
		_apply_walls()
		if int(ring.phase) != was_phase or String(ring.state) != was_state:
			_announce_ring()
		_ring_tick -= delta
		if _ring_tick <= 0.0:
			_ring_tick = 1.0
			_ring_damage()
		_order_t -= delta
		if _order_t <= 0.0:
			_order_t = ORDER_EVERY
			for a in ais:
				if is_instance_valid(a) and not a.is_dead:
					_order(a)
		if d.player.autoplay:
			d.player.autoplay_target = _ring_goal() if _outside(d.player.global_position, 0.92) else Vector3.INF
		if elapsed >= Royale.DURATION + 20.0:
			_timeout()
	if _end_t >= 0.0:
		_end_t -= delta
		if _end_t < 0.0:
			_end_t = -1.0
			d.world.royale_end(_place)
	if _obj_t <= 0.0:
		_obj_t = 0.25
		d.objective_changed.emit(status_text())
	if d.player.autoplay and phase != "countdown":
		_debug(delta)


func _announce_ring() -> void:
	match String(ring.state):
		"shrink":
			d.message.emit("L'anneau se referme !", 2.5)
		"final":
			d.message.emit("DERNIER CERCLE : les dégâts explosent", 3.0)
		"hold":
			if int(ring.phase) > 0:
				d.message.emit("Anneau %d/%d : nouvelle zone marquée en blanc" % [int(ring.phase) + 1, Royale.PHASES.size() - 1], 3.0)
			else:
				d.message.emit("Un premier anneau se refermera bientôt : surveille la carte", 3.0)


## Texte de l'objectif (HUD).
func status_text() -> String:
	var left := float(ring.get("left", 0.0))
	var what := ""
	match String(ring.get("state", "hold")):
		"hold":
			what = "L'anneau se referme dans %d s" % ceili(left)
		"shrink":
			what = "L'anneau se resserre (%d s)" % ceili(left)
		_:
			what = "Dernier cercle"
	return "Battle royale · %s\n%d / %d en vie · éliminations %d · coffres %d" % [what, alive_count(), Royale.PLAYERS, Royale.kills, chests_opened]


func alive_count() -> int:
	var n := 0 if d.player.is_dead else 1
	for a in ais:
		if is_instance_valid(a) and not a.is_dead:
			n += 1
	return n


# --- anneau ---------------------------------------------------------------------------------
func _outside(pos: Vector3, factor := 1.0) -> bool:
	var c: Vector2 = ring.center
	return Vector2(pos.x, pos.z).distance_to(c) > float(ring.radius) * factor


## Point à rejoindre pour rentrer dans l'anneau (ou dans le prochain).
func _ring_goal() -> Vector3:
	var target_next := String(ring.state) == "shrink" or (String(ring.state) == "hold" and float(ring.left) < 12.0)
	var c: Vector2 = ring.next_center if target_next else ring.center
	var g: Vector3 = d.map.ground_at(c.x, c.y)
	return g if g != Vector3.INF else Vector3(c.x, d.map.height_at(c.x, c.y), c.y)


func _ring_damage() -> void:
	var dps := float(ring.dps)
	var members: Array = [d.player] + ais
	for m in members:
		if not is_instance_valid(m) or m.is_dead:
			continue
		if _outside(m.global_position):
			m.take_damage(maxf(1.0, m.max_hp * dps), null, false, true)
			if m == d.player and not m.is_dead and _warn_t <= 0.0:
				_warn_t = 3.0
				d.message.emit("Hors de l'anneau ! (%d %% des PV par seconde)" % roundi(dps * 100.0), 1.8)
	_warn_t = maxf(0.0, _warn_t - 1.0)


# --- héros scriptés ---------------------------------------------------------------------------
## Ordre du moment pour le héros scripté [param r] : rentrer dans l'anneau, se battre, piller, chasser.
func _order(r: ClassRival) -> void:
	var st: Dictionary = r.get_meta("royale")
	st.potion_cd = maxf(0.0, float(st.potion_cd) - ORDER_EVERY)
	if r.hp < r.max_hp * 0.4 and int(st.potions) > 0 and float(st.potion_cd) <= 0.0:
		st.potions = int(st.potions) - 1
		st.potion_cd = Potions.COOLDOWN
		r.heal(r.max_hp * Potions.HEAL_PCT)
		Vfx.ring(r, r.global_position, 2.2, Color(0.4, 1.0, 0.5, 0.8))
	var tag := r.get_node_or_null("RoyaleTag") as Label3D
	if tag:
		tag.text = "%s\n%d %%" % [r.display_name, roundi(r.hp / r.max_hp * 100.0)]
	var pos := r.global_position
	var flat := Vector2(pos.x, pos.z)
	var cc: Vector2 = ring.center
	var cr: float = ring.radius
	var nc: Vector2 = ring.next_center
	var nr: float = ring.next_radius
	var shrinking := nr < cr - 1.0
	var state := String(ring.state)
	# partir à temps : assez tôt pour atteindre le prochain anneau en courant, pas avant
	var must_go := _outside(pos, 0.95)
	if shrinking and flat.distance_to(nc) > nr * 0.9:
		var walk := maxf(0.0, flat.distance_to(nc) - nr * 0.85) / (maxf(r.move_speed, 4.0) * 1.15)
		must_go = must_go or state == "shrink" or float(ring.left) < walk + 6.0
	if must_go:
		_release(r)
		var c := nc if shrinking else cc
		var rad := nr if shrinking else cr
		var dirv := flat - c
		var spot := c + (dirv.normalized() * minf(dirv.length(), rad * 0.7) if dirv.length() > 0.1 else Vector2.ZERO)
		var g: Vector3 = d.map.ground_at(spot.x, spot.y)
		r.goal = g if g != Vector3.INF else Vector3(spot.x, pos.y, spot.y)
		st["mode"] = "R"
		return
	# un adversaire proche : on se bat
	var near := INF
	var near_pos := Vector3.INF
	for f in Combatant.ffa_foes(get_tree(), r):
		var fd := pos.distance_to((f as Node3D).global_position)
		if fd < near:
			near = fd
			near_pos = (f as Node3D).global_position
	if near < FIGHT_RANGE:
		r.goal = Vector3.INF
		st["mode"] = "F"
		return
	# sinon un coffre dans la zone sûre (le prochain anneau quand il approche)
	var soon := shrinking and (state == "shrink" or float(ring.left) < 30.0)
	var chest := _pick_chest(r, flat, nc if soon else cc, (nr * 0.95) if soon else (cr * 0.97))
	if chest != null:
		var cp := chest.global_position
		if Vector2(cp.x - pos.x, cp.z - pos.z).length() < CHEST_RANGE:
			_ai_open(r, chest)
			st["mode"] = "O"
			r.goal = Vector3.INF
		else:
			r.goal = cp
			st["mode"] = "L"
	elif near_pos != Vector3.INF:
		r.goal = near_pos  # plus de coffre : il file vers l'adversaire le plus proche (course, sauts, esquives)
		st["mode"] = "H"
	else:
		r.goal = Vector3.INF
		st["mode"] = "H"


func _release(r: ClassRival) -> void:
	for k in _claims.keys():
		if _claims[k] == r:
			_claims.erase(k)


## Coffre le plus proche de [param flat] dans l'anneau visé, pas déjà visé par un autre héros scripté.
func _pick_chest(r: ClassRival, flat: Vector2, tc: Vector2, tr: float) -> Interactable:
	for k in _claims.keys():
		if _claims[k] == r and is_instance_valid(k) and not (k as Interactable).used:
			return k
	var best: Interactable = null
	var bd := 170.0
	for it in _chests:
		if not is_instance_valid(it) or (it as Interactable).used:
			continue
		var p := (it as Node3D).global_position
		var q := Vector2(p.x, p.z)
		if q.distance_to(tc) > tr:
			continue
		var owner_ai = _claims.get(it)
		if owner_ai != null and is_instance_valid(owner_ai) and owner_ai != r and not owner_ai.is_dead:
			continue
		var dd := flat.distance_to(q)
		if dd < bd:
			bd = dd
			best = it
	if best != null:
		_release(r)
		_claims[best] = r
	return best


func _ai_open(r: ClassRival, chest: Interactable) -> void:
	var tier := int(chest.get_meta("tier", 0))
	chest.open_chest()
	_claims.erase(chest)
	Royale.ai_open_chest(r, tier)
	Sfx.event_at(d, chest.global_position, "chest", -8.0)


func _on_ai_died(who: Combatant, killer: Combatant) -> void:
	_release(who as ClassRival)
	who.clear_ffa()
	if phase == "over":
		return
	var left := alive_count()
	who.set_meta("place", left + 1)
	var tag := who.get_node_or_null("RoyaleTag") as Label3D
	if tag:
		tag.visible = false
	var by := ""
	if killer != null and is_instance_valid(killer) and killer != who:
		if killer == d.player:
			Royale.kills += 1
			d.player.gain_xp(maxi(1, ceili(float(GameData.xp_to_next(d.player.level)) * Royale.KILL_XP)))
			d.player.heal(d.player.max_hp * 0.25)
			by = " (par toi)"
			Profile.record_add("kills", 1)
		elif killer is ClassRival and killer.has_meta("royale"):
			Royale.ai_award(killer as ClassRival, Royale.KILL_XP)
			killer.heal(killer.max_hp * 0.25)
			by = " (par %s)" % killer.display_name.get_slice(" ·", 0)
	d.message.emit("%s éliminé%s\n%d restant%s" % [who.display_name.get_slice(" ·", 0), by, left, "s" if left > 1 else ""], 2.2)
	if randf() < 0.7:
		d._drop_potion(who.global_position, Potions.roll_kind())
	_check_end()


func _check_end() -> void:
	if phase == "over" or d.player.is_dead:
		return
	if alive_count() <= 1:
		_finish(1)


## Le joueur est tombé (world.gd) : sa place est celle des héros encore en vie, lui compris.
func player_down() -> void:
	if phase == "over":
		return
	var left := 1
	for a in ais:
		if is_instance_valid(a) and not a.is_dead:
			left += 1
	d.message.emit("Éliminé ! Tu termines %de sur %d" % [left, Royale.PLAYERS], 3.0)
	_finish(left)


## Temps écoulé sans vainqueur (ne devrait pas arriver : le dernier cercle tue) : le plus de PV l'emporte.
func _timeout() -> void:
	var best: Combatant = null
	for m in [d.player] + ais:
		if is_instance_valid(m) and not m.is_dead and (best == null or m.hp > best.hp):
			best = m
	_finish(1 if best == d.player else 2)


func _finish(place: int) -> void:
	if phase == "over":
		return
	phase = "over"
	_place = place
	for a in ais:
		if is_instance_valid(a):
			a.passive = true
			a.goal = Vector3.INF
	if place == 1:
		d.message.emit("VICTOIRE ! Dernier debout", 3.0)
	d.player.autoplay_target = Vector3.INF
	if d.player.autoplay:
		print("[royale] fin : place %d · %d éliminations · niveau %d · %d coffres · %.0f s" % [place, Royale.kills, d.player.level, chests_opened, elapsed])
	_end_t = 3.0


# --- coffres du joueur, objets cassés ----------------------------------------------------------
## Coffre de la carte ouvert par le joueur : une pièce à choisir parmi trois (niveau du héros), des potions, de
## l'expérience, parfois une carte.
func open_chest(it: Interactable) -> void:
	var p := d.player
	var tier := int(it.get_meta("tier", 0))
	var def: Dictionary = Royale.CHEST_TIERS[clampi(tier, 0, Royale.CHEST_TIERS.size() - 1)]
	it.open_chest()
	_claims.erase(it)
	Sfx.event_at(d, it.global_position, "chest", -2.0)
	chests_opened += 1
	d.chests_opened += 1
	Run.chests_total += 1
	Profile.record_add("chests", 1)
	d.message.emit("%s ouvert" % it.title, 1.5)
	var roll := func() -> Array:
		return Royale.chest_items(tier, p.level, Run.class_id).map(func(x): return RunDirector.weapon_card(x, "gear") if x.slot == "weapon" else RunDirector.item_card(x, "gear"))
	d.world._offer("%s : choisis une pièce d'équipement" % it.title, roll.call(), roll, 1)
	# potions
	var n_potions := int(def.potions) + (1 if randf() < float(def.potion) * (1.0 if int(def.potions) == 0 else 0.0) else 0)
	for i in n_potions:
		d._drop_potion(it.global_position, "heal" if i == 0 and tier == 0 else Potions.roll_kind())
	# cartes
	if randf() < float(def.card):
		var cards: Callable = func(): return Run.roll_cards(3)
		d.world._offer("%s : choisis une carte" % it.title, cards.call(), cards, 1)
	_give_levels(float(def.xp))


## Expérience du joueur en niveaux (fractions comprises).
func _give_levels(amount: float) -> void:
	var p := d.player
	p.gain_xp(maxi(1, ceili(float(GameData.xp_to_next(p.level)) * amount)))


func _on_broken(kind: String, pos: Vector3) -> void:
	if phase == "over" or d.player.is_dead:
		return
	Profile.record_add("breakables", 1)
	match kind:
		"gem":
			if randf() < 0.5:
				d._drop_potion(pos, Potions.roll_kind())
			_give_levels(0.1)
		"gold":
			pass
		_:
			if randf() < 0.05:
				d._drop_potion(pos, Potions.roll_kind())
			if randf() < 0.08 and d.player.hp < d.player.max_hp:
				d.player.heal(d.player.max_hp * 0.1)
				DamageNumber.spawn_text(d.player, "+PV", Color(0.5, 1.0, 0.55))
			_give_levels(0.03)


# --- repères ---------------------------------------------------------------------------------
## Lieux à montrer sur la mini-carte : les coffres proches (rayon de 80 m) et les fontaines.
func markers() -> Array:
	var out: Array = []
	var pp := d.player.global_position
	for it in _chests:
		if is_instance_valid(it) and not (it as Interactable).used and Vector2(it.global_position.x - pp.x, it.global_position.z - pp.z).length() < 80.0:
			var tier := int((it as Interactable).get_meta("tier", 0))
			out.append([it.global_position, "chest" if tier == 0 else "chest%d" % tier])
	for it in d.map.interactables:
		if is_instance_valid(it) and it.kind == "well" and not it.used:
			out.append([it.global_position, "well"])
	return out


## Cible du pilote automatique (tests) : le coffre le plus proche dans l'anneau.
func farm_target() -> Vector3:
	var pp := d.player.global_position
	var best := Vector3.INF
	var bd := INF
	for it in _chests:
		if not is_instance_valid(it) or (it as Interactable).used:
			continue
		var p := (it as Node3D).global_position
		if _outside(p, 0.85):
			continue
		var dd := Vector2(p.x - pp.x, p.z - pp.z).length()
		if dd < bd:
			bd = dd
			best = p
	return best


## Horloge du HUD : phase de l'anneau et temps avant son resserrement.
func clock_text() -> String:
	if phase == "countdown":
		return "Largage · %d" % maxi(0, ceili(_t))
	var n := mini(int(ring.get("phase", 0)) + 1, Royale.PHASES.size() - 1)
	match String(ring.get("state", "hold")):
		"hold":
			return "Anneau %d/%d · se referme dans %d s" % [n, Royale.PHASES.size() - 1, ceili(float(ring.left))]
		"shrink":
			return "Anneau %d/%d · RESSERREMENT" % [n, Royale.PHASES.size() - 1]
	return "DERNIER CERCLE"


## Lignes du panneau d'objectifs (HUD).
func objective_lines() -> Array[String]:
	# trois lignes : les survivants sont déjà sous le titre, les potions dans la barre d'action
	var out: Array[String] = []
	out.append("⚔ Reste dans l'anneau violet")
	out.append("◇ Coffres ouverts : %d · niveau %d / %d" % [chests_opened, d.player.level, Royale.LEVEL_CAP])
	out.append("◇ Chaque élimination : un niveau et des PV")
	return out


var _dbg_t := 0.0


## Ligne de suivi (pilote automatique, tests) : temps, anneau, vivants, niveaux.
func _debug(delta: float) -> void:
	_dbg_t -= delta
	if _dbg_t > 0.0:
		return
	_dbg_t = 15.0
	var lv: Array = []
	for a in ais:
		if not is_instance_valid(a):
			lv.append("-")
			continue
		var st: Dictionary = a.get_meta("royale")
		lv.append("%s%d%s%s%d" % [String(st.cid).substr(0, 3), int(st.lv), "x" if a.is_dead else "", String(st.get("mode", "?")), int(st.chests)])
	print("[royale] %3.0f s · anneau %d %s r=%.0f · vivants %d · toi niv. %d (%d PV) · %s" % [elapsed, int(ring.phase) + 1, ring.state,
		float(ring.radius), alive_count(), d.player.level, int(d.player.hp), " ".join(lv)])
