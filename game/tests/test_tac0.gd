extends Node
## Lot TAC-0 : socle de L'Assaut (Assault, AssaultDirector, fiche « assault » de TeamMatch, profil « assault » de ModeRules).
## 1) machine de manche pure : achat -> manche -> pose / désamorçage -> fin, primes (victoire, défaite progressive qui
##    redescend d'un cran, élimination, aide, pose, désamorçage, pas de prime aux attaquants vivants au temps écoulé,
##    plafond), mi-temps (côtés, or), prolongation (or fixe, côtés alternés, 2 d'écart, manche décisive), format Éclair,
##    parties tirées au hasard ;
## 2) partie réelle IA contre IA en accéléré dans world.tscn sur l'arène simple (le joueur regarde) : une manche libre, une
##    manche « pose puis désamorçage », une manche au temps, mi-temps ; aucun coup entre équipiers ; navigation cuite avant
##    la fin ; fin de partie propre (TeamMatch fermé, menu, vitesse rendue).
## godot --headless --path game res://tests/test_tac0.tscn

var fails := 0
const K := [["a0", "a1", "a2", "a3"], ["b0", "b1", "b2", "b3"]]


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_rules_and_mode()
	_round_flow()
	_halftime_and_overtime()
	_random_matches()
	_eclair()
	await _world_match()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


# --- 1. règles et mode ---------------------------------------------------------------------------

func _rules_and_mode() -> void:
	Assault.ensure_rules()
	check("profil « assault » enregistré", ModeRules.has_profile("assault"))
	TeamMatch.begin("assault", 2, {})
	check("mode courant assault, type objectif, scellé, JcJ", Modes.current() == "assault" and Modes.kind() == "objective"
		and Modes.sealed() and Modes.is_pvp() and Modes.hero_match())
	check("ni Duel.active ni Royale.active (piège 1 de R_MODE0)", not Duel.active and not Royale.active)
	check("règles de combat du profil : échelle 0,13, coup ≤ 25 %, rafale ≤ 55 %", ModeRules.profile_name() == "assault"
		and is_equal_approx(PvpCaps.damage_scale(), 0.13) and is_equal_approx(ModeRules.num("hit_cap"), 0.25)
		and is_equal_approx(ModeRules.num("burst_cap"), 0.55))
	check("ni potions, ni cartes de niveau, ni journal, ni sauvegarde", not TeamMatch.allows("potions")
		and not TeamMatch.allows("level_cards") and not TeamMatch.allows("journal") and not TeamMatch.allows("save"))
	DevEdits.data["modes"] = {"assault": {"round_time": 77.0}}
	check("mode dev : une règle de manche se surcharge", is_equal_approx(Assault.num("round_time"), 77.0))
	DevEdits.data["modes"] = {}
	TeamMatch.end()
	check("activité « L'Assaut » cachée (Bientôt) tant que le mode n'est pas jouable", bool(Activities.get_def("assault").get("soon", false)))
	var kit := Assault.kit_for("warrior")
	var ids: Array = (GameData.class_data("warrior").get("skills", []) as Array).map(func(s): return int(s.id))
	check("kit provisoire : 4 sorts de la classe (%s)" % str(kit), kit.size() == 4 and kit.all(func(id): return int(id) in ids))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var team := Assault.pick_classes(rng, 4, ["warrior"])
	check("équipe tirée : 4 classes différentes, ni la tienne ni les exclues", team.size() == 4 and not "warrior" in team
		and team.all(func(c): return team.count(c) == 1 and not c in Assault.AI_EXCLUDED))


# --- 2. une manche, puis la suivante ---------------------------------------------------------------

func _run(secs: float, step := 0.25) -> Array:
	var ev: Array = []
	var left := secs
	while left > 0.0:
		ev += Assault.tick(minf(step, left))
		left -= step
	return ev


func _types(ev: Array) -> Array:
	return ev.map(func(e): return String(e.type))


