extends Node3D
## Scène d'une run : environnement, map, héros, caméra, directeur de zone,
## interface, choix de cartes, menu pause, résurrections et bilan.
##
## Arguments de test (après `--`) :
##   --autoplay            le héros combat tout seul (et choisit ses cartes)
##   --cards=a,b:2         cartes de build au départ   --gear=storm  panoplie d'un set
##   --shots=4,8,12        captures d'écran à ces secondes (dans user://shots/)
##   --quit-at=13          quitte après N secondes
##   --god                 héros invincible (mesures de performance)
##   --idle                héros immobile qui ne frappe pas (avec --god : foule maximale)
##   --card-shot           ouvre un choix de cartes de démonstration (avec --shots)
##   --orbs-shot           sème des orbes d'expérience autour du héros (avec --idle --shots)
##   --start-level=8       niveau de départ
##   --dungeon             entre directement dans le donjon
##   --teleport=x,z        place le héros
##   --cam-dist=N          distance de la caméra
##   --goto=dungeon|shrine|merchant|chest   place le héros près de ce lieu
##   --shot-prefix=nom     préfixe des captures (lancements en parallèle)
##   --tower               lance la Tour (--tower-floor=N : à l'étage N, --tower-diff=0..3)

const REVIVES_PER_RUN := 1

var player: Player
var director: RunDirector
var rig: CameraRig
var hud: Hud
var env: Environment
var sun: DirectionalLight3D
var tools: TestTools
var cards: CardPicker
var pause_menu: PauseMenu
var merchant_ui: MerchantUI

var revives_left := REVIVES_PER_RUN
var autoplay_boss_after := 99999.0  # bot de test : temps avant d'aller au boss
var _shots: Array = []
var _shot_prefix := ""
var _teleport := Vector2.INF
var _debug_dungeon := false
var _quit_at := -1.0
var _time := 0.0
var _ended := false
var _debug_open := ""
var _goto := ""


## Test : ouvre un écran pour la capture (--open=pause|cards|map|settings0..5).
func _open_for_test() -> void:
	if _debug_open == "pause":
		pause_menu.open()
	elif _debug_open == "cards":
		cards.offer("Niveau 2 ! Choisis une carte", Run.roll_cards(3))
	elif _debug_open.begins_with("settings"):
		pause_menu.open()
		pause_menu.settings.open(int(_debug_open.trim_prefix("settings")))
	elif _debug_open == "map":
		hud._big_map.visible = true
	elif _debug_open == "fortune":
		# autel de la fortune : étage 1 gagné, l'étage 2 proposé
		cards._queue.clear()
		cards._show_next()
		var f := FortunePopup.open(self, player.level, player.level, Callable())
		await get_tree().process_frame
		f._pick(1, (f._trap + 2) % 8)
	elif _debug_open in ["merchant", "forge"]:
		# profil de test (user://profile_test.json) : jamais celui du joueur
		cards._queue.clear()
		cards._show_next()
		for i in 14:
			Profile.add_item(Items.generate(player.level + randi_range(0, 3), randf_range(-0.5, 1.0)))
		Profile.materials.crystal = int(Profile.materials.get("crystal", 0)) + 40
		Profile.add_gold(800)
		# fournitures de test pour la forge
		for k in ["drill", "drill", Craft.stone_key("lucky"), Craft.stone_key("coral"), Craft.stone_key("safety"), Craft.BLESSED,
				Craft.fortify_key("power", 20), Craft.fortify_key("power", 20), Craft.fortify_key("guard", 20), Craft.gem_key("ruby", 1), Craft.gem_key("garnet", 2),
				Craft.gem_key("amethyst", 0), Craft.scroll_key("violence", 1), Craft.scroll_key("muscle", 4)]:
			Profile.add_bag(k)
		if _debug_open == "forge":
			merchant_ui.open_forge(Profile.inventory[0])
		else:
			merchant_ui.open()
			get_tree().create_timer(1.5, true, false, true).timeout.connect(func(): merchant_ui._on_entry_pressed(merchant_ui._shown[0], 0) if not merchant_ui._shown.is_empty() else null)


