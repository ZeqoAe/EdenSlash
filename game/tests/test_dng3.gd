extends Node
## Lot DNG-3 (backlog BM-DNG, P1) : étoiles de donjon (DungeonStars), relève (Relief), « S'entraîner » (BossPractice), Ruée
## chronométrée (RushBoard, fil des temps), Siège lisible (SiegeScore, tableau des trois, fureur sur la barre, horloge), palette
## des télégraphes, mur d'arène mandarine, « Autre boss » (le menu principal rouvert sur la page Donjons), bilans et HUD dans
## 1280×720 et 1600×900. Rien ne touche à l'équilibre : PV fixes, butin et verrous inchangés.
## godot --headless --path game res://tests/test_dng3.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = false
	Settings.reset_all()
	Profile.reset_all()
	_test_stars()
	_test_relief_rules()
	_test_rush_board()
	_test_siege_score()
	_test_palette()
	await _test_relief_real()
	await _test_win_stars()
	await _test_practice()
	await _test_rush_trail()
	await _test_siege_hud()
	await _test_pages()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


# --- étoiles ---------------------------------------------------------------------------------------------------
func _test_stars() -> void:
	Profile.reset_all()
	var plain := ""
	var breaker := ""
	for id in BossLibrary.ids():
		var t: Array = BossLibrary.brick_types(String(id))
		if plain == "" and not t.any(func(b): return String(b) in DungeonStars.BREAK_BRICKS):
			plain = String(id)
		if breaker == "" and t.any(func(b): return String(b) in DungeonStars.BREAK_BRICKS):
			breaker = String(id)
	check("boss sans objet à casser (%s) : 7:30 / 6:15 / 6:15" % plain, DungeonStars.par(plain, 0) == 450.0 and DungeonStars.par(plain, 1) == 375.0 and DungeonStars.par(plain, 2) == 375.0)
	check("boss à totems, cristaux ou tourelles (%s) : 45 s de plus, au quart de minute" % breaker, DungeonStars.par(breaker, 0) == 495.0 and fmod(DungeonStars.par(breaker, 1), 15.0) == 0.0)
	check("nom de l'étoile du temps : « Sous 7:30 »", DungeonStars.star_name(1, plain, 0) == "Sous 7:30")
	var none := DungeonStars.score(plain, 0, false, true, 100.0, 0)
	check("défaite : aucune étoile", (none.stars as Array).is_empty() and DungeonStars.count(plain, 0) == 0)
	DungeonStars.ally_fell = false
	var a := DungeonStars.score(plain, 0, true, false, 100.0, 0)
	check("reprise au boss : le boss tombe et personne ne tombe, pas le temps (%s)" % [a.stars], a.stars == ["clear", "safe"] and a.new == ["clear", "safe"])
	var b := DungeonStars.score(plain, 0, true, true, 300.0, 1)
	check("relève utilisée : pas « Personne ne tombe » ; le temps neuf seul (%s / %s)" % [b.stars, b.new], b.stars == ["clear", "time"] and b.new == ["time"])
	check("trois étoiles : titre « Étoilé » (premier palier)", "Étoilé" in (b.titles as Array) and "Étoilé" in Profile.extra_titles)
	var c := DungeonStars.score(plain, 0, true, true, 100.0, 0)
	check("une étoile ne se gagne qu'une fois, le titre aussi", (c.new as Array).is_empty() and (c.titles as Array).is_empty())
	DungeonStars.ally_fell = true
	var d := DungeonStars.score(plain, 1, true, true, 100.0, 0)
	check("un allié tombé : pas « Personne ne tombe »", not "safe" in (d.stars as Array))
	DungeonStars.ally_fell = false
	check("lignes du bilan : trois objectifs, « nouvelle » sur les neuves", DungeonStars.spec_rows(plain, 0, b).size() == 3 and DungeonStars.spec_rows(plain, 0, b)[1].new and not DungeonStars.spec_rows(plain, 0, b)[0].new)
	check("compteurs : 3 + 2 étoiles, 1 donjon à trois étoiles", DungeonStars.total() == 5 and DungeonStars.full_count() == 1 and DungeonStars.glyphs(plain, 0) == "★★★")
	check("prochain palier annoncé (Constellation)", DungeonStars.next_line().contains("Constellation"))
	var crystals := int(Profile.materials.get("crystal", 0))
	check("aucune économie nouvelle : pas un cristal, pas un coffre hors apparence", crystals == 0 and Profile.reward_chests.all(func(ch): return String(ch.get("type", "")).begins_with("look")))


