class_name EdenModel
extends RefCounted
## Chargement des modèles convertis depuis Eden Eternal (.glb + .anims.json)
## et application du rendu « manga » (toon).

static var _anim_info := {}  # chemin json -> Dictionary
static var _toon_cache := {}  # clé matériau/texture -> BaseMaterial3D


## Instancie un modèle et règle les boucles d'animation d'après le jeu d'origine.
static func instantiate(glb_path: String, texture_path := "") -> Node3D:
	var scene: PackedScene = load(glb_path)
	var node: Node3D = scene.instantiate()
	var anim := find_anim_player(node)
	if anim:
		_apply_anim_info(anim, glb_path.get_basename() + ".anims.json")
	var tex: Texture2D = load(texture_path) if texture_path != "" else null
	stylize(node, tex)
	return node


static func find_anim_player(node: Node) -> AnimationPlayer:
	return node.find_child("AnimationPlayer", true, false) as AnimationPlayer


static func anim_info(glb_path: String) -> Dictionary:
	return _anim_info.get(glb_path.get_basename() + ".anims.json", {})


static func _apply_anim_info(player: AnimationPlayer, json_path: String) -> void:
	if _anim_info.has(json_path):
		return  # les ressources Animation sont partagées entre instances
	var info: Dictionary = {}
	if FileAccess.file_exists(json_path):
		info = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	for lib_name in player.get_animation_library_list():
		var lib := player.get_animation_library(lib_name)
		for anim_name in lib.get_animation_list():
			if info.has(anim_name):
				var a := lib.get_animation(anim_name)
				a.loop_mode = Animation.LOOP_LINEAR if info[anim_name].loop else Animation.LOOP_NONE
	_anim_info[json_path] = info


## Passe les matériaux en éclairage stylisé (shaders/eden_character.gdshader ; toon
## standard pour les matériaux à transparence fondue), avec une texture de remplacement
## optionnelle (variantes de couleur d'un même monstre).
static func stylize(root: Node, texture: Texture2D = null) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null:
				continue
			var key := "%d|%s" % [mat.get_instance_id(), texture.resource_path if texture else ""]
			var toon: Material = _toon_cache.get(key)
			if toon == null and mat.transparency in [BaseMaterial3D.TRANSPARENCY_DISABLED, BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR]:
				toon = _character_material(mat, texture)
				_toon_cache[key] = toon
			if toon == null:
				toon = mat.duplicate()
				toon.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				toon.specular_mode = BaseMaterial3D.SPECULAR_TOON
				toon.roughness = 1.0
				toon.rim_enabled = true
				toon.rim = 0.35
				toon.rim_tint = 0.6
				if texture:
					toon.albedo_texture = texture
				if toon.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
					toon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				_toon_cache[key] = toon
			mi.set_surface_override_material(s, toon)


const CHARACTER_SHADER := preload("res://shaders/eden_character.gdshader")
static var _character_2sided: Shader