## Mesures d'équilibrage : --class=<id> (classe du profil), --hub=new | <époque>.<carte>.<+N>[.<palier de gemme>]
## (équipement du hub, voir StarterGear.scenario), avant le départ de la run (profil séparé : EDEN_PROFILE).
func _apply_scenario_args() -> void:
	var hub := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			Profile.selected_class = arg.trim_prefix("--class=")
			Profile.save_profile()  # change la vue du hub vers cette classe (équipement de départ compris)
		elif arg.begins_with("--hub="):
			hub = arg.trim_prefix("--hub=")
	if hub != "":
		# mesures : réglages par défaut en mémoire (settings_test.cfg, partagé avec les tests, faussait le bot)
		Settings.reset_all(false)
	if hub != "" and hub != "new":
		Profile.install_gear(StarterGear.scenario(hub, Profile.selected_class))


func _ready() -> void:
	add_to_group("world")  # mode dev (F10) : actions de run
	ScreenFade.reveal(get_tree())  # arrivée en fondu (la carte se génère pendant le noir)
	if not Run.active:
		_apply_scenario_args()
		if "--training" in OS.get_cmdline_user_args():
			Training.start(Profile.selected_class)  # test : zone d'entraînement
		elif "--duel" in OS.get_cmdline_user_args():
			# test : duel contre --duel-class=… en --duel-diff=0..3 (le preset actif ou les 4 premiers sorts)
			var opp := "warrior"
			var dd := 2
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--duel-class="):
					opp = arg.trim_prefix("--duel-class=")
				elif arg.begins_with("--duel-diff="):
					dd = int(arg.trim_prefix("--duel-diff="))
				elif arg.begins_with("--duel-pilot="):  # cerveau d'IA (debutant … hardcore, actuel)
					Duel.pilot = arg.trim_prefix("--duel-pilot=")
				elif arg.begins_with("--duel-build="):  # adversaire enregistré dans l'éditeur
					var bi := RivalBuilds.find(arg.trim_prefix("--duel-build="))
					if bi >= 0:
						Duel.rival_build = RivalBuilds.list()[bi]
			Duel.start(Profile.selected_class, opp, dd)
			if Run.skills.is_empty():
				for sk in Run.class_data().get("skills", []).slice(0, 4):
					Run.skills.append({"id": int(sk.id), "rank": 1})
		elif "--royale" in OS.get_cmdline_user_args():
			for arg in OS.get_cmdline_user_args():  # test : Battle royale (--royale-diff=0..3)
				if arg.begins_with("--royale-diff="):
					Royale.difficulty = int(arg.trim_prefix("--royale-diff="))
			Royale.start(Profile.selected_class)
		elif "--tower" in OS.get_cmdline_user_args():
			var diff := 1  # test : la Tour (--tower-diff=0..3, --tower-floor=N)
			var from := 1
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--tower-diff="):
					diff = int(arg.trim_prefix("--tower-diff="))
				elif arg.begins_with("--tower-floor="):
					from = int(arg.trim_prefix("--tower-floor="))
			Tower.start(Profile.selected_class, diff, from)
		else:
			# test : une run de Survie (--epoch=N ; époque I par défaut, ou celle de la zone choisie)
			var ep := 1
			for i in range(Epochs.count(), 0, -1):
				if Epochs.zone(i, 1) == Profile.selected_zone:
					ep = i
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--epoch="):
					ep = int(arg.trim_prefix("--epoch="))
			Run.start_survival(Profile.selected_class, ep)
	_build_environment()

	player = Player.new()
	add_child(player)
	player.global_position = Vector3(0, 0.5, 0)

	rig = CameraRig.new()
	add_child(rig)
	rig.target = player
	rig.global_position = player.global_position

	director = RunDirector.new()
	Profile.class_unlocked.connect(_on_class_unlocked)
	director.world = self
	add_child(director)

	hud = Hud.new()
	add_child(hud)
	hud.setup(player, director)

	tools = TestTools.new()
	add_child(tools)
	tools.setup(player, director)

	cards = CardPicker.new()
	add_child(cards)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(player)
	pause_menu.abandon_requested.connect(func():
		if Training.active:
			Training.leave(get_tree())
		elif Tower.active:
			tower_end("abandon")
		elif Duel.active:
			duel_end(false)
		elif Royale.active:
			royale_end(Royale.PLAYERS)
		else:
			end_run("abandon"))
	if Training.active:
		var tp := TrainingPanel.new()
		add_child(tp)
		tp.setup(player, director)
	merchant_ui = MerchantUI.new()
	add_child(merchant_ui)
	merchant_ui.setup(player, director)

	player.health_changed.connect(_on_player_hp)
	player.leveled_up.connect(_on_level_up)
	player.died.connect(_on_player_died)
	director.boss_defeated.connect(func(): end_run("victoire"))
	director.extracted.connect(func(): end_run("extraction"))
	pause_menu.extract_requested.connect(func(): director.start_extraction())
	_parse_args()
	# captures et arrêt programmés indépendamment de la pause
	for t in _shots:
		get_tree().create_timer(t, true).timeout.connect(_save_screenshot.bind("%sshot_%02d.png" % [_shot_prefix, int(t)]))
	if _quit_at > 0.0:
		get_tree().create_timer(_quit_at, true).timeout.connect(func():
			_print_report()
			get_tree().quit())
	var zone_bonus := int(GameData.zone(Run.zone_id).get("level_bonus", 0))
	if zone_bonus > 0 and player.level < 1 + zone_bonus and not Royale.active:
		player.level = 1 + zone_bonus
		player.recalc_stats()
		player.hp = player.max_hp
	director.start(player)
	if _debug_dungeon:
		director.debug_enter_dungeon()
	if _teleport != Vector2.INF:
		var h: float = map.height_at(_teleport.x, _teleport.y)
		player.global_position = Vector3(_teleport.x, h + 0.5, _teleport.y)
	if _goto != "":
		var target: Vector3 = {"village": map.village, "dungeon": map.dungeon}.get(_goto, map.start)
		var off := Vector3(6, 1, 6)
		match _goto:  # tests : sanctuaire, marchand ambulant, coffre
			"shrine":
				target = map.shrines[0].global_position
				off = Vector3(0, 1, 3.0)
			"merchant", "chest":
				for it in map.interactables:
					if it.kind == _goto:
						target = it.global_position
						off = Vector3(0, 1, 4.5)
						break
		player.global_position = target + off
	rig.global_position = player.global_position
	director.prompt_changed.connect(hud.show_prompt)
	director.npc_opened.connect(_on_npc_opened)
	if Duel.active:
		pass  # duel : le build du preset, pas de carte
	elif Tower.active:
		# la Tour : une seule carte de départ, de rareté aléatoire
		_offer("Ta carte de départ", [Run.roll_cards(6).pick_random()])  # Tour, donjons, Siège, Ruée
	# première compétence : choix parmi 3 cartes de compétence
	elif Run.skills.is_empty():
		var n := int(Run.class_data().get("start_skills", 3))
		if _goto != "":
			Run.apply_card(Run.roll_cards(n, true)[0])  # captures (--goto) : pas de choix à l'écran
		else:
			_offer("Choisis ta première compétence", Run.roll_cards(n, true), func(): return Run.roll_cards(n, true))


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			player.autoplay = true
		elif arg == "--idle":
			# test : pilote automatique immobile (encerclé, pour mesurer la foule)
			player.autoplay = true
			player.autoplay_idle = true
		elif arg.begins_with("--shots="):
			rig.allow_input = false  # la souris réelle ne doit pas perturber les captures
			for s in arg.trim_prefix("--shots=").split(","):
				_shots.append(float(s))
		elif arg.begins_with("--quit-at="):
			_quit_at = float(arg.trim_prefix("--quit-at="))
		elif arg.begins_with("--aim="):
			# test : mode de visée sans toucher aux paramètres enregistrés
			if not Settings.data.has("game"):
				Settings.data["game"] = {}
			Settings.data["game"]["aim_mode"] = arg.trim_prefix("--aim=")
		elif arg == "--bot-mode":
			# test : mode « Bot » (combos parfaits, attaque et déplacement automatiques) sans l'enregistrer
			for k in Settings.PRESETS.bot.game:
				Settings.data["game"][k] = Settings.PRESETS.bot.game[k]
		elif arg.begins_with("--cam-dist="):
			rig.distance = float(arg.trim_prefix("--cam-dist="))
		elif arg == "--test-feedback":
			get_tree().create_timer(3.0).timeout.connect(func():
				tools._open_report()
				tools._save_report("test automatique du rapport F9"))
		elif arg.begins_with("--open="):
			_debug_open = arg.trim_prefix("--open=")
			get_tree().create_timer(4.0).timeout.connect(_open_for_test)
		elif arg == "--dungeon":
			_debug_dungeon = true
		elif arg.begins_with("--teleport="):
			var xz := arg.trim_prefix("--teleport=").split(",")
			_teleport = Vector2(float(xz[0]), float(xz[1]))
		elif arg.begins_with("--end-at="):
			var t_end := float(arg.trim_prefix("--end-at="))
			get_tree().create_timer(t_end).timeout.connect(func():
				for i in 6:
					Profile.add_item(Items.generate(player.level + 1, randf()))
				end_run("abandon"))
		elif arg.begins_with("--extract-at="):
			var t_ex := float(arg.trim_prefix("--extract-at="))
			get_tree().create_timer(t_ex).timeout.connect(func():
				for i in 3:
					Profile.add_item(Items.generate(player.level + 1, randf()))
				director.start_extraction())
		elif arg.begins_with("--seals="):
			var n_seals := int(arg.trim_prefix("--seals="))
			get_tree().create_timer(1.0).timeout.connect(func(): director.seals = n_seals)
		elif arg.begins_with("--seed="):
			Run.seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--boss-after="):
			autoplay_boss_after = float(arg.trim_prefix("--boss-after="))
		elif arg.begins_with("--shot-prefix="):
			_shot_prefix = arg.trim_prefix("--shot-prefix=") + "_"
		elif arg.begins_with("--goto="):
			_goto = arg.trim_prefix("--goto=")
		elif arg == "--orbs-shot":
			# test : orbes d'expérience de toutes tailles autour du héros immobile
			get_tree().create_timer(1.0).timeout.connect(func():
				for i in 40:
					var a := randf() * TAU
					var r := randf_range(4.0, 12.0)
					var p := player.global_position + Vector3(cos(a) * r, 0, sin(a) * r)
					director.orbs.spawn(p, [2.0, 8.0, 60.0].pick_random()))
		elif arg == "--card-shot":
			# test : choix de cartes avec un passif déjà pris (totaux avant → après), une
			# amélioration de sort et une nouvelle carte
			get_tree().create_timer(1.5).timeout.connect(func():
				Run.passives["wide_arc"] = 1
				Run.passive_power["wide_arc"] = 1.0
				Run.passives["static_blade"] = 2
				Run.passive_power["static_blade"] = 2.5
				if Run.skills.is_empty():
					var heal: Array = Run.class_data().get("skills", []).filter(func(x): return String(x.get("kind", "")) == "heal" or float(x.get("heal", 0.0)) > 0.0)
					var first: Dictionary = heal[0] if not heal.is_empty() else Run.class_data().get("skills", [{"id": 0}])[0]
					Run.skills.append({"id": int(first.id), "rank": 1})
				var picks: Array = [Run._describe_card({"type": "passive", "id": "wide_arc"})]
				if not Run.skills.is_empty():
					picks.append(Run._describe_card({"type": "upgrade", "id": int(Run.skills[0].id)}))
				picks.append(Run._describe_card({"type": "passive", "id": "static_blade"}))
				cards.offer("Niveau 5 ! Choisis une carte", picks, func(): return Run.roll_cards(3)))
		elif arg.begins_with("--pause="):
			# test : menu pause ouvert sur la page N (0 Run, 1 Héros, 2 Aide), avec --shots
			var page := int(arg.trim_prefix("--pause="))
			get_tree().create_timer(2.5).timeout.connect(func():
				cards._queue.clear()
				cards._show_next()
				for i in 6:
					Profile.add_item(Items.generate(player.level + randi_range(0, 2), randf_range(0.0, 1.0)))
				pause_menu.open(page))
		elif arg == "--bigmap":
			# test : grande carte ouverte, carte entièrement découverte (avec --shots)
			get_tree().create_timer(2.0).timeout.connect(func():
				cards._queue.clear()
				cards._show_next()
				if director._fog:
					director._fog.fill(Color(0, 0, 0, 0))
					director._fog_tex.update(director._fog)
				for it in director.map.interactables:
					director._found[it] = true
				for sh in director.map.shrines:
					director._found[sh] = true
				for k in director.map.camps.size():
					if director.map.camps[k].elite:
						director._found["fort%d" % k] = director.map.camps[k].pos
				director.dungeon_found = true
				hud.hide_banner()
				hud._big_map.visible = true)
		elif arg == "--gear-shot":
			# test : choix d'équipement d'un coffre doré (avec --shots)
			get_tree().create_timer(1.5).timeout.connect(func():
				cards._queue.clear()
				cards._show_next()
				cards.offer("Coffre doré : choisis une pièce d'équipement", director.gear_cards(3, 2)))
		elif arg.begins_with("--fight="):
			Run.test_fight_range = float(arg.trim_prefix("--fight="))
		elif arg.begins_with("--rush="):
			Run.test_rush_range = float(arg.trim_prefix("--rush="))
		elif arg.begins_with("--human="):
			Run.test_taken = 1.0 - clampf(float(arg.trim_prefix("--human=")), 0.0, 0.95)
		elif arg == "--god":
			# test : héros invincible (mesures de performance sur une longue run)
			get_tree().create_timer(0.5).timeout.connect(func(): player.dev_invincible = true)
		elif arg == "--rage":
			get_tree().create_timer(2.0).timeout.connect(func(): director.debug_start_rage())
		elif arg.begins_with("--cards="):
			# cartes de build données au départ (test) : --cards=static_blade,volatile:3
			for entry in arg.trim_prefix("--cards=").split(","):
				var parts := entry.split(":")
				if not Run.passive_def(parts[0]).is_empty():
					Run.passives[parts[0]] = int(parts[1]) if parts.size() > 1 else 1
			Run.changed.emit()
		elif arg.begins_with("--gear="):
			# panoplie de test : --gear=storm (6 pièces du set, profil de test)
			var sid := arg.trim_prefix("--gear=")
			if Items.SETS.has(sid):
				for slot in ["head", "chest", "legs", "gloves", "boots", "back"]:
					var it := Items.generate(player.level, 1.0, slot, Run.class_id, 2)
					Items.make_set_piece(it, sid)
					Profile.equipped[slot] = it
				Profile.changed.emit()
		elif arg.begins_with("--start-level="):
			player.level = int(arg.trim_prefix("--start-level="))
			Run.max_level = maxi(Run.max_level, player.level)
			player.recalc_stats()
			player.hp = player.max_hp


