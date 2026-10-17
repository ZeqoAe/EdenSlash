class_name HeroOutline
extends RefCounted
## Contour du héros (lot SVX-1, Survivant : « héros toujours contouré ») : chaque maillage du modèle reçoit en calque
## (material_overlay) la passe de gabarit hero_outline_mask, suivie du liseré hero_outline (lagon clair, 2,5 px à l'écran),
## dessiné par-dessus monstres, boss, effets et décor. Un modèle rhabillé (pièce équipée) perd ses calques : apply les
## remet (appelé régulièrement par SurvivorDirector) ; clear les retire.

const COLOR := Color(0.525, 0.867, 1.0)  # lagon clair #86DDFF (le focus : « toi »)
const WIDTH := 2.5
static var _mat: ShaderMaterial


## Calque partagé (passe de gabarit + liseré).
static func material() -> ShaderMaterial:
	if _mat == null:
		var line := ShaderMaterial.new()
		line.shader = preload("res://shaders/hero_outline.gdshader")
		line.set_shader_parameter("color", COLOR)
		line.set_shader_parameter("width", WIDTH)
		line.render_priority = Material.RENDER_PRIORITY_MAX
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://shaders/hero_outline_mask.gdshader")
		_mat.render_priority = Material.RENDER_PRIORITY_MAX - 1
		_mat.next_pass = line
	return _mat


## Pose le contour sur les maillages de [param model] qui ne l'ont pas encore ; renvoie le nombre de maillages contourés.
static func apply(model: Node) -> int:
	if model == null or not is_instance_valid(model):
		return 0
	var n := 0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if _in_fx(mi):
			continue
		if mi.material_overlay != material():
			if mi.material_overlay != null:
				continue  # un autre calque (éclair d'impact) : on ne le remplace pas
			mi.material_overlay = material()
		n += 1
	return n


## Retire le contour des maillages de [param model].
static func clear(model: Node) -> void:
	if model == null or not is_instance_valid(model):
		return
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.material_overlay == _mat and _mat != null:
			mi.material_overlay = null


## Maillage d'un effet (aura attachée au héros) : jamais contouré.
static func _in_fx(n: Node) -> bool:
	var p := n.get_parent()
	while p != null:
		if p is EdenFx:
			return true
		p = p.get_parent()
	return false
