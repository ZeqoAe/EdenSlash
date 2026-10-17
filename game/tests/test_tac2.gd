extends Node
## Lot TAC-2 : murs, vue, brouillard, voile et bruits de L'Assaut (AssaultVision) sur le Bourg, dans une vraie partie.
## Vue d'équipe (portée, murs pleins, murets transparents, hautes herbes à 3 m, invisibilité à 5 m, brume) ; ce que ton
## équipe ne voit pas est caché (modèle, mini-carte, barre de cible) ; dernière position connue ; coups qui testent le décor
## (télégraphes des scriptés, zones et projectiles du héros) ; perception honnête de l'IA (ciblage) ; bruits (portées, toute la
## carte pour la Charge) ; polygone du voile ; coût d'un tour de vision avec 8 héros.
## godot --headless --path game res://tests/test_tac2.tscn

var fails := 0
var dd: AssaultDirector
var v: AssaultVision
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	check("hors Assaut : aucun coup arrêté, ciblage inchangé", not AssaultVision.active() and not AssaultVision.blocks_shot(Vector3.ZERO, Vector3(10, 0, 0))
		and AssaultVision.filter_seen(null, [1, 2]) == [1, 2] and AssaultVision.perceives(null, null))
	await _start(false)
	await _vision()
	await _hits_ai()
	await _hits_player()
	await _noises()
	await _perf()
	await _stop()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Partie sur le Bourg, achat très long : les héros restent immobiles, le test les pose où il veut.
func _start(watch: bool) -> void:
	Profile.selected_class = "warrior"
	Assault.launch("warrior", {"map": "bourg", "watch": watch, "seed": 9, "buy_time_first": 9999.0, "buy_time": 9999.0,
		"allies": ["cleric", "hunter", "magician"], "foes": ["knight", "thief", "bard", "warrior"]})
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	dd = world.director.team
	await _until(func(): return dd.map._region.navigation_mesh != null, 3600)
	v = dd.vision
	dd.barrier = false  # (le test pose le joueur où il veut pendant l'achat)
	check("vision de la partie montée (AssaultVision.current)", v != null and AssaultVision.current == v and AssaultVision.active())
	for _i in 6:
		await get_tree().physics_frame


func _w(x: float, z: float) -> Vector3:
	var p := AssaultMap.to_world(dd.map, Vector2(x, z))
	p.y = dd.map.floor_at(p.x, p.z)
	return p


## Pose le héros [param key] en (x, z) du plan (immobile).
func _put(key: String, x: float, z: float) -> Combatant:
	var h := dd.hero(key)
	h.global_position = _w(x, z) + Vector3.UP * 0.05
	h.velocity = Vector3.ZERO
	return h


func _ticks(n := 3) -> void:
	for _i in n * 7:
		await get_tree().physics_frame


func _park_all() -> void:
	# tout le monde dans son départ, loin de tout
	for k in dd.heroes:
		var t := Assault.team_of(String(k))
		var i := int(String(k).right(1))
		_put(String(k), 32.0 + i * 3.0, 94.0 if t == 1 else 4.0)


func _vision() -> void:
	_park_all()
	var me := dd.hero("t0_0")
	# un mur plein entre deux héros (la halle ouest : x 30-40, z 26-36) : pas vu
	_put("t0_0", 26.0, 31.0)
	var foe := _put("t1_0", 43.0, 31.0)
	_put("t1_1", 26.0, 40.0)  # au pied du site, à 9 m, rien entre : vu
	await _ticks()
	check("mur plein : l'adversaire derrière la halle n'est pas vu", not v.sees(0, foe))
	check("rue dégagée : vu", v.sees(0, dd.hero("t1_1")))
	check("vu par qui : le joueur", v.seen_by(0, dd.hero("t1_1")) == me)
	check("ce que ton équipe ne voit pas est caché, ce qu'elle voit montré", not foe.visible and dd.hero("t1_1").visible)
	check("tes équipiers restent visibles", dd.hero("t0_1").visible and me.visible)
	_put("t1_1", 42.0, 50.0)  # à 25 m : trop loin
	await _ticks()
	check("au-delà de 22 m : pas vu", not v.sees(0, dd.hero("t1_1")))
	check("dernière position connue gardée (%s)" % str(v.last_seen(0).has(dd.hero("t1_1").get_instance_id())),
		v.last_seen(0).has(dd.hero("t1_1").get_instance_id()))
	check("fantôme « ? » à sa dernière position", v.ghosts().has(dd.hero("t1_1").get_instance_id()))
	# muret : la vue passe (muret 34-39, z 52-53,2)
	_put("t0_0", 36.5, 48.0)
	_put("t1_1", 36.5, 57.0)
	await _ticks()
	check("un muret ne coupe pas la vue", v.sees(0, dd.hero("t1_1")))
	# hautes herbes du jardin (2-13, 34-46)
	_put("t1_2", 7.0, 40.0)
	_put("t0_1", 7.0, 31.0)
	await _ticks()
	check("hautes herbes : caché à 9 m", not v.sees(0, dd.hero("t1_2")))
	_put("t0_1", 7.0, 37.6)
	await _ticks()
	check("hautes herbes : vu à 2,4 m", v.sees(0, dd.hero("t1_2")))
	# invisibilité
	var thief := dd.hero("t1_1")
	thief.add_status("invisible", 5.0, thief)
	await _ticks()
	check("invisible à 9 m : pas vu", not v.sees(0, thief))
	thief.statuses.erase("invisible")
	# brume
	v.smokes.append({"pos": Vector2(_w(36.5, 52.5).x, _w(36.5, 52.5).z), "r": 2.5, "until": v.time + 5.0})
	await _ticks()
	check("une brume coupe la vue", not v.sees(0, thief))
	v.smokes.clear()
	await _ticks()
	check("brume dissipée : vu à nouveau", v.sees(0, thief))
	# polygone du voile : un point derrière la halle est dehors, un point de la rue dedans
	var poly := v.visibility_polygon(_w(26.0, 31.0))
	var behind := _w(45.0, 31.0)
	var street := _w(26.0, 40.0)
	check("voile : %d sommets ; derrière le mur voilé, la rue visible" % poly.size(), poly.size() >= AssaultVision.FAN
		and not Geometry2D.is_point_in_polygon(Vector2(behind.x, behind.z), poly)
		and Geometry2D.is_point_in_polygon(Vector2(street.x, street.z), poly))


