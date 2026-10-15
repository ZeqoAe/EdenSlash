extends Node
## Captures de l'Atelier (Armurerie, Fabrication, Forge) : compte neuf puis compte avancé (user://shots/atelier_*.png).
## godot --path game res://tests/shot_atelier.tscn   (APPDATA détourné : le test ne sauvegarde rien chez le joueur)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.7).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/atelier_%s.png" % name)


func _tabs(lobby: Node, prefix: String) -> void:
	for i in 3:
		lobby._workshop.open(i)
		await _shot("%s_%d" % [prefix, i])


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	await _tabs(lobby, "neuf")
	# compte avancé : pièces découvertes (certaines achetées), insignes, plans, cristaux, pièces et fournitures de forge
	var ids: Array = []
	for ep in [1, 2, 3]:
		for box in ["head", "chest", "legs", "jewel"]:
			for e in SlotChests.pool(box, ep, 2).slice(0, 4):
				ids.append(int(e.id))
	Profile.seen_gear = ids
	Profile.insignia = 300
	Profile.plans = ["plan_limestone", "plan_rainbowfall", "plan_delphi"]
	Profile.records["dungeon_limestone_0"] = 2
	Profile.records["dungeon_rainbowfall_1"] = 1
	Profile.materials["crystal"] = 420
	var items: Array = [Items.generate(40, 1.0, "weapon", "samurai", 1, "", 3), Items.generate(40, 1.0, "chest", "samurai", 2, "", 3), Items.generate(30, 1.0, "head", "samurai", 1, "", 2)]
	items[0]["upgrade"] = 3
	items[1]["upgrade"] = 5
	Profile.inventory = items
	for id in ids.slice(0, 5):
		Profile.add_item(GearShopPage.make(GameData.eden_by_id[int(id)]))  # déjà achetées
	Profile.stash = {Craft.fortify_key("power", 40): 4, Craft.fortify_key("guard", 40): 4, "stone:safety": 2, "stone:lucky": 1, Craft.gem_key("ruby", 0): 5, Craft.gem_key("ruby", 1): 1, "drill": 2}
	lobby._workshop.open(0)
	lobby._workshop.page(0)._f_status.select(3)  # Toutes : disponibles, possédées et silhouettes
	lobby._workshop.page(0)._apply()
	await _shot("avance_0_toutes")
	lobby._workshop.page(0)._f_status.select(0)
	lobby._workshop.page(0)._apply()
	await _shot("avance_0")
	lobby._workshop.page(0)._f_status.select(2)
	lobby._workshop.page(0)._apply()
	await _shot("avance_0_adecouvrir")
	lobby._workshop.open(1)
	await _shot("avance_1")
	lobby._workshop.open(2)
	await _shot("avance_2_vide")
	var forge = lobby._workshop.page(2)
	forge.grid.select_item(items[0])
	for b in ["upgrade", "enchant", "gems", "polish", "reforge", "dismantle"]:
		forge.bench = b
		forge._on_selection()
		await _shot("avance_2_%s" % b)
	forge.bench = "upgrade"
	forge._on_selection()
	await get_tree().create_timer(0.3).timeout
	for btn in forge._pinned.get_children():
		if btn is Button and not btn.disabled:
			btn.pressed.emit()
			break
	await get_tree().create_timer(2.0).timeout
	await _shot("avance_2_verdict")
	get_tree().quit()
