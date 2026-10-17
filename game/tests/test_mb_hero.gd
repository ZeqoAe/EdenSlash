extends Node
## Lot MB-D (Les Deux Voies, conception/benchmark/R_MB_D.md) : héros en partie.
## 1. Règles pures (MobaHero) : niveaux 1-12 par XP, déblocages (2-4 : 1er enchaînement au choix, 5 : ultime, 6-8 : 2e
##    enchaînement, 9 : celui de l'ultime), choix non bloquant et automatique, partage de l'XP et de l'or des sbires,
##    rattrapage, primes, aides, réapparition selon le niveau.
## 2. Partie réelle (world.tscn, toi + 7 IA) : état de chaque héros, 500 or et 2 potions au départ, sorts de départ ; niveau 5
##    = ultime (joueur : 4e case à sa recharge et sa puissance de partie ; IA : son ultime dans ses sorts) ; choix d'un
##    enchaînement ; fiche refaite (PV, attaque) ; or et XP d'un sbire achevé ; prime d'élimination (premier sang),
##    réapparition ; or et XP passifs ; rappel (6 s, coupé par un coup) ; boutique ouverte à la fontaine.
## godot --headless --path game res://tests/test_mb_hero.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_pure()
	await _world()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _pure() -> void:
	var h := MobaHero.new(null, 0, 0, "warrior")
	check("départ : niveau 1, 500 or, 2 potions de soin", h.level == 1 and is_equal_approx(h.gold, 500.0) and int(h.potions.heal) == 2)
	check("déblocages : 2-4 enchaînement, 5 ultime, 6-8 2e enchaînement, 9 celui de l'ultime, 10-12 rien",
		MobaHero.unlock_at(2) == "chain1" and MobaHero.unlock_at(4) == "chain1" and MobaHero.unlock_at(5) == "ult"
		and MobaHero.unlock_at(6) == "chain2" and MobaHero.unlock_at(8) == "chain2" and MobaHero.unlock_at(9) == "ult_chain"
		and MobaHero.unlock_at(10) == "" and MobaHero.unlock_at(12) == "")
	h.add_xp(MobaData.xp_to_next(1))
	check("120 XP : niveau 2, un choix en attente (le jeu continue)", h.level == 2 and h.pending == ["chain1"] and h.choice_options() == [0, 1, 2])
	check("choix : la case 2 reçoit son 1er enchaînement", h.choose(1) and h.chains == [0, 1, 0, 0] and h.pending.is_empty())
	check("choix refusé sans rien en attente", not h.choose(0))
	h.add_xp(float(MobaData.xp_total(5)) - h.xp)
	check("niveau 5 : ultime débloqué, deux choix encore en attente", h.level == 5 and h.ult and h.pending.size() == 2)
	check("le 1er enchaînement d'une case ne se prend qu'une fois", not 1 in h.choice_options() and h.choice_options() == [0, 2])
	h.choose(0)
	h.choose(2)
	var u := h.kit_unlocked()
	check("kit débloqué : 4 cases (ultime compris), 1 enchaînement par case", (u.mains as Array).size() == 4 and bool(u.ult_on)
		and (u.chains as Dictionary).size() == 3)
	h.add_xp(float(MobaData.xp_total(6)) - h.xp)
	check("niveau 6 : 2e enchaînement, seulement pour une case qui a son 1er", h.pending == ["chain2"] and h.choice_options() == [0, 1, 2])
	var a := MobaHero.new(null, 0, 0, "warrior")
	a.auto_pick = true
	a.prefer = [2, 0, 1]
	a.add_xp(float(MobaData.xp_total(MobaData.LEVEL_MAX)) + 999.0)
	check("XP au-delà du niveau 12 : niveau 12, XP bornée", a.level == MobaData.LEVEL_MAX and is_equal_approx(a.xp, float(MobaData.xp_total(MobaData.LEVEL_MAX))))
	check("choix automatique : tout débloqué dans l'ordre préféré (case 3 d'abord)", a.pending.is_empty() and a.chains == [2, 2, 2, 1]
		and a.picks.slice(0, 3) == [2, 0, 1])
	check("XP d'un sbire partagée : mêlée 30 → 15 chacun à deux", is_equal_approx(MobaHero.minion_xp_each("melee", 2), 15.0)
		and is_equal_approx(MobaHero.minion_xp_each("ram", 1), 60.0))
	check("or d'un sbire : 100 % au dernier coup, 60 % aux alliés proches, 50 % achevé par un sbire",
		is_equal_approx(MobaHero.minion_gold("melee", "last"), 20.0) and is_equal_approx(MobaHero.minion_gold("melee", "near"), 12.0)
		and is_equal_approx(MobaHero.minion_gold("melee", "stray"), 10.0))
	check("rattrapage : + 30 % sous la moyenne adverse de 2 niveaux", is_equal_approx(MobaHero.catchup(4.0, 6.0), 1.3)
		and is_equal_approx(MobaHero.catchup(5.0, 6.0), 1.0))
	check("primes : 300, premier sang + 100, série + 100 au-delà de 2, 700 au plus ; aide 150 partagée",
		MobaData.kill_bounty(0, false) == 300 and MobaData.kill_bounty(0, true) == 400 and MobaData.kill_bounty(4, false) == 500
		and MobaData.kill_bounty(20, true) == 700 and is_equal_approx(MobaHero.assist_gold(2), 75.0))
	check("réapparition : 5 + 2 × niveau, + 25 % dès 15:00, + 50 % dès 18:00", is_equal_approx(MobaData.respawn_time(1, 0.0), 7.0)
		and is_equal_approx(MobaData.respawn_time(12, 0.0), 29.0) and is_equal_approx(MobaData.respawn_time(10, 950.0), 31.25)
		and is_equal_approx(MobaData.respawn_time(10, 1100.0), 37.5))
	var v := MobaHero.new(null, 1, 0, "warrior")
	var k1 := Combatant.new()
	var k2 := Combatant.new()
	v.damagers = {k1: 10.0, k2: 18.0}
	check("aides : les héros qui l'ont frappé dans les 10 s ; crédit au dernier", v.assisters(21.0, null).size() == 1
		and v.last_damager(21.0) == k2 and v.assisters(27.0, k2).is_empty())
	k1.free()
	k2.free()


