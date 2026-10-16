extends Node
## Lot E2 de la nuit du 15/10 : maîtrise du JcJ (formule commune), insignes JcJ plafonnés au jour, plan sûr au
## 1er donjon de chaque difficulté, fabrication de l'arme et des bijoux, Siège Normal sans PE, panoplie des
## Esprits universelle (Armurerie, armes de tous les types, éveil, niveau fixe).
## godot --headless --path game res://tests/test_e2.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	_test_mastery()
	_test_insignia()
	_test_dungeons()
	_test_pantheon()
	League.day_override = ""
	Duel.mode = "free"
	Duel.bare = false
	Duel.team_allies = []
	Duel.extra_foes = []
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


func _test_mastery() -> void:
	check("Ligue : formule inchangée (40 + 20 × rang + 150 × manche)", League.mastery_for(2, 4) == 420 and League.mastery_for(2, 1) == 360)
	check("JcJ hors Ligue : moitié de la Ligue au même palier (Hardcore)", League.pvp_mastery("arena3", 2, 3) == 210 and League.pvp_mastery("free", 2, 3) == 210)
	check("difficulté plus faible : moins de maîtrise", League.pvp_mastery("free", 2, 0) < League.pvp_mastery("free", 2, 3))
	check("Gantelet : plus par adversaire", League.pvp_mastery("gauntlet", 2, 2, 2) > League.pvp_mastery("gauntlet", 2, 2, 1))
	# duel libre gagné : maîtrise ; adversaire affaibli : rien
	Profile.reset_all()
	Duel.mode = "free"
	Duel.bare = true
	Duel.bare_level = 10
	Duel.rival_build = {}
	Duel.hp_mult = 1.0
	Duel.atk_mult = 1.0
	Duel.start("warrior", "magician", 3)
	Duel.wins = 2
	Duel.finish(true)
	var m := int(Duel.last_report.get("mastery", 0))
	check("duel libre gagné : maîtrise (%d)" % m, m == League.pvp_mastery("free", 2, 3) and int(Profile.expertise.get("warrior", 0)) == m)
	Duel.hp_mult = 0.5
	Duel.start("warrior", "magician", 3)
	Duel.wins = 2
	Duel.finish(true)
	check("duel libre contre un adversaire affaibli : pas de maîtrise", int(Duel.last_report.get("mastery", 0)) == 0 and Duel.hp_mult == 0.5)
	# un mode classé ignore la préparation du duel libre, puis la rend
	Duel.mode = "arena2"
	Duel.team_allies = ["warrior"]
	Duel.extra_foes = ["mage"]
	Duel.start("warrior", "magician", 2)
	check("Arènes : la préparation du duel libre n'affaiblit pas l'adversaire", Duel.hp_mult == 1.0)
	Duel.wins = 2
	Duel.finish(true)
	check("Arènes : maîtrise et préparation rendue après", int(Duel.last_report.get("mastery", 0)) == League.pvp_mastery("arena2", 2, 2) and Duel.hp_mult == 0.5)
	Duel.hp_mult = 1.0
	# Panthéon : maîtrise à chaque victoire (même une classe déjà passée)
	Profile.reset_all()
	Profile.records["league_rank"] = 4
	Duel.mode = "pantheon"
	Duel.pilot = "debutant"
	Duel.start("warrior", "magician", 3)
	Duel.wins = 2
	Duel.finish(true)
	check("Panthéon : 1re victoire, pièce et maîtrise", not (Duel.last_report.get("piece", {}) as Dictionary).is_empty() and int(Duel.last_report.get("mastery", 0)) == League.mastery_for(2, 1))
	var again := Duel.settle(true, "warrior")  # (la sauvegarde n'est pas écrite en test : 2e victoire en mémoire)
	check("Panthéon : maîtrise même pour une classe déjà passée", not again.has("piece") and int(again.get("mastery", 0)) == League.mastery_for(2, 1) and int(Profile.expertise.get("warrior", 0)) == 2 * League.mastery_for(2, 1))
	Duel.pilot = ""


func _test_insignia() -> void:
	Profile.reset_all()
	League.day_override = "2026-03-01"
	check("Arènes 2v2 : 1re victoire du jour 50, puis 10", League.win_insignia("arena2") == 50 and League.win_insignia("arena2") == League.REPEAT_INSIGNIA)
	check("chaque mode a sa 1re victoire du jour", League.win_insignia("gauntlet_3") == 90 and League.win_insignia("arena3") == 75)
	League.day_override = "2026-03-02"
	check("le lendemain : de nouveau plein", League.win_insignia("arena2") == 50)
	check("Battle royale : la meilleure place du jour paie la différence", League.royale_insignia(4, 0) == 28 and League.royale_insignia(2, 0) == 70 - 28 and League.royale_insignia(3, 1) == League.ROYALE_KILL)
	# une heure de JcJ contre l'IA rapporte moins qu'une heure de Survie (victoire d'époque I, ~35 min)
	League.day_override = "2026-03-03"
	var pvp := 0
	for k in 12:  # ~12 victoires d'Arènes 3v3 de ~5 min
		pvp += League.win_insignia("arena3")
	var survie_h := roundi((Run.INSIGNIA_BASE + 25 * 3 + 600 / 20 + 10 * 2 + 60) * 60.0 / 35.0)
	check("Arènes : une heure (%d) < une heure de Survie (%d)" % [pvp, survie_h], pvp < survie_h)
	League.day_override = "2026-03-04"
	var roy := 0
	for k in 12:  # ~12 parties de 5 min, toutes gagnées avec 2 éliminations
		roy += League.royale_insignia(1, 2)
	check("Battle royale : une heure (%d) < une heure de Survie" % roy, roy < survie_h)


