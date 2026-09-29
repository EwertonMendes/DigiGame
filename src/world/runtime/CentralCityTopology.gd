extends RefCounted
class_name CentralCityTopology

const CONFIG_PATH := "res://assets/resources/world/central_city_topology.json"
const AUTHORING = preload("res://src/world/authoring/CentralCityAuthoringData.gd")
const PAINT_DATA = preload("res://src/world/runtime/GroundPaintData.gd")
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const TILE_HALF_WIDTH := TILE_WIDTH * 0.5
const TILE_HALF_HEIGHT := TILE_HEIGHT * 0.5
const INVALID_LEVEL := ""
const STAIR_ENTRY_MARGIN_GRID := 0.20
const SEGMENT_EPSILON := 0.001

static var _config_cache: Dictionary = {}
static var _transition_lane_cache: Dictionary = {}


static func clear_cache() -> void:
	_config_cache.clear()
	_transition_lane_cache.clear()


static func config() -> Dictionary:
	if not _config_cache.is_empty():
		return _config_cache
	if AUTHORING.has_authoring_scene():
		var authored := AUTHORING.topology_config()
		if not authored.is_empty():
			_config_cache = authored.duplicate(true)
			return _config_cache
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("CentralCityTopology: missing topology config %s" % CONFIG_PATH)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary:
		push_error("CentralCityTopology: invalid JSON in %s" % CONFIG_PATH)
		return {}
	_config_cache = (parsed as Dictionary).duplicate(true)
	return _config_cache


static func levels() -> Dictionary:
	var value = config().get("levels", {})
	return value as Dictionary if value is Dictionary else {}


static func level_break() -> Dictionary:
	var value = config().get("level_break", {})
	return value as Dictionary if value is Dictionary else {}


static func stairs() -> Array:
	var value = config().get("stairs", [])
	return (value as Array).duplicate(true) if value is Array else []


static func voids() -> Array:
	var value = config().get("voids", [])
	return (value as Array).duplicate(true) if value is Array else []


static func bridges() -> Array:
	var value = config().get("bridges", [])
	return (value as Array).duplicate(true) if value is Array else []


