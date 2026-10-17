extends Node
## Lot PERF-1 : aucun chargement long sans indicateur.
## 1. Structure : aucun script du jeu ne change de scène sans LoadScreen (change_scene_to_file / _packed interdits ailleurs ;
##    exceptions : load_screen.gd, le titre lancé avec des arguments (tests, captures) et les modes en cours d'écriture par
##    d'autres équipes, signalés sans échec).
## 2. Parcours réel (vraies scènes) : titre -> lobby, premières ouvertures des pages lourdes, lobby -> Survie, carte suivante
##    (fondu), abandon -> bilan -> lobby. Un chien de garde mesure chaque image : une image de plus de 300 ms pendant une
##    action doit avoir eu un indicateur à l'écran (LoadScreen ouvert au début de l'image, pastille « Chargement… » posée
##    pendant l'image, ou fondu noir de changement de carte avec ses pastilles).
## 3. LoadScreen rend la pause d'avant au moment du changement de scène, et s'affiche en 2 images au plus.
## godot --headless --path game res://tests/test_perf1.tscn

const LIMIT_MS := 300.0
const PENDING_MODES := ["scripts/core/assault_director.gd", "scripts/core/colisee_director.gd", "scripts/core/moba_director.gd",
	"scripts/ui/colisee_page.gd", "scripts/world/net_arena.gd", "scripts/ui/assault_page.gd"]

var fails := 0
var long_frames: Array = []  # [action, ms, annoncée]
var _action := ""
var _last := 0
var _busy_at_start := false
var _hints_at_start := 0
var _fade_at_start := false


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	if name != "Perf1Driver":
		var d: Node = (get_script() as GDScript).new()
		d.name = "Perf1Driver"
		get_tree().root.add_child.call_deferred(d)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000
	_last = Time.get_ticks_usec()
	_run.call_deferred()


