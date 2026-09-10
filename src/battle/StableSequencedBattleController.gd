extends "res://src/battle/SequencedBattleController.gd"

const KEYBOARD_INVALID_GRID := Vector2i(-9997, -9997)
const NAV_DIRECTION_THRESHOLD := 0.05
const NAV_ANGLE_WEIGHT := 2.2

var _keyboard_move_grid := KEYBOARD_INVALID_GRID
var _keyboard_target: Node = null


# Combat/timeline events must use the persistent Digimon instance id. Godot's
# Object instance id is process-local and is a poor identifier to pass between
# battle domain and presentation code, especially on Web builds.
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


# Recovery is no longer previewed by merely hovering/focusing a command. The
# previous behavior rebuilt the turn timeline on pointer hover and made it
# appear to blink/change before the player had actually chosen an action.
func preview_skill_recovery(_skill_id: String) -> void:
	_preview_recovery_cost = _pending_recovery_cost


func preview_basic_attack_recovery() -> void:
	_preview_recovery_cost = _pending_recovery_cost


func clear_action_recovery_preview() -> void:
	_preview_recovery_cost = _pending_recovery_cost


func begin_move_selection() -> void:
	_keyboard_target = null
	_keyboard_move_grid = KEYBOARD_INVALID_GRID
	super.begin_move_selection()
	if phase == Phase.MOVE_SELECT and current_actor != null:
		_keyboard_move_grid = _turn_start_grid


func cancel_move_selection() -> void:
	_keyboard_move_grid = KEYBOARD_INVALID_GRID
	super.cancel_move_selection()


func handle_world_tap(world_position: Vector2) -> bool:
	# Switching back to pointer/touch input should immediately relinquish any
	# keyboard-only cursor so the two input modes never fight each other.
	_keyboard_move_grid = KEYBOARD_INVALID_GRID
	_keyboard_target = null
	return super.handle_world_tap(world_position)


func _begin_action_targeting(action: Dictionary) -> bool:
	_keyboard_target = null
	return super._begin_action_targeting(action)


func _clear_action_selection(reset_preview: bool) -> void:
	_keyboard_target = null
	super._clear_action_selection(reset_preview)


func _on_hovered_digimon_changed(digimon_key: String) -> void:
	# Mouse hover takes ownership of the target preview as soon as the pointer
	# enters/leaves a Digimon, preserving seamless switching between inputs.
	_keyboard_target = null
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

	# Movement selection is a grid operation, not a generic screen-space nearest
	# neighbour search. On our diamond projection, each keyboard direction maps
	# to exactly one edge-connected isometric grid step. Repeating the same key
	# therefore stays on one straight isometric axis and never hops between rows.
	var step := keyboard_grid_step_for_direction(screen_direction)
	if step == Vector2i.ZERO:
		return false
	var candidate := origin_grid + step

	# The origin is always a valid cursor destination so players can walk the
	# keyboard cursor back to where they started. Other destinations must be in
	# the actual reachable set; blocked/out-of-range neighbours stop the cursor
	# instead of making it jump to another lane behind the obstacle.
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


# The board uses the classic 2:1 isometric projection:
#   grid -X = screen up-left     grid -Y = screen up-right
#   grid +Y = screen down-left   grid +X = screen down-right
# Treat the four arrows/D-pad directions as the four edges of that diamond.
# This is intentionally different from a Cartesian top/down/left/right map.
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

	var candidates := _valid_keyboard_targets()
	if candidates.is_empty():
		return false

	var origin_actor: Node = _keyboard_target if _keyboard_target != null and is_instance_valid(_keyboard_target) else current_actor
	var candidate := _find_directional_actor(origin_actor, candidates, screen_direction)
	if candidate == null:
		# On the first navigation input, always give the player a useful target
		# even when none happens to lie strongly in that exact screen direction.
		if _keyboard_target == null:
			candidate = _nearest_actor(current_actor, candidates)
		else:
			return false
	if candidate == null:
		return false

	_keyboard_target = candidate
	_selected_target = null
	_hover_target = candidate
	_update_combat_preview(candidate, false)
	_refresh_hud()
	return true


func keyboard_confirm_target() -> bool:
	if phase != Phase.TARGET_SELECT or _input_locked or _selected_action.is_empty():
		return false
	if _keyboard_target == null or not is_instance_valid(_keyboard_target):
		if not keyboard_navigate_target(Vector2.ZERO):
			return false
	if _keyboard_target == null or not _targeting_system.is_valid_target(_field, current_actor, _keyboard_target, _selected_action):
		return false

	_selected_target = _keyboard_target
	_keyboard_target = null
	_hover_target = null
	_update_combat_preview(_selected_target, true)
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
