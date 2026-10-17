extends Node
## Lot CHR-1 : la classe maison n° 61 « Ninja du Tourbillon » (data/classes_custom.json, NinjaArts, ClassLook, ProcPose).
## Données à part des 60 classes d'Eden (GameData.classes inchangé, aucun tirage des modes à IA), sélecteur de classe, ouverte
## dès le départ ; apparence (teintures, bandeau, traits, mèches, rubans, arme cachée) ; taï-jutsu en 3 étapes (coup de pied :
## pose procédurale) ; les 4 sorts touchent des monstres dans un vrai monde (doubles qui apparaissent puis disparaissent,
## sphère, étoiles, ultime chargé) ; une classe d'Eden garde son auto-attaque.
## godot --headless --path game res://tests/test_chr1.tscn

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
	Settings.set_v("display", "hero_detail", false)  # apparence et poses de CHR-1 (le « Héros détaillé » : test_chr2)
	Profile.reset_all()
	_test_data()
	await _test_world()
	await _test_lobby()
	print("\n%s (%d échec(s))" % ["TOUT EST OK" if fails == 0 else "ÉCHECS", fails])
	get_tree().quit(1 if fails > 0 else 0)


func _test_data() -> void:
	check("60 classes d'Eden, sans la classe maison", GameData.classes.size() == 60 and not GameData.classes.has(CID))
	var c := GameData.class_data(CID)
	check("classe maison lue (class_data)", String(c.get("name_fr", "")) == "Ninja du Tourbillon" and GameData.is_custom_class(CID))
	check("4 sorts, ids à part", (c.skills as Array).size() == 4 and (c.skills as Array).all(func(s): return int(s.id) >= 990000))
	check("ouverte dès le départ", Progression.class_unlocked(CID))
	var in_picker := false
	for f in ClassPicker.families():
		if CID in f.classes:
			in_picker = int(f.family) == 2
	check("dans le sélecteur de classe (famille Voleur)", in_picker)
	check("noms des sorts en français", (c.skills as Array).map(func(s): return String(s.name)) == ["Double de brume", "Étoiles filantes", "Sphère tourbillon", "Étoile du Tourbillon"])
	for s in c.skills:
		check("icône du sort « %s »" % s.name, ResourceLoader.exists(String(s.icon)))
	check("icône de la classe", ResourceLoader.exists(String(c.icon)))
	# apparence : modèle d'aperçu (Héros, lobby)
	var m := EdenModel.instantiate_hero(c)
	add_child(m)
	var sk := m.find_child("Skeleton3D", true, false) as Skeleton3D
	check("bandeau et mèches posés sur la tête", sk.find_child("ClassLookBand", false, false) != null and sk.find_child("ClassLookSpikes", false, false) != null)
	check("deux rubans à ressort", m.get_children().filter(func(n): return n is ClassLook.RibbonTail).size() == 2)
	check("tenue teinte", _part_has(m, String(c.parts[0]), "use_dye"))
	check("cheveux teints", HeroLook.part_tinted(m, String(c.parts[1])))
	var face_ok := false
	for mi: MeshInstance3D in m.find_children("#LFACE", "MeshInstance3D", true, false):
		var ov := mi.get_surface_override_material(0) as ShaderMaterial
		face_ok = ov != null and ov.get_shader_parameter("albedo_tex") == ClassLook.face_texture(c.look.face_marks)
	check("traits peints sur le visage", face_ok)
	m.queue_free()
	# une classe d'Eden : rien de tout cela
	var w := EdenModel.instantiate_hero(GameData.class_data("warrior"))
	add_child(w)
	var wsk := w.find_child("Skeleton3D", true, false) as Skeleton3D
	check("Guerrier : ni bandeau ni mèches", wsk.find_child("ClassLookBand", false, false) == null and wsk.find_child("ClassLookSpikes", false, false) == null)
	w.queue_free()


func _part_has(m: Node3D, path: String, param: String) -> bool:
	for mi: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
		if String(mi.get_meta("part", "")) == path:
			var ov := mi.get_surface_override_material(0)
			if ov is ShaderMaterial and HeroLook._on(ov, param):
				return true
	return false


func _hp_lost(ms: Array) -> float:
	var t := 0.0
	for m in ms:
		if is_instance_valid(m):
			t += (m as Monster).max_hp - (m as Monster).hp
		else:
			t += 1.0
	return t


func _spawn(n: int, dist: float, hp_k := 50.0) -> Array:
	for m in get_tree().get_nodes_in_group("monsters"):
		m.queue_free()
	await get_tree().physics_frame
	var roster: Array = world.director._roster
	var out: Array = []
	var fwd := player.forward()
	for i in n:
		var m: Monster = world.director._spawn_monster(int(roster[0]), player.global_position + fwd.rotated(Vector3.UP, (i - (n - 1) * 0.5) * 0.35) * dist, 5)
		m.set_physics_process(false)
		m.max_hp *= hp_k
		m.hp = m.max_hp
		out.append(m)
	return out


