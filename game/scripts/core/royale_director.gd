class_name RoyaleDirector
extends Node
## Déroulement d'une partie de Battle royale (voir Royale) : la carte de Survie remplie de coffres, huit héros
## (le joueur et sept héros scripté) parachutés à des points tirés au sort, nus et au niveau 1, un anneau qui se
## referme en quatre phases, le dernier debout gagne. Les héros scriptés pillent les coffres, fuient l'anneau et
## se battent quand un adversaire est proche (ClassRival.goal) ; leur niveau et leur équipement montent comme ceux
## du joueur (Royale.ai_open_chest).

const AI_COUNT := Royale.PLAYERS - 1
const CHEST_RANGE := 3.2
const ORDER_EVERY := 0.4
const WALL_HEIGHT := 140.0
## Cerveau des héros scriptés par difficulté (0 Facile … 3 Hardcore), passe M1 :
##   sight : distance (m) où un adversaire est remarqué ; engage : rapport de forces minimal (Royale.power_ratio) pour
##   attaquer un adversaire qui ne le vise pas (0 : toujours) ; flee : rapport sous lequel il fuit un adversaire au
##   contact (0 : jamais) ; hunt : distance où il traque un héros affaibli, occupé ailleurs ou mis à prix (0 : jamais) ;
##   potion : part des PV où il boit ; smart : coffres choisis par valeur / trajet, en évitant ceux qu'un autre atteint avant.
const BRAIN := [
	{"sight": 16.0, "engage": 0.0, "flee": 0.0, "hunt": 0.0, "potion": 0.3, "smart": false},
	{"sight": 20.0, "engage": 0.6, "flee": 0.3, "hunt": 0.0, "potion": 0.4, "smart": false},
	{"sight": 24.0, "engage": 0.85, "flee": 0.5, "hunt": 40.0, "potion": 0.45, "smart": true},
	{"sight": 28.0, "engage": 1.0, "flee": 0.65, "hunt": 60.0, "potion": 0.5, "smart": true},
]
const CONTACT := 6.0  # un adversaire plus près est au contact : on se bat (ou on fuit)
## Pillage d'abord, combats à la fin (passe M1 : sans ça, les héros scriptés s'usaient en duels pendant que le joueur
## pillait, et la partie finissait en 4 min) : pour attaquer de lui-même, un héros scripté demande un rapport de forces
## de brain.engage + ENGAGE_RAMP[anneau] (l'exigence baisse à chaque anneau) ; il ne traque qu'à partir du 3e anneau.
const ENGAGE_RAMP := [1.0, 0.7, 0.4, 0.15, 0.0]
const HUNT_PHASE := 2
const FLEE_TIME := 4.0
const FLEE_COOLDOWN := 15.0  # pas deux fuites de suite : il doit finir un combat
const FLEE_STEP := 28.0
const CHASE_GIVE_UP := 5.0  # poursuite d'un adversaire qui ne le vise pas : abandonnée au bout de 5 s hors de portée
const IGNORE_TIME := 10.0
const STALEMATE := 20.0  # combat égal pendant le pillage : rompu au bout de 20 s
## Valeur d'un coffre pour le choix des héros scriptés (≈ son expérience en niveaux, pièces comprises), par qualité.
const TIER_VALUE := [0.55, 0.9, 1.4, 2.8]
const TRAVEL_EST := 10.0  # vitesse de trajet estimée (m/s) pour le choix des coffres

