extends RefCounted
class_name CentralCityTerrace

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")
const TOPOLOGY = preload("res://src/world/runtime/CentralCityTopology.gd")
const AUTHORING = preload("res://src/world/authoring/CentralCityAuthoringData.gd")
const WORLD_WATER = preload("res://src/world/runtime/WorldWater.gd")

const ROOT_Z := -1164
const FLOOR_FACE_PAVERS_PER_CELL := 4.0
const FLOOR_FACE_JOINT_PX := 1.0
const BASIN_DEPTH_PX := 24.0
const WATER_SURFACE_DROP_PX := 12.0
const BASIN_FLOOR_INSET_GRID := 0.18
const SHORE_BAND_GRID := 0.42
const BRIDGE_BODY_DEPTH_PX := 8.0
const STAIR_BACKPLATE_LOCAL_Z := -64

const GUARD_PLINTH := Color(0.30, 0.34, 0.35, 1.0)
const GUARD_POST := Color(0.39, 0.46, 0.48, 1.0)
const GUARD_TOP := Color(0.56, 0.61, 0.61, 1.0)
const GUARD_ACCENT := Color(0.18, 0.72, 0.82, 1.0)

# Canal architecture stays neutral; cyan belongs to the water/light language,
# not to the concrete itself. Water refraction provides the submerged blue cast.
const FLOOR_FACE_X := Color(0.34, 0.37, 0.38, 1.0)
const FLOOR_FACE_Y := Color(0.25, 0.28, 0.30, 1.0)
const FLOOR_FACE_JOINT := Color(0.16, 0.19, 0.20, 1.0)
const BASIN_WALL_BACK := Color(0.435, 0.455, 0.465, 1.0)
const BASIN_WALL_FRONT := Color(0.355, 0.385, 0.398, 1.0)
const BASIN_WALL_SUBMERGED := Color(0.285, 0.335, 0.350, 1.0)
const BASIN_FLOOR := Color(0.225, 0.305, 0.325, 1.0)
const CANAL_LEDGE := Color(0.515, 0.535, 0.545, 1.0)
const BRIDGE_TOP := Color(0.555, 0.570, 0.580, 1.0)
const BRIDGE_BODY := Color(0.335, 0.370, 0.382, 1.0)
const BRIDGE_RAIL := Color(0.13, 0.22, 0.25, 1.0)


