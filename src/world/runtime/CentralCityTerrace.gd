extends RefCounted
class_name CentralCityTerrace

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")
const TOPOLOGY = preload("res://src/world/runtime/CentralCityTopology.gd")
const WORLD_WATER = preload("res://src/world/runtime/WorldWater.gd")

const ROOT_Z := -1164
const WALL_CAP_GRID := 0.34
const TRENCH_CAP_GRID := 0.07
const CANAL_MODULE_TARGET_PX := 82.0
const CANAL_PILLAR_WIDTH_PX := 7.0
const CANAL_COPING_JOINT_GRID := 0.055
const NEAR_GROUND_OVERLAP_FACTOR := 1.65
const BASIN_DEPTH_PX := 22.0
const WATER_SURFACE_DROP_PX := 8.0
const WATER_EDGE_INSET_GRID := 0.10
const BASIN_FLOOR_INSET_GRID := 0.18
const SHORE_BAND_GRID := 0.42
const BRIDGE_BODY_DEPTH_PX := 8.0
const BRIDGE_RAIL_GRID := 0.16

const WALL_TOP := Color(0.60, 0.61, 0.61, 1.0)
const WALL_FACE := Color(0.22, 0.25, 0.27, 1.0)
const STAIR_TOP := Color(0.60, 0.61, 0.61, 1.0)
const STAIR_RISER := Color(0.27, 0.30, 0.32, 1.0)
const STAIR_SIDE := Color(0.20, 0.23, 0.25, 1.0)
# Canal architecture stays neutral; cyan belongs to the water/light language,
# not to the concrete itself. Water refraction provides the submerged blue cast.
# The top lip deliberately uses the same neutral family as the continuous
# city floor. It must read as pavement thickness, never as a pool surround.
const TRENCH_CAP := Color(0.555, 0.575, 0.585, 1.0)
const TRENCH_CAP_JOINT := Color(0.300, 0.322, 0.332, 1.0)
const BASIN_WALL_BACK := Color(0.435, 0.455, 0.465, 1.0)
const BASIN_WALL_FRONT := Color(0.355, 0.385, 0.398, 1.0)
const BASIN_WALL_SUBMERGED := Color(0.285, 0.335, 0.350, 1.0)
const BASIN_FLOOR := Color(0.225, 0.305, 0.325, 1.0)
const CANAL_LEDGE := Color(0.515, 0.535, 0.545, 1.0)
const CANAL_PILLAR := Color(0.405, 0.435, 0.447, 1.0)
const CANAL_PILLAR_CAP := Color(0.505, 0.525, 0.535, 1.0)
const CANAL_PANEL := Color(0.255, 0.292, 0.305, 1.0)
const CANAL_PANEL_INSET := Color(0.185, 0.225, 0.238, 1.0)
const CANAL_WATERLINE_SHADOW := Color(0.155, 0.205, 0.220, 1.0)
const CANAL_TECH_ACCENT := Color(0.070, 0.565, 0.700, 1.0)
const CANAL_GATE_SLAT := Color(0.315, 0.350, 0.360, 1.0)
const BRIDGE_TOP := Color(0.555, 0.570, 0.580, 1.0)
const BRIDGE_BODY := Color(0.335, 0.370, 0.382, 1.0)
const BRIDGE_RAIL := Color(0.13, 0.22, 0.25, 1.0)


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
	var basin_floor: Array[Dictionary] = []
	var basin_back_faces: Array[Dictionary] = []
	var water_surfaces: Array[Dictionary] = []
	var water_edges: Array[Dictionary] = []
	for raw_void in TOPOLOGY.voids():
		if raw_void is Dictionary:
			_append_void_frame(
				raw_void as Dictionary,
				trench_caps,
				basin_floor,
				basin_back_faces,
				water_surfaces,
				water_edges
			)

	# The basin is real 2.5D geometry now: floor and submerged/back faces are
	# rendered before the water so the refraction shader has actual scenery to
	# bend. Front faces and the stone rim render after the water, making the
	# surface visibly sit below pavement level instead of looking painted on.
	_add_structure_batch(
		root,
		"WaterBasinFloor",
		basin_floor,
		6,
		{
			"aggregate_strength": 0.020,
			"vertical_darkening": 0.02,
			"top_bevel_strength": 0.0,
			"bottom_ao_strength": 0.02,
			"cool_depth_tint": 0.025,
		}
	)
	_add_structure_batch(
		root,
		"TrenchSubmergedWalls",
		basin_back_faces,
		7,
		{
			"aggregate_strength": 0.026,
			"vertical_darkening": 0.12,
			"top_bevel_strength": 0.045,
			"bottom_ao_strength": 0.10,
			"cool_depth_tint": 0.075,
		}
	)

	if not water_surfaces.is_empty():
		var water_profile := {
			"deep_color": Color(0.010, 0.340, 0.565, 1.0),
			"body_color": Color(0.015, 0.670, 0.830, 1.0),
			"shallow_color": Color(0.100, 0.830, 0.920, 1.0),
			"caustic_color": Color(0.460, 0.970, 1.000, 1.0),
			"crest_color": Color(0.840, 1.000, 1.000, 1.0),
			"underwater_tint": Color(0.44, 0.84, 0.90, 1.0),
			"flow_direction": Vector2(1.0, 1.0).normalized(),
			"flow_speed": 0.16,
			"cross_flow_speed": 0.065,
			"wave_scale": 1.10,
			"wave_strength": 0.34,
			"caustic_scale": 1.48,
			"caustic_strength": 0.32,
			"caustic_speed": 0.44,
			"crest_strength": 0.18,
			"depth_strength": 0.54,
			"refraction_pixels": 1.15,
			"refraction_visibility": 0.21,
			"opacity": 0.97,
		}
		var water := WORLD_WATER.create_surface_batch(
			water_surfaces,
			8,
			"CanalWater",
			water_profile
		)
		root.add_child(water)

	if not water_edges.is_empty():
		var shoreline := WORLD_WATER.create_shoreline_batch(
			water_edges,
			9,
			"CanalShoreline",
			{
				"foam_color": Color(0.72, 0.99, 1.00, 0.86),
				"secondary_color": Color(0.12, 0.76, 0.91, 0.52),
				"shore_speed": 0.30,
				"shore_strength": 0.66,
				"secondary_strength": 0.28,
				"world_scale": 0.022,
				"crest_width": 0.048,
			}
		)
		root.add_child(shoreline)

	# The near/right+bottom sides are intentionally NOT vertical wall faces.
	# Their pavement lip renders after water and occludes the near shoreline,
	# while the far/top+left sides expose the actual floor thickness behind it.
	_add_paver_batch(root, "TrenchBankCaps", trench_caps, 11)

	var bridge_bodies: Array[Dictionary] = []
	var bridge_decks: Array[Dictionary] = []
	var bridge_rails: Array[Dictionary] = []
	for raw_bridge in TOPOLOGY.bridges():
		if raw_bridge is Dictionary:
			_append_bridge(raw_bridge as Dictionary, bridge_bodies, bridge_decks, bridge_rails)
	_add_structure_batch(
		root,
		"BridgeBodies",
		bridge_bodies,
		12,
		{
			"aggregate_strength": 0.024,
			"vertical_darkening": 0.17,
			"top_bevel_strength": 0.08,
			"bottom_ao_strength": 0.13,
			"cool_depth_tint": 0.025,
		}
	)
	_add_paver_batch(root, "BridgeDecks", bridge_decks, 13)
	_add_color_batch(root, "BridgeRails", bridge_rails, 14)

	root.set_meta("visual_level_count", TOPOLOGY.levels().size())
	root.set_meta("stair_count", TOPOLOGY.stairs().size())
	root.set_meta("trench_count", TOPOLOGY.voids().size())
	root.set_meta("bridge_count", TOPOLOGY.bridges().size())
	root.set_meta("water_surface_drop_px", WATER_SURFACE_DROP_PX)
	root.set_meta("basin_depth_px", BASIN_DEPTH_PX)
	root.set_meta("canal_coping_width_grid", TRENCH_CAP_GRID)
	root.set_meta("canal_module_target_px", CANAL_MODULE_TARGET_PX)
	root.set_meta("canal_detail_system", "modular_civic_waterfront_v2_cutaway")
	root.set_meta("canal_cutaway_mode", "far_faces_near_ground_occlusion")
	root.set_meta("near_ground_overlap_factor", NEAR_GROUND_OVERLAP_FACTOR)
	root.set_meta("preserves_ground_underlay", true)
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
	basin_floor: Array[Dictionary],
	basin_back_faces: Array[Dictionary],
	water_surfaces: Array[Dictionary],
	water_edges: Array[Dictionary]
) -> void:
	var x0 := float(void_region.get("x_min", 0.0))
	var x1 := float(void_region.get("x_max", 0.0))
	var y0 := float(void_region.get("y_min", 0.0))
	var y1 := float(void_region.get("y_max", 0.0))
	var level := TOPOLOGY.level_at_grid(Vector2((x0 + x1) * 0.5, y0 - 0.5))
	var elevation := TOPOLOGY.elevation_for_level(level)

	var footprint := PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x0, y1),
	])
	var polygon_value = void_region.get("grid_polygon")
	if polygon_value is PackedVector2Array and (polygon_value as PackedVector2Array).size() >= 3:
		footprint = polygon_value as PackedVector2Array

	var has_water := String(void_region.get("fill", "water")) == "water"
	if not has_water:
		return

	var water_grid := _offset_grid_polygon(footprint, -WATER_EDGE_INSET_GRID)
	var floor_grid := _offset_grid_polygon(footprint, -BASIN_FLOOR_INSET_GRID)
	water_grid = _align_polygon_vertices(footprint, water_grid)
	floor_grid = _align_polygon_vertices(footprint, floor_grid)

	# If an extreme authored shape cannot be offset safely, fall back to the
	# original outline rather than producing missing or self-intersecting water.
	if water_grid.size() != footprint.size():
		water_grid = footprint.duplicate()
	if floor_grid.size() != footprint.size():
		floor_grid = water_grid.duplicate()

	var top_logical := _grid_to_logical(footprint)
	var water_logical := _grid_to_logical(water_grid)
	var floor_logical := _grid_to_logical(floor_grid)
	var top_display := _logical_at_elevation(top_logical, elevation)
	var water_elevation := elevation - WATER_SURFACE_DROP_PX
	var floor_elevation := elevation - BASIN_DEPTH_PX
	var water_display := _logical_at_elevation(water_logical, water_elevation)
	var floor_display := _logical_at_elevation(floor_logical, floor_elevation)

	basin_floor.append({
		"points": floor_display,
		"color": BASIN_FLOOR,
		"depths": PackedFloat32Array([
			0.55, 0.55, 0.55, 0.55,
		]),
	})
	water_surfaces.append({
		"points": water_display,
		"grid_points": water_grid,
	})

	# Isometric cutaway rule:
	# - far/top+left edges expose the vertical floor thickness down to the water;
	# - near/right+bottom edges are foreground pavement and must cover the water.
	# A four-sided raised frame is physically wrong for this camera and is what
	# made the previous versions read as a swimming pool.
	var opening_center := Vector2.ZERO
	for point: Vector2 in top_display:
		opening_center += point
	opening_center /= float(maxi(top_display.size(), 1))

	var outer_grid := _offset_grid_polygon(footprint, TRENCH_CAP_GRID)
	outer_grid = _align_polygon_vertices(footprint, outer_grid)
	if outer_grid.size() != footprint.size():
		outer_grid = footprint.duplicate()

	var max_edge_grid_length := 0.0
	for index in range(footprint.size()):
		max_edge_grid_length = maxf(
			max_edge_grid_length,
			footprint[index].distance_to(footprint[(index + 1) % footprint.size()])
		)

	for index in range(footprint.size()):
		var next := (index + 1) % footprint.size()
		var top_a := top_display[index]
		var top_b := top_display[next]
		var water_a := water_display[index]
		var water_b := water_display[next]
		var bottom_a := floor_display[index]
		var bottom_b := floor_display[next]
		var edge_midpoint := (top_a + top_b) * 0.5
		var is_far_edge := edge_midpoint.y < opening_center.y

		# Submerged retaining geometry remains behind the water on every side.
		# It can be seen only through the approved refractive water material.
		basin_back_faces.append({
			"points": PackedVector2Array([water_a, water_b, bottom_b, bottom_a]),
			"color": BASIN_WALL_SUBMERGED,
			"depths": PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
		})

		var outer_a := outer_grid[index]
		var outer_b := outer_grid[next]
		var floor_a := footprint[index]
		var floor_b := footprint[next]
		var edge_grid := floor_b - floor_a
		var edge_grid_length := edge_grid.length()
		var is_endpoint := (
			max_edge_grid_length > 0.001
			and edge_grid_length <= max_edge_grid_length * 0.68
		)

		if is_far_edge:
			# The visible wall is a true vertical "cube face": its lower edge
			# is directly below the pavement edge, exactly WATER_SURFACE_DROP_PX
			# lower. The water itself remains inset behind this face.
			var face_bottom_a := top_a + Vector2(0.0, WATER_SURFACE_DROP_PX)
			var face_bottom_b := top_b + Vector2(0.0, WATER_SURFACE_DROP_PX)
			var is_x_axis_edge := absf(edge_grid.x) >= absf(edge_grid.y)
			var floor_color := CITY.surface_base_color(CITY.SURFACE_MAIN)
			var face_color := floor_color.darkened(0.27 if is_x_axis_edge else 0.34)

			basin_back_faces.append({
				"points": PackedVector2Array([
					top_a,
					top_b,
					face_bottom_b,
					face_bottom_a,
				]),
				"color": face_color,
				"depths": PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
			})
			# Small inner shelf at water level bridges the vertical cube face to
			# the inset water polygon, preventing a floating gap at the corner.
			basin_back_faces.append({
				"points": PackedVector2Array([
					face_bottom_a,
					face_bottom_b,
					water_b,
					water_a,
				]),
				"color": CANAL_LEDGE.darkened(0.12),
				"depths": PackedFloat32Array([0.72, 0.72, 0.88, 0.88]),
			})
			_append_canal_wall_architecture(
				basin_back_faces,
				top_a,
				top_b,
				face_bottom_a,
				face_bottom_b,
				is_endpoint
			)

			# Top surface is merely a continuation of the city floor, not a
			# contrasting gray ring.
			_append_paver_spec(
				caps,
				PackedVector2Array([
					outer_a,
					outer_b,
					floor_b,
					floor_a,
				]),
				level,
				TRENCH_CAP
			)
			_append_coping_joints_for_edge(
				caps,
				outer_a,
				outer_b,
				floor_a,
				floor_b,
				level
			)
		else:
			# Foreground pavement deliberately extends beyond the mathematical
			# opening and OVER the water. This is the key near-side occlusion:
			# the player sees pavement first, so the water reads below floor.
			var cover_a := floor_a.lerp(water_grid[index], NEAR_GROUND_OVERLAP_FACTOR)
			var cover_b := floor_b.lerp(water_grid[next], NEAR_GROUND_OVERLAP_FACTOR)
			_append_paver_spec(
				caps,
				PackedVector2Array([
					outer_a,
					outer_b,
					cover_b,
					cover_a,
				]),
				level,
				TRENCH_CAP
			)
			_append_near_edge_inlays(
				caps,
				outer_a,
				outer_b,
				cover_a,
				cover_b,
				level
			)

	# Shoreline strips live on the lowered water plane and pulse inward from
	# the physical basin wall. Their animation is independent of downstream
	# flow, so the edge behaves like lapping water rather than a moving border.
	var signed_area := _polygon_signed_area(water_grid)
	var sign_value := 1.0 if signed_area >= 0.0 else -1.0
	for index in range(water_grid.size()):
		var next := (index + 1) % water_grid.size()
		var a := water_grid[index]
		var b := water_grid[next]
		var edge := b - a
		if edge.is_zero_approx():
			continue
		var inward := -Vector2(edge.y, -edge.x).normalized() * sign_value
		var strip_grid := PackedVector2Array([
			a + inward * 0.015,
			b + inward * 0.015,
			b + inward * SHORE_BAND_GRID,
			a + inward * SHORE_BAND_GRID,
		])
		var strip_world := _logical_at_elevation(
			_grid_to_logical(strip_grid),
			water_elevation
		)
		water_edges.append({
			"outer_a": strip_world[0],
			"outer_b": strip_world[1],
			"inner_b": strip_world[2],
			"inner_a": strip_world[3],
		})


