extends Node2D

signal hovered_grid_changed(grid: Vector2i, block_reason: String)

const GRID_SIZE_X := 15
const GRID_SIZE_Y := 25
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const INVALID_GRID := Vector2i(-9999, -9999)
const TERRAIN_DETAIL_ALPHA := 0.42
const HOVER_AVAILABLE_FILL := Color(0.12, 0.92, 1.0, 0.20)
const HOVER_AVAILABLE_OUTLINE := Color(0.28, 0.96, 1.0, 0.95)
const HOVER_BLOCKED_FILL := Color(1.0, 0.12, 0.14, 0.24)
const HOVER_BLOCKED_OUTLINE := Color(1.0, 0.28, 0.30, 0.98)
const RANGE_FILL := Color(0.12, 0.72, 1.0, 0.13)
const PATH_FILL := Color(1.0, 0.82, 0.18, 0.30)

# Kenney Isometric Landscape source tiles are 132x83 pixels. We sample only
# the upper ground face and blend it over a solid biome-colored diamond.
const SOURCE_TOP_LEFT := Vector2(2.0, 32.0)
const SOURCE_TOP_TOP := Vector2(66.0, 1.0)
const SOURCE_TOP_RIGHT := Vector2(130.0, 32.0)
const SOURCE_TOP_BOTTOM := Vector2(66.0, 63.0)

const TERRAIN_PATHS := {
	"earth": "res://assets/terrain/kenney/earth.png",
	"grass": "res://assets/terrain/kenney/grass.png",
	"lush_grass": "res://assets/terrain/kenney/lush_grass.png",
}

const TERRAIN_BASE_COLORS := {
	"earth": Color(0.63, 0.39, 0.20, 1.0),
	"grass": Color(0.42, 0.64, 0.16, 1.0),
	"lush_grass": Color(0.50, 0.72, 0.18, 1.0),
}

var tile_map_data: Dictionary = {}
var selectedTile := Vector2i.ZERO

# Static blockers live here instead of inside character movement. Future
# scenery can register trees, cliffs, water, etc. Dynamic occupancy stays in
# DigimonController, while MovementSystem decides whether an occupant may be
# crossed or used as a destination.
var _static_blocked_tiles: Dictionary = {}
var _terrain_textures: Dictionary = {}
var _map_center := Vector2.ZERO
var _hover_fill: Polygon2D
var _hover_outline: Line2D
var _last_hovered_grid := INVALID_GRID
var _last_hover_block_reason := ""
var _movement_mode_active := false
var _movement_origin := INVALID_GRID
var _movement_actor: Node = null
var _movement_reachable: Dictionary = {}
var _range_indicators: Array[Node] = []
var _path_indicators: Array[Node] = []


func _ready() -> void:
	_map_center = _grid_to_raw(Vector2((GRID_SIZE_X - 1) * 0.5, (GRID_SIZE_Y - 1) * 0.5))
	if not _load_terrain_textures():
		return
	_create_board_foundation()
	_create_hover_indicator()
	_generate_terrain()


func _process(_delta: float) -> void:
	_update_hover()


func _load_terrain_textures() -> bool:
	for terrain_name in TERRAIN_PATHS:
		var texture := load(TERRAIN_PATHS[terrain_name]) as Texture2D
		if texture == null:
			push_error("Missing terrain texture: %s" % TERRAIN_PATHS[terrain_name])
			return false
		_terrain_textures[terrain_name] = texture
	return true


func _generate_terrain() -> void:
	var biome_noise := FastNoiseLite.new()
	biome_noise.seed = 1701
	biome_noise.frequency = 0.070
	biome_noise.fractal_octaves = 3

	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 4117
	detail_noise.frequency = 0.18
	detail_noise.fractal_octaves = 2

	for y in range(GRID_SIZE_Y):
		for x in range(GRID_SIZE_X):
			var grid := Vector2i(x, y)
			var biome_value := biome_noise.get_noise_2d(float(x), float(y))
			var detail_value := detail_noise.get_noise_2d(float(x), float(y))
			var terrain_name := _terrain_for_noise(biome_value, detail_value)
			var world_position := grid_to_world(grid)

			tile_map_data[grid] = {
				"type": terrain_name,
				"world_position": world_position,
			}

			var tile := _create_terrain_tile(terrain_name, detail_value)
			tile.name = "Tile_%02d_%02d" % [x, y]
			tile.position = world_position
			tile.z_index = -100 + x + y
			add_child(tile)

	selectedTile = Vector2i(grid_to_world(Vector2i(GRID_SIZE_X / 2, GRID_SIZE_Y / 2)))


