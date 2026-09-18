extends Control
class_name DigiLabWorkspaceBackdrop

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.008, 0.024, 0.036, 1.0))

	var center := size * Vector2(0.68, 0.46)
	var radius := minf(size.x, size.y) * 0.34
	for index in range(5):
		var ring_radius := radius * (0.38 + float(index) * 0.15)
		draw_arc(center, ring_radius, 0.0, TAU, 96, Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.028 + float(index) * 0.008), 1.0, true)

	var spacing := 64.0
	var x := fmod(size.x * 0.12, spacing)
	while x < size.x:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.026), 1.0)
		x += spacing
	var y := fmod(size.y * 0.08, spacing)
	while y < size.y:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.022), 1.0)
		y += spacing

	var horizon := size.y * 0.73
	for index in range(9):
		var t := float(index) / 8.0
		var yy := lerpf(horizon, size.y, t * t)
		draw_line(Vector2(0.0, yy), Vector2(size.x, yy), Color(V2.BLUE.r, V2.BLUE.g, V2.BLUE.b, 0.035), 1.0)

	for index in range(8):
		var t := float(index) / 7.0
		var top_x := lerpf(size.x * 0.24, size.x * 0.76, t)
		var bottom_x := lerpf(-size.x * 0.08, size.x * 1.08, t)
		draw_line(Vector2(top_x, horizon), Vector2(bottom_x, size.y), Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.035), 1.0)

	draw_rect(Rect2(0.0, 0.0, size.x, size.y), Color(0.0, 0.0, 0.0, 0.14))
