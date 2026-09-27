@tool
extends Node2D
class_name CentralCitySectionAuthoring

const TILE_W := 64.0
const TILE_H := 32.0
const SECTION_SIZE := 14

@export var coord := Vector2i.ZERO:
	set(value):
		coord = value
		_update_editor_position()
@export_enum("garden", "residential", "canal", "archive", "training", "digilab", "plaza", "hospital", "gate", "market") var theme := "residential"
@export var title := ""
@export var subtitle := ""
@export var preview_color := Color(0.25, 0.75, 1.0, 0.08)


func _ready() -> void:
	_update_editor_position()
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW and Engine.is_editor_hint():
		var corners := PackedVector2Array([
			_grid_to_world(Vector2(-0.5, -0.5)),
			_grid_to_world(Vector2(SECTION_SIZE - 0.5, -0.5)),
			_grid_to_world(Vector2(SECTION_SIZE - 0.5, SECTION_SIZE - 0.5)),
			_grid_to_world(Vector2(-0.5, SECTION_SIZE - 0.5)),
		])
		draw_colored_polygon(corners, preview_color)
		var outline := corners.duplicate()
		outline.append(corners[0])
		draw_polyline(outline, Color(0.4, 0.82, 1.0, 0.35), 1.0, false)


func _update_editor_position() -> void:
	if not Engine.is_editor_hint():
		return
	position = _grid_to_world(Vector2(coord * SECTION_SIZE))


func _grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_W * 0.5,
		(grid.x + grid.y) * TILE_H * 0.5
	)
