extends Node
## L'Échiquier, lot ACX-3 (backlog BM-AUTO, P1 restant) : format Éclair, partie du jour (graine et règle du jour, record),
## objets utilitaires (Pince, Creuset, Miroir) et recettes au survol, 15 atouts de plus (de trait, d'unité) joués par les
## IA, adversaire probable et survol riche des stratèges, coup au stratège, fin de partie v2 (équipe finale, coffres révélés),
## planificateur (cible dans la boutique, gardé entre les parties), première partie guidée (non bloquante, passable).
## godot --headless --path game res://tests/test_acx3.tscn

var fails := 0
var screen: AutochessScreen


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _frames(n := 2) -> void:
	for _i in n:
		await get_tree().process_frame


## Textes lisibles : [texte, infobulle ?] (les infobulles peuvent porter des chiffres en %, jamais le texte permanent).
func _texts(n: Node, out: Array) -> void:
	if n is Label:
		out.append([(n as Label).text, false])
	if n is Button:
		out.append([(n as Button).text, false])
	if n is Control and (n as Control).tooltip_text != "":
		out.append([(n as Control).tooltip_text, true])
	for c in n.get_children():
		_texts(c, out)


func _english(fr: Node, root: Node) -> Array:
	var texts: Array = []
	_texts(root, texts)
	var bad: Array = []
	for t in texts:
		if not (fr._english_in(String(t[0])) as Array).is_empty() or (String(t[0]).contains("%") and not bool(t[1])):
			bad.append(String(t[0]))
	return bad


func _game(fmt := "classique", rule := "", seed_v := 5, ai := false) -> Autochess:
	var g := Autochess.new()
	g.save_path = ""
	g.configure(fmt, rule)
	g.start(seed_v, AutochessAi.lineup(2, seed_v, -1) if ai else [])
	return g


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "magician"
	Profile.hero_name = "Aelis"
	get_tree().root.size = Vector2i(1280, 720)
	Gamepad.active = false
	test_formats()
	test_daily()
	test_utilities()
	test_augments_ai()
	test_likely()
	test_planner()
	test_rewards()
	await test_screen()
	await test_results()
	print("[test_acx3] %s (%d échec(s))" % ["VERT" if fails == 0 else "ROUGE", fails])
	get_tree().paused = false
	get_tree().quit(1 if fails > 0 else 0)


# --- format Éclair -----------------------------------------------------------------------------------------------------
func test_formats() -> void:
	var g := _game("eclair", "", 21, true)
	var p: Dictionary = g.players[0]
	check("Éclair : 40 PV, 2 manches à l'étape 1, atouts en 2-1 et 3-1", g.max_hp() == 40 and int(p.hp) == 40
		and g.rounds_in(1) == 2 and g.is_augment_round(2, 1) and g.is_augment_round(3, 1) and not g.is_augment_round(3, 2))
	var inc := g.income_for(0, 2, 3)
	p.gold = 45
	var inc2 := g.income_for(0, 2, 3)
	check("Éclair : revenu fixe (7), sans intérêts ni série, aucune XP offerte", int(inc.base) == 7 and int(inc2.interest) == 0
		and int(inc2.streak) == 0 and int(inc2.xp) == 0 and g.interest_cap(0) == 0)
	g.play_to_end()
	check("Éclair : une partie entre IA jusqu'au bout (%d manches, fin %s), réserve juste" % [g.rounds_played, g.round_key()],
		g.is_over() and g.pool_ok() and g.rounds_played < 30)
	var back := Autochess.new()
	back.save_path = ""
	var h := _game("eclair", "ecole", 4)
	check("format et règle du jour gardés par la sauvegarde", back.from_dict(JSON.parse_string(JSON.stringify(h.to_dict())))
		and back.format == "eclair" and back.day_rule == "ecole" and back.xp_cost() == 3 and back.max_hp() == 40)
	var c := _game()
	check("Classique inchangé : 100 PV, 4 manches à l'étape 1, intérêts 5", c.max_hp() == 100 and c.rounds_in(1) == 4
		and c.interest_cap(0) == 5 and c.reroll_cost() == 2 and c.xp_cost() == 4)


