class_name RoyaleDirector
extends Node
## Déroulement d'une partie de Battle royale (voir Royale) : la carte de Survie remplie de coffres, huit héros
## (le joueur et sept héros scripté) largués d'un aigle où chacun veut (RoyaleDrop, lot BR4), nus et au niveau 1, un anneau qui se
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
var phase := "drop"  # drop (largage, lot BR4), fight, over
## Secondes de combat : l'horloge de l'anneau, de la réanimation et du bilan. Elle part quand le dernier héros a
## atterri (ou au plus tard RoyaleDrop.LATE s après la fin du vol) : l'anneau ne bouge pas pendant le largage.
var elapsed := 0.0
## Secondes depuis le départ de l'aigle (largage compris) : horloge des coups (PvpCaps.elapsed) et du fil des éliminations.
var clock := 0.0
## Largage (lot BR4) : l'aigle et les héros à bord ou en l'air.
var jump: RoyaleDrop
## Réanimations en attente (lot BR4) : [{st: état du héros scripté (meta « royale ») ou {} pour le joueur, player, t: secondes}]
var revives: Array = []
var _player_revived := false
var ais: Array = []  # ClassRival (libérés à leur mort : toujours tester is_instance_valid)
var ai_stats: Array = []  # état de chaque héros scripté (meta « royale »), gardé après sa mort (bilan, mesures)
var centers: Array = []
var ring: Dictionary = {}
var chests_opened := 0
var rng := RandomNumberGenerator.new()
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
var recap_view: RoyaleRecap = null  # récapitulatif de mort et bandeau du spectateur (lot BR-I2)
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
	# largage (lot BR4) : tout le monde à bord de l'aigle, chacun saute où il veut
	jump = RoyaleDrop.new()
	jump.name = "RoyaleDrop"
	add_child(jump)
	jump.setup(d, rng, [p] + ais)
	jump.landed.connect(_on_landed)
	_build_walls()
	d.zone_changed.emit({"name": "Battle royale · %s" % d.zone.get("name", ""), "levels": [1, Royale.LEVEL_CAP]})
	d.message.emit("Battle royale\n%d héros, un seul survivant. Saute au-dessus d'un coffre !" % Royale.PLAYERS, 4.0)
	d.world._offer("Ton arme de %s : choisis sa variante" % String(GameData.weapon_type(Run.weapon_type()).get("name", "classe")).to_lower(),
		RoyaleLoot.start_weapon_cards(d.start_weapon_cards()))  # lot BR3 : armes du Survivant (jet, passif fixe)
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
	var classes: Array = GameData.classes.keys().filter(func(x): return x != Run.class_id and not x in Royale.AI_EXCLUDED)
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
	if phase != "over":
		clock += delta
		PvpCaps.elapsed = clock
		Royale.stats["clock"] = clock  # (lot BR-I2 : longueur de la chronologie du bilan)
	if jump != null:
		jump.update(delta)
	_tick_revives(delta)
	if phase == "drop":
		# largage : ceux qui ont atterri pillent (et se battent) ; l'anneau attend que tout le monde soit au sol
		_ai_orders(delta)
		_ai_breakables(delta)
		if jump == null or jump.count_airborne() == 0 or jump.t >= jump.duration + RoyaleDrop.LATE:
			if jump != null:
				jump.land_all()
			phase = "fight"
			d.message.emit("Tout le monde est au sol : l'anneau démarre !", 2.0)
	elif phase == "fight":
		elapsed += delta
		d.time = elapsed
		var was_phase := int(ring.get("phase", 0))
		var was_state := String(ring.get("state", ""))
		ring = Royale.ring_at(elapsed, centers)
		Royale.level_cap_now = Royale.level_cap(int(ring.phase))  # niveau maximal de l'anneau (lot BR1)
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
		_ai_orders(delta)
		_ai_breakables(delta)
		if spectating:
			_update_spectator()
		elif d.player.autoplay:
			d.player.autoplay_target = _ring_goal() if _outside(d.player.global_position, 0.92) else Vector3.INF
			_autoplay_pickup()
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
				d.message.emit("Anneau %d/%d : nouvelle zone marquée en blanc\nNiveau maximal : %d" % [int(ring.phase) + 1,
					Royale.PHASES.size() - 1, Royale.level_cap_now], 3.0)
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
	if phase == "drop":
		what = "Largage"
	return "Battle royale · %s\n%d / %d en vie · éliminations %d · coffres %d" % [what, alive_count(), Royale.PLAYERS, Royale.kills, chests_opened]


