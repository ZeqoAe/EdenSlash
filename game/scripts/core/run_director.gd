class_name RunDirector
extends Node3D
## Déroulement d'une run sur une map générée (voir DESIGN.md) :
## 10 minutes d'exploration et de farm, puis la rage ; le donjon est accessible
## dès que son entrée est découverte et mène à l'arène du boss.

signal message(text: String, duration: float)
signal zone_changed(zone: Dictionary)
signal objective_changed(text: String)
signal prompt_changed(text: String)
signal npc_opened(kind: String, npc: Interactable)
signal boss_defeated

const RUN_TIME := 600.0
const DISCOVER_VILLAGE := 45.0
const DISCOVER_DUNGEON := 32.0
const DISCOVER_CHEST := 18.0
const CAMP_ACTIVATE := 55.0
const CAMP_RESPAWN := 40.0
const BOSS_ADDS_EVERY := 14.0
const FOG_RES := 128
## Niveau maximal du butin par zone : la map 1 ne donne pas d'équipement au-delà du
## niveau 15 (les maps suivantes prendront le relais). Les monstres plafonnent au
## même niveau, +3 pendant la rage (plus durs, mais le butin reste plafonné).
const ZONE_MAX_LEVEL := {"limestone": 15}
const RAGE_LEVEL_BONUS := 3

var world: Node  # world.gd
var map  # ProcMap
var player: Player
var state := "explore"  # explore, rage, boss, cleared
var zone: Dictionary
var kills := 0
var time := 0.0
var village_found := false
var dungeon_found := false
var chests_opened := 0
var route := PackedVector3Array()

var _camp_ready_at := {}  # index de camp -> instant
var _roam_timer := 2.0
var _wave_timer := 60.0
const EARLY_RAMP := 180.0  # durée de la montée en puissance du début de run (s)
const EARLY_EASE := 0.6  # PV et dégâts des monstres au tout début (×)
var _wave_hard := false
var seals := 0
const SEALS_NEEDED := 3
var _elite_timer := 25.0
var _adds_timer := BOSS_ADDS_EVERY
var _route_timer := 0.0
var _objective_timer := 0.0
var _boss: Monster
var _near: Interactable
var _last_safe := Vector3.ZERO
var _trail: MultiMeshInstance3D
var _fog: Image
var _fog_tex: ImageTexture
var _fog_timer := 0.0
var _roster: Array = []  # monstres normaux de la zone, par niveau
var _elites: Array = []
var _seed := 0


func start(p: Player) -> void:
	player = p
	zone = GameData.zones[0]
	_roster = zone.monsters.map(func(x): return int(x))
	_elites = zone.get("elites", []).map(func(x): return int(x))
	_seed = Run.seed if Run.seed != 0 else randi()
	map = world.new_run_map(_seed)
	_place_player(map.start)
	_fog = Image.create(FOG_RES, FOG_RES, false, Image.FORMAT_LA8)
	_fog.fill(Color(0, 0, 0, 1))
	_fog_tex = ImageTexture.create_from_image(_fog)
	zone_changed.emit({"name": zone.name, "levels": [int(zone.levels[0]), max_level()]})
	message.emit("%s\nTrouve le village et l'entrée du donjon" % zone.name, 3.5)


func _place_player(pos: Vector3) -> void:
	player.global_position = pos + Vector3.UP * 0.6
	player.velocity = Vector3.ZERO
	_last_safe = player.global_position


func time_left() -> float:
	return maxf(0.0, RUN_TIME - time)


func in_dungeon() -> bool:
	return state in ["boss", "cleared"]


# --- boucle -----------------------------------------------------------------------------
func _process(delta: float) -> void:
	if player == null or map == null:
		return
	time += delta
	if state == "explore" and time >= RUN_TIME:
		_start_rage()
	match state:
		"explore", "rage":
			_update_discovery()
			_update_spawns(delta)
		"boss":
			_update_boss(delta)
	_update_interactions()
	_update_fog(delta)
	_update_route(delta)
	_objective_timer -= delta
	if _objective_timer <= 0.0:
		_objective_timer = 0.25
		objective_changed.emit(_objective_text())
	_keep_on_map()


