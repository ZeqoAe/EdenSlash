extends Node
## Captures du lot SVX-4 (Survivant : faveurs, pièces maudites, boutique du gardien, accessibilité, partie du jour, reprise,
## prolongations, choix regroupés, fiches du Codex), user://shots/svx4/<quoi>_<rés>.png, à REGARDER : page du mode (reprise,
## faveurs, partie du jour), réglages (accessibilité), boutique du gardien, carte de pièce maudite, HUD (sous-titres, choix en
## attente, horde contrastée), fiche d'arme et onglet Sorts du Codex.
## godot --path game res://tests/shot_svx4.tscn -- [lobby|reglages|boutique|cartes|hud|codex|tout]   (SVX4_RES=1280x720)
## APPDATA détourné conseillé : le profil est remis à zéro.

var res := "1600x900"


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots/svx4")
	get_viewport().get_texture().get_image().save_png("user://shots/svx4/%s_%s.png" % [name, res])
	print("[shot] svx4/%s_%s.png" % [name, res])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var what := "tout"
	for a in OS.get_cmdline_user_args():
		if a in ["lobby", "reglages", "boutique", "cartes", "hud", "codex", "tout"]:
			what = a
	Settings.reset_all()
	if OS.get_environment("SVX4_RES") != "":
		res = OS.get_environment("SVX4_RES")
	Settings.set_v("display", "resolution", res)
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
	if what in ["lobby", "tout"]:
		await _lobby()
	if what in ["reglages", "tout"]:
		await _settings()
	if what in ["codex", "tout"]:
		await _codex()
	if what in ["boutique", "cartes", "hud", "tout"]:
		await _world(what)
	get_tree().quit()


func _lobby() -> void:
	Profile.reset_all()
	preload("res://tests/shot_svx3.gd").fill_codex()
	var st: Dictionary = Profile.records[SurvivorRewards.KEY]
	st["favor"] = "horde"
	st["daily"] = {"day": Quests.today(), "runs": [{"class": "warrior", "res": "victoire", "time": 1311.0, "level": 42, "kills": 9870},
		{"class": "warrior", "res": "defaite", "time": 1040.0, "level": 33, "kills": 6020}]}
	Profile.records[SurvivorRewards.KEY] = st
	# une partie sauvée (Sauver et quitter) : la ligne « Reprendre la partie »
	SafeFile.write(SurvivorSave.PATH, var_to_str({"v": SurvivorSave.VERSION, "class": "warrior", "zone": "limestone", "palier": 1, "time": 754.0, "level": 24}), func(t): return SurvivorSave._valid(t))
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(3.0, true, false, true).timeout
	lobby.call("_show_menu", "survivor")
	await _shot("lobby_haut", 1.5)
	var scroll: ScrollContainer = lobby.get("_scroll")
	for target in ["Sans faveur", "Jouer la partie du jour"]:
		var btn: Control = null
		for b in lobby.find_children("*", "Control", true, false):
			if b is Button and (b as Button).text.begins_with(target):
				btn = b
			elif b.get("title") != null and String(b.get("title")).begins_with(target):
				btn = b
		if btn == null:
			for b in lobby.find_children("*", "Label", true, false):
				if (b as Label).text.begins_with(target) or (b as Label).text.contains(target):
					btn = b
		if scroll != null and btn != null:
			scroll.ensure_control_visible(btn)
		await _shot("lobby_" + ("faveurs" if target == "Sans faveur" else "jour"), 1.0)
	lobby.queue_free()
	SurvivorSave.clear()
	await get_tree().process_frame


