extends Node
## Intégration (passe P4) : chaque activité est lancée depuis le lobby (vraies fonctions de lancement, vraie scène du jeu),
## jouée quelques secondes en pilote automatique, terminée, son bilan est lu et « Retour au lobby » est pressé.
## Le pilote vit dans la racine (il survit aux changements de scène). Console : chercher ensuite ERROR / SCRIPT ERROR.
## godot --headless --path game res://tests/test_p4_activities.tscn [-- survival,training,tower,dungeon0,dungeon1,dungeon2,rush,siege,
##   duel,league,pantheon,gauntlet,arena2,arena3,royale,challenge]

const LOBBY := "res://scenes/lobby.tscn"
const ALL := ["survival+r", "survival_win", "training", "tower+r", "dungeon0+r", "dungeon1", "dungeon2", "rush+r", "siege+r", "duel+r", "league", "pantheon",
	"gauntlet", "arena2+r", "arena3", "royale+r", "challenge"]
const HARD_LIMIT := 1500.0  # secondes : au-delà, le pilote s'arrête en échec

var fails := 0
var rows: Array = []
var _t0 := 0.0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	if name == "P4Driver":
		_t0 = Time.get_ticks_msec() / 1000.0
		_run.call_deferred()
		return
	var d: Node = (load("res://tests/test_p4_activities.gd") as GDScript).new()
	d.name = "P4Driver"
	get_tree().root.add_child.call_deferred(d)


func _elapsed() -> float:
	return Time.get_ticks_msec() / 1000.0 - _t0


## Attend [param secs] secondes de jeu (le temps continue même si le jeu est en pause).
func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


## Attend qu'une condition soit vraie (au plus [param limit] secondes) ; renvoie vrai si elle l'est.
func _until(cond: Callable, limit: float, label := "") -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		await _wait(0.1)
		t += 0.1
		if _elapsed() > HARD_LIMIT:
			return false
	if label != "":
		print("   (délai dépassé : %s)" % label)
	return cond.call()


func _scene() -> Node:
	return get_tree().current_scene


func _is_lobby() -> bool:
	var s := _scene()
	return s != null and s.get_script() != null and s.has_method("_start_run") and s.has_method("_start_tower")


func _is_world() -> bool:
	var s := _scene()
	return s != null and s.has_method("end_run") and "director" in s and s.director != null and "player" in s and is_instance_valid(s.player) and s.get("hud") != null


func _to_lobby() -> bool:
	if _is_lobby():
		await _wait(0.5)
		return true
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(LOBBY)
	var ok: bool = await _until(_is_lobby, 40.0, "lobby")
	await _wait(0.8)
	return ok


func _results() -> ResultsPanel:
	var s := _scene()
	if s == null:
		return null
	for c in s.get_children():
		if c is ResultsPanel:
			return c
	return null


func _clean_state() -> bool:
	return not Run.active and not Duel.active and not Tower.active and not Training.active and not Royale.active and not get_tree().paused


func _reset_modes() -> void:
	Run.active = false
	Run.survival = false
	Duel.active = false
	Tower.active = false
	Training.active = false
	Royale.active = false
	Duel.mode = "free"


func _veteran_profile() -> void:
	# un compte avancé : toutes les époques gagnées, les 8 boss battus, tout ouvert, un préréglage de sorts pour chaque classe jouée
	Profile.records["epochs_cleared"] = Epochs.count()
	for zid in Dungeons.zone_ids():
		Profile.records["boss_" + String(zid)] = 1
	Profile.unlocked_features = Unlocks.LIST.keys()
	Profile.runs_done = maxi(Profile.runs_done, 10)
	Profile.records["duel_wins"] = 10
	for cid in GameData.classes.keys().slice(0, 12):
		_make_preset(String(cid))
	Profile.save_profile()


func _make_preset(cid: String) -> void:
	var skills: Array = GameData.class_data(cid).get("skills", []).filter(func(s): return String(s.kind) != "buff" and String(s.kind) != "heal")
	if skills.size() < 4:
		skills = GameData.class_data(cid).get("skills", [])
	var cols := SpellPresets.empty_cols()
	for i in mini(4, skills.size()):
		cols[i][0] = int(skills[i].id)
	SpellPresets.set_active(cid, SpellPresets.store(cid, "P4", cols))


