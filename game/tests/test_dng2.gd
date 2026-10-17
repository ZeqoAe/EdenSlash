extends Node
## Lot DNG-2 (backlog BM-DNG, partie visuelle) : barre de boss v2 (seuils réels, mécanique active, fureur, jamais hors de l'écran
## ni sur le boss), frise « À venir » (minuteurs du cerveau, réglage), annonces à 3 niveaux (28 signes au plus, noms français),
## télégraphes v2 (hachures, pointillés du sûr, zone immense peinte par son bord), page Donjons v2, Carnet > Rencontres, bilan v2.
## Lecture seule : le cerveau du boss garde ses minuteurs et ses dégâts.
## godot --headless --path game res://tests/test_dng2.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = false
	Settings.reset_all()
	Profile.reset_all()
	_test_tables()
	_test_announce_texts()
	_test_brain_api()
	await _test_telegraphs()
	await _test_hud_boss()
	await _test_pages()
	await _test_results()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


# --- tables : chaque mécanique a son icône, sa couleur, sa consigne ----------------------------------------------
func _test_tables() -> void:
	var types: Array = BossBricks.DEFS.keys() + BossBrain.KIT
	var miss: Array = types.filter(_lacks)
	check("%d mécaniques et attaques : icône du jeu, consigne, nom français (manquent : %s)" % [types.size(), miss], miss.is_empty())
	var fams: Array = BossBricks.FAMILIES.keys().filter(func(f): return not BossBar.FAMILY_TONE.has(f))
	check("chaque famille a sa couleur de bonbon (%s)" % [fams], fams.is_empty())
	var long_hint: Array = BossBar.CAST_HINT.keys().filter(func(k): return String(BossBar.CAST_HINT[k]).length() > 20)
	check("consignes de la ligne d'incantation : 20 signes au plus (%s)" % [long_hint], long_hint.is_empty())
	var long_short: Array = BossBar.SHORT.keys().filter(func(k): return String(BossBar.SHORT[k]).length() > BossBar.MAX_ALERT)
	check("annonces courtes : 28 signes au plus (%s)" % [long_short], long_short.is_empty())
	check("frise : « maintenant », « dans 7 s », « à 35 % »", BossTimeline.when_text({"now": true}) == "maintenant"
		and BossTimeline.when_text({"in": 6.2, "now": false}) == "dans 7 s" and BossTimeline.when_text({"in": -1.0, "at": 0.35, "now": false}) == "à 35 %")
	check("frise : affichée par défaut, réglage dans les Paramètres", BossTimeline.enabled() and Settings.get_v("interface", "boss_timeline") == true)


func _lacks(t) -> bool:
	return not BossBar.TYPE_ICON.has(t) or not BossBar.CAST_HINT.has(t) or BossBar.icon_of(String(t)) == null or BossBar.mech_name(String(t)) == ""


## Toutes les annonces des briques (lues dans boss_bricks.gd) tiennent en 28 signes une fois passées par l'alerte.
func _test_announce_texts() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/ai/boss_bricks.gd")
	var fn_re := RegEx.create_from_string("^static func _(\\w+)\\(")
	var an_re := RegEx.create_from_string("announce\\.emit\\(\"([^\"]+)\"")
	var cur := ""
	var bad: Array = []
	var n := 0
	for line in src.split("\n"):
		var f := fn_re.search(line)
		if f:
			cur = f.get_string(1).trim_suffix("_loop").trim_suffix("_timer")
		var a := an_re.search(line)
		if a and cur != "":
			n += 1
			var text := a.get_string(1).replace("%s", "Double-porte")
			var type := cur if BossBricks.DEFS.has(cur) else "result"
			if text.contains("brisé") or text.contains("tient"):
				type = "result"
			var out := BossBar.alert_text(type, text)
			if out.length() > BossBar.MAX_ALERT or out.ends_with("…"):
				bad.append("%s : %s -> %s" % [cur, text, out])
	check("%d annonces de mécaniques : 28 signes au plus, jamais coupées (%s)" % [n, bad], n >= 25 and bad.is_empty())
	check("« L'arène se resserre : reste près du centre ! » -> « L'arène se resserre ! »",
		BossBar.alert_text("shrink", "L'arène se resserre : reste près du centre !") == "L'arène se resserre !")
	check("« La barrière tient : il se soigne ! » -> « La barrière tient ! »", BossBar.alert_text("result", "La barrière tient : il se soigne !") == "La barrière tient !")


