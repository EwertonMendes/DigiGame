@tool
extends EditorPlugin

const AUTHORING_ROOT = preload("res://src/world/authoring/CentralCityAuthoringRoot.gd")
const ROAD_SCRIPT = preload("res://src/world/authoring/CentralCityRoadAuthoring.gd")
const ROAD_GEOMETRY = preload("res://src/world/runtime/CentralCityRoadGeometry.gd")
const BOUNDARY_SCRIPT = preload("res://src/world/authoring/CentralCityBoundaryAuthoring.gd")
const MATH = preload("res://src/world/authoring/CentralCityEditorMath.gd")
const VALIDATOR = preload("res://src/world/authoring/CentralCityAuthoringValidator.gd")
const BAKER = preload("res://src/world/authoring/CentralCityBaker.gd")
const DECOR_CONFIG_PATH := "res://assets/resources/world/central_city_decor.json"

const HANDLE_RADIUS := 8.0
const HIT_RADIUS := 15.0
const ROAD_COLOR := Color(1.0, 0.62, 0.10, 0.96)
const ROAD_IDLE_COLOR := Color(1.0, 0.62, 0.10, 0.34)
const ROAD_HOVER_FILL := Color(1.0, 0.62, 0.10, 0.10)
const ROAD_SELECTED_FILL := Color(1.0, 0.62, 0.10, 0.16)
const ROAD_SELECTED_BORDER := Color(1.0, 0.78, 0.32, 0.92)
const HANDLE_COLOR := Color(1.0, 0.92, 0.32, 1.0)
const WIDTH_COLOR := Color(0.24, 0.92, 1.0, 1.0)
const SELECT_COLOR := Color(0.35, 1.0, 0.55, 0.95)

var _toolbar: HBoxContainer
var _toolbar_toggle: Button
var _toolbar_expanded := true
var _mode: OptionButton
var _snap: OptionButton
var _surface: OptionButton
var _overlay_toggle: Button
var _status: Label
var _active_root: Node = null
var _show_handles := true
var _hovered_road: Line2D = null

var _drag_kind := ""
var _drag_node: Node = null
var _drag_point_index := -1
var _drag_start_mouse_world := Vector2.ZERO
var _drag_original: Array[Dictionary] = []
var _drag_old_width := 0.0
var _drag_changed := false
var _pointer_double_click := false

var _paint_stroke_active := false
var _paint_erase := false
var _paint_old_cells: Dictionary = {}
var _paint_last_cell := Vector2i(999999, 999999)
var _ground_hover_cell := Vector2i(999999, 999999)
var _creating_road := false
var _road_creation_start := Vector2(INF, INF)
var _decor_config_cache: Dictionary = {}


func _enter_tree() -> void:
	_build_toolbar()
	add_control_to_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	set_input_event_forwarding_always_enabled()
	set_force_draw_over_forwarding_enabled()
	_toolbar.visible = false


func _exit_tree() -> void:
	if _toolbar != null:
		remove_control_from_container(EditorPlugin.CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
	_toolbar = null


func _handles(_object: Object) -> bool:
	# The road tool must remain active even if the stock 2D editor clears the
	# current selection after an empty click. Scene identity, not selection,
	# decides whether this plugin owns the Central City authoring workflow.
	return _authoring_root() != null


func _edit(_object: Object) -> void:
	_sync_active_root()


func _make_visible(_visible: bool) -> void:
	# Godot calls this when the selected object changes. Central City tools are
	# scene-level authoring controls, so selection must never decide whether the
	# toolbar exists. Its visibility follows the edited scene instead.
	_sync_toolbar_visibility()


func _process(_delta: float) -> void:
	var root := _authoring_root()
	if root != _active_root:
		_active_root = root
		_sync_overlay_toggle()
		update_overlays()
	_sync_toolbar_visibility()


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	var root := _authoring_root()
	if root == null or not _toolbar_expanded or not _show_handles:
		return
	if _mode_text() == "Road":
		_draw_all_roads(overlay, root)
		_draw_new_road_start(overlay)
	if _mode_text() == "Ground":
		_draw_ground_hover(overlay)
	if _mode_text() == "Level":
		_draw_all_boundaries(overlay, root)
	var selected := _selected_node()
	if selected != null and selected.get_script() == ROAD_SCRIPT:
		_draw_selected_road(overlay, selected as Line2D)
	elif selected != null and selected.get_script() == BOUNDARY_SCRIPT:
		_draw_selected_boundary(overlay, selected as Line2D)
	elif selected is Marker2D and _is_under_authoring_root(selected):
		_draw_marker_handle(overlay, selected as Marker2D)
	elif selected is Polygon2D and _is_under_authoring_root(selected):
		_draw_polygon_outline(overlay, selected as Polygon2D)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	var root := _authoring_root()
	if root == null or not _toolbar_expanded:
		return false

	if _mode_text() == "Ground":
		return _handle_ground_input(event, root)

	if _mode_text() == "Road" and _creating_road and event is InputEventMouseButton:
		var create_button := event as InputEventMouseButton
		if create_button.button_index == MOUSE_BUTTON_LEFT and create_button.pressed:
			_complete_new_road(create_button.position, root)
			return true
		if create_button.button_index == MOUSE_BUTTON_RIGHT and create_button.pressed:
			_creating_road = false
			_road_creation_start = Vector2(INF, INF)
			_status.text = "Road creation cancelled"
			update_overlays()
			return true

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return false
		if button.pressed:
			_pointer_double_click = button.double_click
			return _begin_pointer_action(button.position, root)
		_finish_pointer_action()
		return _drag_kind != ""

	if event is InputEventMouseMotion and not _drag_kind.is_empty():
		_update_pointer_drag(event as InputEventMouseMotion)
		return true

	if event is InputEventMouseMotion and _mode_text() == "Road":
		var motion := event as InputEventMouseMotion
		var hover_hit := _road_hit(motion.position, root)
		var next_hover: Line2D = null
		if not hover_hit.is_empty():
			next_hover = hover_hit.get("road") as Line2D
		if next_hover != _hovered_road:
			_hovered_road = next_hover
			update_overlays()
		return false

	return false


func _build_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.name = "CentralCityEditorToolbar"

	_toolbar_toggle = Button.new()
	_toolbar_toggle.text = "Central City ▾"
	_toolbar_toggle.toggle_mode = true
	_toolbar_toggle.button_pressed = true
	_toolbar_toggle.tooltip_text = "Keep Central City authoring tools open. Click to collapse/restore them explicitly."
	_toolbar_toggle.toggled.connect(_on_toolbar_toggled)
	_toolbar.add_child(_toolbar_toggle)

	_mode = OptionButton.new()
	_mode.tooltip_text = "Editing tool. Roads are constrained/snapped automatically."
	for item in ["Select", "Road", "Ground", "Surface", "Transition", "Level", "Building", "Prop", "Landscape"]:
		_mode.add_item(item)
	_mode.item_selected.connect(func(_index: int) -> void:
		_hovered_road = null
		_status.text = _mode_text()
		update_overlays()
	)
	_toolbar.add_child(_mode)

	var new_road_button := Button.new()
	new_road_button.text = "+ Road"
	new_road_button.tooltip_text = "Create a new snapped road with two clicks."
	new_road_button.pressed.connect(_start_new_road)
	_toolbar.add_child(new_road_button)

	var snap_label := Label.new()
	snap_label.text = "Snap"
	_toolbar.add_child(snap_label)
	_snap = OptionButton.new()
	for entry in [["1", 1.0], ["1/2", 0.5], ["1/4", 0.25]]:
		_snap.add_item(entry[0])
		_snap.set_item_metadata(_snap.item_count - 1, entry[1])
	_snap.select(1)
	_toolbar.add_child(_snap)

	_surface = OptionButton.new()
	for item in ["main", "dark", "stone_soft", "tech_teal", "tech_blue", "tech_purple", "market", "training", "grass", "water", "void"]:
		_surface.add_item(item)
	_surface.select(0)
	_surface.tooltip_text = "Surface used by Ground paint or applied to the selected road/region."
	_surface.item_selected.connect(_on_surface_selected)
	_toolbar.add_child(_surface)

	_overlay_toggle = Button.new()
	_overlay_toggle.text = "Handles"
	_overlay_toggle.toggle_mode = true
	_overlay_toggle.toggled.connect(_on_overlay_toggled)
	_toolbar.add_child(_overlay_toggle)

	var validate_button := Button.new()
	validate_button.text = "Validate"
	validate_button.pressed.connect(_validate_city)
	_toolbar.add_child(validate_button)

	var duplicate_button := Button.new()
	duplicate_button.text = "Duplicate"
	duplicate_button.pressed.connect(_duplicate_selected)
	_toolbar.add_child(duplicate_button)

	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_delete_selected)
	_toolbar.add_child(delete_button)

	var bake_button := Button.new()
	bake_button.text = "Bake"
	bake_button.pressed.connect(_bake_city)
	_toolbar.add_child(bake_button)

	_status = Label.new()
	_status.text = "Select"
	_status.custom_minimum_size = Vector2(170.0, 0.0)
	_toolbar.add_child(_status)


