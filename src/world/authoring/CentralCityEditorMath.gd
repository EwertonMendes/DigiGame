@tool
extends RefCounted
class_name CentralCityEditorMath

const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const UPPER_ELEVATION_PX := 48.0
const TERRACE_THRESHOLD_Y := 19.5


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


static func visual_world_to_grid(world: Vector2) -> Vector2:
	var upper := world_to_grid(world + Vector2(0.0, UPPER_ELEVATION_PX))
	if upper.y < TERRACE_THRESHOLD_Y:
		return upper
	return world_to_grid(world)


static func grid_to_visual_world(grid: Vector2, elevation_px: float) -> Vector2:
	return grid_to_world(grid) + Vector2(0.0, -elevation_px)


static func snap_grid(grid: Vector2, step: float) -> Vector2:
	if step <= 0.0:
		return grid
	return Vector2(
		roundf(grid.x / step) * step,
		roundf(grid.y / step) * step
	)


static func constrained_endpoint(
	anchor_grid: Vector2,
	original_grid: Vector2,
	candidate_grid: Vector2,
	step: float
) -> Vector2:
	var snapped := snap_grid(candidate_grid, step)
	var delta := original_grid - anchor_grid
	if absf(delta.x) >= absf(delta.y):
		snapped.y = anchor_grid.y
	else:
		snapped.x = anchor_grid.x
	return snapped


static func screen_distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.0001:
		return point.distance_to(a)
	var t := clampf((point - a).dot(ab) / length_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t)


static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]
