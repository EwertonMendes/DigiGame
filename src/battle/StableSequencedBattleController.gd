extends "res://src/battle/SequencedBattleController.gd"

const KEYBOARD_INVALID_GRID := Vector2i(-9997, -9997)
const NAV_DIRECTION_THRESHOLD := 0.05
const NAV_ANGLE_WEIGHT := 2.2

var _keyboard_move_grid := KEYBOARD_INVALID_GRID
var _keyboard_aim_grid := KEYBOARD_INVALID_GRID
var _keyboard_target: Node = null


func _instance_id(actor: Node) -> String:
	if actor == null or not is_instance_valid(actor):
		return ""
	if actor.has_method("get_digimon_instance_id"):
		var stable_id: String = String(actor.call("get_digimon_instance_id")).strip_edges()
		if not stable_id.is_empty():
			return stable_id
	return str(actor.get_instance_id())


func focus_actor_by_instance_id(instance_id: String) -> void:
	if instance_id.is_empty():
		return
	for actor: Node in _turn_order:
		if actor == null or not is_instance_valid(actor):
			continue
		if _instance_id(actor) != instance_id:
			continue
		var camera := get_viewport().get_camera_2d()
		if camera != null and camera.has_method("focus_on"):
			camera.call("focus_on", actor.global_position)
		return


func preview_skill_recovery(_skill_id: String) -> void:
	_preview_recovery_cost = _pending_recovery_cost


func preview_basic_attack_recovery() -> void:
	_preview_recovery_cost = _pending_recovery_cost


func clear_action_recovery_preview() -> void:
	_preview_recovery_cost = _pending_recovery_cost


func begin_move_selection() -> void:
	_keyboard_target = null
	_keyboard_aim_grid = KEYBOARD_INVALID_GRID
	_keyboard_move_grid = KEYBOARD_INVALID_GRID
	super.begin_move_selection()
	if phase == Phase.MOVE_SELECT and current_actor != null:
		_keyboard_move_grid = _turn_start_grid


func cancel_move_selection() -> void:
	_keyboard_move_grid = KEYBOARD_INVALID_GRID
	super.cancel_move_selection()


func handle_world_tap(world_position: Vector2) -> bool:
	_keyboard_move_grid = KEYBOARD_INVALID_GRID
	_keyboard_aim_grid = KEYBOARD_INVALID_GRID
	_keyboard_target = null
	return super.handle_world_tap(world_position)


func _begin_action_targeting(action: Dictionary) -> bool:
	_keyboard_target = null
	_keyboard_aim_grid = KEYBOARD_INVALID_GRID
	return super._begin_action_targeting(action)


func _clear_action_selection(reset_preview: bool) -> void:
	_keyboard_target = null
	_keyboard_aim_grid = KEYBOARD_INVALID_GRID
	super._clear_action_selection(reset_preview)


func _on_hovered_digimon_changed(digimon_key: String) -> void:
	_keyboard_target = null
	_keyboard_aim_grid = KEYBOARD_INVALID_GRID
	super._on_hovered_digimon_changed(digimon_key)


func keyboard_navigate_move(screen_direction: Vector2) -> bool:
	if (
		phase != Phase.MOVE_SELECT
		or _input_locked
		or current_actor == null
		or not _is_user_controlled(current_actor)
		or _field == null
		or _reachable_tiles.is_empty()
	):
		return false

	var origin_grid := _keyboard_move_grid
	if origin_grid == KEYBOARD_INVALID_GRID or (origin_grid != _turn_start_grid and not _reachable_tiles.has(origin_grid)):
		origin_grid = _turn_start_grid

	var step := keyboard_grid_step_for_direction(screen_direction)
	if step == Vector2i.ZERO:
		return false
	var candidate := origin_grid + step

	if candidate == _turn_start_grid:
		_keyboard_move_grid = candidate
		_planned_move_path.clear()
		_waypoints.clear()
		_clear_preview_state()
		_refresh_movement_plan_state()
		return true
	if not _reachable_tiles.has(candidate):
		return false

	_planned_move_path.clear()
	_waypoints.clear()
	_clear_preview_state()
	_set_preview_destination(candidate)
	if _preview_destination != candidate or _preview_move_path.is_empty():
		return false
	_keyboard_move_grid = candidate
	return true


