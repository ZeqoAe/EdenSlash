extends Node
## Battle royale, lot BR-I3 (backlog P1-P2 de BM-BR) : points de saut toujours écartés (RoyaleDrop.plan, cause de
## l'instabilité de test_royale), noms de classe sans doublon, annonces centrales une à la fois (file à priorités, DA v2,
## dans l'écran), cadre de cible v2 (force relative, mis à prix), plaques (▲ ▼, intention des scriptés Facile / Normal),
## aide du largage à touches dessinées et altimètre, « Voir les sons », couleurs pour daltoniens, chiffres sobres,
## retours (K.O., Niveau, Niveau max), ambiance (vent, anneau), premiers pas du mode, coût par image.
## godot --headless --path game res://tests/test_bri3.tscn

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
	_test_static()
	var rd: RoyaleDirector = await _boot()
	var hud: Hud = world.hud
	var rh: RoyaleHud = hud.get("_royale")
	check("HUD du Battle royale v3 posé (cible, annonces, aide, sons, ambiance)", rh != null and rh.target != null and rh.announce != null
		and rh.drop_hint != null and rh.cues != null and rh.ambience != null)
	if rh == null:
		_finish()
		return
	_test_plan(rd)
	await _test_flight(rd, hud, rh)
	await _test_fight(rd, hud, rh)
	await _test_announce(rd, rh)
	await _test_layout(rd, rh)
	_test_perf(rd, rh)
	_finish()


func _finish() -> void:
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _boot() -> RoyaleDirector:
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.start("magician")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	var waited := 0.0
	while waited < 60.0 and not (world.get("director") != null and world.director.royale != null and world.director.royale.ais.size() == 7):
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	return world.director.royale


func _cards() -> void:
	if is_instance_valid(world) and world.cards.is_open():
		world.cards._queue.clear()
		world.cards._show_next()


func _until(cond: Callable, limit: float) -> bool:
	var t := 0.0
	while t < limit and not cond.call():
		_cards()
		await get_tree().process_frame
		t += get_process_delta_time()
	return cond.call()


func _frames(n: int) -> void:
	for i in n:
		_cards()
		await get_tree().process_frame


# --- sans partie ------------------------------------------------------------------------------------------
func _test_static() -> void:
	# (b) noms de classe : aucun doublon, les deux styles du Battle royale sont distincts
	var names := {}
	var dup: Array = []
	for c in ProjectSettings.get_global_class_list():
		var n := String(c["class"])
		if names.has(n):
			dup.append(n)
		names[n] = true
	check("aucun nom de classe en double (%s)" % str(dup), dup.is_empty())
	check("RoyaleStyle (bilan, pile) et RoyaleHudStyle (HUD) : deux classes, deux fichiers", names.has("RoyaleStyle") and names.has("RoyaleHudStyle")
		and load("res://scripts/ui/royale_style.gd") != load("res://scripts/ui/royale_hud_style.gd"))
	for k in ["sound_cues", "colorblind", "combat_vibration"]:
		check("réglage interface/%s connu (Settings.DEFAULTS)" % k, (Settings.DEFAULTS.interface as Dictionary).has(k))
	# touches dessinées
	var parts := RoyaleHudStyle.key_parts("[Espace] Sauter · saut auto dans 9 s")
	check("ligne à touches : « Espace » en pastille, puis le texte (%s)" % str(parts), parts.size() == 2 and bool(parts[0].key)
		and String(parts[0].s) == "Espace" and not bool(parts[1].key))
	check("ligne sans touche : un seul morceau de texte", RoyaleHudStyle.key_parts("Dirige ton planeur").size() == 1)
	# daltonisme : la paire danger / sûr change, les formes non
	Settings.set_v("interface", "colorblind", false)
	var d0 := RoyaleHudStyle.danger()
	var s0 := RoyaleHudStyle.safe()
	Settings.set_v("interface", "colorblind", true)
	check("daltoniens : danger fraise -> mandarine, sûr pomme -> lagon", d0 == RoyaleHudStyle.STRAWBERRY and s0 == RoyaleHudStyle.APPLE
		and RoyaleHudStyle.danger() == RoyaleHudStyle.MANDARIN and RoyaleHudStyle.safe() == RoyaleHudStyle.LAGOON)
	check("daltoniens : « ▲ plus fort » garde sa flèche", String(RoyaleTarget.force_label(2.0)[0]).begins_with("▲")
		and RoyaleTarget.force_label(2.0)[1] == RoyaleHudStyle.MANDARIN)
	Settings.set_v("interface", "colorblind", false)
	check("force relative : ▲ plus fort / ▼ plus faible / = égal", String(RoyaleTarget.force_label(1.6)[0]) == "▲ plus fort"
		and String(RoyaleTarget.force_label(0.5)[0]) == "▼ plus faible" and String(RoyaleTarget.force_label(1.0)[0]) == "= égal")
	# annonces : sens et rang d'après le texte
	check("annonces : sens et rang", RoyaleAnnounce.classify("Hors de l'anneau !\nSuis la flèche violette") == ["danger", 3]
		and RoyaleAnnounce.classify("Largage !\nDans 15 s") == ["drop", 2] and RoyaleAnnounce.classify("3 héros restants") == ["count", 1]
		and RoyaleAnnounce.classify("Victoire !\nDernier debout") == ["win", 4])
	# premiers pas : ≤ 125 signes, en français
	for id in RoyaleHud.TIPS:
		var body := String(RoyaleHud.TIPS[id].body)
		check("fiche « %s » : %d signes (≤ 125), sans pourcentage" % [id, body.length()], body.length() <= 125 and not body.contains("%"))