func _world() -> void:
	seed(77)
	Profile.selected_class = "warrior"
	Moba.launch("warrior", {"heroes": "all", "diff": 1, "seed": 77, "speed": 2.0})
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await _until(func(): return world.is_inside_tree() and world.get("director") != null and is_instance_valid(world.director.team), 900)
	var dd: MobaDirector = world.director.team as MobaDirector
	check("directeur des Deux Voies monté", dd != null)
	if dd == null:
		Moba.finish()
		return
	await _until(func(): return dd.map != null and dd.map.nav_ready(), 900)
	var p: Player = dd.player
	var ps: MobaHero = dd.info.get(p)
	check("8 héros, un état de partie chacun ; objets appliqués au joueur et aux IA (MobaItems actif)", dd.heroes.size() == 8
		and dd.info.size() == 8 and ps != null and ps.is_player and MobaItems.active)
	check("départ : niveau 1 (fiche de niveau 30), 500 or, 2 potions de soin", ps.level == 1 and p.level == 30
		and int(ps.gold) == 500 and Potions.count("heal") == 2)
	check("sorts de départ : les 3 cases principales du kit de partie", Run.skills.size() == 3 and Run.chains.is_empty())
	var hp1 := p.max_hp
	var atk1 := maxf(p.atk, p.matk)
	dd._xp(ps, float(MobaData.xp_total(5)) - ps.xp)
	for _i in 10:
		await get_tree().physics_frame
	check("niveau 5 : fiche de niveau 50, PV et attaque plus hauts", ps.level == 5 and p.level == 50 and p.max_hp > hp1 * 1.2
		and maxf(p.atk, p.matk) > atk1 * 1.2)
	var ult := int(MobaData.kit("warrior").ult.id)
	var ue: Dictionary = {}
	for s in Run.skills:
		if int(s.id) == ult:
			ue = s
	var base_cd := float(Run.skill_def(ult).cooldown)
	var got_cd := base_cd * Run.skill_cooldown_mult(ult)
	check("niveau 5 : l'ultime en 4e case, à sa recharge de partie (%d s) et sa puissance (× %.1f)" % [roundi(got_cd), Run.skill_damage_mult(ult)],
		Run.skills.size() == 4 and not ue.is_empty() and absf(got_cd - float(MobaData.kit("warrior").ult.cooldown)) < 0.6
		and is_equal_approx(Run.skill_damage_mult(ult), float(MobaData.kit("warrior").ult.power)))
	check("choix de niveau non bloquant : 3 enchaînements en attente, le jeu continue", ps.pending.size() == 3 and not get_tree().paused)
	check("Ctrl + 1 : la case 1 reçoit son 1er enchaînement", dd.choose_chain(p, 0) and (Run.chain_of(0) as Array).size() == 1
		and int(Run.chain_of(0)[0].id) == int(MobaData.kit("warrior").slots[0].chains[0]))
	# IA : niveau 5 → son ultime dans ses sorts, à sa recharge de partie
	var r: MobaRival = null
	for h in dd.heroes:
		if h is MobaRival and (h as MobaRival).side == 1:
			r = h
			break
	var rs: MobaHero = dd.info[r]
	var rhp := r.max_hp
	dd._xp(rs, float(MobaData.xp_total(5)) - rs.xp)
	for _i in 10:
		await get_tree().physics_frame
	var rult: Dictionary = {}
	for s in r._skills + r._support:
		if int(s.id) == r.ult_id:
			rult = s
	check("IA niveau 5 : ultime dans ses sorts (recharge 60-90 s), enchaînements choisis seuls, fiche plus forte",
		r.ult_on and not rult.is_empty() and float(rult.cooldown) >= 60.0 and float(rult.cooldown) <= 90.0 and rs.pending.is_empty()
		and r._skills.size() + r._support.size() >= 5 and r.max_hp > rhp * 1.2)
	# sbire achevé par le joueur : 100 % de l'or, XP partagée avec les héros proches
	await _until(func(): return dd.minions.any(func(m): return not m.is_dead and m.side == 1 and m.global_position.distance_to(dd.map.moba.fountains[0]) > 30.0), 60 * 90)
	var m: MobaMinion = null
	for x in dd.minions:
		if not x.is_dead and x.side == 1:
			m = x
			break
	check("un sbire rouge en jeu", m != null)
	if m != null:
		p.global_position = m.global_position + Vector3(0.5, 0.5, 0)
		for _i in 3:
			await get_tree().physics_frame
		var g0 := ps.gold
		var x0 := ps.xp
		var near := dd.units_near(0, m.global_position, MobaData.SHARE_RADIUS, MobaDirector.KIND_HERO).size()
		m.take_damage(m.max_hp * 50.0, p)
		var c := MobaHero.catchup(ps.level, dd.avg_level(1))
		check("sbire achevé : 100 %% de son or au joueur (%d) et sa part d'XP (%.0f)" % [roundi(ps.gold - g0), ps.xp - x0],
			m.is_dead and absf(ps.gold - g0 - MobaHero.minion_gold(m.kind, "last") * c) < 1.0
			and absf(ps.xp - x0 - MobaHero.minion_xp_each(m.kind, maxi(near, 1)) * c) < 1.0 and ps.cs == 1)
	# élimination : premier sang, réapparition selon le niveau de la victime
	var g1 := ps.gold
	var k0 := ps.kills
	var d0 := rs.deaths
	var bounty := MobaData.kill_bounty(rs.streak, not dd.first_blood)
	r.hp = 1.0
	r.take_damage(r.max_hp, p, false, true)
	await get_tree().physics_frame
	check("élimination : prime (%d or ; premier sang + 100), une élimination, réapparition selon le niveau (%.0f s)" % [bounty, rs.respawn_at - Moba.t],
		r.is_dead and absf(ps.gold - g1 - bounty) < 2.5 and ps.kills == k0 + 1 and rs.deaths == d0 + 1 and dd.first_blood
		and absf(rs.respawn_at - Moba.t - MobaData.respawn_time(rs.level, Moba.t)) < 0.2)
	await _until(func(): return not r.is_dead, 60 * 40)
	check("réapparition à la fontaine, PV pleins", not r.is_dead and is_equal_approx(r.hp, r.max_hp)
		and r.global_position.distance_to(dd.map.moba.fountains[1]) < 8.0)
	# or passif (à la fontaine : aucun sbire autour)
	p.global_position = dd.map.moba.fountains[0] + Vector3.UP * 0.5
	for _i in 3:
		await get_tree().physics_frame
	var g2 := ps.gold
	var t2 := Moba.t
	for _i in 60:
		await get_tree().physics_frame
	check("or passif : 2 par seconde (%.1f en %.1f s)" % [ps.gold - g2, Moba.t - t2], absf((ps.gold - g2) - 2.0 * (Moba.t - t2)) < 1.5)
	# rappel : 6 s sans bouger, coupé par un coup
	p.global_position = dd.map.lane_point(0, 1, 30.0) + Vector3.UP * 0.5
	for _i in 3:
		await get_tree().physics_frame
	check("loin de la fontaine : boutique fermée", not ps.in_shop and not MobaItems.shop_open(ps))
	check("rappel lancé", dd.start_recall(p) and ps.recalling())
	for _i in 30:
		await get_tree().physics_frame
	p.take_damage(10.0, null, false, true)
	check("un coup coupe le rappel", not ps.recalling())
	dd.start_recall(p)
	var t3 := Moba.t
	await _until(func(): return not ps.recalling(), 60 * 10)
	check("rappel : 6 s plus tard, à la fontaine (%.1f s), boutique ouverte" % (Moba.t - t3), Moba.t - t3 >= MobaData.RECALL_TIME - 0.1
		and p.global_position.distance_to(dd.map.moba.fountains[0]) < 8.0 and ps.in_shop and MobaItems.shop_open(ps))
	var hd := dd.hud_data()
	check("données d'affichage : niveau, XP, or, objets, K / M / A, cases, conseil, tableau des 8 héros", int(hd.level) == ps.level
		and hd.has("xp_next") and hd.has("items") and int(hd.kda[0]) >= 1 and (hd.slots as Array).size() == 4
		and not (hd.advice as Dictionary).is_empty() and (hd.board as Array).size() == 8)
	TeamMatch.end()
	Moba.reset()
	Engine.time_scale = 1.0
	world.queue_free()
	await get_tree().process_frame
	Run.active = false
	Profile.in_run = false
	check("après la partie : objets coupés (MobaItems inactif), rien de scellé", not MobaItems.active and Modes.current() == "menu")


func _until(cond: Callable, max_frames := 300) -> void:
	for _i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame
