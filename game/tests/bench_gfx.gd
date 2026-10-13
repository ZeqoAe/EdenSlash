extends Node3D
## Banc graphique : toujours la même vue (map générée graine fixe, héros, monstres,
## un effet d'Eden) pour comparer le rendu avant / après une modification.
## Captures dans user://shots/gfx_<zone>.png puis quitte.
## godot --path game --rendering-driver vulkan res://tests/bench_gfx.tscn -- <zone> [fx] [instant]

const MONSTERS := ["56001", "56021", "56041"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var zone := String(args[0]) if args.size() > 0 else "limestone"
	var fx := String(args[1]) if args.size() > 1 else "s36441"
	var at := float(args[2]) if args.size() > 2 else 0.35  # instant de la capture dans l'effet (s)
	var bd := MapBackdrop.new()
	add_child(bd)
	bd.show_zone(zone)
	var map := bd.map
	var p := map.start
	p.y = map.height_at(p.x, p.z)
	# héros et monstres
	var cls := GameData.class_data("samurai")
	var hero := EdenModel.instantiate(cls.model)
	hero.scale = Vector3.ONE * GameData.HERO_SCALE
	add_child(hero)
	hero.global_position = p
	EdenModel.attach_weapon(hero, EdenModel.weapon_entry(cls, "W21601"))
	_idle(hero, String(cls.anims.get("battle", "stand01")))
	var ids := GameData.monsters.keys()
	for i in 3:
		var d: Dictionary = GameData.monsters.get(int(MONSTERS[i]), GameData.monsters[ids[i * 7 % ids.size()]])
		var base := "res://assets/monsters/%s/%s" % [d.model, d.model]
		var tex := "res://assets/monsters/textures/%s.png" % d.texture
		var m := EdenModel.instantiate(base + ".glb", tex if ResourceLoader.exists(tex) else "")
		m.scale = Vector3.ONE * float(d.scale) * GameData.MONSTER_SCALE
		add_child(m)
		var a := -0.9 + i * 0.9
		var q := p + Vector3(sin(a) * 3.2, 0, -cos(a) * 3.2)
		q.y = map.height_at(q.x, q.z)
		m.global_position = q
		m.look_at(Vector3(p.x, q.y, p.z), Vector3.UP, true)
		_idle(m, "stand01")
	# caméra du jeu (distance 15, 52°)
	var cam := bd.camera
	var pitch := deg_to_rad(52.0)
	cam.fov = 45.0
	cam.global_position = p + Vector3(0, sin(pitch), cos(pitch)) * 15.0
	cam.look_at(p + Vector3.UP, Vector3.UP)
	bd._fade.color.a = 0.0
	await get_tree().create_timer(1.0).timeout
	EdenFx.play(self, fx, p + Vector3(0, 0.1, -1.5), 0.0, GameData.HERO_SCALE)
	await get_tree().create_timer(at).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://shots")
	get_viewport().get_texture().get_image().save_png("user://shots/gfx_%s.png" % zone)
	# gros plan (comme le lobby)
	cam.fov = 40.0
	cam.global_position = p + Vector3(1.5, 2.2, 5.0)
	cam.look_at(p + Vector3(0, 1.0, -1.2), Vector3.UP)
	await get_tree().create_timer(1.0).timeout  # effet terminé : on voit les modèles
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/gfx_%s_close.png" % zone)
	get_tree().quit()


func _idle(model: Node3D, anim_name: String) -> void:
	var ap := EdenModel.find_anim_player(model)
	if ap and ap.has_animation(anim_name):
		ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		ap.play(anim_name)