static func build() -> Node2D:
	var root := Node2D.new()
	root.name = "SouthTerraceStructure"
	root.z_index = ROOT_Z

	var wall_faces: Array[Dictionary] = []
	var wall_panels: Array[Dictionary] = []
	var wall_pilasters: Array[Dictionary] = []
	var wall_bands: Array[Dictionary] = []
	var wall_accents: Array[Dictionary] = []
	_build_retaining_wall(
		wall_faces,
		wall_panels,
		wall_pilasters,
		wall_bands,
		wall_accents
	)
	_add_color_batch(root, "RetainingWallFaces", wall_faces, 1)
	# Decorative facade layers share one color mesh so the richer wall does not
	# regress the city batching/render-node budget.
	var wall_details: Array[Dictionary] = []
	wall_details.append_array(wall_panels)
	wall_details.append_array(wall_pilasters)
	wall_details.append_array(wall_bands)
	wall_details.append_array(wall_accents)
	_add_color_batch(root, "RetainingWallDetails", wall_details, 2)

	var stair_backplates: Array[Dictionary] = []
	var stair_treads: Array[Dictionary] = []
	var stair_risers: Array[Dictionary] = []
	var stair_side_walls: Array[Dictionary] = []
	var stair_rails: Array[Dictionary] = []
	for raw_stair in TOPOLOGY.stairs():
		if raw_stair is Dictionary:
			_append_staircase(
				raw_stair as Dictionary,
				stair_backplates,
				stair_treads,
				stair_risers,
				stair_side_walls,
				stair_rails
			)
	# The backplate is intentionally BELOW the normal ground batch. It can fill
	# anti-aliased cracks inside the stair footprint, but it can never paint over
	# the road/floor at either mouth.
	_add_color_batch(root, "StairBackplates", stair_backplates, STAIR_BACKPLATE_LOCAL_Z)
	# Side closure stays behind the walkable top faces. It may fill the visible
	# terrain cut beside a stair, but it must never paint over the tread pavers.
	_add_color_batch(root, "StairSideWalls", stair_side_walls, 5)
	_add_paver_batch(root, "StairTreads", stair_treads, 6)
	_add_color_batch(root, "StairRisers", stair_risers, 7)
	_add_color_batch(root, "StairNosingAndParapets", stair_rails, 8)

	var far_floor_faces: Array[Dictionary] = []
	var basin_floor: Array[Dictionary] = []
	var basin_back_faces: Array[Dictionary] = []
	var water_surfaces: Array[Dictionary] = []
	var water_edges: Array[Dictionary] = []
	for raw_void in TOPOLOGY.voids():
		if raw_void is Dictionary:
			_append_void_frame(
				raw_void as Dictionary,
				far_floor_faces,
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
		12,
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
		13,
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
			14,
			"CanalWater",
			water_profile
		)
		root.add_child(water)

	if not water_edges.is_empty():
		var shoreline := WORLD_WATER.create_shoreline_batch(
			water_edges,
			15,
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

	# Far/top+left edges are actual visible thickness of the city floor. This
	# dedicated layer renders after water so the 12px cube face cannot disappear
	# behind the refractive surface.
	_add_structure_batch(
		root,
		"TrenchFarFloorFaces",
		far_floor_faces,
		16,
		{
			"aggregate_strength": 0.012,
			"vertical_darkening": 0.08,
			"top_bevel_strength": 0.08,
			"top_bevel_width": 0.10,
			"bottom_ao_strength": 0.05,
			"cool_depth_tint": 0.0,
		}
	)

	# Intentionally no near-side floor strip, curb, cap or foreground overlay.
	# The water meets the opening directly on the near/right+bottom camera sides.
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
		18,
		{
			"aggregate_strength": 0.024,
			"vertical_darkening": 0.17,
			"top_bevel_strength": 0.08,
			"bottom_ao_strength": 0.13,
			"cool_depth_tint": 0.025,
		}
	)
	_add_paver_batch(root, "BridgeDecks", bridge_decks, 19)
	_add_color_batch(root, "BridgeRails", bridge_rails, 20)

	root.set_meta("visual_level_count", TOPOLOGY.levels().size())
	root.set_meta("stair_count", TOPOLOGY.stairs().size())
	root.set_meta("trench_count", TOPOLOGY.voids().size())
	root.set_meta("bridge_count", TOPOLOGY.bridges().size())
	root.set_meta("water_surface_drop_px", WATER_SURFACE_DROP_PX)
	root.set_meta("basin_depth_px", BASIN_DEPTH_PX)
	root.set_meta("far_floor_face_depth_px", WATER_SURFACE_DROP_PX)
	root.set_meta("far_floor_face_pavers_per_cell", FLOOR_FACE_PAVERS_PER_CELL)
	root.set_meta("canal_detail_system", "recessed_water_v5_bridge_openings")
	root.set_meta("canal_cutaway_mode", "far_cube_faces_near_open_water")
	root.set_meta("near_side_border", "none")
	root.set_meta("near_side_overlay", "none")
	root.set_meta("near_shoreline_mode", "none")
	root.set_meta("preserves_ground_underlay", true)
	root.set_meta("transition_surface_ownership", "exclusive_half_grid_cells")
	root.set_meta("terrace_facade_system", "procedural_modular_civic_v13_unified_transition_corridor")
	root.set_meta(
		"terrace_boundary_grid_y",
		float(TOPOLOGY.level_break().get("lower_threshold_y", TOPOLOGY.level_break().get("grid_y", 19.0)))
	)
	root.set_meta("stair_guard_system", "procedural_civic_guard_v4_exact_mouth_edges")
	root.set_meta("retaining_backfill_mode", "continuous_under_stairs")
	root.set_meta("stair_understructure_mode", "terrain_cut_side_modules_behind_treads")
	root.set_meta("stair_material_mode", "exclusive_terrain_owned_treads")
	root.set_meta("bridge_material_mode", "inherit_exact_mouth_context")
	root.set_meta("bridge_void_composition", "subtract_support_corridor_from_void_edges")
	root.set_meta("bridge_guard_joint", "single_post_shared_with_connected_stair")
	root.set_meta("bridge_mouth_geometry", "flush_deck_support_clipped_to_void")
	root.set_meta("transition_fit_mode", "painted_lane_half_grid_cell_bounds")
	root.set_meta("upper_elevation_px", TOPOLOGY.elevation_for_level("upper_civic"))
	root.set_meta("lower_elevation_px", TOPOLOGY.elevation_for_level("south_terrace"))
	return root