static func road_network() -> Dictionary:
	var value = config().get("road_network", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func fitted_transition_lane(transition: Dictionary) -> Dictionary:
	if transition.is_empty():
		return {}

	var id := String(transition.get("id", ""))
	var x_min := minf(float(transition.get("x_min", 0.0)), float(transition.get("x_max", 0.0)))
	var x_max := maxf(float(transition.get("x_min", 0.0)), float(transition.get("x_max", 0.0)))
	var y_min := minf(
		float(transition.get("y_start", transition.get("y_min", 0.0))),
		float(transition.get("y_end", transition.get("y_max", 0.0)))
	)
	var y_max := maxf(
		float(transition.get("y_start", transition.get("y_min", 0.0))),
		float(transition.get("y_end", transition.get("y_max", 0.0)))
	)
	var cache_key := "%s:%.3f:%.3f:%.3f:%.3f" % [id, x_min, x_max, y_min, y_max]
	if _transition_lane_cache.has(cache_key):
		return (_transition_lane_cache[cache_key] as Dictionary).duplicate(true)

	# Transition authoring defines where a stair/bridge belongs structurally.
	# Its visible width is intentionally resolved from the painted floor at the
	# two insertion mouths. This makes the module follow the road/plaza actually
	# painted by the level author instead of preserving a stale hard-coded span.
	var upper_row := int(floor(y_min - 0.001))
	var lower_row := int(ceil(y_max + 0.001))
	var upper := _painted_lane_at_row(x_min, x_max, upper_row)
	var lower := _painted_lane_at_row(x_min, x_max, lower_row)
	var resolved: Dictionary = {}
	if upper.is_empty():
		resolved = lower
	elif lower.is_empty():
		resolved = upper
	else:
		var authored_width := maxf(0.001, x_max - x_min)
		var upper_width := float(upper.get("x_max", x_max)) - float(upper.get("x_min", x_min))
		var lower_width := float(lower.get("x_max", x_max)) - float(lower.get("x_min", x_min))
		var upper_persistence := _lane_persistence(upper, upper_row, -1)
		var lower_persistence := _lane_persistence(lower, lower_row, 1)
		if not is_equal_approx(upper_persistence, lower_persistence):
			# A real corridor keeps roughly the same painted width for several
			# rows away from the transition. Intersections and diagonal joins do
			# not, so persistence is a stronger signal than the stale polygon size.
			resolved = upper if upper_persistence > lower_persistence else lower
		else:
			var upper_delta := absf(upper_width - authored_width)
			var lower_delta := absf(lower_width - authored_width)
			if not is_equal_approx(upper_delta, lower_delta):
				resolved = upper if upper_delta < lower_delta else lower
			else:
				resolved = upper if upper_width <= lower_width else lower

	# A bridge that physically starts/ends at a stair mouth must inherit that
	# stair's fitted lane exactly. Resolving both modules independently from paint
	# can be numerically valid yet still leave them one cell/half-cell apart after
	# authoring changes. Structural adjacency has stronger authority here: one
	# corridor means one x interval from stair through bridge.
	if transition.has("y_min") and transition.has("y_max"):
		var connected_lane := _connected_stair_lane_for_bridge(transition)
		if not connected_lane.is_empty():
			resolved = connected_lane

	if not resolved.is_empty():
		_transition_lane_cache[cache_key] = resolved.duplicate(true)
	return resolved.duplicate(true)


static func _connected_stair_lane_for_bridge(bridge: Dictionary) -> Dictionary:
	var bridge_x_min := minf(float(bridge.get("x_min", 0.0)), float(bridge.get("x_max", 0.0)))
	var bridge_x_max := maxf(float(bridge.get("x_min", 0.0)), float(bridge.get("x_max", 0.0)))
	var bridge_y_min := minf(float(bridge.get("y_min", 0.0)), float(bridge.get("y_max", 0.0)))
	var bridge_y_max := maxf(float(bridge.get("y_min", 0.0)), float(bridge.get("y_max", 0.0)))
	var best_lane: Dictionary = {}
	var best_overlap := 0.0

	var value = config().get("stairs", [])
	if not value is Array:
		return {}
	for raw_stair in value as Array:
		if not raw_stair is Dictionary:
			continue
		var stair := raw_stair as Dictionary
		var stair_y_min := minf(float(stair.get("y_start", 0.0)), float(stair.get("y_end", 0.0)))
		var stair_y_max := maxf(float(stair.get("y_start", 0.0)), float(stair.get("y_end", 0.0)))
		var touches_mouth := (
			absf(stair_y_max - bridge_y_min) <= 0.01
			or absf(stair_y_min - bridge_y_max) <= 0.01
		)
		if not touches_mouth:
			continue
		var stair_x_min := minf(float(stair.get("x_min", 0.0)), float(stair.get("x_max", 0.0)))
		var stair_x_max := maxf(float(stair.get("x_min", 0.0)), float(stair.get("x_max", 0.0)))
		var authored_overlap := maxf(
			0.0,
			minf(bridge_x_max, stair_x_max) - maxf(bridge_x_min, stair_x_min)
		)
		if authored_overlap <= best_overlap:
			continue
		var stair_lane := fitted_transition_lane(stair)
		if stair_lane.is_empty():
			continue
		best_overlap = authored_overlap
		best_lane = stair_lane.duplicate(true)

	return best_lane


static func fitted_transition_rect(transition: Dictionary) -> Dictionary:
	if transition.is_empty():
		return {}

	var lane := fitted_transition_lane(transition)
	var authored_x_min := minf(
		float(transition.get("x_min", 0.0)),
		float(transition.get("x_max", 0.0))
	)
	var authored_x_max := maxf(
		float(transition.get("x_min", 0.0)),
		float(transition.get("x_max", 0.0))
	)
	var raw_y_min := minf(
		float(transition.get("y_start", transition.get("y_min", 0.0))),
		float(transition.get("y_end", transition.get("y_max", 0.0)))
	)
	var raw_y_max := maxf(
		float(transition.get("y_start", transition.get("y_min", 0.0))),
		float(transition.get("y_end", transition.get("y_max", 0.0)))
	)

	# Structural transition mouths live on cell boundaries. Snapping to the
	# half-grid lattice means a stair/bridge owns a whole-cell rectangle and the
	# normal ground owns the immediately adjacent rectangle. They therefore
	# share one mathematical edge instead of overlapping two independently
	# rendered surfaces and hiding the seam with overscan.
	var rect := {
		"x_min": float(lane.get("x_min", authored_x_min)),
		"x_max": float(lane.get("x_max", authored_x_max)),
		"y_min": _snap_half_grid(raw_y_min),
		"y_max": _snap_half_grid(raw_y_max),
	}
	if not lane.is_empty():
		rect["surface"] = lane.get("surface", "")
		rect["sample_grid"] = lane.get("sample_grid", Vector2.ZERO)
	return rect


static func _snap_half_grid(value: float) -> float:
	return floor(value * 2.0 + 0.5) * 0.5


static func _painted_lane_at_row(
	authored_x_min: float,
	authored_x_max: float,
	row_y: int
) -> Dictionary:
	var painted := AUTHORING.painted_cells()
	if painted.is_empty():
		return {}

	var center_x := (authored_x_min + authored_x_max) * 0.5
	var scan_min := floori(authored_x_min) - 8
	var scan_max := ceili(authored_x_max) + 8
	var runs: Array[Dictionary] = []
	var current: Dictionary = {}

	for x in range(scan_min, scan_max + 1):
		var key := "%d,%d" % [x, row_y]
		var surface := ""
		if painted.has(key):
			surface = PAINT_DATA.surface(painted.get(key, ""))
		if surface in ["", "water", "void"]:
			if not current.is_empty():
				runs.append(current)
				current = {}
			continue

		if (
			current.is_empty()
			or String(current.get("surface", "")) != surface
			or x != int(current.get("last_x", x - 1)) + 1
		):
			if not current.is_empty():
				runs.append(current)
			current = {
				"surface": surface,
				"first_x": x,
				"last_x": x,
			}
		else:
			current["last_x"] = x
	if not current.is_empty():
		runs.append(current)

	var best: Dictionary = {}
	var best_overlap := -1.0
	var best_distance := INF
	for run in runs:
		var first_x := int(run.get("first_x", 0))
		var last_x := int(run.get("last_x", first_x))
		var run_min := float(first_x) - 0.5
		var run_max := float(last_x) + 0.5
		var overlap := maxf(
			0.0,
			minf(run_max, authored_x_max) - maxf(run_min, authored_x_min)
		)
		var run_center := (run_min + run_max) * 0.5
		var distance := absf(run_center - center_x)
		if overlap > best_overlap + 0.001 or (
			is_equal_approx(overlap, best_overlap) and distance < best_distance
		):
			best_overlap = overlap
			best_distance = distance
			best = {
				"x_min": run_min,
				"x_max": run_max,
				"surface": String(run.get("surface", "")),
				"row_y": row_y,
				"sample_grid": Vector2(float(first_x), float(row_y)),
			}

	if best_overlap <= 0.0:
		return {}
	return best


static func _lane_persistence(lane: Dictionary, row_y: int, direction: int) -> float:
	if lane.is_empty():
		return 0.0
	var surface := String(lane.get("surface", ""))
	var lane_min := float(lane.get("x_min", 0.0))
	var lane_max := float(lane.get("x_max", 0.0))
	var lane_width := maxf(0.001, lane_max - lane_min)
	var score := 0.0
	for offset in [1, 2]:
		var neighbor := _painted_lane_at_row(
			lane_min,
			lane_max,
			row_y + direction * offset
		)
		if neighbor.is_empty() or String(neighbor.get("surface", "")) != surface:
			continue
		var neighbor_min := float(neighbor.get("x_min", lane_min))
		var neighbor_max := float(neighbor.get("x_max", lane_max))
		var overlap := maxf(0.0, minf(lane_max, neighbor_max) - maxf(lane_min, neighbor_min))
		score += overlap / lane_width
	return score


static func elevation_for_level(level_id: String) -> float:
	var level_value = levels().get(level_id, {})
	if not level_value is Dictionary:
		return 0.0
	return maxf(0.0, float((level_value as Dictionary).get("elevation_px", 0.0)))


static func level_at_grid(grid: Vector2) -> String:
	var transition := _stair_at_grid_ref(grid)
	if not transition.is_empty():
		return String(
			transition.get(
				"from_level" if stair_progress(grid, transition) <= 0.5 else "to_level",
				INVALID_LEVEL
			)
		)

	var break_data := level_break()
	var threshold := float(break_data.get("lower_threshold_y", 19.5))
	if grid.y < threshold:
		return String(break_data.get("upper_level", "upper_civic"))
	return String(break_data.get("lower_level", "south_terrace"))


static func elevation_at_grid(grid: Vector2) -> float:
	var transition := _stair_at_grid_ref(grid)
	if not transition.is_empty():
		var from_level := String(transition.get("from_level", "upper_civic"))
		var to_level := String(transition.get("to_level", "south_terrace"))
		var from_elevation := elevation_for_level(from_level)
		var to_elevation := elevation_for_level(to_level)
		var t := stair_progress(grid, transition)
		return lerpf(from_elevation, to_elevation, t)
	return elevation_for_level(level_at_grid(grid))


static func stair_progress(grid: Vector2, stair: Dictionary) -> float:
	var rect := fitted_transition_rect(stair)
	var y_start := float(rect.get("y_min", stair.get("y_start", grid.y)))
	var y_end := float(rect.get("y_max", stair.get("y_end", y_start + 1.0)))
	return (
		1.0
		if is_equal_approx(y_start, y_end)
		else clampf((grid.y - y_start) / (y_end - y_start), 0.0, 1.0)
	)


static func visual_offset_at_grid(grid: Vector2) -> Vector2:
	return Vector2(0.0, -elevation_at_grid(grid))


static func grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_HALF_WIDTH,
		(grid.x + grid.y) * TILE_HALF_HEIGHT
	)


