extends Node
## Échelle de puissance de l'équipement en Survie : stats d'un équipement type à plusieurs niveaux de héros.
## godot --headless --path game res://tools/gear_probe.tscn -- [classe]

func _show(label: String, g: Dictionary) -> void:
	Run.active = true
	Run.survival = true
	Profile.equipped = g
	for lv in [1, 2, 5, 10, 15, 25, 35]:
		Run.hero_level = lv
		var st := Profile.equipment_stats()
		print("%-22s niv %2d : patk %4.0f matk %4.0f hp %5.0f def %4.0f str %3.0f agi %3.0f int %3.0f | héros atk %4.0f hp %5.0f" % [label, lv,
			st.get("patk", 0), st.get("matk", 0), st.get("hp", 0), st.get("def", 0), st.get("str", 0), st.get("agi", 0), st.get("int", 0),
			GameData.player_atk(lv), GameData.player_max_hp(lv)])


func _ready() -> void:
	var cid := "warrior"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		cid = a[0]
	var st := StarterGear.items(cid)
	for s in st:
		var it: Dictionary = st[s]
		print("  départ %-8s %s niv %d rareté %d" % [s, it.name, int(it.level), int(it.rarity)])
	_show("départ " + cid, st)
	for spec in ["1.1.0", "1.1.5", "1.3.0", "1.3.10", "1.3.10.3", "2.3.10.4"]:
		_show("mythique " + spec, StarterGear.scenario(spec, cid))
	get_tree().quit()
