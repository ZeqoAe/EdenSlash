extends Node
## Captures du lot GX-6 : Héros > Classe > Talents avec « Conseillé » et les chargements ; aperçu avant / après du build
## conseillé ; arbre conseillé posé (« Annuler ») ; fiche d'un chargement (vide, remplie) ; aperçu d'un chargement.
## Résolution : GX6_RES=1280x720 (défaut 1600x900). Images : user://shots/gx6_<résolution>_*.png ; une ligne « [débord] »
## par contrôle visible qui sort de l'écran.
## godot --path game res://tests/shot_gx6.tscn   (APPDATA détourné : rien n'est gardé chez le joueur)

var res := Vector2i(1600, 900)
var lobby: Node


func _shot(name: String, root: Node = null) -> void:
	await get_tree().create_timer(0.7).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/gx6_%dx%d_%s.png" % [res.x, res.y, name])
	if root != null:
		_overflow(name, root)


## Contrôles visibles qui sortent de l'écran (hors défilement).
func _overflow(name: String, root: Node) -> void:
	var view := Rect2(Vector2.ZERO, Vector2(get_viewport().get_visible_rect().size))
	for n in root.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or c.size.x < 2.0:
			continue
		var p := c.get_parent()
		var in_scroll := false
		while p != null:
			if p is ScrollContainer:
				in_scroll = true
				break
			p = p.get_parent()
		if in_scroll:
			continue
		var r := c.get_global_rect()
		if r.end.x > view.end.x + 1.0 or r.end.y > view.end.y + 1.0 or r.position.x < -1.0 or r.position.y < -1.0:
			print("[débord] %s : %s %s %s" % [name, c.get_class(), String(c.get("text")) if c.get("text") != null else c.name, r])


func _ask() -> Node:
	for c in get_tree().root.find_children("*", "", true, false):
		if c is InfoCard.Ask and not c.is_queued_for_deletion():
			return c
	return null


func _ready() -> void:
	var env := OS.get_environment("GX6_RES")
	if env.contains("x"):
		res = Vector2i(int(env.get_slice("x", 0)), int(env.get_slice("x", 1)))
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.hero_name = "Nico"
	HeroLevel.ensure()
	Profile.records["epochs_cleared"] = 1
	Profile.best_level = 60
	Profile.expertise["warrior"] = 40000  # maîtrise 30 environ : 60 points
	for id in [52582, 52582, 52582, 52582, 52582, 52582, 52582, 52582, 52582, 52582, 54699, 52586, 52586, 52586, 52586, 52586, 52584, 52584]:
		Profile.add_talent("warrior", id)
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = res
	await get_tree().process_frame
	await get_tree().process_frame
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	lobby._open_hero("class")
	var hero: HeroScreen = lobby._hero
	var tp: TalentsPage = hero.talents
	tp.show_sub("talents")
	await _shot("1_talents", hero)
	# --- aperçu du build conseillé ---
	tp._advise.pressed.emit()
	await get_tree().process_frame
	await _shot("2_conseille_apercu", _ask())
	var ask = _ask()
	if ask:
		ask.ok_button.pressed.emit()
	await get_tree().create_timer(0.4).timeout
	await _shot("3_conseille_pose", hero)
	# --- chargements : fiche vide, enregistrer, fiche remplie, aperçu ---
	tp.open_load(0)
	await get_tree().process_frame
	tp._load_dialog.name_edit.text = "Donjons"
	await _shot("4_chargement_vide", tp._load_dialog)
	tp._load_dialog._save()
	await get_tree().process_frame
	Profile.reset_talents("warrior")
	for id in [52583, 52583, 52583, 52583, 52583, 52585, 52585, 52585]:
		Profile.add_talent("warrior", id)
	Profile.save_talent_load("warrior", 1, "Duel")
	tp.refresh()
	await _shot("5_chargements", hero)
	tp.open_load(0)
	await get_tree().process_frame
	await _shot("6_chargement_rempli", tp._load_dialog)
	tp._load_dialog._load()
	await get_tree().process_frame
	await _shot("7_chargement_apercu", _ask())
	print("[shot_gx6] fini : user://shots/gx6_%dx%d_*.png" % [res.x, res.y])
	get_tree().quit()