# --- relève : qui y a droit --------------------------------------------------------------------------------------
func _test_relief_rules() -> void:
	Tower.start_dungeon("warrior", "limestone", 0, [], "mori")
	check("donjon Normal : une relève au départ", Relief.allowed() and Relief.left == 1 and Relief.pill_text() == "Relève 1")
	Tower.start_dungeon("warrior", "limestone", 2, [], "mori")
	check("donjon Mythique : aucune relève", not Relief.allowed() and Relief.left == 0 and Relief.pill_text() == "")
	Tower.start("warrior", 3, 1)
	check("Tour Hardcore : aucune relève", not Relief.allowed())
	Tower.start("warrior", 2, 1)
	check("Tour Difficile : une relève", Relief.allowed() and Relief.left == 1)
	Tower.start_siege("warrior", "limestone", 0, [])
	check("Siège : aucune relève (une seule vie)", not Relief.allowed())
	Tower.start_dungeon("warrior", "limestone", 1, [], "mori")
	Relief.left = 0
	Relief.on_boss(true)
	check("un lieutenant ne rend pas la relève", Relief.left == 0)
	Relief.on_boss(false)
	check("un boss la rend (une au plus)", Relief.left == 1)
	Relief.on_boss(false)
	check("jamais deux d'avance", Relief.left == 1)
	Relief.enabled = false
	check("coupée : aucune", not Relief.allowed())
	Relief.enabled = true
	Tower.active = false
	Run.active = false


# --- Ruée : classement local ---------------------------------------------------------------------------------------
func _test_rush_board() -> void:
	Profile.reset_all()
	Profile.records["rush_prev"] = 12345
	var s := Rush.current_seed()
	var lineup := Rush.lineup_for(s).duplicate()
	RushBoard.add(s, 0, 700.0, [], 12345)
	var r2 := RushBoard.add(s, 0, 650.0, ["blind"], 12345)
	check("meilleur temps : 1er, ancien meilleur noté", int(r2.rank) == 1 and float(r2.best) == 700.0)
	for i in 5:
		RushBoard.add(s, 0, 800.0 + i, [], 12345)
	var top := RushBoard.top(s, 0)
	check("classement : 5 temps au plus, le plus rapide d'abord", top.size() == 5 and float(top[0].t) == 650.0 and float(top[4].t) <= 802.0)
	var r3 := RushBoard.add(s, 0, 999.0, [], 12345)
	check("trop lent : hors classement", int(r3.rank) == 0)
	check("lignes du bilan : « Meilleur temps sur le tirage »", RushBoard.lines(r2)[0].begins_with("Meilleur temps sur le tirage n° %d" % s))
	check("texte du classement : « 1. 10:50 · aujourd'hui · À l'aveugle »", RushBoard.rows_text(s, 0, 1)[0] == "1. 10:50 · aujourd'hui · %s" % Rush.MODS.blind.name)
	Rush.reroll()
	check("nouveau tirage : la graine change", Rush.current_seed() != s)
	var best := RushBoard.best_draws(0, 3)
	check("tes tirages les plus rapides", best.size() == 1 and int(best[0].seed) == s and int(best[0].prev) == 12345)
	RushBoard.replay(s, int(best[0].prev))
	check("« Rejouer ce tirage » : même graine, mêmes huit boss dans le même ordre", Rush.current_seed() == s and Rush.lineup_for(s) == lineup)
	Profile.reset_all()


