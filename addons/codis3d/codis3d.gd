@tool
extends EditorPlugin

var export_dialog: ConfirmationDialog


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	add_tool_menu_item("Open Codis3D workspace", _open_workspace)
	add_tool_menu_item("Codis3D: Export scene meshes", _export_scene)


func _exit_tree() -> void:
	remove_tool_menu_item("Open Codis3D workspace")
	remove_tool_menu_item("Codis3D: Export scene meshes")
	if is_instance_valid(export_dialog): export_dialog.queue_free()

func _open_workspace() -> void:
	EditorInterface.open_scene_from_path("res://Codis3D/scenes/workspace.tscn")

func _collect(node: Node, meshes: Array) -> void:
	if node is MeshInstance3D and node.mesh != null: meshes.append(node)
	for child in node.get_children(): _collect(child, meshes)

func _export_scene() -> void:
	if not is_instance_valid(export_dialog):
		export_dialog = preload("res://addons/codis3d/export_dialog.gd").new()
		EditorInterface.get_base_control().add_child(export_dialog)
	var meshes := []
	var selection := []
	var root := EditorInterface.get_edited_scene_root()
	if root: _collect(root, meshes)
	for node in EditorInterface.get_selection().get_selected_nodes():
		var descendants := []
		_collect(node, descendants)
		for mesh in descendants:
			if not mesh in selection: selection.append(mesh)
	export_dialog.open(meshes, selection)
