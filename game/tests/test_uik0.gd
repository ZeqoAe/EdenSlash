extends Node
## Socle de l'interface (UIK0) : jetons chargés, polices (accents, chiffres, signes) et replis, boîtes autocollant des
## boutons dans tous leurs états, UiFeel branché tout seul sur les boutons sans changer leur zone cliquable ni la navigation
## manette, « Réduire les animations », réglages, coût du branchement et du dessin.
## godot --headless --path game res://tests/test_uik0.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## Attend que [param cond] soit vrai (au plus [param max_s] secondes) : en headless les images ont des durées très
## inégales, une attente fixe ne suffit pas toujours à une animation.
func _until(cond: Callable, max_s := 1.5) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > int(max_s * 1000.0):
			return false
		await get_tree().process_frame
	return true


## Le point [param p] (écran) est-il dans la zone cliquable du contrôle, échelle comprise (test de Godot) ?
func _inside(c: Control, p: Vector2) -> bool:
	var local := c.get_global_transform().affine_inverse() * p
	return Rect2(Vector2.ZERO, c.size).has_point(local)


func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit(1))
	Settings.reset_all(false)
	# --- jetons et peau
	check("jetons chargés (tokens.json v2)", String(UiTheme.tok("version", "")) == "2.0.0")
	check("encre 700 = #221A3A", UiTheme.color("encre.700").is_equal_approx(Color("221a3a")))
	check("lagon foncé (focus) = #0B7DB5", UiTheme.color("bonbon.lagon.fonce").is_equal_approx(Color("0b7db5")))
	check("durée d'appui 60 ms, relâchement 220 ms", is_equal_approx(UiTheme.dur("appui"), 0.06) and is_equal_approx(UiTheme.dur("relache"), 0.22))
	check("peau par défaut : sticker", UiTheme.skin == "sticker")
	check("réglages du ressenti par défaut", Settings.get_v("interface", "ui_reduce_motion") == false and Settings.get_v("interface", "ui_vibration") == true
		and is_equal_approx(float(Settings.get_v("interface", "ui_fx")), 1.0))
	# --- polices
	for p in [UiTheme.FONT_TITLE, UiTheme.FONT_BODY, UiTheme.FONT_LABEL, UiTheme.FONT_BOLD, UiTheme.FONT_NUMBER]:
		check("police présente : " + p.get_file(), FileAccess.file_exists(p) and UiTheme.font(p) is FontFile)
	check("licences OFL copiées", FileAccess.file_exists("res://assets/fonts/OFL-MochiyPopOne.txt") and FileAccess.file_exists("res://assets/fonts/OFL-MPLUSRounded1c.txt"))
	var body := UiTheme.font(UiTheme.FONT_BODY)
	var title := UiTheme.font(UiTheme.FONT_TITLE)
	var fr := "ÉÈÊËÀÂÎÏÔÛÙÜÇŒéèêëàâîïôûùüçœÿ«»’€0123456789"
	var miss_body := ""
	var miss_title := ""
	for ch in fr:
		if not body.has_char(ch.unicode_at(0)):
			miss_body += ch
		if not title.has_char(ch.unicode_at(0)):
			miss_title += ch
	check("M PLUS Rounded : tous les accents et chiffres (manque : %s)" % miss_body, miss_body == "")
	check("Mochiy Pop One : tous les accents et chiffres (manque : %s)" % miss_title, miss_title == "")
	var signs := "×→▲▼★✔✕›…·•"
	var miss_signs := ""
	for ch in signs:
		if not body.has_char(ch.unicode_at(0)):
			miss_signs += ch
	check("signes du jeu dans la police du texte (manque : %s)" % miss_signs, miss_signs == "")
	var chained := (UiTheme.body_font() as FontVariation).base_font
	check("replis de police (Nunito puis système)", chained is FontFile and (chained as FontFile).fallbacks.size() >= 1 and (chained as FontFile).allow_system_fallback)
	check("titres en Mochiy (variation avec approche)", UiTheme.title_font() is FontVariation and (UiTheme.title_font() as FontVariation).base_font == title)
	var h_new := UiTheme.body_font().get_height(16)
	var h_old := UiTheme.font(UiTheme.FONT_FALLBACK).get_height(16)
	check("hauteur de ligne du texte ≤ celle de Nunito (%.1f / %.1f px) : pas de débord" % [h_new, h_old], h_new <= h_old + 0.5)
	var t_new := UiTheme.title_font().get_height(32)
	check("hauteur de ligne des titres (%.1f px à 32) proche de Cinzel (43 px)" % t_new, t_new <= 44.5)
	check("police par défaut du thème = M PLUS Rounded", ThemeDB.get_default_theme().default_font == UiTheme.body_font())
	# --- boîtes et états
	var st := UiTheme.button_states("papier")
	check("6 états d'un bouton (normal, survol, appui, désactivé, choisi…)", st.has_all(["normal", "hover", "pressed", "hover_pressed", "disabled", "selected"]))
	var n: UiTheme.StickerBox = st.normal
	check("contour d'encre 3 px, coins 14, ombre dure", n.border == 3 and n.radius == 14 and n.shadow > 0 and n.ink.is_equal_approx(UiTheme.color("encre.700")))
	check("survol : la face monte de 3 px", (st.hover as UiTheme.StickerBox).lift == -3)
	check("appui : la face descend sur son ombre", (st.pressed as UiTheme.StickerBox).lift == (st.pressed as UiTheme.StickerBox).shadow)
	check("désactivé : tramé, contour encre 300", (st.disabled as UiTheme.StickerBox).trame and (st.disabled as UiTheme.StickerBox).ink.is_equal_approx(UiTheme.color("encre.300")))
	check("choisi : lagon", (st.selected as UiTheme.StickerBox).fill.is_equal_approx(UiTheme.color("bonbon.lagon.base")))
	check("hauteur réservée identique dans tous les états (pas de saut de mise en page)",
		st.values().all(func(b): return is_equal_approx(b.content_margin_top + b.content_margin_bottom, n.content_margin_top + n.content_margin_bottom)))
	# --- un bouton du thème, branché tout seul
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var b := Button.new()
	b.text = "Équiper"
	b.position = Vector2(200, 200)
	b.size = Vector2(160, 48)
	var hits := [0]
	b.pressed.connect(func(): hits[0] += 1)
	root.add_child(b)
	await get_tree().process_frame
	check("UiFeel : tout bouton est concerné, sans branchement", UiFeel.target_of(b) == b and b.mouse_entered.get_connections().is_empty())
	check("bouton du thème : autocollant", b.get_theme_stylebox("normal") is UiTheme.StickerBox)
	var t := Button.new()
	t.toggle_mode = true
	root.add_child(t)
	check("bouton à bascule : variation ToggleButton (choisi = lagon)", t.theme_type_variation == &"ToggleButton"
		and (t.get_theme_stylebox("pressed") as UiTheme.StickerBox).fill.is_equal_approx(UiTheme.color("bonbon.lagon.base")))
	var rect0 := b.get_global_rect()
	var center := rect0.get_center()
	check("navigable par la manette", UiNav.navigable(b))
	# survol, appui, relâchement, sortie (UiFeel piloté directement : en headless la souris n'atteint pas l'interface)
	UiFeel.reduce_motion = false
	UiFeel.intensity = 1.0
	UiFeel._enter(b, false)
	await _until(func(): return b.scale.x > 1.02)
	await _wait(0.15)
	check("survol : léger agrandissement (≈ 4 %%) : %.3f" % b.scale.x, b.scale.x > 1.02 and b.scale.x < 1.06)
	check("survol : taille et position inchangées", b.size == rect0.size and b.position == rect0.position)
	check("survol : le centre reste dans la zone cliquable", _inside(b, center))
	UiFeel._press(b)
	await _until(func(): return b.scale.x > b.scale.y + 0.05)
	check("appui : écrasement (plus large, moins haut)", b.scale.x > b.scale.y)
	check("appui : le centre (clic de la manette) reste dans la zone cliquable", _inside(b, center))
	UiFeel._release(b)
	await _wait(0.3)
	UiFeel._exit(b)
	await _until(func(): return b.scale.is_equal_approx(Vector2.ONE))
	check("sortie : retour exact au repos (échelle 1)", b.scale.is_equal_approx(Vector2.ONE))
	check("zone cliquable au repos inchangée", b.get_global_rect().is_equal_approx(rect0) and UiNav.rect_of(b).is_equal_approx(rect0))
	b.pressed.emit()
	check("le clic passe toujours", hits[0] == 1)
	# focus de la manette : le contrôle visé grossit, le précédent revient
	var b2 := Button.new()
	b2.text = "Autre"
	b2.position = Vector2(400, 200)
	b2.size = Vector2(120, 48)
	root.add_child(b2)
	Gamepad.active = true  # la manette est la dernière entrée : UiNav garde son cadre
	UiNav.shown = true
	UiNav.cursor = b
	UiFeel.nav_focus(b, null)
	var up: bool = await _until(func(): return b.scale.x > 1.02)
	UiNav.cursor = b2
	UiFeel.nav_focus(b2, b)
	await _until(func(): return b2.scale.x > 1.02 and b.scale.is_equal_approx(Vector2.ONE))
	check("focus manette : le bouton visé grossit, le précédent revient au repos (%s %.3f %.3f)" % [up, b2.scale.x, b.scale.x], up and b2.scale.x > 1.02 and b.scale.is_equal_approx(Vector2.ONE))
	Gamepad.active = false
	UiNav.shown = false
	UiNav.cursor = null
	UiFeel._focused = null
	UiFeel._exit(b2)
	await _wait(0.3)
	# bouton désactivé : secousse puis retour exact à sa place
	b.disabled = true
	UiFeel.deny(b)
	var shook: bool = await _until(func(): return not is_equal_approx(b.position.x, rect0.position.x))
	await _until(func(): return not b.has_meta("_uf_shake"))
	check("désactivé cliqué : secousse (refus)", shook)
	check("désactivé : revient exactement à sa place", b.position.is_equal_approx(rect0.position))
	b.disabled = false
	# « Réduire les animations » : plus d'échelle (le son et la vibration restent)
	Settings.set_v("interface", "ui_reduce_motion", true)
	check("réglage lu par UiFeel", UiFeel.reduce_motion)
	UiFeel._enter(b, false)
	await _wait(0.2)
	check("animations réduites : aucune échelle au survol", b.scale.is_equal_approx(Vector2.ONE))
	UiFeel._exit(b)
	Settings.set_v("interface", "ui_reduce_motion", false)
	# genre « off » : rien ne bouge
	var off := Button.new()
	off.set_meta("ui_feel", "off")
	root.add_child(off)
	check("genre « off » : ignoré par UiFeel", UiFeel.target_of(off) == null)
	# interrupteur : s'aplatit à l'appui, revient au relâchement
	var sw := UiTheme.Switch.new()
	sw.position = Vector2(200, 320)
	sw.size = Vector2(60, 30)
	root.add_child(sw)
	UiFeel._press(sw)
	var squashed: bool = await _until(func(): return sw.squash > 1.05)
	UiFeel._release(sw)
	await _until(func(): return absf(sw.squash - 1.0) < 0.05)
	check("interrupteur : s'aplatit à l'appui puis revient", squashed and absf(sw.squash - 1.0) < 0.05)
	# onglet d'écran : variation PageTab, l'actif en mandarine
	var tab := Button.new()
	tab.toggle_mode = true
	tab.theme_type_variation = &"PageTab"
	root.add_child(tab)
	check("onglet actif en mandarine", (tab.get_theme_stylebox("pressed") as UiTheme.StickerBox).fill.is_equal_approx(UiTheme.color("bonbon.mandarine.base")))
	# zone papier : textes à l'encre, boutons papier
	var paper := PanelContainer.new()
	root.add_child(paper)
	UiTheme.scope(paper)
	var pl := Label.new()
	paper.add_child(pl)
	check("zone papier : texte à l'encre", pl.get_theme_color("font_color").is_equal_approx(UiTheme.color("encre.700")))
	# peau nuit (option technique) puis retour
	UiTheme.set_skin("night")
	check("peau nuit : panneau nuit", (UiTheme.panel_style() as UiTheme.StickerBox).fill.is_equal_approx(UiTheme.color("encre.500")))
	UiTheme.set_skin("sticker")
	check("peau sticker : panneau papier", (UiTheme.panel_style() as UiTheme.StickerBox).fill.is_equal_approx(UiTheme.color("papier.100")))
	# passage au papier (UIK1) : texte clair d'un écran existant → encre sur le papier, gardé clair dans un puits d'encre
	var sheet := PanelContainer.new()
	UiTheme.paper(sheet)
	root.add_child(sheet)
	var col := VBoxContainer.new()
	sheet.add_child(col)
	var light := Hud._label(col, "Texte clair", 16, UiTheme.TEXT)
	var p_gold := Hud._label(col, "Or", 16, UiTheme.GOLD)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", UiTheme.well_style())
	col.add_child(well)
	var inwell := Hud._label(well, "Dans le puits", 16, UiTheme.TEXT)
	var kept := Hud._label(col, "Titre", 16, UiTheme.GOLD)
	kept.set_meta("ink_keep", true)
	await _until(func(): return light.get_theme_color("font_color").get_luminance() < 0.3, 1.0)
	check("papier : texte clair → encre, contour retiré", light.get_theme_color("font_color").is_equal_approx(UiTheme.color("encre.700"))
		and light.get_theme_constant("outline_size") == 0)
	check("papier : or → or foncé lisible", p_gold.get_theme_color("font_color").get_luminance() < 0.4)
	check("papier : texte d'un puits d'encre gardé clair", inwell.get_theme_color("font_color").is_equal_approx(UiTheme.TEXT))
	check("papier : « ink_keep » laisse le titre autocollant", kept.get_theme_color("font_color").is_equal_approx(UiTheme.GOLD))
	check("on_paper : blanc → encre, lilas → encre 300", UiTheme.on_paper(Color.WHITE).is_equal_approx(UiTheme.color("encre.700"))
		and UiTheme.on_paper(UiTheme.MUTED).is_equal_approx(UiTheme.color("encre.300")))
	# pastilles d'onglet : API officielle de PageScreen (UIK1)
	var ps := PageScreen.new("Essai")
	add_child(ps)
	ps.add_page("A", Control.new())
	ps.add_page("B", Control.new())
	check("PageScreen.set_tab_badge : une pastille sur l'onglet", ps.set_tab_badge(1, ["essai.uik1"]) is NewsDot and ps.set_tab_badge(5, []) == null)
	ps.queue_free()
	# rayons de soleil derrière le primaire survolé (StickerBox.rays)
	check("primaire survolé : rayons de soleil", (UiTheme.button_states("soleil").hover as UiTheme.StickerBox).rays)
	# MenuWidgets : API inchangée, autocollants
	var gold := MenuWidgets.gold_button("Jouer", 26, Vector2(200, 56))
	check("bouton primaire : soleil, ressenti « primaire »", (gold.get_theme_stylebox("normal") as UiTheme.StickerBox).fill.is_equal_approx(UiTheme.color("bonbon.soleil.base"))
		and String(gold.get_meta("ui_feel", "")) == "primary")
	check("panneau des menus (glass) : puits d'encre", MenuWidgets.glass(12).bg_color.is_equal_approx(Color(UiTheme.color("encre.500"), 0.9)))
	gold.free()
	# coûts (budget du socle : < 0,3 ms par écran chargé) : UiFeel ne branche rien sur les boutons ; il voit passer chaque
	# nœud ajouté (pour les boutons à bascule) : un écran de 300 nœuds dont 40 boutons (10 à bascule)
	var nodes: Array[Node] = []
	for i in 260:
		nodes.append(Label.new())
	for i in 40:
		var x := Button.new()
		x.toggle_mode = i % 4 == 0
		nodes.append(x)
	var feel_us := INF
	for k in 5:
		var t1 := Time.get_ticks_usec()
		for nd in nodes:
			UiFeel._on_node_added(nd)
		feel_us = minf(feel_us, float(Time.get_ticks_usec() - t1))
	for nd in nodes:
		nd.free()
	print("[uik0] UiFeel sur un écran de 300 nœuds : %.0f µs" % feel_us)
	check("UiFeel : < 0,3 ms pour un écran de 300 nœuds", feel_us < 300.0)
	var ci := RenderingServer.canvas_item_create()
	UiTheme.legacy_boxes = true  # (UIK2 : flat_box est passé à la DA ; la mesure compare au bouton d'avant)
	var old := UiTheme.flat_box(Color(0.14, 0.11, 0.24, 0.96), UiTheme.GOLD_DIM, 2, 8)  # bouton d'avant (0.1.256)
	UiTheme.legacy_boxes = false
	var draw_us := INF
	var old_us := INF
	for k in 5:
		var t0 := Time.get_ticks_usec()
		for i in 40:
			n.draw(ci, Rect2(0, 0, 180, 52))
		draw_us = minf(draw_us, float(Time.get_ticks_usec() - t0) / 40.0)
		t0 = Time.get_ticks_usec()
		for i in 40:
			old.draw(ci, Rect2(0, 0, 180, 52))
		old_us = minf(old_us, float(Time.get_ticks_usec() - t0) / 40.0)
		RenderingServer.canvas_item_clear(ci)
	RenderingServer.free_rid(ci)
	print("[uik0] dessin d'un bouton : %.1f µs autocollant, %.1f µs avant" % [draw_us, old_us])
	check("dessin : 40 boutons autocollants coûtent < 0,3 ms de plus qu'avant (redessinés seulement quand leur état change)", (draw_us - old_us) * 40.0 < 300.0)
	print("[uik0] %d échec(s)" % fails)
	get_tree().quit(1 if fails > 0 else 0)