# --- Siège : tableau des trois ---------------------------------------------------------------------------------------
func _test_siege_score() -> void:
	SiegeScore.reset()
	var me := Player.new()
	var ally := ClassRival.new()
	ally.display_name = "Prêtre"
	var boss := Monster.new()
	SiegeScore.hero(me, "me", true)
	SiegeScore.hero(ally, "priest")
	SiegeScore.track(boss, true)
	boss.damaged.emit(300.0, me)
	boss.damaged.emit(900.0, ally)
	boss.damaged.emit(50.0, null)
	var rows := SiegeScore.rows()
	check("dégâts au boss par héros, le plus gros d'abord (%s)" % [rows], rows.size() == 2 and String(rows[0].name) == "Prêtre" and float(rows[0].dmg) == 900.0 and float(rows[1].dmg) == 300.0 and bool(rows[1].me))
	SiegeScore.fall(ally)
	boss.died.emit(boss, me)
	rows = SiegeScore.rows()
	check("chute et dernier coup notés", int(rows[0].falls) == 1 and bool(rows[1].last) and SiegeScore.last_hit == "Toi")
	var ally2 := ClassRival.new()
	ally2.display_name = "Prêtre"
	ally.is_dead = true
	SiegeScore.hero(ally2, "priest")
	check("allié remplacé (chacun pour soi) : il reprend sa ligne", SiegeScore.heroes.size() == 2)
	check("ligne du bilan : « Dégâts au boss : Prêtre en tête (75 %) · dernier coup : toi »", DungeonResults.siege_board_line(SiegeScore.rows()) == "Dégâts au boss : Prêtre en tête (75 %) · dernier coup : toi")
	check("format des dégâts : 1,2 M · 845 k · 920", SiegeScore.fmt(1.24e6) == "1,2 M" and SiegeScore.fmt(845000.0) == "845 k" and SiegeScore.fmt(920.0) == "920")
	for n in [me, ally, ally2, boss]:
		n.free()
	SiegeScore.reset()


# --- télégraphes : palette réglable, mur mandarine -------------------------------------------------------------------
func _test_palette() -> void:
	check("défaut : fraise, intensité 100 %", Telegraph.palette_key() == "fraise" and Telegraph.danger_color().is_equal_approx(Telegraph.COLOR) and Telegraph.intensity() == 1.0)
	Settings.set_v("interface", "colorblind", true)
	check("« daltoniens » coché, palette auto : mandarine", Telegraph.palette_key() == "mandarine")
	Settings.set_v("interface", "tele_palette", "amethyste")
	check("palette choisie : améthyste", Telegraph.danger_color().is_equal_approx(UiTheme.color("bonbon.amethyste.base")))
	var t := Telegraph.spawn(self, Vector3.ZERO, 0.0, {"shape": "circle", "radius": 4.0, "delay": 5.0, "damage": 10.0})
	check("zone de danger v2 peinte dans la palette choisie", t.v2 and t.color.is_equal_approx(UiTheme.color("bonbon.amethyste.base")))
	var safe := Telegraph.spawn(self, Vector3.ZERO, 0.0, {"shape": "circle", "radius": 4.0, "delay": 5.0, "damage": 0.0, "color": Color(0.3, 1.0, 0.45)})
	check("zone sûre : reste pomme, quelle que soit la palette", safe.safe and safe.color.is_equal_approx(Color(0.3, 1.0, 0.45)))
	Settings.set_v("interface", "tele_intensity", 9.0)
	check("intensité bornée (150 % au plus)", Telegraph.intensity() == Telegraph.INTENSITY_MAX)
	var strong := Telegraph.spawn(self, Vector3.ZERO, 0.0, {"shape": "circle", "radius": 4.0, "delay": 5.0, "damage": 10.0})
	var fill: float = (strong._fill.material_override as StandardMaterial3D).albedo_color.a
	check("intensité haute : le cœur reste transparent (%.2f ≤ %.2f)" % [fill, Telegraph.ALPHA_CAP], fill <= Telegraph.ALPHA_CAP + 0.001 and fill > Telegraph.FILL_ALPHA)
	for n in [t, safe, strong]:
		n.queue_free()
	Settings.set_v("interface", "tele_palette", "auto")
	Settings.set_v("interface", "tele_intensity", 1.0)
	Settings.set_v("interface", "colorblind", false)
	check("mur d'arène des boss : mandarine", BossBricks.ArenaWall.WALL_COLOR.is_equal_approx(UiTheme.color("bonbon.mandarine.base")))


# --- parties réelles -------------------------------------------------------------------------------------------------
func _world() -> Node:
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	return world


