extends Node
## Lot 14 en jeu : un duel du Panthéon contre un cerveau, dans la vraie scène.
## godot --headless --path game res://tests/test_lot14b.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.reset_all()
	Profile.records["league_rank"] = 4
	if not Pantheon.brain_file_present("debutant"):
		print("(cerveau absent sur ce PC : test ignoré)")
		get_tree().quit(0)
		return
	Duel.mode = "pantheon"
	Duel.pilot = "debutant"
	Duel.start("warrior", "magician", 3)
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(8.0).timeout
	var d: RunDirector = world.director
	check("duel du Panthéon : directeur de duel, niveau 10, à l'arme", d.state == "duel" and Duel.level == 10 and Duel.bare and Duel.ranked())
	check("le cerveau pilote un héros ennemi", d.duel._foe != null or d.duel._pilot != null)
	check("l'aide automatique est coupée en duel classé", not world.player._auto_combo() and world.player._tower_duel())
	check("héros du joueur sans équipement ni méta", world.player.weapon_item().has("auto_variant") and is_equal_approx(world.player.dmg_mult, 1.0))
	world.queue_free()
	Duel.active = false
	Duel.mode = "free"
	Duel.bare = false
	Duel.pilot = ""
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)
