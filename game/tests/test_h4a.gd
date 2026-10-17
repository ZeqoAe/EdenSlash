extends Node
## Lot H4a (NIVEAU_HEROS.md §1.4) : l'Aventure au niveau de héros, par bandes de niveau, sans plafond 35.
## Bandes et M′ des 12 cartes, monstres au niveau du héros borné par la bande, boss au niveau de la carte + 1 (PV fixes à ce
## niveau), héros aux stats de son niveau (fixe pendant la partie), niveau de run sans plafond qui ne donne que des cartes,
## pièces des coffres jamais au-dessus du niveau de héros (et portables pendant la partie), port vérifié en partie, autres
## modes inchangés : godot --headless --path game res://tests/test_h4a.tscn

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	_test_tables()
	_test_run_rules()
	_test_chests()
	_set_hero(1)
	Run.start_survival("warrior", 1)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.player.autoplay = false
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.3).timeout
	await _test_world()
	_test_other_modes()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().paused = false
	world.queue_free()
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(1 if fails > 0 else 0)


func _set_hero(lv: int) -> void:
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(lv)


## Bandes, M′, montée dans le temps, PV des boss, PE conseillée.
func _test_tables() -> void:
	var bands := [[1, 23], [18, 33], [28, 43], [38, 48], [43, 53], [48, 60], [55, 65], [60, 70], [65, 75], [70, 80], [75, 85], [80, 90]]
	var ok := true
	for ep in range(1, 5):
		for st in range(1, 4):
			var b := Epochs.band(ep, st)
			var want: Array = bands[(ep - 1) * 3 + st - 1]
			ok = ok and b.x == int(want[0]) and b.y == int(want[1]) and Epochs.map_mult(ep, st) > 0.0
	check("12 cartes : bandes du §1.4 (I-1 %s … IV-3 %s) et un M′ chacune" % [Epochs.band_text(1, 1), Epochs.band_text(4, 3)], ok)
	check("bande I-1 dès le niveau 1, IV-3 jusqu'au 90", Epochs.band(1, 1).x == 1 and Epochs.band(4, 3).y == HeroLevel.MAX_LEVEL)
	check("niveau de carte = niveau du héros borné (I-2 : %d / %d / %d pour 5 / 25 / 60)" % [Epochs.map_level(1, 2, 5), Epochs.map_level(1, 2, 25), Epochs.map_level(1, 2, 60)],
		Epochs.map_level(1, 2, 5) == 18 and Epochs.map_level(1, 2, 25) == 25 and Epochs.map_level(1, 2, 60) == 33)
	check("plus de plafond 15 / 25 / 35 dans le jeu (Epochs.OLD_CAPS : outils seulement)", not (load("res://scripts/core/epochs.gd") as Script).get_script_constant_map().has("CAPS"))
	check("montée dans le temps : ×1 au départ, croissante, bornée (×%.2f à 7 min)" % Epochs.time_ramp(420.0),
		is_equal_approx(Epochs.time_ramp(0.0), 1.0) and Epochs.time_ramp(420.0) > 1.0 and Epochs.time_ramp(1.0e6) <= Epochs.TIME_RAMP_MAX)
	var hp_lo := Epochs.boss_hp(1, 1, 2)
	var hp_hi := Epochs.boss_hp(1, 1, 24)
	check("PV du boss : suivent le niveau du boss (×1,1 par niveau : %.0f au niveau 2, %.0f au 24)" % [hp_lo, hp_hi],
		absf(hp_hi / hp_lo / pow(1.1, 22) - 1.0) < 0.001 and is_equal_approx(Epochs.boss_hp(1, 1), hp_hi))
	var mono := true
	for ep in range(1, 5):
		for st in range(1, 4):
			if st == 3 and Epochs.boss_hp(ep, st) <= Epochs.boss_hp(ep, 1):
				mono = false
			if ep > 1 and Epochs.boss_hp(ep, st) <= Epochs.boss_hp(ep - 1, st):
				mono = false
	check("PV des boss au sommet des bandes : croissants d'une époque à l'autre, 3e carte au-dessus de la 1re", mono)
	# lot H4b : dégâts du boss à part, réglages de mesure neutres en jeu, boss d'I-1 plus solide (1re run punitive)
	check("H4b : dégâts du boss = BOSS_ATK de la carte (%.3f en I-1), réglages de mesure neutres (--boss-atk-scale, --ranged)" % Epochs.map_atk(1, 1, true),
		is_equal_approx(Epochs.map_atk(1, 1, true), float(Epochs.BOSS_ATK[0][0])) and Epochs.test_boss_atk == 1.0 and not Run.test_ranged)
	check("H4b : boss d'I-1 plus solide que ses monstres (PV ×%.2f, dégâts ×%.2f)" % [float(Epochs.BOSS_HP_ADJ[0][0]), Epochs.map_atk(1, 1, true) / Epochs.map_atk(1, 1)],
		float(Epochs.BOSS_HP_ADJ[0][0]) > 1.0 and Epochs.map_atk(1, 1, true) > Epochs.map_atk(1, 1))
	check("PE conseillée : > 0, plus haute en haut de la bande (I-2 : %d au niveau 18, %d au 33)" % [Epochs.advised_power(1, 2, 1), Epochs.advised_power(1, 2, 90)],
		Epochs.advised_power(1, 1, 1) > 0 and Epochs.advised_power(1, 2, 90) > Epochs.advised_power(1, 2, 1))
	check("rang des gemmes : échelle d'avant (I-1 : %d à %d ; III-3 en haut : %d)" % [Epochs.gem_scale_level(1, 1, 1), Epochs.gem_scale_level(1, 1, 23), Epochs.gem_scale_level(3, 3, 90)],
		Epochs.gem_scale_level(1, 1, 1) == 1 and Epochs.gem_scale_level(1, 1, 23) == 15 and Epochs.gem_scale_level(3, 3, 90) == 35)


