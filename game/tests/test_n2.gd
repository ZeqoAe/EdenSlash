extends Node
## Passe N2 : plus d'enclume en Survie, arme trouvée rangée dans le sac, arme secondaire qui ne frappe pas seule,
## « Changer d'arme » en plein combat (recharge, pas de coup juste après), compétences toujours aux stats de
## l'arme principale : godot --headless --path game res://tests/test_n2.tscn

var fails := 0
var world: Node
var player: Player


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
	player = world.player
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	world.director.set_process(false)
	world.director.set_physics_process(false)
	world.cards._queue.clear()
	world.cards._show_next()
	await get_tree().create_timer(0.3).timeout
	_test_no_anvil()
	_test_bag()
	await _test_swap()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


## Touche, textes, défis d'époque : rien ne parle plus de l'enclume de la Survie.
func _test_rules() -> void:
	check("action « Changer d'arme » : clavier, manette réassignable, carte des touches", Settings.DEFAULT_BINDS.has("swap_weapon")
		and Settings.PAD_BINDS.has("swap_weapon") and "swap_weapon" in Settings.PAD_ACTIONS and InputMap.has_action("swap_weapon"))
	var used := {}
	var clash := ""
	for a in Settings.DEFAULT_BINDS:
		for e in Settings.DEFAULT_BINDS[a]:
			var k := str(e)
			if used.has(k) and not [String(used[k]), String(a)] in Settings.SHARED_OK and not [String(a), String(used[k])] in Settings.SHARED_OK:
				clash = "%s / %s" % [used[k], a]
			used[k] = a
	check("touche par défaut sans conflit %s" % clash, clash == "")
	var pad_used := []
	for a in Settings.PAD_BINDS:
		if a != "swap_weapon":
			pad_used.append_array(Settings.PAD_BINDS[a].map(func(e): return str(e)))
	check("bouton de manette libre", not Settings.PAD_BINDS.swap_weapon.any(func(e): return str(e) in pad_used))
	check("recharge d'échange : courte, plus longue entre héros", WeaponAttacks.SWAP_CD > 0.0 and WeaponAttacks.SWAP_CD_PVP > WeaponAttacks.SWAP_CD)
	check("défis d'époque : plus d'enclume", not Epochs.CHALLENGES.any(func(t): return String(t).to_lower().contains("enclume")))
	check("fiches : plus de fiche d'enclume, fiche « Deux armes »", not Tutorial.CARDS.has("anvil") and Tutorial.CARDS.has("offhand")
		and String(Tutorial.CARDS.offhand.short).length() <= 125)
	check("plus d'enclume de run (+N du hub seul)", not "slot_bonus" in Run and not "UPGRADE_CAP" in Run)


func _test_no_anvil() -> void:
	var map = world.director.map
	check("Survie : aucune enclume sur la carte", map.interactables.filter(func(i): return is_instance_valid(i) and i.kind == "anvil").is_empty()
		and map.stations.filter(func(s): return String(s.kind) == "anvil").is_empty())


## Une arme trouvée (coffre d'arme, arme secondaire) va dans le sac, jamais équipée d'office.
func _test_bag() -> void:
	var main_uid := String(Profile.equipped.weapon.uid)
	var off0: Dictionary = Profile.equipped.get("offhand", {})
	var got := []
	Run.weapon_bagged.connect(func(it): got.append(it))
	var w: Dictionary = SlotChests.offer("weapon", 1, 1)[0]
	Run.apply_card({"type": "gear", "item": w})
	check("coffre d'arme : l'arme va dans le sac, l'arme principale ne change pas", String(Profile.equipped.weapon.uid) == main_uid
		and Profile.inventory.any(func(x): return is_same(x, w)))
	var o: Dictionary = SlotChests.offhand_offer(1, 1)[0]
	Run.apply_card({"type": "offhand", "item": o})
	check("arme secondaire trouvée : dans le sac, pas portée", Profile.equipped.get("offhand", {}).hash() == off0.hash() and Profile.inventory.any(func(x): return is_same(x, o)))
	check("annonce au HUD pour chaque arme rangée (%d)" % got.size(), got.size() == 2 and world.hud._better_box.visible)
	check("[G] : l'arme rangée s'équipe (secondaire : autre type)", world.hud.quick_equip() and is_same(Profile.equipped.get("offhand"), o))
	check("comparaison d'une arme d'un autre type : avec l'arme secondaire", Items.compare_to_equipped(o) == 0.0)


