extends Node
## Lot S4 du Survivant (conception/survivor) : déroulé de la run. Chronologie (gardiens à 5, 10 et 15 min, portail à
## 15:00, horde finale à 19:00, arène forcée à 20:00), courbe des monstres par minute, coffres du Survivant, butin des
## monstres (potions seulement), gardiens et boss à PV fixes (× palier × Menace, jamais d'après le héros), rage du boss à
## 4:00, fin de run (victoire, défaite, abandon) et hub intact. Le temps de la carte est avancé à la main (director.time).
## godot --headless --path game res://tests/test_sv4.tscn

const WORLD := "res://scenes/world.tscn"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	if name == "Sv4Driver":
		_run.call_deferred()
		return
	var d: Node = (load("res://tests/test_sv4.gd") as GDScript).new()
	d.name = "Sv4Driver"
	get_tree().root.add_child.call_deferred(d)


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout


func _until(cond: Callable, limit: float, label := "") -> bool:
	var t := 0.0
	while t < limit:
		if cond.call():
			return true
		await _wait(0.1)
		t += 0.1
	if label != "":
		print("   (délai dépassé : %s)" % label)
	return cond.call()


func _world() -> Node:
	var s := get_tree().current_scene
	if s != null and s.has_method("end_run") and s.get("director") != null and s.director.player != null and s.get("hud") != null:
		return s
	return null


func _results() -> Node:
	var s := get_tree().current_scene
	if s == null:
		return null
	for c in s.get_children():
		if c is ResultsPanel:
			return c
	return null


## Empreinte du hub (comme test_sv1) : équipement et progression du compte.
func _hub() -> String:
	var parts := ["loadout=" + _norm(Profile.loadout), "presets=" + _norm(Profile.presets), "vault=%d" % Profile.vault.size()]
	for k in Survivor.HUB_KEYS:
		parts.append("%s=%s" % [k, _norm(SurvivorRewards.hub_view(k, Profile.get(k)))])
	return "\n".join(parts)


func _norm(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)


func _run() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	Profile.in_run = false
	Profile.insignia = 77
	Profile.records["kills"] = 3
	Profile.save_profile()
	_unit()
	await _victory_run()
	await _defeat_run()
	await _early_run()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().unload_current_scene()  # (quitter avec le monde chargé faisait planter Godot à la sortie)
	await _wait(1.0)
	Profile.reset_all()
	get_tree().quit(1 if fails > 0 else 0)