## La partie : niveau de héros fixé au départ, stats de base à ce niveau, niveau de run sans plafond.
func _test_run_rules() -> void:
	_set_hero(37)
	Run.start_survival("warrior", 1)
	check("Aventure : Epochs.adventure() et Run.hero_level = niveau de héros (%d)" % Run.hero_level, Epochs.adventure() and Run.hero_level == 37)
	var p := Player.new()
	add_child(p)
	p.set_physics_process(false)
	p.set_process(false)
	p.recalc_stats()
	var atk37 := p.atk
	var hp37 := p.max_hp
	check("héros niveau 37, niveau de run 1 : stats du niveau 37 (stat_level %d)" % p.stat_level(), p.stat_level() == 37 and p.level == 1)
	p.gain_xp(GameData.xp_to_next(1) * 4)
	var lv := p.level
	for i in 40:
		p.gain_xp(GameData.xp_to_next(p.level))
	check("niveau de run sans plafond par carte (%d → %d, plus de 15)" % [lv, p.level], p.level > 15 and p.level > lv)
	check("le niveau de run ne donne aucune stat (attaque %d / %d, PV %d / %d)" % [roundi(p.atk), roundi(atk37), roundi(p.max_hp), roundi(hp37)],
		is_equal_approx(p.atk, atk37) and is_equal_approx(p.max_hp, hp37) and Run.hero_level == 37)
	_set_hero(5)
	Run.start_survival("warrior", 1)
	p.level = 1
	p.recalc_stats()
	check("héros niveau 5 : moins fort que niveau 37 (attaque %d < %d)" % [roundi(p.atk), roundi(atk37)], p.atk < atk37 and Run.hero_level == 5)
	p.queue_free()
	Run.active = false
	Run.survival = false
	Profile.end_run_survival()


## Coffres d'emplacement : jamais au-dessus du niveau de héros ; portables en partie ; vraie pièce au-dessus du palier.
func _test_chests() -> void:
	_set_hero(1)
	Run.start_survival("warrior", 1)
	var all_ok := true
	var all_wear := true
	var seen_from := false
	for box in ["weapon", "head", "chest", "legs", "gloves", "boots", "back", "jewel"]:
		for it in SlotChests.offer(box, 1, 1, 3):
			all_ok = all_ok and Items.required_level(it) <= 1
			all_wear = all_wear and HeroLevel.can_wear(it)
			seen_from = seen_from or int(it.get("from_level", 0)) >= 20
	check("compte neuf (niveau 1), carte I-1 : pièces des coffres au niveau 1, palier d'origine gardé (from_level)", all_ok and seen_from)
	check("… et toutes portables pendant la partie (HeroLevel.wear_block sans exception de partie)", all_wear and Profile.in_run)
	var start := Profile.equipped.get("weapon", {}) as Dictionary
	var wpn: Dictionary = SlotChests.offer("weapon", 1, 1, 1)[0]
	Profile.add_item(wpn)
	check("compte neuf : l'arme d'un coffre s'équipe (%s)" % String(wpn.get("name", "?")), Profile.equip(wpn))
	check("puissance de la pièce ramenée : celle du niveau du héros (%d)" % Items.power_level(wpn), Items.power_level(wpn) == 1)
	var high := Items.from_template(SlotChests.pool("head", 2, 3)[0], 60, Items.MYTHIC)
	Profile.add_item(high)
	check("pièce du hub niveau %d : refusée pendant la partie au niveau 1" % Items.required_level(high), HeroLevel.wear_block(high) == Items.required_level(high) and not Profile.equip(high))
	check("pièces de départ : toujours portables", Items.required_level(start) == 0 or start.is_empty())
	Run.active = false
	Run.survival = false
	Profile.end_run_survival()
	_set_hero(60)
	Run.start_survival("warrior", 1)
	var it60: Dictionary = SlotChests.offer("head", 1, 1, 1)[0]
	check("héros niveau 60 sur I-1 : la vraie pièce du palier (niveau %d, sans from_level)" % int(it60.level), int(it60.level) == 23 and not it60.has("from_level"))
	_set_hero(28)
	Run.start_survival("warrior", 1)
	var it28: Dictionary = SlotChests.offer("head", 1, 2, 1)[0]
	check("héros niveau 28 sur I-2 (palier 33) : pièce au niveau 28 (%d)" % int(it28.level), int(it28.level) == 28)
	check("titre du coffre : « %s »" % Epochs.map_text(1, 2), Epochs.map_text(1, 2).begins_with("niveau 28"))
	Run.active = false
	Run.survival = false
	Profile.end_run_survival()