static func _append_canal_wall_architecture(
	target: Array[Dictionary],
	top_a: Vector2,
	top_b: Vector2,
	water_a: Vector2,
	water_b: Vector2,
	is_endpoint: bool
) -> void:
	var edge_length := top_a.distance_to(top_b)
	if edge_length < 20.0:
		return

	# Continuous horizontal hierarchy: a narrow ledge under the pavement and
	# a dark waterline recess frame every module without relying on one flat
	# monolithic wall colour.
	_append_face_rect(
		target,
		top_a,
		top_b,
		water_a,
		water_b,
		0.0,
		1.0,
		0.055,
		0.175,
		CANAL_LEDGE
	)
	_append_face_rect(
		target,
		top_a,
		top_b,
		water_a,
		water_b,
		0.0,
		1.0,
		0.835,
		0.985,
		CANAL_WATERLINE_SHADOW
	)

	var module_count := maxi(1, int(round(edge_length / CANAL_MODULE_TARGET_PX)))
	var pillar_half_t := minf(
		0.055,
		(CANAL_PILLAR_WIDTH_PX * 0.5) / maxf(edge_length, 1.0)
	)
	var module_step := 1.0 / float(module_count)

	# Structural piers sit exactly on module boundaries, giving the wall a
	# civic-infrastructure rhythm instead of a swimming-pool perimeter.
	for boundary_index in range(module_count + 1):
		var center_t := float(boundary_index) / float(module_count)
		var pillar_start := clampf(center_t - pillar_half_t, 0.0, 1.0)
		var pillar_end := clampf(center_t + pillar_half_t, 0.0, 1.0)
		_append_face_rect(
			target,
			top_a,
			top_b,
			water_a,
			water_b,
			pillar_start,
			pillar_end,
			0.115,
			0.955,
			CANAL_PILLAR
		)
		var cap_extra := pillar_half_t * 0.75
		_append_face_rect(
			target,
			top_a,
			top_b,
			water_a,
			water_b,
			clampf(pillar_start - cap_extra, 0.0, 1.0),
			clampf(pillar_end + cap_extra, 0.0, 1.0),
			0.025,
			0.205,
			CANAL_PILLAR_CAP
		)

	# Recessed panels make each bay read as assembled architecture. A restrained
	# cyan status strip appears only on alternating bays: technology is an
	# accent, while the water remains the main cyan surface.
	for module_index in range(module_count):
		var module_start := float(module_index) * module_step
		var module_end := float(module_index + 1) * module_step
		var inset_t := minf(module_step * 0.13, 0.035)
		var panel_start := module_start + inset_t
		var panel_end := module_end - inset_t
		if panel_end <= panel_start:
			continue
		_append_face_rect(
			target,
			top_a,
			top_b,
			water_a,
			water_b,
			panel_start,
			panel_end,
			0.315,
			0.790,
			CANAL_PANEL
		)
		_append_face_rect(
			target,
			top_a,
			top_b,
			water_a,
			water_b,
			panel_start + inset_t * 0.45,
			panel_end - inset_t * 0.45,
			0.385,
			0.705,
			CANAL_PANEL_INSET
		)
		if module_index % 2 == 1:
			var accent_start := lerpf(panel_start, panel_end, 0.28)
			var accent_end := lerpf(panel_start, panel_end, 0.72)
			_append_face_rect(
				target,
				top_a,
				top_b,
				water_a,
				water_b,
				accent_start,
				accent_end,
				0.245,
				0.305,
				CANAL_TECH_ACCENT
			)

	# Short edges are treated as maintenance/intake heads, not as generic pool
	# end walls. The dark recessed gate + slats gives the water a visual reason
	# to terminate here and can later be replaced by a dedicated art asset.
	if is_endpoint:
		_append_face_rect(
			target,
			top_a,
			top_b,
			water_a,
			water_b,
			0.16,
			0.84,
			0.265,
			0.875,
			CANAL_PANEL_INSET.darkened(0.08)
		)
		for slat_index in range(5):
			var center_t := lerpf(0.24, 0.76, float(slat_index) / 4.0)
			var slat_half := minf(0.018, 2.0 / maxf(edge_length, 1.0))
			_append_face_rect(
				target,
				top_a,
				top_b,
				water_a,
				water_b,
				center_t - slat_half,
				center_t + slat_half,
				0.33,
				0.82,
				CANAL_GATE_SLAT
			)
		_append_face_rect(
			target,
			top_a,
			top_b,
			water_a,
			water_b,
			0.31,
			0.69,
			0.205,
			0.275,
			CANAL_TECH_ACCENT
		)


