extends Node3D
## Mesure et corrige la place des accessoires de dos sur le héros :
## godot --headless --path game res://tests/probe_backs.tscn [-- write]
## Pour chaque pièce articulée : sommets réels (peau calculée à la main, morceaux rigides
## compris), médianes et étendues par rapport à l'os du haut du dos (repère du modèle :
## x côté, y haut, z avant ; le dos est en z négatif). Avec « write », calcule une correction
## (quart de tour autour de la verticale si l'accessoire s'ouvre vers l'avant, puis décalage
## vers le haut du dos) et l'écrit dans data/back_fix.json.
## Résultat : user://shots/probe_backs.json (avant / après).

const TARGET_Z := -0.45
const TARGET_Y := 0.3
## Quart de tour imposé (vérifié à l'œil : leurs halos et éclairs faussent les mesures) :
## préfixe d'id -> angle autour de la verticale (degrés).
const FORCE_YAW := {}


func _ready() -> void:
	var write := "write" in OS.get_cmdline_user_args()
	var cls := GameData.class_data("warrior")
	var backs: Array = GameData.cosmetics.filter(func(x): return String(x.get("cat", "")) == "back")
	var out: Array = []
	var fixes := {}
	for c in backs:
		var id := String(c.id)
		EdenModel.use_back_fix = false
		var before := await _measure(cls, c)
		var info := {"id": id, "name": c.name, "before": before}
		if write and not before.is_empty():
			var f := _fit(before, String(c.name), id)
			if f != Transform3D.IDENTITY:
				fixes[id] = [f.basis.x.x, f.basis.x.y, f.basis.x.z, f.basis.y.x, f.basis.y.y, f.basis.y.z,
					f.basis.z.x, f.basis.z.y, f.basis.z.z, f.origin.x, f.origin.y, f.origin.z].map(func(v): return snappedf(v, 0.0001))
		out.append(info)
	if write:
		var fw := FileAccess.open("res://data/back_fix.json", FileAccess.WRITE)
		fw.store_string(JSON.stringify(fixes, " "))
		fw.close()
		EdenModel._back_fix = fixes
	EdenModel.use_back_fix = true
	for i in backs.size():
		out[i]["after"] = await _measure(cls, backs[i])
	DirAccess.make_dir_recursive_absolute("user://shots")
	var f := FileAccess.open("user://shots/probe_backs.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("probe : %d pièces, %d corrections" % [out.size(), fixes.size()])
	get_tree().quit()


## Correction : quart de tour autour de l'os si la pièce est plus profonde que large, puis
## décalage pour ramener le milieu dans le dos (les ailes « simples » gardent leur côté).
func _fit(m: Dictionary, name: String, id := "") -> Transform3D:
	var med: Vector3 = m.med
	var spread: Vector3 = m.spread
	var rot := Basis.IDENTITY
	var forced := ""
	for k in FORCE_YAW:
		if id.begins_with(k):
			forced = k
	if forced != "":
		rot = Basis(Vector3.UP, deg_to_rad(float(FORCE_YAW[forced])))
		med = rot * Vector3(m.med)
	elif spread.z > spread.x * 1.25 and spread.z > 1.2:
		rot = Basis(Vector3.UP, PI * 0.5)
		if (rot * Vector3(m.med)).z > 0.0:
			rot = Basis(Vector3.UP, -PI * 0.5)
		med = rot * Vector3(m.med)
	var t := Vector3.ZERO
	if absf(med.x) > 0.3 and not name.to_lower().contains("single"):
		t.x = -med.x
	if med.z > -0.2 or med.z < -1.0:
		t.z = TARGET_Z - med.z
	if med.y > 0.9 or med.y < -0.5:
		t.y = TARGET_Y - med.y
	if rot == Basis.IDENTITY and t.length() < 0.01:
		return Transform3D.IDENTITY
	# rotation autour de l'os du dos (origine des mesures), puis décalage ; repère du modèle
	var sp: Vector3 = m.spine
	return Transform3D(rot, sp - rot * sp + t)


func _measure(cls: Dictionary, c: Dictionary) -> Dictionary:
	var path := String(c.outfit)
	var model := EdenModel.instantiate_hero(cls, "", [path])
	add_child(model)
	await get_tree().process_frame
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var inv := model.global_transform.affine_inverse()
	var spine := inv * (skel.global_transform * skel.get_bone_global_pose(skel.find_bone(EdenModel.BACK_BONE))).origin
	var pts: Array = skinned_points(model, skel, path)
	var skinned := not pts.is_empty()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null and String(mi.get_meta("part", "")) == path:
			var faces := mi.mesh.get_faces()
			var step := maxi(1, faces.size() / 60)
			for k in range(0, faces.size(), step):
				pts.append(inv * (mi.global_transform * faces[k]))
	model.queue_free()
	if pts.is_empty() or not skinned:
		return {}
	var med := Vector3.ZERO
	var spread := Vector3.ZERO
	for ax in 3:
		var vals: Array = pts.map(func(q): return q[ax] - spine[ax])
		vals.sort()
		med[ax] = vals[vals.size() / 2]
		spread[ax] = vals[int(vals.size() * 0.9)] - vals[int(vals.size() * 0.1)]
	return {"med": med.snapped(Vector3.ONE * 0.01), "spread": spread.snapped(Vector3.ONE * 0.01), "spine": spine}


## Sommets de la pièce après habillage (peau calculée à la main, pose actuelle), repère du modèle.
static func skinned_points(model: Node3D, skel: Skeleton3D, path: String) -> Array:
	var out: Array = []
	var inv := model.global_transform.affine_inverse()
	for mi: MeshInstance3D in skel.get_children().filter(func(x): return x is MeshInstance3D and String(x.get_meta("part", "")) == path):
		var sk: Skin = mi.skin
		if sk == null:
			continue
		var bone_xf := []
		for j in sk.get_bind_count():
			var bi := skel.find_bone(sk.get_bind_name(j)) if sk.get_bind_name(j) != "" else sk.get_bind_bone(j)
			bone_xf.append(skel.global_transform * skel.get_bone_global_pose(maxi(bi, 0)) * sk.get_bind_pose(j))
		for si in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones = arr[Mesh.ARRAY_BONES]
			var weights = arr[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null or verts.is_empty():
				continue
			var per := int(bones.size() / verts.size())
			var step := maxi(1, verts.size() / 400)
			for v in range(0, verts.size(), step):
				var acc := Vector3.ZERO
				var wsum := 0.0
				for k in per:
					var w := float(weights[v * per + k])
					if w <= 0.0:
						continue
					var bj := int(bones[v * per + k])
					if bj < bone_xf.size():
						acc += (bone_xf[bj] * verts[v]) * w
						wsum += w
				if wsum > 0.0:
					out.append(inv * (acc / wsum))
	return out
