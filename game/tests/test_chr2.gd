extends Node
## Lot CHR-2 : « Héros détaillé » (ClassPremium, réglage display.hero_detail) du Ninja du Tourbillon.
## Animations neuves (bibliothèque chr2_ninja.res, dans le dépôt) : mêmes longueurs que les animations d'Eden qu'elles
## remplacent, jouées à leur place sans changer le calage du jeu (impacts et durée d'action identiques réglage mis / coupé) ;
## poses procédurales remplacées ; une classe d'Eden n'a rien. Tête détaillée (fichiers HORS dépôt) : vérifiée seulement si
## elle est sur ce PC (sinon : repli sur l'apparence de CHR-1, vérifié aussi).
## godot --headless --path game res://tests/test_chr2.tscn

const CID := "whirl_ninja"

var fails := 0
var world: Node
var player: Player


func check(label: String, ok: bool) -> void:
	print(("OK    " if ok else "ÉCHEC ") + label)
	if not ok:
		fails += 1


func _ready() -> void:
	check("profil de test", Profile.save_path == Profile.TEST_SAVE_PATH)
	Settings.reset_all()
	Profile.reset_all()
	check("réglage « Héros détaillé » mis par défaut", bool(Settings.get_v("display", "hero_detail")))
	_test_data()
	_test_models()
	await _test_world()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _detail(on: bool) -> void:
	Settings.set_v("display", "hero_detail", on)


func _test_data() -> void:
	var c := GameData.class_data(CID)
	var p := ClassPremium.spec(c)
	check("60 classes d'Eden sans « premium »", GameData.classes.size() == 60 and GameData.classes.values().all(func(x): return not x.get("look", {}).has("premium")))
	check("classe maison : look.premium", not p.is_empty())
	var lib := load(String(p.anims)) as AnimationLibrary
	check("bibliothèque d'animations : 7 animations", lib != null and lib.get_animation_list().size() == 7)
	var body: Node3D = (load("res://assets/player/body/body_m.glb") as PackedScene).instantiate()
	var ap := EdenModel.find_anim_player(body)
	for eden in p.remap:
		var neu := lib.get_animation(String(p.remap[eden])) if lib else null
		var src := "battle10" if eden == "battle" else String(eden)
		if eden == "battle":
			check("garde : boucle", neu != null and neu.loop_mode == Animation.LOOP_LINEAR)
			continue
		check("%s : même longueur que %s (%.3f / %.3f s)" % [p.remap[eden], src, neu.length if neu else -1.0, ap.get_animation(src).length],
			neu != null and absf(neu.length - ap.get_animation(src).length) < 0.02)
	# pistes aux chemins du corps commun (sinon l'animation ne bouge rien)
	var kick := lib.get_animation("ninja_kick")
	var ok_paths := true
	for i in kick.get_track_count():
		var path := kick.track_get_path(i)
		ok_paths = ok_paths and body.get_node_or_null(NodePath(String(path).get_slice(":", 0))) != null
	check("pistes aux chemins du corps commun (%d)" % kick.get_track_count(), ok_paths and kick.get_track_count() > 40)
	body.free()


func _test_models() -> void:
	var c := GameData.class_data(CID)
	# réglage coupé : apparence de CHR-1, aucune animation remplacée
	_detail(false)
	var m0 := EdenModel.instantiate_hero(c)
	add_child(m0)
	var sk0 := m0.find_child("Skeleton3D", true, false) as Skeleton3D
	check("réglage coupé : bandeau par code (CHR-1)", sk0.find_child("ClassLookBand", false, false) != null)
	check("réglage coupé : aucune animation remplacée", not m0.has_meta("anim_remap"))
	m0.queue_free()
	# réglage mis
	_detail(true)
	var m := EdenModel.instantiate_hero(c)
	add_child(m)
	var ap := EdenModel.find_anim_player(m)
	check("réglage mis : bibliothèque « chr2 » ajoutée", ap.has_animation_library("chr2") and ap.has_animation("chr2/ninja_kick"))
	check("réglage mis : coup de pied, signe, lancer, course, garde remplacés",
		ClassPremium.remapped(m, "attack20") == "chr2/ninja_kick" and ClassPremium.remapped(m, "magic01") == "chr2/ninja_seal"
		and ClassPremium.remapped(m, "shoot50") == "chr2/ninja_throw" and ClassPremium.remapped(m, "move02") == "chr2/ninja_run"
		and ClassPremium.remapped(m, String(GameData.weapon_type(String(c.weapon_type)).get("battle", c.anims.battle))) == "chr2/ninja_guard")
	check("poses procédurales remplacées sautées (coup de pied)", not _pose_runs(m, "kick") and _pose_runs(m, "hold_front"))
	var sk := m.find_child("Skeleton3D", true, false) as Skeleton3D
	var head_here := ClassPremium.file(c, "head") != ""
	if head_here:
		check("tête détaillée : visage d'Eden remplacé", m.find_children("#LFACE", "MeshInstance3D", true, false).is_empty()
			and not m.find_children("PremiumFace", "MeshInstance3D", true, false).is_empty())
		check("tête détaillée : mèches, bandeau, rubans", not m.find_children("PremiumHair", "MeshInstance3D", true, false).is_empty()
			and not m.find_children("PremiumBand", "MeshInstance3D", true, false).is_empty())
		check("tête détaillée : pas d'ajouts par code de CHR-1", sk.find_child("ClassLookBand", false, false) == null
			and m.get_children().filter(func(n): return n is ClassLook.RibbonTail).is_empty())
		check("os neufs : cheveux ×4, rubans ×6", ["PremiumHair_L1", "PremiumHair_L2", "PremiumHair_R1", "PremiumHair_R2",
			"PremiumRibbon_L1", "PremiumRibbon_L2", "PremiumRibbon_L3", "PremiumRibbon_R1", "PremiumRibbon_R2", "PremiumRibbon_R3"].all(func(b): return sk.find_bone(b) >= 0))
		var sim := sk.find_child("PremiumSprings", false, false) as SpringBoneSimulator3D
		check("ressorts : 4 chaînes (SpringBoneSimulator3D)", sim != null and sim.setting_count == 4)
		var tris := 0
		for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			for s in mi.mesh.get_surface_count():
				tris += mi.mesh.surface_get_array_index_len(s) / 3 if mi.mesh is ArrayMesh else 0
		check("budget : ≤ 15 000 triangles pour le héros (%d)" % tris, tris > 0 and tris <= 15000)
	else:
		check("tête détaillée absente de ce PC : repli sur l'apparence de CHR-1", sk.find_child("ClassLookBand", false, false) != null)
	# une classe d'Eden : rien
	var w := EdenModel.instantiate_hero(GameData.class_data("warrior"))
	add_child(w)
	check("Guerrier : ni animation neuve ni tête détaillée", not w.has_meta("anim_remap") and not w.has_meta("premium_head")
		and not EdenModel.find_anim_player(w).has_animation_library("chr2"))
	w.queue_free()
	m.queue_free()