func _hits_ai() -> void:
	_park_all()
	await _ticks(1)
	# un coup en ligne d'un scripté : arrêté par la halle, pas dans la rue
	var src := _put("t1_0", 43.0, 31.0)
	var tgt := _put("t0_1", 26.0, 31.0)
	var hp0 := tgt.hp
	_line(src, tgt)
	await _ticks(2)
	check("télégraphe d'un scripté : arrêté par le mur plein (PV %d -> %d)" % [hp0, tgt.hp], is_equal_approx(tgt.hp, hp0))
	_put("t0_1", 43.0, 45.0)
	await _ticks(1)
	hp0 = tgt.hp
	_line(src, tgt)
	await _ticks(2)
	check("télégraphe dans la rue : touche (PV %d -> %d)" % [hp0, tgt.hp], tgt.hp < hp0)
	# muret : arrête le coup au sol
	_put("t1_0", 36.5, 49.0)
	_put("t0_1", 36.5, 56.5)
	await _ticks(1)
	hp0 = tgt.hp
	_line(src, tgt)
	await _ticks(2)
	check("télégraphe : arrêté par un muret", is_equal_approx(tgt.hp, hp0))
	# zone au sol posée derrière un mur : sans effet même sur une cible en vue de la zone
	_put("t1_0", 26.0, 31.0)
	_put("t0_1", 43.0, 31.0)
	await _ticks(1)
	hp0 = tgt.hp
	var tg := Telegraph.spawn(src, tgt.global_position, 0.0, {"delay": 0.05, "damage": 300.0, "source": src, "shape": "circle", "radius": 3.0})
	await _ticks(2)
	check("zone posée derrière un mur : sans effet (PV %d -> %d)" % [hp0, tgt.hp], is_equal_approx(tgt.hp, hp0) and tg != null)
	# perception honnête : une cible derrière le mur n'est pas dans la liste, ni « visable »
	var pool: Array = AssaultVision.filter_seen(src, Combatant.ffa_foes(get_tree(), src))
	check("ciblage honnête : l'adversaire derrière le mur n'est pas visé", not tgt in pool and not AssaultVision.perceives(src, tgt))
	_put("t0_1", 27.5, 31.0)
	await _ticks()
	check("au contact (2,5 m), il se sent", AssaultVision.perceives(src, tgt))


func _line(src: Combatant, tgt: Combatant) -> void:
	var to := tgt.global_position - src.global_position
	to.y = 0.0
	Telegraph.spawn(src, src.global_position, atan2(to.x, to.z), {"delay": 0.05, "damage": 300.0, "source": src, "shape": "line",
		"length": to.length() + 2.0, "width": 2.0})


