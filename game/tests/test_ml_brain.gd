extends Node
## Cerveau d'IA dans le jeu (MlBrain) : mêmes décisions que Python, temps de calcul.
## godot --headless --path game res://tests/test_ml_brain.tscn -- [res://data/cerveaux/<nom>.json]

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if not args.is_empty() else ""
	if path == "":
		for f in DirAccess.get_files_at("res://data/cerveaux"):
			if f.ends_with(".json"):
				path = "res://data/cerveaux/" + f
				break
	if path == "":
		print("Aucun cerveau dans res://data/cerveaux (lancer ia/export_brain.py)")
		get_tree().quit()
		return
	var b := MlBrain.load_file(path)
	check("chargement de %s" % path.get_file(), b != null and b.obs_size > 0)
	var worst := 0.0
	var same := 0
	for c in b.checks:
		var z := b.logits(c.obs)
		for i in z.size():
			worst = maxf(worst, absf(z[i] - float(c.logits[i])))
		if b.act(c.obs) == (c.act as Array).map(func(x): return int(x)):
			same += 1
	check("mêmes actions que Python (%d / %d)" % [same, b.checks.size()], same == b.checks.size())
	check("écart des sorties < 0,001 (%.6f)" % worst, worst < 0.001)
	var t0 := Time.get_ticks_usec()
	for i in 50:
		b.act(b.checks[0].obs)
	var ms := (Time.get_ticks_usec() - t0) / 50000.0
	check("décision en %.2f ms (20 par seconde : %.0f %% d'un cœur)" % [ms, ms * 2.0], ms < 20.0)
	var r := b.act(b.checks[0].obs, 1.0)
	check("tirage au sort (température 1)", r.size() == b.heads.size())
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit()
