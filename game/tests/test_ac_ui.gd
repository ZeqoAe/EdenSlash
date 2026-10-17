extends Node
## L'Échiquier, lot AC-G : l'interface branchée sur la partie (AC-B) et le plateau (AC-F). Achat (bouton, touche),
## actualisation, XP, verrou, placement, objet donné, vente, fiche d'unité, Prêt (bouton, Y), choix du premier héros,
## choix d'atout (relance, replier / revenir), choix partagé, atteignabilité à la manette de chaque bouton (plateau,
## atout, choix partagé), aucun texte en anglais, partie complète jusqu'à la fin, Rejouer.
## godot --headless --path game res://tests/test_ac_ui.tscn

var fails := 0
var screen: AutochessScreen


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _frames(n := 2) -> void:
	for _i in n:
		await get_tree().process_frame


## Avance jusqu'à la préparation de la manche [param st]-[param rd] (Prêt à chaque préparation).
func _goto(st: int, rd: int, limit := 4000) -> bool:
	var guard := 0
	while guard < limit:
		guard += 1
		var g := screen.game
		if g.stage == st and g.round_i == rd and screen.phase == "prep":
			return true
		if screen.phase == "over" or g.is_over():
			return false
		if screen.phase == "prep":
			if screen.carousel.visible:
				pass  # le choix partagé se règle seul (temps écoulé, durées réduites)
			else:
				screen._end_prep()
		await get_tree().process_frame
	return false


## Contrôles atteignables depuis le premier candidat, à la croix (comme test_nav_screens).
func reach() -> Array:
	var all: Array = UiNav.candidates()
	if all.is_empty():
		return [[], all]
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
	return [seen.keys(), all]


func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	if n is Button:
		out.append((n as Button).text)
	if n is RichTextLabel:
		out.append((n as RichTextLabel).get_parsed_text())
	if n is Control and (n as Control).tooltip_text != "":
		out.append((n as Control).tooltip_text)
	for c in n.get_children():
		_texts(c, out)


func _english(fr: Node, root: Node) -> Array:
	var texts: Array = []
	_texts(root, texts)
	var bad: Array = []
	for t in texts:
		var hits: Array = fr._english_in(String(t))
		if not hits.is_empty():
			bad.append("%s (%s)" % [t, ", ".join(hits)])
	return bad


