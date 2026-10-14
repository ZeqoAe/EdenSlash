extends Node
## Restes : niveau du Duel équipé, insensible aux renversements, coups plafonnés en gris.
## godot --headless --path game res://tests/test_lot17.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Run.start("warrior")
	var p := Player.new()
	p.level = 10
	add_child(p)
	await get_tree().physics_frame
	p.set_physics_process(false)
	check("sans certificat : étourdissable", not p.knock_immune())
	Profile.certificates = ["knight/c50203"]
	check("certificat « Esprit clair » : insensible aux renversements", p.knock_immune())
	p.stun(1.0)
	check("l'étourdissement est ignoré", p._state != "stun")
	Profile.certificates = []
	p.stun(1.0)
	check("sans le certificat il passe", p._state == "stun")
	Profile.equipped = {}
	check("niveau du Duel équipé sans objet : 1", Duel.gear_level() == 1)
	check("6 cerveaux du Panthéon figés", Pantheon.BRAINS.all(func(b): return FileAccess.file_exists(MlDuelPilot.frozen_path(String(b.id)))))
	Duel.mode = "pantheon"
	check("Panthéon : le cerveau figé est utilisé", MlDuelPilot.brain_path("actuel") == MlDuelPilot.frozen_path("actuel"))
	Duel.mode = "free"
	check("hors Panthéon : cerveau d'entraînement", MlDuelPilot.brain_path("actuel").contains("cerveau_actuel"))
	# un cerveau adverse en équipe (si le cerveau Débutant est présent sur ce PC)
	if MlDuelPilot.available().any(func(b): return b[0] == "debutant"):
		Duel.active = false
		Duel.mode = "arena2"
		Duel.team_allies = ["cleric"]
		Duel.extra_foes = ["magician"]
		Duel.pilot = "debutant"
		Duel.start("warrior", "hunter", 2)
		var world: Node = load("res://scenes/world.tscn").instantiate()
		get_tree().root.add_child.call_deferred(world)
		await get_tree().create_timer(8.0).timeout
		var dd: DuelDirector = world.director.duel
		check("équipe : le premier adversaire est un héros piloté par un cerveau", is_instance_valid(dd._foe) and dd._foe.foe and dd._foes.size() == 1)
		for _i in 80:
			await get_tree().physics_frame
		_kill(dd._foes[0], world.player)
		for _i in 10:
			await get_tree().physics_frame
		check("l'adversaire scripté tombé, le cerveau debout : la manche continue", dd.phase == "fight" and Duel.wins == 0)
		_kill(dd._foe, world.player)
		for _i in 60:
			if Duel.wins >= 1:
				break
			await get_tree().physics_frame
		check("cerveau tombé aussi : manche gagnée", Duel.wins == 1)
		world.queue_free()
		Duel.active = false
		Duel.mode = "free"
		Duel.pilot = ""
		Duel.team_allies = []
		Duel.extra_foes = []
		Duel.bare = false
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Tue [param t] malgré l'esquive (20 % en duel) : on réessaie.
func _kill(t, src) -> void:
	for _i in 12:
		if t.is_dead:
			return
		t.hp = 1.0
		t.take_damage(1e12, src, false)
