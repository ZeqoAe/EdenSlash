extends SceneTree
## Rasterise les SVG des icônes (tools/art/ico_gen.py) avec le moteur : ThorVG est déjà dans Godot, aucune bibliothèque de plus.
## Appel : Godot --headless --path game --script res://../tools/art/ico_render.gd -- <dossier svg> <dossier png>
## Écrit ico_<id>.png (128 px) et ico_<id>_64.png (64 px) ; un SVG de 128 unités rend à l'échelle 1 et 0,5.
## Les `ico_<id>.png` sont les fichiers du jeu (128) : Ico.tex lit les 128 et le moteur les réduit (mipmaps) ;
## les 64 servent à la planche et aux petites tailles (Ico.tex(id, true)).


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage : -- <dossier svg> <dossier png>")
		quit(2)
		return
	var src := String(args[0])
	var dst := String(args[1])
	DirAccess.make_dir_recursive_absolute(dst)
	var n := 0
	var bad := 0
	for f in DirAccess.get_files_at(src):
		if not f.ends_with(".svg"):
			continue
		var id := f.get_basename()
		var svg := FileAccess.get_file_as_string(src.path_join(f))
		for variant in [[1.0, ""], [0.5, "_64"]]:
			var img := Image.new()
			var err := img.load_svg_from_string(svg, float(variant[0]))
			if err != OK or img.is_empty():
				push_error("SVG illisible : " + f)
				bad += 1
				continue
			img.save_png(dst.path_join(id + String(variant[1]) + ".png"))
		n += 1
	print("[ico] %d icones rendues, %d erreurs" % [n, bad])
	quit(1 if bad > 0 else 0)
