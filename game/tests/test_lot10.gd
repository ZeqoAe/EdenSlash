extends Node
## Lot 10 : Défi de maîtrise, contrats de classe, reprise de la Tour, page Jouer.
## godot --headless --path game res://tests/test_lot10.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	# page Jouer : 3 rangées, Arènes fusionnées, plus de champ de bataille
	var ids: Array = Activities.LIST.map(func(a): return a.id)
	check("Arènes en une seule carte, pas de Champ de bataille", "arenas" in ids and not "arena2" in ids and not "battlefield" in ids)
	check("trois rangées : Aventure, Défis, Affrontements", Activities.ROWS.size() == 3 and Activities.LIST.any(func(a): return a.row == "challenge"))
	check("chaque carte dit son gain", Activities.LIST.all(func(a): return String(a.get("gain", "")) != ""))
	# Défi de maîtrise
	var m := Challenge.modifiers_today()
	check("deux modificateurs distincts du jour", m.size() == 2 and m[0] != m[1] and m.all(func(x): return Modifiers.LIST.has(x)))
	check("même défi toute la journée", Challenge.modifiers_today() == m and Challenge.classes_today() == Challenge.classes_today())
	check("trois classes proposées, ouvertes", Challenge.classes_today().size() == 3 and Challenge.classes_today().all(func(c): return Progression.class_unlocked(c)))
	Challenge.start("warrior")
	check("défi lancé : modificateurs actifs, Survie époque I", Challenge.active and ModeRules.modifiers == m and Run.survival and Run.epoch == 1)
	var s1 := Challenge.settle(1000, "victoire")
	check("1re victoire du jour : maîtrise ×2 + 600", int(s1.gain) == 2600 and s1.first and Challenge.done_today())
	check("2e victoire du jour : maîtrise ×2 seulement", int(Challenge.settle(1000, "victoire").gain) == 2000)
	check("défaite : ×2 sans bonus", int(Challenge.settle(1000, "defaite").gain) == 2000)
	Run.start_survival("warrior", 1)
	check("une Survie normale remet le jeu à zéro", not Challenge.active and ModeRules.modifiers.is_empty())
	# modificateurs en jeu
	ModeRules.modifiers = ["heal_half"]
	var p := Player.new()
	add_child(p)
	await get_tree().physics_frame
	p.set_physics_process(false)
	p.hp = 1.0
	p.heal(100.0)
	var healed := p.hp - 1.0
	ModeRules.modifiers = []
	p.hp = 1.0
	p.heal(100.0)
	check("soins ÷ 2 avec le modificateur", absf(healed * 2.0 - (p.hp - 1.0)) < 0.01 and healed > 0.0)
	ModeRules.modifiers = ["chests_plus"]
	Profile.gold = 0
	Run.add_gold(100)
	check("or +30 %", Profile.gold == 130)
	ModeRules.modifiers = []
	# contrats
	var st := Contracts.state("warrior")
	check("3 contrats par classe, tous différents", (st.active as Array).size() == 3 and (st.active as Array).size() == Array(st.active).filter(func(x): return true).size())
	var fin := Contracts.report("warrior", {"kills": 100000, "elites": 100000, "chests": 100000, "perfects": 100000, "max_level": 100, "wins": 100})
	check("tous les contrats terminés, remplacés par trois autres", fin.size() == 3 and (Contracts.state("warrior").active as Array).size() == 3)
	check("récompense de 400 à 800", fin.all(func(c): return int(c.reward) >= 400 and int(c.reward) <= 800))
	var none := Contracts.report("warrior", {"kills": 1})
	check("peu de progression : rien de terminé", none.is_empty())
	# reprise de la Tour
	Profile.records["tower_best"] = 37
	check("reprise : palier 31 après 37 étages battus", Tower.checkpoint(1) == 31)
	Profile.records["tower_best"] = 4
	check("moins de 10 étages : on repart de l'étage 1", Tower.checkpoint(1) == 1)
	Profile.records["tower_best"] = 37
	Tower.start("warrior", 1, 31)
	check("reprise : kit complet (sorts du préréglage) et cartes selon l'étage", Run.skills.size() >= 1 and Run.passives.size() + Run.weapon_ups.size() >= 0 and Tower.active)
	Tower.active = false
	Run.active = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
