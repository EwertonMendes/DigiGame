extends "res://src/world/DevilsWorkshopField.gd"

# Tactical guidance deliberately sits above the terrain treatment but below all
# combatants. The previous alpha-only overlays were technically correct, yet
# they disappeared against the new detailed grass. Each state now combines a
# restrained fill, a crisp frame and a soft outer glow so the player can read
# clickability at a glance without turning the battlefield into a neon board.
const MOVE_RANGE_FILL := Color(0.04, 0.72, 0.92, 0.24)
const MOVE_RANGE_OUTLINE := Color(0.22, 0.92, 1.0, 0.72)
const MOVE_RANGE_GLOW := Color(0.10, 0.84, 1.0, 0.16)

const MOVE_PATH_FILL := Color(1.0, 0.78, 0.12, 0.34)
const MOVE_PATH_OUTLINE := Color(1.0, 0.91, 0.34, 0.94)
const MOVE_PATH_GLOW := Color(1.0, 0.72, 0.08, 0.18)

const ATTACK_RANGE_FILL := Color(1.0, 0.28, 0.10, 0.24)
const ATTACK_RANGE_OUTLINE := Color(1.0, 0.50, 0.22, 0.84)
const ATTACK_RANGE_GLOW := Color(1.0, 0.30, 0.10, 0.16)

const SKILL_RANGE_FILL := Color(0.62, 0.28, 1.0, 0.24)
const SKILL_RANGE_OUTLINE := Color(0.80, 0.52, 1.0, 0.88)
const SKILL_RANGE_GLOW := Color(0.66, 0.30, 1.0, 0.18)

const TARGET_FILL := Color(1.0, 0.78, 0.10, 0.42)
const TARGET_OUTLINE := Color(1.0, 0.94, 0.42, 1.0)
const TARGET_GLOW := Color(1.0, 0.70, 0.08, 0.26)

const HOVER_AVAILABLE_FILL_V2 := Color(0.06, 0.86, 1.0, 0.34)
const HOVER_AVAILABLE_OUTLINE_V2 := Color(0.64, 0.98, 1.0, 1.0)
const HOVER_AVAILABLE_GLOW_V2 := Color(0.08, 0.86, 1.0, 0.32)
const HOVER_BLOCKED_FILL_V2 := Color(1.0, 0.10, 0.12, 0.30)
const HOVER_BLOCKED_OUTLINE_V2 := Color(1.0, 0.40, 0.38, 1.0)
const HOVER_BLOCKED_GLOW_V2 := Color(1.0, 0.12, 0.12, 0.26)

var _action_range_indicators: Array[Node] = []
var _target_indicators: Array[Node] = []
var _hover_glow: Line2D


func _process(_delta: float) -> void:
	_update_hover()
	if _last_hovered_grid == INVALID_GRID and _hover_glow != null:
		_hover_glow.visible = false


func set_movement_range(reachable: Dictionary, origin: Vector2i, moving_actor: Node) -> void:
	clear_movement_range()
	_movement_mode_active = true
	_movement_origin = origin
	_movement_actor = moving_actor
	_movement_reachable = reachable.duplicate()

	for key in _movement_reachable.keys():
		var grid := Vector2i(key)
		if grid == origin:
			continue
		var indicator := _create_tactical_indicator(
			"MoveRange_%02d_%02d" % [grid.x, grid.y],
			grid,
			MOVE_RANGE_FILL,
			MOVE_RANGE_OUTLINE,
			MOVE_RANGE_GLOW,
			Vector2(-1.5, -0.75),
			1.35,
			4.25,
			-36
		)
		_range_indicators.append(indicator)

	_last_hovered_grid = INVALID_GRID
	_last_hover_block_reason = ""


func set_movement_path(path: Array[Vector2i]) -> void:
	clear_movement_path()
	for grid in path:
		if grid == _movement_origin:
			continue
		var indicator := _create_tactical_indicator(
			"MovePath_%02d_%02d" % [grid.x, grid.y],
			grid,
			MOVE_PATH_FILL,
			MOVE_PATH_OUTLINE,
			MOVE_PATH_GLOW,
			Vector2(-5.0, -2.5),
			1.8,
			5.0,
			-34
		)
		_path_indicators.append(indicator)