func _create_terrain_tile(terrain_name: String, detail_value: float) -> Node2D:
	var tile_root := Node2D.new()
	var brightness := 0.99 + clampf(detail_value, -1.0, 1.0) * 0.025

	var base := Polygon2D.new()
	base.name = "Base"
	base.polygon = _tile_diamond(Vector2(0.8, 0.4))
	var base_color: Color = TERRAIN_BASE_COLORS[terrain_name]
	base.color = Color(
		base_color.r * brightness,
		base_color.g * brightness,
		base_color.b * brightness,
		1.0
	)
	base.z_index = 0
	tile_root.add_child(base)

	var detail := Polygon2D.new()
	detail.name = "KenneyDetail"
	detail.polygon = _tile_diamond()
	detail.texture = _terrain_textures[terrain_name]
	detail.uv = PackedVector2Array([
		SOURCE_TOP_LEFT,
		SOURCE_TOP_TOP,
		SOURCE_TOP_RIGHT,
		SOURCE_TOP_BOTTOM,
	])
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	detail.color = Color(1.0, 1.0, 1.0, TERRAIN_DETAIL_ALPHA)
	detail.z_index = 1
	tile_root.add_child(detail)

	return tile_root


func _terrain_for_noise(biome_value: float, detail_value: float) -> String:
	if biome_value < -0.38:
		return "earth"
	if biome_value > 0.32 or (biome_value > 0.16 and detail_value > 0.48):
		return "lush_grass"
	return "grass"


func _create_board_foundation() -> void:
	var outline := _board_outline()

	var shadow := Polygon2D.new()
	shadow.name = "BoardShadow"
	shadow.polygon = _offset_polygon(outline, Vector2(0.0, 24.0))
	shadow.color = Color(0.0, 0.012, 0.03, 0.72)
	shadow.z_index = -190
	add_child(shadow)

	var base := Polygon2D.new()
	base.name = "BoardBase"
	base.polygon = _offset_polygon(outline, Vector2(0.0, 10.0))
	base.color = Color(0.025, 0.075, 0.09, 1.0)
	base.z_index = -180
	add_child(base)

	var rim := Line2D.new()
	rim.name = "BoardRim"
	rim.points = PackedVector2Array([
		outline[0], outline[1], outline[2], outline[3], outline[0]
	])
	rim.width = 1.5
	rim.default_color = Color(0.18, 0.72, 0.78, 0.36)
	rim.z_index = -80
	add_child(rim)


func _board_outline() -> PackedVector2Array:
	return PackedVector2Array([
		grid_to_world(Vector2i(0, 0)) + Vector2(0.0, -TILE_HEIGHT * 0.5),
		grid_to_world(Vector2i(GRID_SIZE_X - 1, 0)) + Vector2(TILE_WIDTH * 0.5, 0.0),
		grid_to_world(Vector2i(GRID_SIZE_X - 1, GRID_SIZE_Y - 1)) + Vector2(0.0, TILE_HEIGHT * 0.5),
		grid_to_world(Vector2i(0, GRID_SIZE_Y - 1)) + Vector2(-TILE_WIDTH * 0.5, 0.0),
	])


func get_camera_pan_bounds() -> Rect2:
	var outline := _board_outline()
	var min_point := outline[0]
	var max_point := outline[0]
	for point in outline:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


func select_tile_from_world(world_position: Vector2) -> bool:
	var grid := world_to_grid(to_local(world_position))
	if not _is_valid_grid(grid):
		return false
	var moving_actor := _movement_actor if _movement_actor != null else _get_selected_digimon()
	_apply_selected_grid(grid, _effective_block_reason(grid, moving_actor))
	return true


