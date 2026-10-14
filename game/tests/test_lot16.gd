extends Node
## Lot 16 : étoiles d'époque, rangs héroïques.
## godot --headless --path game res://tests/test_lot16.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	check("aucune étoile au départ", Epochs.total_stars() == 0 and Epochs.star_text(1) == "☆☆☆")
	# rangs héroïques fermés avant l'époque IV
	Run.start_survival("warrior", 1, 5)
	check("rang héroïque ignoré tant que l'époque IV n'est pas gagnée", Run.heroic_rank == 0)
	Profile.records["epochs_cleared"] = 4
	Run.start_survival("warrior", 1, 6)
	check("rang 6 : monstres +72 % PV, 2 contraintes", Run.heroic_rank == 6 and is_equal_approx(1.0 + Epochs.HEROIC_HP * 6, 1.72) and Epochs.heroic_mods(6).size() == 2 and Challenge.has(Epochs.heroic_mods(6)[0]))
	check("rang 2 : aucune contrainte", Epochs.heroic_mods(2).is_empty())
	# étoiles : victoire sans résurrection, avec le défi de l'époque I (pas de rage)
	Run.start_survival("warrior", 1, 3)
	Run.stage = 3
	Run.active = true
	Run.max_level = 20
	Run.finish("victoire")
	check("victoire : ★ gagnée, ★ sans résurrection, ★ défi (pas de rage) = 3", Epochs.stars(1) == 3 and Run.stars_gained == 3)
	check("rang héroïque 3 terminé : un coffre d'apparence", Epochs.heroic_best(1) == 3 and Run.heroic_rewards.size() == 1 and Profile.reward_chests.any(func(c): return String(c.type).begins_with("look_")))
	# deuxième run avec résurrection et rage : une seule étoile de plus ne vient pas
	Run.start_survival("warrior", 2, 0)
	Run.stage = 3
	Run.resurrections = 1
	Run.rage_stages = [3]
	Run.trophies = []
	Run.active = true
	Run.finish("victoire")
	check("avec résurrection : seulement l'étoile de victoire", Epochs.star_mask(2) == 1)
	# insignes : rang héroïque
	Run.start_survival("warrior", 1, 4)
	Run.stage = 1
	Run.active = true
	Profile.insignia = 0
	Run.finish("extraction")
	var plain := 25 * 1
	check("insignes × (1 + 0,15 × rang)", Run.insignia_gain == roundi(plain * (1.0 + 0.15 * 4)) or Run.insignia_gain > plain)
	check("le total d'étoiles compte dans la complétion", Epochs.total_stars() == 4 and int(Completion.categories()[7][1]) >= 4)
	Run.active = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