# --- le déroulé ---------------------------------------------------------------------------------------------------
func _run() -> void:
	var wanted: Array = ALL
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and args[0] != "":
		wanted = Array(args[0].split(","))
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	_make_preset("warrior")
	check("départ : compte neuf, tout est propre", _clean_state())
	var ok := await _to_lobby()
	check("lobby : la scène du lobby se charge (compte neuf)", ok)
	for act in wanted:
		if _elapsed() > HARD_LIMIT:
			check("durée totale respectée avant « %s »" % act, false)
			break
		if not _is_lobby():
			await _to_lobby()
		if not String(act).begins_with("survival") and act != "training":
			_veteran_profile()
		var t := _elapsed()
		var res: Dictionary = await _activity(String(act))
		res["act"] = act
		res["secs"] = snappedf(_elapsed() - t, 0.1)
		rows.append(res)
		check("%s : lancée, jouée, terminée, bilan lu et retour au lobby (%s)" % [act, str(res)], bool(res.get("ok", false)))
	print("\n--- récapitulatif ---")
	for r in rows:
		print("%-10s %s  %5.1f s  %s" % [r.act, "OK   " if r.ok else "ÉCHEC", r.secs, r.get("note", "")])
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


## Lance une activité depuis le lobby, la joue, la termine et revient au lobby. Renvoie {ok, note, ...}.
func _activity(act_in: String) -> Dictionary:
	var replay := act_in.ends_with("+r")
	var act := act_in.trim_suffix("+r")
	var out := {"ok": false, "note": ""}
	var lobby := _scene()
	_reset_modes()
	var dev: bool = act in ["dungeon1", "dungeon2", "rush", "siege", "royale", "arena2", "arena3", "gauntlet"]
	if dev:
		Settings.set_v("interface", "dev_mode", true)  # (puissance d'équipement exigée par ces activités)
	var zid := String(Dungeons.zone_ids()[0])
	match act:
		"survival", "survival_win":
			lobby._start_run()
		"training":
			lobby._start_training()
		"tower":
			lobby._start_tower(1, 1)
		"dungeon0", "dungeon1", "dungeon2":
			lobby._dg_zone = zid
			lobby._dg_diff = int(act.trim_prefix("dungeon"))
			lobby._dg_allies = ["", ""]
			lobby._start_dungeon()
		"rush":
			lobby._dg_diff = 0
			lobby._dg_allies = ["", ""]
			lobby._start_rush()
		"siege":
			lobby._dg_zone = zid
			lobby._dg_diff = 0
			lobby._dg_allies = ["", ""]
			lobby._start_siege()
		"duel":
			Duel.bare = true
			Duel.mode = "free"
			lobby._start_duel()
		"league":
			lobby._start_ranked("league", "")
		"pantheon":
			lobby._start_ranked("pantheon", "")
		"gauntlet":
			lobby._start_team("gauntlet", [], ["warrior", "hunter"])
		"arena2":
			lobby._team_brain = ""
			lobby._start_team("arena2", ["cleric"], ["hunter", "magician"])
		"arena3":
			lobby._team_brain = ""
			lobby._start_team("arena3", ["cleric", "hunter"], ["magician", "thief", "warrior"])
		"royale":
			lobby._start_royale()
		"challenge":
			lobby._start_challenge("warrior")
	if act in ["duel", "league", "pantheon"]:
		var q = await _drive_queue(lobby)
		out["queue"] = q
		if q != "ok":
			out.note = "file d'attente : " + String(q)
			Settings.set_v("interface", "dev_mode", false)
			return out
	if not await _until(_is_world, 90.0, "monde chargé"):
		out.note = "le monde ne se charge pas"
		Settings.set_v("interface", "dev_mode", false)
		return out
	Settings.set_v("interface", "dev_mode", false)
	var world := _scene()
	var player: Player = world.player
	check("%s : modes exacts (Modes.current = %s)" % [act, Modes.current()], Modes.current() != "")
	player.autoplay = true
	await _wait(1.0)
	check("%s : le HUD est là et le héros vit" % act, world.hud != null and is_instance_valid(player) and not player.is_dead)
	await _wait(6.0)
	if act == "survival_win":
		# trois cartes par le portail, le boss de la dernière tombe : victoire d'époque, ce qu'elle ouvre au hub
		var d: RunDirector = world.director
		for i in 2:
			await ScreenFade.run(get_tree(), d._next_stage.bind(d.next_zone_id()))
		check("survival_win : étape %d / 3 atteinte par le portail" % Run.stage, Run.stage == 3)
		d._on_boss_killed()
		check("survival_win : carte finale vaincue, époque I gagnée, tour et forge ouvertes", await _until(func(): return Epochs.unlocked() >= 2, 5.0) and Unlocks.is_open("tower") and Unlocks.is_open("forge"))
	if act == "training":
		world.pause_menu.abandon_requested.emit()
		var back: bool = await _until(_is_lobby, 40.0, "retour de l'entraînement")
		out.ok = back and _clean_state()
		out.note = "retour direct au lobby"
		return out
	var panel: ResultsPanel = await _end_game(act, world, player)
	out["bilan"] = panel != null
	if panel == null:
		out.note = "aucun bilan"
		return out
	if replay:
		# « Rejouer » : le bouton principal relance la même partie, qui se termine de la même façon
		var again: Button = panel.buttons[0]
		out["rejouer"] = again.text
		if again.disabled:
			out.note = "« Rejouer » toujours gelé"
			return out
		again.pressed.emit()
		var gone: bool = await _until(func(): return not is_instance_valid(world) or _scene() != world, 30.0, "ancienne scène")
		var ok2: bool = gone and await _until(_is_world, 90.0, "monde relancé")
		if not ok2:
			out.note = "« Rejouer » ne relance pas la partie"
			return out
		world = _scene()
		player = world.player
		player.autoplay = true
		await _wait(5.0)
		check("%s : la partie relancée est propre (mode %s)" % [act, Modes.current()], Modes.current() != "" and world.hud != null)
		panel = await _end_game(act, world, player)
		if panel == null:
			out.note = "aucun bilan après « Rejouer »"
			return out
	var n_buttons := panel.buttons.size()
	var texts: Array = panel.buttons.map(func(b): return b.text)
	out["boutons"] = texts
	if n_buttons == 0:
		out.note = "pas de bouton"
		return out
	var ret: Button = panel.buttons[n_buttons - 1]
	if ret.disabled:
		out.note = "bouton de retour toujours gelé"
		return out
	ret.pressed.emit()
	var home: bool = await _until(_is_lobby, 40.0, "retour au lobby")
	await _wait(0.6)
	out.ok = home and _clean_state()
	if not home:
		out.note = "pas de retour au lobby"
	elif not _clean_state():
		out.note = "état non remis à zéro (Run %s Duel %s Tour %s Royale %s pause %s)" % [Run.active, Duel.active, Tower.active, Royale.active, get_tree().paused]
	return out


