extends Node
## Lot MB-A (Les Deux Voies, conception/benchmark/R_MB_A.md) : tables de MobaData (réglages, or, XP, réapparition, 40
## objets et recettes, camps, objectifs, sbires), kits générés des 60 classes (data/moba_kits.json : 4 cases valides,
## déplacement / contrôle / soin quand la classe en a, ultime en case 4 à 60-90 s), profil « moba » de ModeRules lu par
## PvpCaps, fiche « moba » de TeamMatch et mode scellé.
## godot --headless --path game res://tests/test_mb_data.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	_tables()
	_items()
	_kits()
	_rules_and_mode()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _tables() -> void:
	var bad := MobaData.validate()
	for b in bad.slice(0, 12):
		print("  problème : ", b)
	check("MobaData.validate : aucune incohérence (%d)" % bad.size(), bad.is_empty())
	check("niveaux 1 à 12, fiche 30 à 85", MobaData.sheet_level(1) == 30 and MobaData.sheet_level(12) == 85
		and MobaData.sheet_level(99) == 85)
	check("XP : 120, 160 … 520, 3 520 au total pour le niveau 12", MobaData.xp_to_next(1) == 120 and MobaData.xp_to_next(2) == 160
		and MobaData.xp_to_next(11) == 520 and MobaData.xp_to_next(12) == 0 and MobaData.xp_total(12) == 3520)
	check("niveau d'après l'XP", MobaData.level_for_xp(0) == 1 and MobaData.level_for_xp(119) == 1 and MobaData.level_for_xp(120) == 2
		and MobaData.level_for_xp(3519) == 11 and MobaData.level_for_xp(99999) == 12)
	check("réapparition : 7 s au niveau 1, 29 s au niveau 12, + 25 % dès 15:00, + 50 % dès 18:00",
		is_equal_approx(MobaData.respawn_time(1, 0.0), 7.0) and is_equal_approx(MobaData.respawn_time(12, 0.0), 29.0)
		and is_equal_approx(MobaData.respawn_time(12, 900.0), 36.25) and is_equal_approx(MobaData.respawn_time(12, 1080.0), 43.5))
	check("primes : 300, premier sang + 100, série plafonnée à 700", MobaData.kill_bounty(0) == 300 and MobaData.kill_bounty(0, true) == 400
		and MobaData.kill_bounty(4) == 500 and MobaData.kill_bounty(20, true) == 700)
	check("niveau attendu : 1 au départ, croissant, 12 vers 18:00", is_equal_approx(MobaData.expected_level(0.0), 1.0)
		and MobaData.expected_level(300.0) > MobaData.expected_level(120.0) and is_equal_approx(MobaData.expected_level(2000.0), 12.0)
		and MobaData.expected_level(960.0) > 10.5)
	check("déroulé : vagues dès 0:40 puis toutes les 30 s, Gardien 3:00, Colosse 9:00, Marée 18:00, fin 25:00",
		is_equal_approx(MobaData.wave_time(1), 40.0) and is_equal_approx(MobaData.wave_time(3), 100.0)
		and MobaData.GUARDIAN_AT == 180.0 and MobaData.COLOSSUS_AT == 540.0 and MobaData.TIDE_AT == 1080.0 and MobaData.END_AT == 1500.0)
	var w1 := MobaData.wave(1, 40.0)
	var w3 := MobaData.wave(3, 100.0)
	var late := MobaData.wave(4, 800.0, 1)
	check("vague : 3 mêlées + 2 tireurs ; bélier une vague sur 3 (sur 2 dès 12:00) ; géants en plus",
		w1.count("melee") == 3 and w1.count("ranged") == 2 and not "ram" in w1 and "ram" in w3 and "ram" in late and late.count("giant") == 1)
	check("4 postes : Brumes (Rempart), jungle (Ombre), tir (Traque, Arcane), soutien (Ferveur)", MobaData.ROLES.size() == 4
		and MobaData.role_for_family(1) == 0 and MobaData.role_for_family(2) == 1 and MobaData.role_for_family(3) == 2
		and MobaData.role_for_family(5) == 2 and MobaData.role_for_family(4) == 3)
	check("camps : Source, Braise, petits ; objectifs : Gardien (palier 1), Colosse (palier 3)", MobaData.CAMPS.has("source")
		and MobaData.CAMPS.has("braise") and MobaData.CAMPS.has("petit") and int(MobaData.OBJECTIVES.guardian.tier) == 1
		and int(MobaData.OBJECTIVES.colossus.tier) == 3)
	# force des sbires : relative au héros de référence (fiches hors scène)
	var t0 := Time.get_ticks_msec()
	MobaData.warm_ref()
	var warm_ms := Time.get_ticks_msec() - t0
	var r1 := MobaData.ref_hero(1.0)
	var r12 := MobaData.ref_hero(12.0)
	print("[mb-a] héros de référence : niv. 1 %d PV, %.0f déf, %.0f par auto ; niv. 12 %d PV, %.0f déf, %.0f par auto (%d ms)" % [
		int(r1.hp), float(r1.def), float(r1.auto), int(r12.hp), float(r12.def), float(r12.auto), warm_ms])
	check("héros de référence : plus fort au niveau 12", float(r12.hp) > float(r1.hp) and float(r12.auto) > float(r1.auto))
	var m := MobaData.minion_stats("melee", 0.0)
	var m2 := MobaData.minion_stats("melee", 0.0, 1.2)
	check("sbire mêlée : 4 auto-attaques d'un héros, coup = 3 % de ses PV, × 1,2 sur demande",
		is_equal_approx(float(m.hp), 4.0 * float(r1.auto)) and absf(float(m.atk) * 100.0 / (100.0 + float(r1.def)) - 0.03 * float(r1.hp)) < 0.01 * float(r1.hp)
		and is_equal_approx(float(m2.hp), float(m.hp) * 1.2))
	check("sbires de fin de partie plus solides", float(MobaData.minion_stats("melee", 1200.0).hp) > float(m.hp))


