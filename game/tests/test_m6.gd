extends Node
## Passe M6 (Ruée des boss et Siège) : tirage de la Ruée dans la bibliothèque (un boss par zone, mécaniques variées, graine,
## nouveau tirage), modificateurs et leurs cristaux, PV des boss, boss du jour et lieutenants du Siège, objectifs secondaires,
## estimation de difficulté et pages du lobby ; puis une Ruée et un Siège en scène (boss de la bibliothèque, escouades par rôle).
## godot --headless --path game res://tests/test_m6.tscn

var fails := 0
var _world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	_rush_data()
	_siege_data()
	_verdicts()
	await _pages()
	await _rush_scene()
	await _siege_scene()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


# --- Ruée : tirage, modificateurs, PV, butin ------------------------------------------------------
func _rush_data() -> void:
	var zones := Dungeons.zone_ids()
	var a := Rush.lineup_for(4821)
	Rush._cache.clear()
	check("tirage déterministe pour une graine", Rush.lineup_for(4821) == a)
	check("8 boss, un par zone, dans l'ordre des zones", a.size() == zones.size() and range(a.size()).all(func(i): return Dungeons.boss_zone(a[i]) == zones[i]))
	var seen := {}
	var shared := 0
	var pairs := 0
	var heavy := 0
	for s in range(1000, 1200):
		var l := Rush.lineup_for(s)
		for i in l.size():
			seen[l[i]] = true
			if i > 0:
				pairs += 1
				var n := Rush._shared(BossLibrary.families_of(l[i - 1]), BossLibrary.families_of(l[i]))
				shared += n
				if n >= 2:
					heavy += 1
	check("200 tirages : au moins 40 des 48 boss apparaissent (%d)" % seen.size(), seen.size() >= 40)
	check("deux boss qui se suivent partagent rarement une famille de mécaniques (%.2f en moyenne, %d paires sur %d à 2 et plus)" % [float(shared) / pairs, heavy, pairs],
		float(shared) / pairs < 0.6 and heavy <= pairs / 20)
	Profile.records.erase("rush_seed")
	Profile.records.erase("rush_prev")
	var s0 := Rush.current_seed()
	check("graine tirée et gardée (affichée sur la page)", s0 >= 1000 and Rush.current_seed() == s0)
	var before := Rush.lineup_for(s0)
	var s1 := Rush.reroll()
	var after := Rush.lineup_for(s1)
	var same := range(before.size()).filter(func(i): return before[i] == after[i]).size()
	check("nouveau tirage : autre graine, presque tous les boss changent (%d repris sur 8)" % same, s1 != s0 and same <= 2)
	# modificateurs
	Profile.records["rush_mods"] = 0
	Rush.toggle("no_heal")
	Rush.toggle("blind")
	check("modificateurs cochés et gardés", Rush.chosen() == ["no_heal", "blind"])
	check("bonus de cristaux des modificateurs", is_equal_approx(Rush.bonus(["no_heal", "enraged", "blind"]), 1.85) and is_equal_approx(Rush.bonus([]), 1.0))
	Tower.start_dungeon("warrior", Dungeons.RUSH, 2, [])
	check("Ruée lancée : tirage proposé et modificateurs cochés", Tower.rush and Rush.seed == Rush.current_seed() and Rush.lineup == Rush.lineup_for(Rush.seed) and Rush.mods == ["no_heal", "blind"])
	check("à l'aveugle : le boss suivant est caché, celui en cours non", Rush.shown_name(3, 2) == "???" and Rush.shown_name(2, 2) == BossLibrary.short_name(Rush.boss_at(2)))
	var hp1 := Rush.boss_hp(1, 91, 2, 0) / BossLibrary.hp(Rush.boss_at(1), 91, 2, true)
	var hp8 := Rush.boss_hp(8, 91, 2, 0) / BossLibrary.hp(Rush.boss_at(8), 91, 2, true)
	check("Mythique (tous niveau 90) : PV en rampe du 1er au 8e (×%.2f → ×%.2f)" % [hp1, hp8], hp1 < 0.9 and hp8 > 1.1)
	check("Normal : PV fixes du palier × le boss, + 50 % par allié", is_equal_approx(Rush.boss_hp(4, 40, 0, 2), BossLibrary.hp(Rush.boss_at(4), 40, 0, true) * 2.0))
	var seed_run := Rush.seed
	var rew := Dungeons.rush_reward(8, 2)
	check("butin : cristaux × bonus (%d), boss vaincus et modificateurs au bilan" % int(rew.crystals),
		int(rew.crystals) == roundi(ActivityLoot.rush_crystals(8, 2) * 1.45) and (rew.bosses as Array).size() == 8 and rew.mods == ["no_heal", "blind"])
	check("Ruée vaincue : un nouveau tirage est proposé", Rush.current_seed() != seed_run)
	Tower.finish()
	check("fin : la Ruée en cours est remise à zéro", Rush.lineup.is_empty() and Rush.seed == 0 and not Tower.rush)
	Profile.records["rush_mods"] = 0
	check("PE conseillée au moins la requise, croissante", Rush.advised(1) >= Dungeons.power_required(Dungeons.RUSH, 1) and Rush.advised(2) > Rush.advised(0))