func alive_count() -> int:
	var n := 0 if d.player.is_dead else 1
	for a in ais:
		if is_instance_valid(a) and not a.is_dead:
			n += 1
	return n + revives.size()  # (un héros qui va revenir est encore en jeu)


## Héros scriptés éliminés qui vont revenir (lot BR4).
func pending_ais() -> int:
	return revives.filter(func(rv): return not rv.has("player")).size()


func _ai_orders(delta: float) -> void:
	_order_t -= delta
	if _order_t <= 0.0:
		_order_t = ORDER_EVERY
		for a in ais:
			if is_instance_valid(a) and not a.is_dead and not (jump != null and jump.airborne(a)):
				_order(a)


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
		if not is_instance_valid(m) or m.is_dead or (jump != null and jump.airborne(m)):
			continue
		if _outside(m.global_position):
			m.take_damage(maxf(1.0, m.max_hp * dps), null, false, true)
			if m == d.player and not m.is_dead and _warn_t <= 0.0:
				_warn_t = 3.0
				d.message.emit("Hors de l'anneau !\nSuis la flèche violette", 1.8)  # (lot BR-I1 : sans pourcentage ; la flèche montre la zone sûre)
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
	# une pièce tombée d'un héros éliminé, meilleure que la sienne et proche (lot BR3)
	if _ai_ground(r, pos):
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
	tag.text = "%s%s · niv. %d\nPV %s" % ["★ " if marked else "", r.display_name, r.level, Hud._big_number(ceilf(r.hp))]  # (lot BR-I2 : pas de pourcentage)
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
		if is_instance_valid(a) and not a.is_dead and not (jump != null and jump.airborne(a)):
			_breaker = a
			d.map.breakables.touch(a.global_position)
	_breaker = null


func _on_ai_died(who: Combatant, killer: Combatant) -> void:
	_release(who as ClassRival)
	who.clear_ffa()
	if phase == "over":
		return
	# réanimation (lot BR4) : tombé dans les deux premières minutes, il reviendra (pas encore de place) ; chaque
	# héros ne compte qu'une fois au compteur d'éliminations (sa première chute), l'expérience est donnée à chaque fois
	var st_r: Dictionary = who.get_meta("royale", {})
	var back := _can_revive(st_r)
	var first := not bool(st_r.get("counted", false))
	st_r["counted"] = true
	if back:
		st_r["revived"] = true
		revives.append({"st": st_r, "t": Royale.REVIVE_DELAY})
	var left := alive_count()
	if not back:
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
		var xp := Royale.kill_xp(killer.level, who.level, was_bounty)  # (lot BR1 : selon l'écart de niveau)
		_log_kill(killer, who)
		if killer == d.player:
			Royale.kills += 1 if first else 0
			d.player.gain_xp(maxi(1, ceili(float(GameData.xp_to_next(d.player.level)) * xp)))
			d.player.heal(d.player.max_hp * 0.25)
			line = "Tu élimines %s" % name
			if first:
				Profile.record_add("kills", 1)
				timeline_add("kill", name)  # (lot BR-I2 : la première seulement)
		elif killer is ClassRival and killer.has_meta("royale"):
			var kst: Dictionary = killer.get_meta("royale")
			kst.kills = int(kst.get("kills", 0)) + (1 if first else 0)
			Royale.ai_award(killer as ClassRival, xp)
			killer.heal(killer.max_hp * 0.25)
			line = "%s élimine %s" % [killer.display_name.get_slice(" ·", 0), name]
	if was_bounty:
		bounty = null
		line += " : la prime tombe"
	if back:
		line += " : il reviendra"
	feed(line)
	if not spectating and not back:
		d.message.emit("%d restant%s" % [left, "s" if left > 1 else ""], 1.6)
	if randf() < 0.7 or was_bounty:
		d._drop_potion(who.global_position, Potions.roll_kind())
	_fall(who)  # lot BR3 : ses pièces tombent (sauf l'arme), sa dépouille garde sa fiche
	if who == watched:
		watched = killer if killer != null and is_instance_valid(killer) and not killer.is_dead and killer != d.player else null
	_update_bounty()
	_check_end()


## Mesures (pilote automatique, lot BR1) : une ligne par élimination entre héros (niveaux, durée du combat).
func _log_kill(killer: Combatant, who: Combatant) -> void:
	if not d.player.autoplay:
		return
	var who_name := "joueur" if who == d.player else String(who.get_meta("royale", {}).get("cid", "?"))
	var killer_name := "joueur" if killer == d.player else String(killer.get_meta("royale", {}).get("cid", "?"))
	print("[royale] élimination %3.0f s : %s niv. %d -> %s niv. %d · combat %.0f s%s" % [elapsed, killer_name, killer.level, who_name, who.level,
		Royale.fight_time(killer, who), " · prime" if who == bounty else ""])


