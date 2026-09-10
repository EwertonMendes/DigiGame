extends Node

const MovementSystemScript = preload("res://src/MovementSystem.gd")
const DATABASE_PATH := "res://database/base-digimon-list.json"
const DEFAULT_MOV := 4
const ENEMY_PLACEHOLDER_TURN_SECONDS := 0.45
const INVALID_GRID := Vector2i(-9999, -9999)

enum Phase {
	TURN_START,
	COMMAND,
	MOVE_SELECT,
	MOVING,
	ACTION_SELECT,
	TARGET_SELECT,
	ACTION_RESOLVE,
	TURN_END,
}

var phase: Phase = Phase.TURN_START
var current_actor: Node = null
var _field: Node = null
var _controller: Node = null
var _movement_system = MovementSystemScript.new()
var _turn_order: Array[Node] = []
var _turn_index := -1
var _reachable_tiles: Dictionary = {}
var _turn_start_grid := Vector2i.ZERO

# Movement planning intentionally separates committed input from pointer preview.
# _planned_move_path is the locked/manual prefix that will actually be confirmed.
# _preview_move_path is transient and is freely replaced as the pointer changes tile.
var _planned_move_path: Array[Vector2i] = []
var _preview_move_path: Array[Vector2i] = []
var _preview_destination := INVALID_GRID
var _waypoints: Array[Vector2i] = []

var _last_move_path: Array[Vector2i] = []
var _has_moved := false
var _input_locked := false
var _mov_by_key: Dictionary = {}
var _debug_actor: Node = null
var _last_pointer_grid := INVALID_GRID


func _ready() -> void:
	_field = get_node_or_null("../Blocks")
	_controller = get_node_or_null("../DigimonController")
	if _field != null and _field.has_signal("hovered_grid_changed"):
		_field.connect("hovered_grid_changed", Callable(self, "_on_field_hovered_grid_changed"))
	_load_movement_database()
	call_deferred("_start_battle")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return

		if key_event.keycode == KEY_ESCAPE:
			if GlobalVariables.DebugMode:
				_clear_debug_selection()
				get_viewport().set_input_as_handled()
				return
			if phase == Phase.MOVE_SELECT and not _input_locked:
				cancel_move_selection()
				get_viewport().set_input_as_handled()
			return

		if phase == Phase.MOVE_SELECT and not _input_locked and _is_user_controlled(current_actor):
			if key_event.keycode == KEY_BACKSPACE or key_event.keycode == KEY_DELETE:
				remove_last_planned_step()
				get_viewport().set_input_as_handled()
				return
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
				confirm_move_path()
				get_viewport().set_input_as_handled()
				return
		return

	# Touch input is routed by MainCamera so taps, route tracing, pan, and pinch
	# have one deterministic gesture owner. Mouse drag tracing is handled here.
	if GlobalVariables.TouchInputActive:
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if is_manual_path_input_active() and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if handle_path_pointer_world(_pointer_world_position()):
				get_viewport().set_input_as_handled()
		return

	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	if GlobalVariables.DebugMode:
		if _handle_debug_world_tap(_pointer_world_position()):
			get_viewport().set_input_as_handled()
		return

	if _input_locked or current_actor == null or not _is_user_controlled(current_actor):
		return
	if handle_world_tap(_pointer_world_position()):
		get_viewport().set_input_as_handled()


func uses_tactical_input() -> bool:
	return true


func is_manual_path_input_active() -> bool:
	return (
		not GlobalVariables.DebugMode
		and phase == Phase.MOVE_SELECT
		and not _input_locked
		and current_actor != null
		and _is_user_controlled(current_actor)
	)


func set_debug_mode(enabled: bool) -> void:
	if enabled and phase == Phase.MOVE_SELECT and not _input_locked:
		cancel_move_selection()
	GlobalVariables.DebugMode = enabled
	if not enabled:
		_clear_debug_selection()
	_refresh_hud()


