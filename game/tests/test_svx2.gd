extends Node
## Lot SVX-2 du Survivant (interface v2, conception/survivor/R_SVX2.md) :
##   - SurvivorLog : dégâts par source (arme, sort, passif, panoplie, effets), fenêtre de 30 s, moments marquants ;
##   - choix de carte v2 (SurvivorPicker) : titre en deux temps, cartes papier (bandeau, famille, une décision, synergie),
##     « Maj : tout le détail », panneau « Ton équipement » (héros avant → après), barre unique Relancer / Bannir… / Garder… /
##     Passer avec mode visée, touches clavier et manette ; 120 états tirés au hasard : aucune carte ne déborde, ni en court ni
##     en détail, à 1280 × 720 et 1600 × 900 ; aucun mot « run / build / set / lobby » ;
##   - HUD v2 en jeu (XP pleine largeur, chrono et frise, collection, vie en jauge, grille 4 × 3, moments manga) ;
##   - page « Équipement » de la pause (« Qui fait le travail », évolutions « il manque… ») ;
##   - bilan v2 (4 tuiles, dégâts par source, équipement final, moments, « Menu principal ») qui tient dans 1280 × 720.
## godot --headless --path game res://tests/test_svx2.tscn   (SVX2_STATES=N : états du rendu, 120 par défaut)