var d: RunDirector
var phase := "countdown"  # countdown, fight, over
var elapsed := 0.0  # secondes de combat (après le compte à rebours)
var ais: Array = []  # ClassRival (libérés à leur mort : toujours tester is_instance_valid)
var ai_stats: Array = []  # état de chaque héros scripté (meta « royale »), gardé après sa mort (bilan, mesures)
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
var _touch_t := 0.0
var _breaker: ClassRival = null  # héros scripté qui casse un objet (sinon : le joueur)
## Spectateur (passe M1) : le joueur éliminé regarde la fin de la partie ; Échap / B ouvre le bilan.
var spectating := false
var watched: Combatant = null
var _down_at := -1.0
## Largages (passe M1) : {node: Interactable, land: secondes de combat, pos}
var drops: Array = []
var _drop_phase := -1
## Héros mis à prix (passe M1) : celui qui compte le plus d'éliminations (au moins Royale.BOUNTY_KILLS).
var bounty: Combatant = null


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
		ai_stats.append(r.get_meta("royale"))
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
	l.text = "%s · niv. %d" % [r.display_name, r.level]
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
			if String(ring.state) == "shrink" and int(ring.phase) < Royale.PHASES.size() - 2:
				_announce_drop()
			if (String(ring.state) == "hold" and int(ring.phase) >= 1) or (String(ring.state) == "shrink" and int(ring.phase) < Royale.PHASES.size() - 2):
				_restock()
		if _restocks == 0 and elapsed >= Royale.RESTOCK_FIRST:
			_restock()
		_update_drops()
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
		_ai_breakables(delta)
		if spectating:
			_update_spectator()
		elif d.player.autoplay:
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
	if d.player.autoplay and phase == "fight":
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
## Ordre du moment pour le héros scripté [param r] : rentrer dans l'anneau, fuir, se battre, traquer, piller.
func _order(r: ClassRival) -> void:
	var st: Dictionary = r.get_meta("royale")
	var brain: Dictionary = BRAIN[clampi(int(st.diff), 0, BRAIN.size() - 1)]
	st.potion_cd = maxf(0.0, float(st.potion_cd) - ORDER_EVERY)
	if r.hp < r.max_hp * float(brain.potion) and int(st.potions) > 0 and float(st.potion_cd) <= 0.0:
		st.potions = int(st.potions) - 1
		st.potion_cd = Potions.COOLDOWN
		r.heal(r.max_hp * Potions.HEAL_PCT)
		Vfx.ring(r, r.global_position, 2.2, Color(0.4, 1.0, 0.5, 0.8))
	_refresh_tag(r)
	var pos := r.global_position
	var flat := Vector2(pos.x, pos.z)
	var cc: Vector2 = ring.center
	var cr: float = ring.radius
	var nc: Vector2 = ring.next_center
	var nr: float = ring.next_radius
	var shrinking := nr < cr - 1.0
	var state := String(ring.state)
	# partir à temps : assez tôt pour atteindre le prochain anneau à la course, pas avant
	var must_go := _outside(pos, 0.95)
	if shrinking and flat.distance_to(nc) > nr * 0.9:
		var walk := maxf(0.0, flat.distance_to(nc) - nr * 0.85) / maxf(r.travel_speed * 1.3, 5.0)
		must_go = must_go or state == "shrink" or float(ring.left) < walk + 6.0
	if must_go:
		_release(r)
		var c := nc if shrinking else cc
		var rad := nr if shrinking else cr
		var dirv := flat - c
		var spot := c + (dirv.normalized() * minf(dirv.length(), rad * 0.7) if dirv.length() > 0.1 else Vector2.ZERO)
		r.goal = _ground(spot, pos.y)
		st["mode"] = "R"
		return
	# adversaires : le plus proche, et le rapport de forces avec lui
	var foes := Combatant.ffa_foes(get_tree(), r)
	var foe: Combatant = null
	var fd := INF
	for f in foes:
		var dd := pos.distance_to((f as Node3D).global_position)
		if dd < fd:
			fd = dd
			foe = f
	if foe != null:
		var ratio := Royale.power_ratio(r, foe)
		if elapsed < float(st.flee_until):
			if fd < float(brain.sight) * 1.5:
				_flee(r, foe)
				return
			st.flee_until = 0.0
		var hunted := _targets(foe, r)
		# poursuites sans fin (passe M1 : deux héros se visaient l'un l'autre à distance pendant 100 s sans s'atteindre) :
		# un adversaire resté hors de portée CHASE_GIVE_UP s est laissé de côté IGNORE_TIME s (il retourne piller) ; un
		# combat égal qui traîne plus de STALEMATE s pendant les deux premiers anneaux est rompu de la même façon
		var fighting := String(st.get("mode", "")) == "F"
		st.chase = float(st.get("chase", 0.0)) + ORDER_EVERY if fighting and fd > CONTACT else 0.0
		st.fight_t = float(st.get("fight_t", 0.0)) + ORDER_EVERY if fighting else 0.0
		if float(st.chase) > CHASE_GIVE_UP or (float(st.fight_t) > STALEMATE and int(ring.phase) <= 1 and ratio > 0.67 and ratio < 1.5):
			st.chase = 0.0
			st.fight_t = 0.0
			st.ignore = foe.get_instance_id()
			st.ignore_until = elapsed + IGNORE_TIME
		var ignored: bool = int(st.get("ignore", 0)) == foe.get_instance_id() and elapsed < float(st.get("ignore_until", 0.0)) 			and (fd > CONTACT * 0.5 or not hunted)
		if not ignored and (fd < CONTACT or (fd < float(brain.sight) and hunted)):
			# fuite : seulement s'il peut boire ensuite ou s'il est écrasé, et pas deux fois de suite
			if float(brain.flee) > 0.0 and ratio < float(brain.flee) and elapsed >= float(st.get("flee_cd", 0.0)) \
					and (int(st.potions) > 0 or ratio < float(brain.flee) * 0.6):
				st.flee_until = elapsed + FLEE_TIME
				st.flee_cd = elapsed + FLEE_COOLDOWN
				_flee(r, foe)
				return
			_fight(r, foe)
			return
		var want := float(brain.engage) + float(ENGAGE_RAMP[mini(int(ring.phase), ENGAGE_RAMP.size() - 1)])
		if not ignored and fd < float(brain.sight) and ratio >= want:
			_fight(r, foe)
			return
	# traque : un héros affaibli, occupé contre un autre, ou mis à prix
	if float(brain.hunt) > 0.0 and int(ring.phase) >= HUNT_PHASE:
		var prey := _prey(r, foes, brain)
		if prey != null:
			_release(r)
			r.goal = prey.global_position
			st["mode"] = "H"
			return
	# sinon un coffre dans la zone sûre (le prochain anneau quand il approche)
	var soon := shrinking and (state == "shrink" or float(ring.left) < 30.0)
	var chest := _pick_chest(r, flat, nc if soon else cc, (nr * 0.95) if soon else (cr * 0.97), foes, bool(brain.smart))
	if chest != null:
		var cp := chest.global_position
		if Vector2(cp.x - pos.x, cp.z - pos.z).length() < CHEST_RANGE:
			if chest.used:
				r.goal = cp
				st["mode"] = "W"  # largage encore en l'air : il attend dessous
			else:
				r.goal = Vector3.INF
				_ai_open(r, chest)
				st["mode"] = "O"
		else:
			r.goal = cp
			st["mode"] = "L"
	else:
		# plus de coffre à portée : il casse jarres et caisses (comme le joueur), sinon il va vers l'adversaire le plus proche
		var pot := _nearest_pot(pos, 60.0)
		if pot != Vector3.INF and not _outside(pot, 0.95):
			r.goal = pot
			st["mode"] = "B"
		elif foe != null:
			r.goal = foe.global_position
			st["mode"] = "H"
		else:
			r.goal = Vector3.INF
			st["mode"] = "H"