func _objective_text() -> String:
	if state == "boss":
		return "Vaincs %s !" % (_boss.display_name if is_instance_valid(_boss) else "le boss")
	if state == "cleared":
		return "Boss vaincu !"
	var t := time_left()
	var clock := "RAGE !" if state == "rage" else "%02d:%02d avant la rage" % [int(t) / 60, int(t) % 60]
	return "%s\nVillage %s   ·   Donjon %s   ·   Sceaux %d/%d   ·   Coffres %d/%d" % [clock,
		"✔" if village_found else "?", "✔" if dungeon_found else "?", seals, SEALS_NEEDED,
		chests_opened, map.chests.size()]


func _start_rage() -> void:
	state = "rage"
	message.emit("LES MONSTRES ENTRENT EN RAGE !\nDanger accru, butin et XP accrus", 4.0)
	world.set_rage_mood(true)
	for node in get_tree().get_nodes_in_group("monsters"):
		(node as Monster).enrage()


# --- découvertes et interactions ---------------------------------------------------------
func _update_discovery() -> void:
	var p := player.global_position
	if not village_found and _flat(p, map.village) < DISCOVER_VILLAGE:
		village_found = true
		message.emit("Village découvert !\nMarchand, forgeron et boutique", 3.0)
	if not dungeon_found and _flat(p, map.dungeon) < DISCOVER_DUNGEON:
		dungeon_found = true
		message.emit("Entrée du donjon découverte !\n[F] pour affronter le boss quand tu es prêt", 3.5)


func _update_interactions() -> void:
	var best: Interactable = null
	var best_d := INF
	for it in map.interactables:
		if not is_instance_valid(it) or it.used:
			continue
		var d := _flat(player.global_position, it.global_position)
		if d < it.radius and d < best_d:
			best = it
			best_d = d
	if best != _near:
		_near = best
		prompt_changed.emit(best.prompt() if best else "")
	if best == null:
		return
	if Input.is_action_just_pressed("interact") or (player.autoplay and best.kind in ["chest", "dungeon"]):
		_interact(best)


func _interact(it: Interactable) -> void:
	match it.kind:
		"chest":
			it.open_chest()
			chests_opened += 1
			var luck := 0.25 + (0.25 if state == "rage" else 0.0)
			for k in 2:
				_drop_item(it.global_position, _monster_level(1), luck)
			Run.add_gold(15 + player.level * 4)
			message.emit("Coffre ouvert !", 1.5)
		"dungeon":
			# le bot de test (--boss-after) ignore les sceaux
			if seals < SEALS_NEEDED and not (player.autoplay and time > _autoplay_dungeon_time()):
				message.emit("L'entrée est scellée : %d/%d sceaux\nLes gardiens d'élite les portent" % [seals, SEALS_NEEDED], 3.0)
				_near = null
				return
			_enter_arena()
		_:
			npc_opened.emit(it.kind, it)
	_near = null
	prompt_changed.emit("")


# --- monstres --------------------------------------------------------------------------
## Niveau des monstres : monte avec le temps, +3 en rage, +palier du camp.
func _monster_level(tier: int) -> int:
	var base := 1.0 + time / 60.0 * 0.9 + (float(RAGE_LEVEL_BONUS) if state == "rage" else 0.0)
	var cap := max_level() + (RAGE_LEVEL_BONUS if state in ["rage", "boss"] else 0)
	return clampi(roundi(maxf(base, player.level - 1.0) + tier), 1, cap)


## Niveau maximal du butin et des monstres (hors rage) de la zone en cours.
func max_level() -> int:
	return int(zone.get("max_level", ZONE_MAX_LEVEL.get(String(zone.get("id", "")), 30)))


## Niveau d'un objet donné dans cette zone (plafonné).
func loot_level(level: int) -> int:
	return clampi(level, 1, max_level())


func _pick_monster(level: int) -> int:
	var options := _roster.filter(func(id): return int(GameData.monster(id).level) <= level)
	if options.is_empty():
		options = [_roster[0]]
	# on privilégie les monstres les plus forts disponibles
	return options[mini(options.size() - 1, options.size() - 1 - randi() % mini(3, options.size()))]


