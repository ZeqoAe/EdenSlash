extends Node3D
## Comptes de lieux sur plusieurs graines (aucun lieu ne doit manquer) :
## godot --headless --path game res://tools/map_stats.tscn -- [nombre]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 12
	for seed_value in n:
		var m := ProcMap.new()
		add_child(m)
		m.generate_run(1000 + seed_value * 7919)
		var merchants := m.interactables.filter(func(i): return i.kind == "merchant").size()
		print("graine %d : marchands %d, coffres %d, sanctuaires %d, lieux %d, décors %d, camps %d, plateaux %d" % [seed_value, merchants,
			m.chests.size(), m.shrines.size(), m.stations.size(), m.sites.size(), m.camps.size(), m.plateaus.size()])
		m.free()
	get_tree().quit()
