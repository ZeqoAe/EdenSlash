extends Node
## Captures du lot GX-2 (Atelier) : Fabriquer par paliers, catalogue, Plans de donjon, Forge (persévérance, viser +N,
## verdict, réajuster au choix). Résolution : GX2_RES=1280x720 (défaut 1600x900). Images : user://shots/gx2_<résolution>_*.png ;
## une ligne « [débord] » par contrôle visible qui sort de l'écran.
## godot --path game res://tests/shot_gx2.tscn   (APPDATA détourné : rien n'est gardé chez le joueur)

var res := Vector2i(1600, 900)
var lobby: Node


func _shot(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/gx2_%dx%d_%s.png" % [res.x, res.y, name])
	_overflow(name)


## Contrôles visibles de l'Atelier qui sortent de l'écran.
func _overflow(name: String) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	for n in lobby._workshop.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size.x < 2.0 or c.get_parent() is ScrollContainer:
			continue
		var in_scroll := false
		var p := c.get_parent()
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


func _ready() -> void:
	var env := OS.get_environment("GX2_RES")
	if env.contains("x"):
		res = Vector2i(int(env.get_slice("x", 0)), int(env.get_slice("x", 1)))
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	HeroLevel.ensure()
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(53) + 1.0
	Profile.records["epochs_cleared"] = 1
	var wt := Items.default_weapon_type("warrior")
	# compte avancé : plans des paliers I et II-2 (quelques-uns fabriqués), insignes, plans de donjon, cristaux
	var ids: Array = []
	for t in [[1, 1], [1, 2], [1, 3], [2, 2]]:
		for slot in GearShopPage.KIT_SLOTS:
			var pool := GearShopPage.tier_pool(t[0], t[1], slot, wt)
			if not pool.is_empty() and (t != [2, 2] or slot in ["weapon", "head", "chest", "legs", "gloves", "boots"]):
				ids.append(int(pool[0].id))
	Profile.seen_gear = ids
	Profile.insignia = 303
	Profile.plans = ["plan_limestone", "plan_rainbowfall", "plan_delphi"]
	Profile.records["dungeon_limestone_0"] = 2
	Profile.records["dungeon_rainbowfall_1"] = 1
	Profile.unlocked_features = ["dungeons", "forge"]
	Profile.materials["crystal"] = 420
	for id in ids.slice(0, 13):
		Profile.add_item(GearShopPage.make(GameData.eden_by_id[int(id)]))
	for id in ids.slice(18, 22):
		Profile.add_item(GearShopPage.make(GameData.eden_by_id[int(id)]))
	var weapon := Items.generate(53, 1.0, "weapon", "warrior", Items.LEGENDARY, "", Items.LEGENDARY)
	weapon["upgrade"] = 5
	weapon["up_rolls"] = [["patk", 3.5, 4]]
	weapon["pity"] = 0.3
	weapon["pity_n"] = 1
	var chest := Items.generate(53, 1.0, "chest", "warrior", Items.MYTHIC, "", Items.MYTHIC)
	chest["upgrade"] = 6
	chest["up_rolls"] = [["hp", 25.0, 4], ["def", 2.4, 6]]
	Profile.add_item(weapon)
	Profile.add_item(chest)
	Profile.stash = {Craft.fortify_key("power", 60): 12, Craft.fortify_key("guard", 60): 6, "stone:safety": 2, "stone:lucky": 1, Craft.gem_key("ruby", 0): 5, "drill": 2}
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = res
	await get_tree().process_frame
	await get_tree().process_frame
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._workshop.open(0)
	var shop: GearShopPage = lobby._workshop.page(0)
	shop._tier = Vector2i(2, 2)
	shop._show_tier()
	await _shot("1_paliers")
	var locked := shop._kit.filter(func(k): return k.state == "locked")
	if not locked.is_empty():
		shop._select(int(locked[0].e.id))
		await _shot("2_plan_a_trouver")
	shop._tier = Vector2i(1, 2)
	shop._show_tier()
	await _shot("3_palier_I2")
	shop.set_view("catalog")
	await _shot("4_catalogue")
	shop.set_view("tiers")
	lobby._workshop.open(1)
	await _shot("5_plans_de_donjon")
	lobby._workshop.open(2)
	var forge = lobby._workshop.page(2)
	forge.grid.select_item(weapon)
	forge.bench = "upgrade"
	forge._on_selection()
	await _shot("6_forge_ameliorer")
	ForgeBench.fast = true
	for b in forge.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Fortifier jusqu'à") and not (b as Button).disabled:
			(b as Button).pressed.emit()
			break
	await get_tree().create_timer(0.4).timeout
	await _shot("7_forge_enchainer")
	forge.grid.select_item(chest)
	forge.bench = "reforge"
	forge._on_selection()
	await get_tree().process_frame
	Forge.reforge(chest, "def")
	forge._on_selection()
	await _shot("8_reajuster_choix")
	ForgeBench.fast = false
	get_tree().quit()