## Pression constante : un flux de packs qui fonce sur le héros, des vagues qui
## alternent faciles (nombreux et faibles) et dures (encerclement + élite), et
## les gardiens d'élite des camps qui portent les sceaux du donjon.
func _update_spawns(delta: float) -> void:
	var rage := state == "rage"
	var minutes := time / 60.0
	var alive := get_tree().get_nodes_in_group("monsters").size()
	var cap := 120 if rage else mini(18 + int(minutes * 4.0), 50)
	# gardiens d'élite des camps (une fois chacun, puis toutes les 2 min)
	for k in map.camps.size():
		var camp: Dictionary = map.camps[k]
		if not camp.elite or _elites.is_empty():
			continue
		if _flat(player.global_position, camp.pos) > CAMP_ACTIVATE or time < float(_camp_ready_at.get(k, 0.0)):
			continue
		_camp_ready_at[k] = time + 120.0
		var lvl := _monster_level(int(camp.tier) + 1)
		var e := _spawn_monster(_elites.pick_random(), camp.pos, lvl)
		e.carries_seal = true
		for i in 4:
			_spawn_monster(_pick_monster(lvl), _around(camp.pos, 6.0), lvl)
		message.emit("Un gardien d'élite garde un sceau !", 2.0)
	# flux continu
	_roam_timer -= delta
	if _roam_timer <= 0.0 and alive < cap:
		_roam_timer = randf_range(1.8, 2.6) if rage else maxf(3.5, 6.0 - minutes * 0.3)
		var size := randi_range(8, 12) if rage else mini(4 + int(minutes), 9) + randi_range(0, 2)
		_spawn_pack(size, _monster_level(0), 20.0, 28.0)
	# vagues
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = 30.0 if rage else 45.0
		_wave_hard = not _wave_hard
		var lvl := _monster_level(1)
		if _wave_hard:
			message.emit("Vague : encerclement !", 2.0)
			# anneau complet autour du héros, plus une élite
			var n := 10 + int(minutes * 2.0) + (8 if rage else 0)
			for i in n:
				var a := TAU * i / n
				var p := player.global_position + Vector3(cos(a), 0, sin(a)) * 18.0
				var g: Vector3 = map.ground_at(p.x, p.z)
				if g != Vector3.INF:
					_spawn_monster(_pick_monster(lvl), g, lvl)
			var ep := _ring_point(18.0, 22.0)
			if not _elites.is_empty() and ep != Vector3.INF:
				_spawn_monster(_elites.pick_random(), ep, lvl)
		else:
			message.emit("Vague : horde !", 1.6)
			for k in 3:
				_spawn_pack(6 + int(minutes), maxi(1, lvl - 2), 22.0, 30.0)
	# élites en masse pendant la rage
	if rage and not _elites.is_empty():
		_elite_timer -= delta
		if _elite_timer <= 0.0:
			_elite_timer = 22.0
			var c := _ring_point(24.0, 34.0)
			if c != Vector3.INF:
				for i in 3:
					_spawn_monster(_elites.pick_random(), _around(c, 5.0), _monster_level(1))
				message.emit("Des élites enragées arrivent !", 2.0)


func _spawn_pack(count: int, level: int, min_d: float, max_d: float) -> void:
	var center := _ring_point(min_d, max_d)
	if center == Vector3.INF:
		return
	var id := _pick_monster(level)
	for i in count:
		_spawn_monster(id if randf() < 0.7 else _pick_monster(level), _around(center, 4.0), level)


func _spawn_monster(id: int, pos: Vector3, level: int, boss := false) -> Monster:
	var m := Monster.new()
	m.configure(GameData.monster(id), boss, level)
	if state == "explore":
		# montée en puissance sur les 3 premières minutes : la run démarre sans
		# équipement, le joueur doit pouvoir apprendre avant que ça devienne punitif
		var k := lerpf(EARLY_EASE, 1.0, clampf(time / EARLY_RAMP, 0.0, 1.0))
		m.max_hp *= k
		m.hp = m.max_hp
		m.atk *= k
	add_child(m)
	m.global_position = pos + Vector3.UP * 0.4
	m.rotation.y = randf() * TAU
	if state == "rage":
		m.enrage()
	m.died.connect(_on_monster_died)
	return m


func _around(c: Vector3, r: float) -> Vector3:
	for attempt in 6:
		var p := c + Vector3(randf_range(-r, r), 0, randf_range(-r, r))
		var g: Vector3 = map.ground_at(p.x, p.z)
		if g != Vector3.INF:
			return g
	return c


func _ring_point(min_d: float, max_d: float) -> Vector3:
	for attempt in 20:
		var a := randf() * TAU
		var p := player.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(min_d, max_d)
		var g: Vector3 = map.ground_at(p.x, p.z)
		if g != Vector3.INF:
			return g
	return Vector3.INF


