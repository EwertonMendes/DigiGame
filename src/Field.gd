extends Node2D

const GRID_SIZE_X := 15
const GRID_SIZE_Y := 25
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const INVALID_GRID := Vector2i(-9999, -9999)
const TERRAIN_DETAIL_ALPHA := 0.42
const CAMERA_PAN_PADDING := Vector2(176.0, 112.0)

# Kenney Isometric Landscape source tiles are 132x83 pixels. We sample only
# the upper ground face and blend it over a solid biome-colored diamond. The
# solid layer prevents transparent source edges from producing seams between
# adjacent tactical cells while the source art still provides texture detail.
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

var _terrain_textures: Dictionary = {}
var _map_center := Vector2.ZERO
var _hover_fill: Polygon2D
var _hover_outline: Line2D
var _last_hovered_grid := INVALID_GRID


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
	# Grass remains the visual baseline while noise creates broad readable patches.
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

	return Rect2(
		min_point - CAMERA_PAN_PADDING,
		(max_point - min_point) + CAMERA_PAN_PADDING * 2.0
	)


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
	_hover_fill.color = Color(0.12, 0.92, 1.0, 0.20)
	_hover_fill.z_index = -40
	_hover_fill.visible = false
	add_child(_hover_fill)

	_hover_outline = Line2D.new()
	_hover_outline.name = "HoverOutline"
	_hover_outline.points = PackedVector2Array([
		diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]
	])
	_hover_outline.width = 2.0
	_hover_outline.default_color = Color(0.28, 0.96, 1.0, 0.95)
	_hover_outline.z_index = -39
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
	var local_mouse := to_local(get_global_mouse_position())
	var grid := world_to_grid(local_mouse)

	if not _is_valid_grid(grid):
		_last_hovered_grid = INVALID_GRID
		_hover_fill.visible = false
		_hover_outline.visible = false
		return

	if grid == _last_hovered_grid:
		return

	_last_hovered_grid = grid
	var world_position := grid_to_world(grid)
	selectedTile = Vector2i(int(round(world_position.x)), int(round(world_position.y)))
	_hover_fill.position = world_position
	_hover_outline.position = world_position
	_hover_fill.visible = true
	_hover_outline.visible = true


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