func handle_world_tap(world_position: Vector2) -> bool:
	# Debug movement is deliberately independent from the tactical turn state.
	if GlobalVariables.DebugMode:
		return _handle_debug_world_tap(world_position)

	if _input_locked or current_actor == null or not _is_user_controlled(current_actor):
		return false
	if _field == null or not _field.has_method("select_tile_from_world"):
		return false
	if not bool(_field.call("select_tile_from_world", world_position)):
		return false

	var grid := Vector2i(_field.call("world_to_grid", _field.to_local(world_position)))
	match phase:
		Phase.COMMAND:
			var hovered: Node = null
			if _controller != null and _controller.has_method("get_digimon_under_pointer"):
				hovered = _controller.call("get_digimon_under_pointer", world_position) as Node
			if hovered == current_actor:
				begin_move_selection()
				return true
		Phase.MOVE_SELECT:
			return _lock_move_destination(grid)
	return false


func handle_path_pointer_world(world_position: Vector2) -> bool:
	# Explicit mouse/touch dragging edits the locked route. It is intentionally
	# different from hover, which only previews and never mutates the plan.
	if not is_manual_path_input_active() or _field == null:
		return false
	var grid := Vector2i(_field.call("world_to_grid", _field.to_local(world_position)))
	if grid == _last_pointer_grid:
		return false
	_last_pointer_grid = grid
	if not bool(_field.call("select_tile_from_world", world_position)):
		return false
	return _apply_manual_drag_grid(grid)


func _on_field_hovered_grid_changed(grid: Vector2i, block_reason: String) -> void:
	if GlobalVariables.TouchInputActive or not is_manual_path_input_active():
		return
	if grid == INVALID_GRID or not block_reason.is_empty():
		if _clear_preview_state():
			_refresh_movement_plan_state()
		return
	_set_preview_destination(grid)


func _set_preview_destination(grid: Vector2i) -> bool:
	if not is_manual_path_input_active():
		return false

	var endpoint := _locked_endpoint()
	if grid == endpoint or _planned_move_path.has(grid):
		if _clear_preview_state():
			_refresh_movement_plan_state()
		return false

	var remaining := _remaining_movement_after_locked_path()
	if remaining <= 0:
		if _clear_preview_state():
			_refresh_movement_plan_state()
		return false

	var segment: Array[Vector2i] = _movement_system.find_path(
		_field,
		_controller,
		current_actor,
		endpoint,
		grid,
		remaining
	)
	if segment.is_empty():
		if _clear_preview_state():
			_refresh_movement_plan_state()
		return false

	if grid == _preview_destination and segment == _preview_move_path:
		return false

	_preview_destination = grid
	_preview_move_path = segment
	_refresh_movement_plan_state()
	return true


func _lock_move_destination(grid: Vector2i) -> bool:
	if not is_manual_path_input_active():
		return false

	# Tapping/clicking the origin is a quick, touch-friendly way to reset the plan.
	if grid == _turn_start_grid:
		var changed := not _planned_move_path.is_empty() or not _preview_move_path.is_empty()
		_planned_move_path.clear()
		_waypoints.clear()
		_clear_preview_state()
		if changed:
			_refresh_movement_plan_state()
		return true

	var endpoint := _locked_endpoint()
	# A second click/tap on the already locked destination confirms immediately.
	if grid == endpoint and not _planned_move_path.is_empty():
		confirm_move_path()
		return true

	# Clicking an earlier locked tile deliberately truncates/backtracks the route.
	var existing_index := _planned_move_path.find(grid)
	if existing_index >= 0:
		_planned_move_path.resize(existing_index + 1)
		_trim_waypoints_to_locked_path()
		_clear_preview_state()
		_refresh_movement_plan_state()
		return true

	if _preview_destination != grid or _preview_move_path.is_empty():
		_set_preview_destination(grid)
	if _preview_destination != grid or _preview_move_path.is_empty():
		return true

	for step: Vector2i in _preview_move_path:
		_planned_move_path.append(step)
	if _waypoints.is_empty() or _waypoints[_waypoints.size() - 1] != grid:
		_waypoints.append(grid)
	_clear_preview_state()
	_refresh_movement_plan_state()
	return true


