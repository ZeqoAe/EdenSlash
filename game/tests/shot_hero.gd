extends Node
## Captures de l'écran Héros : Équipement (vide, pièces, comparaison, préréglages), Classe (trois
## sous-onglets), Apparence, Cartes, Grimoire (user://shots/hero_*.png).
## godot --path game res://tests/shot_hero.tscn   (APPDATA détourné : le test ne sauvegarde rien)


func _shot(name: String) -> void:
	await get_tree().create_timer(0.7).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/hero_%s.png" % name)


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(HeroLevel.MAX_LEVEL)  # lot H3 : niveau 90, toutes les pièces se portent
	Profile.selected_class = "warrior"
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	var hero: HeroScreen = lobby._hero
	# --- équipement : compte neuf, puis une panoplie et des pièces à comparer
	lobby._open_hero("equipment")
	await _shot("1_equipement_neuf")
	var worn: Array = []
	for slot in ["head", "chest", "legs", "boots", "gloves", "back", "necklace", "ring"]:
		var it := Items.generate(30, 0.6, slot, "warrior")
		Profile.inventory.append(it)
		Profile.equip(it)
		worn.append(it)
	var better := Items.generate(45, 0.95, "chest", "warrior", Items.MYTHIC, "", Items.MYTHIC)
	var worse := Items.generate(10, 0.1, "head", "warrior")
	for k in 3:
		Profile.inventory.append(Items.generate(32 + k * 4, 0.7, "gloves", "warrior"))
	Profile.inventory.append(better)
	Profile.inventory.append(worse)
	Profile.save_profile()
	hero.refresh()
	await _shot("2_equipement_porte")
	hero.page._select({"kind": "item", "item": better})
	await _shot("3_comparaison_meilleure")
	hero.page._select({"kind": "item", "item": worse})
	await _shot("4_comparaison_moins_bonne")
	hero.page._select({"kind": "item", "item": worn[0]})
	await _shot("5_piece_portee")
	# préréglages : le menu « Gérer »
	hero.page._select({})
	hero.page.preset_bar._open_menu()
	await _shot("6_gerer")
	hero.page.preset_bar._pop.hide()
	hero.page.preset_bar.changed.emit("Équipement copié vers « Préréglage 2 ».")
	await _shot("7_message")
	# --- classe
	for sub in ["spells", "talents", "certs"]:
		hero.show_section("class")
		hero.talents.show_sub(sub)
		await _shot("8_classe_%s" % sub)
	# --- apparence
	for cat in ["body", "head", "aura", "weapon"]:
		hero.appearance._cat = cat
		hero.appearance._slot = cat
		hero.show_section("appearance")
		await _shot("9_apparence_%s" % cat)
	hero.appearance._cat = "body"
	hero.appearance._owned_only.button_pressed = false
	hero.show_section("appearance")
	await _shot("9_apparence_tout")
	# --- cartes, aide, grimoire
	hero.show_section("cards")
	await _shot("a_cartes")
	hero._open_guide()
	await _shot("b_aide")
	Guide.close_in(lobby)
	hero.show_section("class")
	hero.grimoire.open("warrior", int(GameData.class_data("warrior").skills[3].id))
	await _shot("c_grimoire")
	hero.grimoire.close_ui()
	# sélecteur de classe
	hero._test_class_menu()
	await _shot("d_menu_classes")
	Profile.reset_all()
	get_tree().quit()
