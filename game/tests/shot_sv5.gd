extends Node
## Captures de l'interface du Survivant (lot S5, user://shots/sv5_<quoi>_<résolution>.png), à REGARDER :
##   cartes : premier choix (avec la fiche), pièce (avec la fiche « pièce à vie »), amélioration à passif de palier, sort
##   (amélioration), coffre d'emplacement, jet parfait et arme ; page Build de la pause (début et fin de run) ;
##   HUD en jeu au début, au milieu (14:00), à la fin (19:30) et dans l'arène du boss.
## godot --path game res://tests/shot_sv5.tscn -- [cartes|build|hud|tout]   (SV5_RES=1280x720 : petite fenêtre)
## APPDATA détourné conseillé : le profil est remis à zéro.

var res := "1600x900"


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/sv5_%s_%s.png" % [name, res])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var what := "tout"
	for a in OS.get_cmdline_user_args():
		if a in ["cartes", "build", "hud", "tout"]:
			what = a
	Settings.reset_all()
	if OS.get_environment("SV5_RES") != "":
		res = OS.get_environment("SV5_RES")
	Settings.set_v("display", "resolution", res)
	Profile.reset_all()
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
	if what in ["cartes", "tout"]:
		await _cards()
	if what in ["build", "hud", "tout"]:
		await _world(what)
	get_tree().quit()


## Un état de run riche : arme +6, 6 pièces dont une parfaite et une +10, 5 sorts à des niveaux variés.
static func rich_state(level := 34, minutes := 14.0) -> void:
	SurvivorCards.minutes_override = minutes
	Run.hero_level = level
	var w := SurvivorCards.weapon_card()
	Run.apply_card(w)
	var skills: Array = Run.class_data().skills
	var n_spells := int(OS.get_environment("SV5_SPELLS")) if OS.get_environment("SV5_SPELLS") != "" else 5  # S9 : 12 = grille pleine
	for k in mini(n_spells, skills.size()):
		Run.apply_card(SurvivorCards.spell_card(int(skills[k].id)))
	var ranks := [7, 4, 10, 2, 1]
	for k in Run.all_skills().size():
		var s: Dictionary = Run.all_skills()[k]
		for r in ranks[k % ranks.size()] - 1:
			var c := SurvivorCards.spell_up_card(int(s.id), "rare")
			if not c.is_empty():
				Run.apply_card(c)
	for slot in ["head", "chest", "legs", "gloves", "ring", "back"]:
		var c := SurvivorCards.new_piece_card(slot)
		if not c.is_empty():
			Run.apply_card(c)
	Profile.equipped.head.quality = Survivor.rule("perfect_quality")
	for slot_up in [["weapon", 3], ["chest", 5], ["head", 2], ["legs", 1]]:
		for i in int(slot_up[1]):
			var c := SurvivorCards.up_card(String(slot_up[0]), "common")
			if not c.is_empty():
				Run.apply_card(c)


func _cards() -> void:
	SurvivorCards.seed_with(7)
	Survivor.start("warrior", "limestone")
	var bg := ColorRect.new()
	bg.color = Color(0.22, 0.27, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var picker := CardPicker.new()
	add_child(picker)
	var next := func() -> void:
		picker._queue.clear()
		picker._show_next()
	picker.offer("Choisis ton arme ou ta première compétence", SurvivorCards.first_offer(), func(): return SurvivorCards.first_offer())
	await _shot("premier_choix")
	next.call()
	Run.apply_card(SurvivorCards.weapon_card())
	Run.apply_card(SurvivorCards.spell_card(int(Run.class_data().skills[0].id)))
	Run.hero_level = 6
	SurvivorCards.minutes_override = 3.0
	picker.offer("Niveau 6 ! Choisis une carte", [SurvivorCards.new_piece_card("chest"), SurvivorCards.new_piece_card("head"),
		SurvivorCards.spell_up_card(int(Run.skills[0].id), "rare")], func(): return Run.roll_cards(3))
	await _shot("piece_fiche")
	next.call()
	Run.apply_card(SurvivorCards.new_piece_card("head"))
	Profile.equipped.head.upgrade = 4
	Run.apply_card(SurvivorCards.spell_card(int(Run.class_data().skills[1].id)))
	for i in 3:
		Run.apply_card(SurvivorCards.spell_up_card(int(Run.skills[0].id), "rare"))
	Run.hero_level = 14
	SurvivorCards.minutes_override = 7.0
	picker.offer("Niveau 14 ! Choisis une carte", [SurvivorCards.up_card("head", "epic"), SurvivorCards.up_card("weapon", "legendary"),
		SurvivorCards.spell_up_card(int(Run.skills[0].id), "epic")], func(): return Run.roll_cards(3))
	await _shot("amelioration")
	next.call()
	picker.offer("Coffre de torse : choisis une carte", SurvivorCards.chest_cards("sv_chest"), func(): return SurvivorCards.chest_cards("sv_chest"), 1)
	await _shot("coffre")
	next.call()
	var perfect := SurvivorCards.new_piece_card("boots")
	perfect.item.quality = Survivor.rule("perfect_quality")
	var spell_new := SurvivorCards.spell_card(int(Run.class_data().skills[2].id))
	picker.offer("Niveau 15 ! Choisis une carte", [perfect, spell_new, SurvivorCards.new_piece_card("necklace")], func(): return Run.roll_cards(3))
	await _shot("parfaite")
	next.call()
	Run.finish("abandon")
	Profile.end_run_survival()
	bg.queue_free()
	picker.queue_free()


func _world(what: String) -> void:
	await get_tree().process_frame  # (« build » seul : la racine monte encore ses enfants)
	Profile.reset_all()
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
	Profile.selected_class = "warrior"
	Survivor.start("warrior", "limestone")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(1.5, true, false, true).timeout
	while world.cards == null:  # (le monde se monte en plusieurs images)
		await get_tree().process_frame
	world.cards._queue.clear()
	world.cards._show_next()
	world.player.dev_invincible = true
	if what in ["hud", "tout"]:
		Run.apply_card(SurvivorCards.weapon_card())
		Run.apply_card(SurvivorCards.spell_card(int(Run.class_data().skills[0].id)))
		world.player.skills_changed.emit()
		await _shot("hud_debut", 2.0)
	SurvivorCards.minutes_override = -1.0
	rich_state()
	world.player.level = 34
	world.player.recalc_stats()
	world.player.skills_changed.emit()
	world.director.time = 14.0 * 60.0 + 12.0
	if what in ["build", "tout"]:
		world.pause_menu.open()
		await _shot("build", 3.0)  # (le fondu d'entrée du monde doit être fini)
		world.pause_menu.close()
		await get_tree().process_frame
	if what in ["hud", "tout"]:
		await _shot("hud_milieu", 1.5)
		world.director.time = 19.0 * 60.0 + 30.0
		await _shot("hud_fin", 1.5)
		world.director.time = 4.0 * 60.0 + 52.0  # annonce du 1er gardien (5:00)
		await _shot("hud_gardien", 1.0)
		world.director.time = 19.0 * 60.0 + 59.0
		await get_tree().create_timer(6.0, true, false, true).timeout
		world.cards._queue.clear()
		world.cards._show_next()
		if world.director._boss_time < 1.0:
			world.director._boss_time = 200.0
		await _shot("hud_boss", 1.5)