# --- cerveau : lecture seule ---------------------------------------------------------------------------------------
func _test_brain_api() -> void:
	var boss := Monster.new()
	boss.display_name = "<Boss> Latif, Roi du ciel"
	boss.is_boss = true
	boss.max_hp = 1000.0
	boss.hp = 1000.0
	var br := BossBrain.new()
	br.boss = boss
	boss.brain = br
	for t in ["meteors", "barrier", "enrage", "frenzy"]:
		br.bricks.append(BossBricks.normalize({"type": t}))
	br._brick_t = br.bricks.map(func(b): return float(b.first))
	br._reflect_timer = 1.0e9  # (comme setup_bricks : le miroir n'est qu'une brique)
	var th := br.thresholds()
	check("seuils réels : barrière 70 %%, fureur 50 %%, barrière 35 %%, rage 30 %% (%s)" % [th.map(func(x): return "%s@%s" % [x.type, x.at])],
		th.map(func(x): return float(x.at)) == [0.7, 0.5, 0.35, 0.3] and String(th[1].type) == "phase2")
	var up := br.upcoming(4)
	check("à venir : Météores dans 8 s, puis Barrière (70 %%) et Rage (30 %%) (%s)" % [up], up.size() == 3 and String(up[0].type) == "meteors"
		and is_equal_approx(float(up[0].in), 8.0) and String(up[1].type) == "barrier" and is_equal_approx(float(up[1].at), 0.7) and String(up[2].type) == "enrage")
	br._thresholds_done["1_0.7"] = true
	check("seuil passé : la barrière suivante (35 %)", is_equal_approx(float(br.upcoming(4)[1].at), 0.35) and bool(br.thresholds()[0].done))
	var t0: float = br._brick_t[0]
	br.note_cast("meteors")
	var up2 := br.upcoming(4)
	check("mécanique lancée : en cours (« maintenant »), pas deux fois dans la frise", br.active_cast() == "meteors" and bool(up2[0].now)
		and up2.filter(func(e): return String(e.type) == "meteors").size() == 1)
	check("rien ne change le combat : minuteur intact, « Ce qui t'a battu » toujours attribué", is_equal_approx(float(br._brick_t[0]), t0) and br.blame() == "meteors")
	check("annonce juste après la brique : sa mécanique", BossBar.classify(br, "Pluie de météores !") == "meteors")
	br.age = 10.0
	check("Impatience : 1:50 avant le 1er cran (%s)" % [br.fury()], absf(float(br.fury().left) - 110.0) < 0.01 and int(br.fury().steps) == 0)
	br.age = 165.0
	check("Impatience : 2 crans à 2:45", int(br.fury().steps) == 2 and float(br.fury().left) == 0.0)
	check("plus rien en cours après la fenêtre", br.active_cast() == "")
	check("annonce qui suit (barrière brisée) : résultat, alerte mineure", BossBar.classify(br, "Barrière brisée : il chancelle !") == "result"
		and int(BossBar.SEVERITY.get("result", 1)) == 0)
	check("annonce critique : cercle sûr, regard, rage", int(BossBar.SEVERITY.safe_zone) == 2 and int(BossBar.SEVERITY.gaze) == 2 and int(BossBar.SEVERITY.enrage) == 2)
	boss.free()
	br.free()