func _items() -> void:
	check("40 objets", MobaData.ITEMS.size() == 40)
	var types := {}
	for it in MobaData.ITEMS:
		types[String(it.type)] = int(types.get(String(it.type), 0)) + 1
	check("9 composants, 5 bottes, 4 potions", int(types.get("composant", 0)) == 9 and int(types.get("bottes", 0)) == 5
		and int(types.get("potion", 0)) == 4)
	check("recette : Lame de braise = Lame courte + Œil de faucon + 1 550", MobaData.recipe_cost("lame_braise") == 1550
		and MobaData.item("lame_braise").recipe == ["lame_courte", "oeil_faucon"])
	var no_pct := true
	for it in MobaData.ITEMS:
		if "%" in String(it.text) or "%" in String(it.name):
			no_pct = false
	check("aucun pourcentage dans les textes des objets (les chiffres sont dans l'infobulle)", no_pct)
	var tabs_ok := true
	for tb in MobaData.TABS:
		if MobaData.tab_items(String(tb[0])).is_empty():
			tabs_ok = false
	check("7 onglets de boutique, aucun vide", MobaData.TABS.size() == 7 and tabs_ok)
	check("2 parcours conseillés par famille", MobaData.BUILDS.size() == 5 and MobaData.BUILDS.values().all(func(b): return (b as Array).size() == 2))


