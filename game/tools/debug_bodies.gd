extends SceneTree

func _init() -> void:
	await process_frame
	var map := MapLoader.new()
	root.add_child(map)
	map.load_map(OS.get_cmdline_user_args()[0])
	await physics_frame
	for body: StaticBody3D in map.find_children("*", "StaticBody3D", true, false):
		for col: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
			var s := col.shape
			var info := s.get_class()
			if s is ConcavePolygonShape3D:
				var f: PackedVector3Array = (s as ConcavePolygonShape3D).get_faces()
				var mn := Vector3.INF
				var mx := -Vector3.INF
				for v in f:
					var w := col.global_transform * v
					mn = mn.min(w)
					mx = mx.max(w)
				info += " faces=%d backface=%s y=[%.1f, %.1f]" % [f.size() / 3, (s as ConcavePolygonShape3D).backface_collision, mn.y, mx.y]
			print(body.name, " layer=", body.collision_layer, " ", info, " scale=", col.global_transform.basis.get_scale())
	quit()
