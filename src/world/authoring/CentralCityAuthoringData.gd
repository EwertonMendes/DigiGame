extends RefCounted
class_name CentralCityAuthoringData

const AUTHORING_SCENE_PATH := "res://scenes/world/central_city_authoring.tscn"
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const DEFAULT_SECTION_SIZE := 14
const BAKED_PATH := "res://assets/resources/world/central_city_baked.tres"

static var _cache: Dictionary = {}
static var _preview_override: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


static func set_preview_snapshot(snapshot: Dictionary) -> void:
	_preview_override = snapshot.duplicate(true)
	_cache = _preview_override.duplicate(true)


static func clear_preview_snapshot() -> void:
	_preview_override.clear()
	_cache.clear()


static func snapshot_from_root(root: Node) -> Dictionary:
	if root == null:
		return {}
	var section_size := int(root.get("section_size")) if root.get("section_size") != null else DEFAULT_SECTION_SIZE
	var area := {
		"id": String(root.get("area_id")),
		"region": String(root.get("region_id")),
		"display_name": String(root.get("display_name")),
		"subtitle": String(root.get("subtitle")),
		"section_size": section_size,
		"sections": _parse_sections(root),
	}
	var transition_data := _parse_transitions(root)
	var road_network := _parse_roads(root, transition_data)
	var topology := {
		"version": 2,
		"description": "Generated from the visual Central City authoring scene.",
		"levels": _parse_levels(root),
		"level_break": _parse_boundary(root),
		"stairs": transition_data.get("stairs", []),
		"voids": transition_data.get("voids", []),
		"bridges": transition_data.get("bridges", []),
		"road_network": road_network,
	}
	return {
		"area": area,
		"topology": topology,
		"urban_layout": _parse_surface_regions(root),
		"buildings": _parse_buildings(root),
		"props_by_section": _parse_props(root, section_size),
		"landscapes_by_section": _parse_landscapes(root, section_size),
		"ground_regions": _parse_ground_regions(root),
		"ground_paint": _parse_ground_paint(root),
	}


static func has_authoring_scene() -> bool:
	return ResourceLoader.exists(AUTHORING_SCENE_PATH)


