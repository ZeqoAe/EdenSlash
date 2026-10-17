extends Node
## L'Échiquier, lot ACX-1 (P0 n° 1 à 4 de l'étude BM-AUTO) : habillage v2, traits toujours visibles, boutique v2, aides
## d'économie. Vérifie : la fiche d'unité est une bulle qui ne cache ni les traits ni les stratèges ; survol d'un trait (souris
## et manette) → ses unités et ses cartes de boutique marquées ; survol d'une carte → copies possédées marquées et « 2 → 3 »
## dans la colonne ; étoile d'amélioration (★★ et ★★★) ; flèche du trait qui monte ; barre des taux (chiffres seulement en
## infobulle) ; flamme de série ; revenu de la prochaine manche ; aucun « % » dans le texte permanent ; cadre au repos ≤ 30 %
## de l'écran en 1600 × 900 et plateau cadré hors des panneaux ; aucun contrôle hors de l'écran en 1600 × 900 et 1280 × 720.
## godot --headless --path game res://tests/test_acx1.tscn

var fails := 0
var screen: AutochessScreen


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _frames(n := 2) -> void:
	for _i in n:
		await get_tree().process_frame


func _open(res: Vector2i) -> void:
	if screen != null:
		screen.queue_free()
		await _frames(2)
	get_tree().root.size = res
	await _frames(2)
	AutochessScreen.config = {"seed": 11, "save_path": "", "fast": true}
	screen = load("res://scenes/autochess.tscn").instantiate()
	add_child(screen)
	await _frames(4)
	if screen.choice.visible:
		(screen.choice.cards[0] as Button).pressed.emit()
		await _frames(2)


