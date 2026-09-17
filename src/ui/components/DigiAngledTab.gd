extends Button
class_name DigiAngledTab

const V2 = preload("res://src/ui/components/DigiUiTheme.gd")
const SLANT := 18.0

var _active := false


func set_active(active: bool) -> void:
	_active = active
	queue_redraw()


func _ready() -> void:
	for state in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	if size.x <= SLANT * 2.0 or size.y <= 0.0:
		return
	var points := _shape_points()
	var highlighted := is_hovered() or has_focus()
	var fill := Color(0.055, 0.155, 0.190, 0.98) if _active else Color(0.035, 0.075, 0.105, 0.94)
	var edge := Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.95) if _active else Color(V2.CYAN.r, V2.CYAN.g, V2.CYAN.b, 0.35)
	if highlighted:
		fill = Color(0.075, 0.195, 0.230, 0.98)
		edge = V2.CYAN
	draw_colored_polygon(points, fill)
	var outline := PackedVector2Array(points)
	outline.append(points[0])
	draw_polyline(outline, edge, 2.0, true)
	draw_line(Vector2(SLANT + 6.0, 4.0), Vector2(size.x - 7.0, 4.0), Color(V2.WHITE.r, V2.WHITE.g, V2.WHITE.b, 0.16), 1.0, true)


func _has_point(point: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(point, _shape_points())


func _shape_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(SLANT, 1.0),
		Vector2(size.x - 1.0, 1.0),
		Vector2(size.x - SLANT - 1.0, size.y - 1.0),
		Vector2(1.0, size.y - 1.0),
	])
