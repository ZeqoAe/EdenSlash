extends Node
## Captures du lot H3 (port des pièces selon le niveau de héros), 1280 × 720 : inventaire (pièce trop haute choisie,
## refus, pièce portée d'avant le niveau, confirmation pour la retirer), Atelier > Fabriquer (cases rouges, filtre
## « Portables »), coffres. Fichiers user://shots/h3_*.png.
## APPDATA détourné : godot --path game res://tests/shot_h3.tscn


func _shot(name: String) -> void:
	await get_tree().create_timer(0.7).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/h3_%s.png" % name)


## Pièce d'Eden de l'emplacement [param slot] (ou arme du type [param wtype]) au niveau le plus proche de [param lv] sans le dépasser.
func _piece(slot: String, lv: int, wtype := "") -> Dictionary:
	var best: Dictionary = {}
	for e in GameData.eden_by_slot.get(wtype if slot == "weapon" else slot, []):
		if GameData.is_awakened(e) or int(e.level) > lv or ((e.get("r", {}) as Dictionary).is_empty() and not e.has("passive")):
			continue
		if best.is_empty() or int(e.level) > int(best.level):
			best = e
	var it := Items.from_template(best, int(best.level), int(best.rarity))
	it["upgrade"] = 0
	return it


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	HeroLevel.ensure()
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(34)
	var w := Items.default_weapon_type("warrior")
	# compte d'avant le niveau de héros : un torse de niveau 60 déjà porté
	Profile.install_gear({"weapon": _piece("weapon", 33, w), "head": _piece("head", 30), "chest": _piece("chest", 60), "legs": _piece("legs", 33),
		"gloves": _piece("gloves", 28), "boots": _piece("boots", 33), "ring": _piece("ring", 30), "necklace": _piece("necklace", 30)})
	var high := _piece("head", 60)
	Profile._sync_vault()
	for it in [high, _piece("head", 34), _piece("gloves", 45), _piece("boots", 75), _piece("weapon", 70, w), _piece("legs", 20)]:
		Profile.vault.append(it)
	Profile._lobby_view()
	Profile.save_profile()
	# après Settings.reset_all (qui remet la fenêtre) : 1280 × 720
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	await get_tree().process_frame
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._open_hero("equipment")
	await _shot("1_equipement")
	var page: InventoryPage = lobby._hero.page
	var shown := Profile.inventory.filter(func(x): return String(x.uid) == String(high.uid))
	page._select({"kind": "item", "item": shown[0]})
	await _shot("2_piece_trop_haute")
	page._equip(shown[0])
	await _shot("3_refus")
	page._select({"kind": "item", "item": Profile.equipped.chest})
	await _shot("4_portee_avant")
	page._unequip("chest")
	await _shot("5_confirmation")
	for c in page.get_children():
		if c is InfoCard.Ask:
			c.queue_free()
	lobby._hero.hide()
	# Atelier > Fabriquer : plans découverts des époques I à III
	var ids: Array = []
	for ep in [1, 2, 3]:
		for box in ["head", "chest", "legs", "jewel"]:
			for e in SlotChests.pool(box, ep, 2).slice(0, 4):
				ids.append(int(e.id))
	Profile.seen_gear = ids
	Profile.insignia = 900
	lobby._workshop.open(0)
	var shop: GearShopPage = lobby._workshop.page(0)
	shop._f_status.select(0)
	shop._apply()
	var hi_row := shop._rows.filter(func(r): return int(r.level) > 34)
	if not hi_row.is_empty():
		shop._select(int(hi_row[0].id))
	await _shot("6_fabriquer")
	shop._f_status.select(GearShopPage.STATUSES.size() - 1)
	shop._apply()
	await _shot("7_fabriquer_portables")
	get_tree().quit()
