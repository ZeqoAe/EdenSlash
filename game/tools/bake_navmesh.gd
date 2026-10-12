extends SceneTree
## Calcule et enregistre le maillage de navigation d'une map :
##   godot --headless --path game --script tools/bake_navmesh.gd -- s002

func _init() -> void:
	await process_frame
	var id: String = OS.get_cmdline_user_args()[0]
	var map := MapLoader.new()
	root.add_child(map)
	map.load_map(id)
	await physics_frame
	var t0 := Time.get_ticks_msec()
	var nav := MapLoader.make_navmesh_settings()
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav, src, map)
	print("géométrie lue en ", Time.get_ticks_msec() - t0, " ms")
	NavigationServer3D.bake_from_source_geometry_data(nav, src)
	print("navmesh : %d polygones en %d ms" % [nav.get_polygon_count(), Time.get_ticks_msec() - t0])
	var path := "res://assets/maps/%s/navmesh.res" % id
	ResourceSaver.save(nav, path)
	print("enregistré : ", path)
	quit()
