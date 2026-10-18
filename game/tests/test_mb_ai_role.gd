extends Node
## Lot MB-E (Les Deux Voies, conception/benchmark/R_MB_E.md) : IA par poste (MobaHeroAi).
## 1. Partie réelle (world.tscn, 8 IA Hardcore, × 4) : une IA de poste par héros scripté, cadence de la difficulté ; zones
##    interdites = tours adverses (aucun héros dedans sans sbire allié pour occuper la tour) ; le soutien suit son tireur ;
##    le jungler va aux camps (lot MB-F) ou soutient une voie sans jungle ; achats à la fontaine selon le parcours ; coût de
##    la couche de poste sous 150 µs par décision.
## 2. Parties accélérées dans des processus à part (--fixed-fps 60, × 4) : jusqu'à 4:10, chaque jungler a vidé au moins
##    6 camps avant 4:00 (si la jungle du lot MB-F est là) ; aucune mort sous une tour adverse ni sans héros adverse dans les
##    10 s (Hardcore), sur 4 parties jusqu'à 4:10 et une jusqu'à 10:00. La série de 20 parties complètes est dans le rapport
##    (tools/moba_ai_games.py).
## godot --headless --path game res://tests/test_mb_ai_role.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	await _world()
	_runs()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


static func has_jungle() -> bool:
	for c in ProjectSettings.get_global_class_list():
		if String(c.get("class", "")) == "MobaJungle":
			return true
	return false


func _world() -> void:
	seed(5)
	Profile.selected_class = "warrior"
	Moba.launch("warrior", {"heroes": "watch", "diff": 3, "seed": 5, "speed": 4.0})
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 900)
	var dd: MobaDirector = world.director.team as MobaDirector
	if dd == null:
		check("directeur monté", false)
		Moba.finish()
		return
	await _until(func(): return dd.map != null and dd.map.nav_ready(), 900)
	var all_ai := true
	for h in dd.heroes:
		all_ai = all_ai and h is MobaRival and (dd.info[h] as MobaHero).ai is MobaHeroAi
	check("8 héros scriptés, une IA de poste chacun (MobaHeroAi)", dd.heroes.size() == 8 and all_ai)
	await _until(func(): return Moba.t >= 70.0, 60 * 60)
	var zones := true
	var inside := 0
	for h in dd.heroes:
		var r := h as MobaRival
		var towers := 0
		for s in dd.structures:
			if not s.is_dead and s.side != r.side:
				towers += 1
		zones = zones and r.avoid.size() >= 1 and r.avoid.size() <= towers
	check("zones interdites : les tours adverses debout", zones)
	var sup_ok := false
	var jg_ok := false
	for _i in 40:
		await get_tree().physics_frame
		for h in dd.heroes:
			var hs: MobaHero = dd.info[h]
			var r := h as MobaRival
			if r.inside_avoid() and not r.dive_ok and not r.is_dead:
				inside += 1
			if hs.role == 3 and (hs.ai as MobaHeroAi).mode == "follow":
				sup_ok = true
			if hs.role == 1 and (hs.ai as MobaHeroAi).mode in (["jungle", "gank"] if has_jungle() else ["lane", "jungle"]):
				jg_ok = true
	check("aucun héros dans la portée d'une tour adverse inoccupée (%d)" % inside, inside == 0)
	check("le soutien suit son tireur", sup_ok)
	check("le jungler joue la jungle (ou une voie sans jungle)", jg_ok)
	var bought := 0
	for h in dd.heroes:
		bought += (dd.info[h] as MobaHero).items.size()
	check("achats à la fontaine au départ (%d objets ou composants pour 8)" % bought, bought >= 8)
	var us := 0.0
	var n := 0
	for h in dd.heroes:
		var ai: MobaHeroAi = (dd.info[h] as MobaHero).ai
		us += ai.cost_us
		n += ai.cost_n
	check("coût d'une décision de poste : %.1f µs (≤ 150)" % (us / maxf(1.0, n)), n > 0 and us / n <= 150.0)
	TeamMatch.end()
	Moba.reset()
	Engine.time_scale = 1.0
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false


func _run(extra: Array) -> Array:
	var args := ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "res://scenes/world.tscn", "--",
		"--moba", "--moba-heroes=watch", "--moba-diff=3", "--moba-speed=4", "--auto-quit"] + extra
	var out := []
	var t0 := Time.get_ticks_msec()
	OS.execute(OS.get_executable_path(), args, out, true)
	var games: Array = []
	for chunk in out:
		for l in String(chunk).split("\n"):
			if l.begins_with("[moba] bilan "):
				var j = JSON.parse_string(l.substr(13))
				if j is Dictionary:
					games.append(j)
	print("[mb-e] partie %s : %.0f s" % [" ".join(extra), (Time.get_ticks_msec() - t0) / 1000.0])
	return games


func _runs() -> void:
	var jungle := has_jungle()
	var camps: Array = []
	var deaths := 0
	var bad: Array = []
	var played := 0
	var runs := [["--moba-until=250", "--moba-seed=201"], ["--moba-until=250", "--moba-seed=202"], ["--moba-until=250", "--moba-seed=203"],
		["--moba-until=250", "--moba-seed=204"], ["--moba-until=600", "--moba-seed=205"]]
	for extra in runs:
		for g in _run(extra):
			played += 1
			for h in g.heroes:
				if int(h.role) == 1:
					camps.append((h.camp_times as Array).filter(func(x): return float(x) < 240.0).size())
				for d in h.deaths:
					deaths += 1
					if bool(d.under_tower) or not bool(d.hero_hit):
						bad.append("%s %.0f s (%s)" % [h.cid, float(d.t), d.by])
	check("parties jouées jusqu'au bout de la mesure (%d / %d)" % [played, runs.size()], played == runs.size())
	if jungle:
		check("jungler : au moins 6 camps avant 4:00, chaque fois (%s)" % str(camps), camps.size() == 2 * runs.size() and camps.min() >= 6)
	else:
		print("  (jungle du lot MB-F absente : camps non vérifiés)")
	check("Hardcore : %d morts, aucune sous une tour adverse ni sans héros adverse (%s)" % [deaths, ", ".join(bad)], bad.is_empty())


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
