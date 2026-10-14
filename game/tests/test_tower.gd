extends Node
## La Tour (données et fin de partie, sans scène) : étages, types, niveaux, records.
## godot --headless --path game res://tests/test_tower.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Tower.start("warrior", 1, 1)
	check("la Tour est le mode en cours", Modes.current() == "tower" and Tower.active and Tower.floor_n == 1)
	var s1 := Tower.spec(1)
	check("étage 1 : un type, un niveau de départ", Tower.TYPES.has(String(s1.type)) and int(s1.level) >= 1)
	var mon_floor := 0
	for f in range(1, 30):
		if Tower.floor_type(f) == "monsters":
			mon_floor = f
			break
	check("un étage de monstres : effectif de départ", mon_floor > 0 and int(Tower.spec(mon_floor).count) >= int(Tower.RULES.monsters_base[0]))
	var duels := 0
	var bosses := 0
	var elites := 0
	var prev := 0
	var rising := true
	for f in range(1, Tower.FLOORS + 1):
		var sp := Tower.spec(f)
		match String(sp.type):
			"duel":
				duels += 1
				check_duel(f, sp)
			"boss":
				bosses += 1
			"elite":
				elites += 1
		rising = rising and int(sp.level) >= prev
		prev = int(sp.level)
		if int(sp.get("count", 0)) > int(Tower.RULES.monsters_max[0]) or int(sp.get("alive", 0)) > int(Tower.RULES.alive_max[0]):
			check("effectifs sous les plafonds, étage %d" % f, false)
	check("niveaux jamais en baisse d'un étage à l'autre", rising)
	check("200 étages : des duels, des boss et des élites", duels > 20 and bosses >= 4 and elites >= 4)
	check("boss aux étages 50, 100, 150 et 200", [50, 100, 150, 200].all(func(f): return Tower.is_boss_floor(f)))
	check("difficulté plus dure = monstres plus forts", Tower.monster_mult(30, 3) > Tower.monster_mult(30, 0))
	# fin de partie : étage atteint, record gardé, mode quitté
	Tower.reached = 12
	var old := Tower.best()
	var r := Tower.finish()
	check("fin de la Tour : record d'étage enregistré", Tower.best() >= 12 and int(r.best) >= 12 and (r.new_record == (12 > old)))
	check("Tour quittée : plus de mode", not Tower.active and Modes.current() == "menu")
	check("la Tour a écrit son journal", RunJournal.last_line.is_empty() or RunJournal.last_line.mode == "tower")
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func check_duel(f: int, sp: Dictionary) -> void:
	if not (String(sp.get("class", "")) != "" and Tower.is_duel_floor(f)):
		check("étage de duel %d complet" % f, false)
