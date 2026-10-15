extends Node
## Lot E5 de la nuit du 15/10 : barème unique des insignes (Survie = référence, JcJ et donjons en dessous), Armurerie à
## paliers, puits (coffres d'apparence et d'auras par semaine, leçons de maîtrise par jour), et maîtrise des 60 classes
## (rattrapage, 1re victoire de la classe par époque, part de l'arbre de classe, Défi de maîtrise tourné vers les
## classes en retard).
## godot --headless --path game res://tests/test_e5.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	_test_rates()
	_test_armory()
	_test_sinks()
	_test_mastery()
	_test_run()
	_test_challenge()
	Economy.day_override = ""
	Profile.reset_all()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _test_rates() -> void:
	check("Survie : formule inchangée (défaite carte 1, 40 monstres, 1 élite = 52)", Economy.survival_insignia(1, 40, 1, 1, false) == 25 + 25 + 2 + 2)
	check("Survie : pas de participation sous 10 monstres", Economy.survival_insignia(1, 9, 0, 1, false) == 25)
	var r1 := Economy.survival_insignia_per_hour(1)
	var r4 := Economy.survival_insignia_per_hour(4)
	check("Survie : %d / h (époque I) à %d / h (époque IV), proches des cibles" % [r1, r4],
		absi(r1 - int(Economy.INSIGNIA_PER_HOUR.survie_1)) <= 10 and absi(r4 - int(Economy.INSIGNIA_PER_HOUR.survie_4)) <= 10)
	# JcJ : la somme des 1res victoires du jour de tous les modes + Battle royale gagnée ne dépasse pas la Survie d'époque IV
	var pvp := 0
	for k in League.DAILY_INSIGNIA:
		pvp += int(League.DAILY_INSIGNIA[k])
	pvp += int(League.ROYALE_PLACE[1]) + 3 * League.ROYALE_KILL
	check("JcJ : 1re heure du jour (tout gagné) %d ≤ cible %d ≤ Survie IV %d" % [pvp, Economy.INSIGNIA_PER_HOUR.jcj, r4],
		pvp <= int(Economy.INSIGNIA_PER_HOUR.jcj) and int(Economy.INSIGNIA_PER_HOUR.jcj) <= r4)
	check("JcJ : heures suivantes (10 par victoire, ≈ 6 / h) sous la Survie I", League.REPEAT_INSIGNIA * 6 <= int(Economy.INSIGNIA_PER_HOUR.jcj_suite) and int(Economy.INSIGNIA_PER_HOUR.jcj_suite) < r1)
	check("Donjons, Tour, Siège : aucune source d'insigne", int(Economy.INSIGNIA_PER_HOUR.donjons) == 0 and int(Economy.INSIGNIA_PER_HOUR.tour) == 0 and int(Economy.INSIGNIA_PER_HOUR.siege) == 0)


func _test_armory() -> void:
	Profile.reset_all()
	# deux pièces d'un même palier (même emplacement, niveau, rareté) dans l'Armurerie
	var by_tier := {}
	var pair: Array = []
	for id in Completion.armory_ids():
		var e: Dictionary = GameData.eden_by_id.get(int(id), {})
		if e.is_empty() or String(e.slot) == "weapon":
			continue
		var k := Economy.tier_key(e)
		if by_tier.has(k):
			pair = [by_tier[k], e]
			break
		by_tier[k] = e
	check("Armurerie : au moins un palier de 2 pièces", pair.size() == 2)
	if pair.size() < 2:
		return
	var a: Dictionary = pair[0]
	var b: Dictionary = pair[1]
	check("Armurerie : prix plein tant que le palier n'est pas entamé", Economy.base_price(a) == GearShopPage.price(a) and Economy.base_price(b) == GearShopPage.price(b))
	check("palier non entamé : prix plein (%d)" % Economy.armory_price(b), Economy.armory_price(b) == Economy.base_price(b))
	Profile.add_item(GearShopPage.make(a))  # comme un achat de l'Armurerie
	var tiers := Economy.owned_tiers()
	check("palier entamé : %d -> %d insignes (×%.2f)" % [Economy.base_price(b), Economy.armory_price(b, tiers), Economy.TIER_REPEAT],
		Economy.armory_price(b, tiers) == maxi(1, roundi(Economy.base_price(b) * Economy.TIER_REPEAT)))
	check("l'Armurerie applique la remise", GearShopPage.price(b) == Economy.armory_price(b, tiers))
	# une autre pièce d'un autre palier garde son prix
	for id in Completion.armory_ids():
		var e: Dictionary = GameData.eden_by_id.get(int(id), {})
		if not e.is_empty() and Economy.tier_key(e) != Economy.tier_key(a):
			check("autre palier : prix plein", Economy.armory_price(e, tiers) == Economy.base_price(e))
			break
	# pièce des Esprits : jamais de remise
	check("pièce des Esprits : son propre palier, jamais de remise", Economy.tier_key({"id": Pantheon.shop_id(0), "slot": "boots", "level": 70, "rarity": Items.LEGENDARY}).begins_with("pantheon|"))