func keyboard_grid_step_for_direction(screen_direction: Vector2) -> Vector2i:
	if screen_direction.length_squared() <= 0.001:
		return Vector2i.ZERO
	var x := screen_direction.x
	var y := screen_direction.y
	if absf(x) > absf(y):
		return Vector2i(0, -1) if x > 0.0 else Vector2i(0, 1)
	return Vector2i(1, 0) if y > 0.0 else Vector2i(-1, 0)


func keyboard_confirm_move() -> bool:
	if phase != Phase.MOVE_SELECT or _input_locked or current_actor == null:
		return false
	var destination := _keyboard_move_grid
	if destination == KEYBOARD_INVALID_GRID:
		destination = _preview_destination
	if destination == KEYBOARD_INVALID_GRID or destination == _turn_start_grid:
		return false

	if _preview_destination != destination:
		_planned_move_path.clear()
		_waypoints.clear()
		_clear_preview_state()
		_set_preview_destination(destination)
	if _preview_destination != destination or _preview_move_path.is_empty():
		return false

	if not _lock_move_destination(destination) or _planned_move_path.is_empty():
		return false
	_keyboard_move_grid = KEYBOARD_INVALID_GRID
	confirm_move_path()
	return true


func keyboard_navigate_target(screen_direction: Vector2) -> bool:
	if (
		phase != Phase.TARGET_SELECT
		or _input_locked
		or current_actor == null
		or _selected_action.is_empty()
		or not _is_user_controlled(current_actor)
	):
		return false

	if _targeting_system.selection_mode(_selected_action) == "unit":
		return _keyboard_navigate_unit_target(screen_direction)
	return _keyboard_navigate_aim_grid(screen_direction)


func _keyboard_navigate_unit_target(screen_direction: Vector2) -> bool:
	var candidates := _valid_keyboard_targets()
	if candidates.is_empty():
		return false
	var origin_actor: Node = _keyboard_target if _keyboard_target != null and is_instance_valid(_keyboard_target) else current_actor
	var candidate := _find_directional_actor(origin_actor, candidates, screen_direction)
	if candidate == null:
		if _keyboard_target == null:
			candidate = _nearest_actor(current_actor, candidates)
		else:
			return false
	if candidate == null:
		return false

	_keyboard_target = candidate
	_keyboard_aim_grid = _grid_for_actor(candidate)
	_selected_target = null
	_hover_target = candidate
	_update_combat_preview(candidate, false)
	_refresh_hud()
	return true


func _keyboard_navigate_aim_grid(screen_direction: Vector2) -> bool:
	var candidates := _valid_keyboard_aim_grids()
	if candidates.is_empty():
		return false
	var origin_grid := _keyboard_aim_grid
	if origin_grid == KEYBOARD_INVALID_GRID or not candidates.has(origin_grid):
		origin_grid = _grid_for_actor(current_actor)
	var candidate := _find_directional_grid(origin_grid, candidates, screen_direction)
	if candidate == KEYBOARD_INVALID_GRID:
		if _keyboard_aim_grid == KEYBOARD_INVALID_GRID:
			candidate = _nearest_aim_grid(_grid_for_actor(current_actor), candidates)
		else:
			return false
	if candidate == KEYBOARD_INVALID_GRID:
		return false

	_keyboard_aim_grid = candidate
	var targets := _targets_for_aim(candidate)
	_keyboard_target = targets[0] if not targets.is_empty() else null
	_selected_target = null
	_hover_target = _keyboard_target
	_update_combat_preview_for_grid(candidate, _keyboard_target, false)
	_refresh_hud()
	return true


