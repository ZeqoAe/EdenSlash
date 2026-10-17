class_name ClassLook
extends RefCounted
## Apparence propre à une classe faite à la main (lot CHR-1 ; clé « look » de data/classes_custom.json). Les 60 classes d'Eden
## n'ont pas cette clé : rien ne change pour elles. Tout est fait par code sur des pièces d'Eden déjà dans le jeu (aucun
## fichier d'image ou de modèle propre à ce design dans le dépôt) :
##   dye        : { pièce .glb : 3 couleurs } teintures (tenue, accessoire de tête), si le joueur n'a pas choisi la sienne ;
##   hair_tint  : couleur des cheveux de la classe (variante grise teinte), si le joueur n'a pas choisi sa coiffure ;
##   hair_gain  : éclaircit la texture des cheveux avant la teinte (un blond vif sur la variante grise, sombre) ;
##   head       : accessoire de tête d'Eden porté par défaut, si le joueur ne porte rien sur la tête ;
##   band       : bandeau frontal fait par code (anneau de tissu autour de la tête + plaque de métal lisse devant) ;
##   face_marks : traits peints sur la texture du visage (repère 512 px de lfaces01b : [x0, y0, x1, y1, épaisseur]) ;
##   spikes     : mèches en pointes ajoutées sur la tête (cônes, couleur des cheveux) ;
##   ribbon     : deux rubans de bandeau à ressort derrière la tête (chaîne de points, rendu en bande, suit la tête).
##   premium    : « Héros détaillé » (lot CHR-2, ClassPremium) : animations neuves, tête détaillée, tenue 2048.
## Appelé par Player._dress_model, EdenModel.instantiate_hero et ClassRival._ready.

const FACE_TEX := "res://assets/player/textures/lfaces01b__4c3821.png"
const FACE_MESH := "#LFACE"
static var _face_cache := {}  # clé des traits -> ImageTexture


## [param opts] : outfit (tenue choisie par le joueur, "" = celle de la classe), worn_head (accessoire de tête porté),
## hair_set (coiffure ou couleur choisie dans la création de personnage), no_motion (aperçu figé : pas de ruban animé).
static func apply(model: Node3D, cls: Dictionary, opts: Dictionary = {}) -> void:
	var look: Dictionary = cls.get("look", {})
	if look.is_empty() or model == null:
		return
	var parts: Array = cls.get("parts", [])
	var outfit := String(opts.get("outfit", ""))
	var dyes: Dictionary = look.get("dye", {})
	if outfit == "" and parts.size() >= 1 and dyes.has(String(parts[0])):
		EdenModel.apply_dye(model, String(parts[0]), dyes[String(parts[0])])
	var hair_set: bool = opts.get("hair_set", false)
	if ClassPremium.apply(model, cls, opts):
		return  # tête détaillée (lot CHR-2) : visage, cheveux, bandeau et rubans sont dans la pièce
	if not hair_set and parts.size() >= 2 and look.has("hair_tint"):
		var c: Array = look.hair_tint
		HeroLook._tint_part(model, String(parts[1]), Color8(int(c[0]), int(c[1]), int(c[2])))
		if look.has("hair_gain"):
			_gain_part(model, String(parts[1]), float(look.hair_gain))
	var head := String(look.get("head", ""))
	var worn_head: bool = opts.get("worn_head", false)
	if head != "" and not worn_head and ResourceLoader.exists(head):
		EdenModel.dress(model, head)
		if dyes.has(head):
			EdenModel.apply_dye(model, head, dyes[head])
	if look.has("band") and not worn_head:
		_add_band(model, look.band)
	if look.has("face_marks"):
		_paint_face(model, look.face_marks)
	if look.has("spikes") and not hair_set:
		_add_spikes(model, look.spikes)
	if look.has("ribbon") and (head != "" or look.has("band")) and not worn_head:
		_add_ribbon(model, look.ribbon, not opts.get("no_motion", false))


## Éclaircit la texture d'une pièce (multiplie sa couleur avant la teinte).
static func _gain_part(model: Node3D, path: String, gain: float) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if String(mi.get_meta("part", "")) != path:
			continue
		for i in mi.mesh.get_surface_count():
			var ov := mi.get_surface_override_material(i)
			if ov is ShaderMaterial:
				var m := (ov as ShaderMaterial).duplicate() as ShaderMaterial
				m.set_shader_parameter("albedo_color", Color(gain, gain, gain, 1.0))
				mi.set_surface_override_material(i, m)


