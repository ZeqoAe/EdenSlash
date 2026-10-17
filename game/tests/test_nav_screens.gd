extends Node
## Chaque écran est-il entièrement atteignable à la manette ? (croix directionnelle seulement)
## godot --headless --path game res://tests/test_nav_screens.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


## Part du premier candidat et explore en déplaçant le curseur ; renvoie [atteints, total].
func reach() -> Array:
	var all: Array = UiNav.candidates()
	if all.is_empty():
		return [0, 0]
	UiNav.cursor = null
	UiNav._last_center = Vector2.ZERO
	UiNav.pick_default()
	var seen := {UiNav.cursor: true}
	var todo: Array = [UiNav.cursor]
	while not todo.is_empty():
		var c: Control = todo.pop_back()
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			UiNav.cursor = c
			if UiNav.move(d) and not seen.has(UiNav.cursor):
				seen[UiNav.cursor] = true
				todo.append(UiNav.cursor)
	return [seen.size(), all.size()]


## Appui sur B (Rond) : ferme la carte du dessus.
func back_event() -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_B
	e.pressed = true
	return e


func probe(label: String, min_ratio := 0.9) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var r := reach()
	var ok: bool = r[1] > 0 and float(r[0]) / float(r[1]) >= min_ratio
	check("%s : %d / %d contrôles atteignables" % [label, r[0], r[1]], ok)


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Gamepad.active = true
	get_tree().root.size = Vector2i(1600, 900)
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.5).timeout
	await probe("lobby : menu de gauche")
	# lot HUB-1 : la boussole est la bulle « Ta quête » ; _compass est son bouton « Y aller »
	check("lobby : la boussole montre un conseil cliquable", lobby._compass.is_visible_in_tree() and lobby._compass.text != "" and not lobby._compass_go.is_empty())
	check("lobby : la boussole est un contrôle atteignable à la manette", UiNav.candidates().has(lobby._compass))
	# P10 : l'option « Afficher la boussole d'objectif » (activée par défaut) la masque aussitôt
	check("réglage « boussole » activé par défaut", Settings.show_compass())
	Settings.set_v("interface", "compass", false)
	check("boussole masquée par le réglage, et plus un contrôle de navigation", not lobby._compass.is_visible_in_tree() and not UiNav.candidates().has(lobby._compass))
	Settings.set_v("interface", "compass", true)
	check("boussole de retour quand le réglage est remis", lobby._compass.is_visible_in_tree() and lobby._compass.text != "")
	# P8 : petites cartes d'information : au-dessus de tout, navigables, B les ferme sans perdre le cadre
	var prev_ctl: Control = lobby._menu["play"]
	UiNav.cursor = prev_ctl
	lobby._show_news(Tutorial.news_sorted(["trophy", "chain", "cards", "dungeons", "hub_gear"]))
	await get_tree().create_timer(0.6).timeout
	var stack: InfoCard = lobby.info_cards()
	check("cartes : 3 nouveautés puis « Tout voir dans le Guide », la plus récente d'abord", stack.ids() == ["hub_gear", "dungeons", "cards", "news_more"])
	check("cartes : le cadre de la manette part sur le bouton principal de la carte du dessus", UiNav.cursor == stack.primary_button())
	check("cartes : le calque des cartes est au-dessus de tout", UiNav.layer_of(stack.primary_button()) == InfoCard.LAYER)
	await probe("lobby : pile de cartes (boutons, croix)")
	UiNav.cursor = stack.primary_button()
	stack._input(back_event())
	await get_tree().create_timer(0.5).timeout
	check("cartes : B ferme la carte du dessus et le cadre passe à la suivante", stack.ids() == ["dungeons", "cards", "news_more"] and UiNav.cursor == stack.primary_button())
	for i in 3:
		stack._input(back_event())
		await get_tree().create_timer(0.5).timeout
	check("cartes : B ferme tout, le cadre revient où il était", stack.count() == 0 and UiNav.cursor == prev_ctl)
	lobby.info_cards().add_card({"id": "x", "title": "Essai", "body": "Un texte court."})
	await get_tree().create_timer(0.5).timeout
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	stack._input(esc)
	await get_tree().create_timer(0.5).timeout
	check("cartes : Échap ferme aussi la carte", stack.count() == 0)
	var hit := [false]
	var ask := InfoCard.ask(lobby, "Quitter ?", "Texte de confirmation.", "Quitter", func(): hit[0] = true)
	await get_tree().create_timer(0.5).timeout
	check("confirmation : le cadre part sur « Annuler » (choix prudent)", UiNav.cursor == ask.cancel_button)
	await probe("lobby : petite confirmation")
	UiNav.cursor = ask.cancel_button
	ask._input(back_event())
	await get_tree().create_timer(0.4).timeout
	check("confirmation : B annule sans rien faire et rend le cadre", not hit[0] and not is_instance_valid(ask) and UiNav.cursor == prev_ctl)
	ask = InfoCard.ask(lobby, "Quitter ?", "Texte de confirmation.", "Quitter", func(): hit[0] = true)
	await get_tree().create_timer(0.3).timeout
	ask.ok_button.pressed.emit()
	await get_tree().create_timer(0.4).timeout
	check("confirmation : le bouton principal valide", hit[0])
	lobby._compass_open(lobby._compass_go)
	await probe("lobby : page ouverte par la boussole")
	lobby._show_menu("")
	lobby._on_menu("play")
	await probe("lobby : Jouer")
	lobby._show_menu("survival")
	await probe("lobby : Survie")
	lobby._show_menu("survivor")
	await probe("lobby : Survivant (zones, Lancer)")
	Profile.records["sv_rewards"] = {"wins": {"1": 1, "2": 1}}  # lot S8 : paliers I à III ouverts, IV et V grisés
	lobby._sv_palier = 0
	lobby._show_menu("survivor")
	await probe("lobby : Survivant (sélecteur de palier)")
	Profile.records.erase("sv_rewards")
	lobby._show_menu("duel")
	await probe("lobby : Duel")
	lobby._show_menu("")
	lobby._chests.open(0)
	await probe("Coffres")
	lobby._chests.open(1)
	await probe("Roulette (cases, liste des gains, boutons)")
	lobby._chests.open(0)
	var chests_page: ChestsPage = lobby._chests._pages[0]
	for t in ["gear", "look_rare"]:
		Profile.reward_chests.append(Rewards.make(t, 40))
	Profile.reward_chests.append(Rewards.make("forge", 60, false, "scroll"))
	chests_page.refresh()
	await probe("Coffres : liste variée, pastilles et Ouvrir tout")
	Profile.reward_chests.clear()
	lobby._chests.close_ui()
	lobby._archive.open(0)
	await probe("Carnet : vue d'ensemble")
	lobby._archive.show_page(1)
	await probe("Carnet : succès", 0.8)
	var subs := {}
	for i in lobby._archive.page_count():
		lobby._archive.show_page(i)
		subs[lobby._archive._subtitle.text] = true
		if i >= 2:
			await probe("Carnet : onglet %d" % i, 0.8)
	check("Carnet : un sous-titre différent par onglet", subs.size() == lobby._archive.page_count() and not subs.has(""))
	lobby._archive.show_page(2)
	CarnetPages.open_hero(lobby._archive.page(2), "cards")
	check("Carnet > Cartes : le lien ouvre Héros > Cartes", lobby._hero.is_open() and not lobby._archive.is_open())
	lobby._hero.close_ui()
	# Registre de l'équipement (lot E3) : filtres et lignes de classe ; une ligne ouvre Héros > Équipement
	var reg_i := 0
	for i in lobby._archive.page_count():
		if lobby._archive.page(i) is RegistryPage:
			reg_i = i
	lobby._archive.open(reg_i)
	await probe("Carnet : Registre de l'équipement", 0.8)
	lobby._archive.page(reg_i)._open_class(Profile.selected_class)
	check("Registre : une classe ouvre Héros > Équipement", lobby._hero.is_open() and not lobby._archive.is_open())
	lobby._hero.close_ui()
	lobby._archive.open(0)
	lobby._archive.close_ui()
	lobby._workshop.open(0)
	await probe("Atelier : Armurerie", 0.8)
	Profile.seen_gear = SlotChests.pool("head", 1, 1).slice(0, 4).map(func(e): return int(e.id))
	lobby._workshop.page(0).refresh()
	await probe("Atelier : Armurerie avec des pièces découvertes (filtres, pages, achat)", 0.8)
	# lot GX-3 : objectif épinglé (barre en tête des paliers, « ★ Objectif » dans la fiche)
	Goals.follow(Goals.piece_id(int(Profile.seen_gear[0])))
	lobby._workshop.page(0).refresh()
	await probe("Atelier : Fabriquer avec un objectif (barre d'objectif, ★ Objectif)", 0.8)
	Profile.seen_gear = []
	lobby._workshop.show_page(1)
	await probe("Atelier : Fabrication", 0.8)
	lobby._workshop.show_page(2)
	await probe("Atelier : Forge (établis)", 0.8)
	var forge_items: Array = Profile.all_items()
	if not forge_items.is_empty():
		lobby._workshop.page(2).grid.select_item(forge_items[0])
		await probe("Atelier : Forge avec une pièce choisie", 0.8)
	lobby._workshop.close_ui()
	lobby._show_menu("rush")
	await probe("lobby : Ruée des boss", 0.8)
	lobby._show_menu("royale")
	await probe("lobby : Battle royale", 0.8)
	lobby._show_menu("autochess")
	await probe("lobby : L'Échiquier (difficultés, graine, Lancer)", 0.8)
	# lot HUB-1 : les quêtes sont le Journal (écran à onglets) ; « quests » l'ouvre
	Profile.unlocked_features.append("daily")
	lobby._show_menu("quests")
	await probe("Journal : Aujourd'hui (épingles, Y aller, relance, Défi du jour)", 0.8)
	for i in range(1, lobby._journal.page_count()):
		lobby._journal.show_page(i)
		await probe("Journal : onglet %d" % i, 0.8)
	lobby._journal.close_ui()
	lobby._refresh_ui()
	await probe("lobby : Aujourd'hui et la bulle « Ta quête » (quêtes ouvertes)")
	lobby._show_menu("siege")
	await probe("lobby : Le Siège", 0.8)
	lobby._show_menu("dungeon")
	await probe("lobby : Donjons", 0.8)
	lobby._show_menu("tower")
	await probe("lobby : Tour, difficulté", 0.8)
	lobby._show_menu("tower_floors")
	await probe("lobby : Tour, étages", 0.8)
	lobby._show_menu("")
	lobby._open_hero("equipment")
	await probe("Héros : équipement", 0.8)
	lobby._hero.page._select({"kind": "item", "item": Profile.equipped.values()[0]})
	await probe("Héros : équipement, fiche d'objet ouverte", 0.8)
	lobby._hero.page.preset_bar._open_menu()
	await probe("Héros : menu « Gérer » des préréglages", 0.8)
	lobby._hero.page.preset_bar._pop.hide()
	# lot GX-3 : barre d'objectif, pastilles du sac (« Inutiles » : démontage en masse), « Le meilleur ▲N »
	lobby._hero.page.refresh()
	await probe("Héros : équipement avec l'objectif épinglé", 0.8)
	lobby._hero.page._chip = "useless"
	lobby._hero.page._refresh_grid()
	await probe("Héros : pastille « Inutiles »", 0.8)
	lobby._hero.page._chip = ""
	lobby._hero.page._refresh_grid()
	if not EquipmentPage.PresetBar.best_plan(Profile.selected_class).is_empty():
		lobby._hero.page.preset_bar._open_best()
		await probe("Héros : aperçu « Le meilleur » (Annuler, Appliquer)", 0.8)
		for c in lobby._hero.page.preset_bar.get_children():
			if c is InfoCard.Ask:
				c._finish(false)
		await get_tree().process_frame
	lobby._open_hero("class")
	await probe("Héros : classe, sorts", 0.8)
	lobby._hero.talents.show_sub("talents")
	await probe("Héros : classe, talents", 0.8)
	lobby._hero.talents.show_sub("certs")
	await probe("Héros : classe, certificats", 0.8)
	lobby._hero.talents.show_sub("spells")
	lobby._hero.show_section("appearance")
	await probe("Héros : apparence", 0.8)
	lobby._hero.show_section("cards")
	await probe("Héros : cartes", 0.8)
	lobby._hero.close_ui()
	lobby._settings.open()
	for t in lobby._settings._pages.size():
		lobby._settings.show_page(t)
		await probe("Paramètres : page %d (%s)" % [t, lobby._settings._tab_buttons[t].text], 0.95)
	# lot BR-I3 : la section « Accessibilité » (Voir les sons, couleurs pour daltoniens, vibration en combat) est atteignable
	var acc_rows := 0
	for l in lobby._settings.find_children("*", "Label", true, false):
		if (l as Label).text in ["Voir les sons", "Couleurs pour daltoniens", "Vibration en combat"]:
			acc_rows += 1
	check("Paramètres : section Accessibilité (%d réglages)" % acc_rows, acc_rows == 3)
	# Touches : un saut de groupe à la croix gauche (de la touche au bouton de son groupe) et retour
	lobby._settings.show_page(2)
	await get_tree().process_frame
	await get_tree().process_frame
	var first_key: Button = null
	for c in UiNav.candidates():
		if c is Button and c.has_meta("nav_left"):
			first_key = c
			break
	check("Paramètres > Touches : un bouton de touche mène à son groupe", first_key != null)
	if first_key != null:
		UiNav.cursor = first_key
		check("croix gauche : saute au groupe", UiNav.move(Vector2.LEFT) and UiNav.cursor == first_key.get_meta("nav_left"))
		check("croix droite : revient à la première touche du groupe", UiNav.move(Vector2.RIGHT) and UiNav.cursor.has_meta("nav_left"))
	# interrupteurs à glissière : valider bascule le réglage et la sauvegarde le garde
	lobby._settings.show_page(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var sw: UiTheme.Switch = null
	for c in UiNav.candidates():
		if c is UiTheme.Switch:
			sw = c
			break
	check("Paramètres > Combat : des interrupteurs navigables", sw != null)
	if sw != null:
		var before := sw.button_pressed
		UiNav.cursor = sw
		UiNav.shown = true
		UiNav.activate()
		await get_tree().process_frame
		await get_tree().process_frame
		check("A sur un interrupteur : il bascule", sw.button_pressed != before)
	lobby._settings.close()
	# barre d'aide et cadre doré
	UiNav.shown = false
	await get_tree().process_frame
	check("cadre doré caché tant qu'aucune croix n'a bougé", not UiNav._frame.visible)
	UiNav.reveal()
	await get_tree().process_frame
	check("reveal() montre le cadre", UiNav.shown and UiNav._frame.visible)
	var labels: Array = UiNav.hint_items().map(func(it): return it[1])
	check("barre d'aide : Valider · Retour (+ Onglets si l'écran en a)", labels.slice(0, 2) == ["Valider", "Retour"] and labels.size() <= 3)
	Gamepad.active = false
	await get_tree().process_frame
	check("souris : barre d'aide et cadre cachés", not UiNav._bar.visible and not UiNav._frame.visible and not UiNav.shown)
	Gamepad.active = true
	var w := Welcome.new()
	lobby.add_child(w)
	await probe("accueil : 3 départs")
	w._step_class()
	await probe("accueil : classes")
	w._step_controls()
	await probe("accueil : contrôles")
	w.queue_free()
	var hc := HeroCreator.open_on(lobby, true)
	await probe("création de personnage (nom, coiffure, couleurs, Valider)")
	hc.close_ui()
	var g := Guide.open_on(lobby, "commands")
	await probe("Guide")
	g.close()
	lobby.queue_free()
	await get_tree().process_frame
	# lot AC-G : l'Échiquier (premier héros ; préparation : cases, boutique, boutons, traits, stratèges)
	AutochessScreen.config = {"seed": 3, "save_path": "", "fast": true}
	var ac: AutochessScreen = load("res://scenes/autochess.tscn").instantiate()
	add_child(ac)
	await get_tree().create_timer(0.8).timeout
	await probe("Échiquier : premier héros (4 cartes, Voir le plateau)", 0.95)
	ac.choice.chosen.emit(0)
	await probe("Échiquier : préparation (cases, boutique, boutons, stratèges)", 0.95)
	ac.game.abandon(0)  # lot AC-I : le bilan de fin (Rejouer, Statistiques, Retour au lobby)
	ac._show_end()
	await get_tree().create_timer(ResultsPanel.LOCK_SECS + 0.3).timeout
	await probe("Échiquier : bilan de fin", 0.95)
	get_tree().paused = false
	ac.queue_free()
	AutochessScreen.config = {}
	await get_tree().process_frame
	# en run : choix de cartes, menu pause
	Run.start_survival("warrior", 1)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	await probe("run : choix de l'arme au départ", 0.9)
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.5).timeout
	world.pause_menu.open()
	await probe("pause : Run", 0.8)
	world.pause_menu._screen.show_page(1)
	await probe("pause : Héros", 0.7)
	world.pause_menu._screen.show_page(0)
	world.pause_menu._run.quit_requested.emit()
	await probe("pause : confirmation de « Quitter le jeu »", 0.9)
	world.pause_menu._confirm.hide_now()
	world.pause_menu.close()
	# lot S5 : Survivant, page Build de la pause (cases des pièces, Reprendre) et choix de cartes (cartes, Bannir, Garder, Relancer)
	Survivor.active = true
	var sv_layer := CanvasLayer.new()
	sv_layer.layer = 30
	world.add_child(sv_layer)
	var sv_page := SurvivorBuildPage.new()
	sv_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	sv_layer.add_child(sv_page)
	sv_page.refresh()
	await probe("Survivant : page Équipement", 0.9)
	sv_layer.queue_free()
	var sv_pick := SurvivorPicker.new()  # (choix de carte v2 : cartes, panneau, barre Relancer / Bannir / Garder / Passer, lot SVX-2)
	world.add_child(sv_pick)
	sv_pick.offer("Choisis ton arme ou ta première compétence", SurvivorCards.first_offer(), func(): return SurvivorCards.first_offer())
	await get_tree().create_timer(0.5, true).timeout
	await probe("Survivant : choix de cartes", 0.9)
	sv_pick._queue.clear()
	sv_pick._show_next()
	sv_pick.queue_free()
	Survivor.active = false
	get_tree().paused = false
	# P8 : la fiche de découverte en jeu est une petite carte sous le HUD ; L3 la ferme, R3 ouvre le Guide
	var hud: Hud = world.hud
	hud._show_card("results")
	await get_tree().create_timer(0.7).timeout
	var crect := UiNav.rect_of(hud._cards.primary_button())
	check("en jeu : une petite carte à droite, dans la fenêtre", hud._cards.count() == 1 and get_viewport().get_visible_rect().encloses(crect) and crect.position.x > 1100.0)
	check("en jeu : boutons Compris, Guide (R3) et Plus de conseils", hud._cards.buttons().size() == 3 and (hud._cards.buttons()[1] as Button).text == "Guide")
	var l3 := InputEventJoypadButton.new()
	l3.button_index = JOY_BUTTON_LEFT_STICK
	l3.pressed = true
	check("en jeu : L3 ferme la carte", hud._pad_card_input(l3))
	await get_tree().create_timer(0.5).timeout
	check("en jeu : carte fermée", hud._cards.count() == 0)
	var r := ResultsScreen.new()
	world.add_child(r)
	Run.result = "victoire"
	r.show_results()
	await get_tree().create_timer(ResultsPanel.LOCK_SECS + 0.3, true).timeout  # les boutons du bilan se dégèlent
	await probe("bilan de Survie", 0.9)
	r.queue_free()
	get_tree().paused = false
	# lot S6 : le bilan du Survivant (Rejouer, Changer de classe, Menu principal ; blocs v2 du lot SVX-2)
	Run.survivor = true
	SurvivorRewards.last = {"res": "victoire", "tier": 1, "time": 1260.0, "guardians": 3, "boss": true, "kills": 800, "title": "Survivant", "new_title": true,
		"chests": [{"id": "win", "type": "look_epic", "text": "Vaincre le boss", "kind": "first"}], "build": SurvivorRewards.build()}
	var rsv := ResultsScreen.new()
	world.add_child(rsv)
	rsv.show_results()
	await get_tree().create_timer(ResultsPanel.LOCK_SECS + 0.3, true).timeout
	await probe("bilan : Survivant", 0.9)
	rsv.queue_free()
	Run.survivor = false
	SurvivorRewards.reset()
	get_tree().paused = false
	for mode in ["duel", "tour", "donjon", "royale"]:
		var b: ResultsPanel
		match mode:
			"duel":
				b = DuelResults.new()
				world.add_child(b)
				b.show_results(true, "2 - 1", "thief", 2, 5)
			"tour":
				b = TowerResults.new()
				world.add_child(b)
				b.show_results("defaite", 14, {"best": 14, "new_record": true, "xp": 130, "levels": 1, "items": 2, "crystals": 15, "chests": [Rewards.make("forge", 30, true, "scroll")], "looks": 0})
			"donjon":
				b = DungeonResults.new()
				world.add_child(b)
				b.show_results({"victory": true, "zone": "limestone", "diff": 1, "rooms": 4, "xp": 90, "reward": {"chests": [Rewards.make("set", 30, true)], "crystals": 90}})
			_:
				b = RoyaleResults.new()
				world.add_child(b)
				b.show_results(3, 2, 7, 6, 171.0, {"text": ["+90 insignes (place 3)"]})
		await get_tree().create_timer(ResultsPanel.LOCK_SECS + 0.3, true).timeout
		await probe("bilan : %s" % mode, 0.9)
		b.queue_free()
		get_tree().paused = false
	var fp := FortunePopup.open(world, 10, 10, Callable())
	await probe("autel de la fortune", 0.7)
	fp.queue_free()
	# P18 : marchand en run et file d'attente du Duel (match trouvé, draft), absents jusque-là (R_P4 §6)
	world.merchant_ui.open()
	await get_tree().create_timer(0.4, true).timeout
	await probe("marchand en run", 0.9)
	world.merchant_ui.close_ui()
	get_tree().paused = false
	var dq := DuelQueue.open(self, "Duel", "", "thief", 10, 1, Callable())
	DuelQueue.speed = 0.0  # (décomptes figés : l'écran reste le temps de la sonde ; variable de classe, remise après)
	await get_tree().process_frame
	dq._enter(DuelQueue.Phase.FOUND)
	await probe("file du Duel : match trouvé", 0.9)
	dq.me_accepted = true
	dq._enter(DuelQueue.Phase.DRAFT)
	await get_tree().create_timer(0.3, true).timeout
	await probe("file du Duel : draft", 0.8)
	dq._finish("test")
	DuelQueue.speed = 1.0
	await get_tree().process_frame
	# lot BR3 : fiche d'équipement d'un héros du Battle royale (près de sa dépouille, ou en spectateur)
	var br_gear := {}
	for s in ["weapon", "head", "chest", "ring"]:
		br_gear[s] = Items.generate(10, 0.5, s, "warrior")
	var sheet := RoyaleGearSheet.open(world, {"name": "Guerrier", "cid": "warrior", "lv": 12, "kills": 2, "place": 4, "gear": br_gear, "drops": {}})
	await probe("Battle royale : fiche d'équipement", 0.9)
	sheet._input(back_event())
	check("fiche d'équipement : B la ferme et rend la main", not sheet.is_open() and not get_tree().paused)
	await get_tree().process_frame
	world.queue_free()
	await get_tree().process_frame
	var title: Node = load("res://scenes/title.tscn").instantiate()
	add_child(title)
	await get_tree().create_timer(1.0).timeout
	await probe("écran titre")
	title._open_saves()
	await probe("écran titre : sauvegardes")
	Gamepad.active = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
