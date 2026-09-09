extends Camera2D

const CAMERA_MOVEMENT_FORCE := 1.75
const MIN_ZOOM := 0.65
const MAX_ZOOM := 1.80
const INITIAL_ZOOM := 0.90
const ZOOM_STEP := 0.10


func _ready() -> void:
	zoom = Vector2.ONE * INITIAL_ZOOM


func _physics_process(_delta: float) -> void:
	_handle_zoom()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if mouse_motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			position -= (mouse_motion.relative / zoom) / CAMERA_MOVEMENT_FORCE


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
