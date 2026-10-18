extends Node
## L'Échiquier, lot ACX-4 (R_ACX4.md) : traits croisés (styles de lignée qui relient deux familles, unités ponts, IA qui joue
## les styles), notes du joueur : verrou d'une seule manche, monstres de 1-4 adoucis, boutique et vente au banc pendant le
## combat (fusions du plateau à la préparation), or en sacs (toi et les autres stratèges), objets en icônes à gauche et
## enclumes des atouts sur le plateau, fiche qui reste et ligne « Viser » cliquable.
## godot --headless --path game res://tests/test_acx4.tscn

var fails := 0
var screen: AutochessScreen


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _frames(n := 2) -> void:
	for _i in n:
		await get_tree().process_frame


func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append([(n as Label).text, false])
	if n is Button:
		out.append([(n as Button).text, false])
	if n is Control and (n as Control).tooltip_text != "":
		out.append([(n as Control).tooltip_text, true])
	for c in n.get_children():
		_texts(c, out)


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "magician"
	Profile.hero_name = "Aelis"
	get_tree().root.size = Vector2i(1280, 720)
	Gamepad.active = false
	test_traits()
	test_ai_plans()
	test_lock()
	test_waves()
	test_combat_shop()
	await test_screen()
	print("[test_acx4] %s (%d échec(s))" % ["VERT" if fails == 0 else "ROUGE", fails])
	get_tree().paused = false
	get_tree().quit(1 if fails > 0 else 0)


# --- 1. traits croisés ---------------------------------------------------------------------------------------------------
func test_traits() -> void:
	var A := AutochessData
	var mono := 0
	var pair_of := {}
	for t in A.weapon_traits():
		var fams := {}
		for id in A.units_with_trait(t):
			fams[String(A.unit(id).traits[0])] = true
		mono += 1 if fams.size() < 2 else 0
		pair_of[t] = fams.keys()
	check("chaque style réunit deux familles (aucun style d'une seule couleur)", mono == 0)
	var shared := true
	for f in A.family_traits():
		var with := {}
		for t in pair_of:
			if f in pair_of[t]:
				for g in pair_of[t]:
					if g != f:
						with[g] = true
		shared = shared and with.size() == 4
	check("chaque famille partage un style avec chacune des 4 autres", shared)
	var lineage_ok := true
	for id in A.unit_ids():
		var u := A.unit(id)
		var root := A.unit(String(u.parent))
		lineage_ok = lineage_ok and (u.traits as Array).slice(0, 2) == (root.traits as Array).slice(0, 2)
	check("une lignée (classe verte et ses éveils, coûts différents) garde ses deux traits", lineage_ok)
	var bridges: Array = A.unit_ids().filter(func(id): return (A.unit(id).traits as Array).size() == 3)
	check("5 unités ponts à 3 traits (%s)" % str(bridges), bridges.size() == 5)
	var blurb := A.trait_blurb("estoc")
	check("explication d'un style : ses deux familles et ses héros (%s)" % blurb, blurb.begins_with("Style ")
		and blurb.contains("Rempart") and blurb.contains("Traque") and blurb.contains(A.unit_name("knight")))
	check("explication d'une famille", A.trait_blurb("rempart").begins_with("Famille ") and A.trait_kind_name("tir") == "Style")
	var names := {}
	for t in A.TRAITS:
		names[String(A.TRAITS[t].name)] = true
	check("15 noms de traits distincts, styles renommés (Cadence, Harmonie, Brasier)", names.size() == 15
		and String(A.TRAITS.tir.name) == "Cadence" and String(A.TRAITS.choeur.name) == "Harmonie" and String(A.TRAITS.poudre.name) == "Brasier")