func _test_sinks() -> void:
	Profile.reset_all()
	Economy.day_override = "2026-10-15"  # un jeudi
	check("semaine : du lundi 12/10 (%s)" % Economy.week(), Economy.week() == "2026-10-12")
	Economy.day_override = "2026-10-12"
	check("semaine : un lundi est son propre début", Economy.week() == "2026-10-12")
	Economy.day_override = "2026-10-18"
	check("semaine : le dimanche suivant aussi", Economy.week() == "2026-10-12")
	Economy.day_override = "2026-10-15"
	Profile.insignia = 5000
	var n0 := Profile.reward_chests.size()
	check("coffre légendaire : 1 par semaine", Economy.chest_left("look_legend") == 1 and Economy.buy_chest("look_legend"))
	check("insignes débités (600) et coffre rangé", Profile.insignia == 4400 and Profile.reward_chests.size() == n0 + 1
		and String(Profile.reward_chests[-1].type) == "look_legend")
	check("2e coffre légendaire la même semaine : refusé", not Economy.buy_chest("look_legend") and Profile.insignia == 4400)
	Economy.day_override = "2026-10-19"  # lundi suivant
	check("nouvelle semaine : de nouveau achetable", Economy.chest_left("look_legend") == 1)
	check("type inconnu : jamais achetable", Economy.chest_left("gear") == 0 and not Economy.buy_chest("gear"))
	Profile.insignia = 100
	check("pas assez d'insignes : refusé", not Economy.buy_chest("look_rare") and Profile.insignia == 100)


func _test_mastery() -> void:
	Profile.reset_all()
	Economy.day_override = "2026-10-15"
	# rattrapage : relatif à la meilleure classe du compte
	check("compte neuf : pas de rattrapage", not Economy.lagging("warrior") and Economy.catchup("warrior", 1000) == 1000)
	Profile.set_expertise_level("thief", 10)
	check("classe 7 niveaux sous la meilleure : ×%.1f" % Economy.CATCHUP_MULT, Economy.lagging("warrior") and Economy.catchup("warrior", 1000) == 1500)
	check("la meilleure classe : pas de rattrapage", Economy.catchup("thief", 1000) == 1000)
	Profile.set_expertise_level("warrior", 8)
	check("à 2 niveaux de la meilleure : plus de rattrapage", not Economy.lagging("warrior"))
	Profile.set_expertise_level("thief", 30)
	Profile.set_expertise_level("warrior", 20)
	check("niveau %d atteint : plus de rattrapage" % Economy.CATCHUP_MAX, not Economy.lagging("warrior"))
	# 1re victoire de la classe, une fois par époque
	check("1re victoire époque I : %d" % Economy.FIRST_WIN[0], Economy.first_win("magician", 1) == int(Economy.FIRST_WIN[0]))
	check("2e victoire époque I : rien", Economy.first_win("magician", 1) == 0)
	check("1re victoire époque IV : %d" % Economy.FIRST_WIN[3], Economy.first_win("magician", 4) == int(Economy.FIRST_WIN[3]))
	# arbre de classe : voisines débloquées et plus basses
	Profile.reset_all()
	var nb := Economy.tree_neighbours("warrior")
	check("voisines du Guerrier : Chevalier, Templier, Berserker… (%s)" % [nb], "knight" in nb and "templar" in nb and "berserker" in nb and not "thief" in nb and not "magician" in nb)
	check("voisine de l'Exécuteur : le Chevalier", Economy.tree_neighbours("executioner") == ["knight"])
	Profile.set_expertise_level("warrior", 10)
	if not "knight" in Profile.unlocked_classes:
		Profile.unlocked_classes.append("knight")
	var k0 := int(Profile.expertise.get("knight", 0))
	var t0 := int(Profile.expertise.get("thief", 0))
	Profile.add_expertise("warrior", 1000)
	check("part de l'arbre : Chevalier +%d (10 %%)" % (int(Profile.expertise.get("knight", 0)) - k0), int(Profile.expertise.get("knight", 0)) - k0 == 100
		and Profile.last_shared.get("knight", 0) == 100)
	check("part de l'arbre : rien pour une autre famille", int(Profile.expertise.get("thief", 0)) == t0)
	check("part de l'arbre : classe verrouillée exclue", not Profile.last_shared.has("berserker") or Progression.class_unlocked("berserker"))
	Profile.set_expertise_level("knight", 12)
	Profile.add_expertise("warrior", 1000)
	check("part de l'arbre : rien pour une voisine plus haute", not Profile.last_shared.has("knight"))
	Profile.add_expertise("knight", 1000, false)
	check("sans part (leçon) : rien de partagé", Profile.last_shared.is_empty())
	# leçons de maîtrise : classes en retard, 3 par jour
	Profile.reset_all()
	Profile.set_expertise_level("warrior", 12)
	Profile.insignia = 1000
	check("leçon : refusée pour la meilleure classe", not Economy.can_buy_lesson("warrior"))
	var m0 := int(Profile.expertise.get("thief", 0))
	Economy.buy_lesson("thief")
	check("leçon : -%d insignes, +%d maîtrise" % [Economy.LESSON_COST, Economy.LESSON_MASTERY],
		Profile.insignia == 1000 - Economy.LESSON_COST and int(Profile.expertise.get("thief", 0)) == m0 + Economy.LESSON_MASTERY)
	Economy.buy_lesson("thief")
	Economy.buy_lesson("thief")
	check("leçon : %d par jour au plus" % Economy.LESSONS_PER_DAY, Economy.lessons_left() == 0 and Economy.buy_lesson("thief") == -1)
	Economy.day_override = "2026-10-16"
	check("leçon : de nouveau le lendemain", Economy.lessons_left() == Economy.LESSONS_PER_DAY)
	check("leçon : classe verrouillée refusée", not Progression.class_unlocked("sage") and not Economy.can_buy_lesson("sage"))