## Jarre ou caisse la plus proche de [param pos] à moins de [param r] m (un héros scripté les casse en passant ;
## ni cristal, qu'il faut frapper, ni tas d'or, qui ne donne rien ici). Vector3.INF : aucune.
func _nearest_pot(pos: Vector3, r: float) -> Vector3:
	var b: Breakables = d.map.breakables
	if b == null:
		return Vector3.INF
	var best := Vector3.INF
	var bd := r
	for i in b._near(pos, r):
		var it: Dictionary = b._items[i]
		if it.kind == "gem" or it.kind == "gold":
			continue
		var dd := Vector2(it.pos.x - pos.x, it.pos.z - pos.z).length()
		if dd < bd:
			bd = dd
			best = it.pos
	return best


func _ground(spot: Vector2, y: float) -> Vector3:
	var g: Vector3 = d.map.ground_at(spot.x, spot.y)
	return g if g != Vector3.INF else Vector3(spot.x, y, spot.y)


## Plaque du héros scripté : nom, niveau, PV (★ s'il est mis à prix).
func _refresh_tag(r: ClassRival) -> void:
	var tag := r.get_node_or_null("RoyaleTag") as Label3D
	if tag == null:
		return
	var marked := r == bounty
	tag.text = "%s%s · niv. %d\n%d %%" % ["★ " if marked else "", r.display_name, r.level, roundi(r.hp / r.max_hp * 100.0)]
	tag.modulate = Color(1.0, 0.82, 0.3) if marked else Color.WHITE
	tag.visibility_range_end = 120.0 if marked else 35.0


func _fight(r: ClassRival, foe: Combatant) -> void:
	_release(r)
	r.goal = Vector3.INF
	r._player = foe
	r.get_meta("royale")["mode"] = "F"


## [param foe] vise-t-il [param r] ? (le joueur : sa cible verrouillée ; un héros scripté : sa cible quand il a décidé de se battre)
func _targets(foe: Combatant, r: ClassRival) -> bool:
	if foe is ClassRival:
		return String(foe.get_meta("royale", {}).get("mode", "")) == "F" and (foe as ClassRival)._player == r
	if foe is Player:
		return (foe as Player).current_target() == r
	return false


## Fuite : s'éloigne de [param foe] en restant dans la zone sûre (le trajet enchaîne les esquives).
func _flee(r: ClassRival, foe: Combatant) -> void:
	_release(r)
	var pos := r.global_position
	var flat := Vector2(pos.x, pos.z)
	var away := flat - Vector2(foe.global_position.x, foe.global_position.z)
	var dir := away.normalized() if away.length() > 0.1 else Vector2.RIGHT.rotated(randf() * TAU)
	var shrinking := float(ring.next_radius) < float(ring.radius) - 1.0
	var sc: Vector2 = ring.next_center if shrinking else ring.center
	var sr: float = float(ring.next_radius) if shrinking else float(ring.radius)
	var spot := flat + dir * FLEE_STEP
	if spot.distance_to(sc) > sr * 0.85:
		spot = flat + (dir + (sc - flat).normalized() * 1.3).normalized() * FLEE_STEP
	r.goal = _ground(spot, pos.y)
	r.get_meta("royale")["mode"] = "E"