## L'IA planifie aussi par style (plan « family » = trait principal, famille ou style) et monte des plateaux mêlés.
func test_ai_plans() -> void:
	var style_plans := 0
	var plans := 0
	var shares: Array = []
	for seed_v in [3, 4]:
		var g := Autochess.new()
		g.save_path = ""
		g.start(seed_v, AutochessAi.lineup(3, seed_v, -1), AutochessSim.fight)
		g.play_to_end()
		for p in g.players:
			var pl: Dictionary = (p.meta as Dictionary).get("plan", {})
			var main := String(pl.get("family", ""))
			if main != "":
				plans += 1
				style_plans += 1 if String(AutochessData.TRAITS.get(main, {}).get("kind", "")) == "arme" else 0
			var fb: Array = p.get("final_board", [])
			if fb.size() >= 5:
				var fams := {}
				for u in fb:
					var f := String(AutochessData.unit(String(u.id)).traits[0])
					fams[f] = int(fams.get(f, 0)) + 1
				shares.append(float(fams.values().max()) / float(fb.size()))
	var mean := 0.0
	for x in shares:
		mean += float(x) / maxf(shares.size(), 1)
	check("IA Légende : des plans de style (%d sur %d plans)" % [style_plans, plans], plans >= 8 and style_plans >= 1)
	check("plateaux finaux mêlés : famille la plus présente %.0f %% en moyenne (< 90 %%)" % (100.0 * mean), not shares.is_empty() and mean < 0.9)


# --- 2. verrou d'une manche -----------------------------------------------------------------------------------------------
func _humans(seed_v := 9) -> Autochess:
	var g := Autochess.new()
	g.save_path = ""
	g.start(seed_v, [])
	return g


func _to_jcj(g: Autochess) -> void:
	var guard := 0
	while not (g.phase == "prep" and g.round_kind() == "jcj") and guard < 40:
		g.step()
		guard += 1


func test_lock() -> void:
	var g := _humans(9)
	_to_jcj(g)
	var p: Dictionary = g.players[0]
	g.toggle_lock(0)
	var kept: Array = (p.shop as Array).duplicate()
	g.step()  # combat
	g.step()  # bilan
	g.step()  # préparation suivante
	check("verrou : la boutique est gardée à la manche suivante", p.shop == kept)
	check("verrou : il saute une fois servi (prochaine manche seulement)", not bool(p.locked))
	g.step()
	g.step()
	g.step()
	check("verrou : la manche d'après, la boutique change", p.shop != kept)


# --- 3. monstres de l'étape 1 -----------------------------------------------------------------------------------------
func test_waves() -> void:
	var w: Dictionary = AutochessData.MONSTER_WAVES["1-4"]
	check("1-4 : une élite et deux sbires (note du joueur : défaites à 3 héros)", int(w.get("elites", 0)) == 1 and int(w.get("sbires", 0)) == 2)
	var g := _humans(11)
	var guard := 0
	while g.round_key() != "1-4" and guard < 10:
		g.step()
		guard += 1
	var board := g._pve_board(0)
	check("1-4 : 3 monstres au combat", board.size() == 3 and board.filter(func(m): return String(m.monster) == "elite").size() == 1)


# --- 4. boutique pendant le combat ------------------------------------------------------------------------------------
func test_combat_shop() -> void:
	var g := _humans(17)
	_to_jcj(g)
	var p: Dictionary = g.players[0]
	var id := String(AutochessData.units_of_cost(1)[0])
	for i in AutochessData.SHOP_SIZE:
		p.shop[i] = id
	p.gold = 30
	g.buy(0, 0)
	g.buy(0, 1)
	var on_board: Dictionary = g.bench_units(0)[0]
	g.place(0, int(on_board.uid), Vector2i(3, 0))
	g.end_prep()
	var board_before := str(p.board)  # (la fin de la préparation complète le plateau depuis le banc)
	check("combat : phase « combat »", g.phase == "combat")
	var gold := int(p.gold)
	check("combat : achat permis (or retiré, héros au banc)", g.buy(0, 2) and int(p.gold) == gold - 1)
	check("combat : le plateau ne bouge pas (pas de fusion avec le héros posé)", str(p.board) == board_before)
	var bench_ids: Array = g.bench_units(0).map(func(u): return String(u.id))
	check("combat : deux copies ★ attendent au banc", bench_ids.count(id) == 2)
	check("combat : vendre un héros du plateau est refusé", not g.sell(0, int(p.board[0].uid)))
	check("combat : actualiser et acheter de l'XP permis", g.reroll(0) and g.buy_xp(0))
	for i in AutochessData.SHOP_SIZE:
		p.shop[i] = "warrior" if id != "warrior" else "knight"
	g.buy(0, 0)
	var extra: Dictionary = g.bench_units(0).filter(func(u): return String(u.id) != id)[0]
	var g1 := int(p.gold)
	check("combat : vendre un héros du banc permis (+1 or)", g.sell(0, int(extra.uid)) and int(p.gold) == g1 + 1)
	g.run_fights()
	g.step()  # bilan -> préparation
	var stars := 0
	for u in p.board:
		if String(u.id) == id:
			stars = int(u.stars)
	check("préparation suivante : la fusion attendue se fait sur le plateau (★★)", stars == 2
		and g.bench_units(0).filter(func(u): return String(u.id) == id).is_empty())