# --- Siège : boss du jour, lieutenants, objectifs --------------------------------------------------
func _siege_data() -> void:
	var zid := String(Dungeons.zone_ids()[2])
	var bid := Siege.boss_for(zid, "2026-10-15")
	check("Siège : boss du jour de la zone (bibliothèque)", bid in BossLibrary.for_zone(zid))
	var days := {}
	for d in range(1, 29):
		days[Siege.boss_for(zid, "2026-10-%02d" % d)] = true
	check("le boss change selon le jour (%d boss différents sur 28 jours)" % days.size(), days.size() >= 4)
	var lts := Siege.lieutenants_for(zid, "2026-10-15")
	check("deux lieutenants, autres que le boss, différents", lts.size() == 2 and not bid in lts and lts[0] != lts[1])
	check("lieutenants aux vagues d'élites", Siege.lieutenant_at(zid, 3) != "" and Siege.lieutenant_at(zid, 5) != "" and Siege.lieutenant_at(zid, 1) == "")
	Siege.reset()
	Siege.ally_fell = true
	check("objectifs : boss sans allié debout, avant la fureur", Siege.score_stars(true, true) == ["boss", "fast"])
	Siege.ally_fell = false
	check("objectifs : les trois", Siege.score_stars(true, true) == ["boss", "allies", "fast"])
	var plain := ActivityLoot.siege_crystals(Siege.WAVES + 1, 1, true)
	var r := Siege.settle(zid, 1, Siege.WAVES + 1, "eliminated")
	check("objectifs secondaires : +25 %% de cristaux chacun (%d contre %d)" % [int(r.crystals), plain], int(r.crystals) == roundi(plain * 1.5))
	check("étoiles retenues par zone et difficulté, nouvelles au bilan", Siege.stars(zid, 1) == ["boss", "allies", "fast"] and (r.new_stars as Array).size() == 3)
	Siege.score_stars(true, false)
	var r2 := Siege.settle(zid, 1, Siege.WAVES + 1, "eliminated")
	check("étoiles déjà gagnées : rien de nouveau, gardées", (r2.new_stars as Array).is_empty() and Siege.stars(zid, 1).size() == 3)
	Siege.reset()
	check("PE conseillée du Siège au moins la requise", Siege.advised(zid, 1) >= Siege.power_required(zid, 1) and Siege.advised(zid, 0) > 0)


func _verdicts() -> void:
	check("estimation : Facile / Équilibré / Difficile / Hors de portée selon la PE conseillée",
		DifficultyPanel.verdict(150, 100)[0] == "Facile" and DifficultyPanel.verdict(100, 100)[0] == "Équilibré"
		and DifficultyPanel.verdict(80, 100)[0] == "Difficile" and DifficultyPanel.verdict(40, 100)[0] == "Hors de portée")
	var box := VBoxContainer.new()
	add_child(box)
	DifficultyPanel.add(box, 50000, 60000, ["100 cristaux"])
	var texts := _texts(box)
	check("bloc : PE requise et la tienne, estimation, récompenses, avertissement (compte neuf)",
		texts.any(func(t): return t.begins_with("PE requise")) and texts.has("Hors de portée") and texts.any(func(t): return t.begins_with("Récompenses"))
		and texts.any(func(t): return t.begins_with("⚠")))
	check("aucun pourcentage dans le texte permanent du bloc", not texts.any(func(t): return "%" in t))
	box.queue_free()


