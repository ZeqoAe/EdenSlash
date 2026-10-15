extends Node
## Captures de Coffres et de la Roulette (user://shots/coffres_*.png) : liste variée, coffre à choix, coffres ouverts, roue.
## godot --path game res://tests/shot_chests.tscn   (APPDATA détourné : le test ne sauvegarde rien)


func _shot(name: String, wait := 0.7) -> void:
	await get_tree().create_timer(wait).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/coffres_%s.png" % name)


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.insignia = 380
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._chests.open(0)
	await _shot("vide")
	for t in ["look_legend", "look_epic", "look_rare", "look_common", "set", "gear", "aura_rare"]:
		Profile.reward_chests.append(Rewards.make(t, 40))
	for f in ["", "scroll", "stone"]:
		Profile.reward_chests.append(Rewards.make("forge", 60, false, f))
	Profile.reward_chests.append(Rewards.make("forge", 60, false, "scroll"))
	for f in ["", "gem", "enchant"]:
		Profile.reward_chests.append(Rewards.make("jewel", 60, false, f))
	lobby._chests.open(0)
	await _shot("liste")
	var page: ChestsPage = lobby._chests._pages[0]
	var forge: Dictionary = Profile.reward_chests.filter(func(c): return c.type == "forge" and c.get("focus", "") == "scroll")[0]
	page._preview(forge)
	page.refresh()
	await _shot("forge")
	page.open_chest(forge)
	await _shot("forge_ouvert", 2.2)
	var set: Dictionary = Profile.reward_chests.filter(func(c): return c.type == "set")[0]
	page.open_chest(set)
	await _shot("set_choix", 2.2)
	page.open_many(Profile.reward_chests.filter(func(c): return not Rewards.is_choice(c)))
	await _shot("tout_ouvert", 2.2)
	lobby._chests.open(1)
	await _shot("roulette")
	var wp: WheelPage = lobby._chests._pages[1]
	wp._on_spin(0.85)
	await _shot("roulette_tour", 1.5)
	await _shot("roulette_gain", 4.3)
	await _shot("roulette_apres", 4.0)
	get_tree().quit()
