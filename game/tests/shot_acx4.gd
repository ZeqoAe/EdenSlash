extends Node
## Captures du lot ACX-4 (L'Échiquier), en 1280 × 720 puis 1600 × 900 : préparation avec les objets en icônes à gauche et
## les enclumes des atouts sur le plateau, or en sacs (toi et les stratèges), fiche d'un style (traits croisés), carte d'une
## unité pont dans la boutique, combat avec la boutique ouverte et le banc en vignettes.
## Fichiers user://shots/acx4_<largeur>_*.png ; lignes « [débord] » : panneau hors de l'écran ou panneaux qui se chevauchent.
## APPDATA détourné : godot --path game res://tests/shot_acx4.tscn

var screen: AutochessScreen
var overflow := 0


func _shot(name: String) -> void:
	await get_tree().create_timer(0.7).timeout
	_check(name)
	DirAccess.make_dir_recursive_absolute("user://shots")
	var w := get_window().size.x
	get_viewport().get_texture().get_image().save_png("user://shots/acx4_%d_%s.png" % [w, name])
	print("[shot] acx4_%d_%s" % [w, name])


func _check(name: String) -> void:
	var vr := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var hud := screen.hud
	var panels := {"traits": hud.traits, "objets": hud.item_tray, "stratèges": hud.players, "bas": hud._bottom,
		"banc": hud.bench_strip, "haut": hud._top}
	for k in panels:
		var c: Control = panels[k]
		if c.is_visible_in_tree() and not vr.grow(1.0).encloses(c.get_global_rect()):
			print("[débord] %s %s hors de l'écran : %s" % [name, k, c.get_global_rect()])
			overflow += 1
	var keys := panels.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Control = panels[keys[i]]
			var b: Control = panels[keys[j]]
			if a.is_visible_in_tree() and b.is_visible_in_tree() and a.get_global_rect().grow(-1.0).intersects(b.get_global_rect().grow(-1.0)):
				print("[débord] %s chevauchement %s / %s" % [name, keys[i], keys[j]])
				overflow += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Settings.set_v("autochess", "guide_done", true)
	Profile.selected_class = "magician"
	Profile.hero_name = "Aelis"
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = res
		await get_tree().process_frame
		if screen:
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
		p.items = ["lame", "arc", "larme", "executeur", "pince"]
		if (p.augments as Array).is_empty():
			p.augments = ["tirelire"]
		p.shop[0] = "mecha_ares"  # une unité pont (3 traits)
		screen._sync()
		screen.timer = 18.0
		screen.cursor._set_slot(AutochessBoard.items_slot(3), "keys")
		await _shot("1_objets_enclumes")
		screen.cursor._set_slot({}, "keys")
		screen._trait_card("estoc")
		await _shot("2_style")
		screen._close_trait_cards()
		# combat : boutique ouverte, banc en vignettes (vrai combat, durée normale)
		screen.fast = false
		screen.real_combat = true
		screen._end_prep()
		guard = 0
		while screen.phase != "combat" and guard < 600:
			guard += 1
			await get_tree().process_frame
		screen.speed = 1
		screen.hud.set_combat_shop(true)
		screen._sync()
		await _shot("3_combat_boutique")
		screen.hud.set_combat_shop(false)
		await _shot("4_combat_replie")
	print("[shot] débords : %d" % overflow)
	get_tree().quit()
