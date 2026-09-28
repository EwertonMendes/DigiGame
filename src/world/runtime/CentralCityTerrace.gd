extends RefCounted
class_name CentralCityTerrace

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")
const TOPOLOGY = preload("res://src/world/runtime/CentralCityTopology.gd")
const WORLD_WATER = preload("res://src/world/runtime/WorldWater.gd")

const ROOT_Z := -1164
const WALL_CAP_GRID := 0.34
const TRENCH_CAP_GRID := 0.28
const TRENCH_DEPTH_PX := 14.0
const BRIDGE_BODY_DEPTH_PX := 8.0
const BRIDGE_RAIL_GRID := 0.16
const WATER_INSET_PX := 10.0

const WALL_TOP := Color(0.60, 0.61, 0.61, 1.0)
const WALL_FACE := Color(0.22, 0.25, 0.27, 1.0)
const STAIR_TOP := Color(0.60, 0.61, 0.61, 1.0)
const STAIR_RISER := Color(0.27, 0.30, 0.32, 1.0)
const STAIR_SIDE := Color(0.20, 0.23, 0.25, 1.0)
const TRENCH_CAP := Color(0.55, 0.57, 0.58, 1.0)
const TRENCH_FACE := Color(0.12, 0.15, 0.17, 1.0)
const BRIDGE_TOP := Color(0.51, 0.53, 0.54, 1.0)
const BRIDGE_BODY := Color(0.18, 0.21, 0.23, 1.0)
const BRIDGE_RAIL := Color(0.12, 0.18, 0.21, 1.0)


static func build() -> Node2D:
	var root := Node2D.new()
	root.name = "SouthTerraceStructure"
	root.z_index = ROOT_Z

	var wall_caps: Array[Dictionary] = []
	var wall_faces: Array[Dictionary] = []
	_build_retaining_wall(wall_caps, wall_faces)
	_add_paver_batch(root, "RetainingWallCaps", wall_caps, 0)
	_add_color_batch(root, "RetainingWallFaces", wall_faces, 1)

	var stair_landings: Array[Dictionary] = []
	var stair_treads: Array[Dictionary] = []
	var stair_risers: Array[Dictionary] = []
	var stair_side_caps: Array[Dictionary] = []
	var stair_rails: Array[Dictionary] = []
	for raw_stair in TOPOLOGY.stairs():
		if raw_stair is Dictionary:
			_append_staircase(
				raw_stair as Dictionary,
				stair_landings,
				stair_treads,
				stair_risers,
				stair_side_caps,
				stair_rails
			)
	_add_paver_batch(root, "StairLandings", stair_landings, 2)
	_add_paver_batch(root, "StairTreads", stair_treads, 3)
	_add_color_batch(root, "StairRisers", stair_risers, 4)
	_add_paver_batch(root, "StairSideCaps", stair_side_caps, 5)
	_add_color_batch(root, "StairNosingAndParapets", stair_rails, 6)

	var trench_caps: Array[Dictionary] = []
	var trench_faces: Array[Dictionary] = []
	var water_surfaces: Array[Dictionary] = []
	var water_edges: Array[Dictionary] = []
	for raw_void in TOPOLOGY.voids():
		if raw_void is Dictionary:
			_append_void_frame(raw_void as Dictionary, trench_caps, trench_faces, water_surfaces, water_edges)
	if not water_surfaces.is_empty():
		var water_profile := {
			"deep_color": Color(0.012, 0.105, 0.17, 1.0),
			"body_color": Color(0.018, 0.30, 0.39, 1.0),
			"shallow_color": Color(0.055, 0.50, 0.54, 1.0),
			"highlight_color": Color(0.63, 0.95, 0.92, 1.0),
			"flow_direction": Vector2(0.92, 0.38),
			"flow_speed": 0.30,
			"wave_scale": 0.46,
			"detail_scale": 1.18,
			"wave_strength": 0.88,
			"highlight_strength": 0.66,
			"sparkle_strength": 0.16,
			"depth_bias": 0.48,
			"opacity": 0.98,
		}
		var water := CITY.create_world_uv_polygon_batch(
			water_surfaces,
			CITY.create_water_material(water_profile),
			6
		)
		water.name = "CanalWater"
		root.add_child(water)
	if not water_edges.is_empty():
		var shoreline := WORLD_WATER.create_shoreline_batch(
			water_edges,
			7,
			"CanalShoreline",
			{
				"foam_color": Color(0.72, 0.98, 0.95, 0.92),
				"secondary_color": Color(0.24, 0.72, 0.74, 0.52),
				"shore_speed": 0.72,
				"shore_strength": 0.90,
				"secondary_strength": 0.34,
			}
		)
		root.add_child(shoreline)
	_add_paver_batch(root, "TrenchBankCaps", trench_caps, 8)
	_add_color_batch(root, "TrenchInnerWalls", trench_faces, 9)

	var bridge_bodies: Array[Dictionary] = []
	var bridge_decks: Array[Dictionary] = []
	var bridge_rails: Array[Dictionary] = []
	for raw_bridge in TOPOLOGY.bridges():
		if raw_bridge is Dictionary:
			_append_bridge(raw_bridge as Dictionary, bridge_bodies, bridge_decks, bridge_rails)
	_add_color_batch(root, "BridgeBodies", bridge_bodies, 10)
	_add_paver_batch(root, "BridgeDecks", bridge_decks, 11)
	_add_color_batch(root, "BridgeRails", bridge_rails, 12)

	root.set_meta("visual_level_count", TOPOLOGY.levels().size())
	root.set_meta("stair_count", TOPOLOGY.stairs().size())
	root.set_meta("trench_count", TOPOLOGY.voids().size())
	root.set_meta("bridge_count", TOPOLOGY.bridges().size())
	root.set_meta("upper_elevation_px", TOPOLOGY.elevation_for_level("upper_civic"))
	root.set_meta("lower_elevation_px", TOPOLOGY.elevation_for_level("south_terrace"))
	return root