# --- télégraphes v2 ------------------------------------------------------------------------------------------------
func _test_telegraphs() -> void:
	var boss := Monster.new()
	boss.is_boss = true
	var made: Array = []
	var mk := func(props: Dictionary) -> Telegraph:
		var t := Telegraph.spawn(self, Vector3.ZERO, 0.0, props)
		made.append(t)
		return t
	var a: Telegraph = mk.call({"shape": "circle", "radius": 4.0, "delay": 1.0, "damage": 10.0, "source": boss})
	var b: Telegraph = mk.call({"shape": "circle", "radius": 7.0, "delay": 2.0, "damage": 10.0, "source": boss})
	var c: Telegraph = mk.call({"shape": "circle", "radius": 4.5, "delay": 3.0, "damage": 0.0, "source": boss, "color": Color(0.3, 1.0, 0.45)})
	var d: Telegraph = mk.call({"shape": "ring", "radius": 45.0, "inner": 4.5, "delay": 3.0, "damage": 10.0, "source": boss})
	var e: Telegraph = mk.call({"shape": "circle", "radius": 2.6, "delay": 1.0, "damage": 0.0, "small": true, "color": Color(1.0, 0.55, 0.1)})
	var f: Telegraph = mk.call({"shape": "circle", "radius": 3.0, "delay": 0.5, "damage": 0.0, "small": true, "color": Telegraph.PLAYER_COLOR})
	var g: Telegraph = mk.call({"shape": "line", "length": 22.0, "width": 0.9, "delay": 0.7, "damage": 0.0, "source": boss})
	await get_tree().process_frame
	await get_tree().process_frame
	check("danger : dessin v2 (hachures, bord net, cœur qui monte), sans compte à rebours sur une petite zone",
		a.v2 and not a.safe and not a.wide and a._fill != null and a._count == null and a._hatch != null)
	check("grosse zone : compte à rebours « 1,9 s » (%s)" % (b._count.text if b._count else "—"), b._count != null and b._count.text.ends_with(" s") and b._count.text.contains(","))
	var word: Array = c.get_children().filter(func(n): return n is Label3D)
	check("zone sûre : pomme, pointillés et « SÛR »", c.safe and c.v2 and word.size() == 1 and (word[0] as Label3D).text == "SÛR")
	check("danger immense (anneau de 45 m autour du sûr) : seul le bord du sûr est peint, aucun écran plein", d.wide and d._fill == null and d._hatch != null
		and float(d._hatch.get_shader_parameter("fade_len")) > 0.0)
	check("annonces discrètes, zones du héros, traits de projectiles : dessin simple", not e.v2 and not f.v2 and not g.v2)
	check("intérieur : 35 % d'opacité au plus (cœur + hachures)", Telegraph.FILL_ALPHA <= 0.35
		and float(a._hatch.get_shader_parameter("hatch_alpha")) + float(a._hatch.get_shader_parameter("base_alpha")) <= 0.35)  # (intensité réglable, lot DNG-3 : 100 % par défaut)
	check("couleur du danger : fraise de la bible", Telegraph.COLOR.is_equal_approx(UiTheme.color("bonbon.fraise.base")))
	for t in made:
		if is_instance_valid(t):
			t.queue_free()
	boss.free()
	await get_tree().process_frame


# --- HUD de boss en partie réelle ------------------------------------------------------------------------------------
func _world() -> Node:
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	return world


func _in(r: Rect2, vp: Vector2) -> bool:
	return r.position.x >= -1.0 and r.position.y >= -1.0 and r.end.x <= vp.x + 1.0 and r.end.y <= vp.y + 1.0