func _settings() -> void:
	var host := CanvasLayer.new()
	add_child(host)
	var s := SettingsMenu.new()
	host.add_child(s)
	await get_tree().process_frame
	s.open()
	for i in 30:
		await get_tree().process_frame  # (les pages se construisent une par image)
	# la page « Caméra & interface », section Accessibilité : la ligne « Taille des nombres » à l'écran
	var target: Control = null
	for i in s.page_count():
		s.show_page(i)
		for k in 3:
			await get_tree().process_frame
		for l in s.find_children("*", "Label", true, false):
			if (l as Label).text == "Taille des nombres" and (l as Label).is_visible_in_tree():
				target = l
		if target != null:
			break
	if target != null:
		var p := target.get_parent()
		while p != null and not (p is ScrollContainer):
			p = p.get_parent()
		if p is ScrollContainer:
			(p as ScrollContainer).ensure_control_visible(target)
	await _shot("reglages_accessibilite", 1.2)
	host.queue_free()


func _codex() -> void:
	Profile.reset_all()
	preload("res://tests/shot_svx3.gd").fill_codex()
	var host := Node.new()
	add_child(host)
	var c := SurvivorCodexPage.open_on(host, SurvivorCodexPage.TABS.size() - 1)
	await _shot("codex_sorts", 1.2)
	c.show_page(1)
	var f := SurvivorCodexPage.Fiche.open_on(host, "weapon", "axe")
	await _shot("codex_fiche_arme", 1.0)
	f.queue_free()
	var sk: Dictionary = GameData.class_data("warrior").get("skills", [{}])[0]
	var f2 := SurvivorCodexPage.Fiche.open_on(host, "spell", str(int(sk.get("id", 0))))
	await _shot("codex_fiche_sort", 1.0)
	f2.queue_free()
	host.queue_free()


func _world(what: String) -> void:
	await get_tree().process_frame
	Profile.reset_all()
	Settings.set_v("interface", "alert_captions", true)
	Survivor.start("warrior", "limestone", 1, "")
	SurvivorCards.seed_with(19)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(0.6, true, false, true).timeout
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
	Run.apply_card(SurvivorCards.weapon_card())
	for s in SurvivorCards.spells_open().slice(0, 3):
		Run.apply_card(SurvivorCards.spell_card(int(s.id)))
	for slot in ["head", "chest", "gloves"]:
		Run.apply_card(SurvivorCards.new_piece_card(slot))
	Run.hero_level = 14
	world.player.level = 14
	world.player.recalc_stats()
	if what in ["cartes", "tout"]:
		var cards: Array = []
		for slot in ["legs", "boots", "ring"]:
			var c := SurvivorCards.new_piece_card(slot)
			if not c.is_empty():
				cards.append(c)
		if not cards.is_empty():
			var it: Dictionary = cards[0].item
			SurvivorGear.curse(it, "avide")
			cards[0] = SurvivorCards.piece_card(it)
		world._offer("Niveau 14 ! Choisis une carte", cards, func(): return Run.roll_cards(3))
		await _shot("choix_maudite", 1.5)
		picker.set_detail(true)
		await _shot("choix_maudite_detail", 1.0)
		picker.set_detail(false)
		picker._queue.clear()
		picker._show_next()
	if what in ["boutique", "tout"]:
		Profile.gold = 4200
		var ui := SurvivorShopUI.new()
		world.add_child(ui)
		ui.open_shop(300.0)
		await _shot("boutique", 1.2)
		ui._do_buy(0)
		ui._do_keep(2)
		await _shot("boutique_achat_garde", 0.8)
		ui.close_shop()
		ui.queue_free()
	if what in ["hud", "tout"]:
		Settings.set_v("interface", "sv_group_choices", true)
		Settings.set_v("interface", "horde_contrast", true)
		world.director.time = 288.0
		await get_tree().create_timer(2.5, true, false, true).timeout
		world._on_level_up(15)
		world._on_level_up(16)
		SurvivorHud.caption("Sifflement : une élite va exploser")
		await _shot("hud_sous_titres_attente", 1.0)
		Settings.set_v("interface", "sv_group_choices", false)
		Settings.set_v("interface", "horde_contrast", false)
	Settings.set_v("interface", "alert_captions", false)
	world.queue_free()
	await get_tree().process_frame
