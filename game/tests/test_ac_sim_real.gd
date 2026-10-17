extends Node
## L'Échiquier, lot AC-J : le simulateur (AutochessSim) reste calé sur le vrai combat et la mesure de masse reste celle du
## rapport (conception/autochess/R_AC_J.md). Relit tests/ac_mesures.json (chiffres de référence de la dernière passe AC-J) :
## - réglages du simulateur (AutochessSim.TUNE) et du combat (dmg_scale, égalité) identiques à ceux de la mesure ;
## - accord simulateur / vrai combat sur un échantillon court (combats de calage joués des deux façons) ;
## - quelques parties entre IA au simulateur : durées, manches et échelle des difficultés dans de larges bornes autour des
##   chiffres de référence.
## Changer un réglage (TUNE, dmg_scale, données d'unités, de traits, d'objets, d'atouts, IA) demande de refaire la mesure et
## ce fichier (R_AC_J.md, « Relancer »).
## godot --headless --path game res://tests/test_ac_sim_real.tscn   (AC_REAL_QUICK=1 : sans les vrais combats)

const Tool := preload("res://tools/autochess_fight.gd")
const Games := preload("res://tools/autochess_games.gd")
const MESURES := "res://tests/ac_mesures.json"

var fails := 0
var ref: Dictionary = {}


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	seed(29)
	Training.active = false
	Settings.reset_all()
	var ui: Dictionary = Settings.data.get("interface", {})
	ui["hit_stop"] = false
	Settings.data["interface"] = ui
	var fa := FileAccess.open(MESURES, FileAccess.READ)
	check("tests/ac_mesures.json lisible", fa != null)
	if fa != null:
		var d: Variant = JSON.parse_string(fa.get_as_text())
		ref = d if d is Dictionary else {}
	check("tests/ac_mesures.json : chiffres de référence présents", ref.has("tune") and ref.has("short") and ref.has("games"))
	if ref.has("tune"):
		_test_settings()
		_test_games()
		if OS.get_environment("AC_REAL_QUICK") != "1":
			await _test_real()
	print("durée : %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# --- Réglages ------------------------------------------------------------------------------------------------------
func _test_settings() -> void:
	var diff: Array = []
	var tune: Dictionary = ref.tune
	for k in tune:
		if not AutochessSim.TUNE.has(k) or absf(float(AutochessSim.TUNE[k]) - float(tune[k])) > 0.0001:
			diff.append("%s %s / %s" % [k, str(AutochessSim.TUNE.get(k)), str(tune[k])])
	check("AutochessSim.TUNE = réglages de la mesure (écarts : %s ; sinon refaire la mesure, R_AC_J.md)" % str(diff), diff.is_empty())
	var ds := ModeRules.num("dmg_scale", 0.0, "autochess")
	check("dmg_scale du profil autochess = celui de la mesure (%.3f / %.3f)" % [ds, float(ref.dmg_scale)],
		absf(ds - float(ref.dmg_scale)) < 0.0001)


# --- Parties entre IA ------------------------------------------------------------------------------------------------
func _test_games() -> void:
	var gref: Dictionary = ref.games
	var tool: Node = Games.new()
	tool.set("fight_name", "sim")
	tool.set("_fight", AutochessSim.fight)
	var n := int(gref.get("check_games", 8))
	var jcj: Array = []
	var rounds := 0.0
	var minutes := 0.0
	var places := [[], [], [], []]
	var stuck := 0
	for k in n:
		var g: Dictionary = tool.play(int(gref.get("check_seed", 9001)) + k, "echelle")
		jcj.append_array(g.jcj)
		rounds += float(g.rounds)
		minutes += float(g.min.total)
		for p in g.players:
			(places[int(p.d)] as Array).append(int(p.place))
	stuck = int(tool.get("stuck"))
	tool.free()
	check("%d parties entre IA (simulateur) jouées jusqu'au bout" % n, stuck == 0)
	var med := Tool.median(jcj)
	var rmed := float(gref.fight_median)
	check("combat JcJ médian %.1f s proche de la référence %.1f s (± 25 %%)" % [med, rmed], absf(med - rmed) <= 0.25 * rmed)
	var mr := rounds / maxf(n, 1)
	check("manches par partie %.1f proche de la référence %.1f (± 4)" % [mr, float(gref.rounds)], absf(mr - float(gref.rounds)) <= 4.0)
	var mm := minutes / maxf(n, 1)
	check("durée d'une partie %.1f min proche de la référence %.1f min (± 15 %%)" % [mm, float(gref.minutes)],
		absf(mm - float(gref.minutes)) <= 0.15 * float(gref.minutes))
	var avg: Array = []
	for d in 4:
		avg.append(_mean(places[d]))
	check("échelle : Recrue derrière Vétéran, Vétéran derrière Légende (places %s ; référence %s)" % [str(avg.map(func(x): return snappedf(x, 0.01))), str(gref.ladder)],
		float(avg[0]) > float(avg[1]) and float(avg[1]) > float(avg[3]))
	check("Recrue dans les dernières places (%.2f ; référence %.2f, seuil 5,5)" % [float(avg[0]), float(gref.ladder[0])], float(avg[0]) >= 5.5)


static func _mean(a: Array) -> float:
	var s := 0.0
	for x in a:
		s += float(x)
	return s / maxf(float(a.size()), 1.0)


# --- Accord simulateur / vrai combat (échantillon court) ---------------------------------------------------------------
func _test_real() -> void:
	var sh: Dictionary = ref.short
	var fights := Tool.calib_fights(int(sh.n), int(sh.seed))
	var dir := AutochessDirector.new()
	add_child(dir)
	dir.fallback_ms = 0.0
	var ticks := Engine.physics_ticks_per_second
	var steps := Engine.max_physics_steps_per_frame
	# 4 × plus vite à pas de physique inchangé (1/60 s de jeu), comme test_ac_sim
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 16
	dir.set_speed(4.0)
	var real: Array = []
	var i := 0
	while i < fights.size():
		dir.begin(fights.slice(i, i + 8), 0)
		for a in dir.arenas:
			a.ctx["keep_log"] = true
		if dir.running:
			await dir.round_finished
		for a in dir.arenas:
			real.append(Tool.measures(a.ctx, a.result))
		dir.clear()
		i += 8
	Engine.physics_ticks_per_second = ticks
	Engine.max_physics_steps_per_frame = steps
	AutochessDirector.speed = 1.0
	dir.queue_free()
	var sim: Array = []
	for f in fights:
		sim.append(Tool.sim_one(f))
	var g := Tool.agreement(real, sim)
	print("[ac_real] " + Tool.agreement_line(g))
	var calib: Dictionary = ref.calib
	check("même vainqueur que le vrai combat : %.0f %% sur %d (calage de référence %s sur 2 × 100 ; seuil %.0f %%)" % [
		100.0 * float(g.agree), int(g.n), str(calib.agree), 100.0 * float(sh.agree_min)], float(g.agree) >= float(sh.agree_min))
	check("durée médiane : écart %.0f %% (vrai %.1f s, simulé %.1f s ; seuil %.0f %%)" % [100.0 * float(g.dur_gap),
		float(g.dur_real), float(g.dur_sim), 100.0 * float(sh.dur_gap_max)], float(g.dur_gap) <= float(sh.dur_gap_max))
	check("durée vraie médiane %.1f s proche du calage de référence %s (± 30 %%)" % [float(g.dur_real), str(calib.dur_real)],
		absf(float(g.dur_real) - _mean(calib.dur_real)) <= 0.3 * _mean(calib.dur_real))
	var ra: float = g.autos[0]
	var sa: float = g.autos[1]
	check("rythme des auto-attaques : vrai %.3f / simulé %.3f par unité-s (écart ≤ 20 %%)" % [ra, sa], absf(sa - ra) <= 0.2 * ra)
