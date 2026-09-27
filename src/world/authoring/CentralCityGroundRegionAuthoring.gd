@tool
extends Polygon2D
class_name CentralCityGroundRegionAuthoring

@export var region_id := ""
@export_enum("main", "dark", "stone_soft", "tech_teal", "tech_blue", "tech_purple", "market", "training", "grass", "water") var surface := "main"
@export var render := true
@export var walkable := true
@export var base_color := Color.WHITE
@export var priority := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		color = Color(base_color.r, base_color.g, base_color.b, 0.18)
