class_name ClassPremium
extends RefCounted
## « Héros détaillé » (lot CHR-2, conception/art/R_CHR2.md) : niveau de finition au-dessus de ClassLook pour une classe faite à
## la main (clé look.premium de data/classes_custom.json). Réglage de rendu Paramètres > Affichage « Héros détaillé »
## (display.hero_detail, oui par défaut). Les 60 classes d'Eden n'ont pas cette clé : rien ne change pour elles.
##   anims   : bibliothèque d'animations faites dans Blender (tools/art/chr2_anims.py -> tools/chr2/chr2_anim_build.gd), ajoutée à
##             l'AnimationPlayer du héros sous le nom « chr2 » ; remap { animation d'Eden : animation neuve } : le jeu cale
##             toujours ses coups sur l'animation d'Eden (longueur, impact) et ne fait que JOUER la neuve à sa place
##             (Combatant.anim_remap) ; les neuves ont la même longueur et le même impact : le jeu ne change pas avec le réglage ;
##             skip_poses : poses procédurales (ProcPose) que les neuves remplacent ; ult : [charge, lancer, avance du lancer s] ;
##   head    : pièce GLB (tools/art/chr2_head.py) : visage subdivisé texture 2048, mèches 3D, bandeau, rubans, avec ses os
##             (cheveux ×4, rubans ×6) que EdenModel.dress ajoute au squelette ; remplace le visage d'Eden, la coiffure de la
##             classe et les ajouts par code de ClassLook (bandeau, mèches, rubans) ; springs : ressorts SpringBoneSimulator3D ;
##   outfit_tex : texture 2048 de la tenue de la classe (agrandie par IA, tools/art/chr2_tex.py), teintures gardées.
## Les fichiers de dir (tête, textures) d'un design inspiré d'une œuvre restent HORS du dépôt public (dossier ignoré par git) :
## sans eux, seules les animations s'appliquent.

const LIB := "chr2"


static func enabled() -> bool:
	return bool(Settings.get_v("display", "hero_detail"))


static func spec(cls: Dictionary) -> Dictionary:
	return cls.get("look", {}).get("premium", {})


## Chemin d'un fichier de la tête détaillée (vide s'il n'est pas sur ce PC).
static func file(cls: Dictionary, key: String) -> String:
	var p := spec(cls)
	if not p.has(key):
		return ""
	var path := String(p.get("dir", "")).path_join(String(p[key]))
	return path if ResourceLoader.exists(path) or FileAccess.file_exists(path) else ""


## La tête détaillée sera-t-elle posée (réglage, fichiers présents, rien sur la tête ni coiffure choisie) ?
static func head_on(cls: Dictionary, opts: Dictionary) -> bool:
	return enabled() and file(cls, "head") != "" and not opts.get("worn_head", false) and not opts.get("hair_set", false)


## Appelé par ClassLook.apply avant les ajouts par code ; renvoie true si la tête détaillée a été posée (ClassLook saute
## alors bandeau, mèches, rubans et traits du visage).
static func apply(model: Node3D, cls: Dictionary, opts: Dictionary) -> bool:
	var p := spec(cls)
	if p.is_empty() or model == null or not enabled():
		return false
	_add_anims(model, cls, p)
	var tex := file(cls, "outfit_tex")
	var parts: Array = cls.get("parts", [])
	if tex != "" and String(opts.get("outfit", "")) == "" and not parts.is_empty():
		_outfit_texture(model, String(parts[0]), load(tex) as Texture2D, String(p.get("outfit_src", "")))
	if not head_on(cls, opts):
		return false
	var sk := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if sk == null:
		return false
	# visage et coiffure d'Eden retirés : la pièce détaillée les remplace
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part := String(mi.get_meta("part", ""))
		if mi.name == "#LFACE" or (parts.size() >= 2 and part == String(parts[1])):
			mi.get_parent().remove_child(mi)
			mi.free()
	EdenModel.dress(model, file(cls, "head"))
	_add_springs(sk, p.get("springs", []), not opts.get("no_motion", false))
	model.set_meta("premium_head", true)
	return true


