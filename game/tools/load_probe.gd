extends "res://tests/test_p4_activities.gd"
## PERF-1 : sonde des chargements et des à-coups, EN FENÊTRE (rendu, compilation des shaders et cartes graphiques compris).
## Reprend le pilote de test_p4_activities (vraies fonctions de lancement du lobby, vraie scène, pilote automatique, bilan, retour)
## et y ajoute un moniteur d'images (FrameMon) : durée de chaque image, images figées (> 50 / 100 / 300 ms), compilations de
## pipelines (shaders) par image, nœuds / ressources créés dans l'image (chargement, instanciation), changement de scène.
## Lancé par `python tools/perf_loads.py` (copie propre, 3 passages, temps CPU du processus, charge de la machine) ; à la main :
##   LOAD_PROBE="--acts=survival,tower --out=C:/x.json" godot --path game res://tools/load_probe.tscn
## Options (variable LOAD_PROBE, jamais d'arguments « -- » : le lobby lancerait une run) : --acts=liste (ALL_ACTS par défaut),
## --no-pages, --play=secondes de jeu par activité (7), --out=fichier JSON, --vsync (laisse la synchronisation verticale).
## Chaque marque s'imprime « [perf1] mark <nom> <µs> » : perf_loads.py y relève le temps CPU du processus.

const ALL_ACTS := ["survival", "survivor", "dungeon0", "tower", "rush", "siege", "duel", "arena3", "royale", "autochess"]
const HITCH_MS := 50.0  # une image plus longue est un à-coup (relevée en détail)

var opts := {"acts": ALL_ACTS, "pages": true, "play": 7.0, "out": "user://load_probe.json", "vsync": false, "shots": ""}
var mon: FrameMon


## Moniteur d'images : premier nœud traité à chaque image (priorité -1000), même en pause.
class FrameMon extends Node:
	var phase := "boot"
	var phases: Array = []  # {name, t0, t1, frames, max, n50, n100, n300, frozen, pipes, draw_pipes, ready_ms}
	var hitches: Array = []  # {phase, ms, process, physics, pipes{}, nodes, res, scene}
	var cur: Dictionary = {}
	var _last := 0
	var _scene: Node = null
	var _settle := -1  # images courtes d'affilée depuis le dernier changement de scène (-1 : aucun en cours)
	var _pipes0 := {}
	var _nodes0 := 0
	var _res0 := 0
	var shots := ""
	var _ls: GDScript = load("res://scripts/ui/load_screen.gd") if ResourceLoader.exists("res://scripts/ui/load_screen.gd") else null  # (absent avant PERF-1)
	var _load_frames := 0
	var _shot_n := 0
	const PIPES := {"canvas": Performance.PIPELINE_COMPILATIONS_CANVAS, "mesh": Performance.PIPELINE_COMPILATIONS_MESH,
		"surface": Performance.PIPELINE_COMPILATIONS_SURFACE, "draw": Performance.PIPELINE_COMPILATIONS_DRAW,
		"spec": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		process_priority = -1000
		_last = Time.get_ticks_usec()
		_snap()
		begin("boot")

	func _snap() -> void:
		for k in PIPES:
			_pipes0[k] = int(Performance.get_monitor(PIPES[k]))
		_nodes0 = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		_res0 = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))

	## Nouvelle phase (la précédente se ferme) ; imprimée pour le relevé du temps CPU.
	func begin(name: String) -> void:
		var now := Time.get_ticks_usec()
		if not cur.is_empty():
			cur.t1 = now
			phases.append(cur)
		cur = {"name": name, "t0": now, "t1": now, "frames": 0, "max": 0.0, "n50": 0, "n100": 0, "n300": 0, "frozen": 0.0,
			"pipes": 0, "draw_pipes": 0, "ready_ms": -1.0, "scene_at": -1.0}
		phase = name
		print("[perf1] mark %s %d" % [name, now])

	func finish() -> void:
		begin("fin")
		cur.t1 = cur.t0
		phases.append(cur)
		cur = {}

	func _process(_d: float) -> void:
		var now := Time.get_ticks_usec()
		var ms := float(now - _last) / 1000.0
		_last = now
		var dp := {}
		var total := 0
		for k in PIPES:
			var v := int(Performance.get_monitor(PIPES[k]))
			dp[k] = v - int(_pipes0.get(k, v))
			total += int(dp[k])
		var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
		var res := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
		var dn := nodes - _nodes0
		var dr := res - _res0
		_snap()
		if cur.is_empty():
			return
		cur.frames += 1
		cur.max = maxf(cur.max, ms)
		cur.pipes += total
		cur.draw_pipes += int(dp.draw)
		if ms > 50.0:
			cur.n50 += 1
			cur.frozen += ms
		if ms > 100.0:
			cur.n100 += 1
		if ms > 300.0:
			cur.n300 += 1
		var sc := get_tree().current_scene
		if shots != "":
			_load_frames = _load_frames + 1 if _ls != null and _ls.busy() else 0
			if _load_frames == 4:
				_shot_n += 1
				get_viewport().get_texture().get_image().save_png("%s/chargement_%02d.png" % [shots, _shot_n])
		if ms > HITCH_MS:
			var compact := {}
			for k in dp:
				if int(dp[k]) != 0:
					compact[k] = dp[k]
			hitches.append({"phase": phase, "ms": snappedf(ms, 0.1), "process": snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.1),
				"physics": snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1), "pipes": compact, "nodes": dn, "res": dr,
				"scene": (sc.scene_file_path.get_file() if sc else "-"), "at": snappedf(float(now - int(cur.t0)) / 1000.0, 1.0)})
		if sc != _scene:
			_scene = sc
			if sc != null:
				cur.scene_at = float(now - int(cur.t0)) / 1000.0
				_settle = 0
		elif _settle >= 0:
			_settle = _settle + 1 if ms < 50.0 else 0
			if _settle >= 5 and float(cur.ready_ms) < 0.0:
				# nouvelle scène affichée et 5 images courtes d'affilée : l'écran est prêt
				cur.ready_ms = float(now - int(cur.t0)) / 1000.0 - 5.0 * 16.7
				print("[perf1] mark %s:pret %d" % [phase, now])
				_settle = -1
				if phase.begins_with("lancer:"):
					begin("jeu:" + phase.trim_prefix("lancer:"))  # la partie commence : ses à-coups sont comptés à part