# --- règles sans monde ------------------------------------------------------------------------------------------------
func _unit() -> void:
	var tl := SurvivorDirector.timeline()
	var at := func(id: String, n := -1) -> float:
		for e in tl:
			if e.id == id and (n < 0 or int(e.get("n", -1)) == n):
				return float(e.t)
		return -1.0
	check("chronologie : gardiens à 5:00, 10:00 et 15:00", at.call("guardian", 0) == 300.0 and at.call("guardian", 1) == 600.0 and at.call("guardian", 2) == 900.0)
	check("chronologie : chaque gardien annoncé 10 s avant", at.call("guardian_warn", 0) == 290.0 and at.call("guardian_warn", 2) == 890.0)
	check("chronologie : portail annoncé à 15:00, horde finale à 19:00, boss à 20:00", at.call("portal") >= 900.0 and at.call("portal") < 910.0
		and at.call("final_horde") == 1140.0 and at.call("boss") == 1200.0)
	var sorted := true
	for i in range(1, tl.size()):
		sorted = sorted and float(tl[i].t) >= float(tl[i - 1].t)
	check("chronologie triée, le boss en dernier", sorted and tl[-1].id == "boss")

	Survivor.start("warrior", "limestone")
	var p0 := SurvivorDirector.spawn_plan(0.0)
	var p10 := SurvivorDirector.spawn_plan(600.0)
	var p20 := SurvivorDirector.spawn_plan(1199.0)
	print("   courbe : 0:00 %s\n   10:00 %s\n   20:00 %s" % [p0, p10, p20])
	check("vivants : 18 au départ, 110 à 20:00", int(p0.alive_max) == 18 and int(p20.alive_max) == 110)
	check("PV des monstres ×0,5 au départ, ×1,55 à 10:00, ×4,8 à 20:00", is_equal_approx(float(p0.hp_mult), 0.5)
		and absf(float(p10.hp_mult) - 1.55) < 0.02 and absf(float(p20.hp_mult) - 4.8) < 0.1)
	check("dégâts des monstres ×0,5 → ×1,93", is_equal_approx(float(p0.atk_mult), 0.5) and absf(float(p20.atk_mult) - 1.93) < 0.03)
	check("meutes toutes les 6 s de 4 monstres, puis 1,8 s de 12", is_equal_approx(float(p0.pack_every), 6.0) and int(p0.pack_size) == 4
		and absf(float(p20.pack_every) - 1.8) < 0.05 and int(p20.pack_size) == 12)
	check("élites : aucune avant 8:00, toutes les 40 s, 20 s après 15:00", float(p0.elite_every) == 0.0 and float(SurvivorDirector.spawn_plan(479.0).elite_every) == 0.0
		and float(p10.elite_every) == 40.0 and float(SurvivorDirector.spawn_plan(901.0).elite_every) == 20.0)
	check("niveau des monstres : 1 + 1,8 par minute (37 à 20:00)", int(p0.level) == 1 and int(SurvivorDirector.spawn_plan(1200.0).level) == 37)
	check("au-delà de 20:00 (renforts de l'arène) : la courbe de 20:00", is_equal_approx(float(SurvivorDirector.spawn_plan(1500.0).hp_mult), float(SurvivorDirector.spawn_plan(1200.0).hp_mult)))
	check("horde finale : densité maximale à 19:00", SurvivorDirector.spawn_plan(1141.0).final and int(SurvivorDirector.spawn_plan(1141.0).alive_max) == 110)
	check("gardiens à PV fixes : 40 000 / 150 000 / 450 000", SurvivorDirector.guardian_hp(0) == 40000.0 and SurvivorDirector.guardian_hp(1) == 150000.0
		and SurvivorDirector.guardian_hp(2) == 450000.0)
	check("boss final à PV fixes : 1 500 000", SurvivorDirector.final_boss_hp() == 1500000.0)
	Run.hero_level = 40
	check("PV fixes indépendants du niveau du héros", SurvivorDirector.final_boss_hp() == 1500000.0 and SurvivorDirector.guardian_hp(1) == 150000.0)
	Survivor.palier = 2
	check("palier II : gardiens et boss ×1,5, monstres aussi", SurvivorDirector.final_boss_hp() == 2250000.0 and SurvivorDirector.guardian_hp(0) == 60000.0
		and is_equal_approx(float(SurvivorDirector.spawn_plan(0.0).hp_mult), 0.75))
	Survivor.palier = 1
	check("niveau du héros : plus de plafond de carte (90)", Survivor.level_cap(15) == 90)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var boxes: Array = []
	var tiers: Array = []
	for i in 30:
		boxes.append("head")
		tiers.append(0)
	SurvivorDirector.layout_map(boxes, tiers, rng)
	var count := func(id: String) -> int: return boxes.count(id)
	var slots_ok := true
	for s in ["head", "chest", "legs", "gloves", "boots", "back", "necklace", "ring"]:
		slots_ok = slots_ok and count.call("sv_" + s) == 2
	check("30 coffres : 2 par emplacement (16), 2 d'arme, 6 de sort, 6 dorés", slots_ok and count.call("sv_weapon") == 2 and count.call("sv_spell") == 6 and count.call("sv_gold") == 6)
	check("apparences : simple, ouvragé (sort), doré", tiers.count(2) == 6 and tiers.count(1) == 6 and tiers.count(0) == 18)
	check("aucun coffre de la Survie (trophée, certificat, passif)", boxes.all(func(b): return SurvivorDirector.BOXES.has(b)))
	Run.finish("abandon")
	Profile.end_run_survival()


# --- une run en monde : butin, gardiens, portail, arène forcée, boss, victoire ------------------------------------------
func _launch(zone := "limestone") -> Node:
	get_tree().paused = false  # (le bilan de la run d'avant tient la pause)
	Engine.time_scale = 1.0
	Profile.in_run = false
	Survivor.start("warrior", zone)
	get_tree().change_scene_to_file.call_deferred(WORLD)
	await _wait(0.5)
	if not await _until(func(): return _world() != null, 90.0, "monde"):
		return null
	var w := _world()
	if await _until(func(): return w.cards.is_open(), 90.0, "choix de départ"):  # (charge de la machine : il arrive après 10 s, et tient la pause tant qu'il est ouvert)
		w.cards._opened_at -= CardPicker.CONFIRM_DELAY_MS
		w.cards._choose(0)
	w.player.autoplay = true  # les choix suivants se font seuls (CardPicker.auto_pick)
	return w