func _authoring_root() -> Node2D:
	var root := get_editor_interface().get_edited_scene_root()
	if root is Node2D and root.get_script() == AUTHORING_ROOT:
		return root as Node2D
	return null


func _sync_active_root() -> void:
	_active_root = _authoring_root()
	_sync_toolbar_visibility()
	_sync_overlay_toggle()
	update_overlays()


func _sync_overlay_toggle() -> void:
	var root := _authoring_root()
	if root == null or _overlay_toggle == null:
		return
	# Raw authoring nodes stay hidden: the plugin draws only precise handles on
	# top of the real WYSIWYG runtime preview.
	root.set("show_edit_overlays", false)
	_overlay_toggle.set_pressed_no_signal(_show_handles)


func _on_overlay_toggled(enabled: bool) -> void:
	_show_handles = enabled
	var root := _authoring_root()
	if root != null:
		root.set("show_edit_overlays", false)
	update_overlays()


func _on_surface_selected(_index: int) -> void:
	var selected := _selected_node()
	if selected == null or not _has_property(selected, "surface"):
		return
	var next_surface := _surface.get_item_text(_surface.selected)
	if selected.get_script() == ROAD_SCRIPT and next_surface == "void":
		_status.text = "Void is only valid for Ground"
		return
	var previous := String(selected.get("surface"))
	if previous == next_surface:
		return
	var undo := get_undo_redo()
	undo.create_action("Change Central City surface")
	undo.add_do_property(selected, "surface", next_surface)
	undo.add_undo_property(selected, "surface", previous)
	undo.commit_action()
	_status.text = "Surface: %s" % next_surface


func _duplicate_selected() -> void:
	var root := _authoring_root()
	var selected := _selected_node()
	if root == null or selected == null or selected == root or selected.get_parent() == null:
		return
	var parent := selected.get_parent()
	if parent.name == "Buildings":
		_status.text = "Service buildings are unique; move the existing building"
		return
	var duplicate := selected.duplicate()
	duplicate.name = "%s_Copy" % selected.name
	if _has_property(duplicate, "road_id"):
		duplicate.set("road_id", _unique_authoring_id(String(selected.get("road_id")), selected.get_parent()))
	if _has_property(duplicate, "transition_id"):
		duplicate.set("transition_id", _unique_authoring_id(String(selected.get("transition_id")), selected.get_parent()))
	if _has_property(duplicate, "landscape_id"):
		duplicate.set("landscape_id", _unique_authoring_id(String(selected.get("landscape_id")), selected.get_parent()))
	var undo := get_undo_redo()
	undo.create_action("Duplicate Central City object")
	undo.add_do_method(parent, "add_child", duplicate)
	undo.add_do_method(duplicate, "set_owner", root)
	undo.add_do_reference(duplicate)
	undo.add_undo_method(parent, "remove_child", duplicate)
	undo.commit_action()
	_select_node(duplicate)
	_status.text = "Duplicated"


func _delete_selected() -> void:
	var root := _authoring_root()
	var selected := _selected_node()
	if root == null or selected == null or selected == root or selected.get_parent() == null:
		return
	var parent := selected.get_parent()
	get_editor_interface().get_selection().clear()
	var undo := get_undo_redo()
	undo.create_action("Delete Central City object")
	undo.add_do_method(parent, "remove_child", selected)
	undo.add_undo_method(parent, "add_child", selected)
	undo.add_undo_method(selected, "set_owner", root)
	undo.add_undo_reference(selected)
	undo.commit_action()
	_status.text = "Deleted"


func _unique_authoring_id(base_id: String, parent: Node) -> String:
	var stem := "%s_copy" % (base_id if not base_id.is_empty() else "item")
	var candidate := stem
	var suffix := 2
	while true:
		var used := false
		for child in parent.get_children():
			for property_name in ["road_id", "transition_id", "landscape_id"]:
				if _has_property(child, property_name) and String(child.get(property_name)) == candidate:
					used = true
					break
			if used:
				break
		if not used:
			return candidate
		candidate = "%s_%d" % [stem, suffix]
		suffix += 1
	return candidate


func _on_toolbar_toggled(expanded: bool) -> void:
	_toolbar_expanded = expanded
	_apply_toolbar_expanded_state()
	if not expanded:
		_finish_pointer_action()
		_paint_stroke_active = false
		_creating_road = false
		_hovered_road = null
	_status.text = _mode_text() if expanded else "Paused"
	update_overlays()


func _apply_toolbar_expanded_state() -> void:
	if _toolbar == null or _toolbar_toggle == null:
		return
	_toolbar_toggle.text = "Central City ▾" if _toolbar_expanded else "Central City ▸"
	for child in _toolbar.get_children():
		if child == _toolbar_toggle:
			continue
		if child is CanvasItem:
			(child as CanvasItem).visible = _toolbar_expanded


func _sync_toolbar_visibility() -> void:
	if _toolbar == null:
		return
	var should_show := _authoring_root() != null
	if _toolbar.visible != should_show:
		_toolbar.visible = should_show
	if should_show:
		_apply_toolbar_expanded_state()


func _mode_text() -> String:
	return _mode.get_item_text(_mode.selected) if _mode != null else "Select"


func _snap_step() -> float:
	if _snap == null:
		return 0.5
	return float(_snap.get_item_metadata(_snap.selected))


func _canvas_transform() -> Transform2D:
	var viewport := get_editor_interface().get_editor_viewport_2d()
	# The 2D editor has no Camera2D. Pan and zoom live in the SubViewport's
	# global_canvas_transform. Using canvas_transform here makes gizmos drift
	# with pan/zoom and breaks viewport hit-testing.
	return viewport.get_global_canvas_transform() if viewport != null else Transform2D.IDENTITY


func _screen_to_visual_world(screen: Vector2) -> Vector2:
	return _canvas_transform().affine_inverse() * screen


func _visual_world_to_screen(world: Vector2) -> Vector2:
	return _canvas_transform() * world


func _screen_to_authoring_local(screen: Vector2) -> Vector2:
	var root := _authoring_root()
	var world := _screen_to_visual_world(screen)
	return root.to_local(world) if root != null else world


