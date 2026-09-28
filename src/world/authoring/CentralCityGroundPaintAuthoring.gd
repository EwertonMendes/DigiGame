@tool
extends Node2D
class_name CentralCityGroundPaintAuthoring

const PAINT_DATA = preload("res://src/world/runtime/GroundPaintData.gd")

@export var cells: Dictionary = {}


func set_cell(cell: Vector2i, surface: String) -> void:
	cells["%d,%d" % [cell.x, cell.y]] = surface
	notify_property_list_changed()


func erase_cell(cell: Vector2i) -> void:
	cells.erase("%d,%d" % [cell.x, cell.y])
	notify_property_list_changed()


func get_surface(cell: Vector2i) -> String:
	return PAINT_DATA.surface(cells.get("%d,%d" % [cell.x, cell.y], ""))
