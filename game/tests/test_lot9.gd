extends Node
## Lot 9 : tutoriel (Premiers pas, fiches, nouveautés), accueil, Guide.
## godot --headless --path game res://tests/test_lot9.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = false
	Settings.reset_all()
	Profile.reset_all()
	Tutorial._counts = {}
	check("nouvelle partie : pas de choix de tutoriel", Tutorial.mode() == "")
	# ancienne sauvegarde jouée : explications coupées, nouveautés seules
	Profile.runs_done = 4
	Tutorial.init_for_save()
	check("partie déjà jouée : tutoriel coupé", Tutorial.mode() == "skip" and not Tutorial.guided())
	var news := Tutorial.news_to_show()
	check("nouveautés annoncées une fois, puis la version est notée", news.size() > 0 and Tutorial.news_to_show().is_empty())
	# nouvelle partie guidée
	Profile.reset_all()
	var w := Welcome.new()
	add_child(w)
	await get_tree().process_frame
	w._class = "magician"
	w._control_i = 1
	w._aid = "relax"
	w.finish()
	check("accueil : classe, contrôles et aide appliqués", Profile.selected_class == "magician" and Settings.move_mode() == "click" and Settings.assist_level() != "assisted")
	check("accueil : mode guidé gardé", Tutorial.mode() == "guided")
	# Premiers pas dans la Survie
	Run.start_survival("warrior", 1)
	check("Premiers pas actifs en Survie guidée", Tutorial.guided() and Tutorial.steps_done().is_empty())
	Tutorial.event("weapon")
	check("étape 1 validée : arme choisie", Tutorial.steps_done() == ["weapon"])
	for i in 9:
		Tutorial.event("kill")
	check("9 monstres : étape pas encore validée", not "fight" in Tutorial.steps_done())
	var fin := Tutorial.event("kill")
	check("10e monstre : étape validée", fin.get("id") == "fight")
	Tutorial.event("dodge")
	check("l'événement doit venir dans l'ordre de la liste (esquive attend le saut ? non : chaque étape suit son événement)", "dodge" in Tutorial.steps_done())
	check("texte d'étape avec les touches réelles", Tutorial.step_text(Tutorial.current_step()).contains("[") or Tutorial.current_step().id == "jump")
	for s in ["jump", "card", "skill", "chain", "chest", "seal", "boss"]:
		Tutorial.event(s)
	check("10 étapes faites : Premiers pas terminés", Tutorial.done_all() and not Tutorial.guided())
	# fiches : 1re occurrence seulement
	Tutorial.event("cards_open")
	check("1re ouverture de cartes : fiche en attente", Tutorial.pending_card == "cards")
	check("la fiche est prise une fois", Tutorial.take_card() == "cards" and Tutorial.take_card() == "")
	Tutorial.event("cards_open")
	check("déjà vue : plus jamais proposée", Tutorial.pending_card == "")
	Profile.tutorial["cards_off"] = true
	Tutorial.event("weapon_up")
	check("conseils coupés : aucune fiche", Tutorial.pending_card == "")
	Profile.tutorial["cards_off"] = false
	# passer
	Profile.tutorial["steps"] = []
	Tutorial.skip_steps()
	check("Passer : étapes toutes cochées, rien de bloqué", Tutorial.done_all())
	Run.active = false
	# Premiers pas : jamais en dehors de la Survie
	Run.start_survival("warrior", 1)
	Profile.tutorial["steps"] = []
	check("Premiers pas actifs en Survie", Tutorial.guided())
	Duel.active = true
	check("Premiers pas masqués en Duel", not Tutorial.guided() and Tutorial.event("weapon").is_empty())
	Duel.active = false
	Training.active = true
	check("Premiers pas masqués à l'entraînement", not Tutorial.guided())
	Training.active = false
	Run.active = false
	check("Premiers pas masqués hors run", not Tutorial.guided())
	# textes : fiches courtes, sans pourcentage ni mention du jeu d'origine, rangées dans un chapitre du Guide
	var chapter_ids: Array = Guide.CHAPTERS.map(func(c): return c[0])
	check("Guide : 6 onglets au plus", Guide.CHAPTERS.size() <= 6)
	var bad_cards: Array = []
	for id in Tutorial.CARDS:
		var c: Dictionary = Tutorial.CARDS[id]
		var all: String = " ".join(c.lines) + String(c.title)
		if c.lines.size() > 3 or "%" in all or "Eden" in all or not String(c.chapter) in chapter_ids:
			bad_cards.append(id)
	check("fiches : 3 lignes au plus, sans %% ni Eden, chapitre connu %s" % str(bad_cards), bad_cards.is_empty())
	# P8 : texte des petites cartes (nouveautés, fiches en jeu) : une ou deux phrases courtes, sans tiret long ni jargon
	var bad_short: Array = []
	for id in Tutorial.CARDS:
		var c: Dictionary = Tutorial.CARDS[id]
		var sh := String(c.get("short", ""))
		var spec := Tutorial.card_spec(id)
		if sh == "" or sh.length() > 125 or String(c.title).length() > 26 or "—" in sh or "–" in sh or "—" in String(c.title) or "%" in sh or "Eden" in sh 				or MenuWidgets.icon(String(c.get("icon", ""))) == null or String(spec.body) != sh or String(spec.title) != String(c.title):
			bad_short.append(id)
	check("cartes d'information : texte court (125 signes), titre court, sans tiret long ni %%, icône %s" % str(bad_short), bad_short.is_empty())
	var sorted_news := Tutorial.news_sorted(["cards", "hub_gear", "chain", "dungeons"])
	check("nouveautés : la plus récente d'abord, puis l'ordre d'écriture", sorted_news == ["hub_gear", "dungeons", "cards", "chain"])
	var bad_steps: Array = []
	for s in Tutorial.STEPS:
		if "%" in String(s.text) or "Eden" in String(s.text):
			bad_steps.append(s.id)
	check("Premiers pas : sans pourcentage ni Eden %s" % str(bad_steps), bad_steps.is_empty())
	# Guide
	var g := Guide.open_on(self, "commands")
	await get_tree().process_frame
	check("Guide ouvert sur Commandes (ancien identifiant)", g.current_page() == 0 and g.page_count() == Guide.CHAPTERS.size())
	var txt := ""
	for b in Guide.blocks_for("controls"):
		txt += String(b.text)
	check("Commandes : touches du joueur, pas de touches de test", txt.contains("Sauter") and not txt.contains("F9") and not txt.contains("Tests et retours"))
	g.select("chain")
	check("fiche d'un chapitre : onglet Sorts et cartes, bloc visé", g.current_page() == 1 and g.page(1)._blocks.has("chain"))
	for i in Guide.CHAPTERS.size() - 1:
		g.show_page(i)
		await get_tree().process_frame
		check("chapitre « %s » : des blocs" % Guide.CHAPTERS[i][1], g.page(i)._blocks.size() >= 3)
	g.select("news")
	# la nouveauté la plus récente change à chaque fiche ajoutée (0.1.191 : Géants et Menace) : on la relit au lieu de la figer
	var released: Array = Tutorial.CARDS.keys().filter(func(id): return Tutorial._vkey(String(Tutorial.CARDS[id].version)) <= Tutorial._vkey(Version.NUMBER))
	var latest: String = String(Tutorial.news_sorted(released)[0])
	check("« news » mène à la dernière nouveauté (%s, chapitre %s)" % [latest, Tutorial.chapter_of(latest)], g.current_page() == Guide.chapter_index(Tutorial.chapter_of(latest)))
	g.show_page(Guide.chapter_index("details"))
	await get_tree().process_frame
	check("Détails : l'ancienne page d'aide", g.page(Guide.chapter_index("details")) is InfoPage)
	g.close()
	await get_tree().process_frame
	check("Guide fermé : la partie n'est plus en pause", not get_tree().paused)
	# Accueil : le panneau tient dans la fenêtre à plusieurs tailles
	var win := get_tree().root
	var old_size := win.size
	for sz in [Vector2i(1600, 900), Vector2i(1280, 720), Vector2i(1024, 576), Vector2i(800, 600)]:
		win.size = sz
		var w2 := Welcome.new()
		add_child(w2)
		await get_tree().process_frame
		await get_tree().process_frame
		for step in 3:
			match step:
				1: w2._step_class()
				2: w2._step_controls()
			await get_tree().process_frame
			await get_tree().process_frame
			var r := w2._panel.get_global_rect()
			var vp := get_viewport().get_visible_rect().size
			check("accueil %dx%d écran %d : panneau dans la fenêtre" % [sz.x, sz.y, step + 1], r.position.x >= -1.0 and r.position.y >= -1.0 and r.end.x <= vp.x + 1.0 and r.end.y <= vp.y + 1.0)
		w2.queue_free()
		await get_tree().process_frame
	win.size = old_size
	get_tree().paused = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
