extends Node
## Lot H1 : niveau de héros permanent (1 → 90, compte). Courbe (105 × 1,035^L), XP selon l'écart de niveau (×0,1 à ×3),
## gains seulement en Survie / Donjons / Tour / Ruée / Siège (jamais en Survivant, Battle royale, Duel, Défi du jour),
## +20 % à la victoire, versement au bilan (Quests.end_run) et ligne du bilan, migration de profils types (idempotente,
## aucune pièce portée au-dessus du niveau), persistance par la sauvegarde (SafeFile), jauge du lobby.
## godot --headless --path game res://tests/test_h1.tscn

const PATH := "user://h1_legacy.json"

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = false
	Settings.reset_all()
	Profile.reset_all()
	_test_curve()
	_test_gap()
	_test_modes()
	await _test_monster()
	_test_results()
	_test_persist()
	_test_migration()
	await _test_gauge()
	Modes.forced = ""
	Challenge.active = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _test_curve() -> void:
	check("besoin du niveau 10 : 148 (105 × 1,035^10)", is_equal_approx(HeroLevel.need(10), 148.0))
	check("besoin du niveau 43 : ≈ 462", absf(HeroLevel.need(43) - 462.0) <= 1.0)
	check("besoin du niveau 89 : ≈ 2 240", absf(HeroLevel.need(89) - 2240.0) <= 5.0)
	check("niveau 90 : plus rien à gagner", HeroLevel.need(90) == 0.0)
	var ok := true
	for lv in range(1, HeroLevel.MAX_LEVEL + 1):
		var t := HeroLevel.total_for(lv)
		if HeroLevel.level_for(t) != lv or (lv > 1 and HeroLevel.level_for(t - 1.0) != lv - 1):
			ok = false
	check("niveau ⇄ XP totale exacts de 1 à 90", ok)
	check("XP totale du niveau 1 : 0", HeroLevel.total_for(1) == 0.0)
	var t90 := HeroLevel.total_for(90)
	check("niveau 90 ≈ 63 000 monstres de son niveau (%d)" % roundi(t90), t90 > 55000.0 and t90 < 70000.0)
	check("au-delà de 90 : plafond", HeroLevel.level_for(t90 * 3.0) == 90)
	Profile.reset_all()
	check("compte neuf : niveau 1, 0 XP", HeroLevel.level() == 1 and HeroLevel.total() == 0.0 and HeroLevel.xp_left() == HeroLevel.need(1))
	HeroLevel.add_xp(HeroLevel.total_for(90) * 2.0)
	check("XP plafonnée au niveau 90, barre pleine", HeroLevel.level() == 90 and HeroLevel.total() == t90 and HeroLevel.progress() == 1.0 and HeroLevel.xp_left() == 0.0)
	check("au niveau 90, plus d'XP ajoutée", HeroLevel.add_xp(500.0) == 0.0)


func _test_gap() -> void:
	check("monstre de son niveau : 1 (élite 4, boss 8)", HeroLevel.kill_xp(30, 30) == 1.0 and HeroLevel.kill_xp(30, 30, true) == 4.0
		and HeroLevel.kill_xp(30, 30, false, true) == 8.0)
	check("10 niveaux au-dessus : ×2,6", absf(HeroLevel.kill_xp(40, 30) - 2.594) < 0.01)
	check("10 niveaux en dessous : ×0,39", absf(HeroLevel.kill_xp(20, 30) - 0.3855) < 0.01)
	check("borne haute ×3", HeroLevel.kill_xp(80, 30) == 3.0 and HeroLevel.kill_xp(80, 30, false, true) == 24.0)
	check("borne basse ×0,1", is_equal_approx(HeroLevel.kill_xp(1, 60), 0.1))


## Tue [param n] monstres de niveau [param lv] (+ un boss) dans le mode [param mode] puis verse au bilan [param act].
func _play(mode: String, act: String, won: bool, n := 10, lv := -1, boss := true, challenge := false, killer: Combatant = null) -> Dictionary:
	Modes.forced = mode
	Challenge.active = challenge
	Run.started_at += 1000  # une nouvelle partie
	var hl := HeroLevel.level()
	var mobs: Array = []
	for i in n + (1 if boss else 0):
		var m := Monster.new()
		m.level = hl if lv < 0 else lv
		m.is_boss = boss and i == n
		mobs.append(m)
		HeroLevel.on_kill(m, killer)
	for m in mobs:
		m.free()
	var r := HeroLevel.settle(act, won)
	Modes.forced = ""
	Challenge.active = false
	return r


