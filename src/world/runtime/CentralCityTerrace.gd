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
const BRIDGE_RAIL_GRID := 0.16

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
	var stair_landings: Array[Dictionary] = []
	var stair_treads: Array[Dictionary] = []
	var stair_risers: Array[Dictionary] = []
	var stair_side_caps: Array[Dictionary] = []
	var stair_cheek_faces: Array[Dictionary] = []
	var stair_rails: Array[Dictionary] = []
	for raw_stair in TOPOLOGY.stairs():
		if raw_stair is Dictionary:
			_append_staircase(
				raw_stair as Dictionary,
				stair_backplates,
				stair_landings,
				stair_treads,
				stair_risers,
				stair_side_caps,
				stair_cheek_faces,
				stair_rails
			)
	_add_color_batch(root, "StairBackplates", stair_backplates, 5)
	_add_paver_batch(root, "StairLandings", stair_landings, 6)
	_add_paver_batch(root, "StairTreads", stair_treads, 7)
	stair_risers.append_array(stair_cheek_faces)
	_add_color_batch(root, "StairRisers", stair_risers, 8)
	_add_paver_batch(root, "StairSideCaps", stair_side_caps, 9)
	_add_color_batch(root, "StairNosingAndParapets", stair_rails, 10)

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
	root.set_meta("canal_detail_system", "recessed_water_v4_open_near_edge")
	root.set_meta("canal_cutaway_mode", "far_cube_faces_near_open_water")
	root.set_meta("near_side_border", "none")
	root.set_meta("near_side_overlay", "none")
	root.set_meta("near_shoreline_mode", "none")
	root.set_meta("preserves_ground_underlay", true)
	root.set_meta("terrace_facade_system", "procedural_modular_civic_v6_seamless_modules")
	root.set_meta(
		"terrace_boundary_grid_y",
		float(TOPOLOGY.level_break().get("lower_threshold_y", TOPOLOGY.level_break().get("grid_y", 19.0)))
	)
	root.set_meta("stair_guard_system", "procedural_civic_guard_v1")
	root.set_meta("retaining_backfill_mode", "continuous_under_stairs")
	root.set_meta("stair_understructure_mode", "per_step_side_modules_with_backplate")
	root.set_meta("stair_material_mode", "inherit_insertion_surface")
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
		gaps.append(Vector2(
			float(stair.get("x_min", 0.0)),
			float(stair.get("x_max", 0.0))
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
	landings: Array[Dictionary],
	treads: Array[Dictionary],
	risers: Array[Dictionary],
	side_caps: Array[Dictionary],
	cheek_faces: Array[Dictionary],
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
	var side_width := minf(0.26, maxf(0.14, (x_max - x_min) * 0.065))
	var center_x := (x_min + x_max) * 0.5

	# A staircase is a self-contained transition module. Its top material is
	# sampled from the authored ground paint at the insertion point instead of
	# imposing a fixed gray palette, so a stair cut into a road remains a road
	# and a stair cut into plaza paving remains plaza paving.
	var upper_color := _landing_surface_color(x_min, x_max, y_start - 0.40)
	var lower_color := _landing_surface_color(x_min, x_max, y_end + 0.40)
	var module_color := upper_color.lerp(lower_color, 0.5)
	var module_overlap := 0.18
	# Continuous projected backing plate: individual ground cells inside the
	# transition live at different presentation elevations, so relying on them as
	# an underlay can expose diagonal wedges between diamonds. This single module
	# polygon overlaps the wall opening and both landings, making the staircase
	# watertight before treads/risers/side shells are layered on top.
	backplates.append({
		"points": PackedVector2Array([
			TOPOLOGY.grid_to_world(Vector2(x_min - module_overlap, y_start - 0.10))
				+ Vector2(0.0, -from_elevation),
			TOPOLOGY.grid_to_world(Vector2(x_max + module_overlap, y_start - 0.10))
				+ Vector2(0.0, -from_elevation),
			TOPOLOGY.grid_to_world(Vector2(x_max + module_overlap, y_end + 0.10))
				+ Vector2(0.0, -to_elevation),
			TOPOLOGY.grid_to_world(Vector2(x_min - module_overlap, y_end + 0.10))
				+ Vector2(0.0, -to_elevation),
		]),
		"color": module_color,
	})
	_append_paver_spec(
		landings,
		PackedVector2Array([
			Vector2(x_min - 0.16, y_start - 0.72),
			Vector2(x_max + 0.16, y_start - 0.72),
			Vector2(x_max + 0.16, y_start + 0.12),
			Vector2(x_min - 0.16, y_start + 0.12),
		]),
		from_level,
		upper_color
	)
	_append_paver_spec(
		landings,
		PackedVector2Array([
			Vector2(x_min - 0.16, y_end - 0.12),
			Vector2(x_max + 0.16, y_end - 0.12),
			Vector2(x_max + 0.16, y_end + 0.72),
			Vector2(x_min - 0.16, y_end + 0.72),
		]),
		to_level,
		lower_color
	)

	for step in range(step_count):
		var y0 := y_start + float(step) * step_depth
		var y1 := y0 + step_depth
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
			"points": PackedVector2Array([top_left, top_right, bottom_right, bottom_left]),
			"color": step_color.darkened(0.24),
		})
		# The nosing derives from the same local material instead of using a fixed
		# white strip, preserving readable steps on both light paving and roads.
		rails.append({
			"points": PackedVector2Array([
				top_left,
				top_right,
				top_right + Vector2(0.0, 2.0),
				top_left + Vector2(0.0, 2.0),
			]),
			"color": step_color.lightened(0.16),
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
				"color": step_color.darkened(0.08),
			})

			var side_x := x_min if side == 0 else x_max
			var side_top_start := (
				TOPOLOGY.grid_to_world(Vector2(side_x, y0))
				+ Vector2(0.0, -tread_elevation)
			)
			var side_top_end := (
				TOPOLOGY.grid_to_world(Vector2(side_x, y1))
				+ Vector2(0.0, -tread_elevation)
			)
			var side_bottom_end := (
				TOPOLOGY.grid_to_world(Vector2(side_x, y1))
				+ Vector2(0.0, -next_elevation)
			)
			var side_bottom_start := (
				TOPOLOGY.grid_to_world(Vector2(side_x, y0))
				+ Vector2(0.0, -next_elevation)
			)
			cheek_faces.append({
				"points": PackedVector2Array([
					side_top_start,
					side_top_end,
					side_bottom_end,
					side_bottom_start,
				]),
				"color": step_color.darkened(0.20),
			})

	# The structural backing plate closes the volume behind these per-step side
	# modules, while the visible sides stay compact and follow the stair rhythm.

	for x in [x_min, x_max]:
		_append_civic_guardrail(
			rails,
			TOPOLOGY.grid_to_display(Vector2(x, y_start), from_level),
			TOPOLOGY.grid_to_display(Vector2(x, y_end), to_level),
			true
		)


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
		var edge_midpoint := (top_a + top_b) * 0.5
		var is_far_edge := edge_midpoint.y < opening_center.y

		# Submerged geometry stays behind the approved water shader.
		basin_back_faces.append({
			"points": PackedVector2Array([water_a, water_b, bottom_b, bottom_a]),
			"color": BASIN_WALL_SUBMERGED,
			"depths": PackedFloat32Array([0.0, 0.0, 1.0, 1.0]),
		})

		var floor_a := footprint[index]
		var floor_b := footprint[next]
		var edge_grid := floor_b - floor_a
		var edge_grid_length := edge_grid.length()

		if is_far_edge:
			var face_bottom_a := top_a + Vector2(0.0, WATER_SURFACE_DROP_PX)
			var face_bottom_b := top_b + Vector2(0.0, WATER_SURFACE_DROP_PX)
			_append_far_floor_cube_face(
				far_floor_faces,
				top_a,
				top_b,
				face_bottom_a,
				face_bottom_b,
				edge_grid_length,
				absf(edge_grid.x) >= absf(edge_grid.y)
			)

			# Only the FAR side gets a tiny horizontal shelf at water level. It
			# joins the vertical floor thickness to the inset water and remains
			# behind the dedicated cube face.
			basin_back_faces.append({
				"points": PackedVector2Array([
					face_bottom_a,
					face_bottom_b,
					water_b,
					water_a,
				]),
				"color": CANAL_LEDGE.darkened(0.16),
				"depths": PackedFloat32Array([0.75, 0.75, 0.90, 0.90]),
			})
		else:
			# Near camera sides intentionally add NOTHING. No gray floor strip,
			# no cap, no wall and no decorative rail lives on this edge.
			pass

	# No shoreline mesh is generated for these canals. The animated surface is
	# sufficient; an explicit edge strip was still reading as a pool outline.


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

	_append_civic_guardrail(rails, left_top_a, left_top_b)
	_append_civic_guardrail(rails, right_top_a, right_top_b)

	# Wider heads visually anchor the bridge into the pavement at both ends.
	for landing_y in [y0 - 0.55, y1 + 0.10]:
		var landing_grid := PackedVector2Array([
			Vector2(x0 - 0.22, landing_y),
			Vector2(x1 + 0.22, landing_y),
			Vector2(x1 + 0.22, landing_y + 0.45),
			Vector2(x0 - 0.22, landing_y + 0.45),
		])
		_append_paver_spec(decks, landing_grid, level, BRIDGE_TOP)


static func _append_civic_guardrail(
	specs: Array[Dictionary],
	start: Vector2,
	end: Vector2,
	solid_plinth: bool = false
) -> void:
	var span := start.distance_to(end)
	if span < 1.0:
		return

	# The guard is built entirely from screen-aligned polygons calculated from
	# the structural edge. No raster or SVG needs to be scaled to fit a stair or
	# bridge, so the geometry stays perfectly attached when the authoring region
	# changes size.
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
		# Small integrated cyan marker gives the civic rail the same technological
		# language as the city lamps without making the entire edge glow.
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