func _on_monster_died(who: Combatant, _killer: Combatant) -> void:
	kills += 1
	var m := who as Monster
	player.gain_xp(m.xp_reward)
	Run.kills += 1
	if m.is_elite:
		Run.elites += 1
	Run.add_gold(2 + m.level * (3 if m.is_elite else 1))
	if seals < SEALS_NEEDED and (m.carries_seal or (m.is_elite and randf() < 0.3)):
		seals += 1
		message.emit("Sceau du donjon obtenu (%d/%d)" % [seals, SEALS_NEEDED], 2.5)
	var luck := 0.0
	var count := 0
	if m.is_boss:
		count = 3
		luck = 0.5
	elif m.is_elite:
		count = 1
		luck = 0.3
	elif randf() < (0.08 if m.enraged else 0.05):
		count = 1
	if m.enraged:
		luck += 0.2
	for i in count:
		_drop_item(m.global_position, m.level, luck)
	if m == _boss:
		_on_boss_killed()


func _drop_item(pos: Vector3, level: int, luck: float) -> void:
	var drop := LootDrop.new()
	drop.item = Items.generate(loot_level(level), luck, "", Run.class_id)
	drop.on_picked = func(item): message.emit("Butin : %s" % item.name, 1.5)
	add_child(drop)
	var p := pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	var g: Vector3 = map.ground_at(p.x, p.z)
	drop.global_position = (g if g != Vector3.INF else pos) + Vector3.UP * 0.2


func _clear_monsters() -> void:
	for node in get_tree().get_nodes_in_group("monsters"):
		node.remove_from_group("monsters")
		node.queue_free()


# --- boss -----------------------------------------------------------------------------
func _enter_arena() -> void:
	print("[run] entrée dans l'arène à %.0f s, niveau %d" % [time, player.level])
	state = "boss"
	_clear_monsters()
	map = world.new_arena_map(_seed)
	_place_player(map.start)
	player.heal(player.max_hp)
	world.set_dungeon_mood(true)
	player.set_torch(true)
	route = PackedVector3Array()
	var boss_id := int(zone.dungeon.boss)
	var c := Vector3(map.size * 0.5, 0, map.size * 0.5)
	c.y = map.height_at(c.x, c.z)
	_boss = _spawn_monster(boss_id, c, mini(maxi(player.level + 1, _monster_level(2)), max_level() + RAGE_LEVEL_BONUS), true)
	_boss.display_name = "<Boss> " + _boss.display_name
	if _boss.brain:
		_boss.brain.enraged_phase.connect(func(): message.emit("%s entre en fureur !" % _boss.display_name, 2.5))
		_boss.reflect_started.connect(func(): message.emit("Miroir ! Ne frappe pas pendant 3 s", 2.0))
	message.emit("BOSS : %s
Évite les zones rouges (Maj : esquive)" % _boss.display_name, 3.5)


func _update_boss(delta: float) -> void:
	if not is_instance_valid(_boss) or _boss.is_dead:
		return
	_adds_timer -= delta
	if _adds_timer <= 0.0:
		_adds_timer = BOSS_ADDS_EVERY
		var lvl := maxi(1, _boss.level - 2)
		for i in 4:
			var a := TAU * i / 4.0 + randf()
			var p := _boss.global_position + Vector3(cos(a), 0, sin(a)) * 8.0
			var m := _spawn_monster(_pick_monster(lvl), _around(p, 2.0), lvl)


func _on_boss_killed() -> void:
	print("[run] boss vaincu à %.0f s, niveau %d" % [time, player.level])
	state = "cleared"
	message.emit("Boss vaincu !\nRamasse le butin", 3.0)
	await get_tree().create_timer(6.0).timeout
	boss_defeated.emit()


# --- divers ----------------------------------------------------------------------------
func revive_point() -> Vector3:
	if state in ["boss", "cleared"]:
		return map.start + Vector3.UP * 0.6
	var best: Vector3 = map.start
	if village_found and _flat(player.global_position, map.village) < _flat(player.global_position, best):
		best = map.village + Vector3(4, 0, 0)
	return best + Vector3.UP * 0.6


func objective_target() -> Vector3:
	if state in ["explore", "rage"] and dungeon_found:
		for p in route:
			if _flat(p, player.global_position) > 4.0:
				return p
		return map.dungeon
	return Vector3.INF


func _update_route(delta: float) -> void:
	_route_timer -= delta
	if _route_timer > 0.0:
		return
	_route_timer = 0.5
	var show: bool = state in ["explore", "rage"] and dungeon_found
	if not show:
		route = PackedVector3Array()
		if _trail and is_instance_valid(_trail):
			_trail.visible = false
		player.autoplay_target = map.dungeon if player.autoplay and state != "boss" and time > _autoplay_dungeon_time() else Vector3.INF
		return
	route = map.path_between(player.global_position, map.dungeon)
	player.autoplay_target = objective_target() if player.autoplay and time > _autoplay_dungeon_time() else Vector3.INF
	_draw_trail()


## Bot de test : va au donjon après un temps de farm (option --boss-after=N).
func _autoplay_dungeon_time() -> float:
	return world.autoplay_boss_after


func _draw_trail() -> void:
	if _trail == null or not is_instance_valid(_trail):
		_trail = MultiMeshInstance3D.new()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var orb := SphereMesh.new()
		orb.radius = 0.2
		orb.height = 0.4
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.85, 0.4)
		orb.material = mat
		mm.mesh = orb
		_trail.multimesh = mm
		_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		map.add_child(_trail)
	var points: Array[Vector3] = []
	var acc := 0.0
	for i in range(1, route.size()):
		var a := route[i - 1]
		var b := route[i]
		var seg := a.distance_to(b)
		var t := 3.0 - acc
		while t < seg and points.size() < 12:
			points.append(a.lerp(b, t / seg) + Vector3.UP * 0.4)
			t += 3.0
		acc = seg - (t - 3.0)
		if points.size() >= 12:
			break
	_trail.multimesh.instance_count = points.size()
	for i in points.size():
		_trail.multimesh.set_instance_transform(i, Transform3D(Basis(), points[i]))
	_trail.visible = true


