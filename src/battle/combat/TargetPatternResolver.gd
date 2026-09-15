extends RefCounted
class_name TargetPatternResolver

const FootprintScript = preload("res://src/combat/BattleFootprint.gd")

const DIRS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]


func selection_mode(action: Dictionary) -> String:
	return String(action.get("selection", "unit"))


func cast_grids(field: Node, source_grid: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var source_grids: Array[Vector2i] = [source_grid]
	return cast_grids_for_footprint(field, source_grids, action)


func cast_grids_for_footprint(field: Node, source_grids: Array[Vector2i], action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if source_grids.is_empty():
		return result
	var range_data = action.get("range", {})
	if not range_data is Dictionary:
		return result
	var min_range := maxi(0, int(range_data.get("min", 0)))
	var max_range := maxi(min_range, int(range_data.get("max", min_range)))
	var shape := String(range_data.get("shape", "diamond"))
	var candidates: Dictionary = {}
	for source_grid: Vector2i in source_grids:
		for x in range(source_grid.x - max_range, source_grid.x + max_range + 1):
			for y in range(source_grid.y - max_range, source_grid.y + max_range + 1):
				candidates[Vector2i(x, y)] = true
	for raw_grid in candidates.keys():
		var grid := Vector2i(raw_grid)
		if _grid_exists(field, grid) and _matches_cast_from_footprint(grid, source_grids, shape, min_range, max_range):
			result.append(grid)
	return result


func is_valid_aim_grid(field: Node, source_grid: Vector2i, action: Dictionary, aim_grid: Vector2i) -> bool:
	var source_grids: Array[Vector2i] = [source_grid]
	return is_valid_aim_grid_for_footprint(field, source_grids, action, aim_grid)


func is_valid_aim_grid_for_footprint(field: Node, source_grids: Array[Vector2i], action: Dictionary, aim_grid: Vector2i) -> bool:
	if not _grid_exists(field, aim_grid):
		return false
	var range_data = action.get("range", {})
	if not range_data is Dictionary:
		return source_grids.has(aim_grid)
	var min_range := maxi(0, int(range_data.get("min", 0)))
	var max_range := maxi(min_range, int(range_data.get("max", min_range)))
	return _matches_cast_from_footprint(aim_grid, source_grids, String(range_data.get("shape", "diamond")), min_range, max_range)


func is_valid_target_footprint(field: Node, source_grids: Array[Vector2i], target_grids: Array[Vector2i], action: Dictionary) -> bool:
	if source_grids.is_empty() or target_grids.is_empty():
		return false
	for grid: Vector2i in target_grids:
		if not _grid_exists(field, grid):
			return false
	var range_data = action.get("range", {})
	if not range_data is Dictionary:
		return FootprintScript.intersects(source_grids, target_grids)
	var min_range := maxi(0, int(range_data.get("min", 0)))
	var max_range := maxi(min_range, int(range_data.get("max", min_range)))
	var shape := String(range_data.get("shape", "diamond"))
	var metric := "chebyshev" if ["adjacent_8", "square", "line"].has(shape) else "manhattan"
	var distance := FootprintScript.minimum_distance(source_grids, target_grids, metric)
	if distance < min_range or distance > max_range:
		return false
	if shape == "self":
		return FootprintScript.intersects(source_grids, target_grids)
	if shape == "line":
		for source_grid: Vector2i in source_grids:
			for target_grid: Vector2i in target_grids:
				var delta := target_grid - source_grid
				if delta.x == 0 or delta.y == 0 or absi(delta.x) == absi(delta.y):
					return true
		return false
	return true


func effect_grids(field: Node, source_grid: Vector2i, aim_grid: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var source_grids: Array[Vector2i] = [source_grid]
	return effect_grids_for_footprint(field, source_grids, aim_grid, action)


func effect_grids_for_footprint(field: Node, source_grids: Array[Vector2i], aim_grid: Vector2i, action: Dictionary) -> Array[Vector2i]:
	if source_grids.is_empty():
		return []
	var source_grid := source_grids[0]
	var area_data = action.get("area", {})
	if not area_data is Dictionary:
		return [aim_grid] if _grid_exists(field, aim_grid) else []
	var shape := String(area_data.get("shape", "single"))
	var result: Array[Vector2i] = []
	match shape:
		"self":
			for occupied_grid: Vector2i in source_grids:
				_append_if_valid(result, field, occupied_grid)
		"single":
			_append_if_valid(result, field, aim_grid)
		"diamond":
			var radius := maxi(0, int(area_data.get("radius", 1)))
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					if absi(dx) + absi(dy) <= radius:
						_append_if_valid(result, field, aim_grid + Vector2i(dx, dy))
		"ring":
			var inner_radius := maxi(0, int(area_data.get("innerRadius", 1)))
			var outer_radius := maxi(inner_radius, int(area_data.get("radius", 2)))
			for dx in range(-outer_radius, outer_radius + 1):
				for dy in range(-outer_radius, outer_radius + 1):
					var distance := absi(dx) + absi(dy)
					if distance >= inner_radius and distance <= outer_radius:
						_append_if_valid(result, field, aim_grid + Vector2i(dx, dy))
		"square", "adjacent_8":
			var radius := maxi(1, int(area_data.get("radius", 1)))
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					_append_if_valid(result, field, aim_grid + Vector2i(dx, dy))
		"cross":
			var radius := maxi(0, int(area_data.get("radius", 1)))
			_append_if_valid(result, field, aim_grid)
			for step in range(1, radius + 1):
				_append_if_valid(result, field, aim_grid + Vector2i(step, 0))
				_append_if_valid(result, field, aim_grid + Vector2i(-step, 0))
				_append_if_valid(result, field, aim_grid + Vector2i(0, step))
				_append_if_valid(result, field, aim_grid + Vector2i(0, -step))
		"line":
			var direction := _quantized_direction(aim_grid - source_grid)
			var length := maxi(1, int(area_data.get("length", _chebyshev(aim_grid - source_grid))))
			for edge_grid: Vector2i in FootprintScript.front_edge(source_grids, direction):
				for step in range(1, length + 1):
					_append_if_valid(result, field, edge_grid + direction * step)
		"cone":
			var length := maxi(1, int(area_data.get("length", 3)))
			var angle := clampf(float(area_data.get("angle", 90.0)), 10.0, 170.0)
			var cone_direction := _quantized_direction(aim_grid - source_grid)
			for edge_grid: Vector2i in FootprintScript.front_edge(source_grids, cone_direction):
				_append_cone(result, field, edge_grid, edge_grid + cone_direction, length, angle)
		_:
			_append_if_valid(result, field, aim_grid)
	return result


func _matches_cast_from_footprint(aim_grid: Vector2i, source_grids: Array[Vector2i], shape: String, min_range: int, max_range: int) -> bool:
	if shape == "self":
		return source_grids.has(aim_grid) and min_range == 0
	if shape == "line":
		var nearest_aligned := 999999
		for source_grid: Vector2i in source_grids:
			var delta := aim_grid - source_grid
			if delta.x == 0 or delta.y == 0 or absi(delta.x) == absi(delta.y):
				nearest_aligned = mini(nearest_aligned, _chebyshev(delta))
		return nearest_aligned >= min_range and nearest_aligned <= max_range
	var metric := "chebyshev" if ["adjacent_8", "square"].has(shape) else "manhattan"
	var target_grids: Array[Vector2i] = [aim_grid]
	var distance := FootprintScript.minimum_distance(source_grids, target_grids, metric)
	return distance >= min_range and distance <= max_range


func relationship_matches(source: Node, target: Node, action: Dictionary) -> bool:
	if source == null or target == null:
		return false
	var targets = action.get("targets", ["enemy"])
	if not targets is Array:
		return false
	var source_player := bool(source.get("is_player_controlled"))
	var target_player := bool(target.get("is_player_controlled"))
	var relationship := "self" if source == target else ("ally" if source_player == target_player else "enemy")
	return (targets as Array).has(relationship)


func _matches_cast_shape(delta: Vector2i, shape: String, min_range: int, max_range: int) -> bool:
	var distance := 0
	match shape:
		"self":
			return delta == Vector2i.ZERO
		"adjacent_8", "square":
			distance = _chebyshev(delta)
		"line":
			if not (delta.x == 0 or delta.y == 0 or absi(delta.x) == absi(delta.y)):
				return false
			distance = _chebyshev(delta)
		_:
			distance = absi(delta.x) + absi(delta.y)
	return distance >= min_range and distance <= max_range


func _append_cone(result: Array[Vector2i], field: Node, source_grid: Vector2i, aim_grid: Vector2i, length: int, angle: float) -> void:
	var direction_i := _quantized_direction(aim_grid - source_grid)
	if direction_i == Vector2i.ZERO:
		return
	var direction := Vector2(direction_i).normalized()
	var threshold := cos(deg_to_rad(angle * 0.5))
	for dx in range(-length, length + 1):
		for dy in range(-length, length + 1):
			var delta_i := Vector2i(dx, dy)
			if delta_i == Vector2i.ZERO or _chebyshev(delta_i) > length:
				continue
			var delta := Vector2(delta_i).normalized()
			if direction.dot(delta) + 0.0001 < threshold:
				continue
			_append_if_valid(result, field, source_grid + delta_i)


func _quantized_direction(delta: Vector2i) -> Vector2i:
	return Vector2i(signi(delta.x), signi(delta.y))


func _chebyshev(delta: Vector2i) -> int:
	return maxi(absi(delta.x), absi(delta.y))


func _append_if_valid(result: Array[Vector2i], field: Node, grid: Vector2i) -> void:
	if _grid_exists(field, grid) and not result.has(grid):
		result.append(grid)


func _grid_exists(field: Node, grid: Vector2i) -> bool:
	if field == null:
		return false
	if field.has_method("get_static_tile_block_reason"):
		return String(field.call("get_static_tile_block_reason", grid)) != "out_of_bounds"
	return true
