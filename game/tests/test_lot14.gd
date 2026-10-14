extends Node
## Lot 14 : Panthéon (cerveaux, panoplie, éveil, titres), coffres d'auras, Ligue classée.
## godot --headless --path game res://tests/test_lot14.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	check("6 cerveaux dans l'ordre", Pantheon.BRAINS.size() == 6 and Pantheon.BRAINS[0].id == "debutant" and Pantheon.BRAINS[5].id == "actuel")
	check("panthéon fermé au départ", not Pantheon.available(0))
	Profile.records["league_rank"] = 4
	check("ouvert au rang Platine ; seul le Débutant est défiable", Pantheon.available(0) and not Pantheon.available(1))
	# 1re victoire
	var r := Pantheon.report_win("debutant", "warrior")
	check("1re victoire : une pièce de la panoplie dans le coffre commun", not r.piece.is_empty() and String(r.piece.set) == "pantheon" and Profile.vault.has(r.piece))
	check("pièce légendaire à l'emplacement du cerveau (bottes)", String(r.piece.slot) == "boots" and int(r.piece.rarity) == Items.LEGENDARY)
	check("coffre d'apparence rare et titre « Éveillé »", Profile.reward_chests.any(func(c): return c.type == "look_rare") and "Éveillé" in Profile.extra_titles and "Éveillé" in Achievements.titles())
	check("le cerveau suivant devient défiable", Pantheon.beaten("debutant") and Pantheon.available(1) and Pantheon.progress() == 1)
	check("même classe : rien de plus (pas de farm)", Pantheon.report_win("debutant", "warrior").is_empty())
	var chests := Profile.reward_chests.size()
	var r2 := Pantheon.report_win("debutant", "magician")
	check("nouvelle classe : un coffre d'apparence de qualité en moins", Profile.reward_chests.size() == chests + 1 and r2.chests == ["look_common"] and r2.piece.is_empty())
	# éveil : les 5 familles
	var by_family := {}
	for cid in GameData.classes:
		var f := int(GameData.class_data(cid).get("family", 1))
		if not by_family.has(f):
			by_family[f] = cid
	var awake := {}
	for f in by_family:
		awake = Pantheon.report_win("debutant", String(by_family[f]))
	check("5 familles : la pièce s'éveille et une aura légendaire arrive", Pantheon.entry("debutant").awake and Profile.reward_chests.any(func(c): return c.type == "aura_legend"))
	check("pièce éveillée marquée", Profile.vault.any(func(it): return String(it.get("pantheon", "")) == "debutant" and it.get("awakened", false)))
	# coffres d'auras
	var ch := Rewards.make("aura_rare", 10)
	Profile.reward_chests.append(ch)
	check("aperçu d'un coffre d'auras", Rewards.preview(ch).contains("aura"))
	var got := Rewards.open(ch)
	check("coffre d'auras rare : une aura rare, nouvelle", got.get("looks", []).size() == 1 and int(got.looks[0].rarity) == 2 and Profile.collected(got.looks[0]))
	# panoplie : bonus à 2 / 4 / 6 pièces
	var eq := {}
	for i in 6:
		eq["s%d" % i] = {"set": "pantheon", "slot": "head"}
	var tiers: Array = Items.set_tiers("pantheon")
	check("panoplie : bonus à 2, 4 et 6 pièces, sans statistiques brutes", tiers == [2, 4, 6] and Items.active_set_bonuses(eq).size() == 3 and Items.active_set_bonuses(eq).all(func(b): return (b.stat as Dictionary).is_empty()))
	# Ligue classée via le duel
	Profile.reset_all()
	Duel.mode = "league"
	Duel.start("warrior", "mage", 0)
	check("Ligue : à l'arme niveau 10, duel classé", Duel.bare and Duel.level == 10 and Duel.ranked())
	Duel.wins = 2
	Duel.losses = 0
	Duel.finish(true)
	check("victoire de Ligue : série 1 et maîtrise gagnée", League.streak() == 1 and int(Duel.last_report.get("mastery", 0)) > 0)
	Duel.mode = "free"
	Duel.bare = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