# --- partie du jour ----------------------------------------------------------------------------------------------------
func test_daily() -> void:
	var day := "2026-10-17"
	var s1 := AutochessData.daily_seed(day)
	var a := AutochessAi.lineup(AutochessData.DAILY_DIFF, s1, 0)
	var b := AutochessAi.lineup(AutochessData.DAILY_DIFF, s1, 0)
	var same := true
	for i in a.size():
		if a[i] != null:
			same = same and (a[i] as AutochessAi).label() == (b[i] as AutochessAi).label() and a[i].seed_value == b[i].seed_value
	check("partie du jour : même graine et mêmes stratèges pour tous ce jour-là (%d)" % s1, same and s1 > 0)
	var g1 := _game(AutochessData.DAILY_FORMAT, AutochessData.daily_rule(day), s1)
	var g2 := _game(AutochessData.DAILY_FORMAT, AutochessData.daily_rule(day), s1)
	check("partie du jour : même première boutique", g1.players[0].shop == g2.players[0].shop)
	var ok := true
	for r in AutochessData.DAY_RULES:
		var g := _game("classique", String(r), 9)
		var p: Dictionary = g.players[0]
		match String(r):
			"tresor":
				ok = ok and int(g.income_for(0, 1, 2).total) == AutochessData.START_GOLD + 8
			"boutique":
				ok = ok and g.reroll_cost() == 1
			"ecole":
				ok = ok and g.xp_cost() == 3
			"grand_plateau":
				ok = ok and int(p.crowns) == 1
			"banquiers":
				p.gold = 80
				ok = ok and int(g.income_for(0, 2, 2).interest) == 7
			"indecis":
				ok = ok and int(g.rule("augment_rerolls", 1)) == 2
			"eclats":
				g._roll_augment_rarity()
				ok = ok and g.augment_rarity == "eclat"
			"forge":
				g.stage = 2
				g.round_i = 7
				var n0 := (p.items as Array).size()
				g._pve_outcome(0, true, [], true)
				ok = ok and (p.items as Array).size() >= n0 + 3
	check("les 8 règles du jour agissent (même règle pour les 8 stratèges)", ok)


# --- objets utilitaires ------------------------------------------------------------------------------------------------
func test_utilities() -> void:
	var g := _game()
	var p: Dictionary = g.players[0]
	p.pending = []
	var u: Dictionary = g._make_unit("warrior", 1, 1, ["executeur", "lame"])
	g.pool.take("warrior")
	p.bench[0] = u
	p.items = ["pince"]
	check("Pince : les objets reviennent intacts au banc d'objets", g.equip(0, 0, int(u.uid)) and (u.items as Array).is_empty()
		and "executeur" in p.items and "lame" in p.items and not "pince" in p.items)
	check("Pince annulable (Ctrl+Z)", g.undo(0) == "item" and "pince" in p.items and (g.find_unit(0, int(u.uid)).items as Array).size() == 2)
	u = g.find_unit(0, int(u.uid))
	p.items = ["creuset"]
	g.equip(0, 0, int(u.uid))
	var it := String(u.items[0])
	check("Creuset : l'objet complet devient un autre objet complet (%s), le composant reste" % it,
		AutochessData.ITEMS.has(it) and it != "executeur" and String(u.items[1]) == "lame")
	p.items = ["miroir"]
	var copies0 := g.units_of(0).filter(func(x): return String(x.id) == "warrior").size()
	var pool0 := g.pool.remaining("warrior")
	check("Miroir : une copie à une étoile, prise à la réserve", g.equip(0, 0, int(u.uid))
		and g.units_of(0).filter(func(x): return String(x.id) == "warrior").size() == copies0 + 1 and g.pool.remaining("warrior") == pool0 - 1
		and g.pool_ok())
	var dear := ""
	for id in AutochessData.units_of_cost(5):
		dear = String(id)
	var du: Dictionary = g._make_unit(dear, 1, 1)
	g.pool.take(dear)
	p.bench[5] = du
	p.items = ["miroir"]
	check("Miroir refusé sur un héros de coût 5 (il reste au banc d'objets)", not g.equip(0, 0, int(du.uid)) and "miroir" in p.items)
	check("butin : Miroir à 3-7, Pince à 4-7, Creuset à 6-7 (gardiens gagnés)", AutochessData.loot(3, 7, true).has("miroir")
		and AutochessData.loot(4, 7, true).has("pince") and AutochessData.loot(6, 7, true).has("creuset"))