func _guardians(w: Node) -> Array:
	return get_tree().get_nodes_in_group("monsters").filter(func(m): return m is GiantMonster and m.has_meta("sv_guardian") and not m.is_dead)


func _victory_run() -> void:
	var hub := _hub()
	var w := await _launch()
	check("monde du Survivant chargé", w != null)
	if w == null:
		return
	var d: RunDirector = w.director
	check("directeur du Survivant, état exploration", d.sv != null and d.state == "explore")
	var chests: Array = d.map.interactables.filter(func(it): return is_instance_valid(it) and it.kind == "chest")
	check("30 coffres du Survivant sur la carte (%d)" % chests.size(), chests.size() == 30
		and chests.all(func(it): return SurvivorDirector.BOXES.has(String(it.get_meta("box", "")))))
	check("noms des coffres : « Coffre de bague », « Coffre doré »… (%s)" % chests[0].title, chests.all(func(it): return not String(it.title).begins_with("Coffre ·")))
	check("pas d'extraction en Survivant", (func(): d.start_extraction(); return not d.extracting).call())
	# 60 s de pilote (temps accéléré) : ni pièce, ni fourniture, ni coffre de récompense au sol
	Engine.time_scale = 4.0
	var kills0 := Run.kills
	await _until(func(): return d.time >= 60.0, 300.0, "60 s de carte")
	Engine.time_scale = 1.0
	var drops: Array = get_tree().get_nodes_in_group("loot").map(func(n): return n.item)
	var bad := drops.filter(func(it): return not String(it.get("consumable", "")).begins_with("potion:"))
	print("   pilote : %.0f s de carte, %d monstres vaincus, %d objets au sol, niveau %d" % [d.time, Run.kills - kills0, drops.size(), w.player.level])
	check("60 s de pilote : le héros joue (monstres vaincus)", Run.kills > kills0 and d.time >= 50.0)
	check("butin au sol : des potions seulement (%s)" % [bad.slice(0, 3)], bad.is_empty())
	check("sac : aucune fourniture (%s)" % Profile.bag, Profile.bag.keys().all(func(k): return String(k).begins_with("potion:")))
	check("pas de rage de carte", d.state == "explore" and d.rage_tier() == 0)
	check("niveau des monstres = courbe par minute (sans plancher du héros)", d._monster_level(0) == int(SurvivorDirector.spawn_plan(d.time).level))
	# portail fermé avant 15:00
	d.sv.try_enter_boss()
	check("portail du boss fermé avant 15:00", d.state == "explore")
	# gardien 1 à 5:00
	d.time = 289.0
	await _wait(0.3)
	d.time = 299.6
	check("gardien 1 à 5:00", await _until(func(): return _guardians(w).size() >= 1, 5.0, "gardien 1"))
	var g: Monster = _guardians(w)[0] if not _guardians(w).is_empty() else null
	check("gardien 1 : géant aux PV fixes 40 000 (%s), à environ 18 m" % (str(roundi(g.max_hp)) if g else "?"), g != null and is_equal_approx(g.max_hp, 40000.0)
		and absf(d._flat(g.global_position, w.player.global_position) - SurvivorDirector.GUARDIAN_DIST) < 6.0)
	var gold0 := Profile.gold
	if g:
		g.take_damage(g.max_hp * 10.0 + 1e7, w.player)
	await _wait(0.5)
	check("gardien 1 vaincu : or, la Menace ne monte pas", d.sv.guardians_killed() == 1 and Profile.gold > gold0 and Menace.level == 0)
	# gardien 2 à 10:00, sous Menace ×1,2
	Menace.level = 1
	d.time = 599.6
	check("gardien 2 à 10:00", await _until(func(): return _guardians(w).size() >= 1, 5.0, "gardien 2"))
	g = _guardians(w)[0] if not _guardians(w).is_empty() else null
	check("gardien 2 : 150 000 × Menace ×1,2 (%s)" % (str(roundi(g.max_hp)) if g else "?"), g != null and is_equal_approx(g.max_hp, 180000.0))
	if g:
		g.take_damage(g.max_hp * 10.0 + 1e7, w.player)
	Menace.level = 0
	# gardien 3 et portail à 15:00
	d.time = 899.6
	check("gardien 3 à 15:00 (450 000)", await _until(func(): return _guardians(w).any(func(m): return int(m.get_meta("sv_guardian")) == 2), 5.0, "gardien 3")
		and _guardians(w).any(func(m): return is_equal_approx(m.max_hp, 450000.0)))
	d.time = 905.5
	await _wait(0.3)
	check("portail du boss ouvert à 15:00 (trace vers le donjon)", d.sv.portal_open() and d.dungeon_found)
	check("HUD : objectifs du Survivant (portail ouvert)", d.sv.objective_lines()[1].begins_with("✔") and d.sv.status_text().begins_with("Gardiens"))
	# arène forcée à 20:00, héros de niveau élevé : PV du boss toujours fixes
	w.player.level = 30
	w.player.recalc_stats()
	Menace.level = 2
	d.time = 1199.8
	check("20:00 : entrée forcée dans l'arène", await _until(func(): return d.state == "boss", 10.0, "arène"))
	await _wait(0.5)
	var boss: Monster = d._boss
	check("arène forcée (pas en avance), à 20:00", d.sv.arena_forced and d.sv.early_seconds() == 0.0 and d.sv.arena_at >= 1199.0)
	check("boss : PV fixes 1 500 000 × Menace ×1,4 (%s), jamais d'après le héros" % (str(roundi(boss.max_hp)) if boss else "?"),
		boss != null and is_equal_approx(boss.max_hp, 1500000.0 * 1.4))
	check("rage du boss après 4:00", is_equal_approx(d._boss_rage_start(), 240.0) and d.boss_rage_tier() == 0)
	d._boss_time = 241.0
	check("rage du boss : palier 1 à 4:01", d.boss_rage_tier() == 1)
	d._boss_time = 0.0
	Menace.level = 0
	# victoire : le boss tombe
	var line := {}
	boss.take_damage(boss.max_hp * 10.0 + 1e9, w.player)
	check("boss vaincu : victoire", await _until(func(): return d.state == "cleared", 5.0, "boss vaincu"))
	check("bilan de victoire", await _until(func(): return _results() != null, 20.0, "bilan"))
	check("résultat « victoire »", Run.result == "victoire")
	line = RunJournal.last_line
	check("journal : mode survivor, minutes, gardiens, arène (%s)" % [line.keys().filter(func(k): return String(k).begins_with("sv_"))],
		line.get("mode", "") == "survivor" and (line.get("sv_minutes", []) as Array).size() >= 1 and (line.get("sv_guardians", []) as Array).size() == 3
		and bool(line.get("sv_arena_forced", false)) and int(line.get("sv_boss_hp", 0)) == 1500000)
	Profile.end_run_survival()
	check("victoire : hub intact", _hub() == hub)