static func world_to_grid(world: Vector2) -> Vector2:
	return Vector2(
		world.x / TILE_WIDTH + world.y / TILE_HEIGHT,
		-world.x / TILE_WIDTH + world.y / TILE_HEIGHT
	)


static func grid_to_display(grid: Vector2, forced_level: String = "") -> Vector2:
	var elevation := (
		elevation_for_level(forced_level)
		if not forced_level.is_empty()
		else elevation_at_grid(grid)
	)
	return grid_to_world(grid) + Vector2(0.0, -elevation)


static func stair_at_grid(grid: Vector2) -> Dictionary:
	var stair := _stair_at_grid_ref(grid)
	return stair.duplicate(true) if not stair.is_empty() else {}


static func _stair_at_grid_ref(grid: Vector2) -> Dictionary:
	var value = config().get("stairs", [])
	if not value is Array:
		return {}
	for raw in value as Array:
		if not raw is Dictionary:
			continue
		var stair := raw as Dictionary
		var rect := fitted_transition_rect(stair)
		if rect.is_empty():
			continue
		if _point_in_rect(
			grid,
			float(rect.get("x_min", 0.0)),
			float(rect.get("x_max", 0.0)),
			float(rect.get("y_min", 0.0)),
			float(rect.get("y_max", 0.0))
		):
			return stair
	return {}


