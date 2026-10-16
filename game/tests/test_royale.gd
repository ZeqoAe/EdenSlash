extends Node
## Battle royale : chacun pour soi (Combatant.ffa_id), calendrier de l'anneau, récompenses, héros scriptés,
## et une partie complète dans le monde (carte, coffres, éliminations, anneau, victoire, défaite).
## godot --headless --path game res://tests/test_royale.tscn

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	await _test_ffa()
	_test_ring()
	_test_rules()
	_test_snowball()
	await _test_ai_duels()
	await _test_travel()
	await _test_spell_swap()
	await _test_game_win()
	await _test_game_loss()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Chacun pour soi : trois héros, tous ennemis les uns des autres, même camp ou non.
func _test_ffa() -> void:
	var root := Node3D.new()
	add_child(root)
	var heroes: Array = []
	for i in 3:
		var r := ClassRival.new()
		r.setup(["warrior", "magician", "cleric"][i], 5, 1)
		r.passive = true
		root.add_child(r)
		r.global_position = Vector3(i * 4.0, 0.4, 0)
		heroes.append(r)
	await get_tree().physics_frame
	var a: ClassRival = heroes[0]
	var b: ClassRival = heroes[1]
	var c: ClassRival = heroes[2]
	check("sans chacun pour soi : un monstre ne vise aucun monstre", Combatant.hostile_targets(get_tree(), a).is_empty())
	for i in 3:
		(heroes[i] as Combatant).set_ffa(i)
	var ta := Combatant.hostile_targets(get_tree(), a)
	check("chacun pour soi : cibles = les deux autres", b in ta and c in ta and not (a in ta) and ta.size() == 2)
	check("hostile_heroes pareil", Combatant.hostile_heroes(get_tree(), b).size() == 2)
	c.is_dead = true
	check("un héros tombé n'est plus une cible", not (c in Combatant.hostile_targets(get_tree(), a)))
	c.is_dead = false
	check("le groupe de cibles du monstre suit le chacun pour soi", a._hostile_pool().size() == 2)
	var hp_b := b.hp
	var hp_a := a.hp
	Telegraph.spawn(root, b.global_position, 0.0, {"damage": 40.0, "delay": 0.05, "shape": "circle", "radius": 2.0, "source": a})
	await get_tree().create_timer(0.4).timeout
	check("un coup au sol touche l'autre héros (PV %d → %d)" % [hp_b, b.hp], b.hp < hp_b)
	check("... et pas son lanceur", is_equal_approx(a.hp, hp_a))
	b.clear_ffa()
	check("clear_ffa : retiré du groupe", not b.is_in_group("ffa") and b.ffa_id == -1)
	root.queue_free()


## Calendrier de l'anneau : 9 min 50 (passe M1), rayons décroissants, centres emboîtés.
func _test_ring() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var c0 := Vector2(256, 256)
	var centers := Royale.roll_centers(c0, rng)
	check("5 centres pour 5 phases (+ la carte)", centers.size() == Royale.PHASES.size() + 1 and centers[0] == c0)
	check("calendrier : 9 min 50 (%.0f s)" % Royale.total_time(), is_equal_approx(Royale.total_time(), Royale.DURATION) and Royale.DURATION == 590.0)
	var r0 := Royale.ring_at(0.0, centers)
	check("départ : toute la carte, phase d'attente", is_equal_approx(float(r0.radius), Royale.START_RADIUS) and r0.state == "hold" and int(r0.phase) == 0)
	var prev := 1e9
	var mono := true
	var nested := true
	for t in range(0, 601, 2):
		var rg := Royale.ring_at(float(t), centers)
		if float(rg.radius) > prev + 0.001:
			mono = false
		prev = float(rg.radius)
		# l'anneau reste dans le cercle de départ
		if (rg.center as Vector2).distance_to(c0) + float(rg.radius) > Royale.START_RADIUS + 0.5:
			nested = false
	check("le rayon ne fait que décroître", mono)
	check("chaque anneau reste dans celui de départ", nested)
	var mid := Royale.ring_at(float(Royale.PHASES[0].hold) + float(Royale.PHASES[0].shrink) * 0.5, centers)
	check("à mi-resserrement le rayon est entre les deux (%.0f)" % float(mid.radius), mid.state == "shrink" and float(mid.radius) < 260.0 and float(mid.radius) > float(Royale.PHASES[0].radius))
	var last := Royale.ring_at(Royale.DURATION - 5.0, centers)
	check("dernier cercle : mort subite", last.state == "final" and float(last.dps) >= 0.2 and float(last.radius) <= 14.5)
	var dps := Royale.PHASES.map(func(p): return float(p.dps))
	var rising := true
	for i in range(1, dps.size()):
		if dps[i] <= dps[i - 1]:
			rising = false
	check("dégâts hors anneau croissants", rising)


