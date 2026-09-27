@tool
extends Line2D
class_name CentralCityRoadAuthoring

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")

@export var road_id := ""
@export var level_id := "upper_civic"
@export var width_grid := 3.0:
	set(value):
		width_grid = maxf(0.5, value)
		_refresh_editor_style()
@export_enum("main", "dark", "stone_soft", "tech_teal", "tech_blue", "tech_purple", "market", "training", "grass", "water") var surface := "dark":
	set(value):
		surface = value
		_refresh_editor_style()
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
	var base := CITY.surface_base_color(surface)
	default_color = Color(
		clampf(base.r * tint.r, 0.0, 1.0),
		clampf(base.g * tint.g, 0.0, 1.0),
		clampf(base.b * tint.b, 0.0, 1.0),
		0.78
	)
	antialiased = false
