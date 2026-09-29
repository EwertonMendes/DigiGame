extends RefCounted
class_name CentralCityArt

# Central City keeps DigiGame's original 64x32 isometric gameplay contract, but
# its exterior hardscape is rendered as a continuous procedural micro-paver
# surface. The visual paving is deliberately finer than gameplay cells so the
# overworld reads as a city floor instead of a tactical board. Grass, water,
# perimeter depth and authored interiors still use their dedicated source art.
const CITY_PAVER_SHADER = preload("res://shaders/city_paver_floor.gdshader")
const CITY_CANAL_STRUCTURE_SHADER = preload("res://shaders/city_canal_structure.gdshader")
const WORLD_WATER = preload("res://src/world/runtime/WorldWater.gd")
const GROUND_GRASS_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0056.png"
const GROUND_GRASS_CHECKER_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0053.png"
const GROUND_MINT_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0058.png"
const GROUND_MAIN_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0072.png"
const GROUND_STONE_SOFT_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0054.png"
const GROUND_TECH_TEAL_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0048.png"
const GROUND_TECH_BLUE_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0049.png"
const GROUND_TECH_PURPLE_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0050.png"
const GROUND_DARK_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0063.png"
const GROUND_WATER_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0064.png"
const GROUND_MARKET_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0009.png"
const GROUND_TRAINING_PATH := "res://assets/world/devilsworkshop/city_1024/isometric_0007.png"
const GROUND_DIGILAB_FLOOR_1_PATH := "res://assets/world/tblack/digilab/floor/floor-1.png"
const GROUND_DIGILAB_FLOOR_2_PATH := "res://assets/world/tblack/digilab/floor/floor-2.png"

static var _texture_cache: Dictionary = {}

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const TILE_HALF_WIDTH := TILE_WIDTH * 0.5
const TILE_HALF_HEIGHT := TILE_HEIGHT * 0.5
const FLOOR_OVERSCAN := Vector2(0.45, 0.22)
const PAVERS_PER_GAMEPLAY_CELL := 4.0
const PAVER_GROUT_WIDTH := 0.055

# Shared procedural civic-wall language. Retaining walls and elevated map-edge
# faces both use this geometry so the city reads as one constructed structure
# instead of mixing a bespoke facade with legacy tan block sides.
const CIVIC_WALL_MODULE_PX := 76.0
const CIVIC_WALL_PILASTER_HALF_PX := 3.0
const CIVIC_WALL_TOP_FASCIA_PX := 8.0
const CIVIC_WALL_BASE_BAND_PX := 5.0
const CIVIC_WALL_PANEL_TOP_PX := 11.0
const CIVIC_WALL_PANEL_BOTTOM_PX := 9.0
const CIVIC_WALL_SEAM_OVERLAP_PX := 2.0
const CIVIC_WALL_FACE := Color(0.35, 0.385, 0.40, 1.0)
const CIVIC_WALL_PANEL_A := Color(0.285, 0.315, 0.33, 1.0)
const CIVIC_WALL_PANEL_B := Color(0.305, 0.335, 0.35, 1.0)
const CIVIC_WALL_PILASTER := Color(0.47, 0.50, 0.50, 1.0)
const CIVIC_WALL_FASCIA := Color(0.50, 0.525, 0.525, 1.0)
const CIVIC_WALL_BASE := Color(0.30, 0.33, 0.34, 1.0)
const CIVIC_WALL_ACCENT := Color(0.16, 0.78, 0.88, 1.0)

# Top-face coordinates measured from the 1024x1024 exports.
const SOURCE_TOP_LEFT := Vector2(92.0, 266.0)
const SOURCE_TOP_TOP := Vector2(512.0, 31.0)
const SOURCE_TOP_RIGHT := Vector2(932.0, 266.0)
const SOURCE_TOP_BOTTOM := Vector2(512.0, 502.0)
const SOURCE_TOP_WIDTH := 840.0
const SOURCE_TOP_HEIGHT := 471.0
const SOURCE_TOP_CENTER_Y := 266.0

# Tblack's DigiLab floor art is authored on the same 1024x1024 canvas, but its
# top face is larger than the Devil's Work.shop source diamond. Keep dedicated
# UVs so the complete authored panel (including its border/detail work) is used
# instead of cropping it to the legacy source coordinates.
const DIGILAB_FLOOR_1_TOP_LEFT := Vector2(63.0, 261.0)
const DIGILAB_FLOOR_1_TOP_TOP := Vector2(503.0, 5.0)
const DIGILAB_FLOOR_1_TOP_RIGHT := Vector2(945.0, 261.0)
const DIGILAB_FLOOR_1_TOP_BOTTOM := Vector2(503.0, 512.0)
const DIGILAB_FLOOR_2_TOP_LEFT := Vector2(71.0, 259.0)
const DIGILAB_FLOOR_2_TOP_TOP := Vector2(503.0, 8.0)
const DIGILAB_FLOOR_2_TOP_RIGHT := Vector2(936.0, 259.0)
const DIGILAB_FLOOR_2_TOP_BOTTOM := Vector2(503.0, 508.0)

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
const SURFACE_ROAD := "road"
const SURFACE_WATER := "water"
const SURFACE_MARKET := "market"
const SURFACE_TRAINING := "training"
const SURFACE_DIGILAB_FLOOR_1 := "digilab_floor_1"
const SURFACE_DIGILAB_FLOOR_2 := "digilab_floor_2"


static func tile_diamond(overscan := Vector2.ZERO) -> PackedVector2Array:
	return panel_diamond(1, overscan)


static func panel_diamond(cell_span: int, overscan := Vector2.ZERO) -> PackedVector2Array:
	var span := maxi(cell_span, 1)
	var half_width := TILE_HALF_WIDTH * float(span)
	var half_height := TILE_HALF_HEIGHT * float(span)
	return PackedVector2Array([
		Vector2(-half_width - overscan.x, 0.0),
		Vector2(0.0, -half_height - overscan.y),
		Vector2(half_width + overscan.x, 0.0),
		Vector2(0.0, half_height + overscan.y),
	])


static func surface_texture(surface: String) -> Texture2D:
	var path := GROUND_MAIN_PATH
	match surface:
		SURFACE_GRASS:
			path = GROUND_GRASS_PATH
		SURFACE_GRASS_CHECKER:
			path = GROUND_GRASS_CHECKER_PATH
		SURFACE_MINT:
			path = GROUND_MINT_PATH
		SURFACE_STONE_SOFT:
			path = GROUND_STONE_SOFT_PATH
		SURFACE_TECH_TEAL:
			path = GROUND_TECH_TEAL_PATH
		SURFACE_TECH_BLUE:
			path = GROUND_TECH_BLUE_PATH
		SURFACE_TECH_PURPLE:
			path = GROUND_TECH_PURPLE_PATH
		SURFACE_DARK, SURFACE_ROAD:
			path = GROUND_DARK_PATH
		SURFACE_WATER:
			path = GROUND_WATER_PATH
		SURFACE_MARKET:
			path = GROUND_MARKET_PATH
		SURFACE_TRAINING:
			path = GROUND_TRAINING_PATH
		SURFACE_DIGILAB_FLOOR_1:
			path = GROUND_DIGILAB_FLOOR_1_PATH
		SURFACE_DIGILAB_FLOOR_2:
			path = GROUND_DIGILAB_FLOOR_2_PATH
	return _load_texture(path)


static func _load_texture(path: String) -> Texture2D:
	var cached = _texture_cache.get(path)
	if cached is Texture2D:
		return cached as Texture2D
	var resource = ResourceLoader.load(path)
	if resource is Texture2D:
		_texture_cache[path] = resource
		return resource as Texture2D
	return null


