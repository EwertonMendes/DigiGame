extends RefCounted
class_name CentralCityArt

# Central City deliberately has its own exterior renderer. Interiors, the legacy
# Hub and tactical battlefields keep their existing 64x32 contracts.
const ATLAS = preload("res://assets/terrain/MCBlocksColorOutline.png")

# High-resolution Devil's Work.shop source blocks used only for the Central City
# exterior. The complete 1024x1024 source files stay untouched in the repository;
# only their authored top faces are sampled onto the gameplay diamond.
const GROUND_GRASS = preload("res://assets/world/devilsworkshop/city_1024/isometric_0056.png")
const GROUND_GRASS_CHECKER = preload("res://assets/world/devilsworkshop/city_1024/isometric_0053.png")
const GROUND_MINT = preload("res://assets/world/devilsworkshop/city_1024/isometric_0058.png")
const GROUND_STONE = preload("res://assets/world/devilsworkshop/city_1024/isometric_0055.png")
const GROUND_STONE_SOFT = preload("res://assets/world/devilsworkshop/city_1024/isometric_0054.png")
const GROUND_TECH_TEAL = preload("res://assets/world/devilsworkshop/city_1024/isometric_0048.png")
const GROUND_TECH_BLUE = preload("res://assets/world/devilsworkshop/city_1024/isometric_0049.png")
const GROUND_TECH_PURPLE = preload("res://assets/world/devilsworkshop/city_1024/isometric_0050.png")
const GROUND_DARK = preload("res://assets/world/devilsworkshop/city_1024/isometric_0063.png")
const GROUND_WATER = preload("res://assets/world/devilsworkshop/city_1024/isometric_0064.png")
const GROUND_YELLOW = preload("res://assets/world/devilsworkshop/city_1024/isometric_0001.png")
const GROUND_LIME_CHECKER = preload("res://assets/world/devilsworkshop/city_1024/isometric_0007.png")

const CELL_SIZE := 32.0
const TILE_WIDTH := 128.0
const TILE_HEIGHT := 64.0
const TILE_HALF_WIDTH := TILE_WIDTH * 0.5
const TILE_HALF_HEIGHT := TILE_HEIGHT * 0.5
const FLOOR_OVERSCAN := Vector2(0.90, 0.45)
const EXTERIOR_SCALE := 2.0
const BLOCK_SCALE := Vector2(4.0, 4.0)
const BLOCK_TOP_CENTER_OFFSET := Vector2(0.0, 24.0)
const BLOCK_LEVEL_HEIGHT := 64.0

# The high-resolution files are the same authored blocks as the original
# Devil's Work.shop exports at a larger source resolution. These coordinates
# are the 1024px equivalents of the pack's top-face diamond.
const SOURCE_TOP_LEFT := Vector2(92.0, 266.0)
const SOURCE_TOP_TOP := Vector2(512.0, 31.0)
const SOURCE_TOP_RIGHT := Vector2(932.0, 266.0)
const SOURCE_TOP_BOTTOM := Vector2(512.0, 502.0)

# MCBlocks atlas top face, retained for existing Central City structures.
const FLOOR_LEFT := Vector2(4.0, 21.0)
const FLOOR_TOP := Vector2(16.0, 14.0)
const FLOOR_RIGHT := Vector2(28.0, 21.0)
const FLOOR_BOTTOM := Vector2(16.0, 28.0)

const SURFACE_GRASS := "grass"
const SURFACE_GRASS_CHECKER := "grass_checker"
const SURFACE_MINT := "mint"
const SURFACE_STONE := "stone"
const SURFACE_STONE_SOFT := "stone_soft"
const SURFACE_TECH_TEAL := "tech_teal"
const SURFACE_TECH_BLUE := "tech_blue"
const SURFACE_TECH_PURPLE := "tech_purple"
const SURFACE_DARK := "dark"
const SURFACE_WATER := "water"
const SURFACE_YELLOW := "yellow"
const SURFACE_LIME_CHECKER := "lime_checker"


static func tile_diamond(overscan := Vector2.ZERO) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-TILE_HALF_WIDTH - overscan.x, 0.0),
		Vector2(0.0, -TILE_HALF_HEIGHT - overscan.y),
		Vector2(TILE_HALF_WIDTH + overscan.x, 0.0),
		Vector2(0.0, TILE_HALF_HEIGHT + overscan.y),
	])


static func surface_texture(surface: String) -> Texture2D:
	match surface:
		SURFACE_GRASS:
			return GROUND_GRASS
		SURFACE_GRASS_CHECKER:
			return GROUND_GRASS_CHECKER
		SURFACE_MINT:
			return GROUND_MINT
		SURFACE_STONE_SOFT:
			return GROUND_STONE_SOFT
		SURFACE_TECH_TEAL:
			return GROUND_TECH_TEAL
		SURFACE_TECH_BLUE:
			return GROUND_TECH_BLUE
		SURFACE_TECH_PURPLE:
			return GROUND_TECH_PURPLE
		SURFACE_DARK:
			return GROUND_DARK
		SURFACE_WATER:
			return GROUND_WATER
		SURFACE_YELLOW:
			return GROUND_YELLOW
		SURFACE_LIME_CHECKER:
			return GROUND_LIME_CHECKER
		_:
			return GROUND_STONE


