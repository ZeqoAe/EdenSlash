extends Node
## Systèmes de build : combo d'auto-attaque, effets déclenchés (procs), sets
## d'équipement, cartes roguelite (raretés, évolutions, relances), plafond de niveau.
## godot --headless --path game res://tests/test_build.tscn  (profil de test uniquement)

var fails := 0
var world: Node
var player: Player


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Profile.reset_all()
	Profile.selected_class = "samurai"  # combo du katana (on démarre Guerrier sinon)
	Profile.save_profile()
	Run.start("samurai")
	_test_sets()
	_test_cards()
	_test_ban_keep()
	await _test_world()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_sets() -> void:
	var pieces: Array = []
	for slot in ["head", "chest", "legs", "gloves"]:
		var it := Items.generate(10, 1.0, slot, "samurai", 2)
		Items.make_set_piece(it, "storm")
		pieces.append(it)
	check("pièce de set : nom", String(pieces[0].name).ends_with("de la Tempête"))
	var eq := {"head": pieces[0], "chest": pieces[1]}
	check("2 pièces : 1 bonus actif", Items.active_set_bonuses(eq).size() == 1)
	for i in 4:
		Profile.equipped[pieces[i].slot] = pieces[i]
	var b := Items.active_set_bonuses(Profile.equipped)
	check("4 pièces : bonus 2 et 4 actifs", b.size() == 2)
	check("stats de set ajoutées à l'équipement", Profile.equipment_stats().get("atk_speed", 0.0) >= 0.08)
	check("proc de set (foudre) actif", Profile.equipment_procs().filter(func(p): return p.effect == "lightning").size() == 1)
	check("infobulle : bonus de set", Items.describe(pieces[0]).contains("4 pièces"))
	var n_sets := 0
	for i in 200:
		if Items.generate(5, 0.5, "", "samurai", Items.MYTHIC, "", Items.MYTHIC).has("set"):
			n_sets += 1
	check("pièces de set d'Eden sur les mythiques (boss) : %d / 200" % n_sets, n_sets > 10)
	check("pas de set sur le butin courant", range(200).all(func(_i): return not Items.generate(5, 1.0).has("set")))
	for i in 4:
		Profile.equipped.erase(pieces[i].slot)


func _test_cards() -> void:
	var ids := {}
	for i in 300:
		for c in Run.roll_cards(3):
			ids[str(c.id)] = c
	check("cartes de build proposées", ids.has("static_blade") and ids.has("wide_arc"))
	check("évolution absente sans prérequis", not ids.has("storm_lord"))
	check("carte verrouillée (méta-progression) : 2 boss pour Seigneur de la tempête", not Cards.card_unlocked("storm_lord") and Cards.card_unlocked("wide_arc"))
	Profile.unlocked_cards.append("storm_lord")
	Run.apply_card(_common_card("static_blade"))
	var found := false
	for i in 300:
		for c in Run.roll_cards(3):
			found = found or str(c.id) == "storm_lord"
	check("évolution proposée avec son prérequis", found)
	check("carte de base rare, rareté tirée à l'offre", Run.passive_def("static_blade").rarity == "rare" and Run._describe_card({"type": "passive", "id": "static_blade"}).has("tier"))
	check("1 relance par run", Run.rerolls_left() == 1)
	Run.apply_card(_common_card("fortune"))
	check("Bonne étoile : +1 relance", Run.rerolls_left() == 2)
	Run.apply_card(_common_card("static_blade"))
	var p: Dictionary = Run.passive_procs().filter(func(x): return x.id == "static_blade_0")[0]
	check("proc cumulé (2 cartes) : plus de chances et de rebonds", is_equal_approx(float(p.chance), 0.5) and int(p.chain) == 4)
	Run.passives.clear()


