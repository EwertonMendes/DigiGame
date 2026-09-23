extends RefCounted
class_name CityAtlasArt

const ATLAS = preload("res://assets/terrain/MCBlocksColorOutline.png")
const HUB_GRASS = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0000.png")
const HUB_WARM = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0001.png")
const HUB_DATA = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0005.png")
const HUB_WATER = preload("res://assets/world/devilsworkshop/blocks/isometric_pixel_0020.png")

const CELL_SIZE := 32.0
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const TILE_HALF_WIDTH := TILE_WIDTH * 0.5
const TILE_HALF_HEIGHT := TILE_HEIGHT * 0.5
const FLOOR_OVERSCAN := Vector2(0.55, 0.28)
const BLOCK_SCALE := Vector2(2.0, 2.0)
const BLOCK_TOP_CENTER_OFFSET := Vector2(0.0, 12.0)
const BLOCK_LEVEL_HEIGHT := 32.0

# Central City walls use a slightly oversized presentation of the same MC
# Blocks cells. The source sprites include transparent breathing room around
# each cube; at the original scale this reads as detached blocks. A small,
# uniform overscale closes that authored padding without changing the grid,
# collision footprint or atlas source.
const JOINED_BLOCK_SCALE := Vector2(2.30, 2.30)
const JOINED_BLOCK_TOP_CENTER_OFFSET := Vector2(0.0, 13.80)
const JOINED_BLOCK_LEVEL_HEIGHT := 28.0

# Every flat-floor icon in row 16 shares this authored diamond footprint
# inside its 32x32 atlas cell.
const FLOOR_LEFT := Vector2(4.0, 21.0)
const FLOOR_TOP := Vector2(16.0, 14.0)
const FLOOR_RIGHT := Vector2(28.0, 21.0)
const FLOOR_BOTTOM := Vector2(16.0, 28.0)

# The floor art itself has a dark one-to-two-pixel outline. Sampling slightly
# inside that authored diamond removes the outline while preserving the actual
# MC Blocks material/detail. The inner sample is stretched back over the exact
# 64x32 world diamond, so neighboring tiles meet with no visible gap.
const FLOOR_SAMPLE_LEFT := Vector2(6.0, 21.0)
const FLOOR_SAMPLE_TOP := Vector2(16.0, 16.0)
const FLOOR_SAMPLE_RIGHT := Vector2(26.0, 21.0)
const FLOOR_SAMPLE_BOTTOM := Vector2(16.0, 26.0)


# Central City ground now reuses the exact top-face textures from the approved
# Test Hub. Those source blocks have no heavy black border baked into the
# sampled top face, and the detail is intentionally blended over an opaque base
# just like HubVisualRedesign.gd. This keeps roads and paving textured while the
# 64x32 gameplay diamonds read as continuous surfaces.
const HUB_SOURCE_LEFT := Vector2(4.5, 13.0)
const HUB_SOURCE_TOP := Vector2(25.0, 1.5)
const HUB_SOURCE_RIGHT := Vector2(45.5, 13.0)
const HUB_SOURCE_BOTTOM := Vector2(25.0, 24.5)


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

	var resolved_detail_alpha := clampf(detail_alpha, 0.0, 1.0)
	if resolved_detail_alpha > 0.001:
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
			resolved_detail_alpha
		)
		detail.z_index = 1
		root.add_child(detail)
	return root


static func create_floor_batch(
	tiles: Array[Dictionary],
	depth_order: int,
	node_name: String = "FloorBatch"
) -> Node2D:
	# Generic MC Blocks batch used by interiors and any non-Central-City caller.
	# Keep its original atlas semantics intact.
	var root := Node2D.new()
	root.name = node_name
	root.z_index = clampi(depth_order, -4000, 4000)
	if tiles.is_empty():
		return root

	var base := MeshInstance2D.new()
	base.name = "BaseMesh"
	base.mesh = _build_mcblocks_floor_mesh(tiles, false)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(base)

	var has_visible_detail := false
	for spec: Dictionary in tiles:
		if float(spec.get("detail_alpha", 1.0)) > 0.001:
			has_visible_detail = true
			break
	if has_visible_detail:
		var detail := MeshInstance2D.new()
		detail.name = "DetailMesh"
		detail.mesh = _build_mcblocks_floor_mesh(tiles, true)
		detail.texture = ATLAS
		detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		detail.z_index = 1
		root.add_child(detail)
	return root


