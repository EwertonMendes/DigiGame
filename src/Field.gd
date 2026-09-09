extends TileMap

const GRID_SIZE_X := 15
const GRID_SIZE_Y := 25

var tile_map_data: Dictionary = {}
var selectedTile := Vector2i.ZERO

var tile_types := [
	{"type": "DIRT", "position": Vector2i(0, 0)},
	{"type": "GRASS", "position": Vector2i(2, 0)},
	{"type": "SNOW", "position": Vector2i(5, 0)},
]

func _ready() -> void:
	initialize_tile_map()

func _process(_delta: float) -> void:
	update_tile_map_on_hover()

func initialize_tile_map() -> void:
	for x in range(GRID_SIZE_X):
		for y in range(GRID_SIZE_Y):
			var tile_type: Dictionary = tile_types.pick_random()
			var position := Vector2i(x, y)
			tile_map_data[position] = {
				"type": tile_type["type"],
				"position": str(position),
			}
			set_cell(0, position, 1, tile_type["position"], 0)

func update_tile_map_on_hover() -> void:
	var mouse_position := Vector2i(get_global_mouse_position())
	var tile := local_to_map(mouse_position + Vector2i(0, 7))

	clear_hovered_tiles_from_field()

	if tile_map_data.has(tile):
		selectedTile = Vector2i(map_to_local(tile))
		var tile_type: Dictionary = find_tile_by_type(tile_map_data[tile]["type"])
		if not tile_type.is_empty():
			set_cell(1, tile, 0, tile_type["position"], 0)

func clear_hovered_tiles_from_field() -> void:
	for position in tile_map_data.keys():
		erase_cell(1, position)

func find_tile_by_type(type: String) -> Dictionary:
	for tile_type in tile_types:
		if tile_type["type"] == type:
			return tile_type
	return {}
