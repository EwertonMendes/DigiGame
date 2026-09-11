extends "res://src/world/DevilsWorkshopField.gd"

const ATTACK_RANGE_FILL := Color(1.0, 0.24, 0.20, 0.16)
const SKILL_RANGE_FILL := Color(0.62, 0.30, 1.0, 0.16)
const TARGET_FILL := Color(1.0, 0.82, 0.20, 0.34)

var _action_range_indicators: Array[Node] = []
var _target_indicators: Array[Node] = []


func set_action_range(grids: Array[Vector2i], kind: String = "attack") -> void:
	clear_action_range()
	var color := SKILL_RANGE_FILL if kind == "skill" else ATTACK_RANGE_FILL
	for grid: Vector2i in grids:
		var indicator := Polygon2D.new()
		indicator.name = "ActionRange_%02d_%02d" % [grid.x, grid.y]
		indicator.polygon = _tile_diamond(Vector2(-2.0, -1.0))
		indicator.color = color
		indicator.position = grid_to_world(grid)
		indicator.z_index = -33
		add_child(indicator)
		_action_range_indicators.append(indicator)


func set_target_preview_grid(grid: Vector2i) -> void:
	clear_target_preview()
	var indicator := Polygon2D.new()
	indicator.name = "TargetPreview"
	indicator.polygon = _tile_diamond(Vector2(-6.0, -3.0))
	indicator.color = TARGET_FILL
	indicator.position = grid_to_world(grid)
	indicator.z_index = -30
	add_child(indicator)
	_target_indicators.append(indicator)


func clear_action_range() -> void:
	_free_combat_indicators(_action_range_indicators)
	clear_target_preview()


func clear_target_preview() -> void:
	_free_combat_indicators(_target_indicators)


func _free_combat_indicators(indicators: Array[Node]) -> void:
	for indicator: Node in indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	indicators.clear()
