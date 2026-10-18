extends Node
## Lot MB-H (Les Deux Voies, conception/benchmark/R_MB_H.md) : HUD et écrans en partie.
## 1. Règles pures : sorte et rang des messages (classify), raison de la fin (MobaResults.reason_text), repères (MobaPings).
## 2. Partie réelle (world.tscn, toi + 7 IA, horloge à 2:50) : HUD posé (plus de ligne d'état de test), tableau (temps, tours),
##    minuteurs (Gardien, Colosse, Marée), 3 alliés, mini-carte (10 structures, brouillard : un adversaire loin n'y est pas, près
##    d'un allié il y est), niveau de partie sur la barre, choix de niveau (bandeau, cases, Ctrl + 1, plots), annonces (une à la
##    fois, priorités, messages du directeur repris), fil (élimination, premier sang, tour), boutique (onglets, cartes, achat
##    conseillé, annuler, vente au maintien, fermée loin de la base, aucun pourcentage), boutique à la manette (la partie attend,
##    tout est atteignable, LB / RB), tableau des scores (Tab tenu), repère (sur un adversaire : « Attaquez ! »), mort (carte,
##    qui t'a battu, barre cachée, réapparition), mise en page 1280 × 720 et 1600 × 900 (dans l'écran, sans se croiser), coût du
##    HUD par image (≤ 0,3 ms), bilan (raison de la décision, tableau des 8 héros).
## godot --headless --path game res://tests/test_mb_hud.tscn

const BUDGET_MS := 0.3

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	get_window().size = Vector2i(1600, 900)
	_pure()
	await _world()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().paused = false
	get_tree().quit(fails)


func _pure() -> void:
	check("message « Niveau 4 ! » : repris par le bandeau de choix", String(MobaHud.classify("Niveau 4 !")[0]) == "level")
	check("tour adverse détruite : moment fort soleil ; la nôtre : danger fraise",
		MobaHud.classify("Tour rouge T1 détruite !") == ["tower_won", 3, "soleil"] and MobaHud.classify("Tour bleue T2 tombe !") == ["tower_lost", 3, "fraise"])
	check("objectif annoncé : rang 2 ; pris par l'adversaire : danger", int(MobaHud.classify("Gardien arrive dans 45 s")[1]) == 2
		and String(MobaHud.classify("L'équipe adverse prend le Colosse !")[0]) == "objective_lost")
	check("mort et rappel : jamais en bulle de danger", String(MobaHud.classify("Tu es tombé : retour dans 9 s")[0]) == "death"
		and int(MobaHud.classify("Retour à la fontaine…")[1]) == 0)
	Moba.reset()
	Moba.structures_down = [5, 3]
	Moba.objectives_taken = [2, 1]
	check("raison : Cœur détruit / fin au temps aux structures (5 contre 3) / aux objectifs",
		MobaResults.reason_text("core", "", true, 0) == "Le Cœur adverse est détruit"
		and MobaResults.reason_text("time", "structures", true, 0).contains("5 contre 3")
		and MobaResults.reason_text("time", "objectifs", false, 1).contains("1 contre 2") and MobaResults.reason_text("abandon", "", false, 0) != "")
	Moba.reset()
	MobaPings.reset()
	MobaPings.add("attack", Vector3(1, 0, 1))
	MobaPings.add("attack", Vector3(2, 0, 1))
	MobaPings.add("help", Vector3(30, 0, 1))
	check("repères : le même au même endroit remplace le premier ; sorte inconnue = « Ici »", MobaPings.recent().size() == 2
		and String(MobaPings.add("?", Vector3.ZERO).kind) == "here")
	MobaPings.reset()


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _key(code: Key, ctrl := false) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.ctrl_pressed = ctrl
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


