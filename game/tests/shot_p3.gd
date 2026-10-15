extends Node
## Passe P3 : lance la Survie à l'étape N dans la scène du monde (captures du HUD, avec compétences,
## foule et boss). Arguments après `--` : stage=N  boss_at=S (entre dans l'arène du boss à S secondes)
## puis les arguments habituels du monde (--autoplay --god --rage --shots=… --quit-at=…).
## APPDATA détourné : rien n'est écrit chez le joueur.


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Settings.reset_all()
	if OS.get_environment("P3_RES") != "":
		Settings.set_v("display", "resolution", OS.get_environment("P3_RES"))  # captures à 1280x720 (le réglage prime sur --resolution)
	Profile.selected_class = "warrior"
	var st := 1
	var boss_at := -1.0
	var guide_at := -1.0
	for a in args:
		if a.begins_with("stage="):
			st = int(a.trim_prefix("stage="))
		elif a.begins_with("boss_at="):
			boss_at = float(a.trim_prefix("boss_at="))
		elif a.begins_with("guide_at="):
			guide_at = float(a.trim_prefix("guide_at="))  # « ? Aide » de la pause (ouvrir la pause avant : --pause=0)
	Run.start_survival("warrior", 1)
	Run.stage = st
	Run.zone_id = Epochs.zone(1, st)
	for sk in Run.class_data().get("skills", []).slice(0, 4):
		Run.skills.append({"id": int(sk.id), "rank": 1})
	var world: Node = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	if guide_at >= 0.0:
		await get_tree().create_timer(guide_at).timeout
		world.pause_menu.open_guide()
	if boss_at >= 0.0:
		await get_tree().create_timer(boss_at).timeout
		world.director.debug_enter_dungeon()