## Proie d'un héros scripté qui traque : le mis à prix, un héros sous 45 % de PV ou occupé contre un autre, à portée
## de traque et pas trop fort pour lui. null : aucune.
func _prey(r: ClassRival, foes: Array, brain: Dictionary) -> Combatant:
	var best: Combatant = null
	var bd := INF
	for f in foes:
		var c := f as Combatant
		var dd := r.global_position.distance_to(c.global_position)
		if dd > float(brain.hunt) * (1.6 if c == bounty else 1.0):
			continue
		var busy := false
		if c is ClassRival:
			var cr := c as ClassRival
			busy = cr.goal == Vector3.INF and cr._player != r and is_instance_valid(cr._player) \
				and c.global_position.distance_to(cr._player.global_position) < 10.0
		if not (c == bounty or c.hp < c.max_hp * 0.45 or busy):
			continue
		if Royale.power_ratio(r, c) < float(brain.engage) * 0.8:
			continue
		if dd < bd:
			bd = dd
			best = c
	return best


func _release(r: ClassRival) -> void:
	for k in _claims.keys():
		if _claims[k] == r:
			_claims.erase(k)


## Coffre visé par [param r] dans l'anneau visé (centre [param tc], rayon [param tr]), pas déjà visé par un autre héros
## scripté (sauf un largage : on s'y dispute). Sans [param smart] : le plus proche (le Normal préfère un peu les
## meilleurs) ; [param smart] : la meilleure valeur par seconde de trajet, à moitié prix si un adversaire y est avant lui.
func _pick_chest(r: ClassRival, flat: Vector2, tc: Vector2, tr: float, foes: Array, smart: bool) -> Interactable:
	for k in _claims.keys():
		if _claims[k] == r and is_instance_valid(k) and not (k as Interactable).used:
			var kp := (k as Node3D).global_position
			if Vector2(kp.x, kp.z).distance_to(tc) <= tr:
				return k
	var best: Interactable = null
	var best_score := -INF
	var diff := int(r.get_meta("royale").diff)
	for it in _chests:
		if not is_instance_valid(it):
			continue
		var tier := int((it as Interactable).get_meta("tier", 0))
		var is_drop := tier == Royale.DROP_TIER
		if (it as Interactable).used and not (is_drop and not it.has_meta("opened")):
			continue
		var p := (it as Node3D).global_position
		var q := Vector2(p.x, p.z)
		if q.distance_to(tc) > tr:
			continue
		var owner_ai = _claims.get(it)
		if not is_drop and owner_ai != null and is_instance_valid(owner_ai) and owner_ai != r and not owner_ai.is_dead:
			continue
		var dd := flat.distance_to(q)
		if dd > 220.0:
			continue
		var score := -dd / (1.0 + 0.4 * tier) if diff >= 1 else -dd
		if smart:
			var value := float(TIER_VALUE[tier])
			for f in foes:
				var fq := Vector2((f as Node3D).global_position.x, (f as Node3D).global_position.z)
				if fq.distance_to(q) < minf(dd * 0.8, 30.0):
					value *= 0.5  # disputé : un adversaire l'atteint avant lui
					break
			score = value / (dd / TRAVEL_EST + 2.0)
		if score > best_score:
			best_score = score
			best = it
	if best != null:
		_release(r)
		if int(best.get_meta("tier", 0)) != Royale.DROP_TIER:
			_claims[best] = r
	return best


func _ai_open(r: ClassRival, chest: Interactable) -> void:
	var tier := int(chest.get_meta("tier", 0))
	chest.set_meta("opened", true)
	chest.open_chest()
	_claims.erase(chest)
	Royale.ai_open_chest(r, tier)
	Sfx.event_at(d, chest.global_position, "chest", -8.0)
	if tier == Royale.DROP_TIER:
		d.message.emit("%s s'empare du largage" % r.display_name.get_slice(" ·", 0), 2.0)


## Les héros scriptés cassent jarres et caisses en passant, comme le joueur (même expérience : Royale.BREAK_XP).
func _ai_breakables(delta: float) -> void:
	_touch_t -= delta
	if _touch_t > 0.0 or d.map.breakables == null:
		return
	_touch_t = 0.1
	for a in ais:
		if is_instance_valid(a) and not a.is_dead:
			_breaker = a
			d.map.breakables.touch(a.global_position)
	_breaker = null


