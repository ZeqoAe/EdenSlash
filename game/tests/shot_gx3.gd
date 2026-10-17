extends Node
## Captures du lot GX-3 (fiche d'objet v2, sac : cadenas, « neuf », pastilles, démontage en masse ; objectifs ; « Le meilleur ▲N » ;
## poupée ▲ ; Atelier ★ Objectif ; Registre « Monte ton niveau de héros »). Résolution : GX3_RES=1280x720 (défaut 1600x900).
## Images : user://shots/gx3_<résolution>_*.png ; une ligne « [débord] » par contrôle visible qui sort de l'écran.
## godot --path game res://tests/shot_gx3.tscn   (APPDATA détourné : rien n'est gardé chez le joueur)

var res := Vector2i(1600, 900)
var lobby: Node


func _shot(name: String, root: Node = null) -> void:
	await get_tree().create_timer(0.6).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/gx3_%dx%d_%s.png" % [res.x, res.y, name])
	if root != null:
		_overflow(name, root)


## Contrôles visibles qui sortent de l'écran (hors défilement).
func _overflow(name: String, root: Node) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size.x < 2.0:
			continue
		var p := c.get_parent()
		var in_scroll := false
		while p != null:
			if p is ScrollContainer:
				in_scroll = true
				break
			p = p.get_parent()
		if in_scroll:
			continue
		var r := c.get_global_rect()
		if r.end.x > view.end.x + 1.0 or r.end.y > view.end.y + 1.0 or r.position.x < -1.0 or r.position.y < -1.0:
			print("[débord] %s : %s %s %s" % [name, c.get_class(), String(c.get("text")) if c.get("text") != null else c.name, r])


## Pièce d'Eden de l'emplacement [param slot] (arme : du type [param wtype]) au niveau le plus proche de [param lv] sans le dépasser.
func _piece(slot: String, lv: int, wtype := "", rarity := -1) -> Dictionary:
	var best: Dictionary = {}
	for e in GameData.eden_by_slot.get(wtype if slot == "weapon" else slot, []):
		if GameData.is_awakened(e) or int(e.level) > lv or ((e.get("r", {}) as Dictionary).is_empty() and not e.has("passive")):
			continue
		if best.is_empty() or int(e.level) > int(best.level):
			best = e
	var it := Items.from_template(best, int(best.level), int(best.rarity) if rarity < 0 else rarity)
	it["upgrade"] = 0
	return it


func _ready() -> void:
	var env := OS.get_environment("GX3_RES")
	if env.contains("x"):
		res = Vector2i(int(env.get_slice("x", 0)), int(env.get_slice("x", 1)))
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	HeroLevel.ensure()
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(53) + 1.0
	Profile.records["epochs_cleared"] = 1
	Profile.unlocked_features = ["dungeons", "forge", "armory", "chests"]
	Profile.best_level = 80
	var w := Items.default_weapon_type("warrior")
	Profile.install_gear({"weapon": _piece("weapon", 45, w), "head": _piece("head", 40), "chest": _piece("chest", 44), "legs": _piece("legs", 42),
		"gloves": _piece("gloves", 38), "boots": _piece("boots", 41), "ring": _piece("ring", 40), "necklace": _piece("necklace", 40)})
	Profile._sync_vault()
	var better := _piece("chest", 53, "", Items.MYTHIC)
	var high := _piece("head", 70)
	var kept := _piece("legs", 50, "", Items.LEGENDARY)
	kept["locked"] = true
	var fresh := _piece("gloves", 52, "", Items.MYTHIC)
	fresh["new"] = true
	var fresh2 := _piece("back", 50)
	fresh2["new"] = true
	for it in [better, high, kept, fresh, fresh2, _piece("boots", 30), _piece("head", 28), _piece("ring", 30), _piece("legs", 30), _piece("chest", 31)]:
		Profile.vault.append(it)
	Profile._lobby_view()
	# objectifs : un plan du palier II-2 pas encore trouvé (épinglé), un plan connu
	var pool := GearShopPage.tier_pool(2, 2, "head", w)
	var target := int(pool[0].id) if not pool.is_empty() else 0
	var known := GearShopPage.tier_pool(1, 3, "boots", w)
	Profile.seen_gear = [int(known[0].id)] if not known.is_empty() else []
	Profile.insignia = 140
	Profile.materials["crystal"] = 120
	Profile.plans = ["plan_limestone"]
	Profile.records["dungeon_limestone_0"] = 2
	if not known.is_empty():
		Goals.follow(Goals.piece_id(int(known[0].id)))
	if target > 0:
		Goals.follow(Goals.piece_id(target))
	Profile.save_profile()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = res
	await get_tree().process_frame
	await get_tree().process_frame
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._open_hero("equipment")
	var hero: HeroScreen = lobby._hero
	var page: InventoryPage = hero.page
	await _shot("1_equipement", hero)
	page._select({"kind": "item", "item": better})
	page._preview_stats(better)
	await _shot("2_fiche_meilleure", hero)
	page._select({"kind": "item", "item": kept})
	await _shot("3_fiche_gardee", hero)
	page._select({"kind": "item", "item": high})
	await _shot("4_fiche_trop_haute", hero)
	page._select({})
	page._chip = "useless"
	page._refresh_grid()
	await _shot("5_inutiles", hero)
	page._chip = "new"
	page._refresh_grid()
	await _shot("6_nouveautes", hero)
	page._chip = ""
	page._refresh_grid()
	page.preset_bar._open_best()
	await _shot("7_le_meilleur", hero)
	for c in page.preset_bar.get_children():
		if c is InfoCard.Ask:
			c.queue_free()
	# infobulles v2 posées à plat (courte, complète, niveau trop haut)
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.85, 0.9, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var box := HBoxContainer.new()
	box.position = Vector2(20, 20)
	box.add_theme_constant_override("separation", 20)
	layer.add_child(box)
	box.add_child(ItemWidgets.item_card(better, "", 0))
	box.add_child(ItemWidgets.item_card(high, "", 0))
	await _shot("8_infobulles")
	for c in box.get_children():
		c.queue_free()
	box.add_child(ItemWidgets.item_card(better, "", 1))
	await _shot("9_infobulle_complete")
	layer.queue_free()
	hero.close_ui()
	# Atelier : objectif en tête, ★ Objectif, filtre « ★ Objectifs », Plans de donjon
	lobby._workshop.open(0)
	var shop: GearShopPage = lobby._workshop.page(0)
	shop.refresh()
	if target > 0:
		shop.show_goal(Goals.piece_id(target))
	await _shot("a_fabriquer_objectif", lobby._workshop)
	shop.set_view("catalog")
	shop._f_status.select(GearShopPage.STATUSES.size() - 1)
	shop._apply()
	await _shot("b_catalogue_objectifs", lobby._workshop)
	shop.set_view("tiers")
	lobby._workshop.open(1)
	await _shot("c_plans_de_donjon", lobby._workshop)
	lobby._workshop.close_ui()
	# Registre : « Monte ton niveau de héros »
	lobby._open_registry()
	await _shot("d_registre", lobby._archive)
	get_tree().quit()
