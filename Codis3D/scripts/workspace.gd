extends Control

var world: Node3D
var camera: Camera3D
var viewport: SubViewport
var objects: Array[MeshInstance3D] = []
var selected: MeshInstance3D
var history: Array = []
var future: Array = []
var yaw := 0.7
var pitch := 0.4
var distance := 9.0
var target := Vector3.ZERO
var tool := "select"
var touches := {}
var status: Label
var object_list: ItemList
var frame: HSlider
var tracks := {}
var playing := false
var play_time := 0.0
var serial := 0
const WORKSPACES = ["modeling", "sculpting", "animation", "rendering"]
var active_workspace := ""
var workspace_views := {}
var workspace_buttons := {}
var tool_buttons := {}
var modeling_actions: HFlowContainer
var timeline: HBoxContainer
var sculpt_panel: HFlowContainer
var render_panel: HFlowContainer
var workspace_label: Label
var brush_radius := 70.0
var brush_strength := 1.0
var scene_light: DirectionalLight3D
var grid_node: MeshInstance3D
var layout_path := "user://workspace_layout.cfg"
const SAVE_PATH = "user://workspace.codis.json"

func _ready() -> void:
	_build_ui()
	_build_world()
	_add("cube")
	history.clear()
	_update_camera()
	_load_layout()
	_switch_workspace("modeling")
	get_viewport().size_changed.connect(_responsive)
	_responsive()

