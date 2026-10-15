extends Node
## Lance une activité de Tower (donjon, siège, ruée) puis la scène du monde, pour les captures du HUD :
## godot --path game res://tests/shot_hud.tscn -- dungeon|siege|rush --autoplay --god --shots=12 --shot-prefix=hud_donjon --quit-at=14


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Settings.reset_all()
	if OS.get_environment("P3_RES") != "":
		Settings.set_v("display", "resolution", OS.get_environment("P3_RES"))  # captures à 1280x720 (le réglage prime sur --resolution)
	Profile.selected_class = "warrior"
	if "siege" in args:
		Tower.start_siege("warrior", "limestone", 0, [])
	elif "rush" in args:
		Tower.start_dungeon("warrior", Dungeons.RUSH, 0, [])
	else:
		Tower.start_dungeon("warrior", "limestone", 0, [])
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
