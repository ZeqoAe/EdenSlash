extends Node
## Sonde de performances du Colisée (lot CO-C, ARENA.md § 6.16, R_CO_C.md) : une vraie partie (world.tscn, directeur du
## combat, vrais héros scriptés et leurs sorts, combats cachés) dont on mesure la 1re manche : tous les combats en même
## temps pendant --seconds s. Lignes « [colisee] image … » (médiane, p95, p99, max de la durée d'une image en ms réelles,
## une image = un pas de physique avec --fixed-fps 60) et « [colisee] chargement … » ; une ligne JSON « [colisee] json {…} ».
## Critères (décision du Grand tournoi) : image médiane ≤ 8 ms et p95 ≤ 16 ms avec 24 héros en Hardcore ; chargement < 1,5 s.
##
## godot --headless --fixed-fps 60 --path game res://tools/colisee_probe.tscn -- --teams=6|8 [--diff=3] [--seconds=30]
##   [--seed=N] [--class=warrior]     (--fixed-fps 60 : une image = un pas de physique, sans attente : on mesure le calcul)
## Sans --headless (fenêtre) : même mesure, rendu de l'arène regardée compris.

var teams := 6
var diff := 3
var seconds := 30.0
var seed_value := 4242
var world: Node
var t_begin := 0
var t_fight := 0
var frames: Array = []
var fighting := false
var fight_t := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--teams="):
			teams = int(arg.trim_prefix("--teams="))
		elif arg.begins_with("--diff="):
			diff = int(arg.trim_prefix("--diff="))
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--seed="):
			seed_value = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--class="):
			Profile.selected_class = arg.trim_prefix("--class=")
	Settings.reset_all(false)
	if Profile.selected_class == "":
		Profile.selected_class = "warrior"
	ColiseeDirector.probe = true
	t_begin = Time.get_ticks_msec()
	var fmt := "grand" if teams >= 8 else ("eclair" if teams == 4 else "classique")
	Colisee.begin(Profile.selected_class, fmt, diff, seed_value, teams)
	world = load("res://scenes/world.tscn").instantiate()
	world.ready.connect(func(): world.player.autoplay = true)
	get_tree().root.add_child.call_deferred(world)


func _process(delta: float) -> void:
	if world == null or not world.is_inside_tree() or world.get("director") == null:
		return
	var dd = world.director.team
	if dd == null or not is_instance_valid(dd):
		return
	if not fighting:
		if dd.phase == "fight":
			fighting = true
			t_fight = Time.get_ticks_msec()
		return
	fight_t += delta
	if fight_t >= seconds:
		_report(dd)
		set_process(false)
		get_tree().quit()


static func _stats(a: Array) -> Dictionary:
	if a.is_empty():
		return {"med": 0.0, "p95": 0.0, "p99": 0.0, "max": 0.0, "n": 0}
	var s := a.duplicate()
	s.sort()
	return {"med": snappedf(float(s[s.size() / 2]), 0.01), "p95": snappedf(float(s[int(s.size() * 0.95)]), 0.01),
		"p99": snappedf(float(s[mini(s.size() - 1, int(s.size() * 0.99))]), 0.01), "max": snappedf(float(s[-1]), 0.01), "n": s.size()}


func _report(dd) -> void:
	# les 2 premières secondes (apparition des héros cachés, 3 par image) comptent à part
	var all: Array = dd.frame_ms.slice(1)
	var warm := mini(all.size(), 120)
	var steady := all.slice(warm)
	var heroes := 0
	var alive := 0
	for f in dd.fights:
		for side in 2:
			for c in f.heroes[side]:
				if is_instance_valid(c):
					heroes += 1
					if not (c as Combatant).is_dead:
						alive += 1
	var godots := _godot_count()
	var st := _stats(steady)
	var res := {"teams": teams, "heroes": heroes, "alive_end": alive, "diff": diff, "seconds": seconds, "seed": seed_value,
		"headless": DisplayServer.get_name() == "headless", "image": st, "warmup": _stats(all.slice(0, warm)),
		"spawn_ms": snappedf(float(dd.spawn_ms), 0.1),
		"load_ms": t_fight - t_begin, "godots": godots, "fallbacks": dd.fallbacks,
		"pass": float(st.med) <= 8.0 and float(st.p95) <= 16.0}
	print("[colisee] image : %d équipes, %d héros (%d debout à la fin), %s · médiane %.2f ms, p95 %.2f, p99 %.2f, max %.2f (n=%d) · %d Godot actifs"
		% [teams, heroes, alive, Colisee.DIFFS[diff], st.med, st.p95, st.p99, st["max"], st.n, godots])
	print("[colisee] chargement : apparition des héros %.0f ms, du lancement au combat %d ms" % [float(dd.spawn_ms), int(res.load_ms)])
	print("[colisee] json " + JSON.stringify(res))


## Processus Godot en cours sur la machine (charge des mesures, celui-ci compris) ; -1 si inconnu.
static func _godot_count() -> int:
	var out: Array = []
	var code := OS.execute("tasklist", [], out) if OS.get_name() == "Windows" else OS.execute("ps", ["-A"], out)
	if code != 0 or out.is_empty():
		return -1
	var n := 0
	for line in String(out[0]).split("
"):
		if line.to_lower().contains("godot"):
			n += 1
	return n
