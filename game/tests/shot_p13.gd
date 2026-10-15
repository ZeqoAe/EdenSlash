extends Node
## Captures de la passe P13 (conception/nuit_15_10/captures/p13_*.png) : Héros > Apparence avec la Pièce de
## l'Œil de rose écarlate teinte en rouge (et une pièce non teintable), puis un choix de carte ouvert à
## l'entrée dans l'arène du boss, cadre de la manette sur la 1re carte.
## APPDATA détourné conseillé : godot --path game res://tests/shot_p13.tscn

const ROSE := "res://assets/player/outfits/head_l1288.glb"
const PLAIN := "res://assets/player/hairs/l104_aede18.glb"  # sans masque de teinture


func _shot(name: String) -> void:
	await get_tree().create_timer(0.8).timeout
	var dir := ProjectSettings.globalize_path("res://").path_join("../conception/nuit_15_10/captures").simplify_path()
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().get_texture().get_image().save_png(dir.path_join("p13_%s.png" % name))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "hunter"
	for c in GameData.cosmetics:
		if String(c.outfit) == ROSE:
			Profile.unlock_outfit(String(c.id))
	Profile.set_worn("hunter", "head", ROSE)
	Profile.set_dye("hunter", "head", [[220, 30, 40], [150, 10, 20], [255, 90, 90]])
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	var hero: HeroScreen = lobby._hero
	lobby._open_hero("equipment")
	hero.appearance._cat = "head"
	hero.appearance._slot = "head"
	hero.show_section("appearance")
	await _shot("1_rose_rouge")
	Profile.set_worn("hunter", "head", PLAIN)
	hero.appearance.refresh()
	await _shot("2_non_teintable")
	Profile.set_worn("hunter", "head", ROSE)
	lobby.queue_free()
	await get_tree().process_frame
	# en jeu : choix de carte à l'entrée de l'arène, à la manette
	Profile.selected_zone = String(GameData.zones[0].id)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	add_child(world)
	await get_tree().create_timer(6.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	var p: Player = world.player
	var d: RunDirector = world.director
	d.orbs.spawn(p.global_position + Vector3(60, 0, 60), float(GameData.xp_to_next(p.level)) / maxf(p.xp_mult, 0.01) + 5.0)
	Gamepad._set_active(true)
	await ScreenFade.run(get_tree(), d._enter_arena)
	await _shot("3_choix_arene_manette")
	Profile.reset_all()
	get_tree().quit()
