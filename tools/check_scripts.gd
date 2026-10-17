extends SceneTree
## Pilote Godot de tools/check_scripts.py (ne pas lancer seul).
## Charge (compile) chaque script, puis chaque scène, de la liste donnée après `--` ; écrit une ligne
## « ECHEC_SCRIPT <chemin> » / « ECHEC_SCENE <chemin> » pour chaque ressource qui ne se charge pas,
## « CHECK_DEBUT » / « CHECK_FIN <n> » autour du travail. Les messages d'erreur de Godot (Parse Error...)
## sont relus par le script Python. Rien n'est instancié : aucun code du jeu n'est exécuté ici.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("check_scripts.gd : liste de fichiers attendue après --")
		quit(2)
		return
	var paths := FileAccess.get_file_as_string(args[0]).split("\n", false)
	print("CHECK_DEBUT")
	var n := 0
	for p in paths:
		p = p.strip_edges()
		if p.is_empty():
			continue
		n += 1
		print("CHECK_FICHIER ", p)
		if p.ends_with(".gd"):
			var s = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REUSE)
			if s == null or not (s is Script):
				print("ECHEC_SCRIPT ", p)
			elif not s.can_instantiate() and not (s.has_method("is_abstract") and s.is_abstract()):
				print("ECHEC_SCRIPT ", p)
		else:
			var r = ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REUSE)
			if r == null:
				print("ECHEC_SCENE ", p)
			elif r is PackedScene and not r.can_instantiate():
				print("ECHEC_SCENE ", p)
	print("CHECK_FIN ", n)
	quit(0)