## Part du premier candidat et explore en déplaçant le curseur ; renvoie [atteints, total] (comme test_nav_screens).
func _reach() -> Array:
	var all: Array = UiNav.candidates()
	if all.is_empty():
		return [0, 0]
	UiNav.cursor = null
	UiNav._last_center = Vector2.ZERO
	UiNav.pick_default()
	var seen := {UiNav.cursor: true}
	var todo: Array = [UiNav.cursor]
	while not todo.is_empty():
		var c: Control = todo.pop_back()
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			UiNav.cursor = c
			if UiNav.move(d) and not seen.has(UiNav.cursor):
				seen[UiNav.cursor] = true
				todo.append(UiNav.cursor)
	return [seen.size(), all.size()]


static func _rect(c: Control) -> Rect2:
	return Rect2(c.global_position, c.size * c.scale)


## Toutes les étiquettes visibles sous [param n] (textes de la boutique) : aucun « % ».
static func _texts(n: Node, out: Array) -> void:
	if n is Label and (n as Label).is_visible_in_tree():
		out.append((n as Label).text)
	elif n is Button and (n as Button).is_visible_in_tree():
		out.append((n as Button).text)
	for c in n.get_children():
		_texts(c, out)


func _world() -> void:
	seed(91)
	Profile.selected_class = "magician"
	Moba.launch("magician", {"heroes": "all", "diff": 1, "seed": 91, "clock": 170.0})
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 900)
	var dd: MobaDirector = world.director.team as MobaDirector
	check("directeur des Deux Voies monté", dd != null)
	if dd == null:
		Moba.finish()
		return
	await _until(func(): return dd.map != null and dd.map.nav_ready(), 900)
	var hud: Hud = world.hud
	var mh: MobaHud = hud.get("_moba")
	check("HUD des Deux Voies posé par le HUD commun ; plus de ligne d'état de test", mh != null and MobaHud.current == mh and dd.get("_hud") == null)
	if mh == null:
		Moba.finish()
		return
	await _frames(4)
	await get_tree().create_timer(0.5).timeout
	var p: Player = dd.player
	var ps: MobaHero = dd.info[p]
	check("mini-carte ronde et objectifs de la Survie cachés", not (hud.get("_map_holder") as Control).visible and not (hud.get("_obj_panel") as Control).visible)
	check("tableau : temps de partie (après 2:50) et tours debout (%s)" % mh.band.text, (mh.band.text.contains(" · 2:5") or mh.band.text.contains(" · 3:"))
		and mh.band.text.contains("tours 4 – 4"))
	check("minuteurs : Gardien, Colosse, Marée (%s)" % ", ".join(mh.objs.pills), mh.objs.pills.size() >= 3 and String(mh.objs.pills[0]).begins_with("Gardien")
		and String(mh.objs.pills[1]).begins_with("Colosse") and mh.objs.pills.any(func(x): return String(x).begins_with("Marée")))
	check("3 alliés à gauche, chacun avec ce qu'il fait (%s)" % " | ".join(mh.allies.lines), mh.allies.lines.size() == 3
		and mh.allies.lines.all(func(x): return String(x).contains(" · ")))
	check("mini-carte : 10 structures, les alliés, toi", int(mh.minimap.drawn.get("towers", 0)) == 10 and int(mh.minimap.drawn.get("heroes", 0)) >= 4)
	check("brouillard : l'image de la vue de l'équipe existe", mh.minimap.fog_tex != null)
	var foe: MobaRival = null
	for h in dd.heroes:
		if h is MobaRival and (h as MobaRival).side == 1:
			foe = h
			break
	foe.passive = true
	foe.global_position = dd.map.moba.fountains[1] + Vector3(0, 0.5, 0)
	mh._update_seen(dd)
	check("un adversaire à sa fontaine n'est pas vu par l'équipe", not mh.is_seen(foe))
	foe.global_position = p.global_position + Vector3(6, 0, 0)
	mh._update_seen(dd)
	check("près de toi, il est vu (mini-carte, repères)", mh.is_seen(foe))
	# barre de niveau : le niveau de partie (1-12), jamais celui de la fiche
	var lb = hud.get("_xp_orb")
	await get_tree().create_timer(0.4).timeout
	check("barre de niveau : niveau de partie %d (fiche %d)" % [int(lb.level), p.level], int(lb.level) == ps.level and p.level >= 30)
	# choix de niveau non bloquant
	dd._xp(ps, float(MobaData.xp_total(2)) - ps.xp + 1.0)
	await _frames(4)
	await get_tree().create_timer(0.35).timeout
	check("niveau 2 : choix en attente, bandeau « Niveau 2 ! » et les touches (%s)" % mh.choice.text, not ps.pending.is_empty()
		and mh.choice.text.begins_with("Niveau 2 !") and mh.choice.text.contains("[Ctrl+1]"))
	check("les 3 cases s'éclairent ; l'ultime reste verrouillé « niv. 5 »", (mh.marks.slice(0, 3) as Array).all(func(m): return m.state == "choice")
		and mh.marks[3].state == "locked")
	check("le message « Niveau 2 ! » du directeur n'est pas une bulle", not mh.announce.log.has("Niveau 2 !"))
	_key(KEY_1, true)
	await _frames(4)
	await get_tree().create_timer(0.35).timeout  # (les pièces se redessinent 10 fois par seconde)
	check("Ctrl + 1 : la case 1 reçoit son enchaînement (plots %s)" % str(mh.marks[0].pips), int(ps.chains[0]) == 1 and ps.pending.is_empty()
		and mh.marks[0].pips == Vector2i(1, 2) and mh.choice.text == "")
	# annonces : une à la fois, la plus importante passe
	mh.announce.clear()
	mh.announce.push("Information", "", 1, "lagon", 2.0)
	await _frames(2)
	dd.d.message.emit("Tour rouge T1 détruite !", 2.5)
	await _frames(3)
	check("annonce : « Tour … détruite ! » passe devant une information (%s)" % mh.announce.shown_title(), mh.announce.shown_title() == "Tour rouge T1 détruite !")
	mh.announce.push("Petite chose", "", 0, "lagon", 2.0)
	check("une annonce moins importante attend (file : %s ; affichée : %s)" % [str(mh.announce.queue.map(func(q): return q.title)), mh.announce.shown_title()], mh.announce.queue.any(func(q): return String(q.title) == "Petite chose")
		and mh.announce.shown_title() == "Tour rouge T1 détruite !")
	# fil : élimination, premier sang, tour
	foe.passive = false
	foe.hp = 1.0
	foe.take_damage(foe.max_hp, p, false, true)
	await _frames(6)
	for _i in 60:
		if mh.announce.log.has("Premier sang !"):
			break
		await get_tree().create_timer(0.1).timeout
	check("élimination : au fil (%s) et « Premier sang ! » annoncé" % ", ".join(mh.column.shown), mh.column.shown.any(func(x): return String(x).begins_with("Toi ⚔"))
		and mh.announce.log.has("Premier sang !"))
	Moba.note("tower", 1, {"lane": 0, "tier": 1})
	await get_tree().create_timer(0.35).timeout
	check("tour adverse tombée : au fil", mh.column.shown.any(func(x): return String(x).contains("tour T1 tombée")))
	# boutique à la fontaine
	p.global_position = dd.map.moba.fountains[0] + Vector3(0, 0.5, 0)
	await _until(func(): return ps.in_shop, 30)
	ps.gold = 3000.0
	_key(KEY_P)
	await _frames(4)
	var st: MobaStore = mh.store
	check("[P] : la boutique s'ouvre (7 onglets, cartes du parcours conseillé), la partie continue", st != null and st.visible and st._tabs.size() == 7
		and st.cards.size() >= 4 and not get_tree().paused)
	var items0 := ps.items.size()
	var g0 := ps.gold
	check("« Conseillé » achète la prochaine étape du parcours", st.buy_next() and ps.items.size() == items0 + 1 and ps.gold < g0)
	check("annuler rend l'or", st.undo() and ps.items.size() == items0 and is_equal_approx(ps.gold, g0))
	st.buy_next()
	st.refresh(true)
	var n1 := ps.items.size()
	st._hold_start(0)
	await get_tree().create_timer(0.3).timeout
	var mid := ps.items.size() == n1
	await get_tree().create_timer(0.6).timeout
	check("maintenir une place 0,6 s : l'objet est vendu (pas avant)", mid and ps.items.size() == n1 - 1)
	for t in MobaData.TABS.size():
		st.set_tab(t)
		await _frames(2)
		var texts: Array = []
		_texts(st, texts)
		var pct: Array = texts.filter(func(x): return String(x).contains("%"))
		check("onglet %s : %d cartes, aucun pourcentage dans le texte" % [MobaData.TABS[t][1], st.cards.size()], st.cards.size() > 0 and pct.is_empty())
	st.selected = "baton_eclipse"
	st.refresh(true)
	check("fiche : la recette et ce que l'objet donne, en mots", st._detail.get_child_count() >= 6)
	p.global_position = dd.map.lane_point(0, 0, 40.0) + Vector3.UP * 0.5
	await _until(func(): return not ps.in_shop, 20)
	st.selected = "potion_soin"
	st.refresh(true)
	check("loin de la base : on regarde sans acheter (%s)" % st._btn_buy.text, st._btn_buy.disabled and st._btn_buy.text.contains("fontaine"))
	_key(KEY_P)
	await _frames(3)
	check("[P] la referme", not st.visible)
	# boutique à la manette : la partie attend, tout est atteignable
	p.global_position = dd.map.moba.fountains[0] + Vector3(0, 0.5, 0)
	await _until(func(): return ps.in_shop, 30)
	Gamepad.active = true
	mh.toggle_store(true)
	await _frames(3)
	check("à la manette : la partie attend pendant la boutique", get_tree().paused and st.paused_by_me)
	var r := _reach()
	check("boutique : %d / %d contrôles atteignables à la croix" % [r[0], r[1]], r[1] > 10 and float(r[0]) / float(r[1]) >= 0.9)
	var tab0 := st.tab
	UiNav.step_tab(1)
	await _frames(2)
	check("RB : onglet suivant", st.tab == wrapi(tab0 + 1, 0, MobaData.TABS.size()))
	st.close()
	await _frames(2)
	check("fermée : la partie reprend", not get_tree().paused)
	Gamepad.active = false
	# tableau des scores
	Input.action_press("objectives")
	await get_tree().create_timer(0.35).timeout
	check("[Tab] tenu : tableau des scores, 8 héros (%s)" % (mh.board.rows[0] if not mh.board.rows.is_empty() else ""), mh.board.visible and mh.board.rows.size() == 8)
	Input.action_release("objectives")
	await _frames(2)
	check("relâché : le tableau se range", not mh.board.visible)
	# repère sur un adversaire vu
	await _until(func(): return not foe.is_dead, 60 * 40)
	foe.passive = true
	foe.global_position = p.global_position + Vector3(8, 0, 0)
	mh._update_seen(dd)
	var e := mh.place_ping("", foe.global_position)
	check("repère sur un adversaire vu : « Attaquez ! » (pour le coach)", String(e.get("kind", "")) == "attack" and MobaPings.recent().size() >= 1
		and e.get("target") == foe)
	# mise en page
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().size = res
		await _frames(6)
		_layout_checks(mh, hud, res)
	get_window().size = Vector2i(1600, 900)
	await _frames(4)
	# coût du HUD par image (la meilleure de 7 séries de 100 images)
	var runs: Array = []
	for k in 7:
		var t0 := Time.get_ticks_usec()
		for i in 100:
			mh.tick(1.0 / 60.0)
		runs.append(float(Time.get_ticks_usec() - t0) / 1000.0 / 100.0)
	runs.sort()
	print("[mbh] coût du HUD des Deux Voies : %.3f ms par image (médiane %.3f)" % [float(runs[0]), float(runs[3])])
	check("coût du HUD par image : %.3f ms (≤ %.1f)" % [float(runs[0]), BUDGET_MS], float(runs[0]) <= BUDGET_MS)
	# mort : carte, qui t'a battu, barre cachée, puis réapparition
	foe.passive = false
	p.evasion_chance = 0.0
	p.parry_chance = 0.0
	p.take_damage(p.max_hp * 0.1, foe, false, true)
	p.hp = 1.0
	p.take_damage(p.max_hp, foe, false, true)
	await get_tree().create_timer(0.35).timeout
	check("mort : carte « Tombé ! » (%s), barre d'action cachée" % mh.death.text, p.is_dead and mh.death.visible and mh.death.text.begins_with("Tombé !")
		and not (hud.get("_action_root") as Control).visible)
	check("qui t'a battu : %s" % String(mh.recap.get("killer", "")), String(mh.recap.get("killer", "")) != "" and not (mh.recap.get("rows", []) as Array).is_empty())
	await _until(func(): return not p.is_dead, 60 * 30)
	await _frames(4)
	check("réapparition : la carte se range, la barre revient", not p.is_dead and not mh.death.visible and (hud.get("_action_root") as Control).visible)
	# bilan : raison de la décision et tableau des 8 héros
	Moba.decided_by = "structures"
	dd._finish(0, "time")
	await _frames(6)
	var res_panel: MobaResults = null
	for n in world.get_children():
		if n is MobaResults:
			res_panel = n
	check("bilan : la raison de la fin (%s)" % (res_panel.reason if res_panel != null else ""), res_panel != null and res_panel.reason.begins_with("Fin au temps"))
	check("bilan : tableau des 8 héros, le meilleur marqué", res_panel != null and res_panel.table != null and res_panel.table.get_child_count() == 9
		and res_panel.mvp_cid != "")
	get_tree().paused = false
	TeamMatch.end()
	Moba.reset()
	Engine.time_scale = 1.0
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false