func _ready() -> void:
	if name == "P4Driver":
		_parse_opts()
		mon = FrameMon.new()
		mon.name = "FrameMon"
		mon.shots = String(opts.shots)
		get_tree().root.add_child.call_deferred(mon)
	super()


func _parse_opts() -> void:
	for a in OS.get_environment("LOAD_PROBE").split(" ", false):
		if a.begins_with("--acts="):
			opts.acts = Array(a.trim_prefix("--acts=").split(","))
		elif a == "--no-pages":
			opts.pages = false
		elif a.begins_with("--play="):
			opts.play = float(a.trim_prefix("--play="))
		elif a.begins_with("--out="):
			opts.out = a.trim_prefix("--out=")
		elif a == "--vsync":
			opts.vsync = true
		elif a.begins_with("--shots="):
			opts.shots = a.trim_prefix("--shots=")  # dossier : une capture de chaque écran de chargement


func _run() -> void:
	await get_tree().process_frame
	if not opts.vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 240  # (sans synchronisation : la durée d'une image = son coût ; plafond poli pour les autres processus)
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	Profile.hero_made = true  # (le créateur de personnage du premier lancement ne se met pas en travers des pages)
	_make_preset("warrior")
	# titre (sans argument : l'écran titre se construit), puis Jouer -> lobby
	mon.begin("titre")
	get_tree().change_scene_to_file.call_deferred("res://scenes/title.tscn")
	await _until(func(): return _scene() != null and _scene().has_method("_go"), 30.0, "titre")
	await _wait(2.5)
	mon.begin("titre->lobby")
	_scene()._go()
	await _until(_is_lobby, 40.0, "lobby")
	await _wait(3.0)
	mon.begin("lobby:repos")
	await _wait(2.0)
	if opts.pages:
		_veteran_profile()
		await _pages(_scene())
	for act in opts.acts:
		if not _is_lobby():
			await _to_lobby()
		if not String(act).begins_with("survival") and act != "training":
			_veteran_profile()
		var res: Dictionary = await _activity(String(act))
		print("[perf1] activité %s : %s" % [act, str(res)])
	mon.finish()
	_write()
	get_tree().quit(0)