## Fil des éliminations (en haut à droite du HUD, Hud.feed) : les 4 dernières lignes.
var kill_feed: Array = []  # [texte, instant (clock)]


func feed(line: String) -> void:
	kill_feed.append([line, clock])
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
		timeline_add("bounty")
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
	left += pending_ais()  # (lot BR4 : ceux qui vont revenir sont encore en jeu)
	_place = left
	_down_at = elapsed
	var recap := death_recap(killer, left)  # (lot BR-I2 : avant que le vainqueur ne se soigne)
	_fall_player()  # lot BR3 : tes pièces tombent au sol (sauf l'arme)
	if killer != null and is_instance_valid(killer) and killer != d.player:
		_log_kill(killer, d.player)
		if killer is ClassRival and killer.has_meta("royale") and not killer.is_dead:
			# lot BR1 : le héros scripté qui t'élimine gagne comme pour un autre héros (expérience, PV, compteur une fois)
			var kst: Dictionary = killer.get_meta("royale")
			kst.kills = int(kst.get("kills", 0)) + (0 if _player_revived else 1)
			Royale.ai_award(killer as ClassRival, Royale.kill_xp(killer.level, d.player.level, d.player == bounty))
			killer.heal(killer.max_hp * 0.25)
			_update_bounty()
	if not _player_revived and _can_revive({}):
		# réanimation (lot BR4) : tombé dans les deux premières minutes, il revient une fois
		_player_revived = true
		_down_at = -1.0
		revives.append({"st": {}, "player": true, "t": Royale.REVIVE_DELAY})
		recap["revive"] = true
		_show_recap(recap)  # (lot BR-I2 : qui t'a eu, et le compte à rebours du retour ; plus de ligne « tu reviendras » dans le fil)
		return
	feed("Tu es éliminé (%de)" % left)
	timeline_add("down", "%de" % left)
	if left <= 2:
		_finish(left)  # un seul héros restant : il a gagné
		d.message.emit("Éliminé ! Tu termines %de sur %d" % [left, Royale.PLAYERS], 3.0)
		return
	spectating = true
	watched = killer if killer != null and is_instance_valid(killer) and not killer.is_dead else null
	d.player.autoplay_target = Vector3.INF
	_update_spectator()
	_show_recap(recap)  # lot BR-I2 : récapitulatif, puis le spectateur suit le tueur (◀ ▶ pour changer)


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
	# spectateur : [F] montre l'équipement du héros suivi (lot BR3)
	if spectating and phase != "over" and event.is_action_pressed("interact") and watched != null and is_instance_valid(watched) and watched.has_meta("royale"):
		get_viewport().set_input_as_handled()
		inspect(record_of(watched))
		return
	# spectateur : Échap / B ouvre le bilan (pas le menu pause : il n'y a plus rien à y faire)
	if spectating and phase != "over" and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		request_results()
		return
	# spectateur (lot BR-I2) : LB / RB (◀ ▶ au clavier) change de héros regardé
	if spectating and phase != "over":
		var step := 0
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
			match (event as InputEventJoypadButton).button_index:
				JOY_BUTTON_LEFT_SHOULDER:
					step = -1
				JOY_BUTTON_RIGHT_SHOULDER:
					step = 1
		elif event is InputEventKey and event.is_action_pressed("move_left"):
			step = -1
		elif event is InputEventKey and event.is_action_pressed("move_right"):
			step = 1
		if step != 0:
			get_viewport().set_input_as_handled()
			spectate_step(step)


## Spectateur : bilan tout de suite (Échap / B, bouton « Bilan » du récapitulatif).
func request_results() -> void:
	if not spectating or phase == "over":
		return
	_finish(_place)
	_end_t = 0.01


## Spectateur : héros suivant (+1) ou précédent (-1) parmi ceux encore en vie.
func spectate_step(dir: int) -> void:
	var alive: Array = ais.filter(func(a): return is_instance_valid(a) and not a.is_dead)
	if alive.is_empty():
		return
	var i := alive.find(watched)
	watched = alive[wrapi(i + dir, 0, alive.size())] if i >= 0 else alive[0]
	_update_spectator()
	Sfx.ui("click", -10.0)


