extends RefCounted
class_name CentralCityUrbanLayout

const CITY = preload("res://src/world/runtime/CentralCityArt.gd")
const CONFIG_PATH := "res://assets/resources/world/central_city_urban_layout.json"
const LAYOUT_Z := -1170

static var _config_cache: Dictionary = {}


static func build() -> Dictionary:
	var root := Node2D.new()
	root.name = "CityUrbanLayout"
	root.z_index = LAYOUT_Z

	var config := _load_config()
	if config.is_empty():
		return {
			"root": root,
			"polygon_count": 0,
			"layer_count": 0,
		}

	var layers_value = config.get("layers", [])
	if not layers_value is Array:
		push_error("CentralCityUrbanLayout: layers must be an array")
		return {
			"root": root,
			"polygon_count": 0,
			"layer_count": 0,
		}

	var polygon_count := 0
	var layer_count := 0
	for raw_layer in layers_value:
		if not raw_layer is Dictionary:
			continue
		var layer := raw_layer as Dictionary
		var layer_id := String(layer.get("id", "layer_%d" % layer_count))
		var polygons_value = layer.get("polygons", [])
		if not polygons_value is Array or polygons_value.is_empty():
			continue

		var fills: Array[Dictionary] = []
		var borders: Array[Dictionary] = []
		var layer_surface := String(layer.get("surface", CITY.SURFACE_MAIN))
		var layer_tint := _color(layer.get("tint", [1.0, 1.0, 1.0, 1.0]))
		var border_width := maxf(0.0, float(layer.get("border_width", 0.0)))
		var border_color := _color(layer.get("border_color", [0.25, 0.27, 0.28, 1.0]))

		for raw_polygon in polygons_value:
			if not raw_polygon is Dictionary:
				continue
			var polygon := raw_polygon as Dictionary
			var points := _grid_polygon(polygon.get("grid_polygon", []))
			if points.size() < 3:
				continue

			var surface := String(polygon.get("surface", layer_surface))
			var tint := _color(polygon.get("tint", [
				layer_tint.r,
				layer_tint.g,
				layer_tint.b,
				layer_tint.a,
			]))
			var fill_color := _tinted_surface_color(surface, tint)
			fills.append({
				"points": points,
				"color": fill_color,
			})

			var polygon_border_width := maxf(
				0.0,
				float(polygon.get("border_width", border_width))
			)
			if polygon_border_width > 0.0:
				var authored_border := _color(polygon.get("border_color", [
					border_color.r,
					border_color.g,
					border_color.b,
					border_color.a,
				]))
				borders.append({
					"points": _expand_polygon(points, polygon_border_width),
					"color": authored_border,
				})
			polygon_count += 1

		if fills.is_empty():
			continue

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
		layer_count += 1

	root.set_meta("polygon_count", polygon_count)
	root.set_meta("layer_count", layer_count)
	return {
		"root": root,
		"polygon_count": polygon_count,
		"layer_count": layer_count,
	}


static func _load_config() -> Dictionary:
	if not _config_cache.is_empty():
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


static func _grid_polygon(value) -> PackedVector2Array:
	var points := PackedVector2Array()
	if not value is Array:
		return points
	for raw_point in value:
		if not raw_point is Array or raw_point.size() < 2:
			continue
		points.append(_grid_to_world(Vector2(float(raw_point[0]), float(raw_point[1]))))
	return points


static func _grid_to_world(grid: Vector2) -> Vector2:
	return Vector2(
		(grid.x - grid.y) * CITY.TILE_HALF_WIDTH,
		(grid.x + grid.y) * CITY.TILE_HALF_HEIGHT
	)


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
	var center := Vector2.ZERO
	for point: Vector2 in points:
		center += point
	center /= float(points.size())

	var expanded := PackedVector2Array()
	for point: Vector2 in points:
		var direction := point - center
		if direction.length_squared() < 0.001:
			expanded.append(point)
		else:
			expanded.append(point + direction.normalized() * margin)
	return expanded


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