# --- défaite : la seconde chute termine la run ---------------------------------------------------------------------------
func _defeat_run() -> void:
	var hub := _hub()
	var w := await _launch("rainbowfall")
	check("2e run (Rainbowfall) chargée", w != null)
	if w == null:
		return
	await _wait(2.0)
	w.player.take_damage(1e9, null, false)
	check("1re chute : résurrection", await _until(func(): return not w.player.is_dead and w.revives_left == 0, 10.0, "résurrection"))
	w.player.take_damage(1e9, null, false)
	check("2e chute : fin de run, défaite", await _until(func(): return _results() != null, 15.0, "bilan défaite") and Run.result == "defaite")
	Profile.end_run_survival()
	check("défaite : hub intact", _hub() == hub)


# --- entrée en avance au portail, puis abandon ----------------------------------------------------------------------------
func _early_run() -> void:
	var hub := _hub()
	var w := await _launch()
	if w == null:
		check("3e run chargée", false)
		return
	var d: RunDirector = w.director
	d.time = 905.5
	await _wait(0.3)
	d.sv.try_enter_boss()
	check("entrée en avance au portail (15:05)", await _until(func(): return d.state == "boss", 10.0, "arène en avance"))
	check("avance comptée pour l'Audace (≈ 295 s)", not d.sv.arena_forced and absf(d.sv.early_seconds() - 294.5) < 3.0)
	d.time = 1300.0
	await _wait(0.3)
	check("aucune seconde entrée forcée", d.state == "boss")
	w.pause_menu.abandon_requested.emit()
	check("abandon : bilan", await _until(func(): return _results() != null, 15.0, "bilan abandon") and Run.result == "abandon")
	Profile.end_run_survival()
	check("abandon : hub intact", _hub() == hub)