func _test_modes() -> void:
	Profile.reset_all()
	var t0 := HeroLevel.total()
	var r := _play("survival", "survival", false)
	check("Survie perdue : 10 monstres + 1 boss de son niveau = 18 XP", int(r.get("xp", 0)) == 18 and HeroLevel.total() == t0 + 18.0)
	r = _play("survival", "survival", true)
	check("Survie gagnée : +20 % (22)", int(r.get("xp", 0)) == 22)
	for m in [["tower", "tower"], ["dungeon", "dungeon"], ["dungeon", "rush"], ["dungeon", "siege"]]:
		r = _play(String(m[0]), String(m[1]), false)
		check("%s : XP de héros gagnée" % m[1], float(r.get("xp", 0)) > 0.0)
	var before := HeroLevel.total()
	for m in [["survivor", "survivor"], ["royale", "royale"], ["duel", "duel"], ["duel", "arenas"], ["training", "survival"], ["menu", "survival"]]:
		r = _play(String(m[0]), String(m[1]), true)
		check("%s (%s) : aucune XP de héros" % [m[1], m[0]], r.is_empty() and HeroLevel.pending == 0.0)
	r = _play("survival", "survival", true, 10, -1, true, true)
	check("Défi du jour : aucune XP de héros", r.is_empty())
	var foe := Monster.new()
	foe.team = Combatant.Team.MONSTER
	r = _play("survival", "survival", false, 10, -1, true, false, foe)
	foe.free()
	check("monstre abattu par un autre monstre : rien", float(r.get("xp", 0)) == 0.0)
	check("aucun gain hors progression", HeroLevel.total() == before)
	# l'XP d'une partie abandonnée sans bilan ne passe pas à la suivante
	Modes.forced = "survival"
	Run.started_at += 1000
	var m1 := Monster.new()
	m1.level = HeroLevel.level()
	HeroLevel.on_kill(m1, null)
	Run.started_at += 1000  # partie suivante, sans bilan entre les deux
	HeroLevel.on_kill(m1, null)
	m1.free()
	r = HeroLevel.settle("survival", false)
	Modes.forced = ""
	check("XP d'une partie sans bilan oubliée (1, pas 2)", int(r.get("xp", 0)) == 1)
	# versement par le bus de fin de partie (Quests.end_run)
	Modes.forced = "dungeon"
	Run.started_at += 1000
	var t1 := HeroLevel.total()
	var mb := Monster.new()
	mb.level = HeroLevel.level() + 10
	mb.is_boss = true
	HeroLevel.on_kill(mb, null)
	mb.free()
	Modes.forced = ""
	Quests.end_run("dungeon", true, {})
	check("Quests.end_run verse l'XP (boss +10 niveaux, victoire : 8 × 2,59 × 1,2 = 25)", HeroLevel.total() == t1 + 25.0)
	Quests.end_run("duel", true, {})
	check("un duel ensuite efface le dernier versement (pas de ligne au bilan)", HeroLevel.last.is_empty())


## Un vrai monstre de la Survie, tué dans l'arbre de scène : Monster._on_death compte l'XP.
func _test_monster() -> void:
	Profile.reset_all()
	Modes.forced = "survival"
	Run.started_at += 1000
	var mob := Monster.new()
	mob.configure(GameData.monster(GameData.zone("limestone").monsters[0]), false, 1)
	add_child(mob)
	await get_tree().process_frame
	mob.take_damage(mob.max_hp * 100.0, null)
	check("monstre tué en Survie : XP en attente du bilan", mob.is_dead and HeroLevel.pending > 0.0)
	var r := HeroLevel.settle("survival", false)
	check("versée au bilan", float(r.get("xp", 0)) >= 1.0 and HeroLevel.total() >= 1.0)
	Modes.forced = "royale"
	Run.started_at += 1000
	var mob2 := Monster.new()
	mob2.configure(GameData.monster(GameData.zone("limestone").monsters[0]), false, 1)
	add_child(mob2)
	await get_tree().process_frame
	mob2.take_damage(mob2.max_hp * 100.0, null)
	check("monstre tué en Battle royale : rien", mob2.is_dead and HeroLevel.pending == 0.0)
	Modes.forced = ""
	mob.queue_free()
	mob2.queue_free()