static func area_definition() -> Dictionary:
	_ensure_cache()
	var value = _cache.get("area", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func topology_config() -> Dictionary:
	_ensure_cache()
	var value = _cache.get("topology", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func urban_layout_config() -> Dictionary:
	_ensure_cache()
	var value = _cache.get("urban_layout", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func building_anchor_grid(building_id: String, fallback: Vector2) -> Vector2:
	_ensure_cache()
	var anchors_value = _cache.get("buildings", {})
	if not anchors_value is Dictionary:
		return fallback
	var anchors := anchors_value as Dictionary
	var value = anchors.get(building_id, fallback)
	return value as Vector2 if value is Vector2 else fallback


static func decoration_placements(section_coord: Vector2i) -> Array:
	_ensure_cache()
	var sections_value = _cache.get("props_by_section", {})
	if not sections_value is Dictionary:
		return []
	var sections := sections_value as Dictionary
	var key := _section_key(section_coord)
	var value = sections.get(key, [])
	return (value as Array).duplicate(true) if value is Array else []


static func landscape_cells(section_coord: Vector2i) -> Array[Vector2]:
	_ensure_cache()
	var sections_value = _cache.get("landscapes_by_section", {})
	if not sections_value is Dictionary:
		return []
	var sections := sections_value as Dictionary
	var key := _section_key(section_coord)
	var value = sections.get(key, [])
	var result: Array[Vector2] = []
	if value is Array:
		for item in value as Array:
			if item is Vector2:
				result.append(item)
	return result


static func ground_override_at(global_grid: Vector2) -> Dictionary:
	_ensure_cache()
	var paint_value = _cache.get("ground_paint", {})
	if paint_value is Dictionary:
		var cell := Vector2i(roundi(global_grid.x), roundi(global_grid.y))
		var key := "%d,%d" % [cell.x, cell.y]
		var painted_surface := String((paint_value as Dictionary).get(key, ""))
		if not painted_surface.is_empty():
			return {
				"surface": painted_surface,
				"walkable": painted_surface not in ["water", "void"],
				"render": painted_surface != "void",
			}

	var regions_value = _cache.get("ground_regions", [])
	if not regions_value is Array:
		return {}
	var best_priority := -2147483648
	var best: Dictionary = {}
	for raw in regions_value as Array:
		if not raw is Dictionary:
			continue
		var region := raw as Dictionary
		var polygon_value = region.get("grid_polygon", PackedVector2Array())
		if not polygon_value is PackedVector2Array:
			continue
		var polygon := polygon_value as PackedVector2Array
		if polygon.size() < 3 or not Geometry2D.is_point_in_polygon(global_grid, polygon):
			continue
		var priority := int(region.get("priority", 0))
		if priority < best_priority:
			continue
		best_priority = priority
		best = region.duplicate(true)
	best.erase("grid_polygon")
	best.erase("priority")
	var authored_base = best.get("base_color", null)
	if authored_base is Color and (authored_base as Color).is_equal_approx(Color.WHITE):
		best.erase("base_color")
	return best


static func authored_section_count() -> int:
	var area := area_definition()
	var value = area.get("sections", [])
	return (value as Array).size() if value is Array else 0


static func authored_road_count() -> int:
	var topology := topology_config()
	var network_value = topology.get("road_network", {})
	if not network_value is Dictionary:
		return 0
	var network := network_value as Dictionary
	if String(network.get("mode", "")) == "painted_tiles":
		var cells_value = network.get("cells", [])
		return (cells_value as Array).size() if cells_value is Array else 0
	var paths_value = network.get("paths", [])
	return (paths_value as Array).size() if paths_value is Array else 0


static func _ensure_cache() -> void:
	if not _cache.is_empty():
		return
	if not _preview_override.is_empty():
		_cache = _preview_override.duplicate(true)
		return
	if not Engine.is_editor_hint() and ResourceLoader.exists(BAKED_PATH):
		var baked = ResourceLoader.load(BAKED_PATH)
		if baked != null:
			var baked_value = baked.get("snapshot")
			if baked_value is Dictionary and not (baked_value as Dictionary).is_empty():
				_cache = (baked_value as Dictionary).duplicate(true)
				return
	if not ResourceLoader.exists(AUTHORING_SCENE_PATH):
		push_error("CentralCityAuthoringData: missing %s" % AUTHORING_SCENE_PATH)
		_cache = {
			"area": {},
			"topology": {},
			"urban_layout": {},
			"buildings": {},
			"props_by_section": {},
			"landscapes_by_section": {},
			"ground_regions": [],
		}
		return

	var resource = ResourceLoader.load(AUTHORING_SCENE_PATH)
	if not resource is PackedScene:
		push_error("CentralCityAuthoringData: authoring resource is not a PackedScene")
		return
	var root := (resource as PackedScene).instantiate()
	if root == null:
		push_error("CentralCityAuthoringData: could not instantiate authoring scene")
		return

	_cache = snapshot_from_root(root)
	root.free()


static func _parse_sections(root: Node) -> Array:
	var container := root.get_node_or_null("Sections")
	if container == null:
		return []
	var sections: Array = []
	for child in container.get_children():
		var coord_value = child.get("coord")
		if not coord_value is Vector2i:
			continue
		var coord := coord_value as Vector2i
		sections.append({
			"coord": [coord.x, coord.y],
			"theme": String(child.get("theme")),
			"title": String(child.get("title")),
			"subtitle": String(child.get("subtitle")),
		})
	sections.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ac = a.get("coord", [0, 0])
		var bc = b.get("coord", [0, 0])
		return int(ac[1]) < int(bc[1]) or (int(ac[1]) == int(bc[1]) and int(ac[0]) < int(bc[0]))
	)
	return sections


static func _parse_levels(root: Node) -> Dictionary:
	var container := root.get_node_or_null("Levels")
	var result := {}
	if container == null:
		return result
	for child in container.get_children():
		var level_id := String(child.get("level_id"))
		if level_id.is_empty():
			continue
		result[level_id] = {"elevation_px": maxf(0.0, float(child.get("elevation_px")))}
	return result


static func _parse_boundary(root: Node) -> Dictionary:
	var container := root.get_node_or_null("Boundaries")
	if container == null or container.get_child_count() == 0:
		return {}
	var boundary = container.get_child(0)
	if not boundary is Line2D:
		return {}
	var line := boundary as Line2D
	if line.points.size() < 2:
		return {}
	var grid_points := PackedVector2Array()
	for point: Vector2 in line.points:
		grid_points.append(world_to_grid(line.position + point))
	var x_min := INF
	var x_max := -INF
	var y_sum := 0.0
	for grid: Vector2 in grid_points:
		x_min = minf(x_min, grid.x)
		x_max = maxf(x_max, grid.x)
		y_sum += grid.y
	return {
		"id": String(boundary.get("boundary_id")),
		"grid_y": y_sum / float(grid_points.size()),
		"lower_threshold_y": float(boundary.get("lower_threshold_grid_y")),
		"x_min": x_min,
		"x_max": x_max,
		"upper_level": String(boundary.get("upper_level")),
		"lower_level": String(boundary.get("lower_level")),
	}


static func _parse_transitions(root: Node) -> Dictionary:
	var result := {"stairs": [], "bridges": [], "voids": []}
	var container := root.get_node_or_null("Transitions")
	if container == null:
		return result
	for child in container.get_children():
		if not child is Polygon2D:
			continue
		var polygon_node := child as Polygon2D
		var grid_polygon := _polygon_to_grid(polygon_node)
		if grid_polygon.size() < 3:
			continue
		var bounds := _grid_bounds(grid_polygon)
		var kind := String(child.get("kind"))
		var transition_id := String(child.get("transition_id"))
		match kind:
			"stairs":
				(result["stairs"] as Array).append({
					"id": transition_id,
					"x_min": bounds.position.x,
					"x_max": bounds.end.x,
					"y_start": bounds.position.y,
					"y_end": bounds.end.y,
					"steps": maxi(2, int(child.get("steps"))),
					"from_level": String(child.get("from_level")),
					"to_level": String(child.get("to_level")),
				})
			"bridge":
				(result["bridges"] as Array).append({
					"id": transition_id,
					"x_min": bounds.position.x,
					"x_max": bounds.end.x,
					"y_min": bounds.position.y,
					"y_max": bounds.end.y,
					"level": String(child.get("level_id")),
				})
			"void":
				(result["voids"] as Array).append({
					"id": transition_id,
					"x_min": bounds.position.x,
					"x_max": bounds.end.x,
					"y_min": bounds.position.y,
					"y_max": bounds.end.y,
				})
	return result


static func _parse_roads(root: Node, _transition_data: Dictionary) -> Dictionary:
	var paint := _parse_ground_paint(root)
	var road_cells: Array[String] = []
	for raw_key in paint.keys():
		var key := String(raw_key)
		if String(paint.get(raw_key, "")) == "road":
			road_cells.append(key)
	road_cells.sort()
	return {
		"mode": "painted_tiles",
		"surface": "road",
		"cells": road_cells,
	}


static func _graph_node_id(
	nodes: Array,
	node_by_key: Dictionary,
	grid: Vector2,
	level_id: String
) -> String:
	var key := "%s:%.3f:%.3f" % [level_id, grid.x, grid.y]
	if node_by_key.has(key):
		return String(node_by_key[key])
	var id := "n_%03d" % nodes.size()
	nodes.append({"id": id, "grid": [grid.x, grid.y], "level": level_id})
	node_by_key[key] = id
	return id


static func _parse_surface_regions(root: Node) -> Dictionary:
	var container := root.get_node_or_null("Surfaces")
	var layer_map := {}
	var layer_order: Array[String] = []
	if container != null:
		for child in container.get_children():
			if not child is Polygon2D:
				continue
			var region := child as Polygon2D
			var layer_id := String(child.get("layer_id"))
			if layer_id.is_empty():
				layer_id = "areas"
			if not layer_map.has(layer_id):
				layer_order.append(layer_id)
				layer_map[layer_id] = {
					"id": layer_id,
					"surface": String(child.get("surface")),
					"tint": _color_array(child.get("tint") as Color),
					"border_width": float(child.get("border_width")),
					"border_color": _color_array(child.get("border_color") as Color),
					"polygons": [],
				}
			var layer := layer_map[layer_id] as Dictionary
			(layer["polygons"] as Array).append({
				"name": String(child.get("region_id")),
				"level": String(child.get("level_id")),
				"surface": String(child.get("surface")),
				"tint": _color_array(child.get("tint") as Color),
				"border_width": float(child.get("border_width")),
				"border_color": _color_array(child.get("border_color") as Color),
				"grid_polygon": _packed_vec2_to_arrays(_polygon_to_grid(region)),
			})
	var layers: Array = []
	for layer_id in layer_order:
		layers.append((layer_map[layer_id] as Dictionary).duplicate(true))
	return {
		"version": 5,
		"description": "Generated at runtime from visual Polygon2D authoring regions.",
		"layers": layers,
	}


static func _parse_buildings(root: Node) -> Dictionary:
	var container := root.get_node_or_null("Buildings")
	var result := {}
	if container == null:
		return result
	for child in container.get_children():
		if not child is Marker2D:
			continue
		var building_id := String(child.get("building_id"))
		if building_id.is_empty():
			continue
		result[building_id] = world_to_grid((child as Marker2D).position)
	return result


static func _parse_props(root: Node, section_size: int) -> Dictionary:
	var container := root.get_node_or_null("Props")
	var result := {}
	if container == null:
		return result
	for child in container.get_children():
		if not child is Marker2D:
			continue
		var global_grid := world_to_grid((child as Marker2D).position)
		var section_coord := _grid_to_section(global_grid, section_size)
		var local_grid := global_grid - Vector2(section_coord * section_size)
		var placement := {
			"asset": String(child.get("asset_id")),
			"cell": [local_grid.x, local_grid.y],
			"role": String(child.get("role")),
		}
		var surround := String(child.get("surround"))
		if surround != "none" and not surround.is_empty():
			placement["surround"] = surround
		var depth := String(child.get("depth"))
		if depth != "world":
			placement["depth"] = depth
		var clearance_value = child.get("clearance_override")
		if clearance_value is Vector2:
			var clearance := clearance_value as Vector2
			if clearance.x >= 0.0 and clearance.y >= 0.0:
				placement["clearance"] = [clearance.x, clearance.y]
		placement["accent"] = _color_array(child.get("accent") as Color)
		var key := _section_key(section_coord)
		if not result.has(key):
			result[key] = []
		(result[key] as Array).append(placement)
	return result


static func _parse_landscapes(root: Node, section_size: int) -> Dictionary:
	var container := root.get_node_or_null("Landscapes")
	var result := {}
	if container == null:
		return result
	for child in container.get_children():
		if not child is Marker2D:
			continue
		var global_grid := world_to_grid((child as Marker2D).position)
		var section_coord := _grid_to_section(global_grid, section_size)
		var local_grid := global_grid - Vector2(section_coord * section_size)
		var key := _section_key(section_coord)
		if not result.has(key):
			result[key] = []
		(result[key] as Array).append(local_grid)
	return result


static func _parse_ground_paint(root: Node) -> Dictionary:
	var node := root.get_node_or_null("GroundPaint")
	if node == null:
		return {}
	var value = node.get("cells")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _parse_ground_regions(root: Node) -> Array:
	var container := root.get_node_or_null("GroundOverrides")
	var result: Array = []
	if container == null:
		return result
	for child in container.get_children():
		if not child is Polygon2D:
			continue
		var region := child as Polygon2D
		var base_color := child.get("base_color") as Color
		result.append({
			"id": String(child.get("region_id")),
			"grid_polygon": _polygon_to_grid(region),
			"surface": String(child.get("surface")),
			"render": bool(child.get("render")),
			"walkable": bool(child.get("walkable")),
			"base_color": base_color,
			"priority": int(child.get("priority")),
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) < int(b.get("priority", 0))
	)
	return result


static func _polygon_to_grid(node: Polygon2D) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in node.polygon:
		result.append(world_to_grid(node.position + point))
	return result


static func _grid_bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for point: Vector2 in points:
		min_point.x = minf(min_point.x, point.x)
		min_point.y = minf(min_point.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)
	return Rect2(min_point, max_point - min_point)


static func _grid_to_section(grid: Vector2, section_size: int) -> Vector2i:
	return Vector2i(
		floori((grid.x + 0.5) / float(section_size)),
		floori((grid.y + 0.5) / float(section_size))
	)


static func _section_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


static func grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * TILE_WIDTH * 0.5,
		(grid.x + grid.y) * TILE_HEIGHT * 0.5
	)


static func world_to_grid(world: Vector2) -> Vector2:
	return Vector2(
		world.x / TILE_WIDTH + world.y / TILE_HEIGHT,
		-world.x / TILE_WIDTH + world.y / TILE_HEIGHT
	)


static func _color_array(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]


static func _packed_vec2_to_arrays(points: PackedVector2Array) -> Array:
	var result: Array = []
	for point: Vector2 in points:
		result.append([point.x, point.y])
	return result