func _test_hud_boss() -> void:
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 1
	Profile.save_profile()
	Tower.start_dungeon("warrior", "limestone", 0, [], "mori", Dungeons.ROOMS.size())
	var world: Node = await _world()
	var td: TowerDirector = world.director.tower
	var p: Player = world.player
	p.dev_invincible = true
	var hud: Hud = world.hud
	var boss: Monster = td._boss
	var bar: BossBar = hud._boss_bar
	var hp_spawn := boss.max_hp
	for i in 6:
		await get_tree().process_frame
	check("salle du boss : barre de boss v2, le cadre de cible ordinaire caché (barre %s, boss suivi %s, cadre %s)" % [bar.visible if bar else null,
		bar.current() == boss if bar else null, hud._target_box.visible], bar != null and bar.visible and bar.current() == boss and not hud._target_box.visible)
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = res
		for i in 4:
			await get_tree().process_frame
		var vp := Vector2(res)
		var pr := bar.panel.get_global_rect()
		var rr := bar.row.get_global_rect()
		check("%dx%d : barre et pastilles dans l'écran (%s, %s)" % [res.x, res.y, pr, rr], _in(pr, vp) and _in(rr, vp))
		check("%dx%d : ni sur la pile de gauche ni sur la mini-carte" % [res.x, res.y], pr.position.x >= 14.0 + Hud.PANEL_W - 1.0 and pr.end.x <= vp.x - 246.0 + 1.0)
		check("%dx%d : une encoche par seuil réel (%d)" % [res.x, res.y, bar._gauge.marks.size()], bar._gauge.marks.size() == boss.brain.thresholds().size() and bar._gauge.marks.size() >= 1)
		check("%dx%d : PV en valeur lisible au centre, aucun pourcentage permanent (« %s »)" % [res.x, res.y, bar._gauge.text],
			not bar._gauge.text.contains("%") and bar._gauge.text == BossBar.hp_text(boss.hp) and bar._gauge.text.ends_with(" PV"))
		var tl := bar.timeline
		check("%dx%d : frise « À venir » affichée, %d lignes, dans l'écran et au-dessus de la barre de sorts" % [res.x, res.y, tl.rows_shown],
			tl.visible and tl.rows_shown >= 2 and _in(tl.get_global_rect(), vp) and tl.get_global_rect().end.y <= vp.y - 204.0)
		hud.hide_banner()
		boss.brain.note_cast("safe_zone")
		hud.show_message("Rejoins le cercle sûr !", 2.5)
		await get_tree().process_frame
		await get_tree().process_frame
		var al := bar.alert
		check("%dx%d : cercle sûr = annonce critique (bulle fraise), pas le bandeau" % [res.x, res.y], al.level == 2 and al.shown() and not hud.banner_up())
		check("%dx%d : annonce dans l'écran (%s)" % [res.x, res.y, al.box.get_global_rect()], _in(al.box.get_global_rect(), vp))
		check("%dx%d : ligne d'incantation « Cercle sûr · au cercle sûr ! »" % [res.x, res.y], bar._cast.modulate.a > 0.9 and bar._cast_label.text.begins_with("Cercle sûr"))
		boss.brain.note_cast("shrink")
		hud.show_message("L'arène se resserre : reste près du centre !", 2.5)
		check("%dx%d : annonce longue raccourcie (« %s »)" % [res.x, res.y, al.text], al.text == "L'arène se resserre !")
		boss.brain.note_cast("meteors")
		hud.show_message("Pluie de météores !", 2.5)
		check("%dx%d : météores = annonce moyenne (bulle lagon)" % [res.x, res.y], al.level == 1)
		boss.brain.last_cast_at -= 5.0
		hud.show_message("Mori Mori\nIl répand ses spores : évite les flaques vertes !", 3.0)
		await get_tree().create_timer(0.4).timeout
		check("%dx%d : intro du boss dans le bandeau, sous la barre" % [res.x, res.y], hud.banner_up()
			and hud._banner.get_global_rect().position.y >= bar.row.get_global_rect().end.y - 1.0 and _in(hud._banner.get_global_rect(), vp))
	# boss hors de la vue : flèche au bord ; réglage : la frise se cache
	var home := boss.global_position
	boss.global_position = home + Vector3(400, 0, 400)
	for i in 3:
		await get_tree().process_frame
	check("boss hors de la vue : flèche soleil au bord de l'écran", bar.arrow.visible and _in(bar.arrow.get_global_rect(), Vector2(1600, 900)))
	boss.global_position = home
	Settings.set_v("interface", "boss_timeline", false)
	for i in 3:
		await get_tree().process_frame
	check("réglage « Frise À venir » coupé : plus de frise", not bar.timeline.visible)
	Settings.set_v("interface", "boss_timeline", true)
	check("PV fixes du boss inchangés par le HUD (%.0f)" % boss.max_hp, is_equal_approx(boss.max_hp, hp_spawn))
	boss.take_damage(boss.max_hp * 50.0, p)
	for i in 4:
		await get_tree().process_frame
	check("boss tombé : la barre se retire", not bar.is_visible_in_tree())
	get_tree().paused = false
	for n in get_tree().get_nodes_in_group("results_panel"):
		n.queue_free()
	world.queue_free()
	await get_tree().create_timer(0.4).timeout
	Tower.active = false
	Run.active = false