func _test_dungeons() -> void:
	Profile.reset_all()
	Profile.unlocked_features = ["dungeons"]
	var zid := "wetlands"
	var r := Dungeons.reward(zid, 0)
	var zb := BossLibrary.zone_boss(zid)
	check("1er donjon Normal terminé : plan sûr (celui du boss, lot A1)", r.plan == Dungeons.plan_id(zb) and Dungeons.has_plan(zb))
	Profile.insignia = 100000  # lot A1 : fabrication en insignes
	# boss dont le butin compte l'arme, puis les bijoux (lot A1 : deux emplacements par boss)
	for slot in ["weapon", "necklace", "ring"]:
		var bid := String(Dungeons.catalog({"slot": slot, "zone": zid})[0])
		Dungeons.reward(zid, 0, bid)
		var it := FabricationPage.craft(bid, slot)
		check("fabrication : %s de la panoplie" % slot, not it.has("error") and String(it.slot) == slot and it.get("archetype", "") == String(BossLibrary.loot(bid).archetype))
	Profile.selected_class = "magician"
	var w := FabricationPage.craft(String(Dungeons.catalog({"slot": "weapon", "zone": zid})[0]), "weapon")
	check("arme fabriquée du type de la classe choisie", Items.weapon_type_of(w) == Items.default_weapon_type(Profile.selected_class))
	var hb := String(Dungeons.catalog({"slot": "head", "zone": zid})[0])
	Dungeons.reward(zid, 0, hb)
	Profile.selected_zone = "blackflame"
	var a := FabricationPage.craft(hb, "head")
	Profile.selected_zone = "limestone"
	var b := FabricationPage.craft(hb, "head")
	check("niveau de la pièce fabriquée : celui du donjon, pas de la zone du lobby (%d / %d)" % [int(a.level), int(b.level)], absi(int(a.level) - int(b.level)) <= 12 and int(a.level) <= Dungeons.level(zid, 0))
	Profile.unlocked_features = ["dungeons", "siege"]
	Profile.records["boss_" + zid] = 1
	Profile.equipped = {}
	check("Siège Normal : aucune PE requise", Siege.power_required(zid, 0) == 0 and Siege.playable(zid, 0) and not Siege.power_ok(zid, 1))


func _test_pantheon() -> void:
	Profile.reset_all()
	Profile.records["league_rank"] = 4
	Profile.selected_zone = "limestone"
	var r := Pantheon.report_win("debutant", "warrior")
	Profile._lobby_view()  # (Duel.finish le fait après le bilan)
	var p: Dictionary = r.piece
	check("pièce légendaire de niveau fixe (%d), même dans la 1re zone" % int(p.get("level", 0)), int(p.rarity) == Items.LEGENDARY and absi(int(p.level) - Pantheon.PIECE_LEVEL) <= 5 and String(p.set) == "pantheon")
	var id := Pantheon.shop_id(0)
	check("pièce gagnée : à l'Armurerie (seen_gear), déjà possédée", id in Profile.seen_gear and GearShopPage.owned(id) and Pantheon.brain_of(p) == "debutant")
	var e: Dictionary = GameData.eden_by_id.get(id, {})
	var bought := GearShopPage.make(e)
	check("l'Armurerie revend la pièce des Esprits (panoplie, niveau fixe)", String(bought.get("set", "")) == "pantheon" and String(bought.slot) == "boots" and int(bought.level) == int(p.level))
	check("pièce des Esprits : hors du compte de l'Armurerie", Completion.armory_done() == 0)
	# Champion : les armes des 17 types
	for b in Pantheon.BRAINS.slice(1):
		Pantheon.report_win(String(b.id), "warrior")
	var weapons := Pantheon.shop_ids(5)
	check("Champion : 17 armes des Esprits à l'Armurerie", weapons.size() == 17 and weapons.all(func(x): return int(x) in Profile.seen_gear and GameData.eden_by_id.has(int(x))))
	var bow := GearShopPage.make(GameData.eden_by_id[Pantheon.shop_id(5, "bow")])
	check("arme des Esprits d'un autre type (arc)", Items.weapon_type_of(bow) == "bow" and String(bow.set) == "pantheon")
	# éveil : bonus 6 pièces renforcé
	var gear := {}
	for b in Pantheon.BRAINS:
		gear[String(b.slot)] = Pantheon.make_piece(b, "warrior")
	var base6: Dictionary = Items.active_set_bonuses(gear).filter(func(x): return x.set == "pantheon" and x.pieces == 6)[0]
	check("6 pièces : bonus 6 normal tant que rien n'est éveillé", (base6.stat as Dictionary).is_empty())
	for b in Pantheon.BRAINS:
		Pantheon.entry(String(b.id))["awake"] = true
	var aw6: Dictionary = Items.active_set_bonuses(gear).filter(func(x): return x.set == "pantheon" and x.pieces == 6)[0]
	check("6 pièces éveillées : bonus 6 renforcé (dégâts, recharge moitié)", float((aw6.stat as Dictionary).get("dmg_pct", 0.0)) > 0.0 and float(aw6.procs[0].cd) < float(base6.procs[0].cd))
	check("l'infobulle montre le palier éveillé", Items.describe(gear["head"]).contains("pièces éveillées"))
	# ancienne sauvegarde : cerveaux battus sans pièces à l'Armurerie
	Profile.seen_gear = []
	Pantheon.sync_seen()
	check("chargement : pièces des cerveaux battus remises à l'Armurerie", Profile.seen_gear.size() == 5 + 17)
