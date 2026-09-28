@tool
extends Polygon2D
class_name CentralCitySurfaceRegion

@export var region_id := ""
@export var layer_id := "district_courts"
@export var level_id := "upper_civic"
@export_enum("main", "dark", "stone_soft", "tech_teal", "tech_blue", "tech_purple", "market", "training", "grass", "water") var surface := "stone_soft"
@export var tint := Color(1.0, 1.0, 1.0, 1.0)
@export var border_width := 1.0
@export var border_color := Color(0.45, 0.46, 0.47, 1.0)
@export var editor_elevation_px := 48.0


func _ready() -> void:
	if Engine.is_editor_hint():
		color = Color(tint.r, tint.g, tint.b, 0.20)
