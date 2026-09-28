@tool
extends Line2D
class_name CentralCityBoundaryAuthoring

@export var boundary_id := "south_terrace_break"
@export var upper_level := "upper_civic"
@export var lower_level := "south_terrace"
@export var lower_threshold_grid_y := 19.5
@export var editor_color := Color(1.0, 0.65, 0.16, 0.75):
	set(value):
		editor_color = value
		if Engine.is_editor_hint():
			default_color = value


func _ready() -> void:
	if Engine.is_editor_hint():
		width = 5.0
		default_color = editor_color
		antialiased = false