static func _append_face_rect(
	target: Array[Dictionary],
	top_a: Vector2,
	top_b: Vector2,
	bottom_a: Vector2,
	bottom_b: Vector2,
	t0: float,
	t1: float,
	d0: float,
	d1: float,
	color: Color
) -> void:
	t0 = clampf(t0, 0.0, 1.0)
	t1 = clampf(t1, 0.0, 1.0)
	d0 = clampf(d0, 0.0, 1.0)
	d1 = clampf(d1, 0.0, 1.0)
	if t1 - t0 <= 0.0001 or d1 - d0 <= 0.0001:
		return

	var top_left := top_a.lerp(top_b, t0)
	var top_right := top_a.lerp(top_b, t1)
	var bottom_left := bottom_a.lerp(bottom_b, t0)
	var bottom_right := bottom_a.lerp(bottom_b, t1)
	var upper_left := top_left.lerp(bottom_left, d0)
	var upper_right := top_right.lerp(bottom_right, d0)
	var lower_right := top_right.lerp(bottom_right, d1)
	var lower_left := top_left.lerp(bottom_left, d1)
	target.append({
		"points": PackedVector2Array([
			upper_left,
			upper_right,
			lower_right,
			lower_left,
		]),
		"color": color,
		"depths": PackedFloat32Array([d0, d0, d1, d1]),
	})