static func bridge_at_grid(grid: Vector2) -> Dictionary:
	for raw in bridges():
		if not raw is Dictionary:
			continue
		var bridge := raw as Dictionary
		var rect := fitted_transition_rect(bridge)
		if rect.is_empty():
			continue
		if _point_in_rect(
			grid,
			float(rect.get("x_min", 0.0)),
			float(rect.get("x_max", 0.0)),
			float(rect.get("y_min", 0.0)),
			float(rect.get("y_max", 0.0))
		):
			return bridge.duplicate(true)
	return {}


static func void_at_grid(grid: Vector2) -> Dictionary:
	for raw in voids():
		if not raw is Dictionary:
			continue
		var void_region := raw as Dictionary
		if _point_in_transition(
			grid,
			void_region,
			float(void_region.get("x_min", 0.0)),
			float(void_region.get("x_max", 0.0)),
			float(void_region.get("y_min", 0.0)),
			float(void_region.get("y_max", 0.0))
		):
			return void_region.duplicate(true)
	return {}


static func is_void_at_grid(grid: Vector2) -> bool:
	return not void_at_grid(grid).is_empty() and bridge_at_grid(grid).is_empty()


static func can_traverse_grid_segment(from_grid: Vector2, to_grid: Vector2) -> bool:
	if from_grid.distance_squared_to(to_grid) <= SEGMENT_EPSILON * SEGMENT_EPSILON:
		return true

	# When the painted lane is narrower than the structural transition polygon,
	# the leftover strip becomes retaining-wall infill. It stays rendered as
	# floor underlay but is never traversable, so shrinking a stair to match a
	# painted road cannot accidentally create a lateral shortcut beside it.
	if (
		_is_stair_side_infill(from_grid)
		or _is_stair_side_infill(to_grid)
		or _is_stair_side_infill((from_grid + to_grid) * 0.5)
	):
		return false

	var from_stair := _stair_at_grid_ref(from_grid)
	var to_stair := _stair_at_grid_ref(to_grid)
	if not from_stair.is_empty() or not to_stair.is_empty():
		if not from_stair.is_empty() and not to_stair.is_empty():
			if String(from_stair.get("id", "")) != String(to_stair.get("id", "")):
				return false
		elif from_stair.is_empty():
			if not _crosses_stair_landing(from_grid, to_grid, to_stair):
				return false
		else:
			if not _crosses_stair_landing(to_grid, from_grid, from_stair):
				return false

	var break_data := level_break()
	var threshold := float(break_data.get("lower_threshold_y", 19.5))
	if not _segment_crosses_y(from_grid, to_grid, threshold):
		return true

	var crossing_x := _segment_x_at_y(from_grid, to_grid, threshold)
	var x_min := float(break_data.get("x_min", -INF))
	var x_max := float(break_data.get("x_max", INF))
	if crossing_x < minf(x_min, x_max) or crossing_x > maxf(x_min, x_max):
		return true

	var stair := _stair_at_grid_ref(Vector2(crossing_x, threshold))
	if stair.is_empty():
		return false
	return _stair_x_is_inside_walkway(crossing_x, stair)


