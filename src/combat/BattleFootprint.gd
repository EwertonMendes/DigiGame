extends RefCounted
class_name BattleFootprint

const SINGLE := "single"
const LARGE_2X2 := "large_2x2"

const _OFFSETS := {
	SINGLE: [Vector2i.ZERO],
	LARGE_2X2: [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(1, 1),
	],
}


static func normalize_id(footprint_id: String) -> String:
	var clean_id := footprint_id.to_lower().strip_edges()
	return clean_id if _OFFSETS.has(clean_id) else SINGLE


static func is_supported(footprint_id: String) -> bool:
	return _OFFSETS.has(footprint_id.to_lower().strip_edges())


static func offsets_for(footprint_id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for raw_offset in _OFFSETS[normalize_id(footprint_id)]:
		result.append(Vector2i(raw_offset))
	return result


static func occupied_grids(anchor: Vector2i, footprint_id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset: Vector2i in offsets_for(footprint_id):
		result.append(anchor + offset)
	return result


static func newly_entered_grids(previous_anchor: Vector2i, next_anchor: Vector2i, footprint_id: String) -> Array[Vector2i]:
	var previous := occupied_grids(previous_anchor, footprint_id)
	var result: Array[Vector2i] = []
	for grid: Vector2i in occupied_grids(next_anchor, footprint_id):
		if not previous.has(grid):
			result.append(grid)
	return result


static func minimum_distance(first: Array[Vector2i], second: Array[Vector2i], metric: String = "manhattan") -> int:
	if first.is_empty() or second.is_empty():
		return 999999
	var result := 999999
	for first_grid: Vector2i in first:
		for second_grid: Vector2i in second:
			var delta := second_grid - first_grid
			var distance := (
				maxi(absi(delta.x), absi(delta.y))
				if metric == "chebyshev"
				else absi(delta.x) + absi(delta.y)
			)
			result = mini(result, distance)
	return result


static func center_world(field: Node, anchor: Vector2i, footprint_id: String) -> Vector2:
	if field == null or not field.has_method("grid_to_world"):
		return Vector2(anchor)
	var result := Vector2.ZERO
	var grids := occupied_grids(anchor, footprint_id)
	for grid: Vector2i in grids:
		result += Vector2(field.call("grid_to_world", grid))
	return result / float(maxi(1, grids.size()))


static func front_edge(grids: Array[Vector2i], direction: Vector2i) -> Array[Vector2i]:
	if grids.is_empty() or direction == Vector2i.ZERO:
		return grids.duplicate()
	var best_projection := -1_000_000
	var result: Array[Vector2i] = []
	for grid: Vector2i in grids:
		var projection := grid.x * direction.x + grid.y * direction.y
		if projection > best_projection:
			best_projection = projection
			result.clear()
			result.append(grid)
		elif projection == best_projection:
			result.append(grid)
	return result


static func intersects(first: Array[Vector2i], second: Array[Vector2i]) -> bool:
	for grid: Vector2i in first:
		if second.has(grid):
			return true
	return false
