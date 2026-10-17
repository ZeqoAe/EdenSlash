extends Node
## Captures du lot SVX-3 (Survivant : évolutions, records, coffres, Codex, élites et événements), user://shots/svx3/<quoi>_<rés>.png,
## à REGARDER : bilan (records, défis, coffres fermés puis ouverts, Codex), page du mode (records et Codex), Codex (6 onglets),
## choix de carte (évolutions d'arme et de sort, indices), HUD (frise avec Nuée et Chasseur, élite à modificateur).
## godot --path game res://tests/shot_svx3.tscn -- [bilan|codex|lobby|cartes|hud|tout]   (SVX3_RES=1280x720 : petite fenêtre)
## APPDATA détourné conseillé : le profil est remis à zéro.

var res := "1600x900"


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots/svx3")
	get_viewport().get_texture().get_image().save_png("user://shots/svx3/%s_%s.png" % [name, res])
	print("[shot] svx3/%s_%s.png" % [name, res])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var what := "tout"
	for a in OS.get_cmdline_user_args():
		if a in ["bilan", "codex", "lobby", "cartes", "hud", "tout"]:
			what = a
	Settings.reset_all()
	if OS.get_environment("SVX3_RES") != "":
		res = OS.get_environment("SVX3_RES")
	Settings.set_v("display", "resolution", res)
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
	if what in ["bilan", "tout"]:
		await _bilan()
	if what in ["codex", "tout"]:
		await _codex()
	if what in ["lobby", "tout"]:
		await _lobby()
	if what in ["cartes", "hud", "tout"]:
		await _world(what)
	get_tree().quit()


## Un compte qui a déjà joué : codex à moitié rempli, records, défis.
static func fill_codex() -> void:
	var st: Dictionary = Profile.records.get(SurvivorRewards.KEY, {})
	var evo: Array = SurvivorEvo.all().map(func(d): return String(d.id))
	var weapons: Array = SurvivorCodex.weapon_entries().map(func(e): return String(e.key))
	var mons := SurvivorCodex.roster()
	st["codex"] = {"evo": evo.slice(0, 7), "evo_seen": evo.slice(7, 12), "weapons": weapons.slice(0, 14), "sets": SurvivorPool.sets().slice(0, 3),
		"sets_seen": SurvivorPool.sets().slice(0, 7), "monsters": mons.slice(0, 70), "bosses": mons.slice(0, 2)}
	st["stats"] = {"games": 23, "wins": 9, "time": 23.0 * 1150.0, "kills": 51230, "weapons": {"katana": 9, "bow": 5}, "evos": {String(evo[0]): 4},
		"classes": {"warrior": 14, "hunter": 9}}
	st["best"] = {"warrior:1": {"win": 1342.0, "level": 41.0, "dmg": 2.1e6, "kills": 3120.0}, "warrior:2": {"time": 940.0, "level": 30.0, "dmg": 8.0e5, "kills": 1900.0},
		"hunter:1": {"win": 1401.0, "level": 39.0, "dmg": 1.8e6, "kills": 2900.0}}
	st["defis"] = ["first_win", "ten_min", "guardians", "evo_1", "set_5", "level_50"]
	st["wins"] = {"1": 3}
	Profile.records[SurvivorRewards.KEY] = st


func _bilan() -> void:
	for res_kind in ["victoire", "defaite"]:
		Profile.reset_all()
		fill_codex()
		Survivor.start("warrior", "beluga", 2 if res_kind == "victoire" else 1)
		SurvivorCards.seed_with(3)
		preload("res://tests/shot_sv5.gd").rich_state()
		Run.max_level = 43
		Run.kills = 3212
		Run.elites = 14
		SurvivorLog.begin()
		for k in [["weapon", 41000.0], ["skill:%d" % int(Run.all_skills()[0].id), 27000.0], [SurvivorLog.proc_tag("sve_quake_0"), 26000.0],
				[SurvivorLog.proc_tag("ember_0"), 16000.0], ["dot", 5000.0]]:
			SurvivorLog.tag = String(k[0])
			SurvivorLog.note(float(k[1]) * 30.0)
		SurvivorLog.tag = ""
		SurvivorLog.moment(337.0, "Gardien 1 vaincu en 0:37", "guardian")
		SurvivorLog.moment(452.0, "Nuée repoussée", "event")
		SurvivorLog.moment(611.0, "Évolution : Séisme", "evolution")
		SurvivorLog.moment(642.0, "Gardien 2 vaincu en 0:42", "guardian")
		SurvivorLog.moment(1200.0, "Arène du boss", "boss")
		SurvivorCodex.note_evolution("sve_quake")
		SurvivorCodex.note_evolution("sve_hawk")
		SurvivorRewards.stats = {"time": 1301.0 if res_kind == "victoire" else 880.0, "guardians": 3 if res_kind == "victoire" else 2,
			"arena": res_kind == "victoire", "early": 0.0, "arena_at": 1150.0 if res_kind == "victoire" else -1.0, "ttk": [37.0, 42.0, 55.0]}
		if res_kind == "defaite":
			Profile.records[SurvivorRewards.KEY]["best"]["warrior:1"]["time"] = 700.0
		RunJournal._time = 30.0
		Run.finish(res_kind)
		var bg := ColorRect.new()
		bg.color = Color(0.67, 0.71, 0.5)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		var rs := ResultsScreen.new()
		add_child(rs)
		rs.show_results()
		for k in 120:  # la montée des chiffres et les fondus du bilan (la toute première image est longue)
			await get_tree().create_timer(0.25, true, false, true).timeout
			if k > 8 and not rs._tweens.any(func(t): return t.is_valid() and t.is_running()):
				break
		await _shot("bilan_" + res_kind, 1.0)
		print("[svx3] bilan %s : cadre %s" % [res_kind, str(rs._panel.get_global_rect())])
		var btn: Node = rs.find_child("OpenChests", true, false)
		if btn != null:
			(btn as Button).pressed.emit()
			await _shot("bilan_%s_ouverts" % res_kind, 3.5)
		rs.queue_free()
		bg.queue_free()
		get_tree().paused = false
		Profile.end_run_survival()