func _round_flow() -> void:
	Assault.begin(K, {"first_attack": 1, "seed": 7})
	check("début : achat de 25 s, l'équipe 1 attaque, 800 d'or chacun", Assault.phase == "buy" and is_equal_approx(Assault.t, 25.0)
		and Assault.attack == 1 and K[0].all(func(k): return Assault.gold(k) == 800))
	var ev := _run(25.1)
	check("fin de l'achat : manche de 1:40", "live" in _types(ev) and Assault.phase == "live" and Assault.t > 99.0)
	Assault.ko("b0", "a0", ["a1"])
	check("élimination +200, aide +50", Assault.gold("a0") == 1000 and Assault.gold("a1") == 850 and Assault.gold("a2") == 800)
	ev = Assault.plant("A", "b1")
	check("pose : mèche de 40 s, +300 à chaque attaquant (même tombé)", Assault.phase == "planted" and is_equal_approx(Assault.t, 40.0)
		and Assault.gold("b0") == 1100 and Assault.gold("b3") == 1100 and Assault.site == "A")
	check("pas de pose pour la Défense", Assault.plant("B", "a0").is_empty())
	for k in ["b1", "b2", "b3"]:
		ev = Assault.ko(k, "a3")
	check("Attaque à terre après la pose : la manche continue", ev.is_empty() and Assault.phase == "planted")
	ev = Assault.defuse("a2")
	check("désamorçage : la Défense gagne la manche", "defused" in _types(ev) and "round_end" in _types(ev) and Assault.score == [1, 0]
		and String(Assault.history[0].how) == "defuse")
	check("primes : victoire +2 400, désamorçage +200, défaite 1 500", Assault.gold("a2") == 800 + 200 + 2400
		and Assault.gold("b1") == 1100 + 1500 and Assault.gold("a3") == 800 + 600 + 2400)
	ev = _run(5.1)
	check("bandeau de 5 s puis manche 2 : achat de 20 s", "next" in _types(ev) and Assault.round_n == 2 and Assault.phase == "buy"
		and Assault.t > 19.5 and Assault.t <= 20.0)
	_run(20.1)
	Assault.ko("b0", "a0")
	var before_b0 := Assault.gold("b0")
	var before_b1 := Assault.gold("b1")
	ev = _run(100.1)
	check("temps écoulé sans pose : la Défense gagne", "time" in _types(ev) and Assault.score == [2, 0] and String(Assault.history[1].how) == "time")
	check("attaquant vivant au temps : pas de prime ; tombé : 1 900 (2e défaite)", Assault.gold("b1") == before_b1
		and Assault.gold("b0") == before_b0 + 1900)
	_run(5.1)
	_run(20.1)
	Assault.plant("B", "b2")
	for k in K[0]:
		ev = Assault.ko(k, "b2")
	check("Défense à terre après la pose : l'Attaque gagne tout de suite", Assault.score == [2, 1] and String(Assault.history[2].how) == "elim")
	check("une victoire fait redescendre la série d'un cran", int(Assault.streak[1]) == 1 and Assault.next_loss_gold(1) == 1900)
	_run(5.1)
	_run(20.1)
	Assault.plant("A", "b0")
	ev = _run(40.1)
	check("la mèche va au bout : l'Attaque gagne (Charge)", "explode" in _types(ev) and Assault.score == [2, 2] and String(Assault.history[3].how) == "charge")
	Assault.money["a0"] = 6900
	Assault.give("a0", 500)
	check("plafond de 7 000", Assault.gold("a0") == 7000)
	check("point de sauvegarde du désamorçage à la moitié", is_equal_approx(Assault.defuse_resume(4.0, 7.0), 3.5)
		and is_equal_approx(Assault.defuse_resume(3.0, 7.0), 0.0))


# --- 3. mi-temps, prolongation -------------------------------------------------------------------

## Joue une manche gagnée par [param w] de la façon [param how] (elim, time, charge, defuse ; charge / defuse : selon le côté).
func _play(w: int, how := "elim") -> void:
	if Assault.phase == "buy":
		_run(Assault.t + 0.05, 1.0)
	var l := 1 - w
	match how:
		"time":
			if w == Assault.defense():
				_run(Assault.t + 0.05, 1.0)
				return
		"charge":
			if w == Assault.attack:
				Assault.plant("A", String(Assault.members[w][0]))
				_run(Assault.t + 0.05, 1.0)
				return
		"defuse":
			if w == Assault.defense():
				Assault.plant("A", String(Assault.members[l][0]))
				Assault.defuse(String(Assault.members[w][0]))
				return
	for k in Assault.members[l]:
		Assault.ko(String(k), String(Assault.members[w][0]))


func _next() -> void:
	if Assault.phase == "end":
		_run(Assault.t + 0.05, 1.0)