static func _append_coping_joints_for_edge(
	target: Array[Dictionary],
	outer_a: Vector2,
	outer_b: Vector2,
	inner_a: Vector2,
	inner_b: Vector2,
	level: String
) -> void:
	var edge_length := inner_a.distance_to(inner_b)
	if edge_length < 0.5:
		return
	var joint_count := maxi(1, int(round(edge_length / 2.0)))
	var half_t := minf(
		0.045,
		(CANAL_COPING_JOINT_GRID * 0.5) / edge_length
	)
	for joint_index in range(1, joint_count):
		var center_t := float(joint_index) / float(joint_count)
		var t0 := clampf(center_t - half_t, 0.0, 1.0)
		var t1 := clampf(center_t + half_t, 0.0, 1.0)
		_append_paver_spec(
			target,
			PackedVector2Array([
				outer_a.lerp(outer_b, t0),
				outer_a.lerp(outer_b, t1),
				inner_a.lerp(inner_b, t1),
				inner_a.lerp(inner_b, t0),
			]),
			level,
			TRENCH_CAP_JOINT
		)


static func _append_near_edge_inlays(
	target: Array[Dictionary],
	outer_a: Vector2,
	outer_b: Vector2,
	inner_a: Vector2,
	inner_b: Vector2,
	level: String
) -> void:
	var edge_length := outer_a.distance_to(outer_b)
	if edge_length < 0.5:
		return

	# The near-side ornament lives ON the foreground pavement. It therefore
	# participates in the same occlusion as the floor instead of becoming a
	# visible vertical "pool border".
	var module_count := maxi(2, int(round(edge_length / 2.4)))
	for module_index in range(module_count):
		if module_index % 2 == 0:
			continue
		var center_t := (float(module_index) + 0.5) / float(module_count)
		var half_t := minf(0.040, 0.16 / edge_length)
		var t0 := clampf(center_t - half_t, 0.0, 1.0)
		var t1 := clampf(center_t + half_t, 0.0, 1.0)

		var outer_l := outer_a.lerp(outer_b, t0)
		var outer_r := outer_a.lerp(outer_b, t1)
		var inner_l := inner_a.lerp(inner_b, t0)
		var inner_r := inner_a.lerp(inner_b, t1)
		var dark_l0 := outer_l.lerp(inner_l, 0.22)
		var dark_r0 := outer_r.lerp(inner_r, 0.22)
		var dark_l1 := outer_l.lerp(inner_l, 0.68)
		var dark_r1 := outer_r.lerp(inner_r, 0.68)
		_append_paver_spec(
			target,
			PackedVector2Array([dark_l0, dark_r0, dark_r1, dark_l1]),
			level,
			TRENCH_CAP_JOINT
		)

		# Very small cyan service indicator; the water stays the dominant cyan.
		if module_index % 4 == 1:
			var accent_l0 := outer_l.lerp(inner_l, 0.34)
			var accent_r0 := outer_r.lerp(inner_r, 0.34)
			var accent_l1 := outer_l.lerp(inner_l, 0.46)
			var accent_r1 := outer_r.lerp(inner_r, 0.46)
			_append_paver_spec(
				target,
				PackedVector2Array([
					accent_l0,
					accent_r0,
					accent_r1,
					accent_l1,
				]),
				level,
				CANAL_TECH_ACCENT
			)


