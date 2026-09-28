@tool
extends Polygon2D
class_name CentralCityTransitionRegion

@export_enum("stairs", "bridge", "void") var kind := "void"
@export var transition_id := ""
@export var from_level := ""
@export var to_level := ""
@export var level_id := ""
@export_range(2, 16, 1) var steps := 6
@export_enum("water", "none") var void_fill := "water"


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	match kind:
		"stairs":
			color = Color(0.95, 0.65, 0.18, 0.26)
		"bridge":
			color = Color(0.20, 0.85, 0.95, 0.22)
		_:
			color = Color(0.02, 0.08, 0.11, 0.42)
