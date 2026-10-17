extends Node
## Lot MB-C (Les Deux Voies, conception/benchmark/R_MB_C.md) : tours, Cœur, sbires, vagues, protections, victoire.
## 1. Partie réelle dans world.tscn (vagues seules, sans héros) : directeur monté par TeamMatch, 10 structures hors des groupes
##    « heroes » / « monsters », sbires recyclés du camp de leur équipe (ffa_id), jamais membres de TeamMatch, mode horde,
##    vagues de 3 mêlées + 2 tireurs, fronts qui avancent, plafond de sbires, aucune création de sbire après le chargement,
##    règles pures (protection sans sbire, garde des T1 avant 4:00, T2 et Cœur invulnérables, tirs de suite, décision au temps).
## 2. Deux parties accélérées dans un processus à part (--fixed-fps 60, vitesse × 4, au plus vite) :
##    20 min de vagues égales : aucune structure ne tombe ; un camp × 1,2 : la première tour tombée est une T1 adverse, vers
##    8-10 min (accepté 7:30-11:00).
## godot --headless --path game res://tests/test_mb_lanes.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_pure_rules()
	await _world_lanes()
	_long_runs()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _pure_rules() -> void:
	Moba.reset()
	var full := Moba.structure_damage(1.0, "tower", 1, true, false, 600.0)
	check("une unité = 100 points", is_equal_approx(full, 100.0))
	check("sans sbire ennemi proche : un tiers des dégâts", is_equal_approx(Moba.structure_damage(1.0, "tower", 1, false, false, 600.0), 100.0 * MobaData.PROTECT_MULT))
	check("T1 à moitié avant 4:00, pas la T2", is_equal_approx(Moba.structure_damage(1.0, "tower", 1, true, false, 100.0), 50.0)
		and is_equal_approx(Moba.structure_damage(1.0, "tower", 2, true, false, 100.0), 100.0))
	check("invulnérable : aucun dégât", Moba.structure_damage(5.0, "core", 0, true, true, 900.0) == 0.0)
	check("tirs de suite : × 1, 1,4, 1,8, puis × 2,2 au plus", is_equal_approx(Moba.tower_streak(1), 1.0) and is_equal_approx(Moba.tower_streak(2), 1.4)
		and is_equal_approx(Moba.tower_streak(3), 1.8) and is_equal_approx(Moba.tower_streak(9), 2.2))
	check("PV : Cœur = 1,5 × T2", is_equal_approx(Moba.structure_hp("core", 0), Moba.structure_hp("tower", 2) * 1.5))
	Moba.structures_down = [2, 1]
	check("fin au temps : plus de structures détruites", Moba.decide([0.5, 1.0]) == 0)
	Moba.structures_down = [1, 1]
	check("à égalité : le Cœur le moins entamé", Moba.decide([0.4, 0.9]) == 1)
	Moba.minion_kills = [30, 31]
	check("puis l'or, puis les sbires tués", Moba.decide([1.0, 1.0], [500, 400]) == 0 and Moba.decide([1.0, 1.0]) == 1)
	Moba.reset()