func set_static_tile_blocked(grid: Vector2i, reason := "terrain_blocked") -> void:
	if _is_valid_grid(grid):
		_static_blocked_tiles[grid] = reason


func clear_static_tile_blocker(grid: Vector2i) -> void:
	_static_blocked_tiles.erase(grid)


func get_static_tile_block_reason(grid: Vector2i) -> String:
	if not _is_valid_grid(grid):
		return "out_of_bounds"
	if _static_blocked_tiles.has(grid):
		return String(_static_blocked_tiles[grid])
	return ""


func get_tile_block_reason(grid: Vector2i, moving_digimon: Node = null) -> String:
	var static_reason := get_static_tile_block_reason(grid)
	if not static_reason.is_empty():
		return static_reason

	if moving_digimon != null:
		var controller := _get_digimon_controller()
		if controller != null and controller.has_method("is_tile_occupied"):
			var tile_world_position := grid_to_world(grid)
			if bool(controller.call("is_tile_occupied", tile_world_position, moving_digimon)):
				return "occupied"
	return ""


func get_movement_cost(grid: Vector2i, _moving_digimon: Node = null) -> int:
	if not _is_valid_grid(grid):
		return 999999
	# All current terrain costs 1. MovementSystem already uses this hook, so mud,
	# water, roads, flying movement, etc. can later change cost without touching
	# turn flow or pathfinding.
	return 1


func get_tile_type(grid: Vector2i) -> String:
	if not tile_map_data.has(grid):
		return ""
	return String(tile_map_data[grid].get("type", ""))


func can_digimon_move_to_world(tile_world_position: Vector2, moving_digimon: Node) -> bool:
	var grid := world_to_grid(to_local(tile_world_position))
	return get_tile_block_reason(grid, moving_digimon).is_empty()


func set_movement_range(reachable: Dictionary, origin: Vector2i, moving_actor: Node) -> void:
	clear_movement_range()
	_movement_mode_active = true
	_movement_origin = origin
	_movement_actor = moving_actor
	_movement_reachable = reachable.duplicate()

	for key in _movement_reachable.keys():
		var grid := Vector2i(key)
		var indicator := Polygon2D.new()
		indicator.name = "MoveRange_%02d_%02d" % [grid.x, grid.y]
		indicator.polygon = _tile_diamond(Vector2(-1.0, -0.5))
		indicator.color = RANGE_FILL
		indicator.position = grid_to_world(grid)
		indicator.z_index = -36
		add_child(indicator)
		_range_indicators.append(indicator)

	_last_hovered_grid = INVALID_GRID
	_last_hover_block_reason = ""


func clear_movement_range() -> void:
	_free_indicators(_range_indicators)
	_movement_reachable.clear()
	_movement_mode_active = false
	_movement_origin = INVALID_GRID
	_movement_actor = null
	_last_hovered_grid = INVALID_GRID
	_last_hover_block_reason = ""


func set_movement_path(path: Array[Vector2i]) -> void:
	clear_movement_path()
	for grid in path:
		var indicator := Polygon2D.new()
		indicator.name = "MovePath_%02d_%02d" % [grid.x, grid.y]
		indicator.polygon = _tile_diamond(Vector2(-5.0, -2.5))
		indicator.color = PATH_FILL
		indicator.position = grid_to_world(grid)
		indicator.z_index = -34
		add_child(indicator)
		_path_indicators.append(indicator)


func clear_movement_path() -> void:
	_free_indicators(_path_indicators)


func _free_indicators(indicators: Array[Node]) -> void:
	for indicator in indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	indicators.clear()


func _get_selected_digimon() -> Node:
	var controller := _get_digimon_controller()
	if controller != null and controller.has_method("get_selected_digimon"):
		return controller.call("get_selected_digimon") as Node
	return null


func _get_digimon_controller() -> Node:
	var main := get_tree().root.get_node_or_null("Main")
	if main == null:
		return null
	return main.get_node_or_null("DigimonController")


