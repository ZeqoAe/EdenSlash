extends Node
## Captures du lot PRP-2 : Héros > Apparence (Dos, Arme) avec une création maison portée, menu Coffres > Vitrine, et une
## vitrine 3D des 24 créations sur le héros (vue du jeu et gros plan). Résolution : PRP2_RES=1280x720 (défaut 1600x900).
## Images : user://shots/prp2_<résolution>_*.png ; une ligne « [débord] » par contrôle visible qui sort de l'écran.
## godot --path game res://tests/shot_prp2.tscn   (APPDATA détourné : rien n'est gardé chez le joueur)

var res := Vector2i(1600, 900)
var lobby: Node


func _shot(name: String, root: Node = null) -> void:
	await get_tree().create_timer(0.8).timeout
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/prp2_%dx%d_%s.png" % [res.x, res.y, name])
	if root != null:
		_overflow(name, root)


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


func _ready() -> void:
	var env := OS.get_environment("PRP2_RES")
	if env.contains("x"):
		res = Vector2i(int(env.get_slice("x", 0)), int(env.get_slice("x", 1)))
	Training.active = true
	Settings.reset_all()
	Profile.reset_all()
	Profile.selected_class = "warrior"
	Profile.hero_made = true
	Profile.insignia = 900
	Profile.unlocked_features = ["dungeons", "forge", "armory", "chests"]
	# la moitié des créations obtenues (la vitrine montre les deux états)
	var all := PrpLooks.shop_entries()
	for i in all.size():
		if i % 2 == 0:
			Profile.collect(all[i])
	Profile.collect(PrpLooks.entry("prp_hache_mandarine"))
	Profile.collect(PrpLooks.entry("back_prp_ailes_aube"))
	Profile.set_skin("axe", "prp_hache_mandarine")
	Profile.set_worn("warrior", "back", "res://assets/player/outfits/back_prp_ailes_aube.glb")
	Profile._lobby_view()
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = res
	await get_tree().process_frame
	lobby = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	for i in 30:
		await get_tree().process_frame
	lobby._open_hero("appearance")
	var app = lobby._hero.appearance
	app._slot = "back"
	app._cat = "back"
	app.refresh()
	await _shot("1_apparence_dos", lobby._hero)
	app._slot = "weapon"
	app._cat = "weapon"
	app.refresh()
	await _shot("2_apparence_arme", lobby._hero)
	lobby._hero.close_ui()
	lobby._chests.open(0)
	var cp: ChestsPage = lobby._chests.page(0)
	cp._set_shop(2)
	await _shot("3_vitrine", lobby._chests)
	cp._vitrine_row(PrpLooks.entry("back_prp_ailes_phenix"))  # construit sans l'ajouter : ligne d'achat
	if PrpLooks.buy(PrpLooks.entry("prp_crosse_jade")):
		cp._show_loot({"looks": [PrpLooks.entry("prp_crosse_jade")]})
		cp.refresh()
	await _shot("4_vitrine_achat", lobby._chests)
	lobby.queue_free()
	await get_tree().process_frame
	await _showroom()
	get_tree().quit()


## Les créations sur le héros : armes en garde, ailes de dos ; vue du jeu (15 m, 52°) puis gros plans.
func _showroom() -> void:
	var stage := Node3D.new()
	add_child(stage)
	var envn := WorldEnvironment.new()
	envn.environment = Environment.new()
	envn.environment.background_mode = Environment.BG_COLOR
	envn.environment.background_color = Color("ccdef3")
	envn.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	envn.environment.ambient_light_color = Color(0.78, 0.76, 0.84)
	stage.add_child(envn)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	stage.add_child(sun)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.make_current()
	var looks := PrpLooks.list
	var cls_for := {}
	for cid in GameData.classes:
		var wt := String(GameData.classes[cid].get("weapon_type", ""))
		if not cls_for.has(wt):
			cls_for[wt] = cid
	var heroes: Array = []
	for i in looks.size():
		var e: Dictionary = looks[i]
		var cid := String(cls_for.get(String(e.get("wtype", "")), "warrior"))
		var cls := GameData.class_data(cid)
		var extra: Array = [String(e.model)] if String(e.slot) == "back" else []
		var m := EdenModel.instantiate_hero(cls, "", extra)
		m.scale = Vector3.ONE * GameData.HERO_SCALE
		m.position = Vector3((i % 8) * 2.4, 0, (i / 8) * 3.2)
		stage.add_child(m)
		EdenModel.attach_weapon(m, EdenModel.weapon_entry(cls, String(e.id) if String(e.slot) == "weapon" else String(GameData.weapon_type(String(cls.get("weapon_type", ""))).get("weapons", [{}])[0].get("code", ""))))
		m.rotation.y = 0.5 if String(e.slot) == "weapon" else PI + 0.35
		var ap := EdenModel.find_anim_player(m)
		var battle: String = cls.get("anims", {}).get("battle", "stand01")
		if ap and ap.has_animation(battle):
			ap.get_animation(battle).loop_mode = Animation.LOOP_LINEAR
			ap.play(battle)
		heroes.append(m)
	# vue du jeu : 15 m, 52°, au-dessus du milieu de la vitrine
	cam.fov = 52.0
	cam.look_at_from_position(Vector3(8.4, 11.5, 13.2), Vector3(8.4, 0, 3.6))
	await _shot("5_vitrine3d_vue_du_jeu")
	# gros plans : chaque création seule (arme de trois quarts face, dos de trois quarts dos)
	cam.fov = 30.0
	for i in heroes.size():
		for j in heroes.size():
			heroes[j].visible = j == i
		var h: Node3D = heroes[i]
		cam.look_at_from_position(h.position + Vector3(0.6, 2.4, 6.2), h.position + Vector3(0, 1.25, 0))
		await _shot("7_%02d_%s" % [i + 1, String(looks[i].id)])
	stage.queue_free()