static func _build_retaining_wall(
	caps: Array[Dictionary],
	faces: Array[Dictionary]
) -> void:
	var break_data := TOPOLOGY.level_break()
	if break_data.is_empty():
		return
	var y := float(break_data.get("grid_y", 19.0))
	var x_min := float(break_data.get("x_min", -13.0))
	var x_max := float(break_data.get("x_max", 29.0))
	var upper_level := String(break_data.get("upper_level", "upper_civic"))
	var upper_elevation := TOPOLOGY.elevation_for_level(upper_level)

	var gaps: Array[Vector2] = []
	for raw_stair in TOPOLOGY.stairs():
		if not raw_stair is Dictionary:
			continue
		var stair := raw_stair as Dictionary
		gaps.append(Vector2(
			float(stair.get("x_min", 0.0)),
			float(stair.get("x_max", 0.0))
		))
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var cursor := x_min
	for gap: Vector2 in gaps:
		if gap.x > cursor:
			_append_wall_segment(caps, faces, cursor, gap.x, y, upper_level, upper_elevation)
		cursor = maxf(cursor, gap.y)
	if cursor < x_max:
		_append_wall_segment(caps, faces, cursor, x_max, y, upper_level, upper_elevation)


static func _append_wall_segment(
	caps: Array[Dictionary],
	faces: Array[Dictionary],
	x0: float,
	x1: float,
	y: float,
	level: String,
	elevation: float
) -> void:
	var cap_grid := PackedVector2Array([
		Vector2(x0, y - WALL_CAP_GRID),
		Vector2(x1, y - WALL_CAP_GRID),
		Vector2(x1, y),
		Vector2(x0, y),
	])
	_append_paver_spec(caps, cap_grid, level, WALL_TOP)

	var logical_a := TOPOLOGY.grid_to_world(Vector2(x0, y))
	var logical_b := TOPOLOGY.grid_to_world(Vector2(x1, y))
	var top_a := logical_a + Vector2(0.0, -elevation)
	var top_b := logical_b + Vector2(0.0, -elevation)
	var bottom_drop := Vector2(0.0, elevation)
	faces.append({
		"points": PackedVector2Array([top_a, top_b, top_b + bottom_drop, top_a + bottom_drop]),
		"color": WALL_FACE,
	})