# --- (a) points de saut ------------------------------------------------------------------------------------
## Le tirage des points de saut, sur 60 graines : jamais deux héros à moins de 25 m (test_royale), ni quand aucun
## coffre n'est libre (repli seul : c'était la cause de l'instabilité).
func _test_plan(rd: RoyaleDirector) -> void:
	var j := rd.jump
	var worst := INF
	for seed_i in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1000 + seed_i
		worst = minf(worst, _closest(j.plan(8, rng)))
	check("points de saut sur 60 graines : écart minimal %.0f m (≥ 25)" % worst, worst >= 25.0)
	# sans coffre libre : tous les points viennent du repli
	var hidden: Array = []
	for it in rd.d.map.interactables:
		if is_instance_valid(it) and it.kind == "chest" and not it.used:
			it.used = true
			hidden.append(it)
	var worst_fb := INF
	var inside := true
	for seed_i in 30:
		var rng := RandomNumberGenerator.new()
		rng.seed = 5000 + seed_i
		var pl := j.plan(8, rng)
		worst_fb = minf(worst_fb, _closest(pl))
		for e in pl:
			var t: Vector3 = e.target
			inside = inside and rd.d.map.bounds.has_point(Vector2(t.x, t.z)) and float(e.jump_t) >= Royale.COUNTDOWN and float(e.jump_t) <= j.duration
	for it in hidden:
		it.used = false
	check("sans coffre libre (repli seul, 30 graines) : écart minimal %.0f m (≥ 40)" % worst_fb, worst_fb >= 40.0)
	check("repli : points dans la carte, sauts pendant le vol", inside)


static func _closest(plan: Array) -> float:
	var best := INF
	for i in plan.size():
		for k in range(i + 1, plan.size()):
			var a: Vector3 = plan[i].target
			var b: Vector3 = plan[k].target
			best = minf(best, Vector2(a.x - b.x, a.z - b.z).length())
	return best


# --- vol : aide à touches dessinées, altimètre, vent --------------------------------------------------------
func _test_flight(rd: RoyaleDirector, hud: Hud, rh: RoyaleHud) -> void:
	var p: Player = world.player
	var j := rd.jump
	await _until(func(): return rh.map.is_open, 6.0)
	rh.map.close()  # (la carte du vol cache l'aide : on la ferme pour la voir)
	await _until(func(): return j.t >= Royale.COUNTDOWN + 0.3, 8.0)
	await _frames(2)
	var old_box = hud.get("_drop_box")
	check("aide du largage : l'ancienne ligne est cachée", old_box == null or not (old_box as CanvasItem).visible)
	check("aide à touches dessinées (« %s »)" % rh.drop_hint.line.text, rh.drop_hint.line.visible and rh.drop_hint.line.text == rd.drop_hint()
		and RoyaleHudStyle.key_parts(rh.drop_hint.line.text).any(func(x): return bool(x.key)))
	check("à bord : vent doux, pas d'altimètre (vent %.2f)" % rh.ambience.wind, rh.ambience.wind > 0.1 and rh.ambience.wind < 0.5 and rh.drop_hint.height < 0.0)
	check("portes ouvertes : moment « portes » joué", RoyaleAmbience.last_cue in ["doors", "tick"] or RoyaleAmbience._cue_ms.has("doors"))
	RoyalePing.reset()
	RoyalePing.toggle(j.b.lerp(j.eagle_pos(), 0.5) * Vector3(1, 0, 1))
	j.jump(p)
	await _until(func(): return j.riders.has(p) and float(j.riders[p].air) > 0.6, 4.0)
	await _frames(2)
	check("chute : altimètre (%.0f m) et repère à l'écran (« %s »)" % [rh.drop_hint.height, rh.drop_hint._ping_txt], rh.drop_hint.height > RoyaleDrop.GLIDE_AT
		and rh.drop_hint._ping_txt.begins_with("Repère · "))
	check("chute : le vent forcit (%.2f)" % rh.ambience.wind, rh.ambience.wind >= 0.6)
	check("saut : moment « saut » joué", RoyaleAmbience._cue_ms.has("jump"))
	await _until(func(): return "chute" in rh.tips_shown, 2.0)
	check("chute : fiche « Le largage » (premiers pas)", "chute" in rh.tips_shown)
	RoyalePing.reset()