## Les coups du joueur : sa zone (_resolve_area) et ses projectiles (HeroBolt) testent le décor.
func _hits_player() -> void:
	var p: Player = dd.d.player
	_park_all()
	_put("t0_0", 26.0, 31.0)
	var foe := _put("t1_0", 43.0, 31.0)
	await _ticks(1)
	var hp0 := foe.hp
	p._resolve_area({"radius": 30.0, "arc": 360.0, "mult": 2.0}, p.global_position, p.forward(), false)
	check("zone du héros : rien à travers le mur (PV %d -> %d)" % [hp0, foe.hp], is_equal_approx(foe.hp, hp0))
	var to := foe.global_position - p.global_position
	HeroBolt.fire(p, p.global_position + Vector3.UP * 1.1, to, {"range": 25.0, "mult": 2.0})
	for _i in 60:
		await get_tree().physics_frame
	check("projectile du héros : arrêté par le mur (PV %d -> %d)" % [hp0, foe.hp], is_equal_approx(foe.hp, hp0))
	_put("t1_0", 26.0, 40.0)
	await _ticks(1)
	hp0 = foe.hp
	p.face_direction(foe.global_position - p.global_position, 1.0, 100.0)
	p._resolve_area({"radius": 30.0, "arc": 360.0, "mult": 2.0}, p.global_position, p.forward(), false)
	check("zone du héros dans la rue : touche (PV %d -> %d)" % [hp0, foe.hp], foe.hp < hp0)


func _noises() -> void:
	_park_all()
	_put("t0_0", 36.0, 40.0)
	_put("t1_0", 42.0, 52.0)  # à 13 m
	await _ticks(1)
	var n0 := (v.noises[0] as Array).size()
	v.noise(_w(42.0, 52.0), "steps", 1)
	check("des pas à 13 m s'entendent (portée 14 m)", (v.noises[0] as Array).size() == n0 + 1)
	v.noise(_w(36.0, 60.0), "steps", 1)
	check("des pas à 20 m ne s'entendent pas", (v.noises[0] as Array).size() == n0 + 1)
	v.noise(_w(36.0, 60.0), "fight", 1)
	check("un coup à 20 m s'entend (portée 24 m)", (v.noises[0] as Array).size() == n0 + 2)
	v.noise(_w(70.0, 27.0), "plant", 1)
	check("la pose s'entend sur toute la carte", (v.noises[0] as Array).size() == n0 + 3 and String(v.heard_since(0, 1.0)[-1].kind) == "plant")
	check("son équipe n'entend pas ses propres bruits", (v.noises[1] as Array).all(func(n): return int(n.src) != 1))
	check("« Voir les sons » : les bruits de ton équipe deviennent des arcs", RoyaleCues.events.size() >= 2)
	# bruits automatiques : un coup d'un scripté (télégraphe) à 12 m
	var before := (v.noises[0] as Array).size()
	_line(dd.hero("t1_0"), dd.hero("t0_0"))
	await _ticks(1)
	check("un coup d'un scripté fait du bruit (combat)", (v.noises[0] as Array).size() > before
		and (v.noises[0] as Array).any(func(n): return String(n.kind) == "fight"))


## Coût de la vision : 8 héros sur le Bourg, manche en cours (les scriptés se battent).
func _perf() -> void:
	Assault.t = 0.01  # fin de l'achat : la manche démarre, les 7 scriptés bougent
	for _i in 30:
		await get_tree().physics_frame
	var ticks: Array = []
	var frames: Array = []
	var last := int(v.stats.ticks)
	for _i in 600:
		await get_tree().physics_frame
		frames.append((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		if int(v.stats.ticks) != last:
			last = int(v.stats.ticks)
			ticks.append(float(v.stats.ms))
	ticks.sort()
	frames.sort()
	var med := float(ticks[ticks.size() / 2]) if not ticks.is_empty() else -1.0
	var fmed := float(frames[frames.size() / 2])
	print("[tac2] tour de vision : médiane %.2f ms, 90e %.2f ms, max %.2f ms (%d tours, %d rayons) ; image (process + physique) : médiane %.2f ms, 90e %.2f ms"
		% [med, float(ticks[int(ticks.size() * 0.9)]), float(v.stats.ms_max), ticks.size(), int(v.stats.rays), fmed, float(frames[int(frames.size() * 0.9)])])
	check("tour de vision (8 héros, Bourg) : médiane %.2f ms ≤ 2 ms" % med, med >= 0.0 and med <= 2.0)
	# (l'image entière se mesure au calme, fenêtre ouverte : world.tscn -- --assault --assault-perf ; machine chargée par d'autres
	# agents, son temps ne dit rien ici. La part de la vision, elle, se compare à l'image de la même partie.)
	check("la vision pèse moins de 5 %% d'une image (%.2f ms sur %.2f ms)" % [med, fmed], med >= 0.0 and med <= fmed * 0.05 + 0.05)


func _stop() -> void:
	dd.abandon()
	await get_tree().process_frame
	check("fin de partie : la vision s'éteint avec la partie", not TeamMatch.active)
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	check("plus de vision hors partie", not AssaultVision.active())
	Run.active = false
	Profile.in_run = false


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