static func surface_base_color(surface: String) -> Color:
	match surface:
		SURFACE_GRASS:
			return Color(0.32, 0.61, 0.22, 1.0)
		SURFACE_GRASS_CHECKER:
			return Color(0.37, 0.68, 0.20, 1.0)
		SURFACE_MINT:
			return Color(0.20, 0.62, 0.43, 1.0)
		SURFACE_MAIN:
			return Color(0.555, 0.575, 0.585, 1.0)
		SURFACE_STONE_SOFT:
			return Color(0.53, 0.54, 0.54, 1.0)
		SURFACE_TECH_TEAL:
			return Color(0.39, 0.46, 0.46, 1.0)
		SURFACE_TECH_BLUE:
			return Color(0.39, 0.43, 0.48, 1.0)
		SURFACE_TECH_PURPLE:
			return Color(0.44, 0.40, 0.47, 1.0)
		SURFACE_DARK, SURFACE_ROAD:
			return Color(0.25, 0.275, 0.29, 1.0)
		SURFACE_WATER:
			return Color(0.04, 0.58, 0.72, 1.0)
		SURFACE_MARKET:
			return Color(0.58, 0.49, 0.30, 1.0)
		SURFACE_TRAINING:
			return Color(0.48, 0.51, 0.46, 1.0)
		SURFACE_DIGILAB_FLOOR_1:
			return Color(0.82, 0.83, 0.82, 1.0)
		SURFACE_DIGILAB_FLOOR_2:
			return Color(0.68, 0.70, 0.70, 1.0)
		_:
			return Color(0.47, 0.48, 0.48, 1.0)


static func is_procedural_paver_surface(surface: String) -> bool:
	return surface in [
		SURFACE_MAIN,
		SURFACE_STONE_SOFT,
		SURFACE_TECH_TEAL,
		SURFACE_TECH_BLUE,
		SURFACE_TECH_PURPLE,
		SURFACE_DARK,
		SURFACE_ROAD,
		SURFACE_MARKET,
		SURFACE_TRAINING,
	]


static func _grid_cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]