static func _build_retaining_wall(
	faces: Array[Dictionary],
	panels: Array[Dictionary],
	pilasters: Array[Dictionary],
	bands: Array[Dictionary],
	accents: Array[Dictionary]
) -> void:
	var break_data := TOPOLOGY.level_break()
	if break_data.is_empty():
		return
	# The visible facade must sit on the exact level threshold shared by the
	# final Upper Civic diamond row and the first South Terrace row. Using the
	# old integer authoring guide (grid_y) placed the wall half a cell away from
	# both floor edges and exposed the backdrop as a black slot.
	var y := float(break_data.get("lower_threshold_y", break_data.get("grid_y", 19.0)))
	var x_min := float(break_data.get("x_min", -13.0))
	var x_max := float(break_data.get("x_max", 29.0))
	var upper_level := String(break_data.get("upper_level", "upper_civic"))
	var upper_elevation := TOPOLOGY.elevation_for_level(upper_level)

	# One continuous structural backfill spans the whole break, including behind
	# both stair openings. This is intentionally independent of the decorative
	# facade modules: the backdrop can never leak through as a black trench even
	# between stair cheek geometry, and a tiny overlap tucks under both floor
	# meshes to eliminate raster seams.
	var logical_a := TOPOLOGY.grid_to_world(Vector2(x_min, y))
	var logical_b := TOPOLOGY.grid_to_world(Vector2(x_max, y))
	var top_a := logical_a + Vector2(0.0, -upper_elevation)
	var top_b := logical_b + Vector2(0.0, -upper_elevation)
	var overlap := CITY.CIVIC_WALL_SEAM_OVERLAP_PX
	faces.append({
		"points": PackedVector2Array([
			top_a + Vector2(0.0, -overlap),
			top_b + Vector2(0.0, -overlap),
			logical_b + Vector2(0.0, overlap),
			logical_a + Vector2(0.0, overlap),
		]),
		"color": CITY.CIVIC_WALL_FACE,
	})

	var gaps: Array[Vector2] = []
	for raw_stair in TOPOLOGY.stairs():
		if not raw_stair is Dictionary:
			continue
		var stair := raw_stair as Dictionary
		var lane := TOPOLOGY.fitted_transition_lane(stair)
		gaps.append(Vector2(
			float(lane.get("x_min", stair.get("x_min", 0.0))),
			float(lane.get("x_max", stair.get("x_max", 0.0)))
		))
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var cursor := x_min
	for gap: Vector2 in gaps:
		if gap.x > cursor:
			_append_wall_segment(
				faces, panels, pilasters, bands, accents,
				cursor, gap.x, y, upper_level, upper_elevation
			)
		cursor = maxf(cursor, gap.y)
	if cursor < x_max:
		_append_wall_segment(
			faces, panels, pilasters, bands, accents,
			cursor, x_max, y, upper_level, upper_elevation
		)

	# Finish both ends as deliberate civic corner columns. The perimeter wall is
	# built by the ground batch, while this retaining facade belongs to the
	# terrace batch; without a shared end column their independent polygons can
	# leave a dark vertical crack where the two systems meet.
	var end_half_width := CITY.CIVIC_WALL_PILASTER_HALF_PX * 1.65
	for endpoint in [top_a, top_b]:
		pilasters.append({
			"points": PackedVector2Array([
				endpoint + Vector2(-end_half_width, -overlap),
				endpoint + Vector2(end_half_width, -overlap),
				endpoint + Vector2(end_half_width, upper_elevation + overlap),
				endpoint + Vector2(-end_half_width, upper_elevation + overlap),
			]),
			"color": CITY.CIVIC_WALL_PILASTER,
		})


static func _append_wall_segment(
	faces: Array[Dictionary],
	panels: Array[Dictionary],
	pilasters: Array[Dictionary],
	bands: Array[Dictionary],
	accents: Array[Dictionary],
	x0: float,
	x1: float,
	y: float,
	_level: String,
	elevation: float
) -> void:
	if x1 <= x0 or elevation <= 0.0:
		return

	var logical_a := TOPOLOGY.grid_to_world(Vector2(x0, y))
	var logical_b := TOPOLOGY.grid_to_world(Vector2(x1, y))
	var top_a := logical_a + Vector2(0.0, -elevation)
	var top_b := logical_b + Vector2(0.0, -elevation)

	# The base face is already continuous behind the stairs. Append only the
	# shared modular civic treatment on solid wall spans so the front retaining
	# wall and the lateral elevated perimeter are literally generated by the
	# same geometry/palette instead of merely looking similar.
	CITY.append_civic_wall_segment(
		faces,
		panels,
		pilasters,
		bands,
		accents,
		top_a,
		top_b,
		elevation,
		absi(roundi(x0 * 2.0)),
		false
	)