func keyboard_confirm_target() -> bool:
	if phase != Phase.TARGET_SELECT or _input_locked or _selected_action.is_empty():
		return false

	if _targeting_system.selection_mode(_selected_action) == "unit":
		if _keyboard_target == null or not is_instance_valid(_keyboard_target):
			if not keyboard_navigate_target(Vector2.ZERO):
				return false
		if _keyboard_target == null or not _targeting_system.is_valid_target(_field, current_actor, _keyboard_target, _selected_action):
			return false
		_selected_target = _keyboard_target
		_selected_target_grid = _grid_for_actor(_keyboard_target)
	else:
		if _keyboard_aim_grid == KEYBOARD_INVALID_GRID:
			if not keyboard_navigate_target(Vector2.ZERO):
				return false
		if _keyboard_aim_grid == KEYBOARD_INVALID_GRID or not _targeting_system.is_valid_aim_grid(_field, current_actor, _selected_action, _keyboard_aim_grid):
			return false
		var targets := _targets_for_aim(_keyboard_aim_grid)
		if targets.is_empty():
			return false
		_selected_target_grid = _keyboard_aim_grid
		_selected_target = targets[0]

	_keyboard_target = null
	_keyboard_aim_grid = KEYBOARD_INVALID_GRID
	_hover_target = null
	_update_combat_preview_for_grid(_effective_selected_grid(), _selected_target, true)
	_refresh_hud()
	return confirm_selected_action()


func get_keyboard_navigation_target() -> Node:
	if _keyboard_target != null and is_instance_valid(_keyboard_target):
		return _keyboard_target
	return null


func _valid_keyboard_targets() -> Array[Node]:
	var result: Array[Node] = []
	for actor: Node in _turn_order:
		if actor == null or not is_instance_valid(actor):
			continue
		if _targeting_system.is_valid_target(_field, current_actor, actor, _selected_action):
			result.append(actor)
	return result


func _valid_keyboard_aim_grids() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for grid: Vector2i in _targeting_system.grids_in_range(_field, current_actor, _selected_action):
		if not _targets_for_aim(grid).is_empty():
			result.append(grid)
	return result


func _find_directional_actor(origin_actor: Node, candidates: Array[Node], direction: Vector2) -> Node:
	var origin_node := origin_actor as Node2D
	if origin_node == null:
		return null
	var best: Node = null
	var best_score := 1.0e20
	for actor: Node in candidates:
		if actor == origin_actor or actor == null or not is_instance_valid(actor):
			continue
		var actor_node := actor as Node2D
		if actor_node == null:
			continue
		var score := _directional_score(actor_node.global_position - origin_node.global_position, direction)
		if score < best_score:
			best_score = score
			best = actor
	return best


func _find_directional_grid(origin_grid: Vector2i, candidates: Array[Vector2i], direction: Vector2) -> Vector2i:
	if _field == null:
		return KEYBOARD_INVALID_GRID
	var origin_world := Vector2(_field.call("grid_to_world", origin_grid))
	var best := KEYBOARD_INVALID_GRID
	var best_score := 1.0e20
	for grid: Vector2i in candidates:
		if grid == origin_grid:
			continue
		var world := Vector2(_field.call("grid_to_world", grid))
		var score := _directional_score(world - origin_world, direction)
		if score < best_score:
			best_score = score
			best = grid
	return best


func _nearest_actor(origin_actor: Node, candidates: Array[Node]) -> Node:
	var origin_node := origin_actor as Node2D
	if origin_node == null:
		return candidates[0] if not candidates.is_empty() else null
	var best: Node = null
	var best_distance := 1.0e20
	for actor: Node in candidates:
		if actor == null or not is_instance_valid(actor):
			continue
		var actor_node := actor as Node2D
		if actor_node == null:
			continue
		var distance := actor_node.global_position.distance_squared_to(origin_node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = actor
	return best


func _nearest_aim_grid(origin_grid: Vector2i, candidates: Array[Vector2i]) -> Vector2i:
	if candidates.is_empty() or _field == null:
		return KEYBOARD_INVALID_GRID
	var origin_world := Vector2(_field.call("grid_to_world", origin_grid))
	var best := KEYBOARD_INVALID_GRID
	var best_distance := 1.0e20
	for grid: Vector2i in candidates:
		var world := Vector2(_field.call("grid_to_world", grid))
		var distance := world.distance_squared_to(origin_world)
		if distance < best_distance:
			best_distance = distance
			best = grid
	return best


func _directional_score(delta: Vector2, direction: Vector2) -> float:
	var distance := delta.length()
	if distance <= 0.001:
		return 1.0e20
	if direction.length_squared() <= 0.001:
		return distance
	var alignment := delta.normalized().dot(direction.normalized())
	if alignment <= NAV_DIRECTION_THRESHOLD:
		return 1.0e20
	return distance * (1.0 + (1.0 - alignment) * NAV_ANGLE_WEIGHT)