static func _character_material(src: BaseMaterial3D, texture: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if src.cull_mode == BaseMaterial3D.CULL_DISABLED:
		if _character_2sided == null:
			_character_2sided = Shader.new()
			_character_2sided.code = CHARACTER_SHADER.code.replace("cull_back", "cull_disabled")
		m.shader = _character_2sided
	else:
		m.shader = CHARACTER_SHADER
	m.set_shader_parameter("albedo_tex", texture if texture else src.albedo_texture)
	m.set_shader_parameter("albedo_color", src.albedo_color)
	m.set_shader_parameter("use_vertex_color", 1.0 if src.vertex_color_use_as_albedo else 0.0)
	if src.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
		m.set_shader_parameter("alpha_cut", maxf(src.alpha_scissor_threshold, 0.1))
	return m


## Héros d'une classe : corps animé commun (squelette, visage, animations) habillé de
## pièces séparées (tenue, cheveux) ; [param outfit] remplace la tenue de la classe (skin).
## Les anciennes classes à modèle complet (data/classes.json -> model) restent gérées.
static func instantiate_hero(cls: Dictionary, outfit := "") -> Node3D:
	var body := String(cls.get("body_model", ""))
	if body == "" or not ResourceLoader.exists(body):
		return instantiate(String(cls.get("model", "")))
	var node := instantiate(body)
	strip_body(node)
	var parts: Array = cls.get("parts", [])
	if outfit != "" and ResourceLoader.exists(outfit):
		parts = [outfit] + parts.slice(1)
	for p in parts:
		dress(node, String(p))
	return node


## Le corps commun est exporté avec une tenue complète (pour que tous ses os soient de
## vrais os animés) : on ne garde que le visage avant d'habiller le héros.
static func strip_body(model: Node3D) -> void:
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name != "#LFACE" and not mi.has_meta("part"):
			mi.get_parent().remove_child(mi)
			mi.free()


## Habille le modèle d'une pièce (.glb exporté sur le même squelette) : ses maillages
## passent sous le squelette du modèle et suivent ses animations.
static func dress(model: Node3D, glb_path: String, group := "") -> void:
	if not ResourceLoader.exists(glb_path):
		return
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	var part: Node = (load(glb_path) as PackedScene).instantiate()
	stylize(part)
	# os propres à la pièce (manches, rubans...) : ajoutés au squelette, au repos
	var src := part.find_child("Skeleton3D", true, false) as Skeleton3D
	var added := false
	if src:
		for b in src.get_bone_count():
			var bname := src.get_bone_name(b)
			if skel.find_bone(bname) >= 0:
				continue
			var idx := skel.get_bone_count()
			skel.add_bone(bname)
			var parent := src.get_bone_parent(b)
			if parent >= 0:
				skel.set_bone_parent(idx, skel.find_bone(src.get_bone_name(parent)))
			skel.set_bone_rest(idx, src.get_bone_rest(b))
			skel.reset_bone_pose(idx)
			added = true
	if added:
		# nouveaux os : les maillages déjà habillés réenregistrent leur peau sur le squelette
		for old in skel.get_children():
			if old is MeshInstance3D and old.skin:
				old.skeleton = NodePath("")
				old.skeleton = NodePath("..")
	for mi: MeshInstance3D in part.find_children("*", "MeshInstance3D", true, false):
		var xf := mi.transform
		mi.owner = null
		mi.get_parent().remove_child(mi)
		skel.add_child(mi)
		mi.transform = xf
		mi.skeleton = NodePath("..")
		mi.set_meta("part", glb_path)
		if group != "":
			mi.add_to_group(group)
	part.free()


## Remplace la tenue portée (skin) par [param glb_path].
static func change_outfit(model: Node3D, old_path: String, glb_path: String) -> void:
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return
	for mi in skel.get_children():
		if mi is MeshInstance3D and String(mi.get_meta("part", "")) == old_path:
			mi.queue_free()
	dress(model, glb_path)


## Met une arme d'Eden (data/classes.json -> weapons) dans la main du modèle.
## Renvoie le nœud attaché à l'os (ou null).
static func attach_weapon(model: Node3D, weapon: Dictionary) -> BoneAttachment3D:
	if weapon.is_empty() or not ResourceLoader.exists(weapon.model):
		return null
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel == null:
		return null
	var bone := ""
	var bones: Array = [weapon.bone] if weapon.has("bone") else []
	for b in bones + ["Bip01 Prop1", "Bip01 R Hand"]:
		if skel.find_bone(b) >= 0:
			bone = b
			break
	if bone == "":
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skel.add_child(att)
	var inst := instantiate(weapon.model, weapon.texture if ResourceLoader.exists(weapon.texture) else "")
	# l'arme est déjà exprimée dans le repère de l'os : on annule la conversion Z-up
	var root := inst.find_child("EdenRoot", true, false) as Node3D
	if root:
		root.transform = Transform3D.IDENTITY
	att.add_child(inst)
	return att


static func weapon_entry(cls: Dictionary, code: String) -> Dictionary:
	var eden: Dictionary = GameData.eden_by_code.get(code, {})
	if eden.has("model"):
		var we := {"code": code, "model": eden.model, "texture": eden.texture}
		var bone := String(GameData.weapon_type(String(eden.get("wtype", ""))).get("bone", ""))
		if bone != "":
			we["bone"] = bone
		return we
	for wt in GameData.weapon_types.values():
		for w in wt.get("weapons", []):
			if w.code == code:
				return w
	var weapons: Array = GameData.weapon_type(String(cls.get("weapon_type", "katana"))).get("weapons", cls.get("weapons", []))
	for w in weapons:
		if w.code == code:
			return w
	return weapons[0] if not weapons.is_empty() else {}


## Boîte englobante (au repos) de tous les maillages d'un modèle.
static func bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var b := _relative_xform(root, mi) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _relative_xform(root: Node3D, node: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
