extends Camera2D

const MIN_ZOOM := 0.65
const MAX_ZOOM := 1.80
const INITIAL_ZOOM := 0.90
const ZOOM_STEP := 0.10
const PAN_SPEED := 1.0
const KEYBOARD_PAN_SPEED := 560.0
const PAN_OVERSCROLL := Vector2(96.0, 64.0)
const TOUCH_TAP_SLOP := 18.0
const PINCH_MIN_DISTANCE := 24.0

var _is_panning := false
var _has_pan_bounds := false
var _pan_bounds := Rect2()
var _touch_positions: Dictionary = {}
var _single_touch_index := -1
var _single_touch_start := Vector2.ZERO
var _single_touch_candidate := false
var _touch_gesture_had_multiple := false
var _last_pinch_center := Vector2.ZERO
var _last_pinch_distance := 0.0
var _shake_remaining := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _shake_rng := RandomNumberGenerator.new()


func _ready() -> void:
	zoom = Vector2.ONE * INITIAL_ZOOM
	_shake_rng.randomize()
	get_viewport().size_changed.connect(_clamp_to_pan_bounds)
	call_deferred("_refresh_pan_bounds")


func _physics_process(delta: float) -> void:
	_handle_zoom()
	_handle_keyboard_pan(delta)
	_update_shake(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_keyboard_zoom(event as InputEventKey)
		return

	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_is_panning = mouse_button.pressed
			get_viewport().set_input_as_handled()
			return

	if event is InputEventMouseMotion and _is_panning:
		var mouse_motion := event as InputEventMouseMotion
		global_position -= (mouse_motion.relative / zoom.x) * PAN_SPEED
		_clamp_to_pan_bounds()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
		return

	if event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func focus_on(world_position: Vector2) -> void:
	global_position = world_position
	_clamp_to_pan_bounds()


func shake(strength: float = 4.0, duration: float = 0.22) -> void:
	var next_strength := clampf(strength, 0.0, 10.0)
	var next_duration := clampf(duration, 0.05, 0.45)
	if _shake_remaining > 0.0:
		_shake_strength = maxf(_shake_strength, next_strength)
		_shake_duration = maxf(_shake_duration, next_duration)
		_shake_remaining = maxf(_shake_remaining, next_duration)
	else:
		_shake_strength = next_strength
		_shake_duration = next_duration
		_shake_remaining = next_duration


func zoom_in() -> void:
	_zoom_by_steps(1.0)


func zoom_out() -> void:
	_zoom_by_steps(-1.0)


func reset_view() -> void:
	_set_zoom_value(INITIAL_ZOOM)
	if _has_pan_bounds:
		global_position = _pan_bounds.position + _pan_bounds.size * 0.5
	_clamp_to_pan_bounds()


func _update_shake(delta: float) -> void:
	if _shake_remaining <= 0.0 or _shake_duration <= 0.0:
		offset = Vector2.ZERO
		return
	_shake_remaining = maxf(0.0, _shake_remaining - delta)
	var envelope := clampf(_shake_remaining / _shake_duration, 0.0, 1.0)
	envelope *= envelope
	offset = Vector2(
		_shake_rng.randf_range(-1.0, 1.0),
		_shake_rng.randf_range(-1.0, 1.0)
	) * _shake_strength * envelope
	if _shake_remaining <= 0.0:
		offset = Vector2.ZERO


func _refresh_pan_bounds() -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var field := main.get_node_or_null("Blocks")
	if field == null or not field.has_method("get_camera_pan_bounds"):
		return
	_pan_bounds = field.call("get_camera_pan_bounds")
	_has_pan_bounds = true
	_clamp_to_pan_bounds()


func _clamp_to_pan_bounds() -> void:
	if not _has_pan_bounds:
		return

	var viewport_half_world := get_viewport_rect().size * 0.5 / zoom.x
	var x_limits := _camera_axis_limits(
		_pan_bounds.position.x,
		_pan_bounds.end.x,
		viewport_half_world.x,
		PAN_OVERSCROLL.x
	)
	var y_limits := _camera_axis_limits(
		_pan_bounds.position.y,
		_pan_bounds.end.y,
		viewport_half_world.y,
		PAN_OVERSCROLL.y
	)
	global_position = Vector2(
		clampf(global_position.x, x_limits.x, x_limits.y),
		clampf(global_position.y, y_limits.x, y_limits.y)
	)


func _camera_axis_limits(
	min_edge: float,
	max_edge: float,
	viewport_half: float,
	overscroll: float
) -> Vector2:
	var min_center := min_edge + viewport_half - overscroll
	var max_center := max_edge - viewport_half + overscroll
	if min_center > max_center:
		var board_center := (min_edge + max_edge) * 0.5
		return Vector2(board_center - overscroll, board_center + overscroll)
	return Vector2(min_center, max_center)


func _handle_zoom() -> void:
	if Input.is_action_just_released("wheel_down"):
		_zoom_by_steps(-1.0, get_viewport().get_mouse_position())
	elif Input.is_action_just_released("wheel_up"):
		_zoom_by_steps(1.0, get_viewport().get_mouse_position())


func _handle_keyboard_zoom(key_event: InputEventKey) -> void:
	if not key_event.pressed or key_event.echo:
		return
	var physical_key := key_event.physical_keycode
	if physical_key == KEY_EQUAL or physical_key == KEY_KP_ADD:
		zoom_in()
		get_viewport().set_input_as_handled()
	elif physical_key == KEY_MINUS or physical_key == KEY_KP_SUBTRACT:
		zoom_out()
		get_viewport().set_input_as_handled()
	elif physical_key == KEY_HOME:
		reset_view()
		get_viewport().set_input_as_handled()


func _handle_keyboard_pan(delta: float) -> void:
	# Arrow keys/D-pad belong exclusively to UI focus navigation. Camera panning
	# stays on WASD, right-mouse drag and touch gestures.
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y += 1.0
	if direction == Vector2.ZERO:
		return
	global_position += direction.normalized() * (KEYBOARD_PAN_SPEED * delta / zoom.x)
	_clamp_to_pan_bounds()


func _handle_screen_touch(touch: InputEventScreenTouch) -> void:
	if touch.pressed:
		_touch_positions[touch.index] = touch.position
		if _touch_positions.size() == 1:
			_single_touch_index = touch.index
			_single_touch_start = touch.position
			_single_touch_candidate = true
			_touch_gesture_had_multiple = false
		else:
			_single_touch_candidate = false
			_touch_gesture_had_multiple = true
			_reset_pinch_reference()
			get_viewport().set_input_as_handled()
		return

	var was_tap_candidate := (
		_single_touch_candidate
		and not _touch_gesture_had_multiple
		and touch.index == _single_touch_index
		and touch.position.distance_to(_single_touch_start) <= TOUCH_TAP_SLOP
	)
	_touch_positions.erase(touch.index)
	if was_tap_candidate:
		_handle_touch_tap(touch.position)
		get_viewport().set_input_as_handled()
	if _touch_positions.size() < 2:
		_last_pinch_distance = 0.0
		_last_pinch_center = Vector2.ZERO
	if _touch_positions.is_empty():
		_single_touch_index = -1
		_single_touch_candidate = false
		_touch_gesture_had_multiple = false


func _handle_screen_drag(drag: InputEventScreenDrag) -> void:
	_touch_positions[drag.index] = drag.position
	if _touch_positions.size() >= 2:
		_single_touch_candidate = false
		_touch_gesture_had_multiple = true
		_apply_multi_touch_gesture()
		get_viewport().set_input_as_handled()
		return
	if drag.index != _single_touch_index:
		return
	if drag.position.distance_to(_single_touch_start) <= TOUCH_TAP_SLOP:
		return

	_single_touch_candidate = false
	var battle := _get_battle_controller()
	if battle != null and battle.has_method("is_manual_path_input_active") and bool(battle.call("is_manual_path_input_active")):
		if battle.has_method("handle_path_pointer_world"):
			battle.call("handle_path_pointer_world", _screen_to_world(drag.position))
		get_viewport().set_input_as_handled()
		return

	global_position -= drag.relative / zoom.x
	_clamp_to_pan_bounds()
	get_viewport().set_input_as_handled()


func _reset_pinch_reference() -> void:
	var pair := _first_two_touch_positions()
	if pair.size() < 2:
		_last_pinch_distance = 0.0
		_last_pinch_center = Vector2.ZERO
		return
	var first: Vector2 = pair[0]
	var second: Vector2 = pair[1]
	_last_pinch_center = (first + second) * 0.5
	_last_pinch_distance = first.distance_to(second)


func _apply_multi_touch_gesture() -> void:
	var pair := _first_two_touch_positions()
	if pair.size() < 2:
		return
	var first: Vector2 = pair[0]
	var second: Vector2 = pair[1]
	var center := (first + second) * 0.5
	var distance := first.distance_to(second)
	if _last_pinch_distance <= 0.0:
		_last_pinch_center = center
		_last_pinch_distance = distance
		return
	var center_delta := center - _last_pinch_center
	global_position -= center_delta / zoom.x
	if distance >= PINCH_MIN_DISTANCE and _last_pinch_distance >= PINCH_MIN_DISTANCE:
		var pinch_factor := distance / _last_pinch_distance
		_set_zoom_value(zoom.x * pinch_factor, center)
	_last_pinch_center = center
	_last_pinch_distance = distance
	_clamp_to_pan_bounds()


func _first_two_touch_positions() -> Array[Vector2]:
	var indices: Array = _touch_positions.keys()
	indices.sort()
	if indices.size() < 2:
		return []
	return [
		Vector2(_touch_positions[indices[0]]),
		Vector2(_touch_positions[indices[1]]),
	]


func _handle_touch_tap(screen_position: Vector2) -> void:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return
	var world_position := _screen_to_world(screen_position)
	var battle := main.get_node_or_null("BattleController")
	if battle != null and battle.has_method("handle_world_tap"):
		battle.call("handle_world_tap", world_position)
		return

	var field := main.get_node_or_null("Blocks")
	var controller := main.get_node_or_null("DigimonController")
	if field == null or controller == null or not field.has_method("select_tile_from_world"):
		return
	if not bool(field.call("select_tile_from_world", world_position)):
		return
	var tile_world_position := Vector2(field.get("selectedTile"))
	for child in controller.get_children():
		if child is CharacterBody2D and bool(child.get("is_selected")):
			if child.has_method("handle_touch_tap"):
				child.call("handle_touch_tap", tile_world_position, world_position)
			return
	for child in controller.get_children():
		if child is CharacterBody2D and child.has_method("handle_touch_tap"):
			if bool(child.call("handle_touch_tap", tile_world_position, world_position)):
				return


func _get_battle_controller() -> Node:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return null
	return main.get_node_or_null("BattleController")


func _screen_to_world(screen_position: Vector2) -> Vector2:
	var viewport_center := get_viewport_rect().size * 0.5
	return global_position + (screen_position - viewport_center) / zoom.x


func _zoom_by_steps(direction: float, anchor_screen := Vector2(-1.0, -1.0)) -> void:
	_set_zoom_value(zoom.x + ZOOM_STEP * direction, anchor_screen)


func _set_zoom_value(target_zoom: float, anchor_screen := Vector2(-1.0, -1.0)) -> void:
	var old_zoom := zoom.x
	var clamped_zoom := clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(old_zoom, clamped_zoom):
		return
	if anchor_screen.x >= 0.0 and anchor_screen.y >= 0.0:
		var viewport_center := get_viewport_rect().size * 0.5
		var anchor_offset := anchor_screen - viewport_center
		var world_anchor := global_position + anchor_offset / old_zoom
		zoom = Vector2.ONE * clamped_zoom
		global_position = world_anchor - anchor_offset / clamped_zoom
	else:
		zoom = Vector2.ONE * clamped_zoom
	_clamp_to_pan_bounds()