static func _append_staircase(
	stair: Dictionary,
	landings: Array[Dictionary],
	treads: Array[Dictionary],
	risers: Array[Dictionary],
	side_caps: Array[Dictionary],
	rails: Array[Dictionary]
) -> void:
	var x_min := float(stair.get("x_min", 0.0))
	var x_max := float(stair.get("x_max", 0.0))
	var y_start := float(stair.get("y_start", 0.0))
	var y_end := float(stair.get("y_end", y_start + 1.0))
	var step_count := maxi(2, int(stair.get("steps", 6)))
	var from_level := String(stair.get("from_level", "upper_civic"))
	var to_level := String(stair.get("to_level", "south_terrace"))
	var from_elevation := TOPOLOGY.elevation_for_level(from_level)
	var to_elevation := TOPOLOGY.elevation_for_level(to_level)
	var span := y_end - y_start
	var step_depth := span / float(step_count)
	var elevation_step := (from_elevation - to_elevation) / float(step_count)
	var side_width := minf(0.24, maxf(0.12, (x_max - x_min) * 0.06))

	# Explicit landings overlap the connected road graph by half a tile so there
	# is never a black seam between a route and the first/last stair tread.
	_append_paver_spec(
		landings,
		PackedVector2Array([
			Vector2(x_min, y_start - 0.55),
			Vector2(x_max, y_start - 0.55),
			Vector2(x_max, y_start + 0.10),
			Vector2(x_min, y_start + 0.10),
		]),
		from_level,
		STAIR_TOP
	)
	_append_paver_spec(
		landings,
		PackedVector2Array([
			Vector2(x_min, y_end - 0.10),
			Vector2(x_max, y_end - 0.10),
			Vector2(x_max, y_end + 0.55),
			Vector2(x_min, y_end + 0.55),
		]),
		to_level,
		STAIR_TOP
	)

	for step in range(step_count):
		var y0 := y_start + float(step) * step_depth
		var y1 := y0 + step_depth
		var tread_elevation := from_elevation - float(step) * elevation_step
		var next_elevation := from_elevation - float(step + 1) * elevation_step
		var tread_grid := PackedVector2Array([
			Vector2(x_min, y0),
			Vector2(x_max, y0),
			Vector2(x_max, y1),
			Vector2(x_min, y1),
		])
		var logical_tread := _grid_to_logical(tread_grid)
		treads.append({
			"points": _logical_at_elevation(logical_tread, tread_elevation),
			"logical_points": logical_tread,
			"color": STAIR_TOP.darkened(float(step) * 0.012),
		})

		var front_left_logical := TOPOLOGY.grid_to_world(Vector2(x_min, y1))
		var front_right_logical := TOPOLOGY.grid_to_world(Vector2(x_max, y1))
		var top_left := front_left_logical + Vector2(0.0, -tread_elevation)
		var top_right := front_right_logical + Vector2(0.0, -tread_elevation)
		var bottom_left := front_left_logical + Vector2(0.0, -next_elevation)
		var bottom_right := front_right_logical + Vector2(0.0, -next_elevation)
		risers.append({
			"points": PackedVector2Array([top_left, top_right, bottom_right, bottom_left]),
			"color": STAIR_RISER,
		})

		for side in [0, 1]:
			var sx0 := x_min if side == 0 else x_max - side_width
			var sx1 := x_min + side_width if side == 0 else x_max
			var cap_grid := PackedVector2Array([
				Vector2(sx0, y0),
				Vector2(sx1, y0),
				Vector2(sx1, y1),
				Vector2(sx0, y1),
			])
			var logical_cap := _grid_to_logical(cap_grid)
			side_caps.append({
				"points": _logical_at_elevation(logical_cap, tread_elevation - 1.5),
				"logical_points": logical_cap,
				"color": STAIR_SIDE,
			})

	for x in [x_min, x_max]:
		_append_handrail(rails, TOPOLOGY.grid_to_display(Vector2(x, y_start), from_level), TOPOLOGY.grid_to_display(Vector2(x, y_end), to_level))


