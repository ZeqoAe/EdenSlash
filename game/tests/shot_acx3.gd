extends Node
## Captures du lot ACX-3 (L'Échiquier), en 1280 × 720 puis 1600 × 900 : première partie guidée, format Éclair (frise,
## étiquette), survol riche d'un stratège et adversaire probable, recettes d'un composant, planificateur (cible dans la
## boutique), bilan v2 (équipe finale, coffres révélés), page du lobby (formats, partie du jour). Une ligne « [débord] … »
## par contrôle visible hors de l'écran. Fichiers user://shots/acx3_<largeur>_*.png ; APPDATA détourné :
##   godot --path game res://tests/shot_acx3.tscn

var screen: AutochessScreen
var overflow := 0


func _shot(name: String, root: Node = null, wait := 0.6) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	_check_overflow(name, root if root != null else screen)
	DirAccess.make_dir_recursive_absolute("user://shots")
	var w := get_window().size.x
	get_viewport().get_texture().get_image().save_png("user://shots/acx3_%d_%s.png" % [w, name])
	print("[shot] acx3_%d_%s" % [w, name])


func _check_overflow(name: String, root: Node) -> void:
	var vr := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	for c in root.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl.size.x < 2.0 or ctl.modulate.a < 0.05:
			continue
		if ctl is Label and (ctl as Label).text == "":
			continue
		if ctl.get_parent() is ScrollContainer or _in_scroll(ctl):
			continue
		var r := UiNav.rect_of(ctl)
		if not vr.grow(1.0).encloses(r):
			print("[débord] %s %s : %s hors de %s" % [name, ctl.name, r, vr.size])
			overflow += 1


func _in_scroll(c: Node) -> bool:
	var n := c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false


func _ready() -> void:
	Training.active = true
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		Settings.reset_all()
		Profile.reset_all()
		Profile.selected_class = "magician"
		Profile.hero_name = "Aelis"
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = res
		get_tree().paused = false
		await get_tree().process_frame
		Gamepad._set_active(false)
		# --- première partie guidée, format Éclair -------------------------------------------------------------------
		AutochessScreen.config = {"seed": 21, "save_path": "", "fast": false, "real": false, "diff": 1, "format": "eclair"}
		screen = load("res://scenes/autochess.tscn").instantiate()
		add_child(screen)
		await get_tree().create_timer(0.8).timeout
		var g := screen.game
		var p: Dictionary = g.players[0]
		if screen.choice.visible:
			(screen.choice.cards[0] as Button).pressed.emit()
		await get_tree().process_frame
		await _shot("1_guide_eclair")
		p.gold = 10
		for i in AutochessData.SHOP_SIZE:
			if String(p.shop[i]) != "":
				screen._buy(i)
				break
		screen._sync()
		await _shot("2_guide_etape2")
		# --- survol riche d'un stratège ----------------------------------------------------------------------------
		screen.hud.players.record(g)
		screen._sync()
		var row: AutochessPlayers.Row = screen.hud.players.rows[3]
		var tip: Control = row._make_custom_tooltip("") as Control
		screen._ui.add_child(tip)
		await get_tree().process_frame
		var rr := row.get_global_rect()
		tip.position = Vector2(rr.position.x - tip.size.x - 10.0, rr.position.y)
		await _shot("3_survol_stratege")
		tip.queue_free()
		# --- recettes d'un composant, planificateur ----------------------------------------------------------------
		p.items = ["lame", "arc", "larme"]
		screen._sync()
		screen.cursor._set_slot(AutochessBoard.items_slot(0), "keys")
		await _shot("4_recettes")
		screen.cursor.slot = {}
		AutochessPlanner.clear()
		var sid := String(p.shop[1]) if String(p.shop[1]) != "" else String(p.shop[2])
		AutochessPlanner.toggle(sid)
		for i in AutochessData.SHOP_SIZE:
			if String(p.shop[i]) == "":
				p.shop[i] = sid
		screen._sync()
		screen.hud.shop.hovered = 1
		await _shot("5_planificateur")
		screen.hud.shop.hovered = -1
		AutochessPlanner.clear()
		if screen.guide != null:
			screen.guide.close(true)
		screen.queue_free()
		await get_tree().process_frame
		# --- bilan v2 : équipe finale, coffres révélés ---------------------------------------------------------------
		var r := AutochessResults.new()
		add_child(r)
		var team: Array = [{"id": "warrior", "stars": 3, "items": ["executeur", "precision", "lame"]},
			{"id": "magician", "stars": 2, "items": ["arcanes"]}, {"id": "knight", "stars": 2, "items": []},
			{"id": "hunter", "stars": 1, "items": ["lame_vive"]}, {"id": "cleric", "stars": 2, "items": []},
			{"id": "assassin", "stars": 1, "items": []}, {"id": "bard", "stars": 2, "items": ["source"]}]
		var got := {"chests": [{"type": "look_common", "text": "Finir dans les 4 premiers", "kind": "first"},
			{"type": "look_rare", "text": "Finir dans les 2 premiers", "kind": "first"},
			{"type": "look_epic", "text": "Gagner la partie", "kind": "first"}],
			"titles": [{"title": "Tacticien", "text": "Victoire en Vétéran", "new": true}],
			"daily": {"place": 1, "best": 1, "new_best": true, "first": false, "best_ever": 1}}
		var podium: Array = []
		for k in 8:
			podium.append({"name": ["Aelis", "Daphné", "Élouan", "Faustine", "Gauvain", "Héloïse", "Ysolde", "Tristan"][k],
				"class_id": ["magician", "warrior", "hunter", "cleric", "knight", "assassin", "bard", "sage"][k], "place": k + 1,
				"trait": ["Arcane", "Rempart", "Traque", "Ferveur", "Rempart", "Ombre", "Chœur", "Arcane"][k], "me": k == 0})
		r.show_results({"diff": 1, "place": 1, "rounds": 19, "rounds_won": 13, "secs": 812.0, "team": team, "daily": true},
			{}, got, {}, podium)
		await _shot("6_bilan_coffres", r, 2.4)
		get_tree().paused = false
		r.queue_free()
		await get_tree().process_frame
		# --- page du lobby : formats et partie du jour ---------------------------------------------------------------
		var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
		add_child(lobby)
		await get_tree().create_timer(1.5).timeout
		lobby._show_menu("autochess")
		await _shot("7_lobby_formats", lobby, 0.8)
		var daily: Control = lobby.find_child("AcDaily", true, false)
		var n: Node = daily.get_parent() if daily != null else null
		while n != null and not n is ScrollContainer:
			n = n.get_parent()
		if n is ScrollContainer and daily != null:
			(n as ScrollContainer).ensure_control_visible(daily)
		await _shot("8_lobby_partie_du_jour", lobby, 0.6)
		lobby.queue_free()
		await get_tree().process_frame
	AutochessScreen.config = {}
	print("[shot] débords : %d" % overflow)
	get_tree().quit()
