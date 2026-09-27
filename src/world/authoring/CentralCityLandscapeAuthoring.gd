@tool
extends Marker2D
class_name CentralCityLandscapeAuthoring

@export var landscape_id := ""
@export var section_coord := Vector2i.ZERO
@export var preferred_local_cell := Vector2.ZERO


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_circle(Vector2.ZERO, 9.0, Color(0.38, 0.95, 0.32, 0.85))
