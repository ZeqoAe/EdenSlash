extends Node
## Passe P15 : indice de puissance d'équipement en run (MonsterScaling.gear_index) pour les équipements de mesure
## (StarterGear : compte neuf, « E.C.N[.G] »), à plusieurs niveaux du héros, et coefficients PV / dégâts des monstres
## à l'époque I et à l'époque II (niveau 15). Sert à régler MonsterScaling.EPOCH_BAND.
## godot --headless --path game res://tools/power_probe.tscn [-- warrior,magician]

const SPECS := ["new", "1.1.0", "1.1.3", "1.3.5", "1.3.10.3", "2.3.10.3", "2.3.10.4", "3.3.10.4", "4.3.10.4"]


func _ready() -> void:
	var classes := ["warrior", "magician", "hunter", "cleric", "knight"]
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			classes = Array(a.split(","))
	var was := Profile.equipped.duplicate()
	Run.active = true
	Run.survival = true
	for spec in SPECS:
		var line := "%-10s" % spec
		for lv in [5, 15, 35]:
			Run.hero_level = lv
			var vals: Array = []
			for cid in classes:
				Profile.equipped = StarterGear.items(cid) if spec == "new" else StarterGear.scenario(spec, cid)
				vals.append(MonsterScaling.gear_index())
			vals.sort()
			line += "  niv %2d : %.2f (%.2f-%.2f)" % [lv, vals[vals.size() / 2], vals[0], vals[-1]]
			if lv == 15:
				var med: float = vals[vals.size() / 2]
				var k1 := MonsterScaling.target(med, MonsterScaling.epoch_band(1))
				var k2 := MonsterScaling.target(med, MonsterScaling.epoch_band(2))
				line += " [E I ×%.2f/×%.2f · E II ×%.2f/×%.2f]" % [k1.x, k1.y, k2.x, k2.y]
		print(line)
	Profile.equipped = was
	Run.active = false
	get_tree().quit()
