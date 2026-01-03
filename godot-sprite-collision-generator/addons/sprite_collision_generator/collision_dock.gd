@tool
extends Control

var collision_generator: Node
var selected_sprite: Sprite2D
var editor_selection: EditorSelection
var undo_redo: EditorUndoRedoManager

var tolerance_slider: HSlider
var tolerance_label: Label
var convex_hull_checkbox: CheckBox
var max_points_spinbox: SpinBox
var generate_button: Button
var status_label: Label
var info_label: Label
var preview_checkbox: CheckBox
var min_area_spinbox: SpinBox
var x_offset_slider: HSlider
var x_offset_spinbox: SpinBox
var reset_x_button: Button
var y_offset_slider: HSlider
var y_offset_spinbox: SpinBox
var reset_y_button: Button
var expansion_slider: HSlider
var expansion_spinbox: SpinBox
var reset_expansion_button: Button
var target_node_button: Button
var target_node_label: Label
var target_node: Node = null

func _ready():
	if not Engine.is_editor_hint():
		return

	# Get UI elements
	tolerance_slider = $VBoxContainer/ToleranceControl/HBoxContainer/ToleranceSlider
	tolerance_label = $VBoxContainer/ToleranceControl/HBoxContainer/ToleranceValue
	convex_hull_checkbox = $VBoxContainer/ToleranceControl/ConvexHullCheckBox
	max_points_spinbox = $VBoxContainer/MaxPointsControl/MaxPointsSpinBox
	generate_button = $VBoxContainer/GenerateButton
	status_label = $VBoxContainer/StatusLabel
	info_label = $VBoxContainer/InfoLabel
	preview_checkbox = $VBoxContainer/PreviewCheckBox
	min_area_spinbox = $VBoxContainer/MinAreaControl/MinAreaSpinBox
	x_offset_slider = $VBoxContainer/XOffsetControl/HBoxContainer/XOffsetSlider
	x_offset_spinbox = $VBoxContainer/XOffsetControl/HBoxContainer/XOffsetSpinBox
	reset_x_button = $VBoxContainer/XOffsetControl/HBoxContainer/ResetXButton
	y_offset_slider = $VBoxContainer/YOffsetControl/HBoxContainer/YOffsetSlider
	y_offset_spinbox = $VBoxContainer/YOffsetControl/HBoxContainer/YOffsetSpinBox
	reset_y_button = $VBoxContainer/YOffsetControl/HBoxContainer/ResetYButton
	expansion_slider = $VBoxContainer/ExpansionControl/HBoxContainer/ExpansionSlider
	expansion_spinbox = $VBoxContainer/ExpansionControl/HBoxContainer/ExpansionSpinBox
	reset_expansion_button = $VBoxContainer/ExpansionControl/HBoxContainer/ResetExpansionButton
	target_node_button = $VBoxContainer/TargetNodeControl/HBoxContainer/PickNodeButton
	target_node_label = $VBoxContainer/TargetNodeControl/TargetNodeLabel

	_setup_ui()

	# Get editor selection and undo/redo
	editor_selection = EditorInterface.get_selection()
	if editor_selection:
		editor_selection.selection_changed.connect(_on_selection_changed)
		_on_selection_changed()

	undo_redo = EditorInterface.get_editor_undo_redo()

func _setup_ui():
	if tolerance_slider:
		tolerance_slider.value_changed.connect(_on_tolerance_changed)
	if convex_hull_checkbox:
		convex_hull_checkbox.toggled.connect(_on_convex_hull_toggled)
	if generate_button:
		generate_button.pressed.connect(_on_generate_pressed)
	if preview_checkbox:
		preview_checkbox.toggled.connect(_on_preview_toggled)
	if target_node_button:
		target_node_button.pressed.connect(_on_pick_node_pressed)
	if x_offset_slider:
		x_offset_slider.value_changed.connect(_on_x_offset_slider_changed)
	if x_offset_spinbox:
		x_offset_spinbox.value_changed.connect(_on_x_offset_spinbox_changed)
	if reset_x_button:
		reset_x_button.pressed.connect(_on_reset_x_pressed)
	if y_offset_slider:
		y_offset_slider.value_changed.connect(_on_y_offset_slider_changed)
	if y_offset_spinbox:
		y_offset_spinbox.value_changed.connect(_on_y_offset_spinbox_changed)
	if reset_y_button:
		reset_y_button.pressed.connect(_on_reset_y_pressed)
	if expansion_slider:
		expansion_slider.value_changed.connect(_on_expansion_slider_changed)
	if expansion_spinbox:
		expansion_spinbox.value_changed.connect(_on_expansion_spinbox_changed)
	if reset_expansion_button:
		reset_expansion_button.pressed.connect(_on_reset_expansion_pressed)

	_update_status("Select a Sprite2D node to begin")
	if tolerance_slider:
		_on_tolerance_changed(tolerance_slider.value)
	if x_offset_slider and x_offset_spinbox:
		x_offset_spinbox.value = x_offset_slider.value
	if y_offset_slider and y_offset_spinbox:
		y_offset_spinbox.value = y_offset_slider.value
	if expansion_slider and expansion_spinbox:
		expansion_spinbox.value = expansion_slider.value

	_update_target_node_label()