func _test_results() -> void:
	Profile.reset_all()
	var ups := []
	var cb := func(a: int, b: int): ups.append([a, b])
	HeroLevel.events.level_up.connect(cb)
	var r := _play("survival", "survival", true, 400)
	HeroLevel.events.level_up.disconnect(cb)
	check("400 monstres du niveau 1 : montée de niveau (%d → %d)" % [int(r.get("from", 0)), int(r.get("to", 0))], int(r.get("to", 0)) > int(r.get("from", 0)))
	check("signal de montée de niveau", ups.size() == 1 and int(ups[0][0]) == int(r.from) and int(ups[0][1]) == int(r.to))
	var spec := HeroLevel.decorate({"title": "VICTOIRE !", "gained": [ResultsPanel.row("Maîtrise", "+15")]})
	var row: Dictionary = (spec.gained as Array)[0]
	var up := int(r.to) - int(r.from)
	check("bilan : « Niveau de héros %d → %d » « +%d niveau(x) » en tête du bloc Gagné" % [int(r.from), int(r.to), up],
		String(row.text) == "Niveau de héros %d → %d" % [int(r.from), int(r.to)] and String(row.value).begins_with("+%d niveau" % up) and (spec.gained as Array).size() == 2)
	check("message sobre de montée : « Ton héros passe au niveau %d. »" % int(r.to), (spec.get("notes", []) as Array).has("Ton héros passe au niveau %d." % int(r.to)))
	check("la ligne ne s'ajoute qu'une fois", (HeroLevel.decorate({"gained": []}).gained as Array).is_empty())
	r = _play("tower", "tower", false, 3, -1, false)
	var s2 := HeroLevel.decorate({})
	check("sans montée : « XP de héros +3 », aucune annonce", String((s2.gained as Array)[0].value) == "+3" and String((s2.gained as Array)[0].text) == "XP de héros"
		and (s2.get("notes", []) as Array).is_empty())
	_play("survivor", "survivor", true)
	check("Survivant : rien au bilan", not HeroLevel.decorate({}).has("gained"))
	# vrai bilan affiché
	_play("survival", "survival", true, 5)
	var panel := ResultsPanel.new()
	add_child(panel)
	panel.show_spec({"title": "DÉFAITE", "tone": "lose", "gained": [], "buttons": []})
	var found := false
	for l in panel.find_children("*", "Label", true, false):
		if (l as Label).text == "XP de héros":
			found = true
	check("le bilan montre la ligne « XP de héros »", found)
	get_tree().paused = false
	panel.queue_free()


func _test_persist() -> void:
	Profile.reset_all()
	Profile.save_path = PATH
	HeroLevel.ensure()
	HeroLevel.add_xp(HeroLevel.total_for(37) + 55.0)
	var t := HeroLevel.total()
	Profile.save_profile()
	Profile._clear()
	Profile.load_profile()
	check("niveau et XP relus après sauvegarde (niveau 37)", HeroLevel.total() == t and HeroLevel.level() == 37)
	var f := FileAccess.get_file_as_string(PATH)
	check("dans le fichier de sauvegarde (records.hero_xp)", f.contains("\"hero_xp\""))
	# fin de Tour / donjon : la sauvegarde est rechargée en gardant les records
	HeroLevel.add_xp(100.0)
	var t2 := HeroLevel.total()
	Profile.reload_keep_records()
	check("rechargement de fin de partie : l'XP gagnée reste", HeroLevel.total() == t2)