func _kits() -> void:
	var n := 0
	var miss_move := []
	var miss_cc := []
	var miss_heal := []
	var main_first := 0
	for cid in GameData.classes:
		var k := MobaData.kit(String(cid))
		if (k.get("slots", []) as Array).size() == 4:
			n += 1
		else:
			continue
		var by_id := {}
		for s in GameData.class_data(String(cid)).get("skills", []):
			by_id[int(s.id)] = s
		var mains: Array = k.slots.map(func(s): return by_id.get(int(s.main), {}))
		var all: Array = []
		for s in k.slots:
			all.append(by_id.get(int(s.main), {}))
			for c in s.chains:
				all.append(by_id.get(int(c), {}))
		if bool(k.has.mobility) and not mains.any(func(s): return String(s.get("kind", "")) in ["dash", "blink"] or float(s.get("dash", 0.0)) > 0.0 or s.has("move_dir")):
			miss_move.append(cid)
		if bool(k.has.control) and not mains.any(func(s): return _control(s)):
			miss_cc.append(cid)
		if int(k.family) == 4 and bool(k.has.heal) and not mains.any(func(s): return String(s.get("kind", "")) == "heal" or float(s.get("heal", 0.0)) > 0.0):
			miss_heal.append(cid)
		var first4: Array = (GameData.class_data(String(cid)).get("skills", []) as Array).slice(0, 4).map(func(s): return int(s.id))
		if k.slots.slice(0, 3).any(func(s): return int(s.main) in first4):
			main_first += 1
	check("60 kits de 4 cases (3 + ultime)", n == 60 and GameData.classes.size() == 60)
	check("un sort de déplacement dans les cases quand la classe en a un %s" % str(miss_move), miss_move.is_empty())
	check("un sort de contrôle dans les cases quand la classe en a un %s" % str(miss_cc), miss_cc.is_empty())
	check("un soin dans les cases de la Ferveur %s" % str(miss_heal), miss_heal.is_empty())
	check("les sorts principaux de la classe d'abord (%d classes sur 60)" % main_first, main_first >= 55)
	var st := MobaData.start_skills("warrior")
	check("sorts de départ : les 3 cases de base", st.size() == 3 and int(st[0].id) == int(MobaData.kit("warrior").slots[0].main))
	var out := []
	var r := OS.execute("python", [ProjectSettings.globalize_path("res://").path_join("../tools/moba_kits.py"), "--check"], out, true)
	if r == -1 or r == 9009:
		print("  (python absent : vérification du fichier sautée)")
	else:
		check("data/moba_kits.json à jour (tools/moba_kits.py --check)", r == 0)


func _control(s: Dictionary) -> bool:
	for k in (s.get("applies", {}) as Dictionary):
		if String(k) in ["stun", "freeze", "sleep", "fear", "root", "disarm", "chill"]:
			return true
	return float(s.get("pull", 0.0)) > 0.0


func _rules_and_mode() -> void:
	MobaData.ensure_rules()
	check("profil « moba » enregistré", ModeRules.has_profile("moba"))
	TeamMatch.begin("moba")
	check("fiche « moba » : Les Deux Voies, 2 équipes de 4, objectif", TeamMatch.title() == "Les Deux Voies" and TeamMatch.team_count() == 2
		and int(TeamMatch.spec.size) == 4 and Modes.kind() == "objective" and Modes.current() == "moba")
	check("mode scellé, combat entre héros, sans Duel ni Battle royale", Modes.sealed() and Modes.is_pvp() and Modes.hero_match()
		and not Duel.active and not Royale.active)
	check("profil de règles lu par PvpCaps : échelle 0,3 (lot MB-E), coup ≤ 22 %, rafale ≤ 50 %", ModeRules.profile_name() == "moba"
		and is_equal_approx(PvpCaps.damage_scale(), 0.3) and is_equal_approx(ModeRules.num("hit_cap"), 0.22)
		and is_equal_approx(ModeRules.num("burst_cap"), 0.5))
	check("fiche : directeur MobaDirector, potions permises", String(TeamMatch.spec.get("director", "")).ends_with("moba_director.gd")
		and bool(TeamMatch.spec.get("potions", false)))
	TeamMatch.end()
	check("fin : plus de mode d'équipes", Modes.current() == "menu" and not Modes.sealed())
