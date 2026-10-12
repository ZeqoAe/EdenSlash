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
var _roam_timer := 3.0
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
	zone_changed.emit({"name": zone.name, "levels": zone.levels})
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
	return "%s\nVillage %s   ·   Donjon %s   ·   Coffres %d/%d" % [clock,
		"✔" if village_found else "?", "✔" if dungeon_found else "?",
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
			_enter_arena()
		_:
			npc_opened.emit(it.kind, it)
	_near = null
	prompt_changed.emit("")


# --- monstres --------------------------------------------------------------------------
## Niveau des monstres : monte avec le temps, +3 en rage, +palier du camp.
func _monster_level(tier: int) -> int:
	var base := 1.0 + time / 60.0 * 0.9 + (3.0 if state == "rage" else 0.0)
	return clampi(roundi(maxf(base, player.level - 1.0) + tier), 1, 30)


func _pick_monster(level: int) -> int:
	var options := _roster.filter(func(id): return int(GameData.monster(id).level) <= level)
	if options.is_empty():
		options = [_roster[0]]
	# on privilégie les monstres les plus forts disponibles
	return options[mini(options.size() - 1, options.size() - 1 - randi() % mini(3, options.size()))]


func _update_spawns(delta: float) -> void:
	var rage := state == "rage"
	var alive := get_tree().get_nodes_in_group("monsters").size()
	var cap := 90 if rage else 32
	# camps fixes de la map
	for k in map.camps.size():
		var camp: Dictionary = map.camps[k]
		if _flat(player.global_position, camp.pos) > CAMP_ACTIVATE or time < float(_camp_ready_at.get(k, 0.0)):
			continue
		_camp_ready_at[k] = time + CAMP_RESPAWN * (0.5 if rage else 1.0)
		if alive >= cap:
			continue
		var lvl := _monster_level(int(camp.tier))
		if camp.elite and not _elites.is_empty():
			var e := _spawn_monster(_elites.pick_random(), camp.pos, lvl, false)
			e.aggro_radius = 22.0
		for i in randi_range(3, 5) + (3 if rage else 0):
			_spawn_monster(_pick_monster(lvl), _around(camp.pos, 6.0), lvl)
	# vagues errantes autour du héros
	_roam_timer -= delta
	if _roam_timer <= 0.0 and alive < cap:
		_roam_timer = randf_range(1.6, 2.6) if rage else randf_range(4.0, 7.0)
		var center := _ring_point(22.0, 32.0)
		if center != Vector3.INF:
			var lvl := _monster_level(0)
			var id := _pick_monster(lvl)
			for i in randi_range(6, 10) if rage else randi_range(2, 4):
				var m := _spawn_monster(id, _around(center, 4.0), lvl)
				m.aggro_radius = 60.0  # elles viennent chercher le héros
	# élites en masse pendant la rage
	if rage and not _elites.is_empty():
		_elite_timer -= delta
		if _elite_timer <= 0.0:
			_elite_timer = 22.0
			var c := _ring_point(24.0, 34.0)
			if c != Vector3.INF:
				for i in 3:
					var e := _spawn_monster(_elites.pick_random(), _around(c, 5.0), _monster_level(1))
					e.aggro_radius = 60.0
				message.emit("Des élites enragées arrivent !", 2.0)


func _spawn_monster(id: int, pos: Vector3, level: int, boss := false) -> Monster:
	var m := Monster.new()
	m.configure(GameData.monster(id), boss, level)
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
	drop.item = Items.generate(level, luck, "", Run.class_id)
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
	_boss = _spawn_monster(boss_id, c, maxi(player.level + 1, _monster_level(2)), true)
	_boss.display_name = "<Boss> " + _boss.display_name
	_boss.aggro_radius = 80.0
	if _boss.brain:
		_boss.brain.enraged_phase.connect(func(): message.emit("%s entre en fureur !" % _boss.display_name, 2.5))
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
			m.aggro_radius = 80.0


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
		_enter_arena()


func teleport_to_gateway() -> bool:
	if state in ["boss", "cleared"]:
		return false
	_place_player(map.dungeon + Vector3(3, 0, 3))
	return true


func debug_start_rage() -> void:
	if state == "explore":
		time = RUN_TIME