static func _append_staircase(
	stair: Dictionary,
	backplates: Array[Dictionary],
	treads: Array[Dictionary],
	risers: Array[Dictionary],
	side_walls: Array[Dictionary],
	rails: Array[Dictionary]
) -> void:
	var rect := TOPOLOGY.fitted_transition_rect(stair)
	if rect.is_empty():
		return
	var x_min := float(rect.get("x_min", stair.get("x_min", 0.0)))
	var x_max := float(rect.get("x_max", stair.get("x_max", 0.0)))
	var y_start := float(rect.get("y_min", stair.get("y_start", 0.0)))
	var y_end := float(rect.get("y_max", stair.get("y_end", y_start + 1.0)))
	var step_count := maxi(2, int(stair.get("steps", 6)))
	var from_level := String(stair.get("from_level", "upper_civic"))
	var to_level := String(stair.get("to_level", "south_terrace"))
	var from_elevation := TOPOLOGY.elevation_for_level(from_level)
	var to_elevation := TOPOLOGY.elevation_for_level(to_level)
	var span := y_end - y_start
	if span <= 0.001:
		return
	var step_depth := span / float(step_count)
	var elevation_step := (from_elevation - to_elevation) / float(step_count)

	# Surface ownership is exclusive: normal ground stops exactly at the
	# half-grid mouth and this stair begins on that same mathematical edge.
	# There are no landing polygons and no overscan sitting on top of the road.
	var upper_surface := _transition_mouth_surface(x_min, x_max, y_start - 0.50)
	var lower_surface := _transition_mouth_surface(x_min, x_max, y_end + 0.50)
	var upper_color: Color = upper_surface.get(
		"color",
		CITY.surface_base_color(CITY.SURFACE_MAIN)
	)
	var lower_color: Color = lower_surface.get("color", upper_color)

	# Hidden sloped backing lives below the city ground z-order and is clipped to
	# the exact transition rectangle. It exists only as a safety net for subpixel
	# raster seams between tread/riser polygons.
	backplates.append({
		"points": PackedVector2Array([
			TOPOLOGY.grid_to_world(Vector2(x_min, y_start))
				+ Vector2(0.0, -from_elevation),
			TOPOLOGY.grid_to_world(Vector2(x_max, y_start))
				+ Vector2(0.0, -from_elevation),
			TOPOLOGY.grid_to_world(Vector2(x_max, y_end))
				+ Vector2(0.0, -to_elevation),
			TOPOLOGY.grid_to_world(Vector2(x_min, y_end))
				+ Vector2(0.0, -to_elevation),
		]),
		"color": upper_color.lerp(lower_color, 0.5).darkened(0.14),
	})

	for step in range(step_count):
		var y0 := y_start + float(step) * step_depth
		var y1 := y_start + float(step + 1) * step_depth
		var tread_elevation := from_elevation - float(step) * elevation_step
		var next_elevation := from_elevation - float(step + 1) * elevation_step
		var step_t := (float(step) + 0.5) / float(step_count)
		var step_color := upper_color.lerp(lower_color, step_t)

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
			"color": step_color,
		})

		var front_left_logical := TOPOLOGY.grid_to_world(Vector2(x_min, y1))
		var front_right_logical := TOPOLOGY.grid_to_world(Vector2(x_max, y1))
		var top_left := front_left_logical + Vector2(0.0, -tread_elevation)
		var top_right := front_right_logical + Vector2(0.0, -tread_elevation)
		var bottom_left := front_left_logical + Vector2(0.0, -next_elevation)
		var bottom_right := front_right_logical + Vector2(0.0, -next_elevation)
		risers.append({
			"points": PackedVector2Array([
				top_left,
				top_right,
				bottom_right,
				bottom_left,
			]),
			"color": step_color.darkened(0.24),
		})
		rails.append({
			"points": PackedVector2Array([
				top_left,
				top_right,
				top_right + Vector2(0.0, 2.0),
				top_left + Vector2(0.0, 2.0),
			]),
			"color": step_color.lightened(0.16),
		})

		# The staircase is a CUT through the two terrain planes, not a ramp sitting
		# on top of one of them. Before the retaining threshold the visible cheek
		# closes upward to the upper civic floor; after the threshold it closes
		# downward to the south-terrace floor. This keeps every side module local
		# to the actual terrain beside that step and avoids the giant gray wedge
		# created by forcing every tread all the way to the lower plane.
		var threshold := float(TOPOLOGY.level_break().get("lower_threshold_y", 19.5))
		var segment_mid_y := (y0 + y1) * 0.5
		var adjacent_elevation := from_elevation if segment_mid_y < threshold else to_elevation
		if not is_equal_approx(adjacent_elevation, tread_elevation):
			for side_index in range(2):
				var side_x := x_min if side_index == 0 else x_max
				var tread_a := (
					TOPOLOGY.grid_to_world(Vector2(side_x, y0))
					+ Vector2(0.0, -tread_elevation)
				)
				var tread_b := (
					TOPOLOGY.grid_to_world(Vector2(side_x, y1))
					+ Vector2(0.0, -tread_elevation)
				)
				var terrain_a := (
					TOPOLOGY.grid_to_world(Vector2(side_x, y0))
					+ Vector2(0.0, -adjacent_elevation)
				)
				var terrain_b := (
					TOPOLOGY.grid_to_world(Vector2(side_x, y1))
					+ Vector2(0.0, -adjacent_elevation)
				)
				var panel_color := (
					CITY.CIVIC_WALL_PANEL_A
					if (step + side_index) % 2 == 0
					else CITY.CIVIC_WALL_PANEL_B
				)
				side_walls.append({
					"points": (
						PackedVector2Array([terrain_a, terrain_b, tread_b, tread_a])
						if adjacent_elevation > tread_elevation
						else PackedVector2Array([tread_a, tread_b, terrain_b, terrain_a])
					),
					"color": panel_color,
				})

	# The handrail starts on the exact first tread edge and ends on the exact last
	# stair edge. No horizontal rail stub is drawn over either adjacent terrain.
	for side_x in [x_min, x_max]:
		_append_civic_guardrail(
			rails,
			TOPOLOGY.grid_to_display(Vector2(side_x, y_start), from_level),
			TOPOLOGY.grid_to_display(Vector2(side_x, y_end), to_level),
			false
		)


