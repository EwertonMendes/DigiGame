extends RefCounted
class_name DevilsWorkshopArt

const GRASS_BLOCK = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0000.png")
const WARM_BLOCK = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0001.png")
const DATA_BLOCK = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0005.png")
const WATER_BLOCK = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0020.png")

# The selected source sprites are 50x50 blocks whose top face fits the same 2:1
# projection as DigiGame's 64x32 logical grid. Scaling the source width to 64
# keeps every existing movement/targeting coordinate intact while giving the
# world real block depth instead of a flat diamond texture.
const SOURCE_SIZE := 50.0
const WORLD_TILE_WIDTH := 64.0
const WORLD_SCALE := WORLD_TILE_WIDTH / SOURCE_SIZE
const TOP_CENTER_Y_OFFSET := 16.0
const BLOCK_LEVEL_HEIGHT := 32.0


static func create_block(
	texture: Texture2D,
	top_center: Vector2,
	depth_order: int,
	tint: Color = Color.WHITE,
	level: int = 0
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	sprite.position = top_center + Vector2(0.0, TOP_CENTER_Y_OFFSET - float(level) * BLOCK_LEVEL_HEIGHT)
	sprite.z_index = depth_order + level
	sprite.modulate = tint
	return sprite
