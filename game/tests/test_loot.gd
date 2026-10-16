extends Node
## Matières et cristaux des activités (lot E1, 0.1.165) : chaque activité donne ses coffres de forge / du joaillier
## au niveau de l'activité, de quoi monter les pièces de niveau 40 à 100 ; coût d'une pièce à +10 en cristaux ;
## compteur d'Armurerie calculé ; plus de coffre « trophée ».
## godot --headless --path game res://tests/test_loot.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	_test_costs()
	_test_chests()
	_test_open()
	_test_activities()
	_test_misc()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Table « pièce à +10 » : cristaux si chaque tentative réussit, et nombre de clears Mythiques.
func _test_costs() -> void:
	print("--- coût de +0 → +10 (cristaux, chaque tentative réussit)")
	var mythic := {"donjon": ActivityLoot.dungeon_crystals(2), "ruée": ActivityLoot.rush_crystals(8, 2), "siège": ActivityLoot.siege_crystals(5, 2, true)}
	for lv in [20, 40, 60, 85, 90]:
		var c := Forge.upgrade_crystals(lv, 0, 10)
		print("  niveau %d : %d cristaux = %.1f clears de donjon Mythique, %.1f de Ruée, %.1f de Siège" % [lv, c, float(c) / mythic.donjon, float(c) / mythic.ruée, float(c) / mythic.siège])
	var c85 := Forge.upgrade_crystals(85, 0, 10)
	check("+10 d'une pièce niveau 85 : 600 à 900 cristaux", c85 >= 600 and c85 <= 900)
	var per_clear: float = float(mythic.donjon + mythic.ruée + mythic.siège) / 3.0
	check("= 3 à 5,5 clears Mythiques en moyenne", float(c85) / per_clear >= 3.0 and float(c85) / per_clear <= 5.5)
	check("un clear Mythique donne 170 à 280 cristaux", mythic.values().all(func(v): return v >= 170 and v <= 280))
	var normal := ActivityLoot.dungeon_crystals(0)
	check("un donjon Normal paie un petit +N (au moins +3) sur une pièce niveau 30", Forge.upgrade_crystals(30, 0, 3) <= normal)
	check("mais pas un +10", Forge.upgrade_crystals(30, 0, 10) > normal * 5)
	check("hors run, 1 cristal pour 125 or", Forge.price(1250) == {"crystal": 10})


func _levels_of(chests: Array) -> Array:
	return chests.map(func(c): return int(c.plevel))


func _count(chests: Array, type: String, focus := "") -> int:
	return chests.filter(func(c): return c.type == type and String(c.get("focus", "")) == focus).size()


func _test_chests() -> void:
	Profile.reward_chests = []
	var d0 := ActivityLoot.dungeon_chests(Dungeons.level("delphi", 0), 0)
	var d1 := ActivityLoot.dungeon_chests(Dungeons.level("delphi", 1), 1)
	var d2 := ActivityLoot.dungeon_chests(Dungeons.MYTHIC_LEVEL, 2)
	check("donjon Normal : 1 coffre de forge", d0.size() == 1 and _count(d0, "forge") == 1)
	check("donjon Héroïque : 1 coffre de forge + 1 du joaillier", d1.size() == 2 and _count(d1, "forge") == 1 and _count(d1, "jewel") == 1)
	check("donjon Mythique : 2 coffres de forge + 1 du joaillier, au niveau 90", d2.size() == 3 and _count(d2, "forge") == 2 and _levels_of(d2).all(func(l): return l == 90))
	check("les coffres rejoignent le menu Coffres", Profile.reward_chests.size() == 6)
	Profile.reward_chests = []
	var rush_part := ActivityLoot.rush_chests(90, 3, 2)
	var rush_half := ActivityLoot.rush_chests(90, 4, 2)
	var rush_n := ActivityLoot.rush_chests(60, 8, 0)
	var rush_m := ActivityLoot.rush_chests(90, 8, 2)
	check("Ruée arrêtée avant la moitié : aucun coffre", rush_part.is_empty())
	check("Ruée à 4 boss : 1 coffre de forge", rush_half.size() == 1 and _count(rush_half, "forge") == 1)
	check("Ruée Normale finie : 1 coffre de parchemins, 1 de pierres, 1 de gemmes", _count(rush_n, "forge", "scroll") == 1 and _count(rush_n, "forge", "stone") == 1 and _count(rush_n, "jewel", "gem") == 1)
	check("Ruée Mythique finie : 2 coffres de parchemins, 1 de pierres, 1 de gemmes, niveau 90", _count(rush_m, "forge", "scroll") == 2 and rush_m.size() == 4 and _levels_of(rush_m).all(func(l): return l == 90))
	Profile.reward_chests = []
	var s0 := ActivityLoot.siege_chests(30, 0)
	var s2 := ActivityLoot.siege_chests(91, 2)
	check("Siège Normal : 1 coffre de formules d'enchantement", s0.size() == 1 and _count(s0, "jewel", "enchant") == 1)
	check("Siège Mythique : 3 coffres de formules + 1 de forge", _count(s2, "jewel", "enchant") == 3 and _count(s2, "forge") == 1)
	Profile.reward_chests = []
	var lvf := func(f): return 1 + f / 2
	var t := ActivityLoot.tower_chests(1, 100, lvf)
	check("Tour, étages 1 à 100 : 8 coffres de gemmes (tous les 10, sauf 50 et 100) + 2 de forge", _count(t, "jewel", "gem") == 8 and _count(t, "forge") == 2 and t.size() == 10)
	var t2 := ActivityLoot.tower_chests(51, 80, lvf)
	check("Tour, reprise à l'étage 51 jusqu'à 80 : 3 coffres de gemmes", t2.size() == 3 and _levels_of(t2) == [31, 36, 41])
	check("Tour : rien sans étage monté", ActivityLoot.tower_chests(10, 9, lvf).is_empty())
	check("texte groupé des coffres", ActivityLoot.chests_text(d2).contains("Coffre de forge ×2") and ActivityLoot.chests_text(d2).contains("Coffre de joaillier"))
	Profile.reward_chests = []