static func create_city_surface_batch(
	tiles: Array[Dictionary],
	depth_order: int,
	node_name: String = "CitySurfaceBatch"
) -> Node2D:
	# Central City only: reuse the approved Test Hub top-face materials and its
	# low-opacity blending strategy, while keeping the same global batched
	# renderer and exact 64x32 gameplay geometry.
	var root := Node2D.new()
	root.name = node_name
	root.z_index = clampi(depth_order, -4000, 4000)
	if tiles.is_empty():
		return root

	var base := MeshInstance2D.new()
	base.name = "BaseMesh"
	base.mesh = _build_base_floor_mesh(tiles)
	base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(base)

	var groups: Dictionary = {}
	for spec: Dictionary in tiles:
		var alpha := clampf(float(spec.get("detail_alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.001:
			continue
		var surface := String(spec.get("surface", "warm"))
		if not groups.has(surface):
			groups[surface] = []
		(groups[surface] as Array).append(spec)

	for surface_variant in groups.keys():
		var surface := String(surface_variant)
		var detail_tiles: Array = groups[surface]
		var texture := _hub_surface_texture(surface)
		var detail := MeshInstance2D.new()
		detail.name = "Detail_%s" % surface.capitalize()
		detail.mesh = _build_hub_surface_mesh(detail_tiles, texture)
		detail.texture = texture
		detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		detail.z_index = 1
		root.add_child(detail)

	return root


static func _build_mcblocks_floor_mesh(tiles: Array[Dictionary], textured: bool) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var texture_size := Vector2(
		maxf(1.0, float(ATLAS.get_width())),
		maxf(1.0, float(ATLAS.get_height()))
	)
	var diamond := tile_diamond(Vector2.ZERO if textured else FLOOR_OVERSCAN)

	for spec: Dictionary in tiles:
		var center: Vector2 = spec.get("position", Vector2.ZERO)
		var vertex_start := vertices.size()
		for point: Vector2 in diamond:
			vertices.append(center + point)

		if textured:
			var atlas_cell: Vector2i = spec.get("cell", Vector2i.ZERO)
			var cell_origin := Vector2(
				float(atlas_cell.x) * CELL_SIZE,
				float(atlas_cell.y) * CELL_SIZE
			)
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
			var detail_color := Color(
				detail_tint.r,
				detail_tint.g,
				detail_tint.b,
				detail_alpha
			)
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


static func _build_base_floor_mesh(tiles: Array[Dictionary]) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var diamond := tile_diamond(FLOOR_OVERSCAN)

	for spec: Dictionary in tiles:
		var center: Vector2 = spec.get("position", Vector2.ZERO)
		var vertex_start := vertices.size()
		for point: Vector2 in diamond:
			vertices.append(center + point)
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
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _build_hub_surface_mesh(tiles: Array, texture: Texture2D) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var diamond := tile_diamond()
	var texture_size := Vector2(
		maxf(1.0, float(texture.get_width())),
		maxf(1.0, float(texture.get_height()))
	)
	var source_uvs := PackedVector2Array([
		HUB_SOURCE_LEFT,
		HUB_SOURCE_TOP,
		HUB_SOURCE_RIGHT,
		HUB_SOURCE_BOTTOM,
	])

	for raw_spec in tiles:
		var spec: Dictionary = raw_spec
		var center: Vector2 = spec.get("position", Vector2.ZERO)
		var vertex_start := vertices.size()
		for point: Vector2 in diamond:
			vertices.append(center + point)
		for pixel_uv: Vector2 in source_uvs:
			uvs.append(Vector2(pixel_uv.x / texture_size.x, pixel_uv.y / texture_size.y))
		var detail_tint: Color = spec.get("detail_tint", Color.WHITE)
		var detail_alpha := clampf(float(spec.get("detail_alpha", 0.42)), 0.0, 1.0)
		var detail_color := Color(
			detail_tint.r,
			detail_tint.g,
			detail_tint.b,
			detail_alpha
		)
		for _index in range(4):
			colors.append(detail_color)
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


static func _hub_surface_texture(surface: String) -> Texture2D:
	match surface:
		"grass":
			return HUB_GRASS
		"data":
			return HUB_DATA
		"water":
			return HUB_WATER
		_:
			return HUB_WARM


static func create_city_wall_segment(
	ground_start: Vector2,
	ground_end: Vector2,
	height: float,
	base_color: Color,
	accent_color: Color,
	depth_order: int,
	node_name: String = "WallSurface",
	show_accent: bool = true,
	show_top_edge: bool = true
) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.z_index = clampi(depth_order, -4000, 4000)
	root.add_to_group("central_city_wall_surface")

	var lift := Vector2(0.0, maxf(1.0, height))
	var face := Polygon2D.new()
	face.name = "Face"
	face.polygon = PackedVector2Array([
		ground_start,
		ground_end,
		ground_end - lift,
		ground_start - lift,
	])
	face.color = base_color
	root.add_child(face)

	var shade_height := height * 0.34
	var upper := Polygon2D.new()
	upper.name = "UpperWash"
	upper.polygon = PackedVector2Array([
		ground_start - Vector2(0.0, height - shade_height),
		ground_end - Vector2(0.0, height - shade_height),
		ground_end - lift,
		ground_start - lift,
	])
	var upper_color := base_color.lightened(0.10)
	upper.color = Color(upper_color.r, upper_color.g, upper_color.b, 0.28)
	upper.z_index = 1
	root.add_child(upper)

	if show_accent:
		var accent_y := height * 0.64
		var accent := Line2D.new()
		accent.name = "AccentBand"
		accent.points = PackedVector2Array([
			ground_start - Vector2(0.0, accent_y),
			ground_end - Vector2(0.0, accent_y),
		])
		accent.width = 5.0
		accent.default_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.82)
		accent.antialiased = true
		accent.z_index = 2
		root.add_child(accent)

	if show_top_edge:
		var top_edge := Line2D.new()
		top_edge.name = "TopEdge"
		top_edge.points = PackedVector2Array([
			ground_start - lift,
			ground_end - lift,
		])
		top_edge.width = 2.0
		var edge_color := accent_color.lightened(0.24)
		top_edge.default_color = Color(edge_color.r, edge_color.g, edge_color.b, 0.58)
		top_edge.antialiased = true
		top_edge.z_index = 3
		root.add_child(top_edge)

	return root


static func create_city_door_panel(
	ground_start: Vector2,
	ground_end: Vector2,
	height: float,
	accent_color: Color,
	depth_order: int,
	node_name: String = "DoorPanel"
) -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.z_index = clampi(depth_order, -4000, 4000)
	root.add_to_group("central_city_door_surface")

	var bottom_a := ground_start.lerp(ground_end, 0.14)
	var bottom_b := ground_start.lerp(ground_end, 0.86)
	var lift := Vector2(0.0, maxf(1.0, height))
	var top_a := bottom_a - lift
	var top_b := bottom_b - lift

	var panel := Polygon2D.new()
	panel.name = "Panel"
	panel.polygon = PackedVector2Array([
		bottom_a,
		bottom_b,
		top_b,
		top_a,
	])
	panel.color = Color(0.055, 0.075, 0.085, 1.0)
	root.add_child(panel)

	var frame := Line2D.new()
	frame.name = "Frame"
	frame.points = PackedVector2Array([
		bottom_a,
		top_a,
		top_b,
		bottom_b,
	])
	frame.width = 3.0
	frame.default_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.92)
	frame.antialiased = true
	frame.z_index = 1
	root.add_child(frame)

	var center_line := Line2D.new()
	center_line.name = "CenterLine"
	var center_bottom := bottom_a.lerp(bottom_b, 0.5)
	center_line.points = PackedVector2Array([
		center_bottom,
		center_bottom - lift,
	])
	center_line.width = 1.5
	center_line.default_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.42)
	center_line.antialiased = true
	center_line.z_index = 2
	root.add_child(center_line)

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


static func create_joined_block(
	cell: Vector2i,
	top_center: Vector2,
	depth_order: int,
	level: int = 0,
	tint: Color = Color.WHITE
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = atlas_texture(cell)
	# Preserve the authored MC Blocks wall pixels. Joining comes from calibrated
	# scale/overlap, not from blurring the individual block sprites.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = JOINED_BLOCK_SCALE
	sprite.position = (
		top_center
		+ JOINED_BLOCK_TOP_CENTER_OFFSET
		- Vector2(0.0, float(level) * JOINED_BLOCK_LEVEL_HEIGHT)
	)
	sprite.z_index = clampi(depth_order + level, -4000, 4000)
	sprite.modulate = tint
	sprite.add_to_group("central_city_wall_block")
	sprite.set_meta("wall_level", level)
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