func _offset_polygon(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(point + offset)
	return result


func _create_hover_indicator() -> void:
	var diamond := _tile_diamond()

	_hover_fill = Polygon2D.new()
	_hover_fill.name = "HoverFill"
	_hover_fill.polygon = diamond
	_hover_fill.color = HOVER_AVAILABLE_FILL
	_hover_fill.z_index = -32
	_hover_fill.visible = false
	add_child(_hover_fill)

	_hover_outline = Line2D.new()
	_hover_outline.name = "HoverOutline"
	_hover_outline.points = PackedVector2Array([
		diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]
	])
	_hover_outline.width = 2.0
	_hover_outline.default_color = HOVER_AVAILABLE_OUTLINE
	_hover_outline.z_index = -31
	_hover_outline.visible = false
	add_child(_hover_outline)


func _tile_diamond(overscan := Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-TILE_WIDTH * 0.5 - overscan.x, 0.0),
		Vector2(0.0, -TILE_HEIGHT * 0.5 - overscan.y),
		Vector2(TILE_WIDTH * 0.5 + overscan.x, 0.0),
		Vector2(0.0, TILE_HEIGHT * 0.5 + overscan.y),
	])


func _update_hover() -> void:
	if GlobalVariables.TouchInputActive:
		return

	var local_mouse := to_local(get_global_mouse_position())
	var grid := world_to_grid(local_mouse)
	if not _is_valid_grid(grid):
		if _last_hovered_grid != INVALID_GRID:
			hovered_grid_changed.emit(INVALID_GRID, "out_of_bounds")
		_last_hovered_grid = INVALID_GRID
		_last_hover_block_reason = ""
		_hover_fill.visible = false
		_hover_outline.visible = false
		return

	var moving_actor := _movement_actor if _movement_actor != null else _get_selected_digimon()
	var block_reason := _effective_block_reason(grid, moving_actor)
	if grid == _last_hovered_grid and block_reason == _last_hover_block_reason:
		return
	_apply_selected_grid(grid, block_reason)


func _effective_block_reason(grid: Vector2i, moving_actor: Node) -> String:
	var block_reason := get_tile_block_reason(grid, moving_actor)
	if (
		block_reason.is_empty()
		and _movement_mode_active
		and grid != _movement_origin
		and not _movement_reachable.has(grid)
	):
		return "out_of_range"
	return block_reason


func _apply_selected_grid(grid: Vector2i, block_reason := "") -> void:
	_last_hovered_grid = grid
	_last_hover_block_reason = block_reason
	var world_position := grid_to_world(grid)
	selectedTile = Vector2i(int(round(world_position.x)), int(round(world_position.y)))
	_hover_fill.position = world_position
	_hover_outline.position = world_position
	_hover_fill.color = HOVER_BLOCKED_FILL if not block_reason.is_empty() else HOVER_AVAILABLE_FILL
	_hover_outline.default_color = HOVER_BLOCKED_OUTLINE if not block_reason.is_empty() else HOVER_AVAILABLE_OUTLINE
	_hover_fill.visible = true
	_hover_outline.visible = true
	hovered_grid_changed.emit(grid, block_reason)


func _is_valid_grid(grid: Vector2i) -> bool:
	return grid.x >= 0 and grid.x < GRID_SIZE_X and grid.y >= 0 and grid.y < GRID_SIZE_Y


func _grid_to_raw(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_WIDTH * 0.5,
		(grid.x + grid.y) * TILE_HEIGHT * 0.5
	)


func grid_to_world(grid: Vector2i) -> Vector2:
	return _grid_to_raw(Vector2(grid)) - _map_center


func world_to_grid(local_position: Vector2) -> Vector2i:
	var raw := local_position + _map_center
	var half_width := TILE_WIDTH * 0.5
	var half_height := TILE_HEIGHT * 0.5
	var grid_x := (raw.x / half_width + raw.y / half_height) * 0.5
	var grid_y := (raw.y / half_height - raw.x / half_width) * 0.5
	return Vector2i(int(round(grid_x)), int(round(grid_y)))
