extends Node
## Lot PRP-1 : contrôle des candidats dans Godot 4.7 (projet de brouillon C:\AI\prp1_godot monté par
## tools/art/prp_pipeline.py godot ; rien n'est lu ni écrit dans game/).
## Pour chaque objet de jobs.json : import réel du GLB, accroche comme EdenModel (BoneAttachment3D sur l'os, nœud
## EdenRoot remis à l'identité), rendu toon du jeu (eden_character.gdshader), héros du jeu à l'échelle HERO_SCALE dans
## sa pose de combat ; deux images : <id>_godot.png (gros plan 3/4) et <id>_distance.png (caméra du jeu :
## 15 m, 52°, champ 45°, écran 1280×720, recadré 160×160 autour du héros : la taille réelle à l'écran).
## Lignes « [prp] » : contrôle de format (EdenRoot, W1/W2, triangles, taille dans le repère de l'os).

const HERO_SCALE := 1.3  # GameData.HERO_SCALE
const MAX_WEAPON_SIZE := 2.7  # EdenModel.MAX_WEAPON_SIZE
const SHADER := preload("res://shaders/eden_character.gdshader")
const STANCE := {"sword": "battle01", "greatsword": "battle03", "katana": "battle01", "axe": "battle03",
	"hammer": "battle03", "staff": "battle07", "scepter": "battle04", "spear": "battle12", "wings": "stand01"}

var out_dir := "user://"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	var jobs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://jobs.json"))
	for j in jobs:
		await _shoot(j)
	get_tree().quit()


func _stylize(root: Node) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null:
				continue
			var m := ShaderMaterial.new()
			m.shader = SHADER
			m.set_shader_parameter("albedo_tex", mat.albedo_texture)
			m.set_shader_parameter("albedo_color", mat.albedo_color)
			if mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				m.set_shader_parameter("alpha_cut", maxf(mat.alpha_scissor_threshold, 0.1))
			mi.set_surface_override_material(s, m)


func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != null and cur != root:
			if cur is Node3D:
				t = (cur as Node3D).transform * t
			cur = cur.get_parent()
		var b := t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _shoot(j: Dictionary) -> void:
	var id := String(j.id)
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("ccdef3")  # ciel du jeu (bible § 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.87, 0.95)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var hero: Node3D = (load("res://body/body_m.glb") as PackedScene).instantiate()
	hero.scale = Vector3.ONE * HERO_SCALE
	vp.add_child(hero)
	_stylize(hero)
	var skel := hero.find_child("Skeleton3D", true, false) as Skeleton3D
	var anim := hero.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var st := String(STANCE.get(String(j.get("type", "")), "stand01"))
	if anim:
		for lib in anim.get_animation_library_list():
			if anim.get_animation_library(lib).has_animation(st):
				anim.play((lib + "/" if lib != "" else "") + st)
				anim.seek(0.4, true)
				anim.pause()
	# accroche, comme EdenModel.attach_weapon / EdenModel.dress (accessoire rigide)
	var bone := String(j.bone)
	if j.kind == "weapon" and skel.find_bone("Bip01 Prop1") >= 0:
		bone = "Bip01 Prop1"
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	var inst: Node3D = (load("res://cand/%s.glb" % id) as PackedScene).instantiate()
	var root := inst.find_child("EdenRoot", true, false) as Node3D
	var report := "[prp] %s : os %s (%s)" % [id, bone, "ok" if skel.find_bone(bone) >= 0 else "ABSENT"]
	if root:
		root.transform = Transform3D.IDENTITY
	else:
		report += ", EdenRoot ABSENT"
	_stylize(inst)
	att.add_child(inst)
	var box := _bounds(inst)
	var tris := 0
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(s) / 3
	report += ", %d triangles, boite %s" % [tris, str(box)]
	if j.kind == "weapon":
		var w1 := inst.find_child("W1", true, false) as Node3D
		var w2 := inst.find_child("W2", true, false) as Node3D
		report += ", W1 %s, W2 %s" % [str(w1.position) if w1 else "ABSENT", str(w2.position) if w2 else "ABSENT"]
		if box.get_longest_axis_size() > MAX_WEAPON_SIZE:
			report += ", REDUITE par le jeu (> %.1f m)" % MAX_WEAPON_SIZE
	print(report)

	var cam := Camera3D.new()
	cam.fov = 40.0
	vp.add_child(cam)
	await get_tree().process_frame
	await get_tree().process_frame
	# cadrage : le haut du dos du héros (os, pose jouée) et la boîte de l'objet
	var spine := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("Bip01 Spine1"))
	var center := spine.origin
	var pts: Array[Vector3] = [center + Vector3(0, 0.75, 0), center - Vector3(0, 1.3, 0)]
	for i in 8:
		pts.append(inst.global_transform * box.get_endpoint(i))
	var lo := pts[0]
	var hi := pts[0]
	for q in pts:
		lo = lo.min(q)
		hi = hi.max(q)
	var mid := (lo + hi) / 2.0
	var rad := (hi - lo).length() / 2.0
	# gros plan : de face en 3/4 (armes), de dos en 3/4 (ailes) ; le héros regarde +Z
	var dir := Vector3(0.75, 0.35, 1.0) if j.kind == "weapon" else Vector3(-0.8, 0.45, -1.0)
	cam.position = mid + dir.normalized() * rad / tan(deg_to_rad(cam.fov / 2.0)) * 1.05
	cam.look_at(mid)
	for i in 6:
		await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out_dir.path_join(id + "_godot.png"))
	# distance de jeu : CameraRig (distance 15, tangage 52°, champ 45°), écran 1280×720, vue de dos pour les ailes
	vp.size = Vector2i(1280, 720)
	cam.fov = 45.0
	var yaw := 0.0 if j.kind == "weapon" else PI
	var pitch := deg_to_rad(52.0)
	var target := center
	cam.position = target + Vector3(sin(yaw + 0.5) * cos(pitch), sin(pitch), cos(yaw + 0.5) * cos(pitch)) * 15.0
	cam.look_at(target)
	for i in 6:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var p := cam.unproject_position(center)
	var r := Rect2i(int(p.x) - 80, int(p.y) - 85, 160, 160)
	img.get_region(r).save_png(out_dir.path_join(id + "_distance.png"))
	vp.queue_free()
	await get_tree().process_frame
