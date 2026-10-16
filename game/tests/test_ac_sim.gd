extends Node
## L'Échiquier, lot AC-C : le simulateur de combats de données (AutochessSim ; rapport conception/autochess/R_AC_C.md).
## Déterminisme (même graine = même combat), format du combat injecté (et une partie d'AC-B jouée avec), durée médiane
## 20-35 s sur 50 combats d'équipes types, chaque trait change le résultat attendu (miroir avec et sans le trait), aucune
## unité hors du plateau, cadence, accord avec le vrai combat sur un échantillon court (20 combats joués des deux façons).
## godot --headless --path game res://tests/test_ac_sim.tscn   (AC_SIM_QUICK=1 : sans les vrais combats)

const Tool := preload("res://tools/autochess_fight.gd")
## Équipes types (rôles de l'annexe A) : plongeurs, tireurs, mur, sorts, soins.
const ARCHETYPES := {
	"plongeurs": ["assassin", "assassin", "assassin", "combattant", "combattant", "tank"],
	"tireurs": ["tireur", "tireur", "tireur", "tank", "tank", "soutien"],
	"mur": ["tank", "tank", "tank", "combattant", "combattant", "soigneur"],
	"sorts": ["mage", "mage", "mage", "tank", "tank", "combattant"],
	"soins": ["soigneur", "soigneur", "tank", "tank", "combattant", "tireur"],
}
const REAL_FIGHTS := 20
const REAL_SEED := 3