func _codex() -> void:
	Profile.reset_all()
	fill_codex()
	var host := Node.new()
	add_child(host)
	var c := SurvivorCodexPage.open_on(host)
	for i in SurvivorCodexPage.TABS.size():
		c.show_page(i)
		await _shot("codex_%s" % String(SurvivorCodexPage.TABS[i][0]), 1.2)
	host.queue_free()


func _lobby() -> void:
	Profile.reset_all()
	fill_codex()
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(3.0, true, false, true).timeout
	lobby.call("_show_menu", "survivor")
	await _shot("lobby_page", 1.5)
	var scroll: ScrollContainer = lobby.get("_scroll")
	var btn: Control = null
	for b in lobby.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Codex du Survivant"):
			btn = b
	if scroll != null and btn != null:
		scroll.ensure_control_visible(btn)
	await _shot("lobby_page_codex", 1.0)
	if btn != null:
		(btn as Button).pressed.emit()
		await _shot("lobby_codex_ouvert", 1.5)
	lobby.queue_free()
	await get_tree().process_frame


func _world(what: String) -> void:
	await get_tree().process_frame
	Profile.reset_all()
	Survivor.start("warrior", "limestone")
	SurvivorCards.seed_with(11)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(0.6, true, false, true).timeout
	await _shot("premier_choix", 0.1)  # fondu d'arrivée : le choix est déjà lisible
	while world.get("cards") == null:
		await get_tree().process_frame
	var picker: SurvivorPicker = world.cards
	world.player.dev_invincible = true
	for k in 150:
		if not get_tree().root.get_children().any(func(n): return n is ScreenFade):
			break
		await get_tree().create_timer(0.1, true, false, true).timeout
	picker._queue.clear()
	picker._show_next()
	# hache +4, Onde de choc portée par une pièce : la carte d'arme +6 annonce « Évolution prête : Séisme »
	var w := SurvivorGear.make_weapon("axe")
	SurvivorGear.equip(w)
	Profile.equipped.weapon["upgrade"] = 4
	Run.apply_card(SurvivorCards.spell_card(int(Run.class_data().skills[0].id)))
	SurvivorGear._grant("shockwave", 1.0)
	SurvivorGear._grant("echo", 1.0)
	SurvivorGear._grant("giant_slayer", 1.0)
	Run.skills[0]["rank"] = 9
	world.player.skills_changed.emit()
	if what in ["cartes", "tout"]:
		var cards := [SurvivorCards.up_card("weapon", "rare"), SurvivorCards.spell_up_card(int(Run.skills[0].id), "legendary")]
		var piece := SurvivorCards.new_piece_card("ring")
		if not piece.is_empty():
			cards.append(piece)
		world._offer("Niveau 18 !", cards)
		await _shot("choix_indices", 1.5)
		picker._queue.clear()
		picker._show_next()
		Profile.equipped.weapon["upgrade"] = 6
		Run.skills[0]["rank"] = 10
		world._offer("Coffre du gardien", SurvivorCards.chest_cards("sv_guardian"))
		await _shot("choix_evolution", 1.5)
		picker._queue.clear()
		picker._show_next()
	if what in ["hud", "tout"]:
		world.director.time = 452.0
		var ev: SurvivorEvents = world.director.sv.events
		await get_tree().create_timer(1.0, true, false, true).timeout
		ev = world.director.sv.events
		if ev != null:
			var e: Monster = world.director._spawn_monster(world.director._elites.pick_random(), world.player.global_position + Vector3(4, 0, 2), 12)
			ev.apply_affix(e, "explosif")
		await _shot("hud_nuee", 2.5)
	world.queue_free()
	await get_tree().process_frame
