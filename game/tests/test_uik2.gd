extends Node
## Finitions de la peau papier (lot UIK2, conception/art/R_UIK2.md) : boîtes d'avant traduites dans la DA (plus de liseré
## or ni de fond noir, sélection lagon), raretés des cartes, passifs et coffres au code de la bible, fond flou des fenêtres
## (pause, cartes, confirmations), composants des pages (en-tête de section, état vide, chargement), case d'objet,
## mouvements (feuille qui se pose, onglet qui glisse sans décaler une page ancrée, nombres qui défilent), « Réduire les
## animations ».
## godot --headless --path game res://tests/test_uik2.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _ready() -> void:
	get_tree().create_timer(120.0, true).timeout.connect(func(): get_tree().quit(1))
	Settings.reset_all(false)
	# --- boîtes d'avant dans la DA (flat_box) -----------------------------------------------------
	var tile := UiTheme.flat_box(Color(0.06, 0.05, 0.12, 0.9), Color(UiTheme.GOLD_DIM, 0.55), 1, 8, false)
	check("tuile : plus de fond presque noir (valeur %.2f)" % tile.bg_color.v, tile.bg_color.v >= 0.3)
	check("tuile : contour d'encre, plus de liseré or", tile.border_color.is_equal_approx(UiTheme.color("encre.900")))
	check("tuile : contour de 2 px au moins, coins arrondis (≥ 10)", tile.border_width_left >= 2 and tile.corner_radius_top_left >= 10)
	check("tuile : relief d'autocollant (ombre dure décalée)", tile.shadow_size == 1 and tile.shadow_offset.y >= 3.0)
	var hot := UiTheme.flat_box(Color(0.15, 0.11, 0.24, 1.0), UiTheme.GOLD, 2, 10)
	check("survol : l'écart avec le repos est gardé", hot.bg_color.v > tile.bg_color.v)
	var sel := UiTheme.flat_box(Color(0.5, 0.36, 0.1, 1.0), UiTheme.GOLD, 1, 7, false)
	check("choisi (fond brun) : lagon, contour d'encre", sel.bg_color.is_equal_approx(UiTheme.color("bonbon.lagon.base")) and sel.border_color.is_equal_approx(UiTheme.color("encre.700")))
	var sel_dark := UiTheme.flat_box(Color(0.3, 0.22, 0.1, 1.0), Color(1.0, 0.8, 0.4), 3, 10, false)
	check("choisi sombre (texte clair dessus) : lagon foncé", sel_dark.bg_color.is_equal_approx(UiTheme.color("bonbon.lagon.fonce")))
	var frame := UiTheme.flat_box(Color(0.05, 0.04, 0.1, 0.98), UiTheme.GOLD, 2, 12)
	check("fenêtre à liseré or : contour d'encre, ombre dure", frame.border_color.is_equal_approx(UiTheme.color("encre.900")) and frame.shadow_size == 1)
	var rar := UiTheme.flat_box(Color(0.07, 0.06, 0.12, 0.95), Items.RARITIES[3].color, 2, 10)
	check("bord de rareté gardé", rar.border_color.is_equal_approx(Items.RARITIES[3].color))
	var bar := UiTheme.flat_box(UiTheme.GOLD, UiTheme.GOLD, 0, 4, false)
	check("jauge vive : inchangée", bar.bg_color.is_equal_approx(UiTheme.GOLD) and bar.border_width_left == 0 and bar.corner_radius_top_left == 4)
	check("ancien « or terni » = lilas d'encre 100", UiTheme.GOLD_DIM.is_equal_approx(UiTheme.color("encre.100")))
	UiTheme.legacy_boxes = true
	check("boîte d'avant disponible (essais)", UiTheme.flat_box(Color(0.06, 0.05, 0.12, 0.9), UiTheme.GOLD, 1, 8).border_color.is_equal_approx(UiTheme.GOLD))
	UiTheme.legacy_boxes = false
	# --- raretés : un seul code partout --------------------------------------------------------------
	var code := {"common": Items.RARITIES[0].color, "rare": Items.RARITIES[2].color, "epic": Items.RARITIES[3].color, "legendary": Items.RARITIES[5].color}
	var same := true
	for k in code:
		same = same and Cards.TIERS[k].color.is_equal_approx(code[k]) and Boons.RARITY[k].color.is_equal_approx(code[k])
	check("cartes et passifs : couleurs des raretés des objets (commun, rare lagon, épique, légendaire soleil)", same)
	check("légendaire = soleil de la bible", Cards.TIERS.legendary.color.is_equal_approx(UiTheme.color("bonbon.soleil.base")))
	check("coffres : mythique mandarine, légendaire soleil, rare lagon", Rewards.TYPES.look_epic.color.is_equal_approx(UiTheme.color("bonbon.mandarine.base"))
		and Rewards.TYPES.look_legend.color.is_equal_approx(UiTheme.color("bonbon.soleil.base")) and Rewards.TYPES.look_rare.color.is_equal_approx(UiTheme.color("bonbon.lagon.base")))
	check("mini-carte : coffre doré soleil (code des raretés)", Minimap.ICONS.chest2.is_equal_approx(UiTheme.color("bonbon.soleil.base")))
	# --- fond flou des fenêtres ----------------------------------------------------------------------
	var m := UiTheme.blur_material()
	check("fond flou : lit l'écran, voile d'encre de la bible", m.shader != null and m.shader.code.contains("hint_screen_texture")
		and (m.get_shader_parameter("veil") as Color).is_equal_approx(UiTheme.color("monde.voile-modale")))
	var dim := ColorRect.new()
	UiTheme.veil(dim, 0.85)
	check("voile d'une fenêtre : flou, jamais noir plein (voile ≤ 0,7)", dim.material is ShaderMaterial and (dim.material.get_shader_parameter("veil") as Color).a <= 0.7)
	dim.free()
	var cp := CardPicker.new()
	add_child(cp)
	await get_tree().process_frame
	check("choix de carte : la scène floutée derrière", (cp._root.get_child(0) as ColorRect).material is ShaderMaterial)
	cp.queue_free()
	var ps := PageScreen.new("Essai", 30)
	ps.pause_game = false
	add_child(ps)
	ps.add_page("A", Control.new())
	ps.add_page("B", Control.new())
	await get_tree().process_frame
	Profile.in_run = true
	ps.open(0)
	check("écran à pages en partie : scène floutée, pas le fond clair", ps._blur.visible and not ps._bg.visible)
	ps.close_ui()
	Profile.in_run = false
	ps.open(0)
	check("écran à pages au menu principal : fond clair", ps._bg.visible and not ps._blur.visible)
	# --- onglet qui glisse sans décaler une page ancrée (bug des Paramètres ouverts sur un onglet) -------
	var page_b := ps.page(1)
	var left0 := page_b.offset_left
	ps.show_page(1)
	check("onglet : la page part décalée de 24 px (glisse)", is_equal_approx(page_b.offset_left, left0 + 24.0) or UiFeel.reduce_motion)
	await _wait(0.5)
	check("onglet : la page revient exactement à ses marges d'ancrage", is_equal_approx(page_b.offset_left, left0) and page_b.position.x < 1.0)
	ps.show_page(0)
	ps.show_page(1)
	ps.show_page(0)
	await _wait(0.5)
	check("onglets changés vite : aucune page ne reste décalée", is_equal_approx(ps.page(0).offset_left, 0.0) and is_equal_approx(page_b.offset_left, left0))
	ps.close_ui()
	ps.queue_free()
	# --- nombres qui défilent -------------------------------------------------------------------------
	var l := Label.new()
	add_child(l)
	var f := func(x: float) -> String: return "%d or" % roundi(x)
	UiFeel.number(l, 10.0, f)
	check("nombre : premier affichage immédiat", l.text == "10 or")
	UiFeel.number(l, 250.0, f)
	check("nombre : sans écran (tests), la valeur finale tout de suite", l.text == "250 or")
	l.text = "x"
	UiFeel.number(l, 250.0, f)
	check("nombre : même valeur, rien ne bouge (rafraîchissement périodique)", l.text == "x")
	l.queue_free()
	# --- composants des pages ---------------------------------------------------------------------
	var box := VBoxContainer.new()
	add_child(box)
	var head := UiTheme.section_header(box, "Succès", "7 / 44")
	var ht := head.get_child(0) as Label
	check("en-tête de section : Mochiy contouré, soleil, compteur à droite", ht.get_theme_font("font") == UiTheme.title_font() and ht.get_theme_constant("outline_size") >= 3
		and ht.get_theme_color("font_color").is_equal_approx(UiTheme.color("bonbon.soleil.base")) and (head.get_child(1) as Label).text == "7 / 44")
	var hits := [0]
	var es := UiTheme.empty_state(box, "Aucun coffre pour l'instant.", "chest", "Jouer", func(): hits[0] += 1)
	var tile_p := es.get_child(0) as PanelContainer
	check("état vide : icône dans une tuile bonbon, phrase, action", tile_p.get_theme_stylebox("panel") is UiTheme.StickerBox and (es.get_child(1) as Label).text.begins_with("Aucun")
		and es.get_child(2) is Button)
	(es.get_child(2) as Button).pressed.emit()
	check("état vide : l'action répond", hits[0] == 1)
	var ld := UiTheme.Loading.new("Chargement…")
	box.add_child(ld)
	check("chargement : pastilles et phrase", ld.get_child_count() == 2 and (ld.get_child(1) as Label).text == "Chargement…")
	var grid := ItemWidgets.ItemGrid.new()
	box.add_child(grid)
	grid.set_empty_text("Aucun objet.")
	grid.set_items([])
	check("grille d'objets vide : état vide illustré", grid._empty.text == "Aucun objet." and (grid._empty.get_parent() as Control).visible)
	grid.set_items([Items.generate(10, 1.0, "head", "warrior", 1, "", 2)])
	check("grille remplie : plus d'état vide", not (grid._empty.get_parent() as Control).visible)
	box.queue_free()
	# --- « Réduire les animations » --------------------------------------------------------------
	Settings.set_v("interface", "ui_reduce_motion", true)
	UiFeel.read_settings()
	var root := Control.new()
	add_child(root)
	UiFeel.screen_in(root, [])
	check("animations réduites : l'écran s'ouvre sans fondu", is_equal_approx(root.modulate.a, 1.0))
	var row := PanelContainer.new()
	root.add_child(row)
	UiFeel.attach(row, "row")
	UiFeel._enter(row, false)
	check("rangée survolée : elle s'éclaire (la couleur reste avec les animations réduites)", row.modulate.r > 1.0)
	UiFeel._exit(row)
	check("rangée quittée : couleur normale", row.modulate.is_equal_approx(Color.WHITE))
	root.queue_free()
	Settings.set_v("interface", "ui_reduce_motion", false)
	UiFeel.read_settings()
	print("[uik2] %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