func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append(String(n.text))
	for c in n.get_children():
		out.append_array(_texts(c))
	return out


# --- pages du lobby ---------------------------------------------------------------------------------
func _pages() -> void:
	Settings.set_v("interface", "dev_mode", true)
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(1.0).timeout
	lobby._dg_diff = 2
	lobby._show_menu("rush")
	await get_tree().create_timer(0.3).timeout
	var t := _texts(lobby._sub)
	check("page Ruée : tirage et ses 8 boss", t.any(func(x): return x.begins_with("Les 8 boss · tirage n°")) and t.filter(func(x): return x.length() > 3 and x[0] in "12345678" and x[1] == " ").size() == 8)
	check("page Ruée : PE et estimation, récompenses, modificateurs", t.any(func(x): return x.begins_with("PE requise")) and t.any(func(x): return x.begins_with("Récompenses"))
		and t.has("Modificateurs"))
	var seed0 := Rush.current_seed()
	var btn: Button = _find_button(lobby._sub, "Nouveau tirage")
	check("bouton « Nouveau tirage »", btn != null)
	if btn:
		btn.pressed.emit()
		await get_tree().create_timer(0.3).timeout
		check("nouveau tirage : autre graine affichée", Rush.current_seed() != seed0 and _texts(lobby._sub).any(func(x): return x.ends_with("n° %d" % Rush.current_seed())))
	lobby._dg_diff = 0
	lobby._show_menu("siege")
	await get_tree().create_timer(0.3).timeout
	t = _texts(lobby._sub)
	check("page Siège : boss du jour, lieutenants, objectifs, PE conseillée", t.has("Boss du jour") and t.any(func(x): return x.begins_with("Lieutenants"))
		and t.any(func(x): return x.begins_with("Objectifs")) and t.any(func(x): return x.begins_with("PE conseillée")))
	lobby.queue_free()
	Settings.set_v("interface", "dev_mode", false)
	await get_tree().create_timer(0.3).timeout


func _find_button(n: Node, text: String) -> Button:
	if n is Button and String(n.text).ends_with(text):
		return n
	for c in n.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


# --- en scène ---------------------------------------------------------------------------------------
func _launch() -> Node:
	var world: Node = load("res://scenes/world.tscn").instantiate()
	_world = world
	get_tree().root.add_child.call_deferred(world)
	await _wait(func(): return world.is_inside_tree() and world.director != null and world.director.tower != null and world.player != null, 40.0)
	world.player.immortal = true
	await _wait(func(): return world.cards.is_open(), 5.0)
	world.cards._queue.clear()
	world.cards._show_next()
	return world


func _wait(cond: Callable, secs := 10.0) -> void:
	var t := 0.0
	while t < secs and not cond.call():
		t += get_physics_process_delta_time()
		if is_instance_valid(_world) and _world.get("cards") != null and _world.cards.is_open():
			_world.cards._choose(0)
		await get_tree().physics_frame