## Ce que contiennent les coffres ouverts : niveau des parchemins, rang des gemmes, niveau des formules.
func _test_open() -> void:
	print("--- contenu des coffres")
	Profile.reward_chests = []
	Profile.stash = {}
	var forge := Rewards.make("forge", 90, false, "scroll")
	check("l'aperçu d'un coffre de parchemins parle de parchemins de niveau 90", Rewards.preview(forge).contains("niveau 90") and Rewards.preview(forge).contains("2-3"))
	Profile.reward_chests.append(forge)
	var got := Rewards.open(forge)
	var sup: Dictionary = got.supplies
	check("coffre de parchemins niveau 90 : puissance 2-3 et garde 2-4 de niveau 90", int(sup.get("fortify:power:90", 0)) >= 2 and int(sup.get("fortify:guard:90", 0)) >= 2)
	check("les parchemins vont à la réserve", int(Profile.stash.get("fortify:guard:90", 0)) >= 2)
	var piece := Items.generate(85, 1.0, "chest", "warrior", Items.LEGENDARY, "", Items.LEGENDARY)
	piece["level"] = 85
	check("un parchemin de niveau 90 convient à une pièce de niveau 85", Craft.fortify_fits(piece, "fortify:guard:90"))
	var stone := Rewards.make("forge", 90, false, "stone")
	Profile.reward_chests.append(stone)
	var gs: Dictionary = Rewards.open(stone).supplies
	var stones := 0
	for k in gs:
		if String(k).begins_with("stone:"):
			stones += int(gs[k])
	check("coffre de pierres : au moins 7 pierres (2 de sûreté, 1 chanceuse, 4 rares), pas de ciseaux", stones >= 7 and not gs.has("drill"))
	var gem := Rewards.make("jewel", 90, false, "gem")
	Profile.reward_chests.append(gem)
	var gg: Dictionary = Rewards.open(gem).supplies
	var gems := 0
	var scrolls := 0
	var top_tier := true
	for k in gg:
		if String(k).begins_with("gem:"):
			gems += int(gg[k])
			top_tier = top_tier and int(String(k).split(":")[2]) == 4
		elif String(k).begins_with("scroll:"):
			scrolls += int(gg[k])
	check("coffre de gemmes niveau 90 : 3 gemmes royales + 1 formule", gems == 3 and top_tier and scrolls == 1)
	var ench := Rewards.make("jewel", 91, false, "enchant")
	Profile.reward_chests.append(ench)
	var ge: Dictionary = Rewards.open(ench).supplies
	var lv9 := 0
	var eg := 0
	for k in ge:
		if String(k).begins_with("scroll:") and int(String(k).split(":")[2]) == 9:
			lv9 += int(ge[k])
		elif String(k).begins_with("gem:"):
			eg += int(ge[k])
	check("coffre de formules niveau 91 : 3 formules de niveau 9 + 1 gemme", lv9 == 3 and eg == 1)
	var ench_mid := Rewards.make("jewel", 50, false, "enchant")
	Profile.reward_chests.append(ench_mid)
	var gm: Dictionary = Rewards.open(ench_mid).supplies
	var mid_scrolls: Array = gm.keys().filter(func(k): return String(k).begins_with("scroll:"))
	check("coffre de formules niveau 50 : toutes de niveau %d" % Craft.scroll_level_for(50), not mid_scrolls.is_empty() and mid_scrolls.all(func(k): return int(String(k).split(":")[2]) == Craft.scroll_level_for(50)))
	var plain := Rewards.make("forge", 30)
	check("un coffre de forge sans spécialité garde l'ancien contenu (1-2 puissance)", not plain.has("focus") and Rewards.preview(plain).contains("1-2 parchemins de puissance"))
	for t in ["forge", "jewel"]:
		for f in ["", "scroll", "stone", "gem", "enchant"]:
			check("aperçu lisible : %s %s" % [t, f], Rewards.preview(Rewards.make(t, 60, false, f)).length() > 20)
	var cr := Rewards.make("forge", 30)
	Profile.reward_chests.append(cr)
	var cry: int = Rewards.open(cr).crystal
	check("un coffre de forge donne 2 à 3 cristaux au niveau 30", cry == 2 or cry == 3)
	Profile.reward_chests = []


