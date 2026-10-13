extends Node
## Insensibilité aux contrôles (Combatant.CC_TYPES) :
## godot --headless --path game res://tests/test_cc.tscn

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	var c := Combatant.new()
	add_child(c)
	c.add_status("stun", 1.0)
	check("renversé appliqué", c.has_status("stun"))
	check("insensibilité au renversement en buff", c.has_status("imm_stun") and StatusDb.is_buff("imm_stun"))
	var end := float(c.statuses.stun)
	c.add_status("stun", 2.0)
	check("renversé pas prolongé pendant qu'il dure", is_equal_approx(float(c.statuses.stun), end))
	c.add_status("fear", 1.5)
	check("autre type (terreur) accepté pendant le renversement", c.has_status("fear"))
	c.tick_statuses(1.2)
	check("renversé fini", not c.has_status("stun"))
	c.add_status("stun", 1.0)
	check("renversé refusé pendant l'insensibilité", not c.has_status("stun"))
	c.add_status("bleed", 3.0)
	check("les effets qui ne sont pas des contrôles passent", c.has_status("bleed"))
	c.tick_statuses(Combatant.CC_IMMUNITY)
	check("insensibilité finie après %.0f s" % Combatant.CC_IMMUNITY, not c.has_status("imm_stun"))
	c.add_status("stun", 1.0)
	check("renversé de nouveau possible", c.has_status("stun"))
	check("nom affiché", StatusDb.display_name("imm_fear") == "Insensible à la terreur")
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit()
