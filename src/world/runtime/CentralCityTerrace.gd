extends RefCounted
class_name CentralCityTerrace

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")

const ROOT_Z := -1164
const TERRACE_EDGE_Y := 19.0
const TERRACE_FACE_DEPTH := 12.0
const TRENCH_NORTH_Y := 22.0
const TRENCH_SOUTH_Y := 25.0
const TRENCH_FACE_DEPTH := 10.0

# The terrace is architectural, not a fake height system. The upper deck ends
# on one deliberate retaining wall. Two stair openings connect to the lower
# district, while two separate trenches cut pockets into the south instead of
# drawing one giant water stripe across the complete map.
const STAIR_GAPS := [
	Vector2(-7.0, -4.0),
	Vector2(5.0, 9.0),
]

const WALL_SEGMENTS := [
	Vector2(-13.0, -7.0),
	Vector2(-4.0, 5.0),
	Vector2(9.0, 29.0),
]

const TRENCH_SEGMENTS := [
	Vector2(-13.0, -1.0),
	Vector2(13.0, 29.0),
]

const BRIDGES := [
	{"x": Vector2(-7.0, -4.0), "trench": 0},
	{"x": Vector2(20.0, 23.0), "trench": 1},
]


static func build() -> Node2D:
	var root := Node2D.new()
	root.name = "SouthTerraceStructure"
	root.z_index = ROOT_Z

	var wall_caps: Array[Dictionary] = []
	var wall_faces: Array[Dictionary] = []
	for segment: Vector2 in WALL_SEGMENTS:
		_append_retaining_wall(wall_caps, wall_faces, segment.x, segment.y)

	var cap_mesh := CITY.create_paver_polygon_batch(wall_caps, 0)
	cap_mesh.name = "RetainingWallCaps"
	root.add_child(cap_mesh)

	var face_mesh := CITY.create_color_polygon_batch(wall_faces, 1)
	face_mesh.name = "RetainingWallFaces"
	root.add_child(face_mesh)

	var stair_treads: Array[Dictionary] = []
	var stair_risers: Array[Dictionary] = []
	for gap: Vector2 in STAIR_GAPS:
		_append_staircase(stair_treads, stair_risers, gap.x, gap.y)

	var tread_mesh := CITY.create_paver_polygon_batch(stair_treads, 2)
	tread_mesh.name = "StairTreads"
	root.add_child(tread_mesh)

	var riser_mesh := CITY.create_color_polygon_batch(stair_risers, 3)
	riser_mesh.name = "StairRisers"
	root.add_child(riser_mesh)

	var trench_caps: Array[Dictionary] = []
	var trench_faces: Array[Dictionary] = []
	for segment: Vector2 in TRENCH_SEGMENTS:
		_append_trench_banks(trench_caps, trench_faces, segment.x, segment.y)

	var trench_cap_mesh := CITY.create_paver_polygon_batch(trench_caps, 4)
	trench_cap_mesh.name = "TrenchBankCaps"
	root.add_child(trench_cap_mesh)

	var trench_face_mesh := CITY.create_color_polygon_batch(trench_faces, 5)
	trench_face_mesh.name = "TrenchInnerWalls"
	root.add_child(trench_face_mesh)

	var bridge_decks: Array[Dictionary] = []
	var bridge_bodies: Array[Dictionary] = []
	for raw_bridge in BRIDGES:
		var bridge := raw_bridge as Dictionary
		var span: Vector2 = bridge.get("x", Vector2.ZERO)
		_append_bridge(bridge_decks, bridge_bodies, span.x, span.y)

	var bridge_body_mesh := CITY.create_color_polygon_batch(bridge_bodies, 6)
	bridge_body_mesh.name = "BridgeBodies"
	root.add_child(bridge_body_mesh)

	var bridge_deck_mesh := CITY.create_paver_polygon_batch(bridge_decks, 7)
	bridge_deck_mesh.name = "BridgeDecks"
	root.add_child(bridge_deck_mesh)

	root.set_meta("visual_level_count", 2)
	root.set_meta("stair_count", STAIR_GAPS.size())
	root.set_meta("trench_count", TRENCH_SEGMENTS.size())
	root.set_meta("bridge_count", BRIDGES.size())
	return root


