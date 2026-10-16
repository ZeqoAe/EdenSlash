extends Node
## Passe M8 : captures des écrans de la Tour, de la Ruée, du Siège et des Donjons dans une taille de fenêtre donnée
## (user://shots/m8_<taille>_*.png) : pages Tour (difficulté, étages), fiches d'étage (monstres, ombre, maudit, boss),
## pages Ruée / Siège / Donjons (haut et bas), HUD de la Tour (élites, boss), bilans de la Tour, de la Ruée, d'un
## donjon et du Siège.
##   M8_RES=1280x720 godot --path game res://tests/shot_m8.tscn   (APPDATA détourné : rien n'est sauvegardé chez le joueur)
## La taille est posée APRÈS Settings.reset_all() (qui remet la résolution des paramètres, 1600 × 900 par défaut).

var _world: Node
var _tag := "1600x900"


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://shots/m8_%s_%s.png" % [_tag, name])
	print("[m8] capture %s %dx%d" % [name, img.get_width(), img.get_height()])


func _first(t: String, kind := "") -> int:
	for f in range(1, Tower.FLOORS + 1):
		if Tower.floor_type(f) == t and (kind == "" or Tower.shadow_kind(f) == kind):
			return f
	return 1


func _size() -> void:
	var wh := _tag.split("x")
	Settings.set_v("display", "resolution", _tag)
	get_window().size = Vector2i(int(wh[0]), int(wh[1]))


func _profile() -> void:
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.records["epochs_cleared"] = 4
	Profile.records["boss_wetlands"] = 1
	Profile.records["boss_avila"] = 1
	Profile.records[Tower.record_key(1)] = 23
	Profile.records["rush_seed"] = 4821
	Profile.unlocked_features.append_array(["dungeons", "siege", "tower", "rush"])
	Profile.install_gear(StarterGear.scenario("3.3.10.4", "warrior"))


func _ready() -> void:
	if OS.get_environment("M8_RES") != "":
		_tag = OS.get_environment("M8_RES")  # (pas d'argument « -- » : le lobby lancerait une run)
	Training.active = true
	Settings.reset_all()
	_size()
	_profile()
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.5).timeout
	_size()
	# --- la Tour ---
	lobby._show_menu("tower")
	await _shot("tour")
	lobby._scroll.scroll_vertical = 600
	await _shot("tour_bas")
	lobby._tower_diff = 1
	lobby._tower_sel = 24
	lobby._tower_page = 4
	lobby._show_menu("tower_floors")
	lobby._scroll.scroll_vertical = 0
	await _shot("tour_etages")
	lobby._scroll.scroll_vertical = 600
	await _shot("tour_etages_bas")
	for f in [2, _first("shadow"), _first("cursed"), 10]:
		var sheet: CanvasLayer = TowerPages.info_popup(lobby._sub, Tower.spec(f, 1))
		await _shot("fiche_%d_%s" % [f, Tower.floor_type(f)], 0.9)
		sheet.queue_free()
	# --- Ruée, Siège, Donjons ---
	lobby._dg_diff = 0
	lobby._show_menu("rush")
	lobby._scroll.scroll_vertical = 0
	await _shot("ruee")
	lobby._scroll.scroll_vertical = 600
	await _shot("ruee_bas")
	lobby._dg_zone = "wetlands"
	lobby._show_menu("siege")
	lobby._scroll.scroll_vertical = 0
	await _shot("siege")
	lobby._scroll.scroll_vertical = 600
	await _shot("siege_bas")
	DungeonPage.sel = "latif"
	lobby._show_menu("dungeon")
	lobby._scroll.scroll_vertical = 0
	await _shot("donjon")
	lobby._scroll.scroll_vertical = 600
	await _shot("donjon_bas")
	lobby.queue_free()
	Training.active = false
	await get_tree().create_timer(0.5).timeout
	# --- la Tour en jeu : HUD d'un étage d'élites et d'un boss, puis le bilan ---
	_profile()
	Tower.start("warrior", 1, 1)
	var world := await _launch()
	var td: TowerDirector = world.director.tower
	td.begin(5)
	await _shot("hud_tour_elites", 6.0)
	td.begin(10)
	await _shot("hud_tour_boss", 6.0)
	Tower.reached = 12
	world.tower_end("defaite")
	await _shot("bilan_tour", 3.0)
	world.queue_free()
	await get_tree().create_timer(1.0).timeout
	# --- Ruée : HUD puis bilan ---
	_profile()
	Tower.start_dungeon("warrior", Dungeons.RUSH, 0, ["cleric"])
	world = await _launch()
	await _shot("hud_ruee", 5.0)
	Tower.reached = 3
	world.tower_end("defaite")
	await _shot("bilan_ruee", 3.0)
	world.queue_free()
	await get_tree().create_timer(1.0).timeout
	# --- un donjon : bilan de victoire ---
	_profile()
	Tower.start_dungeon("warrior", "avila", 0, [], "latif")
	world = await _launch()
	Tower.reached = Tower.top()
	world.tower_end("victoire")
	await _shot("bilan_donjon", 3.0)
	world.queue_free()
	await get_tree().create_timer(1.0).timeout
	# --- Siège : bilan ---
	_profile()
	Tower.start_siege("warrior", "wetlands", 0, ["cleric", "knight"])
	world = await _launch()
	await _shot("hud_siege", 5.0)
	var sd: SiegeDirector = world.director.tower
	sd._finish("won", "VICTOIRE ! Dernier debout")
	await _shot("bilan_siege", 4.5)
	get_tree().quit()


func _launch() -> Node:
	var world: Node = load("res://scenes/world.tscn").instantiate()
	_world = world
	get_tree().root.add_child.call_deferred(world)
	await _wait(func(): return world.is_inside_tree() and world.director != null and world.director.tower != null and world.player != null, 40.0)
	_size()
	world.player.dev_invincible = true
	await _wait(func(): return world.cards.is_open(), 5.0)
	world.cards._queue.clear()
	world.cards._show_next()
	return world


func _wait(cond: Callable, secs := 10.0) -> void:
	var t := 0.0
	while t < secs and not cond.call():
		t += get_physics_process_delta_time()
		if is_instance_valid(_world) and _world.get("cards") != null and _world.cards.is_open():
			_world.cards._choose(0)
		await get_tree().physics_frame
