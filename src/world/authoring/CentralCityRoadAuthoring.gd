@tool
extends Line2D
class_name CentralCityRoadAuthoring

@export var road_id := ""
@export var level_id := "upper_civic"
@export var width_grid := 3.0
@export_enum("main", "dark", "stone_soft", "tech_teal", "tech_blue", "tech_purple", "market", "training", "grass", "water") var surface := "dark"
@export var tint := Color(1.48, 1.50, 1.54, 1.0)
@export var border_width_grid := 0.12
@export var border_color := Color(0.31, 0.33, 0.35, 1.0)
@export var editor_elevation_px := 48.0


func _ready() -> void:
	if Engine.is_editor_hint():
		width = 4.0
		default_color = Color(1.0, 0.69, 0.18, 0.92)
		antialiased = false
