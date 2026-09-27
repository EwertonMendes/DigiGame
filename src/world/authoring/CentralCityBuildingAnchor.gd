@tool
extends Marker2D
class_name CentralCityBuildingAnchor

@export_enum("digilab", "training", "hospital", "market", "archive") var building_id := "digilab"
@export var editor_color := Color(0.45, 1.0, 0.55, 0.95)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 10.0, editor_color)
	draw_line(Vector2(-16, 0), Vector2(16, 0), editor_color, 2.0)
	draw_line(Vector2(0, -16), Vector2(0, 16), editor_color, 2.0)