static func append_civic_wall_segment(
	faces: Array[Dictionary],
	panels: Array[Dictionary],
	pilasters: Array[Dictionary],
	bands: Array[Dictionary],
	accents: Array[Dictionary],
	top_a: Vector2,
	top_b: Vector2,
	depth_px: float,
	accent_seed: int = 0,
	include_face: bool = true
) -> void:
	if depth_px <= 0.5 or top_a.distance_squared_to(top_b) <= 0.25:
		return

	# A small vertical overlap is deliberate. It hides sub-pixel/raster seams
	# under both adjoining floor meshes, so the backdrop can never leak through
	# as a black slot between a deck and its wall.
	var overlap := CIVIC_WALL_SEAM_OVERLAP_PX
	var face_top_a := top_a + Vector2(0.0, -overlap)
	var face_top_b := top_b + Vector2(0.0, -overlap)
	var face_bottom_a := top_a + Vector2(0.0, depth_px + overlap)
	var face_bottom_b := top_b + Vector2(0.0, depth_px + overlap)
	if include_face:
		faces.append({
			"points": PackedVector2Array([
				face_top_a,
				face_top_b,
				face_bottom_b,
				face_bottom_a,
			]),
			"color": CIVIC_WALL_FACE,
		})

	var span := top_a.distance_to(top_b)
	var module_count := maxi(1, int(ceil(span / CIVIC_WALL_MODULE_PX)))
	var tangent := (top_b - top_a).normalized()

	bands.append({
		"points": PackedVector2Array([
			face_top_a,
			face_top_b,
			face_top_b + Vector2(0.0, minf(depth_px, CIVIC_WALL_TOP_FASCIA_PX)),
			face_top_a + Vector2(0.0, minf(depth_px, CIVIC_WALL_TOP_FASCIA_PX)),
		]),
		"color": CIVIC_WALL_FASCIA,
	})
	bands.append({
		"points": PackedVector2Array([
			top_a + Vector2(0.0, maxf(0.0, depth_px - CIVIC_WALL_BASE_BAND_PX)),
			top_b + Vector2(0.0, maxf(0.0, depth_px - CIVIC_WALL_BASE_BAND_PX)),
			face_bottom_b,
			face_bottom_a,
		]),
		"color": CIVIC_WALL_BASE,
	})

	for module_index in range(module_count):
		var t0 := float(module_index) / float(module_count)
		var t1 := float(module_index + 1) / float(module_count)
		var panel_a := top_a.lerp(top_b, lerpf(t0, t1, 0.10))
		var panel_b := top_a.lerp(top_b, lerpf(t0, t1, 0.90))
		var panel_top := minf(CIVIC_WALL_PANEL_TOP_PX, depth_px * 0.34)
		var panel_bottom := maxf(panel_top + 4.0, depth_px - CIVIC_WALL_PANEL_BOTTOM_PX)
		panels.append({
			"points": PackedVector2Array([
				panel_a + Vector2(0.0, panel_top),
				panel_b + Vector2(0.0, panel_top),
				panel_b + Vector2(0.0, panel_bottom),
				panel_a + Vector2(0.0, panel_bottom),
			]),
			"color": CIVIC_WALL_PANEL_A if (module_index + accent_seed) % 2 == 0 else CIVIC_WALL_PANEL_B,
		})
		if (module_index + accent_seed) % 2 == 0 and depth_px >= 20.0:
			var accent_a := top_a.lerp(top_b, lerpf(t0, t1, 0.30))
			var accent_b := top_a.lerp(top_b, lerpf(t0, t1, 0.70))
			var accent_y := minf(depth_px - 10.0, maxf(13.0, depth_px * 0.44))
			accents.append({
				"points": PackedVector2Array([
					accent_a + Vector2(0.0, accent_y),
					accent_b + Vector2(0.0, accent_y),
					accent_b + Vector2(0.0, accent_y + 2.0),
					accent_a + Vector2(0.0, accent_y + 2.0),
				]),
				"color": CIVIC_WALL_ACCENT,
			})

	for boundary_index in range(module_count + 1):
		var t := float(boundary_index) / float(module_count)
		var center := top_a.lerp(top_b, t)
		var half_width := tangent * CIVIC_WALL_PILASTER_HALF_PX
		pilasters.append({
			"points": PackedVector2Array([
				center - half_width + Vector2(0.0, -overlap),
				center + half_width + Vector2(0.0, -overlap),
				center + half_width + Vector2(0.0, depth_px + overlap),
				center - half_width + Vector2(0.0, depth_px + overlap),
			]),
			"color": CIVIC_WALL_PILASTER,
		})


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

	# Flat city edges can keep the legacy authored block depth. Elevated civic
	# edges must not: those tan brick faces visually contradict the retaining
	# facade. Build every visible +X/+Y elevated perimeter face from the exact
	# same procedural wall language used by the level break.
	var edge_specs: Array[Dictionary] = []
	var occupied_cells := {}
	for spec: Dictionary in tiles:
		var logical_center: Vector2 = spec.get("position", Vector2.ZERO)
		var grid := _world_to_grid_coordinates(logical_center)
		var cell := Vector2i(roundi(grid.x), roundi(grid.y))
		occupied_cells[_grid_cell_key(cell)] = true
		if bool(spec.get("edge", false)) and String(spec.get("surface", "")) != SURFACE_WATER:
			edge_specs.append(spec)
	edge_specs.sort_custom(_ground_spec_before)

	var edges := Node2D.new()
	edges.name = "EdgeBlocks"
	edges.z_index = 1
	root.add_child(edges)

	var civic_edge_faces: Array[Dictionary] = []
	var civic_edge_panels: Array[Dictionary] = []
	var civic_edge_pilasters: Array[Dictionary] = []
	var civic_edge_bands: Array[Dictionary] = []
	var civic_edge_accents: Array[Dictionary] = []
	for spec: Dictionary in edge_specs:
		var logical_center: Vector2 = spec.get("position", Vector2.ZERO)
		var elevation_px := maxf(0.0, float(spec.get("elevation_px", 0.0)))
		if elevation_px <= 0.5:
			var edge := create_full_block(
				String(spec.get("surface", SURFACE_MAIN)),
				logical_center,
				0
			)
			edges.add_child(edge)
			continue

		var grid := _world_to_grid_coordinates(logical_center)
		var cell := Vector2i(roundi(grid.x), roundi(grid.y))
		var accent_seed := absi(cell.x + cell.y)
		var display_offset := Vector2(0.0, -elevation_px)

		# +X is the right-to-bottom diamond edge. +Y is left-to-bottom.
		# These are the two camera-facing exterior sides of an isometric tile.
		if not occupied_cells.has(_grid_cell_key(cell + Vector2i.RIGHT)):
			append_civic_wall_segment(
				civic_edge_faces,
				civic_edge_panels,
				civic_edge_pilasters,
				civic_edge_bands,
				civic_edge_accents,
				logical_center + Vector2(TILE_HALF_WIDTH, 0.0) + display_offset,
				logical_center + Vector2(0.0, TILE_HALF_HEIGHT) + display_offset,
				elevation_px,
				accent_seed,
				true
			)
		if not occupied_cells.has(_grid_cell_key(cell + Vector2i.DOWN)):
			append_civic_wall_segment(
				civic_edge_faces,
				civic_edge_panels,
				civic_edge_pilasters,
				civic_edge_bands,
				civic_edge_accents,
				logical_center + Vector2(-TILE_HALF_WIDTH, 0.0) + display_offset,
				logical_center + Vector2(0.0, TILE_HALF_HEIGHT) + display_offset,
				elevation_px,
				accent_seed,
				true
			)

	if not civic_edge_faces.is_empty():
		var civic_faces := create_color_polygon_batch(civic_edge_faces, 1)
		civic_faces.name = "CivicEdgeFaces"
		civic_faces.z_index = 1
		root.add_child(civic_faces)
		var civic_details_specs: Array[Dictionary] = []
		civic_details_specs.append_array(civic_edge_panels)
		civic_details_specs.append_array(civic_edge_pilasters)
		civic_details_specs.append_array(civic_edge_bands)
		civic_details_specs.append_array(civic_edge_accents)
		var civic_details := create_color_polygon_batch(civic_details_specs, 2)
		civic_details.name = "CivicEdgeDetails"
		civic_details.z_index = 2
		root.add_child(civic_details)

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
		if is_procedural_paver_surface(surface):
			detail.mesh = _build_ground_paver_mesh(grouped[surface] as Array, surface)
			detail.material = _create_paver_material(surface)
			detail.texture = null
		elif surface == SURFACE_WATER:
			detail.mesh = _build_ground_paver_mesh(grouped[surface] as Array, surface)
			detail.material = create_water_material()
			detail.texture = null
		else:
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
	return create_surface_panel(surface, top_center, depth_order, 1, detail_alpha, detail_tint)


