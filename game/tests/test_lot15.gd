extends Node
## Lot 15 : Arènes 2v2 / 3v3 et Gantelet (équipes dans le directeur de duel).
## godot --headless --path game res://tests/test_lot15.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	# règles des profils d'équipe
	Duel.active = true
	Duel.mode = "arena2"
	check("arène 2v2 : échelle 0,022, soins ×0,5", ModeRules.profile_name() == "arena2" and is_equal_approx(PvpCaps.damage_scale(), 0.022) and is_equal_approx(PvpCaps.heal_mult(), PvpCaps.HEAL_MULT * 0.5))
	Duel.mode = "arena3"
	check("arène 3v3 : échelle 0,018", is_equal_approx(PvpCaps.damage_scale(), 0.018))
	Duel.mode = "gauntlet"
	check("Gantelet : règles du duel équipé", ModeRules.profile_name() == "gauntlet" and is_equal_approx(PvpCaps.damage_scale(), PvpCaps.DAMAGE_SCALE))
	Duel.active = false
	Duel.mode = "free"
	# 2v2 en scène
	Duel.mode = "arena2"
	Duel.team_allies = ["cleric"]
	Duel.extra_foes = ["magician"]
	Duel.start("warrior", "hunter", 2)
	check("arène : à l'arme niveau 10, classée", Duel.bare and Duel.level == 10 and Duel.ranked())
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(8.0).timeout
	var dd: DuelDirector = world.director.duel
	check("2 adversaires et 1 allié IA en place", dd._foes.size() == 2 and dd._allies.size() == 1)
	check("l'allié est du camp du joueur, les adversaires des monstres", dd._allies[0].team == Combatant.Team.PLAYER and dd._foes[0].team == Combatant.Team.MONSTER)
	for i in 80:
		await get_tree().physics_frame
	check("le combat est lancé", dd.phase == "fight")
	# un seul adversaire tombe : la manche continue
	dd._foes[0].hp = 1.0
	dd._foes[0].take_damage(1e12, world.player, false)
	await get_tree().physics_frame
	check("un adversaire tombé ne termine pas la manche", dd.phase == "fight" and Duel.wins == 0)
	dd._foes[1].hp = 1.0
	dd._foes[1].take_damage(1e12, world.player, false)
	await get_tree().physics_frame
	check("tous les adversaires à terre : manche gagnée", Duel.wins == 1 and dd.phase == "between")
	# le joueur tombe mais l'allié se bat : la manche continue
	for i in 220:
		await get_tree().physics_frame
	check("manche suivante lancée", Duel.round_n == 2)
	for i in 200:
		await get_tree().physics_frame
	world.player.hp = 1.0
	world.player.take_damage(1e12, dd._foes[0], false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check("joueur à terre, allié debout : la manche n'est pas perdue", dd.phase == "fight" and Duel.losses == 0 and dd._player_out)
	dd._allies[0].hp = 1.0
	dd._allies[0].take_damage(1e12, dd._foes[0], false)
	for i in 5:
		await get_tree().physics_frame
	check("allié à terre aussi : manche perdue", Duel.losses == 1)
	world.queue_free()
	Duel.active = false
	Duel.mode = "free"
	Duel.team_allies = []
	Duel.extra_foes = []
	Duel.bare = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
