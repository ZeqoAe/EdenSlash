extends Node3D
## Captures pour le jeu de données du LoRA de style (département LORA) : vues sans interface de NOTRE jeu
## (paysage, vue aérienne, héros en gros plan, combat vu par la caméra du jeu, monstre en gros plan), zone par zone.
## Ce script n'est PAS dans game/ : tools/art/lora_capture.py le copie dans une copie propre de HEAD et le lance.
## godot --path <copie>/game res://tools/lora_capture.tscn -- <dossier_sortie> [zones,séparées|all] [l x h] [vues,séparées|all]
## Rendu dans un SubViewport 2x puis réduit de moitié (anticrénelage) : 1216 x 832 par défaut.

const VIEWS := ["paysage", "aerien", "heros", "heros2", "combat", "monstre"]

var _views: Array = VIEWS

var _vp: SubViewport
var _cam: Camera3D
var _out := ""
var _size := Vector2i(1216, 832)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_out = String(args[0]) if args.size() > 0 else "user://lora_shots"
	var zones: Array = []
	if args.size() > 1 and String(args[1]) != "all":
		zones = String(args[1]).split(",")
	else:
		for z in GameData.zones:
			zones.append(String(z.id))
	if args.size() > 2:
		var p := String(args[2]).split("x")
		_size = Vector2i(int(p[0]), int(p[1]))
	if args.size() > 3 and String(args[3]) != "all":
		_views = String(args[3]).split(",")
	DirAccess.make_dir_recursive_absolute(_out)
	var bd := MapBackdrop.new()
	add_child(bd)
	_vp = SubViewport.new()
	_vp.size = _size * 2
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.far = 900.0
	_vp.add_child(_cam)
	_cam.make_current()
	var class_ids: Array = GameData.classes.keys()
	for zi in zones.size():
		var zid := String(zones[zi])
		var zindex := GameData.zone_index(zid)
		bd.show_zone(zid)
		bd._fade.color.a = 0.0
		var map := bd.map
		var start := map.start
		start.y = map.height_at(start.x, start.z)
		var look := map.village if map.village != Vector3.INF else Vector3(map.size * 0.5, 0, map.size * 0.5)
		look.y = map.height_at(look.x, look.z)
		var away := Vector3(start.x - look.x, 0, start.z - look.z).normalized()
		if away == Vector3.ZERO:
			away = Vector3.BACK
		var right := away.cross(Vector3.UP).normalized()
		# héros : une classe différente par zone (deux par zone : gros plan et combat)
		var cls_a: Dictionary = GameData.class_data(String(class_ids[(zindex * 7 + 3) % class_ids.size()]))
		var cls_b: Dictionary = GameData.class_data(String(class_ids[(zindex * 11 + 17) % class_ids.size()]))
		var mons := _zone_monsters(zindex)
		# 1. paysage : à hauteur de toit, vers le village (comme les cartes d'activité)
		if "paysage" in _views:
			_place(start + away * 4.0 + Vector3.UP * 7.0, look + Vector3.UP * 1.5, 50.0)
			await _shot("%s_paysage" % zid)
		# 2. vue aérienne oblique sur le village
		if "aerien" in _views:
			_place(look + away * 70.0 + right * 25.0 + Vector3.UP * 45.0, look, 50.0)
			await _shot("%s_aerien" % zid)
		# 3. héros en gros plan, le paysage derrière
		if "heros" in _views:
			await _hero_shot(cls_a, start, away, right, 1.2, "%s_heros" % zid)
		# 3 bis. un autre héros, de trois quarts, un peu plus loin sur le chemin
		if "heros2" in _views:
			var cls_c: Dictionary = GameData.class_data(String(class_ids[(zindex * 13 + 29) % class_ids.size()]))
			var s2 := start + right * 4.0 - away * 3.0
			s2.y = map.height_at(s2.x, s2.z)
			await _hero_shot(cls_c, s2, (away - right * 0.8).normalized(), right, -1.6, "%s_heros2" % zid)
		# 4. combat : caméra du jeu un peu rapprochée (distance 11, 52 degrés), héros et 3 monstres
		if "combat" in _views:
			var p := start - away * 10.0
			p.y = map.height_at(p.x, p.z)
			var hero2 := _hero(cls_b)
			add_child(hero2)
			hero2.global_position = p
			var placed: Array = [hero2]
			for i in mons.size():
				var a := -0.9 + i * 0.9
				var q := p + Vector3(sin(a) * 3.4, 0, -cos(a) * 3.4)
				q.y = map.height_at(q.x, q.z)
				var m := _monster(mons[i])
				if m == null:
					continue
				add_child(m)
				m.global_position = q
				m.look_at(Vector3(p.x, q.y, p.z), Vector3.UP, true)
				placed.append(m)
			hero2.look_at(Vector3(p.x, p.y, p.z - 1.0), Vector3.UP, true)
			var pitch := deg_to_rad(52.0)
			_place(p + Vector3(0, sin(pitch), cos(pitch)) * 11.0, p + Vector3.UP, 45.0)
			await _shot("%s_combat" % zid, 1.2)
			for n in placed:
				n.queue_free()
		# 5. monstre en gros plan, contre-plongée
		if "monstre" in _views:
			if not mons.is_empty():
				var big := _monster(mons[mons.size() - 1])
				if big != null:
					var mp := start + right * 8.0
					mp.y = map.height_at(mp.x, mp.z)
					add_child(big)
					big.global_position = mp
					var box := EdenModel.bounds(big)
					var h := maxf(box.size.y * big.scale.y, 1.0)
					var cp := mp + away * (h * 2.2 + 1.5) + right * h * 0.6 + Vector3.UP * h * 0.35
					cp.y = maxf(cp.y, map.height_at(cp.x, cp.z) + 0.4)
					big.look_at(Vector3(cp.x, mp.y, cp.z), Vector3.UP, true)
					_place(cp, mp + Vector3.UP * h * 0.55, 42.0)
					await _shot("%s_monstre" % zid, 1.2)
					big.queue_free()
		print("[lora] zone %s : vues prêtes" % zid)
	print("[lora] fini")
	get_tree().quit()


