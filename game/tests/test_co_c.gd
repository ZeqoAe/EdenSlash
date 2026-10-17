extends Node
## Lot CO-C : directeur du combat du Colisée (core/colisee_director.gd, rapport conception/benchmark/R_CO_C.md). Une vraie
## partie Classique dans world.tscn : 3 combats simultanés dans 3 arènes, chacun fini (à terre ou au temps), aucun coup d'une
## arène à l'autre ni entre équipiers, combats cachés (héros invisibles, animations arrêtées, effets et chiffres coupés),
## regarder un autre combat, mort du joueur (ses alliés continuent, la caméra suit un allié, pas de bilan de Survie), repli
## « au tableau », manche rendue à la machine (PV d'équipe, TeamMatch), puis une finale jusqu'au bilan.
## godot --headless --path game res://tests/test_co_c.tscn

var fails := 0
var hits: Array = []  # voir _on_hit
var watched_heroes := {}


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	await _game()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().paused = false
	get_tree().quit(fails)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().physics_frame


func _until(cond: Callable, max_frames := 300) -> bool:
	for _i in max_frames:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


## Relève les coups de tous les héros de la manche (une fois par héros).
func _watch_hits(dd: ColiseeDirector) -> void:
	for f in dd.fights:
		for side in 2:
			for c in f.heroes[side]:
				if is_instance_valid(c) and not watched_heroes.has(c.get_instance_id()):
					watched_heroes[c.get_instance_id()] = true
					(c as Combatant).damaged.connect(_on_hit.bind(c))


