extends SceneTree
## godot --headless --path game --script tools/inspect_scene.gd -- res://chemin.glb
## Affiche l'arborescence d'une scène importée (types, collisions, matériaux).

func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var root: Node = (load(path) as PackedScene).instantiate()
	var counts := {}
	_walk(root, 0, counts)
	print(counts)
	quit()


func _walk(n: Node, depth: int, counts: Dictionary) -> void:
	counts[n.get_class()] = counts.get(n.get_class(), 0) + 1
	if depth < 3 or n is CollisionShape3D or n is StaticBody3D:
		var extra := ""
		if n is MeshInstance3D:
			var m := (n as MeshInstance3D).mesh
			extra = " surfaces=%d mat0=%s" % [m.get_surface_count(), m.surface_get_material(0)]
		if depth < 6:
			print("  ".repeat(depth), n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children():
		_walk(c, depth + 1, counts)
