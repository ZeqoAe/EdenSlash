extends Node
## Captures du lot GX-5 : Héros > Classe > Talents (arbre, liens, paliers, points, recherche), Héros > Titres (titre sous le
## nom), Carnet > Registre (fiche dépliée), Coffres (« Ouvrir tout » : confirmation, récapitulatif), Journal > Niveau de
## héros, préréglage sur la page Survie et Donjons, Forge > Reporter (établi et confirmation). Résolution : GX5_RES=1280x720 (défaut 1600x900). Images :
## user://shots/gx5_<résolution>_*.png ; une ligne « [débord] » par contrôle visible qui sort de l'écran.
## godot --path game res://tests/shot_gx5.tscn   (APPDATA détourné : rien n'est gardé chez le joueur)

var res := Vector2i(1600, 900)
var lobby: Node


func _shot(name: String, root: Node = null) -> void:
	await get_tree().create_timer(0.7).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/gx5_%dx%d_%s.png" % [res.x, res.y, name])
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


func _ask() -> Node:
	for c in get_tree().root.find_children("*", "", true, false):
		if c is InfoCard.Ask and not c.is_queued_for_deletion():
			return c
	return null


func _ready() -> void:
	var env := OS.get_environment("GX5_RES")
	if env.contains("x"):
		res = Vector2i(int(env.get_slice("x", 0)), int(env.get_slice("x", 1)))
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.hero_name = "Nico"
	HeroLevel.ensure()
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(53) + 1.0
	HeroLevel.claim_milestones()
	Profile.records["epochs_cleared"] = 1
	Profile.unlocked_features = ["dungeons", "forge", "armory", "chests", "collection"]
	Profile.best_level = 60
	Profile.expertise["warrior"] = 40000
	for id in [52582, 52582, 52582, 52582, 52582, 52582, 52582, 52582, 52582, 52582, 54699, 52583, 52583, 52583, 52583, 52583, 52586, 52586]:
		Profile.add_talent("warrior", id)
	Profile.add_title("Vétéran")
	Profile.achievements["run_50"] = "2026-10-17"
	Profile.title = "Aventurier"
	var it := Items.generate(40, 0.0, "head", "warrior", 3, "", 3)
	Profile.vault.append(it)
	# Reporter : un casque porté à +7 (stats bonus +4 et +6), un casque neuf plus haut dans le coffre
	var old := Items.generate(30, 0.0, "head", "warrior", 4, "", 4)
	old["upgrade"] = 7
	old["up_rolls"] = [["hp", 12.0, 4], ["def", 6.0, 6]]
	var neu := Items.generate(52, 0.0, "head", "warrior", 5, "", 5)
	Profile.install_gear({"head": old})
	Profile.inventory.append(neu)
	Profile._sync_vault()
	Profile.materials["crystal"] = 640
	Profile._lobby_view()
	Profile._class_presets("warrior")
	Profile.rename_preset("warrior", 0, "Survie")
	Profile.presets.warrior.sets[2].slots["head"] = String(it.uid)
	Profile.rename_preset("warrior", 2, "Donjons")
	for f in ["", "", "scroll", "stone"]:
		Profile.reward_chests.append(Rewards.make("forge", 40, false, f))
	Profile.reward_chests.append(Rewards.make("gear", 40))
	Profile.reward_chests.append(Rewards.make("set", 40))
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = res
	await get_tree().process_frame
	await get_tree().process_frame
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	# --- Héros > Classe > Talents ---
	lobby._open_hero("class")
	var hero: HeroScreen = lobby._hero
	hero.talents.show_sub("talents")
	await _shot("1_talents", hero)
	hero.talents._search.text = "défense"
	hero.talents._apply_search()
	await _shot("2_talents_recherche", hero)
	hero.talents._search.text = ""
	hero.talents._apply_search()
	hero.talents.show_sub("spells")
	await _shot("3_classe_sorts_points", hero)
	# --- Héros > Titres ---
	hero.show_section("titles")
	await _shot("4_titres", hero)
	hero.close_ui()
	# --- Carnet > Registre, fiche dépliée ---
	var reg_i := 0
	for i in lobby._archive.page_count():
		if lobby._archive.page(i) is RegistryPage:
			reg_i = i
	lobby._archive.open(reg_i)
	var reg: RegistryPage = lobby._archive.page(reg_i)
	await get_tree().process_frame
	reg.toggle("warrior")
	await _shot("5_registre_fiche", lobby._archive)
	lobby._archive.close_ui()
	# --- Coffres : Ouvrir tout ---
	lobby._chests.open(0)
	var cp: ChestsPage = lobby._chests._pages[0]
	cp.refresh()
	cp.ask_open_all()
	await _shot("6_coffres_confirmation", _ask())
	var a := _ask()
	if a:
		a.ok_button.pressed.emit()
	await get_tree().create_timer(2.6).timeout
	await _shot("7_coffres_recapitulatif", lobby._chests)
	lobby._chests.close_ui()
	# --- Journal > Niveau de héros ---
	var j := QuestJournal.open_on(lobby, QuestJournal.TABS.size() - 1)
	await _shot("8_journal_niveau", j)
	j.close_ui()
	# --- Forge > Reporter ---
	lobby._workshop.open(2)
	var forge = lobby._workshop.page(2)
	forge.bench = "report"
	forge.grid.select_item(neu)
	forge._on_selection()
	await _shot("b_forge_reporter", lobby._workshop)
	var rb: Button = null
	for b in forge.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with("Prendre le"):
			rb = b
	if rb:
		rb.pressed.emit()
		await _shot("c_reporter_confirmation", _ask())
		var aa := _ask()
		if aa:
			aa.queue_free()
	lobby._workshop.close_ui()
	# --- préréglage sur la page d'une activité ---
	lobby._show_menu("survival")
	await _shot("9_survie_prereglage", lobby)
	lobby._show_menu("dungeon")
	await _shot("a_donjons_prereglage", lobby)
	get_tree().quit()
