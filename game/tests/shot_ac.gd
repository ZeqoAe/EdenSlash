extends Node
## Captures du lot AC-G (interface de l'Échiquier), en 1280 × 720 puis 1600 × 900 : préparation (fiche d'unité),
## boutique à la manette, unité tenue (zone « Vendre »), atout, choix partagé, combat, bilan de manche, fin de partie.
## Une ligne « [débord] … » par contrôle hors de l'écran ou par panneau qui en chevauche un autre.
## Fichiers user://shots/ac_<largeur>_*.png. APPDATA détourné : godot --path game res://tests/shot_ac.tscn

var screen: AutochessScreen
var overflow := 0


func _shot(name: String) -> void:
	if screen and screen.cursor:
		screen.cursor._last_mouse = get_viewport().get_mouse_position()
	await get_tree().create_timer(0.7).timeout
	_check_overflow(name)
	DirAccess.make_dir_recursive_absolute("user://shots")
	var w := get_window().size.x
	get_viewport().get_texture().get_image().save_png("user://shots/ac_%d_%s.png" % [w, name])
	print("[shot] ac_%d_%s" % [w, name])


## Contrôles visibles des calques de l'interface : dans l'écran, et les panneaux du cadre sans chevauchement.
func _check_overflow(name: String) -> void:
	var vr := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	for layer in [screen._ui, screen._top, screen.recap.get_parent()]:
		for c in layer.find_children("*", "Control", true, false):
			var ctl := c as Control
			if not ctl.is_visible_in_tree() or ctl.size.x < 2.0 or ctl.modulate.a < 0.05:
				continue
			if ctl.get_parent() is Control and not (ctl.get_parent() as Control).clip_contents and ctl is Label \
					and (ctl as Label).text == "":
				continue
			var r := UiNav.rect_of(ctl)
			if not vr.grow(1.0).encloses(r):
				print("[débord] %s %s : %s hors de %s" % [name, ctl.name, r, vr.size])
				overflow += 1
	var hud := screen.hud
	var panels := {"traits": hud.traits, "fiche": hud.unit_card, "stratèges": hud.players, "haut": hud._top,
		"bas": hud._bottom, "or": hud._gold_tab, "équipes": screen.team_bars, "compteur": screen.meter}
	var keys := panels.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Control = panels[keys[i]]
			var b: Control = panels[keys[j]]
			if a.is_visible_in_tree() and b.is_visible_in_tree() and UiNav.rect_of(a).grow(-1.0).intersects(UiNav.rect_of(b).grow(-1.0)):
				if keys[i] == "bas" and keys[j] == "or" or keys[i] == "or" and keys[j] == "bas":
					continue  # l'onglet de l'or chevauche le bord de la boutique, voulu
				print("[débord] %s chevauchement %s / %s" % [name, keys[i], keys[j]])
				overflow += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "magician"
	Profile.hero_name = "Aelis"
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = res
		await get_tree().process_frame
		if screen:
			# le bilan de fin du tour précédent met l'arbre en pause (ResultsPanel) : sans ce retour, la 2e passe
			# (1600 × 900) restait bloquée à la manche 1-1 (le pilote ne tournait plus)
			screen._close_results()
			screen.recap.close()
			screen.queue_free()
			await get_tree().process_frame
		get_tree().paused = false
		Gamepad._set_active(false)
		AutochessScreen.config = {"seed": 21, "save_path": "", "fast": true}
		screen = load("res://scenes/autochess.tscn").instantiate()
		add_child(screen)
		await get_tree().create_timer(0.8).timeout
		await _shot("0_ouverture")
		# quelques manches au pilote, puis la main au joueur à 3-1
		screen.autoplay = true
		var guard := 0
		while not (screen.game.stage == 3 and screen.game.round_i == 1 and screen.phase == "prep") and guard < 6000:
			guard += 1
			await get_tree().process_frame
		screen.autoplay = false
		var g := screen.game
		var p: Dictionary = g.players[0]
		while not g.pending(0).is_empty():
			g.choose(0, 0)
		screen._open_choices()
		p.gold = 37
		p.hp = maxi(int(p.hp), 64)
		screen._sync()
		screen.timer = 18.0
		var unit_cell := Vector2i(-1, -1)
		for u in p.board:
			unit_cell = Vector2i(int(u.cell[0]), int(u.cell[1]))
			break
		if unit_cell.x >= 0:
			screen.cursor._set_slot(AutochessBoard.board_slot(unit_cell.x, unit_cell.y), "keys")
		await _shot("1_preparation")
		# lot ACX-2 : un achat, le bouton Annuler au bout de l'onglet de l'or
		for i in AutochessData.SHOP_SIZE:
			if String(p.shop[i]) != "" and screen.game.buy(0, i):
				break
		screen._sync()
		await _shot("1b_annuler")
		screen.game.undo(0)
		screen._sync()
		# fiche d'un objet du banc d'objets
		(p.items as Array).append("executeur")
		screen._sync()
		screen.cursor._set_slot(AutochessBoard.items_slot((p.items as Array).size() - 1), "keys")
		await _shot("2_objet")
		# lot ACX-3 : fiche d'un composant, ses 8 recettes (celles qu'on peut faire en tête)
		(p.items as Array).append("lame")
		(p.items as Array).append("gant")
		screen._sync()
		screen.cursor._set_slot(AutochessBoard.items_slot((p.items as Array).size() - 2), "keys")
		await _shot("2b_recettes")
		(p.items as Array).resize((p.items as Array).size() - 2)
		screen._sync()
		# manette : cadre doré sur une carte de la boutique, fiche de cette unité
		Gamepad._set_active(true)
		UiNav.focus(screen.hud.shop.cards[2])
		await _shot("3_manette_boutique")
		Gamepad._set_active(false)
		# unité du banc tenue : la boutique laisse la place à « Vendre »
		var bi := -1
		for i in AutochessData.BENCH_SIZE:
			if p.bench[i] != null:
				bi = i
				break
		if bi >= 0:
			screen.cursor._set_slot(AutochessBoard.bench_slot(bi), "keys")
			screen.cursor.activate()
			await _shot("4_tenue")
			screen.cursor.cancel()
		# atout (or) : 3 cartes, la 2e visée
		(p.pending as Array).append({"kind": "atout", "rarity": "or", "rerolls": 1,
			"options": ["interets_composes", "chef_de_guerre", "garde_du_corps"]})
		screen._open_choices()
		Gamepad._set_active(true)
		UiNav.focus(screen.choice.cards[1])
		await _shot("5_atout")
		Gamepad._set_active(false)
		g.choose(0, 1)
		screen.choice.visible = false
		screen._open_choices()
		# choix partagé
		g._start_carousel()
		screen._cr_done = -1.0
		screen._open_choices()
		screen.fast = false
		await get_tree().create_timer(2.5).timeout
		await _shot("6_choix_partage")
		screen.fast = true
		guard = 0
		while screen.carousel.visible and guard < 2000:
			guard += 1
			if screen._my_carousel_turn():
				var c := g.pending(0)
				g.choose(0, 0)
			await get_tree().process_frame
		g._finish_carousel()
		screen._dirty = true
		await get_tree().process_frame
		# vrai combat dans l'arène (lot AC-V), puis bilan de manche
		screen.fast = false
		screen.real_combat = true
		screen._end_prep()
		await get_tree().create_timer(0.05).timeout
		await _shot("7a_banniere_combat")
		await get_tree().create_timer(1.3).timeout
		await _shot("7_combat")
		screen.meter.set_collapsed(false)
		var frames: Array = []
		var t0 := Time.get_ticks_msec()
		while screen.phase == "combat" and Time.get_ticks_msec() - t0 < 60000:
			var u0 := Time.get_ticks_usec()
			await get_tree().process_frame
			frames.append((Time.get_ticks_usec() - u0) / 1000.0)
			if frames.size() == 360:
				await _shot("7b_melee")
			if frames.size() == 700:
				screen.meter.set_tab("heal")
				await _shot("7c_compteur_soins")
				screen.meter.set_tab("dealt")
		# lot ACX-3 : coup au stratège (projectiles en vol, puis le chiffre sur la figurine)
		await get_tree().create_timer(0.3).timeout
		get_viewport().get_texture().get_image().save_png("user://shots/ac_%d_7d_coup.png" % get_window().size.x)
		print("[shot] ac_%d_7d_coup (coups : %s)" % [get_window().size.x, str(screen.strikes)])
		frames.sort()
		if not frames.is_empty():
			print("[shot] combat rendu dans l'arène : image médiane %.1f ms, p95 %.1f ms (%d images)" % [frames[frames.size() / 2],
				frames[int(frames.size() * 0.95)], frames.size()])
		await _shot("8_bilan")
		screen._open_detail()  # lot ACX-2 : le bilan complet sur [Détail] (le bandeau ne bloque plus rien)
		if screen.recap.visible:
			Gamepad._set_active(true)
			screen.recap.step_page(1)
			UiNav.focus(screen.recap.continue_button)
			await _shot("8b_bilan_subis_manette")
			Gamepad._set_active(false)
			screen.recap.close()
		screen.real_combat = false
		screen.fast = true
		# lot ACX-2 : élimination, carte « Tu es éliminé » (spectateur), puis la fin
		while screen.phase != "prep" and screen.phase != "over":
			await get_tree().process_frame
		p.hp = 0
		g._eliminate_dead()
		screen.fast = false
		screen._next_round()
		await _shot("9a_elimine")
		screen.fast = true
		# fin de partie
		screen._show_end()
		Gamepad._set_active(true)
		UiNav.focus(screen.hud.replay_button)
		await _shot("9_fin")
		Gamepad._set_active(false)
		screen._open_game_stats()
		await _shot("9b_statistiques")
		screen.recap.close()
	AutochessScreen.config = {}
	print("[shot] débords : %d" % overflow)
	get_tree().quit()
