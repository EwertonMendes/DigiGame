extends Camera2D

var MIN_ZOOM = Vector2(1,1)
var MAX_ZOOM = Vector2(4,4)

func zoom():
	var currentZoom = get_zoom()
	if Input.is_action_just_released('wheel_down') and currentZoom >= MIN_ZOOM:
		set_zoom(currentZoom - Vector2(0.25, 0.25))
	if Input.is_action_just_released('wheel_up') and currentZoom <= MAX_ZOOM:
		set_zoom(currentZoom + Vector2(0.25, 0.25))

func _physics_process(delta):
	zoom()
