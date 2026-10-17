class_name RoyaleEvent
extends Node
## Événement de milieu de partie du Battle royale (lot BR-R1, backlog BM-BR P1 n° 13 : « autel gardé par un élite qui donne un
## coffre doré, annoncé au 2e anneau ») : l'autel du gardien. Un seul événement, le même à chaque partie, pour qu'on le
## reconnaisse ; il crée de l'action sans punir personne :
##   - au début du 2e anneau (AT_PHASE), un autel s'éveille dans la zone qui restera sûre jusqu'au 4e (pilier soleil visible de
##     loin, losange sur les cartes, annonce) ; un gardien (un héros scripté plus grand, plus solide, qui frappe moins fort) le garde ;
##   - le gardien ne quitte jamais l'autel (LEASH m) : il attaque qui s'approche, se remet quand personne n'est là ; on peut
##     l'ignorer sans rien perdre ;
##   - le vaincre : un niveau pour qui l'achève et le trésor de l'autel (un coffre de largage) posé sur place, à prendre (les
##     autres héros arrivent : c'est là que l'action se crée) ;
##   - au resserrement du 4e anneau (LEAVE_PHASE), s'il tient encore, le gardien s'en va et laisse le trésor à qui le prend.
## Les héros scriptés le jouent (RoyaleDirector._order -> [method ai_goal]) : Facile s'il passe à côté, les autres s'ils sont
## assez forts et en forme ; ils se battent ensuite contre lui comme contre un autre héros (et contre ceux qui arrivent).

const AT_PHASE := 1
const LEAVE_PHASE := 3
const LEASH := 13.0
const GUARD_ID := 90  # identifiant « chacun pour soi » du gardien (les héros : 0 à 7)
## Classes du gardien (corps à corps solides, silhouettes lisibles).
const GUARD_CLASSES := ["shielder", "templar", "paladin", "berserker"]
## Gardien : niveau = niveau médian des héros en vie + LEVEL_ADD (au plus le plafond de l'anneau) ; PV × HP_MULT, attaque ×
## ATK_MULT (mesurés : voir R_BRR1.md ; au plafond - 2, il tombait en 15 s sous les coups du pilote, avant que d'autres
## n'arrivent) ; sans personne à moins de LEASH m, il reprend REGEN de ses PV max par seconde.
const LEVEL_ADD := 3
const HP_MULT := 3.2
const ATK_MULT := 0.55
const REGEN := 0.05
const SCALE := 1.35
## Récompense de celui qui l'achève (en niveaux, en plus du trésor).
const KILL_LEVELS := 1.0
## Un scripté y va s'il est à moins de AI_REACH m, a au moins AI_HP de ses PV, et que son rapport de forces face au gardien à PV
## pleins (Royale.power_ratio) dépasse AI_RATIO[difficulté] ; le Facile seulement s'il passe à moins de EASY_REACH m.
const AI_REACH := 170.0
const AI_HP := 0.55
const AI_RATIO := [0.0, 0.4, 0.32, 0.25]
const EASY_REACH := 40.0
const TOWARD := 6.0  # s'arrête à cette distance de l'autel (le gardien vient au contact)

var rd: RoyaleDirector
var state := "wait"  # wait, awake (le gardien veille), won (vaincu, trésor posé), gone (parti, trésor libre)
var pos := Vector3.INF
var guardian: ClassRival = null
var treasure: Interactable = null
var winner := ""  # nom de celui qui l'a vaincu (« Toi » pour le joueur)
var player_won := false
## Mesures (pilote automatique, R_BRR1.md) : instants (secondes de combat) et visiteurs.
var awake_at := -1.0
var first_hit_at := -1.0
var end_at := -1.0
var hitters := {}  # id d'instance -> nom (héros qui l'ont frappé)
var deaths_near := 0  # héros éliminés près de l'autel pendant l'événement
var _altar: Node3D
var _plate: Label3D
var _tick := 0.0


func setup(director: RoyaleDirector) -> void:
	rd = director
	name = "RoyaleEvent"


## Appelé à chaque image de combat par le directeur.
func update(delta: float) -> void:
	if rd == null or rd.phase != "fight":
		return
	var ph := int(rd.ring.get("phase", 0))
	if state == "wait" and ph >= AT_PHASE:
		_awake()
	elif state == "awake":
		if ph > LEAVE_PHASE or (ph == LEAVE_PHASE and String(rd.ring.get("state", "")) == "shrink"):
			_leave()
			return
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.25
			_guard(0.25)