func _apply_manual_drag_grid(grid: Vector2i) -> bool:
	if not is_manual_path_input_active():
		return false

	_clear_preview_state()
	if grid == _turn_start_grid:
		if _planned_move_path.is_empty():
			return false
		_planned_move_path.clear()
		_waypoints.clear()
		_refresh_movement_plan_state()
		return true

	var existing_index := _planned_move_path.find(grid)
	if existing_index >= 0:
		if existing_index == _planned_move_path.size() - 1:
			return false
		_planned_move_path.resize(existing_index + 1)
		_trim_waypoints_to_locked_path()
		_refresh_movement_plan_state()
		return true

	var endpoint := _locked_endpoint()
	var remaining := _remaining_movement_after_locked_path()
	if remaining <= 0:
		return false

	# Fast mouse/finger motion can skip visual tiles between input events. Fill
	# that gap with a valid path segment instead of silently ignoring the drag.
	var segment: Array[Vector2i] = _movement_system.find_path(
		_field,
		_controller,
		current_actor,
		endpoint,
		grid,
		remaining
	)
	if segment.is_empty():
		return false

	# If the generated segment touches our existing route, interpret it as
	# natural backtracking instead of creating a loop in the locked path.
	for step: Vector2i in segment:
		var path_index := _planned_move_path.find(step)
		if path_index >= 0:
			_planned_move_path.resize(path_index + 1)
			_trim_waypoints_to_locked_path()
			_refresh_movement_plan_state()
			return true

	for step: Vector2i in segment:
		_planned_move_path.append(step)
	_refresh_movement_plan_state()
	return true


func remove_last_planned_step() -> void:
	if not is_manual_path_input_active():
		return
	if not _preview_move_path.is_empty():
		_clear_preview_state()
		_refresh_movement_plan_state()
		return
	if _planned_move_path.is_empty():
		return
	_planned_move_path.pop_back()
	_trim_waypoints_to_locked_path()
	_refresh_movement_plan_state()


func confirm_move_path() -> bool:
	if not is_manual_path_input_active():
		return false
	var movement_points := _movement_for(current_actor)
	if not _movement_system.can_confirm_manual_path(
		_field,
		_controller,
		current_actor,
		_planned_move_path,
		movement_points
	):
		return false

	var path := _planned_move_path.duplicate()
	_input_locked = true
	phase = Phase.MOVING
	_clear_manual_path_visuals()
	_refresh_hud()
	await current_actor.call("move_along_grid_path", path, _field)
	_last_move_path = path.duplicate()
	_planned_move_path.clear()
	_preview_move_path.clear()
	_preview_destination = INVALID_GRID
	_waypoints.clear()
	_has_moved = true
	_reachable_tiles.clear()
	_input_locked = false
	if current_actor.has_method("set_tactical_selected"):
		current_actor.call("set_tactical_selected", false)
	phase = Phase.ACTION_SELECT
	_refresh_hud()
	return true


func _handle_debug_world_tap(world_position: Vector2) -> bool:
	if _controller == null or _field == null:
		return false

	var hovered: Node = null
	if _controller.has_method("get_digimon_under_pointer"):
		hovered = _controller.call("get_digimon_under_pointer", world_position) as Node

	if hovered != null:
		_set_debug_actor(hovered)
		return true

	if _debug_actor == null or not is_instance_valid(_debug_actor):
		_debug_actor = null
		return false
	if not _field.has_method("select_tile_from_world") or not bool(_field.call("select_tile_from_world", world_position)):
		return false

	var grid := Vector2i(_field.call("world_to_grid", _field.to_local(world_position)))
	var target_world := Vector2(_field.call("grid_to_world", grid))
	if _field.has_method("can_digimon_move_to_world"):
		if not bool(_field.call("can_digimon_move_to_world", target_world, _debug_actor)):
			return true

	if _debug_actor.has_method("debug_relocate_to_grid"):
		return bool(_debug_actor.call("debug_relocate_to_grid", grid, _field))
	if _debug_actor.has_method("get_tile_world_position"):
		var current_tile := Vector2(_debug_actor.call("get_tile_world_position"))
		_debug_actor.global_position += target_world - current_tile
		return true
	return false