static func _offset_grid_polygon(
	points: PackedVector2Array,
	delta: float
) -> PackedVector2Array:
	var candidates := Geometry2D.offset_polygon(points, delta)
	if candidates.is_empty():
		return points.duplicate()

	var best := PackedVector2Array()
	var best_area := -1.0
	for candidate_value in candidates:
		if not candidate_value is PackedVector2Array:
			continue
		var candidate := candidate_value as PackedVector2Array
		var area := absf(_polygon_signed_area(candidate))
		if area > best_area:
			best = candidate
			best_area = area
	return best if not best.is_empty() else points.duplicate()


static func _align_polygon_vertices(
	reference: PackedVector2Array,
	candidate: PackedVector2Array
) -> PackedVector2Array:
	if reference.size() < 3 or candidate.size() != reference.size():
		return candidate

	var count := reference.size()
	var best := candidate.duplicate()
	var best_error := INF
	for reverse_order in [false, true]:
		for offset in range(count):
			var aligned := PackedVector2Array()
			var error := 0.0
			for index in range(count):
				var source_index := offset + (-index if reverse_order else index)
				source_index = ((source_index % count) + count) % count
				var point := candidate[source_index]
				aligned.append(point)
				error += point.distance_squared_to(reference[index])
			if error < best_error:
				best_error = error
				best = aligned
	return best