func _halftime_and_overtime() -> void:
	Assault.begin(K, {"first_attack": 1, "seed": 11})
	var sides: Array = []
	for i in 6:
		sides.append(Assault.attack)
		_play(i % 2)
		_next()
	check("1re moitié : l'équipe 1 attaque les 6 manches", sides.all(func(s): return s == 1))
	check("mi-temps : on change de côté, 800 d'or chacun, séries remises", Assault.round_n == 7 and Assault.attack == 0
		and Assault.phase == "buy" and Assault.t > 24.5 and (K[0] + K[1]).all(func(k): return Assault.gold(k) == 800)
		and Assault.streak == [0, 0])
	for i in 6:
		_play(i % 2)
		_next()
	check("6-6 après 12 manches : prolongation", Assault.score == [6, 6] and Assault.round_n == 13 and Assault.winner == -1)
	check("prolongation : 4 000 d'or fixes", (K[0] + K[1]).all(func(k): return Assault.gold(k) == 4000))
	var a13 := Assault.attack
	_play(0)
	_next()
	check("prolongation : une manche par côté", Assault.attack == 1 - a13 and (K[0] + K[1]).all(func(k): return Assault.gold(k) == 4000))
	_play(1)
	_next()
	check("7-7 : pas encore de vainqueur (2 manches d'écart)", Assault.winner == -1 and Assault.score == [7, 7])
	for i in 4:  # deux blocs encore à égalité
		_play(i % 2)
		_next()
	check("3 blocs à égalité : manche décisive", Assault.decisive and Assault.round_n == 19 and Assault.score == [9, 9])
	_play(1)
	check("manche décisive : son vainqueur gagne la partie", Assault.winner == 1)
	var ev := _run(Assault.t + 0.05, 1.0)
	check("fin de partie : phase done", "done" in _types(ev) and Assault.phase == "done")
	# prolongation gagnée par 2 d'écart
	Assault.begin(K, {"first_attack": 0, "seed": 12})
	for i in 12:
		_play(i % 2)
		_next()
	_play(0)
	_next()
	_play(0)
	check("prolongation : 2 manches d'écart gagnent (8-6)", Assault.winner == 0 and Assault.score == [8, 6])
	# premier à 7 dans le temps réglementaire
	Assault.begin(K, {"first_attack": 1, "seed": 13})
	for i in 7:
		_play(0)
		_next()
	check("7-0 : partie gagnée en 7 manches", Assault.winner == 0 and Assault.round_n == 7 and Assault.phase == "done")


func _random_matches() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var bad := 0
	var rounds: Array = []
	for g in 200:
		Assault.begin(K, {"first_attack": rng.randi() % 2, "seed": g})
		var guard := 0
		while Assault.phase != "done" and guard < 60:
			guard += 1
			_play(rng.randi() % 2, ["elim", "time", "charge", "defuse"][rng.randi() % 4])
			_run(Assault.t + 0.05, 1.0)
		var s0 := int(Assault.score[0])
		var s1 := int(Assault.score[1])
		var w := Assault.winner
		var ok := Assault.phase == "done" and w >= 0 and int(Assault.score[w]) > int(Assault.score[1 - w])
		if Assault.round_n <= 12:
			ok = ok and int(Assault.score[w]) == 7
		elif not Assault.decisive:
			ok = ok and absi(s0 - s1) == 2
		var by_side := Assault.history.all(func(e): return int(e.winner) in [0, 1] and String(e.how) in Assault.HOW)
		if not ok or not by_side or Assault.history.size() != Assault.round_n:
			bad += 1
		rounds.append(Assault.round_n)
	rounds.sort()
	check("200 parties au hasard : un vainqueur valable à chaque fois (manches : %d à %d, médiane %d)" % [rounds[0], rounds[-1], rounds[100]], bad == 0)


func _eclair() -> void:
	Assault.begin(K, {"format": "eclair", "first_attack": 1, "seed": 5})
	check("Éclair : premier à 4, 1 200 d'or", int(Assault.num("win")) == 4 and Assault.gold("a0") == 1200)
	for i in 3:
		_play(i % 2)
		_next()
	check("Éclair : mi-temps après 3 manches", Assault.round_n == 4 and Assault.attack == 0)
	for i in 3:
		_play((i + 1) % 2)
		_next()
	_play(0)
	check("Éclair : 3-3 puis la 7e manche décide (%s)" % str(Assault.score), Assault.winner == 0 and Assault.round_n == 7 and Assault.score[0] == 4)
	Assault.reset()


# --- 4. partie réelle en accéléré : 8 IA sur l'arène simple -------------------------------------------