## Récapitulatif de mort (lot BR-I2) : place, tueur (nom, classe, niveau, PV restants), coup de grâce (Royale.stats.last_hit
## s'il vient de lui), dégâts donnés et reçus, temps survécu. Sans tueur (ou lui-même) : l'anneau.
func death_recap(killer: Combatant, place: int) -> Dictionary:
	var r := {"place": place, "dealt": float(Royale.stats.get("dealt", 0.0)), "taken": float(Royale.stats.get("taken", 0.0)), "survived": elapsed,
		"name": "", "cid": "", "lv": 0, "killer_hp": -1, "move": "", "dmg": 0.0}
	if killer != null and is_instance_valid(killer) and killer != d.player:
		var st: Dictionary = killer.get_meta("royale", {})
		r.name = killer.display_name.get_slice(" ·", 0)
		r.cid = String(st.get("cid", ""))
		r.lv = int(st.get("lv", killer.level))
		r.killer_hp = maxi(1, ceili(killer.hp))
		var lh: Dictionary = Royale.stats.get("last_hit", {})
		if int(lh.get("id", 0)) == killer.get_instance_id():
			r.move = String(lh.get("move", ""))
			r.dmg = float(lh.get("dmg", 0.0))
	return r


## Montre le récapitulatif [param recap] (un seul à la fois).
func _show_recap(recap: Dictionary) -> void:
	_close_recap()
	if "--auto-quit" in OS.get_cmdline_user_args():
		return  # (mesures au pilote : pas d'interface)
	recap_view = RoyaleRecap.open(d.world, self, recap)
	recap_view.results_requested.connect(request_results)


func _close_recap() -> void:
	if recap_view != null and is_instance_valid(recap_view):
		recap_view.close()
	recap_view = null


## Moment de la partie pour la chronologie du bilan (Royale.stats.timeline), à l'horloge du largage.
func timeline_add(kind: String, text := "") -> void:
	Royale.timeline_add(kind, clock, text)


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
	_close_recap()
	if place == 1:
		timeline_add("win", "N°1")
	else:
		timeline_add("down", "%de" % place)  # (déjà noté s'il est tombé avant : une seule fois)
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
		var order: Array = ai_stats.map(func(st): return "%s:%d(niv.%d,%d élim.,%d coffres,%d pièces,note %.1f)" % [String(st.cid).substr(0, 6),
			int(st.get("place", 1)), int(st.lv), int(st.get("kills", 0)), int(st.chests), (st.gear as Dictionary).size(),
			Royale.gear_score(Royale.ai_gear(st.gear), String(st.cid), int(st.lv))])
		print("[royale] équipement du joueur : %d pièces portées, %d dans le sac, note %.1f" % [Profile.equipped.size(), Profile.inventory.size(),
			Royale.gear_score(Profile.equipped, Run.class_id, d.player.level)])
		print("[royale] fin : place %d · %d éliminations · niveau %d · %d coffres · joueur %.0f s · partie %.0f s · coffres restants %d · %s" % [place,
			Royale.kills, d.player.level, chests_opened, player_time(), elapsed, chests_left(), " ".join(order)])
	_end_t = 3.0


func chests_left() -> int:
	var n := 0
	for it in _chests:
		if is_instance_valid(it) and not (it as Interactable).used:
			n += 1
	return n


# --- largage et réanimation (lot BR4) --------------------------------------------------------------
## Un héros éliminé peut-il revenir ? Une fois, dans les Royale.REVIVE_WINDOW premières secondes de combat.
func _can_revive(st: Dictionary) -> bool:
	return phase != "over" and elapsed < Royale.REVIVE_WINDOW and not bool(st.get("revived", false))


func _tick_revives(delta: float) -> void:
	for rv in revives.duplicate():
		rv.t = float(rv.t) - delta
		if float(rv.t) > 0.0:
			continue
		revives.erase(rv)
		if phase == "over":
			continue
		if rv.has("player"):
			_revive_player()
		else:
			_revive_ai(rv.st)


## Revenant : il ne garde que son arme (ses pièces sont tombées au sol à sa chute, lot BR3).
static func keep_weapon(gear: Dictionary) -> Dictionary:
	return {"weapon": gear["weapon"]} if gear.has("weapon") else {}


func _revive_player() -> void:
	var p := d.player
	Profile.equipped = keep_weapon(Profile.equipped)
	Profile.inventory = Profile.inventory.filter(func(x): return x is Dictionary and String(x.get("slot", "")) == "weapon")
	var pt := revive_point()
	p.respawn(pt + Vector3.UP * RoyaleDrop.GLIDE_AT)
	Profile.changed.emit()  # (fiche du héros recalculée sans les pièces)
	p.recalc_stats()
	p.hp = p.max_hp
	p.health_changed.emit(p.hp, p.max_hp)
	p.set_meta("revive_shield", true)
	jump.drop_in(p, pt)
	if d.world.rig != null:
		d.world.rig.target = p
	feed("Tu reviens dans la partie")
	d.message.emit("De retour !\nPlus de seconde chance", 2.5)
	_close_recap()
	timeline_add("revive")


