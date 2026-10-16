extends Node
## Lot K1 : curseurs de souris au choix et réticule de visée (CursorSets, AimReticle, Paramètres).
## godot --headless --path game res://tests/test_k1.tscn  (paramètres de test uniquement)

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


## Un pixel visible à moins de [param r] pixels du point chaud.
func _opaque_near(img: Image, p: Vector2, r: int) -> bool:
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			var x := int(p.x) + dx
			var y := int(p.y) + dy
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a > 0.5:
				return true
	return false


func _ready() -> void:
	Settings.reset_all()
	# --- défauts et valeurs invalides
	check("défaut : curseur classique", CursorSets.current() == "classic")
	check("défaut : réticule point, taille 1, or", AimReticle.shape() == "dot" and is_equal_approx(AimReticle.size_factor(), 1.0) and AimReticle.color() == UiTheme.GOLD)
	Settings.set_v("interface", "cursor_set", "n_importe_quoi")
	check("curseur inconnu : retour au défaut", CursorSets.current() == "classic")
	Settings.set_v("interface", "cursor_set", 12)
	check("curseur de mauvais type : retour au défaut", CursorSets.current() == "classic")
	Settings.set_v("interface", "reticle", "zzz")
	Settings.set_v("interface", "reticle_color", "zzz")
	Settings.set_v("interface", "reticle_size", 99.0)
	check("réticule inconnu : défauts", AimReticle.shape() == "dot" and AimReticle.color() == UiTheme.GOLD)
	check("taille du réticule bornée", is_equal_approx(AimReticle.size_factor(), AimReticle.SIZE_MAX))
	Settings.set_v("interface", "reticle_size", "grand")
	check("taille de mauvais type : 1", is_equal_approx(AimReticle.size_factor(), 1.0))

	# --- chaque curseur se charge, points chauds dans l'image
	check("au moins 10 jeux de curseurs", CursorSets.LIST.size() >= 10)
	var all_ok := true
	var hot_ok := true
	var size_ok := true
	for e in CursorSets.LIST:
		var id: String = e[0]
		if id == CursorSets.DEFAULT:
			check("classique : aucune image (curseur du système)", CursorSets.image(id, "arrow", 32) == null)
			continue
		for kind in CursorSets.SHAPES:
			for size in [32, 48]:
				var img := CursorSets.image(id, kind, size)
				if img == null:
					all_ok = false
					print("   manque : ", id, " ", kind, " ", size)
					continue
				size_ok = size_ok and img.get_width() == size and img.get_height() == size
				var h := CursorSets.hotspot(id, kind, size)
				if not (h.x >= 0 and h.y >= 0 and h.x < size and h.y < size and _opaque_near(img, h, 3)):
					hot_ok = false
					print("   point chaud hors forme : ", id, " ", kind, " ", size, " ", h)
	check("chaque jeu : 4 formes en 32 et 48 px chargées", all_ok)
	check("images carrées de la bonne taille", size_ok)
	check("points chauds dans l'image, sur la forme", hot_ok)
	check("noms français", CursorSets.name_of("gauntlet") == "Gantelet" and CursorSets.name_of("zzz") == "Classique")

	# --- application et persistance
	Settings.set_v("interface", "cursor_set", "blade")
	check("réglage appliqué", CursorSets.current() == "blade" and CursorSets.applied == "blade")
	Settings.set_v("display", "ui_scale", 1.5)
	check("interface agrandie : curseur 48 px", CursorSets.pixel_size() == 48 and CursorSets.applied_size == 48)
	Settings.set_v("display", "ui_scale", 1.0)
	check("interface normale : curseur 32 px", CursorSets.pixel_size() == 32 and CursorSets.applied_size == 32)
	Settings.set_v("interface", "reticle", "circle")
	Settings.set_v("interface", "reticle_size", 1.4)
	Settings.set_v("interface", "reticle_color", "cyan")
	Settings.data = Settings.DEFAULTS.duplicate(true)  # comme un nouveau lancement
	Settings.load_settings()
	check("persistance du curseur", CursorSets.current() == "blade")
	check("persistance du réticule", AimReticle.shape() == "circle" and is_equal_approx(AimReticle.size_factor(), 1.4) and AimReticle.color() == Color(0.35, 0.9, 1.0))
	Settings.reset_section("interface")
	check("réinitialisation : classique", CursorSets.current() == "classic" and CursorSets.applied == "classic")

	# --- quand le réticule s'affiche
	var tree := get_tree()
	Settings.set_v("game", "aim_mode", "smart")
	var hero := Node.new()
	hero.add_to_group("player")
	add_child(hero)
	check("visée automatique : pas de réticule", not AimReticle.wanted(tree))
	Settings.set_v("game", "aim_mode", "cursor")
	check("visée au curseur avec un héros : réticule", AimReticle.wanted(tree))
	Settings.set_v("game", "aim_mode", "action")
	check("mode Action : réticule", AimReticle.wanted(tree))
	Settings.set_v("interface", "reticle", "off")
	check("« Aucun » : pas de réticule", not AimReticle.wanted(tree))
	Settings.set_v("interface", "reticle", "cross")
	var was_pad := Gamepad.active
	Gamepad.active = true
	check("manette : pas de réticule", not AimReticle.wanted(tree))
	Gamepad.active = was_pad
	tree.paused = true
	check("en pause : pas de réticule", not AimReticle.wanted(tree))
	tree.paused = false
	hero.remove_from_group("player")
	check("sans héros (menus) : pas de réticule", not AimReticle.wanted(tree))
	hero.queue_free()
	var r := AimReticle.new()
	check("le réticule ignore la souris", r.mouse_filter == Control.MOUSE_FILTER_IGNORE and not r.visible)
	r.free()

	# --- Paramètres : lignes présentes, aperçu
	var menu := SettingsMenu.new()
	add_child(menu)
	menu.ensure_built()
	var titles: Array[String] = []
	for l in menu.find_children("*", "Label", true, false):
		titles.append((l as Label).text)
	for t in ["Curseur de la souris", "Réticule de visée", "Taille du réticule", "Couleur du réticule", "Aperçu"]:
		check("Paramètres : ligne « %s »" % t, t in titles)
	var prev := menu.find_children("*", "CursorPreview", true, false)
	check("Paramètres : aperçu présent", prev.size() == 1)
	Settings.set_v("interface", "cursor_set", "crystal")
	(prev[0] as CursorPreview).refresh()
	check("aperçu : 4 formes du jeu choisi", (prev[0] as CursorPreview)._icons.size() == 4)
	menu.queue_free()

	Settings.reset_all()
	print("K1 : ", "TOUT VERT" if fails == 0 else "%d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