func _button(parent: Node, glyph: String, hint: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = glyph
	b.tooltip_text = hint
	b.custom_minimum_size = Vector2(48, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("171c26")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(layout)
	var workspace_bar := HFlowContainer.new()
	layout.add_child(workspace_bar)
	for entry in [["▣", "modeling"], ["✎", "sculpting"], ["▶", "animation"], ["▧", "rendering"]]:
		var button := _button(workspace_bar, entry[0], entry[1].capitalize() + " workspace", _switch_workspace.bind(entry[1]))
		button.toggle_mode = true
		workspace_buttons[entry[1]] = button
	workspace_label = Label.new()
	workspace_bar.add_child(workspace_label)
	var top := HFlowContainer.new()
	layout.add_child(top)
	modeling_actions = HFlowContainer.new()
	top.add_child(modeling_actions)
	for entry in [["▣", "cube"], ["●", "sphere"], ["◉", "cylinder"], ["▱", "plane"]]:
		_button(modeling_actions, entry[0], "Add " + entry[1], _add.bind(entry[1]))
	_button(modeling_actions, "⧉", "Duplicate", _duplicate)
	_button(modeling_actions, "×", "Delete", _delete)
	_button(top, "↶", "Undo", _undo)
	_button(top, "↷", "Redo", _redo)
	_button(top, "↓", "Save workspace", _save)
	_button(top, "↑", "Load workspace", _load)
	_button(top, "⇧", "Export mesh: OBJ, STL, PLY, GLB, glTF", _open_export)
	_button(top, "▧", "Render PNG", _render_image)
	sculpt_panel = HFlowContainer.new()
	layout.add_child(sculpt_panel)
	_setting(sculpt_panel, "Brush radius", 10, 200, brush_radius, func(v: float): brush_radius = v)
	_setting(sculpt_panel, "Strength", 0.1, 5, brush_strength, func(v: float): brush_strength = v)
	render_panel = HFlowContainer.new()
	layout.add_child(render_panel)
	_setting(render_panel, "Light", 0, 5, 1.3, func(v: float):
		if scene_light: scene_light.light_energy = v)
	_setting(render_panel, "Lens FOV", 15, 100, 75, func(v: float):
		if camera: camera.fov = v)
	var grid_toggle := CheckBox.new()
	grid_toggle.text = "Grid"
	grid_toggle.button_pressed = true
	grid_toggle.custom_minimum_size.y = 48
	grid_toggle.toggled.connect(func(value: bool):
		if grid_node: grid_node.visible = value)
	render_panel.add_child(grid_toggle)
	var background := ColorPickerButton.new()
	background.color = Color("252e40")
	background.tooltip_text = "Render background"
	background.custom_minimum_size = Vector2(48, 48)
	background.color_changed.connect(func(color: Color):
		if world:
			for child in world.get_children():
				if child is WorldEnvironment: child.environment.background_color = color)
	render_panel.add_child(background)
	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(middle)
	var toolbar := VBoxContainer.new()
	middle.add_child(toolbar)
	for entry in [["⌖", "select"], ["↔", "move"], ["⟳", "rotate"], ["⤢", "scale"], ["✎", "sculpt"]]:
		var button := _button(toolbar, entry[0], entry[1].capitalize(), _set_tool.bind(entry[1]))
		button.toggle_mode = true
		tool_buttons[entry[1]] = button
	tool_buttons["subdivide"] = _button(toolbar, "⊞", "Subdivide triangles", _subdivide)
	_button(toolbar, "⌂", "Frame selected", _focus)
	var canvas := SubViewportContainer.new()
	canvas.stretch = true
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.gui_input.connect(_input_view)
	middle.add_child(canvas)
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	canvas.add_child(viewport)
	object_list = ItemList.new()
	object_list.custom_minimum_size.x = 160
	object_list.item_selected.connect(func(i: int): _select(objects[i]))
	middle.add_child(object_list)
	timeline = HBoxContainer.new()
	layout.add_child(timeline)
	_button(timeline, "▶", "Play / pause", func(): playing = not playing)
	_button(timeline, "◆", "Insert transform keyframe", _keyframe)
	frame = HSlider.new()
	frame.min_value = 1
	frame.max_value = 240
	frame.step = 1
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.value_changed.connect(_evaluate)
	timeline.add_child(frame)
	status = Label.new()
	status.text = "Drag to orbit · wheel/pinch to zoom · right drag to pan"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status)

func _responsive() -> void:
	object_list.visible = size.x >= 760 and active_workspace != "rendering"

func _setting(parent: Node, label: String, minimum: float, maximum: float, value: float, callback: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title := Label.new()
	title.text = label
	row.add_child(title)
	var input := SpinBox.new()
	input.min_value = minimum
	input.max_value = maximum
	input.step = 0.1
	input.value = value
	input.custom_minimum_size = Vector2(100, 48)
	input.value_changed.connect(callback)
	row.add_child(input)

func _capture_view() -> Dictionary:
	return {"yaw": yaw, "pitch": pitch, "distance": distance, "target": target, "tool": tool}

func _switch_workspace(id: String) -> void:
	if id not in WORKSPACES: return
	if active_workspace != "": workspace_views[active_workspace] = _capture_view()
	playing = false
	touches.clear()
	active_workspace = id
	var view: Dictionary = workspace_views.get(id, {})
	yaw = view.get("yaw", yaw)
	pitch = view.get("pitch", pitch)
	distance = view.get("distance", distance)
	target = view.get("target", target)
	modeling_actions.visible = id == "modeling"
	sculpt_panel.visible = id == "sculpting"
	render_panel.visible = id == "rendering"
	timeline.visible = id == "animation"
	for key in workspace_buttons: workspace_buttons[key].set_pressed_no_signal(key == id)
	for key in tool_buttons:
		tool_buttons[key].visible = key in _workspace_tools(id)
	var default_tool := "sculpt" if id == "sculpting" else "select"
	var remembered: String = view.get("tool", default_tool)
	_set_tool(remembered if remembered in _workspace_tools(id) else default_tool)
	workspace_label.text = id.capitalize()
	_select(selected)
	_responsive()
	_update_camera()
	_save_layout()

func _workspace_tools(id: String) -> Array:
	match id:
		"sculpting": return ["select", "sculpt", "subdivide"]
		"rendering": return ["select"]
		_: return ["select", "move", "rotate", "scale", "subdivide"] if id == "modeling" else ["select", "move", "rotate", "scale"]

func _save_layout() -> void:
	if active_workspace == "": return
	workspace_views[active_workspace] = _capture_view()
	var config := ConfigFile.new()
	config.set_value("layout", "views", workspace_views)
	config.save(layout_path)

func _load_layout() -> void:
	var config := ConfigFile.new()
	if config.load(layout_path) == OK:
		var views = config.get_value("layout", "views", {})
		if views is Dictionary: workspace_views = views

func _exit_tree() -> void:
	_save_layout()

func _build_world() -> void:
	world = Node3D.new()
	viewport.add_child(world)
	camera = Camera3D.new()
	camera.current = true
	world.add_child(camera)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.3
	world.add_child(light)
	scene_light = light
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("252e40")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b5c4e0")
	settings.ambient_light_energy = 0.6
	env.environment = settings
	world.add_child(env)
	var grid := MeshInstance3D.new()
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-10, 11):
		lines.surface_add_vertex(Vector3(i, -1.01, -10))
		lines.surface_add_vertex(Vector3(i, -1.01, 10))
		lines.surface_add_vertex(Vector3(-10, -1.01, i))
		lines.surface_add_vertex(Vector3(10, -1.01, i))
	lines.surface_end()
	grid.mesh = lines
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("455168")
	grid.material_override = material
	world.add_child(grid)
	grid_node = grid

func _update_camera() -> void:
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)

