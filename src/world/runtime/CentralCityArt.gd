extends RefCounted
class_name CentralCityArt

# Central City uses the project-supplied high-resolution Devil's Work.shop
# collection as source art. Runtime geometry stays on DigiGame's original
# 64x32 isometric contract; only the authored top face is sampled for interior
# floor cells. Perimeter cells additionally render the source block sides.
const GROUND_GRASS = preload("res://assets/world/devilsworkshop/city_1024/isometric_0056.png")
const GROUND_GRASS_CHECKER = preload("res://assets/world/devilsworkshop/city_1024/isometric_0053.png")
const GROUND_MINT = preload("res://assets/world/devilsworkshop/city_1024/isometric_0058.png")
const GROUND_MAIN = preload("res://assets/world/devilsworkshop/city_1024/isometric_0087.png")
const GROUND_STONE_SOFT = preload("res://assets/world/devilsworkshop/city_1024/isometric_0054.png")
const GROUND_TECH_TEAL = preload("res://assets/world/devilsworkshop/city_1024/isometric_0048.png")
const GROUND_TECH_BLUE = preload("res://assets/world/devilsworkshop/city_1024/isometric_0049.png")
const GROUND_TECH_PURPLE = preload("res://assets/world/devilsworkshop/city_1024/isometric_0050.png")
const GROUND_DARK = preload("res://assets/world/devilsworkshop/city_1024/isometric_0063.png")
const GROUND_WATER = preload("res://assets/world/devilsworkshop/city_1024/isometric_0064.png")
const GROUND_MARKET = preload("res://assets/world/devilsworkshop/city_1024/isometric_0009.png")
const GROUND_TRAINING = preload("res://assets/world/devilsworkshop/city_1024/isometric_0007.png")

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const TILE_HALF_WIDTH := TILE_WIDTH * 0.5
const TILE_HALF_HEIGHT := TILE_HEIGHT * 0.5
const FLOOR_OVERSCAN := Vector2(0.45, 0.22)

# Top-face coordinates measured from the 1024x1024 exports.
const SOURCE_TOP_LEFT := Vector2(92.0, 266.0)
const SOURCE_TOP_TOP := Vector2(512.0, 31.0)
const SOURCE_TOP_RIGHT := Vector2(932.0, 266.0)
const SOURCE_TOP_BOTTOM := Vector2(512.0, 502.0)
const SOURCE_TOP_WIDTH := 840.0
const SOURCE_TOP_HEIGHT := 471.0
const SOURCE_TOP_CENTER_Y := 266.0

# Full blocks are used only where authored depth is desirable (map perimeter
# and the temporary Devil's Work.shop interior shell). Non-uniform scaling
# maps the source top face exactly to the 64x32 gameplay diamond.
const FULL_BLOCK_SCALE := Vector2(
	TILE_WIDTH / SOURCE_TOP_WIDTH,
	TILE_HEIGHT / SOURCE_TOP_HEIGHT
)
const FULL_BLOCK_CENTER_OFFSET := Vector2(
	0.0,
	(512.0 - SOURCE_TOP_CENTER_Y) * FULL_BLOCK_SCALE.y
)
const BLOCK_LEVEL_HEIGHT := TILE_HEIGHT

const SURFACE_GRASS := "grass"
const SURFACE_GRASS_CHECKER := "grass_checker"
const SURFACE_MINT := "mint"
const SURFACE_MAIN := "main"
const SURFACE_STONE_SOFT := "stone_soft"
const SURFACE_TECH_TEAL := "tech_teal"
const SURFACE_TECH_BLUE := "tech_blue"
const SURFACE_TECH_PURPLE := "tech_purple"
const SURFACE_DARK := "dark"
const SURFACE_WATER := "water"
const SURFACE_MARKET := "market"
const SURFACE_TRAINING := "training"


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
		SURFACE_MARKET:
			return GROUND_MARKET
		SURFACE_TRAINING:
			return GROUND_TRAINING
		_:
			return GROUND_MAIN