var fails := 0
var rng := RandomNumberGenerator.new()


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	rng.seed = 23
	seed(23)
	Training.active = false
	Settings.reset_all()
	var ui: Dictionary = Settings.data.get("interface", {})
	ui["hit_stop"] = false
	Settings.data["interface"] = ui
	_test_determinism()
	_test_format_and_game()
	_test_median()
	_test_traits()
	_test_cadence()
	if OS.get_environment("AC_SIM_QUICK") != "1":
		await _test_real()
	print("durée : %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# --- Déterminisme -------------------------------------------------------------------------------------------------
func _snapshot(f: Dictionary) -> String:
	var ctx := AutochessSim.make_context(f.board_a, f.board_b, f.ctx)
	var r := AutochessSim.run(ctx, 0.0, AutochessDirector.draw_at(), {"counts": true})
	var hp: Array = []
	for fid in ctx.units:
		hp.append([snappedf(float(ctx.units[fid].hp), 0.001), (ctx.units[fid].pos as Vector2).snapped(Vector2(0.001, 0.001))])
	return JSON.stringify([r, hp])


func _test_determinism() -> void:
	var fights := Tool.calib_fights(12, 41)
	var same := 0
	var differ := 0
	for f in fights:
		var a := _snapshot(f)
		var b := _snapshot(f)
		same += 1 if a == b else 0
		var g: Dictionary = f.duplicate(true)
		g.ctx["seed"] = int(g.ctx.seed) + 1
		differ += 1 if _snapshot(g) != a else 0
	check("même graine = même combat (%d / %d identiques : vainqueur, durée, PV et positions de chaque unité)" % [same, fights.size()], same == fights.size())
	check("une autre graine change le combat (%d / %d)" % [differ, fights.size()], differ >= fights.size() / 2)


# --- Format et partie ---------------------------------------------------------------------------------------------
func _test_format_and_game() -> void:
	var f: Dictionary = Tool.calib_fights(1, 7)[0]
	var r := AutochessSim.fight(f.board_a, f.board_b, f.ctx)
	var ok: bool = r.has("winner") and r.has("stars") and r.has("duration") and r.has("gold") and int(r.winner) in [-1, 0, 1] \
		and (r.stars as Array).size() == 2 and (r.gold as Array).size() == 2
	check("résultat au format du combat injecté (winner %d, stars %s, duration %.1f, gold %s)" % [int(r.winner), str(r.stars), float(r.duration), str(r.gold)], ok)
	var strats: Array = []
	for _i in AutochessData.PLAYERS:
		strats.append(Autochess.RandomStrategist.new())
	var g := Autochess.new()
	g.save_path = ""
	var t0 := Time.get_ticks_msec()
	g.start(5, strats, AutochessSim.fight)
	g.play_to_end()
	var ms := Time.get_ticks_msec() - t0
	check("une partie d'AC-B (8 stratèges au hasard) jouée de bout en bout avec le simulateur (%d manches, %d combats, %.1f s)" % [
		g.rounds_played, g.history.size(), ms / 1000.0], g.is_over() and g.rounds_played > 5)


# --- Durée médiane sur 50 combats d'équipes types -----------------------------------------------------------------
func _archetype_team(kind: String, r: RandomNumberGenerator) -> Array:
	var used := {}
	var out: Array = []
	var taken := {}
	var k := 0
	for role in ARCHETYPES[kind]:
		var ids: Array = AutochessData.unit_ids().filter(func(id):
			var d := AutochessData.unit(id)
			return String(d.get("role", "")) == role and int(d.get("cost", 1)) <= 3 and not taken.has(id))
		if ids.is_empty():
			ids = AutochessData.unit_ids().filter(func(id): return int(AutochessData.unit(id).get("cost", 1)) <= 3 and not taken.has(id))
		var id := String(ids[r.randi_range(0, ids.size() - 1)])
		taken[id] = true
		k += 1
		out.append(Tool.make_unit(id, 2 if r.randf() < 0.3 else 1, [], k, [], used))
	return out


func _test_median() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 77
	var kinds: Array = ARCHETYPES.keys()
	var durs: Array = []
	var draws := 0
	var out := 0
	for i in 50:
		var a := _archetype_team(String(kinds[i % kinds.size()]), r)
		var b := _archetype_team(String(kinds[(i / kinds.size() + i + 1) % kinds.size()]), r)
		var f := Tool.make_fight(a, b, 900 + i)
		var ctx := AutochessSim.make_context(f.board_a, f.board_b, f.ctx)
		var res := AutochessSim.run(ctx, 0.0, AutochessDirector.draw_at(), {"counts": true, "bounds": true})
		durs.append(float(res.duration))
		draws += 1 if int(res.winner) < 0 else 0
		out += int(res.counts.out)
	# plateaux pleins et sauts des Ombre : 10 contre 10 aux 4 coins
	for i in 20:
		var f := Tool.make_fight(Tool.random_team(r, 10, 5, 0.3, 0.1, 0.4), Tool.random_team(r, 10, 5, 0.3, 0.1, 0.4), 1900 + i)
		var ctx := AutochessSim.make_context(f.board_a, f.board_b, f.ctx)
		out += int(AutochessSim.run(ctx, 0.0, AutochessDirector.draw_at(), {"counts": true, "bounds": true}).counts.out)
	var med := Tool.median(durs)
	durs.sort()
	print("[ac_sim] 50 combats d'équipes types : médiane %.1f s (min %.1f, max %.1f), égalités %d" % [med, durs[0], durs[-1], draws])
	check("durée médiane de 50 combats d'équipes types entre 20 et 35 s (%.1f s)" % med, med >= 20.0 and med <= 35.0)
	check("égalités rares (%d sur 50)" % draws, draws <= 5)
	check("aucune unité hors du plateau, à aucun pas (70 combats, %d positions hors)" % out, out == 0)


# --- Chaque trait change le résultat attendu ----------------------------------------------------------------------
## Miroir exact (mêmes unités, cases retournées), joué deux fois par graine : le camp A avec le trait à son palier haut,
## puis sans (le camp B n'a jamais de trait). Marge d'un combat = part de PV restants de A − celle de B (+1 / −1 par
## victoire) ; effet du trait = marge avec − marge sans, en moyenne sur les graines (même graine : peu de bruit).
func _trait_margin(t: String, seeds: int) -> Dictionary:
	var carriers: Array = AutochessData.units_with_trait(t)
	carriers.sort_custom(func(x, y):
		var cx := int(AutochessData.unit(x).get("cost", 1))
		var cy := int(AutochessData.unit(y).get("cost", 1))
		return cx < cy or (cx == cy and String(x) < String(y)))
	var team: Array = []
	var used := {}
	for i in mini(6, carriers.size()):
		team.append(Tool.make_unit(String(carriers[i]), 1, [], i + 1, [], used))
	var thr: Array = AutochessData.trait_thresholds(t)
	var effect := 0.0
	var changed := 0
	var wins := [0, 0]
	for s in seeds:
		var m := [0.0, 0.0]
		for with_trait in [true, false]:
			var f := Tool.make_fight(team, team, 3100 + s)
			f.ctx["traits"] = [{t: int(thr[-1])} if with_trait else {}, {}]
			var ctx := AutochessSim.make_context(f.board_a, f.board_b, f.ctx)
			var r := AutochessSim.run(ctx, 0.0, AutochessDirector.draw_at())
			var frac := [0.0, 0.0]
			for side in 2:
				var hp := 0.0
				var mx := 0.0
				for fid in ctx.sides[side]:
					hp += maxf(0.0, float(ctx.units[fid].hp))
					mx += float(ctx.units[fid].hp_max)
				frac[side] = hp / maxf(mx, 1.0)
			var k := 0 if with_trait else 1
			m[k] = frac[0] - frac[1] + (0.0 if int(r.winner) < 0 else (1.0 if int(r.winner) == 0 else -1.0))
			if with_trait and int(r.winner) >= 0:
				wins[int(r.winner)] += 1
		effect += m[0] - m[1]
		changed += 1 if absf(m[0] - m[1]) > 0.01 else 0
	return {"margin": effect / seeds, "wins": wins, "team": team.size(), "changed": changed}


func _test_traits() -> void:
	var weak: Array = []
	var still: Array = []
	var lines: Array = []
	var ids: Array = AutochessData.TRAITS.keys()
	ids.sort()
	const SEEDS := 8
	for t in ids:
		var m := _trait_margin(String(t), SEEDS)
		lines.append("%s %+.2f (%d-%d)" % [t, float(m.margin), int(m.wins[0]), int(m.wins[1])])
		if float(m.margin) <= 0.05:
			weak.append(String(t))
		if int(m.changed) < SEEDS * 3 / 4:
			still.append(String(t))
	print("[ac_sim] traits (effet sur la marge du camp qui a le trait, miroir, %d graines ; victoires avec le trait) : " % SEEDS + ", ".join(lines))
	check("chaque trait (%d) change le combat (fin différente avec et sans, 3 graines sur 4 au moins ; sans effet : %s)" % [ids.size(), str(still)], still.is_empty())
	# Arcane (puissance des sorts) pèse peu tant que les sorts sont rares, souvent esquivés et plafonnés à 20 % des PV
	# (le vrai combat mesure la même chose, R_AC_C.md) ; Ombre est juste au-dessus du seuil : à recaler par AC-J.
	check("les traits aident le camp qui les a (%d sur %d au moins ; faibles : %s)" % [ids.size() - 2, ids.size(), str(weak)], weak.size() <= 2)


# --- Cadence ------------------------------------------------------------------------------------------------------
func _test_cadence() -> void:
	var b: Dictionary = Tool.bench(150)
	# cible 2 000 combats par minute (AC-J) sur une machine libre ; la suite de tests peut tourner à 4 en parallèle
	check("cadence du simulateur : %.0f combats 5 contre 5 par minute (%.1f ms ; cible 2 000, seuil chargé 1 200)" % [float(b.per_min), float(b.ms)],
		float(b.per_min) >= 1200.0)


# --- Accord avec le vrai combat -----------------------------------------------------------------------------------
## 20 compositions jouées en vrai (AutochessDirector, 10 plateaux en même temps, pas de 1/60 s comme en jeu, accéléré)
## puis au simulateur : même vainqueur, durée médiane.
func _test_real() -> void:
	var fights := Tool.calib_fights(REAL_FIGHTS, REAL_SEED)
	var dir := AutochessDirector.new()
	add_child(dir)
	dir.fallback_ms = 0.0
	var ticks := Engine.physics_ticks_per_second
	var steps := Engine.max_physics_steps_per_frame
	# 4 × plus vite à pas de physique inchangé (1/60 s de jeu) : 240 pas par seconde réelle, Engine.time_scale 4
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 16
	dir.set_speed(4.0)
	var real: Array = []
	var i := 0
	while i < fights.size():
		dir.begin(fights.slice(i, i + 10), 0)
		for a in dir.arenas:
			a.ctx["keep_log"] = true
		if dir.running:
			await dir.round_finished
		for a in dir.arenas:
			real.append(Tool.measures(a.ctx, a.result))
		dir.clear()
		i += 10
	Engine.physics_ticks_per_second = ticks
	Engine.max_physics_steps_per_frame = steps
	AutochessDirector.speed = 1.0
	dir.queue_free()
	var sim: Array = []
	for f in fights:
		sim.append(Tool.sim_one(f))
	var g := Tool.agreement(real, sim)
	print("[ac_sim] vrai contre simulé, " + Tool.agreement_line(g))
	check("même vainqueur que le vrai combat dans 75 %% des combats au moins (%.0f %% sur %d ; calage sur 100 : R_AC_C.md)" % [100.0 * float(g.agree), int(g.n)],
		float(g.agree) >= 0.75)
	check("durée médiane proche du vrai combat (écart %.0f %%, vrai %.1f s, simulé %.1f s ; seuil 25 %%)" % [100.0 * float(g.dur_gap), float(g.dur_real), float(g.dur_sim)],
		float(g.dur_gap) <= 0.25)
	check("survivants proches (écart moyen %.2f ; seuil 1,5)" % float(g.surv_gap), float(g.surv_gap) <= 1.5)