func _revive_ai(st: Dictionary) -> void:
	var k := ai_stats.find(st)
	if k < 0:
		return
	st.gear = keep_weapon(st.gear)
	st["mode"] = ""
	var r := Royale.make_ai(String(st.cid), int(st.diff), int(st.index))
	r.set_meta("royale", st)
	Royale.refresh_ai(r, false)
	d.add_child(r)
	r.set_ffa(int(st.index))
	r.died.connect(_on_ai_died)
	_tag(r)
	var pt := revive_point()
	r.global_position = pt + Vector3.UP * RoyaleDrop.GLIDE_AT
	r.set_meta("revive_shield", true)
	jump.drop_in(r, pt)
	ais[k] = r
	feed("%s revient dans la partie" % r.display_name.get_slice(" ·", 0))


## Point de retour d'un revenant : au sol, dans la zone sûre (le prochain anneau s'il se resserre), le plus loin
## possible des héros en vie.
func revive_point() -> Vector3:
	var shrinking := float(ring.next_radius) < float(ring.radius) - 1.0
	var c: Vector2 = ring.next_center if shrinking else ring.center
	var rad := (float(ring.next_radius) if shrinking else float(ring.radius)) * 0.75
	var others: Array = ([d.player] + ais).filter(func(m): return is_instance_valid(m) and not m.is_dead)
	var best := Vector3.INF
	var best_d := -1.0
	for i in 48:
		var q := c + Vector2.RIGHT.rotated(rng.randf() * TAU) * sqrt(rng.randf()) * rad
		var g: Vector3 = d.map.ground_at(q.x, q.y)
		if g == Vector3.INF:
			continue
		var near := INF
		for m in others:
			near = minf(near, Vector2((m as Node3D).global_position.x - q.x, (m as Node3D).global_position.z - q.y).length())
		if near > best_d:
			best_d = near
			best = g
	return best if best != Vector3.INF else _ground(c, d.map.height_at(c.x, c.y))


## Un héros a atterri (largage ou retour) : le revenant est invulnérable quelques secondes.
func _on_landed(c: Combatant) -> void:
	if c is ClassRival:
		_refresh_tag(c as ClassRival)
	if c == d.player and not c.has_meta("revive_shield"):
		var pl := place_at(c.global_position)  # lot BR-I2 : le lieu nommé où l'on atterrit
		if not pl.is_empty():
			d.message.emit("Tu atterris %s\n%s" % [String(pl.at), "★".repeat(int(pl.stars))], 2.5)
			timeline_add("jump", String(pl.name))
		else:
			timeline_add("jump", "")
	if not c.has_meta("revive_shield"):
		return
	c.remove_meta("revive_shield")
	if c is Player:
		(c as Player).shield_until = (c as Player)._time + Royale.REVIVE_SHIELD
	elif c is ClassRival:
		(c as ClassRival)._invuln_until = (c as ClassRival)._time + Royale.REVIVE_SHIELD
	Vfx.ring(c, c.global_position, 2.4, Color(0.5, 0.9, 1.0, 0.8))
	DamageNumber.spawn_text(c, "PROTÉGÉ", Color(0.6, 0.95, 1.0))


## Aide du largage et du retour (HUD, au centre en bas) ; vide : rien à afficher.
func drop_hint() -> String:
	for rv in revives:
		if rv.has("player"):
			return "Tu es éliminé : retour dans %d s" % maxi(1, ceili(float(rv.t)))
	return jump.hint() if jump != null else ""


## Le joueur est-il au sol (largage fini pour lui) ? Les coffres et objets cassables ne réagissent pas en l'air.
func player_grounded() -> bool:
	return jump == null or not jump.airborne(d.player)


# --- réapprovisionnement -------------------------------------------------------------------------
var _restocks := 0


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