func _on_selection_changed():
	var selected_nodes = editor_selection.get_selected_nodes()

	selected_sprite = null
	for node in selected_nodes:
		if node is Sprite2D:
			selected_sprite = node
			break

	if selected_sprite:
		_update_status("Ready to generate collision for: %s" % selected_sprite.name)
		generate_button.disabled = false
	else:
		_update_status("Select a Sprite2D node to begin")
		generate_button.disabled = true

func _on_tolerance_changed(value: float):
	tolerance_label.text = str(int(value))

	if preview_checkbox.button_pressed and selected_sprite:
		_generate_collision(true)

func _on_x_offset_slider_changed(value: float):
	if x_offset_spinbox and x_offset_spinbox.value != value:
		x_offset_spinbox.value = value

	if preview_checkbox.button_pressed and selected_sprite:
		_generate_collision(true)

func _on_x_offset_spinbox_changed(value: float):
	if x_offset_slider and x_offset_slider.value != value:
		x_offset_slider.value = value

	if preview_checkbox.button_pressed and selected_sprite:
		_generate_collision(true)

func _on_y_offset_slider_changed(value: float):
	if y_offset_spinbox and y_offset_spinbox.value != value:
		y_offset_spinbox.value = value

	if preview_checkbox.button_pressed and selected_sprite:
		_generate_collision(true)

func _on_y_offset_spinbox_changed(value: float):
	if y_offset_slider and y_offset_slider.value != value:
		y_offset_slider.value = value

	if preview_checkbox.button_pressed and selected_sprite:
		_generate_collision(true)

func _on_expansion_slider_changed(value: float):
	if expansion_spinbox and expansion_spinbox.value != value:
		expansion_spinbox.value = value

	if preview_checkbox.button_pressed and selected_sprite:
		_generate_collision(true)

func _on_expansion_spinbox_changed(value: float):
	if expansion_slider and expansion_slider.value != value:
		expansion_slider.value = value

	if preview_checkbox.button_pressed and selected_sprite:
		_generate_collision(true)

func _on_convex_hull_toggled(enabled: bool):
	if preview_checkbox.button_pressed and selected_sprite:
		_generate_collision(true)

func _on_reset_x_pressed():
	if x_offset_slider:
		x_offset_slider.value = 0.0

func _on_reset_y_pressed():
	if y_offset_slider:
		y_offset_slider.value = 0.0

func _on_reset_expansion_pressed():
	if expansion_slider:
		expansion_slider.value = 0.0

func _on_preview_toggled(enabled: bool):
	if enabled and selected_sprite:
		_generate_collision(true)

func _on_generate_pressed():
	print("Generate button pressed!")

	if not selected_sprite:
		print("ERROR: No sprite selected")
		_update_status("No Sprite2D selected!", true)
		return

	if not collision_generator:
		print("ERROR: No collision generator")
		_update_status("Collision generator not initialized!", true)
		return

	_generate_collision(false)

func _generate_collision(preview_only: bool = false):
	if not collision_generator:
		print("ERROR: collision_generator is null")
		_update_status("Collision generator not initialized!", true)
		return

	if not selected_sprite:
		print("ERROR: selected_sprite is null")
		return

	print("Starting collision generation for: ", selected_sprite.name)
	print("Tolerance: ", tolerance_slider.value if tolerance_slider else "N/A")
	print("Max points: ", max_points_spinbox.value if max_points_spinbox else "N/A")
	print("Min area: ", min_area_spinbox.value if min_area_spinbox else "N/A")

	_update_status("Generating collision polygons...")
	if generate_button:
		generate_button.disabled = true

	var tolerance = tolerance_slider.value if tolerance_slider else 128.0
	var max_points = int(max_points_spinbox.value) if max_points_spinbox else 500
	var min_area = min_area_spinbox.value if min_area_spinbox else 0.0
	var x_offset = x_offset_spinbox.value if x_offset_spinbox else 0.0
	var y_offset = y_offset_spinbox.value if y_offset_spinbox else 0.0
	var expansion = expansion_spinbox.value if expansion_spinbox else 0.0
	var make_convex = convex_hull_checkbox.button_pressed if convex_hull_checkbox else false

	var polygons = collision_generator.generate_collision_polygon(selected_sprite, tolerance, max_points, min_area, x_offset, y_offset, expansion, make_convex)

	print("Generated ", polygons.size(), " polygons")

	if polygons.size() > 0:
		_apply_collision_polygons(polygons)
	else:
		_update_status("No collision polygons generated", true)

	if generate_button:
		generate_button.disabled = false