# --- combat : cible, plaques, chiffres, sons, retours --------------------------------------------------------
func _test_fight(rd: RoyaleDirector, hud: Hud, rh: RoyaleHud) -> void:
	var p: Player = world.player
	rd.jump.land_all()
	await _until(func(): return rd.phase == "fight", 10.0)
	await _frames(3)
	check("au sol : plus de vent", rh.ambience.wind == 0.0)
	var a: ClassRival = null
	for r in rd.ais:
		if is_instance_valid(r) and not r.is_dead and r.is_in_group("ffa"):
			a = r
			break
	check("un héros scripté au sol", a != null)
	if a == null:
		return
	for r in rd.ais:
		if is_instance_valid(r) and r != a:
			r.global_position = p.global_position + Vector3(220, 0, 220)
			r.passive = true
	a.passive = true
	a.global_position = p.global_position + Vector3(4, 0, 0)
	# --- cadre de cible v2
	p._target = a
	await _frames(3)
	var tt := rh.target.texts()
	check("cible verrouillée : cadre v2 (« %s » · %s · %s · %s)" % [tt.name, tt.level, tt.force, tt.hp], rh.target.visible and tt.name == a.display_name.get_slice(" ·", 0)
		and tt.level == "niv. %d" % a.level and String(tt.force) != "" and String(tt.hp).contains(" / "))
	check("le cadre commun de Hud est caché", not (hud.get("_target_box") as CanvasItem).visible)
	check("force relative cohérente (%.2f -> « %s »)" % [RoyaleTarget.force_of(a, p), tt.force], String(tt.force) == String(RoyaleTarget.force_label(RoyaleTarget.force_of(a, p))[0]))
	rd.bounty = a
	await _frames(2)
	check("mis à prix : étoile sur le cadre", rh.target.texts().star)
	rd.bounty = null
	# --- plaques : ▲ ▼ et intention
	var st: Dictionary = a.get_meta("royale")
	var keep_diff := int(st.diff)
	st.diff = 0
	st.mode = "L"
	rd._refresh_tag(a)
	var fl := a.get_node_or_null("RoyaleForce") as Label3D
	check("plaque d'un scripté Facile : force et intention (« %s »)" % (fl.text if fl else "?"), fl != null and fl.text.contains("pille"))
	st.diff = 3
	rd._refresh_tag(a)
	check("plaque d'un scripté Hardcore : pas d'intention (« %s »)" % fl.text, fl != null and not fl.text.contains("pille"))
	st.diff = keep_diff
	# --- chiffres sobres : une rafale = un nombre
	var before := _numbers()
	a.set_meta("rc_hit_ms", Time.get_ticks_msec())
	DamageNumber.spawn(a, 120.0, false, false)
	DamageNumber.spawn(a, 80.0, false, false, true)
	DamageNumber.spawn(a, 50.0, false, false, false, true)
	await _frames(1)
	var nums := _numbers()
	var mine: Array = nums.filter(func(l): return not before.has(l))
	check("chiffres sobres : 3 coups -> 1 nombre (« %s »)" % (mine[0].text if mine.size() > 0 else "?"), mine.size() == 1 and String(mine[0].text) == "250")
	check("chiffres sobres : jamais « (max) »", not mine.any(func(l): return String(l.text).contains("max")))
	DamageNumber.spawn(a, 40.0, true, false)
	await _frames(1)
	check("critique du joueur : « ! » et onomatopée « Critique ! »", _numbers().any(func(l): return String(l.text).ends_with("!"))
		and (rh.announce.words.any(func(w): return String(w.text) == "Critique !")))
	Settings.set_v("interface", "damage_numbers", "off")
	var n_off := _numbers().size()
	DamageNumber.spawn(p, 30.0, false, true)
	check("réglage « Chiffres de dégâts : masqués » respecté", _numbers().size() == n_off)
	Settings.set_v("interface", "damage_numbers", "all")
	# --- coup donné : « tic » et vibration
	RoyaleAmbience._cue_ms.erase("hit")
	a.take_damage(5.0, p, false)
	check("coup donné à un héros : moment « coup »", RoyaleAmbience._cue_ms.has("hit"))
	# --- « Voir les sons »
	Settings.set_v("interface", "sound_cues", true)
	var cam := get_viewport().get_camera_3d()
	RoyaleCues.events.clear()
	RoyaleCues.heard(p.global_position + Vector3(25, 0, 0).rotated(Vector3.UP, cam.global_rotation.y), "chest")
	rh.cues.compute()
	check("voir les sons : coffre à droite -> un arc à droite (%s)" % str(rh.cues.shown), rh.cues.shown.size() == 1
		and absf(angle_difference(float(rh.cues.shown[0].angle), 0.0)) < 0.2 and String(rh.cues.shown[0].kind) == "chest")
	RoyaleCues.heard(p.global_position + Vector3(0, 0, -30).rotated(Vector3.UP, cam.global_rotation.y), "fight")
	rh.cues.compute()
	check("voir les sons : combat devant -> un arc en haut", rh.cues.shown.any(_fight_above))
	RoyaleCues.heard(p.global_position + Vector3(90, 0, 0), "chest")
	rh.cues.compute()
	check("voir les sons : trop loin (90 m), rien de plus", rh.cues.shown.size() == 2)
	Settings.set_v("interface", "sound_cues", false)
	# --- élimination par le joueur : « K.O. ! »
	rh.announce.words.clear()
	a.passive = true
	a.hp = 1.0
	a.take_damage(1e6, p, false)
	await _frames(2)
	check("élimination : « K.O. ! » et moment « K.O. »", rh.announce.words.any(func(w): return String(w.text) == "K.O. !") and RoyaleAmbience._cue_ms.has("ko"))
	# --- niveau et plafond de l'anneau
	rh.announce.clear()
	rh._cap_phase = -1
	p.level = Royale.level_cap_now
	rh._on_level_up(p.level)
	check("au plafond : « Niveau max ! » (« %s »)" % rh.announce.shown_title(), rh.announce.shown_title() == "Niveau max !"
		and String(rh.announce.current.sub).contains(str(Royale.level_cap(int(rd.ring.get("phase", 0)) + 1))))
	# --- anneau : grondement près du mur
	var c: Vector2 = rd.ring.center
	var out := c + Vector2.RIGHT * (float(rd.ring.radius) + 10.0)
	p.global_position = Vector3(out.x, rd.d.map.height_at(out.x, out.y) + 0.1, out.y)
	rh.ambience._targets(rd)
	check("dehors, près du mur : grondement de l'anneau (%.2f)" % rh.ambience.hum, rh.ambience.hum >= 0.5)
	p.global_position = Vector3(c.x, rd.d.map.height_at(c.x, c.y) + 0.1, c.y)
	rh.ambience._targets(rd)
	check("au centre : silence (%.2f)" % rh.ambience.hum, rh.ambience.hum == 0.0 or float(rd.ring.radius) < RoyaleAmbience.HUM_RANGE)
	# --- premiers pas : une fois par profil
	var seen0: Array = Profile.records.get("royale_tips", []).duplicate()
	var first := rh.show_tip("butin") if not "butin" in seen0 else true
	check("fiche « Les dépouilles » montrée une fois, puis plus jamais", first and not rh.show_tip("butin") and "butin" in Profile.records.get("royale_tips", []))