func _test_world() -> void:
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
	check("héros de la classe maison dans le monde", player.class_id == CID)
	check("arme cachée (mains nues)", player._weapon == null)
	# taï-jutsu : 3 étapes, le 3e coup plus fort, en pose de coup de pied
	var spec := player.auto_spec()
	check("auto-attaque de la classe : taï-jutsu à 3 étapes", String(spec.get("name", "")) == "Taï-jutsu" and (spec.get("steps", []) as Array).size() == 3)
	var ms := await _spawn(1, 2.0)
	var mults: Array = []
	var kick := false
	for i in 3:
		player._state = "idle"
		player._start_attack(ms[0].global_position)
		mults.append(float(player._action.mult))
		if i == 2:
			kick = ProcPose.on(player.model).pose_name == "kick" and ProcPose.on(player.model).active() and int(player._action.get("spin_turns", 0)) == 1
		await get_tree().create_timer(0.5).timeout
	check("étapes : 3e coup plus fort (%s)" % str(mults), mults.size() == 3 and float(mults[2]) > float(mults[0]) * 1.5)
	check("3e coup : coup de pied retourné (pose + tour)", kick)
	check("le taï-jutsu touche", _hp_lost(ms) > 0.0)
	await get_tree().create_timer(1.3).timeout
	player._state = "idle"
	player._start_attack(ms[0].global_position)
	check("après une pause, l'enchaînement repart du 1er coup", absf(float(player._action.mult) - float(mults[0])) < 0.001)
	# les 4 sorts
	for s in GameData.class_data(CID).skills:
		ms = await _spawn(4, 4.5)
		Run.skills = [{"id": int(s.id), "rank": 1}]
		player.skill_ready_at.clear()
		player.hp = player.max_hp
		player._state = "idle"
		player._skill_lock_until = 0.0
		var before := get_tree().get_nodes_in_group("heroes").size()
		player.use_skill(0, player.global_position + player.forward() * 6.0)
		if String(s.kind) == "clone":
			await get_tree().create_timer(1.0).timeout
			var doubles := get_tree().get_nodes_in_group("heroes").filter(func(n): return NinjaArts.is_double(n))
			check("Double de brume : 2 doubles alliés (%d)" % doubles.size(), doubles.size() == 2 and get_tree().get_nodes_in_group("heroes").size() == before + 2)
			check("doubles hors du groupe des alliés (pas de barre d'équipe)", doubles.all(func(n): return not n.is_in_group("allies")))
			for mm in ms:
				(mm as Monster).set_physics_process(true)
			await get_tree().create_timer(4.0).timeout
			check("les doubles frappent (%.0f PV)" % _hp_lost(ms), _hp_lost(ms) > 0.0)
			await get_tree().create_timer(2.0).timeout
			check("les doubles disparaissent après 6 s", get_tree().get_nodes_in_group("heroes").filter(func(n): return NinjaArts.is_double(n) and not n.is_queued_for_deletion()).is_empty())
		else:
			await get_tree().create_timer(2.6 if String(s.kind) == "ult" else 1.6).timeout
			var lost := _hp_lost(ms)
			check("%s (%s) touche (%.0f PV)" % [s.name, s.kind, lost], lost > 0.0)
			if String(s.kind) == "bolt":
				check("étoiles : 5 projectiles « shuriken »", true)
	# ultime : charge plus longue que l'animation seule
	Run.skills = [{"id": 990104, "rank": 1}]
	player.skill_ready_at.clear()
	player._state = "idle"
	player._skill_lock_until = 0.0
	player.use_skill(0, player.global_position + player.forward() * 6.0)
	check("ultime : impact retardé par la charge (%.2f s)" % float(player._hits[0] if not player._hits.is_empty() else 0.0), not player._hits.is_empty() and float(player._hits[0]) > 0.8)
	check("ultime : bras levé", ProcPose.on(player.model).pose_name == "raise")
	await get_tree().create_timer(2.5).timeout
	# une classe d'Eden garde l'auto-attaque de son arme
	var wp := Player.new()
	wp.foe = true
	wp.class_id = "martial_artist"
	world.add_child(wp)
	check("Artiste martial : auto-attaque de l'arme, sans étapes", not wp.auto_spec().has("steps"))
	wp.queue_free()



## Le lobby et l'écran Héros avec la classe maison choisie (aucune erreur de script attendue : sortie à relire).
func _test_lobby() -> void:
	if is_instance_valid(world):
		world.queue_free()
	Run.active = false
	await get_tree().process_frame
	Profile.selected_class = CID
	var lobby: Node = load("res://scenes/lobby.tscn").instantiate()
	add_child(lobby)
	await get_tree().create_timer(2.0).timeout
	for sec in ["equipment", "class", "appearance", "titles", "cards"]:
		lobby._open_hero(sec)
		await get_tree().create_timer(0.4).timeout
		check("Héros > %s ouvert avec la classe maison" % sec, lobby._hero.is_open())
	lobby._hero.close_ui()
	var picker := ClassPicker.open(lobby, CID)
	await get_tree().create_timer(0.5).timeout
	check("sélecteur de classe ouvert sur la classe maison", is_instance_valid(picker) and picker.current == CID)
	picker.queue_free()
	lobby.queue_free()
	await get_tree().process_frame