static func create_surface_panel(
	surface: String,
	top_center: Vector2,
	depth_order: int,
	cell_span: int,
	detail_alpha: float = 1.0,
	detail_tint: Color = Color.WHITE
) -> Node2D:
	var span := maxi(cell_span, 1)
	var root := Node2D.new()
	root.position = top_center
	root.z_index = clampi(depth_order, -4000, 4000)

	var base := Polygon2D.new()
	base.name = "Base"
	base.polygon = panel_diamond(span, FLOOR_OVERSCAN * float(span))
	base.color = surface_base_color(surface)
	root.add_child(base)

	var detail := Polygon2D.new()
	detail.name = "TopFaceDetail"
	detail.polygon = panel_diamond(span)
	detail.texture = surface_texture(surface)
	detail.uv = surface_top_face_uvs(surface)
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


static func create_paver_polygon(
	points: PackedVector2Array,
	color: Color,
	depth_order: int
) -> MeshInstance2D:
	var mesh_instance := MeshInstance2D.new()
	mesh_instance.mesh = _build_paver_polygon_mesh(points, color)
	mesh_instance.material = _create_paver_material()
	mesh_instance.z_index = clampi(depth_order, -4000, 4000)
	return mesh_instance


static func create_paver_polygon_batch(
	polygons: Array[Dictionary],
	depth_order: int,
	paint_mask: Texture2D = null,
	paint_mask_origin: Vector2i = Vector2i.ZERO
) -> MeshInstance2D:
	var material := _create_paver_material()
	if paint_mask != null:
		material.set_shader_parameter("use_paint_mask", true)
		material.set_shader_parameter("paint_mask", paint_mask)
		material.set_shader_parameter("paint_mask_origin", Vector2(paint_mask_origin))
		material.set_shader_parameter("paint_mask_size", Vector2(paint_mask.get_size()))
	return create_world_uv_polygon_batch(polygons, material, depth_order)


static func create_world_uv_polygon_batch(
	polygons: Array[Dictionary],
	material: Material,
	depth_order: int
) -> MeshInstance2D:
	var mesh_instance := MeshInstance2D.new()
	mesh_instance.mesh = _build_paver_polygon_batch_mesh(polygons)
	mesh_instance.material = material
	mesh_instance.texture = null
	mesh_instance.z_index = clampi(depth_order, -4000, 4000)
	return mesh_instance


static func create_water_material(profile: Dictionary = {}) -> ShaderMaterial:
	return WORLD_WATER.create_surface_material(profile)


