extends RefCounted
class_name CentralCityUrbanLayout

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")
const TOPOLOGY = preload("res://src/world/runtime/CentralCityTopology.gd")
const CONFIG_PATH := "res://assets/resources/world/central_city_urban_layout.json"
const AUTHORING = preload("res://src/world/authoring/CentralCityAuthoringData.gd")
const LAYOUT_Z := -1170

static var _config_cache: Dictionary = {}


static func clear_cache() -> void:
	_config_cache.clear()


static func build() -> Dictionary:
	var root := Node2D.new()
	root.name = "CityUrbanLayout"
	root.z_index = LAYOUT_Z

	var polygon_count := 0
	var layer_count := 0
	var road_result := _build_road_network(root)
	polygon_count += int(road_result.get("polygon_count", 0))
	if int(road_result.get("polygon_count", 0)) > 0:
		layer_count += 1

	var config := _load_config()
	var layers_value = config.get("layers", [])
	if layers_value is Array:
		for raw_layer in layers_value:
			if not raw_layer is Dictionary:
				continue
			var result := _build_area_layer(root, raw_layer as Dictionary)
			polygon_count += int(result.get("polygon_count", 0))
			if int(result.get("polygon_count", 0)) > 0:
				layer_count += 1

	root.set_meta("polygon_count", polygon_count)
	root.set_meta("layer_count", layer_count)
	root.set_meta("road_graph_connected", TOPOLOGY.road_graph_is_connected())
	return {
		"root": root,
		"polygon_count": polygon_count,
		"layer_count": layer_count,
		"road_graph_connected": TOPOLOGY.road_graph_is_connected(),
	}


static func _build_road_network(root: Node2D) -> Dictionary:
	var network := TOPOLOGY.road_network()
	if network.is_empty():
		return {"polygon_count": 0}

	var paths_value = network.get("paths", [])
	if paths_value is Array and not paths_value.is_empty():
		return _build_authored_road_paths(root, paths_value as Array, network)

	var nodes_value = network.get("nodes", [])
	var edges_value = network.get("edges", [])
	if not nodes_value is Array or not edges_value is Array:
		return {"polygon_count": 0}

	var nodes := {}
	for raw_node in nodes_value:
		if not raw_node is Dictionary:
			continue
		var node := raw_node as Dictionary
		var id := String(node.get("id", ""))
		var raw_grid = node.get("grid", [])
		if id.is_empty() or not raw_grid is Array or raw_grid.size() < 2:
			continue
		nodes[id] = {
			"grid": Vector2(float(raw_grid[0]), float(raw_grid[1])),
			"level": String(node.get("level", "")),
		}

	var surface := String(network.get("surface", CITY.SURFACE_DARK))
	var tint := _color(network.get("tint", [1.0, 1.0, 1.0, 1.0]))
	var fill_color := _tinted_surface_color(surface, tint)
	var border_color := _color(network.get("border_color", [0.31, 0.33, 0.35, 1.0]))
	var default_width := maxf(0.75, float(network.get("width", 3.0)))
	var border_grid := maxf(0.0, float(network.get("border_width_grid", 0.12)))

	var fills: Array[Dictionary] = []
	var underlays: Array[Dictionary] = []
	var node_widths := {}
	var polygon_count := 0

	for raw_edge in edges_value:
		if not raw_edge is Dictionary:
			continue
		var edge := raw_edge as Dictionary
		if String(edge.get("type", "road")) != "road":
			continue
		var from_id := String(edge.get("from", ""))
		var to_id := String(edge.get("to", ""))
		if not nodes.has(from_id) or not nodes.has(to_id):
			continue
		var from_node := nodes[from_id] as Dictionary
		var to_node := nodes[to_id] as Dictionary
		var from_grid: Vector2 = from_node.get("grid", Vector2.ZERO)
		var to_grid: Vector2 = to_node.get("grid", Vector2.ZERO)
		var level := String(from_node.get("level", ""))
		if level != String(to_node.get("level", "")):
			push_error("CentralCityUrbanLayout: road edge %s -> %s crosses levels without a transition" % [from_id, to_id])
			continue
		var width := maxf(0.75, float(edge.get("width", default_width)))
		var corridor := _axis_corridor(from_grid, to_grid, width)
		if corridor.size() < 3:
			continue
		_append_grid_spec(fills, corridor, level, fill_color)
		_append_grid_spec(underlays, _axis_corridor(from_grid, to_grid, width + border_grid * 2.0), level, border_color)
		node_widths[from_id] = maxf(float(node_widths.get(from_id, 0.0)), width)
		node_widths[to_id] = maxf(float(node_widths.get(to_id, 0.0)), width)
		polygon_count += 1

	for node_id_value in node_widths.keys():
		var node_id := String(node_id_value)
		var node := nodes[node_id] as Dictionary
		var grid: Vector2 = node.get("grid", Vector2.ZERO)
		var level := String(node.get("level", ""))
		var width := float(node_widths[node_id])
		var pad := _grid_square(grid, width * 0.5)
		_append_grid_spec(fills, pad, level, fill_color)
		_append_grid_spec(underlays, _grid_square(grid, width * 0.5 + border_grid), level, border_color)
		polygon_count += 1

	if not underlays.is_empty():
		var edges := CITY.create_paver_polygon_batch(underlays, 0)
		edges.name = "Edges_road_network"
		edges.z_index = 0
		root.add_child(edges)
	if not fills.is_empty():
		var surface_mesh := CITY.create_paver_polygon_batch(fills, 1)
		surface_mesh.name = "Surface_road_network"
		surface_mesh.z_index = 1
		root.add_child(surface_mesh)
	return {"polygon_count": polygon_count}


