extends Node
## Captures du lot GX-4 : Forge « Tout monter à +5 » (rangée, confirmation, séance en cours, verdict), gemmes lisibles,
## Héros (5 préréglages, « Gérer » : copier / comparer / noms d'usage / tenue liée, comparaison), panoplie, Fabriquer
## (recherche). Résolution : GX4_RES=1280x720 (défaut 1600x900). Images : user://shots/gx4_<résolution>_*.png ; une
## ligne « [débord] » par contrôle visible qui sort de l'écran.
## godot --path game res://tests/shot_gx4.tscn   (APPDATA détourné : rien n'est gardé chez le joueur)

var res := Vector2i(1600, 900)
var lobby: Node


func _shot(name: String, root: Node = null) -> void:
	await get_tree().create_timer(0.6).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/gx4_%dx%d_%s.png" % [res.x, res.y, name])
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


## Pièce d'Eden de l'emplacement [param slot] (arme : du type [param wtype]) au niveau le plus proche de [param lv].
func _piece(slot: String, lv: int, up: int, wtype := "", rarity := -1) -> Dictionary:
	var best: Dictionary = {}
	for e in GameData.eden_by_slot.get(wtype if slot == "weapon" else slot, []):
		if GameData.is_awakened(e) or int(e.level) > lv or ((e.get("r", {}) as Dictionary).is_empty() and not e.has("passive")):
			continue
		if best.is_empty() or int(e.level) > int(best.level):
			best = e
	var it := Items.from_template(best, int(best.level), int(best.rarity) if rarity < 0 else rarity)
	it["upgrade"] = up
	return it


func _ask() -> Node:
	for c in get_tree().root.find_children("*", "", true, false):
		if c is InfoCard.Ask and not c.is_queued_for_deletion():
			return c
	return null


func _close_ask() -> void:
	var a := _ask()
	if a:
		a.queue_free()
	await get_tree().process_frame


func _ready() -> void:
	var env := OS.get_environment("GX4_RES")
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
	var gear := {"weapon": _piece("weapon", 50, 5, w), "head": _piece("head", 48, 2), "chest": _piece("chest", 50, 6), "legs": _piece("legs", 47, 1),
		"gloves": _piece("gloves", 46, 3), "boots": _piece("boots", 48, 0), "back": _piece("back", 45, 2), "ring": _piece("ring", 46, 4), "necklace": _piece("necklace", 44, 1)}
	gear.chest["sockets"] = [{"type": "garnet", "tier": 2}, null]
	Profile.install_gear(gear)
	Profile._sync_vault()
	for it in [_piece("head", 52, 0), _piece("boots", 40, 3), _piece("ring", 30, 0)]:
		Profile.vault.append(it)
	Profile._lobby_view()
	Profile.rename_preset("warrior", 0, "Survie")
	Profile.rename_preset("warrior", 2, "Donjons")
	Profile.copy_active_preset("warrior", 2)
	Profile.presets.warrior.sets[2].slots["head"] = Profile.vault[-3].uid
	Profile.materials["crystal"] = 640
	Profile.insignia = 220
	var seen: Array = []
	for t in [[1, 1], [1, 2], [2, 2]]:
		for slot in GearShopPage.KIT_SLOTS:
			var pool := GearShopPage.tier_pool(t[0], t[1], slot, w)
			if not pool.is_empty():
				seen.append(int(pool[0].id))
	Profile.seen_gear = seen
	var lv := Craft.fortify_level_for(gear.chest)
	Profile.stash = {Craft.fortify_key("power", lv): 14, Craft.fortify_key("guard", lv): 30, "stone:safety": 3, "stone:lucky": 1,
		Craft.gem_key("ruby", 0): 7, Craft.gem_key("garnet", 1): 3, "drill": 2}
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = res
	await get_tree().process_frame
	await get_tree().process_frame
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	# --- Forge : Tout monter à +5 ---
	lobby._workshop.open(2)
	var forge = lobby._workshop.page(2)
	forge.bench = "upgrade"
	forge.grid.clear_selection()
	forge._on_selection()
	await _shot("1_forge_tout_monter", lobby._workshop)
	forge._ask_even()
	await _shot("2_confirmation", _ask())
	await _close_ask()
	forge._even_start(5)
	await get_tree().create_timer(0.5).timeout
	await _shot("3_seance_en_cours", lobby._workshop)
	for _i in 600:
		await get_tree().process_frame
		if not forge._busy:
			break
	await _shot("4_verdict", lobby._workshop)
	# gemmes : la valeur sur la pièce, retirer, tout fusionner
	forge.bench = "gems"
	forge.grid.select_item(Profile.equipped.chest)
	forge._on_selection()
	await _shot("5_gemmes", lobby._workshop)
	# Fabriquer : recherche
	lobby._workshop.open(0)
	var shop: GearShopPage = lobby._workshop.page(0)
	shop.set_view("catalog")
	shop._f_search.text = "casque"
	shop._apply()
	await _shot("6_fabriquer_recherche", lobby._workshop)
	shop._f_search.text = ""
	shop.set_view("tiers")
	lobby._workshop.close_ui()
	# --- Héros : 5 préréglages, Gérer, comparaison, panoplie ---
	lobby._open_hero("equipment")
	var hero: HeroScreen = lobby._hero
	var page: InventoryPage = hero.page
	page.refresh()
	await _shot("7_heros_prereglages", hero)
	page.preset_bar._open_menu()
	await _shot("8_gerer", hero)
	if is_instance_valid(page.preset_bar._pop):
		page.preset_bar._pop.hide()
	page.preset_bar._open_compare(2)
	await _shot("9_comparer", _ask())
	await _close_ask()
	# Grimoire : le préréglage de sorts actif en petites cases
	var cols := SpellPresets.empty_cols()
	var sk: Array = GameData.class_data("warrior").get("skills", [])
	for c in mini(4, sk.size()):
		cols[c][0] = int(sk[c].id)
	if sk.size() > 5:
		cols[0][1] = int(sk[4].id)
	if OS.get_environment("GX4_NOSPELL") == "":
		SpellPresets.store("warrior", "Boss", cols)
	hero.show_section("grimoire")
	await get_tree().process_frame
	hero.grimoire._refresh_presets()
	await get_tree().process_frame
	hero.grimoire._mscroll.scroll_vertical = 5000
	await _shot("a_grimoire", hero.grimoire)
	get_tree().quit()
