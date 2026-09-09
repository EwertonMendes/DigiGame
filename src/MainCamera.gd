extends Camera2D

const CAMERA_MOVEMENT_FORCE := 5.0
const MIN_ZOOM := Vector2(1.0, 1.0)
const MAX_ZOOM := Vector2(4.0, 4.0)
const INITIAL_ZOOM := Vector2(2.0, 2.0)
const ZOOM_FACTOR := Vector2(0.25, 0.25)

func _ready() -> void:
	zoom = INITIAL_ZOOM

func _physics_process(_delta: float) -> void:
	handle_zoom()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if mouse_motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			position -= mouse_motion.relative * zoom / CAMERA_MOVEMENT_FORCE

func handle_zoom() -> void:
	var current_zoom := zoom
	if Input.is_action_just_released("wheel_down"):
		var next_zoom := current_zoom - ZOOM_FACTOR
		zoom = Vector2(maxf(next_zoom.x, MIN_ZOOM.x), maxf(next_zoom.y, MIN_ZOOM.y))
	elif Input.is_action_just_released("wheel_up"):
		var next_zoom := current_zoom + ZOOM_FACTOR
		zoom = Vector2(minf(next_zoom.x, MAX_ZOOM.x), minf(next_zoom.y, MAX_ZOOM.y))
