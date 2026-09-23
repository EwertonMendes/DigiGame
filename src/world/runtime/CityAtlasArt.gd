extends RefCounted
class_name CityAtlasArt

const ATLAS = preload("res://assets/terrain/MCBlocksColorOutline.png")

const CELL_SIZE := 32.0
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const TILE_HALF_WIDTH := TILE_WIDTH * 0.5
const TILE_HALF_HEIGHT := TILE_HEIGHT * 0.5
const FLOOR_OVERSCAN := Vector2(0.55, 0.28)
const BLOCK_SCALE := Vector2(2.0, 2.0)
const BLOCK_TOP_CENTER_OFFSET := Vector2(0.0, 12.0)
const BLOCK_LEVEL_HEIGHT := 32.0

# Every flat-floor icon in row 16 shares this authored diamond footprint
# inside its 32x32 atlas cell.
const FLOOR_LEFT := Vector2(4.0, 21.0)
const FLOOR_TOP := Vector2(16.0, 14.0)
const FLOOR_RIGHT := Vector2(28.0, 21.0)
const FLOOR_BOTTOM := Vector2(16.0, 28.0)


static func tile_diamond(overscan := Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-TILE_HALF_WIDTH - overscan.x, 0.0),
		Vector2(0.0, -TILE_HALF_HEIGHT - overscan.y),
		Vector2(TILE_HALF_WIDTH + overscan.x, 0.0),
		Vector2(0.0, TILE_HALF_HEIGHT + overscan.y),
	])


static func atlas_texture(cell: Vector2i) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = Rect2(
		float(cell.x) * CELL_SIZE,
		float(cell.y) * CELL_SIZE,
		CELL_SIZE,
		CELL_SIZE
	)
	return texture


static func create_floor_tile(
	cell: Vector2i,
	top_center: Vector2,
	depth_order: int,
	base_color: Color,
	detail_tint: Color = Color.WHITE,
	detail_alpha: float = 1.0
) -> Node2D:
	var root := Node2D.new()
	root.position = top_center
	root.z_index = clampi(depth_order, -4000, 4000)

	var base := Polygon2D.new()
	base.name = "Base"
	base.polygon = tile_diamond(FLOOR_OVERSCAN)
	base.color = base_color
	base.z_index = 0
	root.add_child(base)

	var cell_origin := Vector2(float(cell.x) * CELL_SIZE, float(cell.y) * CELL_SIZE)
	var detail := Polygon2D.new()
	detail.name = "AtlasFloor"
	detail.polygon = tile_diamond()
	detail.texture = ATLAS
	detail.uv = PackedVector2Array([
		cell_origin + FLOOR_LEFT,
		cell_origin + FLOOR_TOP,
		cell_origin + FLOOR_RIGHT,
		cell_origin + FLOOR_BOTTOM,
	])
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail.color = Color(
		detail_tint.r,
		detail_tint.g,
		detail_tint.b,
		clampf(detail_alpha, 0.0, 1.0)
	)
	detail.z_index = 1
	root.add_child(detail)
	return root


static func create_block(
	cell: Vector2i,
	top_center: Vector2,
	depth_order: int,
	level: int = 0,
	tint: Color = Color.WHITE
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = atlas_texture(cell)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = BLOCK_SCALE
	sprite.position = top_center + BLOCK_TOP_CENTER_OFFSET - Vector2(0.0, float(level) * BLOCK_LEVEL_HEIGHT)
	sprite.z_index = clampi(depth_order + level, -4000, 4000)
	sprite.modulate = tint
	return sprite


static func create_prop(
	cell: Vector2i,
	ground_anchor: Vector2,
	depth_order: int,
	scale := Vector2(2.0, 2.0),
	tint: Color = Color.WHITE,
	offset := Vector2.ZERO
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = atlas_texture(cell)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = scale
	# Most atlas props use y=28 as their authored foot. With a 32px cell
	# center at y=16, subtracting 12*scale anchors that foot to the ground.
	sprite.position = ground_anchor + offset - Vector2(0.0, 12.0 * scale.y)
	sprite.z_index = clampi(depth_order, -4000, 4000)
	sprite.modulate = tint
	return sprite
