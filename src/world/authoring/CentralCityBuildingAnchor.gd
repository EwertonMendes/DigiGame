@tool
extends Marker2D
class_name CentralCityBuildingAnchor

@export_enum("digilab", "training", "hospital", "market", "archive") var building_id := "digilab"
@export var editor_color := Color(0.45, 1.0, 0.55, 0.95)


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 8.0, editor_color)
	draw_line(Vector2(-14, 0), Vector2(14, 0), editor_color, 2.0)
	draw_line(Vector2(0, -14), Vector2(0, 14), editor_color, 2.0)
