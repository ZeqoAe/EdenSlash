extends Node
## Lot DNG-1 (backlog BM-DNG, P0-5 / 6 / 7 / 9 / 10) : « Ce qui t'a battu » (HitLog), temps et records (BestTimes), journal des
## rencontres (Encounters), bilans (butin en cases, Réessayer le boss, Reprendre à l'étage 11), noms français des intros de boss,
## HUD de boss sans débordement en 1280×720 et 1600×900.
## godot --headless --path game res://tests/test_dng1.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = false
	Settings.reset_all()
	Profile.reset_all()
	_test_hitlog()
	_test_best_times()
	_test_encounters()
	_test_names()
	await _test_dungeon_win()
	await _test_dungeon_fall()
	await _test_tower_fall()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


# --- « Ce qui t'a battu » : attribution, regroupement, conseil -------------------------------------------------
func _test_hitlog() -> void:
	var missing: Array = BossBricks.DEFS.keys().filter(func(t): return not HitLog.TIPS.has(t) or not HitLog.WINDOWS.has(t))
	check("un conseil et une fenêtre pour chacune des %d briques (manquent : %s)" % [BossBricks.DEFS.size(), missing], missing.is_empty())
	var kit: Array = BossBrain.KIT.filter(func(t): return not HitLog.TIPS.has(t) or not HitLog.BASE_NAMES.has(t))
	check("attaques de base : nom et conseil français (%s)" % [kit], kit.is_empty())
	var long: Array = HitLog.TIPS.keys().filter(func(t): return String(HitLog.TIPS[t]).length() > 95)
	check("conseils courts (≤ 95 signes : %s)" % [long], long.is_empty())
	HitLog.reset()
	var hero := Player.new()
	hero.max_hp = 1000.0
	var boss := Monster.new()
	boss.display_name = "<Boss> Latif, Roi du ciel"
	boss.set_meta("boss_id", "latif")
	var br := BossBrain.new()
	br.boss = boss
	boss.brain = br
	var add := Monster.new()
	add.display_name = "Rat"
	add.set_meta("boss_brick", "adds")
	var elite := Monster.new()
	elite.display_name = "Gobelin · Flaques"
	br.note_cast("meteors")
	check("mécanique lancée : tenue pour responsable de ses coups", br.blame() == "meteors")
	hero.hp = 520.0
	HitLog.note(hero, 480.0, boss)
	hero.hp = 400.0
	HitLog.note(hero, 120.0, add)
	hero.hp = 310.0
	HitLog.note(hero, 90.0, elite)
	br._casts = [[HitLog.clock() - 30.0, "leap"]]
	check("mécanique trop ancienne : plus responsable", br.blame() == "")
	br._casts = [[HitLog.clock() - 8.0, "puddles"], [HitLog.clock() - 1.0, "slams"]]
	check("dégâts continus : la flaque d'abord, un coup : la dernière attaque", br.blame(true) == "puddles" and br.blame(false) == "slams")
	br._casts = [[HitLog.clock() - 1.0, "marks"]]
	check("pas encore de chute : rien à dire", not HitLog.died())
	hero.hp = 0.0
	HitLog.note(hero, 310.0, boss)
	check("chute notée", HitLog.died())
	var rep := HitLog.report()
	check("rapport : %d coups, 3 lignes au plus" % int(rep.get("hits", 0)), int(rep.hits) == 4 and (rep.lines as Array).size() == 3)
	var first: Dictionary = rep.lines[0]
	check("ligne la plus lourde : Pluie de météores de Latif, 48 %% (%s · %s, %.2f)" % [first.mech, first.name, float(first.share)],
		String(first.name) == "Latif" and String(first.brick) == "meteors" and absf(float(first.share) - 0.48) < 0.001)
	check("coup final : la Marque, visible même s'il pèse moins", String(rep.killer.brick) == "marks" and (rep.lines as Array).any(func(l): return bool(l.final) and String(l.brick) == "marks"))
	check("mécanique fautive = celle qui a pris le plus de PV, avec son conseil", String(rep.brick) == "meteors" and String(rep.tip) == String(HitLog.TIPS.meteors))
	var rows := ResultsPanel.defeat_lines(rep)
	check("bilan : « Pluie de météores · Latif » · « −48 %% PV » (%s / %s)" % [rows[0].text, rows[0].value],
		String(rows[0].text) == "Pluie de météores · Latif" and String(rows[0].value) == "−48 % PV")
	check("invocation : la mécanique qui l'a appelée (Renforts)", HitLog.blame(add).brick == "adds" and HitLog.blame(elite).name == "Gobelin")
	check("source inconnue : « Effets et pièges »", String(HitLog.blame(null).name) == "Effets et pièges")
	hero.foe = true
	HitLog.reset()
	hero.hp = 0.0
	HitLog.note(hero, 50.0, boss)
	check("héros ennemi : jamais noté", HitLog.report().is_empty())
	for n in [hero, boss, add, elite, br]:
		n.free()
	HitLog.reset()


