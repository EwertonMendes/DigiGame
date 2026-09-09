extends Node2D

const GRID_SIZE_X := 15
const GRID_SIZE_Y := 25
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const TILE_ART_OFFSET_Y := 16.0
const TILE_SCALE := Vector2(0.5, 0.5)
const INVALID_GRID := Vector2i(-9999, -9999)

const TERRAIN_PATHS := {
	"earth": "res://assets/terrain/kenney/earth.png",
	"grass": "res://assets/terrain/kenney/grass.png",
	"lush_grass": "res://assets/terrain/kenney/lush_grass.png",
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
	_create_board_shadow()
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
	biome_noise.frequency = 0.085
	biome_noise.fractal_octaves = 3

	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 4117
	detail_noise.frequency = 0.19
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

			var tile := Sprite2D.new()
			tile.name = "Tile_%02d_%02d" % [x, y]
			tile.texture = _terrain_textures[terrain_name]
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			tile.scale = TILE_SCALE
			tile.position = world_position + Vector2(0.0, TILE_ART_OFFSET_Y)
			tile.z_index = -100 + x + y
			add_child(tile)

	selectedTile = Vector2i(grid_to_world(Vector2i(GRID_SIZE_X / 2, GRID_SIZE_Y / 2)))


func _terrain_for_noise(biome_value: float, detail_value: float) -> String:
	if biome_value < -0.26:
		return "earth"
	if biome_value > 0.28 or (biome_value > 0.10 and detail_value > 0.42):
		return "lush_grass"
	return "grass"


func _create_board_shadow() -> void:
	var shadow := Polygon2D.new()
	shadow.name = "BoardShadow"
	shadow.polygon = PackedVector2Array([
		grid_to_world(Vector2i(0, 0)) + Vector2(-TILE_WIDTH * 0.5, 22.0),
		grid_to_world(Vector2i(GRID_SIZE_X - 1, 0)) + Vector2(0.0, 22.0),
		grid_to_world(Vector2i(GRID_SIZE_X - 1, GRID_SIZE_Y - 1)) + Vector2(TILE_WIDTH * 0.5, 22.0),
		grid_to_world(Vector2i(0, GRID_SIZE_Y - 1)) + Vector2(0.0, 22.0),
	])
	shadow.color = Color(0.0, 0.035, 0.08, 0.66)
	shadow.z_index = -180
	add_child(shadow)


func _create_hover_indicator() -> void:
	var diamond := PackedVector2Array([
		Vector2(-TILE_WIDTH * 0.5, 0.0),
		Vector2(0.0, -TILE_HEIGHT * 0.5),
		Vector2(TILE_WIDTH * 0.5, 0.0),
		Vector2(0.0, TILE_HEIGHT * 0.5),
	])

	_hover_fill = Polygon2D.new()
	_hover_fill.name = "HoverFill"
	_hover_fill.polygon = diamond
	_hover_fill.color = Color(0.16, 0.94, 1.0, 0.22)
	_hover_fill.z_index = -40
	_hover_fill.visible = false
	add_child(_hover_fill)

	_hover_outline = Line2D.new()
	_hover_outline.name = "HoverOutline"
	_hover_outline.points = PackedVector2Array([
		diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]
	])
	_hover_outline.width = 2.0
	_hover_outline.default_color = Color(0.28, 0.96, 1.0, 0.9)
	_hover_outline.z_index = -39
	_hover_outline.visible = false
	add_child(_hover_outline)


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