static func _build_authored_road_paths(
	root: Node2D,
	paths: Array,
	network: Dictionary
) -> Dictionary:
	var fills: Array[Dictionary] = []
	var underlays: Array[Dictionary] = []
	var polygon_count := 0
	var junctions := {}

	for raw_path in paths:
		if not raw_path is Dictionary:
			continue
		var path := raw_path as Dictionary
		var points_value = path.get("grid_points", [])
		if not points_value is Array or points_value.size() < 2:
			continue
		var grid_points: Array[Vector2] = []
		for raw_point in points_value as Array:
			if raw_point is Array and raw_point.size() >= 2:
				grid_points.append(Vector2(float(raw_point[0]), float(raw_point[1])))
		if grid_points.size() < 2:
			continue

		var level := String(path.get("level", "upper_civic"))
		var width := maxf(0.75, float(path.get("width", network.get("width", 3.0))))
		var surface := String(path.get("surface", network.get("surface", CITY.SURFACE_DARK)))
		var tint := _color(path.get("tint", network.get("tint", [1.0, 1.0, 1.0, 1.0])))
		var fill_color := _tinted_surface_color(surface, tint)
		var border_grid := maxf(
			0.0,
			float(path.get("border_width_grid", network.get("border_width_grid", 0.12)))
		)
		var border_color := _color(
			path.get("border_color", network.get("border_color", [0.31, 0.33, 0.35, 1.0]))
		)

		for index in range(grid_points.size() - 1):
			var corridor := _axis_corridor(grid_points[index], grid_points[index + 1], width)
			if corridor.size() < 3:
				continue
			_append_grid_spec(fills, corridor, level, fill_color)
			_append_grid_spec(
				underlays,
				_axis_corridor(grid_points[index], grid_points[index + 1], width + border_grid * 2.0),
				level,
				border_color
			)
			polygon_count += 1

		for point: Vector2 in grid_points:
			var key := "%s:%.3f:%.3f" % [level, point.x, point.y]
			var current = junctions.get(key, {})
			if not current is Dictionary or current.is_empty() or width > float((current as Dictionary).get("width", 0.0)):
				junctions[key] = {
					"grid": point,
					"level": level,
					"width": width,
					"border_grid": border_grid,
					"fill_color": fill_color,
					"border_color": border_color,
				}

	for raw_junction in junctions.values():
		if not raw_junction is Dictionary:
			continue
		var junction := raw_junction as Dictionary
		var point: Vector2 = junction.get("grid", Vector2.ZERO)
		var level := String(junction.get("level", "upper_civic"))
		var width := float(junction.get("width", 3.0))
		var border_grid := float(junction.get("border_grid", 0.12))
		_append_grid_spec(
			fills,
			_grid_square(point, width * 0.5),
			level,
			junction.get("fill_color", Color.WHITE) as Color
		)
		_append_grid_spec(
			underlays,
			_grid_square(point, width * 0.5 + border_grid),
			level,
			junction.get("border_color", Color(0.31, 0.33, 0.35, 1.0)) as Color
		)
		polygon_count += 1

	if not underlays.is_empty():
		var edge_mesh := CITY.create_paver_polygon_batch(underlays, 0)
		edge_mesh.name = "Edges_road_network"
		edge_mesh.z_index = 0
		root.add_child(edge_mesh)
	if not fills.is_empty():
		var surface_mesh := CITY.create_paver_polygon_batch(fills, 1)
		surface_mesh.name = "Surface_road_network"
		surface_mesh.z_index = 1
		root.add_child(surface_mesh)
	return {"polygon_count": polygon_count}