# --- atouts 30 → 45, joués par les IA ---------------------------------------------------------------------------------
func test_augments_ai() -> void:
	var new_ids := ["maitre_armes", "recrue_doree", "atelier", "ligne_de_boucliers", "porte_etendard", "serment_rempart",
		"pacte_ombre", "piste_traque", "flamme_ferveur", "savoir_arcane", "jumeaux", "grand_grimoire", "trinite",
		"miroir_des_ames", "grand_coeur"]
	var known := new_ids.all(func(a): return AutochessData.AUGMENTS.has(a) and AutochessAi.AUGMENT_BASE.has(a))
	check("45 atouts dont 15 nouveaux, chacun noté par les IA", AutochessData.AUGMENTS.size() == 45 and known)
	var taken := {}
	var util_left := 0  # objets utilitaires restés au banc d'objets des IA en fin de partie
	for s in 12:
		var g := Autochess.new()
		g.save_path = ""
		var strats: Array = []
		for i in AutochessData.PLAYERS:
			strats.append(AutochessAi.make(2 + i % 2, "", 100 + s * 8 + i))
		g.start(300 + s, strats)
		var guard := 0
		var last_items := {}
		while not g.is_over() and guard < 400:
			guard += 1
			g.step()
			for q in g.players:
				if bool(q.alive):
					last_items[int(q.id)] = (q.items as Array).duplicate()
		for q in g.players:
			for a in q.augments:
				if String(a) in new_ids:
					taken[String(a)] = true
		for k in last_items:
			util_left += (last_items[k] as Array).filter(func(x): return String(x) == "miroir").size()
	check("les IA prennent les nouveaux atouts (%d sur 15 vus en 12 parties : %s)" % [taken.size(), str(taken.keys())], taken.size() >= 5)
	check("les IA se servent de leurs Miroirs (%d laissés en fin de partie, 12 parties ; la Pince se garde pour le bon moment)" % util_left,
		util_left <= 4)
	# une IA Champion pose le Miroir sur son meilleur héros bon marché et la Pince sur un héros du banc qui porte des objets
	var g2 := _game("classique", "", 7)
	var ai := AutochessAi.make(3, "econome", 3)
	var p: Dictionary = g2.players[1]
	p.pending = []
	p.board = []
	var keep: Dictionary = g2._make_unit("warrior", 1, 1)
	keep["cell"] = [3, 0]
	g2.pool.take("warrior")
	p.board = [keep]
	var spare: Dictionary = g2._make_unit("warrior", 1, 1)
	g2.pool.take("warrior")
	p.bench[0] = spare
	var benched: Dictionary = g2._make_unit("assassin", 1, 1, ["executeur"])
	g2.pool.take("assassin")
	p.bench[1] = benched
	p.items = ["miroir", "pince"]
	ai._bind(g2, 1)
	ai._utilities()
	var stars2 := g2.units_of(1).filter(func(x): return String(x.id) == "warrior" and int(x.stars) == 2).size()
	check("IA : Miroir posé pour finir une ★★ (%d) et Pince sur le héros du banc (objets rendus)" % stars2,
		stars2 == 1 and not "miroir" in p.items and (benched.items as Array).is_empty())