func _test_run() -> void:
	Profile.reset_all()
	Profile.set_expertise_level("thief", 12)  # meilleure classe : le Guerrier est en retard
	Run.start_survival("warrior", 1)
	Run.stage = RunDirector.STAGES
	Run.max_level = 35
	Run.kills = 600
	Run.elites = 10
	var x0 := int(Profile.expertise.get("warrior", 0))
	Run.finish("victoire")
	var before_bonus := Run.expertise_gain - Run.expertise_catchup - Run.first_win_bonus
	check("Survie gagnée en retard : rattrapage +%d sur %d" % [Run.expertise_catchup, before_bonus], Run.expertise_catchup == roundi(before_bonus * Economy.CATCHUP_MULT) - before_bonus and Run.expertise_catchup > 0)
	check("Survie gagnée : 1re victoire du Guerrier en époque I +%d" % Run.first_win_bonus, Run.first_win_bonus == int(Economy.FIRST_WIN[0]))
	check("maîtrise ajoutée = gain affiché (%d)" % Run.expertise_gain, int(Profile.expertise.get("warrior", 0)) - x0 == Run.expertise_gain)
	check("insignes de la run = barème (%d)" % Run.insignia_gain, Run.insignia_gain == Economy.survival_insignia(RunDirector.STAGES, 600, 10, 1, true))
	Profile.end_run_survival()
	Run.start_survival("warrior", 1)
	Run.stage = RunDirector.STAGES
	Run.max_level = 35
	Run.finish("victoire")
	check("2e victoire en époque I : plus de bonus de 1re victoire", Run.first_win_bonus == 0)
	Profile.end_run_survival()
	Run.start_survival("warrior", 1)
	Run.stage = 1
	Run.kills = 50
	Run.finish("defaite")
	check("défaite : pas de bonus de victoire", Run.first_win_bonus == 0)
	Profile.end_run_survival()


func _test_challenge() -> void:
	Profile.reset_all()
	for c in ["knight", "samurai", "inquisitor", "bard", "luminary", "dragon_knight"]:
		if not c in Profile.unlocked_classes:
			Profile.unlocked_classes.append(c)
	Profile.set_expertise_level("warrior", 15)
	Profile.set_expertise_level("thief", 15)
	Profile.set_expertise_level("hunter", 15)
	var cls := Challenge.classes_today()
	check("Défi de maîtrise : 3 classes (%s)" % [cls], cls.size() == 3)
	check("Défi de maîtrise : toutes en retard quand il y en a assez", cls.all(func(c): return Economy.lagging(String(c))))
