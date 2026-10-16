extends Node
## Lot A4 (refonte « Aventure ») : coffre de plans du boss de chaque carte : 3 pièces non découvertes du palier au choix,
## le plan acquis tout de suite (gardé si la run est perdue ensuite), aucun doublon, tout découvert → 30 insignes,
## bilan, pilote automatique : godot --headless --path game res://tests/test_a4.tscn

var fails := 0
var world: Node


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	_test_rules()
	Run.start_survival("warrior", 1)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.director.set_physics_process(false)
	world.player.autoplay = false
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.3).timeout
	var a := await _test_map1()
	var b := _test_map2_pilot(a)
	_test_all_found()
	await _test_defeat_after(a, b)
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().paused = false
	world.queue_free()  # sortie propre (sans cela Godot plantait en quittant)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(1 if fails > 0 else 0)


## Tirage : 3 pièces différentes, jamais découvertes (compte, trouvailles de la run), jamais de trophée, arme de la classe.
func _test_rules() -> void:
	check("fiche « Coffre de plans » courte", Tutorial.CARDS.has("boss_plans") and String(Tutorial.CARDS.boss_plans.short).length() <= 125)
	Run.start_survival("warrior", 1)
	var pool := Run.plan_pool(1, 1)
	check("palier I-1 : des plans à découvrir (%d)" % pool.size(), pool.size() >= 3)
	var main := Items.default_weapon_type("warrior")
	var odd := pool.filter(func(e): return String(e.slot) == "trophy" or (String(e.slot) == "weapon" and String(e.get("wtype", "")) != main))
	check("palier : ni trophée ni arme d'un autre type", odd.is_empty())
	var ids := pool.map(func(e): return int(e.id))
	var uniq := {}
	for id in ids:
		uniq[id] = true
	check("palier sans doublon", uniq.size() == ids.size())
	# une pièce découverte (compte) ou choisie dans un coffre de la run n'est plus proposée
	Profile.seen_gear.append(int(ids[0]))
	Run.seen_items.append(int(ids[1]))
	var bad := 0
	for i in 40:
		var offer := Run.plan_offer(1, 1)
		var oid := offer.map(func(it): return int(it.eden))
		if offer.size() != 3 or int(ids[0]) in oid or int(ids[1]) in oid or oid[0] == oid[1] or oid[1] == oid[2] or oid[0] == oid[2]:
			bad += 1
	check("3 choix non découverts et différents (40 tirages)", bad == 0)
	check("pièces +0 au palier de la carte", Run.plan_offer(1, 1).all(func(it): return int(it.get("upgrade", 0)) == 0 and it.has("eden")))
	Profile.reset_all()
	Profile.selected_class = "warrior"


## Carte 1 : le boss tombe, l'amélioration d'arme puis le coffre de plans s'ouvrent ; le choix rejoint le compte tout de suite.
func _test_map1() -> int:
	var d = world.director
	var seen0: Array = Profile.seen_gear.duplicate()
	d._on_boss_killed()
	await get_tree().process_frame
	var cards = world.cards
	check("boss vaincu : un choix ouvert", cards.is_open())
	if cards.is_open() and not cards._cards.is_empty() and String(cards._cards[0].get("type", "")) != "plan":
		cards._opened_at -= 1000
		cards._choose(0)  # l'amélioration d'arme garantie d'abord
	await get_tree().process_frame
	var plans: Array = cards._cards if cards.is_open() else []
	check("coffre de plans : 3 cartes « plan »", plans.size() == 3 and plans.all(func(c): return String(c.type) == "plan"))
	var labelled := plans.filter(func(c): return String(c.subtitle).begins_with("Plan · ") and String(c.desc).contains("insignes"))
	check("cartes : « Plan · … » et prix de l'Atelier", labelled.size() == 3)
	check("3 pièces non découvertes", plans.all(func(c): return not int(c.item.eden) in seen0))
	check("cartes cliquables (souris, manette)", cards._buttons.size() == 3 and cards._buttons.all(func(b): return b is BaseButton))
	if plans.size() < 3:
		return -1
	var id := int(plans[1].item.eden)
	cards._opened_at -= 1000
	cards._choose(1)
	await get_tree().process_frame
	check("plan acquis tout de suite (Profile.seen_gear)", id in Profile.seen_gear and Run.boss_plans == [id])
	check("choix fermé", not cards.is_open())
	return id


## Carte 2 : le pilote automatique choisit seul (aucun écran laissé ouvert) ; un plan différent du premier.
func _test_map2_pilot(a: int) -> int:
	var d = world.director
	d._next_stage(d.next_zone_id())
	check("carte 2", Run.stage == 2)
	world.player.autoplay = true
	d._on_boss_killed()
	world.player.autoplay = false
	check("pilote : aucun choix laissé ouvert", not world.cards.is_open())
	check("pilote : un plan de plus", Run.boss_plans.size() == 2)
	var b := int(Run.boss_plans[-1]) if Run.boss_plans.size() == 2 else -1
	check("aucun doublon entre les cartes", b != a and b in Profile.seen_gear)
	return b


## Tout le palier découvert : 30 insignes à la place, crédités tout de suite.
func _test_all_found() -> void:
	for e in Run.plan_pool(Run.epoch, Run.stage):
		Profile.seen_gear.append(int(e.id))
	check("palier entièrement découvert : plus de plan à proposer", Run.plan_offer(Run.epoch, Run.stage).is_empty())
	var ins0 := Profile.insignia
	var n := Run.boss_plans.size()
	world.director.offer_plans()
	check("tout découvert : +%d insignes à la place" % Run.PLAN_INSIGNIA, Profile.insignia == ins0 + Run.PLAN_INSIGNIA
		and Run.plan_insignia == Run.PLAN_INSIGNIA and Run.boss_plans.size() == n and not world.cards.is_open())


## Défaite sur la carte suivante : les plans des boss restent acquis (sauvegarde relue), le bilan les nomme et compte les insignes.
func _test_defeat_after(a: int, b: int) -> void:
	var d = world.director
	d._next_stage(d.next_zone_id())
	world.end_run("defaite")
	await get_tree().process_frame
	check("défaite en carte 3", Run.result == "defaite" and Run.stage == 3)
	check("plans gardés après la défaite", a in Profile.seen_gear and b in Profile.seen_gear)
	Profile.end_run_survival()
	Profile.load_profile()
	check("plans gardés dans la sauvegarde", a in Profile.seen_gear and b in Profile.seen_gear)
	var rows := ResultsScreen.kept_rows(false)
	var plan_rows := rows.filter(func(r): return str(r).contains("Plan trouvé : "))
	check("bilan : une ligne « Plan trouvé : <pièce> » par plan (%d)" % plan_rows.size(), plan_rows.size() == 2)
	var total := 0
	for l in ResultsScreen.insignia_lines():
		total += int(l[1])
	var line := ResultsScreen.insignia_lines().filter(func(l): return int(l[1]) == Run.PLAN_INSIGNIA and String(l[0]).contains("Plans"))
	check("bilan : insignes du coffre comptés (%d = %d)" % [total, Run.insignia_gain], total == Run.insignia_gain and line.size() == 1)
