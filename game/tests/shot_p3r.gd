extends Node
## Passe P3 : bilan de Survie à mi-animation et à la fin (user://shots/p3r_*.png). APPDATA détourné.


func _shot(name: String, wait: float) -> void:
	await get_tree().create_timer(wait, true).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/p3r_%s_%dx%d.png" % [name, get_viewport().size.x, get_viewport().size.y])


func _ready() -> void:
	Settings.reset_all()
	if OS.get_environment("P3_RES") != "":
		Settings.set_v("display", "resolution", OS.get_environment("P3_RES"))
		await get_tree().create_timer(0.5).timeout
	Profile.reset_all()
	Run.start_survival("warrior", 2)
	Run.kills = 212
	Run.elites = 9
	Run.max_level = 17
	Run.stage = 3
	Run.gold = 480
	Run.started_at = Time.get_ticks_msec() - (14 * 60 + 12) * 1000
	Run.seen_items = [1001, 1002, 1003]
	Profile.reward_chests.append(Rewards.make("look_rare", 40, true))
	Profile.reward_chests.append(Rewards.make("forge", 40, true))
	Profile.reward_chests.append(Rewards.make("forge", 40, true))
	Profile.keys = 2
	Run.combo_best = 18420.0
	Run.finish("victoire")
	Run.stars_gained = 1
	Run.expertise_levels = 1
	var r := ResultsScreen.new()
	add_child(r)
	r.show_results()
	await _shot("mid", 0.7)
	await _shot("end", 1.8)
	get_tree().quit()