# --- temps et records ------------------------------------------------------------------------------------------
func _test_best_times() -> void:
	Profile.reset_all()
	BestTimes.reset()
	check("formats : 1:58 · 12:04 · 1:02:05", BestTimes.fmt(118.0) == "1:58" and BestTimes.fmt(724.0) == "12:04" and BestTimes.fmt(3725.0) == "1:02:05")
	var key := BestTimes.boss_key("dungeon", "latif", 0)
	check("vieille sauvegarde : aucun temps, aucune clé à migrer", BestTimes.best(key) == 0.0 and not Profile.records.has(BestTimes.KEY))
	var e := BestTimes.note(key, "Latif", 140.0)
	check("premier temps : neuf, pas un « record battu »", bool(e.new) and BestTimes.beaten().is_empty())
	check("en partie, rien n'est écrit avant commit", BestTimes.best(key) == 0.0)
	BestTimes.commit()
	check("commit : 2:20 enregistré", absf(BestTimes.best(key) - 140.0) < 0.2)
	BestTimes.reset()
	e = BestTimes.note(key, "Latif", 118.0)
	var notes := BestTimes.record_notes()
	check("record battu : « %s »" % [notes], notes.size() == 1 and String(notes[0]) == "Record ! Latif en 1:58 (ancien 2:20)")
	var t := BestTimes.tile(e, 0.0)
	check("tuile : « 1:58 · temps · Record ! » mise en avant", String(t[0]) == "1:58" and String(t[1]).contains("Record") and bool(t[3]))
	BestTimes.commit()
	BestTimes.reset()
	BestTimes.note(key, "Latif", 130.0)
	BestTimes.commit()
	check("plus lent : le record reste 1:58", absf(BestTimes.best(key) - 118.0) < 0.2 and BestTimes.tile(BestTimes.entry(key), 0.0)[1] == "temps (record 1:58)")
	Profile.records[BestTimes.KEY] = 5
	check("clé abîmée : lue comme vide, puis réécrite", BestTimes.best(key) == 0.0)
	BestTimes.commit()
	check("clé réécrite en dictionnaire", Profile.records[BestTimes.KEY] is Dictionary)
	check("clés distinctes : boss, donjon, tranche, tirage", BestTimes.dungeon_key("latif", 1) == "dungeon:latif:1" and BestTimes.tower_key(1, 0) == "tower:1:0" \
		and BestTimes.rush_key(4821, 2) == "rush:4821:2")
	BestTimes.reset()