static func _polygon_signed_area(points: PackedVector2Array) -> float:
	var twice_area := 0.0
	for index in range(points.size()):
		twice_area += points[index].cross(points[(index + 1) % points.size()])
	return twice_area * 0.5


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
		"depths": PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
	})
	bodies.append({
		"points": PackedVector2Array([right_top_a, right_top_b, right_top_b + drop, right_top_a + drop]),
		"color": BRIDGE_BODY,
		"depths": PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
	})

	# Close both bridge ends with real abutment faces. These occupy the same
	# batched structural material as the slab sides and remove the floating
	# bridge / open-void read at the canal heads.
	var near_top_a := TOPOLOGY.grid_to_display(Vector2(x0, y0 - 0.18), level)
	var near_top_b := TOPOLOGY.grid_to_display(Vector2(x1, y0 - 0.18), level)
	var far_top_a := TOPOLOGY.grid_to_display(Vector2(x0, y1 + 0.18), level)
	var far_top_b := TOPOLOGY.grid_to_display(Vector2(x1, y1 + 0.18), level)
	var near_bottom_a := near_top_a + drop
	var near_bottom_b := near_top_b + drop
	var far_bottom_a := far_top_a + drop
	var far_bottom_b := far_top_b + drop
	bodies.append({
		"points": PackedVector2Array([
			near_top_a,
			near_top_b,
			near_bottom_b,
			near_bottom_a,
		]),
		"color": BRIDGE_BODY.lightened(0.025),
		"depths": PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
	})
	_append_bridge_abutment_detail(
		bodies,
		near_top_a,
		near_top_b,
		near_bottom_a,
		near_bottom_b
	)
	bodies.append({
		"points": PackedVector2Array([
			far_top_a,
			far_top_b,
			far_bottom_b,
			far_bottom_a,
		]),
		"color": BRIDGE_BODY.darkened(0.035),
		"depths": PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
	})
	_append_bridge_abutment_detail(
		bodies,
		far_top_a,
		far_top_b,
		far_bottom_a,
		far_bottom_b
	)

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