func _on_ai_died(who: Combatant, killer: Combatant) -> void:
	_release(who as ClassRival)
	who.clear_ffa()
	if phase == "over":
		return
	var left := alive_count()
	who.set_meta("place", left + 1)
	if who.has_meta("royale"):
		who.get_meta("royale")["place"] = left + 1
	who.set_meta("died_at", elapsed)
	var tag := who.get_node_or_null("RoyaleTag") as Label3D
	if tag:
		tag.visible = false
	var was_bounty := who == bounty
	var name := who.display_name.get_slice(" ·", 0)
	var line := "%s est éliminé par l'anneau" % name
	if killer != null and is_instance_valid(killer) and killer != who:
		var xp := Royale.KILL_XP + (Royale.BOUNTY_XP if was_bounty else 0.0)
		if killer == d.player:
			Royale.kills += 1
			d.player.gain_xp(maxi(1, ceili(float(GameData.xp_to_next(d.player.level)) * xp)))
			d.player.heal(d.player.max_hp * 0.25)
			line = "Tu élimines %s" % name
			Profile.record_add("kills", 1)
		elif killer is ClassRival and killer.has_meta("royale"):
			var kst: Dictionary = killer.get_meta("royale")
			kst.kills = int(kst.get("kills", 0)) + 1
			Royale.ai_award(killer as ClassRival, xp)
			killer.heal(killer.max_hp * 0.25)
			line = "%s élimine %s" % [killer.display_name.get_slice(" ·", 0), name]
	if was_bounty:
		bounty = null
		line += " : la prime tombe"
	feed(line)
	if not spectating:
		d.message.emit("%d restant%s" % [left, "s" if left > 1 else ""], 1.6)
	if randf() < 0.7 or was_bounty:
		d._drop_potion(who.global_position, Potions.roll_kind())
	if who == watched:
		watched = killer if killer != null and is_instance_valid(killer) and not killer.is_dead and killer != d.player else null
	_update_bounty()
	_check_end()


## Fil des éliminations (en haut à droite du HUD, Hud.feed) : les 4 dernières lignes.
var kill_feed: Array = []  # [texte, secondes de combat]


func feed(line: String) -> void:
	kill_feed.append([line, elapsed])
	if kill_feed.size() > 4:
		kill_feed.pop_front()


## Éliminations de [param c] (le joueur : Royale.kills).
func kills_of(c: Combatant) -> int:
	if c == d.player:
		return Royale.kills
	return int(c.get_meta("royale").get("kills", 0)) if c != null and c.has_meta("royale") else 0


## Met à prix le héros qui compte le plus d'éliminations (au moins Royale.BOUNTY_KILLS ; en cas d'égalité, le
## mis à prix le reste).
func _update_bounty() -> void:
	var best: Combatant = bounty if bounty != null and is_instance_valid(bounty) and not bounty.is_dead else null
	var bk := kills_of(best) if best != null else Royale.BOUNTY_KILLS - 1
	for c in [d.player] + ais:
		if is_instance_valid(c) and not c.is_dead and kills_of(c) > bk:
			best = c
			bk = kills_of(c)
	if best == bounty or best == null:
		return
	bounty = best
	if best == d.player:
		d.message.emit("Tu es mis à prix !\nTous les héros voient où tu es", 3.0)
	else:
		d.message.emit("%s est mis à prix\nÉlimine-le : un niveau de plus" % best.display_name.get_slice(" ·", 0), 3.0)
	for a in ais:
		if is_instance_valid(a) and not a.is_dead:
			_refresh_tag(a)


func _check_end() -> void:
	if phase == "over":
		return
	if d.player.is_dead:
		if alive_count() <= 1:
			_finish(_place)  # spectateur : la partie se termine sans lui, sa place est déjà fixée
		return
	if alive_count() <= 1:
		_finish(1)


## Le joueur est tombé (world.gd) : sa place est celle des héros encore en vie, lui compris. Il regarde la fin de la
## partie (spectateur) ; Échap / B ouvre le bilan tout de suite.
func player_down(killer: Combatant = null) -> void:
	if phase == "over":
		return
	var left := 1
	for a in ais:
		if is_instance_valid(a) and not a.is_dead:
			left += 1
	_place = left
	_down_at = elapsed
	feed("Tu es éliminé (%de)" % left)
	if left <= 2:
		_finish(left)  # un seul héros restant : il a gagné
		d.message.emit("Éliminé ! Tu termines %de sur %d" % [left, Royale.PLAYERS], 3.0)
		return
	spectating = true
	watched = killer if killer != null and is_instance_valid(killer) and not killer.is_dead else null
	d.player.autoplay_target = Vector3.INF
	d.message.emit("Éliminé ! Tu termines %de sur %d\nTu regardes la fin · [%s] : bilan" % [left, Royale.PLAYERS, Settings.action_label("pause", 1)], 4.0)
	_update_spectator()