static func can_traverse_world_segment(from_world: Vector2, to_world: Vector2) -> bool:
	return can_traverse_grid_segment(world_to_grid(from_world), world_to_grid(to_world))


static func ground_rule_for_cell(global_grid: Vector2i) -> Dictionary:
	var point := Vector2(global_grid)
	if _is_stair_side_infill(point):
		return {
			"render": true,
			"walkable": false,
			"inherit_surface": true,
			"stair_side_infill": true,
		}

	var stair := _stair_at_grid_ref(point)
	if not stair.is_empty():
		# The stair owns this exact half-grid-aligned cell rectangle. Do not keep a
		# second copy of the road/floor below it: coplanar overlap is what made the
		# mouths look blurred and "pasted on". The transition mesh supplies the
		# visible surface while movement remains independently walkable.
		return {
			"render": false,
			"walkable": true,
			"stair_transition": true,
		}

	var break_data := level_break()
	var break_y := int(floor(float(break_data.get("lower_threshold_y", 19.5))))
	var x_min := float(break_data.get("x_min", -INF))
	var x_max := float(break_data.get("x_max", INF))
	if global_grid.y == break_y and point.x >= x_min and point.x <= x_max:
		return {
			"render": true,
			"walkable": false,
			"inherit_surface": true,
			"terrace_boundary_surface": true,
		}

	var void_region := void_at_grid(point)
	if not void_region.is_empty():
		var bridge := bridge_at_grid(point)
		if not bridge.is_empty():
			# Bridges follow the same ownership rule as stairs: the deck replaces
			# the base floor in a whole-cell rectangle and meets the adjacent terrain
			# on a shared edge, so there is no hidden road slab underneath it.
			return {
				"render": false,
				"walkable": true,
				"bridge_transition": true,
			}
		# Water basins still keep the base city floor as a hidden underlay because
		# the authored basin polygon is not restricted to whole gameplay cells.
		return {
			"render": true,
			"walkable": false,
			"basin_underlay": true,
		}
	return {}


static func is_route_reserved(grid: Vector2, extra_margin: float = 0.0) -> bool:
	var network := road_network()
	if String(network.get("mode", "")) == "painted_tiles":
		var cells_value = network.get("cells", [])
		if not cells_value is Array:
			return false
		var radius := 0.75 + maxf(0.0, extra_margin)
		for raw_key in cells_value as Array:
			var parts := String(raw_key).split(",", false)
			if parts.size() != 2:
				continue
			var road_cell := Vector2(float(parts[0]), float(parts[1]))
			if grid.distance_to(road_cell) <= radius:
				return true
		return false

	var nodes_value = network.get("nodes", [])
	var edges_value = network.get("edges", [])
	if not nodes_value is Array or not edges_value is Array:
		return false

	var nodes := {}
	for raw_node in nodes_value:
		if not raw_node is Dictionary:
			continue
		var node := raw_node as Dictionary
		var id := String(node.get("id", ""))
		var raw_grid = node.get("grid", [])
		if id.is_empty() or not raw_grid is Array or raw_grid.size() < 2:
			continue
		nodes[id] = Vector2(float(raw_grid[0]), float(raw_grid[1]))

	var default_width := maxf(0.5, float(network.get("width", 3.0)))
	for raw_edge in edges_value:
		if not raw_edge is Dictionary:
			continue
		var edge := raw_edge as Dictionary
		var type := String(edge.get("type", "road"))
		if type not in ["road", "stairs", "bridge"]:
			continue
		var from_id := String(edge.get("from", ""))
		var to_id := String(edge.get("to", ""))
		if not nodes.has(from_id) or not nodes.has(to_id):
			continue
		var a: Vector2 = nodes[from_id]
		var b: Vector2 = nodes[to_id]
		var width := maxf(0.5, float(edge.get("width", default_width)))
		if type in ["stairs", "bridge"]:
			width = maxf(maxf(width, absf(b.x - a.x)), 3.0)
		if _distance_to_axis_segment(grid, a, b) <= width * 0.5 + extra_margin:
			return true
	return false


