extends RefCounted
class_name TargetPatternResolver

const DIRS_8: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1, 0), Vector2i(1, 0),
	Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]


func selection_mode(action: Dictionary) -> String:
	return String(action.get("selection", "unit"))


func cast_grids(field: Node, source_grid: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var range_data = action.get("range", {})
	if not range_data is Dictionary:
		return result
	var min_range := maxi(0, int(range_data.get("min", 0)))
	var max_range := maxi(min_range, int(range_data.get("max", min_range)))
	var shape := String(range_data.get("shape", "diamond"))
	for x in range(source_grid.x - max_range, source_grid.x + max_range + 1):
		for y in range(source_grid.y - max_range, source_grid.y + max_range + 1):
			var grid := Vector2i(x, y)
			if not _grid_exists(field, grid):
				continue
			if _matches_cast_shape(grid - source_grid, shape, min_range, max_range):
				result.append(grid)
	return result


func is_valid_aim_grid(field: Node, source_grid: Vector2i, action: Dictionary, aim_grid: Vector2i) -> bool:
	if not _grid_exists(field, aim_grid):
		return false
	var range_data = action.get("range", {})
	if not range_data is Dictionary:
		return aim_grid == source_grid
	var min_range := maxi(0, int(range_data.get("min", 0)))
	var max_range := maxi(min_range, int(range_data.get("max", min_range)))
	return _matches_cast_shape(aim_grid - source_grid, String(range_data.get("shape", "diamond")), min_range, max_range)


func effect_grids(field: Node, source_grid: Vector2i, aim_grid: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var area_data = action.get("area", {})
	if not area_data is Dictionary:
		return [aim_grid] if _grid_exists(field, aim_grid) else []
	var shape := String(area_data.get("shape", "single"))
	var result: Array[Vector2i] = []
	match shape:
		"self":
			_append_if_valid(result, field, source_grid)
		"single":
			_append_if_valid(result, field, aim_grid)
		"diamond":
			var radius := maxi(0, int(area_data.get("radius", 1)))
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					if absi(dx) + absi(dy) <= radius:
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
			for step in range(1, length + 1):
				_append_if_valid(result, field, source_grid + direction * step)
		"cone":
			var length := maxi(1, int(area_data.get("length", 3)))
			var angle := clampf(float(area_data.get("angle", 90.0)), 10.0, 170.0)
			_append_cone(result, field, source_grid, aim_grid, length, angle)
		_:
			_append_if_valid(result, field, aim_grid)
	return result


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