func _world_lanes() -> void:
	seed(4242)
	Profile.selected_class = "warrior"
	Moba.launch("warrior", {"heroes": "none", "speed": 4.0, "seed": 4242})
	check("lancement : partie des Deux Voies, scellée, sans Duel ni Battle royale", Modes.current() == "moba" and Modes.sealed()
		and not Duel.active and not Royale.active and Moba.active)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 900)
	var dd: MobaDirector = world.director.team as MobaDirector
	check("directeur des Deux Voies monté par RunDirector (état « team »)", dd != null and world.director.state == "team")
	if dd == null:
		Moba.finish()
		return
	await _until(func(): return dd.map != null and dd.map.nav_ready(), 900)
	check("carte et navigation prêtes", dd.map != null and dd.map.nav_ready())
	check("10 structures : 8 tours et 2 Cœurs", dd.structures.size() == 10 and dd.cores[0] != null and dd.cores[1] != null)
	var groups_ok := true
	for s in dd.structures:
		groups_ok = groups_ok and not s.is_in_group("heroes") and not s.is_in_group("monsters") and s.is_in_group("ffa")
	check("structures hors de « heroes » / « monsters », dans le chacun-pour-soi de leur équipe", groups_ok)
	var t2: MobaStructure = dd.structure_of(1, 0, 2)
	check("T2 invulnérable tant que la T1 de sa voie tient ; Cœur tant que ses T2 tiennent", t2 != null and t2.invulnerable()
		and not dd.structure_of(1, 0, 1).invulnerable() and dd.cores[1].invulnerable())
	check("aucun héros : le joueur hors de tout camp", dd.heroes.is_empty() and TeamMatch.team_of(world.player) == -1)
	check("réserve de sbires préparée au chargement", int(dd.stats.created_load) >= 60)
	# deux vagues (≈ 1:40 de partie à × 4)
	await _until(func(): return Moba.t >= 105.0, 60 * 60)
	check("deux vagues parties (%d sbires apparus)" % int(dd.stats.spawned), dd.wave_n >= 2 and int(dd.stats.spawned) >= 40)
	var m: MobaMinion = null
	for x in dd.minions:
		if not x.is_dead:
			m = x
			break
	check("un sbire en jeu", m != null)
	if m != null:
		check("sbire : mode horde, camp de son équipe (ffa_id), pas membre de TeamMatch", m.lite and m.ffa_id == TeamMatch.FFA_BASE + m.side
			and TeamMatch.team_of(m) == -1 and m.is_in_group("ffa"))
		check("sbire : force relative au héros attendu", m.max_hp > 0.0 and m.atk > 0.0 and m.struct_units > 0.0)
	var kinds := {}
	for x in dd.minions:
		kinds[x.kind] = int(kinds.get(x.kind, 0)) + 1
	check("vagues : mêlées et tireurs", int(kinds.get("melee", 0)) > 0 and int(kinds.get("ranged", 0)) > 0)
	check("fronts : les vagues ont avancé sur les deux voies", float(dd.fronts[0][0]) > 30.0 and float(dd.fronts[1][1]) > 30.0)
	check("sbires vivants sous le plafond (%d)" % int(dd.stats.max_alive), int(dd.stats.max_alive) <= MobaData.MINION_CAP)
	check("aucun sbire créé pendant la partie (recyclage)", int(dd.stats.created_live) == 0)
	check("les sbires se battent (%d - %d tués)" % [Moba.minion_kills[0], Moba.minion_kills[1]], Moba.minion_kills[0] + Moba.minion_kills[1] > 0)
	var lods := 0
	for x in dd.minions:
		if not x.is_dead and x.lod > 0:
			lods += 1
	check("niveau de détail : les sbires loin de la caméra pensent moins souvent (%d)" % lods, lods > 0)
	TeamMatch.end()
	Moba.reset()
	Engine.time_scale = 1.0
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false
	check("après la partie : menu, rien de scellé", Modes.current() == "menu" and not Modes.sealed())


## Partie accélérée dans un processus à part : lignes « [moba] … » de sa sortie.
func _run(extra: Array) -> Array:
	var args := ["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"), "res://scenes/world.tscn", "--",
		"--moba", "--moba-heroes=none", "--moba-speed=4", "--auto-quit"] + extra
	var out := []
	var t0 := Time.get_ticks_msec()
	OS.execute(OS.get_executable_path(), args, out, true)
	var lines: Array = []
	for chunk in out:
		for l in String(chunk).split("\n"):
			if l.begins_with("[moba]"):
				lines.append(l)
	print("[mb-c] partie %s : %.0f s" % [" ".join(extra), (Time.get_ticks_msec() - t0) / 1000.0])
	for l in lines:
		if "tombe" in l or "mesure" in l or "tour :" in l:
			print("  ", l.left(220))
	return lines


func _long_runs() -> void:
	var sym := _run(["--moba-until=1200", "--moba-seed=4"])
	var fell := sym.filter(func(l): return "tombe" in l)
	check("20 min de vagues égales : aucune structure ne tombe (%d)" % fell.size(), fell.is_empty() and sym.any(func(l): return "mesure" in l))
	var adv := _run(["--moba-until=780", "--moba-power=1.2,1.0", "--moba-seed=2", "--moba-stop=tower"])
	var first := ""
	for l in adv:
		if "tombe" in l:
			first = l
			break
	var secs := -1
	var re := RegEx.create_from_string("([0-9]+):([0-9][0-9])[ \\t\\r]*$")  # (la sortie du processus peut arriver dans un autre codage : on ne lit que l'heure)
	var hit := re.search(first.strip_edges())
	if hit != null:
		secs = int(hit.get_string(1)) * 60 + int(hit.get_string(2))
	print("[mb-c] camp bleu × 1,2 : %s" % (first if first != "" else "aucune tour tombée en 13 min"))
	check("un camp × 1,2 : la première tour tombée est une T1 adverse (%s)" % ("Tour 1 rouge" if first.contains("Tour 1 rouge") else first.get_slice("] ", 1).left(24)),
		first.contains("Tour 1 rouge"))
	check("… vers 8-10 min (%d:%02d ; accepté 7:30-11:00)" % [secs / 60, secs % 60], secs >= 450 and secs <= 660)


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
