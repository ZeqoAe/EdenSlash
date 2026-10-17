extends SceneTree
## Lot CHR-2 (conception/art/R_CHR2.md) : fabrique une AnimationLibrary Godot à partir des animations cuites par Blender
## (tools/art/chr2_anims.py -> chr2_anims.json : deltas monde par os D = P · R⁻¹, repère de l'armature de Blender).
##   Godot --headless --path game -s res://tools/chr2/chr2_anim_build.gd -- --json=<chr2_anims.json> --out=<bibliothèque.res>
##                                                                         [--check]   (compare rt_attack20 à attack20 d'Eden)
## Méthode : le passage repère de Blender -> repère d'EdenRoot (Mc) est calculé par alignement (Kabsch) des positions de
## repos des os, jamais supposé ; puis pour chaque image : G = Mc·D·Mc⁻¹·G_repos (repère d'EdenRoot), ramené en local
## (nœud Bip01_Nub, puis os du Skeleton3D) aux chemins de pistes exacts des animations du corps commun.

const BODY := "res://assets/player/body/body_m.glb"


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(String(args.get("json", ""))))
	var body: Node3D = (load(BODY) as PackedScene).instantiate()
	var ap := body.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var root := ap.get_node(ap.root_node)  # nœud de base des chemins de pistes (body_m)
	var eden_root := body.find_child("EdenRoot", true, false) as Node3D
	var nub := body.find_child("Bip01_Nub", true, false) as Node3D
	var sk := body.find_child("Skeleton3D", true, false) as Skeleton3D
	var nub_path := String(root.get_path_to(nub))
	var sk_path := String(root.get_path_to(sk))
	# repos dans le repère d'EdenRoot
	var nub_rest := _rel(eden_root, nub)
	var pelvis_node_g := _rel(eden_root, nub.get_parent() as Node3D)
	var skel_g := nub_rest * sk.transform
	var g_rest := {"Bip01_Nub": nub_rest}
	for b in sk.get_bone_count():
		g_rest[sk.get_bone_name(b)] = skel_g * sk.get_bone_global_rest(b)
	# Mc : Blender -> EdenRoot (Kabsch sur les têtes d'os communes)
	var src: Array[Vector3] = []
	var dst: Array[Vector3] = []
	for n in data.rest:
		if g_rest.has(n):
			var r: Array = data.rest[n]
			src.append(Vector3(r[0], r[1], r[2]))
			dst.append((g_rest[n] as Transform3D).origin)
	var mc := _kabsch(src, dst)
	var err := 0.0
	for i in src.size():
		err = maxf(err, (mc * src[i]).distance_to(dst[i]))
	print("[chr2] alignement Blender -> EdenRoot : %d os, écart max %.5f m" % [src.size(), err])
	var lib := AnimationLibrary.new()
	var fps := float(data.fps)
	for aname in data.anims:
		var ad: Dictionary = data.anims[aname]
		var anim := _build(ad, fps, mc, g_rest, pelvis_node_g, skel_g, sk, nub_path, sk_path)
		lib.add_animation(aname, anim)
	if args.has("check") and lib.has_animation("rt_attack20"):
		_check(ap.get_animation("attack20"), lib.get_animation("rt_attack20"))
		_check(ap.get_animation("stand01"), lib.get_animation("rt_stand01"))
	for n in lib.get_animation_list():
		if String(n).begins_with("rt_"):
			lib.remove_animation(n)
	if args.has("out"):
		var e := ResourceSaver.save(lib, String(args.out))
		print("[chr2] bibliothèque %s : %d animations (%s)" % [args.out, lib.get_animation_list().size(), error_string(e)])
	body.free()
	quit()


