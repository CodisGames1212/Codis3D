extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene = load("res://Codis3D/scenes/workspace.tscn").instantiate()
	scene.layout_path = "user://test_workspace_layout.cfg"
	root.add_child(scene)
	await process_frame
	assert(scene.objects.size() == 1)
	scene.workspace_views.clear()
	scene._switch_workspace("modeling")
	var original = scene.selected
	var original_history = scene.history.size()
	assert(scene.modeling_actions.visible and not scene.timeline.visible)
	scene.yaw = 1.25
	scene._set_tool("move")
	scene._switch_workspace("sculpting")
	assert(scene.tool == "sculpt" and scene.sculpt_panel.visible)
	assert(not scene.modeling_actions.visible and not scene.render_panel.visible)
	assert(not scene.tool_buttons["move"].visible)
	scene.yaw = -0.5
	scene._switch_workspace("rendering")
	assert(scene.render_panel.visible and not scene.object_list.visible)
	assert(scene.tool == "select" and not scene.timeline.visible)
	assert(scene.selected.material_override.albedo_color == Color("a7b5ce"))
	var light_input = scene.render_panel.get_child(0).get_child(1)
	light_input.value = 2.5
	assert(is_equal_approx(scene.scene_light.light_energy, 2.5))
	scene._switch_workspace("animation")
	assert(scene.timeline.visible and not scene.render_panel.visible)
	scene.playing = true
	scene._switch_workspace("modeling")
	assert(not scene.playing)
	assert(is_equal_approx(scene.yaw, 1.25) and scene.tool == "move")
	assert(scene.selected == original and scene.objects.size() == 1)
	assert(scene.history.size() == original_history)
	scene._switch_workspace("sculpting")
	assert(is_equal_approx(scene.yaw, -0.5))
	scene.workspace_views.clear()
	scene._load_layout()
	assert(scene.workspace_views.has("sculpting"))
	scene._switch_workspace("modeling")
	scene._subdivide()
	assert(scene.selected.mesh.get_faces().size() == 144)
	scene._duplicate()
	assert(scene.objects.size() == 2)
	scene._undo()
	assert(scene.objects.size() == 1)
	scene._redo()
	assert(scene.objects.size() == 2)
	scene.frame.value = 1
	scene.selected.position = Vector3.ZERO
	scene._keyframe()
	scene.frame.value = 25
	scene.selected.position = Vector3(4, 0, 0)
	scene._keyframe()
	scene._evaluate(13)
	assert(scene.selected.position.is_equal_approx(Vector3(2, 0, 0)))
	var data = JSON.parse_string(JSON.stringify(scene._snapshot()))
	assert(scene._valid_workspace(data))
	assert(not scene._valid_workspace({"version": 1, "objects": [{"name": "Broken"}]}))
	scene._restore(data)
	assert(scene.objects.size() == 2)
	scene._evaluate(13)
	assert(scene.selected.position.is_equal_approx(Vector3(2, 0, 0)))
	scene._delete()
	assert(scene.objects.size() == 1)
	scene._undo()
	assert(scene.objects.size() == 2)
	scene._export_obj()
	assert(FileAccess.get_file_as_string("user://workspace.obj").contains("f 1 3 2"))
	print("Workspace checks passed")
	quit()
