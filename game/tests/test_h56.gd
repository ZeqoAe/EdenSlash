extends Node
## Lot H56 (conception/progression/R_H56.md) : activités au niveau de héros (H5), textes et bilan (H6), boussole (A8),
## rythme de l'équipement (cristaux des coffres de forge de la Survie).
## godot --headless --path game res://tests/test_h56.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = false
	Settings.reset_all()
	Profile.reset_all()
	_test_combat_level()
	_test_panel()
	_test_rhythm()
	_test_texts()
	_test_compass()
	_test_defeat()
	await _test_tower()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _set_level(lv: int) -> void:
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(lv)


func _test_combat_level() -> void:
	_set_level(38)
	check("H5 : héros 38 dans un donjon de niveau 46 : il s'y bat au niveau 38", HeroLevel.combat_level(46) == 38)
	check("H5 : héros 38 dans une activité de niveau 30 : niveau de l'activité (jamais ramené plus bas)", HeroLevel.combat_level(30) == 30)
	check("H5 : ligne de page « ton héros est niveau 38 »", HeroLevel.activity_line(46).contains("niveau 38") and HeroLevel.activity_line(30) == "")
	_set_level(90)
	check("H5 : héros 90, étage de la Tour au-delà du niveau 90 : niveau de l'étage (rien ne change)", HeroLevel.combat_level(97) == 97)
	check("H5 : héros 90 : aucune ligne d'avertissement", HeroLevel.activity_line(97) == "" and HeroLevel.activity_line(90) == "")
	_set_level(1)
	check("H5 : compte neuf : niveau 1 au plus bas", HeroLevel.combat_level(14) == 1)


func _test_panel() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	_set_level(30)
	DifficultyPanel.add(box, 0, 1000, [], "", 46)
	var texts := _texts(box)
	check("H5 : la page d'activité dit que le héros s'y bat à son niveau (%s)" % [texts.filter(func(t): return t.contains("niveau")).slice(0, 2)],
		texts.any(func(t): return t.contains("ton héros est niveau 30")))
	var box2 := VBoxContainer.new()
	add_child(box2)
	_set_level(60)
	DifficultyPanel.add(box2, 0, 1000, [], "", 46)
	check("H5 : héros au niveau de l'activité : pas de ligne", not _texts(box2).any(func(t): return t.contains("ton héros est niveau")))
	box.queue_free()
	box2.queue_free()