## Chien de garde : la durée de l'image qui vient de finir, et ce qui était à l'écran à son début.
func _process(_d: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := float(now - _last) / 1000.0
	_last = now
	if _action != "" and ms > LIMIT_MS:
		var announced := _busy_at_start or LoadScreen.hint_count > _hints_at_start or _fade_at_start or LoadScreen.busy()
		long_frames.append([_action, snappedf(ms, 1.0), announced, "process %d ms, physique %d ms, navigation %d ms" % [
			int(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0), int(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0),
			int(Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0)]])
	_busy_at_start = LoadScreen.busy()
	_hints_at_start = LoadScreen.hint_count
	_fade_at_start = _fade_open()


func _fade_open() -> bool:
	for c in get_tree().root.get_children():
		if c is ScreenFade and (c as ScreenFade).is_open():
			return true
	return false


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func _until(cond: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		await _wait(0.1)
		t += 0.1
	return cond.call()


func _scene() -> Node:
	return get_tree().current_scene


func _is_lobby() -> bool:
	var s := _scene()
	return s != null and s.has_method("_start_run") and s.has_method("_start_tower") and not LoadScreen.busy()


func _is_world() -> bool:
	var s := _scene()
	return s != null and s.has_method("end_run") and "director" in s and s.director != null and s.get("hud") != null and not LoadScreen.busy()


func _results() -> ResultsPanel:
	var s := _scene()
	if s == null:
		return null
	for c in s.get_children():
		if c is ResultsPanel:
			return c
	return null


func _run() -> void:
	_structure()
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	Profile.hero_made = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/title.tscn")
	await _until(func(): return _scene() != null and _scene().has_method("_go"), 30.0)
	await _wait(0.5)
	# titre -> lobby
	_action = "titre -> lobby"
	var n0 := LoadScreen.history.size()
	_scene()._go()
	await get_tree().process_frame
	check("titre -> lobby : l'écran de chargement s'ouvre tout de suite", LoadScreen.busy())
	var ok: bool = await _until(_is_lobby, 60.0)
	check("titre -> lobby : le lobby arrive", ok)
	await _wait(1.0)
	_action = ""
	check("titre -> lobby : chargement noté, voile affiché en moins d'une seconde (%s)" % str(LoadScreen.history.slice(n0)),
		LoadScreen.history.size() > n0 and float(LoadScreen.history[-1].shown_ms) < 1000.0 and String(LoadScreen.history[-1].path).ends_with("lobby.tscn"))
	var lobby := _scene()
	# premières ouvertures des pages lourdes
	Profile.records["epochs_cleared"] = Epochs.count()
	Profile.unlocked_features = Unlocks.LIST.keys()
	for id in ["play", "dungeon", "tower", "survival"]:
		_action = "menu " + id
		lobby._show_menu(id)
		await _wait(0.4)
	lobby._show_menu("")
	for sec in ["equipment", "class", "cards"]:
		_action = "Héros > " + sec
		lobby._hero.open(sec)
		await _wait(0.4)
	lobby._hero.close_ui()
	for sc in [lobby._archive, lobby._chests]:
		for i in (sc as PageScreen).page_count():
			_action = "page %s %d" % [(sc as PageScreen).title, i]
			(sc as PageScreen).open(i)
			await _wait(0.4)
		(sc as PageScreen).close_ui()
	_action = ""
	check("pages : une pastille « Chargement… » à chaque 1re ouverture (%d posées)" % LoadScreen.hint_count, LoadScreen.hint_count >= 5)
	var hc := LoadScreen.hint_count
	lobby._archive.open(0)
	await _wait(0.2)
	lobby._archive.close_ui()
	check("pages : rien de plus à la 2e ouverture", LoadScreen.hint_count == hc)
	# lobby -> Survie : la pause d'avant revient au changement de scène
	await _wait(0.3)
	_action = "lobby -> Survie"
	get_tree().paused = false
	lobby._launch()
	await get_tree().process_frame
	await get_tree().process_frame
	check("lobby -> Survie : le jeu est en pause pendant le chargement (l'ancienne scène ne joue plus)", get_tree().paused and LoadScreen.busy())
	ok = await _until(_is_world, 90.0)
	check("lobby -> Survie : le monde arrive", ok)
	await _wait(2.0)
	_action = ""
	var world := _scene()
	if ok:
		world.player.autoplay = true
		world.player.dev_invincible = true
		for i in 3:  # (choix de la première compétence : il tient la pause)
			if world.cards.is_open():
				world.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
				world.cards._choose(0)
			await _wait(0.3)
		# carte suivante : fondu noir avec ses pastilles
		_action = "carte suivante (fondu)"
		var d: RunDirector = world.director
		await ScreenFade.run(get_tree(), d._next_stage.bind(d.next_zone_id()))
		await _wait(1.0)
		_action = ""
		# abandon -> bilan -> lobby
		world.pause_menu.abandon_requested.emit()
		var shown: bool = await _until(func(): return _results() != null, 30.0)
		check("abandon : le bilan s'affiche", shown)
		if shown:
			var panel := _results()
			await _wait(ResultsPanel.LOCK_SECS + 1.5)
			_action = "bilan -> lobby"
			panel.buttons[panel.buttons.size() - 1].pressed.emit()
			check("bilan -> lobby : retour au lobby", await _until(_is_lobby, 60.0))
			await _wait(1.0)
			_action = ""
	# verdict du chien de garde
	var bad := long_frames.filter(func(f): return not bool(f[2]))
	print("images de plus de %d ms pendant une action : %s" % [int(LIMIT_MS), str(long_frames)])
	check("aucune image de plus de %d ms sans indicateur (%s)" % [int(LIMIT_MS), str(bad)], bad.is_empty())
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


## Aucun changement de scène hors de LoadScreen dans les scripts du jeu.
func _structure() -> void:
	var offenders: Array = []
	var pending: Array = []
	var stack: Array = ["res://scripts"]
	var re := RegEx.create_from_string("change_scene_to_(file|packed|node)\\s*[.(]")
	while not stack.is_empty():
		var dir: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(dir):
			stack.append(dir + "/" + sub)
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var path := dir + "/" + f
			var rel := path.trim_prefix("res://")
			if rel == "scripts/ui/load_screen.gd":
				continue
			var lines := FileAccess.get_file_as_string(path).split("\n")
			for i in lines.size():
				var ln := lines[i].strip_edges()
				if ln.begins_with("#") or ln.begins_with("##") or re.search(ln) == null:
					continue
				var before := lines[maxi(i - 1, 0)] + lines[maxi(i - 2, 0)]
				if rel == "scripts/ui/title_screen.gd" and (before.contains("get_cmdline_user_args") or before.contains("NetLaunch.requested")):
					continue  # (lancement en ligne de commande : tests et captures vont droit au lobby, --host / --join à l'arène)
				if rel in PENDING_MODES:
					pending.append("%s:%d" % [rel, i + 1])
				else:
					offenders.append("%s:%d" % [rel, i + 1])
	if not pending.is_empty():
		print("À BRANCHER (modes en cours, autres équipes) : LoadScreen.go / LoadScreen.to_lobby au lieu de change_scene_to_file : " + ", ".join(pending))
	check("structure : tout changement de scène passe par LoadScreen (%s)" % ", ".join(offenders), offenders.is_empty())
