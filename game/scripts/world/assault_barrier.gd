class_name AssaultBarrier
extends Node3D
## Barrière d'encre d'un départ de L'Assaut pendant l'achat (lot TAC-7, TACTIQUE § 7.2 : « barrières d'encre (couleur du camp)
## jusqu'à la fin ») : quatre parois basses translucides de la couleur de l'équipe, bord d'encre en haut, autour du rectangle du
## départ. Rien de physique : le directeur garde déjà le joueur dans son départ (AssaultDirector._hold_in_spawn) ; la barrière
## le montre. Posée et retirée par AssaultDirector._show_barriers.

const HEIGHT := 1.6
const THICK := 0.12


## Parois autour de [param center] (monde), demi-tailles [param half] (x, z), couleur [param col] ; [param map] : sol (floor_at).
func build(center: Vector3, half: Vector2, col: Color, map: Node) -> void:
	name = "AssaultBarrier"
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(col, 0.28)
	var ink := StandardMaterial3D.new()
	ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ink.albedo_color = UiTheme.color("encre.700", Color("221a3a"))
	var y := center.y
	if map != null and map.has_method("height_at"):
		y = float(map.call("height_at", center.x, center.z))
	var sides := [
		[Vector3(center.x, y, center.z - half.y), Vector2(half.x * 2.0, THICK)],
		[Vector3(center.x, y, center.z + half.y), Vector2(half.x * 2.0, THICK)],
		[Vector3(center.x - half.x, y, center.z), Vector2(THICK, half.y * 2.0)],
		[Vector3(center.x + half.x, y, center.z), Vector2(THICK, half.y * 2.0)],
	]
	for s in sides:
		var wall := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3((s[1] as Vector2).x, HEIGHT, (s[1] as Vector2).y)
		wall.mesh = bm
		wall.material_override = mat
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wall)
		wall.global_position = (s[0] as Vector3) + Vector3.UP * HEIGHT * 0.5
		var rim := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3((s[1] as Vector2).x + 0.08, 0.12, (s[1] as Vector2).y + 0.08)
		rim.mesh = rm
		rim.material_override = ink
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rim)
		rim.global_position = (s[0] as Vector3) + Vector3.UP * HEIGHT