# --- page Donjons v2 et Carnet > Rencontres -------------------------------------------------------------------------
func _test_pages() -> void:
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 1
	Profile.records[Dungeons.boss_key("mori", 0)] = 2
	Profile.records[Dungeons.boss_key("mori", 1)] = 1
	get_tree().root.size = Vector2i(1600, 900)
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.5).timeout
	DungeonPage.sel = "mori"
	DungeonPage.f_slot = ""
	DungeonPage.f_arch = ""
	DungeonPage.f_family = ""
	lobby._dg_diff = 0
	lobby._show_menu("dungeon")
	for i in 3:
		await get_tree().process_frame
	check("Donjons v2 : 48 tuiles par zone", DungeonPage.cards.size() == BossLibrary.ids().size())
	check("difficulté en onglets : 3, l'actif plus haut", DungeonPage.diff_tabs.size() == 3 and DungeonPage.diff_tabs[0].custom_minimum_size.y > DungeonPage.diff_tabs[1].custom_minimum_size.y)
	check("butin en cases : un emplacement par pièce, plus le plan", DungeonPage.loot_cells.size() == (BossLibrary.loot("mori").slots as Array).size() + 1)
	var mori: Button = DungeonPage.cards.filter(func(c): return String(c.get_meta("boss", "")) == "mori")[0]
	check("tuile de Mori : médailles N et H gagnées", mori.find_children("*", "Control", true, false).size() > 5 and Dungeons.boss_cleared("mori", 0) == 2)
	var other: Button = DungeonPage.cards.filter(func(c): return String(c.get_meta("boss", "")) != "mori" and Dungeons.is_open(Dungeons.boss_zone(String(c.get_meta("boss", "")))))[0]
	var other_id := String(other.get_meta("boss"))
	other.pressed.emit()
	await get_tree().process_frame
	check("une tuile choisit son donjon", DungeonPage.sel == other_id)
	DungeonPage.diff_tabs[1].pressed.emit()
	await get_tree().process_frame
	check("onglet Héroïque : choisi", int(lobby._dg_diff) == 1)
	lobby._dg_diff = 0
	BestTimes.reset()
	Profile.records[BestTimes.KEY] = {BestTimes.boss_key("dungeon", "mori", 0): 118.0}
	check("records de la difficulté : « %s »" % DungeonPage.records_line("mori", 0), DungeonPage.records_line("mori", 0) == "Tes records en Normal : boss 1:58")
	# Carnet > Rencontres
	var i_enc: int = lobby._archive.page_count() - 1
	check("Carnet : « Rencontres » en dernier onglet, la Collection garde l'indice 4", lobby._archive.page(i_enc) is EncounterJournal and lobby._archive.page(4) is ArchivePages.CollectionPage)
	EncounterJournal.sel = "mori"
	lobby._archive.open(i_enc)
	for i in 3:
		await get_tree().process_frame
	var ej: EncounterJournal = lobby._archive.page(i_enc)
	check("Rencontres : 48 fiches", ej.tiles.size() == BossLibrary.ids().size())
	check("Rencontres : sous-titre propre", lobby._archive._subtitle.text == ej.subtitle())
	var hidden := Encounters.all().filter(func(c): return String(c.name) == "???")
	check("boss d'une zone fermée et jamais vu : nom caché (%d)" % hidden.size(), not hidden.is_empty())
	var tips_ok: bool = not hidden.is_empty() and (Encounters.card(String(hidden[0].id)).bricks as Array).all(func(b): return String(b.hint) != "")
	check("…mais ses conseils restent lisibles", tips_ok)
	check("fiche de Mori : « Aller à son donjon »", ej.go_button != null and not ej.go_button.disabled)
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = res
		for k in 3:
			await get_tree().process_frame
		check("Rencontres en %dx%d : grille et fiche dans l'écran (%s)" % [res.x, res.y, ej.get_global_rect()], _in(ej.get_global_rect(), Vector2(res)))
		if not _in(ej.get_global_rect(), Vector2(res)):
			_wide(lobby._archive, 0)
	ej.go_button.pressed.emit()
	await get_tree().process_frame
	check("« Aller à son donjon » : Carnet fermé, page Donjons sur Mori", not lobby._archive.is_open() and DungeonPage.sel == "mori" and lobby._current == "dungeon")
	lobby.queue_free()
	await get_tree().process_frame