func _panel(secs: float) -> ResultsPanel:
	var t := 0.0
	while t < secs:
		var p := get_tree().get_first_node_in_group("results_panel")
		if p != null:
			await get_tree().create_timer(0.6, true, false, true).timeout
			return p as ResultsPanel
		await get_tree().create_timer(0.25, true, false, true).timeout
		t += 0.25
	return null


func _close(world: Node, panel: Node) -> void:
	get_tree().paused = false
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	if is_instance_valid(world):
		world.queue_free()
	await get_tree().create_timer(0.4).timeout
	Tower.active = false
	Run.active = false
	BossPractice.active = false


func _setup_profile() -> void:
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 1
	Profile.save_profile()  # Tower.finish recharge la sauvegarde


## Un coup fatal (l'esquive ou un bouclier peut l'ignorer : on recommence) ; s'arrête dès que le héros est à terre.
func _kill(p: Player, by: Combatant) -> void:
	for i in 30:
		if p.is_dead:
			return
		p.take_damage(p.max_hp * 50.0, by)
		await get_tree().create_timer(0.2).timeout


func _in(r: Rect2, vp: Vector2) -> bool:
	return r.position.x >= -1.0 and r.position.y >= -1.0 and r.end.x <= vp.x + 1.0 and r.end.y <= vp.y + 1.0


## Relève en partie réelle : chute devant le boss en Normal -> le héros se relève (moitié des PV, intouchable un instant) ; la
## pastille « Relève 1 » collée aux PV ; 2e chute -> bilan : Réessayer le boss · S'entraîner · Retour au menu.
func _test_relief_real() -> void:
	_setup_profile()
	Tower.start_dungeon("warrior", "limestone", 0, [], "mori", Dungeons.ROOMS.size())
	var world: Node = await _world()
	var td: TowerDirector = world.director.tower
	var p: Player = world.player
	var hud: Hud = world.hud
	var dh: DngHud = hud._boss_bar.extra
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = res
		await get_tree().create_timer(0.5).timeout
		var pill := dh.relief
		var pr := pill.get_global_rect() if pill != null else Rect2()
		var gr: Rect2 = hud._hp_orb.get_global_rect()
		check("%dx%d : pastille « Relève 1 » collée aux PV (%s / %s), dans l'écran, sans les recouvrir" % [res.x, res.y, pr, gr], pill != null and pill.is_visible_in_tree()
			and pill.text == "Relève 1" and _in(pr, Vector2(res)) and not pr.intersects(gr) and pr.grow(40.0).intersects(gr))
	var boss: Monster = td._boss
	await _kill(p, boss)
	await get_tree().create_timer(Relief.DELAY + 0.5).timeout
	check("1re chute : relevé (PV %.0f %%), pas de bilan" % (100.0 * p.hp / p.max_hp), not p.is_dead and absf(p.hp / p.max_hp - Relief.HP_BACK) < 0.06
		and get_tree().get_first_node_in_group("results_panel") == null)
	check("relève utilisée : compteur 0, pastille « Relève 0 »", Relief.left == 0 and Relief.used == 1 and dh.relief.text == "Relève 0")
	check("intouchable un instant après la relève", p.is_invulnerable())
	await get_tree().create_timer(Relief.SHIELD + 0.2).timeout
	boss.brain.note_cast("meteors")
	await _kill(p, boss)
	var panel := await _panel(12.0)
	check("2e chute : bilan du donjon", panel is DungeonResults)
	if panel != null:
		var texts: Array = panel.buttons.map(func(b): return b.text)
		check("boutons : Réessayer le boss · S'entraîner · Retour au menu (%s)" % [texts], texts == ["Réessayer le boss", "S'entraîner", "Retour au menu"])
		check("bilan d'échec : « Ce qui t'a battu »", panel.defeat_box != null)
	get_tree().root.size = Vector2i(1600, 900)
	await _close(world, panel)


