extends RefCounted
class_name CentralCitySheetArt

const ATLAS = preload("res://assets/terrain/central_city_sheet_atlas.png")

const CELL_SIZE := 64.0
const COLUMNS := 5
const TILE_HALF_WIDTH := 32.0
const TILE_HALF_HEIGHT := 16.0
const BACKING_OVERSCAN := Vector2(0.75, 0.40)

# Compact runtime atlas prepared from the project-owner supplied Central City
# test sheet. Each atlas slot keeps the original drawing intact inside a
# transparent 64x64 cell whose visual top-face centre is aligned to the cell
# centre. This lets the large city remain one batched draw instead of creating
# thousands of Sprite2D nodes.
const ROAD_PLAIN := 0
const ROAD_LANE := 1
const ROAD_EDGE := 2
const ROAD_VARIANT := 3
const CROSSWALK_A := 4
const CROSSWALK_B := 5
const ROAD_ARROW := 6
const ROAD_TECH := 7
const PAVEMENT_GRAY := 8
const PAVEMENT_TAN := 9
const PAVEMENT_STONE := 10
const TECH_PAVER := 11
const GRASS := 12
const GRASS_ALT := 13
const SAND := 14
const DIRT := 15
const WATER := 16


static func create_ground_batch(
	tiles: Array[Dictionary],
	depth_order: int,
	node_name: String = "CityGround"
) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.z_index = clampi(depth_order, -4000, 4000)
	if tiles.is_empty():
		return root

	var ordered: Array[Dictionary] = tiles.duplicate(true)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa: Vector2 = a.get("position", Vector2.ZERO)
		var pb: Vector2 = b.get("position", Vector2.ZERO)
		return pa.x < pb.x if is_equal_approx(pa.y, pb.y) else pa.y < pb.y
	)

	# A tiny colour-matched diamond underneath every sprite closes sub-pixel
	# seams without replacing any of the supplied artwork.
	var backing := MeshInstance2D.new()
	backing.name = "BackingMesh"
	backing.mesh = _build_backing_mesh(ordered)
	backing.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(backing)

	var detail := MeshInstance2D.new()
	detail.name = "SheetTileMesh"
	detail.mesh = _build_tile_mesh(ordered)
	detail.texture = ATLAS
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	detail.z_index = 1
	root.add_child(detail)
	return root


static func _build_backing_mesh(tiles: Array[Dictionary]) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var diamond := PackedVector2Array([
		Vector2(-TILE_HALF_WIDTH - BACKING_OVERSCAN.x, 0.0),
		Vector2(0.0, -TILE_HALF_HEIGHT - BACKING_OVERSCAN.y),
		Vector2(TILE_HALF_WIDTH + BACKING_OVERSCAN.x, 0.0),
		Vector2(0.0, TILE_HALF_HEIGHT + BACKING_OVERSCAN.y),
	])

	for spec: Dictionary in tiles:
		var center: Vector2 = spec.get("position", Vector2.ZERO)
		var start := vertices.size()
		for point: Vector2 in diamond:
			vertices.append(center + point)
		var base_color: Color = spec.get("base_color", Color(0.32, 0.34, 0.35, 1.0))
		for _index in range(4):
			colors.append(base_color)
		indices.append_array(PackedInt32Array([
			start,
			start + 1,
			start + 2,
			start,
			start + 2,
			start + 3,
		]))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _build_tile_mesh(tiles: Array[Dictionary]) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var texture_size := Vector2(
		maxf(1.0, float(ATLAS.get_width())),
		maxf(1.0, float(ATLAS.get_height()))
	)
	var half := CELL_SIZE * 0.5
	var quad := PackedVector2Array([
		Vector2(-half, -half),
		Vector2(half, -half),
		Vector2(half, half),
		Vector2(-half, half),
	])

	for spec: Dictionary in tiles:
		var center: Vector2 = spec.get("position", Vector2.ZERO)
		var start := vertices.size()
		for point: Vector2 in quad:
			vertices.append(center + point)

		var tile_id := clampi(int(spec.get("sheet_tile", PAVEMENT_GRAY)), 0, WATER)
		var column := tile_id % COLUMNS
		var row := int(tile_id / COLUMNS)
		var origin := Vector2(float(column) * CELL_SIZE, float(row) * CELL_SIZE)
		var pixel_uvs := PackedVector2Array([
			origin,
			origin + Vector2(CELL_SIZE, 0.0),
			origin + Vector2(CELL_SIZE, CELL_SIZE),
			origin + Vector2(0.0, CELL_SIZE),
		])
		for pixel_uv: Vector2 in pixel_uvs:
			uvs.append(Vector2(pixel_uv.x / texture_size.x, pixel_uv.y / texture_size.y))

		var tint: Color = spec.get("detail_tint", Color.WHITE)
		for _index in range(4):
			colors.append(tint)
		indices.append_array(PackedInt32Array([
			start,
			start + 1,
			start + 2,
			start,
			start + 2,
			start + 3,
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