func _bench_count() -> int:
	return screen.game.bench_units(0).size()


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "magician"
	Profile.hero_name = "Aelis"
	get_tree().root.size = Vector2i(1280, 720)
	Gamepad.active = false
	AutochessScreen.config = {"seed": 7, "save_path": "", "fast": true}
	screen = load("res://scenes/autochess.tscn").instantiate()
	add_child(screen)
	await _frames(4)
	var g := screen.game
	var p: Dictionary = g.players[0]
	var fr: Node = load("res://tests/test_texts_fr.gd").new()

	# --- ouverture : 1 héros de coût 1 parmi 4 -------------------------------------------------------------------
	check("1-1 : le choix du premier héros est ouvert (4 cartes)", screen.choice.visible and screen.choice.kind == "ouverture"
		and screen.choice.cards.size() == AutochessData.OPENING_CHOICES)
	check("aucun nœud « player » (la manette navigue sur l'écran)", get_tree().get_first_node_in_group("player") == null)
	var bad := _english(fr, screen.choice)
	check("textes du choix en français" + ("" if bad.is_empty() else " : " + str(bad)), bad.is_empty())
	var pick: String = g.pending(0).options[1]
	(screen.choice.cards[1] as Button).pressed.emit()
	await _frames()
	check("le héros choisi rejoint le banc, le choix se ferme", _bench_count() == 1 and String(g.bench_units(0)[0].id) == pick
		and not screen.choice.visible)
	check("l'avis « … rejoint ton banc »", screen.hud.toast_text().contains("rejoint ton banc"))

	# --- boutique ------------------------------------------------------------------------------------------------
	check("1-1 : la boutique a 5 cartes", screen.hud.shop.cards.size() == AutochessData.SHOP_SIZE)
	p.gold = 30
	screen._sync()
	var slot := -1
	for i in AutochessData.SHOP_SIZE:
		if String(p.shop[i]) != "":
			slot = i
			break
	var id := String(p.shop[slot])
	var cost := AutochessPool.cost_of(id)
	var n0 := _bench_count()
	(screen.hud.shop.cards[slot] as Button).pressed.emit()
	await _frames()
	check("achat au clic : une unité de plus, l'or baisse du coût", _bench_count() == n0 + 1 and int(p.gold) == 30 - cost
		and String(p.shop[slot]) == "")
	var slot2 := -1
	for i in AutochessData.SHOP_SIZE:
		if String(p.shop[i]) != "":
			slot2 = i
			break
	var gold := int(p.gold)
	var key := InputEventKey.new()
	key.keycode = KEY_1 + slot2
	key.pressed = true
	screen._unhandled_input(key)
	await _frames()
	check("achat à la touche %d" % (slot2 + 1), int(p.gold) < gold and String(p.shop[slot2]) == "")
	gold = int(p.gold)
	var shop_before: Array = (p.shop as Array).duplicate()
	screen.hud.reroll_button.pressed.emit()
	await _frames()
	check("actualiser : −%d or, 5 nouvelles offres" % AutochessData.REROLL_COST,
		int(p.gold) == gold - AutochessData.REROLL_COST and not (p.shop as Array).has("") and p.shop != shop_before)
	p.gold = 0
	screen._sync()
	screen.hud.reroll_button.pressed.emit()
	await _frames()
	check("actualiser sans or : refusé, avis « Pas assez d'or »", screen.hud.toast_text() == "Pas assez d'or")
	p.gold = 20
	var lv := int(p.level)
	var xp := int(p.xp)
	screen.hud.xp_button.pressed.emit()
	await _frames()
	check("acheter de l'XP : +%d XP (ou un niveau)" % AutochessData.XP_BUY_AMOUNT, int(p.level) > lv or int(p.xp) == xp + AutochessData.XP_BUY_AMOUNT)
	screen.hud.lock_button.pressed.emit()
	await _frames()
	check("verrou : la boutique est verrouillée", bool(p.locked) and screen.hud.lock_button.text == "Verrouillée")
	screen.hud.lock_button.pressed.emit()
	await _frames()
	check("verrou : un second appui la libère", not bool(p.locked))

	# --- plateau : placer, objet, vente, fiche --------------------------------------------------------------------
	var b := screen.board
	var u0: Dictionary = g.bench_units(0)[0]
	var bslot := -1
	for i in AutochessData.BENCH_SIZE:
		if p.bench[i] != null and int(p.bench[i].uid) == int(u0.uid):
			bslot = i
	b.move(AutochessBoard.bench_slot(bslot), AutochessBoard.board_slot(3, 1))
	await _frames()
	check("placer : l'unité est sur la case (3, 1) de la partie", not g.unit_at(0, Vector2i(3, 1)).is_empty()
		and int(g.unit_at(0, Vector2i(3, 1)).uid) == int(u0.uid))
	(p.items as Array).append("lame")
	screen._sync()
	await _frames()
	b.move(AutochessBoard.items_slot(0), AutochessBoard.board_slot(3, 1))
	await _frames()
	check("objet donné : la Lame d'acier est portée, le banc d'objets est vide",
		(g.unit_at(0, Vector2i(3, 1)).items as Array).has("lame") and (p.items as Array).is_empty())
	screen.cursor._set_slot(AutochessBoard.board_slot(3, 1), "keys")
	await _frames(3)
	check("fiche d'unité au survol de la case", screen.hud.unit_card.visible and screen.hud.unit_card.shown_key().begins_with("u:%s" % u0.id)
		and not screen.hud.traits.visible)
	bad = _english(fr, screen.hud.unit_card)
	check("fiche d'unité en français" + ("" if bad.is_empty() else " : " + str(bad)), bad.is_empty())
	screen.cursor._set_slot(AutochessBoard.bench_slot(8), "keys")
	await _frames(3)
	check("case vide : la fiche se ferme, les traits reviennent", not screen.hud.unit_card.visible and screen.hud.traits.visible)
	check("traits : une ligne par trait de l'unité posée", screen.hud.traits.rows.size() == Autochess.unit_traits(u0).size())
	var u1: Dictionary = g.bench_units(0)[0]
	var s1 := -1
	for i in AutochessData.BENCH_SIZE:
		if p.bench[i] != null and int(p.bench[i].uid) == int(u1.uid):
			s1 = i
	gold = int(p.gold)
	var units := g.units_of(0).size()
	screen.cursor._set_slot(AutochessBoard.bench_slot(s1), "keys")
	screen.cursor.sell_current()
	await _frames()
	check("vente : une unité de moins, l'or rendu", g.units_of(0).size() == units - 1
		and int(p.gold) == gold + AutochessData.sell_value(AutochessPool.cost_of(String(u1.id)), int(u1.stars)))
	screen.cursor._set_slot(AutochessBoard.board_slot(3, 1), "keys")
	await _frames(2)
	screen.cursor.activate()
	await _frames(2)
	check("unité tenue : la boutique se replie (zone « Vendre » du plateau)", not screen.hud._bottom.visible)
	screen.cursor.cancel()
	await _frames(2)
	check("reposée : la boutique revient", screen.hud._bottom.visible)

	# --- manette : chaque bouton du plateau est atteignable -------------------------------------------------------
	Gamepad.active = true
	await _frames(3)
	var r := reach()
	var seen: Array = r[0]
	check("niveau 1 : acheter de l'XP est grisé (le niveau 2 vient à la manche suivante)", screen.hud.xp_button.disabled)
	var want: Array = [screen.hud.reroll_button, screen.hud.lock_button, screen.hud.ready_button]
	want.append_array(screen.hud.shop.cards)
	want.append_array(screen.hud.traits.rows.values())
	want.append_array(screen.hud.players.rows.values())
	var missing: Array = want.filter(func(c): return not seen.has(c)).map(func(c): return String(c.name))
	check("manette : boutons, 5 cartes, traits et 8 stratèges atteignables (%d / %d contrôles)" % [seen.size(), (r[1] as Array).size()]
		+ ("" if missing.is_empty() else " ; manquent " + str(missing)), missing.is_empty() and seen.size() >= (r[1] as Array).size() * 0.95)
	var cells := 0
	for c in seen:
		if (c as Control).has_meta("ac_slot"):
			cells += 1
	check("manette : les 47 cases du plateau atteignables", cells == 47)
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	screen._input(rb)
	await _frames(2)
	check("RB : le cadre passe sur la boutique", UiNav.cursor == screen.hud.shop.cards[0])
	await _frames(2)
	check("cadre sur une carte de la boutique : sa fiche s'affiche", screen.hud.unit_card.visible
		and screen.hud.unit_card.shown_key().contains(String(p.shop[0])) if String(p.shop[0]) != "" else true)
	screen._trait_card(String(Autochess.unit_traits(u0)[0]))
	await _frames(3)
	check("trait : une petite carte de détail s'ouvre", screen.cards.count() == 1)
	screen.cards.dismiss_all()
	await get_tree().create_timer(0.4).timeout
	bad = _english(fr, screen.hud)
	check("cadre de la partie en français" + ("" if bad.is_empty() else " : " + str(bad)), bad.is_empty())
	screen._scout(1)
	await _frames()
	check("stratège cliqué : son plateau sur la moitié adverse", screen.scouted == 1)
	screen._scout(1)
	check("second clic : on ne le regarde plus", screen.scouted == -1)

	# --- Prêt ----------------------------------------------------------------------------------------------------
	var rk := g.round_key()
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	screen._input(y)
	await _frames()
	check("Y : Prêt, la préparation se termine", screen.phase != "prep" or g.round_key() != rk)
	var guard := 0
	while not (screen.phase == "prep" and g.round_key() != rk) and guard < 600:
		guard += 1
		await get_tree().process_frame
	check("manche suivante : %s" % g.round_key(), screen.phase == "prep" and g.round_key() != rk)
	screen.hud.ready_button.pressed.emit()
	await _frames()
	check("bouton Prêt : combat de la manche %s" % rk, screen.phase in ["combat", "recap"])
	var saw_banner := false
	guard = 0
	while screen.phase != "prep" and guard < 600:
		guard += 1
		if screen.hud.banner_text().begins_with("Victoire") or screen.hud.banner_text().begins_with("Défaite") \
				or screen.hud.banner_text().begins_with("Égalité"):
			saw_banner = true
		await get_tree().process_frame
	check("bilan de manche : bandeau Victoire / Défaite", saw_banner)

	# --- atout (2-1) ----------------------------------------------------------------------------------------------
	check("on atteint 2-1", await _goto(2, 1))
	await _frames(2)
	var c := g.pending(0)
	check("2-1 : le choix d'atout est ouvert (3 cartes, Relancer)", screen.choice.visible and screen.choice.kind == "atout"
		and screen.choice.cards.size() == AutochessData.AUGMENT_CHOICES and screen.choice.reroll_button.visible
		and not screen.choice.reroll_button.disabled)
	r = reach()
	seen = r[0]
	missing = (screen.choice.cards + [screen.choice.reroll_button, screen.choice.hide_button]).filter(func(x): return not seen.has(x))
	check("manette : les 3 atouts, Relancer et Voir le plateau atteignables, et rien d'autre", missing.is_empty()
		and seen.size() == (r[1] as Array).size() and (r[1] as Array).size() == AutochessData.AUGMENT_CHOICES + 2)
	bad = _english(fr, screen.choice)
	check("atouts en français" + ("" if bad.is_empty() else " : " + str(bad)), bad.is_empty())
	var before: Array = (c.options as Array).duplicate()
	screen.choice.reroll_button.pressed.emit()
	await _frames()
	c = g.pending(0)
	check("Relancer : 3 nouvelles cartes, plus de relance", c.options != before and screen.choice.reroll_button.disabled)
	screen.choice.hide_button.pressed.emit()
	await _frames()
	check("Voir le plateau : le choix se replie, un bouton pour revenir", not screen.choice.visible and screen.hud.choice_button.visible)
	screen.hud.choice_button.pressed.emit()
	await _frames()
	check("Revenir au choix : les cartes reviennent", screen.choice.visible and not screen.hud.choice_button.visible)
	var aug := String(c.options[2])
	(screen.choice.cards[2] as Button).pressed.emit()
	await _frames()
	check("atout choisi : %s" % AutochessData.augment(aug).get("name", ""), (p.augments as Array).has(aug))
	guard = 0
	while screen.choice.visible and guard < 8:  # un atout peut ouvrir un second choix (composant, famille…)
		guard += 1
		(screen.choice.cards[0] as Button).pressed.emit()
		await _frames()
	check("tous les choix faits : les cartes se ferment", not screen.choice.visible and g.pending(0).is_empty())
	await _frames(3)
	r = reach()
	seen = r[0]
	check("manette (niveau %d) : Acheter de l'XP, Actualiser, Verrouiller, Prêt atteignables" % int(p.level),
		[screen.hud.xp_button, screen.hud.reroll_button, screen.hud.lock_button, screen.hud.ready_button].all(func(x): return seen.has(x)))

	# --- choix partagé (2-4) --------------------------------------------------------------------------------------
	screen.fast = false  # l'anneau garde son rythme pour qu'on y choisisse soi-même
	check("on atteint 2-4", await _goto(2, 4))
	await _frames(2)
	check("2-4 : l'anneau du choix partagé est ouvert (%d cartes)" % screen.carousel.cards.size(),
		screen.carousel.visible and screen.carousel.cards.size() > 0)
	bad = _english(fr, screen.carousel)
	check("choix partagé en français" + ("" if bad.is_empty() else " : " + str(bad)), bad.is_empty())
	guard = 0
	while not screen._my_carousel_turn() and guard < 1200:
		guard += 1
		await get_tree().process_frame
	check("ton tour arrive après ceux qui ont moins de PV", screen._my_carousel_turn())
	r = reach()
	seen = r[0]
	check("manette : toutes les cartes libres de l'anneau atteignables (%d / %d)" % [seen.size(), (r[1] as Array).size()],
		seen.size() == (r[1] as Array).size() and seen.size() >= 1)
	var free_k := -1
	for k in screen.carousel.cards.size():
		if not (screen.carousel.cards[k] as Button).disabled:
			free_k = k
			break
	var want_id := String(g.carousel.options[free_k].id)
	var want_comp := String(g.carousel.options[free_k].component)
	units = g.units_of(0).size()
	var items_n := (p.items as Array).size()
	(screen.carousel.cards[free_k] as Button).pressed.emit()
	await _frames()
	var got := false
	for uu in g.units_of(0):
		if String(uu.id) == want_id and (uu.items as Array).has(want_comp):
			got = true
	check("choix partagé : %s et son composant rejoignent l'équipe" % AutochessData.unit_name(want_id),
		got or (g.units_of(0).size() == units and (p.items as Array).size() == items_n + 1))
	guard = 0
	while screen.carousel.visible and guard < 1200:
		guard += 1
		await get_tree().process_frame
	check("l'anneau se ferme une fois tous les choix faits", not screen.carousel.visible)
	screen.fast = true

	# --- partie complète, fin, Rejouer ----------------------------------------------------------------------------
	Gamepad.active = false
	screen.autoplay = true
	guard = 0
	while screen.phase != "over" and guard < 20000:
		guard += 1
		await get_tree().process_frame
	check("partie jouée jusqu'au bout au pilote (%s, place %d)" % [g.round_key(), int(p.place)], screen.phase == "over" and int(p.place) >= 1)
	check("fin : ta place, Rejouer et Retour", screen.hud.is_end_shown() and screen.hud.replay_button.is_visible_in_tree()
		and screen.hud.back_button.is_visible_in_tree())
	Gamepad.active = true
	await _frames(2)
	r = reach()
	seen = r[0]
	check("manette : Rejouer et Retour atteignables", seen.has(screen.hud.replay_button) and seen.has(screen.hud.back_button))
	check("manette : Statistiques atteignable (AC-V)", seen.has(screen.hud.stats_button))
	Gamepad.active = false
	# lot AC-V : bilan de la partie (cumul de tes héros, manche après manche)
	var acc: Dictionary = screen.game_stats
	check("statistiques de la partie : %d manches, %d classes" % [int(acc.get("rounds", 0)), (acc.get("units", {}) as Dictionary).size()],
		int(acc.get("rounds", 0)) > 3 and not (acc.get("units", {}) as Dictionary).is_empty())
	screen.hud.stats_button.pressed.emit()
	await _frames(2)
	check("bouton Statistiques : bilan de la partie ouvert", screen.recap.visible and screen.recap.mode == "game" and not screen.recap.shown_rows().is_empty())
	bad = _english(fr, screen.recap)
	check("bilan de la partie en français" + ("" if bad.is_empty() else " : " + str(bad)), bad.is_empty())
	screen.recap.close()
	screen.autoplay = false
	screen.hud.replay_button.pressed.emit()
	await _frames(3)
	check("Rejouer : nouvelle partie à 1-1", screen.game != g and screen.game.round_key() == "1-1" and screen.phase == "prep"
		and screen.choice.visible)
	fr.free()
	AutochessScreen.config = {}
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