static func _append_void_frame(
	void_region: Dictionary,
	caps: Array[Dictionary],
	faces: Array[Dictionary],
	water_surfaces: Array[Dictionary],
	water_edges: Array[Dictionary]
) -> void:
	var x0 := float(void_region.get("x_min", 0.0))
	var x1 := float(void_region.get("x_max", 0.0))
	var y0 := float(void_region.get("y_min", 0.0))
	var y1 := float(void_region.get("y_max", 0.0))
	var level := TOPOLOGY.level_at_grid(Vector2((x0 + x1) * 0.5, y0 - 0.5))
	var elevation := TOPOLOGY.elevation_for_level(level)

	var footprint := PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])
	var polygon_value = void_region.get("grid_polygon")
	if polygon_value is PackedVector2Array and (polygon_value as PackedVector2Array).size() >= 3:
		footprint = polygon_value as PackedVector2Array
	var has_water := String(void_region.get("fill", "water")) == "water"
	if has_water:
		var logical := _grid_to_logical(footprint)
		water_surfaces.append({
			"points": _logical_at_elevation(logical, elevation - WATER_INSET_PX),
			"logical_points": logical,
			"color": Color.WHITE,
		})
	if has_water:
		var signed_area := 0.0
		for index in range(footprint.size()):
			signed_area += footprint[index].cross(footprint[(index + 1) % footprint.size()])
		var sign_value := 1.0 if signed_area >= 0.0 else -1.0
		for index in range(footprint.size()):
			var a := footprint[index]
			var b := footprint[(index + 1) % footprint.size()]
			var edge := b - a
			if edge.is_zero_approx():
				continue
			var inward := -Vector2(edge.y, -edge.x).normalized() * sign_value
			var strip_grid := PackedVector2Array([
				a + inward * 0.04,
				b + inward * 0.04,
				b + inward * 0.36,
				a + inward * 0.36,
			])
			var strip_world := _logical_at_elevation(
				_grid_to_logical(strip_grid),
				elevation - WATER_INSET_PX
			)
			water_edges.append({
				"outer_a": strip_world[0],
				"outer_b": strip_world[1],
				"inner_b": strip_world[2],
				"inner_a": strip_world[3],
			})
	var cap_strips := [
		PackedVector2Array([Vector2(x0, y0 - TRENCH_CAP_GRID), Vector2(x1, y0 - TRENCH_CAP_GRID), Vector2(x1, y0), Vector2(x0, y0)]),
		PackedVector2Array([Vector2(x0, y1), Vector2(x1, y1), Vector2(x1, y1 + TRENCH_CAP_GRID), Vector2(x0, y1 + TRENCH_CAP_GRID)]),
		PackedVector2Array([Vector2(x0 - TRENCH_CAP_GRID, y0), Vector2(x0, y0), Vector2(x0, y1), Vector2(x0 - TRENCH_CAP_GRID, y1)]),
		PackedVector2Array([Vector2(x1, y0), Vector2(x1 + TRENCH_CAP_GRID, y0), Vector2(x1 + TRENCH_CAP_GRID, y1), Vector2(x1, y1)]),
	]
	for strip: PackedVector2Array in cap_strips:
		_append_paver_spec(caps, strip, level, TRENCH_CAP)

	var edges := [
		[Vector2(x0, y0), Vector2(x1, y0)],
		[Vector2(x1, y0), Vector2(x1, y1)],
		[Vector2(x1, y1), Vector2(x0, y1)],
		[Vector2(x0, y1), Vector2(x0, y0)],
	]
	for edge in edges:
		var a_logical := TOPOLOGY.grid_to_world(edge[0] as Vector2)
		var b_logical := TOPOLOGY.grid_to_world(edge[1] as Vector2)
		var a := a_logical + Vector2(0.0, -elevation)
		var b := b_logical + Vector2(0.0, -elevation)
		var drop := Vector2(0.0, TRENCH_DEPTH_PX)
		faces.append({
			"points": PackedVector2Array([a, b, b + drop, a + drop]),
			"color": TRENCH_FACE,
		})


