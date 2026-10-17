extends Node
## Captures de l'interface v2 du Survivant (lot SVX-2, user://shots/svx2/<quoi>_<résolution>.png), à REGARDER :
##   choix de carte v2 (montée de niveau, Maj : détail, mode visée « Bannir… », coffre du gardien, 1er choix), HUD v2 en jeu
##   (début, milieu riche, gardien annoncé, arène du boss), moments manga (« Niveau ! », évolution), page « Équipement » de la
##   pause, bilans (victoire riche, défaite).
## godot --path game res://tests/shot_svx2.tscn -- [cartes|hud|pause|bilan|tout]   (SVX2_RES=1280x720 : petite fenêtre)
## APPDATA détourné conseillé : le profil est remis à zéro.

var res := "1600x900"


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots/svx2")
	get_viewport().get_texture().get_image().save_png("user://shots/svx2/%s_%s.png" % [name, res])
	print("[shot] svx2/%s_%s.png" % [name, res])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var what := "tout"
	for a in OS.get_cmdline_user_args():
		if a in ["cartes", "hud", "pause", "bilan", "tout"]:
			what = a
	Settings.reset_all()
	if OS.get_environment("SVX2_RES") != "":
		res = OS.get_environment("SVX2_RES")
	Settings.set_v("display", "resolution", res)
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
	if what in ["cartes", "hud", "pause", "tout"]:
		await _world(what)
	if what in ["bilan", "tout"]:
		await _bilan()
	get_tree().quit()


func _world(what: String) -> void:
	await get_tree().process_frame
	Survivor.start("warrior", "limestone")
	SurvivorCards.seed_with(7)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(2.0, true, false, true).timeout
	while world.get("cards") == null:
		await get_tree().process_frame
	var picker: SurvivorPicker = world.cards
	world.player.dev_invincible = true
	for k in 150:  # le fondu d'arrivée (ScreenFade) doit être fini avant la première capture
		if not get_tree().root.get_children().any(func(n): return n is ScreenFade):
			break
		await get_tree().create_timer(0.1, true, false, true).timeout
	picker._queue.clear()
	picker._show_next()
	Run.apply_card(SurvivorCards.weapon_card())
	Run.apply_card(SurvivorCards.spell_card(int(Run.class_data().skills[0].id)))
	world.player.skills_changed.emit()
	if what in ["hud", "tout"]:
		await _shot("hud_debut", 2.0)
	SurvivorCards.minutes_override = -1.0
	preload("res://tests/shot_sv5.gd").rich_state()
	world.player.level = 34
	world.player.recalc_stats()
	world.player.hp = world.player.max_hp * 0.62
	world.player.skills_changed.emit()
	world.director.time = 14.0 * 60.0 + 12.0
	for i in 2:  # deux gardiens vaincus (la frise les coche)
		world.director.sv.guardians.append({"n": i, "t": 300.0 * (i + 1), "level": 30, "hp": 1000, "ttk": 30.0 + i * 7.0})
	SurvivorLog.tag = "weapon"
	SurvivorLog.note(41000.0)
	SurvivorLog.tag = "skill:%d" % int(Run.all_skills()[0].id)
	SurvivorLog.note(27000.0)
	SurvivorLog.tag = SurvivorLog.proc_tag("ember_0")
	SurvivorLog.note(16000.0)
	SurvivorLog.tag = ""
	SurvivorLog.note(6000.0, true)
	if what in ["hud", "tout"]:
		await _shot("hud_milieu", 1.5)
		world.hud._sv_hud.moments.level_up(35)
		await _shot("moment_niveau", 0.25)
		world.hud._sv_hud.moments.evolution("Lame du phénix")
		await _shot("moment_evolution", 0.45)
		world.director.time = 4.0 * 60.0 + 52.0
		await _shot("hud_gardien", 1.0)
		world.director.time = 14.0 * 60.0 + 12.0
	if what in ["cartes", "tout"]:
		# premier choix (rejoué ici : au tout début, le fondu d'arrivée du monde peut encore couvrir la capture)
		Profile.tutorial["seen"] = []
		picker.offer("Choisis ton arme ou ta première compétence", SurvivorCards.first_offer(), func(): return SurvivorCards.first_offer())
		await _shot("premier_choix", 1.0)
		picker._queue.clear()
		picker._show_next()
		Run.hero_level = 34
		picker.offer("Niveau 35 ! Choisis une carte", [SurvivorCards.up_card("head", "epic"), SurvivorCards.new_piece_card("boots"),
			SurvivorCards.spell_up_card(int(Run.skills[0].id), "epic")], func(): return Run.roll_cards(3))
		picker.offer("Niveau 36 ! Choisis une carte", Run.roll_cards(3), func(): return Run.roll_cards(3))
		await _shot("choix_niveau", 1.2)
		picker._set_hover(1)
		await _shot("choix_survol", 0.4)
		picker.set_detail(true)
		await _shot("choix_detail", 0.6)
		picker.set_detail(false)
		picker.toggle_aim("ban")
		await _shot("choix_bannir", 0.5)
		picker.toggle_aim("ban")
		Gamepad._set_active(true)
		picker._refresh_reroll()
		await _shot("choix_manette", 0.6)
		Gamepad._set_active(false)
		picker._queue.clear()
		picker._show_next()
		picker.offer("Coffre du gardien : choisis une carte", SurvivorCards.chest_cards("sv_guardian"), func(): return SurvivorCards.chest_cards("sv_guardian"), 1)
		await _shot("choix_coffre", 1.0)
		picker._queue.clear()
		picker._show_next()
	if what in ["pause", "tout"]:
		world.pause_menu.open()
		var page: SurvivorBuildPage = world.pause_menu.build
		page.set_work_open(true)
		await _shot("pause_equipement", 2.5)
		page.set_work_open(false)
		await _shot("pause_equipement_replie", 0.6)
		world.pause_menu.close()
		await get_tree().process_frame
	if what in ["hud", "tout"]:
		world.director.time = 19.0 * 60.0 + 59.0
		await get_tree().create_timer(6.0, true, false, true).timeout
		picker._queue.clear()
		picker._show_next()
		if world.director._boss_time < 1.0:
			world.director._boss_time = 200.0
		await _shot("hud_boss", 1.5)
	world.queue_free()
	await get_tree().process_frame
	Run.finish("abandon")
	Profile.end_run_survival()
	get_tree().paused = false