## Règles du mode et récompenses.
func _test_rules() -> void:
	Profile.reset_all()
	Royale.active = true
	check("mode « royale », règles JcJ", Modes.current() == "royale" and Modes.is_pvp() and PvpCaps.active() and ModeRules.profile_name() == "royale")
	check("pas d'acharnement (l'anneau fait pression)", is_equal_approx(PvpCaps.pressure(), 1.0))
	Royale.active = false
	check("hors partie : mode normal", Modes.current() != "royale")
	League.day_override = "2026-01-01"
	var before := Profile.insignia
	var win := Royale.settle(1, 3, "warrior")
	check("1re victoire : titre « Dernier debout », coffre d'apparence légendaire", win.first_win and "Dernier debout" in Profile.extra_titles and win.chest == "look_legend")
	check("insignes : meilleure place du jour + 3 par élimination", Profile.insignia - before == 110 + 9 and int(win.insignia) == 119)
	check("maîtrise de la classe jouée", int(win.mastery) > 0 and int(Profile.expertise.get("warrior", 0)) >= int(win.mastery))
	var again := Royale.settle(1, 0, "warrior")
	check("2e victoire : pas de second titre, ni insignes de place le même jour", not again.first_win and again.title == "" and int(again.insignia) == 0)
	var third := Royale.settle(3, 1, "warrior")
	check("3e place : coffre d'apparence rare", third.chest == "look_rare")
	League.day_override = "2026-01-02"
	var fifth := Royale.settle(5, 0, "warrior")
	check("5e place (jour suivant) : insignes seulement", fifth.chest == "" and int(fifth.insignia) == 18)
	League.day_override = ""
	check("records : parties, victoires, meilleure place", int(Profile.records.royale_games) == 4 and int(Profile.records.royale_wins) == 2 and int(Profile.records.royale_best) == 1)
	check("le butin suit le niveau, plafonné", Royale.loot_level(1) == 2 and Royale.loot_level(500) == Royale.LEVEL_CAP)
	check("3 pièces par coffre", Royale.chest_items(2, 10, "warrior").size() == 3)