static func can_place_landscape(grid: Vector2, radius_grid: float = 1.20) -> bool:
	var probes := [
		grid,
		grid + Vector2(radius_grid, 0.0),
		grid + Vector2(-radius_grid, 0.0),
		grid + Vector2(0.0, radius_grid),
		grid + Vector2(0.0, -radius_grid),
	]
	var break_data := level_break()
	var break_y := float(break_data.get("grid_y", 19.0))
	var break_x_min := float(break_data.get("x_min", -INF))
	var break_x_max := float(break_data.get("x_max", INF))
	for probe: Vector2 in probes:
		if not _stair_at_grid_ref(probe).is_empty():
			return false
		if not bridge_at_grid(probe).is_empty():
			return false
		if not void_at_grid(probe).is_empty():
			return false
		if (
			probe.x >= break_x_min - radius_grid
			and probe.x <= break_x_max + radius_grid
			and absf(probe.y - break_y) <= 1.25 + radius_grid
		):
			return false
		if is_route_reserved(probe, 0.35):
			return false
	return true


static func road_graph_is_connected() -> bool:
	var network := road_network()
	if String(network.get("mode", "")) == "painted_tiles":
		var cells_value = network.get("cells", [])
		return cells_value is Array and not (cells_value as Array).is_empty()

	var nodes_value = network.get("nodes", [])
	var edges_value = network.get("edges", [])
	if not nodes_value is Array or not edges_value is Array or nodes_value.is_empty():
		return false
	var adjacency := {}
	for raw_node in nodes_value:
		if raw_node is Dictionary:
			var id := String((raw_node as Dictionary).get("id", ""))
			if not id.is_empty():
				adjacency[id] = []
	if adjacency.is_empty():
		return false

	for raw_edge in edges_value:
		if not raw_edge is Dictionary:
			continue
		var edge := raw_edge as Dictionary
		var from_id := String(edge.get("from", ""))
		var to_id := String(edge.get("to", ""))
		if not adjacency.has(from_id) or not adjacency.has(to_id):
			return false
		(adjacency[from_id] as Array).append(to_id)
		(adjacency[to_id] as Array).append(from_id)

	var start := String(adjacency.keys()[0])
	var queue: Array[String] = [start]
	var visited := {start: true}
	while not queue.is_empty():
		var current: String = String(queue.pop_front())
		var neighbors: Array = adjacency[current] as Array
		for raw_neighbor in neighbors:
			var neighbor := String(raw_neighbor)
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return visited.size() == adjacency.size()


static func _is_stair_side_infill(point: Vector2) -> bool:
	var value = config().get("stairs", [])
	if not value is Array:
		return false
	for raw in value as Array:
		if not raw is Dictionary:
			continue
		var stair := raw as Dictionary
		var authored_x_min := minf(float(stair.get("x_min", 0.0)), float(stair.get("x_max", 0.0)))
		var authored_x_max := maxf(float(stair.get("x_min", 0.0)), float(stair.get("x_max", 0.0)))
		var rect := fitted_transition_rect(stair)
		if rect.is_empty():
			continue
		var y_min := float(rect.get("y_min", 0.0))
		var y_max := float(rect.get("y_max", 0.0))
		if not _point_in_rect(point, authored_x_min, authored_x_max, y_min, y_max):
			continue
		var lane_min := float(rect.get("x_min", authored_x_min))
		var lane_max := float(rect.get("x_max", authored_x_max))
		if point.x < lane_min - SEGMENT_EPSILON or point.x > lane_max + SEGMENT_EPSILON:
			return true
	return false