# --- journal des rencontres (données) --------------------------------------------------------------------------
func _test_encounters() -> void:
	Profile.reset_all()
	Encounters.reset()
	check("48 fiches, dans l'ordre de la bibliothèque", Encounters.all().size() == BossLibrary.ids().size() and BossLibrary.ids().size() == 48)
	var c := Encounters.card("latif")
	check("fiche neuve : à découvrir, mécaniques lisibles quand même (%d)" % (c.bricks as Array).size(), String(c.state) == "unknown"
		and (c.bricks as Array).size() == BossLibrary.brick_types("latif").size() and (c.bricks as Array).all(func(b): return String(b.tip) != "" and int(b.seen) == 0))
	check("fiche : records par difficulté des Donjons (3)", (c.dungeon as Array).size() == 3)
	check("compteurs : 48 à découvrir", int(Encounters.counts().total) == 48 and int(Encounters.counts().met) == 0)
	Profile.records["dgb_latif_1"] = 2
	check("victoires d'avant le journal (dgb_*) : la fiche est « vaincu »", Encounters.state("latif") == "won" and Encounters.wins("latif") == 2)
	var slots: Array = BossLibrary.loot("latif").slots
	check("emplacements qui manquent : les deux au départ", Encounters.missing_slots("latif").size() == slots.size())
	var it := Items.generate(30, 0.0, String(slots[0]), "warrior", 4, "", 0)
	it["archetype"] = String(BossLibrary.loot("latif").archetype)
	Profile.inventory.append(it)
	check("une pièce de sa panoplie possédée : il n'en manque plus qu'une", Encounters.missing_slots("latif") == [slots[1]])
	check("texte du bilan : « seul emplacement de Latif qui te manque »", DungeonResults.missing_text("latif").contains("seul emplacement de Latif"))
	Profile.records[Encounters.KEY] = "abîmé"
	check("clé abîmée : fiche lisible quand même", Encounters.card("latif").has("bricks"))
	Profile.reset_all()


# --- noms français ---------------------------------------------------------------------------------------------
func _test_names() -> void:
	var bad: Array = []
	for z in GameData.zones:
		var dg: Dictionary = z.get("dungeon", {})
		var m: Dictionary = GameData.monsters.get(int(dg.get("boss", 0)), {})
		var en := String(m.get("name_en", ""))
		if en != "" and en != String(m.get("name", "")) and String(dg.get("intro", "")).contains(en):
			bad.append(z.id)
	check("intros des donjons de zone : jamais le nom anglais du boss (%s)" % [bad], bad.is_empty())
	var bad2: Array = BossLibrary.ids().filter(func(id): return not BossLibrary.intro(String(id)).is_empty() and _english_in(String(id)))
	check("intros de la bibliothèque : jamais le nom anglais du boss (%s)" % [bad2], bad2.is_empty())
	check("Double-porte : « Double-porte, hôte de la magie… »", BossLibrary.intro("doubledoor").begins_with("Double-porte"))


func _english_in(id: String) -> bool:
	var m: Dictionary = GameData.monsters.get(int(BossLibrary.get_def(id).get("monster", 0)), {})
	var en := String(m.get("name_en", ""))
	return en != "" and en != String(m.get("name", "")) and BossLibrary.intro(id).contains(en)


# --- parties réelles -------------------------------------------------------------------------------------------
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


func _setup_profile() -> void:
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 1
	Profile.save_profile()  # Tower.finish recharge la sauvegarde