## Victoire (reprise au boss) : étoiles au bilan (le boss tombe, personne ne tombe ; pas le temps : reprise), « Autre boss ».
func _test_win_stars() -> void:
	_setup_profile()
	get_tree().root.size = Vector2i(1280, 720)  # (le bilan se mesure à son ouverture : la fenêtre la plus petite d'abord)
	Tower.start_dungeon("warrior", "limestone", 0, [], "mori", Dungeons.ROOMS.size())
	var world: Node = await _world()
	var td: TowerDirector = world.director.tower
	var p: Player = world.player
	p.dev_invincible = true
	var boss: Monster = td._boss
	var hp0 := boss.max_hp
	check("PV fixes du boss inchangés (Dungeons.boss_hp × le boss)", is_equal_approx(hp0, BossLibrary.hp("mori", Tower.level_for(3) + 1, 0)))
	boss.take_damage(boss.max_hp * 50.0, p)
	await get_tree().create_timer(0.3).timeout
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and not m.is_dead:
			m.take_damage(m.max_hp * 50.0, p)
	var panel := await _panel(12.0)
	check("victoire : bilan", panel is DungeonResults)
	check("étoiles écrites après le rechargement du profil : ★ ☆ ★", DungeonStars.got("mori", 0) == ["clear", "safe"])
	check("premier palier : titre « Étoilé » pas encore (2 étoiles)", not "Étoilé" in Profile.extra_titles)
	if panel != null:
		var texts: Array = panel.buttons.map(func(b): return b.text)
		check("boutons de victoire : Rejouer · Autre boss · Retour au menu (%s)" % [texts], texts == ["Rejouer (même donjon)", "Autre boss", "Retour au menu"])
		var labels: Array = panel.find_children("*", "Label", true, false).map(func(l): return String(l.text))
		check("bilan : les trois objectifs du donjon (« Sous 7:30 »…)", labels.any(func(t): return t.contains("Sous %s" % BestTimes.fmt(DungeonStars.par("mori", 0))))
			and labels.any(func(t): return t.contains("Personne ne tombe")))
		for res in [Vector2i(1280, 720)]:
			var out: Array = []
			for n in panel.find_children("*", "Control", true, false):
				var c := n as Control
				if c.is_visible_in_tree() and c.size.x > 2.0 and not _scrolled(c) and not _in(c.get_global_rect(), Vector2(res)):
					out.append(c.get_class())
			check("%dx%d : bilan de victoire dans l'écran (%s)" % [res.x, res.y, out.slice(0, 3)], out.is_empty())
	get_tree().root.size = Vector2i(1600, 900)
	await _close(world, panel)


func _scrolled(c: Node) -> bool:
	var n := c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false


## « S'entraîner » : invincible, mécaniques à rejouer, K.O. sans bilan, boss vaincu qui revient, rien d'écrit à la sortie.
func _test_practice() -> void:
	_setup_profile()
	Profile.load_profile()  # (les nombres relus du fichier : même forme qu'après la sortie)
	var before := JSON.stringify(Profile.records)
	BossPractice.start("warrior", "mori", 0)
	check("entraînement : salle du boss, aucune relève", BossPractice.active and Tower.start_floor == 3 and not Relief.allowed())
	var world: Node = await _world()
	var td: TowerDirector = world.director.tower
	var p: Player = world.player
	var hud: Hud = world.hud
	var dh: DngHud = hud._boss_bar.extra
	await get_tree().create_timer(0.5).timeout
	var boss: Monster = td._boss
	check("panneau d'entraînement dans la pile de gauche (%s)" % [dh.practice != null], dh.practice != null and dh.practice.is_visible_in_tree())
	var mech := 0
	if dh.practice_body != null:
		for b in dh.practice_body.get_children():
			if b is Button and b.has_meta("type"):
				mech += 1
	check("un bouton « Rejouer » par mécanique du boss (%d)" % mech, boss != null and mech == boss.brain.bricks.size())
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = res
		await get_tree().create_timer(0.5).timeout
		var r := dh.practice.get_global_rect()
		check("%dx%d : panneau dans l'écran, au-dessus des PV (%s)" % [res.x, res.y, r], _in(r, Vector2(res)) and r.end.y <= hud._hp_orb.get_global_rect().position.y + 1.0
			and r.end.x <= (hud._boss_bar.panel.get_global_rect().position.x if hud._boss_bar.visible else r.end.x) + 1.0)
	check("héros invincible par défaut", p.immortal)
	p.take_damage(p.max_hp * 50.0, boss)
	check("invincible : un coup fatal ne fait rien", not p.is_dead and p.hp >= p.max_hp - 1.0)
	var periodic := -1
	for i in boss.brain.bricks.size():
		if String(boss.brain.bricks[i].kind) == "every":
			periodic = i
	if periodic >= 0:
		boss.brain._brick_t[periodic] = 99.0
		BossPractice.replay(boss, periodic)
		check("« Rejouer » : la mécanique part tout de suite", float(boss.brain._brick_t[periodic]) <= 0.0 or float(boss.brain._brick_t[periodic]) > 5.0)
	BossPractice.god = false
	await get_tree().create_timer(0.5).timeout
	check("invincible décoché", not p.immortal)
	await _kill(p, boss)
	await get_tree().create_timer(1.6).timeout
	check("K.O. à l'entraînement : relevé aussitôt, pas de bilan", not p.is_dead and get_tree().get_first_node_in_group("results_panel") == null)
	BossPractice.god = true
	boss.take_damage(boss.max_hp * 50.0, p)
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and not m.is_dead:
			m.take_damage(m.max_hp * 50.0, p)
	await get_tree().create_timer(1.5).timeout
	check("boss vaincu : il revient à pleine vie, pas de bilan", is_instance_valid(td._boss) and not td._boss.is_dead and td._boss != boss
		and get_tree().get_first_node_in_group("results_panel") == null)
	BossPractice.refill(td._boss)
	check("« Boss à pleine vie »", is_equal_approx(td._boss.hp, td._boss.max_hp))
	BossPractice.leave(get_tree(), false)
	check("sortie : sauvegarde rechargée telle qu'avant (ni rencontre, ni record, ni étoile)", JSON.stringify(Profile.records) == before)
	check("sortie : le menu principal rouvrira la page Donjons sur ce boss", DungeonPage.lobby_request == "dungeon" and DungeonPage.sel == "mori")
	DungeonPage.lobby_request = ""
	await _close(world, null)