# --- bandeau ------------------------------------------------------------------------------------------------
## Anneau de tissu autour de la tête (repère de l'os de la tête : X = haut, Y = devant, Z = côté), plus bas devant
## (front) que derrière, et plaque de métal lisse sur le front (aucun symbole).
static func _add_band(model: Node3D, bd: Dictionary) -> void:
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or sk.find_bone("Bip01 Head") < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "Bip01 Head"
	att.name = "ClassLookBand"
	sk.add_child(att)
	var h := float(bd.get("height", 0.27))  # hauteur du milieu de l'anneau sur l'os
	var tilt := float(bd.get("tilt", 0.03))  # plus bas devant de tant
	var r: Array = bd.get("radius", [0.23, 0.22])  # [devant-derrière, côtés]
	var w := float(bd.get("width", 0.065))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 40
	var ring: Array = []
	for i in segs + 1:
		var a := TAU * float(i) / segs
		var c := Vector3(h - tilt * cos(a), float(r[0]) * cos(a), float(r[1]) * sin(a))
		var out := Vector3(0.0, cos(a), sin(a)).normalized()
		ring.append([c, out])
	for i in segs:
		var a0: Vector3 = ring[i][0]
		var a1: Vector3 = ring[i + 1][0]
		var n0: Vector3 = ring[i][1]
		var n1: Vector3 = ring[i + 1][1]
		var up := Vector3(w * 0.5, 0, 0)
		for tri in [[a0 - up, a1 - up, a1 + up, n0, n1, n1], [a0 - up, a1 + up, a0 + up, n0, n1, n0]]:
			for k in 3:
				st.set_normal(tri[k + 3])
				st.add_vertex(tri[k])
	var band := MeshInstance3D.new()
	band.mesh = st.commit()
	band.material_override = _toon(bd.get("color", [34, 46, 92]), true)
	att.add_child(band)
	# plaque : boîte plate posée sur le devant de l'anneau, un liseré sombre autour
	var ps: Array = bd.get("plate", [0.075, 0.15])  # [hauteur, largeur]
	var front := Vector3(h - tilt, float(r[0]) + 0.006, 0.0)
	var rim := MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(float(ps[0]) + 0.012, 0.012, float(ps[1]) + 0.014)
	rim.mesh = rb
	rim.material_override = _toon([40, 44, 58], false)
	rim.position = front
	att.add_child(rim)
	var plate := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(float(ps[0]), 0.016, float(ps[1]))
	plate.mesh = pb
	plate.material_override = _toon(bd.get("plate_color", [200, 208, 222]), false, 0.1)
	plate.position = front + Vector3(0, 0.004, 0)
	att.add_child(plate)


static func _toon(c: Array, two_sided: bool, rim := 0.25) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color8(int(c[0]), int(c[1]), int(c[2]))
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = 0.8
	m.rim_enabled = true
	m.rim = rim
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


