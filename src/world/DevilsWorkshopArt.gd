extends RefCounted
class_name DevilsWorkshopArt

const GRASS_BLOCK = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0000.png")
const WARM_BLOCK = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0001.png")
const DATA_BLOCK = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0005.png")
const WATER_BLOCK = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0020.png")

# DigiGame's gameplay grid is a strict 64x32 (2:1) isometric diamond. The
# Devil's Workshop 50x50 block sprites are not 50px-wide tiles: the usable top
# face only spans roughly x=4.5..45.5 and y=1.5..24.5. Scaling the whole PNG to
# 64px therefore leaves visible gaps between logical tiles and makes rows look
# crooked. Surface tiles are now rendered as exact 64x32 polygons and only the
# authored top face is sampled from the source block.
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const TILE_HALF_WIDTH := TILE_WIDTH * 0.5
const TILE_HALF_HEIGHT := TILE_HEIGHT * 0.5
const BASE_OVERSCAN := Vector2(0.45, 0.22)

const SOURCE_TOP_LEFT := Vector2(4.5, 13.0)
const SOURCE_TOP_TOP := Vector2(25.0, 1.5)
const SOURCE_TOP_RIGHT := Vector2(45.5, 13.0)
const SOURCE_TOP_BOTTOM := Vector2(25.0, 24.5)

# Full blocks remain available for isolated props/elevation. Their scale is
# calibrated against the top-face footprint rather than the 50x50 canvas.
const SOURCE_TOP_WIDTH := 41.0
const SOURCE_TOP_HEIGHT := 23.0
const FULL_BLOCK_SCALE := Vector2(TILE_WIDTH / SOURCE_TOP_WIDTH, TILE_HEIGHT / SOURCE_TOP_HEIGHT)
const FULL_BLOCK_CENTER_OFFSET := Vector2(0.0, (25.0 - 13.0) * FULL_BLOCK_SCALE.y)
const BLOCK_LEVEL_HEIGHT := TILE_HEIGHT


static func tile_diamond(overscan := Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-TILE_HALF_WIDTH - overscan.x, 0.0),
		Vector2(0.0, -TILE_HALF_HEIGHT - overscan.y),
		Vector2(TILE_HALF_WIDTH + overscan.x, 0.0),
		Vector2(0.0, TILE_HALF_HEIGHT + overscan.y),
	])


static func top_face_uv() -> PackedVector2Array:
	return PackedVector2Array([
		SOURCE_TOP_LEFT,
		SOURCE_TOP_TOP,
		SOURCE_TOP_RIGHT,
		SOURCE_TOP_BOTTOM,
	])


static func create_surface_tile(
	texture: Texture2D,
	top_center: Vector2,
	depth_order: int,
	base_color: Color,
	detail_tint: Color = Color.WHITE,
	detail_alpha: float = 0.42
) -> Node2D:
	var root := Node2D.new()
	root.position = top_center
	root.z_index = depth_order

	# Slightly oversized opaque base prevents sub-pixel cracks at non-integer
	# camera zoom while the textured face itself stays on the exact gameplay
	# diamond. Any seam therefore resolves to the neighboring terrain color,
	# never to the background behind the map.
	var base := Polygon2D.new()
	base.name = "Base"
	base.polygon = tile_diamond(BASE_OVERSCAN)
	base.color = base_color
	base.z_index = 0
	root.add_child(base)

	var detail := Polygon2D.new()
	detail.name = "TopFaceDetail"
	detail.polygon = tile_diamond()
	detail.texture = texture
	detail.uv = top_face_uv()
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail.color = Color(detail_tint.r, detail_tint.g, detail_tint.b, clampf(detail_alpha, 0.0, 1.0))
	detail.z_index = 1
	root.add_child(detail)

	return root


static func create_full_block(
	texture: Texture2D,
	top_center: Vector2,
	depth_order: int,
	tint: Color = Color.WHITE,
	level: int = 0
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = FULL_BLOCK_SCALE
	sprite.position = top_center + FULL_BLOCK_CENTER_OFFSET - Vector2(0.0, float(level) * BLOCK_LEVEL_HEIGHT)
	sprite.z_index = depth_order + level
	sprite.modulate = tint
	return sprite


# Backward-compatible alias for any future scene still asking for a complete
# block. Ground surfaces should use create_surface_tile() instead.
static func create_block(
	texture: Texture2D,
	top_center: Vector2,
	depth_order: int,
	tint: Color = Color.WHITE,
	level: int = 0
) -> Sprite2D:
	return create_full_block(texture, top_center, depth_order, tint, level)
