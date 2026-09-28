@tool
extends Marker2D
class_name CentralCityPropAuthoring

@export var asset_id := "lamp_blue"
@export var role := ""
@export_enum("none", "civic", "landscape") var surround := "none"
@export_enum("world", "behind_building") var depth := "world"
@export var clearance_override := Vector2(-1.0, -1.0)
@export var accent := Color(0.24, 0.88, 1.0, 1.0)


func _validate_property(property: Dictionary) -> void:
	if property.get("name") != "asset_id" or not Engine.is_editor_hint():
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/resources/world/central_city_decor.json"))
	if not parsed is Dictionary:
		return
	var assets := (parsed as Dictionary).get("assets", {}) as Dictionary
	var choices := PackedStringArray()
	for id: String in assets:
		choices.append(id)
	choices.sort()
	property["hint"] = PROPERTY_HINT_ENUM
	property["hint_string"] = ",".join(choices)


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var c := Color(0.25, 0.85, 1.0, 0.95) if asset_id.begins_with("lamp") else Color(1.0, 0.78, 0.28, 0.95)
	draw_circle(Vector2.ZERO, 6.0, c)
	draw_circle(Vector2.ZERO, 10.0, Color(c.r, c.g, c.b, 0.22), false, 2.0)