## Coffre de la qualité [param tier] posé en [param pos] (le même que ceux de la carte, ProcMap.make_royale_chest).
func _spawn_chest(pos: Vector3, tier: int) -> Interactable:
	var it := ProcMap.make_royale_chest(tier)
	d.map.add_child(it)
	it.global_position = pos
	it.rotation.y = rng.randf() * TAU
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
	var it := ProcMap.make_royale_chest(Royale.DROP_TIER)
	it.used = true  # en l'air : ni le joueur ni les héros scriptés ne l'ouvrent avant l'atterrissage
	d.map.add_child(it)
	it.global_position = pos + Vector3.UP * 60.0
	# repère au point d'atterrissage (halo et faisceau au sol) ; l'aura du coffre ne s'allume qu'une fois posé
	var look: Dictionary = ProcMap.ROYALE_LOOKS[Royale.DROP_TIER]
	var mark := Interactable.make_aura(look.col, float(look.beam), float(look.halo), 0)
	d.map.add_child(mark)
	mark.global_position = pos
	it.tree_exited.connect(mark.queue_free)
	it.set_aura_visible(false)
	d.map.interactables.append(it)
	_chests.append(it)
	drops.append({"node": it, "land": elapsed + Royale.DROP_DELAY, "pos": pos})
	var tw := it.create_tween()
	tw.tween_property(it, "global_position", pos, Royale.DROP_DELAY).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		mark.queue_free()
		it.set_aura_visible(true))
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
		timeline_add("drop")
	# lot BR3 : une pièce par emplacement vide, puis des améliorations des pièces portées (l'arme de départ est gardée)
	var roll := func() -> Array:
		return RoyaleLoot.player_cards(tier, p.level)
	var gear_cards: Array = roll.call()
	if gear_cards.is_empty():
		d.world._offer("%s : choisis une carte" % it.title, Run.roll_cards(3), func(): return Run.roll_cards(3), 1)  # tout est au maximum
	else:
		var pieces := gear_cards.filter(func(c): return c.has("item")).size()
		d.world._offer("%s : %s" % [it.title, "choisis une pièce" if pieces == gear_cards.size() else ("améliore une pièce" if pieces == 0 else "une pièce ou une amélioration")],
			gear_cards, roll, 1)
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
		if not (it as Interactable).used and Vector2(it.global_position.x - pp.x, it.global_position.z - pp.z).length() < (80.0 if player_grounded() else 200.0):
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


## Lieux nommés de la carte (lot BR-I2, ProcMap.places) pour la mini-carte et la grande carte : [{name, at, kind, pos,
## stars (1 à 3 : richesse du butin), radius, aimed (héros scriptés encore en l'air qui y atterrissent)}].
func places() -> Array:
	var out: Array = []
	if d == null or not is_instance_valid(d.map):
		return out
	for pl in d.map.places:
		var e: Dictionary = (pl as Dictionary).duplicate()
		e.erase("cover")
		var c := Vector2(e.pos.x, e.pos.z)
		var n := 0
		if jump != null:
			for r in jump.riders:
				var t: Vector3 = jump.riders[r].target
				if r != d.player and jump.airborne(r) and t != Vector3.INF and Vector2(t.x, t.z).distance_to(c) <= float(e.radius) + 10.0:
					n += 1
		e["aimed"] = n
		out.append(e)
	return out


## Lieu nommé qui contient [param pos] ({} : aucun).
func place_at(pos: Vector3) -> Dictionary:
	if d == null or not is_instance_valid(d.map):
		return {}
	var best: Dictionary = {}
	var bd := INF
	for pl in d.map.places:
		var dd := Vector2(pl.pos.x - pos.x, pl.pos.z - pos.z).length()
		if dd <= float(pl.radius) + 12.0 and dd < bd:
			bd = dd
			best = pl
	return best


## Cible du pilote automatique (tests) : le largage s'il est proche, sinon le coffre le plus proche dans l'anneau.
func farm_target() -> Vector3:
	var pp := d.player.global_position
	var dr := active_drop()
	if not dr.is_empty() and not _outside(dr.pos, 0.85) and Vector2(dr.pos.x - pp.x, dr.pos.z - pp.z).length() < 90.0:
		return dr.pos
	var gp := _ground_for(Profile.equipped, Run.class_id, d.player.level, pp, 40.0)  # pièce tombée meilleure que la sienne (lot BR3)
	if not gp.is_empty():
		return (gp.bag as Node3D).global_position
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
	if phase == "drop":
		return "Largage · %d / %d au sol" % [Royale.PLAYERS - (jump.count_airborne() if jump != null else 0), Royale.PLAYERS]
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
		out.append("◉ Tu regardes %s" % who)  # (les touches sont sur le bandeau du spectateur, RoyaleRecap)
		return out
	if phase == "drop":
		out.append("◆ Saute au-dessus d'un coffre")
		out.append("◇ Personne ne frappe en l'air")
		out.append("◇ L'anneau part quand tous sont au sol")
		return out
	out.append("⚔ Reste dans l'anneau violet")
	if bounty == d.player:
		out.append("★ Tu es mis à prix : tous te voient")
	elif not active_drop().is_empty():
		out.append("◆ Largage : repère doré sur la carte")
	else:
		out.append("◇ Coffres ouverts : %d · niveau %d / %d" % [chests_opened, d.player.level, Royale.level_cap_now])
	out.append("◇ Élimine plus fort que toi : plus de niveaux")
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
	var note := 0.0
	for st in ai_stats:
		var dead: bool = st.has("place")
		if not dead:
			sum += float(st.lv) + float(st.prog)
			note += Royale.gear_score(Royale.ai_gear(st.gear), String(st.cid), int(st.lv))
			n += 1
		lv.append("%s%d%s%s%d" % [String(st.cid).substr(0, 3), int(st.lv), "x" if dead else "", "" if dead else String(st.get("mode", "?")), int(st.chests)])
	print("[royale] %3.0f s · anneau %d %s r=%.0f · vivants %d · toi niv. %d (%d PV, %d coffres%s) · bots moy. %.1f (équipement %.1f) · coffres restants %d · %s" % [elapsed,
		int(ring.phase) + 1, ring.state, float(ring.radius), alive_count(), d.player.level, int(d.player.hp), chests_opened, ", spectateur" if spectating else "",
		sum / maxf(n, 1.0), note / maxf(n, 1.0), chests_left(), " ".join(lv)])
	_log_force()


