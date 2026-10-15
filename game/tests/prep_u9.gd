extends Node
## Prépare le profil de test pour les captures du HUD : godot --path game res://tests/prep_u9.tscn -- guided|free [advanced]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Settings.reset_all()
	Profile.reset_all()
	Tutorial.set_mode("guided" if "guided" in args else "free")
	if "advanced" in args:
		Profile.gold = 0
		Profile.insignia = 380
		Profile.materials["crystal"] = 420
	Profile.save_profile()
	get_tree().quit()