static func _build_area_layer(root: Node2D, layer: Dictionary) -> Dictionary:
	var layer_id := String(layer.get("id", "area"))
	var polygons_value = layer.get("polygons", [])
	if not polygons_value is Array or polygons_value.is_empty():
		return {"polygon_count": 0}

	var fills: Array[Dictionary] = []
	var borders: Array[Dictionary] = []
	var layer_surface := String(layer.get("surface", CITY.SURFACE_MAIN))
	var layer_tint := _color(layer.get("tint", [1.0, 1.0, 1.0, 1.0]))
	var layer_level := String(layer.get("level", ""))
	var border_width := maxf(0.0, float(layer.get("border_width", 0.0)))
	var border_color := _color(layer.get("border_color", [0.35, 0.36, 0.37, 1.0]))
	var polygon_count := 0

	for raw_polygon in polygons_value:
		if not raw_polygon is Dictionary:
			continue
		var polygon := raw_polygon as Dictionary
		var raw_grid = polygon.get("grid_polygon", [])
		var grid_points := _grid_points(raw_grid)
		if grid_points.size() < 3:
			continue
		var level := String(polygon.get("level", layer_level))
		if level.is_empty():
			level = TOPOLOGY.level_at_grid(_centroid(grid_points))
		var logical_points := _grid_to_logical_world(grid_points)
		var display_points := _logical_to_display(logical_points, level)
		var surface := String(polygon.get("surface", layer_surface))
		var tint := _color(polygon.get("tint", [layer_tint.r, layer_tint.g, layer_tint.b, layer_tint.a]))
		fills.append({
			"points": display_points,
			"logical_points": logical_points,
			"color": _tinted_surface_color(surface, tint),
		})

		var polygon_border_width := maxf(0.0, float(polygon.get("border_width", border_width)))
		if polygon_border_width > 0.0:
			var authored_border := _color(polygon.get("border_color", [border_color.r, border_color.g, border_color.b, border_color.a]))
			var expanded_logical := _expand_polygon(logical_points, polygon_border_width)
			borders.append({
				"points": _logical_to_display(expanded_logical, level),
				"logical_points": expanded_logical,
				"color": authored_border,
			})
		polygon_count += 1

	if fills.is_empty():
		return {"polygon_count": 0}
	var token := _node_token(layer_id)
	if not borders.is_empty():
		var edge_mesh := CITY.create_paver_polygon_batch(borders, 0)
		edge_mesh.name = "Edges_%s" % token
		edge_mesh.z_index = 0
		root.add_child(edge_mesh)
	var surface_mesh := CITY.create_paver_polygon_batch(fills, 1)
	surface_mesh.name = "Surface_%s" % token
	surface_mesh.z_index = 1
	root.add_child(surface_mesh)
	return {"polygon_count": polygon_count}