## Lieu de l'autel : dans le prochain anneau du prochain (il reste sûr jusqu'au 4e), au sol, loin des héros si possible.
func pick_spot() -> Vector3:
	var cs: Array = rd.centers
	var c: Vector2 = cs[mini(LEAVE_PHASE, cs.size() - 1)]
	var rad := float(Royale.PHASES[mini(LEAVE_PHASE - 1, Royale.PHASES.size() - 1)].radius) * 0.5
	var best := Vector3.INF
	var best_d := -1.0
	for i in 24:
		var q := c + Vector2.RIGHT.rotated(rd.rng.randf() * TAU) * sqrt(rd.rng.randf()) * rad
		var g: Vector3 = rd.d.map.ground_at(q.x, q.y)
		if g == Vector3.INF:
			continue
		var near := INF
		for m in [rd.d.player] + rd.ais:
			if is_instance_valid(m) and not m.is_dead:
				near = minf(near, Vector2((m as Node3D).global_position.x - q.x, (m as Node3D).global_position.z - q.y).length())
		near = minf(near, 60.0)  # (au-delà de 60 m, peu importe : on garde le plus central)
		var score := near - q.distance_to(c) * 0.15
		if score > best_d:
			best_d = score
			best = g
	return best if best != Vector3.INF else rd._ground(c, rd.d.map.height_at(c.x, c.y))


func _awake() -> void:
	pos = pick_spot()
	state = "awake"
	awake_at = rd.elapsed
	_build_altar()
	_spawn_guardian()
	rd.d.message.emit("L'autel s'éveille !\nUn gardien veille sur un trésor doré", 3.5)
	RoyaleCues.heard(pos, "drop")
	Sfx.ui("chest", -6.0)
	rd.feed("L'autel du gardien s'éveille")
	if rd.d.player.autoplay:
		print("[royale] autel %3.0f s : éveil · gardien %s niv. %d · %.0f PV · à %.0f m du joueur" % [rd.elapsed, String(guardian.cid), guardian.level,
			guardian.max_hp, Vector2(pos.x - rd.d.player.global_position.x, pos.z - rd.d.player.global_position.z).length()])


## Autel : socle de pierre, anneau d'or et pilier de lumière soleil (lisible de loin, comme le largage).
func _build_altar() -> void:
	_altar = Node3D.new()
	_altar.name = "RoyaleAltar"
	rd.d.map.add_child(_altar)
	_altar.global_position = pos
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("cfc6b4")
	stone.roughness = 0.9
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.6
	cyl.height = 0.5
	cyl.radial_segments = 8
	base.mesh = cyl
	base.material_override = stone
	base.position = Vector3(0, 0.25, 0)
	_altar.add_child(base)
	var top := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.2, 1.1, 1.2)
	top.mesh = box
	top.material_override = stone
	top.position = Vector3(0, 1.05, 0)
	_altar.add_child(top)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ffc928")
	gold.emission_enabled = true
	gold.emission = Color("ffb000") * 0.6
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 2.4
	tor.outer_radius = 2.62
	ring.mesh = tor
	ring.material_override = gold
	ring.position = Vector3(0, 0.52, 0)
	_altar.add_child(ring)
	var aura := Interactable.make_aura(Color("ff9a3d"), 70.0, 4.0, 8)
	_altar.add_child(aura)
	# zone gardée : cercle au sol (LEASH), pour qu'on sache où le gardien attaque
	var zone := MeshInstance3D.new()
	var zt := TorusMesh.new()
	zt.inner_radius = LEASH - 0.08
	zt.outer_radius = LEASH + 0.08
	zt.rings = 64
	zt.ring_segments = 4
	zone.mesh = zt
	var zm := StandardMaterial3D.new()
	zm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zm.albedo_color = Color(1.0, 0.6, 0.24, 0.32)
	zm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zone.mesh.material = zm
	zone.position = Vector3(0, 0.25, 0)
	zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_altar.add_child(zone)
	var l := OmniLight3D.new()
	l.light_color = Color("ffb35c")
	l.light_energy = 1.4
	l.omni_range = 12.0
	l.position = Vector3(0, 3.0, 0)
	_altar.add_child(l)