## Brouillard de la mini-carte : révélé autour du héros.
func _update_fog(delta: float) -> void:
	_fog_timer -= delta
	if _fog_timer > 0.0 or state in ["boss", "cleared"]:
		return
	_fog_timer = 0.25
	var k: float = FOG_RES / map.size
	var c := Vector2(player.global_position.x, player.global_position.z) * k
	var r := 48.0 * k
	var changed := false
	for y in range(maxi(0, int(c.y - r)), mini(FOG_RES, int(c.y + r) + 1)):
		for x in range(maxi(0, int(c.x - r)), mini(FOG_RES, int(c.x + r) + 1)):
			var d := Vector2(x, y).distance_to(c) / r
			if d < 1.0:
				var a := _fog.get_pixel(x, y).a
				var na := minf(a, smoothstep(0.7, 1.0, d))
				if na < a:
					_fog.set_pixel(x, y, Color(0, 0, 0, na))
					changed = true
	if changed:
		_fog_tex.update(_fog)


func fog_texture() -> Texture2D:
	return null if state in ["boss", "cleared"] else _fog_tex


## Lieux connus à afficher sur la mini-carte : [position, type].
func markers() -> Array:
	var out: Array = []
	if state in ["boss", "cleared"]:
		return out
	if village_found:
		out.append([map.village, "village"])
	if dungeon_found:
		out.append([map.dungeon, "dungeon"])
	for it in map.interactables:
		if is_instance_valid(it) and it.kind == "chest" and not it.used and _flat(player.global_position, it.global_position) < DISCOVER_CHEST * 3.0:
			out.append([it.global_position, "chest"])
	return out


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _keep_on_map() -> void:
	var p := player.global_position
	if player.is_on_floor():
		_last_safe = p
	elif p.y < _last_safe.y - 25.0:
		player.global_position = _last_safe + Vector3.UP * 0.5
		player.velocity = Vector3.ZERO
		return
	var b: Rect2 = map.bounds.grow(-3.0)
	var x := clampf(p.x, b.position.x, b.end.x)
	var z := clampf(p.z, b.position.y, b.end.y)
	if x != p.x or z != p.z:
		player.global_position = Vector3(x, p.y, z)


# --- outils de test --------------------------------------------------------------------
func debug_enter_dungeon() -> void:
	if state in ["explore", "rage"]:
		dungeon_found = true
		seals = SEALS_NEEDED
		_enter_arena()


func teleport_to_gateway() -> bool:
	if state in ["boss", "cleared"]:
		return false
	_place_player(map.dungeon + Vector3(3, 0, 3))
	return true


func debug_start_rage() -> void:
	if state == "explore":
		time = RUN_TIME