## Spectateur : la caméra suit un héros encore en vie (celui qui t'a éliminé, puis le mieux placé).
func _update_spectator() -> void:
	if watched == null or not is_instance_valid(watched) or watched.is_dead:
		watched = null
		var best_lv := -1
		for a in ais:
			if is_instance_valid(a) and not a.is_dead and int(a.get_meta("royale").lv) > best_lv:
				best_lv = int(a.get_meta("royale").lv)
				watched = a
	if watched != null and d.world.rig != null and d.world.rig.target != watched:
		d.world.rig.target = watched


## Place du joueur s'il quitte maintenant (menu pause, bilan du spectateur) : la sienne s'il est déjà éliminé.
func leave_place() -> int:
	return _place if spectating or d.player.is_dead else Royale.PLAYERS


## Temps de jeu du joueur (bilan) : jusqu'à son élimination s'il est tombé.
func player_time() -> float:
	return _down_at if _down_at >= 0.0 else elapsed


func _unhandled_input(event: InputEvent) -> void:
	# spectateur : Échap / B ouvre le bilan (pas le menu pause : il n'y a plus rien à y faire)
	if spectating and phase != "over" and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_finish(_place)
		_end_t = 0.01


## Temps écoulé sans vainqueur (ne devrait pas arriver : le dernier cercle tue) : le plus de PV l'emporte.
func _timeout() -> void:
	var best: Combatant = null
	for m in [d.player] + ais:
		if is_instance_valid(m) and not m.is_dead and (best == null or m.hp > best.hp):
			best = m
	_finish(1 if best == d.player else (_place if d.player.is_dead else 2))


func _finish(place: int) -> void:
	if phase == "over":
		return
	phase = "over"
	_place = place
	var winner: Combatant = null
	for a in ais:
		if is_instance_valid(a):
			if not a.is_dead:
				winner = a
			a.passive = true
			a.goal = Vector3.INF
	if place == 1:
		d.message.emit("VICTOIRE ! Dernier debout", 3.0)
	elif spectating and winner != null:
		d.message.emit("%s remporte la partie" % winner.display_name.get_slice(" ·", 0), 3.0)
	d.player.autoplay_target = Vector3.INF
	if d.player.autoplay:
		var order: Array = ai_stats.map(func(st): return "%s:%d(niv.%d,%d élim.,%d coffres)" % [String(st.cid).substr(0, 6),
			int(st.get("place", 1)), int(st.lv), int(st.get("kills", 0)), int(st.chests)])
		print("[royale] fin : place %d · %d éliminations · niveau %d · %d coffres · joueur %.0f s · partie %.0f s · coffres restants %d · %s" % [place,
			Royale.kills, d.player.level, chests_opened, player_time(), elapsed, chests_left(), " ".join(order)])
	_end_t = 3.0


func chests_left() -> int:
	var n := 0
	for it in _chests:
		if is_instance_valid(it) and not (it as Interactable).used:
			n += 1
	return n


# --- réapprovisionnement -------------------------------------------------------------------------
var _restocks := 0
var _chest_npc: Dictionary = {}


## Vague de nouveaux coffres dans l'anneau (Royale.RESTOCK_PER_HERO par héros en vie), plus souvent dorés à chaque vague.
func _restock() -> void:
	var n := mini(Royale.RESTOCK_PER_HERO * alive_count(), Royale.RESTOCK_MAX)
	var c: Vector2 = ring.center
	var rad := float(ring.radius) * 0.85
	var placed := 0
	var tries := 0
	while placed < n and tries < n * 12:
		tries += 1
		var q := c + Vector2.RIGHT.rotated(rng.randf() * TAU) * sqrt(rng.randf()) * rad
		var g: Vector3 = d.map.ground_at(q.x, q.y)
		if g == Vector3.INF or _chests.any(func(it): return is_instance_valid(it) and not it.used and Vector2(it.global_position.x - q.x, it.global_position.z - q.y).length() < 9.0):
			continue
		var roll := rng.randf()
		_spawn_chest(g, 2 if roll < 0.08 + 0.04 * _restocks else (1 if roll < 0.4 else 0))
		placed += 1
	_restocks += 1
	if placed > 0:
		d.message.emit("De nouveaux coffres tombent dans l'anneau", 2.5)