var fails := 0
const WORDS := ["run", "build", "builds", "set", "sets", "lobby", "jce"]


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size = Vector2i(1280, 720)
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": ["sv_first", "sv_locked", "sv_tier"], "version": Version.NUMBER}
	SurvivorCards.seed_with(42)
	_log()
	await _picker()
	await _render(Vector2i(1280, 720))
	await _render(Vector2i(1600, 900))
	get_tree().root.size = Vector2i(1280, 720)
	await _world()
	await _bilan()
	print("test_svx2 : %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _settle(n := 4) -> void:
	for i in n:
		await get_tree().process_frame


func _texts(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	elif n is RichTextLabel:
		out += (n as RichTextLabel).get_parsed_text() + "\n"
	elif n is Button:
		out += (n as Button).text + "\n" + (n as Button).tooltip_text + "\n"
	if n is Control and (n as Control).tooltip_text != "" and not n is Button:
		out += (n as Control).tooltip_text + "\n"
	for c in n.get_children():
		out += _texts(c)
	return out


## Mots interdits côté joueur (BIBLE § 12) présents dans [param s].
func _bad_words(s: String) -> Array:
	var clean := s.to_lower()
	for ch in ["'", "’", "(", ")", ":", ",", ".", "!", "?", ";", "«", "»", "·", "/", "\n", "-", "…"]:
		clean = clean.replace(ch, " ")
	var out: Array = []
	for w in clean.split(" ", false):
		if w in WORDS and not w in out:
			out.append(w)
	return out


# --- journal de la partie --------------------------------------------------------------------------------------------------
func _log() -> void:
	Survivor.start("warrior", "limestone")
	SurvivorLog.begin()
	var sid := int(Run.class_data().skills[0].id)
	SurvivorLog.tag = "weapon"
	SurvivorLog.note(300.0)
	SurvivorLog.tag = "skill:%d" % sid
	SurvivorLog.note(500.0)
	SurvivorLog.tag = SurvivorLog.proc_tag("ember_0")
	SurvivorLog.note(100.0)
	SurvivorLog.tag = SurvivorLog.proc_tag("set_tempest_2_0")
	SurvivorLog.note(50.0)
	SurvivorLog.tag = ""
	SurvivorLog.note(40.0, true)
	SurvivorLog.note(10.0)
	var rows := SurvivorLog.rows()
	check("journal : 6 sources, du plus fort au plus faible (%s)" % str(rows.map(func(r): return r.key)), rows.size() == 6 and String(rows[0].key) == "skill:%d" % sid
		and String(rows[1].key) == "weapon" and absf(SurvivorLog.total() - 1000.0) < 0.01)
	check("journal : parts (sort 50 %%, arme 30 %%)", absf(float(rows[0].share) - 0.5) < 0.001 and absf(float(rows[1].share) - 0.3) < 0.001)
	check("journal : étiquettes des effets déclenchés (passif, panoplie)", SurvivorLog.proc_tag("ember_0") == "passive:ember" and SurvivorLog.proc_tag("set_tempest_2_0") == "set:tempest"
		and SurvivorLog.proc_tag("static_blade_1") == "passive:static_blade")
	check("journal : noms lisibles (sort, Braise, effets)", String(rows[0].name) == String(Run.skill_def(sid).name) and String(rows[0].kind) == "sort"
		and rows.any(func(r): return String(r.name) == "Braise" and String(r.kind) == "passif") and rows.any(func(r): return String(r.kind) == "effets"))
	check("journal : fenêtre de 30 s (tout vient d'arriver)", SurvivorLog.rows(SurvivorLog.WINDOW).size() == 6 and float(SurvivorLog.rows(30)[0].dps) > 0.0)
	for i in 20:
		SurvivorLog.moment(float(i), "Moment %d" % i, "level")
	SurvivorLog.moment(3.0, "Moment 19", "level")
	check("journal : %d moments au plus, sans doublon" % SurvivorLog.MOMENTS_MAX, SurvivorLog.moments.size() == SurvivorLog.MOMENTS_MAX)
	Survivor.active = false
	SurvivorLog.note(999.0)
	check("journal : rien compté hors du Survivant", absf(SurvivorLog.total() - 1000.0) < 0.01)
	Run.finish("abandon")
	Profile.end_run_survival()


# --- choix de carte v2 --------------------------------------------------------------------------------------------------------
func _picker() -> void:
	Survivor.start("warrior", "limestone")
	var picker := SurvivorPicker.new()
	add_child(picker)
	picker.offer("Choisis ton arme ou ta première compétence", SurvivorCards.first_offer(), func(): return SurvivorCards.first_offer())
	await _settle()
	check("1er choix : ni Passer, relance, bannir et garder présents", picker.is_open() and not picker._skip.visible and picker._reroll.visible and picker.ban_button.visible and picker.keep_button.visible)
	check("1er choix : titre court (sans « : »)", not picker._title.text.contains(":"))
	picker._opened_at -= CardPicker.CONFIRM_DELAY_MS
	picker._choose(picker._cards.find_custom(func(c): return String(c.type) == "sv_weapon") if picker._cards.any(func(c): return String(c.type) == "sv_weapon") else 0)
	await _settle()
	if Profile.equipped.get("weapon", {}).is_empty():
		Run.apply_card(SurvivorCards.weapon_card())
	Run.apply_card(SurvivorCards.spell_card(int(Run.class_data().skills[0].id)))
	Run.hero_level = 8
	var reroll := func(): return Run.roll_cards(3)
	picker.offer("Niveau 8 ! Choisis une carte", [SurvivorCards.new_piece_card("chest"), SurvivorCards.new_piece_card("head"),
		SurvivorCards.spell_up_card(int(Run.skills[0].id), "rare")], reroll)
	picker.offer("Niveau 9 ! Choisis une carte", Run.roll_cards(3), reroll)
	await _settle()
	check("titre en deux temps : « %s » / « %s »" % [picker._title.text, picker.sub_label.text], picker._title.text == "Niveau 8 !"
		and picker.sub_label.text == "Choisis une carte · 1 autre en attente")
	check("barre : Relancer · n, Bannir · n, Garder · n, Passer · +or", picker._reroll.text.begins_with("Relancer · ") and picker.ban_button.text.begins_with("Bannir · ")
		and picker.keep_button.text.begins_with("Garder · ") and picker._skip.text == "Passer · +%d or" % SurvivorCards.skip_gold())
	var c0: Button = picker._buttons[0]
	var band: Control = c0.get_child(0)
	check("carte : bandeau dessiné, contenu court (pas de puits d'encre)", band is SurvivorPicker.Band and float(c0.get_meta("measure_pad")) == 0.0)
	check("carte pièce : famille PIÈCE, pied « Maj : tout le détail · gardée à vie »", SurvivorCardView.family_label(picker._cards[0]) == "PIÈCE"
		and _texts(c0).contains("Maj : tout le détail · 🔒 gardée à vie"))
	# panneau « Ton équipement » : la carte survolée (pièce) change les statistiques du héros
	picker._set_hover(0)
	await _settle(2)
	var ptxt := _texts(picker.panel)
	check("panneau : Ton équipement, Héros, Panoplies, Sorts n / 12", ptxt.contains("Ton équipement") and ptxt.contains("Héros") and ptxt.contains("Panoplies") and ptxt.contains("Sorts 1 / 12"))
	var prev := SurvivorCardView.hero_preview(picker._cards[0], null)
	var p := Player.new()
	add_child(p)
	await _settle(2)
	p.recalc_stats()
	prev = SurvivorCardView.hero_preview(picker._cards[0], p)
	check("aperçu du héros : 4 lignes, une au moins change avec la pièce (%s)" % str(prev), prev.size() == 4 and prev.any(func(r): return String(r[2]) != ""))
	check("aperçu : l'équipement est rendu tel quel après le calcul", not Profile.equipped.has("chest") or not Profile.equipped.chest.is_empty())
	check("aperçu : la case visée en pointillés (torse)", picker.panel.grid.target == "chest")
	# Maj : tout le détail
	picker.set_detail(true)
	await _settle()
	check("Maj tenue : cartes complètes (puits d'encre)", picker.detail and float((picker._buttons[0] as Button).get_meta("measure_pad")) > 0.0)
	picker.set_detail(false)
	await _settle()
	check("Maj relâchée : cartes courtes", not picker.detail and float((picker._buttons[0] as Button).get_meta("measure_pad")) == 0.0)
	# mode visée : bannir
	var bans := Run.bans_used
	picker.toggle_aim("ban")
	check("Bannir : mode visée, bouton « Annuler »", picker.aim == "ban" and picker.ban_button.text.begins_with("Annuler") and picker.aim_hint.text.begins_with("Bannir"))
	var elig := range(picker._cards.size()).filter(func(i): return picker.eligible(i))
	check("mode visée : les cartes non éligibles sont grisées", range(picker._buttons.size()).all(func(i): return (picker._buttons[i].modulate == Color.WHITE) == (i in elig)))
	picker._choose(elig[0] if not elig.is_empty() else 0)
	await _settle()
	check("bannir : un bannissement compté, le choix reste ouvert, la visée finie", Run.bans_used == bans + 1 and picker.is_open() and picker.aim == "")
	picker.toggle_aim("ban")
	picker.toggle_aim("ban")
	check("même bouton : annule le mode visée", picker.aim == "")
	# garder
	var locks := Run.locks_used
	picker.toggle_aim("keep")
	var ki := range(picker._cards.size()).filter(func(i): return picker.eligible(i))
	if not ki.is_empty():
		picker._choose(ki[0])
	await _settle()
	check("garder : une carte gardée (« GARDÉE » sur son bandeau)", Run.locks_used == locks + 1 and Run.kept.size() >= 1)
	# clavier : R relance, P passe ; touche 1 choisit
	var used := Run.rerolls_used
	picker._opened_at -= CardPicker.CONFIRM_DELAY_MS
	_key(picker, KEY_R)
	await _settle()
	check("clavier : R relance (%d -> %d)" % [used, Run.rerolls_used], Run.rerolls_used == used + 1)
	picker._opened_at -= CardPicker.CONFIRM_DELAY_MS
	var g0 := Profile.gold
	_key(picker, KEY_P)
	await _settle()
	check("clavier : P passe (or %d -> %d), le choix suivant s'ouvre" % [g0, Profile.gold], Profile.gold > g0 and picker.is_open() and picker._title.text == "Niveau 9 !"
		and not picker.sub_label.text.contains("attente"))
	# manette : Y bannir (visée), B annule, X relance, B passe
	Gamepad._set_active(true)
	picker._refresh_reroll()
	await _settle()
	check("manette : cadre sur la 1re carte", UiNav.cursor == picker._buttons[0])
	await _tap(JOY_BUTTON_Y)
	check("manette : Y → Bannir (visée)", picker.aim == "ban" or picker.ban_button.disabled)
	await _tap(JOY_BUTTON_B)
	check("manette : B annule la visée sans passer", picker.aim == "" and picker.is_open())
	used = Run.rerolls_used
	await _tap(JOY_BUTTON_X)
	check("manette : X relance", Run.rerolls_used == used + 1 or picker._reroll.disabled)
	picker._opened_at -= CardPicker.CONFIRM_DELAY_MS
	g0 = Profile.gold
	await _tap(JOY_BUTTON_B)
	check("manette : B passe", not picker.is_open() and Profile.gold > g0)
	Gamepad._set_active(false)
	# mots
	picker.offer("Coffre du gardien : choisis une carte", SurvivorCards.chest_cards("sv_guardian"), func(): return SurvivorCards.chest_cards("sv_guardian"), 1)
	await _settle()
	check("coffre : « Coffre du gardien » / « Choisis une carte »", picker._title.text == "Coffre du gardien" and picker.sub_label.text == "Choisis une carte")
	var words := _bad_words(_texts(picker))
	check("choix de carte : aucun mot « run / build / set / lobby » (%s)" % str(words), words.is_empty())
	picker._queue.clear()
	picker._show_next()
	p.queue_free()
	picker.queue_free()
	Run.finish("abandon")
	Profile.end_run_survival()


func _key(picker: CardPicker, k: Key) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = true
	picker._unhandled_input(e)


func _tap(button: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	await get_tree().process_frame
	var u := InputEventJoypadButton.new()
	u.device = 0
	u.button_index = button
	u.pressed = false
	Input.parse_input_event(u)
	await get_tree().process_frame


# --- rendu : états tirés au hasard ---------------------------------------------------------------------------------------------
func _render(res: Vector2i) -> void:
	get_tree().root.size = res
	await _settle(2)
	var n := int(OS.get_environment("SVX2_STATES")) if OS.get_environment("SVX2_STATES") != "" else 120
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + res.x
	var picker := SurvivorPicker.new()
	add_child(picker)
	var seen := 0
	var over: Array = []
	var bad: Array = []
	var off: Array = []
	var syn := 0
	var types := {}
	var classes := ["warrior", "magician", "ranger", "cleric", "thief"]
	for i in n:
		Survivor.start(String(classes[i % classes.size()]), "limestone")
		SurvivorCards.minutes_override = rng.randf_range(0.0, 20.0)
		var steps := rng.randi_range(0, 60)
		for s in steps:
			Run.hero_level = 1 + s
			var opts := Run.roll_cards(3)
			if opts.is_empty():
				break
			Run.apply_card(SurvivorCards.auto_pick(opts, true))
		var offer: Array = Run.roll_cards(3) if i % 3 != 2 else SurvivorCards.chest_cards(["sv_head", "sv_weapon", "sv_spell", "sv_guardian", "sv_anvil", "sv_ring"][rng.randi() % 6])
		if offer.is_empty():
			Run.finish("abandon")
			Profile.end_run_survival()
			continue
		picker.offer("Niveau %d ! Choisis une carte" % Run.hero_level, offer, func(): return Run.roll_cards(3))
		await _settle()
		for detail in [false, true]:
			picker.set_detail(detail)
			await _settle(3)
			var cap := picker.card_cap()
			for k in picker._buttons.size():
				var c: Dictionary = picker._cards[k]
				var need := picker.needed_height(k)
				if need > cap + 0.5:
					over.append("%s%s (%d > %d) %s" % ["détail " if detail else "", String(c.type), roundi(need), roundi(cap), String(c.get("title", ""))])
				if not detail:
					seen += 1
					types[String(c.type)] = int(types.get(String(c.type), 0)) + 1
					if SurvivorCardView.synergy(c) != "":
						syn += 1
					var txt := _texts(picker._buttons[k])
					if "Eden" in txt or RegEx.create_from_string("\\d\\.\\d+ ?%").search(txt) != null or not _bad_words(txt).is_empty():
						bad.append("%s : %s" % [String(c.type), txt.substr(0, 90).replace("\n", " | ")])
		# tout l'écran du choix tient dans la fenêtre (cartes, panneau, barre)
		var vr := Rect2(Vector2.ZERO, Vector2(res))
		for ctl in [picker._row, picker.panel, picker._reroll.get_parent(), picker._title]:
			var r: Rect2 = (ctl as Control).get_global_rect()
			if not vr.grow(1.0).encloses(r):
				off.append("%s %s" % [ctl.get_class(), str(r)])
		picker.set_detail(false)
		picker._queue.clear()
		picker._show_next()
		Run.finish("abandon")
		Profile.end_run_survival()
	SurvivorCards.minutes_override = -1.0
	# avec la fiche de découverte (« pièce à vie ») sous le titre : tout tient encore
	Survivor.start("warrior", "limestone")
	preload("res://tests/shot_sv5.gd").rich_state()
	Profile.tutorial["seen"] = []
	picker.offer("Niveau 35 ! Choisis une carte", [SurvivorCards.up_card("head", "epic"), SurvivorCards.new_piece_card("boots"), SurvivorCards.new_piece_card("necklace")],
		func(): return Run.roll_cards(3))
	picker.offer("Niveau 36 ! Choisis une carte", Run.roll_cards(3), func(): return Run.roll_cards(3))
	await _settle(4)
	var vr2 := Rect2(Vector2.ZERO, Vector2(res)).grow(1.0)
	var bar_r := (picker._reroll.get_parent() as Control).get_global_rect()
	check("%dx%d : avec la fiche « %s », barre, cartes et panneau dans la fenêtre (%s)" % [res.x, res.y, picker.tip_id, str(bar_r)], picker._tip.visible
		and vr2.encloses(bar_r) and vr2.encloses(picker._row.get_global_rect()) and vr2.encloses(picker.panel.get_global_rect())
		and range(picker._buttons.size()).all(func(k): return picker.needed_height(k) <= picker.card_cap() + 0.5))
	Profile.tutorial["seen"] = ["sv_first", "sv_locked", "sv_tier"]
	picker._queue.clear()
	picker._show_next()
	Run.finish("abandon")
	Profile.end_run_survival()
	print("[svx2] %s : %d cartes, %s, synergies écrites : %d" % [str(res), seen, str(types), syn])
	check("%dx%d : cartes rendues (%d), toutes les familles" % [res.x, res.y, seen], seen >= n * 2 and ["sv_piece", "sv_piece_up", "sv_weapon_up", "upgrade"].all(func(t): return types.has(t)))
	check("%dx%d : aucune carte ne déborde, courte ou complète (%d) %s" % [res.x, res.y, over.size(), str(over.slice(0, 4))], over.is_empty())
	check("%dx%d : l'écran du choix tient dans la fenêtre (%d) %s" % [res.x, res.y, off.size(), str(off.slice(0, 3))], off.is_empty())
	check("%dx%d : textes sans « Eden », point décimal ni mot interdit %s" % [res.x, res.y, str(bad.slice(0, 3))], bad.is_empty())
	picker.queue_free()


# --- en jeu : HUD v2, moments, pause « Équipement » ------------------------------------------------------------------------------
func _world() -> void:
	Profile.reset_all()
	Profile.tutorial = {"mode": "skip", "steps": [], "seen": ["sv_first", "sv_locked", "sv_tier"], "version": Version.NUMBER}
	Survivor.start("warrior", "limestone")
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().create_timer(1.5, true, false, true).timeout
	while world.get("cards") == null:
		await get_tree().process_frame
	check("monde : choix de carte v2 (SurvivorPicker)", world.cards is SurvivorPicker)
	world.cards._queue.clear()
	world.cards._show_next()
	var hud: Hud = world.hud
	var sv: SurvivorHud = hud._sv_hud
	check("HUD v2 posé (barre d'XP, chrono, collection, vie)", sv != null and sv.xp != null and sv.clock != null and sv.collection.is_inside_tree() and sv.hp.is_inside_tree())
	check("HUD : orbes et compteur de dégâts retirés", not hud._xp_orb.visible and not hud._hp_orb.visible and not hud._dmg_box.visible and not hud._clock_label.visible)
	Run.apply_card(SurvivorCards.weapon_card())
	Run.apply_card(SurvivorCards.spell_card(int(Run.class_data().skills[0].id)))
	world.player.skills_changed.emit()
	await _settle()
	check("HUD : grille 4 × 3 (2 enchaînements dessinés) et touche en pastille", hud._slots[0].chain_slots == Run.MAX_CHAIN and hud._slots[0].key_sticker)
	check("HUD : « Sorts 1 / 12 »", sv.spells_label.text == "Sorts 1 / %d" % Survivor.SPELL_MAX)
	var vr := Rect2(Vector2.ZERO, Vector2(get_tree().root.size))
	check("HUD : barre d'XP pleine largeur, chrono au centre haut", sv.xp.size.x >= vr.size.x - 1.0 and absf(sv.clock.get_global_rect().get_center().x - vr.get_center().x) < 2.0)
	check("HUD : tout tient dans 1280 × 720", vr.grow(1.0).encloses(sv.clock.get_global_rect()) and vr.grow(1.0).encloses(sv.hp.get_global_rect())
		and vr.grow(1.0).encloses(sv.collection.get_global_rect()))
	world.director.time = 296.0
	await _settle()
	check("frise : gardien annoncé (fraise), la frise tremble", sv.guardian_state(0) == 1 and sv.clock.shake > 0.0)
	# moments : montée de niveau, évolution
	world.player.leveled_up.emit(10)
	check("moment : « Niveau ! » au-dessus du héros", sv.moments.items.any(func(e): return String(e.text) == "Niveau !"))
	world.cards.picked.emit({"type": "sv_evolution", "id": "storm_lord", "title": "Seigneur de la tempête"})
	await _settle()
	check("moment : évolution (bannière) et journal", sv.moments.items.any(func(e): return String(e.kind) == "banner" and String(e.sub) == "Seigneur de la tempête")
		and SurvivorLog.moments.any(func(m): return String(m.text).contains("Seigneur de la tempête")))
	# dégâts par source en vrai : un coup du héros sur un monstre
	world.director.dev_spawn_elite()
	await _settle()
	var mons := get_tree().get_nodes_in_group("monsters")
	if not mons.is_empty():
		SurvivorLog.tag = "weapon"
		(mons[0] as Monster).take_damage(123.0, world.player)
		SurvivorLog.tag = ""
	check("dégâts par source : le coup du héros est compté (arme)", float(SurvivorLog.totals.get("weapon", 0.0)) > 0.0)
	# pause : page « Équipement »
	world.pause_menu.open()
	await _settle()
	var sc: PageScreen = world.pause_menu._screen
	var page: SurvivorBuildPage = sc.page(0)
	var ptxt := _texts(page)
	check("pause : page « Équipement » en premier", page != null and sc.current_page() == 0 and _texts(sc).contains("Équipement") and not _texts(sc).contains("Build"))
	page.set_work_open(true)
	await _settle()
	ptxt = _texts(page)
	check("Équipement : « Qui fait le travail », Panoplies, sous-titre sans « build »", ptxt.contains("Qui fait le travail") and ptxt.contains("Panoplies")
		and page.subtitle().contains("cartes") and _bad_words(ptxt + page.subtitle()).is_empty())
	check("Équipement : une source au moins dans « Qui fait le travail »", page._work.get_child_count() >= 2)
	page.set_work_open(false)
	await _settle()
	check("Équipement : tient en largeur à 1280 (colonne repliée, %d px)" % roundi(page.get_combined_minimum_size().x), page.get_combined_minimum_size().x <= 1240.0)
	world.pause_menu.close()
	world.queue_free()
	await _settle()
	Run.finish("abandon")
	Profile.end_run_survival()
	get_tree().paused = false


# --- bilan v2 ------------------------------------------------------------------------------------------------------------------
func _bilan() -> void:
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_tree().root.size = res
		Profile.reset_all()
		Survivor.start("warrior", "beluga", 2)
		SurvivorCards.seed_with(3)
		preload("res://tests/shot_sv5.gd").rich_state()
		Run.max_level = 31
		Run.kills = 2812
		Run.elites = 14
		SurvivorLog.begin()
		for k in [["weapon", 41000.0], ["skill:%d" % int(Run.all_skills()[0].id), 27000.0], [SurvivorLog.proc_tag("ember_0"), 16000.0]]:
			SurvivorLog.tag = String(k[0])
			SurvivorLog.note(float(k[1]))
		SurvivorLog.tag = ""
		SurvivorLog.moment(337.0, "Gardien 1 vaincu en 0:37", "guardian")
		SurvivorLog.moment(611.0, "Jet parfait : Couronne", "perfect")
		SurvivorLog.moment(1200.0, "Arène du boss", "boss")
		SurvivorRewards.stats = {"time": 1361.0, "guardians": 3, "arena": true, "early": 0.0}
		RunJournal._time = 30.0
		Run.finish("victoire")
		var rs := ResultsScreen.new()
		var spec := rs.spec()
		check("bilan : 4 tuiles (niveau, monstres 2 812, gardiens, boss)", spec.tiles.size() == 4 and spec.tiles[0][0] == "31" and spec.tiles[1][0] == "2 812" and spec.tiles[2][1] == "gardiens" and spec.tiles[3][0] == "vaincu")
		check("bilan : sous-titre classe · Survivant · palier · zone · durée", String(spec.subtitle).contains("Survivant · palier II") and String(spec.subtitle).ends_with("22:41"))
		check("bilan : Rejouer (principal), Changer de classe, Menu principal", spec.buttons.size() == 3 and spec.buttons[0].text == "Rejouer" and spec.buttons[0].primary
			and spec.buttons[2].text == "Menu principal")
		check("bilan : plus de colonne « build » (équipement en cases)", not spec.has("build") and (spec.gear as Array).size() >= 3)
		add_child(rs)
		rs.show_results()
		await _settle(6)
		var block: Control = rs._body.get_node_or_null("SurvivorBilan")
		var txt := _texts(rs)
		check("%dx%d bilan v2 : « Qui a fait le travail », « Ton équipement final », moments" % [res.x, res.y], block != null and txt.contains("QUI A FAIT LE TRAVAIL")
			and txt.contains("TON ÉQUIPEMENT FINAL") and txt.contains("Gardien 1 vaincu en 0:37"))
		check("%dx%d bilan : aucun mot interdit (%s)" % [res.x, res.y, str(_bad_words(txt))], _bad_words(txt).is_empty())
		var vr := Rect2(Vector2.ZERO, Vector2(res))
		var pr: Rect2 = rs._panel.get_global_rect()
		check("%dx%d bilan : tient dans la fenêtre (%s)" % [res.x, res.y, str(pr)], vr.grow(1.0).encloses(pr))
		rs.queue_free()
		await _settle()
		get_tree().paused = false
		Profile.end_run_survival()
