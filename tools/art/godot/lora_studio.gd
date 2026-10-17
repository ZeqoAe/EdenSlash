extends Node3D
## Portraits pour le jeu de données du LoRA de style (département LORA) : héros (pied, buste) et monstres de NOTRE
## jeu, cadrés d'après leur boîte englobante, devant le décor d'une zone (une zone différente par image).
## Ce script n'est PAS dans game/ : tools/art/lora_dataset.py le copie dans une copie propre de HEAD et le lance.
## godot --path <copie>/game res://tools/lora_studio.tscn -- <dossier_sortie> <heros|buste|monstre> <nombre> [décalage]
## Héros : 832 x 1216 (pied) ou 1024 x 1024 (buste) ; monstres : 1024 x 1024. Rendu 2x puis réduit de moitié.

var _vp: SubViewport
var _cam: Camera3D
var _bd: MapBackdrop


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := String(args[0]) if args.size() > 0 else "user://lora_studio"
	var kind := String(args[1]) if args.size() > 1 else "heros"
	var count := int(args[2]) if args.size() > 2 else 8
	var offset := int(args[3]) if args.size() > 3 else 0
	DirAccess.make_dir_recursive_absolute(out)
	var size := Vector2i(832, 1216) if kind == "heros" else Vector2i(1024, 1024)
	_bd = MapBackdrop.new()
	add_child(_bd)
	_vp = SubViewport.new()
	_vp.size = size * 2
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.far = 900.0
	_vp.add_child(_cam)
	_cam.make_current()
	# sujets : répartis sur toute la liste (classes, ou monstres de tous les rangs)
	var subjects: Array = []
	if kind == "monstre":
		var ids: Array = GameData.monsters.keys()
		ids.sort()
		for i in count:
			subjects.append(ids[(offset + i * ids.size() / count) % ids.size()])
	else:
		var ids: Array = GameData.classes.keys()
		for i in count:
			subjects.append(ids[(offset + i * ids.size() / count) % ids.size()])
	# rangés par zone pour ne générer chaque carte qu'une fois
	var zones: Array = []
	for z in GameData.zones:
		zones.append(String(z.id))
	var jobs: Array = []
	for i in subjects.size():
		jobs.append([zones[(i + offset) % zones.size()], subjects[i], i])
	jobs.sort_custom(func(a, b): return String(a[0]) < String(b[0]))
	for j in jobs:
		var zid := String(j[0])
		if _bd.map == null or String(_bd.zone.get("id", "")) != zid:
			_bd.show_zone(zid)
			_bd._fade.color.a = 0.0
		var map := _bd.map
		var at := map.start
		at.y = map.height_at(at.x, at.z)
		var look := map.village if map.village != Vector3.INF else Vector3(map.size * 0.5, 0, map.size * 0.5)
		var away := Vector3(at.x - look.x, 0, at.z - look.z).normalized()
		if away == Vector3.ZERO:
			away = Vector3.BACK
		var node: Node3D
		var name := ""
		if kind == "monstre":
			var d: Dictionary = GameData.monsters[j[1]]
			node = _monster(d)
			name = "monstre_%s_%s" % [str(j[1]), zid]
		else:
			var cls: Dictionary = GameData.class_data(String(j[1]))
			node = _hero(cls)
			name = "%s_%s_%s" % [kind, String(j[1]), zid]
		if node == null:
			continue
		add_child(node)
		node.global_position = at
		# de trois quarts : tourné de 25 degrés par rapport à la caméra
		var yaw := deg_to_rad(25.0 if int(j[2]) % 2 == 0 else -25.0)
		node.look_at(at + away.rotated(Vector3.UP, yaw), Vector3.UP, true)
		await get_tree().create_timer(0.3).timeout
		var box := EdenModel.bounds(node)
		var s := node.scale.y
		var h := maxf(box.size.y * s, 0.5)
		var fov := 30.0
		_cam.fov = fov
		var half := 0.0
		var center_y := 0.0
		if kind == "buste":
			center_y = h * 0.74
			half = h * 0.30
		else:
			center_y = h * 0.5
			half = h * 0.54  # le héros remplit le cadre (une arme longue peut déborder)
		var dist := half / tan(deg_to_rad(fov * 0.5))
		var target := at + Vector3.UP * center_y
		var cpos := target + away * dist + Vector3.UP * dist * 0.12
		cpos.y = maxf(cpos.y, map.height_at(cpos.x, cpos.z) + 0.3)
		_cam.global_position = cpos
		_cam.look_at(target, Vector3.UP)
		await get_tree().create_timer(0.9).timeout
		for f in 3:
			await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
		img.save_png(out.path_join(name + ".png"))
		print("[lora] %s" % name)
		node.queue_free()
	print("[lora] fini")
	get_tree().quit()


func _hero(cls: Dictionary) -> Node3D:
	var node := EdenModel.instantiate_hero(cls)
	node.scale = Vector3.ONE * GameData.HERO_SCALE
	EdenModel.attach_weapon(node, EdenModel.weapon_entry(cls, ""))
	_idle(node, String(cls.get("anims", {}).get("idle", "stand01")))  # pose de repos : toujours de face (certaines poses de combat tournent le corps)
	return node


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
