extends Node
## Captures de la passe M7 (Arènes, Duel, Gantelet) : pages du Duel (Libre, Ligue, Panthéon, Gantelet) en compte neuf et
## avancé, Arènes 2v2 / 3v3, éditeur d'adversaire, file d'attente (recherche, match, draft, récapitulatif), puis en jeu :
## Arène 3v3 (compte à rebours, combat, pause, joueur tombé, entre deux manches, bilan) et Gantelet (combat, bilan).
## godot --path game res://tests/shot_m7.tscn   ->  user://shots/m7_*.png   (M7_RES=1280x720 : petite résolution ;
## M7_PART=lobby | game : une moitié seulement). APPDATA détourné : rien n'est écrit chez le joueur.

var _suffix := ""
var world: Node


func _shot(name: String, wait := 0.9) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/m7_%s%s.png" % [name, _suffix])


func _preset(cid: String) -> void:
	var ids: Array = (GameData.class_data(cid).get("skills", []) as Array).slice(0, 4).map(func(x): return int(x.id))
	SpellPresets.store(cid, "M7", [[ids[0], 0, 0], [ids[1], 0, 0], [ids[2], 0, 0], [ids[3], 0, 0]])


func _lobby() -> Node:
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.5).timeout
	return lobby


func _ready() -> void:
	Settings.reset_all()
	var res := OS.get_environment("M7_RES")
	if res != "":
		Settings.set_v("display", "resolution", res)
		_suffix = "_" + res
	Profile.reset_all()
	Profile.selected_class = "warrior"
	var part := OS.get_environment("M7_PART")
	if part != "game":
		await _lobby_shots()
	if part != "lobby":
		await _game_shots()
	get_tree().paused = false
	get_tree().quit()


func _lobby_shots() -> void:
	# compte neuf : le Duel est verrouillé, la page s'ouvre quand même (onglets grisés)
	var lobby := await _lobby()
	lobby._show_menu("play")
	await _shot("01_jouer_neuf")
	lobby._show_menu("duel")
	await _shot("02_duel_neuf")
	lobby.queue_free()
	await get_tree().process_frame
	# compte avancé : Ligue Or (Arènes et Gantelet ouverts), préréglage rempli
	Profile.records["duel_wins"] = 14
	Profile.records["league_rank"] = 3
	Profile.records["league_streak"] = 1
	Profile.records["arena3_wins"] = 4
	_preset("warrior")
	lobby = await _lobby()
	lobby._show_menu("play")
	await _shot("03_jouer_avance")
	Duel.bare = true
	lobby._duel_tab = "free"
	lobby._show_menu("duel")
	await _shot("04_duel_libre_arme")
	Duel.bare = false
	lobby._show_menu("duel")
	await _shot("05_duel_libre_equipe")
	Duel.bare = true
	lobby._duel_tab = "league"
	lobby._show_menu("duel")
	await _shot("06_ligue")
	lobby._duel_tab = "pantheon"
	lobby._show_menu("duel")
	await _shot("07_pantheon_verrou")
	lobby._duel_tab = "gauntlet"
	lobby._show_menu("duel")
	await _shot("08_gantelet")
	lobby._team_size = 2
	lobby._show_menu("arenas")
	await _shot("09_arenes_2v2")
	lobby._team_size = 3
	lobby._show_menu("arenas")
	await _shot("10_arenes_3v3")
	lobby.queue_free()
	await get_tree().process_frame
	Profile.records["league_rank"] = 4
	lobby = await _lobby()
	lobby._duel_tab = "pantheon"
	lobby._show_menu("duel")
	await _shot("11_pantheon")
	# éditeur d'adversaire
	var b := RivalBuilds.blank("magician", 45)
	RivalBuilds.auto_fill(b)
	ProfileEditor.open(lobby, b, func(_b): pass)
	await _shot("12_editeur", 1.5)
	lobby.queue_free()
	await get_tree().process_frame
	# file d'attente (Ligue)
	for n in get_tree().root.get_children():
		if n is ProfileEditor:
			n.queue_free()
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.14, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	Duel.bare = true
	Duel.mode = "league"
	var q := DuelQueue.open(self, "Ligue", "Duel classé · à l'arme", "cleric", 10, 1, func(): pass)
	await get_tree().create_timer(1.0).timeout
	q._search_total = 99.0
	await _shot("13_file_recherche")
	q._enter(DuelQueue.Phase.FOUND)
	q._opp_accept_at = 0.1
	await _shot("14_file_match")
	q.accept()
	await get_tree().create_timer(0.3).timeout
	q._opp_lock_at = 999.0
	await _shot("15_file_draft")
	q.lock_in()
	q._enter(DuelQueue.Phase.RECAP)
	await _shot("16_file_recap")
	q._finish("fin")
	bg.queue_free()
	await get_tree().process_frame


func _game_shots() -> void:
	_preset("warrior")
	Profile.records["league_rank"] = 3
	# Arène 3 contre 3
	Duel.mode = "arena3"
	Duel.bare = true
	Duel.team_allies = ["cleric", "ranger"]
	Duel.extra_foes = ["magician", "assassin"]
	Duel.pilot = ""
	Duel.hazards = true
	Duel.start("warrior", "knight", 2)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	while not (world.get("director") != null and world.director.get("duel") != null):
		await get_tree().create_timer(0.3).timeout
	await _shot("20_arene_decompte", 1.2)
	world.player.autoplay = true
	await _shot("21_arene_combat", 13.8)  # 3 s de décompte + 10 s : première zone de feu annoncée
	world.pause_menu.open()
	await _shot("22_arene_pause")
	world.pause_menu.close()
	# (lot HUD-2) la pause doit être refermée avant les captures suivantes : sinon le HUD reste caché sous elle
	await get_tree().process_frame
	if world.pause_menu.is_open():
		world.pause_menu.close()
	get_tree().paused = false
	await get_tree().process_frame
	print("[m7] pause refermée : %s, HUD visible : %s" % [not world.pause_menu.is_open(), world.hud._root.visible])
	var dd: DuelDirector = world.director.duel
	world.player.take_damage(1e9, null, false)
	await _shot("23_arene_joueur_tombe", 1.5)
	for f in dd._foes:
		if is_instance_valid(f) and not f.is_dead:
			f.take_damage(1e12, null, false)
	await _shot("24_arene_manche", 0.8)
	world.duel_end(true)
	await _shot("25_arene_bilan", 2.5)
	get_tree().paused = false
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	# Gantelet 1 contre 3 (équipé)
	Profile.reset_all()
	Profile.selected_class = "warrior"
	_preset("warrior")
	Duel.mode = "gauntlet"
	Duel.team_allies = []
	Duel.extra_foes = ["hunter", "berserker"]
	Duel.start("warrior", "cleric", 2)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	while not (world.get("director") != null and world.director.get("duel") != null):
		await get_tree().create_timer(0.3).timeout
	world.player.autoplay = true
	await _shot("30_gantelet_combat", 6.0)
	world.pause_menu.abandon_requested.emit()  # abandon : le bilan dit « Abandon »
	await _shot("31_gantelet_bilan", 2.5)
