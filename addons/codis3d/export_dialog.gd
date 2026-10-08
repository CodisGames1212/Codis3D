@tool
extends ConfirmationDialog

const Exporter = preload("res://addons/codis3d/mesh_exporter.gd")
signal export_finished(path: String, result: int)
var sources: Array = []
var selection: Array = []
var format: OptionButton
var selected_only: CheckBox
var apply_transform: CheckBox
var axis: OptionButton
var scale: SpinBox
var normals: CheckBox
var uvs: CheckBox
var binary: CheckBox
var destination: LineEdit
var browser: FileDialog
var message: Label

func _ready() -> void:
	title = "Export mesh"
	ok_button_text = "Export"
	dialog_hide_on_ok = false
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(layout)
	format = OptionButton.new()
	for label in ["Wavefront OBJ (.obj)", "STL (.stl)", "Stanford PLY (.ply)", "glTF Binary (.glb)", "glTF Separate (.gltf)"]: format.add_item(label)
	format.custom_minimum_size.y = 48
	layout.add_child(format)
	selected_only = _check(layout, "Selected objects only", false)
	apply_transform = _check(layout, "Apply world transforms", true)
	axis = OptionButton.new()
	axis.add_item("Y up (Godot / glTF)")
	axis.add_item("Z up (Blender / printing)")
	layout.add_child(axis)
	var row := HBoxContainer.new()
	layout.add_child(row)
	var label := Label.new()
	label.text = "Scale"
	row.add_child(label)
	scale = SpinBox.new()
	scale.min_value = 0.001
	scale.max_value = 1000
	scale.step = 0.001
	scale.value = 1
	row.add_child(scale)
	normals = _check(layout, "OBJ: export normals", true)
	uvs = _check(layout, "OBJ: export UVs when present", true)
	binary = _check(layout, "STL: binary (off = ASCII)", true)
	var path_row := HBoxContainer.new()
	layout.add_child(path_row)
	destination = LineEdit.new()
	destination.text = "user://workspace.obj"
	destination.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destination.custom_minimum_size.y = 48
	path_row.add_child(destination)
	var browse := Button.new()
	browse.text = "…"
	browse.tooltip_text = "Choose destination"
	browse.custom_minimum_size = Vector2(48, 48)
	path_row.add_child(browse)
	browser = FileDialog.new()
	browser.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	browser.access = FileDialog.ACCESS_FILESYSTEM
	add_child(browser)
	browse.pressed.connect(func():
		browser.filters = PackedStringArray(["*." + Exporter.FORMATS[format.selected] + " ; Mesh export"])
		browser.current_path = ProjectSettings.globalize_path(destination.text)
		browser.popup_centered_ratio(0.85))
	browser.file_selected.connect(func(path: String): destination.text = path)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(message)
	format.item_selected.connect(_format_changed)
	confirmed.connect(_export)
	_format_changed(0)

func _check(parent: Node, label: String, enabled: bool) -> CheckBox:
	var check := CheckBox.new()
	check.text = label
	check.button_pressed = enabled
	check.custom_minimum_size.y = 40
	parent.add_child(check)
	return check

func open(meshes: Array, selected_meshes: Array) -> void:
	sources = meshes
	selection = selected_meshes
	message.text = "Exports mesh geometry at the current pose. glTF keeps surface materials; OBJ/STL/PLY export geometry."
	popup_centered(Vector2i(mini(520, get_viewport().get_visible_rect().size.x - 16), mini(620, get_viewport().get_visible_rect().size.y - 16)))

func _format_changed(index: int) -> void:
	destination.text = destination.text.get_basename() + "." + Exporter.FORMATS[index]
	normals.visible = index == 0
	uvs.visible = index == 0
	binary.visible = index == 1
	# glTF has a standard Y-up convention.
	axis.disabled = index >= 3
	if index >= 3: axis.select(0)

func _export() -> void:
	var meshes := selection if selected_only.button_pressed else sources
	if meshes.is_empty():
		message.text = "No mesh objects to export. Select an object or turn off Selected objects only."
		return
	var path := destination.text.strip_edges()
	if path.is_empty():
		message.text = "Choose a destination."
		return
	path = path.get_basename() + "." + Exporter.FORMATS[format.selected]
	destination.text = path
	if FileAccess.file_exists(path):
		var overwrite := ConfirmationDialog.new()
		overwrite.dialog_text = "Replace " + path.get_file() + "?"
		add_child(overwrite)
		overwrite.confirmed.connect(func():
			_write(path, meshes)
			overwrite.queue_free())
		overwrite.canceled.connect(overwrite.queue_free)
		overwrite.popup_centered()
	else: _write(path, meshes)

func _write(path: String, meshes: Array) -> void:
	var result := Exporter.export_meshes(path, meshes, {"scale": scale.value, "apply_transform": apply_transform.button_pressed, "z_up": axis.selected == 1, "normals": normals.button_pressed, "uvs": uvs.button_pressed, "binary": binary.button_pressed})
	export_finished.emit(path, result)
	if result == OK: hide()
	else: message.text = "Export failed: " + error_string(result)
