extends Node
## Poursuite de la horde (retour du joueur, 14/10 : « les monstres sont trop facilement bloqués par le
## décor quand on court ») : le héros court le long d'un chemin de la carte de Survie, 40 monstres le
## suivent ; on mesure leur vitesse réelle, la part du temps où un monstre en chasse n'avance presque
## pas, et à quelle distance du héros ils finissent.
## godot --headless --path game --fixed-fps 60 res://tests/test_pursuit.tscn [-- --report]
## Les tireurs gardent leurs distances (12 m) : ils comptent comme suiveurs tant qu'ils restent à portée.

const MONSTERS := 40
const RUN_S := 22.0
const SPEED := 6.5  # vitesse de course du héros (m/s)
const ROUTES := 3

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	seed(1234)
	Profile.selected_zone = String(GameData.zones[0].id)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	var d: RunDirector = world.director
	var player: Player = world.player
	d.set_process(false)
	world.cards._queue.clear()
	world.cards._show_next()
	player.immortal = true
	player.set_physics_process(false)  # le test déplace le héros lui-même
	var map: ProcMap = d.map
	# la carte de navigation se cuit en tâche de fond
	for i in 60:
		if NavigationServer3D.map_get_iteration_id(map.get_world_3d().navigation_map) > 0:
			break
		await get_tree().create_timer(0.2).timeout
	var stuck := 0
	var samples := 0
	var near := 0
	var total := 0
	var dist_sum := 0.0
	var eff := 0.0
	var detour := 0
	var dmax := 0.0
	for r in ROUTES:
		var res: Dictionary = await _route(d, map, player, r)
		stuck += int(res.stuck)
		samples += int(res.samples)
		near += int(res.near)
		total += int(res.total)
		dist_sum += float(res.dist)
		eff += float(res.eff)
		detour += int(res.detour)
		dmax = maxf(dmax, float(res.dmax))
	var stuck_pct := 100.0 * stuck / maxf(samples, 1)
	var near_pct := 100.0 * near / maxf(total, 1)
	var speed_ratio := eff / maxf(samples, 1)
	var mean_d := dist_sum / maxf(total, 1)
	var detour_pct := 100.0 * detour / maxf(samples, 1)
	print("[poursuite] échantillons %d · vitesse réelle / voulue %.2f · immobiles %.1f %% · à moins de 30 m à la fin %.0f %% · distance moyenne %.1f m · contournement %.0f %% · le plus distancé %.0f m" % [
		samples, speed_ratio, stuck_pct, near_pct, mean_d, detour_pct, dmax])
	# avant la passe P9 : vitesse réelle 0,38 de la voulue (demi-tours vers le départ du chemin), distance moyenne 91 m
	check("les monstres en chasse avancent à leur vitesse (%.2f de la vitesse voulue, ≥ 0,85)" % speed_ratio, speed_ratio >= 0.85)
	check("presque jamais immobiles contre le décor (%.1f %% du temps, ≤ 6 %%)" % stuck_pct, stuck_pct <= 6.0)
	check("la horde reste dans les talons du héros qui court (%.1f m en moyenne, ≤ 30 ; %.0f %% à moins de 30 m)" % [mean_d, near_pct], mean_d <= 30.0 and near_pct >= 70.0)
	# passe P11 (sentiment) : en terrain dégagé la horde va droit au héros (2 % des pas mesurés s'écartent de plus
	# de 30° : rochers, arbres, falaises contournés par le maillage), et un héros qui court distance les plus lents
	# (vitesse 3,4 à 4,6 m/s, rattrapage ×1,7 au plus à 30 m : le plus lent plafonne à 5,8 m/s contre 6,5)
	check("les monstres contournent le décor au lieu de foncer en ligne droite (%.1f %% des pas à plus de 30°, ≥ 1 %%)" % detour_pct, detour_pct >= 1.0)
	check("pas de poursuite parfaite : les plus lents décrochent (%.0f m au plus loin, > 25)" % dmax, dmax > 25.0)
	print("TOUS LES TESTS PASSENT" if fails == 0 else "%d ÉCHEC(S)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


## Une course : un chemin de la carte d'environ RUN_S × SPEED mètres, la horde lâchée autour du départ.
func _route(d: RunDirector, map: ProcMap, player: Player, r: int) -> Dictionary:
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	await get_tree().process_frame
	var start := player.global_position
	var path := PackedVector3Array()
	for attempt in 30:
		var ang := randf() * TAU
		var goal: Vector3 = map.ground_at(start.x + cos(ang) * 130.0, start.z + sin(ang) * 130.0)
		if goal == Vector3.INF:
			continue
		path = map.path_between(start, goal)
		if _length(path) > RUN_S * SPEED * 0.8:
			break
	var mons: Array = []
	for i in MONSTERS:
		var ang := TAU * i / MONSTERS
		var p: Vector3 = map.ground_at(start.x + cos(ang) * randf_range(12.0, 26.0), start.z + sin(ang) * randf_range(12.0, 26.0))
		if p == Vector3.INF:
			continue
		var m := d._spawn_monster(d._pick_monster(5), p, 5)
		m._attack_ready_at = 1e9  # pas d'attaque : on ne mesure que la course
		mons.append(m)
	await get_tree().create_timer(0.8).timeout  # sortie du sol
	var t := 0.0
	var along := 0.0
	var last := {}
	var stuck := 0
	var samples := 0
	var sample_t := 0.0
	var eff_sum := 0.0
	var states := {}
	var detour := 0
	while t < RUN_S:
		var dt := get_physics_process_delta_time()
		await get_tree().physics_frame
		t += dt
		along += SPEED * dt
		var pos := _point_at(path, along)
		var g: Vector3 = map.ground_at(pos.x, pos.z)
		player.global_position = g if g != Vector3.INF else pos
		sample_t += dt
		if sample_t >= 0.5:
			for m in mons:
				if not is_instance_valid(m) or m.is_dead:
					continue
				var dist := _flat(m.global_position, player.global_position)
				if last.has(m) and dist > 6.0 and m._state == "chase":
					samples += 1
					var moved := _flat(m.global_position, last[m])
					# contournement (passe P11) : la marche s'écarte de plus de 30° de la ligne droite vers le héros
					var step := Vector2(m.global_position.x - last[m].x, m.global_position.z - last[m].z)
					var line := Vector2(player.global_position.x - last[m].x, player.global_position.z - last[m].z)
					if moved > 0.5 and absf(step.angle_to(line)) > deg_to_rad(30.0):
						detour += 1
					eff_sum += moved / maxf(m.move_speed * m.catch_up(dist) * sample_t, 0.01)
					if moved < m.move_speed * sample_t * 0.25:
						stuck += 1
				last[m] = m.global_position
			sample_t = 0.0
	var near := 0
	var dsum := 0.0
	var dmax := 0.0
	for m in mons:
		if is_instance_valid(m):
			states[m._state] = int(states.get(m._state, 0)) + 1
			var dist := _flat(m.global_position, player.global_position)
			dsum += dist
			dmax = maxf(dmax, dist)
			near += 1 if dist <= 30.0 else 0
	if "--report" in OS.get_cmdline_user_args():
		print("  course %d : chemin %.0f m, %d monstres, immobiles %d / %d, vitesse réelle / voulue %.2f, au contact %d, états %s" % [r + 1, _length(path), mons.size(), stuck, samples, eff_sum / maxf(samples, 1), near, states])
	return {"stuck": stuck, "samples": samples, "near": near, "total": mons.size(), "dist": dsum, "eff": eff_sum, "detour": detour, "dmax": dmax}


func _length(p: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, p.size()):
		l += p[i].distance_to(p[i - 1])
	return l


func _point_at(p: PackedVector3Array, s: float) -> Vector3:
	if p.size() < 2:
		return p[0] if p.size() == 1 else Vector3.ZERO
	for i in range(1, p.size()):
		var seg := p[i].distance_to(p[i - 1])
		if s <= seg:
			return p[i - 1].lerp(p[i], s / maxf(seg, 0.001))
		s -= seg
	return p[p.size() - 1]  # au bout du chemin, le héros s'arrête


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