func _pose_runs(m: Node3D, pose: String) -> bool:
	var pp := ProcPose.on(m)
	pp.pose_name = ""
	pp.hold(pose, 0.5)
	var on := pp.pose_name == pose
	pp.release()
	return on


## Calage du jeu identique réglage mis / coupé : impacts et durée des 3 coups du taï-jutsu et des sorts.
func _timing() -> Array:
	var out: Array = []
	player._swing = 0
	player._combo_at = -10.0
	for i in 3:
		player._state = "idle"
		player._start_attack(player.global_position + player.forward() * 2.0)
		out.append([snappedf(player._state_len, 0.001), (player._hits as Array).map(func(x): return snappedf(x, 0.001)), player._current_anim])
	return out


func _test_world() -> void:
	_detail(true)
	Profile.selected_class = CID
	Run.start(CID)
	world = load("res://scenes/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().create_timer(6.0).timeout
	world.cards._queue.clear()
	world.cards._show_next()
	player = world.player
	world.director.set_process(false)
	world.director.set_physics_process(false)
	check("dans le monde : animations neuves", player.model.has_meta("anim_remap"))
	var on := _timing()
	check("3e coup joue le coup de pied neuf (%s)" % on[2][2], String(on[2][2]) == "chr2/ninja_kick")
	# même héros, réglage coupé : on retire le remplacement (comme un héros habillé sans le réglage)
	var remap = player.model.get_meta("anim_remap")
	player.model.remove_meta("anim_remap")
	var off := _timing()
	player.model.set_meta("anim_remap", remap)
	var same := true
	for i in 3:
		same = same and on[i][0] == off[i][0] and str(on[i][1]) == str(off[i][1])
	check("calage du jeu identique (durées %s, impacts %s)" % [str(on.map(func(x): return x[0])), str(on.map(func(x): return x[1]))], same)
	# course : l'animation neuve joue quand le héros court
	player._state = "idle"
	player.play("move02", 0.1)
	check("course : ninja_run jouée à la place de move02", player.anim.current_animation == "chr2/ninja_run")
	# ressorts : un ruban bouge quand le héros se déplace (tête détaillée sur ce PC seulement)
	var sk := player.model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk.find_bone("PremiumRibbon_L3") >= 0:
		var b := sk.find_bone("PremiumRibbon_L3")
		var before := sk.get_bone_global_pose(b).origin
		var moved := 0.0
		for i in 30:
			player.global_position += Vector3(0.15, 0, 0)
			await get_tree().physics_frame
			moved = maxf(moved, sk.get_bone_global_pose(b).origin.distance_to(before))
		check("ressorts : le ruban traîne quand le héros bouge (%.3f)" % moved, moved > 0.005)
	# ultime : charge puis lancer neufs
	Run.skills = [{"id": 990104, "rank": 1}]
	player.skill_ready_at.clear()
	player._state = "idle"
	player._skill_lock_until = 0.0
	player.use_skill(0, player.global_position + player.forward() * 6.0)
	await get_tree().process_frame
	check("ultime : charge bras levés (%s)" % player.anim.current_animation, player.anim.current_animation == "chr2/ninja_ult_charge")
	await get_tree().create_timer(float(player._hits[0]) + 0.1 if not player._hits.is_empty() else 1.3).timeout
	check("ultime : lancer (%s)" % player.anim.current_animation, player.anim.current_animation == "chr2/ninja_ult_throw" or player._state != "skill")
	await get_tree().create_timer(1.0).timeout
	world.queue_free()
	await get_tree().process_frame