func _test_world() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	player = world.player
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.director.set_physics_process(false)
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.3).timeout

	# plafond de niveau de la map 1
	check("butin plafonné au niveau 15", world.director.loot_level(40) == 15 and world.director.max_level() == 15)
	player.level = 40
	check("monstres plafonnés (hors rage)", world.director._monster_level(2) == 15)
	player.level = 1

	# combo : 3 coups enchaînés, le 3e en saut et en zone
	var m := _dummy(1.8)
	player._start_attack(m.global_position)
	check("combo : 1er coup", player.combo_state() == Vector2i(1, 3) and not player._action.get("finisher", false))
	await _wait_idle()
	player._start_attack(m.global_position)
	check("combo : 2e coup", player.combo_state().x == 2)
	await _wait_idle()
	player._start_attack(m.global_position)
	check("combo : coup final en saut et en zone", player._action.get("finisher", false) and player.velocity.y > 0.0 and float(player._action.arc) == 360.0)
	await _wait_idle()
	await get_tree().create_timer(player.combo_window + 0.2).timeout
	player._start_attack(m.global_position)
	check("combo : repart du début après une pause", player.combo_state().x == 1)
	await _wait_idle()

	# zone et portée
	var sk: Dictionary = Run.class_data().skills[1]  # tourbillon (cercle)
	var r0 := player.skill_radius(sk)
	Run.apply_card(_common_card("wide_arc"))
	check("Lame large : rayon des zones +15 %", is_equal_approx(player.skill_radius(sk), r0 * 1.15))

	# procs : foudre en chaîne
	var pack: Array = [_dummy(3.0, 0.0), _dummy(4.5, 0.6), _dummy(6.0, -0.6)]
	var hp0 := pack.map(func(x): return x.hp)
	Procs.run(player, {"effect": "lightning", "mult": 1.0, "chain": 3, "radius": 7.0}, pack[0], pack[0].global_position)
	var struck := 0
	for i in pack.size():
		if pack[i].hp < hp0[i]:
			struck += 1
	check("foudre : rebondit sur les 3 monstres", struck == 3 and pack[1].has_status("shock"))
	# gel : immobilise et annule l'attaque annoncée
	Procs.run(player, {"effect": "freeze", "duration": 1.5, "radius": 2.0}, pack[2], pack[2].global_position)
	check("gel appliqué", pack[2].has_status("freeze") and pack[2].is_disabled())
	# explosion à la mort (Cadavres explosifs), avec recharge interne
	# l'or du monstre tué recalcule les stats (et donc les procs, venus des cartes et
	# de l'équipement) : on garde ici un proc de test injecté à la main
	Profile.changed.disconnect(player._on_profile_changed)
	player.procs = [{"id": "t_volatile", "trigger": "kill", "chance": 1.0, "cd": 0.0, "effect": "explosion", "mult": 0.5, "radius": 4.0}]
	var victim := _dummy(3.0, 0.0, 1.0)
	victim.xp_reward = 0  # pas de passage de niveau (il recalculerait les procs)
	var near_hp: float = pack[1].hp
	player.proc_hit(victim, 1.0)
	check("explosion à la mort touche les voisins", victim.is_dead and pack[1].hp < near_hp)
	Profile.changed.connect(player._on_profile_changed)
	# exécution des monstres normaux
	player.recalc_stats()
	player.execute = 0.2
	var weak := _dummy(2.0, 0.0, 1000.0)
	weak.hp = 150.0
	player._hit_monster(weak, Vector3.FORWARD, {"mult": 0.01}, false)
	check("Exécuteur : monstre faible exécuté", weak.is_dead)
	player.execute = 0.0
	# Écho : la compétence frappe une 2e fois
	var echo_target := _dummy(2.0, 0.0)
	player._last_skill = {"action": {"mult": 1.0, "radius": 4.0, "arc": 360.0, "kind": "spin"}, "pos": player.global_position, "fwd": player.forward()}
	var before := echo_target.hp
	player.echo_last_skill(0.6)
	await get_tree().create_timer(0.4).timeout
	check("Écho : seconde frappe", echo_target.hp < before)
	# buff temporaire d'un proc
	var spd := player.atk_speed
	Procs.run(player, {"effect": "buff", "status": "frenzy", "duration": 2.0}, null, player.global_position)
	check("Frénésie : +30 % de vitesse d'attaque", is_equal_approx(player.atk_speed, spd + 0.3))
	# déclencheur avec recharge interne
	player.procs = [{"id": "t_cd", "trigger": "dodge", "chance": 1.0, "cd": 5.0, "effect": "buff", "status": "haste", "duration": 1.0}]
	Procs.fire(player, "dodge")
	player.statuses.erase("haste")
	Procs.fire(player, "dodge")
	check("recharge interne respectée", not player.has_status("haste"))
	# trophées : buff sous condition (stats temporaires), double frappe
	for st in Trophies.STATUSES:
		player.statuses.erase(st)
	player.recalc_stats()
	var agi0 := float(player.attrs.agi)
	var crit0 := player.crit
	var tp := Trophies.proc_for("agi", Items.LEGENDARY)
	Procs.run(player, tp, null, player.global_position)
	check("trophée Vivacité : +%d %% d'Agilité pendant %d s" % [roundi(float(tp.stats.agi_pct) * 100), roundi(float(tp.duration))],
		player.has_status("t_agi") and float(player.attrs.agi) > agi0 * 1.2)
	var crit1 := player.crit
	var cd0 := player.crit_dmg
	Procs.run(player, Trophies.proc_for("crit", 3), null, player.global_position)
	check("trophée Instinct : critique et dégâts critiques", player.crit > crit1 + 0.1 and player.crit_dmg > cd0 + 0.2)
	player.statuses.erase("t_agi")
	player.statuses.erase("t_crit")
	player.recalc_stats()
	check("buffs de trophée retirés à la fin", is_equal_approx(float(player.attrs.agi), agi0) and is_equal_approx(player.crit, crit0))
	var dbl := _dummy(2.0, 0.0)
	var hp_before := dbl.hp
	Procs.run(player, Trophies.proc_for("double", 2), dbl, dbl.global_position)
	check("trophée Double frappe : coup supplémentaire", dbl.hp < hp_before)
	check("rareté : buff plus fort sur un légendaire", float(Trophies.proc_for("agi", Items.LEGENDARY).stats.agi_pct) > float(Trophies.proc_for("agi", 2).stats.agi_pct)
		and float(Trophies.proc_for("agi", Items.LEGENDARY).chance) > float(Trophies.proc_for("agi", 0).chance))
	Run.passives.clear()
	player.recalc_stats()
	await _test_card_tiers()
	world.queue_free()


