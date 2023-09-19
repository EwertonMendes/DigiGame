extends TileMap

var GridSizeX = 30
var GridSizeY = 50
var Dic = {}
var selectedTile

var tileTypes = {
	"DIRT": Vector2i(0,0),
	"GRASS": Vector2i(2,0),
}

# Called when the node enters the scene tree for the first time.
func _ready():
	for x in GridSizeX:
		for y in GridSizeY:
			Dic[str(Vector2(x,y))] = {
				"Type": "GRASS",
				"Position": str(Vector2(x,y))
			}
			set_cell(0, Vector2(x,y), 1, tileTypes["GRASS"], 0)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var tile = local_to_map(get_global_mouse_position())
	
	for x in GridSizeX:
		for y in GridSizeY:
			erase_cell(1, Vector2(x,y))
			
	if Dic.has(str(tile)):
		selectedTile = map_to_local(tile)
		
		var hoveredTile = Dic.get(str(tile))
		
		set_cell(1, tile, 0, tileTypes[hoveredTile["Type"]], 0)
		#print(hoveredTile["Type"])
