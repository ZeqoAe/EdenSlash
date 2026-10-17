extends Node
## PERF-1 (retour du joueur) : coût de l'appui sur « Prêt » dans L'Échiquier, manche après manche, EN FENÊTRE.
## Partie au pilote (stratège du joueur compris) à vitesse normale ; à chaque préparation, on attend AC_WAIT secondes (le
## temps qu'un joueur réfléchisse : les préchargements de la préparation tournent) puis on appuie sur Prêt et on relève :
## durée de l'appel (fin de préparation + mise en place du combat), puis chaque image jusqu'à 2 s après (la plus longue,
## celles de plus de 100 ms), nœuds créés, unités en jeu. Une ligne « [acready] » par manche, résumé à la fin.
##   AC_PROBE="--rounds=12 --wait=3 --diff=1 --seed=7" godot --path game res://tools/ac_ready_probe.tscn

var rounds := 12
var wait := 3.0
var diff := 1
var seed_value := 7
var rows: Array = []
var _last := 0
var _frames: Array = []  # [ms, nœuds] des images suivies
var _track := false


func _ready() -> void:
	if name != "AcReadyDriver":
		var d: Node = (get_script() as GDScript).new()
		d.name = "AcReadyDriver"
		get_tree().root.add_child.call_deferred(d)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000
	for a in OS.get_environment("AC_PROBE").split(" ", false):
		if a.begins_with("--rounds="):
			rounds = int(a.trim_prefix("--rounds="))
		elif a.begins_with("--wait="):
			wait = float(a.trim_prefix("--wait="))
		elif a.begins_with("--diff="):
			diff = int(a.trim_prefix("--diff="))
		elif a.begins_with("--seed="):
			seed_value = int(a.trim_prefix("--seed="))
	_run.call_deferred()


func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	if _track:
		_frames.append([float(now - _last) / 1000.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	_last = now


func _wait_s(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 240
	Settings.reset_all()
	Profile.reset_all()
	AutochessScreen.config = {"seed": seed_value, "autoplay": true, "diff": diff, "save_path": "user://acready_save.json"}
	get_tree().change_scene_to_file("res://scenes/autochess.tscn")
	var t := 0.0
	while not (get_tree().current_scene is AutochessScreen and (get_tree().current_scene as AutochessScreen).game != null) and t < 60.0:
		await _wait_s(0.1)
		t += 0.1
	var sc: AutochessScreen = get_tree().current_scene
	var done := 0
	var guard := 0.0
	while done < rounds and guard < 900.0:
		if sc.phase == "over" or not is_instance_valid(sc):
			break
		if sc.phase != "prep" or sc.game.phase != "prep":
			await _wait_s(0.05)
			guard += 0.05
			continue
		# le joueur réfléchit : le minuteur de la préparation est tenu
		var t0 := 0.0
		while t0 < wait and sc.phase == "prep":
			sc.timer = 999.0
			await _wait_s(0.05)
			t0 += 0.05
		if sc.phase != "prep":
			continue
		var round_key: String = sc.game.round_key()
		var kind: String = sc.game.round_kind()
		var units := 0
		for p in sc.game.players:
			units += (p.board as Array).size()
		var n0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		_frames = []
		_track = true
		var tc := Time.get_ticks_usec()
		sc._ready_pressed()
		var call_ms := float(Time.get_ticks_usec() - tc) / 1000.0
		await _wait_s(2.0)
		_track = false
		var mx := 0.0
		var n100 := 0
		var first := 0.0
		var ms_list: Array = []
		for i in _frames.size():
			var ms: float = _frames[i][0]
			ms_list.append(snappedf(ms, 1.0))
			if i == 0:
				first = ms
			mx = maxf(mx, ms)
			if ms > 100.0:
				n100 += 1
		ms_list.sort()
		var med: float = ms_list[ms_list.size() / 2] if not ms_list.is_empty() else 0.0
		var row := {"round": round_key, "kind": kind, "units": units, "call_ms": snappedf(call_ms, 0.1), "first_frame": snappedf(first, 0.1),
			"max": snappedf(mx, 0.1), "n100": n100, "median": med, "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - n0,
			"real": sc.real, "top": ms_list.slice(maxi(ms_list.size() - 5, 0))}
		rows.append(row)
		print("[acready] ", JSON.stringify(row))
		done += 1
	var calls: Array = rows.map(func(r): return r.call_ms)
	var maxes: Array = rows.map(func(r): return r.max)
	calls.sort()
	maxes.sort()
	print("[acready] résumé : %d manches ; appel Prêt médiane %.0f ms (pire %.0f) ; image max médiane %.0f ms (pire %.0f) ; images > 100 ms : %d" % [
		rows.size(), calls[calls.size() / 2] if not calls.is_empty() else 0.0, calls[-1] if not calls.is_empty() else 0.0,
		maxes[maxes.size() / 2] if not maxes.is_empty() else 0.0, maxes[-1] if not maxes.is_empty() else 0.0,
		rows.reduce(func(a, r): return a + int(r.n100), 0)])
	get_tree().quit()