## (diagnostic) contrôles plus larges que 900 px.
func _wide(c: Node, depth: int) -> void:
	if c is Control and ((c as Control).get_combined_minimum_size().x > 900.0 or (c as Control).size.x > 1300.0):
		print("  [large] %s%s %s min=%s taille=%s pos=%s" % ["  ".repeat(depth), c.get_class(), c.name, (c as Control).get_combined_minimum_size(),
			(c as Control).size, (c as Control).global_position])
	for k in c.get_children():
		_wide(k, depth + 1)


# --- bilan v2 ------------------------------------------------------------------------------------------------------
func _test_results() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var r := ResultsPanel.new()
	add_child(r)
	r.show_spec({"title": "Victoire !", "tone": "win", "tiles": [["4:12", "temps · Record !", "Ancien record : 4:31", true], ["1:58", "boss (record 2:20)"]],
		"stars": [{"label": "Fini", "done": true, "new": true}, {"label": "Sans tomber", "done": false}],
		"loot": [{"name": "Tête ou Gants", "sub": "Phénix · Nv 46", "rarity": Items.LEGENDARY}, {"name": "Plan de donjon", "sub": "Latif", "rarity": Items.LEGENDARY}],
		"missing": "Il te manque encore ici : Gants (seul emplacement de Latif qui te manque)",
		"buttons": [{"text": "Rejouer", "primary": true}, {"text": "Retour au menu"}]})
	await get_tree().create_timer(0.6, true, false, true).timeout
	var rec := r.find_children("*", "PanelContainer", true, false).filter(func(n): return n.has_meta("record"))
	check("bilan v2 : « Record ! » en pastille sur la tuile du temps", rec.size() == 1)
	check("bilan v2 : butin en cases (2)", r._loot_row != null and r._loot_row.get_child_count() == 2)
	var vp := Vector2(1280, 720)
	var out: Array = []
	for n in r.find_children("*", "Control", true, false):
		var c := n as Control
		if c.is_visible_in_tree() and c.size.x > 2.0 and not _in(c.get_global_rect(), vp) and not c.get_parent() is ScrollContainer:
			out.append(c.name)
	check("bilan v2 dans 1280×720 (%s)" % [out.slice(0, 4)], out.is_empty())
	r.queue_free()
	await get_tree().process_frame
	HitLog.reset()
	var t := HitLog.clock()
	HitLog._hits = [{"t": t - 3.0, "dmg": 900.0, "share": 0.48, "hp": 0.52, "name": "Latif", "brick": "meteors", "boss": "latif", "dot": false, "lethal": false},
		{"t": t - 0.5, "dmg": 900.0, "share": 0.52, "hp": 0.0, "name": "Latif", "brick": "marks", "boss": "latif", "dot": false, "lethal": true}]
	HitLog._death_at = t - 0.5
	var r2 := ResultsPanel.new()
	add_child(r2)
	r2.show_spec({"title": "Défaite", "tone": "lose", "defeat": HitLog.report(), "buttons": [{"text": "Réessayer le boss", "primary": true}]})
	await get_tree().create_timer(0.6, true, false, true).timeout
	var chips := r2.defeat_box.find_children("*", "TextureRect", true, false) if r2.defeat_box != null else []
	check("« Ce qui t'a battu » v2 : une pastille de mécanique par ligne", chips.size() >= 2)
	check("lignes : la brique gardée (pour l'icône)", ResultsPanel.defeat_lines(HitLog.report())[0].brick == "marks" or ResultsPanel.defeat_lines(HitLog.report())[0].brick == "meteors")
	r2.queue_free()
	get_tree().paused = false
	HitLog.reset()
	get_tree().root.size = Vector2i(1600, 900)