func _set_debug_actor(actor: Node) -> void:
	if _debug_actor == actor:
		return
	_clear_debug_selection()
	_debug_actor = actor
	if _debug_actor != null and _debug_actor.has_method("set_debug_selected"):
		_debug_actor.call("set_debug_selected", true)


func _clear_debug_selection() -> void:
	if _debug_actor != null and is_instance_valid(_debug_actor) and _debug_actor.has_method("set_debug_selected"):
		_debug_actor.call("set_debug_selected", false)
	_debug_actor = null


func begin_move_selection() -> void:
	if current_actor == null or _input_locked or _has_moved or not _is_user_controlled(current_actor):
		return
	if phase != Phase.COMMAND:
		return

	_turn_start_grid = _grid_for_actor(current_actor)
	_planned_move_path.clear()
	_preview_move_path.clear()
	_preview_destination = INVALID_GRID
	_waypoints.clear()
	_reachable_tiles = _movement_system.get_reachable_tiles(
		_field,
		_controller,
		current_actor,
		_turn_start_grid,
		_movement_for(current_actor)
	)
	phase = Phase.MOVE_SELECT
	if current_actor.has_method("set_tactical_selected"):
		current_actor.call("set_tactical_selected", true)
	if _field != null and _field.has_method("set_movement_range"):
		_field.call("set_movement_range", _reachable_tiles, _turn_start_grid, current_actor)
	_refresh_movement_plan_state()


func cancel_move_selection() -> void:
	if phase != Phase.MOVE_SELECT or _input_locked:
		return
	_planned_move_path.clear()
	_preview_move_path.clear()
	_preview_destination = INVALID_GRID
	_waypoints.clear()
	_reachable_tiles.clear()
	_clear_manual_path_visuals()
	if current_actor != null and current_actor.has_method("set_tactical_selected"):
		current_actor.call("set_tactical_selected", false)
	phase = Phase.COMMAND
	_refresh_hud()


func _refresh_movement_plan_state() -> void:
	if phase != Phase.MOVE_SELECT or current_actor == null:
		return
	if _field != null and _field.has_method("set_movement_path"):
		_field.call("set_movement_path", _display_move_path())
	_last_pointer_grid = INVALID_GRID
	_refresh_hud()


func _display_move_path() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for grid: Vector2i in _planned_move_path:
		result.append(grid)
	for grid: Vector2i in _preview_move_path:
		result.append(grid)
	return result


func _locked_endpoint() -> Vector2i:
	if _planned_move_path.is_empty():
		return _turn_start_grid
	return _planned_move_path[_planned_move_path.size() - 1]


func _remaining_movement_after_locked_path() -> int:
	var spent := _movement_system.get_path_cost(_field, current_actor, _planned_move_path)
	return maxi(0, _movement_for(current_actor) - spent)


func _clear_preview_state() -> bool:
	var changed := not _preview_move_path.is_empty() or _preview_destination != INVALID_GRID
	_preview_move_path.clear()
	_preview_destination = INVALID_GRID
	return changed


func _trim_waypoints_to_locked_path() -> void:
	while not _waypoints.is_empty():
		var last_waypoint := _waypoints[_waypoints.size() - 1]
		if _planned_move_path.has(last_waypoint):
			break
		_waypoints.pop_back()