## Coffre de la qualité [param tier] posé en [param pos] (même allure que ceux de la carte, ProcMap.CHEST_LOOKS).
func _spawn_chest(pos: Vector3, tier: int) -> Interactable:
	var look: Dictionary = ProcMap.CHEST_LOOKS[tier]
	var it := Interactable.new()
	if String(look.model) == "":
		if _chest_npc.is_empty():
			_chest_npc = (JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json")) as Dictionary).get("chest", {})
		it.setup("chest", String(look.title), "res://assets/monsters/%s/%s.glb" % [_chest_npc.model, _chest_npc.model],
			"res://assets/monsters/textures/%s.png" % _chest_npc.texture, 1.0, 3.0)
	else:
		it.setup("chest", String(look.title), "res://assets/maps/objects/%s.glb" % look.model, "", float(look.scale), 3.0)
	it.set_meta("tier", tier)
	d.map.add_child(it)
	it.global_position = pos
	it.rotation.y = rng.randf() * TAU
	if String(look.model) != "":
		it.add_beam(look.light, 10.0 if tier == 1 else 18.0)
	d.map.interactables.append(it)
	_chests.append(it)
	return it


# --- largages ----------------------------------------------------------------------------------
## Annonce un largage : il tombera dans le prochain anneau dans Royale.DROP_DELAY s (pilier doré, repère sur la carte).
func _announce_drop() -> void:
	if int(ring.phase) == _drop_phase:
		return
	_drop_phase = int(ring.phase)
	var nc: Vector2 = ring.next_center
	var nr: float = ring.next_radius
	var pos := Vector3.INF
	for i in 40:
		var a := rng.randf() * TAU
		var q := nc + Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * nr * 0.6
		var g: Vector3 = d.map.ground_at(q.x, q.y)
		if g != Vector3.INF:
			pos = g
			break
	if pos == Vector3.INF:
		pos = _ground(nc, 0.0)
	var it := Interactable.new()
	it.setup("chest", "Largage", "res://assets/maps/objects/uc009.glb", "", 1.9, 3.0)
	it.set_meta("tier", Royale.DROP_TIER)
	it.used = true  # en l'air : ni le joueur ni les héros scriptés ne l'ouvrent avant l'atterrissage
	d.map.add_child(it)
	it.global_position = pos + Vector3.UP * 60.0
	it.add_beam(Color(1.0, 0.85, 0.35), 60.0)
	d.map.interactables.append(it)
	_chests.append(it)
	drops.append({"node": it, "land": elapsed + Royale.DROP_DELAY, "pos": pos})
	var tw := it.create_tween()
	tw.tween_property(it, "global_position", pos, Royale.DROP_DELAY).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	d.message.emit("Largage dans %d s : le meilleur coffre de la partie\nRepère doré sur la carte" % int(Royale.DROP_DELAY), 3.5)
	Sfx.ui("chest", -6.0)


## Atterrissage des largages annoncés.
func _update_drops() -> void:
	for dr in drops:
		var it = dr.node  # (pas de type : un largage ouvert finit libéré)
		if not is_instance_valid(it) or not it.used or it.has_meta("opened") or elapsed < float(dr.land):
			continue
		it.global_position = dr.pos
		it.used = false
		Vfx.ring(d, dr.pos + Vector3.UP * 0.2, 6.0, Color(1.0, 0.85, 0.35, 0.9))
		Sfx.event_at(d, dr.pos, "chest", 0.0)
		d.message.emit("Le largage a atterri !", 2.0)


## Largage encore à prendre (en l'air ou au sol) : {pos, land} ; {} : aucun.
func active_drop() -> Dictionary:
	for dr in drops:
		var it = dr.node
		if is_instance_valid(it) and not it.has_meta("opened"):
			return dr
	return {}


# --- coffres du joueur, objets cassés ----------------------------------------------------------
## Coffre de la carte ouvert par le joueur : une pièce à choisir parmi trois (niveau du héros), des potions, de
## l'expérience, parfois une carte.
func open_chest(it: Interactable) -> void:
	var p := d.player
	var tier := int(it.get_meta("tier", 0))
	var def: Dictionary = Royale.CHEST_TIERS[clampi(tier, 0, Royale.CHEST_TIERS.size() - 1)]
	it.set_meta("opened", true)
	it.open_chest()
	_claims.erase(it)
	Sfx.event_at(d, it.global_position, "chest", -2.0)
	chests_opened += 1
	d.chests_opened += 1
	Run.chests_total += 1
	Profile.record_add("chests", 1)
	d.message.emit("%s ouvert" % it.title, 1.5)
	if tier == Royale.DROP_TIER:
		feed("Tu t'empares du largage")
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
	if phase == "over":
		return
	if _breaker != null:
		# un héros scripté casse en passant : la même expérience que le joueur, parfois une potion
		if kind == "gold":
			return  # (le tas d'or ne donne rien au Battle royale, au joueur non plus)
		Royale.ai_award(_breaker, Royale.GEM_XP if kind == "gem" else Royale.BREAK_XP)
		if randf() < 0.04:
			var st: Dictionary = _breaker.get_meta("royale")
			st.potions = int(st.potions) + 1
		return
	if d.player.is_dead:
		return
	Profile.record_add("breakables", 1)
	match kind:
		"gem":
			if randf() < 0.5:
				d._drop_potion(pos, Potions.roll_kind())
			_give_levels(Royale.GEM_XP)
		"gold":
			pass
		_:
			if randf() < 0.05:
				d._drop_potion(pos, Potions.roll_kind())
			if randf() < 0.08 and d.player.hp < d.player.max_hp:
				d.player.heal(d.player.max_hp * 0.1)
				DamageNumber.spawn_text(d.player, "+PV", Color(0.5, 1.0, 0.55))
			_give_levels(Royale.BREAK_XP)


# --- repères ---------------------------------------------------------------------------------
## Lieux à montrer sur la mini-carte : les coffres proches (rayon de 80 m), les fontaines, le largage et le héros
## mis à prix (visibles de partout).
func markers() -> Array:
	var out: Array = []
	var pp := d.player.global_position
	for it in _chests:
		if not is_instance_valid(it):
			continue
		var tier := int((it as Interactable).get_meta("tier", 0))
		if tier == Royale.DROP_TIER:
			continue
		if not (it as Interactable).used and Vector2(it.global_position.x - pp.x, it.global_position.z - pp.z).length() < 80.0:
			out.append([it.global_position, "chest" if tier == 0 else "chest%d" % tier])
	for it in d.map.interactables:
		if is_instance_valid(it) and it.kind == "well" and not it.used:
			out.append([it.global_position, "well"])
	var dr := active_drop()
	if not dr.is_empty():
		out.append([dr.pos, "drop"])
	if bounty != null and is_instance_valid(bounty) and not bounty.is_dead and bounty != d.player:
		out.append([bounty.global_position, "bounty"])
	return out


## Cible du pilote automatique (tests) : le largage s'il est proche, sinon le coffre le plus proche dans l'anneau.
func farm_target() -> Vector3:
	var pp := d.player.global_position
	var dr := active_drop()
	if not dr.is_empty() and not _outside(dr.pos, 0.85) and Vector2(dr.pos.x - pp.x, dr.pos.z - pp.z).length() < 90.0:
		return dr.pos
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
		return "Largage des héros · %d" % maxi(0, ceili(_t))
	var n := mini(int(ring.get("phase", 0)) + 1, Royale.PHASES.size() - 1)
	match String(ring.get("state", "hold")):
		"hold":
			var left := ceili(float(ring.left))
			return "Anneau %d/%d · se referme dans %s" % [n, Royale.PHASES.size() - 1, "%d:%02d" % [left / 60, left % 60] if left >= 60 else "%d s" % left]
		"shrink":
			return "Anneau %d/%d · RESSERREMENT" % [n, Royale.PHASES.size() - 1]
	return "DERNIER CERCLE"


## Lignes du panneau d'objectifs (HUD).
func objective_lines() -> Array[String]:
	# trois lignes : les survivants sont déjà sous le titre, les potions dans la barre d'action
	var out: Array[String] = []
	if spectating:
		var who := watched.display_name.get_slice(" ·", 0) if watched != null and is_instance_valid(watched) else "—"
		out.append("◉ Tu regardes %s" % who)
		out.append("◇ [%s] : bilan de la partie" % Settings.action_label("pause", 1))
		return out
	out.append("⚔ Reste dans l'anneau violet")
	if bounty == d.player:
		out.append("★ Tu es mis à prix : tous te voient")
	elif not active_drop().is_empty():
		out.append("◆ Largage : repère doré sur la carte")
	else:
		out.append("◇ Coffres ouverts : %d · niveau %d / %d" % [chests_opened, d.player.level, Royale.LEVEL_CAP])
	out.append("◇ Chaque élimination : un niveau et des PV")
	return out


var _dbg_t := 0.0


## Ligne de suivi (pilote automatique, tests) : temps, anneau, vivants, niveaux (moyenne des héros scriptés en vie),
## coffres restants.
func _debug(delta: float) -> void:
	_dbg_t -= delta
	if _dbg_t > 0.0:
		return
	_dbg_t = 15.0
	var lv: Array = []
	var sum := 0.0
	var n := 0
	for st in ai_stats:
		var dead: bool = st.has("place")
		if not dead:
			sum += float(st.lv) + float(st.prog)
			n += 1
		lv.append("%s%d%s%s%d" % [String(st.cid).substr(0, 3), int(st.lv), "x" if dead else "", "" if dead else String(st.get("mode", "?")), int(st.chests)])
	print("[royale] %3.0f s · anneau %d %s r=%.0f · vivants %d · toi niv. %d (%d PV, %d coffres%s) · bots moy. %.1f · coffres restants %d · %s" % [elapsed,
		int(ring.phase) + 1, ring.state, float(ring.radius), alive_count(), d.player.level, int(d.player.hp), chests_opened, ", spectateur" if spectating else "",
		sum / maxf(n, 1.0), chests_left(), " ".join(lv)])
