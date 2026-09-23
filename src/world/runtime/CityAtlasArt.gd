extends RefCounted
class_name CityAtlasArt

const ATLAS = preload("res://assets/terrain/MCBlocksColorOutline.png")
const GROUND_ATLAS = preload("res://assets/terrain/central_city_user_sheet/central_city_ground_atlas.png")

const GROUND_ATLAS_CELL_SIZE := 64.0
const GROUND_DRAW_SIZE := Vector2(88.0, 88.0)

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


static func create_floor_batch(
	tiles: Array[Dictionary],
	depth_order: int,
	node_name: String = "FloorBatch"
) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.z_index = clampi(depth_order, -4000, 4000)
	if tiles.is_empty():
		return root

	var base := MeshInstance2D.new()
	base.name = "BaseMesh"
	base.mesh = _build_floor_mesh(tiles, false)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(base)

	var detail := MeshInstance2D.new()
	detail.name = "DetailMesh"
	detail.mesh = _build_floor_mesh(tiles, true)
	detail.texture = ATLAS
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail.z_index = 1
	root.add_child(detail)
	return root


static func _build_floor_mesh(tiles: Array[Dictionary], textured: bool) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var texture_size := Vector2(maxf(1.0, float(ATLAS.get_width())), maxf(1.0, float(ATLAS.get_height())))
	var diamond := tile_diamond(Vector2.ZERO if textured else FLOOR_OVERSCAN)

	for spec: Dictionary in tiles:
		var center: Vector2 = spec.get("position", Vector2.ZERO)
		var vertex_start := vertices.size()
		for point: Vector2 in diamond:
			vertices.append(center + point)

		if textured:
			var atlas_cell: Vector2i = spec.get("cell", Vector2i.ZERO)
			var cell_origin := Vector2(float(atlas_cell.x) * CELL_SIZE, float(atlas_cell.y) * CELL_SIZE)
			var pixel_uvs := PackedVector2Array([
				cell_origin + FLOOR_LEFT,
				cell_origin + FLOOR_TOP,
				cell_origin + FLOOR_RIGHT,
				cell_origin + FLOOR_BOTTOM,
			])
			for pixel_uv: Vector2 in pixel_uvs:
				uvs.append(Vector2(pixel_uv.x / texture_size.x, pixel_uv.y / texture_size.y))
			var detail_tint: Color = spec.get("detail_tint", Color.WHITE)
			var detail_alpha := clampf(float(spec.get("detail_alpha", 1.0)), 0.0, 1.0)
			var detail_color := Color(detail_tint.r, detail_tint.g, detail_tint.b, detail_alpha)
			for _index in range(4):
				colors.append(detail_color)
		else:
			var base_color: Color = spec.get("base_color", Color.WHITE)
			for _index in range(4):
				colors.append(base_color)

		indices.append_array(PackedInt32Array([
			vertex_start,
			vertex_start + 1,
			vertex_start + 2,
			vertex_start,
			vertex_start + 2,
			vertex_start + 3,
		]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	if textured:
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func create_ground_batch(
	tiles: Array[Dictionary],
	depth_order: int,
	node_name: String = "GroundBatch"
) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.z_index = clampi(depth_order, -4000, 4000)
	if tiles.is_empty():
		return root

	var sheet := MeshInstance2D.new()
	sheet.name = "SheetMesh"
	sheet.mesh = _build_ground_mesh(tiles)
	sheet.texture = GROUND_ATLAS
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(sheet)
	return root


static func _build_ground_mesh(tiles: Array[Dictionary]) -> ArrayMesh:
	var ordered_tiles: Array[Dictionary] = []
	ordered_tiles.assign(tiles)
	ordered_tiles.sort_custom(_ground_tile_before)

	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var texture_size := Vector2(
		maxf(1.0, float(GROUND_ATLAS.get_width())),
		maxf(1.0, float(GROUND_ATLAS.get_height()))
	)
	var half := GROUND_DRAW_SIZE * 0.5
	var inset := 0.5

	for spec: Dictionary in ordered_tiles:
		var center: Vector2 = spec.get("position", Vector2.ZERO)
		var atlas_cell: Vector2i = spec.get("cell", Vector2i.ZERO)
		var vertex_start := vertices.size()

		vertices.append(center + Vector2(-half.x, -half.y))
		vertices.append(center + Vector2(half.x, -half.y))
		vertices.append(center + Vector2(half.x, half.y))
		vertices.append(center + Vector2(-half.x, half.y))

		var pixel_origin := Vector2(
			float(atlas_cell.x) * GROUND_ATLAS_CELL_SIZE,
			float(atlas_cell.y) * GROUND_ATLAS_CELL_SIZE
		)
		var pixel_end := pixel_origin + Vector2(GROUND_ATLAS_CELL_SIZE, GROUND_ATLAS_CELL_SIZE)
		for pixel_uv: Vector2 in [
			pixel_origin + Vector2(inset, inset),
			Vector2(pixel_end.x - inset, pixel_origin.y + inset),
			pixel_end - Vector2(inset, inset),
			Vector2(pixel_origin.x + inset, pixel_end.y - inset),
		]:
			uvs.append(Vector2(pixel_uv.x / texture_size.x, pixel_uv.y / texture_size.y))

		var tint: Color = spec.get("ground_tint", Color.WHITE)
		for _index in range(4):
			colors.append(tint)

		indices.append_array(PackedInt32Array([
			vertex_start,
			vertex_start + 1,
			vertex_start + 2,
			vertex_start,
			vertex_start + 2,
			vertex_start + 3,
		]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _ground_tile_before(a: Dictionary, b: Dictionary) -> bool:
	var a_position: Vector2 = a.get("position", Vector2.ZERO)
	var b_position: Vector2 = b.get("position", Vector2.ZERO)
	if is_equal_approx(a_position.y, b_position.y):
		return a_position.x < b_position.x
	return a_position.y < b_position.y


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