func _game() -> void:
	Profile.selected_class = "warrior"
	ColiseeDirector.fallback = false  # (machine chargée : pas de repli automatique pendant le test ; essayé à la main plus bas)
	var g := Colisee.begin("warrior", "classique", 1, 31)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	var dd: ColiseeDirector = world.director.team
	check("directeur du Colisée monté (état « team »)", dd != null and world.director.state == "team" and TeamMatch.director == dd)
	await _until(func(): return dd.map != null and dd.map._region.navigation_mesh != null, 3600)
	check("carte du Colisée : 3 arènes, navigation cuite", dd.arenas.size() == 3 and dd.map._region.navigation_mesh != null)
	check("aucune carte de compétence offerte, pas de monstre de la Survie", not world.cards.is_open()
		and get_tree().get_nodes_in_group("monsters").all(func(m): return m is ClassRival))
	await _until(func(): return dd.phase == "fight", 900)
	_watch_hits(dd)
	check("manche 1 : 3 combats, 18 héros dont le joueur", dd.fights.size() == 3 and _count(dd) == 18 and d_has_player(dd))
	var arenas_ok := true
	for f in dd.fights:
		for side in 2:
			for c in f.heroes[side]:
				var t := int(f.a) if side == 0 else int(f.b)
				arenas_ok = arenas_ok and (c as Combatant).arena_id == int(f.index) and TeamMatch.team_of(c) == t
	check("chaque héros dans l'arène de son combat et dans son équipe", arenas_ok)
	var mine: Dictionary = dd.fights[dd.watched]
	check("le combat regardé est celui du joueur", int(mine.a) == TeamMatch.player_team and world.player in (mine.heroes[0] as Array))
	var hidden_ok := true
	for f in dd.fights:
		if int(f.index) == dd.watched:
			continue
		for side in 2:
			for c in f.heroes[side]:
				var cc: Combatant = c
				hidden_ok = hidden_ok and not cc.visible and (cc.anim == null or not cc.anim.active) and Vfx.muted(cc)
		hidden_ok = hidden_ok and not (f.arena as ColiseeArena).visible
	check("combats cachés : héros invisibles, animations arrêtées, effets / sons / chiffres coupés, arène non dessinée", hidden_ok)
	check("combat regardé : rendu, effets permis", not Vfx.muted(world.player) and (mine.arena as ColiseeArena).visible)
	await _frames(600)  # 10 s de combat
	_watch_hits(dd)
	# regarder un autre combat puis revenir
	var other := (dd.watched + 1) % 3
	dd.watch(other)
	var sw_ok: bool = (dd.fights[other].arena as ColiseeArena).visible and not (mine.arena as ColiseeArena).visible \
		and Vfx.muted(world.player) and world.rig.target != world.player
	dd.watch(int(mine.index))
	check("regarder un autre combat : son arène est rendue, la tienne cachée ; retour", sw_ok and (mine.arena as ColiseeArena).visible)
	# mort du joueur : les alliés continuent
	world.player.take_damage(world.player.max_hp * 10.0, null, false, true)
	await _frames(3)
	var allies_up := (mine.heroes[0] as Array).filter(func(c): return is_instance_valid(c) and c != world.player and not c.is_dead).size()
	check("mort du joueur : pas de bilan de Survie, rendue au directeur", not world._ended and dd._player_out)
	if allies_up > 0:
		await _frames(30)
		check("la caméra suit un allié debout", is_instance_valid(world.rig.target) and world.rig.target != world.player
			and not (world.rig.target as Combatant).is_dead)
	# repli « au tableau » d'un combat caché encore en cours
	var hid: Dictionary = dd.fights[other]
	if not hid.done:
		dd._resolve_board(hid)
		check("repli au tableau : combat caché fini, noté « tableau »", hid.done and String(hid.result.mode) == "tableau" and dd.fallbacks == 1)
	var t0 := Time.get_ticks_msec()
	await _until(func(): return dd.phase in ["recap", "prep", "done"] or g.round_n > 1, 60 * 100)
	print("[co_c] manche 1 : %s (%.0f s réelles)" % [str(dd.fights.map(func(f): return [f.result.get("winner", -9), f.result.get("time", 0), f.result.get("mode", "")])),
		(Time.get_ticks_msec() - t0) / 1000.0])
	check("les 3 combats de la manche finissent (à terre ou au temps)", dd.fights.all(func(f): return f.done) or g.round_n > 1)
	_watch_hits(dd)
	var cross := 0
	var mates := 0
	var inside := 0
	for h in hits:
		if h[1] == -2:
			continue  # sans source (anneau de feu, zone d'arène)
		if int(h[0]) != int(h[1]):
			cross += 1
		elif int(h[2]) == int(h[3]) and not bool(h[4]):
			mates += 1
		else:
			inside += 1
	print("[co_c] coups relevés : %d dans les arènes, %d entre arènes, %d entre équipiers" % [inside, cross, mates])
	check("des coups dans les arènes", inside > 20)
	check("aucun coup d'une arène à l'autre", cross == 0)
	check("aucun coup entre équipiers", mates == 0)
	await _until(func(): return g.round_n >= 2 and dd.phase in ["prep", "countdown", "fight"], 600)
	check("manche rendue à la machine : PV d'équipe perdus, TeamMatch à la manche 2", g.history.size() == 1
		and g.hp.any(func(h): return int(h) < Colisee.TEAM_HP) and TeamMatch.round_n == 2)
	check("le joueur relevé pour la manche 2 (ou au repos s'il est exempt)", not world.player.is_dead or world.player.arena_id == ColiseeDirector.PARK)
	# finale : il ne reste que le trio du joueur et un autre, à 1 PV
	var keep := TeamMatch.player_team
	var rival := -1
	for f in dd.fights:
		if int(f.a) == keep:
			rival = int(f.b)
	if rival < 0:
		rival = 1 if keep != 1 else 2
	for t in g.n:
		if t != keep and t != rival and not g.out[t]:
			g.hp[t] = -50
			g.out[t] = true
			g.place[t] = g.alive().size() + 1
			TeamMatch.eliminate(t)
	g.hp[keep] = 500  # (la manche 2, finie à la main, ne doit éliminer personne)
	g.hp[rival] = 500
	for f in dd.fights:
		if not f.done:
			dd._end_fight(f, int(f.a))
	await _until(func(): return g.round_n >= 3 and dd.phase in ["prep", "countdown", "fight"], 900)
	g.hp[keep] = 1  # finale : le perdant de la manche 3 est éliminé
	g.hp[rival] = 1
	await _until(func(): return dd.phase == "fight", 900)
	check("finale : un seul combat, trio du joueur contre le dernier trio", dd.fights.size() == 1 and g.alive().size() == 2)
	await _until(func(): return dd.phase == "done", 60 * 100)
	check("fin de partie : bilan, mode d'équipes refermé (%d bilan)" % get_tree().get_nodes_in_group("results_panel").size(),
		dd.phase == "done" and not TeamMatch.active and not Modes.team_match() and Colisee.game == null
		and get_tree().get_nodes_in_group("results_panel").size() == 1)
	var places: Array = g.place.duplicate()
	places.sort()
	check("places uniques de 1 à 6 (%s)" % str(g.place), places == [1, 2, 3, 4, 5, 6])
	check("plus aucun effet coupé après la partie", Vfx.hidden_arenas.is_empty())
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false
	ModeRules._extra.erase("colisee")
	ColiseeDirector.fallback = true


## Coup relevé au moment où il tombe (un héros tombé est libéré ensuite) : [arène victime, arène source (-2 : sans source),
## équipe victime, équipe source, coup sur soi].
func _on_hit(_amount: float, src: Combatant, victim: Combatant) -> void:
	if src == null or not is_instance_valid(src):
		hits.append([victim.arena_id, -2, TeamMatch.team_of(victim), -1, false])
		return
	hits.append([victim.arena_id, src.arena_id, TeamMatch.team_of(victim), TeamMatch.team_of(src), src == victim])


func _count(dd: ColiseeDirector) -> int:
	var n := 0
	for f in dd.fights:
		for side in 2:
			n += (f.heroes[side] as Array).size()
	return n


func d_has_player(dd: ColiseeDirector) -> bool:
	for f in dd.fights:
		if dd.d.player in (f.heroes[0] as Array):
			return true
	return false
