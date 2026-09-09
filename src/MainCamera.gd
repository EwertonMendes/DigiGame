extends Camera2D

const MIN_ZOOM := 0.65
const MAX_ZOOM := 1.80
const INITIAL_ZOOM := 0.90
const ZOOM_STEP := 0.10
const PAN_SPEED := 1.0

var _is_panning := false
var _has_pan_bounds := false
var _pan_bounds := Rect2()


func _ready() -> void:
	zoom = Vector2.ONE * INITIAL_ZOOM
	call_deferred("_refresh_pan_bounds")


func _physics_process(_delta: float) -> void:
	_handle_zoom()


func _unhandled_input(event: InputEvent) -> void:
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


func focus_on(world_position: Vector2) -> void:
	global_position = world_position
	_clamp_to_pan_bounds()


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

	global_position = Vector2(
		clampf(global_position.x, _pan_bounds.position.x, _pan_bounds.end.x),
		clampf(global_position.y, _pan_bounds.position.y, _pan_bounds.end.y)
	)


func _handle_zoom() -> void:
	var target_zoom := zoom.x
	if Input.is_action_just_released("wheel_down"):
		target_zoom -= ZOOM_STEP
	elif Input.is_action_just_released("wheel_up"):
		target_zoom += ZOOM_STEP
	else:
		return

	target_zoom = clampf(target_zoom, MIN_ZOOM, MAX_ZOOM)
	zoom = Vector2.ONE * target_zoom
	_clamp_to_pan_bounds()
