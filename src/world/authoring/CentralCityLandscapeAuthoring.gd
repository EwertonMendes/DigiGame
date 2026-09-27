@tool
extends Marker2D
class_name CentralCityLandscapeAuthoring

@export var landscape_id := ""
@export var section_coord := Vector2i.ZERO
@export var preferred_local_cell := Vector2.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c := Color(0.38, 0.95, 0.32, 0.90)
	draw_circle(Vector2.ZERO, 7.0, c)
	draw_line(Vector2(-11.0, 0.0), Vector2(11.0, 0.0), c, 1.5)
	draw_line(Vector2(0.0, -11.0), Vector2(0.0, 11.0), c, 1.5)