func _authoring_local_to_screen(local: Vector2) -> Vector2:
	var root := _authoring_root()
	var world := root.to_global(local) if root != null else local
	return _visual_world_to_screen(world)


func _selected_node() -> Node:
	var selected := get_editor_interface().get_selection().get_selected_nodes()
	return selected[0] if selected.size() == 1 else null


func _select_node(node: Node) -> void:
	var selection := get_editor_interface().get_selection()
	selection.clear()
	selection.add_node(node)
	if _surface != null and _has_property(node, "surface"):
		var current_surface := String(node.get("surface"))
		for index in range(_surface.item_count):
			if _surface.get_item_text(index) == current_surface:
				_surface.select(index)
				break
	update_overlays()


func _is_under_authoring_root(node: Node) -> bool:
	var root := _authoring_root()
	return root != null and (node == root or root.is_ancestor_of(node))


func _begin_pointer_action(screen: Vector2, root: Node) -> bool:
	var mode := _mode_text()
	var selected := _selected_node()
	if mode == "Level" or mode == "Select":
		var boundary_hit := _boundary_hit(screen, root)
		if not boundary_hit.is_empty():
			var boundary := boundary_hit.get("boundary") as Line2D
			_select_node(boundary)
			var boundary_point := int(boundary_hit.get("point_index", -1))
			if boundary_point >= 0:
				_begin_boundary_point_drag(boundary, boundary_point)
			else:
				_begin_boundary_body_drag(boundary, screen)
			return true
	if selected is Polygon2D and mode in ["Select", "Surface", "Transition"]:
		var vertex_index := _polygon_vertex_hit(screen, selected as Polygon2D)
		if vertex_index >= 0:
			_begin_polygon_vertex_drag(selected as Polygon2D, vertex_index)
			return true
	if mode == "Road" or mode == "Select":
		var road_hit := _road_hit(screen, root)
		if not road_hit.is_empty():
			var road := road_hit.get("road") as Line2D
			_select_node(road)
			var point_index := int(road_hit.get("point_index", -1))
			var width_hit := bool(road_hit.get("width", false))
			if _pointer_double_click and point_index < 0 and not width_hit:
				_split_road_at_screen(road, screen)
				return true
			if width_hit:
				_begin_width_drag(road)
			elif point_index >= 0:
				_begin_road_point_drag(road, point_index)
			else:
				_begin_road_body_drag(road, screen)
			return true

	var containers: Array[String] = []
	match mode:
		"Building":
			containers = ["Buildings"]
		"Prop":
			containers = ["Props"]
		"Landscape":
			containers = ["Landscapes"]
		"Surface":
			containers = ["Surfaces", "GroundOverrides"]
		"Transition":
			containers = ["Transitions"]
		"Select":
			containers = ["Buildings", "Props", "Landscapes", "Transitions", "Surfaces", "GroundOverrides"]
		_:
			pass

	var object_hit := _object_hit(screen, root, containers)
	if object_hit != null:
		_select_node(object_hit)
		if object_hit is Marker2D:
			_begin_marker_drag(object_hit as Marker2D, screen)
		elif object_hit is Polygon2D:
			_begin_polygon_drag(object_hit as Polygon2D, screen)
		return true

	# While a specialist Central City tool is active, clicking empty pavement
	# means "no target", not "leave the authoring context". Swallow the click so
	# Godot's stock 2D selection does not clear the current authored object.
	# Select mode intentionally keeps native empty-click deselection available.
	if mode != "Select":
		_status.text = "%s · no target" % mode
		return true
	return false