func _clear_manual_path_visuals() -> void:
	if _field == null:
		return
	if _field.has_method("clear_movement_range"):
		_field.call("clear_movement_range")
	if _field.has_method("clear_movement_path"):
		_field.call("clear_movement_path")
	if _field.has_method("clear_movement_step_options"):
		_field.call("clear_movement_step_options")


func defend_current() -> void:
	if current_actor == null or _input_locked or not _is_user_controlled(current_actor):
		return
	if phase != Phase.COMMAND and phase != Phase.ACTION_SELECT:
		return
	phase = Phase.ACTION_RESOLVE
	current_actor.set("is_defending", true)
	_refresh_hud()
	call_deferred("_end_turn")


func wait_current() -> void:
	if current_actor == null or _input_locked or not _is_user_controlled(current_actor):
		return
	if phase != Phase.COMMAND and phase != Phase.ACTION_SELECT:
		return
	phase = Phase.ACTION_RESOLVE
	_refresh_hud()
	call_deferred("_end_turn")


func undo_move() -> void:
	if current_actor == null or _input_locked or not _has_moved or phase != Phase.ACTION_SELECT:
		return
	if not current_actor.has_method("move_along_grid_path"):
		return

	var route: Array[Vector2i] = [_turn_start_grid]
	for grid in _last_move_path:
		route.append(grid)
	route.reverse()
	if not route.is_empty():
		route.remove_at(0)

	_input_locked = true
	phase = Phase.MOVING
	_refresh_hud()
	await current_actor.call("move_along_grid_path", route, _field)
	_has_moved = false
	_last_move_path.clear()
	_input_locked = false
	phase = Phase.COMMAND
	_refresh_hud()


func get_hud_state() -> Dictionary:
	var actor_name := ""
	if current_actor != null:
		actor_name = String(current_actor.get("digimon_key")).capitalize()
	var user_turn := current_actor != null and _is_user_controlled(current_actor)
	var total_mov := _movement_for(current_actor) if current_actor != null else DEFAULT_MOV
	var move_spent := 0
	if phase == Phase.MOVE_SELECT and current_actor != null:
		move_spent = _movement_system.get_path_cost(_field, current_actor, _display_move_path())
	var can_confirm := (
		user_turn
		and phase == Phase.MOVE_SELECT
		and not _input_locked
		and _movement_system.can_confirm_manual_path(
			_field,
			_controller,
			current_actor,
			_planned_move_path,
			total_mov
		)
	)
	return {
		"actor_name": actor_name,
		"phase": phase_name(),
		"mov": total_mov,
		"move_spent": move_spent,
		"move_remaining": maxi(0, total_mov - move_spent),
		"is_planning_move": phase == Phase.MOVE_SELECT,
		"is_previewing_move": not _preview_move_path.is_empty(),
		"has_locked_move_path": not _planned_move_path.is_empty(),
		"waypoint_count": _waypoints.size(),
		"is_user_turn": user_turn,
		"can_move": user_turn and phase == Phase.COMMAND and not _has_moved and not _input_locked,
		"can_confirm_move": can_confirm,
		"can_defend": user_turn and (phase == Phase.COMMAND or phase == Phase.ACTION_SELECT) and not _input_locked,
		"can_wait": user_turn and (phase == Phase.COMMAND or phase == Phase.ACTION_SELECT) and not _input_locked,
		"can_undo": user_turn and phase == Phase.ACTION_SELECT and _has_moved and not _input_locked,
		"can_cancel": user_turn and phase == Phase.MOVE_SELECT and not _input_locked,
	}


func phase_name() -> String:
	match phase:
		Phase.TURN_START: return "Turn Start"
		Phase.COMMAND: return "Choose an action"
		Phase.MOVE_SELECT: return "Preview movement"
		Phase.MOVING: return "Moving"
		Phase.ACTION_SELECT: return "Choose an action"
		Phase.TARGET_SELECT: return "Choose a target"
		Phase.ACTION_RESOLVE: return "Resolving action"
		Phase.TURN_END: return "Turn End"
	return ""


