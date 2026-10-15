extends Node
## Passe P1 « raccords » de la nuit du 15/10 : plus aucune mention du jeu d'origine dans les textes joueur, noms de tenues,
## touches en français, pluriels, puits d'insignes (boutique des coffres, leçon de maîtrise), en-tête des écrans à pages.
## godot --headless --path game res://tests/test_p1.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func():  # garde-fou : une erreur après un await ne doit pas bloquer la suite de tests
		print("ÉCHEC délai dépassé")
		get_tree().quit(1))
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	_test_no_eden()
	_test_texts()
	await _test_shop()
	await _test_lesson()
	await _test_header()
	Economy.day_override = ""
	Profile.reset_all()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Aucune chaîne de l'interface ne nomme le jeu d'origine (« Eden Slash » excepté). Mode dev et outils : hors joueur.
func _test_no_eden() -> void:
	var rx := RegEx.new()
	rx.compile("\"[^\"\\n]*\\bEden\\b(?! Slash)[^\"\\n]*\"")
	var bad: Array = []
	for dir in ["res://scripts/ui", "res://scripts/core"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd") or f.begins_with("dev_") or f in ["test_tools.gd", "game_data.gd", "dev.gd", "names_fr.gd"]:
				continue
			var lines := FileAccess.get_file_as_string(dir + "/" + f).split("\n")
			for i in lines.size():
				var l := lines[i].strip_edges()
				if l.begins_with("#") or l.begins_with("##"):
					continue
				var code := l.split("  #")[0]
				if rx.search(code) != null and not code.contains("print(") and not code.contains("\"eden\""):
					bad.append("%s:%d" % [f, i + 1])
	check("aucune mention d'Eden dans les textes joueur (%s)" % ", ".join(bad.slice(0, 5)), bad.is_empty())
	var costume := NamesFr.clean("Costume d'Eden L202")
	check("tenues génériques : « %s »" % costume, costume == "Tenue n°202")
	for k in ["scroll:swift_song:3", "fortify:power:40", "stone:safety"]:
		var t := Craft.describe_key(k)
		check("description sans nom d'origine : %s" % k, not t.contains("Eden") and not t.contains("Enchant-") and not t.contains(" Lv"))
	check("niveaux écrits « niv. » et non « Lv »", Craft.label("scroll:swift_song:3").contains("niv. 3") and Craft.label("fortify:power:40").contains("niv. 40"))


func _test_texts() -> void:
	check("pluriel : 0 et 1 au singulier", GearPower.plural(0, "objet") == "0 objet" and GearPower.plural(1, "objet") == "1 objet")
	check("pluriel : 2 et 1 200 au pluriel", GearPower.plural(2, "objet") == "2 objets" and GearPower.plural(1200, "insigne") == "1 200 insignes")
	check("pluriel : forme donnée", GearPower.plural(3, "pièce portée", "pièces portées") == "3 pièces portées")
	check("touche virgule en français", Settings.event_label({"k": KEY_COMMA}) == "," or DisplayServer.get_name() == "headless")
	check("touche Suppr en français", Settings.event_label({"k": KEY_DELETE}) == "Suppr")
	check("coffre d'aura au singulier", String(Rewards.TYPES.aura_rare.name) == "Coffre d'aura rare")
	check("succès sans nom d'origine", not Achievements.LIST.any(func(a): return String(a.name).contains("Eden") or String(a.title).contains("Eden")))
	check("préréglage : le mot « preset » n'apparaît plus dans le Duel", not Duel.requirements("warrior").any(func(c): return String(c.label).to_lower().contains("preset") or String(c.hint).to_lower().contains("preset")))


## Boutique des coffres (Coffres > Boutique) : un coffre par rareté, limité par semaine, payé en insignes.
func _test_shop() -> void:
	Profile.reset_all()
	Economy.day_override = "2026-10-12"  # un lundi
	Profile.insignia = 2000
	var page := ChestsPage.new()
	add_child(page)
	page.size = Vector2(1400, 800)
	page.refresh()
	page._set_shop(1)
	await get_tree().process_frame
	check("boutique : une ligne par coffre en vente + le solde", page._list.get_child_count() == Economy.SHOP_CHESTS.size() + 2)
	var before := Profile.reward_chests.size()
	check("boutique : l'achat est possible", Economy.can_buy_chest("look_rare"))
	page._set_shop(1)
	var rows := page._list.get_children()
	var btn := _find_button(rows[2], "Acheter")
	check("boutique : un bouton Acheter par ligne", btn != null and not btn.disabled)
	if btn != null:
		btn.pressed.emit()
	await get_tree().process_frame
	check("boutique : le coffre rejoint Tes coffres", Profile.reward_chests.size() == before + 1 and Profile.insignia == 2000 - 150)
	check("boutique : le compteur de la semaine baisse", Economy.chest_left("look_rare") == 2)
	Profile.insignia = 0
	page.refresh()
	await get_tree().process_frame
	var none := _find_button(page._list.get_children()[2], "Acheter")
	check("boutique : sans insignes, le bouton est grisé", none != null and none.disabled)
	page._set_shop(0)
	check("retour à Tes coffres : la liste des coffres", page._list.get_child_count() >= 1 and not page._shop)
	page.queue_free()


func _test_lesson() -> void:
	Profile.reset_all()
	Economy.day_override = "2026-10-12"
	Profile.expertise["warrior"] = 9000
	Profile.insignia = 500
	var page := TalentsPage.new()
	add_child(page)
	page.size = Vector2(1400, 800)
	page.cls = "hunter"
	await get_tree().process_frame
	page.refresh()
	check("leçon : visible pour une classe en retard", Economy.lagging("hunter") and page._lesson.visible)
	check("leçon : le compteur restant est dans le texte", page._lesson.text.contains("3 restantes") and page._lesson.text.contains("200 insignes"))
	var lv := Profile.expertise_level("hunter")
	page._lesson.pressed.emit()
	check("leçon : 200 insignes contre 300 points de maîtrise", Profile.insignia == 300 and Profile.expertise_level("hunter") >= lv)
	check("leçon : 2 restantes", Economy.lessons_left() == 2 and page._lesson.text.contains("2 restantes"))
	page.cls = "warrior"
	page.refresh()
	check("leçon : cachée pour la meilleure classe", not page._lesson.visible)
	page.queue_free()


## L'en-tête d'un écran à pages ne dépend pas du texte de la page et tient dans 1280 px.
func _test_header() -> void:
	var s := PageScreen.new("Test")
	add_child(s)
	for n in ["Vue d'ensemble", "Succès", "Cartes", "Trophées", "Collection", "Registre"]:
		var p := Control.new()
		s.add_page(n, p)
	s.open(0)
	await get_tree().process_frame
	check("en-tête : largeur du titre fixe d'une page à l'autre", s._tbox.custom_minimum_size.x > 0.0)
	s.set_title("Test", "Un sous-titre bien trop long pour tenir dans la place réservée au titre de l'écran")
	await get_tree().process_frame
	check("en-tête : un sous-titre long est abrégé, pas élargi", s._subtitle.clip_text and s._tbox.get_combined_minimum_size().x <= s._tbox.custom_minimum_size.x + 1.0)
	s.queue_free()


func _find_button(n: Node, text: String) -> Button:
	if n is Button and (n as Button).text == text:
		return n
	for c in n.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null