static func _crosses_stair_landing(
	outside: Vector2,
	inside: Vector2,
	stair: Dictionary
) -> bool:
	# Traversal and rendering must use the SAME fitted half-grid mouths. The
	# stair geometry was snapped to those bounds, but this check still used the
	# old authored y_start/y_end values, creating an invisible wall exactly where
	# the visible stair began.
	var rect := fitted_transition_rect(stair)
	if rect.is_empty():
		return false
	var y_start := float(rect.get("y_min", stair.get("y_start", 0.0)))
	var y_end := float(rect.get("y_max", stair.get("y_end", y_start)))

	if outside.y < y_start - SEGMENT_EPSILON and inside.y >= y_start - SEGMENT_EPSILON:
		var crossing_x := _segment_x_at_y(outside, inside, y_start)
		return _stair_x_is_inside_walkway(crossing_x, stair)
	if outside.y > y_end + SEGMENT_EPSILON and inside.y <= y_end + SEGMENT_EPSILON:
		var crossing_x := _segment_x_at_y(outside, inside, y_end)
		return _stair_x_is_inside_walkway(crossing_x, stair)
	return false


static func _stair_x_is_inside_walkway(x: float, stair: Dictionary) -> bool:
	var lane := fitted_transition_lane(stair)
	var x_min := minf(
		float(lane.get("x_min", stair.get("x_min", 0.0))),
		float(lane.get("x_max", stair.get("x_max", 0.0)))
	)
	var x_max := maxf(
		float(lane.get("x_min", stair.get("x_min", 0.0))),
		float(lane.get("x_max", stair.get("x_max", 0.0)))
	)
	var margin := minf(STAIR_ENTRY_MARGIN_GRID, maxf(0.0, (x_max - x_min) * 0.15))
	return x >= x_min + margin and x <= x_max - margin


static func _segment_crosses_y(a: Vector2, b: Vector2, y: float) -> bool:
	if absf(a.y - b.y) <= SEGMENT_EPSILON:
		return false
	return (
		(a.y < y - SEGMENT_EPSILON and b.y >= y - SEGMENT_EPSILON)
		or (b.y < y - SEGMENT_EPSILON and a.y >= y - SEGMENT_EPSILON)
	)


static func _segment_x_at_y(a: Vector2, b: Vector2, y: float) -> float:
	var delta_y := b.y - a.y
	if absf(delta_y) <= SEGMENT_EPSILON:
		return (a.x + b.x) * 0.5
	var t := clampf((y - a.y) / delta_y, 0.0, 1.0)
	return lerpf(a.x, b.x, t)


static func _point_in_transition(
	point: Vector2,
	transition: Dictionary,
	x_min: float,
	x_max: float,
	y_min: float,
	y_max: float
) -> bool:
	if not _point_in_rect(point, x_min, x_max, y_min, y_max):
		return false
	var polygon_value = transition.get("grid_polygon")
	if polygon_value is PackedVector2Array:
		var polygon := polygon_value as PackedVector2Array
		if polygon.size() >= 3:
			if Geometry2D.is_point_in_polygon(point, polygon):
				return true
			for index in range(polygon.size()):
				if _distance_to_axis_segment(
					point, polygon[index], polygon[(index + 1) % polygon.size()]
				) <= SEGMENT_EPSILON:
					return true
			return false
	return _point_in_rect(point, x_min, x_max, y_min, y_max)


static func _point_in_rect(
	point: Vector2,
	x_min: float,
	x_max: float,
	y_min: float,
	y_max: float
) -> bool:
	return (
		point.x >= minf(x_min, x_max)
		and point.x <= maxf(x_min, x_max)
		and point.y >= minf(y_min, y_max)
		and point.y <= maxf(y_min, y_max)
	)


static func _distance_to_axis_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	if absf(a.x - b.x) <= 0.001:
		var clamped_y := clampf(point.y, minf(a.y, b.y), maxf(a.y, b.y))
		return point.distance_to(Vector2(a.x, clamped_y))
	if absf(a.y - b.y) <= 0.001:
		var clamped_x := clampf(point.x, minf(a.x, b.x), maxf(a.x, b.x))
		return point.distance_to(Vector2(clamped_x, a.y))
	var segment := b - a
	if segment.length_squared() <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(a + segment * t)
