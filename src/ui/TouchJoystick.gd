extends Control
class_name TouchJoystick

signal direction_changed(direction: Vector2)

const DEADZONE := 0.16
const KNOB_LIMIT := 0.72

var _active_touch := -1
var _direction := Vector2.ZERO
var _mouse_active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(148.0, 148.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _active_touch != -1:
				return
			_active_touch = touch.index
			_update_from_global_position(touch.position)
			accept_event()
			return
		if touch.index == _active_touch:
			_active_touch = -1
			_set_direction(Vector2.ZERO)
			accept_event()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _active_touch:
			_update_from_global_position(drag.position)
			accept_event()
		return

	# Mouse support keeps the control easy to exercise from desktop browsers and
	# automated smoke tests without changing its touch-first behavior.
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		_mouse_active = button.pressed
		if _mouse_active:
			_update_from_global_position(button.position)
		else:
			_set_direction(Vector2.ZERO)
		accept_event()
		return

	if event is InputEventMouseMotion and _mouse_active:
		_update_from_global_position((event as InputEventMouseMotion).position)
		accept_event()


func force_release() -> void:
	_active_touch = -1
	_mouse_active = false
	_set_direction(Vector2.ZERO)


func get_direction() -> Vector2:
	return _direction


func _update_from_global_position(global_pos: Vector2) -> void:
	var local_pos := get_global_transform_with_canvas().affine_inverse() * global_pos
	var radius := maxf(1.0, minf(size.x, size.y) * 0.5)
	var raw := (local_pos - size * 0.5) / radius
	var length := raw.length()
	if length < DEADZONE:
		_set_direction(Vector2.ZERO)
		return
	var normalized_strength := clampf((length - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
	_set_direction(raw.normalized() * normalized_strength)


func _set_direction(next_direction: Vector2) -> void:
	next_direction = next_direction.limit_length(1.0)
	if _direction.is_equal_approx(next_direction):
		return
	_direction = next_direction
	direction_changed.emit(_direction)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.44
	var outline := Color(0.35, 0.86, 0.90, 0.72)
	var fill := Color(0.025, 0.045, 0.045, 0.72)
	var inner := Color(0.35, 0.86, 0.90, 0.16)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 48, outline, 2.0, true)
	draw_circle(center, radius * 0.56, inner)

	var knob_offset := _direction * radius * KNOB_LIMIT
	var knob_center := center + knob_offset
	draw_circle(knob_center, radius * 0.28, Color(0.35, 0.86, 0.90, 0.32))
	draw_arc(knob_center, radius * 0.28, 0.0, TAU, 32, Color(0.87, 0.98, 1.0, 0.92), 2.0, true)