func _set_tool(value: String) -> void:
	tool = value
	for key in tool_buttons:
		if key != "subdivide": tool_buttons[key].set_pressed_no_signal(key == value)
	status.text = value.capitalize() + " · drag selected object · two fingers orbit/pinch"

func _add(kind: String) -> void:
	_checkpoint()
	var mesh: PrimitiveMesh
	match kind:
		"sphere": mesh = SphereMesh.new()
		"cylinder": mesh = CylinderMesh.new()
		"plane": mesh = PlaneMesh.new()
		_: mesh = BoxMesh.new()
	serial += 1
	var editable := ArrayMesh.new()
	editable.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh.get_mesh_arrays())
	_select(_make(editable, kind.capitalize() + str(serial)))

func _make(mesh: ArrayMesh, label: String) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	obj.name = label
	obj.mesh = mesh
	world.add_child(obj)
	objects.append(obj)
	return obj

func _select(obj: MeshInstance3D) -> void:
	selected = obj
	object_list.clear()
	for item in objects:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("e6a45b") if item == selected and active_workspace != "rendering" else Color("a7b5ce")
		item.material_override = mat
		object_list.add_item(item.name)
		if item == selected: object_list.select(object_list.item_count - 1)

func _pick(point: Vector2) -> MeshInstance3D:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var best: MeshInstance3D
	var closest := INF
	for obj in objects:
		var inverse := obj.global_transform.affine_inverse()
		var hit = obj.mesh.get_aabb().intersects_ray(inverse * origin, inverse.basis * direction)
		if hit != null:
			var d: float = origin.distance_to(obj.global_transform * hit)
			if d < closest:
				best = obj
				closest = d
	return best