func _hero_shot(cls: Dictionary, at: Vector3, facing: Vector3, right: Vector3, side: float, name: String) -> void:
	var map: ProcMap = get_child(0).map
	var hero := _hero(cls)
	add_child(hero)
	hero.global_position = at
	hero.look_at(at + facing, Vector3.UP, true)
	var cpos := at + facing * 4.2 + right * side + Vector3.UP * 1.7
	cpos.y = maxf(cpos.y, map.height_at(cpos.x, cpos.z) + 0.5)
	_place(cpos, at + Vector3.UP * 1.2, 40.0)
	await _shot(name, 1.2)
	hero.queue_free()


func _place(pos: Vector3, target: Vector3, fov: float) -> void:
	_cam.fov = fov
	_cam.global_position = pos
	_cam.look_at(target, Vector3.UP)


func _shot(name: String, wait := 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	for f in 3:
		await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.resize(_size.x, _size.y, Image.INTERPOLATE_LANCZOS)
	img.save_png(_out.path_join(name + ".png"))
	print("[lora] %s" % name)


func _hero(cls: Dictionary) -> Node3D:
	var node := EdenModel.instantiate_hero(cls)
	node.scale = Vector3.ONE * GameData.HERO_SCALE
	EdenModel.attach_weapon(node, EdenModel.weapon_entry(cls, ""))
	_idle(node, String(cls.get("anims", {}).get("battle", "stand01")))
	return node


func _zone_monsters(zindex: int) -> Array:
	var out: Array = []
	for id in GameData.monsters:
		var d: Dictionary = GameData.monsters[id]
		if int(d.get("level", 0)) / 10 == zindex and int(d.get("rank", 2)) == 2:
			out.append(d)
	if out.size() > 3:
		var picked: Array = []
		for k in 3:
			picked.append(out[(k * 5 + zindex) % out.size()])
		out = picked
	return out


func _monster(d: Dictionary) -> Node3D:
	var base := "res://assets/monsters/%s/%s" % [d.model, d.model]
	if not ResourceLoader.exists(base + ".glb"):
		return null
	var tex := "res://assets/monsters/textures/%s.png" % d.texture
	var m := EdenModel.instantiate(base + ".glb", tex if ResourceLoader.exists(tex) else "")
	m.scale = Vector3.ONE * float(d.scale) * GameData.MONSTER_SCALE
	_idle(m, "stand01")
	return m


func _idle(model: Node3D, anim_name: String) -> void:
	var ap := EdenModel.find_anim_player(model)
	if ap and ap.has_animation(anim_name):
		ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		ap.play(anim_name)
