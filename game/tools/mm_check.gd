extends Node3D
## Vérification : chaque modèle d'objet cassable rendu en MultiMesh (comme en jeu), côte à côte.
## godot --path game res://tools/mm_check.tscn  -> user://shots/mm_check.png

func _ready() -> void:
	var we := WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.35, 0.4, 0.45)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	add_child(sun)
	var models: Array = []
	for k in Breakables.KINDS:
		models.append_array(Breakables.KINDS[k].models)
	for i in models.size():
		for entry in ProcMap.model_meshes(String(models[i])):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = entry[0]
			mm.instance_count = 1
			mm.set_instance_transform(0, Transform3D(Basis(), Vector3((i % 7) * 3.0, 0, (i / 7) * 3.5)) * entry[1])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			add_child(mmi)
		print(i, " ", models[i])
	var cam := Camera3D.new()
	add_child(cam)
	cam.make_current()
	cam.position = Vector3(9, 11, 9)
	cam.look_at(Vector3(9, 0, 2.5))
	for f in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://shots/mm_check.png")
	get_tree().quit()