static func surface_base_color(surface: String) -> Color:
	match surface:
		SURFACE_GRASS:
			return Color(0.31, 0.60, 0.22, 1.0)
		SURFACE_GRASS_CHECKER:
			return Color(0.35, 0.66, 0.20, 1.0)
		SURFACE_MINT:
			return Color(0.20, 0.62, 0.43, 1.0)
		SURFACE_TECH_TEAL:
			return Color(0.10, 0.37, 0.36, 1.0)
		SURFACE_TECH_BLUE:
			return Color(0.12, 0.27, 0.50, 1.0)
		SURFACE_TECH_PURPLE:
			return Color(0.31, 0.14, 0.47, 1.0)
		SURFACE_DARK:
			return Color(0.16, 0.17, 0.17, 1.0)
		SURFACE_WATER:
			return Color(0.04, 0.58, 0.72, 1.0)
		SURFACE_YELLOW:
			return Color(0.57, 0.55, 0.13, 1.0)
		SURFACE_LIME_CHECKER:
			return Color(0.39, 0.68, 0.14, 1.0)
		SURFACE_STONE_SOFT:
			return Color(0.43, 0.43, 0.40, 1.0)
		_:
			return Color(0.43, 0.45, 0.45, 1.0)


static func create_ground_batch(
	tiles: Array[Dictionary],
	depth_order: int,
	node_name: String = "CentralCityGround"
) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.z_index = clampi(depth_order, -4000, 4000)
	if tiles.is_empty():
		return root

	var base := MeshInstance2D.new()
	base.name = "BaseMesh"
	base.mesh = _build_ground_base_mesh(tiles)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(base)

	var grouped: Dictionary = {}
	for spec: Dictionary in tiles:
		var surface := String(spec.get("surface", SURFACE_STONE))
		if not grouped.has(surface):
			grouped[surface] = []
		var bucket: Array = grouped[surface]
		bucket.append(spec)
		grouped[surface] = bucket

	var surfaces: Array = grouped.keys()
	surfaces.sort()
	for surface_value in surfaces:
		var surface := String(surface_value)
		var detail := MeshInstance2D.new()
		detail.name = "Surface_%s" % surface
		detail.mesh = _build_ground_surface_mesh(grouped[surface] as Array)
		detail.texture = surface_texture(surface)
		# These are 1024px source faces being reduced to a 128x64 gameplay
		# diamond. Linear filtering preserves the source detail instead of
		# introducing nearest-neighbour shimmer while the camera moves.
		detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		detail.z_index = 1
		root.add_child(detail)
	return root


static func _build_ground_base_mesh(tiles: Array[Dictionary]) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var diamond := tile_diamond(FLOOR_OVERSCAN)

	for spec: Dictionary in tiles:
		var center: Vector2 = spec.get("position", Vector2.ZERO)
		var vertex_start := vertices.size()
		for point: Vector2 in diamond:
			vertices.append(center + point)
		var color: Color = spec.get(
			"base_color",
			surface_base_color(String(spec.get("surface", SURFACE_STONE)))
		)
		for _index in range(4):
			colors.append(color)
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
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _build_ground_surface_mesh(tiles: Array) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var diamond := tile_diamond()
	var texture_size := Vector2(1024.0, 1024.0)
	var source_uvs := PackedVector2Array([
		SOURCE_TOP_LEFT,
		SOURCE_TOP_TOP,
		SOURCE_TOP_RIGHT,
		SOURCE_TOP_BOTTOM,
	])

	for raw_spec in tiles:
		if not raw_spec is Dictionary:
			continue
		var spec := raw_spec as Dictionary
		var center: Vector2 = spec.get("position", Vector2.ZERO)
		var vertex_start := vertices.size()
		for point: Vector2 in diamond:
			vertices.append(center + point)
		for pixel_uv: Vector2 in source_uvs:
			uvs.append(Vector2(pixel_uv.x / texture_size.x, pixel_uv.y / texture_size.y))
		var tint: Color = spec.get("detail_tint", Color.WHITE)
		var alpha := clampf(float(spec.get("detail_alpha", 1.0)), 0.0, 1.0)
		var color := Color(tint.r, tint.g, tint.b, alpha)
		for _index in range(4):
			colors.append(color)
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
	base.mesh = _build_mc_floor_mesh(tiles, false)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(base)

	var detail := MeshInstance2D.new()
	detail.name = "DetailMesh"
	detail.mesh = _build_mc_floor_mesh(tiles, true)
	detail.texture = ATLAS
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail.z_index = 1
	root.add_child(detail)
	return root


static func _build_mc_floor_mesh(tiles: Array[Dictionary], textured: bool) -> ArrayMesh:
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
	var exterior_scale := scale * EXTERIOR_SCALE
	sprite.scale = exterior_scale
	sprite.position = (
		ground_anchor
		+ offset * EXTERIOR_SCALE
		- Vector2(0.0, 12.0 * exterior_scale.y)
	)
	sprite.z_index = clampi(depth_order, -4000, 4000)
	sprite.modulate = tint
	return sprite