## Propose des cartes ; en mode bot (et au pilote automatique), le choix se fait seul, équipement compris
## (CardPicker.auto_pick : aucun écran de choix ne reste ouvert).
func _offer(title: String, options: Array, reroll := Callable(), own_rerolls := -1) -> void:
	if options.is_empty():
		return
	if options.any(func(o): return String(o.get("type", "")) in ["skill", "chain", "upgrade", "passive"]):
		Tutorial.event("cards_open")
	if player.autoplay:
		# pilote automatique : cartes au hasard (passifs compris : les mesures d'équilibrage doivent voir des builds)
		Run.apply_card(CardPicker.auto_pick(options, true))
		return
	if Settings.auto_cards():
		var pick := CardPicker.auto_pick(options)
		Run.apply_card(pick)
		var what: String = {"anvil_slot": "Enclume", "anvil": "Enclume", "scroll": "Parchemin choisi"}.get(String(pick.get("type", "")),
			"Pièce choisie" if pick.has("item") else "Carte choisie")
		hud.show_message("%s : %s" % [what, String(pick.get("title", "?"))], 2.0)
		return
	cards.offer(title, options, reroll, own_rerolls)


func _on_level_up(lvl: int) -> void:
	Sfx.ui("level_up", -6.0)
	Vfx.shockwave(player, player.global_position, 5.0, Color(1.0, 0.85, 0.4))
	if Training.active or Tower.active or Duel.active:
		return  # entraînement : les cartes se choisissent dans le panneau ; Tour : une par étage
	_offer("Niveau %d ! Choisis une carte" % lvl, Run.roll_cards(3), func(): return Run.roll_cards(3))


