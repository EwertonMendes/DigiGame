extends RefCounted
class_name DigiAnalogNavigationGate

var vertical_press_threshold := 0.62
var vertical_release_threshold := 0.34
var horizontal_press_threshold := 0.62
var horizontal_release_threshold := 0.34
var trigger_press_threshold := 0.55
var trigger_release_threshold := 0.25

var _vertical_state := 0
var _horizontal_state := 0
var _left_trigger_down := false
var _right_trigger_down := false


func reset() -> void:
	_vertical_state = 0
	_horizontal_state = 0
	_left_trigger_down = false
	_right_trigger_down = false


func vertical_step(value: float) -> int:
	if absf(value) <= vertical_release_threshold:
		_vertical_state = 0
		return 0

	var direction := 0
	if value <= -vertical_press_threshold:
		direction = -1
	elif value >= vertical_press_threshold:
		direction = 1
	if direction == 0 or direction == _vertical_state:
		return 0
	_vertical_state = direction
	return direction


func horizontal_step(value: float) -> int:
	if absf(value) <= horizontal_release_threshold:
		_horizontal_state = 0
		return 0

	var direction := 0
	if value <= -horizontal_press_threshold:
		direction = -1
	elif value >= horizontal_press_threshold:
		direction = 1
	if direction == 0 or direction == _horizontal_state:
		return 0
	_horizontal_state = direction
	return direction


func trigger_step(axis: JoyAxis, value: float) -> int:
	if axis != JOY_AXIS_TRIGGER_LEFT and axis != JOY_AXIS_TRIGGER_RIGHT:
		return 0
	var left := axis == JOY_AXIS_TRIGGER_LEFT
	var was_down := _left_trigger_down if left else _right_trigger_down
	if not was_down and value >= trigger_press_threshold:
		if left:
			_left_trigger_down = true
		else:
			_right_trigger_down = true
		return -1 if left else 1
	if was_down and value <= trigger_release_threshold:
		if left:
			_left_trigger_down = false
		else:
			_right_trigger_down = false
	return 0