static func _append_bridge(
	bridge: Dictionary,
	bodies: Array[Dictionary],
	decks: Array[Dictionary],
	rails: Array[Dictionary]
) -> void:
	var x0 := float(bridge.get("x_min", 0.0))
	var x1 := float(bridge.get("x_max", 0.0))
	var y0 := float(bridge.get("y_min", 0.0))
	var y1 := float(bridge.get("y_max", 0.0))
	var level := String(bridge.get("level", "south_terrace"))
	var elevation := TOPOLOGY.elevation_for_level(level)

	var deck_grid := PackedVector2Array([
		Vector2(x0, y0 - 0.18),
		Vector2(x1, y0 - 0.18),
		Vector2(x1, y1 + 0.18),
		Vector2(x0, y1 + 0.18),
	])
	var logical_deck := _grid_to_logical(deck_grid)
	var display_deck := _logical_at_elevation(logical_deck, elevation)
	decks.append({
		"points": display_deck,
		"logical_points": logical_deck,
		"color": BRIDGE_TOP,
	})

	# Give the crossing a real slab thickness. Only the two long side faces are
	# exposed, so the result reads like a bridge over a void rather than a road
	# polygon painted over missing ground.
	var left_top_a := TOPOLOGY.grid_to_display(Vector2(x0, y0 - 0.18), level)
	var left_top_b := TOPOLOGY.grid_to_display(Vector2(x0, y1 + 0.18), level)
	var right_top_a := TOPOLOGY.grid_to_display(Vector2(x1, y0 - 0.18), level)
	var right_top_b := TOPOLOGY.grid_to_display(Vector2(x1, y1 + 0.18), level)
	var drop := Vector2(0.0, BRIDGE_BODY_DEPTH_PX)
	bodies.append({
		"points": PackedVector2Array([left_top_a, left_top_b, left_top_b + drop, left_top_a + drop]),
		"color": BRIDGE_BODY,
	})
	bodies.append({
		"points": PackedVector2Array([right_top_a, right_top_b, right_top_b + drop, right_top_a + drop]),
		"color": BRIDGE_BODY,
	})

	var left_rail := PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x0 + BRIDGE_RAIL_GRID, y0),
		Vector2(x0 + BRIDGE_RAIL_GRID, y1),
		Vector2(x0, y1),
	])
	var right_rail := PackedVector2Array([
		Vector2(x1 - BRIDGE_RAIL_GRID, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x1 - BRIDGE_RAIL_GRID, y1),
	])
	for rail_grid: PackedVector2Array in [left_rail, right_rail]:
		var logical_rail := _grid_to_logical(rail_grid)
		var rail_points := _logical_at_elevation(logical_rail, elevation + 3.0)
		rails.append({"points": rail_points, "color": BRIDGE_RAIL})

	_append_handrail(rails, left_top_a, left_top_b)
	_append_handrail(rails, right_top_a, right_top_b)

	# Wider heads visually anchor the bridge into the pavement at both ends.
	for landing_y in [y0 - 0.55, y1 + 0.10]:
		var landing_grid := PackedVector2Array([
			Vector2(x0 - 0.22, landing_y),
			Vector2(x1 + 0.22, landing_y),
			Vector2(x1 + 0.22, landing_y + 0.45),
			Vector2(x0 - 0.22, landing_y + 0.45),
		])
		_append_paver_spec(decks, landing_grid, level, BRIDGE_TOP)


static func _append_handrail(specs: Array[Dictionary], start: Vector2, end: Vector2) -> void:
	var count := maxi(1, int(ceil(start.distance_to(end) / 64.0)))
	for index in range(count + 1):
		var foot := start.lerp(end, float(index) / float(count))
		specs.append({
			"points": PackedVector2Array([foot + Vector2(-2, 0), foot + Vector2(2, 0), foot + Vector2(2, -18), foot + Vector2(-2, -18)]),
			"color": BRIDGE_RAIL,
		})
	for height in [10.0, 18.0]:
		var a := start + Vector2(0, -height)
		var b := end + Vector2(0, -height)
		specs.append({
			"points": PackedVector2Array([a, b, b + Vector2(0, 2), a + Vector2(0, 2)]),
			"color": Color(0.22, 0.50, 0.55) if height == 10.0 else Color(0.49, 0.57, 0.59),
		})


static func _append_paver_spec(
	target: Array[Dictionary],
	grid_points: PackedVector2Array,
	level: String,
	color: Color
) -> void:
	var logical := _grid_to_logical(grid_points)
	target.append({
		"points": _logical_at_elevation(logical, TOPOLOGY.elevation_for_level(level)),
		"logical_points": logical,
		"color": color,
	})


static func _grid_to_logical(grid_points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for grid: Vector2 in grid_points:
		result.append(TOPOLOGY.grid_to_world(grid))
	return result


static func _logical_at_elevation(
	logical_points: PackedVector2Array,
	elevation: float
) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in logical_points:
		result.append(point + Vector2(0.0, -elevation))
	return result


static func _add_paver_batch(
	root: Node2D,
	node_name: String,
	specs: Array[Dictionary],
	z: int
) -> void:
	if specs.is_empty():
		return
	var mesh := CITY.create_paver_polygon_batch(specs, z)
	mesh.name = node_name
	mesh.z_index = z
	root.add_child(mesh)


static func _add_color_batch(
	root: Node2D,
	node_name: String,
	specs: Array[Dictionary],
	z: int
) -> void:
	if specs.is_empty():
		return
	var mesh := CITY.create_color_polygon_batch(specs, z)
	mesh.name = node_name
	mesh.z_index = z
	root.add_child(mesh)
