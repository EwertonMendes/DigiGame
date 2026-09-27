extends RefCounted
class_name CentralCityTopology

const CONFIG_PATH := "res://assets/resources/world/central_city_topology.json"
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const TILE_HALF_WIDTH := TILE_WIDTH * 0.5
const TILE_HALF_HEIGHT := TILE_HEIGHT * 0.5
const INVALID_LEVEL := ""
const STAIR_ENTRY_MARGIN_GRID := 0.20
const SEGMENT_EPSILON := 0.001

static var _config_cache: Dictionary = {}


static func config() -> Dictionary:
	if not _config_cache.is_empty():
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


static func elevation_for_level(level_id: String) -> float:
	var level_value = levels().get(level_id, {})
	if not level_value is Dictionary:
		return 0.0
	return maxf(0.0, float((level_value as Dictionary).get("elevation_px", 0.0)))


static func level_at_grid(grid: Vector2) -> String:
	var transition := _stair_at_grid_ref(grid)
	if not transition.is_empty():
		var y_start := float(transition.get("y_start", 0.0))
		var y_end := float(transition.get("y_end", y_start + 1.0))
		var midpoint := (y_start + y_end) * 0.5
		return String(
			transition.get(
				"from_level" if grid.y <= midpoint else "to_level",
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
		var y_start := float(transition.get("y_start", grid.y))
		var y_end := float(transition.get("y_end", y_start + 1.0))
		var from_level := String(transition.get("from_level", "upper_civic"))
		var to_level := String(transition.get("to_level", "south_terrace"))
		var from_elevation := elevation_for_level(from_level)
		var to_elevation := elevation_for_level(to_level)
		if is_equal_approx(y_start, y_end):
			return to_elevation
		var t := clampf((grid.y - y_start) / (y_end - y_start), 0.0, 1.0)
		return lerpf(from_elevation, to_elevation, t)
	return elevation_for_level(level_at_grid(grid))


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
		if _point_in_rect(
			grid,
			float(stair.get("x_min", 0.0)),
			float(stair.get("x_max", 0.0)),
			float(stair.get("y_start", 0.0)),
			float(stair.get("y_end", 0.0))
		):
			return stair
	return {}


static func bridge_at_grid(grid: Vector2) -> Dictionary:
	for raw in bridges():
		if not raw is Dictionary:
			continue
		var bridge := raw as Dictionary
		if _point_in_rect(
			grid,
			float(bridge.get("x_min", 0.0)),
			float(bridge.get("x_max", 0.0)),
			float(bridge.get("y_min", 0.0)),
			float(bridge.get("y_max", 0.0))
		):
			return bridge.duplicate(true)
	return {}


static func void_at_grid(grid: Vector2) -> Dictionary:
	for raw in voids():
		if not raw is Dictionary:
			continue
		var void_region := raw as Dictionary
		if _point_in_rect(
			grid,
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
	var stair := _stair_at_grid_ref(point)
	if not stair.is_empty():
		var y_start := float(stair.get("y_start", 0.0))
		var y_end := float(stair.get("y_end", 0.0))
		if point.y > floorf(y_start) and point.y < ceilf(y_end):
			return {"render": false, "walkable": true}

	var break_data := level_break()
	var break_y := int(round(float(break_data.get("grid_y", 19.0))))
	var x_min := float(break_data.get("x_min", -INF))
	var x_max := float(break_data.get("x_max", INF))
	if global_grid.y == break_y and point.x >= x_min and point.x <= x_max:
		return {"render": false, "walkable": not stair.is_empty()}

	var void_region := void_at_grid(point)
	if not void_region.is_empty():
		var bridge := bridge_at_grid(point)
		return {
			"render": false,
			"walkable": not bridge.is_empty(),
		}
	return {}


static func is_route_reserved(grid: Vector2, extra_margin: float = 0.0) -> bool:
	var network := road_network()
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


static func _crosses_stair_landing(
	outside: Vector2,
	inside: Vector2,
	stair: Dictionary
) -> bool:
	var y_start := minf(
		float(stair.get("y_start", 0.0)),
		float(stair.get("y_end", 0.0))
	)
	var y_end := maxf(
		float(stair.get("y_start", 0.0)),
		float(stair.get("y_end", 0.0))
	)

	if outside.y < y_start - SEGMENT_EPSILON and inside.y >= y_start - SEGMENT_EPSILON:
		var crossing_x := _segment_x_at_y(outside, inside, y_start)
		return _stair_x_is_inside_walkway(crossing_x, stair)
	if outside.y > y_end + SEGMENT_EPSILON and inside.y <= y_end + SEGMENT_EPSILON:
		var crossing_x := _segment_x_at_y(outside, inside, y_end)
		return _stair_x_is_inside_walkway(crossing_x, stair)
	return false


static func _stair_x_is_inside_walkway(x: float, stair: Dictionary) -> bool:
	var x_min := minf(float(stair.get("x_min", 0.0)), float(stair.get("x_max", 0.0)))
	var x_max := maxf(float(stair.get("x_min", 0.0)), float(stair.get("x_max", 0.0)))
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
