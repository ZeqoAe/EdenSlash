extends Node
## Garde-fous de build (lot 6) : projectiles normalisés, Élan meurtrier, trophées, Lame large,
## physique / magique, arme qui grandit.
## godot --headless --path game res://tests/test_guards.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true  # rien n'est sauvegardé
	Settings.reset_all()
	Run.start("warrior")
	var p := Player.new()
	p.level = 10
	add_child(p)
	await get_tree().physics_frame
	p.set_physics_process(false)

	# --- Élan meurtrier : 1,5 s rendues par seconde au plus
	p.clock = 100.0
	p._cdr_given = 0.0
	p._cdr_at = 100.0
	var got := 0.0
	for i in 20:  # 20 morts d'un coup, 0,3 s chacune
		got += p.cdr_allow(0.3)
	check("Élan : 1,5 s rendues au plus d'un coup (%.2f)" % got, is_equal_approx(got, 1.5))
	p.clock = 102.0
	check("Élan : la réserve se remplit avec le temps", is_equal_approx(p.cdr_allow(0.3), 0.3))
	check("Élan : recharge interne de 0,15 s", is_equal_approx(float(Boons.get_def("momentum").procs[0].cd), 0.15))

	# --- trophées à l'impact : plus de bonus permanent en horde
	for k in ["agi", "agi_int", "str", "int_wis", "all", "crit"]:
		check("trophée « %s » : recharge de 5 s" % k, float(Trophies.KINDS[k].get("cd", 0.0)) >= 5.0)
	check("Double frappe : recharge de 1 s", float(Trophies.KINDS.double.get("cd", 0.0)) >= 1.0)

	# --- Lame large : +100 % au plus
	var wa: Dictionary = Boons.get_def("wide_arc")
	check("Lame large plafonnée à +100 %%", float(wa.stat.area) * int(wa.max) <= 1.0)

	# --- projectiles en plus normalisés
	var katana: Dictionary = WeaponAttacks.variants("katana")[0]
	p.extra_proj = 0
	var a0 := WeaponAttacks.action_for(katana, p)
	p.extra_proj = 1
	var a1 := WeaponAttacks.action_for(katana, p)
	var total0 := float(a0.mult) * int(a0.hits)
	var total1 := float(a1.mult) * int(a1.hits)
	check("+1 frappe en mêlée : environ +50 %% de dégâts (%.2f)" % (total1 / total0), absf(total1 / total0 - 1.5) < 0.02)
	p.extra_proj = 9
	var a9 := WeaponAttacks.action_for(katana, p)
	check("plafond de 4 frappes en plus", int(a9.hits) == int(a0.hits) + WeaponAttacks.MAX_EXTRA_PROJ)
	p.extra_proj = 0

	# --- arme qui grandit : l'effet légendaire arrive au niveau 4
	var cur := {}
	for i in 3:
		WeaponAttacks.merge_upgrade(cur, {"dmg": 0.15})
	check("niveau 3 : pas d'effet légendaire", not cur.get("sig", false))
	WeaponAttacks.merge_upgrade(cur, {"dmg": 0.15})
	check("niveau 4 : effet légendaire acquis", cur.get("sig", false) == true)

	# --- Exécuteur au plafond : plus proposé
	Run.passives["executioner"] = 3
	check("Exécuteur à 36 %% (plafond 30 %%) : plus proposé", range(40).all(func(_i): return Run.roll_cards(3).all(func(c): return str(c.id) != "executioner")))
	check("_at_cap détecte le plafond", Run._at_cap(Boons.get_def("executioner")))
	Run.passives.erase("executioner")
	check("Exécuteur sous le plafond : proposé", not Run._at_cap(Boons.get_def("executioner")))

	# --- physique / magique : classes à majorité de sorts magiques
	var bad: PackedStringArray = []
	for cid in GameData.classes:
		var c: Dictionary = GameData.classes[cid]
		var mag := 0
		var phys := 0
		for s in c.get("skills", []):
			if s.get("shared", false) or String(s.get("kind", "")) in ["buff", "heal"]:
				continue
			if String(s.get("dmg_type", "phys")) == "mag":
				mag += 1
			else:
				phys += 1
		if mag > phys and (String(c.get("dmg_type", "phys")) != "mag" or float(c.get("base", {}).get("matk", 0.5)) < float(c.get("base", {}).get("atk", 1.0))):
			bad.append(cid)
	check("physique / magique : toutes les classes à sorts magiques sont magiques %s" % [bad], bad.is_empty())
	check("une classe physique reste physique", String(GameData.class_data("warrior").get("dmg_type", "phys")) == "phys")

	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