func _bilan() -> void:
	for res_kind in ["victoire", "defaite"]:
		Profile.reset_all()
		Survivor.start("warrior", "beluga", 2)
		SurvivorCards.seed_with(3)
		preload("res://tests/shot_sv5.gd").rich_state()
		Run.max_level = 31
		Run.kills = 2812
		Run.elites = 14
		SurvivorLog.begin()
		for k in [["weapon", 41000.0], ["skill:%d" % int(Run.all_skills()[0].id), 27000.0], [SurvivorLog.proc_tag("ember_0"), 16000.0],
				["skill:%d" % int(Run.all_skills()[1].id), 12000.0], ["dot", 5000.0]]:
			SurvivorLog.tag = String(k[0])
			SurvivorLog.note(float(k[1]))
		SurvivorLog.tag = ""
		SurvivorLog.moment(337.0, "Gardien 1 vaincu en 0:37", "guardian")
		SurvivorLog.moment(611.0, "Jet parfait : Couronne", "perfect")
		SurvivorLog.moment(642.0, "Gardien 2 vaincu en 0:42", "guardian")
		SurvivorLog.moment(800.0, "Niveau 30", "level")
		SurvivorLog.moment(1200.0, "Arène du boss", "boss")
		SurvivorRewards.stats = {"time": 1361.0 if res_kind == "victoire" else 742.0, "guardians": 3 if res_kind == "victoire" else 2,
			"arena": res_kind == "victoire", "early": 0.0}
		RunJournal._time = 30.0
		Run.finish(res_kind)
		var bg := ColorRect.new()
		bg.color = Color(0.67, 0.71, 0.5)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(bg)
		var rs := ResultsScreen.new()
		add_child(rs)
		rs.show_results()
		await _shot("bilan_" + res_kind, 2.5)
		rs.queue_free()
		bg.queue_free()
		get_tree().paused = false
		Profile.end_run_survival()