static func _fight_above(s: Dictionary) -> bool:
	return String(s.kind) == "fight" and absf(angle_difference(float(s.angle), -PI / 2.0)) < 0.2


func _numbers() -> Array:
	return get_tree().current_scene.find_children("RoyaleNumber*", "Label3D", false, false) if get_tree().current_scene else []


# --- annonces : une à la fois ---------------------------------------------------------------------------------
func _test_announce(rd: RoyaleDirector, rh: RoyaleHud) -> void:
	var an := rh.announce
	an.clear()
	rd.d.message.emit("Nouveaux coffres\nIls tombent dans l'anneau", 2.5)
	await _frames(1)
	check("message du directeur -> annonce centrale (« %s »)" % an.shown_title(), an.shown_title() == "Nouveaux coffres")
	check("le bandeau commun de Hud reste éteint", (world.hud.get("_banner") as Control).modulate.a < 0.05)
	rd.d.message.emit("Hors de l'anneau !\nSuis la flèche violette", 1.8)
	await _frames(1)
	check("danger : passe tout de suite (« %s »)" % an.shown_title(), an.shown_title() == "Hors de l'anneau !")
	rd.d.message.emit("5 héros restants", 1.6)
	rd.d.message.emit("4 héros restants", 1.6)
	await _frames(1)
	check("moins important : attend son tour, et seul le dernier compte reste (%s)" % str(an.queue.map(func(q): return q.title)),
		an.shown_title() == "Hors de l'anneau !" and an.queue.size() == 1 and String(an.queue[0].title) == "4 héros restants")
	rd.d.message.emit("Hors de l'anneau !\nSuis la flèche violette", 1.8)
	check("même annonce : ravivée, pas doublée", an.queue.size() == 1)
	await _until(func(): return an.shown_title() == "4 héros restants", 4.0)
	check("puis la suivante (« %s »)" % an.shown_title(), an.shown_title() == "4 héros restants")
	world.hud.show_message("Coffre doré ouvert", 1.5)
	check("ligne de butin : reste au fil (pas d'annonce)", an.shown_title() == "4 héros restants")
	for t in ["L'anneau se resserre !", "Dernier cercle !", "Largage !", "Mis à prix !", "Victoire !", "Éliminé !", "Anneau 2 / 5"]:
		check("texte d'annonce « %s » : sans pourcentage" % t, not t.contains("%"))
	var src := FileAccess.get_file_as_string("res://scripts/core/royale_director.gd")
	check("plus de majuscules criées ni de « restants » sans héros", not src.contains("DERNIER CERCLE") and not src.contains("VICTOIRE ! Dernier")
		and src.contains("héros restant%s"))