static func create_canal_structure_batch(
	polygons: Array[Dictionary],
	depth_order: int,
	profile: Dictionary = {}
) -> MeshInstance2D:
	var material := ShaderMaterial.new()
	material.shader = CITY_CANAL_STRUCTURE_SHADER
	for raw_key in profile:
		material.set_shader_parameter(
			StringName(String(raw_key)),
			profile[raw_key]
		)

	var mesh_instance := MeshInstance2D.new()
	mesh_instance.mesh = _build_canal_structure_batch_mesh(polygons)
	mesh_instance.material = material
	mesh_instance.texture = null
	mesh_instance.z_index = clampi(depth_order, -4000, 4000)
	return mesh_instance


static func create_color_polygon_batch(
	polygons: Array[Dictionary],
	depth_order: int
) -> MeshInstance2D:
	var mesh_instance := MeshInstance2D.new()
	mesh_instance.mesh = _build_color_polygon_batch_mesh(polygons)
	mesh_instance.texture = null
	mesh_instance.z_index = clampi(depth_order, -4000, 4000)
	return mesh_instance


static func _build_canal_structure_batch_mesh(
	polygons: Array[Dictionary]
) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for spec: Dictionary in polygons:
		var points_value = spec.get("points", PackedVector2Array())
		if not points_value is PackedVector2Array:
			continue
		var points := points_value as PackedVector2Array
		if points.size() < 3:
			continue

		var triangulated := Geometry2D.triangulate_polygon(points)
		if triangulated.is_empty():
			continue

		var base_color: Color = spec.get("color", Color(0.42, 0.44, 0.45, 1.0))
		var depths_value = spec.get("depths", PackedFloat32Array())
		var depths := (
			depths_value as PackedFloat32Array
			if depths_value is PackedFloat32Array
			else PackedFloat32Array()
		)
		var vertex_start := vertices.size()
		for point_index in range(points.size()):
			var point := points[point_index]
			var depth := (
				clampf(depths[point_index], 0.0, 1.0)
				if point_index < depths.size()
				else 0.5
			)
			vertices.append(point)
			# RGB keeps the authored neutral concrete family; alpha is a data
			# channel carrying normalized top-to-bottom face depth.
			colors.append(Color(
				base_color.r,
				base_color.g,
				base_color.b,
				depth
			))
			# Display/world position keeps subtle aggregate variation continuous
			# across independently-authored faces without texture assets.
			uvs.append(point)
		for raw_index in triangulated:
			indices.append(vertex_start + int(raw_index))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _build_color_polygon_batch_mesh(polygons: Array[Dictionary]) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for spec: Dictionary in polygons:
		var points_value = spec.get("points", PackedVector2Array())
		if not points_value is PackedVector2Array:
			continue
		var points := points_value as PackedVector2Array
		if points.size() < 3:
			continue
		var triangulated := Geometry2D.triangulate_polygon(points)
		if triangulated.is_empty():
			continue
		var vertex_start := vertices.size()
		var color: Color = spec.get("color", Color.WHITE)
		for point: Vector2 in points:
			vertices.append(point)
			colors.append(color)
		for raw_index in triangulated:
			indices.append(vertex_start + int(raw_index))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _build_paver_polygon_batch_mesh(polygons: Array[Dictionary]) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for spec: Dictionary in polygons:
		var points_value = spec.get("points", PackedVector2Array())
		if not points_value is PackedVector2Array:
			continue
		var points := points_value as PackedVector2Array
		if points.size() < 3:
			continue

		var triangulated := Geometry2D.triangulate_polygon(points)
		if triangulated.is_empty():
			continue
		var vertex_start := vertices.size()
		var color: Color = spec.get("color", Color.WHITE)
		var logical_value = spec.get("logical_points", points)
		var logical_points := logical_value as PackedVector2Array if logical_value is PackedVector2Array else points
		for point_index in range(points.size()):
			var point := points[point_index]
			var logical_point := logical_points[point_index] if point_index < logical_points.size() else point
			vertices.append(point)
			colors.append(color)
			uvs.append(_world_to_grid_coordinates(logical_point))
		for raw_index in triangulated:
			indices.append(vertex_start + int(raw_index))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _build_paver_polygon_mesh(
	points: PackedVector2Array,
	color: Color
) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for point: Vector2 in points:
		colors.append(color)
		uvs.append(_world_to_grid_coordinates(point))

	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = Geometry2D.triangulate_polygon(points)

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func surface_top_face_uvs(surface: String) -> PackedVector2Array:
	match surface:
		SURFACE_DIGILAB_FLOOR_1:
			return PackedVector2Array([
				DIGILAB_FLOOR_1_TOP_LEFT,
				DIGILAB_FLOOR_1_TOP_TOP,
				DIGILAB_FLOOR_1_TOP_RIGHT,
				DIGILAB_FLOOR_1_TOP_BOTTOM,
			])
		SURFACE_DIGILAB_FLOOR_2:
			return PackedVector2Array([
				DIGILAB_FLOOR_2_TOP_LEFT,
				DIGILAB_FLOOR_2_TOP_TOP,
				DIGILAB_FLOOR_2_TOP_RIGHT,
				DIGILAB_FLOOR_2_TOP_BOTTOM,
			])
		_:
			return PackedVector2Array([
				SOURCE_TOP_LEFT,
				SOURCE_TOP_TOP,
				SOURCE_TOP_RIGHT,
				SOURCE_TOP_BOTTOM,
			])


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
		var logical_center: Vector2 = spec.get("position", Vector2.ZERO)
		var elevation_px := maxf(0.0, float(spec.get("elevation_px", 0.0)))
		var display_center := logical_center + Vector2(0.0, -elevation_px)
		var vertex_start := vertices.size()
		for point: Vector2 in diamond:
			vertices.append(display_center + point)
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