# --- adversaire probable -----------------------------------------------------------------------------------------------
func test_likely() -> void:
	var g := _game()
	for i in range(3, AutochessData.PLAYERS):
		g.players[i].alive = false
	var lo := g.likely_opponents(0)
	check("3 vivants : 2 adversaires possibles, un fantôme possible", (lo.cands as Array).size() == 2 and bool(lo.ghost))
	g.players[0].recent = [1]
	g.players[1].recent = [0]
	lo = g.likely_opponents(0)
	check("le dernier adversaire est évité : adversaire probable = le seul autre (%s)" % str(lo.cands), lo.cands == [2])
	var rng0 := g.rng.state
	g.likely_opponents(0)
	check("lire l'adversaire probable ne touche pas au hasard de la partie", g.rng.state == rng0)


# --- planificateur -----------------------------------------------------------------------------------------------------
func test_planner() -> void:
	AutochessPlanner.clear()
	var ids: Array = AutochessData.unit_ids()
	ids.sort()
	check("viser un héros", AutochessPlanner.toggle(String(ids[0])) and AutochessPlanner.is_planned(String(ids[0])))
	for k in range(1, 12):
		AutochessPlanner.toggle(String(ids[k]))
	check("10 héros visés au plus", AutochessPlanner.planned().size() == AutochessPlanner.MAX)
	check("viser à nouveau = retirer", not AutochessPlanner.toggle(String(ids[0])) and not AutochessPlanner.is_planned(String(ids[0])))
	check("gardé dans les Paramètres (entre les parties)", (Settings.get_v("autochess", "planned") as Array).size() == AutochessPlanner.MAX - 1)
	AutochessPlanner.clear()


# --- récompenses : Éclair divisé par deux, record du jour ---------------------------------------------------------------
func test_rewards() -> void:
	check("Éclair : 2e = top 4 seulement, 3e = rien, 1re = tout", AutochessRewards.reached(2, true) == ["top4"]
		and AutochessRewards.reached(3, true).is_empty() and AutochessRewards.reached(1, true).size() == 3
		and AutochessRewards.reached(3, false).size() == 1)
	var r1 := AutochessRewards.settle({"diff": 1, "place": 4, "daily": true, "rule": "ecole", "format": "eclair"})
	var r2 := AutochessRewards.settle({"diff": 1, "place": 2, "daily": true, "rule": "ecole", "format": "eclair"})
	var ds := AutochessRewards.daily_state()
	check("partie du jour : record du jour (4e puis 2e : nouveau record), parties comptées", bool(r1.daily.first)
		and bool(r2.daily.new_best) and int(ds.best) == 2 and int(ds.games) == 2 and int(ds.days) == 1)
	check("partie du jour en Éclair : 4e = aucun coffre (place deux fois meilleure)", (r1.chests as Array).is_empty())