var _trace_t := 0.0
var _trace := "--trace" in OS.get_cmdline_user_args()


func _process(delta: float) -> void:
	Potions.tick(delta)
	if _trace and not _ended and director != null and director.time >= _trace_t:
		_trace_t = director.time + 15.0  # mesures (--trace) : l'état de la run toutes les 15 s
		print("[trace] t=%3.0f niv=%d pv=%d/%d tués=%d or=%d monstres=%d état=%s" % [director.time, player.level, player.hp, player.max_hp,
			Run.kills, Profile.gold, get_tree().get_nodes_in_group("monsters").size(), director.state])


func _unhandled_input(event: InputEvent) -> void:
	if merchant_ui.is_open():
		return
	for slot in [1, 2]:
		if event.is_action_pressed("potion_%d" % slot) and not _ended and not pause_menu.is_open() and not cards.is_open():
			var msg := Potions.use(player, slot)
			if msg != "":
				hud.show_message(msg, 1.6)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("quick_equip") and not _ended and not pause_menu.is_open() and not cards.is_open():
		if hud.quick_equip():
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("extract") and not _ended and not pause_menu.is_open() and not cards.is_open():
		director.start_extraction()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and not _ended and not cards.is_open() and not tools._report_box.visible:
		if pause_menu.is_open():
			pause_menu.close()
		else:
			pause_menu.open()
		get_viewport().set_input_as_handled()


