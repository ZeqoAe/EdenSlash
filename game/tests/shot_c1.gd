extends Node
## Captures de la création de personnage (lot C1) : planches des coiffures, des couleurs de cheveux et des yeux (gros plans),
## puis l'écran de création (compte neuf, ancien compte, erreur de nom, manette), le lobby et Héros avec le nom.
## user://shots/c1_*.png ; taille de fenêtre : C1_RES=1280x720 (défaut 1600x900).
## godot --path game res://tests/shot_c1.tscn   (APPDATA détourné : rien du joueur n'est lu ni écrit)

var _res := "1600x900"


func _shot(name: String, wait := 0.8) -> void:
	await get_tree().create_timer(wait).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/c1_%s_%s.png" % [_res, name])


## Planche : une case par apparence, gros plan du visage.
func _plate(name: String, looks: Array, cid := "warrior", dist := 1.9, look_y := 1.5) -> void:
	var grid := GridContainer.new()
	grid.columns = 4 if looks.size() > 6 else 3
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	layer.add_child(grid)
	for lk in looks:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(v)
		var p := EquipmentPage.HeroPreview.new()
		p.spin = false
		p.idle_pose = true
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(p)
		var l := Label.new()
		l.text = String(lk.get("label", ""))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		p.look_override = lk
		p.show_hero(String(lk.get("cid", cid)), "")
		p.frame(dist, look_y, float(lk.get("yaw", 0.4)))
	await _shot(name, 2.0)
	layer.queue_free()


func _ready() -> void:
	var r := OS.get_environment("C1_RES")
	if r.contains("x"):
		_res = r
	Training.active = true
	Settings.reset_all()
	Settings.set_v("display", "resolution", _res)
	Profile.reset_all()
	Profile.selected_class = "warrior"
	# le lobby d'abord (sans lui, la fenêtre se fermait pendant la première planche)
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	if OS.get_environment("C1_ONLY") != "screens":
		var looks: Array = [{"label": "Classe (d'origine)"}]
		for h in HeroLook.HAIRS:
			looks.append({"hair": h[0], "label": h[1]})
		await _plate("1_coiffures", looks)
		looks = []
		for c in HeroLook.HAIR_COLORS:
			looks.append({"hair_color": c[0], "label": c[1]})
		await _plate("2_cheveux", looks)
		looks = [{"label": "D'origine", "yaw": 0.0}]
		for c in HeroLook.EYE_COLORS:
			looks.append({"eyes": c[0], "label": c[1], "yaw": 0.0})
		await _plate("3_yeux", looks, "warrior", 1.3, 1.42)
		looks = []
		for cid in ["warrior", "thief", "hunter", "cleric", "magician", "samurai"]:
			looks.append({"cid": cid, "hair": "l105", "hair_color": "pink", "eyes": "green", "label": cid})
		await _plate("4_classes", looks)
	# --- écran de création : compte neuf, nom au hasard
	var c := HeroCreator.open_on(lobby, true)
	await _shot("5_creation_neuf", 1.5)
	c.name_edit.text = "ab"
	c._check_name()
	await _shot("6_nom_trop_court")
	c.name_edit.text = "Kaelis"
	c._look = {"hair": "l108", "hair_color": "blond", "eyes": "violet"}
	c._sync()
	await _shot("7_choix", 1.5)
	Gamepad.active = true
	UiNav.reveal()
	UiNav.pick_default()
	c._sync()
	await _shot("8_manette")
	Gamepad.active = false
	c._apply()
	await get_tree().create_timer(0.5).timeout
	lobby._show_hero()
	lobby._refresh_ui()
	await _shot("9_lobby_nom", 1.5)
	lobby._open_hero("appearance")
	await _shot("a_heros")
	Profile.hero_name = "Seize lettres ok"  # nom le plus long : titre de Héros et badge du lobby
	lobby._hero.refresh()
	await _shot("a2_heros_nom_long")
	lobby._hero.close_ui()
	await _shot("a3_lobby_nom_long")
	Profile.hero_name = "Kaelis"
	lobby._refresh_ui()
	# ancien compte : pré-rempli, « Garder tel quel », confirmation au changement depuis Héros
	var c2 := HeroCreator.open_on(lobby, false)
	c2._look.hair_color = "green"
	c2._sync()
	c2.validate()
	await _shot("b_confirmation", 1.2)
	Profile.reset_all()
	get_tree().quit()