func _test_swap() -> void:
	# arme secondaire bien plus forte que la principale : les auto-attaques le montrent, pas les compétences
	var bow := Items.generate(60, 0.0, "weapon", "warrior", Items.MYTHIC, "bow", Items.MYTHIC)
	bow["auto_variant"] = 0
	Profile.inventory.append(bow)
	Profile.equip_offhand(bow)
	player.level = 30  # (puissance des pièces : celle du héros, plafonnée par leur niveau)
	Run.hero_level = 30
	Profile.changed.emit()
	player.recalc_stats()
	var st_off := Profile.equipment_stats()
	Profile.equipped.erase("offhand")
	var st_none := Profile.equipment_stats()
	Profile.equipped["offhand"] = bow
	player.recalc_stats()
	check("l'arme secondaire ne donne aucune stat au héros", st_off.hash() == st_none.hash())
	# ne frappe pas seule
	var m := _dummy(1.6)
	var hp0 := m.hp
	for i in 60:
		await get_tree().physics_frame
	check("arme secondaire : ne frappe pas seule (%.0f → %.0f)" % [hp0, m.hp], is_equal_approx(m.hp, hp0))
	await get_tree().create_timer(0.1).timeout
	await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(0.3).timeout
	check("HUD : case de l'arme rangée visible", world.hud._swap.visible)
	# dégâts : compétence identique, auto-attaque différente
	player.crit = 0.0
	player.mcrit = 0.0
	_target = _dummy(1.6, 0.5)
	var skill_main := _hit(false)
	var basic_main := _hit(true)
	var atk_main := player.atk
	check("arme principale en main : auto-attaque aux stats du héros", is_equal_approx(player.basic_atk, player.atk))
	player._time += 10.0
	check("échange : arme secondaire en main", player.swap_weapon() and player.hand_off and player.hand_slot() == "offhand")
	check("échange : auto-attaque de l'arc (%s)" % String(player.auto_spec().wtype), String(player.auto_spec().wtype) == "bow")
	check("échange : défi « sans changer d'arme » perdu", Run.offhand_used)
	check("échange : modèle de l'arme suivi", player._weapon_code == Profile.weapon_code("offhand"))
	player.crit = 0.0
	player.mcrit = 0.0
	var skill_off := _hit(false)
	var basic_off := _hit(true)
	check("compétence : attaque du héros inchangée (%.1f / %.1f)" % [atk_main, player.atk], is_equal_approx(atk_main, player.atk))
	check("compétence : mêmes dégâts quelle que soit l'arme en main (%.1f / %.1f)" % [skill_main, skill_off], absf(skill_main - skill_off) <= 0.01 * skill_main)
	var dp := float(Items.stats(bow).get("patk", 0.0)) - float(Items.stats(Profile.equipped.weapon).get("patk", 0.0))
	check("auto-attaque : attaque de l'arme secondaire en main (écart d'arme %+.0f : %.0f → %.0f)" % [dp, basic_main, basic_off],
		absf(dp) > 1.0 and signf(basic_off - basic_main) == signf(dp) and absf(basic_off - basic_main) > 0.005 * basic_main)
	check("échange : pas d'auto-attaque juste après", _attack_starts() == false)
	check("échange : recharge (pas de nouvel échange tout de suite)", not player.swap_weapon() and player.swap_left() > 0.0)
	player._time += WeaponAttacks.SWAP_CD + 0.05
	check("échange : retour à l'arme principale après la recharge", player.swap_weapon() and not player.hand_off and String(player.auto_spec().wtype) == Items.default_weapon_type("warrior"))
	# sans arme secondaire : rien
	player._time += 10.0
	Profile.unequip("offhand")
	player.recalc_stats()
	check("sans arme secondaire : l'échange ne fait rien, case cachée", not player.swap_weapon() and player.stowed_item().is_empty())
	# pilote automatique : ne demande jamais l'échange
	player.autoplay = true
	check("pilote automatique : ignore l'échange", not player._wants("swap_weapon"))
	player.autoplay = false


var _target: Monster


## Dégâts d'un coup (compétence ou auto-attaque) sur la même cible, PV remis, tirage aléatoire figé.
func _hit(basic: bool) -> float:
	var m := _target
	m.hp = m.max_hp
	seed(1234)
	var a := {"mult": 1.0, "dmg_type": "phys"}
	if basic:
		a["basic"] = true
	player._hit_monster(m, player.forward(), a, not basic)
	return m.max_hp - m.hp


func _attack_starts() -> bool:
	player._state = "idle"
	player._start_attack(player.global_position + player.forward() * 2.0)
	return player._state == "attack"


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
