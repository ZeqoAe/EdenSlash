extends Node
## Passe M3 (la Tour) : types d'étage déterministes, une élite à mécanique à chaque étage de monstres, boss de la
## bibliothèque variés, ombres (classe, ton ombre, ombre éveillée), halte, étage maudit ; puis chaque type en jeu.
## godot --headless --path game res://tests/test_m3.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	_data()
	await _scene()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _data() -> void:
	# --- plan déterministe -------------------------------------------------------------------
	var first: Array = range(1, Tower.FLOORS + 1).map(func(f): return Tower.floor_type(f))
	Tower._plans.clear()
	Tower._boss_cache.clear()
	var again: Array = range(1, Tower.FLOORS + 1).map(func(f): return Tower.floor_type(f))
	check("types d'étage déterministes (même plan après remise à zéro)", first == again)
	check("duellistes aux étages 1, 4 et 7, et nulle part ailleurs",
		range(1, Tower.FLOORS + 1).filter(func(f): return Tower.floor_type(f) == "duel") == [1, 4, 7])
	check("boss tous les 10 étages, halte juste avant", range(1, Tower.FLOORS + 1).all(func(f):
		return (Tower.floor_type(f) == "boss") == (f % 10 == 0) and (Tower.floor_type(f) == "rest") == (f % 10 == 9)))
	# fil d'éveil : les duellistes comptent comme avant (Duel libre au 1er, Ligue au 3e)
	Profile.records[Tower.record_key(1)] = 4
	var two := Tower.duelists_beaten()
	Profile.records[Tower.record_key(1)] = 7
	var three := Tower.duelists_beaten()
	Profile.records.erase(Tower.record_key(1))
	check("fil d'éveil : 2 duellistes à l'étage 4, 3 à l'étage 7", two == 2 and three == 3)
	# --- élites ------------------------------------------------------------------------------
	var no_elite: Array = []
	var dup_mech: Array = []
	for f in range(1, Tower.FLOORS + 1):
		var t := Tower.floor_type(f)
		if t in ["monsters", "elite", "cursed"]:
			if Tower.elite_count(f) < 1:
				no_elite.append(f)
			var m: Array = Tower.spec(f).mechanics
			var uniq := {}
			for b in m:
				uniq[b] = true
			if uniq.size() != m.size() or not m.all(func(b): return BossBricks.DEFS.has(String(b))):
				dup_mech.append(f)
	check("au moins une élite à chaque étage de monstres, d'élites ou maudit", no_elite.is_empty())
	check("mécaniques d'élite connues et toutes différentes sur un étage", dup_mech.is_empty())
	check("étage d'élites : 3 élites au moins", range(1, Tower.FLOORS + 1).filter(func(f): return Tower.floor_type(f) == "elite").all(func(f): return Tower.elite_count(f) >= 3))
	var all_mechs := {}
	for f in range(1, Tower.FLOORS + 1):
		for b in Tower.spec(f).get("mechanics", []):
			all_mechs[b] = true
	check("les %d mécaniques d'élite servent toutes" % Tower.ELITE_BRICKS.size(), all_mechs.size() == Tower.ELITE_BRICKS.size())
	# --- espèces -----------------------------------------------------------------------------
	var poor: Array = []
	for f in range(1, Tower.FLOORS + 1):
		if Tower.floor_type(f) in ["monsters", "elite", "cursed"]:
			var sp := Tower.floor_species(f)
			if sp.size() < 3:
				poor.append(f)
	check("étages de monstres : 3 espèces au moins (plus de packs d'une seule espèce)", poor.is_empty())
	var mixes := {}
	for f in range(11, 26):
		mixes[str(Tower.floor_species(f))] = true
	check("le mélange d'espèces change d'un étage à l'autre", mixes.size() >= 4)
	# --- boss --------------------------------------------------------------------------------
	var bosses: Array = range(10, Tower.FLOORS + 1, 10).map(func(f): return Tower.boss_id(f))
	check("20 étages de boss, tous des boss de la bibliothèque", bosses.size() == 20 and bosses.all(func(b): return BossLibrary.has(String(b))))
	var repeats := 0
	for i in range(1, bosses.size()):
		if bosses[i] == bosses[i - 1]:
			repeats += 1
	var distinct := {}
	for b in bosses:
		distinct[b] = true
	check("boss variés : jamais deux fois de suite, au moins 15 différents", repeats == 0 and distinct.size() >= 15)
	check("le dernier boss de chaque zone est son gardien", [20, 50, 75, 100, 125, 150, 175, 200].all(func(f):
		var zid := String(Tower.zone_for(f).id)
		return Tower.boss_id(f) == BossLibrary.zone_boss(zid) or Tower.floor_type(f) != "boss"))
	check("PV fixes du boss qui montent avec l'étage", Tower.boss_hp_fixed(100, 1) > Tower.boss_hp_fixed(50, 1) and Tower.boss_hp_fixed(50, 1) > Tower.boss_hp_fixed(10, 1))
	check("PV du boss plus hauts en Hardcore qu'en Facile", Tower.boss_hp_fixed(30, 3) > Tower.boss_hp_fixed(30, 0))
	check("palier du boss qui monte avec l'étage", Tower.boss_tier(10, 1) == 0 and Tower.boss_tier(100, 1) == 1 and Tower.boss_tier(190, 1) == 2)
	# --- ombres ------------------------------------------------------------------------------
	var shadows: Array = range(1, Tower.FLOORS + 1).filter(func(f): return Tower.floor_type(f) == "shadow")
	check("deux ombres par bloc de 10 après le premier (38)", shadows.size() == 38)
	var classes := {}
	for f in shadows:
		classes[Tower.duel_class(f)] = true
	check("ombres de classes variées (au moins 20 classes)", classes.size() >= 20)
	check("une ombre sur quatre est la tienne", shadows.filter(func(f): return Tower.shadow_kind(f, 1) == "self").size() == shadows.size() / 4)
	var brains := shadows.filter(func(f): return Tower.shadow_kind(f, 3) == "brain")
	check("ombres éveillées (cerveau d'IA) en Hardcore à partir de l'étage 100 seulement", not brains.is_empty() and brains.all(func(f): return f >= 100)
		and shadows.all(func(f): return Tower.shadow_kind(f, 1) != "brain"))
	check("IA des ombres plus dure aux étages hauts", Tower.duel_ai(shadows[0], 0) == 0 and Tower.duel_ai(shadows[-1], 0) == 2 and Tower.duel_ai(4, 0) == 0)
	# --- maudits -----------------------------------------------------------------------------
	var cursed: Array = range(1, Tower.FLOORS + 1).filter(func(f): return Tower.floor_type(f) == "cursed")
	var curses := {}
	for f in cursed:
		curses[Tower.curse_of(f)] = true
	check("un étage maudit par bloc à partir du bloc 3 (18), les 3 malédictions", cursed.size() == 18 and curses.size() == 3 and cursed.all(func(f): return f > 20))
	# --- fiches de toutes les difficultés ------------------------------------------------------
	var bad: Array = []
	for d in Tower.DIFF_NAMES.size():
		for f in [1, 2, 5, 9, 10, shadows[0], shadows[3], cursed[0], 100, 199, 200] + brains.slice(0, 1):
			var txt := TowerPages.info_text(Tower.spec(f, d))
			var line: Array = TowerPages.floor_line(f, d)
			if txt.length() < 40 or String(line[0]).length() < 8 or ("%" in txt and Tower.floor_type(f) not in ["duel", "shadow"]):  # (descriptions de sorts : données du jeu)
				bad.append("%d/%d %s" % [f, d, String(line[0])])
	check("fiches et lignes de tous les types, toutes difficultés %s" % [bad.slice(0, 4)], bad.is_empty())
	print("[m3] plan des blocs 0 à 3 : %s" % [range(4).map(func(b): return ",".join(Tower.block_plan(b).map(func(t): return String(t).left(3))))])
	print("[m3] boss : %s" % [",".join(bosses)])


