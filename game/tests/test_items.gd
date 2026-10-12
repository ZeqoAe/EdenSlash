extends Node
## Test des jets d'objets et des améliorations : godot --headless --path game res://tests/test_items.tscn

func _ready() -> void:
	var qs: Array = []
	for i in 300:
		qs.append(float(Items.generate(10, 0.0, "chest").quality))
	print("qualité min %.2f max %.2f" % [qs.min(), qs.max()])
	var it := Items.generate(5, 2.0, "chest")
	print("rareté ", it.rarity, " affixes ", it.affixes.size(), " stats ", Items.stats(it))
	var hp0: float = Items.stats(it).hp
	var log := []
	for k in 10:
		var s := Items.upgrade(it)
		log.append("+%d%s" % [it.upgrade, (" (" + s + ")") if s != "" else ""])
	print(" ".join(log))
	print("PV +0 = %d, +10 = %d (x%.2f), affixes %d" % [hp0, Items.stats(it).hp, Items.stats(it).hp / hp0, it.affixes.size()])
	print("coût +0->+1 ", Items.upgrade_cost({"level": 5, "upgrade": 0}), "  +9->+10 ", Items.upgrade_cost({"level": 5, "upgrade": 9}))
	print("désassemblage épique +10 ", Items.disassemble_yield(it), "  vente ", Items.sell_price(it))
	get_tree().quit()