## Donjon repris à la salle du boss (« Réessayer le boss »), boss vaincu : temps du boss, fiche du journal, bilan avec butin en cases.
func _test_dungeon_win() -> void:
	_setup_profile()
	Tower.start_dungeon("warrior", "limestone", 0, [], "mori", Dungeons.ROOMS.size())
	check("reprise au boss : départ salle 3, salles 1-2 comptées franchies", Tower.start_floor == 3 and Tower.reached == 2)
	var world: Node = await _world()
	var td: TowerDirector = world.director.tower
	var p: Player = world.player
	p.dev_invincible = true
	check("reprise au boss : le boss du donjon est là", Tower.floor_n == 3 and is_instance_valid(td._boss) and String(td._boss.get_meta("boss_id", "")) == "mori")
	var boss: Monster = td._boss
	BossBricks.run(boss.brain, boss.brain.bricks[0])
	var brick := String(boss.brain.bricks[0].type)
	await get_tree().create_timer(1.5).timeout
	boss.take_damage(boss.max_hp * 0.5, p)
	await get_tree().create_timer(0.5).timeout
	boss.take_damage(boss.max_hp * 50.0, p)
	await get_tree().create_timer(0.2).timeout
	var be := BestTimes.entry(BestTimes.boss_key("dungeon", "mori", 0))
	check("temps du boss mesuré (%.1f s)" % float(be.get("t", 0.0)), float(be.get("t", 0.0)) > 1.0 and bool(be.get("new", false)))
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and not m.is_dead:
			m.take_damage(m.max_hp * 50.0, p)
	var panel := await _panel(12.0)
	check("victoire : bilan du donjon", panel is DungeonResults)
	var enc: Dictionary = Encounters.raw("mori")
	check("journal : Mori rencontré et vaincu en donjon, sa mécanique « %s » vue" % brick, int(enc.get("met", 0)) >= 1
		and int(enc.get("won", {}).get("dungeon", 0)) == 1 and int(enc.get("seen", {}).get(brick, 0)) >= 1)
	check("records écrits dans le profil après la fin (rechargement compris)", BestTimes.best(BestTimes.boss_key("dungeon", "mori", 0)) > 1.0)
	check("reprise au boss : pas de temps de donjon complet", BestTimes.best(BestTimes.dungeon_key("mori", 0)) == 0.0)
	check("fiche : « vaincu », meilleur temps du boss en Normal", Encounters.card("mori").state == "won" and float(Encounters.card("mori").dungeon[0].best) > 1.0)
	if panel != null:
		check("bilan : butin en cases (coffre de panoplie, plan)", panel.loot_box != null and panel.loot_box.get_child_count() >= 1)
		check("bilan de victoire : pas de bloc « Ce qui t'a battu »", panel.defeat_box == null)
	await _close(world, panel)


## Chute devant le boss d'un donjon : « Ce qui t'a battu », meilleur pourcentage, « Réessayer le boss » ; bilan dans 1280×720.
func _test_dungeon_fall() -> void:
	_setup_profile()
	get_tree().root.size = Vector2i(1280, 720)
	Tower.start_dungeon("warrior", "limestone", 0, [], "mori", Dungeons.ROOMS.size())
	var world: Node = await _world()
	var td: TowerDirector = world.director.tower
	var p: Player = world.player
	p.dev_invincible = false
	var boss: Monster = td._boss
	await _hud_fit(world, Vector2i(1280, 720))
	get_tree().root.size = Vector2i(1600, 900)
	await _hud_fit(world, Vector2i(1600, 900))
	get_tree().root.size = Vector2i(1280, 720)
	await get_tree().process_frame
	boss.take_damage(boss.max_hp * 0.4, p)
	var left := boss.hp / boss.max_hp
	boss.brain.note_cast("leap")
	p.take_damage(p.max_hp * 0.3 * (100.0 + p.defense) / 100.0, boss)
	await get_tree().create_timer(0.3).timeout
	boss.brain.note_cast("meteors")
	p.take_damage(p.max_hp * 50.0, boss)
	var panel := await _panel(12.0)
	check("chute : bilan du donjon", panel is DungeonResults)
	if panel != null:
		check("« Ce qui t'a battu » au bilan d'échec", panel.defeat_box != null)
		check("« Réessayer le boss » en premier, puis Rejouer et Retour (%s)" % [panel.buttons.map(func(b): return b.text)], panel.buttons.size() == 3
			and panel.buttons[0].text == "Réessayer le boss" and panel.buttons[1].text == "Rejouer (même donjon)")
		var k: Dictionary = HitLog.report().get("killer", {})
		check("coup final : Pluie de météores de Mori, part bornée aux PV restants (%s)" % [k], String(k.get("brick", "")) == "meteors" and String(k.get("name", "")) == BossLibrary.short_name("mori") and float(k.get("share", 9.0)) <= 1.0)
		check("part de PV laissée au boss notée (%.2f, attendu %.2f)" % [float(Encounters.last_low.get("mori", -1.0)), left],
			absf(float(Encounters.last_low.get("mori", -1.0)) - left) < 0.05)
		_inside(panel, Vector2(1280, 720), "bilan d'échec du donjon en 1280×720")
	get_tree().root.size = Vector2i(1600, 900)
	await _close(world, panel)