func _road_grid_points(road: Line2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in road.points:
		# Match CentralCityAuthoringData exactly: road.position + local point.
		result.append(MATH.world_to_grid(road.position + point))
	return result


func _road_grid_to_screen(grid: Vector2, elevation: float) -> Vector2:
	return _authoring_local_to_screen(MATH.grid_to_visual_world(grid, elevation))


func _road_screen_points(road: Line2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	var elevation := float(road.get("editor_elevation_px"))
	for grid: Vector2 in _road_grid_points(road):
		result.append(_road_grid_to_screen(grid, elevation))
	return result


func _road_segment_screen_polygon(
	road: Line2D,
	segment_index: int,
	width_grid: float
) -> PackedVector2Array:
	var grids := _road_grid_points(road)
	if segment_index < 0 or segment_index >= grids.size() - 1:
		return PackedVector2Array()
	var grid_polygon := ROAD_GEOMETRY.corridor_grid_polygon(
		grids[segment_index],
		grids[segment_index + 1],
		width_grid
	)
	var elevation := float(road.get("editor_elevation_px"))
	var result := PackedVector2Array()
	for grid: Vector2 in grid_polygon:
		result.append(_road_grid_to_screen(grid, elevation))
	return result


func _road_outer_width(road: Line2D) -> float:
	return maxf(
		0.5,
		float(road.get("width_grid")) + maxf(0.0, float(road.get("border_width_grid"))) * 2.0
	)


func _road_hit(screen: Vector2, root: Node) -> Dictionary:
	var roads := root.get_node_or_null("Roads")
	if roads == null:
		return {}

	var selected := _selected_node()
	var best: Dictionary = {}
	var best_distance := INF

	for child in roads.get_children():
		if not child is Line2D or child.get_script() != ROAD_SCRIPT:
			continue
		var road := child as Line2D
		var centerline := _road_screen_points(road)
		if centerline.size() < 2:
			continue

		# Endpoints have priority so length editing stays effortless even at a
		# junction where several visible road corridors overlap.
		for index in range(centerline.size()):
			var endpoint_distance := screen.distance_to(centerline[index])
			if endpoint_distance <= HIT_RADIUS and endpoint_distance < best_distance:
				best_distance = endpoint_distance
				best = {"road": road, "point_index": index}

		# Width control only belongs to the selected road, so an invisible
		# handle on another road can never steal a click.
		if road == selected:
			var width_handle := _road_width_handle_screen(road)
			var width_distance := screen.distance_to(width_handle)
			if width_distance <= HIT_RADIUS and width_distance < best_distance:
				best_distance = width_distance
				best = {"road": road, "point_index": -1, "width": true}

		# Clicking anywhere on the actual rendered road selects it. The hit
		# polygon uses the exact same corridor math as the runtime mesh.
		var outer_width := _road_outer_width(road)
		for segment_index in range(centerline.size() - 1):
			var corridor := _road_segment_screen_polygon(road, segment_index, outer_width)
			if corridor.size() < 3 or not Geometry2D.is_point_in_polygon(screen, corridor):
				continue
			var center_distance := MATH.screen_distance_to_segment(
				screen,
				centerline[segment_index],
				centerline[segment_index + 1]
			)
			if center_distance < best_distance:
				best_distance = center_distance
				best = {"road": road, "point_index": -1}

	return best


func _boundary_screen_points(boundary: Line2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in boundary.points:
		result.append(_visual_world_to_screen(boundary.to_global(point)))
	return result


func _draw_all_boundaries(overlay: Control, root: Node) -> void:
	var container := root.get_node_or_null("Boundaries")
	if container == null:
		return
	var selected := _selected_node()
	for child in container.get_children():
		if not child is Line2D or child == selected:
			continue
		var points := _boundary_screen_points(child as Line2D)
		if points.size() >= 2:
			overlay.draw_polyline(points, Color(0.78, 0.40, 1.0, 0.55), 3.0, true)


func _draw_selected_boundary(overlay: Control, boundary: Line2D) -> void:
	var points := _boundary_screen_points(boundary)
	if points.size() >= 2:
		overlay.draw_polyline(points, Color(0.83, 0.45, 1.0, 1.0), 4.0, true)
	for point: Vector2 in points:
		overlay.draw_circle(point, HANDLE_RADIUS, Color(0.92, 0.70, 1.0, 1.0))


func _boundary_hit(screen: Vector2, root: Node) -> Dictionary:
	var container := root.get_node_or_null("Boundaries")
	if container == null:
		return {}
	var best := {}
	var best_distance := INF
	for child in container.get_children():
		if not child is Line2D:
			continue
		var boundary := child as Line2D
		var points := _boundary_screen_points(boundary)
		for index in range(points.size()):
			var distance := screen.distance_to(points[index])
			if distance <= HIT_RADIUS and distance < best_distance:
				best_distance = distance
				best = {"boundary": boundary, "point_index": index}
		for index in range(points.size() - 1):
			var distance := MATH.screen_distance_to_segment(screen, points[index], points[index + 1])
			if distance <= 12.0 and distance < best_distance:
				best_distance = distance
				best = {"boundary": boundary, "point_index": -1}
	return best


func _begin_boundary_point_drag(boundary: Line2D, point_index: int) -> void:
	_drag_kind = "boundary_point"
	_drag_node = boundary
	_drag_point_index = point_index
	_drag_original = [{
		"node": boundary,
		"points": boundary.points.duplicate(),
		"threshold": float(boundary.get("lower_threshold_grid_y")),
	}]
	_drag_changed = false
	_status.text = "Level edge · drag endpoint"


func _begin_boundary_body_drag(boundary: Line2D, screen: Vector2) -> void:
	_drag_kind = "boundary_body"
	_drag_node = boundary
	_drag_start_mouse_world = _screen_to_visual_world(screen)
	_drag_original = [{
		"node": boundary,
		"points": boundary.points.duplicate(),
		"threshold": float(boundary.get("lower_threshold_grid_y")),
	}]
	_drag_changed = false
	_status.text = "Level edge · drag whole boundary"


func _update_boundary_point_drag(event: InputEventMouseMotion) -> void:
	var boundary := _drag_node as Line2D
	var original := _drag_original[0].get("points") as PackedVector2Array
	var candidate_grid := MATH.world_to_grid(_screen_to_visual_world(event.position))
	if not event.alt_pressed:
		candidate_grid = MATH.snap_grid(candidate_grid, _snap_step())
	var other_index := 1 if _drag_point_index == 0 else 0
	var other_grid := MATH.world_to_grid(original[other_index])
	candidate_grid.y = other_grid.y
	var updated := original.duplicate()
	updated[_drag_point_index] = boundary.to_local(MATH.grid_to_world(candidate_grid))
	boundary.points = updated
	_drag_changed = true


func _update_boundary_body_drag(event: InputEventMouseMotion) -> void:
	var boundary := _drag_node as Line2D
	var original := _drag_original[0].get("points") as PackedVector2Array
	var start_grid := MATH.world_to_grid(_drag_start_mouse_world)
	var current_grid := MATH.world_to_grid(_screen_to_visual_world(event.position))
	var delta := current_grid - start_grid
	if not event.alt_pressed:
		delta = MATH.snap_grid(delta, _snap_step())
	var updated := original.duplicate()
	for index in range(updated.size()):
		updated[index] += MATH.grid_to_world(delta)
	boundary.points = updated
	var old_threshold := float(_drag_original[0].get("threshold"))
	boundary.set("lower_threshold_grid_y", old_threshold + delta.y)
	_drag_changed = true


func _commit_boundary_undo() -> void:
	var boundary := _drag_node as Line2D
	var old_points := (_drag_original[0].get("points") as PackedVector2Array).duplicate()
	var old_threshold := float(_drag_original[0].get("threshold"))
	var final_points := boundary.points.duplicate()
	var final_threshold := float(boundary.get("lower_threshold_grid_y"))
	boundary.points = old_points
	boundary.set("lower_threshold_grid_y", old_threshold)
	var undo := get_undo_redo()
	undo.create_action("Edit Central City level boundary")
	undo.add_do_property(boundary, "points", final_points)
	undo.add_undo_property(boundary, "points", old_points)
	undo.add_do_property(boundary, "lower_threshold_grid_y", final_threshold)
	undo.add_undo_property(boundary, "lower_threshold_grid_y", old_threshold)
	undo.commit_action()


func _draw_new_road_start(overlay: Control) -> void:
	if not _creating_road or _road_creation_start.x == INF:
		return
	var elevation := 48.0 if _road_creation_start.y < 19.5 else 0.0
	var world := MATH.grid_to_visual_world(_road_creation_start, elevation)
	var screen := _visual_world_to_screen(world)
	overlay.draw_circle(screen, 10.0, WIDTH_COLOR)
	overlay.draw_circle(screen, 16.0, WIDTH_COLOR, false, 2.0)


func _draw_all_roads(overlay: Control, root: Node) -> void:
	var roads := root.get_node_or_null("Roads")
	if roads == null:
		return
	var selected := _selected_node()
	for child in roads.get_children():
		if not child is Line2D or child.get_script() != ROAD_SCRIPT or child == selected:
			continue
		var road := child as Line2D
		var points := _road_screen_points(road)
		if points.size() < 2:
			continue
		if road == _hovered_road:
			for segment_index in range(points.size() - 1):
				var hover_polygon := _road_segment_screen_polygon(
					road,
					segment_index,
					_road_outer_width(road)
				)
				if hover_polygon.size() >= 3:
					overlay.draw_colored_polygon(hover_polygon, ROAD_HOVER_FILL)
					_draw_closed_polyline(
						overlay,
						hover_polygon,
						Color(1.0, 0.74, 0.28, 0.72),
						2.0
					)
		overlay.draw_polyline(
			points,
			ROAD_COLOR if road == _hovered_road else ROAD_IDLE_COLOR,
			2.0 if road == _hovered_road else 1.25,
			true
		)


func _draw_closed_polyline(
	overlay: Control,
	polygon: PackedVector2Array,
	color: Color,
	width: float
) -> void:
	if polygon.size() < 2:
		return
	var closed := polygon.duplicate()
	closed.append(polygon[0])
	overlay.draw_polyline(closed, color, width, true)


func _draw_selected_road(overlay: Control, road: Line2D) -> void:
	var points := _road_screen_points(road)
	if points.size() < 2:
		return

	# Show the real corridor footprint instead of an abstract line. The inner
	# fill is Width Grid; the bright outline includes the authored road border.
	for segment_index in range(points.size() - 1):
		var outer_polygon := _road_segment_screen_polygon(
			road,
			segment_index,
			_road_outer_width(road)
		)
		if outer_polygon.size() >= 3:
			overlay.draw_colored_polygon(
				outer_polygon,
				Color(ROAD_SELECTED_FILL.r, ROAD_SELECTED_FILL.g, ROAD_SELECTED_FILL.b, 0.08)
			)
			_draw_closed_polyline(overlay, outer_polygon, ROAD_SELECTED_BORDER, 2.0)

		var inner_polygon := _road_segment_screen_polygon(
			road,
			segment_index,
			maxf(0.5, float(road.get("width_grid")))
		)
		if inner_polygon.size() >= 3:
			overlay.draw_colored_polygon(inner_polygon, ROAD_SELECTED_FILL)

	overlay.draw_polyline(points, ROAD_COLOR, 2.5, true)

	for point: Vector2 in points:
		overlay.draw_circle(point, HANDLE_RADIUS, HANDLE_COLOR)
		overlay.draw_circle(
			point,
			HANDLE_RADIUS,
			Color(0.15, 0.15, 0.15, 1.0),
			false,
			2.0
		)

	var width_handle := _road_width_handle_screen(road)
	var first_midpoint := (points[0] + points[1]) * 0.5
	overlay.draw_line(first_midpoint, width_handle, WIDTH_COLOR, 2.0)
	overlay.draw_circle(width_handle, 8.0, WIDTH_COLOR)
	overlay.draw_circle(width_handle, 12.0, WIDTH_COLOR, false, 1.5)


func _road_width_handle_screen(road: Line2D) -> Vector2:
	var grids := _road_grid_points(road)
	if grids.size() < 2:
		return Vector2.ZERO
	var handle_grid := ROAD_GEOMETRY.width_handle_grid(
		grids[0],
		grids[1],
		maxf(0.5, float(road.get("width_grid")))
	)
	return _road_grid_to_screen(handle_grid, float(road.get("editor_elevation_px")))


func _begin_road_point_drag(road: Line2D, point_index: int) -> void:
	_drag_kind = "road_point"
	_drag_node = road
	_drag_point_index = point_index
	_drag_original = _collect_connected_endpoint_snapshots(road, point_index)
	_drag_changed = false
	_status.text = "Road endpoint · drag to resize · Shift = free angle · Alt = no snap"


func _begin_road_body_drag(road: Line2D, screen: Vector2) -> void:
	_drag_kind = "road_body"
	_drag_node = road
	_drag_start_mouse_world = _screen_to_authoring_local(screen)
	_drag_original = _collect_road_body_snapshots(road)
	_drag_changed = false
	_status.text = "Road · drag to move"


func _begin_width_drag(road: Line2D) -> void:
	_drag_kind = "road_width"
	_drag_node = road
	_drag_old_width = float(road.get("width_grid"))
	_drag_changed = false
	_status.text = "Road width · drag sideways"


func _update_pointer_drag(event: InputEventMouseMotion) -> void:
	if _drag_node == null or not is_instance_valid(_drag_node):
		return
	match _drag_kind:
		"road_point":
			_update_road_point_drag(event)
		"road_body":
			_update_road_body_drag(event)
		"road_width":
			_update_road_width_drag(event)
		"boundary_point":
			_update_boundary_point_drag(event)
		"boundary_body":
			_update_boundary_body_drag(event)
		"marker":
			_update_marker_drag(event)
		"polygon":
			_update_polygon_drag(event)
		"polygon_vertex":
			_update_polygon_vertex_drag(event)
	update_overlays()


func _update_road_point_drag(event: InputEventMouseMotion) -> void:
	var road := _drag_node as Line2D
	var elevation := float(road.get("editor_elevation_px"))
	var visual_local := _screen_to_authoring_local(event.position)
	var candidate_grid := MATH.world_to_grid(visual_local + Vector2(0.0, elevation))
	var step := 0.0 if event.alt_pressed else _snap_step()
	var grids := _road_grid_points(road)
	if grids.is_empty():
		return

	var anchor_index := 1 if _drag_point_index == 0 else grids.size() - 2
	var original_grid := grids[_drag_point_index]
	var anchor_grid := grids[anchor_index]
	var target_grid := (
		MATH.snap_grid(candidate_grid, step)
		if event.shift_pressed or grids.size() > 2 and _drag_point_index > 0 and _drag_point_index < grids.size() - 1
		else MATH.constrained_endpoint(anchor_grid, original_grid, candidate_grid, step)
	)
	if not event.alt_pressed and not event.shift_pressed:
		target_grid = _magnetize_to_road_endpoint(target_grid, road)

	var target_authoring_world := MATH.grid_to_world(target_grid)
	for snapshot in _drag_original:
		var node := snapshot.get("node") as Line2D
		var index := int(snapshot.get("index", -1))
		if node == null or index < 0:
			continue
		var updated := node.points
		updated[index] = target_authoring_world - node.position
		node.points = updated
	_drag_changed = true


func _collect_connected_endpoint_snapshots(road: Line2D, point_index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var target_authoring_world := road.position + road.points[point_index]
	var root := _authoring_root()
	var roads := root.get_node_or_null("Roads") if root != null else null
	if roads == null:
		return result
	for child in roads.get_children():
		if not child is Line2D:
			continue
		var candidate := child as Line2D
		for index in range(candidate.points.size()):
			var endpoint := index == 0 or index == candidate.points.size() - 1
			var candidate_world := candidate.position + candidate.points[index]
			if endpoint and candidate_world.distance_to(target_authoring_world) <= 0.25:
				result.append({
					"node": candidate,
					"index": index,
					"points": candidate.points.duplicate(),
				})
	if result.is_empty():
		result.append({"node": road, "index": point_index, "points": road.points.duplicate()})
	return result


func _collect_road_body_snapshots(road: Line2D) -> Array[Dictionary]:
	var result: Array[Dictionary] = [{"node": road, "points": road.points.duplicate()}]
	for endpoint_index in [0, road.points.size() - 1]:
		var connected := _collect_connected_endpoint_snapshots(road, endpoint_index)
		for entry in connected:
			var node = entry.get("node")
			if node == road:
				continue
			var exists := false
			for current in result:
				if current.get("node") == node:
					exists = true
					break
			if not exists:
				result.append(entry)
	return result


func _update_road_body_drag(event: InputEventMouseMotion) -> void:
	var road := _drag_node as Line2D
	var elevation := float(road.get("editor_elevation_px"))
	var current_visual := _screen_to_authoring_local(event.position)
	var start_grid := MATH.world_to_grid(_drag_start_mouse_world + Vector2(0.0, elevation))
	var current_grid := MATH.world_to_grid(current_visual + Vector2(0.0, elevation))
	var delta_grid := current_grid - start_grid
	if not event.alt_pressed:
		delta_grid = MATH.snap_grid(delta_grid, _snap_step())
	var delta_world := MATH.grid_to_world(delta_grid)

	var road_old := PackedVector2Array()
	for entry in _drag_original:
		if entry.get("node") == road:
			road_old = (entry.get("points") as PackedVector2Array).duplicate()
			break
	if road_old.is_empty():
		return

	var road_new := road_old.duplicate()
	for index in range(road_new.size()):
		road_new[index] += delta_world
	road.points = road_new

	for entry in _drag_original:
		var connected := entry.get("node") as Line2D
		if connected == null or connected == road:
			continue
		var old_points := entry.get("points") as PackedVector2Array
		var new_points := old_points.duplicate()
		for endpoint_index in [0, new_points.size() - 1]:
			var endpoint_world := connected.position + old_points[endpoint_index]
			for moved_endpoint in [
				road.position + road_old[0],
				road.position + road_old[road_old.size() - 1],
			]:
				if endpoint_world.distance_to(moved_endpoint) <= 0.25:
					new_points[endpoint_index] += delta_world
		connected.points = new_points
	_drag_changed = true


func _update_road_width_drag(event: InputEventMouseMotion) -> void:
	var road := _drag_node as Line2D
	var grids := _road_grid_points(road)
	if grids.size() < 2:
		return

	var elevation := float(road.get("editor_elevation_px"))
	var visual_local := _screen_to_authoring_local(event.position)
	var mouse_grid := MATH.world_to_grid(visual_local + Vector2(0.0, elevation))
	var width_grid := maxf(
		0.5,
		ROAD_GEOMETRY.width_from_grid_point(grids[0], grids[1], mouse_grid)
	)
	if not event.alt_pressed:
		width_grid = maxf(0.5, roundf(width_grid * 4.0) / 4.0)
	road.set("width_grid", width_grid)
	_drag_changed = true


func _finish_pointer_action() -> void:
	if _drag_kind.is_empty():
		return
	if _drag_changed:
		match _drag_kind:
			"road_point", "road_body":
				_commit_road_points_undo()
			"road_width":
				_commit_width_undo()
			"boundary_point", "boundary_body":
				_commit_boundary_undo()
			"marker":
				_commit_marker_undo()
			"polygon", "polygon_vertex":
				_commit_polygon_undo()
	_drag_kind = ""
	_drag_node = null
	_drag_point_index = -1
	_drag_original.clear()
	_drag_changed = false
	_status.text = _mode_text()
	update_overlays()


func _commit_road_points_undo() -> void:
	var final_values: Array[Dictionary] = []
	for entry in _drag_original:
		var node := entry.get("node") as Line2D
		if node != null:
			final_values.append({"node": node, "points": node.points.duplicate()})
			node.points = (entry.get("points") as PackedVector2Array).duplicate()
	var undo := get_undo_redo()
	undo.create_action("Edit Central City road")
	for final in final_values:
		var node := final.get("node") as Line2D
		var old_points := PackedVector2Array()
		for entry in _drag_original:
			if entry.get("node") == node:
				old_points = (entry.get("points") as PackedVector2Array).duplicate()
				break
		undo.add_do_property(node, "points", (final.get("points") as PackedVector2Array).duplicate())
		undo.add_undo_property(node, "points", old_points)
	undo.commit_action()


func _commit_width_undo() -> void:
	var road := _drag_node
	var final_width := float(road.get("width_grid"))
	road.set("width_grid", _drag_old_width)
	var undo := get_undo_redo()
	undo.create_action("Resize Central City road")
	undo.add_do_property(road, "width_grid", final_width)
	undo.add_undo_property(road, "width_grid", _drag_old_width)
	undo.commit_action()


func _object_hit(screen: Vector2, root: Node, containers: Array[String]) -> Node:
	var best: Node = null
	var best_distance := INF
	for container_name in containers:
		var container := root.get_node_or_null(container_name)
		if container == null:
			continue
		for child in container.get_children():
			if child is Marker2D:
				var marker := child as Marker2D
				if container_name == "Props":
					var prop_polygon := _prop_screen_polygon(marker)
					if prop_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(screen, prop_polygon):
						var center := Vector2.ZERO
						for point: Vector2 in prop_polygon:
							center += point
						center /= float(prop_polygon.size())
						var distance := screen.distance_to(center)
						if distance < best_distance:
							best = marker
							best_distance = distance
						continue

				var grid := MATH.world_to_grid(marker.position)
				var elevation := 48.0 if grid.y < 19.5 else 0.0
				var marker_screen := _visual_world_to_screen(marker.global_position + Vector2(0.0, -elevation))
				var distance := screen.distance_to(marker_screen)
				var hit_radius := 210.0 if container_name == "Buildings" else 28.0
				if distance < hit_radius and distance < best_distance:
					best = marker
					best_distance = distance
			elif child is Polygon2D:
				var polygon_node := child as Polygon2D
				var screen_polygon := PackedVector2Array()
				var elevation := _polygon_elevation(polygon_node)
				for point: Vector2 in polygon_node.polygon:
					screen_polygon.append(_visual_world_to_screen(polygon_node.to_global(point) + Vector2(0.0, -elevation)))
				if screen_polygon.size() >= 3 and Geometry2D.is_point_in_polygon(screen, screen_polygon):
					return polygon_node
	return best


func _begin_marker_drag(marker: Marker2D, screen: Vector2) -> void:
	_drag_kind = "marker"
	_drag_node = marker
	_drag_start_mouse_world = _screen_to_visual_world(screen)
	_drag_original = [{"node": marker, "position": marker.position}]
	_drag_changed = false


func _update_marker_drag(event: InputEventMouseMotion) -> void:
	var marker := _drag_node as Marker2D
	var old_position := _drag_original[0].get("position") as Vector2
	var old_grid := MATH.world_to_grid(old_position)
	var start_grid := MATH.visual_world_to_grid(_drag_start_mouse_world)
	var current_grid := MATH.visual_world_to_grid(_screen_to_visual_world(event.position))
	var delta := current_grid - start_grid
	if not event.alt_pressed:
		delta = MATH.snap_grid(delta, _snap_step())
	marker.position = MATH.grid_to_world(old_grid + delta)
	_drag_changed = true


func _commit_marker_undo() -> void:
	var marker := _drag_node as Marker2D
	var old_position := _drag_original[0].get("position") as Vector2
	var final_position := marker.position
	marker.position = old_position
	var undo := get_undo_redo()
	undo.create_action("Move Central City object")
	undo.add_do_property(marker, "position", final_position)
	undo.add_undo_property(marker, "position", old_position)
	undo.commit_action()


func _begin_polygon_drag(polygon: Polygon2D, screen: Vector2) -> void:
	_drag_kind = "polygon"
	_drag_node = polygon
	_drag_start_mouse_world = _screen_to_visual_world(screen)
	_drag_original = [{
		"node": polygon,
		"position": polygon.position,
		"polygon": polygon.polygon.duplicate(),
	}]
	_drag_changed = false


func _update_polygon_drag(event: InputEventMouseMotion) -> void:
	var polygon := _drag_node as Polygon2D
	var old_position := _drag_original[0].get("position") as Vector2
	var start_grid := MATH.visual_world_to_grid(_drag_start_mouse_world)
	var current_grid := MATH.visual_world_to_grid(_screen_to_visual_world(event.position))
	var delta := current_grid - start_grid
	if not event.alt_pressed:
		delta = MATH.snap_grid(delta, _snap_step())
	polygon.position = old_position + MATH.grid_to_world(delta)
	_drag_changed = true


func _commit_polygon_undo() -> void:
	var polygon := _drag_node as Polygon2D
	var old_position := _drag_original[0].get("position") as Vector2
	var old_polygon := (
		(_drag_original[0].get("polygon") as PackedVector2Array).duplicate()
		if _drag_original[0].has("polygon")
		else polygon.polygon.duplicate()
	)
	var final_position := polygon.position
	var final_polygon := polygon.polygon.duplicate()
	polygon.position = old_position
	polygon.polygon = old_polygon
	var undo := get_undo_redo()
	undo.create_action("Edit Central City region")
	undo.add_do_property(polygon, "position", final_position)
	undo.add_undo_property(polygon, "position", old_position)
	undo.add_do_property(polygon, "polygon", final_polygon)
	undo.add_undo_property(polygon, "polygon", old_polygon)
	undo.commit_action()


func _draw_marker_handle(overlay: Control, marker: Marker2D) -> void:
	if marker.get_parent() != null and marker.get_parent().name == "Props":
		var prop_polygon := _prop_screen_polygon(marker)
		if prop_polygon.size() >= 3:
			var closed := prop_polygon.duplicate()
			closed.append(prop_polygon[0])
			overlay.draw_polyline(closed, SELECT_COLOR, 2.0, true)

	var grid := MATH.world_to_grid(marker.position)
	var elevation := 48.0 if grid.y < 19.5 else 0.0
	var screen := _visual_world_to_screen(marker.global_position + Vector2(0.0, -elevation))
	overlay.draw_circle(screen, 8.0, SELECT_COLOR)
	overlay.draw_circle(screen, 13.0, SELECT_COLOR, false, 2.0)


func _decor_config() -> Dictionary:
	if not _decor_config_cache.is_empty():
		return _decor_config_cache
	if not FileAccess.file_exists(DECOR_CONFIG_PATH):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DECOR_CONFIG_PATH))
	if parsed is Dictionary:
		_decor_config_cache = (parsed as Dictionary).duplicate(true)
	return _decor_config_cache


func _decor_asset(asset_id: String) -> Dictionary:
	var config := _decor_config()
	var assets_value = config.get("assets", {})
	if not assets_value is Dictionary:
		return {}
	var asset_value = (assets_value as Dictionary).get(asset_id, {})
	return (asset_value as Dictionary).duplicate(true) if asset_value is Dictionary else {}


func _array_vec2(value, fallback: Vector2 = Vector2.ZERO) -> Vector2:
	if value is Vector2:
		return value as Vector2
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func _prop_screen_polygon(marker: Marker2D) -> PackedVector2Array:
	var asset_id := String(marker.get("asset_id"))
	var asset := _decor_asset(asset_id)
	if asset.is_empty():
		return PackedVector2Array()

	var source_size := Vector2.ZERO
	var region_value = asset.get("region", [])
	if region_value is Array and (region_value as Array).size() >= 4:
		source_size = Vector2(float(region_value[2]), float(region_value[3]))
	else:
		var texture_path := String(asset.get("path", ""))
		if not texture_path.is_empty():
			var texture = ResourceLoader.load(texture_path)
			if texture is Texture2D:
				source_size = Vector2(
					float((texture as Texture2D).get_width()),
					float((texture as Texture2D).get_height())
				)
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return PackedVector2Array()

	var scale_value := maxf(0.001, float(asset.get("scale", 1.0)))
	var foot := _array_vec2(asset.get("foot", [source_size.x * 0.5, source_size.y]))
	var grid := MATH.world_to_grid(marker.position)
	var elevation := 48.0 if grid.y < 19.5 else 0.0
	var top_left := marker.position - foot * scale_value + Vector2(0.0, -elevation)
	var size := source_size * scale_value
	var local_corners := PackedVector2Array([
		top_left,
		top_left + Vector2(size.x, 0.0),
		top_left + size,
		top_left + Vector2(0.0, size.y),
	])
	var screen_corners := PackedVector2Array()
	for point: Vector2 in local_corners:
		screen_corners.append(_authoring_local_to_screen(point))
	return screen_corners


func _draw_polygon_outline(overlay: Control, polygon: Polygon2D) -> void:
	var points := _polygon_screen_points(polygon)
	if points.size() >= 2:
		var closed := points.duplicate()
		closed.append(points[0])
		overlay.draw_polyline(closed, SELECT_COLOR, 2.0, true)
		for point: Vector2 in points:
			overlay.draw_circle(point, 6.5, HANDLE_COLOR)
			overlay.draw_circle(point, 6.5, Color(0.12, 0.12, 0.12, 1.0), false, 1.5)


func _polygon_elevation(polygon: Polygon2D) -> float:
	if _has_property(polygon, "editor_elevation_px"):
		return float(polygon.get("editor_elevation_px"))
	if _has_property(polygon, "kind") and String(polygon.get("kind")) == "stairs":
		return 24.0
	if _has_property(polygon, "level_id") and String(polygon.get("level_id")) == "upper_civic":
		return 48.0
	return 0.0


func _has_property(object: Object, property_name: String) -> bool:
	for info in object.get_property_list():
		if String(info.get("name", "")) == property_name:
			return true
	return false


func _polygon_screen_points(polygon: Polygon2D) -> PackedVector2Array:
	var points := PackedVector2Array()
	var elevation := _polygon_elevation(polygon)
	for point: Vector2 in polygon.polygon:
		points.append(_visual_world_to_screen(polygon.to_global(point) + Vector2(0.0, -elevation)))
	return points


func _polygon_vertex_hit(screen: Vector2, polygon: Polygon2D) -> int:
	var points := _polygon_screen_points(polygon)
	var best := -1
	var best_distance := HIT_RADIUS
	for index in range(points.size()):
		var distance := screen.distance_to(points[index])
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _begin_polygon_vertex_drag(polygon: Polygon2D, point_index: int) -> void:
	_drag_kind = "polygon_vertex"
	_drag_node = polygon
	_drag_point_index = point_index
	_drag_original = [{
		"node": polygon,
		"position": polygon.position,
		"polygon": polygon.polygon.duplicate(),
	}]
	_drag_changed = false
	_status.text = "Region corner · drag to resize · Alt = no snap"


func _update_polygon_vertex_drag(event: InputEventMouseMotion) -> void:
	var polygon := _drag_node as Polygon2D
	if polygon == null or _drag_point_index < 0:
		return
	var elevation := _polygon_elevation(polygon)
	var visual_world := _screen_to_visual_world(event.position)
	var logical_global := visual_world + Vector2(0.0, elevation)
	var candidate_grid := MATH.world_to_grid(logical_global)
	if not event.alt_pressed:
		candidate_grid = MATH.snap_grid(candidate_grid, _snap_step())

	var kind_value = polygon.get("kind")
	if kind_value != null and String(kind_value) in ["stairs", "bridge", "void"]:
		_resize_transition_rect(polygon, _drag_point_index, candidate_grid)
	else:
		var updated := polygon.polygon.duplicate()
		updated[_drag_point_index] = polygon.to_local(MATH.grid_to_world(candidate_grid))
		polygon.polygon = updated
	_drag_changed = true


func _resize_transition_rect(polygon: Polygon2D, point_index: int, candidate_grid: Vector2) -> void:
	var original := _drag_original[0].get("polygon") as PackedVector2Array
	var grids: Array[Vector2] = []
	var min_grid := Vector2(INF, INF)
	var max_grid := Vector2(-INF, -INF)
	for point: Vector2 in original:
		var grid := MATH.world_to_grid(polygon.to_global(point))
		grids.append(grid)
		min_grid.x = minf(min_grid.x, grid.x)
		min_grid.y = minf(min_grid.y, grid.y)
		max_grid.x = maxf(max_grid.x, grid.x)
		max_grid.y = maxf(max_grid.y, grid.y)
	var original_min := min_grid
	var original_max := max_grid
	var selected_grid := grids[point_index]
	var move_min_x := absf(selected_grid.x - original_min.x) <= absf(selected_grid.x - original_max.x)
	var move_min_y := absf(selected_grid.y - original_min.y) <= absf(selected_grid.y - original_max.y)
	if move_min_x:
		min_grid.x = minf(candidate_grid.x, max_grid.x - 0.5)
	else:
		max_grid.x = maxf(candidate_grid.x, min_grid.x + 0.5)
	if move_min_y:
		min_grid.y = minf(candidate_grid.y, max_grid.y - 0.5)
	else:
		max_grid.y = maxf(candidate_grid.y, min_grid.y + 0.5)

	var rebuilt := PackedVector2Array()
	for original_grid: Vector2 in grids:
		var use_min_x := absf(original_grid.x - original_min.x) <= 0.01
		var use_min_y := absf(original_grid.y - original_min.y) <= 0.01
		var target := Vector2(
			min_grid.x if use_min_x else max_grid.x,
			min_grid.y if use_min_y else max_grid.y
		)
		rebuilt.append(polygon.to_local(MATH.grid_to_world(target)))
	polygon.polygon = rebuilt


func _handle_ground_input(event: InputEvent, root: Node) -> bool:
	var paint := root.get_node_or_null("GroundPaint")
	if paint == null:
		_status.text = "GroundPaint node missing"
		return false

	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_RIGHT:
			return false
		if button.pressed:
			_paint_stroke_active = true
			_paint_erase = button.button_index == MOUSE_BUTTON_RIGHT
			_paint_old_cells = (paint.get("cells") as Dictionary).duplicate(true)
			_paint_last_cell = Vector2i(999999, 999999)
			_paint_at(button.position, paint)
		else:
			_finish_ground_stroke(paint)
		return true

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var grid := MATH.visual_world_to_grid(_screen_to_visual_world(motion.position))
		_ground_hover_cell = Vector2i(roundi(grid.x), roundi(grid.y))
		update_overlays()
		if _paint_stroke_active:
			_paint_at(motion.position, paint)
			return true
	return false


func _draw_ground_hover(overlay: Control) -> void:
	if _ground_hover_cell.x == 999999:
		return
	var grid := Vector2(_ground_hover_cell)
	var elevation := 48.0 if grid.y < 19.5 else 0.0
	var center := MATH.grid_to_visual_world(grid, elevation)
	var corners := PackedVector2Array([
		center + Vector2(-32.0, 0.0),
		center + Vector2(0.0, -16.0),
		center + Vector2(32.0, 0.0),
		center + Vector2(0.0, 16.0),
		center + Vector2(-32.0, 0.0),
	])
	var screen_points := PackedVector2Array()
	for point: Vector2 in corners:
		screen_points.append(_visual_world_to_screen(point))
	overlay.draw_polyline(screen_points, Color(0.30, 0.95, 1.0, 1.0), 2.5, true)


func _paint_at(screen: Vector2, paint: Node) -> void:
	var grid := MATH.visual_world_to_grid(_screen_to_visual_world(screen))
	var step := _snap_step()
	var snapped := MATH.snap_grid(grid, maxf(0.5, step))
	var cell := Vector2i(roundi(snapped.x), roundi(snapped.y))
	if cell == _paint_last_cell:
		return
	_paint_last_cell = cell
	var cells := (paint.get("cells") as Dictionary).duplicate(true)
	var key := MATH.cell_key(cell)
	if _paint_erase:
		cells.erase(key)
	else:
		cells[key] = _surface.get_item_text(_surface.selected)
	paint.set("cells", cells)
	_status.text = ("Erase " if _paint_erase else "Paint ") + key


func _finish_ground_stroke(paint: Node) -> void:
	if not _paint_stroke_active:
		return
	_paint_stroke_active = false
	var final_cells := (paint.get("cells") as Dictionary).duplicate(true)
	if final_cells == _paint_old_cells:
		return
	paint.set("cells", _paint_old_cells.duplicate(true))
	var undo := get_undo_redo()
	undo.create_action("Paint Central City ground")
	undo.add_do_property(paint, "cells", final_cells)
	undo.add_undo_property(paint, "cells", _paint_old_cells.duplicate(true))
	undo.commit_action()
	_status.text = "Ground painted"


func _magnetize_to_road_endpoint(grid: Vector2, excluded_road: Line2D) -> Vector2:
	var root := _authoring_root()
	if root == null:
		return grid
	var roads := root.get_node_or_null("Roads")
	if roads == null:
		return grid
	var best := grid
	var best_distance := 0.76
	for child in roads.get_children():
		if not child is Line2D or child == excluded_road:
			continue
		var road := child as Line2D
		for index in [0, road.points.size() - 1]:
			if index < 0 or index >= road.points.size():
				continue
			var endpoint_world := road.position + road.points[index]
			var endpoint_grid := MATH.world_to_grid(endpoint_world)
			var distance := grid.distance_to(endpoint_grid)
			if distance < best_distance:
				best_distance = distance
				best = endpoint_grid
	return best


func _split_road_at_screen(road: Line2D, screen: Vector2) -> void:
	if road.points.size() < 2:
		return
	var elevation := float(road.get("editor_elevation_px"))
	var visual_local := _screen_to_authoring_local(screen)
	var target_grid := MATH.snap_grid(
		MATH.world_to_grid(visual_local + Vector2(0.0, elevation)),
		_snap_step()
	)
	var target_local := MATH.grid_to_world(target_grid) - road.position
	var screen_points := _road_screen_points(road)
	var segment_index := 0
	var best_distance := INF
	for index in range(screen_points.size() - 1):
		var distance := MATH.screen_distance_to_segment(
			screen,
			screen_points[index],
			screen_points[index + 1]
		)
		if distance < best_distance:
			best_distance = distance
			segment_index = index

	var old_points := road.points.duplicate()
	var next := PackedVector2Array()
	for index in range(old_points.size()):
		next.append(old_points[index])
		if index == segment_index:
			next.append(target_local)

	var undo := get_undo_redo()
	undo.create_action("Split Central City road")
	undo.add_do_property(road, "points", next)
	undo.add_undo_property(road, "points", old_points)
	undo.commit_action()
	_status.text = "Road junction added"


func _start_new_road() -> void:
	var root := _authoring_root()
	if root == null:
		return
	_mode.select(1)
	_creating_road = true
	_road_creation_start = Vector2(INF, INF)
	_status.text = "New Road · click start point"


func _complete_new_road(screen: Vector2, root: Node) -> void:
	var grid := MATH.visual_world_to_grid(_screen_to_authoring_local(screen))
	grid = MATH.snap_grid(grid, _snap_step())
	grid = _magnetize_to_road_endpoint(grid, null)
	if _road_creation_start.x == INF:
		_road_creation_start = grid
		_status.text = "New Road · click end point · right-click cancels"
		update_overlays()
		return

	var start := _road_creation_start
	var delta := grid - start
	var finish := grid
	if absf(delta.x) >= absf(delta.y):
		finish.y = start.y
	else:
		finish.x = start.x
	if finish.distance_to(start) < 0.49:
		_status.text = "Road is too short"
		return

	var roads := root.get_node_or_null("Roads")
	if roads == null:
		return
	var road := Line2D.new()
	road.name = "road_custom_%02d" % roads.get_child_count()
	road.set_script(ROAD_SCRIPT)
	road.points = PackedVector2Array([MATH.grid_to_world(start), MATH.grid_to_world(finish)])
	road.set("road_id", String(road.name))
	road.set("level_id", "upper_civic" if start.y < 19.5 else "south_terrace")
	road.set("editor_elevation_px", 48.0 if start.y < 19.5 else 0.0)
	road.set("width_grid", 3.0)
	road.set("surface", _surface.get_item_text(_surface.selected))

	var undo := get_undo_redo()
	undo.create_action("Create Central City road")
	undo.add_do_method(roads, "add_child", road)
	undo.add_do_method(road, "set_owner", root)
	undo.add_do_reference(road)
	undo.add_undo_method(roads, "remove_child", road)
	undo.commit_action()
	_select_node(road)
	_creating_road = false
	_road_creation_start = Vector2(INF, INF)
	_status.text = "Road created"


func _validate_city() -> void:
	var root := _authoring_root()
	if root == null:
		return
	var issues := VALIDATOR.validate(root)
	if issues.is_empty():
		_status.text = "✓ City valid"
		print("[CentralCityEditor] validation passed")
	else:
		_status.text = "⚠ %d issue(s)" % issues.size()
		for issue: String in issues:
			push_warning("[CentralCityEditor] %s" % issue)


func _bake_city() -> void:
	var root := _authoring_root()
	if root == null:
		return
	var issues := VALIDATOR.validate(root)
	if not issues.is_empty():
		_status.text = "Fix validation before bake"
		return
	var error := BAKER.bake(root)
	if error == OK:
		_status.text = "✓ Baked"
		print("[CentralCityEditor] baked Central City")
	else:
		_status.text = "Bake failed: %s" % error_string(error)


func _save_external_data() -> void:
	var root := _authoring_root()
	if root != null and VALIDATOR.validate(root).is_empty():
		BAKER.bake(root)