func _test_activities() -> void:
	print("--- butins complets")
	Profile.reward_chests = []
	Profile.materials["crystal"] = 0
	Profile.plans = ["plan_delphi"]
	var r := Dungeons.reward("delphi", 2)
	check("Dungeons.reward Mythique : set + équipement + 3 coffres de matières, 170 cristaux", r.chests.size() == 5 and int(r.crystals) == 170 and Profile.amount("crystal") == 170)
	check("les coffres de matières du donjon sont au niveau du donjon", r.chests.filter(func(c): return c.type in ["forge", "jewel"]).all(func(c): return int(c.plevel) == 90))
	Profile.reward_chests = []
	Profile.materials["crystal"] = 0
	var r0 := Dungeons.reward("limestone", 0)
	check("Dungeons.reward Normal : set + 1 coffre de forge au niveau du donjon, 30 cristaux", r0.chests.size() == 2 and int(r0.crystals) == 30 and r0.chests.any(func(c): return c.type == "forge" and int(c.plevel) == Dungeons.level("limestone", 0)))
	Profile.reward_chests = []
	var rr := Dungeons.rush_reward(8, 1)
	check("Dungeons.rush_reward Héroïque : 144 cristaux, 3 coffres de forge, équipement et titre", int(rr.crystals) == 144 and rr.chests.filter(func(c): return c.type == "forge").size() == 3 and rr.title != "")
	Profile.reward_chests = []
	Profile.materials["crystal"] = 0
	var sg := Siege.settle("blackflame", 2, Siege.WAVES + 1, "escaped")
	check("Siège Mythique, boss tombé : 200 cristaux", int(sg.crystals) == 200 and Profile.amount("crystal") == 200)
	Profile.reward_chests = []
	# la Tour : cristaux + coffres, au bilan
	Profile.materials["crystal"] = 0
	Tower.start("warrior", 1, 1)
	Tower.reached = 20
	var res := Tower.finish()
	var tc := ActivityLoot.tower_crystals(20, 1)  # 4 par étage en Normal depuis la passe E6
	check("Tour (Normal) : 20 étages = %d cristaux et 2 coffres de gemmes" % tc, tc == 80 and int(res.crystals) == tc and res.chests.size() == 2 and Profile.amount("crystal") == tc)
	check("les coffres de gemmes de la Tour sont dans le menu Coffres", Profile.reward_chests.filter(func(c): return c.type == "jewel").size() == 2)
	Profile.reward_chests = []


func _test_misc() -> void:
	print("--- divers")
	check("le coffre « trophée » n'existe plus", not Rewards.TYPES.has("trophy") and not Rewards.ORDER.has("trophy"))
	var old := Rewards.migrate([{"id": "x", "type": "trophy", "plevel": 30}, {"id": "y", "type": "forge", "plevel": 30}])
	check("un ancien coffre de trophées devient un coffre de set", old[0].type == "set" and old[1].type == "forge" and Rewards.is_choice(old[0]))
	var total := Completion.armory_total()
	print("  Armurerie : %d pièces possibles" % total)
	check("compteur de l'Armurerie calculé (plus de 100 pièces)", total > 100)
	check("la catégorie Plans utilise ce total", Completion.categories().any(func(c): return c[0] == "Plans" and int(c[2]) == maxi(total, Completion.armory_done())))
	check("démontage : 1 à 3 cristaux (+1 par 3 niveaux d'amélioration)", Items.disassemble_yield({"rarity": 4, "upgrade": 0}).crystal == 3 and Items.disassemble_yield({"rarity": 0}).crystal == 1 and Items.disassemble_yield({"rarity": 5, "upgrade": 9}).crystal == 6)