func _on_player_died(_who: Combatant, _killer: Combatant) -> void:
	if Training.active:
		hud.show_message("K.O. (entraînement) : retour immédiat", 1.5)
		await get_tree().create_timer(1.0).timeout
		player.respawn(player.global_position)
		return
	if Royale.active:
		director.royale.player_down()  # Battle royale : une seule vie ; le directeur annonce la place
		return
	if Duel.active:
		director.duel.player_down()  # manche perdue ; la manche suivante le relève
		return
	if Tower.active and Tower.siege:
		director.tower.player_down()  # Le Siège : une seule vie ; le directeur annonce la fin et le rang
		return
	if Tower.active:
		# la Tour : une seule vie
		hud.show_message("Tu es tombé à l'étage %d…" % Tower.floor_n, 2.5)
		await get_tree().create_timer(2.5).timeout
		tower_end("defaite")
		return
	if revives_left <= 0 or Challenge.has("one_life"):
		hud.show_message("Tu es tombé au combat…", 2.5)
		await get_tree().create_timer(2.5).timeout
		end_run("defaite")
		return
	revives_left -= 1
	Run.resurrections += 1
	hud.show_message("K.O. — résurrection (%d restante%s)" % [revives_left, "s" if revives_left > 1 else ""], 2.5)
	await get_tree().create_timer(3.0).timeout
	player.respawn(director.revive_point())
	rig.global_position = player.global_position