func _texts(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append(String(n.text))
	for c in n.get_children():
		out.append_array(_texts(c))
	return out


func _test_rhythm() -> void:
	var adv := Rewards.make("forge", 90, false)
	adv["src"] = Rewards.SRC_ADVENTURE
	var other := Rewards.make("forge", 90, false)
	var a := Rewards.forge_crystals(adv)
	var o := Rewards.forge_crystals(other)
	check("rythme : coffre de forge de la Survie, niveau 90 : plus de cristaux (%s contre %s)" % [a, o], a.x > o.x and a.y > o.y)
	var low := Rewards.make("forge", 40, false)
	low["src"] = Rewards.SRC_ADVENTURE
	check("rythme : coffre de la Survie sous le niveau %d : comme avant" % Rewards.ADVENTURE_CRYSTALS_FROM,
		Rewards.forge_crystals(low) == Rewards.forge_crystals(Rewards.make("forge", 40, false)))
	check("rythme : les coffres de forge des autres activités ne changent pas (niveau 90 : 4-5)", o == Vector2i(4, 5))
	check("rythme : l'aperçu du coffre dit ses vrais cristaux", Rewards.preview(adv).contains("%d-%d cristaux" % [a.x, a.y]))
	check("rythme : verrous de PE Héroïque / Mythique 3,4 / 2,9 (Mythique niveau 90 : %d)" % Dungeons.power_required("limestone", 2),
		is_equal_approx(float(GearPower.DIFF_RATIO[1]), 3.4) and is_equal_approx(float(GearPower.DIFF_RATIO[2]), 2.9))
	check("rythme : la PE conseillée reste au-dessus du verrou", Dungeons.advised("blackflame", 2) > Dungeons.power_required("blackflame", 2)
		and Dungeons.advised("blackflame", 1) > Dungeons.power_required("blackflame", 1))
	Profile.materials["crystal"] = 0
	Profile.reward_chests.append(adv)
	var got := Rewards.open(adv)
	check("rythme : ouvert, il donne ses cristaux (%d)" % int(got.crystal), int(got.crystal) >= a.x and int(got.crystal) <= a.y)


func _test_texts() -> void:
	var lv := Achievements.LIST.filter(func(x): return String(x.id) in ["lvl_25", "lvl_50", "lvl_90"])
	check("H6 : succès de niveau sur le niveau de héros (ids gardés, « Niveau 90 » en plus)", lv.size() == 3 and lv.all(func(x): return String(x.c) == "hero_level"))
	_set_level(52)
	check("H6 : compteur du succès = niveau de héros", int(Achievements.value("hero_level")) == 52)
	var card: Dictionary = Tutorial.CARDS.get("two_levels", {})
	check("H6 : fiche « Deux niveaux » (≤ 125 signes)", not card.is_empty() and String(card.short).length() <= 125)
	check("H6 : le Guide parle du niveau de héros", _guide_text().contains("Niveau de héros") and _guide_text().contains("niveau de run"))


func _guide_text() -> String:
	var s := ""
	for ch in Guide.CHAPTERS:
		for b in Guide.blocks_for(String(ch[0])):
			s += String(b.get("title", "")) + " " + String(b.get("text", "")) + "\n"
	return s


func _test_compass() -> void:
	Profile.reset_all()
	Profile.runs_done = 3
	Profile.seen_gear = [1]
	Profile.records["epochs_cleared"] = 1
	_set_level(40)
	var t := Compass.map_for_hero()
	check("A8 : carte de la Survie pour un héros 40 (époque II fermée sauf la I gagnée : %s)" % t, t.x <= Epochs.unlocked() and Epochs.band(t.x, t.y).x <= 40)
	var a := Compass.advice()
	if String(a.get("id", "")) == "find_piece":
		check("A8 : « il te manque … → Survie, carte X » (%s)" % a.text, String(a.text).contains("carte %s" % GearShopPage.tier_code(t.x, t.y)))
	else:
		check("A8 : conseil d'équipement attendu (%s)" % a.get("id", "?"), String(a.get("id", "")) in ["find_piece", "start_gear", "equip_spare", "buy_piece", "goal"])


func _test_defeat() -> void:
	Run.active = true
	Run.survival = true
	Run.survivor = false
	Run.epoch = 1
	Run.result = "defaite"
	HitLog.reset()
	var hero := Player.new()
	hero.max_hp = 100.0
	hero.hp = 0.0
	HitLog.note(hero, 60.0, null)
	var rs := ResultsScreen.new()
	var spec := rs.spec()
	check("H6 : bilan de la Survie perdue : « Ce qui t'a battu »", spec.has("defeat") and not (spec.defeat as Dictionary).is_empty())
	Run.result = "victoire"
	check("H6 : victoire : pas de bloc de défaite", not rs.spec().has("defeat"))
	rs.free()
	hero.free()
	HitLog.reset()
	Run.active = false
	Run.survival = false


func _test_tower() -> void:
	Profile.reset_all()
	_set_level(20)
	Tower.start("warrior", 1, 1)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(5.0).timeout
	var td: TowerDirector = world.director.tower
	world.player.dev_invincible = true
	world.cards._queue.clear()
	world.cards._show_next()
	var f := 81  # niveau 41
	td.begin(f)
	await get_tree().create_timer(0.5).timeout
	check("H5 : Tour, étage %d (niveau %d), héros 20 : il s'y bat au niveau 20 (%d / %d)" % [f, Tower.level_for(f), Run.hero_level, world.player.level],
		Run.hero_level == 20 and world.player.level == 20 and Tower.level_for(f) > 20)
	await get_tree().create_timer(1.5).timeout
	var mons: Array = get_tree().get_nodes_in_group("monsters").filter(func(m): return not m.is_dead)
	check("H5 : les monstres gardent le niveau de l'étage", mons.is_empty() or mons.all(func(m): return int(m.level) >= Tower.level_for(f)))
	_set_level(90)
	td.begin(f + 1)
	await get_tree().create_timer(0.5).timeout
	check("H5 : héros 90 : niveau de l'étage, comme avant (%d)" % Run.hero_level, Run.hero_level == Tower.level_for(f + 1))
	world.queue_free()
	Tower.finish()
	await get_tree().create_timer(0.5).timeout