func _rush_scene() -> void:
	Profile.reset_all()
	Profile.records["rush_mods"] = 0
	Rush.toggle("no_heal")
	Tower.start_dungeon("warrior", Dungeons.RUSH, 0, [])
	var lineup := Rush.lineup.duplicate()
	var world := await _launch()
	var td = world.director.tower
	check("Ruée en scène : directeur de la Ruée", td is RushDirector)
	await _wait(func(): return is_instance_valid(td._boss), 5.0)
	check("boss 1 = 1er boss du tirage, de la bibliothèque, sans renforts génériques", is_instance_valid(td._boss) and String(td._boss.get_meta("boss_id", "")) == lineup[0] and not td._adds_on)
	check("PV du boss : ceux de la Ruée (%d)" % int(td._boss.max_hp), is_equal_approx(td._boss.max_hp, Rush.boss_hp(1, Tower.level_for(1) + 1, 0, 0) * Menace.hp_mult()))
	check("HUD : « Boss 1/8 » et le boss suivant dans l'objectif", td.clock_text() == "Boss 1/8" and BossLibrary.short_name(lineup[1]) in td.objective_text())
	var bar: BossBar = world.hud._boss_bar  # barre de boss v2 (lot DNG-2)
	if world.cards.is_open():
		world.cards._choose(0)
	await _wait(func(): return bar.visible and bar.current() == td._boss, 3.0)
	check("Ruée : barre de boss v2 sur le boss du tirage (« %s », barre %s, suivi %s), pastilles de ses mécaniques" % [bar._diff.text, bar.visible, bar.current() == td._boss],
		bar.visible and bar.current() == td._boss and bar._diff.text == Dungeons.DIFF_NAMES[0] and bar._chips.size() >= 1)
	var p: Player = world.player
	p.hp = p.max_hp * 0.4
	td._boss.hp = 1.0
	td._boss.take_damage(1e12, p, false)
	await _wait(func(): return td.phase == "stairs", 10.0)
	check("boss vaincu : carte prise, escalier vers le boss suivant", td.phase == "stairs" and "Boss suivant" in td.objective_text())
	var ratio := p.hp / p.max_hp
	td.interact(td._goal)
	await _wait(func(): return is_instance_valid(td._boss), 5.0)
	check("boss 2 du tirage", Tower.floor_n == 2 and String(td._boss.get_meta("boss_id", "")) == lineup[1])
	check("Sans répit : pas de soin entre deux boss (%.2f → %.2f)" % [ratio, p.hp / p.max_hp], absf(p.hp / p.max_hp - ratio) < 0.02)
	world.queue_free()
	Tower.active = false
	Tower.finish()
	Profile.records["rush_mods"] = 0
	await get_tree().create_timer(0.5).timeout


func _roles_species() -> Dictionary:
	var roles := {}
	var species := {}
	for m in get_tree().get_nodes_in_group("monsters"):
		if m.has_meta("role"):
			roles[String(m.get_meta("role"))] = true
			species[int(m.data.get("id", 0))] = true
	return {"roles": roles, "species": species}


func _siege_scene() -> void:
	Profile.reset_all()
	Profile.records["epochs_cleared"] = 2
	var zid := String(Dungeons.zone_ids()[0])
	Tower.start_siege("warrior", zid, 0, ["cleric", "knight"])
	var world := await _launch()
	var td: SiegeDirector = world.director.tower
	# les escouades arrivent l'une après l'autre : on attend l'événement (au moins 2 rôles et 2 espèces en jeu), pas une durée
	await _wait(func(): return td.alive() >= 8 and _roles_species().roles.size() >= 2 and _roles_species().species.size() >= 2, 60.0)
	var rs := _roles_species()
	var roles: Dictionary = rs.roles
	var species: Dictionary = rs.species
	check("vague 1 : escouades par rôle (%s), plusieurs espèces (%d)" % [roles.keys(), species.size()], roles.size() >= 2 and species.size() >= 2)
	check("alliés : comportement d'équipe (lisent les zones rouges)", td._allies.size() == 2 and td._allies[0]._team_mode())
	# vague 3 : le lieutenant (vagues 1 et 2 vidées d'office)
	for _i in 3000:
		if Tower.floor_n == 3 and td.phase == "fight":
			break
		if world.cards.is_open():
			world.cards._choose(0)
		if td.phase == "rest":
			td._rest_t = 0.0
		if td.phase == "fight" and Tower.floor_n < 3:
			td.left = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not m.is_dead:
					m.hp = 1.0
					m.take_damage(1e12, world.player, false)
		await get_tree().physics_frame
	await get_tree().create_timer(0.3).timeout
	var lid := Siege.lieutenant_at(zid, 3)
	var found := get_tree().get_nodes_in_group("monsters").filter(func(m): return String(m.get_meta("boss_id", "")) == lid)
	check("vague 3 : le lieutenant %s est là (une mécanique)" % lid, Tower.floor_n == 3 and found.size() == 1)
	world.queue_free()
	Tower.active = false
	Tower.finish()
	await get_tree().create_timer(0.5).timeout
