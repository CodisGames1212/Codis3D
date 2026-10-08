extends SceneTree

const Exporter = preload("res://addons/codis3d/mesh_exporter.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var source := MeshInstance3D.new()
	source.name = "Triangle"
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.UP, Vector3.RIGHT])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2(0, 1), Vector2(1, 0)])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	source.mesh = mesh
	root.add_child(source)
	source.position = Vector3(2, 3, 4)
	await process_frame
	for format in Exporter.FORMATS:
		assert(Exporter.export_meshes("user://test_export." + format, [source]) == OK)
	var obj := FileAccess.get_file_as_string("user://test_export.obj")
	assert(obj.contains("v 2.0 3.0 4.0"))
	for line in obj.split("\n"):
		if line.begins_with("vn "):
			var values := line.split(" ")
			assert(Vector3(float(values[1]), float(values[2]), float(values[3])).distance_to(Vector3.BACK) < 0.0001)
	assert(obj.contains("vt 0.0 1.0"))
	assert(obj.contains("f 1/1/1 3/3/3 2/2/2"))
	assert(Exporter.export_meshes("user://test_local.obj", [source], {"apply_transform": false, "normals": false, "uvs": false, "scale": 2.0, "z_up": true}) == OK)
	var local := FileAccess.get_file_as_string("user://test_local.obj")
	assert(local.contains("v 0.0 0.0 0.0"))
	assert(local.contains("f 1 3 2"))
	assert(not local.contains("vn ") and not local.contains("vt "))
	var file := FileAccess.open("user://test_export.stl", FileAccess.READ)
	assert(file.get_length() == 134)
	file.seek(80)
	assert(file.get_32() == 1)
	assert(is_zero_approx(file.get_float()))
	assert(is_zero_approx(file.get_float()))
	assert(is_equal_approx(file.get_float(), 1.0))
	file.close()
	assert(Exporter.export_meshes("user://test_ascii.stl", [source], {"binary": false}) == OK)
	assert(FileAccess.get_file_as_string("user://test_ascii.stl").contains("facet normal 0.0 0.0 1.0"))
	var ply := FileAccess.get_file_as_string("user://test_export.ply")
	assert(ply.contains("element vertex 3") and ply.contains("element face 1"))
	assert(ply.ends_with("3 0 1 2\n"))
	for extension in ["glb", "gltf"]:
		var state := GLTFState.new()
		var document := GLTFDocument.new()
		assert(document.append_from_file("user://test_export." + extension, state) == OK)
		var imported := document.generate_scene(state)
		root.add_child(imported)
		var imported_mesh := _find_mesh(imported)
		assert(imported_mesh != null)
		assert(imported_mesh.mesh.get_faces().size() == 3)
		assert(imported_mesh.mesh.get_aabb().position.is_equal_approx(Vector3(2, 3, 4)))
		imported.free()
	# Multiple surfaces/objects must maintain separate OBJ attribute offsets.
	assert(Exporter.export_meshes("user://test_multi.obj", [source, source]) == OK)
	assert(FileAccess.get_file_as_string("user://test_multi.obj").contains("f 4/4/4 6/6/6 5/5/5"))
	assert(Exporter.export_meshes("user://empty.obj", []) == ERR_INVALID_PARAMETER)
	assert(Exporter.export_meshes("user://bad.fbx", [source]) == ERR_FILE_UNRECOGNIZED)
	assert(Exporter.export_meshes("user://bad.obj", [source], {"scale": 0}) == ERR_INVALID_PARAMETER)
	assert(Exporter.export_meshes("user://missing_export_folder/test.obj", [source]) != OK)
	assert(source.position == Vector3(2, 3, 4))
	assert(source.mesh == mesh)
	var dialog := preload("res://addons/codis3d/export_dialog.gd").new()
	root.add_child(dialog)
	dialog.open([source], [source])
	dialog.format.select(3)
	dialog._format_changed(3)
	assert(dialog.destination.text.ends_with(".glb"))
	assert(dialog.axis.disabled and not dialog.normals.visible)
	dialog.format.select(1)
	dialog._format_changed(1)
	assert(dialog.binary.visible and not dialog.axis.disabled)
	dialog.free()
	source.free()
	print("Export checks passed")
	quit()

func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D: return node
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null: return found
	return null
