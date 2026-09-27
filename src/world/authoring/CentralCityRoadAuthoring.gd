@tool
extends Path2D
class_name CentralCityRoadAuthoring

@export var road_id := ""
@export var level_id := "upper_civic"
@export var width_grid := 3.0:
	set(value):
		width_grid = maxf(0.5, value)
		queue_redraw()
@export var surface := "dark"
@export var tint := Color(1.48, 1.50, 1.54, 1.0)
@export var border_width_grid := 0.12
@export var border_color := Color(0.31, 0.33, 0.35, 1.0)
@export var editor_elevation_px := 48.0:
	set(value):
		editor_elevation_px = maxf(0.0, value)
		queue_redraw()


func _ready() -> void:
	if curve != null and not curve.changed.is_connected(_on_curve_changed):
		curve.changed.connect(_on_curve_changed)
	queue_redraw()


func _on_curve_changed() -> void:
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint() or curve == null or curve.point_count < 2:
		return
	var points := curve.get_baked_points()
	if points.size() < 2:
		return
	var elevated := PackedVector2Array()
	for point: Vector2 in points:
		elevated.append(point + Vector2(0.0, -editor_elevation_px))
	draw_polyline(elevated, border_color, width_grid * 18.0 + 4.0, false)
	draw_polyline(elevated, Color(0.24, 0.27, 0.30, 0.78), width_grid * 18.0, false)