func set_action_range(grids: Array[Vector2i], kind: String = "attack") -> void:
	clear_action_range()
	var fill := SKILL_RANGE_FILL if kind == "skill" else ATTACK_RANGE_FILL
	var outline := SKILL_RANGE_OUTLINE if kind == "skill" else ATTACK_RANGE_OUTLINE
	var glow := SKILL_RANGE_GLOW if kind == "skill" else ATTACK_RANGE_GLOW

	for grid: Vector2i in grids:
		var indicator := _create_tactical_indicator(
			"ActionRange_%02d_%02d" % [grid.x, grid.y],
			grid,
			fill,
			outline,
			glow,
			Vector2(-2.0, -1.0),
			1.45,
			4.5,
			-33
		)
		_action_range_indicators.append(indicator)


func set_target_preview_grid(grid: Vector2i) -> void:
	clear_target_preview()
	var indicator := _create_tactical_indicator(
		"TargetPreview",
		grid,
		TARGET_FILL,
		TARGET_OUTLINE,
		TARGET_GLOW,
		Vector2(-5.0, -2.5),
		2.25,
		7.0,
		-29
	)
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


func _create_hover_indicator() -> void:
	var diamond := _tile_diamond(Vector2(-1.5, -0.75))

	_hover_glow = Line2D.new()
	_hover_glow.name = "HoverGlow"
	_hover_glow.points = _closed_diamond_points(diamond)
	_hover_glow.width = 7.0
	_hover_glow.default_color = HOVER_AVAILABLE_GLOW_V2
	_hover_glow.antialiased = true
	_hover_glow.z_index = -33
	_hover_glow.visible = false
	add_child(_hover_glow)

	_hover_fill = Polygon2D.new()
	_hover_fill.name = "HoverFill"
	_hover_fill.polygon = diamond
	_hover_fill.color = HOVER_AVAILABLE_FILL_V2
	_hover_fill.z_index = -32
	_hover_fill.visible = false
	add_child(_hover_fill)

	_hover_outline = Line2D.new()
	_hover_outline.name = "HoverOutline"
	_hover_outline.points = _closed_diamond_points(diamond)
	_hover_outline.width = 2.6
	_hover_outline.default_color = HOVER_AVAILABLE_OUTLINE_V2
	_hover_outline.antialiased = true
	_hover_outline.z_index = -31
	_hover_outline.visible = false
	add_child(_hover_outline)


func _apply_selected_grid(grid: Vector2i, block_reason := "") -> void:
	_last_hovered_grid = grid
	_last_hover_block_reason = block_reason
	var world_position := grid_to_world(grid)
	selectedTile = Vector2i(int(round(world_position.x)), int(round(world_position.y)))
	var blocked := not block_reason.is_empty()

	_hover_glow.position = world_position
	_hover_fill.position = world_position
	_hover_outline.position = world_position
	_hover_glow.default_color = HOVER_BLOCKED_GLOW_V2 if blocked else HOVER_AVAILABLE_GLOW_V2
	_hover_fill.color = HOVER_BLOCKED_FILL_V2 if blocked else HOVER_AVAILABLE_FILL_V2
	_hover_outline.default_color = HOVER_BLOCKED_OUTLINE_V2 if blocked else HOVER_AVAILABLE_OUTLINE_V2
	_hover_glow.visible = true
	_hover_fill.visible = true
	_hover_outline.visible = true
	hovered_grid_changed.emit(grid, block_reason)


func _create_tactical_indicator(
	indicator_name: String,
	grid: Vector2i,
	fill_color: Color,
	outline_color: Color,
	glow_color: Color,
	inset: Vector2,
	outline_width: float,
	glow_width: float,
	depth: int
) -> Node2D:
	var root := Node2D.new()
	root.name = indicator_name
	root.position = grid_to_world(grid)
	root.z_index = depth
	add_child(root)

	var diamond := _tile_diamond(inset)
	var closed_points := _closed_diamond_points(diamond)

	var glow := Line2D.new()
	glow.name = "Glow"
	glow.points = closed_points
	glow.width = glow_width
	glow.default_color = glow_color
	glow.antialiased = true
	root.add_child(glow)

	var fill := Polygon2D.new()
	fill.name = "Fill"
	fill.polygon = diamond
	fill.color = fill_color
	root.add_child(fill)

	var outline := Line2D.new()
	outline.name = "Outline"
	outline.points = closed_points
	outline.width = outline_width
	outline.default_color = outline_color
	outline.antialiased = true
	root.add_child(outline)

	return root


func _closed_diamond_points(diamond: PackedVector2Array) -> PackedVector2Array:
	return PackedVector2Array([
		diamond[0], diamond[1], diamond[2], diamond[3], diamond[0],
	])