## Lot BR1 : boule de neige bridée (expérience d'une élimination selon l'écart de niveau, niveau maximal par anneau),
## force des héros scriptés, classes retirées du tirage, échelle des dégâts propre au Battle royale.
func _test_snowball() -> void:
	check("élimination à même niveau : 1 niveau", is_equal_approx(Royale.kill_xp(10, 10), 1.0))
	check("victime 5 niveaux plus faible : 0,25 niveau", is_equal_approx(Royale.kill_xp(15, 10), 0.25))
	check("victime 5 niveaux plus forte : 1,75 niveau", is_equal_approx(Royale.kill_xp(10, 15), 1.75))
	check("bornes : 0,2 à 2 niveaux, prime +1", is_equal_approx(Royale.kill_xp(30, 1), Royale.KILL_XP_MIN) and is_equal_approx(Royale.kill_xp(1, 30), Royale.KILL_XP_MAX)
		and is_equal_approx(Royale.kill_xp(10, 10, true), 1.0 + Royale.BOUNTY_XP))
	var caps: Array = []
	var rising := true
	for i in Royale.PHASES.size():
		caps.append(Royale.level_cap(i))
		if i > 0 and caps[i] < caps[i - 1]:
			rising = false
	check("niveau maximal par anneau : sous 24 avant le 3e anneau, croissant, 40 au dernier (%s)" % [caps], int(caps[1]) < 24 and rising
		and int(caps[caps.size() - 1]) == Royale.LEVEL_CAP)
	Royale.active = true
	Royale.level_cap_now = Royale.level_cap(0)
	var r := Royale.make_ai("warrior", 2, 1)
	Royale.ai_award(r, 40.0)
	check("un scripté s'arrête au niveau maximal de l'anneau (%d)" % int(r.get_meta("royale").lv), int(r.get_meta("royale").lv) == Royale.level_cap(0))
	var hp_cap: float = r.max_hp
	Royale.level_cap_now = Royale.LEVEL_CAP
	Royale.ai_award(r, 1.0)
	check("... et repart quand l'anneau se resserre", int(r.get_meta("royale").lv) == Royale.level_cap(0) + 1 and r.max_hp > hp_cap)
	r.free()
	check("force des scriptés : rien aux premiers niveaux, au plus +25 %", is_equal_approx(Royale.ai_level_factor(1), 1.0)
		and is_equal_approx(Royale.ai_level_factor(40), 1.0 + Royale.AI_LEVEL_BONUS_MAX) and Royale.ai_level_factor(8) > 1.0)
	check("les deux Lames ne sont jamais tirées", "black_blade" in Royale.AI_EXCLUDED and "light_blade" in Royale.AI_EXCLUDED)
	check("échelle du Battle royale 0,055, plafonds du duel équipé", is_equal_approx(PvpCaps.damage_scale(), 0.055)
		and is_equal_approx(float(ModeRules.rule("caps").crit_dmg), 1.0))
	Royale.active = false
	check("les autres modes gardent leur échelle", is_equal_approx(ModeRules.num("dmg_scale", 0.0, "duel_a"), 0.030)
		and is_equal_approx(ModeRules.num("dmg_scale", 0.0, "duel_b"), PvpCaps.DAMAGE_SCALE) and is_equal_approx(ModeRules.num("dmg_scale", 0.0, "arena3"), 0.024)
		and is_equal_approx(ModeRules.num("dmg_scale", 0.0, "siege"), 0.018))


## Deux héros scriptés de même niveau et de même équipement (règles du royale) : 15 à 40 s visés (lot BR1, marge de mesure).
func _test_ai_duels() -> void:
	Royale.active = true
	for lv in [1, 12]:
		var t: float = await _ai_duel("warrior", "magician", lv, lv / 3, 2)
		check("duel scripté niveau %d : %.0f s (12 à 45 s)" % [lv, t], t >= 12.0 and t <= 45.0)
	Royale.active = false


func _ai_duel(cid_a: String, cid_b: String, lv: int, chests: int, diff: int) -> float:
	var root := Node3D.new()
	add_child(root)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameData.PHYS_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 2, 200)
	shape.shape = box
	shape.position.y = -1.0
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var ais: Array = []
	for i in 2:
		var r := Royale.make_ai([cid_a, cid_b][i], diff, i + 1)
		var st: Dictionary = r.get_meta("royale")
		for k in chests:
			Royale.ai_open_chest(r, 1)
		st.lv = lv
		Royale.refresh_ai(r, false)
		root.add_child(r)
		r.global_position = Vector3(-4.0 + 8.0 * i, 0.5, 0)
		r.set_ffa(i + 1)
		ais.append(r)
	await get_tree().physics_frame
	var t := 0.0
	while t < 240.0 and not (ais[0].is_dead or ais[1].is_dead):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		PvpCaps.elapsed = t
	root.queue_free()
	await get_tree().process_frame
	return t