## Ruée : fil des temps (8 lignes, celui en cours qui tourne, puis le temps du boss vaincu).
func _test_rush_trail() -> void:
	_setup_profile()
	Profile.records["epochs_cleared"] = 2
	Profile.save_profile()
	Tower.start_dungeon("warrior", Dungeons.RUSH, 0, [])
	var world: Node = await _world()
	var td = world.director.tower
	var p: Player = world.player
	p.dev_invincible = true
	var dh: DngHud = world.hud._boss_bar.extra
	await get_tree().create_timer(1.0).timeout
	var rows: Array = td.trail()
	check("fil des temps : huit boss, le 1er en cours (%s)" % [rows.map(func(r): return r.state)], rows.size() == Dungeons.rush_floors() and rows[0].state == "now" and rows[1].state == "next")
	check("fil des temps affiché dans la pile de gauche", dh.trail != null and dh.trail.is_visible_in_tree())
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = res
		await get_tree().create_timer(0.5).timeout
		var r := dh.trail.get_global_rect()
		check("%dx%d : fil des temps dans l'écran, au-dessus des PV (%s)" % [res.x, res.y, r], _in(r, Vector2(res)) and r.end.y <= world.hud._hp_orb.get_global_rect().position.y + 1.0)
	td._boss.take_damage(td._boss.max_hp * 50.0, p)
	await get_tree().create_timer(0.6).timeout
	rows = td.trail()
	check("boss 1 vaincu : son temps au fil (%.1f s)" % float(rows[0].t), rows[0].state == "done" and float(rows[0].t) > 0.5)
	await _close(world, null)


