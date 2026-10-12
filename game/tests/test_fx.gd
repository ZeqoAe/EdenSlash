extends Node3D
## Banc d'essai des effets : godot --path game res://tests/test_fx.tscn -- s36041
## Joue l'effet à côté d'un héros et enregistre 4 images (user://shots/fx_<nom>_<i>.png).

func _ready() -> void:
	var name: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "s36041"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.3, 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var hero := EdenModel.instantiate("res://assets/player/samurai/samurai.glb")
	hero.scale = Vector3.ONE * 1.3
	add_child(hero)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 7, 8)
	add_child(cam)
	cam.look_at(Vector3(0, 1, 0))
	var fx := EdenFx.play(self, name, Vector3.ZERO, 0.0, 1.3)
	print("effet ", name, " ", fx != null, " durée ", fx._data.get("duration") if fx else 0)
	DirAccess.make_dir_recursive_absolute("user://shots")
	for i in 4:
		await get_tree().create_timer(0.12 + i * 0.15).timeout
		get_viewport().get_texture().get_image().save_png("user://shots/fx_%s_%d.png" % [name, i])
	get_tree().quit()