## Gardien : un héros scripté (Hardcore) d'une classe solide, au niveau de l'anneau, plus grand et plus solide, qui frappe moins.
func _spawn_guardian() -> void:
	var cid := String(GUARD_CLASSES[rd.rng.randi() % GUARD_CLASSES.size()])
	var lvs: Array = ([rd.d.player] + rd.ais).filter(func(m): return is_instance_valid(m) and not m.is_dead).map(func(m): return int(m.level))
	lvs.sort()
	var mid := int(lvs[lvs.size() / 2]) if not lvs.is_empty() else Royale.level_cap_now
	var lv := clampi(mid + LEVEL_ADD, 1, Royale.level_cap_now)
	var r := make_guardian(cid, lv)
	rd.d.add_child(r)
	r.global_position = pos + Vector3(0, 0.6, 3.0)
	r.set_ffa(GUARD_ID)
	r.goal = pos + Vector3(0, 0, 3.0)
	r.died.connect(_on_guardian_died)
	r.damaged.connect(_on_guardian_hit)
	if r.model != null:
		r.model.scale *= SCALE
		r._base_scale = r.model.scale  # (les effets d'écrasement reviennent à cette taille)
	guardian = r
	_plate = Label3D.new()
	_plate.name = "RoyaleTag"
	_plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plate.no_depth_test = true
	_plate.fixed_size = true
	_plate.pixel_size = 0.0011
	_plate.font_size = 26
	_plate.outline_size = 8
	_plate.outline_modulate = RoyaleHudStyle.INK
	_plate.modulate = Color("ffb35c")
	_plate.position = Vector3(0, 3.6, 0)
	_plate.visibility_range_end = 60.0
	r.add_child(_plate)
	_refresh_plate()


## Gardien de la classe [param cid] au niveau [param lv] (pas encore dans la scène) : la fiche d'un héros nu (Hardcore), PV ×
## HP_MULT, attaque × ATK_MULT. Sert aussi à la sonde tools/royale_duel_probe (--guardian).
static func make_guardian(cid: String, lv: int) -> ClassRival:
	var r := ClassRival.new()
	r.setup(cid, lv, 3)
	var h := Royale.sheet(cid, lv, {})
	r.use_sheet(h)
	h.free()
	r.max_hp *= HP_MULT
	r.hp = r.max_hp
	r.atk *= ATK_MULT
	r.travel_speed = Player.BASE_SPEED
	r.set_meta("guardian", true)
	r.display_name = "Gardien"  # (court : cadre de cible ; la plaque dit « Gardien de l'autel »)
	return r


func _refresh_plate() -> void:
	if _plate == null or not is_instance_valid(guardian):
		return
	_plate.text = "Gardien de l'autel · niv. %d\nPV %s" % [guardian.level, Hud._big_number(ceilf(guardian.hp))]


## Le gardien reste à l'autel : il vise le héros le plus proche dans sa zone, sinon il y retourne et se remet.
func _guard(dt: float) -> void:
	if not is_instance_valid(guardian) or guardian.is_dead:
		return
	var best: Combatant = null
	var bd := LEASH
	for f in Combatant.ffa_foes(get_tree(), guardian):
		var c := f as Combatant
		if rd.jump != null and rd.jump.airborne(c):
			continue
		var dd := Vector2(c.global_position.x - pos.x, c.global_position.z - pos.z).length()
		if dd < bd:
			bd = dd
			best = c
	var off := Vector2(guardian.global_position.x - pos.x, guardian.global_position.z - pos.z).length()
	if best != null and off < LEASH + 4.0:
		guardian.goal = Vector3.INF
		guardian._player = best
	else:
		guardian.goal = pos + Vector3(0, 0, 3.0)
		if best == null and guardian.hp < guardian.max_hp:
			guardian.heal(guardian.max_hp * REGEN * dt)
	_refresh_plate()


func _on_guardian_hit(_amount: float, by) -> void:
	if by == null or not is_instance_valid(by) or not (by is Combatant):
		return
	if first_hit_at < 0.0:
		first_hit_at = rd.elapsed
	hitters[(by as Combatant).get_instance_id()] = "joueur" if by == rd.d.player else String((by as Combatant).get_meta("royale", {}).get("cid", "?"))