func _on_pick_node_pressed():
	if not editor_selection:
		return

	var selected_nodes = editor_selection.get_selected_nodes()

	if selected_nodes.size() > 0:
		# Use the first selected node as target
		target_node = selected_nodes[0]
		_update_target_node_label()
		_update_status("Target node set to: %s" % target_node.name, false)
		print("Target node set to: ", target_node.get_path())
	else:
		# Clear target if nothing selected
		target_node = null
		_update_target_node_label()
		_update_status("Target node cleared (will use sprite)", false)

func _update_target_node_label():
	if target_node_label:
		if target_node:
			target_node_label.text = target_node.name
		else:
			target_node_label.text = "None (use sprite)"

func _apply_collision_polygons(polygons: Array[PackedVector2Array]):
	if not selected_sprite or not undo_redo:
		return

	# Determine target node for collision polygons
	var collision_target: Node = selected_sprite

	if target_node:
		collision_target = target_node
		print("Using custom target node: ", collision_target.get_path())

	# Find existing generated collision polygons to remove
	var old_polygons: Array[Node] = []
	for child in collision_target.get_children():
		if child is CollisionPolygon2D and child.name.begins_with("GeneratedCollision"):
			old_polygons.append(child)
			print("Found existing collision polygon to replace: ", child.name)

	# Create undo/redo action
	undo_redo.create_action("Generate Collision Polygons")

	# Undo: Remove new polygons and restore old ones
	for old_poly in old_polygons:
		var old_index = old_poly.get_index()
		undo_redo.add_undo_method(collision_target, "add_child", old_poly)
		undo_redo.add_undo_method(collision_target, "move_child", old_poly, old_index)
		undo_redo.add_undo_property(old_poly, "owner", old_poly.owner)
		undo_redo.add_undo_reference(old_poly)

	# Do: Remove old polygons
	for old_poly in old_polygons:
		undo_redo.add_do_method(collision_target, "remove_child", old_poly)
		print("Scheduling removal of: ", old_poly.name)

	# Do: Create new collision polygons
	for i in range(polygons.size()):
		var collision_polygon = CollisionPolygon2D.new()
		collision_polygon.name = "GeneratedCollision" + (str(i) if polygons.size() > 1 else "")
		collision_polygon.polygon = polygons[i]
		print("Creating new collision polygon: ", collision_polygon.name, " with ", polygons[i].size(), " points")

		# If target is not the sprite, we need to adjust coordinates
		if collision_target != selected_sprite:
			# Transform polygon coordinates from sprite local space to target local space
			var adjusted_poly = PackedVector2Array()
			for point in polygons[i]:
				# Convert from sprite local to global
				var global_point = selected_sprite.to_global(point)
				# Convert from global to target local
				var target_local_point = collision_target.to_local(global_point)
				adjusted_poly.append(target_local_point)
			collision_polygon.polygon = adjusted_poly

		var scene_root = selected_sprite.get_tree().edited_scene_root

		undo_redo.add_do_method(collision_target, "add_child", collision_polygon)
		undo_redo.add_do_property(collision_polygon, "owner", scene_root)
		undo_redo.add_do_reference(collision_polygon)

		# Undo: Remove this new polygon
		undo_redo.add_undo_method(collision_target, "remove_child", collision_polygon)

	undo_redo.commit_action()

	var target_info = " to " + collision_target.name if collision_target != selected_sprite else ""
	_update_status("Successfully generated %d collision polygon(s)%s" % [polygons.size(), target_info])

func _on_generation_complete(polygon_count: int, point_count: int):
	info_label.text = "Polygons: %d | Points: %d" % [polygon_count, point_count]

func _on_generation_failed(error: String):
	_update_status("Generation failed: %s" % error, true)
	info_label.text = ""

func _update_status(text: String, is_error: bool = false):
	status_label.text = text
	status_label.add_theme_color_override("font_color", Color.RED if is_error else Color.WHITE)