static func _append_retaining_wall(
	caps: Array[Dictionary],
	faces: Array[Dictionary],
	x0: float,
	x1: float
) -> void:
	# A real cap has measurable width on the upper deck; it is not a one-pixel
	# line. The face drops only toward the lower terrace and is confined to the
	# wall segment, so nothing extends across unrelated roads.
	caps.append({
		"points": _grid_quad(x0, x1, TERRACE_EDGE_Y - 0.34, TERRACE_EDGE_Y),
		"color": Color(0.60, 0.61, 0.61, 1.0),
	})
	var a := _grid_to_world(Vector2(x0, TERRACE_EDGE_Y))
	var b := _grid_to_world(Vector2(x1, TERRACE_EDGE_Y))
	var drop := Vector2(0.0, TERRACE_FACE_DEPTH)
	faces.append({
		"points": PackedVector2Array([a, b, b + drop, a + drop]),
		"color": Color(0.24, 0.27, 0.29, 1.0),
	})


static func _append_staircase(
	treads: Array[Dictionary],
	risers: Array[Dictionary],
	x0: float,
	x1: float
) -> void:
	const STEP_COUNT := 5
	const STEP_GRID_DEPTH := 0.38
	var start_y := TERRACE_EDGE_Y - 0.18
	for step in range(STEP_COUNT):
		var y0 := start_y + float(step) * STEP_GRID_DEPTH
		var y1 := y0 + STEP_GRID_DEPTH
		var brightness := 0.61 - float(step) * 0.025
		treads.append({
			"points": _grid_quad(x0, x1, y0, y1),
			"color": Color(brightness, brightness + 0.01, brightness + 0.01, 1.0),
		})

		var front_a := _grid_to_world(Vector2(x0, y1))
		var front_b := _grid_to_world(Vector2(x1, y1))
		var riser_drop := Vector2(0.0, 2.8)
		risers.append({
			"points": PackedVector2Array([
				front_a,
				front_b,
				front_b + riser_drop,
				front_a + riser_drop,
			]),
			"color": Color(0.28, 0.31, 0.33, 1.0),
		})


static func _append_trench_banks(
	caps: Array[Dictionary],
	faces: Array[Dictionary],
	x0: float,
	x1: float
) -> void:
	# The future-water channel is intentionally empty today. These broad bank
	# caps and short inner walls sell the depth while the missing ground lets the
	# world background show through the trench itself.
	caps.append({
		"points": _grid_quad(x0, x1, TRENCH_NORTH_Y - 0.30, TRENCH_NORTH_Y),
		"color": Color(0.57, 0.58, 0.59, 1.0),
	})
	caps.append({
		"points": _grid_quad(x0, x1, TRENCH_SOUTH_Y, TRENCH_SOUTH_Y + 0.30),
		"color": Color(0.55, 0.56, 0.57, 1.0),
	})

	var north_a := _grid_to_world(Vector2(x0, TRENCH_NORTH_Y))
	var north_b := _grid_to_world(Vector2(x1, TRENCH_NORTH_Y))
	var north_drop := Vector2(0.0, TRENCH_FACE_DEPTH)
	faces.append({
		"points": PackedVector2Array([
			north_a,
			north_b,
			north_b + north_drop,
			north_a + north_drop,
		]),
		"color": Color(0.18, 0.21, 0.23, 1.0),
	})

	var south_a := _grid_to_world(Vector2(x0, TRENCH_SOUTH_Y))
	var south_b := _grid_to_world(Vector2(x1, TRENCH_SOUTH_Y))
	var south_lift := Vector2(0.0, -TRENCH_FACE_DEPTH)
	faces.append({
		"points": PackedVector2Array([
			south_a + south_lift,
			south_b + south_lift,
			south_b,
			south_a,
		]),
		"color": Color(0.13, 0.16, 0.18, 1.0),
	})


static func _append_bridge(
	decks: Array[Dictionary],
	bodies: Array[Dictionary],
	x0: float,
	x1: float
) -> void:
	var deck_points := _grid_quad(
		x0,
		x1,
		TRENCH_NORTH_Y - 0.25,
		TRENCH_SOUTH_Y + 0.25
	)
	# A compact slab under the deck makes the crossing read as a bridge rather
	# than the normal road continuing across an empty hole.
	var shadow_points := PackedVector2Array()
	for point: Vector2 in deck_points:
		shadow_points.append(point + Vector2(0.0, 6.0))
	bodies.append({
		"points": shadow_points,
		"color": Color(0.17, 0.20, 0.22, 1.0),
	})
	decks.append({
		"points": deck_points,
		"color": Color(0.49, 0.50, 0.51, 1.0),
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
