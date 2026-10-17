extends Node
## Lot CLS-1 (équilibre des classes face aux boss de l'Aventure, conception/progression/R_CLS1.md) : table
## data/class_balance.json (classes connues, clés de la base, jamais une baisse, jamais au-dessus du meilleur de la famille),
## stats du héros relevées en Aventure seulement (ni hors Aventure, ni pour un héros ennemi), classes sans réglage inchangées.
## godot --headless --path game res://tests/test_cls1.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Settings.reset_all()
	Profile.reset_all()
	_test_table()
	_test_hero()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_table() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(ClassBalance.PATH))
	check("data/class_balance.json lisible (clé « adventure »)", raw is Dictionary and (raw as Dictionary).get("adventure") is Dictionary)
	if not raw is Dictionary:
		return
	var adv: Dictionary = raw.adventure
	check("au moins le Chasseur réglé (%d classe(s))" % adv.size(), adv.has("hunter"))
	var known := true
	var keys_ok := true
	var up := true
	var floor_ok := true
	for cid in adv:
		if not GameData.classes.has(cid):
			known = false
			continue
		var base: Dictionary = GameData.class_data(cid).get("base", {})
		var fam := int(GameData.class_data(cid).get("family", 0))
		for k in (adv[cid] as Dictionary):
			if k == "why":
				continue
			if k in ClassBalance.MULT_KEYS:
				if float(adv[cid][k]) < 1.0 or float(adv[cid][k]) > ClassBalance.MAX_MULT:
					up = false
				continue
			if not k in ClassBalance.KEYS:
				keys_ok = false
				continue
			var v := float(adv[cid][k])
			var before := float(base.get(k, 0.5 if k == "matk" else (1.0 if k in ["hp", "atk"] else 0.0)))
			if v < before - 0.0001:
				up = false
			# plancher de la famille : jamais au-dessus de la meilleure valeur des classes de la même famille
			var best := before
			for other in GameData.classes:
				var od: Dictionary = GameData.class_data(String(other))
				if int(od.get("family", -1)) == fam:
					best = maxf(best, float(od.get("base", {}).get(k, before)))
			if v > best + 0.0001:
				floor_ok = false
	check("classes connues", known)
	check("clés de la base (%s) ou multiplicateurs (%s) seulement" % [", ".join(ClassBalance.KEYS), ", ".join(ClassBalance.MULT_KEYS)], keys_ok)
	check("jamais une baisse par rapport à data/classes.json, multiplicateurs entre 1 et %.1f" % ClassBalance.MAX_MULT, up)
	check("multiplicateur absent : 1 ; borné à %.1f" % ClassBalance.MAX_MULT, is_equal_approx(ClassBalance.mult("warrior", "dmg_mult"), 1.0)
		and ClassBalance.mult("inconnue", "hp_mult") == 1.0)
	check("jamais au-dessus de la meilleure classe de la même famille", floor_ok)
	check("classe sans réglage : base inchangée", ClassBalance.adventure_base("warrior", {"hp": 1.25}) == {"hp": 1.25})


## Héros du joueur : réglage appliqué en Aventure seulement.
func _stats(cid: String, adventure: bool) -> Dictionary:
	Profile.selected_class = cid
	Profile.records[HeroLevel.KEY] = HeroLevel.total_for(10)
	if adventure:
		Run.start_survival(cid, 1)
	else:
		Run.start(cid)  # partie hors Aventure (Run.survival faux : Tour, Donjons, duel…)
	var p := Player.new()
	add_child(p)
	p.set_physics_process(false)
	p.set_process(false)
	p.level = 10
	p.recalc_stats()
	var out := {"adv": Epochs.adventure(), "hp": p.max_hp, "def": p.defense, "atk": p.atk, "dmg": p.dmg_mult}
	p.free()
	Run.active = false
	return out


func _test_hero() -> void:
	var adj := ClassBalance.adventure("hunter")
	var a := _stats("hunter", true)
	var o := _stats("hunter", false)
	check("Aventure / hors Aventure bien distinguées", bool(a.adv) and not bool(o.adv))
	check("Chasseur en Aventure : PV %d > %d hors Aventure" % [roundi(a.hp), roundi(o.hp)], not adj.has("hp") or float(a.hp) > float(o.hp) * 1.02)
	check("Chasseur en Aventure : défense %.0f > %.0f hors Aventure" % [a.def, o.def], not adj.has("def") or float(a.def) > float(o.def))
	var w := _stats("warrior", true)
	var wo := _stats("warrior", false)
	check("Guerrier (sans réglage) : mêmes PV en Aventure et hors Aventure (%d / %d)" % [roundi(w.hp), roundi(wo.hp)], is_equal_approx(float(w.hp), float(wo.hp)))
	# multiplicateurs (PV, dégâts) : appliqués en Aventure seulement
	for key in ClassBalance.MULT_KEYS:
		var cid := ""
		for c in ClassBalance._table():
			if (ClassBalance._table()[c] as Dictionary).has(key):
				cid = String(c)
				break
		if cid == "":
			continue
		var stat := "dmg" if key == "dmg_mult" else "hp"
		var ma := _stats(cid, true)
		var mo := _stats(cid, false)
		check("%s : %s ×%.2f en Aventure (%.2f / %.2f hors Aventure)" % [cid, key, ClassBalance.mult(cid, key), float(ma[stat]), float(mo[stat])],
			absf(float(ma[stat]) / float(mo[stat]) - ClassBalance.mult(cid, key)) < 0.02)
	# héros ennemi (duel, Arènes, Tour) et hors Aventure : mêmes stats avec ou sans la table
	var foe_with := _foe_stats()
	ClassBalance._table()
	var saved: Dictionary = ClassBalance._adv
	ClassBalance._adv = {}
	var foe_without := _foe_stats()
	var o2 := _stats("hunter", false)
	var a2 := _stats("hunter", true)
	ClassBalance._adv = saved
	check("héros ennemi en Aventure : la table ne change rien (PV %d / %d)" % [roundi(foe_with.hp), roundi(foe_without.hp)],
		is_equal_approx(float(foe_with.hp), float(foe_without.hp)) and is_equal_approx(float(foe_with.def), float(foe_without.def)))
	check("héros du joueur hors Aventure : la table ne change rien", is_equal_approx(float(o.hp), float(o2.hp)) and is_equal_approx(float(o.def), float(o2.def)))
	check("sans la table, le Chasseur en Aventure retrouve ses PV d'origine (%d)" % roundi(a2.hp), float(a2.hp) < float(a.hp) or not adj.has("hp"))


func _foe_stats() -> Dictionary:
	Run.start_survival("warrior", 1)
	var f := Player.new()
	f.foe = true
	f.class_id = "hunter"
	add_child(f)
	f.set_physics_process(false)
	f.set_process(false)
	f.level = 10
	f.recalc_stats()
	var out := {"hp": f.max_hp, "def": f.defense}
	f.free()
	Run.active = false
	return out