static func _create_paver_material(surface: String = "") -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CITY_PAVER_SHADER
	material.set_shader_parameter("pavers_per_cell", PAVERS_PER_GAMEPLAY_CELL)
	material.set_shader_parameter("grout_width", PAVER_GROUT_WIDTH)
	if surface in [SURFACE_DARK, SURFACE_ROAD]:
		material.set_shader_parameter("stone_variation", 0.04)
		material.set_shader_parameter("grout_darkening", 0.24)
		material.set_shader_parameter("edge_highlight", 0.02)
	return material


static func _build_ground_paver_mesh(tiles: Array, surface: String) -> ArrayMesh:
	var vertices := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var diamond := tile_diamond()

	for raw_spec in tiles:
		if not raw_spec is Dictionary:
			continue
		var spec := raw_spec as Dictionary
		var logical_center: Vector2 = spec.get("position", Vector2.ZERO)
		var elevation_px := maxf(0.0, float(spec.get("elevation_px", 0.0)))
		var display_center := logical_center + Vector2(0.0, -elevation_px)
		var vertex_start := vertices.size()
		for point: Vector2 in diamond:
			var logical_point := logical_center + point
			var display_point := display_center + point
			vertices.append(display_point)
			uvs.append(_world_to_grid_coordinates(logical_point))

		var base: Color = spec.get("base_color", surface_base_color(surface))
		var tint: Color = spec.get("detail_tint", Color.WHITE)
		var alpha := clampf(float(spec.get("detail_alpha", 1.0)), 0.0, 1.0)
		var color := Color(
			base.r * tint.r,
			base.g * tint.g,
			base.b * tint.b,
			base.a * alpha
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
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _world_to_grid_coordinates(world: Vector2) -> Vector2:
	# This is the exact inverse of the 64x32 isometric transform used by the
	# overworld. Feeding these continuous coordinates to the shader makes grout
	# lines pass through authored section/tile seams with no macro-grid reveal.
	return Vector2(
		world.x / TILE_WIDTH + world.y / TILE_HEIGHT,
		-world.x / TILE_WIDTH + world.y / TILE_HEIGHT
	)


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
		var logical_center: Vector2 = spec.get("position", Vector2.ZERO)
		var elevation_px := maxf(0.0, float(spec.get("elevation_px", 0.0)))
		var display_center := logical_center + Vector2(0.0, -elevation_px)
		var vertex_start := vertices.size()
		for point: Vector2 in diamond:
			vertices.append(display_center + point)
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
	a_pos.y -= maxf(0.0, float(a.get("elevation_px", 0.0)))
	b_pos.y -= maxf(0.0, float(b.get("elevation_px", 0.0)))
	if is_equal_approx(a_pos.y, b_pos.y):
		return a_pos.x < b_pos.x
	return a_pos.y < b_pos.y