## Mesures (lot BR1) : force de chaque héros en vie, √(PV max × puissance de frappe) (Royale.strike), avec son niveau et
## ses coffres : l'issue d'un duel suit le rapport des forces (PvpCaps.damage_mult).
func _log_force() -> void:
	var out: Array = []
	for c in [d.player] + ais:
		if not is_instance_valid(c) or c.is_dead:
			continue
		var st: Dictionary = c.get_meta("royale", {})
		var n := chests_opened if c == d.player else int(st.get("chests", 0))
		out.append("%s:%d/%d/%.0f" % ["joueur" if c == d.player else String(st.get("cid", "?")), c.level, n, sqrt(c.max_hp * Royale.strike(c))])
	print("[royale] force %3.0f s · %s" % [elapsed, " ".join(out)])


# --- équipement des héros tombés (lot BR3) ------------------------------------------------------------
## Un héros scripté s'arrête pour une pièce tombée meilleure que la sienne à moins de GROUND_SIGHT m.
const GROUND_SIGHT := 35.0
## Héros tombés : {name, cid, lv, kills, place, gear (emplacement -> pièce à sa mort), bag (Interactable : sa dépouille, où
## sont ses pièces sauf l'arme, RoyaleLoot.make_bag), node_id} ; le joueur tombé a aussi la sienne (own : vrai).
var fallen: Array = []
## Dépouilles qui contiennent encore des pièces, ou vides (lot BR-I2 : un sac par héros tombé, plus de pièces éparpillées).
var ground: Array = []
var _sheet: RoyaleGearSheet = null


## Fiche d'un héros scripté, en vie ou tombé (RoyaleGearSheet).
func record_of(r: Combatant) -> Dictionary:
	for f in fallen:
		if int(f.get("node_id", 0)) == r.get_instance_id():
			return f
	var st: Dictionary = r.get_meta("royale", {})
	return {"name": r.display_name.get_slice(" ·", 0), "cid": String(st.get("cid", "")), "lv": int(st.get("lv", r.level)),
		"kills": int(st.get("kills", 0)), "place": int(st.get("place", 0)), "gear": st.get("gear", {})}


## Ouvre la fiche d'équipement [param rec] (une seule à la fois) ; avec une dépouille et le joueur debout : la fenêtre de
## pile (prendre une pièce, tout le meilleur).
func inspect(rec: Dictionary) -> void:
	if rec.is_empty() or (_sheet != null and is_instance_valid(_sheet) and _sheet.is_open()):
		return
	var take := Callable()
	if rec.get("bag") != null and is_instance_valid(rec.bag) and not d.player.is_dead and phase != "over":
		take = func(item: Dictionary): _player_take(rec.bag, item)
	_sheet = RoyaleGearSheet.open(d.world, rec, take)


## [F] près d'une dépouille : sa fenêtre de pile (RunDirector._interact).
func interact(it: Interactable) -> void:
	if it.kind == "remains":
		inspect(it.get_meta("record", {}))


## Un héros scripté tombe : sa dépouille garde ses pièces (sauf l'arme) et sa fiche.
func _fall(who: Combatant) -> void:
	if not who.has_meta("royale") or not is_instance_valid(d.map):
		return
	var st: Dictionary = who.get_meta("royale")
	var rec := record_of(who)
	rec["gear"] = (st.gear as Dictionary).duplicate()
	rec["place"] = int(st.get("place", 0))
	rec["lv"] = int(st.lv)
	rec["kills"] = int(st.get("kills", 0))
	rec["node_id"] = who.get_instance_id()
	_drop_bag(rec, RoyaleLoot.drops_of(st.gear), who.global_position, "Dépouille %s" % of_name(String(rec.name)))


