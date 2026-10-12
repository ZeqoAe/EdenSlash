extends Node3D
## Scène d'une run : environnement, map, héros, caméra, directeur de zone,
## interface, choix de cartes, menu pause, résurrections et bilan.
##
## Arguments de test (après `--`) :
##   --autoplay            le héros combat tout seul (et choisit ses cartes)
##   --cards=a,b:2         cartes de build au départ   --gear=storm  panoplie d'un set
##   --shots=4,8,12        captures d'écran à ces secondes (dans user://shots/)
##   --quit-at=13          quitte après N secondes
##   --start-level=8       niveau de départ
##   --dungeon             entre directement dans le donjon
##   --teleport=x,z        place le héros
##   --cam-dist=N          distance de la caméra

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
var village_ui: VillageUI

var revives_left := REVIVES_PER_RUN
var autoplay_boss_after := 99999.0  # bot de test : temps avant d'aller au boss
var _shots: Array = []
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
	elif _debug_open in ["merchant", "smith", "trader", "jeweler"]:
		# profil de test (user://profile_test.json) : jamais celui du joueur
		cards._queue.clear()
		cards._show_next()
		for i in 14:
			Profile.add_item(Items.generate(player.level + randi_range(0, 3), randf_range(-0.5, 1.0)))
		Profile.materials.fragment += 40
		Profile.add_gold(800)
		# fournitures de test pour la forge et le joaillier
		for k in ["drill", "drill", "luck", "luck", "luck", "protect", Craft.gem_key("ruby", 1), Craft.gem_key("garnet", 2),
				Craft.gem_key("amethyst", 0), Craft.scroll_key("violence", 1), Craft.scroll_key("rehab", 1)]:
			Profile.add_bag(k)
		village_ui.open(_debug_open, "Test")
		if _debug_open in ["smith", "jeweler"]:
			get_tree().create_timer(1.5, true, false, true).timeout.connect(func():
				var it = village_ui._shown[0]
				if _debug_open == "jeweler":
					Craft.drill(it)
				village_ui._on_entry_pressed(it, 0))
		if _debug_open == "merchant":
			get_tree().create_timer(1.5, true, false, true).timeout.connect(func(): village_ui._on_entry_pressed(village_ui._shown[0], 0))


func _ready() -> void:
	add_to_group("world")  # mode dev (F10) : actions de run
	if not Run.active:
		Run.start(Profile.selected_class)
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
	pause_menu.abandon_requested.connect(func(): end_run("abandon"))
	village_ui = VillageUI.new()
	add_child(village_ui)
	village_ui.setup(player, director)

	player.health_changed.connect(_on_player_hp)
	player.leveled_up.connect(_on_level_up)
	player.died.connect(_on_player_died)
	director.boss_defeated.connect(func(): end_run("victoire"))
	director.extracted.connect(func(): end_run("extraction"))
	pause_menu.extract_requested.connect(func(): director.start_extraction())
	_parse_args()
	# captures et arrêt programmés indépendamment de la pause
	for t in _shots:
		get_tree().create_timer(t, true).timeout.connect(_save_screenshot.bind("shot_%02d.png" % int(t)))
	if _quit_at > 0.0:
		get_tree().create_timer(_quit_at, true).timeout.connect(get_tree().quit)
	var zone_bonus := int(GameData.zone(Run.zone_id).get("level_bonus", 0))
	if zone_bonus > 0 and player.level < 1 + zone_bonus:
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
		player.global_position = target + Vector3(6, 1, 6)
	rig.global_position = player.global_position
	director.prompt_changed.connect(hud.show_prompt)
	director.npc_opened.connect(_on_npc_opened)
	# première compétence : choix parmi 3 cartes de compétence
	if Run.skills.is_empty():
		var n := int(Run.class_data().get("start_skills", 3))
		_offer("Choisis ta première compétence", Run.roll_cards(n, true), func(): return Run.roll_cards(n, true))


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			player.autoplay = true
		elif arg.begins_with("--shots="):
			rig.allow_input = false  # la souris réelle ne doit pas perturber les captures
			for s in arg.trim_prefix("--shots=").split(","):
				_shots.append(float(s))
		elif arg.begins_with("--quit-at="):
			_quit_at = float(arg.trim_prefix("--quit-at="))
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
		elif arg.begins_with("--goto="):
			_goto = arg.trim_prefix("--goto=")
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
			player.recalc_stats()
			player.hp = player.max_hp


## Propose des cartes ; en mode bot, la première est choisie automatiquement.
func _offer(title: String, options: Array, reroll := Callable()) -> void:
	if options.is_empty():
		return
	if player.autoplay:
		Run.apply_card(options[0])
		return
	cards.offer(title, options, reroll)


func _on_level_up(lvl: int) -> void:
	_offer("Niveau %d ! Choisis une carte" % lvl, Run.roll_cards(3), func(): return Run.roll_cards(3))


func _unhandled_input(event: InputEvent) -> void:
	if village_ui.is_open():
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
	if revives_left <= 0:
		hud.show_message("Tu es tombé au combat…", 2.5)
		await get_tree().create_timer(2.5).timeout
		end_run("defaite")
		return
	revives_left -= 1
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
	var r := ResultsScreen.new()
	add_child(r)
	r.show_results()


func _save_screenshot(file_name: String) -> void:
	print("[perf] monstres=", get_tree().get_nodes_in_group("monsters").size(), " fps=", Engine.get_frames_per_second(), " niveau=", player.level, " pv=", int(player.hp))
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


## Génère l'arène du boss.
func new_arena_map(seed_value: int) -> ProcMap:
	var m := ProcMap.new()
	m.biome = String(GameData.zone(Run.zone_id).get("biome", "limestone"))
	m.name = "Arena"
	_swap_map(m)
	m.generate_arena(seed_value, String(GameData.zone(Run.zone_id).get("dungeon", {}).get("arena", "ring")))
	return m


func _on_npc_opened(kind: String, npc: Interactable) -> void:
	village_ui.open(kind, npc.title)


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
	env.fog_light_color = Color(0.75, 0.35, 0.3) if on else _base_fog
	env.fog_density = 0.004 if on else _base_fog_density
	sun.light_color = Color(1.0, 0.6, 0.45) if on else _base_sun


## Ambiance plus sombre dans les donjons.
func set_dungeon_mood(on: bool) -> void:
	env.fog_light_color = Color(0.35, 0.28, 0.42) if on else _base_fog
	env.fog_density = 0.01 if on else _base_fog_density
	env.ambient_light_energy = 0.45 if on else 0.75
	sun.light_energy = 0.35 if on else 1.25
	# hors de la grotte : du noir plutôt que le ciel
	env.background_mode = Environment.BG_COLOR if on else Environment.BG_SKY
	env.background_color = Color(0.03, 0.02, 0.04)
