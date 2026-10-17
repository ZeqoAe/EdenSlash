extends Node
## Captures du HUD de L'Assaut (lot TAC-7) et de la mort / du bilan (lot TAC-8), en 1280 × 720 puis 1600 × 900 :
## 1 manche en cours (score, minuteur, Charge portée, cases achetées et ultime, utilitaires, bouclier, radar, repère),
## 2 Charge posée et désamorçage adverse, 3 joueur tombé (récapitulatif, spectateur), 4 ordres, 5 carte de fin de manche,
## 6 bilan de partie (frise, tableau des 8, Meilleur héros), 7 page du lobby. Fichiers user://shots/tac7_<largeur>_*.png.
## APPDATA détourné : godot --path game res://tests/shot_tac7.tscn [-- manche,pose,mort,ordres,fin,bilan,page]

const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900)]

var world: Node
var dd: AssaultDirector
var only: Array = []


func _shot(name: String, wait := 0.5) -> void:
	await get_tree().create_timer(wait, true).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	var w := get_window().size.x
	get_viewport().get_texture().get_image().save_png("user://shots/tac7_%d_%s.png" % [w, name])
	print("[shot] tac7_%d_%s" % [w, name])


func _want(part: String) -> bool:
	return only.is_empty() or part in only


## Une capture par taille d'écran.
func _both(name: String, wait := 0.5) -> void:
	for res in SIZES:
		get_window().size = res
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot(name, wait)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			only = Array(a.split(","))
	Settings.reset_all()
	Profile.reset_all()
	Settings.set_v("interface", "dev_mode", true)
	Profile.selected_class = "warrior"
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1600, 900)
	await get_tree().process_frame
	if _want("page"):
		await _page()
	Assault.launch("warrior", {"map": "bourg", "seed": 12, "first_attack": 0, "buy_time": 4.0, "buy_time_first": 4.0,
		"diff_allies": 2, "diff_foes": 0, "round_time": 600.0})
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	for _i in 3600:
		await get_tree().process_frame
		if world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team) \
				and world.director.map != null and world.director.map._region.navigation_mesh != null:
			break
	dd = world.director.team
	await get_tree().create_timer(0.5).timeout
	# achat : de l'or, l'achat conseillé (sort 2, armure, utilitaires, fiole), puis l'écran se ferme
	Assault.give("t0_0", 3000)
	dd.shop_advised()
	dd._close_shop()
	dd.ult_pts["t0_0"] = 5
	for _i in 600:
		await get_tree().process_frame
		if Assault.phase == "live":
			break
	await get_tree().create_timer(1.0).timeout
	var p: Player = world.player
	p.set_meta("assault_shield", p.max_hp * 0.4)
	if _want("manche"):
		var hud: Hud = world.hud
		var ah: AssaultHud = hud.get("_assault")
		ah.place_ping(dd._ground(p.global_position + Vector3(6, 0, -10)))
		hud.show_message("2 contre 4 !", 2.0)
		await _both("1_manche", 0.3)
	if _want("pose"):
		dd.charge_pos = dd._ground(dd.site_pos("A"))
		p.global_position = dd.charge_pos + Vector3(3, 0.5, 2)
		dd.carrier = ""
		dd._handle(Assault.plant("A", "t0_0"))
		var df := dd.hero("t1_1") as ClassRival
		if df != null:
			df.passive = true
			df.global_position = dd.charge_pos + Vector3(0.8, 0.4, 0)
		dd.defuse_by = "t1_1"
		dd.defuse_t = 4.4
		await get_tree().process_frame
		get_tree().paused = true  # (le désamorçage reste à 4,4 s le temps des captures)
		await _both("2_pose", 0.3)
		get_tree().paused = false
		dd._stop_defuse()
		dd.defuse_t = 0.0
		if df != null:
			df.global_position = dd._ground(dd.site_pos("B")) + Vector3.UP * 0.4
	if _want("mort") or _want("ordres"):
		var foe := dd.hero("t1_0")
		p.set_meta("assault_shield", 0.0)
		p.hp = 1.0
		p.take_damage(500.0, foe, false, true)
		await get_tree().create_timer(1.2).timeout
		if _want("mort"):
			await _both("3_mort", 0.3)
		var ah: AssaultHud = world.hud.get("_assault")
		if ah.recap != null:
			ah.recap.card.visible = false
			ah.recap.toggle_orders(1)
			if _want("ordres"):
				await _both("4_ordres", 0.3)
			ah.recap.give("go_b")
			await get_tree().create_timer(0.3).timeout
			if _want("ordres"):
				await _both("4b_ordres_reponses", 0.2)
	if _want("fin"):
		dd._handle(Assault.end_round(0, "defuse"))
		await _both("5_fin_manche", 0.4)
	if _want("bilan"):
		_fake_history()
		Assault.winner = 0
		dd._finish()
		await get_tree().create_timer(2.5, true).timeout
		await _both("6_bilan", 2.0)
	get_tree().paused = false
	if TeamMatch.active:
		TeamMatch.abandon()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()


## Une partie déjà bien avancée pour la frise et le tableau : 11 manches, mi-temps, K.O. et dégâts répartis.
func _fake_history() -> void:
	Assault.history = []
	var hows := ["elim", "charge", "elim", "defuse", "time", "elim", "charge", "elim", "defuse", "elim", "charge"]
	var wins := [0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0]
	for i in hows.size():
		Assault.history.append({"n": i + 1, "winner": wins[i], "how": hows[i], "attack": 0 if i < 6 else 1, "time": 60.0, "planted": "",
			"half": 1 if i < 6 else 2})
	Assault.score = [7, 4]
	Assault.round_n = hows.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in Assault.stats:
		var s: Dictionary = Assault.stats[k]
		s.kills = rng.randi_range(2, 12)
		s.deaths = rng.randi_range(3, 9)
		s.assists = rng.randi_range(0, 8)
		s.plants = rng.randi_range(0, 3)
		s.defuses = rng.randi_range(0, 2)
		s.gold = rng.randi_range(12000, 26000)
		dd.dmg_total[k] = rng.randf_range(3000.0, 14000.0)


## Page du lobby (mode dev : l'activité est montrée).
func _page() -> void:
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.5).timeout
	lobby._show_menu("play")
	await _both("7a_jouer", 0.8)
	lobby._show_menu("assault")
	await _both("7_page", 0.8)
	lobby._scroll.scroll_vertical = 600
	await _both("7b_page_bas", 0.4)
	lobby.queue_free()
	await get_tree().process_frame
