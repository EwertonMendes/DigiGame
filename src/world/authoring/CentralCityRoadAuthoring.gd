@tool
extends Line2D
class_name CentralCityRoadAuthoring

@export var road_id := ""
@export var level_id := "upper_civic"
@export var width_grid := 3.0:
	set(value):
		width_grid = maxf(0.5, value)
		_refresh_editor_style()
@export var surface := "dark"
@export var tint := Color(1.48, 1.50, 1.54, 1.0):
	set(value):
		tint = value
		_refresh_editor_style()
@export var border_width_grid := 0.12
@export var border_color := Color(0.31, 0.33, 0.35, 1.0)
@export var editor_elevation_px := 48.0


func _ready() -> void:
	_refresh_editor_style()


func _refresh_editor_style() -> void:
	if not Engine.is_editor_hint():
		return
	width = width_grid * 18.0
	default_color = Color(
		clampf(0.24 * tint.r, 0.0, 1.0),
		clampf(0.27 * tint.g, 0.0, 1.0),
		clampf(0.30 * tint.b, 0.0, 1.0),
		0.78
	)
	antialiased = false
