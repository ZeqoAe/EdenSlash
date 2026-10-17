extends Node
## Lot PRP-2 : créations maison (PrpLooks, data/prp_looks.json) : chaque GLB se charge, budget de triangles, repère
## (EdenRoot, W1 / W2, moitiés d'ailes), accroche à l'os sur un vrai héros, battement des ailes (et immobile avec
## « Réduire les animations »), présence dans Héros > Apparence (armes, dos), Archive.skins, coffres d'apparence,
## vitrine en insignes (achat, refus, aucune stat), aucun doublon d'identifiant.
## godot --headless --path game res://tests/test_prp_looks.tscn

const PATH := "user://prp2_test.json"
const TRI_MAX := {"weapon": 3000, "back": 5000}
const KB_MAX := 600

var fails := 0


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	Settings.reset_all()
	Profile.selected_class = "warrior"
	Profile.reset_all()
	var main_path: String = Profile.save_path
	Profile.save_path = PATH
	_test_table()
	_test_models()
	await _test_flap()
	_test_lists()
	_test_shop()
	Profile.save_path = main_path
	Profile.reset_all()
	Settings.reset_all()
	for ext in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + ext):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + ext))
	print("\nPRP-2 : %s (%d échec(s))" % ["TOUT VERT" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_table() -> void:
	var raw = JSON.parse_string(FileAccess.get_file_as_string(PrpLooks.PATH))
	var rows: Array = raw.get("looks", []) if raw is Dictionary else []
	check("table : 24 créations au moins (%d)" % rows.size(), rows.size() >= 24)
	check("table : toutes chargées par PrpLooks (%d / %d)" % [PrpLooks.list.size(), rows.size()], PrpLooks.list.size() == rows.size())
	var ids := {}
	var nums := {}
	var dup := false
	var weapons := 0
	var backs := 0
	var wtypes := {}
	for e in rows:
		dup = dup or ids.has(String(e.id)) or nums.has(int(e.num))
		ids[String(e.id)] = true
		nums[int(e.num)] = true
		if String(e.slot) == "weapon":
			weapons += 1
			wtypes[String(e.wtype)] = true
		else:
			backs += 1
	check("aucun doublon d'identifiant ni de numéro", not dup)
	check("armes : 14 au moins (%d), 13 types au moins (%d)" % [weapons, wtypes.size()], weapons >= 14 and wtypes.size() >= 13)
	check("dos : 10 au moins (%d)" % backs, backs >= 10)
	var catalog_clash := false
	for e in rows:
		var x: Dictionary = GameData.collection_by_id.get(int(e.num), {})
		catalog_clash = catalog_clash or not x.has("prp")
	check("numéros de collection libres dans le catalogue (le trésor trouvé est bien le nôtre)", not catalog_clash)
	var types_ok := true
	for e in rows:
		if String(e.slot) == "weapon":
			types_ok = types_ok and GameData.weapon_types.has(String(e.wtype)) and GameData.skin_by_code.has(String(e.id))
		else:
			types_ok = types_ok and GameData.cosmetic_by_code.has(String(e.id)) and String(e.model).get_file().begins_with("back_prp_")
	check("armes : type du jeu et apparence enregistrée ; dos : cosmétique enregistré, fichier back_prp_*", types_ok)
	var names_ok := true
	for x in PrpLooks.shop_entries():
		names_ok = names_ok and String(x.name).length() >= 4 and not x.has("aura") and not x.has("stat") and FileAccess.file_exists(String(x.icon))
	check("noms, icônes présents, aucune stat ni aura", names_ok)
	var icons_ok := true
	for e in rows:
		var big := load(String(e.icon)) as Texture2D
		var small := load(String(e.icon_64)) as Texture2D
		icons_ok = icons_ok and big != null and small != null and big.get_width() == 128 and small.get_width() == 64
	check("icônes 128 et 64 px", icons_ok)


## Nombre de triangles d'un modèle (premier niveau de détail de chaque surface).
func _tris(root: Node) -> int:
	var n := 0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
			n += idx.size() / 3 if idx.size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func _test_models() -> void:
	var cls := GameData.class_data("warrior")
	var load_ok := true
	var budget_ok := true
	var weight_ok := true
	var frame_ok := true
	var bone_ok := true
	var worst := ""
	for e in PrpLooks.list:
		var path := String(e.model)
		var kb := FileAccess.get_file_as_bytes(path).size() / 1024
		weight_ok = weight_ok and kb <= KB_MAX
		var ps := load(path) as PackedScene
		if ps == null:
			load_ok = false
			print("   ne se charge pas : ", path)
			continue
		var inst := ps.instantiate()
		var t := _tris(inst)
		if t > int(TRI_MAX[String(e.slot)]):
			budget_ok = false
			worst += " %s=%d" % [String(e.id), t]
		var root := inst.find_child("EdenRoot", true, false)
		if String(e.slot) == "weapon":
			frame_ok = frame_ok and root != null and inst.find_child("W1", true, false) != null and inst.find_child("W2", true, false) != null
		else:
			frame_ok = frame_ok and root != null and inst.find_child("Skeleton3D", true, false) == null
			if bool(e.get("flap", false)):
				frame_ok = frame_ok and inst.find_child("AileG", true, false) != null and inst.find_child("AileD", true, false) != null
		inst.free()
		# sur un vrai héros : arme dans la main, dos sur l'os du haut du dos
		var hero := EdenModel.instantiate_hero(cls)
		add_child(hero)
		if String(e.slot) == "weapon":
			var att := EdenModel.attach_weapon(hero, EdenModel.weapon_entry(cls, String(e.id)))
			bone_ok = bone_ok and att != null and String(att.bone_name) in ["Bip01 Prop1", "Bip01 R Hand", "Bip01 L Hand"] \
				and EdenModel.bounds(att.get_child(0) as Node3D).get_longest_axis_size() <= EdenModel.MAX_WEAPON_SIZE + 0.01
		else:
			EdenModel.dress(hero, path)
			var found := false
			var skel := hero.find_child("Skeleton3D", true, false) as Skeleton3D
			for c in skel.get_children():
				if c is BoneAttachment3D and String(c.get_meta("part", "")) == path and String((c as BoneAttachment3D).bone_name) == EdenModel.BACK_BONE:
					found = true
			bone_ok = bone_ok and found
		hero.free()
	check("chaque GLB se charge", load_ok)
	check("triangles : armes ≤ 3 000, dos ≤ 5 000%s" % worst, budget_ok)
	check("poids : chaque GLB ≤ %d Ko" % KB_MAX, weight_ok)
	check("repère : EdenRoot, W1 / W2 (armes), moitiés AileG / AileD (ailes battantes), sans squelette", frame_ok)
	check("accroche à l'os sur un héros (main ; haut du dos « %s »)" % EdenModel.BACK_BONE, bone_ok)


func _test_flap() -> void:
	var flap: Dictionary = {}
	for e in PrpLooks.list:
		if bool(e.get("flap", false)):
			flap = e
			break
	check("au moins une paire d'ailes battantes", not flap.is_empty())
	if flap.is_empty():
		return
	var hero := EdenModel.instantiate_hero(GameData.class_data("warrior"))
	add_child(hero)
	EdenModel.dress(hero, String(flap.model))
	var flappers := hero.find_children("*", "PrpWingFlap", true, false)
	check("battement posé par EdenModel.dress", flappers.size() == 1)
	if flappers.is_empty():
		hero.queue_free()
		return
	var wing := hero.find_child("AileD", true, false) as Node3D
	var rest := wing.transform
	UiFeel.reduce_motion = false
	(flappers[0] as PrpWingFlap)._t = 0.0
	for i in 20:
		await get_tree().process_frame
	(flappers[0] as Node)._process(0.45)
	check("les ailes bougent (rotation autour de l'axe du dos)", not wing.transform.basis.is_equal_approx(rest.basis) and wing.transform.origin.is_equal_approx(rest.origin))
	UiFeel.reduce_motion = true
	(flappers[0] as Node)._process(0.3)
	check("« Réduire les animations » : ailes immobiles, ouvertes", wing.transform.basis.is_equal_approx(rest.basis))
	UiFeel.reduce_motion = bool(Settings.get_v("interface", "ui_reduce_motion"))
	hero.queue_free()


func _test_lists() -> void:
	# Héros > Apparence > Dos : la liste des cosmétiques « back » commence par les nôtres
	var backs := GameData.cosmetics.filter(func(c): return String(c.get("cat", "")) == "back")
	check("Héros > Apparence > Dos : créations en tête de liste", not backs.is_empty() and backs[0].has("prp"))
	var n_backs := backs.filter(func(c): return c.has("prp")).size()
	check("Héros > Apparence > Dos : %d créations listées" % n_backs, n_backs == PrpLooks.list.filter(func(e): return String(e.slot) == "back").size())
	# Héros > Apparence > Arme : apparences de la collection (cat. 4, skin)
	var skins := GameData.collection.filter(func(x): return x.has("skin") and x.has("prp"))
	check("Héros > Apparence > Arme : %d créations listées" % skins.size(), skins.size() == PrpLooks.list.filter(func(e): return String(e.slot) == "weapon").size())
	# obtenue : visible dans Archive.skins de son type et portée par le héros
	var x: Dictionary = skins[0]
	check("verrouillée tant qu'elle n'est pas obtenue", not Profile.collected(x))
	Profile.collect(x)
	var listed := Archive.skins(String(x.skin.wtype)).any(func(sk): return String(sk.code) == String(x.code))
	check("obtenue : dans Archive.skins(%s)" % String(x.skin.wtype), listed)
	Profile.set_skin(String(x.skin.wtype), String(x.code))
	check("choisie : Archive.chosen_skin la rend", String(Archive.chosen_skin(String(x.skin.wtype)).get("code", "")) == String(x.code))
	Profile.set_skin(String(x.skin.wtype), "")
	# dos obtenu par le trésor de collection -> cosmétique débloqué
	var bx := PrpLooks.entry(String(backs[0].id))
	Profile.collect(bx)
	check("dos obtenu : cosmétique débloqué (Profile.unlock_outfit)", Profile.outfit_unlocked(String(backs[0].id)))
	# coffres d'apparence : nos créations sont dans le tirage
	var pool := GameData.collection.filter(func(c): return c.has("prp") and not Profile.collected(c) \
		and (c.has("skin") or (int(c.get("cat", 9)) <= 3 and GameData.cosmetic_by_code.has(String(c.get("code", ""))))))
	check("coffres d'apparence : %d créations encore à tirer" % pool.size(), pool.size() == PrpLooks.list.size() - 2)
	var seen := false
	seed(7)
	for i in 1000:
		var got := Rewards.roll_look(["look_common", "look_rare", "look_epic", "look_legend"][i % 4])
		if got.has("prp"):
			seen = true
			break
	check("Rewards.roll_look peut donner une création", seen)
	check("Collection : catégorie Dos et Armes contiennent les créations", Archive.entries("c:2").any(func(e): return e.has("prp")) and Archive.entries("c:4").any(func(e): return e.has("prp")))


func _test_shop() -> void:
	var all := PrpLooks.shop_entries()
	check("vitrine : toutes les créations", all.size() == PrpLooks.list.size())
	var x: Dictionary = {}
	for e in all:
		if not Profile.collected(e):
			x = e
			break
	Profile.insignia = 0
	check("vitrine : refus sans insignes", not PrpLooks.buy(x) and not Profile.collected(x))
	Profile.insignia = 5000
	var before := Profile.insignia
	check("vitrine : achat", PrpLooks.buy(x) and Profile.collected(x))
	check("vitrine : prix retiré (%d)" % PrpLooks.price(x), Profile.insignia == before - PrpLooks.price(x))
	check("vitrine : pas de second achat", not PrpLooks.buy(x) and Profile.insignia == before - PrpLooks.price(x))
	var prices_ok := true
	for e in all:
		prices_ok = prices_ok and PrpLooks.price(e) == int(PrpLooks.PRICES[int(e.rarity)])
	check("vitrine : prix par rareté", prices_ok)
	# page des coffres : l'onglet Vitrine se construit
	var page := ChestsPage.new()
	add_child(page)
	page._set_shop(2)
	var rows := page.find_children("*", "PanelContainer", true, false).filter(func(p): return String(p.get_meta("report", "")).begins_with("Vitrine"))
	check("menu Coffres > Vitrine : une ligne par création (%d)" % rows.size(), rows.size() == all.size())
	page.queue_free()