## « de Paladin », « d'Ingénieur » (élision devant une voyelle).
static func of_name(name: String) -> String:
	var first := name.substr(0, 1).to_lower()
	return ("d'" if first in ["a", "e", "i", "o", "u", "y", "é", "è", "ê", "â", "î", "ô", "œ"] else "de ") + name


## Le joueur tombe : ses pièces portées (sauf l'arme) restent dans sa dépouille, à prendre par les autres (ou par lui à
## son retour).
func _fall_player() -> void:
	var items := RoyaleLoot.drops_of(Profile.equipped)
	if items.is_empty() or not is_instance_valid(d.map):
		return
	var rec := {"name": "Ta dépouille", "title": "Ta dépouille", "own": true, "cid": Run.class_id, "lv": d.player.level, "kills": Royale.kills,
		"place": maxi(_place, 1), "gear": Profile.equipped.duplicate()}
	RoyaleLoot.strip(items)  # (leurs passifs quittent la partie)
	_drop_bag(rec, items, d.player.global_position, "Ta dépouille")


func _drop_bag(rec: Dictionary, items: Array, pos: Vector3, title: String) -> void:
	var bag := RoyaleLoot.make_bag(d.map, items, pos, title)
	bag.set_meta("record", rec)
	rec["bag"] = bag
	d.map.interactables.append(bag)
	ground.append(bag)
	fallen.append(rec)


## Le joueur prend [param it] dans la dépouille [param bag] : elle est portée tout de suite (pièce du Survivant : jet
## ramené entre 100 et 120, passif fixe), la sienne rejoint la dépouille.
func _player_take(bag: Interactable, it: Dictionary) -> void:
	if not is_instance_valid(bag) or not RoyaleLoot.bag_items(bag).any(func(x): return is_same(x, it)):
		return
	RoyaleLoot.bag_take(bag, it)
	var worn := RoyaleLoot.wear(SurvivorGear.adopt(it, null, true))
	RoyaleLoot.bag_put(bag, worn)
	Sfx.ui("pickup", -6.0)
	d.message.emit("Pièce portée : %s" % Items.display_name(it), 1.6)


## Pièce d'une dépouille proche de [param pos] (moins de [param reach] m, dans l'anneau) qui bat celle de son emplacement
## dans [param gear] (la plus proche dépouille, son meilleur gain) : {bag, item} ; {} : aucune.
func _ground_for(gear: Dictionary, cid: String, lv: int, pos: Vector3, reach: float) -> Dictionary:
	var best := {}
	var bd := reach
	for bag in ground:
		if not is_instance_valid(bag) or RoyaleLoot.bag_items(bag).is_empty():
			continue
		var dd := Vector2(bag.global_position.x - pos.x, bag.global_position.z - pos.z).length()
		if dd >= bd or _outside(bag.global_position, 0.9):
			continue
		var ups := RoyaleLoot.bag_upgrades(bag, gear, cid, lv)
		if not ups.is_empty():
			bd = dd
			best = {"bag": bag, "item": ups[0]}
	return best


## Héros scripté : va prendre dans une dépouille proche une pièce meilleure que la sienne ; vrai s'il s'en occupe.
func _ai_ground(r: ClassRival, pos: Vector3) -> bool:
	var st: Dictionary = r.get_meta("royale")
	var pick := _ground_for(st.gear, String(st.cid), int(st.lv), pos, GROUND_SIGHT)
	if pick.is_empty():
		return false
	var bag: Interactable = pick.bag
	if Vector2(bag.global_position.x - pos.x, bag.global_position.z - pos.z).length() > RoyaleLoot.PICK_RANGE + 0.6:
		_release(r)
		r.goal = bag.global_position
		st["mode"] = "G"
		return true
	var it: Dictionary = pick.item
	var worn: Dictionary = st.gear.get(String(it.slot), {})
	RoyaleLoot.bag_take(bag, it)
	st.gear[String(it.slot)] = it
	RoyaleLoot.bag_put(bag, worn)
	Royale.refresh_ai(r)
	r.goal = Vector3.INF
	st["mode"] = "O"
	return true


## Pilote automatique : prend en passant une pièce meilleure que la sienne dans une dépouille.
func _autoplay_pickup() -> void:
	if ground.is_empty() or d.player.is_dead:
		return
	var pick := _ground_for(Profile.equipped, Run.class_id, d.player.level, d.player.global_position, RoyaleLoot.PICK_RANGE + 0.6)
	if not pick.is_empty():
		_player_take(pick.bag, pick.item)
