@tool
extends Marker2D
class_name CentralCityPropAuthoring

@export var asset_id := "lamp_blue"
@export var role := ""
@export_enum("", "civic", "landscape") var surround := ""
@export_enum("world", "behind_building") var depth := "world"
@export var clearance_override := Vector2(-1.0, -1.0)
@export var accent := Color(0.24, 0.88, 1.0, 1.0)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c := Color(0.25, 0.85, 1.0, 0.95) if asset_id.begins_with("lamp") else Color(1.0, 0.78, 0.28, 0.95)
	draw_circle(Vector2.ZERO, 7.0, c)
