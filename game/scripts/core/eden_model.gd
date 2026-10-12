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


## Passe tous les matériaux en ombrage toon, avec une texture de remplacement
## optionnelle (variantes de couleur d'un même monstre).
static func stylize(root: Node, texture: Texture2D = null) -> void:
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat == null:
				continue
			var key := "%d|%s" % [mat.get_instance_id(), texture.resource_path if texture else ""]
			var toon: BaseMaterial3D = _toon_cache.get(key)
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
	var weapons: Array = cls.get("weapons", [])
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
