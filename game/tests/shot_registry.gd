extends Node
## Captures du lot E3 : Registre de l'équipement (compte neuf, compte avancé, filtres), menu « Gérer » de l'écran
## Équipement (Équiper le meilleur, famille, annulation), message, bandeau du lobby (user://shots/e3_*.png).
## godot --path game res://tests/shot_registry.tscn   (APPDATA détourné : rien n'est écrit dans la vraie sauvegarde)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.7).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/e3_%s.png" % name)


func _registry_index(lobby: Node) -> int:
	for i in lobby._archive.page_count():
		if lobby._archive.page(i) is RegistryPage:
			return i
	return 0


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.unlocked_features = ["collection", "chests", "armory"]
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._refresh_ui()
	await _shot("1_lobby_neuf")
	var ri := _registry_index(lobby)
	lobby._archive.open(ri)
	await _shot("2_registre_neuf")
	lobby._archive.close_ui()
	# compte avancé : coffre garni (zone avancée), quelques classes débloquées, Guerrier optimisé
	Items.reward_zone = "wetlands"
	for slot in ["head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]:
		for k in 3:
			Profile.vault.append(Items.generate(40 + k * 5, 0.9, slot, "warrior", 2, "", 4))
	for wt in ["axe", "sword", "rapier", "katana", "staff", "dagger", "bow"]:
		Profile.vault.append(Items.generate(45, 0.9, "weapon", "warrior", 3, wt, 4))
	Items.reward_zone = ""
	Profile.unlocked_classes = ["knight", "berserker", "samurai", "templar"]
	Profile.best_level = 30
	Profile._lobby_view()
	Profile.save_profile()
	lobby._open_hero("equipment")
	await get_tree().create_timer(0.5).timeout
	var hero: HeroScreen = lobby._hero
	hero.page.preset_bar._open_menu()
	await _shot("3_gerer_neuf")
	hero.page.preset_bar._pop.hide()
	hero.page._on_preset_changed(ClassGear.equip_best("warrior"))
	await _shot("4_equipe_le_meilleur")
	hero.page.preset_bar._open_menu()
	await _shot("5_gerer_apres")
	hero.page.preset_bar._pop.hide()
	hero.page._on_preset_changed(ClassGear.apply_family("warrior"))
	await _shot("6_famille")
	for it in Profile.equipped.values().slice(0, 4):
		it["upgrade"] = 10
		it["sockets"] = [{"type": "ruby", "tier": 3}, null]
	Profile.save_profile()
	hero.close_ui()
	lobby._refresh_ui()
	await _shot("7_lobby_avance")
	lobby._archive.open(ri)
	await _shot("8_registre_avance")
	var page: RegistryPage = lobby._archive.page(ri)
	page._filter = 1
	page.refresh()
	await _shot("9_registre_toutes")
	page._filter = 0
	page._profile = "rempart"
	page.refresh()
	await _shot("a_registre_rempart")
	lobby._archive.open(0)
	await _shot("b_vue_ensemble")
	get_tree().quit()