func _start_battle() -> void:
	if _controller == null:
		return
	_turn_order.clear()
	for child in _controller.get_children():
		if child is CharacterBody2D:
			_turn_order.append(child)
	if _turn_order.is_empty():
		return
	_turn_index = -1
	_start_next_turn()


func _start_next_turn() -> void:
	if _turn_order.is_empty():
		return

	_turn_index = (_turn_index + 1) % _turn_order.size()
	var attempts := 0
	while attempts < _turn_order.size() and not is_instance_valid(_turn_order[_turn_index]):
		_turn_index = (_turn_index + 1) % _turn_order.size()
		attempts += 1
	if attempts >= _turn_order.size():
		return

	current_actor = _turn_order[_turn_index]
	phase = Phase.TURN_START
	_has_moved = false
	_last_move_path.clear()
	_planned_move_path.clear()
	_preview_move_path.clear()
	_preview_destination = INVALID_GRID
	_waypoints.clear()
	_reachable_tiles.clear()
	_input_locked = false
	current_actor.set("is_defending", false)
	_turn_start_grid = _grid_for_actor(current_actor)
	_sync_turn_highlight()
	_focus_current_actor()

	phase = Phase.COMMAND
	_refresh_hud()
	if not _is_user_controlled(current_actor):
		_skip_enemy_placeholder_turn(current_actor)


func _skip_enemy_placeholder_turn(actor: Node) -> void:
	await get_tree().create_timer(ENEMY_PLACEHOLDER_TURN_SECONDS).timeout
	if current_actor != actor or phase != Phase.COMMAND:
		return
	_end_turn()


func _end_turn() -> void:
	if current_actor == null:
		return
	phase = Phase.TURN_END
	_input_locked = true
	_planned_move_path.clear()
	_preview_move_path.clear()
	_preview_destination = INVALID_GRID
	_waypoints.clear()
	_clear_manual_path_visuals()
	if current_actor.has_method("set_tactical_selected"):
		current_actor.call("set_tactical_selected", false)
	if current_actor.has_method("set_turn_active"):
		current_actor.call("set_turn_active", false)
	_refresh_hud()
	call_deferred("_start_next_turn")


func _grid_for_actor(actor: Node) -> Vector2i:
	if actor == null or _field == null or not actor.has_method("get_tile_world_position"):
		return Vector2i.ZERO
	var tile_world_position := Vector2(actor.call("get_tile_world_position"))
	return Vector2i(_field.call("world_to_grid", _field.to_local(tile_world_position)))


func _movement_for(actor: Node) -> int:
	if actor == null:
		return DEFAULT_MOV
	var key := String(actor.get("digimon_key")).to_lower()
	return maxi(0, int(_mov_by_key.get(key, DEFAULT_MOV)))


func _load_movement_database() -> void:
	_mov_by_key.clear()
	if not FileAccess.file_exists(DATABASE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATABASE_PATH))
	if not parsed is Array:
		return
	for entry in parsed:
		if not entry is Dictionary or not entry.has("name"):
			continue
		var key := String(entry["name"]).to_lower()
		_mov_by_key[key] = int(entry.get("MOV", DEFAULT_MOV))


func _is_user_controlled(actor: Node) -> bool:
	return actor != null and bool(actor.get("is_player_controlled"))


func _sync_turn_highlight() -> void:
	if _controller == null:
		return
	for child in _controller.get_children():
		if child is CharacterBody2D and child.has_method("set_turn_active"):
			child.call("set_turn_active", child == current_actor)


func _focus_current_actor() -> void:
	if current_actor == null:
		return
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.has_method("focus_on"):
		camera.call("focus_on", current_actor.global_position)


func _pointer_world_position() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		return camera.get_global_mouse_position()
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()


func _refresh_hud() -> void:
	var hud := get_node_or_null("../BattleUI/Root")
	if hud != null and hud.has_method("refresh_from_controller"):
		hud.call("refresh_from_controller")
