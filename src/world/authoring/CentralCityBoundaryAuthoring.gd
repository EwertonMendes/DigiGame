@tool
extends Path2D
class_name CentralCityBoundaryAuthoring

@export var boundary_id := "south_terrace_break"
@export var upper_level := "upper_civic"
@export var lower_level := "south_terrace"
@export var lower_threshold_grid_y := 19.5
@export var editor_color := Color(1.0, 0.65, 0.16, 0.75)


func _ready() -> void:
	if curve != null and not curve.changed.is_connected(_on_curve_changed):
		curve.changed.connect(_on_curve_changed)
	queue_redraw()


func _on_curve_changed() -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or curve == null:
		return
	var points := curve.get_baked_points()
	if points.size() >= 2:
		draw_polyline(points, editor_color, 5.0, false)