## Lance la partie dans le monde et attend que le directeur ait monté la carte et les sept héros.
func _boot_game() -> RoyaleDirector:
	Profile.reset_all()
	Royale.difficulty = 1
	Royale.start("magician")
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	var waited := 0.0
	while waited < 60.0 and not (world.get("director") != null and world.director.royale != null and world.director.royale.ais.size() == 7):
		await get_tree().create_timer(0.5).timeout
		waited += 0.5
	await get_tree().create_timer(1.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	return world.director.royale


func _test_game_win() -> void:
	var rd: RoyaleDirector = await _boot_game()
	var d: RunDirector = world.director
	var p: Player = world.player
	check("partie montée : mode, état, 7 héros IA", Royale.active and d.state == "royale" and rd.ais.size() == 7 and Run.active)
	check("aucune des deux Lames parmi les sept", rd.ais.all(func(a): return not String(a.get_meta("royale").cid) in Royale.AI_EXCLUDED))
	# (lot BR4) largage : tout le monde à bord de l'aigle, chacun vise un point d'atterrissage différent
	check("largage en cours : les 8 à bord, hors du chacun pour soi", rd.phase == "drop" and rd.jump.count_airborne() == 8
		and rd.ais.all(func(a): return a.passive and rd.jump.on_board(a)) and get_tree().get_nodes_in_group("ffa").is_empty())
	var closest := INF
	var pts: Array = rd.jump.riders.values().map(func(st): return st.target)
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			closest = minf(closest, Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length())
	check("points d'atterrissage distincts et éloignés (plus proches : %.0f m)" % closest, closest >= 25.0)
	rd.jump.land_all()
	var ids := {}
	for n in get_tree().get_nodes_in_group("ffa"):
		ids[(n as Combatant).ffa_id] = true
	check("au sol : 8 héros en chacun pour soi, identifiants distincts", get_tree().get_nodes_in_group("ffa").size() == 8 and ids.size() == 8)
	var naked := true
	for a in rd.ais:
		var st: Dictionary = a.get_meta("royale")
		naked = naked and st.gear.is_empty() and int(st.lv) == 1
	check("tous nus au niveau 1", p.level == 1 and Profile.equipped.is_empty() and naked)
	check("2 potions de soin au départ", Potions.count("heal") == 2)
	var tiers := [0, 0, 0]
	var n_chests := 0
	for it in d.map.interactables:
		if it.kind == "chest":
			n_chests += 1
			tiers[int(it.get_meta("tier", 0))] += 1
	check("64 coffres en 3 qualités (%s)" % [tiers], n_chests == 64 and tiers[1] == 18 and tiers[2] == 8 and tiers[0] == 38)
	check("ni camps, ni sanctuaires, ni marchands sur la carte", d.map.camps.is_empty() and d.map.shrines.is_empty() and d.map.merchant_spots.is_empty())
	check("au sol : les héros scriptés jouent", rd.ais.all(func(a): return not a.passive and not rd.jump.airborne(a)))
	# coffre doré ouvert par le joueur
	var gold: Interactable = null
	for it in d.map.interactables:
		if it.kind == "chest" and int(it.get_meta("tier", 0)) == 2:
			gold = it
			break
	var loot_before := get_tree().get_nodes_in_group("loot").size()
	rd.open_chest(gold)
	await get_tree().physics_frame
	check("coffre ouvert : utilisé, niveau gagné, choix proposé", gold.used and p.level >= 2 and (world.cards.is_open() or not world.cards._queue.is_empty()))
	check("coffre doré : deux potions au sol", get_tree().get_nodes_in_group("loot").size() >= loot_before + 2)
	world.cards._queue.clear()
	world.cards._show_next()
	# la pièce choisie dans un coffre est portée tout de suite, au niveau du héros + 1
	var pick: Dictionary = Royale.chest_items(2, p.level, Run.class_id)[0]
	Run.apply_card(RunDirector.item_card(pick, "gear"))
	check("pièce de coffre portée (%s, niveau d'objet %d)" % [pick.slot, int(pick.level)], Profile.equipped.has(String(pick.slot)) and int(pick.level) >= 1)
	# changer de pièce : la page Héros du menu pause remet l'ancienne pièce (elle est restée dans le sac)
	var piece_a := Items.generate(p.level + 1, 0.5, "chest", Run.class_id, 0, "", 3)
	var piece_b := Items.generate(p.level + 1, 0.5, "chest", Run.class_id, 0, "", 3)
	Run.apply_card(RunDirector.item_card(piece_a, "gear"))
	Run.apply_card(RunDirector.item_card(piece_b, "gear"))
	check("2e pièce du même emplacement : portée, la 1re reste dans le sac", is_same(Profile.equipped.chest, piece_b) and Profile.inventory.any(func(x): return is_same(x, piece_a)))
	world.pause_menu._equip._equip(piece_a)
	check("page Héros du menu pause : on remet l'ancienne pièce (échange)", is_same(Profile.equipped.chest, piece_a) and Profile.inventory.any(func(x): return is_same(x, piece_b)))
	# anneau : un héros hors de l'anneau perd des PV
	rd.phase = "fight"
	rd.elapsed = Royale.REVIVE_WINDOW + 10.0  # (après les deux premières minutes : pas de retour, lot BR4)
	var victim: ClassRival = rd.ais[0]
	victim.global_position = Vector3(8, 5, 8)
	var hp0 := victim.hp
	rd.ring = Royale.ring_at(0.0, rd.centers)
	rd._ring_damage()
	check("hors de l'anneau : %d → %d PV" % [hp0, victim.hp], victim.hp < hp0)
	victim.global_position = Vector3(256, 5, 256)
	# élimination
	var kills0 := Royale.kills
	var lv0 := p.level
	var xp0 := p.xp
	rd.ais[1].hp = 1.0
	rd.ais[1].take_damage(1e9, p, false)  # (un coup entre héros est plafonné : PV à 1)
	await get_tree().physics_frame
	check("élimination comptée, expérience gagnée", Royale.kills == kills0 + 1 and (p.level > lv0 or p.xp > xp0) and rd.alive_count() == 7)
	check("... et l'adversaire quitte le chacun pour soi", get_tree().get_nodes_in_group("ffa").size() == 7)
	# tous les autres tombent : victoire
	for i in range(2, 7):
		rd.ais[i].hp = 1.0
		rd.ais[i].take_damage(1e9, p, false)
	victim.hp = 1.0
	victim.take_damage(1e9, p, false)
	await get_tree().physics_frame
	check("dernier debout : partie finie, 1re place", rd.phase == "over" and rd._place == 1)
	world.cards._queue.clear()
	world.cards._show_next()  # (le niveau gagné a ouvert un choix de carte : la partie est en pause)
	var ins := Profile.insignia
	await get_tree().create_timer(3.6).timeout
	check("bilan affiché, partie terminée", world._ended and not Royale.active and Royale.rank == 1 and not Run.active)
	check("récompenses : insignes, titre, coffre d'apparence", Profile.insignia > ins and "Dernier debout" in Profile.extra_titles and Profile.reward_chests.any(func(c): return String(c.type).begins_with("look")))
	check("l'équipement de la partie n'est pas gardé", not Profile.in_run)
	world.queue_free()
	await get_tree().create_timer(0.5).timeout


func _test_game_loss() -> void:
	var rd: RoyaleDirector = await _boot_game()
	var p: Player = world.player
	rd.jump.land_all()
	rd.phase = "fight"
	rd.elapsed = Royale.REVIVE_WINDOW + 10.0  # (après les deux premières minutes : pas de retour, lot BR4)
	var killer: ClassRival = rd.ais[3]
	var kst: Dictionary = killer.get_meta("royale")
	var k_xp := float(kst.lv) + float(kst.prog)
	p.hp = 1.0
	p.evasion_chance = 0.0  # (esquive et parade du héros sont tirées au hasard : le coup fatal doit toujours porter)
	p.parry_chance = 0.0
	p.shield_until = 0.0
	p.take_damage(1e9, killer, false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("le scripté qui t'élimine gagne comme pour un autre héros (lot BR1)", int(kst.kills) == 1 and float(kst.lv) + float(kst.prog) > k_xp + 0.5)
	# (passe M1) éliminé : il regarde la fin, place fixée ; Échap / Options ouvre le bilan
	check("joueur tombé avec 7 adversaires : 8e place, spectateur", rd.spectating and rd._place == 8 and rd.leave_place() == 8)
	var ev := InputEventAction.new()
	ev.action = "pause"
	ev.pressed = true
	rd._unhandled_input(ev)
	check("Échap en spectateur : partie finie à la 8e place", rd.phase == "over" and rd._place == 8)
	await get_tree().create_timer(1.0).timeout
	check("bilan de défaite : partie terminée, place 8", world._ended and Royale.rank == 8 and not Royale.active)
	world.queue_free()
	await get_tree().create_timer(0.5).timeout


## Trajet hors combat : un héros scripté qui rejoint un point lointain court, saute et esquive en chemin.
func _test_travel() -> void:
	Royale.active = true
	var root := Node3D.new()
	add_child(root)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = GameData.PHYS_WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 2, 400)
	shape.shape = box
	shape.position.y = -1.0
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var r := Royale.make_ai("warrior", 2, 1)
	root.add_child(r)
	r.global_position = Vector3(-100, 0.5, 0)
	r.set_ffa(1)
	var other := Royale.make_ai("magician", 2, 2)  # une cible lointaine pour que le héros ait un adversaire
	root.add_child(other)
	other.global_position = Vector3(150, 0.5, 150)
	other.passive = true
	other.set_ffa(2)
	r.goal = Vector3(100, 0.0, 0)
	await get_tree().physics_frame
	var airborne := 0
	var dashes := 0
	var last_dash := -1.0
	var t := 0.0
	while t < 6.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		if not r.is_on_floor():
			airborne += 1
		if r._dash_until != last_dash and r._dash_until > 0.0:
			last_dash = r._dash_until
			dashes += 1
	var moved := r.global_position.x + 100.0
	check("trajet : le héros avance (%.0f m en 6 s)" % moved, moved > 35.0)
	check("trajet : sauts (%d images en l'air) et esquives/bonds (%d)" % [airborne, dashes], airborne > 10 and dashes >= 3)
	root.queue_free()
	Royale.active = false
	await get_tree().process_frame


## Menu pause : les sorts de la run s'échangent par glisser-déposer (Run.swap_spells).
func _test_spell_swap() -> void:
	Profile.reset_all()
	Run.start("magician")
	var ids: Array = (GameData.class_data("magician").get("skills", []) as Array).map(func(s): return int(s.id))
	Run.skills = [{"id": ids[0], "rank": 1}, {"id": ids[1], "rank": 2}, {"id": ids[2], "rank": 1}]
	Run.chains = {0: [{"id": ids[3], "rank": 1}], 1: [{"id": ids[4], "rank": 1}, {"id": ids[5], "rank": 1}]}
	check("deux sorts principaux s'échangent", Run.swap_spells(Vector2i(0, 0), Vector2i(2, 0)) and int(Run.skills[0].id) == ids[2] and int(Run.skills[2].id) == ids[0])
	check("principal ↔ enchaînement", Run.swap_spells(Vector2i(1, 0), Vector2i(0, 1)) and int(Run.skills[1].id) == ids[3] and int(Run.chains[0][0].id) == ids[1] and int(Run.chains[0][0].rank) == 2)
	check("enchaînement vers une position d'enchaînement libre", Run.swap_spells(Vector2i(1, 1), Vector2i(2, 2)) and Run.chain_of(1).size() == 1 and Run.chain_of(2).size() == 1 and int(Run.chain_of(2)[0].id) == ids[4])
	check("un principal ne va pas sur une position libre", not Run.swap_spells(Vector2i(0, 0), Vector2i(0, 2)) and not Run.swap_spells(Vector2i(0, 0), Vector2i(3, 0)))
	check("position libre en source, ou même position : rien", not Run.swap_spells(Vector2i(3, 0), Vector2i(0, 0)) and not Run.swap_spells(Vector2i(0, 0), Vector2i(0, 0)))
	check("12 positions, aucun sort perdu ni dupliqué", Run.all_skills().size() == 6 and Run.all_skills().map(func(s): return int(s.id)).size() == 6)
	var page := RunPage.new()
	page.player = null
	add_child(page)
	await get_tree().process_frame
	page.refresh()
	var rows := page._skills.find_children("*", "HBoxContainer", true, false).filter(func(n): return n is RunPage.SpellRow)
	# (0.1.180) 3 cases : leurs sorts, leurs enchaînements et les positions d'enchaînement libres (cachées hors glisser) ; pas de ligne pour la 4e case libre
	check("la page Run affiche ses lignes de sorts glissables (%d)" % rows.size(), rows.size() == 9)
	var src: RunPage.SpellRow = rows[0]
	var dst: RunPage.SpellRow = rows[3]  # case 2, sort principal
	check("on peut déposer sur une ligne occupée, pas sur sa propre ligne", dst._can_drop_data(Vector2.ZERO, {"spell_pos": src.pos}) and not src._can_drop_data(Vector2.ZERO, {"spell_pos": src.pos}))
	page.queue_free()
	Run.active = false
	Profile.in_run = false