func end_run(result: String) -> void:
	if _ended:
		return
	_ended = true
	pause_menu.close()
	Run.finish(result)
	if "--auto-quit" in OS.get_cmdline_user_args():
		# mesures : une ligne de bilan puis on quitte
		print("[fin] résultat=%s niveau=%d temps=%.0f étape=%d tués=%d élites=%d insignes=%d pv=%d atk=%d matk=%d" % [result, player.level,
			director.time, Run.stage, Run.kills, Run.elites, Run.insignia_gain, player.max_hp, player.atk, player.matk])
		print("[fournitures] sac=%s coffres=%s armes découvertes=%d" % [Profile.bag, Profile.reward_chests.map(func(c): return "%s:%d" % [c.type, int(c.plevel)]),
			Run.seen_family.size()])
		get_tree().quit()
		return
	var r := ResultsScreen.new()
	add_child(r)
	r.show_results()


## Fin du duel (2 manches gagnantes, ou abandon) : bilan puis lobby.
func duel_end(won: bool) -> void:
	if _ended:
		return
	_ended = true
	pause_menu.close()
	var score := "%d - %d" % [Duel.wins, Duel.losses]
	var opp := Duel.rival_class
	var diff := Duel.difficulty
	var got := Duel.finish(won)
	var r := DuelResults.new()
	add_child(r)
	r.show_results(won, score, opp, diff, int(got.get("total", 0)))


## Fin de l'ascension (défaite, abandon, sommet) : record et expertise, puis le bilan.
func tower_end(result: String) -> void:
	if _ended:
		return
	_ended = true
	pause_menu.close()
	if Tower.is_dungeon():
		var dg := Tower.finish()
		var dr := DungeonResults.new()
		add_child(dr)
		dr.show_results(dg)
		return
	var floor_reached := Tower.reached
	var got := Tower.finish()
	var r := TowerResults.new()
	add_child(r)
	r.show_results(result, floor_reached, got)


## Bilan chiffré de la run (tests, --quit-at) : progression, butin, cartes, économie.
func _print_report() -> void:
	var rar := {}
	for it in Profile.inventory + Profile.equipped.values():
		rar[int(it.get("rarity", 0))] = int(rar.get(int(it.get("rarity", 0)), 0)) + 1
	var lv := []
	for it in Profile.inventory:
		lv.append("%d/%d" % [int(it.get("level", 0)), Items.power_level(it)])
	print("[bilan] %.0f s · état %s · niveau %d · tués %d · élites %d · or %d · clés %d · sceaux %d · coffres %d · sanctuaires %d · orbes au sol %d" % [
		director.time, director.state, player.level, Run.kills, Run.elites, Profile.gold, Profile.keys, director.seals,
		director.chests_opened, director.shrines_captured, director.orbs.count() if director.orbs else 0])
	print("[bilan] butin par rareté %s · niveaux Eden/puissance %s" % [rar, lv.slice(0, 12)])
	if director.map and "breakables" in director.map and director.map.breakables:
		print("[bilan] objets à casser restants : %d · étape %d · cupidité %s" % [director.map.breakables.count(), Run.stage, director.greed])
	print("[bilan] compétences %s" % [Run.skills.map(func(x): return "%s r%d" % [Run.skill_def(int(x.id)).get("name", x.id), int(x.rank)])])
	print("[bilan] cartes %s" % [Run.passives])
	print("[bilan] combos : %d annulations parfaites, %d enchaînements, %d esquives" % [player.ml_counts.perfect, player.ml_counts.chain, player.ml_counts.dodged])


func _save_screenshot(file_name: String) -> void:
	print("[perf] monstres=", get_tree().get_nodes_in_group("monsters").size(), " fps=", Engine.get_frames_per_second(), " niveau=", player.level, " pv=", int(player.hp),
		" nœuds=", int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), " appels=", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		" process=%.1fms physique=%.1fms" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	DirAccess.make_dir_recursive_absolute("user://shots")
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shots/" + file_name)
	print("capture : ", ProjectSettings.globalize_path("user://shots/" + file_name))


var _last_hp := -1.0


func _on_player_hp(hp: float, _max_hp: float) -> void:
	if _last_hp >= 0.0 and hp < _last_hp - 1.0:
		rig.shake(0.6)
	_last_hp = hp


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.36, 0.58, 0.9)
	sky_mat.sky_horizon_color = Color(0.82, 0.88, 0.95)
	sky_mat.ground_horizon_color = Color(0.7, 0.78, 0.7)
	sky_mat.ground_bottom_color = Color(0.3, 0.38, 0.28)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.78, 0.82)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.82
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.85, 0.89, 0.91)
	env.fog_density = 0.0018
	env.fog_sky_affect = 0.15
	Gfx.style_sky(sky_mat)
	_apply_biome_env()
	Gfx.style_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.65
	sun.directional_shadow_max_distance = 80.0
	Gfx.style_sun(sun)
	Settings.changed.connect(_on_gfx_settings)
	add_child(sun)
	sun.light_color = _base_sun


var map: Node3D


func _swap_map(m: Node3D) -> void:
	if map:
		map.remove_from_group("map")
		map.queue_free()
	map = m
	add_child(map)


## Génère la map d'une run (graine [param seed_value]).
func new_run_map(seed_value: int) -> ProcMap:
	var m := ProcMap.new()
	m.biome = String(GameData.zone(Run.zone_id).get("biome", "limestone"))
	m.name = "RunMap"
	_swap_map(m)
	m.generate_run(seed_value)
	return m


## Génère la carte du Battle royale (la carte de Survie, remplie de coffres).
func new_royale_map(seed_value: int) -> ProcMap:
	var m := ProcMap.new()
	m.biome = String(GameData.zone(Run.zone_id).get("biome", "limestone"))
	m.name = "RoyaleMap"
	_swap_map(m)
	m.generate_royale(seed_value)
	return m


## Fin d'une partie de Battle royale : récompenses de la place [param place] (1 = vainqueur), puis le bilan.
func royale_end(place: int) -> void:
	if _ended:
		return
	_ended = true
	pause_menu.close()
	var kills := Royale.kills
	var level := player.level
	var chests: int = director.royale.chests_opened if director.royale else 0
	var secs: float = director.royale.elapsed if director.royale else 0.0
	var got := Royale.finish(place)
	var r := RoyaleResults.new()
	add_child(r)
	r.show_results(place, kills, level, chests, secs, got)


## Génère l'arène du boss.
func new_arena_map(seed_value: int) -> ProcMap:
	var m := ProcMap.new()
	m.biome = String(GameData.zone(Run.zone_id).get("biome", "limestone"))
	m.name = "Arena"
	_swap_map(m)
	m.generate_arena(seed_value, String(GameData.zone(Run.zone_id).get("dungeon", {}).get("arena", "ring")))
	return m


func _on_npc_opened(_kind: String, npc: Interactable) -> void:
	merchant_ui.open(npc)


var _base_fog := Color(0.85, 0.89, 0.91)
var _base_fog_density := 0.0018
var _base_sun := Color(1.0, 0.96, 0.88)


## Mission remplie pendant la run : nouvelle classe jouable.
func _on_class_unlocked(cls: String) -> void:
	director.message.emit("Nouvelle classe débloquée : %s !" % GameData.class_data(cls).get("name_fr", cls), 5.0)


func _on_gfx_settings() -> void:
	Gfx.style_environment(env)
	Gfx.style_sun(sun)


## Ambiance du biome de la zone (ciel, brouillard, lumière) : data/biomes.json -> env.
func _apply_biome_env() -> void:
	var b: Dictionary = GameData.biomes.get(String(GameData.zone(Run.zone_id).get("biome", "")), {})
	var e: Dictionary = b.get("env", {})
	if e.is_empty():
		return
	var c := func(k: String) -> Color:
		var a: Array = e[k]
		return Color(a[0], a[1], a[2])
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = c.call("sky_top")
	sky_mat.sky_horizon_color = c.call("horizon")
	sky_mat.ground_horizon_color = c.call("horizon").darkened(0.15)
	_base_fog = c.call("fog")
	_base_fog_density = float(e.get("fog_density", 0.0018))
	_base_sun = c.call("sun")
	env.fog_light_color = _base_fog
	env.fog_density = _base_fog_density
	env.ambient_light_color = c.call("ambient")
	if sun:
		sun.light_color = _base_sun


## Après 10 minutes : ciel et brouillard rougeâtres.
func set_rage_mood(on: bool) -> void:
	if not Duel.active and not Tower.active:
		if on:
			Music.play(Music.RAGE)
		else:
			Music.play_zone(Run.zone_id)
	env.fog_light_color = Color(0.75, 0.35, 0.3) if on else _base_fog
	env.fog_density = 0.004 if on else _base_fog_density
	sun.light_color = Color(1.0, 0.6, 0.45) if on else _base_sun


## Ambiance plus sombre dans les donjons.
func set_dungeon_mood(on: bool) -> void:
	if not Duel.active and not Tower.active:
		if on:
			Music.play(Music.BOSS)
		else:
			Music.play_zone(Run.zone_id)
	env.fog_light_color = Color(0.35, 0.28, 0.42) if on else _base_fog
	env.fog_density = 0.01 if on else _base_fog_density
	env.ambient_light_energy = 0.45 if on else 0.75
	sun.light_energy = 0.35 if on else 1.25
	# hors de la grotte : du noir plutôt que le ciel
	env.background_mode = Environment.BG_COLOR if on else Environment.BG_SKY
	env.background_color = Color(0.03, 0.02, 0.04)