## Vraie carte : niveaux des monstres et du boss dans la bande, XP de run au niveau de run, butin plafonné.
func _test_world() -> void:
	var d: RunDirector = world.director
	var p: Player = world.player
	check("compte neuf : la carte I-1 démarre (héros niveau %d, run niveau %d)" % [Run.hero_level, p.level], Run.hero_level == 1 and p.level == 1 and Epochs.adventure())
	check("compte neuf : monstres au bas de la bande (niveau %d)" % d._monster_level(0), d._monster_level(0) == 1)
	Run.hero_level = 15
	p.recalc_stats()
	var lv := d._monster_level(0)
	check("héros 15 : monstres au niveau du héros − 1 au début (%d), boss %d" % [lv, d._boss_level()], lv == 14 and d._boss_level() == 16)
	Run.hero_level = 60
	check("héros 60 sur I-1 : monstres au haut de la bande (%d ≤ 23), boss 24, butin ≤ 23 (%d)" % [d._monster_level(0), d.loot_level(99)],
		d._monster_level(0) == 23 and d._boss_level() == 24 and d.loot_level(99) == 23)
	Run.hero_level = 10
	check("butin jamais au-dessus du niveau de héros (%d pour 10)" % d.loot_level(99), d.loot_level(99) == 10)
	var id := d._pick_monster(10)
	# (un monstre déjà créé : sans rôle tiré au hasard, qui changerait aussi l'XP)
	var m := d._spawn_monster(id, p.global_position + Vector3(30, 0, 0), 20, false, Monster.new())
	var m5 := d._spawn_monster(id, p.global_position + Vector3(-30, 0, 0), 5, false, Monster.new())
	check("XP de run : celle du niveau de run %d, pas du niveau de carte (même monstre niveau 20 / 5 : %d / %d)" % [p.level, m.xp_reward, m5.xp_reward],
		absf(float(m.xp_reward) / maxf(float(m5.xp_reward), 1.0) - 1.0) < 0.25)  # (±20 % : monstre de référence de GameData.monster_xp)
	m.queue_free()
	m5.queue_free()
	Run.hero_level = 1
	p.recalc_stats()
	await get_tree().process_frame
	d.debug_enter_dungeon()
	await get_tree().physics_frame
	var b: Monster = d._boss
	check("boss de I-1 pour un compte neuf : niveau 2, PV de la table à ce niveau (%.0f)" % b.max_hp,
		b.level == 2 and absf(b.max_hp / Epochs.boss_hp(1, 1, 2) - 1.0) < 0.01)


## Les autres modes gardent leurs règles : ni Survivant, ni Battle royale, ni Tour, ni Donjon ne sont l'Aventure.
func _test_other_modes() -> void:
	Survivor.active = true
	check("Survivant : pas l'Aventure (niveau de run = niveau de combat)", not Epochs.adventure())
	Survivor.active = false
	Royale.active = true
	check("Battle royale : pas l'Aventure", not Epochs.adventure())
	Royale.active = false
	var was := Run.survival
	Run.survival = false
	check("Tour, Donjons, Ruée, Siège (Run.survival faux) : pas l'Aventure", not Epochs.adventure())
	Run.survival = was
