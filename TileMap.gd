extends TileMap

var GridSizeX = 30
var GridSizeY = 50
var Dic = {}
var selectedTile

var tileTypes = [
	{ 
		type = "DIRT",
		position = Vector2i(0,0)
	},
	{ 
		type = "GRASS",
		position = Vector2i(2,0)
	},
	{ 
		type = "SNOW",
		position = Vector2i(5,0)
	},
]

# Called when the node enters the scene tree for the first time.
func _ready():
	for x in GridSizeX:
		for y in GridSizeY:
			var tileType = tileTypes.pick_random()
			Dic[str(Vector2(x,y))] = {
				"type": tileType.type,
				"position": str(Vector2(x,y))
			}
			#randi() % 3
			set_cell(0, Vector2(x,y), 1, tileType.position, 0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var tile = local_to_map(get_global_mouse_position())
	
	for x in GridSizeX:
		for y in GridSizeY:
			erase_cell(1, Vector2(x,y))
			
	if Dic.has(str(tile)):
		selectedTile = map_to_local(tile)
		
		var hoveredTile = Dic.get(str(tile))
		var tileType = findTileByType(hoveredTile["type"])
		set_cell(1, tile, 0, tileType.position, 0)
		
func findTileByType(type: String):
	for tileType in tileTypes:
		if tileType["type"] == type:
			return tileType