static func _append_bridge_abutment_detail(
	target: Array[Dictionary],
	top_a: Vector2,
	top_b: Vector2,
	bottom_a: Vector2,
	bottom_b: Vector2
) -> void:
	# Bridge heads get their own framed service module so the deck visibly
	# plugs into canal infrastructure instead of floating over an unrelated box.
	_append_face_rect(
		target,
		top_a,
		top_b,
		bottom_a,
		bottom_b,
		0.06,
		0.94,
		0.18,
		0.92,
		CANAL_PANEL
	)
	_append_face_rect(
		target,
		top_a,
		top_b,
		bottom_a,
		bottom_b,
		0.10,
		0.18,
		0.06,
		0.98,
		CANAL_PILLAR
	)
	_append_face_rect(
		target,
		top_a,
		top_b,
		bottom_a,
		bottom_b,
		0.82,
		0.90,
		0.06,
		0.98,
		CANAL_PILLAR
	)
	_append_face_rect(
		target,
		top_a,
		top_b,
		bottom_a,
		bottom_b,
		0.34,
		0.66,
		0.30,
		0.46,
		CANAL_TECH_ACCENT
	)


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


static func _add_structure_batch(
	root: Node2D,
	node_name: String,
	specs: Array[Dictionary],
	z: int,
	profile: Dictionary = {}
) -> void:
	if specs.is_empty():
		return
	var mesh := CITY.create_canal_structure_batch(specs, z, profile)
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