static func _transition_mouth_surface(
	x_min: float,
	x_max: float,
	y: float
) -> Dictionary:
	var first_x := ceili(minf(x_min, x_max))
	var last_x := floori(maxf(x_min, x_max))
	var row_y := roundi(y)
	var counts := {}
	var representative := {}
	if first_x > last_x:
		first_x = roundi((x_min + x_max) * 0.5)
		last_x = first_x

	for gx in range(first_x, last_x + 1):
		var probe := Vector2(float(gx), float(row_y))
		var authored := AUTHORING.ground_override_at(probe)
		var surface := String(authored.get("surface", CITY.SURFACE_MAIN))
		if surface in [CITY.SURFACE_WATER, "void"]:
			continue
		counts[surface] = int(counts.get(surface, 0)) + 1
		if not representative.has(surface):
			representative[surface] = authored.duplicate(true)

	var winner := CITY.SURFACE_MAIN
	var winner_count := -1
	for raw_surface in counts.keys():
		var surface := String(raw_surface)
		var count := int(counts[surface])
		if count > winner_count:
			winner = surface
			winner_count = count

	var authored_value = representative.get(winner, {})
	var authored := authored_value as Dictionary if authored_value is Dictionary else {}
	if authored.is_empty():
		authored = {"surface": winner}
	return {
		"surface": winner,
		"color": _surface_color_from_override(authored),
		"row_y": row_y,
	}


static func bridge_surface_for_transition(bridge: Dictionary) -> Dictionary:
	var rect := TOPOLOGY.fitted_transition_rect(bridge)
	if rect.is_empty():
		return {
			"surface": CITY.SURFACE_MAIN,
			"color": CITY.surface_base_color(CITY.SURFACE_MAIN),
		}
	var x_min := float(rect.get("x_min", 0.0))
	var x_max := float(rect.get("x_max", 0.0))
	var y_min := float(rect.get("y_min", 0.0))
	var y_max := float(rect.get("y_max", 0.0))
	var near_surface := _transition_mouth_surface(x_min, x_max, y_min - 0.50)
	var far_surface := _transition_mouth_surface(x_min, x_max, y_max + 0.50)
	var near_id := String(near_surface.get("surface", CITY.SURFACE_MAIN))
	var far_id := String(far_surface.get("surface", CITY.SURFACE_MAIN))

	# A bridge is part of the terrain corridor that enters and leaves it. When
	# both mouths are the same material, inherit it directly. If a road only
	# touches one end, that is an intersection beside the bridge, not permission
	# to repaint the crossing itself; prefer the non-road terrain in that case.
	if near_id == far_id:
		return near_surface
	if near_id == CITY.SURFACE_ROAD and far_id != CITY.SURFACE_ROAD:
		return far_surface
	if far_id == CITY.SURFACE_ROAD and near_id != CITY.SURFACE_ROAD:
		return near_surface
	return near_surface


static func _surface_color_from_override(authored: Dictionary) -> Color:
	var surface := String(authored.get("surface", CITY.SURFACE_MAIN))
	var base_value = authored.get("base_color", null)
	var color := (
		base_value as Color
		if base_value is Color
		else CITY.surface_base_color(surface)
	)
	var tint_value = authored.get("detail_tint", null)
	if tint_value is Color:
		var tint := tint_value as Color
		color = Color(
			color.r * tint.r,
			color.g * tint.g,
			color.b * tint.b,
			color.a * tint.a
		)
	return color


static func _surface_color_at_grid(grid: Vector2) -> Color:
	return _surface_color_from_override(AUTHORING.ground_override_at(grid))


static func _landing_surface_color(x_min: float, x_max: float, y: float) -> Color:
	var center := Vector2((x_min + x_max) * 0.5, y)
	var painted := AUTHORING.painted_cells()
	var best_distance := INF
	var best_override: Dictionary = {}

	# Roads and other brush-painted materials are discrete gameplay cells. Search
	# the whole stair mouth plus one neighboring row instead of trusting a single
	# fractional sample; this makes the stair genuinely inherit the surface it is
	# inserted into even when the transition itself occupies unpainted cells.
	for gx in range(floori(x_min) - 1, ceili(x_max) + 2):
		for gy in range(roundi(y) - 1, roundi(y) + 2):
			var key := "%d,%d" % [gx, gy]
			if not painted.has(key):
				continue
			var probe := Vector2(float(gx), float(gy))
			var authored := AUTHORING.ground_override_at(probe)
			var surface := String(authored.get("surface", ""))
			if surface in ["", CITY.SURFACE_WATER, "void"]:
				continue
			var distance := probe.distance_squared_to(center)
			if distance < best_distance:
				best_distance = distance
				best_override = authored

	if not best_override.is_empty():
		return _surface_color_from_override(best_override)
	return _surface_color_at_grid(center)