func _scene() -> void:
	Tower.start("warrior", 3, 1)  # Hardcore : l'ombre éveillée existe aux étages hauts
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(5.0).timeout
	var d: RunDirector = world.director
	var td: TowerDirector = d.tower
	world.player.dev_invincible = true  # le héros du test ne tombe pas (ombre éveillée de l'étage 100+ au niveau 1)
	world.cards._queue.clear()
	world.cards._show_next()
	check("Tour en scène : étage 1, duelliste face au joueur", td != null and Tower.floor_n == 1 and is_instance_valid(td._rival))
	# étage de monstres : élites armées de leur mécanique, mélange d'espèces
	var mf := 2
	td.begin(mf)
	await get_tree().create_timer(2.5).timeout
	var elites: Array = get_tree().get_nodes_in_group("monsters").filter(func(m): return m.is_elite)
	check("étage de monstres : une élite avec sa mécanique (cerveau) et son nom", elites.size() >= 1 and elites.all(func(m): return m.brain != null and " · " in m.display_name))
	var species := {}
	for m in get_tree().get_nodes_in_group("monsters"):
		if not m.is_elite:
			species[m.data.get("id", m.display_name)] = true
	check("étage de monstres : plusieurs espèces à l'écran", species.size() >= 2)
	check("HUD : étage et type à l'horloge", td.clock_text() == "Étage %d/%d · Monstres" % [mf, Tower.FLOORS])
	# étage d'élites
	td.begin(5)
	await get_tree().create_timer(1.5).timeout
	elites = get_tree().get_nodes_in_group("monsters").filter(func(m): return m.is_elite and m.brain != null)
	check("étage d'élites : 3 élites à mécanique", elites.size() >= 3)
	# halte
	world.cards._queue.clear()
	td.begin(9)
	await get_tree().create_timer(0.5).timeout
	check("halte : pas de monstre, une carte à choisir", td.phase == "cards" and td.alive() == 0 and Tower.reached == 9)
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.6).timeout
	check("halte : puis le coffre", td.phase == "chest")
	# boss de la bibliothèque
	td.begin(10)
	await get_tree().create_timer(1.5).timeout
	check("étage 10 : boss de la bibliothèque, PV fixes", is_instance_valid(td._boss) and td._boss.has_meta("boss_id")
		and String(td._boss.get_meta("boss_id")) == Tower.boss_id(10) and absf(td._boss.max_hp - Tower.boss_hp_fixed(10)) < 1.0)
	check("boss : pas de renforts génériques (ses invocations sont ses mécaniques)", not td._adds_on)
	# ombres
	var shadows: Array = range(1, Tower.FLOORS + 1).filter(func(f): return Tower.floor_type(f) == "shadow")
	td.begin(shadows[0])
	await get_tree().create_timer(1.0).timeout
	check("ombre : un héros scripté nommé « Ombre · classe »", is_instance_valid(td._rival) and td._rival.display_name.begins_with("<Duel> Ombre · "))
	var own: int = shadows.filter(func(f): return Tower.shadow_kind(f) == "self")[0]
	td.begin(own)
	await get_tree().create_timer(1.0).timeout
	check("ton ombre : ta classe", is_instance_valid(td._rival) and td._rival.cid == "warrior" and "Ton ombre" in td._rival.display_name)
	var bf: int = shadows.filter(func(f): return Tower.shadow_kind(f) == "brain")[0]
	td.begin(bf)
	await get_tree().create_timer(1.5).timeout
	var brain_ok := is_instance_valid(td._hero) and td._hero.foe and "Ombre éveillée" in td._hero.display_name
	var fallback_ok := is_instance_valid(td._rival) and not is_instance_valid(td._hero)
	check("ombre éveillée : cerveau d'IA (ou repli scripté si le cerveau manque)", brain_ok or fallback_ok)
	print("[m3] ombre éveillée de l'étage %d : %s" % [bf, "cerveau d'IA" if brain_ok else "repli scripté"])
	if brain_ok:
		var h: Player = td._hero
		for i in 6:  # (il esquive parfois)
			if is_instance_valid(h) and not h.is_dead:
				h.hp = 1.0
				h.take_damage(50.0)
			await get_tree().physics_frame
		await get_tree().create_timer(1.0).timeout
		check("ombre éveillée vaincue : étage vidé (%s, %s, pause %s)" % [td.phase, Tower.reached, get_tree().paused], td.phase in ["cards", "chest"] and Tower.reached == bf)
	# étage maudit
	var cf: int = range(1, Tower.FLOORS + 1).filter(func(f): return Tower.floor_type(f) == "cursed")[0]
	world.cards._queue.clear()
	if world.cards.is_open():
		world.cards._show_next()
	td.begin(cf)
	await get_tree().create_timer(1.5).timeout
	check("étage maudit : malédiction posée", td._curse == Tower.curse_of(cf) and td._curse != "")
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	td.left = 0
	await get_tree().create_timer(0.8).timeout
	check("étage maudit franchi : compté pour les cristaux (%s, %d, %d, pause %s)" % [td.phase, td.alive(), Tower.cursed_cleared, get_tree().paused], Tower.cursed_cleared == 1)
	world.queue_free()
	var got := Tower.finish()
	check("bilan : héros battus, boss vaincus et cristaux des étages maudits", got.has("heroes") and got.has("bosses") and int(got.get("cursed_crystals", 0)) > 0)