static func _append_grid_spec(
	target: Array[Dictionary],
	grid_points: PackedVector2Array,
	level: String,
	color: Color
) -> void:
	var logical := _grid_to_logical_world(grid_points)
	target.append({
		"points": _logical_to_display(logical, level),
		"logical_points": logical,
		"color": color,
	})


static func _axis_corridor(a: Vector2, b: Vector2, width: float) -> PackedVector2Array:
	var half := width * 0.5
	if absf(a.x - b.x) <= 0.001:
		var y0 := minf(a.y, b.y) - half
		var y1 := maxf(a.y, b.y) + half
		return PackedVector2Array([
			Vector2(a.x - half, y0),
			Vector2(a.x + half, y0),
			Vector2(a.x + half, y1),
			Vector2(a.x - half, y1),
		])
	if absf(a.y - b.y) <= 0.001:
		var x0 := minf(a.x, b.x) - half
		var x1 := maxf(a.x, b.x) + half
		return PackedVector2Array([
			Vector2(x0, a.y - half),
			Vector2(x1, a.y - half),
			Vector2(x1, a.y + half),
			Vector2(x0, a.y + half),
		])
	push_error("CentralCityUrbanLayout: road segments must follow one isometric grid axis")
	return PackedVector2Array()


static func _grid_square(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(center.x - half, center.y - half),
		Vector2(center.x + half, center.y - half),
		Vector2(center.x + half, center.y + half),
		Vector2(center.x - half, center.y + half),
	])


static func _grid_points(value) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not value is Array:
		return points
	for raw_point in value:
		if raw_point is Array and raw_point.size() >= 2:
			points.append(Vector2(float(raw_point[0]), float(raw_point[1])))
	return points


static func _grid_to_logical_world(grid_points: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for grid: Vector2 in grid_points:
		points.append(TOPOLOGY.grid_to_world(grid))
	return points


static func _logical_to_display(points: PackedVector2Array, level: String) -> PackedVector2Array:
	var result := PackedVector2Array()
	var elevation := TOPOLOGY.elevation_for_level(level)
	for point: Vector2 in points:
		result.append(point + Vector2(0.0, -elevation))
	return result


static func _load_config() -> Dictionary:
	if not _config_cache.is_empty():
		return _config_cache
	if AUTHORING.has_authoring_scene():
		var authored := AUTHORING.urban_layout_config()
		if not authored.is_empty():
			_config_cache = authored.duplicate(true)
			return _config_cache
	if not FileAccess.file_exists(CONFIG_PATH):
		push_error("CentralCityUrbanLayout: missing layout config %s" % CONFIG_PATH)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary:
		push_error("CentralCityUrbanLayout: invalid JSON in %s" % CONFIG_PATH)
		return {}
	_config_cache = (parsed as Dictionary).duplicate(true)
	return _config_cache


static func _tinted_surface_color(surface: String, tint: Color) -> Color:
	var base := CITY.surface_base_color(surface)
	return Color(
		clampf(base.r * tint.r, 0.0, 1.0),
		clampf(base.g * tint.g, 0.0, 1.0),
		clampf(base.b * tint.b, 0.0, 1.0),
		clampf(base.a * tint.a, 0.0, 1.0)
	)


static func _expand_polygon(points: PackedVector2Array, margin: float) -> PackedVector2Array:
	if points.is_empty() or margin <= 0.0:
		return points.duplicate()
	var center := _centroid(points)
	var expanded := PackedVector2Array()
	for point: Vector2 in points:
		var direction := point - center
		expanded.append(point if direction.length_squared() < 0.001 else point + direction.normalized() * margin)
	return expanded


static func _centroid(points: PackedVector2Array) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var result := Vector2.ZERO
	for point: Vector2 in points:
		result += point
	return result / float(points.size())


static func _node_token(value: String) -> String:
	var token := value.strip_edges().to_lower()
	token = token.replace(" ", "_")
	token = token.replace("-", "_")
	return token


static func _color(value) -> Color:
	if value is Array and value.size() >= 3:
		return Color(
			float(value[0]),
			float(value[1]),
			float(value[2]),
			float(value[3]) if value.size() >= 4 else 1.0
		)
	return Color.WHITE
