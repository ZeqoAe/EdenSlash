extends Node
## Mesure la taille visible de chaque effet d'Eden des sorts : l'effet est joué à l'échelle 1 dans une vue de
## dessus et de côté (caméras orthogonales, fond gris), figé à 8 instants de son animation ; le rayon retenu est celui
## qui contient 80 % des pixels allumés (le « cœur » de l'effet : les étincelles et traînées isolées ne comptent pas),
## au plus fort de l'animation. Écrit res://data/fx_radius.json
## ({nom d'effet : rayon en m à l'échelle 1}), lu par EdenFx.native_radius.
## Demande un rendu (pas de --headless) :  godot --path game res://tools/fx_measure.tscn [-- --debug-png]

const SIZE := 512
const ORTHO := 40.0  # largeur de la vue (m) : 0,078 m par pixel
const STEPS := 8
const THRESHOLD := 0.14
const CORE := 0.80  # part des pixels allumés qui définit le rayon


func _ready() -> void:
	var names: Array = []
	for cid in GameData.classes:
		for s in GameData.class_data(cid).get("skills", []):
			for k in (s.get("fx", {}) as Dictionary):
				var n := String(s.fx[k])
				if n != "" and not n in names:
					names.append(n)
	for extra in ["s00541", "s00141", "s00341"]:  # effets communs (hors compétences)
		if not extra in names:
			names.append(extra)
	names.sort()
	var only: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=").split(",")  # essai : seulement ces effets (rien n'est écrit)
	if not only.is_empty():
		names = Array(only)
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.5, 0.5)
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = ORTHO
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 40, 0), Vector3.ZERO, Vector3(0, 0, -1))
	# vue de côté : les plans verticaux (invisibles de dessus) donnent leur largeur
	var vp2 := SubViewport.new()
	vp2.size = Vector2i(SIZE, SIZE)
	vp2.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp2)
	var cam2 := Camera3D.new()
	cam2.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam2.size = ORTHO
	vp2.add_child(cam2)
	cam2.look_at_from_position(Vector3(0, 3, 40), Vector3(0, 3, 0), Vector3.UP)
	var out := {}
	var debug := "--debug-png" in OS.get_cmdline_user_args()
	var i := 0
	for name in names:
		i += 1
		if not EdenFx._load(name):
			out[name] = 0.0
			continue
		var fx := EdenFx.new()
		fx.fx_name = name
		vp.add_child(fx)
		fx.set_process(false)
		var dur := float(fx._data.get("duration", 1.0))
		var fps := float(fx._data.get("fps", 30.0))
		var best := 0.0
		for k in STEPS:
			fx._t = dur * (0.08 + 0.84 * float(k) / float(STEPS - 1))
			fx._apply(int(fx._t * fps))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			best = maxf(best, maxf(_extent(img), _extent(vp2.get_texture().get_image(), true)))
			if debug and (i <= 6 or not only.is_empty()) and k in [2, 4]:
				DirAccess.make_dir_recursive_absolute("user://shots")
				img.save_png("user://shots/fxm_%s_%d.png" % [name, k])
		fx.queue_free()
		out[name] = snappedf(best, 0.05)
		if i % 25 == 0:
			print("%d / %d" % [i, names.size()])
	if not only.is_empty():
		print(out)
		get_tree().quit()
		return
	var f := FileAccess.open("res://data/fx_radius.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("effets mesurés : %d · data/fx_radius.json écrit" % out.size())
	get_tree().quit()


## Rayon (m) contenant la part CORE des pixels qui diffèrent du fond (de côté : demi-largeur horizontale).
func _extent(img: Image, side := false) -> float:
	var c := SIZE * 0.5
	var hist := PackedInt32Array()
	hist.resize(SIZE)
	var total := 0
	for y in range(0, SIZE, 2):
		for x in range(0, SIZE, 2):
			var col := img.get_pixel(x, y)
			if maxf(absf(col.r - 0.5), maxf(absf(col.g - 0.5), absf(col.b - 0.5))) > THRESHOLD:
				var d := int(absf(x - c) if side else Vector2(x - c, y - c).length())
				if d < SIZE:
					hist[d] += 1
					total += 1
	if total < 12:
		return 0.0
	var acc := 0
	for d in SIZE:
		acc += hist[d]
		if acc >= int(total * CORE):
			return float(d) * ORTHO / float(SIZE)
	return ORTHO * 0.5