# --- 5. écran ---------------------------------------------------------------------------------------------------------
func test_screen() -> void:
	Settings.set_v("autochess", "guide_done", true)
	AutochessScreen.config = {"seed": 21, "save_path": "", "fast": false, "real": false, "diff": 1}
	screen = load("res://scenes/autochess.tscn").instantiate()
	add_child(screen)
	await _frames(6)
	var g := screen.game
	var p: Dictionary = g.players[0]
	var hud := screen.hud
	if screen.choice.visible:
		(screen.choice.cards[0] as Button).pressed.emit()
		await _frames()
	# or en sacs
	p.gold = 37
	screen._sync()
	await _frames()
	var bags: AutochessHud.GoldBags = hud._interest
	check("or en sacs : 5 sacs, 3 pleins, le 4e aux 7 dixièmes", bags.bags() == 5 and is_equal_approx(bags.fill(2), 1.0)
		and is_equal_approx(bags.fill(3), 0.7) and is_equal_approx(bags.fill(4), 0.0))
	var rows_bags := 0
	for pi in hud.players.rows:
		rows_bags += 1 if (hud.players.rows[pi] as Control).find_child("AcBags", true, false) != null else 0
	check("or des stratèges : des sacs sur chaque ligne (%d)" % rows_bags, rows_bags == 8)
	# objets à gauche, enclumes des atouts
	p.items = ["lame", "arc"]
	p.augments = ["tirelire"]
	screen._sync()
	await _frames(3)
	var tray: AutochessHud.ItemTray = hud.item_tray
	var c0: Control = screen.cursor.control_of(AutochessBoard.items_slot(0))
	check("objets : plateau d'icônes à gauche, case 0 = icône 2D du curseur", tray.visible and c0 == tray.slots[0]
		and (c0.get_node("Icon") as TextureRect).texture != null and c0.has_meta("ac_2d"))
	var vr := Rect2(Vector2.ZERO, screen.get_viewport().get_visible_rect().size)
	check("objets : le plateau tient dans 1280 × 720", vr.encloses(tray.get_global_rect()))
	var bench := screen.board.bench
	check("enclumes : 3 enclumes, la 1re porte l'atout pris", bench.anvil_mode and bench._anvil_nodes.size() == 3
		and String((bench._anvil_nodes[0] as Node).get_meta("augment", "")) == "tirelire"
		and String((bench._anvil_nodes[1] as Node).get_meta("augment", "")) == "")
	check("enclumes : la colonne 3D n'est plus une case d'objet à la souris", bench.pick(AutochessBench.item_position(1)).is_empty()
		and bench.anvil_at(AutochessBench.item_position(1)) == "tirelire")
	# objet pris dans le plateau d'icônes puis posé sur un héros
	var cheap := String(AutochessData.units_of_cost(1)[0])
	p.shop[0] = cheap
	p.gold = 30
	screen._sync()
	screen._buy(0)
	await _frames()
	var u: Dictionary = g.bench_units(0)[0]
	g.place(0, int(u.uid), Vector2i(3, 1))
	screen._sync()
	await _frames()
	screen.cursor._set_slot(AutochessBoard.items_slot(0), "mouse")
	screen.cursor.activate()
	check("objets : un clic sur l'icône prend l'objet", String(screen.cursor.held.get("zone", "")) == "items")
	screen.cursor._set_slot(AutochessBoard.board_slot(3, 1), "mouse")
	screen.cursor.activate()
	await _frames()
	check("objets : un clic sur le héros le lui donne", (g.find_unit(0, int(u.uid)).items as Array).has("lame")
		and not (p.items as Array).has("lame"))
	# ligne « Viser » cliquable, la fiche reste
	AutochessPlanner.clear()
	hud.unit_card.show_unit({"id": cheap, "stars": 1, "items": []}, {}, true)
	screen._card_id = cheap
	screen._card_args = [{"id": cheap, "stars": 1, "items": []}, true]
	hud.unit_card.plan_clicked.emit(cheap)
	var line: Label = hud.unit_card.find_child("AcPlanLine", true, false)
	check("fiche : clic sur « Viser » vise le héros, la fiche reste et le dit", AutochessPlanner.is_planned(cheap)
		and hud.unit_card.visible and line != null and line.text.begins_with("◎"))
	AutochessPlanner.clear()
	# verrou : texte « prochaine manche seulement »
	check("verrou : infobulle « prochaine manche seulement »", hud.lock_button.tooltip_text.contains("prochaine manche seulement"))
	# combat : boutique et banc en vignettes
	var guard := 0
	while screen.phase != "combat" and guard < 4000:  # jusqu'au premier vrai combat (l'ouverture n'en a pas)
		if screen.phase == "prep":
			if screen.choice.visible and not screen.choice.cards.is_empty():
				(screen.choice.cards[0] as Button).pressed.emit()
			screen._end_prep()
		await get_tree().process_frame
		guard += 1
	await _frames(2)
	check("combat : bouton Boutique, boutique repliée", screen.phase == "combat" and hud.shop_button.is_visible_in_tree()
		and not hud.shop.is_visible_in_tree())
	hud.shop_toggled.emit()
	await _frames()
	check("combat : la boutique s'ouvre avec le banc en vignettes", hud.shop.is_visible_in_tree() and hud.bench_strip.visible
		and not hud.ready_button.visible and hud.shop_close_button.is_visible_in_tree())
	p.shop[1] = cheap
	p.gold = 30
	var n0 := g.bench_units(0).size()
	screen._buy(1)
	screen._sync()
	await _frames()
	check("combat : achat au banc", g.bench_units(0).size() == n0 + 1)
	var bu: Dictionary = g.bench_units(0)[0]
	var thumb := false
	for b in hud.bench_strip.slots:
		thumb = thumb or int((b as Button).get_meta("uid", -1)) == int(bu.uid)
	check("combat : le héros acheté a sa vignette", thumb)
	hud.bench_sell.emit(int(bu.uid), false)
	await _frames()
	check("combat : vendu depuis sa vignette (ou confirmation pour un héros précieux)", g.find_unit(0, int(bu.uid)).is_empty()
		or screen.cards.count() > 0)
	check("combat : banc en vignettes dans l'écran", vr.encloses(hud.bench_strip.get_global_rect()))
	var fr: Node = load("res://tests/test_texts_fr.gd").new()
	var texts: Array = []
	_texts(hud, texts)
	var bad: Array = []
	for t in texts:
		if not (fr._english_in(String(t[0])) as Array).is_empty() or (String(t[0]).contains("%") and not bool(t[1])):
			bad.append(String(t[0]))
	check("textes en français, sans pourcentage permanent %s" % str(bad), bad.is_empty())
	fr.free()
	hud.shop_toggled.emit()
	await _frames()
	check("combat : « Voir le combat » replie la boutique", not hud.shop.is_visible_in_tree())
