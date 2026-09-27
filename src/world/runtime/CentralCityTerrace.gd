extends RefCounted
class_name CentralCityTerrace

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")

const ROOT_Z := -1165
const TERRACE_EDGE_Y := 19.0
const TERRACE_FACE_DEPTH := 9.0
const CANAL_UPPER_Y := 22.0
const CANAL_LOWER_Y := 25.0
const CANAL_FACE_DEPTH := 6.0

const WALL_SEGMENTS := [
	Vector2(-13.0, -8.0),
	Vector2(-4.0, 5.0),
	Vector2(9.0, 20.0),
	Vector2(24.0, 29.0),
]

const STAIR_GAPS := [
	Vector2(-8.0, -4.0),
	Vector2(5.0, 9.0),
	Vector2(20.0, 24.0),
]

const WATERFALL_RANGES := [
	Vector2(-1.0, 1.0),
	Vector2(14.0, 16.0),
]


static func build() -> Node2D:
	var root := Node2D.new()
	root.name = "SouthTerraceStructure"
	root.z_index = ROOT_Z

	var wall_faces: Array[Dictionary] = []
	var wall_highlights: Array[Dictionary] = []
	for segment: Vector2 in WALL_SEGMENTS:
		_append_edge_face(
			wall_faces,
			wall_highlights,
			segment.x,
			segment.y,
			TERRACE_EDGE_Y,
			TERRACE_FACE_DEPTH,
			Color(0.18, 0.20, 0.22, 1.0),
			Color(0.55, 0.58, 0.59, 1.0)
		)

	# The ornamental south canal uses the same openings as the three authored
	# street axes. Breaking the bank at those openings makes the existing dark
	# routes read as bridge decks instead of pavement painted over water.
	for segment: Vector2 in WALL_SEGMENTS:
		_append_edge_face(
			wall_faces,
			wall_highlights,
			segment.x,
			segment.y,
			CANAL_UPPER_Y,
			CANAL_FACE_DEPTH,
			Color(0.16, 0.19, 0.21, 0.96),
			Color(0.45, 0.49, 0.50, 1.0)
		)
		_append_edge_face(
			wall_faces,
			wall_highlights,
			segment.x,
			segment.y,
			CANAL_LOWER_Y,
			CANAL_FACE_DEPTH,
			Color(0.14, 0.17, 0.19, 0.96),
			Color(0.40, 0.44, 0.46, 1.0)
		)

	var walls := CITY.create_color_polygon_batch(wall_faces, 0)
	walls.name = "RetainingFaces"
	root.add_child(walls)

	var lips := CITY.create_color_polygon_batch(wall_highlights, 1)
	lips.name = "RetainingHighlights"
	root.add_child(lips)

	var stair_specs: Array[Dictionary] = []
	for gap: Vector2 in STAIR_GAPS:
		_append_stair(stair_specs, gap.x, gap.y)
	var stairs := CITY.create_paver_polygon_batch(stair_specs, 3)
	stairs.name = "TerraceStairs"
	root.add_child(stairs)

	var waterfall_faces: Array[Dictionary] = []
	var waterfall_highlights: Array[Dictionary] = []
	for waterfall_range: Vector2 in WATERFALL_RANGES:
		_append_waterfall(
			waterfall_faces,
			waterfall_highlights,
			waterfall_range.x,
			waterfall_range.y
		)

	var waterfalls := CITY.create_color_polygon_batch(waterfall_faces, 4)
	waterfalls.name = "WaterfallFaces"
	root.add_child(waterfalls)

	var waterfall_glints := CITY.create_color_polygon_batch(waterfall_highlights, 5)
	waterfall_glints.name = "WaterfallHighlights"
	root.add_child(waterfall_glints)

	root.set_meta("visual_level_count", 2)
	root.set_meta("stair_count", STAIR_GAPS.size())
	root.set_meta("waterfall_count", WATERFALL_RANGES.size())
	return root


static func _append_edge_face(
	faces: Array[Dictionary],
	highlights: Array[Dictionary],
	x0: float,
	x1: float,
	grid_y: float,
	depth: float,
	face_color: Color,
	highlight_color: Color
) -> void:
	var a := _grid_to_world(Vector2(x0, grid_y))
	var b := _grid_to_world(Vector2(x1, grid_y))
	var drop := Vector2(0.0, depth)
	faces.append({
		"points": PackedVector2Array([a, b, b + drop, a + drop]),
		"color": face_color,
	})
	var highlight_drop := Vector2(0.0, 1.75)
	highlights.append({
		"points": PackedVector2Array([a, b, b + highlight_drop, a + highlight_drop]),
		"color": highlight_color,
	})


static func _append_stair(specs: Array[Dictionary], x0: float, x1: float) -> void:
	const STEP_COUNT := 6
	const STEP_DEPTH := 0.46
	var start_y := TERRACE_EDGE_Y - 0.25
	for step in range(STEP_COUNT):
		var y0 := start_y + float(step) * STEP_DEPTH
		var y1 := y0 + STEP_DEPTH
		var shade := 0.60 - float(step) * 0.018
		specs.append({
			"points": _grid_quad(x0, x1, y0, y1),
			"color": Color(shade, shade + 0.01, shade + 0.01, 1.0),
		})


static func _append_waterfall(
	faces: Array[Dictionary],
	highlights: Array[Dictionary],
	x0: float,
	x1: float
) -> void:
	var a := _grid_to_world(Vector2(x0, TERRACE_EDGE_Y))
	var b := _grid_to_world(Vector2(x1, TERRACE_EDGE_Y))
	var fall := Vector2(0.0, 19.0)
	faces.append({
		"points": PackedVector2Array([a, b, b + fall, a + fall]),
		"color": Color(0.03, 0.62, 0.78, 0.94),
	})

	var width := x1 - x0
	for fraction in [0.22, 0.50, 0.78]:
		var gx := x0 + width * float(fraction)
		var top := _grid_to_world(Vector2(gx, TERRACE_EDGE_Y)) + Vector2(0.0, 2.0)
		highlights.append({
			"points": PackedVector2Array([
				top + Vector2(-1.3, 0.0),
				top + Vector2(1.3, 0.0),
				top + Vector2(1.3, 15.0),
				top + Vector2(-1.3, 15.0),
			]),
			"color": Color(0.36, 0.96, 1.0, 0.78),
		})


static func _grid_quad(x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([
		_grid_to_world(Vector2(x0, y0)),
		_grid_to_world(Vector2(x1, y0)),
		_grid_to_world(Vector2(x1, y1)),
		_grid_to_world(Vector2(x0, y1)),
	])


static func _grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * CITY.TILE_HALF_WIDTH,
		(grid.x + grid.y) * CITY.TILE_HALF_HEIGHT
	)