## Tour : chute à l'étage 12 d'une ascension partie de l'étage 1 : « Reprendre (étage 11) » proposé d'abord.
func _test_tower_fall() -> void:
	_setup_profile()
	Tower.start("warrior", 1, 1)
	var world: Node = await _world()
	var td: TowerDirector = world.director.tower
	var p: Player = world.player
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	Tower.reached = 11
	td.begin(12)
	await get_tree().create_timer(1.0).timeout
	p.dev_invincible = false
	var foe: Combatant = null
	for m in get_tree().get_nodes_in_group("monsters"):
		foe = m
		break
	p.take_damage(p.max_hp * 50.0, foe)
	var panel := await _panel(12.0)
	check("chute dans la Tour : bilan", panel is TowerResults)
	if panel != null:
		var texts: Array = panel.buttons.map(func(b): return b.text)
		check("après une chute à l'étage 12 : « Reprendre (étage 11) » d'abord, puis Rejouer (étage 1) (%s)" % [texts],
			texts.size() == 3 and texts[0] == "Reprendre (étage 11)" and String(texts[1]).begins_with("Rejouer (étage 1,"))
		check("« Ce qui t'a battu » au bilan de la Tour", panel.defeat_box != null)
		_inside(panel, Vector2(1600, 900), "bilan de la Tour en 1600×900")
	check("palier de reprise : étage 11 (record 11)", Tower.checkpoint() == 11 and TowerResults.resume_floor("defaite") == 11 and TowerResults.resume_floor("victoire") == 0)
	await _close(world, panel)


## HUD de boss dans [param res] : barre du boss, bandeau d'annonce (intro très longue) et compteur de dégâts dans l'écran,
## le bandeau à l'écart de la mini-carte.
func _hud_fit(world: Node, res: Vector2i) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var hud: Hud = world.hud
	var vp := Vector2(res)
	check("fenêtre %dx%d appliquée (%s)" % [res.x, res.y, get_viewport().get_visible_rect().size], get_viewport().get_visible_rect().size.is_equal_approx(vp))
	hud.show_message("Double-porte, hôte de la magie, se protège derrière des totems : détruis-les tous avant qu'il ne te noie sous ses sorts !", 4.0)
	Run.add_combo_damage(987654321.0)
	await get_tree().create_timer(0.6).timeout
	for n in [hud._banner, hud._target_box, hud._dmg_box]:
		_rect_in(n as Control, vp, "%s %dx%d" % [n.name if n.name != "" else n.get_class(), res.x, res.y])
	var b := (hud._banner as Control).get_global_rect()
	check("bandeau d'annonce à l'écart de la mini-carte (fin %.0f, mini-carte dès %.0f) en %dx%d" % [b.end.x, vp.x - 246.0, res.x, res.y], b.end.x <= vp.x - 246.0 + 1.0)
	check("titre long renvoyé à la ligne en %dx%d" % [res.x, res.y], hud._center_label.autowrap_mode != TextServer.AUTOWRAP_OFF)


func _rect_in(c: Control, vp: Vector2, what: String) -> void:
	if c == null or not c.is_visible_in_tree():
		check("%s : affiché" % what, false)
		return
	var r := c.get_global_rect()
	check("%s dans l'écran (%s)" % [what, r], r.position.x >= -1.0 and r.position.y >= -1.0 and r.end.x <= vp.x + 1.0 and r.end.y <= vp.y + 1.0)


## Tous les contrôles visibles du bilan [param panel] dans l'écran [param vp].
func _inside(panel: Node, vp: Vector2, what: String) -> void:
	var out: Array = []
	for n in panel.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size.x < 2.0 or c.size.y < 2.0:
			continue
		if c.get_parent() is ScrollContainer or _in_scroll(c):
			continue  # (une liste qui défile peut dépasser : elle est coupée par son cadre)
		var r := c.get_global_rect()
		if r.end.y > vp.y + 1.0 or r.end.x > vp.x + 1.0 or r.position.y < -1.0:
			out.append("%s %s" % [c.get_class(), r])
	check("%s : rien hors de l'écran (%s)" % [what, out.slice(0, 3)], out.is_empty())


func _in_scroll(c: Node) -> bool:
	var n := c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false