# --- visage ----------------------------------------------------------------------------------------------
static func _paint_face(model: Node3D, marks: Dictionary) -> void:
	var tex := face_texture(marks)
	if tex == null:
		return
	for mi: MeshInstance3D in model.find_children(FACE_MESH, "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var ov := mi.get_surface_override_material(i)
			if ov is ShaderMaterial:
				var m := (ov as ShaderMaterial).duplicate() as ShaderMaterial
				m.set_shader_parameter("albedo_tex", tex)
				mi.set_surface_override_material(i, m)


## Texture du visage avec les traits peints (calculée une fois par jeu de traits).
static func face_texture(marks: Dictionary) -> Texture2D:
	var key := str(marks)
	if _face_cache.has(key):
		return _face_cache[key]
	if not ResourceLoader.exists(FACE_TEX):
		return null
	var src := load(FACE_TEX) as Texture2D
	var img := src.get_image() if src else null
	if img == null or img.is_empty():
		return null
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var c: Array = marks.get("color", [70, 44, 40])
	var col := Color8(int(c[0]), int(c[1]), int(c[2]))
	var k := float(img.get_width()) / 512.0
	for ln: Array in marks.get("lines", []):
		_stroke(img, Vector2(float(ln[0]), float(ln[1])) * k, Vector2(float(ln[2]), float(ln[3])) * k, float(ln[4]) * k, col)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_face_cache[key] = tex
	return tex


## Trait au pinceau : épais au milieu, effilé aux deux bouts, bord adouci.
static func _stroke(img: Image, a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var lo := Vector2i(floori(minf(a.x, b.x) - width - 2), floori(minf(a.y, b.y) - width - 2))
	var hi := Vector2i(ceili(maxf(a.x, b.x) + width + 2), ceili(maxf(a.y, b.y) + width + 2))
	var ab := b - a
	var len2 := maxf(ab.length_squared(), 0.0001)
	for y in range(maxi(lo.y, 0), mini(hi.y, img.get_height())):
		for x in range(maxi(lo.x, 0), mini(hi.x, img.get_width())):
			var pt := Vector2(x + 0.5, y + 0.5)
			var t := clampf((pt - a).dot(ab) / len2, 0.0, 1.0)
			var d := pt.distance_to(a + ab * t)
			var w := width * 0.5 * (0.35 + 0.65 * sin(t * PI))  # effilé
			var cover := clampf(w + 0.6 - d, 0.0, 1.0)
			if cover > 0.0:
				var base := img.get_pixel(x, y)
				img.set_pixel(x, y, base.lerp(Color(col.r, col.g, col.b, base.a), cover * 0.9))


# --- mèches en pointes -------------------------------------------------------------------------------------
## Cônes posés sur la tête, dans le repère de l'os de la tête (X = haut, Y = devant, Z = côté), couleur des cheveux.
static func _add_spikes(model: Node3D, sp: Dictionary) -> void:
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or sk.find_bone("Bip01 Head") < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = "Bip01 Head"
	att.name = "ClassLookSpikes"
	sk.add_child(att)
	var mat: Material = _toon(sp.get("color", [240, 200, 90]), false, 0.15)  # aplat de la couleur des cheveux teints
	# [hauteur sur l'os, avant(+)/arrière(-), côté, longueur, rayon, inclinaison vers l'arrière, écart sur le côté]
	for s: Array in sp.get("list", []):
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = float(s[4])
		cone.height = float(s[3])
		cone.radial_segments = 6
		cone.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = mat
		# le cylindre pousse le long de son Y : on l'oriente le long de X (le haut de l'os), puis on l'incline
		var dir := Vector3(1.0, -float(s[5]), float(s[6])).normalized()
		var basis := Basis(Quaternion(Vector3.UP, dir))
		mi.transform = Transform3D(basis, Vector3(float(s[0]), float(s[1]), float(s[2])) + dir * float(s[3]) * 0.5)
		att.add_child(mi)


# --- rubans du bandeau -------------------------------------------------------------------------------------
static func _add_ribbon(model: Node3D, rb: Dictionary, moving: bool) -> void:
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null or sk.find_bone("Bip01 Head") < 0:
		return
	var c: Array = rb.get("color", [40, 40, 60])
	for side in [-1.0, 1.0]:
		var r := RibbonTail.new()
		r.color = Color8(int(c[0]), int(c[1]), int(c[2]))
		r.length = float(rb.get("length", 0.5))
		r.width = float(rb.get("width", 0.07))
		r.moving = moving
		var o: Array = rb.get("anchor", [0.33, -0.17, 0.05])
		r.anchor_local = Vector3(float(o[0]), float(o[1]), float(o[2]) * side)
		r.skel = sk
		r.side = side
		model.add_child(r)


## Ruban à ressort (« os dynamique » sans os) : une chaîne de points intégrée (Verlet), accrochée derrière la tête, qui
## traîne derrière le héros, retombe et ondule ; rendue en bande face caméra. Coût : quelques points par héros.
class RibbonTail extends MeshInstance3D:
	var skel: Skeleton3D
	var anchor_local := Vector3.ZERO  # repère de l'os de la tête
	var color := Color(0.15, 0.15, 0.22)
	var length := 0.5
	var width := 0.07
	var side := 1.0
	var moving := true
	const N := 7
	var _pts: Array[Vector3] = []
	var _prev: Array[Vector3] = []
	var _head := -1
	var _t := 0.0

	func _ready() -> void:
		top_level = true
		global_transform = Transform3D.IDENTITY  # sommets en coordonnées du monde (top_level garde sinon le repère du modèle)
		mesh = ImmediateMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		material_override = m
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_head = skel.find_bone("Bip01 Head")
		var a := _anchor()
		for i in N:
			var p := a + Vector3.DOWN * length * float(i) / (N - 1)
			_pts.append(p)
			_prev.append(p)

	func _anchor() -> Vector3:
		return skel.global_transform * (skel.get_bone_global_pose(_head) * anchor_local)

	func _process(delta: float) -> void:
		if not is_instance_valid(skel) or _head < 0:
			return
		_t += delta
		var seg := length / (N - 1)
		var scale_k := skel.global_transform.basis.get_scale().x
		seg *= scale_k
		_pts[0] = _anchor()
		if moving:
			var dt := clampf(delta, 0.0, 1.0 / 30.0)
			var wind := Vector3(sin(_t * 3.1 + side) * 0.6, 0.0, cos(_t * 2.3) * 0.4)
			for i in range(1, N):
				var v := (_pts[i] - _prev[i]) * 0.9
				_prev[i] = _pts[i]
				_pts[i] += v + (Vector3.DOWN * 9.0 + wind) * dt * dt
			for _k in 3:
				for i in range(1, N):
					var d := _pts[i] - _pts[i - 1]
					var l := d.length()
					if l > 0.0001:
						_pts[i] = _pts[i - 1] + d / l * seg
		else:
			var back := -skel.global_transform.basis.z.normalized()
			for i in range(1, N):
				_pts[i] = _pts[0] + (Vector3.DOWN * 0.8 + back * 0.5).normalized() * seg * i
		_draw()

	func _draw() -> void:
		var im := mesh as ImmediateMesh
		im.clear_surfaces()
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		var w := width * skel.global_transform.basis.get_scale().x
		for i in N:
			var p := _pts[i]
			var tng := (_pts[mini(i + 1, N - 1)] - _pts[maxi(i - 1, 0)]).normalized()
			var to_cam := (cam.global_position - p).normalized()
			var side_v := tng.cross(to_cam).normalized() * w * (1.0 - 0.45 * float(i) / (N - 1))
			var shade := color.lerp(color.darkened(0.35), float(i) / (N - 1))
			im.surface_set_color(shade)
			im.surface_add_vertex(p - side_v)
			im.surface_set_color(shade.lightened(0.1))
			im.surface_add_vertex(p + side_v)
		im.surface_end()