## Termine la partie en cours comme un joueur le ferait (mort, victoire de duel, abandon) et attend son bilan, boutons dégelés.
func _end_game(act: String, world: Node, player: Player) -> ResultsPanel:
	var duelish: bool = act in ["duel", "league", "pantheon", "gauntlet", "arena2", "arena3"]
	if act == "survival_win":
		# la victoire arrive d'elle-même 6 s après le boss, une fois choisie l'amélioration d'arme (le choix tient la pause, P13)
		for i in 8:
			await _wait(0.5)
			if world.cards.is_open():
				world.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
				world.cards._choose(0)
	elif act in ["survival", "challenge"]:
		world.revives_left = 0
		player.dev_invincible = false
		for i in 6:
			if _results() != null:
				break
			if is_instance_valid(player) and not player.is_dead:
				player.hp = 1.0
				player.take_damage(1e9, null, false)
			await _wait(1.0)
	elif duelish:
		var t := 0.0
		while _results() == null and t < 90.0:
			var dd: DuelDirector = world.director.duel
			if dd != null and dd.phase == "fight":
				for f in dd._foes + [dd._foe]:
					if is_instance_valid(f) and not f.is_dead:
						f.hp = 1.0
						f.take_damage(1e12, player, false)
			await _wait(0.5)
			t += 0.5
	else:
		world.pause_menu.abandon_requested.emit()
	var shown: bool = await _until(func(): return _results() != null, 20.0, "bilan")
	if not shown:
		return null
	var panel := _results()
	await _wait(ResultsPanel.LOCK_SECS + 1.8)
	return panel if panel.buttons.size() > 0 else null


var _q: DuelQueue = null


func _find_queue(lobby: Node) -> bool:
	for c in get_tree().root.get_children():
		if c is DuelQueue:
			_q = c
			return true
	return false


func _queue_step() -> bool:
	if not is_instance_valid(_q):
		return true
	if _q.phase == DuelQueue.Phase.FOUND:
		_q.accept()
	elif _q.phase == DuelQueue.Phase.DRAFT:
		_q.lock_in()
	return not _is_lobby()


## File d'attente du Duel (recherche, match trouvé, draft, récapitulatif) menée jusqu'au lancement. Renvoie "ok" ou la raison.
func _drive_queue(lobby: Node) -> String:
	_q = null
	var found: bool = await _until(_find_queue.bind(lobby), 10.0, "file d'attente")
	if not found:
		return "file absente"
	Engine.time_scale = 4.0
	var done: bool = await _until(_queue_step, 80.0, "file d'attente jusqu'au lancement")
	Engine.time_scale = 1.0
	return "ok" if done else "file bloquée en phase %s" % [_q.phase if is_instance_valid(_q) else "?"]