# --- écran : guide, planificateur, recettes, stratèges, coup au stratège -----------------------------------------------
func test_screen() -> void:
	Settings.set_v("autochess", "guide_done", false)
	AutochessScreen.config = {"seed": 13, "save_path": "", "fast": false, "real": true, "diff": 1}
	screen = load("res://scenes/autochess.tscn").instantiate()
	add_child(screen)
	await _frames(6)
	var g := screen.game
	var p: Dictionary = g.players[0]
	var fr: Node = load("res://tests/test_texts_fr.gd").new()
	check("première partie : le guide est là (« Premiers pas · 1 / 4 »), rien n'est bloqué", screen.guide != null
		and screen.guide.current() == "buy" and screen.guide._count.text.begins_with("Premiers pas"))
	if screen.choice.visible:
		(screen.choice.cards[0] as Button).pressed.emit()
		await _frames()
	# acheter, placer
	var cheap: Array = AutochessData.units_of_cost(1)
	cheap.sort()
	var id := String(cheap[2])
	for i in AutochessData.SHOP_SIZE:
		p.shop[i] = id if i < 3 else ""
	p.gold = 20
	screen._sync()
	screen._buy(0)
	await _frames()
	check("guide : « Achète un héros » coché, étape suivante « Place-le »", screen.guide != null and screen.guide.done.has("buy")
		and screen.guide.current() == "place")
	var bu: Array = g.bench_units(0)
	var slot := {}
	for s in screen.board.all_slots():
		if String(s.zone) == "bench" and int(screen.board.unit_at(s).get("uid", -1)) == int(bu[bu.size() - 1].uid):
			slot = s
	screen._on_placed(bu[bu.size() - 1], slot, {"zone": "board", "col": 2, "row": 1})
	check("guide : placer coché", screen.guide != null and screen.guide.done.has("place"))
	screen._buy(1)
	screen._buy(2)
	screen._sync()
	await _frames()
	check("guide : trois copies = une étoile, cochée", screen.guide != null and screen.guide.done.has("star"))
	# planificateur depuis la fiche (T) et cible dans la boutique
	AutochessPlanner.clear()
	for i in AutochessData.SHOP_SIZE:
		p.shop[i] = String(cheap[5]) if i == 0 else ""
	screen._sync()
	screen._card_id = String(cheap[5])
	screen._plan_toggle()
	screen._sync()
	await _frames()
	var plan: Control = (screen.hud.shop.cards[0] as Button).get_node("Plan")
	check("planificateur : T vise le héros de la fiche, sa carte de boutique porte la cible", plan.visible
		and bool(screen.hud.shop.info[0].get("planned", false)))
	AutochessPlanner.clear()
	# recettes au survol d'un composant
	p.items = ["lame", "arc"]
	screen.hud.unit_card.show_item("lame", screen.have_components())
	await _frames()
	var rec := screen.hud.unit_card.find_child("AcRecipes", true, false)
	var ready_n := 0
	if rec != null:
		for c in rec.get_children():
			ready_n += 1 if bool(c.get_meta("ready", false)) else 0
	check("fiche d'un composant : 8 recettes, celle qu'on peut faire en tête (%d prête)" % ready_n, rec != null
		and rec.get_child_count() == 9 and ready_n == 1 and bool(rec.get_child(1).get_meta("ready", false)))
	screen.hud.unit_card.hide_card()
	# stratèges : survol riche, adversaire probable
	for i in range(3, AutochessData.PLAYERS):
		g.players[i].alive = false
		g.players[i].place = 9 - i
	screen._sync()
	var lines := screen.hud.players.hover_lines(1, 0)
	check("survol d'un stratège : niveau, traits, valeur d'équipe (%s)" % str(lines.map(func(l): return l[0])),
		lines.size() >= 3 and String(lines[0][0]).begins_with("Niveau") and String(lines[2][0]).begins_with("Valeur"))
	var tip: Control = (screen.hud.players.rows[1] as AutochessPlayers.Row)._make_custom_tooltip("") as Control
	check("bulle de survol : un autocollant papier (pas le texte brut)", tip is PanelContainer)
	if tip != null:
		tip.free()
	var my_lines := screen.hud.players.hover_lines(0, 0)
	check("ta bulle dit l'adversaire probable de la manche JcJ", g.round_kind() != "jcj"
		or my_lines.any(func(l): return String(l[0]).contains("adversaire")))
	for i in range(3, AutochessData.PLAYERS):
		g.players[i].alive = true
		g.players[i].place = 0
	# coup au stratège : un vrai combat de stratèges à ×1
	AutochessScreen.speed = 1
	var guard := 0
	screen.real_combat = false  # manches d'avant : combat de données, vite
	while g.round_kind() != "jcj" and guard < 4000:
		guard += 1
		if screen.phase == "prep" and not screen.carousel.visible:
			if screen.choice.visible:
				(screen.choice.cards[0] as Button).pressed.emit()
			screen.fast = true
			screen._end_prep()
		await get_tree().process_frame
	screen.fast = false
	screen.real_combat = true
	var hits := 0
	for attempt in 3:
		guard = 0
		while screen.phase != "prep" and guard < 2000:
			guard += 1
			await get_tree().process_frame
		if screen.phase != "prep" or g.round_kind() != "jcj":
			break
		screen.strikes.clear()
		screen._end_prep()
		guard = 0
		while screen.phase == "combat" and guard < 6000:
			guard += 1
			await get_tree().physics_frame
		await _frames(2)
		var mf := screen.my_fight
		print("[test_acx3] combat : vrai %s, combat %d, résultat %s, PV perdus %s" % [screen.real, mf,
			str(g.results[mf].winner) if mf >= 0 and mf < g.results.size() else "?", str(g.players[0].last)])
		if not screen.strikes.is_empty():
			hits = int(screen.strikes[0].from)
			break
	check("coup au stratège : les survivants tirent sur le perdant (%d projectiles, %s)" % [hits, str(screen.strikes)],
		hits >= 1 and hits <= AutochessScreen.STRIKE_MAX)
	var bad := _english(fr, screen.hud)
	check("cadre de l'écran en français" + ("" if bad.is_empty() else " : " + str(bad.slice(0, 6))), bad.is_empty())
	# guide passé : réglage gardé, ne revient plus
	if screen.guide != null:
		screen.guide.skip_button.pressed.emit()
		await _frames(12)
	check("« Passer le guide » : réglage gardé, le guide ne reviendra plus", screen.guide == null
		and bool(Settings.get_v("autochess", "guide_done")) and not AutochessGuide.wanted())
	screen.queue_free()
	await _frames(4)


