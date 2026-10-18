extends Node
## Lot CO-D : IA d'équipe du Colisée (ai/colisee_coach.gd, hooks de ai/class_rival.gd, core/colisee_director.gd ; rapport
## conception/benchmark/R_CO_D.md). 1) Décisions du chef sur des trios posés à la main (héros scriptés figés) : rôles, cible
## commune (danger ÷ temps pour abattre), protection d'un tireur plongé (peel) et écart, fleur de vie, cercle sûr avec l'avance
## du resserrement, cohésion en approche, attente d'un adversaire plus fort, rien au niveau Recrue ; guidage du héros (rentrer
## dans l'anneau, longer le bord, esquive renvoyée dedans) ; choix d'atouts et d'enclumes (point d'extension CO-E / CO-F).
## 2) Une manche réelle IA contre IA (banc : joueur au repos, Éclair, Légende contre Recrue, fiche égale) : un chef par camp,
## un ordre pour chaque héros scripté, cible commune tenue, combats finis, mesures du banc dans le résultat.
## godot --headless --path game res://tests/test_co_d.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_choices()
	await _decisions()
	await _real_round()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().paused = false
	get_tree().quit(fails)


func _until(cond: Callable, max_frames := 300) -> bool:
	for _i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


# --- 1. choix (atouts, enclumes) ----------------------------------------------------------------------------------------