static func _add_anims(model: Node3D, cls: Dictionary, p: Dictionary) -> void:
	var path := String(p.get("anims", ""))
	var ap := EdenModel.find_anim_player(model)
	if path == "" or ap == null or not ResourceLoader.exists(path):
		return
	if not ap.has_animation_library(LIB):
		ap.add_animation_library(LIB, load(path) as AnimationLibrary)
	var remap := {}
	for k: String in p.get("remap", {}):
		var key := k
		if k == "battle":  # garde : l'animation de combat de l'arme de la classe
			key = String(GameData.weapon_type(String(cls.get("weapon_type", ""))).get("battle", cls.get("anims", {}).get("battle", "battle13")))
		var dst := LIB + "/" + String(p.remap[k])
		if ap.has_animation(dst):
			remap[key] = dst
	model.set_meta("anim_remap", remap)
	model.set_meta("proc_skip", p.get("skip_poses", []))
	if p.has("ult"):
		model.set_meta("premium_ult", p.ult)


## Animation neuve qui remplace [param eden_anim] sur ce modèle (vide sinon).
static func remapped(model: Node3D, eden_anim: String) -> String:
	if model == null:
		return ""
	return String((model.get_meta("anim_remap", {}) as Dictionary).get(eden_anim, ""))


## Ultime en deux temps (NinjaArts) : la charge tout de suite, le lancer [param t_throw] s plus tard ; false si pas d'animation.
static func play_ult(c: Combatant, t_throw: float) -> bool:
	if c == null or c.model == null or not c.model.has_meta("premium_ult"):
		return false
	var u: Array = c.model.get_meta("premium_ult")
	var charge := LIB + "/" + String(u[0])
	var throw := LIB + "/" + String(u[1])
	if c.anim == null or not c.anim.has_animation(charge) or not c.anim.has_animation(throw):
		return false
	c.anim.play(charge, 0.06)
	c.anim.seek(0.0, true)
	var lead := float(u[2]) if u.size() > 2 else 0.12
	c.get_tree().create_timer(maxf(t_throw - lead, 0.05), false).timeout.connect(func():
		if is_instance_valid(c) and c.anim and not c.is_dead:
			c.anim.play(throw, 0.05)
			c.anim.seek(0.0, true))
	return true


## Texture agrandie de la tenue : remplace sur la pièce [param part] la texture d'origine nommée [param src_file]
## (teintures gardées : seul albedo_tex change dans la copie du matériau).
static func _outfit_texture(model: Node3D, part: String, tex: Texture2D, src_file: String) -> void:
	if tex == null:
		return
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if String(mi.get_meta("part", "")) != part:
			continue
		for i in mi.mesh.get_surface_count():
			var ov := mi.get_surface_override_material(i)
			var src := mi.mesh.surface_get_material(i) as BaseMaterial3D
			if ov is ShaderMaterial and src and src.albedo_texture and src.albedo_texture.resource_path.get_file() == src_file:
				var m := (ov as ShaderMaterial).duplicate() as ShaderMaterial
				m.set_shader_parameter("albedo_tex", tex)
				mi.set_surface_override_material(i, m)


## Ressorts (SpringBoneSimulator3D) des os neufs : une chaîne par réglage {root, end, stiff, drag, gravity, radius}.
static func _add_springs(sk: Skeleton3D, springs: Array, moving: bool) -> void:
	if springs.is_empty() or not moving:
		return
	var sim := SpringBoneSimulator3D.new()
	sim.name = "PremiumSprings"
	sk.add_child(sim)
	var ok := 0
	for s: Dictionary in springs:
		if sk.find_bone(String(s.root)) < 0 or sk.find_bone(String(s.end)) < 0:
			continue
		ok += 1
	sim.setting_count = ok
	var i := 0
	for s: Dictionary in springs:
		if sk.find_bone(String(s.root)) < 0 or sk.find_bone(String(s.end)) < 0:
			continue
		sim.set_root_bone_name(i, String(s.root))
		sim.set_end_bone_name(i, String(s.end))
		sim.set_extend_end_bone(i, true)
		sim.set_end_bone_direction(i, SpringBoneSimulator3D.BONE_DIRECTION_PLUS_X)
		sim.set_end_bone_length(i, float(s.get("tail", 0.1)))
		sim.set_stiffness(i, float(s.get("stiff", 1.0)))
		sim.set_drag(i, float(s.get("drag", 0.4)))
		sim.set_gravity(i, float(s.get("gravity", 0.5)))
		sim.set_radius(i, float(s.get("radius", 0.02)))
		i += 1
	# la tête et le haut du dos repoussent rubans et mèches
	for c: Array in [["Bip01 Head", Vector3(0.18, 0.06, 0.0), 0.2], ["Bip01 Spine1", Vector3(0.05, -0.02, 0.0), 0.16]]:
		var col := SpringBoneCollisionSphere3D.new()
		col.bone_name = String(c[0])
		col.position_offset = c[1]
		col.radius = float(c[2])
		sim.add_child(col)
