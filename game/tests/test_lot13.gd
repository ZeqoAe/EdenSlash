extends Node
## Lot 13 : Donjons (3 salles depuis le lot A2, difficultés, alliés IA, butin, plans).
## godot --headless --path game res://tests/test_lot13.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	var zids := Dungeons.zone_ids()
	check("un donjon par zone (8)", zids.size() == 8)
	check("niveaux : Normal < Héroïque (+15) et Mythique 90", Dungeons.level(zids[0], 1) == Dungeons.level(zids[0], 0) + 15 and Dungeons.level(zids[0], 2) == 90)
	check("fermés au départ (époque I non gagnée)", not Dungeons.is_open(zids[0]))
	Profile.records["epochs_cleared"] = 2
	Profile.records["boss_" + zids[3]] = 1
	check("ouvert : boss de sa zone battu en Survie", Dungeons.is_open(zids[3]))
	check("les zones d'une époque gagnée sont ouvertes", Dungeons.is_open(String(Epochs.get_def(1).zones[0])))
	check("un donjon dont le boss n'est pas battu reste fermé", not Dungeons.is_open(zids[7]) and Dungeons.condition(zids[7]).contains("boss"))
	check("trois salles : élites, lieutenant, boss (lot A2)", Dungeons.rooms(zids[0], 0).map(func(r): return r.type) == ["elite", "lieutenant", "boss"])
	check("PV des monstres +50 % par allié", is_equal_approx(Dungeons.hp_mult(false, false, 2), Dungeons.MONSTER_HP * 2.0))
	# mode : la Tour sert de moteur de salles
	Profile.records["epochs_cleared"] = 2
	Tower.start_dungeon("warrior", zids[0], 1, ["cleric", "knight", "thief"])
	check("mode donjon actif, salles et mode « dungeon »", Tower.is_dungeon() and Tower.top() == 3 and Modes.current() == "dungeon" and Tower.floor_type(3) == "boss")
	check("2 alliés au plus", Tower.allies.size() == 2)
	check("kit complet : les sorts du préréglage ou de base", Run.skills.size() >= 1)
	check("niveau de la salle du boss : +1", Tower.level_for(3) == Tower.level_for(1) + 1)
	check("zone du donjon", String(Tower.zone_for(2).id) == zids[0])
	# fin : défaite puis victoire
	Tower.reached = 2
	var lose := Tower.finish()
	check("défaite : pas de butin", lose.dungeon and not lose.victory and lose.reward.is_empty() and not Tower.is_dungeon())
	Tower.start_dungeon("warrior", zids[0], 1, [])
	Tower.reached = Tower.top()
	var chests0 := Profile.reward_chests.size()
	var win := Tower.finish()
	check("victoire : un coffre de set + 2 coffres de matières (Héroïque), des cristaux, record gardé", win.victory and Profile.reward_chests.size() == chests0 + 3 and Dungeons.cleared(zids[0], 1) == 1 and int(win.reward.crystals) == ActivityLoot.dungeon_crystals(1))
	check("1re victoire en Héroïque : un plan de fabrication", Dungeons.has_plan(BossLibrary.zone_boss(zids[0])))
	check("la Tour est de nouveau la Tour", not Tower.is_dungeon() and not Tower.active)
	# le mode Tour normal n'est pas touché
	Tower.start("warrior", 1, 1)
	check("Tour : 200 étages", Tower.top() == Tower.FLOORS and not Tower.is_dungeon())
	Tower.active = false
	Run.active = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