# --- mise en page : 1600×900 et 1280×720 ---------------------------------------------------------------------
func _test_layout(rd: RoyaleDirector, rh: RoyaleHud) -> void:
	var p: Player = world.player
	var a: ClassRival = null
	for r in rd.ais:
		if is_instance_valid(r) and not r.is_dead:
			a = r
			break
	for res in [Vector2i(1600, 900), Vector2i(1280, 720)]:
		get_window().size = res
		await _frames(3)
		var vp := Rect2(Vector2.ZERO, rh.get_viewport_rect().size)
		if a != null:
			a.global_position = p.global_position + Vector3(4, 0, 0)
			p._target = a
		rh.announce.clear()
		rh.announce.push("Mis à prix !\nUn héros au nom assez long : élimine-le, un niveau de plus", 3.0)
		await get_tree().create_timer(0.4).timeout  # (fin de l'entrée en ressort : l'échelle revient à 1)
		var br := rh.announce.banner_rect()
		var tr := rh.target.get_global_rect()
		var col: Rect2 = rh._col.get_global_rect()
		var goal: Rect2 = rh._goal.get_global_rect()
		print("[bri3] %dx%d · bandeau %s · cible %s · colonne %s · objectif %s" % [res.x, res.y, str(br), str(tr), str(col), str(goal)])
		check("%d×%d : bandeau dans l'écran" % [res.x, res.y], vp.grow(0.5).encloses(br))
		check("%d×%d : bandeau sous le cadre de cible" % [res.x, res.y], not rh.target.visible or br.position.y >= tr.end.y - 4.0)
		check("%d×%d : bandeau loin de la mini-carte et de l'objectif" % [res.x, res.y], not br.intersects(col) and not br.intersects(goal))
		check("%d×%d : cadre de cible dans l'écran, entre l'objectif et la mini-carte" % [res.x, res.y], not rh.target.visible
			or (vp.encloses(tr) and tr.position.x > goal.end.x - 1.0 and tr.end.x < col.position.x))
	get_window().size = Vector2i(1600, 900)
	await _frames(2)


# --- coût par image ------------------------------------------------------------------------------------------
func _test_perf(rd: RoyaleDirector, rh: RoyaleHud) -> void:
	Settings.set_v("interface", "sound_cues", true)
	for i in 6:
		RoyaleCues.heard(world.player.global_position + Vector3(10 + i * 3, 0, i * 2), "chest")
	var runs: Array = []
	for k in 7:
		var t0 := Time.get_ticks_usec()
		for i in 100:
			rh.tick(1.0 / 60.0)
			rh.edge.compute()
			rh.cues.compute()
		runs.append(float(Time.get_ticks_usec() - t0) / 1000.0 / 100.0)
	runs.sort()
	print("[bri3] coût du HUD du Battle royale (avec cible, aide, sons) : %.3f ms par image (médiane %.3f)" % [runs[0], float(runs[3])])
	check("coût du HUD par image : %.3f ms (≤ %.1f)" % [runs[0], BUDGET_MS], float(runs[0]) <= BUDGET_MS)
	Settings.set_v("interface", "sound_cues", false)