func _choices() -> void:
	check("noms des 4 difficultés", ColiseeCoach.NAMES == ["Recrue", "Vétéran", "Champion", "Légende"]
		and Colisee.DIFFS.slice(0, 4) == ColiseeCoach.NAMES and ColiseeCoach.LEVELS.size() == 4)
	check("rôles : Guerrier tank, Clerc soin, Chasseur tireur, Assassin mêlée", ColiseeCoach.role_of_class("warrior") == "tank"
		and ColiseeCoach.role_of_class("cleric") == "soin" and ColiseeCoach.role_of_class("hunter") == "tireur"
		and ColiseeCoach.role_of_class("assassin") == "melee")
	var offers := [{"id": "soins", "tags": ["healer"]}, {"id": "lame", "tags": ["melee", "coups"]}, {"id": "arc", "tags": ["ranged"]}]
	check("atout : le Clerc (Légende) prend l'atout de soin", ColiseeCoach.choose_augment(offers, "cleric", 3) == 0)
	check("atout : le Guerrier (Légende) prend la lame, jamais le soin", ColiseeCoach.choose_augment(offers, "warrior", 3) == 1)
	check("atout : le Chasseur (Légende) prend l'arc", ColiseeCoach.choose_augment(offers, "hunter", 3) == 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var seen := {}
	for i in 60:
		seen[ColiseeCoach.choose_augment(offers, "warrior", 0, [], rng)] = true
	check("atout : la Recrue choisit au hasard (les 3 offres sorties)", seen.size() == 3)
	var team_offers := [{"id": "a", "tags": ["survie"]}, {"id": "b", "tags": ["equipe"], "score": 0.95}]
	var team := ColiseeCoach.choose_augment(team_offers, "assassin", 3, ["assassin", "warrior", "cleric"])
	check("atout : synergie de trio (Légende) : l'atout d'équipe passe devant", team == 1)
	var anvil := [{"kind": "piece", "slot": "head", "gain": 0.2}, {"kind": "up", "slot": "weapon", "gain": 0.9},
		{"kind": "piece", "slot": "feet", "gain": 0.4}]
	check("enclume : la meilleure pièce (gain) en Légende", ColiseeCoach.choose_anvil(anvil, "warrior", 3) == 1)
	check("enclume vide : -1", ColiseeCoach.choose_anvil([], "warrior", 3) == -1)


# --- 2. décisions du chef sur des trios posés ---------------------------------------------------------------------------

var _root: Node3D
var _arena: ColiseeArena


func _hero(cid: String, diff: int, at: Vector3) -> ClassRival:
	var r := TeamMatch.make_hero(cid, Colisee.LEVEL, diff)
	_root.add_child(r)
	r.set_physics_process(false)  # (figé : seules les décisions du chef sont lues)
	r.global_position = at
	return r


func _place(rows: Array) -> void:
	for e in rows:
		(e[0] as Node3D).global_position = e[1]


func _decisions() -> void:
	_root = Node3D.new()
	add_child(_root)
	_arena = ColiseeArena.new()
	_root.add_child(_arena)
	_arena.setup({"index": 0, "name": "Prairie", "center": Vector3.ZERO, "flowers": [Vector3(6, 0, 6)]})
	var flower: ColiseeFlower = _arena.flowers[0]
	var ours: Array = [_hero("warrior", 3, Vector3(0, 0, 6)), _hero("hunter", 3, Vector3(-3, 0, 8)), _hero("cleric", 3, Vector3(3, 0, 8))]
	var theirs: Array = [_hero("knight", 3, Vector3(0, 0, -6)), _hero("assassin", 3, Vector3(-3, 0, -8)), _hero("druid", 3, Vector3(3, 0, -8))]
	var tank: ClassRival = ours[0]
	var hunter: ClassRival = ours[1]
	var cleric: ClassRival = ours[2]
	var knight: ClassRival = theirs[0]
	var assassin: ClassRival = theirs[1]
	var druid: ClassRival = theirs[2]
	await get_tree().process_frame
	var lv3 := ColiseeCoach.new(3, _arena, ours, theirs, 0, 11)
	lv3.decide()
	check("Légende : un ordre pour chaque héros scripté (cercle sûr, seuil de soin)", _all_ordered(ours) and float(cleric.coach_order.heal_at) > 0.5)
	check("Légende : cible commune = le soigneur adverse à PV égaux (%s)" % (lv3.focus.cid if lv3.focus else "aucune"), lv3.focus == druid
		and _all_target(ours, druid))
	check("la cible est posée tout de suite sur le héros", tank._player == druid)
	assassin.hp = assassin.max_hp * 0.08
	lv3.t += 3.0
	lv3.decide()
	check("Légende : un adversaire presque à terre devient la cible commune", lv3.focus == assassin)
	assassin.hp = assassin.max_hp
	# protection (peel) : l'Assassin plonge sur le Chasseur, la cible commune reste le Druide
	lv3.focus = druid
	lv3._focus_since = lv3.t
	_place([[assassin, hunter.global_position + Vector3(1.6, 0, -0.6)], [tank, hunter.global_position + Vector3(4.0, 0, -2.0)]])
	tank.coach_order = {}
	lv3.decide()
	check("peel : le tank frappe le plongeur au lieu de la cible commune", tank.coach_order.target == assassin and int(lv3.stats.peels) >= 1)
	check("peel : le tireur plongé s'écarte (« evade »)", String(hunter.coach_order.kind) == "evade"
		and Vector3(hunter.coach_order.goal).distance_to(assassin.global_position) > hunter.global_position.distance_to(assassin.global_position))
	var lv0 := ColiseeCoach.new(0, _arena, ours, theirs, 0, 12)
	lv0.decide()
	check("Recrue : aucun chef (ni cible commune, ni point), seulement le cercle sûr", _all_target(ours, null) and _all_kind(ours, "")
		and not bool(tank.coach_order.slide) and float(tank.coach_order.safe_r) < 100.0)
	# fleur de vie : le soigneur à 30 % des PV, fleur à 3 m, personne autour
	_place([[tank, Vector3(0, 0, 6)], [hunter, Vector3(-3, 0, 8)], [cleric, Vector3(4, 0, 4)], [knight, Vector3(0, 0, -6)],
		[assassin, Vector3(-3, 0, -8)], [druid, Vector3(3, 0, -8)]])
	cleric.hp = cleric.max_hp * 0.3
	var lv2 := ColiseeCoach.new(2, _arena, ours, theirs, 0, 13)
	lv2.decide()
	check("Champion : le blessé va à la fleur de vie", String(cleric.coach_order.kind) == "flower"
		and Vector3(cleric.coach_order.goal).distance_to(flower.global_position) < 0.1)
	var lv1 := ColiseeCoach.new(1, _arena, ours, theirs, 0, 14)
	cleric.hp = cleric.max_hp * 0.45
	lv1.decide()
	check("Vétéran : à 45 % des PV, pas encore la fleur (seuil 35 %)", String(cleric.coach_order.kind) != "flower")
	_place([[assassin, flower.global_position + Vector3(0.5, 0, 0.5)]])
	lv2.decide()
	check("fleur gardée par un adversaire : il n'y va pas", String(cleric.coach_order.kind) != "flower")
	_place([[assassin, Vector3(-3, 0, -8)]])
	cleric.hp = cleric.max_hp
	# cercle sûr : 21,5 s de combat, le resserrement à 16 m arrive dans 3,5 s
	_arena.ring.t = 21.5
	_arena.ring.radius = ColiseeRing.radius_at(21.5)
	check("cercle sûr : la Légende prend déjà l'anneau suivant (16 m), le Champion pas encore, la Recrue le bord",
		absf(lv3.safe_radius() - (16.0 - 1.5)) < 0.01 and absf(lv2.safe_radius() - (22.0 - 1.2)) < 0.01 and absf(lv0.safe_radius() - 21.7) < 0.01)
	_arena.ring.t = 0.0
	_arena.ring.radius = ColiseeRing.START_R
	# approche : adversaires loin ; le tank part seul devant -> il attend le groupe (cohésion)
	_place([[tank, Vector3(0, 0, 1)], [hunter, Vector3(-3, 0, 12)], [cleric, Vector3(3, 0, 12)], [knight, Vector3(0, 0, -16)],
		[assassin, Vector3(-3, 0, -18)], [druid, Vector3(3, 0, -18)]])
	lv2.decide()
	check("cohésion (Champion) : le tank parti devant attend le groupe", String(tank.coach_order.kind) == "hold" and String(hunter.coach_order.kind) == "")
	lv1.decide()
	check("Vétéran : pas de cohésion", String(tank.coach_order.kind) == "")
	# attente : trio affaibli face à un trio plein, la Légende attend (fleur hors jeu)
	flower.ready_now = false
	for r in ours:
		(r as ClassRival).hp = (r as ClassRival).max_hp * 0.5
	var lv3b := ColiseeCoach.new(3, _arena, ours, theirs, 0, 15)
	lv3b.decide()
	check("attente (Légende) : trio plus faible en approche -> il tient sa position", _all_kind(ours, "hold") and float(lv3b.stats.wait_s) > 0.0)
	lv3b.t = ColiseeCoach.WAIT_MAX + 1.0
	lv3b.decide()
	check("attente bornée : passé WAIT_MAX s, il engage (pas d'équipe passive)", not _all_kind(ours, "hold"))
	for r in ours:
		(r as ClassRival).hp = (r as ClassRival).max_hp
	# guidage du héros scripté
	tank.coach_order = {"safe_c": Vector3.ZERO, "safe_r": 10.0, "react": 0.0, "slide": true, "goal": Vector3.INF, "target": null}
	tank.global_position = Vector3(12, 0, 0)
	var esc := tank._coach_escape(0.1)
	check("hors du cercle sûr : il rentre vers le centre", esc != Vector3.INF and esc.x < -1.0)
	tank.global_position = Vector3(9, 0, 0)
	check("esquive vers l'extérieur près du bord : renvoyée dedans", tank._coach_inside(Vector3(1, 0, 0)).x < 0.0)
	tank.global_position = Vector3(9.5, 0, 0)
	check("près du bord : il le longe (plus de vitesse sortante)", absf(tank._coach_steer(Vector3(1, 0, 1)).x) < 0.01)
	tank.global_position = Vector3(2, 0, 0)
	check("dedans : rien ne change", tank._coach_escape(0.1) == Vector3.INF and tank._coach_steer(Vector3(1, 0, 0)).x > 0.99)
	tank.coach_order = {}
	_root.queue_free()
	await get_tree().process_frame


# --- 3. une manche réelle IA contre IA ----------------------------------------------------------------------------------

func _real_round() -> void:
	ColiseeDirector.fallback = false
	ColiseeDirector.watch_only = true
	ColiseeDirector.even_sheets = true
	Profile.selected_class = "warrior"
	var g := Colisee.begin("warrior", "eclair", 3, 41)
	g.team_diffs = [3, 0, 3, 0]
	g.classes = Colisee.compose_teams(g.n, "", g.rng)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	world.ready.connect(func(): world.player.autoplay = true)
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	var dd: ColiseeDirector = world.director.team
	await _until(func(): return dd.map != null and dd.map._region.navigation_mesh != null, 3600)
	await _until(func(): return dd.phase == "fight", 1800)
	check("banc : le joueur au repos, 12 héros scriptés dans 2 combats", world.player.arena_id == ColiseeDirector.PARK and dd.fights.size() == 2
		and _bench_heroes(dd))
	check("un chef par camp, de niveau = difficulté du trio", _coaches_ok(dd, g))
	var shared := 0
	var samples := 0
	var orders_ok := true
	for i in 40:
		await get_tree().create_timer(0.25, false).timeout
		for f in dd.fights:
			if f.done:
				continue
			for side in 2:
				var al: Array = (f.heroes[side] as Array).filter(func(c): return is_instance_valid(c) and not (c as Combatant).is_dead)
				for c in al:
					orders_ok = orders_ok and not (c as ClassRival).coach_order.is_empty()
				var co: ColiseeCoach = f.coach[side]
				if co != null and co.level >= 1 and al.size() >= 2:
					samples += 1
					var tg = (al[0] as ClassRival).coach_order.get("target")
					if al.all(func(c): return (c as ClassRival).coach_order.get("target") == tg) and tg != null:
						shared += 1
	check("chaque héros scripté debout a un ordre de son chef", orders_ok)
	check("cible commune tenue (Légende) : %d / %d relevés" % [shared, samples], samples > 0 and shared >= samples * 0.5)
	await _until(_round_over.bind(dd), 60 * 90)
	var res: Array = dd.fights.map(func(f): return f.result)
	for r in res:
		print("[co_d] manche 1 : %s" % str([r.get("diff_a"), r.get("diff_b"), r.get("winner"), r.get("time"), r.get("first_hit"), r.get("chef_a")]))
	check("les combats de la manche finissent", res.all(func(r): return not (r as Dictionary).is_empty()))
	var keys_ok := true
	var active_ok := true
	var both_ok := true
	for r in res:
		for k in ["diff_a", "coach_b", "first_hit", "dealt_a", "out_b", "flowers_a", "chef_a"]:
			keys_ok = keys_ok and (r as Dictionary).has(k)
		active_ok = active_ok and float(r.get("first_hit", -1)) >= 0.0 and float(r.get("first_hit", 99)) < 15.0
		both_ok = both_ok and float(r.get("dealt_a", 0)) > 0.0 and float(r.get("dealt_b", 0)) > 0.0
	check("mesures du banc dans le résultat (difficultés, chefs, premier coup, dégâts, feu, fleurs)", keys_ok)
	check("personne ne reste passif : un coup avant 15 s dans chaque combat", active_ok)
	check("les deux camps frappent", both_ok)
	var line: Dictionary = dd.summary(0.0)
	check("bilan JSON de la partie (banc)", line.has("fights") and line.has("diffs") and line.has("coach") and bool(line.watch) and bool(line.even))
	dd.abandon_stay = true
	dd.abandon()
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false
	ModeRules._extra.erase("colisee")
	ColiseeDirector.fallback = true
	ColiseeDirector.watch_only = false
	ColiseeDirector.even_sheets = false
	ColiseeDirector.coach_levels = []


func _all_ordered(arr: Array) -> bool:
	for r in arr:
		if (r as ClassRival).coach_order.is_empty() or float((r as ClassRival).coach_order.safe_r) >= 100.0:
			return false
	return true


func _all_target(arr: Array, tgt) -> bool:
	for r in arr:
		if (r as ClassRival).coach_order.get("target") != tgt:
			return false
	return true


func _all_kind(arr: Array, kind: String) -> bool:
	for r in arr:
		if String((r as ClassRival).coach_order.get("kind", "")) != kind:
			return false
	return true


func _bench_heroes(dd: ColiseeDirector) -> bool:
	for f in dd.fights:
		for side in 2:
			if (f.heroes[side] as Array).size() != 3:
				return false
			for c in f.heroes[side]:
				if not (c is ClassRival):
					return false
	return true


func _coaches_ok(dd: ColiseeDirector, g: Colisee) -> bool:
	for f in dd.fights:
		for side in 2:
			var co: ColiseeCoach = f.coach[side]
			var t := int(f.a) if side == 0 else int(f.b)
			if co == null or co.level != int(g.team_diffs[t]):
				return false
	return true


func _round_over(dd: ColiseeDirector) -> bool:
	if dd.phase != "fight":
		return true
	for f in dd.fights:
		if not f.done:
			return false
	return true
