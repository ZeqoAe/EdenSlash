extends SceneTree
## Diagnostic : charge la map d'un donjon et teste le sol sous un point clé.

func _init() -> void:
	await process_frame
	var map := MapLoader.new()
	root.add_child(map)
	map.load_map(OS.get_cmdline_user_args()[0])
	await physics_frame
	await physics_frame
	print("bounds ", map.bounds)
	var box := EdenModel.bounds(map)
	print("aabb meshes ", box)
	for e in map.info.events:
		var p := map.event_pos(e)
		var space := map.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 5, p + Vector3.DOWN * 30)
		var hit := space.intersect_ray(q)
		print(e.type, " ", p, " -> ", hit.get("position", "rien"), " ", hit.get("collider", null))
	# maillages sous le point d'arrivée
	var p0 := map.event_pos(map.info.events[0])
	var n := 0
	for mi: MeshInstance3D in map.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		if b.grow(0.5).has_point(Vector3(p0.x, b.get_center().y, p0.z)) and b.position.y < p0.y:
			n += 1
			if n < 8:
				print("  sous le point : ", mi.name, " ", b)
	print("maillages sous le point : ", n)
	quit()