## Pages du lobby : chaque ouverture est une phase (l'image la plus longue = le coût vu par le joueur).
func _pages(lobby: Node) -> void:
	var steps: Array = []
	for id in ["play", "survival", "survivor", "dungeon", "tower", "rush", "siege", "duel", "arenas", "royale", "autochess", "quests"]:
		steps.append(["menu " + id, func(): lobby._show_menu(id), func(): lobby._show_menu("")])
	for s in ["equipment", "class", "appearance", "cards"]:
		steps.append(["Héros > " + s, func(): lobby._hero.open(s), func(): lobby._hero.close_ui()])
	for sc in [["Carnet", lobby._archive], ["Atelier", lobby._workshop], ["Coffres", lobby._chests]]:
		var s: PageScreen = sc[1]
		for i in s.page_count():
			steps.append(["%s > %s" % [sc[0], s._tab_buttons[i].text], func(): s.open(i), func(): s.close_ui()])
	steps.append(["Paramètres", func(): lobby._settings.open(), func(): lobby._settings.close()])
	steps.append(["Guide (F1)", func(): Guide.open_on(lobby), func(): Guide.close_in(lobby)])
	steps.append(["Journal (L)", func(): lobby._open_journal(0), _close_journal.bind(lobby)])
	for rep in 2:  # 1re ouverture (construction), 2e (déjà bâtie)
		for st in steps:
			mon.begin("page:%s (%s)" % [st[0], "1re" if rep == 0 else "2e"])
			st[1].call()
			await _wait(0.6)
			st[2].call()
			await _wait(0.3)
	mon.begin("lobby:repos2")
	await _wait(1.0)


## Modes en cours d'écriture par d'autres équipes (pas encore dans le menu Jouer) : lancés comme leur ligne de commande.
func _launch_extra(act: String, _lobby: Node) -> void:
	match act:
		"colisee":
			Colisee.begin(Profile.selected_class, "classique", 2, 1)
		"assault":
			Assault.launch(Profile.selected_class, Assault.args_options(PackedStringArray()))
		_:
			return
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")


func _close_journal(lobby: Node) -> void:
	var j := QuestJournal.find_open(lobby)
	if j:
		j.close_ui()


func _activity(act_in: String) -> Dictionary:
	mon.begin("lancer:" + act_in)
	var r: Dictionary = await super(act_in)
	mon.begin("lobby:après " + act_in)
	return r


func _check_world(_act: String, _world: Node, _player: Player) -> void:
	await _wait(maxf(opts.play - 7.0, 0.0))  # (7 s déjà joués par le pilote ; la phase « jeu » commence à l'écran prêt)


func _end_game(act: String, world: Node, player: Player) -> ResultsPanel:
	mon.begin("fin->bilan:" + act)
	var p: ResultsPanel = await super(act, world, player)
	mon.begin("bilan->lobby:" + act)
	return p


func _write() -> void:
	var out := {"version": Version.NUMBER, "phases": [], "hitches": mon.hitches, "acts": opts.acts,
		"window": [get_tree().root.size.x, get_tree().root.size.y], "renderer": RenderingServer.get_video_adapter_name()}
	for p in mon.phases:
		var q: Dictionary = p.duplicate()
		q["ms"] = snappedf(float(int(p.t1) - int(p.t0)) / 1000.0, 0.1)
		q["max"] = snappedf(float(p.max), 0.1)
		q["frozen"] = snappedf(float(p.frozen), 0.1)
		q["ready_ms"] = snappedf(float(p.ready_ms), 0.1)
		q["scene_at"] = snappedf(float(p.scene_at), 0.1)
		out.phases.append(q)
	var f := FileAccess.open(String(opts.out), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "\t"))
		f.close()
	print("[perf1] écrit %s (%d phases, %d à-coups)" % [opts.out, out.phases.size(), mon.hitches.size()])