static func _append_void_frame(
	void_region: Dictionary,
	far_floor_faces: Array[Dictionary],
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

	# Water deliberately uses the exact authored opening. Any uniform inset here
	# becomes a visible gray ring because the preserved city floor underlay shows
	# through around the lowered water plane.
	var water_grid := footprint.duplicate()
	var floor_grid := _offset_grid_polygon(footprint, -BASIN_FLOOR_INSET_GRID)
	floor_grid = _align_polygon_vertices(footprint, floor_grid)
	if floor_grid.size() != footprint.size():
		floor_grid = footprint.duplicate()

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
	#
	# FAR (top + left in camera view):
	#   expose the thickness of the SAME paved floor as true cube faces.
	#
	# NEAR (right + bottom):
	#   DO NOT draw a wall, curb, outline or dark border. The same main-floor
	#   pavers extend into the opening and occlude the water in foreground.
	#
	# This is the inverse of a raised platform and is the visual contract for
	# every recessed canal in this camera projection.
	var opening_center := Vector2.ZERO
	for point: Vector2 in top_display:
		opening_center += point
	opening_center /= float(maxi(top_display.size(), 1))

	for index in range(footprint.size()):
		var next := (index + 1) % footprint.size()
		var top_a := top_display[index]
		var top_b := top_display[next]
		var water_a := water_display[index]
		var water_b := water_display[next]
		var bottom_a := floor_display[index]
		var bottom_b := floor_display[next]
		var floor_a := footprint[index]
		var floor_b := footprint[next]
		var edge_midpoint := (top_a + top_b) * 0.5
		var is_far_edge := edge_midpoint.y < opening_center.y

		# The canal and the bridge are one composition. Where a bridge support
		# corridor crosses a basin edge, that interval is removed from every wall,
		# cube-face and ledge generated by the basin. Water may continue underneath,
		# but there is no hidden concrete lip behind/under the bridge mouth.
		var visible_ranges := _visible_void_edge_ranges(void_region, floor_a, floor_b)
		for visible_range: Vector2 in visible_ranges:
			var t0 := visible_range.x
			var t1 := visible_range.y
			var seg_top_a := top_a.lerp(top_b, t0)
			var seg_top_b := top_a.lerp(top_b, t1)
			var seg_water_a := water_a.lerp(water_b, t0)
			var seg_water_b := water_a.lerp(water_b, t1)
			var seg_bottom_a := bottom_a.lerp(bottom_b, t0)
			var seg_bottom_b := bottom_a.lerp(bottom_b, t1)

			# Submerged geometry exists only on exposed basin edges.
			basin_back_faces.append({
				"points": PackedVector2Array([
					seg_water_a,
					seg_water_b,
					seg_bottom_b,
					seg_bottom_a,
				]),
				"color": BASIN_WALL_SUBMERGED,
				"depths": PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
			})

			if is_far_edge:
				var seg_grid_a := floor_a.lerp(floor_b, t0)
				var seg_grid_b := floor_a.lerp(floor_b, t1)
				var seg_edge_grid := seg_grid_b - seg_grid_a
				var face_bottom_a := seg_top_a + Vector2(0.0, WATER_SURFACE_DROP_PX)
				var face_bottom_b := seg_top_b + Vector2(0.0, WATER_SURFACE_DROP_PX)
				_append_far_floor_cube_face(
					far_floor_faces,
					seg_top_a,
					seg_top_b,
					face_bottom_a,
					face_bottom_b,
					seg_edge_grid.length(),
					absf(seg_edge_grid.x) >= absf(seg_edge_grid.y)
				)

				basin_back_faces.append({
					"points": PackedVector2Array([
						face_bottom_a,
						face_bottom_b,
						seg_water_b,
						seg_water_a,
					]),
					"color": CANAL_LEDGE.darkened(0.16),
					"depths": PackedFloat32Array([0.75, 0.75, 0.90, 0.90]),
				})

	# No shoreline mesh is generated for these canals. The animated surface is
	# sufficient; an explicit edge strip was still reading as a pool outline.


static func _visible_void_edge_ranges(
	void_region: Dictionary,
	edge_a: Vector2,
	edge_b: Vector2
) -> Array[Vector2]:
	var ranges: Array[Vector2] = [Vector2(0.0, 1.0)]
	var delta := edge_b - edge_a
	if delta.length_squared() <= 0.000001:
		return ranges
	var void_id := String(void_region.get("id", ""))

	for raw_bridge in TOPOLOGY.bridges():
		if not raw_bridge is Dictionary:
			continue
		var bridge := raw_bridge as Dictionary
		var support := TOPOLOGY.bridge_support_rect(bridge)
		if support.is_empty() or String(support.get("void_id", "")) != void_id:
			continue

		var cut_start := 0.0
		var cut_end := 0.0
		var cuts_edge := false
		if absf(delta.x) >= absf(delta.y):
			var edge_y := edge_a.y
			var support_y_min := float(support.get("y_min", 0.0))
			var support_y_max := float(support.get("y_max", 0.0))
			if (
				absf(edge_y - support_y_min) <= 0.01
				or absf(edge_y - support_y_max) <= 0.01
			):
				cut_start = (float(support.get("x_min", edge_a.x)) - edge_a.x) / delta.x
				cut_end = (float(support.get("x_max", edge_a.x)) - edge_a.x) / delta.x
				cuts_edge = true
		else:
			var edge_x := edge_a.x
			var support_x_min := float(support.get("x_min", 0.0))
			var support_x_max := float(support.get("x_max", 0.0))
			if (
				absf(edge_x - support_x_min) <= 0.01
				or absf(edge_x - support_x_max) <= 0.01
			):
				cut_start = (float(support.get("y_min", edge_a.y)) - edge_a.y) / delta.y
				cut_end = (float(support.get("y_max", edge_a.y)) - edge_a.y) / delta.y
				cuts_edge = true

		if cuts_edge:
			ranges = _subtract_edge_range(ranges, minf(cut_start, cut_end), maxf(cut_start, cut_end))
	return ranges


static func _subtract_edge_range(
	ranges: Array[Vector2],
	cut_min: float,
	cut_max: float
) -> Array[Vector2]:
	var clipped_min := clampf(cut_min, 0.0, 1.0)
	var clipped_max := clampf(cut_max, 0.0, 1.0)
	if clipped_max <= clipped_min + 0.0001:
		return ranges

	var result: Array[Vector2] = []
	for span: Vector2 in ranges:
		if clipped_max <= span.x + 0.0001 or clipped_min >= span.y - 0.0001:
			result.append(span)
			continue
		if clipped_min > span.x + 0.0001:
			result.append(Vector2(span.x, minf(clipped_min, span.y)))
		if clipped_max < span.y - 0.0001:
			result.append(Vector2(maxf(clipped_max, span.x), span.y))
	return result


static func _append_far_floor_cube_face(
	target: Array[Dictionary],
	top_a: Vector2,
	top_b: Vector2,
	bottom_a: Vector2,
	bottom_b: Vector2,
	edge_grid_length: float,
	is_x_axis_edge: bool
) -> void:
	var segment_count := maxi(
		1,
		int(round(edge_grid_length * FLOOR_FACE_PAVERS_PER_CELL))
	)
	var base_color := FLOOR_FACE_X if is_x_axis_edge else FLOOR_FACE_Y

	# Every visible micro-paver gets its own vertical face. This mirrors the
	# "full block" language used at the city perimeter: top squares have real
	# thickness instead of ending in one continuous pool wall.
	for segment_index in range(segment_count):
		var t0 := float(segment_index) / float(segment_count)
		var t1 := float(segment_index + 1) / float(segment_count)
		var seg_top_a := top_a.lerp(top_b, t0)
		var seg_top_b := top_a.lerp(top_b, t1)
		var seg_bottom_a := bottom_a.lerp(bottom_b, t0)
		var seg_bottom_b := bottom_a.lerp(bottom_b, t1)
		var variation := 0.018 if segment_index % 2 == 0 else -0.010
		target.append({
			"points": PackedVector2Array([
				seg_top_a,
				seg_top_b,
				seg_bottom_b,
				seg_bottom_a,
			]),
			"color": base_color.lightened(variation) if variation >= 0.0 else base_color.darkened(-variation),
			"depths": PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
		})

		# One-pixel vertical grout joint aligned to the top-floor paver cadence.
		# Joints stop at the face bottom and never continue around the near side.
		if segment_index > 0:
			var joint_top := seg_top_a
			var joint_bottom := seg_bottom_a
			var tangent := (top_b - top_a).normalized()
			var half_joint := tangent * (FLOOR_FACE_JOINT_PX * 0.5)
			target.append({
				"points": PackedVector2Array([
					joint_top - half_joint,
					joint_top + half_joint,
					joint_bottom + half_joint,
					joint_bottom - half_joint,
				]),
				"color": FLOOR_FACE_JOINT,
				"depths": PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
			})




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
	var rect := TOPOLOGY.fitted_transition_rect(bridge)
	if rect.is_empty():
		return
	var x0 := float(rect.get("x_min", bridge.get("x_min", 0.0)))
	var x1 := float(rect.get("x_max", bridge.get("x_max", 0.0)))
	var y0 := float(rect.get("y_min", bridge.get("y_min", 0.0)))
	var y1 := float(rect.get("y_max", bridge.get("y_max", 0.0)))
	var level := String(bridge.get("level", "south_terrace"))
	var elevation := TOPOLOGY.elevation_for_level(level)
	var bridge_surface := bridge_surface_for_transition(bridge)
	var deck_color: Color = bridge_surface.get(
		"color",
		CITY.surface_base_color(CITY.SURFACE_MAIN)
	)

	# The walkable top is the corridor itself. It owns whole gameplay cells and
	# meets stair/ground on the same half-grid edge, so there is no overlay slab
	# at either mouth.
	var deck_grid := PackedVector2Array([
		Vector2(x0, y0),
		Vector2(x1, y0),
		Vector2(x1, y1),
		Vector2(x0, y1),
	])
	var logical_deck := _grid_to_logical(deck_grid)
	decks.append({
		"points": _logical_at_elevation(logical_deck, elevation),
		"logical_points": logical_deck,
		"color": deck_color,
	})

	# Structural thickness exists ONLY where the corridor is actually suspended
	# over the authored void. The deck may extend to cell boundaries on solid
	# terrain, but those mouth halves are terrain, not "bridge body".
	var support := TOPOLOGY.bridge_support_rect(bridge)
	if not support.is_empty():
		var support_x0 := float(support.get("x_min", x0))
		var support_x1 := float(support.get("x_max", x1))
		var support_y0 := float(support.get("y_min", y0))
		var support_y1 := float(support.get("y_max", y1))
		var left_top_a := TOPOLOGY.grid_to_display(Vector2(support_x0, support_y0), level)
		var left_top_b := TOPOLOGY.grid_to_display(Vector2(support_x0, support_y1), level)
		var right_top_a := TOPOLOGY.grid_to_display(Vector2(support_x1, support_y0), level)
		var right_top_b := TOPOLOGY.grid_to_display(Vector2(support_x1, support_y1), level)
		var drop := Vector2(0.0, BRIDGE_BODY_DEPTH_PX)
		for face in [
			PackedVector2Array([left_top_a, left_top_b, left_top_b + drop, left_top_a + drop]),
			PackedVector2Array([right_top_a, right_top_b, right_top_b + drop, right_top_a + drop]),
		]:
			bodies.append({
				"points": face,
				"color": deck_color.darkened(0.26),
				"depths": PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
			})

	# The stair and bridge share one rail joint. The connected stair owns the
	# joint post; the bridge contributes the continuation bar but does not emit a
	# second post at the exact same point.
	var include_start_post := true
	var include_end_post := true
	var connected_stair := TOPOLOGY.connected_stair_for_bridge(bridge)
	if not connected_stair.is_empty():
		var stair_rect := TOPOLOGY.fitted_transition_rect(connected_stair)
		if not stair_rect.is_empty():
			var stair_y_min := float(stair_rect.get("y_min", 0.0))
			var stair_y_max := float(stair_rect.get("y_max", 0.0))
			include_start_post = not (
				absf(stair_y_min - y0) <= 0.01
				or absf(stair_y_max - y0) <= 0.01
			)
			include_end_post = not (
				absf(stair_y_min - y1) <= 0.01
				or absf(stair_y_max - y1) <= 0.01
			)

	_append_civic_guardrail(
		rails,
		TOPOLOGY.grid_to_display(Vector2(x0, y0), level),
		TOPOLOGY.grid_to_display(Vector2(x0, y1), level),
		false,
		include_start_post,
		include_end_post
	)
	_append_civic_guardrail(
		rails,
		TOPOLOGY.grid_to_display(Vector2(x1, y0), level),
		TOPOLOGY.grid_to_display(Vector2(x1, y1), level),
		false,
		include_start_post,
		include_end_post
	)


static func _append_civic_guardrail(
	specs: Array[Dictionary],
	start: Vector2,
	end: Vector2,
	solid_plinth: bool = false,
	include_start_post: bool = true,
	include_end_post: bool = true
) -> void:
	var span := start.distance_to(end)
	if span < 1.0:
		return

	if solid_plinth:
		specs.append({
			"points": PackedVector2Array([
				start,
				end,
				end + Vector2(0.0, -7.0),
				start + Vector2(0.0, -7.0),
			]),
			"color": GUARD_PLINTH,
		})

	var count := maxi(1, int(ceil(span / 56.0)))
	for index in range(count + 1):
		if index == 0 and not include_start_post:
			continue
		if index == count and not include_end_post:
			continue
		var foot := start.lerp(end, float(index) / float(count))
		specs.append({
			"points": PackedVector2Array([
				foot + Vector2(-2.5, 0.0),
				foot + Vector2(2.5, 0.0),
				foot + Vector2(2.5, -18.0),
				foot + Vector2(-2.5, -18.0),
			]),
			"color": GUARD_POST,
		})
		specs.append({
			"points": PackedVector2Array([
				foot + Vector2(-1.5, -14.0),
				foot + Vector2(1.5, -14.0),
				foot + Vector2(1.5, -10.0),
				foot + Vector2(-1.5, -10.0),
			]),
			"color": GUARD_ACCENT,
		})

	var top_a := start + Vector2(0.0, -18.0)
	var top_b := end + Vector2(0.0, -18.0)
	specs.append({
		"points": PackedVector2Array([
			top_a,
			top_b,
			top_b + Vector2(0.0, 3.0),
			top_a + Vector2(0.0, 3.0),
		]),
		"color": GUARD_TOP,
	})
	var accent_a := start + Vector2(0.0, -10.0)
	var accent_b := end + Vector2(0.0, -10.0)
	specs.append({
		"points": PackedVector2Array([
			accent_a,
			accent_b,
			accent_b + Vector2(0.0, 2.0),
			accent_a + Vector2(0.0, 2.0),
		]),
		"color": GUARD_ACCENT.darkened(0.16),
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
