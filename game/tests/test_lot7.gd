extends Node
## Lot 7 : coffres lisibles (aperçu, Ouvrir tout, récapitulatif), autel en insignes, bilans.
## godot --headless --path game res://tests/test_lot7.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true  # rien n'est sauvegardé
	Settings.reset_all()
	Run.start("warrior")
	Profile.reward_chests = []
	for t in ["forge", "forge", "jewel", "gear", "set"]:
		Profile.reward_chests.append(Rewards.make(t, 30))
	check("aperçu d'un coffre de forge", Rewards.preview(Profile.reward_chests[0]).contains("parchemins") and Rewards.preview(Profile.reward_chests[0]).contains("cristaux"))
	check("aperçu d'un coffre de joaillier", Rewards.preview(Profile.reward_chests[2]).contains("gemmes"))
	check("aperçu d'un coffre d'apparence", Rewards.preview(Rewards.make("look_rare", 30)).contains("apparence"))
	var sets := Profile.reward_chests.filter(func(c): return Rewards.is_choice(c))
	var opened := Rewards.open_all(Profile.reward_chests)
	check("Ouvrir tout : 4 coffres sans choix ouverts, le coffre à choix reste", int(opened.opened) == 4 and Profile.reward_chests.size() == 1 and Profile.reward_chests[0] == sets[0])
	var rec := Rewards.summary(opened)
	check("récapitulatif lisible : « %s »" % rec, rec.contains("cristaux") and rec != "rien")
	# pièces de set : jamais une pièce déjà possédée
	var offer := Rewards.offer(sets[0])
	check("coffre à choix : 3 propositions", offer.size() == 3)
	var dup := false
	for it in offer:
		if int(it.get("eden", -1)) > 0 and GearShopPage.owned(int(it.eden)):
			dup = true
	check("aucune proposition déjà possédée", not dup)
	# autel
	Run.epoch = 1
	Profile.insignia = 0
	Run.fortune_insignia = 0
	Fortune.give(5, 30, 30)
	check("autel étage 5 : 40 insignes", Profile.insignia == 40 and Run.fortune_insignia == 40)
	Run.epoch = 3
	Fortune.give(3, 30, 30)
	check("autel : insignes × (1 + 0,25 × (époque − 1)) = 15 × 1,5", Profile.insignia == 40 + 23)
	var before := Profile.reward_chests.size()
	Fortune.give(7, 30, 30)
	check("étage 7 : un coffre d'apparence rare, plus d'équipement", Profile.reward_chests.size() == before + 1 and String(Profile.reward_chests[-1].type) == "look_rare")
	check("plus de coffre d'équipement ni de forge à l'autel", Fortune.PRIZES.all(func(p): return not (p.get("chests", []) as Array).any(func(t): return t in ["gear", "forge", "jewel", "set"])))
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
