extends RefCounted
class_name CentralCityHDAtlasArt

# Visual experiment only: Central City keeps the exact MC Blocks logical grid
# and world geometry, but selected cells are redrawn from the normalized AI kit.
# Any cell we did not replace delegates to the original atlas, so gameplay,
# collision, trees and miscellaneous props stay unchanged during the test.
const ORIGINAL = preload("res://src/world/runtime/CityAtlasArt.gd")
const HD_ATLAS = preload("res://assets/terrain/central_city_hd_test_atlas.png")

const HD_CELL_SIZE := 32.0
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const TILE_HALF_WIDTH := TILE_WIDTH * 0.5
const TILE_HALF_HEIGHT := TILE_HEIGHT * 0.5
const FLOOR_OVERSCAN := Vector2(0.55, 0.28)

# The AI source was normalized to the exact MC Blocks cell geometry. The compact
# test atlas stores 32px cells and uses smooth 2x display scaling, preserving the
# same 64x32 world footprint without nearest-neighbor pixelation.
const FLOOR_LEFT := Vector2(4.0, 21.0)
const FLOOR_TOP := Vector2(16.0, 14.0)
const FLOOR_RIGHT := Vector2(28.0, 21.0)
const FLOOR_BOTTOM := Vector2(16.0, 28.0)

# One structural level remains exactly 32 world pixels high.
const BLOCK_LEVEL_HEIGHT := 32.0


static func tile_diamond(overscan := Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-TILE_HALF_WIDTH - overscan.x, 0.0),
		Vector2(0.0, -TILE_HALF_HEIGHT - overscan.y),
		Vector2(TILE_HALF_WIDTH + overscan.x, 0.0),
		Vector2(0.0, TILE_HALF_HEIGHT + overscan.y),
	])


static func has_hd_cell(cell: Vector2i) -> bool:
	return _hd_slot(cell).x >= 0


static func atlas_texture(cell: Vector2i) -> AtlasTexture:
	var slot := _hd_slot(cell)
	if slot.x < 0:
		return ORIGINAL.atlas_texture(cell)
	var texture := AtlasTexture.new()
	texture.atlas = HD_ATLAS
	texture.region = Rect2(
		float(slot.x) * HD_CELL_SIZE,
		float(slot.y) * HD_CELL_SIZE,
		HD_CELL_SIZE,
		HD_CELL_SIZE
	)
	return texture


static func create_floor_tile(
	cell: Vector2i,
	top_center: Vector2,
	depth_order: int,
	base_color: Color,
	detail_tint: Color = Color.WHITE,
	_detail_alpha: float = 1.0
) -> Node2D:
	if not _is_hd_floor(cell):
		return ORIGINAL.create_floor_tile(cell, top_center, depth_order, base_color, detail_tint, 1.0)

	var root := Node2D.new()
	root.position = top_center
	root.z_index = clampi(depth_order, -4000, 4000)

	var base := Polygon2D.new()
	base.name = "Base"
	base.polygon = tile_diamond(FLOOR_OVERSCAN)
	base.color = base_color
	root.add_child(base)

	var slot := _hd_slot(cell)
	var slot_origin := Vector2(float(slot.x) * HD_CELL_SIZE, float(slot.y) * HD_CELL_SIZE)
	var detail := Polygon2D.new()
	detail.name = "HDAtlasFloor"
	detail.polygon = tile_diamond()
	detail.texture = HD_ATLAS
	detail.uv = PackedVector2Array([
		slot_origin + FLOOR_LEFT,
		slot_origin + FLOOR_TOP,
		slot_origin + FLOOR_RIGHT,
		slot_origin + FLOOR_BOTTOM,
	])
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# The old atlas detail was intentionally faint over a color base. These new
	# floor cells already contain their finished material, so render them fully.
	detail.color = Color(detail_tint.r, detail_tint.g, detail_tint.b, 1.0)
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
	base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(base)

	var detail := MeshInstance2D.new()
	detail.name = "HDDetailMesh"
	detail.mesh = _build_floor_mesh(tiles, true)
	detail.texture = HD_ATLAS
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	detail.z_index = 1
	root.add_child(detail)
	return root


static func _build_floor_mesh(tiles: Array[Dictionary], textured: bool) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var texture_size := Vector2(
		maxf(1.0, float(HD_ATLAS.get_width())),
		maxf(1.0, float(HD_ATLAS.get_height()))
	)
	var diamond := tile_diamond(Vector2.ZERO if textured else FLOOR_OVERSCAN)

	for spec: Dictionary in tiles:
		var center: Vector2 = spec.get("position", Vector2.ZERO)
		var vertex_start := vertices.size()
		for point: Vector2 in diamond:
			vertices.append(center + point)

		if textured:
			var logical_cell: Vector2i = spec.get("cell", Vector2i.ZERO)
			var slot := _hd_slot(logical_cell)
			if slot.x < 0:
				# Central City currently uses only the nine floor cells covered by
				# this test atlas. Make an unsupported cell fail visibly instead of
				# silently sampling an unrelated texture.
				push_error("[CentralCityHDAtlas] missing HD floor mapping for %s" % str(logical_cell))
				slot = Vector2i(1, 0)
			var slot_origin := Vector2(float(slot.x) * HD_CELL_SIZE, float(slot.y) * HD_CELL_SIZE)
			var pixel_uvs := PackedVector2Array([
				slot_origin + FLOOR_LEFT,
				slot_origin + FLOOR_TOP,
				slot_origin + FLOOR_RIGHT,
				slot_origin + FLOOR_BOTTOM,
			])
			for pixel_uv: Vector2 in pixel_uvs:
				uvs.append(Vector2(pixel_uv.x / texture_size.x, pixel_uv.y / texture_size.y))
			var detail_tint: Color = spec.get("detail_tint", Color.WHITE)
			var detail_color := Color(detail_tint.r, detail_tint.g, detail_tint.b, 1.0)
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


