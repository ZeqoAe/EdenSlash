extends Node
## L'Échiquier, lot ACX-2 : annuler (achat, vente, déplacement ; jamais une actualisation), vente confirmée d'un héros
## précieux, raccourcis (W, Q / R, Ctrl+Z, 1 2 3 en combat), vitesse ×1 / ×2 / ×3, Passer, bandeau de manche non bloquant
## + Détail, moments manga (★★, ★★★, objet complet, victoire, éliminations), atout v2 (icône du jeu, une phrase, genre),
## réglages (sans minuteur, noms, bilan toujours), couleurs de camp fixes, spectateur après élimination (place et
## récompenses fixées à la chute, bilan à la fin), textes en français, captures 1280 × 720 sans débord.
## godot --headless --path game res://tests/test_acx2.tscn

var fails := 0
var screen: AutochessScreen


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _frames(n := 2) -> void:
	for _i in n:
		await get_tree().process_frame


func _key(k: Key, ctrl := false) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.ctrl_pressed = ctrl
		e.pressed = down
		Input.parse_input_event(e)
		await get_tree().process_frame


func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	if n is Button:
		out.append((n as Button).text)
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
		if not hits.is_empty() or String(t).contains("%"):
			bad.append(String(t))
	return bad


## Met [param ids] dans la boutique du joueur (cases 0…).
func _shop(ids: Array) -> void:
	var p: Dictionary = screen.game.players[0]
	for i in AutochessData.SHOP_SIZE:
		p.shop[i] = String(ids[i]) if i < ids.size() else ""
	screen._sync()


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "magician"
	Profile.hero_name = "Aelis"
	get_tree().root.size = Vector2i(1280, 720)
	Gamepad.active = false
	AutochessScreen.config = {"seed": 11, "save_path": "", "fast": true}
	screen = load("res://scenes/autochess.tscn").instantiate()
	add_child(screen)
	await _frames(4)
	var g := screen.game
	var p: Dictionary = g.players[0]
	var fr: Node = load("res://tests/test_texts_fr.gd").new()
	if screen.choice.visible:
		(screen.choice.cards[0] as Button).pressed.emit()
		await _frames()

	# --- annuler ---------------------------------------------------------------------------------------------------
	var cheap: Array = AutochessData.units_of_cost(1)
	cheap.sort()
	var id := String(cheap[3])
	_shop([id, id, id, String(cheap[4]), ""])
	p.gold = 40
	var pool0 := int(g.pool.remaining(id))
	var bench0 := g.bench_units(0).size()
	check("rien à annuler au départ : bouton Annuler caché", not g.can_undo(0))
	screen._buy(0)
	await _frames()
	check("achat : or −1, une unité de plus, bouton Annuler visible", int(p.gold) == 39 and g.bench_units(0).size() == bench0 + 1
		and screen.hud.undo_button.visible)
	await _key(KEY_Z, true)
	check("Ctrl+Z annule l'achat : l'or et la case de boutique reviennent", int(p.gold) == 40 and String(p.shop[0]) == id
		and g.bench_units(0).size() == bench0 and int(g.pool.remaining(id)) == pool0)
	check("avis « Achat annulé »", screen.hud.toast_text() == "Achat annulé")
	screen._buy(0)
	var u: Dictionary = g.bench_units(0)[g.bench_units(0).size() - 1]
	var uid := int(u.uid)
	g.place(0, uid, Vector2i(3, 2))
	check("placement puis annuler : l'unité revient au banc", g.board_cap(0) >= 1 and screen.game.undo(0) == "move"
		and g.find_unit(0, uid).has("uid") and not g.find_unit(0, uid).has("cell"))
	var gold_before_sell := int(p.gold)
	g.sell(0, uid)
	check("vente puis annuler : l'unité et l'or reviennent", g.undo(0) == "sell" and int(p.gold) == gold_before_sell
		and not g.find_unit(0, uid).is_empty())
	p.gold = 20
	g.buy(0, 1)
	g.reroll(0)
	check("une actualisation vide la pile : plus rien à annuler", not g.can_undo(0))
	g.buy(0, 0)
	g.buy_xp(0)
	check("un achat d'XP vide la pile aussi", not g.can_undo(0))

	# --- moments : ★★ à la 3e copie --------------------------------------------------------------------------------
	screen.fast = false
	for k in g.units_of(0):
		g.sell(0, int(k.uid))
	_shop([id, id, id, "", ""])
	p.gold = 30
	screen.moments.shown.clear()
	screen._buy(0)
	screen._buy(1)
	screen._buy(2)
	await _frames(3)
	var two := g.units_of(0).filter(func(x): return String(x.id) == id and int(x.stars) == 2)
	check("3 copies : fusion ★★ et éclat « ★★ ! » sur la figurine", two.size() == 1 and screen.moments.shown.has("★★ !"))
	screen.fast = true

	# --- vente confirmée -------------------------------------------------------------------------------------------
	screen._sync()
	await _frames()
	var star2: Dictionary = two[0] if not two.is_empty() else {}
	var slot: Dictionary = {}
	for s in screen.board.all_slots():
		if not screen.board.unit_at(s).is_empty() and int(screen.board.unit_at(s).get("uid", -1)) == int(star2.get("uid", -2)):
			slot = s
	screen.cursor.slot = slot
	var before_n := g.units_of(0).size()
	var sold := screen.cursor.sell_current()
	await _frames()
	check("héros ★★ vendu d'un coup : « Vendre ? » d'abord, rien n'est vendu", not sold and g.units_of(0).size() == before_n
		and screen.cursor.precious(slot))
	var ask: InfoCard.Ask = null
	for c in screen.get_children():
		if c is InfoCard.Ask:
			ask = c
	check("« Vendre … ★★ ? » : la confirmation est ouverte", ask != null and ask.title_label.text.contains("★★"))
	if ask != null:
		ask.ok_button.pressed.emit()
		await _frames(3)
	check("confirmé : le héros est vendu", g.units_of(0).size() == before_n - 1)
	g.undo(0)
	screen._sync()
	await _frames()
	screen.cursor.slot = slot
	check("maintien terminé (X / E 0,6 s) : vendu sans question", screen.cursor.sell_current(true) and g.units_of(0).size() == before_n - 1)
	check("vente : maintien de 0,6 s (BIBLE)", is_equal_approx(AutochessCursor.SELL_HOLD, 0.6))
	g.undo(0)
	screen._sync()

	# --- raccourci W : banc ↔ plateau ------------------------------------------------------------------------------
	var bu: Array = g.bench_units(0)
	if not bu.is_empty():
		var bslot := {}
		for s in screen.board.all_slots():
			if String(s.zone) == "bench" and int(screen.board.unit_at(s).get("uid", -1)) == int(bu[0].uid):
				bslot = s
		screen.cursor.slot = bslot
		var on_board := (p.board as Array).size()
		await _key(KEY_W)
		check("W : le héros du banc passe sur le plateau", (p.board as Array).size() == on_board + 1)
	# Q / R : plateau des autres
	await _key(KEY_R)
	check("R : plateau du stratège suivant", screen.scouted > 0)
	await _key(KEY_Q)
	check("Q : plateau du stratège précédent", screen.scouted >= 0)

	# --- réglages --------------------------------------------------------------------------------------------------
	screen.set_opt("no_timer", true)
	await _frames()
	check("sans minuteur : le minuteur disparaît, la préparation attend Prêt", screen.timer_total == 0.0 and screen.timer > 1000.0
		and not screen.hud._timer.visible)
	screen.set_opt("no_timer", false)
	screen.set_opt("names", true)
	check("noms au-dessus des héros : réglage lu par les unités", AutochessUnit.show_names)
	screen.set_opt("names", false)
	check("réglages gardés dans les Paramètres (section autochess)", Settings.get_v("autochess", "no_timer") == false)

	# --- couleurs de camp fixes ------------------------------------------------------------------------------------
	AutochessDirector.viewer = 0
	check("camp b du joueur : ses barres restent pomme (is_mine)", AutochessDirector.is_mine({"fight": {"a": 3, "b": 0}}, 1)
		and not AutochessDirector.is_mine({"fight": {"a": 3, "b": 0}}, 0) and AutochessDirector.is_mine({"fight": {"a": 0, "b": 4}}, 0))

	# --- vitesse, Passer -------------------------------------------------------------------------------------------
	AutochessScreen.speed = 1
	screen._toggle_speed()
	var s2 := AutochessScreen.speed
	screen._toggle_speed()
	var s3 := AutochessScreen.speed
	screen._toggle_speed()
	check("vitesse ×1 → ×2 → ×3 → ×1", s2 == 2 and s3 == 3 and AutochessScreen.speed == 1)

	# --- atout v2 --------------------------------------------------------------------------------------------------
	var opts: Array = ["tirelire", "interets_composes", "couronne"]
	screen.choice.open({"kind": "atout", "rarity": "or", "rerolls": 1, "options": opts})
	await _frames()
	var icons_ok := true
	for b in screen.choice.cards:
		var art := (b as Control).get_child(0) as AutochessChoicePanel.CardArt
		icons_ok = icons_ok and art != null and art.icon != null
	check("atout v2 : 3 cartes, icône du jeu dans le médaillon, Relancer · 1", screen.choice.cards.size() == 3 and icons_ok
		and screen.choice.reroll_button.text == "Relancer · 1")
	var all_icons := true
	for a in AutochessData.AUGMENTS:
		all_icons = all_icons and Boons.ICONS.has(String(AutochessData.augment(String(a)).get("icon", "")))
	check("atout v2 : chaque atout a une icône du jeu (30)", all_icons)
	var bad := _english(fr, screen.choice).filter(func(t): return not String(t).contains("%"))
	check("atout v2 : textes en français" + ("" if bad.is_empty() else " : " + str(bad)), bad.is_empty())
	var shorts_ok := true
	for o in opts:
		shorts_ok = shorts_ok and not String(AutochessData.augment(String(o)).get("short", "")).contains("%")
	check("atout v2 : la phrase de la carte n'a aucun pourcentage (le détail chiffré au survol)", shorts_ok)
	screen.choice.visible = false

	# --- bandeau de manche non bloquant + Détail -------------------------------------------------------------------
	screen.strip.show_result("Victoire", "pomme", "+1 or", true)
	check("bandeau de manche : « Victoire|+1 or », sans voile ni attente", screen.strip.text() == "Victoire|+1 or" and not screen.recap.visible)
	screen.strip.add_income(7, [["5 de base", "lilas"], ["2 d'intérêts", "pomme"]])
	check("bandeau : le revenu de la manche suivante en plots", screen.strip.plots.get_child_count() >= 3)

	# --- jusqu'au premier combat de stratèges : bandeau, moments ---------------------------------------------------
	var guard := 0
	screen.moments.shown.clear()
	while g.round_kind() != "jcj" and guard < 2000:
		guard += 1
		if screen.phase == "prep" and not screen.carousel.visible:
			if screen.choice.visible:
				(screen.choice.cards[0] as Button).pressed.emit()
			screen._end_prep()
		await get_tree().process_frame
	screen.fast = false
	screen._end_prep()
	guard = 0
	var saw_strip := false
	while screen.phase != "prep" and guard < 900:
		guard += 1
		saw_strip = saw_strip or screen.strip.text() != ""
		await get_tree().process_frame
	check("combat de stratèges : « Combat ! » puis le bandeau de résultat (%s)" % str(screen.moments.shown),
		screen.moments.shown.has("Combat !") and saw_strip)
	check("le bilan complet ne s'est pas imposé", not screen.recap.visible)
	screen.fast = true

	# --- spectateur après élimination ------------------------------------------------------------------------------
	for other in range(1, AutochessData.PLAYERS):
		g.players[other].hp = maxi(int(g.players[other].hp), 40)
	p.hp = 0
	g._eliminate_dead()
	var place := int(p.place)
	check("élimination : une place fixée (%d)" % place, place >= 2 and not bool(p.alive))
	screen.fast = false
	screen._next_round()
	await _frames()
	check("« Tu es éliminé » : Regarder la fin / Bilan", screen.phase == "out" and screen.cards.ids().has("ac_out"))
	screen.fast = true
	var bs: Array = screen.cards.buttons("ac_out")
	(bs[0] as Button).pressed.emit()
	await _frames(3)
	check("Regarder la fin : spectateur, combats en ×2, partie plus sauvegardée", screen.spectating and AutochessScreen.speed == 2
		and g.save_path == "")
	guard = 0
	var rounds0 := g.rounds_played
	while screen.phase != "over" and guard < 6000:
		guard += 1
		await get_tree().process_frame
	check("spectateur : la partie va jusqu'au bout (%d manches regardées)" % (g.rounds_played - rounds0), screen.phase == "over"
		and g.rounds_played > rounds0)
	check("spectateur : ta place n'a pas changé (%d)" % int(p.place), int(p.place) == place)
	check("bilan de fin : podium des 8 et « Menu principal »", screen.results != null and screen.results.find_child("AcPodium", true, false) != null
		and screen.results.buttons.map(func(b): return b.text).has("Menu principal"))
	check("vitesse rendue après le spectateur", AutochessScreen.speed == 1)
	var bad2 := _english(fr, screen.results)
	check("bilan de fin en français" + ("" if bad2.is_empty() else " : " + str(bad2)), bad2.is_empty())

	print("[test_acx2] %s (%d échec(s))" % ["VERT" if fails == 0 else "ROUGE", fails])
	get_tree().paused = false
	get_tree().quit(1 if fails > 0 else 0)