func _wait_idle() -> void:
	for i in 120:
		await get_tree().physics_frame
		if player._state == "idle":
			return


## Monstre immobile et inoffensif à [param dist] m devant le héros.
func _dummy(dist: float, side := 0.0, hp := 1e7) -> Monster:
	var id: int = world.director._pick_monster(1)
	var fwd := player.forward()
	var pos := player.global_position + fwd * dist + fwd.cross(Vector3.UP) * side * dist
	var m: Monster = world.director._spawn_monster(id, pos, 1)
	m.max_hp = hp
	m.hp = hp
	m.set_physics_process(false)
	m.set_process(false)
	return m


## Cartes à rareté, 10 niveaux, totaux cumulés, sorts améliorés, orbes d'expérience.
func _test_card_tiers() -> void:
	Run.passives.clear()
	Run.passive_power.clear()
	var c := _common_card("sharpened")
	c["tier"] = "legendary"
	c["mult"] = Cards.tier_mult("legendary")
	Run.apply_card(c)
	check("carte légendaire : ×3 (+24 % de dégâts)", is_equal_approx(float(Run.passive_stats().get("dmg_pct", 0.0)), 0.24))
	var next := Run._describe_card({"type": "passive", "id": "sharpened"})
	check("carte suivante : total avant → après (« +24 % → »)", String(next.desc).contains("+24 % →") and String(next.subtitle).contains("niv. 1 → 2"))
	for i in 9:
		Run.apply_card(_common_card("sharpened"))
	check("passif au niveau 10 : plus proposé", Run.roll_cards(3).all(func(x): return str(x.id) != "sharpened") and int(Run.passives.sharpened) == 10)
	# sort de soin amélioré : plus de soins, pas seulement moins de recharge
	var heal_skill := {"id": 9001, "kind": "heal", "heal": 0.3, "cooldown": 10}
	var up := Cards.skill_upgrade(heal_skill, "epic")
	check("amélioration d'un sort de soin : +33 % de soins et -11 % de recharge (épique)", is_equal_approx(float(up.heal), 0.33) and is_equal_approx(float(up.cd), 0.11) and not up.has("dmg"))
	Run.skills.append({"id": 9001, "rank": 1})
	up["rider"] = {"stat": "int", "value": 0.2, "duration": 6.0}
	Run.apply_card({"type": "upgrade", "id": 9001, "up": up})
	check("sort amélioré : soins x1,33, bonus d'Intelligence au lancement", is_equal_approx(Run.skill_heal_mult(9001), 1.33) and Run.skill_riders(9001).size() == 1 and int(Run.skill_entry(9001).rank) == 2)
	Run.skills.pop_back()
	# effets sur la durée plus longs (Venin tenace)
	Run.apply_card(_common_card("lingering"))
	player.recalc_stats()
	var mob := Monster.new()
	mob.configure(GameData.monster(GameData.zone("limestone").monsters[0]))
	add_child(mob)
	mob.add_status("poison", 4.0, player)
	check("Venin tenace : poison 4 s -> 4,6 s", is_equal_approx(float(mob.statuses.poison) - mob.clock, 4.6))
	mob.queue_free()
	# orbes d'expérience : lâchées au sol, ramassées dans la zone de collecte, Rappel
	var orbs := XpOrbs.new()
	add_child(orbs)
	var xp0 := player.xp
	var lvl0 := player.level
	orbs.spawn(player.global_position + Vector3(30, 0, 0), 5.0)
	orbs.spawn(player.global_position + Vector3(1, 0, 0), 5.0)
	player.autoplay = false
	await get_tree().create_timer(0.6).timeout
	check("orbe proche ramassée, orbe lointaine restée au sol", orbs.count() == 1 and (player.xp > xp0 or player.level > lvl0))
	orbs.recall()
	await get_tree().create_timer(1.5).timeout
	check("Rappel : l'orbe lointaine revient", orbs.count() == 0)
	orbs.queue_free()
	Run.passives.clear()
	Run.passive_power.clear()
	player.recalc_stats()


## Bannir et garder des cartes pendant le choix.
func _test_ban_keep() -> void:
	Run.banned.clear()
	Run.kept.clear()
	Run.bans_used = 0
	Run.locks_used = 0
	var shown: Array = [Run._describe_card({"type": "passive", "id": "sharpened"})]
	var rep := Run.ban_card(shown[0], shown)
	check("bannir : carte remplacée, plus jamais proposée", not rep.is_empty() and str(rep.id) != "sharpened"
		and range(100).all(func(_i): return Run.roll_cards(3).all(func(x): return str(x.id) != "sharpened")))
	var k := Run._describe_card({"type": "passive", "id": "long_reach"})
	k["tier"] = "epic"
	check("garder : la carte revient au choix suivant avec sa rareté", Run.keep_card(k) and Run.roll_cards(3).any(func(x): return str(x.id) == "long_reach" and String(x.tier) == "epic"))
	Run.banned.clear()


## Carte de passif tirée en rareté commune (puissance +1), pour des tests déterministes.
func _common_card(id: String) -> Dictionary:
	var c := Run._describe_card({"type": "passive", "id": id})
	c["tier"] = "common"
	c["mult"] = 1.0
	return c