static func create_block(
	cell: Vector2i,
	top_center: Vector2,
	depth_order: int,
	level: int = 0,
	tint: Color = Color.WHITE
) -> Sprite2D:
	if not _is_hd_block(cell):
		return ORIGINAL.create_block(cell, top_center, depth_order, level, tint)

	var sprite := Sprite2D.new()
	sprite.texture = atlas_texture(cell)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2(2.0, 2.0)
	# The compact atlas is 32px per cell. Smooth 2x rendering reproduces the
	# exact world-space footprint of the normalized 64px source.
	sprite.position = top_center - Vector2(0.0, float(level) * BLOCK_LEVEL_HEIGHT)
	sprite.z_index = clampi(depth_order + level, -4000, 4000)
	sprite.modulate = tint
	sprite.add_to_group("central_city_hd_asset")
	return sprite


static func create_prop(
	cell: Vector2i,
	ground_anchor: Vector2,
	depth_order: int,
	scale := Vector2(2.0, 2.0),
	tint: Color = Color.WHITE,
	offset := Vector2.ZERO
) -> Sprite2D:
	if not _is_hd_prop(cell):
		return ORIGINAL.create_prop(cell, ground_anchor, depth_order, scale, tint, offset)

	var sprite := Sprite2D.new()
	sprite.texture = atlas_texture(cell)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# Call-site scales already target a 32px atlas cell, so the compact HD test
	# atlas can use them directly while keeping linear filtering.
	var hd_scale := scale
	sprite.scale = hd_scale

	var foot_y := 27.0 if cell == Vector2i(15, 47) else 25.0
	var center_to_foot := (foot_y - HD_CELL_SIZE * 0.5) * hd_scale.y
	sprite.position = ground_anchor + offset - Vector2(0.0, center_to_foot)
	sprite.z_index = clampi(depth_order, -4000, 4000)
	sprite.modulate = tint
	sprite.add_to_group("central_city_hd_asset")
	return sprite


static func _is_hd_floor(cell: Vector2i) -> bool:
	return (
		cell == Vector2i(12, 16)
		or cell == Vector2i(13, 16)
		or cell == Vector2i(14, 16)
		or cell == Vector2i(8, 16)
		or cell == Vector2i(9, 16)
		or cell == Vector2i(10, 16)
		or cell == Vector2i(15, 16)
		or cell == Vector2i(16, 16)
		or cell == Vector2i(5, 16)
	)


static func _is_hd_block(cell: Vector2i) -> bool:
	return (
		cell == Vector2i(3, 13)
		or cell == Vector2i(2, 13)
		or cell == Vector2i(11, 13)
		or cell == Vector2i(6, 13)
		or cell == Vector2i(14, 13)
		or cell == Vector2i(15, 13)
		or cell == Vector2i(16, 13)
		or cell == Vector2i(5, 13)
		or cell == Vector2i(11, 3)
	)


static func _is_hd_prop(cell: Vector2i) -> bool:
	return (
		cell == Vector2i(15, 47)
		or cell == Vector2i(10, 15)
		or cell == Vector2i(15, 15)
		or cell == Vector2i(12, 15)
		or cell == Vector2i(11, 15)
		or cell == Vector2i(17, 15)
	)


static func _hd_slot(cell: Vector2i) -> Vector2i:
	# Row 0: generated floors.
	if cell == Vector2i(12, 16):
		return Vector2i(0, 0) # road
	if cell == Vector2i(13, 16):
		return Vector2i(1, 0) # pavement
	if cell == Vector2i(14, 16):
		return Vector2i(2, 0) # plaza
	if cell == Vector2i(8, 16):
		return Vector2i(3, 0) # cyan floor
	if cell == Vector2i(9, 16):
		return Vector2i(4, 0) # yellow floor
	if cell == Vector2i(10, 16):
		return Vector2i(5, 0) # green floor
	if cell == Vector2i(15, 16):
		return Vector2i(6, 0) # purple floor
	if cell == Vector2i(16, 16):
		return Vector2i(7, 0) # water

	# Row 1: final floor + structural blocks.
	if cell == Vector2i(5, 16):
		return Vector2i(0, 1) # white floor
	if cell == Vector2i(3, 13):
		return Vector2i(1, 1) # gray wall
	if cell == Vector2i(2, 13):
		return Vector2i(2, 1) # dark wall
	if cell == Vector2i(11, 13):
		return Vector2i(3, 1) # white wall
	if cell == Vector2i(6, 13):
		return Vector2i(4, 1) # blue wall
	if cell == Vector2i(14, 13):
		return Vector2i(5, 1) # teal wall
	if cell == Vector2i(15, 13):
		return Vector2i(6, 1) # yellow wall
	if cell == Vector2i(16, 13):
		return Vector2i(7, 1) # green wall

	# Row 2: final blocks + facade modules.
	if cell == Vector2i(5, 13):
		return Vector2i(0, 2) # purple wall
	if cell == Vector2i(11, 3):
		return Vector2i(1, 2) # glass
	if cell == Vector2i(15, 47):
		return Vector2i(2, 2) # door
	if cell == Vector2i(10, 15):
		return Vector2i(3, 2) # cyan window
	if cell == Vector2i(15, 15):
		return Vector2i(4, 2) # white window
	if cell == Vector2i(12, 15):
		return Vector2i(5, 2) # green window
	if cell == Vector2i(11, 15):
		return Vector2i(6, 2) # yellow window
	if cell == Vector2i(17, 15):
		return Vector2i(7, 2) # purple window

	return Vector2i(-1, -1)