## Profils types d'avant le lot H1 : niveau de départ attendu, aucune pièce déséquipée, migration idempotente.
func _test_migration() -> void:
	_load({"selected_class": "warrior", "runs_done": 0})
	check("compte neuf : niveau 1, pas de message (pièces de départ exclues)", HeroLevel.level() == 1 and HeroLevel.take_note() == ""
		and not Profile.equipped.is_empty())
	_load({"selected_class": "warrior", "runs_done": 12, "best_level": 22})
	check("aucune époque gagnée, meilleur niveau 22 : niveau 22", HeroLevel.level() == 22)
	_load({"selected_class": "warrior", "runs_done": 30, "best_level": 60})
	check("aucune époque gagnée, meilleur niveau 60 : plafonné à 35", HeroLevel.level() == 35)
	for c in [[1, 43], [2, 60], [3, 75], [4, 85]]:
		_load({"selected_class": "warrior", "best_level": 35, "records": {"epochs_cleared": c[0]}})
		check("%d époque(s) gagnée(s) : niveau %d" % c, HeroLevel.level() == int(c[1]))
	_load({"selected_class": "warrior", "best_level": 35, "records": {"epochs_cleared": 4, "heroic_best_1": 2, "heroic_best_3": 3}})
	check("époque IV + 3 rangs héroïques : niveau 88", HeroLevel.level() == 88)
	_load({"selected_class": "warrior", "best_level": 35, "records": {"epochs_cleared": 2, "dungeon_limestone_2": 1}})
	check("donjon Mythique fini : niveau 90", HeroLevel.level() == 90)
	# pièce portée au-dessus du barème (époque I gagnée, plastron de niveau ≥ 60 porté par le Mage)
	var e := _eden("chest", 60)
	var it := Items.from_template(e, int(e.level))
	it["uid"] = "h1_chest"
	var sword := Items.from_template(_eden(Items.default_weapon_type("warrior"), 1), 1)
	sword["uid"] = "h1_sword"
	_load({"selected_class": "warrior", "best_level": 35, "records": {"epochs_cleared": 1}, "vault": [it, sword],
		"presets": {"magician": {"active": 1, "sets": [{"name": "A", "slots": {}}, {"name": "B", "slots": {"chest": "h1_chest"}}]},
			"warrior": {"active": 0, "sets": [{"name": "A", "slots": {"weapon": "h1_sword"}}]}}})
	var lv := HeroLevel.level()
	check("pièce portée de niveau %d (époque I gagnée) : niveau %d" % [int(e.level), mini(int(e.level), 90)], lv == maxi(43, mini(int(e.level), 90)))
	check("la pièce reste portée, aucune pièce portée au-dessus du niveau", Profile.presets.magician.sets[1].slots.get("chest", "") == "h1_chest"
		and HeroLevel.highest_worn() <= lv)
	check("message une seule fois", HeroLevel.take_note() == "Ton héros est niveau %d. Il garde ce niveau dans toutes les classes." % lv
		and HeroLevel.take_note() == "")
	var t := HeroLevel.total()
	HeroLevel.add_xp(50.0)
	Profile.records.erase("epochs_cleared")
	HeroLevel.ensure()
	check("migration idempotente (l'XP gagnée depuis reste, rien n'est recalculé)", HeroLevel.total() == t + 50.0 and int(Profile.records.hero_start) == lv)
	Profile.save_profile()
	Profile._clear()
	Profile.load_profile()
	check("relu : même niveau, message déjà vu", HeroLevel.total() == t + 50.0 and HeroLevel.take_note() == "")


func _eden(slot: String, min_level: int) -> Dictionary:
	var list: Array = GameData.eden_by_slot.get(slot, [])
	var best: Dictionary = {}
	for x in list:
		if int(x.level) >= min_level and not GameData.is_awakened(x) and (best.is_empty() or int(x.level) < int(best.level)):
			best = x
	return best if not best.is_empty() else list[0]


func _test_gauge() -> void:
	Profile.reset_all()
	HeroLevel.ensure()
	HeroLevel.add_xp(HeroLevel.total_for(12) + 40.0)
	var g := HeroLevelGauge.new()
	add_child(g)
	await get_tree().process_frame
	var lab := g.get_child(0) as Label
	var bar := g.get_child(1) as ProgressBar
	check("jauge : « Niv. 12 », barre entamée", lab.text == "Niv. 12" and bar.value > 0.0 and bar.value < 1.0)
	check("infobulle sans pourcentage", g.tooltip_text.begins_with("Niveau de héros 12 · 40 / ") and not g.tooltip_text.contains("%"))
	HeroLevel.add_xp(HeroLevel.need(12))
	check("la jauge suit un gain (signal)", lab.text == "Niv. 13")
	g.queue_free()


## Charge [param d] comme le fait load_slot (profil vidé, chargé, vue du hub, équipement de départ).
func _load(d: Dictionary) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	Profile.save_path = PATH
	Profile._clear()
	Profile.load_profile()
	Profile._lobby_view()
	Profile._ensure_starter()
