extends Node
## Captures des Deux Voies en partie réelle (lots MB-C et suivants, rapport R_MB_C.md) : règle la fenêtre, lance une partie
## (Moba.launch avec les options --moba-… de la ligne de commande), ouvre world.tscn, puis enregistre une image aux instants
## de partie demandés (pas en secondes réelles : une machine chargée ne décale rien).
##   Godot --path game res://tools/moba_shots.tscn -- --res=1280x720 --out=<dossier> --times=70,110,170 [--far=40] [--class=warrior]
##     [--name=…] [--autoplay] [--moba-heroes=watch] [--moba-seed=N] …
## Lignes : [mb-shots] …


## Le preneur d'images : vit sous la racine, il survit au changement de scène.
class Shooter extends Node:
	var opt := {}
	var times: Array = []
	var out := ""
	var tag := ""
	var busy := false

	func _process(_delta: float) -> void:
		if busy:
			return
		if times.is_empty():
			get_tree().quit()
			return
		if not Moba.active or Moba.t < float(times[0]):
			return
		busy = true
		await _shot(float(times.pop_front()))
		busy = false

	func _shot(t: float) -> void:
		var world := get_tree().current_scene
		if opt.has("far") and world != null and world.get("rig") != null:
			world.rig.distance = float(opt.far)
		# --focus=t<tier><b|r><voie> (ex. t1r0 : T1 rouge de la Voie du Soleil) ou core<b|r> : la caméra regarde cette structure
		if opt.has("focus") and world != null and world.get("director") != null and is_instance_valid(world.director.team):
			var dd: MobaDirector = world.director.team as MobaDirector
			var f := String(opt.focus)
			var side := 0 if "b" in f else 1
			var s: Node3D = dd.cores[side] if f.begins_with("core") else dd.structure_of(side, int(f.right(1)), int(f.substr(1, 1)))
			if s != null:
				world.rig.target = s
			for _i in 30:
				await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path := out.path_join("mbc_%s_%03d_%s.jpg" % [String(opt.get("name", "partie")), int(t), tag])
		img.save_jpg(path, 0.85)
		print("[mb-shots] %s (t=%.0f)" % [path, Moba.t])


func _ready() -> void:
	var opt := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			opt[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
		elif a.begins_with("--"):
			opt[a.substr(2)] = "1"
	if opt.has("res"):
		var wh := String(opt.res).split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
		get_window().size = Vector2i(int(wh[0]), int(wh[1]))
	var s := Shooter.new()
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	s.opt = opt
	s.tag = String(opt.get("res", "1600x900"))
	s.out = String(opt.get("out", ProjectSettings.globalize_path("user://shots")))
	DirAccess.make_dir_recursive_absolute(s.out)
	s.times = Array(String(opt.get("times", "70,110,170")).split(",")).map(func(x): return float(x))
	Profile.selected_class = String(opt.get("class", "warrior"))
	Moba.launch(Profile.selected_class, Moba.args_options(OS.get_cmdline_user_args()))
	get_tree().root.add_child.call_deferred(s)
	get_tree().change_scene_to_file.call_deferred("res://scenes/world.tscn")
