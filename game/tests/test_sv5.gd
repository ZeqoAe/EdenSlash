extends Node
## Lot S5 du Survivant (interface en run) : rendu de toutes les cartes sur 200 états de run tirés au hasard (aucune
## carte vide, aucune carte qui déborde de son cadre à 1280 × 720, en-tête court, jamais « Eden », virgule décimale),
## fiches de découverte à la 1re rencontre (une fois), manette (cadre sur la 1re carte, croix, LB relance, RB passe),
## page Build de la pause (emplacements verrouillés : un clic ne retire rien), HUD (frise, niveau des sorts) :
## godot --headless --path game res://tests/test_sv5.tscn   (SV5_STATES=N : nombre d'états, 200 par défaut)

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1280, 720)  # sans fenêtre, la fenêtre de test fait 64 px (R_P13)
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
	SurvivorCards.seed_with(55)
	await _tips_and_pad()
	await _render_states()
	await _build_page()
	await _world()
	print("test_sv5 : %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _texts(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	elif n is RichTextLabel:
		out += (n as RichTextLabel).get_parsed_text() + "\n"
	elif n is Button:
		out += (n as Button).text + "\n"
	for c in n.get_children():
		out += _texts(c)
	return out


func _settle() -> void:
	for i in 4:
		await get_tree().process_frame


# --- fiches de découverte et manette ------------------------------------------------------------------------------
func _tips_and_pad() -> void:
	Survivor.start("warrior", "limestone")
	var picker := CardPicker.new()
	add_child(picker)
	picker.offer("Choisis ton arme ou ta première compétence", SurvivorCards.first_offer(), func(): return SurvivorCards.first_offer())
	await _settle()
	check("fiche « 1re carte » au premier choix", picker.tip_id == "sv_first" and picker._tip.visible)
	picker._opened_at -= CardPicker.CONFIRM_DELAY_MS
	picker._choose(picker._cards.find_custom(func(c): return String(c.type) == "sv_weapon") if picker._cards.any(func(c): return String(c.type) == "sv_weapon") else 0)
	if Profile.equipped.get("weapon", {}).is_empty():
		Run.apply_card(SurvivorCards.weapon_card())
	Run.hero_level = 5
	picker.offer("Niveau 5 ! Choisis une carte", [SurvivorCards.new_piece_card("chest"), SurvivorCards.new_piece_card("head")], func(): return Run.roll_cards(3))
	await _settle()
	check("fiche « pièce à vie » à la 1re pièce proposée", picker.tip_id == "sv_locked")
	picker._queue.clear()
	picker._show_next()
	picker.offer("Niveau 6 ! Choisis une carte", [SurvivorCards.new_piece_card("legs")], func(): return Run.roll_cards(3))
	await _settle()
	check("une fiche vue ne revient pas", picker.tip_id == "" and not picker._tip.visible)
	picker._queue.clear()
	picker._show_next()
	# manette : cadre sur la 1re carte, croix droite, LB relance, RB passe
	Gamepad._set_active(true)
	Run.apply_card(SurvivorCards.new_piece_card("head"))
	Run.apply_card(SurvivorCards.spell_card(int(Run.class_data().skills[0].id)))
	picker.offer("Niveau 7 ! Choisis une carte", Run.roll_cards(3), func(): return Run.roll_cards(3))
	await _settle()
	await _settle()
	check("manette : cadre doré sur la 1re carte", UiNav.cursor == picker._buttons[0])
	check("manette : LB / RB écrits sur Relancer / Passer", picker._reroll.text.begins_with(Settings.pad_name(JOY_BUTTON_LEFT_SHOULDER)) and picker._skip.text.begins_with(Settings.pad_name(JOY_BUTTON_RIGHT_SHOULDER)))
	await _tap(JOY_BUTTON_DPAD_RIGHT)
	check("manette : croix droite -> 2e carte", UiNav.cursor == picker._buttons[1])
	var used := Run.rerolls_used
	await _tap(JOY_BUTTON_LEFT_SHOULDER)
	check("manette : LB relance (relances %d -> %d)" % [used, Run.rerolls_used], Run.rerolls_used == used + 1 and picker.is_open())
	picker._opened_at -= CardPicker.CONFIRM_DELAY_MS
	var g0 := Profile.gold
	await _tap(JOY_BUTTON_RIGHT_SHOULDER)
	check("manette : RB passe (or %d -> %d)" % [g0, Profile.gold], not picker.is_open() and Profile.gold > g0)
	Gamepad._set_active(false)
	picker.queue_free()
	Run.finish("abandon")
	Profile.end_run_survival()


func _pad(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)


func _tap(button: JoyButton) -> void:
	_pad(button, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_pad(button, false)
	await get_tree().process_frame


# --- 200 états : chaque carte se rend et tient dans son cadre ------------------------------------------------------
func _render_states() -> void:
	var n := int(OS.get_environment("SV5_STATES")) if OS.get_environment("SV5_STATES") != "" else 200
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var picker := CardPicker.new()
	add_child(picker)
	var cards_seen := 0
	var empty: Array = []
	var overflow: Array = []
	var bad_text: Array = []
	var long_head: Array = []
	var types := {}
	var classes := ["warrior", "magician", "ranger", "cleric", "thief"]
	for i in n:
		Profile.tutorial["seen"] = ["sv_first", "sv_locked", "sv_tier"]
		Survivor.start(String(classes[i % classes.size()]), "limestone")
		SurvivorCards.minutes_override = rng.randf_range(0.0, 20.0)
		var steps := rng.randi_range(0, 60)
		for s in steps:
			Run.hero_level = 1 + s
			var opts := Run.roll_cards(3)
			if opts.is_empty():
				break
			Run.apply_card(SurvivorCards.auto_pick(opts, true))
		var offer: Array
		match i % 4:
			0, 1:
				offer = Run.roll_cards(3)
			2:
				offer = SurvivorCards.chest_cards(["sv_head", "sv_weapon", "sv_spell", "sv_gold", "sv_guardian", "sv_anvil", "sv_ring"][rng.randi() % 7])
			_:
				offer = SurvivorCards.first_offer() if steps == 0 else Run.roll_cards(3)
		if offer.is_empty():
			Run.finish("abandon")
			Profile.end_run_survival()
			continue
		picker.offer("Niveau %d ! Choisis une carte" % Run.hero_level, offer, func(): return Run.roll_cards(3))
		await _settle()
		var cap := picker.card_cap()
		for k in picker._buttons.size():
			var b: Button = picker._buttons[k]
			var c: Dictionary = picker._cards[k]
			cards_seen += 1
			types[String(c.type)] = int(types.get(String(c.type), 0)) + 1
			var content: Control = b.get_meta("content")
			var need := content.get_combined_minimum_size().y + 36.0 + CardPicker.FOOT_H - 18.0
			if content.get_child_count() < 3:
				empty.append(String(c.type))
			if need > cap + 0.5:
				overflow.append("%s (%d > %d) %s" % [String(c.type), roundi(need), roundi(cap), String(c.get("title", ""))])
			var txt := _texts(b)
			if "Eden" in txt or RegEx.create_from_string("\\d\\.\\d+ ?%").search(txt) != null:
				bad_text.append("%s : %s" % [String(c.type), txt.substr(0, 80)])
			var head := SurvivorCardView.header(c)
			if head == "" or head.length() > 30:
				long_head.append(head)
		picker._queue.clear()
		picker._show_next()
		Run.finish("abandon")
		Profile.end_run_survival()
	SurvivorCards.minutes_override = -1.0
	print("[sv5] %d cartes rendues sur %d états : %s" % [cards_seen, n, str(types)])
	check("cartes rendues : %d, toutes les familles vues (%s)" % [cards_seen, str(types.keys())], cards_seen >= n * 2
		and ["sv_weapon", "sv_piece", "sv_piece_up", "sv_weapon_up", "upgrade"].all(func(t): return types.has(t)) and (types.has("skill") or types.has("chain")))
	check("aucune carte vide %s" % str(empty.slice(0, 5)), empty.is_empty())
	check("aucune carte ne déborde de son cadre à 1280 × 720 (%d) %s" % [overflow.size(), str(overflow.slice(0, 5))], overflow.is_empty())
	check("textes : ni « Eden » ni point décimal %s" % str(bad_text.slice(0, 3)), bad_text.is_empty())
	check("en-têtes courts (30 signes) %s" % str(long_head.slice(0, 5)), long_head.is_empty())
	picker.queue_free()


# --- page Build : état riche, verrou ---------------------------------------------------------------------------------
func _build_page() -> void:
	Survivor.start("warrior", "limestone")
	SurvivorCards.seed_with(9)
	preload("res://tests/shot_sv5.gd").rich_state()
	var page := SurvivorBuildPage.new()
	page.size = Vector2(1240, 600)
	add_child(page)
	page.refresh()
	await _settle()
	var txt := _texts(page)
	check("Build : équipement %d / 9, sorts, passifs et sets affichés" % SurvivorGear.worn().size(),
		txt.contains("Équipement  %d / 9" % SurvivorGear.worn().size()) and txt.contains("Sorts  ") and txt.contains("Niv. ") and page._passives.get_child_count() > 0 and page._sets.get_child_count() > 0)
	check("Build : tient en largeur à 1280 (%d px)" % roundi(page.get_combined_minimum_size().x), page.get_combined_minimum_size().x <= 1240.0)
	var before := str(Profile.equipped.keys()) + str(Profile.equipped.get("head", {}).get("uid", ""))
	var tiles: Array = page._grid.get_children().filter(func(t): return t is SurvivorBuildPage.SlotTile and not t.item.is_empty())
	check("Build : cases des pièces portées (%d)" % tiles.size(), tiles.size() >= 5)
	if not tiles.is_empty():
		tiles[0].pressed.emit()
	check("Build : un clic ne retire rien, message sobre (« %s »)" % page._note.text, page._note.text.contains("ne se retire pas")
		and before == str(Profile.equipped.keys()) + str(Profile.equipped.get("head", {}).get("uid", "")))
	Profile.unequip("head")
	check("verrou : Profile.unequip refusé (la pièce reste)", Profile.equipped.has("head"))
	check("verrou : la carte de la pièce s'ouvre au survol", tiles.is_empty() or tiles[0]._make_custom_tooltip("") != null)
	page.queue_free()
	Run.finish("abandon")
	Profile.end_run_survival()


# --- en jeu : pause (Build en premier), HUD (frise, niveau des sorts) ---------------------------------------------------
func _world() -> void:
	Profile.reset_all()
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": [], "version": Version.NUMBER}
	Survivor.start("warrior", "limestone")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(1.5, true, false, true).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	Run.apply_card(SurvivorCards.weapon_card())
	Run.apply_card(SurvivorCards.spell_card(int(Run.class_data().skills[0].id)))
	for i in 3:
		Run.apply_card(SurvivorCards.spell_up_card(int(Run.skills[0].id), "rare"))
	await _settle()
	check("HUD : frise du Survivant posée", world.hud._sv_hud != null and world.hud._sv_hud.is_visible_in_tree())
	check("HUD : niveau du sort en chiffre (%d)" % world.hud._slots[0].level_badge, world.hud._slots[0].level_badge == Run.skill_rank(int(Run.skills[0].id)) and world.hud._slots[0].level_badge == 4)
	world.director.time = 296.0
	check("HUD : gardien annoncé (rouge sur la frise)", world.hud._sv_hud.guardian_state(0) == 1 and world.hud._sv_hud.guardian_state(1) == 0)
	world.pause_menu.open()
	await _settle()
	var sc: PageScreen = world.pause_menu._screen
	check("pause : page Build en premier, pas d'inventaire (%d pages)" % sc.page_count(), sc.page_count() == 2 and sc.page(0) is SurvivorBuildPage and sc.current_page() == 0)
	check("pause : Build atteignable à la manette (cases et Reprendre)", sc.page(0).find_children("*", "Button", true, false).size() >= 10)
	world.pause_menu.close()
	world.queue_free()
	await _settle()
	Run.finish("abandon")
	Profile.end_run_survival()
	get_tree().paused = false
