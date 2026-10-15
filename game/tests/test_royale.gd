extends Node
## Battle royale : chacun pour soi (Combatant.ffa_id), anneau, récompenses, partie complète.
## godot --headless --path game res://tests/test_royale.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	await _test_ffa()
	print("TOUT EST OK (0 échec(s))" if fails == 0 else "ÉCHECS : %d" % fails)
	get_tree().quit(fails)


## Chacun pour soi : trois héros, tous ennemis les uns des autres, même camp ou non.
func _test_ffa() -> void:
	var root := Node3D.new()
	add_child(root)
	var heroes: Array = []
	for i in 3:
		var r := ClassRival.new()
		r.setup(["warrior", "magician", "cleric"][i], 5, 1)
		r.passive = true
		root.add_child(r)
		r.global_position = Vector3(i * 4.0, 0.4, 0)
		heroes.append(r)
	await get_tree().physics_frame
	var a: ClassRival = heroes[0]
	var b: ClassRival = heroes[1]
	var c: ClassRival = heroes[2]
	check("sans chacun pour soi : un monstre ne vise aucun monstre", Combatant.hostile_targets(get_tree(), a).is_empty())
	for i in 3:
		(heroes[i] as Combatant).set_ffa(i)
	var ta := Combatant.hostile_targets(get_tree(), a)
	check("chacun pour soi : cibles = les deux autres", b in ta and c in ta and not (a in ta) and ta.size() == 2)
	check("hostile_heroes pareil", Combatant.hostile_heroes(get_tree(), b).size() == 2)
	c.is_dead = true
	check("un héros tombé n'est plus une cible", not (c in Combatant.hostile_targets(get_tree(), a)))
	c.is_dead = false
	check("le groupe de cibles du monstre suit le chacun pour soi", a._hostile_pool().size() == 2)
	# un coup au sol de A touche B (pas A)
	var hp_b := b.hp
	var hp_a := a.hp
	Telegraph.spawn(root, b.global_position, 0.0, {"damage": 40.0, "delay": 0.05, "shape": "circle", "radius": 2.0, "source": a})
	await get_tree().create_timer(0.4).timeout
	check("un coup au sol touche l'autre héros (PV %d → %d)" % [hp_b, b.hp], b.hp < hp_b)
	check("... et pas son lanceur", is_equal_approx(a.hp, hp_a))
	b.clear_ffa()
	check("clear_ffa : retiré du groupe", not b.is_in_group("ffa") and b.ffa_id == -1)
	root.queue_free()
