@tool
extends RefCounted

const SOURCE := "res://assets/scenery/darkmoon_city/tiles_8x8.png"
const SHA256 := "a9abb47ff5433abdcdc82632b6e6e748bb4389f1919e2e452e3f92e493a1226a"
const RAW_TEMPLATE = preload("res://assets/scenery/darkmoon_city/tiles_8x8.png")


static func assemble() -> Image:
	var source := RAW_TEMPLATE.get_image()
	source.convert(Image.FORMAT_RGBA8)
	var palette := Image.create(1024,512,false,Image.FORMAT_RGBA8)
	var brushes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://experiments/darkmoon_sandbox/brushes.json"))
	for brush: Dictionary in brushes.values():
		var region: Array = brush.rect
		var cells: Array = brush.private_cells
		for y in range(cells.size()):
			for x in range(cells[y].size()):
				var cell: Variant = cells[y][x]
				if cell == null:
					continue
				var index := int(cell)
				assert(index >= 0 and index < 3825)
				palette.blit_rect(source,Rect2i((index%32)*8,(index/32)*8,8,8),
					Vector2i(int(region[0])+x*8,int(region[1])+y*8))
	return palette


static func set_palette(host: Node, texture: Texture2D, raw_texture: Texture2D = RAW_TEMPLATE) -> void:
	# Duplicate before changing the texture: hand-painted cells and the public
	# source resources remain intact. Only the displayed palette is substituted.
	var replacements: Dictionary = {}
	for layer: TileMapLayer in host.find_children("*","TileMapLayer",true,false):
		var original := layer.tile_set
		if original == null or not original.has_source(0) or original.get_source(0).resource_name != "Assembled city pieces":
			continue
		if not replacements.has(original):
			var tiles := original.duplicate(true) as TileSet
			(tiles.get_source(0) as TileSetAtlasSource).texture = texture
			if tiles.has_source(1):
				(tiles.get_source(1) as TileSetAtlasSource).texture = raw_texture
			replacements[original] = tiles
		layer.tile_set = replacements[original]


static func preview_in_editor(host: Node) -> void:
	set_palette(host,preload("res://assets/scenery/darkmoon_city/pieces.png"),RAW_TEMPLATE)