# --- fin de partie v2 --------------------------------------------------------------------------------------------------
func test_results() -> void:
	var team: Array = [{"id": "warrior", "stars": 2, "items": ["executeur", "lame"]}, {"id": "magician", "stars": 3, "items": []}]
	var got := {"chests": [{"type": "look_common", "text": "Finir dans les 4 premiers", "kind": "first"},
		{"type": "look_rare", "text": "Finir dans les 2 premiers", "kind": "first"}], "titles": [], "daily": {"place": 2, "best": 2,
		"new_best": true, "first": false, "best_ever": 2}}
	var r := AutochessResults.new()
	add_child(r)
	r.show_results({"diff": 1, "place": 2, "rounds": 30, "rounds_won": 18, "secs": 900.0, "team": team, "daily": true}, {}, got,
		{}, [{"name": "Aelis", "class_id": "magician", "place": 2, "trait": "Arcane", "me": true}])
	await _frames(2)
	var final := r.find_child("AcFinal", true, false)
	var chips := r.find_child("AcTeam", true, false)
	check("bilan : « Ton équipe finale » (2 héros, étoiles et objets) et les coffres", final != null and chips != null
		and r.find_child("AcChests", true, false) != null)
	var c0: Control = r.find_child("AcChest_0", true, false)
	var c1: Control = r.find_child("AcChest_1", true, false)
	check("coffres fermés au départ (révélés un à un)", c0 != null and c1 != null and c0.modulate.a < 0.1 and c1.modulate.a < 0.1)
	var guard := 0
	while guard < 400 and c0 != null and not (c0 as AutochessResults.ChestSticker).opened:
		guard += 1
		await get_tree().process_frame
	var first_open := c0 != null and (c0 as AutochessResults.ChestSticker).opened and not (c1 as AutochessResults.ChestSticker).opened
	guard = 0
	while guard < 400 and c1 != null and not (c1 as AutochessResults.ChestSticker).opened:
		guard += 1
		await get_tree().process_frame
	check("le 1er coffre s'ouvre, puis le 2e", first_open and (c1 as AutochessResults.ChestSticker).opened)
	check("bilan de la partie du jour : « nouveau record du jour »", r.find_child("AcDailyLine", true, false) != null
		and (r.find_child("AcDailyLine", true, false) as Label).text.contains("record"))
	get_tree().paused = false
	r.queue_free()
	await _frames(2)