## Siège : tableau des trois au boss, fureur sur la barre, horloge qui dit ce qu'elle compte, objectifs en direct.
func _test_siege_hud() -> void:
	_setup_profile()
	Profile.records["epochs_cleared"] = 2
	Profile.save_profile()
	Tower.start_siege("warrior", "limestone", 0, ["priest", "warrior"])
	var world: Node = await _world()
	var td = world.director.tower
	var p: Player = world.player
	p.dev_invincible = true
	var hud: Hud = world.hud
	var dh: DngHud = hud._boss_bar.extra
	await get_tree().create_timer(0.5).timeout
	check("horloge des vagues : « Vague 1/5 · 0:0x »", String(td.clock_text()).begins_with("Vague 1/5 · 0:"))
	check("trois héros au tableau", SiegeScore.heroes.size() == 3)
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	Tower.reached = Siege.WAVES
	td.begin(Siege.WAVES + 1)
	await get_tree().create_timer(0.8).timeout
	check("horloge du boss : « Boss · fureur dans 6:00 » (%s)" % td.clock_text(), String(td.clock_text()) == "Boss · fureur dans 6:00" or String(td.clock_text()) == "Boss · fureur dans 5:59")
	var boss: Monster = td._boss
	boss.take_damage(boss.max_hp * 0.2, p)
	await get_tree().create_timer(0.5).timeout
	var me: Dictionary = SiegeScore.rows().filter(func(r): return bool(r.me))[0]
	check("tes dégâts au boss comptés (%.0f)" % float(me.dmg), float(me.dmg) > 0.0 and float(me.dmg) <= boss.max_hp * 0.2 + 1.0)
	check("barre du boss : pastille « Fureur 5:5x »", hud._boss_bar._fury.visible and hud._boss_bar._fury.text.begins_with("Fureur 5:5") or hud._boss_bar._fury.text == "Fureur 6:00")
	check("objectifs en direct : boss à faire, personne tombé, fureur à venir", DngHud.siege_star_state("boss", false, td) == "open"
		and DngHud.siege_star_state("allies", false, td) == "open" and DngHud.siege_star_state("fast", false, td) == "open")
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = res
		await get_tree().create_timer(0.5).timeout
		var r := dh.board.get_global_rect()
		check("%dx%d : tableau des trois dans l'écran, au-dessus des PV, à gauche de la barre de boss (%s)" % [res.x, res.y, r], _in(r, Vector2(res))
			and r.end.y <= hud._hp_orb.get_global_rect().position.y + 1.0 and r.end.x <= hud._boss_bar.panel.get_global_rect().position.x + 1.0)
	td._wave_t = Siege.ENRAGE_AT + 1.0
	await get_tree().create_timer(0.5).timeout
	check("fureur : « Avant sa fureur » manqué, horloge « Boss · en fureur »", DngHud.siege_star_state("fast", false, td) == "lost" and td.clock_text() == "Boss · en fureur")
	check("trêve annoncée en alerte (« %s »)" % hud._boss_bar.alert.text, hud._boss_bar.alert.text.begins_with("Trêve"))
	await _close(world, null)


## Pages : Donjons (objectifs, « S'entraîner »), Ruée (« Tes temps »), « Autre boss » (le menu principal rouvert sur les Donjons).
func _test_pages() -> void:
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 2
	Profile.records["dgs_mori_0"] = 5  # ★ ☆ ★
	var s := Rush.current_seed()
	RushBoard.add(s, 0, 640.0, [], int(Profile.records.get("rush_prev", 0)))
	DungeonPage.sel = "mori"
	DungeonPage.lobby_request = "dungeon"
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	check("« Autre boss » : le menu principal s'ouvre sur la page Donjons (%s)" % lobby._current, lobby._current == "dungeon" and DungeonPage.lobby_request == "")
	check("page Donjons : trois objectifs, deux tenus", DungeonPage.stars_cells.size() == 3 and DungeonPage.stars_cells.filter(func(c): return bool(c.get_meta("done"))).size() == 2)
	check("page Donjons : « S'entraîner contre Mori » ouvert", DungeonPage.practice_button != null and not DungeonPage.practice_button.disabled
		and DungeonPage.practice_button.text.contains(BossLibrary.short_name("mori")))
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = res
		lobby._show_menu("dungeon")
		await get_tree().create_timer(0.6).timeout
		var wide: Array = DungeonPage.stars_cells.filter(func(c): return (c as Control).get_global_rect().end.x > float(res.x) + 1.0)
		check("%dx%d : objectifs dans l'écran" % [res.x, res.y], wide.is_empty())
		lobby._dg_diff = 0
		lobby._show_menu("rush")
		await get_tree().create_timer(0.6).timeout
		var found := false
		for n in lobby._sub.find_children("*", "Label", true, false):
			if String((n as Label).text).begins_with("Ce tirage (n° %d) : 1. 10:40" % s):
				found = true
		check("%dx%d : page Ruée, « Tes temps » du tirage" % [res.x, res.y], found)
	get_tree().root.size = Vector2i(1600, 900)
	lobby.queue_free()
	await get_tree().process_frame