func _input_view(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(1, distance * 0.9)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(100, distance * 1.1)
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var hit := _pick(event.position)
			if hit: _select(hit)
			if tool != "select": _checkpoint()
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			target += (-camera.global_basis.x * event.relative.x + camera.global_basis.y * event.relative.y) * distance * 0.002
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT: _drag(event.relative, event.position)
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if touches.size() == 1:
				var hit := _pick(event.position)
				if hit: _select(hit)
				if tool != "select": _checkpoint()
		else: touches.erase(event.index)
	if event is InputEventScreenDrag:
		if touches.size() >= 2:
			var ids := touches.keys()
			var other: Vector2 = touches[ids[1] if ids[0] == event.index else ids[0]]
			var before: float = (touches[event.index] as Vector2).distance_to(other)
			var after: float = event.position.distance_to(other)
			if after > 1: distance = clampf(distance * before / after, 1, 100)
			yaw -= event.relative.x * 0.004
			pitch = clampf(pitch + event.relative.y * 0.004, -1.4, 1.4)
		else: _drag(event.relative, event.position)
		touches[event.index] = event.position
	_update_camera()

func _drag(delta: Vector2, point: Vector2) -> void:
	if tool == "select" or selected == null:
		yaw -= delta.x * 0.008
		pitch = clampf(pitch + delta.y * 0.008, -1.4, 1.4)
		return
	match tool:
		"move":
			var right := camera.global_basis.x
			selected.position += (right * delta.x + Vector3(right.z, 0, -right.x) * delta.y) * distance * 0.002
		"rotate": selected.rotate_y(delta.x * 0.01)
		"scale": selected.scale = (selected.scale * exp(delta.x * 0.008)).clamp(Vector3.ONE * 0.01, Vector3.ONE * 100)
		"sculpt":
			var arrays := selected.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for i in vertices.size():
				var pos := selected.global_transform * vertices[i]
				if camera.is_position_behind(pos): continue
				var d := camera.unproject_position(pos).distance_to(point)
				if d < brush_radius: vertices[i] += vertices[i].normalized() * -delta.y * 0.006 * brush_strength * (1 - d / brush_radius)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			_rebuild(arrays)

func _rebuild(arrays: Array) -> void:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(mesh, 0)
	surface.generate_normals()
	selected.mesh = surface.commit()

func _subdivide() -> void:
	if selected == null: return
	var faces := selected.mesh.get_faces()
	if faces.size() > 150000:
		status.text = "Mobile subdivision limit reached"
		return
	_checkpoint()
	var vertices := PackedVector3Array()
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		var ab := (a + b) / 2
		var bc := (b + c) / 2
		var ca := (c + a) / 2
		vertices.append_array(PackedVector3Array([a, ab, ca, ab, b, bc, ca, bc, c, ab, bc, ca]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	_rebuild(arrays)
	status.text = "Subdivided to %d triangles" % (vertices.size() / 3)

func _duplicate() -> void:
	if selected == null: return
	_checkpoint()
	serial += 1
	var obj := _make(selected.mesh.duplicate(), "Object" + str(serial))
	obj.transform = selected.transform
	obj.position.x += 1.5
	_select(obj)

func _delete() -> void:
	if selected == null: return
	_checkpoint()
	tracks.erase(str(selected.name))
	objects.erase(selected)
	selected.free()
	_select(null)

func _focus() -> void:
	if selected: target = selected.position
	_update_camera()

func _vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _unvec(v: Array) -> Vector3:
	return Vector3(v[0], v[1], v[2])

func _snapshot() -> Dictionary:
	var data := {"version": 1, "objects": [], "tracks": tracks.duplicate(true), "serial": serial}
	for obj in objects:
		var vertices := []
		for v in obj.mesh.get_faces(): vertices.append(_vec(v))
		data.objects.append({"name": str(obj.name), "position": _vec(obj.position), "rotation": _vec(obj.rotation), "scale": _vec(obj.scale), "vertices": vertices})
	return data

func _restore(data: Dictionary) -> void:
	playing = false
	selected = null
	for obj in objects: obj.free()
	objects.clear()
	tracks = data.get("tracks", {}).duplicate(true)
	serial = int(data.get("serial", 0))
	for entry in data.objects:
		var vertices := PackedVector3Array()
		for v in entry.vertices: vertices.append(_unvec(v))
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var obj := _make(mesh, entry.name)
		_select(obj)
		_rebuild(arrays)
		obj.position = _unvec(entry.position)
		obj.rotation = _unvec(entry.rotation)
		obj.scale = _unvec(entry.scale)
	_select(selected)

func _checkpoint() -> void:
	history.append(_snapshot())
	if history.size() > 24: history.pop_front()
	future.clear()

func _undo() -> void:
	if history.is_empty(): return
	future.append(_snapshot())
	_restore(history.pop_back())

func _redo() -> void:
	if future.is_empty(): return
	history.append(_snapshot())
	_restore(future.pop_back())

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		status.text = "Save failed"
		return
	file.store_string(JSON.stringify(_snapshot()))
	status.text = "Saved " + ProjectSettings.globalize_path(SAVE_PATH)

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		status.text = "No saved workspace"
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not _valid_workspace(data):
		status.text = "Invalid workspace"
		return
	_checkpoint()
	_restore(data)
	status.text = "Workspace loaded"

func _valid_workspace(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1 or not data.get("objects") is Array:
		return false
	if not data.get("tracks", {}) is Dictionary: return false
	for entry in data.objects:
		if not entry is Dictionary or not entry.get("name") is String: return false
		for field in ["position", "rotation", "scale"]:
			if not _valid_vector(entry.get(field)): return false
		if not entry.get("vertices") is Array: return false
		if entry.vertices.is_empty() or entry.vertices.size() % 3 != 0: return false
		for vertex in entry.vertices:
			if not _valid_vector(vertex): return false
	for id in data.get("tracks", {}):
		var keys = data.tracks[id]
		if not keys is Dictionary: return false
		for key in keys:
			if not str(key).is_valid_int() or not keys[key] is Dictionary: return false
			for field in ["position", "rotation", "scale"]:
				if not _valid_vector(keys[key].get(field)): return false
	return true

func _valid_vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	for number in value:
		if not (number is float or number is int) or not is_finite(float(number)): return false
	return true

func _keyframe() -> void:
	if selected == null: return
	_checkpoint()
	var id := str(selected.name)
	if not tracks.has(id): tracks[id] = {}
	tracks[id][str(int(frame.value))] = {"position": _vec(selected.position), "rotation": _vec(selected.rotation), "scale": _vec(selected.scale)}
	status.text = "Keyframe %d · %s" % [frame.value, id]

func _evaluate(value: float) -> void:
	for obj in objects:
		var keys: Dictionary = tracks.get(str(obj.name), {})
		if keys.is_empty(): continue
		var times: Array[int] = []
		for key in keys: times.append(int(key))
		times.sort()
		var lo := times[0]
		var hi := times[-1]
		for time in times:
			if time <= value: lo = time
			if time >= value:
				hi = time
				break
		var blend := clampf((value - lo) / maxf(1, hi - lo), 0, 1)
		var a: Dictionary = keys[str(lo)]
		var b: Dictionary = keys[str(hi)]
		obj.position = _unvec(a.position).lerp(_unvec(b.position), blend)
		obj.scale = _unvec(a.scale).lerp(_unvec(b.scale), blend)
		obj.quaternion = Quaternion.from_euler(_unvec(a.rotation)).slerp(Quaternion.from_euler(_unvec(b.rotation)), blend)

func _process(delta: float) -> void:
	if playing:
		play_time += delta * 24
		frame.value = 1 + fmod(play_time, 239)

func _export_obj() -> void:
	var result := preload("res://addons/codis3d/mesh_exporter.gd").export_meshes("user://workspace.obj", objects, {"normals": false, "uvs": false})
	status.text = "Exported workspace.obj" if result == OK else error_string(result)

func _open_export() -> void:
	var dialog := preload("res://addons/codis3d/export_dialog.gd").new()
	add_child(dialog)
	dialog.export_finished.connect(func(path: String, result: int):
		status.text = "Exported " + ProjectSettings.globalize_path(path) if result == OK else "Export failed: " + error_string(result))
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	dialog.open(objects, [selected] if selected != null else [])

func _render_image() -> void:
	await RenderingServer.frame_post_draw
	var path := "user://render.png"
	var result := viewport.get_texture().get_image().save_png(path)
	status.text = "Rendered " + ProjectSettings.globalize_path(path) if result == OK else error_string(result)