func _on_guardian_died(who: Combatant, killer: Combatant) -> void:
	who.clear_ffa()
	if state != "awake":
		return
	state = "won"
	end_at = rd.elapsed
	var name := ""
	if killer != null and is_instance_valid(killer) and killer != who:
		if killer == rd.d.player:
			player_won = true
			name = "Toi"
			rd._give_levels(KILL_LEVELS)
			rd.d.player.heal(rd.d.player.max_hp * 0.25)
			Profile.record_add("royale_altars", 1)
			Royale.stats["altar"] = 1
			rd.timeline_add("altar", "Gardien")
		elif killer is ClassRival and killer.has_meta("royale"):
			name = killer.display_name.get_slice(" ·", 0)
			Royale.ai_award(killer as ClassRival, KILL_LEVELS)
			killer.heal(killer.max_hp * 0.25)
	winner = name
	_drop_treasure()
	if name == "Toi":
		rd.d.message.emit("Gardien vaincu !\nLe trésor de l'autel est à toi : prends-le vite", 3.0)
		rd.feed("Tu as vaincu le gardien")
	elif name != "":
		rd.d.message.emit("Gardien vaincu !\n%s s'empare de l'autel" % name, 3.0)
		rd.feed("%s a vaincu le gardien" % name)
	else:
		rd.d.message.emit("Le gardien est tombé !\nLe trésor de l'autel est libre", 3.0)
	_log("vaincu par %s" % (name if name != "Toi" else "joueur"))


## Au resserrement du 4e anneau, le gardien s'en va : le trésor reste à prendre.
func _leave() -> void:
	state = "gone"
	end_at = rd.elapsed
	if is_instance_valid(guardian) and not guardian.is_dead:
		guardian.clear_ffa()
		Vfx.ring(rd.d, guardian.global_position, 3.0, Color(1.0, 0.7, 0.35, 0.9))
		guardian.queue_free()
	guardian = null
	_drop_treasure()
	rd.d.message.emit("Le gardien s'en va !\nLe trésor de l'autel est libre", 3.0)
	_log("parti")


func _drop_treasure() -> void:
	if treasure != null:
		return
	treasure = rd._spawn_chest(pos + Vector3(0, 0, -1.6), Royale.DROP_TIER)
	treasure.title = "Trésor de l'autel"
	Vfx.ring(rd.d, pos + Vector3.UP * 0.2, 6.0, Color(1.0, 0.75, 0.35, 0.9))
	Sfx.event_at(rd.d, pos, "chest", 0.0)


func _log(what: String) -> void:
	if not rd.d.player.autoplay:
		return
	print("[royale] autel %3.0f s : %s · éveil %.0f s · 1er coup %s · %d héros l'ont frappé (%s) · %d éliminés près de l'autel" % [rd.elapsed, what,
		awake_at, ("%.0f s" % first_hit_at) if first_hit_at >= 0.0 else "aucun", hitters.size(), ",".join(hitters.values()), deaths_near])


## Le gardien veille-t-il encore ?
func active() -> bool:
	return state == "awake" and is_instance_valid(guardian) and not guardian.is_dead


## Le trésor de l'autel est-il encore à prendre ?
func treasure_open() -> bool:
	return treasure != null and is_instance_valid(treasure) and not treasure.used


## Point où le héros scripté [param r] doit aller pour l'autel (Vector3.INF : il ne s'en occupe pas).
func ai_goal(r: ClassRival, st: Dictionary) -> Vector3:
	if not active():
		return Vector3.INF
	var diff := clampi(int(st.get("diff", 1)), 0, 3)
	var dd := Vector2(r.global_position.x - pos.x, r.global_position.z - pos.z).length()
	if dd > (EASY_REACH if diff == 0 else AI_REACH) or r.hp < r.max_hp * AI_HP:
		return Vector3.INF
	# rapport de forces face au gardien à PV pleins (le gardien se remet quand personne n'est là)
	var ratio := (r.hp * Royale.strike(r)) / maxf(guardian.max_hp * Royale.strike(guardian), 0.001)
	if diff > 0 and ratio < float(AI_RATIO[diff]):
		return Vector3.INF
	if dd <= TOWARD:
		return Vector3.INF  # au contact : le combat ordinaire prend le relais
	var to := Vector2(r.global_position.x - pos.x, r.global_position.z - pos.z).normalized() * (TOWARD - 1.0)
	return Vector3(pos.x + to.x, pos.y, pos.z + to.y)


## Héros éliminé (mesures) : près de l'autel pendant l'événement ?
func note_death(at: Vector3) -> void:
	if state == "awake" and Vector2(at.x - pos.x, at.z - pos.z).length() < LEASH + 10.0:
		deaths_near += 1


## Repère pour les cartes : [position, sorte] ou [].
func marker() -> Array:
	if active():
		return [pos, "altar"]
	if treasure_open():
		return [treasure.global_position, "altar"]
	return []


## Ligne de l'objectif (HUD) : "" quand il n'y a rien à dire.
func objective() -> String:
	if active():
		return "◆ Autel : bats le gardien, trésor doré"
	if treasure_open():
		return "◆ Le trésor de l'autel est à prendre"
	return ""
