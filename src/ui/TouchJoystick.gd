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
	set_process_input(true)
	queue_redraw()


# Touch is captured at viewport-input level instead of relying on GUI hit
# dispatch. In mobile Web exports Godot may synthesize mouse input from touch,
# and relying only on _gui_input made held touches on the old controls fragile.
# Claiming one finger explicitly also lets the player slide outside the visual
# ring without losing movement until that same finger is released.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _active_touch != -1 or not _contains_viewport_point(touch.position):
				return
			_active_touch = touch.index
			_update_from_viewport_position(touch.position)
			get_viewport().set_input_as_handled()
			return
		if touch.index == _active_touch:
			_active_touch = -1
			_set_direction(Vector2.ZERO)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _active_touch:
			return
		_update_from_viewport_position(drag.position)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	# Mouse support keeps the joystick testable on desktop and remains useful for
	# hybrid/touch-laptop browsers. ScreenTouch/ScreenDrag are handled in _input
	# above so touch-to-mouse emulation can never swallow the joystick gesture.
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		_mouse_active = button.pressed
		if _mouse_active:
			_update_from_local_position(button.position)
		else:
			_set_direction(Vector2.ZERO)
		accept_event()
		return

	if event is InputEventMouseMotion and _mouse_active:
		_update_from_local_position((event as InputEventMouseMotion).position)
		accept_event()


func force_release() -> void:
	_active_touch = -1
	_mouse_active = false
	_set_direction(Vector2.ZERO)


func get_direction() -> Vector2:
	return _direction


func _contains_viewport_point(viewport_pos: Vector2) -> bool:
	var local_pos := get_global_transform_with_canvas().affine_inverse() * viewport_pos
	return Rect2(Vector2.ZERO, size).has_point(local_pos)


func _update_from_viewport_position(viewport_pos: Vector2) -> void:
	var local_pos := get_global_transform_with_canvas().affine_inverse() * viewport_pos
	_update_from_local_position(local_pos)


func _update_from_local_position(local_pos: Vector2) -> void:
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