## Visible texts of the frame (labels, buttons) : the permanent text.
func _permanent_texts(n: Node, out: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Label:
		out.append((n as Label).text)
	elif n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		_permanent_texts(c, out)


## Part de l'écran couverte par les panneaux du cadre au repos (somme des aires moins les recouvrements deux à deux).
func _coverage() -> float:
	var rects: Array = screen.hud.frame_rects()
	var area := 0.0
	for i in rects.size():
		area += (rects[i] as Rect2).get_area()
		for j in range(i + 1, rects.size()):
			area -= (rects[i] as Rect2).intersection(rects[j]).get_area()
	var vs := get_viewport().get_visible_rect().size
	return area / (vs.x * vs.y)


func _overflow() -> Array:
	var vr := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(1.0)
	var bad: Array = []
	for c in screen.hud.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.is_visible_in_tree() or ctl.size.x < 2.0 or ctl.modulate.a < 0.05:
			continue
		if ctl is Label and (ctl as Label).text == "":
			continue
		if not vr.encloses(UiNav.rect_of(ctl)):
			bad.append(String(ctl.name))
	return bad


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "magician"
	Profile.hero_name = "Aelis"
	Gamepad.active = false
	await _open(Vector2i(1600, 900))
	var g := screen.game
	var p: Dictionary = g.players[0]

	# --- mise en place : Voleur ×2 et Samouraï (Ombre 2 sur le plateau), deux Clercs ★★ et deux ★ au banc -----------
	p.level = 8
	p.gold = 200
	p.shop = ["thief", "thief", "samurai", "", ""]
	for slot in 3:
		g.buy(0, slot)
	var thief := -1
	var samurai := -1
	for u in g.bench_units(0):
		if String(u.id) == "thief" and thief < 0:
			thief = int(u.uid)
		elif String(u.id) == "samurai":
			samurai = int(u.uid)
	g.place(0, thief, Vector2i(1, 1))
	g.place(0, samurai, Vector2i(2, 1))
	var free_slots: Array = []
	for i in AutochessData.BENCH_SIZE:
		if p.bench[i] == null:
			free_slots.append(i)
	var uid := 9001
	for st in [2, 2, 1, 1]:
		p.bench[free_slots.pop_front()] = {"id": "cleric", "stars": st, "items": [], "uid": uid}
		uid += 1
	p.shop = ["thief", "assassin", "warrior", "cleric", "knight"]
	screen._sync()
	await _frames(3)
	var shop := screen.hud.shop
	var counts := g.trait_counts(0)
	check("mise en place : Ombre 2 sur le plateau (%s)" % str(counts.get("ombre", 0)), int(counts.get("ombre", 0)) == 2)

	# --- boutique v2 : étoile d'amélioration, mini ★★ / ★★★, flèche du trait qui monte -----------------------------------
	var star0: Control = (shop.cards[0] as Button).get_node("StarUp")
	check("boutique : Voleur (2 copies possédées) → étoile d'amélioration et ★★", bool(shop.info[0].star_up)
		and int(shop.info[0].stars) == 2 and star0.visible)
	check("boutique : Clerc (2 ★ et 2 ★★ possédés) → ★★★", bool(shop.info[3].star_up) and int(shop.info[3].stars) == 3)
	check("boutique : Guerrier → pas d'étoile", not bool(shop.info[2].star_up) and not ((shop.cards[2] as Button).get_node("StarUp") as Control).visible)
	var up_chip: Control = ((shop.cards[1] as Button).find_child("Traits", true, false) as Control).get_child(0)
	check("boutique : Assassin fait monter Ombre (2 → 3, seuil) : flèche sur la tuile", (shop.info[1].rising as Array).has("ombre")
		and (up_chip.find_child("Up", true, false) as Control).visible)
	check("boutique : Tranchant (2 → 3, pas un seuil) : pas de flèche", not (shop.info[1].rising as Array).has("tranchant"))
	check("boutique : Voleur déjà sur le plateau : son trait ne monte pas", (shop.info[0].rising as Array).is_empty())
	var chip_text := ((up_chip.find_child("Text", true, false)) as Label).text
	check("tuile de trait : nom du trait (%s)" % chip_text, chip_text == "Ombre")

	# --- traits toujours visibles ; fiche d'unité en bulle -------------------------------------------------------------
	screen.cursor._set_slot(AutochessBoard.board_slot(1, 1), "keys")
	await _frames(3)
	var card := screen.hud.unit_card
	var tr := screen.hud.traits
	check("fiche d'unité visible, traits toujours visibles", card.visible and tr.visible and card.shown_key().begins_with("u:thief"))
	var cr := card.get_global_rect()
	var vs := get_viewport().get_visible_rect().size
	check("bulle dans l'écran", Rect2(Vector2.ZERO, vs).encloses(cr))
	check("bulle : ne cache ni les traits ni les stratèges", not cr.intersects(tr.get_global_rect()) and not cr.intersects(screen.hud.players.get_global_rect()))
	var cell := screen.cursor.control_of(AutochessBoard.board_slot(1, 1)).get_global_rect()
	check("bulle : ne cache pas la case visée", not cr.grow(-2.0).intersects(cell))
	screen.cursor._set_slot(AutochessBoard.bench_slot(8), "keys")
	await _frames(2)

	# --- survol d'un trait : unités et cartes marquées ----------------------------------------------------------------
	var want := 0
	for u in g.units_of(0):
		if Autochess.unit_traits(u).has("ombre"):
			want += 1
	tr.hovered = "ombre"
	await _frames(2)
	check("survol d'Ombre : %d unités marquées (plateau et banc)" % want, screen.board.marked_count() == want and want == 3)
	check("survol d'Ombre : cartes Voleur et Assassin marquées", shop.marked_cards() == [0, 1])
	check("survol d'Ombre : la ligne du trait est mise en avant", tr.marked == "ombre")
	tr.hovered = ""
	await _frames(2)
	check("fin du survol : plus rien de marqué", screen.board.marked_count() == 0 and shop.marked_cards().is_empty() and tr.marked == "")

	# --- survol d'une carte : copies possédées marquées, traits qui monteraient --------------------------------------
	shop.hovered = 3
	await _frames(2)
	check("survol du Clerc : ses 4 copies marquées", screen.board.marked_count() == 4)
	var rows_rising := 0
	for t in tr.rows:
		if ((tr.rows[t] as Control).find_child("Rising", true, false) as Control).visible:
			rows_rising += 1
	var ghost_n: int = tr._ghosts.get_child_count()
	check("survol du Clerc : Ferveur et Chœur apparaissent en « 0 → 1 » (%d lignes fantômes)" % ghost_n, ghost_n == 2 and rows_rising == 0)
	shop.hovered = 1
	await _frames(2)
	var orow: Control = tr.rows.get("ombre")
	var rising: Label = orow.find_child("Rising", true, false) if orow != null else null
	check("survol de l'Assassin : « 2 → 3 » sur Ombre", rising != null and rising.visible and rising.text == "2 → 3")
	shop.hovered = -1
	await _frames(2)
	check("fin du survol : aperçu retiré", rising != null and not rising.visible and tr._ghosts.get_child_count() == 0)

	# --- manette : cadre sur un trait, puis sur une carte -------------------------------------------------------------
	Gamepad.active = true
	await _frames(2)
	UiNav.focus(tr.rows["ombre"])
	await _frames(2)
	check("manette : cadre sur Ombre → %d unités marquées" % want, screen.board.marked_count() == want and shop.marked_cards() == [0, 1])
	UiNav.focus(shop.cards[1])
	await _frames(2)
	check("manette : cadre sur l'Assassin → « 2 → 3 » sur Ombre, fiche en bulle", rising.visible and card.visible
		and not card.get_global_rect().intersects(tr.get_global_rect()))
	check("manette : bulle au-dessus de la carte visée", card.get_global_rect().end.y <= (shop.cards[1] as Control).get_global_rect().position.y + 1.0)
	Gamepad.active = false
	UiNav.cursor = null
	await _frames(2)

	# --- aides d'économie -----------------------------------------------------------------------------------------------
	var hud := screen.hud
	check("barre des taux : chiffres en infobulle (niveau 8)", hud.odds.level == 8 and hud.odds.tooltip_text.contains("%")
		and hud.odds.tooltip_text.contains("coût 5"))
	p.streak = 3
	p.gold = 34
	screen._sync()
	await _frames(2)
	check("flamme de série : 3 victoires, +1 or en infobulle", hud.streak.visible and hud.streak.tooltip_text.contains("+1 or"))
	var st := g.stage
	var rd := g.round_i + 1
	if rd > AutochessData.rounds_in(st):
		st += 1
		rd = 1
	var inc := g.income_for(0, st, rd)
	check("revenu de la prochaine manche : %s (%d)" % [hud.income_chip.text, int(inc.total)], hud.income_chip.text == "+%d" % int(inc.total)
		and hud.income_chip.tooltip_text.contains("Prochaine manche"))
	p.streak = -1
	screen._sync()
	await _frames(1)
	check("pas de série : flamme cachée", not hud.streak.visible)
	var texts: Array = []
	_permanent_texts(hud, texts)
	var pct: Array = texts.filter(func(t): return String(t).contains("%"))
	check("aucun « % » dans le texte permanent du cadre" + ("" if pct.is_empty() else " : " + str(pct)), pct.is_empty())

	# --- place du plateau ------------------------------------------------------------------------------------------------
	for res in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		if res.x == 1280:
			await _open(res)
		screen.cursor._set_slot(AutochessBoard.bench_slot(8), "keys")
		await _frames(4)
		var cov := _coverage()
		check("%d × %d : cadre au repos sur %d %% de l'écran (≤ %d %%)" % [res.x, res.y, roundi(cov * 100.0), 30 if res.x == 1600 else 33],
			cov <= (0.30 if res.x == 1600 else 0.33))
		var fits: bool = AutochessScreen._fits(screen.camera, screen.board_points(), screen.hud.frame_rects(), get_viewport().get_visible_rect().size)
		var bb: Rect2 = AutochessScreen._proj_box(screen.camera, screen.board_points())
		var v2 := get_viewport().get_visible_rect().size
		check("%d × %d : plateau, banc et objets hors des panneaux (cadre du plateau : %d %% × %d %% de l'écran)" % [res.x, res.y,
			roundi(bb.size.x / v2.x * 100.0), roundi(bb.size.y / v2.y * 100.0)], fits)
		var bad := _overflow()
		check("%d × %d : aucun contrôle du cadre hors de l'écran" % [res.x, res.y] + ("" if bad.is_empty() else " : " + str(bad)), bad.is_empty())

	AutochessScreen.config = {}
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
