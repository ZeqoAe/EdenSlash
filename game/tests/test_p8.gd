extends Node
## Passe P8 : petites cartes d'information (InfoCard) : pile, fermetures, durée, confirmation, nouveautés du lobby.
## godot --headless --path game res://tests/test_p8.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _x_button(card: Control) -> Button:
	for b in card.find_children("*", "Button", true, false):
		if (b as Button).text == "×":
			return b
	return null


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	get_tree().root.size = Vector2i(1600, 900)
	var host := Node.new()
	add_child(host)
	var st := InfoCard.in_layer(host)
	var log: Array = []
	st.closed.connect(func(id, how): log.append("%s:%s" % [id, how]))
	var first := st.add_card({"id": "a", "title": "Une carte", "body": "Deux lignes de texte au plus.", "icon": "grimoire",
			"buttons": [{"label": "Compris"}, {"label": "Guide", "cb": func(): log.append("guide")}, {"label": "Plus", "kind": "link", "keep": true}]})
	st.add_card({"id": "b", "title": "Autre", "body": "Courte.", "duration": 1.2, "on_close": func(how): log.append("cb:" + String(how))})
	st.add_card({"id": "c", "title": "Troisième", "lines": ["Une phrase.", "Une autre."]})
	check("une carte de même identifiant n'est pas ajoutée deux fois", st.add_card({"id": "a", "title": "Doublon"}) == null and st.count() == 3)
	await get_tree().create_timer(0.7).timeout
	check("pile : les cartes entrent dans l'ordre et sont visibles", st.ids() == ["a", "b", "c"] and first.get_parent().modulate.a > 0.95)
	var r := first.get_global_rect()
	check("carte : 400 px de large au plus, dans la fenêtre, à droite", r.size.x <= 400.5 and r.size.x >= 380.0 and get_viewport().get_visible_rect().encloses(r) and r.position.x > 1100.0)
	check("carte : pas de fond plein écran (le calque ne capte aucun clic hors des cartes)", st.mouse_filter == Control.MOUSE_FILTER_IGNORE and st._box.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	check("carte : bouton principal = le premier, trois boutons", st.primary_button().text == "Compris" and st.buttons("a").size() == 3)
	# durée : « b » se ferme seule, avec son rappel
	await get_tree().create_timer(1.2).timeout
	check("durée : la carte se ferme seule, rappel appelé", not "b" in st.ids() and "b:auto" in log and "cb:auto" in log)
	# un bouton « garder » ne ferme pas ; un bouton normal appelle son rappel puis ferme
	st.buttons("a")[2].pressed.emit()
	check("bouton « keep » : la carte reste", "a" in st.ids())
	st.buttons("a")[1].pressed.emit()
	check("bouton : rappel appelé puis la carte se ferme", "guide" in log and not "a" in st.ids() and "a:button" in log)
	# croix
	var cx := _x_button(st._find("c").panel)
	check("croix : présente, avec une infobulle", cx != null and cx.tooltip_text == "Fermer")
	cx.pressed.emit()
	await get_tree().create_timer(0.6).timeout
	check("croix : ferme la carte, la pile est vide et nettoyée", st.count() == 0 and st._entries.is_empty() and st._box.get_child_count() == 0 and "c:x" in log)
	# une fermeture pendant l'entrée ne plante pas
	st.add_card({"id": "d", "title": "Vite", "body": "Fermée tout de suite."})
	st.dismiss("d")
	await get_tree().create_timer(0.8).timeout
	check("fermeture avant la fin de l'entrée : propre", st.count() == 0 and st._entries.is_empty())
	# place : moins de cartes sur une petite fenêtre
	var big := st.capacity()
	get_tree().root.size = Vector2i(1280, 720)
	await get_tree().process_frame
	var small := st.capacity()
	get_tree().root.size = Vector2i(1600, 900)
	check("place : 4 cartes à 900 de haut, 3 à 720 (jamais sur les ressources du pied)", big == 4 and small == 3)
	# confirmation : clic hors du cadre = annuler ; le bouton principal rappelle après la fermeture
	var hit := [0]
	var ask := InfoCard.ask(host, "Titre", "Texte.", "Faire", func(): hit[0] += 1)
	await get_tree().create_timer(0.3).timeout
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	var dim: ColorRect = ask._root.get_child(0)
	dim.gui_input.emit(ev)
	await get_tree().create_timer(0.3).timeout
	check("confirmation : un clic à côté annule", hit[0] == 0 and not is_instance_valid(ask))
	ask = InfoCard.ask(host, "Titre", "Texte.", "Faire", func(): hit[0] += 1)
	await get_tree().create_timer(0.3).timeout
	ask.ok_button.pressed.emit()
	ask.ok_button.pressed.emit()  # un double clic ne le fait pas deux fois
	await get_tree().create_timer(0.3).timeout
	check("confirmation : le bouton principal agit une seule fois", hit[0] == 1)
	# lobby : nouveautés, et le bouton « Guide » retire les cartes
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.5).timeout
	lobby._show_news(Tutorial.news_sorted(["trophy", "chain", "cards", "dungeons", "hub_gear"]))
	await get_tree().create_timer(0.5).timeout
	check("lobby : 3 cartes puis « Tout voir dans le Guide » (grande fenêtre)", lobby.info_cards().ids() == ["hub_gear", "dungeons", "cards", "news_more"])
	lobby._guide_from_cards("news")
	await get_tree().create_timer(0.5).timeout
	check("lobby : « Guide » retire toutes les cartes", lobby.info_cards().count() == 0)
	lobby.queue_free()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