func _world_match() -> void:
	Profile.selected_class = "warrior"
	var opts := {"map": "arena", "watch": true, "seed": 4242, "speed": 3.0, "win": 3, "half": 2, "max_rounds": 4,
		"overtime": false, "buy_time": 2.0, "buy_time_first": 2.0, "round_time": 30.0, "banner": 1.0, "fuse": 22.0}
	Assault.launch("warrior", opts)
	check("lancement : TeamMatch « assault », directeur du mode, rien d'équipé", TeamMatch.active and TeamMatch.mode == "assault"
		and String(TeamMatch.spec.director) == Assault.DIRECTOR and Profile.equipped.is_empty() and Run.skills.size() == 4)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 600)
	var dd: AssaultDirector = world.director.team
	check("AssaultDirector monté (état « team »)", dd != null and world.director.state == "team" and TeamMatch.director == dd)
	await _until(func(): return world.director.map != null and world.director.map._region.navigation_mesh != null, 3600)
	check("navigation cuite", world.director.map._region.navigation_mesh != null)
	check("8 héros scriptés, 4 par équipe, chacun dans son camp", dd.heroes.size() == 8 and TeamMatch.members(0).size() == 4
		and TeamMatch.members(1).size() == 4 and not world.player in TeamMatch.members(0))
	check("vitesse du jeu (mesures) : ×3", is_equal_approx(Engine.time_scale, 3.0))
	# manche 1 : libre
	await _until(func(): return Assault.round_n >= 2 or Assault.phase == "done", 20000)
	check("manche 1 jouée (%s)" % (dd.round_lines[0] if not dd.round_lines.is_empty() else "?"), Assault.history.size() >= 1)
	# manche 2 : la Défense mise à l'écart -> l'Attaque pose ; puis l'Attaque à l'écart -> la Défense désamorce
	if Assault.phase != "done":
		await _until(func(): return Assault.phase == "live", 4000)
		var tsite := dd.target_site
		var away := dd.site_pos("B" if tsite == "A" else "A")
		await _until(func(): return _sideline(dd, Assault.defense(), away) or Assault.phase != "live", 6000)
		check("manche 2 : la Charge est posée (%s)" % Assault.phase, Assault.phase == "planted" and Assault.site == tsite)
		if Assault.phase == "planted":
			for k in Assault.members[Assault.defense()]:
				var h := dd.hero(String(k)) as ClassRival
				if h != null:
					h.passive = false
			var att_spawn: Vector3 = dd.layout.spawns.attack.pos  # (loin de la Charge et des défenseurs mis à l'écart)
			await _until(func(): return _sideline(dd, Assault.attack, att_spawn) or Assault.phase != "planted", 6000)
			check("manche 2 : la Défense désamorce (%s)" % (dd.round_lines[-1] if not dd.round_lines.is_empty() else "?"),
				Assault.history.size() >= 2 and String(Assault.history[1].how) == "defuse")
	# manche 3 : tout le monde immobile -> temps écoulé ; côtés changés à la mi-temps (après 2 manches)
	if Assault.phase != "done":
		await _until(func(): return Assault.round_n >= 3 and Assault.phase == "live" or Assault.phase == "done", 4000)
		if Assault.phase != "done":
			var att3 := Assault.attack
			await _until(func(): return _freeze_all(dd) or Assault.round_n > 3 or Assault.phase == "done", 6000)
			check("mi-temps : l'équipe qui attaque change (manches 1-2 : %d, manche 3 : %d)" % [int(Assault.history[0].attack), att3],
				att3 != int(Assault.history[0].attack))
			check("manche 3 : temps écoulé, la Défense gagne", Assault.history.size() >= 3 and String(Assault.history[2].how) == "time"
				and int(Assault.history[2].winner) != int(Assault.history[2].attack))
	await _until(func(): return dd._ended, 20000)
	check("fin de partie (%s)" % " | ".join(dd.round_lines), dd._ended and Assault.winner >= 0 and Assault.history.size() >= 3)
	check("aucun coup entre équipiers", dd.friendly_hits == 0)
	check("des K.O. pendant la partie", Assault.stats.values().any(func(s): return int(s.kills) > 0))
	check("après la partie : TeamMatch fermé, menu, rien de scellé, vitesse rendue", not TeamMatch.active and Modes.current() == "menu"
		and not Modes.sealed() and is_equal_approx(Engine.time_scale, 1.0))
	check("bilan affiché", world.get_children().any(func(c): return c is ResultsPanel))
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false


## Met les héros de l'équipe [param t] à l'écart (immobiles, près de [param at]) ; faux pour que l'attente continue.
func _sideline(dd: AssaultDirector, t: int, at: Vector3) -> bool:
	var i := 0
	for k in Assault.members[t]:
		var h := dd.hero(String(k)) as ClassRival
		if h != null and not h.is_dead:
			h.passive = true
			var q := at + Vector3((i - 1.5) * 2.5 + (8.0 if at.x > 48.5 else (-8.0 if at.x < 47.5 else 0.0)), 0, 0)
			if h.global_position.distance_to(q) > 3.0:
				h.global_position = q + Vector3.UP * 0.5
				h.velocity = Vector3.ZERO
		i += 1
	return false


func _freeze_all(dd: AssaultDirector) -> bool:
	for k in dd.heroes:
		var h := dd.hero(String(k)) as ClassRival
		if h != null:
			h.passive = true
	return false


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