func _layout_checks(mh: MobaHud, hud: Hud, res: Vector2i) -> void:
	var vp := Rect2(Vector2.ZERO, Vector2(res))
	var bar: Control = hud.get("_action_root")
	var bar_content := Rect2(bar.global_position + Vector2(30, 0), Vector2(800, 196))
	var parts := {"tableau": mh.band, "minuteurs": mh.objs, "mini-carte": mh.minimap, "alliés": mh.allies, "or": mh.gold_box, "choix": mh.choice}
	var all_in := true
	for k in parts:
		var r := _rect(parts[k] as Control)
		if not vp.encloses(r):
			all_in = false
			print("[débord] %s %s hors de %s" % [k, str(r), str(vp)])
	check("%d×%d : tableau, minuteurs, mini-carte, alliés, or, choix dans l'écran" % [res.x, res.y], all_in)
	var mm := _rect(mh.minimap)
	check("%d×%d : le tableau et ses minuteurs ne touchent pas la mini-carte" % [res.x, res.y], not _rect(mh.band).intersects(mm)
		and not _rect(mh.objs).intersects(mm))
	check("%d×%d : alliés et or loin de la barre d'action" % [res.x, res.y], not _rect(mh.allies).intersects(bar_content)
		and not _rect(mh.gold_box).intersects(bar_content))
	var left: Control = hud.get("_left")
	check("%d×%d : la pile de gauche (quête) ne croise ni les minuteurs ni les alliés" % [res.x, res.y],
		not _rect(left).intersects(_rect(mh.objs)) and not _rect(left).intersects(_rect(mh.allies)))
	check("%d×%d : tableau des scores et carte de mort dans l'écran" % [res.x, res.y], vp.encloses(_rect(mh.board)) and vp.encloses(_rect(mh.death)))
	mh.minimap.big = true
	mh._layout()
	check("%d×%d : grande carte dans l'écran, au-dessus de la barre d'action" % [res.x, res.y], vp.encloses(_rect(mh.minimap))
		and _rect(mh.minimap).end.y <= bar.global_position.y)
	mh.minimap.big = false
	mh._layout()