func _build(ad: Dictionary, fps: float, mc: Transform3D, g_rest: Dictionary, pelvis_g: Transform3D, skel_g: Transform3D,
		sk: Skeleton3D, nub_path: String, sk_path: String) -> Animation:
	var anim := Animation.new()
	anim.length = float(ad.length)
	anim.loop_mode = Animation.LOOP_LINEAR if ad.loop else Animation.LOOP_NONE
	var frames: Array = ad.frames
	var names: Array = (frames[0] as Dictionary).keys()
	var tracks := {}
	var mci := mc.affine_inverse()
	var skel_gi := skel_g.affine_inverse()
	for n: String in names:
		if n == "Bip01_Nub":
			tracks[n] = [anim.add_track(Animation.TYPE_POSITION_3D), anim.add_track(Animation.TYPE_ROTATION_3D)]
			anim.track_set_path(tracks[n][0], nub_path)
			anim.track_set_path(tracks[n][1], nub_path)
		elif sk.find_bone(n) >= 0:
			tracks[n] = [anim.add_track(Animation.TYPE_POSITION_3D), anim.add_track(Animation.TYPE_ROTATION_3D)]
			anim.track_set_path(tracks[n][0], "%s:%s" % [sk_path, n])
			anim.track_set_path(tracks[n][1], "%s:%s" % [sk_path, n])
	for fi in frames.size():
		var t := minf(fi / fps, anim.length)
		var row: Dictionary = frames[fi]
		var g := {}
		for n in row:
			var v: Array = row[n]
			var d := Transform3D(Basis(Quaternion(v[0], v[1], v[2], v[3])), Vector3(v[4], v[5], v[6]))
			g[n] = mc * d * mci * (g_rest[n] as Transform3D)
		# Bip01_Nub : local au nœud Bip01 Pelvis (fixe)
		var nub_g: Transform3D = g.get("Bip01_Nub", g_rest["Bip01_Nub"])
		var nub_local := pelvis_g.affine_inverse() * nub_g
		anim.position_track_insert_key(tracks["Bip01_Nub"][0], t, nub_local.origin)
		anim.rotation_track_insert_key(tracks["Bip01_Nub"][1], t, nub_local.basis.get_rotation_quaternion())
		var skel_now := nub_g * (g_rest["Bip01_Nub"] as Transform3D).affine_inverse() * skel_g  # Skeleton3D suit Bip01_Nub
		var skel_now_i := skel_now.affine_inverse()
		var s_global := {}
		for b in sk.get_bone_count():
			var n := sk.get_bone_name(b)
			if not g.has(n):
				continue
			s_global[n] = skel_now_i * (g[n] as Transform3D)
		for n in s_global:
			var b := sk.find_bone(n)
			var p := sk.get_bone_parent(b)
			var pg: Transform3D
			if p < 0:
				pg = Transform3D.IDENTITY
			elif s_global.has(sk.get_bone_name(p)):
				pg = s_global[sk.get_bone_name(p)]
			else:
				pg = skel_gi * (g_rest[sk.get_bone_name(p)] as Transform3D)
			var local: Transform3D = pg.affine_inverse() * (s_global[n] as Transform3D)
			anim.position_track_insert_key(tracks[n][0], t, local.origin)
			anim.rotation_track_insert_key(tracks[n][1], t, local.basis.get_rotation_quaternion().normalized())
	return anim


## Compare deux animations sur les pistes de rotation communes (écart d'angle en degrés).
func _check(a: Animation, b: Animation) -> void:
	var worst := 0.0
	var worst_name := ""
	var sum := 0.0
	var n := 0
	for i in a.get_track_count():
		if a.track_get_type(i) != Animation.TYPE_ROTATION_3D:
			continue
		var j := b.find_track(a.track_get_path(i), Animation.TYPE_ROTATION_3D)
		if j < 0:
			continue
		for k in 20:
			var t := a.length * k / 19.0
			var qa := a.rotation_track_interpolate(i, t)
			var qb := b.rotation_track_interpolate(j, t)
			var ang := rad_to_deg(qa.angle_to(qb))
			sum += ang
			n += 1
			if ang > worst:
				worst = ang
				worst_name = String(a.track_get_path(i)).get_slice(":", 1)
	print("[chr2] aller-retour %s : %d échantillons, écart moyen %.3f°, max %.3f° (%s)" % [a.resource_name, n, sum / maxf(n, 1), worst, worst_name])


static func _rel(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## Meilleure transformation rigide src -> dst (Kabsch, par itération de la matrice de covariance en quaternion : Horn).
static func _kabsch(src: Array[Vector3], dst: Array[Vector3]) -> Transform3D:
	var cs := Vector3.ZERO
	var cd := Vector3.ZERO
	for i in src.size():
		cs += src[i]
		cd += dst[i]
	cs /= src.size()
	cd /= dst.size()
	var s := [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
	for i in src.size():
		var a := src[i] - cs
		var b := dst[i] - cd
		for r in 3:
			for c in 3:
				s[r][c] += a[r] * b[c]
	var sxx: float = s[0][0]; var sxy: float = s[0][1]; var sxz: float = s[0][2]
	var syx: float = s[1][0]; var syy: float = s[1][1]; var syz: float = s[1][2]
	var szx: float = s[2][0]; var szy: float = s[2][1]; var szz: float = s[2][2]
	var n := [
		[sxx + syy + szz, syz - szy, szx - sxz, sxy - syx],
		[syz - szy, sxx - syy - szz, sxy + syx, szx + sxz],
		[szx - sxz, sxy + syx, -sxx + syy - szz, syz + szy],
		[sxy - syx, szx + sxz, syz + szy, -sxx - syy + szz]]
	# plus grand vecteur propre par puissance itérée (décalée pour rester positive)
	var shift := 0.0
	for r in 4:
		for c in 4:
			shift += absf(n[r][c])
	var v := [1.0, 0.3, 0.2, 0.1]
	for _it in 200:
		var w := [0.0, 0.0, 0.0, 0.0]
		for r in 4:
			for c in 4:
				w[r] += (n[r][c] + (shift if r == c else 0.0)) * v[c]
		var l := sqrt(w[0] * w[0] + w[1] * w[1] + w[2] * w[2] + w[3] * w[3])
		for r in 4:
			v[r] = w[r] / l
	var q := Quaternion(v[1], v[2], v[3], v[0]).normalized()
	var basis := Basis(q)
	return Transform3D(basis, cd - basis * cs)
