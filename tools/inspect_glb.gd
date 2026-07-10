extends SceneTree
## Engångsverktyg: skriv ut mesh-ytor och material för en GLB.
## Kör: godot --headless -s res://tools/inspect_glb.gd -- res://assets/models3d/middle_aged_man.glb

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path := args[0] if args.size() > 0 else "res://assets/models3d/middle_aged_man.glb"
	var scene: PackedScene = load(path)
	var root := scene.instantiate()
	_dump(root, 0)
	root.free()
	quit()

func _dump(n: Node, depth: int) -> void:
	var ind := "  ".repeat(depth)
	var info := "%s%s (%s)" % [ind, n.name, n.get_class()]
	if n is MeshInstance3D and n.mesh != null:
		info += " — %d ytor" % n.mesh.get_surface_count()
		for i in n.mesh.get_surface_count():
			var mat: Material = n.mesh.surface_get_material(i)
			var mname: String = mat.resource_name if mat != null else "<null>"
			var tex := ""
			if mat is BaseMaterial3D and mat.albedo_texture != null:
				tex = " tex=" + mat.albedo_texture.resource_path.get_file()
			info += "\n%s  yta %d: %s (%s)%s" % [ind, i, mname,
				mat.get_class() if mat != null else "-", tex]
	print(info)
	for c in n.get_children():
		_dump(c, depth + 1)