static func surface_base_color(surface: String) -> Color:
	match surface:
		SURFACE_GRASS:
			return Color(0.32, 0.61, 0.22, 1.0)
		SURFACE_GRASS_CHECKER:
			return Color(0.37, 0.68, 0.20, 1.0)
		SURFACE_MINT:
			return Color(0.20, 0.62, 0.43, 1.0)
		SURFACE_STONE_SOFT:
			return Color(0.43, 0.43, 0.40, 1.0)
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
		SURFACE_MARKET:
			return Color(0.10, 0.66, 0.28, 1.0)
		SURFACE_TRAINING:
			return Color(0.40, 0.68, 0.14, 1.0)
		_:
			return Color(0.55, 0.72, 0.24, 1.0)


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
	base.z_index = 0
	root.add_child(base)

	# Only edge cells render the original block depth. The city interior remains
	# a perfectly flat 64x32 floor, while the island silhouette gets the authored
	# side faces requested for border tiles.
	var edge_specs: Array[Dictionary] = []
	for spec: Dictionary in tiles:
		if bool(spec.get("edge", false)):
			edge_specs.append(spec)
	edge_specs.sort_custom(_ground_spec_before)
	var edges := Node2D.new()
	edges.name = "EdgeBlocks"
	edges.z_index = 1
	root.add_child(edges)
	for spec: Dictionary in edge_specs:
		var edge := create_full_block(
			String(spec.get("surface", SURFACE_MAIN)),
			spec.get("position", Vector2.ZERO),
			0
		)
		edges.add_child(edge)

	var grouped: Dictionary = {}
	for spec: Dictionary in tiles:
		var surface := String(spec.get("surface", SURFACE_MAIN))
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
		detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		detail.z_index = 2
		root.add_child(detail)
	return root


static func create_surface_tile(
	surface: String,
	top_center: Vector2,
	depth_order: int,
	detail_alpha: float = 1.0,
	detail_tint: Color = Color.WHITE
) -> Node2D:
	var root := Node2D.new()
	root.position = top_center
	root.z_index = clampi(depth_order, -4000, 4000)

	var base := Polygon2D.new()
	base.name = "Base"
	base.polygon = tile_diamond(FLOOR_OVERSCAN)
	base.color = surface_base_color(surface)
	root.add_child(base)

	var detail := Polygon2D.new()
	detail.name = "TopFaceDetail"
	detail.polygon = tile_diamond()
	detail.texture = surface_texture(surface)
	detail.uv = PackedVector2Array([
		SOURCE_TOP_LEFT,
		SOURCE_TOP_TOP,
		SOURCE_TOP_RIGHT,
		SOURCE_TOP_BOTTOM,
	])
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	detail.color = Color(
		detail_tint.r,
		detail_tint.g,
		detail_tint.b,
		clampf(detail_alpha, 0.0, 1.0)
	)
	detail.z_index = 1
	root.add_child(detail)
	return root


static func create_full_block(
	surface: String,
	top_center: Vector2,
	depth_order: int,
	level: int = 0,
	tint: Color = Color.WHITE
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = surface_texture(surface)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = FULL_BLOCK_SCALE
	sprite.position = (
		top_center
		+ FULL_BLOCK_CENTER_OFFSET
		- Vector2(0.0, float(level) * BLOCK_LEVEL_HEIGHT)
	)
	sprite.z_index = clampi(depth_order + level, -4000, 4000)
	sprite.modulate = tint
	return sprite


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
			surface_base_color(String(spec.get("surface", SURFACE_MAIN)))
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


static func _ground_spec_before(a: Dictionary, b: Dictionary) -> bool:
	var a_pos: Vector2 = a.get("position", Vector2.ZERO)
	var b_pos: Vector2 = b.get("position", Vector2.ZERO)
	if is_equal_approx(a_pos.y, b_pos.y):
		return a_pos.x < b_pos.x
	return a_pos.y < b_pos.y
